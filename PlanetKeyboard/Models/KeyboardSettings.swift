import Foundation

struct KeyboardSettings: Codable {
    var selectedThemeID: String = "default-light"
    var hapticFeedbackEnabled: Bool = true
    var preferredLanguage: Language = .english
    var soundEnabled: Bool = false
    /// Globe switches 한 ↔ EN only; a 한/中 toggle in the keyboard's bar switches to Chinese.
    var pairedLanguageMode: Bool = false
    /// Key height multipliers (1 = iPhone system keyboard).
    var koreanKeyScale: Double = 1
    var latinKeyScale: Double = 1

    static func load() -> KeyboardSettings {
        let defaults = AppGroup.userDefaults
        return KeyboardSettings(
            selectedThemeID: defaults.string(forKey: AppConstants.UserDefaultsKey.selectedTheme) ?? "default-light",
            hapticFeedbackEnabled: defaults.object(forKey: AppConstants.UserDefaultsKey.hapticFeedback) as? Bool ?? true,
            preferredLanguage: Language(rawValue: defaults.string(forKey: AppConstants.UserDefaultsKey.preferredLanguage) ?? "en") ?? .english,
            soundEnabled: defaults.object(forKey: AppConstants.UserDefaultsKey.soundEnabled) as? Bool ?? false,
            pairedLanguageMode: defaults.bool(forKey: AppConstants.UserDefaultsKey.pairedLanguageMode),
            koreanKeyScale: defaults.object(forKey: AppConstants.UserDefaultsKey.koreanKeyScale) as? Double ?? 1,
            latinKeyScale: defaults.object(forKey: AppConstants.UserDefaultsKey.latinKeyScale) as? Double ?? 1
        )
    }

    func save() {
        let defaults = AppGroup.userDefaults
        defaults.set(selectedThemeID, forKey: AppConstants.UserDefaultsKey.selectedTheme)
        defaults.set(hapticFeedbackEnabled, forKey: AppConstants.UserDefaultsKey.hapticFeedback)
        defaults.set(preferredLanguage.rawValue, forKey: AppConstants.UserDefaultsKey.preferredLanguage)
        defaults.set(soundEnabled, forKey: AppConstants.UserDefaultsKey.soundEnabled)
        defaults.set(pairedLanguageMode, forKey: AppConstants.UserDefaultsKey.pairedLanguageMode)
        defaults.set(koreanKeyScale, forKey: AppConstants.UserDefaultsKey.koreanKeyScale)
        defaults.set(latinKeyScale, forKey: AppConstants.UserDefaultsKey.latinKeyScale)
    }
}
