import XCTest
@testable import SplashMonitor

// MARK: - P-08 / H-07: ficheros de bloqueo del motor

final class ServeLockTests: XCTestCase {
    
    func testCandidateNamesPreferPortSpecificLock() {
        XCTAssertEqual(ServeLockStore.candidateFileNames(port: 8005),
                       ["serve-8005.lock", "serve.lock"])
        XCTAssertEqual(ServeLockStore.candidateFileNames(port: 8008).first, "serve-8008.lock")
    }
    
    /// El motor 1.0.2 deja `serve.lock` con 0 bytes: debía devolver `nil`, no fallar.
    func testEmptyOrCorruptLockDecodesToNil() {
        XCTAssertNil(ServeLockStore.decode(Data()))
        XCTAssertNil(ServeLockStore.decode(Data("no es json".utf8)))
        XCTAssertNil(ServeLockStore.decode(nil))
        let lock = ServeLockStore.decode(Fixtures.lockData(pid: 1234, port: 8005))
        XCTAssertEqual(lock?.pid, 1234)
        XCTAssertEqual(lock?.port, 8005)
    }
    
    func testLockIsUsableOnlyWithLiveMatchingPID() {
        let lock = ServeLockStore.decode(Fixtures.lockData(pid: 1234, port: 8005))
        XCTAssertTrue(ServeLockStore.isUsable(lock, port: 8005, pidAlive: { $0 == 1234 }))
        // PID muerto
        XCTAssertFalse(ServeLockStore.isUsable(lock, port: 8005, pidAlive: { _ in false }))
        // Bloqueo de otro puerto (serve-8008.lock con un motor en 8005)
        XCTAssertFalse(ServeLockStore.isUsable(lock, port: 8008, pidAlive: { _ in true }))
        XCTAssertFalse(ServeLockStore.isUsable(nil, port: 8005, pidAlive: { _ in true }))
    }
    
    /// Caso real medido en el equipo auditado: `serve-8008.lock` con un PID ya muerto
    /// que nadie limpiaba y que hacía creer a la app que había un motor en 8008.
    func testDeadOldLockIsStale() {
        let lock = ServeLockStore.decode(Fixtures.lockData(pid: 99999, port: 8008))
        XCTAssertTrue(ServeLockStore.isStale(lock, pidAlive: false, age: 86_400))
        XCTAssertTrue(ServeLockStore.isStale(nil, pidAlive: false, age: 86_400))
    }
    
    /// Margen de arranque: un motor recién lanzado puede tardar; su bloqueo se respeta.
    func testFreshLockOfStartingEngineIsNotStale() {
        let lock = ServeLockStore.decode(Fixtures.lockData(pid: 99999, port: 8008))
        XCTAssertFalse(ServeLockStore.isStale(lock, pidAlive: false, age: 5))
        XCTAssertFalse(ServeLockStore.isStale(lock, pidAlive: true, age: 86_400))
    }
}
