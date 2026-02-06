import Foundation

internal enum WhisperKitStorage {
    // WhisperKit downloads CoreML bundles into a model folder. During download, the folder may exist with
    // partial contents (e.g. config JSON), so "is downloaded" must check for the required CoreML bundles
    // and tokenizer artifacts rather than any single file extension.
    private static let requiredCoreMLBundles = [
        "AudioEncoder.mlmodelc",
        "MelSpectrogram.mlmodelc",
        "TextDecoder.mlmodelc",
    ]

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

        // Required top-level files
        let requiredFiles = ["config.json", "generation_config.json"]
        for file in requiredFiles {
            if !fileManager.fileExists(atPath: modelDirectory.appendingPathComponent(file).path) {
                return false
            }
        }

        // Required CoreML bundles (and a sentinel file inside each) to avoid partial-download false positives.
        for bundle in requiredCoreMLBundles {
            let bundleURL = modelDirectory.appendingPathComponent(bundle, isDirectory: true)
            var isBundleDir: ObjCBool = false
            guard fileManager.fileExists(atPath: bundleURL.path, isDirectory: &isBundleDir),
                  isBundleDir.boolValue else {
                return false
            }

            let sentinel = bundleURL.appendingPathComponent("coremldata.bin")
            if !fileManager.fileExists(atPath: sentinel.path) {
                return false
            }
        }

        // Tokenizer artifact (location varies by model, so search under `models/`).
        let modelsDir = modelDirectory.appendingPathComponent("models", isDirectory: true)
        var isModelsDir: ObjCBool = false
        guard fileManager.fileExists(atPath: modelsDir.path, isDirectory: &isModelsDir),
              isModelsDir.boolValue else {
            return false
        }

        return containsTokenizerJSON(in: modelsDir, fileManager: fileManager)
    }

    private static func containsTokenizerJSON(in directory: URL, fileManager: FileManager) -> Bool {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "tokenizer.json" {
                return true
            }
        }

        return false
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
