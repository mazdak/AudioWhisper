import Foundation

internal enum WhisperKitSupplementalFiles {
    static let requiredFilenames = [
        "tokenizer_config.json",
        "special_tokens_map.json",
        "added_tokens.json",
        "normalizer.json",
        "vocab.json",
        "merges.txt",
        "preprocessor_config.json",
        "tokenizer.json",
    ]

    static func areInstalled(for model: WhisperModel, fileManager: FileManager = .default) -> Bool {
        guard let modelDirectory = WhisperKitStorage.modelDirectory(for: model, fileManager: fileManager) else {
            return false
        }

        let modelsDirectory = modelDirectory.appendingPathComponent("models", isDirectory: true)
        for filename in requiredFilenames {
            guard fileManager.fileExists(atPath: modelDirectory.appendingPathComponent(filename).path),
                  fileManager.fileExists(atPath: modelsDirectory.appendingPathComponent(filename).path) else {
                return false
            }
        }

        return true
    }

    static func install(
        for model: WhisperModel,
        progressHandler: (@Sendable (_ completedFiles: Int, _ totalFiles: Int, _ currentFileName: String) -> Void)? = nil
    ) async throws {
        guard let modelDirectory = WhisperKitStorage.modelDirectory(for: model) else {
            throw ModelError.applicationSupportDirectoryNotFound
        }

        let fileManager = FileManager.default
        let modelsDirectory = modelDirectory.appendingPathComponent("models", isDirectory: true)
        try fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        for (index, filename) in requiredFilenames.enumerated() {
            try await install(filename: filename, model: model, modelDirectory: modelDirectory, modelsDirectory: modelsDirectory)
            progressHandler?(index + 1, requiredFilenames.count, filename)
        }

        try ensureRequiredFilesExist(for: model, fileManager: fileManager)
    }

    private static func install(filename: String, model: WhisperModel, modelDirectory: URL, modelsDirectory: URL) async throws {
        let topLevelDestination = modelDirectory.appendingPathComponent(filename)
        let nestedDestination = modelsDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: topLevelDestination.path) {
            try copyIfNeeded(from: topLevelDestination, to: nestedDestination)
            return
        }

        if FileManager.default.fileExists(atPath: nestedDestination.path) {
            try copyIfNeeded(from: nestedDestination, to: topLevelDestination)
            return
        }

        try await download(filename: filename, for: model, to: topLevelDestination)
        try copyIfNeeded(from: topLevelDestination, to: nestedDestination)
    }

    private static func ensureRequiredFilesExist(for model: WhisperModel, fileManager: FileManager) throws {
        guard areInstalled(for: model, fileManager: fileManager) else {
            throw ModelError.downloadFailed
        }
    }

    private static func download(filename: String, for model: WhisperModel, to destination: URL) async throws {
        let url = URL(string: "\(model.openAIWhisperRepoURL.absoluteString)/resolve/main/\(filename)")!
        let temporaryURL: URL
        let response: URLResponse

        do {
            (temporaryURL, response) = try await URLSession.shared.download(from: url)
        } catch {
            throw ModelError.downloadFileFailed(
                fileName: filename,
                repo: model.openAIWhisperRepoName,
                reason: error.localizedDescription
            )
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            throw ModelError.downloadFileFailed(
                fileName: filename,
                repo: model.openAIWhisperRepoName,
                reason: statusCode.map { "HTTP \($0)" } ?? "Invalid response"
            )
        }

        let resourceValues = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
        guard (resourceValues.fileSize ?? 0) > 0 else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw ModelError.downloadFileFailed(
                fileName: filename,
                repo: model.openAIWhisperRepoName,
                reason: "Downloaded file is empty"
            )
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporaryURL, to: destination)
    }

    private static func copyIfNeeded(from source: URL, to destination: URL) throws {
        guard source.path != destination.path else { return }

        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination.path) else { return }

        try fileManager.copyItem(at: source, to: destination)
    }
}
