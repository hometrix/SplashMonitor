import SwiftUI
import AppKit

public struct ConnectedAppsView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    @State private var copiedMessage: String? = nil
    @State private var selectedTab: ConnectedAppsTab = .detected
    
    public enum ConnectedAppsTab: String, CaseIterable, Identifiable {
        case detected
        case quickConnect
        
        public var id: String { rawValue }
        
        public func title(isSpanish: Bool) -> String {
            switch self {
            case .detected: return isSpanish ? "Apps Detectadas" : "Detected Apps"
            case .quickConnect: return isSpanish ? "Guía de Integración" : "Integration Guide"
            }
        }
    }
    
    public init(service: SplashService) {
        self.service = service
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView
            
            // Metrics Summary
            metricsSummaryRow
            
            // Tab Picker
            Picker("", selection: $selectedTab) {
                ForEach(ConnectedAppsTab.allCases) { tab in
                    Text(tab.title(isSpanish: loc.isSpanish)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)
            
            // Content according to tab
            if selectedTab == .detected {
                detectedAppsListSection
            } else {
                quickConnectGuideSection
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(tr(es: "Aplicaciones y Clientes Conectados", en: "Connected Applications & Clients"))
                        .font(.system(size: 20, weight: .bold))
                    
                    if service.isRunning {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                            Text(tr(es: "Puerto \(service.activePort)", en: "Port \(service.activePort)"))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(6)
                    }
                }
                
                Text(tr(
                    es: "Monitoreo en tiempo real de editores, agentes autónomos y procesos consumiendo el motor Splash",
                    en: "Real-time monitoring of editors, autonomous agents, and processes consuming the Splash engine"
                ))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                Task {
                    await service.scanConnectedClients()
                }
            } label: {
                Label(tr(es: "Escanear", en: "Scan Now"), systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    // MARK: - Metrics Summary Row
    private var metricsSummaryRow: some View {
        HStack(spacing: 12) {
            let activeCount = service.connectedApps.filter { $0.status == .active || $0.status == .idle }.count
            let totalSockets = service.connectedApps.reduce(0) { $0 + $1.connectionCount }
            
            StatBadgeCard(
                title: tr(es: "Apps Conectadas", en: "Connected Apps"),
                value: "\(activeCount)",
                subtitle: tr(es: "\(service.connectedApps.count) en esta sesión", en: "\(service.connectedApps.count) this session"),
                icon: "app.connected.to.app.below.fill",
                color: activeCount > 0 ? .green : .secondary
            )
            
            StatBadgeCard(
                title: tr(es: "Sockets TCP Activos", en: "Active TCP Sockets"),
                value: "\(totalSockets)",
                subtitle: tr(es: "Conexiones 127.0.0.1", en: "127.0.0.1 connections"),
                icon: "network",
                color: totalSockets > 0 ? .blue : .secondary
            )
            
            StatBadgeCard(
                title: tr(es: "Motor en Ejecución", en: "Running Engine"),
                value: service.isRunning ? service.activeModel.components(separatedBy: "/").last ?? service.activeModel : tr(es: "Apagado", en: "Offline"),
                subtitle: service.isRunning ? tr(es: "Listo para inferencia", en: "Ready for inference") : tr(es: "Inicia el servidor", en: "Start the server"),
                icon: "cpu.fill",
                color: service.isRunning ? .purple : .red
            )
        }
    }
    
    // MARK: - Detected Apps List Section
    private var detectedAppsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !service.isRunning {
                serverOfflinePlaceholder
            } else if service.connectedApps.isEmpty {
                emptyAppsPlaceholder
            } else {
                VStack(spacing: 10) {
                    ForEach(service.connectedApps) { app in
                        ConnectedAppCard(app: app, service: service, loc: loc)
                    }
                }
            }
        }
    }
    
    // MARK: - Server Offline Placeholder
    private var serverOfflinePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text(tr(es: "El servidor Splash está detenido", en: "Splash server is offline"))
                .font(.system(size: 14, weight: .bold))
            
            Text(tr(
                es: "Para ver qué aplicaciones y agentes están consumiendo el motor, primero arranca el servidor desde la pestaña 'Servidor y Agentes'.",
                en: "To see which applications and agents are consuming the engine, first start the server from the 'Server & Agents' tab."
            ))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
            
            Button {
                service.startServer(model: service.selectedModelForLaunch, port: service.activePort)
            } label: {
                Label(tr(es: "Arrancar Servidor Ahora", en: "Start Server Now"), systemImage: "play.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.regular)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
    
    // MARK: - Empty Apps Placeholder
    private var emptyAppsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 34))
                .foregroundColor(.accentColor.opacity(0.8))
            
            Text(tr(es: "Escuchando conexiones entrantes...", en: "Listening for incoming connections..."))
                .font(.system(size: 14, weight: .semibold))
            
            Text(tr(
                es: "Aún no hay clientes conectados al puerto \(service.activePort).\nPuedes conectar Cursor, VS Code, Claude Code, OpenCode, Hermes o cualquier app compatible con la API de OpenAI.",
                en: "No clients connected to port \(service.activePort) yet.\nYou can connect Cursor, VS Code, Claude Code, OpenCode, Hermes, or any OpenAI API compatible app."
            ))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 450)
            
            HStack(spacing: 10) {
                Button {
                    copyToClipboard("http://127.0.0.1:\(service.activePort)/v1")
                    showCopied(tr(es: "¡URL Copiada!", en: "URL Copied!"))
                } label: {
                    Label(tr(es: "Copiar OpenAI Base URL", en: "Copy OpenAI Base URL"), systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    selectedTab = .quickConnect
                } label: {
                    Label(tr(es: "Ver Guía de Conexión", en: "View Connection Guide"), systemImage: "book.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.top, 4)
            
            if let msg = copiedMessage {
                Text(msg)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
    
    // MARK: - Quick Connect Guide Section
    private var quickConnectGuideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr(es: "Conectar tus Aplicaciones e IDEs Favoritos", en: "Connect Your Favorite Apps & IDEs"))
                .font(.system(size: 14, weight: .bold))
            
            Text(tr(
                es: "Splash expone una API compatible al 100% con OpenAI y Anthropic en tu máquina local:",
                en: "Splash exposes a 100% OpenAI & Anthropic compatible API on your local machine:"
            ))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                IntegrationGuideCard(
                    title: "Cursor IDE",
                    subtitle: tr(es: "Editor AI nativo", en: "Native AI Code Editor"),
                    icon: "chevron.left.forwardslash.chevron.right",
                    badge: "OpenAI API",
                    color: .purple,
                    steps: [
                        tr(es: "1. Ve a Settings → Models en Cursor", en: "1. Go to Settings → Models in Cursor"),
                        tr(es: "2. Activa 'OpenAI API Key' (ingresa cualquier texto, ej. 'splash')", en: "2. Enable 'OpenAI API Key' (enter any text, e.g. 'splash')"),
                        tr(es: "3. En 'Override OpenAI Base URL', coloca:", en: "3. In 'Override OpenAI Base URL', enter:"),
                        "http://127.0.0.1:\(service.activePort)/v1"
                    ],
                    copyText: "http://127.0.0.1:\(service.activePort)/v1"
                )
                
                IntegrationGuideCard(
                    title: "VS Code (Continue / Cline)",
                    subtitle: tr(es: "Extensiones de Inteligencia Artificial", en: "AI Coding Extensions"),
                    icon: "sidebar.squares.trailing",
                    badge: "OpenAI Compatible",
                    color: .blue,
                    steps: [
                        tr(es: "1. En la extensión Continue/Cline, añade un nuevo modelo", en: "1. In Continue/Cline extension, add a new model"),
                        tr(es: "2. Selecciona proveedor 'OpenAI' o 'Custom'", en: "2. Select provider 'OpenAI' or 'Custom'"),
                        tr(es: "3. Configura el apiBase en config.json:", en: "3. Set apiBase in config.json:"),
                        "http://127.0.0.1:\(service.activePort)/v1"
                    ],
                    copyText: "http://127.0.0.1:\(service.activePort)/v1"
                )
                
                IntegrationGuideCard(
                    title: "Claude Code CLI",
                    subtitle: tr(es: "Agente terminal de Anthropic", en: "Anthropic terminal agent"),
                    icon: "brain.head.profile",
                    badge: "Anthropic API",
                    color: .orange,
                    steps: [
                        tr(es: "1. Exporta la variable de entorno de Splash:", en: "1. Export Splash environment variable:"),
                        "export ANTHROPIC_BASE_URL=\"http://127.0.0.1:\(service.activePort)\"",
                        tr(es: "2. Lanza Claude Code en tu terminal:", en: "2. Launch Claude Code in your terminal:"),
                        "splash claude"
                    ],
                    copyText: "export ANTHROPIC_BASE_URL=\"http://127.0.0.1:\(service.activePort)\"\nsplash claude"
                )
                
                IntegrationGuideCard(
                    title: "Chatbox / NextChat / WebUI",
                    subtitle: tr(es: "Interfaces de Chatbot para macOS", en: "macOS Chatbot Interfaces"),
                    icon: "bubble.left.and.bubble.right.fill",
                    badge: "OpenAI Format",
                    color: .green,
                    steps: [
                        tr(es: "1. En Ajustes del Chatbot, elige 'OpenAI API'", en: "1. In Chatbot Settings, choose 'OpenAI API'"),
                        tr(es: "2. Host / API Host:", en: "2. Host / API Host:"),
                        "http://127.0.0.1:\(service.activePort)",
                        tr(es: "3. API Key: 'splash' (no requerida pero obligatoria en algunas UIs)", en: "3. API Key: 'splash' (any string)")
                    ],
                    copyText: "http://127.0.0.1:\(service.activePort)/v1"
                )
                
                IntegrationGuideCard(
                    title: "Python (OpenAI / LangChain)",
                    subtitle: tr(es: "Scripts y automatizaciones", en: "Scripts and pipelines"),
                    icon: "terminal.fill",
                    badge: "Python SDK",
                    color: .cyan,
                    steps: [
                        "from openai import OpenAI",
                        "client = OpenAI(base_url='http://127.0.0.1:\(service.activePort)/v1', api_key='splash')",
                        "resp = client.chat.completions.create(model='\(service.activeModel)', messages=[...])"
                    ],
                    copyText: "from openai import OpenAI\nclient = OpenAI(base_url='http://127.0.0.1:\(service.activePort)/v1', api_key='splash')"
                )
                
                IntegrationGuideCard(
                    title: "cURL / Terminal Directo",
                    subtitle: tr(es: "Peticiones HTTP directas", en: "Direct HTTP requests"),
                    icon: "network",
                    badge: "REST HTTP",
                    color: .indigo,
                    steps: [
                        "curl http://127.0.0.1:\(service.activePort)/v1/chat/completions \\",
                        "  -H 'Content-Type: application/json' \\",
                        "  -d '{\"model\": \"\(service.activeModel)\", \"messages\": [{\"role\": \"user\", \"content\": \"Hola!\"}]}'"
                    ],
                    copyText: "curl http://127.0.0.1:\(service.activePort)/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\": \"\(service.activeModel)\", \"messages\": [{\"role\": \"user\", \"content\": \"Hola\"}]}'"
                )
            }
        }
    }
    
    private func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
    
    private func showCopied(_ message: String) {
        withAnimation {
            copiedMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                if copiedMessage == message {
                    copiedMessage = nil
                }
            }
        }
    }
}

// MARK: - Subcomponents

struct ConnectedAppCard: View {
    let app: ConnectedApp
    let service: SplashService
    let loc: Localization
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 38, height: 38)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryColor(app.category).opacity(0.15))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: app.category.iconName)
                            .font(.system(size: 18))
                            .foregroundColor(categoryColor(app.category))
                    }
                }
            }
            
            // App Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .bold))
                    
                    Text(app.category.localizedName(isSpanish: loc.isSpanish))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(categoryColor(app.category))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(categoryColor(app.category).opacity(0.12))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Status Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(app.status))
                            .frame(width: 6, height: 6)
                        Text(app.status.localizedName(isSpanish: loc.isSpanish))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(statusColor(app.status))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor(app.status).opacity(0.12))
                    .cornerRadius(5)
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 3) {
                        Text("PID:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(app.pid)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    
                    HStack(spacing: 3) {
                        Image(systemName: "network")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(app.connectionCount) \(loc.isSpanish ? (app.connectionCount == 1 ? "conexión" : "conexiones") : (app.connectionCount == 1 ? "socket" : "sockets"))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    if let bundle = app.bundleId, !bundle.isEmpty {
                        Text(bundle)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text("\(loc.isSpanish ? "Visto:" : "Last seen:") \(formattedTime(app.lastSeen))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            // Actions
            HStack(spacing: 6) {
                Button {
                    service.activateApp(app: app)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(loc.isSpanish ? "Traer app al frente" : "Bring app to front")
                
                Button {
                    service.revealAppInFinder(app: app)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(loc.isSpanish ? "Ver en Finder" : "Reveal in Finder")
                
                Button(role: .destructive) {
                    service.terminateApp(app: app)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(loc.isSpanish ? "Terminar proceso cliente" : "Terminate client process")
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(app.status == .active ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private func categoryColor(_ cat: AppCategory) -> Color {
        switch cat {
        case .ide: return .purple
        case .codingAgent: return .orange
        case .chatbot: return .green
        case .terminal: return .blue
        case .customScript: return .cyan
        }
    }
    
    private func statusColor(_ st: AppConnectionStatus) -> Color {
        switch st {
        case .active: return .green
        case .idle: return .blue
        case .recent: return .secondary
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct StatBadgeCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct IntegrationGuideCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let badge: String
    let color: Color
    let steps: [String]
    let copyText: String
    @State private var isCopied: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(badge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .cornerRadius(4)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 3) {
                ForEach(steps, id: \.self) { step in
                    if step.hasPrefix("http") || step.hasPrefix("export") || step.hasPrefix("curl") || step.hasPrefix("from") || step.hasPrefix("client") || step.hasPrefix("splash") {
                        Text(step)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .padding(.vertical, 1)
                    } else {
                        Text(step)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(copyText, forType: .string)
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isCopied = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    Text(isCopied ? "¡Copiado!" : "Copiar Configuración")
                }
                .font(.system(size: 10, weight: .medium))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
