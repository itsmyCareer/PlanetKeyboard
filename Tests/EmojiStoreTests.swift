import XCTest

final class EmojiStoreTests: XCTestCase {

    private var store: EmojiStore!
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "EmojiStoreTests")
        defaults.removePersistentDomain(forName: "EmojiStoreTests")
        store = EmojiStore(path: EmojiStore.bundledPath, maxVersion: 16.0, defaults: defaults)
    }

    override func tearDown() {
        store.close()
        defaults.removePersistentDomain(forName: "EmojiStoreTests")
    }

    func testBundledDatabaseIsFound() {
        XCTAssertNotNil(EmojiStore.bundledPath)
    }

    // MARK: - Normalizing & tokenizing

    func testNormalizeCollapsesLaughter() {
        XCTAssertEqual(EmojiStore.normalize("ㅋㅋㅋㅋㅋ"), "ㅋㅋ")
        XCTAssertEqual(EmojiStore.normalize("ㅎㅎㅎ"), "ㅎㅎ")
        XCTAssertEqual(EmojiStore.normalize("HAHAHA"), "haha")
        XCTAssertEqual(EmojiStore.normalize("hahah"), "haha")
        XCTAssertEqual(EmojiStore.normalize("哈哈哈哈"), "哈哈")
        XCTAssertEqual(EmojiStore.normalize("lol"), "lol")
        XCTAssertEqual(EmojiStore.normalize("사랑"), "사랑")
    }

    func testTrailingTokenSplitsByScript() {
        XCTAssertEqual(EmojiStore.trailingToken(of: "좋아ㅋㅋㅋ")?.text, "ㅋㅋㅋ")
        XCTAssertEqual(EmojiStore.trailingToken(of: "오늘 정말 사랑해요")?.text, "사랑해요")
        XCTAssertEqual(EmojiStore.trailingToken(of: "that was lol")?.text, "lol")
        XCTAssertEqual(EmojiStore.trailingToken(of: "我们哈哈")?.script, .han)
        XCTAssertNil(EmojiStore.trailingToken(of: "끝 "))
        XCTAssertNil(EmojiStore.trailingToken(of: ""))
    }

    // MARK: - Suggestions (ko / en / zh)

    func testLaughterInAllLanguages() {
        for context in ["ㅋㅋㅋ", "좋아ㅋㅋㅋㅋ", "haha", "hahaha", "lol", "LOL", "哈哈", "哈哈哈", "嘿嘿"] {
            let suggestions = store.suggestions(forContext: context)
            XCTAssertFalse(suggestions.isEmpty, context)
            XCTAssertTrue(suggestions.contains("😂") || suggestions.contains("😁"), "\(context): \(suggestions)")
        }
    }

    func testCryingAndLove() {
        XCTAssertEqual(store.suggestions(forContext: "ㅠㅠ").first, "😭")
        XCTAssertTrue(store.suggestions(forContext: "사랑해요").contains("❤️"))
        XCTAssertTrue(store.suggestions(forContext: "我爱你").contains("❤️"))
        XCTAssertTrue(store.suggestions(forContext: "love").contains("❤️"))
    }

    func testCldrKeywordsInEachLanguage() {
        XCTAssertTrue(store.suggestions(forContext: "고양이").contains("🐈"))
        XCTAssertTrue(store.suggestions(forContext: "cats").contains("🐈"))
        XCTAssertTrue(store.suggestions(forContext: "猫").contains("🐈"))
        XCTAssertEqual(store.suggestions(forContext: "피자").first, "🍕")
        XCTAssertTrue(store.suggestions(forContext: "한국").contains("🇰🇷"))
    }

    func testNoSuggestionsAfterSpace() {
        XCTAssertTrue(store.suggestions(forContext: "ㅋㅋㅋ ").isEmpty)
    }

    func testVersionFilterHidesNewEmoji() {
        let old = EmojiStore(path: EmojiStore.bundledPath, maxVersion: 1.0, defaults: defaults)
        XCTAssertLessThan(old.emojis(in: .smileys).count, store.emojis(in: .smileys).count)
    }

    // MARK: - Keyboard pages

    func testCategoriesHaveEmoji() {
        for category in EmojiStore.Category.allCases where category != .recent {
            XCTAssertFalse(store.emojis(in: category).isEmpty, category.rawValue)
        }
        XCTAssertEqual(store.emojis(in: .smileys).first, "😀")
    }

    func testRecentsAreMostRecentFirstAndUnique() {
        store.recordUse("😂")
        store.recordUse("❤️")
        store.recordUse("😂")
        XCTAssertEqual(store.emojis(in: .recent), ["😂", "❤️"])
    }

    func testRecentsAreCapped() {
        for e in store.emojis(in: .food).prefix(40) { store.recordUse(e) }
        XCTAssertEqual(store.recents.count, EmojiStore.maxRecents)
    }

    // MARK: - Chinese candidate bar

    func testEmojiMixedIntoPinyinCandidates() {
        let engine = makeRimeEngine()
        defer { engine.reset() }
        engine.emojiProvider = { [store] word in store!.specific(word) }
        engine.type("haha")
        XCTAssertEqual(engine.candidates.first, "哈哈")
        XCTAssertTrue(engine.candidates.prefix(5).contains("😂"), "\(engine.candidates.prefix(5))")

        let index = engine.candidates.firstIndex(of: "😂")!
        XCTAssertEqual(engine.selectCandidate(at: index), "😂")
        XCTAssertEqual(engine.compositionText, "", "emoji replaces the whole pinyin buffer")
    }
}

