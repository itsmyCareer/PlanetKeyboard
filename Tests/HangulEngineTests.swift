import XCTest

/// Document-level tests: what actually ends up in the text field.
final class HangulEngineTests: XCTestCase {

    private var h: HangulHarness!

    override func setUp() {
        h = HangulHarness()
    }

    // MARK: - Basic composition (가 must never show up as ㄱㅏ)

    func testGa() {
        h.type("ㄱㅏ")
        XCTAssertEqual(h.text, "가")
    }

    func testGaWithFastTyping() {
        h.type("ㄱㅏ", gap: 0.05)
        XCTAssertEqual(h.text, "가")
    }

    func testHanguk() {
        h.type("ㅎㅏㄴㄱㅜㄱ")
        XCTAssertEqual(h.text, "한국")
    }

    func testFinalMovesToNextSyllable() {
        h.type("ㅁㅓㄱ")
        XCTAssertEqual(h.text, "먹")
        h.type("ㅏ")
        XCTAssertEqual(h.text, "머가")
    }

    func testSentenceWithSpaces() {
        h.type("ㅇㅏㄴㄴㅕㅇ ㅎㅏㅅㅔㅇㅛ")
        // ㄴㄴ is not a doubleable consonant, ㅕ is typed via ㅓㅓ below; here ㅕ key doesn't
        // exist on the layout but the engine still accepts it.
        XCTAssertEqual(h.text, "안녕 하세요")
    }

    func testCompoundFinal() {
        h.type("ㄷㅏㄹㄱ")
        XCTAssertEqual(h.text, "닭")
        h.type("ㅇㅣ")
        XCTAssertEqual(h.text, "닭이")
    }

    func testCompoundFinalSplitsOnVowel() {
        h.type("ㄷㅏㄹㄱㅣ")
        XCTAssertEqual(h.text, "달기")
    }

    // MARK: - 단모음: double-tap vowels

    func testDoubleVowels() {
        let cases: [(String, String)] = [
            ("ㄱㅏㅏ", "갸"), ("ㅇㅓㅓ", "여"), ("ㄱㅗㅗ", "교"), ("ㅇㅜㅜ", "유"),
            ("ㄱㅐㅐ", "걔"), ("ㅇㅔㅔ", "예"),
        ]
        for (keys, expected) in cases {
            let harness = HangulHarness()
            harness.type(keys)
            XCTAssertEqual(harness.text, expected, keys)
        }
    }

    func testCompoundVowels() {
        let cases: [(String, String)] = [
            ("ㄱㅗㅏ", "과"), ("ㅇㅜㅓ", "워"), ("ㅇㅡㅣ", "의"), ("ㅇㅗㅐ", "왜"),
            ("ㅇㅗㅣ", "외"), ("ㅇㅜㅣ", "위"), ("ㄱㅜㅔ", "궤"),
        ]
        for (keys, expected) in cases {
            let harness = HangulHarness()
            harness.type(keys)
            XCTAssertEqual(harness.text, expected, keys)
        }
    }

    func testAIsNotTurnedIntoAe() {
        // ㅐ has its own key on 단모음, so ㅏ+ㅣ must not silently become ㅐ.
        h.type("ㅎㅏㅣ")
        XCTAssertEqual(h.text, "하ㅣ")
    }

    func testStandaloneVowelDoubleTap() {
        h.type("ㅜㅜ", gap: 0.1)
        XCTAssertEqual(h.text, "ㅠ")
    }

    func testStandaloneVowelSlowRepeat() {
        h.type("ㅜㅜ", gap: 0.8)
        XCTAssertEqual(h.text, "ㅜㅜ")
    }

    // MARK: - 단모음: double-tap consonants

    func testDoubleConsonantInitial() {
        let cases: [(String, String)] = [("ㅂ", "ㅃ"), ("ㅈ", "ㅉ"), ("ㄷ", "ㄸ"), ("ㄱ", "ㄲ"), ("ㅅ", "ㅆ")]
        for (key, expected) in cases {
            let harness = HangulHarness()
            harness.type(key + key, gap: 0.15)
            XCTAssertEqual(harness.text, expected, key)
        }
    }

    func testDoubleConsonantWithVowel() {
        h.type("ㅂ", gap: 0.6)
        h.type("ㅂ", gap: 0.15)
        h.type("ㅏ")
        XCTAssertEqual(h.text, "빠")
    }

    func testSlowRepeatIsTwoConsonants() {
        h.type("ㄱㄱ", gap: 0.8)
        XCTAssertEqual(h.text, "ㄱㄱ")
    }

    // MARK: - 받침 + same consonant

    func testHakgyo() {
        h.type("ㅎㅏㄱ")
        h.type("ㄱ", gap: 0.15)
        h.type("ㅛ")
        XCTAssertEqual(h.text, "학교")
    }

    func testHakgyoWithDoubleTapVowel() {
        h.type("ㅎㅏㄱ")
        h.type("ㄱ", gap: 0.15)
        h.type("ㅗ")
        h.type("ㅗ", gap: 0.15)
        XCTAssertEqual(h.text, "학교")
    }

    func testAppa() {
        h.type("ㅇㅏㅂ")
        h.type("ㅂ", gap: 0.15)
        h.type("ㅏ")
        XCTAssertEqual(h.text, "아빠")
    }

    func testItda() {
        h.type("ㅇㅣㅅ")
        h.type("ㅅ", gap: 0.15)
        XCTAssertEqual(h.text, "있")
        h.type("ㄷㅏ")
        XCTAssertEqual(h.text, "있다")
    }

    func testItseo() {
        h.type("ㅇㅣㅅ")
        h.type("ㅅ", gap: 0.15)
        h.type("ㅇㅓ")
        XCTAssertEqual(h.text, "있어")
    }

    func testBakThenSpace() {
        h.type("ㅂㅏㄱ")
        h.type("ㄱ", gap: 0.15)
        h.type(" ")
        XCTAssertEqual(h.text, "밖 ")
    }

    func testSlowSameConsonantAfterFinal() {
        h.type("ㅎㅏㄱㄱㅣ", gap: 0.8)
        XCTAssertEqual(h.text, "학기")
    }

    // MARK: - Backspace

    func testBackspaceStepsBackThroughSyllable() {
        h.type("ㄱㅏㄱ")
        h.type("⌫")
        XCTAssertEqual(h.text, "가")
        h.type("⌫")
        XCTAssertEqual(h.text, "ㄱ")
        h.type("⌫")
        XCTAssertEqual(h.text, "")
    }

    func testBackspaceUndoesDoubleVowel() {
        h.type("ㄱㅏㅏ")
        h.type("⌫")
        XCTAssertEqual(h.text, "가")
    }

    func testBackspaceAfterCommitDeletesWholeCharacter() {
        h.type("ㄱㅏ ")
        h.type("⌫")
        XCTAssertEqual(h.text, "가")
        h.type("⌫")
        XCTAssertEqual(h.text, "")
    }

    func testBackspaceOnEmptyDocumentIsHarmless() {
        h.type("⌫⌫")
        XCTAssertEqual(h.text, "")
    }

    // MARK: - Host / cursor changes

    func testCursorMoveNeverDeletesForeignText() {
        h.type("ㄱㅏ")
        // User moved the cursor somewhere else (the text before the cursor changed).
        h.doc.text = "hello"
        h.hostChanged()
        h.type("ㄴ")
        XCTAssertEqual(h.text, "helloㄴ")
    }

    func testOwnEditsKeepCompositionInSync() {
        h.type("ㄱㅏ")
        h.hostChanged()   // callback after our own insert: still in sync
        h.type("ㄴ")
        XCTAssertEqual(h.text, "간")
    }

    func testHostWithoutContextStillComposes() {
        h.doc.reportsContext = false
        h.type("ㅎㅏㄴㄱㅡㄹ")
        h.hostChanged()
        XCTAssertEqual(h.text, "한글")
    }

    // MARK: - Punctuation & numbers

    func testPunctuationCommits() {
        h.type("ㄱㅏ.")
        XCTAssertEqual(h.text, "가.")
        h.type("ㄴ")
        XCTAssertEqual(h.text, "가.ㄴ")
    }

    func testDigitsCommit() {
        h.type("ㄱㅏ1")
        XCTAssertEqual(h.text, "가1")
    }

    func testCompositionStaysShort() {
        h.type("ㅎㅏㄴㄱㅜㄱㅇㅓ")
        XCTAssertLessThanOrEqual(h.inline.tracked.count, 2)
        XCTAssertEqual(h.text, "한국어")
    }
}
