// trd-bt: native Bluetooth helper for the car (replaces cycript-based connect-car.cy)
// usage: trd-bt status | trd-bt connect [name] [timeoutSec]
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <dlfcn.h>

@interface BluetoothManager : NSObject
+(id)sharedInstance;
-(BOOL)available;-(BOOL)enabled;-(BOOL)powered;-(BOOL)setEnabled:(BOOL)e;-(BOOL)setPowered:(BOOL)p;
-(NSArray *)pairedDevices;-(NSArray *)connectedDevices;
@end
@interface BluetoothDevice : NSObject
-(NSString *)name;-(NSString *)address;-(BOOL)connected;-(void)connect;
-(void)connectWithServices:(unsigned)s;-(unsigned)connectedServices;-(unsigned)connectedServicesCount;
-(BOOL)isServiceSupported:(unsigned)s;
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
static BluetoothDevice *findCar(BluetoothManager *m,NSString *want){
 for(BluetoothDevice *d in [m pairedDevices]){NSString *n=[[d name]lowercaseString]?:@"";
  if([n isEqual:want.lowercaseString]||[n rangeOfString:@"car multimedia"].location!=NSNotFound)return d;}
 return nil;
}
static void status(BluetoothManager *m){
 logline([NSString stringWithFormat:@"available=%d enabled=%d powered=%d route=%@",[m available],[m enabled],[m powered],routeDesc()]);
 for(BluetoothDevice *d in [m pairedDevices]){
  unsigned cs=[d respondsToSelector:@selector(connectedServices)]?[d connectedServices]:0;
  logline([NSString stringWithFormat:@"paired '%@' %@ connected=%d services=0x%x",[d name],[d address],[d connected],cs]);
 }
 logline([NSString stringWithFormat:@"connectedDevices=%lu",(unsigned long)[[m connectedDevices]count]]);
}
int main(int argc,char **argv){@autoreleasepool{
 dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager",RTLD_NOW);
 Class C=NSClassFromString(@"BluetoothManager");if(!C){logline(@"no BluetoothManager");return 2;}
 BluetoothManager *m=[C sharedInstance];
 for(int i=0;i<20&&![m available];i++)spin(.25);
 NSString *cmd=argc>1?[NSString stringWithUTF8String:argv[1]]:@"status";
 if([cmd isEqual:@"status"]){status(m);return 0;}
 if([cmd isEqual:@"connect"]){
  NSString *want=argc>2?[NSString stringWithUTF8String:argv[2]]:@"CAR MULTIMEDIA";
  double timeout=argc>3?atof(argv[3]):60;
  NSDate *end=[NSDate dateWithTimeIntervalSinceNow:timeout];
  NSFileManager *fm=[NSFileManager defaultManager];
  if(![m enabled]){[m setPowered:YES];[m setEnabled:YES];}
  int attempt=0;
  while([end timeIntervalSinceNow]>0){
   if(![fm fileExistsAtPath:@"/var/mobile/codex-car/power-connected"]){logline(@"cancel: power removed");return 3;}
   if(![m enabled]||![m powered]){logline(@"waiting for bluetooth power");[m setPowered:YES];[m setEnabled:YES];spin(2);continue;}
   BluetoothDevice *d=findCar(m,want);
   if(!d){logline(@"car not paired");return 4;}
   if([d connected]){
    // Make sure the media (A2DP+AVRCP) profile is up, not only hands-free.
    unsigned cs=[d respondsToSelector:@selector(connectedServices)]?[d connectedServices]:0;
    logline([NSString stringWithFormat:@"connected services=0x%x route=%@",cs,routeDesc()]);
    if((cs & 0x200) && [routeDesc() rangeOfString:@"BluetoothA2DP"].location!=NSNotFound){logline(@"A2DP+AVRCP route OK");return 0;}
    if(attempt<8&&[d respondsToSelector:@selector(connectWithServices:)]){logline(@"requesting A2DP+AVRCP (0x210)");[d connectWithServices:0x10|0x200];}
    attempt++;spin(3);
    if(attempt>=10)return 0;
    continue;
   }
   attempt++;logline([NSString stringWithFormat:@"connect attempt %d",attempt]);
   if([d respondsToSelector:@selector(connectWithServices:)]){
    [d connectWithServices:0x10|0x200];
   } else {
    [d connect];
   }
   spin(5);
  }
  logline(@"timeout");return 1;
 }
 return 0;
}}
