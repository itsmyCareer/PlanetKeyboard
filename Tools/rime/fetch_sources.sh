#!/bin/bash
# Download the third-party sources of the Chinese engine into Vendor/ (not in git), pinned to
# the exact versions this app was built with:
#
#   Tools/rime/fetch_sources.sh
#
# Then: Tools/rime/build_librime.sh macos|ios|iossim|xcframework and Tools/rime/build_data.sh
# (see Tools/README.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
V="$ROOT/Vendor"
mkdir -p "$V"

LIBRIME_COMMIT=f71eac9a4d6063ec926a5d7bec4575d30785b3ee
OCTAGRAM_COMMIT=57d18b9f58e5284bd891d559f6bdd16cf60341e9
RIME_ICE_COMMIT=927e1cf1d3eeb9bf4be85e3f684dba4dd485b6f6
BOOST_VERSION=1.92.0
BOOST_SHA256=c4a3b310ddd2472416e091067166b0713be97c63f38c212c484ada022fd296ce
GRAM_URL=https://github.com/lotem/rime-octagram-data/releases/download/20260712/zh-hans-t-essay-bgc-compact.gram
GRAM_SHA256=c52deb56b1642e4f56a18926fffcb4b70385828f921bfac92c5ff4055cce5377

checkout() {   # url, dir, commit
  if [ ! -d "$2/.git" ]; then git clone --filter=blob:none "$1" "$2"; fi
  git -C "$2" fetch --quiet origin "$3" 2>/dev/null || true
  git -C "$2" checkout --quiet "$3"
}

checkout https://github.com/rime/librime.git "$V/librime" "$LIBRIME_COMMIT"
git -C "$V/librime" submodule update --init --depth 1 deps/leveldb deps/yaml-cpp deps/marisa-trie deps/opencc
checkout https://github.com/lotem/librime-octagram.git "$V/librime/plugins/octagram" "$OCTAGRAM_COMMIT"
checkout https://github.com/iDvel/rime-ice.git "$V/rime-ice" "$RIME_ICE_COMMIT"

if [ ! -d "$V/librime/deps/boost/boost" ]; then
  tarball="boost_${BOOST_VERSION//./_}.tar.gz"
  tmp="$(mktemp -d)"
  curl -fL "https://archives.boost.io/release/$BOOST_VERSION/source/$tarball" -o "$tmp/$tarball"
  echo "$BOOST_SHA256  $tmp/$tarball" | shasum -a 256 -c -
  tar -xzf "$tmp/$tarball" -C "$tmp"
  mv "$tmp/boost_${BOOST_VERSION//./_}" "$V/librime/deps/boost"
  rm -rf "$tmp"
fi

mkdir -p "$V/models"
if [ ! -f "$V/models/zh-hans-t-essay-bgc-compact.gram" ]; then
  curl -fL "$GRAM_URL" -o "$V/models/zh-hans-t-essay-bgc-compact.gram"
fi
echo "$GRAM_SHA256  $V/models/zh-hans-t-essay-bgc-compact.gram" | shasum -a 256 -c -
curl -fsL https://raw.githubusercontent.com/lotem/rime-octagram-data/master/LICENSE -o "$V/models/LICENSE"
# Korean word frequencies for Tools/build_hangul_pairs.py (CC BY-SA 4.0).
FREQ_COMMIT=525f9b560de45753a5ea01069454e72e9aa541c6
mkdir -p "$V/frequencywords"
curl -fsL "https://raw.githubusercontent.com/hermitdave/FrequencyWords/$FREQ_COMMIT/content/2018/ko/ko_full.txt" \
  -o "$V/frequencywords/ko_full.txt"
curl -fsL "https://raw.githubusercontent.com/hermitdave/FrequencyWords/$FREQ_COMMIT/LICENSE" -o "$V/frequencywords/LICENSE"
echo "sources ready in $V"
