// Included after TRDRoadAudio's implementation. Runs inside the audio source.
@interface NSObject(TRDCarMediaPlayer)
-(BOOL)playerIsPlaying;
-(void)togglePlayPause;
-(void)pausePlayback;
-(void)updateNowPlayingInfo;
@end

static id TRDCarPlayer(void){
 Class cls=NSClassFromString(@"LTPlayerController");
 return [cls respondsToSelector:@selector(sharedController)]?[cls sharedController]:nil;
}

static void TRDCarMediaRecord(NSString *reason){
 NSDictionary *info=[MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo?:@{};
 MPRemoteCommandCenter *center=[MPRemoteCommandCenter sharedCommandCenter];
 NSMutableArray *events=[[NSArray arrayWithContentsOfFile:@"/var/mobile/codex-car/car-media-events.plist"]mutableCopy]?:[NSMutableArray array];
 [events addObject:@{@"at":[NSDate date],@"event":reason,
  @"title":info[MPMediaItemPropertyTitle]?:@"",
  @"artist":info[MPMediaItemPropertyArtist]?:@"",
  @"rate":info[MPNowPlayingInfoPropertyPlaybackRate]?:@0,
  @"nextEnabled":@(center.nextTrackCommand.enabled),
  @"previousEnabled":@(center.previousTrackCommand.enabled)}];
 if(events.count>60)[events removeObjectsInRange:NSMakeRange(0,events.count-60)];
 [events writeToFile:@"/var/mobile/codex-car/car-media-events.plist" atomically:YES];
}

static void TRDCarRefreshMetadata(NSString *reason){
 // Preserve the source's real artwork, title, position and playback rate.
 // Do not claim Now Playing from another audio app during a route change.
 void (^publish)(void)=^{id p=TRDCarPlayer();
  if([p respondsToSelector:@selector(hasActivePlayer)]&&[p hasActivePlayer]&&
     [p respondsToSelector:@selector(updateNowPlayingInfo)])[p updateNowPlayingInfo];
  TRDCarMediaRecord(reason);
 };
 void (*owner)(dispatch_queue_t,void (^)(int))=dlsym(RTLD_DEFAULT,"MRMediaRemoteGetNowPlayingApplicationPID");
 if(owner)owner(dispatch_get_main_queue(),^(int pid){
  id p=TRDCarPlayer();
  if(pid==getpid()||(pid<=0&&[p respondsToSelector:@selector(playerIsPlaying)]&&[p playerIsPlaying]))publish();
 });
 else if(![AVAudioSession sharedInstance].otherAudioPlaying)publish();
}

@interface TRDRoadAudio(TRDCarMedia)
-(MPRemoteCommandHandlerStatus)carPlay:(id)event;
-(MPRemoteCommandHandlerStatus)carPause:(id)event;
-(MPRemoteCommandHandlerStatus)carToggle:(id)event;
+(void)refreshCarMetadata;
@end

static CFAbsoluteTime TRDLastTransportAt=0;
static NSInteger TRDLastTransportKind=-1;

@implementation TRDRoadAudio(TRDCarMedia)
-(MPRemoteCommandHandlerStatus)carTransport:(NSInteger)kind{
 __block BOOL delivered=NO;
 void (^action)(void)=^{id p=TRDCarPlayer();
  if(![p respondsToSelector:@selector(hasActivePlayer)]||![p hasActivePlayer]||
     ![p respondsToSelector:@selector(playerIsPlaying)])return;
  BOOL playing=[p playerIsPlaying];
  // iOS 9 can deliver the same accessory press through both event APIs.
  CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
  if(kind==TRDLastTransportKind&&now-TRDLastTransportAt<.25){delivered=YES;return;}
  TRDLastTransportAt=now;TRDLastTransportKind=kind;
  if(kind==1){
   if(!playing)delivered=YES;
   else if([p respondsToSelector:@selector(pausePlayback)]){[p pausePlayback];delivered=YES;}
  }else if((kind==0&&playing)){delivered=YES;}
  else if([p respondsToSelector:@selector(togglePlayPause)]){[p togglePlayPause];delivered=YES;}
  if(delivered){
   TRDCarRefreshMetadata(kind==0?@"play":kind==1?@"pause":@"toggle");
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),dispatch_get_main_queue(),^{TRDCarRefreshMetadata(@"transport-updated");});
  }
 };
 if([NSThread isMainThread])action();else dispatch_sync(dispatch_get_main_queue(),action);
 return delivered?MPRemoteCommandHandlerStatusSuccess:MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
}
-(MPRemoteCommandHandlerStatus)carPlay:(id)event{return [self carTransport:0];}
-(MPRemoteCommandHandlerStatus)carPause:(id)event{return [self carTransport:1];}
-(MPRemoteCommandHandlerStatus)carToggle:(id)event{return [self carTransport:2];}
+(void)refreshCarMetadata{dispatch_async(dispatch_get_main_queue(),^{TRDCarRefreshMetadata(@"metadata-refresh");});}
@end

static void TRDInstallCarControls(void){
 if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.legacymusic.app"])return;
 MPRemoteCommandCenter *center=[MPRemoteCommandCenter sharedCommandCenter];
 NSArray *commands=@[center.playCommand,center.pauseCommand,center.stopCommand,center.togglePlayPauseCommand];
 SEL selectors[]={@selector(carPlay:),@selector(carPause:),@selector(carPause:),@selector(carToggle:)};
 for(NSUInteger i=0;i<commands.count;i++){
  MPRemoteCommand *command=commands[i];[command removeTarget:nil];
  [command addTarget:roadAudio action:selectors[i]];command.enabled=YES;
 }
 static BOOL observing=NO;
 if(!observing){observing=YES;
  [[NSNotificationCenter defaultCenter]addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note){
   [TRDRoadAudio install];
   TRDCarRefreshMetadata(@"audio-route-changed");
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{TRDCarRefreshMetadata(@"audio-route-ready");});
  }];
 }
}
