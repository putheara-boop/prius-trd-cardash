const fs = require('fs');

console.log("Reading cardash_main.m...");
let src = fs.readFileSync('cardash_main.m', 'utf8');

// 1. Add TRD14BlockGraphView if missing
const blockGraphDef = `
@interface TRD14BlockGraphView : UIView
@property (nonatomic, copy) NSArray *voltages;
@end
@implementation TRD14BlockGraphView
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = [UIColor colorWithRed:.01 green:.03 blue:.05 alpha:0.95];
    self.layer.cornerRadius = 6;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:0.18 alpha:1].CGColor;
    self.clipsToBounds = YES;
  }
  return self;
}
- (void)drawRect:(CGRect)rect {
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  NSInteger count = 14;
  CGFloat gap = 2.0;
  CGFloat barW = (w - 8 - (count - 1) * gap) / count;
  CGFloat baselineY = h - 5.0;
  
  CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.25 alpha:1].CGColor);
  CGContextSetLineWidth(ctx, 1.0);
  CGContextMoveToPoint(ctx, 4, baselineY);
  CGContextAddLineToPoint(ctx, w - 4, baselineY);
  CGContextStrokePath(ctx);
  
  for (NSInteger i = 0; i < count; i++) {
    CGFloat x = 4 + i * (barW + gap);
    CGFloat barH = 22.0;
    if (self.voltages && i < self.voltages.count) {
      double v = [self.voltages[i] doubleValue];
      barH = 10.0 + (v - 15.5) * 16.0;
      if (barH < 4.0) barH = 4.0;
      if (barH > baselineY - 4.0) barH = baselineY - 4.0;
    }
    CGFloat y = baselineY - barH;
    CGRect barRect = CGRectMake(x, y, barW, barH);
    
    UIColor *fillColor = [UIColor colorWithRed:0.0 green:0.85 blue:0.55 alpha:0.85];
    [fillColor setFill];
    UIRectFill(barRect);
    
    [[UIColor colorWithRed:0.35 green:1.0 blue:0.80 alpha:1] setFill];
    UIRectFill(CGRectMake(x, y, barW, 2));
  }
}
@end
`;

if (!src.includes('@interface TRD14BlockGraphView')) {
  src = src.replace('@interface Dashboard:UIViewController', blockGraphDef + "\n@interface Dashboard:UIViewController");
}

// 2. Fix the control character \\u2744\\u00ef\\u00b8\\u008f
src = src.replace(/\\u2744\\u00ef\\u00b8\\u008f/g, '\\U00002744\\U0000FE0F');

// 3. Fix deltaL type casting
src = src.replace('UIView *deltaL = [self.view viewWithTag:706];\n    if (!deltaL) {\n      deltaL = [[UILabel alloc] init];',
  'UILabel *deltaL = (UILabel *)[self.view viewWithTag:706];\n    if (!deltaL) {\n      deltaL = [[UILabel alloc] init];');

fs.writeFileSync('cardash_main.m', src, 'utf8');
fs.writeFileSync('car_dash_live_main.m', src, 'utf8');
console.log("Fixes applied successfully.");
