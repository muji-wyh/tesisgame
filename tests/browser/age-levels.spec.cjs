const { test, expect } = require('@playwright/test');
const words = require('../../words.json');
const { enterGame, openGame, openRewards, metrics, tap, rendered, ageControl,
  boardPoint, chooseMode, matchWords, growthView, growthState, activateGrowthControl,
  observeAudio } = require('./game-ui.cjs');
const { watchAudioRequests, expectRecording } = require('./bundled-audio.cjs');

async function age(page, id) {
  const rect = await ageControl(page, id);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await expect.poll(async () => String((await growthView(page)).catalog?.age_band)).toBe(String(id));
}

async function saved(page) {
  return page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'));
}

test('all ten age catalogues preserve the current lesson and cannot unlock later words', async ({ page }, info) => {
  test.setTimeout(150000);
  const errors = await openGame(page);
  const lesson = await matchWords(page), initial = await saved(page);
  expect(lesson.every(text => words.find(word => word.text === text)?.min_age === 3)).toBe(true);
  const first = boardPoint(await metrics(page), 0);
  await tap(page, first.x, first.y);
  const selection = await page.locator('#selection-status').textContent();
  await openRewards(page);
  for (let id = 3; id <= 12; id++) {
    await age(page, id);
    const view = await growthView(page);
    expect(view.catalog.word_count).toBe(words.filter(word => word.min_age === id).length);
    expect(view.notice).toContain(id === 3 ? 'Six correct answers' : 'Preview only');
    expect((await growthState(page)).level).toBe(3);
    expect(await saved(page)).toBe(initial);
    expect(await page.locator('#selection-status').textContent()).toBe(selection);
  }
  await page.screenshot({ path: info.outputPath('age-12-preview.png'), scale: 'css' });
  await activateGrowthControl(page, 'GrowthBack');
  await tap(page, first.x, first.y);
  expect(await matchWords(page)).toEqual(lesson);
  await chooseMode(page, 'memory');
  await page.reload();
  await enterGame(page);
  expect((await matchWords(page)).every(text => words.find(word => word.text === text)?.min_age === 3)).toBe(true);
  expect((await growthState(page)).level).toBe(3);
  expect(errors).toEqual([]);
});

test('age catalogues expose artwork, meanings and bundled pronunciations across pages', async ({ page, browserName }, info) => {
  test.setTimeout(120000);
  await page.setViewportSize({ width: 480, height: 640 });
  const requests = watchAudioRequests(page);
  await observeAudio(page);
  const errors = await openGame(page);
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  await openRewards(page);
  await age(page, 3);
  const initial = await saved(page), played = [];
  for (const pageIndex of [1, 2]) {
    if (pageIndex === 2) await activateGrowthControl(page, 'AgeWordNext');
    const view = await growthView(page);
    expect(view.catalog.page).toBe(pageIndex);
    const id = view.catalog.visible_word_ids.find(id => words.some(word => word.id === id && word.image));
    const word = words.find(item => item.id === id);
    expect(word.image).toBeTruthy();
    const from = await page.evaluate(() => window.audioObservation.playbacks.length);
    await activateGrowthControl(page, `AgeWord_${id}`);
    await expect(page.locator('#game-status')).toContainText(word.text);
    played.push({ id, sound: available ? await expectRecording(page, from, word.audio) : null });
  }
  await page.screenshot({ path: info.outputPath('growth-word-catalog-page-two.png'), scale: 'css' });
  await activateGrowthControl(page, 'AgeWordPrevious');
  expect((await growthView(page)).catalog.page).toBe(1);
  expect(await saved(page), 'Browsing and word pronunciation never count as attempts').toBe(initial);
  expect(requests, 'Word recordings remain inside the game pack').toEqual([]);
  expect(errors).toEqual([]);
  await info.attach('growth-catalog-audio.json', { body: JSON.stringify(played), contentType: 'application/json' });
});
