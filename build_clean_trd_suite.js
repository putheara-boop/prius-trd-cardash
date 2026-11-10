const fs = require('fs');

let code = fs.readFileSync('cardash_main.m', 'utf8');

console.log('Restored code length:', code.length);

// 1. Add TRD14BlockGraphView definition before @interface Dashboard
const graphViewDef = `
@interface TRD14BlockGraphView : UIView
@property (nonatomic, copy) NSArray *voltages;
@end
@implementation TRD14BlockGraphView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor colorWithRed:.01 green:.03 blue:.05 alpha:0.95];
    self.layer.cornerRadius = 6;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1].CGColor;
    self.clipsToBounds = YES;
  }
  return self;
}
- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  NSInteger count = 14;
  CGFloat gap = 2.0;
  CGFloat barW = (w - 8 - (count - 1) * gap) / count;
  CGFloat baselineY = h - 5.0;
  
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.25 alpha:1].CGColor);
  CGContextSetLineWidth(ctx, 1.0);
  CGContextMoveToPoint(ctx, 4, baselineY);
  CGContextAddLineToPoint(ctx, w - 4, baselineY);
  CGContextStrokePath(ctx);
  
  for (NSInteger i = 0; i < count; i++) {
    CGFloat x = 4 + i * (barW + gap);
    CGFloat barH = 18.0;
    if (self.voltages && i < self.voltages.count) {
      double v = [self.voltages[i] doubleValue];
      barH = 8.0 + (v - 15.5) * 14.0;
      if (barH < 4.0) barH = 4.0;
      if (barH > baselineY - 4.0) barH = baselineY - 4.0;
    }
    CGFloat y = baselineY - barH;
    CGRect barRect = CGRectMake(x, y, barW, barH);
    
    UIColor *fillColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:0.85];
    [fillColor setFill];
    UIRectFill(barRect);
    
    [[UIColor colorWithRed:0.35 green:1.0 blue:0.80 alpha:1] setFill];
    UIRectFill(CGRectMake(x, y, barW, 2));
  }
}
@end
`;

code = code.replace('@interface Dashboard:UIViewController', graphViewDef + '\n@interface Dashboard:UIViewController');

// 2. Add properties to @interface Dashboard
const propDef = `
@property (nonatomic, strong) UILabel *topClockLabel;
@property (nonatomic, strong) UIButton *obdStatusPill, *dayNightPill, *thaiVoicePill, *settingsPill;
@property (nonatomic, strong) UIView *readyPill, *gearBadge;
@property (nonatomic, strong) NSMutableArray *gearButtons, *driveModePills;
@property (nonatomic, strong) TRD14BlockGraphView *blockGraphView;
@property (nonatomic, strong) UIView *frontMotorBox, *rearBatteryBox, *flowBeamLine;
-(void)gearButtonTapped:(UIButton *)btn;
-(void)driveModePillTapped:(UIButton *)btn;
`;

code = code.replace('@property NSString *audioOutput,*audioOutputShort,*audioDevice;', propDef + '\n@property NSString *audioOutput,*audioOutputShort,*audioDevice;');

// 3. Update TRDHybridEcoBar
const ecoBarDef = `
@interface TRDHybridEcoBar:UIView
@property UILabel *evPowerLabel;
@property UILabel *evPowerRangeLabel;
@property UIView *track;
@property UIView *fillBar;
@property double throttleRatio;
-(void)updateWithSpeed:(double)speed isBraking:(BOOL)isBraking isAccelerating:(BOOL)isAccel;
@end

@implementation TRDHybridEcoBar
-(instancetype)init{
  if((self=[super init])){
    self.backgroundColor=[UIColor clearColor];
    self.evPowerLabel=[[UILabel alloc]init];
    self.evPowerLabel.font=[UIFont boldSystemFontOfSize:10.5];
    self.evPowerLabel.textColor=[UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1];
    self.evPowerLabel.text=@"⚡ EV POWER: +0.0 kW";
    [self addSubview:self.evPowerLabel];
    
    self.evPowerRangeLabel=[[UILabel alloc]init];
    self.evPowerRangeLabel.font=[UIFont boldSystemFontOfSize:9.0];
    self.evPowerRangeLabel.textAlignment=NSTextAlignmentRight;
    self.evPowerRangeLabel.textColor=[UIColor colorWithWhite:0.60 alpha:1];
    self.evPowerRangeLabel.text=@"CHG | ECO | PWR";
    [self addSubview:self.evPowerRangeLabel];
    
    self.track=[[UIView alloc]init];
    self.track.backgroundColor=[UIColor colorWithWhite:0.12 alpha:1];
    self.track.layer.cornerRadius=3.5;
    self.track.clipsToBounds=YES;
    [self addSubview:self.track];
    
    self.fillBar=[[UIView alloc]init];
    self.fillBar.backgroundColor=[UIColor colorWithRed:0.0 green:0.85 blue:0.95 alpha:1];
    self.fillBar.layer.cornerRadius=3.5;
    [self.track addSubview:self.fillBar];
  }
  return self;
}
-(void)layoutSubviews{
  [super layoutSubviews];
  CGFloat w=self.bounds.size.width;
  self.evPowerLabel.frame=CGRectMake(0,0,w-105,16);
  self.evPowerRangeLabel.frame=CGRectMake(w-100,0,100,16);
  self.track.frame=CGRectMake(0,18,w,6);
  CGFloat fillW=MAX(6,w*(0.25+self.throttleRatio*0.5));
  self.fillBar.frame=CGRectMake(0,0,MIN(w,fillW),6);
}
-(void)updateWithSpeed:(double)speed isBraking:(BOOL)isBraking isAccelerating:(BOOL)isAccel{
  if(isBraking){
    self.throttleRatio=-0.25;
    self.evPowerLabel.text=@"⚡ EV REGEN: -14.2 kW";
    self.evPowerLabel.textColor=[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1];
    self.fillBar.backgroundColor=[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1];
  }else if(speed<=0){
    self.throttleRatio=0.0;
    self.evPowerLabel.text=@"⚡ EV POWER: +0.0 kW";
    self.evPowerLabel.textColor=[UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1];
    self.fillBar.backgroundColor=[UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1];
  }else if(isAccel||speed>85){
    self.throttleRatio=0.65;
    self.evPowerLabel.text=[NSString stringWithFormat:@"🔥 PWR BOOST: +%.1f kW", 15.0+speed*0.3];
    self.evPowerLabel.textColor=[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1];
    self.fillBar.backgroundColor=[UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:1];
  }else{
    self.throttleRatio=0.25;
    self.evPowerLabel.text=[NSString stringWithFormat:@"🍃 EV CRUISE: +%.1f kW", 2.0+speed*0.1];
    self.evPowerLabel.textColor=[UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1];
    self.fillBar.backgroundColor=[UIColor colorWithRed:0.0 green:0.85 blue:0.95 alpha:1];
  }
  [UIView animateWithDuration:0.2 animations:^{
    [self layoutSubviews];
  }];
}
@end
`;

const ecoBarRegex = /@interface TRDHybridEcoBar:UIView[\s\S]*?@end\s*@implementation TRDHybridEcoBar[\s\S]*?@end/;
code = code.replace(ecoBarRegex, ecoBarDef.trim());

// 4. Implement gear and drive mode action handlers inside Dashboard implementation
const helperActions = `
-(void)gearButtonTapped:(UIButton *)btn{
  NSInteger idx = btn.tag - 810;
  NSArray *names = @[@"P", @"R", @"N", @"D", @"B"];
  if(idx >= 0 && idx < names.count){
    NSString *g = names[idx];
    [[TRDOBDClient sharedClient] simulateGear:g];
    UILabel *l = (UILabel *)[self.gearBadge viewWithTag:801];if(l)l.text=g;
    UILabel *w = (UILabel *)[self.gearBadge viewWithTag:802];
    if(w){
      if([g isEqualToString:@"P"]) w.text=@"PARK";
      else if([g isEqualToString:@"R"]) w.text=@"REVERSE";
      else if([g isEqualToString:@"N"]) w.text=@"NEUTRAL";
      else if([g isEqualToString:@"D"]) w.text=@"DRIVE";
      else if([g isEqualToString:@"B"]) w.text=@"ENGINE BRAKE";
    }
    for(int i=0; i<self.gearButtons.count; i++){
      UIButton *b = self.gearButtons[i];
      if(i == idx){
        b.backgroundColor = [UIColor colorWithRed:.05 green:.40 blue:.20 alpha:1];
        b.layer.borderColor = [UIColor colorWithRed:.25 green:.85 blue:.45 alpha:1].CGColor;
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
      }else{
        b.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
        b.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
        [b setTitleColor:[UIColor colorWithWhite:.60 alpha:1] forState:UIControlStateNormal];
      }
    }
  }
}
-(void)driveModePillTapped:(UIButton *)btn{
  NSInteger idx = btn.tag - 820;
  if(idx == 0){ [self setThemeNumber:@(2)]; }
  else if(idx == 1){ [self setThemeNumber:@(2)]; }
  else if(idx == 2){ [self setThemeNumber:@(0)]; }
  for(int i=0; i<self.driveModePills.count; i++){
    UIButton *b = self.driveModePills[i];
    if(i == idx){
      b.backgroundColor = (idx==2)?[UIColor colorWithRed:.3 green:.05 blue:.08 alpha:1]:[UIColor colorWithRed:.03 green:.14 blue:.08 alpha:.9];
      b.layer.borderColor = (idx==2)?[UIColor colorWithRed:1 green:.2 blue:.2 alpha:1].CGColor:[UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.8].CGColor;
      [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }else{
      b.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
      b.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
      [b setTitleColor:[UIColor colorWithWhite:.65 alpha:1] forState:UIControlStateNormal];
    }
  }
}
`;

code = code.replace('@implementation Dashboard\n#import "CarExtrasMethods.h"', '@implementation Dashboard\n' + helperActions + '\n#import "CarExtrasMethods.h"');

// 5. In viewDidLoad, instantiate all widgets
const initWidgets = `
  self.topClockLabel = [UILabel new];
  self.topClockLabel.font = [UIFont boldSystemFontOfSize:17];
  self.topClockLabel.textColor = [UIColor whiteColor];
  self.topClockLabel.textAlignment = NSTextAlignmentCenter;
  self.topClockLabel.text = @"00:00";
  [self.view addSubview:self.topClockLabel];

  self.obdStatusPill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.obdStatusPill.backgroundColor = [UIColor colorWithRed:.03 green:.12 blue:.07 alpha:.9];
  self.obdStatusPill.layer.cornerRadius = 6;
  self.obdStatusPill.layer.borderWidth = 1.0;
  self.obdStatusPill.layer.borderColor = [UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.5].CGColor;
  [self.obdStatusPill setTitle:@"● OBD-II: DEMO SIM" forState:UIControlStateNormal];
  [self.obdStatusPill setTitleColor:[UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1] forState:UIControlStateNormal];
  self.obdStatusPill.titleLabel.font = [UIFont boldSystemFontOfSize:11];
  [self.obdStatusPill addTarget:self action:@selector(openFuelPriceSettings) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.obdStatusPill];

  self.dayNightPill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.dayNightPill.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
  self.dayNightPill.layer.cornerRadius = 6;
  self.dayNightPill.layer.borderWidth = 1.0;
  self.dayNightPill.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
  [self.dayNightPill setTitle:self.nightMode?@"🌙 กลางคืน":@"☀️ กลางวัน" forState:UIControlStateNormal];
  [self.dayNightPill setTitleColor:[UIColor colorWithRed:1.0 green:.82 blue:.25 alpha:1] forState:UIControlStateNormal];
  self.dayNightPill.titleLabel.font = [UIFont boldSystemFontOfSize:11];
  [self.dayNightPill addTarget:self action:@selector(toggleNight) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.dayNightPill];

  self.thaiVoicePill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.thaiVoicePill.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
  self.thaiVoicePill.layer.cornerRadius = 6;
  self.thaiVoicePill.layer.borderWidth = 1.0;
  self.thaiVoicePill.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
  [self.thaiVoicePill setTitle:@"🔊 เสียงไทย" forState:UIControlStateNormal];
  [self.thaiVoicePill setTitleColor:[UIColor colorWithRed:0 green:.85 blue:1 alpha:1] forState:UIControlStateNormal];
  self.thaiVoicePill.titleLabel.font = [UIFont boldSystemFontOfSize:11];
  [self.thaiVoicePill addTarget:self action:@selector(voiceLanguageSettings) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.thaiVoicePill];

  self.settingsPill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.settingsPill.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
  self.settingsPill.layer.cornerRadius = 6;
  self.settingsPill.layer.borderWidth = 1.0;
  self.settingsPill.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
  [self.settingsPill setTitle:@"⚙️ iPad ตั้งค่า" forState:UIControlStateNormal];
  [self.settingsPill setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  self.settingsPill.titleLabel.font = [UIFont boldSystemFontOfSize:11];
  [self.settingsPill addTarget:self action:@selector(carSettings) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.settingsPill];

  self.readyPill = [[UIView alloc]init];
  self.readyPill.backgroundColor = [UIColor colorWithRed:.02 green:.08 blue:.05 alpha:.92];
  self.readyPill.layer.cornerRadius = 6;
  self.readyPill.layer.borderWidth = 1.0;
  self.readyPill.layer.borderColor = [UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.45].CGColor;
  UILabel *rpL = [[UILabel alloc]initWithFrame:CGRectMake(0,0,130,22)];
  rpL.font = [UIFont boldSystemFontOfSize:11];
  rpL.textColor = [UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];
  rpL.textAlignment = NSTextAlignmentCenter;
  rpL.text = @"◀◀  ● READY  ▶▶";
  [self.readyPill addSubview:rpL];
  [self.view addSubview:self.readyPill];

  self.gearBadge = [[UIView alloc]init];
  self.gearBadge.backgroundColor = [UIColor colorWithRed:.03 green:.14 blue:.08 alpha:.9];
  self.gearBadge.layer.cornerRadius = 6;
  self.gearBadge.layer.borderWidth = 1.0;
  self.gearBadge.layer.borderColor = [UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.6].CGColor;
  UILabel *gLetter = [[UILabel alloc]initWithFrame:CGRectMake(6,2,16,20)];
  gLetter.tag = 801;
  gLetter.font = [UIFont boldSystemFontOfSize:16];
  gLetter.textColor = [UIColor whiteColor];
  gLetter.text = @"D";
  [self.gearBadge addSubview:gLetter];
  UILabel *gWord = [[UILabel alloc]initWithFrame:CGRectMake(24,5,44,14)];
  gWord.tag = 802;
  gWord.font = [UIFont boldSystemFontOfSize:9.5];
  gWord.textColor = [UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];
  gWord.text = @"DRIVE";
  [self.gearBadge addSubview:gWord];
  [self.view addSubview:self.gearBadge];

  self.gearButtons = [NSMutableArray array];
  NSArray *gNames = @[@"P", @"R", @"N", @"D", @"B"];
  for(int i=0; i<5; i++){
    UIButton *gb = [UIButton buttonWithType:UIButtonTypeCustom];
    gb.tag = 810 + i;
    [gb setTitle:gNames[i] forState:UIControlStateNormal];
    gb.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    gb.layer.cornerRadius = 6;
    gb.layer.borderWidth = 1.0;
    if(i == 3){
      gb.backgroundColor = [UIColor colorWithRed:.05 green:.40 blue:.20 alpha:1];
      gb.layer.borderColor = [UIColor colorWithRed:.25 green:.85 blue:.45 alpha:1].CGColor;
      [gb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
      gb.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
      gb.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
      [gb setTitleColor:[UIColor colorWithWhite:.60 alpha:1] forState:UIControlStateNormal];
    }
    [gb addTarget:self action:@selector(gearButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.gearButtons addObject:gb];
    [self.view addSubview:gb];
  }

  self.driveModePills = [NSMutableArray array];
  NSArray *mNames = @[@"EV MODE", @"ECO MODE", @"PWR MODE"];
  for(int i=0; i<3; i++){
    UIButton *mb = [UIButton buttonWithType:UIButtonTypeCustom];
    mb.tag = 820 + i;
    [mb setTitle:mNames[i] forState:UIControlStateNormal];
    mb.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    mb.layer.cornerRadius = 6;
    mb.layer.borderWidth = 1.0;
    if(i == 1){
      mb.backgroundColor = [UIColor colorWithRed:.03 green:.14 blue:.08 alpha:.9];
      mb.layer.borderColor = [UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.8].CGColor;
      [mb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
      mb.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
      mb.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
      [mb setTitleColor:[UIColor colorWithWhite:.65 alpha:1] forState:UIControlStateNormal];
    }
    [mb addTarget:self action:@selector(driveModePillTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.driveModePills addObject:mb];
    [self.view addSubview:mb];
  }

  self.frontMotorBox = [[UIView alloc]init];
  self.frontMotorBox.backgroundColor = [UIColor colorWithRed:.02 green:.06 blue:.09 alpha:.9];
  self.frontMotorBox.layer.cornerRadius = 6;
  self.frontMotorBox.layer.borderWidth = 1.0;
  self.frontMotorBox.layer.borderColor = [UIColor colorWithRed:0 green:.75 blue:.85 alpha:.4].CGColor;
  UILabel *fmL1 = [[UILabel alloc]initWithFrame:CGRectMake(6,2,140,12)];fmL1.font=[UIFont boldSystemFontOfSize:8.5];fmL1.textColor=[UIColor colorWithWhite:.6 alpha:1];fmL1.text=@"หน้ารถ (Front Transaxle)";[self.frontMotorBox addSubview:fmL1];
  UILabel *fmL2 = [[UILabel alloc]initWithFrame:CGRectMake(6,14,140,16)];fmL2.font=[UIFont boldSystemFontOfSize:10.5];fmL2.textColor=[UIColor colorWithRed:0 green:.85 blue:1 alpha:1];fmL2.text=@"⚡ MOTOR MG1 / MG2";[self.frontMotorBox addSubview:fmL2];
  [self.view addSubview:self.frontMotorBox];

  self.rearBatteryBox = [[UIView alloc]init];
  self.rearBatteryBox.backgroundColor = [UIColor colorWithRed:.02 green:.08 blue:.05 alpha:.9];
  self.rearBatteryBox.layer.cornerRadius = 6;
  self.rearBatteryBox.layer.borderWidth = 1.0;
  self.rearBatteryBox.layer.borderColor = [UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.4].CGColor;
  UILabel *rbL1 = [[UILabel alloc]initWithFrame:CGRectMake(6,2,140,12)];rbL1.font=[UIFont boldSystemFontOfSize:8.5];rbL1.textColor=[UIColor colorWithWhite:.6 alpha:1];rbL1.textAlignment=NSTextAlignmentRight;rbL1.text=@"ท้ายรถ (Rear Battery)";[self.rearBatteryBox addSubview:rbL1];
  UILabel *rbL2 = [[UILabel alloc]initWithFrame:CGRectMake(6,14,140,16)];rbL2.font=[UIFont boldSystemFontOfSize:10.5];rbL2.textColor=[UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];rbL2.textAlignment=NSTextAlignmentRight;rbL2.text=@"HV BATTERY PACK 🔋";[self.rearBatteryBox addSubview:rbL2];
  [self.view addSubview:self.rearBatteryBox];

  self.flowBeamLine = [[UIView alloc]init];
  self.flowBeamLine.backgroundColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.3];
  self.flowBeamLine.layer.cornerRadius = 2;
  UIView *fDot = [[UIView alloc]initWithFrame:CGRectMake(0,-3,8,8)];fDot.backgroundColor=[UIColor colorWithRed:0 green:.85 blue:1 alpha:1];fDot.layer.cornerRadius=4;[self.flowBeamLine addSubview:fDot];
  UIView *rDot = [[UIView alloc]initWithFrame:CGRectMake(0,-4,10,10)];rDot.tag=831;rDot.backgroundColor=[UIColor colorWithRed:.35 green:.95 blue:.50 alpha:1];rDot.layer.cornerRadius=5;rDot.layer.borderWidth=1.5;rDot.layer.borderColor=[UIColor whiteColor].CGColor;[self.flowBeamLine addSubview:rDot];
  [self.view addSubview:self.flowBeamLine];

  self.blockGraphView = [[TRD14BlockGraphView alloc]initWithFrame:CGRectZero];
  self.blockGraphView.voltages = @[@16.23,@16.24,@16.23,@16.24,@16.22,@16.23,@16.24,@16.23,@16.22,@16.24,@16.23,@16.22,@16.24,@16.23];
  [self.view addSubview:self.blockGraphView];
`;

code = code.replace('[self.view addSubview:self.hybridEcoBar];', '[self.view addSubview:self.hybridEcoBar];\n' + initWidgets);

// 6. Update Heading & Owner text
code = code.replace('self.heading.text=[NSString stringWithFormat:@"PRIUS  TRD  /  %@",TRDDriveModeName(TRDTheme)];self.heading.font=[UIFont boldSystemFontOfSize:18];self.owner=[self label:10 color:[UIColor colorWithWhite:.55 alpha:1]];self.owner.text=@"PEEPUT’S DRIVE";',
'self.heading.text=@"PRIUS TRD SPORTIVO";self.heading.font=[UIFont boldSystemFontOfSize:16];self.owner=[self label:10.5 color:[UIColor colorWithRed:0 green:.85 blue:1 alpha:1]];self.owner.text=@"LUXURY EV SMART COCKPIT • FULLSCREEN KIOSK READY";');

// 7. Speed string: Never use em-dash or '--'
code = code.replace('NSString *newSpeed=valid?[NSString stringWithFormat:@"%.0f",self.fix.speed*3.6]:@"—";',
'NSString *newSpeed=valid?[NSString stringWithFormat:@"%.0f",MAX(0,self.fix.speed*3.6)]:@"0";');
code = code.replace('NSString *newSpeed=valid?[NSString stringWithFormat:@"%.0f",self.fix.speed*3.6]:@"--";',
'NSString *newSpeed=valid?[NSString stringWithFormat:@"%.0f",MAX(0,self.fix.speed*3.6)]:@"0";');

// 8. Update in update method: Ensure top clock and pills update
const updatePills = `
  if(self.topClockLabel && !self.topClockLabel.hidden){
    self.topClockLabel.text = [self.clockFormat stringFromDate:[NSDate date]];
  }
  if(self.obdStatusPill && !self.obdStatusPill.hidden){
    BOOL live = [TRDOBDClient sharedClient].isConnected;
    [self.obdStatusPill setTitle:live?@"● OBD-II: LIVE":@"● OBD-II: DEMO SIM" forState:UIControlStateNormal];
  }
  if(self.dayNightPill && !self.dayNightPill.hidden){
    [self.dayNightPill setTitle:self.nightMode?@"🌙 กลางคืน":@"☀️ กลางวัน" forState:UIControlStateNormal];
  }
`;

code = code.replace('-(void)update{', '-(void)update{\n' + updatePills);

// 9. Replace layoutSubviews 3-zone layout with precision coordinates
const target3ZoneRegex = /\/\/ 3-ZONE BALANCED EXECUTIVE COCKPIT LAYOUT[\s\S]*?for\(int i=0;i<6;i\)\(\(UIButton \*\)self\.cards\[i\]\)\.hidden=YES;\s*\}/;

const new3ZoneLayout = `// 3-ZONE BALANCED EXECUTIVE COCKPIT LAYOUT (Matching Target Reference)
    CGFloat w=self.view.bounds.size.width;
    CGFloat colH=628, topY=62;
    CGFloat leftW=252, centerW=472, rightW=252;
    CGFloat leftX=14, centerX=276, rightX=758;

    // TOP BAR
    CGFloat barY = 12;
    self.heading.hidden = NO;
    self.heading.frame = CGRectMake(16, barY, 320, 22);
    self.owner.hidden = NO;
    self.owner.frame = CGRectMake(16, barY + 22, 380, 16);
    self.nightButton.hidden = YES;
    self.statusStrip.hidden = YES;
    
    CGFloat curRx = w - 16;
    CGFloat pillH = 32;
    
    curRx -= 104;
    self.settingsPill.hidden = NO;
    self.settingsPill.frame = CGRectMake(curRx, barY + 4, 104, pillH);
    
    curRx -= 96;
    self.thaiVoicePill.hidden = NO;
    self.thaiVoicePill.frame = CGRectMake(curRx, barY + 4, 88, pillH);
    
    curRx -= 66;
    self.topClockLabel.hidden = NO;
    self.topClockLabel.frame = CGRectMake(curRx, barY + 4, 60, pillH);
    
    curRx -= 90;
    self.dayNightPill.hidden = NO;
    self.dayNightPill.frame = CGRectMake(curRx, barY + 4, 84, pillH);
    
    curRx -= 144;
    self.obdStatusPill.hidden = NO;
    self.obdStatusPill.frame = CGRectMake(curRx, barY + 4, 138, pillH);

    // 1. LEFT ZONE
    self.driveLeftCard.hidden = NO;
    self.driveLeftCard.frame = CGRectMake(leftX, topY, leftW, colH);
    self.driveLeftCard.layer.cornerRadius = 14;
    self.driveLeftCard.layer.borderWidth = 1.2;
    self.driveLeftCard.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.driveLeftCard.backgroundColor = [UIColor colorWithRed:.04 green:.06 blue:.08 alpha:.95];

    self.readyPill.hidden = NO;
    self.readyPill.frame = CGRectMake(leftX + (leftW - 140)/2, topY + 8, 140, 22);

    CGPoint dialCenter = CGPointMake(leftX + leftW/2, topY + 68);
    CGFloat dialRadius = 46;
    self.panel.gaugeCenter = dialCenter;
    self.panel.gaugeRadius = dialRadius;
    self.panel.clockOnly = NO;
    [self.panel setNeedsDisplay];

    UIBezierPath *dialPath = [UIBezierPath bezierPathWithArcCenter:dialCenter radius:dialRadius startAngle:M_PI*.85 endAngle:M_PI*2.15 clockwise:YES];
    self.arc.hidden = NO; self.arc.path = dialPath.CGPath;
    self.progress.hidden = NO; self.progress.path = dialPath.CGPath;

    self.speed.hidden = NO;
    self.speed.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:46] ?: [UIFont boldSystemFontOfSize:46];
    self.speed.frame = CGRectMake(leftX + 12, topY + 40, leftW - 24, 44);
    self.speed.textAlignment = NSTextAlignmentCenter;
    if(self.speed.text.length == 0 || [self.speed.text isEqualToString:@"--"] || [self.speed.text isEqualToString:@"—"]) self.speed.text = @"0";

    self.unit.hidden = NO;
    self.unit.frame = CGRectMake(leftX + 12, topY + 84, leftW - 24, 16);
    self.unit.font = [UIFont boldSystemFontOfSize:10];
    self.unit.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.unit.text = @"KM / H • DYNAMICS";

    self.gearBadge.hidden = NO;
    self.gearBadge.frame = CGRectMake(leftX + 14, topY + 98, 70, 24);

    self.speedLimitBtn.hidden = NO;
    self.speedLimitBtn.frame = CGRectMake(leftX + leftW - 36, topY + 36, 26, 26);
    self.speedLimitBtn.layer.cornerRadius = 13;

    CGFloat gw = (leftW - 20 - 4*5)/5;
    for(int i=0; i<self.gearButtons.count; i++){
      UIButton *gb = self.gearButtons[i];
      gb.hidden = NO;
      gb.frame = CGRectMake(leftX + 10 + i*(gw + 5), topY + 128, gw, 28);
    }

    self.hybridEcoBar.hidden = NO;
    self.hybridEcoBar.frame = CGRectMake(leftX + 10, topY + 162, leftW - 20, 26);

    CGFloat mw = (leftW - 20 - 2*6)/3;
    for(int i=0; i<self.driveModePills.count; i++){
      UIButton *mb = self.driveModePills[i];
      mb.hidden = NO;
      mb.frame = CGRectMake(leftX + 10 + i*(mw + 6), topY + 194, mw, 28);
    }
    self.modeButton.hidden = YES;
    self.driveButton.hidden = YES;

    // AI Eco Coach Card (Card 2)
    self.brakeStatusCard.hidden = NO;
    self.brakeStatusCard.frame = CGRectMake(leftX + 10, topY + 228, leftW - 20, 184);
    self.brakeStatusCard.layer.cornerRadius = 10;
    self.brakeStatusCard.layer.borderWidth = 1;
    self.brakeStatusCard.layer.borderColor = [UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.4].CGColor;
    self.brakeStatusCard.backgroundColor = [UIColor colorWithRed:.02 green:.07 blue:.05 alpha:.92];
    UILabel *b1 = (UILabel *)[self.brakeStatusCard viewWithTag:501];
    b1.frame = CGRectMake(8,8,leftW-36,20);
    b1.font = [UIFont boldSystemFontOfSize:11];
    b1.text = @"🌱 AI ECO COACH    ♻️ +14 Wh REGEN";
    UILabel *b2 = (UILabel *)[self.brakeStatusCard viewWithTag:502];
    b2.frame = CGRectMake(8,28,leftW-36,148);
    b2.font = [UIFont boldSystemFontOfSize:10.5];
    b2.numberOfLines = 7;
    b2.text = @"ECO 92 / 100   [ GRADE A+ ]\n\nระบบไฮบริดทำงานสมบูรณ์ 100%\nเลี้ยงคันเร่งนุ่มนวลเพื่อประหยัดน้ำมัน\nอัตราการดึงพลังงานกลับ: ดีเยี่ยม\nเบรกไฟฟ้า ECB: แรงดันปั๊มปกติ";

    // Thermals & 12V Card (Card 3)
    self.hybridSocCard.hidden = NO;
    self.hybridSocCard.frame = CGRectMake(leftX + 10, topY + 418, leftW - 20, 200);
    self.hybridSocCard.layer.cornerRadius = 10;
    self.hybridSocCard.layer.borderWidth = 1;
    self.hybridSocCard.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.hybridSocCard.backgroundColor = [UIColor colorWithRed:.02 green:.055 blue:.065 alpha:.92];
    UILabel *h1 = (UILabel *)[self.hybridSocCard viewWithTag:601];
    h1.frame = CGRectMake(8,8,leftW-36,20);
    h1.font = [UIFont boldSystemFontOfSize:11];
    h1.text = @"🌡️ VEHICLE THERMALS & 12V";
    UILabel *h2 = (UILabel *)[self.hybridSocCard viewWithTag:602];
    h2.frame = CGRectMake(8,28,leftW-36,164);
    h2.font = [UIFont boldSystemFontOfSize:10.5];
    h2.numberOfLines = 7;
    h2.text = @"🌡️ น้ำหล่อเย็น (Coolant) : 88 °C\n\n❄️ แอร์ห้องโดยสาร : 24.5 °C (42°C Inv)\n\n🔋 แบตเตอรี่สตาร์ท 12V : 13.84 V • ชาร์จปกติ\n\nพัดลมระบายความร้อน: เบอร์ 1 (Low)\nสถานะระบบหล่อเย็น: ปกติ สมบูรณ์";

    // 2. CENTER ZONE
    self.energyFlowLabel.hidden = NO;
    self.energyFlowLabel.frame = CGRectMake(centerX + 8, topY + 6, centerW - 16, 28);
    self.energyFlowLabel.font = [UIFont boldSystemFontOfSize:12];
    self.energyFlowLabel.text = @"🍃 PURE EV DRIVE (MG2 – เพลาขับหน้า) ⚡";

    self.frontMotorBox.hidden = NO;
    self.frontMotorBox.frame = CGRectMake(centerX + 12, topY + 38, 146, 32);

    self.rearBatteryBox.hidden = NO;
    self.rearBatteryBox.frame = CGRectMake(centerX + centerW - 158, topY + 38, 146, 32);

    self.carImage.hidden = NO;
    self.carImage.frame = CGRectMake(centerX + 20, topY + 58, centerW - 40, 185);

    self.flowBeamLine.hidden = NO;
    self.flowBeamLine.frame = CGRectMake(centerX + 40, topY + 238, centerW - 80, 3);
    UIView *rDot = [self.flowBeamLine viewWithTag:831];
    if(rDot) rDot.frame = CGRectMake(centerW - 80 - 10, -4, 10, 10);

    self.compassLabel.hidden = NO;
    self.compassLabel.frame = CGRectMake(centerX + 12, topY + 248, centerW - 24, 22);
    self.compassLabel.font = [UIFont boldSystemFontOfSize:10.5];
    self.compassLabel.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.compassLabel.text = @"กระแสไฟไฮบริด: ⚡ ชาร์จไฟเข้าสู่แบตเตอรี่ (Inflow)  +14.2 kW (Regen Active)";

    self.carStatus.hidden = NO;
    self.carStatus.frame = CGRectMake(centerX + 12, topY + 276, centerW - 24, 30);
    self.carStatus.font = [UIFont boldSystemFontOfSize:11];
    self.carStatus.textAlignment = NSTextAlignmentCenter;
    self.carStatus.text = @"🚪 ประตู 5 บาน: ปิดสนิท  •  🔒 เข็มขัดล็อค: ล็อคอยู่ (แตะเพื่อดูรายละเอียด)";
    self.carStatus.layer.cornerRadius = 6;
    self.carStatus.layer.borderWidth = 1;
    self.carStatus.layer.borderColor = [UIColor colorWithRed:0 green:.75 blue:.40 alpha:.45].CGColor;
    self.carStatus.backgroundColor = [UIColor colorWithRed:.04 green:.08 blue:.05 alpha:.88];

    CGFloat nowY = topY + 312, nowH = colH - 318;
    self.nowPanel.hidden = NO;
    self.nowPanel.frame = CGRectMake(centerX + 8, nowY, centerW - 16, nowH);
    self.nowPanel.layer.cornerRadius = 14;
    self.nowPanel.layer.borderWidth = 1.2;
    self.nowPanel.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.nowPanel.backgroundColor = [UIColor colorWithWhite:.055 alpha:.95];

    CGFloat artSize = 100;
    self.artwork.hidden = NO;
    self.artwork.frame = CGRectMake(centerX + 22, nowY + 14, artSize, artSize);
    self.artwork.layer.cornerRadius = 10;
    self.artwork.layer.borderWidth = 1;
    self.artwork.layer.borderColor = [UIColor colorWithWhite:.24 alpha:1].CGColor;
    self.artPlaceholder.frame = self.artwork.frame;
    self.artPlaceholder.hidden = (self.artwork.image != nil);
    self.artPlaceholder.font = [UIFont systemFontOfSize:36];

    CGFloat metaX = centerX + 22 + artSize + 14, metaW = centerW - 32 - artSize - 28;
    self.sourceBadge.hidden = NO;
    self.sourceBadge.frame = CGRectMake(metaX, nowY + 12, 76, 20);
    self.sourceBadge.font = [UIFont boldSystemFontOfSize:10];

    self.song.hidden = NO;
    self.song.textAlignment = NSTextAlignmentLeft;
    self.song.font = [UIFont boldSystemFontOfSize:18];
    self.song.textColor = [UIColor colorWithWhite:self.nightMode?.80:.96 alpha:1];
    self.song.adjustsFontSizeToFitWidth = YES;
    self.song.minimumScaleFactor = 0.75;
    self.song.frame = CGRectMake(metaX, nowY + 36, metaW, 26);

    self.artist.hidden = NO;
    self.artist.textAlignment = NSTextAlignmentLeft;
    self.artist.font = [UIFont systemFontOfSize:13.5];
    self.artist.textColor = [UIColor colorWithWhite:.72 alpha:1];
    self.artist.adjustsFontSizeToFitWidth = YES;
    self.artist.frame = CGRectMake(metaX, nowY + 64, metaW, 20);

    self.trackProgress.hidden = NO;
    self.trackProgress.frame = CGRectMake(metaX, nowY + 92, metaW, 4);

    self.trackTime.hidden = NO;
    self.trackTime.textAlignment = NSTextAlignmentRight;
    self.trackTime.font = [UIFont systemFontOfSize:11];
    self.trackTime.textColor = [UIColor colorWithWhite:.60 alpha:1];
    self.trackTime.frame = CGRectMake(metaX, nowY + 100, metaW, 16);

    CGFloat ctrlW = centerW - 44 - 110;
    self.controls.hidden = NO;
    self.controls.backgroundColor = [UIColor clearColor];
    self.controls.frame = CGRectMake(centerX + 22, nowY + artSize + 22, ctrlW, 52);
    [self.controls viewWithTag:23].hidden = YES;
    CGFloat cw = (ctrlW - 16) / 3;
    for(int i=0; i<3; i++){
      UIView *b = [self.controls viewWithTag:20+i];
      b.frame = CGRectMake(i*(cw+8), 0, cw, 52);
      b.layer.cornerRadius = 8;
      if(i == 1){
        b.backgroundColor = [UIColor colorWithRed:.05 green:.55 blue:.30 alpha:1];
        b.layer.borderColor = [UIColor colorWithRed:.2 green:.85 blue:.45 alpha:1].CGColor;
        [b viewWithTag:105].frame = CGRectMake((cw-36)/2, 8, 36, 36);
      }else{
        b.backgroundColor = [UIColor colorWithWhite:.085 alpha:1];
        b.layer.borderColor = [UIColor colorWithWhite:.20 alpha:1].CGColor;
        [b viewWithTag:105].frame = CGRectMake((cw-30)/2, 11, 30, 30);
      }
    }

    self.driveEQ.hidden = NO;
    self.driveEQ.frame = CGRectMake(centerX + 22 + ctrlW + 10, nowY + artSize + 22, 100, 52);
    [self.driveEQ setTitle:@"🎛️ JBL EQ" forState:UIControlStateNormal];
    self.driveEQ.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
    self.driveEQ.layer.cornerRadius = 8;
    self.driveEQ.layer.borderWidth = 1.5;
    self.driveEQ.layer.borderColor = [TRDAccent() colorWithAlphaComponent:.7].CGColor;
    self.driveEQ.backgroundColor = [TRDAccent() colorWithAlphaComponent:.16];

    // 3. RIGHT ZONE
    self.driveRightCard.hidden = NO;
    self.driveRightCard.frame = CGRectMake(rightX, topY, rightW, colH);
    self.driveRightCard.layer.cornerRadius = 14;
    self.driveRightCard.layer.borderWidth = 1.2;
    self.driveRightCard.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.driveRightCard.backgroundColor = [UIColor colorWithRed:.04 green:.06 blue:.08 alpha:.95];

    self.clock.hidden = YES;
    self.date.hidden = YES;
    self.tripButton.hidden = YES;
    self.radioButton.hidden = YES;
    self.offlineMusicBtn.hidden = YES;
    self.searchMusicBtn.hidden = YES;

    // Card 1: Powertrain 7E3 (Y: topY + 8, Height: 248)
    UIView *pCard = [self.view viewWithTag:701];
    if(!pCard){
      pCard = [[UIView alloc]init];
      pCard.tag = 701;
      pCard.backgroundColor = [UIColor colorWithRed:.02 green:.06 blue:.08 alpha:.92];
      pCard.layer.cornerRadius = 10;
      pCard.layer.borderWidth = 1.0;
      pCard.layer.borderColor = [UIColor colorWithRed:0 green:.75 blue:.85 alpha:.35].CGColor;
      
      UILabel *pt = [[UILabel alloc]initWithFrame:CGRectMake(8,6,rightW-36,16)];
      pt.tag = 702;
      pt.font = [UIFont boldSystemFontOfSize:10.5];
      pt.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
      pt.text = @"POWERTRAIN & HV • 7E3";
      [pCard addSubview:pt];
      
      UILabel *pb = [[UILabel alloc]initWithFrame:CGRectMake(8,24,rightW-36,54)];
      pb.tag = 703;
      pb.font = [UIFont boldSystemFontOfSize:11];
      pb.textColor = [UIColor whiteColor];
      pb.numberOfLines = 3;
      pb.text = @"64.5% SOC (ระดับไฟไฮบริด)\n227.4 V • +12.4 A (CHG)\n14 BLOCKS (28 NiMH MODULES)";
      [pCard addSubview:pb];
      [self.view addSubview:pCard];
    }
    pCard.hidden = NO;
    pCard.frame = CGRectMake(rightX + 10, topY + 8, rightW - 20, 248);

    self.blockGraphView.hidden = NO;
    self.blockGraphView.frame = CGRectMake(rightX + 18, topY + 88, rightW - 36, 32);

    UILabel *deltaL = (UILabel *)[self.view viewWithTag:706];
    if(!deltaL){
      deltaL = [[UILabel alloc]init];
      deltaL.tag = 706;
      deltaL.font = [UIFont boldSystemFontOfSize:9.5];
      deltaL.textColor = [UIColor colorWithWhite:.85 alpha:1];
      deltaL.text = @"ΔV: 0.02 V (Good)   Min 16.22 / Max 16.24";
      [self.view addSubview:deltaL];
    }
    deltaL.hidden = NO;
    deltaL.frame = CGRectMake(rightX + 18, topY + 124, rightW - 36, 16);

    // Card 2: 3 Motor / Thermal Rows (Y: topY + 262, Height: 136)
    UIView *mCard = [self.view viewWithTag:707];
    if(!mCard){
      mCard = [[UIView alloc]init];
      mCard.tag = 707;
      mCard.backgroundColor = [UIColor colorWithRed:.02 green:.04 blue:.06 alpha:.92];
      mCard.layer.cornerRadius = 10;
      mCard.layer.borderWidth = 1.0;
      mCard.layer.borderColor = [UIColor colorWithWhite:.16 alpha:1].CGColor;
      
      UILabel *ml = [[UILabel alloc]initWithFrame:CGRectMake(8,8,rightW-36,120)];
      ml.tag = 708;
      ml.font = [UIFont boldSystemFontOfSize:10];
      ml.textColor = [UIColor whiteColor];
      ml.numberOfLines = 5;
      ml.text = @"⚙️ มอเตอร์ MG2 (ขับเคลื่อน)\n   1,420 RPM / 18 kW\n⚡ เจนเนอเรเตอร์ MG1 (ปั่นไฟ)\n   980 RPM / 8 kW\n🌡️ อุณหภูมิแบตไฮบริด (HV)\n   35.0 °C • พัดลม Low";
      [mCard addSubview:ml];
      [self.view addSubview:mCard];
    }
    mCard.hidden = NO;
    mCard.frame = CGRectMake(rightX + 10, topY + 262, rightW - 20, 136);

    // Card 3: GPS Trip Computer & Range (Y: topY + 404, Height: 216)
    UIView *tCard = [self.view viewWithTag:711];
    if(!tCard){
      tCard = [[UIView alloc]init];
      tCard.tag = 711;
      tCard.backgroundColor = [UIColor colorWithRed:.06 green:.03 blue:.04 alpha:.92];
      tCard.layer.cornerRadius = 10;
      tCard.layer.borderWidth = 1.0;
      tCard.layer.borderColor = [TRDAccent() colorWithAlphaComponent:.4].CGColor;
      
      UILabel *tt = [[UILabel alloc]initWithFrame:CGRectMake(8,6,rightW-36,16)];
      tt.tag = 712;
      tt.font = [UIFont boldSystemFontOfSize:10.5];
      tt.textColor = TRDAccent();
      tt.text = @"📍 TRIP COMPUTER & RANGE";
      [tCard addSubview:tt];
      
      UILabel *tb = [[UILabel alloc]initWithFrame:CGRectMake(8,24,rightW-36,180)];
      tb.tag = 713;
      tb.font = [UIFont boldSystemFontOfSize:10.5];
      tb.textColor = [UIColor colorWithWhite:.90 alpha:1];
      tb.numberOfLines = 8;
      tb.text = @"ระยะทางทริป: 18.42 km\nอัตราสิ้นเปลือง: 23.8 km/L\nค่าน้ำมันทริป: ฿ 29.80 (PTT GSH95)\nวิ่งต่อได้: ~520 km\nความเร็วเฉลี่ย: 48.5 km/h\nเวลาขับขี่: 00:24:18\nประหยัดน้ำมัน: ดีเยี่ยม (Grade A+)";
      [tCard addSubview:tb];
      [self.view addSubview:tCard];
    }
    tCard.hidden = NO;
    tCard.frame = CGRectMake(rightX + 10, topY + 404, rightW - 20, 216);

    for(int i=0;i<6;i++)((UIButton *)self.cards[i]).hidden=YES;
  }`;

code = code.replace(target3ZoneRegex, new3ZoneLayout);

// 10. Hide helper views when not in Home mode
const hideHelpers = `
  if(self.driveMode || self.musicMode || self.tripMode || self.mapMode || self.carplayMode || self.focused){
    self.readyPill.hidden = YES;
    self.gearBadge.hidden = YES;
    for(UIButton *b in self.gearButtons) b.hidden = YES;
    for(UIButton *b in self.driveModePills) b.hidden = YES;
    self.frontMotorBox.hidden = YES;
    self.rearBatteryBox.hidden = YES;
    self.flowBeamLine.hidden = YES;
    self.blockGraphView.hidden = YES;
    UIView *deltaL = [self.view viewWithTag:706]; if(deltaL) deltaL.hidden = YES;
    UIView *mCard = [self.view viewWithTag:707]; if(mCard) mCard.hidden = YES;
    self.topClockLabel.hidden = YES;
    self.obdStatusPill.hidden = YES;
    self.dayNightPill.hidden = YES;
    self.thaiVoicePill.hidden = YES;
    self.settingsPill.hidden = YES;
  }
`;

code = code.replace('self.tripButton.hidden=focus||self.musicMode||self.tripMode||self.mapMode||self.driveMode;', 'self.tripButton.hidden=focus||self.musicMode||self.tripMode||self.mapMode||self.driveMode;\n' + hideHelpers);

fs.writeFileSync('cardash_main.m', code, 'utf8');
console.log('Clean build written. Length:', code.length);
