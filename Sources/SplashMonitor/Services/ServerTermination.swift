import Foundation
import AppKit

// MARK: - Ejecución de comandos externos

public struct CommandResult: Sendable {
    public let status: Int32
    public let output: String
    public var succeeded: Bool { status == 0 }

    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }
}

/// Envoltorio delgado sobre `Process` para comandos de inspección cortos.
///
/// Lectura del pipe antes de `waitUntilExit()` para no bloquearse si la salida
/// supera el búfer interno de 64 KB (caso real: `lsof` con muchas conexiones).
public enum CommandRunner {
    @discardableResult
    public static func run(_ executable: String, _ arguments: [String]) -> CommandResult {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            return CommandResult(status: -1, output: "")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return CommandResult(status: -1, output: "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus,
                             output: String(data: data, encoding: .utf8) ?? "")
    }
}

// MARK: - Terminación del motor (P-01 / P-06 / H-02 y H-04)

/// Operaciones destructivas sobre procesos del motor, aisladas tras un protocolo
/// para que las pruebas nunca envíen señales reales.
public protocol ServerTerminating: Sendable {
    /// Detiene el motor en `port` de forma ordenada y verificada.
    func stopEngine(port: Int, candidatePids: [Int32]) async
    /// Variante síncrona para `applicationWillTerminate`.
    func stopEngineSynchronously(port: Int, candidatePids: [Int32])
}

/// Implementación endurecida: solo escuchas verificadas del motor, escalada
/// INT → TERM → KILL, sin `pkill -f` genérico.
public struct HardenedServerTerminator: ServerTerminating {
    public init() {}

    private static let lsof = "/usr/sbin/lsof"
    private static let ps = "/bin/ps"

    /// PIDs que escuchan en el puerto y cuyo comando pertenece al motor.
    static func verifiedEnginePIDs(port: Int) -> [Int32] {
        let listing = CommandRunner.run(lsof, ["-tiTCP:\(port)", "-sTCP:LISTEN"])
        return KillTargetResolver.enginePIDsToStop(lsofOutput: listing.output) { pid in
            let result = CommandRunner.run(ps, ["-p", "\(pid)", "-o", "command="])
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Filtra PIDs candidatos (de `/status` o del fichero de bloqueo) verificando identidad.
    static func verified(_ pids: [Int32]) -> [Int32] {
        var seen = Set<Int32>()
        var result: [Int32] = []
        for pid in pids where pid > 0 && !seen.contains(pid) {
            seen.insert(pid)
            let command = CommandRunner.run(ps, ["-p", "\(pid)", "-o", "command="])
                .output.trimmingCharacters(in: .whitespacesAndNewlines)
            if SplashEngineIdentity.isEngineCommand(command) { result.append(pid) }
        }
        return result
    }

    private static func portIsListening(_ port: Int) -> Bool {
        let listing = CommandRunner.run(lsof, ["-tiTCP:\(port)", "-sTCP:LISTEN"])
        return !ListerOutput.listeningPIDs(listing.output).isEmpty
    }

    public func stopEngine(port: Int, candidatePids: [Int32]) async {
        var targets = Set(Self.verifiedEnginePIDs(port: port))
        targets.formUnion(Self.verified(candidatePids))
        guard !targets.isEmpty else { return }

        for pid in targets { kill(pid, SIGINT) }
        for _ in 0..<30 {
            if !Self.portIsListening(port) { return }
            try? await Task.sleep(nanoseconds: 100_000_000)   // hasta 3 s
        }

        for pid in Self.verifiedEnginePIDs(port: port) { kill(pid, SIGTERM) }
        for _ in 0..<10 {
            if !Self.portIsListening(port) { return }
            try? await Task.sleep(nanoseconds: 100_000_000)   // hasta 1 s adicional
        }

        // Último recurso: solo PIDs reverificados como motor.
        for pid in Self.verifiedEnginePIDs(port: port) { kill(pid, SIGKILL) }
    }

    public func stopEngineSynchronously(port: Int, candidatePids: [Int32]) {
        var targets = Set(Self.verifiedEnginePIDs(port: port))
        targets.formUnion(Self.verified(candidatePids))
        for pid in targets { kill(pid, SIGTERM) }
    }
}

// MARK: - Terminación de aplicaciones cliente (P-04 / H-05)

/// Decisión pura de si es lícito terminar una app cliente.
public enum ClientTerminationPolicy {
    /// Requisitos: el PID sigue existiendo, es la misma aplicación y no es el monitor.
    public static func canTerminate(pid: Int32,
                                    recordedBundleID: String?,
                                    currentBundleID: String?,
                                    currentName: String?,
                                    isRunning: Bool,
                                    ownBundleID: String?) -> Bool {
        guard isRunning, pid > 0 else { return false }
        if let own = ownBundleID, let current = currentBundleID, own == current { return false }
        guard let record = recordedBundleID, !record.isEmpty else {
            // Sin bundle identificado solo se admite si el nombre sigue coincidiendo.
            return currentName != nil
        }
        return currentBundleID == record
    }
}
