#!/usr/bin/env bash
set -euo pipefail

APP_NAME="macMender"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

VERSION="${1:-${RELEASE_VERSION:-}}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>" >&2
  echo "or set RELEASE_VERSION=<version>" >&2
  exit 2
fi

VERSION="${VERSION#v}"
ZIP_PATH="$DIST_DIR/$APP_NAME-v$VERSION.zip"

BUILD_CONFIGURATION=release "$ROOT_DIR/script/build_and_run.sh" --build-only

rm -f "$ZIP_PATH"

# COPYFILE_DISABLE plus explicit excludes keep AppleDouble metadata out of the
# public archive. The app bundle is signed before this step by build_and_run.sh.
(
  cd "$DIST_DIR"
  COPYFILE_DISABLE=1 /usr/bin/zip -qry "$ZIP_PATH" "$APP_NAME.app" \
    -x "*/.DS_Store" "*/._*" "__MACOSX/*"
)

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

echo "$ZIP_PATH"
echo "$SHA256"
