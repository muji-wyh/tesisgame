const { test, expect } = require('@playwright/test');
const {
  metrics, tap, rendered, openGame, enterGame,
  openRewards, collectionHeaderRect, activateLibraryControl,
  discoverMatchCards, boardPoint, resultPoint, visibleColorCount, acceptCelebration
} = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const OLD_COUNTS = { 'spring-1': 3, 'summer-2': 1, 'autumn-6': 2 };
const learningThemes = require('../../data/professional/themes.json').profiles;

async function record(page, key = ROOM_KEY) {
  return page.evaluate(key => localStorage.getItem(key), key);
}

async function counts(page) {
  const dictionary = (await record(page, MEDAL_KEY))?.match(/counts=\{([\s\S]*?)\}/)?.[1] || '';
  return Object.fromEntries([...dictionary.matchAll(/"([^"]+)":\s*(\d+)/g)]
    .map(([, id, amount]) => [id, Number(amount)]));
}

async function seedPriorSave(page) {
  const medals = `[medals]\nversion=1\ncounts=${JSON.stringify(OLD_COUNTS)}\n` +
    '[pair_chests]\nversion=1\nstate={"match":{"dry_rounds":2,"round":{}},"memory":{"dry_rounds":0,"round":{}}}\n';
  const room = '[playroom]\nversion=1\ntoy="toy-ball"\nbackdrop="backdrop-home"\nfavorite="spring-1"\n\n' +
    '[journey]\nrecent_topic_ids=[]\npreferred_theme_id="candy"\ngoal_item_id=""\n\n' +
    '[stickers]\nword_ids=["cat","apple"]\ndisplay_word_id=""\n\n[learning]\nage_band="4-6"\n';
  await page.addInitScript(({ medals, room, medalKey, roomKey }) => {
    // Existing progress is the fixture. The new piece must come from a real win
    // and hold gesture; reloading never overwrites the player's current save.
    if (localStorage.getItem(medalKey) === null) localStorage.setItem(medalKey, medals);
    if (localStorage.getItem(roomKey) === null) localStorage.setItem(roomKey, room);
  }, { medals, room, medalKey: MEDAL_KEY, roomKey: ROOM_KEY });
}

async function winMatch(page) {
  const bounds = await metrics(page), cards = await discoverMatchCards(page);
  const pairs = cards.filter(card => card.kind === 'Word').map(word =>
    [word, cards.find(card => card.kind === 'Picture' && card.word === word.word)]
  ).filter(([, picture]) => picture);
  expect(pairs).toHaveLength(5);
  for (const [index, [word, picture]] of pairs.entries()) {
    const written = boardPoint(bounds, word.index), pictured = boardPoint(bounds, picture.index);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word.word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? /You did it!|Round complete/ : 'Find 5 word');
  }
  await acceptCelebration(page);
}

async function captureSettlement(page, testInfo, phase) {
  await page.mouse.move(0, 0);
  await rendered(page);
  const bounds = await metrics(page), state = bounds.growth;
  expect(state.settlement.visible).toBe(true);
  expect(state.result.visible).toBe(true);
  expect(state.board.visible, 'The finished Match board stays behind the dialog.').toBe(true);
  const [x, y, width, height] = state.settlement.panel_rect;
  expect(x).toBeGreaterThan(0);
  expect(y).toBeGreaterThan(0);
  expect(x + width).toBeLessThan(bounds.width);
  expect(y + height).toBeLessThan(bounds.height);
  const png = await page.screenshot({ path: testInfo.outputPath(`settlement-${phase}.png`), scale: 'css' });
  expect(await visibleColorCount(page, png), `${phase}: evidence contains the rendered game and dialog.`).toBeGreaterThan(20);
}

async function closeRewards(page) {
  const back = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await expect(page.locator('#game-status')).not.toContainText('Lv0');
  await rendered(page);
}

function persistentFields(saved) {
  return Object.fromEntries(['toy', 'backdrop', 'favorite', 'preferred_theme_id', 'goal_item_id',
    'word_ids', 'display_word_id', 'age_band'].map(field => [field, saved.match(new RegExp(`^${field}=(.*)$`, 'm'))?.[1]]));
}

test('the chest settles over its learning path and preserves its saved reward through career previews, growth and reload', async ({ page }, testInfo) => {
  test.setTimeout(180000);
  await seedPriorSave(page);
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  expect(await counts(page)).toEqual(OLD_COUNTS);
  expect((await metrics(page)).library.learning.selection.track).toBe('growth');
  await winMatch(page);
  const beforeClaim = await record(page, MEDAL_KEY);
  expect(await counts(page), 'Winning alone does not claim the chest.').toEqual(OLD_COUNTS);
  const growthPalette = learningThemes.find(profile => profile.id === 'growth_garden').palette;
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', growthPalette.background.toLowerCase());
  await captureSettlement(page, testInfo, 'closed');

  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await rendered(page);
  const bounds = await metrics(page), chest = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
  await page.mouse.down();
  try {
    await expect(page.locator('#game-status')).toContainText('Keep holding to open. Release to cancel.');
    await expect(page.locator('#game-status')).toHaveText('Round complete Treasure collected!', { timeout: 15000 });
  } finally {
    await page.mouse.up();
  }
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await rendered(page);
  // Match awards one ordinary chest independently of the historical preference.
  const earnedCounts = { ...OLD_COUNTS, 'spring-2': 1 };
  expect(await counts(page), 'Holding awards one frozen chest reward and preserves previous medals.').toEqual(earnedCounts);
  const earnedSave = await record(page, MEDAL_KEY);
  expect(earnedSave).not.toBe(beforeClaim);
  await captureSettlement(page, testInfo, 'opened');

  await openRewards(page);
  await closeRewards(page);
  await activateLibraryControl(page, 'ChangeLearningPath');
  await activateLibraryControl(page, 'ProfessionalPath');
  await activateLibraryControl(page, 'Career_retail');
  await expect.poll(async () => (await metrics(page)).library.learning.course_id).toBe('retail');
  const retailPalette = learningThemes.find(profile => profile.id === 'professional_retail').palette;
  await expect.poll(() => page.locator('#game').evaluate(element => element.style.getPropertyValue('--voice-accent').toLowerCase()))
    .toBe(retailPalette.accent.toLowerCase());
  expect(await record(page, MEDAL_KEY)).toBe(earnedSave);
  const savedRoom = persistentFields(await record(page));
  await page.reload();
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', growthPalette.background.toLowerCase());
  expect(await counts(page), 'Reload keeps the earned chest reward and saved learning path.').toEqual(earnedCounts);
  expect(persistentFields(await record(page)), 'Reload preserves owned items, stickers and learning settings.').toEqual(savedRoom);
  await openRewards(page);
  await page.screenshot({ path: testInfo.outputPath('settlement-reloaded-growth.png'), scale: 'css' });
  expect(await counts(page)).toEqual(earnedCounts);
  expect(errors).toEqual([]);
});
