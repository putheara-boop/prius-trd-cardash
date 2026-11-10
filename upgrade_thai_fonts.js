const fs = require('fs');

function upgradeThaiFonts(filePath) {
  let code = fs.readFileSync(filePath, 'utf8');

  // 1. Top Bar Pills (Day/Night, Thai Voice, Settings, OBD2)
  code = code.replace(
    /self\.obdStatusPill\.titleLabel\.font = \[UIFont boldSystemFontOfSize:11\];/g,
    'self.obdStatusPill.titleLabel.font = [UIFont boldSystemFontOfSize:13];'
  );
  code = code.replace(
    /self\.dayNightPill\.titleLabel\.font = \[UIFont boldSystemFontOfSize:11\];/g,
    'self.dayNightPill.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];'
  );
  code = code.replace(
    /self\.thaiVoicePill\.titleLabel\.font = \[UIFont boldSystemFontOfSize:11\];/g,
    'self.thaiVoicePill.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];'
  );
  code = code.replace(
    /self\.settingsPill\.titleLabel\.font = \[UIFont boldSystemFontOfSize:11\];/g,
    'self.settingsPill.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];'
  );

  // Give Top Bar Pills slightly wider frames in HOME mode so larger Thai text fits comfortably
  code = code.replace(
    /curRx -= 104;\s*self\.settingsPill\.hidden = NO;\s*self\.settingsPill\.frame = CGRectMake\(curRx, barY \+ 4, 104, pillH\);\s*curRx -= 96;\s*self\.thaiVoicePill\.hidden = NO;\s*self\.thaiVoicePill\.frame = CGRectMake\(curRx, barY \+ 4, 88, pillH\);\s*curRx -= 66;\s*self\.topClockLabel\.hidden = NO;\s*self\.topClockLabel\.frame = CGRectMake\(curRx, barY \+ 4, 60, pillH\);\s*self\.topClockLabel\.text = \[self\.clockFormat stringFromDate:\[NSDate date\]\];\s*curRx -= 90;\s*self\.dayNightPill\.hidden = NO;\s*self\.dayNightPill\.frame = CGRectMake\(curRx, barY \+ 4, 84, pillH\);\s*curRx -= 144;\s*self\.obdStatusPill\.hidden = NO;\s*self\.obdStatusPill\.frame = CGRectMake\(curRx, barY \+ 4, 138, pillH\);/g,
    `curRx -= 118;
    self.settingsPill.hidden = NO;
    self.settingsPill.frame = CGRectMake(curRx, barY + 4, 118, pillH);

    curRx -= 106;
    self.thaiVoicePill.hidden = NO;
    self.thaiVoicePill.frame = CGRectMake(curRx, barY + 4, 98, pillH);

    curRx -= 70;
    self.topClockLabel.hidden = NO;
    self.topClockLabel.frame = CGRectMake(curRx, barY + 4, 64, pillH);
    self.topClockLabel.text = [self.clockFormat stringFromDate:[NSDate date]];

    curRx -= 104;
    self.dayNightPill.hidden = NO;
    self.dayNightPill.frame = CGRectMake(curRx, barY + 4, 96, pillH);

    curRx -= 154;
    self.obdStatusPill.hidden = NO;
    self.obdStatusPill.frame = CGRectMake(curRx, barY + 4, 146, pillH);`
  );

  // 2. Front Motor Box & Rear Battery Box (หน้ารถ / ท้ายรถ)
  code = code.replace(
    /UILabel \*fmL1 = \[\[UILabel alloc\]initWithFrame:CGRectMake\(6,2,140,12\)\];fmL1\.font=\[UIFont boldSystemFontOfSize:8\.5\];fmL1\.textColor=\[UIColor colorWithWhite:\.6 alpha:1\];fmL1\.text=@"หน้ารถ \(Front Transaxle\)";\[self\.frontMotorBox addSubview:fmL1\];\s*UILabel \*fmL2 = \[\[UILabel alloc\]initWithFrame:CGRectMake\(6,14,140,16\)\];fmL2\.font=\[UIFont boldSystemFontOfSize:10\.5\];fmL2\.textColor=\[UIColor colorWithRed:0 green:\.85 blue:1 alpha:1\];fmL2\.text=@"⚡ MOTOR MG1 \/ MG2";\[self\.frontMotorBox addSubview:fmL2\];/g,
    `UILabel *fmL1 = [[UILabel alloc]initWithFrame:CGRectMake(8,3,172,18)];fmL1.font=[UIFont boldSystemFontOfSize:12.5];fmL1.textColor=[UIColor colorWithWhite:.88 alpha:1];fmL1.text=@"หน้ารถ (ชุดขับเคลื่อนหน้า)";[self.frontMotorBox addSubview:fmL1];
  UILabel *fmL2 = [[UILabel alloc]initWithFrame:CGRectMake(8,21,172,18)];fmL2.font=[UIFont boldSystemFontOfSize:12.5];fmL2.textColor=[UIColor colorWithRed:0 green:.85 blue:1 alpha:1];fmL2.text=@"⚡ MOTOR MG1 / MG2";[self.frontMotorBox addSubview:fmL2];`
  );

  code = code.replace(
    /UILabel \*rbL1 = \[\[UILabel alloc\]initWithFrame:CGRectMake\(6,2,140,12\)\];rbL1\.font=\[UIFont boldSystemFontOfSize:8\.5\];rbL1\.textColor=\[UIColor colorWithWhite:\.6 alpha:1\];rbL1\.textAlignment=NSTextAlignmentRight;rbL1\.text=@"ท้ายรถ \(Rear Battery\)";\[self\.rearBatteryBox addSubview:rbL1\];\s*UILabel \*rbL2 = \[\[UILabel alloc\]initWithFrame:CGRectMake\(6,14,140,16\)\];rbL2\.font=\[UIFont boldSystemFontOfSize:10\.5\];rbL2\.textColor=\[UIColor colorWithRed:\.35 green:\.92 blue:\.45 alpha:1\];rbL2\.textAlignment=NSTextAlignmentRight;rbL2\.text=@"HV BATTERY PACK 🔋";\[self\.rearBatteryBox addSubview:rbL2\];/g,
    `UILabel *rbL1 = [[UILabel alloc]initWithFrame:CGRectMake(8,3,172,18)];rbL1.font=[UIFont boldSystemFontOfSize:12.5];rbL1.textColor=[UIColor colorWithWhite:.88 alpha:1];rbL1.textAlignment=NSTextAlignmentRight;rbL1.text=@"ท้ายรถ (แบตเตอรี่ไฮบริด)";[self.rearBatteryBox addSubview:rbL1];
  UILabel *rbL2 = [[UILabel alloc]initWithFrame:CGRectMake(8,21,172,18)];rbL2.font=[UIFont boldSystemFontOfSize:12.5];rbL2.textColor=[UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];rbL2.textAlignment=NSTextAlignmentRight;rbL2.text=@"HV BATTERY PACK 🔋";[self.rearBatteryBox addSubview:rbL2];`
  );

  code = code.replace(
    /self\.frontMotorBox\.frame = CGRectMake\(centerX \+ 8, topY \+ 42, 160, 36\);\s*self\.rearBatteryBox\.hidden = NO;\s*self\.rearBatteryBox\.frame = CGRectMake\(centerX \+ centerW - 168, topY \+ 42, 160, 36\);/g,
    `self.frontMotorBox.frame = CGRectMake(centerX + 8, topY + 42, 188, 42);

    self.rearBatteryBox.hidden = NO;
    self.rearBatteryBox.frame = CGRectMake(centerX + centerW - 196, topY + 42, 188, 42);`
  );

  // 3. Left Zone: AI Eco Coach Card (`ecoH`, `ecoS`, `ecoD`)
  code = code.replace(
    /UILabel \*ecoH = \[\[UILabel alloc\] initWithFrame:CGRectMake\(10, 8, 230, 18\)\];\s*ecoH\.tag = 501;\s*ecoH\.font = \[UIFont boldSystemFontOfSize:11\];[\s\S]*?\[self\.homeAiEcoCard addSubview:ecoD\];/,
    `UILabel *ecoH = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 214, 20)];
  ecoH.tag = 501;
  ecoH.font = [UIFont boldSystemFontOfSize:12.5];
  ecoH.textColor = [UIColor colorWithRed:.35 green:.92 blue:.45 alpha:1];
  ecoH.text = @"🌱 AI ECO COACH  •  ♻️ +14 Wh";
  [self.homeAiEcoCard addSubview:ecoH];

  UILabel *ecoS = [[UILabel alloc] initWithFrame:CGRectMake(10, 27, 214, 24)];
  ecoS.tag = 502;
  ecoS.font = [UIFont boldSystemFontOfSize:16.5];
  ecoS.textColor = [UIColor whiteColor];
  ecoS.text = @"ECO 92 / 100  [ GRADE A+ ]";
  [self.homeAiEcoCard addSubview:ecoS];

  UILabel *ecoD = [[UILabel alloc] initWithFrame:CGRectMake(10, 52, 214, 118)];
  ecoD.tag = 503;
  ecoD.numberOfLines = 4;
  ecoD.font = [UIFont boldSystemFontOfSize:13.5];
  ecoD.adjustsFontSizeToFitWidth = YES;
  ecoD.minimumScaleFactor = 0.85;
  ecoD.textColor = [UIColor colorWithWhite:0.94 alpha:1];
  ecoD.text = @"• ระบบไฮบริดสมบูรณ์ 100%\\n• คันเร่งนุ่มนวล ประหยัดสูงสุด\\n• ดึงไฟชาร์จกลับ: ดีเยี่ยม\\n• เบรกไฟฟ้า ECB: แรงดันปกติ";
  [self.homeAiEcoCard addSubview:ecoD];`
  );

  // 4. Left Zone: Thermals Card (`tRow1`, `tRow2`, `tRow3`)
  code = code.replace(
    /UILabel \*tRow1 = \[\[UILabel alloc\] initWithFrame:CGRectMake\(10, 10, 230, 48\)\];[\s\S]*?\[self\.homeThermalsCard addSubview:tRow3\];/,
    `UILabel *tRow1 = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 214, 52)];
  tRow1.tag = 601;
  tRow1.numberOfLines = 2;
  tRow1.font = [UIFont boldSystemFontOfSize:14.0];
  tRow1.textColor = [UIColor whiteColor];
  tRow1.text = @"🌡️ น้ำหล่อเย็นเครื่องยนต์\\n     88 °C (เกณฑ์ปกติ)";
  [self.homeThermalsCard addSubview:tRow1];

  UILabel *tRow2 = [[UILabel alloc] initWithFrame:CGRectMake(10, 64, 214, 52)];
  tRow2.tag = 602;
  tRow2.numberOfLines = 2;
  tRow2.font = [UIFont boldSystemFontOfSize:14.0];
  tRow2.textColor = [UIColor colorWithRed:0.65 green:0.92 blue:1.0 alpha:1];
  tRow2.text = @"❄️ แอร์ห้องโดยสาร : 24.5 °C\\n     อินเวอร์เตอร์ : 42 °C";
  [self.homeThermalsCard addSubview:tRow2];

  UILabel *tRow3 = [[UILabel alloc] initWithFrame:CGRectMake(10, 120, 214, 52)];
  tRow3.tag = 603;
  tRow3.numberOfLines = 2;
  tRow3.font = [UIFont boldSystemFontOfSize:14.0];
  tRow3.textColor = [UIColor colorWithRed:.35 green:.95 blue:.50 alpha:1];
  tRow3.text = @"🔋 แบตเตอรี่ 12V : 13.84 V\\n     สถานะชาร์จไฟปกติ";
  [self.homeThermalsCard addSubview:tRow3];`
  );

  // 5. Center Zone: Energy Flow Banner, Compass/Inflow Label, Car Status (Doors & Seatbelt), Multimedia Header
  code = code.replace(
    /self\.energyFlowLabel\.frame = CGRectMake\(centerX \+ 8, topY \+ 8, centerW - 16, 28\);[\s\S]*?self\.energyFlowLabel\.text = @"\\U0001F343 PURE EV DRIVE \(MG2 \\u2013 \\u0e40\\u0e1e\\u0e25\\u0e32\\u0e02\\u0e31\\u0e1a\\u0e2b\\u0e19\\u0e49\\u0e32\) \\u26A1     \\u26A1 \\u0e14\\u0e36\\u0e07\\u0e44\\u0e1f\\u0e08\\u0e32\\u0e01\\u0e41\\u0e1a\\u0e15\\u0e40\\u0e15\\u0e2d\\u0e23\\u0e35\\u0e48 EV";/,
    `self.energyFlowLabel.frame = CGRectMake(centerX + 8, topY + 6, centerW - 16, 32);
    self.energyFlowLabel.font = [UIFont boldSystemFontOfSize:14.0];
    self.energyFlowLabel.layer.cornerRadius = 6;
    self.energyFlowLabel.layer.borderWidth = 1;
    self.energyFlowLabel.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    self.energyFlowLabel.backgroundColor = [UIColor colorWithRed:.02 green:.06 blue:.08 alpha:.95];
    self.energyFlowLabel.text = @"🍃 โหมดไฟฟ้าล้วน EV (เพลาขับหน้า)  ⚡ ดึงไฟจากแบตไฮบริด";`
  );

  code = code.replace(
    /self\.compassLabel\.frame = CGRectMake\(centerX \+ 8, topY \+ 256, centerW - 16, 20\);\s*self\.compassLabel\.font = \[UIFont boldSystemFontOfSize:11\];\s*self\.compassLabel\.textColor = \[UIColor colorWithRed:0 green:\.85 blue:1 alpha:1\];\s*self\.compassLabel\.textAlignment = NSTextAlignmentCenter;\s*self\.compassLabel\.text = @"\\u0e01\\u0e23\\u0e30\\u0e41\\u0e2a\\u0e44\\u0e1f\\u0e44\\u0e2e\\u0e1a\\u0e23\\u0e34\\u0e14: \\u26a1 \\u0e0a\\u0e32\\u0e23\\u0e4c\\u0e08\\u0e44\\u0e1f\\u0e40\\u0e02\\u0e49\\u0e32\\u0e41\\u0e1a\\u0e15\\u0e40\\u0e15\\u0e2d\\u0e23\\u0e35\\u0e48 \(Inflow\)  \+14\.2 kW \(Regen Active\)";/,
    `self.compassLabel.frame = CGRectMake(centerX + 8, topY + 252, centerW - 16, 24);
    self.compassLabel.font = [UIFont boldSystemFontOfSize:14.0];
    self.compassLabel.adjustsFontSizeToFitWidth = YES;
    self.compassLabel.minimumScaleFactor = 0.85;
    self.compassLabel.textColor = [UIColor colorWithRed:0 green:.90 blue:1 alpha:1];
    self.compassLabel.textAlignment = NSTextAlignmentCenter;
    self.compassLabel.text = @"⚡ กระแสไฟไฮบริด: ชาร์จไฟเข้าแบตเตอรี่ +14.2 kW (Regen)";`
  );

  // Also upgrade Drive Mode compassLabel font size
  code = code.replace(
    /self\.compassLabel\.frame = CGRectMake\(centerX \+ 16, topY \+ 490, centerW - 32, 22\);\s*self\.compassLabel\.font = \[UIFont boldSystemFontOfSize:11\.5\];/,
    `self.compassLabel.frame = CGRectMake(centerX + 8, topY + 488, centerW - 16, 26);
    self.compassLabel.font = [UIFont boldSystemFontOfSize:14.0];`
  );

  code = code.replace(
    /self\.carStatus\.frame = CGRectMake\(centerX \+ 8, topY \+ 282, centerW - 16, 28\);\s*self\.carStatus\.font = \[UIFont boldSystemFontOfSize:11\];\s*self\.carStatus\.textColor = \[UIColor colorWithWhite:\.88 alpha:1\];[\s\S]*?self\.carStatus\.text = @"\\U0001F6AA \\u0e1b\\u0e23\\u0e30\\u0e15\\u0e39 5 \\u0e1a\\u0e32\\u0e19: \\u0e1b\\u0e34\\u0e14\\u0e2a\\u0e19\\u0e34\\u0e17 \\u2022 \\U0001F512 \\u0e40\\u0e02\\u0e47\\u0e21\\u0e02\\u0e31\\u0e14\\u0e25\\u0e47\\u0e2d\\u0e04: \\u0e25\\u0e47\\u0e2d\\u0e04\\u0e2d\\u0e22\\u0e39\\u0e48 \(\\u0e41\\u0e15\\u0e30\\u0e40\\u0e1e\\u0e37\\u0e48\\u0e2d\\u0e14\\u0e39\\u0e23\\u0e32\\u0e22\\u0e25\\u0e30\\u0e40\\u0e2d\\u0e35\\u0e22\\u0e14\)";/,
    `self.carStatus.frame = CGRectMake(centerX + 8, topY + 280, centerW - 16, 32);
    self.carStatus.font = [UIFont boldSystemFontOfSize:14.0];
    self.carStatus.adjustsFontSizeToFitWidth = YES;
    self.carStatus.minimumScaleFactor = 0.85;
    self.carStatus.textColor = [UIColor whiteColor];
    self.carStatus.textAlignment = NSTextAlignmentCenter;
    self.carStatus.layer.cornerRadius = 6;
    self.carStatus.layer.borderWidth = 1;
    self.carStatus.layer.borderColor = [UIColor colorWithWhite:.22 alpha:1].CGColor;
    self.carStatus.backgroundColor = [UIColor colorWithRed:.03 green:.06 blue:.09 alpha:.92];
    self.carStatus.text = @"🚪 ประตู 5 บาน: ปิดสนิท  •  🔒 เข็มขัดนิรภัย: ล็อคครบทุกจุด";`
  );

  code = code.replace(
    /mHead = \[\[UILabel alloc\] initWithFrame:CGRectMake\(140, 8, centerW - 160, 16\)\];\s*mHead\.tag = 750;\s*mHead\.font = \[UIFont boldSystemFontOfSize:10\];\s*mHead\.textColor = \[UIColor colorWithRed:0 green:\.85 blue:1 alpha:1\];\s*mHead\.text = @"\\U0001F3B5 CAR MULTIMEDIA & AUDIO         11 \\u0e40\\u0e1e\\u0e25\\u0e07\\u0e43\\u0e19\\u0e40\\u0e04\\u0e23\\u0e37\\u0e48\\u0e2d\\u0e07 \\u2022 JBL EQUALIZER";/,
    `mHead = [[UILabel alloc] initWithFrame:CGRectMake(140, 8, centerW - 164, 20)];
      mHead.tag = 750;
      mHead.font = [UIFont boldSystemFontOfSize:13.0];
      mHead.adjustsFontSizeToFitWidth = YES;
      mHead.minimumScaleFactor = 0.85;
      mHead.textColor = [UIColor colorWithRed:0 green:.88 blue:1 alpha:1];
      mHead.text = @"🎵 เครื่องเสียงรถยนต์ • 11 เพลงในเครื่อง • JBL SOUND";`
  );

  code = code.replace(
    /self\.song\.frame = CGRectMake\(centerX \+ 148, mTop \+ 30, centerW - 168, 30\);\s*self\.song\.font = \[UIFont boldSystemFontOfSize:15\];[\s\S]*?self\.artist\.frame = CGRectMake\(centerX \+ 148, mTop \+ 62, centerW - 168, 20\);\s*self\.artist\.font = \[UIFont systemFontOfSize:12\];/,
    `self.song.frame = CGRectMake(centerX + 148, mTop + 32, centerW - 168, 30);
    self.song.font = [UIFont boldSystemFontOfSize:17.5];
    self.song.textColor = [UIColor whiteColor];

    self.artist.hidden = NO;
    self.artist.frame = CGRectMake(centerX + 148, mTop + 64, centerW - 168, 22);
    self.artist.font = [UIFont boldSystemFontOfSize:13.5];`
  );

  // 6. Right Zone Cards (Card 1: Powertrain & HV, Card 2: Motors & Temps, Card 3: Trip Computer)
  code = code.replace(
    /UILabel \*pt = \[\[UILabel alloc\] initWithFrame:CGRectMake\(8, 6, rightW - 36, 16\)\];[\s\S]*?tCard\.frame = CGRectMake\(rightX \+ 10, topY \+ 406, rightW - 20, 206\);/,
    `UILabel *pt = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, rightW - 36, 20)];
      pt.tag = 702;
      pt.font = [UIFont boldSystemFontOfSize:13.0];
      pt.textColor = [UIColor colorWithRed:0 green:.88 blue:1 alpha:1];
      pt.text = @"⚡ แบตเตอรี่ไฮบริด HV • 7E3";
      [pCard addSubview:pt];

      UILabel *pb = [[UILabel alloc] initWithFrame:CGRectMake(10, 28, rightW - 36, 62)];
      pb.tag = 703;
      pb.font = [UIFont boldSystemFontOfSize:13.5];
      pb.adjustsFontSizeToFitWidth = YES;
      pb.minimumScaleFactor = 0.85;
      pb.textColor = [UIColor whiteColor];
      pb.numberOfLines = 3;
      pb.text = @"ระดับไฟ (SOC): 64.5% (ปกติ)\\nแรงดัน: 227.4 V • ชาร์จ +12.4 A\\n14 บล็อก (28 โมดูล NiMH)";
      [pCard addSubview:pb];
      [self.view addSubview:pCard];
    }
    pCard.hidden = NO;
    pCard.frame = CGRectMake(rightX + 10, topY + 8, rightW - 20, 172);

    self.blockGraphView.hidden = NO;
    self.blockGraphView.frame = CGRectMake(rightX + 18, topY + 100, rightW - 36, 46);

    UILabel *deltaL = (UILabel *)[self.view viewWithTag:706];
    if (!deltaL) {
      deltaL = [[UILabel alloc] init];
      deltaL.tag = 706;
      deltaL.font = [UIFont boldSystemFontOfSize:12.0];
      deltaL.adjustsFontSizeToFitWidth = YES;
      deltaL.minimumScaleFactor = 0.85;
      deltaL.textColor = [UIColor colorWithRed:.35 green:.95 blue:.55 alpha:1];
      deltaL.text = @"ΔV: 0.02V (สมดุลดี) • 16.22–16.24V";
      [self.view addSubview:deltaL];
    }
    deltaL.hidden = NO;
    deltaL.frame = CGRectMake(rightX + 18, topY + 150, rightW - 36, 20);

    // Right Card 2: 3 Motor Rows
    UIView *mCard = [self.view viewWithTag:707];
    if (!mCard) {
      mCard = [[UIView alloc] init];
      mCard.tag = 707;
      mCard.backgroundColor = [UIColor colorWithRed:.02 green:.04 blue:.06 alpha:.95];
      mCard.layer.cornerRadius = 10;
      mCard.layer.borderWidth = 1.0;
      mCard.layer.borderColor = [UIColor colorWithWhite:.20 alpha:1].CGColor;

      UILabel *ml = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, rightW - 36, 174)];
      ml.tag = 708;
      ml.font = [UIFont boldSystemFontOfSize:13.5];
      ml.adjustsFontSizeToFitWidth = YES;
      ml.minimumScaleFactor = 0.85;
      ml.textColor = [UIColor whiteColor];
      ml.numberOfLines = 6;
      ml.text = @"⚙️ มอเตอร์ขับเคลื่อน MG2\\n     1,420 RPM  •  กำลัง 18 kW\\n⚡ มอเตอร์ปั่นไฟ MG1\\n     980 RPM  •  ชาร์จ 8 kW\\n🌡️ อุณหภูมิแบตไฮบริด (HV)\\n     35.0 °C  •  พัดลมแบต: ปกติ";
      [mCard addSubview:ml];
      [self.view addSubview:mCard];
    }
    mCard.hidden = NO;
    mCard.frame = CGRectMake(rightX + 10, topY + 188, rightW - 20, 190);

    // Right Card 3: GPS Trip Computer & Range
    UIView *tCard = [self.view viewWithTag:711];
    if (!tCard) {
      tCard = [[UIView alloc] init];
      tCard.tag = 711;
      tCard.backgroundColor = [UIColor colorWithRed:.06 green:.03 blue:.04 alpha:.95];
      tCard.layer.cornerRadius = 10;
      tCard.layer.borderWidth = 1.0;
      tCard.layer.borderColor = [UIColor colorWithRed:1 green:.3 blue:.3 alpha:.40].CGColor;

      UILabel *tt = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, rightW - 36, 20)];
      tt.tag = 712;
      tt.font = [UIFont boldSystemFontOfSize:13.0];
      tt.textColor = [UIColor colorWithRed:1 green:.45 blue:.45 alpha:1];
      tt.text = @"📍 ข้อมูลการเดินทาง (TRIP & RANGE)";
      [tCard addSubview:tt];

      UILabel *tb = [[UILabel alloc] initWithFrame:CGRectMake(10, 30, rightW - 36, 188)];
      tb.tag = 713;
      tb.font = [UIFont boldSystemFontOfSize:13.5];
      tb.adjustsFontSizeToFitWidth = YES;
      tb.minimumScaleFactor = 0.85;
      tb.textColor = [UIColor whiteColor];
      tb.numberOfLines = 7;
      tb.text = @"ระยะทางทริป: 18.42 km\\nอัตราสิ้นเปลือง: 23.8 km/L\\nค่าน้ำมันทริป: ฿ 29.80 (GSH95)\\nวิ่งต่อได้อีก: ~520 km\\nความเร็วเฉลี่ย: 48.5 km/h\\nเวลาขับขี่: 00:24:18 ชม.\\nความประหยัด: ดีเยี่ยม (A+)";
      [tCard addSubview:tb];
      [self.view addSubview:tCard];
    }
    tCard.hidden = NO;
    tCard.frame = CGRectMake(rightX + 10, topY + 386, rightW - 20, 226);`
  );

  // 7. Also increase CarPlay Telemetry Thai Trip Metrics font size (`self.tripMetricsLabel`) from 11.5pt to 13.5pt
  code = code.replace(
    /self\.tripMetricsLabel = \[\[UILabel alloc\] initWithFrame:CGRectMake\(20, 172, 334, 48\)\];\s*self\.tripMetricsLabel\.numberOfLines = 2;\s*self\.tripMetricsLabel\.font = \[UIFont boldSystemFontOfSize:11\.5\];/,
    `self.tripMetricsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 168, 334, 54)];
    self.tripMetricsLabel.numberOfLines = 2;
    self.tripMetricsLabel.font = [UIFont boldSystemFontOfSize:13.5];
    self.tripMetricsLabel.adjustsFontSizeToFitWidth = YES;
    self.tripMetricsLabel.minimumScaleFactor = 0.85;`
  );

  fs.writeFileSync(filePath, code, 'utf8');
  console.log('Successfully upgraded Thai fonts in', filePath);
}

upgradeThaiFonts('cardash_main.m');
upgradeThaiFonts('car_dash_live_main.m');
