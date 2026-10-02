import XCTest
@testable import SplashMonitor

final class AgentLaunchTests: XCTestCase {
    
    func testSupportedAgentsIncludesClaudeCowork() {
        XCTAssertTrue(SplashService.supportedAgents.contains("claude-cowork"), "supportedAgents debe incluir 'claude-cowork'")
        XCTAssertTrue(SplashService.supportedAgents.contains("claude"))
        XCTAssertTrue(SplashService.supportedAgents.contains("opencode"))
        XCTAssertTrue(SplashService.supportedAgents.contains("codex"))
        XCTAssertTrue(SplashService.supportedAgents.contains("hermes"))
    }
    
    @MainActor
    func testAgentInstallURLForClaudeCowork() {
        let service = SplashService()
        let url = service.agentInstallURL(agent: "claude-cowork")
        XCTAssertEqual(url.absoluteString, "https://claude.ai/download")
    }
    
    @MainActor
    func testIsAgentInstalledDoesNotCrashForClaudeCowork() {
        let service = SplashService()
        // No debe lanzar excepciones ni provocar cuelgues
        _ = service.isAgentInstalled(agent: "claude-cowork")
    }
}
