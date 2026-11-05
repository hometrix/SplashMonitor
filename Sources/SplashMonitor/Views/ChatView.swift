import SwiftUI

// MARK: - Native Chat View

public struct ChatView: View {
    @ObservedObject var service: SplashService
    @ObservedObject private var chatService = ChatService.shared
    @ObservedObject private var loc = Localization.shared
    @ObservedObject private var zoomManager = TextZoomManager.shared
    
    @State private var inputText: String = ""
    @State private var showingSettingsSheet: Bool = false
    @State private var showingSessionList: Bool = true
    @State private var editingSessionId: UUID?
    @State private var editingTitleText: String = ""
    @State private var exportSuccessToast: Bool = false
    @State private var pendingAttachments: [ChatAttachment] = []
    
    public init(service: SplashService) {
        self.service = service
    }
    
    public var body: some View {
        HSplitView {
            // Panel Lateral de Historial de Sesiones
            if showingSessionList {
                sessionListSidebar
                    .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)
            }
            
            // Área Principal de Conversación
            VStack(spacing: 0) {
                chatHeader
                
                Divider()
                
                // Mensajes
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if let session = chatService.currentSession {
                                if session.messages.isEmpty {
                                    emptyConversationState
                                        .padding(.top, 60)
                                } else {
                                    ForEach(session.messages) { message in
                                        MessageBubbleView(message: message)
                                            .id(message.id)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: chatService.currentSession?.messages.last?.content) { _ in
                        if let lastId = chatService.currentSession?.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // Barra inferior de entrada y controles
                inputControlsBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingSettingsSheet) {
            chatSettingsModal
        }
    }
    
    // MARK: - Chat Header
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    showingSessionList.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(loc.isSpanish ? "Alternar lista de conversaciones" : "Toggle chat sidebar")
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(chatService.currentSession?.title ?? (loc.isSpanish ? "Chat con Modelo" : "Model Chat"))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    
                    if chatService.isGenerating {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text("\(String(format: "%.1f", chatService.currentTokensPerSecond)) tok/s")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(service.isRunning ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    
                    // Selector y cambiador rápido de modelos
                    Menu {
                        let models = service.installedModels.map { $0.repoId }
                        let currentModel = service.activeModel.isEmpty ? service.selectedModelForLaunch : service.activeModel
                        
                        Text(loc.isSpanish ? "Modelos Locales Disponibles:" : "Available Local Models:")
                        Divider()
                        
                        ForEach(models, id: \.self) { modelId in
                            Button {
                                if modelId != currentModel {
                                    service.switchModel(to: modelId)
                                }
                            } label: {
                                HStack {
                                    Text(modelId)
                                    if modelId == currentModel {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            let activeName = service.activeModel.isEmpty ? service.selectedModelForLaunch : service.activeModel
                            Text(service.isRunning ? "\(activeName) (:\(service.activePort))" : (loc.isSpanish ? "\(activeName) (Detenido)" : "\(activeName) (Stopped)"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .help(loc.isSpanish ? "Cambiar de modelo en caliente" : "Switch model on the fly")
                }
            }
            
            Spacer()
            
            // Selector de Zoom A- / A+
            HStack(spacing: 2) {
                Button {
                    zoomManager.zoomOut()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(loc.isSpanish ? "Reducir tamaño de letra (⌘-)" : "Zoom Out (⌘-)")
                
                Text(zoomManager.formattedPercentage)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 36)
                    .onTapGesture {
                        zoomManager.resetZoom()
                    }
                    .help(loc.isSpanish ? "Clic para restablecer al 100%" : "Click to reset to 100%")
                
                Button {
                    zoomManager.zoomIn()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(loc.isSpanish ? "Aumentar tamaño de letra (⌘+)" : "Zoom In (⌘+)")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            // Botón Exportar a Markdown
            Button {
                exportConversation()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
                    .foregroundColor(exportSuccessToast ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(loc.isSpanish ? "Exportar conversación a Markdown (.md)" : "Export conversation to Markdown (.md)")
            .disabled(chatService.currentSession?.messages.isEmpty ?? true)
            
            // Botón Limpiar Conversación
            Button {
                chatService.clearCurrentSession()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(loc.isSpanish ? "Limpiar mensajes de esta conversación" : "Clear conversation messages")
            .disabled(chatService.currentSession?.messages.isEmpty ?? true)
            
            // Botón Ajustes de Inferencia
            Button {
                showingSettingsSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(loc.isSpanish ? "Ajustes de generación (Temperatura, tokens)" : "Generation parameters")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Sidebar de Sesiones
    
    private var sessionListSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.isSpanish ? "Conversaciones" : "Conversations")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    chatService.createNewSession(modelId: service.activeModel)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help(loc.isSpanish ? "Nueva conversación" : "New conversation")
            }
            .padding(12)
            
            Divider()
            
            List {
                ForEach(chatService.sessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            if editingSessionId == session.id {
                                TextField("", text: $editingTitleText, onCommit: {
                                    chatService.renameSession(id: session.id, newTitle: editingTitleText)
                                    editingSessionId = nil
                                })
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                            } else {
                                Text(session.title)
                                    .font(.system(size: 12, weight: session.id == chatService.currentSessionId ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            Text("\(session.messages.count) \(loc.isSpanish ? "mensajes" : "messages")")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if session.id == chatService.currentSessionId {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editingSessionId = session.id
                        editingTitleText = session.title
                    }
                    .onTapGesture(count: 1) {
                        if editingSessionId == nil {
                            chatService.selectSession(id: session.id)
                        }
                    }
                    .contextMenu {
                        Button(loc.isSpanish ? "Renombrar" : "Rename") {
                            editingSessionId = session.id
                            editingTitleText = session.title
                        }
                        Divider()
                        Button(loc.isSpanish ? "Eliminar" : "Delete", role: .destructive) {
                            chatService.deleteSession(id: session.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Estado Vacío
    
    private var emptyConversationState: some View {
        VStack(spacing: 12) {
            AppIconView(size: 48)
            
            Text(loc.isSpanish ? "¡Listo para chatear y programar!" : "Ready to chat and code!")
                .font(.system(size: 15, weight: .semibold))
            
            Text(loc.isSpanish
                 ? "Escribe cualquier pregunta, pide código o inicia una sesión de depuración con tu modelo local."
                 : "Ask any question, request code, or start a debugging session with your local model.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if !service.isRunning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(loc.isSpanish ? "Inicia el servidor Splash para comenzar a recibir respuestas." : "Start the Splash server to begin chatting.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Barra de Entrada
    
    private func handleSendMessage() {
        guard (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty),
              service.isRunning, !chatService.isGenerating else { return }
        let text = inputText
        let attachments = pendingAttachments
        inputText = ""
        pendingAttachments = []
        
        chatService.sendMessage(
            text,
            attachments: attachments,
            port: service.activePort,
            model: service.activeModel.isEmpty ? service.selectedModelForLaunch : service.activeModel,
            supportsVision: !service.languageOnly
        )
    }
    
    private func selectFilesToAttach() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedContentTypes = [.text, .plainText, .sourceCode, .image, .json]
        
        openPanel.begin { result in
            if result == .OK {
                for url in openPanel.urls {
                    let name = url.lastPathComponent
                    let ext = url.pathExtension.lowercased()
                    let isImg = ["png", "jpg", "jpeg", "webp", "gif"].contains(ext)
                    
                    if isImg {
                        if let data = try? Data(contentsOf: url) {
                            let b64 = data.base64EncodedString()
                            let mime = ext == "png" ? "image/png" : "image/jpeg"
                            let att = ChatAttachment(
                                name: name,
                                sizeBytes: Int64(data.count),
                                isImage: true,
                                mimeType: mime,
                                base64Data: b64
                            )
                            pendingAttachments.append(att)
                        }
                    } else {
                        if let text = try? String(contentsOf: url, encoding: .utf8) {
                            let att = ChatAttachment(
                                name: name,
                                sizeBytes: Int64(text.utf8.count),
                                isImage: false,
                                mimeType: "text/plain",
                                textContent: text
                            )
                            pendingAttachments.append(att)
                        }
                    }
                }
            }
        }
    }
    
    private func exportConversation() {
        let md = chatService.exportCurrentSessionToMarkdown()
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "\(chatService.currentSession?.title ?? "conversation").md"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                try? md.write(to: url, atomically: true, encoding: .utf8)
                exportSuccessToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    exportSuccessToast = false
                }
            }
        }
    }
    
    private var inputControlsBar: some View {
        VStack(spacing: 6) {
            // Previsualización de archivos adjuntos pendientes
            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(pendingAttachments) { att in
                            HStack(spacing: 4) {
                                Image(systemName: att.isImage ? "photo.fill" : "doc.text.fill")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                Text(att.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Button {
                                    pendingAttachments.removeAll(where: { $0.id == att.id })
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Caja de Entrada Flotante Estilo Compacto
            HStack(alignment: .center, spacing: 8) {
                // Botón Adjuntar Archivo 📎
                Button {
                    selectFilesToAttach()
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(loc.isSpanish ? "Adjuntar código, texto o imágenes para análisis" : "Attach code, text or images for analysis")
                
                // Campo de entrada nativo (Enter envía, Shift+Enter salto de línea, altura compacta)
                let baseFontSize = NSFont.preferredFont(forTextStyle: .body).pointSize * zoomManager.zoomScale
                MacChatInputField(
                    text: $inputText,
                    font: .systemFont(ofSize: baseFontSize),
                    onCommit: {
                        handleSendMessage()
                    }
                )
                .frame(height: 34)
                
                if chatService.isGenerating {
                    Button {
                        chatService.cancelGeneration()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help(loc.isSpanish ? "Detener generación" : "Stop generation")
                } else {
                    Button {
                        handleSendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachments.isEmpty) || !service.isRunning ? .secondary.opacity(0.3) : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachments.isEmpty) || !service.isRunning)
                    .help(loc.isSpanish ? "Enviar mensaje (Enter)" : "Send message (Enter)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            // Sub-barra informativa compacta con selector de modelo en la esquina inferior
            HStack(spacing: 8) {
                // Selector rápido de modelo abajo (Hot-Swap)
                Menu {
                    let models = service.installedModels.map { $0.repoId }
                    let currentModel = service.activeModel.isEmpty ? service.selectedModelForLaunch : service.activeModel
                    Text(loc.isSpanish ? "Modelos Locales Disponibles:" : "Available Local Models:")
                    Divider()
                    ForEach(models, id: \.self) { modelId in
                        Button {
                            if modelId != currentModel {
                                service.switchModel(to: modelId)
                            }
                        } label: {
                            HStack {
                                Text(modelId)
                                if modelId == currentModel {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(service.isRunning ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        let active = (service.activeModel.isEmpty ? service.selectedModelForLaunch : service.activeModel)
                            .components(separatedBy: "/").last ?? ""
                        Text(active.isEmpty ? (loc.isSpanish ? "Seleccionar Modelo" : "Select Model") : active)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 7))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
                .help(loc.isSpanish ? "Cambiar de modelo activo (Hot-Swap)" : "Switch active model (Hot-Swap)")
                
                Text(loc.isSpanish ? "Enter para enviar · Shift + Enter salto" : "Enter to send · Shift + Enter newline")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Temp: \(String(format: "%.1f", chatService.parameters.temperature)) · Max: \(chatService.parameters.maxTokens) tok")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Modal de Parámetros
    
    private var chatSettingsModal: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(loc.isSpanish ? "Parámetros de Inferencia" : "Inference Parameters")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(loc.isSpanish ? "Listo" : "Done") {
                    showingSettingsSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            Divider()
            
            // Temperatura
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(loc.isSpanish ? "Temperatura:" : "Temperature:")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.2f", chatService.parameters.temperature))
                        .font(.system(size: 11, design: .monospaced))
                }
                Slider(value: $chatService.parameters.temperature, in: 0.0...1.5, step: 0.05)
            }
            
            // Max Tokens
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(loc.isSpanish ? "Límite de Tokens (Salida):" : "Max Output Tokens:")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(chatService.parameters.maxTokens)")
                        .font(.system(size: 11, design: .monospaced))
                }
                Slider(value: Binding(
                    get: { Double(chatService.parameters.maxTokens) },
                    set: { chatService.parameters.maxTokens = Int($0) }
                ), in: 256...8192, step: 256)
            }
            
            // System Prompt
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.isSpanish ? "Instrucción del Sistema (System Prompt):" : "System Prompt:")
                    .font(.system(size: 11, weight: .semibold))
                TextEditor(text: $chatService.parameters.systemPrompt)
                    .font(.system(size: 11))
                    .frame(height: 70)
                    .padding(4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 400, height: 360)
    }
}

