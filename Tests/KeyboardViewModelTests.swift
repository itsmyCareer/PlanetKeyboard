import XCTest

final class KeyboardViewModelTests: XCTestCase {

    func testCandidatesAreComposingAndKeepOrder() {
        let vm = KeyboardViewModel()
        vm.showCandidates(["你好", "女孩", "👋"])
        XCTAssertTrue(vm.isComposing)
        XCTAssertEqual(vm.suggestions.map(\.text), ["你好", "女孩", "👋"])
        XCTAssertEqual(vm.suggestions.map(\.isEmoji), [false, false, true])
        XCTAssertEqual(vm.suggestions.map(\.id), [0, 1, 2], "id is the candidate index")
    }

    func testEmojiSuggestionsAreNotComposing() {
        let vm = KeyboardViewModel()
        vm.isExpanded = true
        vm.showEmoji(["😂", "🤣"])
        XCTAssertFalse(vm.isComposing)
        XCTAssertFalse(vm.isExpanded)
        XCTAssertTrue(vm.suggestions.allSatisfy(\.isEmoji))
    }

    func testEmptyCandidatesCollapseGrid() {
        let vm = KeyboardViewModel()
        vm.showCandidates(["你"])
        vm.isExpanded = true
        vm.showCandidates([])
        XCTAssertFalse(vm.isExpanded)
        XCTAssertFalse(vm.isComposing)
    }

    func testClear() {
        let vm = KeyboardViewModel()
        vm.showCandidates(["你"])
        vm.clear()
        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertFalse(vm.isComposing)
    }

    func testThemeUpdate() {
        let vm = KeyboardViewModel()
        XCTAssertEqual(vm.currentTheme, .defaultLight)
        vm.updateTheme(.dark)
        XCTAssertEqual(vm.currentTheme, .dark)
    }
}
