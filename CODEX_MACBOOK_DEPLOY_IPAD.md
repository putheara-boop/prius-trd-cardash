# CODEX TASK DIRECTIVE: BUILD & DEPLOY CARDASH TO IPAD MINI 2

> **Target Device:** iPad mini 2 Cellular (`iPad4,5` / Board `j86ap`)  
> **iOS Version:** iOS 11.3 (Build 15E216) — Non-jailbroken / Activated  
> **Host Environment:** MacBook (macOS)  
> **Workspace on Mac:** `/Users/actorqwerty/Documents/Codex/2026-11-06/new-chat` (or current active folder)  
> **Primary Objective:** Compile `cardash_mini2_arm64.m` into `CarDash-iPadMini2.ipa` (ARM64), sign it, and install it onto the connected iPad mini 2 via USB.

---

## 1. CONTEXT & BACKGROUND FOR CODEX (MACBOOK)

The user requires a standalone, native **Luxury EV Smart Cockpit (Prius TRD Sportivo Gen 3)** for their iPad mini 2.
Because this iPad is managed by an enterprise MDM profile with strict WebKit content filters (`webContentFilterWhitelistedURLs`), web-based dashboards or unverified internet endpoints are blocked.

To ensure 100% functionality without requiring jailbreak or network bypass, this application has been specifically engineered with:
1. **100% Native UIKit & CoreGraphics Rendering** (Zero WebKit/HTML dependency — bypasses MDM web filter).
2. **Dedicated CoreBluetooth Engine (`TRDOBD2Engine.h`)** for Vgate vLinker MC+ BLE adapter (Real Prius Gen 3 PIDs: ICE RPM, Speed, Inverter Temp, Coolant, 14-Block HV Battery Voltages, ΔV Health, and an offline Demo Simulation mode).
3. **Hardware GPS (`CoreLocation`)** leveraging the iPad mini 2 Cellular's built-in GNSS receiver.
4. **Native Offline Music Player** with `UIFileSharingEnabled` (User can drag `.mp3`/`.m4a` files via Finder/iTunes into the app's Documents folder).
5. **Direct iPad System Settings Launcher** via `UIApplicationOpenSettingsURLString` (Standard Public iOS API).

---

## 2. REQUIRED FILES IN THIS PACKAGE

Ensure the following files from `cardash_mini2_pack.zip` are present in your working directory:

| Filename | Purpose |
| :--- | :--- |
| `cardash_mini2_arm64.m` | Complete native 3-Zone Cockpit UI + App Delegate + Lifecycle |
| `TRDOBD2Engine.h` | CoreBluetooth Vgate vLinker MC+ Engine + 14-Block HV Battery + Thai TTS |
| `car_extras.h` | Theme definitions (`TRDAccent()`, Drive Modes SPORT/NORMAL/ECO) & Welcome Banner |
| `TRDSettingsMenu.h` | Native touch settings action sheet menu |
| `Info_mini2.plist` | iOS 11+ Sandboxed Info.plist (Bluetooth, Location, Audio, File Sharing enabled) |
| `build_cardash_mini2_ipa.sh` | Shell script to compile with Xcode Clang and create `Payload/CarDash.app` |
| `cardash_m1/PriusGS.png` | Prius TRD visual asset |
| `cp_*.png` | Dock icons |

---

## 3. STEP-BY-STEP EXECUTION FOR CODEX (MACBOOK)

Codex on MacBook should execute the following automated steps in order:

### STEP 1: Verify Connected iPad mini 2
Run via Terminal / Bash on Mac:
```bash
# Check if iPad is detected via usbmuxd / libimobiledevice
ideviceinfo -s || ./work/Legacy-iOS-Kit/bin/macos/ideviceinfo -s
```
*Expected Output:* SerialNumber, ProductType: `iPad4,5`, ProductVersion: `11.3`.

---

### STEP 2: Compile and Build `CarDash-iPadMini2.ipa`
Run the compilation script on macOS:
```bash
chmod +x build_cardash_mini2_ipa.sh
./build_cardash_mini2_ipa.sh
```
*Verification:*
Ensure `./CarDash-iPadMini2.ipa` is generated successfully and non-empty:
```bash
ls -lh CarDash-iPadMini2.ipa
```

---

### STEP 3: Sign & Install the IPA onto iPad mini 2

Choose **Method A** (Command-line) or **Method B** (PlumeImpactor UI):

#### Method A: CLI Signing & Installation (Preferred for Codex Automation)
If you have an active Apple ID or local developer certificate and `ideviceinstaller` / `pymobiledevice3`:

```bash
# 1. Sign using ldid or codesign with your existing provisioning profile:
# If you have an identity:
codesign -f -s "iPhone Developer: your_apple_id" --entitlements /dev/null build_mini2_ipa/Payload/CarDash.app

# Re-zip into IPA:
(cd build_mini2_ipa && zip -qr ../CarDash-iPadMini2-signed.ipa Payload)

# 2. Deploy directly to the device:
ideviceinstaller -i CarDash-iPadMini2-signed.ipa
# OR using the bundled tool in work/Legacy-iOS-Kit:
./work/Legacy-iOS-Kit/bin/macos/ideviceinstaller -i CarDash-iPadMini2-signed.ipa
```

#### Method B: PlumeImpactor (GUI / Sideloadly)
If CLI signing lacks an active Provisioning Profile:
1. Open `/Applications/Impactor.app` (PlumeImpactor 2.7.2).
2. Drag and drop `CarDash-iPadMini2.ipa` into Impactor.
3. Sign in using the user's Apple ID (the same Apple ID previously verified on this iPad).
4. Impactor will install the app into the connected iPad mini 2.

---

### STEP 4: First Launch & Permissions Verification on iPad
Once installed:
1. Tap the **CarDash TRD** icon on the iPad home screen.
   *(If prompted "Untrusted Developer", go to **Settings > General > Device Management** and tap **Trust**).*
2. When prompted:
   - Allow **Bluetooth** permission (for Vgate vLinker MC+).
   - Allow **Location** permission (for Hardware GPS speedometer).
3. **Verify App Functions:**
   - [x] Cockpit renders in full-screen landscape (3-Zone EV layout).
   - [x] DEMO mode runs smoothly (Speed, ICE RPM, Energy Flow animation, 14-Block HV Battery).
   - [x] Tap **"⚙️ iPad ตั้งค่า"** at the top right -> confirm iPad Settings opens immediately.
   - [x] Tap **"🔊 เสียงไทย"** -> confirm Thai speech synthesis functions.
   - [x] Connect in-car to **Vgate vLinker MC+** and tap **"🟢 OBD-II: DEMO"** -> transitions to live BLE scanning.

---

## 4. TROUBLESHOOTING & SAFETY CONSTRAINTS

* **DO NOT** modify the live RootFS, APFS snapshots, or attempt raw OTA restoration on this device (as detailed in previous handoffs, snapshot `15E216` vs RootFS `16H88` mismatch will cause a bootloop).
* **DO NOT** attach private entitlements (such as `com.apple.wifi.manager-access`) to this IPA, as standard provisioning profiles will reject the installation with code `-402620395` (A valid provisioning profile for this executable was not found).
* All telemetry, preferences, and offline audio are strictly sandboxed inside `Documents/` and `NSUserDefaults`.
