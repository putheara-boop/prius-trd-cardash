const fs = require('fs');

let content = fs.readFileSync('cardash_main.m', 'utf8');

const startIdx = content.indexOf('else if(!self.musicMode&&!self.mapMode&&!self.tripMode&&!self.carplayMode){', 127000);
let open = 0, endIdx = -1;
for (let i = startIdx; i < content.length; i++) {
  if (content[i] === '{') open++;
  else if (content[i] === '}') {
    open--;
    if (open === 0) {
      endIdx = i + 1;
      break;
    }
  }
}

const newBringBlock = `else if(!self.musicMode&&!self.mapMode&&!self.tripMode&&!self.carplayMode){
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
  [self.view bringSubviewToFront:self.speed];
  [self.view bringSubviewToFront:self.unit];
  [self.view bringSubviewToFront:self.speedLimitBtn];
  [self.view bringSubviewToFront:self.gearBadge];
  for(UIButton *b in self.gearButtons) [self.view bringSubviewToFront:b];
  [self.view bringSubviewToFront:self.hybridEcoBar];
  for(UIButton *b in self.driveModePills) [self.view bringSubviewToFront:b];
  [self.view bringSubviewToFront:self.brakeStatusCard];
  [self.view bringSubviewToFront:self.hybridSocCard];
  [self.view bringSubviewToFront:self.energyFlowLabel];
  [self.view bringSubviewToFront:self.frontMotorBox];
  [self.view bringSubviewToFront:self.rearBatteryBox];
  [self.view bringSubviewToFront:self.carImage];
  [self.view bringSubviewToFront:self.flowBeamLine];
  [self.view bringSubviewToFront:self.compassLabel];
  [self.view bringSubviewToFront:self.carStatus];
  [self.view bringSubviewToFront:self.nowPanel];
  [self.view bringSubviewToFront:self.artwork];
  [self.view bringSubviewToFront:self.artPlaceholder];
  [self.view bringSubviewToFront:self.sourceBadge];
  [self.view bringSubviewToFront:self.song];
  [self.view bringSubviewToFront:self.artist];
  [self.view bringSubviewToFront:self.trackProgress];
  [self.view bringSubviewToFront:self.trackTime];
  [self.view bringSubviewToFront:self.driveEQ];
  [self.view bringSubviewToFront:self.controls];
  UIView *pCard = [self.view viewWithTag:701]; if(pCard) [self.view bringSubviewToFront:pCard];
  [self.view bringSubviewToFront:self.blockGraphView];
  UIView *deltaL = [self.view viewWithTag:706]; if(deltaL) [self.view bringSubviewToFront:deltaL];
  UIView *mCard = [self.view viewWithTag:707]; if(mCard) [self.view bringSubviewToFront:mCard];
  UIView *tCard = [self.view viewWithTag:711]; if(tCard) [self.view bringSubviewToFront:tCard];
  [self.view bringSubviewToFront:self.navigation];
 }`;

content = content.slice(0, startIdx) + newBringBlock + content.slice(endIdx);

fs.writeFileSync('cardash_main.m', content, 'utf8');
fs.writeFileSync('car_dash_live_main.m', content, 'utf8');
console.log('Successfully updated bringSubviewToFront at exact location!');
