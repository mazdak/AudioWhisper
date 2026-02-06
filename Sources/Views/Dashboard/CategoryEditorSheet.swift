import SwiftUI

internal struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let categoryStore: CategoryStore
    let originalCategory: CategoryDefinition?
    let onSave: (CategoryDefinition) -> Void
    let onDelete: (() -> Void)?

    @State private var displayName: String
    @State private var identifier: String
    @State private var icon: String
    @State private var accentColor: Color
    @State private var promptDescription: String
    @State private var promptTemplate: String
    @State private var validationError: String?

    private let isNewCategory: Bool
    private let isSystem: Bool

    init(
        category: CategoryDefinition?,
        categoryStore: CategoryStore = .shared,
        onSave: @escaping (CategoryDefinition) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.categoryStore = categoryStore
        self.originalCategory = category
        self.onSave = onSave
        self.onDelete = onDelete
        self.isNewCategory = category == nil
        self.isSystem = category?.isSystem ?? false

        let cat = category ?? CategoryDefinition(
            id: "new-category",
            displayName: "New Category",
            icon: "sparkles",
            colorHex: "#888888",
            promptDescription: "Describe this category's purpose",
            promptTemplate: CategoryDefinition.fallback.promptTemplate,
            isSystem: false
        )

        _displayName = State(initialValue: cat.displayName)
        _identifier = State(initialValue: cat.id)
        _icon = State(initialValue: cat.icon)
        _accentColor = State(initialValue: cat.color)
        _promptDescription = State(initialValue: cat.promptDescription)
        _promptTemplate = State(initialValue: cat.promptTemplate)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: icon.isEmpty ? "questionmark" : icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName.isEmpty ? "Category Name" : displayName)
                            .font(.headline)
                            .lineLimit(1)

                        Text(identifier.isEmpty ? "identifier" : identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }

                    Spacer(minLength: 0)

                    if isSystem {
                        Text("System")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Identity") {
                TextField("Display Name", text: $displayName)

                TextField("Identifier", text: $identifier)
                    .disabled(isSystem)

                if isSystem {
                    Text("System category identifiers can’t be changed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                TextField("Icon (SF Symbol)", text: $icon)

                ColorPicker("Color", selection: $accentColor, supportsOpacity: false)
            }

            Section("Correction") {
                TextField("Description", text: $promptDescription, axis: .vertical)
                    .lineLimit(2...3)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Prompt Template")
                        .font(.subheadline.weight(.semibold))

                    TextEditor(text: $promptTemplate)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )

                    Text("Instructions sent to the correction model for this category.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let validationError {
                Section {
                    Text(validationError)
                        .foregroundStyle(Color(nsColor: .systemRed))
                }
            }

            if !isNewCategory && !isSystem, let onDelete {
                Section {
                    Button("Delete Category", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(isNewCategory ? "New Category" : "Edit Category")
        .frame(width: 560, height: 680)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isNewCategory ? "Add" : "Save") {
                    save()
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        validationError = nil

        let trimmedId = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            validationError = "Display name is required."
            return
        }

        // Check for duplicate ID (only if ID changed or new category).
        let originalId = originalCategory?.id
        if trimmedId != originalId && categoryStore.containsCategory(withId: trimmedId) {
            validationError = "A category with this identifier already exists."
            return
        }

        let category = CategoryDefinition(
            id: isSystem ? (originalCategory?.id ?? trimmedId) : trimmedId,
            displayName: trimmedName,
            icon: icon.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: accentColor.hexString() ?? "#888888",
            promptDescription: promptDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            promptTemplate: promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines),
            isSystem: isSystem
        )

        onSave(category)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CategoryEditorSheet(category: CategoryDefinition.fallback, onSave: { _ in })
    }
}
