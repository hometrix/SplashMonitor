import SwiftUI
import AppKit

public struct AppIconView: View {
    public let size: CGFloat
    
    public init(size: CGFloat = 28) {
        self.size = size
    }
    
    public var body: some View {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let nsImage = NSImage(contentsOf: iconURL) {
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
