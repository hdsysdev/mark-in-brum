// Plain JS probe — node probe-desktop.mjs (official-shell variant)
import { chromium, devices } from '@playwright/test';

async function tryContext(name, options) {
  const browser = await chromium.launch();
  const context = await browser.newContext(options);
  await context.addInitScript(() => {
    window.__markInBrum = { ready: false, errors: [] };
  });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:8090/');
  await page.waitForFunction(() => window.__markInBrum && window.__markInBrum.ready === true, null, { timeout: 90000 });
  await page.waitForTimeout(2500);
  const before = await page.evaluate(() => window.__markInBrum.inputEvents ?? 0);
  await page.mouse.move(400, 300);
  await page.mouse.down();
  await page.mouse.move(430, 310, { steps: 3 });
  await page.mouse.up();
  await page.waitForTimeout(400);
  const after = await page.evaluate(() => window.__markInBrum.inputEvents ?? 0);
  console.log(name + ': inputEvents ' + before + ' -> ' + after);
  await browser.close();
}

await tryContext('desktop', { viewport: { width: 1280, height: 720 } });
await tryContext('pixel7', { ...devices['Pixel 7'] });
