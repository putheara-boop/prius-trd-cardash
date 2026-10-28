#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <unistd.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <notify.h>
static NSString *const Arm=@"/var/mobile/codex-car/browse-return.plist";
static NSString *const Log=@"/var/mobile/codex-car/browse-return-state.plist";

@interface TRDFloatingHome: UIButton <UIGestureRecognizerDelegate>
+(void)installIfNeeded;
+(void)goHome;
+(void)onGesture:(UIGestureRecognizer *)g;
@end

@implementation TRDFloatingHome
+(void)goHome{
 dispatch_async(dispatch_get_main_queue(),^{
  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cardash://home"]];
 });
}
-(void)goHome{
 [[self class] goHome];
}
+(void)onGesture:(UIGestureRecognizer *)g{
 if([g isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]){
  if(g.state==UIGestureRecognizerStateBegan||g.state==UIGestureRecognizerStateRecognized){
   [self goHome];
  }
 } else if([g isKindOfClass:[UISwipeGestureRecognizer class]]){
  if(g.state==UIGestureRecognizerStateRecognized){
   [self goHome];
  }
 }
}
+(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
 return YES;
}
+(void)installIfNeeded{
 dispatch_async(dispatch_get_main_queue(),^{
  UIWindow *window=nil;
  for(UIWindow *w in [UIApplication sharedApplication].windows){
   if([w class]==[UIWindow class]||w.rootViewController){window=w;break;}
  }
  if(!window)return;

  static BOOL gesturesInstalled=NO;
  if(!gesturesInstalled){
   gesturesInstalled=YES;
   // 1. Edge Pan Left (ปัดจากขอบซ้ายเข้ามา)
   UIScreenEdgePanGestureRecognizer *edgeLeft=[[UIScreenEdgePanGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
   edgeLeft.edges=UIRectEdgeLeft;
   edgeLeft.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
   [window addGestureRecognizer:edgeLeft];

   // 2. Edge Pan Right (ปัดจากขอบขวาเข้ามา)
   UIScreenEdgePanGestureRecognizer *edgeRight=[[UIScreenEdgePanGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
   edgeRight.edges=UIRectEdgeRight;
   edgeRight.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
   [window addGestureRecognizer:edgeRight];

   // 3. Two-Finger Swipe Down (2 นิ้วปัดลงที่ไหนก็ได้บนจอ)
   UISwipeGestureRecognizer *swipe2Down=[[UISwipeGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
   swipe2Down.numberOfTouchesRequired=2;
   swipe2Down.direction=UISwipeGestureRecognizerDirectionDown;
   swipe2Down.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
   [window addGestureRecognizer:swipe2Down];

   // 4. Two-Finger Swipe Left (2 นิ้วปัดซ้าย)
   UISwipeGestureRecognizer *swipe2Left=[[UISwipeGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
   swipe2Left.numberOfTouchesRequired=2;
   swipe2Left.direction=UISwipeGestureRecognizerDirectionLeft;
   swipe2Left.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
   [window addGestureRecognizer:swipe2Left];

   // 5. Two-Finger Swipe Right (2 นิ้วปัดขวา)
   UISwipeGestureRecognizer *swipe2Right=[[UISwipeGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
   swipe2Right.numberOfTouchesRequired=2;
   swipe2Right.direction=UISwipeGestureRecognizerDirectionRight;
   swipe2Right.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
   [window addGestureRecognizer:swipe2Right];
  }

  static TRDFloatingHome *btn;
  if(!btn){
   btn=[TRDFloatingHome buttonWithType:UIButtonTypeCustom];
   CGRect screen = window.bounds;
   CGFloat sw = screen.size.width;
   CGFloat sh = screen.size.height;
   // Place at bottom right (above tab bar) so it never blocks top navigation back buttons
   btn.frame=CGRectMake(sw - 116, sh - 105, 100, 44);
   btn.backgroundColor=[UIColor colorWithRed:.10 green:.02 blue:.04 alpha:0.92];
   btn.layer.cornerRadius=8;
   btn.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin;
   btn.layer.borderWidth=1;
   btn.layer.borderColor=[UIColor colorWithRed:1 green:.12 blue:.18 alpha:0.85].CGColor;
   btn.layer.zPosition=9999;
   [btn setTitle:@"\xE2\x80\xB9 TRD" forState:UIControlStateNormal];
   [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
   btn.titleLabel.font=[UIFont boldSystemFontOfSize:15];
   btn.accessibilityLabel=@"Return to TRD dashboard";btn.accessibilityIdentifier=@"trd.return.home";
   [btn addTarget:btn action:@selector(goHome) forControlEvents:UIControlEventTouchUpInside];
   UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:btn action:@selector(dragged:)];
   [btn addGestureRecognizer:pan];
   [NSTimer scheduledTimerWithTimeInterval:2 target:[TRDFloatingHome class] selector:@selector(installIfNeeded) userInfo:nil repeats:YES];
  }
  if(btn.superview!=window)[window addSubview:btn];
  CGRect frame=btn.frame;frame.origin.x=MAX(12,MIN(frame.origin.x,window.bounds.size.width-frame.size.width-12));frame.origin.y=MAX(20,MIN(frame.origin.y,window.bounds.size.height-frame.size.height-61));btn.frame=frame;
  [window bringSubviewToFront:btn];
 });
}
-(void)dragged:(UIPanGestureRecognizer *)p{
 if(!self.superview)return;
 CGPoint t=[p translationInView:self.superview];
 CGPoint c=CGPointMake(self.center.x+t.x,self.center.y+t.y);
 CGRect bounds=self.superview.bounds;
 CGFloat hw=self.bounds.size.width/2.0,hh=self.bounds.size.height/2.0;
 c.x=MAX(hw,MIN(bounds.size.width-hw,c.x));
 c.y=MAX(hh,MIN(bounds.size.height-hh,c.y));
 self.center=c;
 [p setTranslation:CGPointMake(0,0) inView:self.superview];
}
@end

@interface NSObject(TRDBrowsePlayer)
-(id)player;
@end
@protocol TRDBrowseNinjaPlayer<NSObject>
-(BOOL)isPlaying;
-(double)currentTime;
-(NSInteger)currentIndex;
-(NSArray *)queue;
@end
@interface NSObject(TRDBrowseTrack)
-(NSString *)videoId;
@end
@interface TRDBrowseReturn:NSObject
@property NSTimer *timer;
@property id source;
@property NSString *token,*oldTitle;
@property NSString *expectedTrackID;
@property id item;
@property double lastTime;
@property NSDate *deadline;
+(void)selected:(id)source;
-(void)tick;
-(void)stop;
@end
static TRDBrowseReturn *bridge;
static id networkRouteObserver;
@implementation TRDBrowseReturn
+(void)selected:(id)source{dispatch_async(dispatch_get_main_queue(),^{
 NSDictionary *arm=[NSDictionary dictionaryWithContentsOfFile:Arm];NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
 if([bundle isEqual:@"com.legacymusic.app"]&&[UIApplication sharedApplication].applicationState==UIApplicationStateActive){
  NSArray *queue=[(id<TRDBrowseNinjaPlayer>)source queue];NSInteger index=[(id<TRDBrowseNinjaPlayer>)source currentIndex];if(index<0||index>=(NSInteger)queue.count)return;
  arm=@{@"bundle":bundle,@"token":[NSUUID UUID].UUIDString,@"pending":@YES,@"created":[NSDate date],@"expires":[NSDate dateWithTimeIntervalSinceNow:30],@"baselineTitle":@"",@"origin":@"ninja-playback-any-entry"};if(![arm writeToFile:Arm atomically:YES])return;
 }
 if(![arm[@"pending"]boolValue]||![arm[@"bundle"]isEqual:bundle]||![arm[@"expires"]isKindOfClass:[NSDate class]]||[arm[@"expires"]timeIntervalSinceNow]<=0||[UIApplication sharedApplication].applicationState!=UIApplicationStateActive)return;
 if(!bridge){bridge=[TRDBrowseReturn new];[[NSNotificationCenter defaultCenter]addObserver:bridge selector:@selector(stop) name:UIApplicationDidEnterBackgroundNotification object:nil];}[bridge stop];bridge.source=source;bridge.token=arm[@"token"];bridge.oldTitle=arm[@"baselineTitle"]?:@"";bridge.lastTime=-1;bridge.deadline=[NSDate dateWithTimeIntervalSinceNow:25];
 if([bundle isEqual:@"com.legacymusic.app"]){NSArray *queue=[(id<TRDBrowseNinjaPlayer>)source queue];NSInteger index=[(id<TRDBrowseNinjaPlayer>)source currentIndex];id track=index>=0&&index<(NSInteger)queue.count?queue[index]:nil;bridge.expectedTrackID=[track respondsToSelector:@selector(videoId)]?[track videoId]:nil;}
 bridge.timer=[NSTimer scheduledTimerWithTimeInterval:.5 target:bridge selector:@selector(tick) userInfo:nil repeats:YES];
 [@{@"event":@"selection",@"bundle":bundle,@"token":bridge.token?:@""}writeToFile:Log atomically:YES];
 });}
-(void)stop{[self.timer invalidate];self.timer=nil;self.source=nil;self.item=nil;self.expectedTrackID=nil;}
-(void)tick{
 NSDictionary *arm=[NSDictionary dictionaryWithContentsOfFile:Arm];NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
 if([UIApplication sharedApplication].applicationState!=UIApplicationStateActive||![arm[@"pending"]boolValue]||![arm[@"token"]isEqual:self.token]||![arm[@"bundle"]isEqual:bundle]||[arm[@"expires"]timeIntervalSinceNow]<=0||[self.deadline timeIntervalSinceNow]<=0){[self stop];return;}
 BOOL ready=NO;
 if([bundle isEqual:@"com.legacymusic.app"]){id<TRDBrowseNinjaPlayer> player=self.source;NSArray *queue=[player queue];NSInteger index=[player currentIndex];id track=index>=0&&index<(NSInteger)queue.count?queue[index]:nil;NSString *key=[track respondsToSelector:@selector(videoId)]?[track videoId]:nil;double time=[player currentTime];ready=self.expectedTrackID.length&&[key isEqual:self.expectedTrackID]&&[player isPlaying]&&isfinite(time)&&self.lastTime>=0&&time>self.lastTime+.05;self.lastTime=isfinite(time)?time:-1;}
 else {
 id candidate=[self.source respondsToSelector:@selector(player)]?[self.source player]:nil;
 if(![candidate isKindOfClass:[AVPlayer class]]&&![candidate isKindOfClass:[AVAudioPlayer class]]){unsigned count=0;Ivar *vars=class_copyIvarList([self.source class],&count);for(unsigned i=0;i<count;i++){const char *type=ivar_getTypeEncoding(vars[i]);NSString *name=[NSString stringWithUTF8String:ivar_getName(vars[i])];if(type&&type[0]=='@'&&[name.lowercaseString containsString:@"player"]){id object=object_getIvar(self.source,vars[i]);if([object isKindOfClass:[AVPlayer class]]||[object isKindOfClass:[AVAudioPlayer class]]){candidate=object;break;}}}free(vars);}

 if([candidate isKindOfClass:[AVPlayer class]]){AVPlayer *p=candidate;AVPlayerItem *item=p.currentItem;double time=CMTimeGetSeconds(p.currentTime);if(item!=self.item){self.item=item;self.lastTime=-1;}ready=item.status==AVPlayerItemStatusReadyToPlay&&p.rate>0&&isfinite(time)&&self.lastTime>=0&&time>self.lastTime+.05;self.lastTime=isfinite(time)?time:-1;}
 else if([candidate isKindOfClass:[AVAudioPlayer class]]){AVAudioPlayer *p=candidate;double time=p.currentTime;if(self.item!=p){self.item=p;self.lastTime=-1;}ready=p.playing&&isfinite(time)&&self.lastTime>=0&&time>self.lastTime+.05;self.lastTime=time;}
 else {NSDictionary *info=[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;NSString *title=info[MPMediaItemPropertyTitle];ready=[info[MPNowPlayingInfoPropertyPlaybackRate]doubleValue]>0&&title.length&&![title isEqual:self.oldTitle];}
 }

 if(!ready)return;
 NSMutableDictionary *done=[arm mutableCopy];done[@"pending"]=@NO;done[@"returned"]=@YES;done[@"returnedAt"]=[NSDate date];if(![done writeToFile:Arm atomically:YES]){[self stop];return;}
 [@{@"event":@"returned",@"bundle":bundle,@"token":self.token?:@""}writeToFile:Log atomically:YES];
 [self stop];[[UIApplication sharedApplication]openURL:[NSURL URLWithString:[bundle isEqual:@"com.legacymusic.app"]?@"cardash://home":@"cardash://music"]];
}
@end
#import "RoadAudio.h"
#import "TRDNinjaAutoplay.h"
static void(*oldMusic)(id,SEL,id,NSUInteger);
static void Music(id obj,SEL sel,id queue,NSUInteger index){if(!TRDAutoStarting)TRDManualPlaybackOverride(@"manual-selection");if(!TRDAutoStarting)queue=TRDExpandQueue(obj,queue,&index);oldMusic(obj,sel,queue,index);if(!TRDAutoStarting){TRDSaveQueue();[TRDBrowseReturn selected:obj];}[TRDRoadAudio install];}
static void(*oldPause)(id,SEL);
static void AutoPause(id obj,SEL sel){if(!TRDAutoStarting)TRDManualPlaybackOverride(@"manual-pause");oldPause(obj,sel);TRDSaveQueue();}
static void(*oldSeek)(id,SEL,double);
static void AutoSeek(id obj,SEL sel,double seconds){if(!TRDAutoStarting)TRDManualPlaybackOverride(@"manual-seek");oldSeek(obj,sel,seconds);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{TRDSaveQueue();});}
static void(*oldToggle)(id,SEL);
static void NinjaToggle(id obj,SEL sel){BOOL wasPlaying=[(id<TRDBrowseNinjaPlayer>)obj isPlaying];oldToggle(obj,sel);if(!wasPlaying&&!TRDAutoStarting&&!TRDAutoRestoring)[TRDBrowseReturn selected:obj];}
static void(*oldYT)(id,SEL,id,double);
static void YouTube(id obj,SEL sel,id watch,double at){oldYT(obj,sel,watch,at);[TRDRoadAudio install];[TRDBrowseReturn selected:obj];}
static void(*oldPod)(id,SEL,NSInteger);
static void Podcast(id obj,SEL sel,NSInteger index){oldPod(obj,sel,index);[TRDBrowseReturn selected:obj];}
static BOOL TypeIs(const char *allowed,char value){for(const char *p=allowed;*p;p++)if(*p==value)return YES;return NO;}
static BOOL Signature(Method method,const char *a,const char *b){if(!method||method_getNumberOfArguments(method)!=(b?4:3))return NO;char *r=method_copyReturnType(method),*x=method_copyArgumentType(method,2),*y=b?method_copyArgumentType(method,3):NULL;BOOL ok=r&&r[0]=='v'&&x&&TypeIs(a,x[0])&&(!b||(y&&TypeIs(b,y[0])));free(r);free(x);free(y);return ok;}

// Ninja Fullscreen Landscape Hooks
static void (*orig_SplitContainer_viewDidLayoutSubviews)(id, SEL);
static void Hook_SplitContainer_viewDidLayoutSubviews(id self, SEL _cmd) {
 if(orig_SplitContainer_viewDidLayoutSubviews) orig_SplitContainer_viewDidLayoutSubviews(self, _cmd);
 UIViewController *vc = (UIViewController *)self;
 UIWindow *win = vc.view.window ?: [UIApplication sharedApplication].keyWindow;
 CGRect bounds = win ? win.bounds : [UIScreen mainScreen].bounds;
 if(bounds.size.width < bounds.size.height) bounds = CGRectMake(0, 0, bounds.size.height, bounds.size.width);
 vc.view.frame = bounds;

 UIView *sidebar = [self respondsToSelector:@selector(sidebarView)] ? [self sidebarView] : nil;
 if(sidebar){
  sidebar.hidden = YES;
  sidebar.frame = CGRectMake(0, 0, 0, 0);
 }

 UIViewController *tab = [self respondsToSelector:@selector(tabController)] ? [self tabController] : nil;
 if(tab && tab.view){
  tab.view.frame = bounds;
  if([tab isKindOfClass:[UITabBarController class]]){
   UITabBarController *tbc = (UITabBarController *)tab;
   if(tbc.selectedViewController && tbc.selectedViewController.view){
    tbc.selectedViewController.view.frame = bounds;
    if([tbc.selectedViewController isKindOfClass:[UINavigationController class]]){
     UINavigationController *nav = (UINavigationController *)tbc.selectedViewController;
     if(nav.topViewController && nav.topViewController.view){
      nav.topViewController.view.frame = bounds;
     }
    }
   }
  }
 }
}

static void (*orig_TabBar_viewDidLayoutSubviews)(id, SEL);
static void Hook_TabBar_viewDidLayoutSubviews(id self, SEL _cmd) {
 if(orig_TabBar_viewDidLayoutSubviews) orig_TabBar_viewDidLayoutSubviews(self, _cmd);
 UITabBarController *tbc = (UITabBarController *)self;
 UIWindow *win = tbc.view.window ?: [UIApplication sharedApplication].keyWindow;
 CGRect bounds = win ? win.bounds : [UIScreen mainScreen].bounds;
 if(bounds.size.width < bounds.size.height) bounds = CGRectMake(0, 0, bounds.size.height, bounds.size.width);
 tbc.view.frame = bounds;

 CGFloat barH = (tbc.tabBar.frame.size.height > 20 ? tbc.tabBar.frame.size.height : 49.0);
 CGRect barFrame = CGRectMake(0, bounds.size.height - barH, bounds.size.width, barH);
 tbc.tabBar.frame = barFrame;
 tbc.tabBar.hidden = NO;
 [tbc.view bringSubviewToFront:tbc.tabBar];

 CGRect contentFrame = CGRectMake(0, 0, bounds.size.width, bounds.size.height - barH);
 if(tbc.selectedViewController && tbc.selectedViewController.view){
  tbc.selectedViewController.view.frame = contentFrame;
  if([tbc.selectedViewController isKindOfClass:[UINavigationController class]]){
   UINavigationController *nav = (UINavigationController *)tbc.selectedViewController;
   if(nav.topViewController && nav.topViewController.view){
    nav.topViewController.view.frame = contentFrame;
   }
  }
 }
}

static BOOL Hook_ShouldForcePortrait(id self, SEL _cmd, int index) {
 return NO;
}

static void Hook_EnforcePortrait(id self, SEL _cmd, int index) {
}

static NSUInteger Hook_SupportedOrientations(id self, SEL _cmd) {
 return UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;
}

static BOOL Hook_ShouldAutorotate(id self, SEL _cmd) {
 return YES;
}

__attribute__((constructor))static void Install(void){@autoreleasepool{
 NSString *bundle=NSBundle.mainBundle.bundleIdentifier;NSString *name=nil,*selector=nil;IMP replacement=NULL;IMP *original=NULL;const char *a=NULL,*b=NULL;
 if([@[@"com.legacymusic.app",@"com.himais0giiiin.ytnine",@"com.codex.poddash"]containsObject:bundle]){
  networkRouteObserver=[[NSNotificationCenter defaultCenter]addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){
   [@{@"bundle":NSBundle.mainBundle.bundleIdentifier,@"at":[NSDate date]}writeToFile:@"/var/mobile/codex-car/last-media.plist" atomically:YES];
   notify_post("com.codex.trd.network.internet");
   [TRDFloatingHome installIfNeeded];
   if([bundle isEqual:@"com.legacymusic.app"]){TRDNormalizeNinjaOutput();TRDAutoPlayIfRequested();[TRDRoadAudio install];}
   if([bundle isEqual:@"com.legacymusic.app"]){
    dispatch_async(dispatch_get_main_queue(),^{
     NSDictionary *arm=[NSDictionary dictionaryWithContentsOfFile:Arm];
     if([arm[@"pending"] boolValue] && [arm[@"bundle"] isEqual:@"com.legacymusic.app"]){
      UIWindow *w = [UIApplication sharedApplication].keyWindow;
      UIViewController *root = w.rootViewController;
      if([root respondsToSelector:@selector(tabController)]){
       UITabBarController *tbc = (UITabBarController *)[root performSelector:@selector(tabController)];
       if(tbc && [tbc isKindOfClass:[UITabBarController class]]){
        if(tbc.selectedIndex == 4){
         [tbc setSelectedIndex:1];
        }
        if([tbc.selectedViewController isKindOfClass:[UINavigationController class]]){
         UINavigationController *nav = (UINavigationController *)tbc.selectedViewController;
         if(nav.viewControllers.count > 1){
          [nav popToRootViewControllerAnimated:NO];
         }
        }
       }
      }
     }
    });
   }
  }];
  [[NSNotificationCenter defaultCenter]addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){
   [TRDFloatingHome installIfNeeded];
  }];
  dispatch_async(dispatch_get_main_queue(),^{
   if([UIApplication sharedApplication].applicationState==UIApplicationStateActive){
    if([bundle isEqual:@"com.legacymusic.app"])TRDNormalizeNinjaOutput();
    [@{@"bundle":NSBundle.mainBundle.bundleIdentifier,@"at":[NSDate date]}writeToFile:@"/var/mobile/codex-car/last-media.plist" atomically:YES];
    notify_post("com.codex.trd.network.internet");
   }
   [TRDFloatingHome installIfNeeded];
  });
 }
 if([bundle isEqual:@"com.legacymusic.app"]){
  TRDAutoPlayIfRequested();TRDSaveQueueLoop();
  for(NSString *event in @[UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,UIApplicationWillTerminateNotification])[[NSNotificationCenter defaultCenter]addObserverForName:event object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){TRDSaveQueue();}];
  [[NSNotificationCenter defaultCenter]addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){TRDAudioInterrupted=[note.userInfo[AVAudioSessionInterruptionTypeKey]unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan;if(TRDAudioInterrupted)TRDCancelAutoResume(@"audio-interrupted");TRDSaveQueue();}];
  Class playerClass=NSClassFromString(@"LTPlayerController");Method pause=class_getInstanceMethod(playerClass,@selector(pausePlayback));if(pause&&method_getNumberOfArguments(pause)==2){char *type=method_copyReturnType(pause);if(type&&type[0]=='v')oldPause=(void(*)(id,SEL))method_setImplementation(pause,(IMP)AutoPause);free(type);}
  Method seek=class_getInstanceMethod(playerClass,@selector(seekToTime:));if(Signature(seek,"d",NULL))oldSeek=(void(*)(id,SEL,double))method_setImplementation(seek,(IMP)AutoSeek);
  Method toggle=class_getInstanceMethod(playerClass,NSSelectorFromString(@"togglePlayPause"));if(toggle&&method_getNumberOfArguments(toggle)==2){char *type=method_copyReturnType(toggle);if(type&&type[0]=='v')oldToggle=(void(*)(id,SEL))method_setImplementation(toggle,(IMP)NinjaToggle);free(type);}

   name=@"LTPlayerController";selector=@"playQueue:atIndex:";replacement=(IMP)Music;original=(IMP *)&oldMusic;a="@";b="iI";
  
  Class tabCls = NSClassFromString(@"LTTabBarController");
  if(tabCls){
   Method mForce = class_getInstanceMethod(tabCls, NSSelectorFromString(@"shouldForcePortraitForIndex:"));
   if(mForce) method_setImplementation(mForce, (IMP)Hook_ShouldForcePortrait);
   Method mEnforce = class_getInstanceMethod(tabCls, NSSelectorFromString(@"enforcePortraitAwayFromPlayerForIndex:"));
   if(mEnforce) method_setImplementation(mEnforce, (IMP)Hook_EnforcePortrait);
   Method mOri = class_getInstanceMethod(tabCls, @selector(supportedInterfaceOrientations));
   if(mOri) method_setImplementation(mOri, (IMP)Hook_SupportedOrientations);
   Method mAuto = class_getInstanceMethod(tabCls, @selector(shouldAutorotate));
   if(mAuto) method_setImplementation(mAuto, (IMP)Hook_ShouldAutorotate);
   Method mLayout = class_getInstanceMethod(tabCls, @selector(viewDidLayoutSubviews));
   if(mLayout) orig_TabBar_viewDidLayoutSubviews = (void(*)(id,SEL))method_setImplementation(mLayout, (IMP)Hook_TabBar_viewDidLayoutSubviews);
  }
  Class splitCls = NSClassFromString(@"LTSplitContainerViewController");
  if(splitCls){
   Method mOri = class_getInstanceMethod(splitCls, @selector(supportedInterfaceOrientations));
   if(mOri) method_setImplementation(mOri, (IMP)Hook_SupportedOrientations);
   Method mAuto = class_getInstanceMethod(splitCls, @selector(shouldAutorotate));
   if(mAuto) method_setImplementation(mAuto, (IMP)Hook_ShouldAutorotate);
   Method mLayout = class_getInstanceMethod(splitCls, @selector(viewDidLayoutSubviews));
   if(mLayout) orig_SplitContainer_viewDidLayoutSubviews = (void(*)(id,SEL))method_setImplementation(mLayout, (IMP)Hook_SplitContainer_viewDidLayoutSubviews);
  }
  dispatch_async(dispatch_get_main_queue(),^{
   [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationLandscapeRight) forKey:@"orientation"];
   [UIViewController attemptRotationToDeviceOrientation];
   UIWindow *w = [UIApplication sharedApplication].keyWindow;
   if(w){
    CGRect b = [UIScreen mainScreen].bounds;
    if(b.size.width < b.size.height) b = CGRectMake(0, 0, b.size.height, b.size.width);
    w.frame = b;
    if(w.rootViewController){
     w.rootViewController.view.frame = b;
     [w.rootViewController.view setNeedsLayout];
     [w.rootViewController.view layoutIfNeeded];
     if([w.rootViewController respondsToSelector:@selector(tabController)]){
      UITabBarController *tbc = (UITabBarController *)[w.rootViewController performSelector:@selector(tabController)];
      if(tbc && [tbc isKindOfClass:[UITabBarController class]]){
       NSDictionary *arm=[NSDictionary dictionaryWithContentsOfFile:Arm];
       if([arm[@"pending"] boolValue] && [arm[@"bundle"] isEqual:@"com.legacymusic.app"]){
        if(tbc.selectedIndex == 4){
         [tbc setSelectedIndex:1];
        }
       }
      }
     }
    }
   }
  });
 }
 else if([bundle isEqual:@"com.himais0giiiin.ytnine"]){name=@"YTPlayback";selector=@"loadWatch:startAt:";replacement=(IMP)YouTube;original=(IMP *)&oldYT;a="@";b="d";}
 else if([bundle isEqual:@"com.codex.poddash"]){name=@"Podcasts";selector=@"playIndex:";replacement=(IMP)Podcast;original=(IMP *)&oldPod;a="i";}
 else return;
 Class cls=NSClassFromString(name);SEL sel=NSSelectorFromString(selector);Method method=class_getInstanceMethod(cls,sel);BOOL valid=Signature(method,a,b);BOOL installed=valid;
 if(installed)*original=method_setImplementation(method,replacement);
 if([bundle isEqual:@"com.himais0giiiin.ytnine"]){Method remote=class_getInstanceMethod(NSClassFromString(@"YTAppDelegate"),@selector(remoteControlReceivedWithEvent:));if(Signature(remote,"@",NULL))oldRemote=(void(*)(id,SEL,UIEvent *))method_setImplementation(remote,(IMP)RoadRemote);}
if([bundle isEqual:@"com.legacymusic.app"]){Method remote=class_getInstanceMethod(NSClassFromString(@"LTAppDelegate"),@selector(remoteControlReceivedWithEvent:));if(Signature(remote,"@",NULL))oldRemote=(void(*)(id,SEL,UIEvent *))method_setImplementation(remote,(IMP)RoadRemote);[TRDRoadAudio install];}
 NSString *path=[NSString stringWithFormat:@"/var/mobile/codex-car/browse-hook-%@.plist",name];[@{@"installed":@(installed),@"signature":method?[NSString stringWithUTF8String:method_getTypeEncoding(method)]:@"missing",@"class":name,@"selector":selector,@"bundle":bundle}writeToFile:path atomically:YES];
}}
