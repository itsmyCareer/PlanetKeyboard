import XCTest

/// Chinese input through librime + rime-ice + octagram (bundled RimeData).
final class RimeEngineTests: XCTestCase {

    private var engine: RimeEngine!

    override func setUp() {
        engine = makeRimeEngine()
    }

    override func tearDown() {
        engine.reset()
    }

    func testBundledDataIsFound() {
        XCTAssertNotNil(RimeRuntime.bundledDataPath, "RimeData must be in the bundle")
        XCTAssertNotNil(RimeRuntime.start())
    }

    // MARK: - What the user compared with the system keyboard

    func testAbbreviatedSentence() {
        engine.type("nzzsm")
        XCTAssertEqual(engine.candidates.first, "你在做什么", "\(engine.candidates.prefix(6))")
    }

    func testFullPinyinSentence() {
        engine.type("nizaizuoshenme")
        XCTAssertEqual(engine.candidates.first, "你在做什么", "\(engine.candidates.prefix(6))")
        XCTAssertEqual(engine.displayComposition, "ni zai zuo shen me")
    }

    func testSentenceNotInDictionary() {
        engine.type("wojintianhenmang")
        XCTAssertEqual(engine.candidates.first, "我今天很忙", "\(engine.candidates.prefix(6))")
    }

    func testCommonAbbreviations() {
        for (input, word) in [("nh", "你好"), ("wm", "我们"), ("xx", "谢谢"), ("sm", "什么")] {
            engine.reset()
            engine.type(input)
            XCTAssertEqual(engine.candidates.first, word, "\(input): \(engine.candidates.prefix(6))")
        }
    }

    func testSingleSyllable() {
        engine.type("wa")
        XCTAssertEqual(engine.candidates.first, "哇", "\(engine.candidates.prefix(6))")
    }

    // MARK: - Keys

    func testSpaceCommitsFirstCandidate() {
        engine.type("nihao")
        XCTAssertEqual(engine.press(.space), .insert("你好"))
        XCTAssertFalse(engine.isComposing)
    }

    func testReturnCommitsLetters() {
        engine.type("nihao")
        XCTAssertEqual(engine.press(.return_), .insert("nihao"))
    }

    func testBackspaceEditsInputThenDeletes() {
        engine.type("ni")
        XCTAssertEqual(engine.press(.backspace), .composing("n"))
        XCTAssertEqual(engine.press(.backspace), .composing(""))
        XCTAssertEqual(engine.press(.backspace), .delete)
    }

    func testSpaceWithoutInputIsSpace() {
        XCTAssertEqual(engine.press(.space), .insert(" "))
    }

    func testPunctuationCommitsBestCandidate() {
        engine.type("nihao")
        XCTAssertEqual(engine.press(.character(".")), .insert("你好。"))
    }

    func testPartialSelectionKeepsRest() {
        engine.type("nihaoma")
        let index = engine.candidates.firstIndex(of: "你好")!
        XCTAssertEqual(engine.selectCandidate(at: index), "")
        XCTAssertTrue(engine.isComposing, "ma is still composing")
        let ma = engine.candidates.firstIndex(of: "吗")!
        XCTAssertEqual(engine.selectCandidate(at: ma), "你好吗", "Rime commits the whole phrase")
    }

    func testCommitBestEndsComposition() {
        engine.type("nihao")
        XCTAssertEqual(engine.commitBest(), "你好")
        XCTAssertFalse(engine.isComposing)
        XCTAssertEqual(engine.commitBest(), "", "nothing to commit")
    }

    func testSelectOutOfRangeIsSafe() {
        XCTAssertEqual(engine.selectCandidate(at: 0), "")
        XCTAssertEqual(engine.selectCandidate(at: -1), "")
    }

    func testLookupIsFast() {
        measure {
            engine.reset()
            engine.type("nizaizuoshenme")
        }
    }
}
