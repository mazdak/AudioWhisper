import SwiftUI
import SwiftData
import AppKit

@MainActor
internal struct TranscriptionHistoryView: View {
    @Environment(\.modelContext) private var modelContext

    // Paged record state — replaces the previous `@Query` so we don't materialize
    // the entire history. Records are loaded via
    // `DataManager.fetchRecords(limit:offset:search:)` in pages of `pageSize`.
    @State private var records: [TranscriptionRecord] = []
    @State private var page: Int = 0
    @State private var hasMore: Bool = true
    @State private var isLoading: Bool = false
    @State private var hasLoadedOnce: Bool = false

    @State private var searchText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var recordToDelete: TranscriptionRecord?
    @State private var showDeleteConfirmation = false
    @State private var expandedRecords: Set<TranscriptionRecord.ID> = []
    @FocusState private var isSearchFocused: Bool

    private let pageSize = 50

    var body: some View {
        VStack(spacing: 0) {
            TranscriptionHistoryHeader(
                title: "Transcription History",
                subtitle: subtitleText,
                showClearAll: !records.isEmpty,
                onClearAll: showClearAllConfirmation
            )

            Divider()

            TranscriptionSearchBar(
                searchText: $searchText,
                isFocused: $isSearchFocused
            )

            if isLoading && records.isEmpty {
                TranscriptionHistoryLoadingView()
            } else if records.isEmpty && hasLoadedOnce {
                TranscriptionHistoryEmptyState(
                    searchText: searchText,
                    onClearSearch: {
                        searchText = ""
                        isSearchFocused = false
                    }
                )
            } else {
                TranscriptionRecordsList(
                    records: records,
                    expandedRecords: expandedRecords,
                    onToggleExpand: toggleExpansion(for:),
                    onCopy: { copyToClipboard($0.text) },
                    onDelete: confirmDelete,
                    onLastRowAppear: {
                        if hasMore && !isLoading {
                            Task { await loadRecords() }
                        }
                    }
                )
            }
        }
        .task {
            await loadRecords(reset: true)
        }
        .onChange(of: searchText) { _, _ in
            Task { await loadRecords(reset: true) }
        }
        .alert("Delete Record", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let record = recordToDelete {
                    deleteRecord(record)
                }
            }
        } message: {
            Text("Are you sure you want to delete this transcription record? This action cannot be undone.")
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
        .onKeyPress(.escape) {
            handleEscapeKey()
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "f")) { keyPress in
            if keyPress.modifiers.contains(.command) {
                return handleCommandF()
            }
            return .ignored
        }
    }

    // MARK: - Paginated Loading

    @MainActor
    private func loadRecords(reset: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        if reset {
            page = 0
            hasMore = true
        }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerm: String? = trimmed.isEmpty ? nil : trimmed

        do {
            let offset = page * pageSize
            let batch = try await DataManager.shared.fetchRecords(
                limit: pageSize,
                offset: offset,
                search: searchTerm
            )

            if reset {
                records = batch
            } else {
                records.append(contentsOf: batch)
            }

            hasMore = batch.count == pageSize
            page += 1
        } catch {
            errorMessage = "Failed to load transcription history: \(error.localizedDescription)"
            showError = true
            hasMore = false
        }
    }

    private func copyToClipboard(_ text: String) {
        PasteManager.copyToClipboard(text)
    }

    private func confirmDelete(_ record: TranscriptionRecord) {
        recordToDelete = record
        showDeleteConfirmation = true
    }

    private func deleteRecord(_ record: TranscriptionRecord) {
        Task {
            do {
                try await DataManager.shared.deleteRecord(record)
                await loadRecords(reset: true)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete record: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func showClearAllConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Clear All Transcription History"
        alert.informativeText = "Are you sure you want to delete all transcription records? This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear All")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            clearAllRecords()
        }
    }

    private func clearAllRecords() {
        Task {
            isLoading = true
            do {
                try await DataManager.shared.deleteAllRecords()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to clear all records: \(error.localizedDescription)"
                    showError = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
            await loadRecords(reset: true)
        }
    }

    private func toggleExpansion(for record: TranscriptionRecord) {
        if expandedRecords.contains(record.id) {
            expandedRecords.remove(record.id)
        } else {
            expandedRecords.insert(record.id)
        }
    }

    private var subtitleText: String {
        let loadedCount = records.count

        if loadedCount == 0 {
            return "No records"
        }

        let noun = loadedCount == 1 ? "record" : "records"
        let suffix = hasMore ? "+" : ""

        if searchText.isEmpty {
            return "\(loadedCount)\(suffix) \(noun)"
        } else {
            return "\(loadedCount)\(suffix) matching \(noun)"
        }
    }

}

// MARK: - View Extensions

internal extension TranscriptionHistoryView {

    private func handleEscapeKey() -> KeyPress.Result {
        if isSearchFocused {
            searchText = ""
            isSearchFocused = false
            return .handled
        }
        return .ignored
    }

    private func handleCommandF() -> KeyPress.Result {
        isSearchFocused = true
        return .handled
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
                TranscriptionRecord(text: "This is a sample transcription from the Parakeet speech engine. It demonstrates how the history view will look with longer text content.", provider: .parakeet, duration: 12.5),
                TranscriptionRecord(text: "Short test", provider: .local, duration: 2.1, modelUsed: "base"),
                TranscriptionRecord(text: "Another example transcription that shows how multiple records are displayed in the history view.", provider: .parakeet, duration: 8.3)
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

    TranscriptionHistoryView()
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

    TranscriptionHistoryView()
        .modelContainer(previewContainer)
        .frame(
            width: LayoutMetrics.TranscriptionHistory.previewSize.width,
            height: LayoutMetrics.TranscriptionHistory.previewSize.height
        )
}
