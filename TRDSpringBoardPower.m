#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <notify.h>

typedef CFTypeRef WiFiManagerRef;
static WiFiManagerRef (*pWiFiManagerClientCreate)(CFAllocatorRef, int) = NULL;
static void (*pWiFiManagerClientSetPower)(WiFiManagerRef, Boolean) = NULL;
static Boolean (*pWiFiManagerClientGetPower)(WiFiManagerRef) = NULL;
static void (*pBKSDisplayServicesSetScreenBlanked)(BOOL) = NULL;
static Boolean (*pMRMediaRemoteSendCommand)(int, id) = NULL;

static WiFiManagerRef gWiFiMgr = NULL;
static BOOL gSleepScheduled = NO;
static int gSleepGeneration = 0;

@interface NSObject (TRDSBPrivate)
+ (id)sharedInstance;
+ (id)sharedUserAgent;
+ (id)sharedPanel;
+ (id)defaultWorkspace;
+ (id)eventWithName:(NSString *)name mode:(NSString *)mode;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
- (NSString *)currentEventMode;
- (void)sendEvent:(id)event toListenerWithName:(NSString *)name;
- (void)setState:(int)state forSwitchIdentifier:(NSString *)ident;
- (void)setWiFiEnabled:(BOOL)enabled;
- (BOOL)wiFiEnabled;
- (BOOL)setPowered:(BOOL)powered;
- (BOOL)powered;
- (BOOL)enabled;
- (void)lockUIFromSource:(int)source withOptions:(id)options;
- (BOOL)unlockUIFromSource:(int)source withOptions:(id)options;
- (void)_lockUI;
- (BOOL)isUILocked;
- (void)lockAndDimDevice;
- (void)lockAndDimDeviceDisconnectingCallIfNecessary:(BOOL)disc andDimScreen:(BOOL)dim;
- (void)setBacklightFactor:(float)factor source:(int)source;
- (void)turnOnScreenFullyWithBacklightSource:(int)source;
- (void)_startFadeOutAnimationFromLockSource:(int)source;
- (BOOL)screenIsOn;
@end

@interface TRDBluetoothManagerProxy : NSObject
- (BOOL)setPowered:(BOOL)powered;
- (BOOL)setEnabled:(BOOL)enabled;
- (BOOL)powered;
- (BOOL)enabled;
@end

static void TRDInitSymbols(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *wifiLib = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_LAZY);
        if (wifiLib) {
            pWiFiManagerClientCreate = (WiFiManagerRef (*)(CFAllocatorRef, int))dlsym(wifiLib, "WiFiManagerClientCreate");
            pWiFiManagerClientSetPower = (void (*)(WiFiManagerRef, Boolean))dlsym(wifiLib, "WiFiManagerClientSetPower");
            pWiFiManagerClientGetPower = (Boolean (*)(WiFiManagerRef))dlsym(wifiLib, "WiFiManagerClientGetPower");
            if (pWiFiManagerClientCreate) {
                gWiFiMgr = pWiFiManagerClientCreate(kCFAllocatorDefault, 0);
            }
        }
        void *bksLib = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        if (bksLib) {
            pBKSDisplayServicesSetScreenBlanked = (void (*)(BOOL))dlsym(bksLib, "BKSDisplayServicesSetScreenBlanked");
        }
        void *mrLib = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
        if (mrLib) {
            pMRMediaRemoteSendCommand = (Boolean (*)(int, id))dlsym(mrLib, "MRMediaRemoteSendCommand");
        }
        dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_LAZY);
    });
}

static void TRDWriteStatus(NSString *action) {
    TRDInitSymbols();
    Class lockCls = objc_getClass("SBLockScreenManager");
    id lockMgr = [lockCls respondsToSelector:@selector(sharedInstance)] ? [lockCls sharedInstance] : nil;
    BOOL uiLocked = (lockMgr && [lockMgr respondsToSelector:@selector(isUILocked)]) ? [lockMgr isUILocked] : NO;

    Class blCls = objc_getClass("SBBacklightController");
    id blMgr = [blCls respondsToSelector:@selector(sharedInstance)] ? [blCls sharedInstance] : nil;
    BOOL screenOn = (blMgr && [blMgr respondsToSelector:@selector(screenIsOn)]) ? [blMgr screenIsOn] : NO;

    Class wifiCls = objc_getClass("SBWiFiManager");
    id wifiMgr = [wifiCls respondsToSelector:@selector(sharedInstance)] ? [wifiCls sharedInstance] : nil;
    BOOL sbWifi = (wifiMgr && [wifiMgr respondsToSelector:@selector(wiFiEnabled)]) ? [wifiMgr wiFiEnabled] : NO;
    BOOL hwWifi = (gWiFiMgr && pWiFiManagerClientGetPower) ? (BOOL)pWiFiManagerClientGetPower(gWiFiMgr) : sbWifi;

    Class btCls = objc_getClass("BluetoothManager");
    TRDBluetoothManagerProxy *btMgr = [btCls respondsToSelector:@selector(sharedInstance)] ? (TRDBluetoothManagerProxy *)[btCls sharedInstance] : nil;
    BOOL btEnabled = (btMgr && [btMgr respondsToSelector:@selector(enabled)]) ? [btMgr enabled] : NO;
    BOOL btPowered = (btMgr && [btMgr respondsToSelector:@selector(powered)]) ? [btMgr powered] : NO;

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    UIDeviceBatteryState battState = [UIDevice currentDevice].batteryState;
    float battLevel = [UIDevice currentDevice].batteryLevel;
    if (!isfinite(battLevel)) battLevel = -1.0f;

    NSDictionary *dict = @{
        @"action": action ?: @"status",
        @"uiLocked": @(uiLocked),
        @"screenIsOn": @(screenOn),
        @"wifiEnabled": @(hwWifi),
        @"sbWifiEnabled": @(sbWifi),
        @"btEnabled": @(btEnabled),
        @"btPowered": @(btPowered),
        @"batteryState": @((int)battState),
        @"batteryLevel": @((int)roundf(battLevel * 100.0f)),
        @"timestamp": [[NSDate date] description]
    };
    BOOL ok = [dict writeToFile:@"/var/mobile/codex-car/sb-power-state.plist" atomically:YES];
    if (!ok) {
        [[dict description] writeToFile:@"/var/mobile/codex-car/sb-power-state.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

static void TRDApplySleepStep(void) {
    TRDInitSymbols();

    // 1. Pause media playback
    if (pMRMediaRemoteSendCommand) {
        pMRMediaRemoteSendCommand(1, nil); // kMRPause = 1
    }

    // 2. Turn OFF Wi-Fi (Hardware + SpringBoard + Flipswitch)
    if (gWiFiMgr && pWiFiManagerClientSetPower) {
        pWiFiManagerClientSetPower(gWiFiMgr, FALSE);
    }
    Class wifiCls = objc_getClass("SBWiFiManager");
    id wifiMgr = [wifiCls respondsToSelector:@selector(sharedInstance)] ? [wifiCls sharedInstance] : nil;
    if (wifiMgr && [wifiMgr respondsToSelector:@selector(setWiFiEnabled:)]) {
        [wifiMgr setWiFiEnabled:NO];
    }
    Class fspCls = objc_getClass("FSSwitchPanel");
    id fsp = [fspCls respondsToSelector:@selector(sharedPanel)] ? [fspCls sharedPanel] : nil;
    if (fsp && [fsp respondsToSelector:@selector(setState:forSwitchIdentifier:)]) {
        [fsp setState:0 forSwitchIdentifier:@"com.a3tweaks.switch.wifi"];
        [fsp setState:0 forSwitchIdentifier:@"com.a3tweaks.switch.bluetooth"];
        [fsp setState:1 forSwitchIdentifier:@"com.a3tweaks.switch.autolock"];
    }

    // 3. Turn OFF Bluetooth (BluetoothManager + Flipswitch)
    Class btCls = objc_getClass("BluetoothManager");
    TRDBluetoothManagerProxy *btMgr = [btCls respondsToSelector:@selector(sharedInstance)] ? (TRDBluetoothManagerProxy *)[btCls sharedInstance] : nil;
    if (btMgr) {
        if ([btMgr respondsToSelector:@selector(setPowered:)]) [btMgr setPowered:NO];
        if ([btMgr respondsToSelector:@selector(setEnabled:)]) [btMgr setEnabled:NO];
    }

    // 4. Lock UI and dim/blank screen via SpringBoard controllers
    Class lockCls = objc_getClass("SBLockScreenManager");
    id lockMgr = [lockCls respondsToSelector:@selector(sharedInstance)] ? [lockCls sharedInstance] : nil;
    if (lockMgr) {
        if ([lockMgr respondsToSelector:@selector(lockUIFromSource:withOptions:)]) {
            [lockMgr lockUIFromSource:1 withOptions:nil];
        } else if ([lockMgr respondsToSelector:@selector(_lockUI)]) {
            [lockMgr _lockUI];
        }
    }

    Class uaCls = objc_getClass("SBUserAgent");
    id ua = [uaCls respondsToSelector:@selector(sharedUserAgent)] ? [uaCls sharedUserAgent] : nil;
    if (ua) {
        if ([ua respondsToSelector:@selector(lockAndDimDeviceDisconnectingCallIfNecessary:andDimScreen:)]) {
            [ua lockAndDimDeviceDisconnectingCallIfNecessary:NO andDimScreen:YES];
        } else if ([ua respondsToSelector:@selector(lockAndDimDevice)]) {
            [ua lockAndDimDevice];
        }
    }

    Class blCls = objc_getClass("SBBacklightController");
    id blMgr = [blCls respondsToSelector:@selector(sharedInstance)] ? [blCls sharedInstance] : nil;
    if (blMgr) {
        if ([blMgr respondsToSelector:@selector(setBacklightFactor:source:)]) {
            [blMgr setBacklightFactor:0.0f source:1];
        }
    }

    if (pBKSDisplayServicesSetScreenBlanked) {
        pBKSDisplayServicesSetScreenBlanked(YES);
    }

    TRDWriteStatus(@"sleep");
}

static void TRDPerformSleep(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        int gen = ++gSleepGeneration;
        TRDApplySleepStep();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (gen != gSleepGeneration) return;
            UIDeviceBatteryState st = [UIDevice currentDevice].batteryState;
            if (st == UIDeviceBatteryStateCharging || st == UIDeviceBatteryStateFull) return;
            TRDApplySleepStep();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (gen != gSleepGeneration) return;
            TRDWriteStatus(@"sleep-verified");
        });
    });
}

static void TRDPerformWake(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        TRDInitSymbols();
        gSleepScheduled = NO;
        gSleepGeneration++;

        // 1. Unblank screen & restore backlight
        if (pBKSDisplayServicesSetScreenBlanked) {
            pBKSDisplayServicesSetScreenBlanked(NO);
        }
        Class blCls = objc_getClass("SBBacklightController");
        id blMgr = [blCls respondsToSelector:@selector(sharedInstance)] ? [blCls sharedInstance] : nil;
        if (blMgr) {
            if ([blMgr respondsToSelector:@selector(turnOnScreenFullyWithBacklightSource:)]) {
                [blMgr turnOnScreenFullyWithBacklightSource:1];
            }
            if ([blMgr respondsToSelector:@selector(setBacklightFactor:source:)]) {
                [blMgr setBacklightFactor:1.0f source:1];
            }
        }

        // 2. Unlock Lock Screen
        Class lockCls = objc_getClass("SBLockScreenManager");
        id lockMgr = [lockCls respondsToSelector:@selector(sharedInstance)] ? [lockCls sharedInstance] : nil;
        if (lockMgr && [lockMgr respondsToSelector:@selector(unlockUIFromSource:withOptions:)]) {
            [lockMgr unlockUIFromSource:1 withOptions:nil];
        }

        Class actCls = objc_getClass("LAActivator");
        Class evtCls = objc_getClass("LAEvent");
        id act = [actCls respondsToSelector:@selector(sharedInstance)] ? [actCls sharedInstance] : nil;
        if (act && evtCls && [act respondsToSelector:@selector(sendEvent:toListenerWithName:)]) {
            NSString *mode = [act respondsToSelector:@selector(currentEventMode)] ? [act currentEventMode] : @"lockscreen";
            id evt = [evtCls respondsToSelector:@selector(eventWithName:mode:)] ? [evtCls eventWithName:@"libactivator.power.connected" mode:mode] : nil;
            [act sendEvent:evt toListenerWithName:@"libactivator.lockscreen.dismiss"];
        }

        // 3. Turn ON Wi-Fi & Bluetooth, Disable Autolock
        if (gWiFiMgr && pWiFiManagerClientSetPower) {
            pWiFiManagerClientSetPower(gWiFiMgr, TRUE);
        }
        Class wifiCls = objc_getClass("SBWiFiManager");
        id wifiMgr = [wifiCls respondsToSelector:@selector(sharedInstance)] ? [wifiCls sharedInstance] : nil;
        if (wifiMgr && [wifiMgr respondsToSelector:@selector(setWiFiEnabled:)]) {
            [wifiMgr setWiFiEnabled:YES];
        }

        Class btCls = objc_getClass("BluetoothManager");
        TRDBluetoothManagerProxy *btMgr = [btCls respondsToSelector:@selector(sharedInstance)] ? (TRDBluetoothManagerProxy *)[btCls sharedInstance] : nil;
        if (btMgr) {
            if ([btMgr respondsToSelector:@selector(setPowered:)]) [btMgr setPowered:YES];
            if ([btMgr respondsToSelector:@selector(setEnabled:)]) [btMgr setEnabled:YES];
        }

        Class fspCls = objc_getClass("FSSwitchPanel");
        id fsp = [fspCls respondsToSelector:@selector(sharedPanel)] ? [fspCls sharedPanel] : nil;
        if (fsp && [fsp respondsToSelector:@selector(setState:forSwitchIdentifier:)]) {
            [fsp setState:0 forSwitchIdentifier:@"com.a3tweaks.switch.autolock"];
            [fsp setState:1 forSwitchIdentifier:@"com.a3tweaks.switch.wifi"];
            [fsp setState:1 forSwitchIdentifier:@"com.a3tweaks.switch.bluetooth"];
        }

        // 4. Launch CarDash and show welcome
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (act && evtCls && [act respondsToSelector:@selector(sendEvent:toListenerWithName:)]) {
                NSString *mode = [act respondsToSelector:@selector(currentEventMode)] ? [act currentEventMode] : @"springboard";
                id evt = [evtCls respondsToSelector:@selector(eventWithName:mode:)] ? [evtCls eventWithName:@"libactivator.power.connected" mode:mode] : nil;
                [act sendEvent:evt toListenerWithName:@"com.codex.cardash"];
            }
            Class wsCls = objc_getClass("LSApplicationWorkspace");
            if (wsCls && [wsCls respondsToSelector:@selector(defaultWorkspace)]) {
                id ws = [wsCls performSelector:@selector(defaultWorkspace)];
                if ([ws respondsToSelector:@selector(openApplicationWithBundleID:)]) {
                    [ws performSelector:@selector(openApplicationWithBundleID:) withObject:@"com.codex.cardash"];
                }
            }
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cardash://welcome"]];
            TRDWriteStatus(@"wake");
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (pBKSDisplayServicesSetScreenBlanked) pBKSDisplayServicesSetScreenBlanked(NO);
            if (blMgr && [blMgr respondsToSelector:@selector(setBacklightFactor:source:)]) {
                [blMgr setBacklightFactor:1.0f source:1];
            }
            if (lockMgr && [lockMgr respondsToSelector:@selector(unlockUIFromSource:withOptions:)]) {
                [lockMgr unlockUIFromSource:1 withOptions:nil];
            }
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cardash://welcome"]];
            TRDWriteStatus(@"wake-verified");
        });
    });
}

@interface TRDSBBatteryObserver : NSObject
+ (instancetype)shared;
- (void)batteryChanged:(NSNotification *)note;
@end

@implementation TRDSBBatteryObserver
+ (instancetype)shared {
    static TRDSBBatteryObserver *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[TRDSBBatteryObserver alloc] init];
    });
    return inst;
}
- (void)batteryChanged:(NSNotification *)note {
    UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
    if (state == UIDeviceBatteryStateUnplugged) {
        if (!gSleepScheduled) {
            gSleepScheduled = YES;
            int gen = ++gSleepGeneration;
            // Wait 12.5 seconds so CarDash Trip Summary (10.0s) displays AND brief engine crank voltage drops are ignored!
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (gen != gSleepGeneration) return;
                gSleepScheduled = NO;
                if ([UIDevice currentDevice].batteryState == UIDeviceBatteryStateUnplugged) {
                    TRDPerformSleep();
                } else {
                    TRDPerformWake();
                }
            });
        }
    } else if (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull) {
        gSleepScheduled = NO;
        gSleepGeneration++;
        TRDPerformWake();
    }
}
@end

__attribute__((constructor))
static void TRDSpringBoardPowerInit(void) {
    @autoreleasepool {
        NSString *procName = [[NSProcessInfo processInfo] processName];
        [@{@"proc": procName ?: @"nil", @"at": [[NSDate date] description]} writeToFile:@"/var/mobile/codex-car/sb-ctor-hit.plist" atomically:YES];
        if (![procName isEqualToString:@"SpringBoard"]) return;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            TRDInitSymbols();
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
            [[NSNotificationCenter defaultCenter] addObserver:[TRDSBBatteryObserver shared]
                                                     selector:@selector(batteryChanged:)
                                                         name:UIDeviceBatteryStateDidChangeNotification
                                                       object:nil];

            static int sleepToken = 0, wakeToken = 0, statusToken = 0;
            notify_register_dispatch("com.codex.trd.sleep", &sleepToken, dispatch_get_main_queue(), ^(int token) {
                TRDPerformSleep();
            });
            notify_register_dispatch("com.codex.trd.wake", &wakeToken, dispatch_get_main_queue(), ^(int token) {
                TRDPerformWake();
            });
            notify_register_dispatch("com.codex.trd.status", &statusToken, dispatch_get_main_queue(), ^(int token) {
                TRDWriteStatus(@"status");
            });

            TRDWriteStatus(@"loaded");

            // If power is connected when SpringBoard finishes launching, automatically wake & unlock into CarDash!
            UIDeviceBatteryState st = [UIDevice currentDevice].batteryState;
            if (st == UIDeviceBatteryStateCharging || st == UIDeviceBatteryStateFull) {
                TRDPerformWake();
            }
        });
    }
}
