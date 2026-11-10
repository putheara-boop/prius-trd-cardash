#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TRDAutoplayModel.h"
#import "TRDDriveStatus.h"
#import "TRDOBDClient.m"
#import "TRDWelcomeGate.h"
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


// ============================================================================
// PRIUS TRD MASTERPIECE UI COMPONENTS (Pure CoreGraphics / iOS 9.3.6 Compatible)
// ============================================================================

@interface TRDAnalogSpeedoDial : UIView
@property (nonatomic, assign) BOOL driveStyle;
@property (nonatomic, assign) CGFloat speed;
@property (nonatomic, copy) NSString *gear;
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) UIView *gearBadge;
@property (nonatomic, strong) UILabel *unitLabel;
@property (nonatomic, strong) UIButton *speedLimitBadge;
@end

@implementation TRDAnalogSpeedoDial
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = YES;
    self.clipsToBounds = NO;
    self.contentMode = UIViewContentModeRedraw;
    
    self.speedLabel = [[UILabel alloc] init];
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:52] ?: [UIFont boldSystemFontOfSize:52];
    self.speedLabel.textColor = [UIColor whiteColor];
    self.speedLabel.textAlignment = NSTextAlignmentCenter;
    self.speedLabel.text = @"0";
    [self addSubview:self.speedLabel];
    
    self.unitLabel = [[UILabel alloc] init];
    self.unitLabel.font = [UIFont boldSystemFontOfSize:9.5];
    self.unitLabel.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1];
    self.unitLabel.textAlignment = NSTextAlignmentCenter;
    self.unitLabel.text = @"KM / H • DYNAMICS";
    [self addSubview:self.unitLabel];
    
    self.gearBadge = [[UIView alloc] init];
    self.gearBadge.backgroundColor = [UIColor colorWithRed:0.02 green:0.18 blue:0.10 alpha:0.9];
    self.gearBadge.layer.cornerRadius = 6;
    self.gearBadge.layer.borderWidth = 1.0;
    self.gearBadge.layer.borderColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.45 alpha:0.7].CGColor;
    UILabel *gl = [[UILabel alloc] initWithFrame:CGRectMake(5, 2, 14, 18)];
    gl.tag = 101;
    gl.font = [UIFont boldSystemFontOfSize:13];
    gl.textColor = [UIColor whiteColor];
    gl.text = @"D";
    [self.gearBadge addSubview:gl];
    UILabel *gw = [[UILabel alloc] initWithFrame:CGRectMake(20, 4, 38, 14)];
    gw.tag = 102;
    gw.font = [UIFont boldSystemFontOfSize:8.5];
    gw.textColor = [UIColor colorWithRed:0.25 green:0.95 blue:0.50 alpha:1];
    gw.text = @"DRIVE";
    [self.gearBadge addSubview:gw];
    [self addSubview:self.gearBadge];
    
    self.speedLimitBadge = [UIButton buttonWithType:UIButtonTypeCustom];
    self.speedLimitBadge.backgroundColor = [UIColor colorWithRed:0.85 green:0.05 blue:0.10 alpha:0.18];
    self.speedLimitBadge.layer.cornerRadius = 13;
    self.speedLimitBadge.layer.borderWidth = 2;
    self.speedLimitBadge.layer.borderColor = [UIColor colorWithRed:0.95 green:0.10 blue:0.15 alpha:0.9].CGColor;
    [self.speedLimitBadge setTitle:@"90" forState:UIControlStateNormal];
    [self.speedLimitBadge setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.speedLimitBadge.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self addSubview:self.speedLimitBadge];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  if (self.driveStyle) {
    self.speedLimitBadge.frame = CGRectMake(w - 36, 4, 28, 28);
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:68] ?: [UIFont boldSystemFontOfSize:68];
    self.speedLabel.frame = CGRectMake(10, 44, w - 20, 72);
    self.gearBadge.hidden = YES;
    self.unitLabel.frame = CGRectMake(10, h - 28, w - 20, 20);
    self.unitLabel.font = [UIFont boldSystemFontOfSize:12];
    self.unitLabel.text = @"km/h  •  GPS SPEED";
  } else {
    self.speedLimitBadge.frame = CGRectMake(w - 32, 6, 26, 26);
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:52] ?: [UIFont boldSystemFontOfSize:52];
    self.speedLabel.frame = CGRectMake(10, 28, w - 20, 52);
    self.gearBadge.hidden = NO;
    self.gearBadge.frame = CGRectMake(12, h - 26, 60, 22);
    self.unitLabel.frame = CGRectMake(76, h - 24, w - 88, 18);
    self.unitLabel.font = [UIFont boldSystemFontOfSize:9.5];
    self.unitLabel.text = @"KM / H • DYNAMICS";
  }
}

- (void)setSpeed:(CGFloat)speed {
  _speed = speed;
  if (speed <= 0.5) {
    self.speedLabel.text = @"0";
  } else {
    self.speedLabel.text = [NSString stringWithFormat:@"%.0f", speed];
  }
  [self setNeedsDisplay];
}

- (void)setGear:(NSString *)gear {
  _gear = [gear copy];
  UILabel *gl = (UILabel *)[self.gearBadge viewWithTag:101];
  UILabel *gw = (UILabel *)[self.gearBadge viewWithTag:102];
  if (gl) gl.text = gear ?: @"D";
  if (gw) {
    if ([gear isEqualToString:@"P"]) gw.text = @"PARK";
    else if ([gear isEqualToString:@"R"]) gw.text = @"REVERSE";
    else if ([gear isEqualToString:@"N"]) gw.text = @"NEUTRAL";
    else if ([gear isEqualToString:@"B"]) gw.text = @"BRAKE";
    else gw.text = @"DRIVE";
  }
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  CGPoint center = CGPointMake(w / 2.0, h / 2.0 + (self.driveStyle ? 6 : 2));
  CGFloat radius = MIN(w / 2.0 - 18, h / 2.0 - 8);
  
  CGFloat startAngle = M_PI * 0.85;
  CGFloat endAngle = M_PI * 2.15;
  CGFloat totalAngle = endAngle - startAngle;
  
  if (self.driveStyle) {
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.85].CGColor);
    CGContextSetLineWidth(ctx, 5.0);
    CGContextAddArc(ctx, center.x, center.y, radius, startAngle, startAngle + totalAngle * 0.5, 0);
    CGContextStrokePath(ctx);
    
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.2 blue:0.25 alpha:0.85].CGColor);
    CGContextSetLineWidth(ctx, 5.0);
    CGContextAddArc(ctx, center.x, center.y, radius, startAngle + totalAngle * 0.5, endAngle, 0);
    CGContextStrokePath(ctx);
    
    UIFont *trdFont = [UIFont boldSystemFontOfSize:14];
    NSDictionary *trdAttrs = @{NSFontAttributeName: trdFont, NSForegroundColorAttributeName: [UIColor colorWithRed:1.0 green:0.2 blue:0.25 alpha:1]};
    [@"TRD" drawAtPoint:CGPointMake(center.x - 16, center.y - radius + 8) withAttributes:trdAttrs];
  } else {
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.08 green:0.14 blue:0.20 alpha:0.75].CGColor);
    CGContextSetLineWidth(ctx, 4.0);
    CGContextAddArc(ctx, center.x, center.y, radius, startAngle, endAngle, 0);
    CGContextStrokePath(ctx);
    
    CGFloat ratio = MIN(MAX(self.speed / 180.0, 0.0), 1.0);
    if (ratio > 0.01) {
      CGFloat currentAngle = startAngle + totalAngle * ratio;
      CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.9].CGColor);
      CGContextSetLineWidth(ctx, 5.0);
      CGContextAddArc(ctx, center.x, center.y, radius, startAngle, currentAngle, 0);
      CGContextStrokePath(ctx);
    }
    
    NSArray *ticks = @[@0, @30, @60, @80, @100, @120, @140, @160];
    UIFont *font = [UIFont boldSystemFontOfSize:8.5];
    NSDictionary *textAttrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor colorWithWhite:0.6 alpha:0.85]};
    
    for (NSNumber *num in ticks) {
      CGFloat val = [num doubleValue];
      CGFloat tRatio = val / 180.0;
      CGFloat angle = startAngle + totalAngle * tRatio;
      
      CGFloat tickInner = radius - 6.0;
      CGFloat tickOuter = radius + 2.0;
      CGFloat x1 = center.x + tickInner * cos(angle);
      CGFloat y1 = center.y + tickInner * sin(angle);
      CGFloat x2 = center.x + tickOuter * cos(angle);
      CGFloat y2 = center.y + tickOuter * sin(angle);
      
      CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.3 green:0.55 blue:0.75 alpha:0.65].CGColor);
      CGContextSetLineWidth(ctx, 1.5);
      CGContextMoveToPoint(ctx, x1, y1);
      CGContextAddLineToPoint(ctx, x2, y2);
      CGContextStrokePath(ctx);
      
      if (val == 0 || val == 60 || val == 100 || val == 140) {
        NSString *str = [NSString stringWithFormat:@"%.0f", val];
        CGSize sz = [str sizeWithAttributes:textAttrs];
        CGFloat textR = radius - 14.0;
        CGFloat tx = center.x + textR * cos(angle) - sz.width / 2.0;
        CGFloat ty = center.y + textR * sin(angle) - sz.height / 2.0;
        [str drawAtPoint:CGPointMake(tx, ty) withAttributes:textAttrs];
      }
    }
  }
}
@end

@interface TRDVerticalShifterView : UIView
@property (nonatomic, copy) NSString *gear;
@end

@implementation TRDVerticalShifterView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor colorWithRed:0.02 green:0.05 blue:0.08 alpha:0.85];
    self.layer.cornerRadius = 14;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:0.22 alpha:1].CGColor;
    self.gear = @"D";
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  
  NSArray *gears = @[@"P", @"R", @"N", @"D", @"B"];
  CGFloat rowH = (h - 8) / 5.0;
  
  NSInteger activeIdx = [gears indexOfObject:self.gear ?: @"D"];
  if (activeIdx == NSNotFound) activeIdx = 3;
  
  CGFloat sliderY = 4 + activeIdx * rowH;
  CGRect sliderRect = CGRectMake(4, sliderY + 1, w - 8, rowH - 2);
  UIBezierPath *sliderPath = [UIBezierPath bezierPathWithRoundedRect:sliderRect cornerRadius:6];
  [[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.35] setFill];
  [sliderPath fill];
  [[UIColor colorWithRed:0.2 green:0.95 blue:1.0 alpha:0.9] setStroke];
  sliderPath.lineWidth = 1.5;
  [sliderPath stroke];
  
  UIFont *font = [UIFont boldSystemFontOfSize:13];
  for (NSInteger i = 0; i < gears.count; i++) {
    NSString *g = gears[i];
    BOOL isActive = (i == activeIdx);
    UIColor *col = isActive ? [UIColor whiteColor] : [UIColor colorWithWhite:0.45 alpha:1];
    NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: col};
    CGSize sz = [g sizeWithAttributes:attrs];
    CGFloat gy = 4 + i * rowH + (rowH - sz.height) / 2.0;
    CGFloat gx = (w - sz.width) / 2.0;
    [g drawAtPoint:CGPointMake(gx, gy) withAttributes:attrs];
  }
}
@end

@interface TRDHybridPowerMeterView : UIView
@property (nonatomic, assign) CGFloat powerRatio;
@property (nonatomic, strong) UIView *coachPill;
@end

@implementation TRDHybridPowerMeterView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.powerRatio = 0.2;
    self.contentMode = UIViewContentModeRedraw;
    
    self.coachPill = [[UIView alloc] init];
    self.coachPill.backgroundColor = [UIColor colorWithRed:0.02 green:0.18 blue:0.10 alpha:0.85];
    self.coachPill.layer.cornerRadius = 11;
    self.coachPill.layer.borderWidth = 1.0;
    self.coachPill.layer.borderColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.45 alpha:0.7].CGColor;
    
    UILabel *cl = [[UILabel alloc] init];
    cl.tag = 201;
    cl.font = [UIFont boldSystemFontOfSize:10.5];
    cl.textColor = [UIColor colorWithRed:0.25 green:0.95 blue:0.50 alpha:1];
    cl.textAlignment = NSTextAlignmentCenter;
    cl.text = @"ECO  AI ECO COACH: 94 A+";
    [self.coachPill addSubview:cl];
    [self addSubview:self.coachPill];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  self.coachPill.frame = CGRectMake((w - 180)/2, h - 24, 180, 22);
  UILabel *cl = (UILabel *)[self.coachPill viewWithTag:201];
  if (cl) cl.frame = self.coachPill.bounds;
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  CGPoint center = CGPointMake(w / 2.0, h - 32);
  CGFloat radius = MIN(w / 2.0 - 20, h - 42);
  
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.75].CGColor);
  CGContextSetLineWidth(ctx, 7.0);
  CGContextAddArc(ctx, center.x, center.y, radius, M_PI * 1.0, M_PI * 1.25, 0);
  CGContextStrokePath(ctx);
  
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.1 green:0.88 blue:0.4 alpha:0.85].CGColor);
  CGContextSetLineWidth(ctx, 7.0);
  CGContextAddArc(ctx, center.x, center.y, radius, M_PI * 1.28, M_PI * 1.68, 0);
  CGContextStrokePath(ctx);
  
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.95 green:0.25 blue:0.25 alpha:0.75].CGColor);
  CGContextSetLineWidth(ctx, 7.0);
  CGContextAddArc(ctx, center.x, center.y, radius, M_PI * 1.72, M_PI * 2.0, 0);
  CGContextStrokePath(ctx);
  
  UIFont *f = [UIFont boldSystemFontOfSize:9.5];
  NSDictionary *chgAttrs = @{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1]};
  NSDictionary *ecoAttrs = @{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor colorWithRed:0.2 green:0.95 blue:0.45 alpha:1]};
  NSDictionary *pwrAttrs = @{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1]};
  
  [@"CHG" drawAtPoint:CGPointMake(center.x - radius - 8, center.y + 4) withAttributes:chgAttrs];
  [@"- ECO -" drawAtPoint:CGPointMake(center.x - 18, center.y - radius - 15) withAttributes:ecoAttrs];
  [@"PWR" drawAtPoint:CGPointMake(center.x + radius - 14, center.y + 4) withAttributes:pwrAttrs];
  
  CGFloat needleAngle = M_PI * 1.0 + (M_PI * 1.0) * ((self.powerRatio + 1.0) / 2.0);
  CGFloat nx = center.x + (radius - 4) * cos(needleAngle);
  CGFloat ny = center.y + (radius - 4) * sin(needleAngle);
  
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.3 green:1.0 blue:0.6 alpha:1].CGColor);
  CGContextSetLineWidth(ctx, 2.5);
  CGContextMoveToPoint(ctx, center.x, center.y);
  CGContextAddLineToPoint(ctx, nx, ny);
  CGContextStrokePath(ctx);
  
  CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
  CGContextFillEllipseInRect(ctx, CGRectMake(center.x - 3, center.y - 3, 6, 6));
}
@end

@interface TRD3DPerspectiveGridView : UIView
@end

@implementation TRD3DPerspectiveGridView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  
  CGFloat horizonY = h * 0.38;
  CGPoint vp = CGPointMake(w / 2.0, horizonY - 10);
  
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.22].CGColor);
  CGContextSetLineWidth(ctx, 1.0);
  
  NSInteger numLines = 14;
  for (NSInteger i = 0; i <= numLines; i++) {
    CGFloat bottomX = (w / (CGFloat)numLines) * i;
    CGContextMoveToPoint(ctx, vp.x, vp.y);
    CGContextAddLineToPoint(ctx, bottomX, h);
    CGContextStrokePath(ctx);
  }
  
  NSInteger numHoriz = 8;
  for (NSInteger i = 1; i <= numHoriz; i++) {
    CGFloat t = (CGFloat)i / (CGFloat)numHoriz;
    CGFloat y = horizonY + (h - horizonY) * (t * t);
    CGFloat factor = (y - horizonY) / (h - horizonY);
    CGFloat hw = (w * 0.5) * factor + (w * 0.2);
    
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.12 + 0.18 * factor].CGColor);
    CGContextMoveToPoint(ctx, w / 2.0 - hw, y);
    CGContextAddLineToPoint(ctx, w / 2.0 + hw, y);
    CGContextStrokePath(ctx);
  }
}
@end


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
    self.contentMode = UIViewContentModeRedraw;
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
    CGFloat barH = 22.0;
    if (self.voltages && i < self.voltages.count) {
      double v = [self.voltages[i] doubleValue];
      barH = 10.0 + (v - 15.5) * 16.0;
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
    head.text = @"NOW PLAYING \u2022 CARPLAY";
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
    self.artPlaceholder.text = @"\u266b";
    [self addSubview:self.artPlaceholder];

    // Song Title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(132, 40, 220, 52)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.text = @"\u0e2a\u0e31\u0e0d\u0e0d\u0e32\u0e25\u0e21\u0e1b\u0e32\u0e01 (Part Time)";
    [self addSubview:self.titleLabel];

    // Artist
    self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(132, 94, 220, 22)];
    self.artistLabel.font = [UIFont systemFontOfSize:13];
    self.artistLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1];
    self.artistLabel.text = @"\u0e01\u0e2d\u0e25\u0e4c\u0e1f \u0e40\u0e1a\u0e0d\u0e08\u0e1e\u0e25";
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
    [self.btnPrev setTitle:@"\u23ee" forState:UIControlStateNormal];
    self.btnPrev.titleLabel.font = [UIFont systemFontOfSize:24];
    [self addSubview:self.btnPrev];

    self.btnPlay = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPlay.frame = CGRectMake(118, 184, 138, 52);
    self.btnPlay.backgroundColor = [UIColor colorWithRed:.0 green:.72 blue:.40 alpha:1];
    self.btnPlay.layer.cornerRadius = 12;
    self.btnPlay.layer.borderWidth = 1.2;
    self.btnPlay.layer.borderColor = [UIColor colorWithRed:.2 green:.9 blue:.5 alpha:1].CGColor;
    [self.btnPlay setTitle:@"\u275a\u275a" forState:UIControlStateNormal];
    self.btnPlay.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.btnPlay setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self addSubview:self.btnPlay];

    self.btnNext = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnNext.frame = CGRectMake(268, 184, 86, 52);
    self.btnNext.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
    self.btnNext.layer.cornerRadius = 12;
    self.btnNext.layer.borderWidth = 1.0;
    self.btnNext.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    [self.btnNext setTitle:@"\u23ed" forState:UIControlStateNormal];
    self.btnNext.titleLabel.font = [UIFont systemFontOfSize:24];
    [self addSubview:self.btnNext];

    // Quick Audio buttons
    self.btnEQ = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnEQ.frame = CGRectMake(20, 250, 160, 44);
    self.btnEQ.backgroundColor = [UIColor colorWithRed:.03 green:.10 blue:.16 alpha:.9];
    self.btnEQ.layer.cornerRadius = 10;
    self.btnEQ.layer.borderWidth = 1.0;
    self.btnEQ.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.4].CGColor;
    [self.btnEQ setTitle:@"\U0001F39B\U0000FE0F JBL EQUALIZER" forState:UIControlStateNormal];
    self.btnEQ.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [self.btnEQ setTitleColor:[UIColor colorWithRed:0 green:.9 blue:1 alpha:1] forState:UIControlStateNormal];
    [self addSubview:self.btnEQ];

    self.btnRadio = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnRadio.frame = CGRectMake(194, 250, 160, 44);
    self.btnRadio.backgroundColor = [UIColor colorWithRed:.06 green:.08 blue:.12 alpha:.9];
    self.btnRadio.layer.cornerRadius = 10;
    self.btnRadio.layer.borderWidth = 1.0;
    self.btnRadio.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    [self.btnRadio setTitle:@"\U0001F4FB THAI RADIO" forState:UIControlStateNormal];
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
    head.text = @"PRIUS DYNAMICS \u2022 SAFETY ASSIST";
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
    self.speedUnitLabel.text = @"km/h \u2022 GPS LIVE";
    [self addSubview:self.speedUnitLabel];

    self.compassLabel = [[UILabel alloc] initWithFrame:CGRectMake(144, 66, 130, 22)];
    self.compassLabel.font = [UIFont boldSystemFontOfSize:10.5];
    self.compassLabel.textColor = [UIColor colorWithWhite:.8 alpha:1];
    self.compassLabel.backgroundColor = [UIColor colorWithWhite:.15 alpha:1];
    self.compassLabel.layer.cornerRadius = 6;
    self.compassLabel.clipsToBounds = YES;
    self.compassLabel.textAlignment = NSTextAlignmentCenter;
    self.compassLabel.text = @"N 018\u00b0 \u2022 GPS 3D LOCK";
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
    self.thermalsRowLabel.text = @"Coolant: 88\u00b0C  \u2022  A/C: 24.5\u00b0C  \u2022  12V: 13.8V";
    [self addSubview:self.thermalsRowLabel];

    // Trip Metrics
    self.tripMetricsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 168, 334, 54)];
    self.tripMetricsLabel.numberOfLines = 2;
    self.tripMetricsLabel.font = [UIFont boldSystemFontOfSize:13.5];
    self.tripMetricsLabel.adjustsFontSizeToFitWidth = YES;
    self.tripMetricsLabel.minimumScaleFactor = 0.85;
    self.tripMetricsLabel.textColor = [UIColor whiteColor];
    self.tripMetricsLabel.text = @"\U0001F4CD \u0e23\u0e30\u0e22\u0e30\u0e17\u0e32\u0e07\u0e17\u0e23\u0e34\u0e1b: 24.6 km  \u2022  \u0e2d\u0e31\u0e15\u0e23\u0e32\u0e2a\u0e34\u0e49\u0e19\u0e40\u0e1b\u0e25\u0e37\u0e2d\u0e07: 24.2 km/L\n\u0e04\u0e48\u0e32\u0e19\u0e49\u0e33\u0e21\u0e31\u0e19 (GSH95): \u0e3f 38.50  \u2022  \u0e27\u0e34\u0e48\u0e07\u0e15\u0e48\u0e2d\u0e44\u0e14\u0e49: ~520 km";
    [self addSubview:self.tripMetricsLabel];

    // Rear Camera Button
    self.rearCamBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.rearCamBtn.frame = CGRectMake(20, 230, 334, 54);
    self.rearCamBtn.backgroundColor = [UIColor colorWithRed:.05 green:.16 blue:.22 alpha:.9];
    self.rearCamBtn.layer.cornerRadius = 14;
    self.rearCamBtn.layer.borderWidth = 1.5;
    self.rearCamBtn.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.6].CGColor;
    [self.rearCamBtn setTitle:@"\U0001F4F7  REAR / BLIND SPOT CAMERA" forState:UIControlStateNormal];
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
    [self.exitBtn setTitle:@"\U0001F3E0  RETURN TO COCKPIT" forState:UIControlStateNormal];
    self.exitBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.exitBtn setTitleColor:[UIColor colorWithRed:1 green:.8 blue:.8 alpha:1] forState:UIControlStateNormal];
    [self addSubview:self.exitBtn];
  }
  return self;
}
@end

@interface Dashboard:UIViewController<CLLocationManagerDelegate,UIGestureRecognizerDelegate,UIWebViewDelegate>
@property (nonatomic, strong) TRDCarPlayMediaWidget *carplayMediaWidget;
@property (nonatomic, strong) TRDCarPlayTelemetryWidget *carplayTelemetryWidget;


@property (nonatomic, strong) TRDAnalogSpeedoDial *homeSpeedoDial, *driveSpeedoDial;
@property (nonatomic, strong) TRDVerticalShifterView *driveShifter;
@property (nonatomic, strong) TRDHybridPowerMeterView *drivePowerMeter;
@property (nonatomic, strong) TRD3DPerspectiveGridView *drive3DGrid;
@property (nonatomic, strong) UIView *homeAiEcoCard, *homeThermalsCard;
@property (nonatomic, strong) UIView *driveClockCard, *driveBatteryCard, *driveTripCard;
@property (nonatomic, strong) UIButton *driveEqBtn, *driveExitBtn;


@property (nonatomic, strong) UILabel *topClockLabel;
@property (nonatomic, strong) UIButton *obdStatusPill, *dayNightPill, *thaiVoicePill, *settingsPill;
@property (nonatomic, strong) UIView *readyPill, *gearBadge;
@property (nonatomic, strong) NSMutableArray *gearButtons, *driveModePills;
@property (nonatomic, strong) TRD14BlockGraphView *blockGraphView;
@property (nonatomic, strong) UIView *frontMotorBox, *rearBatteryBox, *flowBeamLine;
-(void)gearButtonTapped:(UIButton *)btn;
-(void)driveModePillTapped:(UIButton *)btn;

@property NSString *audioOutput,*audioOutputShort,*audioDevice;
@property float outputVolume;
-(void)refreshAudioRoute;
-(void)audioOutputSettings;
@property NSInteger displayMode;
@property TRDTrip *trip;
@property NSDate *lastTripSavedAt;
@property TRDTripView *tripView;
@property TRDMini *miniPlayer;
@property UIButton *tripButton,*radioButton,*driveTripButton,*driveCameraButton,*offlineMusicBtn,*searchMusicBtn;
-(void)openSearchMusic;
-(void)openOfflineMusicMenu;
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
-(BOOL)launchBundleApp:(NSString *)identifier;
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
-(void)previewWelcome;
-(void)showWelcomeWaitingForCar:(BOOL)waitForCar;
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
-(void)openDriveEQ;
-(void)applyEQPreset:(NSString *)presetName;
@property DrivePrius *driveCar;
@property UILabel *trackTime;
@property UIProgressView *trackProgress;
@property double mediaElapsed,mediaDuration,mediaRate;
@property BOOL hasElapsed;
@property NSDate *mediaTimestamp;
@property BOOL driveMode;
@property UIView *driveLeftCard,*driveRightCard;
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
@property NSDate *movingSince,*stationarySince,*parkedSince;
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
-(void)batteryStateChanged:(NSNotification *)note;
-(void)hideTripSummary;
-(void)immediateSleepFromTripSummary;
-(void)openRadioStationsMenu;
-(void)playRadio:(NSString *)url name:(NSString *)name;
-(void)openPhoneMenu;
-(void)promptCustomCall;
-(void)callNumber:(NSString *)num;
-(void)showPhoneContinuityGuide;
-(void)speakGoodbyeMessage;
-(void)voiceLanguageSettings;
-(void)openFuelPriceSettings;
@property UIButton *brakeStatusCard;
-(void)openBrakeDiagnosticsMenu;
-(void)refreshBrakeStatus;
@property UIButton *hybridSocCard;
@property TRDHybridEcoBar *hybridEcoBar;
-(void)openHybridDiagnosticsMenu;
-(void)refreshHybridStatus;
-(void)toggleTestHybridSOC;
-(void)obdDataUpdated:(NSNotification *)note;
@property float currentTemperature;
@property NSInteger currentWeatherCode;
@property float currentRainMm;
@property BOOL rainDetected;
@property BOOL hasFetchedWeather;
@property BOOL hotCarSaverEnabled;
@property double serviceIntervalKm;
-(void)fetchWeatherForCoordinate:(CLLocationCoordinate2D)coord;
-(void)trackOdometerUpdates;
-(void)serviceSettings;
-(void)weatherSettings;
@property NSInteger ecoScore;
@property double lastSpeedSample;
@property NSDate *lastSpeedSampleTime;
@property NSInteger harshAccelCount;
@property NSInteger harshBrakeCount;
@property NSDate *lastCameraAlertDate;
@property BOOL hasAlertedBattery80;
-(void)checkSpeedCamerasNearLocation:(CLLocation *)location;
-(void)checkBatteryHealthGuard;
-(void)speakQuickAlert:(NSString *)phrase;
-(void)navigateToNearestGasStation;
-(void)navigateToNearestRestArea;
-(void)openSpeedDial;
-(void)promptSetSpeedDial;
-(void)updateEcoScoreForSpeed:(double)curKmh valid:(BOOL)valid;
@property BOOL isReverseActive;
@property NSTimer *reverseBeepTimer;
-(void)obdGearChanged:(NSNotification *)note;
-(void)handleReverseEngaged;
-(void)handleReverseDisengaged;
-(void)playReverseBeep;
@end
@implementation Dashboard

-(void)driveShifterTapped:(UITapGestureRecognizer *)tap{
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
-(void)gearButtonTapped:(UIButton *)btn{
  NSInteger idx = btn.tag - 810;
  NSArray *names = @[@"P", @"R", @"N", @"D", @"B"];
  if(idx >= 0 && idx < names.count){
    NSString *g = names[idx];
    [[TRDOBDClient sharedClient] simulateGear:g];

  self.homeSpeedoDial.gear = g;
  self.driveSpeedoDial.gear = g;
  self.driveShifter.gear = g;
  [self.driveShifter setNeedsDisplay];

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

#import "CarExtrasMethods.h"
#import "TRDTripMethods.h"
-(UILabel *)label:(CGFloat)size color:(UIColor *)color{UILabel *l=[UILabel new];l.font=[UIFont systemFontOfSize:size];l.textColor=color;[self.view addSubview:l];return l;}
-(void)viewDidLoad{
 [super viewDidLoad];[[TRDOBDClient sharedClient] startScanning];[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(obdGearChanged:) name:TRDOBDGearChangedNotification object:nil];[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(obdDataUpdated:) name:TRDOBDDataDidUpdateNotification object:nil];self.trip=[TRDTrip new];[self.trip restore:[[NSUserDefaults standardUserDefaults]dictionaryForKey:@"TRDTripSummary"]];TRDTheme=MAX(0,MIN(2,[[NSUserDefaults standardUserDefaults]integerForKey:@"TRDTheme"]));self.displayMode=MAX(0,MIN(2,[[NSUserDefaults standardUserDefaults]integerForKey:@"TRDDisplayMode"]));self.panel=[[SportPanel alloc]initWithFrame:self.view.bounds];self.panel.userInteractionEnabled=NO;self.panel.opaque=YES;self.panel.clockOnly=YES;[self.view addSubview:self.panel];self.view.backgroundColor=[UIColor colorWithRed:.025 green:.025 blue:.03 alpha:1];UIColor *blue=TRDAccent();self.heading=[self label:18 color:blue];self.heading.text=@"PRIUS TRD SPORTIVO";self.heading.font=[UIFont boldSystemFontOfSize:16];self.owner=[self label:10.5 color:[UIColor colorWithRed:0 green:.85 blue:1 alpha:1]];self.owner.text=@"LUXURY EV SMART COCKPIT • FULLSCREEN KIOSK READY";self.owner.font=[UIFont boldSystemFontOfSize:10];
 NSUserDefaults *wheelPrefs=[NSUserDefaults standardUserDefaults];if(![wheelPrefs boolForKey:@"TRDOptimizedWheelEnabledV1"]){[wheelPrefs setBool:NO forKey:@"TRDCalmDrive"];[wheelPrefs setBool:YES forKey:@"TRDOptimizedWheelEnabledV1"];[wheelPrefs synchronize];}self.calmDrive=[wheelPrefs boolForKey:@"TRDCalmDrive"];self.nightMode=[[NSUserDefaults standardUserDefaults]boolForKey:@"nightMode"];TRDLowLight=self.nightMode;self.dayBrightness=[[NSUserDefaults standardUserDefaults]objectForKey:@"dayBrightness"]?[[NSUserDefaults standardUserDefaults]doubleForKey:@"dayBrightness"]:.6;if(self.dayBrightness<.15)self.dayBrightness=.6;
 NSUserDefaults *p=[NSUserDefaults standardUserDefaults];
  self.hotCarSaverEnabled=[p objectForKey:@"TRDHotCarSaver"]?[p boolForKey:@"TRDHotCarSaver"]:YES;
  self.serviceIntervalKm=[p doubleForKey:@"TRDServiceInterval"]?:10000.0;
  self.nightButton=[UIButton buttonWithType:UIButtonTypeSystem];self.nightButton.backgroundColor=[UIColor colorWithRed:.13 green:.045 blue:.06 alpha:1];self.nightButton.layer.cornerRadius=6;self.nightButton.layer.borderWidth=1;self.nightButton.layer.borderColor=blue.CGColor;[self.nightButton setTitleColor:blue forState:UIControlStateNormal];self.nightButton.titleLabel.font=[UIFont boldSystemFontOfSize:14];[self.nightButton setTitle:self.nightMode?@"DAY MODE":@"NIGHT MODE" forState:UIControlStateNormal];[self.nightButton addTarget:self action:@selector(carSettings) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.nightButton];
 self.modeButton=[UIButton buttonWithType:UIButtonTypeSystem];self.modeButton.backgroundColor=[UIColor colorWithWhite:.10 alpha:1];self.modeButton.layer.cornerRadius=6;self.modeButton.layer.borderWidth=1;self.modeButton.layer.borderColor=blue.CGColor;[self.modeButton setTitle:[NSString stringWithFormat:@"[ %@ ]",TRDDriveModeName(TRDTheme)] forState:UIControlStateNormal];[self.modeButton setTitleColor:blue forState:UIControlStateNormal];self.modeButton.titleLabel.font=[UIFont boldSystemFontOfSize:12];[self.modeButton addTarget:self action:@selector(cycleDriveMode) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.modeButton];
 self.driveButton=[UIButton buttonWithType:UIButtonTypeSystem];self.driveButton.backgroundColor=[UIColor colorWithWhite:.10 alpha:1];self.driveButton.layer.cornerRadius=6;self.driveButton.layer.borderWidth=1;self.driveButton.layer.borderColor=[UIColor colorWithWhite:.30 alpha:1].CGColor;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];[self.driveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];self.driveButton.titleLabel.font=[UIFont boldSystemFontOfSize:12];[self.driveButton addTarget:self action:@selector(toggleDrive) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveButton];
 self.driveEQ=[UIButton buttonWithType:UIButtonTypeCustom];[self.driveEQ setTitle:@"EQ  /  SOUND" forState:UIControlStateNormal];[self.driveEQ setTitleColor:blue forState:UIControlStateNormal];self.driveEQ.titleLabel.font=[UIFont boldSystemFontOfSize:16];self.driveEQ.backgroundColor=[UIColor colorWithRed:.12 green:.04 blue:.06 alpha:1];self.driveEQ.layer.cornerRadius=6;self.driveEQ.layer.borderWidth=1;self.driveEQ.layer.borderColor=[UIColor colorWithRed:.35 green:.10 blue:.13 alpha:1].CGColor;self.driveEQ.accessibilityLabel=@"Open Equalizer";[self.driveEQ addTarget:self action:@selector(openDriveEQ) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveEQ];
 self.driveCar=[[DrivePrius alloc]init];self.driveCar.hidden=YES;[self.view addSubview:self.driveCar];
 self.hybridEcoBar=[[TRDHybridEcoBar alloc]init];self.hybridEcoBar.hidden=YES;[self.view addSubview:self.hybridEcoBar];

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
  self.obdStatusPill.titleLabel.font = [UIFont boldSystemFontOfSize:13];
  [self.obdStatusPill addTarget:self action:@selector(openFuelPriceSettings) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.obdStatusPill];

  self.dayNightPill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.dayNightPill.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
  self.dayNightPill.layer.cornerRadius = 6;
  self.dayNightPill.layer.borderWidth = 1.0;
  self.dayNightPill.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
  [self.dayNightPill setTitle:self.nightMode?@"🌙 กลางคืน":@"☀️ กลางวัน" forState:UIControlStateNormal];
  [self.dayNightPill setTitleColor:[UIColor colorWithRed:1.0 green:.82 blue:.25 alpha:1] forState:UIControlStateNormal];
  self.dayNightPill.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
  [self.dayNightPill addTarget:self action:@selector(toggleNight) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.dayNightPill];

  self.thaiVoicePill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.thaiVoicePill.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
  self.thaiVoicePill.layer.cornerRadius = 6;
  self.thaiVoicePill.layer.borderWidth = 1.0;
  self.thaiVoicePill.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
  [self.thaiVoicePill setTitle:@"🔊 เสียงไทย" forState:UIControlStateNormal];
  [self.thaiVoicePill setTitleColor:[UIColor colorWithRed:0 green:.85 blue:1 alpha:1] forState:UIControlStateNormal];
  self.thaiVoicePill.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
  [self.thaiVoicePill addTarget:self action:@selector(voiceLanguageSettings) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.thaiVoicePill];

  self.settingsPill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.settingsPill.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
  self.settingsPill.layer.cornerRadius = 6;
  self.settingsPill.layer.borderWidth = 1.0;
  self.settingsPill.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
  [self.settingsPill setTitle:@"⚙️ iPad ตั้งค่า" forState:UIControlStateNormal];
  [self.settingsPill setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  self.settingsPill.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
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
      gb.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
      gb.layer.borderColor = [UIColor colorWithWhite:.30 alpha:1].CGColor;
      [gb setTitleColor:[UIColor colorWithWhite:.90 alpha:1] forState:UIControlStateNormal];
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
      mb.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
      mb.layer.borderColor = [UIColor colorWithWhite:.30 alpha:1].CGColor;
      [mb setTitleColor:[UIColor colorWithWhite:.90 alpha:1] forState:UIControlStateNormal];
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
  UILabel *fmL1 = [[UILabel alloc]initWithFrame:CGRectMake(8,3,172,18)];fmL1.font=[UIFont boldSystemFontOfSize:12.5];fmL1.textColor=[UIColor colorWithWhite:.88 alpha:1];fmL1.text=@"หน้ารถ (ชุดขับเคลื่อนหน้า)";[self.frontMotorBox addSubview:fmL1];
  UILabel *fmL2 = [[UILabel alloc]initWithFrame:CGRectMake(8,21,172,18)];fmL2.font=[UIFont boldSystemFontOfSize:12.5];fmL2.textColor=[UIColor colorWithRed:0 green:.85 blue:1 alpha:1];fmL2.text=@"⚡ MOTOR MG1 / MG2";[self.frontMotorBox addSubview:fmL2];
  [self.view addSubview:self.frontMotorBox];

  self.rearBatteryBox = [[UIView alloc]init];
  self.rearBatteryBox.backgroundColor = [UIColor colorWithRed:.02 green:.08 blue:.05 alpha:.9];
  self.rearBatteryBox.layer.cornerRadius = 6;
  self.rearBatteryBox.layer.borderWidth = 1.0;
  self.rearBatteryBox.layer.borderColor = [UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.4].CGColor;
  UILabel *rbL1 = [[UILabel alloc]initWithFrame:CGRectMake(8,3,172,18)];rbL1.font=[UIFont boldSystemFontOfSize:12.5];rbL1.textColor=[UIColor colorWithWhite:.88 alpha:1];rbL1.textAlignment=NSTextAlignmentRight;rbL1.text=@"ท้ายรถ (แบตเตอรี่ไฮบริด)";[self.rearBatteryBox addSubview:rbL1];
  UILabel *rbL2 = [[UILabel alloc]initWithFrame:CGRectMake(8,21,172,18)];rbL2.font=[UIFont boldSystemFontOfSize:12.5];rbL2.textColor=[UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];rbL2.textAlignment=NSTextAlignmentRight;rbL2.text=@"HV BATTERY PACK 🔋";[self.rearBatteryBox addSubview:rbL2];
  [self.view addSubview:self.rearBatteryBox];

  self.flowBeamLine = [[UIView alloc]init];
  self.flowBeamLine.backgroundColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.3];
  self.flowBeamLine.layer.cornerRadius = 2;
  UIView *fDot = [[UIView alloc]initWithFrame:CGRectMake(0,-3,8,8)];fDot.backgroundColor=[UIColor colorWithRed:0 green:.85 blue:1 alpha:1];fDot.layer.cornerRadius=4;[self.flowBeamLine addSubview:fDot];
  UIView *rDot = [[UIView alloc]initWithFrame:CGRectMake(0,-4,10,10)];rDot.tag=831;rDot.backgroundColor=[UIColor colorWithRed:.35 green:.95 blue:.50 alpha:1];rDot.layer.cornerRadius=5;rDot.layer.borderWidth=1.5;rDot.layer.borderColor=[UIColor whiteColor].CGColor;[self.flowBeamLine addSubview:rDot];
  [self.view addSubview:self.flowBeamLine];

  self.homeSpeedoDial = [[TRDAnalogSpeedoDial alloc] initWithFrame:CGRectZero];
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
  [self.view addSubview:self.driveShifter];

  self.drivePowerMeter = [[TRDHybridPowerMeterView alloc] initWithFrame:CGRectZero];
  self.drivePowerMeter.hidden = YES;
  [self.view addSubview:self.drivePowerMeter];

  self.drive3DGrid = [[TRD3DPerspectiveGridView alloc] initWithFrame:CGRectZero];
  self.drive3DGrid.hidden = YES;
  [self.view addSubview:self.drive3DGrid];

  self.homeAiEcoCard = [[UIView alloc] initWithFrame:CGRectZero];
  self.homeAiEcoCard.backgroundColor = [UIColor colorWithRed:.02 green:.07 blue:.05 alpha:.92];
  self.homeAiEcoCard.layer.cornerRadius = 10;
  self.homeAiEcoCard.layer.borderWidth = 1.0;
  self.homeAiEcoCard.layer.borderColor = [UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.4].CGColor;
  [self.view addSubview:self.homeAiEcoCard];

  UILabel *ecoH = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 214, 20)];
  ecoH.tag = 501;
  ecoH.font = [UIFont boldSystemFontOfSize:12.5];
  ecoH.textColor = [UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];
  ecoH.text = @"🌱 AI ECO COACH  •  ♻️ +14 Wh";
  [self.homeAiEcoCard addSubview:ecoH];

  UILabel *ecoS = [[UILabel alloc] initWithFrame:CGRectMake(10, 27, 214, 24)];
  ecoS.tag = 502;
  ecoS.font = [UIFont boldSystemFontOfSize:15.5];
  ecoS.adjustsFontSizeToFitWidth = YES;
  ecoS.minimumScaleFactor = 0.85;
  ecoS.textColor = [UIColor whiteColor];
  ecoS.text = @"ECO 92 / 100  [ GRADE A+ ]";
  [self.homeAiEcoCard addSubview:ecoS];

  UILabel *ecoD = [[UILabel alloc] initWithFrame:CGRectMake(10, 52, 214, 118)];
  ecoD.tag = 503;
  ecoD.numberOfLines = 4;
  ecoD.font = [UIFont boldSystemFontOfSize:13.5];
  ecoD.adjustsFontSizeToFitWidth = YES;
  ecoD.minimumScaleFactor = 0.85;
  ecoD.textColor = [UIColor colorWithWhite:0.94 alpha:1];
  ecoD.text = @"• ระบบไฮบริดสมบูรณ์ 100%\n• คันเร่งนุ่มนวล ประหยัดสูงสุด\n• ดึงไฟชาร์จกลับ: ดีเยี่ยม\n• เบรกไฟฟ้า ECB: แรงดันปกติ";
  [self.homeAiEcoCard addSubview:ecoD];

  self.homeThermalsCard = [[UIView alloc] initWithFrame:CGRectZero];
  self.homeThermalsCard.backgroundColor = [UIColor colorWithRed:.02 green:.045 blue:.06 alpha:.92];
  self.homeThermalsCard.layer.cornerRadius = 10;
  self.homeThermalsCard.layer.borderWidth = 1.0;
  self.homeThermalsCard.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
  [self.view addSubview:self.homeThermalsCard];

  UILabel *tRow1 = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 214, 52)];
  tRow1.tag = 601;
  tRow1.numberOfLines = 2;
  tRow1.font = [UIFont boldSystemFontOfSize:14.0];
  tRow1.textColor = [UIColor whiteColor];
  tRow1.text = @"🌡️ น้ำหล่อเย็นเครื่องยนต์\n     88 °C (เกณฑ์ปกติ)";
  [self.homeThermalsCard addSubview:tRow1];

  UILabel *tRow2 = [[UILabel alloc] initWithFrame:CGRectMake(10, 64, 214, 52)];
  tRow2.tag = 602;
  tRow2.numberOfLines = 2;
  tRow2.font = [UIFont boldSystemFontOfSize:14.0];
  tRow2.textColor = [UIColor colorWithRed:0.65 green:0.92 blue:1.0 alpha:1];
  tRow2.text = @"❄️ แอร์ห้องโดยสาร : 24.5 °C\n     อินเวอร์เตอร์ : 42 °C";
  [self.homeThermalsCard addSubview:tRow2];

  UILabel *tRow3 = [[UILabel alloc] initWithFrame:CGRectMake(10, 120, 214, 52)];
  tRow3.tag = 603;
  tRow3.numberOfLines = 2;
  tRow3.font = [UIFont boldSystemFontOfSize:14.0];
  tRow3.textColor = [UIColor colorWithRed:.35 green:.95 blue:.50 alpha:1];
  tRow3.text = @"🔋 แบตเตอรี่ 12V : 13.84 V\n     สถานะชาร์จไฟปกติ";
  [self.homeThermalsCard addSubview:tRow3];

  self.driveClockCard = [[UIView alloc] initWithFrame:CGRectZero];
  self.driveClockCard.backgroundColor = [UIColor colorWithRed:.03 green:.06 blue:.09 alpha:.9];
  self.driveClockCard.layer.cornerRadius = 12;
  self.driveClockCard.layer.borderWidth = 1.0;
  self.driveClockCard.layer.borderColor = [UIColor colorWithWhite:.2 alpha:1].CGColor;
  self.driveClockCard.hidden = YES;
  [self.view addSubview:self.driveClockCard];

  self.driveBatteryCard = [[UIView alloc] initWithFrame:CGRectZero];
  self.driveBatteryCard.backgroundColor = [UIColor colorWithRed:.03 green:.06 blue:.09 alpha:.9];
  self.driveBatteryCard.layer.cornerRadius = 12;
  self.driveBatteryCard.layer.borderWidth = 1.0;
  self.driveBatteryCard.layer.borderColor = [UIColor colorWithWhite:.2 alpha:1].CGColor;
  self.driveBatteryCard.hidden = YES;
  [self.view addSubview:self.driveBatteryCard];

  self.driveTripCard = [[UIView alloc] initWithFrame:CGRectZero];
  self.driveTripCard.backgroundColor = [UIColor colorWithRed:.03 green:.06 blue:.09 alpha:.9];
  self.driveTripCard.layer.cornerRadius = 12;
  self.driveTripCard.layer.borderWidth = 1.0;
  self.driveTripCard.layer.borderColor = [UIColor colorWithWhite:.2 alpha:1].CGColor;
  self.driveTripCard.hidden = YES;
  [self.view addSubview:self.driveTripCard];

  self.driveEqBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  [self.driveEqBtn setTitle:@"\U0001F39B\U0000FE0F EQ SOUND: JBL BASS" forState:UIControlStateNormal];
  self.driveEqBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
  self.driveEqBtn.backgroundColor = [UIColor colorWithRed:.04 green:.10 blue:.16 alpha:.9];
  self.driveEqBtn.layer.cornerRadius = 8;
  self.driveEqBtn.layer.borderWidth = 1.0;
  self.driveEqBtn.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.4].CGColor;
  [self.driveEqBtn addTarget:self action:@selector(openDriveEQ) forControlEvents:UIControlEventTouchUpInside];
  self.driveEqBtn.hidden = YES;
  [self.view addSubview:self.driveEqBtn];

  self.driveExitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  [self.driveExitBtn setTitle:@"\U0001F3E0 EXIT TO HOME" forState:UIControlStateNormal];
  self.driveExitBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11.5];
  self.driveExitBtn.backgroundColor = [UIColor colorWithRed:.12 green:.06 blue:.08 alpha:.9];
  self.driveExitBtn.layer.cornerRadius = 8;
  self.driveExitBtn.layer.borderWidth = 1.0;
  self.driveExitBtn.layer.borderColor = [UIColor colorWithRed:1 green:.3 blue:.3 alpha:.4].CGColor;
  [self.driveExitBtn addTarget:self action:@selector(homePage) forControlEvents:UIControlEventTouchUpInside];
  self.driveExitBtn.hidden = YES;
  [self.view addSubview:self.driveExitBtn];


  self.blockGraphView = [[TRD14BlockGraphView alloc]initWithFrame:CGRectZero];
  self.blockGraphView.voltages = @[@16.23,@16.24,@16.23,@16.24,@16.22,@16.23,@16.24,@16.23,@16.22,@16.24,@16.23,@16.22,@16.24,@16.23];
  [self.view addSubview:self.blockGraphView];

 self.driveLeftCard=[[UIView alloc]init];self.driveLeftCard.backgroundColor=[UIColor colorWithRed:.06 green:.07 blue:.09 alpha:.92];self.driveLeftCard.layer.cornerRadius=14;self.driveLeftCard.layer.borderWidth=1.2;self.driveLeftCard.layer.borderColor=[blue colorWithAlphaComponent:.35].CGColor;self.driveLeftCard.hidden=YES;self.driveLeftCard.userInteractionEnabled=NO;[self.view addSubview:self.driveLeftCard];
 self.driveRightCard=[[UIView alloc]init];self.driveRightCard.backgroundColor=[UIColor colorWithRed:.06 green:.07 blue:.09 alpha:.92];self.driveRightCard.layer.cornerRadius=14;self.driveRightCard.layer.borderWidth=1.2;self.driveRightCard.layer.borderColor=[blue colorWithAlphaComponent:.35].CGColor;self.driveRightCard.hidden=YES;self.driveRightCard.userInteractionEnabled=NO;[self.view addSubview:self.driveRightCard];
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
 self.brakeStatusCard=[UIButton buttonWithType:UIButtonTypeCustom];self.brakeStatusCard.backgroundColor=[UIColor colorWithRed:.04 green:.08 blue:.05 alpha:.88];self.brakeStatusCard.layer.cornerRadius=8;self.brakeStatusCard.layer.borderWidth=1.2;self.brakeStatusCard.layer.borderColor=[UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.45].CGColor;[self.brakeStatusCard addTarget:self action:@selector(openBrakeDiagnosticsMenu) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.brakeStatusCard];UILabel *bTitle=[[UILabel alloc]initWithFrame:CGRectMake(8,4,172,16)];bTitle.tag=501;bTitle.font=[UIFont boldSystemFontOfSize:10.5];bTitle.textColor=[UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];bTitle.text=@"🛡️ BRAKE / ABS: NORMAL";bTitle.userInteractionEnabled=NO;[self.brakeStatusCard addSubview:bTitle];UILabel *bSub=[[UILabel alloc]initWithFrame:CGRectMake(8,20,172,16)];bSub.tag=502;bSub.font=[UIFont systemFontOfSize:9.5];bSub.textColor=[UIColor colorWithWhite:.75 alpha:1];bSub.text=@"FLUID: OK • PUMP: 18.5 MPa";bSub.userInteractionEnabled=NO;[self.brakeStatusCard addSubview:bSub];[self refreshBrakeStatus];
 self.hybridSocCard=[UIButton buttonWithType:UIButtonTypeCustom];self.hybridSocCard.backgroundColor=[UIColor colorWithRed:.02 green:.07 blue:.06 alpha:.88];self.hybridSocCard.layer.cornerRadius=8;self.hybridSocCard.layer.borderWidth=1.2;self.hybridSocCard.layer.borderColor=[UIColor colorWithRed:.0 green:.78 blue:.55 alpha:.45].CGColor;[self.hybridSocCard addTarget:self action:@selector(openHybridDiagnosticsMenu) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.hybridSocCard];UILabel *hTitle=[[UILabel alloc]initWithFrame:CGRectMake(8,4,172,16)];hTitle.tag=601;hTitle.font=[UIFont boldSystemFontOfSize:10.5];hTitle.textColor=[UIColor colorWithRed:.0 green:.92 blue:.70 alpha:1];hTitle.text=@"🔋 HYBRID SOC: 74% (EV READY)";hTitle.userInteractionEnabled=NO;[self.hybridSocCard addSubview:hTitle];UILabel *hSub=[[UILabel alloc]initWithFrame:CGRectMake(8,20,172,16)];hSub.tag=602;hSub.font=[UIFont systemFontOfSize:9.5];hSub.textColor=[UIColor colorWithWhite:.75 alpha:1];hSub.text=@"ECT: 89°C • INV: 42°C • 14.1V";hSub.userInteractionEnabled=NO;[self.hybridSocCard addSubview:hSub];[self refreshHybridStatus];
 self.energyFlowLabel=[self label:12 color:[UIColor colorWithRed:.0 green:.9 blue:.5 alpha:1]];self.energyFlowLabel.textAlignment=NSTextAlignmentCenter;self.energyFlowLabel.font=[UIFont boldSystemFontOfSize:11];self.energyFlowLabel.text=@"⚡ EV MOTOR · READY";
 self.gps=[CLLocationManager new];self.gps.delegate=self;self.gps.desiredAccuracy=kCLLocationAccuracyBest;self.gps.distanceFilter=kCLDistanceFilterNone;self.gps.activityType=CLActivityTypeAutomotiveNavigation;
 self.audioBars=[[AudioBars alloc]init];[self.view addSubview:self.audioBars];
 self.network=[self label:14 color:[UIColor lightGrayColor]];self.network.textAlignment=NSTextAlignmentRight;self.network.hidden=YES;
 self.statusStrip=[UIView new];[self.view addSubview:self.statusStrip];NSMutableArray *chips=[NSMutableArray array];for(NSString *name in @[@"CAR BT",@"WI-FI",@"AUDIO",@"GPS",@"POWER"]){UIButton *chip=[UIButton buttonWithType:UIButtonTypeCustom];chip.backgroundColor=[UIColor colorWithWhite:.055 alpha:1];chip.layer.cornerRadius=5;chip.layer.borderWidth=1;chip.layer.borderColor=[UIColor colorWithWhite:.14 alpha:1].CGColor;chip.tag=310+chips.count;[chip addTarget:self action:@selector(statusChipTapped:) forControlEvents:UIControlEventTouchUpInside];UILabel *title=[UILabel new];title.tag=301;title.text=name;title.font=[UIFont boldSystemFontOfSize:8];title.textColor=[UIColor colorWithWhite:.48 alpha:1];title.textAlignment=NSTextAlignmentCenter;title.userInteractionEnabled=NO;[chip addSubview:title];UILabel *value=[UILabel new];value.tag=302;value.font=[UIFont boldSystemFontOfSize:11];value.adjustsFontSizeToFitWidth=YES;value.minimumScaleFactor=.7;value.textColor=[UIColor lightGrayColor];value.textAlignment=NSTextAlignmentCenter;value.lineBreakMode=NSLineBreakByTruncatingMiddle;value.userInteractionEnabled=NO;[chip addSubview:value];[self.statusStrip addSubview:chip];[chips addObject:chip];}self.statusChips=chips;
 self.clock=[self label:160 color:[UIColor whiteColor]];self.clock.font=[UIFont fontWithName:@"HelveticaNeue-UltraLight" size:160]?:[UIFont systemFontOfSize:160];self.clock.textAlignment=NSTextAlignmentCenter;self.clock.adjustsFontSizeToFitWidth=YES;
 self.date=[self label:22 color:[UIColor colorWithWhite:.72 alpha:1]];self.date.textAlignment=NSTextAlignmentCenter;
 self.nowPanel=[[UIView alloc]init];self.nowPanel.backgroundColor=[UIColor colorWithWhite:.055 alpha:.95];self.nowPanel.layer.cornerRadius=6;self.nowPanel.layer.borderWidth=1;self.nowPanel.layer.borderColor=[UIColor colorWithWhite:.17 alpha:1].CGColor;[self.view addSubview:self.nowPanel];
 self.sourceBadge=[[UILabel alloc]init];self.sourceBadge.font=[UIFont boldSystemFontOfSize:10];self.sourceBadge.textAlignment=NSTextAlignmentCenter;self.sourceBadge.layer.cornerRadius=4;self.sourceBadge.clipsToBounds=YES;self.sourceBadge.textColor=[UIColor whiteColor];self.sourceBadge.backgroundColor=[blue colorWithAlphaComponent:.28];self.sourceBadge.layer.borderWidth=1;self.sourceBadge.layer.borderColor=[blue colorWithAlphaComponent:.6].CGColor;self.sourceBadge.text=@"MUSIC";self.sourceBadge.userInteractionEnabled=YES;UITapGestureRecognizer *btap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openActiveSourceApp)];[self.sourceBadge addGestureRecognizer:btap];[self.nowPanel addSubview:self.sourceBadge];
 self.artwork=[[UIImageView alloc]init];self.artwork.contentMode=UIViewContentModeScaleAspectFill;self.artwork.clipsToBounds=YES;self.artwork.layer.cornerRadius=4;self.artwork.userInteractionEnabled=YES;[self.artwork addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openActiveSourceApp)]];[self.view addSubview:self.artwork];self.artPlaceholder=[self label:28 color:blue];self.artPlaceholder.text=@"♫";self.artPlaceholder.textAlignment=NSTextAlignmentCenter;self.artPlaceholder.userInteractionEnabled=YES;[self.artPlaceholder addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openActiveSourceApp)]];
 self.trackTime=[self label:10 color:[UIColor colorWithWhite:.65 alpha:1]];self.trackTime.textAlignment=NSTextAlignmentRight;self.trackTime.adjustsFontSizeToFitWidth=YES;self.trackTime.text=@"--:-- / --:--";self.trackProgress=[[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];self.trackProgress.progressTintColor=blue;self.trackProgress.trackTintColor=[UIColor colorWithWhite:.18 alpha:1];self.trackProgress.userInteractionEnabled=NO;[self.view addSubview:self.trackProgress];
 self.artist=[self label:12 color:[UIColor lightGrayColor]];self.artist.adjustsFontSizeToFitWidth=YES;
 self.carStatus=[self label:13 color:[UIColor lightGrayColor]];self.carStatus.textAlignment=NSTextAlignmentCenter;self.carStatus.text=@"CAR DISCONNECTED";self.carStatus.font=[UIFont boldSystemFontOfSize:13];
 self.song=[self label:18 color:[UIColor colorWithRed:1 green:.78 blue:.42 alpha:1]];self.song.textAlignment=NSTextAlignmentLeft;self.song.adjustsFontSizeToFitWidth=YES;
 self.hint=[self label:15 color:[UIColor grayColor]];self.hint.textAlignment=NSTextAlignmentCenter;self.hint.text=@"Tap anywhere to return";self.hint.hidden=YES;
 self.clockHud=[[UIView alloc]init];self.clockHud.backgroundColor=[UIColor colorWithRed:.05 green:.05 blue:.06 alpha:.94];self.clockHud.layer.cornerRadius=8;self.clockHud.layer.borderWidth=1;self.clockHud.layer.borderColor=[blue colorWithAlphaComponent:.38].CGColor;self.clockHud.userInteractionEnabled=NO;self.clockHud.hidden=YES;[self.view addSubview:self.clockHud];UIView *hudAccent=[[UIView alloc]initWithFrame:CGRectMake(0,16,4,76)];hudAccent.tag=401;hudAccent.backgroundColor=blue;[self.clockHud addSubview:hudAccent];UILabel *hudSpeed=[[UILabel alloc]initWithFrame:CGRectMake(16,8,168,70)];hudSpeed.tag=402;hudSpeed.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:72]?:[UIFont boldSystemFontOfSize:72];hudSpeed.textColor=[UIColor whiteColor];hudSpeed.textAlignment=NSTextAlignmentCenter;hudSpeed.adjustsFontSizeToFitWidth=YES;hudSpeed.text=@"--";[self.clockHud addSubview:hudSpeed];UILabel *hudUnit=[[UILabel alloc]initWithFrame:CGRectMake(16,76,168,22)];hudUnit.tag=403;hudUnit.font=[UIFont boldSystemFontOfSize:13];hudUnit.textColor=blue;hudUnit.textAlignment=NSTextAlignmentCenter;hudUnit.text=@"km/h  •  GPS HUD";[self.clockHud addSubview:hudUnit];UIView *hudDiv=[[UIView alloc]initWithFrame:CGRectMake(196,18,1,72)];hudDiv.tag=404;hudDiv.backgroundColor=[UIColor colorWithWhite:.18 alpha:1];[self.clockHud addSubview:hudDiv];UILabel *hudGps=[[UILabel alloc]initWithFrame:CGRectMake(214,16,230,22)];hudGps.tag=405;hudGps.font=[UIFont boldSystemFontOfSize:13];hudGps.textColor=[UIColor colorWithWhite:.76 alpha:1];hudGps.adjustsFontSizeToFitWidth=YES;hudGps.text=@"WAITING FOR GPS";[self.clockHud addSubview:hudGps];UILabel *hudAcc=[[UILabel alloc]initWithFrame:CGRectMake(214,43,230,20)];hudAcc.tag=406;hudAcc.font=[UIFont systemFontOfSize:12];hudAcc.textColor=[UIColor colorWithWhite:.55 alpha:1];hudAcc.adjustsFontSizeToFitWidth=YES;hudAcc.text=@"SIGNAL  •  SEARCHING SATELLITES";[self.clockHud addSubview:hudAcc];UILabel *hudTrip=[[UILabel alloc]initWithFrame:CGRectMake(214,68,230,22)];hudTrip.tag=407;hudTrip.font=[UIFont boldSystemFontOfSize:12];hudTrip.textColor=blue;hudTrip.adjustsFontSizeToFitWidth=YES;hudTrip.text=@"TRIP  AUTO  •  WAITING FOR MOVEMENT";[self.clockHud addSubview:hudTrip];
 self.clockFormat=[NSDateFormatter new];self.clockFormat.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];self.clockFormat.dateFormat=@"HH:mm";self.dateFormat=[NSDateFormatter new];self.dateFormat.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];self.dateFormat.dateFormat=@"EEEE, d MMMM yyyy";
 self.cards=[NSMutableArray array];NSArray *names=@[@"YouTube",@"audioNINJA",@"Maps",@"Camera",@"Settings",@"Full Clock"];
 for(int i=0;i<6;i++){UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=i+1;b.backgroundColor=[UIColor colorWithRed:.065 green:.065 blue:.075 alpha:1];b.layer.cornerRadius=7;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithRed:.25 green:.12 blue:.14 alpha:1].CGColor;UILabel *title=[UILabel new];title.tag=100;title.text=names[i];title.font=[UIFont boldSystemFontOfSize:24];title.textColor=i==0?blue:[UIColor whiteColor];[b addSubview:title];DashIcon *icon=[[DashIcon alloc]init];icon.kind=i+1;icon.tag=104;icon.backgroundColor=[UIColor clearColor];icon.userInteractionEnabled=NO;[b addSubview:icon];b.accessibilityLabel=names[i];UIView *accent=[[UIView alloc]init];accent.tag=102;accent.backgroundColor=blue;accent.userInteractionEnabled=NO;[b addSubview:accent];title.userInteractionEnabled=NO;[b addTarget:self action:@selector(card:) forControlEvents:UIControlEventTouchUpInside];[self.cards addObject:b];[self.view addSubview:b];}
 self.controls=[UIView new];[self.view addSubview:self.controls];NSArray *commands=@[@"Previous",@"Play / Pause",@"Next",@"Equalizer"];for(int i=0;i<4;i++){UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.tag=20+i;b.backgroundColor=[UIColor colorWithRed:.11 green:.055 blue:.065 alpha:1];b.layer.cornerRadius=7;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithRed:.35 green:.10 blue:.13 alpha:1].CGColor;b.accessibilityLabel=commands[i];if(i<3){DashIcon *icon=[[DashIcon alloc]init];icon.kind=7+i;icon.tag=105;icon.backgroundColor=[UIColor clearColor];icon.userInteractionEnabled=NO;[b addSubview:icon];}else [b setTitle:commands[i] forState:UIControlStateNormal];[b setTitleColor:blue forState:UIControlStateNormal];b.titleLabel.font=[UIFont boldSystemFontOfSize:22];[b addTarget:self action:@selector(media:) forControlEvents:UIControlEventTouchUpInside];[self.controls addSubview:b];}
 self.navigation=[UIView new];self.navigation.backgroundColor=[UIColor colorWithWhite:.035 alpha:1];self.navigation.layer.borderWidth=1;self.navigation.layer.borderColor=[UIColor colorWithWhite:.16 alpha:1].CGColor;[self.view addSubview:self.navigation];NSMutableArray *nav=[NSMutableArray array];NSArray *navNames=@[@"HOME",@"CARPLAY",@"MAPS",@"YOUTUBE",@"audioNINJA",@"CAMERA",@"SETTINGS"];NSInteger kinds[]={10,15,3,1,2,4,5};NSInteger tags[]={60,66,62,67,61,65,68};for(int i=0;i<7;i++){UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=tags[i];b.accessibilityLabel=navNames[i];b.layer.cornerRadius=8;DashIcon *icon=[DashIcon new];icon.kind=kinds[i];icon.tag=201;icon.backgroundColor=[UIColor clearColor];icon.userInteractionEnabled=NO;[b addSubview:icon];UILabel *text=[UILabel new];text.tag=202;text.text=navNames[i];text.textColor=[UIColor lightGrayColor];text.font=[UIFont boldSystemFontOfSize:13];text.userInteractionEnabled=NO;[b addSubview:text];UIView *line=[UIView new];line.tag=203;line.backgroundColor=blue;line.userInteractionEnabled=NO;[b addSubview:line];[b addTarget:self action:@selector(navigate:) forControlEvents:UIControlEventTouchUpInside];[self.navigation addSubview:b];[nav addObject:b];}self.navButtons=nav;
 self.musicHeading=[self label:16 color:blue];self.musicHeading.text=@"NOW PLAYING";self.musicHeading.font=[UIFont boldSystemFontOfSize:16];self.musicHeading.hidden=YES;self.browseMusic=[UIButton buttonWithType:UIButtonTypeCustom];[self.browseMusic setTitle:@"Browse music" forState:UIControlStateNormal];self.browseMusic.titleLabel.font=[UIFont boldSystemFontOfSize:16];self.browseMusic.backgroundColor=[UIColor colorWithWhite:.09 alpha:1];self.browseMusic.layer.cornerRadius=7;self.browseMusic.layer.borderWidth=1;self.browseMusic.layer.borderColor=[UIColor colorWithWhite:.25 alpha:1].CGColor;[self.browseMusic addTarget:self action:@selector(showMusicSources:) forControlEvents:UIControlEventTouchUpInside];self.browseMusic.hidden=YES;[self.view addSubview:self.browseMusic];[self.nowPanel addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openMusic)]];
 self.tripView=[TRDTripView new];self.tripView.hidden=YES;[self.view addSubview:self.tripView];[self.tripView.run addTarget:self action:@selector(toggleTrip) forControlEvents:UIControlEventTouchUpInside];[self.tripView.reset addTarget:self action:@selector(resetTripMenu) forControlEvents:UIControlEventTouchUpInside];[self.tripView.close addTarget:self action:@selector(homePage) forControlEvents:UIControlEventTouchUpInside];self.driveTripButton=[UIButton buttonWithType:UIButtonTypeCustom];self.driveTripButton.titleLabel.font=[UIFont boldSystemFontOfSize:14];self.driveTripButton.titleLabel.adjustsFontSizeToFitWidth=YES;self.driveTripButton.titleLabel.minimumScaleFactor=.8;self.driveTripButton.backgroundColor=[UIColor colorWithWhite:.055 alpha:1];self.driveTripButton.layer.cornerRadius=8;self.driveTripButton.layer.borderWidth=1;self.driveTripButton.layer.borderColor=[UIColor colorWithWhite:.2 alpha:1].CGColor;self.driveTripButton.accessibilityLabel=@"Open GPS trip summary";UIGraphicsBeginImageContextWithOptions(CGSizeMake(24,24),NO,0);[[UIColor whiteColor]setStroke];UIBezierPath *pin=[UIBezierPath bezierPath];pin.lineWidth=1.8;[pin moveToPoint:CGPointMake(12,22)];[pin addCurveToPoint:CGPointMake(4,9) controlPoint1:CGPointMake(10,18) controlPoint2:CGPointMake(4,13)];[pin addArcWithCenter:CGPointMake(12,9) radius:8 startAngle:M_PI endAngle:0 clockwise:YES];[pin addCurveToPoint:CGPointMake(12,22) controlPoint1:CGPointMake(20,13) controlPoint2:CGPointMake(14,18)];[pin stroke];UIBezierPath *pinCenter=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9,6,6,6)];pinCenter.lineWidth=1.6;[pinCenter stroke];UIImage *tripIcon=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();[self.driveTripButton setImage:[tripIcon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];self.driveTripButton.imageEdgeInsets=UIEdgeInsetsMake(0,-8,0,0);self.driveTripButton.titleEdgeInsets=UIEdgeInsetsMake(0,5,0,0);[self.driveTripButton addTarget:self action:@selector(openTrip) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveTripButton];
 self.driveCameraButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.driveCameraButton setTitle:@"CAMERA" forState:0];self.driveCameraButton.titleLabel.font=[UIFont boldSystemFontOfSize:22];self.driveCameraButton.backgroundColor=[TRDAccent()colorWithAlphaComponent:.20];self.driveCameraButton.layer.cornerRadius=8;self.driveCameraButton.layer.borderWidth=1.5;self.driveCameraButton.layer.borderColor=[TRDAccent()colorWithAlphaComponent:.8].CGColor;self.driveCameraButton.accessibilityLabel=@"Open live camera";self.driveCameraButton.accessibilityHint=@"View blind spots and follow the main camera";[self.driveCameraButton addTarget:self action:@selector(openCamera) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveCameraButton];
 self.tripButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.tripButton setTitle:@"TRIP / GPS ›" forState:0];self.tripButton.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.tripButton setTitleColor:TRDAccent() forState:0];self.tripButton.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.tripButton.layer.cornerRadius=6;[self.tripButton addTarget:self action:@selector(openTrip) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.tripButton];
 self.radioButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.radioButton setTitle:@"📻 RADIO" forState:0];self.radioButton.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.radioButton setTitleColor:TRDAccent() forState:0];self.radioButton.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.radioButton.layer.cornerRadius=6;self.radioButton.layer.borderWidth=1;self.radioButton.layer.borderColor=[TRDAccent() colorWithAlphaComponent:.4].CGColor;[self.radioButton addTarget:self action:@selector(openRadioStationsMenu) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.radioButton];
  self.offlineMusicBtn=[UIButton buttonWithType:UIButtonTypeCustom];[self.offlineMusicBtn setTitle:@"💾 OFFLINE" forState:0];self.offlineMusicBtn.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.offlineMusicBtn setTitleColor:TRDAccent() forState:0];self.offlineMusicBtn.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.offlineMusicBtn.layer.cornerRadius=6;self.offlineMusicBtn.layer.borderWidth=1;self.offlineMusicBtn.layer.borderColor=[TRDAccent() colorWithAlphaComponent:.4].CGColor;[self.offlineMusicBtn addTarget:self action:@selector(openOfflineMusicMenu) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.offlineMusicBtn];
  self.searchMusicBtn=[UIButton buttonWithType:UIButtonTypeCustom];[self.searchMusicBtn setTitle:@"🔍 SEARCH" forState:0];self.searchMusicBtn.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.searchMusicBtn setTitleColor:TRDAccent() forState:0];self.searchMusicBtn.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.searchMusicBtn.layer.cornerRadius=6;self.searchMusicBtn.layer.borderWidth=1;self.searchMusicBtn.layer.borderColor=[TRDAccent() colorWithAlphaComponent:.4].CGColor;[self.searchMusicBtn addTarget:self action:@selector(openSearchMusic) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.searchMusicBtn];
 self.miniPlayer=[TRDMini new];self.miniPlayer.hidden=YES;[self.miniPlayer.prev addTarget:self action:@selector(miniPrev) forControlEvents:UIControlEventTouchUpInside];[self.miniPlayer.play addTarget:self action:@selector(miniPlay) forControlEvents:UIControlEventTouchUpInside];[self.miniPlayer.next addTarget:self action:@selector(miniNext) forControlEvents:UIControlEventTouchUpInside];[self.miniPlayer.open addTarget:self action:@selector(miniOpen) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.miniPlayer];UILongPressGestureRecognizer *musicHold=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(musicHold:)];musicHold.minimumPressDuration=.55;[self.navButtons[4]addGestureRecognizer:musicHold];UILongPressGestureRecognizer *homeHold=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(homeHold:)];homeHold.minimumPressDuration=.55;[self.navButtons[0]addGestureRecognizer:homeHold];
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

  self.carplayMediaWidget = [[TRDCarPlayMediaWidget alloc] initWithFrame:CGRectZero];
  self.carplayMediaWidget.hidden = YES;
  [self.carplayMediaWidget.btnPrev addTarget:self action:@selector(miniPrev) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayMediaWidget.btnPlay addTarget:self action:@selector(miniPlay) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayMediaWidget.btnNext addTarget:self action:@selector(miniNext) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayMediaWidget.btnEQ addTarget:self action:@selector(openDriveEQ) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayMediaWidget.btnRadio addTarget:self action:@selector(openRadioStationsMenu) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.carplayMediaWidget];

  self.carplayTelemetryWidget = [[TRDCarPlayTelemetryWidget alloc] initWithFrame:CGRectZero];
  self.carplayTelemetryWidget.hidden = YES;
  [self.carplayTelemetryWidget.rearCamBtn addTarget:self action:@selector(openCamera) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayTelemetryWidget.exitBtn addTarget:self action:@selector(homePage) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.carplayTelemetryWidget];

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
 self.returnTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(leaveClock)];self.returnTap.enabled=NO;self.returnTap.delegate=self;[self.view addGestureRecognizer:self.returnTap];[UIDevice currentDevice].batteryMonitoringEnabled=YES;[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryStateDidChangeNotification object:nil];dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager",RTLD_LAZY);Class manager=NSClassFromString(@"BluetoothManager");if([manager respondsToSelector:@selector(sharedInstance)])self.bluetooth=[manager performSelector:@selector(sharedInstance)];dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_LAZY);[self update];if(!self.didShowWelcome){self.didShowWelcome=YES;[self showWelcome];}
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

-(void)hideAllHomeWidgets:(BOOL)hide {
  self.homeSpeedoDial.hidden = hide;
  self.homeAiEcoCard.hidden = hide;
  self.homeThermalsCard.hidden = hide;
  self.driveLeftCard.hidden = hide;
  self.driveRightCard.hidden = hide;
  self.readyPill.hidden = hide;
  self.gearBadge.hidden = YES;
  for (UIButton *b in self.gearButtons) b.hidden = hide;
  self.hybridEcoBar.hidden = hide;
  for (UIButton *b in self.driveModePills) b.hidden = hide;
  self.frontMotorBox.hidden = hide;
  self.rearBatteryBox.hidden = hide;
  self.flowBeamLine.hidden = hide;
  self.blockGraphView.hidden = hide;
  self.topClockLabel.hidden = hide;
  self.obdStatusPill.hidden = hide;
  self.dayNightPill.hidden = hide;
  self.thaiVoicePill.hidden = hide;
  self.settingsPill.hidden = hide;
  self.carImage.hidden = hide;
  self.compassLabel.hidden = hide;
  self.carStatus.hidden = hide;
  self.energyFlowLabel.hidden = hide;
  self.speed.hidden = YES;
  self.unit.hidden = YES;
  self.speedLimitBtn.hidden = YES;
  self.arc.hidden = YES;
  self.progress.hidden = YES;
  self.brakeStatusCard.hidden = YES;
  self.hybridSocCard.hidden = YES;
  self.nowPanel.hidden = hide;
  UIView *pCard = [self.view viewWithTag:701]; if (pCard) pCard.hidden = hide;
  UIView *deltaL = [self.view viewWithTag:706]; if (deltaL) deltaL.hidden = hide;
  UIView *mCard = [self.view viewWithTag:707]; if (mCard) mCard.hidden = hide;
  UIView *tCard = [self.view viewWithTag:711]; if (tCard) tCard.hidden = hide;
  UIView *mH = [self.nowPanel viewWithTag:750]; if (mH) mH.hidden = hide;
}

-(void)hideAllDriveWidgets:(BOOL)hide {
  self.driveSpeedoDial.hidden = hide;
  self.driveShifter.hidden = hide;
  self.drivePowerMeter.hidden = hide;
  self.drive3DGrid.hidden = hide;
  self.driveClockCard.hidden = hide;
  self.driveBatteryCard.hidden = hide;
  self.driveTripCard.hidden = hide;
  self.driveEqBtn.hidden = hide;
  self.driveExitBtn.hidden = hide;
  self.driveCar.hidden = hide;
  self.driveCameraButton.hidden = hide;
  self.radioButton.hidden = hide;
}

-(void)viewDidLayoutSubviews{
  [super viewDidLayoutSubviews];
  self.carGlow.hidden = YES;
  // Early welcome deferred to end of viewDidLayoutSubviews

  CGFloat w = self.view.bounds.size.width;
  CGFloat fullH = self.view.bounds.size.height;
  CGFloat h = fullH - (self.focused ? 0 : 78);
  BOOL landscape = (w > h);

  // 1. CARPLAY MODE LAYOUT
  self.carplayDock.hidden = !self.carplayMode;
  self.carplayTurnBanner.hidden = YES;
  self.carplayMediaCard.hidden = !(self.carplayMode && !self.carplayGridMode);
  self.carplayTelemetryCard.hidden = !(self.carplayMode && !self.carplayGridMode);
  self.carplayAppGrid.hidden = !(self.carplayMode && self.carplayGridMode);

  if (self.carplayMode) {
    [self hideAllHomeWidgets:YES];
    [self hideAllDriveWidgets:YES];
    self.navigation.hidden = YES;
    self.heading.hidden = YES;
    self.owner.hidden = YES;
    self.clock.hidden = YES;
    self.date.hidden = YES;
    self.nowPanel.hidden = YES;
    self.driveEQ.hidden = YES;
    self.miniPlayer.hidden = YES;
    self.tripButton.hidden = YES;

    self.carplayDock.frame = CGRectMake(0, 0, 80, fullH);
    self.carplayHomeBtn.frame = CGRectMake(13, 14, 54, 54);
    for (int i = 0; i < self.carplayDockButtons.count; i++) {
      UIView *db = self.carplayDockButtons[i];
      db.frame = CGRectMake(13, 85 + i * 66, 54, 54);
    }
    self.carplayClock.frame = CGRectMake(4, fullH - 76, 72, 20);
    self.carplayBattery.frame = CGRectMake(4, fullH - 54, 72, 18);
    self.carplayWifi.frame = CGRectMake(8, fullH - 32, 64, 18);

    // Hide raw legacy media controls from self.view to avoid stray overlays
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

      CGFloat colW = 180, rowH = 170, gapX = 36, gapY = 40;
      CGFloat startX = (w - 76 - (4 * colW + 3 * gapX)) / 2.0;
      CGFloat startY = (fullH - (2 * rowH + gapY)) / 2.0;
      for (int i = 0; i < self.carplayGridButtons.count; i++) {
        UIView *gb = self.carplayGridButtons[i];
        int col = i % 4, row = i / 4;
        gb.frame = CGRectMake(startX + col * (colW + gapX), startY + row * (rowH + gapY), colW, rowH);
        UIView *ib = [gb viewWithTag:101];
        CGFloat iconSize = 80;
        ib.frame = CGRectMake((colW - iconSize) / 2.0, 16, iconSize, iconSize);
        UILabel *gt = (UILabel *)[gb viewWithTag:102];
        gt.frame = CGRectMake(8, 110, colW - 16, 28);
        gt.font = [UIFont boldSystemFontOfSize:16];
        gt.textColor = [UIColor whiteColor];
      }
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
      if (self.mapWebView) { self.mapWebView.frame = self.mapContainer.bounds; [self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.map){window.map.invalidateSize(); if(window.recenter)window.recenter(); }"]; }
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
  }

  // Hide legacy/unused items
  self.nightButton.hidden = YES;
  self.modeButton.hidden = YES;
  self.driveButton.hidden = YES;
  self.statusStrip.hidden = YES;
  self.tripButton.hidden = YES;
  self.brakeStatusCard.hidden = YES;
  self.hybridSocCard.hidden = YES;
  for (UIView *cb in self.cards) cb.hidden = YES;


  if (self.mapMode) {
    [self hideAllHomeWidgets:YES];
    [self hideAllDriveWidgets:YES];
    self.carplayDock.hidden = YES;
    self.carplayMediaWidget.hidden = YES;
    self.carplayTelemetryWidget.hidden = YES;
    self.carplayAppGrid.hidden = YES;
    self.navigation.hidden = NO;

    // Top Bar (Width: 1024, Height: 48)
    self.heading.hidden = NO;
    self.heading.frame = CGRectMake(16, 12, 380, 24);
    self.heading.font = [UIFont boldSystemFontOfSize:15];
    self.heading.textColor = [UIColor whiteColor];
    self.heading.text = @"PRIUS TRD SPORTIVO • MAP NAVIGATION";

    UIView *obdB = [self.view viewWithTag:702];
    if (obdB) { obdB.hidden = NO; obdB.frame = CGRectMake(w - 530, 10, 115, 28); }
    UIView *nightB = [self.view viewWithTag:703];
    if (nightB) { nightB.hidden = NO; nightB.frame = CGRectMake(w - 405, 10, 75, 28); }
    self.clock.hidden = NO;
    self.clock.frame = CGRectMake(w - 320, 10, 80, 28);
    self.clock.font = [UIFont boldSystemFontOfSize:15];
    self.clock.textColor = [UIColor whiteColor];
    self.clock.textAlignment = NSTextAlignmentCenter;
    self.clock.backgroundColor = [UIColor colorWithRed:.06 green:.08 blue:.12 alpha:.9];
    self.clock.layer.cornerRadius = 6;
    self.clock.clipsToBounds = YES;
    UIView *thaiB = [self.view viewWithTag:704];
    if (thaiB) { thaiB.hidden = NO; thaiB.frame = CGRectMake(w - 230, 10, 95, 28); }
    UIView *setB = [self.view viewWithTag:705];
    if (setB) { setB.hidden = NO; setB.frame = CGRectMake(w - 125, 10, 110, 28); }

    // Map Container (Takes full width and height between Top Bar and Bottom Dock)
    CGFloat mapTop = 48;
    CGFloat navH = 68;
    CGFloat mapH = fullH - mapTop - navH - 12;
    self.mapContainer.hidden = NO;
    self.mapContainer.frame = CGRectMake(14, mapTop, w - 28, mapH);
    self.mapContainer.layer.cornerRadius = 16;
    self.mapContainer.layer.borderWidth = 1.2;
    self.mapContainer.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
    self.mapContainer.clipsToBounds = YES;
    if (self.mapWebView) self.mapWebView.frame = self.mapContainer.bounds;

    // Bottom Navigation Bar
    self.navigation.frame = CGRectMake(14, fullH - navH - 6, w - 28, navH);
    self.navigation.layer.cornerRadius = 14;
    self.navigation.clipsToBounds = YES;
    CGFloat btnW = (w - 28 - 14) / (CGFloat)self.navButtons.count;
    for (int i = 0; i < self.navButtons.count; i++) {
      UIButton *b = self.navButtons[i];
      b.frame = CGRectMake(7 + i * btnW, 4, btnW - 6, navH - 8);
      DashIcon *icon = (DashIcon *)[b viewWithTag:201];
      icon.frame = CGRectMake((btnW - 6 - 24) / 2.0, 8, 24, 24);
      UILabel *lbl = (UILabel *)[b viewWithTag:202];
      lbl.frame = CGRectMake(0, 34, btnW - 6, 20);
      lbl.font = [UIFont boldSystemFontOfSize:11.5];
      lbl.textAlignment = NSTextAlignmentCenter;
      UIView *line = [b viewWithTag:203];
      line.frame = CGRectMake(8, navH - 12, btnW - 22, 2.5);
      line.hidden = (b.tag != 62); // Highlight MAPS button
    }

    [self.view bringSubviewToFront:self.mapContainer];
    [self.view bringSubviewToFront:self.navigation];
    if (self.settingsSheet) {
      self.settingsSheet.frame = self.view.bounds;
      [self.view bringSubviewToFront:self.settingsSheet];
    }
    return;
  }

  if (self.driveMode) {
    // =========================================================================
    // DRIVE MODE (100% Matching prius_drive_mode_concept.jpg)
    // =========================================================================
    [self hideAllHomeWidgets:YES];
    self.mapContainer.hidden = YES;
    self.carplayDock.hidden = YES;
    self.carplayMediaCard.hidden = YES;
    self.carplayTelemetryCard.hidden = YES;
    self.carplayAppGrid.hidden = YES;
    self.carplayMediaWidget.hidden = YES;
    self.carplayTelemetryWidget.hidden = YES;
    self.navigation.hidden = YES;
    self.nowPanel.hidden = NO;

    // Top Bar
    CGFloat barY = 12;
    self.heading.hidden = NO;
    self.heading.frame = CGRectMake(20, barY, 380, 24);
    self.heading.font = [UIFont boldSystemFontOfSize:15];
    self.heading.textColor = [UIColor whiteColor];
    self.heading.text = @"PRIUS TRD SPORTIVO • DRIVE COCKPIT";

    self.owner.hidden = YES;

    // Center Clock & Speed Limit in Header
    self.clock.hidden = NO;
    self.clock.frame = CGRectMake(w/2 - 60, barY, 80, 24);
    self.clock.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:22] ?: [UIFont boldSystemFontOfSize:22];
    self.clock.textColor = [UIColor whiteColor];
    self.clock.textAlignment = NSTextAlignmentCenter;
    self.date.hidden = YES;

    // Right Pills: GPS, OBD2, 12V
    CGFloat curRx = w - 20;
    CGFloat pillH = 26;
    curRx -= 90;
    self.thaiVoicePill.hidden = NO;
    self.thaiVoicePill.frame = CGRectMake(curRx, barY - 1, 90, pillH);
    [self.thaiVoicePill setTitle:@"12V: 13.8V" forState:UIControlStateNormal];

    curRx -= 105;
    self.obdStatusPill.hidden = NO;
    self.obdStatusPill.frame = CGRectMake(curRx, barY - 1, 100, pillH);
    [self.obdStatusPill setTitle:@"OBD2: LIVE" forState:UIControlStateNormal];

    curRx -= 115;
    self.dayNightPill.hidden = NO;
    self.dayNightPill.frame = CGRectMake(curRx, barY - 1, 110, pillH);
    [self.dayNightPill setTitle:@"GPS: 3D LOCK" forState:UIControlStateNormal];

    // Left Pod (Width: 250, Y: 48, Height: 590)
    CGFloat podW = 250, topY = 48;
    self.driveLeftCard.hidden = NO;
    self.driveLeftCard.frame = CGRectMake(18, topY, podW, 590);
    self.driveLeftCard.layer.cornerRadius = 14;
    self.driveLeftCard.layer.borderWidth = 1.0;
    self.driveLeftCard.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1].CGColor;
    self.driveLeftCard.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.08 alpha:0.95];

    self.driveSpeedoDial.hidden = NO;
    self.driveSpeedoDial.frame = CGRectMake(20, topY + 4, podW - 4, 180);

    self.driveShifter.hidden = NO;
    self.driveShifter.frame = CGRectMake(20 + (podW - 4 - 44)/2 + 20, topY + 190, 44, 138);

    self.gearBadge.hidden = NO;
    self.gearBadge.frame = CGRectMake(20 + (podW - 4 - 44)/2 - 54, topY + 242, 66, 26);

    self.drivePowerMeter.hidden = NO;
    self.drivePowerMeter.frame = CGRectMake(20, topY + 372, podW - 4, 204);

    // Center Pod (Width: 456, X: 284, Y: 48, Height: 590)
    CGFloat centerW = 456, centerX = 284;
    self.energyFlowLabel.hidden = NO;
    self.energyFlowLabel.frame = CGRectMake(centerX + 30, topY + 12, centerW - 60, 32);
    self.energyFlowLabel.font = [UIFont boldSystemFontOfSize:12];
    self.energyFlowLabel.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.energyFlowLabel.layer.cornerRadius = 8;
    self.energyFlowLabel.layer.borderWidth = 1.0;
    self.energyFlowLabel.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.4].CGColor;
    self.energyFlowLabel.backgroundColor = [UIColor colorWithRed:.02 green:.08 blue:.12 alpha:.8];
    self.energyFlowLabel.text = @"CRUISE 78 km/h  •  EV MODE READY";

    self.driveCameraButton.hidden = NO;
    self.driveCameraButton.frame = CGRectMake(centerX + 50, topY + 54, centerW - 100, 46);
    [self.driveCameraButton setTitle:@"\U0001F4F7  REAR CAMERA" forState:UIControlStateNormal];
    self.driveCameraButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.driveCameraButton.layer.cornerRadius = 10;
    self.driveCameraButton.layer.borderWidth = 1.2;
    self.driveCameraButton.layer.borderColor = [UIColor colorWithWhite:.3 alpha:1].CGColor;
    self.driveCameraButton.backgroundColor = [UIColor colorWithRed:.08 green:.12 blue:.16 alpha:.9];

    self.drive3DGrid.hidden = NO;
    self.drive3DGrid.frame = CGRectMake(centerX, topY + 200, centerW, 280);

    self.driveCar.hidden = NO;
    self.driveCar.frame = CGRectMake(centerX + (centerW - 390)/2, topY + 160, 390, 245);

    self.compassLabel.hidden = NO;
    self.compassLabel.frame = CGRectMake(centerX + 8, topY + 488, centerW - 16, 26);
    self.compassLabel.font = [UIFont boldSystemFontOfSize:14.0];
    self.compassLabel.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.compassLabel.textAlignment = NSTextAlignmentCenter;
    self.compassLabel.text = @"\u0e01\u0e23\u0e30\u0e41\u0e2a\u0e44\u0e1f\u0e44\u0e2e\u0e1a\u0e23\u0e34\u0e14: \u26a1 \u0e0a\u0e32\u0e23\u0e4c\u0e08\u0e44\u0e1f\u0e40\u0e02\u0e49\u0e32\u0e41\u0e1a\u0e15\u0e40\u0e15\u0e2d\u0e23\u0e35\u0e48 (Inflow)  +14.2 kW (Regen Active)";

    // Right Pod (Width: 250, X: 756, Y: 48, Height: 590)
    CGFloat rightX = 756;
    self.driveRightCard.hidden = NO;
    self.driveRightCard.frame = CGRectMake(rightX, topY, podW, 590);
    self.driveRightCard.layer.cornerRadius = 14;
    self.driveRightCard.layer.borderWidth = 1.0;
    self.driveRightCard.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1].CGColor;
    self.driveRightCard.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.08 alpha:0.95];

    self.driveClockCard.hidden = NO;
    self.driveClockCard.frame = CGRectMake(rightX + 12, topY + 12, podW - 24, 110);
    UILabel *cBig = (UILabel *)[self.driveClockCard viewWithTag:801];
    if (!cBig) {
      cBig = [[UILabel alloc] initWithFrame:CGRectMake(8, 8, podW - 40, 60)];
      cBig.tag = 801;
      cBig.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:64] ?: [UIFont boldSystemFontOfSize:64];
      cBig.textColor = [UIColor whiteColor];
      cBig.textAlignment = NSTextAlignmentCenter;
      [self.driveClockCard addSubview:cBig];
      UILabel *cSub = [[UILabel alloc] initWithFrame:CGRectMake(8, 70, podW - 40, 24)];
      cSub.tag = 802;
      cSub.font = [UIFont boldSystemFontOfSize:13];
      cSub.textColor = [UIColor colorWithWhite:0.7 alpha:1];
      cSub.textAlignment = NSTextAlignmentCenter;
      cSub.text = @"CABIN  24.0\u00b0C";
      [self.driveClockCard addSubview:cSub];
    }
    cBig.text = [self.clockFormat stringFromDate:[NSDate date]];

    self.driveBatteryCard.hidden = NO;
    self.driveBatteryCard.frame = CGRectMake(rightX + 12, topY + 132, podW - 24, 115);
    UILabel *bH = (UILabel *)[self.driveBatteryCard viewWithTag:811];
    if (!bH) {
      bH = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, podW - 44, 20)];
      bH.tag = 811;
      bH.font = [UIFont boldSystemFontOfSize:10];
      bH.textColor = [UIColor colorWithWhite:0.6 alpha:1];
      bH.text = @"HYBRID TRACTION BATTERY";
      [self.driveBatteryCard addSubview:bH];

      UIView *barBg = [[UIView alloc] initWithFrame:CGRectMake(10, 36, podW - 44, 16)];
      barBg.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
      barBg.layer.cornerRadius = 8;
      barBg.clipsToBounds = YES;
      UIView *barFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, (podW - 44) * 0.76, 16)];
      barFill.backgroundColor = [UIColor colorWithRed:0 green:.85 blue:.5 alpha:1];
      [barBg addSubview:barFill];
      [self.driveBatteryCard addSubview:barBg];

      UILabel *bS = [[UILabel alloc] initWithFrame:CGRectMake(10, 60, podW - 44, 34)];
      bS.tag = 812;
      bS.font = [UIFont boldSystemFontOfSize:15];
      bS.textColor = [UIColor colorWithRed:.2 green:.95 blue:.5 alpha:1];
      bS.text = @"76% (EV READY)";
      [self.driveBatteryCard addSubview:bS];
    }

    self.driveTripCard.hidden = NO;
    self.driveTripCard.frame = CGRectMake(rightX + 12, topY + 258, podW - 24, 160);
    UILabel *tH = (UILabel *)[self.driveTripCard viewWithTag:821];
    if (!tH) {
      tH = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, podW - 44, 20)];
      tH.tag = 821;
      tH.font = [UIFont boldSystemFontOfSize:11];
      tH.textColor = [UIColor colorWithWhite:0.6 alpha:1];
      tH.text = @"TRIP A:";
      [self.driveTripCard addSubview:tH];

      UILabel *tBody = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, podW - 44, 110)];
      tBody.tag = 822;
      tBody.numberOfLines = 4;
      tBody.font = [UIFont boldSystemFontOfSize:14];
      tBody.textColor = [UIColor whiteColor];
      tBody.text = @"\u2022 24.6 km\n\u2022 24.2 km/L\n\u2022 \u0e3f38.50";
      [self.driveTripCard addSubview:tBody];
    }

    self.radioButton.hidden = NO;
    self.radioButton.frame = CGRectMake(rightX + 12, topY + 434, podW - 24, 52);
    [self.radioButton setTitle:@"\U0001F4FB  THAI RADIO" forState:UIControlStateNormal];
    self.radioButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.radioButton.layer.cornerRadius = 10;
    self.radioButton.layer.borderWidth = 1.0;
    self.radioButton.layer.borderColor = [UIColor colorWithWhite:.25 alpha:1].CGColor;
    self.radioButton.backgroundColor = [UIColor colorWithRed:.06 green:.08 blue:.12 alpha:.9];

    // Bottom Console
    CGFloat consoleY = topY + 600;
    CGFloat consoleH = 96;
    self.nowPanel.hidden = NO;
    self.nowPanel.frame = CGRectMake(18, consoleY, w - 36, consoleH);
    self.nowPanel.layer.cornerRadius = 14;
    self.nowPanel.layer.borderWidth = 1.0;
    self.nowPanel.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.nowPanel.backgroundColor = [UIColor colorWithRed:.04 green:.06 blue:.08 alpha:.95];

    self.artwork.hidden = NO;
    self.artwork.frame = CGRectMake(28, consoleY + 12, consoleH - 24, consoleH - 24);
    self.artwork.layer.cornerRadius = 8;
    self.artPlaceholder.frame = self.artwork.frame;
    self.artPlaceholder.hidden = (self.artwork.image != nil);

    CGFloat artRight = 28 + consoleH - 24 + 14;
    self.song.hidden = NO;
    self.song.frame = CGRectMake(artRight, consoleY + 16, 260, 26);
    self.song.font = [UIFont boldSystemFontOfSize:15];
    self.song.textColor = [UIColor whiteColor];

    self.artist.hidden = NO;
    self.artist.frame = CGRectMake(artRight, consoleY + 44, 260, 20);
    self.artist.font = [UIFont systemFontOfSize:12];
    self.artist.textColor = [UIColor colorWithWhite:0.6 alpha:1];

    self.controls.hidden = NO;
    self.controls.frame = CGRectMake(artRight + 270, consoleY + 18, 180, 60);

    self.driveEqBtn.hidden = NO;
    self.driveEqBtn.frame = CGRectMake(w - 36 - 290, consoleY + 24, 135, 48);

    self.driveExitBtn.hidden = NO;
    self.driveExitBtn.frame = CGRectMake(w - 36 - 145, consoleY + 24, 135, 48);
    self.driveEQ.hidden = YES;
    UIView *mH = [self.nowPanel viewWithTag:750]; if(mH) mH.hidden = YES;

    // Bring subviews to front for Drive Mode
    [self.view bringSubviewToFront:self.driveLeftCard];
    [self.driveSpeedoDial setNeedsDisplay];
    [self.driveShifter setNeedsDisplay];
    [self.drivePowerMeter setNeedsDisplay];
    [self.drive3DGrid setNeedsDisplay];
    [self.view bringSubviewToFront:self.driveSpeedoDial];
    [self.view bringSubviewToFront:self.driveShifter];
    [self.view bringSubviewToFront:self.gearBadge];
    [self.view bringSubviewToFront:self.drivePowerMeter];
    [self.view bringSubviewToFront:self.drive3DGrid];
    [self.view bringSubviewToFront:self.driveCar];
    [self.view bringSubviewToFront:self.energyFlowLabel];
    [self.view bringSubviewToFront:self.driveCameraButton];
    [self.view bringSubviewToFront:self.compassLabel];
    [self.view bringSubviewToFront:self.driveRightCard];
    [self.view bringSubviewToFront:self.driveClockCard];
    [self.view bringSubviewToFront:self.driveBatteryCard];
    [self.view bringSubviewToFront:self.driveTripCard];
    [self.view bringSubviewToFront:self.radioButton];
    [self.view bringSubviewToFront:self.nowPanel];
    [self.view bringSubviewToFront:self.artwork];
    [self.view bringSubviewToFront:self.song];
    [self.view bringSubviewToFront:self.artist];
    [self.view bringSubviewToFront:self.controls];
    [self.view bringSubviewToFront:self.driveEqBtn];
    [self.view bringSubviewToFront:self.driveExitBtn];

  } else {
    // =========================================================================
    // HOME DASHBOARD (100% Matching dashboard.html / media_1794267643239_0594d895.jpg)
    // =========================================================================
    [self hideAllDriveWidgets:YES];
    [self hideAllHomeWidgets:NO];
    self.mapContainer.hidden = YES;
    self.carplayDock.hidden = YES;
    self.carplayMediaCard.hidden = YES;
    self.carplayTelemetryCard.hidden = YES;
    self.carplayAppGrid.hidden = YES;
    self.carplayMediaWidget.hidden = YES;
    self.carplayTelemetryWidget.hidden = YES;
    self.clock.hidden = YES;
    self.date.hidden = YES;

    CGFloat colH = 620, topY = 62;
    CGFloat leftW = 252, centerW = 472, rightW = 252;
    CGFloat leftX = 14, centerX = 276, rightX = 758;

    // Top Bar
    CGFloat barY = 12;
    self.heading.hidden = NO;
    self.heading.frame = CGRectMake(16, barY, 320, 22);
    self.heading.font = [UIFont boldSystemFontOfSize:16];
    self.heading.text = @"PRIUS TRD SPORTIVO";
    self.owner.hidden = NO;
    self.owner.frame = CGRectMake(16, barY + 22, 380, 16);
    self.owner.font = [UIFont boldSystemFontOfSize:10.5];
    self.owner.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.owner.text = @"LUXURY EV SMART COCKPIT \u2022 FULLSCREEN KIOSK READY";

    CGFloat curRx = w - 16;
    CGFloat pillH = 32;

    curRx -= 118;
    self.settingsPill.hidden = NO;
    self.settingsPill.frame = CGRectMake(curRx, barY + 4, 118, pillH);

    curRx -= 106;
    self.thaiVoicePill.hidden = NO;
    self.thaiVoicePill.frame = CGRectMake(curRx, barY + 4, 98, pillH);

    curRx -= 70;
    self.topClockLabel.hidden = NO;
    self.topClockLabel.frame = CGRectMake(curRx, barY + 4, 64, pillH);
    self.topClockLabel.text = [self.clockFormat stringFromDate:[NSDate date]];

    curRx -= 104;
    self.dayNightPill.hidden = NO;
    self.dayNightPill.frame = CGRectMake(curRx, barY + 4, 96, pillH);

    curRx -= 154;
    self.obdStatusPill.hidden = NO;
    self.obdStatusPill.frame = CGRectMake(curRx, barY + 4, 146, pillH);

    // 1. LEFT ZONE
    self.driveLeftCard.hidden = NO;
    self.driveLeftCard.frame = CGRectMake(leftX, topY, leftW, colH);
    self.driveLeftCard.layer.cornerRadius = 14;
    self.driveLeftCard.layer.borderWidth = 1.2;
    self.driveLeftCard.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.driveLeftCard.backgroundColor = [UIColor colorWithRed:.04 green:.06 blue:.08 alpha:.95];

    self.readyPill.hidden = NO;
    self.readyPill.frame = CGRectMake(leftX + (leftW - 140)/2, topY + 8, 140, 22);

    self.homeSpeedoDial.hidden = NO;
    self.gearBadge.hidden = YES;
    self.homeSpeedoDial.frame = CGRectMake(leftX + 6, topY + 32, leftW - 12, 108);

    CGFloat gw = (leftW - 20 - 4*5)/5;
    for (int i = 0; i < self.gearButtons.count; i++) {
      UIButton *gb = self.gearButtons[i];
      gb.hidden = NO;
      gb.frame = CGRectMake(leftX + 10 + i*(gw + 5), topY + 144, gw, 28);
    }

    self.hybridEcoBar.hidden = NO;
    self.hybridEcoBar.frame = CGRectMake(leftX + 10, topY + 178, leftW - 20, 26);

    CGFloat mw = (leftW - 20 - 2*6)/3;
    for (int i = 0; i < self.driveModePills.count; i++) {
      UIButton *mb = self.driveModePills[i];
      mb.hidden = NO;
      mb.frame = CGRectMake(leftX + 10 + i*(mw + 6), topY + 210, mw, 28);
    }

    self.homeAiEcoCard.hidden = NO;
    self.homeAiEcoCard.frame = CGRectMake(leftX + 10, topY + 246, leftW - 20, 175);

    self.homeThermalsCard.hidden = NO;
    self.homeThermalsCard.frame = CGRectMake(leftX + 10, topY + 428, leftW - 20, 180);

    // 2. CENTER ZONE
    self.energyFlowLabel.hidden = NO;
    self.energyFlowLabel.frame = CGRectMake(centerX + 8, topY + 6, centerW - 16, 32);
    self.energyFlowLabel.font = [UIFont boldSystemFontOfSize:14.0];
    self.energyFlowLabel.layer.cornerRadius = 6;
    self.energyFlowLabel.layer.borderWidth = 1;
    self.energyFlowLabel.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    self.energyFlowLabel.backgroundColor = [UIColor colorWithRed:.02 green:.06 blue:.08 alpha:.95];
    self.energyFlowLabel.text = @"🍃 โหมดไฟฟ้าล้วน EV (เพลาขับหน้า)  ⚡ ดึงไฟจากแบตไฮบริด";

    self.frontMotorBox.hidden = NO;
    self.frontMotorBox.frame = CGRectMake(centerX + 8, topY + 42, 188, 42);

    self.rearBatteryBox.hidden = NO;
    self.rearBatteryBox.frame = CGRectMake(centerX + centerW - 196, topY + 42, 188, 42);

    self.carImage.hidden = NO;
    self.carImage.frame = CGRectMake(centerX + (centerW - 320)/2, topY + 70, 320, 175);

    self.flowBeamLine.hidden = NO;
    self.flowBeamLine.frame = CGRectMake(centerX + 24, topY + 246, centerW - 48, 2);
    UIView *rDot = [self.flowBeamLine viewWithTag:831];
    if (rDot) rDot.frame = CGRectMake(centerW - 48 - 10, -4, 10, 10);

    self.compassLabel.hidden = NO;
    self.compassLabel.frame = CGRectMake(centerX + 8, topY + 252, centerW - 16, 24);
    self.compassLabel.font = [UIFont boldSystemFontOfSize:14.0];
    self.compassLabel.adjustsFontSizeToFitWidth = YES;
    self.compassLabel.minimumScaleFactor = 0.85;
    self.compassLabel.textColor = [UIColor colorWithRed:0 green:.90 blue:1 alpha:1];
    self.compassLabel.textAlignment = NSTextAlignmentCenter;
    self.compassLabel.text = @"⚡ กระแสไฟไฮบริด: ชาร์จไฟเข้าแบตเตอรี่ +14.2 kW (Regen)";

    self.carStatus.hidden = NO;
    self.carStatus.frame = CGRectMake(centerX + 8, topY + 280, centerW - 16, 32);
    self.carStatus.font = [UIFont boldSystemFontOfSize:14.0];
    self.carStatus.adjustsFontSizeToFitWidth = YES;
    self.carStatus.minimumScaleFactor = 0.85;
    self.carStatus.textColor = [UIColor whiteColor];
    self.carStatus.textAlignment = NSTextAlignmentCenter;
    self.carStatus.layer.cornerRadius = 6;
    self.carStatus.layer.borderWidth = 1;
    self.carStatus.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    self.carStatus.backgroundColor = [UIColor colorWithRed:.03 green:.06 blue:.09 alpha:.92];
    self.carStatus.text = @"🚪 ประตู 5 บาน: ปิดสนิท  •  🔒 เข็มขัดนิรภัย: ล็อคครบทุกจุด";

    // Multimedia Console
    CGFloat mTop = topY + 318;
    CGFloat mH = colH - 318; // 302px -> bottom is topY + 620, 100% aligned with left & right columns
    self.nowPanel.hidden = NO;
    self.nowPanel.frame = CGRectMake(centerX + 8, mTop, centerW - 16, mH);
    self.nowPanel.layer.cornerRadius = 14;
    self.nowPanel.layer.borderWidth = 1.2;
    self.nowPanel.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.nowPanel.backgroundColor = [UIColor colorWithRed:.03 green:.06 blue:.09 alpha:.95];

    self.artwork.hidden = NO;
    self.artwork.frame = CGRectMake(centerX + 22, mTop + 20, 148, 148);
    self.artwork.layer.cornerRadius = 12;
    self.artPlaceholder.frame = self.artwork.frame;
    self.artPlaceholder.hidden = (self.artwork.image != nil);

    UILabel *mHead = (UILabel *)[self.nowPanel viewWithTag:750];
    if (!mHead) {
      mHead = [[UILabel alloc] initWithFrame:CGRectMake(170, 18, centerW - 196, 22)];
      mHead.tag = 750;
      mHead.font = [UIFont boldSystemFontOfSize:13.0];
      mHead.adjustsFontSizeToFitWidth = YES;
      mHead.minimumScaleFactor = 0.85;
      mHead.textColor = [UIColor colorWithRed:0 green:.88 blue:1 alpha:1];
      mHead.text = @"🎵 เครื่องเสียงรถยนต์ • 11 เพลงในเครื่อง • JBL SOUND";
      [self.nowPanel addSubview:mHead];
    }
    mHead.frame = CGRectMake(170, 18, centerW - 196, 22);

    self.song.hidden = NO;
    self.song.frame = CGRectMake(centerX + 184, mTop + 48, centerW - 204, 34);
    self.song.font = [UIFont boldSystemFontOfSize:20.0];
    self.song.textColor = [UIColor whiteColor];

    self.artist.hidden = NO;
    self.artist.frame = CGRectMake(centerX + 184, mTop + 86, centerW - 204, 24);
    self.artist.font = [UIFont boldSystemFontOfSize:14.5];
    self.artist.textColor = [UIColor colorWithWhite:0.72 alpha:1];

    self.trackProgress.hidden = NO;
    self.trackProgress.frame = CGRectMake(centerX + 184, mTop + 128, centerW - 204, 4);

    self.trackTime.hidden = NO;
    self.trackTime.frame = CGRectMake(centerX + 184, mTop + 138, centerW - 204, 20);
    self.trackTime.font = [UIFont boldSystemFontOfSize:12.0];
    self.trackTime.textColor = [UIColor colorWithWhite:0.75 alpha:1];
    self.trackTime.textAlignment = NSTextAlignmentRight;

    CGFloat btnY = mTop + mH - 76; // 60px high buttons, 16px from card bottom -> bottoms align with side cards!
    CGFloat btnH = 60;
    self.controls.hidden = NO;
    self.controls.frame = CGRectMake(centerX + 22, btnY, 300, btnH);
    CGFloat cw = 290 / 3.0;
    for (int i = 0; i < 3; i++) {
      UIView *b = [self.controls viewWithTag:20 + i];
      b.frame = CGRectMake(i * (cw + 5), 0, cw, btnH);
      b.layer.cornerRadius = 10;
      if (i == 1) {
        b.backgroundColor = [UIColor colorWithRed:.0 green:.72 blue:.40 alpha:1];
        b.layer.borderColor = [UIColor colorWithRed:.2 green:.9 blue:.5 alpha:1].CGColor;
      } else {
        b.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
        b.layer.borderColor = [UIColor colorWithWhite:.24 alpha:1].CGColor;
      }
      [b viewWithTag:105].frame = CGRectMake((cw - 28)/2, (btnH - 28)/2, 28, 28);
    }

    self.driveEQ.hidden = NO;
    self.driveEQ.frame = CGRectMake(centerX + 330, btnY, centerW - 352, btnH);
    self.driveEQ.layer.cornerRadius = 10;
    self.driveEQ.layer.borderWidth = 1.2;
    self.driveEQ.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.5].CGColor;
    self.driveEQ.backgroundColor = [UIColor colorWithRed:.04 green:.12 blue:.18 alpha:1];
    [self.driveEQ setTitle:@"🎚️ JBL EQ" forState:UIControlStateNormal];
    [self.driveEQ setTitleColor:[UIColor colorWithRed:0 green:.9 blue:1 alpha:1] forState:UIControlStateNormal];
    self.driveEQ.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
    if(mHead) mHead.hidden = NO;

    // 3. RIGHT ZONE
    self.driveRightCard.hidden = NO;
    self.driveRightCard.frame = CGRectMake(rightX, topY, rightW, colH);
    self.driveRightCard.layer.cornerRadius = 14;
    self.driveRightCard.layer.borderWidth = 1.2;
    self.driveRightCard.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.driveRightCard.backgroundColor = [UIColor colorWithRed:.04 green:.06 blue:.08 alpha:.95];

    // Right Card 1: POWERTRAIN & HV • 7E3
    UIView *pCard = [self.view viewWithTag:701];
    if (!pCard) {
      pCard = [[UIView alloc] init];
      pCard.tag = 701;
      pCard.backgroundColor = [UIColor colorWithRed:.02 green:.06 blue:.08 alpha:.92];
      pCard.layer.cornerRadius = 10;
      pCard.layer.borderWidth = 1.0;
      pCard.layer.borderColor = [UIColor colorWithRed:0 green:.75 blue:.85 alpha:.35].CGColor;

      UILabel *pt = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, rightW - 36, 20)];
      pt.tag = 702;
      pt.font = [UIFont boldSystemFontOfSize:13.0];
      pt.textColor = [UIColor colorWithRed:0 green:.88 blue:1 alpha:1];
      pt.text = @"⚡ แบตเตอรี่ไฮบริด HV • 7E3";
      [pCard addSubview:pt];

      UILabel *pb = [[UILabel alloc] initWithFrame:CGRectMake(10, 28, rightW - 36, 62)];
      pb.tag = 703;
      pb.font = [UIFont boldSystemFontOfSize:13.5];
      pb.adjustsFontSizeToFitWidth = YES;
      pb.minimumScaleFactor = 0.85;
      pb.textColor = [UIColor whiteColor];
      pb.numberOfLines = 3;
      pb.text = @"ระดับไฟ (SOC): 64.5% (ปกติ)\nแรงดัน: 227.4 V • ชาร์จ +12.4 A\n14 บล็อก (28 โมดูล NiMH)";
      [pCard addSubview:pb];
      [self.view addSubview:pCard];
    }
    pCard.hidden = NO;
    pCard.frame = CGRectMake(rightX + 10, topY + 8, rightW - 20, 172);

    self.blockGraphView.hidden = NO;
    self.blockGraphView.frame = CGRectMake(rightX + 18, topY + 100, rightW - 36, 46);

    UILabel *deltaL = (UILabel *)[self.view viewWithTag:706];
    if (!deltaL) {
      deltaL = [[UILabel alloc] init];
      deltaL.tag = 706;
      deltaL.font = [UIFont boldSystemFontOfSize:12.0];
      deltaL.adjustsFontSizeToFitWidth = YES;
      deltaL.minimumScaleFactor = 0.85;
      deltaL.textColor = [UIColor colorWithRed:.35 green:.95 blue:.55 alpha:1];
      deltaL.text = @"ΔV: 0.02V (สมดุลดี) • 16.22–16.24V";
      [self.view addSubview:deltaL];
    }
    deltaL.hidden = NO;
    deltaL.frame = CGRectMake(rightX + 18, topY + 150, rightW - 36, 20);

    // Right Card 2: 3 Motor Rows
    UIView *mCard = [self.view viewWithTag:707];
    if (!mCard) {
      mCard = [[UIView alloc] init];
      mCard.tag = 707;
      mCard.backgroundColor = [UIColor colorWithRed:.02 green:.04 blue:.06 alpha:.95];
      mCard.layer.cornerRadius = 10;
      mCard.layer.borderWidth = 1.0;
      mCard.layer.borderColor = [UIColor colorWithWhite:.20 alpha:1].CGColor;

      UILabel *ml = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, rightW - 36, 174)];
      ml.tag = 708;
      ml.font = [UIFont boldSystemFontOfSize:13.5];
      ml.adjustsFontSizeToFitWidth = YES;
      ml.minimumScaleFactor = 0.85;
      ml.textColor = [UIColor whiteColor];
      ml.numberOfLines = 6;
      ml.text = @"⚙️ มอเตอร์ขับเคลื่อน MG2\n     1,420 RPM  •  กำลัง 18 kW\n⚡ มอเตอร์ปั่นไฟ MG1\n     980 RPM  •  ชาร์จ 8 kW\n🌡️ อุณหภูมิแบตไฮบริด (HV)\n     35.0 °C  •  พัดลมแบต: ปกติ";
      [mCard addSubview:ml];
      [self.view addSubview:mCard];
    }
    mCard.hidden = NO;
    mCard.frame = CGRectMake(rightX + 10, topY + 188, rightW - 20, 190);

    // Right Card 3: GPS Trip Computer & Range
    UIView *tCard = [self.view viewWithTag:711];
    if (!tCard) {
      tCard = [[UIView alloc] init];
      tCard.tag = 711;
      tCard.backgroundColor = [UIColor colorWithRed:.06 green:.03 blue:.04 alpha:.95];
      tCard.layer.cornerRadius = 10;
      tCard.layer.borderWidth = 1.0;
      tCard.layer.borderColor = [UIColor colorWithRed:1 green:.3 blue:.3 alpha:.40].CGColor;

      UILabel *tt = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, rightW - 36, 20)];
      tt.tag = 712;
      tt.font = [UIFont boldSystemFontOfSize:13.0];
      tt.adjustsFontSizeToFitWidth = YES;
      tt.minimumScaleFactor = 0.85;
      tt.textColor = [UIColor colorWithRed:1 green:.45 blue:.45 alpha:1];
      tt.text = @"📍 ข้อมูลการเดินทาง • TRIP";
      [tCard addSubview:tt];

      UILabel *tb = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, rightW - 36, 188)];
      tb.tag = 713;
      tb.font = [UIFont boldSystemFontOfSize:13.5];
      tb.adjustsFontSizeToFitWidth = YES;
      tb.minimumScaleFactor = 0.85;
      tb.textColor = [UIColor whiteColor];
      tb.numberOfLines = 7;
      tb.text = @"ระยะทางทริป: 18.42 km\nอัตราสิ้นเปลือง: 23.8 km/L\nค่าน้ำมันทริป: ฿ 29.80 (GSH95)\nวิ่งต่อได้อีก: ~520 km\nความเร็วเฉลี่ย: 48.5 km/h\nเวลาขับขี่: 00:24:18 ชม.\nความประหยัด: ดีเยี่ยม (A+)";
      [tCard addSubview:tb];
      [self.view addSubview:tCard];
    }
    tCard.hidden = NO;
    tCard.frame = CGRectMake(rightX + 10, topY + 386, rightW - 20, 226);

    // Bottom Navigation Bar
    self.navigation.hidden = self.focused;
    self.navigation.frame = CGRectMake(0, fullH - 78, w, 78);
    CGFloat nw = (w - 24) / self.navButtons.count;
    for (int i = 0; i < self.navButtons.count; i++) {
      UIButton *b = self.navButtons[i];
      BOOL active = (i == 0);
      b.frame = CGRectMake(12 + i * nw, 9, nw - 4, 60);
      b.backgroundColor = active ? [TRDAccent() colorWithAlphaComponent:.14] : [UIColor clearColor];
      [b viewWithTag:201].frame = CGRectMake(b.bounds.size.width/2 - 42, 16, 26, 26);
      UILabel *t = (UILabel *)[b viewWithTag:202];
      t.font = [UIFont boldSystemFontOfSize:12];
      t.frame = CGRectMake(b.bounds.size.width/2 - 14, 16, nw - 32, 28);
      t.textColor = active ? [UIColor whiteColor] : [UIColor lightGrayColor];
      [b viewWithTag:203].backgroundColor = TRDAccent();
      [b viewWithTag:203].hidden = !active;
      [b viewWithTag:203].frame = CGRectMake(14, 56, b.bounds.size.width - 28, 2);
    }

    // Bring subviews to front for Home Dashboard
    [self.view bringSubviewToFront:self.driveLeftCard];
    [self.view bringSubviewToFront:self.driveRightCard];
    [self.view bringSubviewToFront:self.heading];
    [self.view bringSubviewToFront:self.owner];
    [self.view bringSubviewToFront:self.topClockLabel];
    [self.view bringSubviewToFront:self.obdStatusPill];
    [self.view bringSubviewToFront:self.dayNightPill];
    [self.view bringSubviewToFront:self.thaiVoicePill];
    [self.view bringSubviewToFront:self.settingsPill];
    [self.view bringSubviewToFront:self.readyPill];
    [self.homeSpeedoDial setNeedsDisplay];
    [self.view bringSubviewToFront:self.homeSpeedoDial];
    for (UIButton *b in self.gearButtons) [self.view bringSubviewToFront:b];
    [self.view bringSubviewToFront:self.hybridEcoBar];
    for (UIButton *b in self.driveModePills) [self.view bringSubviewToFront:b];
    [self.view bringSubviewToFront:self.homeAiEcoCard];
    [self.view bringSubviewToFront:self.homeThermalsCard];
    [self.view bringSubviewToFront:self.energyFlowLabel];
    [self.view bringSubviewToFront:self.frontMotorBox];
    [self.view bringSubviewToFront:self.rearBatteryBox];
    [self.view bringSubviewToFront:self.carImage];
    [self.view bringSubviewToFront:self.flowBeamLine];
    [self.view bringSubviewToFront:self.compassLabel];
    [self.view bringSubviewToFront:self.carStatus];
    [self.view bringSubviewToFront:self.nowPanel];
    [self.view bringSubviewToFront:self.artwork];
    [self.view bringSubviewToFront:self.song];
    [self.view bringSubviewToFront:self.artist];
    [self.view bringSubviewToFront:self.trackProgress];
    [self.view bringSubviewToFront:self.trackTime];
    [self.view bringSubviewToFront:self.controls];
    [self.view bringSubviewToFront:self.driveEQ];
    if (pCard) [self.view bringSubviewToFront:pCard];
    [self.view bringSubviewToFront:self.blockGraphView];
    if (deltaL) [self.view bringSubviewToFront:deltaL];
    if (mCard) [self.view bringSubviewToFront:mCard];
    if (tCard) [self.view bringSubviewToFront:tCard];
    [self.view bringSubviewToFront:self.navigation];
  }

  if (self.tripSummaryCard) {
    self.tripSummaryCard.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.tripSummaryCard];
  }

  if (self.welcome) {
    self.welcome.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.welcome];
  }

  if (self.settingsSheet) {
    self.settingsSheet.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.settingsSheet];
  }
}

-(void)update{

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
 }else if(previousPower==UIDeviceBatteryStateUnplugged&&(currentPower==UIDeviceBatteryStateCharging||currentPower==UIDeviceBatteryStateFull)){
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  if(self.tripSummaryCard){
   [self.tripSummaryCard removeFromSuperview];
   self.tripSummaryCard=nil;
  }
  [self restoreDisplayBrightness];
  [self showWelcome];
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
  NSString *weatherStr=self.currentTemperature>0?[NSString stringWithFormat:@" • %.0f°C%@",self.currentTemperature,self.rainDetected?@" 🌧️":@" ☀️"]:@"";
  NSString *newNet=[NSString stringWithFormat:@"%@ • BT %@ • %@%@%@",net[@"SSID"]?:@"No Wi-Fi",bt?@"ON":@"OFF",battery,(power==UIDeviceBatteryStateCharging||power==UIDeviceBatteryStateFull)?@" +":@"",weatherStr];
  if(![self.network.text isEqualToString:newNet])self.network.text=newNet;
  self.statusWiFi=net[@"SSID"]?:@"NO NETWORK";
 if(self.carplayMode){
  NSString *cBat=[NSString stringWithFormat:@"⚡ %@",battery];if(![self.carplayBattery.text isEqualToString:cBat])self.carplayBattery.text=cBat;
  if(![self.carplayWifi.text isEqualToString:self.statusWiFi])self.carplayWifi.text=self.statusWiFi;
 }
 self.statusPower=level<0?@"UNKNOWN":[NSString stringWithFormat:@"%@ %.0f%%",(power==UIDeviceBatteryStateCharging)?@"CHG":(power==UIDeviceBatteryStateFull)?@"FULL":@"BAT",level*100];[self refreshCarStatus];
  if (self.carplayMediaWidget) {
    self.carplayMediaWidget.titleLabel.text = self.song.text.length ? self.song.text : @"Select Music";
    self.carplayMediaWidget.artistLabel.text = self.artist.text.length ? self.artist.text : @"audioNINJA / YouTube";
    self.carplayMediaWidget.artworkView.image = self.artwork.image;
    self.carplayMediaWidget.artPlaceholder.hidden = (self.artwork.image != nil);
    self.carplayMediaWidget.progressBar.progress = self.trackProgress.progress;
    self.carplayMediaWidget.timeCurLabel.text = self.trackTime.text;
  }
  [self refreshNowPlaying];
  [self refreshAudioRoute];
  [self refreshStatusStrip];
   [self checkBatteryHealthGuard];
 }
 [self applyMotionPolicy];[self refreshTrip];[self refreshMini];[self refreshBrakeStatus];
}
-(void)refreshNowPlaying{
 if(self.radioPlayer){
  self.sourceBadge.text=@"RADIO";
  AVPlayerItemStatus st=self.radioPlayer.currentItem.status;
  if(st==AVPlayerItemStatusReadyToPlay){
   if(self.radioPlayer.rate>0){
    self.song.text=self.currentRadioStation?:@"Live Radio Broadcast";
    self.artist.text=@"Live Radio Broadcast · Playing Live";
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
 NSInteger targetKind=13;
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
  if(lastCarConnected&&[UIDevice currentDevice].batteryState==UIDeviceBatteryStateUnplugged&&!self.tripSummaryCard){
   [self showTripSummary];
  }
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
 NSString *eqTitle=[NSString stringWithFormat:@"🎚️ EQ • %@",[pName uppercaseString]];
 if(![self.driveEQ.currentTitle isEqualToString:eqTitle]){
  [self.driveEQ setTitle:eqTitle forState:UIControlStateNormal];
  [self.driveEQ setTitleColor:[UIColor colorWithRed:0 green:.92 blue:1 alpha:1] forState:UIControlStateNormal];
 }
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
-(void)applyEQPreset:(NSString *)presetName{
 if(!presetName.length)return;
 NSString *clean=[presetName hasPrefix:@"TRD "]?[presetName substringFromIndex:4]:presetName;
 pid_t pid;
 const char *argv[]={"/usr/local/bin/trd-eqe",[clean UTF8String],NULL};
 posix_spawn(&pid,argv[0],NULL,NULL,(char *const *)argv,NULL);
 if(pid>0){int status=0;waitpid(pid,&status,0);}
 NSString *title=[NSString stringWithFormat:@"EQ • %@",[clean uppercaseString]];
 [self.driveEQ setTitle:title forState:UIControlStateNormal];
 [self.carplayEQBtn setTitle:title forState:UIControlStateNormal];
 NSString *srcPath=@"/var/mobile/codex-car/sound-source.plist";
 NSMutableDictionary *src=[NSMutableDictionary dictionaryWithContentsOfFile:srcPath]?:[NSMutableDictionary dictionary];
 src[@"preset"]=clean;
 [src writeToFile:srcPath atomically:YES];
}
-(void)openDriveEQ{
 NSDictionary *src=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/sound-source.plist"];
 NSString *cur=src[@"preset"]?:@"Rock";
 TRDSettingsMenu *m=[self settingsMenu:@"🎚️ EQUALIZER & SOUND (EQE)" message:[NSString stringWithFormat:@"Active Preset: TRD %@  •  Tap to apply",cur]];
 NSArray *presets=@[
  @{@"name":@"Rock",@"label":@"🎸 Rock (เบสหนัก แน่น สะใจ - สไตล์ TRD)"},
  @{@"name":@"Dance",@"label":@"💃 Dance / Bass Boost (EDM / Club กระหึ่ม)"},
  @{@"name":@"Pop",@"label":@"🎤 Pop / Vocal (เสียงร้องเด่น ใส ชัดเจน)"},
  @{@"name":@"Jazz",@"label":@"🎷 Jazz (เสียงนุ่มนวล มิติเปิดกว้าง)"},
  @{@"name":@"Classical",@"label":@"🎻 Classical (สมดุล คมชัด เวทีกว้าง)"},
  @{@"name":@"Flat",@"label":@"🎵 Flat (เสียงเดิม ไม่ปรุงแต่ง)"}
 ];
 for(NSDictionary *p in presets){
  NSString *name=p[@"name"],*label=p[@"label"];
  BOOL isCur=[cur caseInsensitiveCompare:name]==NSOrderedSame;
  NSString *rowTitle=isCur?[NSString stringWithFormat:@"✓ %@",label]:label;
  [m addAction:[TRDSettingAction actionWithTitle:rowTitle style:0 handler:^(TRDSettingAction *a){
   [self applyEQPreset:name];
  }]];
 }
 [m addAction:[TRDSettingAction actionWithTitle:@"⚙️ Automatic Sound Profiles..." style:0 handler:^(TRDSettingAction *a){
  [self soundProfileSettings];
 }]];
 [self presentSettingsMenu:m];
}
-(void)toggleSpeedLimit{
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
}
-(void)cycleDriveMode{NSInteger next=(TRDTheme+1)%3;[self setThemeNumber:@(next)];}
-(void)toggleDrive{if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}self.tripMode=NO;self.mapMode=NO;self.carplayMode=NO;self.carplayGridMode=NO;if(self.driveMode){self.autoDriveSuppressed=YES;self.movingSince=nil;}self.driveMode=!self.driveMode;self.musicMode=NO;self.focused=NO;self.returnTap.enabled=NO;[self.driveButton setTitle:self.driveMode?@"‹ DASHBOARD":@"DRIVE MODE" forState:UIControlStateNormal];[self.view setNeedsLayout];}
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
 [self updateEcoScoreForSpeed:kmh valid:valid];
 if(reliable&&kmh<=1){if(!self.stationarySince)self.stationarySince=[NSDate date];if(-[self.stationarySince timeIntervalSinceNow]>=10)self.autoDriveSuppressed=NO;}else self.stationarySince=nil;
 if([UIApplication sharedApplication].applicationState==UIApplicationStateActive&&!self.driveMode&&!self.musicMode&&!self.tripMode&&!self.mapMode&&!self.focused&&!self.autoDriveSuppressed&&reliable&&kmh>=10){if(!self.movingSince)self.movingSince=[NSDate date];if(-[self.movingSince timeIntervalSinceNow]>=5){self.movingSince=nil;[self toggleDrive];}}else self.movingSince=nil;
 if(self.driveMode){
  BOOL isStopped=(!valid)||(reliable&&kmh<=1.0);
  if(isStopped){
   if(!self.parkedSince)self.parkedSince=[NSDate date];
   NSTimeInterval parkedDuration=-[self.parkedSince timeIntervalSinceNow];
   NSTimeInterval limit=(!valid)?2.5:5.0;
   if(parkedDuration>=limit){
    self.parkedSince=nil;
    [self homePage];
    self.autoDriveSuppressed=NO;
   }
  }else{
   self.parkedSince=nil;
  }
 }else{
  self.parkedSince=nil;
 }
 self.gpsLive=valid;[self.driveCar setSpeed:self.driveMode&&!self.calmDrive&&valid?self.fix.speed*3.6:0];
 if(self.hybridEcoBar&&!self.hybridEcoBar.hidden){
  double curSpeed=valid?kmh:0;
  BOOL braking=(self.harshBrakeCount>0);
  BOOL accel=(self.harshAccelCount>0);
  [self.hybridEcoBar updateWithSpeed:curSpeed isBraking:braking isAccelerating:accel];
 }
 NSString *newSpeed=valid?[NSString stringWithFormat:@"%.0f",MAX(0,self.fix.speed*3.6)]:@"0";
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
 TRDSettingsMenu *m=[self settingsMenu:@"RADIO & MUSIC BROADCAST" message:@"Direct online English & Thai music broadcasts"];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Met 107 (Bangkok English Hits)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://rstream.mcot.net:8000/fm107" name:@"Met 107 (English Hits)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Capital UK (Top 40 Pop & Dance)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/CapitalUK" name:@"Capital UK (Top 40 Hits)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Heart UK (90s, 00s & Pop Variety)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/HeartLondon" name:@"Heart UK (Pop & Variety)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Smooth Radio UK (Relaxing Pop & Soul)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/SmoothUK" name:@"Smooth Radio UK (Relaxing Pop)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Radio X UK (British Indie & Rock)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/RadioXLondon" name:@"Radio X UK (British Indie & Rock)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Classic FM UK (Soundtracks & Classics)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/ClassicFM" name:@"Classic FM UK (Soundtracks & Classics)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 BBC World Service (Global English News)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://stream.live.vc.bbcmedia.co.uk/bbc_world_service" name:@"BBC World Service (Global News)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🎷 Jazz Radio Paris (Smooth Jazz & Lounge)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://jazz-wr01.ice.infomaniak.ch/jazz-wr01-128.mp3" name:@"Jazz Radio Paris (Smooth Jazz)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇹🇭 COOL Fahrenheit 93 (No. 1 Thai Pop)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://coolism-web.cdn.byteark.com/;stream/1" name:@"COOL Fahrenheit 93 (Thai Pop)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇹🇭 Green Wave 106.5 (Thai Easy Listening)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://atimehd.smartclick.co.th/greenwave/hls/greenwave.m3u8" name:@"Green Wave 106.5 (Easy Listening)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇹🇭 Flex 104.5 (Bangkok Modern Hits)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://streaming.flexconnect.net/voiceflex/voiceflex/playlist.m3u8" name:@"Flex 104.5 (Modern Hits)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇹🇭 ลูกทุ่งเน็ตเวิร์ก 90 (Lukthung Country)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://radio11.plathong.net:8896/;stream.mp3" name:@"ลูกทุ่งเน็ตเวิร์ก 90"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🚗 จส.100 (JS100 Traffic Report)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://sv4.hostpleng.com:8184/;stream.mp3" name:@"จส.100 (JS100 Traffic Report)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🚗 สวพ. FM 91 (Traffic Pro Alerts)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://www.fm91bkk.com:8900/;stream.mp3" name:@"สวพ. FM 91 (Traffic Pro Alerts)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"⏹️ Stop Radio (หยุดวิทยุ)" style:0 handler:^(TRDSettingAction *a){
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
-(void)batteryStateChanged:(NSNotification *)note{
 UIDeviceBatteryState state=[UIDevice currentDevice].batteryState;
 if(state==UIDeviceBatteryStateUnplugged){
  [self showTripSummary];
 }else if(state==UIDeviceBatteryStateCharging||state==UIDeviceBatteryStateFull){
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  if(self.tripSummaryCard){
   [self.tripSummaryCard removeFromSuperview];
   self.tripSummaryCard=nil;
  }
  self.trip=[TRDTrip new];
  [self saveTrip];
  [[TRDOBDClient sharedClient] resetTripFuel];
  [self restoreDisplayBrightness];
  [self showWelcome];
 }
}
typedef struct {
 double lat;
 double lon;
 int limit;
 const char *name;
} TRDSpeedCamera;

static const TRDSpeedCamera gTRDCameras[] = {
 {13.8820, 100.5820, 90, "Don Mueang Tollway"},
 {13.8450, 100.5620, 90, "Tollway Lak Si"},
 {13.6350, 100.7250, 110, "Burapha Withi km 14"},
 {13.6050, 100.8250, 110, "Burapha Withi km 26"},
 {13.5750, 100.9250, 110, "Burapha Withi km 38"},
 {13.7280, 100.7850, 120, "Motorway M7 km 15"},
 {13.6950, 100.9450, 120, "Motorway M7 km 35"},
 {13.6450, 101.0350, 120, "Motorway M7 km 50"},
 {13.9150, 100.6850, 120, "Motorway M9 East km 8"},
 {13.8150, 100.6950, 120, "Motorway M9 East km 25"},
 {13.7150, 100.7150, 120, "Motorway M9 East km 42"},
 {13.8250, 100.6250, 80, "Chalong Rat Ram Inthra"},
 {13.7650, 100.5950, 80, "Chalong Rat Rama 9"},
 {13.7550, 100.5550, 90, "Si Rat Asoke"},
 {13.8350, 100.5350, 90, "Si Rat Pracha Chuen"},
 {13.5850, 100.3850, 90, "Rama 2 km 15"},
 {13.5250, 100.2850, 90, "Rama 2 km 28"},
 {13.8450, 100.5650, 80, "Vibhavadi Kasetsart"},
 {13.8950, 100.5950, 80, "Vibhavadi Don Mueang"},
 {13.6550, 100.6850, 90, "Bang Na km 10"},
 {13.6250, 100.7850, 90, "Bang Na km 20"},
 {14.5850, 101.0850, 90, "Mitraparp Muak Lek"},
 {14.6250, 101.2450, 90, "Mitraparp Pak Chong"}
};
static const int gTRDCamerasCount = sizeof(gTRDCameras) / sizeof(TRDSpeedCamera);

static inline double TRDDistanceMeters(double lat1, double lon1, double lat2, double lon2){
 double dLat = (lat2 - lat1) * 111139.0;
 double dLon = (lon2 - lon1) * 111139.0 * cos(lat1 * 0.017453292519943295);
 return sqrt(dLat * dLat + dLon * dLon);
}

-(void)updateEcoScoreForSpeed:(double)curKmh valid:(BOOL)valid{
 if(!valid) return;
 if(!self.lastSpeedSampleTime){
  self.lastSpeedSampleTime = [NSDate date];
  self.lastSpeedSample = curKmh;
  if(self.ecoScore <= 0) self.ecoScore = 100;
  return;
 }
 NSTimeInterval dt = -[self.lastSpeedSampleTime timeIntervalSinceNow];
 if(dt >= 1.0){
  double deltaSpeed = (curKmh - self.lastSpeedSample) / dt;
  if(deltaSpeed > 13.0){
   self.harshAccelCount++;
  } else if(deltaSpeed < -15.0){
   self.harshBrakeCount++;
  }
  self.lastSpeedSample = curKmh;
  self.lastSpeedSampleTime = [NSDate date];
  NSInteger score = 100 - (self.harshAccelCount * 3) - (self.harshBrakeCount * 4);
  self.ecoScore = MAX(50, MIN(100, score));
 }
}

-(void)checkSpeedCamerasNearLocation:(CLLocation *)location{
 if(!location || location.horizontalAccuracy > 100 || location.speed * 3.6 < 45.0) return;
 NSUserDefaults *p = [NSUserDefaults standardUserDefaults];
 BOOL enabled = [p objectForKey:@"TRDSpeedCameraAlerts"] ? [p boolForKey:@"TRDSpeedCameraAlerts"] : YES;
 if(!enabled) return;
 double lat = location.coordinate.latitude;
 double lon = location.coordinate.longitude;
 for(int i=0; i<gTRDCamerasCount; i++){
  double dist = TRDDistanceMeters(lat, lon, gTRDCameras[i].lat, gTRDCameras[i].lon);
  if(dist <= 650.0){
   if(!self.lastCameraAlertDate || -[self.lastCameraAlertDate timeIntervalSinceNow] >= 90.0){
    self.lastCameraAlertDate = [NSDate date];
    AudioServicesPlaySystemSound(1057);
    int limit = gTRDCameras[i].limit;
    self.gpsStatus.text = [NSString stringWithFormat:@"📷 CAM %s (%.0fm · %d)", gTRDCameras[i].name, dist, limit];
    self.gpsStatus.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
    NSInteger voiceLang = [p integerForKey:@"TRDVoiceLanguage"];
    if(voiceLang != 2){
     NSString *phrase = (voiceLang == 1) ?
      [NSString stringWithFormat:@"แจ้งเตือน ระวังกล้องตรวจจับความเร็วข้างหน้า กำหนดความเร็ว %d กิโลเมตรต่อชั่วโมงครับ", limit] :
      [NSString stringWithFormat:@"Caution. Speed camera ahead. Speed limit is %d kilometers per hour.", limit];
     [self speakQuickAlert:phrase];
    }
    break;
   }
  }
 }
}

-(void)checkBatteryHealthGuard{
 NSUserDefaults *p = [NSUserDefaults standardUserDefaults];
 BOOL enabled = [p objectForKey:@"TRDBatteryHealthGuard"] ? [p boolForKey:@"TRDBatteryHealthGuard"] : YES;
 if(!enabled) return;
 float level = [UIDevice currentDevice].batteryLevel;
 UIDeviceBatteryState power = [UIDevice currentDevice].batteryState;
 if((power == UIDeviceBatteryStateCharging || power == UIDeviceBatteryStateFull) && level >= 0.80){
  if(!self.hasAlertedBattery80){
   self.hasAlertedBattery80 = YES;
   AudioServicesPlaySystemSound(1054);
   NSInteger voiceLang = [p integerForKey:@"TRDVoiceLanguage"];
    if(voiceLang != 2){
     NSString *msg = (voiceLang == 1) ?
      @"แบตเตอรี่ชาร์จถึง 80 เปอร์เซ็นต์แล้วครับ สามารถถอดสายชาร์จเพื่อถนอมอายุการใช้งานได้ครับ" :
      @"Battery is charged to 80 percent. Please unplug the charger to preserve battery health.";
     [self speakQuickAlert:msg];
    }
  }
 }else if(power == UIDeviceBatteryStateUnplugged){
  self.hasAlertedBattery80 = NO;
 }
}

-(void)speakQuickAlert:(NSString *)phrase{
 dispatch_async(dispatch_get_main_queue(), ^{
  @try {
   AVAudioSession *session = [AVAudioSession sharedInstance];
   [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
   [session setActive:YES error:nil];
   if(!gTRDWelcomeSynth) gTRDWelcomeSynth = [[AVSpeechSynthesizer alloc] init];
   if([gTRDWelcomeSynth isSpeaking]){
    [gTRDWelcomeSynth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
   }
   NSInteger voiceLang = [[NSUserDefaults standardUserDefaults] integerForKey:@"TRDVoiceLanguage"];
   NSString *langCode = (voiceLang == 1) ? @"th-TH" : @"en-US";
   float rate = (voiceLang == 1) ? 0.03f : 0.02f;
   TRDEnqueueCalmSpeech(gTRDWelcomeSynth, @[phrase], langCode, rate);
  } @catch(NSException *e){}
 });
}

-(void)navigateToNearestGasStation{
 NSURL *url = [NSURL URLWithString:@"comgooglemaps://?q=gas+station"];
 if(![[UIApplication sharedApplication] canOpenURL:url]){
  url = [NSURL URLWithString:@"http://maps.apple.com/?q=gas+station"];
 }
 [[UIApplication sharedApplication] openURL:url];
}

-(void)navigateToNearestRestArea{
 NSURL *url = [NSURL URLWithString:@"comgooglemaps://?q=rest+area+coffee"];
 if(![[UIApplication sharedApplication] canOpenURL:url]){
  url = [NSURL URLWithString:@"http://maps.apple.com/?q=rest+area+coffee"];
 }
 [[UIApplication sharedApplication] openURL:url];
}

-(void)openSpeedDial{
 NSUserDefaults *p = [NSUserDefaults standardUserDefaults];
 NSString *savedNum = [p stringForKey:@"TRDICENumber"];
 NSString *savedName = [p stringForKey:@"TRDICEName"] ?: @"Family / ICE";
 TRDSettingsMenu *m = [self settingsMenu:@"❤️ SPEED DIAL / CONTACT" message:savedNum.length ? [NSString stringWithFormat:@"Primary contact: %@ (%@)", savedName, savedNum] : @"No speed dial contact set yet."];
 if(savedNum.length){
  [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"📞 Call %@ (%@)", savedName, savedNum] style:0 handler:^(TRDSettingAction *a){
   [self callNumber:savedNum];
  }]];
 }
 [m addAction:[TRDSettingAction actionWithTitle:@"✏️ Set / Change Speed Dial Number" style:0 handler:^(TRDSettingAction *a){
  [self promptSetSpeedDial];
 }]];
 [self presentSettingsMenu:m];
}

-(void)promptSetSpeedDial{
 UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Set Speed Dial" message:@"Enter name and phone number for 1-tap calling" preferredStyle:UIAlertControllerStyleAlert];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"Contact Name (e.g. Home, Wife)"; }];
 [alert addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder = @"Phone Number"; t.keyboardType = UIKeyboardTypePhonePad; }];
 [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
 [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
  NSString *name = alert.textFields[0].text;
  NSString *num = alert.textFields[1].text;
  if(num.length){
   [[NSUserDefaults standardUserDefaults] setObject:name.length ? name : @"Speed Dial" forKey:@"TRDICEName"];
   [[NSUserDefaults standardUserDefaults] setObject:num forKey:@"TRDICENumber"];
   [[NSUserDefaults standardUserDefaults] synchronize];
  }
  [self openSpeedDial];
 }]];
 [self presentViewController:alert animated:YES completion:nil];
}

-(void)trackOdometerUpdates{
 NSUserDefaults *p=[NSUserDefaults standardUserDefaults];
 double curTripMeters=self.trip.meters;
 double lastTracked=[p doubleForKey:@"TRDLastTrackedTripMeters"];
 if(curTripMeters>lastTracked){
  double deltaKm=(curTripMeters-lastTracked)/1000.0;
  double total=[p doubleForKey:@"TRDTotalOdometer"]+deltaKm;
  [p setDouble:total forKey:@"TRDTotalOdometer"];
  [p setDouble:curTripMeters forKey:@"TRDLastTrackedTripMeters"];
 }else if(curTripMeters<lastTracked){
  [p setDouble:curTripMeters forKey:@"TRDLastTrackedTripMeters"];
 }
}

-(void)fetchWeatherForCoordinate:(CLLocationCoordinate2D)coord{
 if(fabs(coord.latitude)<0.001 && fabs(coord.longitude)<0.001)return;
 NSString *urlStr=[NSString stringWithFormat:@"https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=temperature_2m,weather_code,rain",coord.latitude,coord.longitude];
 NSURL *url=[NSURL URLWithString:urlStr];
 if(!url)return;
 NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:4.0];
 [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
  if(!data || error)return;
  NSDictionary *json=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  NSDictionary *cur=json[@"current"];
  if(cur){
   dispatch_async(dispatch_get_main_queue(), ^{
    self.currentTemperature=[cur[@"temperature_2m"] floatValue];
    self.currentRainMm=[cur[@"rain"] floatValue];
    self.currentWeatherCode=[cur[@"weather_code"] integerValue];
    self.rainDetected=(self.currentRainMm>0.0f || (self.currentWeatherCode>=51 && self.currentWeatherCode<=99));
   });
  }
 }] resume];
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{self.gpsUpdates++;self.gpsError=nil;self.fix=[locations lastObject];BOOL wasRunning=self.trip.running;for(CLLocation *fix in locations)[self.trip accept:fix now:[NSDate date]];if(wasRunning!=self.trip.running||!self.lastTripSavedAt||-[self.lastTripSavedAt timeIntervalSinceNow]>=5)[self saveTrip];double spd=(self.fix.speed>=0)?(self.fix.speed*3.6):0;[[TRDOBDClient sharedClient] integrateFallbackFuelForDistanceKm:(self.trip.meters/1000.0) speedKmh:spd dtSeconds:1.0];
 [self trackOdometerUpdates];
 [self checkSpeedCamerasNearLocation:self.fix];
 if(!self.hasFetchedWeather && self.fix && self.fix.horizontalAccuracy>0 && self.fix.horizontalAccuracy<=1000){
  self.hasFetchedWeather=YES;
  [self fetchWeatherForCoordinate:self.fix.coordinate];
 }if([UIApplication sharedApplication].applicationState!=UIApplicationStateBackground){[self refreshSpeed];[self refreshTrip];[self updateMapCar];}}
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{self.gpsError=error.description;self.fix=nil;[self.trip breakSegment];[self saveTrip];[self refreshSpeed];[self refreshTrip];}
-(BOOL)launchBundleApp:(NSString *)identifier{
 if(!identifier.length)return NO;
 Class wsClass=NSClassFromString(@"LSApplicationWorkspace");
 if(!wsClass){
  dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
  wsClass=NSClassFromString(@"LSApplicationWorkspace");
 }
 if(wsClass){
  id ws=[wsClass performSelector:@selector(defaultWorkspace)];
  if([ws respondsToSelector:@selector(openApplicationWithBundleID:)]){
   BOOL launched=(BOOL)[ws performSelector:@selector(openApplicationWithBundleID:) withObject:identifier];
   if(launched){
    [self refreshNowPlaying];
    return YES;
   }
  }
 }
 void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
 if(sbs){
  int (*launch)(CFStringRef, Boolean)=(int (*)(CFStringRef, Boolean))dlsym(sbs, "SBSLaunchApplicationWithIdentifier");
  if(launch&&launch((__bridge CFStringRef)identifier, false)==0){
   [self refreshNowPlaying];
   return YES;
  }
 }
 if([identifier isEqualToString:@"com.apple.Preferences"] && (&UIApplicationOpenSettingsURLString != NULL)){
  NSURL *settingsURL=[NSURL URLWithString:UIApplicationOpenSettingsURLString];
  UIApplication *app=[UIApplication sharedApplication];
  if(settingsURL && [app canOpenURL:settingsURL]){
   [app openURL:settingsURL];
   return YES;
  }
 }
 return NO;
}
-(void)send:(NSString *)identifier{
 if(!identifier.length||self.commandsPending>=4)return;self.commandsPending++;self.lastAction=identifier;
 if([identifier rangeOfString:@"."].location!=NSNotFound && ![identifier hasPrefix:@"libactivator."]){
  if([self launchBundleApp:identifier]){
   self.commandsPending--;
   return;
  }
 }
 static dispatch_queue_t queue;static dispatch_once_t once;dispatch_once(&once,^{queue=dispatch_queue_create("com.codex.cardash.commands",DISPATCH_QUEUE_SERIAL);});
 __weak Dashboard *weak=self;dispatch_async(queue,^{@autoreleasepool{char *args[]={(char *)"/usr/bin/activator",(char *)"send",(char *)identifier.UTF8String,NULL};BOOL ok=TRDRun(args[0],args,5,NULL,NULL);
 dispatch_async(dispatch_get_main_queue(),^{Dashboard *v=weak;if(!v)return;if(v.commandsPending)v.commandsPending--;if(!ok){v.notice=@"Command unavailable. Tap to retry.";v.noticeUntil=[NSDate dateWithTimeIntervalSinceNow:4];v.song.text=v.notice;}else [v refreshNowPlaying];});}});
}
-(UIWebView *)ensureMapWebView{if(!self.mapWebView){self.mapWebView=[[UIWebView alloc]initWithFrame:self.mapContainer.bounds];self.mapWebView.backgroundColor=[UIColor clearColor];self.mapWebView.opaque=NO;self.mapWebView.scalesPageToFit=YES;self.mapWebView.scrollView.bounces=NO;self.mapWebView.delegate=self;[self.mapContainer addSubview:self.mapWebView];}return self.mapWebView;}
-(void)openCarPlay{if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}notify_post("com.codex.trd.network.internet");self.tripMode=NO;self.mapMode=NO;self.musicMode=NO;self.driveMode=NO;self.focused=NO;self.carplayMode=YES;self.carplayGridMode=NO;[self ensureMapWebView];if(!self.mapWebView.request)[self loadMapHTML];[self.view setNeedsLayout];[self update];}
-(void)toggleCarPlayGrid{self.carplayGridMode=!self.carplayGridMode;[self.view setNeedsLayout];}
-(void)carplayTapMap{if(self.carplayGridMode){self.carplayGridMode=NO;[self.view setNeedsLayout];}else{[self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.recenter)window.recenter();"];}}
-(void)carplayTapMusic{if(self.carplayGridMode){self.carplayGridMode=NO;[self.view setNeedsLayout];}[self browseSource:@"com.legacymusic.app"];}
-(void)carplayGridMusic{self.carplayGridMode=NO;[self.view setNeedsLayout];[self browseSource:@"com.legacymusic.app"];}
-(void)carplayGridMap{self.carplayGridMode=NO;[self.view setNeedsLayout];}
-(void)carplayGridTrip{self.carplayMode=NO;self.carplayGridMode=NO;[self openTrip];}
-(void)carplayGridSettings{[self carSettings];}
-(void)handleEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture{if(gesture.state==UIGestureRecognizerStateBegan||gesture.state==UIGestureRecognizerStateRecognized){if(self.carplayMode)[self homePage];}}
-(void)openYouTubeSource{if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}Boolean (*pauseCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");if(!pauseCmd||!pauseCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];notify_post("com.codex.trd.network.internet");[self send:@"com.himais0giiiin.ytnine"];}
-(void)navigate:(UIButton *)button{switch(button.tag){case 60:[self homePage];break;case 66:[self openCarPlay];break;case 61:if(self.musicMode){[self showMusicSources:button];}else{[self openMusic];}break;case 62:[self openMap];break;case 63:[self openDriveEQ];break;case 64:[self screenOff];break;case 65:[self openCamera];break;case 67:notify_post("com.codex.trd.network.internet");[self send:@"com.himais0giiiin.ytnine"];break;case 68:[self carSettings];break;}}
-(void)homePage{if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}notify_post("com.codex.trd.network.internet");[self.settingsSheet dismiss];self.tripMode=NO;self.mapMode=NO;self.carplayMode=NO;self.carplayGridMode=NO;if(self.driveMode){self.autoDriveSuppressed=YES;self.movingSince=nil;}self.driveMode=NO;self.musicMode=NO;self.focused=NO;self.returnTap.enabled=NO;self.song.numberOfLines=1;self.heading.hidden=NO;self.owner.hidden=NO;self.modeButton.hidden=NO;self.driveButton.hidden=NO;self.nightButton.hidden=NO;self.statusStrip.hidden=NO;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];[self.view setNeedsLayout];}
-(void)openMusic{if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}notify_post("com.codex.trd.network.internet");self.tripMode=NO;self.mapMode=NO;self.musicMode=YES;self.driveMode=NO;self.focused=NO;self.returnTap.enabled=NO;[self.driveCar stop];[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];UIView *p=[self.view viewWithTag:701];if(p)p.hidden=YES;UIView *t=[self.view viewWithTag:711];if(t)t.hidden=YES;[self.view setNeedsLayout];self.ticks=0;[self update];}
-(void)openMap{if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}self.tripMode=NO;self.driveMode=NO;self.musicMode=NO;self.focused=NO;self.carplayMode=NO;self.carplayGridMode=NO;self.returnTap.enabled=NO;[self.driveCar stop];self.mapMode=YES;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];UIView *p=[self.view viewWithTag:701];if(p)p.hidden=YES;UIView *t=[self.view viewWithTag:711];if(t)t.hidden=YES;[self ensureMapWebView];[self.view setNeedsLayout];if(!self.mapWebView.request)[self loadMapHTML];else [self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.map){window.map.invalidateSize(); if(window.recenter)window.recenter(); }"];[self updateMapCar];}
-(void)syncMapAppearance:(BOOL)initial{if(!self.mapWebView)return;NSString *mode=self.nightMode?@"night":@"traffic";NSString *js=initial?[NSString stringWithFormat:@"if(window.setMode && !window.__trdInitialThemeDone){window.__trdInitialThemeDone=true;window.setMode('%@');}",mode]:[NSString stringWithFormat:@"if(window.setMode){window.setMode('%@');}",mode];[self.mapWebView stringByEvaluatingJavaScriptFromString:js];}
-(void)webViewDidFinishLoad:(UIWebView *)webView{if(webView==self.mapWebView)[self syncMapAppearance:YES];}
-(void)loadMapHTML{[self ensureMapWebView];NSString *path=@"/Applications/CarDash.app/map.html";if([[NSFileManager defaultManager]fileExistsAtPath:path])[self.mapWebView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]]];}
-(void)updateMapCar{if((!self.mapMode&&!self.carplayMode)||!self.mapWebView)return;if(!self.fix)return;CLLocationDegrees lat=self.fix.coordinate.latitude;CLLocationDegrees lng=self.fix.coordinate.longitude;double kmh=(self.fix.speed>=0)?(self.fix.speed*3.6):-1;BOOL courseValid=self.fix.course>=0&&self.fix.course<360&&kmh>=5&&self.fix.horizontalAccuracy>=0&&self.fix.horizontalAccuracy<=25&&fabs([self.fix.timestamp timeIntervalSinceNow])<5;double course=courseValid?self.fix.course:-1;NSString *js=[NSString stringWithFormat:@"if(window.updateCar){window.updateCar(%f,%f,%f,%f);}",lat,lng,course,kmh];[self.mapWebView stringByEvaluatingJavaScriptFromString:js];}
-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)type{NSString *scheme=request.URL.scheme;if([scheme isEqualToString:@"cardash-route"]){NSString *coords=[request.URL.resourceSpecifier stringByReplacingOccurrencesOfString:@"//" withString:@""];[self fetchRouteWithCoords:coords];return NO;}if([scheme isEqualToString:@"cardash-search"]){NSString *query=[[request.URL.resourceSpecifier stringByReplacingOccurrencesOfString:@"//" withString:@""]stringByRemovingPercentEncoding];[self fetchSearchWithQuery:query];return NO;}return YES;}
-(void)fetchRouteWithCoords:(NSString *)coords{NSString *urlStr=[NSString stringWithFormat:@"http://router.project-osrm.org/route/v1/driving/%@?overview=full&geometries=geojson&steps=true",coords];NSURL *url=[NSURL URLWithString:urlStr];if(!url)return;NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:url];[req setValue:@"CarDash/1.6 (iPad; iOS 9.3.6)" forHTTPHeaderField:@"User-Agent"];__weak Dashboard *weak=self;[[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData *data,NSURLResponse *resp,NSError *err){if(data&&!err){NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(json){dispatch_async(dispatch_get_main_queue(),^{[weak.mapWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(window.onNativeRoute){window.onNativeRoute(%@);}",json]];});}}}]resume];}
-(void)fetchSearchWithQuery:(NSString *)query{if(!query.length)return;NSString *encoded=[query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];CLLocationDegrees lat=self.fix?self.fix.coordinate.latitude:13.7563;CLLocationDegrees lng=self.fix?self.fix.coordinate.longitude:100.5018;NSString *viewbox=[NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f",lng-.4,lat+.4,lng+.4,lat-.4];NSString *urlStr=[NSString stringWithFormat:@"http://nominatim.openstreetmap.org/search?q=%@&format=json&countrycodes=th&limit=5&viewbox=%@",encoded,viewbox];NSURL *url=[NSURL URLWithString:urlStr];if(!url)return;NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:url];[req setValue:@"CarDash/1.6 (iPad; iOS 9.3.6; Prius)" forHTTPHeaderField:@"User-Agent"];__weak Dashboard *weak=self;[[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData *data,NSURLResponse *resp,NSError *err){if(data&&!err){NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(json){dispatch_async(dispatch_get_main_queue(),^{[weak.mapWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(window._onNominatimResult){window._onNominatimResult(%@);}",json]];});}}}]resume];}
-(void)openActiveSourceApp{NSDictionary *src=[NSDictionary dictionaryWithContentsOfFile:TRDSourcePath];NSString *bundle=src[@"bundle"]?:(self.youtubeSource?@"com.himais0giiiin.ytnine":@"com.legacymusic.app");if([bundle isEqualToString:@"com.legacymusic.app"])[self browseSource:bundle];else [self send:bundle];}
-(void)showMusicSources:(UIButton *)button{TRDSettingsMenu *menu=[self settingsMenu:@"AUDIO SOURCES" message:@"Select music, live radio or player"];[menu addAction:[TRDSettingAction actionWithTitle:@"📻 Live Radio & Music (วิทยุออนไลน์)" style:0 handler:^(TRDSettingAction *a){[self openRadioStationsMenu];}]];[menu addAction:[TRDSettingAction actionWithTitle:@"💾 Offline Music (เพลงที่โหลดไว้)" style:0 handler:^(TRDSettingAction *a){[self openOfflineMusicMenu];}]];[menu addAction:[TRDSettingAction actionWithTitle:@"🔍 Search Music (ค้นหา audioNINJA)" style:0 handler:^(TRDSettingAction *a){[self openSearchMusic];}]];[menu addAction:[TRDSettingAction actionWithTitle:@"🎵 audioNINJA Player" style:0 handler:^(TRDSettingAction *a){[self browseSource:@"com.legacymusic.app"];}]];[menu addAction:[TRDSettingAction actionWithTitle:@"▶️ YouTube" style:0 handler:^(TRDSettingAction *a){[self browseSource:@"com.himais0giiiin.ytnine"];}]];[self presentSettingsMenu:menu];}
-(void)openSearchMusic{[self browseSource:@"com.legacymusic.app"];}
-(void)openOfflineMusicMenu{
 NSString *libPath=@"/var/mobile/Documents/LegacyMusic/library.plist";
 NSArray *tracks=[NSArray arrayWithContentsOfFile:libPath];
 if(!tracks||tracks.count==0){
  TRDSettingsMenu *menu=[self settingsMenu:@"💾 OFFLINE MUSIC (0 เพลง)" message:@"No downloaded songs found in audioNINJA.\nUse audioNINJA to download songs."];
  [menu addAction:[TRDSettingAction actionWithTitle:@"🎵 Open audioNINJA" style:0 handler:^(TRDSettingAction *a){[self browseSource:@"com.legacymusic.app"];}]];
  [self presentSettingsMenu:menu];
  return;
 }
 NSString *msg=[NSString stringWithFormat:@"Choose a song to play (%lu เพลงที่ดาวน์โหลดไว้)",(unsigned long)tracks.count];
 TRDSettingsMenu *menu=[self settingsMenu:@"💾 OFFLINE MUSIC" message:msg];
 for(NSDictionary *track in tracks){
  NSString *title=track[@"title"]?:@"Untitled";
  NSString *artist=track[@"artist"]?:@"";
  NSString *vId=track[@"videoId"]?:@"";
  NSString *btnTitle=artist.length?[NSString stringWithFormat:@"▶️ %@ — %@",title,artist]:[NSString stringWithFormat:@"▶️ %@",title];
  [menu addAction:[TRDSettingAction actionWithTitle:btnTitle style:0 handler:^(TRDSettingAction *a){
   NSDictionary *req=@{@"id":vId,@"token":[[NSUUID UUID]UUIDString],@"expires":[NSDate dateWithTimeIntervalSinceNow:60.0],@"pending":@YES};
   [req writeToFile:@"/var/mobile/codex-car/download-play-request.plist" atomically:YES];
   [self browseSource:@"com.legacymusic.app"];
  }]];
 }
 [menu addAction:[TRDSettingAction actionWithTitle:@"🔍 Search / Download More..." style:0 handler:^(TRDSettingAction *a){[self openSearchMusic];}]];
 [self presentSettingsMenu:menu];
}
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
-(void)media:(UIButton *)button{if(self.radioPlayer){if(button.tag==21){if(self.radioPlayer.rate>0){[self.radioPlayer pause];self.song.text=[NSString stringWithFormat:@"[PAUSED] %@",self.currentRadioStation?:@"Radio"];self.artist.text=@"Tap Play button to resume";}else{Boolean (*pCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");if(!pCmd||!pCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];[self.radioPlayer play];self.song.text=self.currentRadioStation?:@"Radio";self.artist.text=@"Live Radio Broadcast · Playing Live";}return;}else if(button.tag==20||button.tag==22){[self openRadioStationsMenu];return;}}NSArray *ids=@[@"libactivator.ipod.previous-track",@"libactivator.ipod.toggle-playback",@"libactivator.ipod.next-track",@"com.r333d.eqe.app"];if(button.tag>=20&&button.tag<=23){Boolean (*command)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");if(button.tag==22){if(!command||!command(4,nil))[self send:ids[2]];}else if(button.tag==20){if(!command||!command(5,nil))[self send:ids[0]];}else if(button.tag==21){NSDictionary *source=[NSDictionary dictionaryWithContentsOfFile:TRDSourcePath];BOOL youtube=self.youtubeSource||[source[@"bundle"]isEqualToString:@"com.himais0giiiin.ytnine"];if(youtube)notify_post("com.codex.trd.youtube.toggle");else if(!command||!command(2,nil))[self send:ids[1]];}else{[self send:ids[button.tag-20]];}[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshNowPlaying) object:nil];[self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:.35];[self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:1.2];}}
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

-(void)openFuelPriceSettings{
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 NSString *msg=[NSString stringWithFormat:@"น้ำมัน: %@ (%.2f ฿/L)\nที่มา: %@ · %@",obd.selectedFuelTypeName?:@"แก๊สโซฮอล์ 95",obd.fuelPricePerLiter,obd.oilPriceSource?:@"ปตท.",obd.oilPriceDate?:@"วันนี้"];
 TRDSettingsMenu *m=[self settingsMenu:@"⛽ ราคาน้ำมันสดจากปั๊ม (LIVE PUMP PRICE)" message:msg];
 NSArray *names=@[@"แก๊สโซฮอล์ 95",@"แก๊สโซฮอล์ 91",@"แก๊สโซฮอล์ E20",@"พรีเมียม 95"];
 for(int i=0;i<4;i++){
  NSNumber *p=obd.cachedPrices[@(i)];
  double price=p?[p doubleValue]:0;
  NSString *check=(i==obd.selectedFuelTypeIndex)?@"✓  ":@"    ";
  NSString *title=[NSString stringWithFormat:@"%@⛽ %@ (%.2f ฿/L)",check,names[i],price];
  [m addAction:[TRDSettingAction actionWithTitle:title style:0 handler:^(TRDSettingAction *a){
   [obd selectFuelTypeIndex:i];
   [self openFuelPriceSettings];
  }]];
 }
 [m addAction:[TRDSettingAction actionWithTitle:@"🔄 ดึงราคาล่าสุดจากปั๊ม ปตท. ออนไลน์" style:0 handler:^(TRDSettingAction *a){
  [obd fetchLiveOilPrices];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   [self openFuelPriceSettings];
  });
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"➕ ปรับราคาเอง +0.50 ฿ (%.2f ฿)",obd.fuelPricePerLiter+0.5] style:0 handler:^(TRDSettingAction *a){
  [obd setCustomFuelPrice:obd.fuelPricePerLiter+0.5];
  [self openFuelPriceSettings];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"➖ ปรับราคาเอง -0.50 ฿ (%.2f ฿)",obd.fuelPricePerLiter-0.5] style:0 handler:^(TRDSettingAction *a){
  [obd setCustomFuelPrice:obd.fuelPricePerLiter-0.5];
  [self openFuelPriceSettings];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🔄 Reset Trip Fuel Counter" style:0 handler:^(TRDSettingAction *a){
  [obd resetTripFuel];
  [self openFuelPriceSettings];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"🔌 OBD2: %@",obd.connectionStatus] style:0 handler:^(TRDSettingAction *a){
  [obd startScanning];
  [self openFuelPriceSettings];
 }]];
 [self presentSettingsMenu:m];
}

-(void)refreshBrakeStatus{
  if(!self.driveMode) return;
 if(!self.brakeStatusCard)return;
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 UILabel *t=(UILabel *)[self.brakeStatusCard viewWithTag:501];
 UILabel *s=(UILabel *)[self.brakeStatusCard viewWithTag:502];
 if(obd.brakeFluidNormal && obd.absSystemNormal){
  self.brakeStatusCard.backgroundColor=[UIColor colorWithRed:.04 green:.08 blue:.05 alpha:.88];
  self.brakeStatusCard.layer.borderColor=[UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.45].CGColor;
  t.textColor=[UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];
  t.text=@"🛡️ BRAKE / ABS: NORMAL";
  s.textColor=[UIColor colorWithWhite:.75 alpha:1];
  s.text=[NSString stringWithFormat:@"FLUID: OK • PUMP: %.1f MPa", obd.brakeAccumulatorPressureMPa];
 }else{
  self.brakeStatusCard.backgroundColor=[UIColor colorWithRed:.18 green:.03 blue:.03 alpha:.92];
  self.brakeStatusCard.layer.borderColor=[UIColor colorWithRed:.95 green:.20 blue:.20 alpha:.85].CGColor;
  t.textColor=[UIColor colorWithRed:1.0 green:.30 blue:.30 alpha:1];
  t.text=@"⚠️ BRAKE / ABS: WARNING!";
  s.textColor=[UIColor colorWithRed:1.0 green:.85 blue:.85 alpha:1];
  s.text=[NSString stringWithFormat:@"%@ • PUMP: %.1f MPa", obd.brakeFluidNormal?@"ABS FAULT":@"LOW FLUID", obd.brakeAccumulatorPressureMPa];
 }
}

-(void)openBrakeDiagnosticsMenu{
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 NSString *fluidStr = obd.brakeFluidNormal ? @"✅ ปกติ (ระดับเต็ม MAX)" : @"⚠️ ต่ำกว่าเกณฑ์ (LOW FLUID)";
 NSString *absStr = obd.absSystemNormal ? @"✅ ระบบทำงานปกติ (Ready)" : @"⚠️ ตรวจพบข้อผิดพลาด (DTC)";
 NSString *pumpStr = [NSString stringWithFormat:@"%.1f MPa (เกณฑ์ปกติ 15-20 MPa)", obd.brakeAccumulatorPressureMPa];
 NSString *regenStr = [NSString stringWithFormat:@"%.1f kW (Regenerative Charging)", obd.regenBrakingPowerKW];
 
 NSString *msg=[NSString stringWithFormat:@"ระบบเบรกไฮบริด Toyota Prius ECB:\n• ระดับน้ำมันเบรก: %@\n• ระบบเบรก ABS/VSC: %@\n• แรงดันปั๊มเบรกไฮดรอลิก: %@\n• ชาร์จไฟกลับขณะเบรก: %@",
               fluidStr, absStr, pumpStr, regenStr];
 TRDSettingsMenu *m=[self settingsMenu:@"🛡️ การวินิจฉัยระบบเบรกและ ABS (PRIUS TRD)" message:msg];
 
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"🧪 ทดสอบสลับสถานะเตือนน้ำมันเบรก (%@)", obd.brakeFluidNormal ? @"ปกติ" : @"จำลองเตือน LOW"] style:0 handler:^(TRDSettingAction *a){
  [obd toggleTestBrakeWarning];
  [self refreshBrakeStatus];
  [self openBrakeDiagnosticsMenu];
 }]];
 
 NSString *gearTitle = [NSString stringWithFormat:@"🚗 ทดสอบสลับเกียร์ถอยหลัง R [กล้อง+เสียง] (%@)", obd.isReverseGear ? @"กำลังถอย R" : @"เกียร์ P/D"];
 [m addAction:[TRDSettingAction actionWithTitle:gearTitle style:0 handler:^(TRDSettingAction *a){
  [obd toggleTestReverseGear];
  [self openBrakeDiagnosticsMenu];
 }]];
 
 [m addAction:[TRDSettingAction actionWithTitle:@"🔄 เคลียร์ค่าและรีเซ็ตสถานะปกติ" style:0 handler:^(TRDSettingAction *a){
  if(!obd.brakeFluidNormal)[obd toggleTestBrakeWarning];
  if(obd.isReverseGear)[obd toggleTestReverseGear];
  [self refreshBrakeStatus];
  [self openBrakeDiagnosticsMenu];
 }]];
 
 [m addAction:[TRDSettingAction actionWithTitle:@"🔙 ปิดหน้าต่าง" style:0 handler:^(TRDSettingAction *a){
  [self.settingsSheet dismiss];
 }]];
 
 [self presentSettingsMenu:m];
}

-(void)obdGearChanged:(NSNotification *)note{
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 if(obd.isReverseGear){
  [self handleReverseEngaged];
 }else{
  [self handleReverseDisengaged];
 }
}

-(void)handleReverseEngaged{
 if(self.isReverseActive)return;
 self.isReverseActive=YES;
 notify_post("com.codex.trd.network.camera");
 if(![self launchBundleApp:@"com.codex.h109viewer"]){
  [self launchBundleApp:@"com.apple.camera"];
 }
 if(self.radioPlayer){
  self.radioPlayer.volume=0.5f;
 }
 [self.reverseBeepTimer invalidate];
 self.reverseBeepTimer=[NSTimer scheduledTimerWithTimeInterval:0.85 target:self selector:@selector(playReverseBeep) userInfo:nil repeats:YES];
 [self playReverseBeep];
}

-(void)handleReverseDisengaged{
 if(!self.isReverseActive)return;
 self.isReverseActive=NO;
 [self.reverseBeepTimer invalidate];
 self.reverseBeepTimer=nil;
 if(self.radioPlayer){
  self.radioPlayer.volume=1.0f;
 }
 notify_post("com.codex.trd.network.internet");
 [self homePage];
}

-(void)playReverseBeep{
 AudioServicesPlaySystemSound(1057);
}

-(void)obdDataUpdated:(NSNotification *)note{
 [self refreshBrakeStatus];
 [self refreshHybridStatus];
}

-(void)refreshHybridStatus{
  if(!self.driveMode) return;
 if(!self.hybridSocCard)return;
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 UILabel *t=(UILabel *)[self.hybridSocCard viewWithTag:601];
 UILabel *s=(UILabel *)[self.hybridSocCard viewWithTag:602];
 CGFloat soc=obd.hybridBatterySOC;
 if(soc<40.0){
  self.hybridSocCard.backgroundColor=[UIColor colorWithRed:.12 green:.08 blue:.02 alpha:.88];
  self.hybridSocCard.layer.borderColor=[UIColor colorWithRed:.95 green:.65 blue:.15 alpha:.55].CGColor;
  t.textColor=[UIColor colorWithRed:1.0 green:.75 blue:.20 alpha:1];
  t.text=[NSString stringWithFormat:@"🔋 HYBRID SOC: %.0f%% (LOW / CHG)", soc];
 }else{
  self.hybridSocCard.backgroundColor=[UIColor colorWithRed:.02 green:.07 blue:.06 alpha:.88];
  self.hybridSocCard.layer.borderColor=[UIColor colorWithRed:.0 green:.78 blue:.55 alpha:.45].CGColor;
  t.textColor=[UIColor colorWithRed:.0 green:.92 blue:.70 alpha:1];
  t.text=[NSString stringWithFormat:@"🔋 HYBRID SOC: %.0f%% (EV READY)", soc];
 }
 s.textColor=[UIColor colorWithWhite:.75 alpha:1];
 s.text=[NSString stringWithFormat:@"ECT: %.0f°C • INV: %.0f°C • 12V: %.1fV", obd.coolantTempC, obd.inverterTempC, obd.auxBatteryVoltage];
}

-(void)openHybridDiagnosticsMenu{
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 NSString *socHealth=(obd.hybridBatterySOC>=40 && obd.hybridBatterySOC<=80)?@"✅ เกณฑ์ปกติ (Optimal 40-80%)":@"⚠️ นอกช่วงเหมาะสม";
 NSString *invStr=[NSString stringWithFormat:@"%.1f °C (เกณฑ์ปกติ 30-55 °C)", obd.inverterTempC];
 NSString *ectStr=[NSString stringWithFormat:@"%.1f °C (เกณฑ์ทำงาน 85-95 °C)", obd.coolantTempC];
 NSString *auxStr=[NSString stringWithFormat:@"%.1f V (ระบบไฟเสริม 12V)", obd.auxBatteryVoltage];
 NSString *evStr=[NSString stringWithFormat:@"%.0f%% (สัดส่วนขับขี่ด้วยไฟฟ้า)", obd.tripEVDistancePercent];
 NSString *msg=[NSString stringWithFormat:@"ระบบไฮบริด Toyota Prius Gen 3 (ZVW30):\n• แบตเตอรี่ไฮบริด (SOC): %.0f%% (%@)\n• ความร้อนอินเวอร์เตอร์: %@\n• ความร้อนเครื่องยนต์ (ECT): %@\n• แบตเตอรี่เสริม 12V: %@\n• อัตราขับด้วยไฟฟ้า (EV): %@",
               obd.hybridBatterySOC, socHealth, invStr, ectStr, auxStr, evStr];
 TRDSettingsMenu *m=[self settingsMenu:@"🔋 ข้อมูลระบบไฮบริด (PRIUS HYBRID TELEMETRY)" message:msg];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"🔄 สลับจำลองระดับแบตเตอรี่ (ปัจจุบัน %.0f%%)", obd.hybridBatterySOC] style:0 handler:^(TRDSettingAction *a){
  [self toggleTestHybridSOC];
  [self refreshHybridStatus];
  [self openHybridDiagnosticsMenu];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"⚡ สลับจำลองมาตรวัด CHG (เบรก) / ECO / PWR" style:0 handler:^(TRDSettingAction *a){
  if(self.hybridEcoBar){
   static int simStep=0;
   simStep=(simStep+1)%3;
   if(simStep==0)[self.hybridEcoBar updateWithSpeed:30 isBraking:YES isAccelerating:NO];
   else if(simStep==1)[self.hybridEcoBar updateWithSpeed:55 isBraking:NO isAccelerating:NO];
   else [self.hybridEcoBar updateWithSpeed:95 isBraking:NO isAccelerating:YES];
  }
  [self openHybridDiagnosticsMenu];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🔙 ปิดหน้าต่าง" style:0 handler:^(TRDSettingAction *a){
  [self.settingsSheet dismiss];
 }]];
 [self presentSettingsMenu:m];
}

-(void)toggleTestHybridSOC{
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 static int socIndex=0;
 socIndex=(socIndex+1)%3;
 CGFloat testValues[3]={78.0, 36.0, 62.0};
 [obd simulateHybridBatterySOC:testValues[socIndex]];
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
 if([url.host isEqualToString:@"camera"])[v openCamera];
 if([url.host isEqualToString:@"map"])[v openMap];
 if([url.host isEqualToString:@"settings"])[v carSettings];
 if([url.host isEqualToString:@"phone"])[v openPhoneMenu];
  if([url.host isEqualToString:@"offline"])[v openOfflineMusicMenu];
  if([url.host isEqualToString:@"search"])[v openSearchMusic];
  if([url.host isEqualToString:@"sources"])[v showMusicSources:nil];
  if([url.host isEqualToString:@"drive"])[v toggleDrive];
  if([url.host isEqualToString:@"sound"])[v openDriveEQ];
  if([url.host isEqualToString:@"night"])[v toggleNight];
  if([url.host isEqualToString:@"mode"])[v cycleDriveMode];
 if([url.host isEqualToString:@"radio"]){
  NSString *p=url.path;
  if([p isEqualToString:@"/0"])[v playRadio:@"http://rstream.mcot.net:8000/fm107" name:@"Met 107 (English Hits)"];
  else if([p isEqualToString:@"/1"])[v playRadio:@"https://media-ssl.musicradio.com/CapitalUK" name:@"Capital UK (Top 40 Hits)"];
  else if([p isEqualToString:@"/2"])[v playRadio:@"https://media-ssl.musicradio.com/HeartLondon" name:@"Heart UK (Pop & Variety)"];
  else if([p isEqualToString:@"/3"])[v playRadio:@"https://media-ssl.musicradio.com/SmoothUK" name:@"Smooth Radio UK (Relaxing Pop)"];
  else if([p isEqualToString:@"/4"])[v playRadio:@"http://jazz-wr01.ice.infomaniak.ch/jazz-wr01-128.mp3" name:@"Jazz Radio Paris (Smooth Jazz)"];
  else if([p isEqualToString:@"/5"])[v playRadio:@"https://coolism-web.cdn.byteark.com/;stream/1" name:@"COOL Fahrenheit 93 (Thai Pop)"];
  else if([p isEqualToString:@"/6"])[v playRadio:@"http://sv4.hostpleng.com:8184/;stream.mp3" name:@"จส.100 (JS100 Traffic Report)"];
  else if([p isEqualToString:@"/stop"])[v playRadio:nil name:nil];
  else [v openRadioStationsMenu];
 }
 if([url.host isEqualToString:@"tripsummary"])[v showTripSummary];
 if([url.host isEqualToString:@"fuel"])[v openFuelPriceSettings];
 if([url.host isEqualToString:@"obd"])[v openFuelPriceSettings];
 if([url.host isEqualToString:@"brake"])[v openBrakeDiagnosticsMenu];
 if([url.host isEqualToString:@"hybrid"])[v openHybridDiagnosticsMenu];
 if([url.host isEqualToString:@"reverse"]){ [[TRDOBDClient sharedClient] toggleTestReverseGear]; }
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
-(void)applicationDidBecomeActive:(UIApplication *)app{notify_post("com.codex.trd.network.internet");[[TRDOBDClient sharedClient] fetchLiveOilPrices];Dashboard *v=(Dashboard *)self.window.rootViewController;[v cancelBrowseReturn];[v applyDisplaySchedule];[v restoreDisplayBrightness];BOOL welcomePending=[[NSFileManager defaultManager]fileExistsAtPath:@"/var/mobile/codex-car/welcome-pending"];if(welcomePending){[[NSFileManager defaultManager]removeItemAtPath:@"/var/mobile/codex-car/welcome-pending" error:nil];[v showWelcome];}[v.view setNeedsLayout];[v refreshNowPlaying];[v performSelector:@selector(restoreDisplayBrightness) withObject:nil afterDelay:.6];[v.audioBars start];[UIApplication sharedApplication].idleTimerDisabled=YES;if(!v.timer)v.timer=[NSTimer scheduledTimerWithTimeInterval:1 target:v selector:@selector(update) userInfo:nil repeats:YES];v.timer.tolerance=.1;[v startGPS];[v update];[v captureLifecycle];}

@end
static void TRDCrashHandler(NSException *exception) {
    NSString *crashReport = [NSString stringWithFormat:@"NAME: %@\nREASON: %@\nSTACK:\n%@", exception.name, exception.reason, [[exception callStackSymbols] componentsJoinedByString:@"\n"]];
    [crashReport writeToFile:@"/var/mobile/cardash_crash.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

int main(int argc,char **argv){
    @autoreleasepool{
        NSSetUncaughtExceptionHandler(&TRDCrashHandler);
        return UIApplicationMain(argc,argv,nil,NSStringFromClass([CarApp class]));
    }
}
