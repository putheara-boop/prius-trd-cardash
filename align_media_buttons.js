const fs = require('fs');

function alignMediaButtons(filePath) {
  let code = fs.readFileSync(filePath, 'utf8');

  code = code.replace(
    /\/\/ Multimedia Console[\s\S]*?if\(mHead\) mHead\.hidden = NO;/,
    `// Multimedia Console
    CGFloat mTop = topY + 318;
    CGFloat mH = colH - 318; // 302px -> bottom is topY + 620, 100% aligned with left & right columns
    self.nowPanel.hidden = NO;
    self.nowPanel.frame = CGRectMake(centerX + 8, mTop, centerW - 16, mH);
    self.nowPanel.layer.cornerRadius = 14;
    self.nowPanel.layer.borderWidth = 1.2;
    self.nowPanel.layer.borderColor = [UIColor colorWithWhite:.18 alpha:1].CGColor;
    self.nowPanel.backgroundColor = [UIColor colorWithRed:.03 green:.06 blue:.09 alpha:.95];

    self.artwork.hidden = NO;
    self.artwork.frame = CGRectMake(centerX + 22, mTop + 20, 148, 148);
    self.artwork.layer.cornerRadius = 12;
    self.artPlaceholder.frame = self.artwork.frame;
    self.artPlaceholder.hidden = (self.artwork.image != nil);

    UILabel *mHead = (UILabel *)[self.nowPanel viewWithTag:750];
    if (!mHead) {
      mHead = [[UILabel alloc] initWithFrame:CGRectMake(170, 18, centerW - 196, 22)];
      mHead.tag = 750;
      mHead.font = [UIFont boldSystemFontOfSize:13.0];
      mHead.adjustsFontSizeToFitWidth = YES;
      mHead.minimumScaleFactor = 0.85;
      mHead.textColor = [UIColor colorWithRed:0 green:.88 blue:1 alpha:1];
      mHead.text = @"🎵 เครื่องเสียงรถยนต์ • 11 เพลงในเครื่อง • JBL SOUND";
      [self.nowPanel addSubview:mHead];
    }
    mHead.frame = CGRectMake(170, 18, centerW - 196, 22);

    self.song.hidden = NO;
    self.song.frame = CGRectMake(centerX + 184, mTop + 48, centerW - 204, 34);
    self.song.font = [UIFont boldSystemFontOfSize:20.0];
    self.song.textColor = [UIColor whiteColor];

    self.artist.hidden = NO;
    self.artist.frame = CGRectMake(centerX + 184, mTop + 86, centerW - 204, 24);
    self.artist.font = [UIFont boldSystemFontOfSize:14.5];
    self.artist.textColor = [UIColor colorWithWhite:0.72 alpha:1];

    self.trackProgress.hidden = NO;
    self.trackProgress.frame = CGRectMake(centerX + 184, mTop + 128, centerW - 204, 4);

    self.trackTime.hidden = NO;
    self.trackTime.frame = CGRectMake(centerX + 184, mTop + 138, centerW - 204, 20);
    self.trackTime.font = [UIFont boldSystemFontOfSize:12.0];
    self.trackTime.textColor = [UIColor colorWithWhite:0.75 alpha:1];
    self.trackTime.textAlignment = NSTextAlignmentRight;

    CGFloat btnY = mTop + mH - 76; // 60px high buttons, 16px from card bottom -> bottoms align with side cards!
    CGFloat btnH = 60;
    self.controls.hidden = NO;
    self.controls.frame = CGRectMake(centerX + 22, btnY, 300, btnH);
    CGFloat cw = 290 / 3.0;
    for (int i = 0; i < 3; i++) {
      UIView *b = [self.controls viewWithTag:20 + i];
      b.frame = CGRectMake(i * (cw + 5), 0, cw, btnH);
      b.layer.cornerRadius = 10;
      if (i == 1) {
        b.backgroundColor = [UIColor colorWithRed:.0 green:.72 blue:.40 alpha:1];
        b.layer.borderColor = [UIColor colorWithRed:.2 green:.9 blue:.5 alpha:1].CGColor;
      } else {
        b.backgroundColor = [UIColor colorWithWhite:.12 alpha:1];
        b.layer.borderColor = [UIColor colorWithWhite:.24 alpha:1].CGColor;
      }
      [b viewWithTag:105].frame = CGRectMake((cw - 28)/2, (btnH - 28)/2, 28, 28);
    }

    self.driveEQ.hidden = NO;
    self.driveEQ.frame = CGRectMake(centerX + 330, btnY, centerW - 352, btnH);
    self.driveEQ.layer.cornerRadius = 10;
    self.driveEQ.layer.borderWidth = 1.2;
    self.driveEQ.layer.borderColor = [UIColor colorWithRed:0 green:.85 blue:1 alpha:.5].CGColor;
    self.driveEQ.backgroundColor = [UIColor colorWithRed:.04 green:.12 blue:.18 alpha:1];
    [self.driveEQ setTitle:@"\U0001F39B\U0000FE0F JBL EQ" forState:UIControlStateNormal];
    [self.driveEQ setTitleColor:[UIColor colorWithRed:0 green:.9 blue:1 alpha:1] forState:UIControlStateNormal];
    self.driveEQ.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
    if(mHead) mHead.hidden = NO;`
  );

  fs.writeFileSync(filePath, code, 'utf8');
  console.log('Aligned media buttons to bottom in', filePath);
}

alignMediaButtons('cardash_main.m');
alignMediaButtons('car_dash_live_main.m');
