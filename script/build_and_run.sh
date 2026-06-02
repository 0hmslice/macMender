#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="macMender"
BUNDLE_ID="com.ryan.macMender"
MIN_SYSTEM_VERSION="14.0"
ICON_NAME="AppIcon.icns"
ICON_BUNDLE_NAME="AppIcon"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

SWIFT_BUILD_ARGS=""
if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  SWIFT_BUILD_ARGS="-c release"
elif [[ "$BUILD_CONFIGURATION" != "debug" ]]; then
  echo "BUILD_CONFIGURATION must be debug or release" >&2
  exit 2
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build $SWIFT_BUILD_ARGS
BUILD_BINARY="$(swift build $SWIFT_BUILD_ARGS --show-bin-path)/$APP_NAME"
BUILD_PRODUCTS_DIR="$(swift build $SWIFT_BUILD_ARGS --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

while IFS= read -r -d '' resource_bundle; do
  cp -R "$resource_bundle" "$APP_RESOURCES/"
done < <(find "$BUILD_PRODUCTS_DIR" -maxdepth 1 -type d -name '*.bundle' -print0)

if [[ -d "$ROOT_DIR/Sources/macMender/Resources/Mendy" ]]; then
  cp "$ROOT_DIR"/Sources/macMender/Resources/Mendy/*.png "$APP_RESOURCES/"
fi

if [[ -f "$ROOT_DIR/Sources/macMender/Resources/PrivacyInfo.xcprivacy" ]]; then
  cp "$ROOT_DIR/Sources/macMender/Resources/PrivacyInfo.xcprivacy" "$APP_RESOURCES/PrivacyInfo.xcprivacy"
fi

if [[ -f "$ROOT_DIR/icon.icns" ]]; then
  cp "$ROOT_DIR/icon.icns" "$APP_RESOURCES/$ICON_NAME"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_BUNDLE_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Developer ID Application|Apple Development/ { print $2; exit }' || true)"
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --fresh|fresh)
    CONFIG_DIR="$HOME/Library/Application Support/macMender"
    BACKUP_DIR="$CONFIG_DIR.backup.$(date +%Y%m%d%H%M%S)"
    if [[ -d "$CONFIG_DIR" ]]; then
      mv "$CONFIG_DIR" "$BACKUP_DIR"
      echo "Moved existing config to $BACKUP_DIR"
    fi
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --build-only|build-only)
    ;;
  *)
    echo "usage: $0 [run|--fresh|--debug|--logs|--telemetry|--verify|--build-only]" >&2
    exit 2
    ;;
esac
