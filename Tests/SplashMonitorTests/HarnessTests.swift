import XCTest
@testable import SplashMonitor

/// F0.1 — El objetivo de pruebas puede importar el módulo del ejecutable.
/// Confirma que no hace falta extraer un target de librería para probar la app.
final class HarnessTests: XCTestCase {
    func testTestTargetCanImportExecutableModuleAndDecodeFixture() throws {
        let status: SplashStatus = Fixtures.status(port: 8005)
        XCTAssertEqual(status.ready, true)
        XCTAssertEqual(status.instance?.model, "incoai/Qwen3.8-27B-Splash")
        XCTAssertEqual(status.instance?.port, 8005)
    }
}
