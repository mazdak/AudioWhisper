import SwiftUI
import SwiftData
import AppKit

// MARK: - Dashboard Theme
internal enum DashboardTheme {
    // Sidebar - Blue gradient theme (#1E2F3D dark to #0D4988 light accent)
    private static let blueDark = Color(red: 0.118, green: 0.184, blue: 0.239)    // #1E2F3D
    private static let blueLight = Color(red: 0.051, green: 0.286, blue: 0.533)   // #0D4988
    
    static let sidebarDark = blueDark
    static let sidebarLight = blueLight
    static let sidebarText = Color.white
    static let sidebarTextMuted = Color.white.opacity(0.6)
    static let sidebarTextFaint = Color.white.opacity(0.4)
    static let sidebarDivider = Color.white.opacity(0.1)
    static let sidebarAccent = blueLight
    static let sidebarAccentSubtle = blueLight.opacity(0.2)
    
    // Main content - Standard macOS appearance
    static let pageBg = Color(nsColor: .windowBackgroundColor)
    static let cardBg = Color(nsColor: .controlBackgroundColor)
    static let cardBgAlt = Color(nsColor: .controlBackgroundColor).opacity(0.8)
    
    // Text - Standard macOS
    static let ink = Color(nsColor: .labelColor)
    static let inkLight = Color(nsColor: .secondaryLabelColor)
    static let inkMuted = Color(nsColor: .tertiaryLabelColor)
    static let inkFaint = Color(nsColor: .quaternaryLabelColor)
    
    // Accent - System blue
    static let accent = Color.accentColor
    static let accentLight = Color.accentColor.opacity(0.12)
    static let accentSubtle = Color.accentColor.opacity(0.06)
    
    // Borders & Dividers - Standard macOS
    static let rule = Color(nsColor: .separatorColor)
    static let ruleBold = Color(nsColor: .gridColor)
    
    // Provider colors
    static let providerOpenAI = Color(red: 0.45, green: 0.55, blue: 0.50)
    static let providerGemini = Color(red: 0.50, green: 0.52, blue: 0.65)
    static let providerLocal = Color(red: 0.55, green: 0.48, blue: 0.58)
    static let providerParakeet = blueLight
    
    // Activity heatmap (blue tones)
    static let heatmapEmpty = Color(nsColor: .separatorColor)
    static let heatmapLow = blueLight.opacity(0.3)
    static let heatmapMedium = blueLight.opacity(0.5)
    static let heatmapHigh = blueLight.opacity(0.7)
    static let heatmapMax = blueLight
    
    // Typography
    enum Fonts {
        // Serif for headlines - using New York (San Francisco Serif)
        static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .serif)
        }
        
        // Sans for body/UI
        static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }
        
        // Monospace for data
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
internal enum DashboardNavItem: String, CaseIterable, Identifiable {
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
    @State private var selectedNav: DashboardNavItem = .dashboard
    @State private var metricsStore = UsageMetricsStore.shared
    
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            
            Divider()
                .frame(width: 1)
                .overlay(DashboardTheme.rule)
            
            mainContent
        }
        .background(DashboardTheme.pageBg)
    }
    
    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Masthead with logo
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.sm) {
                if let logoImage = loadBundledLogo() {
                    Image(nsImage: logoImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    // Fallback text masthead
                    Text("AudioWhisper")
                        .font(DashboardTheme.Fonts.serif(18, weight: .semibold))
                        .foregroundStyle(DashboardTheme.sidebarText)
                }
                
                Text("Voice to text")
                    .font(DashboardTheme.Fonts.sans(11, weight: .regular))
                    .foregroundStyle(DashboardTheme.sidebarTextMuted)
                    .tracking(0.5)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, DashboardTheme.Spacing.md)
            .padding(.top, DashboardTheme.Spacing.lg)
            .padding(.bottom, DashboardTheme.Spacing.xl)
            
            // Navigation sections
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
                // Main section
                navSection(items: [.dashboard, .transcripts, .categories])
                
                // Divider with label
                sectionDivider("Settings")
                
                // Settings section
                navSection(items: [.recording, .providers, .preferences, .permissions])
            }
            .padding(.horizontal, DashboardTheme.Spacing.md)
            
            Spacer()
            
            // Stats footer
            if metricsStore.snapshot.totalSessions > 0 {
                statsFooter
            }
        }
        .frame(width: LayoutMetrics.DashboardWindow.sidebarWidth)
        .background(
            LinearGradient(
                colors: [DashboardTheme.sidebarDark, DashboardTheme.sidebarDark.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func navSection(items: [DashboardNavItem]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items, id: \.id) { item in
                navButton(item)
            }
        }
    }
    
    private func sectionDivider(_ label: String) -> some View {
        HStack(spacing: DashboardTheme.Spacing.sm) {
            Rectangle()
                .fill(DashboardTheme.sidebarDivider)
                .frame(height: 1)
                .frame(maxWidth: 20)
            
            Text(label)
                .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                .foregroundStyle(DashboardTheme.sidebarTextFaint)
                .tracking(0.8)
                .textCase(.uppercase)
            
            Rectangle()
                .fill(DashboardTheme.sidebarDivider)
                .frame(height: 1)
        }
        .padding(.vertical, DashboardTheme.Spacing.sm)
        .padding(.horizontal, DashboardTheme.Spacing.sm)
    }
    
    private func navButton(_ item: DashboardNavItem) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedNav = item
            }
        } label: {
            HStack(spacing: DashboardTheme.Spacing.sm + 2) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .regular))
                    .frame(width: 18)
                    .foregroundStyle(selectedNav == item ? DashboardTheme.sidebarLight : DashboardTheme.sidebarTextMuted)
                
                Text(item.rawValue)
                    .font(DashboardTheme.Fonts.sans(13, weight: selectedNav == item ? .medium : .regular))
                    .foregroundStyle(selectedNav == item ? DashboardTheme.sidebarText : DashboardTheme.sidebarTextMuted)
                
                Spacer()
            }
            .padding(.horizontal, DashboardTheme.Spacing.sm)
            .padding(.vertical, DashboardTheme.Spacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedNav == item ? DashboardTheme.sidebarAccentSubtle : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var statsFooter: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.sm) {
            Rectangle()
                .fill(DashboardTheme.sidebarDivider)
                .frame(height: 1)
                .padding(.horizontal, DashboardTheme.Spacing.md)
            
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                Text("Total recorded")
                    .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                    .foregroundStyle(DashboardTheme.sidebarTextFaint)
                    .tracking(0.5)
                    .textCase(.uppercase)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatNumber(metricsStore.snapshot.totalWords))
                        .font(DashboardTheme.Fonts.serif(22, weight: .semibold))
                        .foregroundStyle(DashboardTheme.sidebarText)
                    
                    Text("words")
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.sidebarTextMuted)
                }
            }
            .padding(.horizontal, DashboardTheme.Spacing.lg)
            .padding(.vertical, DashboardTheme.Spacing.md)
        }
    }
    
    // MARK: - Content Switcher
    @ViewBuilder
    private var mainContent: some View {
        switch selectedNav {
        case .dashboard:
            DashboardHomeView(selectedNav: $selectedNav)
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
    
    private func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private func loadBundledLogo() -> NSImage? {
        // Try app bundle Resources folder
        if let resourcePath = Bundle.main.resourcePath {
            let logoPath = (resourcePath as NSString).appendingPathComponent("DashboardLogo.jpg")
            if let image = NSImage(contentsOfFile: logoPath) {
                return image
            }
        }
        
        // Fallback: try loading from bundle directly
        if let url = Bundle.main.url(forResource: "DashboardLogo", withExtension: "jpg"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        
        return nil
    }
}

// MARK: - Preview
#Preview("Dashboard") {
    DashboardView()
        .frame(width: LayoutMetrics.DashboardWindow.previewSize.width,
               height: LayoutMetrics.DashboardWindow.previewSize.height)
}
