import SwiftUI

public struct DominicanEmblem: View {
    public var size: CGFloat = 20
    
    public init(size: CGFloat = 20) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Flag quarter base
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color.white)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 1)
            
            // Four quarters:
            // Top-left: Blue, Top-right: Red
            // Bottom-left: Red, Bottom-right: Blue
            VStack(spacing: size * 0.14) {
                HStack(spacing: size * 0.14) {
                    Rectangle()
                        .fill(Color(red: 0.0, green: 0.18, blue: 0.45)) // Azul Ultramar Dominicano
                    Rectangle()
                        .fill(Color(red: 0.81, green: 0.07, blue: 0.15)) // Rojo Bermellón
                }
                HStack(spacing: size * 0.14) {
                    Rectangle()
                        .fill(Color(red: 0.81, green: 0.07, blue: 0.15)) // Rojo Bermellón
                    Rectangle()
                        .fill(Color(red: 0.0, green: 0.18, blue: 0.45)) // Azul Ultramar
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            
            // White cross (Cruz Blanca Trinitaria)
            Rectangle()
                .fill(Color.white)
                .frame(width: size * 0.16, height: size)
            
            Rectangle()
                .fill(Color.white)
                .frame(width: size, height: size * 0.16)
            
            // Center emblem dot (Escudo Nacional)
            Circle()
                .fill(Color(red: 0.0, green: 0.45, blue: 0.2)) // Laurel / Escudo verde
                .frame(width: size * 0.2, height: size * 0.2)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 0.5)
                )
        }
        .frame(width: size, height: size)
    }
}
