const { test, expect } = require('@playwright/test');
const { enterGame, metrics, rendered, activateLibraryControl, growthView, growthState,
  growthControl, activateGrowthControl, tap } = require('./game-ui.cjs');
const catalog = require('../../data/professional/catalog.json');

async function openLibrary(page) {
  const errors = [], professionalMedia = [], vocabularyPacks = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text());
  });
  page.on('request', request => {
    if (/\/professional(?:-media)?\//.test(request.url())) professionalMedia.push(request.url());
    if (/\/vocabulary-[^/]+\.pck\.br(?:\?|$)/.test(request.url())) vocabularyPacks.push(request.url());
  });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page, { home: true });
  await expect.poll(async () => (await metrics(page)).library.brand).toBe('Grow with Pip');
  expect((await metrics(page)).library.vocabulary.kind).toBe('everyday');
  expect((await metrics(page)).library.controls.filter(item => item.name.startsWith('Mode_')).length).toBe(6);
  await activateLibraryControl(page, 'HomeVocabulary');
  await expect.poll(async () => (await growthView(page)).visible).toBe(true);
  // The initial Everyday library intentionally loads its first-use word pack.
  await expect.poll(async () => (await growthView(page)).catalog?.loading_state, { timeout: 120000 }).toBe('ready');
  return { errors, professionalMedia, vocabularyPacks, initialVocabularyPacks: [...vocabularyPacks] };
}

function expectMetadataOnly(observed) {
  expect(observed.professionalMedia, 'Career browsing and selection do not request professional media').toEqual([]);
  expect(observed.vocabularyPacks, 'Career browsing does not request additional Everyday word packs').toEqual(observed.initialVocabularyPacks);
}

async function openCareers(page) {
  await activateGrowthControl(page, 'LibraryProfessional');
  const state = await growthView(page);
  if (state.library.screen !== 'courses') await activateGrowthControl(page, 'ChangeCareer');
  await expect.poll(async () => (await growthView(page)).library.screen).toBe('courses');
}

async function search(page, text) {
  const control = await growthControl(page, 'CareerSearch');
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  if (text) await page.keyboard.insertText(text);
  await expect(page.locator('input:focus')).toHaveValue(text);
  await rendered(page);
}

test('the unified word library exposes everyday words and all twenty careers without career media downloads', async ({ page }, info) => {
  test.setTimeout(600000);
  const observed = await openLibrary(page);
  for (const size of [{ width: 320, height: 568 }, { width: 390, height: 844 },
    { width: 844, height: 390 }, { width: 1280, height: 800 }]) {
    await page.setViewportSize(size);
    await rendered(page);
    for (const name of ['LibraryEveryday', 'LibraryProfessional']) {
      const item = await growthControl(page, name);
      const bounds = await metrics(page);
      expect(item.rect[2] * bounds.scale).toBeGreaterThanOrEqual(43);
      expect(item.rect[3] * bounds.scale).toBeGreaterThanOrEqual(43);
    }
    await page.screenshot({ path: info.outputPath(`library-${size.width}x${size.height}.png`), scale: 'css' });
  }
  await openCareers(page);
  expect((await growthView(page)).library.visible_rows).toBe(20);
  await page.screenshot({ path: info.outputPath('professional-word-library.png'), scale: 'css' });
  expect((await growthView(page)).controls.some(item => ['GrowthPath', 'ProfessionalPath'].includes(item.name))).toBe(false);
  for (const course of catalog.courses) {
    await search(page, course.title);
    await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(1);
    expect((await growthView(page)).controls.some(item => item.name === `Career_${course.id}`)).toBe(true);
  }
  await search(page, 'unmatched-career-fixture');
  await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(0);
  await search(page, '');
  await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(20);
  expectMetadataOnly(observed);
  expect(observed.errors).toEqual([]);
});

test('clearing an unmatched career query and deleting the final character restore all careers', async ({ page }) => {
  test.setTimeout(600000);
  const observed = await openLibrary(page);
  await openCareers(page);
  await search(page, 'unmatched-career-fixture');
  await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(0);
  // Use the actual focused browser input so empty replacement must notify Godot.
  await search(page, '');
  await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(20);
  await search(page, 'IT');
  await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(1);
  expect((await growthView(page)).controls.some(item => item.name === 'Career_it_support')).toBe(true);
  await page.keyboard.press('End');
  await page.keyboard.press('Backspace');
  await expect(page.locator('input:focus')).toHaveValue('I');
  await page.keyboard.press('Backspace');
  await expect(page.locator('input:focus')).toHaveValue('');
  await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(20);
  await page.keyboard.press('Backspace');
  await rendered(page);
  expect((await growthView(page)).library.visible_rows).toBe(20);
  expectMetadataOnly(observed);
  expect(observed.errors).toEqual([]);
});

test('career vocabulary uses the shared Pip Home while preparing modules stay unavailable for play', async ({ page, isMobile }, info) => {
  test.setTimeout(isMobile ? 900000 : 600000);
  const observed = await openLibrary(page);
  const everyday = await growthState(page);
  await openCareers(page);
  await search(page, 'Nursing');
  await activateGrowthControl(page, 'Career_nursing');
  await activateGrowthControl(page, 'Module_module03');
  expect((await metrics(page)).library.vocabulary.kind, 'Browsing alone does not select a career').toBe('everyday');
  await activateGrowthControl(page, 'GrowthBack');
  expect((await metrics(page)).library.vocabulary.kind, 'Back preserves the active vocabulary').toBe('everyday');
  await activateLibraryControl(page, 'HomeVocabulary');
  await openCareers(page);
  for (const id of ['retail', 'software_data', 'nursing', 'caregiving', 'food_service', 'office_admin', 'hr_recruitment']) {
    const course = catalog.courses.find(item => item.id === id);
    await search(page, course.title);
    await activateGrowthControl(page, `Career_${id}`);
    expect((await growthView(page)).library.visible_rows).toBe(10);
    await activateGrowthControl(page, 'Module_module03');
    const selected = await growthView(page);
    expect(selected.library.selection.course_id).toBe(id);
    expect(selected.library.continue_enabled).toBe(true);
    expect(selected.controls.find(item => item.name === 'ContinueLearningPath').text).toBe('Use this vocabulary');
    await activateGrowthControl(page, 'ContinueLearningPath');
    await expect.poll(async () => (await metrics(page)).library.visible).toBe(true);
    const home = (await metrics(page)).library;
    expect(home.brand).toBe('Grow with Pip');
    expect(home.vocabulary.kind).toBe('professional');
    expect(home.vocabulary.title).toBe('Playing professional English');
    expect(home.vocabulary.detail).toContain(course.title);
    expect(home.professional).toMatchObject({ course_id: id, ready: true, level: 0, total: 500 });
    expect(home.hero.title).toBe('Pip · Lv0');
    expect(home.pip_profile).toMatchObject({ course_id: id, level: 0 });
    expect(home.controls.filter(item => item.name.startsWith('Mode_'))).toHaveLength(6);
    expect(home.controls.filter(item => item.name.startsWith('Mode_')).every(item => item.disabled)).toBe(true);
    await page.screenshot({ path: info.outputPath(`${id}-pip-home.png`), scale: 'css' });
    if (id === 'retail') {
      await page.reload();
      await enterGame(page, { home: true });
      await expect.poll(async () => (await metrics(page)).library.vocabulary.selection.course_id).toBe('retail');
      const restored = (await metrics(page)).library;
      expect(restored.vocabulary.selection.module_id).toBe('module03');
      expect(restored.pip_profile).toMatchObject({ course_id: 'retail', level: 0 });
      expect(restored.controls.filter(item => item.name.startsWith('Mode_'))).toHaveLength(6);
      expect(restored.controls.filter(item => item.name.startsWith('Mode_')).every(item => item.disabled)).toBe(true);
    }
    await activateLibraryControl(page, 'HomeVocabulary');
    await openCareers(page);
  }
  expectMetadataOnly(observed);
  await activateGrowthControl(page, 'LibraryEveryday');
  await activateGrowthControl(page, 'PlayEverydayVocabulary');
  const home = (await metrics(page)).library;
  expect(home.vocabulary.kind).toBe('everyday');
  expect(home.pip_profile).toEqual({});
  expect(await growthState(page), 'Career selections preserve everyday learning history').toEqual(everyday);
  // Opening Everyday after the reload intentionally reacquires that word pack.
  expect(observed.professionalMedia).toEqual([]);
  expect(observed.errors).toEqual([]);
});

test('touch career search uses the browser input bridge and survives a reduced visible viewport', async ({ page }, info) => {
  test.setTimeout(600000);
  const observed = await openLibrary(page);
  await openCareers(page);
  await search(page, 'IT');
  await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(1);
  expect((await growthView(page)).controls.some(item => item.name === 'Career_it_support')).toBe(true);
  const input = page.locator('input:focus');
  await expect(input).toBeEnabled();
  expect(await input.evaluate(element => ({ tag: element.tagName, type: element.type })))
    .toEqual({ tag: 'INPUT', type: 'text' });
  // A viewport reduction exercises layout; desktop emulation has no OS keyboard.
  const original = page.viewportSize();
  await page.setViewportSize({ width: original.width, height: Math.max(320, Math.floor(original.height * 0.6)) });
  await rendered(page);
  await search(page, 'HR');
  await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(1);
  expect((await growthView(page)).controls.some(item => item.name === 'Career_hr_recruitment')).toBe(true);
  await page.screenshot({ path: info.outputPath('career-search-reduced-viewport.png'), scale: 'css' });
  await page.setViewportSize(original);
  await rendered(page);
  await activateGrowthControl(page, 'Career_hr_recruitment');
  await expect(page.locator('input:focus')).toHaveCount(0);
  expect((await growthView(page)).library.course_id).toBe('hr_recruitment');
  expect((await growthView(page)).library.visible_rows).toBe(10);
  await activateGrowthControl(page, 'ChangeCareer');
  await search(page, 'nursing');
  await expect.poll(async () => (await growthView(page)).library.visible_rows).toBe(1);
  expectMetadataOnly(observed);
  expect(observed.errors).toEqual([]);
});
