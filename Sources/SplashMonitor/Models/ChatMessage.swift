import Foundation

// MARK: - Modelos de Datos del Chat Nativo

public enum ChatRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public var content: String
    public var thinkingContent: String?
    public let timestamp: Date
    
    // Métricas en vivo del mensaje (telemetría por respuesta)
    public var tokensGenerated: Int?
    public var tokensPerSecond: Double?
    public var ttftMs: Double?
    public var isComplete: Bool
    
    public init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        thinkingContent: String? = nil,
        timestamp: Date = Date(),
        tokensGenerated: Int? = nil,
        tokensPerSecond: Double? = nil,
        ttftMs: Double? = nil,
        isComplete: Bool = true
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinkingContent = thinkingContent
        self.timestamp = timestamp
        self.tokensGenerated = tokensGenerated
        self.tokensPerSecond = tokensPerSecond
        self.ttftMs = ttftMs
        self.isComplete = isComplete
    }
}

public struct ChatSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var updatedAt: Date
    public var modelId: String
    public var messages: [ChatMessage]
    
    public init(
        id: UUID = UUID(),
        title: String = "Nueva Conversación",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        modelId: String,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modelId = modelId
        self.messages = messages
    }
}

public struct ChatParameters: Codable, Equatable, Sendable {
    public var temperature: Double
    public var maxTokens: Int
    public var systemPrompt: String
    public var thinkingBudget: Int?
    
    public init(
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        systemPrompt: String = "Eres un asistente experto en ingeniería de software y programación. Proporciona código limpio, moderno y bien estructurado.",
        thinkingBudget: Int? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.thinkingBudget = thinkingBudget
    }
}

