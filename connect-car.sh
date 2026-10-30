#!/bin/sh
cd /var/mobile/codex-car || exit 0
mkdir bt-connect.lock 2>/dev/null || exit 0
trap 'rmdir /var/mobile/codex-car/bt-connect.lock 2>/dev/null' EXIT HUP INT TERM
if [ -x /usr/bin/cycript ] && [ -f /var/mobile/codex-car/connect-car.cy ]; then
    /usr/bin/cycript /var/mobile/codex-car/connect-car.cy
fi
