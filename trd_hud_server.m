#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <notify.h>
#include <spawn.h>
#include <dns_sd.h>

extern char **environ;

static void stopH109ViewerIfRunning(void) {
  pid_t pid = 0;
  char *argv[] = { (char *)"/usr/bin/killall", (char *)"-9", (char *)"H109Viewer", NULL };
  posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, argv, environ);
}

static NSString *extractDirectYTVideoID(NSString *input) {
  NSString *s = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!s.length) return nil;
  if (s.length == 11) {
    NSRegularExpression *idOnly = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9_-]{11}$" options:0 error:nil];
    if ([idOnly numberOfMatchesInString:s options:0 range:NSMakeRange(0, s.length)] == 1) return s;
  }
  NSArray *pats = @[
    @"(?:youtu\\.be/|youtube\\.com/(?:shorts/|embed/|live/|v/))([A-Za-z0-9_-]{11})",
    @"[?&]v=([A-Za-z0-9_-]{11})"
  ];
  for (NSString *p in pats) {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:p options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:s options:0 range:NSMakeRange(0, s.length)];
    if (m && m.numberOfRanges >= 2) return [s substringWithRange:[m rangeAtIndex:1]];
  }
  return nil;
}

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
".mode-switch{position:fixed;top:max(8px,env(safe-area-inset-top));left:50%;-webkit-transform:translateX(-50%);transform:translateX(-50%);z-index:9999;display:-webkit-flex;display:flex;background:rgba(8,14,22,0.95);border:1px solid rgba(0,229,255,0.40);border-radius:20px;padding:3px;box-shadow:0 4px 16px rgba(0,0,0,0.65);max-width:calc(100vw - 12px);}\n"
".ms-btn{border:none;background:transparent;color:#8bb4cc;font-size:12px;font-weight:800;padding:6px 11px;border-radius:16px;cursor:pointer;white-space:nowrap;}\n"
"@media (max-width:375px){.ms-btn{font-size:10.5px;padding:5px 7px;}.rbtn{font-size:12px;padding:10px 6px;}}\n"
".ms-btn.active{background:linear-gradient(135deg,#00b8d4,#0077ff);color:#fff;box-shadow:0 0 12px rgba(0,200,255,0.55);}\n"
"/* === REMOTE & CAR HEALTH VIEWS === */\n"
"#remoteView,#carView{min-height:100%;padding:calc(max(12px,env(safe-area-inset-top)) + 44px) 14px 32px;max-width:540px;margin:0 auto;}\n"
"#carView{display:none;}\n"
".blk-grid{display:grid;grid-template-columns:repeat(7,1fr);gap:5px;margin:10px 0 8px;}\n"
".blk-cell{background:rgba(4,10,18,0.92);border:1px solid rgba(0,229,255,0.22);border-radius:8px;padding:5px 2px;text-align:center;}\n"
".blk-bar-bg{height:30px;width:12px;margin:3px auto;background:rgba(255,255,255,0.08);border-radius:4px;display:-webkit-flex;display:flex;-webkit-align-items:flex-end;align-items:flex-end;overflow:hidden;}\n"
".blk-bar-fill{width:100%;background:linear-gradient(180deg,#22ff88,#00b8d4);border-radius:4px;}\n"
".blk-id{font-size:9.5px;color:#7fa8c4;font-weight:800;}\n"
".blk-v{font-size:10.5px;color:#fff;font-weight:900;font-variant-numeric:tabular-nums;}\n"
".m-row{background:rgba(4,10,18,0.85);border:1px solid rgba(255,255,255,0.10);border-radius:11px;padding:10px 11px;margin-bottom:8px;}\n"
".m-top{display:-webkit-flex;display:flex;-webkit-justify-content:space-between;justify-content:space-between;-webkit-align-items:center;align-items:center;gap:6px;}\n"
".m-title{font-size:13px;font-weight:900;color:#eaf6ff;}\n"
".m-sub{font-size:11.5px;color:#8bb4cc;margin-top:3px;font-weight:700;}\n"
".pbar{height:7px;background:rgba(255,255,255,0.10);border-radius:4px;overflow:hidden;margin-top:6px;}\n"
".pfill{height:100%;background:linear-gradient(90deg,#22ff88,#00e5ff);border-radius:4px;}\n"
".pfill.warn{background:linear-gradient(90deg,#ffaa22,#ff4455);}\n"
".tlog-row{display:-webkit-flex;display:flex;-webkit-justify-content:space-between;justify-content:space-between;padding:7px 4px;border-bottom:1px solid rgba(255,255,255,0.07);font-size:12.5px;}\n"
".tlog-row:last-child{border-bottom:none;}\n"
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
".sr-box{display:none;background:#060b12;border:1px solid rgba(0,229,255,0.35);border-radius:12px;margin:8px 0;max-height:250px;overflow-y:auto;-webkit-overflow-scrolling:touch;}\n"
".sr-row{display:-webkit-flex;display:flex;-webkit-align-items:center;align-items:center;-webkit-justify-content:space-between;justify-content:space-between;padding:9px 10px;border-bottom:1px solid rgba(255,255,255,0.08);gap:8px;}\n"
".sr-row:last-child{border-bottom:none;}\n"
".sr-txt{-webkit-flex:1;flex:1;min-width:0;font-size:13px;font-weight:700;color:#eaf6ff;line-height:1.35;}\n"
".sr-sub{font-size:11px;color:#7fa8c4;font-weight:600;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}\n"
".q-mini{border:1px solid rgba(0,229,255,0.45);background:rgba(0,200,255,0.18);color:#fff;font-size:12px;font-weight:800;padding:7px 10px;border-radius:9px;cursor:pointer;white-space:nowrap;}\n"
".q-mini.yt{background:rgba(230,25,45,0.28);border-color:#ff5566;}\n"
".q-wrap{background:rgba(6,13,22,0.92);border:1px solid rgba(34,255,136,0.32);border-radius:12px;padding:10px;margin-top:9px;}\n"
".q-hdr{display:-webkit-flex;display:flex;-webkit-justify-content:space-between;justify-content:space-between;-webkit-align-items:center;align-items:center;font-size:12px;font-weight:900;color:#22ff88;margin-bottom:6px;}\n"
".q-item{display:-webkit-flex;display:flex;-webkit-align-items:center;align-items:center;padding:7px 8px;border-radius:8px;background:rgba(255,255,255,0.04);margin-bottom:5px;gap:7px;}\n"
".q-item.playing{background:rgba(34,255,136,0.16);border:1px solid rgba(34,255,136,0.5);}\n"
".q-num{font-size:12px;font-weight:900;color:#00e5ff;min-width:20px;}\n"
".q-name{-webkit-flex:1;flex:1;font-size:13px;font-weight:700;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;cursor:pointer;}\n"
".q-del{border:none;background:rgba(255,60,80,0.2);color:#ff7b88;font-size:12px;font-weight:900;padding:4px 8px;border-radius:7px;cursor:pointer;}\n"
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
"  <button class=\"ms-btn active\" id=\"tabRemote\" onclick=\"setView('remote')\">📱 รีโมต & Maps</button>\n"
"  <button class=\"ms-btn\" id=\"tabCar\" onclick=\"setView('car')\">🔧 รถ & สรุปทริป</button>\n"
"  <button class=\"ms-btn\" id=\"tabHud\" onclick=\"setView('hud')\">🪞 จอ HUD</button>\n"
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
"      <button class=\"rbtn green\" onclick=\"pasteAndSendMap('carplay')\">📋 วางลิงก์ → จอ CarPlay</button>\n"
"      <button class=\"rbtn primary\" onclick=\"sendMap(1,'carplay')\">🎛️ นำทางโหมด CarPlay</button>\n"
"    </div>\n"
"    <div class=\"row\">\n"
"      <button class=\"rbtn\" onclick=\"sendMap(1,'maps')\">🗺️ นำทางเต็มจอ</button>\n"
"      <button class=\"rbtn\" id=\"gpsBoostBtn\" onclick=\"togglePhoneGPS()\">🛰️ ส่ง GPS มือถือช่วย: OFF</button>\n"
"    </div>\n"
"    <div class=\"chips\" id=\"quickMapChips\">\n"
"      <span class=\"chip\" onclick=\"quickDest('ปั๊มน้ำมัน')\">⛽ ปั๊มน้ำมันใกล้ฉัน</span>\n"
"      <span class=\"chip\" onclick=\"quickDest('7-Eleven')\">🏪 7-Eleven</span>\n"
"      <span class=\"chip\" onclick=\"quickDest('Cafe Amazon')\">☕ คาเฟ่ / จุดพักรถ</span>\n"
"      <span class=\"chip\" onclick=\"quickDest('ร้านอาหาร')\">🍜 ร้านอาหาร</span>\n"
"    </div>\n"
"    <div class=\"chips\" id=\"recentChips\" style=\"margin-top:6px;\"></div>\n"
"    <div class=\"toast\" id=\"mapToast\"></div>\n"
"    <div class=\"hint\">💡 วิธีใช้: เปิดแอป <b>Google Maps</b> ในมือถือ → กด <b>แชร์ (Share)</b> → <b>คัดลอกลิงก์</b> แล้วกดปุ่มสีเขียวด้านบน พิกัดจริงจะเด้งนำทางบนจอ CarDash ทันที!</div>\n"
"  </div>\n"
"\n"
"  <div class=\"card\">\n"
"    <div class=\"card-hdr\">\n"
"      <div class=\"card-title\">🎵 รีโมตเพลง & YouTube ขึ้นจอรถ</div>\n"
"      <div style=\"font-size:11px;color:#8bb4cc;font-weight:700;\" id=\"clockMini\">--:--</div>\n"
"    </div>\n"
"    <div class=\"song-banner\" id=\"remoteSongTxt\">🎵 กำลังซิงก์ชื่อเพลงจากรถ...</div>\n"
"    <div class=\"row\">\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('music_cmd','prev')\">⏮ ก่อนหน้า</button>\n"
"      <button class=\"rbtn green\" onclick=\"sendCmd('music_cmd','toggle')\">⏯ เล่น / หยุด</button>\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('music_cmd','next')\">⏭ ถัดไป</button>\n"
"    </div>\n"
"    <div class=\"row\" style=\"margin-top:4px;\">\n"
"      <input class=\"inp\" id=\"songInput\" type=\"text\" placeholder=\"พิมพ์ชื่อเพลง / ศิลปิน (มีเดาคำอัตโนมัติ)...\" style=\"margin-bottom:0;-webkit-flex:1;flex:1;\" oninput=\"onSongTyping()\" onkeydown=\"if(event.keyCode===13)searchYTList();\">\n"
"      <button class=\"rbtn\" style=\"-webkit-flex:0 0 92px;flex:0 0 92px;padding:10px 6px;\" onclick=\"searchYTList()\">🔍 ค้นหา</button>\n"
"    </div>\n"
"    <div class=\"chips\" id=\"ytSuggestChips\" style=\"display:none;margin:5px 0 3px;\"></div>\n"
"    <div class=\"row\" style=\"margin-top:7px;\">\n"
"      <button class=\"rbtn\" onclick=\"addInputToQueue()\">➕ เพิ่มคิว</button>\n"
"      <button class=\"rbtn green\" onclick=\"sendSongSearch()\">🎵 เล่นเพลง</button>\n"
"      <button class=\"rbtn primary\" onclick=\"sendYouTubeSearch()\">📺 YouTube</button>\n"
"    </div>\n"
"    <div class=\"sr-box\" id=\"ytResultsBox\"></div>\n"
"    <div class=\"q-wrap\" id=\"queueWrap\">\n"
"      <div class=\"q-hdr\">\n"
"        <span id=\"queueCountTxt\">📋 คิวเพลงเล่นต่อเนื่อง (0 เพลง)</span>\n"
"        <span style=\"color:#ff7b88;cursor:pointer;font-size:11px;\" onclick=\"clearSongQueue()\">🗑️ ล้างคิว</span>\n"
"      </div>\n"
"      <div id=\"queueListBox\"><div class=\"hint\" style=\"margin:2px 0 6px;\">กด 🔍 ค้นหา แล้วแตะ <b>+คิว</b> เรียงเพลง 1, 2, 3, 4 เพื่อเล่นต่อเนื่องได้เลยครับ</div></div>\n"
"      <div class=\"row\" id=\"queuePlayRow\" style=\"display:none;margin-top:7px;margin-bottom:0;\">\n"
"        <button class=\"rbtn green\" onclick=\"playFullQueue('music',0)\">🎵 เล่นคิวต่อเนื่อง (แอปเพลง)</button>\n"
"        <button class=\"rbtn primary\" onclick=\"playFullQueue('yt',0)\">📺 เล่นคิวบน YouTube</button>\n"
"      </div>\n"
"    </div>\n"
"    <div class=\"chips\" style=\"margin-top:6px;\">\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Flat')\">🎚️ Flat</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Rock')\">🎸 Rock</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Pop')\">🎤 Pop</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Dance')\">🔊 Bass/Dance</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Jazz')\">🎷 Jazz</span>\n"
"      <span class=\"chip\" onclick=\"sendCmd('eq','Classical')\">🗣️ เสียงใส/คลาสสิก</span>\n"
"    </div>\n"
"    <div class=\"toast\" id=\"mediaToast\"></div>\n"
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
"    <div class=\"row\" style=\"margin-top:10px;\">\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('screen','home')\">🏠 หน้าหลัก</button>\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('screen','drive')\">🏎️ Drive</button>\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('screen','maps')\">🗺️ แผนที่</button>\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('screen','carplay')\">🎛️ CarPlay</button>\n"
"    </div>\n"
"    <div class=\"row\" style=\"margin-bottom:0;\">\n"
"      <button class=\"rbtn green\" onclick=\"sendCmd('screen','music')\">🎵 แอปเพลง</button>\n"
"      <button class=\"rbtn primary\" onclick=\"sendCmd('screen','youtube')\">📺 YouTube</button>\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('screen','camera')\">📷 กล้องรถ</button>\n"
"      <button class=\"rbtn\" onclick=\"sendCmd('night_toggle','1')\">☀️/🌙 แสงจอ</button>\n"
"    </div>\n"
"    <div class=\"hint\" style=\"margin-top:8px;\">🌐 เข้าผ่านชื่อ <b>http://cardash.local</b> ได้ทันทีโดยไม่ต้องจำเลข IP! (เมื่อดับเครื่องไอแพดพักระบบอัตโนมัติ ไม่กินแบตรถ)</div>\n"
"  </div>\n"
"</div>\n"
"\n"
"<div id=\"carView\">\n"
"  <div class=\"card\">\n"
"    <div class=\"card-hdr\">\n"
"      <div class=\"card-title\">🔋 สุขภาพแบตไฮบริด 14 บล็อก & OBD2</div>\n"
"      <div class=\"live-pill\" id=\"obdLivePill\">○ รอสวิตช์รถ</div>\n"
"    </div>\n"
"    <div class=\"tel-grid\">\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">แรงดันรวม / กระแสไฟ</div><div class=\"tel-val\" id=\"hvPackTxt\">-- V</div><div class=\"tel-sub\" id=\"hvAmpTxt\">+0.0 A • SOC --%</div></div>\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">ความสมดุลเซลล์ (ΔV)</div><div class=\"tel-val\" id=\"hvDeltaTxt\">-- V</div><div class=\"tel-sub\" id=\"hvGradeTxt\">รอวัดค่า 14 บล็อก</div></div>\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">อุณหภูมิแบต / ลมดูด</div><div class=\"tel-val\" id=\"hvTempBig\">-- °C</div><div class=\"tel-sub\" id=\"hvInletTxt\">ลมเข้า --°C • พัดลม AUTO</div></div>\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">แบต 12V / น้ำหล่อเย็น</div><div class=\"tel-val\" id=\"auxBigTxt\">-- V</div><div class=\"tel-sub\" id=\"ectInvTxt\">เครื่อง --°C • INV --°C</div></div>\n"
"    </div>\n"
"    <div class=\"blk-grid\" id=\"hvBlocksGrid\"></div>\n"
"    <div class=\"row\" style=\"margin-top:8px;\">\n"
"      <button class=\"rbtn\" onclick=\"setFanRemote(0)\">🌀 พัดลม AUTO</button>\n"
"      <button class=\"rbtn\" onclick=\"setFanRemote(4)\">❄️ พัดลมระดับ 4</button>\n"
"      <button class=\"rbtn green\" onclick=\"setFanRemote(6)\">🚀 พัดลมแรงสุด</button>\n"
"    </div>\n"
"    <div class=\"row\" style=\"margin-bottom:0;\">\n"
"      <button class=\"rbtn\" onclick=\"scanDTCRemote()\">🔍 สแกนโค้ดไฟโชว์ (DTC)</button>\n"
"      <button class=\"rbtn primary\" onclick=\"clearDTCRemote()\">🧹 ลบโค้ดไฟโชว์</button>\n"
"    </div>\n"
"    <div class=\"song-banner\" id=\"dtcResultBox\" style=\"margin-top:9px;margin-bottom:0;white-space:normal;line-height:1.4;\">✅ ระบบพร้อมสแกนโค้ดเครื่องยนต์ / ไฮบริด / แบต HV / ABS</div>\n"
"    <div class=\"toast\" id=\"carToast\"></div>\n"
"  </div>\n"
"\n"
"  <div class=\"card\">\n"
"    <div class=\"card-hdr\">\n"
"      <div class=\"card-title\">📊 สรุปทริป & ค่าน้ำมันรายวัน / 30 วัน</div>\n"
"      <div style=\"font-size:11px;color:#00e5ff;font-weight:800;\" id=\"tripDaysBadge\">ซิงก์จากรถ</div>\n"
"    </div>\n"
"    <div class=\"tel-grid\" style=\"margin-bottom:10px;\">\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">ระยะทางสะสม (30 วัน)</div><div class=\"tel-val\" id=\"sum30Km\">0.0 กม.</div><div class=\"tel-sub\" id=\"sum30Trips\">0 ทริป</div></div>\n"
"      <div class=\"tel-box\"><div class=\"tel-lbl\">ค่าน้ำมันรวม (30 วัน)</div><div class=\"tel-val\" id=\"sum30Cost\">฿0</div><div class=\"tel-sub\" id=\"sum30Fuel\">0.0 ลิตร • -- km/L</div></div>\n"
"    </div>\n"
"    <div id=\"dailyTripList\"><div class=\"hint\">กำลังโหลดประวัติการเดินทางรายวัน...</div></div>\n"
"  </div>\n"
"\n"
"  <div class=\"card\">\n"
"    <div class=\"card-hdr\">\n"
"      <div class=\"card-title\">🛠️ แจ้งเตือนเช็กระยะตามเลขไมล์จริง</div>\n"
"      <div style=\"font-size:12px;color:#22ff88;font-weight:900;\" id=\"curOdoTxt\">ไมล์รถ -- กม.</div>\n"
"    </div>\n"
"    <div class=\"row\" style=\"margin-bottom:10px;\">\n"
"      <input class=\"inp\" id=\"odoInput\" type=\"number\" inputmode=\"numeric\" placeholder=\"ใส่เลขไมล์หน้าปัดรถปัจจุบัน (กม.)...\" style=\"margin-bottom:0;-webkit-flex:1;flex:1;\">\n"
"      <button class=\"rbtn\" style=\"-webkit-flex:0 0 112px;flex:0 0 112px;\" onclick=\"saveRealOdo()\">💾 ตั้งไมล์รถ</button>\n"
"    </div>\n"
"    <div id=\"maintListBox\"></div>\n"
"    <div class=\"row\" style=\"margin-top:10px;margin-bottom:0;\">\n"
"      <button class=\"rbtn green\" onclick=\"cleanIpadCacheRemote()\">🧹 เคลียร์แคช & คืนแรม iPad (ประวัติอยู่ครบ 100%)</button>\n"
"    </div>\n"
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
"  document.getElementById('carView').style.display = (v === 'car') ? 'block' : 'none';\n"
"  document.getElementById('hudView').style.display = (v === 'hud') ? '-webkit-flex' : 'none';\n"
"  if(v === 'hud') document.getElementById('hudView').style.display = 'flex';\n"
"  document.getElementById('tabRemote').className = 'ms-btn' + (v === 'remote' ? ' active' : '');\n"
"  document.getElementById('tabCar').className = 'ms-btn' + (v === 'car' ? ' active' : '');\n"
"  document.getElementById('tabHud').className = 'ms-btn' + (v === 'hud' ? ' active' : '');\n"
"  if(v === 'car') loadCarHealthDetail();\n"
"}\n"
"function showCarToast(msg){\n"
"  var t = document.getElementById('carToast');\n"
"  if(!t){ showToast(msg); return; }\n"
"  t.innerText = msg; t.style.display = 'block';\n"
"  setTimeout(function(){ t.style.display = 'none'; }, 4200);\n"
"}\n"
"function setFanRemote(lvl){\n"
"  sendCmd('hv_fan', String(lvl), 1);\n"
"  showCarToast(lvl === 0 ? '🌀 ตั้งพัดลมแบตไฮบริดเป็นโหมด AUTO แล้วครับ' : ('🚀 สั่งเร่งพัดลมแบตไฮบริดระดับ ' + lvl + ' แล้วครับ'));\n"
"}\n"
"function scanDTCRemote(){\n"
"  sendCmd('dtc_scan', '1', 1);\n"
"  document.getElementById('dtcResultBox').innerText = '🔍 กำลังสแกนกล่องเครื่องยนต์, ไฮบริด, แบต HV และ ABS...';\n"
"  showCarToast('🔍 ส่งคำสั่งสแกนโค้ดไฟโชว์ไปที่รถแล้วครับ');\n"
"}\n"
"function clearDTCRemote(){\n"
"  if(!confirm('ยืนยันส่งคำสั่งลบโค้ดไฟโชว์ (Clear Prius DTCs) ทั้งหมดหรือไม่ครับ?')) return;\n"
"  sendCmd('dtc_clear', '1', 1);\n"
"  showCarToast('🧹 ส่งคำสั่งลบโค้ดไฟโชว์เรียบร้อยครับ');\n"
"}\n"
"function render14Blocks(blocks){\n"
"  var g = document.getElementById('hvBlocksGrid');\n"
"  if(!g) return;\n"
"  var arr = (Array.isArray(blocks) && blocks.length >= 14) ? blocks : [];\n"
"  var html = '';\n"
"  for(var i=0;i<14;i++){\n"
"    var v = arr.length ? Number(arr[i] || 0) : 0;\n"
"    var pct = v > 10 ? Math.max(12, Math.min(100, Math.round(((v - 14.2) / 2.6) * 100))) : 18;\n"
"    html += '<div class=\"blk-cell\"><div class=\"blk-id\">B' + (i+1) + '</div><div class=\"blk-bar-bg\"><div class=\"blk-bar-fill\" style=\"height:' + pct + '%;\"></div></div><div class=\"blk-v\">' + (v > 1 ? v.toFixed(2) : '--') + '</div></div>';\n"
"  }\n"
"  g.innerHTML = html;\n"
"}\n"
"function saveRealOdo(){\n"
"  var v = Number((document.getElementById('odoInput').value || '').trim());\n"
"  if(!v || v < 0){ showCarToast('⚠️ กรุณาพิมพ์ตัวเลขไมล์รถปัจจุบันก่อนครับ'); return; }\n"
"  var x = new XMLHttpRequest();\n"
"  x.open('GET', '/api/carhealth?op=set_odo&km=' + encodeURIComponent(v) + '&t=' + Date.now(), true);\n"
"  x.onload = function(){ document.getElementById('odoInput').value = ''; showCarToast('✅ บันทึกเลขไมล์รถ ' + v.toLocaleString() + ' กม. เรียบร้อย!'); loadCarHealthDetail(); };\n"
"  x.send();\n"
"}\n"
"function resetMaintItem(key, label){\n"
"  if(!confirm('บันทึกว่าเพิ่งเปลี่ยน/ทำรายการ \"' + label + '\" ที่เลขไมล์ปัจจุบันใช่ไหมครับ?')) return;\n"
"  var x = new XMLHttpRequest();\n"
"  x.open('GET', '/api/carhealth?op=reset&item=' + encodeURIComponent(key) + '&t=' + Date.now(), true);\n"
"  x.onload = function(){ showCarToast('✅ เริ่มนับระยะ ' + label + ' ใหม่เรียบร้อย!'); loadCarHealthDetail(); };\n"
"  x.send();\n"
"}\n"
"function cleanIpadCacheRemote(){\n"
"  showCarToast('🧹 กำลังล้างไฟล์แคชชั่วคราวและคืนแรมบน iPad...');\n"
"  sendCmd('clean_cache', '1', 1);\n"
"  var x = new XMLHttpRequest();\n"
"  x.open('GET', '/api/carhealth?op=clean_cache&t=' + Date.now(), true);\n"
"  x.onload = function(){ showCarToast('✅ เคลียร์แคชและคืนแรม iPad เรียบร้อย! (ประวัติทริป/คิวเพลง/หมุดแผนที่อยู่ครบ 100%)'); };\n"
"  x.send();\n"
"}\n"
"function loadCarHealthDetail(){\n"
"  var x = new XMLHttpRequest();\n"
"  x.open('GET', '/api/carhealth?t=' + Date.now(), true);\n"
"  x.onload = function(){\n"
"    if(x.status !== 200) return;\n"
"    try {\n"
"      var r = JSON.parse(x.responseText);\n"
"      document.getElementById('curOdoTxt').innerText = 'ไมล์รถ ' + Math.round(r.currentOdo || 0).toLocaleString() + ' กม.';\n"
"      document.getElementById('sum30Km').innerText = Number(r.sum30Km || 0).toFixed(1) + ' กม.';\n"
"      document.getElementById('sum30Trips').innerText = (r.sum30Trips || 0) + ' ทริป • ' + (r.activeDays || 0) + ' วันที่มีขับ';\n"
"      document.getElementById('sum30Cost').innerText = '฿' + Math.round(Number(r.sum30Cost || 0)).toLocaleString();\n"
"      document.getElementById('sum30Fuel').innerText = Number(r.sum30Fuel || 0).toFixed(1) + ' L • เฉลี่ย ' + (r.avgKmL || '--') + ' km/L';\n"
"      var dBox = document.getElementById('dailyTripList');\n"
"      if(Array.isArray(r.days) && r.days.length > 0){\n"
"        dBox.innerHTML = r.days.map(function(dy){\n"
"          return '<div class=\"tlog-row\"><span style=\"color:#bfeaff;font-weight:800;\">📅 ' + dy.date + ' (' + dy.trips + ' ทริป)</span><span style=\"color:#fff;font-weight:900;\">' + Number(dy.km).toFixed(1) + ' กม. • <span style=\"color:#22ff88;\">฿' + Math.round(dy.cost) + '</span> (' + Number(dy.fuelL).toFixed(2) + 'L)</span></div>';\n"
"        }).join('');\n"
"      } else {\n"
"        dBox.innerHTML = '<div class=\"hint\">ยังไม่มีประวัติการวิ่งที่มีระยะทางบันทึกไว้</div>';\n"
"      }\n"
"      var mBox = document.getElementById('maintListBox');\n"
"      if(Array.isArray(r.maint)){\n"
"        mBox.innerHTML = r.maint.map(function(m){\n"
"          var used = Math.max(0, (r.currentOdo || 0) - (m.lastOdo || 0));\n"
"          var rem = Math.max(0, m.interval - used);\n"
"          var pct = Math.min(100, Math.round((used / m.interval) * 100));\n"
"          var warn = rem <= 1000;\n"
"          return '<div class=\"m-row\"><div class=\"m-top\"><div class=\"m-title\">' + m.title + '</div><button class=\"q-mini\" onclick=\"resetMaintItem(\\'' + m.key + '\\',\\'' + m.title + '\\')\">🔄 รีเซ็ต</button></div><div class=\"m-sub\">วิ่งไป ' + Math.round(used).toLocaleString() + ' / ' + m.interval.toLocaleString() + ' กม. • <span style=\"color:' + (warn ? '#ff6b7a' : '#22ff88') + ';\">' + (rem > 0 ? ('เหลืออีก ' + Math.round(rem).toLocaleString() + ' กม.') : '⚠️ ถึงกำหนดเช็กระยะแล้ว!') + '</span></div><div class=\"pbar\"><div class=\"pfill' + (warn ? ' warn' : '') + '\" style=\"width:' + pct + '%;\"></div></div></div>';\n"
"        }).join('');\n"
"      }\n"
"    } catch(e){}\n"
"  };\n"
"  x.send();\n"
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
"function sendCmd(action, value, autoStart, mode, cb){\n"
"  var xhr = new XMLHttpRequest();\n"
"  var url = '/api/cmd?action=' + encodeURIComponent(action) + '&value=' + encodeURIComponent(value || '') + '&auto=' + (autoStart ? '1' : '0') + '&mode=' + encodeURIComponent(mode || '') + '&t=' + Date.now();\n"
"  xhr.open('GET', url, true);\n"
"  xhr.onload = function(){ if(cb) cb(xhr.status === 200); };\n"
"  xhr.onerror = function(){ if(cb) cb(false); };\n"
"  xhr.send();\n"
"}\n"
"function sendMap(autoStart, mode){\n"
"  var v = (document.getElementById('mapInput').value || '').trim();\n"
"  if(!v){ showToast('⚠️ กรุณาวางลิงก์ Google Maps หรือพิมพ์ชื่อสถานที่ก่อนครับ'); return; }\n"
"  saveRecent(v);\n"
"  showToast('🚀 ส่งเข้าจอ CarDash แล้ว! ปิดจอมือถือได้เลยครับ');\n"
"  sendCmd('nav', v, autoStart, mode || 'carplay', function(ok){\n"
"    if(ok) showToast('✅ เส้นทาง Apple CarPlay ขึ้นจอรถเรียบร้อย! ปิดมือถือได้เลย');\n"
"  });\n"
"}\n"
"function quickDest(q){\n"
"  document.getElementById('mapInput').value = q;\n"
"  sendMap(1, 'carplay');\n"
"}\n"
"function pasteAndSendMap(mode){\n"
"  if(navigator.clipboard && navigator.clipboard.readText){\n"
"    navigator.clipboard.readText().then(function(txt){\n"
"      if(txt && txt.trim().length > 0){\n"
"        document.getElementById('mapInput').value = txt.trim();\n"
"        sendMap(1, mode || 'carplay');\n"
"      } else {\n"
"        document.getElementById('mapInput').focus();\n"
"        showToast('📋 แตะค้างที่ช่องด้านบนแล้วกด วาง (Paste) ได้เลยครับ');\n"
"      }\n"
"    }).catch(function(){\n"
"      var v = (document.getElementById('mapInput').value || '').trim();\n"
"      if(v.length > 0){ sendMap(1, mode || 'carplay'); return; }\n"
"      document.getElementById('mapInput').focus();\n"
"      showToast('📋 แตะค้างในช่องข้อความเพื่อวางลิงก์ Google Maps แล้วกดนำทางครับ');\n"
"    });\n"
"  } else {\n"
"    var v = (document.getElementById('mapInput').value || '').trim();\n"
"    if(v.length > 0){ sendMap(1, mode || 'carplay'); return; }\n"
"    document.getElementById('mapInput').focus();\n"
"    showToast('📋 แตะค้างในช่องข้อความเพื่อวางลิงก์ Google Maps แล้วกดนำทางครับ');\n"
"  }\n"
"}\n"
"var songQueue = [];\n"
"var activeQueueIdx = -1;\n"
"var lastSyncedRev = -1;\n"
"var importedLocalOnce = false;\n"
"try { songQueue = JSON.parse(localStorage.getItem('trd_song_queue_v1') || '[]'); } catch(e){ songQueue = []; }\n"
"function pushQueueOp(qs){\n"
"  var x = new XMLHttpRequest();\n"
"  x.open('GET', '/api/queue?' + qs + '&t=' + Date.now(), true);\n"
"  x.onload = function(){\n"
"    if(x.status === 200){\n"
"      try {\n"
"        var r = JSON.parse(x.responseText);\n"
"        if(r && Array.isArray(r.queue)){ songQueue = r.queue; activeQueueIdx = (typeof r.queueIdx === 'number') ? r.queueIdx : -1; lastSyncedRev = r.queueRev || 0; try { localStorage.setItem('trd_song_queue_v1', JSON.stringify(songQueue)); } catch(e){} renderSongQueue(); }\n"
"      } catch(e){}\n"
"    }\n"
"  };\n"
"  x.send();\n"
"}\n"
"function saveSongQueue(){ try { localStorage.setItem('trd_song_queue_v1', JSON.stringify(songQueue)); } catch(e){} renderSongQueue(); }\n"
"function renderSongQueue(){\n"
"  var box = document.getElementById('queueListBox');\n"
"  var cnt = document.getElementById('queueCountTxt');\n"
"  var prow = document.getElementById('queuePlayRow');\n"
"  cnt.innerText = '📋 คิวเพลงเล่นต่อเนื่อง (' + songQueue.length + ' เพลง)';\n"
"  if(!songQueue.length){\n"
"    box.innerHTML = '<div class=\"hint\" style=\"margin:2px 0 4px;\">กด 🔍 ค้นหา แล้วแตะ <b>+คิว</b> เรียงเพลง 1, 2, 3, 4 เพื่อเล่นต่อเนื่องโดยไม่ต้องค้นหาซ้ำครับ</div>';\n"
"    prow.style.display = 'none';\n"
"    return;\n"
"  }\n"
"  prow.style.display = '-webkit-flex'; prow.style.display = 'flex';\n"
"  box.innerHTML = '';\n"
"  songQueue.forEach(function(it, idx){\n"
"    var row = document.createElement('div');\n"
"    row.className = 'q-item' + (idx === activeQueueIdx ? ' playing' : '');\n"
"    var num = document.createElement('span');\n"
"    num.className = 'q-num';\n"
"    num.innerText = (idx === activeQueueIdx ? '▶' : (idx + 1) + '.');\n"
"    var nm = document.createElement('div');\n"
"    nm.className = 'q-name';\n"
"    nm.innerText = it.title;\n"
"    nm.onclick = function(){ playFullQueue(lastQueueMode || 'yt', idx); };\n"
"    var ytB = document.createElement('button');\n"
"    ytB.className = 'q-mini yt';\n"
"    ytB.innerText = '📺';\n"
"    ytB.onclick = function(){ playFullQueue('yt', idx); };\n"
"    var del = document.createElement('button');\n"
"    del.className = 'q-del';\n"
"    del.innerText = '✕';\n"
"    del.onclick = function(){ songQueue.splice(idx, 1); saveSongQueue(); pushQueueOp('op=del&idx=' + idx); };\n"
"    row.appendChild(num); row.appendChild(nm); row.appendChild(ytB); row.appendChild(del);\n"
"    box.appendChild(row);\n"
"  });\n"
"}\n"
"var lastQueueMode = 'yt';\n"
"function addTrackObjToQueue(id, title){\n"
"  if(songQueue.length >= 25){ showMediaToast('⚠️ คิวเต็ม 25 เพลงแล้วครับ'); return; }\n"
"  songQueue.push({id: id || '', title: title});\n"
"  saveSongQueue();\n"
"  pushQueueOp('op=add&id=' + encodeURIComponent(id || '') + '&title=' + encodeURIComponent(title || ''));\n"
"  showMediaToast('➕ เพิ่มลำดับที่ ' + songQueue.length + ': ' + title);\n"
"}\n"
"var sugTimer = null;\n"
"function onSongTyping(){\n"
"  if(sugTimer) clearTimeout(sugTimer);\n"
"  var v = (document.getElementById('songInput').value || '').trim();\n"
"  var sbox = document.getElementById('ytSuggestChips');\n"
"  if(v.length < 2 || v.indexOf('http') === 0){ sbox.style.display = 'none'; return; }\n"
"  sugTimer = setTimeout(function(){\n"
"    var x = new XMLHttpRequest();\n"
"    x.open('GET', '/api/ytsuggest?q=' + encodeURIComponent(v) + '&t=' + Date.now(), true);\n"
"    x.onload = function(){\n"
"      if(x.status === 200){\n"
"        try {\n"
"          var arr = JSON.parse(x.responseText);\n"
"          if(!arr || !arr.length){ sbox.style.display = 'none'; return; }\n"
"          sbox.innerHTML = '';\n"
"          arr.slice(0, 6).forEach(function(w){\n"
"            var c = document.createElement('span'); c.className = 'chip'; c.innerText = '✨ ' + w;\n"
"            c.onclick = function(){ document.getElementById('songInput').value = w; sbox.style.display = 'none'; searchYTList(); };\n"
"            sbox.appendChild(c);\n"
"          });\n"
"          sbox.style.display = '-webkit-flex'; sbox.style.display = 'flex';\n"
"        } catch(e){}\n"
"      }\n"
"    };\n"
"    x.send();\n"
"  }, 220);\n"
"}\n"
"function addInputToQueue(){\n"
"  var s = (document.getElementById('songInput').value || '').trim();\n"
"  if(!s){ showMediaToast('⚠️ พิมพ์ชื่อเพลงก่อนกด +เพิ่มคิว ครับ'); document.getElementById('songInput').focus(); return; }\n"
"  document.getElementById('songInput').value = '';\n"
"  document.getElementById('ytSuggestChips').style.display = 'none';\n"
"  showMediaToast('🔍 กำลังเทียบชื่อเพลงที่ถูกต้องเข้าคิว...');\n"
"  var x = new XMLHttpRequest();\n"
"  x.open('GET', '/api/ytsearch?q=' + encodeURIComponent(s) + '&t=' + Date.now(), true);\n"
"  x.onload = function(){\n"
"    try {\n"
"      var arr = JSON.parse(x.responseText);\n"
"      if(arr && arr.length > 0){ addTrackObjToQueue(arr[0].id, arr[0].title); return; }\n"
"    } catch(e){}\n"
"    addTrackObjToQueue('', s);\n"
"  };\n"
"  x.onerror = function(){ addTrackObjToQueue('', s); };\n"
"  x.send();\n"
"}\n"
"function clearSongQueue(){\n"
"  songQueue = []; activeQueueIdx = -1; saveSongQueue();\n"
"  pushQueueOp('op=clear');\n"
"  showMediaToast('🗑️ ล้างคิวเพลงเรียบร้อยครับ');\n"
"}\n"
"function playFullQueue(target, startIdx){\n"
"  if(!songQueue.length) return;\n"
"  lastQueueMode = target;\n"
"  var idx = startIdx || 0;\n"
"  activeQueueIdx = idx;\n"
"  renderSongQueue();\n"
"  pushQueueOp('op=setidx&idx=' + idx);\n"
"  var tokens = songQueue.map(function(x){ return (x.id && x.id.length === 11) ? (x.id + '::' + x.title.replace(/\\|\\|/g,' ')) : x.title.replace(/\\|\\|/g,' '); });\n"
"  var joined = tokens.join('||');\n"
"  if(target === 'yt'){\n"
"    sendCmd('youtube_queue', joined, 1, String(idx));\n"
"    showMediaToast('📺 เริ่มเล่นคิว YouTube เพลงที่ ' + (idx + 1) + '/' + songQueue.length + ' ต่อเนื่องครับ!');\n"
"  } else {\n"
"    sendCmd('music_queue', joined, 1, String(idx));\n"
"    showMediaToast('🎵 เริ่มเล่นคิวแอปเพลง ' + (idx + 1) + '/' + songQueue.length + ' ต่อเนื่องครับ!');\n"
"  }\n"
"}\n"
"function searchYTList(){\n"
"  var s = (document.getElementById('songInput').value || '').trim();\n"
"  if(!s){ showMediaToast('⚠️ พิมพ์ชื่อเพลงหรือศิลปินที่ต้องการค้นหาก่อนครับ'); document.getElementById('songInput').focus(); return; }\n"
"  var box = document.getElementById('ytResultsBox');\n"
"  box.style.display = 'block';\n"
"  box.innerHTML = '<div class=\"sr-row\"><div class=\"sr-txt\">🔍 กำลังค้นหา \"' + s + '\"...</div></div>';\n"
"  var x = new XMLHttpRequest();\n"
"  x.open('GET', '/api/ytsearch?q=' + encodeURIComponent(s) + '&t=' + Date.now(), true);\n"
"  x.onload = function(){\n"
"    if(x.status === 200){\n"
"      try {\n"
"        var arr = JSON.parse(x.responseText);\n"
"        if(!arr || !arr.length){ box.innerHTML = '<div class=\"sr-row\"><div class=\"sr-txt\">ไม่พบรายการ ลองพิมพ์คำอื่นครับ</div></div>'; return; }\n"
"        box.innerHTML = '';\n"
"        arr.forEach(function(it){\n"
"          var r = document.createElement('div'); r.className = 'sr-row';\n"
"          var tx = document.createElement('div'); tx.className = 'sr-txt';\n"
"          tx.innerText = it.title;\n"
"          if(it.sub){ var sb = document.createElement('div'); sb.className = 'sr-sub'; sb.innerText = it.sub; tx.appendChild(sb); }\n"
"          var bAdd = document.createElement('button'); bAdd.className = 'q-mini'; bAdd.innerText = '➕ คิว';\n"
"          bAdd.onclick = function(){ addTrackObjToQueue(it.id, it.title); };\n"
"          var bYT = document.createElement('button'); bYT.className = 'q-mini yt'; bYT.innerText = '📺 เล่น';\n"
"          bYT.onclick = function(){ sendCmd('youtube_search', it.id, 1); showMediaToast('📺 เล่นบน YouTube: ' + it.title); box.style.display = 'none'; };\n"
"          r.appendChild(tx); r.appendChild(bAdd); r.appendChild(bYT);\n"
"          box.appendChild(r);\n"
"        });\n"
"      } catch(e){ box.innerHTML = '<div class=\"sr-row\"><div class=\"sr-txt\">เกิดข้อผิดพลาดในการอ่านผลลัพธ์</div></div>'; }\n"
"    }\n"
"  };\n"
"  x.onerror = function(){ box.innerHTML = '<div class=\"sr-row\"><div class=\"sr-txt\">เชื่อมต่อค้นหาไม่สำเร็จ</div></div>'; };\n"
"  x.send();\n"
"}\n"
"function showMediaToast(msg){\n"
"  var t = document.getElementById('mediaToast');\n"
"  if(!t){ showToast(msg); return; }\n"
"  t.innerText = msg; t.style.display = 'block';\n"
"  setTimeout(function(){ t.style.display = 'none'; }, 4200);\n"
"}\n"
"function sendSongSearch(){\n"
"  var s = (document.getElementById('songInput').value || '').trim();\n"
"  if(!s){ if(songQueue.length > 0){ playFullQueue('music', 0); return; } showMediaToast('⚠️ พิมพ์ชื่อเพลงหรือเลือกเข้าคิวก่อนครับ'); document.getElementById('songInput').focus(); return; }\n"
"  sendCmd('music_search', s, 1);\n"
"  showMediaToast('🎵 ส่งไปเล่นเพลงบน audioNINJA แล้ว: ' + s);\n"
"  document.getElementById('songInput').value = '';\n"
"}\n"
"function sendYouTubeSearch(){\n"
"  var s = (document.getElementById('songInput').value || '').trim();\n"
"  if(!s){ if(songQueue.length > 0){ playFullQueue('yt', 0); return; } sendCmd('screen','youtube'); showMediaToast('📺 เปิดหน้าแอป YouTube บนไอแพดแล้วครับ'); return; }\n"
"  sendCmd('youtube_search', s, 1);\n"
"  showMediaToast('📺 กำลังเปิดวิดีโอ YouTube บนไอแพด: ' + s);\n"
"  document.getElementById('songInput').value = '';\n"
"}\n"
"renderSongQueue();\n"
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
"        var obdP = document.getElementById('obdLivePill');\n"
"        if(obdP){ obdP.className = 'live-pill' + (d.obdOk ? '' : ' off'); obdP.innerText = d.obdOk ? '● OBD2 เชื่อมต่อสด' : '○ รอบิดสวิตช์รถ'; }\n"
"        document.getElementById('hvPackTxt').innerText = (Number(d.hvPackV || 0) > 10 ? d.hvPackV : '--') + ' V';\n"
"        document.getElementById('hvAmpTxt').innerText = (d.hvPackA || '+0.0') + ' A • SOC ' + soc + '%';\n"
"        var dv = Number(d.hvDeltaV || 0);\n"
"        document.getElementById('hvDeltaTxt').innerText = (Array.isArray(d.hvBlocks) && d.hvBlocks.length >= 14 && Number(d.hvBlocks[0]) > 1) ? (dv.toFixed(2) + ' V') : '-- V';\n"
"        document.getElementById('hvGradeTxt').innerText = (Array.isArray(d.hvBlocks) && d.hvBlocks.length >= 14 && Number(d.hvBlocks[0]) > 1) ? (dv <= 0.15 ? '✅ สมดุลดีเยี่ยม' : (dv <= 0.30 ? '👍 ปกติดี' : '⚠️ ควรตรวจเช็กเซลล์')) : 'รออ่านค่า 14 บล็อกตอนติดเครื่อง';\n"
"        document.getElementById('hvTempBig').innerText = (d.hvC || '--') + ' °C';\n"
"        document.getElementById('hvInletTxt').innerText = 'ลมเข้า ' + (d.hvInC || '--') + '°C • พัดลม ' + (d.fan || 'AUTO');\n"
"        document.getElementById('auxBigTxt').innerText = (d.aux12v || '--') + ' V';\n"
"        document.getElementById('ectInvTxt').innerText = 'เครื่อง ' + (d.ect || '--') + '°C • INV ' + (d.invC || '--') + '°C';\n"
"        render14Blocks(d.hvBlocks);\n"
"        var dtcBox = document.getElementById('dtcResultBox');\n"
"        if(dtcBox){\n"
"          if(d.dtcBusy) dtcBox.innerText = '🔍 กำลังสแกนโค้ดไฟโชว์ Prius ทุกกล่อง...';\n"
"          else if(Array.isArray(d.dtcList) && d.dtcList.length > 0) dtcBox.innerText = '🚨 พบโค้ดแจ้งเตือน (' + d.dtcList.length + '): ' + d.dtcList.join(' | ');\n"
"          else if(d.dtcTime) dtcBox.innerText = '✅ ไม่พบรหัสไฟโชว์ผิดปกติ (สแกนล่าสุด ' + d.dtcTime + ')';\n"
"        }\n"
"        var songStr = d.song ? ('🎵 ' + d.song) : '🎵 พร้อมเล่นเพลง (audioNINJA / YouTube)';\n"
"        document.getElementById('remoteSongTxt').innerText = songStr;\n"
"        document.getElementById('songTxt').innerText = songStr;\n"
"        if(Array.isArray(d.queue)){\n"
"          if(!importedLocalOnce && d.queue.length === 0 && songQueue.length > 0){\n"
"            importedLocalOnce = true;\n"
"            songQueue.forEach(function(it){ pushQueueOp('op=add&id=' + encodeURIComponent(it.id || '') + '&title=' + encodeURIComponent(it.title || '')); });\n"
"          } else if(d.queueRev !== lastSyncedRev || d.queueIdx !== activeQueueIdx){\n"
"            importedLocalOnce = true;\n"
"            lastSyncedRev = d.queueRev || 0;\n"
"            songQueue = d.queue;\n"
"            activeQueueIdx = (typeof d.queueIdx === 'number') ? d.queueIdx : -1;\n"
"            try { localStorage.setItem('trd_song_queue_v1', JSON.stringify(songQueue)); } catch(e){}\n"
"            renderSongQueue();\n"
"          }\n"
"        }\n"
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

static void collectYTVideoRenderers(id node, NSMutableArray *out, NSMutableSet *seen) {
  if (!node || out.count >= 8) return;
  if ([node isKindOfClass:[NSDictionary class]]) {
    NSDictionary *d = (NSDictionary *)node;
    NSDictionary *vr = [d[@"videoRenderer"] isKindOfClass:[NSDictionary class]] ? d[@"videoRenderer"] : nil;
    if (vr) {
      NSString *vid = [vr[@"videoId"] isKindOfClass:[NSString class]] ? vr[@"videoId"] : @"";
      if (vid.length == 11 && ![seen containsObject:vid]) {
        NSString *title = @"";
        NSDictionary *tDict = [vr[@"title"] isKindOfClass:[NSDictionary class]] ? vr[@"title"] : nil;
        if ([tDict[@"simpleText"] isKindOfClass:[NSString class]]) {
          title = tDict[@"simpleText"];
        } else if ([tDict[@"runs"] isKindOfClass:[NSArray class]] && [tDict[@"runs"] count] > 0) {
          NSMutableString *ms = [NSMutableString string];
          for (id r in tDict[@"runs"]) {
            if ([r isKindOfClass:[NSDictionary class]] && [r[@"text"] isKindOfClass:[NSString class]]) [ms appendString:r[@"text"]];
          }
          title = ms;
        }
        NSString *dur = @"";
        NSDictionary *lDict = [vr[@"lengthText"] isKindOfClass:[NSDictionary class]] ? vr[@"lengthText"] : nil;
        if ([lDict[@"simpleText"] isKindOfClass:[NSString class]]) dur = lDict[@"simpleText"];
        NSString *chan = @"";
        NSDictionary *oDict = [vr[@"ownerText"] isKindOfClass:[NSDictionary class]] ? vr[@"ownerText"] : nil;
        if ([oDict[@"runs"] isKindOfClass:[NSArray class]] && [oDict[@"runs"] count] > 0) {
          id r0 = oDict[@"runs"][0];
          if ([r0 isKindOfClass:[NSDictionary class]] && [r0[@"text"] isKindOfClass:[NSString class]]) chan = r0[@"text"];
        }
        if (title.length > 0) {
          [seen addObject:vid];
          NSString *sub = (chan.length && dur.length) ? [NSString stringWithFormat:@"%@ • %@", chan, dur] : (chan.length ? chan : dur);
          [out addObject:@{@"id": vid, @"title": title, @"sub": sub ?: @""}];
        }
      }
      return;
    }
    for (id k in d) {
      collectYTVideoRenderers(d[k], out, seen);
      if (out.count >= 8) return;
    }
  } else if ([node isKindOfClass:[NSArray class]]) {
    for (id it in (NSArray *)node) {
      collectYTVideoRenderers(it, out, seen);
      if (out.count >= 8) return;
    }
  }
}

static NSString *performYTSearchJSON(NSString *q) {
  NSString *clean = [q stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!clean.length) return @"[]";
  NSURL *u = [NSURL URLWithString:@"https://www.youtube.com/youtubei/v1/search?prettyPrint=false"];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5.0];
  req.HTTPMethod = @"POST";
  [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [req setValue:@"contents.twoColumnSearchResultsRenderer.primaryContents.sectionListRenderer.contents.itemSectionRenderer.contents.videoRenderer(videoId,title,lengthText,ownerText)" forHTTPHeaderField:@"X-Goog-FieldMask"];
  NSDictionary *body = @{
    @"context": @{@"client": @{@"clientName": @"WEB", @"clientVersion": @"2.20240726.00.00", @"hl": @"th", @"gl": @"TH"}},
    @"query": clean
  };
  req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  __block NSData *respData = nil;
  [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e){
    respData = d;
    dispatch_semaphore_signal(sem);
  }] resume];
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.2 * NSEC_PER_SEC)));
  if (!respData.length) return @"[]";
  id root = [NSJSONSerialization JSONObjectWithData:respData options:0 error:nil];
  NSMutableArray *items = [NSMutableArray array];
  collectYTVideoRenderers(root, items, [NSMutableSet set]);
  NSData *out = [NSJSONSerialization dataWithJSONObject:items options:0 error:nil];
  return out ? ([[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding] ?: @"[]") : @"[]";
}

static NSString *performYTSuggestJSON(NSString *q) {
  NSString *clean = [q stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (!clean.length) return @"[]";
  NSString *enc = [clean stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: @"";
  NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&hl=th&q=%@", enc]];
  if (!u) return @"[]";
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:2.5];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  __block NSData *respData = nil;
  [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e){
    respData = d;
    dispatch_semaphore_signal(sem);
  }] resume];
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.7 * NSEC_PER_SEC)));
  if (!respData.length) return @"[]";
  id root = [NSJSONSerialization JSONObjectWithData:respData options:0 error:nil];
  if ([root isKindOfClass:[NSArray class]] && [root count] >= 2 && [root[1] isKindOfClass:[NSArray class]]) {
    NSData *out = [NSJSONSerialization dataWithJSONObject:root[1] options:0 error:nil];
    if (out) return [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding] ?: @"[]";
  }
  return @"[]";
}

static NSString *const kSharedQueuePath = @"/var/mobile/codex-car/shared-song-queue.plist";
static NSObject *sQueueLock = nil;

static NSDictionary *readSharedQueueState(void) {
  if (!sQueueLock) sQueueLock = [NSObject new];
  @synchronized(sQueueLock) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kSharedQueuePath];
    NSArray *items = [d[@"items"] isKindOfClass:[NSArray class]] ? d[@"items"] : @[];
    NSInteger idx = d[@"activeIdx"] ? [d[@"activeIdx"] integerValue] : -1;
    NSInteger rev = [d[@"rev"] integerValue];
    NSDictionary *ytSt = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/youtube-search-state.plist"];
    if ([ytSt[@"queueCount"] integerValue] == (NSInteger)items.count && items.count > 0 && ytSt[@"queueIdx"]) {
      NSInteger yIdx = [ytSt[@"queueIdx"] integerValue];
      if (yIdx >= 0 && yIdx < (NSInteger)items.count) idx = yIdx;
    }
    return @{@"items": items, @"activeIdx": @(idx), @"rev": @(rev)};
  }
}

static NSString *mutateSharedQueueJSON(NSDictionary *params) {
  if (!sQueueLock) sQueueLock = [NSObject new];
  @synchronized(sQueueLock) {
    NSDictionary *cur = [NSDictionary dictionaryWithContentsOfFile:kSharedQueuePath];
    NSMutableArray *items = [cur[@"items"] isKindOfClass:[NSArray class]] ? [cur[@"items"] mutableCopy] : [NSMutableArray array];
    NSInteger idx = cur[@"activeIdx"] ? [cur[@"activeIdx"] integerValue] : -1;
    NSInteger rev = [cur[@"rev"] integerValue] + 1;
    NSString *op = params[@"op"] ?: @"";
    if ([op isEqualToString:@"add"]) {
      NSString *vid = params[@"id"] ?: @"";
      NSString *title = [params[@"title"] ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if (title.length > 0 && items.count < 25) {
        [items addObject:@{@"id": vid, @"title": title}];
      }
    } else if ([op isEqualToString:@"del"]) {
      NSInteger delIdx = [params[@"idx"] integerValue];
      if (delIdx >= 0 && delIdx < (NSInteger)items.count) {
        [items removeObjectAtIndex:(NSUInteger)delIdx];
        if (idx == delIdx) idx = -1;
        else if (idx > delIdx) idx--;
      }
    } else if ([op isEqualToString:@"clear"]) {
      [items removeAllObjects];
      idx = -1;
    } else if ([op isEqualToString:@"setidx"]) {
      idx = [params[@"idx"] integerValue];
    }
    NSDictionary *saved = @{@"items": items, @"activeIdx": @(idx), @"rev": @(rev)};
    [saved writeToFile:kSharedQueuePath atomically:YES];
    NSDictionary *resp = @{@"ok": @YES, @"queue": items, @"queueIdx": @(idx), @"queueRev": @(rev)};
    NSData *jd = [NSJSONSerialization dataWithJSONObject:resp options:0 error:nil];
    return jd ? ([[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding] ?: @"{}") : @"{}";
  }
}

static NSString *const kMaintStatePath = @"/var/mobile/codex-car/maintenance-state.plist";

static NSString *buildCarHealthJSON(NSDictionary *params) {
  @autoreleasepool {
    NSDictionary *live = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/hud-live.plist"] ?: @{};
    double trackedOdo = [live[@"odoKm"] doubleValue];
    NSMutableDictionary *mState = [[NSDictionary dictionaryWithContentsOfFile:kMaintStatePath] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (!mState[@"baseOdo"]) {
      mState[@"baseOdo"] = @180000.0;
      mState[@"trackedAtSet"] = @(trackedOdo);
      mState[@"oilLastOdo"] = @180000.0;
      mState[@"fanLastOdo"] = @180000.0;
      mState[@"atfLastOdo"] = @180000.0;
      [mState writeToFile:kMaintStatePath atomically:YES];
    }
    double currentOdo = [mState[@"baseOdo"] doubleValue] + MAX(0.0, trackedOdo - [mState[@"trackedAtSet"] doubleValue]);
    NSString *op = params[@"op"] ?: @"";
    if ([op isEqualToString:@"set_odo"]) {
      double newOdo = [params[@"km"] doubleValue];
      if (newOdo > 0) {
        double prevOdo = currentOdo;
        currentOdo = newOdo;
        mState[@"baseOdo"] = @(newOdo);
        mState[@"trackedAtSet"] = @(trackedOdo);
        if (fabs(prevOdo - 180000.0) < 1.0) {
          mState[@"oilLastOdo"] = @(newOdo);
          mState[@"fanLastOdo"] = @(newOdo);
          mState[@"atfLastOdo"] = @(newOdo);
        }
        [mState writeToFile:kMaintStatePath atomically:YES];
      }
    } else if ([op isEqualToString:@"reset"]) {
      NSString *item = params[@"item"] ?: @"";
      if ([item isEqualToString:@"oil"]) mState[@"oilLastOdo"] = @(currentOdo);
      else if ([item isEqualToString:@"fan"]) mState[@"fanLastOdo"] = @(currentOdo);
      else if ([item isEqualToString:@"atf"]) mState[@"atfLastOdo"] = @(currentOdo);
      [mState writeToFile:kMaintStatePath atomically:YES];
    } else if ([op isEqualToString:@"clean_cache"]) {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        pid_t pid = 0;
        char *argv[] = { (char *)"/bin/sh", (char *)"/usr/local/bin/trd-clean-cache", NULL };
        posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
      });
    }

    NSDictionary *hist = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/trip-daily-history.plist"];
    NSDictionary *daysDict = [hist[@"days"] isKindOfClass:[NSDictionary class]] ? hist[@"days"] : @{};
    NSArray *sortedKeys = [[daysDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *recentDays = [NSMutableArray array];
    double sum30Km = 0, sum30Fuel = 0, sum30Cost = 0;
    NSInteger sum30Trips = 0, activeDays = 0;
    NSInteger startK = MAX(0, (NSInteger)sortedKeys.count - 30);
    for (NSInteger i = (NSInteger)sortedKeys.count - 1; i >= startK; i--) {
      NSString *k = sortedKeys[(NSUInteger)i];
      NSDictionary *rec = [daysDict[k] isKindOfClass:[NSDictionary class]] ? daysDict[k] : nil;
      double km = [rec[@"km"] doubleValue];
      double fl = [rec[@"fuelL"] doubleValue];
      double cs = [rec[@"cost"] doubleValue];
      NSInteger tr = [rec[@"trips"] integerValue];
      if (km >= 0.05 || tr > 0) {
        sum30Km += km; sum30Fuel += fl; sum30Cost += cs; sum30Trips += MAX(1, tr); activeDays++;
        if (recentDays.count < 14) {
          [recentDays addObject:@{@"date": k, @"km": @(km), @"fuelL": @(fl), @"cost": @(cs), @"trips": @(MAX(1, tr))}];
        }
      }
    }
    NSString *avgKmL = (sum30Fuel > 0.05) ? [NSString stringWithFormat:@"%.1f", sum30Km / sum30Fuel] : @"--";
    NSArray *maint = @[
      @{@"key": @"oil", @"title": @"🛢️ น้ำมันเครื่องสังเคราะห์แท้", @"interval": @10000, @"lastOdo": mState[@"oilLastOdo"] ?: @(currentOdo)},
      @{@"key": @"fan", @"title": @"🌀 ล้างพัดลม & กรองแบตไฮบริด HV", @"interval": @20000, @"lastOdo": mState[@"fanLastOdo"] ?: @(currentOdo)},
      @{@"key": @"atf", @"title": @"⚙️ น้ำมันเกียร์ไฮบริด Toyota ATF WS", @"interval": @40000, @"lastOdo": mState[@"atfLastOdo"] ?: @(currentOdo)}
    ];
    NSDictionary *out = @{
      @"currentOdo": @(currentOdo),
      @"sum30Km": @(sum30Km),
      @"sum30Fuel": @(sum30Fuel),
      @"sum30Cost": @(sum30Cost),
      @"sum30Trips": @(sum30Trips),
      @"activeDays": @(activeDays),
      @"avgKmL": avgKmL,
      @"days": recentDays,
      @"maint": maint
    };
    NSData *jd = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
    return jd ? ([[NSString alloc] initWithData:jd encoding:NSUTF8StringEncoding] ?: @"{}") : @"{}";
  }
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

    NSDictionary *qState = readSharedQueueState();
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
      @"hvInC": live[@"hvInC"] ?: @"--",
      @"hvPackV": live[@"hvPackV"] ?: @"0.0",
      @"hvPackA": live[@"hvPackA"] ?: @"+0.0",
      @"hvDeltaV": live[@"hvDeltaV"] ?: @"0.00",
      @"hvBlocks": live[@"hvBlocks"] ?: @[],
      @"obdOk": live[@"obdOk"] ?: @NO,
      @"dtcBusy": live[@"dtcBusy"] ?: @NO,
      @"dtcList": live[@"dtcList"] ?: @[],
      @"dtcTime": live[@"dtcTime"] ?: @"",
      @"fan": live[@"fan"] ?: @"AUTO",
      @"fuelL": live[@"fuelL"] ?: @"--",
      @"rangeKm": live[@"rangeKm"] ?: @"--",
      @"aux12v": live[@"aux12v"] ?: @"--",
      @"hybridMode": live[@"hybridMode"] ?: @"EV READY",
      @"song": fullSong,
      @"queue": qState[@"items"] ?: @[],
      @"queueIdx": qState[@"activeIdx"] ?: @(-1),
      @"queueRev": qState[@"rev"] ?: @0
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!jsonData) return @"{}";
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] ?: @"{}";
  }
}

static void handleClientSocket(int clientFd) {
  @autoreleasepool {
    fcntl(clientFd, F_SETFD, FD_CLOEXEC);
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
    } else if ([path isEqualToString:@"/api/ytsearch"]) {
      contentType = @"application/json; charset=utf-8";
      NSDictionary *params = parseQueryParams(query);
      bodyData = [performYTSearchJSON(params[@"q"] ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([path isEqualToString:@"/api/ytsuggest"]) {
      contentType = @"application/json; charset=utf-8";
      NSDictionary *params = parseQueryParams(query);
      bodyData = [performYTSuggestJSON(params[@"q"] ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([path isEqualToString:@"/api/queue"]) {
      contentType = @"application/json; charset=utf-8";
      NSDictionary *params = parseQueryParams(query);
      bodyData = [mutateSharedQueueJSON(params) dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([path isEqualToString:@"/api/carhealth"]) {
      contentType = @"application/json; charset=utf-8";
      NSDictionary *params = parseQueryParams(query);
      bodyData = [buildCarHealthJSON(params) dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([path isEqualToString:@"/api/cmd"]) {
      contentType = @"application/json; charset=utf-8";
      NSDictionary *params = parseQueryParams(query);
      NSString *action = params[@"action"] ?: @"";
      NSString *value = params[@"value"] ?: @"";
      NSString *mode = params[@"mode"] ?: @"";
      BOOL autoStart = [params[@"auto"] isEqualToString:@"1"];
      BOOL needStopCam = NO;
      if (action.length > 0) {
        if (([action isEqualToString:@"youtube_search"] || [action isEqualToString:@"youtube_queue"]) && value.length > 0) {
          needStopCam = YES;
          notify_post("com.codex.trd.network.internet.force");
          notify_post("com.codex.trd.music.pause");
          [@{@"bundle": @"com.himais0giiiin.ytnine", @"at": [NSDate date]} writeToFile:@"/var/mobile/codex-car/last-media.plist" atomically:YES];
          if ([action isEqualToString:@"youtube_queue"]) {
            NSArray *items = [value componentsSeparatedByString:@"||"];
            NSInteger startIdx = MAX(0, [mode integerValue]);
            [@{@"pending": @YES, @"items": items, @"startIndex": @(startIdx), @"at": [NSDate date]} writeToFile:@"/var/mobile/codex-car/youtube-search.plist" atomically:YES];
          } else {
            NSString *vid = extractDirectYTVideoID(value) ?: @"";
            [@{@"pending": @YES, @"videoId": vid, @"query": value, @"at": [NSDate date]} writeToFile:@"/var/mobile/codex-car/youtube-search.plist" atomically:YES];
          }
          notify_post("com.codex.trd.launch.ytnine");
          notify_post("com.codex.trd.youtube.search");
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            notify_post("com.codex.trd.youtube.search");
          });
        } else if (([action isEqualToString:@"music_search"] || [action isEqualToString:@"music_queue"]) && value.length > 0) {
          // Direct zero-bounce dispatch straight to audioNINJA!
          needStopCam = YES;
          notify_post("com.codex.trd.network.internet.force");
          notify_post("com.codex.trd.youtube.pause");
          [@{@"bundle": @"com.legacymusic.app", @"at": [NSDate date]} writeToFile:@"/var/mobile/codex-car/last-media.plist" atomically:YES];
          if ([action isEqualToString:@"music_queue"]) {
            NSArray *items = [value componentsSeparatedByString:@"||"];
            NSInteger startIdx = MAX(0, [mode integerValue]);
            [@{@"pending": @YES, @"items": items, @"startIndex": @(startIdx), @"query": items.firstObject ?: value, @"at": [NSDate date]} writeToFile:@"/var/mobile/codex-car/voice-search.plist" atomically:YES];
          } else {
            [@{@"pending": @YES, @"query": value, @"at": [NSDate date]} writeToFile:@"/var/mobile/codex-car/voice-search.plist" atomically:YES];
          }
          notify_post("com.codex.trd.launch.legacymusic");
          notify_post("com.codex.trd.music.voicesearch");
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.95 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            notify_post("com.codex.trd.music.voicesearch");
          });
        } else {
          NSDictionary *cmdDict = @{
            @"token": [NSUUID UUID].UUIDString ?: @"cmd",
            @"action": action,
            @"value": value,
            @"mode": mode,
            @"autoStart": @(autoStart),
            @"at": @([[NSDate date] timeIntervalSince1970])
          };
          [cmdDict writeToFile:@"/var/mobile/codex-car/mobile-cmd.plist" atomically:YES];
          notify_post("com.codex.trd.mobile.cmd");

          if ([action isEqualToString:@"screen"]) {
            if ([value isEqualToString:@"camera"]) {
              notify_post("com.codex.trd.launch.h109viewer");
            } else {
              needStopCam = YES;
              notify_post("com.codex.trd.network.internet.force");
              if ([value isEqualToString:@"youtube"]) {
                notify_post("com.codex.trd.music.pause");
                [@{@"bundle": @"com.himais0giiiin.ytnine", @"at": [NSDate date]} writeToFile:@"/var/mobile/codex-car/last-media.plist" atomically:YES];
                notify_post("com.codex.trd.launch.ytnine");
              } else if ([value isEqualToString:@"music"]) {
                notify_post("com.codex.trd.youtube.pause");
                [@{@"bundle": @"com.legacymusic.app", @"at": [NSDate date]} writeToFile:@"/var/mobile/codex-car/last-media.plist" atomically:YES];
                notify_post("com.codex.trd.launch.legacymusic");
              } else {
                notify_post("com.codex.trd.launch.cardash");
              }
            }
          } else if ([action isEqualToString:@"nav"]) {
            needStopCam = YES;
            notify_post("com.codex.trd.network.internet.force");
            notify_post("com.codex.trd.launch.cardash");
          } else if ([action isEqualToString:@"music_cmd"]) {
            NSDictionary *lm = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/codex-car/last-media.plist"];
            BOOL isYT = [lm[@"bundle"] isEqualToString:@"com.himais0giiiin.ytnine"];
            if (isYT) {
              if ([value isEqualToString:@"next"]) notify_post("com.codex.trd.youtube.next");
              else if ([value isEqualToString:@"prev"]) notify_post("com.codex.trd.youtube.previous");
              else notify_post("com.codex.trd.youtube.toggle");
            }
          }
        }
      }
      bodyData = [@"{\"ok\":true}" dataUsingEncoding:NSUTF8StringEncoding];
      NSString *cmdHdr = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\n"
        "Content-Type: %@\r\n"
        "Content-Length: %lu\r\n"
        "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
        "Pragma: no-cache\r\n"
        "Expires: 0\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Connection: close\r\n\r\n",
        contentType, (unsigned long)bodyData.length];
      NSData *cmdHdrData = [cmdHdr dataUsingEncoding:NSUTF8StringEncoding];
      if (sendAllBytes(clientFd, cmdHdrData.bytes, cmdHdrData.length)) {
        sendAllBytes(clientFd, bodyData.bytes, bodyData.length);
      }
      shutdown(clientFd, SHUT_WR);
      close(clientFd);
      if (needStopCam) stopH109ViewerIfRunning();
      return;
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
      "Cache-Control: no-store, no-cache, must-revalidate, max-age=0\r\n"
      "Pragma: no-cache\r\n"
      "Expires: 0\r\n"
      "Access-Control-Allow-Origin: *\r\n"
      "Connection: close\r\n\r\n",
      contentType, (unsigned long)bodyData.length];

    NSData *headerData = [header dataUsingEncoding:NSUTF8StringEncoding];
    if (sendAllBytes(clientFd, headerData.bytes, headerData.length) && bodyData.length > 0) {
      sendAllBytes(clientFd, bodyData.bytes, bodyData.length);
    }
    shutdown(clientFd, SHUT_WR);
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

static BOOL getCurrentEn0IPv4(struct in_addr *outAddr) {
  struct ifaddrs *ifaddr = NULL;
  BOOL found = NO;
  if (getifaddrs(&ifaddr) == 0) {
    for (struct ifaddrs *ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
      if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET || !ifa->ifa_name) continue;
      if (strcmp(ifa->ifa_name, "en0") == 0 || strcmp(ifa->ifa_name, "bridge100") == 0) {
        struct in_addr a = ((struct sockaddr_in *)ifa->ifa_addr)->sin_addr;
        uint32_t h = ntohl(a.s_addr);
        if (h != 0 && (h >> 16) != 0xA9FE && (h >> 24) != 127) {
          if (outAddr) *outAddr = a;
          found = YES;
          if (strcmp(ifa->ifa_name, "en0") == 0) break;
        }
      }
    }
    freeifaddrs(ifaddr);
  }
  return found;
}

static void dnssdRecordCallback(DNSServiceRef sdRef, DNSRecordRef RecordRef, DNSServiceFlags flags, DNSServiceErrorType errorCode, void *context) {
  // Callback required by DNSServiceRegisterRecord
}

static void startDynamicHostnameResponders(void) {
  // 1. Official Apple mDNSResponder registration for cardash.local (port 5353 owned by mDNSResponder)
  dispatch_queue_t mdnsQ = dispatch_queue_create("com.codex.trd.dnssd", DISPATCH_QUEUE_SERIAL);
  dispatch_async(mdnsQ, ^{
    __block DNSServiceRef sdConn = NULL;
    __block DNSRecordRef aRec = NULL;
    __block uint32_t registeredIP = 0;

    void (^syncDNSSD)(void) = ^{
      struct in_addr cur;
      if (!getCurrentEn0IPv4(&cur)) return;
      if (!sdConn) {
        if (DNSServiceCreateConnection(&sdConn) == kDNSServiceErr_NoError && sdConn) {
          DNSServiceSetDispatchQueue(sdConn, mdnsQ);
        } else {
          sdConn = NULL;
          return;
        }
      }
      if (!aRec) {
        DNSServiceErrorType err = DNSServiceRegisterRecord(
          sdConn, &aRec, kDNSServiceFlagsUnique, 0,
          "cardash.local.", kDNSServiceType_A, kDNSServiceClass_IN,
          4, &cur.s_addr, 120, dnssdRecordCallback, NULL
        );
        if (err != kDNSServiceErr_NoError) {
          err = DNSServiceRegisterRecord(
            sdConn, &aRec, kDNSServiceFlagsShared, 0,
            "cardash.local.", kDNSServiceType_A, kDNSServiceClass_IN,
            4, &cur.s_addr, 120, dnssdRecordCallback, NULL
          );
        }
        if (err == kDNSServiceErr_NoError) {
          registeredIP = cur.s_addr;
        } else {
          aRec = NULL;
        }
      } else if (cur.s_addr != registeredIP) {
        if (DNSServiceUpdateRecord(sdConn, aRec, 0, 4, &cur.s_addr, 120) == kDNSServiceErr_NoError) {
          registeredIP = cur.s_addr;
        } else {
          DNSServiceRefDeallocate(sdConn);
          sdConn = NULL;
          aRec = NULL;
          registeredIP = 0;
        }
      }
    };

    syncDNSSD();
    static int netTok = 0;
    notify_register_dispatch("com.codex.trd.network.changed", &netTok, mdnsQ, ^(int t){
      syncDNSSD();
    });
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, mdnsQ);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), 4 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{ syncDNSSD(); });
    dispatch_resume(timer);
    // Retain timer forever in daemon lifetime
    static dispatch_source_t sKeepTimer;
    sKeepTimer = timer;
  });

  // 2. LLMNR Responder on UDP 224.0.0.252:5355 (for http://cardash/ on Windows & Android!)
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    int fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (fd < 0) return;
    int yes = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
#ifdef SO_REUSEPORT
    setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &yes, sizeof(yes));
#endif
    struct sockaddr_in baddr;
    memset(&baddr, 0, sizeof(baddr));
    baddr.sin_family = AF_INET;
    baddr.sin_addr.s_addr = htonl(INADDR_ANY);
    baddr.sin_port = htons(5355);
    if (bind(fd, (struct sockaddr *)&baddr, sizeof(baddr)) < 0) {
      close(fd);
      return;
    }
    __block uint32_t llmnrJoined = 0;
    void (^joinLLMNR)(void) = ^{
      struct in_addr c;
      if (!getCurrentEn0IPv4(&c) || c.s_addr == llmnrJoined) return;
      if (llmnrJoined != 0) {
        struct ip_mreq oldM = { .imr_multiaddr.s_addr = inet_addr("224.0.0.252"), .imr_interface.s_addr = llmnrJoined };
        setsockopt(fd, IPPROTO_IP, IP_DROP_MEMBERSHIP, &oldM, sizeof(oldM));
      }
      struct ip_mreq m = { .imr_multiaddr.s_addr = inet_addr("224.0.0.252"), .imr_interface = c };
      setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &m, sizeof(m));
      llmnrJoined = c.s_addr;
    };
    joinLLMNR();

    uint8_t rx[512];
    while (1) {
      struct sockaddr_in src;
      socklen_t slen = sizeof(src);
      ssize_t n = recvfrom(fd, rx, sizeof(rx), 0, (struct sockaddr *)&src, &slen);
      if (n < 18) continue;
      joinLLMNR();
      uint16_t flags = (uint16_t)((rx[2] << 8) | rx[3]);
      uint16_t qdc = (uint16_t)((rx[4] << 8) | rx[5]);
      if ((flags & 0x8000) != 0 || qdc != 1) continue;
      uint8_t l = rx[12];
      if (l == 0 || 13 + l + 5 > (size_t)n || rx[13 + l] != 0) continue;
      char name[64];
      if (l >= sizeof(name)) continue;
      for (uint8_t i = 0; i < l; i++) {
        char ch = (char)rx[13 + i];
        name[i] = (ch >= 'A' && ch <= 'Z') ? (char)(ch + 32) : ch;
      }
      name[l] = '\0';
      size_t qend = 13 + l + 1;
      uint16_t qtype = (uint16_t)((rx[qend] << 8) | rx[qend + 1]);
      if ((strcmp(name, "cardash") == 0 || strcmp(name, "cardash.local") == 0) && (qtype == 1 || qtype == 255)) {
        struct in_addr cur;
        if (!getCurrentEn0IPv4(&cur)) continue;
        uint8_t resp[256];
        size_t qsecLen = (qend + 4) - 12;
        resp[0] = rx[0]; resp[1] = rx[1];
        resp[2] = 0x80; resp[3] = 0x00;
        resp[4] = 0x00; resp[5] = 0x01;
        resp[6] = 0x00; resp[7] = 0x01;
        resp[8] = 0x00; resp[9] = 0x00;
        resp[10] = 0x00; resp[11] = 0x00;
        memcpy(resp + 12, rx + 12, qsecLen);
        uint8_t *p = resp + 12 + qsecLen;
        *p++ = 0xC0; *p++ = 0x0C; // pointer to QNAME
        *p++ = 0x00; *p++ = 0x01; // TYPE A
        *p++ = 0x00; *p++ = 0x01; // CLASS IN
        *p++ = 0x00; *p++ = 0x00; *p++ = 0x00; *p++ = 0x1E; // TTL 30s
        *p++ = 0x00; *p++ = 0x04;
        memcpy(p, &cur.s_addr, 4);
        p += 4;
        sendto(fd, resp, (size_t)(p - resp), 0, (struct sockaddr *)&src, slen);
      }
    }
  });
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    signal(SIGPIPE, SIG_IGN);
    startListenerOnPort(80);
    startListenerOnPort(8080);
    startListenerOnPort(8088);
    startDynamicHostnameResponders();
    NSNetService *bonjour = [[NSNetService alloc] initWithDomain:@"local." type:@"_http._tcp." name:@"cardash" port:80];
    [bonjour scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [bonjour publish];
    [[NSRunLoop mainRunLoop] run];
  }
  return 0;
}
