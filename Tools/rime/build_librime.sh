#!/bin/bash
# Build librime (+ octagram plugin) and its dependencies as static libraries.
#
#   Tools/rime/build_librime.sh macos     # host build: rime_deployer for precompiling data
#   Tools/rime/build_librime.sh ios       # arm64 device
#   Tools/rime/build_librime.sh iossim    # arm64 simulator
#   Tools/rime/build_librime.sh xcframework   # after ios + iossim: KeyboardExtension/Frameworks/Rime.xcframework
#
# Sources (see Tools/rime/README.md): Vendor/librime (+ deps submodules, deps/boost headers,
# plugins/octagram). Output: Vendor/build/<platform>/prefix.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RIME="$ROOT/Vendor/librime"
DEPS="$RIME/deps"
BOOST="$DEPS/boost"
PLATFORM="${1:?platform: macos | ios | iossim | xcframework}"
OUT="$ROOT/Vendor/build/$PLATFORM"
PREFIX="$OUT/prefix"
JOBS="$(sysctl -n hw.ncpu)"

common=(
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX="$PREFIX"
  -DCMAKE_PREFIX_PATH="$PREFIX"
  -DBUILD_SHARED_LIBS=OFF
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
)
case "$PLATFORM" in
  macos)
    common+=(-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0) ;;
  ios|iossim)
    sysroot=iphoneos; [ "$PLATFORM" = iossim ] && sysroot=iphonesimulator
    common+=(
      -DCMAKE_SYSTEM_NAME=iOS
      -DCMAKE_OSX_SYSROOT="$sysroot"
      -DCMAKE_OSX_ARCHITECTURES=arm64
      -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0
      -DCMAKE_FIND_ROOT_PATH="$PREFIX"
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH
      -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO
    ) ;;
  xcframework) ;;
  *) echo "unknown platform $PLATFORM"; exit 2 ;;
esac

build_dep() {   # name, extra cmake args...
  local name="$1"; shift
  local b="$OUT/deps/$name"
  cmake -S "$DEPS/$name" -B "$b" "${common[@]}" "$@"
  cmake --build "$b" -j "$JOBS"
  cmake --install "$b"
}

build_opencc() {
  local b="$OUT/deps/opencc"
  if [ "$PLATFORM" = macos ]; then
    cmake -S "$DEPS/opencc" -B "$b" "${common[@]}" -DENABLE_GTEST=OFF -DENABLE_BENCHMARK=OFF -DBUILD_DOCUMENTATION=OFF
    cmake --build "$b" -j "$JOBS" && cmake --install "$b"
  else
    cmake -S "$DEPS/opencc" -B "$b" "${common[@]}" -DENABLE_GTEST=OFF -DENABLE_BENCHMARK=OFF \
      -DBUILD_DOCUMENTATION=OFF -DOPENCC_ENABLE_INSTALL=OFF
    # Cross builds cannot run opencc_dict to generate its data: build the library only.
    cmake --build "$b" -j "$JOBS" --target libopencc
    mkdir -p "$PREFIX/include/opencc" "$PREFIX/lib"
    cp "$DEPS"/opencc/src/*.hpp "$DEPS"/opencc/src/*.h "$PREFIX/include/opencc/" 2>/dev/null || true
    cp "$b"/src/opencc_config.h "$PREFIX/include/opencc/" 2>/dev/null || true
    find "$b" -name 'libopencc*.a' -exec cp {} "$PREFIX/lib/libopencc.a" \;
    find "$b" -name 'libmarisa*.a' -exec cp {} "$PREFIX/lib/" \; || true
  fi
}

build_rime() {
  # plugins/octagram is picked up automatically (merged plugins).
  # RIME_DLL: with logging off, upstream headers use it before rime_api.h defines it.
  local b="$OUT/librime"
  cmake -S "$RIME" -B "$b" "${common[@]}" \
    -DBUILD_STATIC=ON -DBUILD_TEST=OFF -DBUILD_DATA=OFF -DBUILD_SAMPLE=OFF \
    -DBUILD_MERGED_PLUGINS=ON -DENABLE_LOGGING=OFF -DENABLE_EXTERNAL_PLUGINS=OFF \
    -DCMAKE_CXX_FLAGS="-I$BOOST -DBOOST_DLL_USE_STD_FS -DRIME_DLL=" -DCMAKE_C_FLAGS="-I$BOOST"
  cmake --build "$b" -j "$JOBS"
  cmake --install "$b"
}

merge_static() {   # one libRime.a with every dependency inside
  local libs=()
  for l in rime leveldb marisa opencc yaml-cpp; do
    for f in "$PREFIX"/lib/lib$l*.a; do [ -f "$f" ] && libs+=("$f"); done
  done
  libtool -static -no_warning_for_no_symbols -o "$OUT/libRime.a" "${libs[@]}"
  echo "merged ${#libs[@]} libraries → $OUT/libRime.a ($(du -h "$OUT/libRime.a" | cut -f1))"
}

if [ "$PLATFORM" = xcframework ]; then
  DEST="$ROOT/KeyboardExtension/Frameworks/Rime.xcframework"
  HDR="$ROOT/Vendor/build/headers"
  rm -rf "$HDR" "$DEST"
  mkdir -p "$HDR"
  cp "$RIME/src/rime_api.h" "$RIME/src/rime_levers_api.h" "$HDR/" 2>/dev/null || cp "$RIME/src/rime_api.h" "$HDR/"
  [ -f "$RIME/src/rime_api_deprecated.h" ] && cp "$RIME/src/rime_api_deprecated.h" "$HDR/"
  [ -f "$RIME/src/rime_api_stdbool.h" ] && cp "$RIME/src/rime_api_stdbool.h" "$HDR/"
  cat > "$HDR/module.modulemap" <<'EOF'
module RimeC {
  header "rime_api.h"
  link "c++"
  export *
}
EOF
  xcodebuild -create-xcframework \
    -library "$ROOT/Vendor/build/ios/libRime.a" -headers "$HDR" \
    -library "$ROOT/Vendor/build/iossim/libRime.a" -headers "$HDR" \
    -output "$DEST"
  echo "wrote $DEST"
  exit 0
fi

mkdir -p "$OUT"
build_dep leveldb -DLEVELDB_BUILD_TESTS=OFF -DLEVELDB_BUILD_BENCHMARKS=OFF -DLEVELDB_INSTALL=ON
build_dep marisa-trie -DBUILD_TESTING=OFF -DENABLE_TOOLS=OFF
build_dep yaml-cpp -DYAML_CPP_BUILD_CONTRIB=OFF -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF -DYAML_BUILD_SHARED_LIBS=OFF
build_opencc
build_rime
merge_static

if [ "$PLATFORM" = macos ]; then
  # Host tools (librime only builds them for shared builds): the deployer precompiles
  # dictionaries at app build time; the console is for testing candidates.
  inc=(-I"$RIME/src" -I"$OUT/librime/src" -I"$PREFIX/include" -I"$BOOST" -DRIME_DLL= -std=c++17 -O2)
  c++ "${inc[@]}" "$RIME/tools/rime_deployer.cc" "$OUT/libRime.a" -o "$OUT/rime_deployer"
  c++ "${inc[@]}" "$RIME/tools/rime_api_console.cc" "$RIME/tools/line_editor.cc" "$RIME/tools/completion_catalog.cc" \
    "$OUT/libRime.a" -o "$OUT/rime_api_console"
  echo "tools: $OUT/rime_deployer $OUT/rime_api_console"
fi
