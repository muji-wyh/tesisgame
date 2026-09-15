const { test, expect } = require('@playwright/test');
const { openGame, openRewards, roomControl, metrics, learnArtRect, tap,
  rendered, swipeLearn, chooseMode, boardPoint } = require('./game-ui.cjs');

async function wordLesson(page, item, word) {
  const errors = await openGame(page, { mode: 'match', reducedMotion: 'reduce' });
  await openRewards(page);
  await roomControl(page, item);
  await page.keyboard.press('Enter');
  await roomControl(page, 'goal', { locked: true, item });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Learn five words.');
  await rendered(page);
  await swipeLearn(page, 'next');
  await expect(page.locator('#game-status')).toHaveText(/^Learn: [a-z]+\. Swipe to explore\. Tap the picture to hear\.$/);
  await swipeLearn(page, 'previous');
  await expect(page.locator('#game-status')).toHaveText(`Learn: ${word}. Swipe to explore. Tap the picture to hear.`);
  await activatePicture(page);
  if (await page.evaluate(() => Boolean(window.AudioContext || window.webkitAudioContext))) {
    await expect(page.locator('#game-status')).toHaveText(`${word}. Look at the picture and say the word.`);
  }
  return errors;
}

async function activatePicture(page) {
  const bounds = await metrics(page), art = learnArtRect(bounds);
  await tap(page, art.x + art.width / 2, art.y + art.height / 2);
  await rendered(page);
}

async function picture(page, testInfo, name) {
  const bounds = await metrics(page), art = learnArtRect(bounds);
  return page.screenshot({
    path: testInfo.outputPath(`${name}.png`), scale: 'css',
    clip: { x: Math.round(bounds.x + art.x * bounds.scale), y: Math.round(bounds.y + art.y * bounds.scale),
      width: Math.round(art.width * bounds.scale), height: Math.round(art.height * bounds.scale) }
  });
}

async function savedState(page) {
  return page.evaluate(() => ['wordBuddies.medalProgress', 'wordBuddies.playroom']
    .map(key => localStorage.getItem(key)));
}

for (const [item, word] of [['summer', 'ball'], ['winter', 'bell'], ['space', 'rocket']]) {
  test(`${word} picture plays on demand and returns to its original pose`, async ({ page }, testInfo) => {
    const errors = await wordLesson(page, item, word);
    const original = await picture(page, testInfo, `${word}-still`);
    const saved = await savedState(page);
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await rendered(page);
    await activatePicture(page);
    const moving = await picture(page, testInfo, `${word}-playing`);
    expect(moving.equals(original), 'The existing picture must visibly react, not just change hidden state.').toBe(false);
    await page.waitForTimeout(700);
    expect((await picture(page, testInfo, `${word}-settled`)).equals(original)).toBe(true);
    await activatePicture(page);
    await activatePicture(page);
    await swipeLearn(page, 'next');
    await expect(page.locator('#game-status')).toHaveText(/^Learn: [a-z]+\. Swipe to explore\. Tap the picture to hear\.$/);
    await swipeLearn(page, 'previous');
    await expect(page.locator('#game-status')).toHaveText(`Learn: ${word}. Swipe to explore. Tap the picture to hear.`);
    await page.waitForTimeout(700);
    expect((await picture(page, testInfo, `${word}-after-swipe`)).equals(original)).toBe(true);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await rendered(page);
    await activatePicture(page);
    expect((await picture(page, testInfo, `${word}-reduced-motion`)).equals(original)).toBe(true);
    expect(await savedState(page)).toEqual(saved);
    expect(errors).toEqual([]);
  });
}

test('replaying a completed word animates its picture partner without scoring again', async ({ page }, testInfo) => {
  const errors = await wordLesson(page, 'summer', 'ball');
  await chooseMode(page, 'match');
  const bounds = await metrics(page), cards = {};
  for (let index = 0; index < 8; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (word === 'ball') cards[kind] = index;
    await tap(page, point.x, point.y);
  }
  expect(Object.keys(cards).sort()).toEqual(['Picture', 'Word']);
  for (const kind of ['Word', 'Picture']) {
    const point = boardPoint(bounds, cards[kind]);
    await tap(page, point.x, point.y);
  }
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await rendered(page);
  const point = boardPoint(bounds, cards.Picture), size = Math.min(80, bounds.scale * 60);
  const clip = { x: bounds.x + point.x * bounds.scale - size / 2, y: bounds.y + point.y * bounds.scale - size / 2,
    width: size, height: size };
  const before = await page.screenshot({ clip, scale: 'css' }), saved = await savedState(page);
  const word = boardPoint(bounds, cards.Word);
  await tap(page, word.x, word.y);
  await expect(page.locator('#game-status')).toHaveText('ball. Look at the picture and say the word.');
  const active = await page.screenshot({ path: testInfo.outputPath('paired-picture-playing.png'), clip, scale: 'css' });
  expect(active.equals(before)).toBe(false);
  await page.waitForTimeout(700);
  expect((await page.screenshot({ clip, scale: 'css' })).equals(before)).toBe(true);
  await expect(page.locator('#selection-status')).toBeEmpty();
  expect(await savedState(page)).toEqual(saved);
  await page.screenshot({ path: testInfo.outputPath('playful-match-board.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
