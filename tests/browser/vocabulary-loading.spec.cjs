const { test, expect } = require('@playwright/test');
const words = require('../../words.json');
const phrases = require('../../phrases.json');
const { enterGame, openGame, openRewards, growthView, growthState, seedGrowth,
  activateGrowthControl, ageControl, tap, rendered, matchWords, chooseMode, metrics } = require('./game-ui.cjs');

const PACK = /\/vocabulary-(3|4|5|6|7|8|9|10|11|12)-[a-f0-9]{16,64}\.pck\.br(?:\?|$)/;
const SHARED_PACK = /\/vocabulary-shared-((?:[3-9]|1[0-2])(?:-(?:[3-9]|1[0-2]))+)-[a-f0-9]{16,64}\.pck\.br(?:\?|$)/;

function observePacks(page) {
  const ages = [], shared = [], unknownPacks = [], looseMedia = [], errors = [];
  page.on('request', request => {
    const url = new URL(request.url()), match = request.url().match(PACK), dependency = request.url().match(SHARED_PACK);
    if (match) ages.push(Number(match[1]));
    if (dependency) shared.push({ file: url.pathname.split('/').pop(), ages: dependency[1].split('-').map(Number) });
    if (/\/vocabulary-.*\.pck\.br$/.test(url.pathname) && !match && !dependency) unknownPacks.push(url.pathname);
    if (/\/assets\/(?:images\/(?:word-library|word-motion)\/|audio\/voice\/(?:word|phrase)-)/.test(url.pathname)) {
      looseMedia.push(url.pathname);
    }
  });
  page.on('pageerror', error => errors.push(error.message));
  return { ages, shared, unknownPacks, looseMedia, errors };
}

function expectScopedDependencies(observed, requestedAges) {
  expect(observed.shared.length, 'The real shared dependencies are requested').toBeGreaterThan(0);
  for (const pack of observed.shared) {
    expect(pack.ages.some(age => requestedAges.includes(age)),
      `${pack.file} serves a requested cohort rather than unrelated future words`).toBe(true);
  }
  const sharedFiles = observed.shared.map(pack => pack.file);
  expect(new Set(sharedFiles).size, 'Shared media is fetched once across startup, tabs and retries').toBe(sharedFiles.length);
  expect(observed.unknownPacks, 'Every vocabulary request has a specific age or consumer set').toEqual([]);
}
function hold() {
  let release;
  const wait = new Promise(resolve => { release = resolve; });
  return { wait, release };
}

async function loading(page) {
  return (await growthView(page)).vocabulary;
}

async function selectAge(page, age) {
  const rect = await ageControl(page, age);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await expect.poll(async () => String((await growthView(page)).catalog?.age_band)).toBe(String(age));
}

async function expectCatalogReady(page, age) {
  await expect.poll(async () => (await growthView(page)).catalog?.loading_state,
    { timeout: 30000 }).toBe('ready');
  const catalog = (await growthView(page)).catalog;
  expect(catalog.age_band).toBe(String(age));
  expect(catalog.word_count).toBe(words.filter(word => word.min_age === age).length);
}

async function captureNotebookLoading(page, info, state) {
  const original = page.viewportSize();
  try {
    for (const size of [{ width: 1366, height: 768 }, { width: 320, height: 568 }, { width: 568, height: 320 }]) {
      await page.setViewportSize(size);
      await rendered(page);
      const view = await growthView(page), bounds = await metrics(page);
      expect(view.catalog.loading_state).toBe(state);
      expect(view.catalog.visible_word_ids).toEqual([]);
      for (const name of state === 'failed' ? ['GrowthBack', 'AgeVocabularyRetry'] : ['GrowthBack']) {
        const control = view.controls.find(item => item.name === name && item.visible);
        expect(control, `${name} is visible at ${size.width} x ${size.height}`).toBeTruthy();
        expect(control.disabled).toBe(false);
        const [x, y, width, height] = control.rect;
        expect(x).toBeGreaterThanOrEqual(-1);
        expect(y).toBeGreaterThanOrEqual(-1);
        expect(x + width).toBeLessThanOrEqual(bounds.width + 1);
        expect(y + height).toBeLessThanOrEqual(bounds.height + 1);
        expect(width * bounds.scale).toBeGreaterThanOrEqual(43);
        expect(height * bounds.scale).toBeGreaterThanOrEqual(43);
      }
      await page.screenshot({ path: info.outputPath(`notebook-${state}-${size.width}x${size.height}.png`), scale: 'css' });
    }
  } finally {
    await page.setViewportSize(original);
    await rendered(page);
  }
}
test('a fresh visit fetches only the current age and waits for its media before play', async ({ page }, info) => {
  test.setTimeout(150000);
  const observed = observePacks(page), firstAge = hold();
  await page.route(/\/vocabulary-3-[a-f0-9]+\.pck\.br(?:\?|$)/, async route => {
    await firstAge.wait;
    await route.continue();
  });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  try {
    await page.goto('/');
    await expect.poll(() => observed.ages, { timeout: 60000 }).toEqual([3]);
    await expect.poll(async () => (await loading(page))?.states?.['3']?.state).toBe('loading');
    expect((await loading(page)).ready).toBe(false);
    expect((await loading(page)).pending_age).toBe(3);
    expect((await loading(page)).age).toBe(3);
    expect(await page.locator('body').getAttribute('data-engine-ready')).not.toBe('true');
    await page.screenshot({ path: info.outputPath('startup-vocabulary-loading.png'), scale: 'css' });
    firstAge.release();
    await enterGame(page);
    await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
    expect((await loading(page)).ready).toBe(true);
    expect((await growthState(page)).learning_age).toBe(3);
    expect((await growthState(page)).age).toBe(0);
    expect((await growthState(page)).level).toBe(0);
    expect((await matchWords(page)).every(text => words.some(word => word.text === text && word.min_age === 3))).toBe(true);
    await openRewards(page);
    await expectCatalogReady(page, 3);
    await activateGrowthControl(page, 'GrowthBack');
    expect(observed.ages).toEqual([3]);
    expectScopedDependencies(observed, [3]);
    expect(observed.looseMedia).toEqual([]);
    expect(observed.errors).toEqual([]);
    await info.attach('startup-vocabulary-requests.json', {
      body: JSON.stringify({ ages: observed.ages, shared: observed.shared, state: await loading(page) }), contentType: 'application/json'
    });
  } finally {
    firstAge.release();
  }
});

test('notebook loading follows the selected age, retries failures, and ignores stale completions after Back', async ({ page }, info) => {
  test.setTimeout(180000);
  const observed = observePacks(page), ageFour = hold(), ageSix = hold();
  let failedFive = false;
  await page.route(/\/vocabulary-4-[a-f0-9]+\.pck\.br(?:\?|$)/, async route => {
    await ageFour.wait;
    await route.continue();
  });
  await page.route(/\/vocabulary-5-[a-f0-9]+\.pck\.br(?:\?|$)/, async route => {
    if (!failedFive) {
      failedFive = true;
      await route.fulfill({ status: 503, body: 'Temporarily unavailable' });
    } else await route.continue();
  });
  await page.route(/\/vocabulary-6-[a-f0-9]+\.pck\.br(?:\?|$)/, async route => {
    await ageSix.wait;
    await route.continue();
  });
  try {
    await openGame(page);
    expect(observed.ages).toEqual([3]);
    expectScopedDependencies(observed, [3]);
    const initialSharedCount = observed.shared.length;
    const initial = await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'));
    await openRewards(page);
    await selectAge(page, 4);
    await expect.poll(async () => (await growthView(page)).catalog?.loading_state).toBe('loading');
    expect((await growthView(page)).catalog.visible_word_ids).toEqual([]);
    await captureNotebookLoading(page, info, 'loading');
    await selectAge(page, 5);
    await expect.poll(async () => (await growthView(page)).catalog?.loading_state).toBe('failed');
    await captureNotebookLoading(page, info, 'failed');
    ageFour.release();
    await expect.poll(async () => (await loading(page)).states?.['4']?.state, { timeout: 30000 }).toBe('ready');
    expect((await growthView(page)).catalog.age_band).toBe('5');
    expect((await growthView(page)).catalog.loading_state).toBe('failed');
    await activateGrowthControl(page, 'AgeVocabularyRetry');
    await expectCatalogReady(page, 5);
    expect(observed.ages.filter(age => age === 5)).toHaveLength(2);
    for (const pack of observed.shared.slice(initialSharedCount)) {
      expect(pack.ages.some(age => age === 4 || age === 5), 'New notebook dependencies serve Age 4 or Age 5').toBe(true);
    }
    await selectAge(page, 4);
    await expectCatalogReady(page, 4);
    expect(observed.ages.filter(age => age === 4)).toHaveLength(1);
    const beforeSix = observed.shared.length;
    await selectAge(page, 6);
    await expect.poll(async () => (await growthView(page)).catalog?.loading_state).toBe('loading');
    await activateGrowthControl(page, 'GrowthBack');
    ageSix.release();
    await expect.poll(async () => (await loading(page)).states?.['6']?.state, { timeout: 30000 }).toBe('ready');
    expect((await growthView(page)).visible).toBe(false);
    for (const pack of observed.shared.slice(beforeSix)) expect(pack.ages).toContain(6);
    await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
    expect(await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'))).toBe(initial);
    expect(observed.ages).toEqual([3, 4, 5, 5, 6]);
    expectScopedDependencies(observed, [3, 4, 5, 6]);
    expect(observed.looseMedia).toEqual([]);
    expect(observed.errors).toEqual([]);
    await info.attach('notebook-vocabulary-requests.json', {
      body: JSON.stringify({ ages: observed.ages, shared: observed.shared, state: await loading(page) }), contentType: 'application/json'
    });
  } finally {
    ageFour.release();
    ageSix.release();
  }
});

for (const age of [4, 12]) test(`a returning learner fetches only learning age ${age} and its phrase prerequisites`, async ({ page }) => {
  test.setTimeout(150000);
  const observed = observePacks(page);
  await seedGrowth(page, age);
  const errors = await openGame(page);
  expect((await growthState(page)).age).toBe(age - 1);
  expect((await growthState(page)).learning_age).toBe(age);
  expect(observed.ages).toEqual([age]);
  expectScopedDependencies(observed, [age]);
  expect((await matchWords(page)).every(text => words.some(word => word.text === text && word.min_age === age))).toBe(true);
  await chooseMode(page, 'phrase');
  await expect.poll(async () => page.locator('#game-status').evaluate(element =>
    JSON.parse(element.dataset.phrase || '{}').visible)).toBe(true);
  await rendered(page);
  const phrase = await page.locator('#game-status').evaluate(element => JSON.parse(element.dataset.phrase));
  expect(phrases.find(item => item.id === phrase.id)?.min_age, 'The phrase question belongs to the current learning age').toBe(age);
  expect(phrase.options.length).toBeGreaterThan(0);
  for (const option of phrase.options) {
    const word = words.find(word => (word.display_text || word.text) === option.text);
    expect(word, `${option.text} belongs to the vocabulary`).toBeTruthy();
    if (word.image) expect(option.icon, `${option.text} has mounted candidate artwork`).toBeTruthy();
    else expect(option.icon, `${option.text} is deliberately taught in phrase context`).toBe('');
  }
  // Some valid phrases, such as "put it here", contain only contextual words.
  // Each candidate above is checked against its own artwork requirement.
  expect(phrase.listen.visible).toBe(true);
  expect(phrase.listen.disabled).toBe(false);
  expect(observed.ages).toEqual([age]);
  expectScopedDependencies(observed, [age]);
  expect(observed.looseMedia).toEqual([]);
  expect(errors).toEqual([]);
  expect(observed.errors).toEqual([]);
});
