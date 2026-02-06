import SwiftUI

internal final class DashboardSelectionModel: ObservableObject {
    @Published var selectedNav: DashboardNavItem? = .dashboard
}
