#import "TRDAutoplayModel.h"
#include <dlfcn.h>
@interface NSObject(TRDCarWatchSelectors)
+(id)sharedInstance;
-(BOOL)enabled;
-(NSArray *)pairedDevices;
-(NSString *)name;
-(BOOL)connected;
@end
@interface TRDCarWatch:NSObject
@property id manager;
@property NSTimer *timer;
@property NSTimeInterval currentInterval;
@property NSInteger lastSample,samples;
-(void)start;
-(void)scheduleTimerWithInterval:(NSTimeInterval)interval;
-(void)poll;
@end
@implementation TRDCarWatch
-(void)scheduleTimerWithInterval:(NSTimeInterval)interval{
 if(self.timer && fabs(self.currentInterval-interval)<0.5)return;
 [self.timer invalidate];
 self.currentInterval=interval;
 self.timer=[NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(poll) userInfo:nil repeats:YES];
 if([self.timer respondsToSelector:@selector(setTolerance:)])self.timer.tolerance=(interval>=10.0)?5.0:0.4;
}
-(void)btNotification:(NSNotification *)note{
 dispatch_async(dispatch_get_main_queue(),^{[self poll];});
}
-(void)start{dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager",RTLD_LAZY);Class cls=NSClassFromString(@"BluetoothManager");if(![cls respondsToSelector:@selector(sharedInstance)])return;self.manager=[cls sharedInstance];self.lastSample=-1;
 NSNotificationCenter *nc=[NSNotificationCenter defaultCenter];
 for(NSString *n in @[@"BluetoothPowerChangedNotification",@"BluetoothAvailabilityChangedNotification",@"BluetoothDeviceConnectSuccessNotification",@"BluetoothDeviceDisconnectSuccessNotification"]){
  [nc addObserver:self selector:@selector(btNotification:) name:n object:nil];
 }
 [self scheduleTimerWithInterval:2.0];
 [self poll];
}
-(void)poll{@autoreleasepool{if(![self.manager respondsToSelector:@selector(enabled)]||![self.manager respondsToSelector:@selector(pairedDevices)])return;
 BOOL btOn=[self.manager enabled];
 [self scheduleTimerWithInterval:btOn?2.0:20.0];
 BOOL connected=NO,known=!btOn;if(!known){id devices=[self.manager pairedDevices];if(![devices isKindOfClass:[NSArray class]])return;for(id device in devices)if([device respondsToSelector:@selector(name)]&&[[device name]isKindOfClass:[NSString class]]&&[[device name]caseInsensitiveCompare:TRDAutoSettings()[@"carName"]]==NSOrderedSame&&[device respondsToSelector:@selector(connected)]){known=YES;connected=[device connected];break;}}if(!known)return;
 NSInteger sample=connected?1:0;if(self.lastSample!=sample){self.lastSample=sample;self.samples=1;return;}if(++self.samples<2)return;self.samples=2;
 NSString *path=TRDAutoFile(@"car-start-state.plist");NSDictionary *old=[NSDictionary dictionaryWithContentsOfFile:path];NSDictionary *next=TRDCarObservation(old,TRDBootIdentity(),connected,[NSDate date],[[NSProcessInfo processInfo]systemUptime]<180);if(next&&![next isEqual:old]){[next writeToFile:path atomically:YES];notify_post("com.codex.trd.car.connection.changed");}
}}
@end
