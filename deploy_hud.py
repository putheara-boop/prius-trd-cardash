import subprocess
import ipad_cmd

plist_content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.codex.trd.hudserver</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/trd-hud-server</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
"""

with open(r'd:\Projcet\my_web\com.codex.trd.hudserver.plist', 'w', encoding='utf-8', newline='\n') as f:
    f.write(plist_content)

srv, port = ipad_cmd.start_ephemeral_tunnel()
try:
    for src, dst in [
        (r'd:\Projcet\my_web\trd_hud_server.m', 'root@127.0.0.1:/var/mobile/h109-build/trd_hud_server.m'),
        (r'd:\Projcet\my_web\com.codex.trd.hudserver.plist', 'root@127.0.0.1:/Library/LaunchDaemons/com.codex.trd.hudserver.plist')
    ]:
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

remote_sh = (
    "/usr/sbin/scutil --set LocalHostName cardash && "
    "/usr/sbin/scutil --set ComputerName cardash && "
    "/usr/sbin/scutil --set HostName cardash.local && "
    "killall -HUP mDNSResponder 2>/dev/null || true; "
    "cd /var/mobile/h109-build && "
    "rm -f /usr/local/bin/trd-hud-server && "
    "/usr/bin/clang-10 -arch arm64 -isysroot /var/mobile/h109-build/sdks/iPhoneOS12.4.sdk "
    "-fobjc-arc -fblocks -O2 -framework Foundation trd_hud_server.m -o /usr/local/bin/trd-hud-server && "
    "/usr/bin/ldid -S/var/mobile/h109-build/car-dash/TRDNetwork.entitlements /usr/local/bin/trd-hud-server && "
    "/bin/chmod 755 /usr/local/bin/trd-hud-server && "
    "/bin/chmod 644 /Library/LaunchDaemons/com.codex.trd.hudserver.plist && "
    "/bin/launchctl unload /Library/LaunchDaemons/com.codex.trd.hudserver.plist 2>/dev/null || true; "
    "killall -9 trd-hud-server 2>/dev/null || true; "
    "/bin/launchctl load -w /Library/LaunchDaemons/com.codex.trd.hudserver.plist && "
    "sleep 1 && "
    "ps aux | grep trd-hud-server && "
    "echo IP_EN0=$(/usr/sbin/ipconfig getifaddr en0) && "
    "echo HOST_NOW=$(/usr/sbin/scutil --get LocalHostName) && "
    "echo HUD_NATIVE_DEPLOY_OK"
)
ipad_cmd.run_ssh(remote_sh)
