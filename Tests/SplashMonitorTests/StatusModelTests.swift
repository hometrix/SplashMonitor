import XCTest
@testable import SplashMonitor

// MARK: - Sonda V-4: contrato real de `/status` frente al modelo Swift

final class StatusModelTests: XCTestCase {
    
    /// La fixture replica la carga útil real del motor 1.0.2 (30 claves observadas) más
    /// una clave desconocida. El modelo debe decodificar e ignorar lo que no conoce.
    func testDecodesRealStatusPayloadAndToleratesUnknownKeys() throws {
        let status = Fixtures.status(port: 8005)
        XCTAssertTrue(try XCTUnwrap(status.ready))
        XCTAssertEqual(status.maximumContextTokens, 262_144)
        XCTAssertEqual(status.memoryPressure, "nominal")
        XCTAssertEqual(status.instance?.pid, 4242)
        XCTAssertEqual(status.instance?.host, "127.0.0.1")
        XCTAssertEqual(status.instance?.port, 8005)
        XCTAssertEqual(status.instance?.startedAt, 1_758_700_000.0)
    }
    
    func testEveryModelledFieldIsPopulatedByTheRealPayload() throws {
        let status = Fixtures.status(port: 8005)
        // Sonda V-4: las 11 claves modeladas existen todas en la carga útil real.
        XCTAssertNotNil(status.memoryPlan?.device?.physicalMemoryBytes)
        XCTAssertNotNil(status.memoryPlan?.device?.recommendedMaxWorkingSetBytes)
        XCTAssertNotNil(status.memoryPlan?.model?.maximumContextTokens)
        XCTAssertNotNil(status.memoryPlan?.budget?.hardBudgetBytes)
        XCTAssertNotNil(status.memoryActual?.currentBytes)
        XCTAssertNotNil(status.memoryActual?.peakBytes)
        XCTAssertNotNil(status.memoryGovernor?.limitBytes)
        XCTAssertNotNil(status.memoryGovernor?.systemPressure)
        XCTAssertNotNil(status.cache?.hitRate)
        XCTAssertNotNil(status.cache?.reusedTokens)
        XCTAssertNotNil(status.scheduler?.decoding)
        XCTAssertNotNil(status.requests?.completed)
        XCTAssertNotNil(status.metrics?.decodeTokensPerSecond)
        XCTAssertNotNil(status.metrics?.ttftMs?.p50)
    }
    
    /// Valores medidos en la auditoría: prefill 763 tok/s, decodificación 42,5 tok/s.
    func testMetricValuesMatchTheAuditedPayload() throws {
        let metrics = try XCTUnwrap(Fixtures.status(port: 8005).metrics)
        XCTAssertEqual(try XCTUnwrap(metrics.prefillTokensPerSecond), 763.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(metrics.decodeTokensPerSecond), 42.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(metrics.draftAcceptanceRate), 0.8, accuracy: 0.001)
        XCTAssertEqual(metrics.decodeOutputTokens, 2048)
    }
    
    func testMissingOptionalSectionsDecodeToNil() throws {
        let minimal = Data(#"{ "ready": false }"#.utf8)
        let status = try JSONDecoder().decode(SplashStatus.self, from: minimal)
        XCTAssertEqual(status.ready, false)
        XCTAssertNil(status.instance)
        XCTAssertNil(status.metrics)
        XCTAssertNil(status.cache)
    }
    
    /// Formateadores del servicio sobre la carga útil auditada.
    @MainActor
    func testFormattedMetricsFromAuditedPayload() throws {
        let service = SplashService(transport: StubStatusTransport(),
                                    terminator: RecordingServerTerminator(),
                                    pollInterval: 30,
                                    dataDirectoryRoot: FileManager.default.temporaryDirectory,
                                    bootstrapNetwork: false)
        service.status = Fixtures.status(port: 8005)
        XCTAssertEqual(service.formattedDecodeSpeed, "42.5")
        XCTAssertEqual(service.formattedPrefillSpeed, "763.5")
        XCTAssertEqual(service.formattedCacheHitRate, "93.3%")
        XCTAssertEqual(service.formattedTokensDecode, "2.0K")
        XCTAssertEqual(service.formattedMemoryUsed, "2.5 GB")
        XCTAssertEqual(service.formattedMemoryLimit, "26.0 GB")
        XCTAssertEqual(service.memoryUsageRatio, 0.0963, accuracy: 0.001)
    }
}
