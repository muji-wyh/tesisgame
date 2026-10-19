const { test, expect } = require('@playwright/test');
const { enterGame, metrics, rendered, libraryControl, activateLibraryControl, tap } = require('./game-ui.cjs');
const catalog = require('../../data/professional/catalog.json');
const themes = require('../../data/professional/themes.json').profiles;

async function openPaths(page) {
  const errors = [], media = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => {
    if (/\/(?:vocabulary-.+\.pck\.br|professional-media\/)/.test(request.url())) media.push(request.url());
  });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page, { home: true });
  await expect.poll(async () => (await metrics(page)).library.learning.screen).toBe('paths');
  return { errors, media };
}

async function search(page, text) {
  const control = await libraryControl(page, 'CareerSearch');
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  if (text) await page.keyboard.insertText(text);
  await expect(page.locator('input:focus')).toHaveValue(text);
  await rendered(page);
}

test('both paths and all twenty searchable careers are discoverable before media downloads', async ({ page }, info) => {
  test.setTimeout(240000);
  const observed = await openPaths(page);
  for (const size of [{ width: 320, height: 568 }, { width: 390, height: 844 },
    { width: 844, height: 390 }, { width: 1280, height: 800 }]) {
    await page.setViewportSize(size);
    await rendered(page);
    for (const name of ['GrowthPath', 'ProfessionalPath']) {
      const item = await libraryControl(page, name);
      const bounds = await metrics(page);
      expect(item.rect[2] * bounds.scale).toBeGreaterThanOrEqual(43);
      expect(item.rect[3] * bounds.scale).toBeGreaterThanOrEqual(43);
    }
    await page.screenshot({ path: info.outputPath(`paths-${size.width}x${size.height}.png`), scale: 'css' });
  }
  await activateLibraryControl(page, 'ProfessionalPath');
  expect((await metrics(page)).library.learning.visible_rows).toBe(20);
  for (const course of catalog.courses) {
    await search(page, course.title);
    await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(1);
    expect((await metrics(page)).library.controls.some(item => item.name === `Career_${course.id}`)).toBe(true);
  }
  await search(page, 'unmatched-career-fixture');
  await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(0);
  await search(page, '');
  await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(20);
  expect(observed.media, 'Browsing metadata never downloads Growth or Professional media').toEqual([]);
  expect(observed.errors).toEqual([]);
});

test('clearing an unmatched career query and deleting the final character restore all careers', async ({ page }) => {
  test.setTimeout(150000);
  const observed = await openPaths(page);
  await activateLibraryControl(page, 'ProfessionalPath');
  await search(page, 'unmatched-career-fixture');
  await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(0);

  // Use the real focused HTML input and keyboard deletion, so the engine's
  // empty replacement must notify the native selector without a manual signal.
  await search(page, '');
  await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(20);
  await search(page, 'IT');
  await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(1);
  expect((await metrics(page)).library.controls.some(item => item.name === 'Career_it_support')).toBe(true);
  await page.keyboard.press('End');
  await page.keyboard.press('Backspace');
  await expect(page.locator('input:focus')).toHaveValue('I');
  await page.keyboard.press('Backspace');
  await expect(page.locator('input:focus')).toHaveValue('');
  await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(20);
  await page.keyboard.press('Backspace');
  await rendered(page);
  expect((await metrics(page)).library.learning.visible_rows).toBe(20);
  expect(observed.media).toEqual([]);
  expect(observed.errors).toEqual([]);
});

test('career selection applies its automatic palette and pending modules cannot start a game', async ({ page }, info) => {
  test.setTimeout(420000);
  const observed = await openPaths(page);
  await activateLibraryControl(page, 'ProfessionalPath');
  for (const id of ['retail', 'software_data', 'nursing', 'caregiving', 'food_service', 'office_admin', 'hr_recruitment']) {
    const course = catalog.courses.find(item => item.id === id);
    await search(page, course.title);
    await activateLibraryControl(page, `Career_${id}`);
    const theme = themes.find(item => item.id === course.theme_id);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', theme.palette.background.toLowerCase());
    expect((await metrics(page)).library.learning.visible_rows).toBe(10);
    await activateLibraryControl(page, 'Module_module03');
    const current = (await metrics(page)).library;
    expect(current.learning.selection.course_id).toBe(id);
    expect(current.learning.continue_enabled).toBe(false);
    expect(current.controls.filter(item => item.name.startsWith('Mode_')).every(item => item.disabled)).toBe(true);
    await page.screenshot({ path: info.outputPath(`${id}-pending-module.png`), scale: 'css' });
    await activateLibraryControl(page, 'ChangeCareer');
  }
  expect(observed.media, 'Browsing careers and pending modules requests metadata only').toEqual([]);
  await activateLibraryControl(page, 'ChangeLearningPath');
  await activateLibraryControl(page, 'GrowthPath');
  const growth = themes.find(item => item.id === 'growth_garden');
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', growth.palette.background.toLowerCase());
  expect((await metrics(page)).library.learning.selection.track).toBe('growth');
  await expect.poll(() => observed.media.length, { message: 'Selecting Growth requests its first-use vocabulary' }).toBeGreaterThan(0);
  expect(observed.media.every(url => /\/vocabulary-/.test(url))).toBe(true);
  expect(observed.errors).toEqual([]);
});

test('touch search uses the browser text-input bridge and survives a reduced visible viewport', async ({ page }, info) => {
  test.setTimeout(120000);
  const observed = await openPaths(page);
  await activateLibraryControl(page, 'ProfessionalPath');
  await search(page, 'IT');
  await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(1);
  expect((await metrics(page)).library.controls.some(item => item.name === 'Career_it_support')).toBe(true);
  const input = page.locator('input:focus');
  await expect(input).toBeEnabled();
  expect(await input.evaluate(element => ({ tag: element.tagName, type: element.type })))
    .toEqual({ tag: 'INPUT', type: 'text' });

  // Exercise real Godot/browser input synchronization. A viewport reduction is
  // a layout stress case; desktop device emulation does not display an OS keyboard.
  const original = page.viewportSize();
  await page.setViewportSize({ width: original.width, height: Math.max(320, Math.floor(original.height * 0.6)) });
  await rendered(page);
  await search(page, 'HR');
  await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(1);
  expect((await metrics(page)).library.controls.some(item => item.name === 'Career_hr_recruitment')).toBe(true);
  await page.screenshot({ path: info.outputPath('career-search-reduced-viewport.png'), scale: 'css' });

  await page.setViewportSize(original);
  await rendered(page);
  await activateLibraryControl(page, 'Career_hr_recruitment');
  await expect(page.locator('input:focus')).toHaveCount(0);
  expect((await metrics(page)).library.learning.course_id).toBe('hr_recruitment');
  expect((await metrics(page)).library.learning.visible_rows).toBe(10);
  await activateLibraryControl(page, 'ChangeCareer');
  await search(page, 'nursing');
  await expect.poll(async () => (await metrics(page)).library.learning.visible_rows).toBe(1);
  expect(observed.media).toEqual([]);
  expect(observed.errors).toEqual([]);
});
