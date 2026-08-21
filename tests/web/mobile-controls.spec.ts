import { test, expect, Page, CDPSession } from '@playwright/test';

/**
 * Touch-control QA. Drives the game through real touch events (CDP) and
 * verifies that the joystick, look zone, and hold buttons change gameplay
 * state through the debug bridge.
 */

const CONTROL_NAMES: Record<string, string> = {
  joystick: 'Joystick',
  look: 'LookZone',
  action: 'ActionButton',
  sprint: 'SprintButton',
  recenter: 'RecenterButton',
  pause: 'PauseButton',
};

async function bootGame(page: Page): Promise<void> {
  await page.goto('/');
  await page.waitForFunction(() => (window as any).__markInBrum?.ready === true, null, {
    timeout: 90_000,
  });
  // First launch shows the mature-content notice; dismiss it with Enter
  // (the accept button holds focus; keyboard activation is the reliable
  // path across mouse/touch emulation contexts).
  const noticeVisible = await page.evaluate(() => (window as any).__markInBrum?.notice?.visible);
  if (noticeVisible) {
    await page.keyboard.press('Enter');
    await page.waitForFunction(
      () => (window as any).__markInBrum?.notice?.visible === false, null, { timeout: 15_000 });
  }
  // Wait for the controls layout report.
  await page.waitForFunction(() => {
    const bridge = (window as any).__markInBrum;
    return typeof bridge?.controls === 'string' && bridge.controls.length > 0;
  }, null, { timeout: 20_000 });
}

function parseControls(page: Page): Promise<Record<string, { x: number; y: number; w: number; h: number }>> {
  return page.evaluate(() => {
    const rawValue = (window as any).__markInBrum.controls;
    const raw = JSON.parse(rawValue);
    const scaleX = raw.cssScale[0];
    const scaleY = raw.cssScale[1];
    const out: Record<string, { x: number; y: number; w: number; h: number }> = {};
    for (const [name, dims] of Object.entries(raw.rects)) {
      const [x, y, w, h] = dims as number[];
      out[name] = { x: x * scaleX, y: y * scaleY, w: w * scaleX, h: h * scaleY };
    }
    return out;
  });
}

async function touchStart(cdp: CDPSession, x: number, y: number, id = 1): Promise<void> {
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [{ x, y, id, radiusX: 4, radiusY: 4 }],
  });
}

async function touchMove(cdp: CDPSession, x: number, y: number, id = 1): Promise<void> {
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchMove',
    touchPoints: [{ x, y, id, radiusX: 4, radiusY: 4 }],
  });
}

async function touchEnd(cdp: CDPSession, id = 1): Promise<void> {
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

async function markState(page: Page): Promise<{ x: number; z: number; speed: number }> {
  await page.waitForFunction(() => typeof (window as any).__markInBrum?.markX === 'number');
  return page.evaluate(() => ({
    x: (window as any).__markInBrum.markX,
    z: (window as any).__markInBrum.markZ,
    speed: (window as any).__markInBrum.markSpeed,
  }));
}

test('mobile: joystick drag moves Mark and release stops him', async ({ page }) => {
  await bootGame(page);
  const cdp = await page.context().newCDPSession(page);
  const controls = await parseControls(page);
  const joy = controls[CONTROL_NAMES.joystick];
  const cx = joy.x + joy.w / 2;
  const cy = joy.y + joy.h / 2;

  const before = await markState(page);
  await touchStart(cdp, cx, cy);
  await touchMove(cdp, cx, cy - 70, 1); // drag up = forward
  await page.waitForTimeout(1500);
  await touchMove(cdp, cx, cy - 70, 1);
  await page.waitForTimeout(500);
  const during = await markState(page);
  expect(during.speed).toBeGreaterThan(1.0);
  expect(Math.hypot(during.x - before.x, during.z - before.z)).toBeGreaterThan(0.5);

  await touchEnd(cdp);
  await page.waitForTimeout(1200);
  const after = await markState(page);
  expect(after.speed).toBeLessThan(0.4);
});

test('mobile: look-zone drag rotates the camera', async ({ page }) => {
  await bootGame(page);
  const cdp = await page.context().newCDPSession(page);
  const controls = await parseControls(page);
  const look = controls[CONTROL_NAMES.look];
  const sx = look.x + look.w * 0.5;
  const sy = look.y + look.h * 0.3;

  const yawBefore = await page.evaluate(() => (window as any).__markInBrum.camYaw);
  await touchStart(cdp, sx, sy, 2);
  for (let i = 1; i <= 12; i++) {
    await touchMove(cdp, sx + i * 25, sy, 2);
  }
  await page.waitForTimeout(600);
  const yawAfter = await page.evaluate(() => (window as any).__markInBrum.camYaw);
  expect(yawAfter).not.toBe(yawBefore);
  await touchEnd(cdp, 2);
});

test('mobile: action hold and sprint toggle drive router state', async ({ page }) => {
  await bootGame(page);
  const cdp = await page.context().newCDPSession(page);
  const controls = await parseControls(page);
  const action = controls[CONTROL_NAMES.action];
  const sprint = controls[CONTROL_NAMES.sprint];

  // Hold action: speed unchanged but bridge-exposed action state should flip.
  await touchStart(cdp, action.x + action.w / 2, action.y + action.h / 2, 3);
  await page.waitForTimeout(400);
  const actionHeld = await page.evaluate(() => (window as any).__markInBrum.actionHeld);
  expect(actionHeld).toBe(true);
  await touchEnd(cdp, 3);
  await page.waitForTimeout(400);
  const actionReleased = await page.evaluate(() => (window as any).__markInBrum.actionHeld);
  expect(actionReleased).toBe(false);

  // Toggle sprint then drive the joystick: speed should exceed walk speed.
  await touchStart(cdp, sprint.x + sprint.w / 2, sprint.y + sprint.h / 2, 4);
  await touchEnd(cdp, 4);
  await page.waitForTimeout(300);
  const joy = controls[CONTROL_NAMES.joystick];
  await touchStart(cdp, joy.x + joy.w / 2, joy.y + joy.h / 2, 5);
  await touchMove(cdp, joy.x + joy.w / 2, joy.y + joy.h / 2 - 70, 5);
  await page.waitForTimeout(2000);
  const sprinting = await markState(page);
  expect(sprinting.speed).toBeGreaterThan(4.0);
  await touchEnd(cdp, 5);
});

test('mobile: interrupted touch (touchEnd) resets movement state', async ({ page }) => {
  await bootGame(page);
  const cdp = await page.context().newCDPSession(page);
  const controls = await parseControls(page);
  const joy = controls[CONTROL_NAMES.joystick];
  const cx = joy.x + joy.w / 2;
  const cy = joy.y + joy.h / 2;

  await touchStart(cdp, cx, cy);
  await touchMove(cdp, cx + 60, cy);
  await page.waitForTimeout(800);
  // End the touch WITHOUT a touchend delivered to the joystick slot:
  // emulate an interruption by cancelling via touchCancel.
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
  await page.waitForTimeout(1200);
  const state = await markState(page);
  expect(state.speed).toBeLessThan(0.4);
});
