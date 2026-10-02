import Foundation
import XCTest
@testable import SplashMonitor

// MARK: - Utilidades comunes de prueba

/// Directorio temporal aislado, eliminado al liberar el objeto.
/// Ninguna prueba escribe en el `$HOME` real ni en el directorio de datos de la app.
final class TempDirectory {
    let url: URL
    
    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("splashmonitor-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    deinit {
        try? FileManager.default.removeItem(at: url)
    }
    
    func file(_ name: String) -> URL { url.appendingPathComponent(name) }
    
    @discardableResult
    func write(_ contents: String, to name: String) throws -> URL {
        let target = file(name)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try contents.write(to: target, atomically: true, encoding: .utf8)
        return target
    }
    
    func read(_ name: String) -> String? { try? String(contentsOf: file(name), encoding: .utf8) }
    
    func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: file(name).path) }
}

// MARK: - Dobles de prueba

/// Transporte de estado programable: sin red, sin motor.
final class StubStatusTransport: StatusTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var statuses: [Int: SplashStatus] = [:]
    private var queried: [Int] = []
    
    var queriedPorts: [Int] {
        lock.withLock { queried }
    }
    
    func setStatus(_ status: SplashStatus?, for port: Int) {
        lock.withLock { statuses[port] = status }
    }
    
    func fetchStatus(port: Int, timeout: TimeInterval) async -> SplashStatus? {
        // `withLock` es la forma admitida en contextos asíncronos (Swift 6).
        lock.withLock {
            queried.append(port)
            return statuses[port]
        }
    }
}

/// Terminador que registra las peticiones **sin enviar ninguna señal real**.
final class RecordingServerTerminator: ServerTerminating, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [(port: Int, pids: [Int32])] = []
    
    var calls: [(port: Int, pids: [Int32])] {
        lock.withLock { recorded }
    }
    
    func stopEngine(port: Int, candidatePids: [Int32]) async {
        record(port: port, pids: candidatePids)
    }
    
    func stopEngineSynchronously(port: Int, candidatePids: [Int32]) {
        record(port: port, pids: candidatePids)
    }
    
    private func record(port: Int, pids: [Int32]) {
        lock.withLock { recorded.append((port, pids)) }
    }
}

// MARK: - Fixtures

/// Cargas útiles tomadas del motor real (auditoría v1.0.2) y simplificadas a los
/// campos que la app modela, más una clave desconocida para comprobar tolerancia.
enum Fixtures {
    static func statusJSON(port: Int,
                           model: String = "incoai/Qwen3.8-27B-Splash",
                           pid: Int = 4242,
                           ready: Bool = true) -> String {
        """
        {
          "ready": \(ready),
          "maximum_context_tokens": 262144,
          "memory_pressure": "nominal",
          "instance": {
            "id": "832f0b6e-1c1f-4d3f-9f0a-2a1b3c4d5e6f",
            "pid": \(pid),
            "model": "\(model)",
            "host": "127.0.0.1",
            "port": \(port),
            "started_at": 1758700000.0
          },
          "memory_plan": {
            "device": {
              "device_name": "Apple M4 Max",
              "macos_version": "26.4",
              "gpu_core_count": 40,
              "physical_memory_bytes": 38654705664,
              "recommended_max_working_set_bytes": 27917287424
            },
            "model": { "model_name": "\(model)", "maximum_context_tokens": 262144, "attention_layers": 48 },
            "budget": { "physical_memory_bytes": 38654705664, "hard_budget_bytes": 27000000000 }
          },
          "memory_actual": { "current_bytes": 2690000000, "peak_bytes": 3010000000, "dense_bytes": 2400000000, "sparse_resident_bytes": 290000000 },
          "memory_governor": {
            "limit_bytes": 27917287424,
            "observed_resident_bytes": 2690000000,
            "headroom_bytes": 25227287424,
            "system_pressure": "nominal",
            "host_available_bytes": 31000000000
          },
          "cache": { "lookups": 10, "hits": 9, "cold_misses": 1, "hit_rate": 0.933, "reused_tokens": 4200, "kv_hit_tokens": 3900 },
          "scheduler": { "queued": 0, "prefilling": 0, "decoding": 1, "prefill_batches": 3, "decode_batches": 40 },
          "requests": { "submitted": 5, "completed": 4, "cancelled": 0, "failed": 0 },
          "metrics": {
            "prefill_input_tokens": 1336,
            "prefill_tokens_per_second": 763.5,
            "decode_output_tokens": 2048,
            "decode_tokens_per_second": 42.5,
            "drafted_tokens": 100,
            "accepted_draft_tokens": 80,
            "draft_acceptance_rate": 0.8,
            "ttft_ms": { "p50": 282.0, "p95": 401.0, "samples": 5 },
            "itl_ms": { "p50": 23.0, "p95": 31.0, "samples": 5 }
          },
          "clave_desconocida_de_una_version_futura": { "anidada": true, "n": 7 }
        }
        """
    }
    
    static func status(port: Int,
                       model: String = "incoai/Qwen3.8-27B-Splash",
                       pid: Int = 4242,
                       ready: Bool = true) -> SplashStatus {
        let data = Data(statusJSON(port: port, model: model, pid: pid, ready: ready).utf8)
        // La fixture es fija: un fallo aquí es un fallo de la prueba, no del entorno.
        return try! JSONDecoder().decode(SplashStatus.self, from: data)
    }
    
    static func lockData(pid: Int, model: String = "incoai/Qwen3.8-27B-Splash", port: Int) -> Data {
        Data("""
        { "pid": \(pid), "model": "\(model)", "port": \(port) }
        """.utf8)
    }
}

// MARK: - Esperas

/// Espera activa hasta que se cumpla `condition`, con límite de tiempo.
@MainActor
func waitUntil(timeout: TimeInterval = 5.0, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    return condition()
}
