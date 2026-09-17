const { test, expect } = require('@playwright/test');
const { metrics, tap, rendered, openGame, learnCardRect, learnArtRect: artRect, lessonPoint, swipeLearn,
  uiScale, modeHeight, modeRect, contentBounds, headerIconRect, chooseMode, boardPoint, visibleColorCount } = require('./game-ui.cjs');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');

const INTRO = 'Learn five words. Swipe left or right; tap the picture to hear.';
const WORD = /^Learn: ([a-z]+)\. Swipe to explore\. Tap the picture to hear\.$/;
const SAVES = ['wordBuddies.medalProgress', 'wordBuddies.playroom', 'wordBuddies.favoriteReward'];
const wordStatus = word => `Learn: ${word}. Swipe to explore. Tap the picture to hear.`;
const audioStarts = page => page.evaluate(() => window.learnAudio.starts);

async function savedState(page) {
  return page.evaluate(keys => ({
    records: keys.map(key => [key, localStorage.getItem(key)]),
    selection: document.getElementById('selection-status').textContent
  }), SAVES);
}

async function currentWord(page) {
  await expect(page.locator('#game-status')).toHaveText(WORD);
  return (await page.locator('#game-status').textContent()).match(WORD)[1];
}

async function begin(page, { silent = false, controller = false, reducedMotion = 'reduce' } = {}) {
  if (controller) await installGamepad(page);
  await page.addInitScript(silent => {
    if (silent) {
      Object.defineProperty(window, 'AudioContext', { configurable: true, value: undefined });
      Object.defineProperty(window, 'webkitAudioContext', { configurable: true, value: undefined });
    }
    const NativeContext = window.AudioContext || window.webkitAudioContext;
    window.learnAudio = { available: Boolean(NativeContext), starts: 0 };
    if (!NativeContext) return;
    const WrappedContext = new Proxy(NativeContext, {
      construct(Target, args) {
        const context = Reflect.construct(Target, args);
        const createSource = context.createBufferSource.bind(context);
        context.createBufferSource = () => {
          const source = createSource(), start = source.start.bind(source);
          source.start = (...values) => {
            window.learnAudio.starts++;
            return start(...values);
          };
          return source;
        };
        return context;
      }
    });
    if (window.AudioContext) window.AudioContext = WrappedContext;
    else window.webkitAudioContext = WrappedContext;
  }, silent);
  const errors = await openGame(page, { reducedMotion });
  const saved = await savedState(page), starts = await audioStarts(page);
  // A real swipe focuses the picture before testing its focused keyboard navigation.
  await swipeLearn(page, 'next');
  const second = await currentWord(page);
  await page.keyboard.press('ArrowLeft');
  await expect(page.locator('#game-status')).not.toHaveText(wordStatus(second));
  const first = await currentWord(page);
  expect(first).not.toBe(second);
  expect(await audioStarts(page), 'Swipe and keyboard navigation must not autoplay.').toBe(starts);
  if (controller) await page.evaluate(() => window.gamepadFixture.connect());
  return { errors, saved, starts, first, second };
}

function screenPoint(bounds, point) {
  return { x: bounds.x + point.x * bounds.scale, y: bounds.y + point.y * bounds.scale };
}

async function mouseDrag(page, bounds, points, beforeRelease = async () => {}) {
  const start = screenPoint(bounds, points[0]);
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  try {
    await rendered(page);
    for (const point of points.slice(1)) {
      const end = screenPoint(bounds, point);
      await page.mouse.move(end.x, end.y, { steps: 4 });
      await rendered(page);
    }
    await beforeRelease();
  } finally {
    await page.mouse.up();
  }
  await rendered(page);
}

async function expectHear(page, word, activate) {
  const before = await page.locator('#game-status').textContent();
  const starts = await audioStarts(page);
  await activate();
  if (await page.evaluate(() => window.learnAudio.available)) {
    await expect(page.locator('#game-status')).toHaveText(`${word}. Look at the picture and say the word.`);
    await expect.poll(() => audioStarts(page)).toBeGreaterThan(starts);
  } else {
    await expect(page.locator('#game-status')).toHaveText(before);
  }
  await expect(page.locator('#selection-status')).toBeEmpty();
}

async function cardSnapshot(page) {
  const bounds = await metrics(page), card = learnCardRect(bounds);
  await page.mouse.move(0, 0);
  await rendered(page);
  return page.screenshot({ scale: 'css', clip: {
    ...screenPoint(bounds, card), width: card.width * bounds.scale, height: card.height * bounds.scale
  } });
}

function wordPatch(bounds, width = 128) {
  const card = learnCardRect(bounds), scale = uiScale(bounds);
  const wide = card.width >= 420 && card.width >= card.height * 1.3;
  const picture = artRect(bounds);
  const label = wide
    ? { x: card.x + card.width / 2, y: card.y + card.height / 2 - 40 / scale, width: card.width / 2 - 12 / scale }
    : { x: card.x + 8 / scale, y: picture.y + picture.height + 4 / scale, width: card.width - 16 / scale };
  width = Math.min(width / scale, label.width - 8 / scale);
  return { x: label.x + (label.width - width) / 2, y: label.y + 2 / scale, width, height: 48 / scale };
}

function screenClip(bounds, rect, padding = 0) {
  const point = screenPoint(bounds, rect);
  return { x: Math.round(point.x) - padding, y: Math.round(point.y) - padding,
    width: Math.round(rect.width * bounds.scale) + padding * 2,
    height: Math.round(rect.height * bounds.scale) + padding * 2 };
}

async function capturePatch(page, bounds, rect, padding = 0) {
  return page.screenshot({ clip: screenClip(bounds, rect, padding), scale: 'css' });
}

async function comparePatches(page, expected, actual, other = null, padding = 1, colors = false) {
  return page.evaluate(async ({ sources, padding, colors }) => {
    const images = await Promise.all(sources.map(async source => {
      if (!source) return null;
      const image = new Image();
      image.src = 'data:image/png;base64,' + source;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      const pixels = context.getImageData(0, 0, canvas.width, canvas.height);
      const colors = new Map();
      for (let index = 0; index < pixels.data.length; index += 4) {
        const color = (pixels.data[index] >> 4) << 8 | (pixels.data[index + 1] >> 4) << 4 | pixels.data[index + 2] >> 4;
        colors.set(color, (colors.get(color) || 0) + 1);
      }
      const background = [...colors].sort((a, b) => b[1] - a[1])[0][0];
      const channels = [background >> 8, background >> 4 & 15, background & 15].map(value => value * 16 + 8);
      const ink = Array.from({ length: pixels.width * pixels.height }, (_, index) =>
        channels.reduce((sum, value, channel) => sum + (pixels.data[index * 4 + channel] - value) ** 2, 0) > 60 ** 2);
      return { width: pixels.width, height: pixels.height, data: pixels.data, ink };
    }));
    const [target, moved, alternative] = images;
    if (moved.width !== target.width + padding * 2 || moved.height !== target.height + padding * 2) {
      throw new Error('Word comparison crop sizes changed.');
    }
    const distance = (a, ai, b, bi) => [0, 1, 2].reduce((sum, channel) => sum + (a.data[ai * 4 + channel] - b.data[bi * 4 + channel]) ** 2, 0);
    const mask = target.ink.map((ink, index) => alternative
      ? colors ? distance(target, index, alternative, index) > 60 ** 2 : ink !== alternative.ink[index] : ink);
    const pixels = mask.filter(Boolean).length;
    let difference = 1;
    for (let dy = 0; dy <= padding * 2; dy++) for (let dx = 0; dx <= padding * 2; dx++) {
      let changed = 0;
      for (let y = 0; y < target.height; y++) for (let x = 0; x < target.width; x++) {
        const index = y * target.width + x;
        const shifted = (y + dy) * moved.width + x + dx;
        if (mask[index] && (colors ? distance(target, index, moved, shifted) > 60 ** 2 : target.ink[index] !== moved.ink[shifted])) changed++;
      }
      difference = Math.min(difference, changed / Math.max(1, pixels));
    }
    return { difference, pixels };
  }, { sources: [expected, actual, other].map(image => image?.toString('base64') || null), padding, colors });
}

async function expectPatch(page, bounds, rect, expected, message, other = null, colors = false) {
  const actual = await capturePatch(page, bounds, rect, 1);
  const comparison = await comparePatches(page, expected, actual, other, 1, colors);
  expect(comparison.pixels, 'The comparison must include distinguishing picture or word pixels.').toBeGreaterThan(20);
  expect(comparison.difference, message).toBeLessThan(0.2);
}

async function settledPatch(page, bounds, rect, expected) {
  let previous;
  await expect.poll(async () => {
    const current = await capturePatch(page, bounds, rect, 1);
    const comparison = await comparePatches(page, expected, current);
    const stable = previous?.equals(current);
    previous = current;
    return comparison.pixels > 20 && comparison.difference < 0.2 && Boolean(stable);
  }, { timeout: 3000, intervals: [60], message: 'The card settles back into its original visible frame.' }).toBe(true);
}

async function withDrag(page, bounds, input, start, action) {
  if (input === 'mouse') {
    return mouseDrag(page, bounds, [start], () => action(async point => {
      const end = screenPoint(bounds, point);
      await page.mouse.move(end.x, end.y, { steps: 4 });
      await rendered(page);
    }));
  }
  const client = await page.context().newCDPSession(page);
  let pressed = false;
  try {
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...screenPoint(bounds, start) }] });
    pressed = true;
    await rendered(page);
    await action(async point => {
      await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, ...screenPoint(bounds, point) }] });
      await rendered(page);
    });
  } finally {
    if (pressed) await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await client.detach();
  }
  await rendered(page);
}

async function watchSettling(page, bounds, patch, committedStatus) {
  await page.evaluate(({ crop, committedStatus }) => {
    const source = document.getElementById('canvas'), rect = source.getBoundingClientRect();
    const canvas = document.createElement('canvas');
    canvas.width = crop.width; canvas.height = crop.height;
    const context = canvas.getContext('2d', { willReadFrequently: true });
    const result = window.learnSettleCapture = { hashes: [], done: false };
    const until = performance.now() + 900;
    const sample = now => {
      if (document.getElementById('game-status').textContent === committedStatus) {
        context.drawImage(source, (crop.x - rect.x) * source.width / rect.width, (crop.y - rect.y) * source.height / rect.height,
          crop.width * source.width / rect.width, crop.height * source.height / rect.height, 0, 0, crop.width, crop.height);
        const { data } = context.getImageData(0, 0, crop.width, crop.height);
        let hash = 2166136261, opaque = 0;
        for (let index = 0; index < data.length; index += 4) {
          opaque += Number(data[index + 3] > 245);
          hash = Math.imul(hash ^ Number(data[index] + data[index + 1] + data[index + 2] < 600), 16777619);
        }
        if (opaque > data.length / 4 * 0.95) result.hashes.push(hash >>> 0);
      }
      if (now < until) requestAnimationFrame(sample);
      else result.done = true;
    };
    requestAnimationFrame(sample);
  }, { crop: screenClip(bounds, patch), committedStatus });
}

test('Learn mouse swipes commit on release, stay silent and clamp at both ends', async ({ page }, testInfo) => {
  const { errors, saved, starts, first, second } = await begin(page);
  const bounds = await metrics(page), card = learnCardRect(bounds);
  const left = { x: card.x + card.width * 0.25, y: card.y + card.height / 2 };
  const right = { ...left, x: card.x + card.width * 0.75 };
  await swipeLearn(page, 'previous');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  await mouseDrag(page, bounds, [right, left], async () => {
    await expect(page.locator('#game-status'), 'Dragging alone cannot turn the card.').toHaveText(wordStatus(first));
    expect(await savedState(page)).toEqual(saved);
    expect(await audioStarts(page)).toBe(starts);
  });
  await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
  const words = [first, second];
  for (let index = 2; index < 5; index++) {
    await swipeLearn(page, 'next');
    words.push(await currentWord(page));
  }
  expect(new Set(words).size).toBe(5);
  for (let index = 0; index < 2; index++) {
    await swipeLearn(page, 'next');
    await expect(page.locator('#game-status'), 'The last word must not start Match automatically.').toHaveText(wordStatus(words[4]));
  }
  await swipeLearn(page, 'previous');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(words[3]));
  await swipeLearn(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(words[4]));
  expect(await audioStarts(page), 'No swipe may start word or background audio.').toBe(starts);
  expect(await savedState(page)).toEqual(saved);
  const still = await cardSnapshot(page);
  await page.waitForTimeout(350);
  expect((await cardSnapshot(page)).equals(still), 'Reduced-motion swipes replace the association immediately and leave it still.').toBe(true);
  const center = lessonPoint(bounds, 'picture');
  await expectHear(page, words[4], () => mouseDrag(page, bounds, [center, { x: center.x + 6, y: center.y + 4 }]));
  const screen = screenPoint(bounds, center);
  await expectHear(page, words[4], () => page.mouse.click(screen.x, screen.y));
  expect(await savedState(page)).toEqual(saved);
  await page.screenshot({ path: testInfo.outputPath('learn-last-word-no-footer.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('Learn ignores vertical, short, diagonal and outside-card mouse drags', async ({ page }) => {
  const { errors, saved, starts, first } = await begin(page);
  const bounds = await metrics(page), card = learnCardRect(bounds), center = lessonPoint(bounds, 'picture');
  const threshold = Math.max(40, Math.min(card.width * 0.12, 96));
  const distance = threshold + 20;
  for (const points of [
    [center, { x: center.x, y: center.y - distance }],
    [center, { x: center.x - threshold + 4, y: center.y }],
    [center, { x: center.x - distance, y: center.y + distance }],
    [center, { x: card.x - 4, y: center.y }],
    [{ x: card.x - 4, y: center.y }, center],
    [center, { x: center.x, y: center.y - 24 }, center],
    [center, { x: center.x - distance, y: center.y }, { x: center.x + 6, y: center.y }]
  ]) {
    await mouseDrag(page, bounds, points);
    await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
    expect(await audioStarts(page), 'A rejected drag is not a pronunciation tap.').toBe(starts);
    expect(await savedState(page)).toEqual(saved);
  }
  await swipeLearn(page, 'next');
  await expect(page.locator('#game-status')).not.toHaveText(wordStatus(first));
  expect(errors).toEqual([]);
});

test('Learn horizontal out-and-back touch drag restores home before release', async ({ page, browserName }, testInfo) => {
  test.skip(browserName !== 'chromium', 'Trusted touch reversal uses Chromium CDP.');
  const { errors, saved, starts, first } = await begin(page);
  const bounds = await metrics(page), card = learnCardRect(bounds);
  const start = { x: card.x + card.width * 0.75, y: card.y + card.height / 2 };
  await page.mouse.move(0, 0);
  await rendered(page);
  await withDrag(page, bounds, 'touch', start, async move => {
    const home = await page.screenshot({ path: testInfo.outputPath('reversal-home.png'), scale: 'css' });
    await move({ x: start.x - card.width * 0.4, y: start.y });
    const displaced = await page.screenshot({ path: testInfo.outputPath('reversal-out.png'), scale: 'css' });
    expect(displaced.equals(home), 'The outward leg must visibly move the card and reveal its neighbor.').toBe(false);
    await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
    await move({ x: start.x + 6, y: start.y });
    const returned = await page.screenshot({ path: testInfo.outputPath('reversal-returned.png'), scale: 'css' });
    expect(returned.equals(home), 'Returning within 12 logical pixels restores the entire display and hides the neighbor while still held.').toBe(true);
    await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
    expect(await audioStarts(page)).toBe(starts);
    expect(await savedState(page)).toEqual(saved);
  });
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  expect(await audioStarts(page), 'A long out-and-back gesture must not become a pronunciation tap.').toBe(starts);
  expect(await savedState(page)).toEqual(saved);
  expect(errors).toEqual([]);
});

test('Learn slides have no pointer-state variation and reserve outlines for keyboard focus', async ({ page }, testInfo) => {
  const { errors, saved, first } = await begin(page);
  const bounds = await metrics(page), center = lessonPoint(bounds, 'picture');
  await expectHear(page, first, () => tap(page, center.x, center.y));
  const normal = await cardSnapshot(page);
  const reference = await capturePatch(page, bounds, learnCardRect(bounds));
  await testInfo.attach('neutral-normal', { body: reference, contentType: 'image/png' });
  const screen = screenPoint(bounds, center);
  await page.mouse.move(screen.x, screen.y);
  await rendered(page);
  const hover = await capturePatch(page, bounds, learnCardRect(bounds));
  await testInfo.attach('neutral-hover', { body: hover, contentType: 'image/png' });
  expect(hover.equals(reference), 'Hover cannot recolor the neutral slide.').toBe(true);
  await page.mouse.down();
  try {
    await rendered(page);
    const pressed = await capturePatch(page, bounds, learnCardRect(bounds));
    await testInfo.attach('neutral-pressed', { body: pressed, contentType: 'image/png' });
    expect(pressed.equals(reference),
      'Pointer press cannot recolor the card or add a selection glow.').toBe(true);
  } finally { await page.mouse.up(); }
  expect((await cardSnapshot(page)).equals(normal), 'Hover, press and pointer focus preserve the same neutral slide.').toBe(true);
  await page.keyboard.press('Tab');
  await page.keyboard.press('Shift+Tab');
  await rendered(page);
  const keyboard = await cardSnapshot(page);
  expect(keyboard.equals(normal), 'Keyboard focus retains a visible outline.').toBe(false);
  await expectHear(page, first, () => tap(page, center.x, center.y));
  expect((await cardSnapshot(page)).equals(normal), 'Returning to pointer input removes the keyboard outline.').toBe(true);
  expect(await savedState(page)).toEqual(saved);
  await page.screenshot({ path: testInfo.outputPath('learn-neutral-pointer-style.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('Learn progress travels inside the card and the adjacent preview shows its own index', async ({ page, browserName }, testInfo) => {
  test.skip(browserName !== 'chromium', 'Trusted preview positioning uses Chromium CDP.');
  await page.setViewportSize({ width: 320, height: 568 });
  const { errors, saved, starts, first, second } = await begin(page);
  const bounds = await metrics(page), card = learnCardRect(bounds), scale = uiScale(bounds);
  const counter = { x: card.x + card.width - 64 / scale, y: card.y + 12 / scale,
    width: Math.min(52 / scale, 64 / scale - 12 - 2 / bounds.scale), height: 24 / scale };
  await page.keyboard.press('ArrowRight');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
  await page.mouse.move(0, 0);
  await rendered(page);
  const nextCounter = await capturePatch(page, bounds, counter);
  await page.keyboard.press('ArrowLeft');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  await rendered(page);
  const firstCounter = await capturePatch(page, bounds, counter);
  const start = { x: card.x + card.width - 4 / scale, y: card.y + card.height / 2 };
  await withDrag(page, bounds, 'touch', start, async move => {
    const shift = -Math.round(card.width * bounds.scale * 0.2) / bounds.scale;
    await move({ x: start.x + shift, y: start.y });
    await expectPatch(page, bounds, { ...counter, x: counter.x + shift }, firstCounter,
      'The current counter belongs to the sliding card, not an external header.');
    await move({ x: card.x - 8 / scale, y: start.y });
    await expectPatch(page, bounds, { ...counter, x: counter.x + 12 }, nextCounter,
      'The adjacent card has the next index rather than duplicating the current counter.', firstCounter);
    await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
    await page.screenshot({ path: testInfo.outputPath('learn-adjacent-progress.png'), scale: 'css' });
  });
  await expect(page.locator('#game-status'), 'Releasing outside the original display cannot commit the preview.').toHaveText(wordStatus(first));
  expect(await audioStarts(page)).toBe(starts);
  expect(await savedState(page)).toEqual(saved);
  expect(errors).toEqual([]);
});

test('Learn real touch swipes reject invalid drags and multitouch without emulated clicks', async ({ page, browserName }, testInfo) => {
  test.skip(browserName !== 'chromium', 'Real native touch-move and cancellation use Chromium CDP.');
  const { errors, saved, starts, first, second } = await begin(page);
  const bounds = await metrics(page), card = learnCardRect(bounds), center = lessonPoint(bounds, 'picture');
  const resetProbe = wordPatch(bounds), resetWord = await capturePatch(page, bounds, resetProbe);
  await swipeLearn(page, 'next', { input: 'touch' });
  await expect(page.locator('#game-status'), 'One touch swipe must turn exactly one word, not replay its emulated mouse event.').toHaveText(wordStatus(second));
  await swipeLearn(page, 'previous', { input: 'touch' });
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  await page.evaluate(() => {
    window.learnMultitouchEvents = [];
    document.addEventListener('touchstart', event => {
      if (event.touches.length > 1) window.learnMultitouchEvents.push({
        target: event.target.id, trusted: event.isTrusted, touches: event.touches.length
      });
    }, { capture: true });
  });
  const client = await page.context().newCDPSession(page);
  let pressed = false;
  const send = (type, points = []) => client.send('Input.dispatchTouchEvent', {
    type, touchPoints: points.map((point, index) => ({ id: index + 1, ...screenPoint(bounds, point) }))
  });
  const threshold = Math.max(40, Math.min(card.width * 0.12, 96));
  const end = { x: center.x - threshold - 20, y: center.y };
  try {
    for (const [name, destination] of [
      ['vertical', { x: center.x, y: center.y - threshold - 20 }],
      ['short', { x: center.x - threshold + 4, y: center.y }],
      ['diagonal', { x: end.x, y: center.y + threshold + 20 }],
      ['outside', { x: card.x - 4, y: center.y }],
      ['multitouch', end]
    ]) {
      await send('touchStart', [center]);
      pressed = true;
      await rendered(page);
      await send('touchMove', [destination]);
      await rendered(page);
      await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
      if (name === 'multitouch') {
        await send('touchStart', [destination, { x: center.x + 40, y: center.y + 40 }]);
        await rendered(page);
      }
      await send('touchEnd');
      pressed = false;
      await rendered(page);
      if (name === 'multitouch') {
        const events = await page.evaluate(() => window.learnMultitouchEvents);
        await testInfo.attach('trusted-multitouch', {
          body: JSON.stringify({ events, before: wordStatus(first), after: await page.locator('#game-status').textContent(),
            audioStartsBefore: starts, audioStartsAfter: await audioStarts(page) }, null, 2), contentType: 'application/json'
        });
        await page.screenshot({ path: testInfo.outputPath('learn-after-multitouch.png'), scale: 'css' });
        expect(events).toEqual([{ target: 'canvas', trusted: true, touches: 2 }]);
      }
      await expect(page.locator('#game-status'), `${name} touch input must leave the current word unchanged.`).toHaveText(wordStatus(first));
      await expectPatch(page, bounds, resetProbe, resetWord, `${name} touch input also restores the visible card position.`);
      expect(await audioStarts(page), `${name} cannot synthesize a word tap.`).toBe(starts);
      expect(await savedState(page)).toEqual(saved);
    }
  } finally {
    if (pressed) await send('touchCancel');
    await client.detach();
  }
  await expectHear(page, first, () => tap(page, center.x, center.y));
  await swipeLearn(page, 'next', { input: 'touch' });
  await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
  await page.screenshot({ path: testInfo.outputPath('learn-real-touch-next.png'), scale: 'css' });
  expect(await savedState(page)).toEqual(saved);
  expect(errors).toEqual([]);
});

test('Learn real touch cancellation discards the pending word change', async ({ page, browserName }, testInfo) => {
  test.skip(browserName !== 'chromium', 'Real native touch cancellation uses Chromium CDP.');
  const { errors, saved, starts, first } = await begin(page);
  const bounds = await metrics(page), card = learnCardRect(bounds);
  const resetProbe = wordPatch(bounds), resetWord = await capturePatch(page, bounds, resetProbe);
  const start = screenPoint(bounds, { x: card.x + card.width * 0.75, y: card.y + card.height / 2 });
  const end = screenPoint(bounds, { x: card.x + card.width * 0.25, y: card.y + card.height / 2 });
  await page.evaluate(() => {
    window.learnTouchCancelEvents = [];
    document.addEventListener('touchcancel', event => window.learnTouchCancelEvents.push({
      target: event.target.id, trusted: event.isTrusted, touches: event.changedTouches.length
    }), { capture: true, once: true });
  });
  const client = await page.context().newCDPSession(page);
  let pressed = false;
  try {
    await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...start }] });
    pressed = true;
    await rendered(page);
    await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, ...end }] });
    await rendered(page);
    await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
    await page.screenshot({ path: testInfo.outputPath('learn-touch-before-cancel.png'), scale: 'css' });
    await client.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
    pressed = false;
    await rendered(page);
    const events = await page.evaluate(() => window.learnTouchCancelEvents);
    const after = await page.locator('#game-status').textContent();
    await testInfo.attach('trusted-touch-cancel', {
      body: JSON.stringify({ events, before: wordStatus(first), after }, null, 2), contentType: 'application/json'
    });
    await page.screenshot({ path: testInfo.outputPath('learn-touch-after-cancel.png'), scale: 'css' });
    expect(events).toEqual([{ target: 'canvas', trusted: true, touches: 1 }]);
    await expect(page.locator('#game-status'), 'A trusted browser touchcancel must discard the swipe rather than commit it.').toHaveText(wordStatus(first));
    await expectPatch(page, bounds, resetProbe, resetWord, 'Trusted cancellation resets the visible slide immediately.');
    expect(await audioStarts(page)).toBe(starts);
    expect(await savedState(page)).toEqual(saved);
    expect(errors).toEqual([]);
  } finally {
    if (pressed) await client.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
    await client.detach();
  }
});

test('Learn cancels in-flight swipes on resize, page lifecycle and More', async ({ page }, testInfo) => {
  const { errors, saved, starts, first, second } = await begin(page, { controller: true });
  const drag = async action => {
    const bounds = await metrics(page), card = learnCardRect(bounds);
    const y = card.y + card.height / 2;
    await mouseDrag(page, bounds, [
      { x: card.x + card.width * 0.75, y }, { x: card.x + card.width * 0.25, y }
    ], action);
  };
  await drag(async () => {
    const old = page.viewportSize();
    const next = old.width > old.height ? { width: 390, height: 844 } : { width: 844, height: 390 };
    await page.setViewportSize(next);
    await expect.poll(() => page.locator('#canvas').evaluate(canvas => canvas.getBoundingClientRect().width)).toBe(next.width);
    await rendered(page);
  });
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  const resetBounds = await metrics(page), resetProbe = wordPatch(resetBounds);
  const resetWord = await capturePatch(page, resetBounds, resetProbe);
  for (const event of ['visibilitychange', 'pagehide']) {
    await drag(async () => {
      await page.evaluate(event => {
        if (event === 'visibilitychange') {
          Object.defineProperty(document, 'hidden', { configurable: true, value: true });
          document.dispatchEvent(new Event(event));
        } else window.dispatchEvent(new Event(event));
      }, event);
      await rendered(page);
    });
    await page.evaluate(event => {
      if (event === 'visibilitychange') {
        delete document.hidden;
        document.dispatchEvent(new Event(event));
      } else window.dispatchEvent(new Event('pageshow'));
    }, event);
    await rendered(page);
    await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
    await expectPatch(page, resetBounds, resetProbe, resetWord, `${event} returns the card to its home position.`);
  }
  await drag(async () => {
    await pressGamepad(page, 3);
    await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  });
  await pressGamepad(page, 1);
  await expect(page.locator('#game-status')).toHaveText(INTRO);
  await expectPatch(page, resetBounds, resetProbe, resetWord, 'Returning from More cannot leave a partially dragged card.');
  await page.keyboard.press('ArrowRight');
  await expect(page.locator('#game-status'), 'Closing More preserves the word from before the canceled swipe.').toHaveText(wordStatus(second));
  await page.keyboard.press('ArrowLeft');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  expect(await audioStarts(page)).toBe(starts);
  expect(await savedState(page)).toEqual(saved);
  await page.screenshot({ path: testInfo.outputPath('learn-after-canceled-input.png'), scale: 'css' });
  await drag(async () => {
    // Picture -> Pip -> More -> Learn -> Match; a visible preview never takes focus.
    for (let index = 0; index < 4; index++) await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
    await expect(page.locator('#game-status')).toContainText('Find 3 word');
  });
  await expect(page.locator('#selection-status')).toBeEmpty();
  await chooseMode(page, 'learn');
  await expect(page.locator('#game-status')).toHaveText(INTRO);
  await expectPatch(page, resetBounds, resetProbe, resetWord, 'Replacing the mode discards the old slide before Learn returns.');
  expect(errors).toEqual([]);
});

test('Learn Enter, Space and Xbox A pronounce the focused picture without navigation', async ({ page }) => {
  const { errors, saved, first } = await begin(page, { controller: true });
  for (const activate of [
    () => page.keyboard.press('Enter'),
    () => page.keyboard.press('Space'),
    () => pressGamepad(page, 0)
  ]) await expectHear(page, first, activate);
  await page.keyboard.press('ArrowRight');
  await expect(page.locator('#game-status')).not.toHaveText(wordStatus(first));
  const next = await currentWord(page);
  expect(next).not.toBe(first);
  await page.keyboard.press('ArrowLeft');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  expect(await savedState(page)).toEqual(saved);
  expect(errors).toEqual([]);
});

test('Learn silent pictures support swipes, keyboard, D-pad and stick with no hidden footer stops', async ({ page }, testInfo) => {
  const { errors, saved, first, second } = await begin(page, { silent: true, controller: true });
  for (const [button, word] of [[15, second], [14, first]]) {
    await pressGamepad(page, button);
    await expect(page.locator('#game-status')).toHaveText(wordStatus(word));
  }
  for (const [direction, word] of [[1, second], [-1, first]]) {
    await page.evaluate(async direction => {
      window.gamepadFixture.axis(0, direction);
      await new Promise(resolve => setTimeout(resolve, 120));
      window.gamepadFixture.axis(0, 0);
      await new Promise(resolve => setTimeout(resolve, 120));
    }, direction);
    await expect(page.locator('#game-status')).toHaveText(wordStatus(word));
  }
  await swipeLearn(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
  await page.keyboard.press('ArrowLeft');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  for (const activate of [
    () => page.keyboard.press('Enter'),
    () => page.keyboard.press('Space'),
    () => pressGamepad(page, 0)
  ]) await expectHear(page, first, activate);
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status'), 'Tab wraps from the only Learn control to header Pip, not a hidden footer button.').toContainText('Pip says: duck!');
  const picture = lessonPoint(await metrics(page), 'picture');
  await tap(page, picture.x, picture.y);
  expect(await savedState(page)).toEqual(saved);
  await pressGamepad(page, 12);
  await pressGamepad(page, 0);
  await expect(page.locator('#game-status'), 'Up from the centered picture reaches the top Match mode tab.').toContainText('Find 3 word');
  expect(await audioStarts(page)).toBe(0);
  await page.screenshot({ path: testInfo.outputPath('learn-silent-header-navigation.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

for (const reducedMotion of ['reduce', 'no-preference']) {
for (const input of ['mouse', 'touch']) {
test(`Learn visibly follows the drag and previews the adjacent association (${reducedMotion}, ${input})`, async ({ page, browserName }, testInfo) => {
  test.skip(input === 'touch' && browserName !== 'chromium', 'Trusted touch dragging uses Chromium CDP.');
  const { errors, saved, starts, first, second } = await begin(page, { reducedMotion });
  const bounds = await metrics(page), card = learnCardRect(bounds), content = contentBounds(bounds);
  const probe = wordPatch(bounds), previewWord = wordPatch(bounds, 240), art = artRect(bounds);
  const firstShift = -Math.round(card.width * bounds.scale * 0.1) / bounds.scale;
  const farShift = -Math.round(card.width * bounds.scale * 0.9) / bounds.scale;
  const previewShift = card.width + 12 + farShift;
  previewWord.width = Math.min(previewWord.width, content.x + content.width - previewWord.x - previewShift - 4);
  const artInset = Math.max(4, content.x + 4 - art.x - firstShift);
  const movingArt = { x: art.x + artInset, y: art.y + 4, width: art.width - artInset - 4, height: art.height - 8 };
  const previewArt = { x: art.x + 4, y: art.y + 4,
    width: Math.min(art.width - 8, content.x + content.width - art.x - previewShift - 8), height: art.height - 8 };
  await test.step(`${input} drag`, async () => {
    await page.keyboard.press('ArrowLeft');
    await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
    await page.keyboard.press('ArrowRight');
    await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
    await page.mouse.move(0, 0);
    await rendered(page);
    const nextWord = await capturePatch(page, bounds, previewWord);
    const nextArt = await capturePatch(page, bounds, previewArt);
    const nextHome = await capturePatch(page, bounds, probe);
    await page.keyboard.press('ArrowLeft');
    await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
    await rendered(page);
    const oldWord = await capturePatch(page, bounds, previewWord);
    const oldArt = await capturePatch(page, bounds, previewArt);
    const homeWord = await capturePatch(page, bounds, probe);
    const homeArt = await capturePatch(page, bounds, movingArt);
    const start = { x: card.x + card.width * 0.95, y: card.y + card.height / 2 };
    await withDrag(page, bounds, input, start, async move => {
      await move({ x: start.x + firstShift, y: start.y });
      await expectPatch(page, bounds, { ...probe, x: probe.x + firstShift }, homeWord, 'The written word follows the finger one CSS pixel per pixel.');
      await expectPatch(page, bounds, { ...movingArt, x: movingArt.x + firstShift }, homeArt, 'The picture must move with the card, not stay behind.', null, true);
      const stillAtHome = await comparePatches(page, homeWord, await capturePatch(page, bounds, probe, 1));
      expect(stillAtHome.difference, 'A static canvas cannot satisfy the drag check.').toBeGreaterThan(0.25);
      const secondShift = -Math.round(card.width * bounds.scale * 0.3) / bounds.scale;
      await move({ x: start.x + secondShift, y: start.y });
      await expectPatch(page, bounds, { ...probe, x: probe.x + secondShift }, homeWord, 'A further drag updates the rendered word position immediately.');
      await move({ x: start.x + farShift, y: start.y });
      await expectPatch(page, bounds, { ...previewWord, x: previewWord.x + previewShift }, nextWord, 'The incoming preview shows the next word, not a clone of the current one.', oldWord);
      await expectPatch(page, bounds, { ...previewArt, x: previewArt.x + previewShift }, nextArt, 'The incoming picture belongs to that next association.', oldArt, true);
      await expect(page.locator('#game-status'), 'Neither drag-follow nor preview creation commits the next index.').toHaveText(wordStatus(first));
      expect(await savedState(page)).toEqual(saved);
      expect(await audioStarts(page)).toBe(starts);
      await page.screenshot({ path: testInfo.outputPath(`learn-follow-${input}.png`), scale: 'css' });
      await watchSettling(page, bounds, probe, wordStatus(second));
    });
    await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
    await page.waitForFunction(() => window.learnSettleCapture.done);
    const frames = await page.evaluate(() => ({
      count: window.learnSettleCapture.hashes.length, unique: new Set(window.learnSettleCapture.hashes).size
    }));
    expect(frames.count, 'Observe actual canvas frames after the index commits.').toBeGreaterThan(1);
    if (reducedMotion === 'reduce') expect(frames.unique, 'Reduced motion follows the hand, then settles immediately without a tween.').toBe(1);
    else expect(frames.unique, 'Normal motion visibly settles the incoming card after release.').toBeGreaterThan(1);
    await testInfo.attach(`settling-${input}`, { body: JSON.stringify(frames), contentType: 'application/json' });
    await settledPatch(page, bounds, probe, nextHome);
    expect(await savedState(page)).toEqual(saved);
    expect(await audioStarts(page)).toBe(starts);
  });
  expect(errors).toEqual([]);
});
}

test(`Learn resists the end of the lesson and snaps back from short drags (${reducedMotion})`, async ({ page }, testInfo) => {
  const { errors, saved, starts, first, second } = await begin(page, { reducedMotion });
  const bounds = await metrics(page), card = learnCardRect(bounds), probe = wordPatch(bounds);
  await page.mouse.move(0, 0);
  await rendered(page);
  const firstHome = await capturePatch(page, bounds, probe);
  const start = { x: card.x + card.width * 0.3, y: card.y + card.height / 2 };
  const distance = Math.round(card.width * bounds.scale * 0.25) / bounds.scale;
  await withDrag(page, bounds, 'mouse', start, async move => {
    await move({ x: start.x + distance, y: start.y });
    await expectPatch(page, bounds, { ...probe, x: probe.x + distance * 0.22 }, firstHome, 'An unavailable previous card rubber-bands at 22% of finger travel.');
    await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
    await page.screenshot({ path: testInfo.outputPath('learn-first-edge-resistance.png'), scale: 'css' });
  });
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  await settledPatch(page, bounds, probe, firstHome);
  await page.keyboard.press('ArrowRight');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
  await rendered(page);
  const secondHome = await capturePatch(page, bounds, probe);
  const threshold = Math.max(40, Math.min(card.width * 0.12, 96));
  const short = -Math.round(threshold * bounds.scale * 0.6) / bounds.scale;
  await withDrag(page, bounds, 'mouse', start, async move => {
    await move({ x: start.x + short, y: start.y });
    await expectPatch(page, bounds, { ...probe, x: probe.x + short }, secondHome, 'A short horizontal drag still follows the hand before snapping back.');
    await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
  });
  await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
  await settledPatch(page, bounds, probe, secondHome);
  let last = second;
  for (let index = 0; index < 3; index++) {
    await swipeLearn(page, 'next');
    await expect(page.locator('#game-status')).not.toHaveText(wordStatus(last));
    last = await currentWord(page);
  }
  await page.keyboard.press('ArrowLeft');
  await expect(page.locator('#game-status')).not.toHaveText(wordStatus(last));
  await page.keyboard.press('ArrowRight');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(last));
  await rendered(page);
  const lastHome = await capturePatch(page, bounds, probe);
  const lastStart = { x: card.x + card.width * 0.7, y: start.y };
  await withDrag(page, bounds, 'mouse', lastStart, async move => {
    await move({ x: lastStart.x - distance, y: lastStart.y });
    await expectPatch(page, bounds, { ...probe, x: probe.x - distance * 0.22 }, lastHome, 'The last word resists the unavailable next direction without wrapping.');
    await expect(page.locator('#game-status')).toHaveText(wordStatus(last));
  });
  await expect(page.locator('#game-status')).toHaveText(wordStatus(last));
  await settledPatch(page, bounds, probe, lastHome);
  expect(await audioStarts(page), 'Resistance and snap-back are not pronunciation taps.').toBe(starts);
  expect(await savedState(page)).toEqual(saved);
  expect(errors).toEqual([]);
});
}

test('Learn accepts a new press while the prior card is settling', async ({ page, browserName }, testInfo) => {
  test.skip(browserName !== 'chromium', 'Back-to-back trusted mouse release/press uses Chromium CDP.');
  const { errors, saved, starts, first, second } = await begin(page, { reducedMotion: 'no-preference' });
  const bounds = await metrics(page), card = learnCardRect(bounds), probe = wordPatch(bounds);
  await page.keyboard.press('ArrowRight');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
  await page.keyboard.press('ArrowRight');
  await expect(page.locator('#game-status')).not.toHaveText(wordStatus(second));
  const third = await currentWord(page);
  await page.keyboard.press('ArrowLeft');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
  await page.keyboard.press('ArrowLeft');
  await expect(page.locator('#game-status')).toHaveText(wordStatus(first));
  const client = await page.context().newCDPSession(page);
  const y = card.y + card.height / 2;
  const start = { x: card.x + card.width * 0.9, y }, end = { x: card.x + card.width * 0.1, y };
  const nextStart = { x: card.x + card.width * 0.6, y };
  const shift = -Math.round(card.width * bounds.scale * 0.2) / bounds.scale;
  const nextEnd = { x: nextStart.x + shift, y };
  let pressed = false;
  const send = (type, point, down) => client.send('Input.dispatchMouseEvent', {
    type, ...screenPoint(bounds, point), button: type === 'mouseMoved' ? 'none' : 'left', buttons: down ? 1 : 0, clickCount: 1
  });
  try {
    await send('mousePressed', start, true);
    pressed = true;
    await rendered(page);
    await send('mouseMoved', end, true);
    await rendered(page);
    await Promise.all([send('mouseReleased', end, false), send('mousePressed', nextStart, true)]);
    await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
    await rendered(page);
    const secondHome = await capturePatch(page, bounds, probe);
    await send('mouseMoved', nextEnd, true);
    await rendered(page);
    // The old 0.18s completion must not cancel a newer, still-held gesture.
    await page.waitForTimeout(250);
    await expectPatch(page, bounds, { ...probe, x: probe.x + shift }, secondHome, 'The new gesture remains in control after the old tween would have finished.');
    await expect(page.locator('#game-status')).toHaveText(wordStatus(second));
    await page.screenshot({ path: testInfo.outputPath('learn-interrupted-settling.png'), scale: 'css' });
    await send('mouseReleased', nextEnd, false);
    pressed = false;
    await expect(page.locator('#game-status')).toHaveText(wordStatus(third));
    expect(await audioStarts(page)).toBe(starts);
    expect(await savedState(page)).toEqual(saved);
    expect(errors).toEqual([]);
  } finally {
    if (pressed) await send('mouseReleased', nextEnd, false);
    await client.detach();
  }
});

for (const viewport of [
  { width: 320, height: 568 }, { width: 390, height: 844 },
  { width: 599, height: 900 }, { width: 600, height: 900 },
  { width: 768, height: 1024 }, { width: 1366, height: 768 }
]) {
test(`Learn has three centered modes, a square More icon and no topic or footer at ${viewport.width}x${viewport.height}`, async ({ page }, testInfo) => {
  await page.setViewportSize(viewport);
  const { errors, saved, first } = await begin(page);
  const bounds = await metrics(page), card = learnCardRect(bounds);
  await page.mouse.move(0, 0);
  await rendered(page);
  const png = await page.screenshot({ path: testInfo.outputPath('learn-full-card.png'), scale: 'css' });
  expect(await visibleColorCount(page, png)).toBeGreaterThan(20);
  await expect(page).toHaveTitle(/Pip and Words/);
  const content = contentBounds(bounds), mode = modeRect(bounds, 'learn');
  const more = headerIconRect(bounds);
  const scale = uiScale(bounds), picture = artRect(bounds);
  const lastMode = modeRect(bounds, 'memory');
  const header = content.inlineModes ? [
    { x: content.x + 60 / scale, width: mode.x - content.x - 64 / scale },
    { x: lastMode.x + lastMode.width + 4 / scale, width: more.x - lastMode.x - lastMode.width - 8 / scale }
  ] : [{ x: content.x + 60 / scale, width: content.width - 60 / scale - content.gap - more.width }];
  const headerClips = header.map(rect => screenClip(bounds, { ...rect, y: content.padding, height: content.header }));
  const topic = screenClip(bounds, { x: card.x + 32 / scale, y: card.y + 12 / scale,
    width: card.width - 128 / scale, height: 20 / scale });
  const modeBox = screenClip(bounds, mode);
  const iconBox = screenClip(bounds, more);
  const pictureBox = screenClip(bounds, picture, 1);
  const points = [card.x + 32, card.x + card.width - 32]
    .map(x => screenPoint(bounds, { x, y: card.y + card.height - 12 }));
  const visual = await page.evaluate(async ({ source, points, headerClips, topic, modeBox, iconBox, pictureBox, maxModeBottom }) => {
    const image = new Image();
    image.src = 'data:image/png;base64,' + source;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.width; canvas.height = image.height;
    const context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    const pixel = (x, y) => [...context.getImageData(Math.round(x), Math.round(y), 1, 1).data].slice(0, 3);
    const colorCount = (rect, exclude) => {
      const colors = new Set();
      for (let y = rect.y; y < rect.y + rect.height; y += 2) for (let x = rect.x; x < rect.x + rect.width; x += 2) {
        if (exclude && x >= exclude.x && x < exclude.x + exclude.width && y >= exclude.y && y < exclude.y + exclude.height) continue;
        colors.add(pixel(x, y).map(channel => channel >> 3).join(','));
      }
      return colors.size;
    };
    const x = modeBox.x + modeBox.width / 2, background = pixel(x, modeBox.y - 3);
    const filled = (x, y) => pixel(x, y).reduce((sum, channel, index) => sum + (channel - background[index]) ** 2, 0) > 6 ** 2;
    let top = Math.round(modeBox.y + modeBox.height / 2), bottom = top;
    while (top > modeBox.y - 4 && filled(x, top - 1)) top--;
    while (bottom < maxModeBottom && filled(x, bottom + 1)) bottom++;
    const y = Math.round(modeBox.y + modeBox.height / 2);
    let left = Math.round(x), right = left;
    while (left > modeBox.x - 4 && filled(left - 1, y)) left--;
    while (right < modeBox.x + modeBox.width + 4 && filled(right + 1, y)) right++;
    let bands = 0, inBand = false;
    for (let row = Math.ceil(iconBox.y + iconBox.height * 0.2); row < iconBox.y + iconBox.height * 0.8; row++) {
      let dark = 0;
      for (let column = Math.ceil(iconBox.x + iconBox.width * 0.2); column < iconBox.x + iconBox.width * 0.8; column++) {
        if (pixel(column, row).reduce((sum, channel) => sum + channel, 0) < 480) dark++;
      }
      const line = dark >= 8;
      if (line && !inBand) bands++;
      inBand = line;
    }
    return { pixels: points.map(point => pixel(point.x, point.y)), headerColors: headerClips.map(rect => colorCount(rect)),
      topicColors: colorCount(topic, pictureBox), modeHeight: bottom - top + 1, modeWidth: right - left + 1, moreBands: bands };
  }, { source: png.toString('base64'), points, headerClips, topic, modeBox, iconBox, pictureBox, maxModeBottom: Math.round(bounds.y + (mode.y + 72) * bounds.scale) });
  expect(visual.pixels, 'The white picture surface must extend to the bottom, not stop above a footer.').toEqual([[255, 255, 255], [255, 255, 255]]);
  expect(visual.headerColors, 'Header space outside Pip, the responsive mode row and More has no brand or Explore control.').toEqual(headerClips.map(() => 1));
  expect(visual.topicColors, 'Only the in-card counter remains, not Play time or another topic heading.').toBe(1);
  expect(content.inlineModes).toBe(viewport.width >= 600);
  expect(Math.abs(card.y * bounds.scale - (content.inlineModes ? 76 : 128))).toBeLessThanOrEqual(4);
  const portrait = card.width < 420 || card.width < card.height * 1.3;
  if (portrait) {
    expect((picture.y - card.y) * bounds.scale).toBeGreaterThanOrEqual(12);
    expect((picture.y - card.y) * bounds.scale).toBeLessThanOrEqual(64.01);
    const formerCenteredTop = (card.height - picture.height - 64 / scale) / 2;
    const upperHeight = Math.min(picture.height / 2, formerCenteredTop - (picture.y - card.y));
    if (upperHeight * bounds.scale >= 80) {
      const upperArt = await capturePatch(page, bounds, { ...picture, height: upperHeight });
      const foreground = await comparePatches(page, upperArt, upperArt, null, 0, true);
      expect(foreground.pixels, 'Tall portrait artwork occupies the bounded upper image area rather than leaving the former centered void.').toBeGreaterThan(20);
    }
  }
  const expectedModeHeight = modeHeight(bounds) * bounds.scale;
  expect(expectedModeHeight).toBeGreaterThanOrEqual(44);
  expect(Math.abs(visual.modeHeight - expectedModeHeight), 'The rendered selected tab has the compact adaptive height.').toBeLessThanOrEqual(2);
  expect(visual.modeHeight, 'Rasterized touch targets retain the 44 CSS-pixel minimum within one antialiasing pixel.').toBeGreaterThanOrEqual(43);
  expect(visual.modeHeight).toBeLessThan(content.header * bounds.scale - 2);
  expect(Math.abs(visual.modeWidth - mode.width * bounds.scale), 'Tabs use natural 80 CSS-pixel widths, centered as a three-mode group.').toBeLessThanOrEqual(2);
  expect(visual.moreBands, 'The More control renders three native icon lines rather than a text button.').toBe(3);
  expect(more.width).toBe(more.height);
  expect(more.width * bounds.scale).toBeGreaterThanOrEqual(44);
  expect(more.width * bounds.scale).toBeLessThan(46);
  await testInfo.attach('responsive-layout', { body: JSON.stringify({
    viewport, scale: bounds.scale, inlineModes: content.inlineModes, cardTopCss: card.y * bounds.scale,
    pictureTopCss: (picture.y - card.y) * bounds.scale, mode: modeBox,
    renderedMode: { width: visual.modeWidth, height: visual.modeHeight }, more: iconBox
  }), contentType: 'application/json' });
  await tap(page, more.x + 1 / bounds.scale, more.y + more.height / 2);
  await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toHaveText(INTRO);
  for (let column = 0; column < 4; column++) {
    await expectHear(page, first, () => tap(page, card.x + card.width * (column + 0.5) / 4, card.y + card.height - 44));
  }
  expect(await savedState(page), 'Former footer locations now only pronounce; they cannot start a game or change words.').toEqual(saved);
  const match = modeRect(bounds, 'match');
  await tap(page, match.x + match.width / 2, match.y + match.height - 1 / bounds.scale);
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  const learnFromMatch = modeRect(bounds, 'learn', 'match');
  await tap(page, learnFromMatch.x + learnFromMatch.width / 2, learnFromMatch.y + 1 / bounds.scale);
  await expect(page.locator('#game-status')).toHaveText(INTRO);
  const picturePoint = lessonPoint(bounds, 'picture');
  await tap(page, picturePoint.x, picturePoint.y);
  for (let index = 0; index < 6; index++) {
    await page.keyboard.press('Tab');
    await rendered(page);
  }
  await expectHear(page, first, () => page.keyboard.press('Enter'));
  await chooseMode(page, 'match');
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  const point = boardPoint(await metrics(page), 0);
  await tap(page, point.x, point.y);
  await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
  await page.screenshot({ path: testInfo.outputPath('match-responsive-header.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
}
