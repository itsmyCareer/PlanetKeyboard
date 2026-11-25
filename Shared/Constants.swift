import Foundation

// MARK: - Language

enum Language: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh"
    case korean = "ko"

    var id: String { rawValue }
}

// MARK: - AppConstants

enum AppConstants {
    static let appGroupID = "group.com.planetkeyboard.shared"

    enum UserDefaultsKey {
        static let selectedTheme = "selectedTheme"
        static let hapticFeedback = "hapticFeedback"
        static let preferredLanguage = "preferredLanguage"
        static let soundEnabled = "soundEnabled"
        /// Globe switches 한 ↔ EN only; Chinese comes from the 한/中 toggle in the suggestion bar.
        static let pairedLanguageMode = "pairedLanguageMode"
        /// Korean or English: what the 한/中 toggle returns to (paired mode).
        static let baseLanguage = "baseLanguage"
        /// Key height multipliers (1 = iPhone system keyboard): Korean, and English & Chinese.
        static let koreanKeyScale = "koreanKeyScale"
        static let latinKeyScale = "latinKeyScale"
    }

    /// Allowed key size settings (1 = the iPhone system keyboard).
    static let keyScaleRange: ClosedRange<Double> = 0.85...1.3
}

// MARK: - KeyCode

enum KeyCode: Hashable {
    case character(String)
    case shift
    case backspace
    case space
    case language
    case return_
    case numbers
    /// Switches between the number page and the #+= symbol page.
    case symbols
    case emoji
    case dismiss
}

// MARK: - KeyType

/// Visual / behavioural class of a key.
enum KeyType: Hashable {
    case character
    case shift
    case backspace
    case space
    case language
    case returnKey
    case numbers
    case dismiss
}

// MARK: - KeyWidth

/// How a key takes space in its row (see `KeyRow.columns`):
/// - `standard`: one column.
/// - `wide(n)`: n columns.
/// - `flex(w)`: shares what is left of the row, weighted by `w`.
/// - `gap(n)`: invisible spacer of n columns *including* the inter-key gap (used for indents).
enum KeyWidth: Hashable {
    case standard
    case wide(CGFloat)
    case flex(CGFloat)
    case gap(CGFloat)
}

// MARK: - KeyDefinition

struct KeyDefinition: Identifiable, Hashable {
    let code: KeyCode
    let label: String
    let width: KeyWidth
    let type: KeyType
    /// SF Symbol drawn instead of `label` (label stays for accessibility/tests).
    var icon: String? = nil
    /// Blue "action" style (return key for go/search/send/done...).
    var isAccent: Bool = false
    var isEnabled: Bool = true

    var id: String { "\(code)|\(label)|\(width)" }
    var isSpacer: Bool { if case .gap = width { return true } else { return false } }
}

/// One row of keys. `columns` is how many standard keys fit the row width
/// (10 for QWERTY/number pages and every bottom row, 8 for 단모음, 3 for the number pad).
struct KeyRow: Hashable {
    var keys: [KeyDefinition]
    var columns: Int
}
