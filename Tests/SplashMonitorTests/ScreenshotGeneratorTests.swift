import XCTest
import SwiftUI
import AppKit
@testable import SplashMonitor

final class ScreenshotGeneratorTests: XCTestCase {
    
    @MainActor
    func testGenerateAllModuleScreenshots() throws {
        let service = SplashService()
        service.isRunning = true
        service.activePort = 8000
        service.activeModel = "mlx-community/Qwen3.8-27B-4bit"
        service.selectedModelForLaunch = "mlx-community/Qwen3.8-27B-4bit"
        service.activePid = 4242
        service.status = Fixtures.status(port: 8000, model: "mlx-community/Qwen3.8-27B-4bit", pid: 4242)
        service.isSplashInstalled = true
        service.installedAgents = ["claude", "claude-cowork", "opencode", "codex", "hermes"]
        
        service.speedHistory = [52.0, 68.4, 82.1, 94.5, 102.3, 98.0, 104.2, 108.5]
        service.languageOnly = false
        
        service.installedModels = [
            InstalledSplashModel(
                repoId: "incoai/Qwen3.6-35B-A3B-Splash",
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
                name: "Cursor",
                bundleId: "com.todesktop.230313mzl4w4u92",
                category: .ide,
                icon: nil,
                connectionCount: 2,
                status: .active,
                remoteAddress: "127.0.0.1"
            )
        ]
        
        let outputDir = URL(fileURLWithPath: "/Users/hometrix/ProyectosJMGREPDEV/SplashMonitor/screenshots")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let artifactDir = URL(fileURLWithPath: "/Users/hometrix/.gemini/antigravity-ide/brain/ad6a6708-a43c-4aa2-8635-8884b76db7d1")
        try FileManager.default.createDirectory(at: artifactDir, withIntermediateDirectories: true)
        
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
            
            // Forzar renderizado
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
            let targetURL = outputDir.appendingPathComponent(filename)
            try pngData.write(to: targetURL)
            
            let artifactTarget = artifactDir.appendingPathComponent(filename)
            try pngData.write(to: artifactTarget)
            
            print("📸 Captura generada con éxito: \(filename)")
        }
        
        // Captura adicional para la pestaña de Guía de Integración
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
                try pngData.write(to: outputDir.appendingPathComponent(filename))
                try pngData.write(to: artifactDir.appendingPathComponent(filename))
                print("📸 Captura generada con éxito: \(filename)")
            }
        }
        
        // Captura adicional para la nueva característica: Telemetría de descarga en vivo de modelos
        let downloadService = SplashService()
        downloadService.isInstalling = true
        downloadService.installingModelId = "mlx-community/Qwen3.8-27B-Uncensored-OptiQ-4bit"
        downloadService.downloadPhase = "Descargando acelerador DFlash2 (especulativo)..."
        downloadService.downloadSpeedMBs = 34.8
        downloadService.downloadedBytes = 1_426_063_360
        downloadService.totalExpectedBytes = 4_133_879_808
        downloadService.downloadProgressFraction = 0.35
        downloadService.installLogs = [
            "Iniciando descarga y preparación para mlx-community/Qwen3.8-27B-Uncensored-OptiQ-4bit...",
            "ℹ️ Modo solo lenguaje (--language-only) activado.",
            "ℹ️ Fetching 1 file(s), 3.85 GB, from incoai/Qwen3.8-27B-DFlash2@015e795645c7; cached files are reused.",
            "⏳ Conectando y transfiriendo archivos grandes en paralelo...",
            "Fetching 2 files:   0%|          | 0/2 [00:00<?, ?it/s]",
            "📥 Descargando paquete: 1.33 GB recibidos..."
        ]
        
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
                try pngData.write(to: outputDir.appendingPathComponent(filename))
                try pngData.write(to: artifactDir.appendingPathComponent(filename))
                print("📸 Captura generada con éxito: \(filename)")
            }
        }
    }
}
