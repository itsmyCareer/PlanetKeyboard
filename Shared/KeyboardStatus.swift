import Foundation

/// How the keyboard vibrates on a key tap.
enum HapticMethod: String, Codable, CaseIterable, Identifiable {
    /// `UIImpactFeedbackGenerator` (the documented API).
    case standard
    /// The system "peek"/"pop" vibration (`AudioServicesPlaySystemSound`).
    case system

    var id: String { rawValue }

    static let peekSound: UInt32 = 1519
    static let popSound: UInt32 = 1520
}

/// What the keyboard extension last saw, written to the App Group so the app can show it.
/// The extension can only write here with "Allow Full Access", so a missing report usually
/// means Full Access is off (or the keyboard has not been opened since installing).
enum KeyboardStatus {
    private typealias Key = AppConstants.UserDefaultsKey

    struct Snapshot {
        let fullAccess: Bool
        let hapticsEnabled: Bool
        let method: HapticMethod
        let seenAt: Date
        let lastHapticAt: Date?
    }

    /// Called by the keyboard each time it appears.
    static func report(fullAccess: Bool, hapticsEnabled: Bool, method: HapticMethod) {
        let defaults = AppGroup.userDefaults
        defaults.set(fullAccess, forKey: Key.statusFullAccess)
        defaults.set(hapticsEnabled, forKey: Key.statusHapticsEnabled)
        defaults.set(method.rawValue, forKey: Key.statusMethod)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.statusSeenAt)
    }

    /// Called by the keyboard on the first haptic it plays after appearing.
    static func reportHaptic() {
        AppGroup.userDefaults.set(Date().timeIntervalSince1970, forKey: Key.statusLastHapticAt)
    }

    static func load() -> Snapshot? {
        let defaults = AppGroup.userDefaults
        let seen = defaults.double(forKey: Key.statusSeenAt)
        guard seen > 0 else { return nil }
        let haptic = defaults.double(forKey: Key.statusLastHapticAt)
        return Snapshot(
            fullAccess: defaults.bool(forKey: Key.statusFullAccess),
            hapticsEnabled: defaults.object(forKey: Key.statusHapticsEnabled) as? Bool ?? true,
            method: HapticMethod(rawValue: defaults.string(forKey: Key.statusMethod) ?? "") ?? .standard,
            seenAt: Date(timeIntervalSince1970: seen),
            lastHapticAt: haptic > 0 ? Date(timeIntervalSince1970: haptic) : nil
        )
    }
}
