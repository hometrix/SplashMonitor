import Foundation
import AppKit

// MARK: - App Category
public enum AppCategory: String, Codable, CaseIterable {
    case ide = "IDE / Editor"
    case codingAgent = "Agente de Código"
    case chatbot = "Chatbot / WebUI"
    case terminal = "Terminal / CLI"
    case customScript = "Script / Proceso"
    
    public var iconName: String {
        switch self {
        case .ide: return "chevron.left.forwardslash.chevron.right"
        case .codingAgent: return "brain.head.profile"
        case .chatbot: return "bubble.left.and.bubble.right.fill"
        case .terminal: return "terminal.fill"
        case .customScript: return "gearshape.2.fill"
        }
    }
    
    public func localizedName(isSpanish: Bool) -> String {
        switch self {
        case .ide: return isSpanish ? "IDE / Editor de Código" : "IDE / Code Editor"
        case .codingAgent: return isSpanish ? "Agente de Código Autónomo" : "Autonomous Coding Agent"
        case .chatbot: return isSpanish ? "Chatbot / Interfaz Gráfica" : "Chatbot / Graphical UI"
        case .terminal: return isSpanish ? "Terminal / Consola CLI" : "Terminal / CLI Console"
        case .customScript: return isSpanish ? "Script / Proceso Personalizado" : "Script / Custom Process"
        }
    }
}

// MARK: - Connection Status
public enum AppConnectionStatus: String, Codable {
    case active = "active"       // Currently has active open sockets or recent stream
    case idle = "idle"           // Connected but waiting
    case recent = "recent"       // Was connected recently in current session
    
    public func localizedName(isSpanish: Bool) -> String {
        switch self {
        case .active: return isSpanish ? "Transmitiendo" : "Streaming"
        case .idle: return isSpanish ? "Conectado (En espera)" : "Connected (Idle)"
        case .recent: return isSpanish ? "Desconectado reciente" : "Recently Disconnected"
        }
    }
}

// MARK: - Connected App Model
public struct ConnectedApp: Identifiable, Hashable {
    public var id: String { "\(pid)-\(name)" }
    public let pid: Int32
    public let name: String
    public let bundleId: String?
    public let executablePath: String?
    public let category: AppCategory
    public let icon: NSImage?
    public var connectionCount: Int
    public var status: AppConnectionStatus
    public var firstConnected: Date
    public var lastSeen: Date
    public var remoteAddress: String
    
    public init(
        pid: Int32,
        name: String,
        bundleId: String? = nil,
        executablePath: String? = nil,
        category: AppCategory = .customScript,
        icon: NSImage? = nil,
        connectionCount: Int = 1,
        status: AppConnectionStatus = .active,
        firstConnected: Date = Date(),
        lastSeen: Date = Date(),
        remoteAddress: String = "127.0.0.1"
    ) {
        self.pid = pid
        self.name = name
        self.bundleId = bundleId
        self.executablePath = executablePath
        self.category = category
        self.icon = icon
        self.connectionCount = connectionCount
        self.status = status
        self.firstConnected = firstConnected
        self.lastSeen = lastSeen
        self.remoteAddress = remoteAddress
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(name)
    }
    
    public static func == (lhs: ConnectedApp, rhs: ConnectedApp) -> Bool {
        return lhs.pid == rhs.pid && lhs.name == rhs.name
    }
}
