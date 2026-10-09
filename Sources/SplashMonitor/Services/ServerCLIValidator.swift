import Foundation

/// Validador y tokenizador para argumentos y flags CLI arbitrarios proporcionados por el usuario
/// para el comando `splash serve`.
/// Aplica controles estrictos contra inyecciones de shell (P-03 / H-03).
public enum ServerCLIValidator {
    
    /// Caracteres seguros permitidos en los argumentos CLI adicionales.
    /// Cubre banderas (--no-webui), identificadores (incoai/model:variant), valores numéricos (50GB, 0.7),
    /// rutas seguras (/tmp/cache) y pares clave-valor (--opt=val).
    private static let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./:=,%")
    
    /// Metacaracteres de shell estrictamente prohibidos para prevenir inyección de comandos.
    private static let dangerousCharacters = CharacterSet(charactersIn: ";|&$`\"'<>!()\n\r\t{}[]*?^~#")
    
    /// Valida y descompone la cadena de argumentos en tokens seguros.
    /// - Parameter raw: Cadena de texto introducida por el usuario (ej. `--no-webui --max-cache-disk 50GB`).
    /// - Returns: Tupla con la lista de tokens seguros y un mensaje de error si no es válida.
    public static func validateAndTokenize(_ raw: String) -> (tokens: [String], error: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ([], nil)
        }
        
        // Comprobación de metacaracteres peligrosos
        if trimmed.unicodeScalars.contains(where: { dangerousCharacters.contains($0) }) {
            return ([], "Caracteres peligrosos de shell detectados en los flags CLI.")
        }
        
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var validTokens: [String] = []
        
        for part in parts {
            guard part.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) else {
                return ([], "El argumento '\(part)' contiene caracteres no válidos.")
            }
            validTokens.append(part)
        }
        
        return (validTokens, nil)
    }
    
    /// Devuelve una cadena saneada con los flags válidos separados por espacio, o cadena vacía si hay error.
    public static func sanitizedString(_ raw: String) -> String {
        let (tokens, error) = validateAndTokenize(raw)
        guard error == nil else { return "" }
        return tokens.joined(separator: " ")
    }
}
