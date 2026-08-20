import { chromium, devices } from '@playwright/test';

const run = async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({ ...devices['Pixel 7'] });
  const page = await context.newPage();
  const messages: string[] = [];
  page.on('console', (msg) => messages.push(`[${msg.type()}] ${msg.text().slice(0, 160)}`));
  page.on('pageerror', (err) => messages.push(`[pageerror] ${err}`));
  await page.goto('http://127.0.0.1:8090/', { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => (window as any).__markInBrum?.ready === true, null, { timeout: 90000 });
  console.log('ready');
  for (let i = 0; i < 10; i++) {
    await page.waitForTimeout(2000);
    const state = await page.evaluate(() => ({
      bridge: { ...(window as any).__markInBrum },
      maxTouchPoints: navigator.maxTouchPoints,
      dpr: window.devicePixelRatio,
      canvas: (() => {
        const c = document.getElementById('canvas') as HTMLCanvasElement;
        return c ? { w: c.width, h: c.height, cssW: c.clientWidth, cssH: c.clientHeight } : null;
      })(),
    }));
    console.log(`t+${(i + 1) * 2}s controls=${String(state.bridge.controls).slice(0, 80)} touchPoints=${state.maxTouchPoints} dpr=${state.dpr} canvas=${JSON.stringify(state.canvas)}`);
    if (state.bridge.controls) break;
  }
  console.log('--- console (last 12) ---');
  for (const m of messages.slice(-12)) console.log(m);
  await browser.close();
};

run();
