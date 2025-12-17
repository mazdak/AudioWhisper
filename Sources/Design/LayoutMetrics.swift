import CoreGraphics

/// Centralized layout metrics to avoid scattered magic numbers.
internal enum LayoutMetrics {
    enum RecordingWindow {
        static let size = CGSize(width: 220, height: 200)
        static let cornerRadius: CGFloat = 16
    }
    
    enum DashboardWindow {
        static let initialSize = CGSize(width: 950, height: 700)
        static let minimumSize = CGSize(width: 800, height: 550)
        static let previewSize = CGSize(width: 900, height: 700)
        static let sidebarWidth: CGFloat = 200
    }
    
    enum TranscriptionHistory {
        static let minimumSize = CGSize(width: 700, height: 400)
        static let previewSize = CGSize(width: 700, height: 500)
    }
    
    enum Welcome {
        static let windowSize = CGSize(width: 600, height: 650)
    }
}
