import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - DashboardTheme Tests
final class DashboardThemeTests: XCTestCase {

    // MARK: - Color Tests

    func testSidebarColorsAreDefined() {
        XCTAssertNotNil(DashboardTheme.sidebarDark)
        XCTAssertNotNil(DashboardTheme.sidebarLight)
        XCTAssertNotNil(DashboardTheme.sidebarText)
        XCTAssertNotNil(DashboardTheme.sidebarTextMuted)
        XCTAssertNotNil(DashboardTheme.sidebarTextFaint)
        XCTAssertNotNil(DashboardTheme.sidebarDivider)
        XCTAssertNotNil(DashboardTheme.sidebarAccent)
        XCTAssertNotNil(DashboardTheme.sidebarAccentSubtle)
    }

    func testContentColorsAreDefined() {
        XCTAssertNotNil(DashboardTheme.pageBg)
        XCTAssertNotNil(DashboardTheme.cardBg)
        XCTAssertNotNil(DashboardTheme.cardBgAlt)
    }

    func testTextColorsAreDefined() {
        XCTAssertNotNil(DashboardTheme.ink)
        XCTAssertNotNil(DashboardTheme.inkLight)
        XCTAssertNotNil(DashboardTheme.inkMuted)
        XCTAssertNotNil(DashboardTheme.inkFaint)
    }

    func testAccentColorsAreDefined() {
        XCTAssertNotNil(DashboardTheme.accent)
        XCTAssertNotNil(DashboardTheme.accentLight)
        XCTAssertNotNil(DashboardTheme.accentSubtle)
    }

    func testBorderColorsAreDefined() {
        XCTAssertNotNil(DashboardTheme.rule)
        XCTAssertNotNil(DashboardTheme.ruleBold)
    }

    func testProviderColorsAreDefined() {
        XCTAssertNotNil(DashboardTheme.providerOpenAI)
        XCTAssertNotNil(DashboardTheme.providerGemini)
        XCTAssertNotNil(DashboardTheme.providerLocal)
        XCTAssertNotNil(DashboardTheme.providerParakeet)
    }

    func testHeatmapColorsAreDefined() {
        XCTAssertNotNil(DashboardTheme.heatmapEmpty)
        XCTAssertNotNil(DashboardTheme.heatmapLow)
        XCTAssertNotNil(DashboardTheme.heatmapMedium)
        XCTAssertNotNil(DashboardTheme.heatmapHigh)
        XCTAssertNotNil(DashboardTheme.heatmapMax)
    }

    func testSemanticColorsAreDefined() {
        XCTAssertNotNil(DashboardTheme.success)
        XCTAssertNotNil(DashboardTheme.destructive)
    }

    // MARK: - Font Tests

    func testSerifFontReturnsFont() {
        let font = DashboardTheme.Fonts.serif(14)
        XCTAssertNotNil(font)
    }

    func testSerifFontWithWeightReturnsFont() {
        let font = DashboardTheme.Fonts.serif(14, weight: .bold)
        XCTAssertNotNil(font)
    }

    func testSansFontReturnsFont() {
        let font = DashboardTheme.Fonts.sans(14)
        XCTAssertNotNil(font)
    }

    func testSansFontWithWeightReturnsFont() {
        let font = DashboardTheme.Fonts.sans(14, weight: .semibold)
        XCTAssertNotNil(font)
    }

    func testMonoFontReturnsFont() {
        let font = DashboardTheme.Fonts.mono(14)
        XCTAssertNotNil(font)
    }

    func testMonoFontWithWeightReturnsFont() {
        let font = DashboardTheme.Fonts.mono(14, weight: .medium)
        XCTAssertNotNil(font)
    }

    func testFontSizeVariations() {
        let sizes: [CGFloat] = [10, 11, 12, 13, 14, 16, 18, 20, 22, 24, 28, 32]
        for size in sizes {
            XCTAssertNotNil(DashboardTheme.Fonts.serif(size))
            XCTAssertNotNil(DashboardTheme.Fonts.sans(size))
            XCTAssertNotNil(DashboardTheme.Fonts.mono(size))
        }
    }

    // MARK: - Spacing Tests

    func testSpacingValuesAreDefined() {
        XCTAssertEqual(DashboardTheme.Spacing.xs, 4)
        XCTAssertEqual(DashboardTheme.Spacing.sm, 8)
        XCTAssertEqual(DashboardTheme.Spacing.md, 16)
        XCTAssertEqual(DashboardTheme.Spacing.lg, 24)
        XCTAssertEqual(DashboardTheme.Spacing.xl, 32)
        XCTAssertEqual(DashboardTheme.Spacing.xxl, 48)
    }

    func testSpacingValuesAreOrdered() {
        XCTAssertLessThan(DashboardTheme.Spacing.xs, DashboardTheme.Spacing.sm)
        XCTAssertLessThan(DashboardTheme.Spacing.sm, DashboardTheme.Spacing.md)
        XCTAssertLessThan(DashboardTheme.Spacing.md, DashboardTheme.Spacing.lg)
        XCTAssertLessThan(DashboardTheme.Spacing.lg, DashboardTheme.Spacing.xl)
        XCTAssertLessThan(DashboardTheme.Spacing.xl, DashboardTheme.Spacing.xxl)
    }

    func testSpacingValuesAreMultiplesOfFour() {
        XCTAssertEqual(DashboardTheme.Spacing.xs.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DashboardTheme.Spacing.sm.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DashboardTheme.Spacing.md.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DashboardTheme.Spacing.lg.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DashboardTheme.Spacing.xl.truncatingRemainder(dividingBy: 4), 0)
        XCTAssertEqual(DashboardTheme.Spacing.xxl.truncatingRemainder(dividingBy: 4), 0)
    }
}

// MARK: - DashboardNavItem Tests
final class DashboardNavItemTests: XCTestCase {

    func testAllNavItemsHaveRawValue() {
        for item in DashboardNavItem.allCases {
            XCTAssertFalse(item.rawValue.isEmpty)
        }
    }

    func testAllNavItemsHaveUniqueIds() {
        let ids = DashboardNavItem.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count)
    }

    func testAllNavItemsHaveIcons() {
        for item in DashboardNavItem.allCases {
            XCTAssertFalse(item.icon.isEmpty)
        }
    }

    func testNavItemIcons() {
        XCTAssertEqual(DashboardNavItem.dashboard.icon, "square.text.square")
        XCTAssertEqual(DashboardNavItem.transcripts.icon, "doc.text")
        XCTAssertEqual(DashboardNavItem.categories.icon, "folder")
        XCTAssertEqual(DashboardNavItem.recording.icon, "mic.fill")
        XCTAssertEqual(DashboardNavItem.providers.icon, "cpu")
        XCTAssertEqual(DashboardNavItem.visuals.icon, "paintpalette")
        XCTAssertEqual(DashboardNavItem.preferences.icon, "gearshape")
        XCTAssertEqual(DashboardNavItem.permissions.icon, "lock")
    }

    func testNavItemRawValues() {
        XCTAssertEqual(DashboardNavItem.dashboard.rawValue, "Overview")
        XCTAssertEqual(DashboardNavItem.transcripts.rawValue, "Transcripts")
        XCTAssertEqual(DashboardNavItem.categories.rawValue, "Categories")
        XCTAssertEqual(DashboardNavItem.recording.rawValue, "Input")
        XCTAssertEqual(DashboardNavItem.providers.rawValue, "Models")
        XCTAssertEqual(DashboardNavItem.visuals.rawValue, "Visuals")
        XCTAssertEqual(DashboardNavItem.preferences.rawValue, "General")
        XCTAssertEqual(DashboardNavItem.permissions.rawValue, "Permissions")
    }

    func testNavItemIdEqualsRawValue() {
        for item in DashboardNavItem.allCases {
            XCTAssertEqual(item.id, item.rawValue)
        }
    }

    func testNavItemCasesCount() {
        XCTAssertEqual(DashboardNavItem.allCases.count, 8)
    }

    func testNavItemConformsToIdentifiable() {
        for item in DashboardNavItem.allCases {
            let _: any Identifiable = item
            XCTAssertNotNil(item.id)
        }
    }
}

// MARK: - DashboardView Tests
@MainActor
final class DashboardViewTests: XCTestCase {

    func testDashboardViewCanBeCreated() {
        let view = DashboardView()
        XCTAssertNotNil(view)
    }


}

// MARK: - DashboardNavItem Navigation Tests
final class DashboardNavItemNavigationTests: XCTestCase {

    func testMainSectionItems() {
        let mainItems: [DashboardNavItem] = [.dashboard, .transcripts, .categories]
        for item in mainItems {
            XCTAssertTrue(DashboardNavItem.allCases.contains(item))
        }
    }

    func testSettingsSectionItems() {
        let settingsItems: [DashboardNavItem] = [.recording, .providers, .visuals, .preferences, .permissions]
        for item in settingsItems {
            XCTAssertTrue(DashboardNavItem.allCases.contains(item))
        }
    }
}
