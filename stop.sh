#!/bin/sh
rm -f /var/mobile/codex-car/power-connected
# Wait 3 seconds to debounce brief bumps/reconnects
sleep 3
[ ! -f /var/mobile/codex-car/power-connected ] || exit 0

printf '%s stop\n' "$(date)" >> /var/mobile/codex-car/events.log

# Pause audio playback
/usr/bin/activator send libactivator.ipod.pause-playback
[ ! -f /var/mobile/codex-car/power-connected ] || exit 0

# Terminate background players
killall YTNine LegacyMusic 2>/dev/null || true
[ ! -f /var/mobile/codex-car/power-connected ] || exit 0

# Turn OFF Wi-Fi
/usr/bin/activator send switch-off.com.a3tweaks.switch.wifi
[ ! -f /var/mobile/codex-car/power-connected ] || exit 0

# Turn OFF Bluetooth
/usr/bin/activator send switch-off.com.a3tweaks.switch.bluetooth
[ ! -f /var/mobile/codex-car/power-connected ] || exit 0

# Re-enable autolock
/usr/bin/activator send switch-on.com.a3tweaks.switch.autolock
[ ! -f /var/mobile/codex-car/power-connected ] || exit 0

# Lock screen / sleep display
/usr/bin/activator send libactivator.lockscreen.show
