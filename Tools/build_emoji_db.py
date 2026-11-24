#!/usr/bin/env python3
"""
Build KeyboardExtension/Resources/emoji.db: the emoji keyboard list and ko/en/zh keyword →
emoji suggestions.

Sources (Tools/sources/emoji/, Unicode License v3):
  - emoji-test.txt                  emoji list, groups, emoji version  (unicode.org)
  - annotations_{en,ko,zh}.xml      CLDR keywords + names              (unicode-org/cldr)
  - derived_{en,ko,zh}.xml          CLDR derived names (flags, etc.)
Plus SLANG below (hand written for this project): ㅋㅋ, haha, lol, 哈哈, 嘿嘿 ...

Tables:
  emojis(ord, category, emoji, version)            keyboard pages, skin-tone variants excluded
  keywords(keyword, emoji, rank, version)          rank: slang < name < keyword, then ord
Keywords are lower-case. Repeated laughter is stored in canonical two-unit form
(ㅋㅋ, ㅎㅎ, haha, 哈哈); EmojiStore.normalize() maps ㅋㅋㅋㅋ → ㅋㅋ before lookup.

Usage:
  python3 -I Tools/build_emoji_db.py --sources Tools/sources/emoji \
      --output KeyboardExtension/Resources/emoji.db
"""

import argparse
import os
import re
import sqlite3
import xml.etree.ElementTree as ET

CATEGORIES = {
    # emoji-test group → keyboard category (iOS-like order)
    "Smileys & Emotion": "smileys",
    "People & Body": "smileys",
    "Animals & Nature": "nature",
    "Food & Drink": "food",
    "Activities": "activities",
    "Travel & Places": "travel",
    "Objects": "objects",
    "Symbols": "symbols",
    "Flags": "flags",
}
SKIN_TONES = {chr(c) for c in range(0x1F3FB, 0x1F400)}

SLANG = {
    # Korean
    "ㅋㅋ": "😂🤣😆😄", "ㅎㅎ": "😊😄☺️😁", "ㅠㅠ": "😭😢🥲", "ㅜㅜ": "😢😭🥺",
    "ㄱㄱ": "🏃🔥👍", "ㅇㅋ": "👌👍", "ㄷㄷ": "😱🥶😨", "ㅊㅋ": "🎉🥳👏",
    "사랑해": "❤️🥰😘💕", "사랑": "❤️💕🥰", "고마워": "🙏😊💕", "감사합니다": "🙏😊🙇",
    "감사": "🙏😊", "축하해": "🎉🥳🎊🎂", "축하": "🎉🥳🎊", "생일": "🎂🎉🥳🎁",
    "생일축하해": "🎂🎉🥳🎁", "화이팅": "💪🔥👊", "파이팅": "💪🔥👊", "대박": "😲🔥👍🤩",
    "헐": "😱😮😳", "굿": "👍👌", "좋아": "👍😊🥰", "졸려": "😴🥱💤", "배고파": "🤤🍚🍔",
    "미안": "🙏😢", "미안해": "🙏😢🥺", "안녕": "👋😊", "잘자": "🌙😴💤", "짱": "👍🔥",
    "최고": "👍🏆🔥", "웃겨": "😂🤣", "슬퍼": "😢😭", "화나": "😡😤", "짜증": "😤😠",
    "오케이": "👌👍", "한국": "🇰🇷", "중국": "🇨🇳", "korea": "🇰🇷", "보고싶어": "🥺💕", "졸업": "🎓🎉", "여행": "✈️🧳🌴",
    # English
    "lol": "😂🤣😆", "lmao": "🤣😂", "rofl": "🤣😂", "haha": "😂😆😄", "hehe": "😁😄😊",
    "omg": "😱😲🙀", "wow": "😮🤩😲", "love": "❤️😍🥰", "ily": "❤️🥰😘", "thanks": "🙏😊",
    "thx": "🙏😊", "ty": "🙏", "congrats": "🎉🥳🎊", "birthday": "🎂🎉🥳🎁", "cool": "😎👍",
    "ok": "👌👍", "okay": "👌👍", "yes": "👍✅", "no": "🙅❌", "sad": "😢😭", "cry": "😭😢",
    "angry": "😡😠", "sleepy": "😴🥱", "hungry": "🤤🍔", "xd": "😆😂", "sorry": "🙏😢",
    "hi": "👋😊", "hello": "👋😊", "bye": "👋", "gn": "🌙😴", "party": "🥳🎉",
    "kiss": "😘💋", "yay": "🥳🎉🙌", "lit": "🔥", "goat": "🐐🏆",
    # Chinese
    "哈哈": "😂😆😄", "嘿嘿": "😁😏😄", "呵呵": "🙂😅", "嘻嘻": "😆😁☺️", "笑死": "🤣😂",
    "哭": "😭😢", "呜呜": "😭😢", "爱你": "❤️🥰😘", "我爱你": "❤️😘💕", "谢谢": "🙏😊",
    "感谢": "🙏😊", "加油": "💪🔥✊", "生日快乐": "🎂🎉🥳", "晚安": "🌙😴💤", "早安": "☀️😊",
    "早上好": "☀️😊", "666": "👍🔥💯", "牛": "🐮👍", "厉害": "👍😲🔥", "赞": "👍",
    "好的": "👌👍", "开心": "😄😊🥳", "难过": "😢😞", "生气": "😡😠", "恭喜": "🎉🥳🎊",
    "再见": "👋", "你好": "👋😊", "么么哒": "😘💋", "无语": "😑🙄", "尴尬": "😅😓",
}


def split_emoji(s, known):
    """Split a run of emoji into known emoji (longest match; handles flags, FE0F, ZWJ)."""
    out, i = [], 0
    plain = s.replace("\ufe0f", "")
    while i < len(plain):
        for j in range(len(plain), i, -1):
            if plain[i:j] in known:
                out.append(plain[i:j])
                i = j
                break
        else:
            i += 1
    return out


def parse_emoji_test(path):
    emojis = []   # (ord, category, emoji, version)
    group = None
    for line in open(path, encoding="utf-8"):
        if line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
            continue
        if not line.strip() or line.startswith("#") or "; fully-qualified" not in line:
            continue
        m = re.search(r"#\s*(\S+)\s+E(\d+\.\d+)", line)
        if not m or group not in CATEGORIES:
            continue
        emoji, version = m.group(1), float(m.group(2))
        if any(c in SKIN_TONES for c in emoji):
            continue
        emojis.append((len(emojis), CATEGORIES[group], emoji, version))
    return emojis


def parse_annotations(path):
    """Yields (emoji_without_fe0f, keyword, is_name)."""
    root = ET.parse(path).getroot()
    for node in root.iter("annotation"):
        cp = node.get("cp", "").replace("️", "")
        text = (node.text or "").strip()
        if not cp or not text or text == "↑↑↑":
            continue
        is_name = node.get("type") == "tts"
        for kw in text.split("|"):
            kw = kw.strip().lower()
            if kw:
                yield cp, kw, is_name
            if is_name and ":" in kw:
                # "깃발: 대한민국" / "flag: china" → also index the country name itself
                yield cp, kw.split(":", 1)[1].strip(), True


def build(args):
    emojis = parse_emoji_test(os.path.join(args.sources, "emoji-test.txt"))
    by_plain = {e.replace("️", ""): (o, e, v) for o, _, e, v in emojis}

    keywords = {}   # (keyword, emoji) -> (rank, version)

    def add(keyword, emoji, rank):
        info = by_plain.get(emoji.replace("️", ""))
        if not info:
            return
        ordinal, qualified, version = info
        key = (keyword, qualified)
        value = (rank * 100000 + ordinal, version)
        if key not in keywords or value[0] < keywords[key][0]:
            keywords[key] = value

    for keyword, run in SLANG.items():
        for i, e in enumerate(split_emoji(run, by_plain)):
            add(keyword, e, 0 if i == 0 else 1)   # slang first; keep its listed order via ord tie
    for lang in ("en", "ko", "zh"):
        for prefix in ("annotations", "derived"):
            for cp, kw, is_name in parse_annotations(os.path.join(args.sources, f"{prefix}_{lang}.xml")):
                add(kw, cp, 2 if is_name else 3)

    # Preserve the hand-written slang order exactly.
    for keyword, run in SLANG.items():
        for i, e in enumerate(split_emoji(run, by_plain)):
            info = by_plain.get(e.replace("️", ""))
            if info:
                keywords[(keyword, info[1])] = (i, info[2])

    if os.path.exists(args.output):
        os.remove(args.output)
    db = sqlite3.connect(args.output)
    db.executescript("""
        CREATE TABLE emojis (ord INTEGER PRIMARY KEY, category TEXT NOT NULL,
                             emoji TEXT NOT NULL, version REAL NOT NULL);
        CREATE INDEX idx_emojis_category ON emojis(category, ord);
        CREATE TABLE keywords (keyword TEXT NOT NULL, emoji TEXT NOT NULL,
                               rank INTEGER NOT NULL, version REAL NOT NULL);
    """)
    db.executemany("INSERT INTO emojis VALUES (?, ?, ?, ?)", emojis)
    db.executemany("INSERT INTO keywords VALUES (?, ?, ?, ?)",
                   [(k, e, r, v) for (k, e), (r, v) in keywords.items()])
    db.execute("CREATE INDEX idx_keywords ON keywords(keyword, rank)")
    db.commit()
    db.execute("VACUUM")
    db.close()
    print(f"emojis: {len(emojis):,}  keywords: {len(keywords):,}  "
          f"size: {os.path.getsize(args.output) / 1e6:.1f} MB")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", required=True)
    parser.add_argument("--output", required=True)
    build(parser.parse_args())
