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

    func testDoubleConsonantBeforeVowelAtAnySpeed() {
        let cases: [(String, String)] = [("ㅂ", "빠"), ("ㅈ", "짜"), ("ㄷ", "따"), ("ㄱ", "까"), ("ㅅ", "싸")]
        for gap in [0.1, 0.9] {
            for (key, expected) in cases {
                let harness = HangulHarness()
                harness.type(key + key + "ㅏ", gap: gap)
                XCTAssertEqual(harness.text, expected, "\(key) gap \(gap)")
            }
        }
    }

    func testRepeatedConsonantsWithoutVowelStayAsTyped() {
        // Chat: ㅂㅂ, ㄷㄷ, ㅈㅈ, ㄱㄱ — even when tapped quickly.
        for keys in ["ㅂㅂ", "ㄷㄷ", "ㅈㅈ", "ㄱㄱ"] {
            let harness = HangulHarness()
            harness.type(keys + " ", gap: 0.1)
            XCTAssertEqual(harness.text, keys + " ", keys)
        }
        h.type("ㄱㄱ", gap: 0.1)
        XCTAssertEqual(h.text, "ㄱㄱ")
    }

    func testTripleConsonantPairsTheLastTwo() {
        h.type("ㄱㄱㄱㅏ")
        XCTAssertEqual(h.text, "ㄱ까")
    }

    // MARK: - 받침 + same consonant (no timing: the next key and word statistics decide)

    func testBakkwoAtAnySpeed() {
        for gap in [0.1, 0.9] {
            let harness = HangulHarness()
            harness.type("ㅂㅏㄱㄱㅜㅓ", gap: gap)
            XCTAssertEqual(harness.text, "바꿔", "gap \(gap)")
        }
    }

    func testBakkiyaAtAnySpeed() {
        // A consonant after ㄱㄱ makes it a doubled 받침, never 박ㄱ.
        for gap in [0.1, 0.9] {
            let harness = HangulHarness()
            harness.type("ㅂㅏㄱㄱㅇㅣㅇㅏㅏ", gap: gap)
            XCTAssertEqual(harness.text, "밖이야", "gap \(gap)")
        }
    }

    func testCommonSplitWords() {
        let cases: [(String, String)] = [
            ("ㅁㅓㄱㄱㅗ", "먹고"), ("ㅎㅏㄱㄱㅗㅗ", "학교"), ("ㅎㅏㄱㄱㅣ", "학기"), ("ㅂㅏㄱㄱㅗ", "박고"),
        ]
        for (keys, expected) in cases {
            let harness = HangulHarness()
            harness.type(keys, gap: 0.9)
            XCTAssertEqual(harness.text, expected, keys)
        }
    }

    func testCommonTenseWords() {
        let cases: [(String, String)] = [
            ("ㅇㅏㅂㅂㅏ", "아빠"), ("ㅇㅗㅂㅂㅏ", "오빠"), ("ㅇㅏㄱㄱㅏ", "아까"), ("ㅇㅖㅂㅂㅓ", "예뻐"),
            ("ㄴㅏㅂㅂㅏ", "나빠"), ("ㅇㅣㄷㄷㅏ", "이따"),
        ]
        for (keys, expected) in cases {
            let harness = HangulHarness()
            harness.type(keys, gap: 0.1)
            XCTAssertEqual(harness.text, expected, keys)
        }
    }

    func testAlternativeSwapsTheDecision() {
        h.type("ㅂㅏㄱㄱㅗ")
        XCTAssertEqual(h.text, "박고")
        XCTAssertEqual(h.engine.ambiguityAlternative, "바꼬")
        h.swap()
        XCTAssertEqual(h.text, "바꼬")
        XCTAssertEqual(h.engine.ambiguityAlternative, "박고")
        h.type("ㅁ ")
        XCTAssertEqual(h.text, "바꼼 ")
        XCTAssertNil(h.engine.ambiguityAlternative)
    }

    func testAlternativeEndsWithTheSyllable() {
        h.type("ㅂㅏㄱㄱㅜㅓ")
        XCTAssertEqual(h.engine.ambiguityAlternative, "박궈")
        h.type("ㅇ")
        XCTAssertEqual(h.engine.ambiguityAlternative, "박궝")
        h.type("ㅛ")    // 바꿔 + 요: the 받침 moved on, the decision is final
        XCTAssertNil(h.engine.ambiguityAlternative)
    }

    func testBackspaceReturnsToTheAmbiguity() {
        h.type("ㅂㅏㄱㄱㅜ")
        XCTAssertEqual(h.text, "바꾸")
        h.type("⌫")
        XCTAssertEqual(h.text, "바ㄲ")
        h.type("⌫")
        XCTAssertEqual(h.text, "밖")
        h.type("⌫")
        XCTAssertEqual(h.text, "박")
        h.type("ㅣ")
        XCTAssertEqual(h.text, "바기")
    }

    func testItda() {
        h.type("ㅇㅣㅅㅅ")
        XCTAssertEqual(h.text, "있")
        h.type("ㄷㅏ")
        XCTAssertEqual(h.text, "있다")
    }

    func testItseo() {
        h.type("ㅇㅣㅅㅅㅇㅓ")
        XCTAssertEqual(h.text, "있어")
    }

    func testBakThenSpace() {
        h.type("ㅂㅏㄱㄱ ")
        XCTAssertEqual(h.text, "밖 ")
    }

    // MARK: - 받침 that could take the consonant (겹받침 / 쌍받침) + 쌍자음

    func testTenseAfterCompoundCapableFinal() {
        let cases: [(String, String)] = [
            ("ㅁㅏㄹㅅㅅㅡㅁ", "말씀"), ("ㅈㅣㄴㅈㅈㅏ", "진짜"), ("ㅎㅏㄹㄱㄱㅏ", "할까"),
            ("ㅂㅓㄹㅅㅅㅓ", "벌써"), ("ㄱㅡㄹㅅㅅㅔ", "글쎄"), ("ㅇㅗㅣㄴㅈㅈㅗㄱ", "왼쪽"),
        ]
        for (keys, expected) in cases {
            let harness = HangulHarness()
            harness.type(keys)
            XCTAssertEqual(harness.text, expected, keys)
        }
    }

    func testCompoundFinalStillWinsWhereItIsTheWord() {
        let cases: [(String, String)] = [
            ("ㅇㅓㅂㅅㅅㅡㅂㄴㅣㄷㅏ", "없습니다"), ("ㅇㅣㄹㄱㄱㅗ", "읽고"), ("ㅇㅏㄴㅈㅈㅣ", "앉지"),
        ]
        for (keys, expected) in cases {
            let harness = HangulHarness()
            harness.type(keys)
            XCTAssertEqual(harness.text, expected, keys)
        }
    }

    func testCompoundAmbiguityWithoutVowelKeepsTheKeys() {
        h.type("ㅁㅏㄹㅅㅅ")
        XCTAssertEqual(h.text, "맔ㅅ")
        h.type("⌫")
        XCTAssertEqual(h.text, "맔")
        h.type("ㅅㅡ")
        XCTAssertEqual(h.text, "말쓰")
        XCTAssertEqual(h.engine.ambiguityAlternative, "맔스")
        h.swap()
        XCTAssertEqual(h.text, "맔스")
    }

    func testThirdTapLetsTheWordDecide() {
        let cases: [(String, String)] = [
            ("ㅇㅏㅈㅣㄱㄱㄱㅏㅈㅣ", "아직까지"), ("ㄱㅏㅅㅅㅅㅡㅂㄴㅣㄷㅏ", "갔습니다"),
            ("ㅎㅐㅅㅅㅅㅡㅂㄴㅣㄷㅏ", "했습니다"), ("ㄷㅏㄱㄱㄱㅗ", "닦고"),
        ]
        for (keys, expected) in cases {
            let harness = HangulHarness()
            harness.type(keys)
            XCTAssertEqual(harness.text, expected, keys)
        }
    }

    func testThirdTapBackspaceAndConsonant() {
        h.type("ㅈㅣㄱㄱㄱ")
        XCTAssertEqual(h.text, "짂ㄱ")
        h.type("⌫")
        XCTAssertEqual(h.text, "짂")
        h.type("ㄷㅏ")
        XCTAssertEqual(h.text, "짂다")
    }

    func testResolverFallsBackToSyllableThenTense() {
        let resolver = HangulAmbiguityResolver(pairs: "# test\n하ㄱㅗ\t50\t1\n하ㄱㅏ\t5\t1\n")
        XCTAssertEqual(resolver.decide(left: "하", consonant: "ㄱ", vowel: "ㅛ"), .splitFinalPlainInitial)
        XCTAssertEqual(resolver.decide(left: "하", consonant: "ㄱ", vowel: "ㅣ"), .splitFinalPlainInitial)
        XCTAssertEqual(resolver.decide(left: "아", consonant: "ㅂ", vowel: "ㅏ"), .tenseInitial)
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

    func testLateHostReportKeepsComposition() {
        // Fast typing: after 끄 → 끈 the host still reports the old text (끄).
        h.type("ㄱㄱㅡㄴ", gap: 0.08)
        h.doc.reportedOverride = "끄"
        h.hostChanged()
        h.doc.reportedOverride = nil
        h.type("ㅎ", gap: 0.08)
        XCTAssertEqual(h.text, "끊")
    }

    func testMidEditHostReportKeepsComposition() {
        // The report arrives between our delete (끄 removed) and insert (끈).
        h.type("ㅈㅓㄴㅎㅘ ㄱㄱㅡㄴ", gap: 0.08)
        h.doc.reportedOverride = "전화 "
        h.hostChanged()
        h.doc.reportedOverride = nil
        h.type("ㅎㅇㅓㅇㅏㅏ", gap: 0.08)
        XCTAssertEqual(h.text, "전화 끊어야")
    }

    func testOldReportAfterAPauseIsACursorMove() {
        h.type("ㄱㄱㅡㄴ")
        h.wait(2)
        h.doc.reportedOverride = "끄"
        h.hostChanged()
        h.doc.reportedOverride = nil
        h.type("ㅎ")
        XCTAssertEqual(h.text, "끈ㅎ")
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
