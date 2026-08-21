// Plain JS probe — run with: node probe-dom.mjs
import { chromium, devices } from '@playwright/test';

const browser = await chromium.launch();
const context = await browser.newContext({ ...devices['Pixel 7'] });
const page = await context.newPage();
const errors = [];
page.on('console', (msg) => {
  if (msg.type() === 'error') errors.push(msg.text());
});
page.on('pageerror', (err) => errors.push(String(err)));
await page.goto('http://127.0.0.1:8090/');
await page.waitForFunction(() => window.__markInBrum && window.__markInBrum.ready === true, null, { timeout: 90000 });
await page.waitForTimeout(3000);
const result = await page.evaluate(() => {
  const pts = {};
  for (const [label, x, y] of [['center', 206, 459], ['top', 206, 100], ['joy', 41, 703]]) {
    pts[label] = document.elementsFromPoint(x, y).slice(0, 4).map((el) => {
      const r = el.getBoundingClientRect();
      return el.tagName + (el.id ? '#' + el.id : '') + ' z=' + getComputedStyle(el).zIndex +
        ' vis=' + getComputedStyle(el).visibility + ' pe=' + getComputedStyle(el).pointerEvents +
        ' ' + Math.round(r.width) + 'x' + Math.round(r.height) + '@' + Math.round(r.left) + ',' + Math.round(r.top);
    });
  }
  return pts;
});
console.log(JSON.stringify(result, null, 2));
console.log('errors:', JSON.stringify(errors));
await browser.close();
