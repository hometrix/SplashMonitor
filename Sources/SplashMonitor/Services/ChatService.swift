import Foundation
import Combine

@MainActor
public final class ChatService: ObservableObject {
    public static let shared = ChatService()
    
    // Sesión activa y lista de sesiones
    @Published public var sessions: [ChatSession] = []
    @Published public var currentSessionId: UUID?
    @Published public var parameters = ChatParameters()
    
    // Estado de streaming en vivo
    @Published public var isGenerating: Bool = false
    @Published public var streamingError: String?
    @Published public var currentTokensPerSecond: Double = 0.0
    
    private var activeTask: Task<Void, Never>?
    private let storageDirectory: URL
    
    public var currentSession: ChatSession? {
        guard let id = currentSessionId else { return sessions.first }
        return sessions.first(where: { $0.id == id })
    }
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.storageDirectory = appSupport.appendingPathComponent("SplashMonitor/chats", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        loadSessionsFromDisk()
        
        if sessions.isEmpty {
            createNewSession(modelId: "default")
        } else {
            currentSessionId = sessions.first?.id
        }
    }
    
    // MARK: - Gestión de Sesiones
    
    public func createNewSession(modelId: String, title: String? = nil) {
        let newTitle = title ?? (Localization.shared.isSpanish ? "Nueva Conversación" : "New Chat")
        let session = ChatSession(title: newTitle, modelId: modelId)
        sessions.insert(session, at: 0)
        currentSessionId = session.id
        saveSessionsToDisk()
    }
    
    public func selectSession(id: UUID) {
        currentSessionId = id
    }
    
    public func deleteSession(id: UUID) {
        sessions.removeAll(where: { $0.id == id })
        if currentSessionId == id {
            currentSessionId = sessions.first?.id
        }
        if sessions.isEmpty {
            createNewSession(modelId: "default")
        }
        saveSessionsToDisk()
    }
    
    public func clearCurrentSession() {
        guard let index = sessions.firstIndex(where: { $0.id == currentSessionId }) else { return }
        sessions[index].messages.removeAll()
        sessions[index].updatedAt = Date()
        saveSessionsToDisk()
    }
    
    // MARK: - Streaming SSE (/v1/chat/completions)
    
    public func sendMessage(
        _ text: String,
        port: Int,
        model: String
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }
        
        // Asegurar sesión
        if currentSession == nil {
            createNewSession(modelId: model)
        }
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == currentSessionId }) else { return }
        
        // Actualizar título de la conversación si es el primer mensaje
        if sessions[sessionIndex].messages.isEmpty {
            let autoTitle = trimmed.count > 30 ? String(trimmed.prefix(30)) + "..." : trimmed
            sessions[sessionIndex].title = autoTitle
        }
        
        // Mensaje de usuario
        let userMessage = ChatMessage(role: .user, content: trimmed, isComplete: true)
        sessions[sessionIndex].messages.append(userMessage)
        sessions[sessionIndex].modelId = model
        sessions[sessionIndex].updatedAt = Date()
        
        // Mensaje asistente vacío inicial
        let assistantMessageId = UUID()
        let initialAssistantMessage = ChatMessage(
            id: assistantMessageId,
            role: .assistant,
            content: "",
            isComplete: false
        )
        sessions[sessionIndex].messages.append(initialAssistantMessage)
        
        isGenerating = true
        streamingError = nil
        currentTokensPerSecond = 0.0
        
        let messagesPayload = buildMessagesPayload(for: sessions[sessionIndex])
        
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            await self?.executeStreamingRequest(
                port: port,
                model: model,
                messages: messagesPayload,
                sessionIndex: sessionIndex,
                assistantMessageId: assistantMessageId
            )
        }
    }
    
    public func cancelGeneration() {
        activeTask?.cancel()
        activeTask = nil
        isGenerating = false
        
        if let sessionIndex = sessions.firstIndex(where: { $0.id == currentSessionId }),
           let lastMsg = sessions[sessionIndex].messages.last, !lastMsg.isComplete {
            sessions[sessionIndex].messages[sessions[sessionIndex].messages.count - 1].isComplete = true
        }
        saveSessionsToDisk()
    }
    
    private func buildMessagesPayload(for session: ChatSession) -> [[String: String]] {
        var payload: [[String: String]] = []
        
        // Prompt de sistema
        let sys = parameters.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sys.isEmpty {
            payload.append(["role": "system", "content": sys])
        }
        
        // Historial excluyendo el último placeholder incompleto del asistente
        for msg in session.messages.dropLast() {
            if !msg.content.isEmpty {
                payload.append(["role": msg.role.rawValue, "content": msg.content])
            }
        }
        
        return payload
    }
    
    private func executeStreamingRequest(
        port: Int,
        model: String,
        messages: [[String: String]],
        sessionIndex: Int,
        assistantMessageId: UUID
    ) async {
        guard let url = URL(string: "http://127.0.0.1:\(port)/v1/chat/completions") else {
            finishWithError("URL de servidor inválida", sessionIndex: sessionIndex)
            return
        }
        
        var bodyDict: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": parameters.temperature,
            "max_tokens": parameters.maxTokens,
            "stream": true
        ]
        if let budget = parameters.thinkingBudget, budget > 0 {
            bodyDict["thinking_token_budget"] = budget
        }
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: bodyDict) else {
            finishWithError("Error al codificar el payload de la petición", sessionIndex: sessionIndex)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = httpBody
        request.timeoutInterval = 120
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var firstTokenTime: CFAbsoluteTime?
        var tokenCount = 0
        var fullText = ""
        var thinkingText = ""
        var isInsideThinkTag = false
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                finishWithError("Respuesta no HTTP del servidor", sessionIndex: sessionIndex)
                return
            }
            
            if httpResponse.statusCode != 200 {
                finishWithError("Error HTTP \(httpResponse.statusCode)", sessionIndex: sessionIndex)
                return
            }
            
            for try await line in bytes.lines {
                if Task.isCancelled { break }
                
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                guard trimmedLine.hasPrefix("data:") else { continue }
                
                let dataPayload = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if dataPayload == "[DONE]" { break }
                
                guard let jsonData = dataPayload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let delta = firstChoice["delta"] as? [String: Any] else {
                    continue
                }
                
                // Extraer delta content o delta reasoning_content
                let deltaContent = delta["content"] as? String ?? ""
                let deltaReasoning = delta["reasoning_content"] as? String ?? ""
                
                if firstTokenTime == nil && (!deltaContent.isEmpty || !deltaReasoning.isEmpty) {
                    firstTokenTime = CFAbsoluteTimeGetCurrent()
                }
                
                if !deltaReasoning.isEmpty {
                    thinkingText += deltaReasoning
                    tokenCount += 1
                }
                
                if !deltaContent.isEmpty {
                    // Detección de tags <think> embebidos
                    if deltaContent.contains("<think>") {
                        isInsideThinkTag = true
                    }
                    
                    if isInsideThinkTag {
                        if deltaContent.contains("</think>") {
                            isInsideThinkTag = false
                            let parts = deltaContent.components(separatedBy: "</think>")
                            thinkingText += parts.first?.replacingOccurrences(of: "<think>", with: "") ?? ""
                            if parts.count > 1 {
                                fullText += parts[1]
                            }
                        } else {
                            thinkingText += deltaContent.replacingOccurrences(of: "<think>", with: "")
                        }
                    } else {
                        fullText += deltaContent
                    }
                    
                    tokenCount += 1
                }
                
                // Calcular métricas dinámicas
                let elapsed = CFAbsoluteTimeGetCurrent() - (firstTokenTime ?? startTime)
                let tokPerSec = elapsed > 0 ? Double(tokenCount) / elapsed : 0.0
                let ttft = firstTokenTime != nil ? (firstTokenTime! - startTime) * 1000.0 : 0.0
                
                self.currentTokensPerSecond = tokPerSec
                
                // Actualizar el mensaje reactivamente en la sesión
                if sessionIndex < self.sessions.count {
                    if let msgIdx = self.sessions[sessionIndex].messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        self.sessions[sessionIndex].messages[msgIdx].content = fullText
                        self.sessions[sessionIndex].messages[msgIdx].thinkingContent = thinkingText.isEmpty ? nil : thinkingText
                        self.sessions[sessionIndex].messages[msgIdx].tokensGenerated = tokenCount
                        self.sessions[sessionIndex].messages[msgIdx].tokensPerSecond = tokPerSec
                        self.sessions[sessionIndex].messages[msgIdx].ttftMs = ttft
                    }
                }
            }
            
            // Marcar como completado
            if sessionIndex < self.sessions.count {
                if let msgIdx = self.sessions[sessionIndex].messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    self.sessions[sessionIndex].messages[msgIdx].isComplete = true
                }
                self.sessions[sessionIndex].updatedAt = Date()
            }
            
        } catch {
            if !Task.isCancelled {
                finishWithError("Fallo en la conexión: \(error.localizedDescription)", sessionIndex: sessionIndex)
            }
        }
        
        self.isGenerating = false
        self.saveSessionsToDisk()
    }
    
    private func finishWithError(_ errorMsg: String, sessionIndex: Int) {
        self.streamingError = errorMsg
        self.isGenerating = false
        if sessionIndex < self.sessions.count,
           let lastIdx = self.sessions[sessionIndex].messages.indices.last {
            self.sessions[sessionIndex].messages[lastIdx].isComplete = true
            if self.sessions[sessionIndex].messages[lastIdx].content.isEmpty {
                self.sessions[sessionIndex].messages[lastIdx].content = "⚠️ [Error] \(errorMsg)"
            }
        }
        self.saveSessionsToDisk()
    }
    
    // MARK: - Persistencia en Disco
    
    private var sessionsFileURL: URL {
        storageDirectory.appendingPathComponent("sessions.json")
    }
    
    private func saveSessionsToDisk() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsFileURL, options: .atomic)
        } catch {
            print("⚠️ [ChatService] Error al guardar sesiones: \(error)")
        }
    }
    
    private func loadSessionsFromDisk() {
        guard FileManager.default.fileExists(atPath: sessionsFileURL.path),
              let data = try? Data(contentsOf: sessionsFileURL),
              let loaded = try? JSONDecoder().decode([ChatSession].self, from: data) else {
            return
        }
        self.sessions = loaded
    }
}

