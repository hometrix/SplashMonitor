import XCTest
@testable import SplashMonitor

// MARK: - P-01 / H-02 y H-04: a quién es lícito señalizar

final class ProcessIntrospectionTests: XCTestCase {
    
    /// Salida real de `lsof -tiTCP:18097 -sTCP:LISTEN` (solo el servidor).
    private let listenerOutput = "50529\n"
    /// Salida real de `lsof -ti :18097` (servidor **y** cliente conectado).
    private let listenerAndClientOutput = "50528\n50529\n"
    
    func testParsesListeningPIDs() {
        XCTAssertEqual(ListerOutput.listeningPIDs(listenerAndClientOutput), [50528, 50529])
        XCTAssertEqual(ListerOutput.listeningPIDs(listenerOutput), [50529])
        XCTAssertEqual(ListerOutput.listeningPIDs(""), [])
        XCTAssertEqual(ListerOutput.listeningPIDs("   \n"), [])
        XCTAssertEqual(ListerOutput.listeningPIDs("abc\n-3\n0\n"), [])
    }
    
    /// La regresión clave: el cliente conectado (PID 50528) nunca debe ser objetivo.
    /// Con la lógica antigua (`lsof -ti :puerto` + `SIGKILL` a todo) sí lo era.
    func testResolverOnlyTargetsListeningEngineProcesses() {
        let commands: [Int32: String] = [
            50528: "/usr/bin/ssh -N -L 18097:127.0.0.1:18097 host",
            50529: "/opt/homebrew/opt/splash/libexec/python/bin/python3 /opt/homebrew/opt/splash/libexec/server/server.py --port 18097"
        ]
        let targets = KillTargetResolver.enginePIDsToStop(lsofOutput: listenerOutput) { commands[$0] }
        XCTAssertEqual(targets, [50529])
        
        // Si por error se pasaran las dos entradas de `lsof -ti :puerto`, el resolver
        // sigue descartando al cliente por identidad, no por puerto.
        let guarded = KillTargetResolver.enginePIDsToStop(lsofOutput: listenerAndClientOutput) { commands[$0] }
        XCTAssertEqual(guarded, [50529])
    }
    
    func testUnknownProcessIsNotTargeted() {
        let targets = KillTargetResolver.enginePIDsToStop(lsofOutput: listenerOutput) { pid in
            pid == 50529 ? "/usr/local/bin/uvicorn backend:app --port 8000" : nil
        }
        XCTAssertTrue(targets.isEmpty)
        XCTAssertTrue(KillTargetResolver.enginePIDsToStop(lsofOutput: listenerOutput) { _ in nil }.isEmpty)
        XCTAssertTrue(KillTargetResolver.enginePIDsToStop(lsofOutput: listenerOutput) { _ in "" }.isEmpty)
    }
    
    func testEngineIdentityRecognisesInstalledLayouts() {
        XCTAssertTrue(SplashEngineIdentity.isEngineCommand("/opt/homebrew/bin/splash serve --model incoai/x"))
        XCTAssertTrue(SplashEngineIdentity.isEngineCommand("/opt/homebrew/Cellar/splash/1.0.2/libexec/engine/splash serve-native"))
        XCTAssertTrue(SplashEngineIdentity.isEngineCommand("/opt/homebrew/opt/splash/libexec/server/server.py"))
        XCTAssertFalse(SplashEngineIdentity.isEngineCommand("/usr/bin/python3 -m uvicorn backend:app"))
        XCTAssertFalse(SplashEngineIdentity.isEngineCommand("/Applications/Visual Studio Code.app/Contents/MacOS/Electron"))
        XCTAssertFalse(SplashEngineIdentity.isEngineCommand(""))
    }
    
    /// Escalada declarada: nunca se empieza por `SIGKILL`.
    func testSignalEscalationStartsCourteous() {
        XCTAssertEqual(KillTargetResolver.escalation.first, .interrupt)
        XCTAssertEqual(KillTargetResolver.escalation.last, .forceKill)
        XCTAssertEqual(KillTargetResolver.escalation.count, 3)
    }
    
    func testParsesEstablishedConnections() {
        let output = """
        COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
        claude    12345 hometrix   23u  IPv4 0x8f2b1c4d5e6f7a8b      0t0  TCP 127.0.0.1:61012->127.0.0.1:18097 (ESTABLISHED)
        Code\\x20H 23456 hometrix   44u  IPv4 0x1a2b3c4d5e6f7a8c      0t0  TCP 127.0.0.1:61028->127.0.0.1:18097 (ESTABLISHED)
        python3   50529 hometrix   18u  IPv4 0x2b3c4d5e6f7a8b9c      0t0  TCP 127.0.0.1:18097->127.0.0.1:61012 (ESTABLISHED)
        """
        let connections = ListerOutput.establishedConnections(output)
        XCTAssertEqual(connections.count, 3)
        XCTAssertEqual(connections.first?.pid, 12345)
        XCTAssertEqual(connections.first?.command, "claude")
        XCTAssertEqual(connections.first?.remoteAddress, "127.0.0.1:61012->127.0.0.1:18097")
    }
    
    func testEstablishedParserIgnoresHeaderAndMalformedRows() {
        XCTAssertTrue(ListerOutput.establishedConnections("").isEmpty)
        XCTAssertTrue(ListerOutput.establishedConnections("COMMAND PID USER").isEmpty)
        XCTAssertTrue(ListerOutput.establishedConnections("claude abc hometrix 1u IPv4 0x1 0t0 TCP x->y").isEmpty)
    }
}
