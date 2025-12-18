import Foundation
import AppKit

internal enum PressAndHoldMode: String, CaseIterable, Identifiable {
    case hold
    case toggle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hold:
            return "Press and Hold"
        case .toggle:
            return "Press to Toggle"
        }
    }
}

internal enum PressAndHoldKey: String, CaseIterable, Identifiable {
    case rightCommand
    case leftCommand
    case rightOption
    case leftOption
    case rightControl
    case leftControl
    case globe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rightCommand:
            return "Right Command (⌘)"
        case .leftCommand:
            return "Left Command (⌘)"
        case .rightOption:
            return "Right Option (⌥)"
        case .leftOption:
            return "Left Option (⌥)"
        case .rightControl:
            return "Right Control (⌃)"
        case .leftControl:
            return "Left Control (⌃)"
        case .globe:
            return "Globe / Fn (🌐)"
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .rightCommand:
            return 54
        case .leftCommand:
            return 55
        case .rightOption:
            return 61
        case .leftOption:
            return 58
        case .rightControl:
            return 62
        case .leftControl:
            return 59
        case .globe:
            return 63
        }
    }

    /// Modifier flag that macOS sets when the key is active.
    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .rightCommand, .leftCommand:
            return .command
        case .rightOption, .leftOption:
            return .option
        case .rightControl, .leftControl:
            return .control
        case .globe:
            return .function
        }
    }
}

internal struct PressAndHoldConfiguration: Equatable {
    var enabled: Bool
    var key: PressAndHoldKey
    var mode: PressAndHoldMode

    static let defaults = PressAndHoldConfiguration(
        enabled: false,
        key: .rightCommand,
        mode: .hold
    )
}

internal enum PressAndHoldSettings {
    private static let enabledKey = "pressAndHoldEnabled"
    private static let keyIdentifierKey = "pressAndHoldKeyIdentifier"
    private static let modeKey = "pressAndHoldMode"

    static func configuration(using defaults: UserDefaults = .standard) -> PressAndHoldConfiguration {
        let enabled = defaults.object(forKey: enabledKey) as? Bool ?? PressAndHoldConfiguration.defaults.enabled
        let keyIdentifier = defaults.string(forKey: keyIdentifierKey) ?? PressAndHoldConfiguration.defaults.key.rawValue
        let modeIdentifier = defaults.string(forKey: modeKey) ?? PressAndHoldConfiguration.defaults.mode.rawValue

        let key = PressAndHoldKey(rawValue: keyIdentifier) ?? legacyKey(from: keyIdentifier) ?? PressAndHoldConfiguration.defaults.key
        let mode = PressAndHoldMode(rawValue: modeIdentifier) ?? PressAndHoldConfiguration.defaults.mode

        return PressAndHoldConfiguration(enabled: enabled, key: key, mode: mode)
    }

    static func update(_ configuration: PressAndHoldConfiguration, using defaults: UserDefaults = .standard) {
        defaults.set(configuration.enabled, forKey: enabledKey)
        defaults.set(configuration.key.rawValue, forKey: keyIdentifierKey)
        defaults.set(configuration.mode.rawValue, forKey: modeKey)
        defaults.synchronize()

        NotificationCenter.default.post(name: .pressAndHoldSettingsChanged, object: configuration)
    }

    private static func legacyKey(from rawValue: String) -> PressAndHoldKey? {
        switch rawValue {
        case "option":
            return .leftOption
        case "control":
            return .leftControl
        case "fn", "globe":
            return .globe
        default:
            return nil
        }
    }
}

/// Observes global keyboard events so that modifier-only keys (e.g. right command)
/// can trigger recording. Uses NSEvent global monitors, which continue to fire even
/// when the app is not focused.
internal final class PressAndHoldKeyMonitor {
    typealias EventMonitorFactory = (NSEvent.EventTypeMask, @escaping (NSEvent) -> Void) -> Any?
    typealias EventMonitorRemoval = (Any) -> Void

    private let configuration: PressAndHoldConfiguration
    private let keyDownHandler: () -> Void
    private let keyUpHandler: (() -> Void)?
    private let addGlobalMonitor: EventMonitorFactory
    private let removeMonitor: EventMonitorRemoval

    private var flagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private let monitorQueue = DispatchQueue(label: "com.audiowhisper.pressAndHoldMonitor")

    private var isPressed = false

    init(
        configuration: PressAndHoldConfiguration,
        keyDownHandler: @escaping () -> Void,
        keyUpHandler: (() -> Void)? = nil,
        addGlobalMonitor: @escaping EventMonitorFactory = NSEvent.addGlobalMonitorForEvents(matching:handler:),
        removeMonitor: @escaping EventMonitorRemoval = NSEvent.removeMonitor(_:)
    ) {
        self.configuration = configuration
        self.keyDownHandler = keyDownHandler
        self.keyUpHandler = keyUpHandler
        self.addGlobalMonitor = addGlobalMonitor
        self.removeMonitor = removeMonitor
    }

    func start() {
        stop()

        let modifierFlag = configuration.key.modifierFlag
        if modifierFlag == .command || modifierFlag == .option || modifierFlag == .control || modifierFlag == .function {
            flagsMonitor = addGlobalMonitor(.flagsChanged) { [weak self] event in
                self?.handleModifierEvent(event)
            }
        } else {
            keyDownMonitor = addGlobalMonitor(.keyDown) { [weak self] event in
                self?.handleKeyEvent(event, isKeyDown: true)
            }
            keyUpMonitor = addGlobalMonitor(.keyUp) { [weak self] event in
                self?.handleKeyEvent(event, isKeyDown: false)
            }
        }
    }

    func stop() {
        if let monitor = flagsMonitor {
            removeMonitor(monitor)
            flagsMonitor = nil
        }
        if let monitor = keyDownMonitor {
            removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = keyUpMonitor {
            removeMonitor(monitor)
            keyUpMonitor = nil
        }
        isPressed = false
    }

    deinit {
        stop()
    }

    private func handleModifierEvent(_ event: NSEvent) {
        guard event.type == .flagsChanged, event.keyCode == configuration.key.keyCode else { return }

        monitorQueue.async { [weak self] in
            self?.processTransition(isKeyDownEvent: !(self?.isPressed ?? false))
        }
    }

    private func handleKeyEvent(_ event: NSEvent, isKeyDown: Bool) {
        guard event.keyCode == configuration.key.keyCode else { return }

        if isKeyDown, event.isARepeat {
            return
        }

        monitorQueue.async { [weak self] in
            self?.processTransition(isKeyDownEvent: isKeyDown)
        }
    }

    func processTransition(isKeyDownEvent: Bool) {
        if isKeyDownEvent {
            guard !isPressed else { return }
            isPressed = true
            Task { @MainActor [keyDownHandler] in
                keyDownHandler()
            }
        } else {
            guard isPressed else { return }
            isPressed = false
            guard let keyUpHandler else { return }
            Task { @MainActor in
                keyUpHandler()
            }
        }
    }
}
