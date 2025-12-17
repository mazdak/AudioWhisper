import XCTest
import SwiftUI
import AppKit
@testable import AudioWhisper

/// Lightweight snapshot helper built on XCTest + ImageRenderer.
@MainActor
class SnapshotTestCase: XCTestCase {
    private let snapshotFolderName = "__Snapshots__"
    
    /// Enable recording by running tests with `SNAPSHOT_RECORD=1`.
    private var isRecording: Bool {
        ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    }
    
    func assertSnapshot<V: View>(
        _ view: V,
        named name: String,
        size: CGSize,
        colorScheme: ColorScheme = .light,
        scale: CGFloat = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let content = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme)
        
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        
        guard let image = renderer.nsImage,
              let actualData = image.pngData() else {
            XCTFail("Failed to render snapshot \(name)", file: file, line: line)
            return
        }
        
        let snapshotURL = makeSnapshotURL(for: name, file: file)
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        if isRecording {
            do {
                try actualData.write(to: snapshotURL)
                XCTFail("Recorded snapshot \(name). Re-run without SNAPSHOT_RECORD to validate.", file: file, line: line)
            } catch {
                XCTFail("Failed to record snapshot \(name): \(error)", file: file, line: line)
            }
            return
        }
        
        guard let baselineData = try? Data(contentsOf: snapshotURL) else {
            XCTFail("Missing baseline for \(name). Run with SNAPSHOT_RECORD=1 to create it.", file: file, line: line)
            return
        }
        
        if baselineData != actualData {
            let expectedAttachment = XCTAttachment(contentsOfFile: snapshotURL)
            expectedAttachment.name = "\(name)-baseline"
            expectedAttachment.lifetime = .deleteOnSuccess
            
            let actualAttachment = XCTAttachment(data: actualData, uniformTypeIdentifier: "public.png")
            actualAttachment.name = "\(name)-actual"
            actualAttachment.lifetime = .deleteOnSuccess
            
            add(expectedAttachment)
            add(actualAttachment)
            XCTFail("Snapshot mismatch for \(name).", file: file, line: line)
        }
    }
    
    private func makeSnapshotURL(for name: String, file: StaticString) -> URL {
        var url = URL(fileURLWithPath: String(describing: file))
        while url.lastPathComponent != "Tests" && url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
        }
        return url
            .appendingPathComponent(snapshotFolderName, isDirectory: true)
            .appendingPathComponent("\(name).png")
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
