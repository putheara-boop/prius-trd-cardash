#import <Foundation/Foundation.h>
#include <math.h>
#include <sys/sysctl.h>
#ifndef TRD_AUTO_DIRECTORY
#define TRD_AUTO_DIRECTORY @"/var/mobile/codex-car"
#endif
static NSString *TRDAutoFile(NSString *name){return [TRD_AUTO_DIRECTORY stringByAppendingPathComponent:name];}
static BOOL TRDAutoEnabled(void){return ![[NSFileManager defaultManager]fileExistsAtPath:TRDAutoFile(@"autoplay-disabled")];}
static BOOL TRDAutoMayPlay(BOOL enabled,BOOL otherAudio,BOOL silenceHint,BOOL interrupted,BOOL alreadyPlaying){return enabled&&!otherAudio&&!silenceHint&&!interrupted&&!alreadyPlaying;}
// Unity gain: legacy startVolume values must not attenuate Ninja behind system volume.
static NSDictionary *TRDAutoSettings(void){NSDictionary *raw=[NSDictionary dictionaryWithContentsOfFile:TRDAutoFile(@"autoplay-settings.plist")];return @{@"startVolume":@1.0,@"offlineOnly":raw[@"offlineOnly"]?:@YES,@"carName":@"CAR MULTIMEDIA"};}
static NSString *TRDBootIdentity(void){struct timeval value={0};size_t size=sizeof(value);int mib[]={CTL_KERN,KERN_BOOTTIME};if(sysctl(mib,2,&value,&size,NULL,0)!=0||value.tv_sec<=0)return nil;return [NSString stringWithFormat:@"%lld",(long long)value.tv_sec];}
// Called only after the Bluetooth observation has been stable for two samples.
static NSDictionary *TRDCarObservation(NSDictionary *old,NSString *boot,BOOL connected,NSDate *now,BOOL initialBootWindow){
 if(!boot.length||!now)return nil;BOOL same=[old[@"boot"]isEqual:boot];BOOL oldConnected=same&&[old[@"connected"]boolValue];BOOL initial=!old||!same;
 if(same&&oldConnected==connected)return old;
 NSMutableDictionary *next=[@{@"boot":boot,@"connected":@(connected),@"at":now}mutableCopy];
 if(connected&&(!initial||initialBootWindow)){next[@"token"]=[NSUUID UUID].UUIDString;next[@"created"]=now;}
 return next;
}
static BOOL TRDFreshCarEvent(NSDictionary *event,NSDictionary *consumed,NSString *boot,NSDate *now){
 if(![event[@"connected"]boolValue]||![event[@"boot"]isEqual:boot]||![event[@"token"]isKindOfClass:[NSString class]]||![event[@"token"]length]||[event[@"token"]isEqual:consumed[@"token"]]||![event[@"created"]isKindOfClass:[NSDate class]])return NO;
 NSTimeInterval age=[now timeIntervalSinceDate:event[@"created"]];return age>=0&&age<=90;
}
static NSDictionary *TRDQueueSnapshot(NSArray *ids,NSInteger index,double seconds){
 if(![ids isKindOfClass:[NSArray class]]||ids.count==0||ids.count>500||index<0||index>=(NSInteger)ids.count)return nil;
 for(id key in ids)if(![key isKindOfClass:[NSString class]]||![key length])return nil;
 return @{@"ids":ids,@"index":@(index),@"currentId":ids[index],@"seconds":@(isfinite(seconds)&&seconds>=0?seconds:0),@"at":[NSDate date]};
}
// Reindex around the same selected ID. Never silently replace a missing song.
static NSDictionary *TRDResolveResume(NSDictionary *saved,NSSet *available,NSSet *offline,BOOL onlyOffline){
 NSArray *ids=saved[@"ids"];NSInteger index=[saved[@"index"]integerValue];if(![ids isKindOfClass:[NSArray class]]||!ids.count||ids.count>500||index<0||index>=(NSInteger)ids.count)return nil;
 NSString *selected=saved[@"currentId"]?:ids[index];if(![selected isKindOfClass:[NSString class]]||![selected isEqual:ids[index]]||![available containsObject:selected]||(onlyOffline&&![offline containsObject:selected]))return nil;
 NSMutableArray *result=[NSMutableArray array];NSInteger position=-1;
 for(NSUInteger i=0;i<ids.count;i++){id key=ids[i];if(![key isKindOfClass:[NSString class]])return nil;if([available containsObject:key]&&(!onlyOffline||[offline containsObject:key])){if((NSInteger)i==index)position=result.count;[result addObject:key];}}
 if(position<0)return nil;double seconds=[saved[@"seconds"]isKindOfClass:[NSNumber class]]?[saved[@"seconds"]doubleValue]:0;
 // Retain a bounded contiguous window including the selected song.
 if(result.count>50){NSUInteger start=(NSUInteger)position>10?(NSUInteger)position-10:0;start=MIN(start,result.count-50);position-=start;result=[[result subarrayWithRange:NSMakeRange(start,50)]mutableCopy];}
 return TRDQueueSnapshot(result,position,seconds);
}
