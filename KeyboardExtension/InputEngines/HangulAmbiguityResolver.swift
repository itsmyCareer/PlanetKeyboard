import Foundation

struct AmbiguityConfig: Codable {
    /// Below this gap a double tap at a 받침 is provisionally read as 쌍자음 (아빠);
    /// a slower second tap is read as 받침 + 초성 (압박). The lexicon can override both.
    var doubleTapThresholdMs: Int = 250
    var undoWindowMs: Int = 500
    var adaptiveEnabled: Bool = false
}

final class HangulAmbiguityResolver {

    private var config: AmbiguityConfig

    init(config: AmbiguityConfig = AmbiguityConfig()) {
        self.config = config
    }

    /// Determine provisional decision based on timing
    func provisionalDecision(
        consonant: Character,
        firstTapTime: CFTimeInterval,
        secondTapTime: CFTimeInterval
    ) -> HangulEngine.BoundaryDecision {
        let intervalMs = (secondTapTime - firstTapTime) * 1000
        if intervalMs < Double(config.doubleTapThresholdMs) {
            return .tenseInitial
        } else {
            return .splitFinalPlainInitial
        }
    }

    /// Final resolution when next input arrives (vowel/delimiter)
    func resolve(
        ambiguity: HangulEngine.BoundaryAmbiguity,
        nextInput: Character?,
        lexicon: HangulLexiconProtocol?
    ) -> HangulEngine.BoundaryDecision {
        var decision = ambiguity.provisionalDecision

        guard let lexicon, let nextInput else { return decision }

        let initial = ambiguity.leftInitial
        let medial = ambiguity.leftMedial
        let consonant = ambiguity.consonant

        guard let initIdx = HangulJamo.initialIndex(of: initial),
              let medIdx = HangulJamo.medialIndex(of: medial),
              let finIdx = HangulJamo.finalIndex(of: consonant),
              HangulJamo.isVowel(nextInput) else {
            return decision
        }

        // Compare by the *initial* of the next syllable only (not the vowel), because on
        // 단모음 the vowel may still change with a double tap (ㅗ → ㅛ in 학교).
        // Option A: 학 + ㄱ...  (split)      Option B: 하 + ㄲ... (tense initial)
        let cvcSyllable = HangulJamo.composeSyllable(initial: initIdx, medial: medIdx, final: finIdx)
        guard let doubled = HangulJamo.doubled(consonant) else {
            return .splitFinalPlainInitial
        }
        let cvSyllable = HangulJamo.composeSyllable(initial: initIdx, medial: medIdx)

        let scoreA = lexicon.score(first: cvcSyllable, nextInitial: consonant)
        let scoreB = lexicon.score(first: cvSyllable, nextInitial: doubled)

        // Only override timing decision if lexicon has a clear preference
        let threshold = 100
        if scoreA > scoreB + threshold {
            decision = .splitFinalPlainInitial
        } else if scoreB > scoreA + threshold {
            decision = .tenseInitial
        }

        return decision
    }

    /// Record a user correction for adaptive learning (v2)
    func registerCorrection(
        consonant: Character,
        wasDecision: HangulEngine.BoundaryDecision,
        correctedTo: HangulEngine.BoundaryDecision
    ) {
        // For v1: no-op. Adaptive learning in v2.
    }
}
