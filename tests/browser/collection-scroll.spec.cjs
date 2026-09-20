const { test, expect } = require('@playwright/test');
const { metrics, uiScale, collectionBounds, roomPoint, roomControl, openRewards, chooseRewardSection, enterGame } = require('./game-ui.cjs');

async function openMedals(page) {
  await openRewards(page);
  await chooseRewardSection(page, 'medals');
  await expect(page.locator('#game-status')).toContainText('Medals. Win a game');
  await rendered(page);
}

async function contentShift(page, before, after) {
  const bounds = await metrics(page), collection = collectionBounds(bounds);
  const contentTop = Math.ceil(bounds.y + collection.top * bounds.scale);
  return page.evaluate(async ({ before, after, contentTop }) => {
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
    // Start below the fixed world and age controls in the current canvas layout.
    for (let shift = 0; shift <= 180; shift++) {
      let error = 0;
      for (let y = contentTop; y < original.length - 190; y++) {
        error += Math.abs(original[y + shift] - moved[y]);
      }
      if (error < best.error) best = { pixels: shift, error };
    }
    return best;
  }, { before: before.toString('base64'), after: after.toString('base64'), contentTop });
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
      await enterGame(page);
      await openMedals(page);
      const before = await page.screenshot({ path: testInfo.outputPath('medals-before-drag.png'), scale: 'css' });
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
          const after = await page.screenshot({
            path: testInfo.outputPath(`medals-drag-${measurements.length + 1}-${displacement}.png`), scale: 'css'
          });
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

    for (const locked of [false, true]) {
      test(`room ${locked ? 'locked toy' : 'empty canvas'} drag scrolls instead of moving Pip`, async ({ page, browserName }, testInfo) => {
        test.skip(browserName !== 'chromium', 'Trusted touch motion uses Chromium CDP.');
        await page.goto('/');
        await enterGame(page);
        await openRewards(page);
        await chooseRewardSection(page, 'room');
        if (locked) {
          await roomControl(page, 'spring');
          await page.keyboard.press('Enter');
          await expect(page.locator('#game-status')).toContainText('Complete Blossom');
          await page.mouse.move(190, 350);
          await page.mouse.wheel(0, -2600);
          await rendered(page);
        }
        const bounds = await metrics(page), collection = collectionBounds(bounds);
        const point = locked ? roomPoint(bounds, 'preview') : { x: collection.x + collection.width / 2, y: collection.top + 90 };
        const start = { x: bounds.x + point.x * bounds.scale, y: bounds.y + point.y * bounds.scale };
        const status = await page.locator('#game-status').textContent();
        const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
        if (locked) {
          await page.touchscreen.tap(start.x, start.y);
          expect(await page.locator('#game-status').textContent()).toBe(status);
        }
        await page.mouse.move(0, 0);
        const before = await page.screenshot({ scale: 'css' });
        const client = await page.context().newCDPSession(page);
        try {
          await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...start }] });
          for (const displacement of [20, 40, 60]) {
            await client.send('Input.dispatchTouchEvent', {
              type: 'touchMove', touchPoints: [{ id: 1, x: start.x, y: start.y - displacement }]
            });
            await rendered(page);
            const after = await page.screenshot({
              path: testInfo.outputPath(`room-${locked ? 'locked' : 'background'}-${displacement}.png`), scale: 'css'
            });
            const measured = await contentShift(page, before, after);
            expect(Math.abs(measured.pixels - displacement), JSON.stringify(measured)).toBeLessThanOrEqual(2);
          }
        } finally {
          await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
          await client.detach();
        }
        expect(await page.locator('#game-status').textContent()).toBe(status);
        expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(saved);
      });
    }
  });
}

test('mouse dragging the room background scrolls without calling Pip', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 650 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page);
  await openRewards(page);
  await chooseRewardSection(page, 'room');
  const bounds = await metrics(page), collection = collectionBounds(bounds);
  const start = { x: bounds.x + (collection.x + collection.width / 2) * bounds.scale,
    y: bounds.y + (collection.top + 90) * bounds.scale };
  const status = await page.locator('#game-status').textContent();
  const before = await page.screenshot({ scale: 'css' });
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  try {
    await page.mouse.move(start.x, start.y - 60, { steps: 6 });
    await rendered(page);
    const after = await page.screenshot({ path: testInfo.outputPath('room-background-mouse.png'), scale: 'css' });
    const measured = await contentShift(page, before, after);
    expect(Math.abs(measured.pixels - 60), JSON.stringify(measured)).toBeLessThanOrEqual(2);
  } finally {
    await page.mouse.up();
  }
  expect(await page.locator('#game-status').textContent()).toBe(status);
});

for (const input of ['mouse', 'touch']) {
  test(`${input} toy-card selection keeps scrolled content stationary`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width: 390, height: 650 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.addInitScript(() => {
      localStorage.setItem('wordBuddies.medalProgress', '[medals]\nversion=1\ncounts={"space-1":2}\n');
    });
    await page.goto('/');
    await enterGame(page);
    await openRewards(page);
    const card = await roomControl(page, 'space');
    const bounds = await metrics(page), collection = collectionBounds(bounds), scale = uiScale(bounds);
    const point = { x: bounds.x + card.x * bounds.scale, y: bounds.y + card.y * bounds.scale };
    const previousY = point.y - (128 / scale + collection.gap) * bounds.scale;
    await page.mouse.move(point.x, previousY);
    await page.mouse.down();
    await page.mouse.move(point.x, previousY + 30, { steps: 6 });
    await page.mouse.up();
    await rendered(page);
    point.y += 30;
    const cell = (collection.width - collection.gap) / 2;
    const untouchedX = card.x > collection.x + collection.width / 2 ? collection.x : collection.x + cell + collection.gap;
    const clip = { x: bounds.x + (untouchedX + 4 / scale) * bounds.scale,
      y: bounds.y + collection.top * bounds.scale,
      width: (cell - 8 / scale) * bounds.scale,
      height: (bounds.height - collection.top - collection.padding) * bounds.scale };
    const before = await page.screenshot({ clip, scale: 'css' });
    const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
    if (input === 'touch') await page.touchscreen.tap(point.x, point.y);
    else await page.mouse.click(point.x, point.y);
    await expect(page.locator('#game-status')).toContainText('Space rocket. Complete Rocket: 2/3. 1 more piece');
    await rendered(page);
    const after = await page.screenshot({ clip, scale: 'css' });
    expect(after.equals(before), 'The untouched card column must not move when selecting a partially visible toy.').toBe(true);
    expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(saved);
    await expect(page.locator('#help')).not.toContainText('Help Pip get this');
    await page.screenshot({ path: testInfo.outputPath(`inline-goal-stable-${input}.png`), scale: 'css' });
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
    await enterGame(page);
    await openMedals(page);
    const client = await page.context().newCDPSession(page);
    let touching = false;
    async function flick() {
      await client.send('Input.dispatchTouchEvent', {
        type: 'touchStart', touchPoints: [{ id: 1, x: 190, y: 470 }]
      });
      touching = true;
      for (const displacement of [20, 40, 60]) {
        await page.waitForTimeout(40);
        await client.send('Input.dispatchTouchEvent', {
          type: 'touchMove', touchPoints: [{ id: 1, x: 190, y: 470 - displacement }]
        });
      }
      await page.waitForTimeout(40);
      // Queue the final move and release together; an IPC round trip can look like a stationary hold.
      await Promise.all([
        client.send('Input.dispatchTouchEvent', {
          type: 'touchMove', touchPoints: [{ id: 1, x: 190, y: 390 }]
        }),
        client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] })
      ]);
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
