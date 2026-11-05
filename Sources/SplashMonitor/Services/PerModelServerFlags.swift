import Foundation

// MARK: - Flags CLI por modelo

/// Flags CLI adicionales asociados a un modelo concreto.
///
/// `customServerFlags` se aplica a todos los modelos, así que flags propios de un modelo
/// (`--model-dir`, `--mmproj`, `--draft-model`, alias) rompían el arranque de los demás.
/// Se persisten como JSON `{"<id de modelo>": "<flags>"}` y se suman a los globales
/// solo al lanzar ese modelo. La clave es el id de lanzamiento en minúsculas: los ids de
/// Hugging Face no distinguen mayúsculas, y un alias (Flash-Next) comparte flags con el id
/// que el motor ejecuta, que es el que vuelve en el lock y usa "Reiniciar".
public enum PerModelServerFlags {
    /// Decodifica el mapa persistido; JSON vacío o corrupto equivale a un mapa vacío.
    public static func decode(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return map
    }

    /// Codifica el mapa con claves ordenadas para que el valor guardado sea estable.
    public static func encode(_ map: [String: String]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(map), let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    /// Flags guardados para `model` (cadena vacía si no hay).
    public static func flags(for model: String, in json: String) -> String {
        decode(json)[key(model)] ?? ""
    }

    /// Devuelve el JSON con los flags de `model` actualizados; una cadena vacía borra la entrada.
    /// Los espacios se conservan para no alterar lo que se está escribiendo en el campo.
    public static func setting(_ flags: String, for model: String, in json: String) -> String {
        let modelKey = key(model)
        guard !modelKey.isEmpty else { return json }
        var map = decode(json)
        map[modelKey] = flags.isEmpty ? nil : flags
        return encode(map)
    }

    private static func key(_ model: String) -> String {
        ModelIDValidator.launchModelId(model).lowercased()
    }
}
