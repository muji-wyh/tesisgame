const { test, expect } = require('@playwright/test');
const { metrics, tap, rendered, openGame } = require('./game-ui.cjs');

test.use({ viewport: { width: 390, height: 844 } });

async function clips(page) {
  const bounds = await metrics(page);
  const rect = (x, y, width, height) => ({
    x: bounds.x + x * bounds.scale, y: bounds.y + y * bounds.scale,
    width: width * bounds.scale, height: height * bounds.scale
  });
  return {
    // Below the eyes: the existing blink alone must not satisfy this test.
    body: rect(14, 42, 52, 22),
    lesson: rect(0, 280, bounds.width, bounds.height - 280)
  };
}

async function gameState(page) {
  return page.evaluate(() => ({
    status: document.getElementById('game-status').textContent,
    selection: document.getElementById('selection-status').textContent,
    saves: ['wordBuddies.medalProgress', 'wordBuddies.playroom', 'wordBuddies.favoriteReward']
      .map(key => [key, localStorage.getItem(key)])
  }));
}

async function capture(page, clip) {
  return page.screenshot({ clip, scale: 'css' });
}

async function changedPixels(page, resting, frame) {
  return page.evaluate(async sources => {
    const pixels = await Promise.all(sources.map(async source => {
      const image = new Image();
      image.src = `data:image/png;base64,${source}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width;
      canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      return context.getImageData(0, 0, image.width, image.height).data;
    }));
    let changed = 0;
    for (let index = 0; index < pixels[0].length; index += 4) {
      const distance = [0, 1, 2].reduce((sum, channel) =>
        sum + (pixels[0][index + channel] - pixels[1][index + channel]) ** 2, 0);
      if (distance > 60 ** 2) changed++;
    }
    return changed / (pixels[0].length / 4);
  }, [resting, frame].map(buffer => buffer.toString('base64')));
}

async function expectGesture(page, clip, resting, testInfo, name) {
  let gesture;
  let change;
  // Atlas compression also changes body pixels during a blink. Require visible
  // movement across >5% of the body, ignoring RGB distances of 60 or less.
  await expect.poll(async () => {
    const frame = await capture(page, clip);
    change = await changedPixels(page, resting, frame);
    if (change > 0.05) gesture = frame;
    return change;
  }, { timeout: 12500, intervals: [150], message: 'Pip visibly moves its body or wings without a player action.' }).toBeGreaterThan(0.05);
  await testInfo.attach(name, { body: gesture, contentType: 'image/png' });
  await testInfo.attach(`${name}-changed-pixels`, { body: `${(change * 100).toFixed(1)}%`, contentType: 'text/plain' });
}

async function expectStill(page, clip) {
  await rendered(page);
  const resting = await capture(page, clip);
  const deadline = Date.now() + 10500;
  // Sample the whole longest idle interval, so an intervening gesture cannot hide
  // between two identical screenshots taken before and after it.
  while (Date.now() < deadline) {
    await page.waitForTimeout(200);
    expect((await capture(page, clip)).equals(resting), 'Pip remains still for the complete idle interval.').toBe(true);
  }
  return resting;
}

test('Pip gestures autonomously while the lesson stays unchanged and its button remains responsive', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await page.mouse.move(0, 0);
  await rendered(page);
  const area = await clips(page);
  const state = await gameState(page);
  const lesson = await capture(page, area.lesson);
  const resting = await capture(page, area.body);
  await page.screenshot({ path: testInfo.outputPath('pip-resting-learn.png'), scale: 'css' });

  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await expectGesture(page, area.body, resting, testInfo, 'pip-autonomous-body-gesture');
  await page.screenshot({ path: testInfo.outputPath('pip-autonomous-learn.png'), scale: 'css' });
  expect(await gameState(page)).toEqual(state);
  expect((await capture(page, area.lesson)).equals(lesson), 'Idle gestures preserve the displayed word, picture and lesson controls.').toBe(true);

  await tap(page, 38, 46);
  await expect(page.locator('#game-status')).toContainText("Pip says: duck! Pip's happy dance!", { timeout: 2000 });
  expect((await gameState(page)).saves).toEqual(state.saves);
  expect((await capture(page, area.lesson)).equals(lesson), 'Clicking Pip does not advance the lesson.').toBe(true);

  await page.emulateMedia({ reducedMotion: 'reduce' });
  // The short pronunciation finishes before checking a stationary whole body.
  await page.waitForTimeout(1800);
  await expectStill(page, area.body);
  await page.screenshot({ path: testInfo.outputPath('pip-reduced-motion.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('page lifecycle pauses Pip and resumes autonomous gestures without changing the lesson', async ({ page }, testInfo) => {
  test.setTimeout(120000);
  const errors = await openGame(page);
  await page.mouse.move(0, 0);
  await rendered(page);
  const area = await clips(page);
  const state = await gameState(page);
  const lesson = await capture(page, area.lesson);
  const resting = await capture(page, area.body);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await expectGesture(page, area.body, resting, testInfo, 'pip-before-page-hide');

  for (const event of ['visibilitychange', 'pagehide']) {
    await page.evaluate(event => {
      if (event === 'visibilitychange') {
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        document.dispatchEvent(new Event('visibilitychange'));
      } else {
        window.dispatchEvent(new Event('pagehide'));
      }
    }, event);
    const paused = await expectStill(page, area.body);
    expect(await gameState(page)).toEqual(state);
    expect((await capture(page, area.lesson)).equals(lesson)).toBe(true);
    await page.screenshot({ path: testInfo.outputPath(`pip-paused-${event}.png`), scale: 'css' });

    await page.evaluate(event => {
      if (event === 'visibilitychange') {
        delete document.hidden;
        document.dispatchEvent(new Event('visibilitychange'));
      } else {
        window.dispatchEvent(new Event('pageshow'));
      }
    }, event);
    await expectGesture(page, area.body, paused, testInfo, `pip-resumed-${event}`);
    expect(await gameState(page)).toEqual(state);
    expect((await capture(page, area.lesson)).equals(lesson)).toBe(true);
  }
  await page.screenshot({ path: testInfo.outputPath('pip-resumed-learn.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
