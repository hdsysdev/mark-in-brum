import { chromium, devices } from '@playwright/test';

const run = async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({ ...devices['Pixel 7'] });
  const page = await context.newPage();
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(`[pageerror] ${e}`));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(`[console.error] ${m.text().slice(0, 120)}`);
  });
  await page.goto('http://127.0.0.1:8090/', { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => (window as any).__markInBrum?.ready === true, null, { timeout: 90000 });
  console.log('ready=true');
  // Spec-identical controls wait:
  await page.waitForFunction(() => {
    const bridge = (window as any).__markInBrum;
    return typeof bridge?.controls === 'string' && bridge.controls.length > 0;
  }, null, { timeout: 20000 });
  console.log('controls wait passed');
  // Spec-identical parse:
  try {
    const raw = await page.evaluate(() => JSON.parse((window as any).__markInBrum.controls));
    console.log('parsed keys:', Object.keys(raw), 'rects type:', typeof raw.rects);
    console.log('rects sample:', String(raw.rects).slice(0, 60));
    console.log('cssScale:', raw.cssScale);
  } catch (e) {
    console.log('PARSE FAILED:', String(e).slice(0, 200));
    const rawValue = await page.evaluate(() => (window as any).__markInBrum?.controls);
    console.log('raw controls value:', JSON.stringify(rawValue)?.slice(0, 160));
  }
  console.log('errors:', errors.slice(0, 6));
  await browser.close();
};

run();
