#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
DIST_DIR="${OUTPUT_DIR:-$ROOT/dist}"

if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>" >&2
  exit 64
fi

PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
if [[ "$VERSION" != "$PLIST_VERSION" ]]; then
  echo "version $VERSION does not match Info.plist version $PLIST_VERSION" >&2
  exit 65
fi

if [[ -z "${SIGNING_IDENTITY:-}" ||
      "$SIGNING_IDENTITY" == "-" ||
      "$SIGNING_IDENTITY" != "Developer ID Application:"* ]]; then
  echo "SIGNING_IDENTITY must name a Developer ID Application certificate" >&2
  exit 66
fi

NOTARY_ARGUMENTS=()
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  NOTARY_ARGUMENTS=(--keychain-profile "$NOTARY_PROFILE")
else
  : "${NOTARYTOOL_KEY_ID:?set NOTARY_PROFILE or NOTARYTOOL_KEY_ID}"
  : "${NOTARYTOOL_ISSUER_ID:?set NOTARYTOOL_ISSUER_ID}"
  : "${NOTARYTOOL_KEY_FILE:?set NOTARYTOOL_KEY_FILE}"
  NOTARY_ARGUMENTS=(
    --key "$NOTARYTOOL_KEY_FILE"
    --key-id "$NOTARYTOOL_KEY_ID"
    --issuer "$NOTARYTOOL_ISSUER_ID"
  )
fi

OUTPUT_DIR="$DIST_DIR" "$ROOT/Scripts/build-universal-app.sh" release

APP_PATH="$DIST_DIR/CapX.app"
ARCHIVE_BASENAME="CapX-$VERSION-universal.zip"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_BASENAME"
NOTARIZATION_PATH="$DIST_DIR/.CapX-$VERSION-notarization.zip"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

/usr/bin/codesign --verify --deep --strict "$APP_PATH"
/usr/bin/lipo "$APP_PATH/Contents/MacOS/capx" -verify_arch arm64 x86_64

/bin/rm -f "$NOTARIZATION_PATH" "$ARCHIVE_PATH" "$CHECKSUM_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARIZATION_PATH"

/usr/bin/xcrun notarytool submit \
  "$NOTARIZATION_PATH" \
  "${NOTARY_ARGUMENTS[@]}" \
  --wait

/usr/bin/xcrun stapler staple "$APP_PATH"
/usr/bin/xcrun stapler validate "$APP_PATH"
/usr/sbin/spctl --assess --type execute --verbose=4 "$APP_PATH"
/usr/bin/codesign --verify --deep --strict "$APP_PATH"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"
(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 "$ARCHIVE_BASENAME" > "$ARCHIVE_BASENAME.sha256"
)
/bin/rm -f "$NOTARIZATION_PATH"

printf '%s\n' "$ARCHIVE_PATH"
printf '%s\n' "$CHECKSUM_PATH"
