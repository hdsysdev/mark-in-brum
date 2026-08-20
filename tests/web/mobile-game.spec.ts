import { test, expect, Page } from '@playwright/test';

/**
 * Web export smoke test. Proves the Godot Compatibility build boots in a
 * portrait mobile viewport, sizes the canvas to the viewport, and announces
 * readiness through the debug bridge without page errors.
 */

async function bootGame(page: Page): Promise<void> {
  await page.goto('/');
  await page.waitForFunction(() => (window as any).__markInBrum?.ready === true, null, {
    timeout: 90_000,
  });
  // First launch shows the mature-content notice; dismiss it if present.
  const notice = await page.evaluate(() => (window as any).__markInBrum?.notice);
  if (notice?.visible) {
    const scaleX = notice.cssScale[0];
    const scaleY = notice.cssScale[1];
    const cx = (notice.accept[0] + notice.accept[2] / 2) * scaleX;
    const cy = (notice.accept[1] + notice.accept[3] / 2) * scaleY;
    await page.mouse.click(cx, cy);
    await page.waitForFunction(
      () => (window as any).__markInBrum?.notice?.visible === false, null, { timeout: 15_000 });
  }
}

test('mobile portrait: game boots, canvas fills viewport, no page errors', async ({ page }) => {
  const pageErrors: string[] = [];
  page.on('pageerror', (err) => pageErrors.push(String(err)));

  await bootGame(page);

  // Canvas must exist and be non-zero sized.
  const box = await page.locator('#canvas').boundingBox();
  expect(box).not.toBeNull();
  expect(box!.width).toBeGreaterThan(0);
  expect(box!.height).toBeGreaterThan(0);

  // Canvas must fill the viewport within tolerance.
  const viewport = page.viewportSize()!;
  expect(Math.abs(box!.width - viewport.width)).toBeLessThanOrEqual(8);
  expect(Math.abs(box!.height - viewport.height)).toBeLessThanOrEqual(8);

  // No captured runtime errors.
  const bridgeErrors = await page.evaluate(() => (window as any).__markInBrum?.errors ?? []);
  expect(pageErrors).toEqual([]);
  expect(bridgeErrors).toEqual([]);
});

test('desktop viewport: game boots with larger canvas', async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await context.newPage();
  await bootGame(page);
  const box = await page.locator('#canvas').boundingBox();
  expect(box!.width).toBeGreaterThan(1000);
  await context.close();
});
