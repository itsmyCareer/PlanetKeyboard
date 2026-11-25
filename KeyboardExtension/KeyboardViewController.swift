import UIKit
import SwiftUI
import Combine

final class KeyboardViewController: UIInputViewController {

    // MARK: - State

    enum Mode: Equatable {
        case letters, numbers, symbols
        case pad(NumberLayout.PadKind)
    }

    private var languages = LanguageSwitch(current: .korean)
    private var currentLanguage: Language { languages.current }
    private var mode: Mode = .letters
    /// Chinese shift: capital letters are typed as they are (NH), not as Pinyin.
    private var chineseShift: EnglishEngine.ShiftState = .off

    private let emojiStore = EmojiStore()
    private let englishEngine = EnglishEngine()
    private let hangulEngine = HangulEngine()
    private let pinyinEngine = RimeEngine()
    private let layouts: [Language: KeyboardLayout] = [
        .english: EnglishLayout(), .korean: KoreanLayout(), .chinese: ChineseLayout(),
    ]
    private let inline = InlineComposition()
    private lazy var document = ProxyDocument(controller: self)

    // UI
    private let model = KeyboardViewModel()
    private let keysView = KeysView()
    private var barHost: UIHostingController<SuggestionBarView>?
    private var gridHost: UIHostingController<CandidateGridView>?
    private var heightConstraint: NSLayoutConstraint?
    private var barHeightConstraint: NSLayoutConstraint?
    private var metrics = KeyboardMetrics.portrait
    /// Key size settings per language, read when the keyboard appears.
    private var keyScales: [Language: Double] = [:]
    private var cancellables = Set<AnyCancellable>()

    /// Pinyin shown in the text field as marked (underlined) text while composing.
    private var markedText: String?
    private var lastSpaceTime: CFTimeInterval = 0
    private var lastShiftTime: CFTimeInterval = 0
    private var lastTraits: FieldTraits?

    private var currentEngine: InputEngine {
        switch currentLanguage {
        case .english: return englishEngine
        case .korean: return hangulEngine
        case .chinese: return pinyinEngine
        }
    }

    private var isPinyinComposing: Bool {
        currentLanguage == .chinese && !pinyinEngine.buffer.isEmpty
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        pinyinEngine.emojiProvider = { [emojiStore] word in emojiStore.specific(word) }
        languages = LanguageSwitch(current: KeyboardPreferences.preferredLanguage ?? .korean,
                                   base: KeyboardPreferences.baseLanguage ?? .korean)
        buildViews()
        bindModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        HapticManager.shared.hasFullAccess = hasFullAccess
        HapticManager.shared.attach(to: view)
        HapticManager.shared.loadSettings()
        HapticManager.shared.prepare()
        languages.isPaired = KeyboardPreferences.isPairedLanguageMode
        keyScales = Dictionary(uniqueKeysWithValues: Language.allCases.map { ($0, KeyboardPreferences.keyScale(for: $0)) })
        ThemeManager.shared.loadTheme()
        model.updateTheme(ThemeManager.shared.currentTheme)
        applyTraits(force: true)
        updateMetrics()
        refreshSuggestions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if markedText != nil {
            // Keep what was typed as plain letters ("nzzsm", not the spaced display "n z z s m").
            let raw = pinyinEngine.buffer
            textDocumentProxy.setMarkedText(raw, selectedRange: NSRange(location: (raw as NSString).length, length: 0))
            textDocumentProxy.unmarkText()
        }
        markedText = nil
        chineseShift = .off
        resetEngines()
        HapticManager.shared.suspend()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Stay well under the extension memory limit: drop SQLite caches & generators.
        emojiStore.close()
        HapticManager.shared.suspend()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.updateMetrics(for: size) })
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateMetrics()
    }

    // MARK: - Host text changes

    override func selectionDidChange(_ textInput: (any UITextInput)?) {
        super.selectionDidChange(textInput)
        abandonCompositionIfOutOfSync()
        refreshSuggestions()
    }

    override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        abandonCompositionIfOutOfSync()
        applyTraits(force: false)       // the user may have moved to another field
        updateAutoCapitalization()
        refreshLayout()
        refreshSuggestions()
    }

    /// The user moved the cursor or the host changed the text: never delete characters that
    /// are no longer our composition — keep them as committed text instead.
    private func abandonCompositionIfOutOfSync() {
        if inline.isActive, !inline.isInSync(with: document) {
            inline.reset()
            hangulEngine.reset()
        }
        if let marked = markedText, let before = textDocumentProxy.documentContextBeforeInput,
           !before.hasSuffix(marked) {
            // The host committed our marked pinyin (tap elsewhere): start over.
            markedText = nil
            pinyinEngine.reset()
        }
    }

    // MARK: - Views

    private func buildViews() {
        let bar = UIHostingController(rootView: SuggestionBarView(model: model, height: metrics.barHeight))
        let grid = UIHostingController(rootView: CandidateGridView(model: model))
        for host in [bar, grid] as [UIViewController] {
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            addChild(host)
            view.addSubview(host.view)
            host.didMove(toParent: self)
        }
        bar.sizingOptions = []
        grid.sizingOptions = []
        if #available(iOS 16.4, *) {
            bar.safeAreaRegions = []
            grid.safeAreaRegions = []
        }
        keysView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(keysView, belowSubview: grid.view)
        grid.view.isHidden = true

        let barHeight = bar.view.heightAnchor.constraint(equalToConstant: metrics.barHeight)
        NSLayoutConstraint.activate([
            bar.view.topAnchor.constraint(equalTo: view.topAnchor),
            bar.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barHeight,
            keysView.topAnchor.constraint(equalTo: bar.view.bottomAnchor),
            keysView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keysView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keysView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            grid.view.topAnchor.constraint(equalTo: keysView.topAnchor),
            grid.view.leadingAnchor.constraint(equalTo: keysView.leadingAnchor),
            grid.view.trailingAnchor.constraint(equalTo: keysView.trailingAnchor),
            grid.view.bottomAnchor.constraint(equalTo: keysView.bottomAnchor),
        ])
        // One fixed height for every language and page: the keyboard never jumps.
        let height = view.heightAnchor.constraint(equalToConstant: metrics.totalHeight)
        height.priority = UILayoutPriority(999)
        height.isActive = true
        heightConstraint = height
        barHeightConstraint = barHeight
        barHost = bar
        gridHost = grid

        keysView.onKeyDown = { key in
            if key.type == .character { HapticManager.shared.triggerKeyTap() }
            else { HapticManager.shared.triggerSpecialKey() }
        }
        keysView.onKey = { [weak self] key in self?.handle(key) }
        keysView.onBackspaceRepeat = { [weak self] step in self?.repeatBackspace(step) }
        keysView.onTrackpad = { [weak self] active in self?.trackpadChanged(active) }
        keysView.onCursorMove = { [weak self] steps in self?.moveCursor(by: steps) }
        keysView.canStartTrackpad = { [weak self] in !(self?.isPinyinComposing ?? true) }
    }

    private func bindModel() {
        model.onSelect = { [weak self] item in self?.selectSuggestion(item) }
        model.onToggleLanguage = { [weak self] in
            HapticManager.shared.triggerSpecialKey()
            self?.changeLanguage { $0.toggleChinese() }
        }
        model.onAlternative = { [weak self] in
            guard let self, let result = self.hangulEngine.swapAmbiguity() else { return }
            HapticManager.shared.triggerKeyTap()
            self.apply(result)
            self.refreshSuggestions()
        }
        model.onDismiss = { [weak self] in
            self?.commitComposition()
            self?.dismissKeyboard()
        }
        model.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                // The grid replaces the keys (same area, system background), like the system keyboard.
                self?.gridHost?.view.isHidden = !expanded
                self?.keysView.isHidden = expanded
            }
            .store(in: &cancellables)
    }

    private func updateMetrics(for size: CGSize? = nil) {
        let landscape: Bool
        if let size, size.width > 0 {
            landscape = size.width > size.height
        } else {
            landscape = traitCollection.verticalSizeClass == .compact
        }
        let new = KeyboardMetrics.make(landscape: landscape, scale: keyScales[currentLanguage] ?? 1)
        guard new != metrics || heightConstraint?.constant != new.totalHeight else { return }
        metrics = new
        keysView.metrics = new
        heightConstraint?.constant = new.totalHeight
        barHeightConstraint?.constant = new.barHeight
        barHost?.rootView = SuggestionBarView(model: model, height: new.barHeight)
    }

    // MARK: - Text field traits

    private struct FieldTraits: Equatable {
        var keyboardType: UIKeyboardType
        var returnKeyType: UIReturnKeyType
        var appearance: UIKeyboardAppearance
    }

    private func applyTraits(force: Bool) {
        let proxy = textDocumentProxy
        let traits = FieldTraits(keyboardType: proxy.keyboardType ?? .default,
                                 returnKeyType: proxy.returnKeyType ?? .default,
                                 appearance: proxy.keyboardAppearance ?? .default)
        guard force || traits != lastTraits else { return }
        let typeChanged = traits.keyboardType != lastTraits?.keyboardType
        lastTraits = traits

        if force || typeChanged {
            switch traits.keyboardType {
            case .numberPad, .asciiCapableNumberPad: mode = .pad(.number)
            case .decimalPad: mode = .pad(.decimal)
            case .phonePad: mode = .pad(.phone)
            case .numbersAndPunctuation: mode = .numbers
            default: mode = .letters
            }
        }
        overrideUserInterfaceStyle = traits.appearance == .dark ? .dark : .unspecified
        updateAutoCapitalization()
        refreshLayout()
    }

    private var bottomConfig: BottomRow.Config {
        let proxy = textDocumentProxy
        let field: BottomRow.FieldKind
        switch proxy.keyboardType ?? .default {
        case .emailAddress: field = .email
        case .URL: field = .url
        case .webSearch: field = .webSearch
        case .twitter: field = .twitter
        default: field = .text
        }
        let style: BottomRow.ReturnStyle
        switch proxy.returnKeyType ?? .default {
        case .go: style = .go
        case .google, .yahoo, .search: style = .search
        case .join: style = .join
        case .next: style = .next
        case .route: style = .route
        case .send: style = .send
        case .done: style = .done
        case .emergencyCall: style = .emergency
        case .continue: style = .continue
        default: style = .default
        }
        let enabled = !(proxy.enablesReturnKeyAutomatically ?? false) || proxy.hasText || isPinyinComposing
        return BottomRow.Config(language: currentLanguage, field: field, returnStyle: style, returnEnabled: enabled)
    }

    private func refreshLayout() {
        let rows: [KeyRow]
        switch mode {
        case .pad(let kind):
            rows = NumberLayout.padRows(kind)
        case .numbers:
            rows = NumberLayout.rows(page: .numbers, bottom: bottomConfig)
        case .symbols:
            rows = NumberLayout.rows(page: .symbols, bottom: bottomConfig)
        case .letters:
            rows = layouts[currentLanguage]?.rows(shifted: shiftState != .off, bottom: bottomConfig) ?? []
        }
        keysView.rows = rows
        keysView.shiftState = shiftState
    }

    /// Shift of the current language (Korean has none).
    private var shiftState: EnglishEngine.ShiftState {
        get {
            switch currentLanguage {
            case .english: return englishEngine.shiftState
            case .chinese: return chineseShift
            case .korean: return .off
            }
        }
        set {
            switch currentLanguage {
            case .english: englishEngine.shiftState = newValue
            case .chinese: chineseShift = newValue
            case .korean: break
            }
        }
    }

    // MARK: - Keys

    private func handle(_ key: KeyDefinition) {
        let now = CACurrentMediaTime()
        defer {
            if key.code != .space { lastSpaceTime = 0 }
        }
        switch key.code {
        case .language:
            switchLanguage()
            return
        case .numbers:
            commitComposition()
            mode = (mode == .letters) ? .numbers : .letters
            updateAutoCapitalization()
            refreshLayout()
            refreshSuggestions()
            return
        case .symbols:
            mode = (mode == .numbers) ? .symbols : .numbers
            refreshLayout()
            return
        case .shift:
            toggleShift(now)
            return
        case .space:
            handleSpace(now)
            return
        case .character(let text) where mode == .letters && currentLanguage == .chinese && chineseShift != .off:
            // Shifted Pinyin keys type capitals as they are: keep the best candidate, then the letter.
            guard !text.isEmpty else { return }
            let committed = isPinyinComposing ? pinyinEngine.commitBest() : ""
            if chineseShift == .once { chineseShift = .off }
            apply(.insert(committed + text.uppercased()))
            return
        case .character(let text) where mode != .letters:
            // Number / symbol pages type exactly what is on the key (no Pinyin full-width mapping).
            guard !text.isEmpty else { return }
            commitComposition()
            textDocumentProxy.insertText(text)
            afterTextChange()
            return
        default:
            break
        }
        let event = KeyEvent(keyCode: key.code, character: nil, timestamp: now, type: key.type)
        apply(currentEngine.handleKey(event))
    }

    private func apply(_ result: InputResult) {
        switch result {
        case .insert(let text):
            commitText(text)
        case .update(let commit, let composing):
            inline.apply(commit: commit, composing: composing, to: document)
        case .delete:
            // No context guard: the host knows best (selected text, empty context reporting).
            textDocumentProxy.deleteBackward()
        case .composing, .none:
            break
        }
        syncMarkedText()
        afterTextChange()
    }

    /// Writes finished text. If pinyin is shown as marked text it is replaced by `text`.
    private func commitText(_ text: String) {
        if markedText != nil {
            textDocumentProxy.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
            textDocumentProxy.unmarkText()
            markedText = nil
        } else if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
    }

    /// Shows the Pinyin buffer in the text field (underlined, like the system keyboard).
    private func syncMarkedText() {
        guard currentLanguage == .chinese else { return }
        let display = pinyinEngine.buffer.isEmpty ? "" : pinyinEngine.displayComposition
        if display.isEmpty {
            if markedText != nil {
                textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
                textDocumentProxy.unmarkText()
                markedText = nil
            }
        } else if display != markedText {
            textDocumentProxy.setMarkedText(display, selectedRange: NSRange(location: (display as NSString).length, length: 0))
            markedText = display
        }
    }

    private func afterTextChange() {
        updateAutoCapitalization()
        refreshLayout()
        refreshSuggestions()
    }

    // MARK: Space

    private func handleSpace(_ now: CFTimeInterval) {
        if isPinyinComposing {
            apply(currentEngine.handleKey(KeyEvent(keyCode: .space, character: " ", timestamp: now, type: .space)))
            lastSpaceTime = 0
            return
        }
        // Double space → ". " (Chinese: "。") after a word, like iOS.
        if now - lastSpaceTime < 0.6,
           let before = textDocumentProxy.documentContextBeforeInput, before.hasSuffix(" "),
           let previous = before.dropLast().last, previous.isLetter || previous.isNumber {
            inline.reset()
            hangulEngine.reset()
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText(currentLanguage == .chinese ? "。" : ". ")
            lastSpaceTime = 0
            afterTextChange()
            return
        }
        lastSpaceTime = now
        if mode == .letters {
            apply(currentEngine.handleKey(KeyEvent(keyCode: .space, character: " ", timestamp: now, type: .space)))
        } else {
            commitComposition()
            textDocumentProxy.insertText(" ")
            if mode == .numbers || mode == .symbols { mode = .letters }   // iOS returns to letters
            afterTextChange()
        }
    }

    // MARK: Shift / auto-capitalization

    private func toggleShift(_ now: CFTimeInterval) {
        switch shiftState {
        case .once where now - lastShiftTime < 0.3: shiftState = .locked
        case .off: shiftState = .once
        case .once, .locked: shiftState = .off
        }
        lastShiftTime = now
        refreshLayout()
    }

    private func updateAutoCapitalization() {
        guard currentLanguage == .english, mode == .letters, englishEngine.shiftState != .locked else { return }
        let type = textDocumentProxy.autocapitalizationType ?? .sentences
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        englishEngine.shiftState = AutoCapitalization.shouldCapitalize(type: type, before: before) ? .once : .off
    }

    // MARK: Backspace

    private func repeatBackspace(_ step: KeysView.BackspaceStep) {
        HapticManager.shared.triggerKeyTap()
        if isPinyinComposing {
            if step == .word { pinyinEngine.reset() } else {
                _ = pinyinEngine.handleKey(KeyEvent(keyCode: .backspace, character: nil,
                                                    timestamp: CACurrentMediaTime(), type: .backspace))
            }
            syncMarkedText()
            afterTextChange()
            return
        }
        // Held backspace removes whole characters (not jamo) and then whole words.
        inline.reset()
        hangulEngine.reset()
        let count = step == .word ? WordDeletion.count(before: textDocumentProxy.documentContextBeforeInput ?? "") : 1
        for _ in 0..<max(count, 1) { textDocumentProxy.deleteBackward() }
        afterTextChange()
    }

    // MARK: Trackpad

    private func trackpadChanged(_ active: Bool) {
        if active {
            HapticManager.shared.triggerSpecialKey()
            inline.reset()
            hangulEngine.reset()
        } else {
            afterTextChange()
        }
    }

    private func moveCursor(by steps: Int) {
        let proxy = textDocumentProxy
        for _ in 0..<abs(steps) {
            if steps < 0 {
                guard let last = proxy.documentContextBeforeInput?.last else { break }
                proxy.adjustTextPosition(byCharacterOffset: -String(last).utf16.count)
            } else {
                guard let next = proxy.documentContextAfterInput?.first else { break }
                proxy.adjustTextPosition(byCharacterOffset: String(next).utf16.count)
            }
        }
    }

    // MARK: - Suggestions

    private func refreshSuggestions() {
        updateLanguageToggle()
        model.setAlternative(currentLanguage == .korean && mode == .letters ? hangulEngine.ambiguityAlternative : nil)
        if isPinyinComposing {
            model.showCandidates(pinyinEngine.candidates)
            return
        }
        guard mode == .letters else { model.clear(); return }
        model.showEmoji(emojiStore.suggestions(forContext: textDocumentProxy.documentContextBeforeInput ?? ""))
    }

    private func selectSuggestion(_ item: KeyboardViewModel.Suggestion) {
        HapticManager.shared.triggerKeyTap()
        if isPinyinComposing {
            let text = pinyinEngine.selectCandidate(at: item.id)
            apply(text.isEmpty ? .none : .insert(text))
            if !isPinyinComposing { model.isExpanded = false }
        } else {
            insertEmoji(item.text)
        }
    }

    /// Finish any composition (keep the text) and insert the emoji after it.
    private func insertEmoji(_ emoji: String) {
        commitComposition()
        textDocumentProxy.insertText(emoji)
        emojiStore.recordUse(emoji)
        afterTextChange()
    }

    // MARK: - Composition helpers

    /// Keeps whatever is being composed as normal text.
    private func commitComposition() {
        if isPinyinComposing {
            let raw = pinyinEngine.buffer
            pinyinEngine.reset()
            commitText(raw)
        }
        inline.reset()
        hangulEngine.reset()
    }

    private func resetEngines() {
        inline.reset()
        hangulEngine.reset()
        pinyinEngine.reset()
        model.clear()
    }

    // MARK: - Language Switching

    private func switchLanguage() {
        changeLanguage { $0.globe() }
    }

    private func changeLanguage(_ change: (inout LanguageSwitch) -> Void) {
        commitComposition()
        change(&languages)
        if case .pad = mode {} else { mode = .letters }
        englishEngine.reset()
        chineseShift = .off
        KeyboardPreferences.preferredLanguage = languages.current
        KeyboardPreferences.baseLanguage = languages.base
        updateMetrics()     // Korean and English/Chinese can have different key sizes
        afterTextChange()
    }

    /// 한 中 / EN 中 at the left of the bar (paired mode only, not on number pads).
    private func updateLanguageToggle() {
        var show = languages.isPaired
        if case .pad = mode { show = false }
        model.setLanguageToggle(show ? .init(baseLabel: languages.baseLabel,
                                             chineseSelected: currentLanguage == .chinese) : nil)
    }

    fileprivate var proxyForDocument: UITextDocumentProxy { textDocumentProxy }
}

/// Adapts `UITextDocumentProxy` to the testable `TextDocumentEditing` protocol.
private final class ProxyDocument: TextDocumentEditing {
    private unowned let controller: KeyboardViewController

    init(controller: KeyboardViewController) {
        self.controller = controller
    }

    var documentContextBeforeInput: String? { controller.proxyForDocument.documentContextBeforeInput }
    func insertText(_ text: String) { controller.proxyForDocument.insertText(text) }
    func deleteBackward() { controller.proxyForDocument.deleteBackward() }
}

/// Keyboard-local preferences. The extension's own UserDefaults always works; the App Group
/// suite only works when the user grants "Allow Full Access", so it is a best-effort mirror.
enum KeyboardPreferences {
    private typealias Key = AppConstants.UserDefaultsKey

    static var preferredLanguage: Language? {
        get { language(Key.preferredLanguage) }
        set { setLanguage(newValue, Key.preferredLanguage) }
    }

    static var baseLanguage: Language? {
        get { language(Key.baseLanguage) }
        set { setLanguage(newValue, Key.baseLanguage) }
    }

    /// Set in the app (Settings → Language), so it is read from the App Group.
    static var isPairedLanguageMode: Bool {
        AppGroup.userDefaults.bool(forKey: Key.pairedLanguageMode)
    }

    /// Key size setting for a language (app Settings → Key Size; 1 = system keyboard).
    static func keyScale(for language: Language) -> Double {
        let key = language == .korean ? Key.koreanKeyScale : Key.latinKeyScale
        return AppGroup.userDefaults.object(forKey: key) as? Double ?? 1
    }

    private static func language(_ key: String) -> Language? {
        let raw = UserDefaults.standard.string(forKey: key) ?? AppGroup.userDefaults.string(forKey: key)
        return raw.flatMap(Language.init(rawValue:))
    }

    private static func setLanguage(_ value: Language?, _ key: String) {
        UserDefaults.standard.set(value?.rawValue, forKey: key)
        AppGroup.userDefaults.set(value?.rawValue, forKey: key)
    }
}
