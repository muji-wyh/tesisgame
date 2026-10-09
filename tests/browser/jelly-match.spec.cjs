const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, metrics, tap, rendered, celebrationState } = require('./game-ui.cjs');

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
    return state.visible && state.phase === 'playing' && state.tiles?.length >= 8 &&
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
  }, { message: 'A settled, visible word and its matching picture are available' }).toBe(true);
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
        fusion: Boolean(state.fusion && Object.keys(state.fusion).length),
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

async function focusTile(page, tileId) {
  for (let index = 0; index < 48; index++) {
    if ((await jelly(page)).tiles.some(tile => tile.id === tileId && tile.focused)) return;
    await page.keyboard.press('Tab');
    // Focus is published on the ordinary 100 ms presentation cadence.
    await page.waitForTimeout(120);
  }
  throw new Error(`Keyboard navigation could not focus Jelly tile ${tileId}.`);
}

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
  test.skip(info.project.name !== 'desktop-chromium', 'The real 28-second supply and eight-second countdown run once on desktop.');
  const errors = await startJelly(page, { reducedMotion: 'no-preference' });
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.cells.length === 24 && state.tiles.every(tile => tile.settled);
  }, { timeout: 50000, intervals: [100, 250, 500], message: 'Unmodified paired supply naturally fills all 24 cells' }).toBe(true);
  expect((await jelly(page)).notice).toContain('Board full');
  await openModeMenu(page);
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const paused = await jelly(page);
  expect(paused.danger).toEqual({ active: false, strength: 0 });
  await page.waitForTimeout(1200);
  const stillPaused = await jelly(page);
  expect(stillPaused.full_elapsed, 'The menu freezes the real danger clock').toBe(paused.full_elapsed);
  expect(stillPaused.generated_pairs).toBe(paused.generated_pairs);
  await libraryControl(page, 'LibraryClose');
  await expect.poll(async () => (await jelly(page)).visible && !(await jelly(page)).paused).toBe(true);

  const rescue = await availablePair(page, { chest: false });
  const streak = (await growth(page)).streaks[rescue[0].word.id] || 0;
  await dragPair(page, rescue);
  const rescued = await expectClear(page, 1, rescue);
  expect(rescued.cells).toHaveLength(22);
  expect(rescued.full_elapsed, 'A completed rescue cancels the entire previous countdown').toBe(-1);
  expect(rescued.danger).toEqual({ active: false, strength: 0 });
  expect(rescued.chest_count).toBe(0);
  await expect.poll(async () => (await growth(page)).streaks[rescue[0].word.id]).toBe(streak + 1);
  await page.screenshot({ path: info.outputPath('jelly-full-board-rescue.png'), scale: 'css' });
  await expect.poll(async () => (await jelly(page)).cells.length,
    { timeout: 10000, message: 'Natural supply fills the newly opened space' }).toBe(24);
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
    await page.screenshot({ path: info.outputPath(`jelly-${dimensions.width}x${dimensions.height}.png`), scale: 'css' });
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
