import XCTest
@testable import SplashMonitor

final class ModelDiagnosticTests: XCTestCase {
    
    @MainActor
    func testSmokeTestItemsInitializedCorrectly() {
        let service = ModelDiagnosticService()
        XCTAssertEqual(service.smokeTestResults.count, 7)
        
        let ids = service.smokeTestResults.map { $0.id }
        XCTAssertTrue(ids.contains("health"))
        XCTAssertTrue(ids.contains("ready"))
        XCTAssertTrue(ids.contains("status"))
        XCTAssertTrue(ids.contains("template"))
        XCTAssertTrue(ids.contains("openai"))
        XCTAssertTrue(ids.contains("anthropic"))
        XCTAssertTrue(ids.contains("tools"))
        
        for item in service.smokeTestResults {
            XCTAssertEqual(item.status, .idle)
            XCTAssertFalse(item.status.isPassed)
        }
    }
    
    @MainActor
    func testResetSmokeTestsResetsState() {
        let service = ModelDiagnosticService()
        service.smokeTestResults[0].status = .passed(details: "OK", latencyMs: 12.0)
        XCTAssertTrue(service.smokeTestResults[0].status.isPassed)
        
        service.resetSmokeTests()
        XCTAssertEqual(service.smokeTestResults[0].status, .idle)
        XCTAssertFalse(service.smokeTestResults[0].status.isPassed)
    }
    
    func testBenchmarkResultValues() {
        let bench = ModelDiagnosticService.BenchmarkResult(
            coldDecodeTokPerSec: 45.2,
            warmDecodeTokPerSec: 154.8,
            coldTTFTMs: 380.0,
            warmTTFTMs: 95.0,
            cacheSpeedupMultiplier: 4.0,
            promptTokens: 256,
            outputTokens: 128
        )
        
        XCTAssertEqual(bench.coldDecodeTokPerSec, 45.2, accuracy: 0.01)
        XCTAssertEqual(bench.warmDecodeTokPerSec, 154.8, accuracy: 0.01)
        XCTAssertEqual(bench.cacheSpeedupMultiplier, 4.0, accuracy: 0.01)
        XCTAssertEqual(bench.promptTokens, 256)
        XCTAssertEqual(bench.outputTokens, 128)
    }
    
    func testCheckStatusEquality() {
        let s1 = ModelDiagnosticService.CheckStatus.passed(details: "OK", latencyMs: 5.0)
        let s2 = ModelDiagnosticService.CheckStatus.passed(details: "OK", latencyMs: 5.0)
        let s3 = ModelDiagnosticService.CheckStatus.failed(error: "Fail")
        let s4 = ModelDiagnosticService.CheckStatus.idle
        
        XCTAssertEqual(s1, s2)
        XCTAssertNotEqual(s1, s3)
        XCTAssertNotEqual(s1, s4)
        XCTAssertTrue(s1.isPassed)
        XCTAssertFalse(s3.isPassed)
    }
    
    @MainActor
    func testSidebarItemIncludesModelTesting() {
        let allItems = MainWindowView.SidebarItem.allCases
        XCTAssertTrue(allItems.contains(.modelTesting))
        
        let testingItem = MainWindowView.SidebarItem.modelTesting
        XCTAssertEqual(testingItem.title(isSpanish: true), "Test de Modelos")
        XCTAssertEqual(testingItem.title(isSpanish: false), "Model Testing")
        XCTAssertEqual(testingItem.icon, "testtube.2")
    }
}
