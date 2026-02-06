import SwiftUI
import Observation

internal struct DashboardCategoriesView: View {
    @State private var categoryManager = AppCategoryManager.shared
    @State private var categoryStore = CategoryStore.shared
    @State private var sourceUsageStore = SourceUsageStore.shared

    @State private var editingCategory: CategoryDefinition?
    @State private var isCreatingNew = false
    
    private var topSources: [SourceUsageStats] {
        sourceUsageStore.topSources(limit: 10)
    }

    var body: some View {
        Form {
            Section("Category Types") {
                ForEach(categoryStore.categories, id: \.id) { category in
                    Button {
                        editingCategory = category
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(category.displayName)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)

                                    if category.isSystem {
                                        Text("System")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(category.promptDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Edit \(category.displayName)")
                }

                HStack(spacing: 10) {
                    Button {
                        isCreatingNew = true
                    } label: {
                        Label("New Category…", systemImage: "plus")
                    }

                    Spacer()

                    Button("Reset to Defaults") {
                        categoryStore.resetToDefaults()
                    }
                }
            }

            Section {
                if topSources.isEmpty {
                    Text("No apps recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(topSources) { source in
                        LabeledContent {
                            HStack(spacing: 8) {
                                Picker("", selection: categoryBinding(for: source.bundleIdentifier)) {
                                    ForEach(categoryStore.categories, id: \.id) { category in
                                        Text(category.displayName).tag(category.id)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                if categoryManager.isUserOverridden(source.bundleIdentifier) {
                                    Button("Reset") {
                                        categoryManager.resetToDefault(for: source.bundleIdentifier)
                                    }
                                    .controlSize(.small)
                                }
                            }
                        } label: {
                            AppLabel(source: source)
                        }
                        .contextMenu {
                            if categoryManager.isUserOverridden(source.bundleIdentifier) {
                                Button("Reset to Default") {
                                    categoryManager.resetToDefault(for: source.bundleIdentifier)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("App Assignments")
            } footer: {
                Text("Assignments are applied automatically when you paste a finished transcript.")
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingCategory) { category in
            NavigationStack {
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
        }
        .sheet(isPresented: $isCreatingNew) {
            NavigationStack {
                CategoryEditorSheet(
                    category: nil,
                    categoryStore: categoryStore,
                    onSave: { newCategory in
                        categoryStore.upsert(newCategory)
                    }
                )
            }
        }
    }

    private func categoryBinding(for bundleId: String) -> Binding<String> {
        Binding(
            get: { categoryManager.categoryId(for: bundleId) },
            set: { newId in
                categoryManager.setCategory(id: newId, for: bundleId)
            }
        )
    }
}

private struct AppLabel: View {
    let source: SourceUsageStats

    var body: some View {
        HStack(spacing: 10) {
            appIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .lineLimit(1)

                Text(source.bundleIdentifier)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var appIcon: some View {
        Group {
            if let image = source.nsImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                    .overlay(
                        Text(source.initials.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    DashboardCategoriesView()
        .frame(width: 900, height: 700)
}
