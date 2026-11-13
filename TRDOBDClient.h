//
// TRDOBDClient.h - CarDash OBD2 / CAN-Bus Integration Module for Toyota Prius TRD
// Compatible with vLinker MC+ (Bluetooth 4.0 Low Energy / iOS 9 CoreBluetooth)
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreBluetooth/CoreBluetooth.h>

extern NSString * const TRDOBDDataDidUpdateNotification;
extern NSString * const TRDOBDConnectionStateChangedNotification;
extern NSString * const TRDOBDGearChangedNotification;

@interface TRDOBDClient : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate>

+ (instancetype)sharedClient;

// Connection Status
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, copy, readonly) NSString *connectionStatus;
@property (nonatomic, copy, readonly) NSString *connectedDeviceName;
@property (nonatomic, copy, readonly) NSString *lastScanSummary;

// Live Powertrain Metrics
@property (nonatomic, assign, readonly) NSInteger engineRPM;         // 0 - 5500 RPM
@property (nonatomic, assign, readonly) CGFloat coolantTempC;        // Engine Coolant °C
@property (nonatomic, assign, readonly) CGFloat hybridBatterySOC;    // 0.0% - 100.0%
@property (nonatomic, assign, readonly) CGFloat inverterTempC;       // Inverter Coolant °C
@property (nonatomic, assign, readonly) CGFloat auxBatteryVoltage;    // 12V Battery Volts
@property (nonatomic, assign, readonly) CGFloat currentSpeedKmh;     // Speed from Wheel / OBD Sensors
@property (nonatomic, assign, readonly) CGFloat hvPackVoltage;       // 200-245V HV Battery Pack
@property (nonatomic, assign, readonly) CGFloat hvPackCurrent;       // Signed Amps (-200..+200A)
@property (nonatomic, assign, readonly) CGFloat hvDeltaSOC;          // Block SOC imbalance %
@property (nonatomic, assign, readonly) CGFloat hvBatteryTempC;      // HV Battery Avg Temp °C
@property (nonatomic, assign, readonly) CGFloat hvIntakeTempC;       // HV Cooling Intake °C
@property (nonatomic, assign, readonly) NSInteger mg1RPM;            // Generator MG1 RPM
@property (nonatomic, assign, readonly) NSInteger mg2RPM;            // Traction Motor MG2 RPM
@property (nonatomic, assign, readonly) CGFloat mg1TempC;            // MG1 Temp °C
@property (nonatomic, assign, readonly) CGFloat mg2TempC;            // MG2 Temp °C
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *hvBlockVoltages;     // 14 Block Voltages
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *hvBlockResistances;  // 14 Block mOhm
@property (nonatomic, assign, readonly) CGFloat hvBlockMinV;
@property (nonatomic, assign, readonly) CGFloat hvBlockMaxV;
@property (nonatomic, assign, readonly) BOOL parkSwitchEngaged;

// Fuel & Trip Cost Metrics
@property (nonatomic, assign, readonly) CGFloat fuelLevelPercent;     // 0% - 100%
@property (nonatomic, assign, readonly) CGFloat fuelRemainingLiters;  // Liters left in 45L tank
@property (nonatomic, assign, readonly) CGFloat fuelPricePerLiter;    // Baht / Liter (e.g. 39.84)
@property (nonatomic, assign, readonly) CGFloat tripFuelUsedLiters;   // Liters burned this trip
@property (nonatomic, assign, readonly) CGFloat tripFuelCostTHB;      // Baht spent this trip
@property (nonatomic, assign, readonly) CGFloat tripAverageKmPerL;    // km / L for this trip
@property (nonatomic, assign, readonly) CGFloat tripEVDistancePercent;// % driven in EV (0 RPM)
@property (nonatomic, assign, readonly) NSInteger selectedFuelTypeIndex; // 0=G95, 1=G91, 2=E20, 3=Prem95
@property (nonatomic, copy, readonly) NSString *selectedFuelTypeName;  // @"แก๊สโซฮอล์ 95"
@property (nonatomic, copy, readonly) NSString *oilPriceSource;        // @"ปตท. (PTT Station)"
@property (nonatomic, copy, readonly) NSString *oilPriceDate;          // Date of price
@property (nonatomic, assign, readonly) BOOL isLiveOilPriceActive;
@property (nonatomic, strong, readonly) NSDictionary *cachedPrices;

// Body & Door Sensors (Tesla/EV Style)
@property (nonatomic, copy, readonly) NSString *currentGear;          // @"P", @"R", @"N", @"D", @"B"
@property (nonatomic, assign, readonly) BOOL isReverseGear;           // YES when gear == @"R"
@property (nonatomic, assign, readonly) BOOL doorFrontLeftOpen;      // Driver Door
@property (nonatomic, assign, readonly) BOOL doorFrontRightOpen;     // Passenger Door
@property (nonatomic, assign, readonly) BOOL doorRearLeftOpen;       // Rear Left Door
@property (nonatomic, assign, readonly) BOOL doorRearRightOpen;      // Rear Right Door
@property (nonatomic, assign, readonly) BOOL trunkOpen;              // Hatch / Trunk
@property (nonatomic, assign, readonly) BOOL doorSensorsLive;        // YES when CAN 0x620 body frame received
@property (nonatomic, assign, readonly) CGFloat cabinTempC;          // A/C Inside Temp °C
@property (nonatomic, assign, readonly) CGFloat exteriorTempC;       // Outside Ambient Temp °C

// Brake & ABS Metrics (Prius ECB System)
@property (nonatomic, assign, readonly) BOOL brakeFluidNormal;
@property (nonatomic, assign, readonly) BOOL absSystemNormal;
@property (nonatomic, assign, readonly) CGFloat brakeAccumulatorPressureMPa;
@property (nonatomic, assign, readonly) CGFloat regenBrakingPowerKW;

// Controls
- (void)startScanning;
- (void)stopScanning;
- (void)ensureConnectedOrScan;
- (void)forceReconnect;
- (void)setCustomFuelPrice:(CGFloat)price;
- (void)selectFuelTypeIndex:(NSInteger)index;
- (void)fetchLiveOilPrices;
- (void)resetTripFuel;
- (void)toggleTestBrakeWarning;
- (void)simulateHybridBatterySOC:(CGFloat)soc;
- (void)toggleTestReverseGear;
- (void)simulateGear:(NSString *)gear;
- (void)integrateFallbackFuelForDistanceKm:(double)distanceKm speedKmh:(double)kmh dtSeconds:(double)dt;

@end
