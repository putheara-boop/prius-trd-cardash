#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>

static NSString *const kHUDHTML =
@"<!DOCTYPE html>\n"
"<html lang=\"th\">\n"
"<head>\n"
"<meta charset=\"utf-8\">\n"
"<meta name=\"viewport\" content=\"width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover\">\n"
"<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n"
"<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black-translucent\">\n"
"<meta name=\"apple-mobile-web-app-title\" content=\"TRD HUD\">\n"
"<title>PRIUS TRD • PRO HUD</title>\n"
"<style>\n"
"*{box-sizing:border-box;margin:0;padding:0;-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;}\n"
"html,body{width:100%;height:100%;background:#000000;color:#ffffff;font-family:-apple-system,'Helvetica Neue',Helvetica,Arial,sans-serif;overflow:hidden;}\n"
"#app{position:fixed;top:0;left:0;right:0;bottom:0;background:#000000;padding:10px 18px;display:-webkit-flex;display:flex;-webkit-flex-direction:column;flex-direction:column;-webkit-justify-content:space-between;justify-content:space-between;-webkit-transition:-webkit-transform 0.25s ease;transition:transform 0.25s ease;}\n"
"#app.mirror{-webkit-transform:scaleX(-1);transform:scaleX(-1);}\n"
"/* Themes via CSS classes on #app */\n"
"#app.t-cyan .acc{color:#00e5ff;}\n"
"#app.t-green .acc{color:#22ff88;}\n"
"#app.t-red .acc{color:#ff3848;}\n"
"/* Top minimal frameless header */\n"
".topbar{display:-webkit-flex;display:flex;-webkit-justify-content:space-between;justify-content:space-between;-webkit-align-items:center;align-items:center;padding-bottom:2px;}\n"
".status-left{display:-webkit-flex;display:flex;-webkit-align-items:center;align-items:center;font-size:13px;font-weight:800;letter-spacing:1.6px;color:#00e5ff;}\n"
".dot{width:9px;height:9px;border-radius:50%;background:#22ff88;box-shadow:0 0 10px #22ff88;display:inline-block;margin-right:8px;}\n"
".clock-wrap{display:-webkit-flex;display:flex;-webkit-align-items:center;align-items:center;cursor:pointer;}\n"
".clock-svg{width:46px;height:46px;margin-right:10px;}\n"
".clock-big{font-size:40px;font-weight:900;line-height:1;letter-spacing:1.5px;color:#ffffff;text-shadow:0 0 18px rgba(0,229,255,0.45);font-variant-numeric:tabular-nums;}\n"
".trip-txt{font-size:14px;font-weight:800;letter-spacing:1.2px;color:#7de8ff;}\n"
"/* Curved OEM HSI Power Arc across top */\n"
".hsi-wrap{width:100%;height:34px;display:-webkit-flex;display:flex;-webkit-justify-content:center;justify-content:center;-webkit-align-items:center;align-items:center;}\n"
".hsi-svg{width:92%;max-width:660px;height:34px;}\n"
"/* Frameless 3-column floating HUD stage (Zero heavy boxes!) */\n"
".stage{display:-webkit-flex;display:flex;-webkit-flex:1;flex:1;-webkit-align-items:center;align-items:center;-webkit-justify-content:space-between;justify-content:space-between;}\n"
".zone{display:-webkit-flex;display:flex;-webkit-flex-direction:column;flex-direction:column;-webkit-justify-content:center;justify-content:center;}\n"
".z-nav{width:27%;padding-right:8px;}\n"
".z-spd{width:46%;-webkit-align-items:center;align-items:center;position:relative;}\n"
".z-hyb{width:27%;padding-left:8px;-webkit-align-items:flex-end;align-items:flex-end;text-align:right;}\n"
"/* Left: Floating Navigation Turn & Compass */\n"
".nav-row{display:-webkit-flex;display:flex;-webkit-align-items:center;align-items:center;}\n"
".nav-arrow{font-size:108px;font-weight:900;line-height:0.9;color:#00e5ff;text-shadow:0 0 28px rgba(0,229,255,0.85);margin-right:12px;min-width:86px;text-align:center;}\n"
".nav-dist{font-size:30px;font-weight:900;color:#ffffff;line-height:1.05;}\n"
".nav-sub{font-size:14px;font-weight:800;color:#22ff88;letter-spacing:0.6px;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:190px;}\n"
".nav-street{font-size:16px;font-weight:700;color:#bfeaff;margin-top:8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%;}\n"
"/* Center: Giant Floating Speedometer or Sport Analog Gauge */\n"
"#digitalWrap{display:-webkit-flex;display:flex;-webkit-align-items:baseline;align-items:baseline;-webkit-justify-content:center;justify-content:center;}\n"
".speed-num{font-size:200px;font-weight:900;line-height:0.84;letter-spacing:-6px;color:#ffffff;text-shadow:0 0 38px rgba(0,229,255,0.52);margin-right:12px;font-variant-numeric:tabular-nums;}\n"
".speed-num.warn90{color:#ffaa22;text-shadow:0 0 42px rgba(255,170,34,0.85);}\n"
".speed-num.warn120{color:#ff2636;text-shadow:0 0 48px rgba(255,38,54,0.98);}\n"
".spd-side{display:-webkit-flex;display:flex;-webkit-flex-direction:column;flex-direction:column;-webkit-align-items:center;align-items:center;}\n"
".gear-badge{font-size:38px;font-weight:900;color:#22ff88;text-shadow:0 0 18px rgba(34,255,136,0.75);line-height:1;margin-bottom:4px;}\n"
".unit-txt{font-size:16px;font-weight:900;color:#00e5ff;letter-spacing:2.5px;}\n"
".limit-ring{position:absolute;top:-6px;right:8px;width:44px;height:44px;border-radius:50%;border:3.5px solid #ff2233;color:#ffffff;font-size:16px;font-weight:900;line-height:37px;text-align:center;box-shadow:0 0 14px rgba(255,34,51,0.55);}\n"
"#analogWrap{display:none;width:100%;-webkit-align-items:center;align-items:center;-webkit-justify-content:center;justify-content:center;}\n"
"#analogSvg{width:100%;max-width:350px;height:250px;}\n"
"/* Right: Floating Hybrid EV + 6-Cell Prius Battery + Live Thermals */\n"
".ev-tag{font-size:16px;font-weight:900;letter-spacing:1.6px;color:#22ff88;text-shadow:0 0 16px rgba(34,255,136,0.75);margin-bottom:8px;}\n"
".soc-big{font-size:34px;font-weight:900;color:#ffffff;line-height:1;margin-bottom:6px;}\n"
".soc-big span{font-size:13px;font-weight:800;color:#7fb2cc;margin-right:6px;}\n"
".cells{display:-webkit-flex;display:flex;-webkit-justify-content:flex-end;justify-content:flex-end;margin-bottom:10px;}\n"
".cell{width:22px;height:14px;border-radius:3px;background:#122430;margin-left:4px;}\n"
".cell.on{background:#22ff88;box-shadow:0 0 10px rgba(34,255,136,0.65);}\n"
".cell.low{background:#ff9f1c;box-shadow:0 0 10px rgba(255,159,28,0.65);}\n"
".cell.chg{background:#00e5ff;box-shadow:0 0 10px rgba(0,229,255,0.65);}\n"
".hyb-metrics{font-size:15px;font-weight:800;color:#c8e8f8;letter-spacing:0.6px;}\n"
".hyb-metrics span{margin-left:12px;}\n"
"/* Bottom floating controls (Auto-dim when driving, tap anywhere to wake) */\n"
".botbar{display:-webkit-flex;display:flex;-webkit-justify-content:space-between;justify-content:space-between;-webkit-align-items:center;align-items:center;padding-top:4px;-webkit-transition:opacity 0.4s ease;transition:opacity 0.4s ease;}\n"
".botbar.dim{opacity:0.28;}\n"
".btn-group{display:-webkit-flex;display:flex;}\n"
".btn{background:rgba(0,30,45,0.65);border:1px solid rgba(0,229,255,0.45);color:#aef4ff;padding:6px 11px;border-radius:10px;font-size:12px;font-weight:800;margin-right:7px;}\n"
".song-lbl{font-size:13px;font-weight:700;color:#7cb8d4;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:38%;text-align:right;}\n"
"@media (max-width:820px){\n"
"  .speed-num{font-size:145px;}\n"
"  .clock-big{font-size:32px;}\n"
"  .cell{width:16px;height:12px;}\n"
"}\n"
"@media (orientation:portrait){\n"
"  .stage{-webkit-flex-direction:column;flex-direction:column;-webkit-justify-content:space-around;justify-content:space-around;}\n"
"  .z-nav,.z-spd,.z-hyb{width:100%;-webkit-align-items:center;align-items:center;text-align:center;padding:0;}\n"
"  .speed-num{font-size:170px;}\n"
"  .cells{-webkit-justify-content:center;justify-content:center;}\n"
"}\n"
"</style>\n"
"</head>\n"
"<body>\n"
"<div id=\"app\" class=\"t-cyan\" onclick=\"wakeBar()\">\n"
"  <div class=\"topbar\">\n"
"    <div class=\"status-left acc\"><span class=\"dot\" id=\"connDot\"></span><span>PRIUS TRD • HUD</span></div>\n"
"    <div class=\"clock-wrap\" onclick=\"event.stopPropagation();toggleClockMode()\">\n"
"      <svg class=\"clock-svg\" id=\"analogClockSvg\" viewBox=\"0 0 100 100\">\n"
"        <circle cx=\"50\" cy=\"50\" r=\"45\" fill=\"none\" stroke=\"#00e5ff\" stroke-width=\"3\" opacity=\"0.85\"/>\n"
"        <line x1=\"50\" y1=\"9\" x2=\"50\" y2=\"17\" stroke=\"#ffffff\" stroke-width=\"3\"/>\n"
"        <line x1=\"91\" y1=\"50\" x2=\"83\" y2=\"50\" stroke=\"#ffffff\" stroke-width=\"3\"/>\n"
"        <line x1=\"50\" y1=\"91\" x2=\"50\" y2=\"83\" stroke=\"#ffffff\" stroke-width=\"3\"/>\n"
"        <line x1=\"9\" y1=\"50\" x2=\"17\" y2=\"50\" stroke=\"#ffffff\" stroke-width=\"3\"/>\n"
"        <line id=\"clkHr\" x1=\"50\" y1=\"50\" x2=\"50\" y2=\"24\" stroke=\"#ffffff\" stroke-width=\"4.5\" stroke-linecap=\"round\"/>\n"
"        <line id=\"clkMin\" x1=\"50\" y1=\"50\" x2=\"50\" y2=\"15\" stroke=\"#00e5ff\" stroke-width=\"3.2\" stroke-linecap=\"round\"/>\n"
"        <line id=\"clkSec\" x1=\"50\" y1=\"54\" x2=\"50\" y2=\"13\" stroke=\"#ff2a3a\" stroke-width=\"1.8\" stroke-linecap=\"round\"/>\n"
"        <circle cx=\"50\" cy=\"50\" r=\"3.8\" fill=\"#ff2a3a\"/>\n"
"      </svg>\n"
"      <div class=\"clock-big\" id=\"clockTxt\">--:--</div>\n"
"    </div>\n"
"    <div class=\"trip-txt acc\" id=\"wifiTxt\">TRD LIVE</div>\n"
"  </div>\n"
"  <div class=\"hsi-wrap\">\n"
"    <svg class=\"hsi-svg\" viewBox=\"0 0 600 34\">\n"
"      <defs>\n"
"        <linearGradient id=\"hsiGrad\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"0%\">\n"
"          <stop offset=\"0%\" stop-color=\"#00e5ff\"/>\n"
"          <stop offset=\"45%\" stop-color=\"#22ff88\"/>\n"
"          <stop offset=\"78%\" stop-color=\"#ffaa22\"/>\n"
"          <stop offset=\"100%\" stop-color=\"#ff2233\"/>\n"
"        </linearGradient>\n"
"      </defs>\n"
"      <path d=\"M 20 26 Q 300 -4 580 26\" fill=\"none\" stroke=\"#0d1e2b\" stroke-width=\"8\" stroke-linecap=\"round\"/>\n"
"      <path id=\"hsiArc\" d=\"M 20 26 Q 300 -4 580 26\" fill=\"none\" stroke=\"url(#hsiGrad)\" stroke-width=\"8\" stroke-linecap=\"round\" stroke-dasharray=\"565\" stroke-dashoffset=\"440\"/>\n"
"      <text x=\"22\" y=\"33\" fill=\"#00e5ff\" font-size=\"9\" font-weight=\"800\">CHG</text>\n"
"      <text x=\"300\" y=\"33\" fill=\"#22ff88\" font-size=\"9\" font-weight=\"800\" text-anchor=\"middle\">ECO HYBRID</text>\n"
"      <text x=\"578\" y=\"33\" fill=\"#ff3848\" font-size=\"9\" font-weight=\"800\" text-anchor=\"end\">PWR</text>\n"
"    </svg>\n"
"  </div>\n"
"  <div class=\"stage\">\n"
"    <div class=\"zone z-nav\">\n"
"      <div class=\"nav-row\">\n"
"        <div class=\"nav-arrow acc\" id=\"navArrow\">↑</div>\n"
"        <div>\n"
"          <div class=\"nav-dist\" id=\"navDist\">GPS LIVE</div>\n"
"          <div class=\"nav-sub acc\" id=\"navSub\">AUTO SYNC</div>\n"
"        </div>\n"
"      </div>\n"
"      <div class=\"nav-street\" id=\"navStreet\">ซิงก์พิกัดสดจาก iPad อัตโนมัติ</div>\n"
"    </div>\n"
"    <div class=\"zone z-spd\">\n"
"      <div class=\"limit-ring\" id=\"limitRing\">90</div>\n"
"      <div id=\"digitalWrap\">\n"
"        <div class=\"speed-num\" id=\"speedNum\">0</div>\n"
"        <div class=\"spd-side\">\n"
"          <div class=\"gear-badge\" id=\"gearBox\">D</div>\n"
"          <div class=\"unit-txt acc\">KM/H</div>\n"
"        </div>\n"
"      </div>\n"
"      <div id=\"analogWrap\">\n"
"        <svg id=\"analogSvg\" viewBox=\"0 0 320 230\">\n"
"          <defs>\n"
"            <linearGradient id=\"arcGrad\" x1=\"0%\" y1=\"100%\" x2=\"100%\" y2=\"0%\">\n"
"              <stop offset=\"0%\" stop-color=\"#00e5ff\"/>\n"
"              <stop offset=\"55%\" stop-color=\"#22ff88\"/>\n"
"              <stop offset=\"80%\" stop-color=\"#ffaa22\"/>\n"
"              <stop offset=\"100%\" stop-color=\"#ff2233\"/>\n"
"            </linearGradient>\n"
"          </defs>\n"
"          <path d=\"M 42 185 A 125 125 0 1 1 278 185\" fill=\"none\" stroke=\"#0e1f2e\" stroke-width=\"14\" stroke-linecap=\"round\"/>\n"
"          <path id=\"analogArc\" d=\"M 42 185 A 125 125 0 1 1 278 185\" fill=\"none\" stroke=\"url(#arcGrad)\" stroke-width=\"14\" stroke-linecap=\"round\" stroke-dasharray=\"520\" stroke-dashoffset=\"520\"/>\n"
"          <text x=\"40\" y=\"208\" fill=\"#78a8c4\" font-size=\"13\" font-weight=\"800\" text-anchor=\"middle\">0</text>\n"
"          <text x=\"28\" y=\"118\" fill=\"#78a8c4\" font-size=\"13\" font-weight=\"800\" text-anchor=\"middle\">40</text>\n"
"          <text x=\"92\" y=\"40\" fill=\"#78a8c4\" font-size=\"13\" font-weight=\"800\" text-anchor=\"middle\">80</text>\n"
"          <text x=\"228\" y=\"40\" fill=\"#ffaa22\" font-size=\"13\" font-weight=\"800\" text-anchor=\"middle\">120</text>\n"
"          <text x=\"292\" y=\"118\" fill=\"#ff4444\" font-size=\"13\" font-weight=\"800\" text-anchor=\"middle\">160</text>\n"
"          <text x=\"280\" y=\"208\" fill=\"#ff2233\" font-size=\"13\" font-weight=\"800\" text-anchor=\"middle\">180</text>\n"
"          <g id=\"needleGroup\" transform=\"rotate(-128 160 150)\">\n"
"            <line x1=\"160\" y1=\"150\" x2=\"160\" y2=\"38\" stroke=\"#ff2a3a\" stroke-width=\"5\" stroke-linecap=\"round\"/>\n"
"            <circle cx=\"160\" cy=\"150\" r=\"9\" fill=\"#ff2a3a\" stroke=\"#ffffff\" stroke-width=\"2\"/>\n"
"          </g>\n"
"          <text id=\"analogSpeedTxt\" x=\"160\" y=\"136\" fill=\"#ffffff\" font-size=\"64\" font-weight=\"900\" text-anchor=\"middle\">0</text>\n"
"          <text id=\"analogGearTxt\" x=\"160\" y=\"205\" fill=\"#22ff88\" font-size=\"22\" font-weight=\"900\" text-anchor=\"middle\">D • KM/H</text>\n"
"        </svg>\n"
"      </div>\n"
"    </div>\n"
"    <div class=\"zone z-hyb\">\n"
"      <div class=\"ev-tag\" id=\"modePill\">⚡ EV ELECTRIC</div>\n"
"      <div class=\"soc-big\"><span>HV</span><b id=\"socVal\">72%</b></div>\n"
"      <div class=\"cells\" id=\"cellWrap\">\n"
"        <div class=\"cell on\"></div><div class=\"cell on\"></div><div class=\"cell on\"></div>\n"
"        <div class=\"cell on\"></div><div class=\"cell on\"></div><div class=\"cell\"></div>\n"
"      </div>\n"
"      <div class=\"hyb-metrics\">\n"
"        <span id=\"ectTxt\">86°C</span>\n"
"        <span id=\"auxTxt\">13.8V</span>\n"
"      </div>\n"
"      <div class=\"hyb-metrics\" style=\"margin-top:6px;color:#ffcf56;font-size:16px;\">\n"
"        <span id=\"fuelCostTxt\">⛽ ฿0.0 • 22.0 km/L</span>\n"
"      </div>\n"
"    </div>\n"
"  </div>\n"
"  <div class=\"botbar\" id=\"botBar\" onclick=\"event.stopPropagation()\">\n"
"    <div class=\"btn-group\">\n"
"      <button class=\"btn\" id=\"styleBtn\" onclick=\"toggleStyle()\">🔢 ตัวเลขยักษ์</button>\n"
"      <button class=\"btn\" id=\"modeBtn\" onclick=\"toggleMirror()\">📱 มองตรง</button>\n"
"      <button class=\"btn\" id=\"themeBtn\" onclick=\"cycleTheme()\">🎨 ฟ้า TRD</button>\n"
"    </div>\n"
"    <div class=\"song-lbl\" id=\"songTxt\">🎵 PRIUS TRD</div>\n"
"  </div>\n"
"</div>\n"
"<script>\n"
"var isMirror = false, isAnalog = false, themeIdx = 0, clockMode = 0, dimTimer = null;\n"
"var themes = ['t-cyan','t-green','t-red'];\n"
"var themeNames = ['🎨 ฟ้า TRD','🎨 เขียว EV','🎨 แดง SPORT'];\n"
"try {\n"
"  isMirror = localStorage.getItem('trd_hud_mirror') === '1';\n"
"  isAnalog = localStorage.getItem('trd_hud_analog') === '1';\n"
"  themeIdx = parseInt(localStorage.getItem('trd_hud_theme') || '0', 10) % 3;\n"
"} catch(e){}\n"
"function wakeBar(){\n"
"  var b = document.getElementById('botBar');\n"
"  b.className = 'botbar';\n"
"  if(dimTimer) clearTimeout(dimTimer);\n"
"  dimTimer = setTimeout(function(){ b.className = 'botbar dim'; }, 6000);\n"
"}\n"
"function applyUI(){\n"
"  var app = document.getElementById('app');\n"
"  app.className = themes[themeIdx] + (isMirror ? ' mirror' : '');\n"
"  document.getElementById('modeBtn').innerText = isMirror ? '🪞 สะท้อนกระจก' : '📱 มองตรง';\n"
"  document.getElementById('themeBtn').innerText = themeNames[themeIdx];\n"
"  var dWrap = document.getElementById('digitalWrap'), aWrap = document.getElementById('analogWrap');\n"
"  if(isAnalog){\n"
"    dWrap.style.display = 'none'; aWrap.style.display = '-webkit-flex'; aWrap.style.display = 'flex';\n"
"    document.getElementById('styleBtn').innerText = '⏱️ เข็มอนาล็อก';\n"
"  } else {\n"
"    aWrap.style.display = 'none'; dWrap.style.display = '-webkit-flex'; dWrap.style.display = 'flex';\n"
"    document.getElementById('styleBtn').innerText = '🔢 ตัวเลขยักษ์';\n"
"  }\n"
"  wakeBar();\n"
"}\n"
"function toggleMirror(){ isMirror = !isMirror; try{localStorage.setItem('trd_hud_mirror', isMirror?'1':'0');}catch(e){} applyUI(); }\n"
"function toggleStyle(){ isAnalog = !isAnalog; try{localStorage.setItem('trd_hud_analog', isAnalog?'1':'0');}catch(e){} applyUI(); }\n"
"function cycleTheme(){ themeIdx = (themeIdx + 1) % 3; try{localStorage.setItem('trd_hud_theme', String(themeIdx));}catch(e){} applyUI(); }\n"
"function toggleClockMode(){\n"
"  clockMode = (clockMode + 1) % 3;\n"
"  document.getElementById('analogClockSvg').style.display = (clockMode === 2) ? 'none' : 'block';\n"
"  document.getElementById('clockTxt').style.display = (clockMode === 1) ? 'none' : 'block';\n"
"}\n"
"function updateAnalogClock(){\n"
"  var now = new Date();\n"
"  var s = now.getSeconds(), m = now.getMinutes(), h = now.getHours() % 12;\n"
"  document.getElementById('clkSec').setAttribute('transform', 'rotate(' + (s*6) + ' 50 50)');\n"
"  document.getElementById('clkMin').setAttribute('transform', 'rotate(' + (m*6 + s*0.1) + ' 50 50)');\n"
"  document.getElementById('clkHr').setAttribute('transform', 'rotate(' + (h*30 + m*0.5) + ' 50 50)');\n"
"  var hh = (now.getHours() < 10 ? '0' : '') + now.getHours();\n"
"  var mm = (m < 10 ? '0' : '') + m;\n"
"  document.getElementById('clockTxt').innerText = hh + ':' + mm;\n"
"}\n"
"setInterval(updateAnalogClock, 1000);\n"
"updateAnalogClock();\n"
"applyUI();\n"
"var pollBusy = false;\n"
"function poll(){\n"
"  if(pollBusy) return;\n"
"  pollBusy = true;\n"
"  var xhr = new XMLHttpRequest();\n"
"  xhr.open('GET', '/api/hud?t=' + (new Date().getTime()), true);\n"
"  xhr.timeout = 1200;\n"
"  xhr.onloadend = function(){ pollBusy = false; };\n"
"  xhr.onload = function(){\n"
"    if(xhr.status === 200){\n"
"      try {\n"
"        var d = JSON.parse(xhr.responseText);\n"
"        document.getElementById('connDot').style.background = '#22ff88';\n"
"        var spd = Math.max(0, Math.round(Number(d.speed || 0)));\n"
"        var sn = document.getElementById('speedNum');\n"
"        sn.innerText = spd;\n"
"        sn.className = 'speed-num' + (spd >= 120 ? ' warn120' : (spd >= 90 ? ' warn90' : ''));\n"
"        var gear = d.gear || 'D';\n"
"        document.getElementById('gearBox').innerText = gear;\n"
"        var frac = Math.min(1.0, spd / 180.0);\n"
"        document.getElementById('needleGroup').setAttribute('transform', 'rotate(' + (-128 + frac*256).toFixed(1) + ' 160 150)');\n"
"        document.getElementById('analogArc').setAttribute('stroke-dashoffset', Math.round(520 * (1.0 - frac)));\n"
"        document.getElementById('analogSpeedTxt').textContent = spd;\n"
"        document.getElementById('analogGearTxt').textContent = gear + ' • KM/H';\n"
"        var hsiFrac = Math.min(1.0, Math.max(0.14, (spd / 130.0)));\n"
"        document.getElementById('hsiArc').setAttribute('stroke-dashoffset', Math.round(565 * (1.0 - hsiFrac)));\n"
"        var wBadge = d.weather ? (' • ' + d.weather) : '';\n"
"        document.getElementById('wifiTxt').innerText = (d.trip || 'TRD LIVE') + wBadge;\n"
"        document.getElementById('navArrow').innerText = d.navArrow || '↑';\n"
"        document.getElementById('navDist').innerText = d.navDist || 'GPS LIVE';\n"
"        document.getElementById('navSub').innerText = d.navSub || 'AUTO SYNC';\n"
"        document.getElementById('navStreet').innerText = d.navStreet || 'พร้อมขับขี่ • ซิงก์สดจาก iPad';\n"
"        var soc = Math.max(0, Math.min(100, Math.round(Number(d.soc || 72))));\n"
"        document.getElementById('socVal').innerText = soc + '%';\n"
"        var modeTxt = d.hybridMode || 'EV ELECTRIC';\n"
"        document.getElementById('modePill').innerText = (modeTxt.indexOf('REGEN') >= 0 ? '🔋 ' : '⚡ ') + modeTxt;\n"
"        var lit = Math.ceil(soc / 16.7);\n"
"        var cls = (modeTxt.indexOf('REGEN') >= 0) ? 'chg' : (soc < 42 ? 'low' : 'on');\n"
"        var cells = document.getElementById('cellWrap').children;\n"
"        for(var i=0;i<cells.length;i++){ cells[i].className = 'cell' + (i < lit ? (' ' + cls) : ''); }\n"
"        document.getElementById('ectTxt').innerText = (d.ect || 86) + '°C';\n"
"        document.getElementById('auxTxt').innerText = (d.aux12v || '13.8') + 'V';\n"
"        document.getElementById('fuelCostTxt').innerText = '⛽ ฿' + (d.fuelCost || '0.0') + ' • ' + (d.kmPerL || '22.0') + ' km/L';\n"
"        document.getElementById('songTxt').innerText = d.song ? ('🎵 ' + d.song) : '🎵 PRIUS TRD';\n"
"      } catch(e){}\n"
"    }\n"
"  };\n"
"  xhr.onerror = function(){ document.getElementById('connDot').style.background = '#ff3344'; };\n"
"  xhr.send();\n"
"}\n"
"setInterval(poll, 350);\n"
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

    NSString *speedStr = live[@"speed"] ?: (state[@"speed"] ?: @"0");
    double spd = [speedStr doubleValue];
    NSString *clockStr = live[@"clock"] ?: @"";
    if (clockStr.length == 0) {
      @synchronized(df) { clockStr = [df stringFromDate:[NSDate date]]; }
    }
    NSString *gearStr = live[@"gear"] ?: @"D";
    NSString *navArrow = live[@"navArrow"] ?: @"↑";
    NSString *navDist = live[@"navDist"] ?: (state[@"gps"] ?: @"GPS LIVE");
    NSString *navSub = live[@"navSub"] ?: @"AUTO SYNC";
    NSString *navStreet = live[@"navStreet"] ?: (state[@"driveTripText"] ?: @"พร้อมขับขี่ • ซิงก์สดจาก iPad");
    NSNumber *socNum = live[@"soc"] ?: @72;
    NSNumber *ectNum = live[@"ect"] ?: @86;
    NSString *auxStr = live[@"aux12v"] ?: @"13.8";
    NSString *hybMode = live[@"hybridMode"] ?: ((spd < 45.0) ? @"EV ELECTRIC" : @"HYBRID ECO");

    NSString *song = live[@"song"] ?: (state[@"song"] ?: @"");
    NSString *artist = live[@"artist"] ?: (state[@"artist"] ?: @"");
    NSString *fullSong = (song.length > 0 && artist.length > 0)
      ? [NSString stringWithFormat:@"%@ — %@", song, artist]
      : (song.length > 0 ? song : @"PRIUS TRD LIVE");

    NSString *tripStr = live[@"trip"];
    if (tripStr.length == 0) {
      NSDictionary *tripDict = state[@"tripSummary"];
      double km = [tripDict[@"meters"] doubleValue] / 1000.0;
      tripStr = (km > 0.01) ? [NSString stringWithFormat:@"TRIP %.1f KM", km] : @"TRD LIVE";
    }

    NSString *weatherStr = live[@"weather"] ?: @"";
    if (weatherStr.length == 0) {
      NSString *netStr = state[@"network"] ?: @"";
      NSRange degR = [netStr rangeOfString:@"°C"];
      if (degR.location != NSNotFound) {
        NSArray *seg = [netStr componentsSeparatedByString:@" • "];
        if (seg.count > 0) weatherStr = [seg lastObject];
      }
    }
    NSDictionary *payload = @{
      @"speed": @(spd),
      @"gear": gearStr,
      @"clock": clockStr,
      @"trip": tripStr,
      @"fuelCost": live[@"fuelCost"] ?: @"0.0",
      @"kmPerL": live[@"kmPerL"] ?: @"22.0",
      @"weather": weatherStr ?: @"",
      @"navArrow": navArrow,
      @"navDist": navDist,
      @"navSub": navSub,
      @"navStreet": navStreet,
      @"soc": socNum,
      @"ect": ectNum,
      @"aux12v": auxStr,
      @"hybridMode": hybMode,
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
    struct timeval tv;
    tv.tv_sec = 4;
    tv.tv_usec = 0;
    setsockopt(clientFd, SOL_SOCKET, SO_RCVTIMEO, (const char *)&tv, sizeof(tv));
    setsockopt(clientFd, SOL_SOCKET, SO_SNDTIMEO, (const char *)&tv, sizeof(tv));

    char buf[4096];
    ssize_t n = recv(clientFd, buf, sizeof(buf) - 1, 0);
    if (n <= 0) {
      close(clientFd);
      return;
    }
    buf[n] = '\0';
    NSString *req = [NSString stringWithUTF8String:buf];
    if (!req) req = [[NSString alloc] initWithBytes:buf length:(NSUInteger)n encoding:NSISOLatin1StringEncoding] ?: @"";
    NSString *firstLine = [[req componentsSeparatedByString:@"\r\n"] firstObject] ?: @"";

    BOOL isAPI = ([firstLine rangeOfString:@"/api/hud"].location != NSNotFound);
    NSData *bodyData = nil;
    NSString *contentType = @"text/html; charset=utf-8";
    if (isAPI) {
      contentType = @"application/json; charset=utf-8";
      bodyData = [buildLiveHUDJSON() dataUsingEncoding:NSUTF8StringEncoding];
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
    struct timeval drainTv;
    drainTv.tv_sec = 0;
    drainTv.tv_usec = 150000;
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
