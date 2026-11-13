-(void)openTrip{[self.settingsSheet dismiss];[self teardownMapWebView];self.carplayMode=NO;self.carplayGridMode=NO;self.tripMode=YES;self.mapMode=NO;self.musicMode=NO;self.driveMode=NO;self.focused=NO;self.returnTap.enabled=NO;[self.driveCar stop];[self.driveButton setTitle:@"DRIVE MODE" forState:0];[self refreshTrip];[self.view setNeedsLayout];}
-(void)toggleTrip{[self refreshTrip];}
-(void)saveTrip{if(self.trip){NSUserDefaults *p=[NSUserDefaults standardUserDefaults];[p setObject:[self.trip summary] forKey:@"TRDTripSummary"];self.lastTripSavedAt=[NSDate date];}}
-(void)resetTripMenu{
  NSArray *slotNames = @[@"TRIP A (ทริปปัจจุบัน)", @"TRIP B (ทริปถังน้ำมันนี้)", @"TRIP C (ทริประยะยาว)"];
  NSInteger curSlot = self.activeTripSlot;
  if(curSlot < 0 || curSlot > 2) curSlot = 0;
  TRDSettingsMenu *menu=[self settingsMenu:@"📍 จัดการข้อมูลทริป (TRIP A / B / C)" message:[NSString stringWithFormat:@"กำลังเลือก: %@\nสามารถสลับดูทริป A/B/C หรือรีเซ็ตค่าเป็นศูนย์ได้ทันที", slotNames[curSlot]]];
  for(int i=0; i<3; i++){
    NSString *prefix = (i == curSlot) ? @"✓  " : @"    ";
    [menu addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"%@สลับไปแสดง %@", prefix, slotNames[i]] style:0 handler:^(TRDSettingAction *a){
      self.activeTripSlot = i;
      [[NSUserDefaults standardUserDefaults] setInteger:i forKey:@"TRDActiveTripSlot"];
      [[NSUserDefaults standardUserDefaults] synchronize];
      [self refreshDriveTripDisplay];
    }]];
  }
  [menu addAction:[TRDSettingAction actionWithTitle:[NSString stringWithFormat:@"🔄 รีเซ็ตค่า %@ เป็น 0.0 km", slotNames[curSlot]] style:0 handler:^(TRDSettingAction *a){
    self.trip=[TRDTrip new];
    [self saveTrip];
    [self refreshTrip];
    [self refreshDriveTripDisplay];
  }]];
  [menu addAction:[TRDSettingAction actionWithTitle:@"📊 เปิดหน้าจอสรุปทริปแบบเต็มจอ (Trip Summary)" style:0 handler:^(TRDSettingAction *a){
    [self showTripSummary];
  }]];
  [menu addAction:[TRDSettingAction actionWithTitle:@"⏱️ เปิดหน้าจอวัดความเร็ว GPS เต็มจอ (Trip / GPS)" style:0 handler:^(TRDSettingAction *a){
    [self openTrip];
  }]];
  [self presentSettingsMenu:menu];
}
-(void)refreshTrip{
 if(!self.tripView)return;
 TRDTrip *t=self.trip;
 BOOL fresh=TRDTripFixIsReliable(self.fix,[NSDate date]);
 if(!fresh&&t.running)[t breakSegment];
 if(self.driveTripButton&&!self.driveTripButton.hidden){
  NSString *newTitle=TRDDriveTripText(t.meters,t.seconds,t.running,fresh);
  if(![self.driveTripButton.currentTitle isEqualToString:newTitle]){
   [self.driveTripButton setTitle:newTitle forState:0];
   self.driveTripButton.accessibilityValue=newTitle;
  }
 }
 if(!self.tripMode)return;
 BOOL data=t.seconds>0;
 NSArray *values=@[data?[NSString stringWithFormat:@"%.2f",t.meters/1000]:@"--",data?[NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)t.seconds/3600,((long)t.seconds/60)%60,(long)t.seconds%60]:@"--:--:--",data?[NSString stringWithFormat:@"%.1f",t.meters/t.seconds*3.6]:@"--",data?[NSString stringWithFormat:@"%.0f",t.maximum]:@"--"];
 for(NSUInteger i=0;i<4;i++){
  UILabel *lbl=(UILabel *)self.tripView.values[i];
  if(![lbl.text isEqualToString:values[i]])lbl.text=values[i];
 }
 NSString *newState=fresh?(t.running?@"AUTO / RECORDING MOVEMENT":@"AUTO / PAUSED WHILE STOPPED"):@"AUTO / WAITING FOR RELIABLE GPS";
 if(![self.tripView.state.text isEqualToString:newState])self.tripView.state.text=newState;
 self.tripView.run.hidden=YES;
 self.tripView.title.textColor=TRDAccent();
 self.tripView.state.textColor=TRDAccent();
}
-(void)refreshMini{
 if(!self.miniPlayer||self.miniPlayer.hidden)return;
 NSString *newTitle=self.song.text.length?self.song.text:@"Choose your music";
 if(![self.miniPlayer.title.text isEqualToString:newTitle])self.miniPlayer.title.text=newTitle;
 NSString *newArtist=self.artist.text?:@"";
 if(![self.miniPlayer.artist.text isEqualToString:newArtist])self.miniPlayer.artist.text=newArtist;
 NSInteger newKind=self.radioPlayer?((self.radioPlayer.rate>0)?14:13):(self.hasPlaybackRate?(self.mediaRate>0?14:13):8);
 if(self.miniPlayer.icon.kind!=newKind){
  self.miniPlayer.icon.kind=newKind;
  [self.miniPlayer.icon setNeedsDisplay];
 }
 NSString *newLabel=self.radioPlayer?((self.radioPlayer.rate>0)?@"Pause":@"Play"):(self.hasPlaybackRate?(self.mediaRate>0?@"Pause":@"Play"):@"Play or pause");
 if(![self.miniPlayer.play.accessibilityLabel isEqualToString:newLabel])self.miniPlayer.play.accessibilityLabel=newLabel;
}
-(void)miniPlay{
  if(!self.radioPlayer){
    self.hasPlaybackRate = YES;
    self.mediaRate = (self.mediaRate > 0) ? 0.0 : 1.0;
    [self refreshTransportState];
  }
  [self media:(UIButton *)[self.controls viewWithTag:21]];
}
-(void)miniPrev{[self media:(UIButton *)[self.controls viewWithTag:20]];}
-(void)miniNext{[self media:(UIButton *)[self.controls viewWithTag:22]];}
-(void)miniOpen{[self.settingsSheet dismiss];[self openMusic];}
-(void)musicHold:(UILongPressGestureRecognizer *)gesture{if(gesture.state==UIGestureRecognizerStateBegan)[self showMusicSources:self.navButtons[2]];}
-(void)homeHold:(UILongPressGestureRecognizer *)gesture{if(gesture.state!=UIGestureRecognizerStateBegan)return;[self quickPages];}
-(void)quickPages{TRDSettingsMenu *menu=[self settingsMenu:@"QUICK VIEWS" message:@"Hold MUSIC for audio sources"];[menu addAction:[TRDSettingAction actionWithTitle:@"📞 Phone & Emergency (โทรศัพท์)" style:0 handler:^(TRDSettingAction *a){[self openPhoneMenu];}]];[menu addAction:[TRDSettingAction actionWithTitle:@"Trip / GPS" style:0 handler:^(TRDSettingAction *a){[self openTrip];}]];[menu addAction:[TRDSettingAction actionWithTitle:@"Google Maps" style:0 handler:^(TRDSettingAction *a){[self openMap];}]];[menu addAction:[TRDSettingAction actionWithTitle:@"Full Clock" style:0 handler:^(TRDSettingAction *a){UIButton *button=[UIButton new];button.tag=6;[self card:button];}]];[self presentSettingsMenu:menu];}
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch{if(gesture==self.returnTap&&[touch.view isDescendantOfView:self.miniPlayer])return NO;return YES;}
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)g1 shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)g2{return YES;}
-(void)testMiniPlay{[self.miniPlayer.play sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)testMiniPrev{[self.miniPlayer.prev sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)testMiniNext{[self.miniPlayer.next sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)testMiniOpen{[self.miniPlayer.open sendActionsForControlEvents:UIControlEventTouchUpInside];}
-(void)testTripButton{[self.tripButton sendActionsForControlEvents:UIControlEventTouchUpInside];}

-(void)cancelBrowseReturn{NSString *path=@"/var/mobile/codex-car/browse-return.plist";NSMutableDictionary *arm=[[NSDictionary dictionaryWithContentsOfFile:path]mutableCopy];if([arm[@"pending"]boolValue]){arm[@"pending"]=@NO;arm[@"cancelled"]=@YES;[arm writeToFile:path atomically:YES];}}
-(void)browseSource:(NSString *)bundle{
 if(![@[@"com.legacymusic.app",@"com.himais0giiiin.ytnine",@"com.codex.poddash"]containsObject:bundle])return;
 if(self.radioPlayer){[self.radioPlayer pause];self.radioPlayer=nil;}
 Boolean (*pauseCmd)(int,id)=dlsym(RTLD_DEFAULT,"MRMediaRemoteSendCommand");
 if(!pauseCmd||!pauseCmd(1,nil))[self send:@"libactivator.ipod.pause-playback"];
 [self prepareForExternalAppLaunch];
 if([bundle isEqualToString:@"com.legacymusic.app"]){
  NSDictionary *arm=@{@"bundle":bundle,@"token":[NSUUID UUID].UUIDString,@"pending":@YES,@"created":[NSDate date],@"expires":[NSDate dateWithTimeIntervalSinceNow:180],@"baselineTitle":self.song.text?:@""};
  if(![arm writeToFile:@"/var/mobile/codex-car/browse-return.plist" atomically:YES]){self.notice=@"Automatic return unavailable. Return to TRD manually.";self.noticeUntil=[NSDate dateWithTimeIntervalSinceNow:5];}
 }
 [self send:bundle];
}
