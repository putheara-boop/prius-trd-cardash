import subprocess
import ipad_cmd

srv, port = ipad_cmd.start_ephemeral_tunnel()
try:
    for src, dst in [
        (r'd:\Projcet\my_web\H109RTSP.m', 'root@127.0.0.1:/var/mobile/h109-build/h109-viewer/H109RTSP.m'),
        (r'd:\Projcet\my_web\H109HUD.h', 'root@127.0.0.1:/var/mobile/h109-build/h109-viewer/H109HUD.h'),
        (r'd:\Projcet\my_web\h109_main.m', 'root@127.0.0.1:/var/mobile/h109-build/h109-viewer/h109_main.m'),
        (r'd:\Projcet\my_web\cardash_main.m', 'root@127.0.0.1:/var/mobile/h109-build/car-dash/main.m'),
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
    "cd /var/mobile/h109-build/h109-viewer && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O1 -Wno-deprecated-declarations "
    "-framework CoreLocation -framework UIKit -framework Foundation -framework CFNetwork "
    "-framework AVFoundation -framework SystemConfiguration -framework QuartzCore "
    "-framework CoreMedia -framework CoreVideo -framework CoreGraphics -framework CoreImage "
    "-framework VideoToolbox -framework AVKit -framework ImageIO "
    "h109_main.m H109RTSP.m -o H109Viewer.new && "
    "(killall -9 H109Viewer 2>/dev/null || true); "
    "/bin/rm -f /Applications/H109Viewer.app/H109Viewer && "
    "/bin/cp H109Viewer.new /Applications/H109Viewer.app/H109Viewer && "
    "/bin/chmod 755 /Applications/H109Viewer.app/H109Viewer && "
    "/usr/bin/ldid -S /Applications/H109Viewer.app/H109Viewer && "
    "echo H109VIEWER_OK && "
    "cd /var/mobile/h109-build/car-dash && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O1 -Wno-deprecated-declarations -Wno-arc-performSelector-leaks "
    "-framework UIKit -framework Foundation -framework CoreLocation -framework AVFoundation "
    "-framework AudioToolbox -framework QuartzCore -framework CoreGraphics -framework ImageIO "
    "-framework SystemConfiguration -framework CFNetwork -framework MediaPlayer -framework CoreBluetooth "
    "-framework Speech -framework MapKit -framework CoreMedia -lc++ main.m -o CarDash.new && "
    "(killall -9 CarDash 2>/dev/null || true); "
    "/bin/rm -f /Applications/CarDash.app/CarDash && "
    "/bin/cp CarDash.new /Applications/CarDash.app/CarDash && "
    "/bin/chmod 755 /Applications/CarDash.app/CarDash && "
    "/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements /Applications/CarDash.app/CarDash && "
    "echo CARDASH_OK && "
    "su - mobile -c '/usr/bin/uiopen cardash://home' && "
    "sleep 2 && "
    "ls -la /Applications/H109Viewer.app/H109Viewer /Applications/CarDash.app/CarDash && "
    "ps aux | grep -E 'CarDash|H109Viewer|trd-hud-server' | grep -v grep && "
    "echo DEPLOY_ALL_OK"
)
ipad_cmd.run_ssh(cmd)
