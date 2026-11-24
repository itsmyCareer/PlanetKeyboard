import Foundation
import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var currentTheme: KeyboardTheme = .defaultLight

    private(set) var cachedKeyBackground: Color = KeyboardTheme.defaultLight.keyBackground
    private(set) var cachedKeyText: Color = KeyboardTheme.defaultLight.keyText
    private(set) var cachedSpecialKeyBackground: Color = KeyboardTheme.defaultLight.specialKeyBackground
    private(set) var cachedBackground: Color = KeyboardTheme.defaultLight.background
    private(set) var cachedAccent: Color = KeyboardTheme.defaultLight.accent

    private init() {}

    func loadTheme() {
        let themeId = AppGroup.userDefaults.string(forKey: AppConstants.UserDefaultsKey.selectedTheme) ?? "default-light"
        currentTheme = KeyboardTheme.allBuiltIn.first { $0.id == themeId } ?? .defaultLight
        refreshColorCache()
    }

    func saveTheme(_ theme: KeyboardTheme) {
        AppGroup.userDefaults.set(theme.id, forKey: AppConstants.UserDefaultsKey.selectedTheme)
        currentTheme = theme
        refreshColorCache()
    }

    private func refreshColorCache() {
        cachedKeyBackground = currentTheme.keyBackground
        cachedKeyText = currentTheme.keyText
        cachedSpecialKeyBackground = currentTheme.specialKeyBackground
        cachedBackground = currentTheme.background
        cachedAccent = currentTheme.accent
    }
}
