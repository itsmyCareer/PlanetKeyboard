import XCTest

final class LayoutTests: XCTestCase {

    private func labels(_ row: KeyRow) -> [String] {
        row.keys.filter { $0.type == .character && !$0.isSpacer }.map(\.label)
    }

    // MARK: - Letter pages

    func testDanmoeumLayoutMatchesSpec() {
        let rows = KoreanLayout().rows()
        XCTAssertEqual(labels(rows[0]), ["ㅂ", "ㅈ", "ㄷ", "ㄱ", "ㅅ", "ㅗ", "ㅐ", "ㅔ"])
        XCTAssertEqual(labels(rows[1]), ["ㅁ", "ㄴ", "ㅇ", "ㄹ", "ㅎ", "ㅓ", "ㅏ", "ㅣ"])
        XCTAssertEqual(labels(rows[2]), ["ㅋ", "ㅌ", "ㅊ", "ㅍ", "ㅜ", "ㅡ"])
        XCTAssertTrue(rows[2].keys.first!.isSpacer, "third row is indented like the reference")
        XCTAssertEqual(rows[2].keys.last?.code, .backspace)
        XCTAssertEqual(rows[0].columns, 8)
    }

    func testBottomRowIsNumbersLanguageSpaceReturn() {
        for layout in [KoreanLayout(), EnglishLayout(), ChineseLayout()] as [KeyboardLayout] {
            let bottom = layout.rows(bottom: .init(language: layout.language)).last!
            XCTAssertEqual(bottom.keys.map(\.code), [.numbers, .language, .space, .return_], "\(layout.language)")
            XCTAssertNil(layout.keyDefinition(for: .emoji), "emoji key removed (use the system globe)")
            XCTAssertNil(layout.keyDefinition(for: .character(".")), ".? key removed")
        }
    }

    func testChineseHasShiftForCapitals() {
        let rows = ChineseLayout().rows()
        XCTAssertEqual(rows[2].keys.first?.code, .shift)
        XCTAssertEqual(labels(rows[0]).first, "q")
        XCTAssertEqual(labels(ChineseLayout().rows(shifted: true)[0]).first, "Q")
    }

    func testEmailAndUrlBottomRows() {
        let email = BottomRow.letters(.init(language: .english, field: .email))
        XCTAssertEqual(email.keys.map(\.label).filter { ["@", "."].contains($0) }, ["@", "."])
        let url = BottomRow.letters(.init(language: .korean, field: .url))
        XCTAssertTrue(url.keys.contains { $0.label == ".com" })
        XCTAssertFalse(url.keys.contains { $0.code == .space })
    }

    func testReturnKeyStyles() {
        let search = BottomRow.returnKey(.init(language: .korean, returnStyle: .search), width: .standard)
        XCTAssertTrue(search.isAccent)
        XCTAssertEqual(search.icon, "magnifyingglass")
        let send = BottomRow.returnKey(.init(language: .korean, returnStyle: .send), width: .standard)
        XCTAssertEqual(send.label, "보내기")
        let disabled = BottomRow.returnKey(.init(language: .english, returnStyle: .go, returnEnabled: false), width: .standard)
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertFalse(disabled.isAccent)
    }

    // MARK: - Number pages (match the iOS keyboard of each language)

    func testKoreanNumberPages() {
        let numbers = NumberLayout.rows(page: .numbers, bottom: .init(language: .korean))
        XCTAssertEqual(labels(numbers[0]), ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
        XCTAssertEqual(labels(numbers[1]), ["-", "/", ":", ";", "(", ")", "₩", "&", "@", "\""])
        XCTAssertEqual(numbers[2].keys.first?.label, "#+=")
        XCTAssertEqual(labels(numbers[2]), [".", ",", "?", "!", "'"])
        XCTAssertEqual(numbers[3].keys.first?.label, "한글")

        let symbols = NumberLayout.rows(page: .symbols, bottom: .init(language: .korean))
        XCTAssertEqual(labels(symbols[0]), ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
        XCTAssertEqual(labels(symbols[1]), ["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "•"])
        XCTAssertEqual(symbols[2].keys.first?.label, "123")
    }

    func testEnglishAndChineseNumberPages() {
        XCTAssertEqual(NumberLayout.keys(page: .numbers, language: .english).1[6], "$")
        XCTAssertEqual(NumberLayout.keys(page: .symbols, language: .english).1,
                       ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"])
        let zh = NumberLayout.keys(page: .numbers, language: .chinese)
        XCTAssertEqual(zh.2, ["。", "，", "、", "？", "！", "."])
        XCTAssertEqual(NumberLayout.keys(page: .symbols, language: .chinese).0.first, "【")
        XCTAssertEqual(NumberLayout.rows(page: .numbers, bottom: .init(language: .chinese))[3].keys.first?.label, "拼音")
    }

    func testNumberPad() {
        let pad = NumberLayout.padRows(.number)
        XCTAssertEqual(pad.count, 4)
        XCTAssertEqual(pad.map(\.columns), [3, 3, 3, 3])
        XCTAssertEqual(pad[3].keys[1].label, "0")
        XCTAssertEqual(pad[3].keys.last?.code, .backspace)
    }

    func testKeyIdsAreUniquePerPage() {
        let pages = [KoreanLayout().rows(), EnglishLayout().rows(shifted: true), ChineseLayout().rows(),
                     NumberLayout.rows(page: .numbers, bottom: .init(language: .korean)),
                     NumberLayout.rows(page: .symbols, bottom: .init(language: .chinese))]
        for page in pages {
            let ids = page.flatMap(\.keys).filter { !$0.isSpacer }.map(\.id)
            XCTAssertEqual(ids.count, Set(ids).count)
        }
    }

    // MARK: - Geometry

    func testRowsFillTheWidthExactly() {
        let m = KeyboardMetrics.portrait
        let width: CGFloat = 420
        for page in [KoreanLayout().rows(), EnglishLayout().rows(), ChineseLayout().rows(),
                     NumberLayout.rows(page: .numbers, bottom: .init(language: .korean))] {
            for row in page {
                let frames = RowLayout.frames(for: row, width: width, y: 0, metrics: m)
                let visible = zip(row.keys, frames).filter { !$0.0.isSpacer }.map(\.1)
                // Indents are spacers, so the row (spacers included) spans the full width.
                XCTAssertEqual(frames.first!.minX, m.sidePadding, accuracy: 0.5)
                XCTAssertEqual(frames.last!.maxX, width - m.sidePadding, accuracy: 0.5)
                for (a, b) in zip(visible, visible.dropFirst()) {
                    XCTAssertEqual(b.minX - a.maxX, m.keyGap, accuracy: 0.5, "no overlaps, even gaps")
                }
            }
        }
    }

    func testDanmoeumKeysAreWiderThanQwerty() {
        let m = KeyboardMetrics.portrait
        let ko = RowLayout.frames(for: KoreanLayout().rows()[0], width: 420, y: 0, metrics: m)
        let en = RowLayout.frames(for: EnglishLayout().rows()[0], width: 420, y: 0, metrics: m)
        XCTAssertGreaterThan(ko[0].width, en[0].width)
    }

    func testHeightIsTheSameForEveryPage() {
        // Switching language/page must never resize the keyboard.
        let m = KeyboardMetrics.portrait
        let keys: CGFloat = m.keyHeight * 4 + m.rowGap * 3
        XCTAssertEqual(m.totalHeight, m.barHeight + m.topPadding + keys + m.bottomPadding)
        XCTAssertEqual(m.totalHeight, 257)
    }
}

final class LanguageSwitchTests: XCTestCase {

    func testGlobeCyclesAllLanguagesByDefault() {
        var s = LanguageSwitch(current: .english)
        var seen: [Language] = []
        for _ in 0..<3 { s.globe(); seen.append(s.current) }
        XCTAssertEqual(Set(seen), Set(Language.allCases))
        XCTAssertEqual(s.current, .english)
    }

    func testPairedGlobeFlipsKoreanAndEnglishOnly() {
        var s = LanguageSwitch(current: .korean, isPaired: true)
        s.globe()
        XCTAssertEqual(s.current, .english)
        XCTAssertEqual(s.baseLabel, "EN")
        s.globe()
        XCTAssertEqual(s.current, .korean)
        XCTAssertEqual(s.baseLabel, "한")
    }

    func testToggleFlipsBaseAndChinese() {
        var s = LanguageSwitch(current: .korean, isPaired: true)
        s.toggleChinese()
        XCTAssertEqual(s.current, .chinese)
        XCTAssertEqual(s.baseLabel, "한", "한 中 with 中 selected")
        s.toggleChinese()
        XCTAssertEqual(s.current, .korean)
    }

    func testGlobeFromChineseGoesToTheOtherBase() {
        var s = LanguageSwitch(current: .korean, isPaired: true)
        s.toggleChinese()           // 한 中 → 中
        s.globe()                   // → English, EN 中
        XCTAssertEqual(s.current, .english)
        XCTAssertEqual(s.baseLabel, "EN")
        s.toggleChinese()           // EN 中 → 中
        XCTAssertEqual(s.current, .chinese)
        s.toggleChinese()
        XCTAssertEqual(s.current, .english, "returns to EN, not 한")
    }

    func testStartingInChineseKeepsSavedBase() {
        let s = LanguageSwitch(current: .chinese, base: .english, isPaired: true)
        XCTAssertEqual(s.baseLabel, "EN")
        XCTAssertEqual(LanguageSwitch(current: .chinese, base: .chinese).base, .korean)
    }
}

final class TextEditingRulesTests: XCTestCase {

    func testSentenceAutoCapitalization() {
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(type: .sentences, before: ""))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(type: .sentences, before: "Hi. "))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(type: .sentences, before: "ok?  "))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(type: .sentences, before: "line\n"))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(type: .sentences, before: "Hi."))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(type: .sentences, before: "Hi there "))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(type: .none, before: ""))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(type: .words, before: "new "))
    }

    func testWordDeletion() {
        XCTAssertEqual(WordDeletion.count(before: "hello world"), 5)
        XCTAssertEqual(WordDeletion.count(before: "hello world  "), 7)
        XCTAssertEqual(WordDeletion.count(before: "안녕 하세요"), 3)
        XCTAssertEqual(WordDeletion.count(before: "wow!"), 1)
        XCTAssertEqual(WordDeletion.count(before: "ok 😂"), 1)
        XCTAssertEqual(WordDeletion.count(before: "   "), 3)
    }
}
