import Foundation

// MARK: - Rutas del motor (P-05 del plan 1.0.1, congelado aquí para prueba)

/// Resolución de rutas de la instalación de Homebrew.
///
/// En 1.0.1 se eliminaron las rutas con versión fija (`Cellar/splash/1.0/...`) que
/// rompían tras `brew upgrade splash`. Estas funciones concentran esa lógica para que
/// una prueba impida que vuelva una versión fija al código.
public enum SplashPaths {
    public static let brewPrefixes = ["/opt/homebrew", "/usr/local"]

    public static func brewExecutableCandidates() -> [String] {
        brewPrefixes.map { "\($0)/bin/brew" }
    }

    public static func splashExecutableCandidates() -> [String] {
        var candidates = brewPrefixes.map { "\($0)/bin/splash" }
        candidates += brewPrefixes.map { "\($0)/opt/splash/bin/splash" }
        return candidates
    }

    /// Rutas estables vía symlink de Homebrew (sin versión) más raíces de Cellar
    /// para la búsqueda comodín.
    public static func pythonCandidates() -> [String] {
        brewPrefixes.map { "\($0)/opt/splash/libexec/python/bin/python3" }
    }

    public static func modelsScriptCandidates() -> [String] {
        brewPrefixes.map { "\($0)/opt/splash/libexec/install/models.py" }
    }

    public static func cellarRoots() -> [String] {
        brewPrefixes.map { "\($0)/Cellar/splash" }
    }

    /// Directorios de versión dentro de Cellar, ordenados de forma determinista.
    public static func cellarVersions(in root: String, list: (String) -> [String]?) -> [String] {
        guard let versions = list(root) else { return [] }
        return versions.sorted()
    }

    /// Primera ruta que satisface `exists`.
    public static func firstExisting(_ candidates: [String],
                                     exists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) -> String? {
        candidates.first(where: exists)
    }

    /// Busca `<cellar>/<versión>/<subpath>` probando todas las versiones instaladas.
    public static func firstCellarCandidate(subpath: String,
                                            versions: (String) -> [String]?,
                                            exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> String? {
        for root in cellarRoots() {
            for version in cellarVersions(in: root, list: versions) {
                let candidate = "\(root)/\(version)/\(subpath)"
                if exists(candidate) { return candidate }
            }
        }
        return nil
    }
}
