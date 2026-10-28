#import "TRDAutoplayModel.h"
@protocol TRDAutoPlayerAPI<NSObject>
-(double)currentTime;
-(void)seekToTime:(double)seconds;
-(void)setVolume:(float)volume;
-(float)volume;
@end
@interface NSObject(TRDAutoPlayerSelectors)
-(void)playQueue:(NSArray *)queue atIndex:(NSUInteger)index;
-(double)currentTime;
-(double)playerDuration;
-(BOOL)hasActivePlayer;
-(void)seekToTime:(double)seconds;
-(void)setVolume:(float)volume;
-(float)volume;
-(void)pausePlayback;
-(NSString *)existingLocalFilePathForVideoId:(NSString *)key;
-(NSDictionary *)dictionaryRepresentation;
@end
#define AutoPath TRDAutoFile(@"autoplay.plist")
#define LastQ TRDAutoFile(@"last-queue.plist")
static BOOL TRDAutoStarting=NO,TRDAutoRestoring=NO,TRDAudioInterrupted=NO;
static void TRDNormalizeNinjaOutput(void){Class cls=NSClassFromString(@"LTPlayerController");id<TRDAutoPlayerAPI> player=[cls respondsToSelector:@selector(sharedController)]?[cls sharedController]:nil;if([player respondsToSelector:@selector(setVolume:)])[player setVolume:1.0f];}
static NSUInteger TRDAutoGeneration=0;
static void TRDAutoLog(NSString *event,NSDictionary *detail){NSMutableDictionary *state=[detail mutableCopy]?:[NSMutableDictionary dictionary];state[@"event"]=event;state[@"at"]=[NSDate date];[state writeToFile:TRDAutoFile(@"ninja-autoplay-state.plist") atomically:YES];}
static void TRDSaveQueue(void){@autoreleasepool{
 if(TRDAutoRestoring)return;Class cls=NSClassFromString(@"LTPlayerController");id p=[cls respondsToSelector:@selector(sharedController)]?[cls sharedController]:nil;
 NSArray *q=[p respondsToSelector:@selector(queue)]?[p queue]:nil;if(![q isKindOfClass:[NSArray class]]||!q.count||q.count>500||![p respondsToSelector:@selector(currentIndex)])return;
 NSMutableArray *ids=[NSMutableArray array];for(id track in q){id key=[track respondsToSelector:@selector(videoId)]?[track videoId]:nil;if(![key isKindOfClass:[NSString class]]||![key length])return;[ids addObject:key];}
 double seconds=[p respondsToSelector:@selector(currentTime)]?[(id<TRDAutoPlayerAPI>)p currentTime]:0;NSMutableDictionary *snapshot=[TRDQueueSnapshot(ids,[p currentIndex],seconds)mutableCopy];NSMutableArray *records=[NSMutableArray array];for(id track in q)if([track respondsToSelector:@selector(dictionaryRepresentation)]){id record=[track dictionaryRepresentation];if([record isKindOfClass:[NSDictionary class]]&&[NSPropertyListSerialization propertyList:record isValidForFormat:NSPropertyListXMLFormat_v1_0])[records addObject:record];}if(records.count==ids.count)snapshot[@"tracks"]=records;if(snapshot)[snapshot writeToFile:LastQ atomically:YES];
}}
static void TRDSaveQueueLoop(void){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{@autoreleasepool{Class cls=NSClassFromString(@"LTPlayerController");id p=[cls respondsToSelector:@selector(sharedController)]?[cls sharedController]:nil;if([p respondsToSelector:@selector(isPlaying)]&&[p isPlaying])TRDSaveQueue();TRDSaveQueueLoop();}});}
static void TRDCancelAutoResume(NSString *reason){if(TRDAutoRestoring){TRDAutoRestoring=NO;TRDAutoGeneration++;TRDAutoLog(reason,nil);}}
static void TRDManualPlaybackOverride(NSString *reason){TRDCancelAutoResume(reason);NSMutableDictionary *request=[[NSDictionary dictionaryWithContentsOfFile:AutoPath]mutableCopy];if([request[@"pending"]boolValue]){request[@"pending"]=@NO;request[@"cancelledAt"]=[NSDate date];[request writeToFile:AutoPath atomically:YES];TRDAutoLog(reason,nil);}}
static void TRDPausePendingAuto(id player){if([player respondsToSelector:@selector(pausePlayback)]){TRDAutoStarting=YES;[player pausePlayback];TRDAutoStarting=NO;}}
static void TRDFinishAutoResume(id player,NSString *expected,double seconds,NSDate *deadline,NSUInteger generation){
 if(generation!=TRDAutoGeneration||!TRDAutoRestoring)return;
 NSArray *queue=[player queue];NSInteger index=[player currentIndex];id track=index>=0&&index<(NSInteger)queue.count?queue[index]:nil;NSString *key=[track respondsToSelector:@selector(videoId)]?[track videoId]:nil;
 NSDictionary *event=[NSDictionary dictionaryWithContentsOfFile:TRDAutoFile(@"car-start-state.plist")];
 if(!TRDAutoEnabled()||![event[@"connected"]boolValue]||TRDAudioInterrupted||![key isEqual:expected]){if([key isEqual:expected])TRDPausePendingAuto(player);TRDCancelAutoResume(@"resume-cancelled");return;}
 if([deadline timeIntervalSinceNow]<=0){TRDPausePendingAuto(player);TRDCancelAutoResume(@"load-timeout");return;}
 double duration=[player respondsToSelector:@selector(playerDuration)]?[player playerDuration]:0;
 if([player respondsToSelector:@selector(hasActivePlayer)]&&[player hasActivePlayer]&&[player isPlaying]&&isfinite(duration)&&duration>0){
  if(seconds>0&&[player respondsToSelector:@selector(seekToTime:)]){TRDAutoStarting=YES;[(id<TRDAutoPlayerAPI>)player seekToTime:MIN(seconds,MAX(0,duration-2))];TRDAutoStarting=NO;}
  TRDAutoRestoring=NO;TRDAutoLog(@"resumed",@{@"currentId":expected,@"requestedSeconds":@(seconds),@"queueCount":@(queue.count)});
  NSDictionary *arm=@{@"bundle":@"com.legacymusic.app",@"token":[NSUUID UUID].UUIDString,@"pending":@YES,@"created":[NSDate date],@"expires":[NSDate dateWithTimeIntervalSinceNow:30],@"baselineTitle":@""};[arm writeToFile:Arm atomically:YES];[TRDBrowseReturn selected:player];return;
 }
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/4),dispatch_get_main_queue(),^{TRDFinishAutoResume(player,expected,seconds,deadline,generation);});
}
static void TRDAutoPlayIfRequested(void){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{@autoreleasepool{
 NSDictionary *request=[NSDictionary dictionaryWithContentsOfFile:AutoPath];if(![request[@"pending"]boolValue]||![request[@"expires"]isKindOfClass:[NSDate class]]||[request[@"expires"]timeIntervalSinceNow]<=0)return;
 NSDictionary *car=[NSDictionary dictionaryWithContentsOfFile:TRDAutoFile(@"car-start-state.plist")];
 BOOL valid=TRDAutoEnabled()&&[car[@"connected"]boolValue]&&[request[@"token"]isEqual:car[@"token"]]&&[request[@"boot"]isEqual:TRDBootIdentity()]&&[UIApplication sharedApplication].applicationState==UIApplicationStateActive;
 // Claim before invoking playback: constructor and activation notifications can overlap.
 NSMutableDictionary *claimed=[request mutableCopy];claimed[@"pending"]=@NO;claimed[@"claimedAt"]=[NSDate date];if(![claimed writeToFile:AutoPath atomically:YES])return;
 if(!valid){TRDAutoLog(@"request-rejected",nil);return;}
 Class pc=NSClassFromString(@"LTPlayerController"),sc=NSClassFromString(@"LTPlaylistStore");id player=[pc respondsToSelector:@selector(sharedController)]?[pc sharedController]:nil;id store=[sc respondsToSelector:@selector(sharedStore)]?[sc sharedStore]:nil;
 if(!player||!store||![player respondsToSelector:@selector(playQueue:atIndex:)]){TRDAutoLog(@"player-unavailable",nil);return;}
 if(!TRDAutoMayPlay(TRDAutoEnabled(),[AVAudioSession sharedInstance].otherAudioPlaying,[AVAudioSession sharedInstance].secondaryAudioShouldBeSilencedHint,TRDAudioInterrupted,([player respondsToSelector:@selector(isPlaying)]&&[player isPlaying]))){TRDAutoLog(@"audio-busy",nil);return;}
 NSMutableArray *sources=[NSMutableArray array];NSArray *current=[player queue];if([current isKindOfClass:[NSArray class]])[sources addObjectsFromArray:current];SEL selectors[]={@selector(recentTracks),@selector(libraryTracks),@selector(downloadedTracks)};for(int i=0;i<3;i++)if([store respondsToSelector:selectors[i]]){id list=[store performSelector:selectors[i]];if([list isKindOfClass:[NSArray class]])[sources addObjectsFromArray:list];}
 if([store respondsToSelector:@selector(playlists)])for(id list in [store playlists])if([list respondsToSelector:@selector(tracks)]){id tracks=[list tracks];if([tracks isKindOfClass:[NSArray class]])[sources addObjectsFromArray:tracks];}
 NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:LastQ];Class trackClass=NSClassFromString(@"LTTrack");id records=saved[@"tracks"];if([records isKindOfClass:[NSArray class]]&&[records count]<=500&&[trackClass instancesRespondToSelector:NSSelectorFromString(@"setVideoId:")])for(id record in records){if(![record isKindOfClass:[NSDictionary class]]||![record[@"videoId"]isKindOfClass:[NSString class]])continue;id track=[trackClass new];for(NSString *field in @[@"videoId",@"title",@"artist",@"album"]){id value=record[field];if([value isKindOfClass:[NSString class]])[track setValue:value forKey:field];}if([record[@"duration"]isKindOfClass:[NSNumber class]])[track setValue:record[@"duration"]forKey:@"duration"];[sources addObject:track];}
 NSMutableDictionary *pool=[NSMutableDictionary dictionary];NSMutableSet *offline=[NSMutableSet set];for(id track in sources){id key=[track respondsToSelector:@selector(videoId)]?[track videoId]:nil;if(![key isKindOfClass:[NSString class]]||![key length])continue;if(!pool[key])pool[key]=track;if([store respondsToSelector:@selector(existingLocalFilePathForVideoId:)]&&[[store existingLocalFilePathForVideoId:key]length])[offline addObject:key];}
 NSDictionary *settings=TRDAutoSettings();NSDictionary *resume=TRDResolveResume(saved,[NSSet setWithArray:pool.allKeys],offline,[settings[@"offlineOnly"]boolValue]);
 if(!resume){
  // AUTOPLAY FALLBACK: Play downloaded offline tracks or saved 6-track playlist!
  NSArray *dl=[store respondsToSelector:@selector(downloadedTracks)]?[store downloadedTracks]:nil;
  if(!dl.count && pool.count > 0) dl = pool.allValues;
  if(dl.count > 0){
   NSMutableArray *q=[NSMutableArray arrayWithArray:dl];
   id first=q[0];
   NSString *fId=[first respondsToSelector:@selector(videoId)]?[first videoId]:@"";
   [(id<TRDAutoPlayerAPI>)player setVolume:1.0f];
   TRDAutoRestoring=YES;TRDAutoStarting=YES;NSUInteger gen=++TRDAutoGeneration;
   [player playQueue:q atIndex:0];TRDAutoStarting=NO;
   TRDFinishAutoResume(player,fId,0,[NSDate dateWithTimeIntervalSinceNow:25],gen);
   TRDAutoLog(@"started-offline-playlist-fallback",@{@"count":@(q.count)});
   return;
  }
  TRDAutoLog(@"no-resumable-last-song",@{@"offlineOnly":settings[@"offlineOnly"]});return;
 }
 NSMutableArray *queue=[NSMutableArray array];for(NSString *key in resume[@"ids"])[queue addObject:pool[key]];
 if(![player respondsToSelector:@selector(setVolume:)]){TRDAutoLog(@"safe-volume-unavailable",nil);return;}
 [(id<TRDAutoPlayerAPI>)player setVolume:[settings[@"startVolume"]floatValue]];TRDAutoRestoring=YES;TRDAutoStarting=YES;NSUInteger generation=++TRDAutoGeneration;
 [player playQueue:queue atIndex:[resume[@"index"]unsignedIntegerValue]];TRDAutoStarting=NO;
 TRDFinishAutoResume(player,resume[@"currentId"],[resume[@"seconds"]doubleValue],[NSDate dateWithTimeIntervalSinceNow:25],generation);
}});}
