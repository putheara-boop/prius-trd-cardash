#import <UIKit/UIKit.h>
#import "../TRDTrip.h"
@interface Harness:NSObject
@property TRDTrip *trip,*journey;
@property BOOL journeyActive;
@property UIView *tripSummaryCard;
@property int shown;
-(void)saveTrip;-(void)showTripSummary;-(void)hideTripSummary;-(void)restoreDisplayBrightness;-(void)showWelcome;
@end
@implementation Harness
-(void)saveTrip{NSUserDefaults *p=[NSUserDefaults standardUserDefaults];[p setObject:[self.journey summary] forKey:@"TRDJourneyCurrent"];[p setBool:self.journeyActive forKey:@"TRDJourneyActive"]; }
-(void)showTripSummary{self.shown++;}-(void)hideTripSummary{}-(void)restoreDisplayBrightness{}-(void)showWelcome{}
-(void)observeJourneyPower:(UIDeviceBatteryState)power{
 NSUserDefaults *p=[NSUserDefaults standardUserDefaults];
 static UIDeviceBatteryState prior=UIDeviceBatteryStateUnknown;
 BOOL charging=power==UIDeviceBatteryStateCharging||power==UIDeviceBatteryStateFull;
 if(charging&&prior==UIDeviceBatteryStateUnplugged){[self restoreDisplayBrightness];[self showWelcome];}
 if(power!=UIDeviceBatteryStateUnknown)prior=power;
 if(charging&&!self.journeyActive){
  self.journey=[TRDTrip new];self.journeyActive=YES;[self saveTrip];[p synchronize];
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
  if(self.tripSummaryCard){[self.tripSummaryCard removeFromSuperview];self.tripSummaryCard=nil;}
 }else if(power==UIDeviceBatteryStateUnplugged&&self.journeyActive){
  [self.journey breakSegment];[p setObject:[self.journey summary] forKey:@"TRDJourneyLast"];
  self.journeyActive=NO;[self saveTrip];[p synchronize];[self showTripSummary];
 }
}
@end
static void expect(BOOL x,const char *m){if(!x){fprintf(stderr,"FAIL %s\n",m);exit(1);}}
int main(){@autoreleasepool{NSUserDefaults *p=[NSUserDefaults standardUserDefaults];Harness *h=[Harness new];h.trip=[TRDTrip new];h.trip.meters=5000;h.journey=[TRDTrip new];[h observeJourneyPower:UIDeviceBatteryStateCharging];expect(h.journeyActive&&h.journey.meters==0,"start");h.journey.meters=1234;[h observeJourneyPower:UIDeviceBatteryStateFull];expect(h.journey.meters==1234,"duplicate charging");[h observeJourneyPower:UIDeviceBatteryStateUnplugged];expect(!h.journeyActive&&h.shown==1&&[[[p dictionaryForKey:@"TRDJourneyLast"]objectForKey:@"meters"]doubleValue]==1234,"finish");[h observeJourneyPower:UIDeviceBatteryStateUnplugged];expect(h.shown==1,"duplicate unplug");expect(h.trip.meters==5000,"cumulative preserved");[h observeJourneyPower:UIDeviceBatteryStateCharging];expect(h.journeyActive&&h.journey.meters==0,"next journey");puts("journey power tests passed");}}
