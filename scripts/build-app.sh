#!/usr/bin/env bash
# Assemble Coco.app by hand from a SwiftPM binary. No Xcode required.
set -euo pipefail

APP_NAME="Coco"
BUNDLE_ID="com.paologiua.coco"
VERSION="1.0"
BUILD="1"
SDK15="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/dist/$APP_NAME.app"

# 0. Pin the macOS 15 SDK so macOS 26 symbols are not even in scope. A CLT update
#    could remove it — fail loudly rather than silently building against 26.
[ -d "$SDK15" ] || { echo "FATAL: macOS 15 SDK missing at $SDK15"; exit 1; }
export SDKROOT="$SDK15"

# 1. Build.
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/$APP_NAME"

# 2. Prove the deployment target landed.
vtool -show-build-version "$BIN" | grep -q "minos 15.0" \
  || { echo "FATAL: binary is not minos 15.0"; vtool -show-build-version "$BIN"; exit 1; }

# 3. Guard against Bundle.module creeping back in. A resource bundle in the bin path
#    means someone added `resources:` to Package.swift, which builds fine here and
#    crashes on the recipient's Mac.
if compgen -G "$(dirname "$BIN")/*.bundle" > /dev/null; then
  echo "FATAL: SwiftPM produced a resource bundle. Remove 'resources:' from Package.swift."
  exit 1
fi

# 4. Assemble.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

# 5. Sprites go straight into Contents/Resources, read at runtime via Bundle.main.
cp -R "$ROOT/Assets/Sprites" "$APP/Contents/Resources/Sprites"
cp -R "$ROOT/Assets/Menubar" "$APP/Contents/Resources/Menubar"
cp -R "$ROOT/Assets/UI" "$APP/Contents/Resources/UI"
cp -R "$ROOT/Assets/Hatch" "$APP/Contents/Resources/Hatch"
cp -R "$ROOT/Assets/LetterAnim" "$APP/Contents/Resources/LetterAnim"
# Plain text, not compiled in: the birthday message can be rewritten in later years
# by editing this file inside the bundle, with no toolchain and no rebuild.

# 6. Icon, once Assets/Icon exists (ticket 05). iconutil ships with the CLT.
if [ -d "$ROOT/Assets/Icon" ]; then
  rm -rf "$ROOT/build/$APP_NAME.iconset"
  mkdir -p "$ROOT/build/$APP_NAME.iconset"
  for s in 16 32 128 256 512; do
    cp "$ROOT/Assets/Icon/icon_${s}.png"     "$ROOT/build/$APP_NAME.iconset/icon_${s}x${s}.png"
    cp "$ROOT/Assets/Icon/icon_$((s*2)).png" "$ROOT/build/$APP_NAME.iconset/icon_${s}x${s}@2x.png"
  done
  iconutil -c icns "$ROOT/build/$APP_NAME.iconset" -o "$APP/Contents/Resources/$APP_NAME.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>$APP_NAME</string>"
else
  echo "note: Assets/Icon not present yet — building without an app icon"
  ICON_KEY=""
fi

# 7. Info.plist. LSUIElement is what keeps Coco out of the Dock and the app switcher.
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  $ICON_KEY
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" > /dev/null

# 8. Ad-hoc sign. No --deep (deprecated since macOS 13), no hardened runtime,
#    no entitlements — none are needed and all of them cost trouble.
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
codesign --verify --strict "$APP"

echo "built $APP"
codesign -dvv "$APP" 2>&1 | grep -E "^(Identifier|Signature|TeamIdentifier)" || true

# 9. Install into /Applications and relaunch, by default.
#
#    Coco is always run from /Applications, never from dist/. Two copies is how you
#    end up staring at a bug you already fixed: the build lands in dist/ while the
#    thing on screen is whatever was installed last. It is also the only place the
#    delivered app will ever live, so testing anywhere else tests the wrong bundle.
if [ "${1:-}" = "--no-install" ]; then
  echo "skipped install (--no-install) — note that a running Coco is now older than this build"
  exit 0
fi

DEST="/Applications/$APP_NAME.app"
# She saves every minute and on quit, so at worst a minute of decay is lost.
pkill -x "$APP_NAME" 2>/dev/null && sleep 1 || true
rm -rf "$DEST"
# ditto rather than cp -R: it preserves the signature and the bundle's metadata.
ditto "$APP" "$DEST"
codesign --verify --strict "$DEST"
open "$DEST"
echo "installed and launched $DEST"
