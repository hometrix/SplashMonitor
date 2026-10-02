import Foundation

// MARK: - Transporte de estado (para poder probar el ciclo de sondeo sin motor real)

/// Contrato mínimo que necesita `SplashService` para consultar el estado del motor.
/// Inyectarlo permite que las pruebas ejerciten el ciclo de sondeo (P-02) sin un
/// servidor real y sin lanzar procesos.
public protocol StatusTransport: Sendable {
    func fetchStatus(port: Int, timeout: TimeInterval) async -> SplashStatus?
}

/// Implementación de producción: `GET http://127.0.0.1:<puerto>/status`.
public struct URLSessionStatusTransport: StatusTransport {
    public init() {}

    public func fetchStatus(port: Int, timeout: TimeInterval) async -> SplashStatus? {
        guard let url = URL(string: "http://127.0.0.1:\(port)/status") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(SplashStatus.self, from: data) else {
            return nil
        }
        return decoded
    }
}
