const fs = require('fs');

let src = fs.readFileSync('cardash_main.m', 'utf8');

// 1. Fix driveEqBtn and driveExitBtn selectors
src = src.replace(
  '[self.driveEqBtn addTarget:self action:@selector(openSettingsAudio) forControlEvents:UIControlEventTouchUpInside];',
  '[self.driveEqBtn addTarget:self action:@selector(openDriveEQ) forControlEvents:UIControlEventTouchUpInside];'
);
src = src.replace(
  '[self.driveExitBtn addTarget:self action:@selector(toggleDriveMode) forControlEvents:UIControlEventTouchUpInside];',
  '[self.driveExitBtn addTarget:self action:@selector(homePage) forControlEvents:UIControlEventTouchUpInside];'
);

// 2. Wire homeSpeedoDial & driveSpeedoDial speedLimitBadge + tap on homeSpeedoDial + tap on driveShifter
const oldDialsInit = `  self.homeSpeedoDial = [[TRDAnalogSpeedoDial alloc] initWithFrame:CGRectZero];
  self.homeSpeedoDial.driveStyle = NO;
  [self.view addSubview:self.homeSpeedoDial];

  self.driveSpeedoDial = [[TRDAnalogSpeedoDial alloc] initWithFrame:CGRectZero];
  self.driveSpeedoDial.driveStyle = YES;
  self.driveSpeedoDial.hidden = YES;
  [self.view addSubview:self.driveSpeedoDial];

  self.driveShifter = [[TRDVerticalShifterView alloc] initWithFrame:CGRectZero];
  self.driveShifter.hidden = YES;
  [self.view addSubview:self.driveShifter];`;

const newDialsInit = `  self.homeSpeedoDial = [[TRDAnalogSpeedoDial alloc] initWithFrame:CGRectZero];
  self.homeSpeedoDial.driveStyle = NO;
  [self.homeSpeedoDial.speedLimitBadge addTarget:self action:@selector(toggleSpeedLimit) forControlEvents:UIControlEventTouchUpInside];
  [self.homeSpeedoDial addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDrive)]];
  [self.view addSubview:self.homeSpeedoDial];

  self.driveSpeedoDial = [[TRDAnalogSpeedoDial alloc] initWithFrame:CGRectZero];
  self.driveSpeedoDial.driveStyle = YES;
  self.driveSpeedoDial.hidden = YES;
  [self.driveSpeedoDial.speedLimitBadge addTarget:self action:@selector(toggleSpeedLimit) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.driveSpeedoDial];

  self.driveShifter = [[TRDVerticalShifterView alloc] initWithFrame:CGRectZero];
  self.driveShifter.hidden = YES;
  self.driveShifter.userInteractionEnabled = YES;
  [self.driveShifter addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(driveShifterTapped:)]];
  [self.view addSubview:self.driveShifter];`;

if (src.includes(oldDialsInit)) {
  src = src.replace(oldDialsInit, newDialsInit);
  console.log('Wired speedLimitBadge, homeSpeedoDial tap, and driveShifter tap!');
}

// 3. Add driveShifterTapped: method right after gearButtonTapped:
if (!src.includes('-(void)driveShifterTapped:(UITapGestureRecognizer *)tap')) {
  src = src.replace(
    '-(void)gearButtonTapped:(UIButton *)btn{',
    `-(void)driveShifterTapped:(UITapGestureRecognizer *)tap{
  CGPoint pt = [tap locationInView:self.driveShifter];
  CGFloat h = self.driveShifter.bounds.size.height;
  if(h <= 8) return;
  NSInteger idx = (NSInteger)((pt.y - 4.0) / ((h - 8.0) / 5.0));
  if(idx < 0) idx = 0;
  if(idx > 4) idx = 4;
  if(idx < self.gearButtons.count){
    [self gearButtonTapped:self.gearButtons[idx]];
  }
}
-(void)gearButtonTapped:(UIButton *)btn{`
  );
  console.log('Added driveShifterTapped: handler!');
}

// 4. Update toggleSpeedLimit to also update homeSpeedoDial & driveSpeedoDial speedLimitBadge
const oldToggleSpeedLimit = `-(void)toggleSpeedLimit{
 if(self.speedLimit==90)self.speedLimit=120;
 else if(self.speedLimit==120)self.speedLimit=0;
 else self.speedLimit=90;
 [self.speedLimitBtn setTitle:self.speedLimit>0?[NSString stringWithFormat:@"%ld",(long)self.speedLimit]:@"OFF" forState:UIControlStateNormal];
 self.speedLimitBtn.layer.borderColor=(self.speedLimit>0?[UIColor colorWithRed:.95 green:.10 blue:.15 alpha:.9]:[UIColor colorWithWhite:.4 alpha:.6]).CGColor;
 [self refreshSpeed];
}`;

const newToggleSpeedLimit = `-(void)toggleSpeedLimit{
 if(self.speedLimit==90)self.speedLimit=120;
 else if(self.speedLimit==120)self.speedLimit=0;
 else self.speedLimit=90;
 NSString *limStr = self.speedLimit>0?[NSString stringWithFormat:@"%ld",(long)self.speedLimit]:@"OFF";
 CGColorRef limCol = (self.speedLimit>0?[UIColor colorWithRed:.95 green:.10 blue:.15 alpha:.9]:[UIColor colorWithWhite:.4 alpha:.6]).CGColor;
 [self.speedLimitBtn setTitle:limStr forState:UIControlStateNormal];
 self.speedLimitBtn.layer.borderColor=limCol;
 [self.homeSpeedoDial.speedLimitBadge setTitle:limStr forState:UIControlStateNormal];
 self.homeSpeedoDial.speedLimitBadge.layer.borderColor=limCol;
 [self.driveSpeedoDial.speedLimitBadge setTitle:limStr forState:UIControlStateNormal];
 self.driveSpeedoDial.speedLimitBadge.layer.borderColor=limCol;
 [self refreshSpeed];
}`;

if (src.includes(oldToggleSpeedLimit)) {
  src = src.replace(oldToggleSpeedLimit, newToggleSpeedLimit);
  console.log('Updated toggleSpeedLimit for both speedo dials!');
}

// 5. Ensure homePage, openCarPlay, openMap, toggleDrive dismiss welcome & tripSummaryCard cleanly
src = src.replace(
  '-(void)toggleDrive{self.tripMode=NO;self.mapMode=NO;',
  '-(void)toggleDrive{if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}self.tripMode=NO;self.mapMode=NO;self.carplayMode=NO;self.carplayGridMode=NO;'
);
src = src.replace(
  '-(void)openCarPlay{notify_post("com.codex.trd.network.internet");',
  '-(void)openCarPlay{if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}notify_post("com.codex.trd.network.internet");'
);
src = src.replace(
  '-(void)homePage{notify_post("com.codex.trd.network.internet");[self.settingsSheet dismiss];',
  '-(void)homePage{if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}notify_post("com.codex.trd.network.internet");[self.settingsSheet dismiss];'
);
src = src.replace(
  '-(void)openMap{self.tripMode=NO;',
  '-(void)openMap{if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}self.tripMode=NO;'
);

fs.writeFileSync('cardash_main.m', src, 'utf8');
fs.writeFileSync('car_dash_live_main.m', src, 'utf8');
console.log('Successfully applied all selector & interactive fixes to cardash_main.m and car_dash_live_main.m!');
