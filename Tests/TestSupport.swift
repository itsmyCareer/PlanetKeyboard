import Foundation

/// In-memory host document standing in for `UITextDocumentProxy`.
final class FakeDocument: TextDocumentEditing {
    var text = ""
    /// Some hosts return nil context; tests can simulate that.
    var reportsContext = true

    var documentContextBeforeInput: String? { reportsContext ? text : nil }
    func insertText(_ t: String) { text += t }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }
}

/// Drives `HangulEngine` + `InlineComposition` exactly like `KeyboardViewController` does and
/// exposes the resulting document text.
final class HangulHarness {
    let engine = HangulEngine()
    let inline = InlineComposition()
    let doc = FakeDocument()
    private(set) var clock: CFTimeInterval = 100

    var text: String { doc.text }

    /// Types every character of `keys`. " " is the space key, "⌫" backspace, "⏎" return.
    /// `gap` is the time between taps (default: slow, no accidental double taps).
    func type(_ keys: String, gap: Double = 0.6) {
        for ch in keys {
            switch ch {
            case " ": press(.space, gap: gap)
            case "⌫": press(.backspace, gap: gap)
            case "⏎": press(.return_, gap: gap)
            default: press(.character(String(ch)), gap: gap)
            }
        }
    }

    func press(_ code: KeyCode, gap: Double = 0.6) {
        clock += gap
        let result = engine.handleKey(KeyEvent(keyCode: code, character: nil, timestamp: clock, type: .character))
        switch result {
        case .insert(let t): doc.insertText(t)
        case .update(let commit, let composing): inline.apply(commit: commit, composing: composing, to: doc)
        case .delete: doc.deleteBackward()
        case .composing, .none: break
        }
    }

    /// The 받침/쌍자음 alternative in the suggestion bar was tapped.
    func swap() {
        guard case .update(let commit, let composing)? = engine.swapAmbiguity() else { return }
        inline.apply(commit: commit, composing: composing, to: doc)
    }

    /// What the controller does on selectionDidChange / textDidChange.
    func hostChanged() {
        guard inline.isActive, !inline.isInSync(with: doc) else { return }
        inline.reset()
        engine.reset()
    }
}

/// Rime engine with the bundled data and a throwaway user directory (one per test run:
/// librime is set up once per process).
func makeRimeEngine() -> RimeEngine {
    if RimeRuntime.api == nil {
        RimeRuntime.userDataDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rime_user_\(UUID().uuidString)")
    }
    return RimeEngine()
}

extension RimeEngine {
    @discardableResult
    func type(_ letters: String) -> InputResult {
        var last = InputResult.none
        for ch in letters {
            last = handleKey(KeyEvent(keyCode: .character(String(ch)), character: String(ch),
                                      timestamp: 0, type: .character))
        }
        return last
    }

    func press(_ code: KeyCode) -> InputResult {
        handleKey(KeyEvent(keyCode: code, character: nil, timestamp: 0, type: .character))
    }
}
