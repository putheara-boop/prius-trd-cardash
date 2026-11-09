# PRIUS TRD CarDash — Architecture & Technical Handoff Guide for Codex

> **Vehicle:** Toyota Prius TRD  
> **Target Device:** iPad 2 (iPad2,7 - CDMA/GSM/Wi-Fi), iOS 9.3.6 (Build 13G37), 512 MB RAM, `armv7`  
> **Jailbreak:** EverPwnage / Cydia / OpenSSH (Root access enabled)  
> **Repository:** `https://github.com/putheara-boop/prius-trd-cardash.git` (Branch: `main`)  
> **Local Workspace:** `d:\Projcet\my_web\`  
> **iPad Build Directory:** `/var/mobile/h109-build/`  
> **CarDash Installation:** `/Applications/CarDash.app/CarDash`  
> **Date:** 10 November 2026 (Updated: OBD2 + Reverse Camera + Brake Diagnostics)

---

## 1. System Overview & In-Car Behavior

CarDash is a dedicated in-car head unit HUD tailored for the Toyota Prius TRD. It runs natively on iOS 9.3.6 using direct UIKit and private framework APIs for high responsiveness and low memory consumption (~26 MB RAM, ~1.6% idle CPU).

```
+-----------------------------------------------------------------------------------+
| PRIUS TRD / NORMAL          12:34 PM · Wed, 4 Nov           100% [CHG] · BT · GPS |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|     +-------------+    +-------------+    +-------------+                         |
|     |   SPEED     |    | NOW PLAYING |    | MINI MAP    |                         |
|     |  --- km/h   |    | Song Title  |    | Live GPS    |                         |
|     +-------------+    +-------------+    +-------------+                         |
|                                                                                   |
|     [ 💾 OFFLINE MUSIC ]           [ 🔍 SEARCH MUSIC ]         [ 📻 RADIO ]        |
+-----------------------------------------------------------------------------------+
|  [YouTube]  |  [Music]  |  [Maps]  |  [Camera]  |  [Settings]  |  [Full Clock]   |
+-----------------------------------------------------------------------------------+
```

---

## 2. In-Car Power Automation ("Ultra Deep Sleep" Mode)

The vehicle electrical cycle controls the iPad state automatically via USB 12V-to-5V accessory power.

```mermaid
flowchart TD
    subgraph Car Ignition OFF (Power Disconnect)
        A["🔌 12V Accessory Power Cuts Off"] --> B["Detects UIDeviceBatteryStateUnplugged"]
        B --> C["Displays 'TRIP SUMMARY' (3s Countdown)\nDistance • Duration • Avg Speed • Top Speed"]
        C --> D["Pauses Audio / Radio Playback"]
        D --> E["Runs /var/mobile/codex-car/stop.sh"]
        E --> F["Turns OFF Wi-Fi & Bluetooth Radios"]
        F --> G["Stops GPS (locationd) Assertions"]
        G --> H["Calls /usr/local/bin/trd-power-state --screen-off"]
        H --> I["BKSDisplayServicesSetScreenBlanked(YES) - LCD Off"]
        I --> J["GSEventLockDevice() - Ultra Deep Sleep (~1% drain/day)"]
    end

    subgraph Car Ignition ON (Power Connect)
        K["⚡ 12V Accessory Power Reconnects"] --> L["Detects UIDeviceBatteryStateCharging"]
        L --> M["Runs /var/mobile/codex-car/start.sh"]
        M --> N["Calls /usr/local/bin/trd-power-state --screen-on"]
        N --> O["BKSDisplayServicesSetScreenBlanked(NO)"]
        O --> P["Restores Brightness (0.85 Day / 0.25 Night)"]
        P --> Q["Turns ON Wi-Fi & Bluetooth (auto-connects CAR MULTIMEDIA)"]
        Q --> R["Dismisses Lockscreen & shows 'Welcome, PEEPUT' HUD"]
        R --> S["Instant ON: Ready in 0.5 - 1.0s (No Apple Logo wait)"]
    end
```

### Key Differences Between Modes:
* **Option 1 (Full Shutdown):** Zero drain, but takes **40–45 seconds** to boot from cold Apple logo every time you start the car.
* **Option 2 (Ultra Deep Sleep - Currently Active):** **Instant ON in 0.5–1.0 second**. With Wi-Fi, Bluetooth, GPS, and LCD backlight hardware-cut, standby battery loss is **~1% per 24 hours** (~5-7% per week).

---

## 3. Core Software Architecture & Modules

### 3.1 Source Files Structure
* **`cardash_main.m` / `car_dash_live_main.m`**: Main entry point and Dashboard view controller.
  * Window lifecycle, full-screen canvas (1024x768 landscape).
  * Battery observer: `UIDeviceBatteryStateDidChangeNotification` -> `batteryStateChanged:`.
  * URL schemes router: `cardash://home`, `cardash://welcome`, `cardash://tripsummary`, `cardash://capture`, `cardash://drive`, `cardash://offline`, etc.
* **`CarExtrasMethods.h`**: Hardware display control and settings:
  * `screenOff`: Sets brightness to 0.0, calls `BKSDisplayServicesSetScreenBlanked(YES)`, calls `GSEventLockDevice()`.
  * `restoreDisplayBrightness`: Calls `BKSDisplayServicesSetScreenBlanked(NO)`, sets `idleTimerDisabled = YES`, restores brightness target.
  * Audio route monitor: Detects `CAR MULTIMEDIA` Bluetooth, line-out, or internal speaker.
* **`TRDTripMethods.h` / `TRDTrip.h`**:
  * Tracks distance (meters), elapsed time, current speed, maximum speed, and average speed using `CLLocationManager`.
  * Persists trip states to `/var/mobile/h109-build/gps-road-state.plist`.
* **`EQPresets.h` / `RoadAudio.h`**:
  * EQ presets for Prius acoustics via EQE (`com.r333d.eqe`).
* **`browsereturn.m`**:
  * Intercepts media playback in YouTube/browser and returns to CarDash seamlessly.

### 3.2 Power Management Daemons, Binaries & SpringBoard Tweak
* **`TRDSpringBoardPower.m` -> `/Library/MobileSubstrate/DynamicLibraries/TRDSpringBoardPower.dylib`**:
  * Runs **in-process inside `SpringBoard`** (`[[NSProcessInfo processInfo] processName] == @"SpringBoard"`), holding all Apple private entitlements (`com.apple.wifi.manager-access`, `com.apple.BTServer.allowRestrictedServices`, `com.apple.backboard.client`, `com.apple.keystore.lockassertion`).
  * Listens for `UIDeviceBatteryStateDidChangeNotification` AND Darwin notifications (`com.codex.trd.sleep`, `com.codex.trd.wake`, `com.codex.trd.status`).
  * Includes **Engine Crank Debounce (`gSleepGeneration` / 4.2s verification)**: If power briefly drops while cranking the starter motor and returns within 4.2 seconds, the pending sleep timer is automatically cancelled (`++gSleepGeneration`) and `TRDPerformWake()` is called immediately so the screen never locks or goes dark after engine start.
  * Writes live telemetry to `/var/mobile/codex-car/sb-power-state.plist` (`uiLocked`, `screenIsOn`, `wifiEnabled`, `btEnabled`, `batteryState`, `batteryLevel`).
* **`trd_power.m` -> `/usr/local/bin/trd-power-state`** (Setuid root, `chmod 4755`):
  * No args: Prints `STATE: <battery_state>, LEVEL: <battery_level>` and returns 0 (charging/full) or 1 (unplugged).
  * `--sleep` / `--screen-off`: Posts `notify_post("com.codex.trd.sleep")` to `TRDSpringBoardPower.dylib`.
  * `--wake` / `--screen-on`: Posts `notify_post("com.codex.trd.wake")` to `TRDSpringBoardPower.dylib`.
  * `--status`: Posts `notify_post("com.codex.trd.status")` and prints `/var/mobile/codex-car/sb-power-state.plist`.
* **`/var/mobile/codex-car/stop.sh`**:
  * Triggered on unplug via Activator `libactivator.power.disconnected`.
  * Debounces for 4 seconds, aborts if power returned (`trd-power-state`), terminates background music helpers (`YTNine`, `LegacyMusic`, `trd-bt`) **without killing `CarDash`**, and executes `/usr/local/bin/trd-power-state --sleep`.
* **`/var/mobile/codex-car/start.sh`**:
  * Triggered on power reconnect via Activator `libactivator.power.connected`.
  * Calls `/usr/local/bin/trd-power-state --wake` and starts background hotspot (`trd-network-broker internet`) and Bluetooth (`connect-car.sh`).

---

## 4. Hardware Display Blanking vs Activator

> [!WARNING]
> Do NOT rely on `/usr/bin/activator send libactivator.lockscreen.show` or `libactivator.system.sleep-button` from background scripts.
> 1. In iOS 9, non-SpringBoard processes fail with `Activator: Failed to lookup mach port with error 44e`.
> 2. `libactivator.lockscreen.show` turns the backlight **ON** to show the clock, which keeps the LCD panel illuminated.
> 3. **The correct way** is calling `BKSDisplayServicesSetScreenBlanked` directly via `BackBoardServices.framework`.

```c
// Hardware LCD Backlight Cutoff
void *bks = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
if (bks) {
    void (*blank)(BOOL) = (void (*)(BOOL))dlsym(bks, "BKSDisplayServicesSetScreenBlanked");
    if (blank) blank(YES); // YES = cut backlight completely; NO = restore backlight
}

// Hardware Lock Event
void *gs = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_LAZY);
if (gs) {
    void (*lock)(void) = (void (*)(void))dlsym(gs, "GSEventLockDevice");
    if (lock) lock();
}
```

---

## 5. Development, Build & Deployment Workflow

### 5.1 Host Connection & SSH Tunnel
* Connection: USB cable via `usbmuxd` (Windows port 27015).
* Tunnel Daemon: `C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_usb_tunnel.py` forwarding `127.0.0.1:22222` to iPad port 22.
* SSH Authentication:
  ```bash
  ssh -i C:\Users\Intel\AppData\Local\Temp\trd-ipad-usb\ipad_trd_key -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa -p 22222 root@127.0.0.1
  ```

### 5.2 Compiling On-Device
The iPad has an on-device LLVM 3.7 toolchain configured:
```bash
# Deploy updated files
scp -P 22222 cardash_main.m root@127.0.0.1:/var/mobile/h109-build/car-dash/main.m
scp -P 22222 CarExtrasMethods.h root@127.0.0.1:/var/mobile/h109-build/car-dash/CarExtrasMethods.h

# Execute build script on iPad
ssh -p 22222 root@127.0.0.1 "/var/mobile/h109-build/build_cardash.sh"
```

Content of `/var/mobile/h109-build/build_cardash.sh`:
```sh
#!/bin/sh
cd /var/mobile/h109-build
export PATH=/bin:/usr/bin:/var/mobile/h109-build/bin
export DYLD_LIBRARY_PATH=/var/mobile/h109-build/toolchain/usr/lib
toolchain/usr/share/llvm/bin/clang-3.7 -target armv7-apple-ios9.0 -isysroot sdk \
  -B/var/mobile/h109-build/bin -fobjc-arc -fblocks -O1 -Wno-deprecated-declarations \
  -framework UIKit -framework AVFoundation -framework Foundation -framework CFNetwork \
  -framework SystemConfiguration -framework QuartzCore -framework CoreLocation \
  -framework CoreGraphics -framework ImageIO -framework MediaPlayer \
  -framework AudioToolbox -framework CoreMedia \
  car-dash/main.m -o car-dash/CarDash || { echo CARDASH_BUILD_FAILED; exit 1; }

ldid -S car-dash/CarDash
killall -9 CarDash 2>/dev/null || true
cp car-dash/CarDash /Applications/CarDash.app/CarDash.new
chmod 755 /Applications/CarDash.app/CarDash.new
mv -f /Applications/CarDash.app/CarDash.new /Applications/CarDash.app/CarDash
echo CARDASH_BUILD_OK
```

---

## 6. Verification Checklist

When continuing this project with Codex, always verify the following states:
1. **Process check:** `ps aux | grep -i cardash` (should run under user `mobile`, memory < 30 MB).
2. **Power check:** `/usr/local/bin/trd-power-state` (prints state `2` = charging, `1` = unplugged).
3. **Capture UI:** `uiopen cardash://capture` writes current render to `/var/mobile/h109-build/cardash.png`.
4. **Cards intact:** Ensure 6 cards at bottom are never obstructed:
   `[YouTube] [Music] [Maps] [Camera] [Settings] [Full Clock]`
5. **Offline Music:** Must show native popup with 12 downloaded songs without navigating away from Home.
