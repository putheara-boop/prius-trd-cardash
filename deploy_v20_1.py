import subprocess
import ipad_cmd

srv, port = ipad_cmd.start_ephemeral_tunnel()
try:
    for src, dst in [
        (r'd:\Projcet\my_web\browsereturn.m', 'root@127.0.0.1:/var/mobile/h109-build/browsereturn.m'),
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
    "cd /var/mobile/h109-build && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-dynamiclib -fobjc-arc -fblocks -O1 -Wno-deprecated-declarations "
    "-framework UIKit -framework Foundation -framework AVFoundation -framework MediaPlayer -framework QuartzCore "
    "browsereturn.m -o TRDBrowseReturn.dylib.new && "
    "/bin/rm -f /Library/MobileSubstrate/DynamicLibraries/TRDBrowseReturn.dylib && "
    "/bin/cp TRDBrowseReturn.dylib.new /Library/MobileSubstrate/DynamicLibraries/TRDBrowseReturn.dylib && "
    "/bin/chmod 755 /Library/MobileSubstrate/DynamicLibraries/TRDBrowseReturn.dylib && "
    "/usr/bin/ldid -S /Library/MobileSubstrate/DynamicLibraries/TRDBrowseReturn.dylib && "
    "killall -9 LegacyMusic 2>/dev/null || true; "
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
    "sleep 2 && ps aux | grep -E 'CarDash|trd-hud-server' | grep -v grep && "
    "echo V20_1_DYLIB_AND_CARDASH_OK"
)
ipad_cmd.run_ssh(cmd)
