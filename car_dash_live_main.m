#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TRDAutoplayModel.h"
#import "TRDDriveStatus.h"
#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#include <spawn.h>
#include <sys/wait.h>
#include <dlfcn.h>
#include "MeterShared.h"
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <notify.h>
#include <mach/mach_time.h>
extern char **environ;
#import "CarExtras.h"
#import "TRDSettingsMenu.h"
#import "TRDTrip.h"
#import <ImageIO/ImageIO.h>
#import "TRDProcess.h"
typedef void (*NowPlayingReader)(dispatch_queue_t,void (^)(CFDictionaryRef));
@interface NSObject(CarBluetooth)
-(BOOL)enabled;
-(NSArray *)pairedDevices;
-(NSString *)name;
-(BOOL)connected;
@end
@interface SportPanel:UIView
@property CGPoint gaugeCenter;
@property CGFloat gaugeRadius;
@property CGFloat heroBottom;
@property BOOL clockOnly;
@end
@implementation SportPanel
-(void)drawRect:(CGRect)rect{
 CGFloat w=self.bounds.size.width,h=self.bounds.size.height;CGContextRef ctx=UIGraphicsGetCurrentContext();
 [[UIColor colorWithWhite:.028 alpha:1]setFill];UIRectFill(self.bounds);
 CGContextSetLineWidth(ctx,1);CGContextSetStrokeColorWithColor(ctx,[UIColor colorWithWhite:.065 alpha:1].CGColor);
 for(CGFloat x=-h;x<w;x+=14){CGContextMoveToPoint(ctx,x,0);CGContextAddLineToPoint(ctx,x+h,h);}CGContextStrokePath(ctx);
 UIColor *red=TRDAccent();
 [red setFill];UIRectFill(CGRectMake(28,64,60,3));[[UIColor colorWithWhite:.18 alpha:1]setFill];UIRectFill(CGRectMake(92,64,w-120,1));

 if(self.clockOnly)return;
 CGPoint c=self.gaugeCenter;CGFloat r=self.gaugeRadius;
 for(int i=0;i<=36;i++){CGFloat a=M_PI*.85+(M_PI*1.3)*i/36;BOOL major=i%6==0;CGFloat inner=r-14,outer=inner-(major?12:6);CGContextSetStrokeColorWithColor(ctx,(i>=30?red:[UIColor colorWithWhite:major?.8:.28 alpha:1]).CGColor);CGContextSetLineWidth(ctx,major?2:1);CGContextMoveToPoint(ctx,c.x+cos(a)*inner,c.y+sin(a)*inner);CGContextAddLineToPoint(ctx,c.x+cos(a)*outer,c.y+sin(a)*outer);CGContextStrokePath(ctx);
 if(major){NSString *n=[NSString stringWithFormat:@"%d",i*5];NSDictionary *attrs=@{NSFontAttributeName:[UIFont boldSystemFontOfSize:11],NSForegroundColorAttributeName:i>=30?red:[UIColor lightGrayColor]};CGSize size=[n sizeWithAttributes:attrs];CGFloat nr=r+15;[n drawAtPoint:CGPointMake(c.x+cos(a)*nr-size.width/2,c.y+sin(a)*nr-size.height/2) withAttributes:attrs];}}
 [red setFill];UIRectFill(CGRectMake(w*.38,self.heroBottom-43,w*.24,2));

}
@end
@interface DashIcon:UIView
@property NSInteger kind;
@end
@implementation DashIcon
-(void)drawRect:(CGRect)rect{
 CGContextRef c=UIGraphicsGetCurrentContext();CGContextSaveGState(c);CGContextScaleCTM(c,self.bounds.size.width/48,self.bounds.size.height/48);
 UIColor *white=[UIColor colorWithWhite:.94 alpha:1],*red=TRDAccent();[white setStroke];[white setFill];CGContextSetLineCap(c,kCGLineCapRound);CGContextSetLineJoin(c,kCGLineJoinRound);CGContextSetLineWidth(c,2.4);
 UIBezierPath *p=[UIBezierPath bezierPath];p.lineWidth=2.4;p.lineCapStyle=kCGLineCapRound;p.lineJoinStyle=kCGLineJoinRound;
 switch(self.kind){
 case 1:{[white setStroke];UIBezierPath *body=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3,9,42,30) cornerRadius:8];body.lineWidth=2.4;[body stroke];[white setFill];[p moveToPoint:CGPointMake(20,17)];[p addLineToPoint:CGPointMake(32,24)];[p addLineToPoint:CGPointMake(20,31)];[p closePath];[p fill];break;}
 case 2:{[p moveToPoint:CGPointMake(18,34)];[p addLineToPoint:CGPointMake(18,11)];[p addLineToPoint:CGPointMake(37,7)];[p addLineToPoint:CGPointMake(37,30)];[p moveToPoint:CGPointMake(18,18)];[p addLineToPoint:CGPointMake(37,14)];[p stroke];[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(7,30,11,8)]fill];[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(26,26,11,8)]fill];break;}
 case 3:{[p moveToPoint:CGPointMake(24,44)];[p addCurveToPoint:CGPointMake(9,19) controlPoint1:CGPointMake(19,37) controlPoint2:CGPointMake(9,29)];[p addCurveToPoint:CGPointMake(39,19) controlPoint1:CGPointMake(9,-1) controlPoint2:CGPointMake(39,-1)];[p addCurveToPoint:CGPointMake(24,44) controlPoint1:CGPointMake(39,29) controlPoint2:CGPointMake(29,37)];[p closePath];[p stroke];UIBezierPath *ring=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18,13,12,12)];ring.lineWidth=2.4;[ring stroke];break;}
 case 4:{[p moveToPoint:CGPointMake(7,14)];[p addLineToPoint:CGPointMake(15,14)];[p addLineToPoint:CGPointMake(18,9)];[p addLineToPoint:CGPointMake(30,9)];[p addLineToPoint:CGPointMake(33,14)];[p addLineToPoint:CGPointMake(41,14)];[p addQuadCurveToPoint:CGPointMake(44,17) controlPoint:CGPointMake(44,14)];[p addLineToPoint:CGPointMake(44,36)];[p addQuadCurveToPoint:CGPointMake(41,39) controlPoint:CGPointMake(44,39)];[p addLineToPoint:CGPointMake(7,39)];[p addQuadCurveToPoint:CGPointMake(4,36) controlPoint:CGPointMake(4,39)];[p addLineToPoint:CGPointMake(4,17)];[p closePath];[p stroke];UIBezierPath *lens=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(15,18,18,18)];lens.lineWidth=2.4;[lens stroke];break;}
 case 5:{for(int i=0;i<8;i++){CGFloat a=i*M_PI/4;[p moveToPoint:CGPointMake(24+cos(a)*16,24+sin(a)*16)];[p addLineToPoint:CGPointMake(24+cos(a)*21,24+sin(a)*21)];}[p stroke];UIBezierPath *outer=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9,9,30,30)];outer.lineWidth=2.4;[outer stroke];UIBezierPath *inner=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18,18,12,12)];inner.lineWidth=2.4;[inner stroke];break;}
 case 6:{UIBezierPath *face=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(5,5,38,38)];face.lineWidth=2.4;[face stroke];[p moveToPoint:CGPointMake(24,13)];[p addLineToPoint:CGPointMake(24,24)];[p addLineToPoint:CGPointMake(33,29)];[p stroke];break;}
 case 12:{[p addArcWithCenter:CGPointMake(24,25) radius:17 startAngle:-M_PI*.28 endAngle:M_PI*1.28 clockwise:YES];[p stroke];[p removeAllPoints];[p moveToPoint:CGPointMake(24,5)];[p addLineToPoint:CGPointMake(24,25)];[p stroke];break;}
 case 10:{[p moveToPoint:CGPointMake(5,23)];[p addLineToPoint:CGPointMake(24,7)];[p addLineToPoint:CGPointMake(43,23)];[p moveToPoint:CGPointMake(10,20)];[p addLineToPoint:CGPointMake(10,41)];[p addLineToPoint:CGPointMake(20,41)];[p addLineToPoint:CGPointMake(20,29)];[p addLineToPoint:CGPointMake(29,29)];[p addLineToPoint:CGPointMake(29,41)];[p addLineToPoint:CGPointMake(38,41)];[p addLineToPoint:CGPointMake(38,20)];[p stroke];break;}
 case 11:{for(int i=0;i<3;i++){CGFloat x=12+i*12;[p moveToPoint:CGPointMake(x,6)];[p addLineToPoint:CGPointMake(x,42)];}[p stroke];for(int i=0;i<3;i++){CGFloat x=12+i*12,y=i==1?29:17;[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(x-5,y-4,10,8) cornerRadius:2]fill];}break;}
 case 7:case 9:{[red setFill];BOOL next=self.kind==9;CGFloat left=next?10:36,right=next?34:14;[p moveToPoint:CGPointMake(left,10)];[p addLineToPoint:CGPointMake(right,24)];[p addLineToPoint:CGPointMake(left,38)];[p closePath];[p fill];UIRectFill(CGRectMake(next?36:8,10,4,28));break;}
 case 8:{[[UIColor lightGrayColor]setFill];for(int i=0;i<3;i++)[[UIBezierPath bezierPathWithOvalInRect:CGRectMake(8+i*13,21,6,6)]fill];break;}
 case 13:{[red setFill];[p moveToPoint:CGPointMake(12,8)];[p addLineToPoint:CGPointMake(38,24)];[p addLineToPoint:CGPointMake(12,40)];[p closePath];[p fill];break;}
 case 14:{[red setFill];UIRectFill(CGRectMake(12,9,8,30));UIRectFill(CGRectMake(28,9,8,30));break;}
  case 15:{[[UIColor whiteColor]setFill];for(int r=0;r<2;r++)for(int cl=0;cl<2;cl++){[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(11+cl*15,11+r*15,11,11) cornerRadius:3]fill];}break;}

 }
 CGContextRestoreGState(c);
}
@end
#import "TRDMini.h"
#import "TRDTripView.h"
@interface AudioBars:UIView
@property BOOL multicolor;
@property NSTimer *refreshTimer;
@property NSString *state;
@property float rms;
-(void)start;
-(void)stop;
@end
@implementation AudioBars
-(instancetype)init{if((self=[super init])){self.backgroundColor=[UIColor clearColor];self.userInteractionEnabled=NO;self.state=@"";self.multicolor=YES;}return self;}
-(void)start{}
-(void)stop{self.rms=0;self.state=@"";[self setNeedsDisplay];}
-(void)step{}
-(void)drawRect:(CGRect)rect{CGFloat w=self.bounds.size.width,h=self.bounds.size.height;if(w<=0||h<=0)return;CGFloat gap=3;CGFloat bw=MAX(0,(w-gap*17)/18);static const float kStaticPattern[18]={0.25,0.40,0.55,0.70,0.85,0.60,0.45,0.80,0.95,0.80,0.55,0.40,0.65,0.80,0.45,0.35,0.25,0.20};for(int i=0;i<18;i++){CGFloat bh=2+kStaticPattern[i]*MAX(0,h-4);UIColor *tint=self.multicolor?[UIColor colorWithHue:.52+.45*i/17.0 saturation:.82 brightness:1 alpha:.35]:[UIColor colorWithWhite:.22 alpha:1];[tint setFill];UIRectFill(CGRectMake(i*(bw+gap),h-bh,bw,bh));}}
@end
@interface PriusWheel:UIView
@property(nonatomic) CGFloat angle;
@property(nonatomic,strong) UIImage *rim;
@property CALayer *rimLayer;
@end
@implementation PriusWheel
-(instancetype)init{if((self=[super init])){self.opaque=NO;self.userInteractionEnabled=NO;}return self;}
-(void)setRim:(UIImage *)rim{_rim=rim;}
-(void)setAngle:(CGFloat)angle{_angle=angle;}
@end
@interface DrivePrius:UIView
@property UIImageView *body;
@property PriusWheel *front,*rear;
@property NSTimer *wheelTimer;
@property CGFloat kmh,angle;
@property CFTimeInterval lastTick;
-(void)setSpeed:(CGFloat)speed;
-(void)stop;
@end
@implementation DrivePrius
-(instancetype)init{if((self=[super init])){self.userInteractionEnabled=NO;self.body=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"TRDRealPrius.png"]];self.body.contentMode=UIViewContentModeScaleAspectFit;[self addSubview:self.body];}return self;}
-(void)layoutSubviews{[super layoutSubviews];self.body.frame=self.bounds;}
-(void)setSpeed:(CGFloat)speed{self.kmh=MAX(0,speed);}
-(void)startRotation{}
-(void)spin{}
-(void)stop{self.kmh=0;}
@end
@interface Dashboard:UIViewController<CLLocationManagerDelegate,UIGestureRecognizerDelegate,UIWebViewDelegate>
@property NSString *audioOutput,*audioOutputShort,*audioDevice;
@property float outputVolume;
-(void)refreshAudioRoute;
-(void)audioOutputSettings;
@property NSInteger displayMode;
@property TRDTrip *trip;
@property NSDate *lastTripSavedAt;
@property TRDTripView *tripView;
@property TRDMini *miniPlayer;
@property UIButton *tripButton,*radioButton,*driveTripButton,*driveCameraButton;
@property BOOL hadGPSSpeed;
@property BOOL tripMode;
@property BOOL mapMode;
@property UIView *mapContainer;
@property UIWebView *mapWebView;
-(void)openMap;
-(void)updateMapCar;
-(void)loadMapHTML;
-(UIWebView *)ensureMapWebView;
-(void)openTrip;
-(void)toggleTrip;
-(void)resetTripMenu;
-(void)refreshTrip;
-(void)refreshMini;
-(void)saveTrip;
-(void)miniPlay;
-(void)miniOpen;
-(void)quickPages;
-(void)musicHold:(UILongPressGestureRecognizer *)gesture;
-(void)homeHold:(UILongPressGestureRecognizer *)gesture;
@property BOOL calmDrive,gpsLive;
@property NSArray *statusChips;
@property UIView *statusStrip;
@property NSString *statusWiFi,*statusCar,*statusPower;
-(void)openCamera;
-(void)captureLifecycle;
-(void)applyMotionPolicy;
-(void)refreshStatusStrip;
-(void)toggleCalmDrive;

@property TRDSettingsMenu *settingsSheet;
@property BOOL hasPlaybackRate;
@property BOOL youtubeSource;
@property NSData *artworkData;
@property NSUInteger artworkDecodes,metadataGeneration,commandsPending;
@property BOOL metadataPending;
@property double metadataRequestedAt;
@property NSUInteger memoryWarnings;
-(void)releaseArtwork;

-(void)refreshNowPlaying;
-(void)refreshTransportState;
@property CarWelcome *welcome;
@property BOOL didShowWelcome;
-(void)showWelcome;
-(void)hideWelcome;
-(void)applyDisplaySchedule;
-(void)applyTheme;
-(void)carSettings;
-(void)displaySettings;
-(void)themeSettings;
-(void)soundProfileSettings;
-(void)chooseProfile:(NSString *)bundle title:(NSString *)title;
-(void)screenOff;
-(void)restoreDisplayBrightness;

@property UIView *navigation;
@property NSArray *navButtons;
@property BOOL musicMode;
@property UIButton *browseMusic;
@property UILabel *musicHeading;
-(void)openMusic;
-(void)browseSource:(NSString *)bundle;
-(void)cancelBrowseReturn;
-(void)homePage;
-(void)showMusicSources:(UIButton *)anchor;

@property UIButton *driveEQ;
@property DrivePrius *driveCar;
@property UILabel *trackTime;
@property UIProgressView *trackProgress;
@property double mediaElapsed,mediaDuration,mediaRate;
@property BOOL hasElapsed;
@property NSDate *mediaTimestamp;
@property BOOL driveMode;
@property BOOL autoDriveSuppressed;
@property BOOL carplayMode,carplayGridMode;
@property UIView *carplayDock,*carplayMediaCard,*carplayTelemetryCard,*carplayAppGrid,*carplayTurnBanner;
@property UIButton *carplayHomeBtn,*carplayRearCamBtn,*carplayEQBtn;
@property NSMutableArray *carplayDockButtons,*carplayGridButtons;
@property UILabel *carplayClock,*carplayBattery,*carplayWifi;
@property UILabel *carplaySpeedVal,*carplaySpeedUnit,*carplaySpeedLimit,*carplayCompass,*carplayTrip;
@property UILabel *carplayTurnDist,*carplayTurnStreet;
-(void)openCarPlay;
-(void)toggleCarPlayGrid;
-(void)carplayTapMap;
-(void)carplayTapMusic;
-(void)carplayGridMusic;
-(void)carplayGridMap;
-(void)carplayGridTrip;
-(void)carplayGridSettings;
-(void)handleEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture;
@property UISwipeGestureRecognizer *swL,*swR;
@property UIScreenEdgePanGestureRecognizer *edgeR;
-(void)openYouTubeSource;
@property NSDate *movingSince,*stationarySince;
@property UIButton *driveButton;
@property UIButton *modeButton;
@property UILabel *compassLabel;
@property UIButton *speedLimitBtn;
@property UILabel *energyFlowLabel;
@property NSInteger speedLimit;
-(void)toggleSpeedLimit;
-(void)cycleDriveMode;
@property AudioBars *audioBars;
@property UIImageView *artwork;
@property UILabel *artPlaceholder,*artist,*carStatus;
@property UIView *nowPanel;
@property UIButton *nightButton;
@property BOOL nightMode;
@property CGFloat dayBrightness;
@property SportPanel *panel;
@property UIImageView *carImage;
@property UIView *carGlow;
@property CLLocationManager *gps;
@property CLLocation *fix;
@property NSString *gpsError;
@property NSUInteger gpsUpdates;
-(void)captureGPSState;
@property UILabel *speed,*unit,*gpsStatus;
@property CAShapeLayer *arc,*progress;
@property UILabel *owner;
@property UILabel *heading,*clock,*date,*network,*song,*hint;
@property NSMutableArray *cards;
@property UIView *controls;
@property NSTimer *timer;
@property BOOL focused;
@property UILabel *sourceBadge;
-(void)openActiveSourceApp;
@property UIView *clockHud;
-(void)refreshClockHud;
@property UITapGestureRecognizer *returnTap;
@property NSDateFormatter *clockFormat,*dateFormat;
@property id bluetooth;
@property NSString *notice;
@property NSDate *noticeUntil;
@property NSUInteger ticks;
@property NSString *lastAction;
@property NSDate *lastSpeedWarnDate;
@property UIView *tripSummaryCard;
@property AVPlayer *radioPlayer;
@property NSString *currentRadioStation;
-(void)showTripSummary;
-(void)hideTripSummary;
-(void)openRadioStationsMenu;
-(void)playRadio:(NSString *)url name:(NSString *)name;
-(void)openPhoneMenu;
-(void)promptCustomCall;
-(void)callNumber:(NSString *)num;
-(void)showPhoneContinuityGuide;
@end
@implementation Dashboard
#import "CarExtrasMethods.h"
#import "TRDTripMethods.h"
-(UILabel *)label:(CGFloat)size color:(UIColor *)color{UILabel *l=[UILabel new];l.font=[UIFont systemFontOfSize:size];l.textColor=color;[self.view addSubview:l];return l;}
-(void)viewDidLoad{
 [super viewDidLoad];self.trip=[TRDTrip new];[self.trip restore:[[NSUserDefaults standardUserDefaults]dictionaryForKey:@"TRDTripSummary"]];TRDTheme=MAX(0,MIN(2,[[NSUserDefaults standardUserDefaults]integerForKey:@"TRDTheme"]));self.displayMode=MAX(0,MIN(2,[[NSUserDefaults standardUserDefaults]integerForKey:@"TRDDisplayMode"]));self.panel=[[SportPanel alloc]initWithFrame:self.view.bounds];self.panel.userInteractionEnabled=NO;self.panel.opaque=YES;[self.view addSubview:self.panel];self.view.backgroundColor=[UIColor colorWithRed:.025 green:.025 blue:.03 alpha:1];UIColor *blue=TRDAccent();self.heading=[self label:18 color:blue];self.heading.text=[NSString stringWithFormat:@"PRIUS  TRD  /  %@",TRDDriveModeName(TRDTheme)];self.heading.font=[UIFont boldSystemFontOfSize:18];self.owner=[self label:10 color:[UIColor colorWithWhite:.55 alpha:1]];self.owner.text=@"PEEPUT’S DRIVE";self.owner.font=[UIFont boldSystemFontOfSize:10];
 NSUserDefaults *wheelPrefs=[NSUserDefaults standardUserDefaults];if(![wheelPrefs boolForKey:@"TRDOptimizedWheelEnabledV1"]){[wheelPrefs setBool:NO forKey:@"TRDCalmDrive"];[wheelPrefs setBool:YES forKey:@"TRDOptimizedWheelEnabledV1"];[wheelPrefs synchronize];}self.calmDrive=[wheelPrefs boolForKey:@"TRDCalmDrive"];self.nightMode=[[NSUserDefaults standardUserDefaults]boolForKey:@"nightMode"];TRDLowLight=self.nightMode;self.dayBrightness=[[NSUserDefaults standardUserDefaults]objectForKey:@"dayBrightness"]?[[NSUserDefaults standardUserDefaults]doubleForKey:@"dayBrightness"]:.6;if(self.dayBrightness<.15)self.dayBrightness=.6;
 self.nightButton=[UIButton buttonWithType:UIButtonTypeSystem];self.nightButton.backgroundColor=[UIColor colorWithRed:.13 green:.045 blue:.06 alpha:1];self.nightButton.layer.cornerRadius=6;self.nightButton.layer.borderWidth=1;self.nightButton.layer.borderColor=blue.CGColor;[self.nightButton setTitleColor:blue forState:UIControlStateNormal];self.nightButton.titleLabel.font=[UIFont boldSystemFontOfSize:14];[self.nightButton setTitle:self.nightMode?@"DAY MODE":@"NIGHT MODE" forState:UIControlStateNormal];[self.nightButton addTarget:self action:@selector(carSettings) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.nightButton];
 self.modeButton=[UIButton buttonWithType:UIButtonTypeSystem];self.modeButton.backgroundColor=[UIColor colorWithWhite:.10 alpha:1];self.modeButton.layer.cornerRadius=6;self.modeButton.layer.borderWidth=1;self.modeButton.layer.borderColor=blue.CGColor;[self.modeButton setTitle:[NSString stringWithFormat:@"[ %@ ]",TRDDriveModeName(TRDTheme)] forState:UIControlStateNormal];[self.modeButton setTitleColor:blue forState:UIControlStateNormal];self.modeButton.titleLabel.font=[UIFont boldSystemFontOfSize:12];[self.modeButton addTarget:self action:@selector(cycleDriveMode) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.modeButton];
 self.driveButton=[UIButton buttonWithType:UIButtonTypeSystem];self.driveButton.backgroundColor=[UIColor colorWithWhite:.10 alpha:1];self.driveButton.layer.cornerRadius=6;self.driveButton.layer.borderWidth=1;self.driveButton.layer.borderColor=[UIColor colorWithWhite:.30 alpha:1].CGColor;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];[self.driveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];self.driveButton.titleLabel.font=[UIFont boldSystemFontOfSize:12];[self.driveButton addTarget:self action:@selector(toggleDrive) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveButton];
 self.driveEQ=[UIButton buttonWithType:UIButtonTypeSystem];[self.driveEQ setTitle:@"EQ  /  SOUND" forState:UIControlStateNormal];[self.driveEQ setTitleColor:blue forState:UIControlStateNormal];self.driveEQ.titleLabel.font=[UIFont boldSystemFontOfSize:16];self.driveEQ.backgroundColor=[UIColor colorWithRed:.12 green:.04 blue:.06 alpha:1];self.driveEQ.layer.cornerRadius=6;self.driveEQ.layer.borderWidth=1;self.driveEQ.layer.borderColor=[UIColor colorWithRed:.35 green:.10 blue:.13 alpha:1].CGColor;self.driveEQ.accessibilityLabel=@"Open Equalizer";[self.driveEQ addTarget:self action:@selector(openDriveEQ) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveEQ];
 self.driveCar=[[DrivePrius alloc]init];self.driveCar.hidden=YES;[self.view addSubview:self.driveCar];
 self.carGlow=[UIView new];self.carGlow.userInteractionEnabled=NO;self.carGlow.hidden=YES;CAGradientLayer *glow=[CAGradientLayer layer];glow.name=@"carGlow";glow.startPoint=CGPointMake(0,.5);glow.endPoint=CGPointMake(1,.5);[self.carGlow.layer addSublayer:glow];[self.view addSubview:self.carGlow];
 self.carImage=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"TRDRealPrius.png"]];self.carImage.contentMode=UIViewContentModeScaleAspectFit;[self.view addSubview:self.carImage];
 self.arc=[CAShapeLayer layer];self.arc.fillColor=[UIColor clearColor].CGColor;self.arc.strokeColor=[UIColor colorWithWhite:.15 alpha:1].CGColor;self.arc.lineWidth=5;self.arc.lineCap=kCALineCapRound;[self.view.layer addSublayer:self.arc];
 self.progress=[CAShapeLayer layer];self.progress.fillColor=[UIColor clearColor].CGColor;self.progress.strokeColor=blue.CGColor;self.progress.lineWidth=5;self.progress.lineCap=kCALineCapRound;self.progress.strokeEnd=0;[self.view.layer addSublayer:self.progress];
 self.speed=[self label:110 color:[UIColor whiteColor]];self.speed.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:110];self.speed.textAlignment=NSTextAlignmentCenter;self.speed.text=@"--";
 self.unit=[self label:16 color:blue];self.unit.text=@"km/h  /  GPS";self.unit.textAlignment=NSTextAlignmentCenter;
 self.gpsStatus=[self label:13 color:[UIColor lightGrayColor]];self.gpsStatus.textAlignment=NSTextAlignmentCenter;self.gpsStatus.text=@"WAITING FOR GPS";
 self.compassLabel=[self label:13 color:blue];self.compassLabel.textAlignment=NSTextAlignmentCenter;self.compassLabel.text=@"🧭 N  000°";self.compassLabel.font=[UIFont boldSystemFontOfSize:12];
 self.speedLimit=90;
 self.speedLimitBtn=[UIButton buttonWithType:UIButtonTypeCustom];self.speedLimitBtn.backgroundColor=[UIColor colorWithRed:.85 green:.05 blue:.10 alpha:.18];self.speedLimitBtn.layer.cornerRadius=14;self.speedLimitBtn.layer.borderWidth=2;self.speedLimitBtn.layer.borderColor=[UIColor colorWithRed:.95 green:.10 blue:.15 alpha:.9].CGColor;[self.speedLimitBtn setTitle:@"90" forState:UIControlStateNormal];[self.speedLimitBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];self.speedLimitBtn.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.speedLimitBtn addTarget:self action:@selector(toggleSpeedLimit) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.speedLimitBtn];
 self.energyFlowLabel=[self label:12 color:[UIColor colorWithRed:.0 green:.9 blue:.5 alpha:1]];self.energyFlowLabel.textAlignment=NSTextAlignmentCenter;self.energyFlowLabel.font=[UIFont boldSystemFontOfSize:11];self.energyFlowLabel.text=@"⚡ EV MOTOR · READY";
 self.gps=[CLLocationManager new];self.gps.delegate=self;self.gps.desiredAccuracy=kCLLocationAccuracyBest;self.gps.distanceFilter=kCLDistanceFilterNone;self.gps.activityType=CLActivityTypeAutomotiveNavigation;
 self.audioBars=[[AudioBars alloc]init];[self.view addSubview:self.audioBars];
 self.network=[self label:14 color:[UIColor lightGrayColor]];self.network.textAlignment=NSTextAlignmentRight;self.network.hidden=YES;
 self.statusStrip=[UIView new];[self.view addSubview:self.statusStrip];NSMutableArray *chips=[NSMutableArray array];for(NSString *name in @[@"CAR BT",@"WI-FI",@"AUDIO",@"GPS",@"POWER"]){UIButton *chip=[UIButton buttonWithType:UIButtonTypeCustom];chip.backgroundColor=[UIColor colorWithWhite:.055 alpha:1];chip.layer.cornerRadius=5;chip.layer.borderWidth=1;chip.layer.borderColor=[UIColor colorWithWhite:.14 alpha:1].CGColor;chip.tag=310+chips.count;[chip addTarget:self action:@selector(statusChipTapped:) forControlEvents:UIControlEventTouchUpInside];UILabel *title=[UILabel new];title.tag=301;title.text=name;title.font=[UIFont boldSystemFontOfSize:8];title.textColor=[UIColor colorWithWhite:.48 alpha:1];title.textAlignment=NSTextAlignmentCenter;title.userInteractionEnabled=NO;[chip addSubview:title];UILabel *value=[UILabel new];value.tag=302;value.font=[UIFont boldSystemFontOfSize:11];value.adjustsFontSizeToFitWidth=YES;value.minimumScaleFactor=.7;value.textColor=[UIColor lightGrayColor];value.textAlignment=NSTextAlignmentCenter;value.lineBreakMode=NSLineBreakByTruncatingMiddle;value.userInteractionEnabled=NO;[chip addSubview:value];[self.statusStrip addSubview:chip];[chips addObject:chip];}self.statusChips=chips;
 self.clock=[self label:160 color:[UIColor whiteColor]];self.clock.font=[UIFont fontWithName:@"HelveticaNeue-UltraLight" size:160]?:[UIFont systemFontOfSize:160];self.clock.textAlignment=NSTextAlignmentCenter;self.clock.adjustsFontSizeToFitWidth=YES;
 self.date=[self label:22 color:[UIColor colorWithWhite:.72 alpha:1]];self.date.textAlignment=NSTextAlignmentCenter;
 self.nowPanel=[[UIView alloc]init];self.nowPanel.backgroundColor=[UIColor colorWithWhite:.055 alpha:.95];self.nowPanel.layer.cornerRadius=6;self.nowPanel.layer.borderWidth=1;self.nowPanel.layer.borderColor=[UIColor colorWithWhite:.17 alpha:1].CGColor;[self.view addSubview:self.nowPanel];
 self.sourceBadge=[[UILabel alloc]init];self.sourceBadge.font=[UIFont boldSystemFontOfSize:10];self.sourceBadge.textAlignment=NSTextAlignmentCenter;self.sourceBadge.layer.cornerRadius=4;self.sourceBadge.clipsToBounds=YES;self.sourceBadge.textColor=[UIColor whiteColor];self.sourceBadge.backgroundColor=[blue colorWithAlphaComponent:.28];self.sourceBadge.layer.borderWidth=1;self.sourceBadge.layer.borderColor=[blue colorWithAlphaComponent:.6].CGColor;self.sourceBadge.text=@"MUSIC";self.sourceBadge.userInteractionEnabled=YES;UITapGestureRecognizer *btap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openActiveSourceApp)];[self.sourceBadge addGestureRecognizer:btap];[self.nowPanel addSubview:self.sourceBadge];
 self.artwork=[[UIImageView alloc]init];self.artwork.contentMode=UIViewContentModeScaleAspectFill;self.artwork.clipsToBounds=YES;self.artwork.layer.cornerRadius=4;[self.view addSubview:self.artwork];self.artPlaceholder=[self label:28 color:blue];self.artPlaceholder.text=@"♫";self.artPlaceholder.textAlignment=NSTextAlignmentCenter;
 self.trackTime=[self label:10 color:[UIColor colorWithWhite:.65 alpha:1]];self.trackTime.textAlignment=NSTextAlignmentRight;self.trackTime.adjustsFontSizeToFitWidth=YES;self.trackTime.text=@"--:-- / --:--";self.trackProgress=[[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];self.trackProgress.progressTintColor=blue;self.trackProgress.trackTintColor=[UIColor colorWithWhite:.18 alpha:1];self.trackProgress.userInteractionEnabled=NO;[self.view addSubview:self.trackProgress];
 self.artist=[self label:12 color:[UIColor lightGrayColor]];self.artist.adjustsFontSizeToFitWidth=YES;
 self.carStatus=[self label:13 color:[UIColor lightGrayColor]];self.carStatus.textAlignment=NSTextAlignmentCenter;self.carStatus.text=@"CAR DISCONNECTED";self.carStatus.font=[UIFont boldSystemFontOfSize:13];
 self.song=[self label:18 color:[UIColor colorWithRed:1 green:.78 blue:.42 alpha:1]];self.song.textAlignment=NSTextAlignmentLeft;self.song.adjustsFontSizeToFitWidth=YES;
 self.hint=[self label:15 color:[UIColor grayColor]];self.hint.textAlignment=NSTextAlignmentCenter;self.hint.text=@"Tap anywhere to return";self.hint.hidden=YES;
 self.clockHud=[[UIView alloc]init];self.clockHud.backgroundColor=[UIColor colorWithRed:.05 green:.05 blue:.06 alpha:.94];self.clockHud.layer.cornerRadius=8;self.clockHud.layer.borderWidth=1;self.clockHud.layer.borderColor=[blue colorWithAlphaComponent:.38].CGColor;self.clockHud.userInteractionEnabled=NO;self.clockHud.hidden=YES;[self.view addSubview:self.clockHud];UIView *hudAccent=[[UIView alloc]initWithFrame:CGRectMake(0,16,4,76)];hudAccent.tag=401;hudAccent.backgroundColor=blue;[self.clockHud addSubview:hudAccent];UILabel *hudSpeed=[[UILabel alloc]initWithFrame:CGRectMake(16,8,168,70)];hudSpeed.tag=402;hudSpeed.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:72]?:[UIFont boldSystemFontOfSize:72];hudSpeed.textColor=[UIColor whiteColor];hudSpeed.textAlignment=NSTextAlignmentCenter;hudSpeed.adjustsFontSizeToFitWidth=YES;hudSpeed.text=@"--";[self.clockHud addSubview:hudSpeed];UILabel *hudUnit=[[UILabel alloc]initWithFrame:CGRectMake(16,76,168,22)];hudUnit.tag=403;hudUnit.font=[UIFont boldSystemFontOfSize:13];hudUnit.textColor=blue;hudUnit.textAlignment=NSTextAlignmentCenter;hudUnit.text=@"km/h  •  GPS HUD";[self.clockHud addSubview:hudUnit];UIView *hudDiv=[[UIView alloc]initWithFrame:CGRectMake(196,18,1,72)];hudDiv.tag=404;hudDiv.backgroundColor=[UIColor colorWithWhite:.18 alpha:1];[self.clockHud addSubview:hudDiv];UILabel *hudGps=[[UILabel alloc]initWithFrame:CGRectMake(214,16,230,22)];hudGps.tag=405;hudGps.font=[UIFont boldSystemFontOfSize:13];hudGps.textColor=[UIColor colorWithWhite:.76 alpha:1];hudGps.adjustsFontSizeToFitWidth=YES;hudGps.text=@"WAITING FOR GPS";[self.clockHud addSubview:hudGps];UILabel *hudAcc=[[UILabel alloc]initWithFrame:CGRectMake(214,43,230,20)];hudAcc.tag=406;hudAcc.font=[UIFont systemFontOfSize:12];hudAcc.textColor=[UIColor colorWithWhite:.55 alpha:1];hudAcc.adjustsFontSizeToFitWidth=YES;hudAcc.text=@"SIGNAL  •  SEARCHING SATELLITES";[self.clockHud addSubview:hudAcc];UILabel *hudTrip=[[UILabel alloc]initWithFrame:CGRectMake(214,68,230,22)];hudTrip.tag=407;hudTrip.font=[UIFont boldSystemFontOfSize:12];hudTrip.textColor=blue;hudTrip.adjustsFontSizeToFitWidth=YES;hudTrip.text=@"TRIP  AUTO  •  WAITING FOR MOVEMENT";[self.clockHud addSubview:hudTrip];
 self.clockFormat=[NSDateFormatter new];self.clockFormat.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];self.clockFormat.dateFormat=@"HH:mm";self.dateFormat=[NSDateFormatter new];self.dateFormat.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];self.dateFormat.dateFormat=@"EEEE, d MMMM yyyy";
 self.cards=[NSMutableArray array];NSArray *names=@[@"YouTube",@"Music",@"Maps",@"Camera",@"Settings",@"Full Clock"];
 for(int i=0;i<6;i++){UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=i+1;b.backgroundColor=[UIColor colorWithRed:.065 green:.065 blue:.075 alpha:1];b.layer.cornerRadius=7;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithRed:.25 green:.12 blue:.14 alpha:1].CGColor;UILabel *title=[UILabel new];title.tag=100;title.text=names[i];title.font=[UIFont boldSystemFontOfSize:24];title.textColor=i==0?blue:[UIColor whiteColor];[b addSubview:title];DashIcon *icon=[[DashIcon alloc]init];icon.kind=i+1;icon.tag=104;icon.backgroundColor=[UIColor clearColor];icon.userInteractionEnabled=NO;[b addSubview:icon];b.accessibilityLabel=names[i];UIView *accent=[[UIView alloc]init];accent.tag=102;accent.backgroundColor=blue;accent.userInteractionEnabled=NO;[b addSubview:accent];title.userInteractionEnabled=NO;[b addTarget:self action:@selector(card:) forControlEvents:UIControlEventTouchUpInside];[self.cards addObject:b];[self.view addSubview:b];}
 self.controls=[UIView new];[self.view addSubview:self.controls];NSArray *commands=@[@"Previous",@"Play / Pause",@"Next",@"Equalizer"];for(int i=0;i<4;i++){UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.tag=20+i;b.backgroundColor=[UIColor colorWithRed:.11 green:.055 blue:.065 alpha:1];b.layer.cornerRadius=7;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithRed:.35 green:.10 blue:.13 alpha:1].CGColor;b.accessibilityLabel=commands[i];if(i<3){DashIcon *icon=[[DashIcon alloc]init];icon.kind=7+i;icon.tag=105;icon.backgroundColor=[UIColor clearColor];icon.userInteractionEnabled=NO;[b addSubview:icon];}else [b setTitle:commands[i] forState:UIControlStateNormal];[b setTitleColor:blue forState:UIControlStateNormal];b.titleLabel.font=[UIFont boldSystemFontOfSize:22];[b addTarget:self action:@selector(media:) forControlEvents:UIControlEventTouchUpInside];[self.controls addSubview:b];}
 self.navigation=[UIView new];self.navigation.backgroundColor=[UIColor colorWithWhite:.035 alpha:1];self.navigation.layer.borderWidth=1;self.navigation.layer.borderColor=[UIColor colorWithWhite:.16 alpha:1].CGColor;[self.view addSubview:self.navigation];NSMutableArray *nav=[NSMutableArray array];NSArray *navNames=@[@"HOME",@"CARPLAY",@"MUSIC",@"MAPS",@"CAMERA",@"SOUND"];NSInteger kinds[]={10,15,2,3,4,11};NSInteger tags[]={60,66,61,62,65,63};for(int i=0;i<6;i++){UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=tags[i];b.accessibilityLabel=navNames[i];b.layer.cornerRadius=8;DashIcon *icon=[DashIcon new];icon.kind=kinds[i];icon.tag=201;icon.backgroundColor=[UIColor clearColor];icon.userInteractionEnabled=NO;[b addSubview:icon];UILabel *text=[UILabel new];text.tag=202;text.text=navNames[i];text.textColor=[UIColor lightGrayColor];text.font=[UIFont boldSystemFontOfSize:15];text.userInteractionEnabled=NO;[b addSubview:text];UIView *line=[UIView new];line.tag=203;line.backgroundColor=blue;line.userInteractionEnabled=NO;[b addSubview:line];[b addTarget:self action:@selector(navigate:) forControlEvents:UIControlEventTouchUpInside];[self.navigation addSubview:b];[nav addObject:b];}self.navButtons=nav;
 self.musicHeading=[self label:16 color:blue];self.musicHeading.text=@"NOW PLAYING";self.musicHeading.font=[UIFont boldSystemFontOfSize:16];self.musicHeading.hidden=YES;self.browseMusic=[UIButton buttonWithType:UIButtonTypeCustom];[self.browseMusic setTitle:@"Browse music" forState:UIControlStateNormal];self.browseMusic.titleLabel.font=[UIFont boldSystemFontOfSize:16];self.browseMusic.backgroundColor=[UIColor colorWithWhite:.09 alpha:1];self.browseMusic.layer.cornerRadius=7;self.browseMusic.layer.borderWidth=1;self.browseMusic.layer.borderColor=[UIColor colorWithWhite:.25 alpha:1].CGColor;[self.browseMusic addTarget:self action:@selector(showMusicSources:) forControlEvents:UIControlEventTouchUpInside];self.browseMusic.hidden=YES;[self.view addSubview:self.browseMusic];[self.nowPanel addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openMusic)]];
 self.tripView=[TRDTripView new];self.tripView.hidden=YES;[self.view addSubview:self.tripView];[self.tripView.run addTarget:self action:@selector(toggleTrip) forControlEvents:UIControlEventTouchUpInside];[self.tripView.reset addTarget:self action:@selector(resetTripMenu) forControlEvents:UIControlEventTouchUpInside];[self.tripView.close addTarget:self action:@selector(homePage) forControlEvents:UIControlEventTouchUpInside];self.driveTripButton=[UIButton buttonWithType:UIButtonTypeCustom];self.driveTripButton.titleLabel.font=[UIFont boldSystemFontOfSize:14];self.driveTripButton.titleLabel.adjustsFontSizeToFitWidth=YES;self.driveTripButton.titleLabel.minimumScaleFactor=.8;self.driveTripButton.backgroundColor=[UIColor colorWithWhite:.055 alpha:1];self.driveTripButton.layer.cornerRadius=8;self.driveTripButton.layer.borderWidth=1;self.driveTripButton.layer.borderColor=[UIColor colorWithWhite:.2 alpha:1].CGColor;self.driveTripButton.accessibilityLabel=@"Open GPS trip summary";UIGraphicsBeginImageContextWithOptions(CGSizeMake(24,24),NO,0);[[UIColor whiteColor]setStroke];UIBezierPath *pin=[UIBezierPath bezierPath];pin.lineWidth=1.8;[pin moveToPoint:CGPointMake(12,22)];[pin addCurveToPoint:CGPointMake(4,9) controlPoint1:CGPointMake(10,18) controlPoint2:CGPointMake(4,13)];[pin addArcWithCenter:CGPointMake(12,9) radius:8 startAngle:M_PI endAngle:0 clockwise:YES];[pin addCurveToPoint:CGPointMake(12,22) controlPoint1:CGPointMake(20,13) controlPoint2:CGPointMake(14,18)];[pin stroke];UIBezierPath *pinCenter=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9,6,6,6)];pinCenter.lineWidth=1.6;[pinCenter stroke];UIImage *tripIcon=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();[self.driveTripButton setImage:[tripIcon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];self.driveTripButton.imageEdgeInsets=UIEdgeInsetsMake(0,-8,0,0);self.driveTripButton.titleEdgeInsets=UIEdgeInsetsMake(0,5,0,0);[self.driveTripButton addTarget:self action:@selector(openTrip) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveTripButton];
 self.driveCameraButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.driveCameraButton setTitle:@"CAMERA" forState:0];self.driveCameraButton.titleLabel.font=[UIFont boldSystemFontOfSize:22];self.driveCameraButton.backgroundColor=[TRDAccent()colorWithAlphaComponent:.20];self.driveCameraButton.layer.cornerRadius=8;self.driveCameraButton.layer.borderWidth=1.5;self.driveCameraButton.layer.borderColor=[TRDAccent()colorWithAlphaComponent:.8].CGColor;self.driveCameraButton.accessibilityLabel=@"Open live camera";self.driveCameraButton.accessibilityHint=@"View blind spots and follow the main camera";[self.driveCameraButton addTarget:self action:@selector(openCamera) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveCameraButton];
 self.tripButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.tripButton setTitle:@"TRIP / GPS ›" forState:0];self.tripButton.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.tripButton setTitleColor:TRDAccent() forState:0];self.tripButton.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.tripButton.layer.cornerRadius=6;[self.tripButton addTarget:self action:@selector(openTrip) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.tripButton];
 self.radioButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.radioButton setTitle:@"📻 RADIO" forState:0];self.radioButton.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.radioButton setTitleColor:TRDAccent() forState:0];self.radioButton.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.radioButton.layer.cornerRadius=6;self.radioButton.layer.borderWidth=1;self.radioButton.layer.borderColor=[TRDAccent() colorWithAlphaComponent:.4].CGColor;[self.radioButton addTarget:self action:@selector(openRadioStationsMenu) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.radioButton];
 self.miniPlayer=[TRDMini new];self.miniPlayer.hidden=YES;[self.miniPlayer.prev addTarget:self action:@selector(miniPrev) forControlEvents:UIControlEventTouchUpInside];[self.miniPlayer.play addTarget:self action:@selector(miniPlay) forControlEvents:UIControlEventTouchUpInside];[self.miniPlayer.next addTarget:self action:@selector(miniNext) forControlEvents:UIControlEventTouchUpInside];[self.miniPlayer.open addTarget:self action:@selector(miniOpen) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.miniPlayer];UILongPressGestureRecognizer *musicHold=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(musicHold:)];musicHold.minimumPressDuration=.55;[self.navButtons[1]addGestureRecognizer:musicHold];UILongPressGestureRecognizer *homeHold=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(homeHold:)];homeHold.minimumPressDuration=.55;[self.navButtons[0]addGestureRecognizer:homeHold];
 self.mapContainer=[[UIView alloc]init];self.mapContainer.backgroundColor=[UIColor colorWithRed:.06 green:.06 blue:.07 alpha:1];self.mapContainer.layer.cornerRadius=8;self.mapContainer.layer.borderWidth=1;self.mapContainer.layer.borderColor=[blue colorWithAlphaComponent:.35].CGColor;self.mapContainer.clipsToBounds=YES;self.mapContainer.hidden=YES;[self.view addSubview:self.mapContainer];

  // CarPlay Left Dock
  self.carplayDock=[[UIView alloc]init];self.carplayDock.backgroundColor=[UIColor colorWithRed:.06 green:.07 blue:.09 alpha:.96];self.carplayDock.layer.borderWidth=1;self.carplayDock.layer.borderColor=[UIColor colorWithWhite:.14 alpha:1].CGColor;self.carplayDock.userInteractionEnabled=YES;self.carplayDock.clipsToBounds=YES;self.carplayDock.hidden=YES;[self.view addSubview:self.carplayDock];
  self.carplayHomeBtn=[UIButton buttonWithType:UIButtonTypeCustom];self.carplayHomeBtn.backgroundColor=[UIColor colorWithRed:.12 green:.15 blue:.22 alpha:.85];self.carplayHomeBtn.layer.cornerRadius=16;self.carplayHomeBtn.layer.borderWidth=1.2;self.carplayHomeBtn.layer.borderColor=[UIColor colorWithWhite:1.0 alpha:.24].CGColor;self.carplayHomeBtn.showsTouchWhenHighlighted=YES;
  UIImageView *gridI=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"cp_dock_home.png"]];gridI.frame=CGRectMake(11,11,32,32);gridI.contentMode=UIViewContentModeScaleAspectFit;gridI.userInteractionEnabled=NO;[self.carplayHomeBtn addSubview:gridI];
  [self.carplayHomeBtn addTarget:self action:@selector(toggleCarPlayGrid) forControlEvents:UIControlEventTouchUpInside];[self.carplayDock addSubview:self.carplayHomeBtn];

  self.carplayDockButtons=[NSMutableArray array];
  NSInteger dKinds[]={3,2,1,4,11};SEL dSels[]={@selector(carplayTapMap),@selector(carplayTapMusic),@selector(openYouTubeSource),@selector(openCamera),@selector(openDriveEQ)};
  NSArray *dockIcons=@[@"cp_icon_maps.png",@"cp_icon_music.png",@"cp_icon_youtube.png",@"cp_icon_camera.png",@"cp_icon_eq.png"];
  for(int i=0;i<5;i++){UIButton *db=[UIButton buttonWithType:UIButtonTypeCustom];db.layer.cornerRadius=14;db.backgroundColor=[UIColor colorWithRed:.10 green:.12 blue:.18 alpha:.7];db.layer.borderWidth=1;db.layer.borderColor=[UIColor colorWithWhite:1.0 alpha:.18].CGColor;db.clipsToBounds=YES;db.showsTouchWhenHighlighted=YES;UIImageView *ic=[[UIImageView alloc]initWithImage:[UIImage imageNamed:dockIcons[i]]];ic.frame=CGRectMake(6,6,42,42);ic.contentMode=UIViewContentModeScaleAspectFit;ic.layer.cornerRadius=10;ic.clipsToBounds=YES;ic.userInteractionEnabled=NO;[db addSubview:ic];db.accessibilityLabel=@[@"Maps",@"Music",@"YouTube",@"Camera",@"Sound equalizer"][i];[db addTarget:self action:dSels[i] forControlEvents:UIControlEventTouchUpInside];[self.carplayDock addSubview:db];[self.carplayDockButtons addObject:db];}

  self.carplayClock=[[UILabel alloc]init];self.carplayClock.font=[UIFont boldSystemFontOfSize:14];self.carplayClock.textColor=[UIColor whiteColor];self.carplayClock.textAlignment=NSTextAlignmentCenter;[self.carplayDock addSubview:self.carplayClock];
  self.carplayBattery=[[UILabel alloc]init];self.carplayBattery.font=[UIFont boldSystemFontOfSize:11];self.carplayBattery.textColor=[UIColor colorWithRed:.2 green:.9 blue:.5 alpha:1];self.carplayBattery.textAlignment=NSTextAlignmentCenter;[self.carplayDock addSubview:self.carplayBattery];
  self.carplayWifi=[[UILabel alloc]init];self.carplayWifi.font=[UIFont boldSystemFontOfSize:9];self.carplayWifi.textColor=[UIColor colorWithRed:.3 green:.7 blue:1 alpha:1];self.carplayWifi.textAlignment=NSTextAlignmentCenter;self.carplayWifi.backgroundColor=[UIColor colorWithRed:.05 green:.15 blue:.30 alpha:.7];self.carplayWifi.layer.cornerRadius=3;self.carplayWifi.clipsToBounds=YES;[self.carplayDock addSubview:self.carplayWifi];

  // CarPlay Turn Banner inside map
  self.carplayTurnBanner=[[UIView alloc]init];self.carplayTurnBanner.userInteractionEnabled=NO;self.carplayTurnBanner.backgroundColor=[UIColor colorWithRed:.08 green:.10 blue:.14 alpha:.92];self.carplayTurnBanner.layer.cornerRadius=12;self.carplayTurnBanner.layer.borderWidth=1;self.carplayTurnBanner.layer.borderColor=[UIColor colorWithWhite:.22 alpha:1].CGColor;self.carplayTurnBanner.hidden=YES;[self.mapContainer addSubview:self.carplayTurnBanner];
  UILabel *tI=[[UILabel alloc]initWithFrame:CGRectMake(8,8,36,36)];tI.text=@"↗";tI.font=[UIFont boldSystemFontOfSize:26];tI.textColor=[UIColor colorWithRed:0 green:.85 blue:1 alpha:1];tI.textAlignment=NSTextAlignmentCenter;[self.carplayTurnBanner addSubview:tI];
  self.carplayTurnDist=[[UILabel alloc]initWithFrame:CGRectMake(50,7,260,16)];self.carplayTurnDist.font=[UIFont boldSystemFontOfSize:11];self.carplayTurnDist.textColor=[UIColor colorWithRed:0 green:.85 blue:1 alpha:1];self.carplayTurnDist.text=@"IN 350 METERS";[self.carplayTurnBanner addSubview:self.carplayTurnDist];
  self.carplayTurnStreet=[[UILabel alloc]initWithFrame:CGRectMake(50,23,260,22)];self.carplayTurnStreet.font=[UIFont boldSystemFontOfSize:14];self.carplayTurnStreet.textColor=[UIColor whiteColor];self.carplayTurnStreet.text=@"Rama IV Rd · Sukhumvit";[self.carplayTurnBanner addSubview:self.carplayTurnStreet];

  // CarPlay Media Card
  self.carplayMediaCard=[[UIView alloc]init];self.carplayMediaCard.backgroundColor=[UIColor colorWithWhite:.075 alpha:.98];self.carplayMediaCard.layer.cornerRadius=18;self.carplayMediaCard.layer.borderWidth=1;self.carplayMediaCard.layer.borderColor=[UIColor colorWithWhite:.18 alpha:1].CGColor;self.carplayMediaCard.hidden=YES;[self.view addSubview:self.carplayMediaCard];

  // CarPlay Telemetry Card
  self.carplayTelemetryCard=[[UIView alloc]init];self.carplayTelemetryCard.backgroundColor=[UIColor colorWithWhite:.075 alpha:.98];self.carplayTelemetryCard.layer.cornerRadius=18;self.carplayTelemetryCard.layer.borderWidth=1;self.carplayTelemetryCard.layer.borderColor=[UIColor colorWithWhite:.18 alpha:1].CGColor;self.carplayTelemetryCard.hidden=YES;[self.view addSubview:self.carplayTelemetryCard];

  self.carplaySpeedVal=[[UILabel alloc]init];self.carplaySpeedVal.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:56]?:[UIFont boldSystemFontOfSize:56];self.carplaySpeedVal.textColor=[UIColor whiteColor];self.carplaySpeedVal.text=@"0";[self.carplayTelemetryCard addSubview:self.carplaySpeedVal];
  self.carplaySpeedUnit=[[UILabel alloc]init];self.carplaySpeedUnit.font=[UIFont boldSystemFontOfSize:12];self.carplaySpeedUnit.textColor=[UIColor colorWithRed:0 green:.85 blue:1 alpha:1];self.carplaySpeedUnit.text=@"km/h  •  GPS LIVE";[self.carplayTelemetryCard addSubview:self.carplaySpeedUnit];

  self.carplaySpeedLimit=[[UILabel alloc]init];self.carplaySpeedLimit.font=[UIFont boldSystemFontOfSize:14];self.carplaySpeedLimit.textColor=[UIColor blackColor];self.carplaySpeedLimit.backgroundColor=[UIColor whiteColor];self.carplaySpeedLimit.layer.cornerRadius=17;self.carplaySpeedLimit.layer.borderWidth=3;self.carplaySpeedLimit.layer.borderColor=[UIColor colorWithRed:.9 green:.1 blue:.15 alpha:1].CGColor;self.carplaySpeedLimit.clipsToBounds=YES;self.carplaySpeedLimit.textAlignment=NSTextAlignmentCenter;self.carplaySpeedLimit.text=@"90";[self.carplayTelemetryCard addSubview:self.carplaySpeedLimit];

  self.carplayCompass=[[UILabel alloc]init];self.carplayCompass.font=[UIFont boldSystemFontOfSize:11];self.carplayCompass.textColor=[UIColor colorWithWhite:.8 alpha:1];self.carplayCompass.backgroundColor=[UIColor colorWithWhite:.15 alpha:1];self.carplayCompass.layer.cornerRadius=6;self.carplayCompass.clipsToBounds=YES;self.carplayCompass.textAlignment=NSTextAlignmentCenter;self.carplayCompass.text=@"🧭 N  012°";[self.carplayTelemetryCard addSubview:self.carplayCompass];

  self.carplayTrip=[[UILabel alloc]init];self.carplayTrip.font=[UIFont boldSystemFontOfSize:11];self.carplayTrip.textColor=[UIColor colorWithWhite:.8 alpha:1];self.carplayTrip.backgroundColor=[UIColor colorWithWhite:.15 alpha:1];self.carplayTrip.layer.cornerRadius=6;self.carplayTrip.clipsToBounds=YES;self.carplayTrip.textAlignment=NSTextAlignmentCenter;self.carplayTrip.text=@"📍 12.5 km";[self.carplayTelemetryCard addSubview:self.carplayTrip];

  self.carplayRearCamBtn=[UIButton buttonWithType:UIButtonTypeCustom];[self.carplayRearCamBtn setTitle:@"REAR CAMERA" forState:UIControlStateNormal];self.carplayRearCamBtn.titleLabel.font=[UIFont boldSystemFontOfSize:12];[self.carplayRearCamBtn setTitleColor:[UIColor colorWithWhite:.9 alpha:1] forState:UIControlStateNormal];self.carplayRearCamBtn.backgroundColor=[UIColor colorWithWhite:.12 alpha:1];self.carplayRearCamBtn.layer.cornerRadius=8;self.carplayRearCamBtn.layer.borderWidth=1;self.carplayRearCamBtn.layer.borderColor=[UIColor colorWithWhite:.24 alpha:1].CGColor;self.carplayRearCamBtn.showsTouchWhenHighlighted=YES;[self.carplayRearCamBtn addTarget:self action:@selector(openCamera) forControlEvents:UIControlEventTouchUpInside];[self.carplayTelemetryCard addSubview:self.carplayRearCamBtn];

  self.carplayEQBtn=[UIButton buttonWithType:UIButtonTypeCustom];[self.carplayEQBtn setTitle:@"SOUND / EQ" forState:UIControlStateNormal];self.carplayEQBtn.titleLabel.font=[UIFont boldSystemFontOfSize:12];[self.carplayEQBtn setTitleColor:[UIColor colorWithWhite:.85 alpha:1] forState:UIControlStateNormal];self.carplayEQBtn.backgroundColor=[UIColor colorWithWhite:.16 alpha:1];self.carplayEQBtn.layer.cornerRadius=8;self.carplayEQBtn.layer.borderWidth=1;self.carplayEQBtn.layer.borderColor=[UIColor colorWithWhite:.28 alpha:1].CGColor;self.carplayEQBtn.showsTouchWhenHighlighted=YES;[self.carplayEQBtn addTarget:self action:@selector(openDriveEQ) forControlEvents:UIControlEventTouchUpInside];[self.carplayTelemetryCard addSubview:self.carplayEQBtn];

  // CarPlay App Grid
  self.carplayAppGrid=[[UIView alloc]init];self.carplayAppGrid.backgroundColor=[UIColor colorWithRed:.05 green:.06 blue:.09 alpha:.98];self.carplayAppGrid.userInteractionEnabled=YES;self.carplayAppGrid.hidden=YES;[self.view addSubview:self.carplayAppGrid];
  self.carplayGridButtons=[NSMutableArray array];
  NSArray *gridTitles=@[@"Music",@"Maps",@"YouTube",@"Camera",@"EQ Sound",@"Trip Log",@"Settings",@"TRD Dash"];
  SEL gSels[]={@selector(carplayGridMusic),@selector(carplayGridMap),@selector(openYouTubeSource),@selector(openCamera),@selector(openDriveEQ),@selector(carplayGridTrip),@selector(carplayGridSettings),@selector(homePage)};
  NSArray *gridIconNames=@[@"cp_icon_music.png",@"cp_icon_maps.png",@"cp_icon_youtube.png",@"cp_icon_camera.png",@"cp_icon_eq.png",@"cp_icon_trip.png",@"cp_icon_settings.png",@"cp_icon_trd.png"];
  for(int i=0;i<8;i++){
    UIButton *gb=[UIButton buttonWithType:UIButtonTypeCustom];
    gb.layer.cornerRadius=24;
    gb.backgroundColor=[UIColor colorWithRed:.11 green:.14 blue:.20 alpha:.75];
    gb.layer.borderWidth=1.2;
    gb.layer.borderColor=[UIColor colorWithWhite:1.0 alpha:.20].CGColor;
    gb.showsTouchWhenHighlighted=YES;
    UIView *spec=[[UIView alloc]initWithFrame:CGRectMake(16,1,148,1.5)];spec.backgroundColor=[UIColor colorWithWhite:1.0 alpha:.35];spec.userInteractionEnabled=NO;[gb addSubview:spec];
    UIImageView *ib=[[UIImageView alloc]initWithImage:[UIImage imageNamed:gridIconNames[i]]];
    ib.tag=101;
    ib.contentMode=UIViewContentModeScaleAspectFit;
    ib.layer.cornerRadius=20;
    ib.clipsToBounds=YES;
    ib.userInteractionEnabled=NO;
    [gb addSubview:ib];
    UILabel *gt=[[UILabel alloc]init];
    gt.tag=102;
    gt.text=gridTitles[i];
    gt.font=[UIFont fontWithName:@"HelveticaNeue-Medium" size:16]?:[UIFont boldSystemFontOfSize:16];
    gt.textColor=[UIColor whiteColor];
    gt.textAlignment=NSTextAlignmentCenter;
    gt.userInteractionEnabled=NO;
    [gb addSubview:gt];
    [gb addTarget:self action:gSels[i] forControlEvents:UIControlEventTouchUpInside];
    [self.carplayAppGrid addSubview:gb];
    [self.carplayGridButtons addObject:gb];
  }

  self.swL=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(openCarPlay)];self.swL.direction=UISwipeGestureRecognizerDirectionLeft;self.swL.delegate=self;self.swL.cancelsTouchesInView=NO;self.swL.delaysTouchesBegan=NO;[self.view addGestureRecognizer:self.swL];
  self.swR=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(homePage)];self.swR.direction=UISwipeGestureRecognizerDirectionRight;self.swR.delegate=self;self.swR.cancelsTouchesInView=NO;self.swR.delaysTouchesBegan=NO;[self.view addGestureRecognizer:self.swR];
  UISwipeGestureRecognizer *dockSwR=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(homePage)];dockSwR.direction=UISwipeGestureRecognizerDirectionRight;dockSwR.delegate=self;dockSwR.cancelsTouchesInView=NO;dockSwR.delaysTouchesBegan=NO;[self.carplayDock addGestureRecognizer:dockSwR];
  UISwipeGestureRecognizer *gridSwR=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(homePage)];gridSwR.direction=UISwipeGestureRecognizerDirectionRight;gridSwR.delegate=self;gridSwR.cancelsTouchesInView=NO;gridSwR.delaysTouchesBegan=NO;[self.carplayAppGrid addGestureRecognizer:gridSwR];
  UISwipeGestureRecognizer *mapSwR=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(homePage)];mapSwR.direction=UISwipeGestureRecognizerDirectionRight;mapSwR.delegate=self;mapSwR.cancelsTouchesInView=NO;mapSwR.delaysTouchesBegan=NO;[self.mapContainer addGestureRecognizer:mapSwR];
  self.edgeR=[[UIScreenEdgePanGestureRecognizer alloc]initWithTarget:self action:@selector(handleEdgePan:)];self.edgeR.edges=UIRectEdgeLeft;self.edgeR.delegate=self;self.edgeR.cancelsTouchesInView=NO;self.edgeR.delaysTouchesBegan=NO;[self.view addGestureRecognizer:self.edgeR];
 self.returnTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(leaveClock)];self.returnTap.enabled=NO;self.returnTap.delegate=self;[self.view addGestureRecognizer:self.returnTap];[UIDevice currentDevice].batteryMonitoringEnabled=YES;dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager",RTLD_LAZY);Class manager=NSClassFromString(@"BluetoothManager");if([manager respondsToSelector:@selector(sharedInstance)])self.bluetooth=[manager performSelector:@selector(sharedInstance)];dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_LAZY);[self update];if(!self.didShowWelcome){self.didShowWelcome=YES;[self showWelcome];}
  [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
  MPRemoteCommandCenter *rCenter = [MPRemoteCommandCenter sharedCommandCenter];
  [rCenter.nextTrackCommand removeTarget:nil];
  [rCenter.previousTrackCommand removeTarget:nil];
  [rCenter.togglePlayPauseCommand removeTarget:nil];
  [rCenter.playCommand removeTarget:nil];
  [rCenter.pauseCommand removeTarget:nil];
  [rCenter.nextTrackCommand addTarget:self action:@selector(carRemoteNext:)];
  [rCenter.previousTrackCommand addTarget:self action:@selector(carRemotePrev:)];
  [rCenter.togglePlayPauseCommand addTarget:self action:@selector(carRemoteToggle:)];
  [rCenter.playCommand addTarget:self action:@selector(carRemotePlay:)];
  [rCenter.pauseCommand addTarget:self action:@selector(carRemotePause:)];
  rCenter.nextTrackCommand.enabled = YES;
  rCenter.previousTrackCommand.enabled = YES;
  rCenter.togglePlayPauseCommand.enabled = YES;
  rCenter.playCommand.enabled = YES;
  rCenter.pauseCommand.enabled = YES;
}
-(BOOL)prefersStatusBarHidden{return YES;}
-(void)rotateTo:(NSNumber *)value{[[UIDevice currentDevice]setValue:value forKey:@"orientation"];[UIViewController attemptRotationToDeviceOrientation];}
-(BOOL)shouldAutorotate{return YES;}
-(UIInterfaceOrientationMask)supportedInterfaceOrientations{return UIInterfaceOrientationMaskLandscape;}
// The audio source owns Now Playing and Bluetooth remote commands.
-(void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];notify_post("com.codex.trd.network.internet");[self applyTheme];[self applyDisplaySchedule];[self becomeFirstResponder];if(self.welcome){[self.view bringSubviewToFront:self.welcome];}else if(!self.didShowWelcome){self.didShowWelcome=YES;[self showWelcome];}[self.audioBars start];[UIApplication sharedApplication].idleTimerDisabled=YES;[self.timer invalidate];self.timer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(update) userInfo:nil repeats:YES];self.timer.tolerance=.1;[self update];}
-(void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self hideWelcome];[self.audioBars stop];[self.driveCar stop];[self.timer invalidate];self.timer=nil;[self saveTrip];[UIApplication sharedApplication].idleTimerDisabled=NO;}
-(void)viewDidLayoutSubviews{
  [super viewDidLayoutSubviews];self.carGlow.hidden=YES;
  CGFloat w=self.view.bounds.size.width,fullH=self.view.bounds.size.height,h=fullH-(self.focused?0:78);
  // CARPLAY MODE LAYOUT
  self.carplayDock.hidden=!self.carplayMode;
  self.carplayTurnBanner.hidden=YES;
  self.carplayMediaCard.hidden=!(self.carplayMode&&!self.carplayGridMode);
  self.carplayTelemetryCard.hidden=!(self.carplayMode&&!self.carplayGridMode);
  self.carplayAppGrid.hidden=!(self.carplayMode&&self.carplayGridMode);

  if(self.carplayMode){
   self.arc.hidden=YES;self.progress.hidden=YES;self.speed.hidden=YES;self.unit.hidden=YES;self.gpsStatus.hidden=YES;self.compassLabel.hidden=YES;self.energyFlowLabel.hidden=YES;self.speedLimitBtn.hidden=YES;self.carImage.hidden=YES;self.driveCar.hidden=YES;self.driveEQ.hidden=YES;self.clock.hidden=YES;self.date.hidden=YES;self.heading.hidden=YES;self.owner.hidden=YES;self.statusStrip.hidden=YES;self.nowPanel.hidden=YES;self.nightButton.hidden=YES;self.modeButton.hidden=YES;self.driveButton.hidden=YES;self.tripButton.hidden=YES;self.miniPlayer.hidden=YES;self.navigation.hidden=YES;for(UIView *cb in self.cards)cb.hidden=YES;

   self.carplayDock.frame=CGRectMake(0,0,80,fullH);
   self.carplayHomeBtn.frame=CGRectMake(13,14,54,54);
   for(int i=0;i<self.carplayDockButtons.count;i++){UIView *db=self.carplayDockButtons[i];db.frame=CGRectMake(13,85+i*66,54,54);}
   self.carplayClock.frame=CGRectMake(4,fullH-76,72,20);
   self.carplayBattery.frame=CGRectMake(4,fullH-54,72,18);
   self.carplayWifi.frame=CGRectMake(8,fullH-32,64,18);

   if(self.carplayGridMode){
    self.mapContainer.hidden=YES;self.controls.hidden=YES;self.artwork.hidden=YES;self.artPlaceholder.hidden=YES;self.song.hidden=YES;self.artist.hidden=YES;self.trackTime.hidden=YES;self.trackProgress.hidden=YES;self.sourceBadge.hidden=YES;
    self.carplayAppGrid.frame=CGRectMake(80,0,w-80,fullH);
    CGFloat colW=180,rowH=190,gapX=36,gapY=50;
    CGFloat startX=(w-80-(4*colW+3*gapX))/2,startY=(fullH-(2*rowH+gapY))/2;
    for(int i=0;i<8;i++){UIView *gb=self.carplayGridButtons[i];int col=i%4,row=i/4;gb.frame=CGRectMake(startX+col*(colW+gapX),startY+row*(rowH+gapY),colW,rowH);UIView *ib=[gb viewWithTag:101];CGFloat iconSize=88;ib.frame=CGRectMake((colW-iconSize)/2,20,iconSize,iconSize);[gb viewWithTag:102].frame=CGRectMake(8,124,colW-16,28);}
   }else{
    CGFloat mapW=(w-96)*0.57;
    self.mapContainer.hidden=NO;self.mapContainer.frame=CGRectMake(90,12,mapW,fullH-24);if(self.mapWebView)self.mapWebView.frame=self.mapContainer.bounds;
    self.carplayTurnBanner.frame=CGRectMake(10,10,mapW-20,54);

    CGFloat rx=90+mapW+12,rw=w-rx-12;
    CGFloat mediaH=(fullH-36)*0.53;
    self.carplayMediaCard.frame=CGRectMake(rx,12,rw,mediaH);

    self.artwork.hidden=NO;self.artwork.frame=CGRectMake(rx+16,22,96,96);self.artwork.layer.cornerRadius=18;self.artwork.layer.borderWidth=1.5;self.artwork.layer.borderColor=[UIColor colorWithWhite:.35 alpha:1].CGColor;
    self.artPlaceholder.frame=self.artwork.frame;self.artPlaceholder.hidden=self.artwork.image!=nil;
    self.sourceBadge.hidden=NO;self.sourceBadge.frame=CGRectMake(rx+rw-82,20,66,22);
    self.artist.hidden=NO;self.artist.font=[UIFont boldSystemFontOfSize:17];self.artist.textColor=[UIColor colorWithWhite:.65 alpha:1];self.artist.frame=CGRectMake(rx+122,20,rw-212,22);self.artist.textAlignment=NSTextAlignmentLeft;self.artist.adjustsFontSizeToFitWidth=YES;self.artist.minimumScaleFactor=.8;
    self.song.hidden=NO;self.song.font=[UIFont boldSystemFontOfSize:23];self.song.textColor=[UIColor whiteColor];self.song.numberOfLines=2;self.song.lineBreakMode=NSLineBreakByTruncatingTail;self.song.frame=CGRectMake(rx+122,46,rw-136,68);self.song.textAlignment=NSTextAlignmentLeft;self.song.adjustsFontSizeToFitWidth=YES;self.song.minimumScaleFactor=.75;
    self.trackProgress.hidden=NO;self.trackProgress.frame=CGRectMake(rx+16,126,rw-32,5);self.trackProgress.layer.cornerRadius=2.5;self.trackProgress.clipsToBounds=YES;self.trackProgress.progressTintColor=TRDAccent();
    self.trackTime.hidden=NO;self.trackTime.font=[UIFont boldSystemFontOfSize:13];self.trackTime.textColor=[UIColor colorWithWhite:.65 alpha:1];self.trackTime.frame=CGRectMake(rx+16,135,rw-32,20);self.trackTime.textAlignment=NSTextAlignmentRight;

    self.carStatus.hidden=NO;self.carStatus.font=[UIFont boldSystemFontOfSize:13];self.carStatus.textColor=[UIColor colorWithWhite:.80 alpha:1];self.carStatus.backgroundColor=[UIColor colorWithWhite:.14 alpha:.85];self.carStatus.layer.cornerRadius=7;self.carStatus.clipsToBounds=YES;self.carStatus.textAlignment=NSTextAlignmentCenter;self.carStatus.frame=CGRectMake(rx+16,fullH-96,rw-32,28);

    self.controls.hidden=NO;self.controls.frame=CGRectMake(rx+16,mediaH-74,rw-32,66);
    [self.controls viewWithTag:23].hidden=YES;
    CGFloat csw=(rw-56)/3;
    for(int i=0;i<3;i++){UIView *cb=[self.controls viewWithTag:20+i];cb.frame=CGRectMake(i*(csw+12),0,csw,66);cb.layer.cornerRadius=20;cb.backgroundColor=[UIColor colorWithWhite:.10 alpha:1];cb.layer.borderColor=[UIColor colorWithWhite:.22 alpha:1].CGColor;[cb viewWithTag:105].frame=CGRectMake(csw/2-20,13,40,40);}

    CGFloat telY=12+mediaH+12,telH=fullH-telY-12;
    self.carplayTelemetryCard.frame=CGRectMake(rx,telY,rw,telH);
    self.carplaySpeedVal.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:82]?:[UIFont boldSystemFontOfSize:82];self.carplaySpeedVal.adjustsFontSizeToFitWidth=YES;self.carplaySpeedVal.minimumScaleFactor=.65;self.carplaySpeedVal.frame=CGRectMake(18,12,180,88);
    self.carplaySpeedUnit.font=[UIFont boldSystemFontOfSize:15];self.carplaySpeedUnit.textColor=TRDAccent();self.carplaySpeedUnit.frame=CGRectMake(18,100,220,22);
    self.carplaySpeedLimit.hidden=YES;
    CGFloat pW=(rw-48)/2;
    self.carplayCompass.frame=CGRectMake(16,136,pW,28);
    self.carplayTrip.frame=CGRectMake(16+pW+16,136,pW,28);
    self.carplayRearCamBtn.frame=CGRectMake(16,telH-52,rw-32,40);self.carplayRearCamBtn.titleLabel.font=[UIFont boldSystemFontOfSize:15];
    self.carplayEQBtn.hidden=YES;
   }
   self.carplayHomeBtn.layer.borderColor=self.carplayGridMode?[UIColor whiteColor].CGColor:[UIColor colorWithWhite:.28 alpha:1].CGColor;
   self.carplayHomeBtn.backgroundColor=self.carplayGridMode?[UIColor colorWithWhite:.28 alpha:1]:[UIColor colorWithWhite:.16 alpha:1];
   for(int i=0;i<self.carplayDockButtons.count;i++){UIButton *db=self.carplayDockButtons[i];BOOL active=(i==0&&!self.carplayGridMode);db.layer.borderColor=active?[UIColor colorWithRed:.25 green:.55 blue:1 alpha:1].CGColor:[UIColor colorWithWhite:.22 alpha:1].CGColor;db.backgroundColor=active?[UIColor colorWithRed:.12 green:.22 blue:.38 alpha:1]:[UIColor colorWithWhite:.12 alpha:1];}
   if(!self.carplayGridMode){[self.view bringSubviewToFront:self.mapContainer];[self.view bringSubviewToFront:self.carplayMediaCard];[self.view bringSubviewToFront:self.carplayTelemetryCard];[self.view bringSubviewToFront:self.controls];[self.view bringSubviewToFront:self.artwork];[self.view bringSubviewToFront:self.song];[self.view bringSubviewToFront:self.artist];[self.view bringSubviewToFront:self.trackProgress];[self.view bringSubviewToFront:self.trackTime];[self.view bringSubviewToFront:self.sourceBadge];[self.view bringSubviewToFront:self.carStatus];}
   else{[self.view bringSubviewToFront:self.carplayAppGrid];}
   [self.view bringSubviewToFront:self.carplayDock];
   if(self.settingsSheet){self.settingsSheet.frame=self.view.bounds;[self.view bringSubviewToFront:self.settingsSheet];}
   return;
  }

 [super viewDidLayoutSubviews];if(self.welcome){self.welcome.frame=self.view.bounds;[self.view bringSubviewToFront:self.welcome];}w=self.view.bounds.size.width;fullH=self.view.bounds.size.height;h=fullH-(self.focused?0:78);BOOL focus=self.focused;self.heading.hidden=focus;self.owner.hidden=focus;self.modeButton.hidden=focus;self.driveButton.hidden=focus;self.nightButton.hidden=focus;self.statusStrip.hidden=focus;CGFloat margin=20,topGap=8,brandWidth=MIN(210,MAX(110,w*.205)),statusWidth=w*.40;CGFloat statusX=w-margin-statusWidth,buttonsX=margin+brandWidth+topGap,buttonsWidth=MAX(0,statusX-topGap-buttonsX),buttonWidth=MAX(0,(buttonsWidth-2*topGap)/3);self.heading.frame=CGRectMake(margin,14,brandWidth,26);self.heading.adjustsFontSizeToFitWidth=YES;self.heading.minimumScaleFactor=.7;self.owner.frame=CGRectMake(margin,40,brandWidth,16);self.network.hidden=YES;self.statusStrip.frame=CGRectMake(statusX,13,statusWidth,44);CGFloat chipWidth=(statusWidth-4*(self.statusChips.count-1))/self.statusChips.count;for(NSUInteger i=0;i<self.statusChips.count;i++){UIView *chip=self.statusChips[i];chip.frame=CGRectMake(i*(chipWidth+4),0,chipWidth,44);[chip viewWithTag:301].frame=CGRectMake(2,4,chipWidth-4,12);[chip viewWithTag:302].frame=CGRectMake(3,18,chipWidth-6,21);}NSArray *topButtons=@[self.modeButton,self.driveButton,self.nightButton];for(NSUInteger i=0;i<topButtons.count;i++){UIButton *button=topButtons[i];button.frame=CGRectMake(buttonsX+i*(buttonWidth+topGap),13,buttonWidth,44);button.titleLabel.adjustsFontSizeToFitWidth=YES;button.titleLabel.minimumScaleFactor=.7;button.contentEdgeInsets=UIEdgeInsetsMake(0,4,0,4);}
 BOOL landscape=w>h;int cols=landscape?3:2,rows=6/cols;CGFloat gap=14,cellW=MIN(landscape?270:320,(w-56-gap*(cols-1))/cols);CGFloat cellH=landscape?96:112;CGFloat top=h-116-rows*cellH-gap*(rows-1);CGFloat shift=(top-340)*.45;CGFloat dashW=w*.30;
 self.arc.hidden=focus||self.driveMode;self.progress.hidden=focus||self.driveMode;self.speed.hidden=focus;self.unit.hidden=focus;self.gpsStatus.hidden=focus;
 self.compassLabel.hidden=YES;self.speedLimitBtn.hidden=focus||self.driveMode;self.energyFlowLabel.hidden=YES;

 self.carImage.hidden=focus||self.driveMode;self.carImage.frame=landscape?CGRectMake(w*.32,85+shift,w*.40,210):CGRectMake(w*.31,85+shift,w*.38,245);
 CGPoint center=CGPointMake(28+dashW/2,220+shift);CGFloat radius=MIN(132,dashW/2-8);
 UIBezierPath *path=[UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:M_PI*.85 endAngle:M_PI*2.15 clockwise:YES];self.arc.path=path.CGPath;self.progress.path=path.CGPath;
 self.compassLabel.frame=CGRectMake(center.x-70, center.y+radius+8, 140, 18);
 self.energyFlowLabel.frame=CGRectMake(center.x-105, center.y+radius+28, 210, 18);
 self.speedLimitBtn.frame=CGRectMake(center.x+radius-24, center.y-radius-10, 28, 28);self.panel.frame=self.view.bounds;self.panel.gaugeCenter=center;self.panel.gaugeRadius=radius;self.panel.heroBottom=top-32;self.panel.clockOnly=focus||self.driveMode||self.musicMode||self.tripMode||self.mapMode;[self.panel setNeedsDisplay];
 self.speed.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:92];self.speed.frame=CGRectMake(28,140+shift,dashW,108);self.unit.frame=CGRectMake(28,251+shift,dashW,24);self.gpsStatus.frame=CGRectMake(28,280+shift,dashW,24);
 self.clock.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:focus?(landscape?200:176):(w>h?78:60)]?:[UIFont boldSystemFontOfSize:focus?190:72];self.clock.frame=focus?CGRectMake(20,h/2-230,w-40,220):CGRectMake(w*.70,top-250,w*.28-12,100);
 self.date.font=[UIFont systemFontOfSize:focus?22:14];self.date.adjustsFontSizeToFitWidth=YES;self.date.frame=focus?CGRectMake(20,h/2-4,w-40,32):CGRectMake(w*.70,top-150,w*.28-12,28);self.clockHud.hidden=!focus;self.clockHud.frame=CGRectMake((w-460)/2,h/2+44,460,108);
 CGFloat nowX=w*.34,nowW=w*.35,nowY=top-61;self.carStatus.backgroundColor=[UIColor clearColor];self.carStatus.clipsToBounds=NO;self.artwork.layer.cornerRadius=4;self.artwork.layer.borderWidth=0;self.nowPanel.hidden=focus;self.artwork.hidden=focus;self.artPlaceholder.hidden=focus||self.artwork.image!=nil;self.artist.hidden=focus;self.carStatus.hidden=focus;self.audioBars.hidden=focus;
 self.nowPanel.frame=CGRectMake(nowX,nowY,nowW,53);self.artwork.frame=CGRectMake(nowX+6,nowY+5,43,43);self.artPlaceholder.frame=self.artwork.frame;self.sourceBadge.frame=CGRectMake(nowW-64,7,56,18);self.sourceBadge.font=[UIFont boldSystemFontOfSize:10];
 self.song.hidden=focus;self.song.numberOfLines=1;self.artist.numberOfLines=1;self.artPlaceholder.font=[UIFont systemFontOfSize:28];self.trackTime.font=[UIFont systemFontOfSize:10];self.trackTime.textAlignment=NSTextAlignmentRight;self.clock.hidden=NO;self.song.textAlignment=focus?NSTextAlignmentCenter:NSTextAlignmentLeft;self.song.font=[UIFont boldSystemFontOfSize:17];self.song.frame=focus?CGRectMake(28,h/2+150,w-56,30):CGRectMake(nowX+59,nowY+6,nowW-128,23);self.artist.frame=CGRectMake(nowX+59,nowY+29,MAX(30,nowW-195),16);self.trackTime.hidden=focus;self.trackProgress.hidden=focus;self.trackTime.frame=CGRectMake(nowX+nowW-130,nowY+29,120,16);self.trackProgress.frame=CGRectMake(nowX+59,nowY+48,nowW-69,2);
 self.audioBars.multicolor=YES;self.carStatus.frame=CGRectMake(w*.70,top-116,w*.28-12,24);self.audioBars.frame=CGRectMake(w*.73,top-64,w*.22,48);self.hint.frame=CGRectMake(20,focus?h-156:h-76,w-40,28);

 for(int i=0;i<6;i++){UIButton *b=self.cards[i];b.hidden=self.focused||self.driveMode;b.frame=CGRectMake((w-(cols*cellW+(cols-1)*gap))/2+(i%cols)*(cellW+gap),top+(landscape?16:8)+(i/cols)*(cellH+gap),cellW,cellH);UILabel *title=(UILabel *)[b viewWithTag:100];title.textAlignment=NSTextAlignmentCenter;title.font=[UIFont boldSystemFontOfSize:20];title.frame=CGRectMake(12,cellH/2+4,cellW-24,30);title.adjustsFontSizeToFitWidth=YES;[b viewWithTag:104].frame=CGRectMake(cellW/2-17,cellH/2-36,34,34);[b viewWithTag:102].frame=CGRectMake(0,14,3,cellH-28);}
 self.controls.hidden=self.focused;self.hint.hidden=!self.focused;self.controls.frame=CGRectMake(28,h-94,w-56,68);CGFloat width=(w-86)/4;for(int i=0;i<4;i++){UIView *button=[self.controls viewWithTag:20+i];button.frame=CGRectMake(i*(width+10),0,width,68);button.layer.cornerRadius=7;button.backgroundColor=[TRDAccent() colorWithAlphaComponent:.10];button.layer.borderColor=[TRDAccent() colorWithAlphaComponent:.35].CGColor;[button viewWithTag:105].frame=CGRectMake(width/2-20,14,40,40);}
 self.driveCar.hidden=!self.driveMode;self.driveEQ.hidden=!self.driveMode;self.driveEQ.frame=CGRectMake(w*.70+24,352,w*.28-48,46);
 self.date.hidden=self.driveMode;[self.controls viewWithTag:23].hidden=self.driveMode;
 if(self.driveMode){
 self.carStatus.hidden=YES;
 self.driveCar.frame=CGRectMake(w*.18,110,w*.64,230);self.speed.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:160];self.speed.adjustsFontSizeToFitWidth=YES;self.speed.frame=CGRectMake(20,122,w*.19,170);self.unit.frame=CGRectMake(20,292,w*.19,28);self.unit.font=[UIFont boldSystemFontOfSize:22];self.gpsStatus.frame=CGRectMake(20,320,w*.24,24);
 self.clock.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:88];self.clock.frame=CGRectMake(w*.81,164,w*.18,115);self.carStatus.frame=CGRectMake(w*.75,303,w*.24,32);self.audioBars.hidden=NO;self.audioBars.frame=CGRectMake(w*.32,h-330,w*.36,48);
 CGFloat y=h-278;self.nowPanel.hidden=NO;self.nowPanel.frame=CGRectMake(28,y,w-56,100);self.artwork.hidden=NO;self.artwork.frame=CGRectMake(40,y+12,76,76);self.artPlaceholder.frame=self.artwork.frame;self.artPlaceholder.hidden=self.artwork.image!=nil;self.artist.hidden=NO;self.song.textAlignment=NSTextAlignmentLeft;self.song.font=[UIFont boldSystemFontOfSize:30];self.song.frame=CGRectMake(134,y+12,w-270,36);self.artist.font=[UIFont systemFontOfSize:21];self.artist.frame=CGRectMake(134,y+52,w-320,26);self.sourceBadge.frame=CGRectMake(w-56-92,14,78,24);self.sourceBadge.font=[UIFont boldSystemFontOfSize:12];self.trackTime.hidden=NO;self.trackProgress.hidden=NO;self.trackTime.font=[UIFont boldSystemFontOfSize:13];self.trackTime.frame=CGRectMake(w-56-150,y+54,136,22);self.trackProgress.frame=CGRectMake(134,y+84,w-210,3);
 self.controls.hidden=NO;self.controls.frame=CGRectMake(28,h-150,w-56,118);CGFloat cw=(w-80)/3;for(int i=0;i<3;i++){UIView *b=[self.controls viewWithTag:20+i];b.frame=CGRectMake(i*(cw+12),0,cw,118);[b viewWithTag:105].frame=CGRectMake(cw/2-30,29,60,60);}
 if(!landscape){self.speed.frame=CGRectMake(28,105,w*.46-28,175);self.unit.frame=CGRectMake(28,285,w*.46-28,32);self.gpsStatus.frame=CGRectMake(28,321,w*.46-28,30);self.clock.frame=CGRectMake(w*.52,132,w*.44,115);self.carStatus.frame=CGRectMake(w*.52,265,w*.44,32);self.driveEQ.frame=CGRectMake(w*.55,310,w*.38,46);self.driveCar.frame=CGRectMake(w*.18,355,w*.64,h-690);self.audioBars.frame=CGRectMake(w*.24,h-330,w*.52,48);}
 }else{[self.driveCar stop];self.unit.font=[UIFont systemFontOfSize:16];self.artist.font=[UIFont systemFontOfSize:12];}

 self.musicHeading.hidden=!self.musicMode;self.browseMusic.hidden=YES;
 if(self.musicMode){
 self.arc.hidden=YES;self.progress.hidden=YES;self.speed.hidden=YES;self.unit.hidden=YES;self.gpsStatus.hidden=YES;self.carImage.hidden=YES;self.driveCar.hidden=YES;self.driveEQ.hidden=YES;[self.driveCar stop];self.clock.hidden=YES;self.date.hidden=YES;self.hint.hidden=YES;for(UIView *b in self.cards)b.hidden=YES;
 self.musicHeading.frame=CGRectMake(28,92,w-300,36);self.browseMusic.frame=CGRectMake(w-240,86,212,48);self.nowPanel.hidden=NO;self.nowPanel.frame=CGRectMake(28,150,w-56,h-270);self.artwork.hidden=NO;self.artPlaceholder.hidden=self.artwork.image!=nil;self.artPlaceholder.font=[UIFont systemFontOfSize:90];self.sourceBadge.frame=CGRectMake(w-56-96,16,80,26);self.sourceBadge.font=[UIFont boldSystemFontOfSize:13];self.song.font=[UIFont boldSystemFontOfSize:30];self.song.numberOfLines=3;self.song.minimumScaleFactor=.7;self.artist.font=[UIFont systemFontOfSize:20];self.artist.numberOfLines=2;self.trackTime.hidden=NO;self.trackProgress.hidden=NO;self.trackTime.font=[UIFont systemFontOfSize:16];self.audioBars.hidden=NO;self.audioBars.multicolor=YES;self.carStatus.hidden=NO;
 if(landscape){CGFloat art=MIN(300,h-330),x=72+art;self.artwork.frame=CGRectMake(48,180,art,art);self.song.frame=CGRectMake(x,180,w-x-56,105);self.artist.frame=CGRectMake(x,292,w-x-56,54);self.trackProgress.frame=CGRectMake(x,370,w-x-56,3);self.trackTime.frame=CGRectMake(x,386,w-x-56,28);self.carStatus.frame=CGRectMake(x,431,w-x-56,26);self.audioBars.frame=CGRectMake(48,195+art,art,50);}
 else{CGFloat art=MIN(300,w-120);self.artwork.frame=CGRectMake((w-art)/2,172,art,art);CGFloat y=192+art;self.song.frame=CGRectMake(56,y,w-112,94);self.artist.frame=CGRectMake(56,y+100,w-112,50);self.trackProgress.frame=CGRectMake(56,y+177,w-112,3);self.trackTime.frame=CGRectMake(56,y+192,w-112,26);self.carStatus.frame=CGRectMake(56,y+230,w-112,25);self.audioBars.frame=CGRectMake(56,y+267,w-112,48);}
 self.artPlaceholder.frame=self.artwork.frame;self.controls.hidden=NO;self.controls.frame=CGRectMake(28,h-104,w-56,82);[self.controls viewWithTag:23].hidden=YES;CGFloat cw=(w-80)/3;for(int i=0;i<3;i++){UIView *b=[self.controls viewWithTag:20+i];b.frame=CGRectMake(i*(cw+12),0,cw,82);[b viewWithTag:105].frame=CGRectMake(cw/2-24,17,48,48);}
 }
 self.navigation.hidden=self.focused;self.navigation.frame=CGRectMake(0,fullH-78,w,78);CGFloat nw=(w-24)/6;for(int i=0;i<6;i++){UIButton *b=self.navButtons[i];BOOL active=(i==0&&!self.musicMode&&!self.mapMode&&!self.tripMode&&!self.carplayMode)||(i==1&&self.carplayMode)||(i==2&&self.musicMode)||(i==3&&self.mapMode);b.frame=CGRectMake(12+i*nw,9,nw-5,60);b.backgroundColor=active?[TRDAccent() colorWithAlphaComponent:.14]:[UIColor clearColor];[b viewWithTag:201].frame=CGRectMake(b.bounds.size.width/2-47,16,26,26);UILabel *t=(UILabel *)[b viewWithTag:202];t.font=[UIFont boldSystemFontOfSize:13];t.frame=CGRectMake(b.bounds.size.width/2-12,16,70,28);t.textColor=active?[UIColor whiteColor]:[UIColor lightGrayColor];[b viewWithTag:203].backgroundColor=TRDAccent();[b viewWithTag:203].hidden=!active;[b viewWithTag:203].frame=CGRectMake(20,56,b.bounds.size.width-40,2);}
 self.tripButton.hidden=focus||self.musicMode||self.tripMode||self.mapMode;self.radioButton.hidden=self.tripButton.hidden;self.tripButton.frame=CGRectMake(w*.70,top-90,w*.28-12,25);
 if(self.driveMode){CGRect eq=self.driveEQ.frame;self.driveEQ.frame=CGRectMake(eq.origin.x,eq.origin.y,(eq.size.width-8)/2,eq.size.height);self.tripButton.frame=CGRectMake(CGRectGetMaxX(self.driveEQ.frame)+8,eq.origin.y,(eq.size.width-8)/2,eq.size.height);}
 if(landscape&&!focus&&!self.driveMode&&!self.musicMode&&!self.tripMode&&!self.mapMode&&!self.carplayMode){
  self.arc.hidden=YES;self.progress.hidden=YES;self.panel.clockOnly=YES;[self.panel setNeedsDisplay];
  self.carImage.frame=CGRectMake(w*.205,82,w*.59,280);self.carGlow.hidden=NO;self.carGlow.frame=CGRectMake(w*.25,322,w*.50,18);CAGradientLayer *glow=(CAGradientLayer *)self.carGlow.layer.sublayers.firstObject;glow.frame=self.carGlow.bounds;glow.colors=@[(id)[UIColor clearColor].CGColor,(id)[[TRDAccent() colorWithAlphaComponent:.10] CGColor],(id)[[UIColor colorWithWhite:.65 alpha:.13] CGColor],(id)[[TRDAccent() colorWithAlphaComponent:.10] CGColor],(id)[UIColor clearColor].CGColor];
  self.speed.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:110]?:[UIFont boldSystemFontOfSize:110];self.speed.frame=CGRectMake(18,95,w*.17,132);self.unit.frame=CGRectMake(18,226,w*.17,30);self.unit.font=[UIFont boldSystemFontOfSize:18];self.gpsStatus.frame=CGRectMake(18,265,w*.19,28);self.gpsStatus.adjustsFontSizeToFitWidth=YES;
  self.speedLimitBtn.frame=CGRectMake(25,305,32,32);self.speedLimitBtn.layer.cornerRadius=16;
  self.clock.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:76]?:[UIFont boldSystemFontOfSize:76];self.clock.frame=CGRectMake(w*.80,110,w*.19,92);self.date.frame=CGRectMake(w*.80,203,w*.19,28);CGFloat rw=(w*.19-8)/2;self.tripButton.frame=CGRectMake(w*.80,245,rw,38);self.radioButton.frame=CGRectMake(w*.80+rw+8,245,rw,38);self.carStatus.frame=CGRectMake(w*.80,292,w*.19,25);self.carStatus.adjustsFontSizeToFitWidth=YES;
  CGFloat musicY=h-315;self.nowPanel.frame=CGRectMake(28,musicY,w-56,120);self.artwork.frame=CGRectMake(40,musicY+14,90,90);self.artPlaceholder.frame=self.artwork.frame;self.song.font=[UIFont boldSystemFontOfSize:22];self.song.frame=CGRectMake(145,musicY+14,w*.33,30);self.artist.font=[UIFont systemFontOfSize:16];self.artist.frame=CGRectMake(145,musicY+46,w*.37,22);self.trackProgress.frame=CGRectMake(145,musicY+82,w*.37,3);self.trackTime.font=[UIFont systemFontOfSize:12];self.trackTime.frame=CGRectMake(w*.46,musicY+76,w*.11,22);self.sourceBadge.frame=CGRectMake(w*.52-60,14,66,22);
  self.controls.frame=CGRectMake(w*.63,musicY+26,w*.32,68);CGFloat bw=(w*.32-24)/3;for(int i=0;i<3;i++){UIView *b=[self.controls viewWithTag:20+i];b.frame=CGRectMake(i*(bw+12),0,bw,68);b.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];b.layer.borderColor=[UIColor colorWithWhite:.22 alpha:1].CGColor;[b viewWithTag:105].frame=CGRectMake((bw-36)/2,16,36,36);}[self.controls viewWithTag:23].hidden=YES;
  self.audioBars.frame=CGRectMake(145,musicY+98,w*.42,16);
  CGFloat cg=14,cw=MIN(240,(w-56-3*cg)/4),cy=h-162,start=(w-(4*cw+3*cg))/2;NSInteger favorites[]={0,1,4,5};for(int i=0;i<6;i++)((UIButton *)self.cards[i]).hidden=YES;for(int j=0;j<4;j++){UIButton *b=self.cards[favorites[j]];b.hidden=NO;b.frame=CGRectMake(start+j*(cw+cg),cy,cw,104);b.layer.borderColor=[UIColor colorWithWhite:.24 alpha:1].CGColor;UILabel *t=(UILabel *)[b viewWithTag:100];t.font=[UIFont boldSystemFontOfSize:18];t.textColor=[UIColor colorWithWhite:.92 alpha:1];t.textAlignment=NSTextAlignmentLeft;t.frame=CGRectMake(cw*.40,35,cw*.56,34);[b viewWithTag:104].frame=CGRectMake(cw*.20,33,38,38);[b viewWithTag:102].frame=CGRectMake(0,22,2,60);[b viewWithTag:102].alpha=.6;}self.song.textColor=[UIColor colorWithWhite:self.nightMode?.78:.95 alpha:1];
 }
 self.driveTripButton.hidden=!self.driveMode;self.driveCameraButton.hidden=YES;
 if(self.driveMode){self.driveEQ.hidden=YES;self.tripButton.hidden=YES;self.driveTripButton.frame=landscape?CGRectMake(20,352,w*.26,46):CGRectMake(w*.55,310,w*.38,52);self.driveCameraButton.frame=landscape?CGRectMake(w*.70+16,346,w*.28-32,58):CGRectMake(w*.55,310,w*.38,60);self.audioBars.frame=landscape?CGRectMake(w*.32,h-296,w*.36,18):CGRectMake(w*.82,h-330,w*.16,18);}
 self.tripView.hidden=!self.tripMode;if(self.tripMode){self.tripView.frame=CGRectMake(28,86,w-56,h-230);self.arc.hidden=YES;self.progress.hidden=YES;for(UIView *v in @[self.carImage,self.driveCar,self.driveEQ,self.speed,self.unit,self.gpsStatus,self.clock,self.date,self.nowPanel,self.artwork,self.artPlaceholder,self.song,self.artist,self.carStatus,self.audioBars,self.trackTime,self.trackProgress,self.controls,self.musicHeading,self.browseMusic])v.hidden=YES;for(UIView *v in self.cards)v.hidden=YES;}
 self.mapContainer.hidden=!self.mapMode;if(self.mapMode){self.mapContainer.frame=CGRectMake(20,70,w-40,h-70-80);if(self.mapWebView)self.mapWebView.frame=self.mapContainer.bounds;self.arc.hidden=YES;self.progress.hidden=YES;for(UIView *v in @[self.carImage,self.driveCar,self.driveEQ,self.speed,self.unit,self.gpsStatus,self.clock,self.date,self.nowPanel,self.artwork,self.artPlaceholder,self.song,self.artist,self.carStatus,self.audioBars,self.trackTime,self.trackProgress,self.controls,self.musicHeading,self.browseMusic])v.hidden=YES;for(UIView *v in self.cards)v.hidden=YES;}
 if(!self.settingsSheet){self.miniPlayer.hidden=!(self.tripMode||self.focused||self.mapMode);self.miniPlayer.frame=self.mapMode?CGRectMake(20,h-74,w-40,70):CGRectMake(28,h-126,w-56,72);}
 [self refreshTrip];[self refreshMini];[self applyMotionPolicy];if(self.tripMode||self.mapMode)self.audioBars.hidden=YES;if(self.mapMode){[self.view bringSubviewToFront:self.mapContainer];[self.view bringSubviewToFront:self.miniPlayer];}[self.view bringSubviewToFront:self.heading];[self.view bringSubviewToFront:self.owner];[self.view bringSubviewToFront:self.modeButton];[self.view bringSubviewToFront:self.driveButton];[self.view bringSubviewToFront:self.nightButton];[self.view bringSubviewToFront:self.statusStrip];if(!self.mapMode)[self.view bringSubviewToFront:self.audioBars];[self.view bringSubviewToFront:self.navigation];if(self.settingsSheet){self.settingsSheet.frame=self.view.bounds;[self.view bringSubviewToFront:self.settingsSheet];}if(self.welcome){self.welcome.frame=self.view.bounds;[self.view bringSubviewToFront:self.welcome];}

}
-(void)update{
 NSDate *now=[NSDate date];
 NSString *newClock=[self.clockFormat stringFromDate:now];
 if(![self.clock.text isEqualToString:newClock]){
  self.clock.text=newClock;
  self.date.text=[self.dateFormat stringFromDate:now];
 }
 UIDeviceBatteryState currentPower=[UIDevice currentDevice].batteryState;
 static UIDeviceBatteryState previousPower=UIDeviceBatteryStateUnknown;
 if((previousPower==UIDeviceBatteryStateCharging||previousPower==UIDeviceBatteryStateFull)&&currentPower==UIDeviceBatteryStateUnplugged){
  [self showTripSummary];
 }
 previousPower=currentPower;
 if(self.carplayMode){
  if(![self.carplayClock.text isEqualToString:self.clock.text])self.carplayClock.text=self.clock.text;
  NSString *speedVal=(self.gpsLive&&self.speed.text.length&&![self.speed.text isEqualToString:@"--"])?self.speed.text:@"--";
  if(![self.carplaySpeedVal.text isEqualToString:speedVal])self.carplaySpeedVal.text=speedVal;
  NSString *speedUnit=self.gpsLive?@"km/h  •  GPS LIVE":@"km/h  •  WAITING FOR GPS";
  if(![self.carplaySpeedUnit.text isEqualToString:speedUnit])self.carplaySpeedUnit.text=speedUnit;
  BOOL courseKnown=self.gpsLive&&self.fix.course>=0&&self.fix.course<360&&self.fix.speed>=1.4&&self.fix.horizontalAccuracy<=25&&fabs([self.fix.timestamp timeIntervalSinceNow])<5;
  NSString *compass=courseKnown?[NSString stringWithFormat:@"COURSE  %.0f°",self.fix.course]:@"COURSE  --";
  if(![self.carplayCompass.text isEqualToString:compass])self.carplayCompass.text=compass;
  NSString *cTrip=[NSString stringWithFormat:@"TRIP  %.1f km",self.trip.meters/1000.0];
  if(![self.carplayTrip.text isEqualToString:cTrip])self.carplayTrip.text=cTrip;
  if(!self.carplayGridMode)[self updateMapCar];
 }
 self.ticks++;if(self.ticks%60==1)[self applyDisplaySchedule];if(self.ticks%30==0)[self saveTrip];[self refreshSpeed];[self refreshTrackProgress];if(self.mapMode)[self updateMapCar];
 if(self.ticks%5==1){NSDictionary *net=CFBridgingRelease(CNCopyCurrentNetworkInfo(CFSTR("en0")));float level=[UIDevice currentDevice].batteryLevel;UIDeviceBatteryState power=currentPower;NSString *battery=level<0?@"—":[NSString stringWithFormat:@"%.0f%%",level*100];BOOL bt=[self.bluetooth respondsToSelector:@selector(enabled)]?[self.bluetooth enabled]:NO;
  NSString *newNet=[NSString stringWithFormat:@"%@ • BT %@ • %@%@",net[@"SSID"]?:@"No Wi-Fi",bt?@"ON":@"OFF",battery,(power==UIDeviceBatteryStateCharging||power==UIDeviceBatteryStateFull)?@" +":@""];
  if(![self.network.text isEqualToString:newNet])self.network.text=newNet;
  self.statusWiFi=net[@"SSID"]?:@"NO NETWORK";
 if(self.carplayMode){
  NSString *cBat=[NSString stringWithFormat:@"⚡ %@",battery];if(![self.carplayBattery.text isEqualToString:cBat])self.carplayBattery.text=cBat;
  if(![self.carplayWifi.text isEqualToString:self.statusWiFi])self.carplayWifi.text=self.statusWiFi;
 }
 self.statusPower=level<0?@"UNKNOWN":[NSString stringWithFormat:@"%@ %.0f%%",(power==UIDeviceBatteryStateCharging)?@"CHG":(power==UIDeviceBatteryStateFull)?@"FULL":@"BAT",level*100];[self refreshCarStatus];
  [self refreshNowPlaying];
  [self refreshAudioRoute];
  [self refreshStatusStrip];
 }
 [self applyMotionPolicy];[self refreshTrip];[self refreshMini];
}
-(void)refreshNowPlaying{
 if(self.radioPlayer){
  self.sourceBadge.text=@"RADIO";
  AVPlayerItemStatus st=self.radioPlayer.currentItem.status;
  if(st==AVPlayerItemStatusReadyToPlay){
   if(self.radioPlayer.rate>0){
    self.song.text=self.currentRadioStation?:@"Thai Live Radio";
    self.artist.text=@"Thai Live Radio · Playing Live";
   }else{
    self.song.text=[NSString stringWithFormat:@"[PAUSED] %@",self.currentRadioStation?:@"Radio"];
    self.artist.text=@"Tap Play button to resume";
   }
  }else if(st==AVPlayerItemStatusFailed){
   self.song.text=[NSString stringWithFormat:@"[OFFLINE] %@",self.currentRadioStation?:@"Radio"];
   self.artist.text=@"Connection timed out or stream offline";
  }else{
   self.song.text=[NSString stringWithFormat:@"[CONNECTING...] %@",self.currentRadioStation?:@"Radio"];
   self.artist.text=@"Buffering audio stream...";
  }
  return;
 }
 static NowPlayingReader reader;static dispatch_once_t once;dispatch_once(&once,^{reader=(NowPlayingReader)dlsym(RTLD_DEFAULT,"MRMediaRemoteGetNowPlayingInfo");});
 if(!reader){self.song.text=@"Choose music in YouTube or audioNINJA";return;}
 double now=TRDMonotonic();if(self.metadataPending&&now-self.metadataRequestedAt<10)return;
 self.metadataPending=YES;self.metadataRequestedAt=now;NSUInteger generation=++self.metadataGeneration;__weak Dashboard *weak=self;
 void (*owner)(dispatch_queue_t,void (^)(int))=dlsym(RTLD_DEFAULT,"MRMediaRemoteGetNowPlayingApplicationPID");if(owner)owner(dispatch_get_main_queue(),^(int pid){Dashboard *v=weak;if(!v||generation!=v.metadataGeneration)return;int (*pathfn)(int,void *,uint32_t)=dlsym(RTLD_DEFAULT,"proc_pidpath");char path[4096];path[0]=0;v.youtubeSource=pid>0&&pathfn&&pathfn(pid,path,sizeof(path))>0&&[[[NSString stringWithUTF8String:path]lastPathComponent]isEqualToString:@"YTNine"];});

 reader(dispatch_get_main_queue(),^(CFDictionaryRef raw){Dashboard *v=weak;if(!v||generation!=v.metadataGeneration)return;v.metadataPending=NO;if(v.noticeUntil&&[v.noticeUntil timeIntervalSinceNow]>0){v.song.text=v.notice;return;}id info=(__bridge id)raw;[v applyNowPlaying:[info isKindOfClass:[NSDictionary class]]?info:nil];});
}
-(void)refreshTransportState{
 UIButton *button=(UIButton *)[self.controls viewWithTag:21];
 DashIcon *icon=(DashIcon *)[button viewWithTag:105];
 NSInteger targetKind=8;
 NSString *targetLabel=@"Play or pause";
 if(self.radioPlayer){
  targetKind=(self.radioPlayer.rate>0)?14:13;
  targetLabel=(self.radioPlayer.rate>0)?@"Pause":@"Play";
 }else if(self.hasPlaybackRate){
  targetKind=(self.mediaRate>0?14:13);
  targetLabel=(self.mediaRate>0?@"Pause":@"Play");
 }
 if(icon.kind!=targetKind){
  icon.kind=targetKind;
  [icon setNeedsDisplay];
 }
 if(![button.accessibilityLabel isEqualToString:targetLabel]){
  button.accessibilityLabel=targetLabel;
 }
 [self refreshMini];
}
-(void)refreshCarStatus{
 BOOL hasEnabled=[self.bluetooth respondsToSelector:@selector(enabled)];BOOL bt=hasEnabled?[self.bluetooth enabled]:NO;NSArray *devices=[self.bluetooth respondsToSelector:@selector(pairedDevices)]?[self.bluetooth pairedDevices]:nil;BOOL paired=NO,known=NO,connected=NO;
 if([devices isKindOfClass:[NSArray class]])for(id device in devices){NSString *name=[device respondsToSelector:@selector(name)]?[device name]:nil;if([name isKindOfClass:[NSString class]]&&[name caseInsensitiveCompare:@"CAR MULTIMEDIA"]==NSOrderedSame){paired=YES;if([device respondsToSelector:@selector(connected)]){known=YES;connected=[device connected];}break;}}
 self.statusCar=!hasEnabled?@"UNKNOWN":!bt?@"BT OFF":![devices isKindOfClass:[NSArray class]]?@"UNKNOWN":!paired?@"NOT PAIRED":!known?@"UNKNOWN":connected?@"CONNECTED":@"DISCONNECTED";
 static BOOL lastCarConnected=NO;
 if(connected&&!lastCarConnected){
  lastCarConnected=YES;
  id delegate=[UIApplication sharedApplication].delegate;if([delegate respondsToSelector:@selector(carStartAutoplay)])[delegate performSelector:@selector(carStartAutoplay)];
 }else if(!connected){
  lastCarConnected=NO;
 }
 [self refreshAudioRoute];
}
-(void)applyNowPlaying:(NSDictionary *)info{
 if(info&&![info isKindOfClass:[NSDictionary class]])info=nil;
 id elapsed=info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"],duration=info[@"kMRMediaRemoteNowPlayingInfoDuration"],rate=info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"],stamp=info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
 self.hasPlaybackRate=[rate isKindOfClass:[NSNumber class]]&&isfinite([rate doubleValue])&&[rate doubleValue]>=0;self.hasElapsed=[elapsed isKindOfClass:[NSNumber class]]&&isfinite([elapsed doubleValue]);self.mediaElapsed=self.hasElapsed?MAX(0,[elapsed doubleValue]):0;self.mediaDuration=[duration isKindOfClass:[NSNumber class]]&&isfinite([duration doubleValue])?MAX(0,[duration doubleValue]):0;self.mediaRate=[rate isKindOfClass:[NSNumber class]]&&isfinite([rate doubleValue])?[rate doubleValue]:0;self.mediaTimestamp=[stamp isKindOfClass:[NSDate class]]?stamp:[NSDate date];[self refreshTrackProgress];[self refreshTransportState];
 NSString *title=[info[@"kMRMediaRemoteNowPlayingInfoTitle"]isKindOfClass:[NSString class]]?info[@"kMRMediaRemoteNowPlayingInfoTitle"]:nil;
 NSString *artist=[info[@"kMRMediaRemoteNowPlayingInfoArtist"]isKindOfClass:[NSString class]]?info[@"kMRMediaRemoteNowPlayingInfoArtist"]:nil;
 NSString *newSong=title.length?title:@"Choose your music";
 NSString *newArtist=title.length?(artist.length?artist:@"NOW PLAYING"):@"YouTube / audioNINJA";
 if(![self.song.text isEqualToString:newSong])self.song.text=newSong;
 if(![self.artist.text isEqualToString:newArtist])self.artist.text=newArtist;
 static NSString *lastPushedTitle=nil;
 static NSString *lastPushedArtist=nil;
 static double lastPushedRate=-1;
 if(![lastPushedTitle isEqualToString:title]||![lastPushedArtist isEqualToString:artist]||lastPushedRate!=self.mediaRate){
  lastPushedTitle=[title copy];
  lastPushedArtist=[artist copy];
  lastPushedRate=self.mediaRate;
  NSMutableDictionary *carInfo=[NSMutableDictionary dictionary];
  carInfo[MPMediaItemPropertyTitle]=title.length?title:@"Toyota Prius TRD";
  carInfo[MPMediaItemPropertyArtist]=artist.length?artist:@"CarDash Audio";
  carInfo[MPMediaItemPropertyAlbumTitle]=@"Prius Hybrid";
  carInfo[MPNowPlayingInfoPropertyPlaybackRate]=@(self.mediaRate>0?1.0:0.0);
  if(self.mediaDuration>0)carInfo[MPMediaItemPropertyPlaybackDuration]=@(self.mediaDuration);
  if(self.hasElapsed)carInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime]=@(self.mediaElapsed);
  [[MPNowPlayingInfoCenter defaultCenter]setNowPlayingInfo:carInfo];
 }
 static NSDictionary *cachedSrc=nil;
 static NSDictionary *cachedCfg=nil;
 static NSTimeInterval lastConfigRead=0;
 NSTimeInterval nowSec=[[NSDate date]timeIntervalSinceReferenceDate];
 if(!cachedSrc||(nowSec-lastConfigRead>15)){
  cachedSrc=[NSDictionary dictionaryWithContentsOfFile:TRDSourcePath];
  cachedCfg=[NSDictionary dictionaryWithContentsOfFile:TRDProfilesPath];
  lastConfigRead=nowSec;
 }
 NSDictionary *src=cachedSrc;NSString *b=src[@"bundle"];NSString *badgeText=@"MUSIC";if(self.youtubeSource||[b isEqualToString:@"com.himais0giiiin.ytnine"])badgeText=@"YOUTUBE";else if([b isEqualToString:@"com.codex.poddash"])badgeText=@"PODCAST";else if([b isEqualToString:@"com.legacymusic.app"])badgeText=@"NINJA";
 if(![self.sourceBadge.text isEqualToString:badgeText])self.sourceBadge.text=badgeText;
 NSDictionary *cfg=cachedCfg;NSString *pName=src[@"preset"]?:(cfg[@"profiles"][b?:(self.youtubeSource?@"com.himais0giiiin.ytnine":@"com.legacymusic.app")]?:@"Flat");
 NSString *eqTitle=[NSString stringWithFormat:@"EQ • %@",[pName uppercaseString]];
 if(![self.driveEQ.currentTitle isEqualToString:eqTitle])[self.driveEQ setTitle:eqTitle forState:UIControlStateNormal];
 id rawData=info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];NSData *data=[rawData isKindOfClass:[NSData class]]&&[rawData length]<=8*1024*1024?rawData:nil;
 BOOL dataDiff=(self.artworkData==nil&&data!=nil)||(self.artworkData!=nil&&data==nil)||(self.artworkData.length!=data.length)||(![self.artworkData isEqualToData:data]);
 if(dataDiff&&(data||self.artworkData)){
  self.artworkData=data;UIImage *image=nil;
  if(data.length){CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache:@NO});
   if(source){NSDictionary *options=@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@256,(__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES};CGImageRef thumb=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)options);if(thumb){image=[UIImage imageWithCGImage:thumb];CGImageRelease(thumb);self.artworkDecodes++;}CFRelease(source);}}
  self.artwork.image=image;
 }
 self.artPlaceholder.hidden=self.focused||self.artwork.image!=nil;
}
-(void)releaseArtwork{self.artwork.image=nil;self.artworkData=nil;self.artPlaceholder.hidden=self.focused;}
-(void)didReceiveMemoryWarning{[super didReceiveMemoryWarning];self.memoryWarnings++;[self releaseArtwork];[self hideWelcome];[self.settingsSheet dismiss];if(!self.mapMode&&!self.carplayMode&&self.mapWebView){[self.mapWebView stopLoading];[self.mapWebView removeFromSuperview];self.mapWebView.delegate=nil;self.mapWebView=nil;}}
-(NSString *)trackTimeString:(double)value{if(!isfinite(value)||value<0)return @"--:--";long long n=(long long)value;return n>=3600?[NSString stringWithFormat:@"%lld:%02lld:%02lld",n/3600,n/60%60,n%60]:[NSString stringWithFormat:@"%lld:%02lld",n/60,n%60];}
-(void)refreshTrackProgress{if(self.radioPlayer){if(![self.trackTime.text isEqualToString:@"LIVE STREAM · ON AIR"]){self.trackTime.text=@"LIVE STREAM · ON AIR";self.trackProgress.progress=1.0;}return;}double elapsed=self.mediaElapsed;if(self.hasElapsed&&self.mediaTimestamp&&self.mediaRate>0)elapsed+=MAX(0,-[self.mediaTimestamp timeIntervalSinceNow])*self.mediaRate;if(self.mediaDuration>0)elapsed=MIN(elapsed,self.mediaDuration);NSString *newTime=[NSString stringWithFormat:@"%@ / %@",self.hasElapsed?[self trackTimeString:elapsed]:@"--:--",self.mediaDuration>0?[self trackTimeString:self.mediaDuration]:@"--:--"];if(![self.trackTime.text isEqualToString:newTime]){self.trackTime.text=newTime;self.trackProgress.progress=self.hasElapsed&&self.mediaDuration>0?MAX(0,MIN(1,elapsed/self.mediaDuration)):0;}}
-(void)openDriveEQ{[self send:@"com.r333d.eqe.app"];}
-(void)toggleSpeedLimit{
 if(self.speedLimit==90)self.speedLimit=120;
 else if(self.speedLimit==120)self.speedLimit=0;
 else self.speedLimit=90;
 [self.speedLimitBtn setTitle:self.speedLimit>0?[NSString stringWithFormat:@"%ld",(long)self.speedLimit]:@"OFF" forState:UIControlStateNormal];
 self.speedLimitBtn.layer.borderColor=(self.speedLimit>0?[UIColor colorWithRed:.95 green:.10 blue:.15 alpha:.9]:[UIColor colorWithWhite:.4 alpha:.6]).CGColor;
 [self refreshSpeed];
}
-(void)cycleDriveMode{NSInteger next=(TRDTheme+1)%3;[self setThemeNumber:@(next)];}
-(void)toggleDrive{self.tripMode=NO;self.mapMode=NO;if(self.driveMode){self.autoDriveSuppressed=YES;self.movingSince=nil;}self.driveMode=!self.driveMode;self.musicMode=NO;self.focused=NO;self.returnTap.enabled=NO;[self.driveButton setTitle:self.driveMode?@"‹ DASHBOARD":@"DRIVE MODE" forState:UIControlStateNormal];[self.view setNeedsLayout];}
-(void)toggleNight{
 NSUserDefaults *prefs=[NSUserDefaults standardUserDefaults];
 if(!self.nightMode){CGFloat observed=[UIScreen mainScreen].brightness;if(observed>=.15)self.dayBrightness=observed;if(self.dayBrightness<.15)self.dayBrightness=.6;[prefs setDouble:self.dayBrightness forKey:@"dayBrightness"];[UIScreen mainScreen].brightness=MIN(self.dayBrightness,.12);self.nightMode=YES;}
 else{[UIScreen mainScreen].brightness=MAX(.25,MIN(1,self.dayBrightness));self.nightMode=NO;}
 [prefs setBool:self.nightMode forKey:@"nightMode"];[prefs synchronize];TRDLowLight=self.nightMode;[self applyTheme];[self.nightButton setTitle:self.nightMode?@"DAY MODE":@"NIGHT MODE" forState:UIControlStateNormal];[self syncMapAppearance:NO];
}
-(void)captureGPSState{}
-(void)restartGPS{[self.gps stopUpdatingLocation];self.fix=nil;self.gpsError=nil;[self startGPS];[self captureGPSState];}
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{if(status==kCLAuthorizationStatusAuthorizedAlways||status==kCLAuthorizationStatusAuthorizedWhenInUse)[self startGPS];[self captureGPSState];}
-(void)startGPS{self.gps.pausesLocationUpdatesAutomatically=NO;self.gps.desiredAccuracy=kCLLocationAccuracyBestForNavigation;self.gps.distanceFilter=1.0;self.gps.activityType=CLActivityTypeAutomotiveNavigation;if([self.gps respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)])self.gps.allowsBackgroundLocationUpdates=YES;CLAuthorizationStatus status=[CLLocationManager authorizationStatus];if(status==kCLAuthorizationStatusNotDetermined)[self.gps requestWhenInUseAuthorization];if(status!=kCLAuthorizationStatusDenied&&status!=kCLAuthorizationStatusRestricted)[self.gps startUpdatingLocation];}
-(void)refreshClockHud{if(!self.clockHud)return;UIColor *c=TRDAccent();self.clockHud.layer.borderColor=[c colorWithAlphaComponent:.38].CGColor;[self.clockHud viewWithTag:401].backgroundColor=c;UILabel *hudSpeed=(UILabel *)[self.clockHud viewWithTag:402],*hudUnit=(UILabel *)[self.clockHud viewWithTag:403],*hudGps=(UILabel *)[self.clockHud viewWithTag:405],*hudAcc=(UILabel *)[self.clockHud viewWithTag:406],*hudTrip=(UILabel *)[self.clockHud viewWithTag:407];hudSpeed.text=self.speed.text?:@"--";hudSpeed.textColor=self.clock.textColor?:[UIColor whiteColor];hudUnit.textColor=c;hudGps.text=self.gpsStatus.text?:@"WAITING FOR GPS";hudGps.textColor=self.gpsLive?[UIColor colorWithRed:.30 green:self.nightMode?.58:.80 blue:.48 alpha:1]:[UIColor colorWithWhite:self.nightMode?.58:.76 alpha:1];hudAcc.text=(self.fix&&self.fix.horizontalAccuracy>=0)?[NSString stringWithFormat:@"ACCURACY ±%.0f m  •  %@",self.fix.horizontalAccuracy,self.gpsLive?@"SPEED LOCKED":@"NO SPEED VECTOR"]:@"SIGNAL  •  SEARCHING SATELLITES";hudTrip.text=self.trip.seconds>0?[NSString stringWithFormat:@"TRIP  %.2f km  •  MAX %.0f km/h",self.trip.meters/1000.0,self.trip.maximum]:(self.trip.running?@"TRIP  ARMED  •  WAITING FOR GPS":@"TRIP  AUTO  •  WAITING FOR MOVEMENT");hudTrip.textColor=c;}
-(void)refreshSpeed{
 CLAuthorizationStatus auth=[CLLocationManager authorizationStatus];NSDictionary *gps=TRDDriveGPSStatus(self.fix,[NSDate date],auth,self.hadGPSSpeed);BOOL valid=[gps[@"valid"]boolValue];if(valid)self.hadGPSSpeed=YES;
 double kmh=valid?self.fix.speed*3.6:0;BOOL reliable=valid&&self.fix.horizontalAccuracy<=25;
 if(reliable&&kmh<=1){if(!self.stationarySince)self.stationarySince=[NSDate date];if(-[self.stationarySince timeIntervalSinceNow]>=10)self.autoDriveSuppressed=NO;}else self.stationarySince=nil;
 if([UIApplication sharedApplication].applicationState==UIApplicationStateActive&&!self.driveMode&&!self.musicMode&&!self.tripMode&&!self.mapMode&&!self.focused&&!self.autoDriveSuppressed&&reliable&&kmh>=10){if(!self.movingSince)self.movingSince=[NSDate date];if(-[self.movingSince timeIntervalSinceNow]>=5){self.movingSince=nil;[self toggleDrive];}}else self.movingSince=nil;
 self.gpsLive=valid;[self.driveCar setSpeed:self.driveMode&&!self.calmDrive&&valid?self.fix.speed*3.6:0];
 NSString *newSpeed=valid?[NSString stringWithFormat:@"%.0f",self.fix.speed*3.6]:@"—";
 if(![self.speed.text isEqualToString:newSpeed]){
  self.speed.text=newSpeed;
  [CATransaction begin];[CATransaction setDisableActions:YES];self.progress.strokeEnd=valid?MIN(1,self.fix.speed*3.6/180):0;[CATransaction commit];
 }
 
 BOOL overSpeed=(self.speedLimit>0&&valid&&kmh>(self.speedLimit+0.5));
 if(overSpeed){
  self.speed.textColor=[UIColor colorWithRed:1.0 green:0.18 blue:0.18 alpha:1.0];
  self.speedLimitBtn.backgroundColor=[UIColor colorWithRed:1.0 green:0.18 blue:0.18 alpha:0.95];
  if(!self.lastSpeedWarnDate||-[self.lastSpeedWarnDate timeIntervalSinceNow]>=12.0){
   self.lastSpeedWarnDate=[NSDate date];
   AudioServicesPlaySystemSound(1052);
  }
 }else{
  self.speed.textColor=self.clock.textColor?:[UIColor whiteColor];
  self.speedLimitBtn.backgroundColor=(self.speedLimit>0)?[UIColor colorWithRed:.85 green:.05 blue:.10 alpha:.18]:[UIColor colorWithWhite:.2 alpha:.2];
 }
 NSString *newStatus=gps[@"label"];
 if(![self.gpsStatus.text isEqualToString:newStatus]){
  self.gpsStatus.text=newStatus;self.gpsStatus.adjustsFontSizeToFitWidth=YES;self.gpsStatus.minimumScaleFactor=.75;self.gpsStatus.textColor=valid?[UIColor colorWithRed:.30 green:self.nightMode?.58:.8 blue:.48 alpha:1]:[UIColor colorWithRed:self.nightMode?.72:.95 green:self.nightMode?.5:.66 blue:.24 alpha:1];
 }
 [self refreshClockHud];
}
-(void)playRadio:(NSString *)url name:(NSString *)name{
 if(self.radioPlayer){
  [self.radioPlayer pause];
  self.radioPlayer=nil;
 }
 if(!url.length){
  self.currentRadioStation=nil;
  self.song.text=@"Radio stopped";
  self.artist.text=@"Tap RADIO to select station";
  [self refreshNowPlaying];
  return;
 }
 
 // 1. Explicitly pause any background music / YouTube players so audio never overlaps
 Boolean (*pauseCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
 if(!pauseCmd||!pauseCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];
 
 // 2. Configure exclusive AVAudioSession (NO MixWithOthers!)
 AVAudioSession *session=[AVAudioSession sharedInstance];
 NSError *sErr=nil;
 [session setCategory:AVAudioSessionCategoryPlayback error:&sErr];
 [session setActive:YES error:&sErr];
 
 self.currentRadioStation=name;
 self.song.text=[NSString stringWithFormat:@"[CONNECTING...] %@", name];
 self.artist.text=@"Buffering live stream...";
 self.sourceBadge.text=@"RADIO";
 
 NSURL *streamURL=[NSURL URLWithString:url];
 AVPlayerItem *item=[AVPlayerItem playerItemWithURL:streamURL];
 self.radioPlayer=[AVPlayer playerWithPlayerItem:item];
 [self.radioPlayer play];
}
-(void)openRadioStationsMenu{
 TRDSettingsMenu *m=[self settingsMenu:@"THAI RADIO & TRAFFIC" message:@"Direct online audio streams"];
 [m addAction:[TRDSettingAction actionWithTitle:@"📻 COOL Fahrenheit 93 (Hit Music)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://coolism-web.cdn.byteark.com/;stream/1" name:@"COOL Fahrenheit 93"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"📻 จส.100 (JS100 Traffic)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://sv4.hostpleng.com:8184/;stream.mp3" name:@"JS100 Traffic จส.100"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"📻 สวพ. FM 91 (Traffic Pro)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://www.fm91bkk.com:8900/;stream.mp3" name:@"สวพ. FM 91 Traffic"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"📻 ข่าว MCOT FM 100.5 (News Network)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://play-fm1005.mcot.net/fm1005/fm1005.m3u8" name:@"MCOT News 100.5"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"📻 ลูกทุ่งรักไทย 90 (Lukthung)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://radio11.plathong.net:8896/;stream.mp3" name:@"90 รักไทย"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"⏹️ Stop Radio" style:1 handler:^(TRDSettingAction *a){
  [self playRadio:nil name:nil];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🎵 Open audioNINJA / YouTube" style:0 handler:^(TRDSettingAction *a){
  if(self.radioPlayer){
   [self.radioPlayer pause];
   self.radioPlayer=nil;
  }
  [self openMusic];
 }]];
 [self presentSettingsMenu:m];
}
-(void)callNumber:(NSString *)num{
 NSString *clean=[[num componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789*#+"] invertedSet]] componentsJoinedByString:@""];
 if(!clean.length)return;
 NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"tel://%@",clean]];
 [[UIApplication sharedApplication] openURL:url];
}
-(void)promptCustomCall{
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"DIAL NUMBER" message:@"ใส่เบอร์โทรศัพท์ที่ต้องการโทรออก" preferredStyle:UIAlertControllerStyleAlert];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *textField){
  textField.placeholder=@"เช่น 0812345678 หรือ 191";
  textField.keyboardType=UIKeyboardTypePhonePad;
 }];
 [alert addAction:[UIAlertAction actionWithTitle:@"โทรออก (Call)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
  NSString *num=alert.textFields.firstObject.text;
  if(num.length)[self callNumber:num];
 }]];
 [alert addAction:[UIAlertAction actionWithTitle:@"ยกเลิก (Cancel)" style:UIAlertActionStyleCancel handler:nil]];
 [self presentViewController:alert animated:YES completion:nil];
}
-(void)showPhoneContinuityGuide{
 TRDSettingsMenu *m=[self settingsMenu:@"HOW TO RECEIVE CALLS" message:@"วิธีเปิดรับสายโทรศัพท์จาก iPhone เข้า iPad:\n\n1. บน iPhone: เข้า Settings > Phone > 'Calls on Other Devices' แล้วเปิด 'Allow Calls on PeePut's iPad'\n\n2. บน iPad: เข้า Settings > FaceTime แล้วเปิด 'Calls from iPhone'\n\nเมื่อมีคนโทรเข้ามือถือ หน้าจอ iPad บนรถจะดังขึ้นพร้อมปุ่มรับสายทันที คุยผ่านไมค์ iPad และเสียงออกลำโพงรถยนต์ได้เลย!"];
 [m addAction:[TRDSettingAction actionWithTitle:@"⚙️ Open iPad Settings (เปิดตั้งค่า)" style:0 handler:^(TRDSettingAction *a){
  [self send:@"com.apple.Preferences"];
 }]];
 [self presentSettingsMenu:m];
}
-(void)openPhoneMenu{
 TRDSettingsMenu *m=[self settingsMenu:@"📞 PHONE & EMERGENCY" message:@"Make phone calls, emergency speed dial and FaceTime Audio"];
 [m addAction:[TRDSettingAction actionWithTitle:@"🔢 Dial Number (พิมพ์เบอร์โทรออก)" style:0 handler:^(TRDSettingAction *a){
  [self promptCustomCall];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🚨 191 - เหตุด่วนเหตุร้าย (Police Emergency)" style:0 handler:^(TRDSettingAction *a){
  [self callNumber:@"191"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🚑 1669 - หน่วยกู้ชีพ / รถพยาบาล (Ambulance)" style:0 handler:^(TRDSettingAction *a){
  [self callNumber:@"1669"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🚓 1193 - ตำรวจทางหลวง (Highway Police)" style:0 handler:^(TRDSettingAction *a){
  [self callNumber:@"1193"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🚗 1543 - กู้ภัยทางด่วน กทพ. (Expressway Help)" style:0 handler:^(TRDSettingAction *a){
  [self callNumber:@"1543"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"📻 1137 - จส.100 ข่าวจราจร (JS100)" style:0 handler:^(TRDSettingAction *a){
  [self callNumber:@"1137"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"📞 Open FaceTime Audio / Contacts" style:0 handler:^(TRDSettingAction *a){
  [self send:@"com.apple.facetime"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"ℹ️ วิธีตั้งค่ารับสายจาก iPhone เข้า iPad" style:0 handler:^(TRDSettingAction *a){
  [self showPhoneContinuityGuide];
 }]];
 [self presentSettingsMenu:m];
}
-(void)showTripSummary{
 if(!self.trip)return;
 [self.settingsSheet dismiss];
 if(self.tripSummaryCard){
  [self.tripSummaryCard removeFromSuperview];
  self.tripSummaryCard=nil;
 }
 CGFloat w=self.view.bounds.size.width;
 CGFloat h=self.view.bounds.size.height;
 CGFloat cardW=MIN(420,w-40);
 CGFloat cardH=240;
 UIView *card=[[UIView alloc]initWithFrame:CGRectMake((w-cardW)/2,(h-cardH)/2-20,cardW,cardH)];
 card.backgroundColor=[UIColor colorWithRed:0.06 green:0.07 blue:0.09 alpha:0.96];
 card.layer.cornerRadius=14;
 card.layer.borderWidth=2;
 card.layer.borderColor=TRDAccent().CGColor;
 card.clipsToBounds=YES;
 
 UILabel *title=[[UILabel alloc]initWithFrame:CGRectMake(20,16,cardW-40,28)];
 title.font=[UIFont boldSystemFontOfSize:18];
 title.textColor=TRDAccent();
 title.textAlignment=NSTextAlignmentCenter;
 title.text=@"TRIP SUMMARY · PRIUS TRD";
 [card addSubview:title];
 
 UIView *div=[[UIView alloc]initWithFrame:CGRectMake(20,48,cardW-40,1)];
 div.backgroundColor=[UIColor colorWithWhite:0.2 alpha:1];
 [card addSubview:div];
 
 double km=self.trip.meters/1000.0;
 long min=self.trip.seconds/60;
 double avg=(self.trip.seconds>0)?(self.trip.meters/self.trip.seconds*3.6):0;
 double top=self.trip.maximum;
 
 NSArray *labels=@[@"DISTANCE",@"DURATION",@"AVG SPEED",@"TOP SPEED"];
 NSArray *vals=@[
  [NSString stringWithFormat:@"%.1f km",km],
  [NSString stringWithFormat:@"%ld min",min],
  [NSString stringWithFormat:@"%.0f km/h",avg],
  [NSString stringWithFormat:@"%.0f km/h",top]
 ];
 
 CGFloat colW=(cardW-40)/2;
 CGFloat rowH=60;
 for(int i=0;i<4;i++){
  CGFloat col=(i%2)*colW+20;
  CGFloat row=56+(i/2)*rowH;
  UILabel *lbl=[[UILabel alloc]initWithFrame:CGRectMake(col,row,colW,18)];
  lbl.font=[UIFont boldSystemFontOfSize:11];
  lbl.textColor=[UIColor colorWithWhite:0.55 alpha:1];
  lbl.text=labels[i];
  [card addSubview:lbl];
  
  UILabel *val=[[UILabel alloc]initWithFrame:CGRectMake(col,row+20,colW,32)];
  val.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:26]?:[UIFont boldSystemFontOfSize:26];
  val.textColor=[UIColor whiteColor];
  val.text=vals[i];
  [card addSubview:val];
 }
 
 UILabel *sub=[[UILabel alloc]initWithFrame:CGRectMake(20,cardH-32,cardW-40,20)];
 sub.font=[UIFont systemFontOfSize:11];
 sub.textColor=[UIColor colorWithWhite:0.4 alpha:1];
 sub.textAlignment=NSTextAlignmentCenter;
 sub.text=@"Engine stopped • Powering down to Ultra Deep Sleep";
 [card addSubview:sub];
 
 self.tripSummaryCard=card;
 [self.view addSubview:card];
 [self.view bringSubviewToFront:card];
 
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
 [self performSelector:@selector(hideTripSummary) withObject:nil afterDelay:6.0];
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
  }];
 }
}
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{self.gpsUpdates++;self.gpsError=nil;self.fix=[locations lastObject];BOOL wasRunning=self.trip.running;for(CLLocation *fix in locations)[self.trip accept:fix now:[NSDate date]];if(wasRunning!=self.trip.running||!self.lastTripSavedAt||-[self.lastTripSavedAt timeIntervalSinceNow]>=5)[self saveTrip];if([UIApplication sharedApplication].applicationState!=UIApplicationStateBackground){[self refreshSpeed];[self refreshTrip];[self updateMapCar];}}
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{self.gpsError=error.description;self.fix=nil;[self.trip breakSegment];[self saveTrip];[self refreshSpeed];[self refreshTrip];}
-(void)send:(NSString *)identifier{
 if(!identifier.length||self.commandsPending>=4)return;self.commandsPending++;self.lastAction=identifier;
 static dispatch_queue_t queue;static dispatch_once_t once;dispatch_once(&once,^{queue=dispatch_queue_create("com.codex.cardash.commands",DISPATCH_QUEUE_SERIAL);});
 __weak Dashboard *weak=self;dispatch_async(queue,^{@autoreleasepool{char *args[]={(char *)"/usr/bin/activator",(char *)"send",(char *)identifier.UTF8String,NULL};BOOL ok=TRDRun(args[0],args,5,NULL,NULL);
 dispatch_async(dispatch_get_main_queue(),^{Dashboard *v=weak;if(!v)return;if(v.commandsPending)v.commandsPending--;if(!ok){v.notice=@"Command unavailable. Tap to retry.";v.noticeUntil=[NSDate dateWithTimeIntervalSinceNow:4];v.song.text=v.notice;}else [v refreshNowPlaying];});}});
}
-(UIWebView *)ensureMapWebView{if(!self.mapWebView){self.mapWebView=[[UIWebView alloc]initWithFrame:self.mapContainer.bounds];self.mapWebView.backgroundColor=[UIColor clearColor];self.mapWebView.opaque=NO;self.mapWebView.scalesPageToFit=YES;self.mapWebView.scrollView.bounces=NO;self.mapWebView.delegate=self;[self.mapContainer addSubview:self.mapWebView];}return self.mapWebView;}
-(void)openCarPlay{notify_post("com.codex.trd.network.internet");self.tripMode=NO;self.mapMode=NO;self.musicMode=NO;self.driveMode=NO;self.focused=NO;self.carplayMode=YES;self.carplayGridMode=NO;[self ensureMapWebView];if(!self.mapWebView.request)[self loadMapHTML];[self.view setNeedsLayout];[self update];}
-(void)toggleCarPlayGrid{self.carplayGridMode=!self.carplayGridMode;[self.view setNeedsLayout];}
-(void)carplayTapMap{if(self.carplayGridMode){self.carplayGridMode=NO;[self.view setNeedsLayout];}else{[self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.recenter)window.recenter();"];}}
-(void)carplayTapMusic{if(self.carplayGridMode){self.carplayGridMode=NO;[self.view setNeedsLayout];}[self browseSource:@"com.legacymusic.app"];}
-(void)carplayGridMusic{self.carplayGridMode=NO;[self.view setNeedsLayout];[self browseSource:@"com.legacymusic.app"];}
-(void)carplayGridMap{self.carplayGridMode=NO;[self.view setNeedsLayout];}
-(void)carplayGridTrip{self.carplayMode=NO;self.carplayGridMode=NO;[self openTrip];}
-(void)carplayGridSettings{[self carSettings];}
-(void)handleEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture{if(gesture.state==UIGestureRecognizerStateBegan||gesture.state==UIGestureRecognizerStateRecognized){if(self.carplayMode)[self homePage];}}
-(void)openYouTubeSource{if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}Boolean (*pauseCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");if(!pauseCmd||!pauseCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];notify_post("com.codex.trd.network.internet");[self send:@"com.himais0giiiin.ytnine"];}
-(void)navigate:(UIButton *)button{switch(button.tag){case 60:[self homePage];break;case 66:[self openCarPlay];break;case 61:[self openMusic];break;case 62:[self openCarPlay];break;case 63:[self openDriveEQ];break;case 64:[self screenOff];break;case 65:[self openCamera];break;}}
-(void)homePage{notify_post("com.codex.trd.network.internet");[self.settingsSheet dismiss];self.tripMode=NO;self.mapMode=NO;self.carplayMode=NO;self.carplayGridMode=NO;if(self.driveMode){self.autoDriveSuppressed=YES;self.movingSince=nil;}self.driveMode=NO;self.musicMode=NO;self.focused=NO;self.returnTap.enabled=NO;self.song.numberOfLines=1;self.heading.hidden=NO;self.owner.hidden=NO;self.modeButton.hidden=NO;self.driveButton.hidden=NO;self.nightButton.hidden=NO;self.statusStrip.hidden=NO;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];[self.view setNeedsLayout];}
-(void)openMusic{if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}notify_post("com.codex.trd.network.internet");self.tripMode=NO;self.mapMode=NO;self.musicMode=YES;self.driveMode=NO;self.focused=NO;self.returnTap.enabled=NO;[self.driveCar stop];[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];[self.view setNeedsLayout];self.ticks=0;[self update];}
-(void)openMap{self.tripMode=NO;self.driveMode=NO;self.musicMode=NO;self.focused=NO;self.returnTap.enabled=NO;[self.driveCar stop];self.mapMode=YES;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];[self ensureMapWebView];[self.view setNeedsLayout];if(!self.mapWebView.request)[self loadMapHTML];[self updateMapCar];}
-(void)syncMapAppearance:(BOOL)initial{if(!self.mapWebView)return;NSString *mode=self.nightMode?@"night":@"traffic";NSString *js=initial?[NSString stringWithFormat:@"if(window.setMode && !window.__trdInitialThemeDone){window.__trdInitialThemeDone=true;window.setMode('%@');}",mode]:[NSString stringWithFormat:@"if(window.setMode){window.setMode('%@');}",mode];[self.mapWebView stringByEvaluatingJavaScriptFromString:js];}
-(void)webViewDidFinishLoad:(UIWebView *)webView{if(webView==self.mapWebView)[self syncMapAppearance:YES];}
-(void)loadMapHTML{[self ensureMapWebView];NSString *path=@"/Applications/CarDash.app/map.html";if([[NSFileManager defaultManager]fileExistsAtPath:path])[self.mapWebView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]]];}
-(void)updateMapCar{if((!self.mapMode&&!self.carplayMode)||!self.mapWebView)return;if(!self.fix)return;CLLocationDegrees lat=self.fix.coordinate.latitude;CLLocationDegrees lng=self.fix.coordinate.longitude;double kmh=(self.fix.speed>=0)?(self.fix.speed*3.6):-1;BOOL courseValid=self.fix.course>=0&&self.fix.course<360&&kmh>=5&&self.fix.horizontalAccuracy>=0&&self.fix.horizontalAccuracy<=25&&fabs([self.fix.timestamp timeIntervalSinceNow])<5;double course=courseValid?self.fix.course:-1;NSString *js=[NSString stringWithFormat:@"if(window.updateCar){window.updateCar(%f,%f,%f,%f);}",lat,lng,course,kmh];[self.mapWebView stringByEvaluatingJavaScriptFromString:js];}
-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)type{NSString *scheme=request.URL.scheme;if([scheme isEqualToString:@"cardash-route"]){NSString *coords=[request.URL.resourceSpecifier stringByReplacingOccurrencesOfString:@"//" withString:@""];[self fetchRouteWithCoords:coords];return NO;}if([scheme isEqualToString:@"cardash-search"]){NSString *query=[[request.URL.resourceSpecifier stringByReplacingOccurrencesOfString:@"//" withString:@""]stringByRemovingPercentEncoding];[self fetchSearchWithQuery:query];return NO;}return YES;}
-(void)fetchRouteWithCoords:(NSString *)coords{NSString *urlStr=[NSString stringWithFormat:@"http://router.project-osrm.org/route/v1/driving/%@?overview=full&geometries=geojson&steps=true",coords];NSURL *url=[NSURL URLWithString:urlStr];if(!url)return;NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:url];[req setValue:@"CarDash/1.6 (iPad; iOS 9.3.6)" forHTTPHeaderField:@"User-Agent"];__weak Dashboard *weak=self;[[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData *data,NSURLResponse *resp,NSError *err){if(data&&!err){NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(json){dispatch_async(dispatch_get_main_queue(),^{[weak.mapWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(window.onNativeRoute){window.onNativeRoute(%@);}",json]];});}}}]resume];}
-(void)fetchSearchWithQuery:(NSString *)query{if(!query.length)return;NSString *encoded=[query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];CLLocationDegrees lat=self.fix?self.fix.coordinate.latitude:13.7563;CLLocationDegrees lng=self.fix?self.fix.coordinate.longitude:100.5018;NSString *viewbox=[NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f",lng-.4,lat+.4,lng+.4,lat-.4];NSString *urlStr=[NSString stringWithFormat:@"http://nominatim.openstreetmap.org/search?q=%@&format=json&countrycodes=th&limit=5&viewbox=%@",encoded,viewbox];NSURL *url=[NSURL URLWithString:urlStr];if(!url)return;NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:url];[req setValue:@"CarDash/1.6 (iPad; iOS 9.3.6; Prius)" forHTTPHeaderField:@"User-Agent"];__weak Dashboard *weak=self;[[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData *data,NSURLResponse *resp,NSError *err){if(data&&!err){NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(json){dispatch_async(dispatch_get_main_queue(),^{[weak.mapWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(window._onNominatimResult){window._onNominatimResult(%@);}",json]];});}}}]resume];}
-(void)openActiveSourceApp{NSDictionary *src=[NSDictionary dictionaryWithContentsOfFile:TRDSourcePath];NSString *bundle=src[@"bundle"]?:(self.youtubeSource?@"com.himais0giiiin.ytnine":@"com.legacymusic.app");if([bundle isEqualToString:@"com.legacymusic.app"])[self browseSource:bundle];else [self send:bundle];}
-(void)showMusicSources:(UIButton *)button{TRDSettingsMenu *menu=[self settingsMenu:@"AUDIO SOURCES" message:@"Select music, live radio or player"];[menu addAction:[TRDSettingAction actionWithTitle:@"📻 Thai Radio & Traffic" style:0 handler:^(TRDSettingAction *a){[self openRadioStationsMenu];}]];[menu addAction:[TRDSettingAction actionWithTitle:@"🎵 audioNINJA" style:0 handler:^(TRDSettingAction *a){[self browseSource:@"com.legacymusic.app"];}]];[menu addAction:[TRDSettingAction actionWithTitle:@"▶️ YouTube" style:0 handler:^(TRDSettingAction *a){[self browseSource:@"com.himais0giiiin.ytnine"];}]];[self presentSettingsMenu:menu];}
-(void)card:(UIButton *)button{
 if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}
 Boolean (*pauseCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
 if(!pauseCmd||!pauseCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];
 if(button.tag==1){notify_post("com.codex.trd.network.internet");[self send:@"com.himais0giiiin.ytnine"];return;}
 if(button.tag==2){[self browseSource:@"com.legacymusic.app"];return;}
 if(button.tag==3){[self openMap];return;}
 if(button.tag==4){[self openCamera];return;}
 if(button.tag==5){[self carSettings];return;}
 if(button.tag==6){self.tripMode=NO;self.mapMode=NO;self.driveMode=NO;self.musicMode=NO;[self.driveCar stop];[self.driveButton setTitle:@"DRIVE MODE" forState:0];self.focused=YES;self.returnTap.enabled=YES;[self.view setNeedsLayout];return;}
 NSArray *ids=@[@"com.himais0giiiin.ytnine",@"com.legacymusic.app",@"com.apple.Maps",@"com.codex.h109viewer",@"com.apple.Preferences"];
 if(button.tag>=1&&button.tag<=5)[self send:ids[button.tag-1]];
}
-(void)media:(UIButton *)button{if(self.radioPlayer){if(button.tag==21){if(self.radioPlayer.rate>0){[self.radioPlayer pause];self.song.text=[NSString stringWithFormat:@"[PAUSED] %@",self.currentRadioStation?:@"Radio"];self.artist.text=@"Tap Play button to resume";}else{Boolean (*pCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");if(!pCmd||!pCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];[self.radioPlayer play];self.song.text=self.currentRadioStation?:@"Radio";self.artist.text=@"Thai Live Radio · Playing Live";}return;}else if(button.tag==20||button.tag==22){[self openRadioStationsMenu];return;}}NSArray *ids=@[@"libactivator.ipod.previous-track",@"libactivator.ipod.toggle-playback",@"libactivator.ipod.next-track",@"com.r333d.eqe.app"];if(button.tag>=20&&button.tag<=23){Boolean (*command)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");if(button.tag==22){if(!command||!command(4,nil))[self send:ids[2]];}else if(button.tag==20){if(!command||!command(5,nil))[self send:ids[0]];}else if(button.tag==21){NSDictionary *source=[NSDictionary dictionaryWithContentsOfFile:TRDSourcePath];BOOL youtube=self.youtubeSource||[source[@"bundle"]isEqualToString:@"com.himais0giiiin.ytnine"];if(youtube)notify_post("com.codex.trd.youtube.toggle");else if(!command||!command(2,nil))[self send:ids[1]];}else{[self send:ids[button.tag-20]];}[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshNowPlaying) object:nil];[self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:.35];[self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:1.2];}}
-(void)leaveClock{self.focused=NO;self.mapMode=NO;self.returnTap.enabled=NO;[self.view setNeedsLayout];}
-(void)testSettingsAction:(NSNumber *)index{NSInteger i=index.integerValue;if(i>=0&&i<self.settingsSheet.buttons.count)[(UIButton *)self.settingsSheet.buttons[i] sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)testNav:(NSNumber *)index{NSInteger i=index.integerValue;if(i>=0&&i<self.navButtons.count)[(UIButton *)self.navButtons[i] sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)testBrowse{[self.browseMusic sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)dismissSourceMenu{[self.settingsSheet dismiss];[self dismissViewControllerAnimated:NO completion:nil];}
-(void)testMedia:(NSNumber *)index{NSInteger i=index.integerValue;if(i>=0&&i<3)[(UIButton *)[self.controls viewWithTag:20+i] sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)capture{UIView *surface=self.view;UIGraphicsBeginImageContextWithOptions(surface.bounds.size,YES,1);[surface drawViewHierarchyInRect:surface.bounds afterScreenUpdates:YES];NSData *png=UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());UIGraphicsEndImageContext();[png writeToFile:@"/var/mobile/h109-build/cardash.png" atomically:YES];NSDictionary *report=@{@"driveTripText":self.driveTripButton.currentTitle?:@"",@"driveTripVisible":@(!self.driveTripButton.hidden),@"driveTripFrame":NSStringFromCGRect(self.driveTripButton.frame),@"driveCameraVisible":@(!self.driveCameraButton.hidden),@"driveCameraFrame":NSStringFromCGRect(self.driveCameraButton.frame),@"driveCameraActions":[self.driveCameraButton actionsForTarget:self forControlEvent:UIControlEventTouchUpInside]?:@[],@"audioOutput":self.audioOutput?:@"UNKNOWN",@"audioDevice":self.audioDevice?:@"",@"outputVolume":@(self.outputVolume),@"songVisible":@(!self.song.hidden),@"mapMode":@(self.mapMode),@"tripMode":@(self.tripMode),@"tripRunning":@(self.trip.running),@"tripSummary":[self.trip summary],@"tripState":self.tripView.state.text?:@"",@"miniVisible":@(!self.miniPlayer.hidden),@"miniTitle":self.miniPlayer.title.text?:@"",@"miniArtist":self.miniPlayer.artist.text?:@"",@"miniIcon":@(self.miniPlayer.icon.kind),@"musicHoldCount":@(((UIView *)self.navButtons[1]).gestureRecognizers.count),@"calmDrive":@(self.calmDrive),@"carLink":self.statusCar?:@"UNKNOWN",@"wifiSSID":self.statusWiFi?:@"NO NETWORK",@"powerState":self.statusPower?:@"UNKNOWN",@"gpsLive":@(self.gpsLive),@"navLabels":[self.navButtons valueForKey:@"accessibilityLabel"],@"youtubeSource":@(self.youtubeSource),@"commandsPending":@(self.commandsPending),@"metadataPending":@(self.metadataPending),@"artworkDecodes":@(self.artworkDecodes),@"artworkPixels":@(self.artwork.image?MAX(CGImageGetWidth(self.artwork.image.CGImage),CGImageGetHeight(self.artwork.image.CGImage)):0),@"memoryWarnings":@(self.memoryWarnings),@"gpsAccuracy":@(self.gps.desiredAccuracy),@"timerActive":@(self.timer!=nil),@"meterActive":@(self.audioBars.refreshTimer!=nil),@"settingsTitle":self.settingsSheet.title?:@"",@"settingsActions":[self.settingsSheet.actions valueForKey:@"title"]?:@[],@"playbackKnown":@(self.hasPlaybackRate),@"transportIcon":@(((DashIcon *)[[self.controls viewWithTag:21]viewWithTag:105]).kind),@"settingsVisible":@(self.settingsSheet!=nil),@"theme":@(TRDTheme),@"displayMode":@(self.displayMode),@"welcomeVisible":@(self.welcome!=nil),@"mediaRate":@(self.mediaRate),@"bounds":NSStringFromCGRect(self.view.bounds),@"navFrame":NSStringFromCGRect(self.navigation.frame),@"musicMode":@(self.musicMode),@"navigationVisible":@(!self.navigation.hidden),@"trackTime":self.trackTime.text?:@"",@"trackProgress":@(self.trackProgress.progress),@"wheelAnimating":@(self.driveCar.wheelTimer!=nil),@"wheelAngle":@(self.driveCar.angle),@"autoDriveSuppressed":@(self.autoDriveSuppressed),@"driveMode":@(self.driveMode),@"audioState":self.audioBars.state?:@"",@"audioRMS":@(self.audioBars.rms),@"carStatus":self.carStatus.text?:@"",@"hasArtwork":@(self.artwork.image!=nil),@"artist":self.artist.text?:@"",@"nightMode":@(self.nightMode),@"brightness":@([UIScreen mainScreen].brightness),@"speed":self.speed.text?:@"",@"gps":self.gpsStatus.text?:@"",@"clock":self.clock.text?:@"",@"date":self.date.text?:@"",@"network":self.network.text?:@"",@"song":self.song.text?:@"",@"focused":@(self.focused),@"clockHudVisible":@(!self.clockHud.hidden),@"clockHudSpeed":((UILabel *)[self.clockHud viewWithTag:402]).text?:@"",@"clockHudGps":((UILabel *)[self.clockHud viewWithTag:405]).text?:@"",@"clockHudTrip":((UILabel *)[self.clockHud viewWithTag:407]).text?:@"",@"sourceBadge":self.sourceBadge.text?:@"",@"driveEQTitle":self.driveEQ.currentTitle?:@"",@"lastAction":self.lastAction?:@""};[report writeToFile:@"/var/mobile/h109-build/cardash-state.plist" atomically:YES];}
-(BOOL)canBecomeFirstResponder{return YES;}
-(MPRemoteCommandHandlerStatus)carRemoteNext:(id)event{
 Boolean (*command)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
 if(!command||!command(4,nil))[self send:@"libactivator.ipod.next-track"];
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshNowPlaying) object:nil];
 [self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:.5];
 return MPRemoteCommandHandlerStatusSuccess;
}
-(MPRemoteCommandHandlerStatus)carRemotePrev:(id)event{
 Boolean (*command)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
 if(!command||!command(5,nil))[self send:@"libactivator.ipod.previous-track"];
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshNowPlaying) object:nil];
 [self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:.5];
 return MPRemoteCommandHandlerStatusSuccess;
}
-(MPRemoteCommandHandlerStatus)carRemoteToggle:(id)event{
 Boolean (*command)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
 if(!command||!command(2,nil))[self send:@"libactivator.ipod.toggle-playback"];
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshNowPlaying) object:nil];
 [self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:.5];
 return MPRemoteCommandHandlerStatusSuccess;
}
-(MPRemoteCommandHandlerStatus)carRemotePlay:(id)event{
 Boolean (*command)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
 if(!command||!command(0,nil))[self send:@"libactivator.ipod.resume-playback"];
 return MPRemoteCommandHandlerStatusSuccess;
}
-(MPRemoteCommandHandlerStatus)carRemotePause:(id)event{
 Boolean (*command)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
 if(!command||!command(1,nil))[self send:@"libactivator.ipod.pause-playback"];
 return MPRemoteCommandHandlerStatusSuccess;
}
-(void)remoteControlReceivedWithEvent:(UIEvent *)event{
 if(event.type==UIEventTypeRemoteControl){
  if(event.subtype==UIEventSubtypeRemoteControlNextTrack)[self carRemoteNext:nil];
  else if(event.subtype==UIEventSubtypeRemoteControlPreviousTrack)[self carRemotePrev:nil];
  else if(event.subtype==UIEventSubtypeRemoteControlTogglePlayPause)[self carRemoteToggle:nil];
  else if(event.subtype==UIEventSubtypeRemoteControlPlay)[self carRemotePlay:nil];
  else if(event.subtype==UIEventSubtypeRemoteControlPause)[self carRemotePause:nil];
 }
}

@end
@interface CarApp:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation CarApp
-(BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options{self.window=[[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];self.window.rootViewController=[Dashboard new];[self.window makeKeyAndVisible];[self performSelector:@selector(carStartAutoplay) withObject:nil afterDelay:4.0];return YES;}
-(void)carStartAutoplay{
 if([UIApplication sharedApplication].applicationState!=UIApplicationStateActive)return;
 Dashboard *v=(Dashboard *)self.window.rootViewController;
 if(v.radioPlayer)return;
 NSDictionary *event=[NSDictionary dictionaryWithContentsOfFile:TRDAutoFile(@"car-start-state.plist")],*consumed=[NSDictionary dictionaryWithContentsOfFile:TRDAutoFile(@"autoplay-consumed.plist")];
 if(!TRDFreshCarEvent(event,consumed,TRDBootIdentity(),[NSDate date]))return;
 if(![@{@"token":event[@"token"],@"at":[NSDate date]}writeToFile:TRDAutoFile(@"autoplay-consumed.plist") atomically:YES])return;
 if(!TRDAutoMayPlay(TRDAutoEnabled(),[AVAudioSession sharedInstance].otherAudioPlaying,[AVAudioSession sharedInstance].secondaryAudioShouldBeSilencedHint,NO,NO))return;
 NSDictionary *request=@{@"pending":@YES,@"token":event[@"token"],@"boot":event[@"boot"],@"created":event[@"created"],@"expires":[event[@"created"]dateByAddingTimeInterval:90]};
 if(![request writeToFile:TRDAutoFile(@"autoplay.plist") atomically:YES])return;
 v=(Dashboard *)self.window.rootViewController;[v send:@"com.legacymusic.app"];
}
-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary *)options{
 Dashboard *v=(Dashboard *)self.window.rootViewController;
 if([url.host isEqualToString:@"home"])[v homePage];
 if([url.host isEqualToString:@"carplay"])[v openCarPlay];
 if([url.host isEqualToString:@"grid"])[v toggleCarPlayGrid];
 if([url.host isEqualToString:@"trip"])[v openTrip];
 if([url.host isEqualToString:@"music"])[v openMusic];
 if([url.host isEqualToString:@"phone"])[v openPhoneMenu];
 if([url.host isEqualToString:@"radio"]){
  NSString *p=url.path;
  if([p isEqualToString:@"/0"])[v playRadio:@"https://coolism-web.cdn.byteark.com/;stream/1" name:@"COOL Fahrenheit 93"];
  else if([p isEqualToString:@"/1"])[v playRadio:@"http://sv4.hostpleng.com:8184/;stream.mp3" name:@"JS100 Traffic จส.100"];
  else if([p isEqualToString:@"/2"])[v playRadio:@"https://www.fm91bkk.com:8900/;stream.mp3" name:@"สวพ. FM 91 Traffic"];
  else if([p isEqualToString:@"/3"])[v playRadio:@"https://play-fm1005.mcot.net/fm1005/fm1005.m3u8" name:@"MCOT News 100.5"];
  else if([p isEqualToString:@"/4"])[v playRadio:@"http://radio11.plathong.net:8896/;stream.mp3" name:@"90 รักไทย"];
  else if([p isEqualToString:@"/stop"])[v playRadio:nil name:nil];
  else [v openRadioStationsMenu];
 }
 if([url.host isEqualToString:@"tripsummary"])[v showTripSummary];
 if([url.host isEqualToString:@"welcome"])[v showWelcome];
 if([url.host isEqualToString:@"capture"])[v capture];
 return YES;
}
-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation{return [self application:app openURL:url options:@{}];}
-(void)applicationDidEnterBackground:(UIApplication *)app{
 Dashboard *v=(Dashboard *)self.window.rootViewController;
 // Keep radioPlayer playing in background if active; only dismiss menus and pause screen animations
 [NSObject cancelPreviousPerformRequestsWithTarget:v selector:@selector(refreshNowPlaying) object:nil];
 [v.settingsSheet dismiss];
 [v releaseArtwork];
 v.metadataGeneration++;
 v.metadataPending=NO;
 [v.audioBars stop];
 [v.driveCar stop];
 [v.timer invalidate];
 v.timer=nil;
 [v saveTrip];
 [UIApplication sharedApplication].idleTimerDisabled=NO;
 [v captureLifecycle];
}
-(void)applicationDidBecomeActive:(UIApplication *)app{notify_post("com.codex.trd.network.internet");Dashboard *v=(Dashboard *)self.window.rootViewController;[v cancelBrowseReturn];[v applyDisplaySchedule];[v restoreDisplayBrightness];BOOL welcomePending=[[NSFileManager defaultManager]fileExistsAtPath:@"/var/mobile/codex-car/welcome-pending"];if(welcomePending){[[NSFileManager defaultManager]removeItemAtPath:@"/var/mobile/codex-car/welcome-pending" error:nil];[v showWelcome];}[v.view setNeedsLayout];[v refreshNowPlaying];[v performSelector:@selector(restoreDisplayBrightness) withObject:nil afterDelay:.6];[v.audioBars start];[UIApplication sharedApplication].idleTimerDisabled=YES;if(!v.timer)v.timer=[NSTimer scheduledTimerWithTimeInterval:1 target:v selector:@selector(update) userInfo:nil repeats:YES];v.timer.tolerance=.1;[v startGPS];[v update];[v captureLifecycle];}

@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass([CarApp class]));}}
