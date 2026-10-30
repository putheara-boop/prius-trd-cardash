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
@property NSInteger lastSample,samples;
-(void)start;
-(void)poll;
@end
@implementation TRDCarWatch
-(void)start{dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager",RTLD_LAZY);Class cls=NSClassFromString(@"BluetoothManager");if(![cls respondsToSelector:@selector(sharedInstance)])return;self.manager=[cls sharedInstance];self.lastSample=-1;self.timer=[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(poll) userInfo:nil repeats:YES];[self poll];}
-(void)poll{@autoreleasepool{if(![self.manager respondsToSelector:@selector(enabled)]||![self.manager respondsToSelector:@selector(pairedDevices)])return;BOOL connected=NO,known=![self.manager enabled];if(!known){id devices=[self.manager pairedDevices];if(![devices isKindOfClass:[NSArray class]])return;for(id device in devices)if([device respondsToSelector:@selector(name)]&&[[device name]isKindOfClass:[NSString class]]&&[[device name]caseInsensitiveCompare:TRDAutoSettings()[@"carName"]]==NSOrderedSame&&[device respondsToSelector:@selector(connected)]){known=YES;connected=[device connected];break;}}if(!known)return;
 NSInteger sample=connected?1:0;if(self.lastSample!=sample){self.lastSample=sample;self.samples=1;return;}if(++self.samples<2)return;self.samples=2;
 NSString *path=TRDAutoFile(@"car-start-state.plist");NSDictionary *old=[NSDictionary dictionaryWithContentsOfFile:path];NSDictionary *next=TRDCarObservation(old,TRDBootIdentity(),connected,[NSDate date],[[NSProcessInfo processInfo]systemUptime]<180);if(next&&![next isEqual:old]){[next writeToFile:path atomically:YES];notify_post("com.codex.trd.car.connection.changed");}
}}
@end
