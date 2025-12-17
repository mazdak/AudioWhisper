import AppKit

@MainActor
internal class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hotKeyManager: HotKeyManager?
    var keyboardEventHandler: KeyboardEventHandler?
    var windowController = WindowController()
    weak var recordingWindow: NSWindow?
    var recordingWindowDelegate: RecordingWindowDelegate?
    var audioRecorder: AudioRecorder?
    var recordingAnimationTimer: DispatchSourceTimer?
    var pressAndHoldMonitor: PressAndHoldKeyMonitor?
    var pressAndHoldConfiguration = PressAndHoldSettings.configuration()
    var isHoldRecordingActive = false

    enum HotkeyTriggerSource {
        case standardHotkey
        case pressAndHold
    }
}
