import Foundation

/// iOS "123" and "#+=" pages, per language (the Korean, English and Chinese iOS keyboards differ),
/// plus the 3×4 pad used for number / phone / decimal fields.
enum NumberLayout {

    enum Page {
        case numbers
        case symbols
    }

    static func rows(page: Page, bottom: BottomRow.Config) -> [KeyRow] {
        let (row1, row2, row3) = keys(page: page, language: bottom.language)
        let toggle = KeyDefinition(code: .symbols, label: page == .numbers ? "#+=" : "123",
                                   width: .wide(1.25), type: .numbers)
        let punctuation = row3.map {
            KeyDefinition(code: .character($0), label: $0, width: .flex(1), type: .character)
        }
        return [
            KeyRow(keys: row1.map(KeyDefinition.char), columns: 10),
            KeyRow(keys: row2.map(KeyDefinition.char), columns: 10),
            KeyRow(keys: [toggle] + punctuation + [.backspace(.wide(1.25))], columns: 10),
            BottomRow.numbers(bottom),
        ]
    }

    static func keys(page: Page, language: Language) -> ([String], [String], [String]) {
        let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        switch (page, language) {
        case (.numbers, .korean):
            return (digits, ["-", "/", ":", ";", "(", ")", "₩", "&", "@", "\""], [".", ",", "?", "!", "'"])
        case (.numbers, .english):
            return (digits, ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""], [".", ",", "?", "!", "'"])
        case (.numbers, .chinese):
            return (digits, ["-", "/", "：", "；", "（", "）", "¥", "@", "“", "”"], ["。", "，", "、", "？", "！", "."])
        case (.symbols, .korean):
            return (["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
                    ["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "•"], [".", ",", "?", "!", "'"])
        case (.symbols, .english):
            return (["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
                    ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"], [".", ",", "?", "!", "'"])
        case (.symbols, .chinese):
            return (["【", "】", "{", "}", "#", "%", "^", "*", "+", "="],
                    ["_", "—", "\\", "|", "~", "《", "》", "$", "&", "·"], ["…", "，", "^_^", "？", "！", "‘"])
        }
    }

    // MARK: - Number pad

    enum PadKind {
        case number, decimal, phone
    }

    static func padRows(_ kind: PadKind) -> [KeyRow] {
        let digit = { (d: String) in KeyDefinition(code: .character(d), label: d, width: .standard, type: .character) }
        let bottomLeft: KeyDefinition
        switch kind {
        case .number: bottomLeft = .gap(1)
        case .decimal:
            let sep = Locale.current.decimalSeparator ?? "."
            bottomLeft = KeyDefinition(code: .character(sep), label: sep, width: .standard, type: .numbers)
        case .phone:
            bottomLeft = KeyDefinition(code: .character("+"), label: "+", width: .standard, type: .numbers)
        }
        return [
            KeyRow(keys: ["1", "2", "3"].map(digit), columns: 3),
            KeyRow(keys: ["4", "5", "6"].map(digit), columns: 3),
            KeyRow(keys: ["7", "8", "9"].map(digit), columns: 3),
            KeyRow(keys: [bottomLeft, digit("0"), .backspace(.standard)], columns: 3),
        ]
    }
}
