#import <UIKit/UIKit.h>
#import "H109RTSP.h"
#import "H109Events.h"
#import "H109CameraAlerts.h"
#import "H109Files.h"
#import "H109Menu.h"
#import <CoreImage/CoreImage.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <notify.h>
#import <AVFoundation/AVFoundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
static NSString *H109DiagnosticPath(void){return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"H109Diagnostics.plist"];}
static void H109Record(NSMutableArray *trace,NSString *event,NSString *detail){if(detail.length>2048)detail=[detail substringToIndex:2048];[trace addObject:@{@"at":[NSDate date],@"event":event,@"detail":detail?:@""}];if(trace.count>60)[trace removeObjectAtIndex:0];[trace writeToFile:H109DiagnosticPath() atomically:YES];}
#import "H109Telemetry.h"
@interface ParkingGuideView: UIView
@end
@implementation ParkingGuideView
-(instancetype)initWithFrame:(CGRect)frame{
 if((self=[super initWithFrame:frame])){
  self.backgroundColor=[UIColor clearColor];
  self.userInteractionEnabled=NO;
  self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
 }
 return self;
}
-(void)drawRect:(CGRect)rect{
 CGFloat w=rect.size.width,h=rect.size.height;
 if(w<=0||h<=0)return;
 CGContextRef ctx=UIGraphicsGetCurrentContext();
 if(!ctx)return;
 CGFloat bottomY=h*0.93;
 CGFloat topY=h*0.52;
 CGFloat leftBottomX=w*0.14;
 CGFloat rightBottomX=w*0.86;
 CGFloat leftTopX=w*0.34;
 CGFloat rightTopX=w*0.66;
 CGFloat rangeY=bottomY-topY;
 if(rangeY<=0)return;
 #define LX(y) (leftBottomX + (leftTopX - leftBottomX) * (bottomY - (y)) / rangeY)
 #define RX(y) (rightBottomX + (rightTopX - rightBottomX) * (bottomY - (y)) / rangeY)
 CGFloat yRed=bottomY;
 CGFloat yYellow1=h*0.81;
 CGFloat yYellow2=h*0.66;
 CGFloat yGreen=topY;
 CGContextSetLineWidth(ctx, 3.5);
 CGContextSetLineCap(ctx, kCGLineCapRound);
 [[UIColor colorWithRed:0.95 green:0.15 blue:0.18 alpha:0.90] setStroke];
 CGContextMoveToPoint(ctx, LX(yRed), yRed);
 CGContextAddLineToPoint(ctx, LX(yYellow1), yYellow1);
 CGContextStrokePath(ctx);
 CGContextMoveToPoint(ctx, RX(yRed), yRed);
 CGContextAddLineToPoint(ctx, RX(yYellow1), yYellow1);
 CGContextStrokePath(ctx);
 CGContextMoveToPoint(ctx, LX(yYellow1), yYellow1);
 CGContextAddLineToPoint(ctx, RX(yYellow1), yYellow1);
 CGContextStrokePath(ctx);
 CGContextMoveToPoint(ctx, LX(yRed)-18, yRed);
 CGContextAddLineToPoint(ctx, LX(yRed)+18, yRed);
 CGContextStrokePath(ctx);
 CGContextMoveToPoint(ctx, RX(yRed)-18, yRed);
 CGContextAddLineToPoint(ctx, RX(yRed)+18, yRed);
 CGContextStrokePath(ctx);
 [[UIColor colorWithRed:0.98 green:0.82 blue:0.12 alpha:0.90] setStroke];
 CGContextMoveToPoint(ctx, LX(yYellow1), yYellow1);
 CGContextAddLineToPoint(ctx, LX(yYellow2), yYellow2);
 CGContextStrokePath(ctx);
 CGContextMoveToPoint(ctx, RX(yYellow1), yYellow1);
 CGContextAddLineToPoint(ctx, RX(yYellow2), yYellow2);
 CGContextStrokePath(ctx);
 CGContextMoveToPoint(ctx, LX(yYellow2), yYellow2);
 CGContextAddLineToPoint(ctx, RX(yYellow2), yYellow2);
 CGContextStrokePath(ctx);
 [[UIColor colorWithRed:0.18 green:0.88 blue:0.28 alpha:0.90] setStroke];
 CGContextMoveToPoint(ctx, LX(yYellow2), yYellow2);
 CGContextAddLineToPoint(ctx, LX(yGreen), yGreen);
 CGContextStrokePath(ctx);
 CGContextMoveToPoint(ctx, RX(yYellow2), yYellow2);
 CGContextAddLineToPoint(ctx, RX(yGreen), yGreen);
 CGContextStrokePath(ctx);
 CGContextMoveToPoint(ctx, LX(yGreen), yGreen);
 CGContextAddLineToPoint(ctx, RX(yGreen), yGreen);
 CGContextStrokePath(ctx);
 
 UIFont *guideFont = [UIFont boldSystemFontOfSize:11];
 NSDictionary *redAttrs = @{NSFontAttributeName: guideFont, NSForegroundColorAttributeName: [UIColor colorWithRed:0.98 green:0.25 blue:0.28 alpha:0.95]};
 NSDictionary *yelAttrs = @{NSFontAttributeName: guideFont, NSForegroundColorAttributeName: [UIColor colorWithRed:0.98 green:0.85 blue:0.15 alpha:0.95]};
 NSDictionary *grnAttrs = @{NSFontAttributeName: guideFont, NSForegroundColorAttributeName: [UIColor colorWithRed:0.25 green:0.92 blue:0.35 alpha:0.95]};
 [@"0.5m" drawAtPoint:CGPointMake(RX(yRed) + 22, yRed - 7) withAttributes:redAttrs];
 [@"1.0m" drawAtPoint:CGPointMake(RX(yYellow1) + 16, yYellow1 - 7) withAttributes:yelAttrs];
 [@"2.0m" drawAtPoint:CGPointMake(RX(yGreen) + 12, yGreen - 7) withAttributes:grnAttrs];
 [@"0.5m" drawAtPoint:CGPointMake(LX(yRed) - 52, yRed - 7) withAttributes:redAttrs];
 [@"1.0m" drawAtPoint:CGPointMake(LX(yYellow1) - 46, yYellow1 - 7) withAttributes:yelAttrs];
 [@"2.0m" drawAtPoint:CGPointMake(LX(yGreen) - 42, yGreen - 7) withAttributes:grnAttrs];
 
 CGFloat cx = w * 0.5;
 CGContextSetLineWidth(ctx, 2.0);
 [[UIColor colorWithWhite:1.0 alpha:0.75] setStroke];
 CGContextMoveToPoint(ctx, cx - 14, bottomY);
 CGContextAddLineToPoint(ctx, cx + 14, bottomY);
 CGContextStrokePath(ctx);
 CGContextMoveToPoint(ctx, cx, bottomY - 8);
 CGContextAddLineToPoint(ctx, cx, bottomY + 8);
 CGContextStrokePath(ctx);
 #undef LX
 #undef RX
}
@end
@interface Viewer:UIViewController<NSURLSessionDataDelegate,UITextFieldDelegate>
@property UITextField *address;
@property UILabel *status;
@property UIImageView *picture;
@property NSURLSession *session;
@property NSMutableData *buffer;
@property AVPlayer *player;
@property AVPlayerLayer *video;
@property NSUInteger frames;
@property H109RTSP *rtsp;
@property AVSampleBufferDisplayLayer *liveLayer;
@property BOOL framePending;
@property NSUInteger discoveryGeneration;
@property BOOL searching;
@property BOOL snapshotBusy;
@property H109CameraAlerts *alerts;
@property UISwitch *autoSwitch;
@property UILabel *autoLabel;
@property NSString *captureReason;
@property NSDate *eventDate;
@property NSDate *statusUntil;
@property AVPlayerItemVideoOutput *videoOutput;
@property UILabel *heading,*networkLabel,*stateLabel,*emptyLabel;
@property UISegmentedControl *channels;
@property NSMutableArray *actions,*menus;
-(void)showConnection;
-(void)showSettings;
-(void)showSaved;
-(void)showRecordings;
-(void)presentPanel:(UIViewController *)panel;
-(void)openSavedClips;
-(void)openImages;
@property H109Telemetry *telemetry;
@property UILabel *telemetryLabel;
@property UIButton *mediaButton;
@property UIButton *returnButton,*setupButton,*mirrorButton,*fullButton,*exitFull,*guideButton;
@property ParkingGuideView *parkingGuideView;
@property BOOL showGuide;
-(void)toggleGuide;
-(void)swipeChannel:(UISwipeGestureRecognizer *)gesture;
@property BOOL fullscreen,mirrored,wantsLive,retryScheduled,fixtureMode;
@property NSUInteger retryCount;
@property NSTimer *health;
@property NSDate *lastFrame;
@property NSUInteger healthFrames;
@property double lastVideoTime;
@property NSDate *healthySince,*connectionBegan;
@property NSString *lastSSID;
@property NSTimer *networkWait;
@property NSDate *networkDeadline;
@property NSDate *networkRequestedAt;
@property NSString *cameraSSID;
@property NSTimer *channelFollowTimer;
@property BOOL channelProbeBusy;
@property NSInteger mainCameraChannel;
@property NSDate *mainCameraReadAt;
-(void)beginAutomaticCamera;
-(void)checkCameraNetwork;
-(void)checkMainCameraChannel;
-(void)stopTransport;
-(void)scheduleReconnect;
-(void)healthTick;
-(void)openLibrary;
-(void)streamSetup;
@property UIView *fullHudBar;
@property UILabel *fullHudLabel;
@property UIButton *fullSwitchBtn;
@property UIButton *fullHomeBtn;
@property UIView *flashView;
@property UIView *fullMusicBar;
@property UILabel *fullMusicLabel;
@property UIButton *fullNextBtn;
-(void)skipNextTrack;
-(void)toggleChannelFull;
-(void)quickSnapshot;
-(void)updateFullHUD;
@end
@implementation Viewer
#import "H109HUD.h"
-(void)toggleChannelFull{
 NSInteger target=(self.channels.selectedSegmentIndex==0)?1:0;
 self.channels.selectedSegmentIndex=target;
 [self selectChannel];
 [self updateFullHUD];
}
-(void)quickSnapshot{
 self.flashView.alpha=0.75;
 [UIView animateWithDuration:0.25 animations:^{
  self.flashView.alpha=0;
 }];
 self.captureReason=@"triple_tap_quick_snapshot";
 self.eventDate=nil;
 [self snapshot];
}
-(void)skipNextTrack{
 char *args[]={(char *)"/usr/bin/activator",(char *)"send",(char *)"libactivator.ipod.next-track",NULL};
 posix_spawn(NULL,args[0],NULL,NULL,args,NULL);
 [self performSelector:@selector(updateFullHUD) withObject:nil afterDelay:0.7];
}
-(void)updateFullHUD{
 if(!self.fullscreen)return;
 NSDictionary *tele=[self.telemetry summary];
 NSNumber *spd=tele[@"speedKmh"];
 NSString *spdStr=spd?[NSString stringWithFormat:@"%.0f km/h",spd.doubleValue]:@"-- km/h";
 NSString *camStr=(self.channels.selectedSegmentIndex==1)?@"REAR CAM":@"FRONT CAM";
 NSString *recStr=[tele[@"recording"] isEqual:@"OFF"]?@"⚪ IDLE":@"🔴 REC";
 self.fullHudLabel.text=[NSString stringWithFormat:@"%@   •   %@   •   %@",recStr,spdStr,camStr];
 NSString *nextBtn=(self.channels.selectedSegmentIndex==1)?@"⇄ FRONT":@"⇄ REAR";
 [self.fullSwitchBtn setTitle:nextBtn forState:0];
 NSDictionary *dash=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/h109-build/cardash-state.plist"];
 NSString *songTitle=dash[@"song"]?:@"";
 NSString *artistName=dash[@"artist"]?:@"";
 if(songTitle.length&&![songTitle isEqual:@"Choose your music"]){
  self.fullMusicLabel.text=[NSString stringWithFormat:@" 🎵 %@ · %@",songTitle,artistName.length?artistName:@"TRD"];
 }else{
  self.fullMusicLabel.text=@" 🎵 PRIUS TRD • audioNINJA";
 }
}
-(void)beginAutomaticCamera{
 [self stop];NSDictionary *config=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/network-config.plist"];self.cameraSSID=[config[@"cameraSSID"]isKindOfClass:[NSString class]]?config[@"cameraSSID"]:@"H109Y-37802895";self.networkDeadline=[NSDate dateWithTimeIntervalSinceNow:90];
 self.stateLabel.text=@"JOINING CAMERA WI-FI";self.status.text=[NSString stringWithFormat:@"Connecting to %@...",self.cameraSSID];self.emptyLabel.hidden=NO;self.emptyLabel.text=@"CONNECTING TO CAMERA WI-FI";[UIApplication sharedApplication].idleTimerDisabled=YES;
 self.networkRequestedAt=[NSDate date];notify_post("com.codex.trd.network.camera");self.networkWait=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkCameraNetwork) userInfo:nil repeats:YES];self.networkWait.tolerance=.1;[self checkCameraNetwork];
}
-(void)checkCameraNetwork{
 [self refreshTelemetry];
 if([UIApplication sharedApplication].applicationState!=UIApplicationStateActive){[self stop];return;}
 NSDictionary *network=CFBridgingRelease(CNCopyCurrentNetworkInfo(CFSTR("en0")));NSDictionary *state=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/network-state.plist"];
 BOOL ready=[network[@"SSID"]isEqual:self.cameraSSID]&&[state[@"mode"]isEqual:@"camera"]&&[state[@"phase"]isEqual:@"ready"]&&[state[@"actualSSID"]isEqual:self.cameraSSID];
 if(ready){[self.networkWait invalidate];self.networkWait=nil;NSString *cached=[[NSUserDefaults standardUserDefaults]stringForKey:@"lastWorkingStream"];if(cached.length&&[cached hasPrefix:@"rtsp://"]){self.status.text=@"Fast-connecting to camera stream...";self.address.text=cached;[self connect];return;}[self discover];return;}
 NSDate *stateDate=[state[@"at"]isKindOfClass:[NSDate class]]?state[@"at"]:nil;BOOL fresh=stateDate&&[stateDate compare:self.networkRequestedAt]!=NSOrderedAscending;
 if(fresh&&[state[@"cameraUnavailable"]boolValue]&&![@[@"restored",@"error"]containsObject:state[@"phase"]]){self.stateLabel.text=@"RESTORING PREVIOUS WI-FI";self.emptyLabel.text=@"CAMERA UNAVAILABLE\nRestoring previous Wi-Fi...";}
 if((fresh&&(([state[@"cameraUnavailable"]boolValue]&&[@[@"restored",@"error"]containsObject:state[@"phase"]])||([state[@"mode"]isEqual:@"camera"]&&[state[@"phase"]isEqual:@"error"])))||[self.networkDeadline timeIntervalSinceNow]<=0){[self.networkWait invalidate];self.networkWait=nil;self.stateLabel.text=@"WI-FI NOT CONNECTED";self.emptyLabel.text=@"CHECK CAMERA WI-FI\nTap FIND to retry";self.status.text=[state[@"cameraUnavailable"]boolValue]?([state[@"phase"]isEqual:@"restored"]?@"Camera unavailable. Previous Wi-Fi restored. Tap FIND to retry.":@"Camera unavailable. Restoring previous Wi-Fi; tap FIND later."):state[@"error"]?:@"Could not join the camera Wi-Fi. Check that the camera is on, then tap FIND.";[UIApplication sharedApplication].idleTimerDisabled=NO;}
}
-(void)checkMainCameraChannel{
 if(self.channelProbeBusy||!self.wantsLive||!self.rtsp||(self.frames>20&&self.lastFrame&&-[self.lastFrame timeIntervalSinceNow]<3)||self.presentedViewController||[UIApplication sharedApplication].applicationState!=UIApplicationStateActive)return;
 NSURL *url=[NSURL URLWithString:self.address.text];if(![[[NSUserDefaults standardUserDefaults]stringForKey:@"reportedCameraHost"]isEqual:url.host])return;
 self.channelProbeBusy=YES;NSUInteger generation=self.discoveryGeneration;NSString *host=url.host;__weak Viewer *weak=self;
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSDictionary *info=[H109RTSP cameraDeviceInfo:host];dispatch_async(dispatch_get_main_queue(),^{
  Viewer *v=weak;if(!v||v.discoveryGeneration!=generation)return;v.channelProbeBusy=NO;
  if(![info[@"curcamid"]isKindOfClass:[NSNumber class]]||![info[@"camnum"]isKindOfClass:[NSNumber class]])return;
  NSInteger channel=[info[@"curcamid"]integerValue];if(channel<0||channel>1||channel>=[info[@"camnum"]integerValue])return;
  v.mainCameraChannel=channel;v.mainCameraReadAt=[NSDate date];if(v.channels.selectedSegmentIndex==channel)return;
  NSMutableArray *trace=[[NSArray arrayWithContentsOfFile:H109DiagnosticPath()]mutableCopy]?:[NSMutableArray array];H109Record(trace,@"Following main camera",channel==1?@"Rear":@"Front");
  v.channels.selectedSegmentIndex=channel;if(v.parkingGuideView)v.parkingGuideView.hidden=!(v.showGuide&&channel==1);if(channel==1&&!v.mirrored)[v toggleMirror];else if(channel==0&&v.mirrored)[v toggleMirror];v.retryCount=0;[v updateFullHUD];[v connect];
 });});
}
-(void)captureDiagnostics{
 UIView *surface=self.view;UIGraphicsBeginImageContextWithOptions(surface.bounds.size,YES,1);[surface drawViewHierarchyInRect:surface.bounds afterScreenUpdates:YES];NSData *png=UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());UIGraphicsEndImageContext();[png writeToFile:@"/var/mobile/h109-build/capture.png" atomically:YES];
 NSString *state=[NSString stringWithFormat:@"status=%@\nframes=%lu\nrenderer=%ld\nerror=%@\nurl=%@",self.status.text,(unsigned long)self.frames,(long)self.liveLayer.status,self.liveLayer.error,self.address.text];[state writeToFile:@"/var/mobile/h109-build/capture-state.txt" atomically:YES encoding:4 error:NULL];[self captureState];
}
-(void)captureState{[@{@"telemetry":[self.telemetry summary]?:@{},@"telemetryText":self.telemetryLabel.text?:@"",@"renderer":@(self.liveLayer.status),@"placeholder":self.emptyLabel.text?:@"",@"fixture":@(self.fixtureMode),@"state":self.stateLabel.text?:@"",@"status":self.status.text?:@"",@"frames":@(self.frames),@"fullscreen":@(self.fullscreen),@"mirror":@(self.mirrored),@"channel":@(self.channels.selectedSegmentIndex),@"mainCameraChannel":@(self.mainCameraChannel),@"mainCameraChannelFresh":@(self.mainCameraReadAt&&-[self.mainCameraReadAt timeIntervalSinceNow]<3),@"channelFollowActive":@(self.channelFollowTimer!=nil),@"retryCount":@(self.retryCount),@"retryScheduled":@(self.retryScheduled),@"wantsLive":@(self.wantsLive),@"applicationState":@([UIApplication sharedApplication].applicationState),@"healthActive":@(self.health!=nil),@"freshFrame":@(self.lastFrame&&-[self.lastFrame timeIntervalSinceNow]<=2),@"url":self.address.text?:@""}writeToFile:@"/var/mobile/h109-build/viewer-state.plist" atomically:YES];}
-(void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];
#ifdef H109_TESTING
 NSString *test=[NSString stringWithContentsOfFile:@"/var/mobile/h109-build/test-url.txt" encoding:4 error:NULL];if(test.length){self.address.text=test;[self connect];}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{UIGraphicsBeginImageContextWithOptions(self.view.bounds.size,YES,1);[self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:YES];NSData *png=UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());UIGraphicsEndImageContext();[png writeToFile:@"/var/mobile/h109-build/preview.png" atomically:YES];[self.status.text writeToFile:@"/var/mobile/h109-build/state.txt" atomically:YES encoding:4 error:NULL];});
#endif
}
-(void)viewDidLayoutSubviews{[super viewDidLayoutSubviews];[self layoutHUD];}
-(void)wifi{NSDictionary *info=CFBridgingRelease(CNCopyCurrentNetworkInfo(CFSTR("en0")));self.lastSSID=info[@"SSID"];self.networkLabel.text=[NSString stringWithFormat:@"%@  •  PREVIEW MUTED",self.lastSSID?:@"NO WI-FI"];self.status.text=@"Connect to H109Y Wi-Fi, then tap FIND. Tap FIND to discover the camera stream.";}
-(void)tap:(UIButton *)b{if(b.tag==1){self.retryCount=0;[self connect];}else if(b.tag==2)[self stop];else if(b.tag==3)[self beginAutomaticCamera];else if(b.tag==4){self.captureReason=@"manual_snapshot";self.eventDate=nil;[self snapshot];}else if(b.tag==6)[self openLibrary];else{UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:[H109Events new]];[self presentViewController:nav animated:YES completion:nil];}}
-(void)saveSnapshot:(UIImage *)image date:(NSDate *)date{
 [H109Events save:image requestedAt:date reason:(self.fixtureMode?[@"test_fixture_"stringByAppendingString:self.captureReason?:@"manual_snapshot"]:self.captureReason) completion:^(NSString *path,NSString *error){self.snapshotBusy=NO;[self.view viewWithTag:4].userInteractionEnabled=YES;self.statusUntil=[NSDate dateWithTimeIntervalSinceNow:4];self.status.text=path?@"Snapshot saved. Open SAVED to view or share.":error;}];
}
-(void)snapshot{
 if(self.snapshotBusy)return;if(!self.lastFrame||-[self.lastFrame timeIntervalSinceNow]>2){self.status.text=@"No fresh live frame. Connect the camera before taking a snapshot.";return;}self.snapshotBusy=YES;[self.view viewWithTag:4].userInteractionEnabled=NO;self.status.text=@"Saving event snapshot...";self.statusUntil=[NSDate dateWithTimeIntervalSinceNow:8];NSDate *date=self.eventDate?:[NSDate date];self.eventDate=nil;
 if(self.rtsp){[self.rtsp captureFrame:^(CGImageRef image,NSString *error){if(image)[self saveSnapshot:[UIImage imageWithCGImage:image] date:date];else{self.snapshotBusy=NO;[self.view viewWithTag:4].userInteractionEnabled=YES;self.status.text=error;self.statusUntil=[NSDate dateWithTimeIntervalSinceNow:4];}}];return;}
 if(self.videoOutput){CVPixelBufferRef pixel=[self.videoOutput copyPixelBufferForItemTime:self.player.currentTime itemTimeForDisplay:NULL];if(pixel){CIImage *source=[CIImage imageWithCVPixelBuffer:pixel];CIContext *context=[CIContext contextWithOptions:nil];CGImageRef frame=[context createCGImage:source fromRect:source.extent];CVPixelBufferRelease(pixel);if(frame){UIImage *image=[UIImage imageWithCGImage:frame];CGImageRelease(frame);[self saveSnapshot:image date:date];return;}}}
 else if(self.picture.image){[self saveSnapshot:self.picture.image date:date];return;}
 self.snapshotBusy=NO;[self.view viewWithTag:4].userInteractionEnabled=YES;self.status.text=@"No live frame is available for a snapshot.";self.statusUntil=[NSDate dateWithTimeIntervalSinceNow:4];
}
-(void)autoChanged{[[NSUserDefaults standardUserDefaults]setBool:self.autoSwitch.on forKey:@"autoCameraEvents"];[self.alerts stop];self.alerts=nil;if(self.autoSwitch.on&&self.rtsp)[self startAlerts:[NSURL URLWithString:self.address.text] port:3333];else self.autoLabel.text=self.autoSwitch.on?@"EVENTS: waiting for camera":@"EVENTS: OFF";}
-(void)startAlerts:(NSURL *)url port:(int)port{
 [self.alerts stop];self.alerts=nil;if(!self.autoSwitch.on)return;
 if(![url.path isEqual:@"/xxxx.mov"]){self.autoLabel.text=@"EVENTS: unknown camera protocol";return;}
 self.alerts=[H109CameraAlerts new];__weak Viewer *weak=self;__weak H109CameraAlerts *listener=self.alerts;
 self.alerts.status=^(NSString *message){Viewer *v=weak;if(v.alerts==listener)v.autoLabel.text=message;};
 self.alerts.event=^(NSString *reason,NSDate *date){Viewer *v=weak;if(!v||v.alerts!=listener||!v.rtsp||!v.autoSwitch.on)return;if(v.snapshotBusy){v.autoLabel.text=@"EVENTS: previous capture is still saving";return;}v.captureReason=@"camera_sensor_started";v.eventDate=date;v.autoLabel.text=reason;[v snapshot];};
 [self.alerts startHost:url.host port:port];
}
-(void)discover{
 if(self.searching)return;NSMutableArray *trace=[NSMutableArray array];[self stop];NSDictionary *info=CFBridgingRelease(CNCopyCurrentNetworkInfo(CFSTR("en0")));NSString *ssid=info[@"SSID"];H109Record(trace,@"network",ssid?:@"No Wi-Fi");
 if(![ssid hasPrefix:@"H109Y-"]&&![ssid hasPrefix:@"H108Y-"]){self.status.text=[NSString stringWithFormat:@"Wi-Fi: %@. Join the H109Y camera network, then tap FIND.",ssid?:@"none"];return;}
 NSMutableArray *hosts=[NSMutableArray array];struct ifaddrs *all=NULL;if(getifaddrs(&all)==0){for(struct ifaddrs *a=all;a;a=a->ifa_next){if(a->ifa_addr&&a->ifa_addr->sa_family==AF_INET&&[[NSString stringWithUTF8String:a->ifa_name]isEqual:@"en0"]){char ip[INET_ADDRSTRLEN];inet_ntop(AF_INET,&((struct sockaddr_in *)a->ifa_addr)->sin_addr,ip,sizeof(ip));NSString *text=[NSString stringWithUTF8String:ip];NSArray *parts=[text componentsSeparatedByString:@"."];if(parts.count==4){NSString *prefix=[[parts subarrayWithRange:NSMakeRange(0,3)]componentsJoinedByString:@"."];for(NSString *last in @[@"1",@"254"]){NSString *host=[prefix stringByAppendingFormat:@".%@",last];if(![host isEqual:text])[hosts addObject:host];}}}}freeifaddrs(all);}
 if(!hosts.count){self.status.text=@"Camera Wi-Fi has no IPv4 address yet. Wait and try FIND again.";return;}
 self.searching=YES;NSUInteger generation=self.discoveryGeneration;self.status.text=@"Checking known read-only stream descriptions...";self.stateLabel.text=@"DISCOVERING";__weak Viewer *weak=self;
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSDate *started=[NSDate date];H109Record(trace,@"hosts",hosts.description);NSArray *paths=@[@"/xxxx.mov",@"/liveRTSP/av4",@"/liveRTSP/v1",@"/liveRTSP/v3",@"/live/ch00_1",@"/live/ch00_0",@"/264_pcm_rt/XXX.sd",@"/264_pcm_rt/rear.sd",@""];NSMutableArray *found=[NSMutableArray array];BOOL reportedProfile=NO;NSInteger reportedChannel=0;
  for(NSString *host in hosts){NSMutableArray *candidates=[paths mutableCopy];
   Viewer *current=weak;if(!current||current.discoveryGeneration!=generation)return;
   NSDictionary *profile=[H109RTSP cameraProfile:host];
   if(profile){NSDictionary *device=[H109RTSP cameraDeviceInfo:host];reportedChannel=[device[@"curcamid"]integerValue];H109Record(trace,@"Camera profile",[NSString stringWithFormat:@"%@ / %@",profile[@"company"],profile[@"soc"]]);BOOL opened=[H109RTSP openCameraSession:host];H109Record(trace,@"Preview session",opened?@"Opened":@"Failed");if(opened){NSDictionary *currentDevice=[H109RTSP cameraDeviceInfo:host];if([currentDevice[@"curcamid"]isKindOfClass:[NSNumber class]])reportedChannel=[currentDevice[@"curcamid"]integerValue];H109Record(trace,@"Main camera channel",reportedChannel==1?@"Rear":@"Front");for(NSURL *url in [H109RTSP cameraStreamURLs:host]){NSDictionary *r=[H109RTSP describe:url];H109Record(trace,@"Reported RTSP URL",[NSString stringWithFormat:@"%@ -> %@",url.absoluteString,r[@"code"]?:@"No response"]);if([r[@"code"]intValue]==200&&[r[@"body"]rangeOfString:@"H264/" options:NSCaseInsensitiveSearch].location!=NSNotFound){[found addObject:url.absoluteString];reportedProfile=YES;break;}}}if(found.count)break;continue;}
   NSString *meta=[H109RTSP readMetadata:host path:@"/?custom=1&cmd=2019"];
   H109Record(trace,@"Novatek metadata",meta.length?[meta substringToIndex:MIN((NSUInteger)512,meta.length)]:@"No HTTP response");NSRegularExpression *urls=[NSRegularExpression regularExpressionWithPattern:@"rtsp://[^<>\\s\"]+" options:0 error:NULL];for(NSTextCheckingResult *m in [urls matchesInString:meta?:@"" options:0 range:NSMakeRange(0,meta.length)]){NSURL *u=[NSURL URLWithString:[meta substringWithRange:m.range]];if([u.host isEqual:host]&&!u.user.length){NSDictionary *description=[H109RTSP describe:u];H109Record(trace,@"Reported RTSP URL",[NSString stringWithFormat:@"%@ -> %@",u.absoluteString,description?:@{}]);if([description[@"code"]intValue]==200&&[description[@"body"]rangeOfString:@"H264/" options:NSCaseInsensitiveSearch].location!=NSNotFound){[found addObject:u.absoluteString];break;}}}
   if(found.count)break;
   NSString *channel=[H109RTSP readMetadata:host path:@"/cgi-bin/hisnet/getcamchnl.cgi?&-camid=0"];
   NSRegularExpression *cam=[NSRegularExpression regularExpressionWithPattern:@"camchnl[^a-zA-Z0-9]+([a-zA-Z0-9._-]{1,32})" options:NSRegularExpressionCaseInsensitive error:NULL];NSTextCheckingResult *match=[cam firstMatchInString:channel?:@"" options:0 range:NSMakeRange(0,channel.length)];if(match)[candidates insertObject:[@"/livestream/" stringByAppendingString:[channel substringWithRange:[match rangeAtIndex:1]]] atIndex:0];
   for(NSString *path in candidates){if(-[started timeIntervalSinceNow]>30)break;Viewer *v=weak;if(!v||v.discoveryGeneration!=generation)return;NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"rtsp://%@%@",host,path]];NSDictionary *r=[H109RTSP describe:url];NSString *preview=r[@"body"];if(preview.length>512)preview=[preview substringToIndex:512];H109Record(trace,@"RTSP probe",[NSString stringWithFormat:@"%@ -> %@ / %@",url.absoluteString,r[@"code"]?:@"No response",preview?:@""]);if(!r)continue;if([r[@"code"]intValue]==200&&[r[@"body"]rangeOfString:@"H264/" options:NSCaseInsensitiveSearch].location!=NSNotFound){[found addObject:url.absoluteString];break;}}if(found.count)break;}
  dispatch_async(dispatch_get_main_queue(),^{Viewer *v=weak;if(!v||v.discoveryGeneration!=generation)return;v.searching=NO;H109Record(trace,@"result",found.count?found.description:@"No supported H.264 stream found. Share diagnostics for analysis.");if(found.count){v.address.text=found[0];NSUserDefaults *prefs=[NSUserDefaults standardUserDefaults];if(reportedProfile){[prefs setObject:[NSURL URLWithString:found[0]].host forKey:@"reportedCameraHost"];v.channels.selectedSegmentIndex=reportedChannel==1?1:0;}else [prefs removeObjectForKey:@"reportedCameraHost"];[v connect];}else{v.stateLabel.text=@"OFFLINE";v.status.text=@"No supported stream found. CONNECTION > SHARE DIAGNOSTICS saves the probe results.";}});
 });
}
-(BOOL)textFieldShouldReturn:(UITextField *)field{[self connect];return YES;}
-(void)stop{self.wantsLive=NO;self.retryCount=0;self.retryScheduled=NO;[self stopTransport];self.stateLabel.text=@"OFFLINE";self.emptyLabel.text=@"PREVIEW STOPPED\nTap CONNECT or FIND";self.emptyLabel.hidden=self.picture.image!=nil;}
-(void)stopTransport{[self.telemetry stop];[self refreshTelemetry];[self.channelFollowTimer invalidate];self.channelFollowTimer=nil;self.channelProbeBusy=NO;self.mainCameraChannel=-1;self.mainCameraReadAt=nil;[self.networkWait invalidate];self.networkWait=nil;[self.health invalidate];self.health=nil;self.lastFrame=nil;[self.alerts stop];self.alerts=nil;self.autoLabel.text=self.autoSwitch.on?@"EVENTS: waiting for camera validation":@"EVENTS: OFF";self.discoveryGeneration++;self.searching=NO;[self.rtsp stop];self.rtsp=nil;[self.liveLayer flushAndRemoveImage];[self.liveLayer removeFromSuperlayer];self.liveLayer=nil;self.framePending=NO;[self.session invalidateAndCancel];self.session=nil;[self.player pause];self.player=nil;self.videoOutput=nil;[self.video removeFromSuperlayer];self.video=nil;self.buffer=nil;self.status.text=@"Live preview stopped.";[UIApplication sharedApplication].idleTimerDisabled=NO;}
-(void)connect{[self stopTransport];[self updateWiFi];self.wantsLive=YES;self.retryScheduled=NO;self.lastVideoTime=-1;self.connectionBegan=[NSDate date];self.lastFrame=nil;self.healthySince=nil;self.healthFrames=0;self.picture.image=nil;self.emptyLabel.hidden=NO;self.emptyLabel.text=@"CONNECTING TO CAMERA";self.stateLabel.text=@"CONNECTING";self.health=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(healthTick) userInfo:nil repeats:YES];self.health.tolerance=.15;[self.address resignFirstResponder];NSURL *u=[NSURL URLWithString:self.address.text];
if([u.scheme.lowercaseString isEqual:@"rtsp"]&&u.host.length&&!u.user.length&&!u.password.length){
 [[NSUserDefaults standardUserDefaults]setObject:u.absoluteString forKey:@"url"];self.liveLayer=[AVSampleBufferDisplayLayer layer];self.liveLayer.videoGravity=AVLayerVideoGravityResizeAspect;self.liveLayer.frame=self.picture.bounds;[self.picture.layer addSublayer:self.liveLayer];[self.picture bringSubviewToFront:self.emptyLabel];if(self.parkingGuideView)[self.picture bringSubviewToFront:self.parkingGuideView];self.rtsp=[H109RTSP new];__weak Viewer *weak=self;__weak H109RTSP *engine=self.rtsp;
 self.rtsp.finished=^{Viewer *v=weak;if(v.rtsp==engine){[UIApplication sharedApplication].idleTimerDisabled=NO;[v scheduleReconnect];}};
 self.rtsp.status=^(NSString *message){Viewer *v=weak;if(v.rtsp==engine)if(!v.statusUntil||[v.statusUntil timeIntervalSinceNow]<=0)v.status.text=message;};
 self.rtsp.sample=^(CMSampleBufferRef sample){Viewer *v=weak;H109RTSP *client=engine;if(!v||!client)return;@synchronized(v){if(v.framePending)return;v.framePending=YES;}CFRetain(sample);dispatch_async(dispatch_get_main_queue(),^{if(v.rtsp==client){if(v.liveLayer.status==AVQueuedSampleBufferRenderingStatusFailed)[v.liveLayer flush];if(v.liveLayer.readyForMoreMediaData){[v.liveLayer enqueueSampleBuffer:sample];if(!v.frames){[[NSUserDefaults standardUserDefaults]setObject:v.address.text forKey:@"lastWorkingStream"];[[NSUserDefaults standardUserDefaults]synchronize];}v.frames++;v.lastFrame=[NSDate date];v.emptyLabel.hidden=YES;if(!v.statusUntil||[v.statusUntil timeIntervalSinceNow]<=0)v.status.text=[NSString stringWithFormat:@"RTSP H.264 • %lu frames received",(unsigned long)v.frames];}if(v.liveLayer.status==AVQueuedSampleBufferRenderingStatusFailed)v.status.text=[NSString stringWithFormat:@"ตัวถอดภาพไม่รองรับสตรีมนี้: %@",v.liveLayer.error.localizedDescription];}@synchronized(v){v.framePending=NO;}CFRelease(sample);});};
 self.frames=0;[UIApplication sharedApplication].idleTimerDisabled=YES;[self.rtsp start:u];[self startAlerts:u port:3333];if([[[NSUserDefaults standardUserDefaults]stringForKey:@"reportedCameraHost"]isEqual:u.host]){self.telemetry=[H109Telemetry new];[self.telemetry start:u.host];self.channelFollowTimer=[NSTimer scheduledTimerWithTimeInterval:12.0 target:self selector:@selector(checkMainCameraChannel) userInfo:nil repeats:YES];self.channelFollowTimer.tolerance=.2;}return;}
if(!u.host.length||u.user.length||u.password.length||![@[@"http",@"https"] containsObject:u.scheme.lowercaseString]){[self stop];self.status.text=@"ใส่ URL ภาพสดแบบ rtsp:// หรือ http:// ของกล้อง\nหรือเชื่อม Wi-Fi H109Y แล้วแตะค้นหากล้อง";return;}[[NSUserDefaults standardUserDefaults]setObject:u.absoluteString forKey:@"url"];self.frames=0;self.buffer=[NSMutableData data];self.status.text=@"Connecting...";[UIApplication sharedApplication].idleTimerDisabled=YES;NSURLSessionConfiguration *cfg=[NSURLSessionConfiguration ephemeralSessionConfiguration];cfg.timeoutIntervalForRequest=12;cfg.timeoutIntervalForResource=86400;self.session=[NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:[NSOperationQueue mainQueue]];[[self.session dataTaskWithURL:u]resume];}
-(void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveResponse:(NSURLResponse *)r completionHandler:(void (^)(NSURLSessionResponseDisposition))done{if(s!=self.session){done(NSURLSessionResponseCancel);return;}NSInteger code=[(NSHTTPURLResponse *)r statusCode];if(code!=200){self.status.text=[NSString stringWithFormat:@"กล้องตอบ HTTP %ld — ตรวจ URL อีกครั้ง",(long)code];[self scheduleReconnect];done(NSURLSessionResponseCancel);return;}NSString *mime=r.MIMEType.lowercaseString;if([mime containsString:@"mpegurl"]||[r.URL.pathExtension.lowercaseString isEqual:@"m3u8"]||[mime hasPrefix:@"video/"]){self.player=[AVPlayer playerWithURL:r.URL];self.player.muted=YES;[[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryAmbient error:nil];self.videoOutput=[[AVPlayerItemVideoOutput alloc]initWithPixelBufferAttributes:@{(NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];[self.player.currentItem addOutput:self.videoOutput];self.video=[AVPlayerLayer playerLayerWithPlayer:self.player];self.video.frame=self.picture.bounds;[self.picture.layer addSublayer:self.video];[self.picture bringSubviewToFront:self.emptyLabel];if(self.parkingGuideView)[self.picture bringSubviewToFront:self.parkingGuideView];[self.player play];self.status.text=@"System video stream opened. Waiting for playable frames.";done(NSURLSessionResponseCancel);return;}if(![mime containsString:@"multipart"]&&![mime isEqual:@"image/jpeg"]){self.status.text=[NSString stringWithFormat:@"รูปแบบข้อมูลยังไม่รองรับ: %@",mime?:@"ไม่ทราบชนิด"];done(NSURLSessionResponseCancel);return;}self.status.text=@"Connected. Waiting for JPEG frames.";done(NSURLSessionResponseAllow);}
-(void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)data{if(s!=self.session)return;[self.buffer appendData:data];if(self.buffer.length>4194304){[self stop];self.status.text=@"ข้อมูลภาพเกินขีดจำกัด 4 MB";return;}unsigned char a[]={255,216},b[]={255,217};NSData *start=[NSData dataWithBytes:a length:2],*end=[NSData dataWithBytes:b length:2];while(self.buffer.length>=4){NSRange x=[self.buffer rangeOfData:start options:0 range:NSMakeRange(0,self.buffer.length)];if(x.location==NSNotFound)break;NSRange y=[self.buffer rangeOfData:end options:0 range:NSMakeRange(x.location+2,self.buffer.length-x.location-2)];if(y.location==NSNotFound)break;UIImage *im=[UIImage imageWithData:[self.buffer subdataWithRange:NSMakeRange(x.location,y.location+2-x.location)]];[self.buffer replaceBytesInRange:NSMakeRange(0,y.location+2) withBytes:NULL length:0];if(im){self.picture.image=im;self.frames++;self.lastFrame=[NSDate date];self.emptyLabel.hidden=YES;if(!self.statusUntil||[self.statusUntil timeIntervalSinceNow]<=0)self.status.text=[NSString stringWithFormat:@"MJPEG • %lu frames received",(unsigned long)self.frames];}}}
-(void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)error{if(s!=self.session)return;if(error.code!=NSURLErrorCancelled){self.status.text=error?[NSString stringWithFormat:@"รับภาพไม่ได้: %@",error.localizedDescription]:@"Stream ended.";[UIApplication sharedApplication].idleTimerDisabled=NO;}if(!self.player)[UIApplication sharedApplication].idleTimerDisabled=NO;[s finishTasksAndInvalidate];self.session=nil;if(!self.player)[self scheduleReconnect];}
@end
@interface App:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation App
-(BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o{self.window=[[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];self.window.rootViewController=[Viewer new];[self.window makeKeyAndVisible];return YES;}
-(void)applicationDidEnterBackground:(UIApplication *)a{[(Viewer *)self.window.rootViewController stop];}
-(void)applicationDidBecomeActive:(UIApplication *)a{[(Viewer *)self.window.rootViewController beginAutomaticCamera];}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass([App class]));}}
