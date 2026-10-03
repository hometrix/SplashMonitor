import XCTest
@testable import SplashMonitor

@MainActor
final class ServerOptionsTests: XCTestCase {
    
    private let testPort = 58921
    
    private func makeService(directory: URL) -> (SplashService, Box<String?>) {
        let capturedCommand = Box<String?>(nil)
        let service = SplashService(transport: StubStatusTransport(),
                                    terminator: RecordingServerTerminator(),
                                    pollInterval: 60,
                                    dataDirectoryRoot: directory,
                                    bootstrapNetwork: false)
        service.shellEnvironmentDirectory = directory
        service.skipPortConflictCheck = true
        service.isSplashInstalled = true
        service.serverLaunchOverride = { cmd, _, _ in
            capturedCommand.value = cmd
        }
        return (service, capturedCommand)
    }
    
    func testDefaultServerLaunchBindsToLocalhostAndOmitsMaxContext() async throws {
        let dir = try TempDirectory()
        let (service, capturedCommand) = makeService(directory: dir.url)
        service.listenOnAllInterfaces = false
        service.maxContext = "auto"
        
        service.startServer(model: "incoai/Qwen3.6-35B-A3B-Splash", port: testPort)
        
        // Dar tiempo al Task detached en startServer
        try await Task.sleep(nanoseconds: 80_000_000)
        
        guard let cmd = capturedCommand.value else {
            XCTFail("No command was captured in serverLaunchOverride")
            return
        }
        
        XCTAssertTrue(cmd.contains("--host \"127.0.0.1\""), "Debe enlazar a localhost por defecto: \(cmd)")
        XCTAssertFalse(cmd.contains("--host \"0.0.0.0\""), "No debe enlazar a 0.0.0.0 por defecto: \(cmd)")
        XCTAssertFalse(cmd.contains("--max-context"), "No debe inyectar --max-context si está en auto: \(cmd)")
        XCTAssertTrue(cmd.contains("Solo localhost"), "El banner debe indicar localhost: \(cmd)")
    }
    
    func testServerLaunchWithAllInterfacesBindsToZeroZeroZeroZero() async throws {
        let dir = try TempDirectory()
        let (service, capturedCommand) = makeService(directory: dir.url)
        service.listenOnAllInterfaces = true
        service.maxContext = "auto"
        
        service.startServer(model: "incoai/Qwen3.6-35B-A3B-Splash", port: testPort)
        
        try await Task.sleep(nanoseconds: 80_000_000)
        
        guard let cmd = capturedCommand.value else {
            XCTFail("No command was captured in serverLaunchOverride")
            return
        }
        
        XCTAssertTrue(cmd.contains("--host \"0.0.0.0\""), "Debe enlazar a 0.0.0.0 cuando listenOnAllInterfaces es true: \(cmd)")
        XCTAssertFalse(cmd.contains("--host \"127.0.0.1\""), "No debe contener 127.0.0.1 en las opciones del CLI: \(cmd)")
        XCTAssertTrue(cmd.contains("Toda la red local / LAN"), "El banner debe indicar LAN: \(cmd)")
    }
    
    func testServerLaunchWithCustomMaxContextInjectsFlag() async throws {
        let dir = try TempDirectory()
        let (service, capturedCommand) = makeService(directory: dir.url)
        service.listenOnAllInterfaces = false
        service.maxContext = "64K"
        
        service.startServer(model: "incoai/Qwen3.6-35B-A3B-Splash", port: testPort)
        
        try await Task.sleep(nanoseconds: 80_000_000)
        
        guard let cmd = capturedCommand.value else {
            XCTFail("No command was captured in serverLaunchOverride")
            return
        }
        
        XCTAssertTrue(cmd.contains("--max-context \"64K\""), "Debe inyectar --max-context \"64K\": \(cmd)")
        XCTAssertTrue(cmd.contains("🧠 Contexto: 64K"), "El banner debe mostrar 64K: \(cmd)")
    }
    
    func testServerLaunchSanitizesMalformedContextValue() async throws {
        let dir = try TempDirectory()
        let (service, capturedCommand) = makeService(directory: dir.url)
        service.listenOnAllInterfaces = false
        service.maxContext = "32K; rm -rf /"
        
        service.startServer(model: "incoai/Qwen3.6-35B-A3B-Splash", port: testPort)
        
        try await Task.sleep(nanoseconds: 80_000_000)
        
        guard let cmd = capturedCommand.value else {
            XCTFail("No command was captured in serverLaunchOverride")
            return
        }
        
        XCTAssertFalse(cmd.contains("rm -rf"), "No debe contener comandos inyectados: \(cmd)")
        XCTAssertFalse(cmd.contains("--max-context"), "Debe omitir el flag ante caracteres sospechosos: \(cmd)")
    }
    
    func testPreferredHostOrIPReflectsListenOnAllInterfaces() throws {
        let dir = try TempDirectory()
        let (service, _) = makeService(directory: dir.url)
        
        service.allowedHosts = ""
        service.listenOnAllInterfaces = false
        XCTAssertEqual(service.preferredHostOrIP, "127.0.0.1")
        
        service.listenOnAllInterfaces = true
        if let ip = service.localNetworkIP {
            XCTAssertEqual(service.preferredHostOrIP, ip)
        } else {
            XCTAssertEqual(service.preferredHostOrIP, "127.0.0.1")
        }
        
        service.allowedHosts = "midominio.duckdns.org"
        XCTAssertEqual(service.preferredHostOrIP, "midominio.duckdns.org")
    }
    
    func testLanClientAppCategoryProperties() {
        let app = ConnectedApp(
            pid: 91234,
            name: "Cliente LAN (192.168.1.120)",
            category: .lanClient,
            connectionCount: 2,
            remoteAddress: "192.168.1.120:54321"
        )
        XCTAssertEqual(app.category, .lanClient)
        XCTAssertEqual(app.category.iconName, "network")
        XCTAssertEqual(app.category.localizedName(isSpanish: true), "Cliente Remoto / Red LAN")
        XCTAssertEqual(app.category.localizedName(isSpanish: false), "Remote Client / LAN Network")
    }
    
    func testServerLaunchWithAllowedHostsInjectsFlags() async throws {
        let dir = try TempDirectory()
        let (service, capturedCommand) = makeService(directory: dir.url)
        service.listenOnAllInterfaces = true
        service.allowedHosts = "midominio.duckdns.org, mimac.local; test.com"
        
        service.startServer(model: "incoai/Qwen3.6-35B-A3B-Splash", port: testPort)
        try await Task.sleep(nanoseconds: 80_000_000)
        
        guard let cmd = capturedCommand.value else {
            XCTFail("No command captured")
            return
        }
        
        XCTAssertTrue(cmd.contains("--allowed-host \"midominio.duckdns.org\""), "Debe inyectar el host permitido: \(cmd)")
        XCTAssertTrue(cmd.contains("--allowed-host \"mimac.local\""), "Debe inyectar mimac.local: \(cmd)")
        XCTAssertTrue(cmd.contains("--allowed-host \"test.com\""), "Debe inyectar test.com: \(cmd)")
        XCTAssertTrue(cmd.contains("🛡️ Dominios:"), "El banner debe incluir la sección de dominios: \(cmd)")
    }
}

/// Helper para capturar valores dentro de closures concurrentes en tests
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
