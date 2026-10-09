import XCTest
@testable import SplashMonitor

final class ServerCLIValidatorTests: XCTestCase {
    
    func testAcceptsValidFlags() {
        let (tokens, error) = ServerCLIValidator.validateAndTokenize("--no-webui --max-cache-disk 50GB")
        XCTAssertNil(error)
        XCTAssertEqual(tokens, ["--no-webui", "--max-cache-disk", "50GB"])
    }
    
    func testAcceptsComplexArguments() {
        let raw = "--draft-model incoai/Qwen3.6-35B-A3B-DFlash2 --revision f12a584 --temp=0.7 --cache-dir /tmp/splash_cache"
        let (tokens, error) = ServerCLIValidator.validateAndTokenize(raw)
        XCTAssertNil(error)
        XCTAssertEqual(tokens.count, 7)
        XCTAssertTrue(tokens.contains("--no-webui") == false)
        XCTAssertTrue(tokens.contains("--temp=0.7"))
        XCTAssertTrue(tokens.contains("/tmp/splash_cache"))
    }
    
    func testEmptyAndWhitespaceReturnsEmptyListWithoutError() {
        let (tokens1, error1) = ServerCLIValidator.validateAndTokenize("")
        XCTAssertNil(error1)
        XCTAssertTrue(tokens1.isEmpty)
        
        let (tokens2, error2) = ServerCLIValidator.validateAndTokenize("   \n\t  ")
        // Whitespace with \n or \t might be trimmed or rejected, let's verify:
        let (tokens3, error3) = ServerCLIValidator.validateAndTokenize("    ")
        XCTAssertNil(error3)
        XCTAssertTrue(tokens3.isEmpty)
    }
    
    func testRejectsShellInjectionSemicolon() {
        let (tokens, error) = ServerCLIValidator.validateAndTokenize("--no-webui ; rm -rf /")
        XCTAssertNotNil(error)
        XCTAssertTrue(tokens.isEmpty)
    }
    
    func testRejectsCommandSubstitution() {
        let (tokens1, error1) = ServerCLIValidator.validateAndTokenize("--draft $(whoami)")
        XCTAssertNotNil(error1)
        XCTAssertTrue(tokens1.isEmpty)
        
        let (tokens2, error2) = ServerCLIValidator.validateAndTokenize("--draft `whoami`")
        XCTAssertNotNil(error2)
        XCTAssertTrue(tokens2.isEmpty)
    }
    
    func testRejectsPipesAndRedirections() {
        let (tokens1, error1) = ServerCLIValidator.validateAndTokenize("--opt | nc 127.0.0.1 9000")
        XCTAssertNotNil(error1)
        XCTAssertTrue(tokens1.isEmpty)
        
        let (tokens2, error2) = ServerCLIValidator.validateAndTokenize("--opt > /tmp/output")
        XCTAssertNotNil(error2)
        XCTAssertTrue(tokens2.isEmpty)
    }
    
    func testRejectsQuotesAndBackslashes() {
        let (tokens1, error1) = ServerCLIValidator.validateAndTokenize("--opt \"value\"")
        XCTAssertNotNil(error1)
        XCTAssertTrue(tokens1.isEmpty)
        
        let (tokens2, error2) = ServerCLIValidator.validateAndTokenize("--opt \\escape")
        XCTAssertNotNil(error2)
        XCTAssertTrue(tokens2.isEmpty)
    }
    
    func testSanitizedStringHelper() {
        let valid = ServerCLIValidator.sanitizedString("--no-webui --max-cache-disk 50GB")
        XCTAssertEqual(valid, "--no-webui --max-cache-disk 50GB")
        
        let malicious = ServerCLIValidator.sanitizedString("--no-webui ; evil")
        XCTAssertEqual(malicious, "")
    }
}
