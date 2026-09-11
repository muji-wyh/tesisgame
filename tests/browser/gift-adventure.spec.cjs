const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, rendered, openGame, boardPoint, lessonPoint } = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const learningStatus = /^Learn: ([a-z]+)\. Look, read, and press Hear\.$/;
const PICNIC = 'apple banana orange pear grape cherry melon carrot tomato corn peas egg bread cake cookie cheese milk water juice rice'.split(' ');
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

async function openRoom(page) {
  const bounds = await metrics(page);
  await tap(page, bounds.width - 48, 48);
  await expect(page.locator('#game-status')).toContainText('My rewards opened.');
  await rendered(page);
}

async function tabs(page, count, backwards = false) {
  for (let index = 0; index < count; index++) {
    await page.keyboard.press(backwards ? 'Shift+Tab' : 'Tab');
  }
  await rendered(page);
}

async function previewLockedApple(page, hasGoal = false) {
  // Back starts focused. Pip, toy, four Pip actions, the toy action, categories
  // and gift cards follow; focus scrolls the apple into view before activation.
  await tabs(page, hasGoal ? 14 : 13);
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Autumn apple. Complete');
  await expect(page.locator('#game-status')).toContainText('1 more piece');
  await rendered(page);
}

async function requestPreviewGoal(page) {
  // Selecting a locked gift keeps its Help action visible and focused.
  await page.keyboard.press('Enter');
}

async function lessonTap(page, key) {
  const point = lessonPoint(await metrics(page), key);
  await tap(page, point.x, point.y);
  await rendered(page);
}

async function learnWords(page) {
  await lessonTap(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(learningStatus);
  await lessonTap(page, 'previous');
  const words = [];
  for (let index = 0; index < 5; index++) {
    if (index) await lessonTap(page, 'next');
    await expect(page.locator('#game-status')).toHaveText(learningStatus);
    words.push((await page.locator('#game-status').textContent()).match(learningStatus)[1]);
  }
  expect(new Set(words).size).toBe(5);
  return words;
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
  const pairs = [...cards.values()].filter(pair => pair.Word !== undefined && pair.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  for (const pair of pairs) {
    for (const index of [pair.Word, pair.Picture]) {
      const point = boardPoint(bounds, index);
      await tap(page, point.x, point.y);
    }
    await expect(page.locator('#game-status')).toContainText('Great match!');
    const point = lessonPoint(bounds, 'action', { match: true, multiple: false });
    await tap(page, point.x, point.y);
  }
  await expect(page.locator('#game-status')).toContainText('You did it!');
}

async function claimChest(page) {
  const bounds = await metrics(page);
  await page.mouse.move(bounds.x + 48 * bounds.scale, bounds.y + 208 * bounds.scale);
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
  const bounds = await metrics(page);
  const landscape = bounds.width >= bounds.height || bounds.height < 560;
  const textWidth = landscape ? Math.max(232, (bounds.width - 40) * 0.39) : bounds.width - 24;
  const left = bounds.width - 12 - textWidth;
  // The earned gift adds a third action after Repeat lesson and New adventure.
  await tap(page, left + textWidth * 5 / 6, bounds.height - 48);
  await expect(page.locator('#game-status')).toContainText('Offer the apple');
  expect(await record(page)).toContain('toy="toy-autumn"');
  await rendered(page);
}

async function playAppleStages(page, testInfo, prefix, firstTouch = false) {
  for (let index = 0; index < APPLE_STAGES.length; index++) {
    if (index === 0 && firstTouch) {
      const bounds = await metrics(page);
      // The action sits beneath the expanded room at 754 logical pixels; on a shorter
      // view, focusing it scrolls its bottom edge above the 16px page margin.
      await tap(page, bounds.width / 2, Math.min(754, bounds.height - 52));
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
  // Hit the visible Help action in the canvas: keyboard activation alone can
  // pass even when a focused button has incorrectly scrolled off screen.
  await tap(page, (await metrics(page)).width / 2, 208);
  await expect(page.locator('#game-status')).toContainText('Picnic time. Learn five words. Help Pip get Autumn apple.');
  const goalSave = await record(page);
  expect(goalSave).toContain('goal_item_id="toy-autumn"');
  expect(goalSave).toContain('preferred_theme_id="autumn"');
  const words = await learnWords(page);
  expect(words).toContain('apple');
  expect(words.every(word => PICNIC.includes(word))).toBe(true);
  expect(await pieceCount(page)).toBe(2);
  expect(stickerIds(await record(page))).toEqual(initialStickers);
  await page.screenshot({ path: testInfo.outputPath('gift-apple-lesson.png'), scale: 'css' });
  await chooseMode(page, 1);
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
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  for (const field of ['goal_item_id="toy-autumn"', 'preferred_theme_id="autumn"', 'toy="toy-autumn"']) {
    expect(await record(page)).toContain(field);
  }
  await openRoom(page);
  // A saved completed goal is the first room action after Back.
  await tabs(page, 1);
  await page.keyboard.press('Enter');
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
  const previousWords = await learnWords(page);
  const original = await record(page);
  const medals = await record(page, MEDAL_KEY);
  await openRoom(page);
  await previewLockedApple(page, true);
  const bounds = await metrics(page);
  // Crop only the message above Help, excluding Pip and the focus outline.
  // An error announced only off screen would leave this visible area unchanged.
  const goalClip = { x: bounds.x + 16 * bounds.scale, y: bounds.y + 136 * bounds.scale,
    width: (bounds.width - 32) * bounds.scale, height: 34 * bounds.scale };
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
  expect(failedMessage.equals(beforeMessage), 'A failed goal save must show feedback beside the visible Help action.').toBe(false);
  await page.screenshot({ path: testInfo.outputPath('gift-goal-save-failed.png'), scale: 'css' });
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  await lessonTap(page, 'previous');
  await expect(page.locator('#game-status')).toHaveText(`Learn: ${previousWords[3]}. Look, read, and press Hear.`);
  await lessonTap(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(`Learn: ${previousWords[4]}. Look, read, and press Hear.`);
  await page.evaluate(() => window.restoreGiftGoalSave());
  await openRoom(page);
  // The locked preview remains selected, so its Help action follows Back.
  await tabs(page, 1);
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Picnic time. Learn five words. Help Pip get Autumn apple.');
  expect(await record(page)).toContain('goal_item_id="toy-autumn"');
  expect(await record(page)).toContain('preferred_theme_id="autumn"');
  expect(await learnWords(page)).toContain('apple');
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  expect(stickerIds(await record(page))).toEqual(stickerIds(original));
  await page.screenshot({ path: testInfo.outputPath('gift-goal-save-recovered.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('a completed saved goal stays keyboard reachable at 320px and toy replay grants no rewards', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await seedAppleGift(page, { pieces: 3, goal: 'toy-autumn', world: 'autumn' });
  const errors = await openGame(page);
  const medals = await record(page, MEDAL_KEY);
  const stickers = stickerIds(await record(page));
  expect(await record(page)).toContain('toy="toy-ball"');
  await openRoom(page);
  await tabs(page, 1);
  await page.screenshot({ path: testInfo.outputPath('gift-completed-goal-320.png'), scale: 'css' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Offer the apple');
  expect(await record(page)).toContain('toy="toy-autumn"');
  await playAppleStages(page, testInfo, 'gift-keyboard-320-stage');
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  expect(stickerIds(await record(page))).toEqual(stickers);
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  await openRoom(page);
  await tabs(page, 1);
  await page.keyboard.press('Enter');
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('gift-completed-goal-320-return.png'), scale: 'css' });
  expect(await record(page, MEDAL_KEY)).toBe(medals);
  expect(errors).toEqual([]);
});
