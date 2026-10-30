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
static NSString *const SessionPath=@"/var/mobile/codex-car/network-session.plist";

typedef CFTypeRef WiFiRef;
typedef void (*AssociationCallback)(WiFiRef,WiFiRef,CFDictionaryRef,int,const void *);
static WiFiRef (*ManagerCreate)(CFAllocatorRef,int);
static CFArrayRef (*CopyDevices)(WiFiRef);
static CFArrayRef (*CopyNetworks)(WiFiRef);
static CFStringRef (*GetSSID)(WiFiRef);
static void (*Schedule)(WiFiRef,CFRunLoopRef,CFStringRef);
static int (*Associate)(WiFiRef,WiFiRef,AssociationCallback,CFDictionaryRef);
static void (*CancelAssociation)(WiFiRef);
static int (*Disassociate)(WiFiRef);

static NSString *CurrentSSID(void){
 NSDictionary *r=CFBridgingRelease(CNCopyCurrentNetworkInfo(CFSTR("en0")));
 return r[@"SSID"]?:@"";
}

static NSString *CurrentAddress(void){
 struct ifaddrs *all=NULL;NSString *result=@"";
 if(getifaddrs(&all)==0){
  for(struct ifaddrs *a=all;a;a=a->ifa_next){
   if(a->ifa_addr&&a->ifa_addr->sa_family==AF_INET&&[[NSString stringWithUTF8String:a->ifa_name]isEqual:@"en0"]){
    char text[INET_ADDRSTRLEN];
    inet_ntop(AF_INET,&((struct sockaddr_in *)a->ifa_addr)->sin_addr,text,sizeof(text));
    result=[NSString stringWithUTF8String:text];
    break;
   }
  }
  freeifaddrs(all);
 }
 return result;
}

@interface TRDNetworkBroker:NSObject{
 WiFiRef _manager,_device,_network;
}
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, copy) NSString *target;
@property (nonatomic, copy) NSString *cameraPrefix;
@property (nonatomic, strong) NSArray *targetList;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDate *deadline,*attemptDeadline,*retryAt,*stableSince;
@property (nonatomic, assign) NSUInteger attempt;
@property (nonatomic, assign) BOOL callbackDone;
@property (nonatomic, assign) int callbackError;
@property (nonatomic, copy) NSString *previousSSID;

-(BOOL)start;
-(void)request:(NSString *)mode;
-(void)attemptJoin;
-(void)tick;
-(void)writePhase:(NSString *)phase error:(NSString *)error;
-(void)associationReturned:(int)error network:(NSString *)ssid;
-(void)failed:(NSString *)error;
-(void)returnMedia;
-(BOOL)isCurrentOnTarget;
-(BOOL)addressReady;
@end

static TRDNetworkBroker *broker;

static void AssociationReturned(WiFiRef device,WiFiRef network,CFDictionaryRef info,int error,const void *context){
 @autoreleasepool{
  NSString *ssid=network?CFBridgingRelease(CFRetain(GetSSID(network))):@"";
  dispatch_async(dispatch_get_main_queue(),^{
   [broker associationReturned:error network:ssid];
  });
 }
}

@implementation TRDNetworkBroker

-(BOOL)start{
 void *library=dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi",RTLD_NOW);
 if(!library)return NO;
 ManagerCreate=dlsym(library,"WiFiManagerClientCreate");
 CopyDevices=dlsym(library,"WiFiManagerClientCopyDevices");
 CopyNetworks=dlsym(library,"WiFiManagerClientCopyNetworks");
 GetSSID=dlsym(library,"WiFiNetworkGetSSID");
 Schedule=dlsym(library,"WiFiManagerClientScheduleWithRunLoop");
 Associate=dlsym(library,"WiFiDeviceClientAssociateAsync");
 CancelAssociation=dlsym(library,"WiFiDeviceClientAssociateCancel");
 Disassociate=dlsym(library,"WiFiDeviceClientDisassociate");
 if(!ManagerCreate||!CopyDevices||!CopyNetworks||!GetSSID||!Schedule||!Associate||!CancelAssociation)return NO;
 _manager=ManagerCreate(kCFAllocatorDefault,0);
 if(!_manager)return NO;
 Schedule(_manager,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);
 CFArrayRef devices=CopyDevices(_manager);
 if(devices&&CFArrayGetCount(devices))_device=CFRetain(CFArrayGetValueAtIndex(devices,0));
 if(devices)CFRelease(devices);
 return _device!=NULL;
}

-(void)writePhase:(NSString *)phase error:(NSString *)error{
 NSDictionary *state=@{
  @"phase":phase?:@"",
  @"mode":self.mode?:@"idle",
  @"targetSSID":self.target?:@"",
  @"actualSSID":CurrentSSID(),
  @"address":CurrentAddress(),
  @"previousSSID":self.previousSSID?:@"",
  @"attempt":@(self.attempt),
  @"associationError":@(self.callbackError),
  @"error":error?:@"",
  @"at":[NSDate date]
 };
 [state writeToFile:StatePath atomically:YES];
 NSMutableArray *history=[[NSArray arrayWithContentsOfFile:HistoryPath]mutableCopy]?:[NSMutableArray array];
 [history addObject:state];
 while(history.count>80)[history removeObjectAtIndex:0];
 [history writeToFile:HistoryPath atomically:YES];
 notify_post("com.codex.trd.network.changed");
}

-(BOOL)isCurrentOnTarget{
 NSString *current=CurrentSSID();
 if(!current.length)return NO;
 if([self.mode isEqual:@"camera"]){
  return [current caseInsensitiveCompare:self.target]==NSOrderedSame || [current localizedCaseInsensitiveContainsString:@"H109"];
 }
 for(NSString *candidate in self.targetList){
  if([current caseInsensitiveCompare:candidate]==NSOrderedSame ||
     [current localizedCaseInsensitiveContainsString:candidate] ||
     [candidate localizedCaseInsensitiveContainsString:current]){
   return YES;
  }
 }
 return NO;
}

-(BOOL)addressReady{
 NSString *address=CurrentAddress();
 if(!address.length||[address hasPrefix:@"169.254."]||[address isEqual:@"0.0.0.0"])return NO;
 BOOL cameraAddress=[address hasPrefix:self.cameraPrefix];
 return [self.mode isEqual:@"camera"]?cameraAddress:!cameraAddress;
}

-(void)request:(NSString *)mode{@autoreleasepool{
 if(![@[@"camera",@"internet"]containsObject:mode])return;
 NSDictionary *config=[NSDictionary dictionaryWithContentsOfFile:ConfigPath];
 
 NSMutableArray *targets=[NSMutableArray array];
 if([mode isEqual:@"camera"]){
  NSString *cam=config[@"cameraSSID"];
  if(cam.length)[targets addObject:cam];
  else [targets addObject:@"H109Y-37802895"];
 }else{
  NSArray *list=config[@"internetSSIDs"];
  if([list isKindOfClass:[NSArray class]]){
   for(id item in list){
    if([item isKindOfClass:[NSString class]]&&[item length])[targets addObject:item];
   }
  }
  NSString *single=config[@"internetSSID"];
  if([single isKindOfClass:[NSString class]]&&single.length&&![targets containsObject:single]){
   [targets insertObject:single atIndex:0];
  }
  if(!targets.count){
   [targets addObject:@"PeePuT"];
   [targets addObject:@"PEEPUT"];
   [targets addObject:@"P-Phut"];
   [targets addObject:@"Silver-L10"];
  }
 }
 
 self.targetList=targets;
 self.target=targets.firstObject;
 self.cameraPrefix=[config[@"cameraIPv4Prefix"]isKindOfClass:[NSString class]]?config[@"cameraIPv4Prefix"]:@"192.168.169.";
 
 NSString *current=CurrentSSID();
 NSString *currentAddr=CurrentAddress();
 BOOL currentIsCamera=([current localizedCaseInsensitiveContainsString:@"H109"]||[currentAddr hasPrefix:self.cameraPrefix]);
 
 // If already connected to target network and IP is valid, complete immediately!
 if([self.mode isEqual:mode]&&[self isCurrentOnTarget]&&[self addressReady]){
  self.target=current;
  [self writePhase:@"ready" error:nil];
  return;
 }
 
 // Cancel any ongoing associate timer/attempt
 [self.timer invalidate];
 self.timer=nil;
 if(_network){CFRelease(_network);_network=NULL;}
 
 // FAST DISASSOCIATION:
 // If switching from camera -> internet: immediately break camera association!
 if([mode isEqual:@"internet"]&&currentIsCamera){
  if(Disassociate&&_device)Disassociate(_device);
  if(CancelAssociation&&_device)CancelAssociation(_device);
  [[NSFileManager defaultManager]removeItemAtPath:SessionPath error:nil];
  [self writePhase:@"disassociating" error:nil];
 }else if([mode isEqual:@"camera"]&&!currentIsCamera&&current.length){
  if(Disassociate&&_device)Disassociate(_device);
  if(CancelAssociation&&_device)CancelAssociation(_device);
  [self writePhase:@"disassociating" error:nil];
 }
 
 self.mode=mode;
 self.attempt=0;
 self.callbackDone=NO;
 self.callbackError=0;
 self.stableSince=nil;
 self.retryAt=nil;
 
 // Fast timeout: 25 seconds total max, checks every 0.25 seconds
 self.deadline=[NSDate dateWithTimeIntervalSinceNow:25];
 self.timer=[NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(tick) userInfo:nil repeats:YES];
 self.timer.tolerance=0.05;
 [self attemptJoin];
}}

-(void)attemptJoin{@autoreleasepool{
 self.attempt++;
 self.callbackDone=NO;
 self.callbackError=0;
 self.retryAt=nil;
 self.stableSince=nil;
 if(_network){CFRelease(_network);_network=NULL;}
 
 if([self isCurrentOnTarget]){
  if([self addressReady]){
   [self.timer invalidate];
   self.timer=nil;
   [self writePhase:@"ready" error:nil];
   return;
  }
  self.attemptDeadline=[NSDate dateWithTimeIntervalSinceNow:3.5];
  [self writePhase:@"joining" error:nil];
  return;
 }
 
 CFArrayRef networks=CopyNetworks(_manager);
 WiFiRef selectedNetwork=NULL;
 NSString *selectedName=nil;
 
 if(networks){
  CFIndex count=CFArrayGetCount(networks);
  if([self.mode isEqual:@"camera"]){
   for(CFIndex i=0;i<count;i++){
    WiFiRef net=CFArrayGetValueAtIndex(networks,i);
    NSString *name=(__bridge NSString *)GetSSID(net);
    if(!name.length)continue;
    if([name caseInsensitiveCompare:self.target]==NSOrderedSame||[name localizedCaseInsensitiveContainsString:@"H109"]){
     selectedNetwork=net;selectedName=name;break;
    }
   }
  }else{
   // Check candidate SSIDs in prioritized order
   for(NSString *candidate in self.targetList){
    for(CFIndex i=0;i<count;i++){
     WiFiRef net=CFArrayGetValueAtIndex(networks,i);
     NSString *name=(__bridge NSString *)GetSSID(net);
     if(!name.length)continue;
     if([name caseInsensitiveCompare:candidate]==NSOrderedSame||
        [name localizedCaseInsensitiveContainsString:candidate]||
        [candidate localizedCaseInsensitiveContainsString:name]){
      selectedNetwork=net;selectedName=name;break;
     }
    }
    if(selectedNetwork)break;
   }
  }
 }
 
 if(selectedNetwork){
  _network=CFRetain(selectedNetwork);
  self.target=selectedName;
 }
 if(networks)CFRelease(networks);
 
 if(!_network){
  if(self.attempt<25){
   // Rapid retry scan interval: 0.5s
   self.retryAt=[NSDate dateWithTimeIntervalSinceNow:0.5];
   [self writePhase:@"scanning" error:nil];
   return;
  }
  [self failed:@"Network not found in scan. Check hotspot availability."];
  return;
 }
 
 self.attemptDeadline=[NSDate dateWithTimeIntervalSinceNow:4.0];
 [self writePhase:@"joining" error:nil];
 
 int result=Associate(_device,_network,AssociationReturned,NULL);
 if(result!=0){
  self.callbackDone=YES;
  self.callbackError=result;
  if(Disassociate&&_device)Disassociate(_device);
  self.retryAt=[NSDate dateWithTimeIntervalSinceNow:0.4];
 }
}}

-(void)associationReturned:(int)error network:(NSString *)ssid{@autoreleasepool{
 if(!self.timer)return;
 self.callbackDone=YES;
 self.callbackError=error;
 if(error!=0){
  if(Disassociate&&_device)Disassociate(_device);
  self.retryAt=[NSDate dateWithTimeIntervalSinceNow:0.4];
 }
}}

-(void)tick{@autoreleasepool{
 if(!self.timer)return;
 
 BOOL onTarget=[self isCurrentOnTarget];
 if(onTarget&&[self addressReady]){
  if(!self.stableSince)self.stableSince=[NSDate date];
  if(-[self.stableSince timeIntervalSinceNow]>=0.1){
   [self.timer invalidate];
   self.timer=nil;
   [self writePhase:@"ready" error:nil];
   return;
  }
 }else{
  self.stableSince=nil;
 }
 
 if([self.deadline timeIntervalSinceNow]<=0){
  if(!onTarget&&CancelAssociation&&_device)CancelAssociation(_device);
  [self failed:@"Wi-Fi switch timed out."];
  return;
 }
 
 if(self.retryAt){
  if([self.retryAt timeIntervalSinceNow]<=0)[self attemptJoin];
  return;
 }
 
 if((self.callbackDone&&self.callbackError&&!onTarget)||(!onTarget&&[self.attemptDeadline timeIntervalSinceNow]<=0)){
  if(Disassociate&&_device)Disassociate(_device);
  if(CancelAssociation&&_device)CancelAssociation(_device);
  if(self.attempt>=20){
   [self failed:@"Could not join network. Check hotspot availability."];
   return;
  }
  self.retryAt=[NSDate dateWithTimeIntervalSinceNow:0.5];
 }
}}

-(void)failed:(NSString *)error{
 [self.timer invalidate];
 self.timer=nil;
 [self writePhase:@"error" error:error];
}

-(void)returnMedia{
 NSDictionary *saved=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/last-media.plist"];
 NSString *bundle=saved[@"bundle"];
 NSArray *allowed=@[@"com.legacymusic.app",@"com.himais0giiiin.ytnine",@"com.codex.poddash"];
 if(![allowed containsObject:bundle])bundle=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/sound-source.plist"][@"bundle"];
 if(![allowed containsObject:bundle])bundle=@"com.himais0giiiin.ytnine";
 
 [self request:@"internet"];
 NSString *destination=[bundle copy];
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
  char *args[]={(char *)"/usr/bin/activator",(char *)"send",(char *)destination.UTF8String,NULL};
  pid_t child=0;
  int result=posix_spawn(&child,args[0],NULL,NULL,args,NULL);
  if(!result){
   pid_t(*wait)(pid_t,int *,int)=dlsym(RTLD_DEFAULT,"waitpid");
   if(wait)wait(child,NULL,0);
  }
  [@{@"bundle":destination,@"spawnResult":@(result),@"at":[NSDate date]}writeToFile:@"/var/mobile/codex-car/media-return.plist" atomically:YES];
 });
}

@end

int main(int argc,char **argv){@autoreleasepool{
 if(argc==2){
  NSString *action=[NSString stringWithUTF8String:argv[1]];
  if([action isEqual:@"camera"])return notify_post("com.codex.trd.network.camera");
  if([action isEqual:@"internet"])return notify_post("com.codex.trd.network.internet");
  if([action isEqual:@"status"]){
   NSDictionary *st=[NSDictionary dictionaryWithContentsOfFile:StatePath];
   printf("Mode: %s | Phase: %s | Target: %s | Actual: %s | Addr: %s\n",
    [st[@"mode"] UTF8String]?:"" , [st[@"phase"] UTF8String]?:"", [st[@"targetSSID"] UTF8String]?:"", [st[@"actualSSID"] UTF8String]?:"", [st[@"address"] UTF8String]?:"");
   return 0;
  }
  return 2;
 }
 TRDCarWatch *carWatch=[TRDCarWatch new];
 [carWatch start];
 broker=[TRDNetworkBroker new];
 if(![broker start])return 3;
 
 int cameraToken=0,internetToken=0,mediaToken=0;
 notify_register_dispatch("com.codex.trd.media.return",&mediaToken,dispatch_get_main_queue(),^(int token){[broker returnMedia];});
 notify_register_dispatch("com.codex.trd.network.camera",&cameraToken,dispatch_get_main_queue(),^(int token){[broker request:@"camera"];});
 notify_register_dispatch("com.codex.trd.network.internet",&internetToken,dispatch_get_main_queue(),^(int token){[broker request:@"internet"];});
 
 int carConnToken=0;
 notify_register_dispatch("com.codex.trd.car.connection.changed",&carConnToken,dispatch_get_main_queue(),^(int token){
  NSDictionary *st=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/car-start-state.plist"];
  if([st[@"connected"]boolValue]&&![broker.mode isEqual:@"camera"]){[broker request:@"internet"];}
 });
 [broker writePhase:@"idle" error:nil];
 [[NSRunLoop currentRunLoop]run];
 return 0;
}}
