#import <Foundation/Foundation.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#include <dlfcn.h>
#include <notify.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <spawn.h>
#import "TRDCarWatch.h"

// The service accepts only camera/internet intents. Wi-Fi credentials remain in
// the existing system network records; they are never copied into these files.
static NSString *const ConfigPath=@"/var/mobile/codex-car/network-config.plist";
static NSString *const StatePath=@"/var/mobile/codex-car/network-state.plist";
static NSString *const HistoryPath=@"/var/mobile/codex-car/network-history.plist";
typedef CFTypeRef WiFiRef;
typedef void (*AssociationCallback)(WiFiRef,WiFiRef,CFDictionaryRef,int,const void *);
static WiFiRef (*ManagerCreate)(CFAllocatorRef,int);
static CFArrayRef (*CopyDevices)(WiFiRef);
static CFArrayRef (*CopyNetworks)(WiFiRef);
static CFStringRef (*GetSSID)(WiFiRef);
static void (*Schedule)(WiFiRef,CFRunLoopRef,CFStringRef);
static int (*Associate)(WiFiRef,WiFiRef,AssociationCallback,CFDictionaryRef);
static void (*CancelAssociation)(WiFiRef);

static NSString *CurrentSSID(void){NSDictionary *r=CFBridgingRelease(CNCopyCurrentNetworkInfo(CFSTR("en0")));return r[@"SSID"]?:@"";}
static NSString *CurrentAddress(void){struct ifaddrs *all=NULL;NSString *result=@"";if(getifaddrs(&all)==0){for(struct ifaddrs *a=all;a;a=a->ifa_next){if(a->ifa_addr&&a->ifa_addr->sa_family==AF_INET&&[[NSString stringWithUTF8String:a->ifa_name]isEqual:@"en0"]){char text[INET_ADDRSTRLEN];inet_ntop(AF_INET,&((struct sockaddr_in *)a->ifa_addr)->sin_addr,text,sizeof(text));result=[NSString stringWithUTF8String:text];break;}}freeifaddrs(all);}return result;}

@interface TRDNetworkBroker:NSObject{
 WiFiRef _manager,_device,_network;
}
@property NSString *mode,*target,*cameraPrefix;
@property NSTimer *timer;
@property NSDate *deadline,*attemptDeadline,*retryAt,*stableSince;
@property NSUInteger attempt;
@property BOOL callbackDone;
@property int callbackError;
@property NSString *previousSSID;
@property BOOL restoring;
-(BOOL)start;
-(void)request:(NSString *)mode;
-(void)attemptJoin;
-(void)tick;
-(void)writePhase:(NSString *)phase error:(NSString *)error;
-(void)associationReturned:(int)error network:(NSString *)ssid;
-(void)failed:(NSString *)error;
-(void)returnMedia;
@end
static TRDNetworkBroker *broker;
static void AssociationReturned(WiFiRef device,WiFiRef network,CFDictionaryRef info,int error,const void *context){@autoreleasepool{NSString *ssid=network?[( __bridge NSString *)GetSSID(network)copy]:@"";dispatch_async(dispatch_get_main_queue(),^{[broker associationReturned:error network:ssid];});}}

@implementation TRDNetworkBroker
-(BOOL)start{
 void *library=dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi",RTLD_NOW);if(!library)return NO;
 ManagerCreate=dlsym(library,"WiFiManagerClientCreate");CopyDevices=dlsym(library,"WiFiManagerClientCopyDevices");CopyNetworks=dlsym(library,"WiFiManagerClientCopyNetworks");GetSSID=dlsym(library,"WiFiNetworkGetSSID");Schedule=dlsym(library,"WiFiManagerClientScheduleWithRunLoop");Associate=dlsym(library,"WiFiDeviceClientAssociateAsync");CancelAssociation=dlsym(library,"WiFiDeviceClientAssociateCancel");
 if(!ManagerCreate||!CopyDevices||!CopyNetworks||!GetSSID||!Schedule||!Associate||!CancelAssociation)return NO;
 _manager=ManagerCreate(kCFAllocatorDefault,0);if(!_manager)return NO;Schedule(_manager,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);
 CFArrayRef devices=CopyDevices(_manager);if(devices&&CFArrayGetCount(devices))_device=CFRetain(CFArrayGetValueAtIndex(devices,0));if(devices)CFRelease(devices);return _device!=NULL;
}
-(void)writePhase:(NSString *)phase error:(NSString *)error{
 NSDictionary *state=@{@"phase":phase,@"mode":self.mode?:@"idle",@"targetSSID":self.target?:@"",@"actualSSID":CurrentSSID(),@"address":CurrentAddress(),@"previousSSID":self.previousSSID?:@"",@"cameraUnavailable":@(self.restoring),@"attempt":@(self.attempt),@"associationError":@(self.callbackError),@"error":error?:@"",@"at":[NSDate date]};
 [state writeToFile:StatePath atomically:YES];NSMutableArray *history=[[NSArray arrayWithContentsOfFile:HistoryPath]mutableCopy]?:[NSMutableArray array];[history addObject:state];while(history.count>80)[history removeObjectAtIndex:0];[history writeToFile:HistoryPath atomically:YES];notify_post("com.codex.trd.network.changed");
}
-(BOOL)addressReady{
 NSString *address=CurrentAddress();if(!address.length||[address hasPrefix:@"169.254."]||[address isEqual:@"0.0.0.0"])return NO;
 BOOL cameraAddress=[address hasPrefix:self.cameraPrefix];return [self.mode isEqual:@"camera"]?cameraAddress:!cameraAddress;
}
-(void)request:(NSString *)mode{@autoreleasepool{
 if(![@[@"camera",@"internet"]containsObject:mode])return;
 NSDictionary *config=[NSDictionary dictionaryWithContentsOfFile:ConfigPath];NSString *target=config[[mode isEqual:@"camera"]?@"cameraSSID":@"internetSSID"];
 NSString *current=CurrentSSID();
 if([mode isEqual:@"internet"]){
  if(!self.previousSSID.length)self.previousSSID=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/network-session.plist"][@"previousSSID"];
  if(self.previousSSID.length&&![self.previousSSID isEqual:config[@"cameraSSID"]])target=self.previousSSID;
 }
 if(self.timer&&[self.mode isEqual:mode]&&[self.target isEqual:target]){[self writePhase:@"joining" error:nil];return;}
 BOOL pending=self.timer&&!self.callbackDone;[self.timer invalidate];self.timer=nil;if(pending&&_device)CancelAssociation(_device);if(_network){CFRelease(_network);_network=NULL;}
 if([mode isEqual:@"camera"]&&current.length&&![current isEqual:config[@"cameraSSID"]]){self.previousSSID=current;[@{@"previousSSID":current}writeToFile:@"/var/mobile/codex-car/network-session.plist" atomically:YES];}self.restoring=NO;
 self.mode=mode;self.target=[target isKindOfClass:[NSString class]]?target:@"";self.cameraPrefix=[config[@"cameraIPv4Prefix"]isKindOfClass:[NSString class]]?config[@"cameraIPv4Prefix"]:@"192.168.169.";self.attempt=0;self.callbackDone=NO;self.callbackError=0;self.stableSince=nil;self.retryAt=nil;
 // Keep an already usable non-camera network outside the car.
 if([mode isEqual:@"internet"]&&current.length&&![current isEqual:config[@"cameraSSID"]]&&[self addressReady]){self.target=current;[self writePhase:@"ready" error:nil];return;}
 if(!self.target.length){[self writePhase:@"error" error:@"Requested Wi-Fi network is not configured."];return;}
 if([CurrentSSID()isEqual:self.target]&&[self addressReady]){[self writePhase:@"ready" error:nil];return;}
 self.deadline=[NSDate dateWithTimeIntervalSinceNow:45];self.timer=[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(tick) userInfo:nil repeats:YES];self.timer.tolerance=.1;[self attemptJoin];
}}
-(void)attemptJoin{@autoreleasepool{
 self.attempt++;self.callbackDone=NO;self.callbackError=0;self.retryAt=nil;self.stableSince=nil;if(_network){CFRelease(_network);_network=NULL;}
 if([CurrentSSID()isEqual:self.target]){self.attemptDeadline=[NSDate dateWithTimeIntervalSinceNow:12];[self writePhase:@"joining" error:nil];return;}
 CFArrayRef networks=CopyNetworks(_manager);for(CFIndex i=0;networks&&i<CFArrayGetCount(networks);i++){WiFiRef network=CFArrayGetValueAtIndex(networks,i);if([self.target isEqual:(__bridge NSString *)GetSSID(network)]){_network=CFRetain(network);break;}}if(networks)CFRelease(networks);
 if(!_network){
  if(self.attempt<15){
   self.retryAt=[NSDate dateWithTimeIntervalSinceNow:2.0];
   [self writePhase:@"scanning" error:nil];
   return;
  }
  [self failed:@"Save this Wi-Fi network in iPad Settings first."];return;
 }
 self.attemptDeadline=[NSDate dateWithTimeIntervalSinceNow:25];[self writePhase:@"joining" error:nil];int result=Associate(_device,_network,AssociationReturned,NULL);if(result){self.callbackDone=YES;self.callbackError=result;}
}}
-(void)associationReturned:(int)error network:(NSString *)ssid{@autoreleasepool{if(!self.timer||![ssid isEqual:self.target])return;self.callbackDone=YES;self.callbackError=error;}}
-(void)tick{@autoreleasepool{
 if(!self.timer)return;
 BOOL onTarget=[CurrentSSID()isEqual:self.target];
 if(onTarget&&[self addressReady]){if(!self.stableSince)self.stableSince=[NSDate date];if(-[self.stableSince timeIntervalSinceNow]>=0.3){[self.timer invalidate];self.timer=nil;[self writePhase:self.restoring?@"restored":@"ready" error:nil];return;}}else self.stableSince=nil;
 if([self.deadline timeIntervalSinceNow]<=0){if(!onTarget)CancelAssociation(_device);[self failed:@"Wi-Fi connection timed out. Check the camera or iPhone hotspot."];return;}
 if(self.retryAt){if([self.retryAt timeIntervalSinceNow]<=0)[self attemptJoin];return;}
 if((self.callbackDone&&self.callbackError&&!onTarget)||(!onTarget&&[self.attemptDeadline timeIntervalSinceNow]<=0)){if(!self.callbackDone&&!onTarget)CancelAssociation(_device);if(self.attempt>=12){[self failed:@"Could not join the saved network. Check its availability in Settings."];return;}self.retryAt=[NSDate dateWithTimeIntervalSinceNow:2];}
}}
-(void)failed:(NSString *)error{[self.timer invalidate];self.timer=nil;if(NO && [self.mode isEqual:@"camera"]&&!self.restoring){self.restoring=YES;self.previousSSID=self.previousSSID?:[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/network-session.plist"][@"previousSSID"];if(self.previousSSID.length){self.mode=@"restore";self.target=self.previousSSID;self.attempt=0;self.callbackError=0;self.retryAt=nil;self.stableSince=nil;if([CurrentSSID()isEqual:self.target]&&[self addressReady]){[self writePhase:@"restored" error:error];return;}self.deadline=[NSDate dateWithTimeIntervalSinceNow:40];self.timer=[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(tick) userInfo:nil repeats:YES];[self writePhase:@"restoring" error:error];[self attemptJoin];return;}}[self writePhase:@"error" error:error];}
-(void)returnMedia{NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/last-media.plist"];NSString *bundle=saved[@"bundle"];NSArray *allowed=@[@"com.legacymusic.app",@"com.himais0giiiin.ytnine",@"com.codex.poddash"];if(![allowed containsObject:bundle])bundle=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/sound-source.plist"][@"bundle"];if(![allowed containsObject:bundle])return;[self request:@"internet"];NSString *destination=[bundle copy];dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{char *args[]={(char *)"/usr/bin/activator",(char *)"send",(char *)destination.UTF8String,NULL};pid_t child=0;int result=posix_spawn(&child,args[0],NULL,NULL,args,NULL);if(!result){pid_t(*wait)(pid_t,int *,int)=dlsym(RTLD_DEFAULT,"waitpid");if(wait)wait(child,NULL,0);}[@{@"bundle":destination,@"spawnResult":@(result),@"at":[NSDate date]}writeToFile:@"/var/mobile/codex-car/media-return.plist" atomically:YES];});}
@end

int main(int argc,char **argv){@autoreleasepool{
 if(argc==2){NSString *action=[NSString stringWithUTF8String:argv[1]];if([action isEqual:@"camera"])return notify_post("com.codex.trd.network.camera");if([action isEqual:@"internet"])return notify_post("com.codex.trd.network.internet");return 2;}
 TRDCarWatch *carWatch=[TRDCarWatch new];[carWatch start];
 broker=[TRDNetworkBroker new];if(![broker start])return 3;int cameraToken=0,internetToken=0,mediaToken=0;
 notify_register_dispatch("com.codex.trd.media.return",&mediaToken,dispatch_get_main_queue(),^(int token){[broker returnMedia];});
 notify_register_dispatch("com.codex.trd.network.camera",&cameraToken,dispatch_get_main_queue(),^(int token){[broker request:@"camera"];});
 notify_register_dispatch("com.codex.trd.network.internet",&internetToken,dispatch_get_main_queue(),^(int token){[broker request:@"internet"];});
 int carConnToken=0;
 notify_register_dispatch("com.codex.trd.car.connection.changed",&carConnToken,dispatch_get_main_queue(),^(int token){
  NSDictionary *st=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/car-start-state.plist"];
  if([st[@"connected"]boolValue]&&![broker.mode isEqual:@"camera"]){[broker request:@"internet"];}
 });
 [broker writePhase:@"idle" error:nil];[[NSRunLoop currentRunLoop]run];return 0;
}}
