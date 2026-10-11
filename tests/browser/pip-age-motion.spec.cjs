const { test, expect } = require('@playwright/test');
const { createHash } = require('node:crypto');
const { openGame, metrics, openModeMenu } = require('./game-ui.cjs');
const motions = require('../../data/pip-age-motions.json');

for (const age of [0, 7, 12]) test(`Age ${age} Pip performs its own two quiet actions in the real header`, async ({ page }, info) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.addInitScript(age => {
    localStorage.setItem('growWithPip.growth.v1', `[growth]\nversion=3\nlevel=0\nage=${age}\nstreaks={}\nmastered_words=[]\nreceipts=[]\n`);
    localStorage.setItem('pipAndWords.presentation.v1', JSON.stringify({ muted: true, reduced_motion: false, preferred_theme: 'spring' }));
  }, age);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  const read = () => page.locator('#growth-status').evaluate(node => JSON.parse(node.dataset.view).pip);
  await expect.poll(async () => (await read()).age).toBe(age);
  const initial = await read();
  expect(initial.signature_actions).toEqual(motions.stages[age]);
  const bounds = await metrics(page), [x, y, width, height] = initial.rect;
  const crop = { x: bounds.x + x * bounds.scale, y: bounds.y + y * bounds.scale, width: width * bounds.scale, height: height * bounds.scale };
  const saved = await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'));
  const status = await page.locator('#game-status').textContent();
  for (const action of motions.stages[age]) {
    await expect.poll(async () => (await read()).action, { timeout: 14000 }).toBe(action);
    const before = await page.screenshot({ clip: crop });
    await page.waitForTimeout(350);
    const after = await page.screenshot({ clip: crop, path: info.outputPath(`${action}-header.png`) });
    expect(createHash('sha256').update(before).digest('hex')).not.toBe(createHash('sha256').update(after).digest('hex'));
    expect((await read()).rect).toEqual(initial.rect);
    await expect.poll(async () => (await read()).action, { timeout: 4000 }).toBe('');
  }
  expect(await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'))).toBe(saved);
  expect(await page.locator('#game-status').textContent()).toBe(status);
  await page.screenshot({ path: info.outputPath(`age-${age}-phone.png`) });
  await openModeMenu(page);
  await expect.poll(async () => (await read()).action).toBe('');
  expect(errors).toEqual([]);
});
