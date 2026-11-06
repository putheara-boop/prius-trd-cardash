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
-(instancetype)init{if((self=[super init])){
 self.backgroundColor=[UIColor colorWithWhite:.018 alpha:1];self.opaque=YES;
 self.car=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"TRDRealPrius.png"]];self.car.contentMode=UIViewContentModeScaleAspectFit;[self addSubview:self.car];
 self.badge=[UILabel new];self.badge.attributedText=[[NSAttributedString alloc]initWithString:@"PRIUS  /  TRD" attributes:@{NSKernAttributeName:@3.0}];self.badge.textColor=TRDAccent();self.badge.font=[UIFont boldSystemFontOfSize:20];self.badge.textAlignment=NSTextAlignmentCenter;[self addSubview:self.badge];
 self.name=[UILabel new];self.name.attributedText=[[NSAttributedString alloc]initWithString:@"WELCOME, PEEPUT" attributes:@{NSKernAttributeName:@3.0}];self.name.font=[UIFont fontWithName:@"HelveticaNeue-Light" size:42]?:[UIFont systemFontOfSize:42];self.name.textColor=[UIColor whiteColor];self.name.textAlignment=NSTextAlignmentCenter;self.name.adjustsFontSizeToFitWidth=YES;self.name.minimumScaleFactor=.65;[self addSubview:self.name];
 self.tagline=[UILabel new];self.tagline.attributedText=[[NSAttributedString alloc]initWithString:@"READY FOR YOUR NEXT DRIVE" attributes:@{NSKernAttributeName:@2.0}];self.tagline.font=[UIFont systemFontOfSize:13];self.tagline.textColor=[UIColor colorWithWhite:.5 alpha:1];self.tagline.textAlignment=NSTextAlignmentCenter;self.tagline.adjustsFontSizeToFitWidth=YES;[self addSubview:self.tagline];
 self.line=[UIView new];self.line.backgroundColor=TRDAccent();[self addSubview:self.line];
 }return self;}
-(void)drawRect:(CGRect)rect{[[UIColor colorWithWhite:.045 alpha:1]setStroke];UIBezierPath *p=[UIBezierPath bezierPath];p.lineWidth=.5;CGFloat w=self.bounds.size.width,h=self.bounds.size.height;for(CGFloat x=-h;x<w;x+=22){[p moveToPoint:CGPointMake(x,0)];[p addLineToPoint:CGPointMake(x+h,h)];}[p stroke];}
-(void)layoutSubviews{[super layoutSubviews];CGFloat w=self.bounds.size.width,h=self.bounds.size.height;self.badge.frame=CGRectMake(24,h*.15,w-48,34);self.car.frame=CGRectMake(w*.105,h*.25,w*.79,h*.40);self.line.frame=CGRectMake(w*.30,h*.70,w*.40,1.5);self.name.frame=CGRectMake(24,h*.735,w-48,58);self.tagline.frame=CGRectMake(24,h*.845,w-48,25);}
@end
