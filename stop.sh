#!/bin/sh
rm -f /var/mobile/codex-car/power-connected

# Record car stop timestamp for Battery Guardian
touch /var/mobile/codex-car/car-stop-time

# Wait 6 seconds to show Trip Summary and debounce brief bumps/key restarts
sleep 6

# Re-check with hardware power detector: if power restored, abort!
if /usr/local/bin/trd-power-state >/dev/null 2>&1; then
    touch /var/mobile/codex-car/power-connected
    exit 0
fi

printf '%s car stopped -> entering Ultra Deep Sleep\n' "$(date)" >> /var/mobile/codex-car/events.log

# 1. Pause audio & terminate background players
/usr/bin/activator send libactivator.ipod.pause-playback
killall YTNine LegacyMusic 2>/dev/null || true

# 2. Gracefully dismiss CarDash so it flushes trip data, then kill it to release all GPS NoIdleSleepAssertions
/usr/bin/activator send libactivator.system.homebutton
sleep 1
killall -9 CarDash trd-bt 2>/dev/null || true

# 3. Turn OFF Wi-Fi (cuts power to Wi-Fi chip)
/usr/bin/activator send switch-off.com.a3tweaks.switch.wifi

# 4. Turn OFF Bluetooth (cuts power to BT radio)
/usr/bin/activator send switch-off.com.a3tweaks.switch.bluetooth

# 5. Re-enable autolock and lock screen into Deep Sleep
/usr/bin/activator send switch-on.com.a3tweaks.switch.autolock
/usr/bin/activator send libactivator.lockscreen.show
