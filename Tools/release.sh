#!/bin/bash
# Archive PlanetKeyboard and upload it to App Store Connect (TestFlight).
#
#   Tools/release.sh            # test, archive, upload
#   Tools/release.sh --no-upload  # test + archive + export .ipa only
#   Tools/release.sh --skip-tests
#
# Auth: if ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH are set (App Store Connect API key, .p8),
# they are used; otherwise the Apple ID signed in to Xcode (Settings → Accounts) is used.
# Optional: put those three variables in ~/.planetkeyboard-release.env (never in this repo).
# Build number = UTC timestamp, so every upload is unique. Version comes from MARKETING_VERSION in project.yml.
set -euo pipefail
cd "$(dirname "$0")/.."

UPLOAD=1; TESTS=1
for arg in "$@"; do
  case "$arg" in
    --no-upload) UPLOAD=0 ;;
    --skip-tests) TESTS=0 ;;
    *) echo "unknown option: $arg"; exit 2 ;;
  esac
done

[ -f "$HOME/.planetkeyboard-release.env" ] && source "$HOME/.planetkeyboard-release.env"
AUTH=()
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
  AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

BUILD_NUMBER=$(date -u +%Y%m%d%H%M)
OUT="build/release/$BUILD_NUMBER"
ARCHIVE="$OUT/PlanetKeyboard.xcarchive"
mkdir -p "$OUT"

xcodegen generate --quiet

if [ "$TESTS" = 1 ]; then
  SIM=$(xcrun simctl list devices available | grep -m1 -oE 'iPhone [^(]+\(([0-9A-F-]{36})\)' | grep -oE '[0-9A-F-]{36}')
  echo "▶ tests"
  xcodebuild test -project PlanetKeyboard.xcodeproj -scheme PlanetKeyboard \
    -destination "id=$SIM" -quiet
fi

echo "▶ archive (build $BUILD_NUMBER)"
xcodebuild archive -project PlanetKeyboard.xcodeproj -scheme PlanetKeyboard \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} -quiet

DEST=export; [ "$UPLOAD" = 1 ] && DEST=upload
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$DEST</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>2F737PV5X6</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "▶ export ($DEST)"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}

if [ "$UPLOAD" = 1 ]; then
  echo "✅ uploaded build $BUILD_NUMBER — it appears in App Store Connect → TestFlight after processing (~5–30 min)."
else
  echo "✅ exported $OUT/export"
fi
