const fs = require('fs');

['cardash_main.m', 'car_dash_live_main.m'].forEach(file => {
  let s = fs.readFileSync(file, 'utf8');

  // Fix openMap to cleanly reset carplayMode and carplayGridMode
  const oldOpenMap = `-(void)openMap{self.tripMode=NO;self.driveMode=NO;self.musicMode=NO;self.focused=NO;self.returnTap.enabled=NO;[self.driveCar stop];self.mapMode=YES;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];UIView *p=[self.view viewWithTag:701];if(p)p.hidden=YES;UIView *t=[self.view viewWithTag:711];if(t)t.hidden=YES;[self ensureMapWebView];[self.view setNeedsLayout];if(!self.mapWebView.request)[self loadMapHTML];[self updateMapCar];}`;

  const newOpenMap = `-(void)openMap{self.tripMode=NO;self.driveMode=NO;self.musicMode=NO;self.focused=NO;self.carplayMode=NO;self.carplayGridMode=NO;self.returnTap.enabled=NO;[self.driveCar stop];self.mapMode=YES;[self.driveButton setTitle:@"DRIVE MODE" forState:UIControlStateNormal];UIView *p=[self.view viewWithTag:701];if(p)p.hidden=YES;UIView *t=[self.view viewWithTag:711];if(t)t.hidden=YES;[self ensureMapWebView];[self.view setNeedsLayout];if(!self.mapWebView.request)[self loadMapHTML];else [self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.map){window.map.invalidateSize(); if(window.recenter)window.recenter(); }"];[self updateMapCar];}`;

  if (!s.includes(oldOpenMap)) {
    console.error("ERROR: oldOpenMap not found in " + file);
    process.exit(1);
  }
  s = s.replace(oldOpenMap, newOpenMap);

  // In viewDidLayoutSubviews mapMode block, add invalidateSize call
  s = s.replace('if (self.mapWebView) self.mapWebView.frame = self.mapContainer.bounds;',
    'if (self.mapWebView) { self.mapWebView.frame = self.mapContainer.bounds; [self.mapWebView stringByEvaluatingJavaScriptFromString:@"if(window.map){window.map.invalidateSize(); if(window.recenter)window.recenter(); }"]; }');

  fs.writeFileSync(file, s, 'utf8');
});

console.log("Done fixing openMap logic!");
