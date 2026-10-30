#!/bin/sh
cd /var/mobile/h109-build/car-dash
export PATH=/bin:/usr/bin:/usr/local/bin:/var/mobile/h109-build/bin:$PATH
export DYLD_LIBRARY_PATH=/var/mobile/h109-build/toolchain/usr/lib
/var/mobile/h109-build/toolchain/usr/share/llvm/bin/clang-3.7 -target armv7-apple-ios9.0 -isysroot /var/mobile/h109-build/sdk -B/var/mobile/h109-build/bin -fobjc-arc -O1 -framework Foundation -framework AVFoundation trd_bt.m -o trd-bt.new || { echo BT_COMPILE_FAILED; exit 1; }
/usr/bin/ldid -S trd-bt.new
/bin/cp -f trd-bt.new /usr/local/bin/trd-bt
/bin/chmod 755 /usr/local/bin/trd-bt
/usr/bin/ldid -S /usr/local/bin/trd-bt
echo BT_BUILD_OK
