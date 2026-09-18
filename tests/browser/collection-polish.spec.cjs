const { test, expect } = require('@playwright/test');
const { metrics, tap, uiScale, modeRect, collectionBounds, firstMedalPoint,
  enterGame, openGame, openRewards, chooseRewardSection, rendered } = require('./game-ui.cjs');

test('mode positions are Match, Learn, Memory with Match selected on entry and reload', async ({ page }, testInfo) => {
  const errors = await openGame(page, { mode: 'match' });
  const status = page.locator('#game-status');
  await expect(status).toContainText('Find 3 word');
  await expect(page.locator('#speech-panel')).toBeHidden();
  await expect(page.locator('#help')).not.toContainText('Repeat lesson');
  let current = 'match';
  for (const [name, announcement] of [['match', 'Find 3 word'], ['learn', 'Learn five words.'], ['memory', 'Find a pair.']]) {
    const bounds = await metrics(page), rect = modeRect(bounds, name, current);
    await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
    await expect(status).toContainText(announcement);
    current = name;
  }
  await page.reload();
  await enterGame(page);
  await expect(status).toContainText('Find 3 word');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('#speech-panel')).toBeHidden();
  await page.screenshot({ path: testInfo.outputPath('match-default-entry.png'), scale: 'css' });
  expect(errors).toEqual([]);
});

test('playful Medals keeps Pip interactive and earned progress intact', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    localStorage.setItem('wordBuddies.medalProgress', '[medals]\nversion=1\ncounts={"spring-1":3,"spring-2":1}\n');
  });
  const errors = await openGame(page);
  await openRewards(page);
  await chooseRewardSection(page, 'medals');
  const status = page.locator('#game-status');
  await expect(status).toContainText('1 of 48 medals complete.');
  const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'));
  await page.mouse.move(0, 0);
  await rendered(page);
  await page.screenshot({ path: testInfo.outputPath('playful-medals-shelves.png'), scale: 'css' });
  const bounds = await metrics(page), collection = collectionBounds(bounds), scale = uiScale(bounds);
  await tap(page, collection.x + collection.padding + 32 / scale, collection.top + collection.gap + 32 / scale);
  await expect(status).toContainText('Pip says: duck!');
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(saved);
  const first = firstMedalPoint(bounds);
  await tap(page, first.x, first.y);
  await expect(status).toContainText('Blossom #1');
  await page.screenshot({ path: testInfo.outputPath('earned-medal-preview.png'), scale: 'css' });
  await page.keyboard.press('Escape');
  await expect(status).toContainText('Medals. Win a game');
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress'))).toBe(saved);
  expect(errors).toEqual([]);
});
