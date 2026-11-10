const fs = require('fs');

console.log("Reading cardash_main.m...");
let src = fs.readFileSync('cardash_main.m', 'utf8');

// Find the exact boundaries of viewDidLayoutSubviews
const startMarker = '-(void)viewDidLayoutSubviews{';
const endMarker = '-(void)update{';

const startIdx = src.indexOf(startMarker);
const endIdx = src.indexOf(endMarker);

if (startIdx === -1 || endIdx === -1) {
  console.error("Could not find viewDidLayoutSubviews or update!");
  process.exit(1);
}

console.log(`Found viewDidLayoutSubviews from ${startIdx} to ${endIdx}`);

const newLayoutMethod = `-(void)viewDidLayoutSubviews{
  [super viewDidLayoutSubviews];
  self.carGlow.hidden = YES;
  if (self.welcome) {
    self.welcome.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.welcome];
  }

  CGFloat w = self.view.bounds.size.width;
  CGFloat fullH = self.view.bounds.size.height;
  CGFloat h = fullH - (self.focused ? 0 : 78);
  BOOL landscape = (w > h);

  // 1. CARPLAY MODE LAYOUT
  self.carplayDock.hidden = !self.carplayMode;
  self.carplayTurnBanner.hidden = YES;
  self.carplayMediaCard.hidden = !(self.carplayMode && !self.carplayGridMode);
  self.carplayTelemetryCard.hidden = !(self.carplayMode && !self.carplayGridMode);
  self.carplayAppGrid.hidden = !(self.carplayMode && self.carplayGridMode);

  if (self.carplayMode) {
    self.arc.hidden = YES; self.progress.hidden = YES; self.speed.hidden = YES; self.unit.hidden = YES;
    self.gpsStatus.hidden = YES; self.compassLabel.hidden = YES; self.energyFlowLabel.hidden = YES;
    self.speedLimitBtn.hidden = YES; self.brakeStatusCard.hidden = YES; self.carImage.hidden = YES;
    self.driveCar.hidden = YES; self.driveEQ.hidden = YES; self.clock.hidden = YES; self.date.hidden = YES;
    self.heading.hidden = YES; self.owner.hidden = YES; self.statusStrip.hidden = YES; self.nowPanel.hidden = YES;
    self.nightButton.hidden = YES; self.modeButton.hidden = YES; self.driveButton.hidden = YES;
    self.tripButton.hidden = YES; self.miniPlayer.hidden = YES; self.navigation.hidden = YES;
    for (UIView *cb in self.cards) cb.hidden = YES;
    self.homeSpeedoDial.hidden = YES; self.homeAiEcoCard.hidden = YES; self.homeThermalsCard.hidden = YES;
    self.driveSpeedoDial.hidden = YES; self.driveShifter.hidden = YES; self.drivePowerMeter.hidden = YES;
    self.drive3DGrid.hidden = YES; self.driveClockCard.hidden = YES; self.driveBatteryCard.hidden = YES;
    self.driveTripCard.hidden = YES; self.driveEqBtn.hidden = YES; self.driveExitBtn.hidden = YES;

    self.carplayDock.frame = CGRectMake(0, 0, 80, fullH);
    self.carplayHomeBtn.frame = CGRectMake(13, 14, 54, 54);
    for (int i = 0; i < self.carplayDockButtons.count; i++) {
      UIView *db = self.carplayDockButtons[i];
      db.frame = CGRectMake(13, 85 + i * 66, 54, 54);
    }
    self.carplayClock.frame = CGRectMake(4, fullH - 76, 72, 20);
    self.carplayBattery.frame = CGRectMake(4, fullH - 54, 72, 18);
    self.carplayWifi.frame = CGRectMake(8, fullH - 32, 64, 18);

    if (self.carplayGridMode) {
      self.mapContainer.hidden = YES; self.controls.hidden = YES; self.artwork.hidden = YES;
      self.artPlaceholder.hidden = YES; self.song.hidden = YES; self.artist.hidden = YES;
      self.trackTime.hidden = YES; self.trackProgress.hidden = YES; self.sourceBadge.hidden = YES;
      self.carplayAppGrid.frame = CGRectMake(80, 0, w - 80, fullH);
    } else {
      CGFloat mapW = (w - 96) * 0.57;
      self.mapContainer.hidden = NO; self.mapContainer.frame = CGRectMake(90, 12, mapW, fullH - 24);
      if (self.mapWebView) self.mapWebView.frame = self.mapContainer.bounds;
      self.carplayTurnBanner.frame = CGRectMake(10, 10, mapW - 20, 54);

      CGFloat rx = 90 + mapW + 12, rw = w - rx - 12;
      CGFloat mediaH = (fullH - 36) * 0.53;
      self.carplayMediaCard.frame = CGRectMake(rx, 12, rw, mediaH);
      self.artwork.hidden = NO; self.artwork.frame = CGRectMake(rx + 16, 22, 96, 96);
      self.artist.hidden = NO; self.song.hidden = NO;
      self.trackProgress.hidden = NO; self.trackTime.hidden = NO;
      self.controls.hidden = NO; self.controls.frame = CGRectMake(rx + 16, mediaH - 64, rw - 32, 60);

      CGFloat telY = 12 + mediaH + 12, telH = fullH - 24 - mediaH - 12;
      self.carplayTelemetryCard.frame = CGRectMake(rx, telY, rw, telH);
    }
    return;
  }

  // Hide legacy/unused items
  self.nightButton.hidden = YES;
  self.modeButton.hidden = YES;
  self.driveButton.hidden = YES;
  self.statusStrip.hidden = YES;
  self.tripButton.hidden = YES;
  self.brakeStatusCard.hidden = YES;
  self.hybridSocCard.hidden = YES;
  for (UIView *cb in self.cards) cb.hidden = YES;

  if (self.driveMode) {
    // =========================================================================
    // DRIVE MODE (100% Matching prius_drive_mode_concept.jpg)
    // =========================================================================
    self.homeSpeedoDial.hidden = YES;
    self.homeAiEcoCard.hidden = YES;
    self.homeThermalsCard.hidden = YES;
    for (UIButton *b in self.gearButtons) b.hidden = YES;
    self.hybridEcoBar.hidden = YES;
    for (UIButton *b in self.driveModePills) b.hidden = YES;
    self.frontMotorBox.hidden = YES;
    self.rearBatteryBox.hidden = YES;
    self.flowBeamLine.hidden = YES;
    self.blockGraphView.hidden = YES;
    self.navigation.hidden = YES;
    self.topClockLabel.hidden = YES;
    self.obdStatusPill.hidden = YES;
    self.dayNightPill.hidden = YES;
    self.thaiVoicePill.hidden = YES;
    self.settingsPill.hidden = YES;
    self.carImage.hidden = YES;
    self.arc.hidden = YES;
    self.progress.hidden = YES;
    self.speed.hidden = YES;
    self.unit.hidden = YES;
    self.speedLimitBtn.hidden = YES;
    UIView *pCard = [self.view viewWithTag:701]; if (pCard) pCard.hidden = YES;
    UIView *deltaL = [self.view viewWithTag:706]; if (deltaL) deltaL.hidden = YES;
    UIView *mCard = [self.view viewWithTag:707]; if (mCard) mCard.hidden = YES;
    UIView *tCard = [self.view viewWithTag:711]; if (tCard) tCard.hidden = YES;

    // Top Bar
    CGFloat barY = 12;
    self.heading.hidden = NO;
    self.heading.frame = CGRectMake(20, barY, 380, 24);
    self.heading.font = [UIFont boldSystemFontOfSize:15];
    self.heading.textColor = [UIColor whiteColor];
    self.heading.text = @"PRIUS TRD SPORTIVO • DRIVE COCKPIT";

    self.owner.hidden = YES;

    // Center Clock & Speed Limit in Header
    self.clock.hidden = NO;
    self.clock.frame = CGRectMake(w/2 - 60, barY, 80, 24);
    self.clock.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:22] ?: [UIFont boldSystemFontOfSize:22];
    self.clock.textColor = [UIColor whiteColor];
    self.clock.textAlignment = NSTextAlignmentCenter;
    self.date.hidden = YES;

    // Right Pills: GPS, OBD2, 12V
    CGFloat curRx = w - 20;
    CGFloat pillH = 26;
    curRx -= 90;
    self.thaiVoicePill.hidden = NO;
    self.thaiVoicePill.frame = CGRectMake(curRx, barY - 1, 90, pillH);
    [self.thaiVoicePill setTitle:@"12V: 13.8V" forState:UIControlStateNormal];

    curRx -= 105;
    self.obdStatusPill.hidden = NO;
    self.obdStatusPill.frame = CGRectMake(curRx, barY - 1, 100, pillH);
    [self.obdStatusPill setTitle:@"OBD2: LIVE" forState:UIControlStateNormal];

    curRx -= 115;
    self.dayNightPill.hidden = NO;
    self.dayNightPill.frame = CGRectMake(curRx, barY - 1, 110, pillH);
    [self.dayNightPill setTitle:@"GPS: 3D LOCK" forState:UIControlStateNormal];

    // Left Pod (Width: 250, Y: 48, Height: 590)
    CGFloat podW = 250, topY = 48;
    self.driveLeftCard.hidden = NO;
    self.driveLeftCard.frame = CGRectMake(18, topY, podW, 590);
    self.driveLeftCard.layer.cornerRadius = 14;
    self.driveLeftCard.layer.borderWidth = 1.0;
    self.driveLeftCard.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1].CGColor;
    self.driveLeftCard.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.08 alpha:0.95];

    self.driveSpeedoDial.hidden = NO;
    self.driveSpeedoDial.frame = CGRectMake(20, topY + 4, podW - 4, 180);

    self.driveShifter.hidden = NO;
    self.driveShifter.frame = CGRectMake(20 + (podW - 4 - 44)/2 + 20, topY + 190, 44, 138);

    self.gearBadge.hidden = NO;
    self.gearBadge.frame = CGRectMake(20 + (podW - 4 - 44)/2 - 54, topY + 242, 66, 26);

    self.drivePowerMeter.hidden = NO;
    self.drivePowerMeter.frame = CGRectMake(20, topY + 372, podW - 4, 204);

    // Center Pod (Width: 456, X: 284, Y: 48, Height: 590)
    CGFloat centerW = 456, centerX = 284;
    self.energyFlowLabel.hidden = NO;
    self.energyFlowLabel.frame = CGRectMake(centerX + 30, topY + 12, centerW - 60, 32);
    self.energyFlowLabel.font = [UIFont boldSystemFontOfSize:12];
    self.energyFlowLabel.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.energyFlowLabel.layer.cornerRadius = 8;
    self.energyFlowLabel.layer.borderWidth = 1.0;
    self.energyFlowLabel.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.4].CGColor;
    self.energyFlowLabel.backgroundColor = [UIColor colorWithRed:.02 green:.08 blue:.12 alpha:.8];
    self.energyFlowLabel.text = @"CRUISE 78 km/h  •  EV MODE READY";

    self.driveCameraButton.hidden = NO;
    self.driveCameraButton.frame = CGRectMake(centerX + 50, topY + 54, centerW - 100, 46);
    [self.driveCameraButton setTitle:@"\\U0001F4F7  REAR CAMERA" forState:UIControlStateNormal];
    self.driveCameraButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.driveCameraButton.layer.cornerRadius = 10;
    self.driveCameraButton.layer.borderWidth = 1.2;
    self.driveCameraButton.layer.borderColor = [UIColor colorWithWhite:.3 alpha:1].CGColor;
    self.driveCameraButton.backgroundColor = [UIColor colorWithRed:.08 green:.12 blue:.16 alpha:.9];

    self.drive3DGrid.hidden = NO;
    self.drive3DGrid.frame = CGRectMake(centerX, topY + 200, centerW, 280);

    self.driveCar.hidden = NO;
    self.driveCar.frame = CGRectMake(centerX + (centerW - 390)/2, topY + 160, 390, 245);

    self.compassLabel.hidden = NO;
    self.compassLabel.frame = CGRectMake(centerX + 16, topY + 490, centerW - 32, 22);
    self.compassLabel.font = [UIFont boldSystemFontOfSize:11.5];
    self.compassLabel.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.compassLabel.textAlignment = NSTextAlignmentCenter;
    self.compassLabel.text = @"\\u0e01\\u0e23\\u0e30\\u0e41\\u0e2a\\u0e44\\u0e1f\\u0e44\\u0e2e\\u0e1a\\u0e23\\u0e34\\u0e14: \\u26a1 \\u0e0a\\u0e32\\u0e23\\u0e4c\\u0e08\\u0e44\\u0e1f\\u0e40\\u0e02\\u0e49\\u0e32\\u0e41\\u0e1a\\u0e15\\u0e40\\u0e15\\u0e2d\\u0e23\\u0e35\\u0e48 (Inflow)  +14.2 kW (Regen Active)";

    // Right Pod (Width: 250, X: 756, Y: 48, Height: 590)
    CGFloat rightX = 756;
    self.driveRightCard.hidden = NO;
    self.driveRightCard.frame = CGRectMake(rightX, topY, podW, 590);
    self.driveRightCard.layer.cornerRadius = 14;
    self.driveRightCard.layer.borderWidth = 1.0;
    self.driveRightCard.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1].CGColor;
    self.driveRightCard.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.08 alpha:0.95];

    self.driveClockCard.hidden = NO;
    self.driveClockCard.frame = CGRectMake(rightX + 12, topY + 12, podW - 24, 110);
    UILabel *cBig = (UILabel *)[self.driveClockCard viewWithTag:801];
    if (!cBig) {
      cBig = [[UILabel alloc] initWithFrame:CGRectMake(8, 8, podW - 40, 60)];
      cBig.tag = 801;
      cBig.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:64] ?: [UIFont boldSystemFontOfSize:64];
      cBig.textColor = [UIColor whiteColor];
      cBig.textAlignment = NSTextAlignmentCenter;
      [self.driveClockCard addSubview:cBig];
      UILabel *cSub = [[UILabel alloc] initWithFrame:CGRectMake(8, 70, podW - 40, 24)];
      cSub.tag = 802;
      cSub.font = [UIFont boldSystemFontOfSize:13];
      cSub.textColor = [UIColor colorWithWhite:0.7 alpha:1];
      cSub.textAlignment = NSTextAlignmentCenter;
      cSub.text = @"CABIN  24.0\\u00b0C";
      [self.driveClockCard addSubview:cSub];
    }
    cBig.text = [self.clockFormat stringFromDate:[NSDate date]];

    self.driveBatteryCard.hidden = NO;
    self.driveBatteryCard.frame = CGRectMake(rightX + 12, topY + 132, podW - 24, 115);
    UILabel *bH = (UILabel *)[self.driveBatteryCard viewWithTag:811];
    if (!bH) {
      bH = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, podW - 44, 20)];
      bH.tag = 811;
      bH.font = [UIFont boldSystemFontOfSize:10];
      bH.textColor = [UIColor colorWithWhite:0.6 alpha:1];
      bH.text = @"HYBRID TRACTION BATTERY";
      [self.driveBatteryCard addSubview:bH];

      UIView *barBg = [[UIView alloc] initWithFrame:CGRectMake(10, 36, podW - 44, 16)];
      barBg.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
      barBg.layer.cornerRadius = 8;
      barBg.clipsToBounds = YES;
      UIView *barFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, (podW - 44) * 0.76, 16)];
      barFill.backgroundColor = [UIColor colorWithRed:0 green:.85 blue:.5 alpha:1];
      [barBg addSubview:barFill];
      [self.driveBatteryCard addSubview:barBg];

      UILabel *bS = [[UILabel alloc] initWithFrame:CGRectMake(10, 60, podW - 44, 34)];
      bS.tag = 812;
      bS.font = [UIFont boldSystemFontOfSize:15];
      bS.textColor = [UIColor colorWithRed:.2 green:.95 blue:.5 alpha:1];
      bS.text = @"76% (EV READY)";
      [self.driveBatteryCard addSubview:bS];
    }

    self.driveTripCard.hidden = NO;
    self.driveTripCard.frame = CGRectMake(rightX + 12, topY + 258, podW - 24, 160);
    UILabel *tH = (UILabel *)[self.driveTripCard viewWithTag:821];
    if (!tH) {
      tH = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, podW - 44, 20)];
      tH.tag = 821;
      tH.font = [UIFont boldSystemFontOfSize:11];
      tH.textColor = [UIColor colorWithWhite:0.6 alpha:1];
      tH.text = @"TRIP A:";
      [self.driveTripCard addSubview:tH];

      UILabel *tBody = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, podW - 44, 110)];
      tBody.tag = 822;
      tBody.numberOfLines = 4;
      tBody.font = [UIFont boldSystemFontOfSize:14];
      tBody.textColor = [UIColor whiteColor];
      tBody.text = @"\\u2022 24.6 km\\n\\u2022 24.2 km/L\\n\\u2022 \\u0e3f38.50";
      [self.driveTripCard addSubview:tBody];
    }

    self.radioButton.hidden = NO;
    self.radioButton.frame = CGRectMake(rightX + 12, topY + 434, podW - 24, 52);
    [self.radioButton setTitle:@"\\U0001F4FB  THAI RADIO" forState:UIControlStateNormal];
    self.radioButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.radioButton.layer.cornerRadius = 10;
    self.radioButton.layer.borderWidth = 1.0;
    self.radioButton.layer.borderColor = [UIColor colorWithWhite:.25 alpha:1].CGColor;
    self.radioButton.backgroundColor = [UIColor colorWithRed:.06 green:.08 blue:.12 alpha:.9];

    // Bottom Console
    CGFloat consoleY = topY + 600;
    CGFloat consoleH = 96;
    self.nowPanel.hidden = NO;
    self.nowPanel.frame = CGRectMake(18, consoleY, w - 36, consoleH);
    self.nowPanel.layer.cornerRadius = 14;
    self.nowPanel.layer.borderWidth = 1.0;
    self.nowPanel.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.nowPanel.backgroundColor = [UIColor colorWithRed:.04 green:.06 blue:.08 alpha:.95];

    self.artwork.hidden = NO;
    self.artwork.frame = CGRectMake(28, consoleY + 12, consoleH - 24, consoleH - 24);
    self.artwork.layer.cornerRadius = 8;
    self.artPlaceholder.frame = self.artwork.frame;
    self.artPlaceholder.hidden = (self.artwork.image != nil);

    CGFloat artRight = 28 + consoleH - 24 + 14;
    self.song.hidden = NO;
    self.song.frame = CGRectMake(artRight, consoleY + 16, 260, 26);
    self.song.font = [UIFont boldSystemFontOfSize:15];
    self.song.textColor = [UIColor whiteColor];

    self.artist.hidden = NO;
    self.artist.frame = CGRectMake(artRight, consoleY + 44, 260, 20);
    self.artist.font = [UIFont systemFontOfSize:12];
    self.artist.textColor = [UIColor colorWithWhite:0.6 alpha:1];

    self.controls.hidden = NO;
    self.controls.frame = CGRectMake(artRight + 270, consoleY + 18, 180, 60);

    self.driveEqBtn.hidden = NO;
    self.driveEqBtn.frame = CGRectMake(w - 36 - 290, consoleY + 24, 135, 48);

    self.driveExitBtn.hidden = NO;
    self.driveExitBtn.frame = CGRectMake(w - 36 - 145, consoleY + 24, 135, 48);

    // Bring subviews to front for Drive Mode
    [self.view bringSubviewToFront:self.driveLeftCard];
    [self.view bringSubviewToFront:self.driveSpeedoDial];
    [self.view bringSubviewToFront:self.driveShifter];
    [self.view bringSubviewToFront:self.gearBadge];
    [self.view bringSubviewToFront:self.drivePowerMeter];
    [self.view bringSubviewToFront:self.drive3DGrid];
    [self.view bringSubviewToFront:self.driveCar];
    [self.view bringSubviewToFront:self.energyFlowLabel];
    [self.view bringSubviewToFront:self.driveCameraButton];
    [self.view bringSubviewToFront:self.compassLabel];
    [self.view bringSubviewToFront:self.driveRightCard];
    [self.view bringSubviewToFront:self.driveClockCard];
    [self.view bringSubviewToFront:self.driveBatteryCard];
    [self.view bringSubviewToFront:self.driveTripCard];
    [self.view bringSubviewToFront:self.radioButton];
    [self.view bringSubviewToFront:self.nowPanel];
    [self.view bringSubviewToFront:self.artwork];
    [self.view bringSubviewToFront:self.song];
    [self.view bringSubviewToFront:self.artist];
    [self.view bringSubviewToFront:self.controls];
    [self.view bringSubviewToFront:self.driveEqBtn];
    [self.view bringSubviewToFront:self.driveExitBtn];

  } else {
    // =========================================================================
    // HOME DASHBOARD (100% Matching dashboard.html / media_1794267643239_0594d895.jpg)
    // =========================================================================
    self.driveSpeedoDial.hidden = YES;
    self.driveShifter.hidden = YES;
    self.drivePowerMeter.hidden = YES;
    self.drive3DGrid.hidden = YES;
    self.driveClockCard.hidden = YES;
    self.driveBatteryCard.hidden = YES;
    self.driveTripCard.hidden = YES;
    self.driveEqBtn.hidden = YES;
    self.driveExitBtn.hidden = YES;
    self.driveCar.hidden = YES;
    self.driveCameraButton.hidden = YES;
    self.radioButton.hidden = YES;
    self.clock.hidden = YES;
    self.date.hidden = YES;
    self.arc.hidden = YES;
    self.progress.hidden = YES;
    self.speed.hidden = YES;
    self.unit.hidden = YES;
    self.speedLimitBtn.hidden = YES;

    CGFloat colH = 620, topY = 62;
    CGFloat leftW = 252, centerW = 472, rightW = 252;
    CGFloat leftX = 14, centerX = 276, rightX = 758;

    // Top Bar
    CGFloat barY = 12;
    self.heading.hidden = NO;
    self.heading.frame = CGRectMake(16, barY, 320, 22);
    self.heading.font = [UIFont boldSystemFontOfSize:16];
    self.heading.text = @"PRIUS TRD SPORTIVO";
    self.owner.hidden = NO;
    self.owner.frame = CGRectMake(16, barY + 22, 380, 16);
    self.owner.font = [UIFont boldSystemFontOfSize:10.5];
    self.owner.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.owner.text = @"LUXURY EV SMART COCKPIT \\u2022 FULLSCREEN KIOSK READY";

    CGFloat curRx = w - 16;
    CGFloat pillH = 32;

    curRx -= 104;
    self.settingsPill.hidden = NO;
    self.settingsPill.frame = CGRectMake(curRx, barY + 4, 104, pillH);

    curRx -= 96;
    self.thaiVoicePill.hidden = NO;
    self.thaiVoicePill.frame = CGRectMake(curRx, barY + 4, 88, pillH);

    curRx -= 66;
    self.topClockLabel.hidden = NO;
    self.topClockLabel.frame = CGRectMake(curRx, barY + 4, 60, pillH);
    self.topClockLabel.text = [self.clockFormat stringFromDate:[NSDate date]];

    curRx -= 90;
    self.dayNightPill.hidden = NO;
    self.dayNightPill.frame = CGRectMake(curRx, barY + 4, 84, pillH);

    curRx -= 144;
    self.obdStatusPill.hidden = NO;
    self.obdStatusPill.frame = CGRectMake(curRx, barY + 4, 138, pillH);

    // 1. LEFT ZONE
    self.driveLeftCard.hidden = NO;
    self.driveLeftCard.frame = CGRectMake(leftX, topY, leftW, colH);
    self.driveLeftCard.layer.cornerRadius = 14;
    self.driveLeftCard.layer.borderWidth = 1.2;
    self.driveLeftCard.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.driveLeftCard.backgroundColor = [UIColor colorWithRed:.04 green:.06 blue:.08 alpha:.95];

    self.readyPill.hidden = NO;
    self.readyPill.frame = CGRectMake(leftX + (leftW - 140)/2, topY + 8, 140, 22);

    self.homeSpeedoDial.hidden = NO;
    self.homeSpeedoDial.frame = CGRectMake(leftX + 6, topY + 32, leftW - 12, 108);

    CGFloat gw = (leftW - 20 - 4*5)/5;
    for (int i = 0; i < self.gearButtons.count; i++) {
      UIButton *gb = self.gearButtons[i];
      gb.hidden = NO;
      gb.frame = CGRectMake(leftX + 10 + i*(gw + 5), topY + 144, gw, 28);
    }

    self.hybridEcoBar.hidden = NO;
    self.hybridEcoBar.frame = CGRectMake(leftX + 10, topY + 178, leftW - 20, 26);

    CGFloat mw = (leftW - 20 - 2*6)/3;
    for (int i = 0; i < self.driveModePills.count; i++) {
      UIButton *mb = self.driveModePills[i];
      mb.hidden = NO;
      mb.frame = CGRectMake(leftX + 10 + i*(mw + 6), topY + 210, mw, 28);
    }

    self.homeAiEcoCard.hidden = NO;
    self.homeAiEcoCard.frame = CGRectMake(leftX + 10, topY + 246, leftW - 20, 175);

    self.homeThermalsCard.hidden = NO;
    self.homeThermalsCard.frame = CGRectMake(leftX + 10, topY + 428, leftW - 20, 180);

    // 2. CENTER ZONE
    self.energyFlowLabel.hidden = NO;
    self.energyFlowLabel.frame = CGRectMake(centerX + 8, topY + 8, centerW - 16, 28);
    self.energyFlowLabel.layer.cornerRadius = 6;
    self.energyFlowLabel.layer.borderWidth = 1;
    self.energyFlowLabel.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.energyFlowLabel.backgroundColor = [UIColor colorWithRed:.02 green:.06 blue:.08 alpha:.92];
    self.energyFlowLabel.text = @"\\U0001F343 PURE EV DRIVE (MG2 \\u2013 \\u0e40\\u0e1e\\u0e25\\u0e32\\u0e02\\u0e31\\u0e1a\\u0e2b\\u0e19\\u0e49\\u0e32) \\u26A1     \\u26A1 \\u0e14\\u0e36\\u0e07\\u0e44\\u0e1f\\u0e08\\u0e32\\u0e01\\u0e41\\u0e1a\\u0e15\\u0e40\\u0e15\\u0e2d\\u0e23\\u0e35\\u0e48 EV";

    self.frontMotorBox.hidden = NO;
    self.frontMotorBox.frame = CGRectMake(centerX + 8, topY + 42, 160, 36);

    self.rearBatteryBox.hidden = NO;
    self.rearBatteryBox.frame = CGRectMake(centerX + centerW - 168, topY + 42, 160, 36);

    self.carImage.hidden = NO;
    self.carImage.frame = CGRectMake(centerX + (centerW - 320)/2, topY + 70, 320, 175);

    self.flowBeamLine.hidden = NO;
    self.flowBeamLine.frame = CGRectMake(centerX + 24, topY + 246, centerW - 48, 2);
    UIView *rDot = [self.flowBeamLine viewWithTag:831];
    if (rDot) rDot.frame = CGRectMake(centerW - 48 - 10, -4, 10, 10);

    self.compassLabel.hidden = NO;
    self.compassLabel.frame = CGRectMake(centerX + 8, topY + 256, centerW - 16, 20);
    self.compassLabel.font = [UIFont boldSystemFontOfSize:11];
    self.compassLabel.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
    self.compassLabel.textAlignment = NSTextAlignmentCenter;
    self.compassLabel.text = @"\\u0e01\\u0e23\\u0e30\\u0e41\\u0e2a\\u0e44\\u0e1f\\u0e44\\u0e2e\\u0e1a\\u0e23\\u0e34\\u0e14: \\u26a1 \\u0e0a\\u0e32\\u0e23\\u0e4c\\u0e08\\u0e44\\u0e1f\\u0e40\\u0e02\\u0e49\\u0e32\\u0e41\\u0e1a\\u0e15\\u0e40\\u0e15\\u0e2d\\u0e23\\u0e35\\u0e48 (Inflow)  +14.2 kW (Regen Active)";

    self.carStatus.hidden = NO;
    self.carStatus.frame = CGRectMake(centerX + 8, topY + 282, centerW - 16, 28);
    self.carStatus.font = [UIFont boldSystemFontOfSize:11];
    self.carStatus.textColor = [UIColor colorWithWhite:.88 alpha:1];
    self.carStatus.textAlignment = NSTextAlignmentCenter;
    self.carStatus.layer.cornerRadius = 6;
    self.carStatus.layer.borderWidth = 1;
    self.carStatus.layer.borderColor = [UIColor colorWithWhite:.16 alpha:1].CGColor;
    self.carStatus.backgroundColor = [UIColor colorWithRed:.02 green:.05 blue:.07 alpha:.8];
    self.carStatus.text = @"\\U0001F6AA \\u0e1b\\u0e23\\u0e30\\u0e15\\u0e39 5 \\u0e1a\\u0e32\\u0e19: \\u0e1b\\u0e34\\u0e14\\u0e2a\\u0e19\\u0e34\\u0e17 \\u2022 \\U0001F512 \\u0e40\\u0e02\\u0e47\\u0e21\\u0e02\\u0e31\\u0e14\\u0e25\\u0e47\\u0e2d\\u0e04: \\u0e25\\u0e47\\u0e2d\\u0e04\\u0e2d\\u0e22\\u0e39\\u0e48 (\\u0e41\\u0e15\\u0e30\\u0e40\\u0e1e\\u0e37\\u0e48\\u0e2d\\u0e14\\u0e39\\u0e23\\u0e32\\u0e22\\u0e25\\u0e30\\u0e40\\u0e2d\\u0e35\\u0e22\\u0e14)";

    // Multimedia Console
    CGFloat mTop = topY + 318;
    self.nowPanel.hidden = NO;
    self.nowPanel.frame = CGRectMake(centerX + 8, mTop, centerW - 16, colH - 326);
    self.nowPanel.layer.cornerRadius = 12;
    self.nowPanel.layer.borderWidth = 1;
    self.nowPanel.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.nowPanel.backgroundColor = [UIColor colorWithRed:.03 green:.06 blue:.09 alpha:.95];

    self.artwork.hidden = NO;
    self.artwork.frame = CGRectMake(centerX + 20, mTop + 14, 110, 110);
    self.artwork.layer.cornerRadius = 10;
    self.artPlaceholder.frame = self.artwork.frame;
    self.artPlaceholder.hidden = (self.artwork.image != nil);

    UILabel *mHead = (UILabel *)[self.nowPanel viewWithTag:750];
    if (!mHead) {
      mHead = [[UILabel alloc] initWithFrame:CGRectMake(140, 8, centerW - 160, 16)];
      mHead.tag = 750;
      mHead.font = [UIFont boldSystemFontOfSize:10];
      mHead.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
      mHead.text = @"\\U0001F3B5 CAR MULTIMEDIA & AUDIO         11 \\u0e40\\u0e1e\\u0e25\\u0e07\\u0e43\\u0e19\\u0e40\\u0e04\\u0e23\\u0e37\\u0e48\\u0e2d\\u0e07 \\u2022 JBL EQUALIZER";
      [self.nowPanel addSubview:mHead];
    }

    self.song.hidden = NO;
    self.song.frame = CGRectMake(centerX + 148, mTop + 30, centerW - 168, 30);
    self.song.font = [UIFont boldSystemFontOfSize:15];
    self.song.textColor = [UIColor whiteColor];

    self.artist.hidden = NO;
    self.artist.frame = CGRectMake(centerX + 148, mTop + 62, centerW - 168, 20);
    self.artist.font = [UIFont systemFontOfSize:12];
    self.artist.textColor = [UIColor colorWithWhite:0.65 alpha:1];

    self.trackProgress.hidden = NO;
    self.trackProgress.frame = CGRectMake(centerX + 148, mTop + 90, centerW - 168, 3);

    self.trackTime.hidden = NO;
    self.trackTime.frame = CGRectMake(centerX + 148, mTop + 96, centerW - 168, 16);
    self.trackTime.font = [UIFont systemFontOfSize:9.5];
    self.trackTime.textColor = [UIColor colorWithWhite:0.65 alpha:1];
    self.trackTime.textAlignment = NSTextAlignmentRight;

    self.controls.hidden = NO;
    self.controls.frame = CGRectMake(centerX + 20, mTop + 134, 300, 56);
    CGFloat cw = 290 / 3.0;
    for (int i = 0; i < 3; i++) {
      UIView *b = [self.controls viewWithTag:20 + i];
      b.frame = CGRectMake(i * (cw + 4), 0, cw, 56);
      b.layer.cornerRadius = 8;
      if (i == 1) {
        b.backgroundColor = [UIColor colorWithRed:.0 green:.72 blue:.40 alpha:1];
        b.layer.borderColor = [UIColor colorWithRed:.2 green:.9 blue:.5 alpha:1].CGColor;
      } else {
        b.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
        b.layer.borderColor = [UIColor colorWithWhite:.24 alpha:1].CGColor;
      }
      [b viewWithTag:105].frame = CGRectMake((cw - 28)/2, (56 - 28)/2, 28, 28);
    }

    self.driveEQ.hidden = NO;
    self.driveEQ.frame = CGRectMake(centerX + 328, mTop + 134, centerW - 344, 56);
    self.driveEQ.layer.cornerRadius = 8;
    self.driveEQ.layer.borderWidth = 1;
    self.driveEQ.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.4].CGColor;
    self.driveEQ.backgroundColor = [UIColor colorWithRed:.02 green:.08 blue:.12 alpha:.9];
    [self.driveEQ setTitle:@"\\U0001F39B\\U0000FE0F JBL EQ" forState:UIControlStateNormal];
    self.driveEQ.titleLabel.font = [UIFont boldSystemFontOfSize:12];

    // 3. RIGHT ZONE
    self.driveRightCard.hidden = NO;
    self.driveRightCard.frame = CGRectMake(rightX, topY, rightW, colH);
    self.driveRightCard.layer.cornerRadius = 14;
    self.driveRightCard.layer.borderWidth = 1.2;
    self.driveRightCard.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.driveRightCard.backgroundColor = [UIColor colorWithRed:.04 green:.06 blue:.08 alpha:.95];

    // Right Card 1: POWERTRAIN & HV • 7E3
    UIView *pCard = [self.view viewWithTag:701];
    if (!pCard) {
      pCard = [[UIView alloc] init];
      pCard.tag = 701;
      pCard.backgroundColor = [UIColor colorWithRed:.02 green:.06 blue:.08 alpha:.92];
      pCard.layer.cornerRadius = 10;
      pCard.layer.borderWidth = 1.0;
      pCard.layer.borderColor = [UIColor colorWithRed:0 green:.75 blue:.85 alpha:.35].CGColor;

      UILabel *pt = [[UILabel alloc] initWithFrame:CGRectMake(8, 6, rightW - 36, 16)];
      pt.tag = 702;
      pt.font = [UIFont boldSystemFontOfSize:10.5];
      pt.textColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:1];
      pt.text = @"POWERTRAIN & HV \\u2022 7E3";
      [pCard addSubview:pt];

      UILabel *pb = [[UILabel alloc] initWithFrame:CGRectMake(8, 24, rightW - 36, 54)];
      pb.tag = 703;
      pb.font = [UIFont boldSystemFontOfSize:11];
      pb.textColor = [UIColor whiteColor];
      pb.numberOfLines = 3;
      pb.text = @"64.5% SOC (\\u0e23\\u0e30\\u0e14\\u0e31\\u0e1a\\u0e44\\u0e1f\\u0e44\\u0e2e\\u0e1a\\u0e23\\u0e34\\u0e14)\\n227.4 V \\u2022 +12.4 A (CHG)\\n14 BLOCKS (28 NiMH MODULES)";
      [pCard addSubview:pb];
      [self.view addSubview:pCard];
    }
    pCard.hidden = NO;
    pCard.frame = CGRectMake(rightX + 10, topY + 8, rightW - 20, 248);

    self.blockGraphView.hidden = NO;
    self.blockGraphView.frame = CGRectMake(rightX + 18, topY + 88, rightW - 36, 40);

    UIView *deltaL = [self.view viewWithTag:706];
    if (!deltaL) {
      deltaL = [[UILabel alloc] init];
      deltaL.tag = 706;
      deltaL.font = [UIFont boldSystemFontOfSize:9.5];
      deltaL.textColor = [UIColor colorWithWhite:.85 alpha:1];
      deltaL.text = @"\\u0394V: 0.02 V (Good)   Min 16.22 / Max 16.24";
      [self.view addSubview:deltaL];
    }
    deltaL.hidden = NO;
    deltaL.frame = CGRectMake(rightX + 18, topY + 132, rightW - 36, 16);

    // Right Card 2: 3 Motor Rows
    UIView *mCard = [self.view viewWithTag:707];
    if (!mCard) {
      mCard = [[UIView alloc] init];
      mCard.tag = 707;
      mCard.backgroundColor = [UIColor colorWithRed:.02 green:.04 blue:.06 alpha:.92];
      mCard.layer.cornerRadius = 10;
      mCard.layer.borderWidth = 1.0;
      mCard.layer.borderColor = [UIColor colorWithWhite:.16 alpha:1].CGColor;

      UILabel *ml = [[UILabel alloc] initWithFrame:CGRectMake(8, 8, rightW - 36, 120)];
      ml.tag = 708;
      ml.font = [UIFont boldSystemFontOfSize:10];
      ml.textColor = [UIColor whiteColor];
      ml.numberOfLines = 5;
      ml.text = @"\\u2699\\ufe0f \\u0e21\\u0e2d\\u0e40\\u0e15\\u0e2d\\u0e23\\u0e4c MG2 (\\u0e02\\u0e31\\u0e1a\\u0e40\\u0e04\\u0e25\\u0e37\\u0e48\\u0e2d\\u0e19)\\n   1,420 RPM / 18 kW\\n\\u26a1 \\u0e40\\u0e08\\u0e19\\u0e40\\u0e19\\u0e2d\\u0e40\\u0e23\\u0e40\\u0e15\\u0e2d\\u0e23\\u0e4c MG1 (\\u0e1b\\u0e31\\u0e48\\u0e19\\u0e44\\u0e1f)\\n   980 RPM / 8 kW\\n\\U0001F321\\ufe0f \\u0e2d\\u0e38\\u0e13\\u0e2b\\u0e20\\u0e39\\u0e21\\u0e34\\u0e41\\u0e1a\\u0e15\\u0e44\\u0e2e\\u0e1a\\u0e23\\u0e34\\u0e14 (HV)\\n   35.0 \\u00b0C \\u2022 \\u0e1e\\u0e31\\u0e14\\u0e25\\u0e21 Low";
      [mCard addSubview:ml];
      [self.view addSubview:mCard];
    }
    mCard.hidden = NO;
    mCard.frame = CGRectMake(rightX + 10, topY + 262, rightW - 20, 136);

    // Right Card 3: GPS Trip Computer & Range
    UIView *tCard = [self.view viewWithTag:711];
    if (!tCard) {
      tCard = [[UIView alloc] init];
      tCard.tag = 711;
      tCard.backgroundColor = [UIColor colorWithRed:.06 green:.03 blue:.04 alpha:.92];
      tCard.layer.cornerRadius = 10;
      tCard.layer.borderWidth = 1.0;
      tCard.layer.borderColor = [UIColor colorWithRed:1 green:.3 blue:.3 alpha:.35].CGColor;

      UILabel *tt = [[UILabel alloc] initWithFrame:CGRectMake(8, 6, rightW - 36, 16)];
      tt.tag = 712;
      tt.font = [UIFont boldSystemFontOfSize:10.5];
      tt.textColor = [UIColor colorWithRed:1 green:.4 blue:.4 alpha:1];
      tt.text = @"\\U0001F4CD TRIP COMPUTER & RANGE";
      [tCard addSubview:tt];

      UILabel *tb = [[UILabel alloc] initWithFrame:CGRectMake(8, 24, rightW - 36, 175)];
      tb.tag = 713;
      tb.font = [UIFont boldSystemFontOfSize:10.5];
      tb.textColor = [UIColor whiteColor];
      tb.numberOfLines = 8;
      tb.text = @"\\u0e23\\u0e30\\u0e22\\u0e30\\u0e17\\u0e32\\u0e07\\u0e17\\u0e23\\u0e34\\u0e1b: 18.42 km\\n\\u0e2d\\u0e31\\u0e15\\u0e23\\u0e32\\u0e2a\\u0e34\\u0e49\\u0e19\\u0e40\\u0e1b\\u0e25\\u0e37\\u0e2d\\u0e07: 23.8 km/L\\n\\u0e04\\u0e48\\u0e32\\u0e19\\u0e49\\u0e33\\u0e21\\u0e31\\u0e19\\u0e17\\u0e23\\u0e34\\u0e1b: \\u0e3f 29.80 (PTT GSH95)\\n\\u0e27\\u0e34\\u0e48\\u0e07\\u0e15\\u0e48\\u0e2d\\u0e44\\u0e14\\u0e49: ~520 km\\n\\u0e04\\u0e27\\u0e32\\u0e21\\u0e40\\u0e23\\u0e47\\u0e27\\u0e40\\u0e09\\u0e25\\u0e35\\u0e48\\u0e22: 48.5 km/h\\n\\u0e40\\u0e27\\u0e25\\u0e32\\u0e02\\u0e31\\u0e1a\\u0e02\\u0e35\\u0e48: 00:24:18\\n\\u0e1b\\u0e23\\u0e30\\u0e2b\\u0e22\\u0e31\\u0e14\\u0e19\\u0e49\\u0e33\\u0e21\\u0e31\\u0e19: \\u0e14\\u0e35\\u0e40\\u0e22\\u0e35\\u0e48\\u0e22\\u0e21 (Grade A+)";
      [tCard addSubview:tb];
      [self.view addSubview:tCard];
    }
    tCard.hidden = NO;
    tCard.frame = CGRectMake(rightX + 10, topY + 406, rightW - 20, 206);

    // Bottom Navigation Bar
    self.navigation.hidden = self.focused;
    self.navigation.frame = CGRectMake(0, fullH - 78, w, 78);
    CGFloat nw = (w - 24) / self.navButtons.count;
    for (int i = 0; i < self.navButtons.count; i++) {
      UIButton *b = self.navButtons[i];
      BOOL active = (i == 0);
      b.frame = CGRectMake(12 + i * nw, 9, nw - 4, 60);
      b.backgroundColor = active ? [TRDAccent() colorWithAlphaComponent:.14] : [UIColor clearColor];
      [b viewWithTag:201].frame = CGRectMake(b.bounds.size.width/2 - 42, 16, 26, 26);
      UILabel *t = (UILabel *)[b viewWithTag:202];
      t.font = [UIFont boldSystemFontOfSize:12];
      t.frame = CGRectMake(b.bounds.size.width/2 - 14, 16, nw - 32, 28);
      t.textColor = active ? [UIColor whiteColor] : [UIColor lightGrayColor];
      [b viewWithTag:203].backgroundColor = TRDAccent();
      [b viewWithTag:203].hidden = !active;
      [b viewWithTag:203].frame = CGRectMake(14, 56, b.bounds.size.width - 28, 2);
    }

    // Bring subviews to front for Home Dashboard
    [self.view bringSubviewToFront:self.driveLeftCard];
    [self.view bringSubviewToFront:self.driveRightCard];
    [self.view bringSubviewToFront:self.heading];
    [self.view bringSubviewToFront:self.owner];
    [self.view bringSubviewToFront:self.topClockLabel];
    [self.view bringSubviewToFront:self.obdStatusPill];
    [self.view bringSubviewToFront:self.dayNightPill];
    [self.view bringSubviewToFront:self.thaiVoicePill];
    [self.view bringSubviewToFront:self.settingsPill];
    [self.view bringSubviewToFront:self.readyPill];
    [self.view bringSubviewToFront:self.homeSpeedoDial];
    for (UIButton *b in self.gearButtons) [self.view bringSubviewToFront:b];
    [self.view bringSubviewToFront:self.hybridEcoBar];
    for (UIButton *b in self.driveModePills) [self.view bringSubviewToFront:b];
    [self.view bringSubviewToFront:self.homeAiEcoCard];
    [self.view bringSubviewToFront:self.homeThermalsCard];
    [self.view bringSubviewToFront:self.energyFlowLabel];
    [self.view bringSubviewToFront:self.frontMotorBox];
    [self.view bringSubviewToFront:self.rearBatteryBox];
    [self.view bringSubviewToFront:self.carImage];
    [self.view bringSubviewToFront:self.flowBeamLine];
    [self.view bringSubviewToFront:self.compassLabel];
    [self.view bringSubviewToFront:self.carStatus];
    [self.view bringSubviewToFront:self.nowPanel];
    [self.view bringSubviewToFront:self.artwork];
    [self.view bringSubviewToFront:self.song];
    [self.view bringSubviewToFront:self.artist];
    [self.view bringSubviewToFront:self.trackProgress];
    [self.view bringSubviewToFront:self.trackTime];
    [self.view bringSubviewToFront:self.controls];
    [self.view bringSubviewToFront:self.driveEQ];
    if (pCard) [self.view bringSubviewToFront:pCard];
    [self.view bringSubviewToFront:self.blockGraphView];
    if (deltaL) [self.view bringSubviewToFront:deltaL];
    if (mCard) [self.view bringSubviewToFront:mCard];
    if (tCard) [self.view bringSubviewToFront:tCard];
    [self.view bringSubviewToFront:self.navigation];
  }

  if (self.settingsSheet) {
    self.settingsSheet.frame = self.view.bounds;
    [self.view bringSubviewToFront:self.settingsSheet];
  }
}
`;

src = src.substring(0, startIdx) + newLayoutMethod + "\n" + src.substring(endIdx);

console.log("Writing replaced cardash_main.m...");
fs.writeFileSync('cardash_main.m', src, 'utf8');
fs.writeFileSync('car_dash_live_main.m', src, 'utf8');
console.log("Success! Updated both files.");
