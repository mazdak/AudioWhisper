import Foundation
import CallKit
import AVFoundation

/// Manages voice calls using CallKit for native iOS call integration.
/// Handles incoming call reporting and outgoing call initiation.
@MainActor
final class CallManager: NSObject, ObservableObject {
    @Published var activeCallID: UUID?
    @Published var isOnCall = false
    @Published var callStatus: String = ""
    @Published var callerNumber: String = ""

    private let callController = CXCallController()
    private let provider: CXProvider
    private let apiClient = TwilioAPIClient()
    private let keychain = KeychainManager.shared

    static let shared = CallManager()

    override init() {
        let config = CXProviderConfiguration()
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportsVideo = false
        config.supportedHandleTypes = [.phoneNumber]
        config.iconTemplateImageData = nil

        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    // MARK: - Incoming Call

    /// Report an incoming call to CallKit so it shows the native call UI.
    func reportIncomingCall(from phoneNumber: String, callID: UUID = UUID()) async throws {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: phoneNumber)
        update.hasVideo = false
        update.localizedCallerName = phoneNumber.formattedPhoneNumber

        try await provider.reportNewIncomingCall(with: callID, update: update)

        activeCallID = callID
        callerNumber = phoneNumber
        isOnCall = true
        callStatus = "Incoming"
    }

    // MARK: - Outgoing Call

    /// Initiate an outgoing call via Twilio API and report to CallKit.
    func startOutgoingCall(to phoneNumber: String) async throws {
        guard let credentials = keychain.loadCredentials(),
              let myNumber = keychain.loadSelectedPhoneNumber() else {
            throw NetworkError.missingCredentials
        }

        let callID = UUID()
        activeCallID = callID
        callerNumber = phoneNumber
        isOnCall = true
        callStatus = "Calling..."

        // Report to CallKit
        let handle = CXHandle(type: .phoneNumber, value: phoneNumber)
        let startAction = CXStartCallAction(call: callID, handle: handle)
        startAction.isVideo = false

        let transaction = CXTransaction(action: startAction)
        try await callController.request(transaction)

        // Place the call via Twilio REST API
        // Note: For production, you'd use TwilioVoice SDK for real-time audio.
        // This uses the REST API to initiate a call that Twilio bridges.
        do {
            _ = try await apiClient.makeCall(
                credentials: credentials,
                from: myNumber,
                to: phoneNumber,
                twimlURL: "http://demo.twilio.com/docs/voice.xml"
            )
            callStatus = "Connected"

            // Mark as connected in CallKit
            provider.reportOutgoingCall(with: callID, connectedAt: Date())
        } catch {
            callStatus = "Failed"
            endCall()
            throw error
        }
    }

    // MARK: - End Call

    func endCall() {
        guard let callID = activeCallID else { return }

        let endAction = CXEndCallAction(call: callID)
        let transaction = CXTransaction(action: endAction)

        callController.request(transaction) { [weak self] error in
            if let error {
                print("Failed to end call: \(error.localizedDescription)")
            }
            Task { @MainActor [weak self] in
                self?.resetCallState()
            }
        }
    }

    private func resetCallState() {
        activeCallID = nil
        isOnCall = false
        callStatus = ""
        callerNumber = ""
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }

    private func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - CXProviderDelegate

extension CallManager: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            resetCallState()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task { @MainActor in
            configureAudioSession()
            callStatus = "Connecting..."
        }
        action.fulfill()
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { @MainActor in
            configureAudioSession()
            callStatus = "Connected"
        }
        action.fulfill()
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in
            deactivateAudioSession()
            resetCallState()
        }
        action.fulfill()
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        // Handle mute/unmute
        action.fulfill()
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // Audio session activated — start audio playback/recording
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // Audio session deactivated — stop audio
    }
}
