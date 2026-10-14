const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap, rendered, celebrationState } = require('./game-ui.cjs');

const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const room = page => page.locator('#jelly-reward-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));

async function press(page, rect) {
  expect(rect).toHaveLength(4);
  await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);
  await rendered(page);
}

async function fillBoard(page) {
  for (let batch = 0; batch < 12; batch++) {
    await expect.poll(async () => {
      const state = await jelly(page);
      return state.full_elapsed >= 0 || state.preview.enabled;
    }, { message: 'The previous real supply settles before the next manual release' }).toBe(true);
    const state = await jelly(page);
    if (state.full_elapsed >= 0) return state;
    await press(page, state.preview.rect);
    await expect.poll(async () => (await jelly(page)).generated_tiles,
      { message: 'Tapping the actual preview releases the advertised supply' }).toBeGreaterThan(state.generated_tiles);
  }
  throw new Error('The real preview did not fill the board');
}

function inside(rect, bounds) {
  expect(rect[0]).toBeGreaterThanOrEqual(-0.1);
  expect(rect[1]).toBeGreaterThanOrEqual(-0.1);
  expect(rect[0] + rect[2]).toBeLessThanOrEqual(bounds.width + 0.1);
  expect(rect[1] + rect[3]).toBeLessThanOrEqual(bounds.height + 0.1);
}

function pair(state, marked = false) {
  for (const first of state.tiles) {
    if (!first.visible || !first.settled) continue;
    const second = state.tiles.find(tile => tile.id !== first.id && tile.visible && tile.settled &&
      tile.word.id === first.word.id && tile.kind !== first.kind && (!marked || first.chest || tile.chest));
    if (second) return [first, second];
  }
  return null;
}

async function earnChest(page) {
  for (let attempt = 0; attempt < 100; attempt++) {
    await expect.poll(async () => {
      const state = await jelly(page);
      return state.phase === 'playing' && !state.reward_presentation?.active && !state.fusions?.length;
    }, { timeout: 15000, message: 'Each real merge and chest milestone settles before the next gesture' }).toBe(true);
    const state = await jelly(page);
    if (state.chest_count === 1) return state;
    let chosen = pair(state, true) || pair(state);
    if (!chosen) {
      if (state.preview.enabled) await press(page, state.preview.rect);
      await expect.poll(async () => {
        chosen = pair(await jelly(page));
        return Boolean(chosen);
      }, { timeout: 30000 }).toBe(true);
    }
    const before = await jelly(page), bounds = await metrics(page);
    const points = chosen.map(tile => ({
      x: bounds.x + (tile.rect[0] + tile.rect[2] / 2) * bounds.scale,
      y: bounds.y + (tile.rect[1] + tile.rect[3] / 2) * bounds.scale
    }));
    await page.mouse.move(points[0].x, points[0].y);
    await page.mouse.down();
    try {
      await expect.poll(async () => (await jelly(page)).drag.source).toBe(chosen[0].id);
      await page.mouse.move(points[1].x, points[1].y, { steps: 10 });
      await expect.poll(async () => (await jelly(page)).drag.target).toBe(chosen[1].id);
    } finally {
      await page.mouse.up();
    }
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  }
  throw new Error('The real Jelly matches did not earn one chest');
}

for (const mode of ['jelly', 'word_jelly']) {
  for (const viewport of [{ width: 393, height: 852 }, { width: 1366, height: 768 }]) {
    test(mode + ' danger opens a settlement dialog at ' + viewport.width + 'x' + viewport.height, async ({ page }, info) => {
      test.skip(info.project.name !== 'desktop-chromium', 'Private Chromium verifies both explicit viewport sizes once.');
      test.setTimeout(90000);
      await page.setViewportSize(viewport);
      const errors = await openGame(page, { mode, reducedMotion: 'no-preference' });
      await expect.poll(async () => {
        const state = await jelly(page);
        return state.mode === mode && state.phase === 'playing' && state.tiles?.every(tile => tile.settled);
      }).toBe(true);
      const startingCoins = (await wallet(page)).balance;
      const full = await fillBoard(page);
      expect(full.phase).toBe('playing');
      expect(full.game_over.visible).toBe(false);
      await page.screenshot({ path: info.outputPath(mode + '-danger-warning.png'), scale: 'css' });
      await expect.poll(async () => (await jelly(page)).game_over?.visible,
        { timeout: 18000, message: 'The actual danger deadline opens Game over without an extra player action' }).toBe(true);
      await expect.poll(async () => (await room(page)).visible).toBe(true);
      await rendered(page);
      const ended = await jelly(page), settlement = await room(page), bounds = await metrics(page);
      expect(ended.phase).toBe('finished');
      expect(ended.game_over.title).toBe('Game over');
      expect(ended.result.visible, 'The board remains the frozen backdrop instead of becoming a result page').toBe(false);
      expect(ended.danger.active, 'The danger glow stops after its deadline').toBe(false);
      expect((await celebrationState(page)).active, 'Game over does not delay settlement behind a victory intermission').toBe(false);
      expect(settlement).toMatchObject({ heading: 'Game over', visible: true, chest_count: 0, scroll_max: 0 });
      expect(settlement.result_context).toMatchObject({ reason: 'danger', score: 0, fragment_count: 0, chest_count: 0 });
      expect((await wallet(page)).balance).toBe(startingCoins);
      inside(ended.game_over.panel_rect, bounds);
      const actions = settlement.actions.filter(action => action.visible);
      expect(actions.map(action => action.text).sort()).toEqual(['Home', 'Play again']);
      for (const action of actions) {
        inside(action.rect, bounds);
        expect(action.rect[3] * bounds.scale, 'Dialog actions retain a comfortable touch target').toBeGreaterThanOrEqual(43.75);
      }
      await page.screenshot({ path: info.outputPath(mode + '-game-over-dialog.png'), scale: 'css' });
      await info.attach('game-over-state.json', {
        body: JSON.stringify({ viewport, ended, settlement }, null, 2), contentType: 'application/json'
      });
      await tap(page, 3, 3);
      expect((await jelly(page)).game_over.visible, 'Tapping the shade cannot dismiss the result or resume a full board').toBe(true);
      const replay = actions.find(action => action.text === 'Play again');
      await press(page, replay.rect);
      await expect.poll(async () => {
        const state = await jelly(page);
        return state.round_id !== ended.round_id && state.phase === 'playing' && !state.game_over.visible;
      }, { message: 'Play again starts a playable fresh round directly from the dialog' }).toBe(true);
      expect((await wallet(page)).balance).toBe(startingCoins);
      expect(errors).toEqual([]);
    });
  }
}

test('earned Jelly Match treasure opens inside the responsive Game over dialog', async ({ page }, info) => {
  test.skip(info.project.name !== 'desktop-chromium', 'The real earned-chest flow runs in private Chromium once.');
  test.setTimeout(240000);
  await page.setViewportSize({ width: 393, height: 852 });
  const errors = await openGame(page, { mode: 'jelly', reducedMotion: 'no-preference' });
  const before = (await wallet(page)).balance;
  const earned = await earnChest(page);
  expect(earned.chest_tier).toBe(1);
  await fillBoard(page);
  await expect.poll(async () => (await room(page)).game_over?.visible,
    { timeout: 18000, message: 'Earned loot settles in the same modal when the actual deadline expires' }).toBe(true);
  const ended = await jelly(page);
  for (const viewport of [{ width: 393, height: 852 }, { width: 568, height: 320 }]) {
    await page.setViewportSize(viewport);
    await rendered(page);
    await expect.poll(async () => (await room(page)).scroll_max,
      { message: 'The earned chest and footer fit without scrolling after resize' }).toBe(0);
    const state = await room(page), bounds = await metrics(page);
    expect(state).toMatchObject({ heading: 'Game over', chest_count: 1, opened_count: 0, visible: true });
    expect(state.result_context).toMatchObject({ reason: 'danger', score: earned.score, chest_tier: 1 });
    inside(state.game_over.panel_rect, bounds);
    for (const action of state.actions.filter(action => action.visible)) {
      inside(action.rect, bounds);
      expect(action.rect[3] * bounds.scale).toBeGreaterThanOrEqual(43.75);
    }
    await page.screenshot({ path: info.outputPath('earned-game-over-' + viewport.width + 'x' + viewport.height + '.png'), scale: 'css' });
    await info.attach('earned-state-' + viewport.width + '.json', {
      body: JSON.stringify({ viewport, state, bounds }, null, 2), contentType: 'application/json'
    });
  }
  const current = await room(page), bounds = await metrics(page), chest = current.chests[0].rect;
  const position = {
    x: bounds.x + (chest.x + chest.width / 2) * bounds.scale,
    y: bounds.y + (chest.y + chest.height / 2) * bounds.scale
  };
  await page.mouse.move(position.x, position.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await room(page)).opened_count,
      { timeout: 15000, message: 'A real chest hold saves the earned reward inside Game over' }).toBe(1);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => (await wallet(page)).balance).toBe(before + 50);
  await expect.poll(async () => (await room(page)).opening).toBe(false);
  expect((await jelly(page)).round_id).toBe(ended.round_id);
  expect((await room(page)).game_over.visible).toBe(true);
  await page.screenshot({ path: info.outputPath('earned-game-over-opened.png'), scale: 'css' });
  const home = (await room(page)).actions.find(action => action.text === 'Home');
  await press(page, home.rect);
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(true);
  expect((await wallet(page)).balance).toBe(before + 50);
  expect(errors).toEqual([]);
});
