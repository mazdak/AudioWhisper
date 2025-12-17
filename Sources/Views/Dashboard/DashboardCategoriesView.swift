import SwiftUI
import Observation

internal struct DashboardCategoriesView: View {
    @State private var categoryManager = AppCategoryManager.shared
    @State private var categoryStore = CategoryStore.shared
    @State private var sourceUsageStore = SourceUsageStore.shared
    @State private var editingCategory: CategoryDefinition?
    @State private var isCreatingNew = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xl) {
                pageHeader
                categoriesOverview
                appMappingsSection
            }
            .padding(DashboardTheme.Spacing.xl)
        }
        .background(DashboardTheme.pageBg)
        .environment(\.colorScheme, .light)
        .sheet(item: $editingCategory) { category in
            CategoryEditorSheet(
                category: category,
                categoryStore: categoryStore,
                onSave: { updated in
                    categoryStore.upsert(updated)
                },
                onDelete: {
                    categoryStore.delete(category)
                }
            )
        }
        .sheet(isPresented: $isCreatingNew) {
            CategoryEditorSheet(
                category: nil,
                categoryStore: categoryStore,
                onSave: { newCategory in
                    categoryStore.upsert(newCategory)
                }
            )
        }
    }
    
    // MARK: - Header
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
            Text("Categories")
                .font(DashboardTheme.Fonts.serif(28, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
            
            Text("Customize how transcriptions are corrected per app")
                .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
        }
    }
    
    // MARK: - Categories Overview
    private var categoriesOverview: some View {
        let categories = categoryStore.categories
        return VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            HStack {
                sectionHeader("Category Types")
                Spacer()
                
                Button {
                    isCreatingNew = true
                } label: {
                    Label("New Category", systemImage: "plus")
                        .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(DashboardTheme.accent)
                
                Button {
                    categoryStore.resetToDefaults()
                } label: {
                    Text("Reset")
                        .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(categories, id: \.id) { category in
                    categoryRow(category)
                    
                    if category.id != categories.last?.id {
                        Divider().background(DashboardTheme.rule)
                    }
                }
            }
            .cardStyle()
        }
    }
    
    private func categoryRow(_ category: CategoryDefinition) -> some View {
        Button {
            editingCategory = category
        } label: {
            HStack(alignment: .center, spacing: DashboardTheme.Spacing.md) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(category.color, in: RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                    HStack(spacing: DashboardTheme.Spacing.sm) {
                        Text(category.displayName)
                            .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                            .foregroundStyle(DashboardTheme.ink)
                        
                        if category.isSystem {
                            Text("System")
                                .font(DashboardTheme.Fonts.sans(9, weight: .medium))
                                .foregroundStyle(DashboardTheme.inkMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DashboardTheme.rule, in: Capsule())
                        }
                    }
                    
                    Text(category.promptDescription)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardTheme.inkFaint)
            }
            .padding(DashboardTheme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - App Mappings
    private var appMappingsSection: some View {
        let topSources = sourceUsageStore.topSources(limit: 10)
        
        return VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("App Assignments")
            
            if topSources.isEmpty {
                VStack(spacing: DashboardTheme.Spacing.md) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(DashboardTheme.inkFaint)
                    
                    VStack(spacing: DashboardTheme.Spacing.xs) {
                        Text("No apps recorded yet")
                            .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                            .foregroundStyle(DashboardTheme.inkLight)
                        
                        Text("Use AudioWhisper in different apps to customize their categories")
                            .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DashboardTheme.Spacing.xxl)
                .cardStyle()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(topSources) { source in
                        appMappingRow(source)
                        
                        if source.id != topSources.last?.id {
                            Divider().background(DashboardTheme.rule)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }
    
    private func appMappingRow(_ source: SourceUsageStats) -> some View {
        let currentCategory = categoryManager.category(for: source.bundleIdentifier)
        let isOverridden = categoryManager.isUserOverridden(source.bundleIdentifier)
        
        return HStack(spacing: DashboardTheme.Spacing.md) {
            // App icon
            Group {
                if let image = source.nsImage() {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DashboardTheme.rule)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(source.initials.uppercased())
                                .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                                .foregroundStyle(DashboardTheme.inkMuted)
                        )
                }
            }
            
            // App name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DashboardTheme.Spacing.xs) {
                    Text(source.displayName)
                        .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)
                    
                    if isOverridden {
                        Text("Custom")
                            .font(DashboardTheme.Fonts.sans(9, weight: .medium))
                            .foregroundStyle(DashboardTheme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(DashboardTheme.accentLight)
                            )
                    }
                }
                
                Text(source.bundleIdentifier)
                    .font(DashboardTheme.Fonts.mono(10, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkFaint)
            }
            
            Spacer()
            
            // Category picker
            Menu {
                ForEach(categoryStore.categories, id: \.id) { category in
                    Button {
                        categoryManager.setCategory(category, for: source.bundleIdentifier)
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                            if currentCategory.id == category.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if isOverridden {
                    Divider()
                    Button("Reset to Default") {
                        categoryManager.resetToDefault(for: source.bundleIdentifier)
                    }
                }
            } label: {
                HStack(spacing: DashboardTheme.Spacing.xs) {
                    Image(systemName: currentCategory.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(currentCategory.color)
                    
                    Text(currentCategory.displayName)
                        .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                .padding(.horizontal, DashboardTheme.Spacing.sm)
                .padding(.vertical, DashboardTheme.Spacing.xs + 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DashboardTheme.cardBgAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DashboardTheme.rule, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
        }
        .padding(DashboardTheme.Spacing.md)
    }
    
    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
            .foregroundStyle(DashboardTheme.inkMuted)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}

// MARK: - Card Style
private extension View {
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(DashboardTheme.cardBg)
                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
    }
}

#Preview {
    DashboardCategoriesView()
        .frame(width: 700, height: 600)
}
