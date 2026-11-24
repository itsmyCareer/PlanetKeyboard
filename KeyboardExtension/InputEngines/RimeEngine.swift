import Foundation
import RimeC

/// Chinese Pinyin through librime (Rime) with the rime-ice word lists and the octagram
/// language model: whole-sentence input, abbreviations (nzzsm → 你在做什么) and on-device
/// learning (`planet_pinyin.userdb` in the extension's own container — no Full Access needed).
///
/// Data is precompiled on the Mac (`Tools/rime/build_data.sh`) and shipped in `RimeData/`;
/// the extension never runs Rime's deployer, which keeps memory and launch time low
/// (dictionaries are memory-mapped files, so they don't count as dirty memory).
final class RimeEngine: InputEngine {
    var language: Language { .chinese }

    /// Emoji for a Chinese word (哈哈 → 😂). Mixed into the candidates after the top 2 words.
    var emojiProvider: ((String) -> [String])?

    private(set) var buffer: String = ""
    private(set) var displayComposition: String = ""
    private(set) var candidateList: [String] = []
    /// How many leading entries of `candidateList` are Rime candidates (the rest are emoji).
    private var rimeIndexByPosition: [Int?] = []

    private var session: RimeSessionId = 0
    private static let maxCandidates = 60

    var compositionText: String { buffer }
    var candidates: [String] { candidateList }
    var isComposing: Bool { !buffer.isEmpty }

    init() {}

    deinit {
        if session != 0 { RimeRuntime.api?.pointee.destroy_session(session) }
    }

    // MARK: - Keys

    func handleKey(_ key: KeyEvent) -> InputResult {
        switch key.keyCode {
        case .character(let raw):
            let lower = raw.lowercased()
            if lower.count == 1, let scalar = lower.unicodeScalars.first, ("a"..."z").contains(scalar) {
                process(Int32(scalar.value))
                return result()
            }
            // Anything else: keep the best candidate (or the letters), then the character.
            let committed = isComposing ? commitBest() : ""
            return .insert(committed + Self.fullWidth(raw))

        case .space:
            guard isComposing else { return .insert(" ") }
            process(Self.keySpace)
            return result()

        case .return_:
            guard isComposing else { return .insert("\n") }
            process(Self.keyReturn)     // commit_raw_input
            return result()

        case .backspace:
            guard isComposing else { return .delete }
            process(Self.keyBackspace)
            return result()

        case .shift:
            return .none

        case .language, .numbers, .symbols, .emoji, .dismiss:
            guard isComposing else { return .none }
            let text = buffer
            reset()
            return .insert(text)
        }
    }

    /// Commits the candidate at `index` of `candidates`. Rime keeps any input the candidate
    /// does not cover ("nihaoma" → 你好, "ma" stays).
    func selectCandidate(at index: Int) -> String {
        guard candidateList.indices.contains(index) else { return "" }
        guard let rimeIndex = rimeIndexByPosition[index] else {
            // Emoji: replaces the whole input.
            let emoji = candidateList[index]
            reset()
            return emoji
        }
        guard ensureSession(), let api = RimeRuntime.api else { return "" }
        _ = api.pointee.select_candidate(session, rimeIndex)
        let commit = takeCommit()
        refresh()
        return commit
    }

    func reset() {
        if session != 0 { RimeRuntime.api?.pointee.clear_composition(session) }
        buffer = ""
        displayComposition = ""
        candidateList = []
        rimeIndexByPosition = []
    }

    /// Learned words survive the extension being killed.
    func saveUserData() {
        _ = RimeRuntime.api?.pointee.sync_user_data()
    }

    // MARK: - Rime

    private static let keySpace: Int32 = 0x20
    private static let keyBackspace: Int32 = 0xff08
    private static let keyReturn: Int32 = 0xff0d

    private func ensureSession() -> Bool {
        guard let api = RimeRuntime.start() else { return false }
        if session != 0, api.pointee.find_session(session) != 0 { return true }
        session = api.pointee.create_session()
        guard session != 0 else { return false }
        _ = api.pointee.select_schema(session, "planet_pinyin")
        return true
    }

    private func process(_ keycode: Int32) {
        guard ensureSession(), let api = RimeRuntime.api else { return }
        _ = api.pointee.process_key(session, keycode, 0)
    }

    /// The pending commit (if any) as `.insert`, else the new composition.
    private func result() -> InputResult {
        let commit = takeCommit()
        refresh()
        if !commit.isEmpty { return .insert(commit) }
        return .composing(buffer)
    }

    private func takeCommit() -> String {
        guard let api = RimeRuntime.api else { return "" }
        var commit = RimeCommit()
        commit.data_size = Int32(MemoryLayout<RimeCommit>.size - MemoryLayout<Int32>.size)
        guard api.pointee.get_commit(session, &commit) != 0 else { return "" }
        defer { _ = api.pointee.free_commit(&commit) }
        return commit.text.map { String(cString: $0) } ?? ""
    }

    /// Ends the composition: the best candidate (plus any letters it does not cover), or the
    /// letters themselves when there is no candidate.
    func commitBest() -> String {
        if let first = rimeIndexByPosition.first, first != nil {
            let text = selectCandidate(at: 0)
            if !isComposing { return text }
            let rest = buffer
            reset()
            return text + rest
        }
        let text = buffer
        reset()
        return text
    }

    /// Reads input, preedit and candidates from Rime.
    private func refresh() {
        guard let api = RimeRuntime.api, session != 0 else { return }
        buffer = api.pointee.get_input(session).map { String(cString: $0) } ?? ""
        guard !buffer.isEmpty else {
            displayComposition = ""
            candidateList = []
            rimeIndexByPosition = []
            return
        }
        var context = RimeContext()
        context.data_size = Int32(MemoryLayout<RimeContext>.size - MemoryLayout<Int32>.size)
        if api.pointee.get_context(session, &context) != 0 {
            displayComposition = context.composition.preedit.map { String(cString: $0) } ?? buffer
            _ = api.pointee.free_context(&context)
        } else {
            displayComposition = buffer
        }

        var words: [String] = []
        var iterator = RimeCandidateListIterator()
        if api.pointee.candidate_list_begin(session, &iterator) != 0 {
            while words.count < Self.maxCandidates, api.pointee.candidate_list_next(&iterator) != 0 {
                if let text = iterator.candidate.text { words.append(String(cString: text)) }
            }
            api.pointee.candidate_list_end(&iterator)
        }
        candidateList = words
        rimeIndexByPosition = words.indices.map { $0 }
        insertEmojiCandidates()
    }

    /// Emoji for the top words (哈哈 → 😂), placed after the top 2 like the system keyboard.
    private func insertEmojiCandidates() {
        guard let emojiProvider, !candidateList.isEmpty else { return }
        var emojis: [String] = []
        for word in candidateList.prefix(2) where word.count >= 2 {
            for emoji in emojiProvider(word) where !emojis.contains(emoji) { emojis.append(emoji) }
        }
        let items = Array(emojis.prefix(3))
        let at = min(2, candidateList.count)
        candidateList.insert(contentsOf: items, at: at)
        rimeIndexByPosition.insert(contentsOf: Array(repeating: nil, count: items.count), at: at)
    }

    static func fullWidth(_ s: String) -> String {
        let map: [String: String] = [".": "。", ",": "，", "?": "？", "!": "！", ":": "：", ";": "；"]
        return map[s] ?? s
    }
}

/// Process-wide Rime setup (librime allows one setup per process).
enum RimeRuntime {
    private(set) static var api: UnsafeMutablePointer<RimeApi>?
    private static var started = false
    /// Where learned words live. Tests point this at a temporary directory before first use.
    static var userDataDirectory: URL? = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Rime")

    static var bundledDataPath: String? {
        Bundle(for: RimeEngine.self).path(forResource: "RimeData", ofType: nil)
    }

    @discardableResult
    static func start() -> UnsafeMutablePointer<RimeApi>? {
        if started { return api }
        guard let shared = bundledDataPath, let userURL = userDataDirectory,
              let rime = rime_get_api() else { return nil }
        try? FileManager.default.createDirectory(at: userURL, withIntermediateDirectories: true)

        // librime keeps these pointers: allocate once for the process lifetime.
        func keep(_ s: String) -> UnsafePointer<CChar> { UnsafePointer(strdup(s)!) }
        var traits = RimeTraits()
        traits.data_size = Int32(MemoryLayout<RimeTraits>.size - MemoryLayout<Int32>.size)
        traits.shared_data_dir = keep(shared)
        traits.user_data_dir = keep(userURL.path)
        traits.prebuilt_data_dir = keep(shared + "/build")
        traits.staging_dir = keep(userURL.appendingPathComponent("build").path)
        traits.distribution_name = keep("PlanetKeyboard")
        traits.distribution_code_name = keep("planet")
        traits.distribution_version = keep("1.0")
        traits.app_name = keep("rime.planet")
        traits.min_log_level = 3
        rime.pointee.setup(&traits)
        rime.pointee.initialize(&traits)
        api = rime
        started = true
        return api
    }
}
