import SwiftUI
import SwiftData
import AppKit

@MainActor
internal struct TranscriptionHistoryView: View {
    @Query(sort: \TranscriptionRecord.date, order: .reverse) private var allRecords: [TranscriptionRecord]

    @State private var searchText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isBusy = false

    @State private var selection: Set<TranscriptionRecord.ID> = []

    @State private var showDeleteSelectedConfirmation = false
    @State private var showClearAllConfirmation = false
    
    // Computed property for filtered records
    private var filteredRecords: [TranscriptionRecord] {
        if searchText.isEmpty {
            return allRecords
        }
        return allRecords.filter { record in
            record.matches(searchQuery: searchText)
        }
    }

    private var selectedRecords: [TranscriptionRecord] {
        allRecords.filter { selection.contains($0.id) }
    }

    private var primarySelection: TranscriptionRecord? {
        selectedRecords.first
    }
    
    var body: some View {
        VSplitView {
            listPane
                .frame(minHeight: 260)

            detailPane
                .frame(minHeight: 180)
        }
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    copySelectedToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(selectedRecords.isEmpty)

                Button(role: .destructive) {
                    showDeleteSelectedConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedRecords.isEmpty || isBusy)

                Button(role: .destructive) {
                    showClearAllConfirmation = true
                } label: {
                    Text("Clear All")
                }
                .disabled(allRecords.isEmpty || isBusy)
            }
        }
        .onDeleteCommand {
            guard !selectedRecords.isEmpty else { return }
            showDeleteSelectedConfirmation = true
        }
        .confirmationDialog(
            "Delete Transcriptions",
            isPresented: $showDeleteSelectedConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel", role: .cancel) {}
            Button(deleteSelectedButtonTitle, role: .destructive) {
                deleteSelectedRecords()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .confirmationDialog(
            "Clear All Transcription History",
            isPresented: $showClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearAllRecords()
            }
        } message: {
            Text("This will permanently delete all transcriptions.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .frame(
            minWidth: LayoutMetrics.TranscriptionHistory.minimumSize.width,
            minHeight: LayoutMetrics.TranscriptionHistory.minimumSize.height
        )
    }

    private var listPane: some View {
        VStack(spacing: 0) {
            if filteredRecords.isEmpty {
                TranscriptionHistoryEmptyContent(searchText: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(filteredRecords, selection: $selection) {
                    TableColumn("Date") { record in
                        Text(record.formattedDate)
                            .lineLimit(1)
                    }

                    TableColumn("Provider") { record in
                        Text(record.transcriptionProvider?.displayName ?? record.provider)
                            .lineLimit(1)
                    }

                    TableColumn("Duration") { record in
                        Text(record.formattedDuration ?? "—")
                            .lineLimit(1)
                    }

                    TableColumn("Text") { record in
                        Text(record.preview)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var detailPane: some View {
        Group {
            if let record = primarySelection {
                TranscriptionDetailView(record: record)
            } else {
                ContentUnavailableView(
                    "Select a Transcript",
                    systemImage: "doc.text",
                    description: Text("Choose a transcription on the left to view details.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var deleteSelectedButtonTitle: String {
        let count = selectedRecords.count
        if count <= 1 { return "Delete" }
        return "Delete \(count) Items"
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        // Brief visual feedback could be added here
    }

    private func copySelectedToClipboard() {
        let text = selectedRecords.map(\.text).joined(separator: "\n\n")
        guard !text.isEmpty else { return }
        copyToClipboard(text)
    }

    private func deleteSelectedRecords() {
        let records = selectedRecords
        guard !records.isEmpty else { return }

        isBusy = true
        Task {
            do {
                for record in records {
                    try await DataManager.shared.deleteRecord(record)
                }
                await MainActor.run {
                    selection.removeAll()
                    isBusy = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete records: \(error.localizedDescription)"
                    showError = true
                    isBusy = false
                }
            }
        }
    }

    private func clearAllRecords() {
        Task {
            isBusy = true
            do {
                try await DataManager.shared.deleteAllRecords()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to clear all records: \(error.localizedDescription)"
                    showError = true
                }
            }
            await MainActor.run {
                selection.removeAll()
                isBusy = false
            }
        }
    }
}

private struct TranscriptionHistoryEmptyContent: View {
    let searchText: String

    var body: some View {
        if searchText.isEmpty {
            ContentUnavailableView(
                "No Transcripts Yet",
                systemImage: "doc.text",
                description: Text("Your transcription history will appear here.")
            )
        } else {
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("Try a different search term.")
            )
        }
    }
}

private struct TranscriptionDetailView: View {
    let record: TranscriptionRecord

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            details
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 360, alignment: .topLeading)
                .padding(12)

            Divider()

            ScrollView {
                Text(record.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Date") {
                Text(record.formattedDate)
            }

            LabeledContent("Provider") {
                Text(record.transcriptionProvider?.displayName ?? record.provider)
            }

            if let duration = record.formattedDuration {
                LabeledContent("Duration") {
                    Text(duration)
                }
            }

            if let modelUsed = record.modelUsed, !modelUsed.isEmpty {
                LabeledContent("Model") {
                    Text(modelUsed)
                }
            }

            if let source = record.sourceAppName, !source.isEmpty {
                LabeledContent("Source App") {
                    Text(source)
                }
            }

            if record.wordCount > 0 {
                LabeledContent("Words") {
                    Text("\(record.wordCount)")
                }
            }

            if let wpm = record.wordsPerMinute {
                LabeledContent("WPM") {
                    Text(wpm.formatted(.number.precision(.fractionLength(0))))
                }
            }
        }
        .font(.callout)
    }
}

// MARK: - Preview

#Preview("With Records") {
    let previewContainer: ModelContainer = {
        do {
            let container = try ModelContainer(for: TranscriptionRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let context = ModelContext(container)
            
            // Add sample data
            let sampleRecords = [
                TranscriptionRecord(text: "This is a sample transcription from OpenAI Whisper service. It demonstrates how the history view will look with longer text content.", provider: .openai, duration: 12.5),
                TranscriptionRecord(text: "Short test", provider: .local, duration: 2.1, modelUsed: "base"),
                TranscriptionRecord(text: "Another example transcription that shows how multiple records are displayed in the history view.", provider: .gemini, duration: 8.3)
            ]
            
            for record in sampleRecords {
                context.insert(record)
            }
            
            try context.save()
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
    
    return TranscriptionHistoryView()
        .modelContainer(previewContainer)
        .frame(
            width: LayoutMetrics.TranscriptionHistory.previewSize.width,
            height: LayoutMetrics.TranscriptionHistory.previewSize.height
        )
}

#Preview("Empty State") {
    let previewContainer: ModelContainer = {
        do {
            return try ModelContainer(for: TranscriptionRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
    
    return TranscriptionHistoryView()
        .modelContainer(previewContainer)
        .frame(
            width: LayoutMetrics.TranscriptionHistory.previewSize.width,
            height: LayoutMetrics.TranscriptionHistory.previewSize.height
        )
}
