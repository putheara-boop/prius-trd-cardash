#!/bin/sh
cd /var/mobile/h109-build
export PATH=/var/mobile/h109-build/bin:$PATH
export DYLD_LIBRARY_PATH=/var/mobile/h109-build/toolchain/usr/lib
toolchain/usr/share/llvm/bin/clang-3.7 -target armv7-apple-ios9.0 -isysroot sdk -B/var/mobile/h109-build/bin -fobjc-arc -fblocks -O1 -Wno-deprecated-declarations -framework UIKit -framework AVFoundation -framework Foundation -framework CFNetwork -framework SystemConfiguration -framework QuartzCore -framework CoreLocation -framework CoreGraphics -framework ImageIO -framework MediaPlayer car-dash/main.m -o car-dash/CarDash || { echo CARDASH_BUILD_FAILED; exit 1; }
ldid -S car-dash/CarDash
(killall CarDash 2>/dev/null || true)
cp car-dash/CarDash /Applications/CarDash.app/CarDash.new
chmod 755 /Applications/CarDash.app/CarDash.new
mv -f /Applications/CarDash.app/CarDash.new /Applications/CarDash.app/CarDash
echo CARDASH_BUILD_OK
