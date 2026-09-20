import Foundation
import Combine
import SwiftUI

@MainActor
public class SplashService: ObservableObject {
    public static let shared = SplashService()
    
    // MARK: - Published State
    @Published public var isRunning: Bool = false
    @Published public var activePid: Int? = nil
    @Published public var activePort: Int = 8005
    @Published public var activeModel: String = "Ninguno"
    @Published public var status: SplashStatus? = nil
    @Published public var lastError: String? = nil
    
    // Model lists
    @Published public var installedModels: [InstalledSplashModel] = []
    @Published public var availableOnlineModels: [HuggingFaceModelItem] = []
    @Published public var isLoadingOnlineModels: Bool = false
    @Published public var selectedModelForLaunch: String = "incoai/Qwen3.6-35B-A3B-Splash"
    
    // Installation state
    @Published public var isInstalling: Bool = false
    @Published public var installingModelId: String? = nil
    @Published public var installLogs: [String] = []
    @Published public var installSuccess: Bool? = nil
    
    // Performance history for graphing
    @Published public var speedHistory: [Double] = []
    
    // Settings
    @AppStorage("refreshInterval") public var refreshInterval: Double = 1.5
    @AppStorage("menuBarDisplayMode") public var menuBarDisplayMode: String = "speed" // "icon", "speed", "tokens", "model"
    
    // Timers
    private var timer: Timer?
    private var installProcess: Process?
    
    // Paths
    public let dataDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Splash")
    }()
    
    public var modelsDirectory: URL {
        dataDirectory.appendingPathComponent("models")
    }
    
    public var lockFileURL: URL {
        dataDirectory.appendingPathComponent("runtime/serve.lock")
    }
    
    public var splashExecutablePath: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/splash") {
            return "/opt/homebrew/bin/splash"
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/splash") {
            return "/usr/local/bin/splash"
        }
        return "splash"
    }
    
    public var splashPythonPath: String {
        let cellarPath = "/opt/homebrew/Cellar/splash/1.0/libexec/python/bin/python3"
        if FileManager.default.fileExists(atPath: cellarPath) {
            return cellarPath
        }
        return "/usr/bin/python3"
    }
    
    public var splashModelsScriptPath: String {
        let scriptPath = "/opt/homebrew/Cellar/splash/1.0/libexec/install/models.py"
        if FileManager.default.fileExists(atPath: scriptPath) {
            return scriptPath
        }
        return ""
    }
    
    public init() {
        startPolling()
        refreshInstalledModels()
        Task {
            await fetchOnlineModels()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Polling & Status Fetching
    
    public func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.checkServerStatus()
            }
        }
        // Immediate check
        Task { @MainActor in
            await self.checkServerStatus()
        }
    }
    
    public func checkServerStatus() async {
        // 1. Read serve.lock if present
        var lockPid: Int? = nil
        var lockPort: Int = self.activePort
        var lockModel: String? = nil
        
        if FileManager.default.fileExists(atPath: lockFileURL.path) {
            do {
                let data = try Data(contentsOf: lockFileURL)
                if let lock = try? JSONDecoder().decode(ServeLock.self, from: data) {
                    lockPid = lock.pid
                    lockPort = lock.port
                    lockModel = lock.model
                }
            } catch {
                // Ignore lock file read race
            }
        }
        
        // Check if process is alive if we have a PID
        if let pid = lockPid {
            let isAlive = kill(pid_t(pid), 0) == 0
            if !isAlive {
                lockPid = nil
            }
        }
        
        self.activePort = lockPort
        if let model = lockModel {
            self.activeModel = model
        }
        self.activePid = lockPid
        
        // 2. Query /status endpoint
        let endpoint = "http://127.0.0.1:\(activePort)/status"
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                let decoded = try JSONDecoder().decode(SplashStatus.self, from: data)
                self.status = decoded
                self.isRunning = decoded.ready ?? true
                if let instanceModel = decoded.instance?.model {
                    self.activeModel = instanceModel
                }
                if let pid = decoded.instance?.pid {
                    self.activePid = pid
                }
                
                // Track decode speed for chart
                let currentSpeed = decoded.metrics?.decodeTokensPerSecond ?? 0.0
                self.speedHistory.append(currentSpeed)
                if self.speedHistory.count > 30 {
                    self.speedHistory.removeFirst()
                }
                self.lastError = nil
            } else {
                self.isRunning = false
                self.status = nil
            }
        } catch {
            // Also attempt fallback to port 8000 if 8005 failed and lock file wasn't present
            if lockPid == nil && activePort == 8005 {
                await tryFallbackPort8000()
            } else {
                self.isRunning = false
                self.status = nil
            }
        }
        
        // Update active flag on installed models list
        refreshInstalledModels()
    }
    
    private func tryFallbackPort8000() async {
        guard let url = URL(string: "http://127.0.0.1:8000/status") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.8
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
           let decoded = try? JSONDecoder().decode(SplashStatus.self, from: data) {
            self.activePort = 8000
            self.status = decoded
            self.isRunning = decoded.ready ?? true
            if let instanceModel = decoded.instance?.model {
                self.activeModel = instanceModel
            }
            if let pid = decoded.instance?.pid {
                self.activePid = pid
            }
        }
    }
    
    // MARK: - Local Installed Models
    
    public func refreshInstalledModels() {
        var results: [InstalledSplashModel] = []
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: modelsDirectory.path) else {
            self.installedModels = []
            return
        }
        
        do {
            let owners = try fm.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            for ownerURL in owners where ownerURL.hasDirectoryPath {
                let owner = ownerURL.lastPathComponent
                let modelURLs = try fm.contentsOfDirectory(at: ownerURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                for modelURL in modelURLs {
                    let modelName = modelURL.lastPathComponent
                    let repoId = "\(owner)/\(modelName)"
                    let isActive = (repoId == self.activeModel && self.isRunning)
                    
                    // Calculate size
                    let size = calculateDirectorySize(url: modelURL)
                    
                    results.append(InstalledSplashModel(
                        repoId: repoId,
                        localPath: modelURL,
                        diskSizeBytes: size,
                        isCurrentlyActive: isActive
                    ))
                }
            }
        } catch {
            print("Error scanning installed models: \(error)")
        }
        
        self.installedModels = results
        if isRunning && !activeModel.isEmpty && activeModel != "Ninguno" {
            self.selectedModelForLaunch = activeModel
        } else if (self.selectedModelForLaunch.isEmpty || !results.contains(where: { $0.repoId == self.selectedModelForLaunch })),
                  let first = results.first {
            self.selectedModelForLaunch = first.repoId
        }
    }
    
    private func calculateDirectorySize(url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]) else {
            return 0
        }
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]),
               values.isRegularFile == true {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        return total
    }
    
    // MARK: - Online Models Catalog (Hugging Face)
    
    public func fetchOnlineModels() async {
        self.isLoadingOnlineModels = true
        var allItems: [String: HuggingFaceModelItem] = [:]
        
        // 1. Fetch Inco AI models
        if let incoUrl = URL(string: "https://huggingface.co/api/models?author=incoai") {
            if let (data, _) = try? await URLSession.shared.data(from: incoUrl),
               let items = try? JSONDecoder().decode([HuggingFaceModelItem].self, from: data) {
                for item in items {
                    // Filter models that are Splash packages (end with -Splash or tagged splash)
                    if item.id.hasSuffix("-Splash") || (item.tags?.contains("splash") ?? false) {
                        allItems[item.id] = item
                    }
                }
            }
        }
        
        // 2. Fetch all models with tag "splash"
        if let splashTagUrl = URL(string: "https://huggingface.co/api/models?filter=splash") {
            if let (data, _) = try? await URLSession.shared.data(from: splashTagUrl),
               let items = try? JSONDecoder().decode([HuggingFaceModelItem].self, from: data) {
                for item in items {
                    allItems[item.id] = item
                }
            }
        }
        
        // Sort: Inco AI official first, then likes/name
        let sorted = allItems.values.sorted { m1, m2 in
            if m1.isOfficial != m2.isOfficial {
                return m1.isOfficial && !m2.isOfficial
            }
            return (m1.likes ?? 0) > (m2.likes ?? 0)
        }
        
        self.availableOnlineModels = Array(sorted)
        self.isLoadingOnlineModels = false
    }
    
    // MARK: - Model Installation
    
    public func installModel(repoId: String) {
        guard !isInstalling else { return }
        isInstalling = true
        installingModelId = repoId
        installLogs = ["Iniciando descarga y preparación para \(repoId)..."]
        installSuccess = nil
        
        Task.detached(priority: .userInitiated) {
            let scriptPath = await self.splashModelsScriptPath
            let pythonPath = await self.splashPythonPath
            
            guard !scriptPath.isEmpty, FileManager.default.fileExists(atPath: scriptPath) else {
                await MainActor.run {
                    self.installLogs.append("Error: No se encontró script de instalación en \(scriptPath)")
                    self.isInstalling = false
                    self.installSuccess = false
                }
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = ["-u", scriptPath, "--model", repoId, "prepare"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            let outHandle = pipe.fileHandleForReading
            outHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                Task { @MainActor in
                    for line in lines {
                        self.installLogs.append(line)
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                outHandle.readabilityHandler = nil
                
                let success = process.terminationStatus == 0
                await MainActor.run {
                    self.isInstalling = false
                    self.installSuccess = success
                    if success {
                        self.installLogs.append(" Instalación y verificación de \(repoId) completada con éxito.")
                        self.refreshInstalledModels()
                    } else {
                        self.installLogs.append(" Error al instalar \(repoId). Código de salida: \(process.terminationStatus)")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isInstalling = false
                    self.installSuccess = false
                    self.installLogs.append(" Error ejecutando proceso: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Server Control
    
    public func stopServer() {
        guard let pid = activePid, pid > 0 else { return }
        kill(pid_t(pid), SIGTERM)
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await checkServerStatus()
        }
    }
    
    public func startServer(model: String, port: Int = 8005) {
        stopServer()
        
        let splashPath = splashExecutablePath
        let script = """
        tell application "Terminal"
            do script "\(splashPath) serve --model \(model) --port \(port)"
            activate
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error starting server: \(error)")
            }
        }
        
        Task {
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await checkServerStatus()
                if isRunning { break }
            }
        }
    }
    
    public func switchModel(to model: String) {
        startServer(model: model, port: activePort)
    }
    
    public func launchAgent(agent: String) {
        let splashPath = splashExecutablePath
        let script = """
        tell application "Terminal"
            do script "\(splashPath) \(agent)"
            activate
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    // MARK: - Formatting Helpers
    
    public var formattedTokensDecode: String {
        guard let tokens = status?.metrics?.decodeOutputTokens else { return "0" }
        return formatNumber(tokens)
    }
    
    public var formattedTokensPrefill: String {
        guard let tokens = status?.metrics?.prefillInputTokens else { return "0" }
        return formatNumber(tokens)
    }
    
    public var formattedTokensReused: String {
        guard let tokens = status?.cache?.reusedTokens else { return "0" }
        return formatNumber(tokens)
    }
    
    public var formattedDecodeSpeed: String {
        guard let speed = status?.metrics?.decodeTokensPerSecond else { return "0.0" }
        return String(format: "%.1f", speed)
    }
    
    public var formattedPrefillSpeed: String {
        guard let speed = status?.metrics?.prefillTokensPerSecond else { return "0.0" }
        return String(format: "%.1f", speed)
    }
    
    public var formattedDraftAcceptanceRate: String {
        guard let rate = status?.metrics?.draftAcceptanceRate else { return "0.0%" }
        return String(format: "%.1f%%", rate * 100.0)
    }
    
    public var formattedCacheHitRate: String {
        guard let rate = status?.cache?.hitRate else { return "0.0%" }
        return String(format: "%.1f%%", rate * 100.0)
    }
    
    public var formattedMemoryUsed: String {
        guard let bytes = status?.memoryActual?.currentBytes else { return "0 GB" }
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public var formattedMemoryLimit: String {
        guard let bytes = status?.memoryGovernor?.limitBytes ?? status?.memoryPlan?.device?.recommendedMaxWorkingSetBytes else { return "0 GB" }
        let gb = Double(bytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
    
    public var memoryUsageRatio: Double {
        guard let current = status?.memoryActual?.currentBytes,
              let limit = status?.memoryGovernor?.limitBytes ?? status?.memoryPlan?.device?.recommendedMaxWorkingSetBytes,
              limit > 0 else { return 0.0 }
        return min(1.0, Double(current) / Double(limit))
    }
    
    private func formatNumber(_ num: Int64) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000.0)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000.0)
        }
        return "\(num)"
    }
}
