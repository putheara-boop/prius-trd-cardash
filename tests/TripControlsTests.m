#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "../TRDTrip.h"

static CLLocation *fix(double t,double speed,double accuracy,double lat){return [[CLLocation alloc]initWithCoordinate:CLLocationCoordinate2DMake(lat,100) altitude:0 horizontalAccuracy:accuracy verticalAccuracy:10 course:0 speed:speed timestamp:[NSDate dateWithTimeIntervalSince1970:t]];}
static void feed(TRDTrip *trip,double at,double speed,double accuracy,double lat){[trip accept:fix(at,speed,accuracy,lat) now:[NSDate dateWithTimeIntervalSince1970:at]];}
static void expect(BOOL passed,NSString *message){if(!passed){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
int main(){@autoreleasepool{
 TRDTrip *t=[TRDTrip new];
 feed(t,1000,20,5,13);feed(t,1003,20,5,13.00054);
 expect(t.running&&fabs(t.meters-60)<.001&&t.seconds==3&&t.maximum==72,@"starts automatically and integrates moving fixes");
 feed(t,1006,0,5,13.00054);feed(t,1010,.1,5,13.00054);
 expect(!t.running&&t.meters==60&&t.seconds==3,@"stop pauses both distance and moving time");
 feed(t,1020,20,5,13.00054);feed(t,1023,20,5,13.00108);
 expect(t.running&&t.meters==120&&t.seconds==6,@"movement resumes cumulatively without bridging parked time");
 feed(t,1023,0,5,13.00108);expect(t.running&&t.seconds==6,@"duplicate fix does not alter movement state");
 feed(t,1026,20,100,13.002);expect(!t.running,@"bad accuracy pauses tracking");
 feed(t,1029,20,5,13.002);feed(t,1032,20,5,13.00254);
 expect(t.meters==180&&t.seconds==9,@"GPS recovery resumes totals without bridging missing interval");
 feed(t,1050,20,5,13.003);expect(t.seconds==9,@"long gap ignored");feed(t,1053,20,5,13.00354);expect(t.meters==240&&t.seconds==12,@"new continuous fixes resume after gap");
 feed(t,1056,20,5,14);expect(!t.running&&t.meters==240&&t.seconds==12,@"teleport does not create trip distance");
 NSDictionary *summary=[t summary];expect(summary.count==4,@"only aggregate totals persisted");
 TRDTrip *restored=[TRDTrip new];[restored restore:summary];expect(!restored.running&&restored.meters==240,@"reload keeps total and awaits new movement");
 feed(restored,2000,20,5,13);feed(restored,2003,20,5,13.00054);expect(restored.running&&restored.meters==300&&restored.seconds==15,@"reload starts automatically and adds to previous trip");
 TRDTrip *reset=[TRDTrip new];expect(reset.meters==0&&reset.seconds==0&&reset.maximum==0,@"reset clears aggregates");feed(reset,1000,10,5,13);feed(reset,1002,10,5,13.00018);expect(reset.running&&reset.meters==20,@"reset leaves automatic tracking ready");
 TRDTrip *slow=[TRDTrip new];feed(slow,1000,.6,5,13);expect(!slow.running,@"low-speed noise does not start trip");feed(slow,1001,.9,5,13);feed(slow,1003,.6,5,13);expect(slow.running&&slow.seconds==2,@"hysteresis keeps legitimate slow movement");feed(slow,1004,.4,5,13);expect(!slow.running&&slow.seconds==2,@"low stop threshold pauses trip");feed(slow,1005,.6,5,13);expect(!slow.running,@"does not chatter between paused and moving");
 TRDTrip *bad=[TRDTrip new];[bad accept:fix(900,20,5,13) now:[NSDate dateWithTimeIntervalSince1970:1000]];expect(!bad.running,@"stale fix rejected");feed(bad,1000,NAN,5,13);feed(bad,1001,-1,5,13);feed(bad,1002,80,5,13);expect(!bad.running&&bad.seconds==0,@"invalid speed rejected");
 [bad restore:@{@"meters":@(NAN),@"seconds":@(-1),@"maximum":@999}];expect(bad.meters==0&&bad.seconds==0&&bad.maximum==0,@"corrupt saved counters sanitized");
 TRDTrip *manual=[TRDTrip new];feed(manual,3000,20,5,13);feed(manual,3003,20,5,13.00054);[manual pause];
 feed(manual,3006,20,5,13.00108);feed(manual,3010,30,5,13.002);
 expect(manual.manuallyPaused&&!manual.running&&manual.meters==60&&manual.seconds==3,@"manual pause ignores movement indefinitely");
 TRDTrip *reload=[TRDTrip new];[reload restore:[manual summary]];feed(reload,4000,20,5,13);expect(reload.manuallyPaused&&!reload.running&&reload.meters==60,@"manual pause survives app restart");
 [reload start];feed(reload,4003,20,5,13.00054);feed(reload,4006,20,5,13.00108);expect(!reload.manuallyPaused&&reload.meters==120&&reload.seconds==6,@"START resumes cumulative tracking without bridging the pause");
 [reload start];feed(reload,4009,20,5,13.00162);expect(reload.meters==180&&reload.seconds==9,@"repeated START does not break an active segment");
 NSDictionary *legacy=@{@"meters":@100,@"seconds":@10,@"maximum":@36};[reload restore:legacy];feed(reload,5000,10,5,13);feed(reload,5002,10,5,13.00018);expect(!reload.manuallyPaused&&reload.meters==120,@"legacy summaries remain automatic");
 NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"passed":@YES,@"synthetic":@YES,@"movingMeters":@(restored.meters),@"movingSeconds":@(restored.seconds)} options:0 error:nil];puts([[NSString alloc]initWithData:data encoding:4].UTF8String);return 0;
}}
