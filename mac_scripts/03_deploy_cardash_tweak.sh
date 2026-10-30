#!/usr/bin/env bash
# ==============================================================================
# 03_deploy_cardash_tweak.sh
# Automate CarDash, TRD Audio Presets, and Untethered Auto-Launch via Mac SSH
# ==============================================================================

IPAD_IP="${1:-127.0.0.1}"
IPAD_PORT="${2:-2222}"

echo "=== Deploying to iPad at $IPAD_IP:$IPAD_PORT ==="

SSH_CMD="ssh -p $IPAD_PORT -o StrictHostKeyChecking=no root@$IPAD_IP"
SCP_CMD="scp -P $IPAD_PORT -o StrictHostKeyChecking=no"

echo "[1/4] Checking SSH connection (Password: alpine)..."
$SSH_CMD "uname -a; sw_vers"

echo "[2/4] Restoring SystemVersion.plist if backup exists..."
$SSH_CMD "if [ -f /System/Library/CoreServices/SystemVersion.plist.orig ]; then cp -f /System/Library/CoreServices/SystemVersion.plist.orig /System/Library/CoreServices/SystemVersion.plist; chmod 644 /System/Library/CoreServices/SystemVersion.plist; echo 'SystemVersion restored!'; fi"

echo "[3/4] Ensuring TRD EQ Presets are active..."
$SSH_CMD "mkdir -p /var/tweak/com.r333d.eqe/db/presets/ && chown -R mobile:mobile /var/tweak/com.r333d.eqe/db/presets/"

echo "[4/4] Restarting SpringBoard..."
$SSH_CMD "killall -9 SpringBoard"

echo "=== DEPLOYMENT COMPLETE! ==="
