const { test, expect } = require('@playwright/test');
const { openGame, openRewards, enterGame, metrics, collectionHeaderRect, roomControl, roomState, tap, rendered } = require('./game-ui.cjs');

test.use({ viewport: { width: 1024, height: 768 }, deviceScaleFactor: 1.5, hasTouch: true });

test('More opens only Pip\'s room while saved reward pieces still unlock playable toys', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    if (localStorage.getItem('wordBuddies.medalProgress') !== null) return;
    localStorage.setItem('wordBuddies.medalProgress',
      '[medals]\nversion=1\ncounts={"spring-1":3,"spring-2":1,"summer-1":3}\n');
  });
  const errors = await openGame(page, { mode: 'match' });
  const status = page.locator('#game-status');
  await expect(page.locator('#help')).not.toContainText(/Medals|Display with Pip|reward preview/i);
  await openRewards(page);
  await expect(status).toContainText("Pip's room opened. 3 toys in Pip's home. 6 toys to unlock below.");
  const saved = await roomState(page);
  expect(saved.owned).toEqual(['ball', 'spring', 'summer']);
  expect(saved.medals).toMatch(/"spring-2"\s*:\s*1/);

  // The former tab area is a static room title on both desktop and phone.
  for (const viewport of [{ width: 1024, height: 768 }, { width: 320, height: 680 }]) {
    await page.setViewportSize(viewport);
    await rendered(page);
    const title = collectionHeaderRect(await metrics(page), 'room');
    const announcement = await status.textContent();
    await tap(page, title.x + title.width / 2, title.y + title.height / 2);
    await expect(status).toHaveText(announcement);
    expect((await roomState(page)).medals).toBe(saved.medals);
    await page.screenshot({ path: testInfo.outputPath(`pip-room-no-medals-${viewport.width}.png`), scale: 'css' });
  }

  await roomControl(page, 'spring');
  await page.keyboard.press('Enter');
  await expect(status).toContainText('1/3 · A drink for the flower!');
  expect((await roomState(page)).medals).toBe(saved.medals);
  await page.keyboard.press('Escape');
  await expect(status).toContainText('Find 3 word');

  await page.reload();
  await enterGame(page);
  await openRewards(page);
  await expect(status).toContainText("Pip's room opened. 3 toys in Pip's home.");
  const restored = await roomState(page);
  expect(restored.owned).toEqual(saved.owned);
  expect(restored.medals).toBe(saved.medals);
  await expect(page.locator('#help')).not.toContainText(/Medals|Display with Pip|reward preview/i);
  expect(errors).toEqual([]);
});
