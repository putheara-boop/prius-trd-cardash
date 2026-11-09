//
// TRDOBDClient.m - CarDash OBD2 / CAN-Bus Integration Module for Toyota Prius TRD
//

#import "TRDOBDClient.h"

NSString * const TRDOBDDataDidUpdateNotification = @"TRDOBDDataDidUpdateNotification";
NSString * const TRDOBDConnectionStateChangedNotification = @"TRDOBDConnectionStateChangedNotification";

// Well-known BLE Serial Services used by vLinker MC+ and ELM327 BLE
static NSString * const kNordicUARTServiceUUID = @"6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
static NSString * const kNordicUARTTXCharUUID  = @"6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write
static NSString * const kNordicUARTRXCharUUID  = @"6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Notify

static NSString * const kSerialServiceUUID_FFE0 = @"FFE0";
static NSString * const kSerialCharUUID_FFE1    = @"FFE1";

static NSString * const kSerialServiceUUID_FFF0 = @"FFF0";
static NSString * const kSerialCharUUID_FFF1    = @"FFF1";
static NSString * const kSerialCharUUID_FFF2    = @"FFF2";

@interface TRDOBDClient ()
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *activePeripheral;
@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;
@property (nonatomic, strong) CBCharacteristic *notifyCharacteristic;

@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, copy) NSString *connectionStatus;
@property (nonatomic, copy) NSString *connectedDeviceName;

// Metrics
@property (nonatomic, assign) NSInteger engineRPM;
@property (nonatomic, assign) CGFloat coolantTempC;
@property (nonatomic, assign) CGFloat hybridBatterySOC;
@property (nonatomic, assign) CGFloat inverterTempC;
@property (nonatomic, assign) CGFloat auxBatteryVoltage;
@property (nonatomic, assign) CGFloat currentSpeedKmh;

@property (nonatomic, assign) CGFloat fuelLevelPercent;
@property (nonatomic, assign) CGFloat fuelRemainingLiters;
@property (nonatomic, assign) CGFloat fuelPricePerLiter;
@property (nonatomic, assign) CGFloat tripFuelUsedLiters;
@property (nonatomic, assign) CGFloat tripFuelCostTHB;
@property (nonatomic, assign) CGFloat tripAverageKmPerL;
@property (nonatomic, assign) CGFloat tripEVDistancePercent;

@property (nonatomic, copy) NSString *currentGear;
@property (nonatomic, assign) BOOL doorFrontLeftOpen;
@property (nonatomic, assign) BOOL doorFrontRightOpen;
@property (nonatomic, assign) BOOL doorRearLeftOpen;
@property (nonatomic, assign) BOOL doorRearRightOpen;
@property (nonatomic, assign) BOOL trunkOpen;
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
        _currentGear = @"P";
        _engineRPM = 0;
        _coolantTempC = 0.0;
        _hybridBatterySOC = 60.0; // Default Prius nominal SOC
        _inverterTempC = 35.0;
        _auxBatteryVoltage = 12.6;
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
        
        // Fuel type and pump price setup
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
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

- (void)initBluetooth {
    if (!self.centralManager) {
        self.connectionStatus = @"Starting BLE Engine...";
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
    }
}

- (void)startScanning {
    if (!self.centralManager) {
        [self initBluetooth];
        return;
    }
    if (self.centralManager.state == CBCentralManagerStatePoweredOn) {
        self.connectionStatus = @"Scanning for vLinker MC+...";
        [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
    }
}

- (void)stopScanning {
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
    if (central.state == CBCentralManagerStatePoweredOn) {
        self.connectionStatus = @"Bluetooth Ready. Scanning...";
        [self startScanning];
    } else if (central.state == CBCentralManagerStatePoweredOff) {
        self.connectionStatus = @"Bluetooth OFF";
        self.isConnected = NO;
    } else {
        self.connectionStatus = @"Bluetooth Unavailable";
        self.isConnected = NO;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSString *name = peripheral.name ?: advertisementData[CBAdvertisementDataLocalNameKey] ?: @"";
    
    // Match vLinker MC+, Vgate, or generic OBD BLE names
    BOOL isMatch = ([name rangeOfString:@"vLinker" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [name rangeOfString:@"Vgate" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [name rangeOfString:@"OBD" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [name rangeOfString:@"IOS-VLINK" options:NSCaseInsensitiveSearch].location != NSNotFound);
    
    if (isMatch) {
        self.connectionStatus = [NSString stringWithFormat:@"Found %@", name];
        self.activePeripheral = peripheral;
        self.connectedDeviceName = name;
        [self.centralManager stopScan];
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    self.isConnected = YES;
    self.connectionStatus = [NSString stringWithFormat:@"Connected: %@", peripheral.name ?: @"vLinker"];
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    self.isConnected = NO;
    self.connectionStatus = @"Disconnected. Auto-reconnecting...";
    self.activePeripheral = nil;
    self.writeCharacteristic = nil;
    self.notifyCharacteristic = nil;
    if (self.pollingTimer) {
        [self.pollingTimer invalidate];
        self.pollingTimer = nil;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDConnectionStateChangedNotification object:self];
    
    // Auto-reconnect after 3 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startScanning];
    });
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) return;
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) return;
    for (CBCharacteristic *c in service.characteristics) {
        if ((c.properties & CBCharacteristicPropertyWrite) || (c.properties & CBCharacteristicPropertyWriteWithoutResponse)) {
            self.writeCharacteristic = c;
        }
        if ((c.properties & CBCharacteristicPropertyNotify) || (c.properties & CBCharacteristicPropertyIndicate)) {
            self.notifyCharacteristic = c;
            [peripheral setNotifyValue:YES forCharacteristic:c];
        }
    }
    
    // If both channels found, initialize ELM / STN
    if (self.writeCharacteristic && self.notifyCharacteristic && !self.pollingTimer) {
        [self startOBDInitializationSequence];
    }
}

#pragma mark - OBD Protocol Communication

- (void)sendCommand:(NSString *)cmd {
    if (!self.writeCharacteristic || !self.activePeripheral) return;
    NSString *fullCmd = [cmd stringByAppendingString:@"\r"];
    NSData *data = [fullCmd dataUsingEncoding:NSASCIIStringEncoding];
    CBCharacteristicWriteType writeType = (self.writeCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) ? CBCharacteristicWriteWithoutResponse : CBCharacteristicWriteWithResponse;
    [self.activePeripheral writeValue:data forCharacteristic:self.writeCharacteristic type:writeType];
}

- (void)startOBDInitializationSequence {
    self.connectionStatus = @"Configuring CAN-Bus...";
    NSArray *initCmds = @[@"ATZ", @"ATE0", @"ATL0", @"ATS0", @"ATSP6"]; // SP6 = ISO 15765-4 CAN 11bit 500kbps (Prius)
    for (int i = 0; i < initCmds.count; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.15 * (i + 1)) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sendCommand:initCmds[i]];
        });
    }
    
    // Start Polling Loop after init
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.connectionStatus = @"CAN-Bus Live";
        self.pollingTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(pollNextOBD) userInfo:nil repeats:YES];
    });
}

// Tiered Polling loop (RPM fast, temperatures & doors moderate)
- (void)pollNextOBD {
    if (!self.isConnected || !self.writeCharacteristic) return;
    
    self.pollIndex++;
    if (self.pollIndex % 2 == 0) {
        // High priority: RPM (Every 0.5s)
        [self sendCommand:@"010C"];
    } else if (self.pollIndex % 4 == 1) {
        // MAF (Mass Air Flow for fuel flow)
        [self sendCommand:@"0110"];
    } else if (self.pollIndex % 8 == 3) {
        // Coolant Temp
        [self sendCommand:@"0105"];
    } else if (self.pollIndex % 16 == 5) {
        // 12V Control Module Voltage
        [self sendCommand:@"0142"];
    } else if (self.pollIndex % 20 == 7) {
        // Fuel Tank Level
        [self sendCommand:@"012F"];
    } else if (self.pollIndex % 24 == 9) {
        // Prius Hybrid Battery SoC
        [self sendCommand:@"2101"];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error || !characteristic.value) return;
    NSString *chunk = [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
    if (!chunk.length) return;
    
    [self.rxBuffer appendString:chunk];
    if ([self.rxBuffer rangeOfString:@">"].location != NSNotFound || [self.rxBuffer rangeOfString:@"\r"].location != NSNotFound) {
        NSString *clean = [self.rxBuffer stringByReplacingOccurrencesOfString:@" " withString:@""];
        clean = [clean stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        clean = [clean stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        clean = [clean stringByReplacingOccurrencesOfString:@">" withString:@""];
        [self parseOBDResponse:clean];
        [self.rxBuffer setString:@""];
    }
}

#pragma mark - Parser Engine

- (void)parseOBDResponse:(NSString *)hex {
    if (hex.length < 4) return;
    
    // 010C: Engine RPM -> "410CXXYY"
    if ([hex hasPrefix:@"410C"] && hex.length >= 8) {
        unsigned int a = 0, b = 0;
        NSScanner *sA = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4, 2)]];
        NSScanner *sB = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(6, 2)]];
        [sA scanHexInt:&a];
        [sB scanHexInt:&b];
        self.engineRPM = (NSInteger)(((a * 256) + b) / 4);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }
    
    // 0105: Coolant Temp -> "4105XX"
    if ([hex hasPrefix:@"4105"] && hex.length >= 6) {
        unsigned int a = 0;
        NSScanner *s = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4, 2)]];
        [s scanHexInt:&a];
        self.coolantTempC = (CGFloat)((int)a - 40);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }
    
    // 0110: MAF (Mass Air Flow in g/s) -> "4110XXYY"
    if ([hex hasPrefix:@"4110"] && hex.length >= 8) {
        unsigned int a = 0, b = 0;
        NSScanner *sA = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4, 2)]];
        NSScanner *sB = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(6, 2)]];
        [sA scanHexInt:&a];
        [sB scanHexInt:&b];
        double mafGps = ((a * 256.0) + b) / 100.0;
        
        // Fuel flow calculation: Gasoline stoichiometric ratio 14.7, density ~740 g/L
        // Liters/sec = (MAF / 14.7) / 740.0
        NSDate *now = [NSDate date];
        if (self.lastFuelCalcTime) {
            NSTimeInterval dt = [now timeIntervalSinceDate:self.lastFuelCalcTime];
            if (dt > 0.0 && dt < 2.0) {
                double lps = (mafGps / 14.7) / 740.0;
                self.tripFuelUsedLiters += (CGFloat)(lps * dt);
                self.tripFuelCostTHB = self.tripFuelUsedLiters * self.fuelPricePerLiter;
            }
        }
        self.lastFuelCalcTime = now;
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }
    
    // 012F: Fuel Level -> "412FXX"
    if ([hex hasPrefix:@"412F"] && hex.length >= 6) {
        unsigned int a = 0;
        NSScanner *s = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4, 2)]];
        [s scanHexInt:&a];
        self.fuelLevelPercent = (CGFloat)((a * 100.0) / 255.0);
        self.fuelRemainingLiters = (CGFloat)(self.fuelLevelPercent * 0.45); // Prius 45L tank
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }
    
    // 0142: Control Module Voltage -> "4142XXYY"
    if ([hex hasPrefix:@"4142"] && hex.length >= 8) {
        unsigned int a = 0, b = 0;
        NSScanner *sA = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4, 2)]];
        NSScanner *sB = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(6, 2)]];
        [sA scanHexInt:&a];
        [sB scanHexInt:&b];
        self.auxBatteryVoltage = (CGFloat)(((a * 256.0) + b) / 1000.0);
        [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        return;
    }
    
    // 2101: Toyota Prius Hybrid Battery SOC
    if ([hex hasPrefix:@"6101"] && hex.length >= 14) {
        // Byte 5 is SOC in 0.5% resolution
        unsigned int socHex = 0;
        NSScanner *s = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(10, 2)]];
        if ([s scanHexInt:&socHex]) {
            self.hybridBatterySOC = (CGFloat)(socHex * 0.5);
            [[NSNotificationCenter defaultCenter] postNotificationName:TRDOBDDataDidUpdateNotification object:self];
        }
        return;
    }
}

@end
