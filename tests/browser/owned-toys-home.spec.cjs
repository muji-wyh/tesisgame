const { test, expect } = require('@playwright/test');
const { THEME_IDS, openGame, openRewards, roomControl, roomState, tap, rendered } = require('./game-ui.cjs');

const ROOM_KEY = 'wordBuddies.playroom';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const FIRST_ACTION = { ball: 'Roll the ball', spring: 'Water the flower', autumn: 'Offer the apple', candy: 'Set the cake' };

async function seedHome(page, themes, equipped = 'ball') {
  const counts = Object.fromEntries(themes.map(theme => [`${theme}-1`, 3]));
  const room = `[playroom]\nversion=1\ntoy="toy-${equipped}"\nbackdrop="backdrop-home"\nfavorite=""\n`
    + '\n[journey]\nrecent_topic_ids=[]\npreferred_theme_id="spring"\ngoal_item_id=""\n';
  const medals = `[medals]\nversion=1\ncounts=${JSON.stringify(counts)}\n`;
  await page.addInitScript(({ room, medals, roomKey, medalKey }) => {
    if (localStorage.getItem(roomKey) === null) localStorage.setItem(roomKey, room);
    if (localStorage.getItem(medalKey) === null) localStorage.setItem(medalKey, medals);
  }, { room, medals, roomKey: ROOM_KEY, medalKey: MEDAL_KEY });
}

for (const fixture of [
  { name: 'starter', themes: [], choose: 'ball' },
  { name: 'partly earned', themes: ['spring', 'autumn'], choose: 'autumn' },
  { name: 'all earned', themes: THEME_IDS, choose: 'candy' }
]) {
  test(`${fixture.name} toys live in Pip's home and only unearned toys remain below`, async ({ page }, testInfo) => {
    test.setTimeout(150000);
    await seedHome(page, fixture.themes);
    const errors = await openGame(page);
    const original = await roomState(page);
    await openRewards(page);
    // This is the real game's accessible announcement, not a DOM stand-in for its canvas.
    await expect(page.locator('#game-status')).toContainText(`${fixture.themes.length + 1} toys in Pip's home. ${8 - fixture.themes.length} toys to unlock below.`);
    await page.screenshot({ path: testInfo.outputPath(`${fixture.name}-home.png`), scale: 'css' });
    const toy = await roomControl(page, fixture.choose);
    await tap(page, toy.x, toy.y);
    await expect(page.locator('#game-status')).toContainText(FIRST_ACTION[fixture.choose]);
    expect((await roomState(page)).equipped).toBe(fixture.choose);
    expect((await roomState(page)).medals).toBe(original.medals);
    await rendered(page);
    await page.screenshot({ path: testInfo.outputPath(`${fixture.name}-owned-toy-selected.png`), scale: 'css' });
    expect(errors).toEqual([]);
  });
}

test('a locked preview returns through an owned home toy and a failed save retries there', async ({ page }, testInfo) => {
  test.setTimeout(180000);
  await seedHome(page, ['spring', 'autumn'], 'autumn');
  const errors = await openGame(page);
  const original = await roomState(page);
  await openRewards(page);
  await roomControl(page, 'winter');
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Preview only. Winter bell.');
  expect((await roomState(page)).saved).toBe(original.saved);
  await page.screenshot({ path: testInfo.outputPath('locked-bell-preview.png'), scale: 'css' });

  await page.evaluate(() => {
    const save = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'wordBuddies.playroom') throw new DOMException('Home toy retry fixture', 'QuotaExceededError');
      return save.call(this, key, value);
    };
    window.restoreHomeToySave = () => { Storage.prototype.setItem = save; };
  });
  await roomControl(page, 'spring', { locked: true, item: 'winter' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Your room could not be saved.');
  expect((await roomState(page)).saved).toBe(original.saved);
  await page.screenshot({ path: testInfo.outputPath('owned-flower-save-failed.png'), scale: 'css' });
  await page.evaluate(() => window.restoreHomeToySave());
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Water the flower');
  expect((await roomState(page)).equipped).toBe('spring');
  expect((await roomState(page)).medals).toBe(original.medals);
  await page.screenshot({ path: testInfo.outputPath('owned-flower-save-recovered.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
