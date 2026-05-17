#!/usr/bin/env node
const spinners = require('unicode-animations');
const frames = spinners.braille.frames;
let i = 0;
const interval = setInterval(() => {
    process.stdout.write('\r\x1b[36m' + frames[i % frames.length] + '\x1b[0m');
    i++;
}, spinners.braille.interval || 80);
process.on('SIGTERM', () => { clearInterval(interval); process.stdout.write('\r  \r'); process.exit(0); });
process.on('SIGINT', () => { clearInterval(interval); process.stdout.write('\r  \r'); process.exit(0); });
