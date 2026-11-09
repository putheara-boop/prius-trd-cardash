# Toyota Prius TRD (ZVW30) — Smart Cockpit CarDash 🏎️💨

> 📅 **วันที่อัปเดตล่าสุด (Last Updated):** 10 พฤศจิกายน 2026 (10 November 2026)  
> 🛡️ **สถานะเวอร์ชัน:** V3.6 (ระบบเบรก ABS + กล้องถอยหลัง + ค่าน้ำมันสดจากปั๊ม ปตท.)  
> 👤 **Owner:** พี่พุธ (`PEEPUT’S DRIVE`)  
> 🚘 **Vehicle:** Toyota Prius Gen 3 TRD (ZVW30)  
> **Telemetry:** Vgate vLinker MC+ (Bluetooth 4.0 BLE, STN, CAN-Bus 500kbps)  
> **Reverse Camera:** Wi-Fi Camera (`H109Y-37802895`) with Automated Network Broker  
> **Sound & Audio:** Bluetooth In-Car Audio (`CAR MULTIMEDIA`)  

---

## 📖 สารบัญระบบ (Documentation Index)

* 📘 [**คู่มือระบบการทำงาน 4 สเต็ปครบวงจร (PRIUS_WORKFLOW_GUIDE.md)**](PRIUS_WORKFLOW_GUIDE.md) — สตาร์ทรถ, เกียร์ถอยหลัง, การตรวจวัดเบรก ABS, และสรุปค่าน้ำมันจบทริป
* 📸 [**คลังภาพหน้าจอจริง (Screenshots Gallery)**](screenshots/README.md) — ภาพหน้าจอจริงที่บันทึกจากการรันบน iPad Mini
* 🛠️ [**คู่มือทางเทคนิคสำหรับนักพัฒนา (TRD_CARDASH_CODEX_HANDOFF.md)**](TRD_CARDASH_CODEX_HANDOFF.md) — ข้อมูลคำสั่งคอมไพล์ สถาปัตยกรรมภายใน และระบบประหยัดพลังงาน

---

## 🌟 ฟังก์ชันหลักที่ทำงานในรถจริง (Key Features)

1. **คำนวณค่าน้ำมันสดจบทริป (Per-Trip Fuel & Cost Calculation):**
   - สตาร์ทรถ รีเซ็ต 0 ทันที
   - ดึงราคาน้ำมันสดจากปั๊ม ปตท. วันนี้ (`https://api.chnwt.dev/thai-oil-api/latest`)
   - จบทริป A ไป B ดับเครื่อง โชว์การ์ดสรุปค่าน้ำมัน (บาท) และลิตรที่ใช้จริง
2. **ระบบกล้องถอยหลังและเสียงเซ็นเซอร์ถอยหลังอัตโนมัติ (Reverse Camera & Sonar):**
   - เข้าเกียร์ `R` ตัดเน็ตไปเกาะ Wi-Fi กล้อง `H109Y-...` ทันทีภายใน 1-2 วินาที
   - เปิดภาพกล้องถอยหลังเต็มจอ + หรี่เพลง 50% + ส่งเสียงเซ็นเซอร์ถอยออกลำโพงรถ
   - ปลดเกียร์ `R` กลับมาหน้าปัดเรือนไมล์และต่อเน็ตมือถือเหมือนเดิม
3. **การ์ดตรวจระบบเบรก & ABS ไฮบริด (Prius ECB System Monitoring):**
   - ตรวจระดับน้ำมันเบรก (Brake Fluid Level)
   - ตรวจความพร้อมของกล่องควบคุมเบรก ABS / VSC
   - ตรวจแรงดันปั๊มเบรกไฮดรอลิกสะสม (Accumulator Pressure ปกติ 15-20 MPa)
   - แจ้งเตือนสีแดงทันทีหากน้ำมันเบรกต่ำหรือแรงดันผิดปกติ
4. **เรดาร์เตือนกล้องจับความเร็ว (Speed Camera Radar):**
   - เตือนล่วงหน้า 500 เมตรด้วยเสียง
5. **วิทยุออนไลน์และระบบเสียง (Thai Radio & Equalizer):**
   - รวมสถานีวิทยุยอดนิยมในไทย เช่น COOL Fahrenheit 93, Met 107, JS100 ข่าวจราจร
   - ระบบปรับแต่งเสียง Equalizer 10 แบนด์ ปรับมิติเสียงให้เข้ากับลำโพงพรีอุส
