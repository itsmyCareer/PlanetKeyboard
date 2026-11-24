import Foundation

/// Which language the globe key and the 한/中 toggle switch to.
///
/// - Normal mode: the globe cycles every language.
/// - Paired mode (Settings → "Globe: Korean ↔ English"): the globe flips between Korean and
///   English only, and the toggle at the left of the suggestion bar flips between that
///   language and Chinese (한 中 / EN 中). Globe from Chinese goes to the *other* base language.
struct LanguageSwitch: Equatable {
    private(set) var current: Language
    /// Korean or English: what the toggle shows next to 中 and returns to.
    private(set) var base: Language
    var isPaired: Bool

    init(current: Language, base: Language = .korean, isPaired: Bool = false) {
        self.current = current
        self.base = current == .chinese ? (base == .chinese ? .korean : base) : current
        self.isPaired = isPaired
    }

    mutating func globe() {
        guard isPaired else {
            let all = Language.allCases
            let index = all.firstIndex(of: current) ?? 0
            current = all[(index + 1) % all.count]
            if current != .chinese { base = current }
            return
        }
        let next: Language = base == .korean ? .english : .korean
        base = next
        current = next
    }

    mutating func toggleChinese() {
        current = current == .chinese ? base : .chinese
    }

    /// Label of the toggle's left half: 한 or EN.
    var baseLabel: String { base == .english ? "EN" : "한" }
}
