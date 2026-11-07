const fs = require('fs');
const path = require('path');

const cssPath = path.join(__dirname, 'cockpit_compiled.css');
const htmlPath = path.join(__dirname, 'cardash_trd_preview.html');
const dashPath = path.join(__dirname, 'dashboard.html');

const css = fs.readFileSync(cssPath, 'utf8');
let html = fs.readFileSync(htmlPath, 'utf8');

const customLayoutCSS = `
  /* Embedded Compiled Tailwind CSS */
  ${css}

  /* 100% Guaranteed 3-Zone Automotive Cockpit Flexbox Columns */
  .cockpit-main-grid {
    display: -webkit-box !important;
    display: -webkit-flex !important;
    display: flex !important;
    -webkit-box-orient: horizontal !important;
    -webkit-box-direction: normal !important;
    -webkit-flex-direction: row !important;
    flex-direction: row !important;
    width: 100% !important;
    align-items: stretch !important;
    gap: 12px !important;
  }
  .cockpit-zone-left {
    -webkit-box-flex: 0 !important;
    -webkit-flex: 0 0 25% !important;
    flex: 0 0 25% !important;
    width: 25% !important;
    max-width: 25% !important;
    min-width: 240px !important;
    box-sizing: border-box !important;
  }
  .cockpit-zone-center {
    -webkit-box-flex: 1 !important;
    -webkit-flex: 1 1 50% !important;
    flex: 1 1 50% !important;
    width: 50% !important;
    max-width: 50% !important;
    min-width: 0 !important;
    box-sizing: border-box !important;
  }
  .cockpit-zone-right {
    -webkit-box-flex: 0 !important;
    -webkit-flex: 0 0 25% !important;
    flex: 0 0 25% !important;
    width: 25% !important;
    max-width: 25% !important;
    min-width: 240px !important;
    box-sizing: border-box !important;
  }
  .hidden {
    display: none !important;
  }
`;

// Replace link with embedded style
if (html.includes('<link rel="stylesheet" href="cockpit_compiled.css">')) {
  html = html.replace('<link rel="stylesheet" href="cockpit_compiled.css">', '<style id="embeddedCockpitCSS">' + customLayoutCSS + '</style>');
} else if (html.includes('<style id="embeddedCockpitCSS">')) {
  html = html.replace(/<style id="embeddedCockpitCSS">[\s\S]*?<\/style>/, '<style id="embeddedCockpitCSS">' + customLayoutCSS + '</style>');
} else {
  html = html.replace('</head>', '<style id="embeddedCockpitCSS">' + customLayoutCSS + '</style></head>');
}

// Replace grid with cockpit-main-grid
html = html.replace(/class="grid grid-cols-12 gap-3 mb-3 items-stretch"/g, 'class="cockpit-main-grid w-full mb-3 items-stretch"');

// Replace 3 zone column classes
html = html.replace(/class="col-span-12 md:col-span-4 lg:col-span-3 bg-slate-900\/80/g, 'class="cockpit-zone-left bg-slate-900/80');
html = html.replace(/class="col-span-12 md:col-span-8 lg:col-span-6 bg-slate-900\/80/g, 'class="cockpit-zone-center bg-slate-900/80');
html = html.replace(/class="col-span-12 md:col-span-12 lg:col-span-3 bg-slate-900\/80/g, 'class="cockpit-zone-right bg-slate-900/80');

fs.writeFileSync(htmlPath, html, 'utf8');
fs.writeFileSync(dashPath, html, 'utf8');
console.log('Successfully upgraded cardash_trd_preview.html and dashboard.html with embedded CSS and rigid 3-zone flexbox!');
