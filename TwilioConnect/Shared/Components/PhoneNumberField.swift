import SwiftUI

/// A styled text field for phone number input with E.164 formatting hints.
struct PhoneNumberField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("+1 (555) 123-4567", text: $text)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    PhoneNumberField(label: "Phone Number", text: .constant("+14155551234"))
        .padding()
}
