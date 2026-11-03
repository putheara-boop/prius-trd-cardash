#!/bin/sh
touch /var/mobile/codex-car/power-connected
rm -f /var/mobile/codex-car/car-stop-time
printf '%s car started -> waking up HUD\n' "$(date)" >> /var/mobile/codex-car/events.log

# 1. Dismiss lock screen immediately
/usr/bin/activator send libactivator.lockscreen.dismiss

# 2. Disable autolock so screen stays on while driving
/usr/bin/activator send switch-off.com.a3tweaks.switch.autolock

# 3. Turn ON Wi-Fi and Bluetooth
/usr/bin/activator send switch-on.com.a3tweaks.switch.wifi
/usr/bin/activator send switch-on.com.a3tweaks.switch.bluetooth

# 4. Launch CarDash immediately
/usr/bin/activator send com.codex.cardash
/usr/bin/uiopen cardash://welcome

# 5. Connect to hotspot & car Bluetooth in background
(sleep 2; /usr/local/bin/trd-network-broker internet) </dev/null >>/var/mobile/codex-car/network-trigger.log 2>&1 &
rmdir /var/mobile/codex-car/bt-connect.lock 2>/dev/null
/bin/sh /var/mobile/codex-car/connect-car.sh </dev/null >>/var/mobile/codex-car/bluetooth-connect.log 2>&1 &
