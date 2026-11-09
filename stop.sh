#!/bin/sh
rm -f /var/mobile/codex-car/power-connected
touch /var/mobile/codex-car/car-stop-time

# Wait 12 seconds to allow CarDash 10.0s Trip Summary to finish displaying
sleep 12

# Re-check with hardware power detector: if power restored, abort!
if /usr/local/bin/trd-power-state >/dev/null 2>&1; then
    touch /var/mobile/codex-car/power-connected
    exit 0
fi

printf '%s car stopped -> entering Ultra Deep Sleep\n' "$(date)" >> /var/mobile/codex-car/events.log

# Terminate background audio/bt helpers (do NOT kill CarDash with -9 so it stays warm for Instant ON)
killall YTNine LegacyMusic trd-bt 2>/dev/null || true

# Trigger TRDSpringBoardPower inside SpringBoard:
# - Pauses media
# - Turns OFF Wi-Fi (MobileWiFi + SBWiFiManager + Flipswitch)
# - Turns OFF Bluetooth (BluetoothManager + Flipswitch)
# - Locks UI (SBLockScreenManager + SBUserAgent)
# - Turns OFF LCD backlight & blanks display (SBBacklightController + BKSDisplayServices)
/usr/local/bin/trd-power-state --sleep
