import SwiftUI
import AppKit

public struct MainWindowView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true
    @AppStorage("hasAskedAboutMenuBar") private var hasAskedAboutMenuBar: Bool = false
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    
    public enum SidebarItem: String, CaseIterable, Identifiable {
        case dashboard
        case models
        case server
        case settings
        case about
        
        public var id: String { rawValue }
        
        public func title(isSpanish: Bool) -> String {
            switch self {
            case .dashboard: return isSpanish ? "Dashboard de Tokens" : "Token Dashboard"
            case .models: return isSpanish ? "Gestor de Modelos" : "Model Manager"
            case .server: return isSpanish ? "Servidor y Agentes" : "Server & Agents"
            case .settings: return isSpanish ? "Configuración" : "Settings"
            case .about: return isSpanish ? "Acerca de" : "About"
            }
        }
        
        public var icon: String {
            switch self {
            case .dashboard: return "speedometer"
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
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // App Branding Header
                HStack(spacing: 10) {
                    DominicanEmblem(size: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Splash Monitor")
                            .font(.system(size: 15, weight: .bold))
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(service.isRunning ? Color.green : Color.red)
                                .frame(width: 7, height: 7)
                            Text(service.isRunning ? (loc.isSpanish ? "Activo" : "Online") : (loc.isSpanish ? "Detenido" : "Stopped"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                
                Divider()
                
                // Navigation items
                List(SidebarItem.allCases, selection: $selectedSidebarItem) { item in
                    NavigationLink(value: item) {
                        Label {
                            Text(item.title(isSpanish: loc.isSpanish))
                                .font(.system(size: 13, weight: selectedSidebarItem == item ? .semibold : .regular))
                        } icon: {
                            Image(systemName: item.icon)
                                .foregroundColor(selectedSidebarItem == item ? .accentColor : .secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
                
                Spacer()
                
                Divider()
                
                // Bottom Sidebar Controls (Language toggle & Status)
                HStack {
                    Button {
                        loc.toggleLanguage()
                    } label: {
                        HStack(spacing: 4) {
                            Text(loc.isSpanish ? "🇩🇴 ES" : "🇬🇧 EN")
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "globe")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(loc.isSpanish ? "Cambiar idioma (Español / English)" : "Switch language (English / Spanish)")
                    
                    Spacer()
                    
                    Button {
                        showMenuBarIcon.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showMenuBarIcon ? "menubar.rectangle" : "rectangle.slash")
                                .foregroundColor(showMenuBarIcon ? .accentColor : .secondary)
                            Text(showMenuBarIcon ? (loc.isSpanish ? "Barra: ON" : "Menu: ON") : (loc.isSpanish ? "Barra: OFF" : "Menu: OFF"))
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderless)
                    .help(loc.isSpanish ? "Activar/Desactivar ícono en la barra de menú superior" : "Toggle icon in top menu bar")
                }
                .padding(12)
            }
            .frame(minWidth: 220, idealWidth: 240)
        } detail: {
            VStack(spacing: 0) {
                // First-launch or pending prompt to place icon in top menu bar
                if !hasAskedAboutMenuBar {
                    menuBarPromptBanner
                }
                
                // Main Content View
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch selectedSidebarItem {
                        case .dashboard:
                            dashboardDetailView
                        case .models:
                            ModelManagerView(service: service)
                        case .server:
                            ServerControlView(service: service)
                        case .settings:
                            settingsDetailView
                        case .about:
                            AboutView()
                        }
                    }
                    .padding(24)
                }
            }
            .frame(minWidth: 560, minHeight: 480)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
    
    // MARK: - Menu Bar Prompt Banner
    private var menuBarPromptBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "menubar.arrow.up.rectangle")
                .font(.system(size: 22))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.isSpanish ? "¿Deseas colocar el monitor en la barra de menú superior?" : "Would you like to place the monitor in the top menu bar?")
                    .font(.system(size: 12, weight: .semibold))
                Text(loc.isSpanish ? "Podrás ver la velocidad en tok/s y el uso de tokens junto a Bluetooth y Wi-Fi." : "You'll be able to see token speed in tok/s and token usage next to Bluetooth and Wi-Fi.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(loc.isSpanish ? "Sí, colocar arriba" : "Yes, place in menu bar") {
                showMenuBarIcon = true
                hasAskedAboutMenuBar = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button(loc.isSpanish ? "No por ahora" : "Not now") {
                showMenuBarIcon = false
                hasAskedAboutMenuBar = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.accentColor.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Dashboard Detail View
    private var dashboardDetailView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.isSpanish ? "Monitor de Inferencia Local Splash" : "Splash Local Inference Monitor")
                        .font(.system(size: 20, weight: .bold))
                    Text(loc.isSpanish ? "Métricas de tokens, velocidad y memoria Metal en tiempo real" : "Real-time token metrics, throughput, and Metal memory")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        Task { await service.checkServerStatus() }
                    } label: {
                        Label(loc.isSpanish ? "Actualizar" : "Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Divider()
            
            // Embed the token metrics view
            TokenMetricsView(service: service)
        }
    }
    
    // MARK: - Settings Detail View
    private var settingsDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc.isSpanish ? "Configuración de Splash Monitor" : "Splash Monitor Settings")
                .font(.system(size: 18, weight: .bold))
            
            Divider()
            
            // Language selection
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.isSpanish ? "Idioma / Language" : "Language / Idioma")
                    .font(.system(size: 13, weight: .semibold))
                
                Picker("", selection: $loc.currentLanguage) {
                    Text("🇩🇴 Español").tag("es")
                    Text("🇬🇧 English").tag("en")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Menu bar icon toggle
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.isSpanish ? "Barra de Menú Superior (macOS Status Bar)" : "Top Menu Bar (macOS Status Bar)")
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle(loc.isSpanish ? "Mostrar ícono y métricas en la barra superior junto al Bluetooth" : "Show icon and metrics in the top bar next to Bluetooth", isOn: $showMenuBarIcon)
                    .font(.system(size: 12))
                
                if showMenuBarIcon {
                    Text(loc.isSpanish ? "Información en la barra:" : "Information in menu bar:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $service.menuBarDisplayMode) {
                        Text(loc.isSpanish ? "Solo Ícono" : "Icon only").tag("icon")
                        Text(loc.isSpanish ? "Ícono + Velocidad (tok/s)" : "Icon + Speed (tok/s)").tag("speed")
                        Text(loc.isSpanish ? "Ícono + Tokens Usados" : "Icon + Tokens Used").tag("tokens")
                        Text(loc.isSpanish ? "Ícono + Modelo" : "Icon + Model").tag("model")
                    }
                    .pickerStyle(.radioGroup)
                    .font(.system(size: 11))
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Refresh rate
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.isSpanish ? "Frecuencia de Actualización" : "Refresh Interval")
                    .font(.system(size: 13, weight: .semibold))
                
                HStack {
                    Slider(value: $service.refreshInterval, in: 0.5...5.0, step: 0.5)
                        .onChange(of: service.refreshInterval) { _ in
                            service.startPolling()
                        }
                    Text(String(format: "%.1f s", service.refreshInterval))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 50)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Paths & Environment
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.isSpanish ? "Rutas del Sistema" : "System Paths")
                    .font(.system(size: 13, weight: .semibold))
                
                Text("Splash CLI: \(service.splashExecutablePath)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Text(loc.isSpanish ? "Directorio de Modelos: \(service.modelsDirectory.path)" : "Models Directory: \(service.modelsDirectory.path)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}
