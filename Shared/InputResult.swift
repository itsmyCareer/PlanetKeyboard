import Foundation

enum InputResult: Equatable {
    /// Insert plain text at the cursor (no inline composition involved).
    case insert(String)
    /// Inline composition update (Korean): `commit` is finished text, `composing` is the
    /// still-editable tail. Both are written to the document; only `composing` stays tracked.
    case update(commit: String, composing: String)
    /// Composition state changed but nothing is written to the document (Pinyin buffer).
    case composing(String)
    /// Delete one character before the cursor.
    case delete
    case none
}
