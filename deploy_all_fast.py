import subprocess
import ipad_cmd

FILES = [
    (r'd:\Projcet\my_web\TRDNetworkBroker.m', 'root@127.0.0.1:/var/mobile/h109-build/TRDNetworkBroker.m'),
    (r'd:\Projcet\my_web\TRDSpringBoardPower.m', 'root@127.0.0.1:/var/mobile/h109-build/TRDSpringBoardPower.m'),
    (r'd:\Projcet\my_web\H109RTSP.m', 'root@127.0.0.1:/var/mobile/h109-build/H109RTSP.m'),
    (r'd:\Projcet\my_web\H109HUD.h', 'root@127.0.0.1:/var/mobile/h109-build/H109HUD.h'),
    (r'd:\Projcet\my_web\h109_main.m', 'root@127.0.0.1:/var/mobile/h109-build/main.m'),
    (r'd:\Projcet\my_web\cardash_main.m', 'root@127.0.0.1:/var/mobile/h109-build/car-dash/main.m'),
]

srv, port = ipad_cmd.start_ephemeral_tunnel()
try:
    for src, dst in FILES:
        subprocess.run([
            'scp', '-P', str(port), '-i', r'C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_trd_key',
            '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL',
            '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedKeyTypes=+ssh-rsa',
            '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa',
            src, dst
        ], check=True)
finally:
    srv.close()

cmd = (
    "set -e; "
    "echo '=== LOG SNAPSHOT ==='; "
    "cat /var/mobile/h109-build/rtsp-timing.txt 2>/dev/null || true; "
    "plutil -p /var/mobile/codex-car/network-history.plist 2>/dev/null | tail -n 35 || true; "
    "cd /var/mobile/h109-build && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O2 -Wno-deprecated-declarations "
    "-framework Foundation -framework SystemConfiguration -lc++ "
    "TRDNetworkBroker.m -o trd-network-broker.new && "
    "/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements trd-network-broker.new && "
    "/bin/cp trd-network-broker.new /usr/local/bin/trd-network-broker && "
    "/bin/chmod 755 /usr/local/bin/trd-network-broker && "
    "(killall -9 trd-network-broker 2>/dev/null || true); "
    "echo BROKER_OK && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-dynamiclib -fobjc-arc -fblocks -O2 -Wno-deprecated-declarations "
    "-framework UIKit -framework Foundation -lc++ "
    "TRDSpringBoardPower.m -o TRDSpringBoardPower.dylib.new && "
    "/usr/bin/ldid -S TRDSpringBoardPower.dylib.new && "
    "/bin/rm -f /Library/MobileSubstrate/DynamicLibraries/TRDSpringBoardPower.dylib && "
    "/bin/cp TRDSpringBoardPower.dylib.new /Library/MobileSubstrate/DynamicLibraries/TRDSpringBoardPower.dylib && "
    "/bin/chmod 755 /Library/MobileSubstrate/DynamicLibraries/TRDSpringBoardPower.dylib && "
    "echo SBPOWER_OK && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O2 -Wno-deprecated-declarations "
    "-framework UIKit -framework Foundation -framework AVFoundation -framework CoreMedia "
    "-framework CoreVideo -framework VideoToolbox -framework CoreImage -framework SystemConfiguration "
    "-framework CoreLocation -framework QuartzCore -framework CoreGraphics -lc++ "
    "main.m H109RTSP.m H109RTSP+Stopping.m H109Events.m H109CameraAlerts.m H109Files.m H109Menu.m -o H109Viewer.new && "
    "(killall -9 H109Viewer 2>/dev/null || true); "
    "/bin/rm -f /Applications/H109Viewer.app/H109Viewer && "
    "/bin/cp H109Viewer.new /Applications/H109Viewer.app/H109Viewer && "
    "/bin/chmod 755 /Applications/H109Viewer.app/H109Viewer && "
    "/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements /Applications/H109Viewer.app/H109Viewer && "
    "echo H109_OK && "
    "cd /var/mobile/h109-build/car-dash && "
    "(killall -9 CarDash 2>/dev/null || true); "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O1 -Wno-deprecated-declarations -Wno-arc-performSelector-leaks "
    "-framework UIKit -framework Foundation -framework CoreLocation -framework AVFoundation "
    "-framework AudioToolbox -framework QuartzCore -framework CoreGraphics -framework ImageIO "
    "-framework SystemConfiguration -framework CFNetwork -framework MediaPlayer -framework CoreBluetooth "
    "-framework Speech -framework MapKit -framework CoreMedia -framework CoreVideo -lc++ main.m -o CarDash.new && "
    "/bin/rm -f /Applications/CarDash.app/CarDash && "
    "/bin/cp CarDash.new /Applications/CarDash.app/CarDash && "
    "/bin/chmod 755 /Applications/CarDash.app/CarDash && "
    "/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements /Applications/CarDash.app/CarDash && "
    "su - mobile -c '/usr/bin/uiopen cardash://home/force' && "
    "echo ALL_DEPLOY_COMPLETE"
)
sys.exit(ipad_cmd.run_ssh(cmd)) if False else ipad_cmd.run_ssh(cmd)
