#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#include <math.h>
// Pure presentation assessment. Never feeds simulated values into the trip model.
static NSDictionary *TRDDriveGPSStatus(CLLocation *fix,NSDate *now,CLAuthorizationStatus authorization,BOOL hadSpeed){
 BOOL denied=authorization==kCLAuthorizationStatusDenied||authorization==kCLAuthorizationStatusRestricted;
 double age=fix?[now timeIntervalSinceDate:fix.timestamp]:INFINITY;
 BOOL fresh=fix&&isfinite(age)&&fabs(age)<5;
 BOOL accuracy=fresh&&isfinite(fix.horizontalAccuracy)&&fix.horizontalAccuracy>=0&&fix.horizontalAccuracy<=50;
 BOOL speed=accuracy&&isfinite(fix.speed)&&fix.speed>=0&&fix.speed<=250.0/3.6;
 BOOL valid=!denied&&speed;
 NSString *label=denied?@"GPS DISABLED · OPEN SETTINGS":valid?[NSString stringWithFormat:@"GPS LIVE · ±%.0f m",fix.horizontalAccuracy]:!fix?(hadSpeed?@"GPS LOST · WAITING FOR SIGNAL":@"GPS SEARCHING"):!fresh?@"GPS LOST · DATA IS OLD":!accuracy?@"GPS WEAK · NO SPEED":fix.speed<0?@"LOCATION ONLY · NO SPEED":@"GPS UNRELIABLE · NO SPEED";
 NSMutableDictionary *result=[@{@"valid":@(valid),@"label":label,@"age":@(isfinite(age)?age:-1)}mutableCopy];if(valid)result[@"kmh"]=@(fix.speed*3.6);return result;
}
static NSString *TRDDriveTripText(double meters,double seconds,BOOL running,BOOL fresh){
 if(!isfinite(meters)||!isfinite(seconds)||meters<0||seconds<0)return @"TRIP · NO DATA";
 if(!running&&seconds<=0)return @"TRIP · TAP TO START";
 long long total=(long long)MIN(seconds,35999999);NSString *state=running?(fresh?@"LIVE":@"WAITING"):@"SAVED";
 return [NSString stringWithFormat:@"TRIP %.2f km · %02lld:%02lld:%02lld · %@",meters/1000,total/3600,(total/60)%60,total%60,state];
}
static inline BOOL TRDTripFixIsReliable(CLLocation *fix,NSDate *now){
 double age=fix?[now timeIntervalSinceDate:fix.timestamp]:INFINITY;
 return fix&&isfinite(age)&&fabs(age)<5&&isfinite(fix.horizontalAccuracy)&&fix.horizontalAccuracy>=0&&fix.horizontalAccuracy<=25&&isfinite(fix.speed)&&fix.speed>=0;
}
