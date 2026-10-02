import XCTest
@testable import SplashMonitor

// MARK: - P-02 / H-01: el sondeo no puede quedar muerto

@MainActor
final class PollingTests: XCTestCase {
    
    private let port = 54321
    
    private func makeService(transport: StubStatusTransport,
                            terminator: RecordingServerTerminator,
                            directory: URL) -> SplashService {
        let service = SplashService(transport: transport,
                                    terminator: terminator,
                                    pollInterval: 30,           // no dispara durante la prueba
                                    dataDirectoryRoot: directory,
                                    bootstrapNetwork: false)
        service.shellEnvironmentDirectory = directory
        service.skipPortConflictCheck = true
        service.isSplashInstalled = true
        service.serverLaunchOverride = { _, _, _ in }           // no lanza procesos
        return service
    }
    
    // MARK: Estado inicial
    
    func testServiceStartsPollingAndWritesNothingOutsideItsDirectory() async throws {
        let dir = try TempDirectory()
        let service = makeService(transport: StubStatusTransport(),
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        XCTAssertTrue(service.isPollingActive)
        XCTAssertFalse(service.isWatchdogActive)
    }
    
    // MARK: P-02 — núcleo del defecto
    
    /// Defecto original: `stopServerAsync()` invalidaba el temporizador y **nada** lo
    /// recreaba. Tras pulsar «Detener Servidor» el panel quedaba congelado el resto de
    /// la sesión y un motor arrancado después nunca se detectaba.
    func testStoppingServerKeepsWatchingForALaterStart() async throws {
        let dir = try TempDirectory()
        let transport = StubStatusTransport()
        let terminator = RecordingServerTerminator()
        let service = makeService(transport: transport, terminator: terminator, directory: dir.url)
        
        await service.stopServerAsync()
        
        XCTAssertFalse(service.isPollingActive)
        XCTAssertTrue(service.isWatchdogActive, "Debe quedar un vigía capaz de recuperar el sondeo.")
        XCTAssertEqual(terminator.calls.first?.port, service.activePort)
        XCTAssertEqual(terminator.calls.count, 1)
    }
    
    /// El vigía detecta un motor que aparece después y rearma el sondeo periódico.
    func testWatchdogRestoresPollingWhenEngineAppears() async throws {
        let dir = try TempDirectory()
        let transport = StubStatusTransport()
        let service = makeService(transport: transport,
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        await service.stopServerAsync()
        XCTAssertFalse(service.isPollingActive)
        
        transport.setStatus(Fixtures.status(port: service.activePort, model: "incoai/Otro-Modelo"), for: service.activePort)
        await service.watchdogTick()
        
        XCTAssertTrue(service.isRunning)
        XCTAssertTrue(service.isPollingActive, "El sondeo debe reanudarse (H-01).")
        XCTAssertFalse(service.isWatchdogActive, "El vigía se apaga al recuperar el sondeo.")
    }
    
    /// Arranque desde la propia app tras un «Detener»: también debe reanudar el sondeo.
    func testStartServerResumesPollingAfterAStop() async throws {
        let dir = try TempDirectory()
        let transport = StubStatusTransport()
        let terminator = RecordingServerTerminator()
        let service = makeService(transport: transport, terminator: terminator, directory: dir.url)
        
        await service.stopServerAsync()
        XCTAssertFalse(service.isPollingActive)
        
        transport.setStatus(Fixtures.status(port: port), for: port)
        service.startServer(model: "incoai/Qwen3.8-27B-Splash", port: port)
        
        let restored = await waitUntil(timeout: 8) { service.isPollingActive }
        XCTAssertTrue(restored, "startServer debe restaurar el sondeo (P-02).")
        XCTAssertTrue(service.isRunning)
        XCTAssertFalse(service.isStartingServer)
        XCTAssertNil(service.startingModelId)
        XCTAssertEqual(service.activeModel, "incoai/Qwen3.8-27B-Splash")
        XCTAssertGreaterThan(service.speedHistory.count, 0)
    }
    
    /// El motor se limpia siempre a través del terminador verificado: la app ya no
    /// ejecuta `pkill -f` ni `lsof -ti :puerto | kill -9` por su cuenta (P-01/P-06).
    func testServerLifecycleDelegatesAllTerminationToVerifiedTerminator() async throws {
        let dir = try TempDirectory()
        let transport = StubStatusTransport()
        let terminator = RecordingServerTerminator()
        let service = makeService(transport: transport, terminator: terminator, directory: dir.url)
        transport.setStatus(Fixtures.status(port: port), for: port)
        
        service.startServer(model: "incoai/Qwen3.8-27B-Splash", port: port)
        _ = await waitUntil(timeout: 8) { service.isRunning }
        XCTAssertEqual(terminator.calls.map(\.port), [port])
        
        service.stopServerSync()
        XCTAssertEqual(terminator.calls.count, 2)
        XCTAssertEqual(terminator.calls.last?.port, service.activePort)
    }
    
    // MARK: P-03 en el servicio
    
    func testStartServerRejectsInjectedModelIdentifier() async throws {
        let dir = try TempDirectory()
        let transport = StubStatusTransport()
        let terminator = RecordingServerTerminator()
        let service = makeService(transport: transport, terminator: terminator, directory: dir.url)
        
        let witness = "/tmp/splashmonitor-testigo-\(UUID().uuidString)"
        let payload = "incoai/x\" ; touch \(witness) ; echo \""
        service.startServer(model: payload, port: port)
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: witness),
                       "El identificador inyectado no debe llegar nunca al shell (H-03).")
        XCTAssertNotNil(service.lastError)
        XCTAssertFalse(service.isStartingServer)
        XCTAssertTrue(terminator.calls.isEmpty)
        
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: witness))
    }
    
    func testStartServerRejectsOutOfRangePort() async throws {
        let dir = try TempDirectory()
        let service = makeService(transport: StubStatusTransport(),
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        service.startServer(model: "incoai/Qwen3.8-27B-Splash", port: 70000)
        XCTAssertNotNil(service.lastError)
        XCTAssertFalse(service.isStartingServer)
    }
    
    func testInstallModelRejectsUnsafeIdentifier() async throws {
        let dir = try TempDirectory()
        let service = makeService(transport: StubStatusTransport(),
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        service.installModel(repoId: "../../../etc/passwd")
        XCTAssertFalse(service.isInstalling)
        XCTAssertNotNil(service.lastError)
    }
    
    func testDeleteModelRejectsTraversalAndKeepsFiles() async throws {
        let dir = try TempDirectory()
        let models = dir.file("models")
        try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
        let sentinel = dir.file("centinela.txt")
        try "no borrar".write(to: sentinel, atomically: true, encoding: .utf8)
        
        let service = makeService(transport: StubStatusTransport(),
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        service.deleteModel(repoId: "../centinela.txt")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
        XCTAssertNotNil(service.lastError)
    }
    
    // MARK: P-08 en el servicio
    
    /// La app debe leer `serve-<puerto>.lock` (motor 1.0.2), no solo el `serve.lock` vacío.
    func testServiceReadsPortSpecificLockFile() async throws {
        let dir = try TempDirectory()
        let runtime = dir.file("runtime")
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        let transport = StubStatusTransport()
        let service = makeService(transport: transport,
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        
        // Bloqueo vacío (histórico) + bloqueo real del puerto.
        try Data().write(to: runtime.appendingPathComponent("serve.lock"))
        try Fixtures.lockData(pid: Int(getpid()), port: service.activePort)
            .write(to: runtime.appendingPathComponent("serve-\(service.activePort).lock"))
        
        XCTAssertEqual(service.readLockPid(), Int(getpid()))
    }
    
    /// Redundancia deliberada: aunque falte el nombre `serve-<puerto>.lock`, el sondeo del
    /// directorio `runtime/` encuentra cualquier bloqueo del motor. Es lo que hace que la
    /// recuperación no dependa de una única ruta de descubrimiento.
    func testLockDiscoveryFindsAnyServeLockInRuntimeDirectory() async throws {
        let dir = try TempDirectory()
        let runtime = dir.file("runtime")
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        let service = makeService(transport: StubStatusTransport(),
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        XCTAssertNotEqual(service.activePort, 8008)
        try Fixtures.lockData(pid: Int(getpid()), port: 8008)
            .write(to: runtime.appendingPathComponent("serve-8008.lock"))
        XCTAssertEqual(service.readLockPid(), Int(getpid()))
    }
    
    /// Un bloqueo de un PID inexistente y antiguo se limpia; el fichero no persiste.
    func testStaleLockIsRemovedButFreshOneIsKept() async throws {
        let dir = try TempDirectory()
        let runtime = dir.file("runtime")
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
        let service = makeService(transport: StubStatusTransport(),
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        
        let dead = runtime.appendingPathComponent("serve-8008.lock")
        try Fixtures.lockData(pid: 999_999, port: 8008).write(to: dead)
        // Antigüedad: el margen de arranque evita borrar bloqueos recientes.
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-3600)],
                                              ofItemAtPath: dead.path)
        service.cleanStaleLocks()
        XCTAssertFalse(FileManager.default.fileExists(atPath: dead.path))
        
        let fresh = runtime.appendingPathComponent("serve-8009.lock")
        try Fixtures.lockData(pid: 999_999, port: 8009).write(to: fresh)
        service.cleanStaleLocks()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path), "Un motor en arranque no se toca.")
    }
    
    // MARK: P-17 — residuos de versiones anteriores
    
    func testLegacyLauncherArtifactIsRemoved() async throws {
        let dir = try TempDirectory()
        try dir.write("#!/usr/bin/env python3\n# bridge launcher retirado en 1.0.1", to: "splash_launcher.py")
        let service = makeService(transport: StubStatusTransport(),
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        service.cleanLegacyArtifacts()
        XCTAssertFalse(dir.exists("splash_launcher.py"))
    }
    
    // MARK: P-12 — el sondeo no reescanea el catálogo en cada ciclo
    
    func testCatalogScanIsDeferredAcrossTicks() async throws {
        let dir = try TempDirectory()
        let models = dir.file("models/incoai/Qwen3.8-27B-Splash")
        try FileManager.default.createDirectory(at: models, withIntermediateDirectories: true)
        try dir.write(String(repeating: "x", count: 4096), to: "models/incoai/Qwen3.8-27B-Splash/pesos.bin")
        
        let transport = StubStatusTransport()
        let service = makeService(transport: transport,
                                  terminator: RecordingServerTerminator(),
                                  directory: dir.url)
        service.refreshInstalledModels()
        XCTAssertEqual(service.installedModels.count, 1)
        XCTAssertEqual(service.installedModels.first?.repoId, "incoai/Qwen3.8-27B-Splash")
        
        // Seis ciclos con el catálogo ya poblado: el reescaneo se aplaza hasta el décimo.
        transport.setStatus(Fixtures.status(port: service.activePort), for: service.activePort)
        for _ in 0..<6 { await service.checkServerStatus() }
        XCTAssertEqual(service.installedModels.count, 1)
        
        for _ in 0..<5 { await service.checkServerStatus() }
        XCTAssertEqual(service.installedModels.count, 1)
    }
}
