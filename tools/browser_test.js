// Browser smoke test for the web export.
//
//   node tools/browser_test.js [url] [outdir]
//
// Loads the exported game in headless Chromium, fails on any console or
// page error, then plays through main menu -> quest board -> battle and
// writes a screenshot of every step.

const { chromium } = require('playwright');
const fs = require('fs');

const URL = process.argv[2] || 'http://127.0.0.1:8080';
const OUT = process.argv[3] || '/home/user/.cache/browser_shots';

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({
    args: [
      '--use-gl=swiftshader',
      '--enable-unsafe-swiftshader',
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--autoplay-policy=no-user-gesture-required',
    ],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

  const errors = [];
  page.on('console', (m) => {
    console.log(`[${m.type()}]`, m.text());
    if (m.type() === 'error') errors.push(`console: ${m.text()}`);
  });
  page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));

  console.log('loading', URL);
  await page.goto(URL, { waitUntil: 'load', timeout: 120000 });
  await page.waitForSelector('canvas', { timeout: 120000 });
  const canvas = await page.$('canvas');
  const box = await canvas.boundingBox();
  console.log('canvas box', JSON.stringify(box));

  const shot = async (name) => {
    await page.screenshot({ path: `${OUT}/${name}.png` });
    console.log('shot', name);
  };
  const click = async (x, y, label, wait = 2500) => {
    await page.mouse.click(box.x + x, box.y + y);
    await page.waitForTimeout(wait);
    if (label) await shot(label);
  };

  await page.waitForTimeout(7000);
  await shot('web_01_main_menu');

  // "Quest Board" is the second button on the main menu.
  await click(640, 326, 'web_02_quest_board');
  // "Start Quest" on the first quest card.
  await click(1170, 209, 'web_03_battle_start', 9000);
  // Click an enemy on the right to set the preferred target.
  await click(1010, 390, 'web_04_targeted', 2000);
  // Use the first hero's skill (Q) and arts (A).
  await page.keyboard.press('q');
  await page.waitForTimeout(1500);
  await shot('web_05_skill_used');
  await page.keyboard.press('a');
  await page.waitForTimeout(1500);
  await shot('web_06_arts_used');
  // Pause menu.
  await page.keyboard.press('p');
  await page.waitForTimeout(1500);
  await shot('web_07_paused');

  console.log('console errors:', errors.length);
  for (const e of errors.slice(0, 20)) console.log('   ', e);
  await browser.close();
  process.exit(errors.length ? 1 : 0);
})().catch((e) => {
  console.error('FATAL', e);
  process.exit(2);
});
