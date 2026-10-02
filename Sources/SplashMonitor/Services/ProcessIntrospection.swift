import Foundation

// MARK: - Introspección de procesos: parsers puros y política de señales

/// Una conexión TCP activa observada con `lsof`, ya interpretada.
public struct EstablishedConnection: Equatable {
    public let pid: Int32
    public let command: String
    public let remoteAddress: String

    public init(pid: Int32, command: String, remoteAddress: String) {
        self.pid = pid
        self.command = command
        self.remoteAddress = remoteAddress
    }
}

/// Interpreta la salida de `lsof` sin depender del entorno.
public enum ListerOutput {
    /// Columnas de `lsof -n -P`: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME.
    public static let minimumColumns = 9

    /// PIDs de `lsof -tiTCP:<puerto> -sTCP:LISTEN` (una columna, un PID por línea).
    public static func listeningPIDs(_ output: String) -> [Int32] {
        output
            .components(separatedBy: .newlines)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 > 0 }
    }

    /// Conexiones establecidas de `lsof -iTCP:<puerto> -sTCP:ESTABLISHED -n -P`.
    ///
    /// El parser anterior estaba escrito en línea dentro de `scanConnectedClients()`
    /// y descartaba filas con menos de 9 columnas sin dejar rastro; ahora es una
    /// función pura y comprobable.
    public static func establishedConnections(_ output: String) -> [EstablishedConnection] {
        var connections: [EstablishedConnection] = []
        for line in output.components(separatedBy: .newlines).dropFirst() {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard columns.count >= minimumColumns,
                  let pid = Int32(columns[1]), pid > 0 else { continue }
            connections.append(EstablishedConnection(
                pid: pid,
                command: columns[0],
                remoteAddress: columns[8]
            ))
        }
        return connections
    }
}

/// Decide si un proceso pertenece al motor Splash y, por tanto, si es lícito señalizarlo.
public enum SplashEngineIdentity {
    /// Marcadores del motor según su instalación de Homebrew (`libexec/server/server.py`,
    /// `libexec/engine/splash serve-native`, `bin/splash`).
    public static let engineMarkers = ["server.py", "serve-native", "/splash", "splash"]

    public static func isEngineCommand(_ command: String) -> Bool {
        let value = command.lowercased()
        guard !value.isEmpty else { return false }
        return engineMarkers.contains { value.contains($0) }
    }
}

/// Resuelve a qué PIDs es lícito enviar una señal al liberar un puerto.
///
/// Regla corregida: **solo escuchas** (`-sTCP:LISTEN`) **y** solo del motor.
/// El código anterior usaba `lsof -ti :<puerto>`, que devuelve también a los
/// clientes conectados (IDERs, agentes, navegadores) y a continuación aplicaba
/// `SIGKILL` a todos ellos. Medido: con un servidor y un cliente en procesos
/// distintos, `lsof -ti :18097` devuelve los dos PIDs, mientras que
/// `lsof -tiTCP:18097 -sTCP:LISTEN` devuelve solo el servidor.
public enum KillTargetResolver {
    /// - Parameters:
    ///   - lsofOutput: salida de `lsof -tiTCP:<puerto> -sTCP:LISTEN`.
    ///   - commandFor: resolutor del comando de cada PID (`ps -p <pid> -o command=`).
    /// - Returns: PIDs del motor que escuchan en el puerto.
    public static func enginePIDsToStop(lsofOutput: String,
                                        commandFor: (Int32) -> String?) -> [Int32] {
        ListerOutput.listeningPIDs(lsofOutput).filter { pid in
            guard let command = commandFor(pid), !command.isEmpty else { return false }
            return SplashEngineIdentity.isEngineCommand(command)
        }
    }

    /// Escalada de señales verificada: nunca SIGKILL directo.
    public enum Signal: String, Sendable {
        case interrupt = "-INT"
        case terminate = "-TERM"
        case forceKill = "-KILL"
    }

    /// Plan de escalada. El primer paso siempre es cortés; `SIGKILL` solo llega
    /// tras dos esperas fallidas y con la identidad ya verificada.
    public static let escalation: [Signal] = [.interrupt, .terminate, .forceKill]
}
