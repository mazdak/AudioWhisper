import Foundation

internal enum WhisperKitStorage {
    private static func baseDirectory(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true)
    }

    static func storageDirectory(fileManager: FileManager = .default) -> URL? {
        baseDirectory(fileManager: fileManager)
    }

    static func modelDirectory(for model: WhisperModel, fileManager: FileManager = .default) -> URL? {
        baseDirectory(fileManager: fileManager)?
            .appendingPathComponent(model.whisperKitModelName, isDirectory: true)
    }

    static func isModelDownloaded(_ model: WhisperModel, fileManager: FileManager = .default) -> Bool {
        guard let modelDirectory = modelDirectory(for: model, fileManager: fileManager) else { return false }

        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: modelDirectory.path, isDirectory: &isDirectory)
        guard exists, isDirectory.boolValue else { return false }

        let contents = (try? fileManager.contentsOfDirectory(atPath: modelDirectory.path)) ?? []
        return contents.contains { $0.hasSuffix(".json") || $0.hasSuffix(".bin") || $0.hasSuffix(".mlmodelc") }
    }

    static func localModelPath(for model: WhisperModel, fileManager: FileManager = .default) -> String? {
        guard isModelDownloaded(model, fileManager: fileManager),
              let url = modelDirectory(for: model, fileManager: fileManager) else {
            return nil
        }
        return url.path
    }

    static func ensureBaseDirectoryExists(fileManager: FileManager = .default) {
        guard let baseDirectory = baseDirectory(fileManager: fileManager) else { return }
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }
}
