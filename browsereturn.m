#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <unistd.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <notify.h>
static NSString *const Arm=@"/var/mobile/codex-car/browse-return.plist";
static NSString *const Log=@"/var/mobile/codex-car/browse-return-state.plist";
static NSString *const VoiceSearchPlist=@"/var/mobile/codex-car/voice-search.plist";
static NSString *const VoiceSearchLog=@"/var/mobile/codex-car/voice-search-state.plist";

@protocol TRDLTYouTubeClient <NSObject>
+(instancetype)sharedClient;
-(void)searchVideosWithQuery:(NSString *)query completion:(void (^)(NSArray *tracks, NSError *error))completion;
@end
@protocol TRDLTPlayerController <NSObject>
+(instancetype)sharedController;
-(void)playQueue:(NSArray *)tracks atIndex:(NSInteger)index;
-(BOOL)isPlaying;
-(double)currentTime;
@end

@interface TRDFloatingHome: UIButton <UIGestureRecognizerDelegate>
+(void)installIfNeeded;
+(void)goHome;
+(void)onGesture:(UIGestureRecognizer *)g;
@end

@implementation TRDFloatingHome
static CFAbsoluteTime gTRDLastGoHomeAt = 0;
static const void *kTRDGesturesInstalledKey = &kTRDGesturesInstalledKey;

+(void)goHome{
 dispatch_async(dispatch_get_main_queue(),^{
  CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
  if(now - gTRDLastGoHomeAt < 0.55) return;
  gTRDLastGoHomeAt = now;
  NSURL *dashURL = [NSURL URLWithString:@"cardash://home"];
  UIApplication *app = [UIApplication sharedApplication];
  if(dashURL && [app respondsToSelector:@selector(openURL:options:completionHandler:)]){
   [app openURL:dashURL options:@{} completionHandler:^(BOOL success){
    if(!success){
     notify_post("com.codex.trd.launch.cardash");
    }
   }];
  } else if(dashURL){
   [app openURL:dashURL];
  }
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
   if([UIApplication sharedApplication].applicationState == UIApplicationStateActive){
    notify_post("com.codex.trd.launch.cardash");
   }
  });
 });
}
-(void)goHome{
 [[self class] goHome];
}
+(void)onGesture:(UIGestureRecognizer *)g{
 if([g isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]){
  UIScreenEdgePanGestureRecognizer *ep = (UIScreenEdgePanGestureRecognizer *)g;
  CGPoint trans = [ep translationInView:ep.view];
  if(ep.state == UIGestureRecognizerStateEnded ||
     (ep.state == UIGestureRecognizerStateChanged && fabs(trans.x) >= 24.0)){
   [self goHome];
  }
 } else if([g isKindOfClass:[UISwipeGestureRecognizer class]]){
  if(g.state==UIGestureRecognizerStateRecognized){
   [self goHome];
  }
 }
}
+(BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g{
 if([g isKindOfClass:[UISwipeGestureRecognizer class]]){
  UISwipeGestureRecognizer *sw = (UISwipeGestureRecognizer *)g;
  if(sw.numberOfTouchesRequired == 1 && sw.view){
   CGPoint pt = [sw locationInView:sw.view];
   CGFloat w = sw.view.bounds.size.width;
   BOOL inSideZone = (pt.x <= 140.0 || pt.x >= (w - 140.0));
   UIView *hit = [sw.view hitTest:pt withEvent:nil];
   for(UIView *v = hit; v && v != sw.view; v = v.superview){
    if([v isKindOfClass:[UISlider class]] || [NSStringFromClass([v class]) containsString:@"Scrubber"]){
     return inSideZone;
    }
    if([v isKindOfClass:[UIScrollView class]]){
     UIScrollView *sv = (UIScrollView *)v;
     if(sv.contentSize.width > sv.bounds.size.width + 24.0){
      return inSideZone;
     }
    }
   }
  }
 }
 return YES;
}
+(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
 return YES;
}
+(void)attachGesturesToWindow:(UIWindow *)window{
 if(!window)return;
 if([objc_getAssociatedObject(window, kTRDGesturesInstalledKey) boolValue])return;
 objc_setAssociatedObject(window, kTRDGesturesInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

 // 1. Edge Pan Left (ปัดขวาจากขอบซ้ายเข้ามา)
 UIScreenEdgePanGestureRecognizer *edgeLeft=[[UIScreenEdgePanGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
 edgeLeft.edges=UIRectEdgeLeft;
 edgeLeft.cancelsTouchesInView=NO;
 edgeLeft.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
 [window addGestureRecognizer:edgeLeft];

 // 2. Edge Pan Right (ปัดซ้ายจากขอบขวาเข้ามา)
 UIScreenEdgePanGestureRecognizer *edgeRight=[[UIScreenEdgePanGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
 edgeRight.edges=UIRectEdgeRight;
 edgeRight.cancelsTouchesInView=NO;
 edgeRight.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
 [window addGestureRecognizer:edgeRight];

 // 3. One-Finger Swipe Left & Right (1 นิ้วปัดซ้าย / ปัดขวา กลับเข้า Dashboard)
 UISwipeGestureRecognizer *swipe1Left=[[UISwipeGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
 swipe1Left.numberOfTouchesRequired=1;
 swipe1Left.direction=UISwipeGestureRecognizerDirectionLeft;
 swipe1Left.cancelsTouchesInView=NO;
 swipe1Left.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
 [window addGestureRecognizer:swipe1Left];

 UISwipeGestureRecognizer *swipe1Right=[[UISwipeGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
 swipe1Right.numberOfTouchesRequired=1;
 swipe1Right.direction=UISwipeGestureRecognizerDirectionRight;
 swipe1Right.cancelsTouchesInView=NO;
 swipe1Right.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
 [window addGestureRecognizer:swipe1Right];

 // 4. Two-Finger Swipe Down / Left / Right (2 นิ้วปัดเป็นทางลัดเสริมทุกจุดบนหน้าจอ)
 UISwipeGestureRecognizer *swipe2Down=[[UISwipeGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
 swipe2Down.numberOfTouchesRequired=2;
 swipe2Down.direction=UISwipeGestureRecognizerDirectionDown;
 swipe2Down.cancelsTouchesInView=NO;
 swipe2Down.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
 [window addGestureRecognizer:swipe2Down];

 UISwipeGestureRecognizer *swipe2Left=[[UISwipeGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
 swipe2Left.numberOfTouchesRequired=2;
 swipe2Left.direction=UISwipeGestureRecognizerDirectionLeft;
 swipe2Left.cancelsTouchesInView=NO;
 swipe2Left.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
 [window addGestureRecognizer:swipe2Left];

 UISwipeGestureRecognizer *swipe2Right=[[UISwipeGestureRecognizer alloc]initWithTarget:[TRDFloatingHome class] action:@selector(onGesture:)];
 swipe2Right.numberOfTouchesRequired=2;
 swipe2Right.direction=UISwipeGestureRecognizerDirectionRight;
 swipe2Right.cancelsTouchesInView=NO;
 swipe2Right.delegate=(id<UIGestureRecognizerDelegate>)[TRDFloatingHome class];
 [window addGestureRecognizer:swipe2Right];
}
+(void)installIfNeeded{
 dispatch_async(dispatch_get_main_queue(),^{
  UIWindow *window=[UIApplication sharedApplication].keyWindow;
  if(!window || window.windowLevel > UIWindowLevelNormal){
   for(UIWindow *w in [UIApplication sharedApplication].windows){
    if(w.windowLevel == UIWindowLevelNormal && ([w class]==[UIWindow class]||w.rootViewController)){window=w;break;}
   }
  }
  if(!window)return;

  [self attachGesturesToWindow:window];

  static TRDFloatingHome *btn;
  if(!btn){
   btn=[TRDFloatingHome buttonWithType:UIButtonTypeCustom];
   CGRect screen = window.bounds;
   CGFloat sw = screen.size.width;
   CGFloat sh = screen.size.height;
   NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
   CGFloat bx = [ud objectForKey:@"TRDFloatingHomeX"] ? [ud floatForKey:@"TRDFloatingHomeX"] : (sw - 134);
   CGFloat by = [ud objectForKey:@"TRDFloatingHomeY"] ? [ud floatForKey:@"TRDFloatingHomeY"] : (sh - 108);
   btn.frame=CGRectMake(bx, by, 122, 42);
   btn.backgroundColor=[UIColor colorWithRed:.08 green:.02 blue:.04 alpha:0.94];
   btn.layer.cornerRadius=21;
   btn.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin;
   btn.layer.borderWidth=1.5;
   btn.layer.borderColor=[UIColor colorWithRed:1.0 green:.20 blue:.26 alpha:0.92].CGColor;
   btn.layer.shadowColor=[UIColor blackColor].CGColor;
   btn.layer.shadowOpacity=0.65;
   btn.layer.shadowRadius=6;
   btn.layer.shadowOffset=CGSizeMake(0,2);
   btn.layer.zPosition=99999;
   [btn setTitle:@"\xE2\x80\xB9 DASHBOARD" forState:UIControlStateNormal];
   [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
   btn.titleLabel.font=[UIFont boldSystemFontOfSize:13.5];
   btn.accessibilityLabel=@"Return to TRD dashboard";btn.accessibilityIdentifier=@"trd.return.home";
   [btn addTarget:btn action:@selector(goHome) forControlEvents:UIControlEventTouchUpInside];

   // Allow left/right swipe directly on the shortcut button too; hold 0.30s to reposition it cleanly.
   UISwipeGestureRecognizer *btnSwL=[[UISwipeGestureRecognizer alloc]initWithTarget:btn action:@selector(goHome)];
   btnSwL.direction=UISwipeGestureRecognizerDirectionLeft;
   [btn addGestureRecognizer:btnSwL];
   UISwipeGestureRecognizer *btnSwR=[[UISwipeGestureRecognizer alloc]initWithTarget:btn action:@selector(goHome)];
   btnSwR.direction=UISwipeGestureRecognizerDirectionRight;
   [btn addGestureRecognizer:btnSwR];

   UILongPressGestureRecognizer *holdDrag=[[UILongPressGestureRecognizer alloc]initWithTarget:btn action:@selector(dragged:)];
   holdDrag.minimumPressDuration=0.30;
   [btn addGestureRecognizer:holdDrag];
  }
  btn.hidden=NO;
  if(btn.superview!=window)[window addSubview:btn];
  CGRect frame=btn.frame;frame.origin.x=MAX(12,MIN(frame.origin.x,window.bounds.size.width-frame.size.width-12));frame.origin.y=MAX(24,MIN(frame.origin.y,window.bounds.size.height-frame.size.height-58));btn.frame=frame;
  [window bringSubviewToFront:btn];
 });
}
-(void)dragged:(UILongPressGestureRecognizer *)p{
 if(!self.superview)return;
 static CGPoint grabOffset;
 CGPoint pt = [p locationInView:self.superview];
 if(p.state == UIGestureRecognizerStateBegan){
  grabOffset = CGPointMake(self.center.x - pt.x, self.center.y - pt.y);
  self.transform = CGAffineTransformMakeScale(1.06, 1.06);
 }else if(p.state == UIGestureRecognizerStateChanged){
  CGPoint c = CGPointMake(pt.x + grabOffset.x, pt.y + grabOffset.y);
  CGRect bounds=self.superview.bounds;
  CGFloat hw=self.bounds.size.width/2.0,hh=self.bounds.size.height/2.0;
  c.x=MAX(12+hw,MIN(bounds.size.width-hw-12,c.x));
  c.y=MAX(24+hh,MIN(bounds.size.height-hh-58,c.y));
  self.center=c;
 }else if(p.state == UIGestureRecognizerStateEnded || p.state == UIGestureRecognizerStateCancelled){
  self.transform = CGAffineTransformIdentity;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  [ud setFloat:self.frame.origin.x forKey:@"TRDFloatingHomeX"];
  [ud setFloat:self.frame.origin.y forKey:@"TRDFloatingHomeY"];
  [ud synchronize];
 }
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
 if([bundle isEqual:@"com.himais0giiiin.ytnine"]||[bundle isEqual:@"com.google.ios.youtube"])return; // Never auto-return from YouTube
 if([UIApplication sharedApplication].applicationState!=UIApplicationStateActive)return;
 BOOL isNinja=[bundle isEqual:@"com.legacymusic.app"];
 if(!isNinja && (![arm[@"pending"]boolValue]||![arm[@"bundle"]isEqual:bundle]||![arm[@"expires"]isKindOfClass:[NSDate class]]||[arm[@"expires"]timeIntervalSinceNow]<=0))return;
 if(!bridge){bridge=[TRDBrowseReturn new];[[NSNotificationCenter defaultCenter]addObserver:bridge selector:@selector(stop) name:UIApplicationDidEnterBackgroundNotification object:nil];}[bridge stop];bridge.source=source;bridge.token=arm[@"token"]?:@"auto-ninja";bridge.oldTitle=arm[@"baselineTitle"]?:@"";bridge.lastTime=-1;bridge.deadline=[NSDate dateWithTimeIntervalSinceNow:25];
 if(isNinja){NSArray *queue=[(id<TRDBrowseNinjaPlayer>)source queue];NSInteger index=[(id<TRDBrowseNinjaPlayer>)source currentIndex];id track=index>=0&&index<(NSInteger)queue.count?queue[index]:nil;bridge.expectedTrackID=[track respondsToSelector:@selector(videoId)]?[track videoId]:nil;}
 bridge.timer=[NSTimer scheduledTimerWithTimeInterval:.45 target:bridge selector:@selector(tick) userInfo:nil repeats:YES];
 [@{@"event":@"selection",@"bundle":bundle,@"token":bridge.token?:@""}writeToFile:Log atomically:YES];
 });}
-(void)stop{[self.timer invalidate];self.timer=nil;self.source=nil;self.item=nil;self.expectedTrackID=nil;}
-(void)tick{
 NSDictionary *arm=[NSDictionary dictionaryWithContentsOfFile:Arm];NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
 BOOL isNinja=[bundle isEqual:@"com.legacymusic.app"];
 if([UIApplication sharedApplication].applicationState!=UIApplicationStateActive||[self.deadline timeIntervalSinceNow]<=0){[self stop];return;}
 if(!isNinja && (![arm[@"pending"]boolValue]||![arm[@"token"]isEqual:self.token]||![arm[@"bundle"]isEqual:bundle]||[arm[@"expires"]timeIntervalSinceNow]<=0)){[self stop];return;}
 BOOL ready=NO;
 if(isNinja){id<TRDBrowseNinjaPlayer> player=self.source;NSArray *queue=[player queue];NSInteger index=[player currentIndex];id track=index>=0&&index<(NSInteger)queue.count?queue[index]:nil;NSString *key=[track respondsToSelector:@selector(videoId)]?[track videoId]:nil;double time=[player currentTime];ready=(!self.expectedTrackID.length||[key isEqual:self.expectedTrackID])&&[player isPlaying]&&isfinite(time)&&time>=0.45&&self.lastTime>=0&&time>self.lastTime+.02;self.lastTime=isfinite(time)?time:-1;}
 else {
 id candidate=[self.source respondsToSelector:@selector(player)]?[self.source player]:nil;
 if(![candidate isKindOfClass:[AVPlayer class]]&&![candidate isKindOfClass:[AVAudioPlayer class]]){unsigned count=0;Ivar *vars=class_copyIvarList([self.source class],&count);for(unsigned i=0;i<count;i++){const char *type=ivar_getTypeEncoding(vars[i]);NSString *name=[NSString stringWithUTF8String:ivar_getName(vars[i])];if(type&&type[0]=='@'&&[name.lowercaseString containsString:@"player"]){id object=object_getIvar(self.source,vars[i]);if([object isKindOfClass:[AVPlayer class]]||[object isKindOfClass:[AVAudioPlayer class]]){candidate=object;break;}}}free(vars);}

 if([candidate isKindOfClass:[AVPlayer class]]){AVPlayer *p=candidate;AVPlayerItem *item=p.currentItem;double time=CMTimeGetSeconds(p.currentTime);if(item!=self.item){self.item=item;self.lastTime=-1;}ready=item.status==AVPlayerItemStatusReadyToPlay&&p.rate>0&&isfinite(time)&&self.lastTime>=0&&time>self.lastTime+.05;self.lastTime=isfinite(time)?time:-1;}
 else if([candidate isKindOfClass:[AVAudioPlayer class]]){AVAudioPlayer *p=candidate;double time=p.currentTime;if(self.item!=p){self.item=p;self.lastTime=-1;}ready=p.playing&&isfinite(time)&&self.lastTime>=0&&time>self.lastTime+.05;self.lastTime=time;}
 else {NSDictionary *info=[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;NSString *title=info[MPMediaItemPropertyTitle];ready=[info[MPNowPlayingInfoPropertyPlaybackRate]doubleValue]>0&&title.length&&![title isEqual:self.oldTitle];}
 }

 if(!ready)return;
 if([arm isKindOfClass:[NSDictionary class]] && [arm[@"pending"] boolValue]){
  NSMutableDictionary *done=[arm mutableCopy];done[@"pending"]=@NO;done[@"returned"]=@YES;done[@"returnedAt"]=[NSDate date];[done writeToFile:Arm atomically:YES];
 }
 [@{@"event":@"returned",@"bundle":bundle,@"token":self.token?:@""}writeToFile:Log atomically:YES];
 [self stop];
 if(isNinja){
  @try {
   AVAudioSession *s = [AVAudioSession sharedInstance];
   [s setCategory:AVAudioSessionCategoryPlayback error:nil];
   [s setActive:YES error:nil];
  } @catch(NSException *e) {}
  __block UIBackgroundTaskIdentifier holdBg = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
   if(holdBg != UIBackgroundTaskInvalid){
    [[UIApplication sharedApplication] endBackgroundTask:holdBg];
    holdBg = UIBackgroundTaskInvalid;
   }
  }];
  if(holdBg != UIBackgroundTaskInvalid){
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(25.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
    if(holdBg != UIBackgroundTaskInvalid){
     [[UIApplication sharedApplication] endBackgroundTask:holdBg];
     holdBg = UIBackgroundTaskInvalid;
    }
   });
  }
  notify_post("com.codex.trd.launch.cardash");
 }
 [[UIApplication sharedApplication]openURL:[NSURL URLWithString:isNinja?@"cardash://home":@"cardash://music"]];
}
@end
#import "RoadAudio.h"
#import "TRDNinjaAutoplay.h"
static BOOL TRDVoiceSearchInFlight = NO;
static void(*oldMusic)(id,SEL,id,NSUInteger);
static void Music(id obj,SEL sel,id queue,NSUInteger index){if(!TRDAutoStarting)TRDManualPlaybackOverride(@"manual-selection");if(!TRDAutoStarting && !TRDVoiceSearchInFlight)queue=TRDExpandQueue(obj,queue,&index);oldMusic(obj,sel,queue,index);if(!TRDAutoStarting && !TRDVoiceSearchInFlight){TRDSaveQueue();[TRDBrowseReturn selected:obj];}[TRDRoadAudio install];}
static void(*oldPause)(id,SEL);
static BOOL TRDReversePaused = NO;
static void AutoPause(id obj,SEL sel){if(!TRDAutoStarting && !TRDReversePaused)TRDManualPlaybackOverride(@"manual-pause");oldPause(obj,sel);TRDSaveQueue();}
static void(*oldSeek)(id,SEL,double);
static void AutoSeek(id obj,SEL sel,double seconds){if(!TRDAutoStarting)TRDManualPlaybackOverride(@"manual-seek");oldSeek(obj,sel,seconds);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{TRDSaveQueue();});}
static void(*oldToggle)(id,SEL);
static void NinjaToggle(id obj,SEL sel){oldToggle(obj,sel);}
static void(*oldYT)(id,SEL,id,double);
static void YouTube(id obj,SEL sel,id watch,double at){gYTPlaybackInstance=obj;oldYT(obj,sel,watch,at);[TRDRoadAudio install];[TRDFloatingHome installIfNeeded];[@{@"bundle":@"com.himais0giiiin.ytnine",@"at":[NSDate date]}writeToFile:@"/var/mobile/codex-car/last-media.plist" atomically:YES];}
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

static void TRDReturnToCarDashNowWithBgTask(UIBackgroundTaskIdentifier bgTask){
 @try {
  AVAudioSession *s = [AVAudioSession sharedInstance];
  [s setCategory:AVAudioSessionCategoryPlayback error:nil];
  [s setActive:YES error:nil];
 } @catch(NSException *e) {}
 void (^fireReturn)(void) = ^{
  if([UIApplication sharedApplication].applicationState == UIApplicationStateActive){
   notify_post("com.codex.trd.launch.cardash");
   [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cardash://home"] options:@{} completionHandler:nil];
  }
 };
 fireReturn();
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.85*NSEC_PER_SEC)),dispatch_get_main_queue(),fireReturn);
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.90*NSEC_PER_SEC)),dispatch_get_main_queue(),fireReturn);
 if(bgTask != UIBackgroundTaskInvalid){
  UIBackgroundTaskIdentifier holdTask = bgTask;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(165.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   [[UIApplication sharedApplication] endBackgroundTask:holdTask];
  });
 }
}

static void TRDWaitAndReturnToCarDash(id<TRDLTPlayerController> player, int triesLeft, UIBackgroundTaskIdentifier bgTask){
 if(triesLeft <= 0){
  // Only return to CarDash if audio is actually playing; if still buffering, give AVPlayer time so iOS never suspends silent app!
  BOOL playingNow = [player respondsToSelector:@selector(isPlaying)] && [player isPlaying];
  if(playingNow) TRDReturnToCarDashNowWithBgTask(bgTask);
  else if(bgTask != UIBackgroundTaskInvalid) [[UIApplication sharedApplication] endBackgroundTask:bgTask];
  return;
 }
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.35*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  BOOL playing = [player respondsToSelector:@selector(isPlaying)] && [player isPlaying];
  double ct = [player respondsToSelector:@selector(currentTime)] ? [player currentTime] : 0.0;
  if(playing && isfinite(ct) && ct >= 0.85){
   TRDReturnToCarDashNowWithBgTask(bgTask);
  } else {
   TRDWaitAndReturnToCarDash(player, triesLeft - 1, bgTask);
  }
 });
}

static BOOL gVoiceSearchHandling = NO;
static void TRDHandleVoiceSearchIfPending(void){
 dispatch_async(dispatch_get_main_queue(),^{
  if(gVoiceSearchHandling) return;
  NSDictionary *req=[NSDictionary dictionaryWithContentsOfFile:VoiceSearchPlist];
  if(![req isKindOfClass:[NSDictionary class]])return;
  if(![req[@"pending"] boolValue])return;
  NSArray *rawItems = [req[@"items"] isKindOfClass:[NSArray class]] ? req[@"items"] : nil;
  NSInteger startIdx = [req[@"startIndex"] integerValue];
  NSString *q=[req[@"query"] isKindOfClass:[NSString class]]?req[@"query"]:@"";
  q=[q stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSDate *at=[req[@"at"] isKindOfClass:[NSDate class]]?req[@"at"]:nil;
  if((!q.length && !rawItems.count) || (at && [at timeIntervalSinceNow] < -40.0))return;

  gVoiceSearchHandling = YES;
  NSMutableDictionary *done=[req mutableCopy];
  done[@"pending"]=@NO;
  done[@"pickedAt"]=[NSDate date];
  [done writeToFile:VoiceSearchPlist atomically:YES];
  [@{@"status":@"searching",@"query":q?:@"queue",@"at":[NSDate date]} writeToFile:VoiceSearchLog atomically:YES];

  __block UIBackgroundTaskIdentifier bgTask = UIBackgroundTaskInvalid;
  bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
   if(bgTask != UIBackgroundTaskInvalid){
    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    bgTask = UIBackgroundTaskInvalid;
   }
  }];

  Class ytCls=NSClassFromString(@"LTYouTubeClient");
  if(!ytCls || ![ytCls respondsToSelector:@selector(sharedClient)]){
   gVoiceSearchHandling = NO;
   [@{@"status":@"no_yt_client",@"query":q?:@"",@"at":[NSDate date]} writeToFile:VoiceSearchLog atomically:YES];
   TRDReturnToCarDashNowWithBgTask(bgTask);
   return;
  }
  id<TRDLTYouTubeClient> yt=[ytCls sharedClient];

  // Multi-song Playlist Queue Mode (1, 2, 3, 4 continuous playback!)
  if(rawItems.count > 0){
   NSUInteger cap = MIN((NSUInteger)25, rawItems.count);
   NSMutableArray *slots = [NSMutableArray arrayWithCapacity:cap];
   for(NSUInteger i=0; i<cap; i++) [slots addObject:[NSNull null]];
   dispatch_group_t grp = dispatch_group_create();
   Class trackCls = NSClassFromString(@"LTTrack");
   for(NSUInteger i=0; i<cap; i++){
    NSString *entry = [rawItems[i] isKindOfClass:[NSString class]] ? rawItems[i] : @"";
    NSString *vid = nil, *title = entry;
    NSRange sep = [entry rangeOfString:@"::"];
    if(sep.location == 11){
     vid = [entry substringToIndex:11];
     title = [entry substringFromIndex:13];
    }
    if(vid.length == 11 && trackCls && [trackCls instancesRespondToSelector:NSSelectorFromString(@"setVideoId:")]){
     @try {
      id tr = [trackCls new];
      [tr setValue:vid forKey:@"videoId"];
      if(title.length) [tr setValue:title forKey:@"title"];
      slots[i] = tr;
      continue;
     } @catch(NSException *e){}
    }
    NSString *searchQ = title.length ? title : entry;
    if(!searchQ.length) continue;
    dispatch_group_enter(grp);
    [yt searchVideosWithQuery:searchQ completion:^(NSArray *tracks, NSError *err){
     dispatch_async(dispatch_get_main_queue(), ^{
      if(tracks.count > 0) slots[i] = tracks[0];
      dispatch_group_leave(grp);
     });
    }];
   }
   dispatch_group_notify(grp, dispatch_get_main_queue(), ^{
    gVoiceSearchHandling = NO;
    NSMutableArray *finalTracks = [NSMutableArray array];
    NSInteger mappedStart = 0;
    for(NSUInteger i=0; i<cap; i++){
     if((NSInteger)i == startIdx) mappedStart = (NSInteger)finalTracks.count;
     if(slots[i] != [NSNull null]) [finalTracks addObject:slots[i]];
    }
    if(finalTracks.count > 0){
     if(mappedStart >= (NSInteger)finalTracks.count) mappedStart = 0;
     @try {
      AVAudioSession *sess = [AVAudioSession sharedInstance];
      [sess setCategory:AVAudioSessionCategoryPlayback error:nil];
      [sess setActive:YES error:nil];
     } @catch(NSException *e){}
     TRDNormalizeNinjaOutput();
     Class plCls=NSClassFromString(@"LTPlayerController");
     id<TRDLTPlayerController> player=(plCls && [plCls respondsToSelector:@selector(sharedController)])?[plCls sharedController]:nil;
     if(player && [player respondsToSelector:@selector(playQueue:atIndex:)]){
      TRDVoiceSearchInFlight = YES;
      [player playQueue:finalTracks atIndex:mappedStart];
      TRDVoiceSearchInFlight = NO;
      TRDSaveQueue();
      [@{@"status":@"playing_queue",@"count":@(finalTracks.count),@"index":@(mappedStart),@"at":[NSDate date]} writeToFile:VoiceSearchLog atomically:YES];
      TRDWaitAndReturnToCarDash(player, 28, bgTask);
      return;
     }
    }
    if(bgTask != UIBackgroundTaskInvalid) [[UIApplication sharedApplication] endBackgroundTask:bgTask];
   });
   return;
  }

  __block BOOL searchFinished = NO;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(10.0*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   if(!searchFinished){
    searchFinished = YES;
    gVoiceSearchHandling = NO;
    [@{@"status":@"timeout",@"query":q,@"at":[NSDate date]} writeToFile:VoiceSearchLog atomically:YES];
    if(bgTask != UIBackgroundTaskInvalid) [[UIApplication sharedApplication] endBackgroundTask:bgTask];
   }
  });
  [yt searchVideosWithQuery:q completion:^(NSArray *tracks, NSError *error){
   dispatch_async(dispatch_get_main_queue(),^{
    if(searchFinished) return;
    searchFinished = YES;
    gVoiceSearchHandling = NO;
    if(tracks && tracks.count > 0){
     @try {
      AVAudioSession *sess = [AVAudioSession sharedInstance];
      [sess setCategory:AVAudioSessionCategoryPlayback error:nil];
      [sess setActive:YES error:nil];
     } @catch(NSException *e) {}
     TRDNormalizeNinjaOutput();
     Class plCls=NSClassFromString(@"LTPlayerController");
     id<TRDLTPlayerController> player=(plCls && [plCls respondsToSelector:@selector(sharedController)])?[plCls sharedController]:nil;
     if(player && [player respondsToSelector:@selector(playQueue:atIndex:)]){
      TRDVoiceSearchInFlight = YES;
      [player playQueue:tracks atIndex:0];
      TRDVoiceSearchInFlight = NO;
      TRDSaveQueue();
      [@{@"status":@"playing",@"query":q,@"count":@(tracks.count),@"at":[NSDate date]} writeToFile:VoiceSearchLog atomically:YES];
      TRDWaitAndReturnToCarDash(player, 28, bgTask);
      return;
     }
    }
    [@{@"status":@"not_found",@"query":q,@"error":error.localizedDescription?:@"empty",@"at":[NSDate date]} writeToFile:VoiceSearchLog atomically:YES];
    if(bgTask != UIBackgroundTaskInvalid) [[UIApplication sharedApplication] endBackgroundTask:bgTask];
   });
  }];
 });
}

__attribute__((constructor))static void Install(void){@autoreleasepool{
 NSString *bundle=NSBundle.mainBundle.bundleIdentifier;NSString *name=nil,*selector=nil;IMP replacement=NULL;IMP *original=NULL;const char *a=NULL,*b=NULL;
 if([@[@"com.legacymusic.app",@"com.himais0giiiin.ytnine",@"com.codex.poddash",@"com.google.ios.youtube"]containsObject:bundle]){
  networkRouteObserver=[[NSNotificationCenter defaultCenter]addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){
   [UIDevice currentDevice].batteryMonitoringEnabled = YES;
   UIDeviceBatteryState bst = [UIDevice currentDevice].batteryState;
   [UIApplication sharedApplication].idleTimerDisabled = (bst == UIDeviceBatteryStateCharging || bst == UIDeviceBatteryStateFull);
   if((bst == UIDeviceBatteryStateCharging || bst == UIDeviceBatteryStateFull) && [UIScreen mainScreen].brightness < 0.35f){
    [UIScreen mainScreen].brightness = 0.90f;
   }
   [@{@"bundle":NSBundle.mainBundle.bundleIdentifier,@"at":[NSDate date]}writeToFile:@"/var/mobile/codex-car/last-media.plist" atomically:YES];
   notify_post("com.codex.trd.network.internet");
   [TRDFloatingHome installIfNeeded];
   if([bundle isEqual:@"com.legacymusic.app"]){TRDNormalizeNinjaOutput();TRDAutoPlayIfRequested();[TRDRoadAudio install];TRDHandleVoiceSearchIfPending();}
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
  [[NSNotificationCenter defaultCenter]addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){
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
  static int musicPlayTok=0,musicPauseTok=0,musicNextTok=0,musicPrevTok=0,musicToggleTok=0,voiceSearchTok=0,musicRefreshTok=0;
  notify_register_dispatch("com.codex.trd.music.refresh",&musicRefreshTok,dispatch_get_main_queue(),^(int t){
   id p=TRDCarPlayer();
   if(p && [p respondsToSelector:@selector(hasActivePlayer)] && [p hasActivePlayer]){
    if([p respondsToSelector:@selector(playerIsPlaying)] && [p playerIsPlaying]){
     @try {
      AVAudioSession *audSess=[AVAudioSession sharedInstance];
      [audSess setCategory:AVAudioSessionCategoryPlayback error:nil];
      [audSess setActive:YES error:nil];
     } @catch(NSException *e){}
    }
    [TRDRoadAudio install];
    TRDCarRefreshMetadata(@"cardash-refresh");
   }
  });
  notify_register_dispatch("com.codex.trd.music.voicesearch",&voiceSearchTok,dispatch_get_main_queue(),^(int t){
   TRDHandleVoiceSearchIfPending();
  });
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.9*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   TRDHandleVoiceSearchIfPending();
  });
  notify_register_dispatch("com.codex.trd.music.next",&musicNextTok,dispatch_get_main_queue(),^(int t){
   TRDNormalizeNinjaOutput();
   [roadAudio next:nil];
  });
  notify_register_dispatch("com.codex.trd.music.previous",&musicPrevTok,dispatch_get_main_queue(),^(int t){
   TRDNormalizeNinjaOutput();
   [roadAudio previous:nil];
  });
  notify_register_dispatch("com.codex.trd.music.toggle",&musicToggleTok,dispatch_get_main_queue(),^(int t){
   TRDNormalizeNinjaOutput();
   id p=TRDCarPlayer();
   if(p && [p respondsToSelector:@selector(playerIsPlaying)] && [p playerIsPlaying]){[roadAudio carPause:nil];}
   else{[roadAudio carPlay:nil];}
  });
  notify_register_dispatch("com.codex.trd.music.pause",&musicPauseTok,dispatch_get_main_queue(),^(int t){
   TRDReversePaused=YES;
   [roadAudio carPause:nil];
   TRDReversePaused=NO;
  });
  notify_register_dispatch("com.codex.trd.music.play",&musicPlayTok,dispatch_get_main_queue(),^(int t){
   TRDAudioInterrupted=NO;
   TRDNormalizeNinjaOutput();
   [roadAudio carPlay:nil];
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.55*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
    id p=TRDCarPlayer();
    if(p && [p respondsToSelector:@selector(hasActivePlayer)] && [p hasActivePlayer] &&
       [p respondsToSelector:@selector(playerIsPlaying)] && ![p playerIsPlaying]){
     TRDNormalizeNinjaOutput();
     [roadAudio carPlay:nil];
    }
   });
  });
  TRDAutoPlayIfRequested();TRDSaveQueueLoop();
  for(NSString *event in @[UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,UIApplicationWillTerminateNotification])[[NSNotificationCenter defaultCenter]addObserverForName:event object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){TRDSaveQueue();}];
  [[NSNotificationCenter defaultCenter]addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){TRDAudioInterrupted=[note.userInfo[AVAudioSessionInterruptionTypeKey]unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan;if(TRDAudioInterrupted)TRDCancelAutoResume(@"audio-interrupted");TRDSaveQueue();}];
  Class playerClass=NSClassFromString(@"LTPlayerController");Method pause=class_getInstanceMethod(playerClass,@selector(pausePlayback));if(pause&&method_getNumberOfArguments(pause)==2){char *type=method_copyReturnType(pause);if(type&&type[0]=='v')oldPause=(void(*)(id,SEL))method_setImplementation(pause,(IMP)AutoPause);free(type);}
  Method seek=class_getInstanceMethod(playerClass,@selector(seekToTime:));if(Signature(seek,"d",NULL))oldSeek=(void(*)(id,SEL,double))method_setImplementation(seek,(IMP)AutoSeek);
  Method toggle=class_getInstanceMethod(playerClass,NSSelectorFromString(@"togglePlayPause"));if(toggle&&method_getNumberOfArguments(toggle)==2){char *type=method_copyReturnType(toggle);if(type&&type[0]=='v')oldToggle=(void(*)(id,SEL))method_setImplementation(toggle,(IMP)NinjaToggle);free(type);}

   name=@"LTPlayerController";selector=@"playQueue:atIndex:";replacement=(IMP)Music;original=(IMP *)&oldMusic;a="@";b="iIqQ";
  
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
  }
  Class splitCls = NSClassFromString(@"LTSplitContainerViewController");
  if(splitCls){
   Method mOri = class_getInstanceMethod(splitCls, @selector(supportedInterfaceOrientations));
   if(mOri) method_setImplementation(mOri, (IMP)Hook_SupportedOrientations);
   Method mAuto = class_getInstanceMethod(splitCls, @selector(shouldAutorotate));
   if(mAuto) method_setImplementation(mAuto, (IMP)Hook_ShouldAutorotate);
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
 else if([bundle isEqual:@"com.himais0giiiin.ytnine"]){
  static int ytToggleTok=0,ytPauseTok=0,ytPlayTok=0,ytNextTok=0,ytPrevTok=0,ytNextHwTok=0,ytPrevHwTok=0,ytRefreshTok=0,ytSearchTok=0;
  static BOOL sYTSearchInFlight = NO;
  static NSMutableArray *sYTQueueItems = nil;
  static NSInteger sYTQueueIdx = -1;
  void (^playYTVideoID)(NSString *) = ^(NSString *vid){
   if(vid.length != 11) return;
   dispatch_async(dispatch_get_main_queue(), ^{
    @try {
     AVAudioSession *ytSess=[AVAudioSession sharedInstance];
     [ytSess setCategory:AVAudioSessionCategoryPlayback error:nil];
     [ytSess setActive:YES error:nil];
    } @catch(NSException *e){}
    NSURL *u=[NSURL URLWithString:[NSString stringWithFormat:@"ytnine://watch?v=%@", vid]];
    UIApplication *app=[UIApplication sharedApplication];
    id appDel=app.delegate;
    if(u && [appDel respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)]){
     [appDel application:app openURL:u sourceApplication:@"com.codex.cardash" annotation:@{}];
    } else if(u && [appDel respondsToSelector:@selector(application:openURL:options:)]){
     [appDel application:app openURL:u options:@{}];
    } else if(u){
     [app openURL:u];
    }
    [@{@"status":@"playing",@"videoId":vid,@"queueIdx":@(sYTQueueIdx),@"queueCount":@(sYTQueueItems ? sYTQueueItems.count : 0),@"at":[NSDate date]} writeToFile:@"/var/mobile/codex-car/youtube-search-state.plist" atomically:YES];
   });
  };
  void (^playYTQueueEntry)(NSString *) = ^(NSString *entry){
   NSString *clean = [entry stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
   if(!clean.length) return;
   NSRange sep = [clean rangeOfString:@"::"];
   if(sep.location == 11){
    playYTVideoID([clean substringToIndex:11]);
    return;
   }
   if(clean.length == 11 && [[NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9_-]{11}$" options:0 error:nil] numberOfMatchesInString:clean options:0 range:NSMakeRange(0, 11)] == 1){
    playYTVideoID(clean);
    return;
   }
   sYTSearchInFlight = YES;
   NSURL *apiURL = [NSURL URLWithString:@"https://www.youtube.com/youtubei/v1/search?prettyPrint=false"];
   NSMutableURLRequest *ytReq = [NSMutableURLRequest requestWithURL:apiURL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:6.0];
   ytReq.HTTPMethod = @"POST";
   [ytReq setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
   [ytReq setValue:@"contents.twoColumnSearchResultsRenderer.primaryContents.sectionListRenderer.contents.itemSectionRenderer.contents.videoRenderer(videoId)" forHTTPHeaderField:@"X-Goog-FieldMask"];
   NSDictionary *body = @{
    @"context": @{@"client": @{@"clientName": @"WEB", @"clientVersion": @"2.20240726.00.00", @"hl": @"th", @"gl": @"TH"}},
    @"query": clean
   };
   ytReq.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
   [[[NSURLSession sharedSession] dataTaskWithRequest:ytReq completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err){
    sYTSearchInFlight = NO;
    NSString *foundVid = nil;
    if(data.length > 0){
     NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
     if(jsonStr.length > 0){
      NSRegularExpression *re1 = [NSRegularExpression regularExpressionWithPattern:@"\"videoRenderer\":\\{\"videoId\":\"([A-Za-z0-9_-]{11})\"" options:0 error:nil];
      NSTextCheckingResult *m1 = [re1 firstMatchInString:jsonStr options:0 range:NSMakeRange(0, jsonStr.length)];
      if(m1 && m1.numberOfRanges >= 2){
       foundVid = [jsonStr substringWithRange:[m1 rangeAtIndex:1]];
      } else {
       NSRegularExpression *re2 = [NSRegularExpression regularExpressionWithPattern:@"\"videoId\":\"([A-Za-z0-9_-]{11})\"" options:0 error:nil];
       NSTextCheckingResult *m2 = [re2 firstMatchInString:jsonStr options:0 range:NSMakeRange(0, jsonStr.length)];
       if(m2 && m2.numberOfRanges >= 2) foundVid = [jsonStr substringWithRange:[m2 rangeAtIndex:1]];
      }
     }
    }
    if(foundVid.length == 11){
     playYTVideoID(foundVid);
    } else {
     [@{@"status":@"not_found",@"query":clean,@"error":err.localizedDescription?:@"empty",@"at":[NSDate date]} writeToFile:@"/var/mobile/codex-car/youtube-search-state.plist" atomically:YES];
    }
   }] resume];
  };
  void (^handlePendingYTSearch)(void) = ^{
   if(sYTSearchInFlight) return;
   NSDictionary *req=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/youtube-search.plist"];
   if(![req isKindOfClass:[NSDictionary class]] || ![req[@"pending"] boolValue]) return;
   NSDate *at=[req[@"at"] isKindOfClass:[NSDate class]]?req[@"at"]:nil;
   if(at && [at timeIntervalSinceNow] < -35.0) return;
   NSMutableDictionary *done=[req mutableCopy];
   done[@"pending"]=@NO;
   [done writeToFile:@"/var/mobile/codex-car/youtube-search.plist" atomically:YES];
   NSArray *items=[req[@"items"] isKindOfClass:[NSArray class]]?req[@"items"]:nil;
   if(items.count > 0){
    sYTQueueItems = [items mutableCopy];
    sYTQueueIdx = MAX(0, MIN((NSInteger)items.count - 1, [req[@"startIndex"] integerValue]));
    playYTQueueEntry(sYTQueueItems[sYTQueueIdx]);
    return;
   }
   sYTQueueItems = nil;
   sYTQueueIdx = -1;
   NSString *vid=[req[@"videoId"] isKindOfClass:[NSString class]]?req[@"videoId"]:@"";
   NSString *q=[req[@"query"] isKindOfClass:[NSString class]]?[req[@"query"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]:@"";
   if(vid.length == 11){
    playYTVideoID(vid);
   } else if(q.length > 0){
    playYTQueueEntry(q);
   }
  };
  // Auto-advance to next song in custom YouTube queue when current MV finishes!
  [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n){
   if(sYTQueueItems.count > 0 && sYTQueueIdx + 1 < (NSInteger)sYTQueueItems.count){
    id yt = TRDYouTubePlayback();
    id avp = (yt && [yt respondsToSelector:@selector(player)]) ? [yt player] : nil;
    if([avp isKindOfClass:[AVPlayer class]] && ((AVPlayer *)avp).currentItem == n.object){
     sYTQueueIdx++;
     playYTQueueEntry(sYTQueueItems[sYTQueueIdx]);
    }
   }
  }];
  notify_register_dispatch("com.codex.trd.youtube.search",&ytSearchTok,dispatch_get_main_queue(),^(int t){
   handlePendingYTSearch();
  });
  [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n){
   handlePendingYTSearch();
  }];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.75*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
   handlePendingYTSearch();
  });
  notify_register_dispatch("com.codex.trd.music.refresh",&ytRefreshTok,dispatch_get_main_queue(),^(int t){
   id yt=TRDYouTubePlayback();
   if(yt && TRDYouTubeIsCurrentlyPlaying(yt)){
    @try {
     AVAudioSession *ytSess=[AVAudioSession sharedInstance];
     [ytSess setCategory:AVAudioSessionCategoryPlayback error:nil];
     [ytSess setActive:YES error:nil];
    } @catch(NSException *e){}
    [TRDRoadAudio install];
    id<TRDYTPlaybackProto> pb=(id<TRDYTPlaybackProto>)yt;
    if([pb respondsToSelector:@selector(updateNowPlaying)])[pb updateNowPlaying];
   }
  });
  notify_register_dispatch("com.codex.trd.youtube.toggle",&ytToggleTok,dispatch_get_main_queue(),^(int t){TRDYouTubeTransport(2,@"darwin-toggle");});
  notify_register_dispatch("com.codex.trd.youtube.pause",&ytPauseTok,dispatch_get_main_queue(),^(int t){TRDYouTubeTransport(1,@"darwin-pause");});
  notify_register_dispatch("com.codex.trd.youtube.play",&ytPlayTok,dispatch_get_main_queue(),^(int t){TRDYouTubeTransport(0,@"darwin-play");});
  void (^stepYTQueue)(BOOL, BOOL) = ^(BOOL fwd, BOOL fromHw){
   if(!sYTQueueItems || sYTQueueItems.count == 0){
    NSDictionary *sq = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/shared-song-queue.plist"];
    NSArray *sqItems = [sq[@"items"] isKindOfClass:[NSArray class]] ? sq[@"items"] : nil;
    if(sqItems.count > 0){
     NSMutableArray *built = [NSMutableArray array];
     for(NSDictionary *it in sqItems){
      NSString *vid = [it[@"id"] isKindOfClass:[NSString class]] ? it[@"id"] : @"";
      NSString *ttl = [it[@"title"] isKindOfClass:[NSString class]] ? it[@"title"] : @"";
      if(vid.length == 11) [built addObject:vid];
      else if(ttl.length > 0) [built addObject:ttl];
     }
     if(built.count > 0){
      sYTQueueItems = built;
      sYTQueueIdx = [sq[@"activeIdx"] integerValue];
      if(sYTQueueIdx < 0 || sYTQueueIdx >= (NSInteger)built.count) sYTQueueIdx = 0;
     }
    }
   }
   if(sYTQueueItems.count > 0){
    if(fwd){
     sYTQueueIdx = (sYTQueueIdx + 1) % (NSInteger)sYTQueueItems.count;
    } else {
     sYTQueueIdx = (sYTQueueIdx - 1 + (NSInteger)sYTQueueItems.count) % (NSInteger)sYTQueueItems.count;
    }
    playYTQueueEntry(sYTQueueItems[sYTQueueIdx]);
   } else if(!fromHw){
    if(fwd) [roadAudio next:nil]; else [roadAudio previous:nil];
   }
  };
  notify_register_dispatch("com.codex.trd.youtube.next",&ytNextTok,dispatch_get_main_queue(),^(int t){ stepYTQueue(YES, NO); });
  notify_register_dispatch("com.codex.trd.youtube.previous",&ytPrevTok,dispatch_get_main_queue(),^(int t){ stepYTQueue(NO, NO); });
  notify_register_dispatch("com.codex.trd.youtube.next.hw",&ytNextHwTok,dispatch_get_main_queue(),^(int t){ stepYTQueue(YES, YES); });
  notify_register_dispatch("com.codex.trd.youtube.previous.hw",&ytPrevHwTok,dispatch_get_main_queue(),^(int t){ stepYTQueue(NO, YES); });
  dispatch_async(dispatch_get_main_queue(),^{[TRDRoadAudio install];});
  name=@"YTPlayback";selector=@"loadWatch:startAt:";replacement=(IMP)YouTube;original=(IMP *)&oldYT;a="@";b="d";
 }
 else if([bundle isEqual:@"com.codex.poddash"]){name=@"Podcasts";selector=@"playIndex:";replacement=(IMP)Podcast;original=(IMP *)&oldPod;a="iq";}
 else if([bundle isEqual:@"com.google.ios.youtube"]){return;}
 else return;
 Class cls=NSClassFromString(name);SEL sel=NSSelectorFromString(selector);Method method=class_getInstanceMethod(cls,sel);BOOL valid=Signature(method,a,b);BOOL installed=valid;
 if(installed)*original=method_setImplementation(method,replacement);
 if([bundle isEqual:@"com.himais0giiiin.ytnine"]){Method remote=class_getInstanceMethod(NSClassFromString(@"YTAppDelegate"),@selector(remoteControlReceivedWithEvent:));if(Signature(remote,"@",NULL))oldRemote=(void(*)(id,SEL,UIEvent *))method_setImplementation(remote,(IMP)RoadRemote);}
if([bundle isEqual:@"com.legacymusic.app"]){Method remote=class_getInstanceMethod(NSClassFromString(@"LTAppDelegate"),@selector(remoteControlReceivedWithEvent:));if(Signature(remote,"@",NULL))oldRemote=(void(*)(id,SEL,UIEvent *))method_setImplementation(remote,(IMP)RoadRemote);[TRDRoadAudio install];}
 NSString *path=[NSString stringWithFormat:@"/var/mobile/codex-car/browse-hook-%@.plist",name];[@{@"installed":@(installed),@"signature":method?[NSString stringWithUTF8String:method_getTypeEncoding(method)]:@"missing",@"class":name,@"selector":selector,@"bundle":bundle}writeToFile:path atomically:YES];
}}
