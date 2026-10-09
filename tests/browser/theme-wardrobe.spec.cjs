const { test, expect } = require('@playwright/test');
const {
  THEME_IDS, THEME_COLORS, metrics, tap, rendered, openGame, chooseTheme,
  openRewards, collectionHeaderRect, worldControl, growthView,
  contentBounds, pipHeaderRect
} = require('./game-ui.cjs');

const PRESENTATION_KEY = 'pipAndWords.presentation.v1';
const MEDAL_KEY = 'wordBuddies.medalProgress';
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

test('all eight theme choices give Pip different visible outfits in the header and growth notebook', async ({ page }, testInfo) => {
  // Eight full wardrobe captures need enough time on software WebGL runners.
  test.setTimeout(240000);
  // Keep the growth catalogue and world choices in one visual artifact.
  await page.setViewportSize({ width: 390, height: 1560 });
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  expect(THEME_IDS).toEqual(['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy']);
  expect(THEME_COLORS).toHaveLength(8);
  const originalMedals = await record(page, MEDAL_KEY);
  const originalSelection = await page.locator('#selection-status').textContent();
  const outfits = [];
  for (const [index, theme] of THEME_IDS.entries()) {
    await chooseTheme(page, index);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
    expect(JSON.parse(await record(page)).preferred_theme).toBe(theme);
    await settled(page);
    const bounds = await metrics(page), content = contentBounds(bounds);
    const clip = cssClip(bounds, pipHeaderRect(bounds), 2);
    const pip = await page.screenshot({ path: testInfo.outputPath(`wardrobe-pip-${theme}.png`), clip, scale: 'css' });
    await page.waitForTimeout(180);
    expect((await page.screenshot({ clip, scale: 'css' })).equals(pip), `${theme}: the compared Pip has settled.`).toBe(true);
    outfits.push(pip);
    await page.screenshot({ path: testInfo.outputPath(`wardrobe-header-${theme}.png`), scale: 'css',
      clip: cssClip(bounds, { x: content.x, y: content.padding, width: content.width, height: content.header }) });
    await openRewards(page);
    await settled(page);
    await page.screenshot({ path: testInfo.outputPath(`wardrobe-growth-${theme}.png`), fullPage: true, scale: 'css' });
    await closeRewards(page);
    expect(await record(page, MEDAL_KEY), 'Changing outfits never awards or removes medal pieces.').toBe(originalMedals);
    expect(await page.locator('#selection-status').textContent()).toBe(originalSelection);
  }
  const comparisons = [];
  for (let first = 0; first < outfits.length; first++) {
    for (let second = first + 1; second < outfits.length; second++) {
      const difference = await foregroundDifference(page, outfits[first], outfits[second], THEME_COLORS[first], THEME_COLORS[second]);
      const pair = `${THEME_IDS[first]} / ${THEME_IDS[second]}`;
      comparisons.push({ pair, ...difference });
      expect(difference.commonForeground, `${pair}: the crop contains the actual mascot.`).toBeGreaterThan(100);
      expect(difference.changed, `${pair}: clothing changes pixels on Pip, independent of page tint.`).toBeGreaterThan(8);
      expect(difference.fraction, `${pair}: the outfits remain visibly distinct at their real header size.`).toBeGreaterThan(0.02);
    }
  }
  await testInfo.attach('wardrobe-foreground-comparisons', {
    body: JSON.stringify(comparisons, null, 2), contentType: 'application/json'
  });
  expect(errors).toEqual([]);
});

test('all eight themes are reachable in the 320 by 568 rail and survive touch and reload', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  await openRewards(page);
  const originalMedals = await record(page, MEDAL_KEY);
  const bounds = await metrics(page), viewport = page.viewportSize();
  for (const [index, theme] of THEME_IDS.entries()) {
    const rect = cssClip(bounds, await worldControl(page, index));
    expect(rect.width, `${theme}: minimum touch width`).toBeGreaterThanOrEqual(44 - 0.01);
    expect(rect.height, `${theme}: minimum touch height`).toBeGreaterThanOrEqual(44 - 0.01);
    expect(rect.x, `${theme}: left edge`).toBeGreaterThanOrEqual(0);
    expect(rect.y, `${theme}: top edge`).toBeGreaterThanOrEqual(0);
    expect(rect.x + rect.width, `${theme}: right edge`).toBeLessThanOrEqual(viewport.width + 0.01);
    expect(rect.y + rect.height, `${theme}: bottom edge`).toBeLessThanOrEqual(viewport.height + 0.01);
  }
  for (const index of [6, 7, 6, 7]) {
    const world = await worldControl(page, index);
    await tap(page, world.x + world.width / 2, world.y + world.height / 2);
    await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[index]);
    expect((await growthView(page)).visible).toBe(true);
    expect(JSON.parse(await record(page)).preferred_theme).toBe(THEME_IDS[index]);
    await rendered(page);
    await page.screenshot({ path: testInfo.outputPath(`wardrobe-${THEME_IDS[index]}-320.png`), scale: 'css' });
  }
  expect(await record(page, MEDAL_KEY)).toBe(originalMedals);
  const saved = await record(page);
  // openGame navigates to a new exported engine and selects its default Match
  // mode. It must read the saved world rather than overwrite Candy with Spring.
  const reloadErrors = await openGame(page, { reducedMotion: 'reduce' });
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute('content', THEME_COLORS[7]);
  const reloaded = await record(page);
  expect(JSON.parse(reloaded).preferred_theme).toBe(JSON.parse(saved).preferred_theme);
  expect(await record(page, MEDAL_KEY)).toBe(originalMedals);
  await settled(page);
  await page.screenshot({ path: testInfo.outputPath('wardrobe-candy-reloaded-320.png'), scale: 'css' });
  expect([...errors, ...reloadErrors]).toEqual([]);
});
