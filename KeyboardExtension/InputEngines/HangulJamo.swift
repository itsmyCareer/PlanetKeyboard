import Foundation

enum HangulJamo {

    // MARK: - Jamo Tables

    /// 초성 (Initial consonants) - 19 total, in Unicode Hangul Jamo order
    static let initials: [Character] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ",
        "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    /// 중성 (Medial vowels) - 21 total
    static let medials: [Character] = [
        "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ",
        "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ",
        "ㅡ", "ㅢ", "ㅣ"
    ]

    /// 종성 (Final consonants) - 28 total (index 0 = no final)
    static let finals: [Character?] = [
        nil,  "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ",
        "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ",
        "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
    ]

    // MARK: - Lookup Caches (built lazily)

    private static let initialIndexMap: [Character: Int] = {
        var map = [Character: Int]()
        for (i, ch) in initials.enumerated() { map[ch] = i }
        return map
    }()

    private static let medialIndexMap: [Character: Int] = {
        var map = [Character: Int]()
        for (i, ch) in medials.enumerated() { map[ch] = i }
        return map
    }()

    private static let finalIndexMap: [Character: Int] = {
        var map = [Character: Int]()
        for (i, ch) in finals.enumerated() {
            if let ch { map[ch] = i }
        }
        return map
    }()

    // MARK: - Index Lookups

    /// Get initial consonant index (0-18), returns nil if not a valid initial
    static func initialIndex(of char: Character) -> Int? {
        initialIndexMap[char]
    }

    /// Get medial vowel index (0-20)
    static func medialIndex(of char: Character) -> Int? {
        medialIndexMap[char]
    }

    /// Get final consonant index (1-27, 0=none)
    static func finalIndex(of char: Character) -> Int? {
        finalIndexMap[char]
    }

    // MARK: - Classification

    static func isConsonant(_ char: Character) -> Bool {
        initialIndexMap[char] != nil || finalIndexMap[char] != nil
    }

    static func isVowel(_ char: Character) -> Bool {
        medialIndexMap[char] != nil
    }

    // MARK: - Syllable Composition

    /// Compose a Hangul syllable from indices
    /// Formula: 0xAC00 + (initialIdx * 21 + medialIdx) * 28 + finalIdx
    static func composeSyllable(initial: Int, medial: Int, final finalIdx: Int = 0) -> Character {
        let code = 0xAC00 + (initial * 21 + medial) * 28 + finalIdx
        return Character(UnicodeScalar(code)!)
    }

    // MARK: - Double Consonants (쌍자음)

    private static let doubleMap: [Character: Character] = [
        "ㄱ": "ㄲ",
        "ㄷ": "ㄸ",
        "ㅂ": "ㅃ",
        "ㅅ": "ㅆ",
        "ㅈ": "ㅉ"
    ]

    /// Check if a consonant can form a double (쌍자음)
    static func isDoubleable(_ char: Character) -> Bool {
        doubleMap[char] != nil
    }

    /// Get the doubled version of a consonant
    static func doubled(_ char: Character) -> Character? {
        doubleMap[char]
    }

    // MARK: - Double Vowels (단모음: same vowel twice)

    private static let doubleVowelMap: [Character: Character] = [
        "ㅏ": "ㅑ", "ㅓ": "ㅕ", "ㅗ": "ㅛ", "ㅜ": "ㅠ", "ㅐ": "ㅒ", "ㅔ": "ㅖ"
    ]

    /// 단모음 배열에서 같은 모음을 두 번 누르면 만들어지는 모음 (ㅏ→ㅑ, ㅐ→ㅒ ...)
    static func doubledVowel(_ char: Character) -> Character? {
        doubleVowelMap[char]
    }

    /// Undo one keystroke of a vowel (ㅘ→ㅗ, ㅑ→ㅏ). Returns nil for a basic vowel.
    static func decomposeVowel(_ char: Character) -> Character? {
        guard !"ㅏㅓㅗㅜㅡㅣㅐㅔ".contains(char) else { return nil }
        if let base = doubleVowelMap.first(where: { $0.value == char })?.key { return base }
        return vowelCombinations.first(where: { $0.2 == char })?.0
    }

    // MARK: - Compound Vowels

    private static let vowelCombinations: [(Character, Character, Character)] = [
        ("ㅗ", "ㅏ", "ㅘ"),
        ("ㅗ", "ㅐ", "ㅙ"),
        ("ㅗ", "ㅣ", "ㅚ"),
        ("ㅜ", "ㅓ", "ㅝ"),
        ("ㅜ", "ㅔ", "ㅞ"),
        ("ㅜ", "ㅣ", "ㅟ"),
        ("ㅡ", "ㅣ", "ㅢ"),
        // ㅐ/ㅔ have their own keys on the 단모음 layout, so ㅏ+ㅣ is NOT turned into ㅐ.
    ]

    private static let vowelCombinationMap: [String: Character] = {
        var map = [String: Character]()
        for (first, second, result) in vowelCombinations {
            let key = "\(first)\(second)"
            map[key] = result
        }
        return map
    }()

    /// Returns the combined vowel if two vowels can combine, nil otherwise
    static func combineVowels(_ first: Character, _ second: Character) -> Character? {
        vowelCombinationMap["\(first)\(second)"]
    }

    // MARK: - Compound Finals (겹받침)

    private static let compoundFinals: [(Character, Character, Character)] = [
        ("ㄱ", "ㅅ", "ㄳ"),
        ("ㄴ", "ㅈ", "ㄵ"),
        ("ㄴ", "ㅎ", "ㄶ"),
        ("ㄹ", "ㄱ", "ㄺ"),
        ("ㄹ", "ㅁ", "ㄻ"),
        ("ㄹ", "ㅂ", "ㄼ"),
        ("ㄹ", "ㅅ", "ㄽ"),
        ("ㄹ", "ㅌ", "ㄾ"),
        ("ㄹ", "ㅍ", "ㄿ"),
        ("ㄹ", "ㅎ", "ㅀ"),
        ("ㅂ", "ㅅ", "ㅄ"),
    ]

    private static let compoundFinalMap: [String: Character] = {
        var map = [String: Character]()
        for (first, second, result) in compoundFinals {
            map["\(first)\(second)"] = result
        }
        return map
    }()

    private static let splitFinalMap: [Character: (stay: Character, move: Character)] = {
        var map = [Character: (stay: Character, move: Character)]()
        for (first, second, result) in compoundFinals {
            map[result] = (stay: first, move: second)
        }
        return map
    }()

    /// Check if two consonants can form a compound final (겹받침)
    static func combineConsonants(_ first: Character, _ second: Character) -> Character? {
        compoundFinalMap["\(first)\(second)"]
    }

    /// Check if a final consonant can split (for when next char is vowel)
    /// e.g., ㄳ → ㄱ + ㅅ (ㄱ stays as final, ㅅ becomes next initial)
    static func splitCompoundFinal(_ char: Character) -> (stay: Character, move: Character)? {
        splitFinalMap[char]
    }
}
