#!/usr/bin/env bash
set -euo pipefail

APP_NAME="macMender"
# This creates a local Homebrew cask template. Replace OWNER/REPO before
# using the generated cask for a public release.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
RELEASE_DIR="$DIST_DIR/release"
VERSION="${1:-${RELEASE_VERSION:-}}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>" >&2
  echo "or set RELEASE_VERSION=<version>" >&2
  exit 2
fi

VERSION="${VERSION#v}"
ZIP_NAME="$APP_NAME-v$VERSION.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
CASK_PATH="$RELEASE_DIR/macmender.rb"

BUILD_CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --build-only

mkdir -p "$RELEASE_DIR"
rm -f "$ZIP_PATH" "$CASK_PATH" "$RELEASE_DIR/SHA256SUMS"

(
  cd "$DIST_DIR"
  COPYFILE_DISABLE=1 /usr/bin/zip -qry "$ZIP_PATH" "$APP_NAME.app" \
    -x "*/.DS_Store" "*/._*" "__MACOSX/*"
)
SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
printf '%s  %s\n' "$SHA256" "$ZIP_NAME" > "$RELEASE_DIR/SHA256SUMS"

cat > "$CASK_PATH" <<RUBY
cask "macmender" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/OWNER/REPO/releases/download/v#{version}/$ZIP_NAME"
  name "macMender"
  desc "Privacy-first macOS utility for input, Dock, and window quality-of-life fixes"
  homepage "https://github.com/OWNER/REPO"

  depends_on macos: ">= :sonoma"

  app "$APP_NAME.app"

  zap trash: [
    "~/Library/Application Support/macMender",
    "~/Library/LaunchAgents/com.ryan.macMender.login.plist",
  ]
end
RUBY

echo "$ZIP_PATH"
echo "$SHA256"
echo "$CASK_PATH"
