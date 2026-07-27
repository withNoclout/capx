#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
SCRATCH_PATH="${SCRATCH_PATH:-$ROOT/.build/universal}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "usage: $0 [debug|release]" >&2
    exit 64
    ;;
esac

SWIFT_ARGUMENTS=(
  --configuration "$CONFIGURATION"
  --arch arm64
  --arch x86_64
  --scratch-path "$SCRATCH_PATH"
)

/usr/bin/swift build "${SWIFT_ARGUMENTS[@]}"
BIN_DIR="$(/usr/bin/swift build "${SWIFT_ARGUMENTS[@]}" --show-bin-path)"
BINARY="$BIN_DIR/capx"

/usr/bin/lipo "$BINARY" -verify_arch arm64 x86_64

APP_DIR="$OUTPUT_DIR/CapX.app"
STAGING_DIR="$OUTPUT_DIR/.CapX.app.$$.staging"
CONTENTS_DIR="$STAGING_DIR/Contents"

cleanup() {
  /bin/rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

/bin/rm -rf "$STAGING_DIR"
/bin/mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
/bin/cp "$BINARY" "$CONTENTS_DIR/MacOS/capx"
/bin/cp "$ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
/bin/cp "$ROOT/Resources/CapX.icns" "$CONTENTS_DIR/Resources/CapX.icns"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  /usr/bin/codesign --force --sign - --timestamp=none "$STAGING_DIR"
else
  /usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$SIGNING_IDENTITY" \
    "$STAGING_DIR"
fi

/usr/bin/codesign --verify --deep --strict "$STAGING_DIR"
/bin/mkdir -p "$OUTPUT_DIR"
/bin/rm -rf "$APP_DIR"
/bin/mv "$STAGING_DIR" "$APP_DIR"
trap - EXIT

printf '%s\n' "$APP_DIR"
