import XCTest

final class ParakeetDownloadTests: XCTestCase {
    func testParakeetDownloadUsesParakeetMLX() throws {
        let managerURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Services/MLXModelManager.swift")
        let content = try String(contentsOf: managerURL)
        XCTAssertTrue(content.contains("parakeet_mlx"), "Parakeet download should import parakeet_mlx")
        XCTAssertTrue(content.contains("selectedParakeetModel"), "Parakeet repo should use selectedParakeetModel setting")
    }

    func testParakeetModelEnumHasV3() throws {
        let typesURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Models/TranscriptionTypes.swift")
        let content = try String(contentsOf: typesURL)
        XCTAssertTrue(content.contains("parakeet-tdt-0.6b-v3"), "ParakeetModel enum should have v3 multilingual model")
        XCTAssertTrue(content.contains("v3Multilingual"), "ParakeetModel enum should have v3Multilingual case")
    }
}
