#!/bin/sh
# Connect iPad to the car stereo (A2DP audio + AVRCP steering-wheel controls).
# Uses native /usr/local/bin/trd-bt (cycript is not installed on this iPad).
cd /var/mobile/codex-car || exit 0
mkdir bt-connect.lock 2>/dev/null || exit 0
trap 'rmdir /var/mobile/codex-car/bt-connect.lock 2>/dev/null' EXIT HUP INT TERM
/usr/local/bin/trd-bt connect "CAR MULTIMEDIA" 90
