import XCTest
@testable import SplashMonitor

@MainActor
final class ChatServiceTests: XCTestCase {
    
    func testCreateNewSession() {
        let service = ChatService.shared
        let initialCount = service.sessions.count
        
        service.createNewSession(modelId: "test-model", title: "Test Chat")
        
        XCTAssertEqual(service.sessions.count, initialCount + 1)
        XCTAssertEqual(service.currentSession?.title, "Test Chat")
        XCTAssertEqual(service.currentSession?.modelId, "test-model")
    }
    
    func testClearSessionMessages() {
        let service = ChatService.shared
        service.createNewSession(modelId: "test-model", title: "Clearable Chat")
        guard let sessionId = service.currentSessionId else {
            XCTFail("No session id")
            return
        }
        
        if let idx = service.sessions.firstIndex(where: { $0.id == sessionId }) {
            service.sessions[idx].messages.append(ChatMessage(role: .user, content: "Hola"))
            service.sessions[idx].messages.append(ChatMessage(role: .assistant, content: "Hola, en qué puedo ayudarte?"))
        }
        
        XCTAssertEqual(service.currentSession?.messages.count, 2)
        
        service.clearCurrentSession()
        XCTAssertEqual(service.currentSession?.messages.count, 0)
    }
    
    func testDeleteSession() {
        let service = ChatService.shared
        service.createNewSession(modelId: "test-model", title: "Delete Me")
        guard let sessionId = service.currentSessionId else {
            XCTFail("No session id")
            return
        }
        
        service.deleteSession(id: sessionId)
        XCTAssertFalse(service.sessions.contains(where: { $0.id == sessionId }))
    }
}

