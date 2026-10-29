// Recovered selectors from the installed ARMv7 apps; no SpringBoard hooks.

@interface NSObject(TRDRoadSelectors)

+(id)sharedController;

+(id)sharedStore;

+(id)shared;

-(NSString *)title;

-(id)playlist;

-(NSArray *)playlists;

-(NSArray *)tracks;

-(NSArray *)downloadedTracks;

-(NSArray *)recentTracks;

-(NSArray *)tracksFromResults;

-(NSArray *)libraryTracks;

-(NSArray *)mostPlayedTracks;

-(UIView *)sidebarView;

-(UIViewController *)tabController;

-(NSArray *)queue;

-(NSString *)videoId;

-(NSInteger)currentIndex;

-(NSInteger)repeatMode;

-(BOOL)isPlaying;
-(BOOL)hasActivePlayer;
-(void)playQueue:(id)queue atIndex:(NSUInteger)index;
-(void)nextTrack;

-(void)previousTrack;

-(void)playNextVideo;

-(void)playPreviousVideo;

-(void)playNext;

-(void)playPrevious;

-(BOOL)hasNext;

-(BOOL)hasPrevious;

-(id)audioPlayer;

-(id)nextVideo;

@end

static UIViewController *TRDFindController(NSString *name){

 NSMutableArray *pending=[NSMutableArray array];UIViewController *root=[UIApplication sharedApplication].keyWindow.rootViewController;if(root)[pending addObject:root];unsigned visited=0;

 while(pending.count&&visited++<64){UIViewController *v=pending.lastObject;[pending removeLastObject];if([NSStringFromClass([v class])isEqual:name])return v;[pending addObjectsFromArray:v.childViewControllers];if(v.presentedViewController)[pending addObject:v.presentedViewController];}return nil;

}

static NSArray *TRDExpandQueue(id owner,NSArray *queue,NSUInteger *index){

 if(![queue isKindOfClass:[NSArray class]]||queue.count==0)return queue;

 if(queue.count>1){

  [@{@"event":@"already-multi-track",@"count":@(queue.count),@"index":@(*index)}writeToFile:@"/var/mobile/codex-car/ninja-continuous.plist" atomically:YES];

  return queue;

 }

 id selected=queue[0];

 NSString *key=[selected respondsToSelector:@selector(videoId)]?[selected videoId]:nil;

 NSString *selTitle=[selected respondsToSelector:@selector(title)]?[selected title]:nil;

 if(!key.length&&!selTitle.length)return queue;



 Class cls=NSClassFromString(@"LTPlaylistStore");

 id store=[cls respondsToSelector:@selector(sharedStore)]?[cls sharedStore]:nil;



 NSMutableArray *candidates=[NSMutableArray array];



 // 1. Current active view controller

 UIViewController *playlistVC=TRDFindController(@"LTLocalPlaylistDetailViewController");

 if(playlistVC&&[playlistVC respondsToSelector:@selector(playlist)]){

  id pl=[playlistVC playlist];

  if(pl&&[pl respondsToSelector:@selector(tracks)]){

   NSArray *tr=[pl tracks];

   if(tr.count>=2)[candidates addObject:tr];

  }

 }

 UIViewController *searchVC=TRDFindController(@"LTSearchViewController");

 if(searchVC&&[searchVC respondsToSelector:@selector(tracksFromResults)]){

  NSArray *tr=[searchVC tracksFromResults];

  if(tr.count>=2)[candidates addObject:tr];

 }



 // 2. Playlists in store

 if(store&&[store respondsToSelector:@selector(playlists)]){

  NSArray *playlists=[store playlists];

  for(id pl in playlists){

   if([pl respondsToSelector:@selector(tracks)]){

    NSArray *tr=[pl tracks];

    if(tr.count>=2)[candidates addObject:tr];

   }

  }

 }



 // 3. Downloaded / offline tracks

 if(store&&[store respondsToSelector:@selector(downloadedTracks)]){

  NSArray *tr=[store downloadedTracks];

  if(tr.count>=2)[candidates addObject:tr];

 }



 // 4. Recent tracks

 if(store&&[store respondsToSelector:@selector(recentTracks)]){

  NSArray *tr=[store recentTracks];

  if(tr.count>=2)[candidates addObject:tr];

 }



 // 5. Library tracks

 if(store&&[store respondsToSelector:@selector(libraryTracks)]){

  NSArray *tr=[store libraryTracks];

  if(tr.count>=2)[candidates addObject:tr];

 }



 // Search candidates for matching song

 for(NSArray *list in candidates){

  for(NSUInteger i=0;i<list.count;i++){

   id track=list[i];

   NSString *candId=[track respondsToSelector:@selector(videoId)]?[track videoId]:nil;

   NSString *candTitle=[track respondsToSelector:@selector(title)]?[track title]:nil;



   BOOL match=NO;

   if(key.length&&candId.length&&[candId isEqual:key])match=YES;

   else if(selTitle.length&&candTitle.length&&[candTitle isEqual:selTitle])match=YES;



   if(match){

    *index=i;

    [@{@"event":@"expanded-to-list",@"count":@(list.count),@"index":@(i),@"title":selTitle?:@""}writeToFile:@"/var/mobile/codex-car/ninja-continuous.plist" atomically:YES];

    return list;

   }

  }

 }



 // Fallback composite: selected song + recent or library tracks

 NSMutableArray *composite=[NSMutableArray arrayWithObject:selected];

 NSArray *fallback=nil;

 if(store&&[store respondsToSelector:@selector(recentTracks)])fallback=[store recentTracks];

 if((!fallback||fallback.count<2)&&store&&[store respondsToSelector:@selector(libraryTracks)])fallback=[store libraryTracks];



 if(fallback.count>0){

  for(id t in fallback){

   NSString *candId=[t respondsToSelector:@selector(videoId)]?[t videoId]:nil;

   if(!candId.length||!key.length||![candId isEqual:key]){

    [composite addObject:t];

   }

  }

  *index=0;

  [@{@"event":@"expanded-to-composite-list",@"count":@(composite.count),@"index":@0,@"title":selTitle?:@""}writeToFile:@"/var/mobile/codex-car/ninja-continuous.plist" atomically:YES];

  return composite;

 }



 return queue;

}

static void TRDInstallCarControls(void);
static void TRDCarRefreshMetadata(NSString *reason);

@interface TRDRoadAudio:NSObject

@property double lastCommand;

@property NSInteger lastDirection;

-(MPRemoteCommandHandlerStatus)next:(id)event;

-(MPRemoteCommandHandlerStatus)previous:(id)event;

+(void)install;

+(void)captureMusic;

+(void)captureYT;

+(void)testNext;

+(void)testPrevious;

@end

static TRDRoadAudio *roadAudio;

@implementation TRDRoadAudio

-(MPRemoteCommandHandlerStatus)move:(BOOL)next{__block BOOL delivered=NO;void(^action)(void)=^{double now=[NSDate timeIntervalSinceReferenceDate];NSInteger direction=next?1:-1;if(self.lastDirection==direction&&now-self.lastCommand<.4){delivered=YES;return;}self.lastCommand=now;self.lastDirection=direction;
Class pc=NSClassFromString(@"LTPlayerController");
id player=[pc respondsToSelector:@selector(sharedController)]?[pc sharedController]:nil;
if(player){
 NSArray *q=[player respondsToSelector:@selector(queue)]?[player queue]:nil;
 if(!q||q.count==0||([player respondsToSelector:@selector(hasActivePlayer)] && ![player hasActivePlayer])){
  Class sc=NSClassFromString(@"LTPlaylistStore");
  id store=[sc respondsToSelector:@selector(sharedStore)]?[sc sharedStore]:nil;
  NSArray *dl=[store respondsToSelector:@selector(downloadedTracks)]?[store downloadedTracks]:nil;
  if(dl&&dl.count>0&&[player respondsToSelector:@selector(playQueue:atIndex:)]){
   [player playQueue:dl atIndex:0];
   delivered=YES;
   [@{@"command":@"auto-start-downloaded",@"count":@(dl.count),@"target":@"audioNINJA",@"at":[NSDate date]}writeToFile:@"/var/mobile/codex-car/ninja-remote.plist" atomically:YES];
   return;
  }
 }
 if([player respondsToSelector:next?@selector(nextTrack):@selector(previousTrack)]){
  if(next)[player nextTrack];else [player previousTrack];
  delivered=YES;
  [@{@"command":next?@"next":@"previous",@"delivered":@YES,@"target":@"audioNINJA",@"at":[NSDate date]}writeToFile:@"/var/mobile/codex-car/ninja-remote.plist" atomically:YES];
  return;
 }
}
id vc=TRDFindController(@"YTPlayerViewController");if(vc&&[vc respondsToSelector:next?@selector(playNextVideo):@selector(playPreviousVideo)]){if(next)[vc playNextVideo];else [vc playPreviousVideo];delivered=YES;}else{Class cls=NSClassFromString(@"YTQueue");id q=[cls respondsToSelector:@selector(shared)]?[cls shared]:nil;if(q&&((next&&[q hasNext])||(!next&&[q hasPrevious]))){if(next)[q playNext];else [q playPrevious];delivered=YES;}}[@{@"command":next?@"next":@"previous",@"delivered":@(delivered),@"at":[NSDate date]}writeToFile:@"/var/mobile/codex-car/ytnine-remote.plist" atomically:YES];};if([NSThread isMainThread])action();else dispatch_sync(dispatch_get_main_queue(),action);return delivered?MPRemoteCommandHandlerStatusSuccess:MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;}

-(MPRemoteCommandHandlerStatus)next:(id)event{MPRemoteCommandHandlerStatus result=[self move:YES];if([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.legacymusic.app"])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{TRDCarRefreshMetadata(@"next");});return result;}

-(MPRemoteCommandHandlerStatus)previous:(id)event{MPRemoteCommandHandlerStatus result=[self move:NO];if([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.legacymusic.app"])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{TRDCarRefreshMetadata(@"previous");});return result;}

+(void)install{if(!roadAudio)roadAudio=[TRDRoadAudio new];MPRemoteCommandCenter *center=[MPRemoteCommandCenter sharedCommandCenter];[center.nextTrackCommand removeTarget:nil];[center.previousTrackCommand removeTarget:nil];[center.nextTrackCommand addTarget:roadAudio action:@selector(next:)];[center.previousTrackCommand addTarget:roadAudio action:@selector(previous:)];center.nextTrackCommand.enabled=YES;center.previousTrackCommand.enabled=YES;[[UIApplication sharedApplication]beginReceivingRemoteControlEvents];TRDInstallCarControls();}

+(void)captureYT{MPRemoteCommandCenter *c=[MPRemoteCommandCenter sharedCommandCenter];id vc=TRDFindController(@"YTPlayerViewController");NSDictionary *info=[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo;[@{@"nextEnabled":@(c.nextTrackCommand.enabled),@"previousEnabled":@(c.previousTrackCommand.enabled),@"controller":@(vc!=nil),@"nextModel":@([vc respondsToSelector:@selector(nextVideo)]&&[vc nextVideo]!=nil),@"title":info[MPMediaItemPropertyTitle]?:@"",@"rate":info[MPNowPlayingInfoPropertyPlaybackRate]?:@0}writeToFile:@"/var/mobile/h109-build/yt-road-state.plist" atomically:YES];}

+(void)testNext{[roadAudio next:nil];}

+(void)testPrevious{[roadAudio previous:nil];}

+(void)captureMusic{Class cls=NSClassFromString(@"LTPlayerController");id p=[cls respondsToSelector:@selector(sharedController)]?[cls sharedController]:nil;Class storeClass=NSClassFromString(@"LTPlaylistStore");id store=[storeClass respondsToSelector:@selector(sharedStore)]?[storeClass sharedStore]:nil;[@{@"queue":@([[p queue]count]),@"index":@([p currentIndex]),@"repeat":@([p repeatMode]),@"playing":@([p isPlaying]),@"library":@([[store libraryTracks]count])}writeToFile:@"/var/mobile/h109-build/ninja-road-state.plist" atomically:YES];}

@end

#import "TRDCarMedia.h"

static void(*oldRemote)(id,SEL,UIEvent *);

static void RoadRemote(id obj,SEL sel,UIEvent *event){if([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.legacymusic.app"]){if(event.subtype==UIEventSubtypeRemoteControlPlay){[roadAudio carPlay:nil];return;}if(event.subtype==UIEventSubtypeRemoteControlPause||event.subtype==UIEventSubtypeRemoteControlStop){[roadAudio carPause:nil];return;}if(event.subtype==UIEventSubtypeRemoteControlTogglePlayPause){[roadAudio carToggle:nil];return;}}if(event.subtype==UIEventSubtypeRemoteControlNextTrack){[roadAudio next:event];return;}if(event.subtype==UIEventSubtypeRemoteControlPreviousTrack){[roadAudio previous:event];return;}oldRemote(obj,sel,event);}

