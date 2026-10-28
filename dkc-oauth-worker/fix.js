const fs = require('fs');
const file = 'worker.js';
let data = fs.readFileSync(file, 'utf8');
data = data.replace(/\\`/g, '`');
fs.writeFileSync(file, data);
