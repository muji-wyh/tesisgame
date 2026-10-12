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
  await expect.poll(async () => (await growthView(page)).catalog?.loading_state, { timeout: 30000 }).toBe('ready');
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
    expect(view.notice).toContain(id === 3 ? '3 correct answers' : 'Preview only');
    expect((await growthState(page)).level).toBe(0);
    expect((await growthState(page)).age).toBe(0);
    expect((await growthState(page)).learning_age).toBe(3);
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
  expect((await growthState(page)).level).toBe(0);
  expect((await growthState(page)).age).toBe(0);
  expect(errors).toEqual([]);
});

test('age catalogues continuously scroll through every word with artwork and bundled pronunciations', async ({ page, browserName }, info) => {
  test.setTimeout(180000);
  await page.setViewportSize(info.project.use.isMobile ? { width: 320, height: 568 } : { width: 1473, height: 1175 });
  const requests = watchAudioRequests(page);
  await observeAudio(page);
  const errors = await openGame(page);
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  await openRewards(page);
  await age(page, 3);
  const initial = await saved(page), played = [];
  const cohort = words.filter(word => word.min_age === 3);
  let view = await growthView(page);
  const ids = view.catalog.visible_word_ids;
  expect(ids).toHaveLength(cohort.length);
  expect(new Set(ids).size).toBe(cohort.length);
  expect(ids).toEqual(expect.arrayContaining(cohort.map(word => word.id)));
  expect(view.catalog).not.toHaveProperty('page');
  expect(view.catalog).not.toHaveProperty('page_count');
  expect(view.controls.some(control => ['AgeWordPrevious', 'AgeWordNext', 'AgeWordPage', 'AgeWordPages'].includes(control.name))).toBe(false);
  expect(view.catalog.scroll_max).toBeGreaterThan(0);
  await expect.poll(async () => (await growthView(page)).catalog.loaded_image_count).toBeGreaterThan(0);
  expect((await growthView(page)).catalog.loaded_image_count,
    'Offscreen artwork stays lazy even though every word has a card').toBeLessThan(cohort.filter(word => word.image).length);
  await page.screenshot({ path: info.outputPath('growth-word-catalog-top.png'), scale: 'css' });

  async function hear(id) {
    const word = words.find(item => item.id === id);
    const from = await page.evaluate(() => window.audioObservation.playbacks.length);
    await activateGrowthControl(page, `AgeWord_${id}`);
    await expect(page.locator('#game-status')).toContainText(word.text);
    await expect.poll(async () => (await growthView(page)).catalog.meaning).toContain(word.text[0].toUpperCase() + word.text.slice(1));
    played.push({ id, sound: available ? await expectRecording(page, from, word.audio) : null });
  }

  const first = ids.findIndex(id => cohort.some(word => word.id === id && word.image));
  await hear(ids[first]);
  view = await growthView(page);
  const bounds = await metrics(page), [left, top, width, height] = view.catalog.viewport_rect;
  const x = bounds.x + (left + width / 2) * bounds.scale;
  const y = bounds.y + (top + height / 2) * bounds.scale;
  if (browserName === 'webkit' && info.project.use.isMobile) {
    const travel = height * bounds.scale * 0.55;
    await page.mouse.move(x, y + travel / 2);
    await page.mouse.down();
    try {
      await page.mouse.move(x, y - travel / 2, { steps: 8 });
      await rendered(page);
      await page.waitForTimeout(160);
    } finally {
      await page.mouse.up();
    }
  } else {
    await page.mouse.move(x, y);
    await page.mouse.wheel(0, 600);
  }
  await expect.poll(async () => (await growthView(page)).catalog.scroll_offset,
    { message: 'A real scroll gesture moves the continuous vocabulary list' }).toBeGreaterThan(view.catalog.scroll_offset);
  expect((await growthView(page)).catalog.meaning, 'Scrolling does not activate a word').toBe(view.catalog.meaning);

  async function tabTo(from, to) {
    for (let index = from; index < to; index++) await page.locator('#canvas').press('Tab', { delay: 20 });
    await expect.poll(async () => (await growthView(page)).controls.find(control => control.name === `AgeWord_${ids[to]}`)?.focused,
      { message: `Keyboard navigation reaches word ${to + 1} without pagination` }).toBe(true);
    const current = await growthView(page);
    const control = current.controls.find(item => item.name === `AgeWord_${ids[to]}`);
    const [cx, cy, cw, ch] = control.rect, [vx, vy, vw, vh] = current.catalog.viewport_rect;
    expect(cx).toBeGreaterThanOrEqual(vx - 1);
    expect(cx + cw).toBeLessThanOrEqual(vx + vw + 1);
    expect(cy).toBeGreaterThanOrEqual(vy - 1);
    expect(cy + ch).toBeLessThanOrEqual(vy + vh + 1);
    expect(current.catalog.visible_word_ids).toEqual(ids);
  }

  // Cross the former 60-word boundary with one Tab, then continue to the last word.
  expect(ids.length).toBeGreaterThan(60);
  await tabTo(first, 59);
  await tabTo(59, 60);
  expect(cohort.find(word => word.id === ids[60]).image).toBeTruthy();
  await hear(ids[60]);
  await tabTo(60, ids.length - 1);
  await hear(ids.at(-1));
  await page.screenshot({ path: info.outputPath('growth-word-catalog-bottom.png'), scale: 'css' });
  expect(await saved(page), 'Browsing and word pronunciation never count as attempts').toBe(initial);
  expect(requests, 'Word recordings remain inside the game pack').toEqual([]);
  expect(errors).toEqual([]);
  await info.attach('growth-catalog-audio.json', { body: JSON.stringify(played), contentType: 'application/json' });
});
