#ifndef TRD_OBD2_ENGINE_H
#define TRD_OBD2_ENGINE_H

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <AVFoundation/AVFoundation.h>
#include <math.h>

// Toyota Prius Gen 3 (ZVW30) NiMH pack has 28 modules monitored in 14 pairs (Blocks 1..14)
#define TRD_HV_BLOCK_COUNT 14

typedef NS_ENUM(NSInteger, TRDOBDConnectionState) {
    TRDOBDStateDisconnected = 0,
    TRDOBDStateScanning,
    TRDOBDStateConnecting,
    TRDOBDStateInitializing,
    TRDOBDStateLive,
    TRDOBDStateDemo
};

@interface TRDPriusTelemetry : NSObject
// Primary Driving
@property (nonatomic, assign) double speedKmh;          // 010D (km/h)
@property (nonatomic, assign) double engineRPM;         // 010C (RPM)
@property (nonatomic, copy)   NSString *gear;           // P, R, N, D, B
@property (nonatomic, assign) BOOL inReverse;

// Hybrid System & Motors (ECU 7E2)
@property (nonatomic, assign) double mg1RPM;            // Generator RPM
@property (nonatomic, assign) double mg1TorqueNm;
@property (nonatomic, assign) double mg2RPM;            // Traction Motor RPM
@property (nonatomic, assign) double mg2TorqueNm;
@property (nonatomic, assign) double evPowerKw;         // +kW discharge / -kW regen charge
@property (nonatomic, copy)   NSString *energyFlowState;// EV DRIVE, HYBRID ASSIST, CHG / REGEN, STANDBY

// Temperatures (Real vs Estimated clearly tracked)
@property (nonatomic, assign) double coolantTempC;      // 0105 (°C)
@property (nonatomic, assign) double inverterTempC;     // 7E2 21C3 (°C)
@property (nonatomic, assign) double mg1TempC;          // 7E2 21C3 (°C)
@property (nonatomic, assign) double mg2TempC;          // 7E2 21C3 (°C)
@property (nonatomic, assign) double ambientTempC;      // 0146 (°C)
@property (nonatomic, assign) double cabinTempC;        // 7C0 / A/C (°C)
@property (nonatomic, assign) double hvBattTempMaxC;    // 7E3 (°C)

// Electrical & HV Battery (ECU 7E3 + ATRV)
@property (nonatomic, assign) double aux12Voltage;      // ATRV (V)
@property (nonatomic, assign) double hvSOCPercent;      // 7E3 SOC (%)
@property (nonatomic, assign) double hvPackVoltage;     // Sum of 14 blocks (V)
@property (nonatomic, assign) double hvPackCurrentA;    // +A discharge / -A charge
@property (nonatomic, assign) double hvBlockMinV;
@property (nonatomic, assign) double hvBlockMaxV;
@property (nonatomic, assign) double hvDeltaV;          // Max - Min block voltage (V)
@property (nonatomic, assign) double hvHealthEstimatePct;// Calculated from DeltaV
@property (nonatomic, assign) double estimatedRangeKm;  // Calculated from fuel/SOC/consumption

// Eco Coach & Safety
@property (nonatomic, assign) NSInteger ecoScore;       // 0..100
@property (nonatomic, assign) double regenRecoveredWh;  // Cumulative Wh recovered this trip
@property (nonatomic, copy)   NSString *ecoCoachTip;
@property (nonatomic, assign) BOOL doorOpen;
@property (nonatomic, assign) BOOL driverDoorOpen;
@property (nonatomic, assign) BOOL passengerDoorOpen;
@property (nonatomic, assign) BOOL backDoorOpen;
@property (nonatomic, assign) BOOL doorsLocked;
@property (nonatomic, assign) double acSetTempC;
@property (nonatomic, assign) BOOL seatbeltUnfastened;
@property (nonatomic, assign) BOOL isLiveOBD;           // YES = Real BLE OBD2, NO = Demo/GPS
@property (nonatomic, assign) BOOL isOverSpeed;
@property (nonatomic, assign) BOOL isHighDeltaWarn;
@property (nonatomic, assign) BOOL isHighTempWarn;

- (double)blockVoltageAtIndex:(NSUInteger)idx;
- (void)setBlockVoltage:(double)voltage atIndex:(NSUInteger)idx;
- (void)recalculateBlockStats;
@end

@implementation TRDPriusTelemetry {
    double _blocks[TRD_HV_BLOCK_COUNT];
}
- (instancetype)init {
    if ((self = [super init])) {
        _gear = @"P";
        _energyFlowState = @"READY · EV STANDBY";
        _coolantTempC = 82.0;
        _inverterTempC = 41.0;
        _mg1TempC = 48.0;
        _mg2TempC = 52.0;
        _ambientTempC = 31.0;
        _cabinTempC = 24.5;
        _hvBattTempMaxC = 34.0;
        _aux12Voltage = 14.1;
        _hvSOCPercent = 64.5;
        _ecoScore = 92;
        _ecoCoachTip = @"ระบบไฮบริดพร้อมทำงาน • รักษาคันเร่งให้คงที่เพื่อวิ่งโหมด EV";
        _estimatedRangeKm = 540.0;
        double sum = 0;
        for (int i = 0; i < TRD_HV_BLOCK_COUNT; i++) {
            _blocks[i] = 16.20 + ((i % 3) * 0.02);
            sum += _blocks[i];
        }
        _hvPackVoltage = sum;
        _hvBlockMinV = 16.20;
        _hvBlockMaxV = 16.24;
        _hvDeltaV = 0.04;
        _hvHealthEstimatePct = 96.0;
    }
    return self;
}
- (double)blockVoltageAtIndex:(NSUInteger)idx {
    if (idx >= TRD_HV_BLOCK_COUNT) return 0.0;
    return _blocks[idx];
}
- (void)setBlockVoltage:(double)voltage atIndex:(NSUInteger)idx {
    if (idx >= TRD_HV_BLOCK_COUNT) return;
    _blocks[idx] = voltage;
}
- (void)recalculateBlockStats {
    double minV = 99.0, maxV = 0.0, sum = 0.0;
    for (int i = 0; i < TRD_HV_BLOCK_COUNT; i++) {
        double v = _blocks[i];
        if (v > 5.0) {
            if (v < minV) minV = v;
            if (v > maxV) maxV = v;
            sum += v;
        }
    }
    if (maxV > minV && minV < 90.0) {
        self.hvBlockMinV = minV;
        self.hvBlockMaxV = maxV;
        self.hvDeltaV = maxV - minV;
        self.hvPackVoltage = sum;
        // Prius Gen 3 healthy NiMH pair delta is <= 0.15V; > 0.50V indicates weak module
        double health = 100.0 - MAX(0.0, (self.hvDeltaV - 0.03) * 120.0);
        self.hvHealthEstimatePct = MAX(40.0, MIN(100.0, health));
    }
}
@end

@protocol TRDOBD2EngineDelegate <NSObject>
@optional
- (void)obdEngineDidUpdateTelemetry:(TRDPriusTelemetry *)telemetry;
- (void)obdEngineDidChangeState:(TRDOBDConnectionState)state statusText:(NSString *)statusText;
- (void)obdEngineDidDetectReverseGear:(BOOL)inReverse;
@end

@interface TRDOBD2Engine : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>
@property (nonatomic, weak) id<TRDOBD2EngineDelegate> delegate;
@property (nonatomic, strong, readonly) TRDPriusTelemetry *telemetry;
@property (nonatomic, assign, readonly) TRDOBDConnectionState state;
@property (nonatomic, copy, readonly) NSString *statusText;
@property (nonatomic, copy, readonly) NSString *adapterName;
@property (nonatomic, assign) BOOL demoMode;
@property (nonatomic, assign) BOOL thaiVoiceEnabled;
@property (nonatomic, assign) double speedLimitKmh; // 0 = Disabled, 90, 120
@property (nonatomic, assign) BOOL batteryGuardianEnabled;

- (void)start;
- (void)stop;
- (void)toggleDemoOrScan;
- (void)speakThai:(NSString *)phrase;
- (void)speakEcoSummary;
@end

@interface TRDOBD2Engine ()
- (void)startBLEScan;
- (void)enqueueInitSequence;
- (void)enqueuePID:(NSString *)pid header:(NSString *)header;
- (void)dequeueNextCommand;
- (void)handleCommandTimeout;
- (void)parseOBDResponse:(NSString *)raw forCommand:(NSString *)cmd;
- (void)maybeWarn:(NSString *)thaiWarning;
- (void)updateDerivedMetrics;
- (void)pollTick;
- (void)stepDemoSimulation;
@end

@implementation TRDOBD2Engine {
    CBCentralManager *_central;
    CBPeripheral *_peripheral;
    CBCharacteristic *_writeChar;
    CBCharacteristic *_notifyChar;
    NSMutableString *_rxBuffer;
    NSMutableArray<NSString *> *_cmdQueue;
    NSString *_currentCmd;
    NSString *_currentHeader;
    BOOL _awaitingPrompt;
    NSTimer *_pollTimer;
    NSTimer *_cmdTimeoutTimer;
    NSUInteger _tickCount;
    AVSpeechSynthesizer *_synth;
    NSDate *_lastVoiceAlertDate;
    NSDate *_lastSpeedAlertDate;
    NSDate *_lastDeltaAlertDate;
    NSDate *_lastTempAlertDate;
    NSDate *_lastDoorAlertDate;
    BOOL _wasInReverse;
}

- (instancetype)init {
    if ((self = [super init])) {
        _telemetry = [[TRDPriusTelemetry alloc] init];
        _rxBuffer = [NSMutableString string];
        _cmdQueue = [NSMutableArray array];
        _statusText = @"DEMO SIM (แตะเพื่อสแกน vLinker BLE)";
        _adapterName = @"Vgate vLinker MC+";
        _demoMode = YES;
        _thaiVoiceEnabled = YES;
        _speedLimitKmh = 0.0;
        _batteryGuardianEnabled = YES;
        _state = TRDOBDStateDemo;
        _synth = [[AVSpeechSynthesizer alloc] init];
    }
    return self;
}

- (void)start {
    if (!_central) {
        NSDictionary *opts = @{CBCentralManagerOptionShowPowerAlertKey: @NO};
        _central = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:opts];
    }
    if (!_pollTimer) {
        _pollTimer = [NSTimer scheduledTimerWithTimeInterval:0.20 target:self selector:@selector(pollTick) userInfo:nil repeats:YES];
        _pollTimer.tolerance = 0.03;
    }
}

- (void)stop {
    [_pollTimer invalidate];
    _pollTimer = nil;
    [_cmdTimeoutTimer invalidate];
    _cmdTimeoutTimer = nil;
    if (_peripheral && _central) {
        [_central cancelPeripheralConnection:_peripheral];
    }
}

- (void)toggleDemoOrScan {
    if (self.demoMode) {
        self.demoMode = NO;
        self.telemetry.isLiveOBD = NO;
        [self startBLEScan];
        [self speakThai:@"กำลังค้นหาสัญญาณ โอบีดีทู บลูทูธ"];
    } else {
        if (_central.isScanning) [_central stopScan];
        if (_peripheral) [_central cancelPeripheralConnection:_peripheral];
        self.demoMode = YES;
        _state = TRDOBDStateDemo;
        _statusText = @"DEMO SIM (จำลองข้อมูลไฮบริด)";
        self.telemetry.isLiveOBD = NO;
        if ([self.delegate respondsToSelector:@selector(obdEngineDidChangeState:statusText:)]) {
            [self.delegate obdEngineDidChangeState:_state statusText:_statusText];
        }
        [self speakThai:@"สลับเป็นโหมดจำลองข้อมูลไฮบริด"];
    }
}

- (void)speakThai:(NSString *)phrase {
    if (!self.thaiVoiceEnabled || !phrase.length || !_synth) return;
    if (_synth.isSpeaking) return;
    AVSpeechUtterance *utt = [AVSpeechUtterance speechUtteranceWithString:phrase];
    AVSpeechSynthesisVoice *thVoice = [AVSpeechSynthesisVoice voiceWithLanguage:@"th-TH"];
    if (thVoice) utt.voice = thVoice;
    utt.rate = AVSpeechUtteranceDefaultSpeechRate;
    utt.volume = 0.90;
    [_synth speakUtterance:utt];
}

- (void)speakEcoSummary {
    NSString *msg = [NSString stringWithFormat:@"คะแนนอีโคของคุณคือ %ld คะแนน แบตเตอรี่ไฮบริด %.0f เปอร์เซ็นต์ อุณหภูมิอินเวอร์เตอร์ %.0f องศาเซลเซียส",
                     (long)self.telemetry.ecoScore, self.telemetry.hvSOCPercent, self.telemetry.inverterTempC];
    [self speakThai:msg];
}

- (void)startBLEScan {
    if (!_central) [self start];
    if (_central.state != CBManagerStatePoweredOn) {
        _state = TRDOBDStateDisconnected;
        _statusText = @"กรุณาเปิด Bluetooth ในหน้า Settings";
        if ([self.delegate respondsToSelector:@selector(obdEngineDidChangeState:statusText:)]) {
            [self.delegate obdEngineDidChangeState:_state statusText:_statusText];
        }
        return;
    }
    _state = TRDOBDStateScanning;
    _statusText = @"SCANNING vLinker MC+ BLE...";
    if ([self.delegate respondsToSelector:@selector(obdEngineDidChangeState:statusText:)]) {
        [self.delegate obdEngineDidChangeState:_state statusText:_statusText];
    }
    [_central scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn && !self.demoMode) {
        [self startBLEScan];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSString *name = peripheral.name ?: advertisementData[CBAdvertisementDataLocalNameKey] ?: @"";
    if (!name.length) return;
    NSString *upper = [name uppercaseString];
    BOOL isOBD = ([upper rangeOfString:@"VLINKER"].location != NSNotFound ||
                  [upper rangeOfString:@"VGATE"].location != NSNotFound ||
                  [upper rangeOfString:@"IOS-VLINK"].location != NSNotFound ||
                  [upper rangeOfString:@"OBD"].location != NSNotFound ||
                  [upper rangeOfString:@"ELM"].location != NSNotFound);
    if (isOBD) {
        [_central stopScan];
        _peripheral = peripheral;
        _peripheral.delegate = self;
        _adapterName = name;
        _state = TRDOBDStateConnecting;
        _statusText = [NSString stringWithFormat:@"CONNECTING %@...", name];
        if ([self.delegate respondsToSelector:@selector(obdEngineDidChangeState:statusText:)]) {
            [self.delegate obdEngineDidChangeState:_state statusText:_statusText];
        }
        [_central connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    _state = TRDOBDStateInitializing;
    _statusText = [NSString stringWithFormat:@"INIT %@...", _adapterName];
    if ([self.delegate respondsToSelector:@selector(obdEngineDidChangeState:statusText:)]) {
        [self.delegate obdEngineDidChangeState:_state statusText:_statusText];
    }
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    _writeChar = nil;
    _notifyChar = nil;
    _awaitingPrompt = NO;
    [_cmdQueue removeAllObjects];
    self.telemetry.isLiveOBD = NO;
    if (!self.demoMode) {
        _state = TRDOBDStateScanning;
        _statusText = @"OBD LOST · RECONNECTING...";
        if ([self.delegate respondsToSelector:@selector(obdEngineDidChangeState:statusText:)]) {
            [self.delegate obdEngineDidChangeState:_state statusText:_statusText];
        }
        [self startBLEScan];
    }
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *svc in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:svc];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *ch in service.characteristics) {
        if (ch.properties & (CBCharacteristicPropertyNotify | CBCharacteristicPropertyIndicate)) {
            _notifyChar = ch;
            [peripheral setNotifyValue:YES forCharacteristic:ch];
        }
        if (ch.properties & (CBCharacteristicPropertyWrite | CBCharacteristicPropertyWriteWithoutResponse)) {
            _writeChar = ch;
        }
    }
    if (_writeChar && _notifyChar && _state == TRDOBDStateInitializing) {
        _state = TRDOBDStateLive;
        _statusText = [NSString stringWithFormat:@"OBD-II LIVE · %@", _adapterName];
        self.telemetry.isLiveOBD = YES;
        if ([self.delegate respondsToSelector:@selector(obdEngineDidChangeState:statusText:)]) {
            [self.delegate obdEngineDidChangeState:_state statusText:_statusText];
        }
        [self enqueueInitSequence];
        [self speakThai:@"เชื่อมต่อ โอบีดีทู สำเร็จแล้ว"];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error || !characteristic.value.length) return;
    NSString *chunk = [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
    if (!chunk) return;
    [_rxBuffer appendString:chunk];
    if ([_rxBuffer rangeOfString:@">"].location != NSNotFound) {
        NSString *fullResponse = [_rxBuffer copy];
        [_rxBuffer setString:@""];
        _awaitingPrompt = NO;
        [_cmdTimeoutTimer invalidate];
        _cmdTimeoutTimer = nil;
        [self parseOBDResponse:fullResponse forCommand:_currentCmd];
        [self dequeueNextCommand];
    }
}

#pragma mark - Command Queue & Prius Gen 3 PID Parser

- (void)enqueueInitSequence {
    [_cmdQueue removeAllObjects];
    _awaitingPrompt = NO;
    _currentHeader = @"";
    [_cmdQueue addObjectsFromArray:@[@"ATZ", @"ATE0", @"ATL0", @"ATS0", @"ATH0", @"ATSP6", @"ATRV"]];
    [self dequeueNextCommand];
}

- (void)enqueuePID:(NSString *)pid header:(NSString *)header {
    if (_cmdQueue.count > 12) return;
    if (header.length && ![header isEqualToString:_currentHeader]) {
        [_cmdQueue addObject:[NSString stringWithFormat:@"ATSH%@", header]];
        _currentHeader = header;
    }
    [_cmdQueue addObject:pid];
    [self dequeueNextCommand];
}

- (void)dequeueNextCommand {
    if (_awaitingPrompt || !_writeChar || !_peripheral || _cmdQueue.count == 0) return;
    _currentCmd = _cmdQueue.firstObject;
    [_cmdQueue removeObjectAtIndex:0];
    _awaitingPrompt = YES;
    NSString *wire = [_currentCmd stringByAppendingString:@"\r"];
    NSData *data = [wire dataUsingEncoding:NSASCIIStringEncoding];
    CBCharacteristicWriteType wType = (_writeChar.properties & CBCharacteristicPropertyWriteWithoutResponse) ? CBCharacteristicWriteWithoutResponse : CBCharacteristicWriteWithResponse;
    [_peripheral writeValue:data forCharacteristic:_writeChar type:wType];
    [_cmdTimeoutTimer invalidate];
    _cmdTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:1.2 target:self selector:@selector(handleCommandTimeout) userInfo:nil repeats:NO];
}

- (void)handleCommandTimeout {
    _awaitingPrompt = NO;
    [_rxBuffer setString:@""];
    [self dequeueNextCommand];
}

static NSArray<NSNumber *> *TRDHexBytesFromLine(NSString *raw) {
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        if ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')) {
            [hex appendFormat:@"%C", c];
        }
    }
    NSMutableArray<NSNumber *> *bytes = [NSMutableArray array];
    for (NSUInteger i = 0; i + 1 < hex.length; i += 2) {
        unsigned int val = 0;
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&val];
        [bytes addObject:@(val & 0xFF)];
    }
    return bytes;
}

- (void)parseOBDResponse:(NSString *)raw forCommand:(NSString *)cmd {
    if (!cmd.length || !raw.length) return;
    NSString *clean = [[raw stringByReplacingOccurrencesOfString:@"\r" withString:@" "]
                       stringByReplacingOccurrencesOfString:@">" withString:@""];
    if ([cmd isEqualToString:@"ATRV"]) {
        NSScanner *sc = [NSScanner scannerWithString:clean];
        double v = 0.0;
        if ([sc scanDouble:&v] && v > 8.0 && v < 18.0) {
            self.telemetry.aux12Voltage = v;
            if (v < 11.7) [self maybeWarn:@"แบตเตอรี่สิบสองโวลต์แรงดันต่ำกว่าปกติ"];
        }
        return;
    }
    NSArray<NSNumber *> *b = TRDHexBytesFromLine(clean);
    if (b.count < 3) return;

    // Standard Mode 01 responses: 41 <PID> <A> <B> ...
    if ([b[0] intValue] == 0x41) {
        int pid = [b[1] intValue];
        int A = [b[2] intValue];
        int B = (b.count > 3) ? [b[3] intValue] : 0;
        if (pid == 0x0D) {
            self.telemetry.speedKmh = A;
        } else if (pid == 0x0C && b.count >= 4) {
            self.telemetry.engineRPM = ((A * 256.0) + B) / 4.0;
        } else if (pid == 0x05) {
            self.telemetry.coolantTempC = A - 40.0;
            if (self.telemetry.coolantTempC >= 102.0) {
                [self maybeWarn:@"เตือน อุณหภูมิน้ำหล่อเย็นสูงเกินกำหนด"];
            }
        } else if (pid == 0x46) {
            self.telemetry.ambientTempC = A - 40.0;
        }
    }
    // Toyota Enhanced Mode 21 responses: 61 <PID> ...
    else if ([b[0] intValue] == 0x61) {
        int pid = [b[1] intValue];
        // Hybrid ECU 7E2: 21C3 (MG1/MG2 RPM, Inverter/Motor Temps)
        if (pid == 0xC3 && b.count >= 12) {
            int mg2H = [b[2] intValue], mg2L = [b[3] intValue];
            int mg1H = [b[6] intValue], mg1L = [b[7] intValue];
            self.telemetry.mg2RPM = ((mg2H * 256) + mg2L) - 16383;
            self.telemetry.mg1RPM = ((mg1H * 256) + mg1L) - 16383;
            if (b.count > 26) {
                self.telemetry.inverterTempC = [b[25] intValue] - 40.0;
                self.telemetry.mg2TempC = [b[26] intValue] - 40.0;
            }
        }
        // HV Battery ECU 7E3: 21CE (SOC, Pack Current, Block Voltages)
        else if (pid == 0xCE && b.count >= 6) {
            self.telemetry.hvSOCPercent = [b[2] intValue] * 0.5;
            int curH = [b[3] intValue], curL = [b[4] intValue];
            self.telemetry.hvPackCurrentA = ((curH * 256.0) + curL) / 100.0 - 327.68;
            for (int blk = 0; blk < TRD_HV_BLOCK_COUNT && (5 + blk * 2 + 1) < (int)b.count; blk++) {
                int vH = [b[5 + blk * 2] intValue];
                int vL = [b[5 + blk * 2 + 1] intValue];
                double blkV = ((vH * 256.0) + vL) / 100.0 - 327.68;
                if (blkV > 10.0 && blkV < 20.0) {
                    [self.telemetry setBlockVoltage:blkV atIndex:blk];
                }
            }
            [self.telemetry recalculateBlockStats];
            self.telemetry.evPowerKw = (self.telemetry.hvPackVoltage * self.telemetry.hvPackCurrentA) / 1000.0;
        }
        // A/C Amplifier ECU 7C0: 2101 (Cabin Temperature, Set Temp)
        else if (pid == 0x01 && [_currentHeader isEqualToString:@"7C0"] && b.count >= 3) {
            double cTemp = [b[2] intValue] * 0.5 - 40.0;
            if (cTemp >= 5.0 && cTemp <= 55.0) {
                self.telemetry.cabinTempC = cTemp;
            }
            if (b.count >= 5) {
                double sTemp = [b[4] intValue] * 0.5;
                if (sTemp >= 16.0 && sTemp <= 32.0) {
                    self.telemetry.acSetTempC = sTemp;
                }
            }
        }
        // Main Body ECU 750: 2101 / 2140 (Door Courtesy Switches & Central Locks)
        else if ([_currentHeader isEqualToString:@"750"] && b.count >= 3) {
            int dFlags = [b[2] intValue];
            self.telemetry.driverDoorOpen = (dFlags & 0x01) != 0;
            self.telemetry.passengerDoorOpen = (dFlags & 0x02) != 0;
            self.telemetry.backDoorOpen = (dFlags & 0x10) != 0;
            self.telemetry.doorOpen = (self.telemetry.driverDoorOpen || self.telemetry.passengerDoorOpen || self.telemetry.backDoorOpen);
            if (b.count >= 4) {
                int lFlags = [b[3] intValue];
                self.telemetry.doorsLocked = (lFlags & 0x01) != 0;
            }
        }
    }
    [self updateDerivedMetrics];
}

- (void)maybeWarn:(NSString *)thaiWarning {
    if (_lastVoiceAlertDate && -[_lastVoiceAlertDate timeIntervalSinceNow] < 30.0) return;
    _lastVoiceAlertDate = [NSDate date];
    [self speakThai:thaiWarning];
}

- (void)updateDerivedMetrics {
    double kw = self.telemetry.evPowerKw;
    if (self.telemetry.speedKmh < 1.0 && self.telemetry.engineRPM < 100.0) {
        self.telemetry.energyFlowState = @"READY · EV STANDBY";
    } else if (kw < -0.8) {
        self.telemetry.energyFlowState = @"⚡ REGEN BRAKING → HV BATT";
        self.telemetry.regenRecoveredWh += fabs(kw) * (0.20 / 3.6);
    } else if (self.telemetry.engineRPM < 400.0 && kw >= -0.8) {
        self.telemetry.energyFlowState = @"🌿 PURE EV DRIVE (MG2 → WHEELS)";
    } else {
        self.telemetry.energyFlowState = @"🔥 HYBRID POWER (ICE + MG2)";
    }

    if (self.telemetry.inReverse != _wasInReverse) {
        _wasInReverse = self.telemetry.inReverse;
        if (self.telemetry.inReverse) {
            [self speakThai:@"เข้าเกียร์ถอยหลัง โปรดระวังด้านหลัง"];
        }
        if ([self.delegate respondsToSelector:@selector(obdEngineDidDetectReverseGear:)]) {
            [self.delegate obdEngineDidDetectReverseGear:self.telemetry.inReverse];
        }
    }

    // Speed limit warning
    if (self.speedLimitKmh > 0 && self.telemetry.speedKmh > self.speedLimitKmh) {
        self.telemetry.isOverSpeed = YES;
        if (!_lastSpeedAlertDate || -[_lastSpeedAlertDate timeIntervalSinceNow] > 40.0) {
            _lastSpeedAlertDate = [NSDate date];
            [self speakThai:[NSString stringWithFormat:@"ความเร็วเกินกำหนด %.0f กิโลเมตรต่อชั่วโมง กรุณาลดความเร็ว", self.speedLimitKmh]];
        }
    } else {
        self.telemetry.isOverSpeed = NO;
    }

    // Proactive Hybrid Battery Guardian
    if (self.batteryGuardianEnabled) {
        if (self.telemetry.hvDeltaV > 0.25) {
            self.telemetry.isHighDeltaWarn = YES;
            if (!_lastDeltaAlertDate || -[_lastDeltaAlertDate timeIntervalSinceNow] > 600.0) {
                _lastDeltaAlertDate = [NSDate date];
                [self speakThai:@"คำเตือน แรงดันเซลล์แบตเตอรี่ไฮบริดเริ่มมีความต่างสูง ควรตรวจสอบเซลล์"];
            }
        } else {
            self.telemetry.isHighDeltaWarn = NO;
        }

        if (self.telemetry.hvBattTempMaxC > 42.0 || self.telemetry.inverterTempC > 65.0) {
            self.telemetry.isHighTempWarn = YES;
            if (!_lastTempAlertDate || -[_lastTempAlertDate timeIntervalSinceNow] > 600.0) {
                _lastTempAlertDate = [NSDate date];
                [self speakThai:@"คำเตือน อุณหภูมิระบบไฮบริดสูงกว่าปกติ กรุณาลดการเร่งและเปิดระบบปรับอากาศ"];
            }
        } else {
            self.telemetry.isHighTempWarn = NO;
        }
    }

    // Moving with door open warning
    if (self.telemetry.doorOpen && self.telemetry.speedKmh > 5.0) {
        if (!_lastDoorAlertDate || -[_lastDoorAlertDate timeIntervalSinceNow] > 20.0) {
            _lastDoorAlertDate = [NSDate date];
            [self speakThai:@"คำเตือน ประตูรถปิดไม่สนิท กรุณาตรวจสอบ"];
        }
    }
}

#pragma mark - Periodic Polling & Realistic Demo Simulation

- (void)pollTick {
    _tickCount++;
    if (self.demoMode) {
        [self stepDemoSimulation];
        if ([self.delegate respondsToSelector:@selector(obdEngineDidUpdateTelemetry:)]) {
            [self.delegate obdEngineDidUpdateTelemetry:self.telemetry];
        }
        return;
    }

    if (_state == TRDOBDStateLive && _writeChar) {
        // Fast poll (every 200ms): Speed + Engine RPM
        [self enqueuePID:@"010D" header:@"7DF"];
        [self enqueuePID:@"010C" header:@"7DF"];
        // Medium poll (every 1.0s): Hybrid & HV Battery
        if (_tickCount % 5 == 0) {
            [self enqueuePID:@"21C3" header:@"7E2"];
            [self enqueuePID:@"21CE" header:@"7E3"];
        }
        // Slow poll (every 3.0s): Coolant, Ambient, 12V Aux
        if (_tickCount % 15 == 0) {
            [self enqueuePID:@"0105" header:@"7DF"];
            [self enqueuePID:@"0146" header:@"7DF"];
            [_cmdQueue addObject:@"ATRV"];
        }
        // Extended Comfort & Body poll (every 4.0s): A/C Temp (7C0) + Doors/Locks (750)
        if (_tickCount % 20 == 0) {
            [self enqueuePID:@"2101" header:@"7C0"];
            [self enqueuePID:@"2101" header:@"750"];
        }
        if ([self.delegate respondsToSelector:@selector(obdEngineDidUpdateTelemetry:)]) {
            [self.delegate obdEngineDidUpdateTelemetry:self.telemetry];
        }
    }
}

- (void)stepDemoSimulation {
    double t = _tickCount * 0.20;
    double wave = sin(t * 0.18);
    double spd = MAX(0.0, 48.0 + 38.0 * sin(t * 0.11));
    self.telemetry.speedKmh = spd;
    self.telemetry.gear = (spd < 1.0) ? @"P" : @"D";
    self.telemetry.inReverse = NO;

    if (spd < 38.0 && wave >= -0.2) {
        // Pure EV Mode
        self.telemetry.engineRPM = 0.0;
        self.telemetry.hvPackCurrentA = 18.0 + (spd * 0.45);
        self.telemetry.ecoCoachTip = @"🌿 โหมด EV ล้วน • ประหยัดน้ำมันสูงสุด";
    } else if (wave < -0.35) {
        // Regenerative Braking
        self.telemetry.engineRPM = 0.0;
        self.telemetry.hvPackCurrentA = -28.0 * fabs(wave);
        self.telemetry.ecoCoachTip = @"♻️ กำลังชาร์จไฟกลับเข้าแบต HV จากการชะลอความเร็ว";
    } else {
        // Hybrid Assist
        self.telemetry.engineRPM = 1350.0 + (spd * 12.5);
        self.telemetry.hvPackCurrentA = 9.5 + (wave * 8.0);
        self.telemetry.ecoCoachTip = @"⚡ ไฮบริดทำงานประสานเครื่องยนต์ + มอเตอร์ MG2";
    }

    self.telemetry.mg2RPM = spd * 128.0;
    self.telemetry.mg1RPM = (self.telemetry.engineRPM > 0) ? (self.telemetry.engineRPM * 2.6 - self.telemetry.mg2RPM * 0.28) : (-self.telemetry.mg2RPM * 0.38);
    self.telemetry.hvSOCPercent = MAX(45.0, MIN(78.0, 63.0 - 6.0 * sin(t * 0.05)));

    for (int i = 0; i < TRD_HV_BLOCK_COUNT; i++) {
        double ripple = 0.015 * sin(t * 0.4 + i * 0.7);
        double sag = -self.telemetry.hvPackCurrentA * 0.006;
        [self.telemetry setBlockVoltage:(16.35 + sag + ripple) atIndex:i];
    }
    [self.telemetry recalculateBlockStats];
    self.telemetry.evPowerKw = (self.telemetry.hvPackVoltage * self.telemetry.hvPackCurrentA) / 1000.0;
    self.telemetry.coolantTempC = 86.0 + 1.5 * sin(t * 0.03);
    self.telemetry.inverterTempC = 43.0 + 2.0 * fabs(sin(t * 0.04));
    self.telemetry.aux12Voltage = 14.15 + 0.05 * cos(t * 0.2);
    [self updateDerivedMetrics];
}

@end

#endif /* TRD_OBD2_ENGINE_H */
