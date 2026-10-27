import SwiftUI
import AppKit

public struct AppIconView: View {
    public let size: CGFloat
    
    public init(size: CGFloat = 28) {
        self.size = size
    }
    
    private var loadedIconImage: NSImage? {
        // 1. Bundle.main o Bundle.module
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: iconURL) {
            return img
        }
        if let pngURL = Bundle.main.url(forResource: "app_icon_droplet_transparent", withExtension: "png"),
           let img = NSImage(contentsOf: pngURL) {
            return img
        }
        
        // 2. Rutas relativas del repositorio para ejecución en tests y previsualización
        let candidates = [
            "Resources/app_icon_droplet_transparent.png",
            "Resources/AppIcon.icns",
            "../Resources/app_icon_droplet_transparent.png",
            "../Resources/AppIcon.icns",
            "/Users/hometrix/ProyectosJMGREPDEV/SplashMonitor/Resources/app_icon_droplet_transparent.png",
            "/Users/hometrix/ProyectosJMGREPDEV/SplashMonitor/Resources/AppIcon.icns"
        ]
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path),
               let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
        
        return nil
    }
    
    public var body: some View {
        if let nsImage = loadedIconImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
        } else {
            // Elegant fallback: Splash droplet with neon cyan-indigo gradient
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.05, green: 0.1, blue: 0.25), Color(red: 0.1, green: 0.05, blue: 0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                Image(systemName: "drop.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.55, height: size * 0.55)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan, Color.purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}
