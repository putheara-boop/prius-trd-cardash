#!/bin/sh
touch /var/mobile/codex-car/power-connected
echo "1" > /var/mobile/codex-car/welcome-pending
printf '%s start\n' "$(date)" >> /var/mobile/codex-car/events.log
[ -f /var/mobile/codex-car/power-connected ] || exit 0
/usr/bin/activator send libactivator.lockscreen.dismiss
[ -f /var/mobile/codex-car/power-connected ] || exit 0
/usr/bin/uiopen cardash://welcome
[ -f /var/mobile/codex-car/power-connected ] || exit 0
/usr/bin/activator send switch-off.com.a3tweaks.switch.autolock
[ -f /var/mobile/codex-car/power-connected ] || exit 0
/usr/bin/activator send switch-on.com.a3tweaks.switch.wifi
[ -f /var/mobile/codex-car/power-connected ] || exit 0
/usr/bin/activator send switch-on.com.a3tweaks.switch.bluetooth
[ -f /var/mobile/codex-car/power-connected ] || exit 0
(sleep 2; /usr/local/bin/trd-network-broker internet) </dev/null >>/var/mobile/codex-car/network-trigger.log 2>&1 &
[ -f /var/mobile/codex-car/power-connected ] || exit 0
/bin/sh /var/mobile/codex-car/connect-car.sh </dev/null >>/var/mobile/codex-car/bluetooth-connect.log 2>&1 &
