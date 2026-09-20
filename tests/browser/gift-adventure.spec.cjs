const { test, expect } = require('@playwright/test');
const { metrics, tap, rendered, enterGame, openGame, boardPoint, matchWords, discoverMatchCards,
  resultPoint, collectionBounds, openRewards: openRoom, roomPoint, roomState, roomControl } = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const PICNIC = 'apple banana orange pear grape cherry melon carrot tomato corn peas egg bread cake cookie cheese milk water juice rice pumpkin coconut pineapple watermelon strawberry'.split(' ');
const APPLE_STAGES = [
  '1/3 · An apple for Pip!',
  '2/3 · Pip nibbles the apple. Crunch!',
  '3/3 · Pip finishes the apple. Just the core!'
];

async function seedAppleGift(page, { pieces = 2, goal = '', world = 'spring' } = {}) {
  const room = `[playroom]\nversion=1\ntoy="toy-ball"\nbackdrop="backdrop-home"\nfavorite=""\n\n[journey]\nrecent_topic_ids=[]\npreferred_theme_id="${world}"\ngoal_item_id="${goal}"\n\n[stickers]\nword_ids=["apple"]\ndisplay_word_id=""\n`;
  const medals = `[medals]\nversion=1\ncounts={"autumn-1":${pieces}}\n`;
  await page.addInitScript(({ roomKey, medalKey, room, medals }) => {
    // Reload must read the player's latest save, not reapply the starting fixture.
    if (localStorage.getItem(roomKey) === null) localStorage.setItem(roomKey, room);
    if (localStorage.getItem(medalKey) === null) localStorage.setItem(medalKey, medals);
  }, { roomKey: ROOM_KEY, medalKey: MEDAL_KEY, room, medals });
}

async function record(page, key = ROOM_KEY) {
  return page.evaluate(key => localStorage.getItem(key), key);
}

function stickerIds(room) {
  const line = room.match(/^word_ids=(.*)$/m)?.[1] || '';
  return [...line.matchAll(/"([^"]+)"/g)].map(match => match[1]);
}

async function pieceCount(page) {
  const counts = (await record(page, MEDAL_KEY))?.match(/counts=\{([\s\S]*?)\}/)?.[1] || '';
  return [...counts.matchAll(/:\s*(\d+)/g)].reduce((total, match) => total + Number(match[1]), 0);
}

async function previewLockedApple(page, hasGoal = false) {
  await roomControl(page, 'autumn', { goal: hasGoal });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Autumn apple. Complete');
  await expect(page.locator('#game-status')).toContainText('1 more piece');
  await rendered(page);
}

async function requestPreviewGoal(page) {
  await roomControl(page, 'goal', { locked: true, item: 'autumn' });
  await page.keyboard.press('Enter');
}

async function winMatch(page) {
  const bounds = await metrics(page);
  const cards = new Map();
  for (let index = 0; index < 8; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!cards.has(word)) cards.set(word, {});
    cards.get(word)[kind] = index;
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  const pairs = [...cards.entries()].filter(([, pair]) => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  for (const [index, [word, pair]] of pairs.entries()) {
    const written = boardPoint(bounds, pair.Word), pictured = boardPoint(bounds, pair.Picture);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find 3 word');
  }
  await expect(page.locator('#game-status')).toContainText('You did it!');
}

async function claimChest(page) {
  const bounds = await metrics(page);
  const chest = resultPoint(bounds, 'chest');
  await page.mouse.move(bounds.x + chest.x * bounds.scale, bounds.y + chest.y * bounds.scale);
  await page.mouse.down();
  try {
    // Hold through rendered game frames, including a slow phone frame.
    await expect(page.locator('#game-status')).toContainText('A gift for Pip!');
  } finally {
    await page.mouse.up();
  }
  await expect(page.locator('#game-status')).not.toContainText('Tap to place!');
}

async function tryGift(page) {
  const point = resultPoint(await metrics(page), 'gift');
  await tap(page, point.x, point.y);
  await expect(page.locator('#game-status')).toContainText('Offer the apple');
  expect(await record(page)).toContain('toy="toy-autumn"');
  await rendered(page);
}

async function playAppleStages(page, testInfo, prefix, firstTouch = false) {
  await roomControl(page, 'toy');
  for (let index = 0; index < APPLE_STAGES.length; index++) {
    if (index === 0 && firstTouch) {
      const bounds = await metrics(page);
      const toy = roomPoint(bounds, 'toy');
      await tap(page, toy.x, toy.y);
    } else {
      await page.keyboard.press('Enter');
    }
    await expect(page.locator('#game-status')).toHaveText(APPLE_STAGES[index]);
    await rendered(page);
    await page.screenshot({ path: testInfo.outputPath(`${prefix}-${index + 1}.png`), scale: 'css' });
  }
  // Play again resets the short sequence; it does not itself consume stage one.
  await page.keyboard.press('Enter');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText(APPLE_STAGES[0]);
}

test('a chosen gift teaches its noun, earns one normal piece and plays three stages after reload', async ({ page }, testInfo) => {
  await seedAppleGift(page);
  const errors = await openGame(page);
  const initialStickers = stickerIds(await record(page));
  await openRoom(page);
  await previewLockedApple(page);
  await page.screenshot({ path: testInfo.outputPath('gift-locked-apple.png'), scale: 'css' });
  // Hit the visible card action in the canvas: keyboard activation alone can
  // pass even when a focused button has incorrectly scrolled off screen.
  const help = await roomControl(page, 'goal', { locked: true, item: 'autumn' });
  await tap(page, help.x, help.y);
  await expect(page.locator('#game-status')).toContainText('Picnic time. Find 3 word–picture pairs. Help Pip get Autumn apple.');
  const goalSave = await record(page);
  expect(goalSave).toContain('goal_item_id="toy-autumn"');
  expect(goalSave).toContain('preferred_theme_id="autumn"');
  const words = await matchWords(page);
  expect(words).toContain('apple');
  expect(words.every(word => PICNIC.includes(word))).toBe(true);
  expect(await pieceCount(page)).toBe(2);
  expect(stickerIds(await record(page))).toEqual(initialStickers);
  await page.screenshot({ path: testInfo.outputPath('gift-apple-lesson.png'), scale: 'css' });
  await winMatch(page);
  expect(await pieceCount(page)).toBe(2);
  await claimChest(page);
  expect(await pieceCount(page)).toBe(3);
  await page.screenshot({ path: testInfo.outputPath('gift-earned-apple.png'), scale: 'css' });
  await tryGift(page);
  const earnedStickers = stickerIds(await record(page));
  await page.screenshot({ path: testInfo.outputPath('gift-apple-ready.png'), scale: 'css' });
  await playAppleStages(page, testInfo, 'gift-apple-stage', true);
  expect(await pieceCount(page)).toBe(3);
  expect(stickerIds(await record(page))).toEqual(earnedStickers);
  await page.reload();
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  for (const field of ['goal_item_id="toy-autumn"', 'preferred_theme_id="autumn"', 'toy="toy-autumn"']) {
    expect(await record(page)).toContain(field);
  }
  await openRoom(page);
  await roomControl(page, 'autumn');
  await page.keyboard.press('Enter');
  await roomControl(page, 'toy');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText(APPLE_STAGES[0]);
  expect(await pieceCount(page)).toBe(3);
  expect(stickerIds(await record(page))).toEqual(earnedStickers);
  await page.screenshot({ path: testInfo.outputPath('gift-restored-apple.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('a failed gift-goal save keeps the previous goal and lesson until the visible retry succeeds', async ({ page }, testInfo) => {
  await seedAppleGift(page, { goal: 'toy-spring' });
  const errors = await openGame(page);
  const previousCards = await discoverMatchCards(page), selected = previousCards[3];
  const selectedPoint = boardPoint(await metrics(page), selected.index);
  await tap(page, selectedPoint.x, selectedPoint.y);
  await expect(page.locator('#selection-status')).toHaveText(`${selected.kind}: ${selected.word}`);
  const original = await record(page);
  const medals = await record(page, MEDAL_KEY);
  await openRoom(page);
  await previewLockedApple(page, true);
  const bounds = await metrics(page);
  await roomControl(page, 'goal', { locked: true, item: 'autumn' });
  const collection = collectionBounds(bounds);
  const card = roomPoint(bounds, 'autumn', { owned: (await roomState(page)).owned }), scale = Math.max(2 / 3, bounds.scale);
  const columns = collection.width * scale >= 720 ? 3 : 2;
  const cell = (collection.width - collection.gap * (columns - 1)) / columns;
  const goalClip = { x: bounds.x + (card.x - cell / 2 + 6 / scale) * bounds.scale,
    y: bounds.y + (card.y + 4 / scale) * bounds.scale,
    width: (cell - 12 / scale) * bounds.scale, height: 50 / scale * bounds.scale };
  const beforeMessage = await page.screenshot({ path: testInfo.outputPath('gift-goal-message-before.png'), clip: goalClip, scale: 'css' });
  await page.evaluate(() => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Blocked for gift-goal retry test', 'QuotaExceededError');
      return save.call(this, key, value);
    };
    window.restoreGiftGoalSave = () => { Storage.prototype.setItem = save; };
  });
  await requestPreviewGoal(page);
  await expect(page.locator('#game-status')).toContainText('Your gift goal could not be saved. Press the gift button to retry.');
  expect(await record(page)).toBe(original);
  await rendered(page);
  const failedMessage = await page.screenshot({ path: testInfo.outputPath('gift-goal-message-failed.png'), clip: goalClip, scale: 'css' });
  expect(failedMessage.equals(beforeMessage), 'A failed goal save must show feedback on the same visible toy card.').toBe(false);
  await page.screenshot({ path: testInfo.outputPath('gift-goal-save-failed.png'), scale: 'css' });
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toHaveText('Now find its match!');
  await expect(page.locator('#selection-status')).toHaveText(`${selected.kind}: ${selected.word}`);
  await tap(page, selectedPoint.x, selectedPoint.y);
  expect(await discoverMatchCards(page)).toEqual(previousCards);
  await page.evaluate(() => window.restoreGiftGoalSave());
  await openRoom(page);
  await roomControl(page, 'goal', { locked: true, item: 'autumn' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Picnic time. Find 3 word–picture pairs. Help Pip get Autumn apple.');
  expect(await record(page)).toContain('goal_item_id="toy-autumn"');
  expect(await record(page)).toContain('preferred_theme_id="autumn"');
  expect(await matchWords(page)).toContain('apple');
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  expect(stickerIds(await record(page))).toEqual(stickerIds(original));
  await page.screenshot({ path: testInfo.outputPath('gift-goal-save-recovered.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('an earned saved goal stays keyboard reachable in Pip\'s home at 320px and replay grants no rewards', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await seedAppleGift(page, { pieces: 3, goal: 'toy-autumn', world: 'autumn' });
  const errors = await openGame(page);
  const medals = await record(page, MEDAL_KEY);
  const stickers = stickerIds(await record(page));
  expect(await record(page)).toContain('toy="toy-ball"');
  await openRoom(page);
  await roomControl(page, 'autumn');
  await page.screenshot({ path: testInfo.outputPath('gift-completed-goal-320.png'), scale: 'css' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Offer the apple');
  expect(await record(page)).toContain('toy="toy-autumn"');
  await playAppleStages(page, testInfo, 'gift-keyboard-320-stage');
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  expect(stickerIds(await record(page))).toEqual(stickers);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  await openRoom(page);
  await roomControl(page, 'autumn');
  await page.keyboard.press('Enter');
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('gift-completed-goal-320-return.png'), scale: 'css' });
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  expect(errors).toEqual([]);
});
