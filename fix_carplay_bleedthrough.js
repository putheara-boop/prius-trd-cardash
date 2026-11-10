const fs = require('fs');

console.log("Reading cardash_main.m...");
let src = fs.readFileSync('cardash_main.m', 'utf8');

// 1. Add hideAllHomeWidgets & hideAllDriveWidgets methods to Dashboard
const helperMethods = `
-(void)hideAllHomeWidgets:(BOOL)hide {
  self.homeSpeedoDial.hidden = hide;
  self.homeAiEcoCard.hidden = hide;
  self.homeThermalsCard.hidden = hide;
  self.driveLeftCard.hidden = hide;
  self.driveRightCard.hidden = hide;
  self.readyPill.hidden = hide;
  self.gearBadge.hidden = YES;
  for (UIButton *b in self.gearButtons) b.hidden = hide;
  self.hybridEcoBar.hidden = hide;
  for (UIButton *b in self.driveModePills) b.hidden = hide;
  self.frontMotorBox.hidden = hide;
  self.rearBatteryBox.hidden = hide;
  self.flowBeamLine.hidden = hide;
  self.blockGraphView.hidden = hide;
  self.topClockLabel.hidden = hide;
  self.obdStatusPill.hidden = hide;
  self.dayNightPill.hidden = hide;
  self.thaiVoicePill.hidden = hide;
  self.settingsPill.hidden = hide;
  self.carImage.hidden = hide;
  self.compassLabel.hidden = hide;
  self.carStatus.hidden = hide;
  self.energyFlowLabel.hidden = hide;
  self.speed.hidden = YES;
  self.unit.hidden = YES;
  self.speedLimitBtn.hidden = YES;
  self.arc.hidden = YES;
  self.progress.hidden = YES;
  self.brakeStatusCard.hidden = YES;
  self.hybridSocCard.hidden = YES;
  self.nowPanel.hidden = hide;
  UIView *pCard = [self.view viewWithTag:701]; if (pCard) pCard.hidden = hide;
  UIView *deltaL = [self.view viewWithTag:706]; if (deltaL) deltaL.hidden = hide;
  UIView *mCard = [self.view viewWithTag:707]; if (mCard) mCard.hidden = hide;
  UIView *tCard = [self.view viewWithTag:711]; if (tCard) tCard.hidden = hide;
  UIView *mH = [self.nowPanel viewWithTag:750]; if (mH) mH.hidden = hide;
}

-(void)hideAllDriveWidgets:(BOOL)hide {
  self.driveSpeedoDial.hidden = hide;
  self.driveShifter.hidden = hide;
  self.drivePowerMeter.hidden = hide;
  self.drive3DGrid.hidden = hide;
  self.driveClockCard.hidden = hide;
  self.driveBatteryCard.hidden = hide;
  self.driveTripCard.hidden = hide;
  self.driveEqBtn.hidden = hide;
  self.driveExitBtn.hidden = hide;
  self.driveCar.hidden = hide;
  self.driveCameraButton.hidden = hide;
  self.radioButton.hidden = hide;
}
`;

// Insert helpers before viewDidLayoutSubviews
const vdlMarker = '-(void)viewDidLayoutSubviews{';
src = src.replace(vdlMarker, helperMethods + "\n" + vdlMarker);

// 2. Now let's update viewDidLayoutSubviews to use these helpers properly
// In CarPlay mode:
const oldCarplayCheck = `  if (self.carplayMode) {
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
    self.driveTripCard.hidden = YES; self.driveEqBtn.hidden = YES; self.driveExitBtn.hidden = YES;`;

const newCarplayCheck = `  if (self.carplayMode) {
    [self hideAllHomeWidgets:YES];
    [self hideAllDriveWidgets:YES];
    self.navigation.hidden = YES;
    self.heading.hidden = YES;
    self.owner.hidden = YES;
    self.clock.hidden = YES;
    self.date.hidden = YES;
    self.nowPanel.hidden = YES;
    self.driveEQ.hidden = YES;
    self.miniPlayer.hidden = YES;
    self.tripButton.hidden = YES;`;

src = src.replace(oldCarplayCheck, newCarplayCheck);

// And bring CarPlay views to front
const carplayReturn = `      CGFloat telY = 12 + mediaH + 12, telH = fullH - 24 - mediaH - 12;
      self.carplayTelemetryCard.frame = CGRectMake(rx, telY, rw, telH);
    }
    return;
  }`;

const newCarplayReturn = `      CGFloat telY = 12 + mediaH + 12, telH = fullH - 24 - mediaH - 12;
      self.carplayTelemetryCard.frame = CGRectMake(rx, telY, rw, telH);

      [self.view bringSubviewToFront:self.mapContainer];
      [self.view bringSubviewToFront:self.carplayMediaCard];
      [self.view bringSubviewToFront:self.carplayTelemetryCard];
      [self.view bringSubviewToFront:self.artwork];
      [self.view bringSubviewToFront:self.song];
      [self.view bringSubviewToFront:self.artist];
      [self.view bringSubviewToFront:self.trackProgress];
      [self.view bringSubviewToFront:self.trackTime];
      [self.view bringSubviewToFront:self.controls];
    }
    [self.view bringSubviewToFront:self.carplayDock];
    if (self.settingsSheet) {
      self.settingsSheet.frame = self.view.bounds;
      [self.view bringSubviewToFront:self.settingsSheet];
    }
    return;
  }`;

src = src.replace(carplayReturn, newCarplayReturn);

// In Drive Mode:
const oldDriveHide = `  if (self.driveMode) {
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
    UIView *tCard = [self.view viewWithTag:711]; if (tCard) tCard.hidden = YES;`;

const newDriveHide = `  if (self.driveMode) {
    // =========================================================================
    // DRIVE MODE (100% Matching prius_drive_mode_concept.jpg)
    // =========================================================================
    [self hideAllHomeWidgets:YES];
    self.mapContainer.hidden = YES;
    self.carplayDock.hidden = YES;
    self.carplayMediaCard.hidden = YES;
    self.carplayTelemetryCard.hidden = YES;
    self.carplayAppGrid.hidden = YES;
    self.navigation.hidden = YES;
    self.nowPanel.hidden = NO;`;

src = src.replace(oldDriveHide, newDriveHide);

// In Home Mode:
const oldHomeHide = `  } else {
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
    self.speedLimitBtn.hidden = YES;`;

const newHomeHide = `  } else {
    // =========================================================================
    // HOME DASHBOARD (100% Matching dashboard.html / media_1794267643239_0594d895.jpg)
    // =========================================================================
    [self hideAllDriveWidgets:YES];
    [self hideAllHomeWidgets:NO];
    self.mapContainer.hidden = YES;
    self.carplayDock.hidden = YES;
    self.carplayMediaCard.hidden = YES;
    self.carplayTelemetryCard.hidden = YES;
    self.carplayAppGrid.hidden = YES;
    self.clock.hidden = YES;
    self.date.hidden = YES;`;

src = src.replace(oldHomeHide, newHomeHide);

console.log("Writing cardash_main.m & car_dash_live_main.m...");
fs.writeFileSync('cardash_main.m', src, 'utf8');
fs.writeFileSync('car_dash_live_main.m', src, 'utf8');
console.log("Updated both files successfully.");
