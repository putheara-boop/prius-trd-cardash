#!/bin/sh
touch /var/mobile/codex-car/power-connected
touch /var/mobile/codex-car/welcome-pending
rm -f /var/mobile/codex-car/car-stop-time
printf '%s car started -> waking up HUD\n' "$(date)" >> /var/mobile/codex-car/events.log

# Trigger TRDSpringBoardPower inside SpringBoard:
# - Unblanks display & turns ON backlight
# - Dismisses Lock Screen
# - Disables autolock while charging
# - Turns ON Wi-Fi & Bluetooth
# - Launches CarDash (cardash://welcome)
/usr/local/bin/trd-power-state --wake

# Connect to hotspot & car Bluetooth in background
(sleep 2; /usr/local/bin/trd-network-broker internet) </dev/null >>/var/mobile/codex-car/network-trigger.log 2>&1 &
rmdir /var/mobile/codex-car/bt-connect.lock 2>/dev/null
/bin/sh /var/mobile/codex-car/connect-car.sh </dev/null >>/var/mobile/codex-car/bluetooth-connect.log 2>&1 &

# Ensure CarDash launches clean and fresh
(sleep 1; ps aux | grep -i [C]arDash >/dev/null || uiopen 'cardash://welcome') </dev/null >>/var/mobile/codex-car/events.log 2>&1 &
