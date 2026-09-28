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

async function observeChest(page) {
  await page.addInitScript(() => {
    window.chestObservation = { cues: [], presses: [], progress: [] };
    window.addEventListener('wordbuddies:chest-cue', event => {
      window.chestObservation.cues.push(event.detail);
    });
    window.addEventListener('pointerdown', () => {
      window.chestObservation.presses.push(performance.now());
    }, true);
    document.addEventListener('DOMContentLoaded', () => {
      const progress = document.getElementById('chest-progress');
      new MutationObserver(() => {
        window.chestObservation.progress.push({
          hidden: progress.hidden,
          percent: Number(progress.getAttribute('aria-valuenow')),
          text: progress.getAttribute('aria-valuetext'),
          saved: localStorage.getItem('wordBuddies.medalProgress') || ''
        });
      }).observe(progress, { attributes: true });
    });
  });
}

test('an earned chest cancels on release, recharges visibly and saves one piece', async ({ page }, testInfo) => {
  await observeAudio(page, { fingerprintBuffers: true });
  await observeChest(page);
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

  const unopenedSave = await rewardSave(page);
  const progressStart = await page.evaluate(() => window.chestObservation.progress.length);
  await pressChest(page);
  try {
    // Capture transient states in the page. Screenshot encoding can take longer
    // than the complete hold, and must not make an already-completed phase fail.
    await expect(page.locator('#game-status')).toContainText('A new piece!');
  } finally {
    await page.mouse.up();
  }
  const progressHistory = await page.evaluate(start => window.chestObservation.progress.slice(start), progressStart);
  expect(progressHistory.some(state => !state.hidden && state.percent >= 20 && state.percent < 100 &&
    state.text.includes('Keep holding'))).toBe(true);
  const openingStates = progressHistory.filter(state => !state.hidden && state.percent === 100 && state.text === 'Opening!');
  expect(openingStates.length).toBeGreaterThan(0);
  expect(openingStates.every(state => state.saved === unopenedSave), 'Opening cannot claim the piece early').toBe(true);
  await testInfo.attach('chest-progress', { body: JSON.stringify(progressHistory, null, 2), contentType: 'application/json' });
  await expect(progress).toHaveAttribute('hidden', '');
  expect(await pieces(page)).toBe(baseline + 1);
  const saved = await rewardSave(page);
  await rendered(page);
  await screenshot(page, testInfo, 'opened');

  if (await page.evaluate(() => window.audioObservation.available)) {
    const allSounds = await page.evaluate(() => window.audioObservation.playbacks);
    await testInfo.attach('all-audio', { body: JSON.stringify(allSounds, null, 2), contentType: 'application/json' });
    const observation = await page.evaluate(() => window.chestObservation);
    const cues = observation.cues;
    expect(cues.map(event => `${event.cue}:${event.step}`)).toEqual([
      'press:0', 'cancel:0', 'press:0', 'charge_step:1', 'charge_step:2',
      'charge_step:3', 'opening:0', 'unlock:0', 'release:0', 'settle:0'
    ]);
    expect(cues.every(event => event.theme === 'summer')).toBe(true);
    const opening = cues.find(event => event.cue === 'opening');
    // These are observable scheduling measurements, not a physical-device
    // claim about display scanout, speakers or Bluetooth output latency.
    const timing = cues.filter(event => ['press', 'unlock', 'release', 'settle'].includes(event.cue))
      .map(event => ({ cue: event.cue, milliseconds: event.at - (event.cue === 'press'
        ? observation.presses.filter(at => at <= event.at).at(-1) : opening.at) }));
    await testInfo.attach('chest-cue-timing', {
      body: JSON.stringify({ cues, timing }, null, 2), contentType: 'application/json'
    });
    expect(timing.find(event => event.cue === 'unlock').milliseconds,
      'The opening keeps its first 100 milliseconds of tension').toBeGreaterThanOrEqual(100);
    expect(timing.find(event => event.cue === 'release').milliseconds,
      'The lid release cannot consume time from the preceding hold frame').toBeGreaterThanOrEqual(300);
    const startsAt = cues[0].at - 100;
    const chestSounds = allSounds.filter(sound => sound.at >= startsAt &&
      [0.19, 0.22, 0.24, 0.31, 0.44, 0.48, 0.68, 0.74].some(duration => Math.abs(sound.duration - duration) < 0.001));
    await testInfo.attach('chest-audio', { body: JSON.stringify(chestSounds, null, 2), contentType: 'application/json' });
    expect(chestSounds.filter(sound => Math.abs(sound.duration - 0.19) < 0.001)).toHaveLength(2);
    expect(chestSounds.filter(sound => Math.abs(sound.duration - 0.22) < 0.001)).toHaveLength(1);
    for (const duration of [0.31, 0.48, 0.68, 0.74]) {
      expect(chestSounds.filter(sound => Math.abs(sound.duration - duration) < 0.001)).toHaveLength(1);
    }
    const reward = chestSounds.find(sound => Math.abs(sound.duration - 0.74) < 0.001);
    expect(reward.at - opening.at).toBeGreaterThanOrEqual(1700);
    const alignment = [['unlock', 0.31], ['release', 0.68], ['settle', 0.48]].map(([cue, duration]) => ({
      cue, milliseconds: chestSounds.find(sound => Math.abs(sound.duration - duration) < 0.001).at - cues.find(event => event.cue === cue).at
    }));
    await testInfo.attach('chest-audio-alignment', { body: JSON.stringify(alignment, null, 2), contentType: 'application/json' });
    for (const sound of chestSounds) {
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
  await observeChest(page);
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
  const cues = await page.evaluate(() => window.chestObservation.cues);
  expect(cues.filter(event => ['unlock', 'release', 'settle'].includes(event.cue))).toEqual([]);
  expect(cues.filter(event => event.cue === 'opening')).toHaveLength(1);
  await screenshot(page, testInfo, 'reduced-motion-opened');
  expect(errors).toEqual([]);
});

test('unavailable themed samples use immediate local feedback without delaying rewards', async ({ page }, testInfo) => {
  const fs = require('node:fs'), path = require('node:path');
  const html = fs.readFileSync(path.resolve(__dirname, '../../build/web/index.html'), 'utf8');
  const config = JSON.parse(html.match(/const config = (\{[^\r\n]*\});/)[1]);
  const samples = new Set(Object.entries(config.audioAssets)
    .filter(([source]) => source.includes('/audio/chests/')).map(([, file]) => file));
  expect(samples.size).toBe(72);
  let failedRequests = 0;
  await page.route(url => samples.has(url.pathname.split('/').at(-1)), async route => {
    failedRequests += 1;
    // A successful HTTP response with invalid resource bytes exercises the
    // resource-validation failure without unrelated browser network errors.
    await route.fulfill({ status: 200, body: 'unavailable sample', contentType: 'application/octet-stream' });
  });
  await observeAudio(page, { fingerprintBuffers: true });
  await observeChest(page);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await chooseTheme(page, 5);
  await winMatch(page);
  const baseline = await pieces(page);
  await pressChest(page, 200);
  expect(await pieces(page)).toBe(baseline);
  await pressChest(page);
  try {
    await expect(page.locator('#game-status')).toContainText('A new piece!');
  } finally {
    await page.mouse.up();
  }
  expect(await pieces(page)).toBe(baseline + 1);
  expect(failedRequests).toBeGreaterThanOrEqual(9);
  const cues = await page.evaluate(() => window.chestObservation.cues);
  expect(cues.filter(event => event.cue === 'release')).toHaveLength(1);
  if (await page.evaluate(() => window.audioObservation.available)) {
    const playbacks = await page.evaluate(() => window.audioObservation.playbacks);
    const feedback = playbacks.filter(sound => sound.at >= cues[0].at - 100 &&
      [0.2, 0.36, 0.42].some(duration => Math.abs(sound.duration - duration) < 0.001));
    expect(feedback.length).toBeGreaterThanOrEqual(8);
    expect(feedback.filter(sound => Math.abs(sound.duration - 0.42) < 0.001)).toHaveLength(1);
    await testInfo.attach('fallback-audio', { body: JSON.stringify(feedback, null, 2), contentType: 'application/json' });
  }
  const saved = await rewardSave(page);
  await page.waitForTimeout(400);
  expect(await rewardSave(page)).toBe(saved);
  expect(errors).toEqual([]);
});
