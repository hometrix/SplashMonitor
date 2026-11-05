import Foundation

// MARK: - Propiedad del motor al salir

/// Decide si el motor en ejecución lo arrancó esta app.
///
/// `applicationWillTerminate` detenía cualquier motor encontrado por puerto o lock,
/// también uno lanzado desde un terminal o un script. La app siempre arranca el motor
/// a través de su `start_splash.command`, que sigue siendo el proceso padre del motor
/// mientras este vive (el lanzador hace `exec`, así que el PID del lock es hijo directo
/// del script). Un motor sin ese script entre sus antecesores no es de la app.
public enum ServerOwnership {
    /// Niveles de antecesores que se revisan antes de rendirse.
    public static let maxDepth = 8

    /// `true` si algún antecesor de `pid` ejecuta `scriptPath`.
    /// - Parameter process: devuelve `(ppid, comando)` de un PID, o `nil` si no existe.
    public static func isLaunchedByApp(pid: Int,
                                       scriptPath: String,
                                       process: (Int) -> (ppid: Int, command: String)?) -> Bool {
        guard pid > 1, !scriptPath.isEmpty else { return false }
        var current = pid
        for _ in 0..<maxDepth {
            guard let info = process(current), info.ppid > 1 else { return false }
            guard let parent = process(info.ppid) else { return false }
            if parent.command.contains(scriptPath) { return true }
            current = info.ppid
        }
        return false
    }

    /// `(ppid, comando)` de un PID real vía `ps`.
    public static func psInfo(_ pid: Int) -> (ppid: Int, command: String)? {
        let output = CommandRunner.run("/bin/ps", ["-o", "ppid=,command=", "-p", "\(pid)"])
            .output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else { return nil }
        let parts = output.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let ppid = parts.first.flatMap({ Int($0) }) else { return nil }
        return (ppid, parts.count > 1 ? String(parts[1]) : "")
    }
}
