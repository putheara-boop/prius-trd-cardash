const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const baseDir = __dirname;
const stagingDir = path.join(baseDir, 'build_v35_staging');

// 1. Clean staging directory
if (fs.existsSync(stagingDir)) {
  fs.rmSync(stagingDir, { recursive: true, force: true });
}
fs.mkdirSync(stagingDir, { recursive: true });

// 2. Extract original working IPA into staging
console.log('Extracting original IPA...');
execSync(`tar -xf "${path.join(baseDir, 'CarDash-iPadMini2.ipa')}" -C "${stagingDir}"`);

const appDir = path.join(stagingDir, 'Payload', 'CarDash.app');
if (!fs.existsSync(appDir)) {
  throw new Error('Payload/CarDash.app not found!');
}

// 3. Update Info.plist with Version 3.5.0, Build 50, new Bundle ID
const infoPlistPath = path.join(appDir, 'Info.plist');
let plist = fs.readFileSync(infoPlistPath, 'utf8');

plist = plist.replace(/<key>CFBundleShortVersionString<\/key>\s*<string>[^<]+<\/string>/,
  '<key>CFBundleShortVersionString</key>\n\t<string>3.5.0</string>');
plist = plist.replace(/<key>CFBundleVersion<\/key>\s*<string>[^<]+<\/string>/,
  '<key>CFBundleVersion</key>\n\t<string>50</string>');
plist = plist.replace(/<key>CFBundleIdentifier<\/key>\s*<string>[^<]+<\/string>/,
  '<key>CFBundleIdentifier</key>\n\t<string>com.codex.cardash.v35</string>');
plist = plist.replace(/<key>CFBundleDisplayName<\/key>\s*<string>[^<]+<\/string>/,
  '<key>CFBundleDisplayName</key>\n\t<string>CarDash TRD v3.5</string>');

fs.writeFileSync(infoPlistPath, plist, 'utf8');
console.log('Updated Info.plist for v3.5.0');

// 4. Copy web files and extra assets into CarDash.app
const extraFiles = [
  'PriusGS.png',
  'dashboard.html',
  'cardash_trd_preview.html',
  'tailwindcss.min.js',
  'leaflet.js',
  'leaflet.css',
  'manifest.json',
  'apple-touch-icon.png',
  'icon-512.png'
];
for (const f of extraFiles) {
  const src = path.join(baseDir, f);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, path.join(appDir, f));
  }
}

// 5. Create proper PKZIP archive with explicit --format zip
const ipaOut = path.join(baseDir, 'CarDash-TRD-v3.5.ipa');
if (fs.existsSync(ipaOut)) {
  fs.unlinkSync(ipaOut);
}

console.log('Creating PKZIP IPA with bsdtar --format zip...');
execSync(`tar -cf "${ipaOut}" --format zip Payload`, { cwd: stagingDir });

// 6. Verify magic bytes
const buf = fs.readFileSync(ipaOut).subarray(0, 4);
const magicHex = buf.toString('hex');
console.log('Output IPA Magic Bytes:', magicHex);
if (magicHex !== '504b0304') {
  throw new Error('FATAL: Archive is NOT a PKZIP file! Got: ' + magicHex);
}

// 7. Verify file size
const stats = fs.statSync(ipaOut);
console.log('Success! IPA generated. File size:', stats.size, 'bytes');

// 8. Clean staging
fs.rmSync(stagingDir, { recursive: true, force: true });
console.log('Cleaned staging directory.');
