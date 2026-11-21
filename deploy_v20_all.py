import subprocess
import ipad_cmd

srv, port = ipad_cmd.start_ephemeral_tunnel()
try:
    files = [
        (r'd:\Projcet\my_web\TRDOBDClient.h', 'root@127.0.0.1:/var/mobile/h109-build/car-dash/TRDOBDClient.h'),
        (r'd:\Projcet\my_web\TRDOBDClient.m', 'root@127.0.0.1:/var/mobile/h109-build/car-dash/TRDOBDClient.m'),
        (r'd:\Projcet\my_web\cardash_main.m', 'root@127.0.0.1:/var/mobile/h109-build/car-dash/main.m'),
        (r'd:\Projcet\my_web\map.html', 'root@127.0.0.1:/Applications/CarDash.app/map.html'),
        (r'd:\Projcet\my_web\trd_hud_server.m', 'root@127.0.0.1:/var/mobile/h109-build/trd_hud_server.m'),
    ]
    for src, dst in files:
        scp_cmd = [
            'scp', '-P', str(port), '-i', r'C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_trd_key',
            '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL',
            '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedKeyTypes=+ssh-rsa',
            '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa',
            src, dst
        ]
        subprocess.run(scp_cmd, check=True)
finally:
    srv.close()

cmd = (
    "cd /var/mobile/h109-build && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O2 -framework Foundation trd_hud_server.m -o /usr/local/bin/trd-hud-server && "
    "/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements /usr/local/bin/trd-hud-server && "
    "/bin/chmod 755 /usr/local/bin/trd-hud-server && "
    "/bin/launchctl unload /Library/LaunchDaemons/com.codex.trd.hudserver.plist 2>/dev/null || true; "
    "killall -9 trd-hud-server 2>/dev/null || true; "
    "/bin/launchctl load -w /Library/LaunchDaemons/com.codex.trd.hudserver.plist && "
    "cd /var/mobile/h109-build/car-dash && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O1 -Wno-deprecated-declarations -Wno-arc-performSelector-leaks "
    "-framework UIKit -framework Foundation -framework CoreLocation -framework AVFoundation "
    "-framework AudioToolbox -framework QuartzCore -framework CoreGraphics -framework ImageIO "
    "-framework SystemConfiguration -framework CFNetwork -framework MediaPlayer -framework CoreBluetooth "
    "-framework Speech -framework MapKit -framework CoreMedia -lc++ main.m -o CarDash.new && "
    "killall -9 CarDash 2>/dev/null || true; "
    "/bin/rm -f /Applications/CarDash.app/CarDash && "
    "/bin/cp CarDash.new /Applications/CarDash.app/CarDash && "
    "/bin/chmod 755 /Applications/CarDash.app/CarDash && "
    "/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements /Applications/CarDash.app/CarDash && "
    "su - mobile -c '/usr/bin/uiopen cardash://home' && "
    "sleep 2 && "
    "ps aux | grep -E 'CarDash|trd-hud-server' | grep -v grep && "
    "cat /var/mobile/codex-car/hud-live.plist | head -n 25 && "
    "echo V20_ALL_DEPLOY_OK"
)
ipad_cmd.run_ssh(cmd)
