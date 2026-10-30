#!/usr/bin/env bash
# ==============================================================================
# 02_mac_downgrade_841.sh
# Downgrade iPad mini 1 (iPad2,7) to Untethered iOS 8.4.1 (daibutsu)
# ==============================================================================

set -e

WORKDIR="$HOME/iPad-TRD-Fix"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -d "Legacy-iOS-Kit" ]; then
    git clone --depth 1 https://github.com/LukeZGD/Legacy-iOS-Kit.git
fi

cd Legacy-iOS-Kit

echo ""
echo "=========================================================================="
echo " [!] Connect iPad mini 1 (iPad2,7) to MacBook via USB cable."
echo " [!] Put iPad into DFU Mode or Normal Mode."
echo " [!] Select options in the menu:"
echo "     1. Restore / Downgrade"
echo "     2. Select iOS 8.4.1"
echo "     3. Enable 'Jailbreak' (daibutsu untethered)"
echo "=========================================================================="
echo ""

./restore.sh
