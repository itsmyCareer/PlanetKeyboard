import UIKit

/// When the English keyboard should start a capital letter (iOS rules, simplified).
enum AutoCapitalization {
    static func shouldCapitalize(type: UITextAutocapitalizationType, before: String) -> Bool {
        switch type {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            return before.isEmpty || before.last!.isWhitespace
        case .sentences:
            let trimmed = before.reversed().drop { $0 == " " }
            guard let last = trimmed.first else { return true }          // start of text
            if last.isNewline { return true }
            // ". " / "! " / "? " — the punctuation must be followed by at least one space.
            return trimmed.count < before.count && ".!?".contains(last)
        @unknown default:
            return false
        }
    }
}

/// How many characters one "word delete" (held backspace) removes, like the system keyboard:
/// trailing spaces plus the word before them, or a single punctuation mark / emoji.
enum WordDeletion {
    static func count(before: String) -> Int {
        let chars = Array(before)
        var i = chars.count
        while i > 0, chars[i - 1].isWhitespace { i -= 1 }
        guard i > 0 else { return chars.count }
        let isWordChar = { (c: Character) in c.isLetter || c.isNumber }
        if isWordChar(chars[i - 1]) {
            while i > 0, isWordChar(chars[i - 1]) { i -= 1 }
        } else {
            i -= 1
        }
        return chars.count - i
    }
}
