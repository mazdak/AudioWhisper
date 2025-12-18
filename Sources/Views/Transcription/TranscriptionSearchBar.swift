import SwiftUI

internal struct TranscriptionSearchBar: View {
    @Binding var searchText: String
    var isFocused: FocusState<Bool>.Binding
    
    private var isFocusedValue: Bool { isFocused.wrappedValue }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(isFocusedValue ? Color.accentColor : .secondary)
                .font(.callout)
                .animation(.easeInOut(duration: 0.2), value: isFocusedValue)
            
            TextField("Search transcriptions...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused(isFocused)
                .accessibilityLabel("Search transcriptions")
                .accessibilityHint("Type to filter transcription records by text or provider. Press Cmd+F to focus.")
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    isFocused.wrappedValue = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.callout)
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
                        .stroke(isFocusedValue ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocusedValue)
        .padding()
    }
}
