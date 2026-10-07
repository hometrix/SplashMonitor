import XCTest
@testable import SplashMonitor

final class AgentLaunchTests: XCTestCase {
    
    func testSupportedAgentsIncludesClaudeCowork() {
        XCTAssertTrue(SplashService.supportedAgents.contains("claude-cowork"), "supportedAgents debe incluir 'claude-cowork'")
        XCTAssertTrue(SplashService.supportedAgents.contains("claude"))
        XCTAssertTrue(SplashService.supportedAgents.contains("opencode"))
        XCTAssertTrue(SplashService.supportedAgents.contains("codex"))
        XCTAssertTrue(SplashService.supportedAgents.contains("hermes"))
        XCTAssertTrue(SplashService.supportedAgents.contains("chatgpt"), "supportedAgents debe incluir 'chatgpt'")
    }
    
    @MainActor
    func testAgentInstallURLForClaudeCowork() {
        let service = SplashService()
        let url = service.agentInstallURL(agent: "claude-cowork")
        XCTAssertEqual(url.absoluteString, "https://claude.ai/download")
    }
    
    @MainActor
    func testAgentInstallURLForChatGPT() {
        let service = SplashService()
        let url = service.agentInstallURL(agent: "chatgpt")
        XCTAssertEqual(url.absoluteString, "https://openai.com/chatgpt/download/")
    }
    
    @MainActor
    func testIsAgentInstalledDoesNotCrashForClaudeCowork() {
        let service = SplashService()
        // No debe lanzar excepciones ni provocar cuelgues
        _ = service.isAgentInstalled(agent: "claude-cowork")
    }
    
    @MainActor
    func testIsAgentInstalledDoesNotCrashForChatGPT() {
        let service = SplashService()
        _ = service.isAgentInstalled(agent: "chatgpt")
    }
}
