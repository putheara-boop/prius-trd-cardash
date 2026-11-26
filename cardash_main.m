#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Speech/Speech.h>
#import "TRDAutoplayModel.h"
#import "TRDDriveStatus.h"
#import "TRDOBDClient.m"
#import "TRDWelcomeGate.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <QuartzCore/QuartzCore.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CommonCrypto/CommonDigest.h>
#include <spawn.h>
#include <sys/wait.h>
#include <dlfcn.h>
#import <objc/message.h>
#include "MeterShared.h"
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <notify.h>
#include <mach/mach_time.h>
extern char **environ;
static inline void trd_run_bg(const char *cmd){
 if(!cmd)return;
 pid_t pid=0;
 char *argv[]={(char *)"/bin/sh",(char *)"-c",(char *)cmd,NULL};
 posix_spawn(&pid,"/bin/sh",NULL,NULL,argv,environ);
}
static NSString *TRDDailyTripLogPath(void){
 NSString *dir=@"/var/mobile/codex-car";
 NSFileManager *fm=[NSFileManager defaultManager];
 if([fm isWritableFileAtPath:dir] || [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]){
  return [dir stringByAppendingPathComponent:@"trip-daily-history.plist"];
 }
 NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
 return [docs stringByAppendingPathComponent:@"trip-daily-history.plist"];
}
static NSDateFormatter *TRDGregorianDayFormatter(NSString *fmt){
 NSDateFormatter *df=[[NSDateFormatter alloc]init];
 df.calendar=[[NSCalendar alloc]initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
 df.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
 df.dateFormat=fmt;
 return df;
}
static NSString *TRDDateKeyForDate(NSDate *dt){
 return [TRDGregorianDayFormatter(@"yyyy-MM-dd") stringFromDate:dt?:[NSDate date]] ?: @"1970-01-01";
}
static NSString *TRDFormatThaiDayLabel(NSString *ymd){
 NSDate *d=[TRDGregorianDayFormatter(@"yyyy-MM-dd") dateFromString:ymd];
 if(!d) return ymd ?: @"";
 NSDateFormatter *df=[[NSDateFormatter alloc]init];
 df.locale=[NSLocale localeWithLocaleIdentifier:@"th_TH"];
 df.calendar=[[NSCalendar alloc]initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
 df.dateFormat=@"EEE d MMM yy";
 return [df stringFromDate:d] ?: ymd;
}
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
@interface TRDCarLightBeamsView : UIView
@end

static UIImage *TRDAutoVectorIcon(NSInteger kind, CGFloat ptSize, UIColor *tint) {
  static NSMutableDictionary *cache = nil;
  if (!cache) cache = [NSMutableDictionary dictionary];
  CGFloat r = 1, g = 1, b = 1, a = 1;
  [tint getRed:&r green:&g blue:&b alpha:&a];
  NSString *key = [NSString stringWithFormat:@"%ld_%.0f_%.2f_%.2f_%.2f", (long)kind, ptSize, r, g, b];
  UIImage *hit = cache[key];
  if (hit) return hit;

  UIGraphicsBeginImageContextWithOptions(CGSizeMake(ptSize, ptSize), NO, 0.0);
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  [tint setStroke];
  [tint setFill];
  CGFloat s = ptSize;
  CGContextSetLineWidth(ctx, MAX(1.3, s * 0.095));
  CGContextSetLineCap(ctx, kCGLineCapRound);
  CGContextSetLineJoin(ctx, kCGLineJoinRound);

  if (kind == 1) {
    // OBD-II J1962 16-pin trapezoidal connector
    UIBezierPath *trap = [UIBezierPath bezierPath];
    [trap moveToPoint:CGPointMake(s * 0.14, s * 0.28)];
    [trap addLineToPoint:CGPointMake(s * 0.86, s * 0.28)];
    [trap addLineToPoint:CGPointMake(s * 0.76, s * 0.74)];
    [trap addLineToPoint:CGPointMake(s * 0.24, s * 0.74)];
    [trap closePath];
    trap.lineWidth = MAX(1.3, s * 0.09);
    [trap stroke];
    for (int col = 0; col < 4; col++) {
      CGFloat px = s * (0.31 + col * 0.125);
      CGContextFillEllipseInRect(ctx, CGRectMake(px - s * 0.035, s * 0.40, s * 0.07, s * 0.07));
      CGContextFillEllipseInRect(ctx, CGRectMake(px - s * 0.035, s * 0.56, s * 0.07, s * 0.07));
    }
  } else if (kind == 2) {
    // Automotive Rear-View Camera + wide-angle guideline cone
    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(s * 0.10, s * 0.26, s * 0.46, s * 0.48) cornerRadius:s * 0.10];
    body.lineWidth = MAX(1.3, s * 0.095);
    [body stroke];
    CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.25, s * 0.42, s * 0.16, s * 0.16));
    UIBezierPath *fov = [UIBezierPath bezierPath];
    [fov moveToPoint:CGPointMake(s * 0.60, s * 0.42)];
    [fov addLineToPoint:CGPointMake(s * 0.90, s * 0.26)];
    [fov addLineToPoint:CGPointMake(s * 0.90, s * 0.74)];
    [fov addLineToPoint:CGPointMake(s * 0.60, s * 0.58)];
    [fov closePath];
    fov.lineWidth = MAX(1.2, s * 0.085);
    [fov stroke];
  } else if (kind == 3) {
    // Automotive Front Car Door silhouette (angled A-pillar, mirror nub, inner window cutout, flush car handle)
    CGFloat lw = MAX(1.2, s * 0.085);
    UIBezierPath *door = [UIBezierPath bezierPath];
    [door moveToPoint:CGPointMake(s * 0.20, s * 0.84)];
    [door addLineToPoint:CGPointMake(s * 0.14, s * 0.60)];
    [door addLineToPoint:CGPointMake(s * 0.18, s * 0.44)];
    [door addLineToPoint:CGPointMake(s * 0.44, s * 0.16)];
    [door addLineToPoint:CGPointMake(s * 0.84, s * 0.16)];
    [door addLineToPoint:CGPointMake(s * 0.84, s * 0.84)];
    [door closePath];
    door.lineWidth = lw;
    [door stroke];

    // Window pane cutout (angled auto glass)
    UIBezierPath *win = [UIBezierPath bezierPath];
    [win moveToPoint:CGPointMake(s * 0.27, s * 0.44)];
    [win addLineToPoint:CGPointMake(s * 0.47, s * 0.24)];
    [win addLineToPoint:CGPointMake(s * 0.76, s * 0.24)];
    [win addLineToPoint:CGPointMake(s * 0.76, s * 0.44)];
    [win closePath];
    win.lineWidth = MAX(1.0, s * 0.068);
    [win stroke];

    // Wing mirror nub on A-pillar + flush car door handle
    UIBezierPath *mirror = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(s * 0.07, s * 0.38, s * 0.12, s * 0.09) cornerRadius:s * 0.03];
    [mirror fill];
    CGContextSetLineWidth(ctx, MAX(1.5, s * 0.105));
    CGContextMoveToPoint(ctx, s * 0.56, s * 0.56);
    CGContextAddLineToPoint(ctx, s * 0.74, s * 0.56);
    CGContextStrokePath(ctx);
  } else if (kind == 4) {
    // Minimalist Fuel Pump glyph
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(s * 0.20, s * 0.20, s * 0.44, s * 0.62) cornerRadius:s * 0.07];
    p.lineWidth = MAX(1.3, s * 0.09);
    [p stroke];
    UIRectFill(CGRectMake(s * 0.28, s * 0.28, s * 0.28, s * 0.16));
    CGContextMoveToPoint(ctx, s * 0.64, s * 0.34);
    CGContextAddLineToPoint(ctx, s * 0.78, s * 0.44);
    CGContextAddLineToPoint(ctx, s * 0.78, s * 0.72);
    CGContextStrokePath(ctx);
  } else {
    // Coolant Temp Gauge glyph
    CGContextMoveToPoint(ctx, s * 0.50, s * 0.18);
    CGContextAddLineToPoint(ctx, s * 0.50, s * 0.62);
    CGContextStrokePath(ctx);
    CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.35, s * 0.58, s * 0.30, s * 0.30));
    CGContextMoveToPoint(ctx, s * 0.62, s * 0.30);
    CGContextAddLineToPoint(ctx, s * 0.78, s * 0.30);
    CGContextMoveToPoint(ctx, s * 0.62, s * 0.45);
    CGContextAddLineToPoint(ctx, s * 0.74, s * 0.45);
    CGContextStrokePath(ctx);
  }
  UIImage *img = [UIGraphicsGetImageFromCurrentImageContext() imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
  UIGraphicsEndImageContext();
  if (img) cache[key] = img;
  return img;
}
static NSString *TRDFuelShortCode(NSInteger idx) {
  switch (idx) {
    case 1: return @"GSH91";
    case 2: return @"E20";
    case 3: return @"PREM95";
    default: return @"GSH95";
  }
}

@interface TRDMarqueeLabel : UILabel
@property (nonatomic, strong) UILabel *innerLabel;
@property (nonatomic, copy) NSString *lastAnimKey;
- (void)refreshMarquee;
@end

@implementation TRDMarqueeLabel
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.clipsToBounds = YES;
    self.innerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.innerLabel.backgroundColor = [UIColor clearColor];
    self.innerLabel.numberOfLines = 1;
    self.innerLabel.lineBreakMode = NSLineBreakByClipping;
    [self addSubview:self.innerLabel];
  }
  return self;
}
- (void)drawTextInRect:(CGRect)rect {
  // Rendered via GPU-animated innerLabel to avoid double-drawing
}
- (void)setText:(NSString *)text {
  [super setText:text];
  self.innerLabel.text = text;
  [self refreshMarquee];
}
- (void)setFont:(UIFont *)font {
  [super setFont:font];
  self.innerLabel.font = font;
  [self refreshMarquee];
}
- (void)setTextColor:(UIColor *)textColor {
  [super setTextColor:textColor];
  self.innerLabel.textColor = textColor;
}
- (void)setTextAlignment:(NSTextAlignment)textAlignment {
  [super setTextAlignment:textAlignment];
  self.innerLabel.textAlignment = textAlignment;
}
- (void)setHidden:(BOOL)hidden {
  BOOL wasHidden = self.hidden;
  [super setHidden:hidden];
  if (wasHidden && !hidden) {
    self.lastAnimKey = nil;
    [self refreshMarquee];
  } else if (hidden) {
    [self.innerLabel.layer removeAnimationForKey:@"trdMarquee"];
    self.lastAnimKey = nil;
  }
}
- (void)layoutSubviews {
  [super layoutSubviews];
  [self refreshMarquee];
}
- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    self.lastAnimKey = nil;
    [self refreshMarquee];
  }
}
- (void)refreshMarquee {
  CGFloat boxW = self.bounds.size.width;
  CGFloat boxH = self.bounds.size.height;
  if (boxW <= 4.0 || boxH <= 4.0 || self.hidden) return;
  NSString *txt = self.text ?: @"";
  UIFont *f = self.font ?: [UIFont boldSystemFontOfSize:17.0];
  CGSize sz = [txt sizeWithAttributes:@{NSFontAttributeName: f}];
  CGFloat textW = ceil(sz.width) + 2.0;
  NSString *key = [NSString stringWithFormat:@"%@_%.0f_%.1f", txt, boxW, f.pointSize];
  if ([self.lastAnimKey isEqualToString:key] &&
      (textW <= boxW || [self.innerLabel.layer animationForKey:@"trdMarquee"] != nil)) {
    return;
  }
  self.lastAnimKey = key;
  [self.innerLabel.layer removeAnimationForKey:@"trdMarquee"];
  if (textW <= boxW) {
    self.innerLabel.frame = CGRectMake(0, 0, boxW, boxH);
    return;
  }
  self.innerLabel.frame = CGRectMake(0, 0, textW, boxH);
  CGFloat travel = textW - boxW + 16.0;
  CFTimeInterval scrollSec = MAX(2.8, MIN(12.0, travel / 38.0));
  CFTimeInterval pauseSec = 1.4;
  CFTimeInterval total = pauseSec + scrollSec + pauseSec + 1.2;
  CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
  anim.values = @[@(0.0), @(0.0), @(-travel), @(-travel), @(0.0)];
  anim.keyTimes = @[
    @(0.0),
    @(pauseSec / total),
    @((pauseSec + scrollSec) / total),
    @((pauseSec + scrollSec + pauseSec) / total),
    @(1.0)
  ];
  anim.duration = total;
  anim.repeatCount = HUGE_VALF;
  anim.removedOnCompletion = NO;
  anim.timingFunctions = @[
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
    [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
  ];
  [self.innerLabel.layer addAnimation:anim forKey:@"trdMarquee"];
}
@end
@interface TRDDoorDiagramView : UIControl
@property (nonatomic, assign) BOOL doorsLive;
@property (nonatomic, assign) BOOL flOpen;
@property (nonatomic, assign) BOOL frOpen;
@property (nonatomic, assign) BOOL rlOpen;
@property (nonatomic, assign) BOOL rrOpen;
@property (nonatomic, assign) BOOL trunkOpen;
@end
static NSString *TRDOpenDoorsSummary(BOOL live, BOOL fl, BOOL fr, BOOL rl, BOOL rr, BOOL trunk) {
  if (!live) return nil;
  NSMutableArray *parts = [NSMutableArray array];
  if (fr) [parts addObject:@"หน้าขวา (คนขับ)"];
  if (fl) [parts addObject:@"หน้าซ้าย"];
  if (rr) [parts addObject:@"หลังขวา"];
  if (rl) [parts addObject:@"หลังซ้าย"];
  if (trunk) [parts addObject:@"ฝาท้าย"];
  if (parts.count == 0) return @"";
  return [parts componentsJoinedByString:@", "];
}
@implementation TRDDoorDiagramView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.contentMode = UIViewContentModeRedraw;
    self.clipsToBounds = YES;
  }
  return self;
}
- (void)drawDoorLeafFrom:(CGPoint)hinge length:(CGFloat)len swingX:(CGFloat)swingX thickness:(CGFloat)lw open:(BOOL)isOpen live:(BOOL)live ctx:(CGContextRef)ctx {
  UIColor *col = !live ? [UIColor colorWithWhite:0.42 alpha:0.65]
    : (isOpen ? [UIColor colorWithRed:1.0 green:0.24 blue:0.24 alpha:1.0]
              : [UIColor colorWithRed:0.20 green:0.90 blue:0.48 alpha:0.85]);
  CGContextSaveGState(ctx);
  if (isOpen) {
    CGContextSetShadowWithColor(ctx, CGSizeZero, 6.0, [UIColor colorWithRed:1.0 green:0.20 blue:0.20 alpha:0.95].CGColor);
  }
  CGContextSetStrokeColorWithColor(ctx, col.CGColor);
  CGContextSetLineWidth(ctx, isOpen ? lw + 0.8 : lw);
  CGContextSetLineCap(ctx, kCGLineCapRound);
  CGContextMoveToPoint(ctx, hinge.x, hinge.y);
  CGContextAddLineToPoint(ctx, hinge.x + (isOpen ? swingX : 0.0), hinge.y + len);
  CGContextStrokePath(ctx);
  if (isOpen) {
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.22 blue:0.22 alpha:0.25].CGColor);
    CGContextMoveToPoint(ctx, hinge.x, hinge.y);
    CGContextAddLineToPoint(ctx, hinge.x + swingX, hinge.y + len);
    CGContextAddLineToPoint(ctx, hinge.x, hinge.y + len);
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);
  }
  CGContextRestoreGState(ctx);
}
- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  if (w <= 0 || h <= 0) return;

  BOOL anyOpen = self.doorsLive && (self.flOpen || self.frOpen || self.rlOpen || self.rrOpen || self.trunkOpen);

  UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, 1, 1) cornerRadius:12];
  UIColor *fillCol = anyOpen
    ? [UIColor colorWithRed:0.16 green:0.03 blue:0.04 alpha:0.95]
    : [UIColor colorWithRed:0.03 green:0.06 blue:0.11 alpha:0.92];
  [fillCol setFill];
  [bg fill];
  UIColor *borderCol = anyOpen
    ? [UIColor colorWithRed:1.0 green:0.28 blue:0.28 alpha:0.95]
    : (self.doorsLive ? [UIColor colorWithRed:0.16 green:0.86 blue:0.55 alpha:0.55]
                      : [UIColor colorWithRed:0.0 green:0.80 blue:1.0 alpha:0.30]);
  [borderCol setStroke];
  bg.lineWidth = anyOpen ? 1.8 : 1.1;
  [bg stroke];

  // Top title
  NSMutableParagraphStyle *hdrPs = [[NSMutableParagraphStyle alloc] init];
  hdrPs.alignment = NSTextAlignmentCenter;
  NSDictionary *hdrAttr = @{
    NSFontAttributeName: [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold],
    NSForegroundColorAttributeName: anyOpen ? [UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1] : [UIColor colorWithRed:0.55 green:0.90 blue:1.0 alpha:0.9],
    NSParagraphStyleAttributeName: hdrPs
  };
  [@"5-DOOR (RHD)" drawInRect:CGRectMake(4, 5, w - 8, 13) withAttributes:hdrAttr];

  // Contoured top-down Prius body silhouette scaled proportionally to widget bounds
  CGFloat carW = MAX(38.0, w * 0.37);
  CGFloat carH = MAX(72.0, h * 0.55);
  CGFloat carX = (w - carW) * 0.5;
  CGFloat carY = 21.0 + MAX(0.0, (h - 46.0 - carH) * 0.42);
  CGRect bodyR = CGRectMake(carX, carY, carW, carH);

  // Subtle side mirrors
  [[UIColor colorWithWhite:0.52 alpha:0.8] setFill];
  [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(carX - 4.5, carY + carH * 0.25, 4.5, 6.0) cornerRadius:1.5] fill];
  [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(carX + carW, carY + carH * 0.25, 4.5, 6.0) cornerRadius:1.5] fill];

  UIBezierPath *carBody = [UIBezierPath bezierPathWithRoundedRect:bodyR cornerRadius:carW * 0.30];
  [[UIColor colorWithRed:0.09 green:0.14 blue:0.21 alpha:0.96] setFill];
  [carBody fill];
  [[UIColor colorWithWhite:0.62 alpha:0.80] setStroke];
  carBody.lineWidth = 1.4;
  [carBody stroke];

  // Windshield + panoramic roof + rear glass
  UIBezierPath *wind = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(carX + 5.5, carY + carH * 0.20, carW - 11.0, carH * 0.20) cornerRadius:4.0];
  [[UIColor colorWithRed:0.05 green:0.28 blue:0.42 alpha:0.92] setFill];
  [wind fill];
  UIBezierPath *roof = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(carX + 7.5, carY + carH * 0.43, carW - 15.0, carH * 0.18) cornerRadius:3.0];
  [[UIColor colorWithRed:0.12 green:0.19 blue:0.27 alpha:0.90] setFill];
  [roof fill];
  UIBezierPath *rearGlass = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(carX + 6.5, carY + carH * 0.65, carW - 13.0, carH * 0.18) cornerRadius:3.5];
  [[UIColor colorWithRed:0.04 green:0.22 blue:0.34 alpha:0.88] setFill];
  [rearGlass fill];

  // Clean RHD cockpit steering bar inside front-right dash (minimalist top-down look)
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.35 green:0.88 blue:1.0 alpha:0.65].CGColor);
  CGContextSetLineWidth(ctx, 2.0);
  CGContextMoveToPoint(ctx, carX + carW - 15.0, carY + carH * 0.35);
  CGContextAddLineToPoint(ctx, carX + carW - 8.5, carY + carH * 0.35);
  CGContextStrokePath(ctx);

  // Side L / R labels
  NSDictionary *lrAttr = @{
    NSFontAttributeName: [UIFont systemFontOfSize:9.0 weight:UIFontWeightBold],
    NSForegroundColorAttributeName: [UIColor colorWithWhite:0.62 alpha:0.9]
  };
  [@"L" drawAtPoint:CGPointMake(6, carY + carH * 0.42) withAttributes:lrAttr];
  [@"R" drawAtPoint:CGPointMake(w - 13, carY + carH * 0.42) withAttributes:lrAttr];

  // Draw 4 side doors (FL/FR top, RL/RR lower)
  CGFloat fLen = carH * 0.27, rLen = carH * 0.25;
  [self drawDoorLeafFrom:CGPointMake(carX, carY + carH * 0.24) length:fLen swingX:-13.0 thickness:3.2 open:self.flOpen live:self.doorsLive ctx:ctx];
  [self drawDoorLeafFrom:CGPointMake(carX + carW, carY + carH * 0.24) length:fLen swingX:13.0 thickness:3.2 open:self.frOpen live:self.doorsLive ctx:ctx];
  [self drawDoorLeafFrom:CGPointMake(carX, carY + carH * 0.54) length:rLen swingX:-12.0 thickness:3.2 open:self.rlOpen live:self.doorsLive ctx:ctx];
  [self drawDoorLeafFrom:CGPointMake(carX + carW, carY + carH * 0.54) length:rLen swingX:12.0 thickness:3.2 open:self.rrOpen live:self.doorsLive ctx:ctx];

  // Rear Trunk / Hatch bar
  UIColor *tCol = !self.doorsLive ? [UIColor colorWithWhite:0.42 alpha:0.65]
    : (self.trunkOpen ? [UIColor colorWithRed:1.0 green:0.24 blue:0.24 alpha:1.0]
                      : [UIColor colorWithRed:0.20 green:0.90 blue:0.48 alpha:0.85]);
  CGContextSaveGState(ctx);
  if (self.trunkOpen) {
    CGContextSetShadowWithColor(ctx, CGSizeZero, 6.0, [UIColor colorWithRed:1.0 green:0.20 blue:0.20 alpha:0.95].CGColor);
  }
  CGContextSetStrokeColorWithColor(ctx, tCol.CGColor);
  CGContextSetLineWidth(ctx, self.trunkOpen ? 4.0 : 3.0);
  CGContextSetLineCap(ctx, kCGLineCapRound);
  CGFloat hatchY = self.trunkOpen ? (carY + carH + 7.0) : (carY + carH);
  CGContextMoveToPoint(ctx, carX + 8, hatchY);
  CGContextAddLineToPoint(ctx, carX + carW - 8, hatchY);
  CGContextStrokePath(ctx);
  CGContextRestoreGState(ctx);

  // Bottom status line
  NSString *summary = TRDOpenDoorsSummary(self.doorsLive, self.flOpen, self.frOpen, self.rlOpen, self.rrOpen, self.trunkOpen);
  NSString *statusText = !self.doorsLive ? @"รอ CAN 0x620" : (summary.length > 0 ? [NSString stringWithFormat:@"เปิด: %@", summary] : @"ปิดครบ 5 บาน");
  NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
  ps.alignment = NSTextAlignmentCenter;
  ps.lineBreakMode = NSLineBreakByTruncatingTail;
  NSDictionary *stAttr = @{
    NSFontAttributeName: [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold],
    NSForegroundColorAttributeName: !self.doorsLive ? [UIColor colorWithWhite:0.65 alpha:1]
      : (anyOpen ? [UIColor colorWithRed:1.0 green:0.42 blue:0.42 alpha:1]
                 : [UIColor colorWithRed:0.25 green:0.96 blue:0.54 alpha:1]),
    NSParagraphStyleAttributeName: ps
  };
  [statusText drawInRect:CGRectMake(4, h - 22, w - 8, 18) withAttributes:stAttr];
}
@end
@implementation TRDCarLightBeamsView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.clipsToBounds = NO;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}
- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  if (w <= 0 || h <= 0) return;

  // 1. Sleek OEM LED Headlight projection (extends cleanly forward without bulky vertical flare)
  CGPoint lamp = CGPointMake(w * 0.056, h * 0.45);
  CGFloat beamTipX = -w * 0.32;
  CGMutablePathRef cone = CGPathCreateMutable();
  CGPathMoveToPoint(cone, NULL, lamp.x, lamp.y - 2.0);
  CGPathAddLineToPoint(cone, NULL, beamTipX, h * 0.33);
  CGPathAddLineToPoint(cone, NULL, beamTipX, h * 0.59);
  CGPathAddLineToPoint(cone, NULL, lamp.x, lamp.y + 3.0);
  CGPathCloseSubpath(cone);

  CGContextSaveGState(ctx);
  CGContextAddPath(ctx, cone);
  CGContextClip(ctx);
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGFloat colors[] = {
    0.88, 0.99, 1.0, 0.68,
    0.25, 0.90, 1.0, 0.28,
    0.0,  0.72, 1.0, 0.0
  };
  CGFloat locs[] = {0.0, 0.48, 1.0};
  CGGradientRef grad = CGGradientCreateWithColorComponents(cs, colors, locs, 3);
  CGContextDrawLinearGradient(ctx, grad, lamp, CGPointMake(beamTipX, lamp.y + 5), 0);
  CGGradientRelease(grad);
  CGColorSpaceRelease(cs);
  CGContextRestoreGState(ctx);
  CGPathRelease(cone);

  // Subtle headlight lens glint matching housing contour
  [[UIColor colorWithRed:0.75 green:0.97 blue:1.0 alpha:0.65] setFill];
  [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(lamp.x - 5, lamp.y - 2.5, 10, 5) cornerRadius:2.5] fill];
  [[UIColor whiteColor] setFill];
  [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(lamp.x - 3, lamp.y - 1.5, 6, 3) cornerRadius:1.5] fill];

  // Subtle Rear LED Taillight bar
  CGPoint tail = CGPointMake(w * 0.916, h * 0.39);
  [[UIColor colorWithRed:1.0 green:0.12 blue:0.20 alpha:0.55] setFill];
  [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(tail.x - 5, tail.y - 7, 9, 14) cornerRadius:3.5] fill];
  [[UIColor colorWithRed:1.0 green:0.55 blue:0.55 alpha:0.85] setFill];
  [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(tail.x - 2.5, tail.y - 4.5, 4.5, 9) cornerRadius:2.0] fill];
}
@end

@interface TRDEnergyFlowXRayView : UIView
@property (nonatomic, assign) CGFloat kmh;
@property (nonatomic, assign) CGFloat wheelAngle;
@property (nonatomic, assign) CGFloat flowPhase;
@property (nonatomic, assign) NSInteger engineRPM;
@property (nonatomic, assign) double hvCurrent;
@property (nonatomic, assign) double hvSOC;
@property (nonatomic, assign) BOOL isBraking;
@end

@implementation TRDEnergyFlowXRayView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.clipsToBounds = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.hvSOC = 60.0;
  }
  return self;
}
- (void)drawFlowSegmentFrom:(CGPoint)p1 to:(CGPoint)p2 color:(UIColor *)col active:(BOOL)active ctx:(CGContextRef)ctx {
  CGFloat dx = p2.x - p1.x, dy = p2.y - p1.y;
  CGFloat len = hypot(dx, dy);
  if (len < 6.0) return;
  CGFloat ux = dx / len, uy = dy / len;
  CGFloat px = -uy, py = ux;

  CGContextSetLineCap(ctx, kCGLineCapRound);
  if (active) {
    // Sleek OEM Toyota/Lexus fiber-optic conduit + 2 smooth gliding chevrons
    CGContextSetStrokeColorWithColor(ctx, [col colorWithAlphaComponent:0.22].CGColor);
    CGContextSetLineWidth(ctx, 4.6);
    CGContextMoveToPoint(ctx, p1.x, p1.y);
    CGContextAddLineToPoint(ctx, p2.x, p2.y);
    CGContextStrokePath(ctx);

    CGContextSetStrokeColorWithColor(ctx, [col colorWithAlphaComponent:0.86].CGColor);
    CGContextSetLineWidth(ctx, 1.8);
    CGContextMoveToPoint(ctx, p1.x, p1.y);
    CGContextAddLineToPoint(ctx, p2.x, p2.y);
    CGContextStrokePath(ctx);

    // Two smooth animated chevrons gliding from p1 -> p2 with soft edge fade
    CGFloat phase = self.flowPhase - floor(self.flowPhase);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    for (int i = 0; i < 2; i++) {
      CGFloat t = fmod(phase + i * 0.5, 1.0);
      CGFloat fade = sin(t * M_PI);
      if (fade < 0.12) continue;
      CGFloat cx = p1.x + dx * t;
      CGFloat cy = p1.y + dy * t;
      CGFloat head = 4.0, wing = 3.2;
      CGContextSetStrokeColorWithColor(ctx, [[UIColor whiteColor] colorWithAlphaComponent:0.92 * fade].CGColor);
      CGContextSetLineWidth(ctx, 1.7);
      CGContextMoveToPoint(ctx, cx - ux * head + px * wing, cy - uy * head + py * wing);
      CGContextAddLineToPoint(ctx, cx + ux * (head * 0.55), cy + uy * (head * 0.55));
      CGContextAddLineToPoint(ctx, cx - ux * head - px * wing, cy - uy * head - py * wing);
      CGContextStrokePath(ctx);
    }
  } else {
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.38 green:0.54 blue:0.68 alpha:0.22].CGColor);
    CGContextSetLineWidth(ctx, 1.4);
    CGContextMoveToPoint(ctx, p1.x, p1.y);
    CGContextAddLineToPoint(ctx, p2.x, p2.y);
    CGContextStrokePath(ctx);
  }
}
- (void)drawSpinningRimAt:(CGPoint)c r:(CGFloat)r angle:(CGFloat)ang glow:(UIColor *)glow ctx:(CGContextRef)ctx {
  (void)c; (void)r; (void)ang; (void)glow; (void)ctx;
}
- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  if (w <= 0 || h <= 0) return;

  // Compute exact AspectFit rect of TRDRealPrius.png (1440x497) inside self.bounds
  CGFloat imgAspect = 1440.0 / 497.0;
  CGFloat boxAspect = w / h;
  CGRect imgR;
  if (boxAspect > imgAspect) {
    CGFloat fitH = h;
    CGFloat fitW = fitH * imgAspect;
    imgR = CGRectMake((w - fitW) * 0.5, 0, fitW, fitH);
  } else {
    CGFloat fitW = w;
    CGFloat fitH = fitW / imgAspect;
    imgR = CGRectMake(0, (h - fitH) * 0.5, fitW, fitH);
  }

  // Exact compact body-aligned positions (ZERO overlap with front/rear alloy wheels or cabin silhouette)
  CGRect iceR = CGRectMake(imgR.origin.x + imgR.size.width * 0.130, imgR.origin.y + imgR.size.height * 0.370, 27, 16);
  CGPoint iceOut = CGPointMake(CGRectGetMaxX(iceR) + 2, CGRectGetMidY(iceR) + 1.5);

  CGRect pcuR = CGRectMake(imgR.origin.x + imgR.size.width * 0.440, imgR.origin.y + imgR.size.height * 0.555, 26, 16);
  CGPoint pcuLeft  = CGPointMake(CGRectGetMinX(pcuR) - 2, CGRectGetMidY(pcuR));
  CGPoint pcuRight = CGPointMake(CGRectGetMaxX(pcuR) + 2, CGRectGetMidY(pcuR));

  CGFloat batW = MAX(35.0, imgR.size.width * 0.122);
  CGFloat batH = MAX(15.0, imgR.size.height * 0.165);
  CGRect batR = CGRectMake(imgR.origin.x + imgR.size.width * 0.738, imgR.origin.y + imgR.size.height * 0.245, batW, batH);
  CGPoint batIn = CGPointMake(CGRectGetMinX(batR) - 2, CGRectGetMidY(batR) + 1.5);

  // Authentic Toyota THS-II Prius Gen 3 energy flow logic
  BOOL iceActive = (self.engineRPM > 100);
  BOOL regen = (self.kmh > 1.0 && (self.isBraking || (self.hvCurrent < -1.0 && self.engineRPM < 1350)));
  BOOL hvCharging = (self.hvCurrent < -0.6) || (iceActive && self.hvSOC > 0 && self.hvSOC < 42.0);
  BOOL hvDischarging = !regen && !hvCharging && ((self.hvCurrent > 0.8) || (!iceActive && self.kmh > 1.5));

  UIColor *iceCol = [UIColor colorWithRed:1.0 green:0.62 blue:0.14 alpha:1.0];
  UIColor *evCol  = [UIColor colorWithRed:0.14 green:0.88 blue:1.0 alpha:1.0];
  UIColor *chgCol = [UIColor colorWithRed:0.18 green:0.96 blue:0.52 alpha:1.0];
  UIColor *idleCol = [UIColor colorWithRed:0.55 green:0.64 blue:0.74 alpha:0.75];

  // 0. Subtle Real-Time Brake Tail Light Glow (activates when braking or strong regen, daytime & nighttime)
  if (self.isBraking || (self.hvCurrent < -12.0 && self.kmh > 2.0)) {
    CGPoint tailPt = CGPointMake(imgR.origin.x + imgR.size.width * 0.908, imgR.origin.y + imgR.size.height * 0.365);
    CGContextSaveGState(ctx);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    NSArray *bCols = @[(id)[UIColor colorWithRed:1.0 green:0.12 blue:0.16 alpha:0.75].CGColor,
                       (id)[UIColor colorWithRed:1.0 green:0.06 blue:0.10 alpha:0.0].CGColor];
    CGFloat bLocs[] = {0.0, 1.0};
    CGGradientRef bg = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)bCols, bLocs);
    CGContextDrawRadialGradient(ctx, bg, tailPt, 1.5, tailPt, 16.0, 0);
    CGGradientRelease(bg);
    CGColorSpaceRelease(cs);
    [[UIColor colorWithRed:1.0 green:0.22 blue:0.25 alpha:0.95] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(tailPt.x - 3.5, tailPt.y - 5.5, 7.0, 11.0) cornerRadius:2.5] fill];
    CGContextRestoreGState(ctx);
  }

  // 1. Clean Animated Fiber-Optic Conduits (Engine <-> Motor/PCU <-> HV Battery)
  [self drawFlowSegmentFrom:iceOut to:pcuLeft color:iceCol active:iceActive ctx:ctx];
  if (regen || hvCharging) {
    [self drawFlowSegmentFrom:pcuRight to:batIn color:chgCol active:YES ctx:ctx];
  } else if (hvDischarging) {
    [self drawFlowSegmentFrom:batIn to:pcuRight color:evCol active:YES ctx:ctx];
  } else {
    [self drawFlowSegmentFrom:pcuRight to:batIn color:evCol active:NO ctx:ctx];
  }

  // 2. Engine Core Icon (ICE) — compact OEM engine-block silhouette on front hood
  UIBezierPath *valveCap = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(CGRectGetMidX(iceR) - 6.0, iceR.origin.y - 2.2, 12.0, 3.0) cornerRadius:1.2];
  [[UIColor colorWithRed:iceActive ? 1.0 : 0.35 green:iceActive ? 0.68 : 0.44 blue:iceActive ? 0.22 : 0.54 alpha:iceActive ? 0.90 : 0.55] setFill];
  [valveCap fill];
  UIBezierPath *iceBox = [UIBezierPath bezierPathWithRoundedRect:iceR cornerRadius:4.0];
  [[UIColor colorWithRed:iceActive ? 0.45 : 0.05 green:iceActive ? 0.20 : 0.09 blue:iceActive ? 0.04 : 0.14 alpha:0.86] setFill];
  [iceBox fill];
  [[UIColor colorWithRed:iceActive ? 1.0 : 0.42 green:iceActive ? 0.68 : 0.54 blue:iceActive ? 0.20 : 0.66 alpha:iceActive ? 0.95 : 0.55] setStroke];
  iceBox.lineWidth = 1.3;
  [iceBox stroke];
  for (int c = 0; c < 3; c++) {
    CGFloat rx = iceR.origin.x + 5.2 + c * 6.5;
    [[(iceActive ? iceCol : [UIColor colorWithWhite:0.75 alpha:0.32]) colorWithAlphaComponent:iceActive ? 0.92 : 0.32] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(rx, iceR.origin.y + 3.8, 3.2, iceR.size.height - 7.6) cornerRadius:1.0] fill];
  }

  // 3. Electric Motor / PCU Node (MG2) — dark glass capsule with crisp glowing lightning bolt
  UIColor *pcuCol = regen ? chgCol : (iceActive ? (hvDischarging ? evCol : iceCol) : (hvDischarging ? evCol : idleCol));
  UIBezierPath *pcuBox = [UIBezierPath bezierPathWithRoundedRect:pcuR cornerRadius:5.0];
  [[UIColor colorWithRed:0.03 green:0.07 blue:0.12 alpha:0.88] setFill];
  [pcuBox fill];
  [[pcuCol colorWithAlphaComponent:0.92] setStroke];
  pcuBox.lineWidth = 1.3;
  [pcuBox stroke];
  // Vector lightning bolt inside MG2
  CGFloat mx = CGRectGetMidX(pcuR), my = CGRectGetMidY(pcuR);
  CGContextSetFillColorWithColor(ctx, pcuCol.CGColor);
  CGContextMoveToPoint(ctx, mx + 1.2, my - 5.2);
  CGContextAddLineToPoint(ctx, mx - 3.6, my + 0.6);
  CGContextAddLineToPoint(ctx, mx - 0.3, my + 0.6);
  CGContextAddLineToPoint(ctx, mx - 1.4, my + 5.2);
  CGContextAddLineToPoint(ctx, mx + 3.6, my - 0.6);
  CGContextAddLineToPoint(ctx, mx + 0.3, my - 0.6);
  CGContextClosePath(ctx);
  CGContextFillPath(ctx);

  // 4. HV Traction Battery Stack — positive terminal nub + 6 real SOC cells + crisp % readout above
  UIColor *batCol = (self.hvSOC > 0 && self.hvSOC < 42.0)
    ? [UIColor colorWithRed:1.0 green:0.62 blue:0.14 alpha:0.95]
    : ((regen || hvCharging) ? chgCol : evCol);
  // Positive battery terminal cap on right edge
  UIBezierPath *term = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(CGRectGetMaxX(batR) - 0.5, CGRectGetMidY(batR) - 3.5, 3.0, 7.0) cornerRadius:1.2];
  [[batCol colorWithAlphaComponent:0.85] setFill];
  [term fill];
  UIBezierPath *batBox = [UIBezierPath bezierPathWithRoundedRect:batR cornerRadius:3.5];
  [[UIColor colorWithRed:0.02 green:0.06 blue:0.11 alpha:0.88] setFill];
  [batBox fill];
  [[batCol colorWithAlphaComponent:0.90] setStroke];
  batBox.lineWidth = 1.3;
  [batBox stroke];
  NSInteger bars = 6;
  double dispSOC = (self.hvSOC > 0.5) ? self.hvSOC : 62.0;
  NSInteger lit = (NSInteger)ceil(MAX(15.0, MIN(100.0, dispSOC)) / (100.0 / bars));
  CGFloat bw = (batR.size.width - 7.0) / bars;
  for (NSInteger b = 0; b < bars; b++) {
    CGRect cell = CGRectMake(batR.origin.x + 3.5 + b * bw + 0.6, batR.origin.y + 3.0, MAX(2.0, bw - 1.2), batR.size.height - 6.0);
    [(b < lit ? batCol : [UIColor colorWithWhite:0.28 alpha:0.42]) setFill];
    [[UIBezierPath bezierPathWithRoundedRect:cell cornerRadius:1.0] fill];
  }
  if (self.hvSOC > 0.5) {
    NSString *socTxt = [NSString stringWithFormat:@"%.0f%%", self.hvSOC];
    NSDictionary *sAttrs = @{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:8.5 weight:UIFontWeightBold],
                             NSForegroundColorAttributeName:[batCol colorWithAlphaComponent:0.95]};
    CGSize ss = [socTxt sizeWithAttributes:sAttrs];
    [socTxt drawAtPoint:CGPointMake(CGRectGetMidX(batR) - ss.width * 0.5, batR.origin.y - ss.height - 1.5) withAttributes:sAttrs];
  }

  // 5. Ultra-clean single-line hybrid state pill in empty space ABOVE roofline (never covers car)
  NSString *modeText = @"READY • IDLE";
  UIColor *modeCol = idleCol;
  if (regen) {
    modeText = @"REGEN CHARGE";
    modeCol = chgCol;
  } else if (iceActive && hvDischarging) {
    modeText = @"HYBRID POWER";
    modeCol = iceCol;
  } else if (iceActive && hvCharging) {
    modeText = @"ENGINE + CHARGE";
    modeCol = chgCol;
  } else if (iceActive) {
    modeText = @"ENGINE DRIVE";
    modeCol = iceCol;
  } else if (hvDischarging) {
    modeText = @"EV ELECTRIC";
    modeCol = evCol;
  }
  NSDictionary *mAttrs = @{NSFontAttributeName:[UIFont systemFontOfSize:8.5 weight:UIFontWeightBold],
                           NSForegroundColorAttributeName:[modeCol colorWithAlphaComponent:0.96]};
  CGSize ms = [modeText sizeWithAttributes:mAttrs];
  CGFloat pillW = ms.width + 20.0;
  CGFloat pillH = 15.0;
  CGFloat pillY = MAX(1.0, imgR.origin.y - pillH - 2.0);
  if (pillY + pillH < imgR.origin.y + 6.0) {
    CGRect pRect = CGRectMake((w - pillW) * 0.5, pillY, pillW, pillH);
    [[UIColor colorWithRed:0.03 green:0.06 blue:0.10 alpha:0.78] setFill];
    UIBezierPath *mp = [UIBezierPath bezierPathWithRoundedRect:pRect cornerRadius:pillH * 0.5];
    [mp fill];
    [[modeCol colorWithAlphaComponent:0.45] setStroke];
    mp.lineWidth = 0.9;
    [mp stroke];
    [modeCol setFill];
    CGContextFillEllipseInRect(ctx, CGRectMake(pRect.origin.x + 6.0, CGRectGetMidY(pRect) - 2.5, 5.0, 5.0));
    [modeText drawAtPoint:CGPointMake(pRect.origin.x + 14.0, CGRectGetMidY(pRect) - ms.height * 0.5) withAttributes:mAttrs];
  }
}
@end

@interface DrivePrius:UIView
@property UIImageView *body;
@property UIImageView *frontRimView,*rearRimView;
@property TRDCarLightBeamsView *lightBeams;
@property TRDEnergyFlowXRayView *xrayOverlay;
@property PriusWheel *front,*rear;
@property NSTimer *wheelTimer;
@property CGFloat kmh,angle;
@property CFTimeInterval lastTick;
@property NSUInteger flowTickCount;
-(void)setSpeed:(CGFloat)speed;
-(void)updateEnergyWithSpeed:(CGFloat)speed engineRPM:(NSInteger)rpm hvCurrent:(double)hvCurrent hvSOC:(double)hvSOC isBraking:(BOOL)isBraking dt:(NSTimeInterval)dt;
-(void)stop;
@end
@implementation DrivePrius
static UIImage *TRDCropRealWheelFromPrius(UIImage *carImg, CGFloat normX, CGFloat normY, CGFloat normR) {
  if (!carImg || !carImg.CGImage) return nil;
  CGImageRef cg = carImg.CGImage;
  CGFloat iw = (CGFloat)CGImageGetWidth(cg);
  CGFloat ih = (CGFloat)CGImageGetHeight(cg);
  CGFloat cx = normX * iw;
  CGFloat cy = normY * ih;
  CGFloat r = normR * ih;
  CGRect crop = CGRectMake(MAX(0, cx - r), MAX(0, cy - r), r * 2.0, r * 2.0);
  CGImageRef sub = CGImageCreateWithImageInRect(cg, crop);
  if (!sub) return nil;
  UIImage *out = [UIImage imageWithCGImage:sub scale:carImg.scale orientation:UIImageOrientationUp];
  CGImageRelease(sub);
  return out;
}
-(instancetype)init{
  if((self=[super init])){
    self.userInteractionEnabled=NO;
    self.clipsToBounds=NO;
    UIImage *carImg=[UIImage imageNamed:@"TRDRealPrius.png"];
    self.body=[[UIImageView alloc]initWithImage:carImg];
    self.body.contentMode=UIViewContentModeScaleAspectFit;
    self.body.alpha=0.86;
    [self addSubview:self.body];
    // Crop the exact real gunmetal TRD alloy wheels directly from TRDRealPrius.png (measured red TRD cap centers)
    self.frontRimView=[[UIImageView alloc]initWithImage:TRDCropRealWheelFromPrius(carImg, 0.1683, 0.7559, 0.173)];
    self.frontRimView.contentMode=UIViewContentModeScaleAspectFill;
    self.frontRimView.clipsToBounds=YES;
    [self.body addSubview:self.frontRimView];
    self.rearRimView=[[UIImageView alloc]initWithImage:TRDCropRealWheelFromPrius(carImg, 0.7937, 0.7554, 0.173)];
    self.rearRimView.contentMode=UIViewContentModeScaleAspectFill;
    self.rearRimView.clipsToBounds=YES;
    [self.body addSubview:self.rearRimView];
    self.xrayOverlay=[[TRDEnergyFlowXRayView alloc]initWithFrame:CGRectZero];
    self.xrayOverlay.layer.drawsAsynchronously=YES;
    [self addSubview:self.xrayOverlay];
    self.lightBeams=[[TRDCarLightBeamsView alloc]initWithFrame:CGRectZero];
    self.lightBeams.layer.drawsAsynchronously=YES;
    self.lightBeams.hidden=YES;
    [self addSubview:self.lightBeams];
  }
  return self;
}
-(void)layoutSubviews{
  [super layoutSubviews];
  self.body.frame=self.bounds;
  self.xrayOverlay.frame=self.bounds;
  self.lightBeams.frame=self.bounds;
  CGFloat w=self.bounds.size.width, h=self.bounds.size.height;
  if(w>4 && h>4){
    CGFloat imgAspect=1440.0/497.0;
    CGRect imgR=((w/h)>imgAspect)
      ? CGRectMake((w-h*imgAspect)*0.5, 0, h*imgAspect, h)
      : CGRectMake(0, (h-w/imgAspect)*0.5, w, w/imgAspect);
    CGFloat rimDia=imgR.size.height*(0.173*2.0);
    self.frontRimView.transform=CGAffineTransformIdentity;
    self.frontRimView.frame=CGRectMake(imgR.origin.x+imgR.size.width*0.1683-rimDia*0.5, imgR.origin.y+imgR.size.height*0.7559-rimDia*0.5, rimDia, rimDia);
    self.frontRimView.layer.cornerRadius=rimDia*0.5;
    self.frontRimView.transform=CGAffineTransformMakeRotation(-self.angle);
    self.rearRimView.transform=CGAffineTransformIdentity;
    self.rearRimView.frame=CGRectMake(imgR.origin.x+imgR.size.width*0.7937-rimDia*0.5, imgR.origin.y+imgR.size.height*0.7554-rimDia*0.5, rimDia, rimDia);
    self.rearRimView.layer.cornerRadius=rimDia*0.5;
    self.rearRimView.transform=CGAffineTransformMakeRotation(-self.angle);
  }
  [self.lightBeams setNeedsDisplay];
  [self.xrayOverlay setNeedsDisplay];
}
-(void)setSpeed:(CGFloat)speed{
 self.kmh=MAX(0,speed);
 self.xrayOverlay.kmh=self.kmh;
 BOOL visible=(!self.hidden && self.window!=nil && (!self.superview || !self.superview.hidden));
 BOOL ecoThrottle=[[NSUserDefaults standardUserDefaults] boolForKey:@"TRDA7EcoPowerSave"];
 if(!ecoThrottle && [[NSProcessInfo processInfo] respondsToSelector:@selector(thermalState)]){
  ecoThrottle=([[NSProcessInfo processInfo] thermalState] >= NSProcessInfoThermalStateFair);
 }
 NSTimeInterval targetInterval=ecoThrottle?0.125:0.067; // 8 FPS in Eco/Warm mode, 15 FPS normal (cuts A7 GPU load ~35%)
 if(self.kmh>1.0&&!self.wheelTimer&&visible&&[UIApplication sharedApplication].applicationState==UIApplicationStateActive){
  self.lastTick=CACurrentMediaTime();
  self.wheelTimer=[NSTimer scheduledTimerWithTimeInterval:targetInterval target:self selector:@selector(spin) userInfo:nil repeats:YES];
  self.wheelTimer.tolerance=0.016;
 }else if((self.kmh<=1.0||!visible)&&self.wheelTimer){
  [self.wheelTimer invalidate];
  self.wheelTimer=nil;
 }
}
-(void)updateEnergyWithSpeed:(CGFloat)speed engineRPM:(NSInteger)rpm hvCurrent:(double)hvCurrent hvSOC:(double)hvSOC isBraking:(BOOL)isBraking dt:(NSTimeInterval)dt{
 [self setSpeed:speed];
 self.xrayOverlay.engineRPM=rpm;
 self.xrayOverlay.hvCurrent=hvCurrent;
 self.xrayOverlay.hvSOC=hvSOC;
 self.xrayOverlay.isBraking=isBraking;
 if(self.kmh<=1.0 && (rpm>100 || fabs(hvCurrent)>0.8)){
  double step = MAX(0.05, MIN(0.40, dt)) * 0.72;
  self.xrayOverlay.flowPhase = fmod(self.xrayOverlay.flowPhase + step, 1.0);
 }
 [self.xrayOverlay setNeedsDisplay];
}
-(void)startRotation{}
-(void)spin{
 if(self.hidden||!self.window||(self.superview&&self.superview.hidden)||[UIApplication sharedApplication].applicationState!=UIApplicationStateActive){[self stop];return;}
 CFTimeInterval now=CACurrentMediaTime();
 double dt=MAX(0.016,MIN(0.20,now-self.lastTick));
 self.lastTick=now;
 if(self.kmh>1.0){
  // Realistic forward wheel angular velocity (Prius 17" wheel radius ~0.315m: v(m/s)/r = kmh * 0.88 rad/s)
  self.angle=fmod(self.angle+(self.kmh*0.32*dt),M_PI*2.0);
  CGAffineTransform rot=CGAffineTransformMakeRotation(-self.angle);
  self.frontRimView.transform=rot;
  self.rearRimView.transform=rot;
  self.flowTickCount++;
  if((self.flowTickCount % 2) == 0){
   self.xrayOverlay.flowPhase = fmod(self.xrayOverlay.flowPhase + (dt * 2.0 * 0.72), 1.0);
   [self.xrayOverlay setNeedsDisplay];
  }
 }
}
-(void)stop{self.kmh=0;self.xrayOverlay.kmh=0;[self.wheelTimer invalidate];self.wheelTimer=nil;[self.xrayOverlay setNeedsDisplay];}
@end
@interface TRDHybridEcoBar:UIView
@property UILabel *evPowerLabel;
@property UILabel *evPowerRangeLabel;
@property UIView *track;
@property UIView *fillBar;
@property double throttleRatio;
-(void)updateWithSpeed:(double)speed isBraking:(BOOL)isBraking isAccelerating:(BOOL)isAccel;
-(void)updateWithOBDPowerKW:(double)kw hasOBD:(BOOL)hasOBD engineRPM:(NSInteger)rpm speed:(double)speed isBraking:(BOOL)isBraking isAccelerating:(BOOL)isAccel;
@end

@implementation TRDHybridEcoBar
-(instancetype)init{
  if((self=[super init])){
    self.backgroundColor=[UIColor clearColor];
    self.evPowerLabel=[[UILabel alloc]init];
    self.evPowerLabel.font=[UIFont boldSystemFontOfSize:12.5];
    self.evPowerLabel.adjustsFontSizeToFitWidth=YES;
    self.evPowerLabel.minimumScaleFactor=0.85;
    self.evPowerLabel.textColor=[UIColor colorWithRed:0.0 green:0.92 blue:0.50 alpha:1];
    self.evPowerLabel.text=@"⚡ EV POWER: +0.0 kW";
    [self addSubview:self.evPowerLabel];
    
    self.evPowerRangeLabel=[[UILabel alloc]init];
    self.evPowerRangeLabel.font=[UIFont boldSystemFontOfSize:11.5];
    self.evPowerRangeLabel.adjustsFontSizeToFitWidth=YES;
    self.evPowerRangeLabel.minimumScaleFactor=0.85;
    self.evPowerRangeLabel.textAlignment=NSTextAlignmentRight;
    self.evPowerRangeLabel.textColor=[UIColor colorWithWhite:0.92 alpha:1];
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
  [self updateWithOBDPowerKW:0.0 hasOBD:NO engineRPM:0 speed:speed isBraking:isBraking isAccelerating:isAccel];
}
-(void)updateWithOBDPowerKW:(double)kw hasOBD:(BOOL)hasOBD engineRPM:(NSInteger)rpm speed:(double)speed isBraking:(BOOL)isBraking isAccelerating:(BOOL)isAccel{
  if(hasOBD){
    BOOL activePWR = (rpm > 1850 || kw > 12.0 || (isAccel && rpm > 1200) || speed > 92.0);
    BOOL activeCHG = !activePWR && (isBraking || (kw < -0.6 && rpm < 1400));
    if(activeCHG){
      self.throttleRatio=MAX(-0.48, MIN(-0.12, (kw < -0.5 ? kw : -5.0) / 28.0));
      self.evPowerLabel.text=[NSString stringWithFormat:@"⚡ CHG REGEN: %.1f kW", kw < 0 ? kw : -fabs(kw)];
      self.evPowerLabel.textColor=[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1];
      self.fillBar.backgroundColor=[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1];
    }else if(activePWR){
      double engineKW = (rpm > 950) ? ((rpm - 950) / 85.0) : 0.0;
      double pwrKW = MAX(MAX(0.0, kw) + engineKW, 14.0 + speed * 0.14);
      self.throttleRatio=MIN(0.98, MAX(0.46, pwrKW / 38.0));
      self.evPowerLabel.text=[NSString stringWithFormat:@"🔥 PWR: +%.1f kW%@", pwrKW, rpm>0?[NSString stringWithFormat:@" (%ld RPM)",(long)rpm]:@""];
      self.evPowerLabel.textColor=[UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1];
      self.fillBar.backgroundColor=[UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:1];
    }else if(speed <= 0.8 && fabs(kw) < 0.8 && rpm < 100){
      self.throttleRatio=0.0;
      self.evPowerLabel.text=@"⚡ EV READY: +0.0 kW";
      self.evPowerLabel.textColor=[UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1];
      self.fillBar.backgroundColor=[UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1];
    }else{
      double demandKW = MAX(0.0, kw) + (rpm > 950 ? ((rpm - 950) / 110.0) : 0.0);
      self.throttleRatio=MAX(0.08, MIN(0.44, 0.10 + demandKW / 26.0));
      self.evPowerLabel.text=[NSString stringWithFormat:@"🍃 ECO %@: +%.1f kW", (rpm<100?@"EV":@"HV"), MAX(0.0, demandKW)];
      self.evPowerLabel.textColor=[UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1];
      self.fillBar.backgroundColor=[UIColor colorWithRed:0.0 green:0.88 blue:0.45 alpha:1];
    }
  }else if(isBraking){
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
@property (nonatomic, assign) CGFloat powerRatio;
@property (nonatomic, assign) CGFloat fuelRatio;
@property (nonatomic, assign) BOOL hasFuel;
@property (nonatomic, assign) BOOL evActive;
@property (nonatomic, assign) BOOL turnLeftOn;
@property (nonatomic, assign) BOOL turnRightOn;
@property (nonatomic, assign) BOOL hazardOn;
@property (nonatomic, assign) BOOL turnBlinkPhase;
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
    self.powerRatio = -0.46;
    self.fuelRatio = 0.55;
    self.evActive = YES;
    
    self.speedLabel = [[UILabel alloc] init];
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:52] ?: [UIFont boldSystemFontOfSize:52];
    self.speedLabel.textColor = [UIColor whiteColor];
    self.speedLabel.textAlignment = NSTextAlignmentCenter;
    self.speedLabel.text = @"0";
    [self addSubview:self.speedLabel];
    
    self.unitLabel = [[UILabel alloc] init];
    self.unitLabel.font = [UIFont boldSystemFontOfSize:12.0];
    self.unitLabel.textColor = [UIColor colorWithRed:0.0 green:0.88 blue:1.0 alpha:1];
    self.unitLabel.textAlignment = NSTextAlignmentCenter;
    self.unitLabel.text = @"KM / H • DYNAMICS";
    [self addSubview:self.unitLabel];
    
    self.gearBadge = [[UIView alloc] init];
    self.gearBadge.backgroundColor = [UIColor colorWithRed:0.02 green:0.18 blue:0.10 alpha:0.95];
    self.gearBadge.layer.cornerRadius = 6;
    self.gearBadge.layer.borderWidth = 1.2;
    self.gearBadge.layer.borderColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.45 alpha:0.8].CGColor;
    UILabel *gl = [[UILabel alloc] initWithFrame:CGRectMake(4, 1, 22, 24)];
    gl.tag = 101;
    gl.font = [UIFont boldSystemFontOfSize:19.0];
    gl.textAlignment = NSTextAlignmentCenter;
    gl.textColor = [UIColor whiteColor];
    gl.text = @"P";
    [self.gearBadge addSubview:gl];
    UILabel *gw = [[UILabel alloc] initWithFrame:CGRectMake(26, 2, 56, 22)];
    gw.tag = 102;
    gw.font = [UIFont boldSystemFontOfSize:14.5];
    gw.adjustsFontSizeToFitWidth = YES;
    gw.minimumScaleFactor = 0.65;
    gw.textAlignment = NSTextAlignmentCenter;
    gw.textColor = [UIColor colorWithRed:0.35 green:0.98 blue:0.55 alpha:1];
    gw.text = @"PARK";
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
  self.speedLabel.adjustsFontSizeToFitWidth = YES;
  self.speedLabel.minimumScaleFactor = 0.72;
  if (self.driveStyle) {
    self.speedLimitBadge.frame = CGRectMake(w - 36, 4, 30, 30);
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:86] ?: [UIFont boldSystemFontOfSize:86];
    self.speedLabel.frame = CGRectMake(24, 46, w - 58, 86);
    self.gearBadge.hidden = YES;
    self.unitLabel.frame = CGRectMake(24, 134, w - 58, 20);
    self.unitLabel.font = [UIFont boldSystemFontOfSize:12.0];
    self.unitLabel.text = @"km/h  •  GPS";
  } else {
    self.speedLimitBadge.frame = CGRectMake(w - 30, 8, 28, 28);
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:108] ?: [UIFont boldSystemFontOfSize:108];
    self.speedLabel.frame = CGRectMake(8, 8, w - 16, 98);
    self.gearBadge.hidden = NO;
    self.gearBadge.frame = CGRectMake(8, h - 28, 86, 26);
    self.unitLabel.frame = CGRectMake(98, h - 25, w - 104, 20);
    self.unitLabel.font = [UIFont boldSystemFontOfSize:12.0];
    self.unitLabel.adjustsFontSizeToFitWidth = YES;
    self.unitLabel.minimumScaleFactor = 0.85;
    self.unitLabel.text = @"KM / H • DYNAMICS";
  }
}

- (void)setSpeed:(CGFloat)speed {
  if (fabs(_speed - speed) < 0.25 && self.speedLabel.text.length > 0) return;
  _speed = speed;
  NSString *txt = (speed <= 0.5) ? @"0" : [NSString stringWithFormat:@"%.0f", speed];
  if (![self.speedLabel.text isEqualToString:txt]) self.speedLabel.text = txt;
  [self setNeedsDisplay];
}

- (void)setGear:(NSString *)gear {
  if ((_gear == gear) || (gear && [_gear isEqualToString:gear])) return;
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
  
  if (self.driveStyle) {
    // Prius 2026 Minimal HSI Circular Halo Ring (CHG cyan | ECO green | PWR crimson + right Fuel Arc + EV pill)
    CGPoint center = CGPointMake(w / 2.0 - 6.0, h / 2.0 + 10.0);
    CGFloat radius = MIN(w / 2.0 - 18.0, h / 2.0 - 6.0);
    CGFloat hsiStart = M_PI * 0.78;
    CGFloat hsiEnd = M_PI * 1.92;
    CGFloat hsiSpan = hsiEnd - hsiStart;

    // Matte obsidian inner disc glow for high contrast in daylight
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.015 green:0.025 blue:0.04 alpha:0.85].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(center.x - radius + 5, center.y - radius + 5, (radius - 5) * 2, (radius - 5) * 2));

    // Faint CHG / ECO / PWR halo background tracks
    CGContextSetLineWidth(ctx, 4.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.75 blue:0.95 alpha:0.25].CGColor);
    CGContextAddArc(ctx, center.x, center.y, radius, hsiStart, hsiStart + hsiSpan * 0.27, 0);
    CGContextStrokePath(ctx);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.15 green:0.88 blue:0.50 alpha:0.28].CGColor);
    CGContextAddArc(ctx, center.x, center.y, radius, hsiStart + hsiSpan * 0.29, hsiStart + hsiSpan * 0.68, 0);
    CGContextStrokePath(ctx);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.24 blue:0.26 alpha:0.26].CGColor);
    CGContextAddArc(ctx, center.x, center.y, radius, hsiStart + hsiSpan * 0.70, hsiEnd, 0);
    CGContextStrokePath(ctx);

    // Active illuminated HSI arc from CHG-ECO baseline (-0.46) to current powerRatio
    CGFloat clamped = MAX(-1.0, MIN(1.0, self.powerRatio));
    CGFloat norm = (clamped + 1.0) * 0.5;
    CGFloat baseNorm = (-0.46 + 1.0) * 0.5; // 0.27
    CGFloat baseAngle = hsiStart + hsiSpan * baseNorm;
    CGFloat tipAngle = hsiStart + hsiSpan * norm;
    UIColor *hsiCol = (clamped < -0.48)
      ? [UIColor colorWithRed:0.0 green:0.90 blue:1.0 alpha:1.0]
      : (clamped > 0.36 ? [UIColor colorWithRed:1.0 green:0.28 blue:0.28 alpha:1.0]
                        : [UIColor colorWithRed:0.22 green:0.96 blue:0.55 alpha:1.0]);
    CGContextSetStrokeColorWithColor(ctx, hsiCol.CGColor);
    CGContextSetLineWidth(ctx, 6.0);
    if (norm < baseNorm) {
      CGContextAddArc(ctx, center.x, center.y, radius, tipAngle, baseAngle, 0);
    } else {
      CGContextAddArc(ctx, center.x, center.y, radius, baseAngle, MAX(baseAngle + 0.04, tipAngle), 0);
    }
    CGContextStrokePath(ctx);

    // Bright marker tip dot on ring
    CGFloat tx = center.x + radius * cos(tipAngle);
    CGFloat ty = center.y + radius * sin(tipAngle);
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(tx - 4.0, ty - 4.0, 8.0, 8.0));

    // Prius 2026 Micro Arc Labels (CHG / ECO / PWR)
    UIFont *mf = [UIFont boldSystemFontOfSize:8.5];
    [@"CHG" drawAtPoint:CGPointMake(center.x - radius * 0.96, center.y + radius * 0.42) withAttributes:@{NSFontAttributeName:mf, NSForegroundColorAttributeName:[UIColor colorWithRed:0.15 green:0.88 blue:1.0 alpha:0.95]}];
    [@"ECO" drawAtPoint:CGPointMake(center.x - radius * 0.82, center.y - radius * 0.72) withAttributes:@{NSFontAttributeName:mf, NSForegroundColorAttributeName:[UIColor colorWithRed:0.35 green:0.95 blue:0.65 alpha:0.95]}];
    [@"PWR" drawAtPoint:CGPointMake(center.x - 10.0, center.y - radius - 9.0) withAttributes:@{NSFontAttributeName:mf, NSForegroundColorAttributeName:[UIColor colorWithRed:1.0 green:0.40 blue:0.40 alpha:0.95]}];

    // Top EV badge inside dial (bright green pill like Gen 5 cluster)
    if (self.evActive) {
      CGRect evR = CGRectMake(center.x - 13.0, center.y - radius + 12.0, 26.0, 14.0);
      [[UIColor colorWithRed:0.12 green:0.78 blue:0.36 alpha:0.95] setFill];
      [[UIBezierPath bezierPathWithRoundedRect:evR cornerRadius:4.0] fill];
      [@"EV" drawInRect:CGRectMake(evR.origin.x, evR.origin.y + 1.5, 26.0, 12.0) withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:9.5], NSForegroundColorAttributeName:[UIColor whiteColor], NSParagraphStyleAttributeName:({NSMutableParagraphStyle *p=[NSMutableParagraphStyle new];p.alignment=NSTextAlignmentCenter;p;})}];
    }

    // Right Inner Segmented Fuel Gauge Arc (E -> F) matching Prius 2026 right cluster edge
    CGFloat fStart = M_PI * 0.28;
    CGFloat fEnd = -M_PI * 0.04; // goes upward counter-clockwise on right rim
    CGFloat fFrac = self.hasFuel ? MAX(0.05, MIN(1.0, self.fuelRatio)) : 0.55;
    NSInteger segs = 8;
    NSInteger litSegs = (NSInteger)llround(fFrac * segs);
    for (NSInteger s = 0; s < segs; s++) {
      CGFloat t0 = (CGFloat)s / (CGFloat)segs;
      CGFloat a0 = fStart + (fEnd - fStart) * t0;
      CGFloat a1 = fStart + (fEnd - fStart) * (t0 + 0.085);
      UIColor *sc = (s < litSegs) ? ((fFrac < 0.18) ? [UIColor colorWithRed:1.0 green:0.55 blue:0.15 alpha:1.0] : [UIColor colorWithWhite:0.95 alpha:0.95]) : [UIColor colorWithWhite:0.25 alpha:0.50];
      CGContextSetStrokeColorWithColor(ctx, sc.CGColor);
      CGContextSetLineWidth(ctx, 4.5);
      CGContextAddArc(ctx, center.x, center.y, radius, a0, a1, 1);
      CGContextStrokePath(ctx);
    }
    [@"⛽" drawAtPoint:CGPointMake(center.x + radius - 6.0, center.y + radius * 0.42) withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:9.5]}];
  } else {
    CGPoint center = CGPointMake(w / 2.0, h - 24);
    CGFloat radius = MIN(w / 2.0 - 30, h - 42);
    CGFloat startAngle = M_PI * 0.96;
    CGFloat endAngle = M_PI * 2.04;
    CGFloat totalAngle = endAngle - startAngle;

    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.08 green:0.14 blue:0.20 alpha:0.85].CGColor);
    CGContextSetLineWidth(ctx, 4.5);
    CGContextAddArc(ctx, center.x, center.y, radius, startAngle, endAngle, 0);
    CGContextStrokePath(ctx);
    
    CGFloat ratio = MIN(MAX(self.speed / 180.0, 0.0), 1.0);
    if (ratio > 0.01) {
      CGFloat currentAngle = startAngle + totalAngle * ratio;
      CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.95].CGColor);
      CGContextSetLineWidth(ctx, 5.5);
      CGContextAddArc(ctx, center.x, center.y, radius, startAngle, currentAngle, 0);
      CGContextStrokePath(ctx);
    }
    
    NSArray *ticks = @[@0, @30, @60, @80, @100, @120, @140, @160];
    UIFont *font = [UIFont boldSystemFontOfSize:11.0];
    NSDictionary *textAttrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor colorWithWhite:0.92 alpha:1.0]};
    
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
        CGFloat tx = 0, ty = 0;
        if (val == 0) {
          tx = center.x - radius - 17.0;
          ty = center.y - 15.0;
        } else if (val == 60) {
          tx = center.x + (radius + 11.0) * cos(angle) - sz.width - 2.0;
          ty = center.y + (radius + 9.0) * sin(angle) - sz.height / 2.0 - 2.0;
        } else if (val == 100) {
          tx = center.x + (radius + 11.0) * cos(angle) + 2.0;
          ty = center.y + (radius + 9.0) * sin(angle) - sz.height / 2.0 - 2.0;
        } else if (val == 140) {
          tx = center.x + (radius + 10.0) * cos(angle) + 2.0;
          ty = center.y + (radius + 9.0) * sin(angle) - sz.height / 2.0 + 3.0;
        }
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
    self.gear = @"P";
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
@property (nonatomic, assign) NSInteger engineRPM;
@property (nonatomic, assign) NSInteger mg2RPM;
@property (nonatomic, assign) double coolantC;
@property (nonatomic, assign) double hvKW;
@property (nonatomic, assign) double rangeKm;
@property (nonatomic, assign) double fuelLiters;
@property (nonatomic, assign) double avgKmL;
@property (nonatomic, assign) BOOL obdLive;
@end

@implementation TRDHybridPowerMeterView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.powerRatio = -0.46;
    self.rangeKm = 398.0;
    self.fuelLiters = 22.5;
    self.avgKmL = 17.7;
    self.contentMode = UIViewContentModeRedraw;
    // Hidden legacy pill handle preserved cleanly without rendering "ECO AI ECO COACH"
    self.coachPill = [[UIView alloc] initWithFrame:CGRectZero];
    self.coachPill.hidden = YES;
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  if (w <= 0 || h <= 0) return;

  // Matte Prius 2026 Engine / Motor / Range Telemetry Pod (no duplicate needle or ECO AI text)
  CGRect card = CGRectMake(6, 4, w - 12, h - 10);
  UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:card cornerRadius:12];
  [[UIColor colorWithRed:0.02 green:0.035 blue:0.055 alpha:0.92] setFill];
  [bg fill];
  [[UIColor colorWithWhite:0.18 alpha:0.9] setStroke];
  bg.lineWidth = 1.0;
  [bg stroke];

  BOOL isRegen = (self.powerRatio < -0.48);
  BOOL isPWR = (self.powerRatio > 0.36);
  BOOL iceOn = (self.engineRPM > 100);
  UIColor *dotCol = isRegen ? [UIColor colorWithRed:0.0 green:0.90 blue:1.0 alpha:1.0]
                   : (isPWR ? [UIColor colorWithRed:1.0 green:0.30 blue:0.30 alpha:1.0]
                   : (iceOn ? [UIColor colorWithRed:1.0 green:0.75 blue:0.20 alpha:1.0]
                            : [UIColor colorWithRed:0.20 green:0.95 blue:0.55 alpha:1.0]));

  // 1. Minimal Powertrain Status Dot & Mode Pill (EV / HYBRID / PWR / REGEN)
  CGFloat cx = card.origin.x + 12.0;
  CGContextSetFillColorWithColor(ctx, dotCol.CGColor);
  CGContextFillEllipseInRect(ctx, CGRectMake(cx, 18, 9, 9));

  NSString *modeTxt = isRegen ? @"REGEN CHARGE"
                     : (isPWR ? [NSString stringWithFormat:@"HYBRID PWR • %ld RPM", (long)self.engineRPM]
                     : (iceOn ? [NSString stringWithFormat:@"ICE %ld RPM", (long)self.engineRPM]
                              : @"EV DRIVE READY"));
  [modeTxt drawInRect:CGRectMake(cx + 15, 14, card.size.width - 34, 18)
       withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:12.0], NSForegroundColorAttributeName:dotCol}];

  // Hairline divider
  [[UIColor colorWithWhite:0.16 alpha:1.0] setFill];
  UIRectFill(CGRectMake(card.origin.x + 12, 40, card.size.width - 24, 1));

  // 2. Prius 2026 Remaining Driving Range Showcase (~398 km)
  [@"EST. RANGE" drawInRect:CGRectMake(cx, 48, card.size.width - 24, 14)
            withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:10.0], NSForegroundColorAttributeName:[UIColor colorWithWhite:0.58 alpha:1.0]}];

  NSString *rngVal = [NSString stringWithFormat:@"%.0f", MAX(0.0, self.rangeKm)];
  NSDictionary *rngAttr = @{NSFontAttributeName:([UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:44] ?: [UIFont boldSystemFontOfSize:44]),
                            NSForegroundColorAttributeName:[UIColor whiteColor]};
  CGSize rSz = [rngVal sizeWithAttributes:rngAttr];
  [rngVal drawAtPoint:CGPointMake(cx, 62) withAttributes:rngAttr];
  [@"km" drawAtPoint:CGPointMake(cx + rSz.width + 6, 84)
      withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:15.0], NSForegroundColorAttributeName:[UIColor colorWithRed:0.30 green:0.90 blue:1.0 alpha:1.0]}];

  NSString *fuelSub = [NSString stringWithFormat:@"⛽ %.1f L left • %.1f km/L", self.fuelLiters, self.avgKmL];
  [fuelSub drawInRect:CGRectMake(cx, 114, card.size.width - 24, 16)
       withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:11.5], NSForegroundColorAttributeName:[UIColor colorWithWhite:0.78 alpha:1.0]}];

  // Hairline divider 2
  [[UIColor colorWithWhite:0.16 alpha:1.0] setFill];
  UIRectFill(CGRectMake(card.origin.x + 12, 138, card.size.width - 24, 1));

  // 3. Clean 3-column Engine / Motor / HV kW readout
  CGFloat colW = (card.size.width - 24) / 3.0;
  NSArray *titles = @[@"MOTOR MG2", @"ENGINE ECT", @"HV POWER"];
  NSArray *vals = @[
    [NSString stringWithFormat:@"%ld rpm", (long)self.mg2RPM],
    [NSString stringWithFormat:@"%.0f °C", self.coolantC],
    [NSString stringWithFormat:@"%+.1f kW", self.hvKW]
  ];
  for (NSInteger i = 0; i < 3; i++) {
    CGFloat x0 = cx + i * colW;
    [titles[i] drawInRect:CGRectMake(x0, 148, colW - 2, 14)
           withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:9.5], NSForegroundColorAttributeName:[UIColor colorWithWhite:0.52 alpha:1.0]}];
    UIColor *vc = (i == 2) ? dotCol : [UIColor whiteColor];
    [vals[i] drawInRect:CGRectMake(x0, 166, colW - 2, 22)
         withAttributes:@{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:13.5 weight:UIFontWeightBold], NSForegroundColorAttributeName:vc}];
  }

  // 4. Ultra-lightweight Regen Efficiency & EV/ICE Torque Split Bar (pure 2D CoreGraphics, zero extra timers)
  if (card.size.height >= 224.0) {
    CGFloat barY = 196.0;
    CGFloat barW = card.size.width - 24.0;
    BOOL isRegenNow = (self.hvKW < -0.2);
    NSInteger regenPct = isRegenNow ? (NSInteger)MIN(100, MAX(5, fabs(self.hvKW) * 5.0)) : 0;
    NSInteger evShare = (self.engineRPM > 150) ? (self.hvKW > 1.0 ? 45 : 20) : 100;
    NSInteger iceShare = 100 - evShare;
    NSString *splitLabel = isRegenNow
      ? [NSString stringWithFormat:@"REGEN EFF. %ld%%  •  RECOVERING", (long)regenPct]
      : [NSString stringWithFormat:@"TORQUE SPLIT  EV %ld%% / ICE %ld%%", (long)evShare, (long)iceShare];
    [splitLabel drawInRect:CGRectMake(cx, barY, barW, 13)
            withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:9.0],
                             NSForegroundColorAttributeName:isRegenNow ? [UIColor colorWithRed:0.22 green:0.98 blue:0.55 alpha:1.0] : [UIColor colorWithWhite:0.62 alpha:1.0]}];

    CGRect trackR = CGRectMake(cx, barY + 15.0, barW, 6.0);
    [[UIColor colorWithWhite:0.14 alpha:1.0] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:trackR cornerRadius:3.0] fill];

    if (isRegenNow) {
      CGFloat rw = MAX(8.0, barW * (regenPct / 100.0));
      [[UIColor colorWithRed:0.20 green:0.96 blue:0.55 alpha:1.0] setFill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(cx, barY + 15.0, rw, 6.0) cornerRadius:3.0] fill];
    } else {
      CGFloat ew = barW * (evShare / 100.0);
      [[UIColor colorWithRed:0.15 green:0.88 blue:1.0 alpha:0.95] setFill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(cx, barY + 15.0, ew, 6.0) cornerRadius:3.0] fill];
      if (iceShare > 0) {
        [[UIColor colorWithRed:1.0 green:0.68 blue:0.18 alpha:0.95] setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(cx + ew + 2.0, barY + 15.0, MAX(4.0, barW - ew - 2.0), 6.0) cornerRadius:3.0] fill];
      }
    }
  }
}
@end

@interface TRD3DPerspectiveGridView : UIView
@property (nonatomic, assign) CGFloat powerRatio;
@property (nonatomic, assign) CGFloat flowPhase;
@property (nonatomic, assign) BOOL isMoving;
@end

@implementation TRD3DPerspectiveGridView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    self.contentMode = UIViewContentModeRedraw;
    self.powerRatio = -0.46;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  if (w <= 0 || h <= 0) return;

  CGFloat clamped = MAX(-1.0, MIN(1.0, self.powerRatio));
  BOOL isCHG = (clamped < -0.48);
  BOOL isPWR = (clamped > 0.36);
  CGFloat rCol = isPWR ? 1.00 : (isCHG ? 0.00 : 0.12);
  CGFloat gCol = isPWR ? 0.30 : (isCHG ? 0.88 : 0.92);
  CGFloat bCol = isPWR ? 0.25 : (isCHG ? 1.00 : 0.68);

  CGFloat horizonY = h * 0.42;
  CGPoint vp = CGPointMake(w * 0.42, horizonY - 8);
  CGFloat span = MAX(1.0, h - horizonY);

  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:rCol green:gCol blue:bCol alpha:0.20].CGColor);
  CGContextSetLineWidth(ctx, 1.0);
  NSInteger numLines = 12;
  for (NSInteger i = 0; i <= numLines; i++) {
    CGFloat bottomX = (w / (CGFloat)numLines) * i;
    CGContextMoveToPoint(ctx, vp.x, vp.y);
    CGContextAddLineToPoint(ctx, bottomX, h);
    CGContextStrokePath(ctx);
  }

  // Animated perspective depth cross-bars reflecting EV / ECO / PWR / CHG motion
  NSInteger numHoriz = 7;
  CGFloat phase = self.isMoving ? fmod(fabs(self.flowPhase), 1.0) : 0.0;
  for (NSInteger i = 0; i < numHoriz; i++) {
    CGFloat rawT = ((CGFloat)i + phase) / (CGFloat)numHoriz;
    if (rawT > 1.0) rawT -= 1.0;
    CGFloat t = rawT * rawT;
    CGFloat y = horizonY + span * t;
    CGFloat hw = (w * 0.48) * t + (w * 0.18);
    CGFloat alpha = (self.isMoving ? 0.16 : 0.10) + (isPWR ? 0.42 : 0.26) * t;
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:rCol green:gCol blue:bCol alpha:alpha].CGColor);
    CGContextSetLineWidth(ctx, isPWR ? (1.2 + 1.4 * t) : (1.0 + 0.8 * t));
    CGContextMoveToPoint(ctx, w * 0.5 - hw, y);
    CGContextAddLineToPoint(ctx, w * 0.5 + hw, y);
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
  
  double minV = 99.0, maxV = 0.0;
  for (NSNumber *n in self.voltages) {
    double v = [n doubleValue];
    if (v > 5.0 && v < minV) minV = v;
    if (v > 5.0 && v > maxV) maxV = v;
  }
  double floorV = (minV < 50.0) ? (minV - 0.15) : 15.0;
  double spanV = MAX(0.35, (maxV > minV ? (maxV - minV) : 0.0) + 0.30);

  for (NSInteger i = 0; i < count; i++) {
    CGFloat x = 4 + i * (barW + gap);
    CGFloat barH = 18.0;
    BOOL lowCell = NO;
    if (self.voltages && i < self.voltages.count) {
      double v = [self.voltages[i] doubleValue];
      double ratio = (v - floorV) / spanV;
      if (ratio < 0.12) ratio = 0.12;
      if (ratio > 1.0) ratio = 1.0;
      barH = 6.0 + ratio * (baselineY - 10.0);
      lowCell = ((maxV - v) >= 0.20);
    }
    CGFloat y = baselineY - barH;
    CGRect barRect = CGRectMake(x, y, barW, barH);
    
    UIColor *fillColor = lowCell
      ? [UIColor colorWithRed:0.95 green:0.55 blue:0.10 alpha:0.90]
      : [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:0.85];
    [fillColor setFill];
    UIRectFill(barRect);
    
    [(lowCell ? [UIColor colorWithRed:1.0 green:0.75 blue:0.25 alpha:1] : [UIColor colorWithRed:0.35 green:1.0 blue:0.80 alpha:1]) setFill];
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
@property (nonatomic, strong) UIButton *btnChooseMusic;
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
    self.timeCurLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 156, 334, 18)];
    self.timeCurLabel.font = [UIFont boldSystemFontOfSize:11.5];
    self.timeCurLabel.adjustsFontSizeToFitWidth = YES;
    self.timeCurLabel.minimumScaleFactor = 0.80;
    self.timeCurLabel.textColor = [UIColor colorWithRed:0.15 green:0.95 blue:1.0 alpha:1];
    self.timeCurLabel.text = @"TRACK TIME: 0:00 / --:-- (-0:00 LEFT)";
    [self addSubview:self.timeCurLabel];

    self.timeTotalLabel = [[UILabel alloc] initWithFrame:CGRectMake(254, 158, 100, 16)];
    self.timeTotalLabel.hidden = YES;
    [self addSubview:self.timeTotalLabel];

    // Transport buttons (Prev, Play, Next)
    self.btnPrev = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPrev.frame = CGRectMake(20, 184, 86, 52);
    self.btnPrev.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
    self.btnPrev.layer.cornerRadius = 12;
    self.btnPrev.layer.borderWidth = 1.0;
    self.btnPrev.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    [self.btnPrev setTitle:@"⏮ PREV" forState:UIControlStateNormal];
    self.btnPrev.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.btnPrev setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self addSubview:self.btnPrev];

    self.btnPlay = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPlay.frame = CGRectMake(118, 184, 138, 52);
    self.btnPlay.backgroundColor = [UIColor colorWithRed:.0 green:.72 blue:.40 alpha:1];
    self.btnPlay.layer.cornerRadius = 12;
    self.btnPlay.layer.borderWidth = 1.2;
    self.btnPlay.layer.borderColor = [UIColor colorWithRed:.2 green:.9 blue:.5 alpha:1].CGColor;
    [self.btnPlay setTitle:@"▶  PLAY" forState:UIControlStateNormal];
    self.btnPlay.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.btnPlay setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self addSubview:self.btnPlay];

    self.btnNext = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnNext.frame = CGRectMake(268, 184, 86, 52);
    self.btnNext.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
    self.btnNext.layer.cornerRadius = 12;
    self.btnNext.layer.borderWidth = 1.0;
    self.btnNext.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    [self.btnNext setTitle:@"NEXT ⏭" forState:UIControlStateNormal];
    self.btnNext.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.btnNext setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
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

    // Transparent tap target across artwork + song title + source badge to choose music
    self.btnChooseMusic = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnChooseMusic.frame = CGRectMake(12, 8, 346, 136);
    self.btnChooseMusic.backgroundColor = [UIColor clearColor];
    self.btnChooseMusic.layer.cornerRadius = 14;
    self.btnChooseMusic.showsTouchWhenHighlighted = YES;
    self.btnChooseMusic.accessibilityLabel = @"Choose your music";
    [self addSubview:self.btnChooseMusic];
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

static void TRDSendMediaRemoteExternal(int cmd, void (^fallback)(void)){
 static Boolean (*mrSend)(int,id);
 static void (*mrOwner)(dispatch_queue_t,void (^)(int));
 static dispatch_once_t once;
 dispatch_once(&once,^{
  mrSend=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
  mrOwner=dlsym(RTLD_DEFAULT,"MRMediaRemoteGetNowPlayingApplicationPID");
 });
 if(!mrSend){if(fallback)fallback();return;}
 if(!mrOwner){if(!mrSend(cmd,nil)&&fallback)fallback();return;}
 pid_t selfPid=getpid();
 mrOwner(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^(int pid){
  if(pid<=0||pid==selfPid)return;
  if(!mrSend(cmd,nil)&&fallback)dispatch_async(dispatch_get_main_queue(),fallback);
 });
}

@interface TRDFrontGestureEngine : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
 float _baseLuma[96];
 float _prevLuma[96];
 BOOL _hasPrev;
 int _warmupFrames;
 BOOL _mustUncoverFirst;
 int _uncoveredFrames;
 CFAbsoluteTime _waveStartAt;
 int _peakMotion;
 CFAbsoluteTime _holdStartAt;
 BOOL _holdFired;
 float _startCX;
 float _lastCX;
 CFAbsoluteTime _leftPeakAt;
 CFAbsoluteTime _rightPeakAt;
 CFAbsoluteTime _lastSampleAt;
 CFAbsoluteTime _cooldownUntil;
 NSUInteger _frameIdx;
 float _smoothAmbient;
 float _prevMeanLuma;
}
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, copy) void (^onWaveNext)(void);
@property (nonatomic, copy) void (^onWavePrev)(void);
@property (nonatomic, copy) void (^onPlayPause)(void);
@property (nonatomic, copy) void (^onHoldVoiceSearch)(void);
+(instancetype)sharedEngine;
+(BOOL)isEnabledByUser;
-(void)startIfEnabled;
-(void)ensureRunning;
-(void)cooldownFor:(NSTimeInterval)seconds;
-(void)stop;
@end

@implementation TRDFrontGestureEngine
+(instancetype)sharedEngine{
 static TRDFrontGestureEngine *s=nil;
 static dispatch_once_t once;
 dispatch_once(&once,^{ s=[[TRDFrontGestureEngine alloc]init]; });
 return s;
}
// Enabled by default; user can toggle OFF anytime in CAR SETTINGS ("TRDFrontGestureDisabled")
+(BOOL)isEnabledByUser{
 return ![[NSUserDefaults standardUserDefaults] boolForKey:@"TRDFrontGestureDisabled"];
}
-(instancetype)init{
 if((self=[super init])){
  _queue=dispatch_queue_create("com.codex.cardash.frontgesture",DISPATCH_QUEUE_SERIAL);
  _smoothAmbient=-1.0f;
  _warmupFrames=16;
  _mustUncoverFirst=YES;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionEvent:) name:AVCaptureSessionInterruptionEndedNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSessionEvent:) name:AVCaptureSessionRuntimeErrorNotification object:nil];
 }
 return self;
}
-(void)cooldownFor:(NSTimeInterval)seconds{
 dispatch_async(_queue,^{
  CFAbsoluteTime target = CFAbsoluteTimeGetCurrent() + seconds;
  if(target > _cooldownUntil) _cooldownUntil = target;
  _mustUncoverFirst = YES;
  _uncoveredFrames = 0;
  _holdStartAt = 0;
  _holdFired = NO;
  _waveStartAt = 0;
 });
}
-(void)handleSessionEvent:(NSNotification *)note{
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.35*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  if([UIApplication sharedApplication].applicationState==UIApplicationStateActive && [TRDFrontGestureEngine isEnabledByUser]){
   [self ensureRunning];
  }
 });
}
-(void)ensureRunning{
 if(![TRDFrontGestureEngine isEnabledByUser])return;
 UIInterfaceOrientation uiOri=[NSThread isMainThread]?[UIApplication sharedApplication].statusBarOrientation:UIInterfaceOrientationLandscapeRight;
 dispatch_async(_queue,^{
  CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
  if(!self.session){
   dispatch_async(dispatch_get_main_queue(),^{ [self startIfEnabled]; });
   return;
  }
  if(!self.session.isRunning || (_lastSampleAt > 0 && (now - _lastSampleAt) > 3.0)){
   if(self.session.isRunning)[self.session stopRunning];
   AVCaptureVideoDataOutput *out=self.session.outputs.firstObject;
   AVCaptureConnection *conn=[out isKindOfClass:[AVCaptureVideoDataOutput class]]?[out connectionWithMediaType:AVMediaTypeVideo]:nil;
   if(conn && conn.isVideoOrientationSupported){
    conn.videoOrientation=(uiOri==UIInterfaceOrientationLandscapeLeft)?AVCaptureVideoOrientationLandscapeLeft:AVCaptureVideoOrientationLandscapeRight;
   }
   _hasPrev=NO;
   _warmupFrames=16;
   _mustUncoverFirst=YES;
   _uncoveredFrames=0;
   _waveStartAt=0;
   _holdStartAt=0;
   _holdFired=NO;
   _lastSampleAt=now;
   [self.session startRunning];
  }
 });
}
-(void)startIfEnabled{
 if(![TRDFrontGestureEngine isEnabledByUser]){
  [self stop];
  return;
 }
 UIInterfaceOrientation uiOri=[NSThread isMainThread]?[UIApplication sharedApplication].statusBarOrientation:UIInterfaceOrientationLandscapeRight;
 dispatch_async(_queue,^{
  if(self.session){
   if(!self.session.isRunning){
    _hasPrev=NO;
    _warmupFrames=16;
    _mustUncoverFirst=YES;
    _uncoveredFrames=0;
    _holdStartAt=0;
    _holdFired=NO;
    [self.session startRunning];
   }
   return;
  }
  AVCaptureDevice *front=nil;
  for(AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]){
   if(d.position==AVCaptureDevicePositionFront){front=d;break;}
  }
  if(!front)return;
  NSError *err=nil;
  AVCaptureDeviceInput *input=[AVCaptureDeviceInput deviceInputWithDevice:front error:&err];
  if(!input||err)return;
  AVCaptureSession *sess=[[AVCaptureSession alloc]init];
  if([sess respondsToSelector:@selector(setAutomaticallyConfiguresApplicationAudioSession:)]){
   sess.automaticallyConfiguresApplicationAudioSession=NO;
  }
  [sess beginConfiguration];
  if([sess canSetSessionPreset:AVCaptureSessionPresetLow]){
   sess.sessionPreset=AVCaptureSessionPresetLow;
  }
  if([sess canAddInput:input])[sess addInput:input];
  AVCaptureVideoDataOutput *out=[[AVCaptureVideoDataOutput alloc]init];
  out.alwaysDiscardsLateVideoFrames=YES;
  out.videoSettings=@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
  [out setSampleBufferDelegate:self queue:self.queue];
  if([sess canAddOutput:out])[sess addOutput:out];
  AVCaptureConnection *conn=[out connectionWithMediaType:AVMediaTypeVideo];
  if(conn){
   if(conn.isVideoOrientationSupported){
    conn.videoOrientation=(uiOri==UIInterfaceOrientationLandscapeLeft)?AVCaptureVideoOrientationLandscapeLeft:AVCaptureVideoOrientationLandscapeRight;
   }
   if(conn.isVideoMirroringSupported){
    conn.automaticallyAdjustsVideoMirroring=NO;
    conn.videoMirrored=YES;
   }
  }
  [sess commitConfiguration];
  // Set exposure ONCE at creation — NEVER call lockForConfiguration inside captureOutput (prevents mediaserverd hang!)
  if([front lockForConfiguration:nil]){
   if([front isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]){
    front.exposureMode=AVCaptureExposureModeContinuousAutoExposure;
   }
   front.activeVideoMinFrameDuration=CMTimeMake(1,15);
   front.activeVideoMaxFrameDuration=CMTimeMake(1,10);
   [front unlockForConfiguration];
  }
  _hasPrev=NO;
  _warmupFrames=16;
  _mustUncoverFirst=YES;
  _uncoveredFrames=0;
  _waveStartAt=0;
  _holdStartAt=0;
  _holdFired=NO;
  _lastSampleAt=CFAbsoluteTimeGetCurrent();
  self.session=sess;
  [sess startRunning];
 });
}
-(void)stop{
 dispatch_async(_queue,^{
  if(self.session && self.session.isRunning){
   [self.session stopRunning];
  }
  self.session=nil; // Release AVCaptureSession & mediaserverd buffers completely when stopped!
  _hasPrev=NO;
  _warmupFrames=16;
  _mustUncoverFirst=YES;
  _uncoveredFrames=0;
  _waveStartAt=0;
  _holdStartAt=0;
  _holdFired=NO;
 });
}
-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
 CVImageBufferRef pix=CMSampleBufferGetImageBuffer(sampleBuffer);
 if(!pix)return;
 if(CVPixelBufferLockBaseAddress(pix,kCVPixelBufferLock_ReadOnly)!=kCVReturnSuccess)return;
 size_t w=CVPixelBufferGetWidthOfPlane(pix,0);
 size_t h=CVPixelBufferGetHeightOfPlane(pix,0);
 size_t bpr=CVPixelBufferGetBytesPerRowOfPlane(pix,0);
 const uint8_t *base=(const uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pix,0);
 if(!base||w<24||h<16){CVPixelBufferUnlockBaseAddress(pix,kCVPixelBufferLock_ReadOnly);return;}

 float cur[96];
 float sumLuma=0;
 int idx=0;
 for(int gy=0;gy<8;gy++){
  size_t py=(h*(gy*2+1))/16;
  const uint8_t *row=base+py*bpr;
  for(int gx=0;gx<12;gx++){
   size_t px=(w*(gx*2+1))/24;
   float v=(float)row[px];
   cur[idx++]=v;
   sumLuma+=v;
  }
 }
 CVPixelBufferUnlockBaseAddress(pix,kCVPixelBufferLock_ReadOnly);

 float meanLuma=sumLuma/96.0f;
 _lastSampleAt=CFAbsoluteTimeGetCurrent();
 _frameIdx++;
 if(!_hasPrev || _warmupFrames > 0){
  if(_warmupFrames > 0) _warmupFrames--;
  for(int i=0;i<96;i++){_prevLuma[i]=cur[i];_baseLuma[i]=cur[i];}
  _hasPrev=YES;
  _smoothAmbient=meanLuma;
  _prevMeanLuma=meanLuma;
  return;
 }

 float globalShift = meanLuma - _prevMeanLuma;
 _prevMeanLuma = meanLuma;
 float ambEst = (_smoothAmbient > 0.0f) ? _smoothAmbient : meanLuma;
 BOOL isNightCabin = (ambEst < 30.0f);
 // Responsive near-field driver-zone thresholds (gx >= 3 masks out left passenger seat!)
 float dmThresh = isNightCabin ? MAX(8.0f, 5.0f + ambEst * 0.28f) : 17.0f;
 float totalWThresh = isNightCabin ? MAX(95.0f, ambEst * 4.5f) : 185.0f;
 int minStartCells = isNightCabin ? 8 : 10;
 int minWavePeak = isNightCabin ? 14 : 18;
 int edgeHitMin = 3;

 int motionCells=0;
 int rowHitMask=0;
 int leftEdgeHits=0, rightEdgeHits=0;
 int darkCells=0;
 float ambRef = (_smoothAmbient > 8.0f) ? _smoothAmbient : meanLuma;
 float darkCellCut = MAX(20.0f, ambRef * 0.62f);
 float spatialVarSum = 0.0f;
 float weightedX=0.0f, totalW=0.0f;
 for(int i=0;i<96;i++){
  int gx = i % 12;
  int gy = i / 12;
  spatialVarSum += fabsf(cur[i] - meanLuma);
  if(cur[i] <= darkCellCut) darkCells++;
  // Illumination-invariant motion: subtract global brightness shift so passing streetlights / shadows NEVER trigger swipes!
  float dm=fabsf((cur[i]-_prevLuma[i]) - globalShift);
  _prevLuma[i]=cur[i];
  // RHD Prius (steering wheel Right, Lightning port Right -> front lens on Left bezel):
  // Columns gx = 0..2 look straight into the Left Passenger Seat — ignore them for swipe motion!
  if(gx < 3) continue;
  if(dm>=dmThresh){
   motionCells++;
   rowHitMask |= (1 << gy);
   float normDriverX = (float)(gx - 3) / 8.0f; // 0.0 = center-inner, 1.0 = driver right side
   weightedX += normDriverX * dm;
   totalW += dm;
   if(gx <= 5) leftEdgeHits++;
   else if(gx >= 8) rightEdgeHits++;
  }
 }
 int activeRows = __builtin_popcount((unsigned int)rowHitMask);

 if(motionCells <= 2 && _holdStartAt == 0){
  for(int i=0;i<96;i++) _baseLuma[i]=_baseLuma[i]*0.88f + cur[i]*0.12f;
  if(!_mustUncoverFirst){
   _smoothAmbient=(_smoothAmbient<0)?meanLuma:(_smoothAmbient*0.88f + meanLuma*0.12f);
  }
 }

 CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
 if(now < _cooldownUntil){
  _waveStartAt=0;
  _holdStartAt=0;
  _holdFired=NO;
  return;
 }

 // Close palm cover (~1-6 cm directly over camera lens):
 // Works even when Auto-Exposure boosts gain on skin because an out-of-focus palm has low spatial contrast!
 float avgContrast = spatialVarSum / 96.0f;
 BOOL flatClosePalm = (avgContrast < 14.0f && (meanLuma < ambRef * 0.95f || darkCells >= 24));
 BOOL darkDrop = (ambRef >= 12.0f && darkCells >= 38 && meanLuma < ambRef * 0.68f) || (darkCells >= 50 && meanLuma < 20.0f && ambRef > 12.0f);
 BOOL darkCover = (darkDrop || flatClosePalm);

 if(_mustUncoverFirst){
  if(!darkCover && darkCells < 34){
   if(++_uncoveredFrames >= 3) _mustUncoverFirst = NO;
  } else {
   _uncoveredFrames = 0;
  }
 }

 // 1) Close Hand Cover (~1-6 cm over front camera) -> Play/Pause ONLY (NEVER fall through into swipe!)
 if(!_mustUncoverFirst && darkCover){
  _waveStartAt = 0;
  _peakMotion = 0;
  _leftPeakAt = 0;
  _rightPeakAt = 0;
  if(_holdStartAt == 0){
   _holdStartAt = now;
   _holdFired = NO;
  } else if(!_holdFired && (now - _holdStartAt) >= 0.26){
   _holdFired = YES;
   _mustUncoverFirst = YES;
   _uncoveredFrames = 0;
   _cooldownUntil = now + 1.5;
   void (^cb)(void) = self.onPlayPause;
   if(cb) dispatch_async(dispatch_get_main_queue(), cb);
  }
  return;
 } else if(_holdStartAt > 0){
  _holdStartAt = 0;
  _holdFired = NO;
 }

 // 2) Near-Field Driver-Side Hand Swipe (gx=3..11) -> Prev / Next Track ONLY!
 if(motionCells >= minStartCells && activeRows >= 3 && totalW > totalWThresh){
  float cx = weightedX / totalW;
  if(_waveStartAt==0){
   _waveStartAt=now;
   _peakMotion=motionCells;
   _startCX=cx;
   _lastCX=cx;
   _leftPeakAt=(leftEdgeHits>=edgeHitMin)?now:0;
   _rightPeakAt=(rightEdgeHits>=edgeHitMin)?now:0;
  } else {
   if(motionCells>_peakMotion)_peakMotion=motionCells;
   _lastCX=cx;
   if(leftEdgeHits>=edgeHitMin && _leftPeakAt==0)_leftPeakAt=now;
   if(rightEdgeHits>=edgeHitMin && _rightPeakAt==0)_rightPeakAt=now;
  }
  if((now-_waveStartAt)>0.68){_waveStartAt=0;_peakMotion=0;_leftPeakAt=0;_rightPeakAt=0;}
 }else if(_waveStartAt>0 && motionCells<=5){
  double dur=now-_waveStartAt;
  int peak=_peakMotion;
  float deltaX=_lastCX - _startCX;
  CFAbsoluteTime lAt=_leftPeakAt, rAt=_rightPeakAt;
  _waveStartAt=0;
  _peakMotion=0;
  _leftPeakAt=0;
  _rightPeakAt=0;
  BOOL crossedFullSpan = (lAt > 0 && rAt > 0 && fabs(rAt - lAt) >= 0.018);
  if(dur>=0.05 && dur<=0.65 && peak>=minWavePeak && (crossedFullSpan || fabsf(deltaX)>=0.28f)){
   BOOL goNext = crossedFullSpan ? (rAt > lAt) : (deltaX > 0);
   _cooldownUntil=now+1.55;
   if(goNext){
    void (^cb)(void)=self.onWaveNext;
    if(cb)dispatch_async(dispatch_get_main_queue(),cb);
   } else {
    void (^cb)(void)=self.onWavePrev;
    if(cb)dispatch_async(dispatch_get_main_queue(),cb);
   }
  }
 }
}
@end

@interface Dashboard:UIViewController<CLLocationManagerDelegate,UIGestureRecognizerDelegate,UIWebViewDelegate>
@property (nonatomic, strong) TRDCarPlayMediaWidget *carplayMediaWidget;
@property (nonatomic, strong) TRDCarPlayTelemetryWidget *carplayTelemetryWidget;
-(void)showGestureToast:(NSString *)msg;
-(void)voiceMusicTapped;


@property (nonatomic, strong) TRDAnalogSpeedoDial *homeSpeedoDial, *driveSpeedoDial;
@property (nonatomic, strong) TRDVerticalShifterView *driveShifter;
@property (nonatomic, strong) TRDHybridPowerMeterView *drivePowerMeter;
@property (nonatomic, strong) TRD3DPerspectiveGridView *drive3DGrid;
@property (nonatomic, strong) UIView *homeAiEcoCard, *homeThermalsCard;
@property (nonatomic, strong) UIView *driveClockCard, *driveBatteryCard, *driveTripCard;
@property (nonatomic, strong) UIButton *driveEqBtn, *driveExitBtn;
@property (nonatomic, assign) NSInteger activeTripSlot;
@property (nonatomic, assign) double lastSlotMeters, lastSlotSeconds, lastSlotFuel, lastSlotCost;
@property (nonatomic, strong) NSMutableDictionary *dailyHistoryCache;
@property (nonatomic, strong) NSDate *lastDailyHistoryWriteAt;
@property (nonatomic, assign) BOOL sessionLoggedToday;
@property (nonatomic, assign) NSInteger activeSummaryTab;
@property (nonatomic, assign) BOOL lowFuelStage1Alerted, lowFuelStage2Alerted;
@property (nonatomic, assign) NSInteger lowFuelConfirmTicks;
@property (nonatomic, strong) UIView *lowFuelBanner;
@property (nonatomic, strong) AVAudioPlayer *alarmAudioPlayer;
@property (nonatomic, copy) NSString *nearestStationName, *nearestStationAddress;
@property (nonatomic, assign) double nearestStationKm, nearestStationLat, nearestStationLon;
@property (nonatomic, copy) NSString *pendingMapJS;
-(void)homeTripSlotTapped:(UIButton *)btn;
-(void)selectTripSlot:(UIButton *)btn;
-(void)refreshDriveTripDisplay;
-(void)syncTripSlotsDelta:(BOOL)forceDiskFlush;
-(NSDictionary *)loadTripSlot:(NSInteger)slot;
-(void)resetTripSlot:(NSInteger)slot;
-(double)effectiveFuelKmPerL;
-(double)estimatedRangeKmForFuelLiters:(double)fuelL;
-(void)updateHeadlightBeamsUI:(TRDOBDClient *)obd;


@property (nonatomic, strong) UILabel *topClockLabel;
@property (nonatomic, strong) UIButton *obdStatusPill, *dayNightPill, *thaiVoicePill, *settingsPill, *helpPill, *voicePill;
@property (nonatomic, strong) UILabel *voiceBanner;
@property (nonatomic, strong) AVAudioEngine *voiceEngine;
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *speechRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *speechTask;
@property (nonatomic, copy) NSString *voiceLastTranscript;
@property (nonatomic, assign) BOOL voiceListening;
@property (nonatomic, assign) NSUInteger voiceSessionGen;
@property (nonatomic, strong) UIView *readyPill, *gearBadge;
@property (nonatomic, strong) NSMutableArray *gearButtons, *driveModePills;
@property (nonatomic, strong) TRD14BlockGraphView *blockGraphView;
@property (nonatomic, strong) UIView *frontMotorBox, *rearBatteryBox, *flowBeamLine;
@property (nonatomic, strong) UIView *featureExplanationBanner;
@property (nonatomic, strong) NSTimer *featureExplanationTimer;
@property (nonatomic, strong) TRDCarLightBeamsView *homeCarLightBeams;
@property (nonatomic, strong) TRDDoorDiagramView *doorDiagramView;
-(void)gearButtonTapped:(UIButton *)btn;
-(void)driveModePillTapped:(UIButton *)btn;
-(void)openFeatureHelpMenu;
-(void)showFeatureExplanation:(NSString *)title body:(NSString *)body;
-(void)hideFeatureExplanation;

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
-(void)updateMapCarForce:(BOOL)force;
-(void)executeOrQueueMapJS:(NSString *)js;
-(void)openMapToLat:(double)lat lon:(double)lon name:(NSString *)name address:(NSString *)address autoStart:(BOOL)autoStart;
-(void)openMapWithSearchQuery:(NSString *)query;
-(void)loadMapHTML;
-(UIWebView *)ensureMapWebView;
-(void)teardownMapWebView;
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
-(void)prepareForExternalAppLaunch;
-(BOOL)launchBundleApp:(NSString *)identifier;
-(void)captureLifecycle;
-(void)applyMotionPolicy;
-(void)refreshStatusStrip;
-(void)toggleCalmDrive;

@property TRDSettingsMenu *settingsSheet;
@property BOOL hasPlaybackRate;
@property BOOL youtubeSource;
@property NSData *artworkData;
@property NSUInteger artworkLen,artworkSig;
@property NSUInteger artworkDecodes,metadataGeneration,commandsPending;
@property BOOL metadataPending;
@property double metadataRequestedAt;
@property NSUInteger memoryWarnings;
-(void)releaseArtwork;

-(void)refreshNowPlaying;
-(void)refreshTransportState;
@property CarWelcome *welcome;
@property BOOL didShowWelcome;
@property BOOL isCarSessionActive;
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
-(void)releaseTransientSpeechAudio:(BOOL)stopSpeaking;
-(void)confirmSettingsActionTitle:(NSString *)title message:(NSString *)message confirmTitle:(NSString *)confirmTitle onConfirm:(void(^)(void))onConfirm;
-(void)restoreDisplayBrightness;
@property (nonatomic, strong) UILabel *obdAlertBanner;
@property (nonatomic, strong) NSDate *lastOBDWarnDate;
@property (nonatomic, assign) BOOL pausedMusicForReverse;
@property (nonatomic, assign) NSUInteger reverseAudioGen;
@property (nonatomic, assign) NSInteger reverseAudioSource;
@property (nonatomic, copy) NSString *reverseResumeRadioURL;
@property (nonatomic, copy) NSString *reverseResumeRadioName;
@property (nonatomic, assign) NSTimeInterval lastMapVisibleAt;
@property (nonatomic, assign) BOOL ownsSpeechAudioSession;

@property UIView *navigation;
@property NSArray *navButtons;
@property BOOL musicMode;
@property UIButton *browseMusic;
@property UILabel *musicHeading;
-(void)openMusic;
-(void)browseSource:(NSString *)bundle;
-(void)browseSource:(NSString *)bundle target:(NSString *)target;
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
@property BOOL manualDriveActive;
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
@property NSTimeInterval navTouchDownAt;
@property NSInteger navTouchDownTag;
@property (nonatomic, weak) UITouch *navTrackingTouch;
@property CGPoint navTouchDownPoint;
@property NSTimeInterval lastNavigationAcceptedAt;
@property NSTimeInterval lastNavigationRejectAt;
@property (nonatomic, copy) NSString *lastNavigationRejectReason;
@property BOOL mapNavigationAuthorized;
@property NSUInteger mapConfirmationGeneration;
@property NSUInteger mapURLRequestGeneration;
@property NSUInteger unplugCheckGeneration;
@property NSTimeInterval lastOBDUIRefreshAt;
@property BOOL obdUIRefreshPending;
@property NSTimeInterval navGuardUntil;
-(void)ensureActiveRunLoopHealth;
-(void)confirmOpenMapDestination:(BOOL)isCarPlay;
-(void)card:(UIButton *)button;
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
@property NSUInteger radioGeneration;
@property NSString *currentRadioStation;
@property NSString *currentRadioURL;
@property (nonatomic, copy) NSArray *offlineTracks;
@property (nonatomic, assign) NSInteger offlineTrackIndex;
@property (nonatomic, assign) BOOL offlinePlaybackActive;
@property (nonatomic, copy) NSString *currentOfflineArtist;
-(void)playOfflineTrackAtIndex:(NSInteger)index;
-(void)nextOfflineTrack;
-(void)prevOfflineTrack;
-(void)offlineTrackDidFinish:(NSNotification *)note;
-(void)showTripSummary;
-(void)showTripSummaryWithTab:(NSInteger)tabIndex;
-(void)checkLowFuelWarning;
-(void)testLowFuelWarning;
-(void)dismissLowFuelBanner;
-(void)navigateToFoundGasStation;
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
-(void)topAuxPillTapped;
-(void)updateDrive12VPill;
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

-(void)homeTripSlotTapped:(UIButton *)btn{
  NSInteger slot = btn.tag - 740;
  if(slot < 0 || slot > 2) slot = 0;
  self.activeTripSlot = slot;
  [[NSUserDefaults standardUserDefaults] setInteger:slot forKey:@"TRDActiveTripSlot"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [self refreshDriveTripDisplay];
}
-(void)selectTripSlot:(UIButton *)btn{
  NSInteger slot = btn.tag - 840;
  if(slot < 0 || slot > 2) slot = 0;
  self.activeTripSlot = slot;
  [[NSUserDefaults standardUserDefaults] setInteger:slot forKey:@"TRDActiveTripSlot"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [self refreshDriveTripDisplay];
}
-(NSDictionary *)loadTripSlot:(NSInteger)slot{
  if(slot < 0 || slot > 2) slot = 0;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString *key = [NSString stringWithFormat:@"TRDTripSlot_%ld", (long)slot];
  NSDictionary *d = [ud dictionaryForKey:key];
  if([d isKindOfClass:[NSDictionary class]]) return d;
  // First-time non-destructive migration: preserve ongoing Trip A & cumulative Odometer in Trip C
  if(slot == 0 && self.trip){
    TRDOBDClient *obd = [TRDOBDClient sharedClient];
    double km = self.trip.meters / 1000.0;
    double fuel = obd.tripFuelUsedLiters;
    double price = (obd.fuelPricePerLiter > 0) ? obd.fuelPricePerLiter : 38.50;
    double cost = (obd.tripFuelCostTHB > 0) ? obd.tripFuelCostTHB : (fuel * price);
    NSDictionary *initA = @{@"km":@(km), @"sec":@(self.trip.seconds), @"fuel":@(fuel), @"cost":@(cost), @"maf":@(obd.isConnected)};
    [ud setObject:initA forKey:key];
    return initA;
  }
  if(slot == 2){
    double odo = [ud doubleForKey:@"TRDTotalOdometer"];
    if(odo > 0.01){
      NSDictionary *initC = @{@"km":@(odo), @"sec":@(0.0), @"fuel":@(0.0), @"cost":@(0.0), @"maf":@(NO)};
      [ud setObject:initC forKey:key];
      return initC;
    }
  }
  return @{@"km":@(0.0), @"sec":@(0.0), @"fuel":@(0.0), @"cost":@(0.0), @"maf":@(NO)};
}

-(NSMutableDictionary *)ensureDailyHistoryLoaded{
  if(!self.dailyHistoryCache){
    NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:TRDDailyTripLogPath()];
    if([disk isKindOfClass:[NSDictionary class]] && [disk[@"days"] isKindOfClass:[NSDictionary class]]){
      self.dailyHistoryCache = [disk mutableCopy];
      self.dailyHistoryCache[@"days"] = [disk[@"days"] mutableCopy];
    }else{
      self.dailyHistoryCache = [@{@"version":@(1), @"days":[NSMutableDictionary dictionary]} mutableCopy];
    }
  }
  NSMutableDictionary *days = self.dailyHistoryCache[@"days"];
  NSString *todayKey = TRDDateKeyForDate([NSDate date]);
  if(![days[todayKey] isKindOfClass:[NSDictionary class]]){
    days[todayKey] = [@{@"date":todayKey, @"km":@(0.0), @"fuelL":@(0.0), @"cost":@(0.0), @"sec":@(0.0), @"trips":@(self.sessionLoggedToday ? 1 : 0), @"maf":@(NO)} mutableCopy];
  }
  return days;
}

-(void)flushDailyHistoryToPlist{
  if(!self.dailyHistoryCache) return;
  [self.dailyHistoryCache writeToFile:TRDDailyTripLogPath() atomically:YES];
  self.lastDailyHistoryWriteAt = [NSDate date];
}

-(void)syncTripSlotsDelta:(BOOL)forceDiskFlush{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  TRDOBDClient *obd = [TRDOBDClient sharedClient];
  double curM = self.trip ? self.trip.meters : 0.0;
  double curS = self.trip ? self.trip.seconds : 0.0;
  double curF = obd.tripFuelUsedLiters;
  double price = (obd.fuelPricePerLiter > 0) ? obd.fuelPricePerLiter : 38.50;
  double curC = (obd.tripFuelCostTHB > 0.001) ? obd.tripFuelCostTHB : (curF * price);

  if(curM < self.lastSlotMeters) self.lastSlotMeters = 0.0;
  if(curS < self.lastSlotSeconds) self.lastSlotSeconds = 0.0;
  if(curF < self.lastSlotFuel) self.lastSlotFuel = 0.0;
  if(curC < self.lastSlotCost) self.lastSlotCost = 0.0;

  double dKm = MAX(0.0, (curM - self.lastSlotMeters) / 1000.0);
  double dSec = MAX(0.0, curS - self.lastSlotSeconds);
  double dFuel = MAX(0.0, curF - self.lastSlotFuel);
  double dCost = MAX(0.0, curC - self.lastSlotCost);

  // Ensure initial migration seeds Trip A / C / Today cleanly without losing prior state
  NSMutableDictionary *days = [self ensureDailyHistoryLoaded];

  BOOL changed = (dKm > 0.0001 || dSec >= 1.0 || dFuel > 0.0001 || dCost > 0.001);
  if(changed){
    for(NSInteger i = 0; i < 3; i++){
      NSMutableDictionary *slotDict = [[self loadTripSlot:i] mutableCopy];
      slotDict[@"km"] = @([slotDict[@"km"] doubleValue] + dKm);
      slotDict[@"sec"] = @([slotDict[@"sec"] doubleValue] + dSec);
      slotDict[@"fuel"] = @([slotDict[@"fuel"] doubleValue] + dFuel);
      slotDict[@"cost"] = @([slotDict[@"cost"] doubleValue] + dCost);
      if(obd.isConnected) slotDict[@"maf"] = @(YES);
      [ud setObject:slotDict forKey:[NSString stringWithFormat:@"TRDTripSlot_%ld", (long)i]];
    }

    NSString *todayKey = TRDDateKeyForDate([NSDate date]);
    NSMutableDictionary *dayRec = [days[todayKey] mutableCopy] ?: [@{@"date":todayKey, @"km":@(0.0), @"fuelL":@(0.0), @"cost":@(0.0), @"sec":@(0.0), @"trips":@(0), @"maf":@(NO)} mutableCopy];
    dayRec[@"km"] = @([dayRec[@"km"] doubleValue] + dKm);
    dayRec[@"sec"] = @([dayRec[@"sec"] doubleValue] + dSec);
    dayRec[@"fuelL"] = @([dayRec[@"fuelL"] doubleValue] + dFuel);
    dayRec[@"cost"] = @([dayRec[@"cost"] doubleValue] + dCost);
    if(obd.isConnected) dayRec[@"maf"] = @(YES);
    if(!self.sessionLoggedToday && curM > 20.0){
      dayRec[@"trips"] = @([dayRec[@"trips"] integerValue] + 1);
      self.sessionLoggedToday = YES;
    }
    days[todayKey] = dayRec;

    self.lastSlotMeters = curM;
    self.lastSlotSeconds = curS;
    self.lastSlotFuel = curF;
    self.lastSlotCost = curC;
    [ud setDouble:curM forKey:@"TRDLastSyncedTripMeters"];
    [ud setDouble:curS forKey:@"TRDLastSyncedTripSeconds"];
    [ud setDouble:curF forKey:@"TRDLastSyncedTripFuel"];
    [ud setDouble:curC forKey:@"TRDLastSyncedTripCost"];
  }

  BOOL dueForDisk = forceDiskFlush || !self.lastDailyHistoryWriteAt || (-[self.lastDailyHistoryWriteAt timeIntervalSinceNow] >= 8.0);
  if((changed || forceDiskFlush) && dueForDisk){
    [self flushDailyHistoryToPlist];
    [ud synchronize];
  }
}

-(double)effectiveFuelKmPerL{
  TRDOBDClient *obd = [TRDOBDClient sharedClient];
  double tripKm = self.trip ? (self.trip.meters / 1000.0) : 0.0;
  [obd updateRealConsumptionWithDistanceKm:tripKm];

  double sessionKmL = 0.0;
  if(tripKm >= 1.5 && obd.tripFuelUsedLiters >= 0.08){
    sessionKmL = MAX(6.0, MIN(38.0, tripKm / obd.tripFuelUsedLiters));
  }

  NSDictionary *slotB = [self loadTripSlot:1];
  double bKm = [slotB[@"km"] doubleValue];
  double bFuel = [slotB[@"fuel"] doubleValue];
  double slotBKmL = 0.0;
  if(bKm >= 2.0 && bFuel >= 0.12){
    slotBKmL = MAX(6.0, MIN(38.0, bKm / bFuel));
  }

  double dailyKmL = 0.0;
  NSMutableDictionary *days = [self ensureDailyHistoryLoaded];
  NSString *todayKey = TRDDateKeyForDate([NSDate date]);
  NSDictionary *todayRec = days[todayKey];
  if([todayRec isKindOfClass:[NSDictionary class]]){
    double dKm = [todayRec[@"km"] doubleValue];
    double dFuel = [todayRec[@"fuelL"] doubleValue];
    if(dKm >= 2.0 && dFuel >= 0.12){
      dailyKmL = MAX(6.0, MIN(38.0, dKm / dFuel));
    }
  }

  if(sessionKmL > 0.0 && slotBKmL > 0.0){
    double w = MIN(0.65, tripKm / 25.0);
    return w * sessionKmL + (1.0 - w) * slotBKmL;
  }
  if(slotBKmL > 0.0) return slotBKmL;
  if(dailyKmL > 0.0) return dailyKmL;
  if(sessionKmL > 0.0) return sessionKmL;
  if(obd.hasLiveMAFFuel && obd.tripAverageKmPerL > 1.0){
    return MAX(6.0, MIN(35.0, obd.tripAverageKmPerL));
  }
  if(!obd.isConnected && obd.tripAverageKmPerL > 1.0){
    return MAX(6.0, MIN(35.0, obd.tripAverageKmPerL));
  }
  return 17.5;
}

-(double)estimatedRangeKmForFuelLiters:(double)fuelL{
  // Full accuracy vs Prius MFD above 9L; smoothly reserve up to 1.5L sump below 9L so near-empty warnings stay safe.
  double deadSump = (fuelL >= 9.0) ? 0.0 : ((fuelL <= 5.0) ? 1.5 : ((9.0 - fuelL) * (1.5 / 4.0)));
  double usableL = MAX(0.0, fuelL - deadSump);
  return MAX(0.0, usableL * [self effectiveFuelKmPerL]);
}

-(void)updateHeadlightBeamsUI:(TRDOBDClient *)obd{
  BOOL lightsActive = (obd.headlightSensorsLive && (obd.tailLightsOn || obd.headlightsOn || obd.highBeamOn));
  CGFloat beamAlpha = obd.highBeamOn ? 1.0 : (obd.headlightsOn ? 0.85 : 0.35);
  if(self.driveCar.lightBeams){
    self.driveCar.lightBeams.hidden = !lightsActive;
    self.driveCar.lightBeams.alpha = beamAlpha;
  }
  if(self.homeCarLightBeams){
    self.homeCarLightBeams.hidden = !lightsActive;
    self.homeCarLightBeams.alpha = beamAlpha;
  }
}

-(void)resetTripSlot:(NSInteger)slot{
  if(slot < 0 || slot > 2) slot = 0;
  // Always flush pending live trip deltas to all other slots & daily history BEFORE clearing the chosen slot!
  [self syncTripSlotsDelta:YES];
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  [ud setObject:@{@"km":@(0.0), @"sec":@(0.0), @"fuel":@(0.0), @"cost":@(0.0), @"maf":@(NO)}
         forKey:[NSString stringWithFormat:@"TRDTripSlot_%ld", (long)slot]];
  if(slot == 0){
    self.trip = [TRDTrip new];
    [self saveTrip];
    [[TRDOBDClient sharedClient] resetTripFuel];
    self.lastSlotMeters = 0.0;
    self.lastSlotSeconds = 0.0;
    self.lastSlotFuel = 0.0;
    self.lastSlotCost = 0.0;
    [ud setDouble:0.0 forKey:@"TRDLastSyncedTripMeters"];
    [ud setDouble:0.0 forKey:@"TRDLastSyncedTripSeconds"];
    [ud setDouble:0.0 forKey:@"TRDLastSyncedTripFuel"];
    [ud setDouble:0.0 forKey:@"TRDLastSyncedTripCost"];
    self.sessionLoggedToday = NO;
  }
  [ud synchronize];
  [self refreshTrip];
  [self refreshDriveTripDisplay];
}

-(void)refreshDriveTripDisplay{
  [self syncTripSlotsDelta:NO];
  double liveKm = self.trip ? (self.trip.meters / 1000.0) : 0.0;
  long liveSec = self.trip ? (long)self.trip.seconds : 0;
  TRDOBDClient *obd = [TRDOBDClient sharedClient];
  double price = (obd.fuelPricePerLiter > 0) ? obd.fuelPricePerLiter : 38.50;
  double liveLiters = obd.tripFuelUsedLiters;
  double liveCost = (obd.tripFuelCostTHB > 0.001) ? obd.tripFuelCostTHB : (liveLiters * price);
  NSString *liveTimeMin = (liveSec >= 3600)
    ? [NSString stringWithFormat:@"%02ld:%02ld ชม.", liveSec / 3600, (liveSec / 60) % 60]
    : [NSString stringWithFormat:@"%02ld:%02ld นาที", (liveSec / 60) % 60, liveSec % 60];

  UIView *abPod = [self.view viewWithTag:895];
  if (abPod) {
    UILabel *abState = (UILabel *)[abPod viewWithTag:899];
    UILabel *abSub = (UILabel *)[abPod viewWithTag:897];
    UILabel *abVal = (UILabel *)[abPod viewWithTag:898];
    double curSpd = (self.fix && self.fix.speed >= 0 && self.gpsLive) ? (self.fix.speed * 3.6) : 0.0;
    BOOL isMoving = (curSpd >= 2.0);
    if (abState) {
      abState.text = isMoving ? @"🟢 รถกำลังเคลื่อนที่ • นับระยะ GPS ต่อเนื่อง" : @"⏸️ รถจอดนิ่ง • หยุดพักการนับอัตโนมัติ";
      abState.textColor = isMoving ? [UIColor colorWithRed:0.25 green:1.0 blue:0.65 alpha:1.0] : [UIColor colorWithRed:1.0 green:0.82 blue:0.28 alpha:1.0];
    }
    if (abSub) {
      abSub.text = [NSString stringWithFormat:@"⏱️ เวลาขับ %@  •  ⛽ %.2f L (฿ %.1f)", liveTimeMin, liveLiters, liveCost];
    }
    if (abVal) {
      abVal.text = (liveKm < 100.0) ? [NSString stringWithFormat:@"%.2f km", liveKm] : [NSString stringWithFormat:@"%.1f km", liveKm];
    }
  }
  UILabel *lMaxL = (UILabel *)[self.view viewWithTag:906];
  if (lMaxL) {
    double maxSpd = self.trip ? self.trip.maximum : 0.0;
    lMaxL.text = [NSString stringWithFormat:@"🚀 MAX: %.0f km/h • GPS", maxSpd];
  }
  UIButton *lModeB = (UIButton *)[self.view viewWithTag:905];
  if (lModeB) {
    NSString *mText = (TRDTheme == 0) ? @"🔥 SPORT MODE" : (TRDTheme == 1) ? @"❄️ NORMAL MODE" : @"🌱 ECO MODE";
    [lModeB setTitle:mText forState:UIControlStateNormal];
  }

  NSInteger slot = self.activeTripSlot;
  if(slot < 0 || slot > 2) slot = 0;
  NSDictionary *slotData = [self loadTripSlot:slot];
  double dist = [slotData[@"km"] doubleValue];
  long slotSec = (long)[slotData[@"sec"] doubleValue];
  double fuelL = [slotData[@"fuel"] doubleValue];
  double cost = [slotData[@"cost"] doubleValue];
  BOOL usedMAF = [slotData[@"maf"] boolValue] || obd.isConnected;
  double avgSpd = (slotSec > 5 && dist > 0.001) ? ((dist * 1000.0) / slotSec * 3.6) : 0.0;
  NSString *timeStr = (slotSec >= 3600)
    ? [NSString stringWithFormat:@"%02ld:%02ld ชม.", slotSec / 3600, (slotSec / 60) % 60]
    : [NSString stringWithFormat:@"%02ld:%02ld นาที", (slotSec / 60) % 60, slotSec % 60];

  BOOL hasRealFuel = (dist > 0.05 && fuelL > 0.005);
  double kml = hasRealFuel ? MAX(3.0, MIN(99.9, dist / fuelL)) : 0.0;
  NSString *kmlDisplay = hasRealFuel
    ? [NSString stringWithFormat:@"%.1f km/L", kml]
    : ((dist > 0.05 && usedMAF) ? @"EV 0.0 L" : @"--.- km/L");
  NSString *kmlNote = hasRealFuel
    ? (usedMAF ? (kml >= 18.0 ? @"MAF จริง • ประหยัด" : @"MAF จริง • เรียลไทม์") : @"GPS คำนวณจริงตามความเร็ว")
    : ((dist > 0.05 && usedMAF) ? @"วิ่งไฟฟ้าล้วน (EV)" : @"รอรถเคลื่อนที่");

  if(self.driveTripCard){
    for(int i=0; i<3; i++){
      UIButton *tb = (UIButton *)[self.driveTripCard viewWithTag:840+i];
      if(tb){
        if(i == slot){
          tb.backgroundColor = [UIColor colorWithRed:0.0 green:0.75 blue:0.95 alpha:0.30];
          tb.layer.borderColor = [UIColor colorWithRed:0.0 green:0.90 blue:1.0 alpha:0.95].CGColor;
          [tb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }else{
          tb.backgroundColor = [UIColor colorWithWhite:0.10 alpha:1.0];
          tb.layer.borderColor = [UIColor colorWithWhite:0.26 alpha:1.0].CGColor;
          [tb setTitleColor:[UIColor colorWithWhite:0.75 alpha:1.0] forState:UIControlStateNormal];
        }
      }
    }
    UILabel *subL = (UILabel *)[self.driveTripCard viewWithTag:823];
    if(subL){
      subL.adjustsFontSizeToFitWidth = YES;
      subL.minimumScaleFactor = 0.80;
      if(slot == 0) subL.text = @"📍 ทริปนี้ A ➔ B (คำนวณจริงแยกอิสระ)";
      else if(slot == 1) subL.text = @"⛽ ทริปถังน้ำมันนี้ B (สะสมจริงต่อเนื่อง)";
      else subL.text = @"🏁 ทริประยะยาว C (สะสมจริงต่อเนื่อง)";
    }
    UILabel *lCostTitle = (UILabel *)[self.driveTripCard viewWithTag:873];
    if(lCostTitle){
      NSString *fuelTag = TRDFuelShortCode(obd.selectedFuelTypeIndex);
      NSString *costTitle = [NSString stringWithFormat:@"ค่าน้ำมัน (%@)", fuelTag];
      if(![lCostTitle.text isEqualToString:costTitle]) lCostTitle.text = costTitle;
    }
    UILabel *vDist = (UILabel *)[self.driveTripCard viewWithTag:851];
    UILabel *vKml  = (UILabel *)[self.driveTripCard viewWithTag:852];
    UILabel *vCost = (UILabel *)[self.driveTripCard viewWithTag:853];
    UILabel *vTime = (UILabel *)[self.driveTripCard viewWithTag:854];
    if(vDist){
      vDist.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:22.0] ?: [UIFont boldSystemFontOfSize:22.0];
      vDist.textColor = [UIColor colorWithRed:0.20 green:1.0 blue:0.65 alpha:1.0];
      vDist.text = (dist < 100.0) ? [NSString stringWithFormat:@"%.2f km", dist] : [NSString stringWithFormat:@"%.1f km", dist];
    }
    if(vKml)  vKml.text  = kmlDisplay;
    if(vCost) vCost.text = [NSString stringWithFormat:@"฿ %.2f", cost];
    if(vTime) vTime.text = [NSString stringWithFormat:@"%@ • %.0f km/h", [timeStr stringByReplacingOccurrencesOfString:@" ชม." withString:@""], avgSpd];
  }

  UIView *hTripCard = [self.view viewWithTag:711];
  if(hTripCard){
    for(int i=0; i<3; i++){
      UIButton *htb = (UIButton *)[hTripCard viewWithTag:740+i];
      if(htb){
        if(i == slot){
          htb.backgroundColor = [UIColor colorWithRed:0.95 green:0.20 blue:0.25 alpha:0.35];
          htb.layer.borderColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:0.95].CGColor;
          [htb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }else{
          htb.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
          htb.layer.borderColor = [UIColor colorWithWhite:0.28 alpha:1.0].CGColor;
          [htb setTitleColor:[UIColor colorWithWhite:0.78 alpha:1.0] forState:UIControlStateNormal];
        }
      }
    }
    UILabel *htbL = (UILabel *)[hTripCard viewWithTag:713];
    if(htbL){
      NSString *slotTitle = (slot == 0) ? @"TRIP A • ทริปนี้ (คำนวณจริง)" : (slot == 1) ? @"TRIP B • ถังน้ำมันนี้ (คำนวณจริง)" : @"TRIP C • สะสมระยะยาว (คำนวณจริง)";
      NSString *enTimeStr = [[timeStr stringByReplacingOccurrencesOfString:@" ชม." withString:@" hrs"] stringByReplacingOccurrencesOfString:@" นาที" withString:@" min"];
      NSString *distFmt = (dist < 100.0) ? [NSString stringWithFormat:@"%.2f km", dist] : [NSString stringWithFormat:@"%.1f km", dist];
      NSString *fuelTag = TRDFuelShortCode(obd.selectedFuelTypeIndex);
      htbL.text = [NSString stringWithFormat:@"MODE: %@\nDISTANCE: %@ (น้ำมัน %.2f L)\nECONOMY: %@ (%@)\nFUEL COST (%@): ฿ %.2f (%.2f ฿/L)\nAVG SPEED: %.1f km/h\nDRIVE TIME: %@", slotTitle, distFmt, fuelL, kmlDisplay, kmlNote, fuelTag, cost, price, avgSpd, enTimeStr];
    }
  }
}
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
-(void)applyGearToUI:(NSString *)g{
  if(!g.length) return;
  UILabel *curL = (UILabel *)[self.gearBadge viewWithTag:801];
  if([self.driveShifter.gear isEqualToString:g] && [self.homeSpeedoDial.gear isEqualToString:g] &&
     curL && [curL.text isEqualToString:g] && self.gearButtons.count > 0){
    return;
  }
  NSArray *names = @[@"P", @"R", @"N", @"D", @"B"];
  NSInteger idx = [names indexOfObject:g];
  self.homeSpeedoDial.gear = g;
  self.driveSpeedoDial.gear = g;
  self.driveShifter.gear = g;
  [self.driveShifter setNeedsDisplay];

  UILabel *l = (UILabel *)[self.gearBadge viewWithTag:801];
  UILabel *w = (UILabel *)[self.gearBadge viewWithTag:802];
  NSString *gearCode = g ?: @"P";
  if(l) l.text = gearCode;
  UIColor *gColor = [UIColor colorWithRed:.35 green:.95 blue:.50 alpha:1];
  UIColor *gBg = [UIColor colorWithRed:.03 green:.14 blue:.08 alpha:.94];
  NSString *gWordStr = @"PARK";
  if([gearCode isEqualToString:@"P"]){
    gWordStr = @"PARK";
    gColor = [UIColor colorWithRed:.30 green:.98 blue:.58 alpha:1];
    gBg = [UIColor colorWithRed:.03 green:.14 blue:.08 alpha:.94];
  }else if([gearCode isEqualToString:@"R"]){
    gWordStr = @"REVERSE";
    gColor = [UIColor colorWithRed:1.0 green:.32 blue:.38 alpha:1];
    gBg = [UIColor colorWithRed:.20 green:.03 blue:.05 alpha:.95];
  }else if([gearCode isEqualToString:@"N"]){
    gWordStr = @"NEUTRAL";
    gColor = [UIColor colorWithRed:1.0 green:.80 blue:.22 alpha:1];
    gBg = [UIColor colorWithRed:.18 green:.12 blue:.02 alpha:.95];
  }else if([gearCode isEqualToString:@"B"]){
    gWordStr = @"BRAKE";
    gColor = [UIColor colorWithRed:1.0 green:.56 blue:.18 alpha:1];
    gBg = [UIColor colorWithRed:.19 green:.08 blue:.02 alpha:.95];
  }else{
    gWordStr = @"DRIVE";
    gColor = [UIColor colorWithRed:.20 green:.92 blue:1.0 alpha:1];
    gBg = [UIColor colorWithRed:.02 green:.10 blue:.16 alpha:.95];
  }
  if(w){
    w.text = gWordStr;
    w.textColor = gColor;
  }
  if(l) l.textColor = [UIColor whiteColor];
  self.gearBadge.backgroundColor = gBg;
  self.gearBadge.layer.borderColor = [gColor colorWithAlphaComponent:.75].CGColor;
  for(int i=0; i<self.gearButtons.count; i++){
    UIButton *b = self.gearButtons[i];
    if(i == idx){
      b.backgroundColor = [UIColor colorWithRed:.05 green:.45 blue:.22 alpha:1];
      b.layer.borderColor = [UIColor colorWithRed:.25 green:.90 blue:.48 alpha:1].CGColor;
      [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }else{
      b.backgroundColor = [UIColor colorWithWhite:.13 alpha:1];
      b.layer.borderColor = [UIColor colorWithWhite:.34 alpha:1].CGColor;
      [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
  }
}
-(void)gearButtonTapped:(UIButton *)btn{
  NSInteger idx = btn.tag - 810;
  NSArray *names = @[@"P", @"R", @"N", @"D", @"B"];
  if(idx >= 0 && idx < names.count){
    NSString *g = names[idx];
    [[TRDOBDClient sharedClient] simulateGear:g];
    [self applyGearToUI:g];
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
      b.backgroundColor = (idx==2)?[UIColor colorWithRed:.35 green:.06 blue:.10 alpha:1]:[UIColor colorWithRed:.04 green:.22 blue:.12 alpha:.95];
      b.layer.borderColor = (idx==2)?[UIColor colorWithRed:1 green:.25 blue:.25 alpha:1].CGColor:[UIColor colorWithRed:.25 green:.85 blue:.45 alpha:.9].CGColor;
      [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }else{
      b.backgroundColor = [UIColor colorWithWhite:.13 alpha:1];
      b.layer.borderColor = [UIColor colorWithWhite:.34 alpha:1].CGColor;
      [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
  }
}

#import "CarExtrasMethods.h"
#import "TRDTripMethods.h"
-(UILabel *)label:(CGFloat)size color:(UIColor *)color{UILabel *l=[UILabel new];l.font=[UIFont systemFontOfSize:size];l.textColor=color;[self.view addSubview:l];return l;}
-(void)viewDidLoad{
 [super viewDidLoad];[[TRDOBDClient sharedClient] startScanning];[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(obdGearChanged:) name:TRDOBDGearChangedNotification object:nil];[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(obdDataUpdated:) name:TRDOBDDataDidUpdateNotification object:nil];self.trip=[TRDTrip new];[self.trip restore:[[NSUserDefaults standardUserDefaults]dictionaryForKey:@"TRDTripSummary"]];self.activeTripSlot=[[NSUserDefaults standardUserDefaults]integerForKey:@"TRDActiveTripSlot"];NSUserDefaults *syncUd=[NSUserDefaults standardUserDefaults];if([syncUd objectForKey:@"TRDLastSyncedTripMeters"]){self.lastSlotMeters=[syncUd doubleForKey:@"TRDLastSyncedTripMeters"];self.lastSlotSeconds=[syncUd doubleForKey:@"TRDLastSyncedTripSeconds"];self.lastSlotFuel=[syncUd doubleForKey:@"TRDLastSyncedTripFuel"];self.lastSlotCost=[syncUd doubleForKey:@"TRDLastSyncedTripCost"];}else{self.lastSlotMeters=self.trip.meters;self.lastSlotSeconds=self.trip.seconds;self.lastSlotFuel=[TRDOBDClient sharedClient].tripFuelUsedLiters;self.lastSlotCost=[TRDOBDClient sharedClient].tripFuelCostTHB;[self loadTripSlot:0];[self loadTripSlot:2];}[self ensureDailyHistoryLoaded];[self flushDailyHistoryToPlist];TRDTheme=MAX(0,MIN(2,[[NSUserDefaults standardUserDefaults]integerForKey:@"TRDTheme"]));self.displayMode=MAX(0,MIN(2,[[NSUserDefaults standardUserDefaults]integerForKey:@"TRDDisplayMode"]));self.panel=[[SportPanel alloc]initWithFrame:self.view.bounds];self.panel.userInteractionEnabled=NO;self.panel.opaque=YES;self.panel.clockOnly=YES;[self.view addSubview:self.panel];self.view.backgroundColor=[UIColor colorWithRed:.025 green:.025 blue:.03 alpha:1];UIColor *blue=TRDAccent();self.heading=[self label:18 color:blue];self.heading.text=@"PRIUS TRD SPORTIVO";self.heading.font=[UIFont boldSystemFontOfSize:16];self.owner=[self label:10.5 color:[UIColor colorWithRed:0 green:.85 blue:1 alpha:1]];self.owner.text=@"LUXURY EV SMART COCKPIT • FULLSCREEN KIOSK READY";self.owner.font=[UIFont boldSystemFontOfSize:10];
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
  [self.dayNightPill setTitle:self.nightMode?@"🌙 NIGHT":@"☀️ DAY" forState:UIControlStateNormal];
  [self.dayNightPill setTitleColor:[UIColor colorWithRed:1.0 green:.82 blue:.25 alpha:1] forState:UIControlStateNormal];
  self.dayNightPill.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
  [self.dayNightPill addTarget:self action:@selector(toggleNight) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.dayNightPill];

  self.thaiVoicePill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.thaiVoicePill.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
  self.thaiVoicePill.layer.cornerRadius = 6;
  self.thaiVoicePill.layer.borderWidth = 1.0;
  self.thaiVoicePill.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
  [self.thaiVoicePill setTitle:@"🔊 THAI VOICE" forState:UIControlStateNormal];
  [self.thaiVoicePill setTitleColor:[UIColor colorWithRed:0 green:.85 blue:1 alpha:1] forState:UIControlStateNormal];
  self.thaiVoicePill.titleLabel.font = [UIFont boldSystemFontOfSize:12.5];
  [self.thaiVoicePill addTarget:self action:@selector(topAuxPillTapped) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.thaiVoicePill];

  self.settingsPill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.settingsPill.backgroundColor = [UIColor colorWithWhite:.08 alpha:1];
  self.settingsPill.layer.cornerRadius = 6;
  self.settingsPill.layer.borderWidth = 1.0;
  self.settingsPill.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
  [self.settingsPill setTitle:@"⚙️ SETTINGS" forState:UIControlStateNormal];
  [self.settingsPill setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  self.settingsPill.titleLabel.font = [UIFont boldSystemFontOfSize:12.5];
  [self.settingsPill addTarget:self action:@selector(carSettings) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.settingsPill];

  self.helpPill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.helpPill.backgroundColor = [UIColor colorWithRed:0.02 green:0.16 blue:0.24 alpha:0.95];
  self.helpPill.layer.cornerRadius = 6;
  self.helpPill.layer.borderWidth = 1.0;
  self.helpPill.layer.borderColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.75].CGColor;
  [self.helpPill setTitle:@"💡 HELP" forState:UIControlStateNormal];
  [self.helpPill setTitleColor:[UIColor colorWithRed:0.2 green:0.95 blue:1.0 alpha:1] forState:UIControlStateNormal];
  self.helpPill.titleLabel.font = [UIFont boldSystemFontOfSize:12.5];
  [self.helpPill addTarget:self action:@selector(openFeatureHelpMenu) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.helpPill];

  self.voicePill = [UIButton buttonWithType:UIButtonTypeCustom];
  self.voicePill.backgroundColor = [UIColor colorWithRed:0.18 green:0.04 blue:0.08 alpha:0.95];
  self.voicePill.layer.cornerRadius = 10;
  self.voicePill.layer.borderWidth = 1.2;
  self.voicePill.layer.borderColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.35 alpha:0.85].CGColor;
  [self.voicePill setTitle:@"🎙️" forState:UIControlStateNormal];
  [self.voicePill setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  self.voicePill.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
  [self.voicePill addTarget:self action:@selector(toggleVoiceCommand) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.voicePill];

  self.homeCarLightBeams = [[TRDCarLightBeamsView alloc] initWithFrame:CGRectZero];
  self.homeCarLightBeams.hidden = YES;
  [self.view addSubview:self.homeCarLightBeams];

  self.doorDiagramView = [[TRDDoorDiagramView alloc] initWithFrame:CGRectZero];
  self.doorDiagramView.hidden = NO;
  [self.doorDiagramView addTarget:self action:@selector(carStatusTapped) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.doorDiagramView];

  self.readyPill = [[UIView alloc]init];
  self.readyPill.userInteractionEnabled = YES;
  [self.readyPill addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDrive)]];
  self.readyPill.backgroundColor = [UIColor colorWithRed:.02 green:.10 blue:.06 alpha:.95];
  self.readyPill.layer.cornerRadius = 6;
  self.readyPill.layer.borderWidth = 1.2;
  self.readyPill.layer.borderColor = [UIColor colorWithRed:.25 green:.85 blue:.45 alpha:.6].CGColor;
  UILabel *rpL = [[UILabel alloc]initWithFrame:CGRectMake(0,0,154,20)];
  rpL.font = [UIFont boldSystemFontOfSize:13.0];
  rpL.textColor = [UIColor colorWithRed:.35 green:.98 blue:.50 alpha:1];
  rpL.textAlignment = NSTextAlignmentCenter;
  rpL.text = @"◀◀  ● READY  ▶▶";
  [self.readyPill addSubview:rpL];
  [self.view addSubview:self.readyPill];

  self.gearBadge = [[UIView alloc]init];
  self.gearBadge.backgroundColor = [UIColor colorWithRed:.03 green:.14 blue:.08 alpha:.94];
  self.gearBadge.layer.cornerRadius = 8;
  self.gearBadge.layer.borderWidth = 1.3;
  self.gearBadge.layer.borderColor = [UIColor colorWithRed:.25 green:.85 blue:.45 alpha:.75].CGColor;
  UILabel *gLetter = [[UILabel alloc]initWithFrame:CGRectMake(6, 1, 36, 40)];
  gLetter.tag = 801;
  gLetter.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:34.0] ?: [UIFont boldSystemFontOfSize:32.0];
  gLetter.textAlignment = NSTextAlignmentCenter;
  gLetter.adjustsFontSizeToFitWidth = YES;
  gLetter.minimumScaleFactor = 0.70;
  gLetter.textColor = [UIColor whiteColor];
  gLetter.text = @"D";
  [self.gearBadge addSubview:gLetter];
  UILabel *gWord = [[UILabel alloc]initWithFrame:CGRectMake(44, 2, 114, 38)];
  gWord.tag = 802;
  gWord.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:27.0] ?: [UIFont boldSystemFontOfSize:25.0];
  gWord.textAlignment = NSTextAlignmentCenter;
  gWord.adjustsFontSizeToFitWidth = YES;
  gWord.minimumScaleFactor = 0.60;
  gWord.textColor = [UIColor colorWithRed:.20 green:.92 blue:1.0 alpha:1];
  gWord.text = @"DRIVE";
  [self.gearBadge addSubview:gWord];
  [self.view addSubview:self.gearBadge];

  self.gearButtons = [NSMutableArray array];
  NSArray *gNames = @[@"P", @"R", @"N", @"D", @"B"];
  for(int i=0; i<5; i++){
    UIButton *gb = [UIButton buttonWithType:UIButtonTypeCustom];
    gb.tag = 810 + i;
    [gb setTitle:gNames[i] forState:UIControlStateNormal];
    gb.titleLabel.font = [UIFont boldSystemFontOfSize:15.5];
    gb.layer.cornerRadius = 6;
    gb.layer.borderWidth = 1.2;
    if(i == 0){
      gb.backgroundColor = [UIColor colorWithRed:.05 green:.45 blue:.22 alpha:1];
      gb.layer.borderColor = [UIColor colorWithRed:.25 green:.90 blue:.48 alpha:1].CGColor;
      [gb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
      gb.backgroundColor = [UIColor colorWithWhite:.13 alpha:1];
      gb.layer.borderColor = [UIColor colorWithWhite:.34 alpha:1].CGColor;
      [gb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
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
    mb.titleLabel.font = [UIFont boldSystemFontOfSize:12.5];
    mb.titleLabel.adjustsFontSizeToFitWidth = YES;
    mb.titleLabel.minimumScaleFactor = 0.85;
    mb.layer.cornerRadius = 6;
    mb.layer.borderWidth = 1.2;
    if(i == 1){
      mb.backgroundColor = [UIColor colorWithRed:.04 green:.22 blue:.12 alpha:.95];
      mb.layer.borderColor = [UIColor colorWithRed:.25 green:.85 blue:.45 alpha:.9].CGColor;
      [mb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
      mb.backgroundColor = [UIColor colorWithWhite:.13 alpha:1];
      mb.layer.borderColor = [UIColor colorWithWhite:.34 alpha:1].CGColor;
      [mb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    [mb addTarget:self action:@selector(driveModePillTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.driveModePills addObject:mb];
    [self.view addSubview:mb];
  }

  self.frontMotorBox = [[UIView alloc]init];
  self.frontMotorBox.backgroundColor = [UIColor colorWithRed:.02 green:.06 blue:.09 alpha:.95];
  self.frontMotorBox.layer.cornerRadius = 6;
  self.frontMotorBox.layer.borderWidth = 1.2;
  self.frontMotorBox.layer.borderColor = [UIColor colorWithRed:0 green:.80 blue:.95 alpha:.5].CGColor;
  UILabel *fmL1 = [[UILabel alloc]initWithFrame:CGRectMake(8,3,188,20)];fmL1.font=[UIFont boldSystemFontOfSize:13.0];fmL1.adjustsFontSizeToFitWidth=YES;fmL1.minimumScaleFactor=0.85;fmL1.textColor=[UIColor whiteColor];fmL1.text=@"FRONT AXLE (TRANSAXLE)";[self.frontMotorBox addSubview:fmL1];
  UILabel *fmL2 = [[UILabel alloc]initWithFrame:CGRectMake(8,23,188,20)];fmL2.tag=841;fmL2.font=[UIFont boldSystemFontOfSize:13.0];fmL2.adjustsFontSizeToFitWidth=YES;fmL2.minimumScaleFactor=0.85;fmL2.textColor=[UIColor colorWithRed:0 green:.90 blue:1 alpha:1];fmL2.text=@"⚡ MOTOR MG1 / MG2";[self.frontMotorBox addSubview:fmL2];
  [self.view addSubview:self.frontMotorBox];

  self.rearBatteryBox = [[UIView alloc]init];
  self.rearBatteryBox.backgroundColor = [UIColor colorWithRed:.02 green:.08 blue:.05 alpha:.95];
  self.rearBatteryBox.layer.cornerRadius = 6;
  self.rearBatteryBox.layer.borderWidth = 1.2;
  self.rearBatteryBox.layer.borderColor = [UIColor colorWithRed:.25 green:.85 blue:.45 alpha:.5].CGColor;
  UILabel *rbL1 = [[UILabel alloc]initWithFrame:CGRectMake(8,3,188,20)];rbL1.font=[UIFont boldSystemFontOfSize:13.0];rbL1.adjustsFontSizeToFitWidth=YES;rbL1.minimumScaleFactor=0.85;rbL1.textColor=[UIColor whiteColor];rbL1.textAlignment=NSTextAlignmentRight;rbL1.text=@"REAR AXLE (HYBRID PACK)";[self.rearBatteryBox addSubview:rbL1];
  UILabel *rbL2 = [[UILabel alloc]initWithFrame:CGRectMake(8,23,188,20)];rbL2.tag=842;rbL2.font=[UIFont boldSystemFontOfSize:13.0];rbL2.adjustsFontSizeToFitWidth=YES;rbL2.minimumScaleFactor=0.85;rbL2.textColor=[UIColor colorWithRed:.35 green:.98 blue:.50 alpha:1];rbL2.textAlignment=NSTextAlignmentRight;rbL2.text=@"HV BATTERY PACK 🔋";[self.rearBatteryBox addSubview:rbL2];
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
  self.homeAiEcoCard.backgroundColor = [UIColor colorWithRed:.02 green:.07 blue:.05 alpha:1.0];
  self.homeAiEcoCard.opaque = YES;
  self.homeAiEcoCard.layer.cornerRadius = 10;
  self.homeAiEcoCard.layer.borderWidth = 1.0;
  self.homeAiEcoCard.layer.borderColor = [UIColor colorWithRed:.25 green:.75 blue:.40 alpha:.4].CGColor;
  self.homeAiEcoCard.userInteractionEnabled = YES;
  [self.homeAiEcoCard addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cycleHomeWidgetMode)]];
  [self.view addSubview:self.homeAiEcoCard];

  NSArray *qTitles = @[@"📷 กล้องหลัง H109Y", @"🎙️ สั่งเสียงหาเพลง", @"🗺️ แผนที่นำทาง"];
  SEL qActions[3] = {@selector(openCamera), @selector(voiceMusicTapped), @selector(openMap)};
  for(int qi=0; qi<3; qi++){
    UIButton *qb = [UIButton buttonWithType:UIButtonTypeCustom];
    qb.tag = 510 + qi;
    qb.frame = CGRectMake(10, 34 + qi * 45, 212, 39);
    qb.backgroundColor = [UIColor colorWithRed:0.04 green:0.14 blue:0.22 alpha:1.0];
    qb.layer.cornerRadius = 8;
    qb.layer.borderWidth = 1.0;
    qb.layer.borderColor = [UIColor colorWithRed:0.15 green:0.85 blue:1.0 alpha:0.55].CGColor;
    qb.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    [qb setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [qb setTitle:qTitles[qi] forState:UIControlStateNormal];
    [qb addTarget:self action:qActions[qi] forControlEvents:UIControlEventTouchUpInside];
    qb.hidden = YES;
    [self.homeAiEcoCard addSubview:qb];
  }

  UILabel *ecoH = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 214, 22)];
  ecoH.tag = 501;
  ecoH.font = [UIFont boldSystemFontOfSize:14.0];
  ecoH.adjustsFontSizeToFitWidth = YES;
  ecoH.minimumScaleFactor = 0.88;
  ecoH.textColor = [UIColor colorWithRed:.35 green:.95 blue:.50 alpha:1];
  ecoH.text = @"🌱 AI ECO COACH  •  ♻️ +14 Wh";
  [self.homeAiEcoCard addSubview:ecoH];

  UILabel *ecoS = [[UILabel alloc] initWithFrame:CGRectMake(10, 29, 214, 25)];
  ecoS.tag = 502;
  ecoS.font = [UIFont boldSystemFontOfSize:16.0];
  ecoS.adjustsFontSizeToFitWidth = YES;
  ecoS.minimumScaleFactor = 0.88;
  ecoS.textColor = [UIColor whiteColor];
  ecoS.text = @"ECO 92 / 100  [ GRADE A+ ]";
  [self.homeAiEcoCard addSubview:ecoS];

  UILabel *ecoD = [[UILabel alloc] initWithFrame:CGRectMake(10, 54, 214, 118)];
  ecoD.tag = 503;
  ecoD.numberOfLines = 4;
  ecoD.font = [UIFont boldSystemFontOfSize:14.0];
  ecoD.adjustsFontSizeToFitWidth = YES;
  ecoD.minimumScaleFactor = 0.88;
  ecoD.textColor = [UIColor whiteColor];
  ecoD.text = @"• HYBRID SYSTEM: 100% READY\n• THROTTLE: นุ่มนวล ประหยัดสูงสุด\n• REGEN BRAKING: ชาร์จไฟดีเยี่ยม\n• ECB BRAKE: แรงดันเบรกปกติ";
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
  tRow1.adjustsFontSizeToFitWidth = YES;
  tRow1.minimumScaleFactor = 0.88;
  tRow1.textColor = [UIColor whiteColor];
  tRow1.text = @"🌡️ ENGINE COOLANT : 88 °C\n     น้ำหล่อเย็นเครื่องยนต์ (ปกติ)";
  [self.homeThermalsCard addSubview:tRow1];

  UILabel *tRow2 = [[UILabel alloc] initWithFrame:CGRectMake(10, 66, 214, 52)];
  tRow2.tag = 602;
  tRow2.numberOfLines = 2;
  tRow2.font = [UIFont boldSystemFontOfSize:14.0];
  tRow2.adjustsFontSizeToFitWidth = YES;
  tRow2.minimumScaleFactor = 0.88;
  tRow2.textColor = [UIColor colorWithRed:0.65 green:0.94 blue:1.0 alpha:1];
  tRow2.text = @"❄️ CABIN A/C : 24.5 °C\n     INVERTER : 42 °C (อินเวอร์เตอร์)";
  [self.homeThermalsCard addSubview:tRow2];

  UILabel *tRow3 = [[UILabel alloc] initWithFrame:CGRectMake(10, 124, 214, 52)];
  tRow3.tag = 603;
  tRow3.numberOfLines = 2;
  tRow3.font = [UIFont boldSystemFontOfSize:14.0];
  tRow3.adjustsFontSizeToFitWidth = YES;
  tRow3.minimumScaleFactor = 0.88;
  tRow3.textColor = [UIColor colorWithRed:.35 green:.96 blue:.52 alpha:1];
  tRow3.text = @"🔋 AUX 12V BATTERY : 13.84 V\n     แบตเตอรี่ 12V ชาร์จไฟปกติ";
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
  [self.driveEqBtn setTitle:@"🎚️ JBL EQ SOUND" forState:UIControlStateNormal];
  self.driveEqBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
  self.driveEqBtn.backgroundColor = [UIColor colorWithRed:.04 green:.10 blue:.16 alpha:.9];
  self.driveEqBtn.layer.cornerRadius = 8;
  self.driveEqBtn.layer.borderWidth = 1.0;
  self.driveEqBtn.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.4].CGColor;
  [self.driveEqBtn addTarget:self action:@selector(openDriveEQ) forControlEvents:UIControlEventTouchUpInside];
  self.driveEqBtn.hidden = YES;
  [self.view addSubview:self.driveEqBtn];

  self.driveExitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  [self.driveExitBtn setTitle:@"🏠 EXIT TO HOME" forState:UIControlStateNormal];
  self.driveExitBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
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
 self.sourceBadge=[[UILabel alloc]init];self.sourceBadge.font=[UIFont boldSystemFontOfSize:10];self.sourceBadge.textAlignment=NSTextAlignmentCenter;self.sourceBadge.layer.cornerRadius=4;self.sourceBadge.clipsToBounds=YES;self.sourceBadge.textColor=[UIColor whiteColor];self.sourceBadge.backgroundColor=[blue colorWithAlphaComponent:.28];self.sourceBadge.layer.borderWidth=1;self.sourceBadge.layer.borderColor=[blue colorWithAlphaComponent:.6].CGColor;self.sourceBadge.text=@"MUSIC";self.sourceBadge.userInteractionEnabled=YES;UITapGestureRecognizer *btap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openMusic)];[self.sourceBadge addGestureRecognizer:btap];[self.nowPanel addSubview:self.sourceBadge];
 self.artwork=[[UIImageView alloc]init];self.artwork.contentMode=UIViewContentModeScaleAspectFill;self.artwork.clipsToBounds=YES;self.artwork.layer.cornerRadius=4;self.artwork.userInteractionEnabled=YES;[self.artwork addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openMusic)]];[self.view addSubview:self.artwork];self.artPlaceholder=[self label:28 color:blue];self.artPlaceholder.text=@"♫";self.artPlaceholder.textAlignment=NSTextAlignmentCenter;self.artPlaceholder.userInteractionEnabled=YES;[self.artPlaceholder addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openMusic)]];
 self.trackTime=[self label:10 color:[UIColor colorWithWhite:.65 alpha:1]];self.trackTime.textAlignment=NSTextAlignmentRight;self.trackTime.adjustsFontSizeToFitWidth=YES;self.trackTime.text=@"--:-- / --:--";self.trackProgress=[[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];self.trackProgress.progressTintColor=blue;self.trackProgress.trackTintColor=[UIColor colorWithWhite:.18 alpha:1];self.trackProgress.userInteractionEnabled=NO;[self.view addSubview:self.trackProgress];
 self.artist=[self label:12 color:[UIColor lightGrayColor]];self.artist.adjustsFontSizeToFitWidth=YES;
 self.carStatus=[self label:13 color:[UIColor lightGrayColor]];self.carStatus.textAlignment=NSTextAlignmentCenter;self.carStatus.text=@"CAR DISCONNECTED";self.carStatus.font=[UIFont boldSystemFontOfSize:13];self.carStatus.userInteractionEnabled=YES;[self.carStatus addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(carStatusTapped)]];
 TRDMarqueeLabel *mqSong=[[TRDMarqueeLabel alloc]initWithFrame:CGRectZero];mqSong.font=[UIFont boldSystemFontOfSize:18];mqSong.textColor=[UIColor colorWithRed:1 green:.78 blue:.42 alpha:1];mqSong.textAlignment=NSTextAlignmentLeft;mqSong.backgroundColor=[UIColor clearColor];self.song=mqSong;[self.view addSubview:self.song];
 self.hint=[self label:15 color:[UIColor grayColor]];self.hint.textAlignment=NSTextAlignmentCenter;self.hint.text=@"Tap anywhere to return";self.hint.hidden=YES;
 self.clockHud=[[UIView alloc]init];self.clockHud.backgroundColor=[UIColor colorWithRed:.05 green:.05 blue:.06 alpha:.94];self.clockHud.layer.cornerRadius=8;self.clockHud.layer.borderWidth=1;self.clockHud.layer.borderColor=[blue colorWithAlphaComponent:.38].CGColor;self.clockHud.userInteractionEnabled=NO;self.clockHud.hidden=YES;[self.view addSubview:self.clockHud];UIView *hudAccent=[[UIView alloc]initWithFrame:CGRectMake(0,16,4,76)];hudAccent.tag=401;hudAccent.backgroundColor=blue;[self.clockHud addSubview:hudAccent];UILabel *hudSpeed=[[UILabel alloc]initWithFrame:CGRectMake(16,8,168,70)];hudSpeed.tag=402;hudSpeed.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:72]?:[UIFont boldSystemFontOfSize:72];hudSpeed.textColor=[UIColor whiteColor];hudSpeed.textAlignment=NSTextAlignmentCenter;hudSpeed.adjustsFontSizeToFitWidth=YES;hudSpeed.text=@"--";[self.clockHud addSubview:hudSpeed];UILabel *hudUnit=[[UILabel alloc]initWithFrame:CGRectMake(16,76,168,22)];hudUnit.tag=403;hudUnit.font=[UIFont boldSystemFontOfSize:13];hudUnit.textColor=blue;hudUnit.textAlignment=NSTextAlignmentCenter;hudUnit.text=@"km/h  •  GPS HUD";[self.clockHud addSubview:hudUnit];UIView *hudDiv=[[UIView alloc]initWithFrame:CGRectMake(196,18,1,72)];hudDiv.tag=404;hudDiv.backgroundColor=[UIColor colorWithWhite:.18 alpha:1];[self.clockHud addSubview:hudDiv];UILabel *hudGps=[[UILabel alloc]initWithFrame:CGRectMake(214,16,230,22)];hudGps.tag=405;hudGps.font=[UIFont boldSystemFontOfSize:13];hudGps.textColor=[UIColor colorWithWhite:.76 alpha:1];hudGps.adjustsFontSizeToFitWidth=YES;hudGps.text=@"WAITING FOR GPS";[self.clockHud addSubview:hudGps];UILabel *hudAcc=[[UILabel alloc]initWithFrame:CGRectMake(214,43,230,20)];hudAcc.tag=406;hudAcc.font=[UIFont systemFontOfSize:12];hudAcc.textColor=[UIColor colorWithWhite:.55 alpha:1];hudAcc.adjustsFontSizeToFitWidth=YES;hudAcc.text=@"SIGNAL  •  SEARCHING SATELLITES";[self.clockHud addSubview:hudAcc];UILabel *hudTrip=[[UILabel alloc]initWithFrame:CGRectMake(214,68,230,22)];hudTrip.tag=407;hudTrip.font=[UIFont boldSystemFontOfSize:12];hudTrip.textColor=blue;hudTrip.adjustsFontSizeToFitWidth=YES;hudTrip.text=@"TRIP  AUTO  •  WAITING FOR MOVEMENT";[self.clockHud addSubview:hudTrip];
 self.clockFormat=[NSDateFormatter new];self.clockFormat.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];self.clockFormat.dateFormat=@"HH:mm";self.dateFormat=[NSDateFormatter new];self.dateFormat.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];self.dateFormat.dateFormat=@"EEEE, d MMMM yyyy";
 self.cards=[NSMutableArray array];NSArray *names=@[@"YouTube",@"audioNINJA",@"Maps",@"Camera",@"Settings",@"Full Clock"];
 for(int i=0;i<6;i++){UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=i+1;b.backgroundColor=[UIColor colorWithRed:.065 green:.065 blue:.075 alpha:1];b.layer.cornerRadius=7;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithRed:.25 green:.12 blue:.14 alpha:1].CGColor;UILabel *title=[UILabel new];title.tag=100;title.text=names[i];title.font=[UIFont boldSystemFontOfSize:24];title.textColor=i==0?blue:[UIColor whiteColor];[b addSubview:title];DashIcon *icon=[[DashIcon alloc]init];icon.kind=i+1;icon.tag=104;icon.backgroundColor=[UIColor clearColor];icon.userInteractionEnabled=NO;[b addSubview:icon];b.accessibilityLabel=names[i];UIView *accent=[[UIView alloc]init];accent.tag=102;accent.backgroundColor=blue;accent.userInteractionEnabled=NO;[b addSubview:accent];title.userInteractionEnabled=NO;b.clipsToBounds=YES;[b addTarget:self action:@selector(navTouchDown:forEvent:) forControlEvents:UIControlEventTouchDown];[b addTarget:self action:@selector(cancelNavigationTouch:forEvent:) forControlEvents:(UIControlEventTouchCancel|UIControlEventTouchUpOutside|UIControlEventTouchDragExit)];[b addTarget:self action:@selector(card:forEvent:) forControlEvents:UIControlEventTouchUpInside];[self.cards addObject:b];[self.view addSubview:b];}
 self.controls=[UIView new];[self.view addSubview:self.controls];NSArray *commands=@[@"Previous",@"Play / Pause",@"Next",@"Equalizer"];for(int i=0;i<4;i++){UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.tag=20+i;b.backgroundColor=[UIColor colorWithRed:.11 green:.055 blue:.065 alpha:1];b.layer.cornerRadius=7;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithRed:.35 green:.10 blue:.13 alpha:1].CGColor;b.accessibilityLabel=commands[i];if(i<3){DashIcon *icon=[[DashIcon alloc]init];icon.kind=7+i;icon.tag=105;icon.backgroundColor=[UIColor clearColor];icon.userInteractionEnabled=NO;[b addSubview:icon];}else [b setTitle:commands[i] forState:UIControlStateNormal];[b setTitleColor:blue forState:UIControlStateNormal];b.titleLabel.font=[UIFont boldSystemFontOfSize:22];[b addTarget:self action:@selector(media:) forControlEvents:UIControlEventTouchUpInside];[self.controls addSubview:b];}
 self.navigation=[UIView new];self.navigation.backgroundColor=[UIColor colorWithWhite:.035 alpha:1];self.navigation.layer.borderWidth=1;self.navigation.layer.borderColor=[UIColor colorWithWhite:.16 alpha:1].CGColor;[self.view addSubview:self.navigation];NSMutableArray *nav=[NSMutableArray array];NSArray *navNames=@[@"HOME",@"CARPLAY",@"MAPS",@"YOUTUBE",@"audioNINJA",@"CAMERA",@"SETTINGS"];NSInteger kinds[]={10,15,3,1,2,4,5};NSInteger tags[]={60,66,62,67,61,65,68};for(int i=0;i<7;i++){UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];b.tag=tags[i];b.clipsToBounds=YES;b.accessibilityLabel=navNames[i];b.layer.cornerRadius=8;DashIcon *icon=[DashIcon new];icon.kind=kinds[i];icon.tag=201;icon.backgroundColor=[UIColor clearColor];icon.userInteractionEnabled=NO;[b addSubview:icon];UILabel *text=[UILabel new];text.tag=202;text.text=navNames[i];text.textColor=[UIColor lightGrayColor];text.font=[UIFont boldSystemFontOfSize:13];text.userInteractionEnabled=NO;[b addSubview:text];UIView *line=[UIView new];line.tag=203;line.backgroundColor=blue;line.userInteractionEnabled=NO;[b addSubview:line];[b addTarget:self action:@selector(navTouchDown:forEvent:) forControlEvents:UIControlEventTouchDown];[b addTarget:self action:@selector(cancelNavigationTouch:forEvent:) forControlEvents:(UIControlEventTouchCancel|UIControlEventTouchUpOutside|UIControlEventTouchDragExit)];[b addTarget:self action:@selector(navigate:forEvent:) forControlEvents:UIControlEventTouchUpInside];[self.navigation addSubview:b];[nav addObject:b];}self.navButtons=nav;
 self.musicHeading=[self label:16 color:blue];self.musicHeading.text=@"NOW PLAYING";self.musicHeading.font=[UIFont boldSystemFontOfSize:16];self.musicHeading.hidden=YES;self.browseMusic=[UIButton buttonWithType:UIButtonTypeCustom];[self.browseMusic setTitle:@"Browse music" forState:UIControlStateNormal];self.browseMusic.titleLabel.font=[UIFont boldSystemFontOfSize:16];self.browseMusic.backgroundColor=[UIColor colorWithWhite:.09 alpha:1];self.browseMusic.layer.cornerRadius=7;self.browseMusic.layer.borderWidth=1;self.browseMusic.layer.borderColor=[UIColor colorWithWhite:.25 alpha:1].CGColor;[self.browseMusic addTarget:self action:@selector(showMusicSources:) forControlEvents:UIControlEventTouchUpInside];self.browseMusic.hidden=YES;[self.view addSubview:self.browseMusic];[self.nowPanel addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(openMusic)]];
 self.tripView=[TRDTripView new];self.tripView.hidden=YES;[self.view addSubview:self.tripView];[self.tripView.run addTarget:self action:@selector(toggleTrip) forControlEvents:UIControlEventTouchUpInside];[self.tripView.reset addTarget:self action:@selector(resetTripMenu) forControlEvents:UIControlEventTouchUpInside];[self.tripView.close addTarget:self action:@selector(homePage) forControlEvents:UIControlEventTouchUpInside];self.driveTripButton=[UIButton buttonWithType:UIButtonTypeCustom];self.driveTripButton.titleLabel.font=[UIFont boldSystemFontOfSize:14];self.driveTripButton.titleLabel.adjustsFontSizeToFitWidth=YES;self.driveTripButton.titleLabel.minimumScaleFactor=.8;self.driveTripButton.backgroundColor=[UIColor colorWithWhite:.055 alpha:1];self.driveTripButton.layer.cornerRadius=8;self.driveTripButton.layer.borderWidth=1;self.driveTripButton.layer.borderColor=[UIColor colorWithWhite:.2 alpha:1].CGColor;self.driveTripButton.accessibilityLabel=@"Open GPS trip summary";UIGraphicsBeginImageContextWithOptions(CGSizeMake(24,24),NO,0);[[UIColor whiteColor]setStroke];UIBezierPath *pin=[UIBezierPath bezierPath];pin.lineWidth=1.8;[pin moveToPoint:CGPointMake(12,22)];[pin addCurveToPoint:CGPointMake(4,9) controlPoint1:CGPointMake(10,18) controlPoint2:CGPointMake(4,13)];[pin addArcWithCenter:CGPointMake(12,9) radius:8 startAngle:M_PI endAngle:0 clockwise:YES];[pin addCurveToPoint:CGPointMake(12,22) controlPoint1:CGPointMake(20,13) controlPoint2:CGPointMake(14,18)];[pin stroke];UIBezierPath *pinCenter=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9,6,6,6)];pinCenter.lineWidth=1.6;[pinCenter stroke];UIImage *tripIcon=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();[self.driveTripButton setImage:[tripIcon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];self.driveTripButton.imageEdgeInsets=UIEdgeInsetsMake(0,-8,0,0);self.driveTripButton.titleEdgeInsets=UIEdgeInsetsMake(0,5,0,0);[self.driveTripButton addTarget:self action:@selector(openTrip) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveTripButton];
 self.driveCameraButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.driveCameraButton setTitle:@"CAMERA" forState:0];self.driveCameraButton.titleLabel.font=[UIFont boldSystemFontOfSize:22];self.driveCameraButton.backgroundColor=[TRDAccent()colorWithAlphaComponent:.20];self.driveCameraButton.layer.cornerRadius=8;self.driveCameraButton.layer.borderWidth=1.5;self.driveCameraButton.layer.borderColor=[TRDAccent()colorWithAlphaComponent:.8].CGColor;self.driveCameraButton.accessibilityLabel=@"Open live camera";self.driveCameraButton.accessibilityHint=@"View blind spots and follow the main camera";[self.driveCameraButton addTarget:self action:@selector(openCamera) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.driveCameraButton];
 self.tripButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.tripButton setTitle:@"TRIP / GPS ›" forState:0];self.tripButton.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.tripButton setTitleColor:TRDAccent() forState:0];self.tripButton.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.tripButton.layer.cornerRadius=6;[self.tripButton addTarget:self action:@selector(openTrip) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.tripButton];
 self.radioButton=[UIButton buttonWithType:UIButtonTypeCustom];[self.radioButton setTitle:@"📻 RADIO" forState:0];self.radioButton.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.radioButton setTitleColor:TRDAccent() forState:0];self.radioButton.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.radioButton.layer.cornerRadius=6;self.radioButton.layer.borderWidth=1;self.radioButton.layer.borderColor=[TRDAccent() colorWithAlphaComponent:.4].CGColor;[self.radioButton addTarget:self action:@selector(openRadioStationsMenu) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.radioButton];
  self.offlineMusicBtn=[UIButton buttonWithType:UIButtonTypeCustom];[self.offlineMusicBtn setTitle:@"💾 OFFLINE" forState:0];self.offlineMusicBtn.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.offlineMusicBtn setTitleColor:TRDAccent() forState:0];self.offlineMusicBtn.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.offlineMusicBtn.layer.cornerRadius=6;self.offlineMusicBtn.layer.borderWidth=1;self.offlineMusicBtn.layer.borderColor=[TRDAccent() colorWithAlphaComponent:.4].CGColor;[self.offlineMusicBtn addTarget:self action:@selector(openOfflineMusicMenu) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.offlineMusicBtn];
  self.searchMusicBtn=[UIButton buttonWithType:UIButtonTypeCustom];[self.searchMusicBtn setTitle:@"🔍 SEARCH" forState:0];self.searchMusicBtn.titleLabel.font=[UIFont boldSystemFontOfSize:13];[self.searchMusicBtn setTitleColor:TRDAccent() forState:0];self.searchMusicBtn.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];self.searchMusicBtn.layer.cornerRadius=6;self.searchMusicBtn.layer.borderWidth=1;self.searchMusicBtn.layer.borderColor=[TRDAccent() colorWithAlphaComponent:.4].CGColor;[self.searchMusicBtn addTarget:self action:@selector(openSearchMusic) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.searchMusicBtn];
 self.miniPlayer=[TRDMini new];self.miniPlayer.hidden=YES;[self.miniPlayer.prev addTarget:self action:@selector(miniPrev) forControlEvents:UIControlEventTouchUpInside];[self.miniPlayer.play addTarget:self action:@selector(miniPlay) forControlEvents:UIControlEventTouchUpInside];[self.miniPlayer.next addTarget:self action:@selector(miniNext) forControlEvents:UIControlEventTouchUpInside];[self.miniPlayer.open addTarget:self action:@selector(miniOpen) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.miniPlayer];UILongPressGestureRecognizer *homeHold=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(homeHold:)];homeHold.minimumPressDuration=.55;[self.navButtons[0]addGestureRecognizer:homeHold];
 self.mapContainer=[[UIView alloc]init];self.mapContainer.backgroundColor=[UIColor colorWithRed:.06 green:.06 blue:.07 alpha:1];self.mapContainer.layer.cornerRadius=8;self.mapContainer.layer.borderWidth=1;self.mapContainer.layer.borderColor=[blue colorWithAlphaComponent:.35].CGColor;self.mapContainer.clipsToBounds=YES;self.mapContainer.hidden=YES;[self.view addSubview:self.mapContainer];

  // CarPlay Left Dock
  self.carplayDock=[[UIView alloc]init];self.carplayDock.backgroundColor=[UIColor colorWithRed:.06 green:.07 blue:.09 alpha:.96];self.carplayDock.layer.borderWidth=1;self.carplayDock.layer.borderColor=[UIColor colorWithWhite:.14 alpha:1].CGColor;self.carplayDock.userInteractionEnabled=YES;self.carplayDock.clipsToBounds=YES;self.carplayDock.hidden=YES;[self.view addSubview:self.carplayDock];
  self.carplayHomeBtn=[UIButton buttonWithType:UIButtonTypeCustom];self.carplayHomeBtn.backgroundColor=[UIColor colorWithRed:.12 green:.15 blue:.22 alpha:.85];self.carplayHomeBtn.layer.cornerRadius=16;self.carplayHomeBtn.layer.borderWidth=1.2;self.carplayHomeBtn.layer.borderColor=[UIColor colorWithWhite:1.0 alpha:.24].CGColor;self.carplayHomeBtn.showsTouchWhenHighlighted=YES;
  UIImageView *gridI=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"cp_dock_home.png"]];gridI.frame=CGRectMake(11,11,32,32);gridI.contentMode=UIViewContentModeScaleAspectFit;gridI.userInteractionEnabled=NO;[self.carplayHomeBtn addSubview:gridI];
  self.carplayHomeBtn.tag=9300;[self.carplayHomeBtn addTarget:self action:@selector(navTouchDown:forEvent:) forControlEvents:UIControlEventTouchDown];[self.carplayHomeBtn addTarget:self action:@selector(cancelNavigationTouch:forEvent:) forControlEvents:(UIControlEventTouchCancel|UIControlEventTouchUpOutside|UIControlEventTouchDragExit)];[self.carplayHomeBtn addTarget:self action:@selector(carplayHomeTouch:forEvent:) forControlEvents:UIControlEventTouchUpInside];[self.carplayDock addSubview:self.carplayHomeBtn];

  self.carplayDockButtons=[NSMutableArray array];
  NSInteger dKinds[]={3,2,1,4,11};
  NSArray *dockIcons=@[@"cp_icon_maps.png",@"cp_icon_music.png",@"cp_icon_youtube.png",@"cp_icon_camera.png",@"cp_icon_eq.png"];
  for(int i=0;i<5;i++){UIButton *db=[UIButton buttonWithType:UIButtonTypeCustom];db.layer.cornerRadius=14;db.backgroundColor=[UIColor colorWithRed:.10 green:.12 blue:.18 alpha:.7];db.layer.borderWidth=1;db.layer.borderColor=[UIColor colorWithWhite:1.0 alpha:.18].CGColor;db.clipsToBounds=YES;db.showsTouchWhenHighlighted=YES;UIImageView *ic=[[UIImageView alloc]initWithImage:[UIImage imageNamed:dockIcons[i]]];ic.frame=CGRectMake(6,6,42,42);ic.contentMode=UIViewContentModeScaleAspectFit;ic.layer.cornerRadius=10;ic.clipsToBounds=YES;ic.userInteractionEnabled=NO;[db addSubview:ic];db.accessibilityLabel=@[@"Maps",@"Music",@"YouTube",@"Camera",@"Sound equalizer"][i];db.tag=9100+i;[db addTarget:self action:@selector(navTouchDown:forEvent:) forControlEvents:UIControlEventTouchDown];[db addTarget:self action:@selector(cancelNavigationTouch:forEvent:) forControlEvents:(UIControlEventTouchCancel|UIControlEventTouchUpOutside|UIControlEventTouchDragExit)];[db addTarget:self action:@selector(carplayDockTouch:forEvent:) forControlEvents:UIControlEventTouchUpInside];[self.carplayDock addSubview:db];[self.carplayDockButtons addObject:db];}

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
  [self.carplayMediaWidget.btnChooseMusic addTarget:self action:@selector(showMusicSources:) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.carplayMediaWidget];

  self.carplayTelemetryWidget = [[TRDCarPlayTelemetryWidget alloc] initWithFrame:CGRectZero];
  self.carplayTelemetryWidget.hidden = YES;
  [self.carplayTelemetryWidget.rearCamBtn addTarget:self action:@selector(openCamera) forControlEvents:UIControlEventTouchUpInside];
  [self.carplayTelemetryWidget.exitBtn addTarget:self action:@selector(homePage) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:self.carplayTelemetryWidget];

  self.carplayGridButtons=[NSMutableArray array];
  NSArray *gridTitles=@[@"Music",@"Maps",@"YouTube",@"Camera",@"EQ Sound",@"Trip Log",@"Settings",@"TRD Dash"];
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
    gb.tag=9200+i;[gb addTarget:self action:@selector(navTouchDown:forEvent:) forControlEvents:UIControlEventTouchDown];[gb addTarget:self action:@selector(cancelNavigationTouch:forEvent:) forControlEvents:(UIControlEventTouchCancel|UIControlEventTouchUpOutside|UIControlEventTouchDragExit)];[gb addTarget:self action:@selector(carplayGridTouch:forEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.carplayAppGrid addSubview:gb];
    [self.carplayGridButtons addObject:gb];
  }

  self.swR=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(homePage)];self.swR.direction=UISwipeGestureRecognizerDirectionRight;self.swR.delegate=self;self.swR.cancelsTouchesInView=NO;self.swR.delaysTouchesBegan=NO;[self.view addGestureRecognizer:self.swR];
  UISwipeGestureRecognizer *dockSwR=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(homePage)];dockSwR.direction=UISwipeGestureRecognizerDirectionRight;dockSwR.delegate=self;dockSwR.cancelsTouchesInView=NO;dockSwR.delaysTouchesBegan=NO;[self.carplayDock addGestureRecognizer:dockSwR];
  UISwipeGestureRecognizer *gridSwR=[[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(homePage)];gridSwR.direction=UISwipeGestureRecognizerDirectionRight;gridSwR.delegate=self;gridSwR.cancelsTouchesInView=NO;gridSwR.delaysTouchesBegan=NO;[self.carplayAppGrid addGestureRecognizer:gridSwR];
  self.edgeR=[[UIScreenEdgePanGestureRecognizer alloc]initWithTarget:self action:@selector(handleEdgePan:)];self.edgeR.edges=UIRectEdgeLeft;self.edgeR.delegate=self;self.edgeR.cancelsTouchesInView=NO;self.edgeR.delaysTouchesBegan=NO;[self.view addGestureRecognizer:self.edgeR];
 self.returnTap=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(leaveClock)];self.returnTap.enabled=NO;self.returnTap.cancelsTouchesInView=NO;self.returnTap.delegate=self;[self.view addGestureRecognizer:self.returnTap];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(ensureActiveRunLoopHealth) name:UIApplicationDidBecomeActiveNotification object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(ensureActiveRunLoopHealth) name:UIApplicationWillEnterForegroundNotification object:nil];[UIDevice currentDevice].batteryMonitoringEnabled=YES;UIDeviceBatteryState initBat=[UIDevice currentDevice].batteryState;self.isCarSessionActive=(initBat==UIDeviceBatteryStateCharging||initBat==UIDeviceBatteryStateFull);[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryStateDidChangeNotification object:nil];dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager",RTLD_LAZY);Class manager=NSClassFromString(@"BluetoothManager");if([manager respondsToSelector:@selector(sharedInstance)])self.bluetooth=[manager performSelector:@selector(sharedInstance)];dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_LAZY);[self update];NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];BOOL skipWelcome=[ud boolForKey:@"TRDSkipNextLaunchWelcome"];BOOL sessionWelcomeShown=[ud boolForKey:@"TRDWelcomeShownForSession"];NSTimeInterval lastActive=[ud doubleForKey:@"TRDLastActiveTimestamp"];NSTimeInterval nowTs=[[NSDate date] timeIntervalSince1970];BOOL recentSession=(lastActive>0&&(nowTs-lastActive)<1800);if(skipWelcome){[ud setBool:NO forKey:@"TRDSkipNextLaunchWelcome"];[ud synchronize];self.didShowWelcome=YES;}else if((self.isCarSessionActive&&sessionWelcomeShown)||recentSession){self.didShowWelcome=YES;}if(!self.didShowWelcome){self.didShowWelcome=YES;if(self.isCarSessionActive){[ud setBool:YES forKey:@"TRDWelcomeShownForSession"];}[ud setDouble:nowTs forKey:@"TRDLastActiveTimestamp"];[ud synchronize];[self showWelcome];}
  // Do NOT claim MPRemoteCommandCenter / NowPlaying at launch when audioNINJA/YouTube owns Bluetooth AVRCP!
  // Only claim remote control when CarDash's own radioPlayer (Offline/Radio) is actively playing.
  [self setCarDashRemoteControlEnabled:NO];

  __weak typeof(self) weakGestureSelf = self;
  TRDFrontGestureEngine *ge = [TRDFrontGestureEngine sharedEngine];
  ge.onWaveNext = ^{
   Dashboard *d = weakGestureSelf;
   if(!d || d.isReverseActive || d.voiceListening) return;
   AudioServicesPlaySystemSound(1104);
   [d miniNext];
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    notify_post("com.codex.trd.music.play");
    TRDSendMediaRemoteExternal(0, nil);
   });
   [d showGestureToast:@"👋➡️ ปัดขวา: เพลงถัดไป ⏭️"];
  };
  ge.onWavePrev = ^{
   Dashboard *d = weakGestureSelf;
   if(!d || d.isReverseActive || d.voiceListening) return;
   AudioServicesPlaySystemSound(1104);
   [d miniPrev];
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    notify_post("com.codex.trd.music.play");
    TRDSendMediaRemoteExternal(0, nil);
   });
   [d showGestureToast:@"⬅️👋 ปัดซ้าย: เพลงก่อนหน้า ⏮️"];
  };
  ge.onPlayPause = ^{
   Dashboard *d = weakGestureSelf;
   if(!d || d.isReverseActive || d.voiceListening) return;
   BOOL wasPlaying = (d.mediaRate > 0.05) || [AVAudioSession sharedInstance].otherAudioPlaying || (d.radioPlayer && d.radioPlayer.rate > 0.05);
   AudioServicesPlaySystemSound(1104);
   if(d.radioPlayer){
    [d miniPlay];
   } else if([d isYouTubeMediaActive]){
    notify_post("com.codex.trd.youtube.toggle");
   } else if(wasPlaying){
    notify_post("com.codex.trd.music.pause");
    TRDSendMediaRemoteExternal(1, nil);
   } else {
    notify_post("com.codex.trd.music.play");
    TRDSendMediaRemoteExternal(0, nil);
   }
   [d showGestureToast:wasPlaying ? @"✋ หยุดพักเพลงชั่วคราว ⏸️" : @"✋ เล่นเพลงต่อทันที ▶️"];
  };
  // NEVER trigger Voice Search from front camera (Voice Search ONLY via dedicated 🎙️ button!)
  ge.onHoldVoiceSearch = nil;
  [ge startIfEnabled];
  // Zero-lux pitch-black night backup: 2-finger swipe Left/Right anywhere on Dashboard skips tracks!
  UISwipeGestureRecognizer *twoSwR = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(nightTwoFingerSwipe:)];
  twoSwR.direction = UISwipeGestureRecognizerDirectionRight;
  twoSwR.numberOfTouchesRequired = 2;
  [self.view addGestureRecognizer:twoSwR];
  UISwipeGestureRecognizer *twoSwL = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(nightTwoFingerSwipe:)];
  twoSwL.direction = UISwipeGestureRecognizerDirectionLeft;
  twoSwL.numberOfTouchesRequired = 2;
  [self.view addGestureRecognizer:twoSwL];
}
-(void)nightTwoFingerSwipe:(UISwipeGestureRecognizer *)g{
 if(self.isReverseActive || self.voiceListening) return;
 AudioServicesPlaySystemSound(1104);
 if(g.direction == UISwipeGestureRecognizerDirectionRight){
  [self miniNext];
  [self showGestureToast:@"✌️➡️ เพลงถัดไป ⏭️"];
 } else {
  [self miniPrev];
  [self showGestureToast:@"⬅️✌️ เพลงก่อนหน้า ⏮️"];
 }
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
  notify_post("com.codex.trd.music.play");
  TRDSendMediaRemoteExternal(0, nil);
 });
}
-(BOOL)prefersStatusBarHidden{return YES;}
-(void)rotateTo:(NSNumber *)value{[[UIDevice currentDevice]setValue:value forKey:@"orientation"];[UIViewController attemptRotationToDeviceOrientation];}
-(BOOL)shouldAutorotate{return YES;}
-(UIInterfaceOrientationMask)supportedInterfaceOrientations{return UIInterfaceOrientationMaskLandscape;}
static NSString *gTRDLastTouchInfo=@"none";
static NSTimeInterval gTRDFeatureBannerShownAt=0;
static NSUInteger gTRDUpdateTicks=0;
// The audio source owns Now Playing and Bluetooth remote commands.
-(void)ensureActiveRunLoopHealth{
 while([UIApplication sharedApplication].isIgnoringInteractionEvents)[[UIApplication sharedApplication] endIgnoringInteractionEvents];
 self.view.userInteractionEnabled=YES;
 self.view.window.userInteractionEnabled=YES;
 NSTimeInterval now=[NSProcessInfo processInfo].systemUptime;
 if(self.featureExplanationBanner && (self.featureExplanationBanner.alpha<0.05 || (gTRDFeatureBannerShownAt>0 && (now-gTRDFeatureBannerShownAt)>9.0)))[self hideFeatureExplanation];
 if(self.welcome && self.welcome.alpha<0.05)[self hideWelcome];
 if(self.tripSummaryCard && self.tripSummaryCard.alpha<0.05)[self hideTripSummary];
 if(self.lowFuelBanner && self.lowFuelBanner.alpha<0.05)[self dismissLowFuelBanner];
 if([UIApplication sharedApplication].applicationState==UIApplicationStateBackground && self.timer && [self.timer isValid])return;
 UIDeviceBatteryState bat=[UIDevice currentDevice].batteryState;
 [UIApplication sharedApplication].idleTimerDisabled=(bat==UIDeviceBatteryStateCharging||bat==UIDeviceBatteryStateFull);
 if(self.navGuardUntil > now + 2.0)self.navGuardUntil=now;
 if(!self.timer || ![self.timer isValid]){
  self.timer=[NSTimer timerWithTimeInterval:1 target:self selector:@selector(update) userInfo:nil repeats:YES];
  self.timer.tolerance=.1;
  [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
 }
 NSString *nowClock=self.clockFormat?[self.clockFormat stringFromDate:[NSDate date]]:nil;
 if(nowClock && self.clock.text && ![self.clock.text isEqualToString:nowClock])[self update];
}
-(void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];notify_post("com.codex.trd.network.internet");[self applyTheme];[self applyDisplaySchedule];[self becomeFirstResponder];if(self.welcome){[self.view bringSubviewToFront:self.welcome];}else if(!self.didShowWelcome){self.didShowWelcome=YES;[self showWelcome];}[self.audioBars start];[self ensureActiveRunLoopHealth];[self update];}
-(void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self hideWelcome];[self.audioBars stop];[self.driveCar stop];[self.timer invalidate];self.timer=nil;[self saveTrip];[UIApplication sharedApplication].idleTimerDisabled=NO;}

-(void)hideAllHomeWidgets:(BOOL)hide {
  if (hide) { UIView *cp910 = [self.view viewWithTag:910]; if (cp910) cp910.hidden = YES; }
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
  self.helpPill.hidden = hide;
  if (hide) self.homeCarLightBeams.hidden = YES;
  self.doorDiagramView.hidden = hide;
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
  self.miniPlayer.hidden = YES;
  self.trackProgress.hidden = hide;
  self.trackTime.hidden = hide;
  self.driveEQ.hidden = hide;
  self.searchMusicBtn.hidden = hide;
  self.offlineMusicBtn.hidden = YES;
  self.nowPanel.hidden = hide;
  UIView *pCard = [self.view viewWithTag:701]; if (pCard) pCard.hidden = hide;
  UIView *deltaL = [self.view viewWithTag:706]; if (deltaL) deltaL.hidden = hide;
  UIView *mCard = [self.view viewWithTag:707]; if (mCard) mCard.hidden = hide;
  UIView *tCard = [self.view viewWithTag:711]; if (tCard) tCard.hidden = hide;
  UIView *mH = [self.nowPanel viewWithTag:750]; if (mH) mH.hidden = hide;
  UIView *hTopPod = [self.view viewWithTag:790]; if (hTopPod) hTopPod.hidden = hide;
  UIView *hCenterTopCard = [self.view viewWithTag:791]; if (hCenterTopCard) hCenterTopCard.hidden = hide;
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
  UIView *cPod = [self.view viewWithTag:890]; if (cPod) cPod.hidden = hide;
  UIView *abPod = [self.view viewWithTag:895]; if (abPod) abPod.hidden = hide;
  UIView *lModeB = [self.view viewWithTag:905]; if (lModeB) lModeB.hidden = hide;
  UIView *lMaxL = [self.view viewWithTag:906]; if (lMaxL) lMaxL.hidden = hide;
}

-(void)quickResetABTrip{
  [self resetTripSlot:self.activeTripSlot];
  AudioServicesPlaySystemSound(1057);
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
  self.carplayMediaCard.hidden = YES;
  self.carplayTelemetryCard.hidden = YES;
  self.carplayAppGrid.hidden = !(self.carplayMode && self.carplayGridMode);

  if (self.carplayMode) {
    [self hideAllHomeWidgets:YES];
    [self hideAllDriveWidgets:YES];
    self.panel.hidden = YES;
    self.navigation.hidden = YES;
    self.statusStrip.hidden = YES;
    self.modeButton.hidden = YES;
    self.driveButton.hidden = YES;
    self.nightButton.hidden = YES;
    self.helpPill.hidden = YES;
    self.homeCarLightBeams.hidden = YES;
    self.heading.hidden = YES;
    self.owner.hidden = YES;
    self.clock.hidden = YES;
    self.date.hidden = YES;
    self.nowPanel.hidden = YES;
    self.driveEQ.hidden = YES;
    self.miniPlayer.hidden = YES;
    self.tripButton.hidden = YES;

    // Hide raw legacy media controls from self.view to avoid stray overlays
    self.artwork.hidden = YES;
    self.artPlaceholder.hidden = YES;
    self.song.hidden = YES;
    self.artist.hidden = YES;
    self.trackTime.hidden = YES;
    self.trackProgress.hidden = YES;
    self.controls.hidden = YES;

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
      self.mapContainer.layer.cornerRadius = 14;
      self.mapContainer.layer.borderWidth = 1.2;
      self.mapContainer.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
      self.mapContainer.clipsToBounds = YES;
      if (self.mapWebView && !CGRectEqualToRect(self.mapWebView.frame, self.mapContainer.bounds)) {
        self.mapWebView.frame = self.mapContainer.bounds;
        if (self.mapWebView.request && !self.mapWebView.loading) {
          [self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.map){window.map.invalidateSize(false);}"];
        }
      }
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
    if (self.voicePill) {
      self.voicePill.hidden = NO;
      self.voicePill.frame = CGRectMake(13, 374, 50, 50);
      self.voicePill.layer.cornerRadius = 25.0;
      self.voicePill.titleLabel.font = [UIFont boldSystemFontOfSize:22.0];
      [self.view bringSubviewToFront:self.voicePill];
    }
    if (self.settingsSheet) {
      self.settingsSheet.frame = self.view.bounds;
      [self.view bringSubviewToFront:self.settingsSheet];
    }
    return;
  }

  // Hide legacy/unused items
  self.carplayMediaWidget.hidden = YES;
  self.carplayTelemetryWidget.hidden = YES;
  self.nightButton.hidden = YES;
  self.modeButton.hidden = YES;
  self.driveButton.hidden = YES;
  self.statusStrip.hidden = YES;
  self.tripButton.hidden = YES;
  self.brakeStatusCard.hidden = YES;
  self.hybridSocCard.hidden = YES;
  for (UIView *cb in self.cards) cb.hidden = YES;


  if (self.tripMode) {
    [self hideAllHomeWidgets:YES];
    [self hideAllDriveWidgets:YES];
    self.mapContainer.hidden = YES;
    self.carplayDock.hidden = YES;
    self.carplayMediaWidget.hidden = YES;
    self.carplayTelemetryWidget.hidden = YES;
    self.carplayAppGrid.hidden = YES;
    self.navigation.hidden = NO;

    self.tripView.hidden = NO;
    self.tripView.frame = CGRectMake(18, 18, w - 36, fullH - 108);
    [self.view bringSubviewToFront:self.tripView];
    [self.view bringSubviewToFront:self.navigation];
    if (self.settingsSheet) {
      self.settingsSheet.frame = self.view.bounds;
      [self.view bringSubviewToFront:self.settingsSheet];
    }
    return;
  }
  self.tripView.hidden = YES;

  if (self.mapMode) {
    self.panel.hidden = YES;
    [self hideAllHomeWidgets:YES];
    [self hideAllDriveWidgets:YES];
    self.carplayDock.hidden = YES;
    self.carplayMediaWidget.hidden = YES;
    self.carplayTelemetryWidget.hidden = YES;
    self.carplayAppGrid.hidden = YES;
    self.statusStrip.hidden = YES;
    self.modeButton.hidden = YES;
    self.driveButton.hidden = YES;
    self.nightButton.hidden = YES;
    self.helpPill.hidden = YES;
    self.homeCarLightBeams.hidden = YES;
    self.date.hidden = YES;
    self.clock.hidden = YES;
    self.nowPanel.hidden = YES;
    self.driveEQ.hidden = YES;
    self.miniPlayer.hidden = YES;
    self.tripButton.hidden = YES;
    self.artwork.hidden = YES;
    self.artPlaceholder.hidden = YES;
    self.song.hidden = YES;
    self.artist.hidden = YES;
    self.trackTime.hidden = YES;
    self.trackProgress.hidden = YES;
    self.controls.hidden = YES;
    self.navigation.hidden = NO;

    // Top Bar (Width: 1024, Height: 50)
    UIColor *accent = TRDAccent();
    self.heading.hidden = NO;
    self.heading.frame = CGRectMake(16, 8, 390, 22);
    self.heading.font = [UIFont systemFontOfSize:17.5 weight:UIFontWeightHeavy];
    self.heading.textColor = accent;
    self.heading.text = @"PRIUS TRD  •  MAP NAVIGATION";
    self.owner.hidden = NO;
    self.owner.frame = CGRectMake(16, 29, 390, 16);
    self.owner.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    self.owner.textColor = [UIColor colorWithRed:0.68 green:0.90 blue:1.0 alpha:0.90];
    self.owner.text = @"GPS LIVE NAVIGATION • OBD2 TELEMETRY";

    CGFloat curRx = w - 14;
    CGFloat barTop = 10, pillH = 32;
    curRx -= 118;
    self.settingsPill.hidden = NO;
    self.settingsPill.frame = CGRectMake(curRx, barTop, 118, pillH);
    self.settingsPill.layer.cornerRadius = 10;
    [self.settingsPill setTitle:@"⚙️ SETTINGS" forState:UIControlStateNormal];

    curRx -= 64;
    self.voicePill.hidden = NO;
    self.voicePill.frame = CGRectMake(curRx, barTop - 2, 58, pillH + 4);
    self.voicePill.layer.cornerRadius = 12;
    self.voicePill.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    [self.view bringSubviewToFront:self.voicePill];

    curRx -= 118;
    self.thaiVoicePill.hidden = NO;
    self.thaiVoicePill.frame = CGRectMake(curRx, barTop, 110, pillH);
    self.thaiVoicePill.layer.cornerRadius = 10;
    [self updateDrive12VPill];

    curRx -= 70;
    self.topClockLabel.hidden = NO;
    self.topClockLabel.frame = CGRectMake(curRx, barTop, 64, pillH);
    self.topClockLabel.font = [UIFont monospacedDigitSystemFontOfSize:14.0 weight:UIFontWeightBold];
    self.topClockLabel.layer.cornerRadius = 10;
    self.topClockLabel.text = [self.clockFormat stringFromDate:[NSDate date]];

    curRx -= 104;
    self.dayNightPill.hidden = NO;
    self.dayNightPill.frame = CGRectMake(curRx, barTop, 96, pillH);
    self.dayNightPill.layer.cornerRadius = 10;
    [self.dayNightPill setTitle:self.nightMode?@"🌙 NIGHT":@"☀️ DAY" forState:UIControlStateNormal];

    curRx -= 154;
    self.obdStatusPill.hidden = NO;
    self.obdStatusPill.frame = CGRectMake(curRx, barTop, 146, pillH);
    self.obdStatusPill.layer.cornerRadius = 10;

    // Map Container (Takes full width and height between Top Bar and Bottom Dock)
    CGFloat mapTop = 52;
    CGFloat navH = 68;
    CGFloat mapH = fullH - mapTop - navH - 10;
    self.mapContainer.hidden = NO;
    self.mapContainer.frame = CGRectMake(14, mapTop, w - 28, mapH);
    self.mapContainer.layer.cornerRadius = 16;
    self.mapContainer.layer.borderWidth = 1.2;
    self.mapContainer.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
    self.mapContainer.clipsToBounds = YES;
    if (self.mapWebView && !CGRectEqualToRect(self.mapWebView.frame, self.mapContainer.bounds)) {
      self.mapWebView.frame = self.mapContainer.bounds;
      if (self.mapWebView.request && !self.mapWebView.loading) {
        [self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.map){window.map.invalidateSize(false);}"];
      }
    }

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

    [self.view bringSubviewToFront:self.heading];
    [self.view bringSubviewToFront:self.owner];
    [self.view bringSubviewToFront:self.obdStatusPill];
    [self.view bringSubviewToFront:self.dayNightPill];
    [self.view bringSubviewToFront:self.topClockLabel];
    [self.view bringSubviewToFront:self.thaiVoicePill];
    [self.view bringSubviewToFront:self.settingsPill];
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
    // DRIVE MODE (Balanced 3-Column Cockpit with TRIP A / TRIP B / TRIP C)
    // =========================================================================
    self.panel.hidden = NO;
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
    self.heading.frame = CGRectMake(18, barY, 190, 24);
    self.heading.font = [UIFont boldSystemFontOfSize:15.5];
    self.heading.textColor = [UIColor colorWithRed:0.0 green:0.90 blue:1.0 alpha:1];
    self.heading.text = @"PRIUS TRD • DRIVE";

    self.owner.hidden = YES;

    // Live Connectivity Pill (Wi-Fi/Hotspot + Bluetooth/Speaker Audio Output)
    UIButton *connPill = (UIButton *)[self.view viewWithTag:910];
    if (!connPill) {
      connPill = [UIButton buttonWithType:UIButtonTypeCustom];
      connPill.tag = 910;
      connPill.titleLabel.font = [UIFont boldSystemFontOfSize:11.5];
      connPill.titleLabel.adjustsFontSizeToFitWidth = YES;
      connPill.titleLabel.minimumScaleFactor = 0.78;
      connPill.contentEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
      connPill.layer.cornerRadius = 10;
      connPill.layer.borderWidth = 1.0;
      connPill.backgroundColor = [UIColor colorWithRed:0.04 green:0.08 blue:0.13 alpha:0.95];
      [connPill addTarget:self action:@selector(audioOutputSettings) forControlEvents:UIControlEventTouchUpInside];
      [self.view addSubview:connPill];
    }
    connPill.hidden = NO;
    connPill.frame = CGRectMake(212, barY - 5, 216, 34);
    [self.view bringSubviewToFront:connPill];

    // Center Clock in Header (Balanced)
    self.clock.hidden = NO;
    self.clock.frame = CGRectMake(434, barY, 78, 24);
    self.clock.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:20] ?: [UIFont boldSystemFontOfSize:20];
    self.clock.textColor = [UIColor whiteColor];
    self.clock.textAlignment = NSTextAlignmentCenter;
    self.date.hidden = YES;

    // Right Pills: Help, Day/Night, OBD2, Live 12V
    CGFloat curRx = w - 18;
    CGFloat pillH = 34;
    curRx -= 118;
    self.thaiVoicePill.hidden = NO;
    self.thaiVoicePill.frame = CGRectMake(curRx, barY - 5, 118, pillH);
    [self updateDrive12VPill];

    curRx -= 136;
    self.obdStatusPill.hidden = NO;
    self.obdStatusPill.frame = CGRectMake(curRx, barY - 5, 130, pillH);
    BOOL obdLiveNow = [TRDOBDClient sharedClient].isConnected;
    UIColor *obdTint = obdLiveNow ? [UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] : [UIColor colorWithRed:1.0 green:0.78 blue:0.30 alpha:1.0];
    [self.obdStatusPill setImage:TRDAutoVectorIcon(1, 16.0, obdTint) forState:UIControlStateNormal];
    self.obdStatusPill.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 6);
    [self.obdStatusPill setTitle:(obdLiveNow ? @"OBD2 LIVE" : @"OBD2 SCAN") forState:UIControlStateNormal];
    [self.obdStatusPill setTitleColor:obdTint forState:UIControlStateNormal];

    curRx -= 100;
    self.dayNightPill.hidden = NO;
    self.dayNightPill.frame = CGRectMake(curRx, barY - 5, 94, pillH);
    [self.dayNightPill setTitle:self.nightMode?@"🌙 กลางคืน":@"☀️ กลางวัน" forState:UIControlStateNormal];

    curRx -= 72;
    self.helpPill.hidden = NO;
    self.helpPill.frame = CGRectMake(curRx, barY - 5, 66, pillH);

    curRx -= 64;
    self.voicePill.hidden = NO;
    self.voicePill.frame = CGRectMake(curRx, barY - 7, 58, pillH + 4);
    self.voicePill.layer.cornerRadius = 12;
    self.voicePill.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    [self.view bringSubviewToFront:self.voicePill];

    // Balanced 3-Column Layout: Left (264px), Center (432px), Right (272px)
    CGFloat leftX = 18, leftW = 264;
    CGFloat centerX = 294, centerW = 432;
    CGFloat rightX = 738, rightW = 268;
    CGFloat topY = 48, podH = 590;

    // 1. LEFT POD (Speedo + Vertical Shifter + Hybrid Power Meter)
    self.driveLeftCard.hidden = NO;
    self.driveLeftCard.frame = CGRectMake(leftX, topY, leftW, podH);
    self.driveLeftCard.layer.cornerRadius = 14;
    self.driveLeftCard.layer.borderWidth = 1.2;
    self.driveLeftCard.layer.borderColor = [UIColor colorWithWhite:0.20 alpha:1].CGColor;
    self.driveLeftCard.backgroundColor = [UIColor colorWithRed:0.03 green:0.05 blue:0.08 alpha:0.96];

    self.driveSpeedoDial.hidden = NO;
    self.driveSpeedoDial.frame = CGRectMake(leftX + 8, topY + 8, leftW - 16, 178);

    // Subtle divider 1 inside Left Pod
    UIView *lDiv1 = [self.driveLeftCard viewWithTag:901];
    if (!lDiv1) {
      lDiv1 = [[UIView alloc] init];
      lDiv1.tag = 901;
      lDiv1.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1];
      [self.driveLeftCard addSubview:lDiv1];
    }
    lDiv1.frame = CGRectMake(16, 192, leftW - 32, 1);

    self.driveShifter.hidden = NO;
    self.driveShifter.frame = CGRectMake(leftX + 186, topY + 198, 64, 144);

    self.gearBadge.hidden = NO;
    self.gearBadge.frame = CGRectMake(leftX + 14, topY + 200, 164, 42);
    UILabel *gbL = (UILabel *)[self.gearBadge viewWithTag:801];
    UILabel *gbW = (UILabel *)[self.gearBadge viewWithTag:802];
    if (gbL) gbL.frame = CGRectMake(6, 1, 36, 40);
    if (gbW) gbW.frame = CGRectMake(44, 2, 114, 38);

    UIButton *lModeB = (UIButton *)[self.view viewWithTag:905];
    if (!lModeB) {
      lModeB = [UIButton buttonWithType:UIButtonTypeCustom];
      lModeB.tag = 905;
      lModeB.layer.cornerRadius = 8;
      lModeB.layer.borderWidth = 1.1;
      lModeB.layer.borderColor = [UIColor colorWithRed:0.0 green:0.88 blue:0.65 alpha:0.55].CGColor;
      lModeB.backgroundColor = [UIColor colorWithRed:0.03 green:0.11 blue:0.14 alpha:0.95];
      lModeB.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
      [lModeB setTitleColor:[UIColor colorWithRed:0.25 green:1.0 blue:0.70 alpha:1.0] forState:UIControlStateNormal];
      [lModeB setTitle:@"🌱 ECO MODE" forState:UIControlStateNormal];
      [lModeB addTarget:self action:@selector(cycleDriveMode) forControlEvents:UIControlEventTouchUpInside];
      [self.view addSubview:lModeB];
    }
    lModeB.hidden = NO;
    lModeB.frame = CGRectMake(leftX + 14, topY + 250, 164, 42);

    UILabel *lMaxL = (UILabel *)[self.view viewWithTag:906];
    if (!lMaxL) {
      lMaxL = [[UILabel alloc] init];
      lMaxL.tag = 906;
      lMaxL.layer.cornerRadius = 8;
      lMaxL.layer.borderWidth = 1.0;
      lMaxL.layer.borderColor = [UIColor colorWithWhite:0.22 alpha:1.0].CGColor;
      lMaxL.backgroundColor = [UIColor colorWithRed:0.04 green:0.07 blue:0.11 alpha:0.95];
      lMaxL.clipsToBounds = YES;
      lMaxL.font = [UIFont boldSystemFontOfSize:12.0];
      lMaxL.adjustsFontSizeToFitWidth = YES;
      lMaxL.minimumScaleFactor = 0.80;
      lMaxL.textAlignment = NSTextAlignmentCenter;
      lMaxL.textColor = [UIColor colorWithRed:0.55 green:0.92 blue:1.0 alpha:1.0];
      lMaxL.text = @"🚀 MAX: 0 km/h • GPS";
      [self.view addSubview:lMaxL];
    }
    lMaxL.hidden = NO;
    lMaxL.frame = CGRectMake(leftX + 14, topY + 300, 164, 40);

    // Subtle divider 2 inside Left Pod
    UIView *lDiv2 = [self.driveLeftCard viewWithTag:902];
    if (!lDiv2) {
      lDiv2 = [[UIView alloc] init];
      lDiv2.tag = 902;
      lDiv2.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1];
      [self.driveLeftCard addSubview:lDiv2];
    }
    lDiv2.frame = CGRectMake(16, 350, leftW - 32, 1);

    self.drivePowerMeter.hidden = NO;
    self.drivePowerMeter.frame = CGRectMake(leftX + 8, topY + 358, leftW - 16, 222);

    // 2. CENTER POD (Structured Framed Card matching Left & Right Pods!)
    UIView *cPod = [self.view viewWithTag:890];
    if (!cPod) {
      cPod = [[UIView alloc] init];
      cPod.tag = 890;
      cPod.userInteractionEnabled = NO;
      cPod.layer.cornerRadius = 14;
      cPod.layer.borderWidth = 1.2;
      cPod.layer.borderColor = [UIColor colorWithWhite:0.20 alpha:1].CGColor;
      cPod.backgroundColor = [UIColor colorWithRed:0.025 green:0.045 blue:0.07 alpha:0.92];
      [self.view addSubview:cPod];
    }
    cPod.hidden = NO;
    cPod.frame = CGRectMake(centerX, topY, centerW, podH);

    self.energyFlowLabel.hidden = NO;
    self.energyFlowLabel.frame = CGRectMake(centerX + 16, topY + 10, centerW - 32, 32);
    self.energyFlowLabel.font = [UIFont boldSystemFontOfSize:13.0];
    self.energyFlowLabel.textColor = [UIColor colorWithRed:0 green:.90 blue:1 alpha:1];
    self.energyFlowLabel.layer.cornerRadius = 8;
    self.energyFlowLabel.layer.borderWidth = 1.0;
    self.energyFlowLabel.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.45].CGColor;
    self.energyFlowLabel.backgroundColor = [UIColor colorWithRed:.02 green:.08 blue:.12 alpha:.92];
    if (self.energyFlowLabel.text.length == 0) {
      self.energyFlowLabel.text = @"🍃 โหมดขับขี่อัจฉริยะ EV / HYBRID  •  CRUISE READY";
    }

    // Top Car Stage: 3D Dynamic Flow Grid + Side Prius + 5-Door Panel aligned cleanly at top
    self.drive3DGrid.hidden = NO;
    self.drive3DGrid.frame = CGRectMake(centerX + 10, topY + 46, centerW - 20, 218);

    self.driveCar.hidden = NO;
    CGFloat driveCarW = MAX(256.0, centerW - 156.0);
    self.driveCar.frame = CGRectMake(centerX + 12, topY + 48, driveCarW, 174);
    [self updateHeadlightBeamsUI:[TRDOBDClient sharedClient]];
    [self.driveCar.lightBeams setNeedsDisplay];

    self.doorDiagramView.hidden = NO;
    self.doorDiagramView.frame = CGRectMake(centerX + centerW - 134, topY + 52, 120, 168);
    [self.doorDiagramView setNeedsDisplay];

    // Live Hybrid Acceleration / Power Bar directly beneath the car
    self.hybridEcoBar.hidden = NO;
    self.hybridEcoBar.frame = CGRectMake(centerX + 16, topY + 270, centerW - 32, 26);

    // Luxury Start-to-Stop (A -> B) Live Distance HUD Card
    UIButton *abPod = (UIButton *)[self.view viewWithTag:895];
    if (!abPod) {
      abPod = [UIButton buttonWithType:UIButtonTypeCustom];
      abPod.tag = 895;
      abPod.showsTouchWhenHighlighted = YES;
      abPod.layer.cornerRadius = 12;
      abPod.layer.borderWidth = 1.3;
      abPod.layer.borderColor = [UIColor colorWithRed:0.0 green:0.92 blue:0.68 alpha:0.65].CGColor;
      abPod.backgroundColor = [UIColor colorWithRed:0.02 green:0.08 blue:0.12 alpha:0.96];
      [abPod addTarget:self action:@selector(quickResetABTrip) forControlEvents:UIControlEventTouchUpInside];

      UIView *abBar = [[UIView alloc] initWithFrame:CGRectMake(0, 10, 4, 54)];
      abBar.backgroundColor = [UIColor colorWithRed:0.15 green:1.0 blue:0.65 alpha:1.0];
      abBar.userInteractionEnabled = NO;
      [abPod addSubview:abBar];

      UILabel *abTitle = [[UILabel alloc] initWithFrame:CGRectMake(14, 7, 240, 20)];
      abTitle.tag = 896;
      abTitle.font = [UIFont boldSystemFontOfSize:12.5];
      abTitle.adjustsFontSizeToFitWidth = YES;
      abTitle.minimumScaleFactor = 0.85;
      abTitle.textColor = [UIColor colorWithRed:0.0 green:0.92 blue:1.0 alpha:1.0];
      abTitle.text = @"📍 ระยะทางตั้งแต่สตาร์ทรถ (A➔B • แตะรีเซ็ต)";
      abTitle.userInteractionEnabled = NO;
      [abPod addSubview:abTitle];

      UILabel *abState = [[UILabel alloc] initWithFrame:CGRectMake(14, 28, 240, 18)];
      abState.tag = 899;
      abState.font = [UIFont boldSystemFontOfSize:11.5];
      abState.textColor = [UIColor colorWithRed:1.0 green:0.82 blue:0.28 alpha:1.0];
      abState.text = @"⏸️ รถจอดนิ่ง • หยุดพักการนับอัตโนมัติ";
      abState.userInteractionEnabled = NO;
      [abPod addSubview:abState];

      UILabel *abSub = [[UILabel alloc] initWithFrame:CGRectMake(14, 48, 240, 18)];
      abSub.tag = 897;
      abSub.font = [UIFont boldSystemFontOfSize:11.5];
      abSub.textColor = [UIColor colorWithWhite:0.86 alpha:1.0];
      abSub.text = @"⏱️ เวลาขับ 00:00 นาที  •  ⛽ 0.00 L (฿ 0.0)";
      abSub.userInteractionEnabled = NO;
      [abPod addSubview:abSub];

      UILabel *abVal = [[UILabel alloc] initWithFrame:CGRectMake(252, 8, 140, 58)];
      abVal.tag = 898;
      abVal.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:38.0] ?: [UIFont boldSystemFontOfSize:38.0];
      abVal.adjustsFontSizeToFitWidth = YES;
      abVal.minimumScaleFactor = 0.75;
      abVal.textAlignment = NSTextAlignmentRight;
      abVal.textColor = [UIColor colorWithRed:0.20 green:1.0 blue:0.65 alpha:1.0];
      abVal.text = @"0.00 km";
      abVal.userInteractionEnabled = NO;
      [abPod addSubview:abVal];

      [self.view addSubview:abPod];
    }
    abPod.hidden = NO;
    abPod.frame = CGRectMake(centerX + 16, topY + 306, centerW - 32, 72);

    self.driveCameraButton.hidden = NO;
    self.driveCameraButton.frame = CGRectMake(centerX + 16, topY + 388, centerW - 32, 40);
    [self.driveCameraButton setImage:TRDAutoVectorIcon(2, 20.0, [UIColor colorWithRed:0.25 green:0.92 blue:1.0 alpha:1.0]) forState:UIControlStateNormal];
    self.driveCameraButton.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 10);
    [self.driveCameraButton setTitle:@"เปิดกล้องมองหลัง / มุมอับสายตา (REAR CAMERA)" forState:UIControlStateNormal];
    self.driveCameraButton.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
    self.driveCameraButton.layer.cornerRadius = 8;
    self.driveCameraButton.layer.borderWidth = 1.2;
    self.driveCameraButton.layer.borderColor = [UIColor colorWithRed:0.15 green:0.80 blue:1.0 alpha:0.55].CGColor;
    self.driveCameraButton.backgroundColor = [UIColor colorWithRed:.04 green:.09 blue:.15 alpha:1.0];
    self.driveCameraButton.showsTouchWhenHighlighted = YES;

    self.compassLabel.hidden = NO;
    self.compassLabel.userInteractionEnabled = YES;
    if(self.compassLabel.gestureRecognizers.count == 0){
      [self.compassLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cycleDriveWidgetMode)]];
    }
    self.compassLabel.frame = CGRectMake(centerX + 16, topY + 438, centerW - 32, 40);
    self.compassLabel.font = [UIFont boldSystemFontOfSize:14.0];
    self.compassLabel.adjustsFontSizeToFitWidth = YES;
    self.compassLabel.minimumScaleFactor = 0.85;
    self.compassLabel.textColor = [UIColor colorWithRed:0 green:.92 blue:1 alpha:1];
    self.compassLabel.textAlignment = NSTextAlignmentCenter;
    self.compassLabel.layer.cornerRadius = 8;
    self.compassLabel.layer.borderWidth = 1.0;
    self.compassLabel.layer.borderColor = [UIColor colorWithRed:0 green:.80 blue:1 alpha:.35].CGColor;
    self.compassLabel.backgroundColor = [UIColor colorWithRed:.02 green:.07 blue:.11 alpha:1.0];
    self.compassLabel.clipsToBounds = YES;
    if (self.compassLabel.text.length == 0) {
      self.compassLabel.text = @"⚡ HV PACK: กำลังอ่านค่า CAN... (แตะสลับโหมด)";
    }

    self.carStatus.hidden = NO;
    self.carStatus.frame = CGRectMake(centerX + 16, topY + 488, centerW - 32, 78);
    self.carStatus.font = [UIFont boldSystemFontOfSize:13.5];
    self.carStatus.adjustsFontSizeToFitWidth = YES;
    self.carStatus.minimumScaleFactor = 0.85;
    self.carStatus.textColor = [UIColor whiteColor];
    self.carStatus.textAlignment = NSTextAlignmentCenter;
    self.carStatus.layer.cornerRadius = 8;
    self.carStatus.layer.borderWidth = 1.0;
    self.carStatus.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    self.carStatus.backgroundColor = [UIColor colorWithRed:.03 green:.06 blue:.09 alpha:1.0];
    if (self.carStatus.attributedText.length == 0 && self.carStatus.text.length == 0) {
      self.carStatus.text = @"กำลังอ่านสถานะ OBD2 & ประตู (CAN 0x620)...";
    }

    // 3. RIGHT POD (Width: 268, X: 738, Y: 48, Height: 590)
    self.driveRightCard.hidden = NO;
    self.driveRightCard.frame = CGRectMake(rightX, topY, rightW, podH);
    self.driveRightCard.layer.cornerRadius = 14;
    self.driveRightCard.layer.borderWidth = 1.2;
    self.driveRightCard.layer.borderColor = [UIColor colorWithWhite:0.20 alpha:1].CGColor;
    self.driveRightCard.backgroundColor = [UIColor colorWithRed:0.03 green:0.05 blue:0.08 alpha:1.0];

    // Right Card 1: Clock & Cabin Temp (Compact & Balanced)
    self.driveClockCard.hidden = NO;
    self.driveClockCard.frame = CGRectMake(rightX + 10, topY + 10, rightW - 20, 96);
    UILabel *cBig = (UILabel *)[self.driveClockCard viewWithTag:801];
    if (!cBig) {
      cBig = [[UILabel alloc] initWithFrame:CGRectMake(8, 12, rightW - 36, 46)];
      cBig.tag = 801;
      cBig.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:42] ?: [UIFont boldSystemFontOfSize:42];
      cBig.textColor = [UIColor whiteColor];
      cBig.textAlignment = NSTextAlignmentCenter;
      [self.driveClockCard addSubview:cBig];
      UILabel *cSub = [[UILabel alloc] initWithFrame:CGRectMake(8, 62, rightW - 36, 26)];
      cSub.tag = 802;
      cSub.font = [UIFont boldSystemFontOfSize:14.0];
      cSub.adjustsFontSizeToFitWidth = YES;
      cSub.minimumScaleFactor = 0.88;
      cSub.textColor = [UIColor colorWithRed:0.55 green:0.92 blue:1.0 alpha:1];
      cSub.textAlignment = NSTextAlignmentCenter;
      cSub.text = @"❄️ ห้องโดยสาร 24.0°C • ปกติ";
      [self.driveClockCard addSubview:cSub];
    }
    cBig.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:44] ?: [UIFont boldSystemFontOfSize:44];
    cBig.frame = CGRectMake(8, 10, rightW - 36, 48);
    cBig.text = [self.clockFormat stringFromDate:[NSDate date]];
    UILabel *cSub = (UILabel *)[self.driveClockCard viewWithTag:802];
    if (cSub) { cSub.frame = CGRectMake(8, 62, rightW - 36, 26); cSub.font = [UIFont boldSystemFontOfSize:14.0]; }

    // Right Card 2: Hybrid Traction Battery
    self.driveBatteryCard.hidden = NO;
    self.driveBatteryCard.frame = CGRectMake(rightX + 10, topY + 114, rightW - 20, 108);
    UILabel *bH = (UILabel *)[self.driveBatteryCard viewWithTag:811];
    if (!bH) {
      bH = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, rightW - 44, 22)];
      bH.tag = 811;
      bH.font = [UIFont boldSystemFontOfSize:14.0];
      bH.adjustsFontSizeToFitWidth = YES;
      bH.minimumScaleFactor = 0.88;
      bH.textColor = [UIColor colorWithRed:0 green:.90 blue:1 alpha:1];
      bH.text = @"⚡ แบตเตอรี่ไฮบริด (HV SOC)";
      [self.driveBatteryCard addSubview:bH];

      UIView *barBg = [[UIView alloc] initWithFrame:CGRectMake(12, 34, rightW - 44, 18)];
      barBg.tag = 813;
      barBg.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
      barBg.layer.cornerRadius = 9;
      barBg.clipsToBounds = YES;
      UIView *barFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, (rightW - 44) * 0.60, 18)];
      barFill.tag = 814;
      barFill.backgroundColor = [UIColor colorWithRed:0 green:.88 blue:.52 alpha:1];
      [barBg addSubview:barFill];
      [self.driveBatteryCard addSubview:barBg];

      UILabel *bS = [[UILabel alloc] initWithFrame:CGRectMake(12, 56, rightW - 44, 46)];
      bS.tag = 812;
      bS.numberOfLines = 2;
      bS.font = [UIFont boldSystemFontOfSize:14.0];
      bS.adjustsFontSizeToFitWidth = YES;
      bS.minimumScaleFactor = 0.88;
      bS.textColor = [UIColor colorWithRed:.35 green:.98 blue:.55 alpha:1];
      bS.text = @"--% (WAITING ECU)\nแรงดัน: -- V  •  -- A";
      [self.driveBatteryCard addSubview:bS];
    }
    bH.text = @"⚡ แบตเตอรี่ไฮบริด (HV SOC)";
    bH.font = [UIFont boldSystemFontOfSize:14.0];
    bH.textColor = [UIColor colorWithRed:0 green:.90 blue:1 alpha:1];
    UILabel *bS = (UILabel *)[self.driveBatteryCard viewWithTag:812];
    if (bS) {
      bS.frame = CGRectMake(12, 56, rightW - 44, 46);
      bS.numberOfLines = 2;
      bS.font = [UIFont boldSystemFontOfSize:14.0];
    }

    // Right Card 3: Interactive TRIP A / TRIP B / TRIP C Card (Expanded & Multi-Column!)
    self.driveTripCard.hidden = NO;
    self.driveTripCard.userInteractionEnabled = YES;
    self.driveTripCard.frame = CGRectMake(rightX + 10, topY + 230, rightW - 20, 290);
    CGFloat tcW = rightW - 20;

    // Remove old tiny labels if present
    [[self.driveTripCard viewWithTag:821] removeFromSuperview];
    [[self.driveTripCard viewWithTag:822] removeFromSuperview];

    UIButton *tabA = (UIButton *)[self.driveTripCard viewWithTag:840];
    if (!tabA) {
      NSArray *tNames = @[@"TRIP A", @"TRIP B", @"TRIP C"];
      CGFloat tabGap = 6;
      CGFloat tabW = (tcW - 20 - tabGap * 2) / 3.0;
      for (int i = 0; i < 3; i++) {
        UIButton *tb = [UIButton buttonWithType:UIButtonTypeCustom];
        tb.tag = 840 + i;
        tb.showsTouchWhenHighlighted = YES;
        tb.frame = CGRectMake(10 + i * (tabW + tabGap), 8, tabW, 38);
        [tb setTitle:tNames[i] forState:UIControlStateNormal];
        tb.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
        tb.layer.cornerRadius = 8;
        tb.layer.borderWidth = 1.2;
        [tb addTarget:self action:@selector(selectTripSlot:) forControlEvents:UIControlEventTouchUpInside];
        [self.driveTripCard addSubview:tb];
      }

      UILabel *subL = [[UILabel alloc] initWithFrame:CGRectMake(12, 52, tcW - 24, 22)];
      subL.tag = 823;
      subL.font = [UIFont boldSystemFontOfSize:14.5];
      subL.adjustsFontSizeToFitWidth = YES;
      subL.minimumScaleFactor = 0.80;
      subL.textColor = [UIColor colorWithRed:0.0 green:0.90 blue:1.0 alpha:1];
      [self.driveTripCard addSubview:subL];

      // 4 Metric Rows (Left Label + Right Bold Value)
      NSString *fuelTag = TRDFuelShortCode([TRDOBDClient sharedClient].selectedFuelTypeIndex);
      NSArray *rTitles = @[@"ระยะทางสะสม", @"อัตราสิ้นเปลือง", [NSString stringWithFormat:@"ค่าน้ำมัน (%@)", fuelTag], @"เวลาขับ / เฉลี่ย"];
      for (int r = 0; r < 4; r++) {
        CGFloat ry = 76 + r * 39;
        UIView *rBg = [[UIView alloc] initWithFrame:CGRectMake(10, ry, tcW - 20, 33)];
        rBg.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.04];
        rBg.layer.cornerRadius = 6;
        [self.driveTripCard addSubview:rBg];

        UILabel *rL = [[UILabel alloc] initWithFrame:CGRectMake(14, ry, 108, 33)];
        rL.tag = 871 + r;
        rL.font = [UIFont boldSystemFontOfSize:14.0];
        rL.adjustsFontSizeToFitWidth = YES;
        rL.minimumScaleFactor = 0.88;
        rL.textColor = [UIColor colorWithWhite:0.90 alpha:1];
        rL.text = rTitles[r];
        [self.driveTripCard addSubview:rL];

        UILabel *rV = [[UILabel alloc] initWithFrame:CGRectMake(122, ry, tcW - 134, 33)];
        rV.tag = 851 + r;
        rV.font = [UIFont boldSystemFontOfSize:16.0];
        rV.adjustsFontSizeToFitWidth = YES;
        rV.minimumScaleFactor = 0.88;
        rV.textAlignment = NSTextAlignmentRight;
        rV.textColor = (r == 2) ? [UIColor colorWithRed:0.35 green:0.98 blue:0.55 alpha:1] : [UIColor whiteColor];
        [self.driveTripCard addSubview:rV];
      }

      UIButton *fullTripBtn = [UIButton buttonWithType:UIButtonTypeCustom];
      fullTripBtn.tag = 860;
      fullTripBtn.showsTouchWhenHighlighted = YES;
      fullTripBtn.frame = CGRectMake(10, 238, tcW - 20, 42);
      fullTripBtn.backgroundColor = [UIColor colorWithRed:0.05 green:0.14 blue:0.22 alpha:0.95];
      fullTripBtn.layer.cornerRadius = 8;
      fullTripBtn.layer.borderWidth = 1.0;
      fullTripBtn.layer.borderColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.5].CGColor;
      [fullTripBtn setTitle:@"📊 ดูหน้าต่างสถิติ GPS / รีเซ็ตทริป ›" forState:UIControlStateNormal];
      [fullTripBtn setTitleColor:[UIColor colorWithRed:0.2 green:0.95 blue:1.0 alpha:1] forState:UIControlStateNormal];
      fullTripBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
      [fullTripBtn addTarget:self action:@selector(openTrip) forControlEvents:UIControlEventTouchUpInside];
      [self.driveTripCard addSubview:fullTripBtn];
    }
    UIButton *fullTripBtn = (UIButton *)[self.driveTripCard viewWithTag:860];
    if (fullTripBtn) {
      [fullTripBtn setTitle:@"🔄 รีเซ็ตทริป / สลับโหมดดูทริป ›" forState:UIControlStateNormal];
      [fullTripBtn removeTarget:self action:@selector(openTrip) forControlEvents:UIControlEventTouchUpInside];
      [fullTripBtn addTarget:self action:@selector(resetTripMenu) forControlEvents:UIControlEventTouchUpInside];
    }
    [self refreshDriveTripDisplay];

    // Right Card 4: Thai Radio Button (Flush with bottom of Right Pod!)
    self.radioButton.hidden = NO;
    self.radioButton.showsTouchWhenHighlighted = YES;
    self.radioButton.frame = CGRectMake(rightX + 10, topY + 528, rightW - 20, 50);
    [self.radioButton setTitle:@"📻  วิทยุออนไลน์ (THAI RADIO)" forState:UIControlStateNormal];
    self.radioButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.5];
    self.radioButton.layer.cornerRadius = 10;
    self.radioButton.layer.borderWidth = 1.2;
    self.radioButton.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.45].CGColor;
    self.radioButton.backgroundColor = [UIColor colorWithRed:.04 green:.10 blue:.16 alpha:.95];

    // Bottom Console
    CGFloat consoleY = topY + 600;
    CGFloat consoleH = 96;
    self.nowPanel.hidden = NO;
    self.nowPanel.frame = CGRectMake(18, consoleY, w - 36, consoleH);
    self.nowPanel.layer.cornerRadius = 14;
    self.nowPanel.layer.borderWidth = 1.2;
    self.nowPanel.layer.borderColor = [UIColor colorWithWhite:.20 alpha:1].CGColor;
    self.nowPanel.backgroundColor = [UIColor colorWithRed:.03 green:.05 blue:.08 alpha:1.0];

    self.artwork.hidden = NO;
    self.artwork.frame = CGRectMake(28, consoleY + 12, consoleH - 24, consoleH - 24);
    self.artwork.layer.cornerRadius = 8;
    self.artPlaceholder.frame = self.artwork.frame;
    self.artPlaceholder.hidden = (self.artwork.image != nil);

    CGFloat artRight = 28 + consoleH - 24 + 14;
    CGFloat textW = 248;
    self.song.hidden = NO;
    self.song.frame = CGRectMake(artRight, consoleY + 8, textW, 24);
    self.song.font = [UIFont boldSystemFontOfSize:17.5];
    self.song.adjustsFontSizeToFitWidth = YES;
    self.song.minimumScaleFactor = 0.85;
    self.song.textColor = [UIColor whiteColor];

    self.artist.hidden = NO;
    self.artist.frame = CGRectMake(artRight, consoleY + 33, textW, 20);
    self.artist.font = [UIFont boldSystemFontOfSize:14.0];
    self.artist.adjustsFontSizeToFitWidth = YES;
    self.artist.minimumScaleFactor = 0.85;
    self.artist.textColor = [UIColor colorWithWhite:0.90 alpha:1];

    self.trackProgress.hidden = NO;
    self.trackProgress.frame = CGRectMake(artRight, consoleY + 58, textW, 5);

    self.trackTime.hidden = NO;
    self.trackTime.frame = CGRectMake(artRight, consoleY + 66, textW, 22);
    self.trackTime.font = [UIFont boldSystemFontOfSize:13.0];
    self.trackTime.adjustsFontSizeToFitWidth = YES;
    self.trackTime.minimumScaleFactor = 0.82;
    self.trackTime.textColor = [UIColor colorWithRed:0.15 green:0.95 blue:1.0 alpha:1];
    self.trackTime.textAlignment = NSTextAlignmentLeft;

    self.controls.hidden = NO;
    self.controls.frame = CGRectMake(artRight + textW + 12, consoleY + 18, 196, 60);
    CGFloat dcw = 186.0 / 3.0;
    for (int i = 0; i < 3; i++) {
      UIButton *b = (UIButton *)[self.controls viewWithTag:20 + i];
      b.showsTouchWhenHighlighted = YES;
      b.frame = CGRectMake(i * (dcw + 5), 0, dcw, 60);
      b.layer.cornerRadius = 10;
      if (i == 1) {
        b.backgroundColor = [UIColor colorWithRed:.0 green:.72 blue:.40 alpha:1];
        b.layer.borderColor = [UIColor colorWithRed:.2 green:.9 blue:.5 alpha:1].CGColor;
      } else {
        b.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
        b.layer.borderColor = [UIColor colorWithWhite:.24 alpha:1].CGColor;
      }
      [b viewWithTag:105].frame = CGRectMake((dcw - 28)/2, (60 - 28)/2, 28, 28);
    }

    CGFloat btnY = consoleY + 20;
    CGFloat btnH = 56;
    self.driveExitBtn.hidden = NO;
    self.driveExitBtn.showsTouchWhenHighlighted = YES;
    self.driveExitBtn.frame = CGRectMake(w - 28 - 134, btnY, 134, btnH);
    [self.driveExitBtn setTitle:@"🏠 EXIT HOME" forState:UIControlStateNormal];

    self.driveEqBtn.hidden = NO;
    self.driveEqBtn.showsTouchWhenHighlighted = YES;
    self.driveEqBtn.frame = CGRectMake(CGRectGetMinX(self.driveExitBtn.frame) - 8 - 130, btnY, 130, btnH);
    [self.driveEqBtn setTitle:@"🎚️ EQ SOUND" forState:UIControlStateNormal];

    UIColor *drvAccent = TRDAccent();
    self.searchMusicBtn.hidden = NO;
    self.searchMusicBtn.showsTouchWhenHighlighted = YES;
    self.searchMusicBtn.frame = CGRectMake(CGRectGetMinX(self.driveEqBtn.frame) - 8 - 122, btnY, 122, btnH);
    self.searchMusicBtn.backgroundColor = [drvAccent colorWithAlphaComponent:0.18];
    self.searchMusicBtn.layer.cornerRadius = 8;
    self.searchMusicBtn.layer.borderWidth = 1.2;
    self.searchMusicBtn.layer.borderColor = [drvAccent colorWithAlphaComponent:0.70].CGColor;
    [self.searchMusicBtn setTitleColor:drvAccent forState:UIControlStateNormal];
    self.searchMusicBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];

    self.driveEQ.hidden = YES;
    self.miniPlayer.hidden = YES;
    UIView *mH = [self.nowPanel viewWithTag:750]; if(mH) mH.hidden = YES;

    // Bring subviews to front for Drive Mode
    [self.view bringSubviewToFront:self.driveLeftCard];
    [self.view bringSubviewToFront:self.driveSpeedoDial];
    [self.view bringSubviewToFront:self.driveShifter];
    [self.view bringSubviewToFront:self.gearBadge];
    if (lModeB) [self.view bringSubviewToFront:lModeB];
    if (lMaxL) [self.view bringSubviewToFront:lMaxL];
    [self.view bringSubviewToFront:self.drivePowerMeter];
    if (cPod) [self.view bringSubviewToFront:cPod];
    [self.view bringSubviewToFront:self.drive3DGrid];
    [self.view bringSubviewToFront:self.driveCar];
    [self.view bringSubviewToFront:self.doorDiagramView];
    [self.view bringSubviewToFront:self.hybridEcoBar];
    [self.view bringSubviewToFront:self.energyFlowLabel];
    [self.view bringSubviewToFront:self.driveCameraButton];
    if (abPod) [self.view bringSubviewToFront:abPod];
    [self.view bringSubviewToFront:self.compassLabel];
    [self.view bringSubviewToFront:self.carStatus];
    [self.view bringSubviewToFront:self.driveRightCard];
    [self.view bringSubviewToFront:self.driveClockCard];
    [self.view bringSubviewToFront:self.driveBatteryCard];
    [self.view bringSubviewToFront:self.driveTripCard];
    [self.view bringSubviewToFront:self.radioButton];
    [self.view bringSubviewToFront:self.nowPanel];
    [self.view bringSubviewToFront:self.artwork];
    [self.view bringSubviewToFront:self.artPlaceholder];
    [self.view bringSubviewToFront:self.song];
    [self.view bringSubviewToFront:self.artist];
    [self.view bringSubviewToFront:self.trackProgress];
    [self.view bringSubviewToFront:self.trackTime];
    [self.view bringSubviewToFront:self.controls];
    [self.view bringSubviewToFront:self.searchMusicBtn];
    [self.view bringSubviewToFront:self.driveEqBtn];
    [self.view bringSubviewToFront:self.driveExitBtn];
    [self refreshLiveOBDDashboard];

  } else {
    // =========================================================================
    // HOME DASHBOARD (100% Matching dashboard.html / media_1794267643239_0594d895.jpg)
    // =========================================================================
    self.panel.hidden = NO;
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
    UIColor *accent = TRDAccent();
    CGFloat barY = 12;
    self.heading.hidden = NO;
    self.heading.frame = CGRectMake(16, barY, 350, 22);
    self.heading.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightHeavy];
    self.heading.textColor = accent;
    self.heading.text = [NSString stringWithFormat:@"PRIUS TRD  •  %@", TRDDriveModeName(TRDTheme)];
    self.owner.hidden = NO;
    self.owner.frame = CGRectMake(16, barY + 23, 410, 18);
    self.owner.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold];
    self.owner.adjustsFontSizeToFitWidth = YES;
    self.owner.minimumScaleFactor = 0.85;
    self.owner.textColor = [UIColor colorWithRed:0.68 green:0.90 blue:1.0 alpha:0.92];
    self.owner.text = @"HYBRID SMART COCKPIT \u2022 OBD2 LIVE TELEMETRY";

    CGFloat curRx = w - 16;
    CGFloat pillH = 32;

    curRx -= 108;
    self.settingsPill.hidden = NO;
    self.settingsPill.frame = CGRectMake(curRx, barY + 4, 108, pillH);
    self.settingsPill.layer.cornerRadius = 10;
    [self.settingsPill setTitle:@"⚙️ SETTINGS" forState:UIControlStateNormal];

    curRx -= 80;
    self.helpPill.hidden = NO;
    self.helpPill.frame = CGRectMake(curRx, barY + 4, 74, pillH);
    self.helpPill.layer.cornerRadius = 10;

    curRx -= 64;
    self.voicePill.hidden = NO;
    self.voicePill.frame = CGRectMake(curRx, barY + 2, 58, pillH + 4);
    self.voicePill.layer.cornerRadius = 12;
    self.voicePill.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    [self.view bringSubviewToFront:self.voicePill];

    // Remove THAI VOICE pill on Home Mode; show Live Wi-Fi/Hotspot + Bluetooth/Speaker pill instead
    self.thaiVoicePill.hidden = YES;
    curRx -= 190;
    UIButton *connPillH = (UIButton *)[self.view viewWithTag:910];
    if (!connPillH) {
      connPillH = [UIButton buttonWithType:UIButtonTypeCustom];
      connPillH.tag = 910;
      connPillH.titleLabel.font = [UIFont boldSystemFontOfSize:11.5];
      connPillH.titleLabel.adjustsFontSizeToFitWidth = YES;
      connPillH.titleLabel.minimumScaleFactor = 0.78;
      connPillH.contentEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
      connPillH.layer.cornerRadius = 10;
      connPillH.layer.borderWidth = 1.0;
      connPillH.backgroundColor = [UIColor colorWithRed:0.04 green:0.08 blue:0.13 alpha:0.95];
      [connPillH addTarget:self action:@selector(audioOutputSettings) forControlEvents:UIControlEventTouchUpInside];
      [self.view addSubview:connPillH];
    }
    connPillH.hidden = NO;
    connPillH.frame = CGRectMake(curRx, barY + 4, 182, pillH);
    [self.view bringSubviewToFront:connPillH];

    curRx -= 64;
    self.topClockLabel.hidden = NO;
    self.topClockLabel.frame = CGRectMake(curRx, barY + 4, 58, pillH);
    self.topClockLabel.font = [UIFont monospacedDigitSystemFontOfSize:13.5 weight:UIFontWeightBold];
    self.topClockLabel.layer.cornerRadius = 10;
    self.topClockLabel.text = [self.clockFormat stringFromDate:[NSDate date]];

    curRx -= 90;
    self.dayNightPill.hidden = NO;
    self.dayNightPill.frame = CGRectMake(curRx, barY + 4, 84, pillH);
    self.dayNightPill.layer.cornerRadius = 10;
    [self.dayNightPill setTitle:self.nightMode?@"🌙 NIGHT":@"☀️ DAY" forState:UIControlStateNormal];

    curRx -= 142;
    self.obdStatusPill.hidden = NO;
    self.obdStatusPill.frame = CGRectMake(curRx, barY + 4, 136, pillH);
    self.obdStatusPill.layer.cornerRadius = 10;

    UIColor *outerGlassBg = [UIColor colorWithRed:0.032 green:0.050 blue:0.080 alpha:1.0];
    UIColor *innerGlassBg = [UIColor colorWithRed:0.055 green:0.085 blue:0.130 alpha:1.0];
    CGColorRef outerGlassBorder = [accent colorWithAlphaComponent:0.40].CGColor;
    CGColorRef innerGlassBorder = [UIColor colorWithWhite:1.0 alpha:0.11].CGColor;

    // 1. LEFT ZONE
    self.driveLeftCard.hidden = NO;
    self.driveLeftCard.frame = CGRectMake(leftX, topY, leftW, colH);
    self.driveLeftCard.layer.cornerRadius = 16;
    self.driveLeftCard.layer.borderWidth = 1.25;
    self.driveLeftCard.layer.borderColor = outerGlassBorder;
    self.driveLeftCard.backgroundColor = outerGlassBg;

    UIView *hTopPod = [self.view viewWithTag:790];
    if (!hTopPod) {
      hTopPod = [[UIView alloc] init];
      hTopPod.tag = 790;
      hTopPod.userInteractionEnabled = NO;
      [self.view addSubview:hTopPod];
    }
    hTopPod.backgroundColor = innerGlassBg;
    hTopPod.layer.cornerRadius = 12;
    hTopPod.layer.borderWidth = 1.0;
    hTopPod.layer.borderColor = innerGlassBorder;
    hTopPod.hidden = NO;
    hTopPod.frame = CGRectMake(leftX + 10, topY + 8, leftW - 20, 224);

    self.readyPill.hidden = NO;
    self.readyPill.frame = CGRectMake(leftX + (leftW - 154)/2, topY + 12, 154, 20);

    self.homeSpeedoDial.hidden = NO;
    self.gearBadge.hidden = YES;
    self.homeSpeedoDial.frame = CGRectMake(leftX + 12, topY + 34, leftW - 24, 122);

    CGFloat gw = (leftW - 36 - 4*5)/5.0;
    for (int i = 0; i < self.gearButtons.count; i++) {
      UIButton *gb = self.gearButtons[i];
      gb.hidden = NO;
      gb.frame = CGRectMake(leftX + 18 + i*(gw + 5), topY + 158, gw, 28);
      gb.titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
    }

    self.hybridEcoBar.hidden = YES;

    for (int i = 0; i < self.driveModePills.count; i++) {
      UIButton *mb = self.driveModePills[i];
      if (i == 1) {
        mb.hidden = NO;
        mb.frame = CGRectMake(leftX + 18, topY + 192, leftW - 36, 28);
        NSString *mName = (TRDTheme == 0) ? @"🔥 SPORT MODE • แตะสลับ" : ((TRDTheme == 1) ? @"❄️ NORMAL MODE • แตะสลับ" : @"🌱 ECO MODE • แตะสลับ");
        [mb setTitle:mName forState:UIControlStateNormal];
        mb.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
      } else {
        mb.hidden = YES;
      }
    }

    // Left Card 2: AI ECO COACH (Exact mirror of Right Card 2 at Y = topY + 240, H = 178!)
    self.homeAiEcoCard.hidden = NO;
    self.homeAiEcoCard.frame = CGRectMake(leftX + 10, topY + 240, leftW - 20, 178);
    self.homeAiEcoCard.backgroundColor = innerGlassBg;
    self.homeAiEcoCard.layer.cornerRadius = 12;
    self.homeAiEcoCard.layer.borderWidth = 1.0;
    self.homeAiEcoCard.layer.borderColor = [UIColor colorWithRed:0.20 green:0.85 blue:0.45 alpha:0.28].CGColor;
    for(int qi=0; qi<3; qi++){
      UIView *qb = [self.homeAiEcoCard viewWithTag:510 + qi];
      if(qb) qb.frame = CGRectMake(10, 34 + qi * 45, leftW - 40, 39);
    }
    self.compassLabel.userInteractionEnabled = YES;
    if(self.compassLabel.gestureRecognizers.count == 0){
      [self.compassLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cycleDriveWidgetMode)]];
    }
    UILabel *ecoH = (UILabel *)[self.homeAiEcoCard viewWithTag:501];
    if (ecoH) ecoH.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    UILabel *ecoS = (UILabel *)[self.homeAiEcoCard viewWithTag:502];
    if (ecoS) ecoS.font = [UIFont monospacedDigitSystemFontOfSize:16.0 weight:UIFontWeightHeavy];
    UILabel *ecoD = (UILabel *)[self.homeAiEcoCard viewWithTag:503];
    if (ecoD) {
      ecoD.frame = CGRectMake(10, 54, leftW - 40, 116);
      ecoD.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
      ecoD.textColor = [UIColor colorWithWhite:0.90 alpha:1];
    }

    // Left Card 3: THERMALS & 12V (Exact mirror of Right Card 3 at Y = topY + 426, H = 186!)
    self.homeThermalsCard.hidden = NO;
    self.homeThermalsCard.frame = CGRectMake(leftX + 10, topY + 426, leftW - 20, 186);
    self.homeThermalsCard.backgroundColor = innerGlassBg;
    self.homeThermalsCard.layer.cornerRadius = 12;
    self.homeThermalsCard.layer.borderWidth = 1.0;
    self.homeThermalsCard.layer.borderColor = innerGlassBorder;
    for (NSInteger tTag = 601; tTag <= 603; tTag++) {
      UILabel *tr = (UILabel *)[self.homeThermalsCard viewWithTag:tTag];
      if (tr) tr.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightSemibold];
    }

    // 2. CENTER ZONE (Two Symmetric Cards matching Left & Right Top/Bottom borders!)
    UIView *hCenterTopCard = [self.view viewWithTag:791];
    if (!hCenterTopCard) {
      hCenterTopCard = [[UIView alloc] init];
      hCenterTopCard.tag = 791;
      hCenterTopCard.userInteractionEnabled = NO;
      [self.view addSubview:hCenterTopCard];
    }
    hCenterTopCard.backgroundColor = outerGlassBg;
    hCenterTopCard.layer.cornerRadius = 16;
    hCenterTopCard.layer.borderWidth = 1.25;
    hCenterTopCard.layer.borderColor = outerGlassBorder;
    hCenterTopCard.hidden = NO;
    hCenterTopCard.frame = CGRectMake(centerX, topY, centerW, 314);

    self.energyFlowLabel.hidden = NO;
    self.energyFlowLabel.frame = CGRectMake(centerX + 12, topY + 10, centerW - 24, 30);
    self.energyFlowLabel.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightSemibold];
    self.energyFlowLabel.layer.cornerRadius = 10;
    self.energyFlowLabel.layer.masksToBounds = YES;
    self.energyFlowLabel.layer.borderWidth = 1.0;
    self.energyFlowLabel.layer.borderColor = [accent colorWithAlphaComponent:0.35].CGColor;
    self.energyFlowLabel.backgroundColor = innerGlassBg;

    self.frontMotorBox.hidden = NO;
    self.frontMotorBox.frame = CGRectMake(centerX + 12, topY + 46, 206, 46);
    self.frontMotorBox.layer.cornerRadius = 10;

    self.rearBatteryBox.hidden = NO;
    self.rearBatteryBox.frame = CGRectMake(centerX + centerW - 218, topY + 46, 206, 46);
    self.rearBatteryBox.layer.cornerRadius = 10;

    self.carImage.hidden = NO;
    self.carImage.frame = CGRectMake(centerX + 14, topY + 82, 320, 160);
    self.homeCarLightBeams.frame = self.carImage.frame;
    [self updateHeadlightBeamsUI:[TRDOBDClient sharedClient]];

    self.doorDiagramView.hidden = NO;
    CGRect doorTarget = CGRectMake(centerX + centerW - 124, topY + 94, 112, 144);
    if (!CGRectEqualToRect(self.doorDiagramView.frame, doorTarget)) {
      self.doorDiagramView.frame = doorTarget;
      [self.doorDiagramView setNeedsDisplay];
    }

    self.flowBeamLine.hidden = NO;
    self.flowBeamLine.frame = CGRectMake(centerX + 24, topY + 243, centerW - 48, 2);
    UIView *rDot = [self.flowBeamLine viewWithTag:831];
    if (rDot) rDot.frame = CGRectMake(centerW - 48 - 10, -4, 10, 10);

    self.compassLabel.hidden = NO;
    self.compassLabel.frame = CGRectMake(centerX + 12, topY + 248, centerW - 24, 22);
    self.compassLabel.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightSemibold];
    self.compassLabel.adjustsFontSizeToFitWidth = YES;
    self.compassLabel.minimumScaleFactor = 0.85;
    self.compassLabel.textColor = [UIColor colorWithRed:0.35 green:0.94 blue:1.0 alpha:1];
    self.compassLabel.textAlignment = NSTextAlignmentCenter;

    self.carStatus.hidden = NO;
    self.carStatus.frame = CGRectMake(centerX + 12, topY + 272, centerW - 24, 36);
    self.carStatus.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightSemibold];
    self.carStatus.adjustsFontSizeToFitWidth = YES;
    self.carStatus.minimumScaleFactor = 0.85;
    self.carStatus.textColor = [UIColor colorWithWhite:0.96 alpha:1];
    self.carStatus.textAlignment = NSTextAlignmentCenter;
    self.carStatus.layer.cornerRadius = 10;
    self.carStatus.layer.masksToBounds = YES;
    self.carStatus.layer.borderWidth = 1.0;
    self.carStatus.layer.borderColor = innerGlassBorder;
    self.carStatus.backgroundColor = innerGlassBg;

    // Multimedia Console (Full Center Width = 472px, Y = topY + 322, H = 298 -> Bottom = topY + 620!)
    CGFloat mTop = topY + 322;
    CGFloat mH = colH - 322;
    self.nowPanel.hidden = NO;
    self.nowPanel.frame = CGRectMake(centerX, mTop, centerW, mH);
    self.nowPanel.layer.cornerRadius = 16;
    self.nowPanel.layer.borderWidth = 1.25;
    self.nowPanel.layer.borderColor = outerGlassBorder;
    self.nowPanel.backgroundColor = outerGlassBg;

    self.artwork.hidden = NO;
    self.artwork.frame = CGRectMake(centerX + 22, mTop + 20, 148, 148);
    self.artwork.layer.cornerRadius = 14;
    self.artwork.clipsToBounds = YES;
    self.artwork.backgroundColor = innerGlassBg;
    self.artwork.layer.borderWidth = 1.2;
    self.artwork.layer.borderColor = [accent colorWithAlphaComponent:0.45].CGColor;
    self.artPlaceholder.frame = self.artwork.frame;
    self.artPlaceholder.font = [UIFont boldSystemFontOfSize:48];
    self.artPlaceholder.textColor = accent;
    self.artPlaceholder.hidden = (self.artwork.image != nil);

    UILabel *mHead = (UILabel *)[self.nowPanel viewWithTag:750];
    if (!mHead) {
      mHead = [[UILabel alloc] initWithFrame:CGRectMake(184, 18, centerW - 306, 22)];
      mHead.tag = 750;
      mHead.adjustsFontSizeToFitWidth = YES;
      mHead.minimumScaleFactor = 0.75;
      [self.nowPanel addSubview:mHead];
    }
    mHead.frame = CGRectMake(184, 18, centerW - 306, 22);
    mHead.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    mHead.textColor = accent;
    mHead.text = @"🎵 CAR MULTIMEDIA  •  JBL AUDIO";

    self.searchMusicBtn.hidden = NO;
    self.searchMusicBtn.frame = CGRectMake(centerX + centerW - 114, mTop + 12, 98, 28);
    self.searchMusicBtn.backgroundColor = [accent colorWithAlphaComponent:0.16];
    self.searchMusicBtn.layer.cornerRadius = 8;
    self.searchMusicBtn.layer.borderWidth = 1.1;
    self.searchMusicBtn.layer.borderColor = [accent colorWithAlphaComponent:0.65].CGColor;
    [self.searchMusicBtn setTitleColor:accent forState:UIControlStateNormal];
    self.searchMusicBtn.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
    [self.view bringSubviewToFront:self.searchMusicBtn];

    self.song.hidden = NO;
    self.song.frame = CGRectMake(centerX + 184, mTop + 44, centerW - 204, 34);
    self.song.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightHeavy];
    self.song.textColor = [UIColor whiteColor];

    self.artist.hidden = NO;
    self.artist.frame = CGRectMake(centerX + 184, mTop + 82, centerW - 204, 24);
    self.artist.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    self.artist.textColor = [UIColor colorWithRed:0.75 green:0.90 blue:1.0 alpha:0.92];

    self.trackProgress.hidden = NO;
    self.trackProgress.frame = CGRectMake(centerX + 184, mTop + 124, centerW - 204, 6);
    self.trackProgress.layer.cornerRadius = 3;
    self.trackProgress.clipsToBounds = YES;
    self.trackProgress.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    self.trackProgress.progressTintColor = accent;

    self.trackTime.hidden = NO;
    self.trackTime.frame = CGRectMake(centerX + 184, mTop + 136, centerW - 204, 22);
    self.trackTime.font = [UIFont monospacedDigitSystemFontOfSize:13.5 weight:UIFontWeightSemibold];
    self.trackTime.adjustsFontSizeToFitWidth = YES;
    self.trackTime.minimumScaleFactor = 0.80;
    self.trackTime.textColor = [UIColor colorWithRed:0.25 green:0.95 blue:1.0 alpha:1];
    self.trackTime.textAlignment = NSTextAlignmentRight;

    CGFloat btnY = mTop + mH - 76; // 60px high buttons, 16px from card bottom -> bottoms align with side cards!
    CGFloat btnH = 60;
    self.controls.hidden = NO;
    self.controls.frame = CGRectMake(centerX + 22, btnY, 300, btnH);
    CGFloat cw = 290 / 3.0;
    for (int i = 0; i < 3; i++) {
      UIView *b = [self.controls viewWithTag:20 + i];
      b.frame = CGRectMake(i * (cw + 5), 0, cw, btnH);
      b.layer.cornerRadius = 12;
      if (i == 1) {
        b.backgroundColor = [UIColor colorWithRed:.0 green:.74 blue:.42 alpha:1];
        b.layer.borderColor = [UIColor colorWithRed:.25 green:.95 blue:.55 alpha:0.85].CGColor;
      } else {
        b.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        b.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
      }
      [b viewWithTag:105].frame = CGRectMake((cw - 28)/2, (btnH - 28)/2, 28, 28);
    }

    self.driveEQ.hidden = NO;
    self.driveEQ.frame = CGRectMake(centerX + 330, btnY, centerW - 352, btnH);
    self.driveEQ.layer.cornerRadius = 12;
    self.driveEQ.layer.borderWidth = 1.2;
    self.driveEQ.layer.borderColor = [accent colorWithAlphaComponent:0.55].CGColor;
    self.driveEQ.backgroundColor = [accent colorWithAlphaComponent:0.12];
    [self.driveEQ setTitle:@"🎚️ JBL EQ" forState:UIControlStateNormal];
    [self.driveEQ setTitleColor:accent forState:UIControlStateNormal];
    self.driveEQ.titleLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightBold];
    if(mHead) mHead.hidden = NO;

    // 3. RIGHT ZONE (100% Symmetric with Left Zone: 224 + 8 + 178 + 8 + 186!)
    self.driveRightCard.hidden = NO;
    self.driveRightCard.frame = CGRectMake(rightX, topY, rightW, colH);
    self.driveRightCard.layer.cornerRadius = 16;
    self.driveRightCard.layer.borderWidth = 1.25;
    self.driveRightCard.layer.borderColor = outerGlassBorder;
    self.driveRightCard.backgroundColor = outerGlassBg;

    // Right Card 1: POWERTRAIN & HV • 7E3 (H = 224, exact mirror of hTopPod!)
    UIView *pCard = [self.view viewWithTag:701];
    if (!pCard) {
      pCard = [[UIView alloc] init];
      pCard.tag = 701;

      UILabel *pt = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, rightW - 36, 22)];
      pt.tag = 702;
      pt.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
      pt.adjustsFontSizeToFitWidth = YES;
      pt.minimumScaleFactor = 0.85;
      pt.textColor = [UIColor colorWithRed:0.30 green:.92 blue:1 alpha:1];
      pt.text = @"⚡ POWERTRAIN & HV • 7E3";
      [pCard addSubview:pt];

      UILabel *pb = [[UILabel alloc] initWithFrame:CGRectMake(10, 34, rightW - 36, 74)];
      pb.tag = 703;
      pb.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightSemibold];
      pb.adjustsFontSizeToFitWidth = YES;
      pb.minimumScaleFactor = 0.85;
      pb.textColor = [UIColor whiteColor];
      pb.numberOfLines = 3;
      pb.text = @"HV SOC: 64.5% (ระดับไฟปกติ)\nPACK: 227.4 V • ชาร์จ +12.4 A\n14 BLOCKS (28 NiMH MODULES)";
      [pCard addSubview:pb];
      [self.view addSubview:pCard];
    }
    pCard.backgroundColor = innerGlassBg;
    pCard.layer.cornerRadius = 12;
    pCard.layer.borderWidth = 1.0;
    pCard.layer.borderColor = innerGlassBorder;
    pCard.hidden = NO;
    pCard.frame = CGRectMake(rightX + 10, topY + 8, rightW - 20, 224);
    UILabel *ptLbl = (UILabel *)[pCard viewWithTag:702];
    if (ptLbl) {
      ptLbl.frame = CGRectMake(10, 8, rightW - 36, 22);
      ptLbl.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
      ptLbl.textColor = accent;
      ptLbl.text = @"⚡ POWERTRAIN & HV • 7EA";
    }
    UILabel *pbLbl = (UILabel *)[pCard viewWithTag:703];
    if (pbLbl) {
      pbLbl.frame = CGRectMake(10, 34, rightW - 36, 74);
      pbLbl.font = [UIFont monospacedDigitSystemFontOfSize:13.0 weight:UIFontWeightSemibold];
    }

    self.blockGraphView.hidden = NO;
    self.blockGraphView.frame = CGRectMake(rightX + 18, topY + 124, rightW - 36, 64);

    UILabel *deltaL = (UILabel *)[self.view viewWithTag:706];
    if (!deltaL) {
      deltaL = [[UILabel alloc] init];
      deltaL.tag = 706;
      deltaL.adjustsFontSizeToFitWidth = YES;
      deltaL.minimumScaleFactor = 0.85;
      deltaL.textColor = [UIColor colorWithRed:.35 green:.98 blue:.55 alpha:1];
      deltaL.text = @"ΔV: -- V • Waiting 2181...";
      [self.view addSubview:deltaL];
    }
    deltaL.font = [UIFont monospacedDigitSystemFontOfSize:12.5 weight:UIFontWeightSemibold];
    deltaL.hidden = NO;
    deltaL.frame = CGRectMake(rightX + 18, topY + 196, rightW - 36, 24);

    // Right Card 2: 3 Motor Rows (Y = topY + 240, H = 178, exact mirror of homeAiEcoCard!)
    UIView *mCard = [self.view viewWithTag:707];
    if (!mCard) {
      mCard = [[UIView alloc] init];
      mCard.tag = 707;
      mCard.userInteractionEnabled = YES;
      UITapGestureRecognizer *mTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tractionMotorTapped)];
      [mCard addGestureRecognizer:mTap];

      UILabel *ml = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, rightW - 36, 166)];
      ml.tag = 708;
      ml.userInteractionEnabled = NO;
      ml.adjustsFontSizeToFitWidth = YES;
      ml.minimumScaleFactor = 0.85;
      ml.textColor = [UIColor whiteColor];
      ml.numberOfLines = 6;
      ml.text = @"⚙️ TRACTION MOTOR MG2 (แตะดู)\n     0 RPM  •  --\n⚡ GENERATOR MG1\n     0 RPM  •  --\n🌡️ HV BATTERY TEMP\n     -- °C  •  ICE: 0 RPM";
      [mCard addSubview:ml];
      [self.view addSubview:mCard];
    }
    mCard.backgroundColor = innerGlassBg;
    mCard.layer.cornerRadius = 12;
    mCard.layer.borderWidth = 1.0;
    mCard.layer.borderColor = innerGlassBorder;
    mCard.hidden = NO;
    mCard.frame = CGRectMake(rightX + 10, topY + 240, rightW - 20, 178);
    UILabel *mlLbl = (UILabel *)[mCard viewWithTag:708];
    if (mlLbl) {
      mlLbl.frame = CGRectMake(10, 6, rightW - 36, 166);
      mlLbl.font = [UIFont monospacedDigitSystemFontOfSize:14.0 weight:UIFontWeightSemibold];
      mlLbl.adjustsFontSizeToFitWidth = YES;
      mlLbl.minimumScaleFactor = 0.88;
    }

    // Right Card 3: GPS Trip Computer & Range (Y = topY + 426, H = 186, exact mirror of homeThermalsCard!)
    UIView *tCard = [self.view viewWithTag:711];
    if (!tCard) {
      tCard = [[UIView alloc] init];
      tCard.tag = 711;
      tCard.userInteractionEnabled = YES;

      NSArray *htNames = @[@"TRIP A", @"TRIP B", @"TRIP C"];
      CGFloat hTabW = (rightW - 20 - 20 - 10) / 3.0;
      for (int i = 0; i < 3; i++) {
        UIButton *htb = [UIButton buttonWithType:UIButtonTypeCustom];
        htb.tag = 740 + i;
        htb.frame = CGRectMake(10 + i * (hTabW + 5), 8, hTabW, 26);
        [htb setTitle:htNames[i] forState:UIControlStateNormal];
        htb.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
        htb.layer.cornerRadius = 8;
        htb.layer.borderWidth = 1.0;
        [htb addTarget:self action:@selector(homeTripSlotTapped:) forControlEvents:UIControlEventTouchUpInside];
        [tCard addSubview:htb];
      }

      UILabel *tb = [[UILabel alloc] initWithFrame:CGRectMake(10, 38, rightW - 36, 142)];
      tb.tag = 713;
      tb.adjustsFontSizeToFitWidth = YES;
      tb.minimumScaleFactor = 0.82;
      tb.textColor = [UIColor whiteColor];
      tb.numberOfLines = 6;
      tb.userInteractionEnabled = YES;
      [tb addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resetTripMenu)]];
      [tCard addSubview:tb];
      [self.view addSubview:tCard];
    }
    tCard.backgroundColor = innerGlassBg;
    tCard.layer.cornerRadius = 12;
    tCard.layer.borderWidth = 1.0;
    tCard.layer.borderColor = [accent colorWithAlphaComponent:0.32].CGColor;
    tCard.hidden = NO;
    tCard.frame = CGRectMake(rightX + 10, topY + 426, rightW - 20, 186);
    UILabel *tbLbl = (UILabel *)[tCard viewWithTag:713];
    if (tbLbl) {
      tbLbl.frame = CGRectMake(10, 38, rightW - 36, 142);
      tbLbl.numberOfLines = 6;
      tbLbl.font = [UIFont monospacedDigitSystemFontOfSize:14.0 weight:UIFontWeightSemibold];
      tbLbl.adjustsFontSizeToFitWidth = YES;
      tbLbl.minimumScaleFactor = 0.88;
    }
    [self refreshDriveTripDisplay];

    // Bottom Navigation Bar
    self.navigation.hidden = self.focused;
    self.navigation.frame = CGRectMake(0, fullH - 78, w, 78);
    self.navigation.backgroundColor = [UIColor colorWithRed:0.024 green:0.038 blue:0.062 alpha:0.98];
    CGFloat nw = (w - 24) / self.navButtons.count;
    for (int i = 0; i < self.navButtons.count; i++) {
      UIButton *b = self.navButtons[i];
      BOOL active = (i == 0);
      b.clipsToBounds = YES;
      b.layer.cornerRadius = 10;
      b.frame = CGRectMake(12 + i * nw, 9, nw - 4, 60);
      b.backgroundColor = active ? [accent colorWithAlphaComponent:.16] : [UIColor clearColor];
      [b viewWithTag:201].frame = CGRectMake(b.bounds.size.width/2 - 44, 16, 26, 26);
      UILabel *t = (UILabel *)[b viewWithTag:202];
      t.font = [UIFont systemFontOfSize:13.5 weight:(active ? UIFontWeightBold : UIFontWeightSemibold)];
      t.adjustsFontSizeToFitWidth = YES;
      t.minimumScaleFactor = 0.85;
      t.frame = CGRectMake(b.bounds.size.width/2 - 14, 16, MAX(40, b.bounds.size.width/2 + 8), 28);
      t.textColor = active ? [UIColor whiteColor] : [UIColor colorWithWhite:0.86 alpha:1];
      [b viewWithTag:203].backgroundColor = accent;
      [b viewWithTag:203].hidden = !active;
      [b viewWithTag:203].frame = CGRectMake(14, 56, b.bounds.size.width - 28, 2.5);
    }

    // Bring subviews to front for Home Dashboard
    [self.view bringSubviewToFront:self.driveLeftCard];
    [self.view bringSubviewToFront:self.driveRightCard];
    if (hTopPod) [self.view bringSubviewToFront:hTopPod];
    if (hCenterTopCard) [self.view bringSubviewToFront:hCenterTopCard];
    [self.view bringSubviewToFront:self.heading];
    [self.view bringSubviewToFront:self.owner];
    [self.view bringSubviewToFront:self.topClockLabel];
    [self.view bringSubviewToFront:self.obdStatusPill];
    [self.view bringSubviewToFront:self.dayNightPill];
    [self.view bringSubviewToFront:self.thaiVoicePill];
    [self.view bringSubviewToFront:self.settingsPill];
    [self.view bringSubviewToFront:self.helpPill];
    [self.view bringSubviewToFront:self.readyPill];
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
    [self.view bringSubviewToFront:self.homeCarLightBeams];
    [self.view bringSubviewToFront:self.doorDiagramView];
    [self.view bringSubviewToFront:self.flowBeamLine];
    [self.view bringSubviewToFront:self.compassLabel];
    [self.view bringSubviewToFront:self.carStatus];
    [self.view bringSubviewToFront:self.nowPanel];
    [self.view bringSubviewToFront:self.artwork];
    [self.view bringSubviewToFront:self.artPlaceholder];
    [self.view bringSubviewToFront:self.song];
    [self.view bringSubviewToFront:self.artist];
    [self.view bringSubviewToFront:self.trackProgress];
    [self.view bringSubviewToFront:self.trackTime];
    [self.view bringSubviewToFront:self.controls];
    [self.view bringSubviewToFront:self.driveEQ];
    [self.view bringSubviewToFront:self.searchMusicBtn];
    if (pCard) [self.view bringSubviewToFront:pCard];
    [self.view bringSubviewToFront:self.blockGraphView];
    if (deltaL) [self.view bringSubviewToFront:deltaL];
    if (mCard) [self.view bringSubviewToFront:mCard];
    if (tCard) [self.view bringSubviewToFront:tCard];
    [self.view bringSubviewToFront:self.navigation];
    [self refreshLiveOBDDashboard];
  }

  if (self.tripSummaryCard) {
    self.tripSummaryCard.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.tripSummaryCard];
  }

  if (self.obdAlertBanner) {
    CGFloat bw = MIN(380, self.view.bounds.size.width - 40);
    self.obdAlertBanner.frame = CGRectMake((self.view.bounds.size.width - bw) * 0.5, 14, bw, 34);
    [self.view bringSubviewToFront:self.obdAlertBanner];
  }

  if (self.welcome) {
    self.welcome.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.welcome];
  }

  if (self.settingsSheet) {
    self.settingsSheet.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.settingsSheet];
  }

  if (self.featureExplanationBanner) {
    self.featureExplanationBanner.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.featureExplanationBanner];
  }
}

-(void)update{
  gTRDUpdateTicks++;
  if(self.featureExplanationBanner && gTRDFeatureBannerShownAt>0 && ([NSProcessInfo processInfo].systemUptime-gTRDFeatureBannerShownAt)>9.0)[self hideFeatureExplanation];
  if([UIApplication sharedApplication].applicationState==UIApplicationStateActive){
    while([UIApplication sharedApplication].isIgnoringInteractionEvents)[[UIApplication sharedApplication] endIgnoringInteractionEvents];
    self.view.userInteractionEnabled=YES;
  }

  if(self.driveClockCard && !self.driveClockCard.hidden){
    UILabel *cBig=(UILabel *)[self.driveClockCard viewWithTag:801];
    NSString *dc=self.clockFormat?[self.clockFormat stringFromDate:[NSDate date]]:nil;
    if(cBig && dc && ![cBig.text isEqualToString:dc])cBig.text=dc;
  }
  if(self.topClockLabel && !self.topClockLabel.hidden){
    NSString *tc = [self.clockFormat stringFromDate:[NSDate date]];
    if(![self.topClockLabel.text isEqualToString:tc]) self.topClockLabel.text = tc;
  }
  if(self.obdStatusPill && !self.obdStatusPill.hidden){
    TRDOBDClient *obd = [TRDOBDClient sharedClient];
    BOOL live = obd.isConnected;
    NSString *obdTitle = live ? @"OBD2 LIVE" : @"OBD2 SCAN";
    UIColor *obdTint = live ? [UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] : [UIColor colorWithRed:1.0 green:0.78 blue:0.30 alpha:1.0];
    if(![self.obdStatusPill.currentTitle isEqualToString:obdTitle]){
      [self.obdStatusPill setImage:TRDAutoVectorIcon(1, 16.0, obdTint) forState:UIControlStateNormal];
      self.obdStatusPill.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 6);
      [self.obdStatusPill setTitle:obdTitle forState:UIControlStateNormal];
      [self.obdStatusPill setTitleColor:obdTint forState:UIControlStateNormal];
      self.obdStatusPill.backgroundColor = live
        ? [UIColor colorWithRed:0.04 green:0.22 blue:0.12 alpha:0.95]
        : [UIColor colorWithRed:0.14 green:0.09 blue:0.04 alpha:0.95];
      self.obdStatusPill.layer.borderColor = (live
        ? [UIColor colorWithRed:0.20 green:0.92 blue:0.50 alpha:0.8]
        : [UIColor colorWithRed:0.95 green:0.65 blue:0.20 alpha:0.6]).CGColor;
    }
  }
  if(self.dayNightPill && !self.dayNightPill.hidden){
    NSString *dnTitle = self.driveMode ? (self.nightMode?@"🌙 กลางคืน":@"☀️ กลางวัน") : (self.nightMode?@"🌙 NIGHT":@"☀️ DAY");
    if(![self.dayNightPill.currentTitle isEqualToString:dnTitle]){
      [self.dayNightPill setTitle:dnTitle forState:UIControlStateNormal];
    }
  }
  [self updateDrive12VPill];

 NSDate *now=[NSDate date];
 NSString *newClock=[self.clockFormat stringFromDate:now];
 if(![self.clock.text isEqualToString:newClock]){
  self.clock.text=newClock;
  self.date.text=[self.dateFormat stringFromDate:now];
 }
 UIDeviceBatteryState currentPower=[UIDevice currentDevice].batteryState;
 BOOL curPowered=(currentPower==UIDeviceBatteryStateCharging||currentPower==UIDeviceBatteryStateFull);
 static UIDeviceBatteryState previousPower=UIDeviceBatteryStateUnknown;
 if(previousPower!=UIDeviceBatteryStateUnknown && previousPower!=currentPower){
  BOOL prevPowered=(previousPower==UIDeviceBatteryStateCharging||previousPower==UIDeviceBatteryStateFull);
  if(prevPowered != curPowered){
   [self batteryStateChanged:nil];
  }
 }
 previousPower=currentPower;
 if(self.carplayMode){
  if(![self.carplayClock.text isEqualToString:self.clock.text])self.carplayClock.text=self.clock.text;
  if(!self.carplayGridMode&&(self.ticks%2==0))[self updateMapCar];
  if(!self.carplayGridMode&&self.carplayTelemetryWidget){
   NSString *speedVal=(self.gpsLive&&self.speed.text.length&&![self.speed.text isEqualToString:@"--"])?self.speed.text:@"--";
   NSString *speedUnit=self.gpsLive?@"km/h  •  GPS LIVE":@"km/h  •  WAITING FOR GPS";
   BOOL courseKnown=self.gpsLive&&self.fix.course>=0&&self.fix.course<360&&self.fix.speed>=1.4&&self.fix.horizontalAccuracy<=25&&fabs([self.fix.timestamp timeIntervalSinceNow])<5;
   NSString *compass=courseKnown?[NSString stringWithFormat:@"COURSE  %.0f°",self.fix.course]:@"COURSE  --";
   NSString *cTrip=[NSString stringWithFormat:@"TRIP  %.1f km",self.trip.meters/1000.0];
   if(![self.carplayTelemetryWidget.speedLabel.text isEqualToString:speedVal])self.carplayTelemetryWidget.speedLabel.text=speedVal;
   if(![self.carplayTelemetryWidget.speedUnitLabel.text isEqualToString:speedUnit])self.carplayTelemetryWidget.speedUnitLabel.text=speedUnit;
   if(![self.carplayTelemetryWidget.compassLabel.text isEqualToString:compass])self.carplayTelemetryWidget.compassLabel.text=compass;
   if(![self.carplayTelemetryWidget.tripMetricsLabel.text isEqualToString:cTrip])self.carplayTelemetryWidget.tripMetricsLabel.text=cTrip;
  }
  if(!self.carplayGridMode&&self.carplayMediaWidget){
   NSString *cpTitle=self.song.text.length?self.song.text:@"Choose your music";
   NSString *cpArtist=self.artist.text.length?self.artist.text:@"Tap here to choose music / Radio / YouTube";
   NSString *cpBadge=[NSString stringWithFormat:@"%@ ▾",self.sourceBadge.text.length?self.sourceBadge.text:@"MUSIC"];
   if(![self.carplayMediaWidget.titleLabel.text isEqualToString:cpTitle])self.carplayMediaWidget.titleLabel.text=cpTitle;
   if(![self.carplayMediaWidget.artistLabel.text isEqualToString:cpArtist])self.carplayMediaWidget.artistLabel.text=cpArtist;
   if(![self.carplayMediaWidget.sourceBadge.text isEqualToString:cpBadge])self.carplayMediaWidget.sourceBadge.text=cpBadge;
   if(self.carplayMediaWidget.artworkView.image!=self.artwork.image)self.carplayMediaWidget.artworkView.image=self.artwork.image;
   self.carplayMediaWidget.artPlaceholder.hidden=(self.artwork.image!=nil);
   self.carplayMediaWidget.progressBar.progress=self.trackProgress.progress;
   if(![self.carplayMediaWidget.timeCurLabel.text isEqualToString:self.trackTime.text])self.carplayMediaWidget.timeCurLabel.text=self.trackTime.text;
  }
 }
 self.ticks++;if(self.ticks%3==0 && !self.isReverseActive && !self.voiceListening && [UIApplication sharedApplication].applicationState==UIApplicationStateActive)[[TRDFrontGestureEngine sharedEngine] ensureRunning];if(self.ticks%60==1)[self applyDisplaySchedule];if(self.ticks%30==0)[self saveTrip];[self refreshSpeed];if(!self.mapMode && !self.focused)[self refreshTrackProgress];if(self.mapMode&&!self.carplayMode)[self updateMapCar];
 NSUInteger netStride = (self.carplayMode || self.mapMode) ? 15 : 5;
 if(self.ticks%netStride==1){
  float level=[UIDevice currentDevice].batteryLevel;UIDeviceBatteryState power=currentPower;NSString *battery=level<0?@"—":[NSString stringWithFormat:@"%.0f%%",level*100];BOOL bt=[self.bluetooth respondsToSelector:@selector(enabled)]?[self.bluetooth enabled]:NO;
  NSString *weatherStr=self.currentTemperature>0?[NSString stringWithFormat:@" • %.0f°C%@",self.currentTemperature,self.rainDetected?@" 🌧️":@" ☀️"]:@"";
  static dispatch_queue_t sWifiQueryQ=nil;
  static dispatch_once_t wifiQOnce;
  dispatch_once(&wifiQOnce,^{sWifiQueryQ=dispatch_queue_create("com.codex.cardash.wifiq",DISPATCH_QUEUE_SERIAL);});
  __weak Dashboard *weakWifiSelf=self;
  dispatch_async(sWifiQueryQ,^{
   NSDictionary *net=CFBridgingRelease(CNCopyCurrentNetworkInfo(CFSTR("en0")));
   NSString *ssid=[net[@"SSID"] isKindOfClass:[NSString class]]?net[@"SSID"]:nil;
   dispatch_async(dispatch_get_main_queue(),^{
    Dashboard *d=weakWifiSelf;
    if(!d)return;
    NSString *newNet=[NSString stringWithFormat:@"%@ • BT %@ • %@%@%@",ssid?:@"No Wi-Fi",bt?@"ON":@"OFF",battery,(power==UIDeviceBatteryStateCharging||power==UIDeviceBatteryStateFull)?@" +":@"",weatherStr];
    if(![d.network.text isEqualToString:newNet])d.network.text=newNet;
    d.statusWiFi=ssid?:@"NO NETWORK";
    if(d.carplayMode){
     NSString *cBat=[NSString stringWithFormat:@"⚡ %@",battery];if(![d.carplayBattery.text isEqualToString:cBat])d.carplayBattery.text=cBat;
     if(![d.carplayWifi.text isEqualToString:d.statusWiFi])d.carplayWifi.text=d.statusWiFi;
    }
   });
  });
  self.statusPower=level<0?@"UNKNOWN":[NSString stringWithFormat:@"%@ %.0f%%",(power==UIDeviceBatteryStateCharging)?@"CHG":(power==UIDeviceBatteryStateFull)?@"FULL":@"BAT",level*100];
  if(!self.carplayMode && !self.mapMode && !self.focused){
   [self refreshCarStatus];
   [self refreshAudioRoute];
   [self refreshStatusStrip];
  }
  [self refreshNowPlaying];
  [self checkBatteryHealthGuard];
 }
 [self applyMotionPolicy];[self refreshTrip];
 if(self.mapMode || self.carplayMode){
  self.lastMapVisibleAt=[NSProcessInfo processInfo].systemUptime;
 }else if(self.mapWebView && self.lastMapVisibleAt>0 && ([NSProcessInfo processInfo].systemUptime-self.lastMapVisibleAt)>=20.0){
  self.lastMapVisibleAt=0;
  [self teardownMapWebView];
  [[NSURLCache sharedURLCache] removeAllCachedResponses];
  [[TRDOBDClient sharedClient] obdLog:@"MEM reclaimed idle mapWebView after 20s"];
 }
 if(!self.carplayMode && !self.mapMode && !self.focused){
  [self refreshDriveTripDisplay];[self refreshMini];[self refreshBrakeStatus];
 }
 [self refreshLiveOBDDashboard];
 {
  TRDOBDClient *hObd=[TRDOBDClient sharedClient];
  double gpsKmh=(self.fix && self.fix.speed>=0)?(self.fix.speed*3.6):0.0;
  double hSpd=(hObd.isConnected && hObd.obdInitialized)?MAX(0.0,hObd.currentSpeedKmh):gpsKmh;
  [hObd evaluateAutoDoorLockForSpeed:(CGFloat)MAX(hSpd, gpsKmh)];
  NSString *hGear=hObd.currentGear.length?hObd.currentGear:(hSpd>=1.0?@"D":@"P");
  double hSoc=(hObd.hybridBatterySOC>0.5)?hObd.hybridBatterySOC:72.0;
  double hEct=(hObd.coolantTempC>1.0)?hObd.coolantTempC:86.0;
  double hAux=(hObd.auxBatteryVoltage>5.0)?hObd.auxBatteryVoltage:13.8;
  double hKmL=[self effectiveFuelKmPerL];
  double hTripKm=self.trip?(self.trip.meters/1000.0):0.0;
  double hPrice=(hObd.fuelPricePerLiter>5.0)?hObd.fuelPricePerLiter:38.14;
  double hFuelL=(hObd.hasLiveMAFFuel && hObd.tripFuelUsedLiters>0.005)?hObd.tripFuelUsedLiters:(hKmL>1.0?(hTripKm/hKmL):0.0);
  double hCost=hFuelL*hPrice;
  NSString *hMode=(hObd.engineRPM>350)?((hSpd>80.0)?@"HYBRID POWER":@"ENGINE DRIVE"):((hObd.hvPackCurrent<-2.0)?@"REGEN CHARGE":@"EV ELECTRIC");
  NSString *hNavArrow=@"↑";
  NSString *hNavDist=self.gpsStatus.text.length?self.gpsStatus.text:@"GPS LIVE";
  NSString *hNavSub=@"AUTO SYNC • PRIUS TRD";
  NSString *hNavStreet=@"พร้อมขับขี่ • ซิงก์พิกัดสดจาก iPad";
  BOOL mapNavLive=NO;
  if((self.mapMode || self.carplayMode) && self.mapWebView && self.mapWebView.request && !self.mapWebView.loading && (self.ticks%2==0)){
   NSString *navJS=@"(function(){if(window.navActive){var st=(window.navSteps&&window.navSteps[window.currentStepIdx])||{};var m=st.maneuver||{};var mod=(m.modifier||m.type||'straight').toLowerCase();var d=(document.getElementById('nav-dist-next')||{}).innerText||'';var s=(document.getElementById('nav-street')||{}).innerText||'';var dt=(document.getElementById('dest-title')||{}).innerText||'';var sm=(document.getElementById('nav-summary')||{}).innerText||'';return '1|'+mod+'|'+d+'|'+s+'|'+dt+'|'+sm;}return '0|||||';})()";
   NSString *res=[self.mapWebView stringByEvaluatingJavaScriptFromString:navJS];
   NSArray *parts=[res componentsSeparatedByString:@"|"];
   if(parts.count>=6 && [parts[0] isEqualToString:@"1"]){
    mapNavLive=YES;
    NSString *mod=parts[1];
    if([mod containsString:@"uturn"])hNavArrow=@"⤵";
    else if([mod containsString:@"slight left"])hNavArrow=@"↖";
    else if([mod containsString:@"slight right"])hNavArrow=@"↗";
    else if([mod containsString:@"left"])hNavArrow=@"↰";
    else if([mod containsString:@"right"])hNavArrow=@"↱";
    else if([mod containsString:@"arrive"])hNavArrow=@"🏁";
    else hNavArrow=@"↑";
    if([parts[2] length]>0)hNavDist=parts[2];
    NSString *destTitle=parts[4];
    NSString *sumTxt=parts[5];
    if(destTitle.length>0)hNavSub=[NSString stringWithFormat:@"🏁 %@",destTitle];
    else if(sumTxt.length>0)hNavSub=sumTxt;
    if([parts[3] length]>0)hNavStreet=parts[3];
    else if(sumTxt.length>0)hNavStreet=sumTxt;
   }
  }
  if(!mapNavLive && self.fix && self.fix.course>=0 && self.fix.course<360){
   static NSString *const dirs[8]={@"N",@"NE",@"E",@"SE",@"S",@"SW",@"W",@"NW"};
   NSInteger dIdx=((NSInteger)floor((self.fix.course+22.5)/45.0))%8;
   hNavSub=[NSString stringWithFormat:@"COMPASS %@ %.0f°",dirs[dIdx],self.fix.course];
  }
  NSString *hTrip=[NSString stringWithFormat:@"TRIP %.1f KM", hTripKm];
  NSString *hWeather=self.currentTemperature>0?[NSString stringWithFormat:@"%.0f°C%@",self.currentTemperature,self.rainDetected?@" 🌧️":@" ☀️"]:@"";
  NSDictionary *hudLive=@{
   @"speed":@(hSpd),
   @"gear":hGear,
   @"clock":self.clock.text?:@"",
   @"trip":hTrip,
   @"weather":hWeather,
   @"fuelCost":[NSString stringWithFormat:@"%.1f",hCost],
   @"kmPerL":[NSString stringWithFormat:@"%.1f",hKmL],
   @"navActive":@(mapNavLive),
   @"navArrow":hNavArrow,
   @"navDist":hNavDist,
   @"navSub":hNavSub,
   @"navStreet":hNavStreet,
   @"soc":@((NSInteger)llround(hSoc)),
   @"ect":@((NSInteger)llround(hEct)),
   @"aux12v":[NSString stringWithFormat:@"%.1f",hAux],
   @"hybridMode":hMode,
   @"song":self.song.text?:@"",
   @"artist":self.artist.text?:@""
  };
  static NSDictionary *sLastHudLive=nil;
  static CFAbsoluteTime sLastHudWriteAt=0;
  static dispatch_queue_t sHudIOQueue=nil;
  static dispatch_once_t hudIOOnce;
  dispatch_once(&hudIOOnce,^{sHudIOQueue=dispatch_queue_create("com.codex.cardash.hudio",DISPATCH_QUEUE_SERIAL);});
  CFAbsoluteTime nowHud=CFAbsoluteTimeGetCurrent();
  if(!sLastHudLive || ![hudLive isEqualToDictionary:sLastHudLive] || (nowHud-sLastHudWriteAt)>=5.0){
   sLastHudLive=hudLive;
   sLastHudWriteAt=nowHud;
   dispatch_async(sHudIOQueue,^{
    [hudLive writeToFile:@"/var/mobile/codex-car/hud-live.plist" atomically:YES];
   });
  }
 }
}
-(void)refreshNowPlaying{
 if(self.radioPlayer){
  if(self.offlinePlaybackActive){
   self.sourceBadge.text=@"OFFLINE";
   AVPlayerItemStatus st=self.radioPlayer.currentItem.status;
   NSString *artistLine=self.currentOfflineArtist.length?self.currentOfflineArtist:@"OFFLINE MUSIC";
   if(st==AVPlayerItemStatusFailed){
    self.song.text=[NSString stringWithFormat:@"[ERROR] %@",self.currentRadioStation?:@"Offline Track"];
    self.artist.text=@"Cannot open local audio file";
   }else if(self.radioPlayer.rate>0||st==AVPlayerItemStatusUnknown){
    self.song.text=self.currentRadioStation?:@"Offline Music";
    self.artist.text=artistLine;
   }else{
    self.song.text=[NSString stringWithFormat:@"[PAUSED] %@",self.currentRadioStation?:@"Offline Music"];
    self.artist.text=@"Tap Play button to resume";
   }
   return;
  }
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
 double now=TRDMonotonic();if(self.metadataPending&&now-self.metadataRequestedAt<3.0)return;
 self.metadataPending=YES;self.metadataRequestedAt=now;NSUInteger generation=++self.metadataGeneration;__weak Dashboard *weak=self;
 void (*owner)(dispatch_queue_t,void (^)(int))=dlsym(RTLD_DEFAULT,"MRMediaRemoteGetNowPlayingApplicationPID");if(owner)owner(dispatch_get_main_queue(),^(int pid){Dashboard *v=weak;if(!v||generation!=v.metadataGeneration)return;if(pid>0&&pid!=getpid()){int (*pathfn)(int,void *,uint32_t)=dlsym(RTLD_DEFAULT,"proc_pidpath");char path[4096];path[0]=0;v.youtubeSource=pathfn&&pathfn(pid,path,sizeof(path))>0&&[[[NSString stringWithUTF8String:path]lastPathComponent]isEqualToString:@"YTNine"];}});

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
 if(self.carplayMediaWidget && self.carplayMediaWidget.btnPlay){
  NSString *cpPlayTitle = (targetKind == 14) ? @"❚❚  PAUSE" : @"▶  PLAY";
  if(![self.carplayMediaWidget.btnPlay.currentTitle isEqualToString:cpPlayTitle]){
   [self.carplayMediaWidget.btnPlay setTitle:cpPlayTitle forState:UIControlStateNormal];
  }
 }
 [self refreshMini];
}
-(void)refreshCarStatus{
 BOOL hasEnabled=[self.bluetooth respondsToSelector:@selector(enabled)];BOOL bt=hasEnabled?[self.bluetooth enabled]:NO;NSArray *devices=[self.bluetooth respondsToSelector:@selector(pairedDevices)]?[self.bluetooth pairedDevices]:nil;BOOL paired=NO,known=NO,connected=NO;
 id carDevice=nil;
 if([devices isKindOfClass:[NSArray class]])for(id device in devices){NSString *name=[device respondsToSelector:@selector(name)]?[device name]:nil;if([name isKindOfClass:[NSString class]]&&[name caseInsensitiveCompare:@"CAR MULTIMEDIA"]==NSOrderedSame){paired=YES;carDevice=device;if([device respondsToSelector:@selector(connected)]){known=YES;connected=[device connected];}break;}}
 self.statusCar=!hasEnabled?@"UNKNOWN":!bt?@"BT OFF":![devices isKindOfClass:[NSArray class]]?@"UNKNOWN":!paired?@"NOT PAIRED":!known?@"UNKNOWN":connected?@"CONNECTED":@"DISCONNECTED";
 // Proactive fast reconnect to Toyota Prius "CAR MULTIMEDIA" Bluetooth speaker when powered/active!
 static NSTimeInterval sLastCarBTConnectAt=0;
 UIDeviceBatteryState batNow=[UIDevice currentDevice].batteryState;
 BOOL inCarPower=(batNow==UIDeviceBatteryStateCharging||batNow==UIDeviceBatteryStateFull);
 NSTimeInterval upNow=[NSProcessInfo processInfo].systemUptime;
 if(bt && paired && carDevice && !connected && (inCarPower || sLastCarBTConnectAt==0) && (upNow - sLastCarBTConnectAt) >= 8.0){
  sLastCarBTConnectAt=upNow;
  if([carDevice respondsToSelector:@selector(connect)]){
   [carDevice performSelector:@selector(connect)];
  }else if([self.bluetooth respondsToSelector:@selector(connectDevice:)]){
   [self.bluetooth performSelector:@selector(connectDevice:) withObject:carDevice];
  }
 }
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
 static NSDictionary *cachedSrc=nil;
 static NSDictionary *cachedCfg=nil;
 static NSTimeInterval lastConfigRead=0;
 NSTimeInterval nowSec=[[NSDate date]timeIntervalSinceReferenceDate];
 if(!cachedSrc||(nowSec-lastConfigRead>1.0)){
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
 NSUInteger newLen=data.length, newSig=0;
 if(newLen>0){
  const uint8_t *b=(const uint8_t *)data.bytes;
  NSUInteger step=MAX((NSUInteger)1, newLen/64);
  NSUInteger h=1469598103934665603ULL ^ newLen;
  for(NSUInteger idx=0;idx<newLen;idx+=step){h=(h ^ b[idx]) * 1099511628211ULL;}
  h=(h ^ b[newLen-1]) * 1099511628211ULL;
  newSig=h;
 }
 BOOL dataDiff=(newLen!=self.artworkLen)||(newSig!=self.artworkSig);
 if(dataDiff&&(newLen>0||self.artworkLen>0)){
  self.artworkLen=newLen;self.artworkSig=newSig;self.artworkData=nil;UIImage *image=nil;
  if(data.length){CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache:@NO});
   if(source){NSDictionary *options=@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@256,(__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES};CGImageRef thumb=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)options);if(thumb){image=[UIImage imageWithCGImage:thumb];CGImageRelease(thumb);self.artworkDecodes++;}CFRelease(source);}}
  self.artwork.image=image;
 }
 self.artPlaceholder.hidden=self.focused||self.artwork.image!=nil;
}
-(void)releaseArtwork{self.artwork.image=nil;self.artworkData=nil;self.artworkLen=0;self.artworkSig=0;self.artPlaceholder.hidden=self.focused;}
-(void)didReceiveMemoryWarning{[super didReceiveMemoryWarning];self.memoryWarnings++;[self releaseArtwork];[[NSURLCache sharedURLCache]removeAllCachedResponses];[self hideWelcome];[self.settingsSheet dismiss];if(!self.mapMode&&!self.carplayMode&&self.mapWebView){[self.mapWebView stopLoading];[self.mapWebView removeFromSuperview];self.mapWebView.delegate=nil;self.mapWebView=nil;}}
-(NSString *)trackTimeString:(double)value{if(!isfinite(value)||value<0)return @"--:--";long long n=(long long)value;return n>=3600?[NSString stringWithFormat:@"%lld:%02lld:%02lld",n/3600,n/60%60,n%60]:[NSString stringWithFormat:@"%lld:%02lld",n/60,n%60];}
-(void)refreshTrackProgress{
 if(self.radioPlayer){
  AVPlayerItem *item=self.radioPlayer.currentItem;
  CMTime dur=item?item.duration:kCMTimeInvalid;
  CMTime cur=self.radioPlayer.currentTime;
  double durSec=CMTIME_IS_NUMERIC(dur)?CMTimeGetSeconds(dur):0;
  double curSec=CMTIME_IS_NUMERIC(cur)?MAX(0,CMTimeGetSeconds(cur)):0;
  if(isfinite(durSec)&&durSec>0){
   curSec=MIN(curSec,durSec);
   double remSec=MAX(0,durSec-curSec);
   NSString *tStr=[NSString stringWithFormat:@"เล่นไป %@ / %@ (เหลือ -%@)",[self trackTimeString:curSec],[self trackTimeString:durSec],[self trackTimeString:remSec]];
   if(![self.trackTime.text isEqualToString:tStr])self.trackTime.text=tStr;
   self.trackProgress.progress=MAX(0,MIN(1,curSec/durSec));
   return;
  }
  if(![self.trackTime.text isEqualToString:@"LIVE STREAM · ON AIR"]){
   self.trackTime.text=@"LIVE STREAM · ON AIR";
   self.trackProgress.progress=1.0;
  }
  return;
 }
 double elapsed=self.hasElapsed?self.mediaElapsed:0;
 if(self.hasElapsed&&self.mediaTimestamp&&self.mediaRate>0){
  elapsed+=MAX(0,-[self.mediaTimestamp timeIntervalSinceNow])*self.mediaRate;
 }
 if(self.mediaDuration>0){
  elapsed=MIN(elapsed,self.mediaDuration);
 }
 double remaining=(self.mediaDuration>0)?MAX(0,self.mediaDuration-elapsed):0;
 NSString *newTime=nil;
 if(self.mediaDuration>0){
  newTime=[NSString stringWithFormat:@"เล่นไป %@ / %@ (เหลือ -%@)",[self trackTimeString:elapsed],[self trackTimeString:self.mediaDuration],[self trackTimeString:remaining]];
 }else if(self.hasElapsed){
  newTime=[NSString stringWithFormat:@"เล่นไป %@ / --:--",[self trackTimeString:elapsed]];
 }else{
  newTime=@"เวลาเพลง: 0:00 / --:-- (เหลือ -0:00)";
 }
 if(![self.trackTime.text isEqualToString:newTime]){
  self.trackTime.text=newTime;
 }
 self.trackProgress.progress=self.mediaDuration>0?MAX(0,MIN(1,elapsed/self.mediaDuration)):0;
}
-(void)applyEQPreset:(NSString *)presetName{
 if(!presetName.length)return;
 NSString *clean=[presetName hasPrefix:@"TRD "]?[presetName substringFromIndex:4]:presetName;
 NSString *title=[NSString stringWithFormat:@"🎚️ EQ • %@",[clean uppercaseString]];
 [self.driveEQ setTitle:title forState:UIControlStateNormal];
 [self.carplayEQBtn setTitle:title forState:UIControlStateNormal];
 NSString *srcPath=@"/var/mobile/codex-car/sound-source.plist";
 NSMutableDictionary *src=[NSMutableDictionary dictionaryWithContentsOfFile:srcPath]?:[NSMutableDictionary dictionary];
 src[@"preset"]=clean;
 [src writeToFile:srcPath atomically:YES];
 notify_post("com.codex.trd.eqe.apply");
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
-(void)toggleDrive{if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}[self.settingsSheet dismiss];self.mapContainer.hidden=YES;self.tripMode=NO;self.mapMode=NO;self.carplayMode=NO;self.carplayGridMode=NO;if(self.driveMode){self.autoDriveSuppressed=YES;self.movingSince=nil;self.manualDriveActive=NO;[self.driveCar stop];}else{TRDOBDClient *obdCur=[TRDOBDClient sharedClient];BOOL obdOk=(obdCur.isConnected&&obdCur.obdInitialized);double curSpd=obdOk?MAX(0.0,obdCur.currentSpeedKmh):((self.fix&&self.fix.speed>=0)?(self.fix.speed*3.6):0);self.manualDriveActive=(curSpd<15.0);}self.driveMode=!self.driveMode;self.musicMode=NO;self.focused=NO;self.returnTap.enabled=NO;[self.driveButton setTitle:self.driveMode?@"‹ DASHBOARD":@"DRIVE MODE" forState:UIControlStateNormal];[self.view setNeedsLayout];}
-(void)toggleNight{
 NSUserDefaults *prefs=[NSUserDefaults standardUserDefaults];
 if(!self.nightMode){CGFloat observed=[UIScreen mainScreen].brightness;if(observed>=.15)self.dayBrightness=observed;if(self.dayBrightness<.15)self.dayBrightness=.6;[prefs setDouble:self.dayBrightness forKey:@"dayBrightness"];[UIScreen mainScreen].brightness=MIN(self.dayBrightness,.12);self.nightMode=YES;}
 else{[UIScreen mainScreen].brightness=MAX(.25,MIN(1,self.dayBrightness));self.nightMode=NO;}
 [prefs setBool:self.nightMode forKey:@"nightMode"];[prefs synchronize];TRDLowLight=self.nightMode;[self applyTheme];[self.nightButton setTitle:self.nightMode?@"DAY MODE":@"NIGHT MODE" forState:UIControlStateNormal];[self syncMapAppearance:NO];
 if(self.homeCarLightBeams){self.homeCarLightBeams.hidden=YES;[self.homeCarLightBeams setNeedsDisplay];}
 if(self.driveCar&&self.driveCar.lightBeams){self.driveCar.lightBeams.hidden=YES;[self.driveCar.lightBeams setNeedsDisplay];}
}
-(void)captureGPSState{}
-(void)restartGPS{[self.gps stopUpdatingLocation];self.fix=nil;self.gpsError=nil;[self startGPS];[self captureGPSState];}
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{if(status==kCLAuthorizationStatusAuthorizedAlways||status==kCLAuthorizationStatusAuthorizedWhenInUse)[self startGPS];[self captureGPSState];}
-(void)startGPS{
 UIDeviceBatteryState bat=[UIDevice currentDevice].batteryState;
 BOOL powered=(bat==UIDeviceBatteryStateCharging||bat==UIDeviceBatteryStateFull);
 if(!powered && [UIApplication sharedApplication].applicationState==UIApplicationStateBackground){
  if([self.gps respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)])self.gps.allowsBackgroundLocationUpdates=NO;
  [self.gps stopUpdatingLocation];
  return;
 }
 self.gps.pausesLocationUpdatesAutomatically=!powered;
 self.gps.desiredAccuracy=kCLLocationAccuracyBestForNavigation;
 self.gps.distanceFilter=kCLDistanceFilterNone;
 self.gps.activityType=CLActivityTypeAutomotiveNavigation;
 if([self.gps respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)])self.gps.allowsBackgroundLocationUpdates=powered;
 CLAuthorizationStatus status=[CLLocationManager authorizationStatus];
 if(status==kCLAuthorizationStatusNotDetermined)[self.gps requestWhenInUseAuthorization];
 if(status!=kCLAuthorizationStatusDenied&&status!=kCLAuthorizationStatusRestricted)[self.gps startUpdatingLocation];
}
-(void)refreshClockHud{if(!self.clockHud)return;UIColor *c=TRDAccent();self.clockHud.layer.borderColor=[c colorWithAlphaComponent:.38].CGColor;[self.clockHud viewWithTag:401].backgroundColor=c;UILabel *hudSpeed=(UILabel *)[self.clockHud viewWithTag:402],*hudUnit=(UILabel *)[self.clockHud viewWithTag:403],*hudGps=(UILabel *)[self.clockHud viewWithTag:405],*hudAcc=(UILabel *)[self.clockHud viewWithTag:406],*hudTrip=(UILabel *)[self.clockHud viewWithTag:407];hudSpeed.text=self.speed.text?:@"--";hudSpeed.textColor=self.clock.textColor?:[UIColor whiteColor];hudUnit.textColor=c;hudGps.text=self.gpsStatus.text?:@"WAITING FOR GPS";hudGps.textColor=self.gpsLive?[UIColor colorWithRed:.30 green:self.nightMode?.58:.80 blue:.48 alpha:1]:[UIColor colorWithWhite:self.nightMode?.58:.76 alpha:1];hudAcc.text=(self.fix&&self.fix.horizontalAccuracy>=0)?[NSString stringWithFormat:@"ACCURACY ±%.0f m  •  %@",self.fix.horizontalAccuracy,self.gpsLive?@"SPEED LOCKED":@"NO SPEED VECTOR"]:@"SIGNAL  •  SEARCHING SATELLITES";hudTrip.text=self.trip.seconds>0?[NSString stringWithFormat:@"TRIP  %.2f km  •  MAX %.0f km/h",self.trip.meters/1000.0,self.trip.maximum]:(self.trip.running?@"TRIP  ARMED  •  WAITING FOR GPS":@"TRIP  AUTO  •  WAITING FOR MOVEMENT");hudTrip.textColor=c;}
-(void)refreshSpeed{
 CLAuthorizationStatus auth=[CLLocationManager authorizationStatus];NSDictionary *gps=TRDDriveGPSStatus(self.fix,[NSDate date],auth,self.hadGPSSpeed);BOOL valid=[gps[@"valid"]boolValue];if(valid)self.hadGPSSpeed=YES;
 double fixAge = self.fix ? fabs([[NSDate date] timeIntervalSinceDate:self.fix.timestamp]) : 999.0;
 double rawKmh = (valid && fixAge <= 6.0 && self.fix.speed >= 0) ? (self.fix.speed * 3.6) : 0.0;
 double kmh = (rawKmh < 1.5) ? 0.0 : rawKmh;
 TRDOBDClient *obdSpd = [TRDOBDClient sharedClient];
 BOOL obdLive = (obdSpd.isConnected && obdSpd.obdInitialized);
 if (obdLive) {
  kmh = MAX(0.0, obdSpd.currentSpeedKmh);
 }
 BOOL reliable = (valid && (!self.fix || self.fix.horizontalAccuracy <= 65.0)) || obdLive;
 [self updateEcoScoreForSpeed:kmh valid:(valid || obdLive)];

 // Sync live speed to all custom dials & widgets!
 if(self.homeSpeedoDial) self.homeSpeedoDial.speed = kmh;
 if(self.driveSpeedoDial) self.driveSpeedoDial.speed = kmh;
 if(self.carplayTelemetryWidget && self.carplayTelemetryWidget.speedLabel){
  NSString *cpSpd = [NSString stringWithFormat:@"%.0f", kmh];
  if(![self.carplayTelemetryWidget.speedLabel.text isEqualToString:cpSpd]){
   self.carplayTelemetryWidget.speedLabel.text = cpSpd;
  }
 }

 // Clear manual suppression quickly once vehicle drops below 5 km/h
 if(kmh <= 5.0){
  if(!self.stationarySince) self.stationarySince = [NSDate date];
  if(-[self.stationarySince timeIntervalSinceNow] >= 1.0) self.autoDriveSuppressed = NO;
 }else{
  self.stationarySince = nil;
 }

 BOOL obdInPark = (obdLive && [obdSpd.currentGear isEqualToString:@"P"]);
 BOOL obdInReverse = (obdLive && obdSpd.isReverseGear);

 // 1. AUTO-ENTER DRIVE MODE from HOME when speed >= 20 km/h (snappy: 0.2s on OBD2, 0.5s on GPS)
 if(kmh >= 15.0) self.manualDriveActive = NO;
 if([UIApplication sharedApplication].applicationState==UIApplicationStateActive && !self.driveMode && !self.musicMode && !self.tripMode && !self.mapMode && !self.carplayMode && !self.focused && !self.autoDriveSuppressed && reliable && !obdInPark && !obdInReverse && kmh >= 20.0){
  if(!self.movingSince) self.movingSince = [NSDate date];
  NSTimeInterval enterHold = obdLive ? 0.2 : 0.5;
  if(-[self.movingSince timeIntervalSinceNow] >= enterHold){
   self.movingSince = nil;
   self.parkedSince = nil;
   self.manualDriveActive = NO;
   [self toggleDrive];
   self.manualDriveActive = NO;
  }
 }else{
  self.movingSince = nil;
 }

 // 2. AUTO-RETURN TO DASHBOARD when stopped (0 km/h) or shifted to P (instant on P, 0.6s on OBD2 0 km/h, 1.5s on GPS)
 if(self.driveMode && !self.manualDriveActive && !self.musicMode && !self.tripMode && !self.mapMode && !self.carplayMode){
  BOOL isStopped = obdLive ? (obdInPark || kmh <= 0.5) : ((!valid) || (kmh <= 2.5) || (fixAge > 4.0));
  BOOL clearlyMoving = obdLive ? (!obdInPark && kmh > 3.0) : (valid && fixAge <= 4.0 && kmh > 5.0);
  if(isStopped){
   if(!self.parkedSince) self.parkedSince = [NSDate date];
   NSTimeInterval parkedDuration = -[self.parkedSince timeIntervalSinceNow];
   NSTimeInterval returnHold = obdInPark ? 0.0 : (obdLive ? 0.6 : 1.5);
   if(parkedDuration >= returnHold){
    self.parkedSince = nil;
    self.movingSince = nil;
    self.driveMode = NO;
    self.manualDriveActive = NO;
    self.autoDriveSuppressed = NO;
    self.focused = NO;
    self.returnTap.enabled = NO;
    self.song.numberOfLines = 1;
    self.heading.hidden = NO;
    self.owner.hidden = NO;
    [self.settingsSheet dismiss];
    [self.driveCar stop];
    [self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];
    [self.view setNeedsLayout];
   }
  }else if(clearlyMoving){
   // Only cancel stop timer once clearly rolling again; ignore 0.6-3.0 km/h crawl jitter
   self.parkedSince = nil;
  }
 }else{
  self.parkedSince = nil;
 }
 self.gpsLive=valid;
 static double prevEcoKmh = -1.0;
 static NSTimeInterval prevEcoTime = 0.0;
 static double filteredDvDt = 0.0;
 static NSTimeInterval prevPowerMeterAt = 0.0;
 NSTimeInterval nowEcoTime = [NSDate timeIntervalSinceReferenceDate];
 if(prevEcoTime <= 0){
  prevEcoKmh = kmh;
  prevEcoTime = nowEcoTime;
 }else{
  double sampleDt = nowEcoTime - prevEcoTime;
  if(sampleDt >= 0.35){
   if(sampleDt < 4.0 && prevEcoKmh >= 0){
    double rawDvDt = (kmh - prevEcoKmh) / sampleDt;
    filteredDvDt += (rawDvDt - filteredDvDt) * 0.45;
   }else{
    filteredDvDt = 0.0;
   }
   prevEcoKmh = kmh;
   prevEcoTime = nowEcoTime;
  }
 }
 double rawHVkw = obdLive ? ((obdSpd.hvPackVoltage > 50.0 ? obdSpd.hvPackVoltage : 201.6) * obdSpd.hvPackCurrent / 1000.0) : 0.0;
 static double filteredHVkw = 0.0;
 static double filteredRPM = 0.0;
 if(obdLive){
  filteredHVkw += (rawHVkw - filteredHVkw) * 0.48;
  filteredRPM += ((double)obdSpd.engineRPM - filteredRPM) * 0.55;
 }else{
  filteredHVkw = 0.0;
  filteredRPM = 0.0;
 }
 double liveHVkw = filteredHVkw;
 NSInteger smoothRPM = (NSInteger)llround(filteredRPM);
 BOOL instantBraking = obdLive ? ((liveHVkw < -0.9 && smoothRPM < 1350) || obdSpd.regenBrakingPowerKW > 0.6 || filteredDvDt < -2.0) : (filteredDvDt < -2.0);
 BOOL instantAccel = obdLive ? (smoothRPM > 1850 || liveHVkw > 12.0 || filteredDvDt > 2.2) : (filteredDvDt > 2.2);
 if(self.hybridEcoBar&&!self.hybridEcoBar.hidden){
  double curSpeed=(valid||obdLive)?kmh:0;
  [self.hybridEcoBar updateWithOBDPowerKW:liveHVkw hasOBD:obdLive engineRPM:smoothRPM speed:curSpeed isBraking:instantBraking isAccelerating:instantAccel];
 }
 // Continuous Prius HSI scale: -1.0..-0.46 = CHG, -0.46..+0.36 = ECO, +0.36..+1.0 = PWR
 static double smoothedPowerRatio = -0.46;
 static double renderedPowerRatio = -99.0;
 NSTimeInterval meterDt = (prevPowerMeterAt > 0) ? MAX(0.05, MIN(1.2, nowEcoTime - prevPowerMeterAt)) : 0.25;
 prevPowerMeterAt = nowEcoTime;
 double targetRatio = -0.46;
 if(obdLive){
  BOOL highICE = (smoothRPM >= 1850);
  if(instantBraking && !highICE){
   double regenKW = MAX(fabs(MIN(0.0, liveHVkw)), obdSpd.regenBrakingPowerKW);
   if(regenKW < 0.5 && filteredDvDt < -2.0) regenKW = MIN(18.0, fabs(filteredDvDt) * 3.0);
   targetRatio = MAX(-0.98, -0.48 - (regenKW / 22.0) * 0.50);
  }else{
   double engineKW = (smoothRPM > 950) ? ((smoothRPM - 950) / 85.0) : 0.0;
   double evAssistKW = (liveHVkw > 0.0) ? liveHVkw : 0.0;
   double accelBonusKW = (filteredDvDt > 1.5 && kmh > 3.0) ? MIN(8.0, filteredDvDt * 1.4) : 0.0;
   double demandKW = evAssistKW + engineKW + accelBonusKW;
   if(demandKW <= 17.0){
    targetRatio = -0.46 + (demandKW / 17.0) * 0.82;
   }else{
    targetRatio = MIN(0.98, 0.36 + ((demandKW - 17.0) / 28.0) * 0.62);
   }
  }
 }else{
  if(instantBraking) targetRatio = -0.78;
  else if(instantAccel) targetRatio = MIN(0.90, 0.48 + MAX(0.0, filteredDvDt - 2.0) * 0.08);
  else if(kmh > 2.0) targetRatio = MIN(0.32, -0.42 + (kmh / 110.0) * 0.72);
 }
 double tau = (targetRatio > smoothedPowerRatio) ? 0.30 : 0.52;
 double alpha = 1.0 - exp(-meterDt / tau);
 smoothedPowerRatio += (targetRatio - smoothedPowerRatio) * alpha;
 if(fabs(smoothedPowerRatio - targetRatio) < 0.004) smoothedPowerRatio = targetRatio;
 if(self.drivePowerMeter&&!self.drivePowerMeter.hidden){
  self.drivePowerMeter.powerRatio = (CGFloat)smoothedPowerRatio;
  self.drivePowerMeter.engineRPM = obdLive ? smoothRPM : 0;
  self.drivePowerMeter.mg2RPM = obdLive ? obdSpd.mg2RPM : 0;
  self.drivePowerMeter.coolantC = obdLive ? obdSpd.coolantTempC : 0.0;
  self.drivePowerMeter.hvKW = liveHVkw;
  self.drivePowerMeter.fuelLiters = obdSpd.fuelRemainingLiters;
  self.drivePowerMeter.avgKmL = [self effectiveFuelKmPerL];
  self.drivePowerMeter.rangeKm = [self estimatedRangeKmForFuelLiters:obdSpd.fuelRemainingLiters];
  self.drivePowerMeter.obdLive = obdLive;
  if(fabs(smoothedPowerRatio - renderedPowerRatio) >= 0.008 || (self.ticks % 2 == 0)){
   renderedPowerRatio = smoothedPowerRatio;
   [self.drivePowerMeter setNeedsDisplay];
  }
 }
 if(self.driveCar&&!self.driveCar.hidden){
  [self.driveCar updateEnergyWithSpeed:(self.driveMode&&!self.calmDrive&&(valid||obdLive)?kmh:0)
                             engineRPM:obdLive?smoothRPM:0
                             hvCurrent:obdLive?obdSpd.hvPackCurrent:0.0
                                 hvSOC:obdLive?obdSpd.hybridBatterySOC:60.0
                             isBraking:instantBraking
                                    dt:meterDt];
 }
 if(self.driveSpeedoDial&&!self.driveSpeedoDial.hidden){
  BOOL evNow = (!obdLive || smoothRPM < 100);
  CGFloat fFrac = obdLive && obdSpd.hasLiveFuelLevel ? (CGFloat)(obdSpd.fuelLevelPercent / 100.0) : 0.55;
  if(fabs(self.driveSpeedoDial.powerRatio - (CGFloat)smoothedPowerRatio) >= 0.015 ||
     self.driveSpeedoDial.evActive != evNow ||
     fabs(self.driveSpeedoDial.fuelRatio - fFrac) >= 0.03){
   self.driveSpeedoDial.powerRatio = (CGFloat)smoothedPowerRatio;
   self.driveSpeedoDial.evActive = evNow;
   self.driveSpeedoDial.fuelRatio = fFrac;
   self.driveSpeedoDial.hasFuel = (obdLive && obdSpd.hasLiveFuelLevel);
   [self.driveSpeedoDial setNeedsDisplay];
  }
 }
 if(self.drive3DGrid&&!self.drive3DGrid.hidden){
  BOOL gridMoving = (kmh > 1.2 || smoothRPM > 950 || fabs(smoothedPowerRatio + 0.46) > 0.08);
  self.drive3DGrid.powerRatio = (CGFloat)smoothedPowerRatio;
  self.drive3DGrid.isMoving = gridMoving;
  if(gridMoving){
   CGFloat pace = MAX(0.10, MIN(0.55, (kmh / 140.0) * 0.32 + MAX(0.0, (CGFloat)smoothedPowerRatio + 0.46) * 0.22));
   CGFloat dir = (smoothedPowerRatio < -0.48) ? -0.65 : 1.0;
   self.drive3DGrid.flowPhase = fmod(self.drive3DGrid.flowPhase + dir * pace * (CGFloat)meterDt * 2.2 + 10.0, 1.0);
   [self.drive3DGrid setNeedsDisplay];
  }
 }
 if(self.flowBeamLine&&!self.flowBeamLine.hidden){
  UIColor *beamCol = (smoothedPowerRatio > 0.36) ? [UIColor colorWithRed:1.0 green:0.32 blue:0.28 alpha:1]
                    : ((smoothedPowerRatio < -0.48) ? [UIColor colorWithRed:0.0 green:0.88 blue:1.0 alpha:1]
                                                    : [UIColor colorWithRed:0.25 green:0.95 blue:0.55 alpha:1]);
  self.flowBeamLine.backgroundColor = [beamCol colorWithAlphaComponent:0.35];
  UIView *fDot = self.flowBeamLine.subviews.firstObject;
  CGFloat lineW = self.flowBeamLine.bounds.size.width;
  if(fDot && fDot.tag != 831 && lineW > 20.0){
   CGFloat normPos = MAX(0.0, MIN(1.0, (CGFloat)((smoothedPowerRatio + 1.0) * 0.5)));
   fDot.backgroundColor = beamCol;
   fDot.frame = CGRectMake((lineW - 8.0) * normPos, -3, 8, 8);
  }
 }
 NSString *newSpeed=[NSString stringWithFormat:@"%.0f",kmh];
 if(![self.speed.text isEqualToString:newSpeed]){
  self.speed.text=newSpeed;
  [CATransaction begin];[CATransaction setDisableActions:YES];self.progress.strokeEnd=(valid||obdLive)?MIN(1,kmh/180.0):0;[CATransaction commit];
 }
 
 BOOL overSpeed=(self.speedLimit>0&&(valid||obdLive)&&kmh>(self.speedLimit+0.5));
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

 // Real-time OBD2 safety & low-fuel alert banner
 NSString *obdWarn = nil;
 if([[NSProcessInfo processInfo] respondsToSelector:@selector(thermalState)]){
  NSProcessInfoThermalState ts = [[NSProcessInfo processInfo] thermalState];
  if(ts >= NSProcessInfoThermalStateSerious){
   obdWarn = @"🔥 iPad ร้อนสูง: เปิดโหมดลดภาระชิป A7 อัตโนมัติ";
  }
 }
 if(!obdWarn && obdLive){
  if(obdSpd.coolantTempC >= 98.0) obdWarn = [NSString stringWithFormat:@"⚠️ น้ำหล่อเย็นเครื่องยนต์ร้อนสูง: %.0f°C", obdSpd.coolantTempC];
  else if(obdSpd.inverterTempC >= 70.0) obdWarn = [NSString stringWithFormat:@"⚠️ อินเวอร์เตอร์ไฮบริดร้อนสูง: %.0f°C", obdSpd.inverterTempC];
  else if(obdSpd.hvBatteryTempC >= 42.0) obdWarn = [NSString stringWithFormat:@"⚠️ แบตเตอรี่ HV เริ่มร้อน: %.0f°C (เปิดแอร์ช่วยระบาย)", obdSpd.hvBatteryTempC];
  else if(obdSpd.hvBlockMaxV > 1.0 && (obdSpd.hvBlockMaxV - obdSpd.hvBlockMinV) >= 0.30) obdWarn = [NSString stringWithFormat:@"⚠️ แรงดันแบต HV 14 บล็อกต่างกัน ΔV %.2fV", (obdSpd.hvBlockMaxV - obdSpd.hvBlockMinV)];
  else if(obdSpd.auxBatteryVoltage > 5.0 && obdSpd.auxBatteryVoltage < 11.7) obdWarn = [NSString stringWithFormat:@"🔋 แบตเตอรี่ 12V อ่อน: %.2fV", obdSpd.auxBatteryVoltage];
  else if(obdSpd.fuelRemainingLiters > 0.2 && obdSpd.fuelRemainingLiters <= 7.0){
   double estKm = [self estimatedRangeKmForFuelLiters:obdSpd.fuelRemainingLiters];
   obdWarn = [NSString stringWithFormat:@"⛽ น้ำมันใกล้หมด: %.1f L (~%.0f กม.) ควรเติมน้ำมัน", obdSpd.fuelRemainingLiters, estKm];
  }
 }
 if(obdWarn){
  BOOL wasHidden = (!self.obdAlertBanner || self.obdAlertBanner.hidden);
  if(!self.obdAlertBanner){
   self.obdAlertBanner = [[UILabel alloc] init];
   self.obdAlertBanner.backgroundColor = [UIColor colorWithRed:0.85 green:0.10 blue:0.12 alpha:0.94];
   self.obdAlertBanner.textColor = [UIColor whiteColor];
   self.obdAlertBanner.font = [UIFont boldSystemFontOfSize:13.5];
   self.obdAlertBanner.textAlignment = NSTextAlignmentCenter;
   self.obdAlertBanner.layer.cornerRadius = 17;
   self.obdAlertBanner.layer.masksToBounds = YES;
   self.obdAlertBanner.layer.borderWidth = 1.5;
   self.obdAlertBanner.layer.borderColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.20 alpha:0.95].CGColor;
   [self.view addSubview:self.obdAlertBanner];
  }
  if(![self.obdAlertBanner.text isEqualToString:obdWarn]){
   self.obdAlertBanner.text = obdWarn;
  }
  if(wasHidden){
   self.obdAlertBanner.hidden = NO;
   [self.view setNeedsLayout];
  }
  if(!self.lastOBDWarnDate || -[self.lastOBDWarnDate timeIntervalSinceNow] >= 30.0){
   self.lastOBDWarnDate = [NSDate date];
   AudioServicesPlaySystemSound(1052);
  }
 }else if(self.obdAlertBanner && !self.obdAlertBanner.hidden){
  self.obdAlertBanner.hidden = YES;
  [self.view setNeedsLayout];
 }
 NSString *newStatus=gps[@"label"];
 if(![self.gpsStatus.text isEqualToString:newStatus]){
  self.gpsStatus.text=newStatus;self.gpsStatus.adjustsFontSizeToFitWidth=YES;self.gpsStatus.minimumScaleFactor=.75;self.gpsStatus.textColor=valid?[UIColor colorWithRed:.30 green:self.nightMode?.58:.8 blue:.48 alpha:1]:[UIColor colorWithRed:self.nightMode?.72:.95 green:self.nightMode?.5:.66 blue:.24 alpha:1];
 }
 [self refreshClockHud];
}
-(void)playRadio:(NSString *)url name:(NSString *)name{
 NSUInteger gen=++self.radioGeneration;
 self.offlinePlaybackActive=NO;
 [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
 if(self.radioPlayer){
  [self.radioPlayer pause];
  [self.radioPlayer replaceCurrentItemWithPlayerItem:nil];
  self.radioPlayer=nil;
 }
 if(!url.length){
  self.currentRadioStation=nil;
  self.currentRadioURL=nil;
  self.song.text=@"Radio stopped";
  self.artist.text=@"Tap RADIO to select station";
  [self refreshNowPlaying];
  [self refreshTransportState];
  [self refreshMini];
  return;
 }

 self.currentRadioStation=name;
 self.currentRadioURL=url;
 self.song.text=[NSString stringWithFormat:@"[CONNECTING...] %@", name];
 self.artist.text=@"Buffering live stream...";
 self.sourceBadge.text=@"RADIO";
 [self refreshTransportState];
 [self refreshMini];

 static dispatch_queue_t radioQueue;
 static dispatch_once_t radioOnce;
 dispatch_once(&radioOnce,^{
  radioQueue=dispatch_queue_create("com.codex.trd.radio",DISPATCH_QUEUE_SERIAL);
 });
 NSString *urlCopy=[url copy];
 __weak Dashboard *weak=self;
 dispatch_async(radioQueue,^{
  Dashboard *v=weak;
  if(!v||gen!=v.radioGeneration)return;

  // 1. Explicitly pause any background music / YouTube players so audio never overlaps
  notify_post("com.codex.trd.youtube.pause");
  TRDSendMediaRemoteExternal(1,^{ [weak send:@"libactivator.ipod.pause-playback"]; });

  // 2. Configure exclusive AVAudioSession (NO MixWithOthers!) off the main thread
  AVAudioSession *session=[AVAudioSession sharedInstance];
  NSError *sErr=nil;
  [session setCategory:AVAudioSessionCategoryPlayback error:&sErr];
  [session setActive:YES error:&sErr];

  v=weak;
  if(!v||gen!=v.radioGeneration)return;

  NSURL *streamURL=[NSURL URLWithString:urlCopy];
  if(!streamURL)return;
  AVPlayerItem *item=[AVPlayerItem playerItemWithURL:streamURL];
  item.canUseNetworkResourcesForLiveStreamingWhilePaused=NO;
  if(@available(iOS 10.0, *))item.preferredForwardBufferDuration=2.0;

  dispatch_async(dispatch_get_main_queue(),^{
   Dashboard *d=weak;
   if(!d||gen!=d.radioGeneration)return;
   AVPlayer *player=[AVPlayer playerWithPlayerItem:item];
   if(@available(iOS 10.0, *))player.automaticallyWaitsToMinimizeStalling=YES;
   d.radioPlayer=player;
   [d.radioPlayer play];
   [d refreshTransportState];
   [d refreshMini];
  });
 });
}
-(void)openRadioStationsMenu{
 TRDSettingsMenu *m=[self settingsMenu:@"RADIO & MUSIC BROADCAST" message:@"UK & Thai music radio streams (Non-stop music)"];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Capital UK (Top 40 Pop & Hits)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/CapitalUK" name:@"Capital UK (Top 40 Hits)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Capital XTRA UK (Hip-Hop, R&B & Urban)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/CapitalXTRANational" name:@"Capital XTRA UK (Hip-Hop & R&B)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Capital Dance UK (Electronic & Club)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/CapitalDance" name:@"Capital Dance UK (Electronic & Club)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Heart UK (Pop & Feel-Good Variety)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/HeartLondon" name:@"Heart UK (Pop & Variety)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Heart 80s UK (Classic 80s Hits)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/Heart80s" name:@"Heart 80s UK (Classic 80s)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Heart Dance UK (Dance Classics & Party)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/HeartDance" name:@"Heart Dance UK (Dance Classics)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Smooth Radio UK (Relaxing Pop & Soul)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/SmoothUK" name:@"Smooth Radio UK (Relaxing Pop)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Smooth Chill UK (Ambient & Night Drive)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/SmoothChill" name:@"Smooth Chill UK (Ambient Chill)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Gold UK (60s, 70s & 80s Greatest Hits)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/Gold" name:@"Gold UK (Greatest Hits)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Radio X UK (British Indie & Rock)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/RadioXLondon" name:@"Radio X UK (British Indie & Rock)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Classic FM UK (Soundtracks & Classics)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://media-ssl.musicradio.com/ClassicFM" name:@"Classic FM UK (Soundtracks & Classics)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇬🇧 Met 107 (Bangkok English Hits)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://rstream.mcot.net:8000/fm107" name:@"Met 107 (English Hits)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🎷 Jazz Radio Paris (Smooth Jazz & Lounge)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://jazz-wr01.ice.infomaniak.ch/jazz-wr01-128.mp3" name:@"Jazz Radio Paris (Smooth Jazz)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇹🇭 COOL Fahrenheit 93 (No. 1 Thai Pop)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://coolism-web.cdn.byteark.com/;stream/1" name:@"COOL Fahrenheit 93 (Thai Pop)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇹🇭 Green Wave 106.5 (Thai Easy Listening)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://atimevideo.smartclick.co.th/live/greenlive.sdp/chunklist.m3u8" name:@"Green Wave 106.5 (Easy Listening)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇹🇭 Flex 104.5 (Modern Thai & Inter Hits)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"https://streaming.flexconnect.net/voiceflex/voiceflex/playlist.m3u8" name:@"Flex 104.5 (Modern Hits)"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🇹🇭 ลูกทุ่งเน็ตเวิร์ก 90 (Lukthung Country)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:@"http://radio11.plathong.net:8896/;stream.mp3" name:@"ลูกทุ่งเน็ตเวิร์ก 90"];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"⏹️ Stop Radio (หยุดวิทยุ)" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:nil name:nil];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🎵 Open audioNINJA / YouTube" style:0 handler:^(TRDSettingAction *a){
  [self playRadio:nil name:nil];
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
-(void)switchTripSummaryToThis{
  [self showTripSummaryWithTab:0];
}
-(void)switchTripSummaryToDaily{
  [self showTripSummaryWithTab:1];
}
-(void)showTripSummary{
  [self showTripSummaryWithTab:0];
}
-(void)showTripSummaryWithTab:(NSInteger)tabIndex{
  [self syncTripSlotsDelta:YES];
  if(self.welcome)[self hideWelcome];
  if(!self.trip) self.trip=[TRDTrip new];
  [self.settingsSheet dismiss];
  if(self.driveMode||self.carplayMode||self.tripMode||self.mapMode||self.focused){
   [self homePage];
  }
  if(self.tripSummaryCard){
   [self.tripSummaryCard removeFromSuperview];
   self.tripSummaryCard=nil;
  }
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  self.activeSummaryTab = (tabIndex == 1) ? 1 : 0;

  CGFloat w=self.view.bounds.size.width;
  CGFloat h=self.view.bounds.size.height;
  if(w<=0) w=1024;
  if(h<=0) h=768;

  // 1. 100% SOLID FULL-SCREEN BACKDROP OVERLAY (Completely conceals dashboard: ZERO bleed-through)
  UIView *fullOverlay=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,h)];
  fullOverlay.backgroundColor=[UIColor colorWithRed:0.024 green:0.031 blue:0.043 alpha:1.0];
  fullOverlay.opaque=YES;
  fullOverlay.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

  // 2. EXECUTIVE DIALOG CARD (880 x 630 px)
  CGFloat cardW=880;
  CGFloat cardH=630;
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

  // Header Title
  UILabel *title=[[UILabel alloc]initWithFrame:CGRectMake(24,12,410,26)];
  title.font=[UIFont boldSystemFontOfSize:19];
  title.textColor=[UIColor colorWithRed:0.98 green:0.15 blue:0.20 alpha:1.0];
  title.text=@"PRIUS TRD SPORTIVO  •  TRIP SUMMARY";
  [card addSubview:title];

  // Header Subtitle (Date & Engine Status)
  NSDateFormatter *df=[[NSDateFormatter alloc]init];
  [df setDateFormat:@"d MMM yyyy • HH:mm"];
  NSString *timeStr=[df stringFromDate:[NSDate date]]?:@"";
  UILabel *hdrSub=[[UILabel alloc]initWithFrame:CGRectMake(24,40,420,20)];
  hdrSub.font=[UIFont boldSystemFontOfSize:13.0];
  hdrSub.textColor=[UIColor colorWithWhite:0.78 alpha:1.0];
  BOOL isUnplugged = ([UIDevice currentDevice].batteryState == UIDeviceBatteryStateUnplugged);
  hdrSub.text=[NSString stringWithFormat:@"%@  •  %@", timeStr, isUnplugged ? @"ENGINE SHUTDOWN • สรุปทริป" : @"สถิติทริป & ประวัติสะสมรายวัน (.plist)"];
  [card addSubview:hdrSub];

  // Top-right Segmented Tabs: [ทริปรอบนี้] | [รายวัน/สัปดาห์/เดือน]
  UIButton *tabThis = [UIButton buttonWithType:UIButtonTypeCustom];
  tabThis.frame = CGRectMake(cardW - 418, 14, 152, 38);
  tabThis.layer.cornerRadius = 10;
  tabThis.layer.borderWidth = 1.2;
  [tabThis setTitle:@"📍 ทริปรอบนี้" forState:UIControlStateNormal];
  tabThis.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
  [tabThis addTarget:self action:@selector(switchTripSummaryToThis) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:tabThis];

  UIButton *tabDaily = [UIButton buttonWithType:UIButtonTypeCustom];
  tabDaily.frame = CGRectMake(cardW - 258, 14, 194, 38);
  tabDaily.layer.cornerRadius = 10;
  tabDaily.layer.borderWidth = 1.2;
  [tabDaily setTitle:@"📅 รายวัน / สัปดาห์ / เดือน" forState:UIControlStateNormal];
  tabDaily.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
  [tabDaily addTarget:self action:@selector(switchTripSummaryToDaily) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:tabDaily];

  if(self.activeSummaryTab == 0){
    tabThis.backgroundColor = [UIColor colorWithRed:0.85 green:0.12 blue:0.18 alpha:0.92];
    tabThis.layer.borderColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.40 alpha:1.0].CGColor;
    [tabThis setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    tabDaily.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    tabDaily.layer.borderColor = [UIColor colorWithWhite:0.28 alpha:1.0].CGColor;
    [tabDaily setTitleColor:[UIColor colorWithWhite:0.82 alpha:1.0] forState:UIControlStateNormal];
  }else{
    tabDaily.backgroundColor = [UIColor colorWithRed:0.05 green:0.45 blue:0.65 alpha:0.95];
    tabDaily.layer.borderColor = [UIColor colorWithRed:0.10 green:0.88 blue:1.0 alpha:1.0].CGColor;
    [tabDaily setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    tabThis.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    tabThis.layer.borderColor = [UIColor colorWithWhite:0.28 alpha:1.0].CGColor;
    [tabThis setTitleColor:[UIColor colorWithWhite:0.82 alpha:1.0] forState:UIControlStateNormal];
  }

  // Close [✕] button at top right
  UIButton *closeBtn=[UIButton buttonWithType:UIButtonTypeCustom];
  closeBtn.frame=CGRectMake(cardW-52,14,38,38);
  closeBtn.backgroundColor=[UIColor colorWithWhite:0.16 alpha:0.9];
  closeBtn.layer.cornerRadius=19;
  closeBtn.layer.borderWidth=1;
  closeBtn.layer.borderColor=[UIColor colorWithWhite:0.32 alpha:0.6].CGColor;
  [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
  [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  closeBtn.titleLabel.font=[UIFont boldSystemFontOfSize:17];
  [closeBtn addTarget:self action:@selector(hideTripSummary) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:closeBtn];

  // Divider
  UIView *div1=[[UIView alloc]initWithFrame:CGRectMake(20,66,cardW-40,1)];
  div1.backgroundColor=[UIColor colorWithWhite:0.18 alpha:1.0];
  [card addSubview:div1];

  // Compute cumulative rollups from persistent daily plist (Today, Last 7 Days, This Month, All-Time)
  NSMutableDictionary *daysDict = [self ensureDailyHistoryLoaded];
  NSString *todayKey = TRDDateKeyForDate([NSDate date]);
  NSString *monthPrefix = ([todayKey length] >= 7) ? [todayKey substringToIndex:7] : @"";
  NSDate *sevenDaysAgo = [[NSDate date] dateByAddingTimeInterval:-6 * 86400.0];
  NSString *weekMinKey = TRDDateKeyForDate(sevenDaysAgo);

  double todayKm = 0, todayFuel = 0, todayCost = 0; NSInteger todayTrips = 0;
  double weekKm = 0, weekFuel = 0, weekCost = 0; NSInteger weekDays = 0;
  double monthKm = 0, monthFuel = 0, monthCost = 0; NSInteger monthDays = 0;
  double allKm = 0, allFuel = 0, allCost = 0; NSInteger allDays = 0;

  NSArray *sortedKeys = [[daysDict allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b){
    return [b compare:a];
  }];
  for(NSString *dk in sortedKeys){
    NSDictionary *rec = daysDict[dk];
    if(![rec isKindOfClass:[NSDictionary class]]) continue;
    double dKm = [rec[@"km"] doubleValue];
    double dF = [rec[@"fuelL"] doubleValue];
    double dC = [rec[@"cost"] doubleValue];
    NSInteger dTrips = [rec[@"trips"] integerValue];
    allKm += dKm; allFuel += dF; allCost += dC; allDays++;
    if([dk isEqualToString:todayKey]){
      todayKm += dKm; todayFuel += dF; todayCost += dC; todayTrips = dTrips;
    }
    if([dk compare:weekMinKey] != NSOrderedAscending){
      weekKm += dKm; weekFuel += dF; weekCost += dC; weekDays++;
    }
    if(monthPrefix.length && [dk hasPrefix:monthPrefix]){
      monthKm += dKm; monthFuel += dF; monthCost += dC; monthDays++;
    }
  }

  if(self.activeSummaryTab == 0){
    // === TAB 0: THIS TRIP SUMMARY + 7-DAY / MONTHLY CUMULATIVE BANNER ===
    double km=self.trip.meters/1000.0;
    long min=self.trip.seconds/60;
    double avg=(self.trip.seconds>5 && km>0.001)?(self.trip.meters/self.trip.seconds*3.6):0;
    double top=self.trip.maximum;

    TRDOBDClient *obd=[TRDOBDClient sharedClient];
    double price = (obd.fuelPricePerLiter > 0) ? obd.fuelPricePerLiter : 38.50;
    double fuelL=obd.tripFuelUsedLiters;
    double fuelCost=(obd.tripFuelCostTHB > 0.001) ? obd.tripFuelCostTHB : (fuelL * price);

    NSInteger ecoVal = self.ecoScore > 0 ? self.ecoScore : 94;
    float batLvl = [UIDevice currentDevice].batteryLevel;
    NSString *batStr = batLvl >= 0 ? [NSString stringWithFormat:@"%.0f%% %@", batLvl*100, batLvl>=0.80?@"Optimal":@"Normal"] : @"68% Ready";

    UIView *heroBox=[[UIView alloc]initWithFrame:CGRectMake(20,76,cardW-40,96)];
    heroBox.backgroundColor=[UIColor colorWithRed:0.035 green:0.043 blue:0.065 alpha:1.0];
    heroBox.opaque=YES;
    heroBox.layer.cornerRadius=14;
    heroBox.layer.borderWidth=1;
    heroBox.layer.borderColor=[UIColor colorWithWhite:0.18 alpha:1.0].CGColor;
    [card addSubview:heroBox];

    CGFloat hColW=(cardW-40)/3;
    NSArray *hTitles = @[@"TOTAL DISTANCE", @"DRIVING TIME", @"REAL FUEL COST"];
    NSArray *hVals = @[
      [NSString stringWithFormat:@"%.2f km", km],
      [NSString stringWithFormat:@"%ld min", min],
      [NSString stringWithFormat:@"฿ %.2f", fuelCost]
    ];
    NSArray *hSubs = @[@"ระยะทางรวมรอบนี้", @"เวลาในการขับขี่", obd.isConnected ? @"ค่าน้ำมันจริง (MAF)" : @"ค่าน้ำมันคำนวณจริง (GPS)"];
    NSArray *hColors = @[
      [UIColor whiteColor],
      [UIColor colorWithRed:0.22 green:0.74 blue:0.97 alpha:1.0],
      [UIColor colorWithRed:0.29 green:0.87 blue:0.50 alpha:1.0]
    ];
    for(int c=0; c<3; c++){
      UILabel *hl=[[UILabel alloc]initWithFrame:CGRectMake(c*hColW+10,10,hColW-20,16)];
      hl.font=[UIFont boldSystemFontOfSize:11];
      hl.textColor=[UIColor colorWithWhite:0.65 alpha:1.0];
      hl.textAlignment=NSTextAlignmentCenter;
      hl.text=hTitles[c];
      [heroBox addSubview:hl];

      UILabel *hv=[[UILabel alloc]initWithFrame:CGRectMake(c*hColW+6,28,hColW-12,40)];
      hv.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:33]?:[UIFont boldSystemFontOfSize:31];
      hv.textColor=hColors[c];
      hv.textAlignment=NSTextAlignmentCenter;
      hv.text=hVals[c];
      [heroBox addSubview:hv];

      UILabel *hs=[[UILabel alloc]initWithFrame:CGRectMake(c*hColW+10,70,hColW-20,18)];
      hs.font=[UIFont boldSystemFontOfSize:12.5];
      hs.textColor=(c==0)?[UIColor colorWithRed:0.40 green:0.80 blue:1.0 alpha:0.95]:[UIColor colorWithWhite:0.78 alpha:1.0];
      hs.textAlignment=NSTextAlignmentCenter;
      hs.text=hSubs[c];
      [heroBox addSubview:hs];
    }

    // 6-Tile Grid
    NSString *kmlSubStr = (km > 0.05 && fuelL > 0.005)
      ? [NSString stringWithFormat:@"เฉลี่ย %.1f km/L (%@)", MAX(3.0, MIN(99.9, km / fuelL)), obd.isConnected ? @"MAF จริง" : @"GPS"]
      : ((km > 0.05 && obd.isConnected) ? @"EV ไฟฟ้าล้วน (0.0 L)" : @"รอรถเคลื่อนที่");

    NSArray *gridLabels=@[@"FUEL CONSUMED", @"AVERAGE SPEED", @"MAXIMUM SPEED", @"ECO DRIVE SCORE", @"IPAD BATTERY", @"GASOHOL RATE"];
    NSArray *gridValues=@[
      [NSString stringWithFormat:@"%.2f L", fuelL],
      [NSString stringWithFormat:@"%.0f km/h", avg],
      [NSString stringWithFormat:@"%.0f km/h", top],
      [NSString stringWithFormat:@"%ld / 100", (long)ecoVal],
      batStr,
      [NSString stringWithFormat:@"฿ %.2f/L", price]
    ];
    NSArray *gridSubs=@[
      kmlSubStr,
      @"ความเร็วเฉลี่ยตลอดทาง",
      @"ความเร็วสูงสุดที่ทำได้",
      @"คะแนนการขับขี่ประหยัด",
      @"สถานะแบตเตอรี่ iPad Mini 2",
      obd.selectedFuelTypeName ?: @"แก๊สโซฮอล์ 95"
    ];

    CGFloat tileGap=12;
    CGFloat tileW=(cardW-40-tileGap*2)/3;
    CGFloat tileH=92;
    CGFloat gridStartY=182;
    for(int i=0;i<6;i++){
      CGFloat tx=20+(i%3)*(tileW+tileGap);
      CGFloat ty=gridStartY+(i/3)*(tileH+tileGap);
      UIView *tile=[[UIView alloc]initWithFrame:CGRectMake(tx,ty,tileW,tileH)];
      tile.backgroundColor=[UIColor colorWithRed:0.040 green:0.050 blue:0.072 alpha:1.0];
      tile.opaque=YES;
      tile.layer.cornerRadius=12;
      tile.layer.borderWidth=1;
      tile.layer.borderColor=[UIColor colorWithWhite:0.16 alpha:1.0].CGColor;
      [card addSubview:tile];

      UILabel *tLbl=[[UILabel alloc]initWithFrame:CGRectMake(12,8,tileW-24,15)];
      tLbl.font=[UIFont boldSystemFontOfSize:10];
      tLbl.textColor=[UIColor colorWithWhite:0.62 alpha:1.0];
      tLbl.text=gridLabels[i];
      [tile addSubview:tLbl];

      UILabel *tVal=[[UILabel alloc]initWithFrame:CGRectMake(12,25,tileW-24,34)];
      tVal.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:25]?:[UIFont boldSystemFontOfSize:23];
      tVal.textColor=(i==0||i==3)?[UIColor colorWithRed:0.35 green:0.88 blue:0.45 alpha:1.0]:((i==1||i==2)?[UIColor colorWithRed:0.25 green:0.75 blue:1.0 alpha:1.0]:[UIColor whiteColor]);
      tVal.text=gridValues[i];
      [tile addSubview:tVal];

      UILabel *tSub=[[UILabel alloc]initWithFrame:CGRectMake(12,62,tileW-24,22)];
      tSub.font=[UIFont boldSystemFontOfSize:12.5];
      tSub.adjustsFontSizeToFitWidth=YES;
      tSub.minimumScaleFactor=0.80;
      tSub.textColor=[UIColor colorWithWhite:0.78 alpha:1.0];
      tSub.text=gridSubs[i];
      [tile addSubview:tSub];
    }

    // Persistent Rollup Strip right on Main Summary (Today / 7-Day Week / This Month)
    UIView *rollupStrip=[[UIView alloc]initWithFrame:CGRectMake(20,388,cardW-40,104)];
    rollupStrip.backgroundColor=[UIColor colorWithRed:0.025 green:0.065 blue:0.105 alpha:1.0];
    rollupStrip.opaque=YES;
    rollupStrip.layer.cornerRadius=12;
    rollupStrip.layer.borderWidth=1.2;
    rollupStrip.layer.borderColor=[UIColor colorWithRed:0.05 green:0.72 blue:0.95 alpha:0.55].CGColor;
    [card addSubview:rollupStrip];

    UILabel *rTitle=[[UILabel alloc]initWithFrame:CGRectMake(14,8,cardW-70,18)];
    rTitle.font=[UIFont boldSystemFontOfSize:12];
    rTitle.textColor=[UIColor colorWithRed:0.25 green:0.88 blue:1.0 alpha:1.0];
    rTitle.text=@"📊 ยอดสะสมต่อเนื่องจากไฟล์ .plist (ไม่รีเซ็ตเมื่อปิดรถหรือรีเซ็ตทริป)";
    [rollupStrip addSubview:rTitle];

    CGFloat rColW=(cardW-40-24)/3;
    NSString *tKml = (todayFuel > 0.005 && todayKm > 0.05) ? [NSString stringWithFormat:@"%.1f km/L", todayKm/todayFuel] : @"-- km/L";
    NSString *wKml = (weekFuel > 0.005 && weekKm > 0.05) ? [NSString stringWithFormat:@"%.1f km/L", weekKm/weekFuel] : @"-- km/L";
    NSString *mKml = (monthFuel > 0.005 && monthKm > 0.05) ? [NSString stringWithFormat:@"%.1f km/L", monthKm/monthFuel] : @"-- km/L";
    NSArray *rNames=@[
      [NSString stringWithFormat:@"📅 วันนี้ (%ld รอบ)", (long)todayTrips],
      [NSString stringWithFormat:@"📆 7 วันล่าสุด (%ld วัน)", (long)weekDays],
      [NSString stringWithFormat:@"🗓️ เดือนนี้ (%ld วัน)", (long)monthDays]
    ];
    NSArray *rMain=@[
      [NSString stringWithFormat:@"%.1f km • %.2f L", todayKm, todayFuel],
      [NSString stringWithFormat:@"%.1f km • %.2f L", weekKm, weekFuel],
      [NSString stringWithFormat:@"%.1f km • %.2f L", monthKm, monthFuel]
    ];
    NSArray *rSub=@[
      [NSString stringWithFormat:@"฿ %.1f  (%@)", todayCost, tKml],
      [NSString stringWithFormat:@"฿ %.1f  (%@)", weekCost, wKml],
      [NSString stringWithFormat:@"฿ %.1f  (%@)", monthCost, mKml]
    ];
    for(int c=0; c<3; c++){
      UIView *rBox=[[UIView alloc]initWithFrame:CGRectMake(12+c*rColW,30,rColW-8,66)];
      rBox.backgroundColor=[UIColor colorWithRed:0.04 green:0.08 blue:0.13 alpha:1.0];
      rBox.layer.cornerRadius=8;
      [rollupStrip addSubview:rBox];

      UILabel *l1=[[UILabel alloc]initWithFrame:CGRectMake(8,4,rColW-24,16)];
      l1.font=[UIFont boldSystemFontOfSize:11.5];
      l1.textColor=[UIColor colorWithWhite:0.75 alpha:1.0];
      l1.text=rNames[c];
      [rBox addSubview:l1];

      UILabel *l2=[[UILabel alloc]initWithFrame:CGRectMake(8,21,rColW-24,22)];
      l2.font=[UIFont boldSystemFontOfSize:16.0];
      l2.adjustsFontSizeToFitWidth=YES; l2.minimumScaleFactor=0.75;
      l2.textColor=[UIColor colorWithRed:0.35 green:0.95 blue:0.65 alpha:1.0];
      l2.text=rMain[c];
      [rBox addSubview:l2];

      UILabel *l3=[[UILabel alloc]initWithFrame:CGRectMake(8,44,rColW-24,18)];
      l3.font=[UIFont boldSystemFontOfSize:12.5];
      l3.textColor=[UIColor colorWithRed:1.0 green:0.86 blue:0.35 alpha:1.0];
      l3.text=rSub[c];
      [rBox addSubview:l3];
    }

    UILabel *subNote=[[UILabel alloc]initWithFrame:CGRectMake(20,504,cardW-40,22)];
    subNote.font=[UIFont boldSystemFontOfSize:13.5];
    subNote.textColor=[UIColor colorWithWhite:0.78 alpha:1.0];
    subNote.textAlignment=NSTextAlignmentCenter;
    subNote.text=isUnplugged ? @"เครื่องยนต์ดับแล้ว • บันทึกลงสถิติรายวันเรียบร้อย (Auto-sleep in 15s)" : @"ข้อมูลสะสมบันทึกลงไฟล์ plist อัตโนมัติ (ไม่ลบข้อมูลเดิม)";
    [card addSubview:subNote];

    CGFloat btnW = (cardW - 80) / 3.0;
    UIButton *btnDaily=[UIButton buttonWithType:UIButtonTypeCustom];
    btnDaily.frame=CGRectMake(20,540,btnW,56);
    btnDaily.backgroundColor=[UIColor colorWithRed:0.05 green:0.35 blue:0.55 alpha:0.95];
    btnDaily.layer.cornerRadius=14; btnDaily.layer.borderWidth=1;
    btnDaily.layer.borderColor=[UIColor colorWithRed:0.15 green:0.80 blue:1.0 alpha:0.75].CGColor;
    [btnDaily setTitle:@"📅 ดูแยกรายวันทีละวัน" forState:UIControlStateNormal];
    [btnDaily setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnDaily.titleLabel.font=[UIFont boldSystemFontOfSize:15.5];
    [btnDaily addTarget:self action:@selector(switchTripSummaryToDaily) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:btnDaily];

    UIButton *btnHome=[UIButton buttonWithType:UIButtonTypeCustom];
    btnHome.frame=CGRectMake(40+btnW,540,btnW,56);
    btnHome.backgroundColor=[UIColor colorWithRed:0.12 green:0.15 blue:0.22 alpha:0.95];
    btnHome.layer.cornerRadius=14; btnHome.layer.borderWidth=1;
    btnHome.layer.borderColor=[UIColor colorWithWhite:0.32 alpha:0.6].CGColor;
    [btnHome setTitle:@"✕ ปิดหน้าต่าง / RETURN" forState:UIControlStateNormal];
    [btnHome setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnHome.titleLabel.font=[UIFont boldSystemFontOfSize:15.5];
    [btnHome addTarget:self action:@selector(hideTripSummary) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:btnHome];

    UIButton *btnSleep=[UIButton buttonWithType:UIButtonTypeCustom];
    btnSleep.frame=CGRectMake(60+btnW*2,540,btnW,56);
    btnSleep.backgroundColor=[UIColor colorWithRed:0.75 green:0.12 blue:0.16 alpha:0.95];
    btnSleep.layer.cornerRadius=14; btnSleep.layer.borderWidth=1;
    btnSleep.layer.borderColor=[UIColor colorWithRed:0.95 green:0.25 blue:0.30 alpha:0.8].CGColor;
    [btnSleep setTitle:@"● พักหน้าจอทันที / SLEEP" forState:UIControlStateNormal];
    [btnSleep setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnSleep.titleLabel.font=[UIFont boldSystemFontOfSize:15.5];
    [btnSleep addTarget:self action:@selector(immediateSleepFromTripSummary) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:btnSleep];
  }else{
    // === TAB 1: DAILY / 7-DAY / MONTHLY LOG BREAKDOWN ===
    CGFloat sColW = (cardW - 56) / 3.0;
    NSArray *sHeads = @[
      [NSString stringWithFormat:@"📅 วันนี้ (%ld รอบ)", (long)todayTrips],
      [NSString stringWithFormat:@"📆 รวม 7 วันล่าสุด (%ld วัน)", (long)weekDays],
      [NSString stringWithFormat:@"🗓️ รวมเดือนนี้ (%ld วัน)", (long)monthDays]
    ];
    NSArray *sDistances = @[
      [NSString stringWithFormat:@"%.1f km  •  %.2f L", todayKm, todayFuel],
      [NSString stringWithFormat:@"%.1f km  •  %.2f L", weekKm, weekFuel],
      [NSString stringWithFormat:@"%.1f km  •  %.2f L", monthKm, monthFuel]
    ];
    NSArray *sCosts = @[
      [NSString stringWithFormat:@"ค่าน้ำมัน ฿ %.2f", todayCost],
      [NSString stringWithFormat:@"ค่าน้ำมัน ฿ %.2f", weekCost],
      [NSString stringWithFormat:@"ค่าน้ำมัน ฿ %.2f", monthCost]
    ];
    for(int c=0; c<3; c++){
      UIView *box=[[UIView alloc]initWithFrame:CGRectMake(20+c*(sColW+8),76,sColW,88)];
      box.backgroundColor=[UIColor colorWithRed:0.032 green:0.055 blue:0.095 alpha:1.0];
      box.opaque=YES;
      box.layer.cornerRadius=12;
      box.layer.borderWidth=1.2;
      box.layer.borderColor=(c==1?[UIColor colorWithRed:0.10 green:0.82 blue:1.0 alpha:0.75]:(c==2?[UIColor colorWithRed:0.30 green:0.92 blue:0.55 alpha:0.70]:[UIColor colorWithWhite:0.25 alpha:1.0])).CGColor;
      [card addSubview:box];

      UILabel *l1=[[UILabel alloc]initWithFrame:CGRectMake(12,8,sColW-24,18)];
      l1.font=[UIFont boldSystemFontOfSize:13];
      l1.textColor=[UIColor colorWithWhite:0.80 alpha:1.0];
      l1.text=sHeads[c];
      [box addSubview:l1];

      UILabel *l2=[[UILabel alloc]initWithFrame:CGRectMake(12,28,sColW-24,28)];
      l2.font=[UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:24]?:[UIFont boldSystemFontOfSize:22];
      l2.adjustsFontSizeToFitWidth=YES; l2.minimumScaleFactor=0.72;
      l2.textColor=[UIColor colorWithRed:0.32 green:0.95 blue:0.65 alpha:1.0];
      l2.text=sDistances[c];
      [box addSubview:l2];

      UILabel *l3=[[UILabel alloc]initWithFrame:CGRectMake(12,58,sColW-24,20)];
      l3.font=[UIFont boldSystemFontOfSize:14];
      l3.textColor=[UIColor colorWithRed:1.0 green:0.85 blue:0.32 alpha:1.0];
      l3.text=sCosts[c];
      [box addSubview:l3];
    }

    // All-time total bar (enriched with daily average km & Baht/km efficiency — zero plist schema change)
    NSString *allKml = (allFuel > 0.005 && allKm > 0.05) ? [NSString stringWithFormat:@"%.1f km/L", allKm/allFuel] : @"--.- km/L";
    NSString *allBpk = (allKm > 0.1 && allCost > 0.01) ? [NSString stringWithFormat:@"%.2f ฿/กม.", allCost/allKm] : @"-- ฿/กม.";
    double avgDayKm = (allDays > 0) ? (allKm / (double)allDays) : 0.0;
    UILabel *allBar=[[UILabel alloc]initWithFrame:CGRectMake(20,172,cardW-40,28)];
    allBar.backgroundColor=[UIColor colorWithRed:0.04 green:0.08 blue:0.12 alpha:1.0];
    allBar.layer.cornerRadius=8; allBar.clipsToBounds=YES;
    allBar.font=[UIFont boldSystemFontOfSize:12.5];
    allBar.adjustsFontSizeToFitWidth=YES; allBar.minimumScaleFactor=0.75;
    allBar.textAlignment=NSTextAlignmentCenter;
    allBar.textColor=[UIColor colorWithRed:0.45 green:0.90 blue:1.0 alpha:1.0];
    allBar.text=[NSString stringWithFormat:@"🏆 สะสม %ld วัน: %.1f km (เฉลี่ย %.1f km/วัน) • %.2f L • ฿%.1f • %@ • %@", (long)allDays, allKm, avgDayKm, allFuel, allCost, allKml, allBpk];
    [card addSubview:allBar];

    // Table header
    UIView *hdrRow=[[UIView alloc]initWithFrame:CGRectMake(20,208,cardW-40,32)];
    hdrRow.backgroundColor=[UIColor colorWithWhite:0.12 alpha:1.0];
    hdrRow.layer.cornerRadius=8;
    [card addSubview:hdrRow];
    NSArray *colX = @[@14, @200, @290, @435, @570, @700];
    NSArray *colW = @[@180, @80, @135, @125, @120, @130];
    NSArray *colT = @[@"วัน / เดือน / ปี", @"รอบ", @"ระยะทาง (km)", @"น้ำมัน (L)", @"เฉลี่ย km/L", @"ค่าน้ำมัน (฿)"];
    for(int c=0; c<6; c++){
      UILabel *hl=[[UILabel alloc]initWithFrame:CGRectMake([colX[c] doubleValue], 6, [colW[c] doubleValue], 20)];
      hl.font=[UIFont boldSystemFontOfSize:12.5];
      hl.textColor=[UIColor colorWithWhite:0.82 alpha:1.0];
      hl.textAlignment=(c==0)?NSTextAlignmentLeft:NSTextAlignmentRight;
      hl.text=colT[c];
      [hdrRow addSubview:hl];
    }

    // Scrollable daily breakdown rows (lightweight plist records)
    UIScrollView *dailyScroll=[[UIScrollView alloc]initWithFrame:CGRectMake(20,244,cardW-40,282)];
    dailyScroll.backgroundColor=[UIColor colorWithRed:0.03 green:0.04 blue:0.06 alpha:1.0];
    dailyScroll.opaque=YES;
    dailyScroll.layer.cornerRadius=10;
    dailyScroll.layer.borderWidth=1;
    dailyScroll.layer.borderColor=[UIColor colorWithWhite:0.16 alpha:1.0].CGColor;
    [card addSubview:dailyScroll];

    CGFloat rowH=44;
    CGFloat cy=4;
    for(NSString *dk in sortedKeys){
      NSDictionary *rec = daysDict[dk];
      if(![rec isKindOfClass:[NSDictionary class]]) continue;
      double dKm = [rec[@"km"] doubleValue];
      double dF = [rec[@"fuelL"] doubleValue];
      double dC = [rec[@"cost"] doubleValue];
      NSInteger dT = [rec[@"trips"] integerValue];
      BOOL isToday = [dk isEqualToString:todayKey];
      NSString *dayText = isToday ? [NSString stringWithFormat:@"วันนี้ • %@", TRDFormatThaiDayLabel(dk)] : TRDFormatThaiDayLabel(dk);
      NSString *dKml = (dF > 0.005 && dKm > 0.05) ? [NSString stringWithFormat:@"%.1f", MAX(3.0, MIN(99.9, dKm/dF))] : @"--.-";

      UIView *row=[[UIView alloc]initWithFrame:CGRectMake(6,cy,cardW-52,rowH-4)];
      row.backgroundColor=isToday?[UIColor colorWithRed:0.04 green:0.13 blue:0.18 alpha:1.0]:[UIColor colorWithRed:0.05 green:0.06 blue:0.09 alpha:1.0];
      row.opaque=YES;
      row.layer.cornerRadius=8;
      if(isToday){
        row.layer.borderWidth=1;
        row.layer.borderColor=[UIColor colorWithRed:0.15 green:0.80 blue:1.0 alpha:0.55].CGColor;
      }
      [dailyScroll addSubview:row];

      NSString *dBpk = (dKm > 0.1 && dC > 0.01) ? [NSString stringWithFormat:@" (%.1f฿/กม.)", dC/dKm] : @"";
      NSArray *vals = @[
        dayText,
        [NSString stringWithFormat:@"%ld", (long)dT],
        [NSString stringWithFormat:@"%.2f km", dKm],
        [NSString stringWithFormat:@"%.2f L", dF],
        [NSString stringWithFormat:@"%@ km/L", dKml],
        [NSString stringWithFormat:@"฿%.1f%@", dC, dBpk]
      ];
      for(int c=0; c<6; c++){
        UILabel *rl=[[UILabel alloc]initWithFrame:CGRectMake([colX[c] doubleValue]-6, 8, [colW[c] doubleValue], 24)];
        rl.font=[UIFont monospacedDigitSystemFontOfSize:14.0 weight:(c==0||c==2||c==5)?UIFontWeightBold:UIFontWeightSemibold];
        rl.adjustsFontSizeToFitWidth=YES; rl.minimumScaleFactor=0.75;
        rl.textAlignment=(c==0)?NSTextAlignmentLeft:NSTextAlignmentRight;
        if(c==5) rl.textColor=[UIColor colorWithRed:1.0 green:0.86 blue:0.35 alpha:1.0];
        else if(c==2||c==3) rl.textColor=[UIColor colorWithRed:0.35 green:0.95 blue:0.65 alpha:1.0];
        else if(c==4) rl.textColor=[UIColor colorWithRed:0.30 green:0.85 blue:1.0 alpha:1.0];
        else rl.textColor=[UIColor whiteColor];
        rl.text=vals[c];
        [row addSubview:rl];
      }
      cy += rowH;
    }
    dailyScroll.contentSize = CGSizeMake(cardW-40, MAX(dailyScroll.bounds.size.height + 1, cy + 6));

    UIButton *btnBackThis=[UIButton buttonWithType:UIButtonTypeCustom];
    btnBackThis.frame=CGRectMake(20,540,(cardW-60)/2,56);
    btnBackThis.backgroundColor=[UIColor colorWithRed:0.12 green:0.16 blue:0.24 alpha:0.95];
    btnBackThis.layer.cornerRadius=14; btnBackThis.layer.borderWidth=1;
    btnBackThis.layer.borderColor=[UIColor colorWithWhite:0.34 alpha:0.7].CGColor;
    [btnBackThis setTitle:@"📍 กลับหน้าสรุปทริปรอบนี้ (THIS TRIP)" forState:UIControlStateNormal];
    [btnBackThis setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnBackThis.titleLabel.font=[UIFont boldSystemFontOfSize:15.5];
    [btnBackThis addTarget:self action:@selector(switchTripSummaryToThis) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:btnBackThis];

    UIButton *btnClose=[UIButton buttonWithType:UIButtonTypeCustom];
    btnClose.frame=CGRectMake(40+(cardW-60)/2,540,(cardW-60)/2,56);
    btnClose.backgroundColor=[UIColor colorWithRed:0.75 green:0.12 blue:0.16 alpha:0.95];
    btnClose.layer.cornerRadius=14; btnClose.layer.borderWidth=1;
    btnClose.layer.borderColor=[UIColor colorWithRed:0.95 green:0.25 blue:0.30 alpha:0.8].CGColor;
    [btnClose setTitle:@"✕ ปิดหน้าต่าง / CLOSE" forState:UIControlStateNormal];
    [btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnClose.titleLabel.font=[UIFont boldSystemFontOfSize:15.5];
    [btnClose addTarget:self action:@selector(hideTripSummary) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:btnClose];
  }

  // Add card to full overlay
  [fullOverlay addSubview:card];

  self.tripSummaryCard=fullOverlay;
  [self.view addSubview:fullOverlay];
  [self.view bringSubviewToFront:fullOverlay];

  if(isUnplugged){
    if(self.activeSummaryTab == 0){
      [self speakGoodbyeMessage];
    }
    NSTimeInterval hideDelay=self.hotCarSaverEnabled?8.0:9.0;
    [self performSelector:@selector(hideTripSummary) withObject:nil afterDelay:hideDelay];
  }
}

-(void)immediateSleepFromTripSummary{
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  if(self.tripSummaryCard){
    [self.tripSummaryCard removeFromSuperview];
    self.tripSummaryCard=nil;
  }
  [self.view setNeedsLayout];
  if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}
  notify_post("com.codex.trd.youtube.pause");
  Boolean (*pCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
  if(!pCmd||!pCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];
  [self screenOff];
}

-(void)hideTripSummary{
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  void (^finishDismiss)(void)=^{
    if([UIDevice currentDevice].batteryState==UIDeviceBatteryStateUnplugged){
      if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}
      notify_post("com.codex.trd.youtube.pause");
      Boolean (*pCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
      if(!pCmd||!pCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];
      [self screenOff];
    }
  };
  if(self.tripSummaryCard){
    UIView *c=self.tripSummaryCard;
    self.tripSummaryCard=nil;
    c.userInteractionEnabled=NO;
    if([UIApplication sharedApplication].applicationState!=UIApplicationStateActive){
      [c removeFromSuperview];
      [self.view setNeedsLayout];
      finishDismiss();
      return;
    }
    [UIView animateWithDuration:0.3 animations:^{
      c.alpha=0;
    } completion:^(BOOL finished){
      [c removeFromSuperview];
      [self.view setNeedsLayout];
      finishDismiss();
    }];
  }else if([UIApplication sharedApplication].applicationState!=UIApplicationStateActive){
    finishDismiss();
  }
}
-(void)tractionMotorTapped{
  [self showFeatureExplanation:@"⚙️ มอเตอร์ขับเคลื่อน MG2 & เจเนอเรเตอร์ MG1" body:@"• มอเตอร์ไฟฟ้าหลัก MG2 (Traction Motor): กำลังขับ 60 kW (80 แรงม้า) แรงบิดสูงสุด 207 Nm ขับเคลื่อนล้อหน้าโดยตรง ออกตัวเงียบและตอบสนองทันที\n• เจเนอเรเตอร์ MG1: ทำหน้าที่สตาร์ทเครื่องยนต์ 1.8L อย่างนุ่มนวล และปั่นไฟชาร์จกลับเข้าแบตเตอรี่ไฮบริด\n• Inverter ระบายความร้อนด้วยระบบน้ำแยกอิสระ พร้อมระบบชาร์จไฟกลับขณะเบรก (Regenerative Braking) สูงสุด 20+ kW"];
}
-(void)batteryStateChanged:(NSNotification *)note{
 UIDeviceBatteryState state=[UIDevice currentDevice].batteryState;
 BOOL isPowered=(state==UIDeviceBatteryStateCharging||state==UIDeviceBatteryStateFull);
 NSInteger logicalPower=isPowered?1:0;
 static NSInteger lastLogicalPower=-1;
 // Ignore Charging <-> Full ripples at 100% battery completely so navigation and menus never pause!
 if(lastLogicalPower==logicalPower && !(logicalPower==1 && !self.isCarSessionActive)){
  return;
 }
 lastLogicalPower=logicalPower;
 [self cancelNavigationTouch:nil forEvent:nil];
 self.mapConfirmationGeneration++;
 self.mapURLRequestGeneration++;
 self.mapNavigationAuthorized=NO;
 self.navGuardUntil=MAX(self.navGuardUntil,[NSProcessInfo processInfo].systemUptime+0.4);
 if(self.settingsSheet.requiresIntentionalTouch)[self.settingsSheet dismiss];
 [self logNavigation:isPowered?@"power connected":@"power unplugged"];
 if(state==UIDeviceBatteryStateUnplugged){
  NSUInteger gen=++self.unplugCheckGeneration;
  __weak Dashboard *weakSelf=self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   Dashboard *strongSelf=weakSelf;
   if(!strongSelf || gen!=strongSelf.unplugCheckGeneration)return;
   if([UIDevice currentDevice].batteryState!=UIDeviceBatteryStateUnplugged)return;
   // Confirmed unplug: immediately stop background GPS/BLE & idleTimerDisabled, clean caches safely, show trip summary
   strongSelf.isCarSessionActive=NO;
   [UIApplication sharedApplication].idleTimerDisabled=NO;
   if([strongSelf.gps respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)])strongSelf.gps.allowsBackgroundLocationUpdates=NO;
   [strongSelf.gps stopUpdatingLocation];
   [[TRDOBDClient sharedClient] stopScanning];
   NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];
   [ud setBool:NO forKey:@"TRDWelcomeShownForSession"];
   [ud setBool:NO forKey:@"TRDSkipNextLaunchWelcome"];
   [ud setDouble:0 forKey:@"TRDLastActiveTimestamp"];
   [ud synchronize];
   [[NSURLCache sharedURLCache] removeAllCachedResponses];
   [strongSelf releaseArtwork];
   trd_run_bg("killall -9 YTNine Maps 2>/dev/null");
   if([UIApplication sharedApplication].applicationState==UIApplicationStateBackground){
    if(strongSelf.radioPlayer){[strongSelf.radioPlayer pause];strongSelf.radioPlayer=nil;}
    notify_post("com.codex.trd.youtube.pause");
    Boolean (*pCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
    if(!pCmd||!pCmd(1,nil))[strongSelf send:@"libactivator.ipod.pause-playback"];
    [strongSelf screenOff];
   }else{
    [strongSelf showTripSummary];
   }
  });
 }else if(isPowered){
  self.unplugCheckGeneration++;
  // Only run Welcome ONCE per car power-on session; ignore Charging<->Full ripples!
  if(self.isCarSessionActive) return;
  self.isCarSessionActive = YES;
  NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];
  [ud setBool:YES forKey:@"TRDWelcomeShownForSession"];
  [ud setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"TRDLastActiveTimestamp"];
  [ud synchronize];

  self.navGuardUntil = MAX(self.navGuardUntil,[NSProcessInfo processInfo].systemUptime + 0.35);
  self.view.userInteractionEnabled = YES;

  [self syncTripSlotsDelta:YES];
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  if(self.tripSummaryCard){
   [self.tripSummaryCard removeFromSuperview];
   self.tripSummaryCard=nil;
  }
  self.trip=[TRDTrip new];
  [self saveTrip];
  [[TRDOBDClient sharedClient] resetTripFuel];
  self.lastSlotMeters = 0.0;
  self.lastSlotSeconds = 0.0;
  self.lastSlotFuel = 0.0;
  self.lastSlotCost = 0.0;
  [ud setDouble:0.0 forKey:@"TRDLastSyncedTripMeters"];
  [ud setDouble:0.0 forKey:@"TRDLastSyncedTripSeconds"];
  [ud setDouble:0.0 forKey:@"TRDLastSyncedTripFuel"];
  [ud setDouble:0.0 forKey:@"TRDLastSyncedTripCost"];
  [ud setObject:@{@"km":@(0.0), @"sec":@(0.0), @"fuel":@(0.0), @"cost":@(0.0), @"maf":@(NO)} forKey:@"TRDTripSlot_0"];
  [ud synchronize];
  self.sessionLoggedToday = NO;
  [[TRDOBDClient sharedClient] ensureConnectedOrScan];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
   if(![[TRDOBDClient sharedClient] isConnected]){
    [[TRDOBDClient sharedClient] ensureConnectedOrScan];
   }
  });
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
   self.ownsSpeechAudioSession = YES;
   if(!gTRDWelcomeSynth) gTRDWelcomeSynth = [[AVSpeechSynthesizer alloc] init];
   if([gTRDWelcomeSynth isSpeaking]){
    [gTRDWelcomeSynth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
   }
   NSInteger voiceLang = [[NSUserDefaults standardUserDefaults] integerForKey:@"TRDVoiceLanguage"];
   BOOL hasThai = ([phrase rangeOfCharacterFromSet:[NSCharacterSet characterSetWithRange:NSMakeRange(0x0E00, 128)]].location != NSNotFound);
   NSString *langCode = (voiceLang == 1 || hasThai) ? @"th-TH" : @"en-US";
   float rate = [langCode isEqualToString:@"th-TH"] ? 0.46f : 0.44f;
   TRDEnqueueCalmSpeech(gTRDWelcomeSynth, @[phrase], langCode, rate);
   __weak typeof(self) weakSelf = self;
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    Dashboard *v = weakSelf;
    if(v && !v.radioPlayer && v.ownsSpeechAudioSession && (!gTRDWelcomeSynth || !gTRDWelcomeSynth.isSpeaking)){
     v.ownsSpeechAudioSession = NO;
     [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
   });
  } @catch(NSException *e){}
 });
}

static NSString *TRDJSStringLiteral(NSString *str){
  NSArray *arr = @[str ?: @""];
  NSData *d = [NSJSONSerialization dataWithJSONObject:arr options:0 error:nil];
  if(!d) return @"\"\"";
  NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
  if(s.length >= 2) return [s substringWithRange:NSMakeRange(1, s.length - 2)];
  return @"\"\"";
}

-(void)navigateToNearestGasStation{
  [self dismissLowFuelBanner];
  [self.settingsSheet dismiss];
  if(self.fix){
    CLLocation *curLoc = self.fix;
    MKLocalSearchRequest *req = [[MKLocalSearchRequest alloc] init];
    req.naturalLanguageQuery = @"ปั๊มน้ำมัน";
    req.region = MKCoordinateRegionMakeWithDistance(curLoc.coordinate, 25000, 25000);
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:req];
    __weak Dashboard *weak = self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *resp, NSError *err){
      dispatch_async(dispatch_get_main_queue(), ^{
        MKMapItem *best = nil;
        double bestDist = 1e12;
        for(MKMapItem *item in resp.mapItems){
          CLLocation *loc = item.placemark.location;
          if(!loc) continue;
          double d = [curLoc distanceFromLocation:loc];
          if(d <= 50000.0 && d < bestDist){ bestDist = d; best = item; }
        }
        if(best){
          weak.nearestStationName = best.name ?: @"ปั๊มน้ำมัน";
          weak.nearestStationKm = bestDist / 1000.0;
          weak.nearestStationLat = best.placemark.coordinate.latitude;
          weak.nearestStationLon = best.placemark.coordinate.longitude;
          weak.nearestStationAddress = best.placemark.title ?: @"";
          [weak openMapToLat:weak.nearestStationLat lon:weak.nearestStationLon name:weak.nearestStationName address:weak.nearestStationAddress autoStart:YES];
        }else{
          [weak openMapWithSearchQuery:@"ปั๊มน้ำมัน"];
        }
      });
    }];
    return;
  }
  [self openMapWithSearchQuery:@"ปั๊มน้ำมัน"];
}

static NSData *TRDBuildLoudBeepWAVData(void){
  const int sampleRate = 22050;
  const double totalSec = 0.85;
  const int numSamples = (int)(sampleRate * totalSec);
  int dataBytes = numSamples * 2;
  int riffSize = 36 + dataBytes;
  NSMutableData *wav = [NSMutableData dataWithCapacity:44 + dataBytes];
  unsigned char hdr[44] = {
    'R','I','F','F',
    (unsigned char)(riffSize & 0xff), (unsigned char)((riffSize>>8)&0xff), (unsigned char)((riffSize>>16)&0xff), (unsigned char)((riffSize>>24)&0xff),
    'W','A','V','E','f','m','t',' ',
    16,0,0,0, 1,0, 1,0,
    (unsigned char)(sampleRate & 0xff), (unsigned char)((sampleRate>>8)&0xff), 0,0,
    (unsigned char)((sampleRate*2)&0xff), (unsigned char)(((sampleRate*2)>>8)&0xff), 0,0,
    2,0, 16,0,
    'd','a','t','a',
    (unsigned char)(dataBytes & 0xff), (unsigned char)((dataBytes>>8)&0xff), (unsigned char)((dataBytes>>16)&0xff), (unsigned char)((dataBytes>>24)&0xff)
  };
  [wav appendBytes:hdr length:44];
  int16_t *pcm = (int16_t *)calloc((size_t)numSamples, sizeof(int16_t));
  if(pcm){
    // 3 sharp dual-tone beeps (0.00-0.18s, 0.28-0.46s, 0.56-0.80s) at 1760Hz + 2349Hz
    double starts[3] = {0.0, 0.28, 0.56};
    double ends[3]   = {0.18, 0.46, 0.80};
    for(int i=0; i<numSamples; i++){
      double t = (double)i / (double)sampleRate;
      double amp = 0.0;
      for(int p=0; p<3; p++){
        if(t >= starts[p] && t <= ends[p]){
          double env = 1.0;
          double dtEnd = ends[p] - t;
          if(t - starts[p] < 0.008) env = (t - starts[p]) / 0.008;
          else if(dtEnd < 0.015) env = dtEnd / 0.015;
          amp = 0.92 * env * (0.60 * sin(2.0 * M_PI * 1760.0 * t) + 0.40 * sin(2.0 * M_PI * 2349.0 * t));
          break;
        }
      }
      if(amp > 1.0) amp = 1.0; if(amp < -1.0) amp = -1.0;
      pcm[i] = (int16_t)(amp * 32000.0);
    }
    [wav appendBytes:pcm length:(NSUInteger)dataBytes];
    free(pcm);
  }
  return wav;
}

-(void)playLoudLowFuelAlarmSound{
  @try {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
    [session setActive:YES error:nil];
    NSData *wav = TRDBuildLoudBeepWAVData();
    if(wav.length > 44){
      NSError *err = nil;
      self.alarmAudioPlayer = [[AVAudioPlayer alloc] initWithData:wav error:&err];
      if(self.alarmAudioPlayer && !err){
        self.alarmAudioPlayer.volume = 1.0f;
        [self.alarmAudioPlayer prepareToPlay];
        [self.alarmAudioPlayer play];
      }
    }
  } @catch(NSException *e){}
  AudioServicesPlaySystemSound(1005);
}

-(void)dismissLowFuelBanner{
  if(self.lowFuelBanner){
    UIView *b = self.lowFuelBanner;
    self.lowFuelBanner = nil;
    b.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.2 animations:^{ b.alpha = 0; } completion:^(BOOL fin){ [b removeFromSuperview]; }];
  }
}

-(void)navigateToFoundGasStation{
  [self dismissLowFuelBanner];
  [self.settingsSheet dismiss];
  if(fabs(self.nearestStationLat) > 0.001 && fabs(self.nearestStationLon) > 0.001){
    [self openMapToLat:self.nearestStationLat
                   lon:self.nearestStationLon
                  name:(self.nearestStationName ?: @"ปั๊มน้ำมันใกล้ที่สุด")
               address:(self.nearestStationAddress ?: @"")
             autoStart:YES];
    return;
  }
  [self navigateToNearestGasStation];
}

-(void)checkLowFuelWarning{
  TRDOBDClient *obd = [TRDOBDClient sharedClient];
  if(!obd.isConnected || !obd.obdInitialized || !obd.hasLiveFuelLevel){
    self.lowFuelConfirmTicks = 0;
    return;
  }
  double fuelL = obd.fuelRemainingLiters;
  double pct = obd.fuelLevelPercent;
  // Ignore cluster 0x00 sweep when switching car IG-OFF
  if(fuelL < 0.8 || pct < 1.5){
    self.lowFuelConfirmTicks = 0;
    return;
  }
  double rangeKm = [self estimatedRangeKmForFuelLiters:fuelL];

  if(fuelL > 9.5 && pct > 21.0){
    self.lowFuelConfirmTicks = 0;
    self.lowFuelStage1Alerted = NO;
    self.lowFuelStage2Alerted = NO;
    return;
  }
  if(fuelL <= 7.0 || pct <= 15.5 || rangeKm <= 100.0){
    if(self.lowFuelConfirmTicks < 3){
      self.lowFuelConfirmTicks++;
      if(self.lowFuelConfirmTicks < 2) return;
    }
  }else{
    self.lowFuelConfirmTicks = 0;
  }
  if(!self.lowFuelStage2Alerted && (fuelL <= 4.5 || pct <= 10.0 || rangeKm <= 60.0)){
    self.lowFuelStage2Alerted = YES;
    self.lowFuelStage1Alerted = YES;
    [self showLowFuelPopupWithLiters:fuelL pct:pct rangeKm:rangeKm critical:YES isDemo:NO];
  }else if(!self.lowFuelStage1Alerted && (fuelL <= 7.0 || pct <= 15.5 || rangeKm <= 100.0)){
    self.lowFuelStage1Alerted = YES;
    [self showLowFuelPopupWithLiters:fuelL pct:pct rangeKm:rangeKm critical:NO isDemo:NO];
  }
}

-(void)testLowFuelWarning{
  [self showLowFuelPopupWithLiters:5.2 pct:11.6 rangeKm:98.0 critical:YES isDemo:YES];
}

-(void)showLowFuelPopupWithLiters:(double)fuelL pct:(double)pct rangeKm:(double)rangeKm critical:(BOOL)critical isDemo:(BOOL)isDemo{
  [self dismissLowFuelBanner];
  [self playLoudLowFuelAlarmSound];

  CGFloat w = self.view.bounds.size.width ?: 1024;
  CGFloat h = self.view.bounds.size.height ?: 768;
  UIView *dim = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
  dim.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
  dim.layer.zPosition = 99990;

  CGFloat cw = 600, ch = 290;
  UIView *card = [[UIView alloc] initWithFrame:CGRectMake((w - cw)/2.0, (h - ch)/2.0, cw, ch)];
  card.backgroundColor = critical ? [UIColor colorWithRed:0.14 green:0.02 blue:0.03 alpha:0.98] : [UIColor colorWithRed:0.12 green:0.07 blue:0.01 alpha:0.98];
  card.opaque = YES;
  card.layer.cornerRadius = 18;
  card.layer.borderWidth = 2.5;
  card.layer.borderColor = critical ? [UIColor colorWithRed:1.0 green:0.20 blue:0.24 alpha:1.0].CGColor : [UIColor colorWithRed:1.0 green:0.75 blue:0.12 alpha:1.0].CGColor;
  [dim addSubview:card];

  UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(20, 14, cw - 40, 32)];
  hdr.font = [UIFont boldSystemFontOfSize:22];
  hdr.textColor = critical ? [UIColor colorWithRed:1.0 green:0.30 blue:0.34 alpha:1.0] : [UIColor colorWithRed:1.0 green:0.82 blue:0.22 alpha:1.0];
  hdr.text = isDemo
    ? (critical ? @"🚨 [ตัวอย่าง] แจ้งเตือนน้ำมันใกล้หมด!" : @"⚠️ [ตัวอย่าง] เตือนน้ำมันใกล้หมดล่วงหน้า")
    : (critical ? @"🚨 แจ้งเตือนด่วน: น้ำมันใกล้หมดถังแล้ว!" : @"⚠️ แจ้งเตือนล่วงหน้า: ควรเตรียมเติมน้ำมัน");
  [card addSubview:hdr];

  UILabel *mainStat = [[UILabel alloc] initWithFrame:CGRectMake(20, 52, cw - 40, 44)];
  mainStat.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:32] ?: [UIFont boldSystemFontOfSize:30];
  mainStat.textColor = [UIColor whiteColor];
  mainStat.text = [NSString stringWithFormat:@"เหลือ %.1f ลิตร (%.0f%%)  •  วิ่งต่อได้ ~%.0f กม.", fuelL, pct, rangeKm];
  mainStat.adjustsFontSizeToFitWidth = YES; mainStat.minimumScaleFactor = 0.72;
  [card addSubview:mainStat];

  UILabel *pumpLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 104, cw - 40, 62)];
  pumpLbl.tag = 951;
  pumpLbl.numberOfLines = 2;
  pumpLbl.font = [UIFont boldSystemFontOfSize:17.5];
  pumpLbl.textColor = [UIColor colorWithRed:0.35 green:0.95 blue:1.0 alpha:1.0];
  pumpLbl.text = self.fix ? @"🔍 กำลังค้นหาปั๊มน้ำมันที่ใกล้พิกัด GPS ที่สุด..." : @"📍 รอสัญญาณ GPS เพื่อเช็คระยะทางไปยังปั๊มน้ำมันใกล้เคียง (แตะปุ่มด้านล่างเพื่อนำทาง)";
  [card addSubview:pumpLbl];

  UILabel *subInfo = [[UILabel alloc] initWithFrame:CGRectMake(20, 174, cw - 40, 22)];
  subInfo.font = [UIFont boldSystemFontOfSize:13.0];
  subInfo.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
  subInfo.text = @"🔊 เสียงบี๊บเตือน + เสียงพูดไทยออกลำโพง iPad Mini 2 / รถยนต์ (เกณฑ์เตือน <15% และ <10%)";
  [card addSubview:subInfo];

  UIButton *navBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  navBtn.frame = CGRectMake(20, 212, cw - 200, 56);
  navBtn.backgroundColor = [UIColor colorWithRed:0.06 green:0.55 blue:0.28 alpha:1.0];
  navBtn.layer.cornerRadius = 12; navBtn.layer.borderWidth = 1.5;
  navBtn.layer.borderColor = [UIColor colorWithRed:0.30 green:1.0 blue:0.60 alpha:0.9].CGColor;
  [navBtn setTitle:@"🗺️ นำทางไปปั๊มน้ำมันใกล้ที่สุด" forState:UIControlStateNormal];
  [navBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  navBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
  [navBtn addTarget:self action:@selector(navigateToFoundGasStation) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:navBtn];

  UIButton *okBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  okBtn.frame = CGRectMake(cw - 166, 212, 146, 56);
  okBtn.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
  okBtn.layer.cornerRadius = 12; okBtn.layer.borderWidth = 1.2;
  okBtn.layer.borderColor = [UIColor colorWithWhite:0.45 alpha:0.8].CGColor;
  [okBtn setTitle:@"✓ รับทราบ" forState:UIControlStateNormal];
  [okBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  okBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
  [okBtn addTarget:self action:@selector(dismissLowFuelBanner) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:okBtn];

  self.lowFuelBanner = dim;
  [self.view addSubview:dim];
  [self.view bringSubviewToFront:dim];

  self.nearestStationName = nil;
  self.nearestStationAddress = nil;
  self.nearestStationKm = 0.0;
  self.nearestStationLat = 0.0;
  self.nearestStationLon = 0.0;

  if(self.fix){
    CLLocation *curLoc = self.fix;
    MKLocalSearchRequest *req = [[MKLocalSearchRequest alloc] init];
    req.naturalLanguageQuery = @"ปั๊มน้ำมัน";
    req.region = MKCoordinateRegionMakeWithDistance(curLoc.coordinate, 25000, 25000);
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:req];
    __weak Dashboard *weak = self;
    [search startWithCompletionHandler:^(MKLocalSearchResponse *resp, NSError *err){
      dispatch_async(dispatch_get_main_queue(), ^{
        MKMapItem *best = nil;
        double bestDist = 1e12;
        for(MKMapItem *item in resp.mapItems){
          CLLocation *loc = item.placemark.location;
          if(!loc) continue;
          double d = [curLoc distanceFromLocation:loc];
          if(d <= 50000.0 && d < bestDist){ bestDist = d; best = item; }
        }
        NSString *voiceMsg = nil;
        if(best){
          double dKm = bestDist / 1000.0;
          weak.nearestStationName = best.name ?: @"ปั๊มน้ำมัน";
          weak.nearestStationAddress = best.placemark.title ?: @"";
          weak.nearestStationKm = dKm;
          weak.nearestStationLat = best.placemark.coordinate.latitude;
          weak.nearestStationLon = best.placemark.coordinate.longitude;
          if(weak.lowFuelBanner){
            UILabel *pl = (UILabel *)[weak.lowFuelBanner viewWithTag:951];
            if(pl){
              pl.text = [NSString stringWithFormat:@"⛽ ปั๊มใกล้ที่สุด: %@ (ห่าง %.1f กม.)\n%@ — แตะปุ่มสีเขียวเพื่อนำทางทันที",
                         weak.nearestStationName, dKm, weak.nearestStationAddress];
            }
          }
          voiceMsg = [NSString stringWithFormat:@"แจ้งเตือน น้ำมันใกล้หมด เหลือ %.1f ลิตร วิ่งได้อีกประมาณ %.0f กิโลเมตร ปั๊มน้ำมันที่ใกล้ที่สุด %@ ห่าง %.1f กิโลเมตรครับ", fuelL, rangeKm, weak.nearestStationName, dKm];
        }else{
          if(weak.lowFuelBanner){
            UILabel *pl = (UILabel *)[weak.lowFuelBanner viewWithTag:951];
            if(pl) pl.text = @"⛽ แตะปุ่มสีเขียวด้านล่างเพื่อเปิดแผนที่ค้นหาปั๊มน้ำมันใกล้ที่สุด";
          }
          voiceMsg = [NSString stringWithFormat:@"แจ้งเตือน น้ำมันใกล้หมด เหลือ %.1f ลิตร วิ่งได้อีกประมาณ %.0f กิโลเมตร แนะนำให้แวะเติมน้ำมันครับ", fuelL, rangeKm];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [weak speakQuickAlert:voiceMsg];
        });
      });
    }];
  }else{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      NSString *voiceMsg = [NSString stringWithFormat:@"แจ้งเตือน น้ำมันใกล้หมด เหลือ %.1f ลิตร วิ่งได้อีกประมาณ %.0f กิโลเมตร กรุณาแวะเติมน้ำมันครับ", fuelL, rangeKm];
      [self speakQuickAlert:voiceMsg];
    });
  }
}

-(void)navigateToNearestRestArea{
  [self dismissLowFuelBanner];
  [self.settingsSheet dismiss];
  [self openMapWithSearchQuery:@"คาเฟ่ จุดพักรถ"];
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

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{self.gpsUpdates++;self.gpsError=nil;self.fix=[locations lastObject];BOOL wasRunning=self.trip.running;for(CLLocation *fix in locations){double fixKmh=(fix&&fix.speed>=0)?(fix.speed*3.6):0.0;if(fixKmh>=2.0&&fix.horizontalAccuracy>=0&&fix.horizontalAccuracy<=45.0){[self.trip accept:fix now:[NSDate date]];}else{[self.trip breakSegment];}}if(wasRunning!=self.trip.running||!self.lastTripSavedAt||-[self.lastTripSavedAt timeIntervalSinceNow]>=5)[self saveTrip];double spd=(self.fix.speed>=0)?(self.fix.speed*3.6):0;if(spd>=2.0)[[TRDOBDClient sharedClient] integrateFallbackFuelForDistanceKm:(self.trip.meters/1000.0) speedKmh:spd dtSeconds:1.0];
 [self trackOdometerUpdates];
 [self checkSpeedCamerasNearLocation:self.fix];
 if(!self.hasFetchedWeather && self.fix && self.fix.horizontalAccuracy>0 && self.fix.horizontalAccuracy<=1000){
  self.hasFetchedWeather=YES;
  [self fetchWeatherForCoordinate:self.fix.coordinate];
 }if([UIApplication sharedApplication].applicationState!=UIApplicationStateBackground){[self refreshSpeed];[self refreshTrip];[self updateMapCar];}}
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{self.gpsError=error.description;self.fix=nil;[self.trip breakSegment];[self saveTrip];[self refreshSpeed];[self refreshTrip];}
-(BOOL)launchBundleApp:(NSString *)identifier{
 if(!identifier.length || [identifier isEqualToString:@"com.apple.camera"])return NO;
 static uint64_t trdLaunchGeneration=0;
 uint64_t gen=++trdLaunchGeneration;
 [self logNavigation:[NSString stringWithFormat:@"launchBundleApp: %@",identifier]];
 if([identifier isEqualToString:@"com.codex.h109viewer"] || [identifier isEqualToString:@"com.codex.cardash"]){
  const char *notif=[identifier isEqualToString:@"com.codex.h109viewer"]?"com.codex.trd.launch.h109viewer":"com.codex.trd.launch.cardash";
  notify_post(notif);
  __weak typeof(self) weakSelf=self;
  dispatch_async(dispatch_get_main_queue(),^{
   [weakSelf refreshNowPlaying];
  });
  if([identifier isEqualToString:@"com.codex.h109viewer"] && [UIApplication sharedApplication].applicationState!=UIApplicationStateBackground){
   NSString *targetID=[identifier copy];
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.65*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
    if(gen!=trdLaunchGeneration)return;
    if([UIApplication sharedApplication].applicationState!=UIApplicationStateActive)return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
     Class wsClass=NSClassFromString(@"LSApplicationWorkspace");
     if(!wsClass){
      dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
      wsClass=NSClassFromString(@"LSApplicationWorkspace");
     }
     id ws=(wsClass && [wsClass respondsToSelector:@selector(defaultWorkspace)])?((id (*)(id, SEL))objc_msgSend)(wsClass,@selector(defaultWorkspace)):nil;
     if(ws && [ws respondsToSelector:@selector(openApplicationWithBundleID:)]){
      ((BOOL (*)(id, SEL, NSString *))objc_msgSend)(ws,@selector(openApplicationWithBundleID:),targetID);
     }
    });
   });
  }
  return YES;
 }
 if([identifier isEqualToString:@"com.apple.Preferences"] && (&UIApplicationOpenSettingsURLString != NULL)){
  NSURL *settingsURL=[NSURL URLWithString:UIApplicationOpenSettingsURLString];
  UIApplication *app=[UIApplication sharedApplication];
  if(settingsURL && [app canOpenURL:settingsURL]){
   [app openURL:settingsURL];
   [self refreshNowPlaying];
   return YES;
  }
 }
 NSDictionary *schemeMap=@{
  @"com.himais0giiiin.ytnine":@"ytnine://",
  @"com.google.ios.youtube":@"youtube://",
  @"com.legacymusic.app":@"legacymusic://",
  @"com.apple.Maps":@"maps://"
 };
 NSString *schemeStr=schemeMap[identifier];
 if(schemeStr.length){
  NSURL *targetURL=[NSURL URLWithString:schemeStr];
  UIApplication *app=[UIApplication sharedApplication];
  NSString *targetID=[identifier copy];
  __weak typeof(self) weakSelf=self;
  void (^sbFallback)(void)=^{
   if([targetID isEqualToString:@"com.himais0giiiin.ytnine"])notify_post("com.codex.trd.launch.ytnine");
   else if([targetID isEqualToString:@"com.legacymusic.app"])notify_post("com.codex.trd.launch.legacymusic");
   dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
    Class wsClass=NSClassFromString(@"LSApplicationWorkspace");
    if(!wsClass){
     dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
     wsClass=NSClassFromString(@"LSApplicationWorkspace");
    }
    id ws=(wsClass && [wsClass respondsToSelector:@selector(defaultWorkspace)])?((id (*)(id, SEL))objc_msgSend)(wsClass,@selector(defaultWorkspace)):nil;
    BOOL launched=NO;
    if(ws && [ws respondsToSelector:@selector(openApplicationWithBundleID:)]){
     launched=((BOOL (*)(id, SEL, NSString *))objc_msgSend)(ws,@selector(openApplicationWithBundleID:),targetID);
    }
    if(!launched){
     void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
     if(sbs){
      int (*launch)(CFStringRef, Boolean)=(int (*)(CFStringRef, Boolean))dlsym(sbs, "SBSLaunchApplicationWithIdentifier");
      if(launch && launch((__bridge CFStringRef)targetID, false)==0)launched=YES;
     }
    }
    if(!launched){
     dispatch_async(dispatch_get_main_queue(),^{
      Dashboard *v=weakSelf;
      if(v && [UIApplication sharedApplication].applicationState==UIApplicationStateActive){
       [v logNavigation:[NSString stringWithFormat:@"launch failed: %@",targetID]];
      }
     });
    }
   });
  };
  if(targetURL && [app respondsToSelector:@selector(openURL:options:completionHandler:)]){
   [app openURL:targetURL options:@{} completionHandler:^(BOOL success){
    [weakSelf logNavigation:[NSString stringWithFormat:@"openURL %@ -> %d",schemeStr,success?1:0]];
    if(success){
     [weakSelf refreshNowPlaying];
    }else{
     sbFallback();
    }
   }];
   return YES;
  }
  if(targetURL && [app openURL:targetURL]){
   [self logNavigation:[NSString stringWithFormat:@"legacy openURL %@ -> 1",schemeStr]];
   [self refreshNowPlaying];
   return YES;
  }
 }
 Class wsClass=NSClassFromString(@"LSApplicationWorkspace");
 if(!wsClass){
  dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
  wsClass=NSClassFromString(@"LSApplicationWorkspace");
 }
 id ws=(wsClass && [wsClass respondsToSelector:@selector(defaultWorkspace)])?((id (*)(id, SEL))objc_msgSend)(wsClass,@selector(defaultWorkspace)):nil;
 if(ws && [ws respondsToSelector:@selector(applicationIsInstalled:)]){
  BOOL installed=((BOOL (*)(id, SEL, NSString *))objc_msgSend)(ws,@selector(applicationIsInstalled:),identifier);
  if(!installed)return NO;
 }
 if(ws && [ws respondsToSelector:@selector(openApplicationWithBundleID:)]){
  NSString *targetID=[identifier copy];
  __weak typeof(self) weakSelf=self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
   BOOL launched=((BOOL (*)(id, SEL, NSString *))objc_msgSend)(ws,@selector(openApplicationWithBundleID:),targetID);
   if(!launched){
    void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    if(sbs){
     int (*launch)(CFStringRef, Boolean)=(int (*)(CFStringRef, Boolean))dlsym(sbs, "SBSLaunchApplicationWithIdentifier");
     if(launch && launch((__bridge CFStringRef)targetID, false)==0){
      launched=YES;
     }
    }
   }
   if(launched){
    dispatch_async(dispatch_get_main_queue(),^{
     [weakSelf refreshNowPlaying];
    });
   }
  });
  return YES;
 }
 void *sbs=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
 if(sbs){
  int (*launch)(CFStringRef, Boolean)=(int (*)(CFStringRef, Boolean))dlsym(sbs, "SBSLaunchApplicationWithIdentifier");
  if(launch&&launch((__bridge CFStringRef)identifier, false)==0){
   [self refreshNowPlaying];
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
-(void)teardownMapWebView{if(self.mapWebView){[self.mapWebView stopLoading];[self.mapWebView loadHTMLString:@"" baseURL:nil];[self.mapWebView removeFromSuperview];self.mapWebView.delegate=nil;self.mapWebView=nil;}self.mapContainer.hidden=YES;}
-(UIWebView *)ensureMapWebView{if(!self.mapWebView){NSURLCache *cache=[NSURLCache sharedURLCache];cache.memoryCapacity=2*1024*1024;cache.diskCapacity=24*1024*1024;self.mapWebView=[[UIWebView alloc]initWithFrame:self.mapContainer.bounds];self.mapWebView.backgroundColor=[UIColor clearColor];self.mapWebView.opaque=NO;self.mapWebView.scrollView.backgroundColor=[UIColor colorWithRed:0.067 green:0.075 blue:0.10 alpha:1.0];self.mapWebView.scalesPageToFit=NO;self.mapWebView.scrollView.scrollEnabled=NO;self.mapWebView.scrollView.bounces=NO;self.mapWebView.delegate=self;[self.mapContainer addSubview:self.mapWebView];}return self.mapWebView;}
-(void)openCarPlay{if(![self authorizeMapNavigation:YES])return;[self logNavigation:@"opened CarPlay"];self.navGuardUntil=[NSProcessInfo processInfo].systemUptime+0.18;if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}[self dismissLowFuelBanner];[self.settingsSheet dismiss];notify_post("com.codex.trd.network.internet.force");self.tripMode=NO;self.mapMode=NO;self.musicMode=NO;self.driveMode=NO;self.focused=NO;self.carplayMode=YES;self.carplayGridMode=NO;[self.view setNeedsLayout];[self.view layoutIfNeeded];[self ensureMapWebView];if(!self.mapWebView.request)[self loadMapHTML];else if(!self.mapWebView.loading)[self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.map){window.map.invalidateSize(false);}if(!window.navActive){var sc=document.getElementById('search-container');if(sc)sc.style.display='block';var lb=document.getElementById('layer-bar');if(lb){lb.style.display='-webkit-flex';lb.style.display='flex';}}"];[self updateMapCarForce:YES];[self update];}
-(void)toggleCarPlayGrid{self.carplayGridMode=!self.carplayGridMode;[self.view setNeedsLayout];}
-(void)carplayTapMap{if(self.carplayGridMode){self.carplayGridMode=NO;[self.view setNeedsLayout];}else if(self.mapWebView.request && !self.mapWebView.loading){[self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.recenter)window.recenter();"];}}
-(void)carplayTapMusic{if(self.carplayGridMode){self.carplayGridMode=NO;[self.view setNeedsLayout];}[self showMusicSources:nil];}
-(void)carplayGridMusic{self.carplayGridMode=NO;[self.view setNeedsLayout];[self showMusicSources:nil];}
-(void)carplayGridMap{self.carplayGridMode=NO;[self.view setNeedsLayout];}
-(void)carplayGridTrip{self.carplayMode=NO;self.carplayGridMode=NO;[self openTrip];}
-(void)carplayGridSettings{[self carSettings];}
-(void)handleEdgePan:(UIScreenEdgePanGestureRecognizer *)gesture{if(gesture.state==UIGestureRecognizerStateBegan||gesture.state==UIGestureRecognizerStateRecognized){if(self.carplayMode||self.mapMode)[self homePage];}}
-(void)prepareForExternalAppLaunch{
 if(self.welcome)[self hideWelcome];
 [self.settingsSheet dismiss];
 self.mapContainer.hidden=YES;
 NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];
 [ud setBool:YES forKey:@"TRDSkipNextLaunchWelcome"];
 [ud setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"TRDLastActiveTimestamp"];
 [ud synchronize];
}
-(void)openYouTubeSource{
 [self cancelNavigationTouch:nil forEvent:nil];
 [self prepareForExternalAppLaunch];
 self.radioGeneration++;
 if(self.radioPlayer){[self.radioPlayer pause];[self.radioPlayer replaceCurrentItemWithPlayerItem:nil];self.radioPlayer=nil;}
 [self logNavigation:@"opening YouTube (ytnine)"];
 notify_post("com.codex.trd.network.internet.force");
 [self send:@"com.himais0giiiin.ytnine"];
}
-(void)logNavigation:(NSString *)message{
 [[TRDOBDClient sharedClient] obdLog:@"NAV %@",message];
}
-(void)logNavigationReject:(NSString *)reason{
 NSTimeInterval now=[NSProcessInfo processInfo].systemUptime;
 if([self.lastNavigationRejectReason isEqualToString:reason] && now-self.lastNavigationRejectAt<5.0)return;
 self.lastNavigationRejectReason=reason;
 self.lastNavigationRejectAt=now;
 [self logNavigation:[@"blocked: " stringByAppendingString:reason]];
}
-(BOOL)isNavigationControlVisible:(UIButton *)button{
 if(!button || !button.enabled || !button.window)return NO;
 for(UIView *v=button;v;v=v.superview){
  if(v.hidden || v.alpha<=0.01 || !v.userInteractionEnabled)return NO;
 }
 return YES;
}
-(void)cancelNavigationTouch:(id)sender forEvent:(UIEvent *)event{
 self.navTouchDownTag=0;
 self.navTrackingTouch=nil;
 self.navTouchDownAt=0;
}
-(void)navTouchDown:(UIButton *)button forEvent:(UIEvent *)event{
 [self cancelNavigationTouch:nil forEvent:nil];
 NSTimeInterval now=[NSProcessInfo processInfo].systemUptime;
 if(self.navGuardUntil > now + 2.0)self.navGuardUntil=now;
 if(now<self.navGuardUntil || self.welcome || self.tripSummaryCard || self.settingsSheet || self.featureExplanationBanner ||
    ![self isNavigationControlVisible:button] || !event || event.type!=UIEventTypeTouches)return;
 NSSet *viewTouches=[event touchesForView:button];
 UITouch *touch=[viewTouches anyObject]?:[event.allTouches anyObject];
 if(!touch)return;
 CGPoint point=[touch locationInView:button];
 if(touch.phase!=UITouchPhaseBegan || !CGRectContainsPoint(CGRectInset(button.bounds,-10,-10),point))return;
 self.navTrackingTouch=touch;
 self.navTouchDownTag=button.tag;
 self.navTouchDownPoint=point;
 self.navTouchDownAt=now;
}
-(BOOL)acceptNavigationTouch:(UIButton *)button forEvent:(UIEvent *)event{
 NSTimeInterval now=[NSProcessInfo processInfo].systemUptime;
 if(self.navGuardUntil > now + 2.0)self.navGuardUntil=now;
 UITouch *tracked=self.navTrackingTouch;
 NSInteger tag=self.navTouchDownTag;
 NSTimeInterval held=now-self.navTouchDownAt;
 CGPoint origin=self.navTouchDownPoint;
 [self cancelNavigationTouch:nil forEvent:nil];
 if(now<self.navGuardUntil || self.welcome || self.tripSummaryCard || self.settingsSheet || self.featureExplanationBanner){
  [self logNavigationReject:@"cooldown or overlay"];return NO;
 }
 if(![self isNavigationControlVisible:button]){
  [self logNavigationReject:@"invisible control"];return NO;
 }
 if(event && event.type==UIEventTypeTouches){
  NSSet *viewTouches=[event touchesForView:button];
  UITouch *touch=[viewTouches anyObject]?:[event.allTouches anyObject];
  if(!touch){
   [self logNavigationReject:@"missing touch"];return NO;
  }
  CGPoint point=[touch locationInView:button];
  if(tracked!=nil && (touch!=tracked || touch.phase!=UITouchPhaseEnded || tag!=button.tag || held>4.0 ||
     !CGRectContainsPoint(CGRectInset(button.bounds,-10,-10),point) || hypot(point.x-origin.x,point.y-origin.y)>36.0)){
   [self logNavigationReject:@"unmatched, dragged or edge touch"];return NO;
  }
  if(tracked==nil && !CGRectContainsPoint(CGRectInset(button.bounds,-10,-10),point)){
   [self logNavigationReject:@"outside bounds"];return NO;
  }
 }
 if(self.lastNavigationAcceptedAt>0 && now-self.lastNavigationAcceptedAt<0.12){
  [self logNavigationReject:@"repeat touch"];return NO;
 }
 self.lastNavigationAcceptedAt=now;
 [self logNavigation:[NSString stringWithFormat:@"touch accepted: %@",button.accessibilityLabel?:@"navigation"]];
 return YES;
}
-(void)requestMapURL:(BOOL)isCarPlay{
 NSUInteger generation=++self.mapURLRequestGeneration;
 [self logNavigation:isCarPlay?@"URL requested CarPlay":@"URL requested Maps"];
 [self retryMapURL:@{@"generation":@(generation),@"carplay":@(isCarPlay),@"attempt":@0}];
}
-(void)retryMapURL:(NSDictionary *)request{
 if([request[@"generation"]unsignedIntegerValue]!=self.mapURLRequestGeneration)return;
 NSTimeInterval now=[NSProcessInfo processInfo].systemUptime;
 if([UIApplication sharedApplication].applicationState==UIApplicationStateActive && now>=self.navGuardUntil &&
    !self.welcome && !self.tripSummaryCard && !self.settingsSheet && !self.featureExplanationBanner){
  if([request[@"carplay"]boolValue])[self openCarPlay];else[self openMap];
  return;
 }
 NSUInteger attempt=[request[@"attempt"]unsignedIntegerValue];
 if(attempt>=12){[self logNavigationReject:@"URL could not present navigation confirmation"];return;}
 NSDictionary *next=@{@"generation":request[@"generation"],@"carplay":request[@"carplay"],@"attempt":@(attempt+1)};
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self retryMapURL:next];});
}
-(BOOL)authorizeMapNavigation:(BOOL)isCarPlay{
 BOOL authorized=self.mapNavigationAuthorized;
 self.mapNavigationAuthorized=NO;
 NSTimeInterval now=[NSProcessInfo processInfo].systemUptime;
 if(now<self.navGuardUntil || [UIApplication sharedApplication].applicationState!=UIApplicationStateActive ||
    self.welcome || self.tripSummaryCard || self.settingsSheet || self.featureExplanationBanner){
  [self logNavigationReject:@"map request during cooldown, background or overlay"];return NO;
 }
 if(authorized)return YES;
 NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];
 BOOL guard=[ud objectForKey:@"TRDMapConfirmGuard"]?[ud boolForKey:@"TRDMapConfirmGuard"]:NO;
 if(guard){[self confirmOpenMapDestination:isCarPlay];return NO;}
 [self logNavigation:@"map confirmation disabled in settings"];
 return YES;
}
-(void)confirmOpenMapDestination:(BOOL)isCarPlay{
 if(self.settingsSheet || self.welcome || self.tripSummaryCard || self.featureExplanationBanner ||
    [NSProcessInfo processInfo].systemUptime<self.navGuardUntil)return;
 NSUInteger generation=++self.mapConfirmationGeneration;
 NSTimeInterval deadline=[NSProcessInfo processInfo].systemUptime+5.0;
 NSString *title=isCarPlay?@"Open CarPlay & Maps?":@"Open Maps?";
 TRDSettingsMenu *confirm=[self settingsMenu:title message:@"Hold CONFIRM for 0.5 seconds. This closes after 5 seconds."];
 confirm.requiresIntentionalTouch=YES;
 confirm.minimumActionHoldDuration=0.45;
 confirm.intentionalTouchArmedAt=[NSProcessInfo processInfo].systemUptime+0.15;
 __weak Dashboard *weak=self;
 [confirm addAction:[TRDSettingAction actionWithTitle:@"Hold to CONFIRM (0.5 s)" style:0 handler:^(TRDSettingAction *a){
  Dashboard *v=weak;
  if(!v)return;
  if(generation!=v.mapConfirmationGeneration || [NSProcessInfo processInfo].systemUptime>=deadline){
   [v logNavigationReject:@"expired or cancelled confirmation"];return;
  }
  v.mapConfirmationGeneration++;
  v.mapNavigationAuthorized=YES;
  [v logNavigation:@"map hold confirmed"];
  if(isCarPlay)[v openCarPlay];else[v openMap];
 }]];
 [confirm addAction:[TRDSettingAction actionWithTitle:@"Cancel - stay on Dashboard" style:0 handler:^(TRDSettingAction *a){
  Dashboard *v=weak;if(v){v.mapConfirmationGeneration++;[v logNavigation:@"map confirmation cancelled"];}
 }]];
 [self presentSettingsMenu:confirm];
 [self logNavigation:isCarPlay?@"CarPlay confirmation shown":@"Maps confirmation shown"];
 __weak TRDSettingsMenu *weakConfirm=confirm;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(5.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  Dashboard *v=weak;
  if(v && weakConfirm && v.settingsSheet==weakConfirm){
   v.mapConfirmationGeneration++;
   [v.settingsSheet dismiss];
   [v logNavigation:@"map confirmation expired"];
  }
 });
}
-(void)carplayHomeTouch:(UIButton *)button forEvent:(UIEvent *)event{
 if([self acceptNavigationTouch:button forEvent:event])[self toggleCarPlayGrid];
}
-(void)carplayDockTouch:(UIButton *)button forEvent:(UIEvent *)event{
 if(![self acceptNavigationTouch:button forEvent:event])return;
 switch(button.tag-9100){
  case 0:[self carplayTapMap];break;case 1:[self carplayTapMusic];break;
  case 2:[self openYouTubeSource];break;case 3:[self openCamera];break;case 4:[self openDriveEQ];break;
 }
}
-(void)carplayGridTouch:(UIButton *)button forEvent:(UIEvent *)event{
 if(![self acceptNavigationTouch:button forEvent:event])return;
 switch(button.tag-9200){
  case 0:[self carplayGridMusic];break;case 1:[self carplayGridMap];break;
  case 2:[self openYouTubeSource];break;case 3:[self openCamera];break;
  case 4:[self openDriveEQ];break;case 5:[self carplayGridTrip];break;
  case 6:[self carplayGridSettings];break;case 7:[self homePage];break;
 }
}
-(void)navigate:(UIButton *)button forEvent:(UIEvent *)event{
 if(![self acceptNavigationTouch:button forEvent:event])return;
 switch(button.tag){
  case 60:[self homePage];break;
  case 66:
   if(self.carplayMode) return;
   [self openCarPlay];break;
  case 61:if(self.musicMode){[self showMusicSources:button];}else{[self openMusic];}break;
  case 62:
   if(self.mapMode) return;
   [self openMap];break;
  case 63:[self openDriveEQ];break;
  case 64:[self screenOff];break;
  case 65:[self openCamera];break;
  case 67:[self openYouTubeSource];break;
  case 68:[self carSettings];break;
 }
}
-(void)homePage{[self cancelNavigationTouch:nil forEvent:nil];self.mapConfirmationGeneration++;self.mapURLRequestGeneration++;self.mapNavigationAuthorized=NO;self.navGuardUntil=[NSProcessInfo processInfo].systemUptime+0.12;[self hideFeatureExplanation];[self dismissLowFuelBanner];if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}notify_post("com.codex.trd.network.internet");[self.settingsSheet dismiss];[self ensureActiveRunLoopHealth];self.mapContainer.hidden=YES;self.tripMode=NO;self.mapMode=NO;self.carplayMode=NO;self.carplayGridMode=NO;if(self.driveMode){self.autoDriveSuppressed=YES;self.movingSince=nil;[self.driveCar stop];}self.manualDriveActive=NO;self.driveMode=NO;self.musicMode=NO;self.focused=NO;self.returnTap.enabled=NO;self.song.numberOfLines=1;self.heading.hidden=NO;self.owner.hidden=NO;self.modeButton.hidden=NO;self.driveButton.hidden=NO;self.nightButton.hidden=NO;self.statusStrip.hidden=NO;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];[self.view setNeedsLayout];}
-(void)openMusic{self.offlinePlaybackActive=NO;if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}notify_post("com.codex.trd.network.internet.force");[self showMusicSources:nil];}
-(void)executeOrQueueMapJS:(NSString *)js{
  if(!js.length) return;
  if(self.mapWebView && self.mapWebView.request && !self.mapWebView.loading){
    [self updateMapCarForce:YES];
    [self.mapWebView stringByEvaluatingJavaScriptFromString:js];
  }else{
    self.pendingMapJS = js;
  }
}
-(void)openMapToLat:(double)lat lon:(double)lon name:(NSString *)name address:(NSString *)address autoStart:(BOOL)autoStart{
  self.mapNavigationAuthorized = YES;
  self.navGuardUntil = 0;
  [self openMap];
  NSString *jsName = TRDJSStringLiteral(name ?: @"จุดหมาย");
  NSString *jsAddr = TRDJSStringLiteral(address ?: @"");
  NSString *js = [NSString stringWithFormat:@"if(window.selectLocation){window.selectLocation(%.6f,%.6f,%@,%@);if(%@&&window.startNavigation){window.startNavigation();}}",
                  lat, lon, jsName, jsAddr, autoStart ? @"true" : @"false"];
  [self executeOrQueueMapJS:js];
}
-(void)openMapWithSearchQuery:(NSString *)query{
  self.mapNavigationAuthorized = YES;
  self.navGuardUntil = 0;
  [self openMap];
  NSString *jsQ = TRDJSStringLiteral(query ?: @"ปั๊มน้ำมัน");
  NSString *js = [NSString stringWithFormat:@"if(window.quickSearch){window.quickSearch(%@);}", jsQ];
  [self executeOrQueueMapJS:js];
}
-(void)openMap{if(![self authorizeMapNavigation:NO])return;[self logNavigation:@"opened Maps"];self.navGuardUntil=[NSProcessInfo processInfo].systemUptime+0.18;if(self.welcome)[self hideWelcome];if(self.tripSummaryCard){[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}[self dismissLowFuelBanner];[self.settingsSheet dismiss];self.tripMode=NO;self.driveMode=NO;self.musicMode=NO;self.focused=NO;self.carplayMode=NO;self.carplayGridMode=NO;self.returnTap.enabled=NO;[self.driveCar stop];self.mapMode=YES;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];UIView *p=[self.view viewWithTag:701];if(p)p.hidden=YES;UIView *t=[self.view viewWithTag:711];if(t)t.hidden=YES;[self.view setNeedsLayout];[self.view layoutIfNeeded];[self ensureMapWebView];if(!self.mapWebView.request)[self loadMapHTML];else if(!self.mapWebView.loading)[self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.map){window.map.invalidateSize(false);}if(!window.navActive){var sc=document.getElementById('search-container');if(sc)sc.style.display='block';var lb=document.getElementById('layer-bar');if(lb){lb.style.display='-webkit-flex';lb.style.display='flex';}}"];[self updateMapCarForce:YES];}
-(void)syncMapAppearance:(BOOL)initial{if(!self.mapWebView || !self.mapWebView.request || self.mapWebView.loading)return;NSString *mode=self.nightMode?@"night":@"traffic";NSString *js=initial?[NSString stringWithFormat:@"if(window.setMode && !window.__trdInitialThemeDone){window.__trdInitialThemeDone=true;window.setMode('%@');}",mode]:[NSString stringWithFormat:@"if(window.setMode){window.setMode('%@');}",mode];[self.mapWebView stringByEvaluatingJavaScriptFromString:js];}
-(void)webViewDidFinishLoad:(UIWebView *)webView{if(webView==self.mapWebView){NSString *state=[self.mapWebView stringByEvaluatingJavaScriptFromString:@"document.readyState+'|'+typeof L+'|'+(window.map?'map':'nomap')"];[[TRDOBDClient sharedClient] obdLog:@"map webViewDidFinishLoad (%@)",state?:@""];[self syncMapAppearance:YES];[self updateMapCarForce:YES];if(self.pendingMapJS.length){NSString *pending=self.pendingMapJS;self.pendingMapJS=nil;[self.mapWebView stringByEvaluatingJavaScriptFromString:pending];}}}
-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{if(webView==self.mapWebView){[[TRDOBDClient sharedClient] obdLog:@"map webView didFailLoadWithError: %@",error.localizedDescription?:error.description];}}
-(void)loadMapHTML{[self ensureMapWebView];NSString *path=@"/Applications/CarDash.app/map.html";if([[NSFileManager defaultManager]fileExistsAtPath:path])[self.mapWebView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]]];}
-(void)updateMapCar{[self updateMapCarForce:NO];}
-(void)updateMapCarForce:(BOOL)force{if((!self.mapMode&&!self.carplayMode)||!self.mapWebView||!self.mapWebView.request||self.mapWebView.loading)return;if(!self.fix)return;static CLLocationDegrees lastLat=0,lastLng=0;static double lastKmh=-999;static UIWebView *lastWebView=nil;CLLocationDegrees lat=self.fix.coordinate.latitude;CLLocationDegrees lng=self.fix.coordinate.longitude;double kmh=(self.fix.speed>=0)?(self.fix.speed*3.6):-1;if(!force&&lastWebView==self.mapWebView&&fabs(lat-lastLat)<0.000015&&fabs(lng-lastLng)<0.000015&&fabs(kmh-lastKmh)<2.0)return;lastWebView=self.mapWebView;lastLat=lat;lastLng=lng;lastKmh=kmh;BOOL courseValid=self.fix.course>=0&&self.fix.course<360&&kmh>=5&&self.fix.horizontalAccuracy>=0&&self.fix.horizontalAccuracy<=25&&fabs([self.fix.timestamp timeIntervalSinceNow])<5;double course=courseValid?self.fix.course:-1;NSString *js=[NSString stringWithFormat:@"if(window.updateCar){window.updateCar(%f,%f,%f,%f);}",lat,lng,course,kmh];[self.mapWebView stringByEvaluatingJavaScriptFromString:js];}
-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)type{NSString *scheme=request.URL.scheme;if([scheme isEqualToString:@"cardash-route"]){NSString *coords=[[request.URL.resourceSpecifier stringByReplacingOccurrencesOfString:@"//" withString:@""]stringByRemovingPercentEncoding];[self fetchRouteWithCoords:coords];return NO;}if([scheme isEqualToString:@"cardash-search"]){NSString *query=[[request.URL.resourceSpecifier stringByReplacingOccurrencesOfString:@"//" withString:@""]stringByRemovingPercentEncoding];[self fetchSearchWithQuery:query];return NO;}if([scheme isEqualToString:@"cardash-navspeak"]){NSString *phrase=[[request.URL.resourceSpecifier stringByReplacingOccurrencesOfString:@"//" withString:@""]stringByRemovingPercentEncoding];if(phrase.length)[self speakQuickAlert:phrase];return NO;}return YES;}
-(void)dispatchFallbackRouteFrom:(CLLocationCoordinate2D)src to:(CLLocationCoordinate2D)dst{
  MKPlacemark *p1 = [[MKPlacemark alloc] initWithCoordinate:src addressDictionary:nil];
  MKPlacemark *p2 = [[MKPlacemark alloc] initWithCoordinate:dst addressDictionary:nil];
  MKDirectionsRequest *req = [[MKDirectionsRequest alloc] init];
  req.source = [[MKMapItem alloc] initWithPlacemark:p1];
  req.destination = [[MKMapItem alloc] initWithPlacemark:p2];
  req.transportType = MKDirectionsTransportTypeAutomobile;
  MKDirections *dirs = [[MKDirections alloc] initWithRequest:req];
  __weak Dashboard *weak = self;
  [dirs calculateDirectionsWithCompletionHandler:^(MKDirectionsResponse *resp, NSError *err){
    NSDictionary *routePayload = nil;
    MKRoute *mkRoute = resp.routes.firstObject;
    if(mkRoute && mkRoute.polyline.pointCount > 0){
      NSUInteger cnt = mkRoute.polyline.pointCount;
      CLLocationCoordinate2D *pts = (CLLocationCoordinate2D *)malloc(sizeof(CLLocationCoordinate2D) * cnt);
      if(pts){
        [mkRoute.polyline getCoordinates:pts range:NSMakeRange(0, cnt)];
        NSMutableArray *coordArr = [NSMutableArray arrayWithCapacity:cnt];
        for(NSUInteger i=0; i<cnt; i++){
          [coordArr addObject:@[@(pts[i].longitude), @(pts[i].latitude)]];
        }
        free(pts);
        NSMutableArray *stepsArr = [NSMutableArray array];
        for(MKRouteStep *st in mkRoute.steps){
          CLLocationCoordinate2D sc = (st.polyline.pointCount > 0) ? st.polyline.coordinate : src;
          [stepsArr addObject:@{
            @"distance": @(st.distance),
            @"name": st.instructions ?: @"",
            @"maneuver": @{@"type": @"turn", @"modifier": @"", @"location": @[@(sc.longitude), @(sc.latitude)]}
          }];
        }
        if(stepsArr.count == 0){
          [stepsArr addObject:@{@"distance":@(mkRoute.distance), @"name":@"มุ่งหน้าสู่จุดหมาย", @"maneuver":@{@"type":@"depart",@"modifier":@"",@"location":@[@(src.longitude),@(src.latitude)]}}];
        }
        [stepsArr addObject:@{@"distance":@(0), @"name":@"ถึงจุดหมายปลายทาง", @"maneuver":@{@"type":@"arrive",@"modifier":@"",@"location":@[@(dst.longitude),@(dst.latitude)]}}];
        routePayload = @{@"routes":@[@{
          @"distance": @(mkRoute.distance),
          @"duration": @(mkRoute.expectedTravelTime),
          @"geometry": @{@"coordinates": coordArr},
          @"legs": @[@{@"steps": stepsArr}]
        }]};
        [[TRDOBDClient sharedClient] obdLog:@"MKDirections fallback OK: %.0f m (%lu pts)", mkRoute.distance, (unsigned long)cnt];
      }
    }
    if(!routePayload){
      CLLocation *l1 = [[CLLocation alloc] initWithLatitude:src.latitude longitude:src.longitude];
      CLLocation *l2 = [[CLLocation alloc] initWithLatitude:dst.latitude longitude:dst.longitude];
      double dist = [l1 distanceFromLocation:l2];
      double dur = MAX(60.0, dist / (35000.0 / 3600.0));
      [[TRDOBDClient sharedClient] obdLog:@"MKDirections failed (%@) -> straight fallback %.0f m", err.localizedDescription?:@"offline", dist];
      routePayload = @{@"routes":@[@{
        @"distance": @(dist),
        @"duration": @(dur),
        @"geometry": @{@"coordinates": @[@[@(src.longitude), @(src.latitude)], @[@(dst.longitude), @(dst.latitude)]]},
        @"legs": @[@{@"steps": @[
          @{@"distance":@(dist), @"name":@"มุ่งหน้าไปยังจุดหมาย", @"maneuver":@{@"type":@"depart",@"modifier":@"",@"location":@[@(src.longitude),@(src.latitude)]}},
          @{@"distance":@(0), @"name":@"ถึงจุดหมายปลายทาง", @"maneuver":@{@"type":@"arrive",@"modifier":@"",@"location":@[@(dst.longitude),@(dst.latitude)]}}
        ]}]
      }]};
    }
    NSData *d = [NSJSONSerialization dataWithJSONObject:routePayload options:0 error:nil];
    NSString *json = d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : @"{\"routes\":[]}";
    dispatch_async(dispatch_get_main_queue(), ^{
      [weak.mapWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(window.onNativeRoute){window.onNativeRoute(%@);}", json]];
    });
  }];
}
-(void)fetchRouteWithCoords:(NSString *)coords{
  NSArray *pairs = [coords componentsSeparatedByString:@";"];
  CLLocationCoordinate2D src = CLLocationCoordinate2DMake(13.7563, 100.5018);
  CLLocationCoordinate2D dst = src;
  BOOL hasCoords = NO;
  if(pairs.count >= 2){
    NSArray *p1 = [pairs[0] componentsSeparatedByString:@","];
    NSArray *p2 = [pairs[1] componentsSeparatedByString:@","];
    if(p1.count == 2 && p2.count == 2){
      src = CLLocationCoordinate2DMake([p1[1] doubleValue], [p1[0] doubleValue]);
      dst = CLLocationCoordinate2DMake([p2[1] doubleValue], [p2[0] doubleValue]);
      hasCoords = (fabs(src.latitude) > 0.001 && fabs(dst.latitude) > 0.001);
    }
  }
  NSString *urlStr=[NSString stringWithFormat:@"http://router.project-osrm.org/route/v1/driving/%@?overview=full&geometries=geojson&steps=true",coords];
  NSURL *url=[NSURL URLWithString:urlStr];
  if(!url){
    if(hasCoords) [self dispatchFallbackRouteFrom:src to:dst];
    else dispatch_async(dispatch_get_main_queue(),^{ [self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.onNativeRoute){window.onNativeRoute({routes:[]});}"]; });
    return;
  }
  NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:4.0];
  [req setValue:@"CarDash/1.6 (iPad; iOS 9.3.6)" forHTTPHeaderField:@"User-Agent"];
  __weak Dashboard *weak=self;
  [[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData *data,NSURLResponse *resp,NSError *err){
    NSString *json=(data&&!err)?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;
    if(json.length && [json rangeOfString:@"\"routes\""].location!=NSNotFound){
      [[TRDOBDClient sharedClient] obdLog:@"OSRM route OK (%lu bytes)", (unsigned long)data.length];
      dispatch_async(dispatch_get_main_queue(),^{
        [weak.mapWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(window.onNativeRoute){window.onNativeRoute(%@);}",json]];
      });
    }else{
      [[TRDOBDClient sharedClient] obdLog:@"OSRM route unavailable (%@), switching to MKDirections", err.localizedDescription?:@"empty"];
      dispatch_async(dispatch_get_main_queue(),^{
        if(hasCoords) [weak dispatchFallbackRouteFrom:src to:dst];
        else [weak.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.onNativeRoute){window.onNativeRoute({routes:[]});}"];
      });
    }
  }]resume];
}
-(void)fetchSearchWithQuery:(NSString *)query{
  if(!query.length)return;
  CLLocationDegrees lat=self.fix?self.fix.coordinate.latitude:13.7563;
  CLLocationDegrees lng=self.fix?self.fix.coordinate.longitude:100.5018;
  CLLocation *curLoc = self.fix ?: [[CLLocation alloc] initWithLatitude:lat longitude:lng];
  MKLocalSearchRequest *mkReq = [[MKLocalSearchRequest alloc] init];
  mkReq.naturalLanguageQuery = query;
  mkReq.region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2DMake(lat, lng), 120000, 120000);
  MKLocalSearch *mkSearch = [[MKLocalSearch alloc] initWithRequest:mkReq];
  __weak Dashboard *weak = self;
  [mkSearch startWithCompletionHandler:^(MKLocalSearchResponse *resp, NSError *mkErr){
    if(resp.mapItems.count > 0){
      NSArray *sorted = [resp.mapItems sortedArrayUsingComparator:^NSComparisonResult(MKMapItem *a, MKMapItem *b){
        double da = a.placemark.location ? [curLoc distanceFromLocation:a.placemark.location] : 1e12;
        double db = b.placemark.location ? [curLoc distanceFromLocation:b.placemark.location] : 1e12;
        if(da < db) return NSOrderedAscending;
        if(da > db) return NSOrderedDescending;
        return NSOrderedSame;
      }];
      NSMutableArray *items = [NSMutableArray array];
      NSUInteger limit = MIN((NSUInteger)6, sorted.count);
      for(NSUInteger i=0; i<limit; i++){
        MKMapItem *it = sorted[i];
        double dKm = it.placemark.location ? ([curLoc distanceFromLocation:it.placemark.location] / 1000.0) : 0.0;
        NSString *name = it.name ?: query;
        NSString *addr = it.placemark.title ?: @"";
        NSString *disp = [NSString stringWithFormat:@"%@ (%.1f กม.), %@", name, dKm, addr];
        [items addObject:@{
          @"display_name": disp,
          @"lat": [NSString stringWithFormat:@"%.6f", it.placemark.coordinate.latitude],
          @"lon": [NSString stringWithFormat:@"%.6f", it.placemark.coordinate.longitude]
        }];
      }
      NSData *jsonData = [NSJSONSerialization dataWithJSONObject:items options:0 error:nil];
      if(jsonData){
        NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
          [weak.mapWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(window._onNominatimResult){window._onNominatimResult(%@);}", jsonStr]];
        });
        return;
      }
    }
    // Fallback to Nominatim if Apple MKLocalSearch finds nothing
    NSString *encoded=[query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *viewbox=[NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f",lng-.4,lat+.4,lng+.4,lat-.4];
    NSString *urlStr=[NSString stringWithFormat:@"https://nominatim.openstreetmap.org/search?q=%@&format=json&countrycodes=th&limit=5&viewbox=%@",encoded,viewbox];
    NSURL *url=[NSURL URLWithString:urlStr];
    if(!url){
      dispatch_async(dispatch_get_main_queue(), ^{
        [weak.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window._onNominatimResult){window._onNominatimResult([]);}"];
      });
      return;
    }
    NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:6.0];
    [req setValue:@"CarDash/1.6 (iPad; iOS 9.3.6; Prius)" forHTTPHeaderField:@"User-Agent"];
    [[[NSURLSession sharedSession]dataTaskWithRequest:req completionHandler:^(NSData *data,NSURLResponse *resp,NSError *err){
      NSString *json=(data&&!err)?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:@"[]";
      if(!json.length) json=@"[]";
      dispatch_async(dispatch_get_main_queue(),^{
        [weak.mapWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"if(window._onNominatimResult){window._onNominatimResult(%@);}",json]];
      });
    }]resume];
  }];
}
-(void)openActiveSourceApp{NSDictionary *src=[NSDictionary dictionaryWithContentsOfFile:TRDSourcePath];NSString *bundle=src[@"bundle"]?:(self.youtubeSource?@"com.himais0giiiin.ytnine":@"com.legacymusic.app");if([bundle isEqualToString:@"com.legacymusic.app"])[self browseSource:bundle];else [self send:bundle];}
-(void)showMusicSources:(UIButton *)button{
 TRDSettingsMenu *menu=[self settingsMenu:@"AUDIO & MUSIC SOURCES" message:@"Select music, search songs, or online radio"];
 [menu addAction:[TRDSettingAction actionWithTitle:@"🔍 Search Music (ค้นหาเพลง audioNINJA)" style:0 handler:^(TRDSettingAction *a){[self openSearchMusic];}]];
 [menu addAction:[TRDSettingAction actionWithTitle:@"📻 Live Radio & Music (วิทยุออนไลน์)" style:0 handler:^(TRDSettingAction *a){[self openRadioStationsMenu];}]];
 [menu addAction:[TRDSettingAction actionWithTitle:@"💾 Offline Music (เพลงที่โหลดไว้)" style:0 handler:^(TRDSettingAction *a){[self openOfflineMusicMenu];}]];
 [menu addAction:[TRDSettingAction actionWithTitle:@"🎵 audioNINJA Player" style:0 handler:^(TRDSettingAction *a){[self browseSource:@"com.legacymusic.app"];}]];
 [menu addAction:[TRDSettingAction actionWithTitle:@"▶️ YouTube" style:0 handler:^(TRDSettingAction *a){[self openYouTubeSource];}]];
 [self presentSettingsMenu:menu];
}
-(void)openSearchMusic{[self browseSource:@"com.legacymusic.app" target:@"search"];}
-(NSString *)resolveOfflineAudioPathForVideoId:(NSString *)vId{
 if(!vId.length)return nil;
 NSFileManager *fm=[NSFileManager defaultManager];
 NSArray *exts=@[@"mp4",@"m4a",@"mp3",@"aac"];
 for(NSString *ext in exts){
  NSString *p=[NSString stringWithFormat:@"/var/mobile/Documents/LegacyMusic/audio/%@.%@",vId,ext];
  if([fm fileExistsAtPath:p])return p;
 }
 return nil;
}
-(void)offlineTrackDidFinish:(NSNotification *)note{
 if(!self.offlinePlaybackActive||!self.radioPlayer)return;
 if(note.object!=self.radioPlayer.currentItem)return;
 dispatch_async(dispatch_get_main_queue(),^{
  [self nextOfflineTrack];
 });
}
-(void)nextOfflineTrack{
 if(!self.offlineTracks.count)return;
 NSInteger n=(NSInteger)self.offlineTracks.count;
 for(NSInteger step=1;step<=n;step++){
  NSInteger cand=(self.offlineTrackIndex+step)%n;
  NSDictionary *t=self.offlineTracks[cand];
  if([self resolveOfflineAudioPathForVideoId:t[@"videoId"]]){
   [self playOfflineTrackAtIndex:cand];
   return;
  }
 }
}
-(void)prevOfflineTrack{
 if(!self.offlineTracks.count)return;
 NSInteger n=(NSInteger)self.offlineTracks.count;
 for(NSInteger step=1;step<=n;step++){
  NSInteger cand=(self.offlineTrackIndex-step+n)%n;
  NSDictionary *t=self.offlineTracks[cand];
  if([self resolveOfflineAudioPathForVideoId:t[@"videoId"]]){
   [self playOfflineTrackAtIndex:cand];
   return;
  }
 }
}
static NSString *TRDArtworkCachePathForURL(NSString *urlString){
 if(!urlString.length)return nil;
 const char *cStr=[urlString UTF8String];
 if(!cStr)return nil;
 unsigned char digest[CC_MD5_DIGEST_LENGTH];
 CC_MD5(cStr,(CC_LONG)strlen(cStr),digest);
 NSMutableString *hex=[NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
 for(int i=0;i<CC_MD5_DIGEST_LENGTH;i++)[hex appendFormat:@"%02x",digest[i]];
 return [NSString stringWithFormat:@"/var/mobile/Documents/LegacyMusic/art/%@.jpg",hex];
}
static UIImage *TRDDecodeArtworkData(NSData *data){
 if(!data.length)return nil;
 UIImage *image=nil;
 CGImageSourceRef source=CGImageSourceCreateWithData((__bridge CFDataRef)data,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache:@NO});
 if(source){
  NSDictionary *options=@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@256,(__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES};
  CGImageRef thumb=CGImageSourceCreateThumbnailAtIndex(source,0,(__bridge CFDictionaryRef)options);
  if(thumb){image=[UIImage imageWithCGImage:thumb];CGImageRelease(thumb);}
  CFRelease(source);
 }
 return image ?: [UIImage imageWithData:data];
}
-(void)applyOfflineArtworkData:(NSData *)data title:(NSString *)title artist:(NSString *)artist{
 [self setCarDashRemoteControlEnabled:YES];
 UIImage *img=TRDDecodeArtworkData(data);
 if(!img)return;
 self.artworkData=nil;
 self.artworkLen=data.length;
 self.artworkSig=data.length ^ 0xA5A5;
 self.artwork.image=img;
 self.artworkDecodes++;
 self.artPlaceholder.hidden=YES;
 if(self.carplayMediaWidget){
  self.carplayMediaWidget.artworkView.image=img;
  self.carplayMediaWidget.artPlaceholder.hidden=YES;
 }
 NSMutableDictionary *np=[NSMutableDictionary dictionaryWithDictionary:[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo?:@{}];
 np[MPMediaItemPropertyTitle]=title?:(self.currentRadioStation?:@"Offline Music");
 np[MPMediaItemPropertyArtist]=artist?:(self.currentOfflineArtist?:@"Offline Music");
 np[MPNowPlayingInfoPropertyPlaybackRate]=@(1.0);
 MPMediaItemArtwork *mpArt=[[MPMediaItemArtwork alloc]initWithImage:img];
 if(mpArt)np[MPMediaItemPropertyArtwork]=mpArt;
 [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo=np;
}
-(void)loadOfflineArtworkForTrack:(NSDictionary *)track audioPath:(NSString *)audioPath expectedIndex:(NSInteger)expectedIdx generation:(NSUInteger)expectedGen{
 self.artwork.image=nil;
 self.artworkData=nil;
 self.artPlaceholder.hidden=self.focused;
 if(self.carplayMediaWidget){
  self.carplayMediaWidget.artworkView.image=nil;
  self.carplayMediaWidget.artPlaceholder.hidden=NO;
 }
 NSString *title=track[@"title"]?:@"Untitled";
 NSString *artist=track[@"artist"]?:@"Offline Music";
 NSString *thumbURL=[track[@"thumbnail"]isKindOfClass:[NSString class]]?track[@"thumbnail"]:nil;
 NSString *cachePath=TRDArtworkCachePathForURL(thumbURL);
 if(cachePath.length && [[NSFileManager defaultManager]fileExistsAtPath:cachePath]){
  NSData *data=[NSData dataWithContentsOfFile:cachePath];
  if(data.length){
   [self applyOfflineArtworkData:data title:title artist:artist];
   return;
  }
 }
 // Fallback 1: check embedded MP4/M4A metadata artwork
 if(audioPath.length){
  AVURLAsset *asset=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:audioPath] options:nil];
  for(AVMetadataItem *meta in [asset commonMetadata]){
   if([meta.commonKey isEqualToString:AVMetadataCommonKeyArtwork] && [meta.value isKindOfClass:[NSData class]]){
    NSData *emb=(NSData *)meta.value;
    if(emb.length){
     [self applyOfflineArtworkData:emb title:title artist:artist];
     return;
    }
   }
  }
 }
 // Fallback 2: fetch thumbnail once if online and cache to LegacyMusic art dir for offline reuse
 if(thumbURL.length){
  NSURL *u=[NSURL URLWithString:thumbURL];
  if(u){
   __weak Dashboard *weak=self;
   [[[NSURLSession sharedSession]dataTaskWithURL:u completionHandler:^(NSData *data,NSURLResponse *resp,NSError *err){
    if(data.length && !err){
     if(cachePath.length){
      [[NSFileManager defaultManager]createDirectoryAtPath:[cachePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
      [data writeToFile:cachePath atomically:YES];
     }
     dispatch_async(dispatch_get_main_queue(),^{
      Dashboard *v=weak;
      if(!v||!v.offlinePlaybackActive||v.radioGeneration!=expectedGen||v.offlineTrackIndex!=expectedIdx)return;
      [v applyOfflineArtworkData:data title:title artist:artist];
     });
    }
   }]resume];
  }
 }
}
-(void)playOfflineTrackAtIndex:(NSInteger)index{
 if(!self.offlineTracks.count||index<0||index>=(NSInteger)self.offlineTracks.count)return;
 NSDictionary *track=self.offlineTracks[index];
 NSString *title=track[@"title"]?:@"Untitled";
 NSString *artist=track[@"artist"]?:@"Offline Music";
 NSString *vId=track[@"videoId"]?:@"";
 NSString *audioPath=[self resolveOfflineAudioPathForVideoId:vId];
 if(!audioPath){
  // Only fall back to audioNINJA search if the audio file was never downloaded locally
  [self browseSource:@"com.legacymusic.app" target:@"search"];
  return;
 }

 NSUInteger gen=++self.radioGeneration;
 [[NSNotificationCenter defaultCenter]removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
 if(self.radioPlayer){
  [self.radioPlayer pause];
  [self.radioPlayer replaceCurrentItemWithPlayerItem:nil];
  self.radioPlayer=nil;
 }
 notify_post("com.codex.trd.youtube.pause");
 TRDSendMediaRemoteExternal(1,^{ [self send:@"libactivator.ipod.pause-playback"]; });

 AVAudioSession *session=[AVAudioSession sharedInstance];
 [session setCategory:AVAudioSessionCategoryPlayback error:nil];
 [session setActive:YES error:nil];

 self.offlinePlaybackActive=YES;
 self.offlineTrackIndex=index;
 self.currentRadioStation=title;
 self.currentOfflineArtist=artist.length?artist:@"Offline Music";

 AVPlayerItem *item=[AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:audioPath]];
 [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(offlineTrackDidFinish:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
 AVPlayer *player=[AVPlayer playerWithPlayerItem:item];
 self.radioPlayer=player;
 [self.radioPlayer play];

 // Clear any stale pending download-play-request so audioNINJA never hijacks on next open
 [[NSFileManager defaultManager]removeItemAtPath:@"/var/mobile/codex-car/download-play-request.plist" error:nil];

 self.song.text=title;
 self.artist.text=self.currentOfflineArtist;
 self.sourceBadge.text=@"OFFLINE";
 [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo=@{
  MPMediaItemPropertyTitle:title,
  MPMediaItemPropertyArtist:self.currentOfflineArtist,
  MPNowPlayingInfoPropertyPlaybackRate:@(1.0)
 };
 [self loadOfflineArtworkForTrack:track audioPath:audioPath expectedIndex:index generation:gen];
 [self refreshTransportState];
 [self refreshTrackProgress];
 [self refreshMini];
}
-(void)openOfflineMusicMenu{
 NSString *libPath=@"/var/mobile/Documents/LegacyMusic/library.plist";
 NSArray *rawTracks=[NSArray arrayWithContentsOfFile:libPath];
 NSMutableArray *playable=[NSMutableArray array];
 for(NSDictionary *t in rawTracks){
  if([t isKindOfClass:[NSDictionary class]]&&[self resolveOfflineAudioPathForVideoId:t[@"videoId"]]){
   [playable addObject:t];
  }
 }
 if(playable.count==0){
  TRDSettingsMenu *menu=[self settingsMenu:@"💾 OFFLINE MUSIC (0 เพลง)" message:@"No downloaded songs found in audioNINJA.\nUse audioNINJA to download songs."];
  [menu addAction:[TRDSettingAction actionWithTitle:@"🎵 Open audioNINJA" style:0 handler:^(TRDSettingAction *a){[self browseSource:@"com.legacymusic.app"];}]];
  [self presentSettingsMenu:menu];
  return;
 }
 self.offlineTracks=[playable copy];
 NSString *msg=[NSString stringWithFormat:@"แตะเลือกเพลงเพื่อเล่นใน CarDash ทันที (%lu เพลงออฟไลน์)",(unsigned long)self.offlineTracks.count];
 TRDSettingsMenu *menu=[self settingsMenu:@"💾 OFFLINE MUSIC" message:msg];
 NSInteger idx=0;
 for(NSDictionary *track in self.offlineTracks){
  NSString *title=track[@"title"]?:@"Untitled";
  NSString *artist=track[@"artist"]?:@"";
  BOOL cur=(self.offlinePlaybackActive&&self.radioPlayer&&idx==self.offlineTrackIndex);
  NSString *prefix=cur?@"🔊 ":@"▶️ ";
  NSString *btnTitle=artist.length?[NSString stringWithFormat:@"%@%@ — %@",prefix,title,artist]:[NSString stringWithFormat:@"%@%@",prefix,title];
  NSInteger chosen=idx;
  [menu addAction:[TRDSettingAction actionWithTitle:btnTitle style:0 handler:^(TRDSettingAction *a){
   [self playOfflineTrackAtIndex:chosen];
  }]];
  idx++;
 }
 if(self.offlinePlaybackActive&&self.radioPlayer){
  [menu addAction:[TRDSettingAction actionWithTitle:@"⏹️ หยุดเล่นเพลงออฟไลน์" style:0 handler:^(TRDSettingAction *a){
   self.offlinePlaybackActive=NO;
   [self playRadio:nil name:nil];
  }]];
 }
 [menu addAction:[TRDSettingAction actionWithTitle:@"🔍 Search / Download More in audioNINJA..." style:0 handler:^(TRDSettingAction *a){[self openSearchMusic];}]];
 [self presentSettingsMenu:menu];
}
// QUICK VIEWS uses this legacy selector only for its explicit Full Clock action.
-(void)card:(UIButton *)button{
 if(button.tag!=6){[self logNavigationReject:@"legacy card action without touch"];return;}
 [self enterFullClock];
}
-(void)enterFullClock{
 self.mapContainer.hidden=YES;self.carplayMode=NO;self.carplayGridMode=NO;self.tripMode=NO;self.mapMode=NO;self.driveMode=NO;self.musicMode=NO;[self.driveCar stop];[self.driveButton setTitle:@"DRIVE MODE" forState:0];self.focused=YES;self.returnTap.enabled=YES;[self.view setNeedsLayout];
}
-(void)card:(UIButton *)button forEvent:(UIEvent *)event{
 if(![self acceptNavigationTouch:button forEvent:event])return;
 self.offlinePlaybackActive=NO;
 if(self.radioPlayer){[self.radioPlayer pause];[self.radioPlayer replaceCurrentItemWithPlayerItem:nil];self.radioPlayer=nil;}
 TRDSendMediaRemoteExternal(1,^{ [self send:@"libactivator.ipod.pause-playback"]; });
 if(button.tag==1){[self openYouTubeSource];return;}
 if(button.tag==2){[self browseSource:@"com.legacymusic.app"];return;}
 if(button.tag==3){[self openMap];return;}
 if(button.tag==4){[self openCamera];return;}
 if(button.tag==5){[self carSettings];return;}
 if(button.tag==6){[self enterFullClock];return;}
 NSArray *ids=@[@"com.himais0giiiin.ytnine",@"com.legacymusic.app",@"com.apple.Maps",@"com.codex.h109viewer",@"com.apple.Preferences"];
 if(button.tag>=1&&button.tag<=5)[self send:ids[button.tag-1]];
}
-(BOOL)isYouTubeMediaActive{
 if(self.youtubeSource)return YES;
 NSDictionary *source=[NSDictionary dictionaryWithContentsOfFile:TRDSourcePath];
 if([source[@"bundle"]isEqualToString:@"com.himais0giiiin.ytnine"])return YES;
 NSDictionary *lastMedia=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/last-media.plist"];
 NSString *lb=lastMedia[@"bundle"];
 return [lb isEqualToString:@"com.himais0giiiin.ytnine"]&&![source[@"bundle"]isEqualToString:@"com.legacymusic.app"]&&![source[@"bundle"]isEqualToString:@"com.codex.poddash"];
}
-(void)media:(UIButton *)button{if(self.radioPlayer){if(button.tag==21){if(self.radioPlayer.rate>0){[self.radioPlayer pause];self.song.text=[NSString stringWithFormat:@"[PAUSED] %@",self.currentRadioStation?:(self.offlinePlaybackActive?@"Offline":@"Radio")];self.artist.text=@"Tap Play button to resume";}else{notify_post("com.codex.trd.youtube.pause");TRDSendMediaRemoteExternal(1,^{ [self send:@"libactivator.ipod.pause-playback"]; });[self.radioPlayer play];self.song.text=self.currentRadioStation?:(self.offlinePlaybackActive?@"Offline":@"Radio");self.artist.text=self.offlinePlaybackActive?(self.currentOfflineArtist?:@"OFFLINE MUSIC"):@"Live Radio Broadcast · Playing Live";}[self refreshTransportState];[self refreshMini];return;}else if(button.tag==20||button.tag==22){if(self.offlinePlaybackActive){if(button.tag==22)[self nextOfflineTrack];else [self prevOfflineTrack];return;}[self openRadioStationsMenu];return;}}NSArray *ids=@[@"libactivator.ipod.previous-track",@"libactivator.ipod.toggle-playback",@"libactivator.ipod.next-track",@"com.r333d.eqe.app"];if(button.tag>=20&&button.tag<=23){BOOL youtube=[self isYouTubeMediaActive];if(button.tag==22){if(youtube)notify_post("com.codex.trd.youtube.next");else TRDSendMediaRemoteExternal(4,^{ [self send:ids[2]]; });}else if(button.tag==20){if(youtube)notify_post("com.codex.trd.youtube.previous");else TRDSendMediaRemoteExternal(5,^{ [self send:ids[0]]; });}else if(button.tag==21){if(youtube)notify_post("com.codex.trd.youtube.toggle");else TRDSendMediaRemoteExternal(2,^{ [self send:ids[1]]; });}else{[self send:ids[button.tag-20]];}[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshNowPlaying) object:nil];[self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:.15];[self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:.5];[self performSelector:@selector(refreshNowPlaying) withObject:nil afterDelay:1.2];}}
-(void)leaveClock{self.focused=NO;self.mapMode=NO;self.returnTap.enabled=NO;[self.view setNeedsLayout];}
-(void)testSettingsAction:(NSNumber *)index{NSInteger i=index.integerValue;if(i>=0&&i<self.settingsSheet.buttons.count)[(UIButton *)self.settingsSheet.buttons[i] sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)testNav:(NSNumber *)index{NSInteger i=index.integerValue;if(i>=0&&i<self.navButtons.count)[(UIButton *)self.navButtons[i] sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)testBrowse{[self.browseMusic sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)dismissSourceMenu{[self.settingsSheet dismiss];[self dismissViewControllerAnimated:NO completion:nil];}
-(void)testMedia:(NSNumber *)index{NSInteger i=index.integerValue;if(i>=0&&i<3)[(UIButton *)[self.controls viewWithTag:20+i] sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)capture{UIView *surface=self.view;UIGraphicsBeginImageContextWithOptions(surface.bounds.size,YES,1);[surface drawViewHierarchyInRect:surface.bounds afterScreenUpdates:YES];NSData *png=UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());UIGraphicsEndImageContext();[png writeToFile:@"/var/mobile/h109-build/cardash.png" atomically:YES];UIView *hitCenter=[surface hitTest:CGPointMake(CGRectGetMidX(surface.bounds),CGRectGetMidY(surface.bounds)) withEvent:nil];UIView *dockLast=self.navButtons.lastObject;UIView *hitDock=dockLast?[surface hitTest:[surface convertPoint:CGPointMake(CGRectGetMidX(dockLast.bounds),CGRectGetMidY(dockLast.bounds)) fromView:dockLast] withEvent:nil]:nil;UIView *playBtn=[self.controls viewWithTag:21];UIView *hitPlay=playBtn?[surface hitTest:[surface convertPoint:CGPointMake(CGRectGetMidX(playBtn.bounds),CGRectGetMidY(playBtn.bounds)) fromView:playBtn] withEvent:nil]:nil;NSTimeInterval uptime=[NSProcessInfo processInfo].systemUptime;NSDictionary *report=@{@"appState":@([UIApplication sharedApplication].applicationState),@"viewInteraction":@(surface.userInteractionEnabled),@"windowInteraction":@(surface.window.userInteractionEnabled),@"ignoringEvents":@([UIApplication sharedApplication].isIgnoringInteractionEvents),@"featureBannerVisible":@(self.featureExplanationBanner!=nil),@"tripSummaryVisible":@(self.tripSummaryCard!=nil),@"lowFuelVisible":@(self.lowFuelBanner!=nil),@"navGuardRemaining":@(MAX(0.0,self.navGuardUntil-uptime)),@"ticks":@(gTRDUpdateTicks),@"lastTouchInfo":gTRDLastTouchInfo?:@"none",@"hitCenter":NSStringFromClass([hitCenter class])?:@"nil",@"hitDockSettings":NSStringFromClass([hitDock class])?:@"nil",@"hitPlay":NSStringFromClass([hitPlay class])?:@"nil",@"driveTripText":self.driveTripButton.currentTitle?:@"",@"driveTripVisible":@(!self.driveTripButton.hidden),@"driveTripFrame":NSStringFromCGRect(self.driveTripButton.frame),@"driveCameraVisible":@(!self.driveCameraButton.hidden),@"driveCameraFrame":NSStringFromCGRect(self.driveCameraButton.frame),@"driveCameraActions":[self.driveCameraButton actionsForTarget:self forControlEvent:UIControlEventTouchUpInside]?:@[],@"audioOutput":self.audioOutput?:@"UNKNOWN",@"audioDevice":self.audioDevice?:@"",@"outputVolume":@(self.outputVolume),@"songVisible":@(!self.song.hidden),@"mapMode":@(self.mapMode),@"tripMode":@(self.tripMode),@"tripRunning":@(self.trip.running),@"tripSummary":[self.trip summary],@"tripState":self.tripView.state.text?:@"",@"miniVisible":@(!self.miniPlayer.hidden),@"miniTitle":self.miniPlayer.title.text?:@"",@"miniArtist":self.miniPlayer.artist.text?:@"",@"miniIcon":@(self.miniPlayer.icon.kind),@"musicHoldCount":@(((UIView *)self.navButtons[1]).gestureRecognizers.count),@"calmDrive":@(self.calmDrive),@"carLink":self.statusCar?:@"UNKNOWN",@"wifiSSID":self.statusWiFi?:@"NO NETWORK",@"powerState":self.statusPower?:@"UNKNOWN",@"gpsLive":@(self.gpsLive),@"navLabels":[self.navButtons valueForKey:@"accessibilityLabel"],@"youtubeSource":@(self.youtubeSource),@"commandsPending":@(self.commandsPending),@"metadataPending":@(self.metadataPending),@"artworkDecodes":@(self.artworkDecodes),@"artworkPixels":@(self.artwork.image?MAX(CGImageGetWidth(self.artwork.image.CGImage),CGImageGetHeight(self.artwork.image.CGImage)):0),@"memoryWarnings":@(self.memoryWarnings),@"gpsAccuracy":@(self.gps.desiredAccuracy),@"timerActive":@(self.timer!=nil&&[self.timer isValid]),@"meterActive":@(self.audioBars.refreshTimer!=nil),@"settingsTitle":self.settingsSheet.title?:@"",@"settingsActions":[self.settingsSheet.actions valueForKey:@"title"]?:@[],@"playbackKnown":@(self.hasPlaybackRate),@"transportIcon":@(((DashIcon *)[[self.controls viewWithTag:21]viewWithTag:105]).kind),@"settingsVisible":@(self.settingsSheet!=nil),@"theme":@(TRDTheme),@"displayMode":@(self.displayMode),@"welcomeVisible":@(self.welcome!=nil),@"mediaRate":@(self.mediaRate),@"bounds":NSStringFromCGRect(self.view.bounds),@"navFrame":NSStringFromCGRect(self.navigation.frame),@"musicMode":@(self.musicMode),@"navigationVisible":@(!self.navigation.hidden),@"trackTime":self.trackTime.text?:@"",@"trackProgress":@(self.trackProgress.progress),@"wheelAnimating":@(self.driveCar.wheelTimer!=nil),@"wheelAngle":@(self.driveCar.angle),@"autoDriveSuppressed":@(self.autoDriveSuppressed),@"driveMode":@(self.driveMode),@"audioState":self.audioBars.state?:@"",@"audioRMS":@(self.audioBars.rms),@"carStatus":self.carStatus.text?:@"",@"hasArtwork":@(self.artwork.image!=nil),@"artist":self.artist.text?:@"",@"nightMode":@(self.nightMode),@"brightness":@([UIScreen mainScreen].brightness),@"speed":self.speed.text?:@"",@"gps":self.gpsStatus.text?:@"",@"clock":self.clock.text?:@"",@"date":self.date.text?:@"",@"network":self.network.text?:@"",@"song":self.song.text?:@"",@"focused":@(self.focused),@"clockHudVisible":@(!self.clockHud.hidden),@"clockHudSpeed":((UILabel *)[self.clockHud viewWithTag:402]).text?:@"",@"clockHudGps":((UILabel *)[self.clockHud viewWithTag:405]).text?:@"",@"clockHudTrip":((UILabel *)[self.clockHud viewWithTag:407]).text?:@"",@"sourceBadge":self.sourceBadge.text?:@"",@"driveEQTitle":self.driveEQ.currentTitle?:@"",@"lastAction":self.lastAction?:@""};[report writeToFile:@"/var/mobile/h109-build/cardash-state.plist" atomically:YES];}
-(void)setCarDashRemoteControlEnabled:(BOOL)on{
 MPRemoteCommandCenter *rCenter = [MPRemoteCommandCenter sharedCommandCenter];
 [rCenter.nextTrackCommand removeTarget:nil];
 [rCenter.previousTrackCommand removeTarget:nil];
 [rCenter.togglePlayPauseCommand removeTarget:nil];
 [rCenter.playCommand removeTarget:nil];
 [rCenter.pauseCommand removeTarget:nil];
 if(on){
  [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
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
 } else {
  rCenter.nextTrackCommand.enabled = NO;
  rCenter.previousTrackCommand.enabled = NO;
  rCenter.togglePlayPauseCommand.enabled = NO;
  rCenter.playCommand.enabled = NO;
  rCenter.pauseCommand.enabled = NO;
  [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
  [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
 }
}
-(BOOL)canBecomeFirstResponder{return self.radioPlayer!=nil;}
-(MPRemoteCommandHandlerStatus)carRemoteNext:(id)event{
 if(self.radioPlayer){if(self.offlinePlaybackActive)[self nextOfflineTrack];return MPRemoteCommandHandlerStatusSuccess;}
 static NSTimeInterval lastNext=0;
 NSTimeInterval now=TRDMonotonic();
 if(now-lastNext>=0.25){
  lastNext=now;
  if([self isYouTubeMediaActive]){notify_post("com.codex.trd.youtube.next");}
  else{notify_post("com.codex.trd.music.next");}
 }
 return MPRemoteCommandHandlerStatusSuccess;
}
-(MPRemoteCommandHandlerStatus)carRemotePrev:(id)event{
 if(self.radioPlayer){if(self.offlinePlaybackActive)[self prevOfflineTrack];return MPRemoteCommandHandlerStatusSuccess;}
 static NSTimeInterval lastPrev=0;
 NSTimeInterval now=TRDMonotonic();
 if(now-lastPrev>=0.25){
  lastPrev=now;
  if([self isYouTubeMediaActive]){notify_post("com.codex.trd.youtube.previous");}
  else{notify_post("com.codex.trd.music.previous");}
 }
 return MPRemoteCommandHandlerStatusSuccess;
}
-(MPRemoteCommandHandlerStatus)carRemoteToggle:(id)event{
 if(self.radioPlayer){[self media:(UIButton *)[self.controls viewWithTag:21]];return MPRemoteCommandHandlerStatusSuccess;}
 static NSTimeInterval lastTog=0;
 NSTimeInterval now=TRDMonotonic();
 if(now-lastTog>=0.25){
  lastTog=now;
  if([self isYouTubeMediaActive]){notify_post("com.codex.trd.youtube.toggle");}
  else{notify_post("com.codex.trd.music.toggle");}
 }
 return MPRemoteCommandHandlerStatusSuccess;
}
-(MPRemoteCommandHandlerStatus)carRemotePlay:(id)event{
 if(self.radioPlayer){
  if(self.radioPlayer.rate<=0){
   [self.radioPlayer play];
   self.song.text=self.currentRadioStation?:(self.offlinePlaybackActive?@"Offline":@"Radio");
   self.artist.text=self.offlinePlaybackActive?(self.currentOfflineArtist?:@"OFFLINE MUSIC"):@"Live Radio Broadcast · Playing Live";
   [self refreshTransportState];
   [self refreshMini];
  }
  return MPRemoteCommandHandlerStatusSuccess;
 }
 static NSTimeInterval lastPlay=0;
 NSTimeInterval now=TRDMonotonic();
 if(now-lastPlay>=0.25){
  lastPlay=now;
  if([self isYouTubeMediaActive]){notify_post("com.codex.trd.youtube.play");}
  else{notify_post("com.codex.trd.music.play");}
 }
 return MPRemoteCommandHandlerStatusSuccess;
}
-(MPRemoteCommandHandlerStatus)carRemotePause:(id)event{
 if(self.radioPlayer){
  if(self.radioPlayer.rate>0){
   [self.radioPlayer pause];
   self.song.text=[NSString stringWithFormat:@"[PAUSED] %@",self.currentRadioStation?:(self.offlinePlaybackActive?@"Offline":@"Radio")];
   self.artist.text=@"Tap Play button to resume";
   [self refreshTransportState];
   [self refreshMini];
  }
  return MPRemoteCommandHandlerStatusSuccess;
 }
 static NSTimeInterval lastPause=0;
 NSTimeInterval now=TRDMonotonic();
 if(now-lastPause>=0.25){
  lastPause=now;
  if([self isYouTubeMediaActive]){notify_post("com.codex.trd.youtube.pause");}
  else{notify_post("com.codex.trd.music.pause");}
 }
 return MPRemoteCommandHandlerStatusSuccess;
}
-(void)remoteControlReceivedWithEvent:(UIEvent *)event{
 // Handled via MPRemoteCommandCenter targets; never re-broadcast MRMediaRemoteSendCommand here to avoid self-loop.
 (void)event;
}

-(void)carStatusTapped{
  if (self.featureExplanationTimer) {
    [self.featureExplanationTimer invalidate];
    self.featureExplanationTimer = nil;
  }
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideFeatureExplanation) object:nil];
  if (self.featureExplanationBanner) {
    [self.featureExplanationBanner removeFromSuperview];
    self.featureExplanationBanner = nil;
  }

  UIButton *dim = [UIButton buttonWithType:UIButtonTypeCustom];
  dim.frame = self.view.bounds;
  dim.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
  dim.userInteractionEnabled = YES;
  dim.layer.zPosition = 99999;
  [dim addTarget:self action:@selector(hideFeatureExplanation) forControlEvents:UIControlEventTouchUpInside];

  CGFloat w = 720;
  CGFloat h = 420;
  CGFloat x = (self.view.bounds.size.width - w) / 2.0;
  CGFloat y = (self.view.bounds.size.height - h) / 2.0;

  UIView *card = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, h)];
  card.backgroundColor = [UIColor colorWithRed:0.03 green:0.06 blue:0.10 alpha:0.98];
  card.layer.cornerRadius = 18;
  card.layer.borderWidth = 2.0;
  card.layer.borderColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.9].CGColor;
  card.layer.shadowColor = [UIColor blackColor].CGColor;
  card.layer.shadowOffset = CGSizeMake(0, 10);
  card.layer.shadowRadius = 24;
  card.layer.shadowOpacity = 0.95;
  card.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:card.bounds cornerRadius:18].CGPath;
  card.layer.zPosition = 100000;
  card.userInteractionEnabled = NO;

  UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 56)];
  topBar.backgroundColor = [UIColor colorWithRed:0.02 green:0.20 blue:0.30 alpha:1.0];
  topBar.layer.cornerRadius = 18;
  [card addSubview:topBar];

  UIImageView *hIcon = [[UIImageView alloc] initWithFrame:CGRectMake(24, 16, 24, 24)];
  hIcon.image = TRDAutoVectorIcon(3, 24.0, [UIColor colorWithRed:0.25 green:0.95 blue:1.0 alpha:1]);
  [card addSubview:hIcon];

  UILabel *tLbl = [[UILabel alloc] initWithFrame:CGRectMake(54, 12, w - 110, 32)];
  tLbl.font = [UIFont boldSystemFontOfSize:21];
  tLbl.textColor = [UIColor colorWithRed:0.25 green:0.95 blue:1.0 alpha:1];
  tLbl.text = @"สถานะประตู 5 บาน & ตัวถัง (5-DOOR STATUS)";
  [card addSubview:tLbl];

  UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  closeBtn.frame = CGRectMake(w - 56, 10, 44, 36);
  [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
  closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
  [closeBtn setTitleColor:[UIColor colorWithWhite:0.95 alpha:1] forState:UIControlStateNormal];
  [closeBtn addTarget:self action:@selector(hideFeatureExplanation) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:closeBtn];

  TRDOBDClient *obd = [TRDOBDClient sharedClient];
  BOOL doorsLive = obd.doorSensorsLive;
  BOOL doorOpenFlags[5] = {
    obd.doorFrontLeftOpen,
    obd.doorFrontRightOpen,
    obd.doorRearLeftOpen,
    obd.doorRearRightOpen,
    obd.trunkOpen
  };
  NSArray *doorTitles = @[
    @"ประตูหน้าซ้าย (FL • ผู้โดยสาร)",
    @"ประตูหน้าขวา (FR • คนขับ RHD)",
    @"ประตูหลังซ้าย (RL)",
    @"ประตูหลังขวา (RR)",
    @"ฝาท้ายสัมภาระ (TRUNK / HATCH)"
  ];
  
  for(int i=0; i<5; i++){
    BOOL isOpen = doorsLive && doorOpenFlags[i];
    CGFloat bY = 70 + (i * 54);
    UIView *doorRow = [[UIView alloc] initWithFrame:CGRectMake(24, bY, w - 48, 46)];
    doorRow.backgroundColor = [UIColor colorWithWhite:0.07 alpha:1];
    doorRow.layer.cornerRadius = 8;
    doorRow.layer.borderWidth = 1.2;
    doorRow.layer.borderColor = doorsLive
      ? (isOpen ? [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:0.9].CGColor : [UIColor colorWithRed:0.1 green:0.8 blue:0.4 alpha:0.5].CGColor)
      : [UIColor colorWithWhite:0.28 alpha:0.8].CGColor;
    
    UIColor *rowIconTint = doorsLive
      ? (isOpen ? [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1] : [UIColor colorWithRed:0.22 green:0.94 blue:0.55 alpha:1])
      : [UIColor colorWithRed:0.45 green:0.82 blue:0.96 alpha:0.9];
    UIImageView *rowIcon = [[UIImageView alloc] initWithFrame:CGRectMake(14, 13, 20, 20)];
    rowIcon.image = TRDAutoVectorIcon(3, 20.0, rowIconTint);
    [doorRow addSubview:rowIcon];

    UILabel *dLbl = [[UILabel alloc] initWithFrame:CGRectMake(42, 8, 340, 30)];
    dLbl.font = [UIFont boldSystemFontOfSize:17];
    dLbl.textColor = [UIColor whiteColor];
    dLbl.text = doorTitles[i];
    [doorRow addSubview:dLbl];
    
    UILabel *sLbl = [[UILabel alloc] initWithFrame:CGRectMake(w - 48 - 250, 8, 234, 30)];
    sLbl.font = [UIFont boldSystemFontOfSize:16];
    sLbl.textColor = doorsLive
      ? (isOpen ? [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1] : [UIColor colorWithRed:0.2 green:0.95 blue:0.45 alpha:1])
      : [UIColor colorWithWhite:0.65 alpha:1];
    sLbl.textAlignment = NSTextAlignmentRight;
    sLbl.text = doorsLive ? (isOpen ? @"🚨 เปิดอยู่ (OPEN!)" : @"🟢 ปิดสนิท (CLOSED)") : @"⚪ รอสัญญาณ CAN 0x620";
    [doorRow addSubview:sLbl];
    
    [card addSubview:doorRow];
  }

  UIView *beltRow = [[UIView alloc] initWithFrame:CGRectMake(24, 348, w - 48, 48)];
  beltRow.backgroundColor = [UIColor colorWithRed:0.02 green:0.14 blue:0.08 alpha:0.95];
  beltRow.layer.cornerRadius = 8;
  beltRow.layer.borderWidth = 1.2;
  beltRow.layer.borderColor = doorsLive
    ? [UIColor colorWithRed:0.2 green:0.85 blue:0.45 alpha:0.7].CGColor
    : [UIColor colorWithWhite:0.3 alpha:0.7].CGColor;
  
  UILabel *bLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, w - 80, 28)];
  bLbl.font = [UIFont boldSystemFontOfSize:15.0];
  bLbl.adjustsFontSizeToFitWidth = YES;
  bLbl.minimumScaleFactor = 0.8;
  bLbl.textColor = doorsLive ? [UIColor colorWithRed:0.35 green:0.98 blue:0.55 alpha:1] : [UIColor colorWithWhite:0.78 alpha:1];
  NSString *autoLockTag = obd.autoDoorLockEnabled ? @"Auto-Lock ≥20km/h: ON" : @"Auto-Lock: OFF (Settings)";
  NSString *lightTag = obd.headlightSensorsLive ? (obd.lightStateLabel ?: @"OFF") : @"รอ 0x622/0x57F";
  bLbl.text = doorsLive
    ? [NSString stringWithFormat:@"🔒 0x620 LIVE • 💡 ไฟ: %@ • %@", lightTag, autoLockTag]
    : [NSString stringWithFormat:@"ℹ️ รอ 0x620 • 💡 ไฟ: %@ • %@", lightTag, autoLockTag];
  [beltRow addSubview:bLbl];
  [card addSubview:beltRow];

  [dim addSubview:card];
  self.featureExplanationBanner = dim;
  gTRDFeatureBannerShownAt = [NSProcessInfo processInfo].systemUptime;
  [self.view addSubview:self.featureExplanationBanner];
  [self.view bringSubviewToFront:self.featureExplanationBanner];
  
  self.featureExplanationTimer = [NSTimer timerWithTimeInterval:8.0 target:self selector:@selector(hideFeatureExplanation) userInfo:nil repeats:NO];
  [[NSRunLoop mainRunLoop] addTimer:self.featureExplanationTimer forMode:NSRunLoopCommonModes];
  [self performSelector:@selector(hideFeatureExplanation) withObject:nil afterDelay:8.2 inModes:@[NSRunLoopCommonModes]];
}

-(void)showFeatureExplanation:(NSString *)title body:(NSString *)body {
  if (self.featureExplanationTimer) {
    [self.featureExplanationTimer invalidate];
    self.featureExplanationTimer = nil;
  }
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideFeatureExplanation) object:nil];
  if (self.featureExplanationBanner) {
    [self.featureExplanationBanner removeFromSuperview];
    self.featureExplanationBanner = nil;
  }

  UIButton *dim = [UIButton buttonWithType:UIButtonTypeCustom];
  dim.frame = self.view.bounds;
  dim.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.80];
  dim.userInteractionEnabled = YES;
  dim.layer.zPosition = 99999;
  [dim addTarget:self action:@selector(hideFeatureExplanation) forControlEvents:UIControlEventTouchUpInside];

  CGFloat w = 660;
  CGFloat h = 340;
  CGFloat x = (self.view.bounds.size.width - w) / 2.0;
  CGFloat y = (self.view.bounds.size.height - h) / 2.0;

  UIView *card = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, h)];
  card.backgroundColor = [UIColor colorWithRed:0.03 green:0.07 blue:0.12 alpha:1.0];
  card.layer.cornerRadius = 16;
  card.layer.borderWidth = 2.0;
  card.layer.borderColor = [UIColor colorWithRed:0.0 green:0.90 blue:1.0 alpha:0.95].CGColor;
  card.layer.shadowColor = [UIColor blackColor].CGColor;
  card.layer.shadowOffset = CGSizeMake(0, 10);
  card.layer.shadowRadius = 20;
  card.layer.shadowOpacity = 0.9;
  card.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:card.bounds cornerRadius:16].CGPath;
  card.layer.zPosition = 100000;
  card.userInteractionEnabled = NO;

  UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 52)];
  topBar.backgroundColor = [UIColor colorWithRed:0.02 green:0.24 blue:0.34 alpha:1.0];
  topBar.layer.cornerRadius = 16;
  [card addSubview:topBar];

  UILabel *tLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, w - 80, 32)];
  tLbl.font = [UIFont boldSystemFontOfSize:19];
  tLbl.textColor = [UIColor colorWithRed:0.2 green:0.95 blue:1.0 alpha:1];
  tLbl.text = title;
  [card addSubview:tLbl];

  UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  closeBtn.frame = CGRectMake(w - 56, 8, 44, 36);
  [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
  closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
  [closeBtn setTitleColor:[UIColor colorWithWhite:0.95 alpha:1] forState:UIControlStateNormal];
  [closeBtn addTarget:self action:@selector(hideFeatureExplanation) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:closeBtn];

  UILabel *bLbl = [[UILabel alloc] initWithFrame:CGRectMake(24, 64, w - 48, h - 120)];
  bLbl.font = [UIFont systemFontOfSize:16.5];
  bLbl.textColor = [UIColor whiteColor];
  bLbl.numberOfLines = 0;
  bLbl.text = body;
  [card addSubview:bLbl];

  UILabel *timerLbl = [[UILabel alloc] initWithFrame:CGRectMake(24, h - 42, w - 48, 26)];
  timerLbl.font = [UIFont boldSystemFontOfSize:13];
  timerLbl.textColor = [UIColor colorWithRed:0.35 green:0.95 blue:0.75 alpha:1.0];
  timerLbl.textAlignment = NSTextAlignmentRight;
  timerLbl.text = @"⏱️ ปิดอัตโนมัติใน 8 วินาที • แตะที่ใดก็ได้เพื่อปิด";
  [card addSubview:timerLbl];

  [dim addSubview:card];

  dim.alpha = 0.0;
  [self.view addSubview:dim];
  [self.view bringSubviewToFront:dim];
  self.featureExplanationBanner = dim;
  gTRDFeatureBannerShownAt = [NSProcessInfo processInfo].systemUptime;

  [UIView animateWithDuration:0.22 animations:^{
    dim.alpha = 1.0;
  }];

  self.featureExplanationTimer = [NSTimer timerWithTimeInterval:8.0 target:self selector:@selector(hideFeatureExplanation) userInfo:nil repeats:NO];
  [[NSRunLoop mainRunLoop] addTimer:self.featureExplanationTimer forMode:NSRunLoopCommonModes];
  [self performSelector:@selector(hideFeatureExplanation) withObject:nil afterDelay:8.2 inModes:@[NSRunLoopCommonModes]];
}

-(void)hideFeatureExplanation {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideFeatureExplanation) object:nil];
  gTRDFeatureBannerShownAt = 0;
  if (self.featureExplanationTimer) {
    [self.featureExplanationTimer invalidate];
    self.featureExplanationTimer = nil;
  }
  if (!self.featureExplanationBanner) return;
  UIView *dim = self.featureExplanationBanner;
  self.featureExplanationBanner = nil;
  dim.userInteractionEnabled = NO;
  [UIView animateWithDuration:0.18 animations:^{
    dim.alpha = 0.0;
  } completion:^(BOOL finished){
    [dim removeFromSuperview];
  }];
}

-(void)openFeatureHelpMenu {
  TRDSettingsMenu *m = [self settingsMenu:@"💡 คู่มือแนะนำฟังก์ชัน (PRIUS TRD GUIDE)" message:@"แตะเลือกหัวข้อเพื่อดูคำอธิบายการทำงานของระบบ:"];

  [m addAction:[TRDSettingAction actionWithTitle:@"🏎️ โหมดการขับขี่ (SPORT / NORMAL / ECO)" style:0 handler:^(TRDSettingAction *a){
    [self showFeatureExplanation:@"🏎️ โหมดการขับขี่ (DRIVE MODES)" body:@"• ECO MODE: หน่วงการตอบสนองคันเร่งและดึงกำลังมอเตอร์ไฟฟ้าสูงสุดเพื่อประหยัดน้ำมันสูงสุด เหมาะกับการขับในเมืองและการจราจรติดขัด\n• NORMAL MODE: คันเร่งตอบสนองเป็นธรรมชาติ สมดุลระหว่างอัตราเร่งและการประหยัด\n• SPORT MODE: ลิ้นปีกผีเสื้อและมอเตอร์ไฟฟ้าตอบสนองรวดเร็วทันใจ ให้พละกำลังเร่งแซงสูงสุด สไตล์ TRD Sportivo"];
  }]];

  [m addAction:[TRDSettingAction actionWithTitle:@"⚡ ระบบไฮบริด & แบตเตอรี่ HV (Synergy Drive)" style:0 handler:^(TRDSettingAction *a){
    [self showFeatureExplanation:@"⚡ ระบบไฮบริด & แบตเตอรี่ HV" body:@"• เครื่องยนต์ 1.8L Atkinson Cycle ผสานมอเตอร์ไฟฟ้า MG2 (ขับเคลื่อน) และ MG1 (ปั่นไฟ)\n• เมื่อถอนคันเร่งหรือเหยียบเบรก ระบบจะชาร์จไฟกลับ (Regeneration) สูงสุดถึง 20+ kW เข้าแบตเตอรี่ไฮบริด 201.6V (14 บล็อก 28 โมดูล)\n• ระดับ SOC ที่ดีที่สุดคือ 40% - 80% เพื่อถนอมอายุการใช้งานของแบตเตอรี่ได้ยาวนานที่สุด"];
  }]];

  [m addAction:[TRDSettingAction actionWithTitle:@"⏱️ Trip A/B & ระยะทาง A➔B สตาร์ทถึงดับเครื่อง" style:0 handler:^(TRDSettingAction *a){
    [self showFeatureExplanation:@"⏱️ ระบบวัดระยะทาง TRIP & A➔B" body:@"• วัดระยะทางจริงตามดาวเทียม GPS แบบเรียลไทม์\n• Smart Auto-Pause: เมื่อรถจอดนิ่ง (ความเร็ว < 2 km/h) ระบบจะหยุดพักการนับอัตโนมัติ เพื่อป้องกันระยะทางคลาดเคลื่อนขณะติดไฟแดง\n• แตะที่ตัวเลขระยะทาง 0.00 km เพื่อรีเซ็ตค่าทริปได้ทันทีใน 1 วินาที พร้อมคำนวณค่าน้ำมันและความเร็วเฉลี่ยอัตโนมัติ"];
  }]];

  [m addAction:[TRDSettingAction actionWithTitle:@"🚘 ประตู 5 บาน & เข็มขัดนิรภัยรอบคัน" style:0 handler:^(TRDSettingAction *a){
    [self showFeatureExplanation:@"🚘 ระบบตรวจจับประตู 5 บาน & เข็มขัด" body:@"• ตรวจสอบสถานะประตูทั้ง 5 บาน: หน้าซ้าย (FL), หน้าขวา (FR), หลังซ้าย (RL), หลังขวา (RR) และฝาท้าย (Trunk)\n• แถบสีเขียว = ปิดสนิทปลอดภัย\n• แถบสีแดง = ประตูเปิดอยู่หรือปิดไม่สนิท มีการแจ้งเตือนทันที\n• พร้อมระบบตรวจสอบการล็อคเข็มขัดนิรภัยเพื่อความปลอดภัยสูงสุด"];
  }]];

  [m addAction:[TRDSettingAction actionWithTitle:@"⛽ ราคาน้ำมันสดจากปั๊ม ปตท./บางจาก ออนไลน์" style:0 handler:^(TRDSettingAction *a){
    [self showFeatureExplanation:@"⛽ ราคาน้ำมันสดจากปั๊มออนไลน์" body:@"• เชื่อมต่อ API ดึงราคาน้ำมันสดๆ จากปั๊ม ปตท. (PTT) และบางจาก (BCP) ในไทยแบบเรียลไทม์\n• นำราคาจริงมาคำนวณค่าน้ำมันของแต่ละทริปอย่างแม่นยำ\n• หากออฟไลน์ ระบบจะจำราคาล่าสุดไว้ใช้งานต่อเนื่องอัตโนมัติ"];
  }]];

  [m addAction:[TRDSettingAction actionWithTitle:@"🛢️ ระบบแจ้งเตือน & บันทึกประวัติน้ำมันเครื่อง" style:0 handler:^(TRDSettingAction *a){
    [self showFeatureExplanation:@"🛢️ บันทึกประวัติน้ำมันเครื่อง" body:@"• บันทึกวันที่เปลี่ยนถ่ายและเลขไมล์สะสมของรถ\n• ตั้งรอบเปลี่ยนมาตรฐานที่ 10,000 km (สำหรับน้ำมันเครื่องสังเคราะห์แท้ 0W-20)\n• มีระบบนับถอยหลังระยะทางที่เหลือ และเตือนล่วงหน้าเมื่อเหลือน้อยกว่า 1,000 km สามารถดูประวัติย้อนหลังได้ในเมนู SETTINGS"];
  }]];

  [self presentSettingsMenu:m];
}

-(void)syncActiveFuelRateToTripA{
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 double price=(obd.fuelPricePerLiter>0)?obd.fuelPricePerLiter:38.50;
 NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];
 NSMutableDictionary *slotA=[[self loadTripSlot:0] mutableCopy];
 double fuelA=[slotA[@"fuel"] doubleValue];
 double newCostA=fuelA*price;
 slotA[@"cost"]=@(newCostA);
 [ud setObject:slotA forKey:@"TRDTripSlot_0"];
 self.lastSlotCost=obd.tripFuelUsedLiters*price;
 [ud setDouble:self.lastSlotCost forKey:@"TRDLastSyncedTripCost"];
 [ud synchronize];
 [self refreshDriveTripDisplay];
 [self refreshLiveOBDDashboard];
}

-(UIView *)ensureVoiceHudPopup{
 UIView *host = [UIApplication sharedApplication].keyWindow ?: self.view;
 UIView *hud = [host viewWithTag:955];
 if(!hud){
  CGFloat bw = MIN(560.0, host.bounds.size.width - 40.0);
  hud = [[UIView alloc]initWithFrame:CGRectMake((host.bounds.size.width - bw) * 0.5, 52.0, bw, 52.0)];
  hud.tag = 955;
  hud.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.10 alpha:0.96];
  hud.layer.cornerRadius = 26.0;
  hud.layer.borderWidth = 1.8;
  hud.layer.borderColor = [UIColor colorWithRed:0.15 green:0.90 blue:1.0 alpha:0.95].CGColor;
  hud.layer.shadowColor = [UIColor blackColor].CGColor;
  hud.layer.shadowOpacity = 0.75;
  hud.layer.shadowRadius = 12.0;
  hud.layer.shadowOffset = CGSizeMake(0, 4);
  hud.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:hud.bounds cornerRadius:26.0].CGPath;
  hud.layer.zPosition = 99999.0;
  hud.userInteractionEnabled = NO;

  // 7 live animated sound-wave frequency bars on the left
  for(int i = 0; i < 7; i++){
   UIView *bar = [[UIView alloc]initWithFrame:CGRectMake(20.0 + i * 7.5, 22.0, 4.5, 8.0)];
   bar.tag = 960 + i;
   bar.backgroundColor = (i % 2 == 0)
    ? [UIColor colorWithRed:0.15 green:0.92 blue:1.0 alpha:1.0]
    : [UIColor colorWithRed:1.0 green:0.28 blue:0.42 alpha:1.0];
   bar.layer.cornerRadius = 2.25;
   [hud addSubview:bar];
  }

  UILabel *lbl = [[UILabel alloc]initWithFrame:CGRectMake(82.0, 6.0, bw - 98.0, 40.0)];
  lbl.tag = 956;
  lbl.font = [UIFont boldSystemFontOfSize:15.5];
  lbl.textColor = [UIColor whiteColor];
  lbl.textAlignment = NSTextAlignmentLeft;
  lbl.adjustsFontSizeToFitWidth = YES;
  lbl.minimumScaleFactor = 0.72;
  [hud addSubview:lbl];
  self.voiceBanner = lbl;
  [host addSubview:hud];
 } else {
  CGFloat bw = MIN(560.0, host.bounds.size.width - 40.0);
  hud.frame = CGRectMake((host.bounds.size.width - bw) * 0.5, 52.0, bw, 52.0);
  UILabel *lbl = (UILabel *)[hud viewWithTag:956];
  if(lbl){ lbl.frame = CGRectMake(82.0, 6.0, bw - 98.0, 40.0); self.voiceBanner = lbl; }
 }
 hud.layer.zPosition = 99999.0;
 [host bringSubviewToFront:hud];
 return hud;
}

-(void)updateVoiceWaveLevel:(float)level{
 UIView *host = [UIApplication sharedApplication].keyWindow ?: self.view;
 UIView *hud = [host viewWithTag:955];
 if(!hud || hud.hidden) return;
 float norm = MAX(0.12f, MIN(1.0f, level));
 static const float weights[7] = {0.55f, 0.85f, 1.0f, 0.92f, 1.0f, 0.78f, 0.50f};
 double t = [NSProcessInfo processInfo].systemUptime * 14.0;
 for(int i = 0; i < 7; i++){
  UIView *bar = [hud viewWithTag:960 + i];
  if(!bar) continue;
  float wave = 0.65f + 0.35f * (float)sin(t + i * 0.95);
  CGFloat bh = MAX(6.0, MIN(34.0, 6.0 + 28.0 * norm * weights[i] * wave));
  bar.frame = CGRectMake(20.0 + i * 7.5, 26.0 - bh * 0.5, 4.5, bh);
 }
}

-(void)showVoiceToast:(NSString *)text color:(UIColor *)col autoHide:(NSTimeInterval)delay{
 UIView *hud = [self ensureVoiceHudPopup];
 hud.layer.borderColor = [(col ?: [UIColor colorWithRed:0.15 green:0.90 blue:1.0 alpha:0.95]) colorWithAlphaComponent:0.92].CGColor;
 self.voiceBanner.textColor = col ?: [UIColor whiteColor];
 self.voiceBanner.text = text ?: @"";
 hud.hidden = NO;
 if(!self.voiceListening){
  for(int i = 0; i < 7; i++){
   UIView *bar = [hud viewWithTag:960 + i];
   if(bar) bar.frame = CGRectMake(20.0 + i * 7.5, 22.0, 4.5, 8.0);
  }
 }
 NSUInteger gen = self.voiceSessionGen;
 if(delay > 0){
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
   if(!self.voiceListening && self.voiceSessionGen == gen){
    UIView *h = [([UIApplication sharedApplication].keyWindow ?: self.view) viewWithTag:955];
    if(h) h.hidden = YES;
   }
  });
 }
}

-(void)stopVoiceListeningAndExecute:(BOOL)shouldExecute{
 NSString *heard = [self.voiceLastTranscript copy];
 self.voiceListening = NO;
 self.voiceSessionGen++;
 if(self.voiceEngine){
  @try {
   if(self.voiceEngine.isRunning)[self.voiceEngine stop];
   [self.voiceEngine.inputNode removeTapOnBus:0];
  } @catch (NSException *ex) {}
  self.voiceEngine = nil;
 }
 if(self.speechRequest){
  @try { [self.speechRequest endAudio]; } @catch (NSException *ex) {}
  self.speechRequest = nil;
 }
 if(self.speechTask){
  @try { [self.speechTask cancel]; } @catch (NSException *ex) {}
  self.speechTask = nil;
 }
 // Cleanly reset category to Ambient (no HFP/Duck) BEFORE deactivating so audioNINJA keeps 100% stereo volume & never cuts off!
 @try {
  AVAudioSession *sess = [AVAudioSession sharedInstance];
  [sess setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
  [sess setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
 } @catch (NSException *ex) {}
 [[TRDFrontGestureEngine sharedEngine] cooldownFor:4.5];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
  if(!self.isReverseActive && !self.voiceListening && [UIApplication sharedApplication].applicationState == UIApplicationStateActive){
   [[TRDFrontGestureEngine sharedEngine] ensureRunning];
  }
 });
 [self.voicePill setTitle:@"🎙️" forState:UIControlStateNormal];
 self.voicePill.backgroundColor = [UIColor colorWithRed:0.18 green:0.04 blue:0.08 alpha:0.95];
 self.voicePill.layer.borderColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.35 alpha:0.85].CGColor;
 if(shouldExecute && heard.length > 0){
  [self executeVoiceCommand:heard];
 } else if(shouldExecute){
  [self showVoiceToast:@"🎙️ ไม่ได้ยินคำสั่ง ลองแตะไมค์แล้วพูดใหม่ครับ" color:[UIColor colorWithRed:1.0 green:0.78 blue:0.30 alpha:1.0] autoHide:2.8];
 } else {
  UIView *h = [([UIApplication sharedApplication].keyWindow ?: self.view) viewWithTag:955];
  if(h) h.hidden = YES;
 }
}

-(void)executeVoiceCommand:(NSString *)raw{
 NSString *t = [[raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
 if(!t.length) return;
 // 1. Camera
 if([t containsString:@"กล้อง"] || [t containsString:@"camera"]){
  [self showVoiceToast:@"✅ เปิดกล้อง H109" color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:2.2];
  [self openCamera];
  return;
 }
 // 2. Map / Navigation
 if([t containsString:@"แผนที่"] || [t containsString:@"นำทาง"] || [t containsString:@"map"]){
  [self showVoiceToast:@"✅ เปิดแผนที่นำทาง" color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:2.2];
  if(!self.mapMode){
   self.mapMode = YES; self.driveMode = NO; self.carplayMode = NO; self.carplayGridMode = NO; self.tripMode = NO;
   [self.view setNeedsLayout];
  }
  return;
 }
 // 3. Drive Mode
 if([t containsString:@"โหมดขับ"] || [t containsString:@"ไดรฟ์"] || [t containsString:@"drive"]){
  [self showVoiceToast:@"✅ เข้าสู่ Drive Mode" color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:2.2];
  if(!self.driveMode)[self toggleDrive];
  return;
 }
 // 4. Home / Dashboard
 if([t containsString:@"หน้าแรก"] || [t containsString:@"หน้าหลัก"] || [t containsString:@"แดชบอร์ด"] || [t containsString:@"โฮม"] || [t containsString:@"home"]){
  [self showVoiceToast:@"✅ กลับหน้าหลัก CarDash" color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:2.2];
  self.driveMode = NO; self.mapMode = NO; self.carplayMode = NO; self.carplayGridMode = NO; self.tripMode = NO;
  [self.view setNeedsLayout];
  return;
 }
 // 5. Night / Day Mode
 if([t containsString:@"กลางคืน"] || [t containsString:@"night"]){
  if(!self.nightMode)[self toggleNight];
  [self showVoiceToast:@"✅ เปิดโหมดกลางคืน" color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:2.2];
  return;
 }
 if([t containsString:@"กลางวัน"] || [t containsString:@"day"]){
  if(self.nightMode)[self toggleNight];
  [self showVoiceToast:@"✅ เปิดโหมดกลางวัน" color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:2.2];
  return;
 }
 // 6. Fuel prices
 if([t containsString:@"น้ำมัน"] || [t containsString:@"ราคา"]){
  [self showVoiceToast:@"✅ เปิดราคาน้ำมันสด" color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:2.2];
  [self openFuelPriceSettings];
  return;
 }
 // 7. Trip Summary
 if([t containsString:@"สรุป"] || [t containsString:@"ทริป"] || [t containsString:@"รายวัน"]){
  [self showVoiceToast:@"✅ เปิดสรุปทริปขับขี่" color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:2.2];
  [self showTripSummary];
  return;
 }
 // 8. Playback controls
 Boolean (*pMRCmd)(int, id) = dlsym(RTLD_DEFAULT, "MRMediaRemoteSendCommand");
 if([t containsString:@"หยุดเพลง"] || [t containsString:@"พักเพลง"] || [t containsString:@"ปิดเพลง"] || [t containsString:@"pause"] || [t containsString:@"stop"]){
  [self showVoiceToast:@"⏸ หยุดเล่นเพลง" color:[UIColor colorWithRed:0.25 green:0.92 blue:1.0 alpha:1.0] autoHide:2.2];
  if(pMRCmd) pMRCmd(1, nil);
  return;
 }
 if([t containsString:@"ถัดไป"] || [t containsString:@"ข้ามเพลง"] || [t containsString:@"เปลี่ยนเพลง"] || [t containsString:@"next"]){
  [self showVoiceToast:@"⏭ เพลงถัดไป" color:[UIColor colorWithRed:0.25 green:0.92 blue:1.0 alpha:1.0] autoHide:2.2];
  if(pMRCmd) pMRCmd(4, nil);
  return;
 }
 if([t containsString:@"ก่อนหน้า"] || [t containsString:@"ย้อนเพลง"] || [t containsString:@"previous"]){
  [self showVoiceToast:@"⏮ เพลงก่อนหน้า" color:[UIColor colorWithRed:0.25 green:0.92 blue:1.0 alpha:1.0] autoHide:2.2];
  if(pMRCmd) pMRCmd(5, nil);
  return;
 }
 // 9. Music play or Song/Artist search on YouTube
 NSString *q = raw;
 NSArray *fillers = @[@"เปิดเพลง",@"เล่นเพลง",@"ขอเพลง",@"ค้นหาเพลง",@"หาเพลง",@"เปิดยูทูบ",@"ในยูทูบ",@"ยูทูบ",@"youtube",@"ในคาร์แดช",@"คาร์แดช",@"ให้หน่อย",@"หน่อย",@"ครับ",@"ค่ะ",@"เปิด",@"เล่น"];
 for(NSString *f in fillers){
  q = [q stringByReplacingOccurrencesOfString:f withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, q.length)];
 }
 q = [q stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
 if(!q.length && ([t containsString:@"เพลง"] || [t containsString:@"music"] || [t containsString:@"play"])){
  [self showVoiceToast:@"▶️ เล่นเพลงต่อบน CarDash" color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:2.2];
  if(pMRCmd) pMRCmd(0, nil);
  return;
 }
 if(q.length > 0){
  [[TRDOBDClient sharedClient] obdLog:@"VOICE song search -> '%@' (raw='%@')", q, raw];
  [self showVoiceToast:[NSString stringWithFormat:@"🎵 กำลังค้นหาและเล่น: %@", q] color:[UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] autoHide:3.5];
  NSString *vsPath = @"/var/mobile/codex-car/voice-search.plist";
  NSDate *reqAt = [NSDate date];
  [@{@"query":q, @"pending":@YES, @"at":reqAt} writeToFile:vsPath atomically:YES];
  notify_post("com.codex.trd.music.voicesearch");
  // Wake audioNINJA silently in background first via FBSSystemService (__ActivateSuspended) so screen NEVER leaves CarDash!
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
   NSDictionary *chkBg = [NSDictionary dictionaryWithContentsOfFile:vsPath];
   if([chkBg[@"pending"] boolValue] && [chkBg[@"query"] isEqualToString:q]){
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
     Class fbsCls = NSClassFromString(@"FBSSystemService");
     if(!fbsCls){
      dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_LAZY);
      fbsCls = NSClassFromString(@"FBSSystemService");
     }
     id svc = (fbsCls && [fbsCls respondsToSelector:@selector(sharedService)]) ? ((id (*)(id, SEL))objc_msgSend)(fbsCls, @selector(sharedService)) : nil;
     SEL openSel = NSSelectorFromString(@"openApplication:options:withResult:");
     if(svc && [svc respondsToSelector:openSel]){
      NSDictionary *opts = @{@"__ActivateSuspended": @YES};
      ((void (*)(id, SEL, NSString *, NSDictionary *, id))objc_msgSend)(svc, openSel, @"com.legacymusic.app", opts, nil);
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.65 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
       notify_post("com.codex.trd.music.voicesearch");
      });
     }
    });
   }
  });
  // Fallback only if suspended background wake was blocked and audioNINJA still hasn't picked up after 2.4s:
  __weak Dashboard *weakSelf = self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
   NSDictionary *chk = [NSDictionary dictionaryWithContentsOfFile:vsPath];
   if([chk[@"pending"] boolValue] && [chk[@"query"] isEqualToString:q]){
    Dashboard *s = weakSelf;
    if(s){
     [[TRDOBDClient sharedClient] obdLog:@"VOICE waking audioNINJA for '%@'", q];
     [s launchBundleApp:@"com.legacymusic.app"];
    }
   }
  });
 } else {
  [self showVoiceToast:[NSString stringWithFormat:@"🎙️ ได้ยิน: %@", raw] color:[UIColor colorWithRed:1.0 green:0.85 blue:0.35 alpha:1.0] autoHide:2.8];
 }
}

-(void)startVoiceListening{
 if(self.voiceListening) return;
 [[TRDFrontGestureEngine sharedEngine] stop];
 static NSTimeInterval sLastVoiceStartAt = 0;
 NSTimeInterval nowUpV = [NSProcessInfo processInfo].systemUptime;
 if((nowUpV - sLastVoiceStartAt) < 0.45) return;
 sLastVoiceStartAt = nowUpV;
 // Ensure any previous engine/task is 100% torn down before starting a new session
 if(self.voiceEngine){
  @try { if(self.voiceEngine.isRunning)[self.voiceEngine stop]; [self.voiceEngine.inputNode removeTapOnBus:0]; } @catch (NSException *e) {}
  self.voiceEngine = nil;
 }
 if(self.speechTask){ @try { [self.speechTask cancel]; } @catch (NSException *e) {} self.speechTask = nil; }
 if(self.speechRequest){ @try { [self.speechRequest endAudio]; } @catch (NSException *e) {} self.speechRequest = nil; }
 self.voiceListening = YES;
 self.voiceLastTranscript = @"";
 self.voiceSessionGen++;
 NSUInteger gen = self.voiceSessionGen;

 [self.voicePill setTitle:@"⏹" forState:UIControlStateNormal];
 self.voicePill.backgroundColor = [UIColor colorWithRed:0.85 green:0.08 blue:0.16 alpha:0.98];
 self.voicePill.layer.borderColor = [UIColor whiteColor].CGColor;
 [self showVoiceToast:@"🎙️ กำลังฟัง... พูดชื่อเพลงหรือคำสั่งได้เลย" color:[UIColor colorWithRed:0.25 green:0.95 blue:1.0 alpha:1.0] autoHide:0];

 @try {
  AVAudioSession *sess = [AVAudioSession sharedInstance];
  // Use built-in iPad mic + A2DP Stereo + DuckOthers so music lowers briefly while listening & never feeds lyrics into mic!
  AVAudioSessionCategoryOptions vOpts = AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetoothA2DP | AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDuckOthers;
  [sess setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:vOpts error:nil];
  [sess setMode:AVAudioSessionModeDefault error:nil];
  [sess setActive:YES error:nil];

  if(!self.speechRecognizer){
   self.speechRecognizer = [[SFSpeechRecognizer alloc]initWithLocale:[NSLocale localeWithLocaleIdentifier:@"th-TH"]];
  }
  if(!self.speechRecognizer || !self.speechRecognizer.isAvailable){
   [self stopVoiceListeningAndExecute:NO];
   [self showVoiceToast:@"⚠️ สั่งเสียงต้องเชื่อมต่อเน็ต Hotspot ก่อนครับ" color:[UIColor colorWithRed:1.0 green:0.65 blue:0.20 alpha:1.0] autoHide:3.5];
   return;
  }

  self.voiceEngine = [[AVAudioEngine alloc]init];
  self.speechRequest = [[SFSpeechAudioBufferRecognitionRequest alloc]init];
  self.speechRequest.shouldReportPartialResults = YES;

  AVAudioInputNode *inputNode = self.voiceEngine.inputNode;
  __weak Dashboard *weakSelf = self;
  __block CFTimeInterval lastWaveDraw = 0;
  [inputNode installTapOnBus:0 bufferSize:1024 format:nil block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when){
   Dashboard *s = weakSelf;
   if(s && s.speechRequest)[s.speechRequest appendAudioPCMBuffer:buffer];
   CFTimeInterval nowW = CACurrentMediaTime();
   if(buffer && buffer.floatChannelData && buffer.frameLength > 0 && (nowW - lastWaveDraw) >= 0.06){
    lastWaveDraw = nowW;
    float *ch = buffer.floatChannelData[0];
    uint32_t n = buffer.frameLength;
    float sumSq = 0.0f;
    for(uint32_t i = 0; i < n; i += 4){ float v = ch[i]; sumSq += v * v; }
    float rms = sqrtf(sumSq / MAX(1.0f, (float)(n / 4)));
    float lvl = MIN(1.0f, rms * 14.0f);
    dispatch_async(dispatch_get_main_queue(), ^{
     Dashboard *s2 = weakSelf;
     if(s2 && s2.voiceListening)[s2 updateVoiceWaveLevel:lvl];
    });
   }
  }];

  [self.voiceEngine prepare];
  NSError *startErr = nil;
  [self.voiceEngine startAndReturnError:&startErr];
  if(startErr){
   [self stopVoiceListeningAndExecute:NO];
   [self showVoiceToast:@"⚠️ เปิดไมโครโฟนไม่สำเร็จ กรุณาเช็กสิทธิ์ไมค์ครับ" color:[UIColor colorWithRed:1.0 green:0.45 blue:0.35 alpha:1.0] autoHide:3.5];
   return;
  }

  self.speechTask = [self.speechRecognizer recognitionTaskWithRequest:self.speechRequest resultHandler:^(SFSpeechRecognitionResult *result, NSError *error){
   dispatch_async(dispatch_get_main_queue(), ^{
    Dashboard *s = weakSelf;
    if(!s || !s.voiceListening || s.voiceSessionGen != gen) return;
    if(result){
     NSString *txt = result.bestTranscription.formattedString;
     if(txt.length > 0){
      s.voiceLastTranscript = txt;
      [s showVoiceToast:[NSString stringWithFormat:@"🎙️ %@", txt] color:[UIColor whiteColor] autoHide:0];
      if(result.isFinal){
       [s stopVoiceListeningAndExecute:YES];
       return;
      }
      // Auto-execute after 1.3s pause once user finishes speaking
      NSString *snap = [txt copy];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
       Dashboard *s2 = weakSelf;
       if(s2 && s2.voiceListening && s2.voiceSessionGen == gen && [s2.voiceLastTranscript isEqualToString:snap]){
        [s2 stopVoiceListeningAndExecute:YES];
       }
      });
     }
    }
    if(error){
     [s stopVoiceListeningAndExecute:(s.voiceLastTranscript.length > 0)];
    }
   });
  }];

  // Hard cap at 5.5 seconds so mic never stays open
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
   Dashboard *s = weakSelf;
   if(s && s.voiceListening && s.voiceSessionGen == gen){
    [s stopVoiceListeningAndExecute:YES];
   }
  });
 } @catch (NSException *ex) {
  [self stopVoiceListeningAndExecute:NO];
  [self showVoiceToast:@"⚠️ ระบบสั่งเสียงขัดข้องชั่วคราว" color:[UIColor colorWithRed:1.0 green:0.45 blue:0.35 alpha:1.0] autoHide:3.0];
 }
}

-(void)toggleVoiceCommand{
 if(self.voiceListening){
  [self stopVoiceListeningAndExecute:(self.voiceLastTranscript.length > 0)];
  return;
 }
 SFSpeechRecognizerAuthorizationStatus st = [SFSpeechRecognizer authorizationStatus];
 if(st == SFSpeechRecognizerAuthorizationStatusAuthorized){
  [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted){
   dispatch_async(dispatch_get_main_queue(), ^{
    if(granted)[self startVoiceListening];
    else [self showVoiceToast:@"⚠️ กรุณาอนุญาตสิทธิ์ไมโครโฟนใน Settings ครับ" color:[UIColor colorWithRed:1.0 green:0.55 blue:0.25 alpha:1.0] autoHide:3.5];
   });
  }];
 } else {
  [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus newSt){
   dispatch_async(dispatch_get_main_queue(), ^{
    if(newSt == SFSpeechRecognizerAuthorizationStatusAuthorized){
     [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted){
      dispatch_async(dispatch_get_main_queue(), ^{
       if(granted)[self startVoiceListening];
       else [self showVoiceToast:@"⚠️ กรุณาอนุญาตสิทธิ์ไมโครโฟนใน Settings ครับ" color:[UIColor colorWithRed:1.0 green:0.55 blue:0.25 alpha:1.0] autoHide:3.5];
      });
     }];
    } else {
     [self showVoiceToast:@"⚠️ กรุณาอนุญาต Speech Recognition ใน Settings ครับ" color:[UIColor colorWithRed:1.0 green:0.55 blue:0.25 alpha:1.0] autoHide:3.5];
    }
   });
  }];
 }
}

-(void)openFuelPriceSettings{
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 NSString *msg=[NSString stringWithFormat:@"น้ำมัน: %@ (%.2f ฿/L)\nที่มา: %@ · %@",obd.selectedFuelTypeName?:@"แก๊สโซฮอล์ 95",obd.fuelPricePerLiter,obd.oilPriceSource?:@"บางจาก / คาลเท็กซ์",obd.oilPriceDate?:@"วันนี้"];
 TRDSettingsMenu *m=[self settingsMenu:@"⛽ ราคาน้ำมันสด (บางจาก / คาลเท็กซ์)" message:msg];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"⌨️ พิมพ์ราคาน้ำมันเอง (ปัจจุบัน %.2f ฿/L)",obd.fuelPricePerLiter] style:0 handler:^(TRDSettingAction *a){
  UIAlertController *ac=[UIAlertController alertControllerWithTitle:@"กำหนดราคาน้ำมัน (฿/ลิตร)" message:@"ใส่ราคาหน้าปั๊มที่เติม เช่น 30.10 หรือ 38.14" preferredStyle:UIAlertControllerStyleAlert];
  [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
   tf.keyboardType=UIKeyboardTypeDecimalPad;
   tf.placeholder=@"เช่น 30.10";
   tf.text=[NSString stringWithFormat:@"%.2f",obd.fuelPricePerLiter];
  }];
  [ac addAction:[UIAlertAction actionWithTitle:@"ยกเลิก" style:UIAlertActionStyleCancel handler:nil]];
  [ac addAction:[UIAlertAction actionWithTitle:@"บันทึก" style:UIAlertActionStyleDefault handler:^(UIAlertAction *ok){
   NSString *txt=[ac.textFields.firstObject.text stringByReplacingOccurrencesOfString:@"," withString:@"."];
   double val=[txt doubleValue];
   if(val>=10.0 && val<=120.0){
    [obd setCustomFuelPrice:(CGFloat)val];
    [self syncActiveFuelRateToTripA];
   }
   [self openFuelPriceSettings];
  }]];
  [self presentViewController:ac animated:YES completion:nil];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"➕ เพิ่มราคา +0.10 ฿  →  %.2f ฿/L",obd.fuelPricePerLiter+0.10] style:0 handler:^(TRDSettingAction *a){
  [obd setCustomFuelPrice:obd.fuelPricePerLiter+0.10];
  [self syncActiveFuelRateToTripA];
  [self openFuelPriceSettings];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"➖ ลดราคา -0.10 ฿  →  %.2f ฿/L",obd.fuelPricePerLiter-0.10] style:0 handler:^(TRDSettingAction *a){
  [obd setCustomFuelPrice:obd.fuelPricePerLiter-0.10];
  [self syncActiveFuelRateToTripA];
  [self openFuelPriceSettings];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"➕ เพิ่มราคา +0.50 ฿  →  %.2f ฿/L",obd.fuelPricePerLiter+0.50] style:0 handler:^(TRDSettingAction *a){
  [obd setCustomFuelPrice:obd.fuelPricePerLiter+0.50];
  [self syncActiveFuelRateToTripA];
  [self openFuelPriceSettings];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"➖ ลดราคา -0.50 ฿  →  %.2f ฿/L",obd.fuelPricePerLiter-0.50] style:0 handler:^(TRDSettingAction *a){
  [obd setCustomFuelPrice:obd.fuelPricePerLiter-0.50];
  [self syncActiveFuelRateToTripA];
  [self openFuelPriceSettings];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🔄 ดึงราคาสดออนไลน์ (บางจาก / คาลเท็กซ์)" style:0 handler:^(TRDSettingAction *a){
  [obd fetchLiveOilPricesForce:YES];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   [self syncActiveFuelRateToTripA];
   [self openFuelPriceSettings];
  });
 }]];
 NSArray *names=@[@"แก๊สโซฮอล์ 95",@"แก๊สโซฮอล์ 91",@"แก๊สโซฮอล์ E20",@"พรีเมียม 95"];
 for(int i=0;i<4;i++){
  NSNumber *p=obd.cachedPrices[@(i)];
  double price=p?[p doubleValue]:0;
  NSString *check=(i==obd.selectedFuelTypeIndex)?@"✓  ":@"    ";
  NSString *title=[NSString stringWithFormat:@"%@⛽ %@ (%.2f ฿/L)",check,names[i],price];
  [m addAction:[TRDSettingAction actionWithTitle:title style:0 handler:^(TRDSettingAction *a){
   [obd selectFuelTypeIndex:i];
   [self syncActiveFuelRateToTripA];
   [self openFuelPriceSettings];
  }]];
 }
 [m addAction:[TRDSettingAction actionWithTitle:@"🚨 ทดสอบแจ้งเตือนน้ำมันใกล้หมด + ค้นหาปั๊ม (Demo)" style:0 handler:^(TRDSettingAction *a){
  [self.settingsSheet dismiss];
  [self testLowFuelWarning];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"🔄 Reset Trip A Fuel Counter" style:0 handler:^(TRDSettingAction *a){
  [self resetTripSlot:0];
  [self syncActiveFuelRateToTripA];
  [self openFuelPriceSettings];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"🔄 เชื่อมต่อ OBD2 ใหม่ (%@)",obd.connectionStatus] style:0 handler:^(TRDSettingAction *a){
  [obd forceReconnect];
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
 [self applyGearToUI:obd.currentGear];
 if(obd.isReverseGear){
  [self handleReverseEngaged];
 }else{
  [self handleReverseDisengaged];
  // If already on camera Wi-Fi (192.168.169.x), pre-warm rear stream in standby without touching Hotspot or OBD2
  NSDictionary *netState=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/network-state.plist"];
  NSString *ip=[netState[@"address"] isKindOfClass:[NSString class]]?netState[@"address"]:@"";
  if([ip hasPrefix:@"192.168.169."]){
   notify_post("com.codex.h109.prewarm");
  }
 }
}

-(void)handleReverseEngaged{
 if(self.isReverseActive)return;
 self.isReverseActive=YES;
 [[TRDFrontGestureEngine sharedEngine] stop];
 if(!self.mapMode && !self.carplayMode && self.mapWebView){[self teardownMapWebView];}
 [[NSURLCache sharedURLCache] removeAllCachedResponses];
 [self prepareForExternalAppLaunch];
 [@{@"rear": @YES, @"at": [NSDate date], @"fast": @YES} writeToFile:@"/var/mobile/codex-car/reverse-camera.plist" atomically:YES];
 notify_post("com.codex.trd.network.camera");
 notify_post("com.codex.h109.reverse.show");
 [self launchBundleApp:@"com.codex.h109viewer"];
 self.pausedMusicForReverse=NO;
 self.reverseAudioSource=0;
 self.reverseResumeRadioURL=nil;
 self.reverseResumeRadioName=nil;
 NSUInteger revGen=++self.reverseAudioGen;
 if(self.radioPlayer){
  BOOL activelyPlaying=(self.radioPlayer.rate>0.05 ||
                        (![self.song.text hasPrefix:@"[PAUSED]"] && (self.offlinePlaybackActive || self.currentRadioStation.length>0) &&
                         self.radioPlayer.currentItem && self.radioPlayer.currentItem.status!=AVPlayerItemStatusFailed));
  if(activelyPlaying){
   self.pausedMusicForReverse=YES;
   self.reverseAudioSource=self.offlinePlaybackActive?1:2;
   self.reverseResumeRadioURL=self.currentRadioURL;
   self.reverseResumeRadioName=self.currentRadioStation;
   [self.radioPlayer pause];
   [[TRDOBDClient sharedClient] obdLog:@"REVERSE paused in-app audio (src=%ld)",(long)self.reverseAudioSource];
  }
  self.radioPlayer.volume=0.0f;
  [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
 }else{
  BOOL cachedPlaying=(self.mediaRate>0.05);
  if(cachedPlaying){
   self.pausedMusicForReverse=YES;
   self.reverseAudioSource=[self isYouTubeMediaActive]?3:4;
   if(self.reverseAudioSource==3){
    notify_post("com.codex.trd.youtube.pause");
   }else{
    notify_post("com.codex.trd.music.pause");
    TRDSendMediaRemoteExternal(1,nil);
   }
   [[TRDOBDClient sharedClient] obdLog:@"REVERSE paused external audio (src=%ld cachedRate=%.2f)",(long)self.reverseAudioSource,self.mediaRate];
  }else{
   // Backgrounded CarDash may have stale self.mediaRate == 0; query live MediaRemote rate + owner PID now.
   void (*mrInfo)(dispatch_queue_t,void (^)(CFDictionaryRef))=dlsym(RTLD_DEFAULT,"MRMediaRemoteGetNowPlayingInfo");
   void (*mrOwner)(dispatch_queue_t,void (^)(int))=dlsym(RTLD_DEFAULT,"MRMediaRemoteGetNowPlayingApplicationPID");
   BOOL otherAudio=[AVAudioSession sharedInstance].otherAudioPlaying;
   if(mrInfo){
    __weak typeof(self) weakSelf=self;
    mrInfo(dispatch_get_main_queue(),^(CFDictionaryRef raw){
     Dashboard *v=weakSelf;
     if(!v || v.reverseAudioGen!=revGen || !v.isReverseActive || v.pausedMusicForReverse)return;
     NSDictionary *info=[(__bridge id)raw isKindOfClass:[NSDictionary class]]?(__bridge id)raw:nil;
     double liveRate=[info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] respondsToSelector:@selector(doubleValue)]?[info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] doubleValue]:0.0;
     if(liveRate>0.05 || otherAudio){
      void (^applyPause)(NSInteger)=^(NSInteger detectedSrc){
       if(v.reverseAudioGen!=revGen || !v.isReverseActive || v.pausedMusicForReverse)return;
       v.pausedMusicForReverse=YES;
       v.reverseAudioSource=detectedSrc;
       if(detectedSrc==3){
        notify_post("com.codex.trd.youtube.pause");
       }else{
        notify_post("com.codex.trd.music.pause");
        TRDSendMediaRemoteExternal(1,nil);
       }
       [[TRDOBDClient sharedClient] obdLog:@"REVERSE paused live external audio (src=%ld liveRate=%.2f other=%d)",(long)detectedSrc,liveRate,otherAudio?1:0];
      };
      if(mrOwner){
       mrOwner(dispatch_get_main_queue(),^(int pid){
        NSInteger detectedSrc=[v isYouTubeMediaActive]?3:4;
        if(pid>0 && pid!=getpid()){
         int (*pathfn)(int,void *,uint32_t)=dlsym(RTLD_DEFAULT,"proc_pidpath");
         char path[4096];path[0]=0;
         if(pathfn && pathfn(pid,path,sizeof(path))>0){
          NSString *proc=[[NSString stringWithUTF8String:path] lastPathComponent];
          if([proc isEqualToString:@"YTNine"])detectedSrc=3;
          else if([proc isEqualToString:@"LegacyMusic"])detectedSrc=4;
         }
        }
        applyPause(detectedSrc);
       });
      }else{
       applyPause([v isYouTubeMediaActive]?3:4);
      }
     }
    });
   }
  }
 }
 [self.reverseBeepTimer invalidate];
 self.reverseBeepTimer=[NSTimer scheduledTimerWithTimeInterval:0.85 target:self selector:@selector(playReverseBeep) userInfo:nil repeats:YES];
 [self playReverseBeep];
}

-(void)resumeAudioAfterReverseWithGen:(NSUInteger)gen srcKind:(NSInteger)srcKind attempt:(NSInteger)attempt{
 if(gen!=self.reverseAudioGen || self.isReverseActive || srcKind<=0)return;
 if(srcKind==1 || srcKind==2){
  if(!self.radioPlayer){
   if(srcKind==2 && self.reverseResumeRadioURL.length && attempt>=1){
    [self playRadio:self.reverseResumeRadioURL name:self.reverseResumeRadioName?:@"Live Radio"];
   }
   return;
  }
  AVAudioSession *sess=[AVAudioSession sharedInstance];
  [sess setCategory:AVAudioSessionCategoryPlayback error:nil];
  [sess setActive:YES error:nil];
  self.radioPlayer.volume=1.0f;
  AVPlayerItemStatus st=self.radioPlayer.currentItem?self.radioPlayer.currentItem.status:AVPlayerItemStatusUnknown;
  if(srcKind==2 && (st==AVPlayerItemStatusFailed || (attempt>=1 && self.radioPlayer.rate<=0.05)) && self.reverseResumeRadioURL.length){
   [[TRDOBDClient sharedClient] obdLog:@"REVERSE restarting radio stream (attempt=%ld status=%ld)",(long)attempt,(long)st];
   [self playRadio:self.reverseResumeRadioURL name:self.reverseResumeRadioName?:@"Live Radio"];
  }else if(self.radioPlayer.rate<=0.05){
   [self.radioPlayer play];
   [[TRDOBDClient sharedClient] obdLog:@"REVERSE resumed in-app audio (src=%ld rate=%.2f attempt=%ld)",(long)srcKind,self.radioPlayer.rate,(long)attempt];
  }
  [self refreshNowPlaying];
  [self refreshTransportState];
  [self refreshMini];
  if(attempt<3){
   NSTimeInterval waitSec=(srcKind==2)?2.0:1.1;
   __weak typeof(self) weakSelf=self;
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(waitSec*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
    Dashboard *v=weakSelf;
    if(!v || v.reverseAudioGen!=gen || v.isReverseActive)return;
    if(!v.radioPlayer || v.radioPlayer.rate<=0.05 || (v.radioPlayer.currentItem && v.radioPlayer.currentItem.status==AVPlayerItemStatusFailed)){
     [v resumeAudioAfterReverseWithGen:gen srcKind:srcKind attempt:attempt+1];
    }
   });
  }
  return;
 }

 // External app (3=YouTube, 4=audioNINJA/MediaRemote): release CarDash audio session focus cleanly first
 [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
 if(attempt==0){
  if(srcKind==3){
   notify_post("com.codex.trd.youtube.play");
  }else{
   notify_post("com.codex.trd.music.play");
   TRDSendMediaRemoteExternal(0,nil);
  }
  [[TRDOBDClient sharedClient] obdLog:@"REVERSE resume posted (src=%ld attempt=0)",(long)srcKind];
 }
 if(attempt<3){
  NSTimeInterval delay=(attempt==0)?1.4:1.8;
  __weak typeof(self) weakSelf=self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   Dashboard *v=weakSelf;
   if(!v || v.reverseAudioGen!=gen || v.isReverseActive)return;
   void (*mrInfo)(dispatch_queue_t,void (^)(CFDictionaryRef))=dlsym(RTLD_DEFAULT,"MRMediaRemoteGetNowPlayingInfo");
   if(!mrInfo){
    return;
   }
   mrInfo(dispatch_get_main_queue(),^(CFDictionaryRef raw){
    if(v.reverseAudioGen!=gen || v.isReverseActive)return;
    NSDictionary *info=[(__bridge id)raw isKindOfClass:[NSDictionary class]]?(__bridge id)raw:nil;
    double rate=[info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] respondsToSelector:@selector(doubleValue)]?[info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] doubleValue]:0.0;
    if(rate<=0.05){
     if(srcKind==3){
      notify_post("com.codex.trd.youtube.play");
     }else{
      notify_post("com.codex.trd.music.play");
      TRDSendMediaRemoteExternal(0,nil);
     }
     [[TRDOBDClient sharedClient] obdLog:@"REVERSE retry resume (src=%ld attempt=%ld rate=%.2f)",(long)srcKind,(long)(attempt+1),rate];
     [v resumeAudioAfterReverseWithGen:gen srcKind:srcKind attempt:attempt+1];
    }
   });
  });
 }
}

-(void)handleReverseDisengaged{
 if(!self.isReverseActive)return;
 self.isReverseActive=NO;
 [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/codex-car/reverse-camera.plist" error:nil];
 [self.reverseBeepTimer invalidate];
 self.reverseBeepTimer=nil;
 if(self.radioPlayer){
  self.radioPlayer.volume=1.0f;
 }else if(self.ownsSpeechAudioSession){
  self.ownsSpeechAudioSession=NO;
  [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
 }
 NSUInteger rGen=++self.reverseAudioGen;
 BOOL shouldResume=self.pausedMusicForReverse;
 NSInteger srcKind=self.reverseAudioSource;
 self.pausedMusicForReverse=NO;
 if(srcKind<=0 && shouldResume){
  srcKind=self.radioPlayer?(self.offlinePlaybackActive?1:2):([self isYouTubeMediaActive]?3:4);
 }
 notify_post("com.codex.trd.network.internet.force");
 [self homePage];
 [self launchBundleApp:@"com.codex.cardash"];
 [[TRDFrontGestureEngine sharedEngine] startIfEnabled];
 if(shouldResume && srcKind>0){
  __weak typeof(self) weakSelf=self;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.18*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   [weakSelf resumeAudioAfterReverseWithGen:rGen srcKind:srcKind attempt:0];
  });
 }
}

-(void)playReverseBeep{
 AudioServicesPlaySystemSound(1057);
}

-(void)topAuxPillTapped{
 if(self.driveMode)[self openHybridDiagnosticsMenu];
 else [self voiceLanguageSettings];
}

-(void)updateDrive12VPill{
 if(!self.driveMode || !self.thaiVoicePill || self.thaiVoicePill.hidden) return;
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 double v12 = obd.auxBatteryVoltage;
 NSString *title = [NSString stringWithFormat:@"🔋 12V: %.2fV", v12];
 if(![self.thaiVoicePill.currentTitle isEqualToString:title]){
  [self.thaiVoicePill setTitle:title forState:UIControlStateNormal];
 }
 NSInteger band = (v12 > 0.5 && v12 < 12.1) ? 0 : (v12 >= 13.4 ? 2 : 1);
 if(self.thaiVoicePill.tag != 900 + band){
  self.thaiVoicePill.tag = 900 + band;
  UIColor *fg = (band == 0) ? [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0]
                            : ((band == 2) ? [UIColor colorWithRed:0.30 green:0.98 blue:0.58 alpha:1.0]
                                           : [UIColor colorWithRed:0.0 green:0.90 blue:1.0 alpha:1.0]);
  [self.thaiVoicePill setTitleColor:fg forState:UIControlStateNormal];
  self.thaiVoicePill.layer.borderColor = [fg colorWithAlphaComponent:0.55].CGColor;
 }
}

-(void)refreshCarPlayTelemetryWidget:(TRDOBDClient *)obd{
 if(!self.carplayTelemetryWidget || !self.carplayMode || self.carplayGridMode) return;
 if(self.carplayTelemetryWidget.batteryStatusLabel){
  NSString *batTxt = [NSString stringWithFormat:@"%.0f%% (EV READY)", obd.hybridBatterySOC];
  if(![self.carplayTelemetryWidget.batteryStatusLabel.text isEqualToString:batTxt])
   self.carplayTelemetryWidget.batteryStatusLabel.text = batTxt;
 }
 if(self.carplayTelemetryWidget.thermalsRowLabel){
  NSString *openDoors = TRDOpenDoorsSummary(obd.doorSensorsLive, obd.doorFrontLeftOpen, obd.doorFrontRightOpen, obd.doorRearLeftOpen, obd.doorRearRightOpen, obd.trunkOpen);
  NSString *thmTxt = (openDoors.length > 0)
   ? [NSString stringWithFormat:@"🚨 ประตูเปิด: %@ • 12V: %.2fV", openDoors, obd.auxBatteryVoltage]
   : [NSString stringWithFormat:@"Coolant: %.0f°C • INV: %.0f°C • 12V: %.2fV", obd.coolantTempC, obd.inverterTempC, obd.auxBatteryVoltage];
  self.carplayTelemetryWidget.thermalsRowLabel.textColor = (openDoors.length > 0)
   ? [UIColor colorWithRed:1.0 green:0.42 blue:0.42 alpha:1.0]
   : [UIColor colorWithWhite:0.86 alpha:1.0];
  if(![self.carplayTelemetryWidget.thermalsRowLabel.text isEqualToString:thmTxt])
   self.carplayTelemetryWidget.thermalsRowLabel.text = thmTxt;
 }
 if(self.carplayTelemetryWidget.batteryBarTrack && self.carplayTelemetryWidget.batteryBarFill){
  CGFloat cpPct = MAX(0.0, MIN(1.0, obd.hybridBatterySOC / 100.0));
  CGRect tf = self.carplayTelemetryWidget.batteryBarTrack.bounds;
  CGRect targetFrame = CGRectMake(0, 0, tf.size.width * cpPct, tf.size.height);
  if(!CGRectEqualToRect(self.carplayTelemetryWidget.batteryBarFill.frame, targetFrame))
   self.carplayTelemetryWidget.batteryBarFill.frame = targetFrame;
 }
}

 -(void)cycleHomeWidgetMode{
 NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
 NSInteger cur = ([ud integerForKey:@"TRDHomeWidgetMode"] + 1) % 3;
 [ud setInteger:cur forKey:@"TRDHomeWidgetMode"];
 [ud synchronize];
 [self refreshLiveOBDDashboard];
}
-(void)cycleDriveWidgetMode{
 NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
 NSInteger cur = ([ud integerForKey:@"TRDDriveWidgetMode"] + 1) % 3;
 [ud setInteger:cur forKey:@"TRDDriveWidgetMode"];
 [ud synchronize];
 [self refreshLiveOBDDashboard];
}
-(void)showGestureToast:(NSString *)msg{
 UIView *hud = [self ensureVoiceHudPopup];
 UILabel *lbl = (UILabel *)[hud viewWithTag:956];
 if(lbl) lbl.text = msg;
 hud.hidden = NO;
 hud.alpha = 1.0;
 [[hud superview] bringSubviewToFront:hud];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
  if(lbl && [lbl.text isEqualToString:msg]){
   hud.hidden = YES;
  }
 });
}
-(void)voiceMusicTapped{
 if(!self.voiceListening){
  [self toggleVoiceCommand];
 }
}
-(void)refreshLiveOBDDashboard{
 TRDOBDClient *obd=[TRDOBDClient sharedClient];
 if(self.carplayMode || self.mapMode || self.focused){
  if(self.carplayMode)[self refreshCarPlayTelemetryWidget:obd];
  if(self.mapMode && self.obdStatusPill){
   NSString *obdT = obd.isConnected ? @"OBD2 LIVE" : @"OBD2 SCAN";
   UIColor *obdTint = obd.isConnected ? [UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] : [UIColor colorWithRed:1.0 green:0.78 blue:0.30 alpha:1.0];
   if(![[self.obdStatusPill titleForState:UIControlStateNormal] isEqualToString:obdT]){
    [self.obdStatusPill setImage:TRDAutoVectorIcon(1, 16.0, obdTint) forState:UIControlStateNormal];
    self.obdStatusPill.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 6);
    [self.obdStatusPill setTitle:obdT forState:UIControlStateNormal];
    [self.obdStatusPill setTitleColor:obdTint forState:UIControlStateNormal];
    self.obdStatusPill.backgroundColor = obd.isConnected
     ? [UIColor colorWithRed:0.04 green:0.22 blue:0.12 alpha:0.95]
     : [UIColor colorWithRed:0.14 green:0.09 blue:0.04 alpha:0.95];
   }
  }
  return;
 }
 [self applyGearToUI:obd.currentGear];
 [self updateDrive12VPill];

 // 1. Lightweight Door-Ajar Moving Safety Alert (chimes via car BT/AUX or iPad speaker ONLY when in D/R or >=5 km/h)
 {
  BOOL anyDoorOpen = obd.doorSensorsLive && (obd.doorFrontLeftOpen || obd.doorFrontRightOpen || obd.doorRearLeftOpen || obd.doorRearRightOpen || obd.trunkOpen);
  double spdNow = obd.isConnected ? obd.currentSpeedKmh : ((self.fix && self.fix.speed >= 0) ? self.fix.speed * 3.6 : 0.0);
  BOOL inDriveOrMoving = (spdNow >= 5.0) || [obd.currentGear isEqualToString:@"D"] || [obd.currentGear isEqualToString:@"R"];
  static NSTimeInterval sLastDoorChimeAt = 0;
  NSTimeInterval nowUpD = [NSProcessInfo processInfo].systemUptime;
  if(anyDoorOpen && inDriveOrMoving && (nowUpD - sLastDoorChimeAt) >= 6.0){
   sLastDoorChimeAt = nowUpD;
   AudioServicesPlaySystemSound(1052);
  }
 }

 // 2. Lightweight Coffee-Break Attention Reminder (2h continuous driving, 0% extra CPU)
 {
  static double sNextBreakSec = 7200.0;
  double tripSec = self.trip ? self.trip.seconds : 0.0;
  double spdNowB = obd.isConnected ? obd.currentSpeedKmh : ((self.fix && self.fix.speed >= 0) ? self.fix.speed * 3.6 : 0.0);
  if(tripSec < 60.0){
   sNextBreakSec = 7200.0;
  } else if(tripSec >= sNextBreakSec && spdNowB >= 10.0){
   NSInteger hrs = (NSInteger)(sNextBreakSec / 3600.0);
   sNextBreakSec += 7200.0;
   AudioServicesPlaySystemSound(1008);
   UILabel *toast = (UILabel *)[self.view viewWithTag:945];
   if(!toast){
    toast = [[UILabel alloc]initWithFrame:CGRectMake((self.view.bounds.size.width - 420.0) * 0.5, 58.0, 420.0, 36.0)];
    toast.tag = 945;
    toast.backgroundColor = [UIColor colorWithRed:0.12 green:0.08 blue:0.02 alpha:0.94];
    toast.layer.cornerRadius = 18.0;
    toast.clipsToBounds = YES;
    toast.layer.borderWidth = 1.4;
    toast.layer.borderColor = [UIColor colorWithRed:1.0 green:0.75 blue:0.20 alpha:0.90].CGColor;
    toast.textColor = [UIColor colorWithRed:1.0 green:0.92 blue:0.65 alpha:1.0];
    toast.font = [UIFont boldSystemFontOfSize:13.5];
    toast.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:toast];
   }
   toast.text = [NSString stringWithFormat:@"☕ ขับต่อเนื่องครบ %ld ชม. แล้ว — แนะนำแวะพักสายตา", (long)hrs];
   toast.hidden = NO;
   toast.alpha = 1.0;
   [self.view bringSubviewToFront:toast];
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    UIView *t = [self.view viewWithTag:945];
    if(t) t.hidden = YES;
   });
  }
 }

 // Update Top-Bar Connectivity Status Pill (Wi-Fi/Hotspot + Bluetooth/Audio Output) + Auto-refresh live oil prices when online
 UIButton *connPill = (UIButton *)[self.view viewWithTag:910];
 if(connPill){
  NSString *wifi = (self.statusWiFi.length && ![self.statusWiFi isEqualToString:@"NO NETWORK"]) ? self.statusWiFi : nil;
  if(!wifi){
   static NSString *sBrokerSSID = nil;
   static NSTimeInterval sBrokerReadAt = 0;
   NSTimeInterval nowUpR = [NSProcessInfo processInfo].systemUptime;
   if(sBrokerReadAt == 0 || (nowUpR - sBrokerReadAt) >= 2.0){
    sBrokerReadAt = nowUpR;
    NSDictionary *nst = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/network-state.plist"];
    NSString *act = [nst[@"actualSSID"] isKindOfClass:[NSString class]] ? nst[@"actualSSID"] : nil;
    NSString *adr = [nst[@"address"] isKindOfClass:[NSString class]] ? nst[@"address"] : nil;
    sBrokerSSID = (act.length && adr.length) ? act : nil;
   }
   wifi = sBrokerSSID;
  }
  BOOL isCamWifi = (wifi && ([wifi localizedCaseInsensitiveContainsString:@"H109"] || [wifi localizedCaseInsensitiveContainsString:@"H108"]));
  NSString *wifiShort = wifi ? (wifi.length > 10 ? [wifi substringToIndex:10] : wifi) : @"NO WIFI";
  NSString *audioShort = self.audioOutputShort.length ? self.audioOutputShort : @"SPEAKER";
  NSString *btPrefix = ([audioShort isEqualToString:@"CAR BT"] || [audioShort isEqualToString:@"BLUETOOTH"]) ? @"🎧" : @"🔊";
  NSString *connTitle = [NSString stringWithFormat:@"📶 %@ • %@ %@", wifiShort, btPrefix, audioShort];
  if(![[connPill titleForState:UIControlStateNormal] isEqualToString:connTitle]){
   [connPill setTitle:connTitle forState:UIControlStateNormal];
   UIColor *tint = !wifi
    ? [UIColor colorWithRed:1.0 green:0.55 blue:0.30 alpha:1.0]
    : (isCamWifi ? [UIColor colorWithRed:0.25 green:0.90 blue:1.0 alpha:1.0]
                 : [UIColor colorWithRed:0.28 green:0.98 blue:0.60 alpha:1.0]);
   [connPill setTitleColor:tint forState:UIControlStateNormal];
   connPill.layer.borderColor = [tint colorWithAlphaComponent:0.45].CGColor;
  }
  // Auto-refresh live PTT/BCP oil price every 6 hours whenever online
  static NSTimeInterval sLastOilFetchAt = 0;
  NSTimeInterval nowUp = [NSProcessInfo processInfo].systemUptime;
  if(wifi && !isCamWifi && (sLastOilFetchAt == 0 || (nowUp - sLastOilFetchAt) > 21600.0)){
   sLastOilFetchAt = nowUp;
   [obd fetchLiveOilPrices];
  }
 }

 // Top OBD status pill
 if(self.obdStatusPill){
  NSString *obdT = obd.isConnected ? @"OBD2 LIVE" : @"OBD2 SCAN";
  UIColor *obdTint = obd.isConnected ? [UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1.0] : [UIColor colorWithRed:1.0 green:0.78 blue:0.30 alpha:1.0];
  if(![[self.obdStatusPill titleForState:UIControlStateNormal] isEqualToString:obdT]){
   [self.obdStatusPill setImage:TRDAutoVectorIcon(1, 16.0, obdTint) forState:UIControlStateNormal];
   self.obdStatusPill.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 6);
   [self.obdStatusPill setTitle:obdT forState:UIControlStateNormal];
   [self.obdStatusPill setTitleColor:obdTint forState:UIControlStateNormal];
   self.obdStatusPill.backgroundColor = obd.isConnected
    ? [UIColor colorWithRed:0.04 green:0.22 blue:0.12 alpha:0.95]
    : [UIColor colorWithRed:0.14 green:0.09 blue:0.04 alpha:0.95];
  }
 }

 // Left Card 2: Multi-Mode Tap-to-Switch Cockpit Widget (0=AI Eco, 1=Thermal/A7 Guard, 2=Quick Shortcuts)
 if(self.homeAiEcoCard){
  NSInteger wMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"TRDHomeWidgetMode"] % 3;
  UILabel *ecoH = (UILabel *)[self.homeAiEcoCard viewWithTag:501];
  UILabel *ecoS = (UILabel *)[self.homeAiEcoCard viewWithTag:502];
  UILabel *ecoD = (UILabel *)[self.homeAiEcoCard viewWithTag:503];
  for(int qi=0; qi<3; qi++){
   UIView *qb = [self.homeAiEcoCard viewWithTag:510 + qi];
   if(qb) qb.hidden = (wMode != 2);
  }
  if(ecoS) ecoS.hidden = (wMode == 2);
  if(ecoD) ecoD.hidden = (wMode == 2);
  if(wMode == 0){
   NSInteger ecoVal = self.ecoScore > 0 ? self.ecoScore : 96;
   NSString *grade = (ecoVal >= 90) ? @"A+" : (ecoVal >= 80) ? @"A" : (ecoVal >= 70) ? @"B" : @"C";
   if(ecoH){
    ecoH.textColor = [UIColor colorWithRed:.35 green:.95 blue:.50 alpha:1];
    NSString *t = (obd.regenBrakingPowerKW > 0.2)
     ? [NSString stringWithFormat:@"🌱 AI ECO COACH ▾ • +%.1fkW", obd.regenBrakingPowerKW]
     : [NSString stringWithFormat:@"🌱 AI ECO COACH ▾ • %@", (obd.engineRPM > 100 ? @"HYBRID" : @"EV")];
    if(![ecoH.text isEqualToString:t]) ecoH.text = t;
   }
   if(ecoS){
    NSString *t = [NSString stringWithFormat:@"ECO %ld / 100  [ GRADE %@ ]", (long)ecoVal, grade];
    if(![ecoS.text isEqualToString:t]) ecoS.text = t;
   }
   if(ecoD){
    NSString *thrState = (obd.engineRPM > 1850) ? @"เร่งแรง (POWER)" : (obd.engineRPM > 100) ? @"กำลังขับปกติ (Hybrid)" : @"โหมดไฟฟ้าเงียบ (EV)";
    NSString *regState = (obd.hvPackCurrent < -0.5) ? [NSString stringWithFormat:@"ชาร์จคืนแบต %.1f kW", obd.regenBrakingPowerKW] : @"พร้อมปั่นไฟชะลอ";
    NSString *brkState = obd.brakeFluidNormal ? @"แรงดันเบรกปกติ" : @"⚠️ ตรวจเช็กระบบเบรก";
    NSString *t = [NSString stringWithFormat:@"• HYBRID: %@\n• THROTTLE: %@\n• REGEN: %@\n• แตะการ์ดเพื่อสลับ Widget ▸", obd.isConnected ? @"LIVE OBD2" : @"STANDBY", thrState, regState];
    (void)brkState;
    if(![ecoD.text isEqualToString:t]) ecoD.text = t;
   }
  } else if(wMode == 1){
   NSString *a7State = @"ปกติ (เย็น)";
   if([[NSProcessInfo processInfo] respondsToSelector:@selector(thermalState)]){
    NSProcessInfoThermalState ts = [[NSProcessInfo processInfo] thermalState];
    if(ts >= NSProcessInfoThermalStateSerious) a7State = @"🔥 ร้อน (Eco 8FPS)";
    else if(ts == NSProcessInfoThermalStateFair) a7State = @"🌤️ อุ่น (Eco 8FPS)";
   }
   if(ecoH){
    ecoH.textColor = [UIColor colorWithRed:0.25 green:0.92 blue:1.0 alpha:1];
    NSString *t = @"🌡️ THERMAL & A7 GUARD ▾";
    if(![ecoH.text isEqualToString:t]) ecoH.text = t;
   }
   if(ecoS){
    NSString *t = [NSString stringWithFormat:@"ECT %.0f°C  •  INV %.0f°C", obd.coolantTempC, obd.inverterTempC];
    if(![ecoS.text isEqualToString:t]) ecoS.text = t;
   }
   if(ecoD){
    NSString *t = [NSString stringWithFormat:@"• แบต HV: %.1f°C (พัดลมดูด %.0f°C)\n• มอเตอร์ MG2: %.0f°C • 12V: %.2fV\n• ชิป A7: %@\n• แตะการ์ดเพื่อสลับ Widget ▸", obd.hvBatteryTempC, obd.hvIntakeTempC, obd.mg2TempC, obd.auxBatteryVoltage, a7State];
    if(![ecoD.text isEqualToString:t]) ecoD.text = t;
   }
  } else {
   if(ecoH){
    ecoH.textColor = [UIColor colorWithRed:1.0 green:0.82 blue:0.28 alpha:1];
    NSString *t = @"⚡ ทางลัดด่วน (แตะหัวข้อสลับ) ▾";
    if(![ecoH.text isEqualToString:t]) ecoH.text = t;
   }
  }
 }
 if(self.drivePowerMeter && self.drivePowerMeter.coachPill){
  NSInteger ecoVal = self.ecoScore > 0 ? self.ecoScore : 96;
  NSString *grade = (ecoVal >= 90) ? @"A+" : (ecoVal >= 80) ? @"A" : (ecoVal >= 70) ? @"B" : @"C";
  UILabel *cl = (UILabel *)[self.drivePowerMeter.coachPill viewWithTag:201];
  NSString *t = [NSString stringWithFormat:@"ECO  AI ECO COACH: %ld %@", (long)ecoVal, grade];
  if(cl && ![cl.text isEqualToString:t]) cl.text = t;
 }

 // Left Card 3: Thermals & 12V (homeThermalsCard)
 if(self.homeThermalsCard){
  UILabel *tRow1 = (UILabel *)[self.homeThermalsCard viewWithTag:601];
  UILabel *tRow2 = (UILabel *)[self.homeThermalsCard viewWithTag:602];
  UILabel *tRow3 = (UILabel *)[self.homeThermalsCard viewWithTag:603];
  if(tRow1){
   NSString *ectStatus = (obd.coolantTempC >= 98.0) ? @"สูง" : (obd.coolantTempC >= 40.0) ? @"ปกติ" : @"อุ่นเครื่อง";
   NSString *t = [NSString stringWithFormat:@"🌡️ ENGINE COOLANT : %.0f °C\n     น้ำหล่อเย็น (%@) • RPM %ld", obd.coolantTempC, ectStatus, (long)obd.engineRPM];
   if(![tRow1.text isEqualToString:t]) tRow1.text = t;
  }
  if(tRow2){
   NSString *t = [NSString stringWithFormat:@"❄️ CABIN A/C : %.1f°C • EXT %.0f°C\n     INV : %.0f°C • HV AIR %.1f°C", obd.cabinTempC, obd.exteriorTempC, obd.inverterTempC, obd.hvIntakeTempC];
   if(![tRow2.text isEqualToString:t]) tRow2.text = t;
  }
  if(tRow3){
   NSString *auxMsg = (obd.auxBatteryVoltage >= 13.4) ? @"ระบบ DC-DC ชาร์จไฟ 12V ปกติ" : (obd.auxBatteryVoltage >= 12.1) ? @"ไฟ 12V สแตนด์บายปกติ" : @"⚠️ แบตเตอรี่ 12V ต่ำ";
   NSString *t = [NSString stringWithFormat:@"🔋 AUX 12V BATTERY : %.2f V\n     %@", obd.auxBatteryVoltage, auxMsg];
   if(![tRow3.text isEqualToString:t]) tRow3.text = t;
  }
 }

 // Center Card: EV Flow, Motors, HV Pack, kW
 double hvKW = (obd.hvPackVoltage * obd.hvPackCurrent) / 1000.0;
 double liveAvgKmL = [self effectiveFuelKmPerL];
 double estRangeKm = [self estimatedRangeKmForFuelLiters:obd.fuelRemainingLiters];
 [self updateHeadlightBeamsUI:obd];
 if(self.energyFlowLabel){
  NSString *ef = nil;
  NSString *lightSuffix = (obd.headlightSensorsLive && (obd.tailLightsOn || obd.headlightsOn || obd.highBeamOn)) ? [NSString stringWithFormat:@" • 💡 %@", obd.lightStateLabel] : @"";
  if(!obd.isConnected){
   ef = [NSString stringWithFormat:@"🔍 %@  •  RPM %ld", obd.connectionStatus ?: @"Scanning", (long)obd.engineRPM];
  } else if(obd.engineRPM > 100){
   ef = [NSString stringWithFormat:@"🔥 ICE %ld RPM • ⛽ %.1f L (~%.0f กม.)%@", (long)obd.engineRPM, obd.fuelRemainingLiters, estRangeKm, lightSuffix];
  } else {
   ef = [NSString stringWithFormat:@"🍃 EV READY • ⛽ %.1f L (~%.0f กม.)%@", obd.fuelRemainingLiters, estRangeKm, lightSuffix];
  }
  if(![self.energyFlowLabel.text isEqualToString:ef]) self.energyFlowLabel.text = ef;
 }
 if(self.frontMotorBox){
  UILabel *fm2 = (UILabel *)[self.frontMotorBox viewWithTag:841];
  NSString *t = [NSString stringWithFormat:@"MG1 %ld / MG2 %ld RPM", (long)obd.mg1RPM, (long)obd.mg2RPM];
  if(fm2 && ![fm2.text isEqualToString:t]) fm2.text = t;
 }
 if(self.rearBatteryBox){
  UILabel *rb2 = (UILabel *)[self.rearBatteryBox viewWithTag:842];
  NSString *t = [NSString stringWithFormat:@"SOC %.1f%% • %.1f V🔋", obd.hybridBatterySOC, obd.hvPackVoltage];
  if(rb2 && ![rb2.text isEqualToString:t]) rb2.text = t;
 }
 if(self.compassLabel){
  NSInteger dMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"TRDDriveWidgetMode"] % 3;
  NSString *t = nil;
  if(dMode == 1){
   NSString *a7Tag = @"A7 ปกติ";
   if([[NSProcessInfo processInfo] respondsToSelector:@selector(thermalState)] && [[NSProcessInfo processInfo] thermalState] >= NSProcessInfoThermalStateFair) a7Tag = @"A7 Eco";
   t = [NSString stringWithFormat:@"🌡️ ECT %.0f°C • INV %.0f°C • HV %.1f°C • 12V %.2fV (%@) ▾", obd.coolantTempC, obd.inverterTempC, obd.hvBatteryTempC, obd.auxBatteryVoltage, a7Tag];
  } else if(dMode == 2){
   double tripCost = (obd.tripFuelCostTHB > 0.01) ? obd.tripFuelCostTHB : (obd.tripFuelUsedLiters * MAX(30.0, obd.fuelPricePerLiter));
   t = [NSString stringWithFormat:@"⛽ สิ้นเปลือง %.1f km/L • ทริปนี้ ฿%.1f • วิ่งได้อีก ~%.0f กม. ▾", liveAvgKmL, tripCost, estRangeKm];
  } else if(!self.driveMode){
   NSString *flowDir = (obd.hvPackCurrent < -0.5) ? @"ชาร์จไฟเข้า" : (obd.hvPackCurrent > 1.5) ? @"จ่ายไฟขับเคลื่อน" : @"สแตนด์บาย";
   t = [NSString stringWithFormat:@"⚡ HV PACK: %.1f V • %+.2f A • %@ (%.2f kW) ▾", obd.hvPackVoltage, obd.hvPackCurrent, flowDir, fabs(hvKW)];
  } else {
   NSString *engTag = (obd.engineRPM > 100) ? [NSString stringWithFormat:@"🔥 ICE %ld RPM", (long)obd.engineRPM] : @"🍃 EV";
   NSString *flowDir = (obd.hvPackCurrent < -0.5) ? @"♻️ ชาร์จ" : (obd.hvPackCurrent > 1.5) ? @"⚡ จ่ายไฟ" : @"สแตนด์บาย";
   t = [NSString stringWithFormat:@"%@ • HV %.1fV %+.1fA (%@ %.1fkW) ▾", engTag, obd.hvPackVoltage, obd.hvPackCurrent, flowDir, fabs(hvKW)];
  }
  if(![self.compassLabel.text isEqualToString:t]) self.compassLabel.text = t;
 }
 if(self.doorDiagramView){
  BOOL doorDirty = (self.doorDiagramView.doorsLive != obd.doorSensorsLive ||
                    self.doorDiagramView.flOpen != obd.doorFrontLeftOpen ||
                    self.doorDiagramView.frOpen != obd.doorFrontRightOpen ||
                    self.doorDiagramView.rlOpen != obd.doorRearLeftOpen ||
                    self.doorDiagramView.rrOpen != obd.doorRearRightOpen ||
                    self.doorDiagramView.trunkOpen != obd.trunkOpen);
  self.doorDiagramView.doorsLive = obd.doorSensorsLive;
  self.doorDiagramView.flOpen = obd.doorFrontLeftOpen;
  self.doorDiagramView.frOpen = obd.doorFrontRightOpen;
  self.doorDiagramView.rlOpen = obd.doorRearLeftOpen;
  self.doorDiagramView.rrOpen = obd.doorRearRightOpen;
  self.doorDiagramView.trunkOpen = obd.trunkOpen;
  if(doorDirty)[self.doorDiagramView setNeedsDisplay];
 }
 if(self.carStatus){
  NSString *openDoors = TRDOpenDoorsSummary(obd.doorSensorsLive, obd.doorFrontLeftOpen, obd.doorFrontRightOpen, obd.doorRearLeftOpen, obd.doorRearRightOpen, obd.trunkOpen);
  BOOL doorAlert = (openDoors.length > 0);
  BOOL lightsActive = (obd.headlightSensorsLive && (obd.tailLightsOn || obd.headlightsOn || obd.highBeamOn));
  NSString *lightTag = lightsActive ? [NSString stringWithFormat:@" • %@", obd.lightStateLabel ?: @"เปิดไฟ"] : @"";
  NSString *csText = nil;
  NSInteger styleTag = 0;
  if(doorAlert){
   csText = [NSString stringWithFormat:@"เปิด: %@ • เกียร์ %@ • %.2fV%@", openDoors, obd.currentGear ?: @"P", obd.auxBatteryVoltage, lightTag];
   styleTag = 1;
  } else if(self.driveMode){
   csText = [NSString stringWithFormat:@"OBD2 %@  •  ปิดครบ  •  %.1fL (~%.0f กม.)  •  %.0f°C%@", obd.isConnected ? @"LIVE" : @"SCAN", obd.fuelRemainingLiters, estRangeKm, obd.coolantTempC, lightTag];
   styleTag = 2;
  } else {
   csText = [NSString stringWithFormat:@"%@  •  เกียร์ %@  •  %.1f ลิตร (~%.0f กม. • %.1f km/L)%@", obd.isConnected ? @"OBD2 LIVE" : (obd.connectionStatus ?: @"รอเชื่อมต่อ"), obd.currentGear ?: @"P", obd.fuelRemainingLiters, estRangeKm, liveAvgKmL, lightTag];
   styleTag = self.nightMode ? 3 : 4;
  }
  static NSString *sLastCarStatusKey = nil;
  NSString *fullKey = [NSString stringWithFormat:@"%ld_%@", (long)styleTag, csText];
  BOOL missingVectors = (!self.carStatus.attributedText || [self.carStatus.attributedText.string rangeOfString:@"\uFFFC"].location == NSNotFound);
  if(![sLastCarStatusKey isEqualToString:fullKey] || missingVectors){
   sLastCarStatusKey = fullKey;
   if(!doorAlert){
    NSMutableAttributedString *att = [[NSMutableAttributedString alloc] init];
    UIFont *f = self.carStatus.font ?: [UIFont boldSystemFontOfSize:13.0];
    void (^addIcon)(NSInteger, UIColor *) = ^(NSInteger kind, UIColor *c){
     NSTextAttachment *ta = [[NSTextAttachment alloc] init];
     ta.image = TRDAutoVectorIcon(kind, 15.0, c);
     ta.bounds = CGRectMake(0, -3.0, 15.0, 15.0);
     [att appendAttributedString:[NSAttributedString attributedStringWithAttachment:ta]];
     [att appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:@{NSFontAttributeName:f}]];
    };
    UIColor *obdC = obd.isConnected ? [UIColor colorWithRed:0.25 green:0.98 blue:0.55 alpha:1] : [UIColor colorWithRed:1.0 green:0.78 blue:0.30 alpha:1];
    addIcon(1, obdC);
    [att appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"OBD2 %@  •  ", obd.isConnected ? @"LIVE" : @"SCAN"] attributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:obdC}]];
    addIcon(3, [UIColor colorWithRed:0.25 green:0.95 blue:0.58 alpha:1]);
    [att appendAttributedString:[[NSAttributedString alloc] initWithString:(self.driveMode ? @"ปิดครบ  •  " : @"ประตู 5 บาน  •  ") attributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor whiteColor]}]];
    addIcon(4, [UIColor colorWithRed:0.35 green:0.90 blue:1.0 alpha:1]);
    [att appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.1fL (~%.0f กม.)  •  ", obd.fuelRemainingLiters, estRangeKm] attributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor whiteColor]}]];
    addIcon(5, [UIColor colorWithRed:0.55 green:0.92 blue:1.0 alpha:1]);
    [att appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.0f°C%@", obd.coolantTempC, lightTag] attributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor whiteColor]}]];
    self.carStatus.attributedText = att;
   }else{
    NSMutableAttributedString *att = [[NSMutableAttributedString alloc] init];
    UIFont *f = self.carStatus.font ?: [UIFont boldSystemFontOfSize:13.0];
    NSTextAttachment *ta = [[NSTextAttachment alloc] init];
    ta.image = TRDAutoVectorIcon(3, 16.0, [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1]);
    ta.bounds = CGRectMake(0, -3.0, 16.0, 16.0);
    [att appendAttributedString:[NSAttributedString attributedStringWithAttachment:ta]];
    [att appendAttributedString:[[NSAttributedString alloc] initWithString:[@" " stringByAppendingString:csText] attributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor colorWithRed:1.0 green:0.88 blue:0.88 alpha:1.0]}]];
    self.carStatus.attributedText = att;
   }
  }
  if(self.carStatus.tag != styleTag){
   self.carStatus.tag = styleTag;
   if(styleTag == 1){
    self.carStatus.textColor = [UIColor colorWithRed:1.0 green:0.88 blue:0.88 alpha:1.0];
    self.carStatus.backgroundColor = [UIColor colorWithRed:0.30 green:0.04 blue:0.05 alpha:0.96];
    self.carStatus.layer.borderColor = [UIColor colorWithRed:1.0 green:0.30 blue:0.30 alpha:0.95].CGColor;
   }else if(styleTag == 2){
    self.carStatus.textColor = [UIColor whiteColor];
    self.carStatus.backgroundColor = [UIColor colorWithRed:0.03 green:0.06 blue:0.09 alpha:0.95];
    self.carStatus.layer.borderColor = [UIColor colorWithWhite:0.22 alpha:1].CGColor;
   }else{
    self.carStatus.textColor = [UIColor colorWithWhite:0.96 alpha:1];
    self.carStatus.backgroundColor = self.nightMode ? [UIColor colorWithRed:0.05 green:0.09 blue:0.15 alpha:0.90] : [UIColor colorWithWhite:0.08 alpha:0.85];
    self.carStatus.layer.borderColor = [UIColor colorWithRed:0.0 green:0.75 blue:1.0 alpha:0.30].CGColor;
   }
  }
 }

 // Right Card 1: Powertrain & HV Pack + 14 Blocks + Delta V
 UIView *pCard = [self.view viewWithTag:701];
 if(pCard){
  UILabel *pbLbl = (UILabel *)[pCard viewWithTag:703];
  if(pbLbl){
   NSString *socGrade = (obd.hybridBatterySOC >= 40.0 && obd.hybridBatterySOC <= 80.0) ? @"ปกติ" : @"ต้องเฝ้าระวัง";
   NSString *curSign = (obd.hvPackCurrent < 0) ? @"ชาร์จ" : @"โหลด";
   NSString *t = [NSString stringWithFormat:@"HV SOC: %.1f%% (%@)\nPACK: %.1f V • %@ %+.2f A\n14 BLOCKS (ΔSOC %.1f%%)",
                 obd.hybridBatterySOC, socGrade, obd.hvPackVoltage, curSign, obd.hvPackCurrent, obd.hvDeltaSOC];
   if(![pbLbl.text isEqualToString:t]) pbLbl.text = t;
  }
 }
 if(self.blockGraphView && obd.hvBlockVoltages.count == 14){
  if(![self.blockGraphView.voltages isEqualToArray:obd.hvBlockVoltages]){
   self.blockGraphView.voltages = obd.hvBlockVoltages;
   [self.blockGraphView setNeedsDisplay];
  }
 }
 UILabel *deltaL = (UILabel *)[self.view viewWithTag:706];
 if(deltaL){
  NSString *dt = nil;
  if(obd.hvBlockVoltages.count == 14 && obd.hvBlockMaxV > 0){
   CGFloat dv = obd.hvBlockMaxV - obd.hvBlockMinV;
   NSString *bal = (dv <= 0.25) ? @"สมดุลดี" : @"ควรเช็คเซลล์";
   dt = [NSString stringWithFormat:@"ΔV: %.2fV (%@) • %.2f–%.2fV", dv, bal, obd.hvBlockMinV, obd.hvBlockMaxV];
  } else {
   dt = obd.isConnected ? @"ΔV: กำลังอ่าน 14 Blocks (2181)..." : @"ΔV: รอเชื่อมต่อ vLinker MC+";
  }
  if(![deltaL.text isEqualToString:dt]) deltaL.text = dt;
 }

 // Right Card 2: Motors & HV Battery Temp
 UIView *mCard = [self.view viewWithTag:707];
 if(mCard){
  UILabel *mlLbl = (UILabel *)[mCard viewWithTag:708];
  if(mlLbl){
   NSString *t = [NSString stringWithFormat:@"⚙️ MOTOR MG2 : %ld RPM\n     อุณหภูมิ %.0f °C • รถ %.0f km/h\n⚡ GENERATOR MG1 : %ld RPM\n     อุณหภูมิ %.0f °C • ICE %ld RPM\n🌡️ HV BATTERY TEMP\n     %.1f °C • ลมดูด %.1f °C",
                 (long)obd.mg2RPM, obd.mg2TempC, obd.currentSpeedKmh,
                 (long)obd.mg1RPM, obd.mg1TempC, (long)obd.engineRPM,
                 obd.hvBatteryTempC, obd.hvIntakeTempC];
   if(![mlLbl.text isEqualToString:t]) mlLbl.text = t;
  }
 }

 // Drive Mode Cards
 if(self.driveClockCard){
  UILabel *cSub = (UILabel *)[self.driveClockCard viewWithTag:802];
  NSString *t = [NSString stringWithFormat:@"❄️ A/C %.1f°C • INV %.0f°C", obd.cabinTempC, obd.inverterTempC];
  if(cSub && ![cSub.text isEqualToString:t]) cSub.text = t;
 }
 if(self.driveBatteryCard){
  UIView *barBg = [self.driveBatteryCard viewWithTag:813];
  UIView *barFill = [barBg viewWithTag:814];
  if(barBg && barFill){
   CGFloat pct = MAX(0.0, MIN(1.0, obd.hybridBatterySOC / 100.0));
   CGRect targetFrame = CGRectMake(0, 0, barBg.bounds.size.width * pct, barBg.bounds.size.height);
   if(fabs(barFill.frame.size.width - targetFrame.size.width) > 0.5){
    barFill.frame = targetFrame;
   }
  }
  UILabel *bS = (UILabel *)[self.driveBatteryCard viewWithTag:812];
  if(bS){
   NSString *t = [NSString stringWithFormat:@"%.1f%% (HV BAT %.1f°C)\nแรงดัน: %.1f V  •  %+.2f A", obd.hybridBatterySOC, obd.hvBatteryTempC, obd.hvPackVoltage, obd.hvPackCurrent];
   if(![bS.text isEqualToString:t]) bS.text = t;
  }
 }
 [self refreshCarPlayTelemetryWidget:obd];
}

-(void)flushOBDDashboardUpdate{
 self.obdUIRefreshPending = NO;
 self.lastOBDUIRefreshAt = [NSProcessInfo processInfo].systemUptime;
 if(!self.carplayMode && !self.mapMode && !self.focused){
  [self refreshBrakeStatus];
  [self refreshDriveTripDisplay];
 }else{
  [self syncTripSlotsDelta:NO];
 }
 [self refreshHybridStatus];
 [self refreshLiveOBDDashboard];
 if(self.driveMode && !self.drivePowerMeter.hidden && [UIApplication sharedApplication].applicationState==UIApplicationStateActive){
  [self refreshSpeed];
 }
 [self checkLowFuelWarning];
}

-(void)obdDataUpdated:(NSNotification *)note{
 [self applyGearToUI:[TRDOBDClient sharedClient].currentGear];
 NSTimeInterval now = [NSProcessInfo processInfo].systemUptime;
 NSTimeInterval elapsed = now - self.lastOBDUIRefreshAt;
 if(elapsed >= 0.25){
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(flushOBDDashboardUpdate) object:nil];
  [self flushOBDDashboardUpdate];
 }else if(!self.obdUIRefreshPending){
  self.obdUIRefreshPending = YES;
  [self performSelector:@selector(flushOBDDashboardUpdate) withObject:nil afterDelay:(0.25 - elapsed)];
 }
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
@interface TRDWindow : UIWindow
@end
@implementation TRDWindow
-(void)sendEvent:(UIEvent *)event{
 @try{
  if(event.type==UIEventTypeTouches){
   UITouch *t=[[event allTouches] anyObject];
   if(t && t.phase!=UITouchPhaseMoved){
    CGPoint pt=[t locationInView:self];
    UIView *hit=[self hitTest:pt withEvent:event];
    UIViewController *rc=self.rootViewController;
    gTRDLastTouchInfo=[NSString stringWithFormat:@"p=%.0f,%.0f ph=%ld hit=%@ tv=%@ rc=%d",pt.x,pt.y,(long)t.phase,NSStringFromClass([hit class])?:@"nil",NSStringFromClass([t.view class])?:@"nil",rc?(int)rc.view.userInteractionEnabled:-1];
    if([rc isKindOfClass:[Dashboard class]]){
     Dashboard *d=(Dashboard *)rc;
     d.view.userInteractionEnabled=YES;
     self.userInteractionEnabled=YES;
     while([UIApplication sharedApplication].isIgnoringInteractionEvents)[[UIApplication sharedApplication] endIgnoringInteractionEvents];
     if(d.welcome&&d.welcome.alpha<0.05)[d hideWelcome];
     if(d.tripSummaryCard&&d.tripSummaryCard.alpha<0.05)[d hideTripSummary];
     if(d.lowFuelBanner&&d.lowFuelBanner.alpha<0.05)[d dismissLowFuelBanner];
     if(d.featureExplanationBanner&&(d.featureExplanationBanner.alpha<0.05||(gTRDFeatureBannerShownAt>0&&([NSProcessInfo processInfo].systemUptime-gTRDFeatureBannerShownAt)>9.0)))[d hideFeatureExplanation];
     if(d.settingsSheet&&!d.settingsSheet.superview)d.settingsSheet=nil;
     if(d.settingsSheet&&t.phase==UITouchPhaseEnded&&hit==d.settingsSheet&&!CGRectContainsPoint(d.settingsSheet.panel.frame,[self convertPoint:pt toView:d.settingsSheet]))[d.settingsSheet dismiss];
     [d ensureActiveRunLoopHealth];
    }
   }
  }
 }@catch(NSException *e){}
 [super sendEvent:event];
}
@end
@interface CarApp:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation CarApp
-(BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options{[NSURLCache setSharedURLCache:[[NSURLCache alloc]initWithMemoryCapacity:4*1024*1024 diskCapacity:32*1024*1024 diskPath:@"TRDMapTileCache"]];self.window=[[TRDWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];self.window.rootViewController=[Dashboard new];[self.window makeKeyAndVisible];[self performSelector:@selector(carStartAutoplay) withObject:nil afterDelay:4.0];return YES;}
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
 [v ensureActiveRunLoopHealth];
 if(![url.host isEqualToString:@"explain"]&&![url.host isEqualToString:@"capture"])[v hideFeatureExplanation];
 if([url.host isEqualToString:@"home"]){
  BOOL wasDrive=v.driveMode;
  BOOL wasCarPlay=v.carplayMode;
  TRDOBDClient *obdRet=[TRDOBDClient sharedClient];
  double spdNow=(obdRet.isConnected && obdRet.obdInitialized)?MAX(0.0,obdRet.currentSpeedKmh):((v.fix && v.fix.speed>=0)?(v.fix.speed*3.6):0.0);
  BOOL movingNow=(spdNow>=3.0);
  if(wasCarPlay && ![url.path isEqualToString:@"/force"]){
   v.carplayMode=YES;
   [v.view setNeedsLayout];
   [v refreshNowPlaying];
  } else {
   [v homePage];
   if((movingNow || wasDrive) && ![url.path isEqualToString:@"/force"]){
    v.driveMode=YES;
    v.autoDriveSuppressed=NO;
    [v.driveButton setTitle:@"‹ DASHBOARD" forState:UIControlStateNormal];
    [v.view setNeedsLayout];
   }
  }
 }
 if([url.host isEqualToString:@"carplay"])[v requestMapURL:YES];
 if([url.host isEqualToString:@"grid"])[v toggleCarPlayGrid];
 if([url.host isEqualToString:@"trip"])[v openTrip];
 if([url.host isEqualToString:@"music"])[v openMusic];
 if([url.host isEqualToString:@"youtube"])[v openYouTubeSource];
 if([url.host isEqualToString:@"camera"])[v openCamera];
 if([url.host isEqualToString:@"map"])[v requestMapURL:NO];
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
  else if([p isEqualToString:@"/6"])[v playRadio:@"https://atimevideo.smartclick.co.th/live/greenlive.sdp/chunklist.m3u8" name:@"Green Wave 106.5 (Easy Listening)"];
  else if([p isEqualToString:@"/stop"])[v playRadio:nil name:nil];
  else [v openRadioStationsMenu];
 }
 if([url.host isEqualToString:@"tripsummary"])[v showTripSummary];
 if([url.host isEqualToString:@"triplog"])[v showTripSummaryWithTab:1];
 if([url.host isEqualToString:@"lowfueltest"])[v testLowFuelWarning];
 if([url.host isEqualToString:@"gasnav"])[v navigateToFoundGasStation];
 if([url.host isEqualToString:@"fuel"])[v openFuelPriceSettings];
 if([url.host isEqualToString:@"obd"])[v openFuelPriceSettings];
 if([url.host isEqualToString:@"brake"])[v openBrakeDiagnosticsMenu];
 if([url.host isEqualToString:@"hybrid"])[v openHybridDiagnosticsMenu];
 if([url.host isEqualToString:@"reverse"]){ [[TRDOBDClient sharedClient] toggleTestReverseGear]; }
 if([url.host isEqualToString:@"welcome"])[v showWelcome];
 if([url.host isEqualToString:@"help"])[v openFeatureHelpMenu];
 if([url.host isEqualToString:@"explain"])[v carStatusTapped];
 if([url.host isEqualToString:@"oil"])[v serviceSettings];
 if([url.host isEqualToString:@"gesture"]){
  NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];
  BOOL off=![ud boolForKey:@"TRDFrontGestureDisabled"];
  [ud setBool:off forKey:@"TRDFrontGestureDisabled"];
  [ud synchronize];
  if(off){[[TRDFrontGestureEngine sharedEngine] stop];[v showGestureToast:@"👋 ปิดระบบโบกมือหน้ากล้องแล้ว"];}
  else{[[TRDFrontGestureEngine sharedEngine] startIfEnabled];[v showGestureToast:@"👋 เปิดระบบโบกมือหน้ากล้อง & ปรับแสงอัตโนมัติ"];}
 }
 if([url.host isEqualToString:@"capture"]){[v ensureActiveRunLoopHealth];[v update];[v capture];}
 if([url.host isEqualToString:@"testsettings"]&&url.path.length>1)[v testSettingsAction:@([[url.path substringFromIndex:1] integerValue])];
 return YES;
}
-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation{return [self application:app openURL:url options:@{}];}
-(void)applicationDidEnterBackground:(UIApplication *)app{
 Dashboard *guardDashboard=(Dashboard *)self.window.rootViewController;
 [guardDashboard cancelNavigationTouch:nil forEvent:nil];
 guardDashboard.mapConfirmationGeneration++;
 guardDashboard.mapURLRequestGeneration++;
 guardDashboard.mapNavigationAuthorized=NO;
 if(guardDashboard.settingsSheet.requiresIntentionalTouch)[guardDashboard.settingsSheet dismiss];
 Dashboard *v=(Dashboard *)self.window.rootViewController;
 // Keep radioPlayer playing in background if active; only dismiss menus and pause screen animations
 [NSObject cancelPreviousPerformRequestsWithTarget:v selector:@selector(refreshNowPlaying) object:nil];
 [v.settingsSheet dismiss];
 [v releaseArtwork];
 [[NSURLCache sharedURLCache] removeAllCachedResponses];
 if(!v.mapMode && !v.carplayMode && v.mapWebView){[v teardownMapWebView];}
 v.metadataGeneration++;
 v.metadataPending=NO;
 [v.audioBars stop];
 [v.driveCar stop];
 [[TRDFrontGestureEngine sharedEngine] stop];
 [v.timer invalidate];
 v.timer=nil;
 [v saveTrip];
 [v syncTripSlotsDelta:YES];
 NSUserDefaults *ud=[NSUserDefaults standardUserDefaults];
 [ud setBool:YES forKey:@"TRDSkipNextLaunchWelcome"];
 [ud setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"TRDLastActiveTimestamp"];
 [ud synchronize];
 [UIApplication sharedApplication].idleTimerDisabled=NO;
 if([UIDevice currentDevice].batteryState==UIDeviceBatteryStateUnplugged){
  if([v.gps respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)])v.gps.allowsBackgroundLocationUpdates=NO;
  [v.gps stopUpdatingLocation];
  [[TRDOBDClient sharedClient] stopScanning];
  [v releaseTransientSpeechAudio:YES];
  if(v.tripSummaryCard){
   [v immediateSleepFromTripSummary];
  }
 }
 [v captureLifecycle];
}
-(void)applicationWillTerminate:(UIApplication *)app{
 Dashboard *v=(Dashboard *)self.window.rootViewController;
 [v saveTrip];
 [v syncTripSlotsDelta:YES];
 [[NSUserDefaults standardUserDefaults] synchronize];
}
-(void)applicationWillEnterForeground:(UIApplication *)app{
 Dashboard *v=(Dashboard *)self.window.rootViewController;
 [v ensureActiveRunLoopHealth];
 [v restoreDisplayBrightness];
}
-(void)applicationDidBecomeActive:(UIApplication *)app{Dashboard *v=(Dashboard *)self.window.rootViewController;if(!v.isReverseActive && ![TRDOBDClient sharedClient].isReverseGear){notify_post("com.codex.trd.network.internet");}[[TRDOBDClient sharedClient] fetchLiveOilPrices];[[TRDOBDClient sharedClient] ensureConnectedOrScan];[v ensureActiveRunLoopHealth];[v cancelNavigationTouch:nil forEvent:nil];v.navGuardUntil=[NSProcessInfo processInfo].systemUptime+0.10;v.mapConfirmationGeneration++;v.mapNavigationAuthorized=NO;if(v.settingsSheet.requiresIntentionalTouch)[v.settingsSheet dismiss];[v cancelBrowseReturn];[v applyDisplaySchedule];[v restoreDisplayBrightness];BOOL welcomePending=[[NSFileManager defaultManager]fileExistsAtPath:@"/var/mobile/codex-car/welcome-pending"];if(welcomePending){[[NSFileManager defaultManager]removeItemAtPath:@"/var/mobile/codex-car/welcome-pending" error:nil];[v showWelcome];}[v.view setNeedsLayout];[v refreshNowPlaying];[v performSelector:@selector(restoreDisplayBrightness) withObject:nil afterDelay:.6];[v.audioBars start];if(!v.isReverseActive)[[TRDFrontGestureEngine sharedEngine] startIfEnabled];[v ensureActiveRunLoopHealth];[v startGPS];[v update];[v captureLifecycle];}

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
