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
        case connectedApps
        case models
        case server
        case settings
        case about
        
        public var id: String { rawValue }
        
        public func title(isSpanish: Bool) -> String {
            switch self {
            case .dashboard: return isSpanish ? "Dashboard de Tokens" : "Token Dashboard"
            case .connectedApps: return isSpanish ? "Apps Conectadas" : "Connected Apps"
            case .models: return isSpanish ? "Gestor de Modelos" : "Model Manager"
            case .server: return isSpanish ? "Servidor y Agentes" : "Server & Agents"
            case .settings: return isSpanish ? "Configuración" : "Settings"
            case .about: return isSpanish ? "Acerca de" : "About"
            }
        }
        
        public var icon: String {
            switch self {
            case .dashboard: return "speedometer"
            case .connectedApps: return "app.connected.to.app.below.fill"
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
                    AppIconView(size: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text("Splash Monitor")
                                .font(.system(size: 15, weight: .bold))
                            
                            Text("BETA")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .cornerRadius(3)
                        }
                        
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
                VStack(spacing: 3) {
                    ForEach(SidebarItem.allCases) { item in
                        Button {
                            selectedSidebarItem = item
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedSidebarItem == item ? .accentColor : .secondary)
                                    .frame(width: 20, alignment: .center)
                                
                                Text(item.title(isSpanish: loc.isSpanish))
                                    .font(.system(size: 13, weight: selectedSidebarItem == item ? .semibold : .regular))
                                    .foregroundColor(selectedSidebarItem == item ? .primary : .secondary)
                                
                                Spacer()
                                
                                if item == .connectedApps {
                                    let count = service.connectedApps.filter { $0.status == .active }.count
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.green)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selectedSidebarItem == item ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                
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
                            if loc.isSystemMode {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 10))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(loc.isSpanish ? "Cambiar idioma (macOS / Español / English)" : "Switch language (macOS / English / Spanish)")
                    
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
                // Dependency missing banner / wizard
                if !service.isSplashInstalled {
                    DependencyInstallView(service: service)
                        .padding(16)
                }
                
                // Update available banner
                if service.hasUpdate {
                    updateBanner
                }
                
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
                        case .connectedApps:
                            ConnectedAppsView(service: service)
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAboutView"))) { _ in
                selectedSidebarItem = .about
            }
        }
    }
    
    // MARK: - Update Available Banner
    private var updateBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.isSpanish ? "Nueva versión disponible" : "Update available")
                    .font(.system(size: 12, weight: .semibold))
                Text(loc.isSpanish 
                    ? "Splash Monitor \(service.latestVersion ?? "nueva versión") está disponible para descargar."
                    : "Splash Monitor \(service.latestVersion ?? "new version") is available for download.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(loc.isSpanish ? "Descargar" : "Download") {
                if let url = URL(string: service.latestReleaseURL ?? "https://github.com/hometrix/SplashMonitor/releases/latest") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            
            Button(loc.isSpanish ? "Omitir" : "Skip") {
                service.hasUpdate = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.12))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.green.opacity(0.2)),
            alignment: .bottom
        )
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
            
            // Language Settings
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.isSpanish ? "Idioma de la Aplicación" : "Application Language")
                    .font(.system(size: 13, weight: .semibold))
                
                Picker("", selection: $loc.languageMode) {
                    let sysLang = Localization.detectSystemLanguage() == "es" ? "Español" : "English"
                    Text("\(loc.isSpanish ? "Automático (macOS: " : "Automatic (macOS: ")\(sysLang))").tag("system")
                    Text("🇩🇴 Español (República Dominicana)").tag("es")
                    Text("🇬🇧 English").tag("en")
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: 11))
                
                Text(loc.isSpanish ? "Sincroniza automáticamente con el idioma configurado en tu macOS o permite fijar uno manualmente." : "Automatically syncs with macOS system language or lets you choose manually.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
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
            
            // Check for updates
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(loc.isSpanish ? "Actualizaciones de Splash Monitor" : "Splash Monitor Updates")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if service.hasUpdate {
                        Text(loc.isSpanish ? "¡Nueva versión: \(service.latestVersion ?? "")!" : "New version: \(service.latestVersion ?? "")!")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Text(loc.isSpanish ? "Estás en la última versión" : "You're up to date")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 8) {
                    Button {
                        Task { await service.checkForUpdate() }
                    } label: {
                        Label(loc.isSpanish ? "Buscar actualizaciones" : "Check for updates", systemImage: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if service.hasUpdate, let url = service.latestReleaseURL {
                        Button {
                            if let releaseURL = URL(string: url) {
                                NSWorkspace.shared.open(releaseURL)
                            }
                        } label: {
                            Label(loc.isSpanish ? "Descargar nueva versión" : "Download new version", systemImage: "arrow.down.circle")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Dependencies & CLI System Info
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(loc.isSpanish ? "Motor de Inferencia Splash CLI" : "Splash CLI Inference Engine")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(service.isSplashInstalled ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(service.isSplashInstalled ? (service.splashVersion ?? (loc.isSpanish ? "Instalado" : "Installed")) : (loc.isSpanish ? "No instalado" : "Not installed"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(service.isSplashInstalled ? .green : .orange)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Splash CLI: \(service.splashExecutablePath)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text("Python Backend: \(service.splashPythonPath)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text(loc.isSpanish ? "Directorio de Modelos: \(service.modelsDirectory.path)" : "Models Directory: \(service.modelsDirectory.path)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    if service.isSplashInstalled {
                        Button {
                            service.upgradeSplashInTerminal()
                        } label: {
                            Label(loc.isSpanish ? "Actualizar Splash (brew upgrade)" : "Upgrade Splash (brew upgrade)", systemImage: "arrow.up.circle")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button {
                            service.installSplashDependency()
                        } label: {
                            Label(loc.isSpanish ? "Instalar Splash (brew install)" : "Install Splash (brew install)", systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    Button {
                        service.checkDependencies()
                        service.refreshInstalledModels()
                    } label: {
                        Label(loc.isSpanish ? "Verificar" : "Verify", systemImage: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Link(destination: URL(string: "https://github.com/incoai/splash")!) {
                        HStack(spacing: 3) {
                            Text("GitHub incoai/splash")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.system(size: 10))
                    }
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}
