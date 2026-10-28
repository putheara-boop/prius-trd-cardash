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
@property UILabel *badge,*name,*tagline;
@property UIView *line;
@end
@implementation CarWelcome
-(instancetype)init{if((self=[super init])){self.backgroundColor=[UIColor colorWithWhite:.018 alpha:1];self.car=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"PriusGS.png"]];self.car.contentMode=UIViewContentModeScaleAspectFit;[self addSubview:self.car];self.badge=[UILabel new];self.badge.text=@"PRIUS  /  TRD SPORT";self.badge.textColor=TRDAccent();self.badge.font=[UIFont boldSystemFontOfSize:25];self.badge.textAlignment=NSTextAlignmentCenter;[self addSubview:self.badge];self.name=[UILabel new];self.name.text=@"Welcome, PEEPUT";self.name.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:45];self.name.textColor=[UIColor whiteColor];self.name.textAlignment=NSTextAlignmentCenter;[self addSubview:self.name];self.tagline=[UILabel new];self.tagline.text=@"READY FOR YOUR NEXT DRIVE";self.tagline.font=[UIFont boldSystemFontOfSize:13];self.tagline.textColor=[UIColor colorWithWhite:.5 alpha:1];self.tagline.textAlignment=NSTextAlignmentCenter;[self addSubview:self.tagline];self.line=[UIView new];self.line.backgroundColor=TRDAccent();[self addSubview:self.line];}return self;}
-(void)layoutSubviews{[super layoutSubviews];CGFloat w=self.bounds.size.width,h=self.bounds.size.height;self.badge.frame=CGRectMake(24,h*.13,w-48,36);self.car.frame=CGRectMake(w*.10,h*.23,w*.80,h*.45);self.line.frame=CGRectMake(w*.24,h*.71,w*.52,2);self.name.frame=CGRectMake(24,h*.75,w-48,62);self.tagline.frame=CGRectMake(24,h*.88,w-48,26);}
@end
