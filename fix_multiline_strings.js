const fs = require('fs');

let content = fs.readFileSync('cardash_main.m', 'utf8');

// Replace physical newlines inside string literals with \n
content = content.replace(/b2\.text = @"ECO 92[\s\S]*?แรงดันปั๊มปกติ";/, 'b2.text = @"ECO 92 / 100   [ GRADE A+ ]\\\\n\\\\nระบบไฮบริดทำงานสมบูรณ์ 100%\\\\nเลี้ยงคันเร่งนุ่มนวลเพื่อประหยัดน้ำมัน\\\\nอัตราการดึงพลังงานกลับ: ดีเยี่ยม\\\\nเบรกไฟฟ้า ECB: แรงดันปั๊มปกติ";');

content = content.replace(/h2\.text = @"[\s\S]*?สถานะระบบหล่อเย็น: ปกติ สมบูรณ์";/, 'h2.text = @"🌡️ น้ำหล่อเย็น (Coolant) : 88 °C\\\\n\\\\n❄️ แอร์ห้องโดยสาร : 24.5 °C (42°C Inv)\\\\n\\\\n🔋 แบตเตอรี่สตาร์ท 12V : 13.84 V • ชาร์จปกติ\\\\n\\\\nพัดลมระบายความร้อน: เบอร์ 1 (Low)\\\\nสถานะระบบหล่อเย็น: ปกติ สมบูรณ์";');

content = content.replace(/pb\.text = @"64\.5% SOC[\s\S]*?14 BLOCKS \(28 NiMH MODULES\)";/, 'pb.text = @"64.5% SOC (ระดับไฟไฮบริด)\\\\n227.4 V • +12.4 A (CHG)\\\\n14 BLOCKS (28 NiMH MODULES)";');

content = content.replace(/ml\.text = @"⚙️ มอเตอร์ MG2[\s\S]*?พัดลม Low";/, 'ml.text = @"⚙️ มอเตอร์ MG2 (ขับเคลื่อน)\\\\n   1,420 RPM / 18 kW\\\\n⚡ เจนเนอเรเตอร์ MG1 (ปั่นไฟ)\\\\n   980 RPM / 8 kW\\\\n🌡️ อุณหภูมิแบตไฮบริด (HV)\\\\n   35.0 °C • พัดลม Low";');

content = content.replace(/tb\.text = @"ระยะทางทริป: 18\.42 km[\s\S]*?ดีเยี่ยม \(Grade A\+\)";/, 'tb.text = @"ระยะทางทริป: 18.42 km\\\\nอัตราสิ้นเปลือง: 23.8 km/L\\\\nค่าน้ำมันทริป: ฿ 29.80 (PTT GSH95)\\\\nวิ่งต่อได้: ~520 km\\\\nความเร็วเฉลี่ย: 48.5 km/h\\\\nเวลาขับขี่: 00:24:18\\\\nประหยัดน้ำมัน: ดีเยี่ยม (Grade A+)";');

fs.writeFileSync('cardash_main.m', content, 'utf8');
fs.writeFileSync('car_dash_live_main.m', content, 'utf8');
console.log('Fixed literal newlines in strings.');
