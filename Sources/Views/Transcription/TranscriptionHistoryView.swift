import SwiftUI
import SwiftData
import AppKit

@MainActor
internal struct TranscriptionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionRecord.date, order: .reverse) private var allRecords: [TranscriptionRecord]
    
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var recordToDelete: TranscriptionRecord?
    @State private var showDeleteConfirmation = false
    @State private var expandedRecords: Set<TranscriptionRecord.ID> = []
    @FocusState private var isSearchFocused: Bool
    
    // Computed property for filtered records
    private var filteredRecords: [TranscriptionRecord] {
        if searchText.isEmpty {
            return allRecords
        }
        return allRecords.filter { record in
            record.matches(searchQuery: searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TranscriptionHistoryHeader(
                title: "Transcription History",
                subtitle: subtitleText,
                showClearAll: !allRecords.isEmpty,
                onClearAll: showClearAllConfirmation
            )
            
            Divider()
            
            TranscriptionSearchBar(
                searchText: $searchText,
                isFocused: $isSearchFocused
            )
            
            if isLoading {
                TranscriptionHistoryLoadingView()
            } else if filteredRecords.isEmpty {
                TranscriptionHistoryEmptyState(
                    searchText: searchText,
                    onClearSearch: {
                        searchText = ""
                        isSearchFocused = false
                    }
                )
            } else {
                TranscriptionRecordsList(
                    records: filteredRecords,
                    expandedRecords: expandedRecords,
                    onToggleExpand: toggleExpansion(for:),
                    onCopy: { copyToClipboard($0.text) },
                    onDelete: confirmDelete
                )
            }
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
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        // Brief visual feedback could be added here
    }
    
    private func confirmDelete(_ record: TranscriptionRecord) {
        recordToDelete = record
        showDeleteConfirmation = true
    }
    
    private func deleteRecord(_ record: TranscriptionRecord) {
        Task {
            do {
                try await DataManager.shared.deleteRecord(record)
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
        let totalCount = allRecords.count
        let filteredCount = filteredRecords.count
        
        if totalCount == 0 {
            return "No records"
        } else if searchText.isEmpty {
            return "\(totalCount) \(totalCount == 1 ? "record" : "records")"
        } else {
            return "\(filteredCount) of \(totalCount) \(filteredCount == 1 ? "record" : "records")"
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
