import XCTest
@testable import SplashMonitor

// MARK: - P-05 del plan 1.0.1: rutas sin versión fija

final class SplashPathsTests: XCTestCase {
    
    func testFirstExistingPicksFirstAvailableCandidate() {
        let candidates = ["/a", "/b", "/c"]
        XCTAssertEqual(SplashPaths.firstExisting(candidates, exists: { $0 == "/b" }), "/b")
        XCTAssertEqual(SplashPaths.firstExisting(candidates, exists: { $0 == "/c" }), "/c")
        XCTAssertNil(SplashPaths.firstExisting(candidates, exists: { _ in false }))
        XCTAssertNil(SplashPaths.firstExisting([], exists: { _ in true }))
    }
    
    /// Regresión de la clase de errores corregida en 1.0.1: una versión fija en la ruta
    /// rompe la app tras `brew upgrade splash`.
    func testNoCandidatePathPinsAMotorVersion() {
        let all = SplashPaths.brewExecutableCandidates()
            + SplashPaths.splashExecutableCandidates()
            + SplashPaths.pythonCandidates()
            + SplashPaths.modelsScriptCandidates()
        for candidate in all {
            XCTAssertFalse(candidate.contains("/Cellar/"),
                           "Ruta con versión fija detectada: \(candidate)")
            XCTAssertNil(candidate.range(of: #"/\d+\.\d+(\.\d+)?"#, options: .regularExpression),
                         "Ruta con número de versión detectada: \(candidate)")
        }
    }
    
    func testCellarCandidatesTryEveryInstalledVersionInDeterministicOrder() {
        let versions: [String: [String]] = ["/opt/homebrew/Cellar/splash": ["1.0.10", "1.0.2", "1.0.9"]]
        let found = SplashPaths.firstCellarCandidate(
            subpath: "libexec/install/models.py",
            versions: { versions[$0] },
            exists: { $0 == "/opt/homebrew/Cellar/splash/1.0.9/libexec/install/models.py" }
        )
        XCTAssertEqual(found, "/opt/homebrew/Cellar/splash/1.0.9/libexec/install/models.py")
    }
    
    func testCellarSearchReturnsNilWhenAbsent() {
        XCTAssertNil(SplashPaths.firstCellarCandidate(subpath: "libexec/python/bin/python3",
                                                      versions: { _ in nil },
                                                      exists: { _ in true }))
        XCTAssertNil(SplashPaths.firstCellarCandidate(subpath: "libexec/python/bin/python3",
                                                      versions: { _ in [] },
                                                      exists: { _ in true }))
    }
    
    func testCellarVersionListingIsSorted() {
        XCTAssertEqual(SplashPaths.cellarVersions(in: "/opt/homebrew/Cellar/splash",
                                                  list: { _ in ["1.0.10", "1.0.2"] }),
                       ["1.0.10", "1.0.2"])
        XCTAssertEqual(SplashPaths.cellarVersions(in: "/x", list: { _ in nil }), [])
    }
}
