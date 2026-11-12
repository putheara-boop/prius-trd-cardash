#import "TRDWelcomeGate.h"
-(TRDSettingsMenu *)settingsMenu:(NSString *)title message:(NSString *)message{TRDSettingsMenu *m=[TRDSettingsMenu alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];return m;}
-(void)presentSettingsMenu:(TRDSettingsMenu *)m{[self.settingsSheet dismiss];self.settingsSheet=m;m.frame=self.view.bounds;__weak Dashboard *weak=self;m.miniPlayer=self.miniPlayer;self.miniPlayer.hidden=NO;[m.panel addSubview:self.miniPlayer];m.onDismiss=^{Dashboard *v=weak;v.settingsSheet=nil;v.miniPlayer.hidden=YES;[v.view addSubview:v.miniPlayer];[v.view setNeedsLayout];};[self.view addSubview:m];[self refreshMini];[m setNeedsLayout];}
-(void)carSettings{NSArray *modes=@[@"Auto: day 06:00-18:00",@"Day: manual",@"Night: manual"];TRDSettingsMenu *m=[self settingsMenu:@"CAR SETTINGS" message:modes[self.displayMode]];NSInteger voiceLang=[[NSUserDefaults standardUserDefaults] integerForKey:@"TRDVoiceLanguage"];NSString *voiceTitle=voiceLang==1?@"Greeting voice: ภาษาไทย":(voiceLang==2?@"Greeting voice: Muted (Off)":@"Greeting voice: English (US)");[m addAction:[TRDSettingAction actionWithTitle:voiceTitle style:0 handler:^(TRDSettingAction *a){[self voiceLanguageSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"⛽ Fuel & OBD2: %.2f ฿/L",[TRDOBDClient sharedClient].fuelPricePerLiter] style:0 handler:^(TRDSettingAction *a){[self openFuelPriceSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"🛡️ Brake & ABS Diagnostics" style:0 handler:^(TRDSettingAction *a){[self openBrakeDiagnosticsMenu];}]];[m addAction:[TRDSettingAction actionWithTitle:@"🔋 Hybrid Battery & Motor Telemetry" style:0 handler:^(TRDSettingAction *a){[self openHybridDiagnosticsMenu];}]];[m addAction:[TRDSettingAction actionWithTitle:@"🚗 Test Reverse Camera & Beep" style:0 handler:^(TRDSettingAction *a){[[TRDOBDClient sharedClient] toggleTestReverseGear];}]];
 NSUserDefaults *pSet=[NSUserDefaults standardUserDefaults];double totalKm=[pSet doubleForKey:@"TRDTotalOdometer"];double lastService=[pSet doubleForKey:@"TRDLastServiceKm"];double interval=[pSet doubleForKey:@"TRDServiceInterval"]?:10000.0;double remaining=interval-(totalKm-lastService);NSString *serviceTitle=[NSString stringWithFormat:@"🔧 Service: %.0f/%.0f km (%@)",totalKm-lastService,interval,remaining<=0?@"DUE NOW":[NSString stringWithFormat:@"%.0f km left",remaining]];[m addAction:[TRDSettingAction actionWithTitle:serviceTitle style:0 handler:^(TRDSettingAction *a){[self serviceSettings];}]];NSString *wTitle=self.currentTemperature>0?[NSString stringWithFormat:@"🌧️ Weather: %.0f°C (%@)",self.currentTemperature,self.rainDetected?@"Rain Alert":@"Clear"]:@"🌧️ Weather & Road";[m addAction:[TRDSettingAction actionWithTitle:wTitle style:0 handler:^(TRDSettingAction *a){[self weatherSettings];}]];
 [m addAction:[TRDSettingAction actionWithTitle:@"⛽ Find Gas Station (ปั๊มน้ำมันใกล้ฉัน)" style:0 handler:^(TRDSettingAction *a){[self navigateToNearestGasStation];}]];
 [m addAction:[TRDSettingAction actionWithTitle:@"☕ Find Rest Area / Coffee (จุดพักรถ)" style:0 handler:^(TRDSettingAction *a){[self navigateToNearestRestArea];}]];
 BOOL camRadar=[pSet objectForKey:@"TRDSpeedCameraAlerts"]?[pSet boolForKey:@"TRDSpeedCameraAlerts"]:YES;
 [m addAction:[TRDSettingAction actionWithTitle:camRadar?@"📷 Speed Camera Radar: ON":@"📷 Speed Camera Radar: OFF" style:0 handler:^(TRDSettingAction *a){
  [pSet setBool:!camRadar forKey:@"TRDSpeedCameraAlerts"];
  [pSet synchronize];
  [self carSettings];
 }]];
 BOOL batGuard=[pSet objectForKey:@"TRDBatteryHealthGuard"]?[pSet boolForKey:@"TRDBatteryHealthGuard"]:YES;
 [m addAction:[TRDSettingAction actionWithTitle:batGuard?@"🔋 Battery Health Guard (80%): ON":@"🔋 Battery Health Guard (80%): OFF" style:0 handler:^(TRDSettingAction *a){
  [pSet setBool:!batGuard forKey:@"TRDBatteryHealthGuard"];
  [pSet synchronize];
  [self carSettings];
 }]];
 [m addAction:[TRDSettingAction actionWithTitle:@"❤️ Speed Dial / ICE Contact" style:0 handler:^(TRDSettingAction *a){[self openSpeedDial];}]];BOOL hotCar=[pSet objectForKey:@"TRDHotCarSaver"]?[pSet boolForKey:@"TRDHotCarSaver"]:YES;[m addAction:[TRDSettingAction actionWithTitle:hotCar?@"☀️ Hot Car Protector: ON":@"☀️ Hot Car Protector: OFF" style:0 handler:^(TRDSettingAction *a){[pSet setBool:!hotCar forKey:@"TRDHotCarSaver"];[pSet synchronize];self.hotCarSaverEnabled=!hotCar;[self carSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Wi-Fi network" style:0 handler:^(TRDSettingAction *a){[self wifiSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Audio output" style:0 handler:^(TRDSettingAction *a){[self audioOutputSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Day / Night" style:0 handler:^(TRDSettingAction *a){[self displaySettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Accent theme" style:0 handler:^(TRDSettingAction *a){[self themeSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Sound profiles by app" style:0 handler:^(TRDSettingAction *a){[self soundProfileSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:TRDAutoEnabled()?@"Autoplay on car Bluetooth: ON":@"Autoplay on car Bluetooth: OFF" style:0 handler:^(TRDSettingAction *a){NSFileManager *fm=[NSFileManager defaultManager];NSString *path=TRDAutoFile(@"autoplay-disabled");if([fm fileExistsAtPath:path])[fm removeItemAtPath:path error:nil];else [@"off"writeToFile:path atomically:YES encoding:4 error:nil];[fm removeItemAtPath:TRDAutoFile(@"autoplay.plist") error:nil];[self carSettings];}]];

 [m addAction:[TRDSettingAction actionWithTitle:[TRDAutoSettings()[@"offlineOnly"]boolValue]?@"Autoplay downloaded only: ON":@"Autoplay downloaded only: OFF" style:0 handler:^(TRDSettingAction *a){NSMutableDictionary *cfg=[TRDAutoSettings()mutableCopy];cfg[@"offlineOnly"]=@(![cfg[@"offlineOnly"]boolValue]);[cfg writeToFile:TRDAutoFile(@"autoplay-settings.plist") atomically:YES];[self carSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:self.calmDrive?@"Wheel animation: OFF":@"Wheel animation: ON" style:0 handler:^(TRDSettingAction *a){[self toggleCalmDrive];[self carSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Screen off - keep audio" style:0 handler:^(TRDSettingAction *a){[self screenOff];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Preview Welcome" style:0 handler:^(TRDSettingAction *a){[self previewWelcome];}]];[m addAction:[TRDSettingAction actionWithTitle:@"iPad Settings" style:0 handler:^(TRDSettingAction *a){[self send:@"com.apple.Preferences"];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Trip / GPS" style:0 handler:^(TRDSettingAction *a){[self openTrip];}]];[m addAction:[TRDSettingAction actionWithTitle:@"GPS status / Restart" style:0 handler:^(TRDSettingAction *a){[self gpsSettings];}]];[self presentSettingsMenu:m];}
-(void)serviceSettings{
 NSUserDefaults *p=[NSUserDefaults standardUserDefaults];double totalKm=[p doubleForKey:@"TRDTotalOdometer"];double lastService=[p doubleForKey:@"TRDLastServiceKm"];double interval=[p doubleForKey:@"TRDServiceInterval"]?:10000.0;double distanceDriven=totalKm-lastService;double remaining=interval-distanceDriven;NSString *msg=[NSString stringWithFormat:@"Odometer: %.1f km\nSince last service: %.1f km\nRemaining: %.1f km\nInterval: %.0f km",totalKm,distanceDriven,remaining,interval];TRDSettingsMenu *m=[self settingsMenu:@"OIL & SERVICE TRACKER" message:msg];[m addAction:[TRDSettingAction actionWithTitle:@"🔄 Record Oil Change (Reset)" style:0 handler:^(TRDSettingAction *a){[p setDouble:totalKm forKey:@"TRDLastServiceKm"];[p synchronize];[self carSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Set Interval: 10,000 km (Standard)" style:0 handler:^(TRDSettingAction *a){[p setDouble:10000.0 forKey:@"TRDServiceInterval"];[p synchronize];[self serviceSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Set Interval: 7,500 km" style:0 handler:^(TRDSettingAction *a){[p setDouble:7500.0 forKey:@"TRDServiceInterval"];[p synchronize];[self serviceSettings];}]];[m addAction:[TRDSettingAction actionWithTitle:@"Set Interval: 5,000 km (Heavy duty)" style:0 handler:^(TRDSettingAction *a){[p setDouble:5000.0 forKey:@"TRDServiceInterval"];[p synchronize];[self serviceSettings];}]];[self presentSettingsMenu:m];}
-(void)weatherSettings{
 NSString *rainStr=self.rainDetected?@"Rain / Wet road detected 🌧️":@"No rain / Dry road ☀️";NSString *msg=[NSString stringWithFormat:@"Temperature: %.1f °C\nRain rate: %.2f mm/h\nStatus: %@\nCode: %ld",self.currentTemperature,self.currentRainMm,rainStr,(long)self.currentWeatherCode];TRDSettingsMenu *m=[self settingsMenu:@"WEATHER & ROAD" message:msg];[m addAction:[TRDSettingAction actionWithTitle:@"🔄 Refresh weather now" style:0 handler:^(TRDSettingAction *a){if(self.fix)[self fetchWeatherForCoordinate:self.fix.coordinate];[self carSettings];}]];[self presentSettingsMenu:m];}
-(void)voiceLanguageSettings{TRDSettingsMenu *m=[self settingsMenu:@"GREETING VOICE" message:@"Choose startup & trip end voice greeting language."];NSInteger cur=[[NSUserDefaults standardUserDefaults] integerForKey:@"TRDVoiceLanguage"];NSArray *names=@[@"English (Samantha Enhanced)",@"ภาษาไทย (Thai Kanya)",@"Muted (Off)"];for(NSInteger i=0;i<3;i++){NSString *title=[NSString stringWithFormat:@"%@%@",i==cur?@"✓  ":@"",names[i]];[m addAction:[TRDSettingAction actionWithTitle:title style:0 handler:^(TRDSettingAction *a){[[NSUserDefaults standardUserDefaults] setInteger:i forKey:@"TRDVoiceLanguage"];[[NSUserDefaults standardUserDefaults] synchronize];[self previewWelcome];}]];}[self presentSettingsMenu:m];}
-(void)displaySettings{TRDSettingsMenu *m=[self settingsMenu:@"DAY / NIGHT" message:@"Auto follows the iPad's local time. Manual stays until changed."];NSArray *names=@[@"Auto (06:00-18:00 day)",@"Day",@"Night"];for(NSInteger i=0;i<3;i++)[m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"%@%@",i==self.displayMode?@"✓  ":@"",names[i]] style:0 handler:^(TRDSettingAction *a){[self setDisplayModeNumber:@(i)];}]];[self presentSettingsMenu:m];}
-(void)setDisplayModeNumber:(NSNumber *)number{self.displayMode=MAX(0,MIN(2,number.integerValue));[[NSUserDefaults standardUserDefaults]setInteger:self.displayMode forKey:@"TRDDisplayMode"];[[NSUserDefaults standardUserDefaults]synchronize];[self applyDisplaySchedule];}
-(void)applyDisplaySchedule{NSInteger hour=[[NSCalendar currentCalendar]component:NSCalendarUnitHour fromDate:[NSDate date]];[self applyHour:@(hour)];}
-(void)applyHour:(NSNumber *)hour{BOOL night=self.displayMode==2||(self.displayMode==0&&TRDNightHour(hour.integerValue));if(night!=self.nightMode)[self toggleNight];[self restoreDisplayBrightness];[self.nightButton setTitle:self.displayMode==0?(night?@"AUTO / NIGHT":@"AUTO / DAY"):(night?@"NIGHT":@"DAY") forState:UIControlStateNormal];}
-(void)themeSettings{TRDSettingsMenu *m=[self settingsMenu:@"DRIVE MODE / THEME" message:@"Keep the TRD layout. Choose your drive profile."];NSArray *names=@[@"SPORT (TRD Red)",@"NORMAL (Ice Blue)",@"ECO (Prius Green)"];for(NSInteger i=0;i<3;i++)[m addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"%@%@",i==TRDTheme?@"✓  ":@"",names[i]] style:0 handler:^(TRDSettingAction *a){[self setThemeNumber:@(i)];}]];[self presentSettingsMenu:m];}
-(void)setThemeNumber:(NSNumber *)number{TRDTheme=MAX(0,MIN(2,number.integerValue));[[NSUserDefaults standardUserDefaults]setInteger:TRDTheme forKey:@"TRDTheme"];[[NSUserDefaults standardUserDefaults]synchronize];[self applyTheme];}
-(void)redrawIcons:(UIView *)view{if([view isKindOfClass:[DashIcon class]])[view setNeedsDisplay];for(UIView *v in view.subviews)[self redrawIcons:v];}
-(void)applyTheme{TRDLowLight=self.nightMode;UIColor *c=TRDAccent();NSString *mode=TRDDriveModeName(TRDTheme);self.heading.text=[NSString stringWithFormat:@"PRIUS  TRD  /  %@",mode];[self.modeButton setTitle:[NSString stringWithFormat:@"[ %@ ]",mode] forState:UIControlStateNormal];[self.modeButton setTitleColor:c forState:UIControlStateNormal];self.modeButton.layer.borderColor=c.CGColor;self.modeButton.backgroundColor=[c colorWithAlphaComponent:.12];self.driveCameraButton.backgroundColor=[c colorWithAlphaComponent:.20];self.driveCameraButton.layer.borderColor=[c colorWithAlphaComponent:.8].CGColor;self.clock.textColor=[UIColor colorWithWhite:self.nightMode?.78:1 alpha:1];self.speed.textColor=self.clock.textColor;self.song.textColor=self.nightMode?[UIColor colorWithRed:.78 green:.64 blue:.38 alpha:1]:[UIColor colorWithRed:1 green:.78 blue:.42 alpha:1];self.heading.textColor=c;self.musicHeading.textColor=c;self.unit.textColor=c;self.artPlaceholder.textColor=c;self.trackProgress.progressTintColor=c;self.progress.strokeColor=c.CGColor;[self.nightButton setTitleColor:c forState:0];self.nightButton.layer.borderColor=c.CGColor;self.nightButton.backgroundColor=[c colorWithAlphaComponent:.10];[self.driveEQ setTitleColor:c forState:0];self.driveEQ.layer.borderColor=[c colorWithAlphaComponent:.4].CGColor;self.driveEQ.backgroundColor=[c colorWithAlphaComponent:.10];self.sourceBadge.backgroundColor=[c colorWithAlphaComponent:.28];self.sourceBadge.layer.borderColor=[c colorWithAlphaComponent:.65].CGColor;for(UIButton *b in self.cards){[b viewWithTag:102].backgroundColor=c;b.layer.borderColor=[c colorWithAlphaComponent:.3].CGColor;((UILabel *)[b viewWithTag:100]).textColor=b.tag==1?c:[UIColor whiteColor];}for(UIButton *b in self.controls.subviews){b.backgroundColor=[c colorWithAlphaComponent:.10];b.layer.borderColor=[c colorWithAlphaComponent:.35].CGColor;[b setTitleColor:c forState:0];}[self.radioButton setTitleColor:c forState:0];self.radioButton.layer.borderColor=[c colorWithAlphaComponent:.4].CGColor;self.driveLeftCard.layer.borderColor=[c colorWithAlphaComponent:.35].CGColor;self.driveRightCard.layer.borderColor=[c colorWithAlphaComponent:.35].CGColor;[self.panel setNeedsDisplay];[self.audioBars setNeedsDisplay];[self redrawIcons:self.view];[self refreshClockHud];[self.view setNeedsLayout];}
-(void)screenOff{
 [UIApplication sharedApplication].idleTimerDisabled=NO;
 [UIScreen mainScreen].brightness=0.0;
 [self.gps stopUpdatingLocation];
 [self.audioBars stop];
 [self.driveCar stop];
 [self.timer invalidate];
 self.timer=nil;
 [self saveTrip];
 notify_post("com.codex.trd.sleep");
}
static AVSpeechSynthesizer *gTRDWelcomeSynth;
static NSTimer *gTRDWelcomeBTTimer;
static NSDate *gTRDWelcomeWaitStart;
static BOOL gTRDWelcomeSpoken;

-(BOOL)isCarBluetoothReady{
 AVAudioSession *session=[AVAudioSession sharedInstance];
 for(AVAudioSessionPortDescription *port in session.currentRoute.outputs){
  NSString *type=port.portType;
  if([type isEqual:AVAudioSessionPortBluetoothA2DP]||[type isEqual:AVAudioSessionPortBluetoothHFP]||[type isEqual:AVAudioSessionPortBluetoothLE]){
   return YES;
  }
 }
 return NO;
}

static void TRDEnqueueCalmSpeech(AVSpeechSynthesizer *synth, NSArray *sentences, NSString *langCode, float rate) {
 AVSpeechSynthesisVoice *v=[AVSpeechSynthesisVoice voiceWithLanguage:langCode];
 for(NSUInteger i=0;i<sentences.count;i++){
  NSString *s=sentences[i];
  if(!s.length)continue;
  AVSpeechUtterance *utt=[AVSpeechUtterance speechUtteranceWithString:s];
  if(v)utt.voice=v;
  utt.rate=rate;
  utt.pitchMultiplier=1.0f;
  utt.preUtteranceDelay=(i==0)?0.20f:0.0f;
  utt.postUtteranceDelay=(i+1<sentences.count)?0.32f:0.10f;
  utt.volume=1.0f;
  [synth speakUtterance:utt];
 }
}

-(void)speakWelcomeMessage{
 dispatch_async(dispatch_get_main_queue(), ^{
  if(gTRDWelcomeSpoken) return;
  gTRDWelcomeSpoken=YES;
  if(gTRDWelcomeBTTimer){
   [gTRDWelcomeBTTimer invalidate];
   gTRDWelcomeBTTimer=nil;
  }
  NSInteger voiceLang=[[NSUserDefaults standardUserDefaults] integerForKey:@"TRDVoiceLanguage"];
  if(voiceLang==2){
   if(self.welcome){
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideWelcome) object:nil];
    [self performSelector:@selector(hideWelcome) withObject:nil afterDelay:3.2];
   }
   return;
  }
  @try {
   AVAudioSession *session=[AVAudioSession sharedInstance];
   [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
   [session setActive:YES error:nil];
   if(!gTRDWelcomeSynth) gTRDWelcomeSynth=[[AVSpeechSynthesizer alloc]init];
   if([gTRDWelcomeSynth isSpeaking]){
    [gTRDWelcomeSynth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
   }
   NSInteger hour=[[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:[NSDate date]];
   NSString *langCode;
   float rate;
   NSMutableArray *sentences=[NSMutableArray array];

   NSUserDefaults *pW=[NSUserDefaults standardUserDefaults];
   double totalKm=[pW doubleForKey:@"TRDTotalOdometer"];
   double lastService=[pW doubleForKey:@"TRDLastServiceKm"];
   double serviceInterval=[pW doubleForKey:@"TRDServiceInterval"]?:10000.0;
   double dueIn=serviceInterval-(totalKm-lastService);
   BOOL serviceWarning=(dueIn<=500.0 && totalKm>0);
   BOOL rain=self.rainDetected;

   if(voiceLang==1){ // Thai
    langCode=@"th-TH";
    rate=0.03f;
    if(hour>=5 && hour<12){
     [sentences addObject:@"อรุณสวัสดิ์ครับคุณพีพุท"];
     [sentences addObject:@"ระบบพร้อมใช้งาน"];
     [sentences addObject:@"ขอให้เป็นวันที่ดี และเดินทางปลอดภัยนะครับ"];
    }else if(hour>=12 && hour<18){
     [sentences addObject:@"สวัสดีตอนบ่ายครับคุณพีพุท"];
     [sentences addObject:@"ระบบพร้อมใช้งาน"];
     [sentences addObject:@"ขอให้ขับรถอย่างมีความสุข และเดินทางปลอดภัยนะครับ"];
    }else{
     [sentences addObject:@"สวัสดีตอนค่ำครับคุณพีพุท"];
     [sentences addObject:@"ระบบพร้อมใช้งาน"];
     [sentences addObject:@"ขอให้เดินทางปลอดภัยในค่ำคืนนี้นะครับ"];
    }
    if(rain){
     [sentences addObject:@"วันนี้มีรายงานฝนตกในพื้นที่ โปรดขับขี่ด้วยความระมัดระวังนะครับ"];
    }else if(serviceWarning){
     [sentences addObject:@"แจ้งเตือน ใกล้ถึงระยะเปลี่ยนถ่ายน้ำมันเครื่องแล้วครับ"];
    }
   }else{ // English default
    langCode=@"en-US";
    rate=0.02f;
    if(hour>=5 && hour<12){
     [sentences addObject:@"Good morning, PeePut."];
     [sentences addObject:@"System is ready."];
     [sentences addObject:@"Have a productive day, and travel safely."];
    }else if(hour>=12 && hour<18){
     [sentences addObject:@"Good afternoon, PeePut."];
     [sentences addObject:@"System is ready."];
     [sentences addObject:@"Enjoy your drive, and travel safely."];
    }else{
     [sentences addObject:@"Good evening, PeePut."];
     [sentences addObject:@"System is ready."];
     [sentences addObject:@"Enjoy your drive, and travel safely tonight."];
    }
    if(rain){
     [sentences addObject:@"Rain is reported in your area. Drive carefully on wet roads."];
    }else if(serviceWarning){
     [sentences addObject:@"Maintenance reminder. Engine oil service is due soon."];
    }
   }
   TRDEnqueueCalmSpeech(gTRDWelcomeSynth, sentences, langCode, rate);
  } @catch(NSException *e){}
  if(self.welcome){
   [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideWelcome) object:nil];
   [self performSelector:@selector(hideWelcome) withObject:nil afterDelay:9.5];
  }
 });
}

-(void)speakGoodbyeMessage{
 dispatch_async(dispatch_get_main_queue(), ^{
  NSInteger voiceLang=[[NSUserDefaults standardUserDefaults] integerForKey:@"TRDVoiceLanguage"];
  if(voiceLang==2) return;
  @try {
   AVAudioSession *session=[AVAudioSession sharedInstance];
   [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
   [session setActive:YES error:nil];
   if(!gTRDWelcomeSynth) gTRDWelcomeSynth=[[AVSpeechSynthesizer alloc]init];
   if([gTRDWelcomeSynth isSpeaking]){
    [gTRDWelcomeSynth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
   }
   NSString *langCode;
   float rate;
   NSMutableArray *sentences=[NSMutableArray array];
   NSInteger eco = self.ecoScore > 0 ? self.ecoScore : 95;
   if(voiceLang==1){
    langCode=@"th-TH";
    rate=0.03f;
    [sentences addObject:@"สิ้นสุดการเดินทาง"];
    [sentences addObject:[NSString stringWithFormat:@"คะแนนขับขี่ประหยัดพลังงาน %ld เต็ม 100", (long)eco]];
    if(eco >= 85){
     [sentences addObject:@"ขับขี่ได้นุ่มนวลยอดเยี่ยมมากครับคุณพีพุท"];
    }else{
     [sentences addObject:@"ขอบคุณครับคุณพีพุท ขอให้เป็นวันที่ดีนะครับ"];
    }
   }else{
    langCode=@"en-US";
    rate=0.02f;
    [sentences addObject:@"Trip completed."];
    [sentences addObject:[NSString stringWithFormat:@"Your eco drive score is %ld out of 100.", (long)eco]];
    if(eco >= 85){
     [sentences addObject:@"Excellent and smooth driving, PeePut."];
    }else{
     [sentences addObject:@"Goodbye, PeePut. Have a nice day."];
    }
   }
   TRDEnqueueCalmSpeech(gTRDWelcomeSynth, sentences, langCode, rate);
  } @catch(NSException *e){}
 });
}

-(void)checkWelcomeBluetoothReady{
 if(!self.welcome || gTRDWelcomeSpoken){
  [gTRDWelcomeBTTimer invalidate];
  gTRDWelcomeBTTimer=nil;
  return;
 }
 BOOL btReady=[self isCarBluetoothReady];
 NSTimeInterval elapsed=gTRDWelcomeWaitStart?[[NSDate date] timeIntervalSinceDate:gTRDWelcomeWaitStart]:0;
 NSInteger voiceLang=[[NSUserDefaults standardUserDefaults] integerForKey:@"TRDVoiceLanguage"];
 if(btReady){
  [gTRDWelcomeBTTimer invalidate];
  gTRDWelcomeBTTimer=nil;
  if(self.welcome.tagline){
   if(voiceLang==1){
    self.welcome.tagline.text=@"เชื่อมต่อ PRIUS AUDIO สำเร็จ  •  ระบบพร้อม";
    self.welcome.tagline.font=[UIFont systemFontOfSize:15];
   }else{
    self.welcome.tagline.attributedText=[[NSAttributedString alloc]initWithString:@"CONNECTED TO PRIUS  •  SYSTEM READY" attributes:@{NSKernAttributeName:@2.5}];
    self.welcome.tagline.font=[UIFont systemFontOfSize:13];
   }
  }
  [self performSelector:@selector(speakWelcomeMessage) withObject:nil afterDelay:0.35];
 }else if(elapsed>=5.0){
  [gTRDWelcomeBTTimer invalidate];
  gTRDWelcomeBTTimer=nil;
  if(self.welcome.tagline){
   if(voiceLang==1){
    self.welcome.tagline.text=@"ยินดีต้อนรับ... ขอให้ขับรถอย่างสนุก... และเดินทางปลอดภัยนะครับ";
    self.welcome.tagline.font=[UIFont systemFontOfSize:15];
   }else{
    self.welcome.tagline.attributedText=[[NSAttributedString alloc]initWithString:@"SYSTEM READY  •  HAVE A SAFE DRIVE" attributes:@{NSKernAttributeName:@2.5}];
    self.welcome.tagline.font=[UIFont systemFontOfSize:13];
   }
  }
  [self speakWelcomeMessage];
 }
}

-(void)showAutomaticWelcome{
 NSUserDefaults *p=[NSUserDefaults standardUserDefaults];
 NSMutableDictionary *state=[[p dictionaryForKey:@"TRDWelcomePowerState"]mutableCopy]?:[NSMutableDictionary dictionary];
 if(!TRDWelcomeTake(state))return;
 [p setObject:state forKey:@"TRDWelcomePowerState"];
 [p synchronize];
 [self showWelcome];
}

-(void)showWelcomeWaitingForCar:(BOOL)waitForCar{
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTripSummary) object:nil];
 if(self.tripSummaryCard){
  [self.tripSummaryCard removeFromSuperview];
  self.tripSummaryCard=nil;
 }
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideWelcome) object:nil];
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(speakWelcomeMessage) object:nil];
 if(gTRDWelcomeBTTimer){
  [gTRDWelcomeBTTimer invalidate];
  gTRDWelcomeBTTimer=nil;
 }
 [self.welcome removeFromSuperview];
 self.welcome=[CarWelcome new];
 self.welcome.frame=self.view.bounds;
 self.welcome.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
 [self.welcome addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(hideWelcome)]];
 [self.view addSubview:self.welcome];
 [self.view bringSubviewToFront:self.welcome];
 CarWelcome *welcome=self.welcome;
 welcome.alpha=0;
 welcome.name.alpha=0;
 welcome.tagline.alpha=0;
 [UIView animateWithDuration:.45 animations:^{welcome.alpha=1;}];
 [UIView animateWithDuration:.45 delay:.15 options:UIViewAnimationOptionCurveEaseOut animations:^{welcome.name.alpha=1;welcome.tagline.alpha=1;} completion:nil];
 
 gTRDWelcomeSpoken=NO;
 gTRDWelcomeWaitStart=[NSDate date];
 NSInteger voiceLang=[[NSUserDefaults standardUserDefaults] integerForKey:@"TRDVoiceLanguage"];
 
 if([self isCarBluetoothReady] || !waitForCar){
  if([self isCarBluetoothReady]){
   if(voiceLang==1){
    welcome.tagline.text=@"เชื่อมต่อ PRIUS AUDIO สำเร็จ  •  ระบบไฮบริดพร้อม";
    welcome.tagline.font=[UIFont systemFontOfSize:15];
   }else{
    welcome.tagline.attributedText=[[NSAttributedString alloc]initWithString:@"CONNECTED TO PRIUS  •  SYSTEM READY" attributes:@{NSKernAttributeName:@2.5}];
    welcome.tagline.font=[UIFont systemFontOfSize:13];
   }
  }else{
   if(voiceLang==1){
    welcome.tagline.text=@"ยินดีต้อนรับครับ พี่พุธ • ขอให้ขับรถอย่างสนุก และเดินทางปลอดภัยครับ";
    welcome.tagline.font=[UIFont systemFontOfSize:15];
   }else{
    welcome.tagline.attributedText=[[NSAttributedString alloc]initWithString:@"SYSTEM READY  •  HAVE A SAFE DRIVE" attributes:@{NSKernAttributeName:@2.5}];
    welcome.tagline.font=[UIFont systemFontOfSize:13];
   }
  }
  [self performSelector:@selector(speakWelcomeMessage) withObject:nil afterDelay:0.4];
  [self performSelector:@selector(hideWelcome) withObject:nil afterDelay:5.5];
 }else{
  if(voiceLang==1){
   welcome.tagline.text=@"กำลังเชื่อมต่อ PRIUS AUDIO...";
   welcome.tagline.font=[UIFont systemFontOfSize:15];
  }else{
   welcome.tagline.attributedText=[[NSAttributedString alloc]initWithString:@"CONNECTING TO PRIUS AUDIO..." attributes:@{NSKernAttributeName:@2.0}];
   welcome.tagline.font=[UIFont systemFontOfSize:13];
  }
  [self performSelector:@selector(hideWelcome) withObject:nil afterDelay:8.0];
  gTRDWelcomeBTTimer=[NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(checkWelcomeBluetoothReady) userInfo:nil repeats:YES];
 }
}

-(void)showWelcome{
 [self showWelcomeWaitingForCar:YES];
}

-(void)previewWelcome{
 [self showWelcomeWaitingForCar:NO];
}

-(void)hideWelcome{
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideWelcome) object:nil];
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(speakWelcomeMessage) object:nil];
 if(gTRDWelcomeBTTimer){
  [gTRDWelcomeBTTimer invalidate];
  gTRDWelcomeBTTimer=nil;
 }
 if(!self.welcome) return;
 CarWelcome *view=self.welcome;
 self.welcome=nil;
 [UIView animateWithDuration:.25 animations:^{view.alpha=0;} completion:^(BOOL done){
  [view removeFromSuperview];
  [self.view setNeedsLayout];
 }];
}
-(void)previewWelcomeCapture{[self showWelcome];[self.welcome layoutIfNeeded];[self capture];}
-(void)soundProfileSettings{NSMutableDictionary *cfg=[[NSDictionary dictionaryWithContentsOfFile:TRDProfilesPath]mutableCopy];BOOL enabled=[cfg[@"enabled"]boolValue];TRDSettingsMenu *m=[self settingsMenu:@"SOUND PROFILES" message:@"Presets follow the app playing audio. Choosing a preset in EQE also remembers it for that app."];[m addAction:[TRDSettingAction actionWithTitle:enabled?@"Automatic sound: ON (tap to turn off)":@"Automatic sound: OFF (tap to turn on)" style:0 handler:^(TRDSettingAction *a){NSMutableDictionary *next=[[NSDictionary dictionaryWithContentsOfFile:TRDProfilesPath]mutableCopy];next[@"enabled"]=@(!enabled);[next writeToFile:TRDProfilesPath atomically:YES];TRDProfileChanged();}]];NSArray *names=@[@"Music / audioNINJA",@"YouTube"],*ids=@[@"com.legacymusic.app",@"com.himais0giiiin.ytnine"];for(NSInteger i=0;i<names.count;i++){NSString *bundle=ids[i],*label=names[i];NSString *title=[NSString stringWithFormat:@"%@: %@",label,cfg[@"profiles"][bundle]?:@"Flat"];[m addAction:[TRDSettingAction actionWithTitle:title style:0 handler:^(TRDSettingAction *a){[self chooseProfile:bundle title:label];}]];}[self presentSettingsMenu:m];}
-(void)chooseProfile:(NSString *)bundle title:(NSString *)title{TRDSettingsMenu *m=[self settingsMenu:title message:@"Used automatically when this app becomes the audio source."];for(NSString *name in TRDProfileNames())[m addAction:[TRDSettingAction actionWithTitle:name style:0 handler:^(TRDSettingAction *a){NSMutableDictionary *cfg=[[NSDictionary dictionaryWithContentsOfFile:TRDProfilesPath]mutableCopy];NSMutableDictionary *profiles=[cfg[@"profiles"]mutableCopy];profiles[bundle]=name;cfg[@"profiles"]=profiles;[cfg writeToFile:TRDProfilesPath atomically:YES];TRDProfileChanged();}]];[self presentSettingsMenu:m];}

-(void)restoreDisplayBrightness{
 if([UIApplication sharedApplication].applicationState!=UIApplicationStateActive)return;
 [UIApplication sharedApplication].idleTimerDisabled=YES;
 CGFloat target=self.nightMode?.25:.85;
 [UIScreen mainScreen].brightness=target;
 if(!self.timer){
  self.timer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(update) userInfo:nil repeats:YES];
  self.timer.tolerance=.1;
 }
 [self startGPS];
}

-(void)openCamera{if(![self launchBundleApp:@"com.codex.h109viewer"]){[self launchBundleApp:@"com.apple.camera"];}}
-(void)toggleCalmDrive{self.calmDrive=!self.calmDrive;[[NSUserDefaults standardUserDefaults]setBool:self.calmDrive forKey:@"TRDCalmDrive"];[[NSUserDefaults standardUserDefaults]synchronize];[self applyMotionPolicy];[self refreshSpeed];[self.view setNeedsLayout];}
-(void)applyMotionPolicy{BOOL calm=self.driveMode&&self.calmDrive;self.audioBars.hidden=!self.musicMode;self.audioBars.multicolor=self.musicMode;if(!self.musicMode||[UIApplication sharedApplication].applicationState==UIApplicationStateBackground){if(self.audioBars.refreshTimer)[self.audioBars stop];}else [self.audioBars start];if(calm)[self.driveCar stop];}
-(void)refreshAudioRoute{
 AVAudioSession *session=[AVAudioSession sharedInstance];AVAudioSessionPortDescription *port=session.currentRoute.outputs.firstObject;NSString *type=port.portType,*name=port.portName;NSString *route=@"NO AUDIO OUTPUT",*shortName=@"NO OUTPUT";
 if([type isEqual:AVAudioSessionPortBuiltInSpeaker]){route=@"IPAD SPEAKER";shortName=@"SPEAKER";}
 else if([type isEqual:AVAudioSessionPortBluetoothA2DP]||[type isEqual:AVAudioSessionPortBluetoothHFP]||[type isEqual:AVAudioSessionPortBluetoothLE]){BOOL car=[name caseInsensitiveCompare:@"CAR MULTIMEDIA"]==NSOrderedSame&&name.length;route=car?@"CAR BLUETOOTH":@"BLUETOOTH AUDIO";shortName=car?@"CAR BT":@"BLUETOOTH";}
 else if([type isEqual:AVAudioSessionPortHeadphones]){route=@"HEADPHONES";shortName=route;}
 else if([type isEqual:AVAudioSessionPortLineOut]){route=@"AUX OUTPUT";shortName=@"AUX";}
 else if([type isEqual:AVAudioSessionPortUSBAudio]){route=@"USB AUDIO";shortName=@"USB";}
 else if([type isEqual:AVAudioSessionPortAirPlay]){route=@"AIRPLAY";shortName=route;}
 else if(type.length){route=@"EXTERNAL AUDIO";shortName=@"EXTERNAL";}
 self.audioOutput=route;self.audioOutputShort=shortName;self.audioDevice=name?:@"";self.outputVolume=isfinite(session.outputVolume)?MAX(0,MIN(1,session.outputVolume)):-1;
 NSString *level=self.outputVolume<0?@"VOLUME UNKNOWN":self.outputVolume<.005?@"MUTED":[NSString stringWithFormat:@"VOL %.0f%%",self.outputVolume*100];
 NSString *newCarStatus=(self.carplayMode||self.mapMode||self.tripMode)?[NSString stringWithFormat:@"%@  ·  %@",route,level]:(self.driveMode?@"🛡️ เบรก ECB ปกติ  •  🌡️ น้ำหล่อเย็น 88°C  •  ❄️ แอร์ 24.0°C":@"🚪 ประตู 5 บาน: ปิดสนิท  •  🔒 เข็มขัดนิรภัย: ล็อคครบทุกจุด");
 if(![self.carStatus.text isEqualToString:newCarStatus]){self.carStatus.text=newCarStatus;self.carStatus.accessibilityLabel=newCarStatus;}
 self.carStatus.textColor=[UIColor whiteColor];
}
-(void)audioOutputSettings{[self refreshAudioRoute];TRDSettingsMenu *m=[self settingsMenu:@"AUDIO OUTPUT" message:[NSString stringWithFormat:@"%@%@\nUse iPad volume buttons or your car stereo.",self.carStatus.text,([self.audioOutput isEqual:@"CAR BLUETOOTH"]||[self.audioOutput isEqual:@"BLUETOOTH AUDIO"]||[self.audioOutput isEqual:@"AIRPLAY"])&&self.audioDevice.length?[@" · "stringByAppendingString:self.audioDevice]:@""]];[m addAction:[TRDSettingAction actionWithTitle:@"Open iPad Settings" style:0 handler:^(TRDSettingAction *a){[self send:@"com.apple.Preferences"];}]];[self presentSettingsMenu:m];}
-(void)refreshStatusStrip{
 CLAuthorizationStatus auth=[CLLocationManager authorizationStatus];
 NSString *gps=(auth==kCLAuthorizationStatusDenied||auth==kCLAuthorizationStatusRestricted)?@"DISABLED":self.gpsLive?@"LIVE":self.hadGPSSpeed?@"LOST":@"NO FIX";
 NSArray *values=@[self.statusCar?:@"UNKNOWN",self.statusWiFi?:@"NO NETWORK",self.audioOutputShort?:@"NO OUTPUT",gps,self.statusPower?:@"UNKNOWN"];
 for(NSUInteger i=0;i<self.statusChips.count;i++){
  UILabel *label=(UILabel *)[self.statusChips[i]viewWithTag:302];
  UILabel *title=(UILabel *)[self.statusChips[i]viewWithTag:301];
  if(i==2){
   NSString *newAudioTitle=self.outputVolume<0?@"AUDIO":self.outputVolume<.005?@"AUDIO MUTED":[NSString stringWithFormat:@"AUDIO %.0f%%",self.outputVolume*100];
   if(![title.text isEqualToString:newAudioTitle])title.text=newAudioTitle;
  }
  NSString *value=values[i];
  if(i==0){
   if([value isEqual:@"DISCONNECTED"])value=@"NO LINK";
   else if([value isEqual:@"CONNECTED"])value=@"CONNECTED";
   else if([value isEqual:@"NOT PAIRED"])value=@"UNPAIRED";
  }
  if(![label.text isEqualToString:value])label.text=value;
  BOOL good=(i==0&&[values[i]isEqual:@"CONNECTED"])||(i==3&&self.gpsLive);
  label.textColor=good?[UIColor colorWithRed:.30 green:self.nightMode?.58:.8 blue:.48 alpha:1]:[UIColor colorWithWhite:self.nightMode?.58:.8 alpha:1];
  ((UIView *)self.statusChips[i]).accessibilityLabel=[NSString stringWithFormat:@"%@: %@",@[@"Car Bluetooth",@"Wi-Fi",@"Audio output",@"GPS",@"Power"][i],values[i]];
 }
}


-(void)captureLifecycle{[@{@"timerActive":@(self.timer!=nil),@"meterActive":@(self.audioBars.refreshTimer!=nil),@"wheelAnimating":@(self.driveCar.wheelTimer!=nil),@"driveMode":@(self.driveMode),@"musicMode":@(self.musicMode),@"state":@([UIApplication sharedApplication].applicationState),@"at":[NSDate date]}writeToFile:@"/var/mobile/h109-build/trd-background.plist" atomically:YES];}

-(void)gpsSettings{[self captureGPSState];NSString *message=[NSString stringWithFormat:@"Location %@ / permission %d / updates %lu\nAccuracy %.0f m / speed %.1f m/s\nLocation-only fixes do not provide driving speed.",[CLLocationManager locationServicesEnabled]?@"ON":@"OFF",[CLLocationManager authorizationStatus],(unsigned long)self.gpsUpdates,self.fix?self.fix.horizontalAccuracy:-1,self.fix?self.fix.speed:-1];TRDSettingsMenu *m=[self settingsMenu:@"GPS STATUS" message:message];[m addAction:[TRDSettingAction actionWithTitle:@"Restart GPS updates" style:0 handler:^(TRDSettingAction *a){[self restartGPS];}]];[self presentSettingsMenu:m];}
-(void)statusChipTapped:(UIButton *)b{NSInteger idx=b.tag-310;if(idx==0)[self carBtSettings];else if(idx==1)[self wifiSettings];else if(idx==2)[self audioOutputSettings];else if(idx==3)[self gpsSettings];else if(idx==4)[self powerSettings];}
-(void)carBtSettings{TRDSettingsMenu *m=[self settingsMenu:@"CAR BLUETOOTH" message:[NSString stringWithFormat:@"Status: %@\nTarget device: CAR MULTIMEDIA\nVehicle: Toyota Prius",self.statusCar?:@"UNKNOWN"]];[m addAction:[TRDSettingAction actionWithTitle:@"Open iPad Settings" style:0 handler:^(TRDSettingAction *a){[self send:@"com.apple.Preferences"];}]];[self presentSettingsMenu:m];}
-(void)wifiSettings{TRDSettingsMenu *m=[self settingsMenu:@"WI-FI NETWORK" message:[NSString stringWithFormat:@"Current SSID: %@\nConnected on iPad interface en0",self.statusWiFi?:@"NO NETWORK"]];[m addAction:[TRDSettingAction actionWithTitle:@"Open Wi-Fi Settings" style:0 handler:^(TRDSettingAction *a){[self send:@"com.apple.Preferences"];}]];[self presentSettingsMenu:m];}
-(void)powerSettings{TRDSettingsMenu *m=[self settingsMenu:@"POWER & DISPLAY" message:[NSString stringWithFormat:@"Battery / Charger: %@\nLighting: %@",self.statusPower?:@"UNKNOWN",self.nightMode?@"NIGHT":@"DAY"]];[m addAction:[TRDSettingAction actionWithTitle:@"Screen off - keep audio" style:0 handler:^(TRDSettingAction *a){[self screenOff];}]];[m addAction:[TRDSettingAction actionWithTitle:self.nightMode?@"Switch to Day mode":@"Switch to Night mode" style:0 handler:^(TRDSettingAction *a){[self setDisplayModeNumber:@(self.nightMode?1:2)];}]];[self presentSettingsMenu:m];}
