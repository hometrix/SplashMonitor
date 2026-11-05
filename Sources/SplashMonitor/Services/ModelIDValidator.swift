import Foundation

// MARK: - Validación de identificadores de modelo (P-03 / H-03)

/// Valida identificadores `owner/repo` antes de interpolarlos en un script de shell.
///
/// `startServer()` construía `splash serve --model "\(model)"` dentro de un fichero
/// `.command` que después ejecutaba `/bin/bash`. Un modelo con comillas cerraba el
/// entrecomillado y permitía ejecutar comandos arbitrarios (verificado: un payload
/// `incoai/x" ; touch /tmp/testigo ; echo "` creó el fichero testigo).
///
/// Las reglas replican las restricciones que el propio motor impone a los alias de
/// modelo (`DEVELOPMENT.md` §API model aliases): sin espacios, sin caracteres de
/// control, sin `\`, `%`, `?`, `#`, y sin segmentos vacíos, `.` o `..`.
public enum ModelIDValidator {
    public static let maxOwnerLength = 64
    public static let maxRepositoryLength = 96
    public static let maxVariantLength = 64

    private static let forbiddenCharacters = CharacterSet(charactersIn: " \t\n\r\\%?#\"'`;&|$<>(){}[]*!~^=")
        .union(.controlCharacters)
        .union(.illegalCharacters)

    public static func isValid(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.rangeOfCharacter(from: forbiddenCharacters) == nil else { return false }

        let segments = value.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.count == 2 else { return false }

        let owner = String(segments[0])
        let repoSegment = String(segments[1])
        guard !owner.isEmpty, !repoSegment.isEmpty,
              owner.count <= maxOwnerLength,
              owner != ".", owner != ".." else { return false }

        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard owner.unicodeScalars.allSatisfy(allowed.contains) else { return false }

        // Soporte de variantes oficiales de Splash: OWNER/REPO[:VARIANT] (ej. :UD-Q4_K_XL, :Q4_K_M)
        let repoParts = repoSegment.split(separator: ":", omittingEmptySubsequences: false)
        guard repoParts.count <= 2 else { return false }

        let repository = String(repoParts[0])
        guard !repository.isEmpty,
              repository.count <= maxRepositoryLength,
              repository != ".", repository != "..",
              repository.unicodeScalars.allSatisfy(allowed.contains) else { return false }

        if repoParts.count == 2 {
            let variant = String(repoParts[1])
            guard !variant.isEmpty,
                  variant.count <= maxVariantLength,
                  variant != ".", variant != "..",
                  variant.unicodeScalars.allSatisfy(allowed.contains) else { return false }
        }

        return true
    }

    /// Recorta espacios y devuelve `nil` si el identificador no es válido.
    /// Identificador con el que se lanza (e instala) un modelo.
    /// Splash 1.4.0 solo carga Flash-Next desde GGUF con variante, así que el repositorio
    /// base de pesos crudos 'Qwen/Qwen3.8-Flash-Next' se mapea a la cuantización GGUF oficial.
    public static func launchModelId(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = value.lowercased()
        if lower == "qwen/qwen3.8-flash-next" || lower == "qwen3.8-flash-next" {
            return "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:Q2_0"
        }
        return value
    }

    public static func normalized(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return isValid(value) ? value : nil
    }

    /// Desglosa el identificador en sus componentes (owner, repository, variant opcional).
    public static func components(from raw: String) -> (owner: String, repository: String, variant: String?)? {
        guard let valid = normalized(raw) else { return nil }
        let segments = valid.split(separator: "/")
        let owner = String(segments[0])
        let repoParts = segments[1].split(separator: ":")
        let repository = String(repoParts[0])
        let variant = repoParts.count > 1 ? String(repoParts[1]) : nil
        return (owner, repository, variant)
    }

    /// Devuelve el identificador base `owner/repository` sin el sufijo `:variante`.
    public static func baseModelId(_ raw: String) -> String? {
        guard let comp = components(from: raw) else { return nil }
        return "\(comp.owner)/\(comp.repository)"
    }

    /// Indica si el identificador incluye una variante `:VARIANTE`.
    public static func hasVariant(_ raw: String) -> Bool {
        return components(from: raw)?.variant != nil
    }

    /// Motivo legible para mostrar al usuario en la interfaz.
    public static func rejectionReason(_ raw: String, isSpanish: Bool? = nil) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let spanish = isSpanish ?? (UserDefaults.standard.string(forKey: "appLanguageMode") != "en")
        if value.isEmpty {
            return spanish ? "El identificador está vacío." : "The model identifier is empty."
        }
        if isValid(value) { return nil }
        if !value.contains("/") {
            return spanish
                ? "Falta el separador: usa el formato propietario/modelo o propietario/modelo:variante."
                : "Missing separator: use format owner/model or owner/model:variant."
        }
        let segments = value.split(separator: "/", omittingEmptySubsequences: false)
        if segments.count != 2 {
            return spanish
                ? "El formato debe ser propietario/modelo[:variante] (un solo separador '/')."
                : "Format must be owner/model[:variant] (exactly one '/' separator)."
        }
        if value.rangeOfCharacter(from: forbiddenCharacters) != nil {
            return spanish
                ? "Contiene caracteres no permitidos (espacios, comillas, ; | & $ ` \\ % ? # …)."
                : "Contains forbidden characters (spaces, quotes, ; | & $ ` \\ % ? # …)."
        }
        let repoSegment = String(segments[1])
        let repoParts = repoSegment.split(separator: ":", omittingEmptySubsequences: false)
        if repoParts.count > 2 {
            return spanish
                ? "Demasiados separadores de variante ':' (máximo uno permitido)."
                : "Too many variant ':' separators (maximum one allowed)."
        }
        if repoParts.count == 2 && repoParts[1].isEmpty {
            return spanish
                ? "La variante tras ':' no puede estar vacía."
                : "Variant following ':' cannot be empty."
        }
        return spanish
            ? "Solo se admiten letras, dígitos, punto, guion y guion bajo (y ':' para variantes)."
            : "Only letters, digits, dots, hyphens, and underscores are allowed (and ':' for variants)."
    }
}
