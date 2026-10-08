const { test, expect } = require('@playwright/test');
const {
  THEME_IDS, enterGame, chooseMode, rendered, metrics, openGame, chooseTheme,
  tap, boardPoint, discoverMatchCards, celebrationState, acceptCelebration,
  resultPoint, visibleColorCount
} = require('./game-ui.cjs');
const { roomState, scrollChestIntoView, insideViewport } = require('./pop-treasure-ui.cjs');

test.use({ trace: 'off', screenshot: 'off', video: 'off' });

const REWARD_KEY = 'wordBuddies.popRewards';
const PLAYER_KEY = 'wordBuddies.leaderboards';
const PLAYER_SAVE = '[leaderboard]\nversion=1\n' +
  'profiles=[{"id":"chest-review-player","name":"Chest Review","avatar":"fox"}]\n' +
  'bests={"pop":{},"match":{},"memory":{}}\nreceipts=[]\n';
const BATCHES = [
  { id: 'model-smoke-sea', themes: ['autumn', 'ocean', 'space'], types: ['harvest', 'tide', 'nebula'] },
  { id: 'model-smoke-relic', themes: ['jungle', 'candy'], types: ['bramble', 'bonbon'] }
];
const MODEL_THEMES = BATCHES.flatMap(batch => batch.themes);

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

async function captureModels(page, info, label, selected = null) {
  const settled = await roomState(page);
  expect(settled.opening || settled.holding, 'Static captures never interrupt an active opening').toBe(false);
  // Freeze idle model rendering during screenshot and pixel inspection. Real
  // opening gestures below explicitly restore the complete motion timeline.
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await rendered(page);
  const count = (await roomState(page)).chests.length;
  const captures = [];
  for (const index of selected || Array.from({ length: count }, (_, index) => index)) {
    const room = await scrollChestIntoView(page, index);
    await rendered(page);
    const bounds = await metrics(page), chest = room.chests[index];
    const rect = chest.art_rect;
    expect(rect, `${chest.type} exposes its actual artwork bounds`).toBeTruthy();
    expect(rect.width).toBeGreaterThan(30);
    expect(rect.height).toBeGreaterThan(30);
    expect(insideViewport(rect, room.scroll_rect), `${chest.type} is entirely visible in the scroll viewport`).toBe(true);
    const crop = { type: chest.type,
      x: bounds.x + rect.x * bounds.scale, y: bounds.y + rect.y * bounds.scale,
      width: rect.width * bounds.scale, height: rect.height * bounds.scale };
    // Each model now has its own visible frame: offscreen cards are clipped
    // by the list and must not be sampled from the initial viewport image.
    const screenshot = await page.screenshot({ path: info.outputPath(`${label}-${index + 1}-${chest.type}.png`), scale: 'css' });
    const pixels = await page.evaluate(async ({ png, crop }) => {
      const image = new Image();
      image.src = `data:image/png;base64,${png}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
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
    }, { png: screenshot.toString('base64'), crop });
    captures.push({ room, crop, pixels });
    expect(pixels.colors, `${pixels.type} renders detailed material colors inside its artwork region`).toBeGreaterThan(24);
    expect(pixels.darkFraction, `${pixels.type} contains visible solid artwork rather than an empty pale panel`).toBeGreaterThan(0.015);
  }
  await info.attach(`${label}-model-pixels.json`, { body: JSON.stringify(captures, null, 2), contentType: 'application/json' });
}

async function openByHolding(page, info, index, saved) {
  // Scroll while idle models are static, then enable motion before the press.
  // Do not restore reduced motion until the physical timeline has settled.
  const room = await scrollChestIntoView(page, index), rect = room.chests[index].rect;
  const previousCount = room.opened_count;
  expect(room.chests[index].opened).toBe(false);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await rendered(page);
  await page.locator('#pop-reward-status').evaluate(element => {
    const fixture = window.__chestModelSmoke;
    window.__chestModelObserver?.disconnect();
    fixture.writes = [];
    fixture.states = [];
    fixture.pressedAt = null;
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
    window.__chestModelObserver = new MutationObserver(record);
    window.__chestModelObserver.observe(element, { attributes: true, attributeFilter: ['data-snapshot'] });
  });
  const bounds = await metrics(page);
  await page.mouse.move(bounds.x + (rect.x + rect.width / 2) * bounds.scale,
    bounds.y + (rect.y + rect.height / 2) * bounds.scale);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await roomState(page)).opened_count,
      { timeout: 60000, intervals: [150, 250], message: 'A real sustained hold reaches the model release and saves one reward' }).toBe(previousCount + 1);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => {
    const state = await roomState(page);
    return { active: state.active, opening: state.opening, mode: state.chests[index].mode };
  }, { timeout: 30000, intervals: [200, 300] }).toEqual({ active: -1, opening: false, mode: 'opened' });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await rendered(page);
  const observed = await page.evaluate(() => window.__chestModelSmoke);
  await info.attach(`${room.chests[index].type}-actual-hold-and-save.json`, { body: JSON.stringify(observed, null, 2), contentType: 'application/json' });
  expect(observed.states.some(state => state.holding && state.opened === previousCount), 'The real gesture passes through an unawarded hold').toBe(true);
  expect(observed.states.filter(state => state.opened > previousCount).every(state => state.chests[index].committed),
    'An opened reward always has a committed physical model release').toBe(true);
  expect(observed.writes, 'One hold creates exactly one durable reward write').toHaveLength(1);
  expect(observed.pressedAt, 'The duration starts at the real canvas pointer event').not.toBeNull();
  expect(observed.writes[0].at - observed.pressedAt, 'The shared 1.2-second hold and release buildup cannot award early').toBeGreaterThanOrEqual(3000);
  expect(observed.writes[0].value).not.toBe(saved);
  expect((await roomState(page)).chests.map(chest => chest.opened)).toEqual(room.chests.map((chest, at) => chest.opened || at === index));
}

for (const batch of BATCHES) {
  test(`restored treasure renders and opens every ${batch.types.join(', ')} model through real holds`, async ({ page }, info) => {
    test.setTimeout(480000);
    await page.emulateMedia({ reducedMotion: 'reduce' });
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
    await captureModels(page, info, `${batch.id}-closed`);
    for (let index = 0; index < batch.types.length; index++) {
      const before = await page.evaluate(key => localStorage.getItem(key), REWARD_KEY);
      await openByHolding(page, info, index, before);
      await captureModels(page, info, `${batch.id}-opened`, [index]);
    }
    expect((await roomState(page)).opened_count).toBe(batch.types.length);
    expect(errors).toEqual([]);
  });
}

async function winMatch(page) {
  const bounds = await metrics(page), cards = await discoverMatchCards(page);
  const pairs = cards.filter(card => card.kind === 'Word').map(word =>
    [word, cards.find(card => card.kind === 'Picture' && card.word === word.word)]);
  expect(pairs).toHaveLength(5);
  for (const [index, [word, picture]] of pairs.entries()) {
    expect(picture).toBeTruthy();
    const written = boardPoint(bounds, word.index), pictured = boardPoint(bounds, picture.index);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word.word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? 'You did it!' : 'Find 5 word');
  }
  await expect.poll(async () => {
    const state = await celebrationState(page);
    return state.active && state.ready;
  }, { timeout: 15000 }).toBe(true);
}

async function captureThemedStage(page, info, theme, phase) {
  await page.mouse.move(0, 0);
  await rendered(page);
  const png = await page.screenshot({ path: info.outputPath(`${theme}-${phase}.png`), fullPage: true, scale: 'css' });
  expect(await visibleColorCount(page, png), `${theme}/${phase} includes the actual rendered stage`).toBeGreaterThan(20);
}

test('all five replacement designs fit celebrations and closed stages, and a claimed chest survives theme changes', async ({ page }, info) => {
  test.setTimeout(480000);
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  await chooseTheme(page, THEME_IDS.indexOf(MODEL_THEMES[0]));
  await winMatch(page);
  const miniatures = [];
  for (const theme of MODEL_THEMES) {
    await chooseTheme(page, THEME_IDS.indexOf(theme));
    const state = await celebrationState(page), bounds = await metrics(page);
    expect({ active: state.active, ready: state.ready, theme: state.theme, mode: state.chest_mode })
      .toEqual({ active: true, ready: true, theme, mode: 'closed' });
    const [x, y, width, height] = state.chest_rect;
    expect(width).toBeGreaterThan(30);
    expect(height).toBeGreaterThan(30);
    expect(insideViewport({ x, y, width, height }, { x: 0, y: 0, width: bounds.width, height: bounds.height }),
      `${theme} miniature remains inside the game viewport`).toBe(true);
    miniatures.push(state);
    await captureThemedStage(page, info, theme, 'celebration');
  }
  await info.attach('themed-celebration-miniatures.json', { body: JSON.stringify(miniatures, null, 2), contentType: 'application/json' });
  await acceptCelebration(page);
  const before = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  for (const theme of MODEL_THEMES) {
    await chooseTheme(page, THEME_IDS.indexOf(theme));
    await expect(page.locator('#game-status')).toHaveText('You did it! Hold to open your chest!');
    await captureThemedStage(page, info, theme, 'closed');
    expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress')),
      'Previewing closed designs does not award a reward').toBe(before);
  }
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await rendered(page);
  const bounds = await metrics(page), point = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + point.x * bounds.scale, bounds.y + point.y * bounds.scale);
  await page.mouse.down();
  try {
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 60000 });
  } finally {
    await page.mouse.up();
  }
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const claimed = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  expect(claimed).not.toBe(before);
  // Candy was selected when this reward was claimed. Its opened chest stays
  // attached to the reward while the surrounding stage follows theme changes.
  // Each design's own opened model is covered by the restored-batch holds above.
  for (const theme of MODEL_THEMES) {
    await chooseTheme(page, THEME_IDS.indexOf(theme));
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?');
    await captureThemedStage(page, info, theme, 'opened');
    expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress')),
      'Changing the opened stage does not duplicate the claimed reward').toBe(claimed);
  }
  expect(errors).toEqual([]);
});
