#!/bin/bash
# Builds "Style Check.app" into ./dist. Requires Xcode (not just the
# command-line tools), because MLX's Metal GPU kernels are compiled by xcodebuild.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Style Check"
DERIVED=".build/xcode"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "▸ Building (Release)… first build downloads packages and takes several minutes."
xcodebuild build \
  -scheme StyleCheck \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED" \
  -skipPackagePluginValidation \
  -quiet

PRODUCTS="$DERIVED/Build/Products/Release"

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$PRODUCTS/StyleCheck" "$APP/Contents/MacOS/StyleCheck"
# Resource bundles (including MLX's compiled Metal shaders, mlx-swift_Cmlx.bundle).
for bundle in "$PRODUCTS"/*.bundle; do
  [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

echo "▸ Signing for this Mac (ad hoc)"
codesign --force --deep --sign - "$APP"

echo "✓ Done: $APP"
echo "  Drag it into /Applications, or run:  open \"$APP\""
