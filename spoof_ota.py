import subprocess

plist_content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ProductBuildVersion</key>
	<string>10A406</string>
	<key>ProductCopyright</key>
	<string>1983-2019 Apple Inc.</string>
	<key>ProductName</key>
	<string>iPhone OS</string>
	<key>ProductVersion</key>
	<string>6.0</string>
</dict>
</plist>
"""

opts = [
    'ssh',
    '-i', r'C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_trd_key',
    '-p', '22222',
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'HostKeyAlgorithms=+ssh-rsa',
    '-o', 'PubkeyAcceptedKeyTypes=+ssh-rsa',
    'root@127.0.0.1'
]

# 1. Backup
subprocess.run(opts + ['cp -p /System/Library/CoreServices/SystemVersion.plist /System/Library/CoreServices/SystemVersion.plist.orig'], check=True)
print("Backup created.")

# 2. Write new plist
p = subprocess.Popen(opts + ['cat > /System/Library/CoreServices/SystemVersion.plist'], stdin=subprocess.PIPE)
p.communicate(input=plist_content.encode('utf-8'))
print("Written new SystemVersion.plist, exit code:", p.returncode)

# 3. Chmod and verify
res = subprocess.run(opts + ['chmod 644 /System/Library/CoreServices/SystemVersion.plist; cat /System/Library/CoreServices/SystemVersion.plist'], capture_output=True, text=True)
print("Verification output:\n" + res.stdout)
