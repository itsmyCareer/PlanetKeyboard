import Foundation
import SQLite3

/// Emoji keyboard pages + keyword → emoji suggestions (ko / en / zh), backed by the bundled
/// read-only `emoji.db` (Unicode CLDR annotations + project slang such as ㅋㅋ, lol, 哈哈).
final class EmojiStore {

    enum Category: String, CaseIterable {
        case recent, smileys, nature, food, activities, travel, objects, symbols, flags

        var icon: String {
            switch self {
            case .recent: return "🕘"
            case .smileys: return "😀"
            case .nature: return "🐻"
            case .food: return "🍔"
            case .activities: return "⚽"
            case .travel: return "🚗"
            case .objects: return "💡"
            case .symbols: return "🔣"
            case .flags: return "🏳️"
            }
        }
    }

    private let path: String?
    private let maxVersion: Double
    private let defaults: UserDefaults
    private var db: OpaquePointer?
    private var statements: [String: OpaquePointer] = [:]

    static let recentKey = "recentEmojis"
    static let maxRecents = 32

    init(path: String? = EmojiStore.bundledPath,
         maxVersion: Double = EmojiStore.supportedEmojiVersion,
         defaults: UserDefaults = .standard) {
        self.path = path
        self.maxVersion = maxVersion
        self.defaults = defaults
    }

    deinit { close() }

    static var bundledPath: String? {
        Bundle(for: EmojiStore.self).path(forResource: "emoji", ofType: "db")
    }

    /// Newest emoji version the running iOS can draw (newer ones would show as boxes).
    static var supportedEmojiVersion: Double {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let os = Double(v.majorVersion) + Double(v.minorVersion) / 10
        switch os {
        case 18.4...: return 16.0
        case 17.4...: return 15.1
        case 16.4...: return 15.0
        default: return 14.0
        }
    }

    // MARK: - Keyboard pages

    func emojis(in category: Category) -> [String] {
        if category == .recent { return recents }
        return rows(sql: "SELECT emoji FROM emojis WHERE category = ?1 AND version <= ?2 ORDER BY ord",
                    text: category.rawValue, limit: nil)
    }

    var recents: [String] {
        defaults.stringArray(forKey: Self.recentKey) ?? []
    }

    func recordUse(_ emoji: String) {
        var list = recents.filter { $0 != emoji }
        list.insert(emoji, at: 0)
        defaults.set(Array(list.prefix(Self.maxRecents)), forKey: Self.recentKey)
    }

    // MARK: - Suggestions

    /// Emoji for the word right before the cursor ("ㅋㅋㅋ" → 😂, "사랑해요" → ❤️, "哈哈" → 😂).
    func suggestions(forContext context: String, limit: Int = 8) -> [String] {
        guard let token = Self.trailingToken(of: context) else { return [] }
        // A lone Latin letter ("m" → Ⓜ️) is never meant as a word.
        if token.script == .latin, token.text.count < 2 { return [] }
        var result: [String] = []
        for variant in Self.lookupVariants(for: token) {
            for emoji in exact(variant, limit: limit) where !result.contains(emoji) {
                result.append(emoji)
            }
            if result.count >= limit { break }
        }
        if result.isEmpty, token.text.count >= (token.script == .latin ? 3 : 2) {
            result = prefix(Self.normalize(token.text), limit: limit)
        }
        return Array(result.prefix(limit))
    }

    /// Exact keyword match only (used to mix emoji into Chinese candidates).
    func exact(_ keyword: String, limit: Int = 3) -> [String] {
        rows(sql: "SELECT emoji FROM keywords WHERE keyword = ?1 AND version <= ?2 ORDER BY rank LIMIT ?3",
             text: Self.normalize(keyword), limit: limit)
    }

    /// Like `exact`, but generic keywords that name many emoji (女子 → every woman emoji)
    /// return nothing. Used for the Pinyin candidate bar, where noise pushes words aside.
    func specific(_ keyword: String, limit: Int = 3) -> [String] {
        let all = exact(keyword, limit: Self.genericKeywordCount + 1)
        guard all.count <= Self.genericKeywordCount else { return [] }
        // ZWJ sequences are person/gender/role variants (女子 → 👩‍🦼); too specific to guess.
        return Array(all.filter { !$0.unicodeScalars.contains { $0.value == 0x200D } }.prefix(limit))
    }

    static let genericKeywordCount = 8

    private func prefix(_ keyword: String, limit: Int) -> [String] {
        var seen = Set<String>()
        return rows(sql: """
            SELECT emoji FROM keywords WHERE keyword >= ?1 AND keyword < ?4 AND version <= ?2
            ORDER BY rank LIMIT ?3
            """, text: keyword, limit: limit * 3, upper: Self.incrementLastScalar(keyword))
            .filter { seen.insert($0).inserted }
            .prefix(limit).map { $0 }
    }

    // MARK: - Tokenizing

    enum Script: Equatable { case jamo, hangul, latin, han }

    struct Token: Equatable {
        let text: String
        let script: Script
    }

    static func script(of scalar: Unicode.Scalar) -> Script? {
        switch scalar.value {
        case 0x3131...0x318E: return .jamo
        case 0xAC00...0xD7A3: return .hangul
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: return .latin
        case 0x3400...0x4DBF, 0x4E00...0x9FFF: return .han
        default: return nil
        }
    }

    /// The run of same-script characters right before the cursor ("좋아ㅋㅋㅋ" → "ㅋㅋㅋ").
    static func trailingToken(of context: String) -> Token? {
        var scalars: [Unicode.Scalar] = []
        var tokenScript: Script?
        for scalar in context.unicodeScalars.reversed() {
            guard let s = script(of: scalar) else { break }
            if tokenScript == nil { tokenScript = s }
            guard s == tokenScript else { break }
            scalars.append(scalar)
            if scalars.count >= 24 { break }
        }
        guard let tokenScript, !scalars.isEmpty else { return nil }
        return Token(text: String(String.UnicodeScalarView(scalars.reversed())), script: tokenScript)
    }

    /// Lower-cases and collapses repeated laughter: ㅋㅋㅋㅋ → ㅋㅋ, hahaha → haha, 哈哈哈 → 哈哈.
    static func normalize(_ word: String) -> String {
        let chars = Array(word.lowercased())
        for unitLength in 1...2 where chars.count >= unitLength * 2 {
            let unit = Array(chars[0..<unitLength])
            if chars.indices.allSatisfy({ chars[$0] == unit[$0 % unitLength] }) {
                return String(unit + unit)
            }
        }
        return String(chars)
    }

    /// Whole word first, then shorter forms: 사랑해요 → 사랑해 → 사랑, 我爱你 → 爱你 → 你, cats → cat.
    static func lookupVariants(for token: Token) -> [String] {
        let text = token.text.lowercased()
        var variants = [text, normalize(text)]
        let chars = Array(text)
        switch token.script {
        case .hangul:
            for length in stride(from: chars.count - 1, through: 2, by: -1) {
                variants.append(String(chars[0..<length]))
            }
        case .han:
            for start in 1..<max(chars.count, 1) {
                variants.append(String(chars[start...]))
            }
        case .latin:
            if text.count > 3, text.hasSuffix("s") { variants.append(String(text.dropLast())) }
        case .jamo:
            break
        }
        var seen = Set<String>()
        return variants.filter { seen.insert($0).inserted }
    }

    // MARK: - SQLite

    private func rows(sql: String, text: String, limit: Int?, upper: String? = nil) -> [String] {
        guard let stmt = statement(sql) else { return [] }
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        sqlite3_bind_text(stmt, 1, text, -1, Self.transient)
        sqlite3_bind_double(stmt, 2, maxVersion)
        if let limit { sqlite3_bind_int(stmt, 3, Int32(limit)) }
        if let upper { sqlite3_bind_text(stmt, 4, upper, -1, Self.transient) }
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) { out.append(String(cString: c)) }
        }
        return out
    }

    private func statement(_ sql: String) -> OpaquePointer? {
        if let cached = statements[sql] { return cached }
        if db == nil {
            guard let path, sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
                sqlite3_close(db)
                db = nil
                return nil
            }
            sqlite3_exec(db, "PRAGMA cache_size = -256; PRAGMA query_only = ON;", nil, nil, nil)
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        statements[sql] = stmt
        return stmt
    }

    /// Frees SQLite memory; the next call reopens lazily.
    func close() {
        statements.values.forEach { sqlite3_finalize($0) }
        statements.removeAll()
        if let db { sqlite3_close(db) }
        db = nil
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Smallest string greater than every string with this prefix (for range scans).
    static func incrementLastScalar(_ s: String) -> String {
        var scalars = Array(s.unicodeScalars)
        guard let last = scalars.last, let next = Unicode.Scalar(last.value + 1) else { return s }
        scalars[scalars.count - 1] = next
        return String(String.UnicodeScalarView(scalars))
    }
}
