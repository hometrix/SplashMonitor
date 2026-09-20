import Foundation
import Combine
import SwiftUI
import AppKit

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
    
    // Dependencies & CLI state
    @Published public var isSplashInstalled: Bool = false
    @Published public var splashVersion: String? = nil
    @Published public var hasHomebrew: Bool = false
    @Published public var isInstallingDependency: Bool = false
    @Published public var dependencyInstallLogs: [String] = []
    @Published public var dependencyInstallSuccess: Bool? = nil
    
    // Model lists
    @Published public var installedModels: [InstalledSplashModel] = []
    @Published public var availableOnlineModels: [HuggingFaceModelItem] = []
    @Published public var isLoadingOnlineModels: Bool = false
    @Published public var selectedModelForLaunch: String = "incoai/Qwen3.6-35B-A3B-Splash"
    
    // Model Installation state
    @Published public var isInstalling: Bool = false
    @Published public var installingModelId: String? = nil
    @Published public var installLogs: [String] = []
    @Published public var installSuccess: Bool? = nil
    
    // Performance history for graphing
    @Published public var speedHistory: [Double] = []
    
    // Settings
    @AppStorage("refreshInterval") public var refreshInterval: Double = 1.5
    @AppStorage("menuBarDisplayMode") public var menuBarDisplayMode: String = "speed" // "icon", "speed", "tokens", "model"
    
    // Timers & Processes
    private var timer: Timer?
    private var installProcess: Process?
    private var dependencyProcess: Process?
    
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
    
    public var brewExecutablePath: String? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for p in candidates where FileManager.default.isExecutableFile(atPath: p) {
            return p
        }
        return nil
    }
    
    public var splashExecutablePath: String {
        let candidates = [
            "/opt/homebrew/bin/splash",
            "/usr/local/bin/splash",
            "/opt/homebrew/opt/splash/bin/splash",
            "/usr/local/opt/splash/bin/splash"
        ]
        for p in candidates where FileManager.default.isExecutableFile(atPath: p) {
            return p
        }
        return "splash"
    }
    
    public var splashPythonPath: String {
        let candidates = [
            "/opt/homebrew/opt/splash/libexec/python/bin/python3",
            "/usr/local/opt/splash/libexec/python/bin/python3",
            "/opt/homebrew/Cellar/splash/1.0/libexec/python/bin/python3",
            "/usr/local/Cellar/splash/1.0/libexec/python/bin/python3"
        ]
        for p in candidates where FileManager.default.fileExists(atPath: p) {
            return p
        }
        
        let fm = FileManager.default
        let cellarRoots = ["/opt/homebrew/Cellar/splash", "/usr/local/Cellar/splash"]
        for root in cellarRoots where fm.fileExists(atPath: root) {
            if let versions = try? fm.contentsOfDirectory(atPath: root) {
                for v in versions {
                    let py = "\(root)/\(v)/libexec/python/bin/python3"
                    if fm.fileExists(atPath: py) {
                        return py
                    }
                }
            }
        }
        return "/usr/bin/python3"
    }
    
    public var splashModelsScriptPath: String {
        let candidates = [
            "/opt/homebrew/opt/splash/libexec/install/models.py",
            "/usr/local/opt/splash/libexec/install/models.py",
            "/opt/homebrew/Cellar/splash/1.0/libexec/install/models.py",
            "/usr/local/Cellar/splash/1.0/libexec/install/models.py"
        ]
        for p in candidates where FileManager.default.fileExists(atPath: p) {
            return p
        }
        
        let fm = FileManager.default
        let cellarRoots = ["/opt/homebrew/Cellar/splash", "/usr/local/Cellar/splash"]
        for root in cellarRoots where fm.fileExists(atPath: root) {
            if let versions = try? fm.contentsOfDirectory(atPath: root) {
                for v in versions {
                    let script = "\(root)/\(v)/libexec/install/models.py"
                    if fm.fileExists(atPath: script) {
                        return script
                    }
                }
            }
        }
        return ""
    }
    
    public init() {
        checkDependencies()
        startPolling()
        refreshInstalledModels()
        Task {
            await fetchOnlineModels()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Dependency Management
    
    public func checkDependencies() {
        self.hasHomebrew = brewExecutablePath != nil
        let directPath = splashExecutablePath
        let isDirectExecutable = directPath != "splash" && FileManager.default.isExecutableFile(atPath: directPath)
        
        if isDirectExecutable {
            self.isSplashInstalled = true
            // Read splash --version
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: directPath)
            proc.arguments = ["--version"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let ver = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !ver.isEmpty {
                    self.splashVersion = ver.replacingOccurrences(of: "splash ", with: "v")
                } else {
                    self.splashVersion = "v1.0"
                }
            } catch {
                self.splashVersion = "v1.0"
            }
        } else {
            // Check via which
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            proc.arguments = ["splash"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            do {
                try proc.run()
                proc.waitUntilExit()
                self.isSplashInstalled = (proc.terminationStatus == 0)
                self.splashVersion = self.isSplashInstalled ? "v1.0" : nil
            } catch {
                self.isSplashInstalled = false
                self.splashVersion = nil
            }
        }
    }
    
    public func installSplashDependency() {
        guard !isInstallingDependency else { return }
        isInstallingDependency = true
        dependencyInstallLogs = [
            "Iniciando instalación de la dependencia Splash...",
            "Comando: brew install incoai/tap/splash"
        ]
        dependencyInstallSuccess = nil
        
        guard let brewPath = brewExecutablePath else {
            dependencyInstallLogs.append("Error: No se encontró Homebrew instalado en /opt/homebrew/bin/brew o /usr/local/bin/brew.")
            dependencyInstallLogs.append("Por favor instala Homebrew primero desde https://brew.sh")
            isInstallingDependency = false
            dependencyInstallSuccess = false
            return
        }
        
        Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: brewPath)
            proc.arguments = ["install", "incoai/tap/splash"]
            
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            proc.environment = env
            
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            
            let outHandle = pipe.fileHandleForReading
            outHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                Task { @MainActor in
                    for line in lines {
                        self.dependencyInstallLogs.append(line)
                    }
                }
            }
            
            await MainActor.run {
                self.dependencyProcess = proc
            }
            
            do {
                try proc.run()
                proc.waitUntilExit()
                outHandle.readabilityHandler = nil
                
                let status = proc.terminationStatus
                await MainActor.run {
                    self.dependencyProcess = nil
                    self.isInstallingDependency = false
                    if status == 0 {
                        self.dependencyInstallSuccess = true
                        self.dependencyInstallLogs.append(" Splash se instaló correctamente.")
                        self.checkDependencies()
                        self.refreshInstalledModels()
                    } else {
                        self.dependencyInstallSuccess = false
                        self.dependencyInstallLogs.append(" brew install finalizó con código de error \(status).")
                    }
                }
            } catch {
                await MainActor.run {
                    self.dependencyProcess = nil
                    self.isInstallingDependency = false
                    self.dependencyInstallSuccess = false
                    self.dependencyInstallLogs.append(" Error al ejecutar el instalador: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func cancelDependencyInstall() {
        dependencyProcess?.terminate()
        dependencyProcess = nil
        isInstallingDependency = false
        dependencyInstallLogs.append(" Proceso de instalación cancelado.")
    }
    
    public func installSplashInTerminal() {
        let script = """
        tell application "Terminal"
            do script "brew install incoai/tap/splash"
            activate
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    public func upgradeSplashInTerminal() {
        let script = """
        tell application "Terminal"
            do script "brew update && brew upgrade splash"
            activate
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
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
                // Stale lock file cleanup
                try? FileManager.default.removeItem(at: lockFileURL)
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
            // Fallback to port 8000 if 8005 failed and lock file wasn't present
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
                    
                    // Calculate real size resolving symlinks
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
        let resolvedRoot = url.resolvingSymlinksInPath()
        
        guard let enumerator = fm.enumerator(at: resolvedRoot, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        for case let fileURL as URL in enumerator {
            let resolved = fileURL.resolvingSymlinksInPath()
            if let attrs = try? fm.attributesOfItem(atPath: resolved.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
    
    public func deleteModel(repoId: String) {
        let symlinkURL = modelsDirectory.appendingPathComponent(repoId)
        let fm = FileManager.default
        do {
            if repoId == activeModel && isRunning {
                stopServer()
            }
            if fm.fileExists(atPath: symlinkURL.path) {
                try fm.removeItem(at: symlinkURL)
            }
            refreshInstalledModels()
        } catch {
            print("Error deleting model symlink \(repoId): \(error)")
        }
    }
    
    public func openModelInFinder(repoId: String) {
        let symlinkURL = modelsDirectory.appendingPathComponent(repoId)
        let resolved = symlinkURL.resolvingSymlinksInPath()
        if FileManager.default.fileExists(atPath: resolved.path) {
            NSWorkspace.shared.selectFile(resolved.path, inFileViewerRootedAtPath: "")
        } else if FileManager.default.fileExists(atPath: symlinkURL.path) {
            NSWorkspace.shared.selectFile(symlinkURL.path, inFileViewerRootedAtPath: "")
        } else {
            NSWorkspace.shared.open(modelsDirectory)
        }
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
        
        let modelsPath = modelsDirectory.path
        let scriptPath = splashModelsScriptPath
        let pythonPath = splashPythonPath
        
        Task.detached(priority: .userInitiated) {
            guard !scriptPath.isEmpty, FileManager.default.fileExists(atPath: scriptPath) else {
                await MainActor.run {
                    self.installLogs.append("Error: No se encontró script de instalación en \(scriptPath).")
                    self.installLogs.append("Asegúrate de que Splash esté instalado vía: brew install incoai/tap/splash")
                    self.isInstalling = false
                    self.installSuccess = false
                }
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = ["-u", scriptPath, "--models", modelsPath, "--model", repoId, "prepare"]
            
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
            
            await MainActor.run {
                self.installProcess = process
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                outHandle.readabilityHandler = nil
                
                let success = process.terminationStatus == 0
                await MainActor.run {
                    self.installProcess = nil
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
                    self.installProcess = nil
                    self.isInstalling = false
                    self.installSuccess = false
                    self.installLogs.append(" Error ejecutando proceso: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func cancelModelInstall() {
        installProcess?.terminate()
        installProcess = nil
        isInstalling = false
        installSuccess = false
        installLogs.append(" Descarga cancelada por el usuario.")
    }
    
    // MARK: - Server Control
    
    public func stopServer() {
        if let pid = activePid, pid > 0 {
            // Send SIGINT first for graceful exit (Splash recommended)
            kill(pid_t(pid), SIGINT)
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) { [weak self] in
                if kill(pid_t(pid), 0) == 0 {
                    kill(pid_t(pid), SIGTERM)
                }
                Task { @MainActor [weak self] in
                    self?.cleanupLockAndProcess()
                }
            }
        } else {
            cleanupLockAndProcess()
        }
    }
    
    private func cleanupLockAndProcess() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        proc.arguments = ["-f", "splash serve"]
        try? proc.run()
        proc.waitUntilExit()
        
        if FileManager.default.fileExists(atPath: lockFileURL.path) {
            try? FileManager.default.removeItem(at: lockFileURL)
        }
        self.isRunning = false
        self.status = nil
        self.activePid = nil
    }
    
    public func startServer(model: String, port: Int = 8005) {
        guard isSplashInstalled else {
            installSplashDependency()
            return
        }
        
        stopServer()
        
        // Wait 400ms before starting new process to ensure port is freed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            let splashPath = self.splashExecutablePath
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
                for _ in 0..<12 {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await self.checkServerStatus()
                    if self.isRunning { break }
                }
            }
        }
    }
    
    public func switchModel(to model: String) {
        startServer(model: model, port: activePort)
    }
    
    // MARK: - Agent Launcher Helpers
    
    public func isAgentInstalled(agent: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/\(agent)",
            "/usr/local/bin/\(agent)",
            "/usr/bin/\(agent)",
            "\(home)/.npm-global/bin/\(agent)",
            "\(home)/.cargo/bin/\(agent)",
            "\(home)/.local/bin/\(agent)"
        ]
        for p in candidates where FileManager.default.isExecutableFile(atPath: p) {
            return true
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [agent]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }
    
    public func agentInstallURL(agent: String) -> URL {
        switch agent {
        case "claude":
            return URL(string: "https://code.claude.com/docs/en/overview")!
        case "opencode":
            return URL(string: "https://opencode.ai/docs/")!
        case "codex":
            return URL(string: "https://developers.openai.com/codex/cli/")!
        case "hermes":
            return URL(string: "https://hermes-agent.nousresearch.com/docs/getting-started/installation/")!
        default:
            return URL(string: "https://github.com/incoai/splash")!
        }
    }
    
    public func launchAgent(agent: String) {
        guard isSplashInstalled else {
            installSplashDependency()
            return
        }
        
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
