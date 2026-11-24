import Foundation

/// 단모음(Danmoeum) Hangul composer.
///
/// Rules:
/// - Same consonant tapped twice quickly → 쌍자음 (ㄱㄱ→ㄲ, ㅂㅂ→ㅃ ...).
/// - Same vowel tapped twice → 이중모음 (ㅏㅏ→ㅑ, ㅐㅐ→ㅒ ...). Inside a syllable there is no
///   time limit because the result is never ambiguous.
/// - 받침 + same consonant (학 + ㄱ) is ambiguous (학교 / 하꾜 / 밖). It is resolved by the
///   next key: a vowel asks the lexicon + timing, anything else keeps a doubled 받침 (있, 밖).
///
/// Every key returns `.update(commit:composing:)`: `commit` is text that can no longer change,
/// `composing` is the short tail (at most 2 characters) that may still be rewritten.
final class HangulEngine: InputEngine {

    let language: Language = .korean

    // MARK: - State

    enum State: Equatable {
        case empty
        case vowel(Character)
        case initial(Character)
        case composingCV(initial: Character, medial: Character)
        case composingCVC(initial: Character, medial: Character, final_: Character)
        case boundaryAmbiguous(BoundaryAmbiguity)
    }

    struct BoundaryAmbiguity: Equatable {
        let committedSyllable: Character   // CV part, e.g. 하
        let leftInitial: Character
        let leftMedial: Character
        let consonant: Character            // the plain consonant tapped twice, e.g. ㄱ
        let firstTapTime: CFTimeInterval
        let secondTapTime: CFTimeInterval
        var provisionalDecision: BoundaryDecision
    }

    enum BoundaryDecision: Equatable {
        case splitFinalPlainInitial   // 학 + 교
        case tenseInitial             // 하 + 꾜 / 이 + 써
    }

    private(set) var state: State = .empty
    private var pendingCommit: String = ""

    private let resolver: HangulAmbiguityResolver
    private let lexicon: HangulLexicon?

    /// Max gap between two taps of the same key that still counts as a double tap.
    static let defaultThresholdMs: Double = 400
    var doubleTapThresholdMs: Double = HangulEngine.defaultThresholdMs

    private var lastKey: Character?
    private var lastKeyTime: CFTimeInterval = 0

    init(resolver: HangulAmbiguityResolver = HangulAmbiguityResolver(),
         lexicon: HangulLexicon? = HangulLexicon()) {
        self.resolver = resolver
        self.lexicon = lexicon
    }

    // MARK: - InputEngine

    /// Text still being composed (what is currently tracked inline in the document).
    var compositionText: String { display(of: state) }

    var candidates: [String] { [] }

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
                handleConsonant(char, timestamp: key.timestamp)
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
        pendingCommit = ""
        lastKey = nil
    }

    // MARK: - Consonants

    private func handleConsonant(_ char: Character, timestamp: CFTimeInterval) {
        let isRepeat = isQuickRepeat(of: char, at: timestamp)

        switch state {
        case .empty:
            state = .initial(char)

        case .vowel:
            commitState()
            state = .initial(char)

        case .initial(let current):
            if current == char, isRepeat, let doubled = HangulJamo.doubled(char) {
                state = .initial(doubled)
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
            if final_ == char, isRepeat, HangulJamo.isDoubleable(char),
               let iIdx = HangulJamo.initialIndex(of: initial),
               let mIdx = HangulJamo.medialIndex(of: medial) {
                state = .boundaryAmbiguous(BoundaryAmbiguity(
                    committedSyllable: HangulJamo.composeSyllable(initial: iIdx, medial: mIdx),
                    leftInitial: initial,
                    leftMedial: medial,
                    consonant: char,
                    firstTapTime: lastKeyTime,
                    secondTapTime: timestamp,
                    provisionalDecision: resolver.provisionalDecision(
                        consonant: char, firstTapTime: lastKeyTime, secondTapTime: timestamp)
                ))
            } else if let compound = HangulJamo.combineConsonants(final_, char) {
                state = .composingCVC(initial: initial, medial: medial, final_: compound)
            } else {
                commitState()
                state = .initial(char)
            }

        case .boundaryAmbiguous(let ambiguity):
            settleAmbiguityWithoutVowel(ambiguity)
            handleConsonant(char, timestamp: timestamp)
        }
    }

    // MARK: - Vowels

    private func handleVowel(_ char: Character, timestamp: CFTimeInterval) {
        switch state {
        case .empty:
            state = .vowel(char)

        case .vowel(let current):
            if current == char, isQuickRepeat(of: char, at: timestamp),
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
                pendingCommit.append(syllable(initial, medial, split.stay))
                state = .composingCV(initial: split.move, medial: char)
            } else {
                pendingCommit.append(syllable(initial, medial, nil))
                state = .composingCV(initial: final_, medial: char)
            }

        case .boundaryAmbiguous(let ambiguity):
            let decision = resolver.resolve(ambiguity: ambiguity, nextInput: char, lexicon: lexicon)
            switch decision {
            case .splitFinalPlainInitial:
                pendingCommit.append(syllable(ambiguity.leftInitial, ambiguity.leftMedial, ambiguity.consonant))
                state = .composingCV(initial: ambiguity.consonant, medial: char)
            case .tenseInitial:
                pendingCommit.append(ambiguity.committedSyllable)
                state = .composingCV(initial: HangulJamo.doubled(ambiguity.consonant) ?? ambiguity.consonant,
                                     medial: char)
            }
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
            state = .empty
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
            pendingCommit.append(syllable(a.leftInitial, a.leftMedial, a.consonant))
            state = .initial(a.consonant)
        }
    }

    // MARK: - Helpers

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
        pendingCommit.append(display(of: state))
        state = .empty
    }

    private func isQuickRepeat(of char: Character, at timestamp: CFTimeInterval) -> Bool {
        lastKey == char && (timestamp - lastKeyTime) * 1000 < doubleTapThresholdMs
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
