import UIKit

/// Key-tap haptics. iOS only plays them for a keyboard with "Allow Full Access".
///
/// Generators are attached to the keyboard's view (`init(style:view:)`, iOS 17.5+): the
/// view-less initializer is deprecated, and a generator that belongs to no view/window may stay
/// silent inside a keyboard extension.
final class HapticManager {
    static let shared = HapticManager()

    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var isEnabled: Bool = true
    /// iOS only plays keyboard haptics when the user granted "Allow Full Access".
    var hasFullAccess: Bool = false
    /// The view the generators belong to (the keyboard's root view).
    private weak var view: UIView?

    private init() {}

    /// Attach the generators to the keyboard's view (call once the view exists).
    func attach(to view: UIView) {
        guard self.view !== view else { return }
        self.view = view
        suspend()   // recreated for the new view on the next tap
    }

    func activateIfNeeded() {
        if lightGenerator == nil {
            lightGenerator = makeGenerator(.light)
            mediumGenerator = makeGenerator(.medium)
        }
        lightGenerator?.prepare()
        mediumGenerator?.prepare()
    }

    func suspend() {
        lightGenerator = nil
        mediumGenerator = nil
    }

    func prepare() {
        guard isEnabled, hasFullAccess else { return }
        activateIfNeeded()
    }

    func triggerKeyTap() {
        guard isEnabled, hasFullAccess else { return }
        activateIfNeeded()
        lightGenerator?.impactOccurred()
        lightGenerator?.prepare()
    }

    func triggerSpecialKey() {
        guard isEnabled, hasFullAccess else { return }
        activateIfNeeded()
        mediumGenerator?.impactOccurred()
        mediumGenerator?.prepare()
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

    private func makeGenerator(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if #available(iOS 17.5, *), let view {
            return UIImpactFeedbackGenerator(style: style, view: view)
        }
        return UIImpactFeedbackGenerator(style: style)
    }
}
