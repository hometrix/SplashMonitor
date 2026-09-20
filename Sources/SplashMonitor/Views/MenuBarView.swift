import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    @State private var activeTab: AppTab = .metrics
    
    public enum AppTab: String, CaseIterable, Identifiable {
        case metrics
        case models
        case server
        case settings
        case about
        
        public var id: String { rawValue }
        
        public func title(isSpanish: Bool) -> String {
            switch self {
            case .metrics: return isSpanish ? "Métricas" : "Metrics"
            case .models: return isSpanish ? "Modelos" : "Models"
            case .server: return isSpanish ? "Servidor" : "Server"
            case .settings: return isSpanish ? "Ajustes" : "Settings"
            case .about: return isSpanish ? "Acerca de" : "About"
            }
        }
        
        public var icon: String {
            switch self {
            case .metrics: return "speedometer"
            case .models: return "shippingbox"
            case .server: return "server.rack"
            case .settings: return "gearshape"
            case .about: return "info.circle"
            }
        }
    }
    
    public init(service: SplashService) {
        self.service = service
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            // Tab Selector Bar
            tabSelectorBar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Main Content Area
            ScrollView {
                VStack(spacing: 12) {
                    switch activeTab {
                    case .metrics:
                        TokenMetricsView(service: service)
                    case .models:
                        ModelManagerView(service: service)
                    case .server:
                        ServerControlView(service: service)
                    case .settings:
                        settingsView
                    case .about:
                        AboutView()
                    }
                }
                .padding(14)
            }
            .frame(maxHeight: 460)
            
            Divider()
            
            // Footer
            footerView
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        }
        .frame(width: 390)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 8) {
            AppIconView(size: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("Splash Monitor")
                        .font(.system(size: 13, weight: .bold))
                    
                    Text("v1.0")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(service.isRunning ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(service.isRunning ? service.activeModel.components(separatedBy: "/").last ?? service.activeModel : tr(es: "Desconectado", en: "Offline"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Language Switcher
            Button {
                loc.toggleLanguage()
            } label: {
                Text(loc.isSpanish ? "🇩🇴 ES" : "🇬🇧 EN")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help(tr(es: "Cambiar idioma", en: "Switch language"))
            
            // Open full window button
            Button {
                openMainWindow()
            } label: {
                Image(systemName: "macwindow")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(tr(es: "Abrir aplicación completa en ventana", en: "Open full application window"))
            
            Button {
                Task {
                    await service.checkServerStatus()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(tr(es: "Refrescar ahora", en: "Refresh now"))
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(tr(es: "Salir de Splash Monitor", en: "Quit Splash Monitor"))
        }
    }
    
    // MARK: - Tab Selector Bar
    private var tabSelectorBar: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        activeTab = tab
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10))
                        Text(tab.title(isSpanish: loc.isSpanish))
                            .font(.system(size: 11, weight: activeTab == tab ? .semibold : .regular))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(activeTab == tab ? Color.accentColor.opacity(0.18) : Color.clear)
                    .foregroundColor(activeTab == tab ? .accentColor : .secondary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
    
    // MARK: - Settings View
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr(es: "Configuración de la Barra de Menú", en: "Menu Bar Configuration"))
                .font(.system(size: 12, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(tr(es: "Información mostrada en la barra superior:", en: "Information shown in top bar:"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $service.menuBarDisplayMode) {
                    Text(tr(es: "Solo Ícono", en: "Icon Only")).tag("icon")
                    Text(tr(es: "Ícono + Velocidad (tok/s)", en: "Icon + Speed (tok/s)")).tag("speed")
                    Text(tr(es: "Ícono + Tokens Usados", en: "Icon + Tokens Used")).tag("tokens")
                    Text(tr(es: "Ícono + Modelo Activo", en: "Icon + Active Model")).tag("model")
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: 11))
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(tr(es: "Frecuencia de Actualización", en: "Refresh Interval"))
                    .font(.system(size: 11, weight: .semibold))
                
                HStack {
                    Slider(value: $service.refreshInterval, in: 0.5...5.0, step: 0.5)
                        .onChange(of: service.refreshInterval) { _ in
                            service.startPolling()
                        }
                    Text(String(format: "%.1f s", service.refreshInterval))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 45)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            // Open full window button
            Button {
                openMainWindow()
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text(tr(es: "Abrir Ventana Principal Completa", en: "Open Full Main Window"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Link("inco.ai/blog/splash", destination: URL(string: "https://inco.ai/blog/splash/")!)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Link("Hugging Face incoai", destination: URL(string: "https://huggingface.co/incoai")!)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.title == "Splash Monitor" {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
