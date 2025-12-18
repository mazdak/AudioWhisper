import SwiftUI

// MARK: - Section Card
internal struct SettingsSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    init(
        title: String,
        icon: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            // Section header
            Text(title)
                .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                .foregroundStyle(DashboardTheme.inkMuted)
                .tracking(0.8)
                .textCase(.uppercase)
            
            // Content card
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
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
}

// MARK: - Toggle Row
internal struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: DashboardTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                Text(title)
                    .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                    .foregroundStyle(DashboardTheme.ink)
                
                if let subtitle {
                    Text(subtitle)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(DashboardTheme.accent)
                .labelsHidden()
        }
        .padding(DashboardTheme.Spacing.md)
    }
}

// MARK: - Picker Row
internal struct SettingsPickerRow<Selection: Hashable>: View {
    let title: String
    let subtitle: String?
    @Binding var selection: Selection
    let options: [Selection]
    let display: (Selection) -> String
    
    init(
        title: String,
        subtitle: String? = nil,
        selection: Binding<Selection>,
        options: [Selection],
        display: @escaping (Selection) -> String = { "\($0)" }
    ) {
        self.title = title
        self.subtitle = subtitle
        _selection = selection
        self.options = options
        self.display = display
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: DashboardTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                Text(title)
                    .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                    .foregroundStyle(DashboardTheme.ink)
                
                if let subtitle {
                    Text(subtitle)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
            }
            
            Spacer()
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        HStack {
                            Text(display(option))
                            if option == selection {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: DashboardTheme.Spacing.xs) {
                    Text(display(selection))
                        .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                .padding(.horizontal, DashboardTheme.Spacing.sm + 2)
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
}

// MARK: - Button Row
internal struct SettingsButtonRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let role: ButtonRole?
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String = "arrow.right",
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.role = role
        self.action = action
    }
    
    var body: some View {
        Button(role: role, action: action) {
            HStack(alignment: .center, spacing: DashboardTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                    Text(title)
                        .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                        .foregroundStyle(role == .destructive ? DashboardTheme.destructive : DashboardTheme.ink)
                    
                    if let subtitle {
                        Text(subtitle)
                            .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }
                }
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(role == .destructive ? DashboardTheme.destructive : DashboardTheme.inkMuted)
            }
            .padding(DashboardTheme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Row
internal struct SettingsInfoRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: DashboardTheme.Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.inkFaint)
            
            Text(text)
                .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
        }
        .padding(DashboardTheme.Spacing.md)
    }
}

// MARK: - Text Field Row
internal struct SettingsTextFieldRow: View {
    let title: String
    let subtitle: String?
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                Text(title)
                    .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                    .foregroundStyle(DashboardTheme.ink)
                
                if let subtitle {
                    Text(subtitle)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(DashboardTheme.Fonts.sans(13, weight: .regular))
            .padding(DashboardTheme.Spacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(DashboardTheme.cardBgAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
        }
        .padding(DashboardTheme.Spacing.md)
    }
}
