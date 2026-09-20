const { test, expect } = require('@playwright/test');
const { metrics, tap, rendered, openGame, openRewards, collectionBounds, roomControl, chooseRewardSection, visibleColorCount } = require('./game-ui.cjs');

const SAVES = ['wordBuddies.medalProgress', 'wordBuddies.playroom', 'wordBuddies.favoriteReward'];
const POKES = ['Boing! Pip jumps for you!', 'Aww! Pip feels shy!', 'Boop! Pip bounces right back!'];
const POKE_PATTERN = /^(Boing! Pip jumps for you!|Aww! Pip feels shy!|Boop! Pip bounces right back!)$/;
const PET = ['Pip leans into your hand. Lovely!', 'Soft strokes. Pip feels loved!'];

function playground(bounds) {
  // The room has no saved gift goal or displayed sticker in these fresh profiles.
  // Verified against the exported 390px room; all input uses its public canvas scale.
  const { x, top: y, width } = collectionBounds(bounds), height = 304;
  const foot = { x: x + 88, y: y + height - 32 };
  return {
    x, y, width, height, foot,
    pip: { x: foot.x, y: foot.y - 56 },
    body: { x: foot.x - 30, y: foot.y - 88, width: 60, height: 68 },
    toy: { x: x + width - 66, y: y + height - 74 },
    anchor: { x: x + 8, y: y + 4, width: width - 16, height: 32 }
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
  const roomOpenedAt = Date.now();
  const bounds = await openRoom(page);
  const saved = await savedState(page);
  return { errors, lesson, bounds, room: playground(bounds), saved, roomOpenedAt };
}

async function expectPoke(page, previous = '') {
  const status = page.locator('#game-status');
  await expect(status).toHaveText(POKE_PATTERN, { timeout: 800 });
  if (previous) await expect(status).not.toHaveText(previous, { timeout: 800 });
  return status.textContent();
}

async function savedState(page) {
  return page.evaluate(keys => ({
    selection: document.getElementById('selection-status').textContent,
    saves: keys.map(key => [key, localStorage.getItem(key)])
  }), SAVES);
}

async function openRoom(page) {
  const bounds = await metrics(page);
  await openRewards(page);
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

async function screenshot(page, testInfo, name) {
  await rendered(page);
  const full = await page.screenshot({ path: testInfo.outputPath(`${name}.png`), scale: 'css' });
  const canvas = await page.locator('#canvas').screenshot({ path: testInfo.outputPath(`${name}-canvas.png`), scale: 'css' });
  expect(await visibleColorCount(page, full), `${name}: page must show the game`).toBeGreaterThan(20);
  expect(await visibleColorCount(page, canvas), `${name}: raw canvas must show the game`).toBeGreaterThan(20);
}

async function reactionFrame(page, testInfo, caption, startedAt, suffix = 'midpoint') {
  await page.waitForTimeout(Math.max(0, 350 - (Date.now() - startedAt)));
  const key = caption.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/-$/, '');
  const name = `pip-home-${key}-${suffix}`;
  const full = await page.screenshot({ path: testInfo.outputPath(`${name}.png`), scale: 'css' });
  const completedAt = Date.now();
  await testInfo.attach(name, { body: full, contentType: 'image/png' });
  await testInfo.attach(`${name}-caption`, {
    body: JSON.stringify({ caption, screenshotCompletedAfterMs: completedAt - startedAt }), contentType: 'application/json'
  });
}

test('Home dances promptly and shuffled loading reactions replace each other without changing rewards', async ({ page }, testInfo) => {
  const { errors, bounds, room, saved, roomOpenedAt } = await begin(page, page.viewportSize());
  const status = page.locator('#game-status');
  const roomCaption = await status.textContent();
  const anchor = await patch(page, bounds, room.anchor);
  const motion = { x: room.foot.x - 56, y: room.foot.y - 116, width: 112, height: 120 };
  const resting = await patch(page, bounds, motion);
  await visibleChange(page, bounds, motion, resting, testInfo, 'pip-home-autodance-body', 0.035);
  expect(Date.now() - roomOpenedAt, 'Home dances before the former six-second idle delay.').toBeLessThan(5500);
  const danceFrames = [await patch(page, bounds, motion)];
  // Equal sampling intervals can land on matching points of the hip sway.
  // Observe several distinct poses over one complete routine instead.
  await expect.poll(async () => {
    const frame = await patch(page, bounds, motion);
    const differences = await Promise.all(danceFrames.map(previous => changedFraction(page, previous, frame)));
    if (differences.every(change => change > 0.01)) danceFrames.push(frame);
    return danceFrames.length;
  }, { timeout: 6000, intervals: [120, 230, 310],
    message: 'The automatic dance must keep moving through distinct poses.' }).toBeGreaterThanOrEqual(4);
  await expect(status).toHaveText(roomCaption);
  await screenshot(page, testInfo, 'pip-home-autodance');

  const captions = [];
  for (let index = 0; index < POKES.length; index++) {
    const startedAt = Date.now();
    await tap(page, room.pip.x, room.pip.y);
    const caption = await expectPoke(page, captions[captions.length - 1]);
    captions.push(caption);
    await reactionFrame(page, testInfo, caption, startedAt);
    // Capture each animated response independently for visual review.
    await page.waitForTimeout(Math.max(0, 1300 - (Date.now() - startedAt)));
  }
  expect([...captions].sort(), 'One shuffle bag contains each surprise exactly once.').toEqual([...POKES].sort());

  // Measure game feedback inside the page; screenshot encoding and transport
  // can take longer than the complete reaction on a desktop viewport.
  const timingProbe = await page.evaluateHandle(allowed => {
    const taps = [], changes = [], status = document.getElementById('game-status');
    const onTap = event => taps.push({ at: performance.now(), trusted: event.isTrusted });
    const observer = new MutationObserver(() => {
      const caption = status.textContent;
      if (allowed.includes(caption) && caption !== changes[changes.length - 1]?.caption) {
        changes.push({ at: performance.now(), caption });
      }
    });
    document.addEventListener('touchend', onTap, true);
    observer.observe(status, { childList: true, characterData: true, subtree: true });
    return { finish() {
      document.removeEventListener('touchend', onTap, true);
      observer.disconnect();
      return { taps, changes };
    } };
  }, POKES);
  let firstRapid, replacement, replacementAt, timing;
  try {
    await tap(page, room.pip.x, room.pip.y);
    firstRapid = await expectPoke(page, captions[captions.length - 1]);
    replacementAt = Date.now();
    await tap(page, room.pip.x, room.pip.y);
    replacement = await expectPoke(page, firstRapid);
  } finally {
    timing = await timingProbe.evaluate(probe => probe.finish());
    await timingProbe.dispose();
  }
  expect(timing.taps.map(tap => tap.trusted)).toEqual([true, true]);
  expect(timing.changes.map(change => change.caption)).toEqual([firstRapid, replacement]);
  for (let index = 0; index < 2; index++) {
    const latency = timing.changes[index].at - timing.taps[index].at;
    expect(latency, 'A trusted tap must promptly replace the game feedback.').toBeGreaterThanOrEqual(0);
    expect(latency, 'A trusted tap must promptly replace the game feedback.').toBeLessThan(250);
  }
  expect(timing.changes[1].at - timing.changes[0].at,
    'The second reaction starts before even the shortest first reaction could finish.').toBeLessThan(850);
  await reactionFrame(page, testInfo, replacement, replacementAt, 'rapid-replacement');
  await testInfo.attach('pip-home-trusted-tap-timing', {
    body: JSON.stringify(timing), contentType: 'application/json'
  });
  // Static accessible poses let us compare the actual rendered response without
  // screenshot latency sampling different moments in two short animations.
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await rendered(page);
  const references = new Map();
  for (let index = 0; index < 6 && references.size < POKES.length; index++) {
    await tap(page, room.pip.x, room.pip.y);
    replacement = await expectPoke(page, replacement);
    await rendered(page);
    references.set(replacement, await patch(page, bounds, motion));
  }
  expect(references.size).toBe(POKES.length);
  for (let index = 0; index < 2; index++) {
    await tap(page, room.pip.x, room.pip.y);
    replacement = await expectPoke(page, replacement);
  }
  await rendered(page);
  const replaced = await patch(page, bounds, motion);
  await testInfo.attach('pip-home-static-rapid-replacement', { body: replaced, contentType: 'image/png' });
  expect(await changedFraction(page, references.get(replacement), replaced),
    'The latest tap must immediately select its own visible pose.').toBeLessThan(0.005);
  for (const caption of POKES.filter(caption => caption !== replacement)) {
    expect(await changedFraction(page, references.get(caption), replaced),
      'The replacement must visibly differ from the other reactions.').toBeGreaterThan(0.02);
  }
  await page.waitForTimeout(1400);
  await expect(status).toHaveText(replacement);
  expect((await patch(page, bounds, room.anchor)).equals(anchor), 'Dancing and tapping cannot scroll the room').toBe(true);
  expect(await savedState(page)).toEqual(saved);
  expect(errors).toEqual([]);
});

test('Pip responds visibly to a poke and real strokes without scrolling the room', async ({ page, browserName }, testInfo) => {
  const { errors, bounds, room, saved } = await begin(page);
  const anchor = await patch(page, bounds, room.anchor);
  const before = await patch(page, bounds, room.body);
  await tap(page, room.pip.x, room.pip.y);
  let previousPoke = await expectPoke(page);
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
      previousPoke = await expectPoke(page, previousPoke);
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
  await expectPoke(page, previousPoke);
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

  // The bottom edge is below both the ball sprite and its clickable noun.
  const floorY = room.y + room.height - 4;
  const near = { x: room.foot.x + 68, y: floorY };
  const far = { x: room.x + room.width - 10, y: floorY };
  for (const [name, destination, message] of [
    ['walk', near, 'Pip walks over!'], ['run', far, 'Pip runs over!']
  ]) {
    // Pip's feet stop 52px from the sides and 12px above the bottom edge.
    const endpoint = { x: Math.min(destination.x, room.x + room.width - 52), y: room.y + room.height - 12 };
    const arrival = { x: endpoint.x - 24, y: endpoint.y - 76, width: 48, height: 58 };
    const empty = await patch(page, bounds, arrival);
    const leftToy = { ...toyRect, x: room.x + 66 - 28 };
    const emptyLeft = name === 'run' ? await patch(page, bounds, leftToy) : null;
    await tap(page, destination.x, destination.y);
    await expect(page.locator('#game-status')).toHaveText(message);
    await visibleChange(page, bounds, arrival, empty, testInfo, `pip-${name}-arrival`, 0.18);
    if (name === 'run') {
      // Arrival must finish and move the resting ball out from under Pip before capture.
      await visibleChange(page, bounds, leftToy, emptyLeft, testInfo, 'ball-moves-away-from-pip', 0.08);
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
  const firstPoke = await expectPoke(page);
  await screenshot(page, testInfo, 'pip-after-interrupted-stroke');

  await mouseDrag(page, bounds, [room.toy,
    { x: room.toy.x - 65, y: room.toy.y - 30 }, room.pip
  ]);
  await expect(page.locator('#game-status')).toHaveText('Here comes the ball, Pip!');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toHaveText(lesson);
  await page.waitForTimeout(250);
  await expect(page.locator('#game-status')).toHaveText(lesson);
  await openRoom(page);
  await tap(page, room.pip.x, room.pip.y);
  const secondPoke = await expectPoke(page, firstPoke);

  const list = { x: 24, y: bounds.height - 180, width: bounds.width - 48, height: 140 };
  const before = await patch(page, bounds, list);
  await mouseDrag(page, bounds, [
    { x: bounds.width * 0.75, y: bounds.height - 60 },
    { x: bounds.width * 0.75, y: bounds.height - 260 }
  ]);
  await visibleChange(page, bounds, list, before, testInfo, 'gift-list-scroll', 0.15);
  await screenshot(page, testInfo, 'gift-list-after-drag');
  await expect(page.locator('#game-status')).toHaveText(secondPoke);
  expect(await savedState(page)).toEqual(saved);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toHaveText(lesson);
  expect(errors).toEqual([]);
});

test('narrow reduced-motion play keeps Pip and toy actions reachable by keyboard', async ({ page }, testInfo) => {
  const { errors, lesson, bounds, room, saved } = await begin(page, { width: 320, height: 568, reducedMotion: 'reduce' });
  const toyRect = { x: room.toy.x - 28, y: room.toy.y - 28, width: 56, height: 56 };
  await roomControl(page, 'pip');
  await page.keyboard.press('Enter');
  await expectPoke(page);
  await screenshot(page, testInfo, 'pip-narrow-keyboard-pip');

  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText('1/3 · The ball rolls to Pip!');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText('2/3 · Pip rolls the ball back!');
  await page.keyboard.press('Space');
  await expect(page.locator('#game-status')).toHaveText('3/3 · Pip catches the ball. Hooray!');
  await screenshot(page, testInfo, 'pip-narrow-keyboard-toy-action');
  await page.keyboard.press('Enter');
  // Restore the room's top after keyboard focus has followed the moving toy.
  await chooseRewardSection(page, 'room');
  const original = await patch(page, bounds, room.body);
  const destination = { x: room.x + room.width - 10, y: room.y + room.height - 4 };
  const endpoint = { x: room.x + room.width - 52, y: room.y + room.height - 12 };
  const arrival = { x: endpoint.x - 30, y: endpoint.y - 88, width: 60, height: 68 };
  const beforeArrival = await patch(page, bounds, arrival);
  const leftToy = { ...toyRect, x: room.x + 66 - 28 };
  const emptyLeft = await patch(page, bounds, leftToy);
  await tap(page, destination.x, destination.y);
  await expect(page.locator('#game-status')).toHaveText('Pip walks over!');
  await visibleChange(page, bounds, room.body, original, testInfo, 'pip-reduced-motion-departs', 0.15);
  await visibleChange(page, bounds, arrival, beforeArrival, testInfo, 'pip-reduced-motion-arrives', 0.18);
  await visibleChange(page, bounds, leftToy, emptyLeft, testInfo, 'ball-moves-away-from-pip-reduced', 0.08);
  await screenshot(page, testInfo, 'pip-narrow-floor-tap');
  const settled = await patch(page, bounds, room);
  await page.waitForTimeout(350);
  expect((await patch(page, bounds, room)).equals(settled), 'Reduced motion leaves the completed room action still').toBe(true);
  expect(await savedState(page)).toEqual(saved);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toHaveText(lesson);
  expect(errors).toEqual([]);
});
