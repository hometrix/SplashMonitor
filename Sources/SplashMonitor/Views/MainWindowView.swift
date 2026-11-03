import SwiftUI
import AppKit

public struct MainWindowView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true
    @AppStorage("hasAskedAboutMenuBar") private var hasAskedAboutMenuBar: Bool = false
    @AppStorage("menuBarOnlyMode") private var menuBarOnlyMode: Bool = false
    @ObservedObject private var notifications = NotificationService.shared
    @ObservedObject private var autoLaunch = AutoLaunchService.shared
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    @State private var showOptimalAppliedFeedback: Bool = false

    
    public enum SidebarItem: String, CaseIterable, Identifiable {
        case dashboard
        case chat
        case connectedApps
        case models
        case server
        case modelTesting
        case settings
        case about
        
        public var id: String { rawValue }
        
        public func title(isSpanish: Bool) -> String {
            switch self {
            case .dashboard: return isSpanish ? "Dashboard de Tokens" : "Token Dashboard"
            case .chat: return isSpanish ? "Chat con Modelo" : "Model Chat"
            case .connectedApps: return isSpanish ? "Apps Conectadas" : "Connected Apps"
            case .models: return isSpanish ? "Gestor de Modelos" : "Model Manager"
            case .server: return isSpanish ? "Servidor y Agentes" : "Server & Agents"
            case .modelTesting: return isSpanish ? "Test de Modelos" : "Model Testing"
            case .settings: return isSpanish ? "Configuración" : "Settings"
            case .about: return isSpanish ? "Acerca de" : "About"
            }
        }
        
        public var icon: String {
            switch self {
            case .dashboard: return "speedometer"
            case .chat: return "bubble.left.and.bubble.right.fill"
            case .connectedApps: return "app.connected.to.app.below.fill"
            case .models: return "shippingbox"
            case .server: return "server.rack"
            case .modelTesting: return "testtube.2"
            case .settings: return "gearshape"
            case .about: return "info.circle"
            }
        }
    }
    
    public init(service: SplashService, initialTab: SidebarItem = .dashboard) {
        self.service = service
        self._selectedSidebarItem = State(initialValue: initialTab)
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
                
                // Splash CLI engine update banner
                if service.hasSplashCliUpdate {
                    splashCliUpdateBanner
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
                if selectedSidebarItem == .chat {
                    ChatView(service: service)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            switch selectedSidebarItem {
                            case .dashboard:
                                dashboardDetailView
                            case .chat:
                                EmptyView()
                            case .connectedApps:
                                ConnectedAppsView(service: service)
                            case .models:
                                ModelManagerView(service: service)
                            case .server:
                                ServerControlView(service: service)
                            case .modelTesting:
                                ModelTestingView(service: service)
                            case .settings:
                                settingsDetailView
                            case .about:
                                AboutView()
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .frame(minWidth: 560, minHeight: 480)
            .background(Color(nsColor: .windowBackgroundColor))
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAboutView"))) { _ in
                selectedSidebarItem = .about
            }
        }
    }
    
    // MARK: - Splash CLI Engine Update Available Banner
    private var splashCliUpdateBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.isSpanish ? "Nueva versión del motor Splash disponible" : "New Splash engine version available")
                    .font(.system(size: 12, weight: .semibold))
                Text(loc.isSpanish 
                    ? "Splash CLI \(service.latestSplashCliVersion.isEmpty ? "nueva versión" : service.latestSplashCliVersion) está disponible (instalada: \(service.installedSplashCliVersion.isEmpty ? "desconocida" : service.installedSplashCliVersion))."
                    : "Splash CLI \(service.latestSplashCliVersion.isEmpty ? "new version" : service.latestSplashCliVersion) is available (installed: \(service.installedSplashCliVersion.isEmpty ? "unknown" : service.installedSplashCliVersion)).")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(loc.isSpanish ? "Actualizar Splash" : "Upgrade Splash") {
                service.upgradeSplashInTerminal()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
            
            if !service.latestSplashCliReleaseURL.isEmpty, let url = URL(string: service.latestSplashCliReleaseURL) {
                Button(loc.isSpanish ? "Ver notas" : "View notes") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Button(loc.isSpanish ? "Omitir" : "Skip") {
                service.hasSplashCliUpdate = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.2)),
            alignment: .bottom
        )
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
            
            // MARK: Modelo activo
            activeModelCard
            
            Divider()
            
            // Embed the token metrics view
            TokenMetricsView(service: service)
        }
    }
    
    /// Tarjeta compacta que muestra el modelo en ejecución, puerto y versión de Splash.
    @ViewBuilder
    private var activeModelCard: some View {
        let isRunning = service.isRunning
        let modelRaw  = service.activeModel
        let modelShort = modelRaw.components(separatedBy: "/").last ?? modelRaw
        let modelClean = modelShort
            .replacingOccurrences(of: "-Splash", with: "")
            .replacingOccurrences(of: "-GGUF", with: "")
        
        HStack(spacing: 12) {
            // Estado indicator
            Circle()
                .fill(isRunning ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 10)
                .shadow(color: isRunning ? .green.opacity(0.6) : .clear, radius: 4)
            
            // Nombre del modelo
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.isSpanish ? "Modelo en ejecución" : "Running model")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                if isRunning {
                    Text(modelClean)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text(modelRaw)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(loc.isSpanish ? "Servidor detenido" : "Server stopped")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Puerto y versión Splash
            VStack(alignment: .trailing, spacing: 4) {
                if isRunning {
                    HStack(spacing: 4) {
                        Image(systemName: "network")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(":\(service.activePort)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                }
                
                if let splashVer = service.splashVersion {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Splash \(splashVer)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isRunning ? Color.green.opacity(0.35) : Color.secondary.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
    }

    
    // MARK: - Settings Detail View
    private var settingsDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc.isSpanish ? "Configuración de Splash Monitor" : "Splash Monitor Settings")
                .font(.system(size: 18, weight: .bold))
            
            Divider()
            
            // Perfil de Rendimiento Óptimo (Apple Silicon M4 Max / 64 GB)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(loc.isSpanish ? "Perfil de Rendimiento Óptimo" : "Optimal Performance Profile")
                                .font(.system(size: 13, weight: .bold))
                            
                            Text("M4 MAX / 64 GB")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.blue)
                                .cornerRadius(3)
                        }
                        
                        Text(loc.isSpanish
                             ? "Restablece los parámetros de máxima velocidad y capacidad recomendados para tu Apple Silicon: GDN BF16 (-50% RAM), Thinking Budget 8K, Caché SSD persistente, Contexto 128K, Inactividad off (Siempre en RAM), Puerto 8005, Red LAN 0.0.0.0 y CORS abierto (*)."
                             : "Restores recommended high-speed and capacity settings for Apple Silicon: GDN BF16 (-50% RAM), Thinking Budget 8K, Persistent SSD cache, Context 128K, Idle off (Always in RAM), Port 8005, LAN 0.0.0.0, and open CORS (*).")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        service.restoreOptimalProfile()
                        showMenuBarIcon = true
                        withAnimation {
                            showOptimalAppliedFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                showOptimalAppliedFeedback = false
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                            Text(loc.isSpanish ? "Restaurar Configuración Óptima" : "Restore Optimal Configuration")
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.regular)
                }
                
                if showOptimalAppliedFeedback {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text(loc.isSpanish
                             ? "¡Configuración óptima restaurada y guardada con éxito en UserDefaults (M4 Max / 64 GB)!"
                             : "Optimal configuration restored and saved successfully in UserDefaults (M4 Max / 64 GB)!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(6)
                    .transition(.opacity)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue.opacity(0.25), lineWidth: 1)
            )
            
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
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Modo Solo Barra de Menú
                    Toggle(isOn: $menuBarOnlyMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.isSpanish ? "Modo Solo Barra de Menú" : "Menu Bar Only Mode")
                                .font(.system(size: 12))
                            Text(loc.isSpanish
                                 ? "Cmd+Q oculta la app del Dock y del listado de tareas en lugar de cerrarla. Usa ⌥⌘Q (Cmd+Option+Q) para salir completamente."
                                 : "Cmd+Q hides the app from the Dock and task list instead of quitting. Use ⌥⌘Q (Cmd+Option+Q) to quit completely.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 12))
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Inicio Automático al Encender el Mac (Launch at Login)
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.isSpanish ? "Inicio del Sistema" : "System Startup")
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle(isOn: Binding(
                    get: { autoLaunch.isEnabled },
                    set: { autoLaunch.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.isSpanish ? "Iniciar Splash Monitor al encender el Mac" : "Launch Splash Monitor at startup")
                            .font(.system(size: 12))
                        Text(loc.isSpanish
                             ? "Ejecuta automáticamente la aplicación en segundo plano al iniciar sesión en macOS."
                             : "Automatically launch the app in background when logging in to macOS.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 12))
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Notificaciones de macOS
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.isSpanish ? "Notificaciones de macOS" : "macOS Notifications")
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle(isOn: $notifications.isNotificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.isSpanish ? "Alertas y notificaciones del sistema" : "System alerts and notifications")
                            .font(.system(size: 12))
                        Text(loc.isSpanish
                             ? "Recibe avisos cuando el servidor se inicie, se detenga inesperadamente o si la memoria unificada del Mac entra en presión crítica."
                             : "Receive alerts when the server starts, stops unexpectedly, or if unified memory enters critical pressure.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 12))
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            // Shell integration (P-09)
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.isSpanish ? "Integración con el Shell" : "Shell Integration")
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle(loc.isSpanish
                       ? "Permitir a Splash Monitor añadir una línea a tu ~/.zshrc"
                       : "Allow Splash Monitor to add a line to your ~/.zshrc",
                       isOn: Binding(
                            get: { service.shellConfigConsent },
                            set: { allowed in
                                service.shellConfigConsent = allowed
                                service.shellConfigDeclined = !allowed
                                if allowed {
                                    service.syncShellEnvironment(port: service.activePort)
                                } else {
                                    service.clearShellEnvironment()
                                }
                            }
                       ))
                    .font(.system(size: 12))
                
                Text(loc.isSpanish
                     ? "Sin esta línea, los agentes lanzados desde una terminal externa no heredan el puerto activo. El fichero ~/.splash_monitor_env se escribe siempre, con o sin permiso."
                     : "Without this line, agents launched from an external terminal do not inherit the active port. The ~/.splash_monitor_env file is always written, with or without permission.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                if service.shellConfigConsent {
                    Button(loc.isSpanish ? "Deshacer cambios en ~/.zshrc" : "Undo changes to ~/.zshrc") {
                        service.clearShellEnvironment()
                        service.shellConfigConsent = false
                        service.shellConfigDeclined = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
            
            // Server Network & Context Options
            VStack(alignment: .leading, spacing: 10) {
                Text(loc.isSpanish ? "Opciones del Motor de Inferencia" : "Inference Engine Options")
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle(loc.isSpanish
                       ? "Permitir conexiones entrantes desde la red local (enlazar a 0.0.0.0)"
                       : "Allow incoming connections from local network (bind to 0.0.0.0)",
                       isOn: $service.listenOnAllInterfaces)
                    .font(.system(size: 12))
                
                Text(loc.isSpanish
                     ? "Por defecto, Splash solo escucha en 127.0.0.1 (localhost). Activa esta opción para permitir que otros dispositivos, servidores o agentes en tu red local (LAN) realicen inferencias en tu Mac."
                     : "By default, Splash only listens on 127.0.0.1 (localhost). Enable this option to let other devices, servers, or agents on your local network (LAN) run inference on this Mac.")
                    .font(.system(size: 10))
                if service.listenOnAllInterfaces {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc.isSpanish ? "Dominios o Hosts Permitidos (--allowed-host):" : "Allowed Domains or Hosts (--allowed-host):")
                            .font(.system(size: 11, weight: .medium))
                        
                        TextField(loc.isSpanish ? "ej. midominio.duckdns.org, mimac.local" : "e.g. mydomain.duckdns.org, mymac.local", text: $service.allowedHosts)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                        
                        Text(loc.isSpanish
                             ? "Splash bloquea por seguridad cualquier petición con un Host desconocido (protección DNS Rebinding). Ingresa tus dominios DDNS o nombres de host separados por comas."
                             : "Splash blocks requests with unknown Host headers for security (DNS Rebinding protection). Enter your DDNS domains or hostnames separated by commas.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.isSpanish ? "Orígenes Web y Extensiones (--allowed-origin):" : "Allowed Web Origins & Extensions (--allowed-origin):")
                        .font(.system(size: 11, weight: .medium))
                    
                    TextField(loc.isSpanish ? "ej. * (para extensión de Chrome y web local)" : "e.g. * (for Chrome extension and local web)", text: $service.allowedOrigins)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    
                    Text(loc.isSpanish
                         ? "Permite que extensiones de navegador (Chrome, Arc, Brave), aplicaciones Web locales y Tauri interactúen con Splash vía CORS. Por defecto '*' permite cualquier origen local o extensión."
                         : "Allows browser extensions (Chrome, Arc, Brave), local web apps, and Tauri to interact with Splash via CORS. Default '*' allows any local origin or extension.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                
                Divider()
                
                HStack {
                    Text(loc.isSpanish ? "Límite de ventana de contexto:" : "Context window limit:")
                        .font(.system(size: 12))
                    
                    Spacer()
                    
                    Picker("", selection: $service.maxContext) {
                        Text(loc.isSpanish ? "Automático (gestión de Splash)" : "Automatic (managed by Splash)").tag("auto")
                        Text("16K (16,384 tokens)").tag("16K")
                        Text("32K (32,768 tokens)").tag("32K")
                        Text("64K (65,536 tokens)").tag("64K")
                        Text("128K (131,072 tokens)").tag("128K")
                        Text("256K (262,144 tokens)").tag("256K")
                        Text("512K (524,288 tokens)").tag("512K")
                        Text(loc.isSpanish ? "1M (1,000,000 tokens · YaRN)" : "1M (1,000,000 tokens · YaRN)").tag("1M")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text(loc.isSpanish
                     ? "Configura el parámetro --max-context para limitar o expandir la memoria reservada para el historial de tokens (Splash 1.4.0+ soporta hasta 1M con YaRN)."
                     : "Configures the --max-context flag to limit or expand memory reserved for token history (Splash 1.4.0+ supports up to 1M with YaRN).")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Text(loc.isSpanish ? "Liberación de memoria por inactividad:" : "Idle memory release timeout:")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $service.idleRelease) {
                        Text(loc.isSpanish ? "1 min (Ahorro rápido)" : "1 min (Fast saving)").tag("1m")
                        Text(loc.isSpanish ? "2 min (Agresivo)" : "2 min (Aggressive)").tag("2m")
                        Text(loc.isSpanish ? "5 min (Equilibrado)" : "5 min (Balanced)").tag("5m")
                        Text(loc.isSpanish ? "10 min (Por defecto Splash)" : "10 min (Splash default)").tag("10m")
                        Text(loc.isSpanish ? "30 min (Extendido)" : "30 min (Extended)").tag("30m")
                        Text(loc.isSpanish ? "Desactivado (Siempre en RAM)" : "Disabled (Always in RAM)").tag("off")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text(loc.isSpanish
                     ? "Parámetro --idle-release: desvincula y libera los pesos en VRAM cuando no hay peticiones activas, restaurándolos al vuelo al recibir nuevas consultas."
                     : "Flag --idle-release: unwires and frees VRAM model weights when idle, restoring them on-the-fly when new queries arrive.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Text(loc.isSpanish ? "Presupuesto máximo de memoria Metal:" : "Max Metal memory budget:")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $service.maxMemory) {
                        Text(loc.isSpanish ? "Automático (sin límite)" : "Automatic (unlimited)").tag("auto")
                        Text("16 GB").tag("16G")
                        Text("24 GB").tag("24G")
                        Text("28 GB").tag("28G")
                        Text("32 GB").tag("32G")
                        Text("40 GB").tag("40G")
                        Text("48 GB").tag("48G")
                        Text("64 GB").tag("64G")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text(loc.isSpanish
                     ? "Parámetro --max-memory: limita el techo de memoria unificada asignable a Metal para no copar la RAM disponible en el Mac."
                     : "Flag --max-memory: limits the Metal unified memory budget to avoid exhausting Mac RAM.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                Toggle(loc.isSpanish
                       ? "Protección automática ante presión crítica de memoria macOS"
                       : "Automatic protection under macOS critical memory pressure",
                       isOn: $service.autoReleaseOnMemoryPressure)
                    .font(.system(size: 12))
                
                Text(loc.isSpanish
                     ? "Monitorea eventos del kernel de macOS. Si el sistema entra en presión de memoria crítica y Splash está inactivo, libera los recursos para evitar bloqueos del sistema."
                     : "Monitors macOS kernel events. If the system enters critical memory pressure and Splash is idle, frees resources to prevent system freezing.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                Toggle(loc.isSpanish
                       ? "Modo Solo Lenguaje / Código (--language-only)"
                       : "Language / Code Only mode (--language-only)",
                       isOn: $service.languageOnly)
                    .font(.system(size: 12))
                
                Text(loc.isSpanish
                     ? "Desactiva la carga del proyector de visión (mmproj). Requerido para modelos de código GGUF (como Tiel-Coder, Qwopus, Cyber-Tiel) que no incluyen pesos de imágenes."
                     : "Disables vision projector (mmproj) loading. Required for GGUF coder models (like Tiel-Coder, Qwopus, Cyber-Tiel) that lack image weights.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Text(loc.isSpanish ? "Verificación de Borrador MoE (--verify-rows):" : "MoE Draft Verification (--verify-rows):")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $service.verifyRows) {
                        Text(loc.isSpanish ? "Auto (Adaptativa, +13–42% vel)" : "Auto (Adaptive, +13–42% speed)").tag("auto")
                        Text(loc.isSpanish ? "All (Todas las filas, Determinista)" : "All (All rows, Deterministic)").tag("all")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text(loc.isSpanish
                     ? "Parámetro --verify-rows (Splash 1.4.0+): 'auto' adapta la verificación de tokens de borrador aumentando la velocidad de decodificación. 'all' garantiza reproducibilidad exacta de salidas."
                     : "Flag --verify-rows (Splash 1.4.0+): 'auto' adapts speculative draft token verification for faster decode. 'all' ensures deterministic output reproducibility.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack {
                    Text(loc.isSpanish ? "Memoria en RAM para Expertos MoE (--expert-memory):" : "MoE Experts RAM Budget (--expert-memory):")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $service.expertMemory) {
                        Text(loc.isSpanish ? "Automático (gestión de Splash)" : "Automatic (managed by Splash)").tag("auto")
                        Text(loc.isSpanish ? "Desactivado (Todos en RAM)" : "Disabled (All resident in RAM)").tag("off")
                        Text("4 GB (Streaming SSD)").tag("4G")
                        Text("8 GB (Streaming SSD)").tag("8G")
                        Text("12 GB (Streaming SSD)").tag("12G")
                        Text("16 GB (Streaming SSD)").tag("16G")
                        Text("24 GB (Streaming SSD)").tag("24G")
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
                
                Text(loc.isSpanish
                     ? "Parámetro --expert-memory (Splash 1.4.0+): permite mantener expertos MoE en RAM y transmitir los restantes en streaming desde el SSD ultrarrápido sin saturar la memoria."
                     : "Flag --expert-memory (Splash 1.4.0+): retains active MoE experts in RAM and streams the rest on-the-fly from the high-speed SSD.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.isSpanish ? "Flags CLI Adicionales de Splash:" : "Additional Splash CLI Flags:")
                        .font(.system(size: 11, weight: .medium))
                    
                    TextField(loc.isSpanish ? "ej. --no-webui --max-cache-disk 50GB" : "e.g. --no-webui --max-cache-disk 50GB", text: $service.customServerFlags)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    
                    Text(loc.isSpanish
                         ? "Parámetros y banderas arbitrarias adicionales que se pasarán al final de 'splash serve'. Se sanean automáticamente para evitar inyección de comandos."
                         : "Arbitrary additional flags passed directly to 'splash serve'. Automatically sanitized to prevent command injection.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
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
                    if service.hasSplashCliUpdate {
                        Text(loc.isSpanish ? "¡Nueva versión \(service.latestSplashCliVersion)!" : "New version \(service.latestSplashCliVersion)!")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(service.isSplashInstalled ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(service.isSplashInstalled 
                            ? (!service.installedSplashCliVersion.isEmpty ? "v\(service.installedSplashCliVersion)" : (service.splashVersion ?? (loc.isSpanish ? "Instalado" : "Installed"))) 
                            : (loc.isSpanish ? "No instalado" : "Not installed"))
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
                        if service.hasSplashCliUpdate {
                            Button {
                                service.upgradeSplashInTerminal()
                            } label: {
                                Label(loc.isSpanish ? "Actualizar Splash (brew upgrade)" : "Upgrade Splash (brew upgrade)", systemImage: "arrow.up.circle")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                        } else {
                            Button {
                                service.upgradeSplashInTerminal()
                            } label: {
                                Label(loc.isSpanish ? "Actualizar Splash (brew upgrade)" : "Upgrade Splash (brew upgrade)", systemImage: "arrow.up.circle")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
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
                        Task {
                            service.checkDependencies()
                            service.refreshInstalledModels()
                            await service.checkSplashCliUpdate()
                        }
                    } label: {
                        if service.isCheckingSplashCliUpdate {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(loc.isSpanish ? "Buscar actualización" : "Check update", systemImage: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
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
