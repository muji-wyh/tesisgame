const { test, expect } = require('@playwright/test');
const {
  metrics, tap, rendered, openGame, enterGame, activateLibraryControl, libraryControl,
  openRewards, openModeMenu, collectionHeaderRect, growthView,
  contentBounds, pipHeaderRect
} = require('./game-ui.cjs');

const PRESENTATION_KEY = 'pipAndWords.presentation.v1';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const themes = require('../../data/professional/themes.json').profiles;
async function record(page, key = PRESENTATION_KEY) {
  return page.evaluate(key => localStorage.getItem(key), key);
}

function cssClip(bounds, rect, padding = 0) {
  return {
    x: bounds.x + rect.x * bounds.scale - padding,
    y: bounds.y + rect.y * bounds.scale - padding,
    width: rect.width * bounds.scale + padding * 2,
    height: rect.height * bounds.scale + padding * 2
  };
}

async function closeRewards(page) {
  const back = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await expect.poll(async () => (await growthView(page)).visible).toBe(false);
  await rendered(page);
}

async function settled(page) {
  // The happy selection reaction and any short pronunciation finish before a
  // wardrobe comparison. Reduced motion then leaves the same resting pose.
  await page.mouse.move(0, 0);
  await page.waitForTimeout(1800);
  await rendered(page);
}

async function seedHistoricalTheme(page) {
  await page.addInitScript(key => {
    if (localStorage.getItem(key) === null) localStorage.setItem(key, JSON.stringify({ muted: false, preferred_theme: 'candy' }));
  }, PRESENTATION_KEY);
}

async function expectPalette(page, id) {
  const palette = themes.find(profile => profile.id === id).palette;
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', palette.background.toLowerCase());
  await expect.poll(() => page.locator('#game').evaluate(element => element.style.getPropertyValue('--voice-accent').toLowerCase()))
    .toBe(palette.accent.toLowerCase());
}

async function foregroundDifference(page, first, second, firstColor, secondColor) {
  return page.evaluate(async ({ sources, colors }) => {
    const pictures = await Promise.all(sources.map(async source => {
      const image = new Image();
      image.src = `data:image/png;base64,${source}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      return { width: image.width, height: image.height,
        data: context.getImageData(0, 0, image.width, image.height).data };
    }));
    if (pictures[0].width !== pictures[1].width || pictures[0].height !== pictures[1].height) {
      throw new Error('Wardrobe comparison requires identically sized Pip crops.');
    }
    const backgrounds = colors.map(color => [1, 3, 5].map(start => parseInt(color.slice(start, start + 2), 16)));
    const distance = (data, offset, other) => Math.sqrt([0, 1, 2]
      .reduce((sum, channel) => sum + (data[offset + channel] - other[channel]) ** 2, 0));
    let commonForeground = 0, changed = 0;
    for (let index = 0; index < pictures[0].data.length; index += 4) {
      const a = pictures[0].data, b = pictures[1].data;
      // A different page tint must never count as a different costume. Compare
      // only pixels that belong to Pip in both images, excluding each backdrop.
      if (distance(a, index, backgrounds[0]) <= 60 || distance(b, index, backgrounds[1]) <= 60) continue;
      commonForeground++;
      if (distance(a, index, [b[index], b[index + 1], b[index + 2]]) > 55) changed++;
    }
    return { commonForeground, changed, fraction: changed / Math.max(1, commonForeground) };
  }, { sources: [first, second].map(buffer => buffer.toString('base64')), colors: [firstColor, secondColor] });
}

test('career previews preserve Pip earned appearance in the header and growth notebook', async ({ page }, testInfo) => {
  test.setTimeout(240000);
  await page.setViewportSize({ width: 390, height: 1560 });
  await seedHistoricalTheme(page);
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  await expectPalette(page, 'growth_garden');
  const originalMedals = await record(page, MEDAL_KEY);
  const originalSelection = await page.locator('#selection-status').textContent();
  const originalAge = (await metrics(page)).library.pip_age;
  await settled(page);
  const baselineBounds = await metrics(page);
  const baseline = await page.screenshot({ path: testInfo.outputPath('growth-pip-original.png'),
    clip: cssClip(baselineBounds, pipHeaderRect(baselineBounds), 2), scale: 'css' });
  const comparisons = [], background = themes.find(profile => profile.id === 'growth_garden').palette.background;
  for (const course of ['caregiving', 'retail', 'food_service']) {
    await openModeMenu(page);
    await activateLibraryControl(page, 'ChangeLearningPath');
    await activateLibraryControl(page, 'ProfessionalPath');
    await activateLibraryControl(page, `Career_${course}`);
    await expectPalette(page, `professional_${course}`);
    expect((await metrics(page)).library.learning).toMatchObject({ screen: 'modules', course_id: course });
    expect((await metrics(page)).library.pip_age).toBe(originalAge);
    expect(JSON.parse(await record(page)).preferred_theme).toBe('candy');
    await activateLibraryControl(page, 'ContinueCurrentRound');
    await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
    await expectPalette(page, 'growth_garden');
    await settled(page);
    const bounds = await metrics(page), content = contentBounds(bounds);
    const clip = cssClip(bounds, pipHeaderRect(bounds), 2);
    const pip = await page.screenshot({ path: testInfo.outputPath(`growth-pip-after-${course}.png`), clip, scale: 'css' });
    await page.waitForTimeout(180);
    expect((await page.screenshot({ clip, scale: 'css' })).equals(pip), `${course}: the compared Pip has settled.`).toBe(true);
    const difference = await foregroundDifference(page, baseline, pip, background, background);
    comparisons.push({ course, ...difference });
    expect(difference.commonForeground, 'The crop contains the actual mascot').toBeGreaterThan(100);
    expect(difference.fraction, 'Browsing a career keeps the earned Pip appearance').toBeLessThan(0.02);
    await page.screenshot({ path: testInfo.outputPath(`growth-header-after-${course}.png`), scale: 'css',
      clip: cssClip(bounds, { x: content.x, y: content.padding, width: content.width, height: content.header }) });
    await openRewards(page);
    await settled(page);
    await page.screenshot({ path: testInfo.outputPath(`growth-notebook-after-${course}.png`), fullPage: true, scale: 'css' });
    await closeRewards(page);
    expect(await record(page, MEDAL_KEY), 'Career browsing never awards or removes medal pieces.').toBe(originalMedals);
    expect(await page.locator('#selection-status').textContent()).toBe(originalSelection);
  }
  await testInfo.attach('growth-pip-foreground-comparisons', {
    body: JSON.stringify(comparisons, null, 2), contentType: 'application/json'
  });
  expect(errors).toEqual([]);
});

test('compact path and module choices preserve historical preferences and chest reservation on reload', async ({ page }, testInfo) => {
  test.setTimeout(150000);
  await page.setViewportSize({ width: 320, height: 568 });
  await seedHistoricalTheme(page);
  await page.addInitScript(key => {
    document.addEventListener('DOMContentLoaded', () => {
      window.initialWardrobeTheme = { theme: wordBuddiesHost.loadingTheme(),
        saved: JSON.parse(localStorage.getItem(key) || '{}').preferred_theme };
    });
  }, PRESENTATION_KEY);
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  await openModeMenu(page);
  const originalMedals = await record(page, MEDAL_KEY);
  const viewport = page.viewportSize();
  async function checkTouchTarget(name) {
    const control = await libraryControl(page, name), bounds = await metrics(page);
    const [x, y, width, height] = control.rect, rect = cssClip(bounds, { x, y, width, height });
    expect(rect.width, `${name}: minimum touch width`).toBeGreaterThanOrEqual(44 - 0.01);
    expect(rect.height, `${name}: minimum touch height`).toBeGreaterThanOrEqual(44 - 0.01);
    expect(rect.x, `${name}: left edge`).toBeGreaterThanOrEqual(-0.01);
    expect(rect.y, `${name}: top edge`).toBeGreaterThanOrEqual(-0.01);
    expect(rect.x + rect.width, `${name}: right edge`).toBeLessThanOrEqual(viewport.width + 0.01);
    expect(rect.y + rect.height, `${name}: bottom edge`).toBeLessThanOrEqual(viewport.height + 0.01);
  }
  await activateLibraryControl(page, 'ChangeLearningPath');
  for (const name of ['GrowthPath', 'ProfessionalPath']) await checkTouchTarget(name);
  await activateLibraryControl(page, 'ProfessionalPath');
  await checkTouchTarget('Career_retail');
  await activateLibraryControl(page, 'Career_retail');
  await expectPalette(page, 'professional_retail');
  for (let index = 1; index <= 10; index++) {
    await checkTouchTarget(`Module_module${String(index).padStart(2, '0')}`);
  }
  await activateLibraryControl(page, 'Module_module03');
  expect((await metrics(page)).library.learning.continue_enabled).toBe(false);
  expect(JSON.parse(await record(page)).preferred_theme).toBe('candy');
  await page.screenshot({ path: testInfo.outputPath('retail-module-summary-320.png'), scale: 'css' });
  expect(await record(page, MEDAL_KEY)).toBe(originalMedals);
  await activateLibraryControl(page, 'ContinueCurrentRound');
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
  await expectPalette(page, 'growth_garden');
  const saved = await record(page);
  await page.reload();
  expect(await page.evaluate(() => initialWardrobeTheme)).toEqual({ theme: 'spring', saved: 'candy' });
  expect(await record(page)).toBe(saved);
  await expect(page.locator('#enter-game')).toBeEnabled({ timeout: 60000 });
  await expect(page.locator('#loading-themes')).toBeHidden();
  await enterGame(page);
  await expectPalette(page, 'growth_garden');
  const reloaded = await record(page);
  expect(JSON.parse(reloaded).preferred_theme).toBe(JSON.parse(saved).preferred_theme);
  const reloadedMedals = await record(page, MEDAL_KEY);
  const roundIds = text => [...text.matchAll(/"id": "(round-[^"]+)"/g)].map(match => match[1]);
  const previousIds = roundIds(originalMedals), freshIds = roundIds(reloadedMedals);
  expect(previousIds).toHaveLength(1);
  expect(freshIds).toHaveLength(1);
  expect(freshIds[0], 'Reload starts a new Match round without rerolling its reserved chest chance').not.toBe(previousIds[0]);
  expect(reloadedMedals.replace(freshIds[0], previousIds[0]),
    'Every reward field, count and claim remains identical apart from the fresh round ID').toBe(originalMedals);
  await settled(page);
  await page.screenshot({ path: testInfo.outputPath('growth-pip-reloaded-320.png'), scale: 'css' });
  expect(errors).toEqual([]);
});
