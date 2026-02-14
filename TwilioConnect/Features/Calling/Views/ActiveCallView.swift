import SwiftUI

/// Full-screen view displayed during an active phone call.
struct ActiveCallView: View {
    @ObservedObject var callManager: CallManager
    @State private var callDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isMuted = false
    @State private var isSpeaker = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Caller info
            VStack(spacing: 16) {
                ContactAvatar(phoneNumber: callManager.callerNumber, size: 80)

                Text(callManager.callerNumber.formattedPhoneNumber)
                    .font(.title)
                    .fontWeight(.medium)

                Text(callManager.callStatus)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if callManager.callStatus == "Connected" {
                    Text(formattedDuration)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Call controls
            HStack(spacing: 48) {
                CallControlButton(
                    icon: isMuted ? "mic.slash.fill" : "mic.fill",
                    label: "Mute",
                    isActive: isMuted
                ) {
                    isMuted.toggle()
                }

                CallControlButton(
                    icon: isSpeaker ? "speaker.wave.3.fill" : "speaker.fill",
                    label: "Speaker",
                    isActive: isSpeaker
                ) {
                    isSpeaker.toggle()
                }
            }

            // End call button
            Button {
                callManager.endCall()
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(.red, in: Circle())
            }
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private var formattedDuration: String {
        let minutes = Int(callDuration) / 60
        let seconds = Int(callDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            callDuration += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Call Control Button

private struct CallControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(
                        isActive ? Color.white : Color(.systemGray5),
                        in: Circle()
                    )
                    .foregroundStyle(isActive ? .black : .primary)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActiveCallView(callManager: CallManager.shared)
}
