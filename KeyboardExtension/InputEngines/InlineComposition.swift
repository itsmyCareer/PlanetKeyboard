import Foundation

/// The subset of `UITextDocumentProxy` the composer needs. Lets tests use a fake document.
protocol TextDocumentEditing: AnyObject {
    var documentContextBeforeInput: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
}

/// Writes inline (Korean) composition into the host document.
///
/// Only the short composing tail is tracked, and each update rewrites the minimum number of
/// characters (common-prefix diff). If the document no longer ends with the tracked tail
/// (cursor moved, host edited the text) the composition is abandoned instead of deleting
/// characters that are not ours.
final class InlineComposition {

    /// Text we believe sits directly before the cursor and may still be rewritten.
    private(set) var tracked: String = ""

    var isActive: Bool { !tracked.isEmpty }

    func apply(commit: String, composing: String, to proxy: TextDocumentEditing) {
        let old = Array(tracked)
        let new = Array(commit + composing)
        var common = 0
        while common < old.count, common < new.count, old[common] == new[common] {
            common += 1
        }
        for _ in common..<old.count {
            proxy.deleteBackward()
        }
        if common < new.count {
            proxy.insertText(String(new[common...]))
        }
        tracked = composing
    }

    /// True when the host document still ends with our composing text.
    /// Unknown context (`nil`, some hosts) is treated as in sync.
    func isInSync(with proxy: TextDocumentEditing) -> Bool {
        guard isActive, let context = proxy.documentContextBeforeInput else { return true }
        return context.hasSuffix(tracked)
    }

    /// Forget the composition; whatever is in the document stays as committed text.
    func reset() {
        tracked = ""
    }
}
