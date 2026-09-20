import Foundation

// MARK: - Splash Native Status Models

public struct SplashStatus: Codable {
    public let ready: Bool?
    public let maximumContextTokens: Int?
    public let memoryPressure: String?
    public let instance: InstanceInfo?
    public let memoryPlan: MemoryPlan?
    public let memoryActual: MemoryActual?
    public let memoryGovernor: MemoryGovernor?
    public let cache: CacheMetrics?
    public let scheduler: SchedulerMetrics?
    public let requests: RequestMetrics?
    public let metrics: PerformanceMetrics?
    
    enum CodingKeys: String, CodingKey {
        case ready
        case maximumContextTokens = "maximum_context_tokens"
        case memoryPressure = "memory_pressure"
        case instance
        case memoryPlan = "memory_plan"
        case memoryActual = "memory_actual"
        case memoryGovernor = "memory_governor"
        case cache
        case scheduler
        case requests
        case metrics
    }
}

public struct InstanceInfo: Codable {
    public let id: String?
    public let pid: Int?
    public let model: String?
    public let host: String?
    public let port: Int?
    public let startedAt: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, pid, model, host, port
        case startedAt = "started_at"
    }
}

public struct MemoryPlan: Codable {
    public let device: DeviceInfo?
    public let model: ModelInfo?
    public let budget: MemoryBudget?
}

public struct DeviceInfo: Codable {
    public let deviceName: String?
    public let macosVersion: String?
    public let gpuCoreCount: Int?
    public let physicalMemoryBytes: Int64?
    public let recommendedMaxWorkingSetBytes: Int64?
    
    enum CodingKeys: String, CodingKey {
        case deviceName = "device_name"
        case macosVersion = "macos_version"
        case gpuCoreCount = "gpu_core_count"
        case physicalMemoryBytes = "physical_memory_bytes"
        case recommendedMaxWorkingSetBytes = "recommended_max_working_set_bytes"
    }
}

public struct ModelInfo: Codable {
    public let modelName: String?
    public let maximumContextTokens: Int?
    public let attentionLayers: Int?
    
    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case maximumContextTokens = "maximum_context_tokens"
        case attentionLayers = "attention_layers"
    }
}

public struct MemoryBudget: Codable {
    public let physicalMemoryBytes: Int64?
    public let hardBudgetBytes: Int64?
    public let targetWeightsBytes: Int64?
    public let draftWeightsBytes: Int64?
    public let fixedRuntimeBytes: Int64?
    
    enum CodingKeys: String, CodingKey {
        case physicalMemoryBytes = "physical_memory_bytes"
        case hardBudgetBytes = "hard_budget_bytes"
        case targetWeightsBytes = "target_weights_bytes"
        case draftWeightsBytes = "draft_weights_bytes"
        case fixedRuntimeBytes = "fixed_runtime_bytes"
    }
}

public struct MemoryActual: Codable {
    public let currentBytes: Int64?
    public let peakBytes: Int64?
    public let denseBytes: Int64?
    public let sparseResidentBytes: Int64?
    
    enum CodingKeys: String, CodingKey {
        case currentBytes = "current_bytes"
        case peakBytes = "peak_bytes"
        case denseBytes = "dense_bytes"
        case sparseResidentBytes = "sparse_resident_bytes"
    }
}

public struct MemoryGovernor: Codable {
    public let limitBytes: Int64?
    public let observedResidentBytes: Int64?
    public let headroomBytes: Int64?
    public let systemPressure: String?
    public let hostAvailableBytes: Int64?
    
    enum CodingKeys: String, CodingKey {
        case limitBytes = "limit_bytes"
        case observedResidentBytes = "observed_resident_bytes"
        case headroomBytes = "headroom_bytes"
        case systemPressure = "system_pressure"
        case hostAvailableBytes = "host_available_bytes"
    }
}

public struct CacheMetrics: Codable {
    public let lookups: Int?
    public let hits: Int?
    public let coldMisses: Int?
    public let hitRate: Double?
    public let reusedTokens: Int64?
    public let kvHitTokens: Int64?
    
    enum CodingKeys: String, CodingKey {
        case lookups, hits
        case coldMisses = "cold_misses"
        case hitRate = "hit_rate"
        case reusedTokens = "reused_tokens"
        case kvHitTokens = "kv_hit_tokens"
    }
}

public struct SchedulerMetrics: Codable {
    public let queued: Int?
    public let prefilling: Int?
    public let decoding: Int?
    public let prefillBatches: Int?
    public let decodeBatches: Int?
    
    enum CodingKeys: String, CodingKey {
        case queued, prefilling, decoding
        case prefillBatches = "prefill_batches"
        case decodeBatches = "decode_batches"
    }
}

public struct RequestMetrics: Codable {
    public let submitted: Int?
    public let completed: Int?
    public let cancelled: Int?
    public let failed: Int?
}

public struct PerformanceMetrics: Codable {
    public let prefillInputTokens: Int64?
    public let prefillTokensPerSecond: Double?
    public let decodeOutputTokens: Int64?
    public let decodeTokensPerSecond: Double?
    public let draftedTokens: Int64?
    public let acceptedDraftTokens: Int64?
    public let draftAcceptanceRate: Double?
    public let ttftMs: PercentileMetric?
    public let itlMs: PercentileMetric?
    
    enum CodingKeys: String, CodingKey {
        case prefillInputTokens = "prefill_input_tokens"
        case prefillTokensPerSecond = "prefill_tokens_per_second"
        case decodeOutputTokens = "decode_output_tokens"
        case decodeTokensPerSecond = "decode_tokens_per_second"
        case draftedTokens = "drafted_tokens"
        case acceptedDraftTokens = "accepted_draft_tokens"
        case draftAcceptanceRate = "draft_acceptance_rate"
        case ttftMs = "ttft_ms"
        case itlMs = "itl_ms"
    }
}

public struct PercentileMetric: Codable {
    public let p50: Double?
    public let p95: Double?
    public let samples: Int?
}

// MARK: - Lock file model

public struct ServeLock: Codable {
    public let pid: Int
    public let model: String
    public let port: Int
}

// MARK: - Hugging Face & Local Model Info

public struct HuggingFaceModelItem: Codable, Identifiable {
    public var id: String
    public let likes: Int?
    public let downloads: Int?
    public let tags: [String]?
    public let pipelineTag: String?
    public let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, likes, downloads, tags
        case pipelineTag = "pipeline_tag"
        case createdAt
    }
    
    public var isOfficial: Bool {
        return id.hasPrefix("incoai/")
    }
    
    public var displayName: String {
        return id.components(separatedBy: "/").last ?? id
    }
}

public struct InstalledSplashModel: Identifiable, Hashable {
    public var id: String { repoId }
    public let repoId: String
    public let localPath: URL
    public let diskSizeBytes: Int64
    public let isCurrentlyActive: Bool
    
    public var formattedSize: String {
        let gb = Double(diskSizeBytes) / 1_073_741_824.0
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(diskSizeBytes) / 1_048_576.0
        return String(format: "%.0f MB", mb)
    }
    
    public var shortName: String {
        repoId.components(separatedBy: "/").last ?? repoId
    }
}
