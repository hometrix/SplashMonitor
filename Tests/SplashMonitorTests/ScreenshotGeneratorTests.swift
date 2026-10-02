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
        
        service.installedModels = [
            InstalledSplashModel(
                repoId: "mlx-community/Qwen3.8-27B-4bit",
                localPath: URL(fileURLWithPath: "/tmp/qwen"),
                diskSizeBytes: 16_106_127_360,
                isCurrentlyActive: true
            ),
            InstalledSplashModel(
                repoId: "incoai/Qwen3.8-27B-Splash",
                localPath: URL(fileURLWithPath: "/tmp/splash"),
                diskSizeBytes: 15_032_385_536,
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
    }
}
