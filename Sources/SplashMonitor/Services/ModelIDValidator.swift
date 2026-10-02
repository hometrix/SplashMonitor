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
        let repository = String(segments[1])
        guard !owner.isEmpty, !repository.isEmpty,
              owner.count <= maxOwnerLength, repository.count <= maxRepositoryLength,
              owner != ".", owner != "..", repository != ".", repository != ".." else { return false }

        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return owner.unicodeScalars.allSatisfy(allowed.contains)
            && repository.unicodeScalars.allSatisfy(allowed.contains)
    }

    /// Recorta espacios y devuelve `nil` si el identificador no es válido.
    public static func normalized(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return isValid(value) ? value : nil
    }

    /// Motivo legible para mostrar al usuario en la interfaz.
    public static func rejectionReason(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "El identificador está vacío." }
        if isValid(value) { return nil }
        if !value.contains("/") { return "Falta el separador: usa el formato propietario/modelo." }
        if value.split(separator: "/", omittingEmptySubsequences: false).count != 2 {
            return "El formato debe ser propietario/modelo (un solo separador)."
        }
        if value.rangeOfCharacter(from: forbiddenCharacters) != nil {
            return "Contiene caracteres no permitidos (espacios, comillas, ; | & $ ` \\ % ? # …)."
        }
        return "Solo se admiten letras, dígitos, punto, guion y guion bajo."
    }
}
