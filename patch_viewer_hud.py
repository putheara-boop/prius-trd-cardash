with open('d:/Projcet/my_web/viewer_main.m', 'rb') as f:
    text = f.read().decode('utf-8')

text = text.replace('\r\r\n', '\n').replace('\r\n', '\n')

old_hud_block = ''' NSDictionary *tele=[self.telemetry summary];
 NSNumber *spd=tele[@"speedKmh"];
 NSString *spdStr=spd?[NSString stringWithFormat:@"%.0f km/h",spd.doubleValue]:@"-- km/h";'''

new_hud_block = ''' NSDictionary *tele=[self.telemetry summary];
 NSNumber *spd=tele[@"speedKmh"];
 if(!spd || spd.doubleValue < 0){
  NSDictionary *carGps=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/gps-last-speed.plist"];
  if([carGps[@"hasFix"] boolValue]){
   double mps=[carGps[@"rawSpeed"] doubleValue];
   if(mps >= 0) spd=@(mps * 3.6);
  }
 }
 NSString *spdStr=spd?[NSString stringWithFormat:@"%.0f km/h",spd.doubleValue]:@"0 km/h";'''

assert old_hud_block in text, 'old_hud_block not found'
text = text.replace(old_hud_block, new_hud_block)

with open('d:/Projcet/my_web/viewer_main.m', 'wb') as f:
    f.write(text.encode('utf-8'))

print('Patched viewer_main.m successfully')
