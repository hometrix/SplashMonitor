import Foundation
import Combine
import SwiftUI
import AppKit

// MARK: - Port Conflict Model

public struct PortConflictInfo: Identifiable, Equatable {
    public var id: String { "\(port)-\(pid)" }
    public let port: Int
    public let processName: String
    public let pid: Int32
    public let suggestedPort: Int
    
    public init(port: Int, processName: String, pid: Int32, suggestedPort: Int) {
        self.port = port
        self.processName = processName
        self.pid = pid
        self.suggestedPort = suggestedPort
    }
}

@MainActor
public class SplashService: ObservableObject {
    public static let shared = SplashService()
    
    // MARK: - Published State
    @Published public var isRunning: Bool = false
    @Published public var activePid: Int? = nil
    @Published public var activePort: Int = 8000
    @Published public var portConflict: PortConflictInfo? = nil
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
    
    // Server Launching state
    @Published public var isStartingServer: Bool = false
    @Published public var startingModelId: String? = nil
    
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
    
    public var splashLauncherScriptURL: URL {
        dataDirectory.appendingPathComponent("splash_launcher.py")
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
        let cmd = """
        echo "🍺 Instalando Splash Engine via Homebrew..."
        echo ""
        brew install incoai/tap/splash
        echo ""
        echo "Instalación finalizada. Ya puedes cerrar esta ventana."
        """
        runInTerminal(command: cmd, title: "Instalar Splash", scriptFileName: "install_splash.command")
    }
    
    public func upgradeSplashInTerminal() {
        let cmd = """
        echo "🍺 Actualizando Splash Engine via Homebrew..."
        echo ""
        brew update && brew upgrade splash
        echo ""
        echo "Actualización finalizada. Ya puedes cerrar esta ventana."
        """
        runInTerminal(command: cmd, title: "Actualizar Splash", scriptFileName: "upgrade_splash.command")
    }
    
    private func runInTerminal(command: String, title: String, scriptFileName: String) {
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let scriptURL = dataDirectory.appendingPathComponent(scriptFileName)
        let scriptContent = """
        #!/bin/bash
        printf "\\e]0;\(title)\\a"
        \(command)
        """
        try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "Terminal", scriptURL.path]
        try? proc.run()
        
        // Also bring Terminal window to foreground
        let actProc = Process()
        actProc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        actProc.arguments = ["-e", "tell application \"Terminal\" to activate"]
        try? actProc.run()
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
            // Fallback to port 8005 if 8000 failed and lock file wasn't present
            if lockPid == nil && activePort == 8000 {
                await tryFallbackPort8005()
            } else {
                self.isRunning = false
                self.status = nil
            }
        }
        
        // Update active flag on installed models list
        refreshInstalledModels()
    }
    
    private func tryFallbackPort8005() async {
        guard let url = URL(string: "http://127.0.0.1:8005/status") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.8
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
           let decoded = try? JSONDecoder().decode(SplashStatus.self, from: data) {
            self.activePort = 8005
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
    
    public func stopServerAsync() async {
        await killSplashProcesses(port: activePort)
        self.isRunning = false
        self.status = nil
        self.activePid = nil
    }
    
    public func stopServer() {
        Task {
            await stopServerAsync()
        }
    }
    
    public func killSplashProcesses(port: Int) async {
        // 1. Send SIGINT to activePid or PID in serve.lock for graceful exit
        var targetPids: Set<Int32> = []
        if let p = activePid, p > 0 { targetPids.insert(Int32(p)) }
        if let lockPid = readLockPid(), lockPid > 0 { targetPids.insert(Int32(lockPid)) }
        
        for p in targetPids {
            kill(p, SIGINT)
        }
        
        // 2. Also send SIGINT to python server.py and native engine
        runPkill(pattern: "server.py", signal: "-INT")
        runPkill(pattern: "libexec/engine/splash", signal: "-INT")
        runPkill(pattern: "splash serve", signal: "-INT")
        
        // 3. Wait up to 3 seconds for port to become free
        for _ in 0..<30 {
            if !isPortListening(port: port) { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // 4. Force kill if still lingering
        if isPortListening(port: port) {
            runPkill(pattern: "server.py", signal: "-9")
            runPkill(pattern: "libexec/engine/splash", signal: "-9")
            killProcessesOnPort(port: port)
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        
        // 5. Clean lock file
        if FileManager.default.fileExists(atPath: lockFileURL.path) {
            try? FileManager.default.removeItem(at: lockFileURL)
        }
    }
    
    private func runPkill(pattern: String, signal: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        proc.arguments = [signal, "-f", pattern]
        try? proc.run()
        proc.waitUntilExit()
    }
    
    private func readLockPid() -> Int? {
        guard FileManager.default.fileExists(atPath: lockFileURL.path),
              let data = try? Data(contentsOf: lockFileURL),
              let lock = try? JSONDecoder().decode(ServeLock.self, from: data) else {
            return nil
        }
        return lock.pid
    }
    
    private func killProcessesOnPort(port: Int) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments = ["-ti", ":\(port)"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            let pids = output.components(separatedBy: .whitespacesAndNewlines).compactMap { Int32($0) }
            for p in pids where p > 0 {
                kill(p, SIGKILL)
            }
        }
    }
    
    public func isPortListening(port: Int) -> Bool {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)
        
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }
        
        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.stride))
            }
        }
        return result != 0
    }
    
    public func findSuggestedFreePort(preferred: Int? = nil) -> Int {
        var candidates: [Int] = []
        if let pref = preferred, pref > 1024, pref <= 65535 {
            candidates.append(pref)
        }
        for p in [8000, 8001, 8005, 8008, 8080, 8088, 8888, 9000, 9005] {
            if !candidates.contains(p) {
                candidates.append(p)
            }
        }
        for port in candidates {
            if !isPortListening(port: port) {
                return port
            }
        }
        for p in 8001...8100 {
            if !isPortListening(port: p) {
                return p
            }
        }
        return 8000
    }
    
    public func detectPortConflict(port: Int) -> PortConflictInfo? {
        guard isPortListening(port: port) else { return nil }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments = ["-iTCP:\(port)", "-sTCP:LISTEN", "-t"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let firstLine = output.components(separatedBy: .newlines).first,
              let pid = Int32(firstLine), pid > 0 else {
            return nil
        }
        
        if let currentSplashPid = activePid, Int32(currentSplashPid) == pid {
            return nil
        }
        if let lockPid = readLockPid(), Int32(lockPid) == pid {
            return nil
        }
        
        let psProc = Process()
        psProc.executableURL = URL(fileURLWithPath: "/bin/ps")
        psProc.arguments = ["-p", "\(pid)", "-o", "comm="]
        let psPipe = Pipe()
        psProc.standardOutput = psPipe
        try? psProc.run()
        psProc.waitUntilExit()
        
        let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
        let rawComm = (String(data: psData, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if rawComm.localizedCaseInsensitiveContains("splash") {
            return nil
        }
        
        var friendlyName = (rawComm as NSString).lastPathComponent
        if friendlyName.isEmpty { friendlyName = "Proceso desconocido" }
        
        let suggested = findSuggestedFreePort(preferred: port == 8000 ? 8001 : port + 1)
        return PortConflictInfo(port: port, processName: friendlyName, pid: pid, suggestedPort: suggested)
    }
    
    public func resolvePortConflict(killProcess: Bool) {
        guard let conflict = portConflict else { return }
        let targetPort = conflict.port
        self.portConflict = nil
        if killProcess {
            kill(conflict.pid, SIGKILL)
            usleep(250_000)
            startServer(model: selectedModelForLaunch, port: targetPort)
        } else {
            self.isStartingServer = false
            self.startingModelId = nil
        }
    }
    
    public func useSuggestedPort(_ newPort: Int) {
        self.portConflict = nil
        self.activePort = newPort
        startServer(model: selectedModelForLaunch, port: newPort)
    }
    
    public func ensureSplashLauncherScript() {
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let scriptURL = splashLauncherScriptURL
        let scriptContent = """
        #!/usr/bin/env python3
        \"\"\"
        Splash Bridge Launcher for Splash Monitor.
        Enables dynamic port configuration and seamless agent connectivity.
        \"\"\"
        import sys
        import os

        target_port = 8000
        new_argv = [sys.argv[0]]
        skip_next = False
        for i, arg in enumerate(sys.argv[1:]):
            if skip_next:
                skip_next = False
                continue
            if arg == "--port":
                if i + 2 < len(sys.argv):
                    try:
                        target_port = int(sys.argv[i + 2])
                    except ValueError:
                        pass
                    skip_next = True
                continue
            if arg.startswith("--port="):
                try:
                    target_port = int(arg.split("=", 1)[1])
                except ValueError:
                    pass
                continue
            new_argv.append(arg)

        if "SPLASH_PORT" in os.environ:
            try:
                target_port = int(os.environ["SPLASH_PORT"])
            except ValueError:
                pass

        install_dir = None
        for candidate in [
            "/opt/homebrew/opt/splash/libexec/install",
            "/usr/local/opt/splash/libexec/install",
            "/opt/homebrew/Cellar/splash/1.0/libexec/install",
            "/usr/local/Cellar/splash/1.0/libexec/install"
        ]:
            if os.path.isdir(candidate):
                install_dir = candidate
                break

        if not install_dir:
            os.execv("/opt/homebrew/bin/splash", new_argv)

        sys.path.insert(0, install_dir)
        import launcher

        launcher.PORT = target_port
        launcher.BASE_URL = f"http://127.0.0.1:{target_port}"

        orig_execve = os.execve
        def custom_execve(path, argv, env):
            joined = " ".join(argv)
            if "server/server.py" in joined or "server.py" in joined:
                if "--port" not in argv:
                    argv.extend(["--port", str(target_port)])
            return orig_execve(path, argv, env)

        os.execve = custom_execve
        sys.argv = new_argv
        try:
            sys.exit(launcher.main())
        except SystemExit as e:
            sys.exit(e.code)
        """
        try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }
    
    public func startServer(model: String, port: Int = 8000) {
        guard isSplashInstalled else {
            installSplashDependency()
            return
        }
        
        self.activePort = port
        self.selectedModelForLaunch = model
        
        // 1. Pre-flight check for port conflict with third-party software
        if let conflict = detectPortConflict(port: port) {
            self.portConflict = conflict
            self.isStartingServer = false
            self.startingModelId = nil
            return
        }
        
        self.isStartingServer = true
        self.startingModelId = model
        
        Task {
            // Clean up any stale lock file if the process died
            if let lockPid = self.readLockPid() {
                if kill(Int32(lockPid), 0) != 0 {
                    try? FileManager.default.removeItem(at: self.lockFileURL)
                }
            }
            
            // Ensure any existing splash process on this port is cleared
            await killSplashProcesses(port: port)
            
            let splashPath = self.splashExecutablePath
            let runCmd: String
            if port == 8000 {
                runCmd = "\"\(splashPath)\" serve --model \"\(model)\""
            } else {
                self.ensureSplashLauncherScript()
                let pythonPath = self.splashPythonPath
                let launcherPath = self.splashLauncherScriptURL.path
                runCmd = "\"\(pythonPath)\" \"\(launcherPath)\" serve --model \"\(model)\" --port \"\(port)\""
            }
            
            let cmd = """
            echo "🌊 ==============================================="
            echo "🚀 Iniciando Servidor Splash..."
            echo "📦 Modelo: \(model)"
            echo "🔌 Puerto: \(port)"
            echo "⚡️ Motor:  \(splashPath)"
            echo "==============================================="
            echo "Presiona Ctrl+C en esta ventana para detener el servidor."
            echo ""
            \(runCmd)
            EXIT_CODE=$?
            if [ $EXIT_CODE -ne 0 ]; then
                echo ""
                echo "⚠️ Splash finalizó con código de salida: $EXIT_CODE"
                echo "Presiona Enter para cerrar esta ventana..."
                read -r
            fi
            """
            
            self.runInTerminal(
                command: cmd,
                title: "Splash Server - \(model)",
                scriptFileName: "start_splash.command"
            )
            
            // Poll for up to 30 intervals (24 seconds) to detect server startup
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 800_000_000)
                await self.checkServerStatus()
                if self.isRunning { break }
            }
            
            self.isStartingServer = false
            self.startingModelId = nil
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
        let port = self.activePort
        let agentRunCommand: String
        
        if port == 8000 {
            agentRunCommand = "exec \"\(splashPath)\" \"\(agent)\""
        } else {
            ensureSplashLauncherScript()
            let launcherPath = splashLauncherScriptURL.path
            let pythonPath = splashPythonPath
            agentRunCommand = """
            export ANTHROPIC_BASE_URL="http://127.0.0.1:\(port)"
            export OPENAI_BASE_URL="http://127.0.0.1:\(port)/v1"
            export CUSTOM_BASE_URL="http://127.0.0.1:\(port)/v1"
            export SPLASH_PORT="\(port)"
            exec "\(pythonPath)" "\(launcherPath)" "\(agent)" --port "\(port)"
            """
        }
        
        let cmd = """
        echo "🤖 ==============================================="
        echo "⚡️ Conectando agente \(agent) al servidor Splash..."
        echo "🔌 Puerto: \(port)"
        echo "==============================================="
        echo ""
        \(agentRunCommand)
        """
        runInTerminal(
            command: cmd,
            title: "Splash Agent - \(agent)",
            scriptFileName: "launch_\(agent).command"
        )
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
