#!/bin/sh
cd /var/mobile/h109-build/car-dash
export PATH=/bin:/usr/bin:/usr/local/bin:/var/mobile/h109-build/bin:$PATH
export DYLD_LIBRARY_PATH=/var/mobile/h109-build/toolchain/usr/lib
/var/mobile/h109-build/toolchain/usr/share/llvm/bin/clang-3.7 -target armv7-apple-ios9.0 -isysroot /var/mobile/h109-build/sdk -B/var/mobile/h109-build/bin -fobjc-arc -O1 -framework Foundation -framework SystemConfiguration TRDNetworkBroker.m -o trd-network-broker.new || { echo BROKER_COMPILE_FAILED; exit 1; }
/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements trd-network-broker.new
(/usr/bin/killall -9 trd-network-broker 2>/dev/null || true)
/bin/rm -f /usr/local/bin/trd-network-broker
/bin/cp -f trd-network-broker.new /usr/local/bin/trd-network-broker
/bin/chmod 755 /usr/local/bin/trd-network-broker
/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements /usr/local/bin/trd-network-broker
/bin/launchctl stop com.codex.trd.network 2>/dev/null || true
/bin/launchctl start com.codex.trd.network 2>/dev/null || true
echo BROKER_COMPILED_AND_UPDATED
