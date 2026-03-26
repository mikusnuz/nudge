const puppeteer = require('puppeteer');
const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const WIDTH = 1270;
const HEIGHT = 760;
const FPS = 30;
const DURATION_MS = 13500; // 9 layouts * 1.5s each
const FRAME_COUNT = Math.ceil(DURATION_MS / 1000 * FPS);
const FRAMES_DIR = '/tmp/nudge-frames';

(async () => {
  // Clean up
  if (fs.existsSync(FRAMES_DIR)) fs.rmSync(FRAMES_DIR, { recursive: true });
  fs.mkdirSync(FRAMES_DIR);

  const browser = await puppeteer.launch({
    headless: true,
    args: [`--window-size=${WIDTH},${HEIGHT}`]
  });

  const page = await browser.newPage();
  await page.setViewport({ width: WIDTH, height: HEIGHT });

  // Create a standalone HTML page with just the demo animation on dark background
  const html = `
<!DOCTYPE html>
<html>
<head>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #0c0c0c;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100vh;
    font-family: -apple-system, 'Helvetica Neue', sans-serif;
    color: #f0f0f2;
  }
  .title {
    font-size: 48px;
    font-weight: 700;
    letter-spacing: -2px;
    margin-bottom: 12px;
  }
  .subtitle {
    font-size: 18px;
    color: #8e8e96;
    margin-bottom: 48px;
  }
  .demo-container {
    position: relative;
    width: 640px;
  }
  svg {
    width: 640px;
    height: 374px;
    display: block;
  }
  .demo-window {
    transition: x 0.3s cubic-bezier(0.16,1,0.3,1),
                y 0.3s cubic-bezier(0.16,1,0.3,1),
                width 0.3s cubic-bezier(0.16,1,0.3,1),
                height 0.3s cubic-bezier(0.16,1,0.3,1);
  }
  .demo-label {
    text-align: center;
    margin-top: 16px;
    font-size: 20px;
    font-weight: 600;
    color: #f0f0f2;
    height: 28px;
  }
  .demo-key {
    text-align: center;
    margin-top: 6px;
    font-size: 14px;
    color: #8e8e96;
    font-family: 'SF Mono', 'Fira Code', monospace;
    height: 20px;
  }
</style>
</head>
<body>
  <div class="title">Nudge</div>
  <div class="subtitle">Free, open-source window manager for macOS</div>
  <div class="demo-container">
    <svg viewBox="0 0 480 280" id="demo-svg">
      <rect x="2" y="2" width="476" height="276" rx="12" fill="none" stroke="rgba(255,255,255,0.08)" stroke-width="2"/>
      <circle cx="20" cy="16" r="4" fill="#FF5F57"/>
      <circle cx="32" cy="16" r="4" fill="#FFBD2E"/>
      <circle cx="44" cy="16" r="4" fill="#28C840"/>
      <line x1="240" y1="30" x2="240" y2="274" stroke="rgba(255,255,255,0.04)" stroke-width="1" stroke-dasharray="4"/>
      <line x1="160" y1="30" x2="160" y2="274" stroke="rgba(255,255,255,0.04)" stroke-width="1" stroke-dasharray="4"/>
      <line x1="320" y1="30" x2="320" y2="274" stroke="rgba(255,255,255,0.04)" stroke-width="1" stroke-dasharray="4"/>
      <line x1="6" y1="152" x2="474" y2="152" stroke="rgba(255,255,255,0.04)" stroke-width="1" stroke-dasharray="4"/>
      <rect class="demo-window" id="demo-win" x="120" y="70" width="240" height="160" rx="6" fill="rgba(255,255,255,0.8)"/>
    </svg>
    <div class="demo-label" id="demo-label"></div>
    <div class="demo-key" id="demo-key"></div>
  </div>
<script>
var win = document.getElementById('demo-win');
var label = document.getElementById('demo-label');
var keyEl = document.getElementById('demo-key');
var layouts = [
  { x:8, y:32, w:230, h:240, name:'Left Half', k:'Ctrl + Opt + Left' },
  { x:242, y:32, w:230, h:240, name:'Right Half', k:'Ctrl + Opt + Right' },
  { x:8, y:32, w:468, h:240, name:'Maximize', k:'Ctrl + Opt + Return' },
  { x:8, y:32, w:230, h:118, name:'Top Left', k:'Ctrl + Opt + U' },
  { x:242, y:154, w:230, h:118, name:'Bottom Right', k:'Ctrl + Opt + K' },
  { x:8, y:32, w:154, h:240, name:'Left Third', k:'Ctrl + Opt + D' },
  { x:8, y:32, w:310, h:240, name:'Left Two Thirds', k:'Ctrl + Opt + E' },
  { x:80, y:32, w:320, h:240, name:'Center Two Thirds', k:'Ctrl + Opt + R' },
  { x:120, y:70, w:240, h:160, name:'Center', k:'Ctrl + Opt + C' },
];
var i = 0;
function next() {
  var l = layouts[i];
  win.setAttribute('x', l.x);
  win.setAttribute('y', l.y);
  win.setAttribute('width', l.w);
  win.setAttribute('height', l.h);
  label.textContent = l.name;
  keyEl.textContent = l.k;
  i = (i + 1) % layouts.length;
}
next();
setInterval(next, 1500);
</script>
</body>
</html>`;

  await page.setContent(html, { waitUntil: 'networkidle0' });
  await new Promise(r => setTimeout(r, 500));

  console.log(`Capturing ${FRAME_COUNT} frames at ${FPS}fps...`);
  const interval = 1000 / FPS;

  for (let f = 0; f < FRAME_COUNT; f++) {
    const framePath = path.join(FRAMES_DIR, `frame-${String(f).padStart(4, '0')}.png`);
    await page.screenshot({ path: framePath });
    await new Promise(r => setTimeout(r, interval));
    if (f % 30 === 0) console.log(`  frame ${f}/${FRAME_COUNT}`);
  }

  await browser.close();
  console.log('Frames captured. Converting to GIF...');

  const outPath = path.resolve(__dirname, '../assets/demo-ph.gif');
  execSync(`ffmpeg -y -framerate ${FPS} -i ${FRAMES_DIR}/frame-%04d.png -vf "palettegen=stats_mode=diff" -frames:v 1 /tmp/palette-ph.png`, { stdio: 'pipe' });
  execSync(`ffmpeg -y -framerate ${FPS} -i ${FRAMES_DIR}/frame-%04d.png -i /tmp/palette-ph.png -lavfi "paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" ${outPath}`, { stdio: 'pipe' });

  const size = fs.statSync(outPath).size;
  console.log(`Done: ${outPath} (${(size / 1024).toFixed(0)}KB)`);
})();
