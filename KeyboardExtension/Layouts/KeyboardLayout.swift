import Foundation

/// Letter page of one language. Rows 1–3 only; the bottom row comes from `BottomRow` so every
/// language (and every text-field type) gets the same iOS-style row.
protocol KeyboardLayout {
    var language: Language { get }
    func letterRows(shifted: Bool) -> [KeyRow]
}

extension KeyboardLayout {
    /// Full page including the bottom row.
    func rows(shifted: Bool = false, bottom: BottomRow.Config = .init(language: .english)) -> [KeyRow] {
        letterRows(shifted: shifted) + [BottomRow.letters(bottom)]
    }

    func keyDefinition(for code: KeyCode) -> KeyDefinition? {
        rows(bottom: .init(language: language)).lazy.flatMap(\.keys).first { $0.code == code }
    }
}

extension KeyDefinition {
    static func char(_ ch: String) -> KeyDefinition {
        KeyDefinition(code: .character(ch), label: ch, width: .standard, type: .character)
    }

    static func backspace(_ width: KeyWidth = .flex(1)) -> KeyDefinition {
        KeyDefinition(code: .backspace, label: "⌫", width: width, type: .backspace, icon: "delete.left")
    }

    static func gap(_ columns: CGFloat) -> KeyDefinition {
        KeyDefinition(code: .character(""), label: "", width: .gap(columns), type: .character)
    }
}

// MARK: - Bottom row

enum BottomRow {

    /// What kind of text field we are typing into (from `UITextInputTraits.keyboardType`).
    enum FieldKind: Hashable {
        case text, email, url, webSearch, twitter
    }

    /// Return key appearance (from `UITextInputTraits.returnKeyType`).
    enum ReturnStyle: Hashable {
        case `default`, go, search, send, done, next, join, route, emergency, `continue`
    }

    struct Config: Hashable {
        var language: Language
        var field: FieldKind = .text
        var returnStyle: ReturnStyle = .default
        var returnEnabled: Bool = true
    }

    /// Letters page: `123 · 🌐 · [ space ] · ⏎` (email/url/twitter add their iOS keys).
    static func letters(_ c: Config) -> KeyRow {
        var keys = [
            KeyDefinition(code: .numbers, label: "123", width: .wide(1.25), type: .numbers),
            KeyDefinition(code: .language, label: "🌐", width: .wide(1.25), type: .language, icon: "globe"),
        ]
        switch c.field {
        case .text:
            keys.append(space(c.language))
        case .email:
            keys += [space(c.language), .char("@"), .char(".")]
        case .webSearch:
            keys += [space(c.language), .char(".")]
        case .twitter:
            keys += [space(c.language), .char("@"), .char("#")]
        case .url:
            keys += [.char("."), .char("/"),
                     KeyDefinition(code: .character(".com"), label: ".com", width: .flex(1), type: .character)]
        }
        keys.append(returnKey(c, width: .wide(2.25)))
        return KeyRow(keys: keys, columns: 10)
    }

    /// Number / symbol pages: `한글 · [ space ] · ⏎` like iOS.
    static func numbers(_ c: Config) -> KeyRow {
        KeyRow(keys: [
            KeyDefinition(code: .numbers, label: backLabel(c.language), width: .wide(2.5), type: .numbers),
            space(c.language),
            returnKey(c, width: .wide(2.5)),
        ], columns: 10)
    }

    static func backLabel(_ language: Language) -> String {
        switch language {
        case .korean: return "한글"
        case .english: return "ABC"
        case .chinese: return "拼音"
        }
    }

    static func spaceLabel(_ language: Language) -> String {
        switch language {
        case .korean: return "한국어"
        case .english: return "English"
        case .chinese: return "简体拼音"
        }
    }

    static func space(_ language: Language) -> KeyDefinition {
        KeyDefinition(code: .space, label: spaceLabel(language), width: .flex(1), type: .space)
    }

    static func returnKey(_ c: Config, width: KeyWidth) -> KeyDefinition {
        let (label, icon) = returnLabel(c.returnStyle, c.language)
        let accent: Bool
        switch c.returnStyle {
        case .default, .next: accent = false
        default: accent = true
        }
        return KeyDefinition(code: .return_, label: label, width: width, type: .returnKey,
                             icon: icon, isAccent: accent && c.returnEnabled, isEnabled: c.returnEnabled)
    }

    static func returnLabel(_ style: ReturnStyle, _ language: Language) -> (String, String?) {
        func t(_ ko: String, _ en: String, _ zh: String) -> String {
            switch language {
            case .korean: return ko
            case .english: return en
            case .chinese: return zh
            }
        }
        switch style {
        case .default: return ("⏎", "return.left")
        case .search: return (t("검색", "search", "搜索"), "magnifyingglass")
        case .go: return (t("이동", "go", "前往"), nil)
        case .send: return (t("보내기", "send", "发送"), nil)
        case .done: return (t("완료", "done", "完成"), nil)
        case .next: return (t("다음", "next", "下一项"), nil)
        case .join: return (t("연결", "join", "加入"), nil)
        case .route: return (t("경로", "route", "路线"), nil)
        case .emergency: return (t("긴급 통화", "Emergency", "紧急"), nil)
        case .continue: return (t("계속", "continue", "继续"), nil)
        }
    }
}
