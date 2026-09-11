const { test, expect } = require('@playwright/test');
const { metrics, tap, rendered, openGame, visibleColorCount } = require('./game-ui.cjs');

const SAVES = ['wordBuddies.medalProgress', 'wordBuddies.playroom', 'wordBuddies.favoriteReward'];
const POKE = 'Quack! You tickled Pip!';
const PET = ['Pip leans into your hand. Lovely!', 'Soft strokes. Pip feels loved!'];

function playground(bounds) {
  // The room has no saved gift goal or displayed sticker in these fresh profiles.
  // Verified against the exported 390px room; all input uses its public canvas scale.
  const x = 16, y = 172, width = bounds.width - 32, height = 304;
  const foot = { x: x + 88, y: y + height - 32 };
  return {
    x, y, width, height, foot,
    pip: { x: foot.x, y: foot.y - 56 },
    body: { x: foot.x - 30, y: foot.y - 88, width: 60, height: 68 },
    toy: { x: x + width - 66, y: y + height - 74 },
    anchor: { x: x + 8, y: y + 4, width: width - 16, height: 32 },
    shortcut: index => ({ x: x + width * (index + 0.5) / 4, y: y + height + 64 })
  };
}

async function begin(page, { width = 390, height = 844, reducedMotion = 'no-preference' } = {}) {
  await page.setViewportSize({ width, height });
  // Isolate pointer/movement behavior from pronunciation downloads and mouth animation.
  await page.addInitScript(() => {
    Object.defineProperty(window, 'AudioContext', { configurable: true, value: undefined });
    Object.defineProperty(window, 'webkitAudioContext', { configurable: true, value: undefined });
  });
  const errors = await openGame(page, { reducedMotion });
  const lesson = await page.locator('#game-status').textContent();
  const bounds = await openRoom(page);
  const saved = await savedState(page);
  return { errors, lesson, bounds, room: playground(bounds), saved };
}

async function savedState(page) {
  return page.evaluate(keys => ({
    selection: document.getElementById('selection-status').textContent,
    saves: keys.map(key => [key, localStorage.getItem(key)])
  }), SAVES);
}

async function openRoom(page) {
  const bounds = await metrics(page);
  await tap(page, bounds.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  await rendered(page);
  return bounds;
}

function screenPoint(bounds, point) {
  return { x: bounds.x + point.x * bounds.scale, y: bounds.y + point.y * bounds.scale };
}

function screenClip(bounds, rect) {
  return { ...screenPoint(bounds, rect), width: rect.width * bounds.scale, height: rect.height * bounds.scale };
}

async function mouseDrag(page, bounds, points, moved = async () => {}) {
  const first = screenPoint(bounds, points[0]);
  await page.mouse.move(first.x, first.y);
  await page.mouse.down();
  try {
    for (const [index, point] of points.slice(1).entries()) {
      const position = screenPoint(bounds, point);
      await page.mouse.move(position.x, position.y, { steps: 3 });
      await rendered(page);
      await moved(point, index);
    }
  } finally {
    await page.mouse.up();
  }
}

async function touchDrag(page, bounds, points, moved = async () => {}) {
  const client = await page.context().newCDPSession(page);
  let pressed = false;
  try {
    for (const [index, point] of points.entries()) {
      await client.send('Input.dispatchTouchEvent', {
        type: index === 0 ? 'touchStart' : 'touchMove',
        touchPoints: [{ id: 1, ...screenPoint(bounds, point) }]
      });
      pressed = true;
      await rendered(page);
      if (index > 0) await moved(point, index - 1);
    }
  } finally {
    if (pressed) await client.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await client.detach();
  }
}

async function patch(page, bounds, rect) {
  return page.screenshot({ clip: screenClip(bounds, rect), scale: 'css' });
}

async function changedFraction(page, before, after, padding = 0) {
  return page.evaluate(async ({ sources, padding }) => {
    const pixels = await Promise.all(sources.map(async source => {
      const image = new Image();
      image.src = 'data:image/png;base64,' + source;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      return context.getImageData(0, 0, canvas.width, canvas.height);
    }));
    const [a, b] = pixels;
    if (b.width !== a.width + padding * 2 || b.height !== a.height + padding * 2) {
      throw new Error('Compared image sizes changed.');
    }
    let minimum = 1;
    for (let dy = 0; dy <= padding * 2; dy++) for (let dx = 0; dx <= padding * 2; dx++) {
      let changed = 0;
      for (let y = 0; y < a.height; y++) for (let x = 0; x < a.width; x++) {
        const ai = (y * a.width + x) * 4, bi = ((y + dy) * b.width + x + dx) * 4;
        const distance = [0, 1, 2].reduce((total, channel) =>
          total + (a.data[ai + channel] - b.data[bi + channel]) ** 2, 0);
        if (distance > 60 ** 2) changed++;
      }
      minimum = Math.min(minimum, changed / (a.width * a.height));
    }
    return minimum;
  }, { sources: [before, after].map(png => png.toString('base64')), padding });
}

async function visibleChange(page, bounds, rect, before, testInfo, name, minimum = 0.05) {
  let frame, changed;
  await expect.poll(async () => {
    frame = await patch(page, bounds, rect);
    changed = await changedFraction(page, before, frame);
    return changed;
  }, { timeout: 3000, intervals: [80], message: `${name} must visibly affect the rendered playfield.` }).toBeGreaterThan(minimum);
  await testInfo.attach(name, { body: frame, contentType: 'image/png' });
  await testInfo.attach(`${name}-changed-pixels`, {
    body: `${(changed * 100).toFixed(1)}%`, contentType: 'text/plain'
  });
}

async function visibleBall(page, bounds, rect, original) {
  const clip = screenClip(bounds, rect);
  // Fractional canvas scaling can shift opposite-side crops by one CSS pixel.
  // Compare the entire original patch inside a padded capture; never trim its edges.
  const padded = { x: clip.x - 1, y: clip.y - 1, width: clip.width + 2, height: clip.height + 2 };
  await expect.poll(async () => changedFraction(page, original,
    await page.screenshot({ clip: padded, scale: 'css' }), 1), {
    timeout: 4000, intervals: [100],
    message: 'The complete ball remains visible in its own resting place, away from Pip.'
  }).toBeLessThan(0.08);
}

async function screenshot(page, testInfo, name) {
  await rendered(page);
  const full = await page.screenshot({ path: testInfo.outputPath(`${name}.png`), scale: 'css' });
  const canvas = await page.locator('#canvas').screenshot({ path: testInfo.outputPath(`${name}-canvas.png`), scale: 'css' });
  expect(await visibleColorCount(page, full), `${name}: page must show the game`).toBeGreaterThan(20);
  expect(await visibleColorCount(page, canvas), `${name}: raw canvas must show the game`).toBeGreaterThan(20);
}

test('Pip responds visibly to a poke and real strokes without scrolling the room', async ({ page, browserName }, testInfo) => {
  const { errors, bounds, room, saved } = await begin(page);
  const anchor = await patch(page, bounds, room.anchor);
  const before = await patch(page, bounds, room.body);
  await tap(page, room.pip.x, room.pip.y);
  await expect(page.locator('#game-status')).toHaveText(POKE);
  await visibleChange(page, bounds, room.body, before, testInfo, 'pip-poke-body');
  await screenshot(page, testInfo, 'pip-poke');

  const strokes = [0, 23, -23, 23, -23, 23, 0].map(offset => ({
    x: room.pip.x + offset, y: room.pip.y - 18
  }));
  for (const [name, drag] of [
    ['mouse', mouseDrag],
    ...(browserName === 'chromium' ? [['touch', touchDrag]] : [])
  ]) {
    if (name === 'touch') {
      await tap(page, room.pip.x, room.pip.y);
      await expect(page.locator('#game-status')).toHaveText(POKE);
    }
    const resting = await patch(page, bounds, room.body);
    await drag(page, bounds, strokes);
    await page.mouse.move(0, 0);
    await expect(page.locator('#game-status')).toHaveText(PET[name === 'mouse' ? 0 : 1]);
    await visibleChange(page, bounds, room.body, resting, testInfo, `pip-${name}-stroke-body`);
    await screenshot(page, testInfo, `pip-${name}-stroke`);
    expect((await patch(page, bounds, room.anchor)).equals(anchor), `${name} stroking cannot scroll the room`).toBe(true);
    expect(await savedState(page)).toEqual(saved);
  }
  // A release must leave the next independent tap usable, with no stuck drag owner.
  await tap(page, room.pip.x, room.pip.y);
  await expect(page.locator('#game-status')).toHaveText(POKE);
  expect(await savedState(page)).toEqual(saved);
  expect(errors).toEqual([]);
});

test('a dragged ball visibly travels to Pip and empty ground makes Pip walk and run', async ({ page }, testInfo) => {
  const { errors, bounds, room, saved } = await begin(page);
  const anchor = await patch(page, bounds, room.anchor);
  const toyRect = { x: room.toy.x - 28, y: room.toy.y - 28, width: 56, height: 56 };
  const ball = await patch(page, bounds, toyRect);
  await mouseDrag(page, bounds, [room.toy,
    { x: room.toy.x - 65, y: room.toy.y - 30 }, room.pip
  ], async (_, index) => {
    if (index === 0) {
      await visibleChange(page, bounds, toyRect, ball, testInfo, 'ball-leaves-resting-place', 0.12);
      await screenshot(page, testInfo, 'ball-held-in-playground');
    }
  });
  await page.mouse.move(0, 0);
  await expect(page.locator('#game-status')).toHaveText(/^Pip (caught|fetched) the ball!/);
  await screenshot(page, testInfo, 'ball-caught');
  expect((await patch(page, bounds, room.anchor)).equals(anchor), 'Throwing the ball cannot scroll the room').toBe(true);
  await expect.poll(async () => changedFraction(page, ball, await patch(page, bounds, toyRect)), {
    timeout: 4000, intervals: [100], message: 'The ball visibly returns home before testing ground movement.'
  }).toBeLessThan(0.02);

  const near = { x: room.foot.x + 88, y: room.foot.y + 2 };
  const far = { x: room.x + room.width - 55, y: room.foot.y + 2 };
  for (const [name, destination, message] of [
    ['walk', near, 'Pip walks over!'], ['run', far, 'Pip runs over!']
  ]) {
    // These patches contain the destination floor, not captions or button focus rings.
    const arrival = { x: destination.x - 24, y: destination.y - 76, width: 48, height: 58 };
    const empty = await patch(page, bounds, arrival);
    await tap(page, destination.x, destination.y);
    await expect(page.locator('#game-status')).toHaveText(message);
    await visibleChange(page, bounds, arrival, empty, testInfo, `pip-${name}-arrival`, 0.18);
    if (name === 'run') {
      // Arrival must finish and move the resting ball out from under Pip before capture.
      await visibleBall(page, bounds, { ...toyRect, x: room.x + 66 - 28 }, ball);
    }
    await screenshot(page, testInfo, `pip-${name}`);
    expect((await patch(page, bounds, room.anchor)).equals(anchor), 'Ground input cannot scroll the room').toBe(true);
  }
  expect(await savedState(page)).toEqual(saved);
  expect(errors).toEqual([]);
});

test('leaving during a gesture restores input and gift-list drags still scroll without equipping', async ({ page }, testInfo) => {
  const { errors, lesson, bounds, room, saved } = await begin(page);
  const point = screenPoint(bounds, room.pip);
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  try {
    await page.mouse.move(point.x + 24 * bounds.scale, point.y, { steps: 4 });
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toHaveText(lesson);
  } finally {
    await page.mouse.up();
  }
  await openRoom(page);
  await tap(page, room.pip.x, room.pip.y);
  await expect(page.locator('#game-status')).toHaveText(POKE);
  await screenshot(page, testInfo, 'pip-after-interrupted-stroke');

  const toss = room.shortcut(2);
  await tap(page, toss.x, toss.y);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toHaveText(lesson);
  await page.waitForTimeout(250);
  await expect(page.locator('#game-status')).toHaveText(lesson);
  await openRoom(page);
  await tap(page, room.pip.x, room.pip.y);
  await expect(page.locator('#game-status')).toHaveText(POKE);

  const list = { x: 24, y: bounds.height - 180, width: bounds.width - 48, height: 140 };
  const before = await patch(page, bounds, list);
  await mouseDrag(page, bounds, [
    { x: bounds.width * 0.75, y: bounds.height - 60 },
    { x: bounds.width * 0.75, y: bounds.height - 260 }
  ]);
  await visibleChange(page, bounds, list, before, testInfo, 'gift-list-scroll', 0.15);
  await screenshot(page, testInfo, 'gift-list-after-drag');
  await expect(page.locator('#game-status')).toHaveText(POKE);
  expect(await savedState(page)).toEqual(saved);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toHaveText(lesson);
  expect(errors).toEqual([]);
});

test('narrow reduced-motion play keeps Pet Poke Toss and Call reachable by keyboard', async ({ page }, testInfo) => {
  const { errors, lesson, bounds, room, saved } = await begin(page, { width: 320, height: 568, reducedMotion: 'reduce' });
  const toyRect = { x: room.toy.x - 28, y: room.toy.y - 28, width: 56, height: 56 };
  const ball = await patch(page, bounds, toyRect);
  const poke = room.shortcut(1);
  await tap(page, poke.x, poke.y);
  await expect(page.locator('#game-status')).toHaveText(POKE);
  await screenshot(page, testInfo, 'pip-narrow-shortcuts');

  await page.keyboard.press('Shift+Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText(PET[0]);
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText(POKE);
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText(/^Pip (caught|fetched) the ball!/);
  await screenshot(page, testInfo, 'pip-narrow-keyboard-toss');
  const original = await patch(page, bounds, room.body);
  const arrival = { x: room.x + room.width - 98, y: room.y + room.height - 112, width: 60, height: 68 };
  const beforeArrival = await patch(page, bounds, arrival);
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText('Come here, Pip! Tap the floor to choose where Pip goes.');
  await visibleChange(page, bounds, room.body, original, testInfo, 'pip-reduced-motion-departs', 0.15);
  await visibleChange(page, bounds, arrival, beforeArrival, testInfo, 'pip-reduced-motion-arrives', 0.18);
  await visibleBall(page, bounds, { ...toyRect, x: room.x + 66 - 28 }, ball);
  await screenshot(page, testInfo, 'pip-narrow-keyboard-call');
  const settled = await patch(page, bounds, room);
  await page.waitForTimeout(350);
  expect((await patch(page, bounds, room)).equals(settled), 'Reduced motion leaves the completed room action still').toBe(true);
  expect(await savedState(page)).toEqual(saved);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toHaveText(lesson);
  expect(errors).toEqual([]);
});
