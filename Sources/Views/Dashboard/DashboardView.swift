import SwiftUI
import AppKit

// MARK: - Dashboard Theme
internal enum DashboardTheme {
    // Sidebar - standard system colors
    static let sidebarDark = Color(nsColor: .windowBackgroundColor)
    static let sidebarLight = Color(nsColor: .controlBackgroundColor)
    static let sidebarText = Color(nsColor: .labelColor)
    static let sidebarTextMuted = Color(nsColor: .secondaryLabelColor)
    static let sidebarTextFaint = Color(nsColor: .tertiaryLabelColor)
    static let sidebarDivider = Color(nsColor: .separatorColor)
    static let sidebarAccent = Color.accentColor
    static let sidebarAccentSubtle = Color.accentColor.opacity(0.1)

    // Main content - Standard macOS appearance
    static let pageBg = Color(nsColor: .windowBackgroundColor)
    static let cardBg = Color(nsColor: .controlBackgroundColor)
    static let cardBgAlt = Color(nsColor: .controlBackgroundColor)

    // Text - Standard macOS
    static let ink = Color(nsColor: .labelColor)
    static let inkLight = Color(nsColor: .secondaryLabelColor)
    static let inkMuted = Color(nsColor: .tertiaryLabelColor)
    static let inkFaint = Color(nsColor: .quaternaryLabelColor)

    // Accent - System accent
    static let accent = Color.accentColor
    static let accentLight = Color.accentColor.opacity(0.12)
    static let accentSubtle = Color.accentColor.opacity(0.06)

    // Borders & Dividers - Standard macOS
    static let rule = Color(nsColor: .separatorColor)
    static let ruleBold = Color(nsColor: .gridColor)

    // Provider colors (system-leaning)
    static let providerOpenAI = Color(nsColor: .systemBlue)
    static let providerGemini = Color(nsColor: .systemIndigo)
    static let providerLocal = Color(nsColor: .systemTeal)
    static let providerParakeet = Color(nsColor: .systemGreen)

    // Activity heatmap (system grays)
    static let heatmapEmpty = Color(nsColor: .separatorColor)
    static let heatmapLow = Color(nsColor: .quaternaryLabelColor)
    static let heatmapMedium = Color(nsColor: .tertiaryLabelColor)
    static let heatmapHigh = Color(nsColor: .secondaryLabelColor)
    static let heatmapMax = Color(nsColor: .labelColor).opacity(0.6)

    // Semantic colors - adaptive to light/dark mode
    static let success = Color(nsColor: .systemGreen)
    static let destructive = Color(nsColor: .systemRed)

    // Typography - standard macOS system fonts
    enum Fonts {
        static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    // Spacing system (8pt base)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
}

// MARK: - Navigation Item
internal enum DashboardNavItem: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "Overview"
    case transcripts = "Transcripts"
    case categories = "Categories"
    case recording = "Recording"
    case providers = "Providers"
    case preferences = "Preferences"
    case permissions = "Permissions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.text.square"
        case .transcripts: return "doc.text"
        case .categories: return "folder"
        case .recording: return "waveform"
        case .providers: return "cloud"
        case .preferences: return "slider.horizontal.3"
        case .permissions: return "lock"
        }
    }
}

// MARK: - Main Dashboard View
internal struct DashboardView: View {
    @ObservedObject var selectionModel: DashboardSelectionModel

    init(selectionModel: DashboardSelectionModel = DashboardSelectionModel()) {
        self.selectionModel = selectionModel
    }

    var body: some View {
        NavigationSplitView {
            List(DashboardNavItem.allCases, selection: $selectionModel.selectedNav) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            // Remove the built-in sidebar toggle to keep the titlebar clean.
            .toolbar(removing: .sidebarToggle)
        } detail: {
            if let selectedNav = selectionModel.selectedNav {
                detailView(for: selectedNav)
                    .navigationTitle(selectedNav.rawValue)
            } else {
                Text("Select a section in the sidebar")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func detailView(for item: DashboardNavItem) -> some View {
        switch item {
        case .dashboard:
            DashboardHomeView(selectedNav: Binding(get: { selectionModel.selectedNav ?? .dashboard }, set: { selectionModel.selectedNav = $0 }))
        case .transcripts:
            DashboardTranscriptsView()
        case .categories:
            DashboardCategoriesView()
        case .recording:
            DashboardRecordingView()
        case .providers:
            DashboardProvidersView()
        case .preferences:
            DashboardPreferencesView()
        case .permissions:
            DashboardPermissionsView()
        }
    }
}

// MARK: - Preview
#Preview("Dashboard") {
    DashboardView()
        .frame(width: LayoutMetrics.DashboardWindow.previewSize.width,
               height: LayoutMetrics.DashboardWindow.previewSize.height)
}
