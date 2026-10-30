dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", 2);
var manager=[BluetoothManager sharedInstance];
var fs=[NSFileManager defaultManager];
var targetName="CAR MULTIMEDIA";
var success=false;
for(var attempt=0;attempt<6;attempt++){
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
 if(![fs fileExistsAtPath:@"/var/mobile/codex-car/power-connected"]){puts("cancelled: external power removed");break;}
 if(![manager enabled]){puts("waiting for Bluetooth");[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4]];continue;}
 var devices=[manager pairedDevices];
 var target=null;
 for(var i=0;i<[devices count];i++){
  var d=[devices objectAtIndex:i];
  var name=String([d name]||"");
  if(name.toLowerCase().trim()===targetName.toLowerCase().trim() || name.toLowerCase().indexOf("car multimedia")!==-1 || name.toLowerCase().indexOf("car")!==-1){
   target=d;
   break;
  }
 }
 if(!target){puts("CAR MULTIMEDIA is not paired");break;}
 if([target connected]){success=true;break;}
 puts("CAR MULTIMEDIA connect attempt "+(attempt+1));
 [target connect];
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4]];
 if([target connected]){success=true;break;}
}
puts(success?"CAR MULTIMEDIA connected":"CAR MULTIMEDIA not connected; retry ends");
