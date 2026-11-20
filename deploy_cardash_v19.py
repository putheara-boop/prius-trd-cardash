import subprocess
import ipad_cmd

srv, port = ipad_cmd.start_ephemeral_tunnel()
try:
    scp_cmd = [
        'scp', '-P', str(port), '-i', r'C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_trd_key',
        '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL',
        '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'PubkeyAcceptedKeyTypes=+ssh-rsa',
        '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa',
        r'd:\Projcet\my_web\cardash_main.m', 'root@127.0.0.1:/var/mobile/h109-build/car-dash/main.m'
    ]
    subprocess.run(scp_cmd, check=True)
finally:
    srv.close()

cmd = (
    "cd /var/mobile/h109-build/car-dash && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O1 -Wno-deprecated-declarations -Wno-arc-performSelector-leaks "
    "-framework UIKit -framework Foundation -framework CoreLocation -framework AVFoundation "
    "-framework AudioToolbox -framework QuartzCore -framework CoreGraphics -framework ImageIO "
    "-framework SystemConfiguration -framework CFNetwork -framework MediaPlayer -framework CoreBluetooth "
    "-framework Speech -framework MapKit -framework CoreMedia -lc++ main.m -o CarDash.new && "
    "/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements CarDash.new && "
    "killall -9 CarDash 2>/dev/null || true; "
    "/bin/cp -f CarDash.new /Applications/CarDash.app/CarDash && "
    "/bin/chmod 755 /Applications/CarDash.app/CarDash && "
    "su - mobile -c '/usr/bin/uiopen cardash://home' && "
    "sleep 2 && "
    "ps aux | grep CarDash | grep -v grep && "
    "ls -la /var/mobile/codex-car/hud-live.plist && "
    "echo CARDASH_V19_HUD_SYNC_OK"
)
ipad_cmd.run_ssh(cmd)
