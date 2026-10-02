import XCTest
@testable import SplashMonitor

// MARK: - P-04 / H-05: política de terminación de clientes

final class ClientTerminationPolicyTests: XCTestCase {
    
    func testTerminatesMatchingRunningApplication() {
        XCTAssertTrue(ClientTerminationPolicy.canTerminate(
            pid: 12345,
            recordedBundleID: "com.anthropic.claudefordesktop",
            currentBundleID: "com.anthropic.claudefordesktop",
            currentName: "Claude",
            isRunning: true,
            ownBundleID: "com.incoai.splashmonitor"
        ))
    }
    
    /// PID reciclado: el proceso registrado ya no es la misma aplicación.
    func testRejectsRecycledPIDWithDifferentBundle() {
        XCTAssertFalse(ClientTerminationPolicy.canTerminate(
            pid: 12345,
            recordedBundleID: "com.anthropic.claudefordesktop",
            currentBundleID: "com.apple.finder",
            currentName: "Finder",
            isRunning: true,
            ownBundleID: "com.incoai.splashmonitor"
        ))
    }
    
    func testNeverTerminatesTheMonitorItself() {
        XCTAssertFalse(ClientTerminationPolicy.canTerminate(
            pid: 4242,
            recordedBundleID: "com.incoai.splashmonitor",
            currentBundleID: "com.incoai.splashmonitor",
            currentName: "Splash Monitor",
            isRunning: true,
            ownBundleID: "com.incoai.splashmonitor"
        ))
    }
    
    func testRejectsProcessesThatNoLongerExist() {
        XCTAssertFalse(ClientTerminationPolicy.canTerminate(
            pid: 12345,
            recordedBundleID: "com.anthropic.claudefordesktop",
            currentBundleID: nil,
            currentName: nil,
            isRunning: false,
            ownBundleID: "com.incoai.splashmonitor"
        ))
        XCTAssertFalse(ClientTerminationPolicy.canTerminate(
            pid: 0,
            recordedBundleID: "com.x",
            currentBundleID: "com.x",
            currentName: "X",
            isRunning: true,
            ownBundleID: nil
        ))
    }
    
    /// Sin bundle identificado (script suelto) solo se admite si el nombre sigue vivo.
    func testScriptWithoutBundleRequiresMatchingName() {
        XCTAssertTrue(ClientTerminationPolicy.canTerminate(
            pid: 777,
            recordedBundleID: nil,
            currentBundleID: nil,
            currentName: "python3",
            isRunning: true,
            ownBundleID: "com.incoai.splashmonitor"
        ))
        XCTAssertFalse(ClientTerminationPolicy.canTerminate(
            pid: 777,
            recordedBundleID: nil,
            currentBundleID: nil,
            currentName: nil,
            isRunning: true,
            ownBundleID: "com.incoai.splashmonitor"
        ))
    }
}
