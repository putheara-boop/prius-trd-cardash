const fs = require('fs');

['cardash_main.m', 'car_dash_live_main.m'].forEach(file => {
  let s = fs.readFileSync(file, 'utf8');
  s = s.replace(/\\U0001F6E1\\U0000FE0F PRIUS DYNAMICS/g, 'PRIUS DYNAMICS');
  s = s.replace(/\\U0001F9ED N 018\\u00b0 \\u2022 3D LOCK/g, 'N 018\\u00b0 \\u2022 GPS 3D LOCK');
  s = s.replace(/\\U0001F321\\U0000FE0F Coolant: 88\\u00b0C  \\u2022  \\u2744\\U0000FE0F A\/C: 24.5\\u00b0C  \\u2022  \\U0001F50B 12V: 13.8V/g, 'Coolant: 88\\u00b0C  \\u2022  A/C: 24.5\\u00b0C  \\u2022  12V: 13.8V');
  s = s.replace(/\\U0001F3B5 NOW PLAYING/g, 'NOW PLAYING');
  fs.writeFileSync(file, s, 'utf8');
});
console.log('Cleaned iOS 9 emoji placeholders!');
