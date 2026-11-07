// ============================================================================
// cardash_mini2_arm64.m
// PRIUS TRD SPORTIVO GEN 3 — LUXURY EV SMART COCKPIT (iPad mini 2 / arm64 / iOS 11+)
// Native UIKit + CoreBluetooth (Vgate vLinker MC+ BLE) + CoreLocation GPS + Thai TTS
// Sandbox-safe for standard signed .ipa installation (No Jailbreak / No WebView filter issues)
// ============================================================================

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <QuartzCore/QuartzCore.h>

#import "car_extras.h"
#import "TRDSettingsMenu.h"
#import "TRDOBD2Engine.h"

#pragma mark - 14-Block HV Battery Graph View

@interface TRDHVBlockGraphView : UIView
@property (nonatomic, strong) TRDPriusTelemetry *telemetry;
@end

@implementation TRDHVBlockGraphView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    if (!self.telemetry) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat gap = 4.0;
    CGFloat barW = (w - gap * (TRD_HV_BLOCK_COUNT - 1)) / TRD_HV_BLOCK_COUNT;
    CGFloat maxBarH = h - 28.0;

    for (int i = 0; i < TRD_HV_BLOCK_COUNT; i++) {
        double v = [self.telemetry blockVoltageAtIndex:i];
        // Normal Prius Gen 3 pair voltage range: 14.5V .. 17.5V
        double norm = (v - 14.5) / 3.0;
        norm = MAX(0.10, MIN(1.0, norm));
        CGFloat bh = norm * maxBarH;
        CGFloat x = i * (barW + gap);
        CGFloat y = maxBarH - bh + 12.0;

        // Track background
        [[UIColor colorWithWhite:0.13 alpha:1.0] setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, 12.0, barW, maxBarH) cornerRadius:3.0] fill];

        // Highlight min/max block or normal cyan/green
        UIColor *barColor = [UIColor colorWithRed:0.0 green:0.84 blue:0.98 alpha:0.92];
        if (fabs(v - self.telemetry.hvBlockMinV) < 0.005 && self.telemetry.hvDeltaV > 0.15) {
            barColor = [UIColor colorWithRed:0.98 green:0.55 blue:0.12 alpha:1.0];
        } else if (self.telemetry.evPowerKw < -0.5) {
            barColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.55 alpha:0.95];
        }
        [barColor setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, y, barW, bh) cornerRadius:3.0] fill];

        // Block number label (01..14)
        NSString *num = [NSString stringWithFormat:@"%02d", i + 1];
        NSDictionary *numAttr = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:8.5],
            NSForegroundColorAttributeName: [UIColor colorWithWhite:0.58 alpha:1.0]
        };
        CGSize sz = [num sizeWithAttributes:numAttr];
        [num drawAtPoint:CGPointMake(x + (barW - sz.width) / 2.0, h - 13.0) withAttributes:numAttr];
    }
    CGContextSaveGState(ctx);
    CGContextRestoreGState(ctx);
}
@end

#pragma mark - Hybrid Energy Flow Canvas View

@interface TRDEnergyFlowView : UIView
@property (nonatomic, strong) TRDPriusTelemetry *telemetry;
@property (nonatomic, assign) CGFloat phase;
@end

@implementation TRDEnergyFlowView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    CGPoint icePt   = CGPointMake(w * 0.20, h * 0.52);
    CGPoint mgPt    = CGPointMake(w * 0.50, h * 0.52);
    CGPoint battPt  = CGPointMake(w * 0.80, h * 0.52);

    BOOL iceOn = (self.telemetry.engineRPM > 400.0);
    BOOL regen = (self.telemetry.evPowerKw < -0.5);
    BOOL evDis = (self.telemetry.evPowerKw > 0.4);

    // Draw base connection lines
    CGContextSetLineWidth(c, 3.0);
    [[UIColor colorWithWhite:0.18 alpha:1.0] setStroke];
    CGContextMoveToPoint(c, icePt.x + 36, icePt.y);
    CGContextAddLineToPoint(c, mgPt.x - 38, mgPt.y);
    CGContextMoveToPoint(c, mgPt.x + 38, mgPt.y);
    CGContextAddLineToPoint(c, battPt.x - 36, battPt.y);
    CGContextStrokePath(c);

    // Animated energy pulses
    CGFloat dashLengths[2] = {8.0, 6.0};
    if (iceOn) {
        [[UIColor colorWithRed:0.98 green:0.22 blue:0.20 alpha:0.95] setStroke];
        CGContextSetLineDash(c, -self.phase * 14.0, dashLengths, 2);
        CGContextMoveToPoint(c, icePt.x + 36, icePt.y);
        CGContextAddLineToPoint(c, mgPt.x - 38, mgPt.y);
        CGContextStrokePath(c);
    }
    if (regen || evDis) {
        UIColor *flowColor = regen ? [UIColor colorWithRed:0.0 green:0.92 blue:0.55 alpha:1.0]
                                   : [UIColor colorWithRed:0.0 green:0.82 blue:1.0 alpha:1.0];
        [flowColor setStroke];
        CGFloat dir = regen ? -1.0 : 1.0;
        CGContextSetLineDash(c, dir * self.phase * 14.0, dashLengths, 2);
        CGContextMoveToPoint(c, mgPt.x + 38, mgPt.y);
        CGContextAddLineToPoint(c, battPt.x - 36, battPt.y);
        CGContextStrokePath(c);
    }
    CGContextSetLineDash(c, 0, NULL, 0);

    // Draw Node Pills: ICE, MG1/MG2, HV BATT
    NSArray *titles = @[
        [NSString stringWithFormat:@"ICE %.0f", self.telemetry.engineRPM],
        [NSString stringWithFormat:@"MG2 %.0f", self.telemetry.mg2RPM],
        [NSString stringWithFormat:@"HV %.0f%%", self.telemetry.hvSOCPercent]
    ];
    NSArray *subs = @[@"ENGINE RPM", @"MOTOR / WHEELS", [NSString stringWithFormat:@"%+.1f kW", self.telemetry.evPowerKw]];
    CGPoint pts[3] = {icePt, mgPt, battPt};
    UIColor *colors[3] = {
        iceOn ? [UIColor colorWithRed:0.95 green:0.20 blue:0.22 alpha:1.0] : [UIColor colorWithWhite:0.30 alpha:1.0],
        [UIColor colorWithRed:0.0 green:0.82 blue:1.0 alpha:1.0],
        regen ? [UIColor colorWithRed:0.0 green:0.92 blue:0.55 alpha:1.0] : TRDAccent()
    };

    for (int i = 0; i < 3; i++) {
        CGRect box = CGRectMake(pts[i].x - 42, pts[i].y - 22, 84, 44);
        [[UIColor colorWithRed:0.06 green:0.08 blue:0.12 alpha:0.95] setFill];
        UIBezierPath *bp = [UIBezierPath bezierPathWithRoundedRect:box cornerRadius:10.0];
        [bp fill];
        [colors[i] setStroke];
        bp.lineWidth = 1.6;
        [bp stroke];

        NSDictionary *tAttr = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:12.0], NSForegroundColorAttributeName: [UIColor whiteColor]};
        NSDictionary *sAttr = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:8.5], NSForegroundColorAttributeName: colors[i]};
        CGSize tSz = [titles[i] sizeWithAttributes:tAttr];
        CGSize sSz = [subs[i] sizeWithAttributes:sAttr];
        [titles[i] drawAtPoint:CGPointMake(pts[i].x - tSz.width / 2.0, pts[i].y - 15.0) withAttributes:tAttr];
        [subs[i] drawAtPoint:CGPointMake(pts[i].x - sSz.width / 2.0, pts[i].y + 3.0) withAttributes:sAttr];
    }
}
@end

#pragma mark - Main Cockpit View Controller

@interface TRDMini2CockpitController : UIViewController <CLLocationManagerDelegate, TRDOBD2EngineDelegate, AVAudioPlayerDelegate>
@property (nonatomic, strong) TRDOBD2Engine *obd;
@property (nonatomic, strong) CLLocationManager *gps;
@property (nonatomic, strong) CLLocation *lastFix;
@property (nonatomic, assign) double tripMeters;
@property (nonatomic, assign) NSTimeInterval tripSeconds;
@property (nonatomic, assign) double tripMaxSpeed;
@property (nonatomic, assign) BOOL gpsLive;

// UI Containers
@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UILabel *brandLabel, *clockLabel, *obdBadgeLabel;
@property (nonatomic, strong) UIButton *obdModeBtn, *voiceBtn, *themeBtn, *ipadSettingsTopBtn;

@property (nonatomic, strong) UIView *leftZone, *centerZone, *rightZone, *bottomDock;
@property (nonatomic, strong) NSMutableArray<UIButton *> *gearButtons;
@property (nonatomic, strong) UILabel *speedValueLabel, *speedSourceLabel, *evPowerLabel;
@property (nonatomic, strong) UIProgressView *evPowerBar;
@property (nonatomic, strong) UILabel *coolantVal, *inverterVal, *cabinVal, *aux12Val;

// Center Zone
@property (nonatomic, strong) UIImageView *priusHeroImage;
@property (nonatomic, strong) TRDEnergyFlowView *energyFlowView;
@property (nonatomic, strong) UILabel *flowStateBadge;
@property (nonatomic, strong) UILabel *ecoScoreVal, *regenVal, *ecoTipLabel;
@property (nonatomic, strong) UILabel *tripDistVal, *tripTimeVal, *tripMaxVal, *tripRangeVal;
@property (nonatomic, strong) UILabel *nowPlayingLabel, *audioRouteLabel;

// Right Zone
@property (nonatomic, strong) UILabel *hvSocLabel, *hvPackVLabel, *hvCurrentLabel, *hvDeltaLabel, *hvHealthLabel;
@property (nonatomic, strong) TRDHVBlockGraphView *blockGraphView;
@property (nonatomic, strong) UILabel *mg1Val, *mg2Val, *hvTempVal;

// Overlays & Audio
@property (nonatomic, strong) TRDSettingsMenu *settingsSheet;
@property (nonatomic, strong) CarWelcome *welcomeView;
@property (nonatomic, strong) UIView *tripSummaryOverlay;
@property (nonatomic, strong) UIView *fullClockOverlay;
@property (nonatomic, strong) UILabel *fullClockTime, *fullClockSpeed;
@property (nonatomic, strong) AVAudioPlayer *offlineAudioPlayer;
@property (nonatomic, strong) NSArray<NSString *> *offlineMusicFiles;
@property (nonatomic, assign) NSInteger currentTrackIndex;
@property (nonatomic, strong) NSTimer *uiTimer;
@end

@interface TRDMini2CockpitController ()
- (void)openYouTube;
- (void)openIPadSystemSettings;
- (void)buildTopBar;
- (void)buildLeftZone;
- (void)buildCenterZone;
- (void)buildRightZone;
- (void)buildBottomDock;
- (void)buildFullClockOverlay;
- (void)openSettingsSheet;
- (void)configureAudioAndRemoteControls;
- (void)scanOfflineMusicFolder;
- (void)openOfflineMusicPicker;
- (void)playOfflineTrackAtIndex:(NSInteger)idx;
- (void)tapPlayPauseTrack;
- (void)tapNextTrack;
- (void)tapPrevTrack;
- (void)showWelcomeBanner;
- (void)batteryStateChanged:(NSNotification *)note;
- (void)tapOBDMode;
- (void)tapSpeakSummary;
- (void)cycleTheme;
- (void)tapGearButton:(UIButton *)sender;
- (void)resetTripStats;
- (void)showMainCockpit;
- (void)showFullClock;
- (void)hideFullClock;
- (void)tickUI;
- (void)refreshAllUI;
@end

@implementation TRDMini2CockpitController

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.03 green:0.035 blue:0.05 alpha:1.0];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    TRDTheme = [defs integerForKey:@"TRDTheme"];
    self.tripMeters = [defs doubleForKey:@"TRDMini2TripMeters"];
    self.tripSeconds = [defs doubleForKey:@"TRDMini2TripSeconds"];
    self.tripMaxSpeed = [defs doubleForKey:@"TRDMini2TripMaxSpeed"];

    [self buildTopBar];
    [self buildLeftZone];
    [self buildCenterZone];
    [self buildRightZone];
    [self buildBottomDock];
    [self buildFullClockOverlay];

    // Setup OBD2 BLE Engine (Vgate vLinker MC+)
    self.obd = [[TRDOBD2Engine alloc] init];
    self.obd.delegate = self;
    [self.obd start];

    // Setup Hardware GPS (iPad4,5 Cellular built-in GPS)
    self.gps = [[CLLocationManager alloc] init];
    self.gps.delegate = self;
    self.gps.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    self.gps.distanceFilter = kCLDistanceFilterNone;
    if ([self.gps respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.gps requestWhenInUseAuthorization];
    }
    [self.gps startUpdatingLocation];

    // Setup Battery / Ignition Charger Monitoring
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(batteryStateChanged:)
                                                 name:UIDeviceBatteryStateDidChangeNotification
                                               object:nil];

    // Setup Audio Session & Steering Wheel Controls
    [self configureAudioAndRemoteControls];
    [self scanOfflineMusicFolder];

    [UIApplication sharedApplication].idleTimerDisabled = YES;
    self.uiTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(tickUI) userInfo:nil repeats:YES];
    [self refreshAllUI];
}

#pragma mark - Official iOS Settings Opener (Works on non-jailbroken iOS 11.3!)

- (void)openYouTube {
    NSURL *url = [NSURL URLWithString:@"https://m.youtube.com"];
    UIApplication *app = [UIApplication sharedApplication];
    if (url && [app canOpenURL:url]) {
        if ([app respondsToSelector:@selector(openURL:options:completionHandler:)]) {
            [app openURL:url options:@{} completionHandler:nil];
        } else {
            [app openURL:url];
        }
    }
}

- (void)openIPadSystemSettings {
    if (UIApplicationOpenSettingsURLString != nil) {
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        UIApplication *app = [UIApplication sharedApplication];
        if (url && [app canOpenURL:url]) {
            if ([app respondsToSelector:@selector(openURL:options:completionHandler:)]) {
                [app openURL:url options:@{} completionHandler:nil];
            } else {
                [app openURL:url];
            }
            return;
        }
    }
}

#pragma mark - UI Construction (3-Zone Luxury EV Cockpit for 1024x768)

- (UIView *)makePanelWithFrame:(CGRect)frame {
    UIView *v = [[UIView alloc] initWithFrame:frame];
    v.backgroundColor = [UIColor colorWithRed:0.055 green:0.068 blue:0.095 alpha:0.94];
    v.layer.cornerRadius = 14.0;
    v.layer.borderWidth = 1.2;
    v.layer.borderColor = [UIColor colorWithRed:0.18 green:0.22 blue:0.30 alpha:0.85].CGColor;
    v.clipsToBounds = YES;
    return v;
}

- (UILabel *)makeLabel:(CGRect)frame font:(UIFont *)font color:(UIColor *)color align:(NSTextAlignment)align text:(NSString *)text {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.font = font;
    l.textColor = color;
    l.textAlignment = align;
    l.text = text;
    l.adjustsFontSizeToFitWidth = YES;
    l.minimumScaleFactor = 0.7;
    return l;
}

- (void)buildTopBar {
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1024, 58)];
    self.topBar.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:0.96];
    [self.view addSubview:self.topBar];

    UIView *redAccent = [[UIView alloc] initWithFrame:CGRectMake(18, 55, 84, 3)];
    redAccent.tag = 9001;
    redAccent.backgroundColor = TRDAccent();
    [self.topBar addSubview:redAccent];

    self.brandLabel = [self makeLabel:CGRectMake(18, 8, 290, 26)
                                 font:[UIFont boldSystemFontOfSize:19]
                                color:[UIColor whiteColor]
                                align:NSTextAlignmentLeft
                                 text:@"PRIUS TRD SPORTIVO · GEN 3"];
    [self.topBar addSubview:self.brandLabel];

    UILabel *subBrand = [self makeLabel:CGRectMake(18, 32, 290, 18)
                                   font:[UIFont boldSystemFontOfSize:10]
                                  color:[UIColor colorWithRed:0.0 green:0.82 blue:1.0 alpha:1.0]
                                  align:NSTextAlignmentLeft
                                   text:@"LUXURY EV SMART COCKPIT  •  APPLE A7 ARM64"];
    [self.topBar addSubview:subBrand];

    // OBD Mode Button (Toggle DEMO <-> BLE SCAN)
    self.obdModeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.obdModeBtn.frame = CGRectMake(315, 11, 225, 36);
    self.obdModeBtn.backgroundColor = [UIColor colorWithRed:0.06 green:0.18 blue:0.14 alpha:1.0];
    self.obdModeBtn.layer.cornerRadius = 18.0;
    self.obdModeBtn.layer.borderWidth = 1.2;
    self.obdModeBtn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.90 blue:0.55 alpha:0.85].CGColor;
    self.obdModeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.obdModeBtn setTitle:@"🟢 OBD-II: DEMO (แตะสแกน BLE)" forState:UIControlStateNormal];
    [self.obdModeBtn setTitleColor:[UIColor colorWithRed:0.0 green:0.95 blue:0.65 alpha:1.0] forState:UIControlStateNormal];
    [self.obdModeBtn addTarget:self action:@selector(tapOBDMode) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.obdModeBtn];

    // Clock in Center-Right
    self.clockLabel = [self makeLabel:CGRectMake(550, 10, 155, 38)
                                 font:[UIFont boldSystemFontOfSize:22]
                                color:[UIColor whiteColor]
                                align:NSTextAlignmentCenter
                                 text:@"12:00"];
    [self.topBar addSubview:self.clockLabel];

    // Thai Voice Coach Button
    self.voiceBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.voiceBtn.frame = CGRectMake(715, 11, 96, 36);
    self.voiceBtn.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    self.voiceBtn.layer.cornerRadius = 8.0;
    self.voiceBtn.layer.borderWidth = 1.0;
    self.voiceBtn.layer.borderColor = [UIColor colorWithWhite:0.28 alpha:1.0].CGColor;
    self.voiceBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self.voiceBtn setTitle:@"🔊 เสียงไทย" forState:UIControlStateNormal];
    [self.voiceBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.voiceBtn addTarget:self action:@selector(tapSpeakSummary) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.voiceBtn];

    // Drive Mode Theme Button
    self.themeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.themeBtn.frame = CGRectMake(819, 11, 86, 36);
    self.themeBtn.backgroundColor = [TRDAccent() colorWithAlphaComponent:0.18];
    self.themeBtn.layer.cornerRadius = 8.0;
    self.themeBtn.layer.borderWidth = 1.2;
    self.themeBtn.layer.borderColor = TRDAccent().CGColor;
    self.themeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.themeBtn setTitle:TRDDriveModeName(TRDTheme) forState:UIControlStateNormal];
    [self.themeBtn setTitleColor:TRDAccent() forState:UIControlStateNormal];
    [self.themeBtn addTarget:self action:@selector(cycleTheme) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.themeBtn];

    // Direct Open iPad Settings Button
    self.ipadSettingsTopBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.ipadSettingsTopBtn.frame = CGRectMake(913, 11, 96, 36);
    self.ipadSettingsTopBtn.backgroundColor = [UIColor colorWithRed:0.14 green:0.18 blue:0.26 alpha:1.0];
    self.ipadSettingsTopBtn.layer.cornerRadius = 8.0;
    self.ipadSettingsTopBtn.layer.borderWidth = 1.2;
    self.ipadSettingsTopBtn.layer.borderColor = [UIColor colorWithRed:0.35 green:0.55 blue:0.95 alpha:0.9].CGColor;
    self.ipadSettingsTopBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self.ipadSettingsTopBtn setTitle:@"⚙️ iPad ตั้งค่า" forState:UIControlStateNormal];
    [self.ipadSettingsTopBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.ipadSettingsTopBtn addTarget:self action:@selector(openIPadSystemSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.ipadSettingsTopBtn];
}

- (void)buildLeftZone {
    self.leftZone = [self makePanelWithFrame:CGRectMake(14, 68, 272, 612)];
    [self.view addSubview:self.leftZone];

    UILabel *hdr = [self makeLabel:CGRectMake(16, 12, 240, 18)
                              font:[UIFont boldSystemFontOfSize:11]
                             color:[UIColor colorWithWhite:0.55 alpha:1.0]
                             align:NSTextAlignmentLeft
                              text:@"VEHICLE DYNAMICS • 11.3 CAN"];
    [self.leftZone addSubview:hdr];

    // Gear selector pills P / R / N / D / B (Symmetrical 5 equal pills)
    self.gearButtons = [NSMutableArray array];
    NSArray *gears = @[@"P", @"R", @"N", @"D", @"B"];
    CGFloat gpW = (272.0 - 32.0 - 16.0) / 5.0; // 44.8 pt each
    for (int i = 0; i < 5; i++) {
        UIButton *gb = [UIButton buttonWithType:UIButtonTypeCustom];
        gb.frame = CGRectMake(16 + i * (gpW + 4), 36, gpW, 40);
        gb.layer.cornerRadius = 10.0;
        gb.layer.borderWidth = 1.4;
        gb.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [gb setTitle:gears[i] forState:UIControlStateNormal];
        gb.tag = 500 + i;
        [gb addTarget:self action:@selector(tapGearButton:) forControlEvents:UIControlEventTouchUpInside];
        [self.leftZone addSubview:gb];
        [self.gearButtons addObject:gb];
    }

    // Giant Digital Speedometer Centerpiece
    self.speedValueLabel = [self makeLabel:CGRectMake(12, 88, 248, 114)
                                      font:[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:104] ?: [UIFont boldSystemFontOfSize:98]
                                     color:[UIColor whiteColor]
                                     align:NSTextAlignmentCenter
                                      text:@"0"];
    [self.leftZone addSubview:self.speedValueLabel];

    self.speedSourceLabel = [self makeLabel:CGRectMake(16, 202, 240, 22)
                                       font:[UIFont boldSystemFontOfSize:12]
                                      color:[UIColor colorWithRed:0.0 green:0.82 blue:1.0 alpha:1.0]
                                      align:NSTextAlignmentCenter
                                       text:@"km/h  •  DYNAMICS LIVE"];
    [self.leftZone addSubview:self.speedSourceLabel];

    // EV Power Gauge Bar
    self.evPowerLabel = [self makeLabel:CGRectMake(16, 236, 240, 20)
                                   font:[UIFont boldSystemFontOfSize:12]
                                  color:[UIColor colorWithRed:0.0 green:0.92 blue:0.55 alpha:1.0]
                                  align:NSTextAlignmentLeft
                                   text:@"⚡ EV POWER:  +0.0 kW"];
    [self.leftZone addSubview:self.evPowerLabel];

    self.evPowerBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.evPowerBar.frame = CGRectMake(16, 262, 240, 10);
    self.evPowerBar.trackTintColor = [UIColor colorWithWhite:0.16 alpha:1.0];
    self.evPowerBar.progressTintColor = [UIColor colorWithRed:0.0 green:0.84 blue:1.0 alpha:1.0];
    self.evPowerBar.progress = 0.35;
    [self.leftZone addSubview:self.evPowerBar];

    // EXACT 3 THERMAL CARDS (Height 96pt each, perfectly matching Right Zone 3 Cards!)
    NSArray *tTitles = @[@"🌡️ น้ำหล่อเย็น (Coolant)", @"⚡ อินเวอร์เตอร์ (Inverter)", @"🔋 แบต 12V (Auxiliary)"];
    UILabel * __strong *targets[3] = {&_coolantVal, &_inverterVal, &_aux12Val};
    for (int i = 0; i < 3; i++) {
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(14, 288 + i * 104, 244, 94)];
        card.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
        card.layer.cornerRadius = 12.0;
        card.layer.borderWidth = 1.0;
        card.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1.0].CGColor;
        [self.leftZone addSubview:card];

        UILabel *tl = [self makeLabel:CGRectMake(14, 12, 216, 18)
                                 font:[UIFont boldSystemFontOfSize:11]
                                color:[UIColor colorWithWhite:0.55 alpha:1.0]
                                align:NSTextAlignmentLeft
                                 text:tTitles[i]];
        [card addSubview:tl];

        UILabel *vl = [self makeLabel:CGRectMake(14, 38, 216, 44)
                                 font:[UIFont boldSystemFontOfSize:26]
                                color:[UIColor whiteColor]
                                align:NSTextAlignmentLeft
                                 text:@"--"];
        [card addSubview:vl];
        *(targets[i]) = vl;
    }
}

- (void)buildCenterZone {
    self.centerZone = [self makePanelWithFrame:CGRectMake(300, 68, 424, 612)];
    [self.view addSubview:self.centerZone];

    self.flowStateBadge = [self makeLabel:CGRectMake(16, 12, 420, 26)
                                     font:[UIFont boldSystemFontOfSize:13]
                                    color:[UIColor colorWithRed:0.0 green:0.92 blue:0.55 alpha:1.0]
                                    align:NSTextAlignmentCenter
                                     text:@"🌿 PURE EV DRIVE (MG2 → WHEELS)"];
    self.flowStateBadge.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    self.flowStateBadge.layer.cornerRadius = 8.0;
    self.flowStateBadge.clipsToBounds = YES;
    [self.centerZone addSubview:self.flowStateBadge];

    // Prius Gen 3 TRD Visual
    UIImage *carImg = [UIImage imageNamed:@"PriusGS.png"] ?: [UIImage imageNamed:@"TRDRealPrius.png"];
    self.priusHeroImage = [[UIImageView alloc] initWithFrame:CGRectMake(36, 42, 380, 145)];
    self.priusHeroImage.image = carImg;
    self.priusHeroImage.contentMode = UIViewContentModeScaleAspectFit;
    [self.centerZone addSubview:self.priusHeroImage];

    // Animated Hybrid Energy Flow Diagram
    self.energyFlowView = [[TRDEnergyFlowView alloc] initWithFrame:CGRectMake(12, 186, 428, 72)];
    [self.centerZone addSubview:self.energyFlowView];

    // AI Eco Coach & Regenerative Braking Card
    UIView *ecoCard = [[UIView alloc] initWithFrame:CGRectMake(14, 264, 424, 96)];
    ecoCard.backgroundColor = [UIColor colorWithRed:0.04 green:0.11 blue:0.10 alpha:0.95];
    ecoCard.layer.cornerRadius = 12.0;
    ecoCard.layer.borderWidth = 1.0;
    ecoCard.layer.borderColor = [UIColor colorWithRed:0.0 green:0.80 blue:0.50 alpha:0.45].CGColor;
    [self.centerZone addSubview:ecoCard];

    UILabel *ecoHdr = [self makeLabel:CGRectMake(14, 8, 220, 16)
                                 font:[UIFont boldSystemFontOfSize:10]
                                color:[UIColor colorWithRed:0.0 green:0.90 blue:0.55 alpha:1.0]
                                align:NSTextAlignmentLeft
                                 text:@"🌱 AI ECO COACH & REGEN ANALYSIS"];
    [ecoCard addSubview:ecoHdr];

    self.ecoScoreVal = [self makeLabel:CGRectMake(14, 26, 180, 34)
                                  font:[UIFont boldSystemFontOfSize:26]
                                 color:[UIColor whiteColor]
                                 align:NSTextAlignmentLeft
                                  text:@"ECO 92 / 100"];
    [ecoCard addSubview:self.ecoScoreVal];

    self.regenVal = [self makeLabel:CGRectMake(200, 26, 210, 34)
                               font:[UIFont boldSystemFontOfSize:18]
                              color:[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1.0]
                              align:NSTextAlignmentRight
                               text:@"♻️ REGEN: 0 Wh"];
    [ecoCard addSubview:self.regenVal];

    self.ecoTipLabel = [self makeLabel:CGRectMake(14, 64, 396, 24)
                                  font:[UIFont systemFontOfSize:12]
                                 color:[UIColor colorWithWhite:0.85 alpha:1.0]
                                 align:NSTextAlignmentLeft
                                  text:@"ระบบไฮบริดพร้อมทำงาน"];
    [ecoCard addSubview:self.ecoTipLabel];

    // Trip Computer & Estimated Range Card
    UIView *tripCard = [[UIView alloc] initWithFrame:CGRectMake(14, 370, 424, 112)];
    tripCard.backgroundColor = [UIColor colorWithWhite:0.075 alpha:0.96];
    tripCard.layer.cornerRadius = 12.0;
    tripCard.layer.borderWidth = 1.0;
    tripCard.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1.0].CGColor;
    [self.centerZone addSubview:tripCard];

    UILabel *tripHdr = [self makeLabel:CGRectMake(14, 8, 280, 16)
                                  font:[UIFont boldSystemFontOfSize:10]
                                 color:[UIColor colorWithWhite:0.55 alpha:1.0]
                                 align:NSTextAlignmentLeft
                                  text:@"📍 GPS TRIP COMPUTER & RANGE (EST.)"];
    [tripCard addSubview:tripHdr];

    UIButton *rstBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    rstBtn.frame = CGRectMake(336, 6, 76, 22);
    rstBtn.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    rstBtn.layer.cornerRadius = 5.0;
    rstBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10];
    [rstBtn setTitle:@"RESET TRIP" forState:UIControlStateNormal];
    [rstBtn setTitleColor:TRDAccent() forState:UIControlStateNormal];
    [rstBtn addTarget:self action:@selector(resetTripStats) forControlEvents:UIControlEventTouchUpInside];
    [tripCard addSubview:rstBtn];

    self.tripDistVal  = [self makeLabel:CGRectMake(14, 32, 195, 32) font:[UIFont boldSystemFontOfSize:22] color:[UIColor whiteColor] align:NSTextAlignmentLeft text:@"0.00 km"];
    self.tripTimeVal  = [self makeLabel:CGRectMake(220, 32, 190, 32) font:[UIFont boldSystemFontOfSize:22] color:[UIColor whiteColor] align:NSTextAlignmentLeft text:@"00:00:00"];
    self.tripMaxVal   = [self makeLabel:CGRectMake(14, 70, 195, 28) font:[UIFont boldSystemFontOfSize:14] color:[UIColor lightGrayColor] align:NSTextAlignmentLeft text:@"MAX: 0 km/h"];
    self.tripRangeVal = [self makeLabel:CGRectMake(220, 70, 190, 28) font:[UIFont boldSystemFontOfSize:14] color:[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1.0] align:NSTextAlignmentLeft text:@"RANGE (EST): 540 km"];
    [tripCard addSubview:self.tripDistVal];
    [tripCard addSubview:self.tripTimeVal];
    [tripCard addSubview:self.tripMaxVal];
    [tripCard addSubview:self.tripRangeVal];

    // Offline Music & Bluetooth Audio Bar
    UIView *mediaCard = [[UIView alloc] initWithFrame:CGRectMake(14, 492, 424, 106)];
    mediaCard.backgroundColor = [UIColor colorWithWhite:0.075 alpha:0.96];
    mediaCard.layer.cornerRadius = 12.0;
    mediaCard.layer.borderWidth = 1.0;
    mediaCard.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1.0].CGColor;
    [self.centerZone addSubview:mediaCard];

    self.audioRouteLabel = [self makeLabel:CGRectMake(14, 8, 396, 16)
                                      font:[UIFont boldSystemFontOfSize:10]
                                     color:TRDAccent()
                                     align:NSTextAlignmentLeft
                                      text:@"🎵 CAR MULTIMEDIA BLUETOOTH & OFFLINE PLAYER"];
    [mediaCard addSubview:self.audioRouteLabel];

    self.nowPlayingLabel = [self makeLabel:CGRectMake(14, 26, 396, 26)
                                      font:[UIFont boldSystemFontOfSize:16]
                                     color:[UIColor whiteColor]
                                     align:NSTextAlignmentLeft
                                      text:@"พร้อมเล่นเพลงออฟไลน์ หรือเชื่อมต่อ Bluetooth รถ"];
    [mediaCard addSubview:self.nowPlayingLabel];

    NSArray *mTitles = @[@"⏮ PREV", @"⏯ PLAY / PAUSE", @"⏭ NEXT", @"📂 เพลงในเครื่อง"];
    SEL mSels[4] = {@selector(tapPrevTrack), @selector(tapPlayPauseTrack), @selector(tapNextTrack), @selector(openOfflineMusicPicker)};
    for (int i = 0; i < 4; i++) {
        UIButton *mb = [UIButton buttonWithType:UIButtonTypeCustom];
        mb.frame = CGRectMake(14 + i * 101, 58, 94, 38);
        mb.backgroundColor = [UIColor colorWithWhite:0.13 alpha:1.0];
        mb.layer.cornerRadius = 8.0;
        mb.layer.borderWidth = 1.0;
        mb.layer.borderColor = [TRDAccent() colorWithAlphaComponent:0.45].CGColor;
        mb.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        [mb setTitle:mTitles[i] forState:UIControlStateNormal];
        [mb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [mb addTarget:self action:mSels[i] forControlEvents:UIControlEventTouchUpInside];
        [mediaCard addSubview:mb];
    }
}

- (void)buildRightZone {
    self.rightZone = [self makePanelWithFrame:CGRectMake(738, 68, 272, 612)];
    [self.view addSubview:self.rightZone];

    UILabel *hdr = [self makeLabel:CGRectMake(16, 12, 240, 18)
                              font:[UIFont boldSystemFontOfSize:11]
                             color:[UIColor colorWithWhite:0.55 alpha:1.0]
                             align:NSTextAlignmentLeft
                              text:@"POWERTRAIN & HV • 7E3 ECU"];
    [self.rightZone addSubview:hdr];

    self.hvSocLabel = [self makeLabel:CGRectMake(16, 34, 130, 44)
                                 font:[UIFont boldSystemFontOfSize:36]
                                color:[UIColor colorWithRed:0.0 green:0.92 blue:0.55 alpha:1.0]
                                align:NSTextAlignmentLeft
                                 text:@"64.5%"];
    [self.rightZone addSubview:self.hvSocLabel];

    self.hvPackVLabel = [self makeLabel:CGRectMake(146, 34, 110, 22)
                                   font:[UIFont boldSystemFontOfSize:15]
                                  color:[UIColor whiteColor]
                                  align:NSTextAlignmentRight
                                   text:@"227.4 V"];
    [self.rightZone addSubview:self.hvPackVLabel];

    self.hvCurrentLabel = [self makeLabel:CGRectMake(146, 56, 110, 20)
                                     font:[UIFont boldSystemFontOfSize:13]
                                    color:[UIColor colorWithRed:0.0 green:0.82 blue:1.0 alpha:1.0]
                                    align:NSTextAlignmentRight
                                     text:@"+12.4 A"];
    [self.rightZone addSubview:self.hvCurrentLabel];

    // 14-Block Voltage Bar Graph Container
    UIView *blkBox = [[UIView alloc] initWithFrame:CGRectMake(14, 88, 244, 184)];
    blkBox.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.95];
    blkBox.layer.cornerRadius = 12.0;
    blkBox.layer.borderWidth = 1.0;
    blkBox.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1.0].CGColor;
    [self.rightZone addSubview:blkBox];

    UILabel *blkTitle = [self makeLabel:CGRectMake(12, 8, 220, 16)
                                   font:[UIFont boldSystemFontOfSize:10]
                                  color:[UIColor colorWithWhite:0.60 alpha:1.0]
                                  align:NSTextAlignmentLeft
                                   text:@"14 BLOCKS (28 NiMH MODULES)"];
    [blkBox addSubview:blkTitle];

    self.blockGraphView = [[TRDHVBlockGraphView alloc] initWithFrame:CGRectMake(12, 28, 220, 100)];
    [blkBox addSubview:self.blockGraphView];

    self.hvDeltaLabel = [self makeLabel:CGRectMake(12, 134, 220, 20)
                                   font:[UIFont boldSystemFontOfSize:12]
                                  color:[UIColor whiteColor]
                                  align:NSTextAlignmentLeft
                                   text:@"ΔV: 0.04 V (Min 16.20 / Max 16.24)"];
    [blkBox addSubview:self.hvDeltaLabel];

    self.hvHealthLabel = [self makeLabel:CGRectMake(12, 156, 220, 20)
                                    font:[UIFont boldSystemFontOfSize:12]
                                   color:[UIColor colorWithRed:0.0 green:0.92 blue:0.55 alpha:1.0]
                                   align:NSTextAlignmentLeft
                                    text:@"HEALTH (EST.): 96% • BALANCED"];
    [blkBox addSubview:self.hvHealthLabel];

    // EXACT 3 MOTOR CARDS (Height 94pt each, perfectly matching Left Zone 3 Cards!)
    NSArray *rTitles = @[@"⚙️ มอเตอร์ MG2 (ขับเคลื่อน)", @"⚡ เจนเนอเรเตอร์ MG1", @"🌡️ อุณหภูมิแบตเตอรี่ HV"];
    UILabel * __strong *rTargets[3] = {&_mg2Val, &_mg1Val, &_hvTempVal};
    for (int i = 0; i < 3; i++) {
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(14, 288 + i * 104, 244, 94)];
        card.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
        card.layer.cornerRadius = 12.0;
        card.layer.borderWidth = 1.0;
        card.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1.0].CGColor;
        [self.rightZone addSubview:card];

        UILabel *tl = [self makeLabel:CGRectMake(14, 12, 216, 18)
                                 font:[UIFont boldSystemFontOfSize:11]
                                color:[UIColor colorWithWhite:0.55 alpha:1.0]
                                align:NSTextAlignmentLeft
                                 text:rTitles[i]];
        [card addSubview:tl];

        UILabel *vl = [self makeLabel:CGRectMake(14, 38, 216, 44)
                                 font:[UIFont boldSystemFontOfSize:26]
                                color:[UIColor whiteColor]
                                align:NSTextAlignmentLeft
                                 text:@"--"];
        [card addSubview:vl];
        *(rTargets[i]) = vl;
    }
}

- (void)buildBottomDock {
    self.bottomDock = [[UIView alloc] initWithFrame:CGRectMake(14, 690, 996, 66)];
    self.bottomDock.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:0.96];
    self.bottomDock.layer.cornerRadius = 16.0;
    self.bottomDock.layer.borderWidth = 1.2;
    self.bottomDock.layer.borderColor = [UIColor colorWithWhite:0.20 alpha:1.0].CGColor;
    [self.view addSubview:self.bottomDock];

    NSArray *dockTitles = @[
        @"⚡ EV COCKPIT",
        @"▶️ YOUTUBE",
        @"🎵 OFFLINE MUSIC",
        @"📡 OBD-II BLE",
        @"🔊 THAI COACH",
        @"⚙️ SETTINGS"
    ];
    SEL dockSels[6] = {
        @selector(showMainCockpit),
        @selector(openYouTube),
        @selector(openOfflineMusicPicker),
        @selector(tapOBDMode),
        @selector(tapSpeakSummary),
        @selector(openSettingsSheet)
    };
    CGFloat btnW = (996.0 - 14.0 * 7) / 6.0;
    for (int i = 0; i < 6; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(14 + i * (btnW + 14.0), 9, btnW, 48);
        b.backgroundColor = (i == 4) ? [TRDAccent() colorWithAlphaComponent:0.22] : [UIColor colorWithWhite:0.10 alpha:1.0];
        b.layer.cornerRadius = 11.0;
        b.layer.borderWidth = 1.2;
        b.layer.borderColor = (i == 4) ? TRDAccent().CGColor : [UIColor colorWithWhite:0.22 alpha:1.0].CGColor;
        b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        [b setTitle:dockTitles[i] forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [b addTarget:self action:dockSels[i] forControlEvents:UIControlEventTouchUpInside];
        [self.bottomDock addSubview:b];
    }
}

- (void)buildFullClockOverlay {
    self.fullClockOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1024, 768)];
    self.fullClockOverlay.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.03 alpha:1.0];
    self.fullClockOverlay.hidden = YES;
    [self.view addSubview:self.fullClockOverlay];

    self.fullClockTime = [self makeLabel:CGRectMake(60, 160, 904, 240)
                                    font:[UIFont fontWithName:@"HelveticaNeue-UltraLight" size:210] ?: [UIFont boldSystemFontOfSize:190]
                                   color:[UIColor whiteColor]
                                   align:NSTextAlignmentCenter
                                    text:@"12:00"];
    [self.fullClockOverlay addSubview:self.fullClockTime];

    self.fullClockSpeed = [self makeLabel:CGRectMake(100, 430, 824, 80)
                                     font:[UIFont boldSystemFontOfSize:44]
                                    color:TRDAccent()
                                    align:NSTextAlignmentCenter
                                     text:@"0 km/h  •  PRIUS TRD SPORTIVO"];
    [self.fullClockOverlay addSubview:self.fullClockSpeed];

    UILabel *tapHint = [self makeLabel:CGRectMake(100, 660, 824, 30)
                                  font:[UIFont systemFontOfSize:16]
                                 color:[UIColor grayColor]
                                 align:NSTextAlignmentCenter
                                  text:@"แตะที่ใดก็ได้เพื่อกลับสู่หน้า EV Cockpit"];
    [self.fullClockOverlay addSubview:tapHint];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideFullClock)];
    [self.fullClockOverlay addGestureRecognizer:tap];
}

#pragma mark - Settings Sheet (TRD Settings + iPad System Settings)

- (void)openSettingsSheet {
    [self.settingsSheet dismiss];
    TRDSettingsMenu *m = [TRDSettingsMenu alertControllerWithTitle:@"PRIUS TRD & iPAD SETTINGS"
                                                           message:@"ตั้งค่าระบบแดชบอร์ด, OBD2 BLE, เสียงภาษาไทย หรือสลับไปหน้า Settings ของ iPad"];
    __weak typeof(self) weakSelf = self;
    [m addAction:[TRDSettingAction actionWithTitle:@"⚙️ เปิดหน้า iPad Settings (Wi-Fi / Bluetooth / สิทธิ์แอป)" style:0 handler:^(TRDSettingAction *a) {
        [weakSelf openIPadSystemSettings];
    }]];
    [m addAction:[TRDSettingAction actionWithTitle:self.obd.demoMode ? @"📡 สแกนเชื่อมต่อ Vgate vLinker MC+ (BLE Live)" : @"🧪 สลับกลับโหมดจำลองข้อมูลไฮบริด (DEMO SIM)" style:0 handler:^(TRDSettingAction *a) {
        [weakSelf tapOBDMode];
    }]];
    [m addAction:[TRDSettingAction actionWithTitle:@"🎨 เปลี่ยนโหมดสี SPORT (แดง TRD) / NORMAL (ฟ้า) / ECO (เขียว)" style:0 handler:^(TRDSettingAction *a) {
        [weakSelf cycleTheme];
    }]];
    [m addAction:[TRDSettingAction actionWithTitle:self.obd.thaiVoiceEnabled ? @"🔊 เสียงพูดเตือนภาษาไทย: เปิดอยู่ (แตะเพื่อปิด)" : @"🔇 เสียงพูดเตือนภาษาไทย: ปิดอยู่ (แตะเพื่อเปิด)" style:0 handler:^(TRDSettingAction *a) {
        weakSelf.obd.thaiVoiceEnabled = !weakSelf.obd.thaiVoiceEnabled;
    }]];
    [m addAction:[TRDSettingAction actionWithTitle:@"🌙 พักหน้าจอมืด (Screen Off - ประหยัดไฟขณะจอด)" style:0 handler:^(TRDSettingAction *a) {
        [UIScreen mainScreen].brightness = 0.0;
    }]];
    [m addAction:[TRDSettingAction actionWithTitle:@"👋 ทดสอบหน้าต้อนรับ Welcome PEEPUT" style:0 handler:^(TRDSettingAction *a) {
        [weakSelf showWelcomeBanner];
    }]];
    m.frame = self.view.bounds;
    self.settingsSheet = m;
    [self.view addSubview:m];
}

#pragma mark - Offline Music Player (Sandbox Documents via Finder/iTunes File Sharing)

- (void)configureAudioAndRemoteControls {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:nil];
    [session setActive:YES error:nil];

    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    MPRemoteCommandCenter *rc = [MPRemoteCommandCenter sharedCommandCenter];
    [rc.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [self tapPlayPauseTrack];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [rc.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [self tapPlayPauseTrack];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [rc.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [self tapNextTrack];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [rc.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
        [self tapPrevTrack];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
}

- (void)scanOfflineMusicFolder {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docs error:nil];
    NSMutableArray *tracks = [NSMutableArray array];
    for (NSString *fn in items) {
        NSString *ext = fn.pathExtension.lowercaseString;
        if ([ext isEqualToString:@"mp3"] || [ext isEqualToString:@"m4a"] || [ext isEqualToString:@"wav"] || [ext isEqualToString:@"aac"]) {
            [tracks addObject:[docs stringByAppendingPathComponent:fn]];
        }
    }
    self.offlineMusicFiles = tracks;
}

- (void)openOfflineMusicPicker {
    [self scanOfflineMusicFolder];
    [self.settingsSheet dismiss];
    if (self.offlineMusicFiles.count == 0) {
        TRDSettingsMenu *m = [TRDSettingsMenu alertControllerWithTitle:@"💾 OFFLINE MUSIC (เพลงในเครื่อง)"
                                                               message:@"คุณสามารถลากไฟล์เพลง .mp3 หรือ .m4a จากคอมพิวเตอร์ลงในแอป CarDash ผ่านเมนู File Sharing ใน Finder / iTunes ได้โดยตรง (ไม่ต้องใช้เน็ต)"];
        __weak typeof(self) weakSelf = self;
        [m addAction:[TRDSettingAction actionWithTitle:@"🔄 สแกนโฟลเดอร์เพลงอีกครั้ง" style:0 handler:^(TRDSettingAction *a) {
            [weakSelf openOfflineMusicPicker];
        }]];
        m.frame = self.view.bounds;
        self.settingsSheet = m;
        [self.view addSubview:m];
        return;
    }

    TRDSettingsMenu *m = [TRDSettingsMenu alertControllerWithTitle:@"💾 OFFLINE MUSIC"
                                                           message:[NSString stringWithFormat:@"พบเพลงในเครื่อง %lu เพลง (แตะเพื่อเล่นออกลำโพง/Bluetooth รถ)", (unsigned long)self.offlineMusicFiles.count]];
    __weak typeof(self) weakSelf = self;
    for (NSUInteger i = 0; i < self.offlineMusicFiles.count; i++) {
        NSString *path = self.offlineMusicFiles[i];
        NSString *name = path.lastPathComponent.stringByDeletingPathExtension;
        [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"▶️ %@", name] style:0 handler:^(TRDSettingAction *a) {
            [weakSelf playOfflineTrackAtIndex:i];
        }]];
    }
    m.frame = self.view.bounds;
    self.settingsSheet = m;
    [self.view addSubview:m];
}

- (void)playOfflineTrackAtIndex:(NSInteger)idx {
    if (self.offlineMusicFiles.count == 0) return;
    if (idx < 0) idx = self.offlineMusicFiles.count - 1;
    if (idx >= (NSInteger)self.offlineMusicFiles.count) idx = 0;
    self.currentTrackIndex = idx;
    NSString *path = self.offlineMusicFiles[idx];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *err = nil;
    self.offlineAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    self.offlineAudioPlayer.delegate = self;
    if (!err && [self.offlineAudioPlayer prepareToPlay]) {
        [self.offlineAudioPlayer play];
        NSString *title = path.lastPathComponent.stringByDeletingPathExtension;
        self.nowPlayingLabel.text = [NSString stringWithFormat:@"▶️ %@", title];
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: @"Prius TRD Offline Music"
        };
    }
}

- (void)tapPlayPauseTrack {
    if (!self.offlineAudioPlayer) {
        [self scanOfflineMusicFolder];
        if (self.offlineMusicFiles.count > 0) {
            [self playOfflineTrackAtIndex:0];
        } else {
            [self openOfflineMusicPicker];
        }
        return;
    }
    if (self.offlineAudioPlayer.isPlaying) {
        [self.offlineAudioPlayer pause];
    } else {
        [self.offlineAudioPlayer play];
    }
}

- (void)tapNextTrack {
    if (self.offlineMusicFiles.count > 0) {
        [self playOfflineTrackAtIndex:self.currentTrackIndex + 1];
    }
}

- (void)tapPrevTrack {
    if (self.offlineMusicFiles.count > 0) {
        [self playOfflineTrackAtIndex:self.currentTrackIndex - 1];
    }
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (flag && self.offlineMusicFiles.count > 0) {
        [self playOfflineTrackAtIndex:self.currentTrackIndex + 1];
    }
}

#pragma mark - Ignition Charger Power Automation & Welcome Banner

- (void)showWelcomeBanner {
    [self.welcomeView removeFromSuperview];
    self.welcomeView = [[CarWelcome alloc] init];
    self.welcomeView.frame = self.view.bounds;
    [self.view addSubview:self.welcomeView];
    [self.obd speakThai:@"สวัสดีครับ พร้อมออกเดินทาง"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.35 animations:^{
            self.welcomeView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self.welcomeView removeFromSuperview];
            self.welcomeView = nil;
        }];
    });
}

- (void)batteryStateChanged:(NSNotification *)note {
    UIDeviceBatteryState st = [UIDevice currentDevice].batteryState;
    if (st == UIDeviceBatteryStateCharging || st == UIDeviceBatteryStateFull) {
        [UIScreen mainScreen].brightness = 0.85;
        [self showWelcomeBanner];
    } else if (st == UIDeviceBatteryStateUnplugged) {
        if (self.offlineAudioPlayer.isPlaying) [self.offlineAudioPlayer pause];
        [self.obd speakThai:[NSString stringWithFormat:@"ดับเครื่องยนต์ ระยะทางทริปนี้ %.1f กิโลเมตร", self.tripMeters / 1000.0]];
        // Dim screen after 3 seconds if still unplugged
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([UIDevice currentDevice].batteryState == UIDeviceBatteryStateUnplugged) {
                [UIScreen mainScreen].brightness = 0.02;
            }
        });
    }
}

#pragma mark - User Actions & Delegates

- (void)tapOBDMode {
    [self.obd toggleDemoOrScan];
    [self refreshAllUI];
}

- (void)tapSpeakSummary {
    [self.obd speakEcoSummary];
}

- (void)cycleTheme {
    TRDTheme = (TRDTheme + 1) % 3;
    [[NSUserDefaults standardUserDefaults] setInteger:TRDTheme forKey:@"TRDTheme"];
    [self.themeBtn setTitle:TRDDriveModeName(TRDTheme) forState:UIControlStateNormal];
    [self.themeBtn setTitleColor:TRDAccent() forState:UIControlStateNormal];
    self.themeBtn.layer.borderColor = TRDAccent().CGColor;
    UIView *redAccent = [self.topBar viewWithTag:9001];
    redAccent.backgroundColor = TRDAccent();
    [self refreshAllUI];
}

- (void)tapGearButton:(UIButton *)sender {
    NSArray *gears = @[@"P", @"R", @"N", @"D", @"B"];
    NSInteger idx = sender.tag - 500;
    if (idx >= 0 && idx < 5) {
        self.obd.telemetry.gear = gears[idx];
        self.obd.telemetry.inReverse = (idx == 1);
        if (idx == 1) {
            [self.obd speakThai:@"เข้าเกียร์ถอยหลัง โปรดระวังด้านหลัง"];
        }
        [self refreshAllUI];
    }
}

- (void)resetTripStats {
    self.tripMeters = 0;
    self.tripSeconds = 0;
    self.tripMaxSpeed = 0;
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setDouble:0 forKey:@"TRDMini2TripMeters"];
    [defs setDouble:0 forKey:@"TRDMini2TripSeconds"];
    [defs setDouble:0 forKey:@"TRDMini2TripMaxSpeed"];
    [self refreshAllUI];
}

- (void)showMainCockpit {
    self.fullClockOverlay.hidden = YES;
}

- (void)showFullClock {
    self.fullClockOverlay.hidden = NO;
    [self.view bringSubviewToFront:self.fullClockOverlay];
}

- (void)hideFullClock {
    self.fullClockOverlay.hidden = YES;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *loc = locations.lastObject;
    if (!loc || loc.horizontalAccuracy < 0 || loc.horizontalAccuracy > 65.0) return;
    self.gpsLive = YES;
    if (self.lastFix) {
        CLLocationDistance d = [loc distanceFromLocation:self.lastFix];
        if (d > 1.0 && d < 250.0) {
            self.tripMeters += d;
        }
    }
    self.lastFix = loc;
    if (loc.speed >= 0) {
        double gpsKmh = loc.speed * 3.6;
        if (gpsKmh > self.tripMaxSpeed) self.tripMaxSpeed = gpsKmh;
        if (!self.obd.telemetry.isLiveOBD && !self.obd.demoMode) {
            self.obd.telemetry.speedKmh = gpsKmh;
        }
    }
}

- (void)obdEngineDidChangeState:(TRDOBDConnectionState)state statusText:(NSString *)statusText {
    if (state == TRDOBDStateLive) {
        [self.obdModeBtn setTitle:@"🟢 OBD-II: BLE LIVE" forState:UIControlStateNormal];
    } else if (state == TRDOBDStateScanning || state == TRDOBDStateConnecting) {
        [self.obdModeBtn setTitle:@"🟡 SCANNING vLinker BLE..." forState:UIControlStateNormal];
    } else if (state == TRDOBDStateDemo) {
        [self.obdModeBtn setTitle:@"🟢 OBD-II: DEMO (แตะสแกน BLE)" forState:UIControlStateNormal];
    } else {
        [self.obdModeBtn setTitle:statusText forState:UIControlStateNormal];
    }
}

- (void)obdEngineDidUpdateTelemetry:(TRDPriusTelemetry *)telemetry {
    [self refreshAllUI];
}

- (void)tickUI {
    self.energyFlowView.phase += 0.22;
    if (self.obd.telemetry.speedKmh > 1.0) {
        self.tripSeconds += 0.25;
        if (self.obd.demoMode) {
            self.tripMeters += (self.obd.telemetry.speedKmh / 3.6) * 0.25;
            if (self.obd.telemetry.speedKmh > self.tripMaxSpeed) {
                self.tripMaxSpeed = self.obd.telemetry.speedKmh;
            }
        }
    }
    [self refreshAllUI];
}

- (void)refreshAllUI {
    TRDPriusTelemetry *t = self.obd.telemetry;

    // Clock
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"HH:mm:ss";
    NSString *nowStr = [df stringFromDate:[NSDate date]];
    self.clockLabel.text = nowStr;
    self.fullClockTime.text = [nowStr substringToIndex:5];
    self.fullClockSpeed.text = [NSString stringWithFormat:@"%.0f km/h  •  HV %.0f%%  •  PRIUS TRD", t.speedKmh, t.hvSOCPercent];

    // Gear highlight
    NSArray *gears = @[@"P", @"R", @"N", @"D", @"B"];
    for (int i = 0; i < 5; i++) {
        UIButton *gb = self.gearButtons[i];
        BOOL active = [t.gear isEqualToString:gears[i]];
        UIColor *gc = (i == 1) ? [UIColor colorWithRed:0.98 green:0.18 blue:0.20 alpha:1.0] : TRDAccent();
        gb.backgroundColor = active ? gc : [UIColor colorWithWhite:0.10 alpha:1.0];
        gb.layer.borderColor = active ? [UIColor whiteColor].CGColor : [UIColor colorWithWhite:0.24 alpha:1.0].CGColor;
        [gb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }

    // Speed & EV Power
    self.speedValueLabel.text = [NSString stringWithFormat:@"%.0f", t.speedKmh];
    self.speedSourceLabel.text = t.isLiveOBD ? @"km/h  •  OBD-II CAN LIVE" : (self.gpsLive ? @"km/h  •  GPS HARDWARE LIVE" : @"km/h  •  HYBRID DEMO SIM");
    self.evPowerLabel.text = [NSString stringWithFormat:@"⚡ EV POWER:  %+.1f kW", t.evPowerKw];
    double normKw = (t.evPowerKw + 25.0) / 65.0;
    self.evPowerBar.progress = MAX(0.05, MIN(1.0, normKw));
    self.evPowerBar.progressTintColor = (t.evPowerKw < -0.5)
        ? [UIColor colorWithRed:0.0 green:0.92 blue:0.55 alpha:1.0]
        : [UIColor colorWithRed:0.0 green:0.82 blue:1.0 alpha:1.0];

    // Left Zone Temperatures & 12V (Symmetrical 3 cards matching Right Zone)
    self.coolantVal.text  = [NSString stringWithFormat:@"%.0f °C", t.coolantTempC];
    self.inverterVal.text = [NSString stringWithFormat:@"%.0f °C  (MG %.0f°C)", t.inverterTempC, t.mg2TempC];
    self.aux12Val.text    = [NSString stringWithFormat:@"%.2f V  %@", t.aux12Voltage, (t.aux12Voltage >= 12.2 ? @"• OK" : @"• LOW!")];

    // Center Zone Energy Flow & Eco Coach
    self.flowStateBadge.text = t.energyFlowState;
    self.energyFlowView.telemetry = t;
    [self.energyFlowView setNeedsDisplay];

    self.ecoScoreVal.text = [NSString stringWithFormat:@"ECO %ld / 100", (long)t.ecoScore];
    self.regenVal.text    = [NSString stringWithFormat:@"♻️ REGEN: %.0f Wh", t.regenRecoveredWh];
    self.ecoTipLabel.text = t.ecoCoachTip;

    // Trip stats
    long hrs = (long)self.tripSeconds / 3600;
    long mins = ((long)self.tripSeconds / 60) % 60;
    long secs = (long)self.tripSeconds % 60;
    self.tripDistVal.text  = [NSString stringWithFormat:@"%.2f km", self.tripMeters / 1000.0];
    self.tripTimeVal.text  = [NSString stringWithFormat:@"%02ld:%02ld:%02ld", hrs, mins, secs];
    self.tripMaxVal.text   = [NSString stringWithFormat:@"MAX: %.0f km/h", self.tripMaxSpeed];
    self.tripRangeVal.text = [NSString stringWithFormat:@"RANGE (EST): %.0f km", t.estimatedRangeKm];

    // Audio Route
    AVAudioSessionPortDescription *outPort = [AVAudioSession sharedInstance].currentRoute.outputs.firstObject;
    self.audioRouteLabel.text = [NSString stringWithFormat:@"🎵 AUDIO ROUTE: %@ (%@)",
                                 outPort.portName ?: @"iPad Speaker", outPort.portType ?: @"Built-In"];

    // Right Zone HV Battery & 14 Blocks
    self.hvSocLabel.text     = [NSString stringWithFormat:@"%.1f%%", t.hvSOCPercent];
    self.hvPackVLabel.text   = [NSString stringWithFormat:@"%.1f V", t.hvPackVoltage];
    self.hvCurrentLabel.text = [NSString stringWithFormat:@"%+.1f A", t.hvPackCurrentA];
    self.hvDeltaLabel.text   = [NSString stringWithFormat:@"ΔV: %.2f V (%.2f–%.2fV)", t.hvDeltaV, t.hvBlockMinV, t.hvBlockMaxV];
    self.hvHealthLabel.text  = [NSString stringWithFormat:@"HEALTH (EST.): %.0f%% • %@",
                                t.hvHealthEstimatePct, (t.hvDeltaV <= 0.15 ? @"BALANCED" : @"CHECK PACK")];
    self.blockGraphView.telemetry = t;
    [self.blockGraphView setNeedsDisplay];

    self.mg2Val.text    = [NSString stringWithFormat:@"%.0f RPM", t.mg2RPM];
    self.mg1Val.text    = [NSString stringWithFormat:@"%.0f RPM", t.mg1RPM];
    self.hvTempVal.text = [NSString stringWithFormat:@"%.1f °C", t.hvBattTempMaxC];
}

@end

#pragma mark - Application Delegate & Entry Point

@interface TRDMini2AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation TRDMini2AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[TRDMini2CockpitController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([TRDMini2AppDelegate class]));
    }
}
