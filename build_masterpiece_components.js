const fs = require('fs');

console.log("Reading cardash_main.m...");
let src = fs.readFileSync('cardash_main.m', 'utf8');

// Backup
fs.writeFileSync('backup_pre_cockpit_redesign/cardash_main_before_masterpiece.m', src, 'utf8');
console.log("Saved backup.");

// 1. Define custom classes before @interface Dashboard
const customClasses = `
// ============================================================================
// PRIUS TRD MASTERPIECE UI COMPONENTS (Pure CoreGraphics / iOS 9.3.6 Compatible)
// ============================================================================

@interface TRDAnalogSpeedoDial : UIView
@property (nonatomic, assign) BOOL driveStyle;
@property (nonatomic, assign) CGFloat speed;
@property (nonatomic, copy) NSString *gear;
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) UIView *gearBadge;
@property (nonatomic, strong) UILabel *unitLabel;
@property (nonatomic, strong) UIButton *speedLimitBadge;
@end

@implementation TRDAnalogSpeedoDial
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = YES;
    self.clipsToBounds = NO;
    
    self.speedLabel = [[UILabel alloc] init];
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:52] ?: [UIFont boldSystemFontOfSize:52];
    self.speedLabel.textColor = [UIColor whiteColor];
    self.speedLabel.textAlignment = NSTextAlignmentCenter;
    self.speedLabel.text = @"0";
    [self addSubview:self.speedLabel];
    
    self.unitLabel = [[UILabel alloc] init];
    self.unitLabel.font = [UIFont boldSystemFontOfSize:9.5];
    self.unitLabel.textColor = [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1];
    self.unitLabel.textAlignment = NSTextAlignmentCenter;
    self.unitLabel.text = @"KM / H • DYNAMICS";
    [self addSubview:self.unitLabel];
    
    self.gearBadge = [[UIView alloc] init];
    self.gearBadge.backgroundColor = [UIColor colorWithRed:0.02 green:0.18 blue:0.10 alpha:0.9];
    self.gearBadge.layer.cornerRadius = 6;
    self.gearBadge.layer.borderWidth = 1.0;
    self.gearBadge.layer.borderColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.45 alpha:0.7].CGColor;
    UILabel *gl = [[UILabel alloc] initWithFrame:CGRectMake(5, 2, 14, 18)];
    gl.tag = 101;
    gl.font = [UIFont boldSystemFontOfSize:13];
    gl.textColor = [UIColor whiteColor];
    gl.text = @"D";
    [self.gearBadge addSubview:gl];
    UILabel *gw = [[UILabel alloc] initWithFrame:CGRectMake(20, 4, 38, 14)];
    gw.tag = 102;
    gw.font = [UIFont boldSystemFontOfSize:8.5];
    gw.textColor = [UIColor colorWithRed:0.25 green:0.95 blue:0.50 alpha:1];
    gw.text = @"DRIVE";
    [self.gearBadge addSubview:gw];
    [self addSubview:self.gearBadge];
    
    self.speedLimitBadge = [UIButton buttonWithType:UIButtonTypeCustom];
    self.speedLimitBadge.backgroundColor = [UIColor colorWithRed:0.85 green:0.05 blue:0.10 alpha:0.18];
    self.speedLimitBadge.layer.cornerRadius = 13;
    self.speedLimitBadge.layer.borderWidth = 2;
    self.speedLimitBadge.layer.borderColor = [UIColor colorWithRed:0.95 green:0.10 blue:0.15 alpha:0.9].CGColor;
    [self.speedLimitBadge setTitle:@"90" forState:UIControlStateNormal];
    [self.speedLimitBadge setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.speedLimitBadge.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [self addSubview:self.speedLimitBadge];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  if (self.driveStyle) {
    self.speedLimitBadge.frame = CGRectMake(w - 36, 4, 28, 28);
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:76] ?: [UIFont boldSystemFontOfSize:76];
    self.speedLabel.frame = CGRectMake(10, 20, w - 20, 78);
    self.gearBadge.hidden = YES;
    self.unitLabel.frame = CGRectMake(10, h - 26, w - 20, 20);
    self.unitLabel.font = [UIFont boldSystemFontOfSize:12];
    self.unitLabel.text = @"km/h  •  GPS SPEED";
  } else {
    self.speedLimitBadge.frame = CGRectMake(w - 32, 6, 26, 26);
    self.speedLabel.font = [UIFont fontWithName:@"HelveticaNeue-CondensedBold" size:52] ?: [UIFont boldSystemFontOfSize:52];
    self.speedLabel.frame = CGRectMake(10, 28, w - 20, 52);
    self.gearBadge.hidden = NO;
    self.gearBadge.frame = CGRectMake(12, h - 26, 60, 22);
    self.unitLabel.frame = CGRectMake(76, h - 24, w - 88, 18);
    self.unitLabel.font = [UIFont boldSystemFontOfSize:9.5];
    self.unitLabel.text = @"KM / H • DYNAMICS";
  }
}

- (void)setSpeed:(CGFloat)speed {
  _speed = speed;
  if (speed <= 0.5) {
    self.speedLabel.text = @"0";
  } else {
    self.speedLabel.text = [NSString stringWithFormat:@"%.0f", speed];
  }
  [self setNeedsDisplay];
}

- (void)setGear:(NSString *)gear {
  _gear = [gear copy];
  UILabel *gl = (UILabel *)[self.gearBadge viewWithTag:101];
  UILabel *gw = (UILabel *)[self.gearBadge viewWithTag:102];
  if (gl) gl.text = gear ?: @"D";
  if (gw) {
    if ([gear isEqualToString:@"P"]) gw.text = @"PARK";
    else if ([gear isEqualToString:@"R"]) gw.text = @"REVERSE";
    else if ([gear isEqualToString:@"N"]) gw.text = @"NEUTRAL";
    else if ([gear isEqualToString:@"B"]) gw.text = @"BRAKE";
    else gw.text = @"DRIVE";
  }
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  CGPoint center = CGPointMake(w / 2.0, h / 2.0 + (self.driveStyle ? 6 : 2));
  CGFloat radius = MIN(w / 2.0 - 18, h / 2.0 - 8);
  
  CGFloat startAngle = M_PI * 0.85;
  CGFloat endAngle = M_PI * 2.15;
  CGFloat totalAngle = endAngle - startAngle;
  
  if (self.driveStyle) {
    // Drive Mode: Dual glowing arc (Cyan left, Red right) with TRD top badge
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.85].CGColor);
    CGContextSetLineWidth(ctx, 5.0);
    CGContextAddArc(ctx, center.x, center.y, radius, startAngle, startAngle + totalAngle * 0.5, 0);
    CGContextStrokePath(ctx);
    
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.2 blue:0.25 alpha:0.85].CGColor);
    CGContextSetLineWidth(ctx, 5.0);
    CGContextAddArc(ctx, center.x, center.y, radius, startAngle + totalAngle * 0.5, endAngle, 0);
    CGContextStrokePath(ctx);
    
    // Draw TRD text
    UIFont *trdFont = [UIFont boldSystemFontOfSize:14];
    NSDictionary *trdAttrs = @{NSFontAttributeName: trdFont, NSForegroundColorAttributeName: [UIColor colorWithRed:1.0 green:0.2 blue:0.25 alpha:1]};
    [@"TRD" drawAtPoint:CGPointMake(center.x - 14, center.y - radius + 12) withAttributes:trdAttrs];
  } else {
    // Home Mode: Background track arc
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.08 green:0.14 blue:0.20 alpha:0.75].CGColor);
    CGContextSetLineWidth(ctx, 4.0);
    CGContextAddArc(ctx, center.x, center.y, radius, startAngle, endAngle, 0);
    CGContextStrokePath(ctx);
    
    // Active speed progress arc
    CGFloat ratio = MIN(MAX(self.speed / 180.0, 0.0), 1.0);
    if (ratio > 0.01) {
      CGFloat currentAngle = startAngle + totalAngle * ratio;
      CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.9].CGColor);
      CGContextSetLineWidth(ctx, 5.0);
      CGContextAddArc(ctx, center.x, center.y, radius, startAngle, currentAngle, 0);
      CGContextStrokePath(ctx);
    }
    
    // Tick marks and numbers: 0, 30, 60, 80, 100, 120, 140, 160
    NSArray *ticks = @[@0, @30, @60, @80, @100, @120, @140, @160];
    UIFont *font = [UIFont boldSystemFontOfSize:8.5];
    NSDictionary *textAttrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor colorWithWhite:0.6 alpha:0.85]};
    
    for (NSNumber *num in ticks) {
      CGFloat val = [num doubleValue];
      CGFloat tRatio = val / 180.0;
      CGFloat angle = startAngle + totalAngle * tRatio;
      
      CGFloat tickInner = radius - 6.0;
      CGFloat tickOuter = radius + 2.0;
      CGFloat x1 = center.x + tickInner * cos(angle);
      CGFloat y1 = center.y + tickInner * sin(angle);
      CGFloat x2 = center.x + tickOuter * cos(angle);
      CGFloat y2 = center.y + tickOuter * sin(angle);
      
      CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.3 green:0.55 blue:0.75 alpha:0.65].CGColor);
      CGContextSetLineWidth(ctx, 1.5);
      CGContextMoveToPoint(ctx, x1, y1);
      CGContextAddLineToPoint(ctx, x2, y2);
      CGContextStrokePath(ctx);
      
      if (val == 0 || val == 60 || val == 100 || val == 140) {
        NSString *str = [NSString stringWithFormat:@"%.0f", val];
        CGSize sz = [str sizeWithAttributes:textAttrs];
        CGFloat textR = radius - 14.0;
        CGFloat tx = center.x + textR * cos(angle) - sz.width / 2.0;
        CGFloat ty = center.y + textR * sin(angle) - sz.height / 2.0;
        [str drawAtPoint:CGPointMake(tx, ty) withAttributes:textAttrs];
      }
    }
  }
}
@end

@interface TRDVerticalShifterView : UIView
@property (nonatomic, copy) NSString *gear;
@end

@implementation TRDVerticalShifterView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor colorWithRed:0.02 green:0.05 blue:0.08 alpha:0.85];
    self.layer.cornerRadius = 14;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:0.22 alpha:1].CGColor;
    self.gear = @"D";
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  
  NSArray *gears = @[@"P", @"R", @"N", @"D", @"B"];
  CGFloat rowH = (h - 8) / 5.0;
  
  NSInteger activeIdx = [gears indexOfObject:self.gear ?: @"D"];
  if (activeIdx == NSNotFound) activeIdx = 3;
  
  CGFloat sliderY = 4 + activeIdx * rowH;
  CGRect sliderRect = CGRectMake(4, sliderY + 1, w - 8, rowH - 2);
  UIBezierPath *sliderPath = [UIBezierPath bezierPathWithRoundedRect:sliderRect cornerRadius:6];
  [[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.35] setFill];
  [sliderPath fill];
  [[UIColor colorWithRed:0.2 green:0.95 blue:1.0 alpha:0.9] setStroke];
  sliderPath.lineWidth = 1.5;
  [sliderPath stroke];
  
  UIFont *font = [UIFont boldSystemFontOfSize:13];
  for (NSInteger i = 0; i < gears.count; i++) {
    NSString *g = gears[i];
    BOOL isActive = (i == activeIdx);
    UIColor *col = isActive ? [UIColor whiteColor] : [UIColor colorWithWhite:0.45 alpha:1];
    NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: col};
    CGSize sz = [g sizeWithAttributes:attrs];
    CGFloat gy = 4 + i * rowH + (rowH - sz.height) / 2.0;
    CGFloat gx = (w - sz.width) / 2.0;
    [g drawAtPoint:CGPointMake(gx, gy) withAttributes:attrs];
  }
}
@end

@interface TRDHybridPowerMeterView : UIView
@property (nonatomic, assign) CGFloat powerRatio;
@property (nonatomic, strong) UIView *coachPill;
@end

@implementation TRDHybridPowerMeterView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.powerRatio = 0.2;
    
    self.coachPill = [[UIView alloc] init];
    self.coachPill.backgroundColor = [UIColor colorWithRed:0.02 green:0.18 blue:0.10 alpha:0.85];
    self.coachPill.layer.cornerRadius = 11;
    self.coachPill.layer.borderWidth = 1.0;
    self.coachPill.layer.borderColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.45 alpha:0.7].CGColor;
    
    UILabel *cl = [[UILabel alloc] init];
    cl.tag = 201;
    cl.font = [UIFont boldSystemFontOfSize:10.5];
    cl.textColor = [UIColor colorWithRed:0.25 green:0.95 blue:0.50 alpha:1];
    cl.textAlignment = NSTextAlignmentCenter;
    cl.text = @"ECO  AI ECO COACH: 94 A+";
    [self.coachPill addSubview:cl];
    [self addSubview:self.coachPill];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  self.coachPill.frame = CGRectMake((w - 180)/2, h - 24, 180, 22);
  UILabel *cl = (UILabel *)[self.coachPill viewWithTag:201];
  if (cl) cl.frame = self.coachPill.bounds;
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  CGPoint center = CGPointMake(w / 2.0, h - 32);
  CGFloat radius = MIN(w / 2.0 - 20, h - 42);
  
  // CHG arc (180 to 225 deg)
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.75].CGColor);
  CGContextSetLineWidth(ctx, 7.0);
  CGContextAddArc(ctx, center.x, center.y, radius, M_PI * 1.0, M_PI * 1.25, 0);
  CGContextStrokePath(ctx);
  
  // ECO arc (228 to 300 deg)
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.1 green:0.88 blue:0.4 alpha:0.85].CGColor);
  CGContextSetLineWidth(ctx, 7.0);
  CGContextAddArc(ctx, center.x, center.y, radius, M_PI * 1.28, M_PI * 1.68, 0);
  CGContextStrokePath(ctx);
  
  // PWR arc (305 to 360 deg)
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.95 green:0.25 blue:0.25 alpha:0.75].CGColor);
  CGContextSetLineWidth(ctx, 7.0);
  CGContextAddArc(ctx, center.x, center.y, radius, M_PI * 1.72, M_PI * 2.0, 0);
  CGContextStrokePath(ctx);
  
  UIFont *f = [UIFont boldSystemFontOfSize:9.5];
  NSDictionary *chgAttrs = @{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:1]};
  NSDictionary *ecoAttrs = @{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor colorWithRed:0.2 green:0.95 blue:0.45 alpha:1]};
  NSDictionary *pwrAttrs = @{NSFontAttributeName:f, NSForegroundColorAttributeName:[UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1]};
  
  [@"CHG" drawAtPoint:CGPointMake(center.x - radius - 8, center.y + 4) withAttributes:chgAttrs];
  [@"- ECO -" drawAtPoint:CGPointMake(center.x - 18, center.y - radius - 15) withAttributes:ecoAttrs];
  [@"PWR" drawAtPoint:CGPointMake(center.x + radius - 14, center.y + 4) withAttributes:pwrAttrs];
  
  CGFloat needleAngle = M_PI * 1.0 + (M_PI * 1.0) * ((self.powerRatio + 1.0) / 2.0);
  CGFloat nx = center.x + (radius - 4) * cos(needleAngle);
  CGFloat ny = center.y + (radius - 4) * sin(needleAngle);
  
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.3 green:1.0 blue:0.6 alpha:1].CGColor);
  CGContextSetLineWidth(ctx, 2.5);
  CGContextMoveToPoint(ctx, center.x, center.y);
  CGContextAddLineToPoint(ctx, nx, ny);
  CGContextStrokePath(ctx);
  
  CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
  CGContextFillEllipseInRect(ctx, CGRectMake(center.x - 3, center.y - 3, 6, 6));
}
@end

@interface TRD3DPerspectiveGridView : UIView
@end

@implementation TRD3DPerspectiveGridView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  
  CGFloat horizonY = h * 0.38;
  CGPoint vp = CGPointMake(w / 2.0, horizonY - 10);
  
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.22].CGColor);
  CGContextSetLineWidth(ctx, 1.0);
  
  NSInteger numLines = 14;
  for (NSInteger i = 0; i <= numLines; i++) {
    CGFloat bottomX = (w / (CGFloat)numLines) * i;
    CGContextMoveToPoint(ctx, vp.x, vp.y);
    CGContextAddLineToPoint(ctx, bottomX, h);
    CGContextStrokePath(ctx);
  }
  
  NSInteger numHoriz = 8;
  for (NSInteger i = 1; i <= numHoriz; i++) {
    CGFloat t = (CGFloat)i / (CGFloat)numHoriz;
    CGFloat y = horizonY + (h - horizonY) * (t * t);
    CGFloat factor = (y - horizonY) / (h - horizonY);
    CGFloat hw = (w * 0.5) * factor + (w * 0.2);
    
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0.0 green:0.85 blue:1.0 alpha:0.12 + 0.18 * factor].CGColor);
    CGContextMoveToPoint(ctx, w / 2.0 - hw, y);
    CGContextAddLineToPoint(ctx, w / 2.0 + hw, y);
    CGContextStrokePath(ctx);
  }
}
@end
`;

console.log("Custom classes prepared.");
