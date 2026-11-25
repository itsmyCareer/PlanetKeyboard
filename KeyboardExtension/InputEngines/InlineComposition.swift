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
///
/// While typing fast, iOS can report the host's text late or halfway through one of our
/// delete + insert edits (끄 → 끈 seen as 끄, or with the 끄 already deleted). Such a report is
/// not the user moving the cursor: shortly after an edit, a context that matches one of the
/// states our own recent edits passed through keeps the composition (끈 + ㅎ → 끊, not 끈ㅎ).
final class InlineComposition {

    /// Text we believe sits directly before the cursor and may still be rewritten.
    private(set) var tracked: String = ""

    var isActive: Bool { !tracked.isEmpty }

    /// Clock for the stale-report window (tests inject their own).
    var clock: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }

    /// How long after our last edit a lagging host report is still expected.
    static let staleWindow: TimeInterval = 1.0
    /// Characters before the cursor compared when matching a report against our own edits.
    static let anchorLength = 24

    /// Document tails (last `anchorLength` characters) our recent edits passed through.
    private var recentStates: [String] = []
    /// The document tail right after our last edit.
    private var expected: String?
    private var lastEdit: TimeInterval = -.infinity

    func apply(commit: String, composing: String, to proxy: TextDocumentEditing) {
        let reported = proxy.documentContextBeforeInput
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
        record(base: base(reported: reported, oldTracked: String(old)), deletes: old.count - common,
               inserted: common < new.count ? String(new[common...]) : "")
    }

    /// True when the host document still ends with our composing text (or shows a state our own
    /// edits just passed through). Unknown context (`nil`, some hosts) is treated as in sync.
    func isInSync(with proxy: TextDocumentEditing) -> Bool {
        guard isActive, let context = proxy.documentContextBeforeInput else { return true }
        if context.hasSuffix(tracked) { return true }
        guard clock() - lastEdit < Self.staleWindow else { return false }
        return recentStates.contains(Self.anchor(context))
    }

    /// Forget the composition; whatever is in the document stays as committed text.
    func reset() {
        tracked = ""
        recentStates = []
        expected = nil
        lastEdit = -.infinity
    }

    // MARK: - Recent edits

    /// The document before this edit: the reported context when it shows our composition,
    /// otherwise (a lagging report) the tail our previous edit left.
    private func base(reported: String?, oldTracked: String) -> String? {
        if let reported, reported.hasSuffix(oldTracked) { return reported }
        return expected
    }

    private func record(base: String?, deletes: Int, inserted: String) {
        lastEdit = clock()
        guard var doc = base else {
            expected = nil
            return
        }
        var states = [Self.anchor(doc)]
        for _ in 0..<deletes where !doc.isEmpty {
            doc.removeLast()
            states.append(Self.anchor(doc))
        }
        doc += inserted
        let after = Self.anchor(doc)
        states.append(after)
        expected = after
        recentStates = Array((recentStates + states).suffix(12))
    }

    private static func anchor(_ text: String) -> String {
        String(text.suffix(anchorLength))
    }
}
