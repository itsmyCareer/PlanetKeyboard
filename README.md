# PlanetKeyboard

An iOS custom keyboard for **Korean (단모음 / Danmoeum)**, **English (QWERTY)** and
**Simplified Chinese Pinyin** in one keyboard.

- **Korean 단모음**: an 8-column layout; tap a key twice for the doubled consonant or the
  y-vowel (ㅂ→ㅃ, ㅗ→ㅛ).
- **Chinese Pinyin**: whole-sentence input and abbreviations (`nzzsm` → 你在做什么).
  - Powered by [librime](https://github.com/rime/librime), the
    [rime-ice](https://github.com/iDvel/rime-ice) word lists and the
    [octagram](https://github.com/lotem/librime-octagram) language model.
  - Learns your words on the device.
  - Shift types capital letters as they are.
- **iOS-style details**:
  - Space-bar trackpad, held backspace that deletes whole words, and double-space for a period.
  - Field-aware keys for email, URL and number pads, and a return key that follows the field.
  - Emoji suggestions in the bar.
- **Language switching**: the globe key cycles the three languages. In Settings you can turn
  on "Globe Key: 한 ↔ EN Only". The globe then switches Korean ↔ English, and a 한 中 / EN 中
  toggle on the left of the suggestion bar switches to Chinese.

The keyboard has no network code. "Allow Full Access" is only used for haptics and for
reading the app's settings.

## Build

Requirements: Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), CMake and Ninja
(`brew install xcodegen cmake ninja`).

The Chinese engine is built from source. Its downloads and build outputs are not in git:

```bash
Tools/rime/fetch_sources.sh              # librime, octagram, rime-ice, Boost, model → Vendor/
Tools/rime/build_librime.sh macos
Tools/rime/build_librime.sh ios
Tools/rime/build_librime.sh iossim
Tools/rime/build_librime.sh xcframework  # → KeyboardExtension/Frameworks/Rime.xcframework
Tools/rime/build_data.sh                 # → KeyboardExtension/Resources/RimeData
```

Then build the app:

```bash
xcodegen generate
open PlanetKeyboard.xcodeproj
```

Run the `PlanetKeyboard` scheme. On the device or simulator, go to
Settings → General → Keyboard → Keyboards → Add New Keyboard → PlanetKeyboard.

Tests: `xcodebuild test -project PlanetKeyboard.xcodeproj -scheme PlanetKeyboard -destination 'platform=iOS Simulator,name=iPhone 17'`

More in [Tools/README.md](Tools/README.md): emoji data, license notices, TestFlight release.

## Project layout

| Path | What |
|---|---|
| `PlanetKeyboard/` | Container app: settings, setup guide, licenses (SwiftUI) |
| `KeyboardExtension/` | The keyboard: `KeyboardViewController`, `Views/`, `Layouts/`, `InputEngines/` |
| `Shared/` | Code used by both targets (constants, App Group) |
| `Tests/` | Unit tests (Hangul, Rime, layouts, language switching, emoji) |
| `Tools/` | Data and build scripts (`rime/`, emoji DB, notices, `release.sh`) |

## License

PlanetKeyboard is free software under the **GNU General Public License v3.0**. See
[LICENSE](LICENSE). It ships rime-ice data, which is GPL-3.0.

Third-party components and their licenses are listed in
[PlanetKeyboard/Resources/ThirdPartyNotices.txt](PlanetKeyboard/Resources/ThirdPartyNotices.txt),
which is also shown in the app under Settings → Open Source Licenses:

- librime: BSD-3-Clause
- librime-octagram: BSD-3-Clause
- the octagram language model: LGPL-3.0
- Boost: BSL-1.0
- LevelDB: BSD
- marisa-trie: BSD-2 / LGPL
- OpenCC: Apache-2.0
- yaml-cpp: MIT
- Unicode CLDR: Unicode License
