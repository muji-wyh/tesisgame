const { test, expect } = require('@playwright/test');
const {
  openGame, metrics, tap, rendered, discoverMatchCards, boardPoint, resultPoint,
  openRewards, visibleColorCount, observeAudio, chooseTheme
} = require('./game-ui.cjs');

async function rewardSave(page) {
  return page.evaluate(() => localStorage.getItem('wordBuddies.medalProgress') || '');
}

async function pieces(page) {
  return [...(await rewardSave(page)).matchAll(/"([a-z]+-\d+)"\s*:\s*(\d+)/g)]
    .reduce((total, [, , count]) => total + Number(count), 0);
}

async function winMatch(page) {
  const bounds = await metrics(page), cards = await discoverMatchCards(page);
  const pairs = cards.filter(card => card.kind === 'Word').map(word =>
    [word, cards.find(card => card.kind === 'Picture' && card.word === word.word)]
  ).filter(([, picture]) => picture);
  expect(pairs).toHaveLength(3);
  for (const [index, [word, picture]] of pairs.entries()) {
    const written = boardPoint(bounds, word.index), pictured = boardPoint(bounds, picture.index);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word.word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === 2 ? 'You did it!' : 'Find 3 word');
  }
}

async function pressChest(page, holdMilliseconds = null) {
  const bounds = await metrics(page), point = resultPoint(bounds, 'chest');
  const x = bounds.x + point.x * bounds.scale, y = bounds.y + point.y * bounds.scale;
  if (holdMilliseconds !== null) {
    // Avoid assertion waits while the short hold is active.
    await page.mouse.click(x, y, { delay: holdMilliseconds });
    return;
  }
  await page.mouse.move(x, y);
  await page.mouse.down();
}

async function screenshot(page, testInfo, phase) {
  const png = await page.screenshot({
    path: testInfo.outputPath(`chest-charge-${phase}.png`), fullPage: true, scale: 'css'
  });
  expect(await visibleColorCount(page, png), `${phase} evidence includes the real rendered game`).toBeGreaterThan(20);
}

test('an earned chest cancels on release, recharges visibly and saves one piece', async ({ page }, testInfo) => {
  await observeAudio(page, { fingerprintBuffers: true });
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  // Summer has one of the widest world badges on the narrow phone stage.
  await chooseTheme(page, 1);
  const baseline = await pieces(page);
  await winMatch(page);
  const progress = page.locator('#chest-progress');
  await expect(progress).toHaveAttribute('hidden', '');
  expect(await pieces(page)).toBe(baseline);

  await pressChest(page, 250);
  await expect(progress).toHaveAttribute('hidden', '');
  await expect(progress).toHaveAttribute('aria-valuenow', '0');
  expect(await pieces(page)).toBe(baseline);
  await expect(page.locator('#game-status')).toContainText('You did it!');
  await screenshot(page, testInfo, 'cancelled');

  await pressChest(page);
  try {
    await expect(progress).not.toHaveAttribute('hidden', '');
    await expect(progress).toHaveAttribute('aria-valuetext', /Keep holding/);
    await expect.poll(async () => Number(await progress.getAttribute('aria-valuenow')),
      { intervals: [30, 50], timeout: 2500 }).toBeGreaterThanOrEqual(20);
    await screenshot(page, testInfo, 'holding');
    await expect(progress).toHaveAttribute('aria-valuenow', '100');
    await expect(progress).toHaveAttribute('aria-valuetext', 'Opening!');
    expect(await pieces(page)).toBe(baseline);
    await screenshot(page, testInfo, 'opening');
    await expect(page.locator('#game-status')).toContainText('A new piece!');
  } finally {
    await page.mouse.up();
  }
  await expect(progress).toHaveAttribute('hidden', '');
  expect(await pieces(page)).toBe(baseline + 1);
  const saved = await rewardSave(page);
  await rendered(page);
  await screenshot(page, testInfo, 'opened');

  if (await page.evaluate(() => window.audioObservation.available)) {
    const allSounds = await page.evaluate(() => window.audioObservation.playbacks);
    await testInfo.attach('all-audio', { body: JSON.stringify(allSounds, null, 2), contentType: 'application/json' });
    const chargeSounds = allSounds.filter(sound =>
      Math.abs(sound.duration - 0.28) < 0.001 || Math.abs(sound.duration - 0.44) < 0.001);
    await testInfo.attach('charge-audio', { body: JSON.stringify(chargeSounds, null, 2), contentType: 'application/json' });
    // Godot Web implements looping with repeated buffer starts; source.loop stays
    // false. Only the initial source for each hold starts with the 0.82 pitch.
    const pulses = chargeSounds.filter(sound => Math.abs(sound.duration - 0.28) < 0.001);
    expect(pulses.length).toBeGreaterThanOrEqual(2);
    expect(pulses.filter(sound => Math.abs(sound.playbackRate - 0.82) < 0.001)).toHaveLength(2);
    expect(new Set(pulses.map(sound => sound.fingerprint)).size).toBe(1);
    expect(chargeSounds.filter(sound => Math.abs(sound.duration - 0.44) < 0.001)).toHaveLength(1);
    for (const sound of chargeSounds) {
      expect(sound.contextState).toBe('running');
      expect(sound.peak).toBeGreaterThan(0.01);
      expect(sound.peak).toBeLessThan(1);
    }
  } else {
    // Windows Playwright WebKit can lack WebAudio. Still verify the complete
    // visual/reward flow and its honest sound-unavailable fallback.
    await expect(page.locator('#audio-status')).toHaveText('Sound is not available in this browser.');
    testInfo.annotations.push({ type: 'audio', description: 'WebAudio unavailable in this runtime; visual and reward flow verified.' });
  }

  // The input surface may still place the flying fragment. A second hold must
  // never repeat the persisted reward or return to a charging state.
  await pressChest(page);
  try {
    await page.waitForTimeout(1350);
  } finally {
    await page.mouse.up();
  }
  await expect(progress).toHaveAttribute('hidden', '');
  expect(await rewardSave(page)).toBe(saved);
  await openRewards(page);
  await page.keyboard.press('Escape');
  await rendered(page);
  expect(await rewardSave(page)).toBe(saved);
  expect(errors).toEqual([]);
});

test('reduced motion keeps hold progress and releases without claiming early', async ({ page }, testInfo) => {
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  await chooseTheme(page, 4); // Ocean exercises the larger crystal chest.
  await winMatch(page);
  const baseline = await pieces(page), progress = page.locator('#chest-progress');
  await pressChest(page, 250);
  await expect(progress).toHaveAttribute('hidden', '');
  await expect(progress).toHaveAttribute('aria-valuenow', '0');
  expect(await pieces(page)).toBe(baseline);
  await pressChest(page);
  try {
    await expect(progress).not.toHaveAttribute('hidden', '');
    await expect.poll(async () => Number(await progress.getAttribute('aria-valuenow')),
      { intervals: [30, 50], timeout: 2500 }).toBeGreaterThanOrEqual(20);
    await screenshot(page, testInfo, 'reduced-motion-holding');
    await expect(page.locator('#game-status')).toContainText('A new piece!');
  } finally {
    await page.mouse.up();
  }
  await expect(progress).toHaveAttribute('hidden', '');
  expect(await pieces(page)).toBe(baseline + 1);
  await screenshot(page, testInfo, 'reduced-motion-opened');
  expect(errors).toEqual([]);
});
