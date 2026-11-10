const fs = require("fs");
const src = fs.readFileSync("cardash_main.m", "utf8");
const lines = src.split(/\r?\n/);
let inStr = false;
let errs = [];
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  let quoteCount = 0;
  for (let j = 0; j < line.length; j++) {
    if (line[j] === '"' && (j === 0 || line[j-1] !== '\\')) {
      quoteCount++;
    }
  }
  if (inStr) {
    if (quoteCount % 2 === 1) inStr = false;
    else errs.push(`Line ${i+1}: continuing multiline string`);
  } else {
    if (quoteCount % 2 === 1) {
      inStr = true;
      errs.push(`Line ${i+1}: unclosed string opened`);
    }
  }
}
if (errs.length > 0) {
  console.log("Found string issues:", errs.slice(0, 10));
} else {
  console.log("All strings properly single-line / closed!");
}
