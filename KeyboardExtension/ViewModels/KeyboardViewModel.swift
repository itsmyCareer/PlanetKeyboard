import SwiftUI
import Combine

/// State of the suggestion bar (the strip above the keys) and the expanded candidate grid.
/// Chinese candidates and emoji suggestions share this one bar, like the system keyboard.
final class KeyboardViewModel: ObservableObject {

    struct Suggestion: Identifiable, Equatable {
        let id: Int          // index passed back on selection
        let text: String
        let isEmoji: Bool
    }

    /// Pinyin candidates (word + emoji mixed) while composing, otherwise emoji for the last word.
    @Published private(set) var suggestions: [Suggestion] = []
    /// True while Pinyin is composing: the first suggestion is what space will commit.
    @Published private(set) var isComposing = false
    /// The full candidate grid replaces the keys.
    @Published var isExpanded = false
    @Published var currentTheme: KeyboardTheme = .defaultLight
    /// The 한/中 (or EN/中) toggle at the left of the bar; nil when paired mode is off.
    @Published var languageToggle: LanguageToggle?
    /// Korean 단모음: the other reading of a 받침/쌍자음 decision (바꼬 → 박고), tap to switch.
    @Published private(set) var alternative: String?
    /// The keyboard process runs without "Allow Full Access" (no haptics, no shared settings).
    @Published var fullAccessMissing = false

    struct LanguageToggle: Equatable {
        let baseLabel: String      // 한 or EN
        let chineseSelected: Bool
    }

    var onSelect: ((Suggestion) -> Void)?
    var onDismiss: (() -> Void)?
    var onToggleLanguage: (() -> Void)?
    var onAlternative: (() -> Void)?

    func setAlternative(_ text: String?) {
        if text != alternative { alternative = text }
    }

    func setLanguageToggle(_ toggle: LanguageToggle?) {
        if toggle != languageToggle { languageToggle = toggle }
    }

    func showCandidates(_ candidates: [String]) {
        suggestions = candidates.enumerated().map {
            Suggestion(id: $0.offset, text: $0.element, isEmoji: Self.isEmoji($0.element))
        }
        isComposing = !candidates.isEmpty
        if candidates.isEmpty { isExpanded = false }
    }

    func showEmoji(_ emoji: [String]) {
        isComposing = false
        isExpanded = false
        let items = emoji.enumerated().map { Suggestion(id: $0.offset, text: $0.element, isEmoji: true) }
        if items != suggestions { suggestions = items }
    }

    func clear() {
        if !suggestions.isEmpty { suggestions = [] }
        isComposing = false
        isExpanded = false
    }

    func updateTheme(_ theme: KeyboardTheme) {
        currentTheme = theme
    }

    static func isEmoji(_ s: String) -> Bool {
        guard let scalar = s.unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation || s.unicodeScalars.contains { $0.value == 0xFE0F }
    }
}
