// trd-bt: clean Bluetooth A2DP + AVRCP helper for Toyota Prius CAR MULTIMEDIA
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>
#include <spawn.h>

extern char **environ;
#ifndef MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK
#define MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK 5
#define MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES 2
typedef struct memorystatus_priority_properties {
 int32_t priority;
 uint64_t user_data;
} memorystatus_priority_properties_t;
extern int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);
#endif

@interface BluetoothManager : NSObject
+(id)sharedInstance;
-(BOOL)available;-(BOOL)enabled;-(BOOL)powered;-(BOOL)setEnabled:(BOOL)e;-(BOOL)setPowered:(BOOL)p;
-(void)connectDevice:(id)dev;
-(NSArray *)pairedDevices;-(NSArray *)connectedDevices;
@end
@interface BluetoothDevice : NSObject
-(NSString *)name;-(NSString *)address;-(BOOL)connected;-(void)connect;-(void)disconnect;
-(unsigned)connectedServices;-(void)setConnectingServicemask:(unsigned)m;-(unsigned)getConnectingServiceMask;
@end

static void spin(double s){[[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:s]];}
static NSString *routeDesc(void){
 NSMutableArray *a=[NSMutableArray array];
 for(AVAudioSessionPortDescription *p in [AVAudioSession sharedInstance].currentRoute.outputs)[a addObject:[NSString stringWithFormat:@"%@(%@)",p.portType,p.portName]];
 return [a componentsJoinedByString:@","];
}
static void logline(NSString *s){
 NSString *l=[NSString stringWithFormat:@"%@ %@\n",[NSDate date],s];printf("%s",l.UTF8String);fflush(stdout);
}
static void hardenDaemonPID(pid_t pid){
 if(pid <= 1) return;
 memorystatus_priority_properties_t props = { .priority = 18, .user_data = 0 };
 memorystatus_control(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES, pid, 0, &props, sizeof(props));
 memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, pid, 64, NULL, 0);
}
static void ensureAVRCPDaemonsAliveAndPinned(void){
 pid_t p = 0;
 char *argv[] = {(char *)"/bin/sh", (char *)"-c", (char *)"/bin/launchctl kickstart -k system/com.apple.BTServer.avrcp >/dev/null 2>&1 || /bin/launchctl start com.apple.BTServer.avrcp >/dev/null 2>&1 || true", NULL};
 posix_spawn(&p, "/bin/sh", NULL, NULL, argv, environ);
 spin(0.35);
 FILE *fp = popen("/bin/ps -eo pid,comm | /bin/grep -E 'BTAvrcp|mediaremoted|bluetoothd|LegacyMusic|YTNine|CarDash' | /bin/grep -v grep", "r");
 if(fp){
  char line[256];
  while(fgets(line, sizeof(line), fp)){
   int pid = atoi(line);
   if(pid > 1) hardenDaemonPID((pid_t)pid);
  }
  pclose(fp);
 }
}
static BluetoothDevice *findCar(BluetoothManager *m,NSString *want){
 for(BluetoothDevice *d in [m pairedDevices]){NSString *n=[[d name]lowercaseString]?:@"";
  if([n isEqual:want.lowercaseString]||[n rangeOfString:@"car multimedia"].location!=NSNotFound)return d;}
 return nil;
}
static void status(BluetoothManager *m){
 logline([NSString stringWithFormat:@"available=%d enabled=%d powered=%d route=%@",[m available],[m enabled],[m powered],routeDesc()]);
 for(BluetoothDevice *d in [m pairedDevices]){
  unsigned cs=[d respondsToSelector:@selector(connectedServices)]?[d connectedServices]:0;
  unsigned cm=[d respondsToSelector:@selector(getConnectingServiceMask)]?[d getConnectingServiceMask]:0;
  logline([NSString stringWithFormat:@"paired '%@' %@ connected=%d services=0x%x mask=0x%x",[d name],[d address],[d connected],cs,cm]);
 }
 logline([NSString stringWithFormat:@"connectedDevices=%lu",(unsigned long)[[m connectedDevices]count]]);
}
int main(int argc,char **argv){@autoreleasepool{
 dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager",RTLD_NOW);
 Class C=NSClassFromString(@"BluetoothManager");if(!C){logline(@"no BluetoothManager");return 2;}
 BluetoothManager *m=[C sharedInstance];
 for(int i=0;i<20&&![m available];i++)spin(.25);
 NSString *cmd=argc>1?[NSString stringWithUTF8String:argv[1]]:@"status";
 if([cmd isEqual:@"harden"]){
  ensureAVRCPDaemonsAliveAndPinned();
  return 0;
 }
 if([cmd isEqual:@"status"]){status(m);return 0;}
 if([cmd isEqual:@"connect"]){
  ensureAVRCPDaemonsAliveAndPinned();
  NSString *want=argc>2?[NSString stringWithUTF8String:argv[2]]:@"CAR MULTIMEDIA";
  double timeout=argc>3?atof(argv[3]):32;
  NSDate *end=[NSDate dateWithTimeIntervalSinceNow:timeout];
  if(![m enabled]||![m powered]){[m setPowered:YES];[m setEnabled:YES];spin(1.5);}
  BluetoothDevice *d=findCar(m,want);
  if(!d){logline(@"car not paired");return 4;}
  if([d respondsToSelector:@selector(setConnectingServicemask:)])[d setConnectingServicemask:0];
  // If stuck on HFP-only (0x1 without A2DP 0x10), cleanly disconnect once and let default [d connect] bring up full A2DP+AVRCP!
  if([d connected] && (([d connectedServices] & 0x10) == 0)){
   logline(@"stuck on HFP-only (0x1); disconnecting cleanly to re-open A2DP+AVRCP...");
   [d disconnect];
   spin(2.5);
  }
  int attempt=0;
  while([end timeIntervalSinceNow]>0){
   d=findCar(m,want);
   if([d respondsToSelector:@selector(setConnectingServicemask:)])[d setConnectingServicemask:0];
   if([d connected]){
    unsigned cs=[d respondsToSelector:@selector(connectedServices)]?[d connectedServices]:0;
    logline([NSString stringWithFormat:@"connected services=0x%x route=%@",cs,routeDesc()]);
    if((cs & 0x10) && [routeDesc() rangeOfString:@"BluetoothA2DP"].location!=NSNotFound){
     logline(@"A2DP+AVRCP audio route active!");
     ensureAVRCPDaemonsAliveAndPinned();
     return 0;
    }
    spin(2.0);
    if(([d connectedServices] & 0x10) && [routeDesc() rangeOfString:@"BluetoothA2DP"].location!=NSNotFound) return 0;
    if(attempt < 2){
     logline(@"re-cycling radio once to force A2DP stream...");
     [m setPowered:NO]; spin(2.0); [m setPowered:YES]; [m setEnabled:YES]; spin(2.8);
     d=findCar(m,want);
    }
   }
   attempt++;
   logline([NSString stringWithFormat:@"connect attempt %d",attempt]);
   if([d respondsToSelector:@selector(connect)])[d connect];
   else if([m respondsToSelector:@selector(connectDevice:)])[m connectDevice:d];
   spin(4.0);
  }
  logline(@"timeout");return 1;
 }
 return 0;
}}
