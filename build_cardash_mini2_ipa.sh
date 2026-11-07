#!/usr/bin/env bash
# ============================================================================
# build_cardash_mini2_ipa.sh
# Builds CarDash-TRD-v3.5.ipa (arm64 / iOS 11.0+) for iPad mini 2 (iPad4,5)
# Version: 3.5.0 (Build 50) - Luxury TRD EV Smart Cockpit (Full WebKit Native Edition)
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/build_mini2_ipa"
APP_DIR="$BUILD_DIR/Payload/CarDash.app"
IPA_OUT="$SCRIPT_DIR/CarDash-TRD-v3.5.ipa"
IPA_MINI2="$SCRIPT_DIR/CarDash-iPadMini2.ipa"

echo "[1/4] Preparing clean Payload directory..."
rm -rf "$BUILD_DIR" "$IPA_OUT" "$IPA_MINI2"
mkdir -p "$APP_DIR"

echo "[2/4] Compiling cardash_mini2_arm64.m for arm64..."
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "Using SDK: $SDK_PATH"

FRAMEWORKS="-framework UIKit -framework WebKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework AVFoundation -framework MediaPlayer -framework AudioToolbox -framework CoreLocation -framework CoreBluetooth"

if xcrun -sdk iphoneos clang \
  -arch arm64 \
  -isysroot "$SDK_PATH" \
  -miphoneos-version-min=11.0 \
  -fobjc-arc \
  -fblocks \
  -O2 \
  -Wno-deprecated-declarations \
  $FRAMEWORKS \
  "$SCRIPT_DIR/cardash_mini2_arm64.m" \
  -o "$APP_DIR/CarDash"; then
  echo "Compilation succeeded with iOS 11.0 deployment target."
else
  echo "Retrying compilation with iOS 12.0 deployment target..."
  xcrun -sdk iphoneos clang \
    -arch arm64 \
    -isysroot "$SDK_PATH" \
    -miphoneos-version-min=12.0 \
    -fobjc-arc \
    -fblocks \
    -O2 \
    -Wno-deprecated-declarations \
    $FRAMEWORKS \
    "$SCRIPT_DIR/cardash_mini2_arm64.m" \
    -o "$APP_DIR/CarDash"
  echo "Compilation succeeded with iOS 12.0 deployment target."
fi

chmod 755 "$APP_DIR/CarDash"

echo "[3/4] Copying Info.plist and HTML5 Cockpit Web Assets..."
cp "$SCRIPT_DIR/Info_mini2.plist" "$APP_DIR/Info.plist"

# Copy HTML5 Cockpit assets into CarDash.app bundle
WEB_ASSETS=(
  "cardash_trd_preview.html"
  "dashboard.html"
  "tailwindcss.min.js"
  "leaflet.js"
  "leaflet.css"
  "PriusGS.png"
  "apple-touch-icon.png"
  "icon-512.png"
  "manifest.json"
)

for asset in "${WEB_ASSETS[@]}"; do
  if [ -f "$SCRIPT_DIR/$asset" ]; then
    echo "  Bundling asset: $asset"
    cp "$SCRIPT_DIR/$asset" "$APP_DIR/$asset"
  elif [ -f "$SCRIPT_DIR/cardash_m1/$asset" ]; then
    echo "  Bundling asset (from cardash_m1): $asset"
    cp "$SCRIPT_DIR/cardash_m1/$asset" "$APP_DIR/$asset"
  fi
done

# Copy app icons
if [ -f "$SCRIPT_DIR/icon-512.png" ]; then
  cp "$SCRIPT_DIR/icon-512.png" "$APP_DIR/Icon-152.png"
  cp "$SCRIPT_DIR/icon-512.png" "$APP_DIR/Icon-76.png"
fi

for icon in cp_dock_home.png cp_icon_camera.png cp_icon_eq.png cp_icon_maps.png cp_icon_music.png cp_icon_settings.png cp_icon_trd.png cp_icon_trip.png cp_icon_youtube.png; do
  if [ -f "$SCRIPT_DIR/$icon" ]; then
    cp "$SCRIPT_DIR/$icon" "$APP_DIR/$icon"
  fi
done

echo "[4/4] Packaging CarDash-TRD-v3.5.ipa..."
(
  cd "$BUILD_DIR"
  zip -qr "$IPA_OUT" Payload
)
cp "$IPA_OUT" "$IPA_MINI2"

echo "=================================================================="
echo "[SUCCESS] Built: $IPA_OUT"
echo "[SUCCESS] Also copied to: $IPA_MINI2"
echo "=================================================================="
