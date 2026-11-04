#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#include <math.h>
// Only aggregate distance/time/speed are persisted, never route coordinates.
static BOOL TRDTripModelFixIsReliable(CLLocation *fix,NSDate *now){
 return fix&&fabs([fix.timestamp timeIntervalSinceDate:now])<=5&&
  isfinite(fix.horizontalAccuracy)&&fix.horizontalAccuracy>=0&&fix.horizontalAccuracy<=25&&
  isfinite(fix.speed)&&fix.speed>=0&&fix.speed<=250.0/3.6&&
  CLLocationCoordinate2DIsValid(fix.coordinate);
}
@interface TRDTrip:NSObject
@property double meters,seconds,maximum;
@property BOOL running;
@property BOOL manuallyPaused;
@property CLLocation *previous;
@property NSDate *lastFixTimestamp;
-(void)accept:(CLLocation *)fix now:(NSDate *)now;
-(void)breakSegment;
-(void)start;
-(void)pause;
-(NSDictionary *)summary;
-(void)restore:(NSDictionary *)summary;
@end
@implementation TRDTrip
-(void)breakSegment{self.previous=nil;self.running=NO;}
-(void)start{if(!self.manuallyPaused)return;self.manuallyPaused=NO;[self breakSegment];}
-(void)pause{self.manuallyPaused=YES;[self breakSegment];}
-(void)accept:(CLLocation *)fix now:(NSDate *)now{
 if(self.manuallyPaused){[self breakSegment];return;}
 if(!TRDTripModelFixIsReliable(fix,now)){[self breakSegment];return;}
 if(self.lastFixTimestamp&&[fix.timestamp timeIntervalSinceDate:self.lastFixTimestamp]<=0)return;
 self.lastFixTimestamp=fix.timestamp;
 // Start at 3 km/h; pause below 1.8 km/h. Separate thresholds avoid GPS chatter.
 if(fix.speed<.5||(!self.running&&fix.speed<3.0/3.6)){[self breakSegment];return;}
 CLLocation *old=self.previous;
 self.running=YES;
 if(!old){self.previous=fix;return;}
 double dt=[fix.timestamp timeIntervalSinceDate:old.timestamp];
 if(dt>10){self.previous=fix;return;}
 double displacement=[fix distanceFromLocation:old];
 if(!isfinite(displacement)||displacement>80*dt+old.horizontalAccuracy+fix.horizontalAccuracy){[self breakSegment];return;}
 self.previous=fix;self.seconds+=dt;self.meters+=(old.speed+fix.speed)*.5*dt;
 self.maximum=MAX(self.maximum,MAX(old.speed,fix.speed)*3.6);
}
-(NSDictionary *)summary{return @{@"meters":@(self.meters),@"seconds":@(self.seconds),@"maximum":@(self.maximum),@"manuallyPaused":@(self.manuallyPaused)};}
-(void)restore:(NSDictionary *)d{
 double m=[d[@"meters"]isKindOfClass:[NSNumber class]]?[d[@"meters"]doubleValue]:0;
 double s=[d[@"seconds"]isKindOfClass:[NSNumber class]]?[d[@"seconds"]doubleValue]:0;
 double v=[d[@"maximum"]isKindOfClass:[NSNumber class]]?[d[@"maximum"]doubleValue]:0;
 self.meters=isfinite(m)&&m>=0&&m<1e10?m:0;
 self.seconds=isfinite(s)&&s>=0&&s<1e9?s:0;
 self.maximum=isfinite(v)&&v>=0&&v<=250?v:0;
 self.manuallyPaused=[d[@"manuallyPaused"]isKindOfClass:[NSNumber class]]?[d[@"manuallyPaused"]boolValue]:NO;
 self.lastFixTimestamp=nil;[self breakSegment];
}
@end
