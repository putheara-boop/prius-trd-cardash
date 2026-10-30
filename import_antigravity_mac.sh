#!/usr/bin/env bash
# ==============================================================================
# import_antigravity_mac.sh
# One-click Antigravity & Account Migration for MacBook (macOS)
# Account: anuphong11868@gmail.com
# ==============================================================================

set -e

echo "=================================================================="
echo "    Antigravity Migration Installer for macOS (MacBook)"
echo "    Account: anuphong11868@gmail.com"
echo "=================================================================="

# 1. Locate the package file
ZIP_FILE=""
if [ -f "./antigravity_mac_package.zip" ]; then
    ZIP_FILE="./antigravity_mac_package.zip"
elif [ -f "$HOME/Downloads/antigravity_mac_package.zip" ]; then
    ZIP_FILE="$HOME/Downloads/antigravity_mac_package.zip"
elif [ -f "$HOME/Desktop/antigravity_mac_package.zip" ]; then
    ZIP_FILE="$HOME/Desktop/antigravity_mac_package.zip"
fi

if [ -z "$ZIP_FILE" ]; then
    echo "[-] Cannot find 'antigravity_mac_package.zip'."
    echo "    Please place 'antigravity_mac_package.zip' in the current folder, Downloads, or Desktop."
    read -p "Enter full path to antigravity_mac_package.zip: " ZIP_FILE
fi

if [ ! -f "$ZIP_FILE" ]; then
    echo "[-] Error: File not found: $ZIP_FILE"
    exit 1
fi

echo "[+] Found package: $ZIP_FILE"

# 2. Close running Antigravity instances on Mac
echo "[1/4] Closing any running Antigravity processes..."
killall -9 Antigravity 2>/dev/null || true

# 3. Prepare target directories
echo "[2/4] Preparing directories..."
GEMINI_TARGET="$HOME/.gemini"
APPSUP_TARGET="$HOME/Library/Application Support/Antigravity"

mkdir -p "$GEMINI_TARGET"
mkdir -p "$APPSUP_TARGET"

# Temporary extraction folder
TMP_EXTRACT=$(mktemp -d)
trap 'rm -rf "$TMP_EXTRACT"' EXIT

echo "[3/4] Extracting package..."
unzip -q "$ZIP_FILE" -d "$TMP_EXTRACT"

# Copy .gemini contents
if [ -d "$TMP_EXTRACT/dot_gemini" ]; then
    echo "    -> Restoring ~/.gemini (Skills, Conversations, Settings, History)..."
    cp -R "$TMP_EXTRACT/dot_gemini/"* "$GEMINI_TARGET/" 2>/dev/null || cp -R "$TMP_EXTRACT/dot_gemini/". "$GEMINI_TARGET/"
fi

# Copy Application Support contents
if [ -d "$TMP_EXTRACT/app_support" ]; then
    echo "    -> Restoring Application Support (Account, Preferences, Layouts)..."
    cp -R "$TMP_EXTRACT/app_support/"* "$APPSUP_TARGET/" 2>/dev/null || cp -R "$TMP_EXTRACT/app_support/". "$APPSUP_TARGET/"
fi

# 4. Set permissions
echo "[4/4] Setting proper macOS permissions..."
chmod -R 755 "$GEMINI_TARGET"
chmod -R 755 "$APPSUP_TARGET"

echo ""
echo "=================================================================="
echo "[SUCCESS] Antigravity profile migrated successfully!"
echo "=================================================================="
echo " - Account Profile: anuphong11868@gmail.com"
echo " - Custom Skills  : All Reverse Engineering Skills restored"
echo " - Conversations  : All chat history and workspaces linked"
echo ""
echo "You can now launch Antigravity on your MacBook!"
echo "When it opens, your account and all projects will appear automatically."
echo "=================================================================="
