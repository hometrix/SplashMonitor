import SwiftUI
import AppKit

public struct AboutView: View {
    @ObservedObject var loc = Localization.shared
    @ObservedObject var service = SplashService.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header with App Icon
            VStack(spacing: 12) {
                AppIconView(size: 72)
                
                Text("Splash Monitor")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                HStack(spacing: 6) {
                    Text("v\(service.currentVersion)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("BETA")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.orange)
                        .cornerRadius(4)
                    
                    Text(tr(es: "· Primera Versión", en: "· First Release"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("🇩🇴")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                .cornerRadius(12)
            }
            .padding(.top, 8)
            
            // Description Card
            VStack(alignment: .leading, spacing: 10) {
                Text(tr(
                    es: "La primera aplicación gráfica y monitor de barra de menú creada específicamente para el motor de inferencia local Splash de Inco AI en Apple Silicon.",
                    en: "The first visual application and menu bar monitor created specifically for Inco AI's Splash local inference engine on Apple Silicon."
                ))
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineSpacing(3)
                
                Text(tr(
                    es: "Proporciona monitoreo en vivo de tokens (prefill y decode), eficiencia del caché KV, aceptación especulativa DFlash 2, memoria unificada Metal, y permite explorar e instalar cualquier modelo de Hugging Face sin usar la terminal.",
                    en: "Provides real-time monitoring of tokens (prefill and decode), KV cache efficiency, DFlash 2 speculative acceptance, Metal unified memory, and allows exploring and installing any Hugging Face model without using the terminal."
                ))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineSpacing(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Author Card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.18, blue: 0.45), Color(red: 0.81, green: 0.07, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        
                        Text("JG")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Joan Gregorio Pérez")
                                .font(.system(size: 15, weight: .bold))
                            Text("🇩🇴")
                        }
                        
                        Text("JMGREP Developers · \(tr(es: "Ingeniero en Software", en: "Software Engineer"))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.accentColor)
                        
                        Text(tr(es: "Creador y Desarrollador · República Dominicana", en: "Creator & Developer · Dominican Republic"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
            
            // Tech Stack & Badges
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    TechBadge(icon: "swift", label: "Swift 6 & SwiftUI")
                    TechBadge(icon: "cpu", label: "Apple Silicon Metal")
                    TechBadge(icon: "bolt.fill", label: "Inco AI Splash")
                }
                
                HStack(spacing: 10) {
                    TechBadge(icon: "lock.shield", label: "MIT License")
                    TechBadge(icon: "globe.americas.fill", label: tr(es: "Hecho en RD 🇩🇴", en: "Made in DR 🇩🇴"))
                }
            }
            
            // External Links
            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "https://inco.ai/blog/splash/") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Inco Splash", systemImage: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    if let url = URL(string: "https://huggingface.co/incoai") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Modelos Hugging Face", systemImage: "cube")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Copyright
            Text("© 2026 JMGREP Developers · Joan Gregorio Pérez · \(tr(es: "Código Abierto", en: "Open Source"))")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
        .padding(14)
        .frame(maxWidth: 580)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct TechBadge: View {
    let icon: String
    let label: String
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
        .cornerRadius(6)
    }
}
