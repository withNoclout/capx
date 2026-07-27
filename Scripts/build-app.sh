#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
CONFIGURATION="${1:-release}"

cd "$ROOT"
/usr/bin/swift build --configuration "$CONFIGURATION"
BIN_DIR="$(/usr/bin/swift build --configuration "$CONFIGURATION" --show-bin-path)"
APP_DIR="$ROOT/dist/CapX.app"
CONTENTS_DIR="$APP_DIR/Contents"

/bin/rm -rf "$APP_DIR"
/bin/mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
/bin/cp "$BIN_DIR/capx" "$CONTENTS_DIR/MacOS/capx"
/bin/cp "$ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
/bin/cp "$ROOT/Resources/CapX.icns" "$CONTENTS_DIR/Resources/CapX.icns"
/usr/bin/codesign --force --sign - --timestamp=none "$APP_DIR"

print "$APP_DIR"
