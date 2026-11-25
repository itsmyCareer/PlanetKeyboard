[Root](../CLAUDE.md) > **KeyboardExtension**

# KeyboardExtension -- Keyboard Extension Target

> Module-level AI context. Generated 2026-04-17T10:36:45.

## Module Purpose

This is the core module of PlanetKeyboard. It implements an iOS Custom Keyboard Extension that provides multi-language input:

- **English** -- standard QWERTY direct input.
- **Chinese** -- QWERTY layout for Pinyin composition with candidate selection.
- **Korean** -- Danmoeum (단모음) layout with Hangul jamo composition engine.

The extension is loaded by iOS as a system-wide keyboard and runs in a sandboxed process separate from the main app.

## Entry Point and Startup

| File | Role |
|---|---|
| `KeyboardViewController.swift` | Subclass of `UIInputViewController`. This is the single entry point iOS calls. It hosts SwiftUI views via `UIHostingController`, manages language switching, and routes key events to the active input engine. |

### Lifecycle

1. iOS instantiates `KeyboardViewController`.
2. `viewDidLoad()` -- load saved settings from App Group, set up the hosting controller with `KeyboardView`.
3. `viewWillAppear(_:)` -- apply current theme, activate the correct layout/engine.
4. `viewWillTransition(to:with:)` -- handle orientation changes, update layout dimensions.
5. `textDidChange(_:)` -- respond to text field context changes (cursor position, input traits).

## Directory Structure

```
KeyboardExtension/
  KeyboardViewController.swift        # UIInputViewController entry point
  Views/
    KeyboardView.swift                 # Root SwiftUI keyboard view
    KeyView.swift                      # Single key button component
    KeyRowView.swift                   # Horizontal row of keys
    ToolbarView.swift                  # Top bar: language switch, dismiss, etc.
  Layouts/
    KeyboardLayout.swift               # Layout protocol / base definitions
    EnglishLayout.swift                # QWERTY layout data for English
    ChineseLayout.swift                # QWERTY layout data for Pinyin input
    KoreanLayout.swift                 # Danmoeum (단모음) layout data
  InputEngines/
    InputEngine.swift                  # Input engine protocol
    EnglishEngine.swift                # Pass-through engine (key → character)
    RimeEngine.swift                   # Chinese Pinyin via librime (C API)
    HangulEngine.swift                 # Hangul jamo → syllable composition
  Haptics/
    HapticManager.swift                # Haptics: UIImpactFeedbackGenerator (view-attached) or system vibration (HapticMethod); reports KeyboardStatus
  Theme/
    ThemeManager.swift                 # Reads theme from App Group, provides current theme
    KeyboardTheme.swift                # Theme struct used at runtime in the extension
  Utils/
    Extensions.swift                   # Shared UIKit/SwiftUI helpers
  Resources/
    Info.plist                         # Extension plist (NSExtension config)
```

## External Interfaces

### Input Engine Protocol

```swift
protocol InputEngine {
    var language: Language { get }

    /// Process a key tap. Returns the text to insert, or nil if the
    /// engine is still composing (e.g., Pinyin/Hangul mid-sequence).
    func handleKey(_ key: KeyEvent) -> InputResult

    /// Current composition string (shown inline or in candidate bar).
    var compositionText: String { get }

    /// Candidate list (Pinyin characters, Hangul predictions).
    var candidates: [String] { get }

    /// Select a candidate by index; returns finalized text.
    func selectCandidate(at index: Int) -> String

    /// Reset composition state.
    func reset()
}
```

### Layout Protocol

```swift
protocol KeyboardLayout {
    var language: Language { get }
    var rows: [[KeyDefinition]] { get }         // main key rows
    var shiftRows: [[KeyDefinition]] { get }    // shifted variant
    func keyDefinition(for key: KeyCode) -> KeyDefinition?
}
```

### Key Event Flow

```
User tap on KeyView
  -> KeyboardView receives action
  -> KeyboardViewController.handleKey(_:)
  -> Active InputEngine.handleKey(_:)
  -> InputResult:
       .insert(String)      -> textDocumentProxy.insertText(_:)
       .composing           -> update composition display
       .candidates([String])-> show candidate bar
       .delete              -> textDocumentProxy.deleteBackward()
```

## Key Dependencies and Configuration

| Dependency | Type | Notes |
|---|---|---|
| UIKit | System | `UIInputViewController`, `UIHostingController` |
| SwiftUI | System | Keyboard views (hosted inside UIKit container) |
| Shared module | Internal | `AppGroup.swift`, `Constants.swift` |

**Zero third-party dependencies.** This is mandatory due to the ~30 MB memory limit.

### Info.plist -- Required Keys

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.keyboard-service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).KeyboardViewController</string>
    <key>IsASCIICapable</key> <true/>
    <key>PrefersRightToLeft</key> <false/>
    <key>PrimaryLanguage</key> <string>en</string>
    <key>RequestsOpenAccess</key> <true/>   <!-- haptics + App Group settings; everything else works without it -->
</dict>
```

## Data Models

### KeyDefinition

```swift
struct KeyDefinition {
    let code: KeyCode
    let label: String           // display text on the key cap
    let width: KeyWidth         // .standard, .wide, .spacebar, etc.
    let type: KeyType           // .character, .shift, .backspace, .space, .language, .return
}
```

### InputResult

```swift
enum InputResult {
    case insert(String)                              // plain insert (English, Pinyin commits)
    case update(commit: String, composing: String)   // Korean inline composition
    case composing(String)                           // Pinyin buffer changed, document untouched
    case delete
    case none
}
```

`InlineComposition` applies `.update` to the document: it tracks only the short composing tail
(<= 2 chars), rewrites it with a common-prefix diff, and abandons it (never deletes) when
`selectionDidChange`/`textDidChange` show the document no longer ends with it.
While typing fast iOS can report the host text late or halfway through a delete + insert edit;
within 1 s of an edit, a context equal to a state our own recent edits passed through (last 24
characters) is treated as in sync, so the syllable is not dropped (끈 + ㅎ → 끊, not 끈ㅎ).

## Keyboard UI -- Design Notes (2026-11-24 rework)

- Root = UIKit: `SuggestionBarView` (SwiftUI, top strip) + `KeysView` (UIKit, real multi-touch)
  + `CandidateGridView` (SwiftUI, expanded Pinyin candidates over the keys).
- Height (`KeyboardMetrics`) depends only on orientation and the key size setting of the current
  language, never on the page; pages within a language never resize the keyboard. Background is the system's; keys are drawn
  iOS-style (white letter keys, gray function keys, blue action return key).
- Layout model: `KeyRow(keys, columns)` + `KeyWidth.standard/wide/flex/gap`; `RowLayout`
  computes frames (unit-tested). Bottom row everywhere: `123 · 🌐(our language cycle) · space · ⏎`
  (email adds `@ .`, URL `. / .com`, webSearch `.`, twitter `@ #`). No emoji key: the system
  globe reaches Apple's emoji keyboard; emoji *suggestions* stay in the bar.
- Number pages per language follow the iOS keyboards (`NumberLayout.keys`); number/phone/decimal
  fields get a 3×4 pad. Keys on number pages are typed literally (no Pinyin full-width mapping).
- `KeysView`: rollover (a new finger commits the held key), touch-down for backspace/shift,
  long-press or slide on space = cursor trackpad, held backspace repeats then deletes words.
- Double space → ". " (Chinese "。"). English auto-capitalization follows
  `autocapitalizationType`; double-tap shift = caps lock. Return key label/colour follows
  `returnKeyType`, disabled when `enablesReturnKeyAutomatically` and the field is empty.
- Chinese: the Pinyin buffer is shown in the text field as marked text (`setMarkedText`), candidates
  live in the same bar as emoji; space commits the first one. Chinese has a shift key: shifted
  letters are typed as capitals directly (NH), after committing the best candidate; double-tap = caps lock.
- Language switching (`Layouts/LanguageSwitch.swift`, unit-tested): normally the globe cycles all
  languages. Paired mode (app Settings → "Globe Key: 한 ↔ EN Only", App Group key
  `pairedLanguageMode`): globe flips Korean ↔ English only, and a `LanguageToggleView` (한 中 / EN 中)
  at the left of the suggestion bar flips between that base language and Chinese. Globe from
  Chinese goes to the other base. The selected half sits in a raised key-coloured box, the other
  is smaller and dimmed; hidden while Pinyin is composing and on number pads.

## Korean Danmoeum Layout -- Design Notes

```
ㅂ ㅈ ㄷ ㄱ ㅅ ㅗ ㅐ ㅔ
ㅁ ㄴ ㅇ ㄹ ㅎ ㅓ ㅏ ㅣ
  ㅋ ㅌ ㅊ ㅍ ㅜ ㅡ ⌫
123 🌐 [  space  ] ⏎
```

- Tap speed never matters (only a lone vowel: ㅜㅜ quickly → ㅠ, slowly → ㅜㅜ).
- Same consonant twice at a syllable start → 쌍자음 when a vowel follows (ㄱㄱㅏ → 까);
  otherwise it stays as typed (ㅂㅂ, ㄷㄷ, ㄱㄱ in chat). ㄱㄱㄱㅏ → ㄱ까.
- Same vowel twice → ㅗ→ㅛ ㅓ→ㅕ ㅏ→ㅑ ㅜ→ㅠ ㅐ→ㅒ ㅔ→ㅖ.
- Compound vowels: ㅗ+ㅏ=ㅘ, ㅗ+ㅐ=ㅙ, ㅗ+ㅣ=ㅚ, ㅜ+ㅓ=ㅝ, ㅜ+ㅔ=ㅞ, ㅜ+ㅣ=ㅟ, ㅡ+ㅣ=ㅢ.
  ㅏ+ㅣ is NOT ㅐ (ㅐ/ㅔ have their own keys).
- 받침 + same consonant (바 + ㄱㄱ) waits for the next key. A consonant / space keeps a doubled
  받침 when one exists (밖이야, 있다). A vowel is resolved by `HangulAmbiguityResolver` from
  `Resources/hangul_pairs.tsv` (left syllable + consonant + first vowel key → counts of 박구-type vs
  바꾸-type words, built by `Tools/build_hangul_pairs.py` from FrequencyWords, CC BY-SA 4.0;
  unknown → 쌍자음): 바꿔, 아빠, 이따 / 먹고, 학교, 박고.
- The same applies when the left syllable already has a 받침 that could take the consonant
  (key = the syllable as it stays with the 쌍자음 reading): 겹받침 말 + ㅅㅅ → 말씀 / 진짜 / 할까 vs
  없습니다 / 읽고 / 앉지, and a third tap 직 + ㄱ → 아직까지 vs 갔습니다 / 닦고 (unknown → 쌍받침 + 초성).
  Without a vowel the keys stay as typed (맔ㅅ, 짂ㄱ). Check with the top-100k word simulation:
  1 119 → 101 mistyped words (remaining ones type identically, e.g. 각각 / 가깍).
- Until that next syllable is finished the left syllable is held in the composition, and the bar
  shows the other reading in quotes (“바꼬” while 박고 is typed); tapping it swaps
  (`HangulEngine.swapAmbiguity`). Backspace walks back: 바꾸 → 바ㄲ → 밖 → 박.

## Key size

- Defaults are the iOS 26 system keyboard (measured in the simulator: 45 pt keys, 11 pt row gap,
  ~35 pt key width on a 420 pt screen). App Settings → Key Size has a slider for Korean and one for
  English & Chinese (85–130 %, App Group keys `koreanKeyScale` / `latinKeyScale`); only key heights
  and row gaps scale. The keyboard height follows the current language, so switching between
  Korean and English can resize it (`updateMetrics()` in `changeLanguage`).

## Chinese Pinyin Input -- Design Notes

### Layout

Standard QWERTY layout identical to English, but keystrokes are buffered as a Pinyin sequence (e.g., `nihao`).

### Chinese engine responsibilities (RimeEngine)

1. Buffer raw Latin keystrokes as the composition string.
2. Segment the buffer into valid Pinyin syllables.
3. Look up candidate Chinese characters/phrases from a dictionary.
4. Display candidates in a scrollable bar above the keyboard.
5. On candidate selection, commit the Chinese text and clear the buffer.

### Engine (2026-11-24): librime

- `RimeEngine` (InputEngines/RimeEngine.swift) drives librime through its C API (`import RimeC`,
  `KeyboardExtension/Frameworks/Rime.xcframework`, built by `Tools/rime/build_librime.sh`).
- Data: schema `planet_pinyin` (Tools/rime/data) = rime-ice cn_dicts (GPL-3.0) + octagram model
  `zh-hans-t-essay-bgc-compact.gram` (LGPL-3.0) + pinned chat phrases (`planet_custom_phrase.txt`,
  generated from Tools/rime/chat_phrases.txt; codes that are real pinyin like "wa" are skipped).
- Precompiled on the Mac (`Tools/rime/build_data.sh`) into `Resources/RimeData` (shared dir +
  `build/` prebuilt bins). The extension only calls setup/initialize — never maintenance/deploy.
  Tables are memory-mapped; learned words go to `Application Support/Rime/planet_pinyin.userdb`
  (extension's own container, works without Full Access).
- `Tools/rime/probe.cc` loads the data the same way on the Mac and prints candidates + footprint.
- Measured: probe footprint ~3 MB; whole keyboard extension (Debug, simulator) ~35 MB.

## Emoji -- Design Notes

- `emoji.db` (1.9 MB, read-only) built by `Tools/build_emoji_db.py` from Unicode `emoji-test.txt`
  + CLDR annotations (ko/en/zh) + hand-written slang (ㅋㅋ, ㅠㅠ, lol, haha, 哈哈, 嘿嘿 ...).
- `EmojiStore`: category pages (skin-tone variants excluded, filtered by the emoji version the
  running iOS can draw), recents in the extension's own UserDefaults, keyword suggestions.
- Suggestions: trailing same-script token before the cursor, laughter normalized
  (ㅋㅋㅋㅋ → ㅋㅋ), Korean prefixes (사랑해요 → 사랑), Chinese suffixes (我爱你 → 爱你).
  Shown in the toolbar; while Pinyin is composing they are mixed into the candidate bar
  (after the top 2 words) and replace the whole buffer when picked.
- Number pages: `NumberLayout` "123" and "#+=" (KeyCode `.symbols`); emoji key = KeyCode `.emoji`.

## Sandboxing Constraints (Critical)

| Constraint | Impact | Mitigation |
|---|---|---|
| ~30 MB memory limit | Extension killed if exceeded | Lazy-load dictionary, no large caches, profile with Instruments |
| No network by default | Cannot fetch candidates online | Offline dictionary embedded in bundle |
| Separate process | No shared memory with main app | App Group UserDefaults / shared container |
| No UIApplication.shared | Cannot open URLs, access app delegate | Use extensionContext or avoid entirely |
| No background execution | Killed when keyboard dismissed | Save state in viewWillDisappear |
| Limited pasteboard | Full access needs "Allow Full Access" | Degrade gracefully if not granted |

## Testing and Quality

| Scope | Approach |
|---|---|
| HangulEngine | Unit tests for all state transitions: CV, CVC, compound vowels, double consonants, backspace mid-composition |
| RimeEngine | Tests against bundled RimeData: nzzsm, sentences, keys, partial selection (Tests/RimeEngineTests.swift) |
| EnglishEngine | Trivial pass-through tests |
| Layouts | Unit tests asserting correct key count, row structure, label correctness |
| KeyboardViewController | Limited; test proxy interactions with mock `UITextDocumentProxy` |
| Memory | Instruments profiling; automated check that peak memory < 25 MB |

## FAQ

**Q: Why UIKit for the extension instead of pure SwiftUI?**
A: iOS requires the keyboard extension entry point to be a `UIInputViewController` subclass (UIKit). SwiftUI views are hosted inside it via `UIHostingController`.

**Q: How do I add a new language?**
A: 1) Create a new `InputEngine` conforming to the protocol. 2) Create a new `KeyboardLayout` conforming to the protocol. 3) Register both in `KeyboardViewController`'s language switching logic. 4) Add the language to the `Language` enum in `Shared/Constants.swift`.

**Q: Why no SPM packages?**
A: Keyboard extensions are memory-constrained (~30 MB). Third-party code increases binary size and memory usage unpredictably. All logic should be hand-written and profiled.

**Q: How does language switching work?**
A: The globe key in the bottom row calls `KeyboardViewController.changeLanguage`, which updates `LanguageSwitch` (cycle, or 한 ↔ EN in paired mode) and re-lays out the keys; the 한/中 toggle in the suggestion bar does the same for Chinese. The active `KeyboardLayout` and `InputEngine` follow `languages.current`.

## Related Files

- `../Shared/Constants.swift` -- `Language` enum, App Group ID, UserDefaults keys.
- `../Shared/AppGroup.swift` -- Helper for reading settings written by the main app.
- `../PlanetKeyboard/Models/Theme.swift` -- Theme model; `ThemeManager` reads this from App Group.

## Changelog

| Date | Action | Details |
|---|---|---|
| 2026-04-17 | Created | Initial module documentation from planned architecture. |
| 2026-11-25 | Fast typing | InlineComposition ignores late / mid-edit host reports that match its own recent edits (끊 came out as 끈ㅎ on device). |
| 2026-11-25 | 단모음 겹받침 | 쌍자음 after a 받침 that could form a 겹받침 (말씀, 진짜, 할까) and after a third tap (아직까지) decided by word statistics too; hangul_pairs.tsv now 2 009 rows. |
| 2026-11-25 | Haptics | Generators attached to the keyboard view, live hasFullAccess per tap, app-selectable method (Standard / System vibration), KeyboardStatus diagnostics shown in the app; "Full Access off · no vibration" hint in the empty bar (os_log category "haptics"). |
| 2026-11-25 | 단모음 / size | Timing-free 쌍자음 (word statistics + “alternative” chip in the bar); iOS-sized keys (45 pt) with per-language Key Size setting. |
| 2026-11-25 | Languages | Chinese shift key (capitals typed as-is); paired mode: globe 한 ↔ EN, 한/中 toggle in the bar. |
| 2026-11-24 | librime | PinyinEngine/PinyinDictionary replaced by RimeEngine (librime + rime-ice + octagram); app is GPL-3.0. |
| 2026-11-24 | Full Access | RequestsOpenAccess = true (haptics, App Group settings). No network code; keyboard fully works without it. |
| 2026-11-24 | UI rework | UIKit KeysView, fixed height, iOS bottom row/number pages, marked-text Pinyin, unified suggestion bar, trackpad, backspace repeat, double-space period, field types, chat-boosted ranking. |
| 2026-11-24 | Rework | 단모음 layout per spec, rewritten Hangul composer + InlineComposition, Pinyin candidates/learning, DB actually bundled. |
