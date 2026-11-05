#import <Foundation/Foundation.h>
#import "../TRDWelcomeGate.h"
static void check(BOOL value,const char *reason){if(!value){fprintf(stderr,"FAIL: %s\n",reason);exit(1);}}
int main(){@autoreleasepool{
 NSMutableDictionary *s=[NSMutableDictionary dictionary];NSDate *t=[NSDate dateWithTimeIntervalSince1970:1000];
 TRDWelcomeObservePower(s,YES,NO,t);check(TRDWelcomeTake(s),"first welcome");check(!TRDWelcomeTake(s),"duplicate wake");
 TRDWelcomeObservePower(s,YES,NO,[t dateByAddingTimeInterval:2]);check(!TRDWelcomeTake(s),"charging/full transition");
 TRDWelcomeObservePower(s,NO,YES,[t dateByAddingTimeInterval:10]);TRDWelcomeObservePower(s,YES,NO,[t dateByAddingTimeInterval:13]);check(!TRDWelcomeTake(s),"brief power drop");
 TRDWelcomeObservePower(s,NO,YES,[t dateByAddingTimeInterval:20]);TRDWelcomeObservePower(s,NO,YES,[t dateByAddingTimeInterval:30]);TRDWelcomeObservePower(s,YES,NO,[t dateByAddingTimeInterval:40]);check(TRDWelcomeTake(s),"restart after prolonged off");check(!TRDWelcomeTake(s),"duplicate wake after restart");
 NSMutableDictionary *restored=[[s copy]mutableCopy];check(!TRDWelcomeTake(restored),"persists across app restart");puts("welcome power gate tests passed");return 0;
}}
