#!/usr/bin/env bash
# ==============================================================================
# 01_mac_quick_fix_936.sh
# Fix SystemVersion.plist back to genuine iOS 9.3.6 (13G37) via SSH Ramdisk
# Tested on macOS (Terminal)
# ==============================================================================

set -e

echo "=== [Step 1] Checking dependencies on MacBook ==="
if ! command -v git &>/dev/null; then
    echo "[-] Git not found. Please install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

WORKDIR="$HOME/iPad-TRD-Fix"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "=== [Step 2] Cloning Legacy iOS Kit ==="
if [ ! -d "Legacy-iOS-Kit" ]; then
    git clone --depth 1 https://github.com/LukeZGD/Legacy-iOS-Kit.git
else
    echo "[+] Legacy-iOS-Kit already downloaded."
fi

cd Legacy-iOS-Kit

echo ""
echo "=========================================================================="
echo " [!] Connect iPad mini 1 to MacBook via USB cable."
echo " [!] Put iPad into DFU Mode:"
echo "     1. Hold POWER + HOME buttons together for 10 seconds."
echo "     2. Release POWER button, KEEP HOLDING HOME button for 10 seconds."
echo "     3. The screen must remain completely BLACK."
echo "=========================================================================="
echo ""
read -p "Press ENTER when your iPad is connected in DFU Mode..."

echo ""
echo "=== [Step 3] Launching Legacy iOS Kit SSH Ramdisk ==="
echo "Select: Other Utilities -> SSH Ramdisk"
echo ""

./restore.sh
