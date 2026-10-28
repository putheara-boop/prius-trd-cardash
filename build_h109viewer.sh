#!/bin/sh
cd /var/mobile/h109-build
export PATH=/bin:/usr/bin:/usr/local/bin:/var/mobile/h109-build/bin:$PATH
export DYLD_LIBRARY_PATH=/var/mobile/h109-build/toolchain/usr/lib
toolchain/usr/share/llvm/bin/clang-3.7 -target armv7-apple-ios9.0 -isysroot sdk -B/var/mobile/h109-build/bin -fobjc-arc -fblocks -O1 -Wno-deprecated-declarations -framework CoreLocation -framework UIKit -framework Foundation -framework CFNetwork -framework AVFoundation -framework SystemConfiguration -framework QuartzCore -framework CoreMedia -framework CoreVideo -framework CoreGraphics -framework CoreImage -framework VideoToolbox -framework AVKit -framework ImageIO main.m H109RTSP.m H109Events.m H109CameraAlerts.m H109Files.m -o H109Viewer.app/H109Viewer || { echo H109_COMPILE_FAILED; exit 1; }
/usr/bin/ldid -S H109Viewer.app/H109Viewer
(/usr/bin/killall -9 H109Viewer 2>/dev/null || true)
/bin/rm -f /Applications/H109Viewer.app/H109Viewer
/bin/cp -f H109Viewer.app/H109Viewer /Applications/H109Viewer.app/H109Viewer
/bin/chmod 755 /Applications/H109Viewer.app/H109Viewer
/usr/bin/ldid -S /Applications/H109Viewer.app/H109Viewer
echo H109_COMPILE_SUCCESS
