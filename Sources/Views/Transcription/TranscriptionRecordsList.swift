import SwiftUI
import AppKit

internal struct TranscriptionRecordsList: View {
    let records: [TranscriptionRecord]
    let expandedRecords: Set<TranscriptionRecord.ID>
    let onToggleExpand: (TranscriptionRecord) -> Void
    let onCopy: (TranscriptionRecord) -> Void
    let onDelete: (TranscriptionRecord) -> Void
    /// Invoked when the last row appears, used by the parent to trigger
    /// paginated loading of additional records. Defaults to a no-op so existing
    /// call sites and tests don't need to supply it.
    var onLastRowAppear: () -> Void = {}

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    TranscriptionRecordRow(
                        record: record,
                        isExpanded: expandedRecords.contains(record.id),
                        onToggleExpand: { onToggleExpand(record) },
                        onCopy: { onCopy(record) },
                        onDelete: { onDelete(record) }
                    )
                    .transition(.opacity)
                    .onAppear {
                        if index == records.count - 1 {
                            onLastRowAppear()
                        }
                    }
                }
            }
            .padding(.vertical, 1)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .accessibilityLabel("Transcription records list")
        .accessibilityHint("Contains \(records.count) transcription records")
    }
}
