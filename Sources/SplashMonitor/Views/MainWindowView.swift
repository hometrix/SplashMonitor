import SwiftUI
import AppKit

public struct MainWindowView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true
    @AppStorage("hasAskedAboutMenuBar") private var hasAskedAboutMenuBar: Bool = false
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    /// Write-only field for a new Hugging Face token. The stored token is never
    /// pre-filled here (only its masked preview is shown) so the secret stays in the Keychain.
    @State private var hfTokenInput: String = ""
    
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
            
            // Hugging Face token: authenticated, faster (and gated-capable) downloads
            hfTokenCard
            
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
        .onAppear {
            // The Keychain is the source of truth: refresh the badge and the
            // hf_transfer detection every time Settings is opened.
            service.refreshHFTokenState()
            service.refreshHFTransferAvailability()
        }
    }
    
    // MARK: - Hugging Face Token Card
    private var hfTokenCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(tr(es: "Hugging Face — Descargas Autenticadas", en: "Hugging Face — Authenticated Downloads"))
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(service.hasHFToken ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(service.hasHFToken
                         ? (service.hfTokenPreview ?? tr(es: "Guardado", en: "Stored"))
                         : tr(es: "Sin token", en: "No token"))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(service.hasHFToken ? .green : .orange)
                }
            }
            
            Text(tr(
                es: "Un token de Hugging Face acelera las descargas (evita el límite de tasa anónimo), da acceso a repos gated o privados y activa el descargador Rust hf_transfer cuando está instalado. Se guarda en el Llavero de macOS (servicio SplashMonitor.hf) — nunca en UserDefaults ni en los logs.",
                en: "A Hugging Face token speeds up downloads (it lifts the anonymous rate limit), unlocks gated or private repos and enables the Rust hf_transfer downloader when installed. It is stored in the macOS Keychain (service SplashMonitor.hf) — never in UserDefaults or logs."
            ))
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            
            HStack(spacing: 6) {
                SecureField(tr(es: "hf_… (pegar token)", en: "hf_… (paste token)"), text: $hfTokenInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit { saveHFToken() }
                
                Button(tr(es: "Guardar", en: "Save")) {
                    saveHFToken()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(hfTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button {
                    Task { await service.testHFToken() }
                } label: {
                    if service.isTestingHFToken {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text(tr(es: "Probando…", en: "Testing…"))
                        }
                    } else {
                        Text(tr(es: "Probar token", en: "Test token"))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!service.hasHFToken || service.isTestingHFToken)
                
                if service.hasHFToken {
                    Button(role: .destructive) {
                        removeHFToken()
                    } label: {
                        Text(tr(es: "Eliminar", en: "Remove"))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Link(destination: HuggingFaceSupport.tokenSettingsURL) {
                    HStack(spacing: 3) {
                        Text(tr(es: "Crear token", en: "Create token"))
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.system(size: 10))
                }
            }
            
            if let status = hfTokenStatus {
                HStack(spacing: 5) {
                    Image(systemName: status.icon)
                        .font(.system(size: 10))
                        .foregroundColor(status.color)
                    Text(status.text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(status.color)
                        .textSelection(.enabled)
                }
            }
            
            Divider()
            
            // hf_transfer availability in the engine's Python environment
            HStack(spacing: 5) {
                if service.isCheckingHFTransfer {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: service.isHFTransferAvailable ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 10))
                        .foregroundColor(service.isHFTransferAvailable ? .green : .secondary)
                }
                
                Text(service.isHFTransferAvailable
                     ? tr(es: "hf_transfer detectado: las descargas lanzadas desde la app usan el backend Rust.", en: "hf_transfer detected: downloads started from the app use the Rust backend.")
                     : tr(es: "hf_transfer no está instalado en el entorno del motor; las descargas funcionan, pero más lentas.", en: "hf_transfer is not installed in the engine environment; downloads still work, just slower."))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                if !service.isHFTransferAvailable, !service.splashPythonPath.isEmpty {
                    Text("\(service.splashPythonPath) -m pip install hf_transfer")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                Spacer()
                
                Button {
                    service.refreshHFTransferAvailability()
                } label: {
                    Text(tr(es: "Verificar", en: "Recheck"))
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .disabled(service.isCheckingHFTransfer)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
    
    /// Colour-coded message under the token field (Keychain error, test outcome).
    private var hfTokenStatus: (text: String, color: Color, icon: String)? {
        if let error = service.hfTokenError {
            return (
                tr(es: "No se pudo guardar en el Llavero: \(error)", en: "Could not save to the Keychain: \(error)"),
                .red,
                "exclamationmark.triangle.fill"
            )
        }
        switch service.hfTokenTestResult {
        case .success(let user):
            return (
                tr(es: "Token válido — cuenta: \(user)", en: "Valid token — account: \(user)"),
                .green,
                "checkmark.seal.fill"
            )
        case .invalidToken(let code):
            return (
                tr(es: "Hugging Face rechazó el token (HTTP \(code)). Genera uno nuevo con permiso de lectura.",
                   en: "Hugging Face rejected the token (HTTP \(code)). Create a new one with read access."),
                .red,
                "xmark.seal.fill"
            )
        case .networkError(let message):
            return (
                tr(es: "No se pudo verificar el token: \(message)", en: "Could not verify the token: \(message)"),
                .orange,
                "exclamationmark.triangle.fill"
            )
        case .noToken:
            return (
                tr(es: "Añade un token para poder probarlo.", en: "Add a token to test it."),
                .secondary,
                "info.circle"
            )
        case .none:
            return nil
        }
    }
    
    /// Persist the typed token and immediately validate it.
    private func saveHFToken() {
        let value = hfTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if service.setHFToken(value) {
            // Never keep the secret in the view state after it reaches the Keychain.
            hfTokenInput = ""
            Task { await service.testHFToken() }
        }
    }
    
    /// Drop the stored token (Keychain + shell env export).
    private func removeHFToken() {
        service.setHFToken(nil)
        hfTokenInput = ""
    }
}
