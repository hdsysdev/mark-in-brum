import { chromium, devices } from '@playwright/test';

const run = async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({ ...devices['Pixel 7'] });
  const page = await context.newPage();
  const messages: string[] = [];
  page.on('console', (msg) => messages.push(`[${msg.type()}] ${msg.text()}`));
  page.on('pageerror', (err) => messages.push(`[pageerror] ${err}`));
  await page.goto('http://127.0.0.1:8090/', { waitUntil: 'domcontentloaded' });
  for (let i = 0; i < 24; i++) {
    await page.waitForTimeout(5000);
    const ready = await page.evaluate(() => (window as any).__markInBrum?.ready);
    console.log(`t+${(i + 1) * 5}s ready=${ready}`);
    if (ready) break;
  }
  console.log('--- console ---');
  for (const m of messages.slice(-25)) console.log(m);
  await browser.close();
};

run();
