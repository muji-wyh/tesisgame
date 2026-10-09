const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, metrics, tap, rendered, celebrationState, visibleColorCount } = require('./game-ui.cjs');

const JELLY_REWARDS = 'growWithPip.jellyRewards.v1';
const POP_REWARDS = 'wordBuddies.popRewards';
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const growth = page => page.locator('#growth-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const treasure = page => page.locator('#jelly-reward-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));

async function pressRect(page, rect) {
  expect(rect).toHaveLength(4);
  const [x, y, width, height] = rect;
  expect(width).toBeGreaterThan(0);
  expect(height).toBeGreaterThan(0);
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function pressControl(page, control) {
  expect(control?.visible, 'The requested control is visible').toBe(true);
  expect(control.disabled, 'The requested control accepts input').toBe(false);
  await pressRect(page, control.rect);
}

async function libraryControl(page, name) {
  const control = (await metrics(page)).library.controls.find(item => item.name === name);
  expect(control, `${name} exists in the visible game library`).toBeTruthy();
  expect(control.disabled).toBe(false);
  await pressRect(page, control.rect);
}

async function startJelly(page, options = {}) {
  const errors = await openGame(page, options);
  await openModeMenu(page);
  await libraryControl(page, 'Mode_jelly');
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && state.tiles?.length >= 10 &&
      state.tiles.every(tile => tile.settled);
  }, { timeout: 20000, message: 'The real Jelly board starts with settled word and picture tiles' }).toBe(true);
  return errors;
}

function pair(state, { chest = null } = {}) {
  for (const first of state.tiles || []) {
    if (!first.visible || !first.settled) continue;
    const second = state.tiles.find(tile => tile.id !== first.id && tile.visible && tile.settled &&
      tile.word.id === first.word.id && tile.kind !== first.kind);
    if (!second) continue;
    if (chest !== null && Boolean(first.chest || second.chest) !== chest) continue;
    return [first, second];
  }
  return null;
}

async function availablePair(page, options = {}) {
  let found;
  await expect.poll(async () => {
    found = pair(await jelly(page), options);
    return Boolean(found);
  }, { timeout: 30000, message: 'Batched supply provides a settled, visible word and its matching picture' }).toBe(true);
  return found;
}

function center(rect, bounds) {
  return { x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale };
}

async function dragPair(page, tiles) {
  const bounds = await metrics(page), from = center(tiles[0].rect, bounds), to = center(tiles[1].rect, bounds);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(tiles[0].id);
    await page.mouse.move(to.x, to.y, { steps: 10 });
    await expect.poll(async () => {
      const state = await jelly(page);
      return { active: state.drag.active, target: state.drag.target };
    }).toEqual({ active: true, target: tiles[1].id });
    expect((await jelly(page)).contact).toMatchObject({ kind: 'match', source: tiles[0].id, target: tiles[1].id });
  } finally {
    await page.mouse.up();
  }
}

async function tapPair(page, tiles) {
  await pressRect(page, tiles[0].rect);
  await expect.poll(async () => (await jelly(page)).drag.selected).toBe(tiles[0].id);
  // Read the second tile again in case a responsive layout settled after the tap.
  const target = (await jelly(page)).tiles.find(tile => tile.id === tiles[1].id);
  await pressRect(page, target.rect);
}

async function touchDragPair(page, tiles) {
  const bounds = await metrics(page), from = center(tiles[0].rect, bounds), to = center(tiles[1].rect, bounds);
  const session = await page.context().newCDPSession(page);
  const point = (x, y) => [{ x, y, id: 0, radiusX: 6, radiusY: 6, force: 1 }];
  try {
    await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: point(from.x, from.y) });
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(tiles[0].id);
    for (let step = 1; step <= 10; step++) {
      const t = step / 10;
      await session.send('Input.dispatchTouchEvent', { type: 'touchMove',
        touchPoints: point(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t) });
      await page.waitForTimeout(25);
    }
    await expect.poll(async () => (await jelly(page)).drag.target).toBe(tiles[1].id);
    await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } finally {
    await session.detach();
  }
}

async function expectClear(page, count, tiles) {
  await expect.poll(async () => (await jelly(page)).cleared_pairs,
    { message: 'The real fusion completes before the pair receives credit' }).toBe(count);
  const state = await jelly(page);
  expect(state.fusion).toEqual({});
  for (const tile of tiles) expect(state.tiles.some(item => item.id === tile.id)).toBe(false);
  return state;
}

async function observeTimeline(page) {
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.jellyObservedTimeline = [];
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      window.jellyObservedTimeline.push({ at: performance.now(), phase: state.phase,
        cleared: state.cleared_pairs, chests: state.chest_count,
        generated: state.generated_tiles, spawnInterval: state.spawn_interval,
        fusion: Boolean(state.fusion && Object.keys(state.fusion).length),
        effect: state.fusion_effect,
        fullElapsed: state.full_elapsed, resultVisible: state.result?.visible });
    };
    const observer = new MutationObserver(record);
    observer.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  });
}

function expectInCanvas(rect, bounds, description) {
  expect(rect, description).toHaveLength(4);
  expect(rect.every(Number.isFinite), description).toBe(true);
  expect(rect[2], description).toBeGreaterThan(0);
  expect(rect[3], description).toBeGreaterThan(0);
  expect(rect[0], description).toBeGreaterThanOrEqual(-1);
  expect(rect[1], description).toBeGreaterThanOrEqual(-1);
  expect(rect[0] + rect[2], description).toBeLessThanOrEqual(bounds.width + 1);
  expect(rect[1] + rect[3], description).toBeLessThanOrEqual(bounds.height + 1);
}

function separate(a, b) {
  return a[0] + a[2] <= b[0] + 0.5 || b[0] + b[2] <= a[0] + 0.5 ||
    a[1] + a[3] <= b[1] + 0.5 || b[1] + b[3] <= a[1] + 0.5;
}

function expectPreviewLayout(state, bounds) {
  expect(state.preview.visible, 'The upcoming four tiles are visible outside the well').toBe(true);
  expect(state.upcoming).toHaveLength(4);
  expect(state.preview.slots).toHaveLength(4);
  expectInCanvas(state.preview.rect, bounds, 'The complete four-tile preview fits the screen');
  expect(separate(state.preview.rect, state.board_rect), 'The preview never occupies a playable board cell').toBe(true);
  expect(separate(state.preview.rect, state.finish.rect), 'The preview does not overlap Finish').toBe(true);
  for (let index = 0; index < state.preview.slots.length; index++) {
    const slot = state.preview.slots[index], queued = state.upcoming[index];
    expect(slot.visible).toBe(true);
    expect(slot.id, 'Preview order comes from the real dispatch queue').toBe(queued.id);
    expectInCanvas(slot.rect, bounds, `Preview tile ${index + 1} fits the screen`);
    expect(separate(slot.rect, state.board_rect)).toBe(true);
    expect(queued.word.id).toBeTruthy();
    if (queued.kind === 'picture') expect(queued.word.image).toBeTruthy();
    for (const other of state.preview.slots.slice(index + 1)) {
      expect(separate(slot.rect, other.rect), 'Upcoming tiles have separate readable slots').toBe(true);
    }
  }
}

async function captureResponsive(page, info, name) {
  await rendered(page);
  const png = await page.screenshot({ path: info.outputPath(`${name}.png`), scale: 'css' });
  const raw = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
  const canvasPng = Buffer.from(raw, 'base64');
  fs.writeFileSync(info.outputPath(`${name}-canvas.png`), canvasPng);
  const pageColors = await visibleColorCount(page, png), canvasColors = await visibleColorCount(page, canvasPng);
  await info.attach(`${name}-rendering`, { body: JSON.stringify({ pageColors, canvasColors }), contentType: 'application/json' });
  expect(canvasColors, `${name}: the game must render its resized canvas`).toBeGreaterThan(20);
  if (pageColors === 1 && process.platform === 'win32' && info.project.use.browserName === 'webkit') {
    info.annotations.push({ type: 'rendering-limitation',
      description: `${name}: existing Windows WebKit presentation/capture limitation after live resize; the page PNG is blank while the raw canvas renders. Both retained.` });
  } else {
    expect(pageColors, `${name}: the composed page must show the game`).toBeGreaterThan(20);
  }
}

async function observeSupply(page) {
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.jellySupplyTimeline = [];
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      if (!state.visible || state.phase !== 'playing' || !state.tiles?.length) return;
      const tile = item => ({ id: item.id, word: item.word.id, kind: item.kind, chest: item.chest,
        rect: item.rect, visible: item.visible, settled: item.settled,
        age: item.age, fallingRows: item.falling_rows });
      window.jellySupplyTimeline.push({ at: performance.now(), generated: state.generated_tiles,
        spawnElapsed: state.spawn_elapsed, spawnInterval: state.spawn_interval, paused: state.paused,
        fusion: Boolean(state.fusion && Object.keys(state.fusion).length),
        preview: state.preview?.slots.map(slot => ({ id: slot.id, rect: slot.rect, motion: slot.motion })),
        tiles: state.tiles.map(tile), upcoming: (state.upcoming || []).map(tile),
        ghosts: state.landing_ghosts, board: state.board_rect });
    };
    new MutationObserver(record).observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  });
}

async function focusTile(page, tileId) {
  for (let index = 0; index < 48; index++) {
    if ((await jelly(page)).tiles.some(tile => tile.id === tileId && tile.focused)) return;
    await page.keyboard.press('Tab');
    // Focus is published on the ordinary 100 ms presentation cadence.
    await page.waitForTimeout(120);
  }
  throw new Error(`Keyboard navigation could not focus Jelly tile ${tileId}.`);
}

test('four previews predict simultaneous batches and the final partial batch with stable landing ghosts', async ({ page }, info) => {
  test.setTimeout(90000);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await openModeMenu(page);
  await observeSupply(page);
  await libraryControl(page, 'Mode_jelly');
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.preview?.visible && state.upcoming?.length === 4 &&
      state.landing_ghosts?.some(ghost => ghost.visible);
  }, { timeout: 12000, intervals: [50], message: 'An ordinary batch visibly announces its landing destinations' }).toBe(true);
  const starting = await jelly(page);
  expectPreviewLayout(starting, await metrics(page));
  await page.screenshot({ path: info.outputPath('jelly-four-previews-and-falling-batch.png'), scale: 'css' });

  // These are real pointer gestures on the display-only queue. Its contents
  // may naturally advance, but they cannot become a selected gameplay tile.
  for (const slot of (await jelly(page)).preview.slots) {
    await pressRect(page, slot.rect);
    const state = await jelly(page);
    expect(state.drag.source).toBe(-1);
    expect(state.drag.selected).toBe(-1);
    expect(state.cleared_pairs).toBe(0);
  }
  const slot = (await jelly(page)).preview.slots[0];
  const point = center(slot.rect, await metrics(page));
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  try {
    await page.mouse.move(point.x + 20, point.y + 12, { steps: 4 });
    expect((await jelly(page)).drag.active, 'The upcoming preview cannot be dragged into the game').toBe(false);
    expect((await jelly(page)).drag.source).toBe(-1);
  } finally {
    await page.mouse.up();
  }

  await expect.poll(async () => {
    const state = await jelly(page);
    return state.generated_tiles === 24 && state.tiles.every(tile => tile.settled);
  }, { timeout: 40000, intervals: [100], message: 'Real four-tile dispatches fill the last two spaces with a partial batch' }).toBe(true);
  const timeline = await page.evaluate(() => window.jellySupplyTimeline);
  await info.attach('jelly-batch-supply.json', { body: Buffer.from(JSON.stringify(timeline, null, 2)), contentType: 'application/json' });
  const records = timeline.filter(entry => entry.upcoming.length === 4);
  const arrivals = [];
  const identity = tile => ({ id: tile.id, word: tile.word, kind: tile.kind, chest: tile.chest });
  for (let index = 1; index < records.length; index++) {
    const previous = records[index - 1], current = records[index];
    expect(current.tiles.filter(tile => !tile.settled).length,
      'No more than the four incoming tiles are airborne or settling').toBeLessThanOrEqual(4);
    expect(current.ghosts.filter(ghost => ghost.visible).length).toBeLessThanOrEqual(4);
    const added = current.tiles.filter(tile => !previous.tiles.some(older => older.id === tile.id));
    if (!added.length) continue;
    const count = Math.min(4, 24 - previous.tiles.length);
    expect(added, 'A single dispatch inserts its entire available batch together').toHaveLength(count);
    expect(current.generated - previous.generated).toBe(count);
    expect(added.map(identity), 'Every arriving tile matches the preview in the same order')
      .toEqual(previous.upcoming.slice(0, count).map(identity));
    expect(current.upcoming.slice(0, 4 - count).map(identity), 'Undispatched previews stay at the front after a partial batch')
      .toEqual(previous.upcoming.slice(count).map(identity));
    arrivals.push({ ids: added.map(tile => tile.id), at: current.at });
  }
  expect(arrivals.length).toBeGreaterThanOrEqual(3);
  expect(arrivals.at(-1).ids, 'The board has room for exactly two tiles in its final batch').toHaveLength(2);
  for (const batch of arrivals.slice(0, 2)) for (const id of batch.ids) {
    const flight = records.filter(entry => entry.at >= batch.at && entry.ghosts.some(ghost => ghost.visible && ghost.id === id));
    const visibleFlight = flight.filter(entry => {
      const tile = entry.tiles.find(item => item.id === id);
      const visibleHeight = Math.min(tile.rect[1] + tile.rect[3], entry.board[1] + entry.board[3]) -
        Math.max(tile.rect[1], entry.board[1]);
      return tile.visible && visibleHeight >= tile.rect[3] * 0.35;
    });
    // Status publication is nominally 100 ms, but WebKit can coalesce it to
    // roughly 180 ms. A 330 ms visible fall may therefore publish only twice.
    // Inspect its full airborne history as well, including entry into the well.
    const airborneTiles = flight.map(frame => frame.tiles.find(tile => tile.id === id));
    expect(airborneTiles.length, 'The descent has several published airborne poses').toBeGreaterThanOrEqual(3);
    expect(new Set(airborneTiles.map(tile => Math.round(tile.rect[1] * 2))).size,
      'The full airborne history contains distinct moving positions').toBeGreaterThanOrEqual(3);
    expect(flight.at(-1).at - flight[0].at,
      'The full airborne history spans at least two normal publication intervals').toBeGreaterThanOrEqual(180);
    expect(airborneTiles.at(-1).age - airborneTiles[0].age,
      'Published motion covers a meaningful part of the actual fall clock').toBeGreaterThanOrEqual(0.18);
    expect(airborneTiles[0].rect[1], 'The incoming tile enters from above the clipped well').toBeLessThan(flight[0].board[1]);
    expect(visibleFlight.length, 'The clipped well shows more than one position before landing').toBeGreaterThanOrEqual(2);
    const positions = visibleFlight.map(frame => frame.tiles.find(tile => tile.id === id).rect[1]);
    expect(new Set(positions.map(y => Math.round(y * 2))).size,
      'Separate visible frames show actual motion, not repeated stationary poses').toBeGreaterThanOrEqual(2);
    for (let index = 1; index < positions.length; index++) {
      expect(positions[index] - positions[index - 1], 'The incoming tile continues downward before contact').toBeGreaterThanOrEqual(-0.5);
    }
    const first = visibleFlight[0], last = visibleFlight.at(-1);
    expect(last.at - first.at, 'The visible poses span at least one normal publication interval').toBeGreaterThanOrEqual(80);
    const firstTile = first.tiles.find(tile => tile.id === id), lastTile = last.tiles.find(tile => tile.id === id);
    expect(lastTile.age - firstTile.age, 'The visible poses also advance the actual fall clock').toBeGreaterThanOrEqual(0.08);
    const destination = first.ghosts.find(ghost => ghost.id === id).rect;
    expect(lastTile.rect[1] - firstTile.rect[1], 'The tile visibly travels down toward the ghost').toBeGreaterThan(firstTile.rect[3] / 2);
    for (const frame of flight) {
      expect(frame.ghosts.find(ghost => ghost.id === id).rect.every((value, index) => Math.abs(value - destination[index]) < 0.5),
        'The landing destination stays stable throughout this descent').toBe(true);
    }
    const landed = records.find(entry => entry.at > last.at && entry.tiles.some(tile => tile.id === id && tile.settled));
    expect(landed, 'The falling tile reaches its advertised cell').toBeTruthy();
    const tile = landed.tiles.find(item => item.id === id);
    expect(tile.rect.every((value, index) => Math.abs(value - destination[index]) < 1),
      'The ghost marks the actual resting rectangle').toBe(true);
    expect(landed.ghosts.some(ghost => ghost.visible && ghost.id === id), 'This ghost disappears after contact').toBe(false);
  }
  expectPreviewLayout(await jelly(page), await metrics(page));
  await page.screenshot({ path: info.outputPath('jelly-four-previews-final-partial-batch.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('preview wobble builds with the dispatch clock and freezes during menus and fusion', async ({ page }, info) => {
  test.setTimeout(90000);
  const errors = await startJelly(page, { reducedMotion: 'no-preference' });
  const poses = state => state.preview.slots.map(slot => ({ id: slot.id, rect: slot.rect, motion: slot.motion }));
  await expect.poll(async () => {
    const state = await jelly(page), progress = state.spawn_elapsed / state.spawn_interval;
    return progress >= 0.12 && progress <= 0.4;
  }, { timeout: 10000, intervals: [50], message: 'Observe the early part of a real dispatch cycle' }).toBe(true);
  const early = await jelly(page);
  expectPreviewLayout(early, await metrics(page));
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.upcoming[0].id === early.upcoming[0].id && state.spawn_elapsed / state.spawn_interval >= 0.7;
  }, { timeout: 7000, intervals: [50], message: 'The same upcoming batch approaches its actual dispatch time' }).toBe(true);
  const late = await jelly(page);
  expectPreviewLayout(late, await metrics(page));
  for (let index = 0; index < 4; index++) {
    const before = early.preview.slots[index].motion, after = late.preview.slots[index].motion;
    expect(after.intensity, 'Every preview becomes more animated as dispatch approaches').toBeGreaterThan(before.intensity);
    expect({ offset: after.offset, stretch: after.stretch, bend: after.bend }, 'The visible gel pose actually changes')
      .not.toEqual({ offset: before.offset, stretch: before.stretch, bend: before.bend });
  }

  await openModeMenu(page);
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const paused = await jelly(page);
  await page.waitForTimeout(450);
  const stillPaused = await jelly(page);
  expect(stillPaused.spawn_elapsed, 'The menu freezes the actual supply clock').toBe(paused.spawn_elapsed);
  expect(poses(stillPaused), 'Preview jellies retain their exact pose while paused').toEqual(poses(paused));
  await libraryControl(page, 'LibraryClose');
  await expect.poll(async () => (await jelly(page)).spawn_elapsed,
    { timeout: 3000, intervals: [50], message: 'Closing the menu resumes the interrupted dispatch clock' }).toBeGreaterThan(paused.spawn_elapsed);
  const resumed = await jelly(page);
  expect(poses(resumed), 'Preview motion resumes with the dispatch clock').not.toEqual(poses(paused));

  await observeSupply(page);
  const tiles = await availablePair(page, { chest: false }), before = (await jelly(page)).cleared_pairs;
  await dragPair(page, tiles);
  await expectClear(page, before + 1, tiles);
  const fusion = (await page.evaluate(() => window.jellySupplyTimeline)).filter(frame => frame.fusion);
  expect(fusion.length, 'Observe several ordinary frames of the committed fusion').toBeGreaterThanOrEqual(3);
  for (const frame of fusion) {
    expect(frame.spawnElapsed, 'A committed fusion freezes the dispatch clock').toBe(fusion[0].spawnElapsed);
    expect(frame.preview, 'Preview poses stay still throughout the matching animation').toEqual(fusion[0].preview);
  }
  await info.attach('jelly-preview-motion.json', { body: Buffer.from(JSON.stringify({
    early: { elapsed: early.spawn_elapsed, slots: poses(early) },
    late: { elapsed: late.spawn_elapsed, slots: poses(late) },
    paused: { elapsed: paused.spawn_elapsed, slots: poses(paused) }, fusion
  }, null, 2)), contentType: 'application/json' });
  await page.screenshot({ path: info.outputPath('jelly-preview-after-fusion.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('real drag and touch pairs earn learning once, then reveal and open their exact treasure', async ({ page }, info) => {
  test.setTimeout(150000);
  const errors = await startJelly(page, { reducedMotion: 'no-preference' });
  const oldPopSave = await page.evaluate(key => localStorage.getItem(key), POP_REWARDS);
  await observeTimeline(page);
  const first = await availablePair(page, { chest: false });
  const firstBefore = (await growth(page)).streaks[first[0].word.id] || 0;
  await dragPair(page, first);
  await expectClear(page, 1, first);
  await expect.poll(async () => (await growth(page)).streaks[first[0].word.id]).toBe(firstBefore + 1);
  const timeline = await page.evaluate(() => window.jellyObservedTimeline);
  expect(timeline.some(state => state.fusion && state.cleared === 0), 'Fusion visibly precedes success credit').toBe(true);
  expect(timeline.some(state => state.effect?.visible && ['hold', 'compress'].includes(state.effect.stage)),
    'The browser renders the continuous union with its readable combined face').toBe(true);
  expect(timeline.some(state => state.effect?.visible && state.effect.stage === 'release'),
    'Elastic release remains visible before the pair receives credit').toBe(true);

  const marked = await availablePair(page, { chest: true });
  const markedBefore = (await growth(page)).streaks[marked[0].word.id] || 0;
  await tapPair(page, marked);
  const completed = await expectClear(page, 2, marked);
  expect(completed.chest_count).toBe(1);
  expect(completed.loot.count).toBe(1);
  await expect.poll(async () => (await growth(page)).streaks[marked[0].word.id]).toBe(markedBefore + 1);
  await page.screenshot({ path: info.outputPath('jelly-earned-chest.png'), scale: 'css' });

  await pressControl(page, (await jelly(page)).finish);
  await expect.poll(async () => (await celebrationState(page)).active,
    { message: 'Earned loot receives the shared Pip celebration' }).toBe(true);
  const summary = await celebrationState(page);
  expect(summary.title).toBe('Round results');
  expect(summary.score).toBe(2);
  expect(summary.caption).toBe('Score: 2 · Chests: 1');
  expect((await jelly(page)).result.visible, 'Results cannot be used during the celebration').toBe(false);
  await expect.poll(async () => (await jelly(page)).result.visible,
    { timeout: 15000, message: 'The performance naturally reveals the Jelly result' }).toBe(true);
  const result = await jelly(page);
  expect(result.phase).toBe('finished');
  expect(result.score).toBe(2);
  expect(result.result.title).toBe('Round results');
  expect(result.result.caption).toBe('Score: 2 · Chests: 1');
  expect(result.chest_count).toBe(1);
  expect(result.result.open.text).toBe('Open chest');
  expectInCanvas(result.result.open.rect, await metrics(page), 'The earned-chest action fits the screen');
  expectInCanvas(result.result.replay.rect, await metrics(page), 'The replay action fits the screen');
  const saved = await page.evaluate(key => localStorage.getItem(key), JELLY_REWARDS);
  expect(saved, 'The earned batch is saved before opening the reward room').toContain(result.round_id);
  await page.screenshot({ path: info.outputPath('jelly-results.png'), scale: 'css' });

  await pressControl(page, result.result.open);
  await expect.poll(async () => {
    const room = await treasure(page);
    return { visible: room.visible, chests: room.chest_count, opened: room.opened_count, failed: room.save_failed };
  }, { timeout: 45000 }).toEqual({ visible: true, chests: 1, opened: 0, failed: false });
  const room = await treasure(page), chest = room.chests[0].rect, viewport = room.scroll_rect;
  const left = Math.max(chest.x, viewport.x), right = Math.min(chest.x + chest.width, viewport.x + viewport.width);
  const top = Math.max(chest.y, viewport.y), bottom = Math.min(chest.y + chest.height, viewport.y + viewport.height);
  expect(right - left).toBeGreaterThan(20);
  expect(bottom - top).toBeGreaterThan(20);
  const position = center([left, top, right - left, bottom - top], await metrics(page));
  await page.mouse.move(position.x, position.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await treasure(page)).opened_count,
      { timeout: 15000, message: 'A real hold reaches the chest release and saves it' }).toBe(1);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => {
    const current = await treasure(page);
    return { active: current.active, opening: current.opening, pending: current.pending };
  }, { timeout: 12000 }).toEqual({ active: -1, opening: false, pending: false });
  const afterOpen = await page.evaluate(key => localStorage.getItem(key), JELLY_REWARDS);
  expect(afterOpen).not.toBe(saved);
  expect(afterOpen).toContain(result.round_id);
  await page.mouse.click(position.x, position.y);
  await rendered(page);
  expect(await page.evaluate(key => localStorage.getItem(key), JELLY_REWARDS), 'An opened chest cannot write a second receipt').toBe(afterOpen);
  expect(await page.evaluate(key => localStorage.getItem(key), POP_REWARDS), 'Jelly rewards never overwrite Pop treasure').toBe(oldPopSave);
  expect((await growth(page)).streaks[first[0].word.id]).toBe(firstBefore + 1);
  expect((await growth(page)).streaks[marked[0].word.id]).toBe(markedBefore + 1);
  await page.screenshot({ path: info.outputPath('jelly-opened-treasure.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('a naturally full board pauses, can be rescued, and eventually ends without inventing loot', async ({ page }, info) => {
  test.setTimeout(150000);
  test.skip(info.project.name !== 'desktop-chromium', 'Natural supply and the eight-second countdown run once on desktop.');
  const errors = await startJelly(page, { reducedMotion: 'no-preference' });
  expect((await jelly(page)).spawn_interval, 'The round starts with seven seconds between four-tile batches').toBe(7);
  await observeTimeline(page);
  let full;
  await expect.poll(async () => {
    full = await jelly(page);
    return full.cells.length === 24 && full.tiles.every(tile => tile.settled);
  }, { timeout: 50000, intervals: [100], message: 'Unmodified batch supply naturally fills all 24 cells' }).toBe(true);
  // Freeze the real countdown before inspecting cadence or preparing the rescue.
  await openModeMenu(page);
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const paused = await jelly(page);
  expect(full.notice).toContain('Board full');
  expect(paused.phase).toBe('playing');
  expect(paused.danger).toEqual({ active: false, strength: 0 });
  const arrivals = await page.evaluate(() => window.jellyObservedTimeline.filter((entry, index, entries) =>
    index > 0 && entry.generated > entries[index - 1].generated));
  const intervals = arrivals.slice(1).map((entry, index) => (entry.at - arrivals[index].at) / 1000);
  const rescue = pair(paused, { chest: false });
  expect(rescue, 'The full paused board contains an unmarked rescue pair').toBeTruthy();
  const streak = (await growth(page)).streaks[rescue[0].word.id] || 0;
  const bounds = await metrics(page), close = bounds.library.controls.find(item => item.name === 'LibraryClose');
  expect(close?.disabled).toBe(false);
  const from = center(rescue[0].rect, bounds), to = center(rescue[1].rect, bounds);
  await page.waitForTimeout(1200);
  const stillPaused = await jelly(page);
  expect(stillPaused.full_elapsed, 'The menu freezes the real danger clock').toBe(paused.full_elapsed);
  expect(stillPaused.generated_tiles).toBe(paused.generated_tiles);
  await tap(page, close.rect[0] + close.rect[2] / 2, close.rect[1] + close.rect[3] / 2, bounds);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && !state.paused;
  }, { intervals: [25] }).toBe(true);
  // The normal drag test already observes intermediate poses. Here, commit the
  // prepared real gesture promptly instead of holding it through assertion polls.
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await page.mouse.move(to.x, to.y, { steps: 2 });
  } finally {
    await page.mouse.up();
  }
  const rescued = await expectClear(page, 1, rescue);
  expect(rescued.cells).toHaveLength(22);
  expect(rescued.full_elapsed, 'A completed rescue cancels the entire previous countdown').toBe(-1);
  expect(rescued.danger).toEqual({ active: false, strength: 0 });
  expect(rescued.chest_count).toBe(0);
  await expect.poll(async () => (await growth(page)).streaks[rescue[0].word.id]).toBe(streak + 1);
  await page.screenshot({ path: info.outputPath('jelly-full-board-rescue.png'), scale: 'css' });
  await expect.poll(async () => (await jelly(page)).cells.length,
    { timeout: 12000, message: 'A partial batch fills the two newly opened spaces' }).toBe(24);
  expect((await jelly(page)).phase).toBe('playing');
  // Capture feedback during the final countdown so screenshots cannot consume rescue time.
  await expect.poll(async () => (await jelly(page)).danger.strength,
    { intervals: [50], message: 'The full-board frame visibly flashes on each countdown beat' }).toBeGreaterThan(0.9);
  await page.screenshot({ path: info.outputPath('jelly-danger-bright.png'), scale: 'css' });
  await expect.poll(async () => (await jelly(page)).danger.strength,
    { intervals: [50], message: 'The warning returns to the quiet board frame between beats' }).toBe(0);
  await page.screenshot({ path: info.outputPath('jelly-danger-dim.png'), scale: 'css' });
  await expect.poll(async () => (await jelly(page)).result.visible,
    { timeout: 18000, intervals: [100, 250, 500], message: 'The fresh full-board countdown expires through ordinary gameplay time' }).toBe(true);
  const ended = await jelly(page);
  expect(ended.phase).toBe('finished');
  expect(ended.danger).toEqual({ active: false, strength: 0 });
  expect(ended.cleared_pairs).toBe(1);
  expect(ended.score).toBe(1);
  expect(ended.result.title).toBe('Round results');
  expect(ended.result.caption).toBe('Score: 1 · Chests: 0');
  expect(ended.chest_count).toBe(0);
  expect(ended.result.open.visible).toBe(false);
  expect(ended.result.replay.visible).toBe(true);
  expect((await treasure(page)).pending).not.toBe(true);
  await page.waitForTimeout(400);
  expect((await jelly(page)).round_id).toBe(ended.round_id);
  expect((await growth(page)).streaks[rescue[0].word.id]).toBe(streak + 1);
  await info.attach('jelly-spawn-cadence', { body: JSON.stringify({ arrivals, intervals }, null, 2), contentType: 'application/json' });
  expect(arrivals.length, 'Natural batch arrivals establish the real seven-second cadence').toBeGreaterThanOrEqual(3);
  for (let index = 1; index < arrivals.length; index++) {
    expect(arrivals[index].generated - arrivals[index - 1].generated,
      'Dispatches add four tiles until only two board cells remain').toBe(index === arrivals.length - 1 ? 2 : 4);
  }
  for (const interval of intervals) expect(interval, 'Idle batch arrivals leave reading and matching time').toBeGreaterThanOrEqual(6.5);
  expect(errors).toEqual([]);
});

test('portrait and short landscape preserve touch targets and keyboard matching', async ({ page }, info) => {
  test.setTimeout(150000);
  const errors = await startJelly(page);
  let clears = 0;
  for (const dimensions of [{ width: 390, height: 844 }, { width: 844, height: 390 }]) {
    await page.setViewportSize(dimensions);
    await rendered(page);
    await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    const state = await jelly(page), bounds = await metrics(page);
    expectInCanvas(state.board_rect, bounds, 'The complete four-by-six well fits the current screen');
    expect(state.board_rect[2] / state.board_rect[3]).toBeCloseTo(2 / 3, 3);
    expectInCanvas(state.finish.rect, bounds, 'Finish remains visible outside the well');
    expectPreviewLayout(state, bounds);
    for (const tile of state.tiles) {
      expectInCanvas(tile.rect, bounds, `The ${tile.kind} tile for ${tile.word.id} stays on screen`);
      expect(tile.rect[2] * bounds.scale, 'Small-screen jellies retain a usable target width').toBeGreaterThanOrEqual(30);
      if (tile.kind === 'picture') expect(tile.word.image).toBeTruthy();
    }
    for (let first = 0; first < state.tiles.length; first++) for (let second = first + 1; second < state.tiles.length; second++) {
      const a = state.tiles[first].rect, b = state.tiles[second].rect;
      expect(a[0] + a[2] <= b[0] + 0.5 || b[0] + b[2] <= a[0] + 0.5 ||
        a[1] + a[3] <= b[1] + 0.5 || b[1] + b[3] <= a[1] + 0.5,
      'Settled Jelly targets occupy separate board cells').toBe(true);
    }
    const touchPair = await availablePair(page);
    if (info.project.use.browserName === 'chromium') await touchDragPair(page, touchPair);
    else await tapPair(page, touchPair);
    await expectClear(page, ++clears, touchPair);
    await captureResponsive(page, info, `jelly-${dimensions.width}x${dimensions.height}`);
  }

  const keyboardPair = await availablePair(page);
  const previousStreak = (await growth(page)).streaks[keyboardPair[0].word.id] || 0;
  await focusTile(page, keyboardPair[0].id);
  await page.keyboard.press('Enter');
  await expect.poll(async () => (await jelly(page)).drag.selected).toBe(keyboardPair[0].id);
  await focusTile(page, keyboardPair[1].id);
  await page.keyboard.press('Enter');
  await expectClear(page, ++clears, keyboardPair);
  await expect.poll(async () => (await growth(page)).streaks[keyboardPair[0].word.id]).toBe(previousStreak + 1);
  expect(errors).toEqual([]);
});
