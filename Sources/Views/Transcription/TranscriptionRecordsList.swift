import SwiftUI
import AppKit

internal struct TranscriptionRecordsList: View {
    let records: [TranscriptionRecord]
    let expandedRecords: Set<TranscriptionRecord.ID>
    let onToggleExpand: (TranscriptionRecord) -> Void
    let onCopy: (TranscriptionRecord) -> Void
    let onDelete: (TranscriptionRecord) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(records, id: \.id) { record in
                    TranscriptionRecordRow(
                        record: record,
                        isExpanded: expandedRecords.contains(record.id),
                        onToggleExpand: { onToggleExpand(record) },
                        onCopy: { onCopy(record) },
                        onDelete: { onDelete(record) }
                    )
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 1)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .accessibilityLabel("Transcription records list")
        .accessibilityHint("Contains \(records.count) transcription records")
    }
}
