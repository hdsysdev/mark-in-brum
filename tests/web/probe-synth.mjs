// Plain JS probe — node probe-synth.mjs
import { chromium, devices } from '@playwright/test';

const browser = await chromium.launch();
const context = await browser.newContext({ ...devices['Pixel 7'] });
await context.addInitScript(() => {
  window.__markInBrum = { ready: false, errors: [] };
});
const page = await context.newPage();
await page.goto('http://127.0.0.1:8090/');
await page.waitForFunction(() => window.__markInBrum && window.__markInBrum.ready === true, null, { timeout: 90000 });
await page.waitForTimeout(2500);

const before = await page.evaluate(() => window.__markInBrum.inputEvents ?? 0);
const synth = await page.evaluate(() => {
  const canvas = document.getElementById('canvas');
  const rect = canvas.getBoundingClientRect();
  const opts = { bubbles: true, cancelable: true, clientX: rect.left + 100, clientY: rect.top + 100, button: 0, buttons: 1 };
  canvas.dispatchEvent(new MouseEvent('mousedown', opts));
  canvas.dispatchEvent(new MouseEvent('mouseup', opts));
  return 'dispatched';
});
await page.waitForTimeout(400);
const after = await page.evaluate(() => window.__markInBrum.inputEvents ?? 0);
console.log(synth, ': inputEvents ' + before + ' -> ' + after);
await browser.close();
