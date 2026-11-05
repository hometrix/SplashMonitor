import XCTest
@testable import SplashMonitor

final class ServerOwnershipTests: XCTestCase {
    private let script = "/Users/test/Library/Application Support/Splash/start_splash.command"
    
    /// Tabla de procesos falsa: pid -> (ppid, comando).
    private func table(_ rows: [Int: (Int, String)]) -> (Int) -> (ppid: Int, command: String)? {
        { pid in rows[pid].map { (ppid: $0.0, command: $0.1) } }
    }
    
    func testServerUnderAppScriptIsOwned() {
        let process = table([
            500: (400, "/opt/homebrew/Cellar/splash/1.5.0/libexec/python/bin/python3 -u -P -m server.server"),
            400: (1, "/bin/bash \(script)"),
        ])
        XCTAssertTrue(ServerOwnership.isLaunchedByApp(pid: 500, scriptPath: script, process: process))
    }
    
    func testServerUnderTerminalLaunchedScriptIsOwned() {
        let process = table([
            500: (450, "python3 -m server.server"),
            450: (420, "/bin/sh /opt/homebrew/bin/splash serve"),
            420: (410, "/bin/bash \(script)"),
            410: (1, "login -pf user"),
        ])
        XCTAssertTrue(ServerOwnership.isLaunchedByApp(pid: 500, scriptPath: script, process: process))
    }
    
    func testServerStartedFromTerminalOrScriptIsNotOwned() {
        let detached = table([500: (1, "python3 -m server.server")])
        XCTAssertFalse(ServerOwnership.isLaunchedByApp(pid: 500, scriptPath: script, process: detached))
        
        let fromShell = table([
            500: (300, "python3 -m server.server"),
            300: (200, "-zsh"),
            200: (1, "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal"),
        ])
        XCTAssertFalse(ServerOwnership.isLaunchedByApp(pid: 500, scriptPath: script, process: fromShell))
    }
    
    func testMissingProcessOrEmptyScriptIsNotOwned() {
        XCTAssertFalse(ServerOwnership.isLaunchedByApp(pid: 500, scriptPath: script, process: table([:])))
        let process = table([500: (400, "server"), 400: (1, "/bin/bash \(script)")])
        XCTAssertFalse(ServerOwnership.isLaunchedByApp(pid: 500, scriptPath: "", process: process))
    }
    
    func testCycleInProcessTableTerminates() {
        let process = table([500: (400, "a"), 400: (500, "b")])
        XCTAssertFalse(ServerOwnership.isLaunchedByApp(pid: 500, scriptPath: script, process: process))
    }
}
