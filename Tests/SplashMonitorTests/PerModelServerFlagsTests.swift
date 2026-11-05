import XCTest
@testable import SplashMonitor

final class PerModelServerFlagsTests: XCTestCase {

    func testSetAndReadFlagsPerModel() {
        var json = "{}"
        json = PerModelServerFlags.setting("--mmproj /tmp/a.gguf", for: "owner/model-a", in: json)
        json = PerModelServerFlags.setting("--language-only", for: "owner/model-b:Q4_K_M", in: json)
        XCTAssertEqual(PerModelServerFlags.flags(for: "owner/model-a", in: json), "--mmproj /tmp/a.gguf")
        XCTAssertEqual(PerModelServerFlags.flags(for: "owner/model-b:Q4_K_M", in: json), "--language-only")
        XCTAssertEqual(PerModelServerFlags.flags(for: "owner/other", in: json), "")
    }

    func testModelIdIsTrimmed() {
        let json = PerModelServerFlags.setting("--no-webui", for: "  owner/model  ", in: "{}")
        XCTAssertEqual(PerModelServerFlags.flags(for: "owner/model", in: json), "--no-webui")
    }

    func testEmptyFlagsRemoveEntry() {
        var json = PerModelServerFlags.setting("--no-webui", for: "owner/model", in: "{}")
        json = PerModelServerFlags.setting("", for: "owner/model", in: json)
        XCTAssertEqual(json, "{}")
    }
    
    func testWhitespaceIsKeptWhileTyping() {
        let json = PerModelServerFlags.setting("--no-webui ", for: "owner/model", in: "{}")
        XCTAssertEqual(PerModelServerFlags.flags(for: "owner/model", in: json), "--no-webui ")
    }
    
    func testKeysAreCaseInsensitive() {
        let json = PerModelServerFlags.setting("--no-webui", for: "Owner/Model", in: "{}")
        XCTAssertEqual(PerModelServerFlags.flags(for: "owner/model", in: json), "--no-webui")
    }
    
    func testFlashNextAliasSharesFlagsWithLaunchedId() {
        let json = PerModelServerFlags.setting("--no-webui", for: "Qwen/Qwen3.8-Flash-Next", in: "{}")
        XCTAssertEqual(PerModelServerFlags.flags(for: "ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF:Q2_0", in: json), "--no-webui")
    }

    func testCorruptJsonIsTreatedAsEmpty() {
        XCTAssertEqual(PerModelServerFlags.flags(for: "owner/model", in: "not json"), "")
        let json = PerModelServerFlags.setting("--no-webui", for: "owner/model", in: "not json")
        XCTAssertEqual(PerModelServerFlags.flags(for: "owner/model", in: json), "--no-webui")
    }

    func testEmptyModelIdLeavesJsonUnchanged() {
        XCTAssertEqual(PerModelServerFlags.setting("--no-webui", for: " ", in: "{}"), "{}")
    }
}
