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
typedef void (*ScanCallback)(WiFiRef,CFArrayRef,int,const void *);
static WiFiRef (*ManagerCreate)(CFAllocatorRef,int);
static CFArrayRef (*CopyDevices)(WiFiRef);
static CFArrayRef (*CopyNetworks)(WiFiRef);
static CFStringRef (*GetSSID)(WiFiRef);
static void (*Schedule)(WiFiRef,CFRunLoopRef,CFStringRef);
static int (*Associate)(WiFiRef,WiFiRef,AssociationCallback,CFDictionaryRef);
static void (*CancelAssociation)(WiFiRef);
static int (*Disassociate)(WiFiRef);
static int (*ScanAsync)(WiFiRef,CFDictionaryRef,ScanCallback,const void *);
static WiFiRef (*CopyCurrentNetwork)(WiFiRef);
static WiFiRef sActiveDevice;

static NSString *CurrentSSID(void){
 if(sActiveDevice&&CopyCurrentNetwork&&GetSSID){
  WiFiRef net=CopyCurrentNetwork(sActiveDevice);
  if(net){
   CFStringRef raw=GetSSID(net);
   NSString *ssid=raw?[NSString stringWithString:(__bridge NSString *)raw]:@"";
   CFRelease(net);
   if(ssid.length)return ssid;
  }
 }
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
@property (nonatomic, strong) NSArray *scannedNetworks;
@property (nonatomic, strong) NSDate *lastScanAt;
@property (nonatomic, assign) BOOL scanInFlight;
@property (nonatomic, strong) NSDate *scanStartedAt;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDate *deadline,*attemptDeadline,*retryAt,*stableSince;
@property (nonatomic, assign) NSUInteger attempt;
@property (nonatomic, assign) BOOL callbackDone;
@property (nonatomic, assign) int callbackError;
@property (nonatomic, copy) NSString *previousSSID;
@property (nonatomic, strong) NSDate *lastMissingInternetAt;

-(BOOL)start;
-(void)request:(NSString *)mode;
-(void)attemptJoin;
-(void)tick;
-(void)writePhase:(NSString *)phase error:(NSString *)error;
-(void)associationReturned:(int)error network:(NSString *)ssid;
-(void)scanReturned:(NSArray *)results error:(int)error;
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

static void ScanReturned(WiFiRef device,CFArrayRef results,int error,const void *context){
 @autoreleasepool{
  NSMutableArray *captured=[NSMutableArray array];
  if(results){
   CFIndex n=CFArrayGetCount(results);
   for(CFIndex i=0;i<n;i++){
    id net=(__bridge id)CFArrayGetValueAtIndex(results,i);
    if(net)[captured addObject:net];
   }
  }
  dispatch_async(dispatch_get_main_queue(),^{
   [broker scanReturned:captured error:error];
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
 ScanAsync=dlsym(library,"WiFiDeviceClientScanAsync");
 CopyCurrentNetwork=dlsym(library,"WiFiDeviceClientCopyCurrentNetwork");
 if(!ManagerCreate||!CopyDevices||!CopyNetworks||!GetSSID||!Schedule||!Associate||!CancelAssociation)return NO;
 _manager=ManagerCreate(kCFAllocatorDefault,0);
 if(!_manager)return NO;
 Schedule(_manager,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);
 CFArrayRef devices=CopyDevices(_manager);
 if(devices&&CFArrayGetCount(devices))_device=CFRetain(CFArrayGetValueAtIndex(devices,0));
 if(devices)CFRelease(devices);
 sActiveDevice=_device;
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
 if([self.mode isEqual:@"camera"]){
  if(current.length){
   return [current caseInsensitiveCompare:self.target]==NSOrderedSame || [current localizedCaseInsensitiveContainsString:@"H109"] || [current localizedCaseInsensitiveContainsString:@"H108"];
  }
  return [self addressReady];
 }
 if(!current.length)return NO;
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

-(void)triggerScanIfNeeded{
 if(!ScanAsync||!_device)return;
 if(self.scanInFlight&&self.scanStartedAt&&-[self.scanStartedAt timeIntervalSinceNow]<3.5)return;
 self.scanInFlight=YES;
 self.scanStartedAt=[NSDate date];
 ScanAsync(_device,(__bridge CFDictionaryRef)@{},ScanReturned,NULL);
}

-(void)scanReturned:(NSArray *)results error:(int)error{
 self.scanInFlight=NO;
 if(results.count){
  self.scannedNetworks=results;
  self.lastScanAt=[NSDate date];
 }
 if(self.timer&&!_network){
  self.retryAt=nil;
  [self attemptJoin];
 }
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
 BOOL currentIsCamera=([current localizedCaseInsensitiveContainsString:@"H109"]||[current localizedCaseInsensitiveContainsString:@"H108"]||[currentAddr hasPrefix:self.cameraPrefix]);
 
 if([self.mode isEqual:mode]&&self.timer){
  return;
 }

 if([mode isEqual:@"camera"]){
  self.lastMissingInternetAt=nil;
 }else if(currentIsCamera){
  self.lastMissingInternetAt=nil;
 }else if(!current.length && self.lastMissingInternetAt && -[self.lastMissingInternetAt timeIntervalSinceNow]<15.0){
  return;
 }

 if([mode isEqual:@"camera"]&&currentIsCamera&&[currentAddr hasPrefix:self.cameraPrefix]){
  [self.timer invalidate];
  self.timer=nil;
  self.mode=@"camera";
  if(current.length)self.target=current;
  [self writePhase:@"ready" error:nil];
  return;
 }

 if([self.mode isEqual:mode]&&[self isCurrentOnTarget]&&[self addressReady]){
  if(current.length)self.target=current;
  [self writePhase:@"ready" error:nil];
  return;
 }
 
 [self.timer invalidate];
 self.timer=nil;
 if(_network){CFRelease(_network);_network=NULL;}
 
 // Only leave camera Wi-Fi proactively when joining camera mode from another SSID.
 // In internet mode, keep camera Wi-Fi attached until a known internet SSID is actually found in scan.
 if([mode isEqual:@"camera"]&&!currentIsCamera&&current.length){
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
 
 self.deadline=[NSDate dateWithTimeIntervalSinceNow:[mode isEqual:@"camera"]?14.0:12.0];
 self.timer=[NSTimer scheduledTimerWithTimeInterval:0.20 target:self selector:@selector(tick) userInfo:nil repeats:YES];
 self.timer.tolerance=0.05;
 [self attemptJoin];
}}

-(WiFiRef)findMatchingNetworkInList:(NSArray *)list outName:(NSString **)outName{
 if(!list.count)return NULL;
 if([self.mode isEqual:@"camera"]){
  for(id obj in list){
   WiFiRef net=(__bridge WiFiRef)obj;
   NSString *name=(__bridge NSString *)GetSSID(net);
   if(!name.length)continue;
   if([name caseInsensitiveCompare:self.target]==NSOrderedSame||[name localizedCaseInsensitiveContainsString:@"H109"]){
    if(outName)*outName=name;
    return net;
   }
  }
 }else{
  for(NSString *candidate in self.targetList){
   for(id obj in list){
    WiFiRef net=(__bridge WiFiRef)obj;
    NSString *name=(__bridge NSString *)GetSSID(net);
    if(!name.length)continue;
    if([name caseInsensitiveCompare:candidate]==NSOrderedSame||
       [name localizedCaseInsensitiveContainsString:candidate]||
       [candidate localizedCaseInsensitiveContainsString:name]){
     if(outName)*outName=name;
     return net;
    }
   }
  }
 }
 return NULL;
}

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
  self.attemptDeadline=[NSDate dateWithTimeIntervalSinceNow:[self.mode isEqual:@"camera"]?5.0:8.0];
  [self writePhase:@"joining" error:nil];
  return;
 }
 
 WiFiRef selectedNetwork=NULL;
 NSString *selectedName=nil;
 BOOL freshScan=(self.scannedNetworks.count&&self.lastScanAt&&-[self.lastScanAt timeIntervalSinceNow]<15.0);
 if(freshScan){
  selectedNetwork=[self findMatchingNetworkInList:self.scannedNetworks outName:&selectedName];
 }
 if(!selectedNetwork){
  CFArrayRef networks=CopyNetworks(_manager);
  if(networks){
   selectedNetwork=[self findMatchingNetworkInList:(__bridge NSArray *)networks outName:&selectedName];
   if(selectedNetwork){
    _network=CFRetain(selectedNetwork);
    self.target=selectedName;
   }
   CFRelease(networks);
  }
 }else{
  _network=CFRetain(selectedNetwork);
  self.target=selectedName;
 }
 
 if(!_network){
  [self triggerScanIfNeeded];
  BOOL keepCameraOnMissingInternet=([self.mode isEqual:@"internet"]&&[CurrentAddress() hasPrefix:self.cameraPrefix]);
  NSUInteger maxScanAttempts=keepCameraOnMissingInternet?5:([self.mode isEqual:@"internet"]?6:10);
  if(self.attempt<maxScanAttempts){
   self.retryAt=[NSDate dateWithTimeIntervalSinceNow:0.5];
   [self writePhase:@"scanning" error:nil];
   return;
  }
  if([self.mode isEqual:@"internet"])self.lastMissingInternetAt=[NSDate date];
  [self failed:keepCameraOnMissingInternet?@"No internet Wi-Fi in range; kept camera Wi-Fi.":@"Network not found in scan. Check hotspot availability."];
  return;
 }
 
 self.attemptDeadline=[NSDate dateWithTimeIntervalSinceNow:[self.mode isEqual:@"camera"]?5.5:8.5];
 [self writePhase:@"joining" error:nil];
 
 int result=Associate(_device,_network,AssociationReturned,NULL);
 if(result!=0){
  self.callbackDone=YES;
  self.callbackError=result;
  if(![self isCurrentOnTarget]&&Disassociate&&_device)Disassociate(_device);
  self.retryAt=[NSDate dateWithTimeIntervalSinceNow:0.4];
 }
}}

-(void)associationReturned:(int)error network:(NSString *)ssid{@autoreleasepool{
 if(!self.timer)return;
 self.callbackDone=YES;
 self.callbackError=error;
 if(error!=0&&![self isCurrentOnTarget]){
  if(Disassociate&&_device)Disassociate(_device);
  self.scannedNetworks=nil;
  self.retryAt=[NSDate dateWithTimeIntervalSinceNow:0.4];
 }
}}

-(void)tick{@autoreleasepool{
 if(!self.timer)return;
 
 BOOL onTarget=[self isCurrentOnTarget];
 if(onTarget&&[self addressReady]){
  [self.timer invalidate];
  self.timer=nil;
  [self writePhase:@"ready" error:nil];
  return;
 }
 self.stableSince=nil;
 
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
  if(self.attempt>=8){
   if([self.mode isEqual:@"internet"])self.lastMissingInternetAt=[NSDate date];
   [self failed:@"Could not join network. Check hotspot availability."];
   return;
  }
  self.retryAt=[NSDate dateWithTimeIntervalSinceNow:0.5];
 }else if(onTarget&&[self.attemptDeadline timeIntervalSinceNow]<=0){
  self.attemptDeadline=[NSDate dateWithTimeIntervalSinceNow:4.0];
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
 broker=[TRDNetworkBroker new];
 if(![broker start])return 1;
 int cam=0,net=0;
 notify_register_dispatch("com.codex.trd.network.camera",&cam,dispatch_get_main_queue(),^(int t){[broker request:@"camera"];});
 notify_register_dispatch("com.codex.trd.network.internet",&net,dispatch_get_main_queue(),^(int t){[broker request:@"internet"];});
 CFRunLoopRun();
 (void)carWatch;
 return 0;
}}
