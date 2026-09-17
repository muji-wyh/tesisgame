const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { metrics, tap, chooseMode, chooseTheme, collectionBounds, openRewards: rewards,
  chooseRewardSection: rewardSection, worldIconRect, roomControl, leaveRoomPreview: leavePreview, rendered, openGame,
  boardPoint, lessonPoint, swipeLearn, memoryMetrics, memoryPoint, withMemoryPeek, visibleColorCount } = require('./game-ui.cjs');

// Exploratory release audit: interact through the rendered game and its public announcements.
const SIZES = [{ width: 390, height: 844 }, { width: 320, height: 568 }, { width: 844, height: 390 }];

async function memoryCard(page, index) {
  const point = memoryPoint(await memoryMetrics(page), index);
  await tap(page, point.x, point.y);
}

async function lesson(page, control, options) {
  const point = lessonPoint(await metrics(page), control, options);
  await tap(page, point.x, point.y);
}

async function roomTap(page, name, options) {
  const point = await roomControl(page, name, options);
  await tap(page, point.x, point.y);
}

async function scrollToEnd(page, browserName, size) {
  if (browserName === 'chromium') {
    await page.mouse.move(size.width / 2, size.height / 2);
    await page.mouse.wheel(0, 2600);
  } else {
    // Mobile WebKit has no wheel API; use the game's supported pointer drag.
    for (let swipe = 0; swipe < 6; swipe++) {
      await page.mouse.move(size.width / 2, size.height - 30);
      await page.mouse.down();
      await page.mouse.move(size.width / 2, 100, { steps: 8 });
      await page.mouse.up();
      await rendered(page);
    }
  }
  await rendered(page);
}

async function capture(page, testInfo, name, evidence, { held = false } = {}) {
  if (!held) await page.mouse.move(0, 0);
  await rendered(page);
  const path = testInfo.outputPath(`${name}.png`);
  const png = await page.screenshot({ path, scale: 'css' });
  const visibleColors = await visibleColorCount(page, png);
  const entry = { name, path, visibleColors, status: await page.locator('#game-status').textContent(),
    selection: await page.locator('#selection-status').textContent(), metrics: await metrics(page) };
  evidence.push(entry);
  fs.writeFileSync(testInfo.outputPath('audit-evidence.json'), JSON.stringify(evidence, null, 2));
  expect.soft(visibleColors, `${name}: the screenshot must show the game, not a solid loading/background frame`).toBeGreaterThan(20);
}

for (const size of SIZES) {
  test(`exploratory UI tour ${size.width}x${size.height}`, async ({ page, browserName }, testInfo) => {
    test.setTimeout(180000);
    await page.setViewportSize(size);
    const errors = await openGame(page);
    const evidence = [];
    const shot = (name, options) => capture(page, testInfo, name, evidence, options);
    await shot('01-learn-entry');
    await swipeLearn(page, 'next');
    await expect(page.locator('#game-status')).toHaveText(/^Learn: [a-z]+\. Swipe to explore\. Tap the picture to hear\.$/);
    await shot('02-learn-next');
    const learned = await page.locator('#game-status').textContent();
    await rewards(page);
    await shot('03-more-from-learn');
    await expect(page.locator('#game-status')).toContainText('Choose a world from the icons above');
    await shot('04-worlds-from-learn');
    await rewardSection(page, 'room');
    await page.keyboard.press('Escape');
    await swipeLearn(page, 'previous');
    await expect(page.locator('#game-status')).not.toHaveText(learned);
    await swipeLearn(page, 'next');
    await expect(page.locator('#game-status')).toHaveText(learned);
    await lesson(page, 'picture');
    await shot('05-learn-return-hear');
    if (await page.evaluate(() => Boolean(window.AudioContext || window.webkitAudioContext))) {
      const word = learned.match(/^Learn: ([a-z]+)/)[1];
      await expect(page.locator('#game-status'), 'Returning from More preserves the displayed word.').toHaveText(`${word}. Look at the picture and say the word.`);
    }

    await chooseMode(page, 'match');
    await expect(page.locator('#game-status')).toContainText('Find 3 word');
    const first = boardPoint(await metrics(page), 0);
    await tap(page, first.x, first.y);
    await expect(page.locator('#selection-status')).not.toBeEmpty();
    const selected = await page.locator('#selection-status').textContent();
    await shot('06-match-selected');
    await rewards(page);
    await shot('07-rewards-room-top');
    await page.keyboard.press('Escape');
    expect.soft(await page.locator('#selection-status').textContent(), 'Rewards return must preserve the Match selection').toBe(selected);
    await tap(page, first.x, first.y);
    await expect(page.locator('#selection-status')).toBeEmpty();

    await chooseMode(page, 'memory');
    await expect(page.locator('#game-status')).toContainText('Find a pair.');
    await memoryCard(page, 0);
    await expect(page.locator('#selection-status')).toContainText('Memory card 1.');
    await withMemoryPeek(page, async () => {
      await expect(page.locator('#selection-status')).toBeEmpty();
      await shot('11-memory-eye-held', { held: true });
    });
    await expect(page.locator('#game-status')).toContainText('Find a pair.');
    await memoryCard(page, 9);
    const memorySelection = await page.locator('#selection-status').textContent();
    await rewards(page);
    await page.keyboard.press('Escape');
    expect.soft(await page.locator('#selection-status').textContent()).toBe(memorySelection);
    await memoryCard(page, 9);
    await shot('12-memory-after-room');

    await rewards(page);
    const b = await metrics(page);
    await roomTap(page, 'action');
    await expect(page.locator('#game-status')).toHaveText('1/3 · The ball rolls to Pip!');
    await shot('13-room-toy-action');
    if (b.height > 550) {
      await roomTap(page, 'spring');
      await shot('14-toy-gift-preview');
      await leavePreview(page);
    } else {
      await scrollToEnd(page, browserName, size);
      await shot('14-room-controls-scrolled');
      const collection = collectionBounds(b);
      await tap(page, collection.x + collection.width / 6, b.height - 90);
      await expect(page.locator('#game-status')).toContainText('Complete Rocket');
      await shot('14b-room-locked-from-bottom');
      await leavePreview(page);
      await expect(page.locator('#game-status')).toContainText('ball');
      await shot('14c-room-locked-return');
    }
    await rewardSection(page, 'medals');
    await shot('15-medals-section');
    await scrollToEnd(page, browserName, size);
    await rendered(page);
    await shot('16-medals-scrolled');
    await rewardSection(page, 'room');
    await rendered(page);
    await shot('16b-room-section-return');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText('Find a pair.');
    await shot('17-final-return');
    await rewards(page);
    await expect(page.locator('#game-status')).toContainText('Choose a world from the icons above');
    await shot('18-worlds');
    await page.keyboard.press('Escape');
    await chooseTheme(page, 5);
    await expect(page.locator('#game-status')).toContainText('Find a pair.');
    await shot('19-memory-space-world');
    await rewards(page);
    await expect(page.locator('#game-status')).toContainText("Pip's room.");
    await shot('20-world-return-room');
    await page.keyboard.press('Escape');
    expect.soft(errors).toEqual([]);
    expect.soft(learned).toContain('Learn:');
  });
}

test('locked room previews provide a usable return and Medals has its own entry', async ({ page }, testInfo) => {
  test.setTimeout(90000);
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = await openGame(page);
  const evidence = [];
  const shot = name => capture(page, testInfo, name, evidence);
  await rewards(page);
  const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.playroom'));
  await roomTap(page, 'spring');
  await shot('locked-toy-before-return');
  await expect.soft(page.locator('#game-status')).toContainText('Complete Blossom', { timeout: 1500 });
  await leavePreview(page);
  await shot('locked-toy-after-return');
  await expect.soft(page.locator('#game-status')).toContainText('ball', { timeout: 1500 });
  await roomTap(page, 'action');
  await expect.soft(page.locator('#game-status')).toHaveText('1/3 · The ball rolls to Pip!', { timeout: 1500 });
  await roomTap(page, 'space');
  await shot('locked-rocket-before-return');
  await expect.soft(page.locator('#game-status')).toContainText('Complete Rocket', { timeout: 1500 });
  await leavePreview(page);
  await shot('locked-rocket-after-return');
  await expect.soft(page.locator('#game-status')).toContainText('ball', { timeout: 1500 });
  expect.soft(await page.evaluate(() => localStorage.getItem('wordBuddies.playroom'))).toBe(saved);
  await rewardSection(page, 'medals');
  await shot('medals-direct-entry');
  await rewardSection(page, 'room');
  await shot('room-direct-return');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
});

test('More has Pip and Medals with direct world choices and preserved game state', async ({ page }, testInfo) => {
  const errors = await openGame(page, { mode: 'match' });
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  const status = await page.locator('#game-status').textContent();
  const keys = ['wordBuddies.medalProgress', 'wordBuddies.playroom', 'wordBuddies.favoriteReward'];
  const saved = await page.evaluate(keys => keys.map(key => localStorage.getItem(key)), keys);
  const evidence = [];
  await rewards(page);
  await rewardSection(page, 'room');
  await capture(page, testInfo, 'rewards-pip', evidence);
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Medals.');
  await capture(page, testInfo, 'rewards-medals-direct-worlds', evidence);
  for (let index = 0; index < (collectionBounds(await metrics(page)).inlineWorlds ? 7 : 1); index++) {
    await page.keyboard.press('Tab');
  }
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toHaveText(status);
  expect(await page.evaluate(keys => keys.map(key => localStorage.getItem(key)), keys)).toEqual(saved);
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  await rewards(page);
  const world = worldIconRect(await metrics(page), 5);
  await tap(page, world.x + world.width / 2, world.y + world.height / 2);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', '#f1edfb');
  await expect(page.locator('#game-status')).toContainText('Medals.');
  expect(await page.locator('#selection-status').textContent()).toBe(selection);
  expect(errors).toEqual([]);
  expect.soft(errors).toEqual([]);
});
