import XCTest
@testable import SplashMonitor

// MARK: - P-12 / H-13: caché de tamaños de modelo

final class ModelSizeCacheTests: XCTestCase {
    
    func testRepeatedLookupsWithSameStampReuseTheCachedValue() {
        var cache = ModelSizeCache()
        var computations = 0
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        
        for _ in 0..<10 {
            let size = cache.size(repoId: "incoai/Qwen3.8-27B-Splash", stamp: stamp) {
                computations += 1
                return 17_400_000_000
            }
            XCTAssertEqual(size, 17_400_000_000)
        }
        XCTAssertEqual(computations, 1, "10 ciclos de sondeo deben costar 1 sola medición (P-12).")
        XCTAssertEqual(cache.count, 1)
    }
    
    func testStampChangeInvalidatesEntry() {
        var cache = ModelSizeCache()
        var computations = 0
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = first.addingTimeInterval(60)
        
        _ = cache.size(repoId: "incoai/modelo", stamp: first) { computations += 1; return 10 }
        _ = cache.size(repoId: "incoai/modelo", stamp: second) { computations += 1; return 20 }
        XCTAssertEqual(computations, 2)
        
        let size = cache.size(repoId: "incoai/modelo", stamp: second) { computations += 1; return 30 }
        XCTAssertEqual(size, 20)
        XCTAssertEqual(computations, 2)
    }
    
    func testExplicitInvalidationForcesRecompute() {
        var cache = ModelSizeCache()
        var computations = 0
        _ = cache.size(repoId: "incoai/modelo", stamp: nil) { computations += 1; return 1 }
        cache.invalidate(repoId: "incoai/modelo")
        _ = cache.size(repoId: "incoai/modelo", stamp: nil) { computations += 1; return 2 }
        XCTAssertEqual(computations, 2)
        cache.invalidateAll()
        XCTAssertEqual(cache.count, 0)
    }
    
    func testTTLExpiresEvenWithStableStamp() {
        var cache = ModelSizeCache(ttl: 60)
        var computations = 0
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        _ = cache.size(repoId: "m", stamp: nil, now: t0) { computations += 1; return 5 }
        _ = cache.size(repoId: "m", stamp: nil, now: t0.addingTimeInterval(30)) { computations += 1; return 5 }
        XCTAssertEqual(computations, 1)
        _ = cache.size(repoId: "m", stamp: nil, now: t0.addingTimeInterval(61)) { computations += 1; return 5 }
        XCTAssertEqual(computations, 2)
    }
    
    func testIndependentEntriesPerModel() {
        var cache = ModelSizeCache()
        _ = cache.size(repoId: "a/m1", stamp: nil) { 1 }
        _ = cache.size(repoId: "a/m2", stamp: nil) { 2 }
        XCTAssertEqual(cache.count, 2)
        XCTAssertEqual(cache.size(repoId: "a/m1", stamp: nil) { 99 }, 1)
        XCTAssertEqual(cache.size(repoId: "a/m2", stamp: nil) { 99 }, 2)
    }
}
