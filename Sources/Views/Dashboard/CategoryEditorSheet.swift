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
        VStack(spacing: 0) {
            header
            
            ScrollView {
                VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xl) {
                    previewCard
                    identitySection
                    appearanceSection
                    correctionSection
                    
                    if let error = validationError {
                        errorBanner(error)
                    }
                    
                    actionButtons
                }
                .padding(DashboardTheme.Spacing.xl)
            }
        }
        .frame(width: 560, height: 680)
        .background(DashboardTheme.pageBg)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text(isNewCategory ? "New Category" : "Edit Category")
                .font(DashboardTheme.Fonts.serif(20, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(DashboardTheme.inkMuted)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, DashboardTheme.Spacing.xl)
        .padding(.vertical, DashboardTheme.Spacing.md)
        .background(DashboardTheme.cardBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DashboardTheme.rule).frame(height: 1)
        }
    }
    
    // MARK: - Preview Card
    
    private var previewCard: some View {
        HStack(spacing: DashboardTheme.Spacing.md) {
            Image(systemName: icon.isEmpty ? "questionmark" : icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(accentColor, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: accentColor.opacity(0.4), radius: 8, y: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName.isEmpty ? "Category Name" : displayName)
                    .font(DashboardTheme.Fonts.serif(18, weight: .semibold))
                    .foregroundStyle(DashboardTheme.ink)
                
                Text(identifier.isEmpty ? "identifier" : identifier)
                    .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            
            Spacer()
            
            if isSystem {
                Text("System")
                    .font(DashboardTheme.Fonts.sans(10, weight: .semibold))
                    .foregroundStyle(DashboardTheme.inkMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DashboardTheme.rule, in: Capsule())
            }
        }
        .padding(DashboardTheme.Spacing.lg)
        .background(DashboardTheme.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(DashboardTheme.rule, lineWidth: 1)
        )
    }
    
    // MARK: - Sections
    
    private var identitySection: some View {
        formSection("Identity") {
            formField("Display Name") {
                TextField("e.g. Terminal", text: $displayName)
                    .textFieldStyle(.plain)
                    .font(DashboardTheme.Fonts.sans(14, weight: .regular))
                    .padding(12)
                    .background(DashboardTheme.pageBg, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(DashboardTheme.rule, lineWidth: 1)
                    )
            }
            
            formField("Identifier") {
                TextField("e.g. terminal", text: $identifier)
                    .textFieldStyle(.plain)
                    .font(DashboardTheme.Fonts.mono(14, weight: .regular))
                    .padding(12)
                    .background(DashboardTheme.pageBg, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(DashboardTheme.rule, lineWidth: 1)
                    )
                    .disabled(isSystem)
                    .opacity(isSystem ? 0.6 : 1)
                
                if isSystem {
                    Text("System category identifiers cannot be changed")
                        .font(DashboardTheme.Fonts.sans(11, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkFaint)
                }
            }
        }
    }
    
    private var appearanceSection: some View {
        formSection("Appearance") {
            HStack(alignment: .top, spacing: DashboardTheme.Spacing.xl) {
                formField("Icon") {
                    HStack(spacing: DashboardTheme.Spacing.sm) {
                        Image(systemName: icon.isEmpty ? "questionmark" : icon)
                            .font(.system(size: 16))
                            .foregroundStyle(accentColor)
                            .frame(width: 40, height: 40)
                            .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        
                        TextField("SF Symbol", text: $icon)
                            .textFieldStyle(.plain)
                            .font(DashboardTheme.Fonts.mono(13, weight: .regular))
                            .padding(10)
                            .frame(width: 140)
                            .background(DashboardTheme.pageBg, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(DashboardTheme.rule, lineWidth: 1)
                            )
                    }
                }
                
                formField("Color") {
                    HStack(spacing: DashboardTheme.Spacing.sm) {
                        ColorPicker("", selection: $accentColor, supportsOpacity: false)
                            .labelsHidden()
                        
                        Text(accentColor.hexString() ?? "#000000")
                            .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var correctionSection: some View {
        formSection("Correction Behavior") {
            formField("Description") {
                TextField("Brief summary for category list", text: $promptDescription, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                    .lineLimit(2...3)
                    .padding(12)
                    .background(DashboardTheme.pageBg, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(DashboardTheme.rule, lineWidth: 1)
                    )
            }
            
            formField("Prompt Template") {
                TextEditor(text: $promptTemplate)
                    .font(DashboardTheme.Fonts.mono(12, weight: .regular))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 160)
                    .background(DashboardTheme.pageBg, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(DashboardTheme.rule, lineWidth: 1)
                    )
                
                Text("Instructions sent to the correction model for this category")
                    .font(DashboardTheme.Fonts.sans(11, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkFaint)
            }
        }
    }
    
    // MARK: - Actions
    
    private var actionButtons: some View {
        HStack(spacing: DashboardTheme.Spacing.md) {
            Button {
                save()
            } label: {
                Text("Save Category")
                    .font(DashboardTheme.Fonts.sans(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(DashboardTheme.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(displayName.isEmpty)
            .opacity(displayName.isEmpty ? 0.5 : 1)
            
            if !isNewCategory && !isSystem, let onDelete {
                Button {
                    onDelete()
                    dismiss()
                } label: {
                    Text("Delete")
                        .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                .foregroundStyle(DashboardTheme.ink)
        }
        .padding(DashboardTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Helpers
    
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            Text(title.uppercased())
                .font(DashboardTheme.Fonts.sans(10, weight: .bold))
                .foregroundStyle(DashboardTheme.inkMuted)
                .tracking(1.2)
            
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
                content()
            }
            .padding(DashboardTheme.Spacing.lg)
            .background(DashboardTheme.cardBg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(DashboardTheme.rule, lineWidth: 1)
            )
        }
    }
    
    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(DashboardTheme.Fonts.sans(12, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
            
            content()
        }
    }
    
    private func save() {
        // Validate
        let trimmedId = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            validationError = "Display name is required"
            return
        }
        
        // Check for duplicate ID (only if ID changed or new category)
        let originalId = originalCategory?.id
        if trimmedId != originalId && categoryStore.containsCategory(withId: trimmedId) {
            validationError = "A category with this identifier already exists"
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
