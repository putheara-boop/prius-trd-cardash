//
// TRDOBDClient.m - CarDash OBD2 / CAN-Bus Integration Module for Toyota Prius TRD
//

#import "TRDOBDClient.h"

NSString * const TRDOBDDataDidUpdateNotification = @"TRDOBDDataDidUpdateNotification";
NSString * const TRDOBDConnectionStateChangedNotification = @"TRDOBDConnectionStateChangedNotification";
NSString * const TRDOBDGearChangedNotification = @"TRDOBDGearChangedNotification";

// Well-known BLE Serial Services used by vLinker MC+ and ELM327 BLE
static NSString * const kVgateServiceUUID_18F0  = @"18F0";
static NSString * const kVgateNotifyCharUUID    = @"2AF0";
static NSString * const kVgateWriteCharUUID     = @"2AF1";

static NSString * const kNordicUARTServiceUUID = @"6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
static NSString * const kNordicUARTTXCharUUID  = @"6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write
static NSString * const kNordicUARTRXCharUUID  = @"6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Notify

static NSString * const kSerialServiceUUID_FFE0 = @"FFE0";
static NSString * const kSerialCharUUID_FFE1    = @"FFE1";

static NSString * const kSerialServiceUUID_FFF0 = @"FFF0";
static NSString * const kSerialCharUUID_FFF1    = @"FFF1";
static NSString * const kSerialCharUUID_FFF2    = @"FFF2";

static NSString * const kTRDOBDDebugLogPath = @"/var/mobile/codex-car/obd-debug.log";
static NSString * const kTRDOBDPreviousDebugLogPath = @"/var/mobile/codex-car/obd-debug.prev.log";

@interface TRDOBDClient ()
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *activePeripheral;
@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;
@property (nonatomic, strong) CBCharacteristic *notifyCharacteristic;

@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, copy) NSString *connectionStatus;
@property (nonatomic, copy) NSString *connectedDeviceName;
@property (nonatomic, copy) NSString *lastScanSummary;
@property (nonatomic, assign) NSUInteger emptyBLEScanCount;
@property (nonatomic, strong) NSDate *lastEmptyBLEScanLogAt;

// Metrics
@property (nonatomic, assign) NSInteger engineRPM;
@property (nonatomic, assign) CGFloat coolantTempC;
@property (nonatomic, assign) CGFloat hybridBatterySOC;
@property (nonatomic, assign) CGFloat inverterTempC;
@property (nonatomic, assign) CGFloat auxBatteryVoltage;
@property (nonatomic, assign) CGFloat currentSpeedKmh;
@property (nonatomic, assign) CGFloat hvPackVoltage;
@property (nonatomic, assign) CGFloat hvPackCurrent;
@property (nonatomic, assign) CGFloat hvDeltaSOC;
@property (nonatomic, assign) CGFloat hvBatteryTempC;
@property (nonatomic, assign) CGFloat hvIntakeTempC;
@property (nonatomic, assign) NSInteger mg1RPM;
@property (nonatomic, assign) NSInteger mg2RPM;
@property (nonatomic, assign) CGFloat mg1TempC;
@property (nonatomic, assign) CGFloat mg2TempC;
@property (nonatomic, copy) NSArray<NSNumber *> *hvBlockVoltages;
@property (nonatomic, copy) NSArray<NSNumber *> *hvBlockResistances;
@property (nonatomic, assign) CGFloat hvBlockMinV;
@property (nonatomic, assign) CGFloat hvBlockMaxV;
@property (nonatomic, assign) BOOL parkSwitchEngaged;
@property (nonatomic, copy) NSString *lastShiftHex6141;
@property (nonatomic, copy) NSString *lastShiftHex6112;

@property (nonatomic, assign) CGFloat fuelLevelPercent;
@property (nonatomic, assign) CGFloat fuelRemainingLiters;
@property (nonatomic, assign) CGFloat fuelPricePerLiter;
@property (nonatomic, assign) CGFloat tripFuelUsedLiters;
@property (nonatomic, assign) CGFloat tripFuelCostTHB;
@property (nonatomic, assign) CGFloat tripAverageKmPerL;
@property (nonatomic, assign) CGFloat tripEVDistancePercent;

@property (nonatomic, copy) NSString *currentGear;
@property (nonatomic, assign) BOOL isReverseGear;
@property (nonatomic, assign) BOOL doorFrontLeftOpen;
@property (nonatomic, assign) BOOL doorFrontRightOpen;
@property (nonatomic, assign) BOOL doorRearLeftOpen;
@property (nonatomic, assign) BOOL doorRearRightOpen;
@property (nonatomic, assign) BOOL trunkOpen;
@property (nonatomic, assign) BOOL doorSensorsLive;
@property (nonatomic, assign) CGFloat cabinTempC;
@property (nonatomic, assign) CGFloat exteriorTempC;

@property (nonatomic, assign) BOOL brakeFluidNormal;
@property (nonatomic, assign) BOOL absSystemNormal;
@property (nonatomic, assign) CGFloat brakeAccumulatorPressureMPa;
@property (nonatomic, assign) CGFloat regenBrakingPowerKW;

@property (nonatomic, assign) NSInteger selectedFuelTypeIndex;
@property (nonatomic, copy) NSString *selectedFuelTypeName;
@property (nonatomic, copy) NSString *oilPriceSource;
@property (nonatomic, copy) NSString *oilPriceDate;
@property (nonatomic, assign) BOOL isLiveOilPriceActive;
@property (nonatomic, strong) NSDictionary *cachedPrices;

@property (nonatomic, strong) NSMutableString *rxBuffer;
@property (nonatomic, strong) NSMutableArray *commandQueue;
@property (nonatomic, strong) NSTimer *pollingTimer;
@property (nonatomic, assign) NSInteger pollIndex;
@property (nonatomic, strong) NSDate *lastFuelCalcTime;
@property (nonatomic, assign) double totalTripMeters;
@property (nonatomic, assign) double evTripMeters;
@property (nonatomic, assign) BOOL pendingScan;
@property (nonatomic, assign) BOOL obdInitialized;
@property (nonatomic, assign) NSInteger writePriority;
@property (nonatomic, assign) NSInteger notifyPriority;
@property (nonatomic, assign) NSInteger servicesPending;
@property (nonatomic, strong) NSMutableSet *seenPeripheralIDs;
@property (nonatomic, strong) NSMutableArray *seenDeviceSummaries;
@property (nonatomic, copy) NSString *activeCANHeader;
@property (nonatomic, assign) BOOL waitingForResponse;
@property (nonatomic, strong) NSDate *lastCmdSentAt;
@property (nonatomic, assign) NSUInteger rawLogCount;
@property (nonatomic, assign) NSUInteger scanGeneration;
@property (nonatomic, assign) NSUInteger connectGeneration;
@property (nonatomic, strong) NSDate *connectStartedAt;
@property (nonatomic, assign) NSInteger canMonitorPhase;
@property (nonatomic, assign) BOOL obdInitScheduled;
@property (nonatomic, assign) BOOL obdInitInProgress;
@property (nonatomic, assign) NSUInteger obdInitCommandIndex;
@property (nonatomic, assign) BOOL can127FrameCaptured;
@property (nonatomic, assign) BOOL can127AbortSent;
@property (nonatomic, copy) NSString *lastLoggedCAN127Gear;
@property (nonatomic, strong) NSDate *lastCAN127At;
@property (nonatomic, copy) NSString *canMonitorTargetID;
@property (nonatomic, copy) NSString *lastLoggedCAN620Hex;
@property (nonatomic, assign) NSUInteger can620Misses;
@property (nonatomic, strong) NSDate *lastCAN620At;
@property (nonatomic, strong) NSArray *activePollSchedule;
@property (nonatomic, assign) NSInteger fastCycleCount;
@property (nonatomic, assign) NSUInteger consecutiveTimeouts;
@property (nonatomic, assign) BOOL pollDispatchPending;
@property (nonatomic, assign) BOOL hasLive7C4CabinTemp;
@property (nonatomic, assign) CGFloat lastLoggedFuelLiters;
@property (nonatomic, assign) CGFloat lastLoggedCabinTempC;
@property (nonatomic, assign) CGFloat lastLoggedExteriorTempC;
@property (nonatomic, strong) NSMutableArray<NSString *> *pendingBodyCommands;
@property (nonatomic, assign, readwrite) BOOL autoDoorLockEnabled;
@property (nonatomic, assign, readwrite) BOOL autoDoorUnlockOnParkEnabled;
@property (nonatomic, assign, readwrite) BOOL autoDoorLockedForDrive;
@end

@implementation TRDOBDClient

+ (instancetype)sharedClient {
    static TRDOBDClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TRDOBDClient alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _connectionStatus = @"Initialized";
        _connectedDeviceName = @"";
        _lastScanSummary = @"Scan pending";
        _currentGear = @"P";
        _isReverseGear = NO;
        _engineRPM = 0;
        _coolantTempC = 0.0;
        _hybridBatterySOC = 0.0;
        _inverterTempC = 0.0;
        _auxBatteryVoltage = 12.6;
        _hvPackVoltage = 0.0;
        _hvPackCurrent = 0.0;
        _hvDeltaSOC = 0.0;
        _hvBatteryTempC = 0.0;
        _hvIntakeTempC = 0.0;
        _hvBlockVoltages = @[];
        _hvBlockResistances = @[];
        _parkSwitchEngaged = YES;
        _fuelLevelPercent = 50.0;
        _fuelRemainingLiters = 22.5; // 50% of 45L tank
        _cabinTempC = 25.0;
        _exteriorTempC = 32.0;
        _brakeFluidNormal = YES;
        _absSystemNormal = YES;
        _brakeAccumulatorPressureMPa = 18.5;
        _regenBrakingPowerKW = 0.0;
        _rxBuffer = [NSMutableString new];
        _commandQueue = [NSMutableArray new];
        _pendingBodyCommands = [NSMutableArray new];
        _seenPeripheralIDs = [NSMutableSet new];
        _seenDeviceSummaries = [NSMutableArray new];
        
        // Fuel type and pump price setup
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        _autoDoorLockEnabled = [prefs objectForKey:@"TRDAutoDoorLockEnabled"] ? [prefs boolForKey:@"TRDAutoDoorLockEnabled"] : NO;
        _autoDoorUnlockOnParkEnabled = [prefs objectForKey:@"TRDAutoDoorUnlockOnParkEnabled"] ? [prefs boolForKey:@"TRDAutoDoorUnlockOnParkEnabled"] : NO;
        _selectedFuelTypeIndex = [prefs integerForKey:@"TRDSelectedFuelTypeIndex"];
        if (_selectedFuelTypeIndex < 0 || _selectedFuelTypeIndex > 3) _selectedFuelTypeIndex = 0;
        
        NSArray *names = @[@"แก๊สโซฮอล์ 95", @"แก๊สโซฮอล์ 91", @"แก๊สโซฮอล์ E20", @"พรีเมียม 95"];
        _selectedFuelTypeName = names[_selectedFuelTypeIndex];
        _oilPriceSource = @"ปตท. (PTT Station)";
        _oilPriceDate = @"กำลังโหลดจากปั๊ม...";
        _cachedPrices = @{
            @(0): @(39.84),
            @(1): @(39.47),
            @(2): @(31.80),
            @(3): @(49.05)
        };
        
        double savedPrice = [prefs doubleForKey:@"TRDFuelPricePerLiter"];
        if (savedPrice < 10.0 || savedPrice > 100.0) {
            savedPrice = [_cachedPrices[@(_selectedFuelTypeIndex)] doubleValue];
            [prefs setDouble:savedPrice forKey:@"TRDFuelPricePerLiter"];
            [prefs synchronize];
        }
        _fuelPricePerLiter = (CGFloat)savedPrice;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self initBluetooth];
            [self fetchLiveOilPrices];
        });
    }
    return self;
}

- (void)obdLog:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"HH:mm:ss.SSS"];
    });
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [df stringFromDate:[NSDate date]], msg];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:kTRDOBDDebugLogPath error:nil];
    if (attrs && [attrs fileSize] > 48 * 1024) {
        // Keep one complete previous log. If rotation fails, append to the current
        // file instead of truncating it and losing the in-car capture.
        if (![fm fileExistsAtPath:kTRDOBDPreviousDebugLogPath] ||
            [fm removeItemAtPath:kTRDOBDPreviousDebugLogPath error:nil]) {
            [fm moveItemAtPath:kTRDOBDDebugLogPath toPath:kTRDOBDPreviousDebugLogPath error:nil];
        }
    }
    if (![fm fileExistsAtPath:kTRDOBDDebugLogPath]) {
        [line writeToFile:kTRDOBDDebugLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:kTRDOBDDebugLogPath];
        if (fh) {
            [fh seekToEndOfFile];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        }
    }
}

- (void)initBluetooth {
    if (!self.centralManager) {
        self.connectionStatus = @"Starting BLE Engine...";
        [self obdLog:@"initBluetooth: creating CBCentralManager"];
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
    }
}

- (NSArray<CBUUID *> *)knownOBDServiceCBUUIDs {
    return @[
        [CBUUID UUIDWithString:kVgateServiceUUID_18F0],
        [CBUUID UUIDWithString:kSerialServiceUUID_FFF0],
        [CBUUID UUIDWithString:kSerialServiceUUID_FFE0],
        [CBUUID UUIDWithString:kNordicUARTServiceUUID],
        [CBUUID UUIDWithString:@"E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"]
    ];
}

- (BOOL)isOBDPeripheralName:(NSString *)name {
    if (!name.length) return NO;
    return ([name rangeOfString:@"vLinker" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"Vgate" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"OBD" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"IOS-VLINK" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"V-LINK" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"MC+" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"ELM327" options:NSCaseInsensitiveSearch].location != NSNotFound);
}

- (void)resetConnectionStateWithStatus:(NSString *)status {
    self.obdInitInProgress = NO;
    self.obdInitCommandIndex = 0;
    self.lastCAN620At = nil;
    self.connectGeneration++;
    self.connectStartedAt = nil;
    self.isConnected = NO;
    self.obdInitialized = NO;
    self.obdInitScheduled = NO;
    self.waitingForResponse = NO;
    self.activeCANHeader = nil;
    self.canMonitorPhase = 0;
    self.can127FrameCaptured = NO;
    self.can127AbortSent = NO;
    self.pollDispatchPending = NO;
    self.fastCycleCount = 0;
    self.consecutiveTimeouts = 0;
    self.hasLive7C4CabinTemp = NO;
    self.activePollSchedule = nil;
    self.lastCAN127At = nil;
    self.lastLoggedCAN127Gear = nil;
    self.canMonitorTargetID = @"127";
    self.lastLoggedCAN620Hex = nil;
    self.can620Misses = 0;
    self.doorSensorsLive = NO;
    self.doorFrontLeftOpen = NO;
    self.doorFrontRightOpen = NO;
    self.doorRearLeftOpen = NO;
    self.doorRearRightOpen = NO;
    self.autoDoorLockedForDrive = NO;
    [self.pendingBodyCommands removeAllObjects];
    self.trunkOpen = NO;
    self.lastLoggedFuelLiters = -1.0;
    self.lastLoggedCabinTempC = -999.0;
    self.lastLoggedExteriorTempC = -999.0;
    self.activePeripheral = nil;
    self.writeCharacteristic = nil;
    self.notifyCharacteristic = nil;
    self.writePriority = 0;
    self.notifyPriority = 0;
    [self.rxBuffer setString:@""];
    if (self.pollingTimer) {
        [self.pollingTimer invalidate];
        self.pollingTimer = nil;
    }
    if (status) {
        self.connectionStatus = status;
    }
}

- (void)connectToOBDPeripheral:(CBPeripheral *)peripheral label:(NSString *)label {
    if (!peripheral || !self.centralManager || self.centralManager.state != CBCentralManagerStatePoweredOn) return;
    NSUInteger connGen = ++self.connectGeneration;
    self.connectStartedAt = [NSDate date];
    self.activePeripheral = peripheral;
    peripheral.delegate = self;
    self.connectedDeviceName = label.length ? label : @"vLinker MC-IOS";
    self.connectionStatus = [NSString stringWithFormat:@"Connecting %@...", self.connectedDeviceName];
    self.writePriority = 0;
    self.notifyPriority = 0;
    self.writeCharacteristic = nil;
    self.notifyCharacteristic = nil;
    self.isConnected = NO;
    self.obdInitialized = NO;
    self.obdInitScheduled = NO;
    self.waitingForResponse = NO;
    [self.rxBuffer setString:@""];
    [self.centralManager stopScan];
    [self.centralManager connectPeripheral:peripheral options:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (connGen == self.connectGeneration && self.activePeripheral == peripheral && !self.isConnected) {
            [self obdLog:@"BLE connect timeout (5s) for '%@'; cancelling & retrying", self.connectedDeviceName ?: @"?"];
            [self.centralManager cancelPeripheralConnection:peripheral];
            [self resetConnectionStateWithStatus:@"BLE Connect Timeout. Retrying..."];
            [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
            if (self.pendingScan && self.centralManager.state == CBCentralManagerStatePoweredOn) {
                [self beginBLEScan];
            }
        }
    });
}

- (void)beginBLEScan {
    if (!self.centralManager || self.centralManager.state != CBCentralManagerStatePoweredOn) return;
    if (self.isConnected || self.activePeripheral) return;
    [self.centralManager stopScan];
    [self.seenPeripheralIDs removeAllObjects];
    [self.seenDeviceSummaries removeAllObjects];
    self.scanGeneration++;
    NSUInteger gen = self.scanGeneration;

    NSArray *already = [self.centralManager retrieveConnectedPeripheralsWithServices:[self knownOBDServiceCBUUIDs]];
    BOOL unfiltered = (gen % 2 == 0);
    if (self.emptyBLEScanCount == 0 || already.count > 0) {
        [self obdLog:@"beginBLEScan gen=%lu mode=%@ state=%ld alreadyConnected=%lu",
         (unsigned long)gen, unfiltered ? @"all" : @"18F0", (long)self.centralManager.state, (unsigned long)already.count];
    }

    for (CBPeripheral *p in already) {
        if ([self isOBDPeripheralName:p.name]) {
            [self obdLog:@"ALREADY_CONNECTED BLE name='%@' id=%@", p.name ?: @"", p.identifier.UUIDString];
            [self connectToOBDPeripheral:p label:p.name];
            return;
        }
    }

    NSString *lastUUIDStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"TRDLastOBDPeripheralUUID"];
    if (lastUUIDStr.length) {
        NSUUID *lastUUID = [[NSUUID alloc] initWithUUIDString:lastUUIDStr];
        if (lastUUID) {
            NSArray *known = [self.centralManager retrievePeripheralsWithIdentifiers:@[lastUUID]];
            for (CBPeripheral *kp in known) {
                if (kp.state == CBPeripheralStateConnected && (!kp.name.length || [self isOBDPeripheralName:kp.name])) {
                    NSString *lbl = kp.name.length ? kp.name : @"vLinker MC-IOS";
                    [self obdLog:@"REMEMBERED_CONNECTED BLE name='%@' id=%@", kp.name ?: @"", lastUUIDStr];
                    [self connectToOBDPeripheral:kp label:lbl];
                    return;
                }
            }
        }
    }

    // Alternate explicit OBD service UUIDs (reliable on iOS 9.3.6 for 18F0) with unfiltered scan on even cycles.
    NSArray *scanServices = unfiltered ? nil : [self knownOBDServiceCBUUIDs];
    self.connectionStatus = unfiltered ? @"Auto-scanning all BLE..." : @"Auto-scanning vLinker MC+...";
    self.lastScanSummary = unfiltered ? @"Scanning BLE (all)..." : @"Scanning BLE (18F0)...";
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
    [self.centralManager scanForPeripheralsWithServices:scanServices options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (gen == self.scanGeneration && !self.isConnected && !self.activePeripheral) {
            if (self.seenDeviceSummaries.count == 0) {
                self.lastScanSummary = @"0 BLE devices seen";
                self.connectionStatus = @"No BLE OBD seen (auto-retrying...)";
            } else {
                self.lastScanSummary = [NSString stringWithFormat:@"Seen %lu BLE: %@", (unsigned long)self.seenDeviceSummaries.count, [self.seenDeviceSummaries componentsJoinedByString:@", "]];
                self.connectionStatus = [NSString stringWithFormat:@"Scanning (%lu BLE seen, no OBD)", (unsigned long)self.seenDeviceSummaries.count];
            }
            if (self.seenDeviceSummaries.count == 0) {
                self.emptyBLEScanCount++;
                NSDate *now = [NSDate date];
                // Log the first empty scan, then a heartbeat at most once a minute.
                if (!self.lastEmptyBLEScanLogAt || [now timeIntervalSinceDate:self.lastEmptyBLEScanLogAt] >= 60.0) {
                    self.lastEmptyBLEScanLogAt = now;
                    [self obdLog:@"Scan 5s summary gen=%lu: %@ (consecutive empty scans=%lu)",
                     (unsigned long)gen, self.lastScanSummary, (unsigned long)self.emptyBLEScanCount];
                }
            } else {
                self.emptyBLEScanCount = 0;
                self.lastEmptyBLEScanLogAt = nil;
                [self obdLog:@"Scan 5s summary gen=%lu: %@", (unsigned long)gen, self.lastScanSummary];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];

            if (self.pendingScan && self.centralManager.state == CBCentralManagerStatePoweredOn) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (gen == self.scanGeneration && self.pendingScan && !self.isConnected && !self.activePeripheral) {
                        [self beginBLEScan];
                    }
                });
            }
        }
    });
}

- (void)startScanning {
    self.pendingScan = YES;
    if (!self.centralManager) {
        [self initBluetooth];
        return;
    }
    if (self.isConnected && self.activePeripheral) {
        [self obdLog:@"startScanning ignored: already connected to %@", self.connectedDeviceName];
        return;
    }
    if (self.centralManager.state == CBCentralManagerStatePoweredOn) {
        [self beginBLEScan];
    } else {
        [self obdLog:@"startScanning deferred: CB state=%ld", (long)self.centralManager.state];
    }
}

- (void)ensureConnectedOrScan {
    self.pendingScan = YES;
    if (!self.centralManager) {
        [self initBluetooth];
        return;
    }
    if (self.isConnected && self.activePeripheral && self.writeCharacteristic && self.notifyCharacteristic) {
        return;
    }
    if (self.centralManager.state != CBCentralManagerStatePoweredOn) {
        [self obdLog:@"ensureConnectedOrScan deferred: CB state=%ld", (long)self.centralManager.state];
        return;
    }
    if (self.activePeripheral) {
        NSTimeInterval age = self.connectStartedAt ? [[NSDate date] timeIntervalSinceDate:self.connectStartedAt] : 99.0;
        if (!self.isConnected && age < 4.5) {
            return;
        }
        [self obdLog:@"ensureConnectedOrScan: resetting incomplete/stale connection (age=%.1fs)", age];
        [self forceReconnect];
        return;
    }
    [self obdLog:@"ensureConnectedOrScan: launching BLE auto-scan"];
    [self beginBLEScan];
}

- (void)forceReconnect {
    self.pendingScan = YES;
    if (!self.centralManager) {
        [self initBluetooth];
        return;
    }
    [self obdLog:@"forceReconnect triggered (connected=%d active=%@)", self.isConnected, self.connectedDeviceName ?: @"none"];
    CBPeripheral *prev = self.activePeripheral;
    self.scanGeneration++;
    [self.centralManager stopScan];
    [self resetConnectionStateWithStatus:@"Reconnecting OBD2..."];
    if (prev) {
        [self.centralManager cancelPeripheralConnection:prev];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
    if (self.centralManager.state == CBCentralManagerStatePoweredOn) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.pendingScan && !self.isConnected && !self.activePeripheral && self.centralManager.state == CBCentralManagerStatePoweredOn) {
                [self beginBLEScan];
            }
        });
    }
}

- (void)stopScanning {
    self.pendingScan = NO;
    if (self.centralManager && self.centralManager.isScanning) {
        [self.centralManager stopScan];
    }
    if (self.pollingTimer) {
        [self.pollingTimer invalidate];
        self.pollingTimer = nil;
    }
}

- (void)setCustomFuelPrice:(CGFloat)price {
    if (price < 10.0) price = 10.0;
    if (price > 120.0) price = 120.0;
    _fuelPricePerLiter = price;
    [[NSUserDefaults standardUserDefaults] setDouble:price forKey:@"TRDFuelPricePerLiter"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _tripFuelCostTHB = _tripFuelUsedLiters * _fuelPricePerLiter;
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
}

- (void)selectFuelTypeIndex:(NSInteger)index {
    if (index < 0 || index > 3) index = 0;
    _selectedFuelTypeIndex = index;
    NSArray *names = @[@"แก๊สโซฮอล์ 95", @"แก๊สโซฮอล์ 91", @"แก๊สโซฮอล์ E20", @"พรีเมียม 95"];
    _selectedFuelTypeName = names[index];
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"TRDSelectedFuelTypeIndex"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSNumber *p = self.cachedPrices[@(index)];
    if (p) {
        [self setCustomFuelPrice:[p doubleValue]];
    }
}

- (void)fetchLiveOilPrices {
    NSURL *url = [NSURL URLWithString:@"https://api.chnwt.dev/thai-oil-api/latest"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setTimeoutInterval:8.0];
    [req setValue:@"CarDash/1.6 (Prius TRD; iOS 9.3.6)" forHTTPHeaderField:@"User-Agent"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json && [json[@"status"] isEqualToString:@"success"]) {
                NSDictionary *resp = json[@"response"];
                NSDictionary *stations = resp[@"stations"];
                NSDictionary *ptt = stations[@"ptt"] ?: stations[@"bcp"];
                NSString *dateStr = resp[@"date"] ?: @"วันนี้";
                
                if (ptt) {
                    double g95 = [ptt[@"gasohol_95"][@"price"] doubleValue];
                    double g91 = [ptt[@"gasohol_91"][@"price"] doubleValue];
                    double e20 = [ptt[@"gasohol_e20"][@"price"] doubleValue];
                    double p95 = [ptt[@"superpower_gasohol_95"][@"price"] doubleValue] ?: [ptt[@"gasoline_95"][@"price"] doubleValue];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.cachedPrices = @{
                            @(0): @(g95 > 10.0 ? g95 : 39.84),
                            @(1): @(g91 > 10.0 ? g91 : 39.47),
                            @(2): @(e20 > 10.0 ? e20 : 31.80),
                            @(3): @(p95 > 10.0 ? p95 : 49.05)
                        };
                        self.oilPriceSource = @"ปตท. (PTT Station)";
                        self.oilPriceDate = dateStr;
                        self.isLiveOilPriceActive = YES;
                        
                        NSNumber *curP = self.cachedPrices[@(self.selectedFuelTypeIndex)];
                        if (curP) {
                            [self setCustomFuelPrice:[curP doubleValue]];
                        }
                    });
                }
            }
        }
    }] resume];
}

- (void)resetTripFuel {
    _tripFuelUsedLiters = 0.0;
    _tripFuelCostTHB = 0.0;
    _tripAverageKmPerL = 0.0;
    _tripEVDistancePercent = 0.0;
    _totalTripMeters = 0.0;
    _evTripMeters = 0.0;
    _lastFuelCalcTime = [NSDate date];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
}

- (void)toggleTestBrakeWarning {
    _brakeFluidNormal = !_brakeFluidNormal;
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
}

- (void)simulateHybridBatterySOC:(CGFloat)soc {
    _hybridBatterySOC = MAX(0.0, MIN(100.0, soc));
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
}

- (void)simulateGear:(NSString *)gear {
    if (!gear.length) return;
    NSString *oldGear = _currentGear;
    _currentGear = [gear copy];
    _isReverseGear = [_currentGear isEqualToString:@"R"];
    if (![oldGear isEqualToString:_currentGear]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDGearChangedNotification object:self userInfo:@{@"gear": _currentGear}];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
}

- (void)toggleTestReverseGear {
    if ([_currentGear isEqualToString:@"R"]) {
        [self simulateGear:@"P"];
    } else {
        [self simulateGear:@"R"];
    }
}

// Fallback estimator for when OBD is not yet connected physically (uses Prius 21.5 km/L baseline)
- (void)integrateFallbackFuelForDistanceKm:(double)distanceKm speedKmh:(double)kmh dtSeconds:(double)dt {
    if (self.isConnected) {
        // If connected to OBD2, real MAF/injector data handles this!
        return;
    }
    if (distanceKm <= 0.0) return;
    
    _totalTripMeters = distanceKm * 1000.0;
    
    // Prius averages ~21.5 km/L in city/highway mixed
    double avgKmL = 21.5;
    if (kmh > 0 && kmh <= 45.0) {
        // City / EV heavy driving
        avgKmL = 23.5;
        _evTripMeters += (kmh * (1000.0 / 3600.0)) * dt;
    } else if (kmh > 90.0) {
        // High speed highway
        avgKmL = 19.0;
    }
    
    _tripFuelUsedLiters = (CGFloat)(distanceKm / avgKmL);
    _tripFuelCostTHB = _tripFuelUsedLiters * _fuelPricePerLiter;
    _tripAverageKmPerL = (CGFloat)avgKmL;
    
    if (_totalTripMeters > 0) {
        _tripEVDistancePercent = (CGFloat)((_evTripMeters / _totalTripMeters) * 100.0);
        if (_tripEVDistancePercent > 100.0) _tripEVDistancePercent = 100.0;
    }
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    [self obdLog:@"centralManagerDidUpdateState: %ld", (long)central.state];
    if (central.state == CBCentralManagerStatePoweredOn) {
        if (!self.isConnected && self.activePeripheral) {
            [self obdLog:@"CB PoweredOn: clearing stale disconnected peripheral"];
            [self resetConnectionStateWithStatus:@"Bluetooth Ready. Auto-scanning..."];
        } else {
            self.connectionStatus = @"Bluetooth Ready. Auto-scanning...";
        }
        self.pendingScan = YES;
        [self startScanning];
    } else if (central.state == CBCentralManagerStatePoweredOff) {
        [self resetConnectionStateWithStatus:@"Bluetooth OFF"];
    } else if (central.state == CBCentralManagerStateUnauthorized) {
        [self resetConnectionStateWithStatus:@"Bluetooth Unauthorized"];
    } else if (central.state == CBCentralManagerStateUnsupported) {
        [self resetConnectionStateWithStatus:@"BLE Unsupported"];
    } else {
        [self resetConnectionStateWithStatus:@"Bluetooth Resetting..."];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    self.emptyBLEScanCount = 0;
    self.lastEmptyBLEScanLogAt = nil;
    NSString *name = peripheral.name ?: advertisementData[CBAdvertisementDataLocalNameKey] ?: @"";
    NSString *uuidStr = peripheral.identifier.UUIDString ?: @"unknown";
    NSArray *advUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey];
    NSMutableArray *svcStrings = [NSMutableArray array];
    BOOL hasOBDServiceUUID = NO;
    for (CBUUID *u in advUUIDs) {
        NSString *us = [[u UUIDString] uppercaseString];
        [svcStrings addObject:us];
        if ([us isEqualToString:@"18F0"] ||
            [us isEqualToString:@"FFF0"] ||
            [us isEqualToString:@"FFE0"] ||
            [us hasPrefix:@"6E400001"] ||
            [us hasPrefix:@"000018F0"] ||
            [us hasPrefix:@"0000FFF0"] ||
            [us hasPrefix:@"0000FFE0"]) {
            hasOBDServiceUUID = YES;
        }
    }

    if (![self.seenPeripheralIDs containsObject:uuidStr]) {
        [self.seenPeripheralIDs addObject:uuidStr];
        NSString *disp = name.length ? name : @"(noname)";
        NSString *entry = [NSString stringWithFormat:@"%@(%@dBm)", disp, RSSI ?: @0];
        if (self.seenDeviceSummaries.count < 8) {
            [self.seenDeviceSummaries addObject:entry];
        }
        self.lastScanSummary = [NSString stringWithFormat:@"Seen: %@", [self.seenDeviceSummaries componentsJoinedByString:@", "]];
        [self obdLog:@"BLE FOUND name='%@' rssi=%@ svcs=[%@] conn=%@ id=%@",
         disp, RSSI, [svcStrings componentsJoinedByString:@","],
         [advertisementData[CBAdvertisementDataIsConnectable] boolValue] ? @"Y" : @"N", uuidStr];
    }

    // Match vLinker MC+, Vgate, generic ELM327/OBD BLE names, or OBD GATT service UUIDs
    BOOL nameMatch = [self isOBDPeripheralName:name];

    if ((nameMatch || hasOBDServiceUUID) && !self.activePeripheral) {
        NSString *label = name.length ? name : @"vLinker MC-IOS";
        [self obdLog:@"BLE MATCH! Connecting to '%@' (nameMatch=%d uuidMatch=%d)", label, nameMatch, hasOBDServiceUUID];
        [self connectToOBDPeripheral:peripheral label:label];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if (peripheral != self.activePeripheral) return;
    NSUInteger connGen = self.connectGeneration;
    self.isConnected = YES;
    self.obdInitialized = NO;
    self.obdInitScheduled = NO;
    self.activeCANHeader = nil;
    self.waitingForResponse = NO;
    [self.rxBuffer setString:@""];
    NSString *label = peripheral.name.length ? peripheral.name : (self.connectedDeviceName.length ? self.connectedDeviceName : @"vLinker MC-IOS");
    self.connectedDeviceName = label;
    self.connectionStatus = [NSString stringWithFormat:@"Connected: %@", label];
    if (peripheral.identifier.UUIDString.length) {
        [[NSUserDefaults standardUserDefaults] setObject:peripheral.identifier.UUIDString forKey:@"TRDLastOBDPeripheralUUID"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [self obdLog:@"didConnectPeripheral: %@ (%@)", label, peripheral.identifier.UUIDString ?: @"?"];
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (connGen == self.connectGeneration && self.activePeripheral == peripheral && self.isConnected &&
            (!self.writeCharacteristic || !self.notifyCharacteristic || !self.notifyCharacteristic.isNotifying || (!self.obdInitInProgress && !self.obdInitialized))) {
            [self obdLog:@"GATT discovery timeout (6s) for '%@'; forcing reconnect", label];
            [self forceReconnect];
        }
    });
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (peripheral != self.activePeripheral) return;
    [self obdLog:@"didFailToConnectPeripheral: %@", error.localizedDescription ?: @"unknown"];
    [self resetConnectionStateWithStatus:@"BLE Connect Failed. Retrying..."];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
    NSUInteger connGen = self.connectGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (connGen == self.connectGeneration && self.pendingScan) {
            [self startScanning];
        }
    });
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (peripheral != self.activePeripheral) return;
    [self obdLog:@"didDisconnectPeripheral: err=%@", error.localizedDescription ?: @"none"];
    [self resetConnectionStateWithStatus:@"Disconnected. Auto-reconnecting..."];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
    NSUInteger connGen = self.connectGeneration;

    // Auto-reconnect promptly when OBD adapter sleeps or car restarts
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (connGen == self.connectGeneration && self.pendingScan) {
            [self startScanning];
        }
    });
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (peripheral != self.activePeripheral) return;
    if (error || peripheral.services.count == 0) {
        NSUInteger connGen = self.connectGeneration;
        [self obdLog:@"didDiscoverServices failed (count=%lu err=%@); scheduling reconnect",
         (unsigned long)peripheral.services.count, error.localizedDescription ?: @"none"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (connGen == self.connectGeneration && self.activePeripheral == peripheral && (!self.writeCharacteristic || !self.notifyCharacteristic)) {
                [self forceReconnect];
            }
        });
        return;
    }
    self.servicesPending = peripheral.services.count;
    [self obdLog:@"didDiscoverServices count=%lu", (unsigned long)peripheral.services.count];
    for (CBService *service in peripheral.services) {
        [self obdLog:@"  SVC %@", service.UUID.UUIDString];
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (peripheral != self.activePeripheral) return;
    if (self.servicesPending > 0) self.servicesPending--;
    if (error) {
        [self obdLog:@"didDiscoverCharacteristics error for %@: %@", service.UUID.UUIDString, error.localizedDescription];
    } else {
        NSString *svcUUID = [[service.UUID UUIDString] uppercaseString];
        for (CBCharacteristic *c in service.characteristics) {
            NSString *chUUID = [[c.UUID UUIDString] uppercaseString];
            [self obdLog:@"  CHAR svc=%@ ch=%@ props=0x%lx", svcUUID, chUUID, (unsigned long)c.properties];

            BOOL canWrite = ((c.properties & CBCharacteristicPropertyWrite) || (c.properties & CBCharacteristicPropertyWriteWithoutResponse));
            BOOL canNotify = ((c.properties & CBCharacteristicPropertyNotify) || (c.properties & CBCharacteristicPropertyIndicate));

            NSInteger wPrio = 0;
            NSInteger nPrio = 0;
            if ([svcUUID hasSuffix:@"18F0"] || [svcUUID isEqualToString:@"18F0"]) {
                if (canWrite && ([chUUID hasSuffix:@"2AF1"] || [chUUID isEqualToString:kVgateWriteCharUUID])) wPrio = 100;
                else if (canWrite) wPrio = 95;
                if (canNotify && ([chUUID hasSuffix:@"2AF0"] || [chUUID isEqualToString:kVgateNotifyCharUUID])) nPrio = 100;
                else if (canNotify) nPrio = 95;
            } else if ([svcUUID isEqualToString:[kNordicUARTServiceUUID uppercaseString]]) {
                if (canWrite && [chUUID isEqualToString:[kNordicUARTTXCharUUID uppercaseString]]) wPrio = 90;
                if (canNotify && [chUUID isEqualToString:[kNordicUARTRXCharUUID uppercaseString]]) nPrio = 90;
            } else if ([svcUUID hasSuffix:@"FFF0"] || [svcUUID isEqualToString:@"FFF0"]) {
                if (canWrite && ([chUUID hasSuffix:@"FFF2"] || [chUUID isEqualToString:kSerialCharUUID_FFF2])) wPrio = 85;
                else if (canWrite) wPrio = 80;
                if (canNotify && ([chUUID hasSuffix:@"FFF1"] || [chUUID isEqualToString:kSerialCharUUID_FFF1])) nPrio = 85;
                else if (canNotify) nPrio = 80;
            } else if ([svcUUID hasSuffix:@"FFE0"] || [svcUUID isEqualToString:@"FFE0"]) {
                if (canWrite && ([chUUID hasSuffix:@"FFE1"] || [chUUID isEqualToString:kSerialCharUUID_FFE1])) wPrio = 75;
                else if (canWrite) wPrio = 70;
                if (canNotify && ([chUUID hasSuffix:@"FFE1"] || [chUUID isEqualToString:kSerialCharUUID_FFE1])) nPrio = 75;
                else if (canNotify) nPrio = 70;
            } else if ([svcUUID isEqualToString:@"E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"]) {
                BOOL isSecondaryChar = [chUUID isEqualToString:@"BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F"];
                if (canWrite) wPrio = isSecondaryChar ? 60 : 55;
                if (canNotify) nPrio = isSecondaryChar ? 60 : 55;
            } else {
                if (canWrite) wPrio = 10;
                if (canNotify) nPrio = 10;
            }

            if (canWrite && wPrio > self.writePriority) {
                self.writePriority = wPrio;
                self.writeCharacteristic = c;
            }
            if (canNotify && nPrio > self.notifyPriority) {
                self.notifyPriority = nPrio;
                self.notifyCharacteristic = c;
            }
        }
    }

    // Wait until all services finish discovery so unrelated services don't race OBD init
    if (self.servicesPending == 0 && self.writeCharacteristic && self.notifyCharacteristic && !self.obdInitScheduled) {
        [self obdLog:@"Selected GATT write=%@ notify=%@ (prios w=%ld n=%ld)",
         self.writeCharacteristic.UUID.UUIDString, self.notifyCharacteristic.UUID.UUIDString,
         (long)self.writePriority, (long)self.notifyPriority];
        self.obdInitScheduled = YES;
        // Start only after CoreBluetooth confirms the selected RX subscription.
        [peripheral setNotifyValue:YES forCharacteristic:self.notifyCharacteristic];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (peripheral != self.activePeripheral || characteristic != self.notifyCharacteristic || !self.isConnected) return;
    if (error || !characteristic.isNotifying) {
        [self obdLog:@"OBD RX subscription failed: %@", error.localizedDescription ?: @"notifications disabled"];
        [self forceReconnect];
        return;
    }
    [self obdLog:@"didUpdateNotificationState ch=%@ isNotifying=1", characteristic.UUID.UUIDString];
    if (self.obdInitScheduled && !self.obdInitInProgress && !self.obdInitialized) {
        [self startOBDInitializationSequence];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (peripheral != self.activePeripheral) return;
    if (error) {
        [self obdLog:@"didWriteValue error for %@: %@", characteristic.UUID.UUIDString, error.localizedDescription];
    }
}

#pragma mark - OBD Protocol Communication

- (void)sendCommand:(NSString *)cmd {
    if (!self.writeCharacteristic || !self.activePeripheral || !self.isConnected) return;
    NSString *fullCmd = [cmd stringByAppendingString:@"\r"];
    NSData *data = [fullCmd dataUsingEncoding:NSASCIIStringEncoding];
    CBCharacteristicWriteType writeType = (self.writeCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) ? CBCharacteristicWriteWithoutResponse : CBCharacteristicWriteWithResponse;
    self.waitingForResponse = YES;
    self.lastCmdSentAt = [NSDate date];
    if (self.rawLogCount < 80) {
        [self obdLog:@"TX: %@", cmd];
    }
    [self.activePeripheral writeValue:data forCharacteristic:self.writeCharacteristic type:writeType];
}

- (void)sendRawMonitorAbort {
    if (!self.writeCharacteristic || !self.activePeripheral || !self.isConnected || self.can127AbortSent) return;
    self.can127AbortSent = YES;
    self.lastCmdSentAt = [NSDate date];
    NSData *data = [@"\r" dataUsingEncoding:NSASCIIStringEncoding];
    CBCharacteristicWriteType writeType = (self.writeCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) ? CBCharacteristicWriteWithoutResponse : CBCharacteristicWriteWithResponse;
    [self.activePeripheral writeValue:data forCharacteristic:self.writeCharacteristic type:writeType];
}

- (void)scheduleImmediatePoll {
    if (self.pollDispatchPending || !self.isConnected || !self.obdInitialized) return;
    self.pollDispatchPending = YES;
    NSUInteger connGen = self.connectGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(45 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if (connGen != self.connectGeneration) return;
        self.pollDispatchPending = NO;
        if (self.isConnected && self.obdInitialized && !self.waitingForResponse) {
            [self pollNextOBD];
        }
    });
}

- (void)startOBDInitializationSequence {
    if (!self.isConnected || !self.writeCharacteristic || !self.notifyCharacteristic.isNotifying ||
        self.obdInitInProgress || self.obdInitialized) return;
    self.connectionStatus = @"Configuring CAN-Bus...";
    [self.rxBuffer setString:@""];
    self.obdInitialized = NO;
    self.pollIndex = 0;
    self.activeCANHeader = nil;
    self.rawLogCount = 0;
    self.canMonitorPhase = 0;
    self.can127FrameCaptured = NO;
    self.can127AbortSent = NO;
    self.pollDispatchPending = NO;
    self.fastCycleCount = 0;
    self.consecutiveTimeouts = 0;
    self.hasLive7C4CabinTemp = NO;
    self.activePollSchedule = nil;
    self.lastCAN127At = nil;
    self.lastLoggedCAN127Gear = nil;
    self.canMonitorTargetID = @"127";
    self.lastLoggedCAN620Hex = nil;
    self.can620Misses = 0;
    self.doorSensorsLive = NO;
    self.doorFrontLeftOpen = NO;
    self.doorFrontRightOpen = NO;
    self.doorRearLeftOpen = NO;
    self.doorRearRightOpen = NO;
    self.autoDoorLockedForDrive = NO;
    [self.pendingBodyCommands removeAllObjects];
    self.trunkOpen = NO;
    self.lastLoggedFuelLiters = -1.0;
    self.lastLoggedCabinTempC = -999.0;
    self.lastLoggedExteriorTempC = -999.0;
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];

    self.obdInitInProgress = YES;
    self.obdInitCommandIndex = 0;
    self.lastCAN620At = nil;
    if (self.pollingTimer) [self.pollingTimer invalidate];
    // The same watchdog covers initialization and normal polling.
    self.pollingTimer = [NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(pollNextOBD) userInfo:nil repeats:YES];
    [self sendCommand:@"ATZ"];
}

- (NSArray *)obdInitializationCommands {
    return @[@"ATZ", @"ATE0", @"ATL0", @"ATS0", @"ATH0", @"ATSP6"];
}

- (void)handleOBDInitializationFrame:(NSString *)frame {
    if (!self.obdInitInProgress || self.obdInitCommandIndex >= [self obdInitializationCommands].count) return;
    NSString *upper = [frame uppercaseString];
    NSArray *lines = [upper componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    BOOL ok = NO;
    for (NSString *line in lines) {
        if ([[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@"OK"]) ok = YES;
    }
    if (self.obdInitCommandIndex == 0) {
        // A reset must return an adapter identification, not just an echoed ATZ.
        ok = ([upper rangeOfString:@"ELM"].location != NSNotFound ||
              [upper rangeOfString:@"STN"].location != NSNotFound ||
              [upper rangeOfString:@"VLINK"].location != NSNotFound ||
              [upper rangeOfString:@"OBDLINK"].location != NSNotFound);
    }
    if ([upper rangeOfString:@"?"].location != NSNotFound ||
        [upper rangeOfString:@"ERROR"].location != NSNotFound) ok = NO;
    NSString *command = [self obdInitializationCommands][self.obdInitCommandIndex];
    if (!ok) {
        [self obdLog:@"OBD init rejected %@ response: %@", command,
         [upper stringByReplacingOccurrencesOfString:@"\r" withString:@"|"]];
        [self forceReconnect];
        return;
    }

    [self obdLog:@"OBD init ACK: %@", command];
    BOOL wasReset = (self.obdInitCommandIndex == 0);
    self.obdInitCommandIndex++;
    if (self.obdInitCommandIndex == [self obdInitializationCommands].count) {
        self.obdInitInProgress = NO;
        self.obdInitialized = YES;
        self.activeCANHeader = @"7DF";
        self.connectionStatus = @"OBD adapter ready; polling Prius CAN";
        [self obdLog:@"OBD init complete; all setup commands acknowledged; starting Prius CAN polling"];
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
        [self scheduleImmediatePoll];
        return;
    }

    // Preserve the adapter reset settling time, but never overlap commands.
    NSTimeInterval age = self.lastCmdSentAt ? [[NSDate date] timeIntervalSinceDate:self.lastCmdSentAt] : 0.0;
    NSTimeInterval delay = wasReset ? MAX(0.0, 1.2 - age) : 0.0;
    NSUInteger connGen = self.connectGeneration;
    NSUInteger nextIndex = self.obdInitCommandIndex;
    CBPeripheral *peripheral = self.activePeripheral;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (connGen != self.connectGeneration || peripheral != self.activePeripheral ||
            !self.isConnected || !self.obdInitInProgress || self.obdInitCommandIndex != nextIndex) return;
        [self sendCommand:[self obdInitializationCommands][nextIndex]];
    });
}

- (void)finishCANMonitorSnapshot {
    if ([self.canMonitorTargetID isEqualToString:@"620"] && !self.can127FrameCaptured) {
        self.can620Misses++;
        [self obdLog:@"CAN 0x620 snapshot empty (%lu/4)%@", (unsigned long)self.can620Misses,
         self.can620Misses >= 4 ? @"; pausing door monitor until reconnect" : @""];
    }
}

- (void)expireDoorDataIfNeeded {
    if (self.doorSensorsLive && (!self.lastCAN620At || [[NSDate date] timeIntervalSinceDate:self.lastCAN620At] >= 30.0)) {
        self.doorSensorsLive = NO;
        [self obdLog:@"CAN 0x620 stale; door status unavailable"];
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
    }
}

// Prius ZVW30 CAN-Bus poll sequence grouped by ECU header (7DF -> 7E2 -> 7C0) + live CAN 0x127 gear
- (void)pollNextOBD {
    [self expireDoorDataIfNeeded];
    if (!self.isConnected || !self.writeCharacteristic) return;

    NSTimeInterval elapsed = self.lastCmdSentAt ? [[NSDate date] timeIntervalSinceDate:self.lastCmdSentAt] : 0.0;
    if (self.obdInitInProgress) {
        if (self.waitingForResponse && elapsed >= 3.0) {
            [self obdLog:@"OBD init timeout waiting for %@", [self obdInitializationCommands][self.obdInitCommandIndex]];
            [self forceReconnect];
        }
        return;
    }
    if (!self.obdInitialized) return;
    if (self.waitingForResponse) {
        if (self.canMonitorPhase == 4) {
            if (!self.can127AbortSent && elapsed >= 0.35) {
                [self sendRawMonitorAbort];
                return;
            }
            if (elapsed < 0.90) return;
            NSString *monID = self.canMonitorTargetID ?: @"127";
            [self obdLog:@"CAN 0x%@ monitor timeout; restoring normal ELM state", monID];
            [self finishCANMonitorSnapshot];
            [self.rxBuffer setString:@""];
            self.waitingForResponse = NO;
            self.canMonitorPhase = 5;
        } else {
            if (elapsed < 0.95) return;
            self.consecutiveTimeouts++;
            [self obdLog:@"OBD timeout #%lu (phase=%ld hdr=%@); recovering",
             (unsigned long)self.consecutiveTimeouts, (long)self.canMonitorPhase, self.activeCANHeader ?: @"?"];
            self.waitingForResponse = NO;
            if (self.canMonitorPhase > 0 && self.canMonitorPhase < 5) {
                self.canMonitorPhase = 5;
            } else if (self.consecutiveTimeouts >= 8) {
                [self obdLog:@"OBD deadman (%lu timeouts); forcing BLE reconnect", (unsigned long)self.consecutiveTimeouts];
                [self forceReconnect];
                return;
            } else if (self.consecutiveTimeouts >= 5) {
                self.canMonitorPhase = 5;
                self.activeCANHeader = nil;
            }
        }
    }

    // Priority one-shot Body ECU commands (e.g. Prius 0x750 door lock/unlock)
    if (self.canMonitorPhase == 0 && self.pendingBodyCommands.count > 0) {
        NSString *bodyCmd = self.pendingBodyCommands.firstObject;
        [self.pendingBodyCommands removeObjectAtIndex:0];
        if ([bodyCmd hasPrefix:@"ATSH "]) {
            self.activeCANHeader = [bodyCmd substringFromIndex:5];
        }
        [self sendCommand:bodyCmd];
        return;
    }

    // CAN 0x127 (GEAR_PACKET) / 0x620 (SEATS_DOORS) passive snapshot sequence at end of cycle
    if (self.canMonitorPhase > 0) {
        switch (self.canMonitorPhase) {
            case 1: [self sendCommand:@"AT CAF0"]; return;
            case 2: [self sendCommand:@"AT H1"]; return;
            case 3: [self sendCommand:[NSString stringWithFormat:@"AT CRA %@", self.canMonitorTargetID ?: @"127"]]; return;
            case 4:
                self.can127FrameCaptured = NO;
                self.can127AbortSent = NO;
                [self sendCommand:@"AT MA"];
                return;
            case 5: [self sendCommand:@"AT CAF1"]; return;
            case 6: [self sendCommand:@"AT AR"]; return;
            case 7: [self sendCommand:@"AT H0"]; return;
            default: self.canMonitorPhase = 0; break;
        }
    }

    static NSArray *fastSchedule = nil;
    static NSArray *fullSchedule = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fastSchedule = @[
            @{@"hdr": @"7DF", @"cmd": @"010C"}, // Engine RPM
            @{@"hdr": @"7DF", @"cmd": @"010D"}, // Vehicle Speed
            @{@"hdr": @"7DF", @"cmd": @"0110"}, // MAF
            @{@"hdr": @"7E2", @"cmd": @"2101"}, // HV Battery SOC + Thermals
            @{@"hdr": @"7E2", @"cmd": @"2162"}, // MG2 Temp & RPM
            @{@"hdr": @"7E2", @"cmd": @"218A"}, // HV Pack Current
            @{@"hdr": @"7C0", @"cmd": @"2129"}, // Fuel Tank Level (0.5 L/bit)
        ];
        fullSchedule = @[
            @{@"hdr": @"7DF", @"cmd": @"010C"}, // Engine RPM
            @{@"hdr": @"7DF", @"cmd": @"010D"}, // Vehicle Speed
            @{@"hdr": @"7DF", @"cmd": @"0110"}, // MAF
            @{@"hdr": @"7DF", @"cmd": @"0105"}, // Coolant Temp
            @{@"hdr": @"7DF", @"cmd": @"0142"}, // 12V Aux Voltage
            @{@"hdr": @"7E2", @"cmd": @"2101"}, // HV Battery SOC + Thermals
            @{@"hdr": @"7E2", @"cmd": @"2141"}, // Shift Sensor Voltages / Fallback
            @{@"hdr": @"7E2", @"cmd": @"2161"}, // MG1 Temp & RPM
            @{@"hdr": @"7E2", @"cmd": @"2162"}, // MG2 Temp & RPM
            @{@"hdr": @"7E2", @"cmd": @"2171"}, // Inverter MG2 Temp
            @{@"hdr": @"7E2", @"cmd": @"218A"}, // HV Pack Current
            @{@"hdr": @"7E2", @"cmd": @"2187"}, // HV Battery Temps
            @{@"hdr": @"7E2", @"cmd": @"2181"}, // 14 Blocks + Total Pack Voltage
            @{@"hdr": @"7E2", @"cmd": @"2198"}, // Delta SOC
            @{@"hdr": @"7C0", @"cmd": @"2129"}, // Fuel Tank Level (0.5 L/bit)
            @{@"hdr": @"7C0", @"cmd": @"2112"}, // Meter Cluster Indicators
            @{@"hdr": @"7C4", @"cmd": @"2121"}, // A/C Cabin Room Temp Sensor
            @{@"hdr": @"7C4", @"cmd": @"2122"}, // Exterior Ambient Temp Sensor
        ];
    });

    if (!self.activePollSchedule || self.pollIndex >= (NSInteger)self.activePollSchedule.count) {
        if (self.activePollSchedule && self.pollIndex >= (NSInteger)self.activePollSchedule.count) {
            self.pollIndex = 0;
            self.fastCycleCount++;
            self.activePollSchedule = nil;
            self.canMonitorTargetID = (self.fastCycleCount % 3 == 0 && self.can620Misses < 4) ? @"620" : @"127";
            self.canMonitorPhase = 1;
            [self sendCommand:@"AT CAF0"];
            return;
        }
        self.pollIndex = 0;
        self.activePollSchedule = (self.fastCycleCount % 3 == 0) ? fullSchedule : fastSchedule;
    }

    NSDictionary *step = self.activePollSchedule[self.pollIndex];
    NSString *targetHdr = step[@"hdr"];
    NSString *cmd = step[@"cmd"];

    if (![self.activeCANHeader isEqualToString:targetHdr]) {
        self.activeCANHeader = targetHdr;
        [self sendCommand:[NSString stringWithFormat:@"ATSH %@", targetHdr]];
        return;
    }

    self.pollIndex++;
    [self sendCommand:cmd];
}

- (BOOL)parseCANFrameLine:(NSString *)line expectedPrefix:(NSString *)prefix outBytes:(uint8_t *)raw {
    if (![line hasPrefix:prefix] || line.length != 19) return NO;
    NSString *hex = [line substringFromIndex:prefix.length];
    for (int i = 0; i < 8; i++) {
        unichar c0 = [hex characterAtIndex:i * 2];
        unichar c1 = [hex characterAtIndex:i * 2 + 1];
        BOOL ok0 = ((c0 >= '0' && c0 <= '9') || (c0 >= 'A' && c0 <= 'F'));
        BOOL ok1 = ((c1 >= '0' && c1 <= '9') || (c1 >= 'A' && c1 <= 'F'));
        if (!ok0 || !ok1) return NO;
        unsigned int val = 0;
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(i * 2, 2)]] scanHexInt:&val];
        raw[i] = (uint8_t)val;
    }
    return YES;
}

- (BOOL)parseCAN127Line:(NSString *)line {
    uint8_t raw[8];
    if (![self parseCANFrameLine:line expectedPrefix:@"127" outBytes:raw]) return NO;
    // Toyota CAN checksum = (CAN_ID_H + CAN_ID_L + DLC + sum(b[0..6])) & 0xFF
    uint8_t sum = (uint8_t)(0x01 + 0x27 + 0x08);
    for (int i = 0; i < 7; i++) {
        sum = (uint8_t)(sum + raw[i]);
    }
    if (sum != raw[7]) return NO;

    self.lastCAN127At = [NSDate date];
    uint8_t gearNib = (raw[5] >> 4) & 0x0F;
    NSString *gear = nil;
    switch (gearNib) {
        case 0: gear = @"P"; break;
        case 1: gear = @"R"; break;
        case 2: gear = @"N"; break;
        case 3: gear = @"D"; break;
        case 4: gear = @"B"; break;
        default: break;
    }

    NSString *gearLogKey = gear ?: [NSString stringWithFormat:@"?0x%X", gearNib];
    if (![self.lastLoggedCAN127Gear isEqualToString:gearLogKey]) {
        self.lastLoggedCAN127Gear = gearLogKey;
        [self obdLog:@"CAN_127 -> %@ (raw=%@ nib=0x%X b3=0x%02X b5=0x%02X)",
         gear ?: @"?", line, gearNib, raw[3], raw[5]];
    }

    if (gear.length) {
        self.parkSwitchEngaged = [gear isEqualToString:@"P"];
        [self updateLiveGear:gear fromCAN127:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
    }
    return YES;
}

- (BOOL)parseCAN620Line:(NSString *)line {
    uint8_t raw[8];
    if (![self parseCANFrameLine:line expectedPrefix:@"620" outBytes:raw]) return NO;

    // Toyota ZVW30 BO_ 1568 (0x620) SEATS_DOORS: b[5] bits 5..2 = FL/FR/RR/RL
    BOOL fl = (raw[5] & 0x20) != 0;
    BOOL fr = (raw[5] & 0x10) != 0;
    BOOL rr = (raw[5] & 0x08) != 0;
    BOOL rl = (raw[5] & 0x04) != 0;
    BOOL trunk = (raw[5] & 0x02) != 0;
    self.can620Misses = 0;
    self.lastCAN620At = [NSDate date];

    if (!self.lastLoggedCAN620Hex || ![self.lastLoggedCAN620Hex isEqualToString:line]) {
        self.lastLoggedCAN620Hex = line;
        [self obdLog:@"CAN_620 -> FL=%d FR=%d RL=%d RR=%d T?=%d b5=0x%02X raw=%@",
         fl ? 1 : 0, fr ? 1 : 0, rl ? 1 : 0, rr ? 1 : 0, trunk ? 1 : 0, raw[5], line];
    }

    BOOL changed = (!self.doorSensorsLive ||
                    fl != self.doorFrontLeftOpen || fr != self.doorFrontRightOpen ||
                    rl != self.doorRearLeftOpen || rr != self.doorRearRightOpen ||
                    trunk != self.trunkOpen);
    self.doorSensorsLive = YES;
    self.doorFrontLeftOpen = fl;
    self.doorFrontRightOpen = fr;
    self.doorRearLeftOpen = rl;
    self.doorRearRightOpen = rr;
    self.trunkOpen = trunk;
    if (changed) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
    }
    return YES;
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (peripheral != self.activePeripheral || characteristic != self.notifyCharacteristic || !self.isConnected) return;
    if (error || !characteristic.value) return;
    NSString *chunk = [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
    if (!chunk.length) return;

    [self.rxBuffer appendString:chunk];
    if (self.rxBuffer.length > 2048) {
        [self obdLog:@"OBD RX buffer overflow; reconnecting to restore command synchronization"];
        [self forceReconnect];
        return;
    }

    // While AT MA is streaming CAN 0x127 / 0x620, catch first complete frame and abort cleanly
    if (self.canMonitorPhase == 4 && !self.can127FrameCaptured) {
        NSArray *parts = [self.rxBuffer componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
        BOOL target620 = [self.canMonitorTargetID isEqualToString:@"620"];
        for (NSUInteger i = 0; i + 1 < parts.count; i++) {
            NSString *candidate = [[parts[i] stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
            BOOL matched = target620 ? [self parseCAN620Line:candidate] : [self parseCAN127Line:candidate];
            if (matched) {
                self.can127FrameCaptured = YES;
                if ([self.rxBuffer rangeOfString:@"STOPPED"].location == NSNotFound &&
                    [self.rxBuffer rangeOfString:@">"].location == NSNotFound) {
                    [self sendRawMonitorAbort];
                }
                break;
            }
        }
    }

    // ELM327 / STN marks end of full frame with '>'
    NSRange promptRange = [self.rxBuffer rangeOfString:@">"];
    while (promptRange.location != NSNotFound) {
        NSString *frame = [self.rxBuffer substringToIndex:promptRange.location];
        [self.rxBuffer deleteCharactersInRange:NSMakeRange(0, promptRange.location + 1)];
        BOOL wasWaiting = self.waitingForResponse;
        self.waitingForResponse = NO;
        self.consecutiveTimeouts = 0;

        if (self.rawLogCount < 80) {
            self.rawLogCount++;
            NSString *compact = [[frame stringByReplacingOccurrencesOfString:@"\r" withString:@"|"] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            [self obdLog:@"RX[%lu]: %@", (unsigned long)self.rawLogCount, compact];
        }

        if (self.obdInitInProgress) {
            // Ignore duplicate/unsolicited prompts while reset settling is pending.
            if (wasWaiting) [self handleOBDInitializationFrame:frame];
            if (!self.isConnected) return;
            promptRange = [self.rxBuffer rangeOfString:@">"];
            continue;
        }

        if (self.canMonitorPhase > 0) {
            if (self.canMonitorPhase == 4) [self finishCANMonitorSnapshot];
            if (self.canMonitorPhase >= 7) {
                self.canMonitorPhase = 0;
                self.activeCANHeader = nil;
            } else {
                self.canMonitorPhase++;
            }
            promptRange = [self.rxBuffer rangeOfString:@">"];
            continue;
        }

        NSArray *rawLines = [frame componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
        NSMutableString *multiFrameHex = [NSMutableString string];
        for (NSString *rawLine in rawLines) {
            NSString *line = [[rawLine stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
            if (!line.length) continue;
            if ([line isEqualToString:@"OK"] || [line hasPrefix:@"SEARCHING"] || [line hasPrefix:@"NODATA"] ||
                [line hasPrefix:@"STOPPED"] || [line hasPrefix:@"AT"] || [line hasPrefix:@"ELM"] ||
                [line hasPrefix:@"STN"] || [line isEqualToString:@"?"] || [line rangeOfString:@"ERROR"].location != NSNotFound) {
                continue;
            }
            // Handle ISO-TP multi-frame sequence prefix e.g. "0:6101..." / "1:..."
            NSRange colon = [line rangeOfString:@":"];
            if (colon.location == 1 && colon.location + 1 < line.length) {
                [multiFrameHex appendString:[line substringFromIndex:2]];
                continue;
            }
            // Skip pure 3-hex ISO-TP length line (e.g. "01E")
            if (line.length == 3) continue;
            [self parseOBDResponse:line];
        }
        if (multiFrameHex.length >= 4) {
            [self parseOBDResponse:multiFrameHex];
        }

        promptRange = [self.rxBuffer rangeOfString:@">"];
    }

    if (!self.waitingForResponse && self.obdInitialized) {
        [self scheduleImmediatePoll];
    }
}

#pragma mark - Parser Engine

- (NSArray<NSNumber *> *)bytesFromHex:(NSString *)hex afterPrefix:(NSString *)prefix minBytes:(NSUInteger)minBytes {
    if (![hex hasPrefix:prefix]) return nil;
    NSString *payload = [hex substringFromIndex:prefix.length];
    NSUInteger count = payload.length / 2;
    if (count < minBytes) return nil;
    NSMutableArray<NSNumber *> *bytes = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        unsigned int val = 0;
        [[NSScanner scannerWithString:[payload substringWithRange:NSMakeRange(i * 2, 2)]] scanHexInt:&val];
        [bytes addObject:@(val)];
    }
    return bytes;
}

- (void)updateLiveGear:(NSString *)gear {
    [self updateLiveGear:gear fromCAN127:NO];
}

- (void)updateLiveGear:(NSString *)gear fromCAN127:(BOOL)fromCAN127 {
    if (!gear.length) return;
    static NSString *pendingGear = nil;
    static NSInteger pendingHits = 0;
    static CFAbsoluteTime pendingFirstAt = 0;
    if ([_currentGear isEqualToString:gear]) {
        pendingGear = nil;
        pendingHits = 0;
        return;
    }
    // Checksum-verified CAN 0x127 frames are authoritative; apply immediately without 2-cycle lag.
    if (fromCAN127 || !_currentGear.length || [_currentGear isEqualToString:@"--"]) {
        pendingGear = nil;
        pendingHits = 0;
    } else {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (![pendingGear isEqualToString:gear]) {
            pendingGear = [gear copy];
            pendingHits = 1;
            pendingFirstAt = now;
            return;
        }
        pendingHits++;
        if (pendingHits < 2 || (now - pendingFirstAt) < 0.20) {
            return;
        }
        pendingGear = nil;
        pendingHits = 0;
    }
    _currentGear = [gear copy];
    _isReverseGear = [_currentGear isEqualToString:@"R"];
    [self obdLog:@"LIVE GEAR -> %@", _currentGear];
    [self evaluateAutoDoorLockForSpeed:self.currentSpeedKmh];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDGearChangedNotification object:self userInfo:@{@"gear": _currentGear}];
}

- (void)parseOBDResponse:(NSString *)hex {
    if (hex.length < 4) return;
    NSArray<NSNumber *> *b = nil;

    // 010C: Engine RPM -> (A*256 + B)/4
    if ((b = [self bytesFromHex:hex afterPrefix:@"410C" minBytes:2])) {
        self.engineRPM = (NSInteger)((([b[0] unsignedIntValue] * 256) + [b[1] unsignedIntValue]) / 4);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 010D: Vehicle Speed km/h -> A
    if ((b = [self bytesFromHex:hex afterPrefix:@"410D" minBytes:1])) {
        self.currentSpeedKmh = (CGFloat)[b[0] unsignedIntValue];
        [self evaluateAutoDoorLockForSpeed:self.currentSpeedKmh];
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 0105: Coolant Temp -> A - 40
    if ((b = [self bytesFromHex:hex afterPrefix:@"4105" minBytes:1])) {
        self.coolantTempC = (CGFloat)((int)[b[0] unsignedIntValue] - 40);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 0110: MAF -> (A*256 + B)/100 g/s
    if ((b = [self bytesFromHex:hex afterPrefix:@"4110" minBytes:2])) {
        double mafGps = (([b[0] unsignedIntValue] * 256.0) + [b[1] unsignedIntValue]) / 100.0;
        NSDate *now = [NSDate date];
        if (self.lastFuelCalcTime) {
            NSTimeInterval dt = [now timeIntervalSinceDate:self.lastFuelCalcTime];
            if (dt > 0.0 && dt < 5.0) {
                double lps = (mafGps / 14.7) / 740.0;
                self.tripFuelUsedLiters += (CGFloat)(lps * dt);
                self.tripFuelCostTHB = self.tripFuelUsedLiters * self.fuelPricePerLiter;
            }
        }
        self.lastFuelCalcTime = now;
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 0142: Control Module 12V Voltage -> (A*256 + B)/1000
    if ((b = [self bytesFromHex:hex afterPrefix:@"4142" minBytes:2])) {
        self.auxBatteryVoltage = (CGFloat)((([b[0] unsignedIntValue] * 256.0) + [b[1] unsignedIntValue]) / 1000.0);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 7C0 2129: Combination Meter Fuel Level -> A / 2.0 Liters (45L tank)
    if ((b = [self bytesFromHex:hex afterPrefix:@"6129" minBytes:1])) {
        CGFloat liters = (CGFloat)[b[0] unsignedIntValue] / 2.0;
        if (liters >= 0.0 && liters <= 48.0) {
            self.fuelRemainingLiters = MIN(45.0, liters);
            self.fuelLevelPercent = (self.fuelRemainingLiters / 45.0) * 100.0;
            if (self.lastLoggedFuelLiters < 0.0 || fabs(self.fuelRemainingLiters - self.lastLoggedFuelLiters) >= 1.0) {
                self.lastLoggedFuelLiters = self.fuelRemainingLiters;
                [self obdLog:@"7C0_6129 FUEL -> %.1f L (%.0f%% raw=0x%02X)",
                 self.fuelRemainingLiters, self.fuelLevelPercent, [b[0] unsignedIntValue]];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        }
        return;
    }

    // 7C4 2121: Air Conditioner ECU Room / Cabin Temp -> A * 63.75 / 255 - 6.5
    if ([self.activeCANHeader isEqualToString:@"7C4"] && (b = [self bytesFromHex:hex afterPrefix:@"6121" minBytes:1])) {
        CGFloat roomC = (CGFloat)(([b[0] unsignedIntValue] * 63.75 / 255.0) - 6.5);
        if (roomC >= -10.0 && roomC <= 60.0) {
            self.cabinTempC = roomC;
            self.hasLive7C4CabinTemp = YES;
            if (self.lastLoggedCabinTempC < -500.0 || fabs(roomC - self.lastLoggedCabinTempC) >= 1.0) {
                self.lastLoggedCabinTempC = roomC;
                [self obdLog:@"7C4_6121 CABIN -> %.1f C (raw=%@)", roomC, hex];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        }
        return;
    }

    // 7C4 2122: Air Conditioner ECU Exterior Ambient Temp -> A * 89.25 / 255 - 23.3
    if ([self.activeCANHeader isEqualToString:@"7C4"] && (b = [self bytesFromHex:hex afterPrefix:@"6122" minBytes:1])) {
        CGFloat extC = (CGFloat)(([b[0] unsignedIntValue] * 89.25 / 255.0) - 23.3);
        if (extC >= -30.0 && extC <= 70.0) {
            self.exteriorTempC = extC;
            if (self.lastLoggedExteriorTempC < -500.0 || fabs(extC - self.lastLoggedExteriorTempC) >= 1.0) {
                self.lastLoggedExteriorTempC = extC;
                [self obdLog:@"7C4_6122 EXT -> %.1f C (raw=%@)", extC, hex];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        }
        return;
    }

    // 7C0 2112: Log meter changes for shift/indicator verification
    if ([hex hasPrefix:@"6112"]) {
        if (![self.lastShiftHex6112 isEqualToString:hex]) {
            self.lastShiftHex6112 = hex;
            [self obdLog:@"7C0_6112 -> %@", hex];
        }
        return;
    }

    // 7E2 2101: Prius ZVW30 HV ECU Multi-frame -> Byte V (idx 21) * 20 / 51 = SOC %
    if ((b = [self bytesFromHex:hex afterPrefix:@"6101" minBytes:22])) {
        self.hybridBatterySOC = (CGFloat)([b[21] unsignedIntValue] * 20.0 / 51.0);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 7E2 2141: Shift lever sensor voltages + P Pos Switch Voltage (fallback only when CAN 0x127 is stale)
    if ((b = [self bytesFromHex:hex afterPrefix:@"6141" minBytes:9])) {
        if (![self.lastShiftHex6141 isEqualToString:hex]) {
            self.lastShiftHex6141 = hex;
            [self obdLog:@"7E2_6141 -> %@", hex];
        }
        BOOL can127Fresh = (self.lastCAN127At && [[NSDate date] timeIntervalSinceDate:self.lastCAN127At] < 15.0);
        if (!can127Fresh) {
            BOOL inPark = ([b[7] unsignedIntValue] >= 0x20);
            self.parkSwitchEngaged = inPark;
            if (inPark) {
                [self updateLiveGear:@"P" fromCAN127:NO];
            } else if ([self.currentGear isEqualToString:@"P"]) {
                [self updateLiveGear:@"D" fromCAN127:NO];
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 7E2 2161: MG1 Temp & RPM
    if ((b = [self bytesFromHex:hex afterPrefix:@"6161" minBytes:5])) {
        self.mg1TempC = (CGFloat)((int)[b[0] unsignedIntValue] - 40);
        self.mg1RPM = (NSInteger)([b[3] unsignedIntValue] * 256 + [b[4] unsignedIntValue]) - 32768;
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 7E2 2162: MG2 Temp & RPM
    if ((b = [self bytesFromHex:hex afterPrefix:@"6162" minBytes:5])) {
        self.mg2TempC = (CGFloat)((int)[b[0] unsignedIntValue] - 40);
        self.mg2RPM = (NSInteger)([b[3] unsignedIntValue] * 256 + [b[4] unsignedIntValue]) - 32768;
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 7E2 2171: Inverter MG2 Temp
    if ((b = [self bytesFromHex:hex afterPrefix:@"6171" minBytes:1])) {
        self.inverterTempC = (CGFloat)((int)[b[0] unsignedIntValue] - 40);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 7E2 218A: HV Pack Current -> (A*256 + B)/100 - 327.68
    if ((b = [self bytesFromHex:hex afterPrefix:@"618A" minBytes:2])) {
        self.hvPackCurrent = (CGFloat)((([b[0] unsignedIntValue] * 256.0) + [b[1] unsignedIntValue]) / 100.0 - 327.68);
        self.regenBrakingPowerKW = (self.hvPackCurrent < -0.5 && self.hvPackVoltage > 100.0)
            ? (CGFloat)(fabs(self.hvPackVoltage * self.hvPackCurrent) / 1000.0) : 0.0;
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 7E2 2187: HV Intake & 3 Pack Temperature Sensors
    if ((b = [self bytesFromHex:hex afterPrefix:@"6187" minBytes:8])) {
        double scale = 255.9 / 65535.0;
        double tIn = (([b[0] unsignedIntValue] * 256.0) + [b[1] unsignedIntValue]) * scale - 50.0;
        double t1  = (([b[2] unsignedIntValue] * 256.0) + [b[3] unsignedIntValue]) * scale - 50.0;
        double t2  = (([b[4] unsignedIntValue] * 256.0) + [b[5] unsignedIntValue]) * scale - 50.0;
        double t3  = (([b[6] unsignedIntValue] * 256.0) + [b[7] unsignedIntValue]) * scale - 50.0;
        self.hvIntakeTempC = (CGFloat)tIn;
        self.hvBatteryTempC = (CGFloat)((t1 + t2 + t3) / 3.0);
        if (!self.hasLive7C4CabinTemp) {
            self.cabinTempC = self.hvIntakeTempC;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 7E2 2181: 14 Hybrid Block Voltages + Total Pack Voltage (bytes 30..31)
    if ((b = [self bytesFromHex:hex afterPrefix:@"6181" minBytes:32])) {
        NSMutableArray<NSNumber *> *blocks = [NSMutableArray arrayWithCapacity:14];
        CGFloat minV = 99.0, maxV = 0.0;
        for (NSUInteger i = 0; i < 14; i++) {
            double raw = ([b[i * 2] unsignedIntValue] * 256.0) + [b[i * 2 + 1] unsignedIntValue];
            CGFloat v = (CGFloat)((raw * 79.99) / 65535.0);
            if (v < minV) minV = v;
            if (v > maxV) maxV = v;
            [blocks addObject:@(v)];
        }
        self.hvBlockVoltages = blocks;
        self.hvBlockMinV = minV;
        self.hvBlockMaxV = maxV;
        self.hvPackVoltage = (CGFloat)((([b[30] unsignedIntValue] * 256.0) + [b[31] unsignedIntValue]) / 10.0);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }

    // 7E2 2198: Delta SOC -> E/2
    if ((b = [self bytesFromHex:hex afterPrefix:@"6198" minBytes:5])) {
        self.hvDeltaSOC = (CGFloat)([b[4] unsignedIntValue] / 2.0);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }
}

#pragma mark - Body ECU Auto Door Lock (Prius 0x750)

- (void)setAutoDoorLockEnabled:(BOOL)enabled {
    self.autoDoorLockEnabled = enabled;
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setBool:enabled forKey:@"TRDAutoDoorLockEnabled"];
    [prefs synchronize];
    [self obdLog:@"AutoDoorLockEnabled -> %d", enabled];
}

- (void)setAutoDoorUnlockOnParkEnabled:(BOOL)enabled {
    self.autoDoorUnlockOnParkEnabled = enabled;
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setBool:enabled forKey:@"TRDAutoDoorUnlockOnParkEnabled"];
    [prefs synchronize];
    [self obdLog:@"AutoDoorUnlockOnParkEnabled -> %d", enabled];
}

- (void)requestDoorLock:(BOOL)lock {
    if (!self.isConnected || !self.obdInitialized) {
        [self obdLog:@"BODY_ECU door %@ skipped (OBD not connected)", lock ? @"LOCK" : @"UNLOCK"];
        return;
    }
    if (self.pendingBodyCommands.count > 0) {
        [self obdLog:@"BODY_ECU door %@ skipped (command already queued)", lock ? @"LOCK" : @"UNLOCK"];
        return;
    }
    NSString *payload = lock ? @"30 11 00 80 00" : @"30 11 00 40 00";
    [self.pendingBodyCommands addObjectsFromArray:@[
        @"ATSH 750",
        @"ATCEA 40",
        payload,
        @"ATCEA",
        @"ATSH 7DF"
    ]];
    [self obdLog:@"BODY_ECU enqueue door %@ (speed=%.0f gear=%@)", lock ? @"LOCK" : @"UNLOCK", self.currentSpeedKmh, self.currentGear ?: @"?"];
}

- (void)evaluateAutoDoorLockForSpeed:(CGFloat)kmh {
    if (!self.autoDoorLockEnabled || !self.isConnected || !self.obdInitialized) return;
    BOOL anyDoorOpen = self.doorSensorsLive && (self.doorFrontLeftOpen || self.doorFrontRightOpen || self.doorRearLeftOpen || self.doorRearRightOpen);
    if (!self.autoDoorLockedForDrive) {
        if (!anyDoorOpen && kmh >= 20.0 && ![self.currentGear isEqualToString:@"P"]) {
            self.autoDoorLockedForDrive = YES;
            [self obdLog:@"Auto-Lock triggered at %.0f km/h (gear=%@)", kmh, self.currentGear ?: @"?"];
            [self requestDoorLock:YES];
        }
    } else if ([self.currentGear isEqualToString:@"P"] && kmh < 1.0) {
        self.autoDoorLockedForDrive = NO;
        [self obdLog:@"Auto-Lock disarmed in Park (autoUnlock=%d)", self.autoDoorUnlockOnParkEnabled];
        if (self.autoDoorUnlockOnParkEnabled) {
            [self requestDoorLock:NO];
        }
    }
}

@end
