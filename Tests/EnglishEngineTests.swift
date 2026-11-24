import XCTest

final class EnglishEngineTests: XCTestCase {
    var engine: EnglishEngine!

    override func setUp() {
        engine = EnglishEngine()
    }

    // MARK: - Character Input

    func testCharacterInput() {
        let result = engine.handleKey(makeKey(.character("A"), type: .character))
        XCTAssertEqual(result, .insert("a"))
    }

    func testMultipleCharacters() {
        let r1 = engine.handleKey(makeKey(.character("H"), type: .character))
        let r2 = engine.handleKey(makeKey(.character("I"), type: .character))
        XCTAssertEqual(r1, .insert("h"))
        XCTAssertEqual(r2, .insert("i"))
    }

    // MARK: - Shift

    func testShiftThenCharacter() {
        _ = engine.handleKey(makeKey(.shift, type: .shift))
        let result = engine.handleKey(makeKey(.character("A"), type: .character))
        XCTAssertEqual(result, .insert("A"))
    }

    func testShiftAutoRelease() {
        _ = engine.handleKey(makeKey(.shift, type: .shift))
        _ = engine.handleKey(makeKey(.character("A"), type: .character))
        let result = engine.handleKey(makeKey(.character("B"), type: .character))
        XCTAssertEqual(result, .insert("b"))
    }

    func testDoubleShiftToggle() {
        _ = engine.handleKey(makeKey(.shift, type: .shift))
        XCTAssertTrue(engine.isShifted)
        _ = engine.handleKey(makeKey(.shift, type: .shift))
        XCTAssertFalse(engine.isShifted)
    }

    func testShiftReturnsNone() {
        let result = engine.handleKey(makeKey(.shift, type: .shift))
        XCTAssertEqual(result, .none)
    }

    // MARK: - Special Keys

    func testBackspace() {
        let result = engine.handleKey(makeKey(.backspace, type: .backspace))
        XCTAssertEqual(result, .delete)
    }

    func testSpace() {
        let result = engine.handleKey(makeKey(.space, type: .space))
        XCTAssertEqual(result, .insert(" "))
    }

    func testReturn() {
        let result = engine.handleKey(makeKey(.return_, type: .returnKey))
        XCTAssertEqual(result, .insert("\n"))
    }

    func testLanguageReturnsNone() {
        let result = engine.handleKey(makeKey(.language, type: .language))
        XCTAssertEqual(result, .none)
    }

    func testNumbersReturnsNone() {
        let result = engine.handleKey(makeKey(.numbers, type: .numbers))
        XCTAssertEqual(result, .none)
    }

    // MARK: - Composition

    func testNoComposition() {
        XCTAssertEqual(engine.compositionText, "")
        XCTAssertTrue(engine.candidates.isEmpty)
    }

    func testSelectCandidateReturnsEmpty() {
        XCTAssertEqual(engine.selectCandidate(at: 0), "")
    }

    // MARK: - Reset

    func testReset() {
        _ = engine.handleKey(makeKey(.shift, type: .shift))
        XCTAssertTrue(engine.isShifted)
        engine.reset()
        XCTAssertFalse(engine.isShifted)

        let result = engine.handleKey(makeKey(.character("A"), type: .character))
        XCTAssertEqual(result, .insert("a"))
    }

    // MARK: - Language

    func testLanguageIsEnglish() {
        XCTAssertEqual(engine.language, .english)
    }

    // MARK: - Helpers

    private func makeKey(_ code: KeyCode, type: KeyType, timestamp: CFTimeInterval = 0) -> KeyEvent {
        let char: String?
        if case .character(let c) = code {
            char = c
        } else {
            char = nil
        }
        return KeyEvent(keyCode: code, character: char, timestamp: timestamp, type: type)
    }
}
