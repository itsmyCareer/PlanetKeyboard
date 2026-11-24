# Tools

## Emoji database (`KeyboardExtension/Resources/emoji.db`)

```bash
mkdir -p Tools/sources/emoji && cd Tools/sources/emoji
B=https://raw.githubusercontent.com/unicode-org/cldr/main
for l in en ko zh; do
  curl -fL $B/common/annotations/$l.xml -o annotations_$l.xml
  curl -fL $B/common/annotationsDerived/$l.xml -o derived_$l.xml
done
curl -fL $B/LICENSE -o cldr_LICENSE
curl -fL https://unicode.org/Public/emoji/latest/emoji-test.txt -o emoji-test.txt
cd ../../..
python3 -I Tools/build_emoji_db.py --sources Tools/sources/emoji --output KeyboardExtension/Resources/emoji.db
```

Slang keywords (ㅋㅋ, lol, 哈哈 ...) live in `SLANG` inside `build_emoji_db.py`.

## License notices

```bash
python3 -I Tools/build_notices.py --sources Tools/sources --vendor Vendor \
    --output PlanetKeyboard/Resources/ThirdPartyNotices.txt
```

Needs `Vendor/` (see below) for the librime / rime-ice / model licenses.

## Release to App Store Connect / TestFlight

```bash
Tools/release.sh              # tests → archive → upload (build number = UTC timestamp)
Tools/release.sh --no-upload  # tests → archive → export .ipa to build/release/<build>/export
```

- Version shown in the store: `MARKETING_VERSION` in `project.yml`.
- Auth: Apple ID signed in to Xcode, or an App Store Connect API key via
  `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` (put them in `~/.planetkeyboard-release.env`, never in the repo).
- The app record must exist in App Store Connect first (bundle ID `com.planetkeyboard.PlanetKeyboard`).
- App icon: `Tools/make_app_icon.py` draws the placeholder; replace `AppIcon.png` (1024×1024, no alpha) with the final art.

## Chinese engine: librime + rime-ice (GPL-3.0)

PlanetKeyboard is GPL-3.0 because it ships rime-ice data. The third-party sources are not in
git; download them (pinned commits, checksummed Boost and language model) into `Vendor/`:

```bash
Tools/rime/fetch_sources.sh
```

Build (the outputs, `Rime.xcframework` and `RimeData/`, are git-ignored):

```bash
Tools/rime/build_librime.sh macos        # host deployer + probe tools
Tools/rime/build_librime.sh ios
Tools/rime/build_librime.sh iossim
Tools/rime/build_librime.sh xcframework  # → KeyboardExtension/Frameworks/Rime.xcframework
python3 -I Tools/rime/make_custom_phrase.py   # Tools/rime/chat_phrases.txt → pinned chat phrases
Tools/rime/build_data.sh                 # precompiled dictionaries → KeyboardExtension/Resources/RimeData
python3 -I Tools/build_notices.py --sources Tools/sources --vendor Vendor \
    --output PlanetKeyboard/Resources/ThirdPartyNotices.txt
```

Check candidates on the Mac exactly as the keyboard loads them:

```bash
c++ -std=c++17 -I Vendor/librime/src Tools/rime/probe.cc Vendor/build/macos/libRime.a -o Vendor/build/macos/probe
Vendor/build/macos/probe KeyboardExtension/Resources/RimeData /tmp/rime-user nzzsm nh wojintianhenmang
```
