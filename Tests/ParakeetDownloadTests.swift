import XCTest

final class ParakeetDownloadTests: XCTestCase {
    func testParakeetDownloadUsesParakeetMLX() throws {
        let managerURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MLXModelManager.swift")
        let content = try String(contentsOf: managerURL)
        XCTAssertTrue(content.contains("parakeet_mlx"), "Parakeet download should import parakeet_mlx")
        XCTAssertTrue(content.contains("parakeet-tdt-0.6b-v2"), "Parakeet repo string should be present")
    }
}
