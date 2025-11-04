import Foundation
import SwiftData

// SwiftData @Model classes handle Sendable conformance automatically:
// 1. SwiftData manages thread safety internally through its model context
// 2. All access to @Model instances should go through the model context
// 3. The framework ensures proper synchronization across threads
@Model
final class TranscriptionRecord {
    @Attribute(.unique) var id: UUID
    var text: String
    var date: Date
   var provider: String // TranscriptionProvider.rawValue
   var duration: TimeInterval?
   var modelUsed: String?
    var wordCount: Int = 0
    
    init(
        text: String,
        provider: TranscriptionProvider,
        duration: TimeInterval? = nil,
        modelUsed: String? = nil,
        wordCount: Int = 0
    ) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.provider = provider.rawValue
        self.duration = duration
        self.modelUsed = modelUsed
        self.wordCount = wordCount
    }
}

// MARK: - Computed Properties
extension TranscriptionRecord {
    /// Returns the transcription provider as an enum
    var transcriptionProvider: TranscriptionProvider? {
        return TranscriptionProvider(rawValue: provider)
    }
    
    /// Returns the WhisperModel if applicable (for local transcriptions)
    var whisperModel: WhisperModel? {
        guard let modelUsed = modelUsed else { return nil }
        return WhisperModel(rawValue: modelUsed)
    }
    
    /// Returns a formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Returns a formatted duration string for display
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
    
    /// Returns a truncated version of the text for display in lists
    var preview: String {
        let maxLength = 100
        if text.count <= maxLength {
            return text
        }
        let truncatedText = String(text.prefix(maxLength))
        return truncatedText + "..."
    }

    var wordsPerMinute: Double? {
        guard let duration = duration, duration > 0 else { return nil }
        guard wordCount > 0 else { return nil }
        return Double(wordCount) / (duration / 60.0)
    }
}

// MARK: - Search and Filtering
extension TranscriptionRecord {
    /// Returns true if the record matches the search query
    func matches(searchQuery: String) -> Bool {
        guard !searchQuery.isEmpty else { return true }
        
        let lowercaseQuery = searchQuery.lowercased()
        return text.lowercased().contains(lowercaseQuery) ||
               provider.lowercased().contains(lowercaseQuery) ||
               (modelUsed?.lowercased().contains(lowercaseQuery) ?? false)
    }
}
