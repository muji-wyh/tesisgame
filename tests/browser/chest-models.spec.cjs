const { test, expect } = require('@playwright/test');
const { enterGame, chooseMode, rendered, metrics } = require('./game-ui.cjs');

test.use({ trace: 'off', screenshot: 'off', video: 'off' });

const REWARD_KEY = 'wordBuddies.popRewards';
const PLAYER_KEY = 'wordBuddies.leaderboards';
const PLAYER_SAVE = '[leaderboard]\nversion=1\n' +
  'profiles=[{"id":"chest-review-player","name":"Chest Review","avatar":"fox"}]\n' +
  'bests={"pop":{},"match":{},"memory":{}}\nreceipts=[]\n';
const BATCHES = [
  { id: 'model-smoke-sea', themes: ['autumn', 'ocean', 'space'], types: ['harvest', 'tide', 'nebula'] },
  { id: 'model-smoke-relic', themes: ['jungle', 'candy'], types: ['bramble', 'bonbon'], open: 1 }
];

async function seedPendingTreasure(page, batch) {
  const saved = `[treasure]\nversion=1\nround_id="${batch.id}"\n` +
    `entries=${JSON.stringify(batch.themes.map(theme => ({ theme, opened: false })))}\nreceipts=[]\n`;
  await page.addInitScript(({ rewardKey, playerKey, players, saved }) => {
    // Playwright creates a fresh context per test. These are valid saved-game
    // fixtures; the runtime still restores, renders, holds and awards normally.
    if (localStorage.getItem(playerKey) === null) localStorage.setItem(playerKey, players);
    if (localStorage.getItem(rewardKey) === null) localStorage.setItem(rewardKey, saved);
    window.__chestModelSmoke = { writes: [], states: [], pressedAt: null };
    const originalSet = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      const result = originalSet.call(this, key, value);
      if (key === rewardKey) window.__chestModelSmoke.writes.push({ at: performance.now(), value });
      return result;
    };
    document.addEventListener('pointerdown', event => {
      if (event.target.id === 'canvas') window.__chestModelSmoke.pressedAt = performance.now();
    }, true);
  }, { rewardKey: REWARD_KEY, playerKey: PLAYER_KEY, players: PLAYER_SAVE, saved });
  return saved;
}

async function roomState(page) {
  return page.locator('#pop-reward-status').evaluate(element => JSON.parse(element.dataset.snapshot || '{}'));
}

async function captureModels(page, info, label, room) {
  await rendered(page);
  const bounds = await metrics(page);
  const crops = room.chests.map(chest => {
    const rect = chest.art_rect;
    expect(rect, `${chest.type} exposes its actual artwork bounds`).toBeTruthy();
    expect(rect.width).toBeGreaterThan(30);
    expect(rect.height).toBeGreaterThan(30);
    return { type: chest.type,
      x: bounds.x + rect.x * bounds.scale, y: bounds.y + rect.y * bounds.scale,
      width: rect.width * bounds.scale, height: rect.height * bounds.scale };
  });
  const screenshot = await page.screenshot({ path: info.outputPath(`${label}.png`), scale: 'css' });
  // Inspect every model from one saved frame. This avoids taking separate
  // screenshots that force expensive extra software-rendered game frames.
  const pixels = await page.evaluate(async ({ png, crops }) => {
    const image = new Image();
    image.src = `data:image/png;base64,${png}`;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.width; canvas.height = image.height;
    const context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    return crops.map(crop => {
      const x = Math.max(0, Math.ceil(crop.x + crop.width * 0.05));
      const y = Math.max(0, Math.ceil(crop.y + crop.height * 0.05));
      const width = Math.max(1, Math.min(Math.floor(crop.width * 0.9), canvas.width - x));
      const height = Math.max(1, Math.min(Math.floor(crop.height * 0.9), canvas.height - y));
      const { data } = context.getImageData(x, y, width, height);
      const colors = new Set();
      let dark = 0, samples = 0;
      for (let offset = 0; offset < data.length; offset += 12) {
        colors.add(`${data[offset] >> 4},${data[offset + 1] >> 4},${data[offset + 2] >> 4}`);
        if (Math.min(data[offset], data[offset + 1], data[offset + 2]) < 190) dark++;
        samples++;
      }
      return { type: crop.type, colors: colors.size, darkFraction: dark / samples, width, height };
    });
  }, { png: screenshot.toString('base64'), crops });
  await info.attach(`${label}-model-pixels.json`, { body: JSON.stringify({ room, crops, pixels }, null, 2), contentType: 'application/json' });
  for (const model of pixels) {
    expect(model.colors, `${model.type} renders detailed material colors inside its artwork region`).toBeGreaterThan(24);
    expect(model.darkFraction, `${model.type} contains visible solid artwork rather than an empty pale panel`).toBeGreaterThan(0.015);
  }
}

async function openByHolding(page, info, index, saved) {
  await page.locator('#pop-reward-status').evaluate(element => {
    const fixture = window.__chestModelSmoke;
    let previous = '';
    const record = () => {
      const room = JSON.parse(element.dataset.snapshot || '{}');
      const state = { active: room.active, holding: room.holding, opening: room.opening,
        opened: room.opened_count, chests: room.chests?.map(chest => ({ opened: chest.opened,
          committed: chest.committed, phase: chest.phase })) };
      const key = JSON.stringify(state);
      if (key !== previous) {
        fixture.states.push(state);
        previous = key;
      }
    };
    record();
    new MutationObserver(record).observe(element, { attributes: true, attributeFilter: ['data-snapshot'] });
  });
  const room = await roomState(page), rect = room.chests[index].rect, bounds = await metrics(page);
  await page.mouse.move(bounds.x + (rect.x + rect.width / 2) * bounds.scale,
    bounds.y + (rect.y + rect.height / 2) * bounds.scale);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await roomState(page)).opened_count,
      { timeout: 60000, intervals: [150, 250], message: 'A real sustained hold reaches the model release and saves one reward' }).toBe(1);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => {
    const state = await roomState(page);
    return { active: state.active, opening: state.opening, mode: state.chests[index].mode };
  }, { timeout: 30000, intervals: [200, 300] }).toEqual({ active: -1, opening: false, mode: 'opened' });
  const observed = await page.evaluate(() => window.__chestModelSmoke);
  await info.attach('actual-hold-and-save.json', { body: JSON.stringify(observed, null, 2), contentType: 'application/json' });
  expect(observed.states.some(state => state.holding && state.opened === 0), 'The real gesture passes through an unawarded hold').toBe(true);
  expect(observed.states.filter(state => state.opened > 0).every(state => state.chests[index].committed),
    'An opened reward always has a committed physical model release').toBe(true);
  expect(observed.writes, 'One hold creates exactly one durable reward write').toHaveLength(1);
  expect(observed.pressedAt, 'The duration starts at the real canvas pointer event').not.toBeNull();
  expect(observed.writes[0].at - observed.pressedAt, 'The shared 1.2-second hold and release buildup cannot award early').toBeGreaterThanOrEqual(3000);
  expect(observed.writes[0].value).not.toBe(saved);
  expect((await roomState(page)).chests.map(chest => chest.opened)).toEqual(room.chests.map((_, at) => at === index));
}

for (const batch of BATCHES) {
  test(`restored treasure renders ${batch.types.join(', ')}${batch.open === undefined ? '' : ' and opens through a real hold'}`, async ({ page }, info) => {
    test.setTimeout(150000);
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (/SCRIPT ERROR|Parse Error|Unable to configure animated chest model|Failed loading resource/.test(message.text())) errors.push(message.text());
    });
    const saved = await seedPendingTreasure(page, batch);
    await page.goto('/');
    await enterGame(page, { onboarding: false });
    await chooseMode(page, 'pop', { choosePlayer: false });
    await expect.poll(async () => {
      const room = await roomState(page);
      return { visible: room.visible, round: room.round_id, opened: room.opened_count,
        types: room.chests?.map(chest => chest.type), paused: room.paused, failed: room.save_failed };
    }, { timeout: 45000, intervals: [200, 300] }).toEqual({ visible: true, round: batch.id, opened: 0,
      types: batch.types, paused: false, failed: false });
    expect(await page.evaluate(key => localStorage.getItem(key), REWARD_KEY), 'Restoring does not replace the earned batch').toBe(saved);
    await captureModels(page, info, `${batch.id}-closed`, await roomState(page));
    if (batch.open !== undefined) {
      await openByHolding(page, info, batch.open, saved);
      await captureModels(page, info, `${batch.id}-opened`, await roomState(page));
    }
    expect(errors).toEqual([]);
  });
}
