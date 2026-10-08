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

    // MARK: - Dependencias inyectables (pruebas y sustitución)
    /// Transporte HTTP para `/status`. Sustituible para probar el ciclo de sondeo sin motor.
    public let transport: StatusTransport
    /// Operaciones destructivas sobre procesos. Las pruebas inyectan un doble que no
    /// envía señales reales.
    public let terminator: ServerTerminating
    /// Intervalo base de sondeo. Las pruebas lo amplían para no depender del reloj.
    public let pollInterval: TimeInterval
    /// Raíz de datos de la app. `nil` = `~/Library/Application Support/Splash`.
    public let dataDirectoryRoot: URL?
    /// Sustituto del lanzamiento real del motor (escritura de `.command` + `/bin/bash`).
    public var serverLaunchOverride: ((_ command: String, _ logFile: URL?, _ background: Bool) -> Void)?
    /// Sustituto de la escritura en el `~/.zshrc` del usuario.
    public var shellWriteOverride: ((_ contents: String, _ url: URL) -> Void)?
    /// Directorio donde vive `~/.splash_monitor_env`. `nil` = directorio personal real.
    /// Las pruebas lo apuntan a un directorio temporal para no escribir en el HOME.
    public var shellEnvironmentDirectory: URL?
    /// Omite la comprobación previa de conflictos de puerto (pruebas herméticas:
    /// evita abrir un socket real y depender del estado de la máquina).
    public var skipPortConflictCheck: Bool = false
    
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
    @AppStorage("runInBackground") public var runInBackground: Bool = true
    @AppStorage("lastUsedPort") public var lastUsedPort: Int = 8000
    @AppStorage("listenOnAllInterfaces") public var listenOnAllInterfaces: Bool = false
    @AppStorage("maxContext") public var maxContext: String = "auto"
    @AppStorage("allowedHosts") public var allowedHosts: String = ""
    @AppStorage("languageOnly") public var languageOnly: Bool = false
    
    /// Dirección IPv4 primaria en la red de área local (ej. "192.168.1.49").
    public var localNetworkIP: String? {
        NetworkInterfaceHelper.primaryLocalIPv4()
    }
    
    /// Host o IP preferida para clientes e integraciones según la configuración activa.
    /// Si `listenOnAllInterfaces` está activo, prioriza el primer dominio permitido configurado
    /// (ej. DDNS como midominio.duckdns.org) o la IP en la red LAN.
    /// En caso contrario, devuelve `127.0.0.1`.
    public var preferredHostOrIP: String {
        if listenOnAllInterfaces {
            let userHosts = allowedHosts
                .components(separatedBy: CharacterSet(charactersIn: ",; \n\t"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if let primaryDomain = userHosts.first {
                return primaryDomain
            }
            if let ip = localNetworkIP {
                return ip
            }
        }
        return "127.0.0.1"
    }
    
    // Update check
    @Published public var hasUpdate: Bool = false
    @Published public var latestVersion: String? = nil
    @Published public var latestReleaseURL: String? = nil
    public let currentVersion = SplashVersion.current
    private let githubRepo = "hometrix/SplashMonitor"
    
    // Agent installation cache (checked async, not on main thread)
    @Published public var installedAgents: Set<String> = []
    
    // Connected Applications & Clients
    @Published public var connectedApps: [ConnectedApp] = []
    private var knownClientsSession: [Int32: ConnectedApp] = [:]
    
    // Timers & Processes
    private var timer: Timer?
    private var watchdog: Timer?
    /// Intervalo del vigía de recuperación cuando el servidor está detenido.
    public var watchdogInterval: TimeInterval { max(5.0, pollInterval * 4) }
    /// Contador para no reescanear el directorio de modelos en cada ciclo (P-12).
    private var ticksSinceModelRefresh = 0
    private var sizeCache = ModelSizeCache()
    private var installProcess: Process?
    private var dependencyProcess: Process?
    
    // Paths
    public let dataDirectory: URL
    
    public var modelsDirectory: URL {
        dataDirectory.appendingPathComponent("models")
    }
    
    public var runtimeDirectory: URL {
        dataDirectory.appendingPathComponent("runtime")
    }
    
    /// Ficheros de bloqueo candidatos, en orden de preferencia (P-08).
    /// El motor 1.0.2 escribe `serve-<puerto>.lock`; `serve.lock` se mantiene como
    /// compatibilidad con versiones anteriores y suele llegar vacío.
    public func lockFileURLs(port: Int) -> [URL] {
        ServeLockStore.candidateFileNames(port: port).map { runtimeDirectory.appendingPathComponent($0) }
    }
    
    /// Ruta histórica; se conserva para depuración y para la limpieza de residuos.
    public var lockFileURL: URL {
        runtimeDirectory.appendingPathComponent("serve.lock")
    }
    
    public var serverLogURL: URL {
        dataDirectory.appendingPathComponent("logs/server.log")
    }
    
    public func readRecentServerLogs(lines: Int = 100) -> String {
        guard let data = try? Data(contentsOf: serverLogURL),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        let allLines = text.components(separatedBy: .newlines)
        let slice = allLines.suffix(lines)
        return slice.joined(separator: "\n")
    }
    
    public var brewExecutablePath: String? {
        SplashPaths.firstExisting(SplashPaths.brewExecutableCandidates())
    }
    
    public var splashExecutablePath: String {
        SplashPaths.firstExisting(SplashPaths.splashExecutableCandidates()) ?? "splash"
    }
    
    public var splashPythonPath: String {
        if let stable = SplashPaths.firstExisting(SplashPaths.pythonCandidates(),
                                                  exists: { FileManager.default.fileExists(atPath: $0) }) {
            return stable
        }
        let versions: (String) -> [String]? = { try? FileManager.default.contentsOfDirectory(atPath: $0) }
        if let cellar = SplashPaths.firstCellarCandidate(subpath: "libexec/python/bin/python3", versions: versions) {
            return cellar
        }
        return "/usr/bin/python3"
    }
    
    public var splashModelsScriptPath: String {
        if let stable = SplashPaths.firstExisting(SplashPaths.modelsScriptCandidates(),
                                                  exists: { FileManager.default.fileExists(atPath: $0) }) {
            return stable
        }
        let versions: (String) -> [String]? = { try? FileManager.default.contentsOfDirectory(atPath: $0) }
        return SplashPaths.firstCellarCandidate(subpath: "libexec/install/models.py", versions: versions) ?? ""
    }
    
    public init(transport: StatusTransport = URLSessionStatusTransport(),
                terminator: ServerTerminating = HardenedServerTerminator(),
                pollInterval: TimeInterval? = nil,
                dataDirectoryRoot: URL? = nil,
                bootstrapNetwork: Bool = true) {
        self.transport = transport
        self.terminator = terminator
        self.dataDirectoryRoot = dataDirectoryRoot
        // El intervalo configurable por el usuario (`@AppStorage("refreshInterval")`)
        // sigue gobernando el sondeo; las pruebas inyectan uno propio.
        let storedInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        let baseInterval = storedInterval > 0 ? storedInterval : 1.5
        self.pollInterval = max(0.5, pollInterval ?? baseInterval)
        self.dataDirectory = dataDirectoryRoot ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Splash")

        self.activePort = lastUsedPort
        checkDependencies()
        startPolling()
        refreshInstalledModels()
        cleanLegacyArtifacts()
        // `bootstrapNetwork: false` evita tráfico real (Hugging Face, GitHub) en las
        // pruebas y en cualquier integración que necesite un arranque hermético.
        if bootstrapNetwork {
            Task {
                await fetchOnlineModels()
                await checkForUpdate()
                refreshAgentAvailability()
            }
        }
    }
    
    // MARK: - Residuos de versiones anteriores (P-17 / H-14)

    /// Elimina restos del *bridge launcher* que se retiró en 1.0.1 pero que sigue en
    /// disco tras actualizar (`~/Library/Application Support/Splash/splash_launcher.py`),
    /// y bloqueos huérfanos del motor.
    public func cleanLegacyArtifacts() {
        let fm = FileManager.default
        let legacyFiles = ["splash_launcher.py"]
        for name in legacyFiles {
            let url = dataDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
            }
        }
        cleanStaleLocks()
    }

    /// Borra bloqueos del motor cuyo PID ya no existe y que superan el margen de
    /// arranque (P-08). No toca bloqueos vivos.
    public func cleanStaleLocks() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: runtimeDirectory,
                                                        includingPropertiesForKeys: [.contentModificationDateKey],
                                                        options: [.skipsHiddenFiles]) else { return }
        for url in entries where url.pathExtension == "lock" {
            let attributes = try? fm.attributesOfItem(atPath: url.path)
            let age = -(attributes?[.modificationDate] as? Date ?? .distantPast).timeIntervalSinceNow
            let data = try? Data(contentsOf: url)
            let lock = ServeLockStore.decode(data)
            let alive = lock.map { kill(Int32($0.pid), 0) == 0 } ?? false
            if ServeLockStore.isStale(lock, pidAlive: alive, age: age) {
                try? fm.removeItem(at: url)
            }
        }
    }
    
    // MARK: - Dependency Management
    
    public func checkDependencies() {
        self.hasHomebrew = brewExecutablePath != nil
        guard let directPath = SplashPaths.firstExisting(SplashPaths.splashExecutableCandidates()) else {
            self.isSplashInstalled = false
            self.splashVersion = nil
            return
        }
        self.isSplashInstalled = true
        // `splash --version` medido en 30-50 ms (motor 1.0.2, M4 Max): coste acotado.
        let result = CommandRunner.run(directPath, ["--version"])
        let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.succeeded, !version.isEmpty {
            self.splashVersion = version.replacingOccurrences(of: "Splash ", with: "v")
                .replacingOccurrences(of: "splash ", with: "v")
        } else {
            self.splashVersion = "v1.0"
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
        watchdog?.invalidate()
        watchdog = nil
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
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

    /// `true` mientras el sondeo periódico está vivo (P-02). Expuesto para las pruebas.
    public var isPollingActive: Bool {
        timer?.isValid ?? false
    }
    
    /// `true` mientras el vigía de recuperación está armado. Expuesto para las pruebas.
    public var isWatchdogActive: Bool {
        watchdog?.isValid ?? false
    }

    /// Vigía de recuperación (P-02).
    ///
    /// Defecto corregido: `stopServerAsync()` invalidaba el temporizador y **ninguna ruta
    /// lo recreaba**, de modo que tras pulsar «Detener Servidor» una vez el panel dejaba
    /// de actualizarse durante el resto de la sesión, y un motor arrancado desde la
    /// terminal nunca se detectaba. Ahora, con el servidor detenido, un vigía lento
    /// comprueba el estado y reconstruye el sondeo en cuanto aparece un motor vivo.
    private func ensureWatchdog() {
        guard watchdog == nil else { return }
        watchdog = Timer.scheduledTimer(withTimeInterval: watchdogInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.watchdogTick()
            }
        }
    }
    
    /// Un ciclo del vigía: comprueba el estado y reconstruye el sondeo si hay motor.
    /// Expuesto para poder probarlo sin depender del reloj.
    public func watchdogTick() async {
        await checkServerStatus()
        if isRunning { restorePollingAfterDetection() }
    }

    /// Reconstruye el sondeo periódico y apaga el vigía.
    public func restorePollingAfterDetection() {
        watchdog?.invalidate()
        watchdog = nil
        if !isPollingActive { startPolling() }
    }
    
    public func checkServerStatus() async {
        // 1. Resolver el bloqueo del motor (serve-<puerto>.lock y compatibilidad con serve.lock)
        var lockPid: Int? = nil
        var lockPort: Int = self.activePort
        var lockModel: String? = nil
        
        for url in lockCandidateURLs() {
            guard let data = try? Data(contentsOf: url),
                  let lock = ServeLockStore.decode(data), lock.pid > 0 else { continue }
            let alive = kill(Int32(lock.pid), 0) == 0
            if alive {
                lockPid = lock.pid
                lockPort = lock.port
                lockModel = lock.model
                break
            }
            // PID muerto: se limpia solo si ya pasó el margen de arranque (P-08).
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let age = -(attributes?[.modificationDate] as? Date ?? .distantPast).timeIntervalSinceNow
            if ServeLockStore.isStale(lock, pidAlive: false, age: age) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        if lockPid != nil {
            self.activePort = lockPort
            if let model = lockModel {
                self.activeModel = model
            }
        }
        self.activePid = lockPid
        
        // 2. Consultar /status a través del transporte inyectable
        if let decoded = await transport.fetchStatus(port: activePort, timeout: 1.0) {
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
            
            // Sync shell env if port changed (e.g. after brew upgrade)
            if self.activePort != self.lastUsedPort {
                self.lastUsedPort = self.activePort
                self.syncShellEnvironment(port: self.activePort)
            }
        } else {
            // Fallback: scan flexible de puertos si no hay bloqueo vivo
            if lockPid == nil {
                await scanAndConnectPort()
            } else {
                self.isRunning = false
                self.status = nil
            }
        }
        
        // Scan active connected apps/clients
        await scanConnectedClients()
        
        // 3. Reescaneo del catálogo local: como mucho una vez cada 10 ciclos (P-12).
        //    El tamaño en disco no cambia entre ciclos y resolver 215 ficheros con
        //    symlinks costaba 7,5 ms de E/S síncrona sobre el @MainActor cada 1,5 s.
        ticksSinceModelRefresh += 1
        if ticksSinceModelRefresh >= 10 || installedModels.isEmpty {
            ticksSinceModelRefresh = 0
            refreshInstalledModels()
        }
    }
    
    /// Ficheros de bloqueo a considerar, priorizando el del puerto activo.
    public func lockCandidateURLs() -> [URL] {
        let fm = FileManager.default
        var urls = lockFileURLs(port: activePort)
        if let entries = try? fm.contentsOfDirectory(at: runtimeDirectory,
                                                     includingPropertiesForKeys: nil,
                                                     options: [.skipsHiddenFiles]) {
            let discovered = entries
                .filter { $0.lastPathComponent.hasPrefix("serve") && $0.pathExtension == "lock" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for url in discovered where !urls.contains(url) {
                urls.append(url)
            }
        }
        return urls
    }
    
    private func scanAndConnectPort() async {
        let portsToTry = [activePort, lastUsedPort, 8000, 8001, 8005, 8008, 8080, 8088, 8888, 9000, 9005]
        var seen = Set<Int>()
        let uniquePorts = portsToTry.filter { seen.insert($0).inserted }
        
        for port in uniquePorts {
            guard let decoded = await transport.fetchStatus(port: port, timeout: 0.8) else { continue }
            self.activePort = port
            self.lastUsedPort = port
            self.syncShellEnvironment(port: port)
            self.status = decoded
            self.isRunning = decoded.ready ?? true
            if let instanceModel = decoded.instance?.model {
                self.activeModel = instanceModel
            }
            if let pid = decoded.instance?.pid {
                self.activePid = pid
            }
            return
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
                    
                    // Tamaño real resolviendo symlinks, con caché por modelo (P-12).
                    // La clave incluye la fecha de modificación del enlace: al reinstalar
                    // o actualizar un modelo el valor se recalcula solo.
                    let stamp = (try? modelURL.resourceValues(forKeys: [.contentModificationDateKey]))?
                        .contentModificationDate
                    let size = sizeCache.size(repoId: repoId, stamp: stamp) {
                        Self.directorySize(url: modelURL)
                    }
                    
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
    
    /// Suma el tamaño real de un árbol resolviendo enlaces simbólicos.
    /// `nonisolated` para poder invocarse desde trabajo en segundo plano.
    nonisolated public static func directorySize(url: URL) -> Int64 {
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
        // El identificador llega de la interfaz y se usa como ruta: sin validar,
        // un valor como `../../..` borraba fuera del directorio de modelos.
        guard ModelIDValidator.isValid(repoId) else {
            self.lastError = "Identificador de modelo no válido: \(repoId)"
            return
        }
        let symlinkURL = modelsDirectory.appendingPathComponent(repoId)
        let fm = FileManager.default
        do {
            if repoId == activeModel && isRunning {
                stopServer()
            }
            if fm.fileExists(atPath: symlinkURL.path) {
                try fm.removeItem(at: symlinkURL)
            }
            sizeCache.invalidate(repoId: repoId)
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
    
    public func checkForUpdate() async {
        guard let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5.0
        
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else { return }
        
        // Extract version number: "v1.0.2-beta" → "1.0.2-beta"
        let latest = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        
        // Comparación semántica (P-07). El código anterior usaba `String >`
        // (lexicográfico), que consideraba `1.0.10-beta` anterior a `1.0.2-beta` y
        // dejaba de anunciar actualizaciones a partir de la décima revisión.
        if SemanticVersion.isNewer(latest, than: currentVersion) {
            self.hasUpdate = true
            self.latestVersion = tagName
            self.latestReleaseURL = json["html_url"] as? String ?? "https://github.com/\(githubRepo)/releases/latest"
        } else {
            self.hasUpdate = false
            self.latestVersion = tagName
        }
    }
    
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
    
    public func installModel(repoId: String, languageOnly: Bool? = nil) {
        guard !isInstalling else { return }
        guard ModelIDValidator.isValid(repoId) else {
            self.lastError = ModelIDValidator.rejectionReason(repoId) ?? "Identificador de modelo no válido."
            return
        }
        isInstalling = true
        installingModelId = repoId
        let initialLangOnly = languageOnly ?? (repoId.lowercased().contains("coder") || repoId.lowercased().contains("code"))
        installLogs = ["Iniciando descarga y preparación para \(repoId)..."]
        if initialLangOnly {
            installLogs.append("ℹ️ Modo solo texto / código (--language-only) activado.")
        }
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
            
            func runPrepareProcess(withLanguageOnly: Bool) -> (success: Bool, logs: [String]) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                var args = ["-u", scriptPath, "--models", modelsPath, "--model", repoId]
                if withLanguageOnly {
                    args.append("--language-only")
                }
                args.append("prepare")
                process.arguments = args
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                final class LogCollector: @unchecked Sendable {
                    private let lock = NSLock()
                    private var logs: [String] = []
                    func append(_ lines: [String]) {
                        lock.lock()
                        logs.append(contentsOf: lines)
                        lock.unlock()
                    }
                    func getLogs() -> [String] {
                        lock.lock()
                        defer { lock.unlock() }
                        return logs
                    }
                }
                
                let collector = LogCollector()
                
                let outHandle = pipe.fileHandleForReading
                outHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                    let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    collector.append(lines)
                    Task { @MainActor in
                        for line in lines {
                            self.installLogs.append(line)
                        }
                    }
                }
                
                Task { @MainActor in
                    self.installProcess = process
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    outHandle.readabilityHandler = nil
                    return (process.terminationStatus == 0, collector.getLogs())
                } catch {
                    outHandle.readabilityHandler = nil
                    return (false, collector.getLogs())
                }
            }
            
            var (success, logs) = runPrepareProcess(withLanguageOnly: initialLangOnly)
            
            // Auto-fallback: Si falló porque no tiene proyector mmproj y no se había usado languageOnly, reintentar con --language-only
            if !success && !initialLangOnly {
                let joinedLogs = logs.joined(separator: " ").lowercased()
                if joinedLogs.contains("vision projector") || joinedLogs.contains("mmproj") || joinedLogs.contains("--language-only") {
                    await MainActor.run {
                        self.installLogs.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        self.installLogs.append("ℹ️ Detectado modelo de código/texto sin proyector de visión (mmproj).")
                        self.installLogs.append("🔄 Reintentando preparación automáticamente con --language-only...")
                        self.installLogs.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    }
                    let secondPass = runPrepareProcess(withLanguageOnly: true)
                    success = secondPass.success
                }
            }
            
            let finalSuccess = success
            await MainActor.run {
                self.installProcess = nil
                self.isInstalling = false
                self.installSuccess = finalSuccess
                if finalSuccess {
                    self.installLogs.append("✅ Instalación y verificación de \(repoId) completada con éxito.")
                    self.refreshInstalledModels()
                } else {
                    self.installLogs.append("❌ Error al instalar \(repoId).")
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
        await terminator.stopEngine(port: activePort, candidatePids: candidateStopPIDs())
        self.isRunning = false
        self.status = nil
        self.activePid = nil
        self.speedHistory.removeAll()
        timer?.invalidate()
        // P-02: el sondeo no puede quedar muerto. Se deja un vigía lento que detecta
        // cualquier motor que arranque después (desde la app, la terminal o un agente).
        ensureWatchdog()
        cleanStaleLocks()
    }
    
    public func stopServer() {
        Task {
            await stopServerAsync()
        }
    }
    
    /// Detención síncrona para `applicationWillTerminate` (sin async, sin Task).
    /// Solo señaliza procesos verificados como motor (P-01): antes ejecutaba
    /// `pkill -INT -f "splash serve"`, que alcanza cualquier proceso cuya línea de
    /// comandos contenga esa cadena, y después aplicaba `SIGKILL` a todo lo que
    /// `lsof -ti :<puerto>` devolviese, incluidos los clientes conectados.
    public func stopServerSync() {
        terminator.stopEngineSynchronously(port: activePort, candidatePids: candidateStopPIDs())
        for url in lockFileURLs(port: activePort) where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    /// Reset all published state — releases memory
    public func resetState() {
        speedHistory.removeAll()
        status = nil
        isRunning = false
        activePid = nil
        installedModels.removeAll()
        availableOnlineModels.removeAll()
        installedAgents.removeAll()
        connectedApps.removeAll()
        knownClientsSession.removeAll()
        lastError = nil
        isStartingServer = false
        startingModelId = nil
        isInstalling = false
        installingModelId = nil
        installLogs.removeAll()
        installSuccess = nil
        isInstallingDependency = false
        dependencyInstallLogs.removeAll()
        dependencyInstallSuccess = nil
        portConflict = nil
        timer?.invalidate()
        watchdog?.invalidate()
        watchdog = nil
        sizeCache.invalidateAll()
        ticksSinceModelRefresh = 0
    }
    
    /// Detiene el motor del puerto indicado. Delega en el terminador endurecido:
    /// solo escuchas verificadas del motor y escalada INT → TERM → KILL.
    public func killSplashProcesses(port: Int) async {
        await terminator.stopEngine(port: port, candidatePids: candidateStopPIDs())
    }
    
    /// PIDs candidatos a detener: el proceso activo y los declarados por bloqueos vivos.
    /// Nunca se amplía con «todo lo que escuche en el puerto».
    public func candidateStopPIDs() -> [Int32] {
        var pids: [Int32] = []
        if let pid = activePid, pid > 0 { pids.append(Int32(pid)) }
        for url in lockCandidateURLs() {
            guard let lock = ServeLockStore.decode(try? Data(contentsOf: url)), lock.pid > 0 else { continue }
            pids.append(Int32(lock.pid))
        }
        return pids
    }
    
    /// PID declarado por el bloqueo vivo del motor, si existe (P-08).
    public func readLockPid() -> Int? {
        for url in lockCandidateURLs() {
            guard let lock = ServeLockStore.decode(try? Data(contentsOf: url)), lock.pid > 0 else { continue }
            if kill(Int32(lock.pid), 0) == 0 { return lock.pid }
        }
        return nil
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
            // Reverificación de identidad antes de señalizar: entre la detección y la
            // confirmación del usuario el PID puede haberse reciclado por otro proceso
            // (incluido el propio motor). `SIGTERM` primero; `SIGKILL` solo si persiste.
            let comm = CommandRunner.run("/bin/ps", ["-p", "\(conflict.pid)", "-o", "comm="])
                .output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !SplashEngineIdentity.isEngineCommand(comm) {
                kill(conflict.pid, SIGTERM)
                usleep(250_000)
                if kill(conflict.pid, 0) == 0 {
                    kill(conflict.pid, SIGKILL)
                }
            }
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
    
    public func startServer(model: String, port: Int = 8000) {
        guard isSplashInstalled else {
            installSplashDependency()
            return
        }
        
        // P-03: el identificador de modelo se interpola dentro de un script de shell.
        // Sin validación, un valor con comillas cerraba el entrecomillado y ejecutaba
        // comandos arbitrarios (verificado en la auditoría con un fichero testigo).
        guard let validatedModel = ModelIDValidator.normalized(model) else {
            self.lastError = ModelIDValidator.rejectionReason(model) ?? "Identificador de modelo no válido."
            self.isStartingServer = false
            self.startingModelId = nil
            return
        }
        guard (1...65535).contains(port) else {
            self.lastError = "Puerto fuera de rango: \(port)"
            self.isStartingServer = false
            self.startingModelId = nil
            return
        }
        
        self.activePort = port
        self.lastUsedPort = port
        self.selectedModelForLaunch = model
        
        // 1. Pre-flight check for port conflict with third-party software
        if !skipPortConflictCheck, let conflict = detectPortConflict(port: port) {
            self.portConflict = conflict
            self.isStartingServer = false
            self.startingModelId = nil
            return
        }
        
        self.isStartingServer = true
        self.startingModelId = validatedModel
        
        Task {
            // Limpieza de bloqueos muertos antes de arrancar (P-08).
            self.cleanStaleLocks()
            
            // Ensure any existing splash process on this port is cleared
            await killSplashProcesses(port: port)
            
            let splashPath = self.splashExecutablePath
            
            // Aliases de modelos Anthropic, OpenAI y de la familia Splash/IncoAI
            let baseModelAliases = [
                // Familia IncoAI / Splash (resuelve clientes configurados con modelos nativos de Splash)
                "incoai/Qwen3.6-35B-A3B-Splash",
                "incoai/Qwen3.8-27B-Splash",
                "incoai/Qwen3.5-35B-A3B-Splash",
                "incoai/Qwen2.5-Coder-32B-Instruct",
                "Qwen3.6-35B-A3B-Splash",
                "Qwen3.8-27B-Splash",
                // Familia OpenAI & ChatGPT (Desktop Codex / OWL, Chatbox, Cursor)
                "gpt-4o",
                "gpt-4o-mini",
                "gpt-4",
                "gpt-4-turbo",
                "gpt-3.5-turbo",
                "o1",
                "o1-preview",
                "o1-mini",
                "o3-mini",
                "codex",
                "chatgpt",
                "default",
                // Familia Sonnet (Pestaña Code / CCD y Cowork)
                "claude-sonnet-4-6",
                "claude-sonnet-5",
                "claude-sonnet-5-5",
                "claude-sonnet-4-5",
                "claude-3-7-sonnet-latest",
                "claude-3-7-sonnet-20250219",
                "claude-3-5-sonnet-latest",
                "claude-3-5-sonnet-20241022",
                "claude-3-5-sonnet-20240620",
                // Familia Haiku
                "claude-haiku-4-5",
                "claude-haiku-4-5-20251001",
                "claude-3-5-haiku-latest",
                "claude-3-5-haiku-20241022",
                "claude-3-haiku-20240307",
                // Familia Opus
                "claude-opus-4-7",
                "claude-opus-5",
                "claude-opus-5-5",
                "claude-3-opus-latest",
                "claude-3-opus-20240229",
                // Familia Fable
                "claude-fable-5",
                "claude-fable-5-1"
            ]
            
            var allAliases = Set(baseModelAliases)
            let codexConfigURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/config.toml")
            if let configData = try? String(contentsOf: codexConfigURL, encoding: .utf8) {
                for line in configData.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("model") && trimmed.contains("=") {
                        let parts = trimmed.split(separator: "=", maxSplits: 1).map { String($0) }
                        if parts.count == 2 {
                            let val = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                            if !val.isEmpty {
                                allAliases.insert(val)
                            }
                        }
                    }
                }
            }
            
            let aliasFlags = allAliases
                .filter { $0 != validatedModel }
                .sorted()
                .map { "--served-model-name \"\($0)\"" }
                .joined(separator: " ")
            
            // Opciones de red, allowed-hosts y contexto (--host, --allowed-host y --max-context)
            let hostFlag = self.listenOnAllInterfaces ? "--host \"0.0.0.0\"" : "--host \"127.0.0.1\""
            
            var allowedHostFlags = ""
            var parsedAllowedHosts: [String] = []
            if self.listenOnAllInterfaces {
                let userHosts = self.allowedHosts
                    .components(separatedBy: CharacterSet(charactersIn: ",; \n\t"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
                
                let hostAllowedChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-_")
                for host in userHosts where host.unicodeScalars.allSatisfy({ hostAllowedChars.contains($0) }) {
                    if !parsedAllowedHosts.contains(host) {
                        parsedAllowedHosts.append(host)
                    }
                }
                
                if !parsedAllowedHosts.isEmpty {
                    allowedHostFlags = parsedAllowedHosts.map { "--allowed-host \"\($0)\"" }.joined(separator: " ")
                }
            }
            
            var contextFlag = ""
            let trimmedContext = self.maxContext.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedContext.isEmpty && trimmedContext.lowercased() != "auto" {
                let allowedChars = CharacterSet(charactersIn: "0123456789kmKM")
                if trimmedContext.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) {
                    contextFlag = "--max-context \"\(trimmedContext.uppercased())\""
                }
            }
            
            let languageFlag = self.languageOnly ? "--language-only" : ""
            let extraOptions = [hostFlag, allowedHostFlags, contextFlag, languageFlag].filter { !$0.isEmpty }.joined(separator: " ")
            let runCmd = "\"\(splashPath)\" serve --model \"\(validatedModel)\" --port \"\(port)\" \(extraOptions) \(aliasFlags)"
            
            let hostLabel = self.listenOnAllInterfaces ? "0.0.0.0 (Toda la red local / LAN)" : "127.0.0.1 (Solo localhost)"
            let contextLabel = (trimmedContext.isEmpty || trimmedContext.lowercased() == "auto") ? "Automático (por memoria)" : trimmedContext.uppercased()
            let modalityLabel = self.languageOnly ? "Solo Texto / Código (--language-only)" : "Multimodal (Texto y Visión)"
            let allowedHostsEcho = parsedAllowedHosts.isEmpty ? "" : "\necho \"🛡️ Dominios: \(parsedAllowedHosts.joined(separator: ", "))\""
            
            let cmd = """
            echo "🌊 ==============================================="
            echo "🚀 Iniciando Servidor Splash..."
            echo "📦 Modelo:   \(validatedModel)"
            echo "🔌 Puerto:   \(port)"
            echo "🌐 Red/Host: \(hostLabel)"\(allowedHostsEcho)
            echo "🧠 Contexto: \(contextLabel)"
            echo "👁️ Modalidad: \(modalityLabel)"
            echo "⚡️ Motor:    \(splashPath)"
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
            
            if let override = self.serverLaunchOverride {
                let logURL = self.runInBackground ? self.serverLogURL : nil
                override(cmd, logURL, self.runInBackground)
            } else if self.runInBackground {
                let logsDir = self.dataDirectory.appendingPathComponent("logs")
                try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
                let logFileURL = self.serverLogURL
                
                let scriptURL = self.dataDirectory.appendingPathComponent("start_splash.command")
                let fullScript = """
                #!/bin/bash
                \(cmd)
                """
                try? fullScript.write(to: scriptURL, atomically: true, encoding: .utf8)
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
                
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/bash")
                proc.arguments = ["-c", "\"\(scriptURL.path)\" > \"\(logFileURL.path)\" 2>&1 &"]
                try? proc.run()
                proc.waitUntilExit()
            } else {
                self.runInTerminal(
                    command: cmd,
                    title: "Splash Server - \(validatedModel)",
                    scriptFileName: "start_splash.command"
                )
            }
            
            // Poll for up to 30 intervals (24 seconds) to detect server startup
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 800_000_000)
                await self.checkServerStatus()
                if self.isRunning { break }
            }
            
            // P-13: política única de entorno — se sincroniza SIEMPRE, también en 8000,
            // porque los agentes de terminal necesitan SPLASH_PORT/ANTHROPIC_BASE_URL.
            // Antes esta ruta borraba el entorno en 8000 mientras checkServerStatus() lo
            // escribía para el mismo puerto: dos reglas opuestas.
            if self.isRunning {
                self.syncShellEnvironment(port: port)
                self.restorePollingAfterDetection()
            } else {
                // El motor no confirmó: mantener la app sensible a un arranque tardío (P-02).
                self.ensureWatchdog()
            }
            
            self.isStartingServer = false
            self.startingModelId = nil
        }
    }
    
    public func switchModel(to model: String) {
        // Si el modelo y puerto son los mismos, solo reiniciar
        // Si el puerto cambió, reiniciar con el nuevo puerto
        startServer(model: model, port: activePort)
    }
    
    // MARK: - Shell Environment Sync
    
    /// Escribe `SPLASH_PORT` y las URL base del motor en `~/.splash_monitor_env` y añade
    /// el `source` a `~/.zshrc`.
    ///
    /// P-09: escribir fuera del directorio de datos exige consentimiento explícito.
    /// Antes la app modificaba `~/.zshrc` sin avisar y solo se podía deshacer a mano.
    /// P-13: política única — el entorno se sincroniza siempre (también en 8000).
    @Published public var pendingShellConfigPort: Int?
    
    /// Consentimiento para modificar `~/.zshrc`, persistido entre sesiones.
    public var shellConfigConsent: Bool {
        get { UserDefaults.standard.bool(forKey: "shellConfigConsent") }
        set {
            UserDefaults.standard.set(newValue, forKey: "shellConfigConsent")
            objectWillChange.send()
        }
    }
    
    /// El usuario rechazó la escritura: no se vuelve a preguntar.
    public var shellConfigDeclined: Bool {
        get { UserDefaults.standard.bool(forKey: "shellConfigDeclined") }
        set {
            UserDefaults.standard.set(newValue, forKey: "shellConfigDeclined")
            objectWillChange.send()
        }
    }
    
    public func syncShellEnvironment(port: Int) {
        guard ShellEnvironment.shouldSync(port: port) else { return }
        let home = shellEnvironmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        let envFile = home.appendingPathComponent(ShellEnvironment.fileName)
        try? ShellEnvironment.fileContents(port: port).write(to: envFile, atomically: true, encoding: .utf8)
        
        switch ShellConsent.decide(hasConsent: shellConfigConsent, userDeclined: shellConfigDeclined) {
        case .write:
            injectShellSource(envFile: envFile)
        case .askUser:
            // La interfaz muestra el aviso; el fichero de entorno ya está escrito.
            if pendingShellConfigPort != port { pendingShellConfigPort = port }
        case .skip:
            break
        }
    }
    
    /// Añade la línea `source` a `~/.zshrc` si no está ya (idempotente).
    public func injectShellSource(envFile: URL) {
        let home = shellEnvironmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        let zshrc = home.appendingPathComponent(".zshrc")
        let contents = (try? String(contentsOf: zshrc, encoding: .utf8)) ?? ""
        guard ShellEnvironment.needsInjection(into: contents) else { return }
        let updated = contents + ShellEnvironment.injectionBlock(envFilePath: envFile.path)
        if let override = shellWriteOverride {
            override(updated, zshrc)
        } else {
            try? updated.write(to: zshrc, atomically: true, encoding: .utf8)
        }
    }
    
    /// Respuesta del usuario al aviso de configuración del shell (P-09).
    public func resolveShellConfigPrompt(allow: Bool) {
        shellConfigConsent = allow
        shellConfigDeclined = !allow
        guard allow, let port = pendingShellConfigPort else {
            pendingShellConfigPort = nil
            return
        }
        pendingShellConfigPort = nil
        let envFile = (shellEnvironmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser)
            .appendingPathComponent(ShellEnvironment.fileName)
        try? ShellEnvironment.fileContents(port: port).write(to: envFile, atomically: true, encoding: .utf8)
        injectShellSource(envFile: envFile)
    }
    
    /// Revierte por completo el efecto de `syncShellEnvironment`: quita la inyección de
    /// `~/.zshrc` (reversión exacta, no heurística) y borra el fichero de entorno.
    public func clearShellEnvironment() {
        let home = shellEnvironmentDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        let envFile = home.appendingPathComponent(ShellEnvironment.fileName)
        let zshrc = home.appendingPathComponent(".zshrc")
        if let contents = try? String(contentsOf: zshrc, encoding: .utf8) {
            let cleaned = ShellEnvironment.removingInjection(from: contents)
            if cleaned != contents {
                if let override = shellWriteOverride {
                    override(cleaned, zshrc)
                } else {
                    try? cleaned.write(to: zshrc, atomically: true, encoding: .utf8)
                }
            }
        }
        try? FileManager.default.removeItem(at: envFile)
    }
    
    // MARK: - Agent Launcher Helpers
    
    /// Fast check using filesystem only — no Process, no blocking
    public func isAgentInstalled(agent: String) -> Bool {
        if agent == "claude-cowork" {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return installedAgents.contains("claude-cowork")
                || FileManager.default.fileExists(atPath: "/Applications/Claude.app")
                || FileManager.default.fileExists(atPath: "\(home)/Applications/Claude.app")
        }
        if agent == "chatgpt" {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return installedAgents.contains("chatgpt")
                || FileManager.default.fileExists(atPath: "/Applications/ChatGPT.app")
                || FileManager.default.fileExists(atPath: "\(home)/Applications/ChatGPT.app")
        }
        return installedAgents.contains(agent)
    }
    
    /// Background check — safe to call from any thread
    public func refreshAgentAvailability() {
        let agents = ["claude", "opencode", "codex", "hermes"]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        
        Task.detached(priority: .utility) {
            var found = Set<String>()
            for agent in agents {
                let candidates = [
                    "/opt/homebrew/bin/\(agent)",
                    "/usr/local/bin/\(agent)",
                    "/usr/bin/\(agent)",
                    "\(home)/.npm-global/bin/\(agent)",
                    "\(home)/.cargo/bin/\(agent)",
                    "\(home)/.local/bin/\(agent)"
                ]
                if candidates.contains(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
                    found.insert(agent)
                }
            }
            // Detección de Claude Desktop / Cowork en macOS
            if FileManager.default.fileExists(atPath: "/Applications/Claude.app") ||
               FileManager.default.fileExists(atPath: "\(home)/Applications/Claude.app") {
                found.insert("claude-cowork")
            }
            // Detección de ChatGPT Desktop / Codex en macOS
            if FileManager.default.fileExists(atPath: "/Applications/ChatGPT.app") ||
               FileManager.default.fileExists(atPath: "\(home)/Applications/ChatGPT.app") {
                found.insert("chatgpt")
            }
            let result = found
            await MainActor.run {
                self.installedAgents = result
            }
        }
    }
    
    public func agentInstallURL(agent: String) -> URL {
        switch agent {
        case "claude":
            return URL(string: "https://code.claude.com/docs/en/overview")!
        case "claude-cowork":
            return URL(string: "https://claude.ai/download")!
        case "chatgpt":
            return URL(string: "https://openai.com/chatgpt/download/")!
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
    
    /// Agentes que el motor sabe lanzar (`splash <agente>` o app nativa para cowork/chatgpt).
    public static let supportedAgents = ["claude", "claude-cowork", "opencode", "codex", "hermes", "chatgpt"]
    
    public func launchAgent(agent: String) {
        guard isSplashInstalled else {
            installSplashDependency()
            return
        }
        // El nombre del agente se restringe a la lista soportada por el motor.
        guard Self.supportedAgents.contains(agent) else {
            self.lastError = "Agente no soportado: \(agent)"
            return
        }
        
        // Manejo específico para Claude Desktop / Cowork (App GUI macOS)
        if agent == "claude-cowork" {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let appURL = [
                URL(fileURLWithPath: "/Applications/Claude.app"),
                URL(fileURLWithPath: "\(home)/Applications/Claude.app")
            ].first(where: { FileManager.default.fileExists(atPath: $0.path) })
            
            if let targetURL = appURL {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: targetURL, configuration: config) { _, error in
                    if let error = error {
                        Task { @MainActor in
                            self.lastError = "Error al abrir Claude Cowork: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                _ = CommandRunner.run("/usr/bin/open", ["-a", "Claude"])
            }
            return
        }
        
        // Manejo específico para ChatGPT Desktop / Codex (App GUI macOS)
        if agent == "chatgpt" {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let appURL = [
                URL(fileURLWithPath: "/Applications/ChatGPT.app"),
                URL(fileURLWithPath: "\(home)/Applications/ChatGPT.app")
            ].first(where: { FileManager.default.fileExists(atPath: $0.path) })
            
            if let targetURL = appURL {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: targetURL, configuration: config) { _, error in
                    if let error = error {
                        Task { @MainActor in
                            self.lastError = "Error al abrir ChatGPT: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                _ = CommandRunner.run("/usr/bin/open", ["-a", "ChatGPT"])
            }
            return
        }
        
        let splashPath = splashExecutablePath
        let port = self.activePort
        // SIEMPRE configurar env vars con el puerto activo
        let agentRunCommand = """
        export SPLASH_PORT="\(port)"
        export ANTHROPIC_BASE_URL="http://127.0.0.1:\(port)"
        export OPENAI_BASE_URL="http://127.0.0.1:\(port)/v1"
        export CUSTOM_BASE_URL="http://127.0.0.1:\(port)/v1"
        exec "\(splashPath)" "\(agent)"
        """
        
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
    
    // MARK: - Connected Apps / Client Detection
    
    public func scanConnectedClients() async {
        guard isRunning else {
            if !connectedApps.isEmpty {
                self.connectedApps = []
                self.knownClientsSession.removeAll()
            }
            return
        }
        
        let port = self.activePort
        let serverPid = self.activePid
        
        // Solo la inspección de sockets sale del actor principal y devuelve texto
        // (`String` es Sendable). La consulta a AppKit (`NSRunningApplication`) se hace
        // después, ya en el actor principal: Swift 6 exige Sendable para cruzar actores y
        // las API de AppKit no deben usarse desde hilos en segundo plano.
        let listing = await Task.detached(priority: .utility) {
            CommandRunner.run("/usr/sbin/lsof",
                              ["-iTCP:\(port)", "-sTCP:ESTABLISHED", "-n", "-P"]).output
        }.value
        
        var pidConnections: [Int32: (name: String, count: Int, remote: String)] = [:]
        var lanConnections: [String: (count: Int, remote: String)] = [:]
        let localLANIP = self.localNetworkIP
        
        // Parser puro y comprobado (`ListerOutput`) en lugar del bucle en línea.
        for connection in ListerOutput.establishedConnections(listing) {
            let pid = connection.pid
            let comm = connection.command
            
            let isServer = (serverPid != nil && Int32(serverPid!) == pid) || SplashEngineIdentity.isEngineCommand(comm)
            
            // Si la conexión pertenece al proceso del servidor Splash, inspeccionar si proviene de un cliente remoto de la LAN
            if isServer {
                let parts = connection.remoteAddress.components(separatedBy: "->")
                let remoteTarget = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let remoteIP = remoteTarget.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if !remoteIP.isEmpty &&
                   remoteIP != "127.0.0.1" &&
                   remoteIP != "::1" &&
                   remoteIP != "localhost" &&
                   remoteIP != localLANIP {
                    if let existing = lanConnections[remoteIP] {
                        lanConnections[remoteIP] = (count: existing.count + 1, remote: remoteTarget)
                    } else {
                        lanConnections[remoteIP] = (count: 1, remote: remoteTarget)
                    }
                }
                continue
            }
            
            // Filter out Splash's internal engine or python if under a different PID
            if comm.localizedCaseInsensitiveContains("splash") && !comm.localizedCaseInsensitiveContains("claude") {
                continue
            }
            
            if let existing = pidConnections[pid] {
                pidConnections[pid] = (name: existing.name, count: existing.count + 1, remote: existing.remote)
            } else {
                pidConnections[pid] = (name: comm, count: 1, remote: connection.remoteAddress)
            }
        }
        
        var detected: [ConnectedApp] = []
        
        // Clientes remotos conectados a través de la red de área local (LAN)
        for (remoteIP, info) in lanConnections {
            let syntheticPid = Int32(abs(remoteIP.hashValue % 100000) + 900000)
            let app = ConnectedApp(
                pid: syntheticPid,
                name: "Cliente LAN (\(remoteIP))",
                bundleId: nil,
                executablePath: nil,
                category: .lanClient,
                icon: NSImage(systemSymbolName: "network", accessibilityDescription: "LAN"),
                connectionCount: info.count,
                status: .active,
                firstConnected: Date(),
                lastSeen: Date(),
                remoteAddress: info.remote
            )
            detected.append(app)
        }
        
        for (pid, info) in pidConnections {
            let runningApp = NSRunningApplication(processIdentifier: pid)
            var appName = runningApp?.localizedName ?? info.name
            let bundleId = runningApp?.bundleIdentifier
            let icon = runningApp?.icon
            let execPath = runningApp?.executableURL?.path
            
            let lowerName = appName.lowercased()
            let lowerComm = info.name.lowercased()
            let category: AppCategory
            
            if bundleId == "com.anthropic.claudefordesktop" || (lowerName == "claude" && execPath?.contains("Claude.app") == true) {
                appName = "Claude Desktop / Cowork"
                category = .codingAgent
            } else if bundleId == "com.openai.codex" || bundleId == "com.openai.chat" || lowerName == "chatgpt" || execPath?.contains("ChatGPT.app") == true {
                appName = "ChatGPT Desktop (Codex)"
                category = .codingAgent
            } else if lowerName.contains("cursor") || lowerName.contains("code") || lowerName.contains("xcode") || lowerName.contains("zed") || lowerName.contains("studio") || lowerName.contains("intellij") || lowerName.contains("pycharm") {
                category = .ide
            } else if lowerComm.contains("claude") || lowerComm.contains("opencode") || lowerComm.contains("hermes") || lowerComm.contains("codex") || lowerComm.contains("aider") {
                category = .codingAgent
            } else if lowerName.contains("chat") || lowerName.contains("webui") || lowerName.contains("lmstudio") || lowerName.contains("ollama") || lowerName.contains("nextchat") {
                category = .chatbot
            } else if lowerName.contains("terminal") || lowerName.contains("iterm") || lowerName.contains("warp") || lowerName.contains("kitty") || lowerName.contains("alacritty") {
                category = .terminal
            } else {
                category = .customScript
            }
            
            let app = ConnectedApp(
                pid: pid,
                name: appName,
                bundleId: bundleId,
                executablePath: execPath,
                category: category,
                icon: icon,
                connectionCount: info.count,
                status: .active,
                firstConnected: Date(),
                lastSeen: Date(),
                remoteAddress: info.remote
            )
            detected.append(app)
        }
        
        let now = Date()
        var updatedList: [ConnectedApp] = []
        var activePids = Set<Int32>()
        
        for var detectedApp in detected {
            activePids.insert(detectedApp.pid)
            if let existing = knownClientsSession[detectedApp.pid] {
                detectedApp.firstConnected = existing.firstConnected
            }
            detectedApp.lastSeen = now
            detectedApp.status = .active
            knownClientsSession[detectedApp.pid] = detectedApp
            updatedList.append(detectedApp)
        }
        
        for (pid, var cachedApp) in knownClientsSession {
            if !activePids.contains(pid) {
                let elapsed = now.timeIntervalSince(cachedApp.lastSeen)
                if elapsed < 60.0 {
                    cachedApp.status = .recent
                    cachedApp.connectionCount = 0
                    updatedList.append(cachedApp)
                } else {
                    knownClientsSession.removeValue(forKey: pid)
                }
            }
        }
        
        self.connectedApps = updatedList.sorted { 
            if $0.status == .active && $1.status != .active { return true }
            if $0.status != .active && $1.status == .active { return false }
            return $0.lastSeen > $1.lastSeen
        }
    }
    
    public func activateApp(app: ConnectedApp) {
        if let running = NSRunningApplication(processIdentifier: app.pid) {
            running.activate(options: .activateIgnoringOtherApps)
        }
    }
    
    public func revealAppInFinder(app: ConnectedApp) {
        if let path = app.executablePath, FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        } else if let bundle = app.bundleId,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }
    
    /// Termina la aplicación cliente indicada.
    ///
    /// P-04 / H-05: la interfaz pide confirmación y aquí se reverifica la identidad
    /// antes de señalizar. Antes se enviaba `SIGTERM` al PID registrado sin comprobar
    /// que siguiera siendo la misma aplicación (un PID reciclado apuntaba a otro
    /// proceso) y sin distinguir las apps del propio monitor.
    /// - Returns: `true` si la aplicación fue terminada.
    @discardableResult
    public func terminateApp(app: ConnectedApp) -> Bool {
        let running = NSRunningApplication(processIdentifier: app.pid)
        let allowed = ClientTerminationPolicy.canTerminate(
            pid: app.pid,
            recordedBundleID: app.bundleId,
            currentBundleID: running?.bundleIdentifier,
            currentName: running?.localizedName,
            isRunning: running != nil,
            ownBundleID: Bundle.main.bundleIdentifier
        )
        knownClientsSession.removeValue(forKey: app.pid)
        guard allowed, let running else { return false }
        running.terminate()
        self.connectedApps.removeAll(where: { $0.pid == app.pid })
        return true
    }
}
