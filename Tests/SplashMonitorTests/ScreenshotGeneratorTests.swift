import XCTest
import SwiftUI
import AppKit
@testable import SplashMonitor

final class ScreenshotGeneratorTests: XCTestCase {
    
    private func createMockStatus() -> SplashStatus {
        let json = """
        {
          "ready": true,
          "maximum_context_tokens": 262144,
          "memory_pressure": "nominal",
          "thermal_state": "nominal",
          "ane_ffn": {
            "state": "active",
            "share": 0.6667,
            "min_prompt_chunk": 128,
            "evaluations": 142
          },
          "weights": {
            "released": false,
            "idle_release_seconds": 300.0,
            "restores": 0
          },
          "instance": {
            "id": "832f0b6e-1c1f-4d3f-9f0a-2a1b3c4d5e6f",
            "pid": 4242,
            "model": "huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF:Q4_K",
            "host": "127.0.0.1",
            "port": 8005,
            "started_at": 1758700000.0
          },
          "memory_plan": {
            "device": {
              "device_name": "Apple M4 Max",
              "macos_version": "15.2",
              "gpu_core_count": 40,
              "physical_memory_bytes": 68719476736,
              "recommended_max_working_set_bytes": 56693568512
            },
            "model": { "model_name": "Huihui-Qwen3.6-35B-A3B-abliterated-MTP:Q4_K", "maximum_context_tokens": 262144, "attention_layers": 64 },
            "budget": { "physical_memory_bytes": 68719476736, "hard_budget_bytes": 56693568512 }
          },
          "memory_actual": { "current_bytes": 36507222016, "peak_bytes": 37580963840, "dense_bytes": 32212254720, "sparse_resident_bytes": 4294967296 },
          "memory_governor": {
            "limit_bytes": 56693568512,
            "observed_resident_bytes": 36507222016,
            "headroom_bytes": 20186346496,
            "system_pressure": "nominal",
            "host_available_bytes": 28991029248
          },
          "cache": { "lookups": 450, "hits": 408, "cold_misses": 42, "hit_rate": 0.906, "reused_tokens": 19200000, "kv_hit_tokens": 19200000 },
          "scheduler": { "queued": 0, "prefilling": 1, "decoding": 0, "prefill_batches": 12, "decode_batches": 184 },
          "requests": { "submitted": 28, "completed": 27, "cancelled": 0, "failed": 0 },
          "metrics": {
            "prefill_input_tokens": 1300000,
            "prefill_tokens_per_second": 610.6,
            "decode_output_tokens": 327400,
            "decode_tokens_per_second": 109.0,
            "drafted_tokens": 24000,
            "accepted_draft_tokens": 13728,
            "draft_acceptance_rate": 0.572,
            "ttft_ms": { "p50": 1991.0, "p95": 2450.0, "samples": 28 },
            "itl_ms": { "p50": 11.5, "p95": 14.2, "samples": 28 }
          }
        }
        """
        return try! JSONDecoder().decode(SplashStatus.self, from: Data(json.utf8))
    }
    
    @MainActor
    func testGenerateAllModuleScreenshots() throws {
        UserDefaults.standard.set(true, forKey: "hasAskedAboutMenuBar")
        
        let languages = ["es", "en"]
        
        for lang in languages {
            UserDefaults.standard.set(lang, forKey: "languageMode")
            Localization.shared.setLanguageMode(lang)
            
            let service = SplashService()
            service.isRunning = true
            service.activePort = 8005
            service.activeModel = "huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF:Q4_K"
            service.selectedModelForLaunch = "huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF:Q4_K"
            service.activePid = 4242
            service.status = createMockStatus()
            service.isSplashInstalled = true
            service.installedAgents = ["claude", "claude-cowork", "opencode", "codex", "hermes", "pi", "dsh"]
            
            service.speedHistory = [82.0, 89.4, 95.1, 101.5, 104.3, 107.0, 108.5, 109.0]
            service.languageOnly = false
            
            service.installedModels = [
                InstalledSplashModel(
                    repoId: "huihui-ai/Huihui-Qwen3.6-35B-A3B-abliterated-MTP-GGUF:Q4_K",
                    localPath: URL(fileURLWithPath: "/tmp/qwen36"),
                    diskSizeBytes: 21_474_836_480,
                    isCurrentlyActive: true
                ),
                InstalledSplashModel(
                    repoId: "unsloth/Ornith-1.5-122B-GGUF:UD-Q4_K_XL",
                    localPath: URL(fileURLWithPath: "/tmp/ornith"),
                    diskSizeBytes: 68_719_476_736,
                    isCurrentlyActive: false
                ),
                InstalledSplashModel(
                    repoId: "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:IQ3_S",
                    localPath: URL(fileURLWithPath: "/tmp/flashnext"),
                    diskSizeBytes: 12_884_901_888,
                    isCurrentlyActive: false
                ),
                InstalledSplashModel(
                    repoId: "unsloth/Flint-40B-A2.5B-GGUF:Q4_K_M",
                    localPath: URL(fileURLWithPath: "/tmp/flint"),
                    diskSizeBytes: 24_696_061_952,
                    isCurrentlyActive: false
                )
            ]
            
            service.connectedApps = [
                ConnectedApp(
                    pid: 1234,
                    name: "Claude Desktop / Cowork",
                    bundleId: "com.anthropic.claudefordesktop",
                    category: .codingAgent,
                    icon: FileManager.default.fileExists(atPath: "/Applications/Claude.app") ? NSWorkspace.shared.icon(forFile: "/Applications/Claude.app") : nil,
                    connectionCount: 3,
                    status: .active,
                    remoteAddress: "127.0.0.1"
                ),
                ConnectedApp(
                    pid: 5678,
                    name: "Cursor IDE",
                    bundleId: "com.todesktop.230313mzl4w4u92",
                    category: .ide,
                    icon: nil,
                    connectionCount: 2,
                    status: .active,
                    remoteAddress: "127.0.0.1"
                )
            ]
            
            let baseDir = URL(fileURLWithPath: "/Users/hometrix/ProyectosJMGREPDEV/SplashMonitor/screenshots")
            let langDir = baseDir.appendingPathComponent(lang)
            try FileManager.default.createDirectory(at: langDir, withIntermediateDirectories: true)
            
            let artifactDir = URL(fileURLWithPath: "/Users/hometrix/.gemini/antigravity-ide/brain/ad6a6708-a43c-4aa2-8635-8884b76db7d1")
            let artifactLangDir = artifactDir.appendingPathComponent(lang)
            try FileManager.default.createDirectory(at: artifactLangDir, withIntermediateDirectories: true)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: .darkAqua)
            
            for item in MainWindowView.SidebarItem.allCases {
                let view = MainWindowView(service: service, initialTab: item)
                    .frame(width: 1000, height: 700)
                    .preferredColorScheme(.dark)
                
                let hosting = NSHostingView(rootView: view)
                hosting.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
                window.contentView = hosting
                hosting.layoutSubtreeIfNeeded()
                
                guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
                    XCTFail("No se pudo crear bitmapImageRep para \(item.rawValue)")
                    continue
                }
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    XCTFail("No se pudo obtener representación PNG para \(item.rawValue)")
                    continue
                }
                
                let filename = "module-\(item.rawValue).png"
                try pngData.write(to: langDir.appendingPathComponent(filename))
                try pngData.write(to: artifactLangDir.appendingPathComponent(filename))
                
                // Si es español o si no existe en baseDir, guardar también en la raíz de screenshots
                if lang == "es" {
                    try pngData.write(to: baseDir.appendingPathComponent(filename))
                    try pngData.write(to: artifactDir.appendingPathComponent(filename))
                }
                
                print("📸 Captura [\(lang)] generada con éxito: \(filename)")
            }
            
            // Captura de Guía de Conexión
            let guideView = NavigationSplitView {
                VStack { Spacer() }
                    .frame(minWidth: 220, idealWidth: 240)
            } detail: {
                ScrollView {
                    ConnectedAppsView(service: service, initialTab: .quickConnect)
                        .padding(20)
                }
            }
            .frame(width: 1000, height: 700)
            .preferredColorScheme(.dark)
            
            let guideHosting = NSHostingView(rootView: guideView)
            guideHosting.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
            window.contentView = guideHosting
            guideHosting.layoutSubtreeIfNeeded()
            
            if let bitmap = guideHosting.bitmapImageRepForCachingDisplay(in: guideHosting.bounds) {
                guideHosting.cacheDisplay(in: guideHosting.bounds, to: bitmap)
                if let pngData = bitmap.representation(using: .png, properties: [:]) {
                    let filename = "module-connectedApps-guide.png"
                    try pngData.write(to: langDir.appendingPathComponent(filename))
                    try pngData.write(to: artifactLangDir.appendingPathComponent(filename))
                    if lang == "es" {
                        try pngData.write(to: baseDir.appendingPathComponent(filename))
                        try pngData.write(to: artifactDir.appendingPathComponent(filename))
                    }
                    print("📸 Captura [\(lang)] generada con éxito: \(filename)")
                }
            }
            
            // Captura de Descarga en Vivo
            let downloadService = SplashService()
            downloadService.isInstalling = true
            downloadService.installingModelId = "mlx-community/Qwen3.8-27B-Uncensored-OptiQ-4bit"
            downloadService.downloadSpeedMBs = 34.8
            downloadService.downloadedBytes = 1_426_063_360
            downloadService.totalExpectedBytes = 4_133_879_808
            downloadService.downloadProgressFraction = 0.35
            
            if lang == "es" {
                downloadService.downloadPhase = "Descargando acelerador DFlash2 (especulativo)..."
                downloadService.installLogs = [
                    "Iniciando descarga y preparación para mlx-community/Qwen3.8-27B-Uncensored-OptiQ-4bit...",
                    "ℹ️ Modo solo lenguaje (--language-only) activado.",
                    "ℹ️ Fetching 1 file(s), 3.85 GB, from incoai/Qwen3.8-27B-DFlash2@015e795645c7; cached files are reused.",
                    "⏳ Conectando y transfiriendo archivos grandes en paralelo...",
                    "Fetching 2 files:   0%|          | 0/2 [00:00<?, ?it/s]",
                    "📥 Descargando paquete: 1.33 GB recibidos..."
                ]
            } else {
                downloadService.downloadPhase = "Downloading DFlash2 speculative accelerator..."
                downloadService.installLogs = [
                    "Starting download and preparation for mlx-community/Qwen3.8-27B-Uncensored-OptiQ-4bit...",
                    "ℹ️ Language-only mode (--language-only) enabled.",
                    "ℹ️ Fetching 1 file(s), 3.85 GB, from incoai/Qwen3.8-27B-DFlash2@015e795645c7; cached files are reused.",
                    "⏳ Connecting and streaming large model shards in parallel...",
                    "Fetching 2 files:   0%|          | 0/2 [00:00<?, ?it/s]",
                    "📥 Downloading package: 1.33 GB received..."
                ]
            }
            
            let downloadView = MainWindowView(service: downloadService, initialTab: .models)
                .frame(width: 1000, height: 700)
                .preferredColorScheme(.dark)
            
            let dlHosting = NSHostingView(rootView: downloadView)
            dlHosting.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
            window.contentView = dlHosting
            dlHosting.layoutSubtreeIfNeeded()
            
            if let bitmap = dlHosting.bitmapImageRepForCachingDisplay(in: dlHosting.bounds) {
                dlHosting.cacheDisplay(in: dlHosting.bounds, to: bitmap)
                if let pngData = bitmap.representation(using: .png, properties: [:]) {
                    let filename = "module-modelDownload.png"
                    try pngData.write(to: langDir.appendingPathComponent(filename))
                    try pngData.write(to: artifactLangDir.appendingPathComponent(filename))
                    if lang == "es" {
                        try pngData.write(to: baseDir.appendingPathComponent(filename))
                        try pngData.write(to: artifactDir.appendingPathComponent(filename))
                    }
                    print("📸 Captura [\(lang)] generada con éxito: \(filename)")
                }
            }
        }
    }
}
