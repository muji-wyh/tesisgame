const { test, expect } = require('@playwright/test');
const { openGame, openRewards, roomControl, metrics, tap,
  rendered, discoverMatchCards, boardPoint } = require('./game-ui.cjs');

async function wordMatch(page, item, word) {
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  await openRewards(page);
  await roomControl(page, item);
  await page.keyboard.press('Enter');
  await roomControl(page, 'goal', { locked: true, item });
  await page.keyboard.press('Enter');
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  const cards = (await discoverMatchCards(page)).filter(card => card.word === word);
  expect(cards.map(card => card.kind).sort()).toEqual(['Picture', 'Word']);
  const bounds = await metrics(page);
  const pair = Object.fromEntries(cards.map(card => [card.kind, boardPoint(bounds, card.index)]));
  for (const kind of ['Word', 'Picture']) await tap(page, pair[kind].x, pair[kind].y);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  await expect(page.locator('#selection-status')).toBeEmpty();
  await rendered(page);
  return { errors, pair, bounds };
}

async function savedState(page) {
  return page.evaluate(() => ['wordBuddies.medalProgress', 'wordBuddies.playroom']
    .map(key => localStorage.getItem(key)));
}

for (const [item, word] of [['summer', 'ball'], ['winter', 'bell'], ['space', 'rocket']]) {
  test(`replaying the matched ${word} word or picture animates its picture without scoring again`, async ({ page }, testInfo) => {
    const { errors, pair, bounds } = await wordMatch(page, item, word);
    // Compare the picture itself so the card's temporary tap feedback cannot
    // stand in for movement of the illustrated object.
    const size = Math.min(80, bounds.scale * 60);
    const clip = { x: bounds.x + pair.Picture.x * bounds.scale - size / 2,
      y: bounds.y + pair.Picture.y * bounds.scale - size / 2, width: size, height: size };
    const picture = name => page.screenshot({ path: testInfo.outputPath(`${word}-${name}.png`), clip, scale: 'css' });
    const original = await picture('still'), saved = await savedState(page);
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await rendered(page);
    for (const kind of ['Word', 'Picture']) {
      await tap(page, pair[kind].x, pair[kind].y);
      await expect(page.locator('#game-status')).toHaveText(`${word}. Look at the picture and say the word.`);
      expect((await picture(`${kind}-playing`)).equals(original), 'The matched picture must visibly react.').toBe(false);
      await page.waitForTimeout(700);
      expect((await picture(`${kind}-settled`)).equals(original)).toBe(true);
      await expect(page.locator('#selection-status')).toBeEmpty();
      expect(await savedState(page)).toEqual(saved);
    }
    await tap(page, pair.Picture.x, pair.Picture.y);
    await tap(page, pair.Picture.x, pair.Picture.y);
    await page.waitForTimeout(700);
    expect((await picture('repeat-settled')).equals(original)).toBe(true);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await rendered(page);
    for (const kind of ['Word', 'Picture']) {
      await tap(page, pair[kind].x, pair[kind].y);
      await expect(page.locator('#game-status')).toHaveText(`${word}. Look at the picture and say the word.`);
      expect((await picture(`${kind}-reduced-motion`)).equals(original)).toBe(true);
      await expect(page.locator('#selection-status')).toBeEmpty();
    }
    expect(await savedState(page)).toEqual(saved);
    await page.screenshot({ path: testInfo.outputPath(`${word}-playful-match-board.png`), scale: 'css' });
    expect(errors).toEqual([]);
  });
}
