const { test, expect } = require('@playwright/test');
const { openGame, metrics, boardPoint, tap, rendered } = require('./game-ui.cjs');

async function readBoard(page) {
  const bounds = await metrics(page), cards = [];
  for (let index = 0; index < 8; index++) {
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
    ? ['Picture', 'Word', 'Picture', 'Word', 'Picture', 'Word', 'Picture', 'Word']
    : ['Picture', 'Picture', 'Picture', 'Picture', 'Word', 'Word', 'Word', 'Word']);
  return { cards, sideBySide };
}

test('Match keeps pictures and words in separate groups through rotation and a complete game', async ({ page }, testInfo) => {
  const errors = await openGame(page, { mode: 'match' });
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
  expect(pairs).toHaveLength(3);
  for (const [index, [picture, word]] of pairs.entries()) {
    await tap(page, picture.point.x, picture.point.y);
    await expect(page.locator('#selection-status')).toHaveText(`Picture: ${picture.word}`);
    await tap(page, word.point.x, word.point.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find 3 word');
  }
  await page.screenshot({ path: testInfo.outputPath('match-groups-complete.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
