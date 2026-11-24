import subprocess
import ipad_cmd

srv, port = ipad_cmd.start_ephemeral_tunnel()
try:
    for src, dst in [
        (r'd:\Projcet\my_web\H109RTSP.h', 'root@127.0.0.1:/var/mobile/h109-build/h109-viewer/H109RTSP.h'),
        (r'd:\Projcet\my_web\H109RTSP.m', 'root@127.0.0.1:/var/mobile/h109-build/h109-viewer/H109RTSP.m'),
        (r'd:\Projcet\my_web\H109HUD.h', 'root@127.0.0.1:/var/mobile/h109-build/h109-viewer/H109HUD.h'),
        (r'd:\Projcet\my_web\h109_main.m', 'root@127.0.0.1:/var/mobile/h109-build/h109-viewer/h109_main.m'),
        (r'd:\Projcet\my_web\TRDNetworkBroker.m', 'root@127.0.0.1:/var/mobile/h109-build/car-dash/TRDNetworkBroker.m'),
        (r'd:\Projcet\my_web\TRDOBDClient.m', 'root@127.0.0.1:/var/mobile/h109-build/car-dash/TRDOBDClient.m'),
        (r'd:\Projcet\my_web\cardash_main.m', 'root@127.0.0.1:/var/mobile/h109-build/car-dash/main.m'),
        (r'd:\Projcet\my_web\trd_hud_server.m', 'root@127.0.0.1:/var/mobile/h109-build/trd_hud_server.m'),
    ]:
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
    "cd /var/mobile/h109-build && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O2 -Wno-deprecated-declarations "
    "-framework Foundation -lc++ trd_hud_server.m -o trd-hud-server.new && "
    "(/bin/launchctl unload /Library/LaunchDaemons/com.codex.trd.hudserver.plist 2>/dev/null || true); "
    "(killall -9 trd-hud-server 2>/dev/null || true); "
    "/bin/rm -f /usr/local/bin/trd-hud-server && "
    "/bin/cp trd-hud-server.new /usr/local/bin/trd-hud-server && "
    "/bin/chmod 755 /usr/local/bin/trd-hud-server && "
    "/usr/bin/ldid -S /usr/local/bin/trd-hud-server && "
    "/bin/launchctl load -w /Library/LaunchDaemons/com.codex.trd.hudserver.plist && "
    "echo HUDSERVER_OK && "
    "cd /var/mobile/h109-build/car-dash && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O1 -Wno-deprecated-declarations -Wno-arc-performSelector-leaks "
    "-framework UIKit -framework Foundation -framework CoreLocation -framework AVFoundation "
    "-framework AudioToolbox -framework QuartzCore -framework CoreGraphics -framework ImageIO "
    "-framework SystemConfiguration -framework CFNetwork -framework MediaPlayer -framework CoreBluetooth "
    "-framework Speech -framework MapKit -framework CoreMedia -framework CoreVideo -lc++ main.m -o CarDash.new && "
    "grep -q NSCameraUsageDescription /Applications/CarDash.app/Info.plist || "
    "sed -i 's|<key>NSMicrophoneUsageDescription</key>|<key>NSCameraUsageDescription</key><string>ใช้กล้องหน้าตรวจจับการโบกมือเปลี่ยนเพลงและปรับความสว่างหน้าจออัตโนมัติ</string><key>NSMicrophoneUsageDescription</key>|' /Applications/CarDash.app/Info.plist; "
    "/usr/bin/sqlite3 /var/mobile/Library/TCC/TCC.db \"INSERT OR REPLACE INTO access VALUES('kTCCServiceCamera','com.codex.cardash',0,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1700000000);\" 2>/dev/null || true; "
    "(killall -9 CarDash 2>/dev/null || true); "
    "/bin/rm -f /Applications/CarDash.app/CarDash && "
    "/bin/cp CarDash.new /Applications/CarDash.app/CarDash && "
    "/bin/chmod 755 /Applications/CarDash.app/CarDash && "
    "/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements /Applications/CarDash.app/CarDash && "
    "su - mobile -c '/usr/bin/uiopen cardash://home' && "
    "sleep 2 && "
    "ls -lh /Applications/H109Viewer.app/H109Viewer /usr/local/bin/trd-network-broker /usr/local/bin/trd-hud-server /Applications/CarDash.app/CarDash && "
    "ps aux | grep -E 'CarDash|trd-network-broker|trd-hud-server' | grep -v grep && "
    "echo DEPLOY_ALL_4_MODULES_OK"
)
ipad_cmd.run_ssh(cmd)
