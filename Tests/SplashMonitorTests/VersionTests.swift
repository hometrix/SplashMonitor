import XCTest
@testable import SplashMonitor

// MARK: - P-07 / H-08: comparación semántica de versiones

final class VersionTests: XCTestCase {
    
    /// Sonda V-8 de la auditoría, ahora como prueba de regresión.
    /// Con comparación lexicográfica (`String >`) la respuesta era `false`.
    func testPatchTenIsNewerThanPatchTwo() {
        XCTAssertTrue(SemanticVersion.isNewer("1.0.10-beta", than: "1.0.2-beta"))
        XCTAssertFalse(SemanticVersion.isNewer("1.0.2-beta", than: "1.0.10-beta"))
    }
    
    func testNumericComponentsComparedAsNumbers() {
        XCTAssertFalse(SemanticVersion.isNewer("2.0.0", than: "10.0.0"))
        XCTAssertFalse(SemanticVersion.isNewer("1.2.0", than: "1.10.0"))
        XCTAssertTrue(SemanticVersion.isNewer("1.10.0", than: "1.2.0"))
        XCTAssertTrue(SemanticVersion.isNewer("1.0.3", than: "1.0.2"))
        XCTAssertFalse(SemanticVersion.isNewer("1.0.2", than: "1.0.2"))
    }
    
    func testReleaseIsNewerThanItsPrerelease() {
        XCTAssertTrue(SemanticVersion.isNewer("1.0.3", than: "1.0.3-beta"))
        XCTAssertFalse(SemanticVersion.isNewer("1.0.3-beta", than: "1.0.3"))
    }
    
    func testParsingAcceptsPrefixAndPartialVersions() throws {
        XCTAssertEqual(try XCTUnwrap(SemanticVersion("v1.0.2-beta")).description, "1.0.2-beta")
        XCTAssertEqual(try XCTUnwrap(SemanticVersion("1.0")).description, "1.0.0")
        XCTAssertEqual(try XCTUnwrap(SemanticVersion(" 2.1.3 ")).description, "2.1.3")
        XCTAssertEqual(try XCTUnwrap(SemanticVersion("1.0.2+build.9")).major, 1)
    }
    
    func testUnparseableVersionNeverClaimsAnUpdate() {
        // Ante basura no se inventa una actualización: falso negativo silencioso.
        XCTAssertFalse(SemanticVersion.isNewer("latest", than: "1.0.2-beta"))
        XCTAssertFalse(SemanticVersion.isNewer("1.0.10-beta", than: "no-es-version"))
        XCTAssertFalse(SemanticVersion.isNewer("", than: "1.0.2-beta"))
        XCTAssertNil(SemanticVersion("1.0.2.3.4"))
        XCTAssertNil(SemanticVersion("1..2"))
        XCTAssertNil(SemanticVersion("-1.0.0"))
    }
    
    /// P-15: la versión vive en un solo sitio y los scripts la extraen de ahí.
    func testVersionExistsOnceAndScriptsAgreeWithIt() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Tests/SplashMonitorTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // raíz del paquete
        let version = SplashVersion.current
        
        let sources = ["Sources/SplashMonitor/Services/Version.swift"]
        var declarations = 0
        for relative in sources {
            let contents = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            let occurrences = contents.components(separatedBy: "= \"\(version)\"").count - 1
            declarations += occurrences
        }
        XCTAssertEqual(declarations, 1, "La versión debe declararse una sola vez (P-15).")
        
        // Ningún otro fichero Swift puede contener un literal de versión del producto.
        let enumerator = FileManager.default.enumerator(at: root.appendingPathComponent("Sources"),
                                                        includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "swift", file.lastPathComponent != "Version.swift" else { continue }
            let contents = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(contents.contains("\"\(version)\""),
                           "Versión duplicada en \(file.lastPathComponent); debe venir de SplashVersion.current.")
        }
    }
}
