import AudioToolbox
import OSLog
import UIKit

/// Key-tap haptics. iOS only plays them for a keyboard with "Allow Full Access".
///
/// Two methods, picked in the app (`HapticMethod`):
/// - `.standard`: `UIImpactFeedbackGenerator`, attached to the keyboard's view on iOS 17.5+.
/// - `.system`: the system "peek" vibration (`AudioServicesPlaySystemSound`), for devices where
///   the feedback generator stays silent inside the keyboard extension.
///
/// The keyboard also reports what it sees (Full Access, last haptic) to the App Group so the
/// app's Settings can show why there is no vibration.
final class HapticManager {
    static let shared = HapticManager()

    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var isEnabled: Bool = true
    private var method: HapticMethod = .standard
    /// Live "Allow Full Access" state of the keyboard (read on every tap, never cached).
    var fullAccess: () -> Bool = { false }
    /// The view the generators belong to (the keyboard's root view).
    private weak var view: UIView?
    private var reportedHaptic = false
    private let log = Logger(subsystem: "com.planetkeyboard.PlanetKeyboard.Keyboard", category: "haptics")

    private init() {}

    /// Attach the generators to the keyboard's view (call once the view exists).
    func attach(to view: UIView) {
        guard self.view !== view else { return }
        self.view = view
        suspend()   // recreated for the new view on the next tap
    }

    func suspend() {
        lightGenerator = nil
        mediumGenerator = nil
    }

    func prepare() {
        guard canPlay, method == .standard else { return }
        generators().light.prepare()
    }

    func triggerKeyTap() {
        play(light: true)
    }

    func triggerSpecialKey() {
        play(light: false)
    }

    func updateEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func loadSettings() {
        let defaults = AppGroup.userDefaults
        isEnabled = defaults.object(forKey: AppConstants.UserDefaultsKey.hapticFeedback) as? Bool ?? true
        method = HapticMethod(rawValue: defaults.string(forKey: AppConstants.UserDefaultsKey.hapticMethod) ?? "") ?? .standard
        reportedHaptic = false
        log.notice("loadSettings fullAccess=\(self.fullAccess()) enabled=\(self.isEnabled) method=\(self.method.rawValue)")
        KeyboardStatus.report(fullAccess: fullAccess(), hapticsEnabled: isEnabled, method: method)
    }

    // MARK: - Private

    private var canPlay: Bool { isEnabled && fullAccess() }

    private func play(light: Bool) {
        guard canPlay else {
            log.notice("skip haptic fullAccess=\(self.fullAccess()) enabled=\(self.isEnabled)")
            return
        }
        log.notice("play haptic \(self.method.rawValue)")
        switch method {
        case .standard:
            let generator = light ? generators().light : generators().medium
            generator.impactOccurred()
            generator.prepare()
        case .system:
            AudioServicesPlaySystemSound(light ? HapticMethod.peekSound : HapticMethod.popSound)
        }
        if !reportedHaptic {
            reportedHaptic = true
            KeyboardStatus.reportHaptic()
        }
    }

    private func generators() -> (light: UIImpactFeedbackGenerator, medium: UIImpactFeedbackGenerator) {
        if let lightGenerator, let mediumGenerator { return (lightGenerator, mediumGenerator) }
        // Created on first use, when the keyboard view is already in its window.
        let light = makeGenerator(.light)
        let medium = makeGenerator(.medium)
        lightGenerator = light
        mediumGenerator = medium
        return (light, medium)
    }

    private func makeGenerator(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if #available(iOS 17.5, *), let view, view.window != nil {
            return UIImpactFeedbackGenerator(style: style, view: view)
        }
        return UIImpactFeedbackGenerator(style: style)
    }
}
