#!/bin/sh
# Compile and sign locally; does not install or change the running application.
set -eu
BUILD_ROOT=${BUILD_ROOT:-/var/mobile/h109-build}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export PATH="$BUILD_ROOT/bin:/bin:/usr/bin:/usr/local/bin"
export DYLD_LIBRARY_PATH="$BUILD_ROOT/toolchain/usr/lib"
"$BUILD_ROOT/toolchain/usr/share/llvm/bin/clang-3.7" -target armv7-apple-ios9.0 -isysroot "$BUILD_ROOT/sdk" -B"$BUILD_ROOT/bin" -fobjc-arc -fblocks -O1 -Wno-deprecated-declarations -framework UIKit -framework AVFoundation -framework Foundation -framework CFNetwork -framework SystemConfiguration -framework QuartzCore -framework CoreLocation -framework CoreGraphics -framework ImageIO -framework MediaPlayer -framework AudioToolbox -framework CoreMedia "$SCRIPT_DIR/main.m" -o "$SCRIPT_DIR/CarDash.build"
ldid -S "$SCRIPT_DIR/CarDash.build"
printf '%s\n' 'Built and signed CarDash.build; existing app was not changed.'
