import Foundation

// MARK: - Fuente única de versión (P-15)

/// Única ubicación de la versión del proyecto.
///
/// `scripts/build_app.sh`, `scripts/create_dmg.sh` y `scripts/install.sh` extraen este
/// literal con `sed`, de modo que la versión se declara una sola vez. Antes vivía
/// duplicada en 5 lugares (servicio, Info.plist, DMG, instalador y README) y ya había
/// divergido: el README anunciaba 1.0.0-beta mientras el binario compilaba 1.0.2-beta.
public enum SplashVersion {
    public static let current = "1.0.6-beta"
    /// Identificador de paquete propio (P-11). Antes el proyecto se anunciaba como
    /// `com.incoai.splashmonitor`, reclamando el espacio de nombres de IncoAI, del que
    /// este monitor es software independiente.
    public static let bundleIdentifier = "do.jmgrep.splashmonitor"
    /// Número de compilación para `CFBundleVersion` (debe crecer con cada publicación).
    public static let buildNumber = "7"
}

// MARK: - Comparación semántica de versiones (P-07 / H-08)

/// Versión semántica con orden correcto.
///
/// El código anterior comparaba con `String >` (orden lexicográfico), lo que hace que
/// `1.0.10-beta` se considere ANTERIOR a `1.0.2-beta` (`'1' < '2'` en el tercer
/// componente) y la app dejase de detectar actualizaciones a partir de la décima
/// revisión. Verificado con `swift -e` sobre `841014e`.
public struct SemanticVersion: Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    /// Incluye el separador: `-beta`, `-beta.2`, `+build.7`. `nil` en versiones de publicación.
    public let prerelease: String?

    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }

        let core: String
        if let index = text.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            core = String(text[text.startIndex..<index])
            let suffix = String(text[index...])
            prerelease = suffix.count > 1 ? suffix : nil
        } else {
            core = text
            prerelease = nil
        }

        let components = core.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(components.count) else { return nil }

        var numbers: [Int] = []
        for component in components {
            guard let value = Int(component), value >= 0 else { return nil }
            numbers.append(value)
        }
        while numbers.count < 3 { numbers.append(0) }

        major = numbers[0]
        minor = numbers[1]
        patch = numbers[2]
    }

    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):            return false
        case (nil, .some):          return false   // publicación > prepublicación
        case (.some, nil):          return true
        case let (.some(a), .some(b)): return a < b
        }
    }

    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
            && lhs.prerelease == rhs.prerelease
    }

    public var description: String {
        "\(major).\(minor).\(patch)" + (prerelease ?? "")
    }

    /// `true` solo si ambas cadenas se pueden parsear y `latest` es posterior a `current`.
    /// Ante una etiqueta no parseable devuelve `false` (nunca inventa una actualización).
    public static func isNewer(_ latest: String, than current: String) -> Bool {
        guard let new = SemanticVersion(latest), let old = SemanticVersion(current) else { return false }
        return new > old
    }
}
