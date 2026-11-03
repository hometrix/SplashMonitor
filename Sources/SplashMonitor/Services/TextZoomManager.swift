import SwiftUI
import Combine

/// Gestor centralizado del tamaño de texto y zoom de la app
public final class TextZoomManager: ObservableObject {
    public static let shared = TextZoomManager()
    
    // Nivel de zoom (1.0 = normal, 1.15 = grande, etc.)
    @AppStorage("chatTextZoomLevel") public var zoomScale: Double = 1.0
    
    // Tamaños mínimos y máximos
    public let minScale: Double = 0.8
    public let maxScale: Double = 2.0
    public let step: Double = 0.1
    
    public init() {}
    
    public func zoomIn() {
        if zoomScale < maxScale {
            zoomScale = min(maxScale, (zoomScale + step * 10).rounded() / 10)
        }
    }
    
    public func zoomOut() {
        if zoomScale > minScale {
            zoomScale = max(minScale, (zoomScale - step * 10).rounded() / 10)
        }
    }
    
    public func resetZoom() {
        zoomScale = 1.0
    }
    
    public var formattedPercentage: String {
        "\(Int(round(zoomScale * 100)))%"
    }
}

