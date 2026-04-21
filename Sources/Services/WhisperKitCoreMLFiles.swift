import Foundation

internal enum WhisperKitCoreMLFiles {
    private static let repoName = "argmaxinc/whisperkit-coreml"
    private static let revision = "main"
    private static let requestTimeout: TimeInterval = 30

    static func install(
        for model: WhisperModel,
        supplementalFileCount: Int,
        progressHandler: @Sendable (_ completedFiles: Int, _ totalFiles: Int, _ currentFileName: String) -> Void
    ) async throws -> Int {
        guard let storageDirectory = WhisperKitStorage.storageDirectory(),
              let modelDirectory = WhisperKitStorage.modelDirectory(for: model) else {
            throw ModelError.applicationSupportDirectoryNotFound
        }

        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        let files = try await remoteFiles(for: model)
        guard !files.isEmpty else {
            throw ModelError.downloadFileFailed(
                fileName: model.whisperKitModelName,
                repo: repoName,
                reason: "No matching files found"
            )
        }

        let totalFiles = files.count + supplementalFileCount

        for (index, relativeFilename) in files.enumerated() {
            let destination = storageDirectory.appendingPathComponent(relativeFilename)
            try await install(
                relativeFilename: relativeFilename,
                destination: destination
            )
            progressHandler(index + 1, totalFiles, URL(fileURLWithPath: relativeFilename).lastPathComponent)
        }

        return files.count
    }

    private static func remoteFiles(for model: WhisperModel) async throws -> [String] {
        let url = URL(string: "https://huggingface.co/api/models/\(repoName)/revision/\(revision)")!
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ModelError.downloadFileFailed(
                fileName: "model file list",
                repo: repoName,
                reason: error.localizedDescription
            )
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ModelError.downloadFileFailed(
                fileName: "model file list",
                repo: repoName,
                reason: (response as? HTTPURLResponse).map { "HTTP \($0.statusCode)" } ?? "Invalid response"
            )
        }

        do {
            let decoded = try JSONDecoder().decode(HuggingFaceModelInfo.self, from: data)
            let prefix = "\(model.whisperKitModelName)/"
            return decoded.siblings
                .map(\.rfilename)
                .filter { $0.hasPrefix(prefix) }
                .sorted()
        } catch {
            throw ModelError.downloadFileFailed(
                fileName: "model file list",
                repo: repoName,
                reason: "Could not parse response"
            )
        }
    }

    private static func install(relativeFilename: String, destination: URL) async throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            return
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let url = URL(string: "https://huggingface.co/\(repoName)/resolve/\(revision)/\(encodedPath(relativeFilename))")!
        let request = URLRequest(url: url, timeoutInterval: requestTimeout)

        let temporaryURL: URL
        let response: URLResponse
        do {
            (temporaryURL, response) = try await URLSession.shared.download(for: request)
        } catch {
            throw ModelError.downloadFileFailed(
                fileName: relativeFilename,
                repo: repoName,
                reason: error.localizedDescription
            )
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw ModelError.downloadFileFailed(
                fileName: relativeFilename,
                repo: repoName,
                reason: (response as? HTTPURLResponse).map { "HTTP \($0.statusCode)" } ?? "Invalid response"
            )
        }

        let resourceValues = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
        guard (resourceValues.fileSize ?? 0) > 0 else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw ModelError.downloadFileFailed(
                fileName: relativeFilename,
                repo: repoName,
                reason: "Downloaded file is empty"
            )
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destination)
    }

    private static func encodedPath(_ path: String) -> String {
        path.split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
    }
}

private struct HuggingFaceModelInfo: Decodable {
    let siblings: [HuggingFaceSibling]
}

private struct HuggingFaceSibling: Decodable {
    let rfilename: String
}
