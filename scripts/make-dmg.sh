#!/bin/bash
# Packages "Style Check.app" into a drag-to-install disk image:
#   dist/StyleCheck-<version>.dmg
#
# Runs make-app.sh first unless SKIP_BUILD=1.
#
# Optional notarization (needs a Developer ID–signed app, i.e. DEVELOPER_ID set):
#   NOTARY_PROFILE  a keychain profile created with
#                   `xcrun notarytool store-credentials <name> …`
#   or APPLE_ID + APPLE_TEAM_ID + APPLE_APP_PASSWORD (an app-specific password)
set -euo pipefail
cd "$(dirname "$0")/.."

[ "${SKIP_BUILD:-0}" = "1" ] || ./scripts/make-app.sh

APP_NAME="Style Check"
APP="dist/$APP_NAME.app"
[ -d "$APP" ] || { echo "✗ $APP not found. Run scripts/make-app.sh first."; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="dist/StyleCheck-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "▸ Staging disk image contents"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"
cat > "$STAGE/Read Me.txt" <<EOF
Style Check $VERSION

INSTALL
Drag "Style Check" onto the Applications folder.

FIRST LAUNCH
If macOS says it "cannot verify" the app, open System Settings ▸
Privacy & Security, scroll down, and click "Open Anyway" next to
Style Check. You only need to do this once.

On first launch, Style Check downloads a free language model
(about 1–2.3 GB). After that it works fully offline.

REQUIREMENTS
A Mac with Apple silicon (M1 or later), macOS 15 or later,
8 GB of memory, and about 3 GB of free disk space.

Source code and help: https://github.com/vijaisathyan/style-check
EOF

echo "▸ Creating $DMG"
rm -f "$DMG"
hdiutil create -quiet \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO -imagekey zlib-level=9 \
  -ov "$DMG"

# Show the custom volume icon when the image is mounted.
if command -v SetFile >/dev/null 2>&1; then
  RW="$(mktemp -d)/rw.dmg"
  hdiutil convert -quiet "$DMG" -format UDRW -o "$RW"
  MOUNT="$(hdiutil attach -nobrowse -noverify -noautoopen "$RW" | awk -F'\t' '/\/Volumes\// {print $NF; exit}')"
  SetFile -a C "$MOUNT" || true
  hdiutil detach -quiet "$MOUNT"
  rm -f "$DMG"
  hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG"
  rm -f "$RW"
fi

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
  NOTARY_ARGS=()
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ]; then
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD")
  fi
  if [ ${#NOTARY_ARGS[@]} -gt 0 ]; then
    echo "▸ Notarizing (this can take a few minutes)"
    xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait
    xcrun stapler staple "$DMG"
  else
    echo "  (Signed but not notarized: no notarization credentials set.)"
  fi
fi

hdiutil verify -quiet "$DMG"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "✓ Disk image: $DMG ($(du -h "$DMG" | cut -f1))"
