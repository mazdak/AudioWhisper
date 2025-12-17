import SwiftUI
import SwiftData

internal struct DashboardTranscriptsView: View {
    var body: some View {
        Group {
            if let container = DataManager.shared.sharedModelContainer {
                TranscriptionHistoryView()
                    .modelContainer(container)
                    .environment(\.colorScheme, .light)
            } else {
                VStack(spacing: DashboardTheme.Spacing.md) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(DashboardTheme.inkFaint)
                    
                    Text("History not available")
                        .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DashboardTheme.pageBg)
    }
}

#Preview("Transcripts") {
    DashboardTranscriptsView()
}
