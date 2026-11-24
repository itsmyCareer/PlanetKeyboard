import UIKit

final class HapticManager {
    static let shared = HapticManager()

    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var isEnabled: Bool = true
    /// iOS only plays keyboard haptics when the user granted "Allow Full Access".
    var hasFullAccess: Bool = false

    private init() {}

    func activateIfNeeded() {
        if lightGenerator == nil {
            lightGenerator = UIImpactFeedbackGenerator(style: .light)
            mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
        }
        lightGenerator?.prepare()
        mediumGenerator?.prepare()
    }

    func suspend() {
        lightGenerator = nil
        mediumGenerator = nil
    }

    func prepare() {
        guard hasFullAccess else { return }
        activateIfNeeded()
    }

    func triggerKeyTap() {
        guard isEnabled, hasFullAccess else { return }
        activateIfNeeded()
        lightGenerator?.impactOccurred()
    }

    func triggerSpecialKey() {
        guard isEnabled, hasFullAccess else { return }
        activateIfNeeded()
        mediumGenerator?.impactOccurred()
    }

    func updateEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func loadSettings() {
        let defaults = AppGroup.userDefaults
        // Default to true if key doesn't exist
        if defaults.object(forKey: AppConstants.UserDefaultsKey.hapticFeedback) == nil {
            isEnabled = true
        } else {
            isEnabled = defaults.bool(forKey: AppConstants.UserDefaultsKey.hapticFeedback)
        }
    }
}
