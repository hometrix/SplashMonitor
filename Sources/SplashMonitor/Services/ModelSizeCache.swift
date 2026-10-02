import Foundation

// MARK: - Caché de tamaños de modelo (P-12 / H-13)

/// Evita recorrer el árbol de modelos en cada ciclo de sondeo.
///
/// `checkServerStatus()` llamaba a `refreshInstalledModels()` cada 1,5 s, y esa función
/// recorría el árbol completo resolviendo symlinks y pidiendo atributos por fichero,
/// desde el `@MainActor`. Medido sobre los modelos reales del equipo auditado
/// (3 modelos, 215 ficheros, 55,7 GB resueltos): 7,5 ms por ciclo → 430 s de E/S
/// síncrona acumulada en 24 h de app abierta.
///
/// La caché se invalida cuando cambia la fecha de modificación del enlace del modelo,
/// y explícitamente al instalar o eliminar un modelo.
public struct ModelSizeCache {
    private struct Entry {
        let size: Int64
        let stamp: Date?
        let computedAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let ttl: TimeInterval

    public init(ttl: TimeInterval = 900) {
        self.ttl = ttl
    }

    public var count: Int { entries.count }

    /// Devuelve el tamaño cacheado o lo calcula con `compute`.
    public mutating func size(repoId: String,
                              stamp: Date?,
                              now: Date = Date(),
                              compute: () -> Int64) -> Int64 {
        if let entry = entries[repoId],
           entry.stamp == stamp,
           now.timeIntervalSince(entry.computedAt) < ttl {
            return entry.size
        }
        let size = compute()
        entries[repoId] = Entry(size: size, stamp: stamp, computedAt: now)
        return size
    }

    public mutating func invalidate(repoId: String) {
        entries.removeValue(forKey: repoId)
    }

    public mutating func invalidateAll() {
        entries.removeAll()
    }
}
