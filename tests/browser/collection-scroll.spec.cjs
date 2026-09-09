const { test, expect } = require('@playwright/test');

async function contentShift(page, before, after) {
  return page.evaluate(async ({ before, after }) => {
    async function rows(encoded) {
      const image = new Image();
      image.src = 'data:image/png;base64,' + encoded;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width;
      canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
      return Array.from({ length: canvas.height }, (_, y) => {
        let total = 0;
        for (let x = 20; x < canvas.width - 20; x++) {
          const index = (y * canvas.width + x) * 4;
          total += data[index] + data[index + 1] + data[index + 2];
        }
        return total / ((canvas.width - 40) * 3);
      });
    }
    const original = await rows(before);
    const moved = await rows(after);
    let best = { pixels: 0, error: Infinity };
    // Compare actual rendered headings and reward rows, excluding the fixed header.
    for (let shift = 0; shift <= 180; shift++) {
      let error = 0;
      for (let y = 100; y < original.length - 190; y++) {
        error += Math.abs(original[y + shift] - moved[y]);
      }
      if (error < best.error) best = { pixels: shift, error };
    }
    return best;
  }, { before: before.toString('base64'), after: after.toString('base64') });
}

async function rendered(page) {
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

for (const ratio of [1, 2, 3]) {
  test.describe(`collection touch tracking at DPR ${ratio}`, () => {
    test.use({
      viewport: { width: 390, height: 650 },
      deviceScaleFactor: ratio,
      hasTouch: true,
      reducedMotion: 'reduce'
    });

    test('rendered reward rows move one pixel for each finger pixel', async ({ page, browserName }, testInfo) => {
      test.skip(browserName !== 'chromium', 'Real touch-move dispatch uses the Chromium DevTools protocol.');
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.goto('/');
      await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
      await page.touchscreen.tap(342, 26);
      await rendered(page);
      const before = await page.screenshot({ scale: 'css' });
      const client = await page.context().newCDPSession(page);
      const measurements = [];
      try {
        await client.send('Input.dispatchTouchEvent', {
          type: 'touchStart', touchPoints: [{ id: 1, x: 190, y: 470 }]
        });
        for (const displacement of [30, 60, 90, 60]) {
          await client.send('Input.dispatchTouchEvent', {
            type: 'touchMove', touchPoints: [{ id: 1, x: 190, y: 470 - displacement }]
          });
          await rendered(page);
          const after = await page.screenshot({ scale: 'css' });
          const measured = await contentShift(page, before, after);
          measurements.push({ finger: displacement, content: measured.pixels, error: measured.error });
          expect(Math.abs(measured.pixels - displacement), JSON.stringify(measurements)).toBeLessThanOrEqual(2);
        }
      } finally {
        await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
        await client.detach();
        await testInfo.attach('rendered-scroll-displacement', {
          body: JSON.stringify({ devicePixelRatio: ratio, measurements }, null, 2),
          contentType: 'application/json'
        });
      }
      expect(errors).toEqual([]);
    });
  });
}

test.describe('collection release momentum', () => {
  test.use({
    viewport: { width: 390, height: 650 }, deviceScaleFactor: 2, hasTouch: true,
    reducedMotion: 'no-preference'
  });

  test('a released swipe glides, slows down, and stops at the next touch', async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'Real touch-move dispatch uses the Chromium DevTools protocol.');
    await page.goto('/');
    await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
    await page.touchscreen.tap(342, 26);
    await rendered(page);
    const client = await page.context().newCDPSession(page);
    let touching = false;
    async function flick() {
      await client.send('Input.dispatchTouchEvent', {
        type: 'touchStart', touchPoints: [{ id: 1, x: 190, y: 470 }]
      });
      touching = true;
      for (const displacement of [20, 40, 60, 80]) {
        await page.waitForTimeout(40);
        await client.send('Input.dispatchTouchEvent', {
          type: 'touchMove', touchPoints: [{ id: 1, x: 190, y: 470 - displacement }]
        });
      }
      await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      touching = false;
    }
    try {
      const before = await page.screenshot({ scale: 'css' });
      await flick();
      await page.waitForTimeout(100);
      const gliding = await page.screenshot({ scale: 'css' });
      // The finger ends at 80px; a screenshot after release already includes gliding.
      const releaseShift = 80;
      const glideShift = (await contentShift(page, before, gliding)).pixels;
      expect(glideShift).toBeGreaterThan(releaseShift + 3);
      await page.waitForTimeout(100);
      const slower = await page.screenshot({ scale: 'css' });
      const slowShift = (await contentShift(page, before, slower)).pixels;
      expect(slowShift - glideShift).toBeLessThan(glideShift - releaseShift);
      await flick();
      await client.send('Input.dispatchTouchEvent', {
        type: 'touchStart', touchPoints: [{ id: 1, x: 190, y: 420 }]
      });
      touching = true;
      await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      touching = false;
      const stopped = await page.screenshot({ scale: 'css' });
      await page.waitForTimeout(160);
      const settled = await page.screenshot({ scale: 'css' });
      expect((await contentShift(page, stopped, settled)).pixels).toBeLessThanOrEqual(1);
      await expect(page.locator('#game-status')).toContainText('My rewards opened');
    } finally {
      if (touching) await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await client.detach();
    }
  });
});
