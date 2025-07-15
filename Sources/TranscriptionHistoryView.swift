import SwiftUI
import SwiftData
import AppKit

@MainActor
struct TranscriptionHistoryView: View {
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
            // Header with title and actions
            headerView
            
            Divider()
            
            // Search bar
            searchBar
            
            // Content area
            if isLoading {
                loadingView
            } else if filteredRecords.isEmpty {
                emptyStateView
            } else {
                recordsList
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
        .frame(minWidth: 700, minHeight: 400)
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
    
    // MARK: - Header View
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Transcription History")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitleText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !allRecords.isEmpty {
                Button("Clear All", action: showClearAllConfirmation)
                    .font(.system(size: 12))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Search Bar
    
    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isSearchFocused ? .accentColor : .secondary)
                .font(.system(size: 16))
                .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
            
            TextField("Search transcriptions...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isSearchFocused)
                .accessibilityLabel("Search transcriptions")
                .accessibilityHint("Type to filter transcription records by text or provider. Press Cmd+F to focus.")
            
            if !searchText.isEmpty {
                Button(action: { 
                    searchText = ""
                    isSearchFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .help("Clear search (Escape)")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSearchFocused ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        .padding()
    }
    
    // MARK: - Loading View
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("Loading transcription history...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Loading transcription history")
    }
    
    // MARK: - Empty State View
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: searchText.isEmpty ? "mic.slash" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Transcriptions Yet" : "No Results Found")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty 
                     ? "Your transcription history will appear here\nonce you start recording." 
                     : "Try adjusting your search terms\nor check your spelling.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            
            if !searchText.isEmpty {
                Button("Clear Search") {
                    searchText = ""
                    isSearchFocused = false
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityLabel("Clear search to show all records")
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(searchText.isEmpty 
                            ? "No transcription records available" 
                            : "No search results found for \(searchText)")
    }
    
    // MARK: - Records List
    
    @ViewBuilder
    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredRecords, id: \.id) { record in
                    TranscriptionRecordRow(
                        record: record,
                        isExpanded: expandedRecords.contains(record.id),
                        onToggleExpand: { toggleExpansion(for: record) },
                        onCopy: { copyToClipboard(record.text) },
                        onDelete: { confirmDelete(record) }
                    )
                    .transition(.opacity)
                }
            }
            .padding(.vertical, 1)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .accessibilityLabel("Transcription records list")
        .accessibilityHint("Contains \(filteredRecords.count) transcription records")
    }
    
    // MARK: - Actions
    
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

extension TranscriptionHistoryView {
    
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

// MARK: - TranscriptionRecordRow

struct TranscriptionRecordRow: View {
    let record: TranscriptionRecord
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var hoveredButton: String? = nil
    
    var body: some View {
        Button(action: onToggleExpand) {
            VStack(alignment: .leading, spacing: 0) {
                // Header section
                HStack(alignment: .top, spacing: 12) {
                    // Main content
                    VStack(alignment: .leading, spacing: 8) {
                        // Date and metadata row with chevron
                        HStack(spacing: 12) {
                            // Expand/collapse chevron aligned with date text
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                                .frame(width: 12)
                            
                            Text(record.formattedDate)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 8) {
                                // Provider badge
                                providerBadge
                                
                                // Duration if available
                                if let duration = record.formattedDuration {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 10))
                                        Text(duration)
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.secondary)
                                }
                                
                                // Model used if available
                                if let modelUsed = record.modelUsed {
                                    Text(modelUsed)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Action buttons (always present for consistent height, opacity changes on hover)
                            HStack(spacing: 4) {
                                Button(action: { 
                                    onCopy()
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                        .foregroundColor(hoveredButton == "copy" ? .blue : .secondary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(hoveredButton == "copy" ? Color.blue.opacity(0.1) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("Copy to clipboard")
                                .onHover { isHovering in
                                    hoveredButton = isHovering ? "copy" : nil
                                }
                                
                                Button(action: {
                                    onDelete()
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundColor(hoveredButton == "delete" ? .red : .secondary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(hoveredButton == "delete" ? Color.red.opacity(0.1) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help("Delete")
                                .onHover { isHovering in
                                    hoveredButton = isHovering ? "delete" : nil
                                }
                            }
                            .opacity(isHovered ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15), value: isHovered)
                        }
                        
                        // Transcription preview or full text
                        Text(record.text)
                            .font(.system(size: 13))
                            .foregroundColor(isExpanded ? .primary : .secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(nil, value: isExpanded)
                        
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(backgroundFill)
        )
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Transcription from \(record.formattedDate), using \(record.provider)")
        .accessibilityHint("Tap to expand or collapse. Use action buttons to copy or delete.")
    }
    
    @ViewBuilder
    private var providerBadge: some View {
        if let provider = record.transcriptionProvider {
            Text(provider.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(providerColor(for: provider))
                .cornerRadius(4)
        } else {
            Text(record.provider)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray)
                .cornerRadius(4)
        }
    }
    
    private var backgroundFill: Color {
        if isHovered {
            return Color(NSColor.controlBackgroundColor)
        } else {
            return Color.clear
        }
    }
    
    private func providerColor(for provider: TranscriptionProvider) -> Color {
        switch provider {
        case .openai:
            return .green
        case .gemini:
            return .blue
        case .local:
            return .purple
        case .parakeet:
            return .orange
        }
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
        .frame(width: 700, height: 500)
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
        .frame(width: 700, height: 500)
}