#!/usr/bin/env python3
"""
Write PlanetKeyboard/Resources/ThirdPartyNotices.txt (shown in Settings → Open Source Licenses).

Usage: python3 -I Tools/build_notices.py --sources Tools/sources --vendor Vendor \
           --output PlanetKeyboard/Resources/ThirdPartyNotices.txt \
           --source-url https://github.com/itsmyCareer/PlanetKeyboard
"""

import argparse
import os

LINE = "=" * 60


def section(title, url, used_for, body):
    return f"{LINE}\n{title}\n{url}\nUsed for: {used_for}\n{LINE}\n\n{body.strip()}\n\n"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--sources", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--vendor", default="Vendor")
    p.add_argument("--source-url", default="https://github.com/itsmyCareer/PlanetKeyboard")
    a = p.parse_args()
    read = lambda *parts: open(os.path.join(a.sources, *parts), encoding="utf-8").read()

    vread = lambda *parts: open(os.path.join(a.vendor, *parts), encoding="utf-8").read()
    out = "PlanetKeyboard — Open Source Licenses and Data Attribution\n\n"
    out += ("PlanetKeyboard is free software, licensed under the GNU General Public License v3.0\n"
            "(GPL-3.0). You may redistribute and modify it under those terms. The complete\n"
            f"corresponding source code is available at: {a.source_url}\n\n"
            "It includes the software and data listed below. Emoji images are drawn by the system\n"
            "font of your device and are not part of this app.\n\n")
    out += section("librime (Rime Input Method Engine)", "https://github.com/rime/librime",
                   "Chinese Pinyin input engine", vread("librime", "LICENSE"))
    out += section("librime-octagram", "https://github.com/lotem/librime-octagram",
                   "Language-model plugin for whole-sentence input", vread("librime", "plugins", "octagram", "LICENSE"))
    out += section("rime-ice (雾凇拼音)", "https://github.com/iDvel/rime-ice",
                   "Chinese word lists and weights (cn_dicts), schema settings",
                   "Copyright (C) iDvel and contributors. Licensed under the GNU General Public License v3.0;\n"
                   "the full text is at the end of this file.")
    out += section("rime-octagram-data", "https://github.com/lotem/rime-octagram-data",
                   "Language model zh-hans-t-essay-bgc-compact.gram", vread("models", "LICENSE"))
    out += section("Boost C++ Libraries", "https://www.boost.org", "Header-only utilities used by librime",
                   vread("librime", "deps", "boost", "LICENSE_1_0.txt"))
    out += section("LevelDB", "https://github.com/google/leveldb", "On-device learned words storage",
                   vread("librime", "deps", "leveldb", "LICENSE"))
    out += section("marisa-trie", "https://github.com/s-yata/marisa-trie", "Dictionary index",
                   vread("librime", "deps", "marisa-trie", "COPYING.md"))
    out += section("OpenCC", "https://github.com/BYVoid/OpenCC", "Linked by librime",
                   vread("librime", "deps", "opencc", "LICENSE"))
    out += section("yaml-cpp", "https://github.com/jbeder/yaml-cpp", "Rime configuration parsing",
                   vread("librime", "deps", "yaml-cpp", "LICENSE"))
    out += section(
        "Unicode CLDR and Unicode Emoji data", "https://github.com/unicode-org/cldr  ·  https://www.unicode.org/emoji/",
        "Emoji list, categories and Korean/English/Chinese emoji keywords",
        read("emoji", "cldr_LICENSE"))
    out += section(
        "FrequencyWords (Korean word frequencies)", "https://github.com/hermitdave/FrequencyWords",
        "Statistics that decide 받침 vs 쌍자음 on the Korean 단모음 keyboard (hangul_pairs.tsv)",
        "Word list ko_full.txt (2018, from OpenSubtitles) by Hermit Dave, licensed under the Creative\n"
        "Commons Attribution-ShareAlike 4.0 International License\n"
        "(https://creativecommons.org/licenses/by-sa/4.0/). Changed: reduced to counts of syllable\n"
        "pairs by Tools/build_hangul_pairs.py; the resulting table is under the same license.")
    out += section("GNU General Public License v3.0", "https://www.gnu.org/licenses/gpl-3.0.html",
                   "This app and rime-ice", vread("rime-ice", "LICENSE"))
    with open(a.output, "w", encoding="utf-8") as f:
        f.write(out)
    print(f"wrote {a.output} ({len(out):,} chars)")


if __name__ == "__main__":
    main()
