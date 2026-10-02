import Foundation

// MARK: - Ficheros de bloqueo del motor (P-08 / H-07)

/// Acceso a los ficheros de bloqueo que escribe el motor Splash.
///
/// La app leía `runtime/serve.lock`, pero el motor 1.0.2 escribe
/// `runtime/serve-<puerto>.lock`. Verificado en el equipo auditado: `serve.lock`
/// tenía 0 bytes (la decodificación siempre fallaba y `readLockPid()` devolvía `nil`),
/// mientras `serve-8005.lock` contenía el PID real y `serve-8008.lock` guardaba un PID
/// ya muerto que nadie limpiaba.
public enum ServeLockStore {
    /// Nombres candidatos, en orden de preferencia.
    public static func candidateFileNames(port: Int) -> [String] {
        ["serve-\(port).lock", "serve.lock"]
    }

    /// Decodifica un bloqueo ignorando ficheros vacíos o corruptos.
    public static func decode(_ data: Data?) -> ServeLock? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(ServeLock.self, from: data)
    }

    /// Un bloqueo es utilizable si declara un PID vivo.
    public static func isUsable(_ lock: ServeLock?, port: Int, pidAlive: (Int32) -> Bool) -> Bool {
        guard let lock, lock.pid > 0 else { return false }
        guard lock.port == port else { return false }
        return pidAlive(Int32(lock.pid))
    }

    /// Un bloqueo es basura si su PID no existe y ya no puede estar arrancando
    /// (margen de 5 minutos para no borrar el bloqueo de un motor en arranque lento).
    public static func isStale(_ lock: ServeLock?,
                               pidAlive: Bool,
                               age: TimeInterval,
                               maxAge: TimeInterval = 300) -> Bool {
        guard let lock, lock.pid > 0 else { return true }
        return !pidAlive && age > maxAge
    }
}
