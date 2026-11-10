const fs = require('fs');

function polishThaiLabels(filePath) {
  let code = fs.readFileSync(filePath, 'utf8');

  // 1. Fix ecoS ("ECO 92 / 100  [ GRADE A+ ]") so it never truncates
  code = code.replace(
    /UILabel \*ecoS = \[\[UILabel alloc\] initWithFrame:CGRectMake\(10, 27, 214, 24\)\];\s*ecoS\.tag = 502;\s*ecoS\.font = \[UIFont boldSystemFontOfSize:16\.5\];\s*ecoS\.textColor = \[UIColor whiteColor\];\s*ecoS\.text = @"ECO 92 \/ 100  \[ GRADE A\+ \]";/,
    `UILabel *ecoS = [[UILabel alloc] initWithFrame:CGRectMake(10, 27, 214, 24)];
  ecoS.tag = 502;
  ecoS.font = [UIFont boldSystemFontOfSize:15.5];
  ecoS.adjustsFontSizeToFitWidth = YES;
  ecoS.minimumScaleFactor = 0.85;
  ecoS.textColor = [UIColor whiteColor];
  ecoS.text = @"ECO 92 / 100  [ GRADE A+ ]";`
  );

  // 2. Fix tt ("📍 ข้อมูลการเดินทาง (TRIP & RANGE)") so it never truncates
  code = code.replace(
    /UILabel \*tt = \[\[UILabel alloc\] initWithFrame:CGRectMake\(10, 8, rightW - 36, 20\)\];\s*tt\.tag = 712;\s*tt\.font = \[UIFont boldSystemFontOfSize:13\.0\];\s*tt\.textColor = \[UIColor colorWithRed:1 green:\.45 blue:\.45 alpha:1\];\s*tt\.text = @"📍 ข้อมูลการเดินทาง \(TRIP & RANGE\)";/,
    `UILabel *tt = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, rightW - 36, 20)];
      tt.tag = 712;
      tt.font = [UIFont boldSystemFontOfSize:13.0];
      tt.adjustsFontSizeToFitWidth = YES;
      tt.minimumScaleFactor = 0.85;
      tt.textColor = [UIColor colorWithRed:1 green:.45 blue:.45 alpha:1];
      tt.text = @"📍 ข้อมูลการเดินทาง • TRIP";`
  );

  // 3. Fix self.driveEQ button title visibility (UIButtonTypeSystem -> UIButtonTypeCustom, clear tintColor)
  code = code.replace(
    /self\.driveEQ=\[UIButton buttonWithType:UIButtonTypeSystem\];/,
    'self.driveEQ=[UIButton buttonWithType:UIButtonTypeCustom];'
  );
  code = code.replace(
    /NSString \*eqTitle=\[NSString stringWithFormat:@"EQ • %@",\[pName uppercaseString\]\];\s*if\(!\[self\.driveEQ\.currentTitle isEqualToString:eqTitle\]\)\[self\.driveEQ setTitle:eqTitle forState:UIControlStateNormal\];/,
    `NSString *eqTitle=[NSString stringWithFormat:@"🎚️ EQ • %@",[pName uppercaseString]];
 if(![self.driveEQ.currentTitle isEqualToString:eqTitle]){
  [self.driveEQ setTitle:eqTitle forState:UIControlStateNormal];
  [self.driveEQ setTitleColor:[UIColor colorWithRed:0 green:.92 blue:1 alpha:1] forState:UIControlStateNormal];
 }`
  );

  fs.writeFileSync(filePath, code, 'utf8');
  console.log('Polished Thai labels & EQ button in', filePath);
}

polishThaiLabels('cardash_main.m');
polishThaiLabels('car_dash_live_main.m');
