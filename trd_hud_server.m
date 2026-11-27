#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <notify.h>

static NSString *const kHUDHTML =
@"<!DOCTYPE html>\n"
"<html lang=\"th\">\n"
"<head>\n"
"<meta charset=\"utf-8\">\n"
"<meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover\">\n"
"<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n"
"<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black-translucent\">\n"
"<meta name=\"apple-mobile-web-app-title\" content=\"PRIUS TRD\">\n"
"<title>PRIUS TRD • MOBILE & HUD</title>\n"
"<style>\n"
"*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;}\n"
"html,body{width:100%;height:100%;background:#05080d;color:#ffffff;font-family:-apple-system,'Helvetica Neue','Sukhumvit Set',Arial,sans-serif;overflow-x:hidden;}\n"
".mode-switch{position:fixed;top:max(8px,env(safe-area-inset-top));left:50%;-webkit-transform:translateX(-50%);transform:translateX(-50%);z-index:9999;display:-webkit-flex;display:flex;background:rgba(8,14,22,0.92);border:1px solid rgba(0,229,255,0.40);border-radius:20px;padding:3px;box-shadow:0 4px 16px rgba(0,0,0,0.65);}\n"
".ms-btn{border:none;background:transparent;color:#8bb4cc;font-size:12px;font-weight:800;padding:6px 13px;border-radius:16px;cursor:pointer;white-space:nowrap;}\n"
".ms-btn.active{background:linear-gradient(135deg,#00b8d4,#0077ff);color:#fff;box-shadow:0 0 12px rgba(0,200,255,0.55);}\n"
"/* === REMOTE COMPANION VIEW === */\n"
"#remoteView{min-height:100%;padding:calc(max(12px,env(safe-area-inset-top)) + 44px) 14px 32px;max-width:540px;margin:0 auto;}\n"
".card{background:linear-gradient(180deg,rgba(14,22,34,0.96),rgba(9,14,22,0.98));border:1px solid rgba(0,215,255,0.22);border-radius:16px;padding:15px;margin-bottom:13px;box-shadow:0 6px 20px rgba(0,0,0,0.45);}\n"
".card-hdr{display:-webkit-flex;display:flex;-webkit-justify-content:space-between;justify-content:space-between;-webkit-align-items:center;align-items:center;margin-bottom:10px;}\n"
".card-title{font-size:14px;font-weight:900;letter-spacing:0.5px;color:#00e5ff;}\n"
".live-pill{font-size:11px;font-weight:800;color:#22ff88;background:rgba(34,255,136,0.12);border:1px solid rgba(34,255,136,0.4);padding:3px 9px;border-radius:12px;}\n"
".live-pill.off{color:#ff6b7a;background:rgba(255,60,80,0.14);border-color:rgba(255,60,80,0.45);}\n"
".inp{width:100%;background:#070c14;border:1px solid rgba(255,255,255,0.22);border-radius:11px;color:#fff;font-size:15px;padding:12px 13px;outline:none;-webkit-user-select:text;user-select:text;margin-bottom:9px;}\n"
".inp:focus{border-color:#00e5ff;box-shadow:0 0 0 2px rgba(0,229,255,0.22);}\n"
".row{display:-webkit-flex;display:flex;gap:8px;margin-bottom:8px;}\n"
".rbtn{border:1px solid rgba(0,229,255,0.38);background:rgba(0,180,255,0.14);color:#e8faff;font-size:14px;font-weight:800;padding:12px 10px;border-radius:11px;cursor:pointer;-webkit-flex:1;flex:1;text-align:center;}\n"
".rbtn:active{opacity:0.75;-webkit-transform:scale(0.98);transform:scale(0.98);}\n"
".rbtn.primary{background:linear-gradient(135deg,#e6192d,#ff4055);border-color:#ff6677;color:#fff;font-size:15px;box-shadow:0 4px 14px rgba(230,25,45,0.45);}\n"
".rbtn.green{background:linear-gradient(135deg,#00b862,#008f4c);border-color:#22ff88;color:#fff;}\n"
".rbtn.gps-on{background:linear-gradient(135deg,#0099ff,#00c888);border-color:#55ffbb;color:#fff;}\n"
".hint{font-size:12px;color:#8aa4bc;line-height:1.45;margin-top:4px;}\n"
".toast{display:none;margin-top:8px;padding:9px 12px;border-radius:10px;background:rgba(0,200,120,0.18);border:1px solid rgba(34,255,136,0.5);color:#7bffbe;font-size:13px;font-weight:700;}\n"
".chips{display:-webkit-flex;display:flex;overflow-x:auto;gap:7px;padding-top:4px;}\n"
".chips::-webkit-scrollbar{display:none;}\n"
".chip{background:rgba(255,255,255,0.07);border:1px solid rgba(255,255,255,0.18);color:#d8ecff;font-size:12px;font-weight:700;padding:7px 12px;border-radius:16px;white-space:nowrap;cursor:pointer;}\n"
".tel-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;}\n"
".tel-box{background:rgba(4,9,15,0.85);border:1px solid rgba(255,255,255,0.10);border-radius:11px;padding:10px 11px;}\n"
".tel-lbl{font-size:11px;color:#7fa2be;font-weight:700;}\n"
".tel-val{font-size:18px;color:#fff;font-weight:900;margin-top:2px;font-variant-numeric:tabular-nums;}\n"
".tel-sub{font-size:11px;color:#22ff88;font-weight:700;margin-top:2px;}\n"
".song-banner{background:rgba(0,229,255,0.08);border:1px solid rgba(0,229,255,0.25);border-radius:10px;padding:9px 11px;margin-bottom:9px;font-size:13px;font-weight:800;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}\n"
"/* === HUD VIEW === */\n"
"#hudView{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:#000;padding:46px 18px 10px;-webkit-flex-direction:column;flex-direction:column;-webkit-justify-content:space-between;justify-content:space-between;-webkit-user-select:none;user-select:none;}\n"
"#hudView.mirror{-webkit-transform:scaleX(-1);transform:scaleX(-1);}\n"
"#hudView.t-cyan .acc{color:#00e5ff;}\n"
"#hudView.t-green .acc{color:#22ff88;}\n"
"#hudView.t-red .acc{color:#ff3848;}\n"
".topbar{display:-webkit-flex;display:flex;-webkit-justify-content:space-between;justify-content:space-between;-webkit-align-items:center;align-items:center;}\n"
".status-left{display:-webkit-flex;display:flex;-webkit-align-items:center;align-items:center;font-size:13px;font-weight:800;letter-spacing:1.4px;color:#00e5ff;}\n"
".dot{width:9px;height:9px;border-radius:50%;background:#22ff88;box-shadow:0 0 10px #22ff88;display:inline-block;margin-right:8px;}\n"
".clock-big{font-size:36px;font-weight:900;line-height:1;color:#fff;font-variant-numeric:tabular-nums;}\n"
".trip-txt{font-size:13px;font-weight:800;color:#7de8ff;}\n"
".stage{display:-webkit-flex;display:flex;-webkit-flex:1;flex:1;-webkit-align-items:center;align-items:center;-webkit-justify-content:space-between;justify-content:space-between;}\n"
".zone{display:-webkit-flex;display:flex;-webkit-flex-direction:column;flex-direction:column;-webkit-justify-content:center;justify-content:center;}\n"
".z-nav{width:28%;}\n"
".z-spd{width:44%;-webkit-align-items:center;align-items:center;position:relative;}\n"
".z-hyb{width:28%;-webkit-align-items:flex-end;align-items:flex-end;text-align:right;}\n"
".nav-row{display:-webkit-flex;display:flex;-webkit-align-items:center;align-items:center;}\n"
".nav-arrow{font-size:88px;font-weight:900;line-height:0.9;color:#00e5ff;margin-right:10px;}\n"
".nav-dist{font-size:26px;font-weight:900;color:#fff;}\n"
".nav-sub{font-size:13px;font-weight:800;color:#22ff88;margin-top:3px;}\n"
".nav-street{font-size:14px;font-weight:700;color:#bfeaff;margin-top:6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%;}\n"
"#digitalWrap{display:-webkit-flex;display:flex;-webkit-align-items:baseline;align-items:baseline;-webkit-justify-content:center;justify-content:center;}\n"
".speed-num{font-size:165px;font-weight:900;line-height:0.84;letter-spacing:-5px;color:#fff;text-shadow:0 0 34px rgba(0,229,255,0.5);margin-right:10px;font-variant-numeric:tabular-nums;}\n"
".speed-num.warn90{color:#ffaa22;}\n"
".speed-num.warn120{color:#ff2636;}\n"
".gear-badge{font-size:34px;font-weight:900;color:#22ff88;line-height:1;margin-bottom:4px;}\n"
".unit-txt{font-size:15px;font-weight:900;color:#00e5ff;letter-spacing:2px;}\n"
".ev-tag{font-size:15px;font-weight:900;color:#22ff88;margin-bottom:6px;}\n"
".soc-big{font-size:32px;font-weight:900;color:#fff;margin-bottom:6px;}\n"
".hyb-metrics{font-size:14px;font-weight:800;color:#c8e8f8;}\n"
".botbar{display:-webkit-flex;display:flex;-webkit-justify-content:space-between;justify-content:space-between;-webkit-align-items:center;align-items:center;}\n"
".btn{background:rgba(0,30,45,0.7);border:1px solid rgba(0,229,255,0.45);color:#aef4ff;padding:6px 11px;border-radius:10px;font-size:12px;font-weight:800;margin-right:6px;}\n"
"@media (orientation:portrait){\n"
"  #hudView .stage{-webkit-flex-direction:column;flex-direction:column;-webkit-justify-content:space-around;justify-content:space-around;}\n"
"  #hudView .z-nav,#hudView .z-spd,#hudView .z-hyb{width:100%;-webkit-align-items:center;align-items:center;text-align:center;}\n"
"}\n"
"</style>\n"
"</head>\n"
"<body>\n"
"<div class=\"mode-switch\">\n"
"  <button class=\"ms-btn active\" id=\"tabRemote\" onclick=\"setView('remote')\">📱 รีโมต & Google Maps</button>\n"
"  <button class=\"ms-btn\" id=\"tabHud\" onclick=\"setView('hud')\">🪞 จอ HUD สะท้อนกระจก</button>\n"
"</div>\n"
"\n"
"<div id=\"remoteView\">\n"
"  <div class=\"card\">\n"
"    <div class=\"card-hdr\">\n"
"      <div class=\"card-title\">📍 ส่งพิกัด Google Maps ขึ้นจอรถทันที</div>\n"
"      <div class=\"live-pill\" id=\"carConnBadge\">● เชื่อมต่อรถแล้ว</div>\n"
"    </div>\n"
"    <input class=\"inp\" id=\"mapInput\" type=\"text\" placeholder=\"วางลิงก์ Google Maps หรือพิมพ์ชื่อสถานที่...\" autocomplete=\"off\">\n"
"    <div class=\"row\">\n"
"      <button class=\"rbtn green\" onclick=\"pasteAndSendMap()\">📋 วางลิงก์ & นำทางเลย</button>\n"
"      <button class=\"rbtn primary\" onclick=\"sendMap(1)\">🚀 เริ่มนำทางบนรถ</button>\n"
"    </div>\n"
"    <div class=\"row\">\n"
"      <button class=\"rbtn\" onclick=\"sendMap(0)\">📌 ปักหมุดดูเส้นทางก่อน</button>\n"
"      <button class=\"rbtn\" id=\"gpsBoostBtn\" onclick=\"togglePhoneGPS()\">🛰️ ส่ง GPS มือถือช่วยนำทาง: OFF</button>\n"
"    </div>\n"
"    <div class=\"chips\" id=\"quickMapChips\">\n"
"      <span class=\"chip\" onclick=\"quickDest('ปั๊มน้ำมัน บางจาก ปตท.')\">⛽ ปั๊มน้ำมันใกล้ฉัน</span>\n"
"      <span class=\"chip\" onclick=\"quickDest('7-Eleven เซเว่น')\">🏪 7-Eleven</span>\n"
"      <span class=\"chip\" onclick=\"quickDest('คาเฟ่ อเมซอน จุดพักรถ')\">☕ คาเฟ่ / จุดพักรถ</span>\n"
"      <span class=\"chip\" onclick=\"quickDest('ร้านอาหารใกล้ฉัน')\">🍜 ร้านอาหาร</span>\n"
"    </div>\n"
"    <div class=\"chips\" id=\"recentChips\" style=\"margin-top:6px;\"></div>\n"
"    <div class=\"toast\" id=\"mapToast\"></div>\n"
"    <div class=\"hint\">💡 วิธีใช้: เปิดแอป <b>Google Maps</b> ในมือถือ → กด <b>แชร์ (Share)</b> → <b>คัดลอกลิงก์</b> แล้วกดปุ่มสีเขียวด้านบน พิกัดจริงจะเด้งนำทางบนจอ CarDash ทันที!</div>\n"
"  </div>\n"
"\n"
"  <div class=\"card\">\n"
"    <div class=\"card-hdr\">\n"
"      <div class=\"card-title\">🎵 รีโมตเพลง & ค้นหาเพลงเข้าจอรถ</div>\n"
"      <div style=\"font-size:11px;color:#8bb4cc;font-weight:700;\" id=\"clockMini\">--:--</div>\n"
"    </div>\n"
"    <div class=\"song-banner\" id=\"remoteSongTxt\">🎵 กำลังซิงก์ชื่อเพลงจากรถ...</div>\n"
"    <div class=\"row\">\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('music_cmd','prev')\">⏮ ก่อนหน้า</button>\n"
"      <button class=\"rbtn green\" onclick=\"sendCmd('music_cmd','toggle')\">⏯ เล่น / หยุด</button>\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('music_cmd','next')\">⏭ ถัดไป</button>\n"
"    </div>\n"
"    <div class=\"row\" style=\"margin-top:6px;\">\n"
"      <input class=\"inp\" id=\"songInput\" type=\"text\" placeholder=\"พิมพ์ชื่อเพลง / ศิลปิน เล่นบนรถ...\" style=\"margin-bottom:0;-webkit-flex:1;flex:1;\">\n"
"      <button class=\"rbtn primary\" style=\"-webkit-flex:0 0 112px;flex:0 0 112px;\" onclick=\"sendSongSearch()\">▶ เล่นเพลง</button>\n"
"    </div>\n"
"    <div class=\"chips\" style=\"margin-top:8px;\">\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Flat')\">🎚️ Flat</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Rock')\">🎸 Rock</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Pop')\">🎤 Pop</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Dance')\">🔊 Bass/Dance</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Jazz')\">🎷 Jazz</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Voice')\">🗣️ เสียงพูดชัด</span>\n"
"    </div>\n"
"  </div>\n"
"\n"
"  <div class=\"card\">\n"
"    <div class=\"card-hdr\">\n"
"      <div class=\"card-title\">🚗 สถานะ PRIUS TRD สดจากกล่อง OBD2</div>\n"
"      <div style=\"font-size:11px;color:#22ff88;font-weight:800;\" id=\"gearMini\">GEAR P</div>\n"
"    </div>\n"
"    <div class=\"tel-grid\">\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">ความเร็ว / โหมดขับ</div><div class=\"tel-val\" id=\"tSpd\">0 km/h</div><div class=\"tel-sub\" id=\"tMode\">EV READY</div></div>\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">แบตเตอรี่ไฮบริด HV</div><div class=\"tel-val\" id=\"tSoc\">--%</div><div class=\"tel-sub\" id=\"tHvT\">HV --°C • พัดลม AUTO</div></div>\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">ความร้อนเครื่อง / อินเวอร์เตอร์</div><div class=\"tel-val\" id=\"tEct\">--°C</div><div class=\"tel-sub\" id=\"tInv\">INV --°C • แบต 12V --V</div></div>\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">น้ำมันเหลือ / ทริปนี้</div><div class=\"tel-val\" id=\"tFuel\">-- L</div><div class=\"tel-sub\" id=\"tCost\">฿0.0 • -- km/L</div></div>\n"
"    </div>\n"
"    <div class=\"row\" style=\"margin-top:10px;margin-bottom:0;\">\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('screen','home')\">🏠 หน้าหลัก</button>\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('screen','drive')\">🏎️ Drive</button>\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('screen','maps')\">🗺️ แผนที่</button>\n"
"    </div>\n"
"    <div class=\"hint\" style=\"margin-top:8px;\">🔒 ปลอดภัย 100%: ทำงานเฉพาะตอนเปิดสวิตช์รถ เมื่อดับเครื่องไอแพดจะพักระบบอัตโนมัติ ไม่ดึงไฟแบตเตอรี่รถยนต์</div>\n"
"  </div>\n"
"</div>\n"
"\n"
"<div id=\"hudView\" class=\"t-cyan\">\n"
"  <div class=\"topbar\">\n"
"    <div class=\"status-left acc\"><span class=\"dot\" id=\"connDot\"></span><span>PRIUS TRD • HUD</span></div>\n"
"    <div class=\"clock-big\" id=\"clockTxt\">--:--</div>\n"
"    <div class=\"trip-txt acc\" id=\"wifiTxt\">TRD LIVE</div>\n"
"  </div>\n"
"  <div class=\"stage\">\n"
"    <div class=\"zone z-nav\">\n"
"      <div class=\"nav-row\">\n"
"        <div class=\"nav-arrow acc\" id=\"navArrow\">↑</div>\n"
"        <div><div class=\"nav-dist\" id=\"navDist\">GPS LIVE</div><div class=\"nav-sub acc\" id=\"navSub\">AUTO SYNC</div></div>\n"
"      </div>\n"
"      <div class=\"nav-street\" id=\"navStreet\">ซิงก์พิกัดสดจาก iPad อัตโนมัติ</div>\n"
"    </div>\n"
"    <div class=\"zone z-spd\">\n"
"      <div id=\"digitalWrap\">\n"
"        <div class=\"speed-num\" id=\"speedNum\">0</div>\n"
"        <div><div class=\"gear-badge\" id=\"gearBox\">P</div><div class=\"unit-txt acc\">KM/H</div></div>\n"
"      </div>\n"
"    </div>\n"
"    <div class=\"zone z-hyb\">\n"
"      <div class=\"ev-tag\" id=\"modePill\">⚡ EV ELECTRIC</div>\n"
"      <div class=\"soc-big\">HV <span id=\"socVal\">--%</span></div>\n"
"      <div class=\"hyb-metrics\"><span id=\"ectTxt\">--°C</span> • <span id=\"auxTxt\">--V</span></div>\n"
"      <div class=\"hyb-metrics\" style=\"margin-top:5px;color:#ffcf56;\" id=\"fuelCostTxt\">⛽ ฿0.0</div>\n"
"    </div>\n"
"  </div>\n"
"  <div class=\"botbar\">\n"
"    <div>\n"
"      <button class=\"btn\" id=\"modeBtn\" onclick=\"toggleMirror()\">📱 มองตรง</button>\n"
"      <button class=\"btn\" id=\"themeBtn\" onclick=\"cycleTheme()\">🎨 สลับสี</button>\n"
"    </div>\n"
"    <div style=\"font-size:13px;color:#7cb8d4;max-width:48%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;\" id=\"songTxt\">🎵 PRIUS TRD</div>\n"
"  </div>\n"
"</div>\n"
"\n"
"<script>\n"
"var curView = 'remote', isMirror = false, themeIdx = 0, gpsWatchId = null, lastGpsSent = 0;\n"
"var themes = ['t-cyan','t-green','t-red'];\n"
"function setView(v){\n"
"  curView = v;\n"
"  document.getElementById('remoteView').style.display = (v === 'remote') ? 'block' : 'none';\n"
"  document.getElementById('hudView').style.display = (v === 'hud') ? '-webkit-flex' : 'none';\n"
"  if(v === 'hud') document.getElementById('hudView').style.display = 'flex';\n"
"  document.getElementById('tabRemote').className = 'ms-btn' + (v === 'remote' ? ' active' : '');\n"
"  document.getElementById('tabHud').className = 'ms-btn' + (v === 'hud' ? ' active' : '');\n"
"}\n"
"function toggleMirror(){\n"
"  isMirror = !isMirror;\n"
"  document.getElementById('hudView').className = themes[themeIdx] + (isMirror ? ' mirror' : '');\n"
"  document.getElementById('modeBtn').innerText = isMirror ? '🪞 สะท้อนกระจก' : '📱 มองตรง';\n"
"}\n"
"function cycleTheme(){\n"
"  themeIdx = (themeIdx + 1) % 3;\n"
"  document.getElementById('hudView').className = themes[themeIdx] + (isMirror ? ' mirror' : '');\n"
"}\n"
"function showToast(msg){\n"
"  var t = document.getElementById('mapToast');\n"
"  t.innerText = msg; t.style.display = 'block';\n"
"  setTimeout(function(){ t.style.display = 'none'; }, 4500);\n"
"}\n"
"function saveRecent(q){\n"
"  try {\n"
"    var arr = JSON.parse(localStorage.getItem('trd_recent_places') || '[]');\n"
"    var label = q.length > 34 ? (q.indexOf('http') >= 0 ? ('📍 ลิงก์หมุด (' + q.slice(-8) + ')') : (q.slice(0,32) + '…')) : q;\n"
"    arr = arr.filter(function(x){ return x.q !== q; });\n"
"    arr.unshift({q:q, l:label});\n"
"    if(arr.length > 5) arr = arr.slice(0,5);\n"
"    localStorage.setItem('trd_recent_places', JSON.stringify(arr));\n"
"    renderRecents();\n"
"  } catch(e){}\n"
"}\n"
"function renderRecents(){\n"
"  try {\n"
"    var arr = JSON.parse(localStorage.getItem('trd_recent_places') || '[]');\n"
"    var box = document.getElementById('recentChips');\n"
"    box.innerHTML = '';\n"
"    arr.forEach(function(it){\n"
"      var s = document.createElement('span');\n"
"      s.className = 'chip';\n"
"      s.innerText = '🕘 ' + it.l;\n"
"      s.onclick = function(){ document.getElementById('mapInput').value = it.q; sendMap(1); };\n"
"      box.appendChild(s);\n"
"    });\n"
"  } catch(e){}\n"
"}\n"
"function sendCmd(action, value, autoStart, cb){\n"
"  var xhr = new XMLHttpRequest();\n"
"  var url = '/api/cmd?action=' + encodeURIComponent(action) + '&value=' + encodeURIComponent(value || '') + '&auto=' + (autoStart ? '1' : '0') + '&t=' + Date.now();\n"
"  xhr.open('GET', url, true);\n"
"  xhr.onload = function(){ if(cb) cb(xhr.status === 200); };\n"
"  xhr.onerror = function(){ if(cb) cb(false); };\n"
"  xhr.send();\n"
"}\n"
"function sendMap(autoStart){\n"
"  var v = (document.getElementById('mapInput').value || '').trim();\n"
"  if(!v){ showToast('⚠️ กรุณาวางลิงก์ Google Maps หรือพิมพ์ชื่อสถานที่ก่อนครับ'); return; }\n"
"  saveRecent(v);\n"
"  showToast('🚀 ส่งเข้าจอรถแล้ว! กำลังดึงพิกัดและเปิดนำทางบน CarDash...');\n"
"  sendCmd('nav', v, autoStart, function(ok){\n"
"    if(ok) showToast('✅ ส่งพิกัดเข้าจอ CarDash สำเร็จ!');\n"
"  });\n"
"}\n"
"function quickDest(q){\n"
"  document.getElementById('mapInput').value = q;\n"
"  sendMap(1);\n"
"}\n"
"function pasteAndSendMap(){\n"
"  if(navigator.clipboard && navigator.clipboard.readText){\n"
"    navigator.clipboard.readText().then(function(txt){\n"
"      if(txt && txt.trim().length > 0){\n"
"        document.getElementById('mapInput').value = txt.trim();\n"
"        sendMap(1);\n"
"      } else {\n"
"        document.getElementById('mapInput').focus();\n"
"        showToast('📋 แตะค้างที่ช่องด้านบนแล้วกด วาง (Paste) ได้เลยครับ');\n"
"      }\n"
"    }).catch(function(){\n"
"      var v = (document.getElementById('mapInput').value || '').trim();\n"
"      if(v.length > 0){ sendMap(1); return; }\n"
"      document.getElementById('mapInput').focus();\n"
"      showToast('📋 แตะค้างในช่องข้อความเพื่อวางลิงก์ Google Maps แล้วกดเริ่มนำทางครับ');\n"
"    });\n"
"  } else {\n"
"    var v = (document.getElementById('mapInput').value || '').trim();\n"
"    if(v.length > 0){ sendMap(1); return; }\n"
"    document.getElementById('mapInput').focus();\n"
"    showToast('📋 แตะค้างในช่องข้อความเพื่อวางลิงก์ Google Maps แล้วกดเริ่มนำทางครับ');\n"
"  }\n"
"}\n"
"function sendSongSearch(){\n"
"  var s = (document.getElementById('songInput').value || '').trim();\n"
"  if(!s) return;\n"
"  sendCmd('music_search', s, 1);\n"
"  showToast('🎵 กำลังค้นหาและเล่นเพลง: ' + s);\n"
"  document.getElementById('songInput').value = '';\n"
"}\n"
"function togglePhoneGPS(){\n"
"  var btn = document.getElementById('gpsBoostBtn');\n"
"  if(gpsWatchId !== null){\n"
"    navigator.geolocation.clearWatch(gpsWatchId);\n"
"    gpsWatchId = null;\n"
"    btn.className = 'rbtn';\n"
"    btn.innerText = '🛰️ ส่ง GPS มือถือช่วยนำทาง: OFF';\n"
"    return;\n"
"  }\n"
"  if(!navigator.geolocation){\n"
"    showToast('⚠️ เบราว์เซอร์นี้ต้องเปิดผ่าน HTTPS หรืออนุญาต Location ก่อนครับ');\n"
"    return;\n"
"  }\n"
"  btn.className = 'rbtn gps-on';\n"
"  btn.innerText = '🛰️ กำลังซิงก์ GPS มือถือเข้าจอรถ...';\n"
"  gpsWatchId = navigator.geolocation.watchPosition(function(pos){\n"
"    var now = Date.now();\n"
"    if(now - lastGpsSent < 1100) return;\n"
"    lastGpsSent = now;\n"
"    var c = pos.coords;\n"
"    var u = '/api/gps?lat=' + c.latitude + '&lon=' + c.longitude + '&spd=' + (c.speed || 0) + '&crs=' + (c.heading || -1) + '&acc=' + (c.accuracy || 10) + '&t=' + now;\n"
"    var x = new XMLHttpRequest(); x.open('GET', u, true); x.send();\n"
"    btn.innerText = '🛰️ GPS มือถือซิงก์สด (±' + Math.round(c.accuracy || 5) + 'm)';\n"
"  }, function(){\n"
"    gpsWatchId = null;\n"
"    btn.className = 'rbtn';\n"
"    btn.innerText = '🛰️ ส่ง GPS มือถือช่วยนำทาง: OFF';\n"
"    showToast('⚠️ ไม่สามารถอ่าน GPS จากเบราว์เซอร์ได้ (แต่ส่งลิงก์หมุด Google Maps ได้ 100% ครับ)');\n"
"  }, {enableHighAccuracy:true, maximumAge:1500, timeout:6000});\n"
"}\n"
"renderRecents();\n"
"var pollBusy = false;\n"
"function poll(){\n"
"  if(pollBusy) return;\n"
"  pollBusy = true;\n"
"  var xhr = new XMLHttpRequest();\n"
"  xhr.open('GET', '/api/hud?t=' + Date.now(), true);\n"
"  xhr.timeout = 1400;\n"
"  xhr.onloadend = function(){ pollBusy = false; };\n"
"  xhr.onload = function(){\n"
"    if(xhr.status === 200){\n"
"      try {\n"
"        var d = JSON.parse(xhr.responseText);\n"
"        var badge = document.getElementById('carConnBadge');\n"
"        badge.className = 'live-pill'; badge.innerText = '● เชื่อมต่อรถสด';\n"
"        document.getElementById('connDot').style.background = '#22ff88';\n"
"        var spd = Math.max(0, Math.round(Number(d.speed || 0)));\n"
"        var gear = d.gear || 'P';\n"
"        var soc = Math.max(0, Math.min(100, Math.round(Number(d.soc || 0))));\n"
"        document.getElementById('clockMini').innerText = d.clock || '--:--';\n"
"        document.getElementById('clockTxt').innerText = d.clock || '--:--';\n"
"        document.getElementById('gearMini').innerText = 'GEAR ' + gear;\n"
"        document.getElementById('tSpd').innerText = spd + ' km/h';\n"
"        document.getElementById('tMode').innerText = d.hybridMode || 'EV READY';\n"
"        document.getElementById('tSoc').innerText = soc + '%';\n"
"        document.getElementById('tHvT').innerText = 'HV ' + (d.hvC || '--') + '°C • พัดลม ' + (d.fan || 'AUTO');\n"
"        document.getElementById('tEct').innerText = (d.ect || '--') + '°C';\n"
"        document.getElementById('tInv').innerText = 'INV ' + (d.invC || '--') + '°C • 12V ' + (d.aux12v || '--') + 'V';\n"
"        document.getElementById('tFuel').innerText = (d.fuelL || '--') + ' L (~' + (d.rangeKm || '--') + ' กม.)';\n"
"        document.getElementById('tCost').innerText = '฿' + (d.fuelCost || '0.0') + ' • ' + (d.kmPerL || '--') + ' km/L';\n"
"        var songStr = d.song ? ('🎵 ' + d.song) : '🎵 พร้อมเล่นเพลง (audioNINJA / YouTube)';\n"
"        document.getElementById('remoteSongTxt').innerText = songStr;\n"
"        document.getElementById('songTxt').innerText = songStr;\n"
"        var sn = document.getElementById('speedNum');\n"
"        sn.innerText = spd;\n"
"        sn.className = 'speed-num' + (spd >= 120 ? ' warn120' : (spd >= 90 ? ' warn90' : ''));\n"
"        document.getElementById('gearBox').innerText = gear;\n"
"        document.getElementById('wifiTxt').innerText = (d.trip || 'TRD LIVE') + (d.weather ? (' • ' + d.weather) : '');\n"
"        document.getElementById('navArrow').innerText = d.navArrow || '↑';\n"
"        document.getElementById('navDist').innerText = d.navDist || 'GPS LIVE';\n"
"        document.getElementById('navSub').innerText = d.navSub || 'AUTO SYNC';\n"
"        document.getElementById('navStreet').innerText = d.navStreet || 'พร้อมนำทาง';\n"
"        document.getElementById('socVal').innerText = soc + '%';\n"
"        document.getElementById('modePill').innerText = '⚡ ' + (d.hybridMode || 'EV');\n"
"        document.getElementById('ectTxt').innerText = (d.ect || '--') + '°C';\n"
"        document.getElementById('auxTxt').innerText = (d.aux12v || '--') + 'V';\n"
"        document.getElementById('fuelCostTxt').innerText = '⛽ ฿' + (d.fuelCost || '0.0') + ' • ' + (d.kmPerL || '--') + ' km/L';\n"
"      } catch(e){}\n"
"    }\n"
"  };\n"
"  xhr.onerror = function(){\n"
"    var badge = document.getElementById('carConnBadge');\n"
"    badge.className = 'live-pill off'; badge.innerText = '○ รอสัญญาณรถ';\n"
"    document.getElementById('connDot').style.background = '#ff3344';\n"
"  };\n"
"  xhr.send();\n"
"}\n"
"setInterval(poll, 650);\n"
"poll();\n"
"</script>\n"
"</body>\n"
"</html>\n";

static BOOL sendAllBytes(int fd, const void *buf, size_t len) {
  const uint8_t *p = (const uint8_t *)buf;
  size_t remaining = len;
  while (remaining > 0) {
    ssize_t sent = send(fd, p, remaining, 0);
    if (sent < 0) {
      if (errno == EINTR) continue;
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        usleep(5000);
        continue;
      }
      return NO;
    }
    if (sent == 0) return NO;
    p += sent;
    remaining -= (size_t)sent;
  }
  return YES;
}

static NSDictionary *parseQueryParams(NSString *query) {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  if (!query.length) return dict;
  for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
    NSRange eq = [pair rangeOfString:@"="];
    if (eq.location == NSNotFound) continue;
    NSString *k = [pair substringToIndex:eq.location];
    NSString *v = [[pair substringFromIndex:eq.location + 1] stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    v = [v stringByRemovingPercentEncoding] ?: v;
    if (k.length) dict[k] = v ?: @"";
  }
  return dict;
}

static NSString *buildLiveHUDJSON(void) {
  @autoreleasepool {
    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      df = [[NSDateFormatter alloc] init];
      df.dateFormat = @"HH:mm";
    });
    NSDictionary *live = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/hud-live.plist"] ?: @{};
    NSDictionary *state = (live.count > 0) ? @{} : ([NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/h109-build/cardash-state.plist"] ?: @{});

    double spd = [live[@"speed"] ?: (state[@"speed"] ?: @0) doubleValue];
    NSString *clockStr = live[@"clock"] ?: @"";
    if (clockStr.length == 0) {
      @synchronized(df) { clockStr = [df stringFromDate:[NSDate date]]; }
    }
    NSString *song = live[@"song"] ?: (state[@"song"] ?: @"");
    NSString *artist = live[@"artist"] ?: (state[@"artist"] ?: @"");
    NSString *fullSong = (song.length > 0 && ![song isEqualToString:@"Choose your music"] && artist.length > 0)
      ? [NSString stringWithFormat:@"%@ — %@", song, artist]
      : (song.length > 0 ? song : @"พร้อมเล่นเพลง");

    NSDictionary *payload = @{
      @"speed": @(spd),
      @"gear": live[@"gear"] ?: @"P",
      @"clock": clockStr,
      @"trip": live[@"trip"] ?: @"TRD LIVE",
      @"fuelCost": live[@"fuelCost"] ?: @"0.0",
      @"kmPerL": live[@"kmPerL"] ?: @"--",
      @"weather": live[@"weather"] ?: @"",
      @"navArrow": live[@"navArrow"] ?: @"↑",
      @"navDist": live[@"navDist"] ?: @"GPS LIVE",
      @"navSub": live[@"navSub"] ?: @"AUTO SYNC",
      @"navStreet": live[@"navStreet"] ?: @"พร้อมนำทาง",
      @"soc": live[@"soc"] ?: @0,
      @"ect": live[@"ect"] ?: @0,
      @"invC": live[@"invC"] ?: @0,
      @"hvC": live[@"hvC"] ?: @"--",
      @"fan": live[@"fan"] ?: @"AUTO",
      @"fuelL": live[@"fuelL"] ?: @"--",
      @"rangeKm": live[@"rangeKm"] ?: @"--",
      @"aux12v": live[@"aux12v"] ?: @"--",
      @"hybridMode": live[@"hybridMode"] ?: @"EV READY",
      @"song": fullSong
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!jsonData) return @"{}";
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] ?: @"{}";
  }
}

static void handleClientSocket(int clientFd) {
  @autoreleasepool {
    int nodelay = 1;
    setsockopt(clientFd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
    struct timeval tv = { .tv_sec = 4, .tv_usec = 0 };
    setsockopt(clientFd, SOL_SOCKET, SO_RCVTIMEO, (const char *)&tv, sizeof(tv));
    setsockopt(clientFd, SOL_SOCKET, SO_SNDTIMEO, (const char *)&tv, sizeof(tv));

    char buf[8192];
    ssize_t n = recv(clientFd, buf, sizeof(buf) - 1, 0);
    if (n <= 0) {
      close(clientFd);
      return;
    }
    buf[n] = '\0';
    NSString *req = [NSString stringWithUTF8String:buf];
    if (!req) req = [[NSString alloc] initWithBytes:buf length:(NSUInteger)n encoding:NSISOLatin1StringEncoding] ?: @"";
    NSString *firstLine = [[req componentsSeparatedByString:@"\r\n"] firstObject] ?: @"";
    NSArray *parts = [firstLine componentsSeparatedByString:@" "];
    NSString *pathAndQuery = (parts.count >= 2) ? parts[1] : @"/";
    NSRange qRange = [pathAndQuery rangeOfString:@"?"];
    NSString *path = (qRange.location == NSNotFound) ? pathAndQuery : [pathAndQuery substringToIndex:qRange.location];
    NSString *query = (qRange.location == NSNotFound) ? @"" : [pathAndQuery substringFromIndex:qRange.location + 1];

    NSData *bodyData = nil;
    NSString *contentType = @"text/html; charset=utf-8";

    if ([path isEqualToString:@"/api/hud"]) {
      contentType = @"application/json; charset=utf-8";
      bodyData = [buildLiveHUDJSON() dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([path isEqualToString:@"/api/cmd"]) {
      contentType = @"application/json; charset=utf-8";
      NSDictionary *params = parseQueryParams(query);
      NSString *action = params[@"action"] ?: @"";
      NSString *value = params[@"value"] ?: @"";
      BOOL autoStart = [params[@"auto"] isEqualToString:@"1"];
      if (action.length > 0) {
        NSDictionary *cmdDict = @{
          @"token": [NSUUID UUID].UUIDString ?: @"cmd",
          @"action": action,
          @"value": value,
          @"autoStart": @(autoStart),
          @"at": @([[NSDate date] timeIntervalSince1970])
        };
        [cmdDict writeToFile:@"/var/mobile/codex-car/mobile-cmd.plist" atomically:YES];
        notify_post("com.codex.trd.mobile.cmd");
      }
      bodyData = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([path isEqualToString:@"/api/gps"]) {
      contentType = @"application/json; charset=utf-8";
      NSDictionary *params = parseQueryParams(query);
      double lat = [params[@"lat"] doubleValue];
      double lon = [params[@"lon"] doubleValue];
      if (fabs(lat) > 0.001 && fabs(lon) > 0.001) {
        NSDictionary *gpsDict = @{
          @"lat": @(lat),
          @"lon": @(lon),
          @"spd": @([params[@"spd"] doubleValue]),
          @"crs": @([params[@"crs"] doubleValue]),
          @"acc": @([params[@"acc"] doubleValue]),
          @"at": @([[NSDate date] timeIntervalSince1970])
        };
        [gpsDict writeToFile:@"/var/mobile/codex-car/phone-gps.plist" atomically:YES];
        notify_post("com.codex.trd.mobile.gps");
      }
      bodyData = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];
    } else {
      bodyData = [kHUDHTML dataUsingEncoding:NSUTF8StringEncoding];
    }

    NSString *header = [NSString stringWithFormat:
      @"HTTP/1.1 200 OK\r\n"
      "Content-Type: %@\r\n"
      "Content-Length: %lu\r\n"
      "Cache-Control: no-store, no-cache, must-revalidate\r\n"
      "Access-Control-Allow-Origin: *\r\n"
      "Connection: close\r\n\r\n",
      contentType, (unsigned long)bodyData.length];

    NSData *headerData = [header dataUsingEncoding:NSUTF8StringEncoding];
    if (sendAllBytes(clientFd, headerData.bytes, headerData.length) && bodyData.length > 0) {
      sendAllBytes(clientFd, bodyData.bytes, bodyData.length);
    }
    shutdown(clientFd, SHUT_WR);
    struct timeval drainTv = { .tv_sec = 0, .tv_usec = 120000 };
    setsockopt(clientFd, SOL_SOCKET, SO_RCVTIMEO, (const char *)&drainTv, sizeof(drainTv));
    char drain[512];
    while (recv(clientFd, drain, sizeof(drain), 0) > 0) {}
    close(clientFd);
  }
}

static void startListenerOnPort(uint16_t port) {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    int srv = socket(AF_INET, SOCK_STREAM, 0);
    if (srv < 0) return;
    int yes = 1;
    setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);
    if (bind(srv, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
      close(srv);
      return;
    }
    if (listen(srv, 32) < 0) {
      close(srv);
      return;
    }
    while (1) {
      struct sockaddr_in cliAddr;
      socklen_t cliLen = sizeof(cliAddr);
      int cli = accept(srv, (struct sockaddr *)&cliAddr, &cliLen);
      if (cli < 0) continue;
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        handleClientSocket(cli);
      });
    }
  });
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    signal(SIGPIPE, SIG_IGN);
    startListenerOnPort(80);
    startListenerOnPort(8080);
    startListenerOnPort(8088);
    while (1) {
      sleep(3600);
    }
  }
  return 0;
}
