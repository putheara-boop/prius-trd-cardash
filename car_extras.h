static NSInteger TRDTheme;
static BOOL TRDLowLight;
static inline NSString *TRDDriveModeName(NSInteger mode){
 if(mode==1)return @"NORMAL";
 if(mode==2)return @"ECO";
 return @"SPORT";
}
static UIColor *TRDAccent(void){CGFloat dim=TRDLowLight?.66:1;return TRDTheme==1?[UIColor colorWithRed:.10*dim green:.78*dim blue:dim alpha:1]:TRDTheme==2?[UIColor colorWithRed:.15*dim green:.88*dim blue:.38*dim alpha:1]:[UIColor colorWithRed:.98*dim green:.10*dim blue:.17*dim alpha:1];}
static BOOL TRDNightHour(NSInteger hour){return hour<6||hour>=18;}
static NSString *const TRDProfilesPath=@"/var/mobile/codex-car/sound-profiles.plist";
static NSString *const TRDSourcePath=@"/var/mobile/codex-car/sound-source.plist";
static NSArray *TRDProfileNames(void){return @[@"Flat",@"Rock",@"Pop",@"Jazz",@"Dance",@"Classical",@"Voice",@"My Setup"];}
static void TRDProfileChanged(void){CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFSTR("com.codex.cardash.soundprofiles"),NULL,NULL,YES);}

@interface CarWelcome:UIView
@property UIImageView *car;
@property UILabel *badge,*name,*tagline,*hint;
@property UIView *line,*pillBox;
@end

@implementation CarWelcome
-(instancetype)init{if((self=[super init])){
 self.backgroundColor=[UIColor colorWithRed:0.024 green:0.031 blue:0.043 alpha:1.0];
 self.opaque=YES;
 self.userInteractionEnabled=YES;
 
 self.car=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"TRDRealPrius.png"]];
 self.car.contentMode=UIViewContentModeScaleAspectFit;
 [self addSubview:self.car];
 
 self.badge=[UILabel new];
 self.badge.attributedText=[[NSAttributedString alloc]initWithString:@"PEEPUT'S DRIVE  •  PRIUS TRD SPORTIVO" attributes:@{NSKernAttributeName:@3.0}];
 self.badge.textColor=TRDAccent();
 self.badge.font=[UIFont boldSystemFontOfSize:18];
 self.badge.textAlignment=NSTextAlignmentCenter;
 [self addSubview:self.badge];
 
 self.name=[UILabel new];
 self.name.attributedText=[[NSAttributedString alloc]initWithString:@"WELCOME, PEEPUT" attributes:@{NSKernAttributeName:@3.5}];
 self.name.font=[UIFont fontWithName:@"HelveticaNeue-Bold" size:42]?:[UIFont boldSystemFontOfSize:40];
 self.name.textColor=[UIColor whiteColor];
 self.name.textAlignment=NSTextAlignmentCenter;
 self.name.adjustsFontSizeToFitWidth=YES;
 self.name.minimumScaleFactor=.65;
 [self addSubview:self.name];
 
 self.line=[UIView new];
 self.line.backgroundColor=TRDAccent();
 [self addSubview:self.line];
 
 self.tagline=[UILabel new];
 NSInteger voiceLang=[[NSUserDefaults standardUserDefaults] integerForKey:@"TRDVoiceLanguage"];
 NSInteger hour=[[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:[NSDate date]];
 if(voiceLang==1){
  if(hour>=5 && hour<12) self.tagline.text=@"อรุณสวัสดิ์ครับ พี่พุธ • ขอให้เป็นวันที่ราบรื่น และขับขี่ปลอดภัยนะครับ";
  else if(hour>=12 && hour<18) self.tagline.text=@"ยินดีต้อนรับครับ พี่พุธ • ระบบไฮบริดพร้อมใช้งาน ขอให้เดินทางราบรื่นครับ";
  else self.tagline.text=@"สวัสดีตอนค่ำครับ พี่พุธ • ระบบพร้อมดูแลตลอดการเดินทางในค่ำคืนนี้ครับ";
  self.tagline.font=[UIFont systemFontOfSize:16];
 }else{
  if(hour>=5 && hour<12) self.tagline.attributedText=[[NSAttributedString alloc]initWithString:@"GOOD MORNING, PEEPUT  •  HAVE A SAFE DRIVE" attributes:@{NSKernAttributeName:@2.5}];
  else if(hour>=12 && hour<18) self.tagline.attributedText=[[NSAttributedString alloc]initWithString:@"HYBRID SYSTEM READY  •  ENJOY YOUR JOURNEY" attributes:@{NSKernAttributeName:@2.5}];
  else self.tagline.attributedText=[[NSAttributedString alloc]initWithString:@"GOOD EVENING, PEEPUT  •  HAVE A SAFE DRIVE TONIGHT" attributes:@{NSKernAttributeName:@2.5}];
  self.tagline.font=[UIFont systemFontOfSize:14];
 }
 self.tagline.textColor=[UIColor colorWithRed:0.70 green:0.80 blue:0.92 alpha:1.0];
 self.tagline.textAlignment=NSTextAlignmentCenter;
 self.tagline.adjustsFontSizeToFitWidth=YES;
 [self addSubview:self.tagline];

 self.pillBox=[UIView new];
 self.pillBox.backgroundColor=[UIColor clearColor];
 [self addSubview:self.pillBox];

 NSArray *pills=@[@"● HYBRID: READY",@"● GPS 3D: LOCKED",@"● AUDIO: ONLINE"];
 NSArray *pColors=@[
  [UIColor colorWithRed:0.25 green:0.85 blue:0.40 alpha:1.0],
  [UIColor colorWithRed:0.20 green:0.75 blue:1.00 alpha:1.0],
  [UIColor colorWithRed:0.95 green:0.20 blue:0.25 alpha:1.0]
 ];
 CGFloat pW=180;
 for(int i=0;i<3;i++){
  UILabel *pLbl=[[UILabel alloc]initWithFrame:CGRectMake(i*(pW+15),0,pW,32)];
  pLbl.backgroundColor=[UIColor colorWithWhite:0.10 alpha:0.85];
  pLbl.layer.cornerRadius=16;
  pLbl.layer.borderWidth=1;
  pLbl.layer.borderColor=[UIColor colorWithWhite:0.22 alpha:1.0].CGColor;
  pLbl.clipsToBounds=YES;
  pLbl.textAlignment=NSTextAlignmentCenter;
  pLbl.font=[UIFont boldSystemFontOfSize:12];
  pLbl.textColor=pColors[i];
  pLbl.text=pills[i];
  [self.pillBox addSubview:pLbl];
 }

 self.hint=[UILabel new];
 self.hint.text=@"แตะที่ใดก็ได้เพื่อเริ่มใช้งาน (Tap anywhere to start)";
 self.hint.font=[UIFont systemFontOfSize:13];
 self.hint.textColor=[UIColor colorWithWhite:0.42 alpha:1.0];
 self.hint.textAlignment=NSTextAlignmentCenter;
 [self addSubview:self.hint];
 }return self;}

-(void)drawRect:(CGRect)rect{
 [[UIColor colorWithRed:0.024 green:0.031 blue:0.043 alpha:1.0] setFill];
 UIRectFill(rect);
 [[UIColor colorWithWhite:.06 alpha:.8] setStroke];
 UIBezierPath *p=[UIBezierPath bezierPath];
 p.lineWidth=.5;
 CGFloat w=rect.size.width,h=rect.size.height;
 for(CGFloat x=-h;x<w;x+=24){
  [p moveToPoint:CGPointMake(x,0)];
  [p addLineToPoint:CGPointMake(x+h,h)];
 }
 [p stroke];
}

-(void)layoutSubviews{
 [super layoutSubviews];
 CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
 if(w<=0) w=1024;
 if(h<=0) h=768;
 self.badge.frame=CGRectMake((w-580)/2, 45, 580, 32);
 self.car.frame=CGRectMake((w-620)/2, 85, 620, 310);
 self.line.frame=CGRectMake((w-440)/2, 400, 440, 2);
 self.name.frame=CGRectMake(24, 415, w-48, 52);
 self.tagline.frame=CGRectMake(24, 472, w-48, 28);
 self.pillBox.frame=CGRectMake((w-570)/2, 516, 570, 32);
 self.hint.frame=CGRectMake(24, h-45, w-48, 24);
}
@end
