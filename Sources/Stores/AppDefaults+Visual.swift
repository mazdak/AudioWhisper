import Foundation

/// UI/visual state: waveform style, visual intensity, menu bar icon size.
extension AppDefaults {

    // MARK: - Visual Settings

    static var waveformStyle: WaveformStyle {
        get {
            guard let rawValue = defaults.string(forKey: Key.waveformStyle.rawValue),
                  let style = WaveformStyle(rawValue: rawValue) else {
                return .classic
            }
            return style
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.waveformStyle.rawValue)
        }
    }

    static var visualIntensity: VisualIntensity {
        get {
            guard let rawValue = defaults.string(forKey: Key.visualIntensity.rawValue),
                  let intensity = VisualIntensity(rawValue: rawValue) else {
                return .balanced
            }
            return intensity
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.visualIntensity.rawValue)
        }
    }

    static var menuBarIconSize: Double? {
        get { defaults.object(forKey: Key.menuBarIconSize.rawValue) as? Double }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Key.menuBarIconSize.rawValue)
            } else {
                defaults.removeObject(forKey: Key.menuBarIconSize.rawValue)
            }
        }
    }
}
