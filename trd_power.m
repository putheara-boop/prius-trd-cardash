#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <notify.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc > 1) {
            NSString *arg = [NSString stringWithUTF8String:argv[1]];
            if ([arg isEqualToString:@"--sleep"] || [arg isEqualToString:@"--screen-off"]) {
                notify_post("com.codex.trd.sleep");
                return 0;
            }
            if ([arg isEqualToString:@"--wake"] || [arg isEqualToString:@"--screen-on"]) {
                notify_post("com.codex.trd.wake");
                return 0;
            }
            if ([arg isEqualToString:@"--status"]) {
                notify_post("com.codex.trd.status");
                usleep(350000);
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/sb-power-state.plist"];
                if (dict) {
                    printf("%s\n", [[dict description] UTF8String]);
                } else {
                    printf("No sb-power-state.plist found\n");
                }
                return 0;
            }
        }
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
        int state = (int)[UIDevice currentDevice].batteryState;
        float level = [UIDevice currentDevice].batteryLevel;
        printf("STATE: %d, LEVEL: %.2f\n", state, level);
        return (state == 2 || state == 3) ? 0 : 1;
    }
}
