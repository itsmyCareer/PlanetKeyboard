import Foundation

protocol HangulLexiconProtocol {
    func contains(_ text: String) -> Bool
    func prefixScore(_ text: String) -> Int
    /// Best frequency of a word that starts with `first` and whose next syllable begins
    /// with the consonant `nextInitial` (e.g. 학 + ㄱ → 학교).
    func score(first: Character, nextInitial: Character) -> Int
}

/// A lightweight Korean word frequency lexicon for disambiguation
final class HangulLexicon: HangulLexiconProtocol {

    private var wordFrequency: [String: Int] = [:]

    init() {
        loadBuiltinLexicon()
    }

    func contains(_ text: String) -> Bool {
        wordFrequency[text] != nil
    }

    func prefixScore(_ text: String) -> Int {
        wordFrequency
            .filter { $0.key.hasPrefix(text) }
            .map { $0.value }
            .max() ?? 0
    }

    func score(first: Character, nextInitial: Character) -> Int {
        wordFrequency.compactMap { word, freq -> Int? in
            let chars = Array(word)
            guard chars.count >= 2, chars[0] == first,
                  let initial = Self.initial(of: chars[1]), initial == nextInitial else { return nil }
            return freq
        }.max() ?? 0
    }

    private static func initial(of syllable: Character) -> Character? {
        guard let scalar = syllable.unicodeScalars.first,
              (0xAC00...0xD7A3).contains(scalar.value) else { return nil }
        let index = Int(scalar.value - 0xAC00) / (21 * 28)
        return HangulJamo.initials[index]
    }

    private func loadBuiltinLexicon() {
        // Words where 받침 consonant == next 초성 consonant
        // These are the primary ambiguity patterns for ㄱ,ㄷ,ㅂ,ㅅ,ㅈ

        // ㄱ patterns
        let gWords: [(String, Int)] = [
            ("학교", 950), ("약국", 900), ("작곡", 700), ("국가", 850),
            ("식구", 750), ("직거래", 600), ("축구", 880), ("독감", 650),
            ("북극", 500), ("육군", 700), ("국기", 600), ("목걸이", 550),
            ("작가", 800), ("석굴", 400), ("각국", 450), ("박공", 300),
            ("적극", 700), ("격구", 300), ("흑곰", 350), ("먹거리", 650),
        ]

        // ㄷ patterns
        let dWords: [(String, Int)] = [
            ("믿다", 800), ("받다", 850), ("얻다", 750), ("닫다", 700),
            ("묻다", 650), ("걷다", 600), ("듣다", 900),
        ]

        // ㅂ patterns
        let bWords: [(String, Int)] = [
            ("갑부", 500), ("답변", 750), ("업무", 850), ("입법", 600),
            ("합법", 650), ("급변", 500), ("십분", 400), ("집밖", 350),
            ("잡비", 300), ("접빈", 250), ("갑비", 200),
        ]

        // ㅅ patterns
        let sWords: [(String, Int)] = [
            ("맛술", 300), ("옷색", 400), ("빗살", 350), ("못살", 500),
            ("겉속", 450), ("맞서다", 600), ("잇속", 350), ("낫설다", 250),
        ]

        // ㅈ patterns
        let jWords: [(String, Int)] = [
            ("맞짱", 200), ("낮잠", 500), ("밭주인", 300), ("빛줄기", 350),
        ]

        // Common words that actually USE 쌍자음 (NOT the ambiguity case)
        let doubleConsonantWords: [(String, Int)] = [
            ("가끔", 900), ("빨리", 950), ("쏘다", 600), ("빠르다", 850),
            ("써다", 500), ("찌개", 800), ("쓰다", 900), ("뜨다", 700),
            ("꼬리", 650), ("깨다", 700), ("또", 950), ("뿌리", 550),
            ("까닭", 600), ("꾸미다", 650), ("쩔다", 300),
            // 받침 자리에서 같은 자음을 두 번 눌러 쌍자음 초성이 되는 흔한 단어
            ("아빠", 980), ("오빠", 950), ("아까", 900), ("이따가", 850), ("바빠", 800),
            ("나빠", 750), ("기뻐", 750), ("예뻐", 800), ("아파", 300), ("어때", 900),
            ("이쁘다", 700), ("가끔", 900), ("오뚜기", 400), ("아저씨", 850), ("아가씨", 800),
            ("이써", 100), ("아직", 700),
        ]

        for list in [gWords, dWords, bWords, sWords, jWords, doubleConsonantWords] {
            for (word, freq) in list {
                wordFrequency[word] = freq
            }
        }
    }
}
