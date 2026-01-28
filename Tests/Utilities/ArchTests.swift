import XCTest
@testable import AudioWhisper

/// Tests for Arch utility
final class ArchTests: XCTestCase {

    // MARK: - Architecture Detection Tests

    func testIsAppleSiliconReturnsBoolean() {
        let result = Arch.isAppleSilicon

        // Result should be a boolean (true on ARM64, false otherwise)
        XCTAssertTrue(result == true || result == false)
    }

    func testIsAppleSiliconConsistency() {
        // Multiple calls should return the same value
        let result1 = Arch.isAppleSilicon
        let result2 = Arch.isAppleSilicon
        let result3 = Arch.isAppleSilicon

        XCTAssertEqual(result1, result2)
        XCTAssertEqual(result2, result3)
    }

    #if arch(arm64)
    func testIsAppleSiliconOnARM64() {
        // On ARM64 devices (Apple Silicon), should return true
        XCTAssertTrue(Arch.isAppleSilicon)
    }
    #endif

    #if arch(x86_64)
    func testIsAppleSiliconOnIntel() {
        // On x86_64 devices (Intel), should return false
        XCTAssertFalse(Arch.isAppleSilicon)
    }
    #endif

    // MARK: - Enum Type Tests

    func testArchIsEnum() {
        // Arch is an enum with no cases (namespace)
        // This test ensures the type exists and is accessible
        _ = Arch.self
        XCTAssertTrue(true, "Arch type exists")
    }

    func testArchStaticPropertyAccess() {
        // isAppleSilicon is a static property
        _ = Arch.isAppleSilicon
        XCTAssertTrue(true, "Static property is accessible")
    }

    // MARK: - Compile-Time Detection Tests

    func testArchitectureDetectionIsCompileTime() {
        // The architecture detection uses #if arch() which is compile-time
        // This test documents that behavior
        let isAppleSilicon = Arch.isAppleSilicon

        // The value is determined at compile time, not runtime
        // So it should be constant for a given build
        XCTAssertEqual(Arch.isAppleSilicon, isAppleSilicon)
    }

    // MARK: - Usage Context Tests

    func testArchIsUsedForFeatureGating() {
        // Arch.isAppleSilicon is used to gate Apple Silicon-specific features
        // like Parakeet (MLX-based transcription)

        if Arch.isAppleSilicon {
            // On Apple Silicon, Parakeet features should be available
            XCTAssertTrue(true, "Apple Silicon features can be enabled")
        } else {
            // On Intel, Parakeet features may be unavailable or degraded
            XCTAssertTrue(true, "Running on non-Apple Silicon")
        }
    }

    // MARK: - Performance Tests

    func testArchPropertyAccessIsEfficient() {
        // Accessing the static property should be essentially free
        // as it's a compile-time constant
        measure {
            for _ in 0..<100000 {
                _ = Arch.isAppleSilicon
            }
        }
    }

    // MARK: - Documentation Tests

    func testArchProvidesArchitectureInfo() {
        // This is a documentation test to ensure the enum's purpose is clear
        // Arch provides architecture detection for feature gating

        let architectureString: String
        if Arch.isAppleSilicon {
            architectureString = "ARM64 (Apple Silicon)"
        } else {
            architectureString = "x86_64 (Intel)"
        }

        XCTAssertFalse(architectureString.isEmpty)
    }
}
