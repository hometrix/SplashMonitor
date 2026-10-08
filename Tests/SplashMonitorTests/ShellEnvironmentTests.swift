import XCTest
@testable import SplashMonitor

// MARK: - P-09 / H-09 (consentimiento) y P-13 (política única de entorno)

final class ShellEnvironmentTests: XCTestCase {
    
    func testEnvironmentFileContentsCarryTheActivePort() {
        let contents = ShellEnvironment.fileContents(port: 8005)
        XCTAssertTrue(contents.contains("export SPLASH_PORT=\"8005\""))
        XCTAssertTrue(contents.contains("export ANTHROPIC_BASE_URL=\"http://127.0.0.1:8005\""))
        XCTAssertTrue(contents.contains("export OPENAI_BASE_URL=\"http://127.0.0.1:8005/v1\""))
    }
    
    func testInjectionIsIdempotent() {
        let block = ShellEnvironment.injectionBlock(envFilePath: "/Users/x/.splash_monitor_env")
        let initial = "export PATH=/usr/bin\n"
        XCTAssertTrue(ShellEnvironment.needsInjection(into: initial))
        let once = initial + block
        XCTAssertFalse(ShellEnvironment.needsInjection(into: once))
        XCTAssertEqual(once.components(separatedBy: ShellEnvironment.blockHeader).count - 1, 1,
                       "El encabezado de la inyección debe aparecer una sola vez.")
        // Segunda pasada: `needsInjection` es falso, así que no se vuelve a añadir.
        XCTAssertEqual(once + (ShellEnvironment.needsInjection(into: once) ? block : ""), once)
    }
    
    /// La app escribía en `~/.zshrc` y no sabía deshacerlo. La reversión debe ser exacta.
    func testRemovingInjectionRestoresOriginalFile() throws {
        let original = "export PATH=/usr/bin\nalias ll='ls -la'\n"
        let envPath = "/Users/x/.splash_monitor_env"
        let injected = original + ShellEnvironment.injectionBlock(envFilePath: envPath)
        XCTAssertNotEqual(injected, original)
        XCTAssertEqual(ShellEnvironment.removingInjection(from: injected), original)
        // Idempotente: quitar dos veces no rompe el fichero.
        XCTAssertEqual(ShellEnvironment.removingInjection(from: original), original)
    }
    
    /// P-13: una sola política. Antes, `startServer()` borraba el entorno en 8000
    /// mientras `checkServerStatus()` lo escribía también para 8000.
    func testSyncPolicyIsUniformAcrossPorts() {
        XCTAssertTrue(ShellEnvironment.shouldSync(port: 8000))
        XCTAssertTrue(ShellEnvironment.shouldSync(port: 8005))
        XCTAssertTrue(ShellEnvironment.shouldSync(port: 54321))
        XCTAssertFalse(ShellEnvironment.shouldSync(port: 0))
        XCTAssertFalse(ShellEnvironment.shouldSync(port: 70000))
    }
    
    func testConsentDecisions() {
        XCTAssertEqual(ShellConsent.decide(hasConsent: true, userDeclined: false), .write)
        XCTAssertEqual(ShellConsent.decide(hasConsent: true, userDeclined: true), .write)
        XCTAssertEqual(ShellConsent.decide(hasConsent: false, userDeclined: false), .askUser)
        XCTAssertEqual(ShellConsent.decide(hasConsent: false, userDeclined: true), .skip)
    }
    
    /// El servicio no toca el `~/.zshrc` real: escribe en el directorio inyectado y,
    /// sin consentimiento, deja el aviso pendiente en lugar de modificar el perfil.
    @MainActor
    func testServiceWithoutConsentOnlyWritesEnvironmentFileAndAsks() throws {
        let dir = try TempDirectory()
        let service = SplashService(transport: StubStatusTransport(),
                                    terminator: RecordingServerTerminator(),
                                    pollInterval: 30,
                                    dataDirectoryRoot: dir.url,
                                    bootstrapNetwork: false)
        service.shellEnvironmentDirectory = dir.url
        service.shellConfigConsent = false
        service.shellConfigDeclined = false
        var writtenFiles: [String] = []
        service.shellWriteOverride = { _, url in writtenFiles.append(url.lastPathComponent) }
        
        service.syncShellEnvironment(port: 8005)
        
        XCTAssertTrue(dir.exists(ShellEnvironment.fileName))
        XCTAssertTrue(writtenFiles.isEmpty, "Sin consentimiento no se escribe en ~/.zshrc.")
        XCTAssertEqual(service.pendingShellConfigPort, 8005)
        
        // Con consentimiento: escribe el perfil y deja de preguntar.
        service.resolveShellConfigPrompt(allow: true)
        XCTAssertEqual(writtenFiles, [".zshrc"])
        XCTAssertNil(service.pendingShellConfigPort)
        XCTAssertTrue(service.shellConfigConsent)
        XCTAssertFalse(service.shellConfigDeclined)
        
        // Deshacer: borra el fichero de entorno y revierte la inyección.
        service.clearShellEnvironment()
        XCTAssertFalse(dir.exists(ShellEnvironment.fileName))
    }
    
    @MainActor
    func testSyncCodexEnvironmentUpdatesModelAndBaseURL() throws {
        let dir = try TempDirectory()
        let service = SplashService(transport: StubStatusTransport(),
                                    terminator: RecordingServerTerminator(),
                                    pollInterval: 30,
                                    dataDirectoryRoot: dir.url,
                                    bootstrapNetwork: false)
        service.shellEnvironmentDirectory = dir.url
        
        let codexDir = dir.url.appendingPathComponent(".codex")
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
        let configURL = codexDir.appendingPathComponent("config.toml")
        
        let sampleConfig = """
        model = "incoai/Qwen3.6-35B-A3B-Splash"
        model_context_window = 65536
        openai_base_url = "http://127.0.0.1:8000/v1"
        """
        try sampleConfig.write(to: configURL, atomically: true, encoding: .utf8)
        
        service.syncCodexEnvironment(model: "peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL", port: 8005)
        
        let updated = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(updated.contains("model = \"peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF-MTP:UD-Q4_K_XL\""))
        XCTAssertTrue(updated.contains("openai_base_url = \"http://127.0.0.1:8005/v1\""))
        XCTAssertTrue(updated.contains("model_context_window = 65536"))
    }
}
