import Foundation

/// 단모음(Danmoeum) letter page, same arrangement as the reference keyboard:
///
///     ㅂ ㅈ ㄷ ㄱ ㅅ ㅗ ㅐ ㅔ
///     ㅁ ㄴ ㅇ ㄹ ㅎ ㅓ ㅏ ㅣ
///       ㅋ ㅌ ㅊ ㅍ ㅜ ㅡ  ⌫
///
/// Tap the same key twice for the "long" form: ㅂ→ㅃ ㅈ→ㅉ ㄷ→ㄸ ㄱ→ㄲ ㅅ→ㅆ,
/// ㅗ→ㅛ ㅓ→ㅕ ㅏ→ㅑ ㅜ→ㅠ ㅐ→ㅒ ㅔ→ㅖ (handled by `HangulEngine`). No shift key.
struct KoreanLayout: KeyboardLayout {
    let language: Language = .korean

    func letterRows(shifted: Bool) -> [KeyRow] {
        [
            KeyRow(keys: ["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅗ", "ㅐ", "ㅔ"].map(KeyDefinition.char), columns: 8),
            KeyRow(keys: ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅓ", "ㅏ", "ㅣ"].map(KeyDefinition.char), columns: 8),
            KeyRow(keys: [.gap(0.75)] + ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅜ", "ㅡ"].map(KeyDefinition.char)
                   + [.backspace()], columns: 8),
        ]
    }
}

/// iOS QWERTY. Character codes are uppercase; the engine applies the shift state.
struct EnglishLayout: KeyboardLayout {
    let language: Language = .english

    func letterRows(shifted: Bool) -> [KeyRow] {
        QwertyRows.rows(shiftKey: true, uppercase: shifted)
    }
}

/// QWERTY for Pinyin. Shift types capital letters as they are (NH, iPhone) instead of Pinyin.
struct ChineseLayout: KeyboardLayout {
    let language: Language = .chinese

    func letterRows(shifted: Bool) -> [KeyRow] {
        QwertyRows.rows(shiftKey: true, uppercase: shifted)
    }
}

enum QwertyRows {
    static func rows(shiftKey: Bool, uppercase: Bool) -> [KeyRow] {
        func keys(_ s: String) -> [KeyDefinition] {
            s.map { ch in
                let c = String(ch)
                return KeyDefinition(code: .character(c.uppercased()),
                                     label: uppercase ? c.uppercased() : c, width: .standard, type: .character)
            }
        }
        let shift = KeyDefinition(code: .shift, label: "⇧", width: .flex(1), type: .shift, icon: "shift")
        return [
            KeyRow(keys: keys("qwertyuiop"), columns: 10),
            KeyRow(keys: [.gap(0.5)] + keys("asdfghjkl") + [.gap(0.5)], columns: 10),
            KeyRow(keys: (shiftKey ? [shift] : [.gap(1.5)]) + keys("zxcvbnm") + [.backspace()], columns: 10),
        ]
    }
}
