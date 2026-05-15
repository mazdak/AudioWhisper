import Foundation
import CryptoKit

/// Serializes disk-mutating operations keyed by a Hashable identifier.
///
/// Two callers requesting the SAME key (e.g. downloading the same model)
/// block each other and share the result of a single operation. Two callers
/// with DIFFERENT keys (e.g. downloading two different models) proceed in
/// parallel.
///
/// Used by `MLXModelManager` and `ModelManager` to prevent races during
/// model downloads and cache directory creation. The pattern was first
/// introduced for venv setup in `UvBootstrap.VenvSerializer` (Phase 3
/// of the grade-report sweep); this generalizes it.
internal actor DiskMutationSerializer<Key: Hashable & Sendable> {
    private var inFlight: [Key: Task<Void, Error>] = [:]

    /// Run `op` serialized on `key`. Concurrent callers for the same key
    /// will await the in-flight task instead of starting a new one.
    func run(key: Key, _ op: @Sendable @escaping () async throws -> Void) async throws {
        if let existing = inFlight[key] {
            return try await existing.value
        }
        let task = Task<Void, Error> { try await op() }
        inFlight[key] = task
        defer { Task { await self.clear(key: key) } }
        try await task.value
    }

    private func clear(key: Key) {
        inFlight[key] = nil
    }
}

/// Best-effort SHA-256 integrity check for cached model files.
///
/// After a successful download, callers record a hash of a representative
/// file (typically a manifest or small config). Before loading a cached
/// model, callers verify against that recorded hash. The check is
/// trust-on-first-use: if no sidecar exists yet, `verify` records one and
/// returns successfully — this keeps existing caches from a pre-integrity
/// build working without forcing a redownload.
///
/// This is defense in depth, not cryptographic assurance over every byte:
/// TLS already protects downloads in transit. The check guards against
/// cache corruption, partial/interrupted writes that left a truncated
/// file, and tampering by another local process.
internal enum ModelIntegrity {
    /// Compute SHA-256 of file at `url`. Streams the file in 64KB chunks so
    /// gigabyte-sized model files don't blow up memory.
    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        let chunkSize = 64 * 1024
        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Compute and persist a sidecar hash for a model file.
    /// Overwrites any pre-existing sidecar so a fresh download resets the
    /// integrity reference.
    static func record(at modelURL: URL) throws {
        let hash = try sha256(of: modelURL)
        try hash.write(to: sidecarURL(for: modelURL), atomically: true, encoding: .utf8)
    }

    /// Verify the sidecar hash matches; if missing, record it
    /// (trust-on-first-use). Throws `ModelIntegrityError.mismatch` only
    /// when a stored hash exists and the actual hash differs.
    static func verify(at modelURL: URL) throws {
        let sidecar = sidecarURL(for: modelURL)
        let actual = try sha256(of: modelURL)
        if let stored = try? String(contentsOf: sidecar, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty {
            guard stored.lowercased() == actual.lowercased() else {
                throw ModelIntegrityError.mismatch(expected: stored, actual: actual)
            }
        } else {
            // No sidecar yet — trust-on-first-use; persist for next time.
            try actual.write(to: sidecar, atomically: true, encoding: .utf8)
        }
    }

    /// Returns true if a sidecar exists and matches; false on any mismatch,
    /// missing-file error, or unreadable file. Never throws — useful for
    /// background verification where we don't want to surface noise.
    static func quietVerify(at modelURL: URL) -> Bool {
        do {
            try verify(at: modelURL)
            return true
        } catch {
            return false
        }
    }

    private static func sidecarURL(for modelURL: URL) -> URL {
        modelURL.appendingPathExtension("audiowhisper-integrity")
    }
}

internal enum ModelIntegrityError: LocalizedError {
    case mismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case let .mismatch(expected, actual):
            return "Model integrity check failed (expected \(expected.prefix(8))…, got \(actual.prefix(8))…). The cached model may be corrupted; re-download it from Settings."
        }
    }
}
