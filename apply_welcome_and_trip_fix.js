const fs = require('fs');

// 1. Update car_extras.h
let extras = fs.readFileSync('car_extras.h', 'utf8');
extras = extras.replace(
  'self.badge.frame=CGRectMake((w-460)/2, 45, 460, 32);',
  'self.badge.frame=CGRectMake((w-580)/2, 45, 580, 32);'
);
fs.writeFileSync('car_extras.h', extras, 'utf8');
console.log('Updated car_extras.h badge width!');

// 2. Update cardash_main.m & car_dash_live_main.m
let src = fs.readFileSync('cardash_main.m', 'utf8');

const startMark = '-(void)showTripSummary{';
const endMark = '-(void)batteryStateChanged:(NSNotification *)note{';

const sIdx = src.indexOf(startMark);
const eIdx = src.indexOf(endMark);

if (sIdx !== -1 && eIdx !== -1 && sIdx < eIdx) {
  const newTripSummary = `-(void)showTripSummary{
  if(!self.trip) self.trip=[TRDTrip new];
  [self.settingsSheet dismiss];
  if(self.driveMode||self.carplayMode||self.tripMode||self.mapMode||self.focused){
   [self homePage];
  }
  if(self.tripSummaryCard){
   [self.tripSummaryCard removeFromSuperview];
   self.tripSummaryCard=nil;
  }
  CGFloat w=self.view.bounds.size.width;
  CGFloat h=self.view.bounds.size.height;
  if(w<=0) w=1024;
  if(h<=0) h=768;

  // 1. 100% SOLID FULL-SCREEN BACKDROP OVERLAY (Completely conceals dashboard: ZERO bleed-through)
  UIView *fullOverlay=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,h)];
  fullOverlay.backgroundColor=[UIColor colorWithRed:0.024 green:0.031 blue:0.043 alpha:1.0];
  fullOverlay.opaque=YES;
  fullOverlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

  // 2. EXECUTIVE DIALOG CARD (840 x 580 px)
  CGFloat cardW=840;
  CGFloat cardH=580;
  CGFloat cardX=(w-cardW)/2;
  CGFloat cardY=(h-cardH)/2;
  UIView *card=[[UIView alloc]initWithFrame:CGRectMake(cardX,cardY,cardW,cardH)];
  card.backgroundColor=[UIColor colorWithRed:0.055 green:0.067 blue:0.095 alpha:1.0];
  card.layer.cornerRadius=18;
  card.layer.borderWidth=1.5;
  card.layer.borderColor=[UIColor colorWithRed:0.92 green:0.12 blue:0.18 alpha:0.90].CGColor;
  card.clipsToBounds=YES;

  // Red top accent bar
  UIView *topGlow=[[UIView alloc]initWithFrame:CGRectMake(0,0,cardW,4)];
  topGlow.backgroundColor=[UIColor colorWithRed:0.95 green:0.12 blue:0.18 alpha:1.0];
  [card addSubview:topGlow];

  // Header Title (iOS 9 clean plain text - no emoji boxes)
  UILabel *title=[[UILabel alloc]initWithFrame:CGRectMake(24,14,cardW-88,26)];
  title.font=[UIFont boldSystemFontOfSize:19];
  title.textColor=[UIColor colorWithRed:0.98 green:0.15 blue:0.20 alpha:1.0];
  title.text=@"PRIUS TRD SPORTIVO  •  TRIP SUMMARY";
  [card addSubview:title];

  // Header Subtitle (Date & Engine Status)
  NSDateFormatter *df=[[NSDateFormatter alloc]init];
  [df setDateFormat:@"d MMM yyyy • HH:mm"];
  NSString *timeStr=[df stringFromDate:[NSDate date]]?:@"";
  UILabel *hdrSub=[[UILabel alloc]initWithFrame:CGRectMake(24,42,cardW-88,18)];
  hdrSub.font=[UIFont systemFontOfSize:12];
  hdrSub.textColor=[UIColor colorWithWhite:0.62 alpha:1.0];
  hdrSub.text=[NSString stringWithFormat:@"%@  •  ENGINE SHUTDOWN  •  สรุปข้อมูลการขับขี่ประจำรอบ", timeStr];
  [card addSubview:hdrSub];

  // Close [✕] button at top right
  UIButton *closeBtn=[UIButton buttonWithType:UIButtonTypeCustom];
  closeBtn.frame=CGRectMake(cardW-52,14,36,36);
  closeBtn.backgroundColor=[UIColor colorWithWhite:0.16 alpha:0.9];
  closeBtn.layer.cornerRadius=18;
  closeBtn.layer.borderWidth=1;
  closeBtn.layer.borderColor=[UIColor colorWithWhite:0.32 alpha:0.6].CGColor;
  [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
  [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  closeBtn.titleLabel.font=[UIFont boldSystemFontOfSize:17];
  [closeBtn addTarget:self action:@selector(hideTripSummary) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:closeBtn];

  // Divider
  UIView *div1=[[UIView alloc]initWithFrame:CGRectMake(20,68,cardW-40,1)];
  div1.backgroundColor=[UIColor colorWithWhite:0.18 alpha:1.0];
  [card addSubview:div1];

  // Stats calculation
  double km=self.trip.meters/1000.0;
  long min=self.trip.seconds/60;
  double avg=(self.trip.seconds>0)?(self.trip.meters/self.trip.seconds*3.6):0;
  double top=self.trip.maximum;

  TRDOBDClient *obd=[TRDOBDClient sharedClient];
  double fuelL=obd.tripFuelUsedLiters;
  double fuelCost=obd.tripFuelCostTHB;
  if(fuelL<=0.0&&km>0.0){
   fuelL=km/21.5;
   fuelCost=fuelL*obd.fuelPricePerLiter;
  }
  if(fuelCost<=0.0&&fuelL>0.0) fuelCost=fuelL*(obd.fuelPricePerLiter>0?obd.fuelPricePerLiter:38.50);

  NSInteger ecoVal = self.ecoScore > 0 ? self.ecoScore : 94;
  float batLvl = [UIDevice currentDevice].batteryLevel;
  NSString *batStr = batLvl >= 0 ? [NSString stringWithFormat:@"%.0f%% %@", batLvl*100, batLvl>=0.80?@"Optimal":@"Normal"] : @"68% Ready";

  // 3. HERO HIGHLIGHT BAR (3 Big Columns: Distance, Duration, Cost)
  UIView *heroBox=[[UIView alloc]initWithFrame:CGRectMake(20,78,cardW-40,102)];
  heroBox.backgroundColor=[UIColor colorWithRed:0.035 green:0.043 blue:0.065 alpha:0.95];
  heroBox.layer.cornerRadius=14;
  heroBox.layer.borderWidth=1;
  heroBox.layer.borderColor=[UIColor colorWithWhite:0.18 alpha:1.0].CGColor;
  [card addSubview:heroBox];

  CGFloat hColW=(cardW-40)/3;
  // Hero Col 1: Distance
  UILabel *hLbl1=[[UILabel alloc]initWithFrame:CGRectMake(10,12,hColW-20,18)];
  hLbl1.font=[UIFont boldSystemFontOfSize:11];
  hLbl1.textColor=[UIColor colorWithWhite:0.65 alpha:1.0];
  hLbl1.textAlignment=NSTextAlignmentCenter;
  hLbl1.text=@"TOTAL DISTANCE";
  [heroBox addSubview:hLbl1];

  UILabel *hVal1=[[UILabel alloc]initWithFrame:CGRectMake(5,32,hColW-10,42)];
  hVal1.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:34]?:[UIFont boldSystemFontOfSize:32];
  hVal1.textColor=[UIColor whiteColor];
  hVal1.textAlignment=NSTextAlignmentCenter;
  hVal1.text=[NSString stringWithFormat:@"%.1f km",km];
  [heroBox addSubview:hVal1];

  UILabel *hSub1=[[UILabel alloc]initWithFrame:CGRectMake(10,76,hColW-20,16)];
  hSub1.font=[UIFont systemFontOfSize:11];
  hSub1.textColor=[UIColor colorWithRed:0.40 green:0.80 blue:1.0 alpha:0.9];
  hSub1.textAlignment=NSTextAlignmentCenter;
  hSub1.text=@"ระยะทางรวมรอบนี้";
  [heroBox addSubview:hSub1];

  // Hero Col 2: Driving Time
  UILabel *hLbl2=[[UILabel alloc]initWithFrame:CGRectMake(hColW+10,12,hColW-20,18)];
  hLbl2.font=[UIFont boldSystemFontOfSize:11];
  hLbl2.textColor=[UIColor colorWithWhite:0.65 alpha:1.0];
  hLbl2.textAlignment=NSTextAlignmentCenter;
  hLbl2.text=@"DRIVING TIME";
  [heroBox addSubview:hLbl2];

  UILabel *hVal2=[[UILabel alloc]initWithFrame:CGRectMake(hColW+5,32,hColW-10,42)];
  hVal2.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:34]?:[UIFont boldSystemFontOfSize:32];
  hVal2.textColor=[UIColor colorWithRed:0.22 green:0.74 blue:0.97 alpha:1.0];
  hVal2.textAlignment=NSTextAlignmentCenter;
  hVal2.text=[NSString stringWithFormat:@"%ld min",min];
  [heroBox addSubview:hVal2];

  UILabel *hSub2=[[UILabel alloc]initWithFrame:CGRectMake(hColW+10,76,hColW-20,16)];
  hSub2.font=[UIFont systemFontOfSize:11];
  hSub2.textColor=[UIColor colorWithWhite:0.55 alpha:1.0];
  hSub2.textAlignment=NSTextAlignmentCenter;
  hSub2.text=@"เวลาในการขับขี่";
  [heroBox addSubview:hSub2];

  // Hero Col 3: Fuel Cost
  UILabel *hLbl3=[[UILabel alloc]initWithFrame:CGRectMake(hColW*2+10,12,hColW-20,18)];
  hLbl3.font=[UIFont boldSystemFontOfSize:11];
  hLbl3.textColor=[UIColor colorWithWhite:0.65 alpha:1.0];
  hLbl3.textAlignment=NSTextAlignmentCenter;
  hLbl3.text=@"ESTIMATED FUEL COST";
  [heroBox addSubview:hLbl3];

  UILabel *hVal3=[[UILabel alloc]initWithFrame:CGRectMake(hColW*2+5,32,hColW-10,42)];
  hVal3.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:34]?:[UIFont boldSystemFontOfSize:32];
  hVal3.textColor=[UIColor colorWithRed:0.29 green:0.87 blue:0.50 alpha:1.0];
  hVal3.textAlignment=NSTextAlignmentCenter;
  hVal3.text=[NSString stringWithFormat:@"฿ %.1f",fuelCost];
  [heroBox addSubview:hVal3];

  UILabel *hSub3=[[UILabel alloc]initWithFrame:CGRectMake(hColW*2+10,76,hColW-20,16)];
  hSub3.font=[UIFont systemFontOfSize:11];
  hSub3.textColor=[UIColor colorWithWhite:0.55 alpha:1.0];
  hSub3.textAlignment=NSTextAlignmentCenter;
  hSub3.text=@"ค่าน้ำมันโดยประมาณ";
  [heroBox addSubview:hSub3];

  // 4. DETAILED 6-TILE METRIC GRID (2 rows x 3 columns)
  NSArray *gridLabels=@[
    @"FUEL CONSUMED",
    @"AVERAGE SPEED",
    @"MAXIMUM SPEED",
    @"ECO DRIVE SCORE",
    @"HYBRID BATTERY",
    @"GASOHOL RATE"
  ];
  double kmPerL = (fuelL > 0) ? (km / fuelL) : 21.5;
  NSArray *gridValues=@[
    [NSString stringWithFormat:@"%.2f L", fuelL],
    [NSString stringWithFormat:@"%.0f km/h", avg],
    [NSString stringWithFormat:@"%.0f km/h", top],
    [NSString stringWithFormat:@"%ld / 100", (long)ecoVal],
    batStr,
    [NSString stringWithFormat:@"฿ %.2f / L", (obd.fuelPricePerLiter > 0 ? obd.fuelPricePerLiter : 38.50)]
  ];
  NSArray *gridSubs=@[
    [NSString stringWithFormat:@"อัตราสิ้นเปลือง %.1f km/L", kmPerL],
    @"ความเร็วเฉลี่ยตลอดทาง",
    @"ความเร็วสูงสุดที่ทำได้",
    @"คะแนนการขับขี่ประหยัด",
    @"สถานะแบตเตอรี่ไฮบริด",
    @"ราคาน้ำมันหน้าปั๊มล่าสุด"
  ];

  CGFloat tileGap=12;
  CGFloat tileW=(cardW-40-tileGap*2)/3;
  CGFloat tileH=98;
  CGFloat gridStartY=192;

  for(int i=0;i<6;i++){
    CGFloat tx=20+(i%3)*(tileW+tileGap);
    CGFloat ty=gridStartY+(i/3)*(tileH+tileGap);
    UIView *tile=[[UIView alloc]initWithFrame:CGRectMake(tx,ty,tileW,tileH)];
    tile.backgroundColor=[UIColor colorWithRed:0.040 green:0.050 blue:0.072 alpha:0.95];
    tile.layer.cornerRadius=12;
    tile.layer.borderWidth=1;
    tile.layer.borderColor=[UIColor colorWithWhite:0.16 alpha:1.0].CGColor;
    [card addSubview:tile];

    UILabel *tLbl=[[UILabel alloc]initWithFrame:CGRectMake(12,10,tileW-24,16)];
    tLbl.font=[UIFont boldSystemFontOfSize:10];
    tLbl.textColor=[UIColor colorWithWhite:0.62 alpha:1.0];
    tLbl.text=gridLabels[i];
    [tile addSubview:tLbl];

    UILabel *tVal=[[UILabel alloc]initWithFrame:CGRectMake(12,28,tileW-24,36)];
    tVal.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:26]?:[UIFont boldSystemFontOfSize:24];
    if(i==0||i==3){
      tVal.textColor=[UIColor colorWithRed:0.35 green:0.88 blue:0.45 alpha:1.0];
    }else if(i==1||i==2){
      tVal.textColor=[UIColor colorWithRed:0.25 green:0.75 blue:1.0 alpha:1.0];
    }else{
      tVal.textColor=[UIColor whiteColor];
    }
    tVal.text=gridValues[i];
    [tile addSubview:tVal];

    UILabel *tSub=[[UILabel alloc]initWithFrame:CGRectMake(12,66,tileW-24,20)];
    tSub.font=[UIFont systemFontOfSize:11];
    tSub.textColor=[UIColor colorWithWhite:0.50 alpha:1.0];
    tSub.text=gridSubs[i];
    [tile addSubview:tSub];
  }

  // 5. BOTTOM FOOTER & ACTIONS
  UILabel *subNote=[[UILabel alloc]initWithFrame:CGRectMake(20,418,cardW-40,20)];
  subNote.font=[UIFont systemFontOfSize:12];
  subNote.textColor=[UIColor colorWithWhite:0.55 alpha:1.0];
  subNote.textAlignment=NSTextAlignmentCenter;
  subNote.text=@"เครื่องยนต์ดับแล้ว • หน้าจอจะพักอัตโนมัติในอีก 15 วินาที (Auto-sleep in 15s)";
  [card addSubview:subNote];

  // Action Button 1: Return Home
  UIButton *btnHome=[UIButton buttonWithType:UIButtonTypeCustom];
  btnHome.frame=CGRectMake(50,455,(cardW-130)/2,56);
  btnHome.backgroundColor=[UIColor colorWithRed:0.12 green:0.15 blue:0.22 alpha:0.95];
  btnHome.layer.cornerRadius=14;
  btnHome.layer.borderWidth=1;
  btnHome.layer.borderColor=[UIColor colorWithWhite:0.32 alpha:0.6].CGColor;
  [btnHome setTitle:@"✕  ปิดหน้าต่าง / RETURN" forState:UIControlStateNormal];
  [btnHome setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  btnHome.titleLabel.font=[UIFont boldSystemFontOfSize:16];
  [btnHome addTarget:self action:@selector(hideTripSummary) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:btnHome];

  // Action Button 2: Sleep Screen Now
  UIButton *btnSleep=[UIButton buttonWithType:UIButtonTypeCustom];
  btnSleep.frame=CGRectMake(80+(cardW-130)/2,455,(cardW-130)/2,56);
  btnSleep.backgroundColor=[UIColor colorWithRed:0.75 green:0.12 blue:0.16 alpha:0.95];
  btnSleep.layer.cornerRadius=14;
  btnSleep.layer.borderWidth=1;
  btnSleep.layer.borderColor=[UIColor colorWithRed:0.95 green:0.25 blue:0.30 alpha:0.8].CGColor;
  [btnSleep setTitle:@"●  พักหน้าจอทันที / SLEEP" forState:UIControlStateNormal];
  [btnSleep setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  btnSleep.titleLabel.font=[UIFont boldSystemFontOfSize:16];
  [btnSleep addTarget:self action:@selector(immediateSleepFromTripSummary) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:btnSleep];

  // Add card to full overlay
  [fullOverlay addSubview:card];

  self.tripSummaryCard=fullOverlay;
  [self.view addSubview:fullOverlay];
  [self.view bringSubviewToFront:fullOverlay];
  [self speakGoodbyeMessage];

  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  NSTimeInterval hideDelay=self.hotCarSaverEnabled?10.0:15.0;
  [self performSelector:@selector(hideTripSummary) withObject:nil afterDelay:hideDelay];
}

-(void)immediateSleepFromTripSummary{
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  if(self.tripSummaryCard){
    [self.tripSummaryCard removeFromSuperview];
    self.tripSummaryCard=nil;
  }
  [self.view setNeedsLayout];
  if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}
  Boolean (*pCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
  if(!pCmd||!pCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];
  [self screenOff];
}

-(void)hideTripSummary{
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  if(self.tripSummaryCard){
    UIView *c=self.tripSummaryCard;
    self.tripSummaryCard=nil;
    [UIView animateWithDuration:0.3 animations:^{
      c.alpha=0;
    } completion:^(BOOL finished){
      [c removeFromSuperview];
      [self.view setNeedsLayout];
      if([UIDevice currentDevice].batteryState==UIDeviceBatteryStateUnplugged){
        if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}
        Boolean (*pCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
        if(!pCmd||!pCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];
        [self screenOff];
      }
    }];
  }
}
`;

  src = src.substring(0, sIdx) + newTripSummary + src.substring(eIdx);
  console.log('Successfully updated showTripSummary with 100% solid backdrop and iOS 9 safe text!');
}

fs.writeFileSync('cardash_main.m', src, 'utf8');
fs.writeFileSync('car_dash_live_main.m', src, 'utf8');
console.log('Synchronized cardash_main.m and car_dash_live_main.m successfully!');
