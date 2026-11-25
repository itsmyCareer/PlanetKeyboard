import Foundation

/// Decides 받침 + 초성 vs 쌍자음 when the same consonant is tapped twice after a vowel
/// (ㅂㅏㄱㄱㅜ → 박구 or 바꾸). Tap speed plays no part: the decision comes from how often each
/// reading occurs in Korean text (`hangul_pairs.tsv`, built by Tools/build_hangul_pairs.py).
///
/// Lookup order: left syllable + consonant + vowel key → left syllable + consonant (any vowel)
/// → `fallback` (쌍자음, the more common reading for every consonant in the data).
final class HangulAmbiguityResolver {

    struct Counts: Equatable {
        var split: Int    // 박 + 구
        var tense: Int    // 바 + 꾸
    }

    private var exact: [String: Counts] = [:]
    private var bySyllable: [String: Counts] = [:]

    /// `pairs` is the TSV text; nil loads `hangul_pairs.tsv` from the bundle.
    init(pairs: String? = nil) {
        let text = pairs ?? Self.bundledTable()
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t")
            guard fields.count == 3, let split = Int(fields[1]), let tense = Int(fields[2]) else { continue }
            let key = String(fields[0])
            exact[key] = Counts(split: split, tense: tense)
            let prefix = String(key.prefix(2))
            bySyllable[prefix, default: Counts(split: 0, tense: 0)].split += split
            bySyllable[prefix, default: Counts(split: 0, tense: 0)].tense += tense
        }
    }

    /// - Parameters:
    ///   - left: the syllable before the consonant as it stays with the 쌍자음 reading (바, 말, 직)
    ///   - consonant: the plain consonant tapped twice (ㄱ)
    ///   - vowel: the vowel typed after it (ㅜ; ㅠ / ㅝ count as ㅜ)
    ///   - fallback: the decision when the data has nothing (or a tie) for this syllable
    func decide(left: Character, consonant: Character, vowel: Character,
                fallback: HangulEngine.BoundaryDecision = .tenseInitial) -> HangulEngine.BoundaryDecision {
        let key = "\(left)\(consonant)"
        let counts = exact[key + String(Self.vowelKey(vowel))] ?? bySyllable[key]
        guard let counts, counts.split != counts.tense else { return fallback }
        return counts.split > counts.tense ? .splitFinalPlainInitial : .tenseInitial
    }

    /// The first key tapped for a vowel on 단모음: ㅛ ㅘ ㅚ → ㅗ, ㅠ ㅝ ㅟ → ㅜ, ㅢ → ㅡ ...
    static func vowelKey(_ vowel: Character) -> Character {
        HangulJamo.decomposeVowel(vowel) ?? vowel
    }

    private static func bundledTable() -> String {
        guard let url = Bundle(for: HangulAmbiguityResolver.self).url(forResource: "hangul_pairs", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }
}
