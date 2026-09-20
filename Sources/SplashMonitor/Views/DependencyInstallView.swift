import SwiftUI
import AppKit

public struct DependencyInstallView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    
    public init(service: SplashService) {
        self.service = service
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(tr(es: "Dependencia Requerida: Motor Splash", en: "Required Dependency: Splash Engine"))
                            .font(.system(size: 16, weight: .bold))
                        
                        Text("brew")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                            .cornerRadius(4)
                    }
                    
                    Text(tr(
                        es: "Splash Monitor requiere tener instalado el CLI oficial de Splash en tu Mac para controlar servidores, monitorizar tokens y cargar modelos.",
                        en: "Splash Monitor requires the official Splash CLI installed on your Mac to manage servers, monitor tokens, and serve models."
                    ))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                }
                
                Spacer()
            }
            
            // Command snippet card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tr(es: "Comando de Instalación Oficial:", en: "Official Installation Command:"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Link(destination: URL(string: "https://github.com/incoai/splash")!) {
                        HStack(spacing: 3) {
                            Text("github.com/incoai/splash")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.system(size: 10))
                    }
                }
                
                HStack {
                    Text("brew install incoai/tap/splash")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString("brew install incoai/tap/splash", forType: .string)
                    } label: {
                        Label(tr(es: "Copiar", en: "Copy"), systemImage: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            // System Diagnostics
            HStack(spacing: 12) {
                DiagnosticBadge(
                    title: "Homebrew",
                    status: service.hasHomebrew ? tr(es: "Detectado", en: "Detected") : tr(es: "No encontrado", en: "Not found"),
                    icon: service.hasHomebrew ? "checkmark.circle.fill" : "xmark.circle.fill",
                    isSuccess: service.hasHomebrew
                )
                
                DiagnosticBadge(
                    title: "Apple Silicon",
                    status: isAppleSilicon ? "ARM64 Metal" : "Intel (No compatible)",
                    icon: isAppleSilicon ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    isSuccess: isAppleSilicon
                )
                
                DiagnosticBadge(
                    title: "Splash CLI",
                    status: service.isSplashInstalled ? (service.splashVersion ?? "Instalado") : tr(es: "No instalado", en: "Not installed"),
                    icon: service.isSplashInstalled ? "checkmark.circle.fill" : "clock.arrow.circlepath",
                    isSuccess: service.isSplashInstalled
                )
            }
            
            // Actions
            HStack(spacing: 10) {
                if service.isInstallingDependency {
                    Button(role: .destructive) {
                        service.cancelDependencyInstall()
                    } label: {
                        Label(tr(es: "Cancelar Instalación", en: "Cancel Installation"), systemImage: "xmark.circle")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                } else {
                    Button {
                        service.installSplashDependency()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text(tr(es: "Instalar Splash Automáticamente", en: "Install Splash Automatically"))
                        }
                        .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.regular)
                    .disabled(!service.hasHomebrew)
                }
                
                Button {
                    service.installSplashInTerminal()
                } label: {
                    Label(tr(es: "Instalar en Terminal", en: "Install in Terminal"), systemImage: "terminal")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Spacer()
                
                Button {
                    service.checkDependencies()
                } label: {
                    Label(tr(es: "Verificar", en: "Verify"), systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            
            // Live Installation Console
            if service.isInstallingDependency || !service.dependencyInstallLogs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if service.isInstallingDependency {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text(tr(es: "Instalando Splash...", en: "Installing Splash..."))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                        } else if service.dependencyInstallSuccess == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(tr(es: "¡Instalación completada con éxito!", en: "Installation completed successfully!"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        } else if service.dependencyInstallSuccess == false {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(tr(es: "Error durante la instalación", en: "Installation error"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        if !service.isInstallingDependency {
                            Button(tr(es: "Limpiar", en: "Clear")) {
                                service.dependencyInstallLogs.removeAll()
                                service.dependencyInstallSuccess = nil
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 10))
                        }
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(service.dependencyInstallLogs.enumerated()), id: \.offset) { idx, log in
                                    Text(log)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.9))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(idx)
                                }
                            }
                            .padding(8)
                        }
                        .frame(height: 90)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(6)
                        .onChange(of: service.dependencyInstallLogs.count) { _ in
                            if let last = service.dependencyInstallLogs.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
    
    private var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
}

struct DiagnosticBadge: View {
    let title: String
    let status: String
    let icon: String
    let isSuccess: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(isSuccess ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(status)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}
