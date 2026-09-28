const { test, expect } = require('@playwright/test');
const { openGame, metrics, boardPoint, tap, rendered } = require('./game-ui.cjs');

async function readBoard(page) {
  const bounds = await metrics(page), cards = [];
  for (let index = 0; index < 10; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    cards.push({ kind, word, point });
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  const sideBySide = boardPoint(bounds, 0).y !== boardPoint(bounds, 3).y;
  expect(cards.map(card => card.kind)).toEqual(sideBySide
    ? Array.from({ length: 5 }, () => ['Picture', 'Word']).flat()
    : [...Array(5).fill('Picture'), ...Array(5).fill('Word')]);
  expect(new Set(cards.filter(card => card.kind === 'Picture').map(card => card.word)).size).toBe(5);
  expect(cards.filter(card => card.kind === 'Picture').map(card => card.word).sort())
    .toEqual(cards.filter(card => card.kind === 'Word').map(card => card.word).sort());
  return { cards, sideBySide };
}

test('Match keeps five real pairs in separate groups through rotation and completes only after all five', async ({ page }, testInfo) => {
  const errors = await openGame(page, { mode: 'match' });
  const originalViewport = page.viewportSize();
  const first = await readBoard(page);
  await page.screenshot({ path: testInfo.outputPath('match-groups-before.png'), scale: 'css' });
  const picture = first.cards.find(card => card.kind === 'Picture');
  await tap(page, picture.point.x, picture.point.y);
  await expect(page.locator('#selection-status')).toHaveText(`Picture: ${picture.word}`);
  await page.setViewportSize(first.sideBySide ? { width: 1194, height: 834 } : { width: 390, height: 844 });
  await rendered(page);
  await expect(page.locator('#selection-status')).toHaveText(`Picture: ${picture.word}`);
  const point = boardPoint(await metrics(page), 0);
  await tap(page, point.x, point.y);
  await expect(page.locator('#selection-status')).toBeEmpty();
  const next = await readBoard(page);
  expect(next.sideBySide).not.toBe(first.sideBySide);
  for (const kind of ['Picture', 'Word']) {
    expect(next.cards.filter(card => card.kind === kind).map(card => card.word))
      .toEqual(first.cards.filter(card => card.kind === kind).map(card => card.word));
  }
  await page.screenshot({ path: testInfo.outputPath('match-groups-rotated.png'), scale: 'css' });
  const pairs = next.cards.filter(card => card.kind === 'Picture').map(picture =>
    [picture, next.cards.find(word => word.kind === 'Word' && word.word === picture.word)]
  ).filter(([, word]) => word);
  expect(pairs).toHaveLength(5);
  for (const [index, [picture, word]] of pairs.entries()) {
    await tap(page, picture.point.x, picture.point.y);
    await expect(page.locator('#selection-status')).toHaveText(`Picture: ${picture.word}`);
    await tap(page, word.point.x, word.point.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? 'You did it!' : 'Find 5 word');
    if (index === 1) {
      await page.setViewportSize(originalViewport);
      await rendered(page);
      for (const card of next.cards) {
        card.point = first.cards.find(original => original.kind === card.kind && original.word === card.word).point;
      }
      const earned = pairs[0][0];
      await tap(page, earned.point.x, earned.point.y);
      await expect(page.locator('#game-status')).toHaveText(`${earned.word}. Look at the picture and say the word.`);
      await expect(page.locator('#selection-status'), 'Resizing preserves completed pairs instead of making them selectable again.').toBeEmpty();
      await page.screenshot({ path: testInfo.outputPath('match-five-pairs-progress-after-rotation.png'), scale: 'css' });
    }
  }
  await page.screenshot({ path: testInfo.outputPath('match-groups-complete.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
