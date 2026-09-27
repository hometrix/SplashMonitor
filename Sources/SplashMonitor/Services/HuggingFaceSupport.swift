import Foundation
import Security

// MARK: - Keychain-backed token storage

/// Stores the Hugging Face access token in the macOS Keychain.
///
/// The token is **never** written to `UserDefaults`, never echoed into the install
/// log and never printed by this type. Anything that crosses into `installLogs`
/// must go through `HuggingFaceSupport.redact(_:token:)` first.
public enum HFTokenStore {
    /// Keychain service name required by the spec.
    public static let keychainService = "SplashMonitor.hf"
    /// Keychain account the token is stored under.
    public static let keychainAccount = "hf_token"

    /// Add (or replace) the token. Returns `errSecSuccess` on success.
    ///
    /// The item is stored in the login keychain (the legacy, file-based one):
    /// the data-protection keychain would require a `keychain-access-groups`
    /// entitlement that an ad-hoc signed app does not carry.
    @discardableResult
    public static func save(_ token: String) -> OSStatus {
        guard let data = token.data(using: .utf8) else { return errSecParam }
        // Delete first so the ACL is re-created for the current binary and no
        // duplicate generic-password items can accumulate.
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrLabel as String] = "Splash Monitor — Hugging Face token"
        return SecItemAdd(query as CFDictionary, nil)
    }

    /// Read the stored token, or nil when absent.
    public static func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Remove the token from the Keychain.
    @discardableResult
    public static func delete() -> OSStatus {
        SecItemDelete(baseQuery as CFDictionary)
    }

    /// A safe, non-reversible preview of a token: `hf_••••cdef`.
    public static func masked(_ token: String) -> String {
        guard token.count > 4 else { return "hf_••••" }
        return "hf_••••\(token.suffix(4))"
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
    }
}

// MARK: - Token validation result

/// Outcome of `https://huggingface.co/api/whoami-v2`.
public enum HFTokenTestResult: Equatable {
    /// No token configured yet.
    case noToken
    /// The token is valid; `user` is the Hugging Face account name.
    case success(user: String)
    /// Hugging Face rejected the token (401/403).
    case invalidToken(statusCode: Int)
    /// Transport or decoding failure.
    case networkError(String)
}

// MARK: - Environment helpers

/// Everything the app needs to talk to Hugging Face on the engine's behalf.
public enum HuggingFaceSupport {
    /// PATH injected into spawned engine processes (the app inherits launchd's minimal PATH).
    public static let defaultPATH =
        "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    /// `whoami-v2` endpoint used by the "Test token" button.
    public static let whoamiURL = URL(string: "https://huggingface.co/api/whoami-v2")!

    /// Page where the user creates a read token.
    public static let tokenSettingsURL = URL(string: "https://huggingface.co/settings/tokens")!

    /// True when the engine's Python environment can import `hf_transfer`.
    ///
    /// Blocking: spawns the interpreter once. Call it off the main thread.
    public static func isHFTransferInstalled(pythonPath: String) -> Bool {
        guard !pythonPath.isEmpty, FileManager.default.isExecutableFile(atPath: pythonPath) else {
            return false
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = ["-c", "import hf_transfer"]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = defaultPATH
        proc.environment = env
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Environment for the Splash `prepare` downloader: the inherited environment
    /// plus an explicit PATH and the Hugging Face variables.
    ///
    /// `HF_HUB_ENABLE_HF_TRANSFER` is only enabled when `hf_transfer` is really
    /// importable — enabling it without the package makes `huggingface_hub` fail,
    /// so it is explicitly disabled otherwise (a user's shell may have set it).
    public static func downloaderEnvironment(token: String?, transfersEnabled: Bool) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = defaultPATH
        if let token, !token.isEmpty {
            env["HF_TOKEN"] = token
            // Older `huggingface_hub` releases only read HUGGING_FACE_HUB_TOKEN.
            env["HUGGING_FACE_HUB_TOKEN"] = token
        }
        env["HF_HUB_ENABLE_HF_TRANSFER"] = transfersEnabled ? "1" : "0"
        env["HF_HUB_DISABLE_TELEMETRY"] = "1"
        return env
    }

    /// On-disk location of a single repo inside the Hugging Face hub cache.
    /// Returns nil for a malformed repo id or a custom `HF_HUB_CACHE`.
    public static func hubCacheDirectory(forRepo repoId: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        guard repoId.contains("/") else { return nil }
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // Respect an explicit cache location when one is configured.
        if let custom = environment["HF_HUB_CACHE"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath)
                .appendingPathComponent("models--\(repoId.replacingOccurrences(of: "/", with: "--"))")
        }
        if let hfHome = environment["HF_HOME"], !hfHome.isEmpty {
            return URL(fileURLWithPath: (hfHome as NSString).expandingTildeInPath)
                .appendingPathComponent("hub")
                .appendingPathComponent("models--\(repoId.replacingOccurrences(of: "/", with: "--"))")
        }
        return home
            .appendingPathComponent(".cache/huggingface/hub")
            .appendingPathComponent("models--\(repoId.replacingOccurrences(of: "/", with: "--"))")
    }

    /// Total size of the files under `url` (0 when missing). Symlinks are not followed.
    public static func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return 0 }
        var total: Int64 = 0
        if let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if let size = values?.fileSize {
                    total += Int64(size)
                }
            }
        } else if let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int64 {
            total = size
        }
        return total
    }

    /// Heuristic for a rejected download: 401/403, gated or private repo messages.
    /// Used to turn an opaque exit code into an actionable hint.
    public static func indicatesAuthFailure(_ line: String) -> Bool {
        let lower = line.lowercased()
        let markers = [
            "401", "403",
            "unauthorized", "forbidden",
            "gated", "requires authentication", "authentication required",
            "invalid credentials", "access to model", "restricted",
            "repository not found", "private or gated"
        ]
        return markers.contains { lower.contains($0) }
    }

    /// Replaces every occurrence of the token with a fixed redaction marker.
    public static func redact(_ text: String, token: String?) -> String {
        guard let token, token.count >= 6, text.contains(token) else { return text }
        return text.replacingOccurrences(of: token, with: "hf_***REDACTED***")
    }

    /// Human-readable byte count for the install log.
    public static func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Human-readable throughput for the install log.
    public static func formattedSpeed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "0 B/s" }
        // ByteCountFormatter appends "/s" when the countStyle is a rate style.
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }
}

// MARK: - Download speed sampling

/// Samples how fast the Hugging Face cache for one repo grows on disk, which —
/// unlike parsing the downloader's progress bars — works for every download
/// backend (`requests`, `hf_transfer`, `xet`).
public final class HFDownloadSpeedSampler {
    /// One measurement taken every `interval` seconds.
    public struct Sample {
        /// Bytes downloaded during this run (baseline excluded).
        public let downloadedBytes: Int64
        /// Throughput since the previous sample.
        public let bytesPerSecond: Double
        /// Highest throughput seen so far.
        public let peakBytesPerSecond: Double
        /// Seconds elapsed since `start()`.
        public let elapsed: TimeInterval
    }

    /// Totals reported by `stop()`.
    public struct Summary {
        /// Bytes downloaded during this run (baseline excluded).
        public let downloadedBytes: Int64
        /// Seconds elapsed since `start()`.
        public let elapsed: TimeInterval
        /// Mean throughput over the whole run.
        public let averageBytesPerSecond: Double
        /// Highest throughput seen during the run.
        public let peakBytesPerSecond: Double
    }

    private let directory: URL
    private let interval: TimeInterval
    private let stateQueue = DispatchQueue(label: "com.splashmonitor.hf.speed-sampler")
    private var timer: DispatchSourceTimer?
    private var startedAt = Date()
    private var lastSampleAt = Date()
    private var baselineBytes: Int64 = 0
    private var lastBytes: Int64 = 0
    private var peak: Double = 0
    private var currentBytes: Int64 = 0
    private var onSample: ((Sample) -> Void)?

    /// - Parameters:
    ///   - directory: the repo's Hugging Face cache directory to watch.
    ///   - interval: seconds between samples.
    public init(directory: URL, interval: TimeInterval = 2.0) {
        self.directory = directory
        self.interval = interval
    }

    /// Baseline size before the download starts (a resumed install is not counted twice).
    public func start(onSample: @escaping (Sample) -> Void) {
        stateQueue.sync {
            let baseline = HuggingFaceSupport.directorySize(directory)
            let now = Date()
            startedAt = now
            lastSampleAt = now
            baselineBytes = baseline
            lastBytes = baseline
            currentBytes = baseline
            peak = 0
            self.onSample = onSample

            let source = DispatchSource.makeTimerSource(queue: stateQueue)
            source.schedule(deadline: .now() + interval, repeating: interval)
            source.setEventHandler { [weak self] in self?.tick() }
            timer = source
            source.resume()
        }
    }

    /// Stops sampling and returns what was downloaded during this run.
    @discardableResult
    public func stop() -> Summary {
        stateQueue.sync {
            timer?.cancel()
            timer = nil
            onSample = nil
            let elapsed = Date().timeIntervalSince(startedAt)
            let downloaded = max(0, currentBytes - baselineBytes)
            let average = elapsed > 0 ? Double(downloaded) / elapsed : 0
            return Summary(
                downloadedBytes: downloaded,
                elapsed: elapsed,
                averageBytesPerSecond: average,
                peakBytesPerSecond: peak
            )
        }
    }

    /// Bytes downloaded so far (baseline excluded).
    public var downloadedBytes: Int64 {
        stateQueue.sync { max(0, currentBytes - baselineBytes) }
    }

    private func tick() {
        let bytes = HuggingFaceSupport.directorySize(directory)
        let now = Date()
        let deltaSeconds = now.timeIntervalSince(lastSampleAt)
        let deltaBytes = bytes - lastBytes
        var rate = 0.0
        if deltaSeconds > 0 {
            rate = Double(deltaBytes) / deltaSeconds
        }
        if rate > peak { peak = rate }
        lastBytes = bytes
        lastSampleAt = now
        currentBytes = bytes
        let sample = Sample(
            downloadedBytes: max(0, bytes - baselineBytes),
            bytesPerSecond: rate,
            peakBytesPerSecond: peak,
            elapsed: now.timeIntervalSince(startedAt)
        )
        onSample?(sample)
    }
}
