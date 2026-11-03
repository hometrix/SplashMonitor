import SwiftUI

// MARK: - Native Chat View

public struct ChatView: View {
    @ObservedObject var service: SplashService
    @ObservedObject private var chatService = ChatService.shared
    @ObservedObject private var loc = Localization.shared
    
    @State private var inputText: String = ""
    @State private var showingSettingsSheet: Bool = false
    @State private var showingSessionList: Bool = true
    
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
                    
                    let activeName = service.activeModel.isEmpty ? service.selectedModelForLaunch : service.activeModel
                    Text(service.isRunning ? "\(activeName) (:\(service.activePort))" : (loc.isSpanish ? "Servidor Detenido" : "Server Stopped"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
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
                            Text(session.title)
                                .font(.system(size: 12, weight: session.id == chatService.currentSessionId ? .semibold : .regular))
                                .lineLimit(1)
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
                    .onTapGesture {
                        chatService.selectSession(id: session.id)
                    }
                    .contextMenu {
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
    
    private var inputControlsBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $inputText)
                    .font(.system(size: 12, design: .default))
                    .frame(minHeight: 36, maxHeight: 100)
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
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
                        let text = inputText
                        inputText = ""
                        chatService.sendMessage(
                            text,
                            port: service.activePort,
                            model: service.activeModel.isEmpty ? service.selectedModelForLaunch : service.activeModel
                        )
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !service.isRunning ? .secondary.opacity(0.4) : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !service.isRunning)
                    .help(loc.isSpanish ? "Enviar mensaje" : "Send message")
                }
            }
            
            HStack {
                Text(loc.isSpanish ? "Pulsa botón Enviar para consultar" : "Press send button to query")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Temp: \(String(format: "%.1f", chatService.parameters.temperature)) · Max: \(chatService.parameters.maxTokens) tok")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
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

