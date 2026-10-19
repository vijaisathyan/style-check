#!/bin/bash
# Builds "Style Check.app" into ./dist.
#
# Requires Xcode (not just the command-line tools), because MLX's Metal GPU
# kernels are compiled by xcodebuild. Apple silicon only.
#
# Signing:
#   - By default the app is signed "ad hoc": it runs on this Mac, and on other
#     Macs after the user approves it once (see README → Installing).
#   - Set DEVELOPER_ID to a "Developer ID Application: …" identity in your
#     keychain to sign it for distribution (then run make-dmg.sh to notarize).
#
# Environment:
#   VERSION       app version, e.g. 0.2.0 (default: from git tag, else 0.0.0)
#   BUILD_NUMBER  build number (default: git commit count)
#   DEVELOPER_ID  optional signing identity
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Style Check"
DERIVED=".build/xcode"
DIST="dist"
APP="$DIST/$APP_NAME.app"

VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-0.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

echo "▸ Building Style Check $VERSION ($BUILD_NUMBER), Release, arm64"
echo "  The first build downloads packages and compiles MLX; allow several minutes."
xcodebuild build \
  -scheme StyleCheck \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED" \
  -skipPackagePluginValidation \
  ONLY_ACTIVE_ARCH=YES \
  -quiet

PRODUCTS="$DERIVED/Build/Products/Release"
[ -f "$PRODUCTS/StyleCheck" ] || { echo "✗ Build product not found in $PRODUCTS"; exit 1; }

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$PRODUCTS/StyleCheck" "$APP/Contents/MacOS/StyleCheck"

# Resource bundles, including MLX's compiled Metal shaders (mlx-swift_Cmlx.bundle).
found_mlx=0
for bundle in "$PRODUCTS"/*.bundle; do
  [ -e "$bundle" ] || continue
  cp -R "$bundle" "$APP/Contents/Resources/"
  [[ "$(basename "$bundle")" == mlx-swift_Cmlx.bundle ]] && found_mlx=1
done
if [ "$found_mlx" -ne 1 ]; then
  echo "✗ mlx-swift_Cmlx.bundle (Metal shaders) is missing; the app could not run models."
  exit 1
fi

# Dynamic package frameworks, if any were produced.
if [ -d "$PRODUCTS/PackageFrameworks" ] && ls "$PRODUCTS/PackageFrameworks"/*.framework >/dev/null 2>&1; then
  mkdir -p "$APP/Contents/Frameworks"
  cp -R "$PRODUCTS/PackageFrameworks"/*.framework "$APP/Contents/Frameworks/"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/StyleCheck" 2>/dev/null || true
fi

sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" \
  Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ -n "${DEVELOPER_ID:-}" ]; then
  echo "▸ Signing with \"$DEVELOPER_ID\" (hardened runtime)"
  # Sign nested code first, then the app.
  if [ -d "$APP/Contents/Frameworks" ]; then
    find "$APP/Contents/Frameworks" -name "*.framework" -maxdepth 1 -exec \
      codesign --force --timestamp --options runtime --sign "$DEVELOPER_ID" {} \;
  fi
  codesign --force --timestamp --options runtime \
    --entitlements Resources/StyleCheck.entitlements \
    --sign "$DEVELOPER_ID" "$APP"
else
  echo "▸ Signing ad hoc (no Developer ID set)"
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"

echo "✓ Built: $APP"
