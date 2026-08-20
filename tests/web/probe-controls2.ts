import { chromium, devices } from '@playwright/test';

const run = async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({ ...devices['Pixel 7'] });
  const page = await context.newPage();
  const messages: string[] = [];
  page.on('console', (msg) => messages.push(`[${msg.type()}] ${msg.text().slice(0, 140)}`));
  page.on('pageerror', (err) => messages.push(`[pageerror] ${err}`));
  await page.goto('http://127.0.0.1:8090/', { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => (window as any).__markInBrum?.ready === true, null, { timeout: 90000 });
  for (let i = 0; i < 8; i++) {
    await page.waitForTimeout(1500);
    const ctrl = await page.evaluate(() => (window as any).__markInBrum?.controls);
    console.log(`t+${(i + 1) * 1.5}s controls=${JSON.stringify(ctrl)?.slice(0, 120)}`);
    if (ctrl) break;
  }
  for (const m of messages.slice(-6)) console.log(m);
  await browser.close();
};

run();
