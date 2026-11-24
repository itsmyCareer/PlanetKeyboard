#!/bin/bash
# Precompile the Rime data on the Mac (dictionary → prism/table bins) and copy what the
# keyboard needs at runtime into KeyboardExtension/Resources/RimeData. The extension never
# compiles dictionaries itself (that would cost too much memory and time).
#
#   Tools/rime/build_data.sh        (needs Tools/rime/build_librime.sh macos first)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEPLOYER="$ROOT/Vendor/build/macos/rime_deployer"
SRC="$ROOT/Vendor/build/rime-src"
USER_DIR="$ROOT/Vendor/build/rime-user"
DEST="$ROOT/KeyboardExtension/Resources/RimeData"

rm -rf "$SRC" "$USER_DIR"
mkdir -p "$SRC/cn_dicts" "$USER_DIR"
cp "$ROOT"/Tools/rime/data/*.yaml "$ROOT"/Tools/rime/data/*.txt "$SRC/"
for d in 8105 base ext tencent others; do cp "$ROOT/Vendor/rime-ice/cn_dicts/$d.dict.yaml" "$SRC/cn_dicts/"; done
cp "$ROOT/Vendor/models/zh-hans-t-essay-bgc-compact.gram" "$SRC/"

time "$DEPLOYER" --build "$USER_DIR" "$SRC" "$SRC/build"

rm -rf "$DEST"
mkdir -p "$DEST/build"
cp "$SRC/default.yaml" "$SRC/planet_pinyin.schema.yaml" "$SRC/planet_custom_phrase.txt" "$SRC/zh-hans-t-essay-bgc-compact.gram" "$DEST/"
cp "$SRC"/build/*.bin "$SRC"/build/*.yaml "$DEST/build/"
du -sh "$DEST" "$DEST"/build/* "$DEST"/*.gram
