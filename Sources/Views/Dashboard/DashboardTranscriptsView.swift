import SwiftUI
import SwiftData

internal struct DashboardTranscriptsView: View {
    var body: some View {
        Group {
            if let container = DataManager.shared.sharedModelContainer {
                TranscriptionHistoryView()
                    .modelContainer(container)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                    
                    Text("History not available")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview("Transcripts") {
    DashboardTranscriptsView()
}
