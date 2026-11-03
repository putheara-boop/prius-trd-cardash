#!/bin/sh
# Fast boot check - minimize wait time
attempts=0
while [ $attempts -lt 25 ]; do
    if /usr/bin/activator current-mode >/dev/null 2>&1; then
        break
    fi
    attempts=$((attempts + 1))
    sleep 1
done
sleep 1

# If connected to power, start HUD immediately
if /usr/local/bin/trd-power-state >/dev/null 2>&1; then
    printf '%s cold boot with power -> fast start HUD\n' "$(date)" >> /var/mobile/codex-car/events.log
    /bin/sh /var/mobile/codex-car/start.sh
fi
