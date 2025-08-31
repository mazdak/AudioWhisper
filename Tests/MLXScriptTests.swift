import XCTest

final class MLXScriptTests: XCTestCase {
    func testMaxTokensLimit() throws {
        let scriptURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // drop file name
            .deletingLastPathComponent() // drop Tests directory
            .appendingPathComponent("Sources/mlx_semantic_correct.py")
        let content = try String(contentsOf: scriptURL)
        XCTAssertTrue(content.contains("min(4096"), "Script should cap generation at 4096 tokens")
    }
}
