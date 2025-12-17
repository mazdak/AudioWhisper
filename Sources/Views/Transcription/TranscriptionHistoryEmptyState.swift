import SwiftUI

internal struct TranscriptionHistoryEmptyState: View {
    let searchText: String
    let onClearSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: searchText.isEmpty ? "mic.slash" : "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.3))
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Transcriptions Yet" : "No Results Found")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(searchText.isEmpty
                     ? "Your transcription history will appear here\nonce you start recording."
                     : "Try adjusting your search terms\nor check your spelling.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            
            if !searchText.isEmpty {
                Button("Clear Search") {
                    onClearSearch()
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
}
