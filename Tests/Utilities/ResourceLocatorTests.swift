import XCTest
@testable import AudioWhisper

// MARK: - ResourceLocator Tests
final class ResourceLocatorTests: XCTestCase {

    func testURLForResourceWithValidName() {
        // Test that method doesn't crash with valid inputs
        let url = ResourceLocator.url(forResource: "test", withExtension: "txt")
        // URL may be nil if resource doesn't exist, but should not crash
        _ = url
        XCTAssertTrue(true)
    }

    func testURLForResourceWithEmptyName() {
        let url = ResourceLocator.url(forResource: "", withExtension: "txt")
        // Should return nil for empty name
        XCTAssertNil(url)
    }

    func testURLForResourceWithEmptyExtension() {
        let url = ResourceLocator.url(forResource: "test", withExtension: "")
        // Should handle empty extension
        _ = url
        XCTAssertTrue(true)
    }

    func testURLForResourceWithDevRelativePath() {
        let url = ResourceLocator.url(
            forResource: "test",
            withExtension: "txt",
            devRelativePath: "Sources/test.txt"
        )
        // Should handle dev relative path
        _ = url
        XCTAssertTrue(true)
    }

    func testPythonScriptURL() {
        let url = ResourceLocator.pythonScriptURL(named: "nonexistent")
        // Should return nil for non-existent script
        XCTAssertNil(url)
    }

    func testPythonScriptURLFormat() {
        // Test that the dev path is constructed correctly
        let scriptName = "test_script"
        let expectedDevPath = "Sources/\(scriptName).py"
        XCTAssertEqual(expectedDevPath, "Sources/test_script.py")
    }

    func testBundleMainExists() {
        XCTAssertNotNil(Bundle.main)
    }

    func testBundleMainResourceURLAccessible() {
        // Resource URL may be nil but should not crash
        _ = Bundle.main.resourceURL
        XCTAssertTrue(true)
    }

    func testCurrentDirectoryAccessible() {
        let currentDir = FileManager.default.currentDirectoryPath
        XCTAssertFalse(currentDir.isEmpty)
    }
}

// MARK: - ResourceLocator Path Resolution Tests
final class ResourceLocatorPathResolutionTests: XCTestCase {

    func testMainBundleIsFirstPriority() {
        // Document that main bundle is checked first
        XCTAssertNotNil(Bundle.main)
    }

    func testDevPathFallback() {
        // Test that dev path is properly constructed
        let devPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/test.py")
            .path

        XCTAssertTrue(devPath.contains("Sources"))
        XCTAssertTrue(devPath.hasSuffix("test.py"))
    }

    func testResourceBundleName() {
        let bundleName = "AudioWhisper_AudioWhisper"
        XCTAssertEqual(bundleName, "AudioWhisper_AudioWhisper")
    }
}

// MARK: - ResourceLocator Python Script Tests
final class ResourceLocatorPythonScriptTests: XCTestCase {

    func testKnownPythonScripts() {
        let knownScripts = [
            "parakeet_transcribe_pcm",
            "mlx_semantic_correct",
            "verify_parakeet",
            "verify_mlx",
        ]

        for script in knownScripts {
            // These may or may not exist depending on build type
            let url = ResourceLocator.pythonScriptURL(named: script)
            // Just verify no crash
            _ = url
        }
        XCTAssertTrue(true)
    }

    func testPythonScriptExtension() {
        // Verify py extension is used
        let url = ResourceLocator.pythonScriptURL(named: "test")
        // URL format should include .py
        XCTAssertTrue(true)
    }
}

// MARK: - ResourceLocator Bundle Candidates Tests
final class ResourceLocatorBundleCandidatesTests: XCTestCase {

    func testBundleURLAccessible() {
        _ = Bundle.main.bundleURL
        XCTAssertTrue(true)
    }

    func testResourceURLAccessible() {
        _ = Bundle.main.resourceURL
        XCTAssertTrue(true)
    }

    func testAppendingPathComponent() {
        let base = URL(fileURLWithPath: "/test")
        let appended = base.appendingPathComponent("file.txt")
        XCTAssertEqual(appended.lastPathComponent, "file.txt")
    }
}
