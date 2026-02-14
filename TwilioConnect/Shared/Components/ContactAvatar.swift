import SwiftUI

/// Circular avatar displaying initials derived from a phone number.
struct ContactAvatar: View {
    let phoneNumber: String
    var size: CGFloat = 44

    var body: some View {
        Text(phoneNumber.phoneInitials)
            .font(.system(size: size * 0.38, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(avatarColor, in: Circle())
    }

    /// Deterministic color based on the phone number.
    private var avatarColor: Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan
        ]
        let hash = abs(phoneNumber.hashValue)
        return colors[hash % colors.count]
    }
}

#Preview {
    HStack(spacing: 12) {
        ContactAvatar(phoneNumber: "+14155551234")
        ContactAvatar(phoneNumber: "+14155555678", size: 60)
        ContactAvatar(phoneNumber: "+442071234567", size: 80)
    }
}
