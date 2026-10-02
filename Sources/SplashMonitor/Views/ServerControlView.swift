import SwiftUI
import AppKit

public struct ServerControlView: View {
    @ObservedObject var service: SplashService
    @ObservedObject var loc = Localization.shared
    @State private var portString: String = "8000"
    @State private var isCustomModel: Bool = false
    @State private var customModelText: String = ""
    @State private var copiedMessage: String? = nil
    
    // Agent alert state
    @State private var showingAgentOfflineAlert: Bool = false
    @State private var showingAgentNotInstalledAlert: Bool = false
    @State private var showingLogsSheet: Bool = false
    @State private var pendingAgentName: String = ""
    @State private var pendingAgentCommand: String = ""
    
    public init(service: SplashService) {
        self.service = service
    }
    
    /// Error de validación del identificador personalizado (P-03).
    /// `nil` = válido o campo no utilizado. Misma regla que aplica el servicio.
    private var customModelError: String? {
        guard isCustomModel else { return nil }
        let value = customModelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return tr(es: "Escribe un identificador owner/repo.", en: "Enter an owner/repo identifier.")
        }
        return ModelIDValidator.rejectionReason(value)
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 0. Dependency missing alert if needed
            if !service.isSplashInstalled {
                dependencyWarningBanner
            }
            
            // 1. Current Status Banner
            statusBannerView
            
            // 2. Model Selection & Launch Section (FEATURED)
            modelSelectionAndLaunchView
            
            // 3. Coding Agents Launcher
            agentsLauncherView
            
            // 4. API Endpoints & Copy Helpers
            apiEndpointsView
        }
        .onAppear {
            portString = "\(service.activePort)"
        }
        .onChange(of: service.activePort) { newPort in
            portString = "\(newPort)"
        }
        .alert(
            tr(es: "Servidor Splash Apagado", en: "Splash Server Offline"),
            isPresented: $showingAgentOfflineAlert
        ) {
            Button(tr(es: "Arrancar Servidor Primero", en: "Start Server First")) {
                let targetModel = isCustomModel ? customModelText.trimmingCharacters(in: .whitespacesAndNewlines) : service.selectedModelForLaunch
                let targetPort = Int(portString) ?? service.activePort
                service.startServer(model: targetModel, port: targetPort)
            }
            Button(tr(es: "Cancelar", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(tr(
                es: "Para conectar \(pendingAgentName), el servidor de inferencia local Splash debe estar activo. Arranca el servidor primero.",
                en: "To connect \(pendingAgentName), the local Splash inference server must be running. Start the server first."
            ))
        }
        .alert(
            tr(es: "\(pendingAgentName) No Encontrado", en: "\(pendingAgentName) Not Found"),
            isPresented: $showingAgentNotInstalledAlert
        ) {
            Button(tr(es: "Abrir Guía de Instalación", en: "Open Installation Guide")) {
                let url = service.agentInstallURL(agent: pendingAgentCommand)
                NSWorkspace.shared.open(url)
            }
            Button(tr(es: pendingAgentCommand == "claude-cowork" ? "Abrir Claude de Todos Modos" : "Lanzar en Terminal de Todos Modos",
                      en: pendingAgentCommand == "claude-cowork" ? "Open Claude Anyway" : "Launch in Terminal Anyway")) {
                service.launchAgent(agent: pendingAgentCommand)
            }
            Button(tr(es: "Cancelar", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(tr(
                es: pendingAgentCommand == "claude-cowork" ? "No se detectó la aplicación Claude for Mac en tu sistema (/Applications/Claude.app). Puedes descargarla desde la web oficial de Claude." : "No se detectó el comando '\(pendingAgentCommand)' en tu sistema. Puedes instalarlo siguiendo la guía oficial.",
                en: pendingAgentCommand == "claude-cowork" ? "Claude for Mac application was not detected on your system (/Applications/Claude.app). You can download it from the official Claude website." : "Command '\(pendingAgentCommand)' was not detected on your system. You can install it following the official guide."
            ))
        }
        .alert(
            item: $service.portConflict
        ) { conflict in
            Alert(
                title: Text(tr(es: "⚠️ Puerto \(conflict.port) en Uso", en: "⚠️ Port \(conflict.port) In Use")),
                message: Text(tr(
                    es: "El proceso '\(conflict.processName)' (PID \(conflict.pid)) está utilizando el puerto \(conflict.port).\n\n¿Deseas cambiar al puerto libre sugerido \(conflict.suggestedPort) o liberar el puerto \(conflict.port)?",
                    en: "Process '\(conflict.processName)' (PID \(conflict.pid)) is currently using port \(conflict.port).\n\nWould you like to switch to suggested free port \(conflict.suggestedPort) or free port \(conflict.port)?"
                )),
                primaryButton: .default(Text(tr(es: "Usar puerto \(conflict.suggestedPort)", en: "Use port \(conflict.suggestedPort)"))) {
                    portString = "\(conflict.suggestedPort)"
                    service.useSuggestedPort(conflict.suggestedPort)
                },
                secondaryButton: .destructive(Text(tr(es: "Liberar puerto \(conflict.port)", en: "Free port \(conflict.port)"))) {
                    service.resolvePortConflict(killProcess: true)
                }
            )
        }
        .alert(
            tr(es: "Configurar tu shell", en: "Configure your shell"),
            isPresented: Binding(
                get: { service.pendingShellConfigPort != nil },
                set: { presented in
                    if !presented { service.pendingShellConfigPort = nil }
                }
            )
        ) {
            Button(tr(es: "Permitir y configurar", en: "Allow and configure")) {
                service.resolveShellConfigPrompt(allow: true)
            }
            Button(tr(es: "No, gracias", en: "No thanks"), role: .cancel) {
                service.resolveShellConfigPrompt(allow: false)
            }
        } message: {
            Text(tr(
                es: "Splash Monitor puede añadir una línea a tu ~/.zshrc para que los agentes lanzados desde una terminal hereden el puerto \(service.pendingShellConfigPort ?? service.activePort). Escribirá en tu configuración personal; podrás deshacerlo desde Configuración. El fichero ~/.splash_monitor_env se escribe siempre.",
                en: "Splash Monitor can add a line to your ~/.zshrc so agents launched from a terminal inherit port \(service.pendingShellConfigPort ?? service.activePort). This writes to your personal configuration; you can undo it from Settings. The ~/.splash_monitor_env file is always written."
            ))
        }
        .sheet(isPresented: $showingLogsSheet) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(tr(es: "Registros del Servidor Splash", en: "Splash Server Logs"), systemImage: "terminal.fill")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button(tr(es: "Cerrar", en: "Close")) {
                        showingLogsSheet = false
                    }
                    .buttonStyle(.bordered)
                }
                
                let logs = service.readRecentServerLogs(lines: 100)
                ScrollView {
                    Text(logs.isEmpty ? tr(es: "No hay registros disponibles aún.", en: "No logs available yet.") : logs)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                }
                .frame(minHeight: 280, maxHeight: 420)
            }
            .padding(16)
            .frame(width: 580)
        }
    }
    
    // MARK: - 0. Dependency Warning Banner
    private var dependencyWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(tr(es: "Splash CLI no está instalado en este Mac", en: "Splash CLI is not installed on this Mac"))
                    .font(.system(size: 11, weight: .bold))
                Text("brew install incoai/tap/splash")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                service.installSplashDependency()
            } label: {
                Text(tr(es: "Instalar Ahora", en: "Install Now"))
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
    }
    
    // MARK: - 1. Status Banner
    private var statusBannerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(service.isRunning ? Color.green : Color.red)
                    .frame(width: 9, height: 9)
                
                Text(service.isRunning ? tr(es: "Servidor Splash Activo", en: "Splash Server Active") : tr(es: "Servidor Splash Detenido", en: "Splash Server Stopped"))
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                if let pid = service.activePid {
                    Text("PID: \(pid)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr(es: "Modelo en Ejecución", en: "Running Model"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(service.isRunning ? service.activeModel : tr(es: "Ninguno (servidor apagado)", en: "None (server stopped)"))
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(tr(es: "Puerto Activo", en: "Active Port"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(service.activePort)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
            
            if service.isRunning {
                HStack(spacing: 8) {
                    Button(role: .destructive) {
                        service.stopServer()
                    } label: {
                        Label(tr(es: "Detener Servidor", en: "Stop Server"), systemImage: "stop.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button {
                        service.switchModel(to: service.activeModel)
                    } label: {
                        Label(tr(es: "Reiniciar", en: "Restart"), systemImage: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button {
                        if let url = URL(string: "http://127.0.0.1:\(service.activePort)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("WebUI", systemImage: "safari")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - 2. Model Selection & Launch Section
    private var modelSelectionAndLaunchView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(service.isRunning ? tr(es: "Cambiar Modelo o Reiniciar", en: "Switch Model or Restart") : tr(es: "Arrancar Servidor con Modelo", en: "Start Server with Model"))
                    .font(.system(size: 11, weight: .semibold))
                
                Spacer()
                
                Toggle(tr(es: "Personalizado", en: "Custom"), isOn: $isCustomModel)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 10))
            }
            
            if isCustomModel {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr(es: "Identificador de Hugging Face (owner/repo):", en: "Hugging Face Identifier (owner/repo):"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    TextField(tr(es: "ej. incoai/Qwen3.8-27B-Splash", en: "e.g. incoai/Qwen3.8-27B-Splash"), text: $customModelText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                    
                    // P-03: aviso inmediato; el botón de arranque queda bloqueado mientras
                    // el identificador no sea válido, así el usuario no descubre el error
                    // después de intentar arrancar el motor.
                    if let error = customModelError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text(error)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.orange)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr(es: "Selecciona el modelo para la inferencia:", en: "Select model for inference:"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if service.installedModels.isEmpty {
                        HStack {
                            Text(tr(es: "No hay modelos instalados.", en: "No models installed."))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(tr(es: "Usa la pestaña 'Modelos' para descargar", en: "Use 'Models' tab to download"))
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                        .padding(6)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                        .cornerRadius(6)
                    } else {
                        Picker("", selection: $service.selectedModelForLaunch) {
                            ForEach(service.installedModels) { model in
                                HStack {
                                    Text(model.shortName)
                                    Text("(\(model.formattedSize))")
                                        .foregroundColor(.secondary)
                                }
                                .tag(model.repoId)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }
            }
            
            // Port input configuration
            HStack(spacing: 8) {
                Text(tr(es: "Puerto:", en: "Port:"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                TextField("8000", text: $portString)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 65)
                
                Button {
                    let suggested = service.findSuggestedFreePort()
                    portString = "\(suggested)"
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                        Text(tr(es: "Sugerir libre", en: "Suggest free"))
                    }
                    .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
                .help(tr(es: "Escanear y sugerir automáticamente un puerto libre en tu sistema", en: "Scan and automatically suggest a free port on your system"))
                
                if let p = Int(portString) {
                    if service.isPortListening(port: p) && (!service.isRunning || p != service.activePort) {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text(tr(es: "En uso", en: "In use"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text(tr(es: "Libre", en: "Free"))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                let targetModel = isCustomModel ? customModelText.trimmingCharacters(in: .whitespacesAndNewlines) : service.selectedModelForLaunch
                let targetPort = Int(portString) ?? service.activePort
                let isSameAsActive = (targetModel == service.activeModel && service.isRunning)
                
                if service.isStartingServer {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(tr(es: "Iniciando Servidor...", en: "Starting Server..."))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(6)
                } else if service.isRunning {
                    if isSameAsActive {
                        Button {
                            service.switchModel(to: targetModel)
                        } label: {
                            Label(tr(es: "Reiniciar", en: "Restart"), systemImage: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    } else {
                        Button {
                            service.startServer(model: targetModel, port: targetPort)
                        } label: {
                            Label(tr(es: "Cambiar Modelo", en: "Switch Model"), systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.regular)
                        .disabled(targetModel.isEmpty || customModelError != nil)
                    }
                } else {
                    Button {
                        service.startServer(model: targetModel, port: targetPort)
                    } label: {
                        Label(tr(es: "Arrancar Servidor", en: "Start Server"), systemImage: "play.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.regular)
                    .disabled(targetModel.isEmpty)
                }
            }
            
            // Background / Silent mode & logs options
            HStack {
                Toggle(isOn: $service.runInBackground) {
                    HStack(spacing: 4) {
                        Image(systemName: service.runInBackground ? "speaker.slash.fill" : "terminal")
                            .font(.system(size: 10))
                        Text(tr(es: "Ejecutar en silencio (segundo plano)", en: "Run silently in background"))
                            .font(.system(size: 11))
                    }
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Button {
                    showingLogsSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text(tr(es: "Ver Registros", en: "View Logs"))
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .onChange(of: portString) { newValue in
            guard let newPort = Int(newValue), newPort > 1024, newPort <= 65535 else { return }
            // If server is running on a different port, auto-restart on new port
            if service.isRunning && newPort != service.activePort {
                service.startServer(model: service.activeModel, port: newPort)
            }
        }
    }
    
    // MARK: - 3. Coding Agents Launcher
    private var agentsLauncherView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tr(es: "Conectar Agentes de Código", en: "Connect Coding Agents"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !service.isRunning {
                    HStack(spacing: 3) {
                        Image(systemName: "info.circle")
                        Text(tr(es: "Servidor inactivo", en: "Server offline"))
                    }
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                }
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                AgentButton(
                    name: "Claude Code",
                    icon: "brain.head.profile",
                    command: "claude",
                    isInstalled: service.isAgentInstalled(agent: "claude"),
                    isServerRunning: service.isRunning
                ) {
                    handleAgentLaunch(name: "Claude Code", command: "claude")
                }
                
                AgentButton(
                    name: "Claude Cowork",
                    icon: "person.2.badge.gearshape",
                    command: "claude-cowork",
                    subtitle: "Claude for Mac",
                    isInstalled: service.isAgentInstalled(agent: "claude-cowork"),
                    isServerRunning: service.isRunning
                ) {
                    handleAgentLaunch(name: "Claude Cowork", command: "claude-cowork")
                }
                
                AgentButton(
                    name: "OpenCode",
                    icon: "chevron.left.forwardslash.chevron.right",
                    command: "opencode",
                    isInstalled: service.isAgentInstalled(agent: "opencode"),
                    isServerRunning: service.isRunning
                ) {
                    handleAgentLaunch(name: "OpenCode", command: "opencode")
                }
                
                AgentButton(
                    name: "Codex",
                    icon: "terminal",
                    command: "codex",
                    isInstalled: service.isAgentInstalled(agent: "codex"),
                    isServerRunning: service.isRunning
                ) {
                    handleAgentLaunch(name: "Codex", command: "codex")
                }
                
                AgentButton(
                    name: "Hermes",
                    icon: "bolt.horizontal",
                    command: "hermes",
                    isInstalled: service.isAgentInstalled(agent: "hermes"),
                    isServerRunning: service.isRunning
                ) {
                    handleAgentLaunch(name: "Hermes", command: "hermes")
                }
            }
        }
    }
    
    private func handleAgentLaunch(name: String, command: String) {
        pendingAgentName = name
        pendingAgentCommand = command
        
        guard service.isRunning else {
            showingAgentOfflineAlert = true
            return
        }
        
        if !service.isAgentInstalled(agent: command) {
            showingAgentNotInstalledAlert = true
            return
        }
        
        service.launchAgent(agent: command)
    }
    
    // MARK: - 4. API Endpoints & Copy Helpers
    private var apiEndpointsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tr(es: "Endpoints de Integración", en: "Integration Endpoints"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let msg = copiedMessage {
                    Text(msg)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            
            HStack(spacing: 8) {
                Button {
                    copyToClipboard("http://127.0.0.1:\(service.activePort)/v1")
                    showCopied(tr(es: "¡Copiado OpenAI URL!", en: "OpenAI URL copied!"))
                } label: {
                    Label(tr(es: "Copiar OpenAI URL", en: "Copy OpenAI URL"), systemImage: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button {
                    copyToClipboard("export OPENAI_BASE_URL=http://127.0.0.1:\(service.activePort)/v1\nexport ANTHROPIC_BASE_URL=http://127.0.0.1:\(service.activePort)")
                    showCopied(tr(es: "¡Copiado Env Vars!", en: "Env Vars copied!"))
                } label: {
                    Label(tr(es: "Copiar Env Vars", en: "Copy Env Vars"), systemImage: "terminal")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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

struct AgentButton: View {
    let name: String
    let icon: String
    let command: String
    var subtitle: String? = nil
    let isInstalled: Bool
    let isServerRunning: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(isServerRunning ? .accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(.system(size: 11, weight: .medium))
                        
                        Circle()
                            .fill(isInstalled ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 5, height: 5)
                    }
                    
                    Text(subtitle ?? "splash \(command)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 9))
                    .foregroundColor(isServerRunning ? .secondary : .secondary.opacity(0.4))
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .opacity(isServerRunning ? 1.0 : 0.75)
        }
        .buttonStyle(.plain)
    }
}
