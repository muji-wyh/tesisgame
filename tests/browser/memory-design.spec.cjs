const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, activateLibraryControl, metrics, rendered, visibleColorCount } = require('./game-ui.cjs');
const { memoryState, pressMemoryRect, startObservation, startMatching, memoryCardTap } = require('./memory-flow.cjs');

test('Memory keeps its illustrated deck and concealed selection through browsing and a paid Peek', async ({ page }, testInfo) => {
  test.setTimeout(150000);
  await page.addInitScript(() => {
    localStorage.setItem('growWithPip.coinWallet.v1',
      '[wallet]\nversion=2\nbalance=100\nreceipts={"memory-design-opening-coins":100}\n');
  });
  const errors = await openGame(page, { mode: 'memory', reducedMotion: 'reduce' });
  const original = await startObservation(page);
  await startMatching(page);
  await memoryCardTap(page, original[0].index);
  for (const course of ['caregiving', 'retail', 'food_service']) {
    await openModeMenu(page);
    await activateLibraryControl(page, 'ChangeLearningPath');
    await activateLibraryControl(page, 'ProfessionalPath');
    await activateLibraryControl(page, `Career_${course}`);
    expect((await metrics(page)).library.learning).toMatchObject({ screen: 'modules', course_id: course });
    await activateLibraryControl(page, 'ContinueCurrentRound');
    await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
    expect((await metrics(page)).library.current).toBe('memory');
    await page.mouse.move(0, 0);
    await rendered(page);
    const png = await page.screenshot({ path: testInfo.outputPath(`memory-deck-after-${course}.png`), scale: 'css' });
    expect(await visibleColorCount(page, png)).toBeGreaterThan(20);
    const state = await memoryState(page);
    expect(state.cards[original[0].index]).toMatchObject({ selected: true, face_up: false, word_id: '' });
    expect(state.cards.every(card => !card.face_up && !card.word_id)).toBe(true);
    expect(state.reward).toMatchObject({ tier: 6, change_count: 0 });
  }
  const eye = (await metrics(page)).growth.controls.find(control => control.name === 'StudyGarden' && control.visible);
  await pressMemoryRect(page, eye.rect);
  await expect.poll(async () => (await memoryState(page)).peek.studying).toBe(true);
  const revealed = await memoryState(page);
  expect(revealed.peek).toMatchObject({ count: 2, duration: 5, next_price: 200 });
  expect(revealed.cards.map(card => ({ index: card.index, kind: card.kind, word: card.word_id }))).toEqual(original);
  expect(revealed.cards.every(card => card.face_up && !card.selected)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('memory-deck-revealed.png'), scale: 'css' });
  await startMatching(page);
  expect((await memoryState(page)).cards.every(card => !card.face_up && !card.word_id)).toBe(true);
  expect(errors).toEqual([]);
});
