const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const { openGame, openModeMenu, chooseMode, metrics, tap, enterGame, rendered, visibleColorCount } = require('./game-ui.cjs');

async function activate(page, name) {
  const state = (await metrics(page)).library;
  const control = state.controls.find(item => item.name === name);
  expect(control, `${name} is visible in the game library`).toBeTruthy();
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

test('the illustrated library fits, preserves play, and switches every game', async ({ page }, testInfo) => {
  test.setTimeout(180000);
  await page.addInitScript(() => { window.SpeechRecognition = undefined; window.webkitSpeechRecognition = undefined; });
  const errors = await openGame(page);
  for (const size of [{ width: 390, height: 844 }, { width: 320, height: 320 }, { width: 844, height: 390 }, { width: 1280, height: 800 }]) {
    await page.setViewportSize(size);
    await openModeMenu(page);
    await expect.poll(async () => {
      const bounds = await metrics(page);
      return bounds.library.controls.every(({ rect: [x, y, w, h] }) => x >= 0 && y >= 0 && x + w <= bounds.width + 1 && y + h <= bounds.height + 1 && h * bounds.scale >= 43);
    }).toBe(true);
    const png = await page.screenshot({ path: testInfo.outputPath(`library-${size.width}.png`), scale: 'css' });
    const raw = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
    const canvasPng = Buffer.from(raw, 'base64');
    fs.writeFileSync(testInfo.outputPath(`library-${size.width}-canvas.png`), canvasPng);
    expect(await visibleColorCount(page, canvasPng), 'The native game renders after resizing').toBeGreaterThan(20);
    const colors = await visibleColorCount(page, png);
    if (colors === 1 && process.platform === 'win32' && testInfo.project.use.browserName === 'webkit') {
      testInfo.annotations.push({ type: 'rendering-limitation', description: 'Windows WebKit presents a blank page after resize while its raw canvas renders; both captures retained.' });
    } else expect(colors).toBeGreaterThan(20);
    await activate(page, 'LibraryClose');
    await expect(page.locator('#game-status')).toContainText('Game mode menu closed');
  }
  for (const mode of ['memory', 'pop', 'quest', 'match']) {
    await chooseMode(page, mode);
    await openModeMenu(page);
    expect((await metrics(page)).library.current).toBe(mode);
    await page.keyboard.press('Escape');
    await expect.poll(async () => (await metrics(page)).library.visible).toBe(false);
  }
  const bounds = await metrics(page);
  await tap(page, bounds.width / 2, 40 / bounds.scale);
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(true);
  expect(errors).toEqual([]);
});

test('sound and explicit motion choices persist while system motion remains the default', async ({ page }) => {
  const errors = await openGame(page);
  await openModeMenu(page);
  await activate(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: true });
  await activate(page, 'LibraryMotion');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: true, reduced_motion: false });
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'false');
  await page.reload();
  await enterGame(page);
  await openModeMenu(page);
  await activate(page, 'LibraryMotion');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: true, reduced_motion: true });
  await expect(page.locator('html')).toHaveAttribute('data-reduced-motion', 'true');
  await activate(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')))).toEqual({ muted: false, reduced_motion: true });
  expect(errors).toEqual([]);
});
