#import <Foundation/Foundation.h>
// A brief charger interruption must not create another startup greeting.
static void TRDWelcomeObservePower(NSMutableDictionary *state, BOOL charging, BOOL unplugged, NSDate *now){
 NSDate *off=[state[@"unpluggedAt"] isKindOfClass:[NSDate class]]?state[@"unpluggedAt"]:nil;
 if(unplugged&&!off){state[@"unpluggedAt"]=now;return;}
 if(charging&&off){NSTimeInterval elapsed=[now timeIntervalSinceDate:off];if(elapsed>=15)state[@"shown"]=@NO;[state removeObjectForKey:@"unpluggedAt"];}
}
static BOOL TRDWelcomeTake(NSMutableDictionary *state){if([state[@"shown"] boolValue])return NO;state[@"shown"]=@YES;return YES;}
