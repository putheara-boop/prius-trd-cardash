const fs = require('fs');

console.log("Reading cardash_main.m...");
let src = fs.readFileSync('cardash_main.m', 'utf8');

// 1. Define custom CarPlay widget classes
const carplayWidgetClasses = `
// ============================================================================
// APPLE CARPLAY MASTERPIECE WIDGETS FOR IPAD MINI (iOS 9.3.6 Compatible)
// ============================================================================

@interface TRDCarPlayMediaWidget : UIView
@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UILabel *artPlaceholder;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UILabel *sourceBadge;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UILabel *timeCurLabel, *timeTotalLabel;
@property (nonatomic, strong) UIButton *btnPrev, *btnPlay, *btnNext;
@property (nonatomic, strong) UIButton *btnEQ, *btnRadio;
@end

@implementation TRDCarPlayMediaWidget
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor colorWithRed:.06 green:.08 blue:.12 alpha:.96];
    self.layer.cornerRadius = 20;
    self.layer.borderWidth = 1.2;
    self.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.clipsToBounds = YES;

    // Header label
    UILabel *head = [[UILabel alloc] initWithFrame:CGRectMake(20, 12, 200, 16)];
    head.font = [UIFont boldSystemFontOfSize:11];
    head.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    head.text = @"\\U0001F3B5 NOW PLAYING \\u2022 CARPLAY";
    [self addSubview:head];

    // Source badge
    self.sourceBadge = [[UILabel alloc] initWithFrame:CGRectMake(230, 10, 120, 20)];
    self.sourceBadge.font = [UIFont boldSystemFontOfSize:10];
    self.sourceBadge.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.sourceBadge.textAlignment = NSTextAlignmentRight;
    self.sourceBadge.text = @"audioNINJA";
    [self addSubview:self.sourceBadge];

    // Album Artwork
    self.artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 36, 100, 100)];
    self.artworkView.contentMode = UIViewContentModeScaleAspectFill;
    self.artworkView.layer.cornerRadius = 14;
    self.artworkView.layer.borderWidth = 1.0;
    self.artworkView.layer.borderColor = [UIColor colorWithWhite:.25 alpha:1].CGColor;
    self.artworkView.clipsToBounds = YES;
    [self addSubview:self.artworkView];

    self.artPlaceholder = [[UILabel alloc] initWithFrame:self.artworkView.frame];
    self.artPlaceholder.font = [UIFont systemFontOfSize:40];
    self.artPlaceholder.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.8];
    self.artPlaceholder.textAlignment = NSTextAlignmentCenter;
    self.artPlaceholder.backgroundColor = [UIColor colorWithRed:.04 green:.06 blue:.09 alpha:.9];
    self.artPlaceholder.layer.cornerRadius = 14;
    self.artPlaceholder.clipsToBounds = YES;
    self.artPlaceholder.text = @"\\u266b";
    [self addSubview:self.artPlaceholder];

    // Song Title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(132, 40, 220, 52)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.text = @"\\u0e2a\\u0e31\\u0e0d\\u0e0d\\u0e32\\u0e25\\u0e21\\u0e1b\\u0e32\\u0e01 (Part Time)";
    [self addSubview:self.titleLabel];

    // Artist
    self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(132, 94, 220, 22)];
    self.artistLabel.font = [UIFont systemFontOfSize:13];
    self.artistLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1];
    self.artistLabel.text = @"\\u0e01\\u0e2d\\u0e25\\u0e4c\\u0e1f \\u0e40\\u0e1a\\u0e0d\\u0e08\\u0e1e\\u0e25";
    [self addSubview:self.artistLabel];

    // Progress bar
    self.progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressBar.frame = CGRectMake(20, 150, 334, 4);
    self.progressBar.progressTintColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.progressBar.trackTintColor = [UIColor colorWithWhite:0.18 alpha:1];
    self.progressBar.progress = 0.35;
    [self addSubview:self.progressBar];

    // Time labels
    self.timeCurLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 158, 100, 16)];
    self.timeCurLabel.font = [UIFont boldSystemFontOfSize:10.5];
    self.timeCurLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    self.timeCurLabel.text = @"0:19";
    [self addSubview:self.timeCurLabel];

    self.timeTotalLabel = [[UILabel alloc] initWithFrame:CGRectMake(254, 158, 100, 16)];
    self.timeTotalLabel.font = [UIFont boldSystemFontOfSize:10.5];
    self.timeTotalLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    self.timeTotalLabel.textAlignment = NSTextAlignmentRight;
    self.timeTotalLabel.text = @"3:20";
    [self addSubview:self.timeTotalLabel];

    // Transport buttons (Prev, Play, Next)
    self.btnPrev = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPrev.frame = CGRectMake(20, 184, 86, 52);
    self.btnPrev.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
    self.btnPrev.layer.cornerRadius = 12;
    self.btnPrev.layer.borderWidth = 1.0;
    self.btnPrev.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    [self.btnPrev setTitle:@"\\u23ee" forState:UIControlStateNormal];
    self.btnPrev.titleLabel.font = [UIFont systemFontOfSize:24];
    [self addSubview:self.btnPrev];

    self.btnPlay = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPlay.frame = CGRectMake(118, 184, 138, 52);
    self.btnPlay.backgroundColor = [UIColor colorWithRed:.0 green:.72 blue:.40 alpha:1];
    self.btnPlay.layer.cornerRadius = 12;
    self.btnPlay.layer.borderWidth = 1.2;
    self.btnPlay.layer.borderColor = [UIColor colorWithRed:.2 green:.9 blue:.5 alpha:1].CGColor;
    [self.btnPlay setTitle:@"\\u275a\\u275a" forState:UIControlStateNormal];
    self.btnPlay.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.btnPlay setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self addSubview:self.btnPlay];

    self.btnNext = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnNext.frame = CGRectMake(268, 184, 86, 52);
    self.btnNext.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
    self.btnNext.layer.cornerRadius = 12;
    self.btnNext.layer.borderWidth = 1.0;
    self.btnNext.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    [self.btnNext setTitle:@"\\u23ed" forState:UIControlStateNormal];
    self.btnNext.titleLabel.font = [UIFont systemFontOfSize:24];
    [self addSubview:self.btnNext];

    // Quick Audio buttons
    self.btnEQ = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnEQ.frame = CGRectMake(20, 250, 160, 44);
    self.btnEQ.backgroundColor = [UIColor colorWithRed:.03 green:.10 blue:.16 alpha:.9];
    self.btnEQ.layer.cornerRadius = 10;
    self.btnEQ.layer.borderWidth = 1.0;
    self.btnEQ.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.4].CGColor;
    [self.btnEQ setTitle:@"\\U0001F39B\\U0000FE0F JBL EQUALIZER" forState:UIControlStateNormal];
    self.btnEQ.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self.btnEQ setTitleColor:[UIColor colorWithRed:0 green:.9 blue:1 alpha:1] forState:UIControlStateNormal];
    [self addSubview:self.btnEQ];

    self.btnRadio = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnRadio.frame = CGRectMake(194, 250, 160, 44);
    self.btnRadio.backgroundColor = [UIColor colorWithRed:.06 green:.08 blue:.12 alpha:.9];
    self.btnRadio.layer.cornerRadius = 10;
    self.btnRadio.layer.borderWidth = 1.0;
    self.btnRadio.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    [self.btnRadio setTitle:@"\\U0001F4FB THAI RADIO" forState:UIControlStateNormal];
    self.btnRadio.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self.btnRadio setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self addSubview:self.btnRadio];
  }
  return self;
}
@end

@interface TRDCarPlayTelemetryWidget : UIView
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) UILabel *speedUnitLabel;
@property (nonatomic, strong) UIButton *speedLimitBadge;
@property (nonatomic, strong) UILabel *compassLabel;
@property (nonatomic, strong) UILabel *batteryHeaderLabel;
@property (nonatomic, strong) UIView *batteryBarTrack;
@property (nonatomic, strong) UIView *batteryBarFill;
@property (nonatomic, strong) UILabel *batteryStatusLabel;
@property (nonatomic, strong) UILabel *thermalsRowLabel;
@property (nonatomic, strong) UILabel *tripMetricsLabel;
@property (nonatomic, strong) UIButton *rearCamBtn;
@property (nonatomic, strong) UIButton *exitBtn;
@end

@implementation TRDCarPlayTelemetryWidget
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor colorWithRed:.06 green:.08 blue:.12 alpha:.96];
    self.layer.cornerRadius = 20;
    self.layer.borderWidth = 1.2;
    self.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.clipsToBounds = YES;

    // Header
    UILabel *head = [[UILabel alloc] initWithFrame:CGRectMake(20, 12, 334, 16)];
    head.font = [UIFont boldSystemFontOfSize:11];
    head.textColor = [UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];
    head.text = @"\\U0001F6E1\\U0000FE0F PRIUS DYNAMICS \\u2022 SAFETY ASSIST";
    [self addSubview:head];

    // Digital Speed Display
    self.speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 32, 120, 60)];
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:62] ?: [UIFont boldSystemFontOfSize:62];
    self.speedLabel.textColor = [UIColor whiteColor];
    self.speedLabel.text = @"0";
    [self addSubview:self.speedLabel];

    self.speedUnitLabel = [[UILabel alloc] initWithFrame:CGRectMake(144, 44, 140, 20)];
    self.speedUnitLabel.font = [UIFont boldSystemFontOfSize:13];
    self.speedUnitLabel.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.speedUnitLabel.text = @"km/h \\u2022 GPS LIVE";
    [self addSubview:self.speedUnitLabel];

    self.compassLabel = [[UILabel alloc] initWithFrame:CGRectMake(144, 66, 130, 22)];
    self.compassLabel.font = [UIFont boldSystemFontOfSize:10.5];
    self.compassLabel.textColor = [UIColor colorWithWhite:.8 alpha:1];
    self.compassLabel.backgroundColor = [UIColor colorWithWhite:.15 alpha:1];
    self.compassLabel.layer.cornerRadius = 6;
    self.compassLabel.clipsToBounds = YES;
    self.compassLabel.textAlignment = NSTextAlignmentCenter;
    self.compassLabel.text = @"\\U0001F9ED N 018\\u00b0 \\u2022 3D LOCK";
    [self addSubview:self.compassLabel];

    self.speedLimitBadge = [UIButton buttonWithType:UIButtonTypeCustom];
    self.speedLimitBadge.frame = CGRectMake(314, 40, 36, 36);
    self.speedLimitBadge.backgroundColor = [UIColor colorWithRed:.85 green:.05 blue:.10 alpha:.18];
    self.speedLimitBadge.layer.cornerRadius = 18;
    self.speedLimitBadge.layer.borderWidth = 2.5;
    self.speedLimitBadge.layer.borderColor = [UIColor colorWithRed:.95 green:.10 blue:.15 alpha:.9].CGColor;
    [self.speedLimitBadge setTitle:@"90" forState:UIControlStateNormal];
    [self.speedLimitBadge setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.speedLimitBadge.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self addSubview:self.speedLimitBadge];

    // Hybrid Battery Section
    self.batteryHeaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 102, 220, 16)];
    self.batteryHeaderLabel.font = [UIFont boldSystemFontOfSize:10.5];
    self.batteryHeaderLabel.textColor = [UIColor colorWithWhite:.6 alpha:1];
    self.batteryHeaderLabel.text = @"HYBRID BATTERY TRACTION";
    [self addSubview:self.batteryHeaderLabel];

    self.batteryStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(230, 100, 124, 18)];
    self.batteryStatusLabel.font = [UIFont boldSystemFontOfSize:12];
    self.batteryStatusLabel.textColor = [UIColor colorWithRed:.2 green:.95 blue:.5 alpha:1];
    self.batteryStatusLabel.textAlignment = NSTextAlignmentRight;
    self.batteryStatusLabel.text = @"76% (EV READY)";
    [self addSubview:self.batteryStatusLabel];

    self.batteryBarTrack = [[UIView alloc] initWithFrame:CGRectMake(20, 122, 334, 12)];
    self.batteryBarTrack.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
    self.batteryBarTrack.layer.cornerRadius = 6;
    self.batteryBarTrack.clipsToBounds = YES;
    [self addSubview:self.batteryBarTrack];

    self.batteryBarFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 334 * 0.76, 12)];
    self.batteryBarFill.backgroundColor = [UIColor colorWithRed:.0 green:.85 blue:.45 alpha:1];
    [self.batteryBarTrack addSubview:self.batteryBarFill];

    // Thermals row
    self.thermalsRowLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 142, 334, 22)];
    self.thermalsRowLabel.font = [UIFont boldSystemFontOfSize:10.5];
    self.thermalsRowLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    self.thermalsRowLabel.text = @"\\U0001F321\\U0000FE0F Coolant: 88\\u00b0C  \\u2022  \\u2744\\U0000FE0F A/C: 24.5\\u00b0C  \\u2022  \\U0001F50B 12V: 13.8V";
    [self addSubview:self.thermalsRowLabel];

    // Trip Metrics
    self.tripMetricsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 172, 334, 48)];
    self.tripMetricsLabel.numberOfLines = 2;
    self.tripMetricsLabel.font = [UIFont boldSystemFontOfSize:11.5];
    self.tripMetricsLabel.textColor = [UIColor whiteColor];
    self.tripMetricsLabel.text = @"\\U0001F4CD \\u0e23\\u0e30\\u0e22\\u0e30\\u0e17\\u0e32\\u0e07\\u0e17\\u0e23\\u0e34\\u0e1b: 24.6 km  \\u2022  \\u0e2d\\u0e31\\u0e15\\u0e23\\u0e32\\u0e2a\\u0e34\\u0e49\\u0e19\\u0e40\\u0e1b\\u0e25\\u0e37\\u0e2d\\u0e07: 24.2 km/L\\n\\u0e04\\u0e48\\u0e32\\u0e19\\u0e49\\u0e33\\u0e21\\u0e31\\u0e19 (GSH95): \\u0e3f 38.50  \\u2022  \\u0e27\\u0e34\\u0e48\\u0e07\\u0e15\\u0e48\\u0e2d\\u0e44\\u0e14\\u0e49: ~520 km";
    [self addSubview:self.tripMetricsLabel];

    // Rear Camera Button
    self.rearCamBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.rearCamBtn.frame = CGRectMake(20, 230, 334, 54);
    self.rearCamBtn.backgroundColor = [UIColor colorWithRed:.05 green:.16 blue:.22 alpha:.9];
    self.rearCamBtn.layer.cornerRadius = 14;
    self.rearCamBtn.layer.borderWidth = 1.5;
    self.rearCamBtn.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.6].CGColor;
    [self.rearCamBtn setTitle:@"\\U0001F4F7  REAR / BLIND SPOT CAMERA" forState:UIControlStateNormal];
    self.rearCamBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.rearCamBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self addSubview:self.rearCamBtn];

    // Return to Cockpit Button
    self.exitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.exitBtn.frame = CGRectMake(20, 294, 334, 46);
    self.exitBtn.backgroundColor = [UIColor colorWithRed:.14 green:.06 blue:.08 alpha:.9];
    self.exitBtn.layer.cornerRadius = 12;
    self.exitBtn.layer.borderWidth = 1.0;
    self.exitBtn.layer.borderColor = [UIColor colorWithRed:1 green:.3 blue:.3 alpha:.4].CGColor;
    [self.exitBtn setTitle:@"\\U0001F3E0  RETURN TO COCKPIT" forState:UIControlStateNormal];
    self.exitBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.exitBtn setTitleColor:[UIColor colorWithRed:1 green:.8 blue:.8 alpha:1] forState:UIControlStateNormal];
    [self addSubview:self.exitBtn];
  }
  return self;
}
@end
`;

// Insert custom classes before @interface Dashboard
src = src.replace('@interface Dashboard:UIViewController', carplayWidgetClasses + "\n@interface Dashboard:UIViewController");

// Add properties
const cpProps = `
@property (nonatomic, strong) TRDCarPlayMediaWidget *carplayMediaWidget;
@property (nonatomic, strong) TRDCarPlayTelemetryWidget *carplayTelemetryWidget;
`;
src = src.replace('@interface Dashboard:UIViewController<CLLocationManagerDelegate,UIGestureRecognizerDelegate,UIWebViewDelegate>',
  '@interface Dashboard:UIViewController<CLLocationManagerDelegate,UIGestureRecognizerDelegate,UIWebViewDelegate>' + cpProps);

// Allocate in viewDidLoad
const cpInit = `
  self.carplayMediaWidget = [[TRDCarPlayMediaWidget alloc] initWithFrame:CGRectZero];
  self.carplayMediaWidget.hidden = YES;
  [self.carplayMediaWidget.btnPrev addTarget:self action:@selector(miniPrev) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayMediaWidget.btnPlay addTarget:self action:@selector(miniPlay) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayMediaWidget.btnNext addTarget:self action:@selector(miniNext) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayMediaWidget.btnEQ addTarget:self action:@selector(openSettingsAudio) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayMediaWidget.btnRadio addTarget:self action:@selector(openRadioStationsMenu) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.carplayMediaWidget];

  self.carplayTelemetryWidget = [[TRDCarPlayTelemetryWidget alloc] initWithFrame:CGRectZero];
  self.carplayTelemetryWidget.hidden = YES;
  [self.carplayTelemetryWidget.rearCamBtn addTarget:self action:@selector(openCamera) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayTelemetryWidget.exitBtn addTarget:self action:@selector(homePage) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.carplayTelemetryWidget];
`;
src = src.replace('[self.view addSubview:self.carplayAppGrid];', '[self.view addSubview:self.carplayAppGrid];\n' + cpInit);

// Update refreshSpeed for CarPlay widget
const speedHook = `  if (self.carplayTelemetryWidget) {
    self.carplayTelemetryWidget.speedLabel.text = [NSString stringWithFormat:@"%.0f", spd];
  }`;
src = src.replace('self.drivePowerMeter.powerRatio = MIN(1.0, MAX(-1.0, (spd - 40.0) / 40.0));',
  'self.drivePowerMeter.powerRatio = MIN(1.0, MAX(-1.0, (spd - 40.0) / 40.0));\n' + speedHook);

// Update refreshNowPlaying for CarPlay widget
const mediaHook = `  if (self.carplayMediaWidget) {
    self.carplayMediaWidget.titleLabel.text = self.song.text.length ? self.song.text : @"Select Music";
    self.carplayMediaWidget.artistLabel.text = self.artist.text.length ? self.artist.text : @"audioNINJA / YouTube";
    self.carplayMediaWidget.artworkView.image = self.artwork.image;
    self.carplayMediaWidget.artPlaceholder.hidden = (self.artwork.image != nil);
    self.carplayMediaWidget.progressBar.progress = self.trackProgress.progress;
    self.carplayMediaWidget.timeCurLabel.text = self.trackTime.text;
  }`;
src = src.replace('[self refreshCarStatus];', '[self refreshCarStatus];\n' + mediaHook);

// Update viewDidLayoutSubviews for CarPlay mode
const oldCpBlock = `    if (self.carplayGridMode) {
      self.mapContainer.hidden = YES; self.controls.hidden = YES; self.artwork.hidden = YES;
      self.artPlaceholder.hidden = YES; self.song.hidden = YES; self.artist.hidden = YES;
      self.trackTime.hidden = YES; self.trackProgress.hidden = YES; self.sourceBadge.hidden = YES;
      self.carplayAppGrid.frame = CGRectMake(80, 0, w - 80, fullH);
    } else {
      CGFloat mapW = (w - 96) * 0.57;
      self.mapContainer.hidden = NO; self.mapContainer.frame = CGRectMake(90, 12, mapW, fullH - 24);
      if (self.mapWebView) self.mapWebView.frame = self.mapContainer.bounds;
      self.carplayTurnBanner.frame = CGRectMake(10, 10, mapW - 20, 54);

      CGFloat rx = 90 + mapW + 12, rw = w - rx - 12;
      CGFloat mediaH = (fullH - 36) * 0.53;
      self.carplayMediaCard.frame = CGRectMake(rx, 12, rw, mediaH);
      self.artwork.hidden = NO; self.artwork.frame = CGRectMake(rx + 16, 22, 96, 96);
      self.artist.hidden = NO; self.song.hidden = NO;
      self.trackProgress.hidden = NO; self.trackTime.hidden = NO;
      self.controls.hidden = NO; self.controls.frame = CGRectMake(rx + 16, mediaH - 64, rw - 32, 60);

      CGFloat telY = 12 + mediaH + 12, telH = fullH - 24 - mediaH - 12;
      self.carplayTelemetryCard.frame = CGRectMake(rx, telY, rw, telH);

      [self.view bringSubviewToFront:self.mapContainer];
      [self.view bringSubviewToFront:self.carplayMediaCard];
      [self.view bringSubviewToFront:self.carplayTelemetryCard];
      [self.view bringSubviewToFront:self.artwork];
      [self.view bringSubviewToFront:self.song];
      [self.view bringSubviewToFront:self.artist];
      [self.view bringSubviewToFront:self.trackProgress];
      [self.view bringSubviewToFront:self.trackTime];
      [self.view bringSubviewToFront:self.controls];
    }
    [self.view bringSubviewToFront:self.carplayDock];
    if (self.settingsSheet) {
      self.settingsSheet.frame = self.view.bounds;
      [self.view bringSubviewToFront:self.settingsSheet];
    }
    return;
  }`;

const newCpBlock = `    // Hide raw legacy media controls from self.view to avoid stray overlays
    self.artwork.hidden = YES;
    self.artPlaceholder.hidden = YES;
    self.song.hidden = YES;
    self.artist.hidden = YES;
    self.trackTime.hidden = YES;
    self.trackProgress.hidden = YES;
    self.controls.hidden = YES;
    self.carplayMediaCard.hidden = YES;
    self.carplayTelemetryCard.hidden = YES;

    // Left Dock (Width: 76)
    self.carplayDock.hidden = NO;
    self.carplayDock.frame = CGRectMake(0, 0, 76, fullH);
    self.carplayHomeBtn.frame = CGRectMake(13, 14, 50, 50);
    for (int i = 0; i < self.carplayDockButtons.count; i++) {
      UIView *db = self.carplayDockButtons[i];
      db.frame = CGRectMake(13, 76 + i * 58, 50, 50);
    }
    self.carplayClock.frame = CGRectMake(4, fullH - 74, 68, 20);
    self.carplayBattery.frame = CGRectMake(4, fullH - 52, 68, 18);
    self.carplayWifi.frame = CGRectMake(6, fullH - 32, 64, 18);

    if (self.carplayGridMode) {
      self.mapContainer.hidden = YES;
      self.carplayMediaWidget.hidden = YES;
      self.carplayTelemetryWidget.hidden = YES;
      self.carplayAppGrid.hidden = NO;
      self.carplayAppGrid.frame = CGRectMake(76, 0, w - 76, fullH);
      [self.view bringSubviewToFront:self.carplayAppGrid];
    } else {
      self.carplayAppGrid.hidden = YES;

      // Section A: Interactive Map (Width: 546, X: 86, Y: 10, Height: 748)
      CGFloat mapW = 546;
      self.mapContainer.hidden = NO;
      self.mapContainer.frame = CGRectMake(86, 10, mapW, fullH - 20);
      self.mapContainer.layer.cornerRadius = 20;
      self.mapContainer.layer.borderWidth = 1.2;
      self.mapContainer.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
      self.mapContainer.clipsToBounds = YES;
      if (self.mapWebView) self.mapWebView.frame = self.mapContainer.bounds;
      self.carplayTurnBanner.frame = CGRectMake(12, 12, mapW - 24, 54);

      // Section B: Right Stack (Width: 376, X: 642, Y: 10)
      CGFloat rx = 642, rw = w - rx - 12; // 370px
      CGFloat cardH = (fullH - 30) / 2.0;  // ~369px

      // Top Widget: Media Player Card
      self.carplayMediaWidget.hidden = NO;
      self.carplayMediaWidget.frame = CGRectMake(rx, 10, rw, cardH);

      // Bottom Widget: Telemetry & Safety Assistant Card
      self.carplayTelemetryWidget.hidden = NO;
      self.carplayTelemetryWidget.frame = CGRectMake(rx, 10 + cardH + 10, rw, cardH);

      [self.view bringSubviewToFront:self.mapContainer];
      [self.view bringSubviewToFront:self.carplayMediaWidget];
      [self.view bringSubviewToFront:self.carplayTelemetryWidget];
    }
    [self.view bringSubviewToFront:self.carplayDock];
    if (self.settingsSheet) {
      self.settingsSheet.frame = self.view.bounds;
      [self.view bringSubviewToFront:self.settingsSheet];
    }
    return;
  }`;

src = src.replace(oldCpBlock, newCpBlock);

// Hide carplay widgets in Home and Drive modes
src = src.replace('self.carplayAppGrid.hidden = YES;\n    self.navigation.hidden = YES;\n    self.nowPanel.hidden = NO;',
  'self.carplayAppGrid.hidden = YES;\n    self.carplayMediaWidget.hidden = YES;\n    self.carplayTelemetryWidget.hidden = YES;\n    self.navigation.hidden = YES;\n    self.nowPanel.hidden = NO;');

src = src.replace('self.carplayAppGrid.hidden = YES;\n    self.clock.hidden = YES;\n    self.date.hidden = YES;',
  'self.carplayAppGrid.hidden = YES;\n    self.carplayMediaWidget.hidden = YES;\n    self.carplayTelemetryWidget.hidden = YES;\n    self.clock.hidden = YES;\n    self.date.hidden = YES;');

console.log("Writing updated files...");
fs.writeFileSync('cardash_main.m', src, 'utf8');
fs.writeFileSync('car_dash_live_main.m', src, 'utf8');
console.log("Done building CarPlay Masterpiece!");
