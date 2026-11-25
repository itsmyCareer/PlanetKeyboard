import Foundation

/// 단모음(Danmoeum) Hangul composer.
///
/// Rules (tap speed never matters, except for a lone vowel such as ㅜㅜ):
/// - Same consonant twice at the start of a syllable: 쌍자음 if a vowel follows (ㄱㄱㅏ → 까),
///   otherwise the two letters stay as typed (ㄱㄱ, ㅂㅂ, ㄷㄷ).
/// - Same vowel twice → 이중모음 (ㅏㅏ→ㅑ, ㅐㅐ→ㅒ ...).
/// - 받침 + same consonant (바 + ㄱㄱ) waits for the next key:
///   - a consonant, space or anything else keeps a doubled 받침 when one exists (밖, 있);
///   - a vowel asks `HangulAmbiguityResolver` (word statistics): 바꿔 / 박고 / 학교 / 먹고.
///   Until that next syllable is finished the other reading can be picked instead
///   (`ambiguityAlternative` / `swapAmbiguity()`, shown in the suggestion bar).
///
/// Every key returns `.update(commit:composing:)`: `commit` is text that can no longer change,
/// `composing` is the short tail that may still be rewritten.
final class HangulEngine: InputEngine {

    let language: Language = .korean

    // MARK: - State

    enum State: Equatable {
        case empty
        case vowel(Character)
        case initial(Character)
        /// The same plain consonant tapped twice at the start of a syllable (ㄱㄱ).
        case initialPair(Character)
        case composingCV(initial: Character, medial: Character)
        case composingCVC(initial: Character, medial: Character, final_: Character)
        case boundaryAmbiguous(BoundaryAmbiguity)
    }

    /// 바 + ㄱㄱ before the next key: 밖 / 박ㄱ / 바ㄲ.
    struct BoundaryAmbiguity: Equatable {
        let leftInitial: Character
        let leftMedial: Character
        let consonant: Character            // the plain consonant tapped twice, e.g. ㄱ
    }

    enum BoundaryDecision: Equatable {
        case splitFinalPlainInitial   // 학 + 교
        case tenseInitial             // 바 + 꿔

        var flipped: BoundaryDecision {
            self == .tenseInitial ? .splitFinalPlainInitial : .tenseInitial
        }
    }

    /// A resolved ambiguity whose second syllable is still being typed: the left syllable is
    /// held back (not committed) so the other reading can still be chosen.
    private struct Held: Equatable {
        let ambiguity: BoundaryAmbiguity
        var decision: BoundaryDecision
    }

    private(set) var state: State = .empty
    private var held: Held?
    private var pendingCommit: String = ""

    private let resolver: HangulAmbiguityResolver

    /// A lone vowel tapped twice within this gap is doubled (ㅜㅜ → ㅠ); slower stays ㅜㅜ.
    static let defaultThresholdMs: Double = 400
    var doubleTapThresholdMs: Double = HangulEngine.defaultThresholdMs

    private var lastKey: Character?
    private var lastKeyTime: CFTimeInterval = 0

    init(resolver: HangulAmbiguityResolver = HangulAmbiguityResolver()) {
        self.resolver = resolver
    }

    // MARK: - InputEngine

    /// Text still being composed (what is currently tracked inline in the document).
    var compositionText: String { heldText + display(of: state) }

    var candidates: [String] { [] }

    /// The other reading of the last 받침/쌍자음 decision while it can still be changed
    /// (바꼬 → "박고"), nil otherwise.
    var ambiguityAlternative: String? {
        guard var h = held else { return nil }
        h.decision = h.decision.flipped
        return text(of: h) + display(of: state.withInitial(initial(for: h)))
    }

    /// Switch the last 받침/쌍자음 decision to the other reading (바꼬 ↔ 박고).
    func swapAmbiguity() -> InputResult? {
        guard var h = held else { return nil }
        h.decision = h.decision.flipped
        held = h
        state = state.withInitial(initial(for: h))
        lastKey = nil
        return output()
    }

    func handleKey(_ key: KeyEvent) -> InputResult {
        defer {
            if case .character(let s) = key.keyCode, let c = s.first {
                lastKey = c
                lastKeyTime = key.timestamp
            } else {
                lastKey = nil
            }
        }
        switch key.keyCode {
        case .character(let str):
            guard let char = str.first else { return .none }
            if HangulJamo.isVowel(char) {
                handleVowel(char, timestamp: key.timestamp)
            } else if HangulJamo.initialIndex(of: char) != nil {
                handleConsonant(char)
            } else {
                return flush(appending: str)
            }
            return output()
        case .backspace:
            return handleBackspace()
        case .space:
            return flush(appending: " ")
        case .return_:
            return flush(appending: "\n")
        case .shift, .language, .numbers, .symbols, .emoji, .dismiss:
            return state == .empty ? .none : flush(appending: "")
        }
    }

    func selectCandidate(at index: Int) -> String { "" }

    func reset() {
        state = .empty
        held = nil
        pendingCommit = ""
        lastKey = nil
    }

    // MARK: - Consonants

    private func handleConsonant(_ char: Character) {
        switch state {
        case .empty:
            state = .initial(char)

        case .vowel:
            commitState()
            state = .initial(char)

        case .initial(let current):
            if current == char, HangulJamo.isDoubleable(char) {
                state = .initialPair(char)
            } else {
                commitState()
                state = .initial(char)
            }

        case .initialPair(let current):
            if current == char {
                emit(String(char))      // ㄱㄱㄱ: the last two taps still form the pair
            } else {
                commitState()
                state = .initial(char)
            }

        case .composingCV(let initial, let medial):
            if HangulJamo.finalIndex(of: char) != nil {
                state = .composingCVC(initial: initial, medial: medial, final_: char)
            } else {
                commitState()   // ㄸ ㅃ ㅉ can't be 받침
                state = .initial(char)
            }

        case .composingCVC(let initial, let medial, let final_):
            if final_ == char, HangulJamo.isDoubleable(char) {
                emit("")        // an earlier decision is final now
                state = .boundaryAmbiguous(BoundaryAmbiguity(leftInitial: initial, leftMedial: medial,
                                                             consonant: char))
            } else if let compound = HangulJamo.combineConsonants(final_, char) {
                state = .composingCVC(initial: initial, medial: medial, final_: compound)
            } else {
                commitState()
                state = .initial(char)
            }

        case .boundaryAmbiguous(let ambiguity):
            settleAmbiguityWithoutVowel(ambiguity)
            handleConsonant(char)
        }
    }

    // MARK: - Vowels

    private func handleVowel(_ char: Character, timestamp: CFTimeInterval) {
        switch state {
        case .empty:
            state = .vowel(char)

        case .vowel(let current):
            if current == char, lastKey == char, (timestamp - lastKeyTime) * 1000 < doubleTapThresholdMs,
               let doubled = HangulJamo.doubledVowel(char) {
                state = .vowel(doubled)
            } else if let combined = HangulJamo.combineVowels(current, char) {
                state = .vowel(combined)
            } else {
                commitState()
                state = .vowel(char)
            }

        case .initial(let consonant):
            state = .composingCV(initial: consonant, medial: char)

        case .initialPair(let consonant):
            state = .composingCV(initial: HangulJamo.doubled(consonant) ?? consonant, medial: char)

        case .composingCV(let initial, let medial):
            if medial == char, lastKey == char, let doubled = HangulJamo.doubledVowel(char) {
                state = .composingCV(initial: initial, medial: doubled)
            } else if let combined = HangulJamo.combineVowels(medial, char) {
                state = .composingCV(initial: initial, medial: combined)
            } else {
                commitState()
                state = .vowel(char)
            }

        case .composingCVC(let initial, let medial, let final_):
            if let split = HangulJamo.splitCompoundFinal(final_) {
                emit(syllable(initial, medial, split.stay))
                state = .composingCV(initial: split.move, medial: char)
            } else {
                emit(syllable(initial, medial, nil))
                state = .composingCV(initial: final_, medial: char)
            }

        case .boundaryAmbiguous(let a):
            let left = syllable(a.leftInitial, a.leftMedial, nil).first ?? " "
            let h = Held(ambiguity: a, decision: resolver.decide(left: left, consonant: a.consonant, vowel: char))
            held = h
            state = .composingCV(initial: initial(for: h), medial: char)
        }
    }

    // MARK: - Backspace

    private func handleBackspace() -> InputResult {
        switch state {
        case .empty:
            return .delete
        case .vowel(let v):
            state = HangulJamo.decomposeVowel(v).map { .vowel($0) } ?? .empty
        case .initial:
            if let h = held {
                held = nil
                state = .boundaryAmbiguous(h.ambiguity)   // 바꾸 ⌫ 바ㄲ ⌫ 밖
            } else {
                state = .empty
            }
        case .initialPair(let c):
            state = .initial(c)
        case .composingCV(let initial, let medial):
            state = HangulJamo.decomposeVowel(medial).map { .composingCV(initial: initial, medial: $0) }
                ?? .initial(initial)
        case .composingCVC(let initial, let medial, let final_):
            if let split = HangulJamo.splitCompoundFinal(final_) {
                state = .composingCVC(initial: initial, medial: medial, final_: split.stay)
            } else {
                state = .composingCV(initial: initial, medial: medial)
            }
        case .boundaryAmbiguous(let a):
            state = .composingCVC(initial: a.leftInitial, medial: a.leftMedial, final_: a.consonant)
        }
        lastKey = nil
        return output()
    }

    // MARK: - Ambiguity

    /// No vowel followed the double tap: ㄲ/ㅆ become a doubled 받침 (밖, 있),
    /// ㄷ/ㅂ/ㅈ (no doubled 받침 exists) split into 받침 + new 초성.
    private func settleAmbiguityWithoutVowel(_ a: BoundaryAmbiguity) {
        if let doubled = HangulJamo.doubled(a.consonant), HangulJamo.finalIndex(of: doubled) != nil {
            state = .composingCVC(initial: a.leftInitial, medial: a.leftMedial, final_: doubled)
        } else {
            emit(syllable(a.leftInitial, a.leftMedial, a.consonant))
            state = .initial(a.consonant)
        }
    }

    private func initial(for h: Held) -> Character {
        h.decision == .tenseInitial ? (HangulJamo.doubled(h.ambiguity.consonant) ?? h.ambiguity.consonant)
                                    : h.ambiguity.consonant
    }

    /// The held left syllable: 박 (받침 + 초성) or 바 (쌍자음).
    private func text(of h: Held) -> String {
        let a = h.ambiguity
        return syllable(a.leftInitial, a.leftMedial, h.decision == .splitFinalPlainInitial ? a.consonant : nil)
    }

    private var heldText: String { held.map(text(of:)) ?? "" }

    // MARK: - Helpers

    /// Commits `text`, preceded by the held syllable: once anything after it is committed,
    /// its decision can no longer change.
    private func emit(_ text: String) {
        if let h = held {
            pendingCommit.append(self.text(of: h))
            held = nil
        }
        pendingCommit.append(text)
    }

    private func output() -> InputResult {
        let commit = pendingCommit
        pendingCommit = ""
        return .update(commit: commit, composing: compositionText)
    }

    private func flush(appending suffix: String) -> InputResult {
        commitState()
        let commit = pendingCommit + suffix
        pendingCommit = ""
        if commit.isEmpty { return .none }
        return .update(commit: commit, composing: "")
    }

    private func commitState() {
        if case .boundaryAmbiguous(let a) = state {
            settleAmbiguityWithoutVowel(a)
        }
        emit(display(of: state))
        state = .empty
    }

    private func syllable(_ initial: Character, _ medial: Character, _ final_: Character?) -> String {
        guard let i = HangulJamo.initialIndex(of: initial),
              let m = HangulJamo.medialIndex(of: medial) else {
            return String(initial) + String(medial) + (final_.map { String($0) } ?? "")
        }
        let f = final_.flatMap { HangulJamo.finalIndex(of: $0) } ?? 0
        return String(HangulJamo.composeSyllable(initial: i, medial: m, final: f))
    }

    private func display(of state: State) -> String {
        switch state {
        case .empty:
            return ""
        case .vowel(let v):
            return String(v)
        case .initial(let c):
            return String(c)
        case .initialPair(let c):
            return String(c) + String(c)    // ㄱㄱ stays as typed unless a vowel follows
        case .composingCV(let i, let m):
            return syllable(i, m, nil)
        case .composingCVC(let i, let m, let f):
            return syllable(i, m, f)
        case .boundaryAmbiguous(let a):
            // Show what we'd produce if no vowel follows: 밖 / 있 (one syllable) or 압ㅂ.
            if let doubled = HangulJamo.doubled(a.consonant), HangulJamo.finalIndex(of: doubled) != nil {
                return syllable(a.leftInitial, a.leftMedial, doubled)
            }
            return syllable(a.leftInitial, a.leftMedial, a.consonant) + String(a.consonant)
        }
    }
}

private extension HangulEngine.State {
    /// The same state with another 초성 (used when a held decision is switched).
    func withInitial(_ c: Character) -> Self {
        switch self {
        case .initial: return .initial(c)
        case .composingCV(_, let m): return .composingCV(initial: c, medial: m)
        case .composingCVC(_, let m, let f): return .composingCVC(initial: c, medial: m, final_: f)
        default: return self
        }
    }
}
