const fs = require('fs');

console.log("Reading cardash_main.m...");
let src = fs.readFileSync('cardash_main.m', 'utf8');

// 1. Fix carplayGridMode button layout
const oldGridBlock = `    if (self.carplayGridMode) {
      self.mapContainer.hidden = YES;
      self.carplayMediaWidget.hidden = YES;
      self.carplayTelemetryWidget.hidden = YES;
      self.carplayAppGrid.hidden = NO;
      self.carplayAppGrid.frame = CGRectMake(76, 0, w - 76, fullH);
      [self.view bringSubviewToFront:self.carplayAppGrid];
    } else {`;

const newGridBlock = `    if (self.carplayGridMode) {
      self.mapContainer.hidden = YES;
      self.carplayMediaWidget.hidden = YES;
      self.carplayTelemetryWidget.hidden = YES;
      self.carplayAppGrid.hidden = NO;
      self.carplayAppGrid.frame = CGRectMake(76, 0, w - 76, fullH);

      CGFloat colW = 180, rowH = 170, gapX = 36, gapY = 40;
      CGFloat startX = (w - 76 - (4 * colW + 3 * gapX)) / 2.0;
      CGFloat startY = (fullH - (2 * rowH + gapY)) / 2.0;
      for (int i = 0; i < self.carplayGridButtons.count; i++) {
        UIView *gb = self.carplayGridButtons[i];
        int col = i % 4, row = i / 4;
        gb.frame = CGRectMake(startX + col * (colW + gapX), startY + row * (rowH + gapY), colW, rowH);
        UIView *ib = [gb viewWithTag:101];
        CGFloat iconSize = 80;
        ib.frame = CGRectMake((colW - iconSize) / 2.0, 16, iconSize, iconSize);
        UILabel *gt = (UILabel *)[gb viewWithTag:102];
        gt.frame = CGRectMake(8, 110, colW - 16, 28);
        gt.font = [UIFont boldSystemFontOfSize:16];
        gt.textColor = [UIColor whiteColor];
      }
      [self.view bringSubviewToFront:self.carplayAppGrid];
    } else {`;

if (!src.includes(oldGridBlock)) {
  console.error("ERROR: oldGridBlock not found!");
  process.exit(1);
}
src = src.replace(oldGridBlock, newGridBlock);

// 2. Add mapMode layout block in viewDidLayoutSubviews
const mapModeLayout = `
  if (self.mapMode) {
    [self hideAllHomeWidgets:YES];
    [self hideAllDriveWidgets:YES];
    self.carplayDock.hidden = YES;
    self.carplayMediaWidget.hidden = YES;
    self.carplayTelemetryWidget.hidden = YES;
    self.carplayAppGrid.hidden = YES;
    self.navigation.hidden = NO;

    // Top Bar (Width: 1024, Height: 48)
    self.heading.hidden = NO;
    self.heading.frame = CGRectMake(16, 12, 380, 24);
    self.heading.font = [UIFont boldSystemFontOfSize:15];
    self.heading.textColor = [UIColor whiteColor];
    self.heading.text = @"PRIUS TRD SPORTIVO • MAP NAVIGATION";

    UIView *obdB = [self.view viewWithTag:702];
    if (obdB) { obdB.hidden = NO; obdB.frame = CGRectMake(w - 530, 10, 115, 28); }
    UIView *nightB = [self.view viewWithTag:703];
    if (nightB) { nightB.hidden = NO; nightB.frame = CGRectMake(w - 405, 10, 75, 28); }
    self.clock.hidden = NO;
    self.clock.frame = CGRectMake(w - 320, 10, 80, 28);
    self.clock.font = [UIFont boldSystemFontOfSize:15];
    self.clock.textColor = [UIColor whiteColor];
    self.clock.textAlignment = NSTextAlignmentCenter;
    self.clock.backgroundColor = [UIColor colorWithRed:.06 green:.08 blue:.12 alpha:.9];
    self.clock.layer.cornerRadius = 6;
    self.clock.clipsToBounds = YES;
    UIView *thaiB = [self.view viewWithTag:704];
    if (thaiB) { thaiB.hidden = NO; thaiB.frame = CGRectMake(w - 230, 10, 95, 28); }
    UIView *setB = [self.view viewWithTag:705];
    if (setB) { setB.hidden = NO; setB.frame = CGRectMake(w - 125, 10, 110, 28); }

    // Map Container (Takes full width and height between Top Bar and Bottom Dock)
    CGFloat mapTop = 48;
    CGFloat navH = 68;
    CGFloat mapH = fullH - mapTop - navH - 12;
    self.mapContainer.hidden = NO;
    self.mapContainer.frame = CGRectMake(14, mapTop, w - 28, mapH);
    self.mapContainer.layer.cornerRadius = 16;
    self.mapContainer.layer.borderWidth = 1.2;
    self.mapContainer.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
    self.mapContainer.clipsToBounds = YES;
    if (self.mapWebView) self.mapWebView.frame = self.mapContainer.bounds;

    // Bottom Navigation Bar
    self.navigation.frame = CGRectMake(14, fullH - navH - 6, w - 28, navH);
    self.navigation.layer.cornerRadius = 14;
    self.navigation.clipsToBounds = YES;
    CGFloat btnW = (w - 28 - 14) / (CGFloat)self.navButtons.count;
    for (int i = 0; i < self.navButtons.count; i++) {
      UIButton *b = self.navButtons[i];
      b.frame = CGRectMake(7 + i * btnW, 4, btnW - 6, navH - 8);
      DashIcon *icon = (DashIcon *)[b viewWithTag:201];
      icon.frame = CGRectMake((btnW - 6 - 24) / 2.0, 8, 24, 24);
      UILabel *lbl = (UILabel *)[b viewWithTag:202];
      lbl.frame = CGRectMake(0, 34, btnW - 6, 20);
      lbl.font = [UIFont boldSystemFontOfSize:11.5];
      lbl.textAlignment = NSTextAlignmentCenter;
      UIView *line = [b viewWithTag:203];
      line.frame = CGRectMake(8, navH - 12, btnW - 22, 2.5);
      line.hidden = (b.tag != 62); // Highlight MAPS button
    }

    [self.view bringSubviewToFront:self.mapContainer];
    [self.view bringSubviewToFront:self.navigation];
    if (self.settingsSheet) {
      self.settingsSheet.frame = self.view.bounds;
      [self.view bringSubviewToFront:self.settingsSheet];
    }
    return;
  }
`;

const driveModeCheck = `  if (self.driveMode) {`;
if (!src.includes(driveModeCheck)) {
  console.error("ERROR: driveModeCheck not found!");
  process.exit(1);
}
src = src.replace(driveModeCheck, mapModeLayout + "\n" + driveModeCheck);

console.log("Writing files...");
fs.writeFileSync('cardash_main.m', src, 'utf8');
fs.writeFileSync('car_dash_live_main.m', src, 'utf8');
console.log("Done applying Map & Grid fixes!");
