const { test, expect } = require('@playwright/test');
const {
  openGame, metrics, tap, rendered, discoverMatchCards, boardPoint, resultPoint,
  openRewards, visibleColorCount, observeAudio, chooseTheme
} = require('./game-ui.cjs');

const HOLD_PULSE_TIMES = [0.08, 0.38, 0.65, 0.89, 1.10];
const PULSE_TIMES = [0.08, 0.245, 0.395, 0.535, 0.665, 0.785, 0.895, 0.995,
  1.09, 1.18, 1.265, 1.35, 1.435, 1.52, 1.605, 1.69, 1.775, 1.86];
const isRhythmCue = event => ['hold_pulse', 'tension_pulse'].includes(event.cue);
const hasDuration = (sound, duration) => Math.abs(sound.duration - duration) < 0.001;
const isChestSound = sound => [0.19, 0.22, 0.24, 0.31, 0.48, 0.68, 0.74, 0.8]
  .some(duration => hasDuration(sound, duration));
const audioOnset = sound => sound.at + Math.max(0, sound.scheduledAt - sound.contextTime) * 1000;
const audioStop = sound => sound.stoppedAt + Math.max(0, sound.stopScheduledAt - sound.stopContextTime) * 1000;

function expectBedChain(bed, { press, stop, opening }) {
  expect(bed.length, 'A press starts a sustained material bed').toBeGreaterThan(0);
  expect(bed.every(sound => typeof sound.fingerprint === 'string')).toBe(true);
  expect(new Set(bed.map(sound => sound.fingerprint)).size,
    'Every manually looped source retains the same themed material sample').toBe(1);
  expect(Math.abs(audioOnset(bed[0]) - press.at), 'The bed responds to the initial press').toBeLessThanOrEqual(100);
  // Godot loops samples by replacing naturally ended buffer sources. Native
  // source.loop is false; only the final cycle should receive an explicit stop.
  for (let index = 1; index < bed.length; index++) {
    const previous = bed[index - 1], current = bed[index];
    expect(previous.stoppedAt, 'A loop handoff never truncates its previous source').toBeUndefined();
    expect(Number.isFinite(previous.endedAt), 'Every replacement follows a naturally ended source').toBe(true);
    expect(Math.abs(audioOnset(current) - previous.endedAt),
      'The next material cycle follows the previous natural end without a new attack or gap').toBeLessThanOrEqual(100);
    expect(current.playbackRate, 'Replacement sources preserve the rising pitch instead of resetting to rate 1')
      .toBeGreaterThan(previous.playbackRate);
    if (opening && audioOnset(current) >= opening.at) {
      expect(current.playbackRate, 'Opening-stage replacements retain the accumulated pitch above rate 1').toBeGreaterThan(1);
    }
  }
  const terminal = bed.at(-1);
  expect(Number.isFinite(terminal.stoppedAt), 'The active final material cycle is explicitly stopped').toBe(true);
  expect(Math.abs(audioStop(terminal) - stop.at), 'The final material cycle stops promptly with its physical cue').toBeLessThanOrEqual(100);
  if (opening) {
    expect(bed.length, 'The accepted hold and opening share several cycles of one material bed').toBeGreaterThan(1);
    expect(audioOnset(bed[0])).toBeLessThan(opening.at);
    expect(audioStop(terminal)).toBeGreaterThan(opening.at);
    // A natural loop boundary can land near confirmation. Allow that boundary,
    // while the lifecycle checks above reject an extra restart at confirmation.
    const spansConfirmation = bed.some(sound => audioOnset(sound) <= opening.at &&
      (sound.stoppedAt === undefined ? sound.endedAt : audioStop(sound)) >= opening.at);
    const naturalHandoff = bed.slice(1).some((sound, index) =>
      Math.abs(audioOnset(sound) - opening.at) <= 100 && Math.abs(bed[index].endedAt - opening.at) <= 100);
    expect(spansConfirmation || naturalHandoff, 'The material bed continues through confirmation without a new attack').toBe(true);
  }
}

function expectAccelerating(times, message) {
  const intervals = times.slice(1).map((time, index) => time - times[index]);
  expect(intervals.every(interval => interval > 0), `${message}: beats remain distinct`).toBe(true);
  expect(intervals.slice(-3).reduce((sum, value) => sum + value, 0) / 3, message).toBeLessThan(
    intervals.slice(0, 3).reduce((sum, value) => sum + value, 0) / 3 * 0.60);
}

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
  expect(pairs).toHaveLength(5);
  for (const [index, [word, picture]] of pairs.entries()) {
    const written = boardPoint(bounds, word.index), pictured = boardPoint(bounds, picture.index);
    await tap(page, written.x, written.y);
    await expect(page.locator('#selection-status')).toHaveText(`Word: ${word.word}`);
    await tap(page, pictured.x, pictured.y);
    await expect(page.locator('#game-status')).toContainText('Great match!');
    await page.keyboard.press('Escape');
    await expect(page.locator('#game-status')).toContainText(index === pairs.length - 1 ? 'You did it!' : 'Find 5 word');
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
    window.chestObservation = { cues: [], presses: [], progress: [], statuses: [] };
    window.addEventListener('wordbuddies:chest-cue', event => {
      window.chestObservation.cues.push(event.detail);
    });
    window.addEventListener('pointerdown', () => {
      window.chestObservation.presses.push(performance.now());
    }, true);
    document.addEventListener('DOMContentLoaded', () => {
      const progress = document.getElementById('chest-progress');
      const status = document.getElementById('game-status');
      new MutationObserver(() => {
        window.chestObservation.statuses.push({ at: performance.now(), text: status.textContent });
      }).observe(status, { childList: true });
      new MutationObserver(() => {
        window.chestObservation.progress.push({
          at: performance.now(),
          hidden: progress.hidden,
          phase: progress.getAttribute('data-phase'),
          percent: Number(progress.getAttribute('aria-valuenow')),
          text: progress.getAttribute('aria-valuetext'),
          saved: localStorage.getItem('wordBuddies.medalProgress') || ''
        });
      }).observe(progress, { attributes: true });
    });
  });
}

test('an earned chest cancels on release, recharges visibly and saves one piece', async ({ page }, testInfo) => {
  await observeAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
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
  const cancelledCueCount = await page.evaluate(() => window.chestObservation.cues.length);
  const cancelledAudioCount = await page.evaluate(() => window.audioObservation.playbacks.length);
  await page.waitForTimeout(1350);
  expect(await page.evaluate(() => window.chestObservation.cues.length), 'A cancelled hold cannot dispatch delayed opening or tension cues').toBe(cancelledCueCount);
  expect((await page.evaluate(start => window.audioObservation.playbacks.slice(start), cancelledAudioCount)).filter(isChestSound),
    'A cancelled hold cannot restart a material sound after its original hold deadline').toEqual([]);
  expect(await pieces(page)).toBe(baseline);
  await screenshot(page, testInfo, 'cancelled');

  const unopenedSave = await rewardSave(page);
  const progressStart = await page.evaluate(() => window.chestObservation.progress.length);
  await pressChest(page);
  try {
    // Capture transient states in the page. Screenshot encoding can take longer
    // than the complete hold, and must not make an already-completed phase fail.
    await expect.poll(() => page.evaluate(() => window.chestObservation.cues.some(cue => cue.cue === 'opening')),
      { timeout: 4000 }).toBe(true);
  } finally {
    await page.mouse.up();
  }
  await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
  const progressHistory = await page.evaluate(start => window.chestObservation.progress.slice(start), progressStart);
  const holdingProgress = progressHistory.filter(state => !state.hidden && state.phase === 'holding');
  expect(holdingProgress.some(state => state.percent >= 30 && state.text.includes('Hold to begin'))).toBe(true);
  expect(holdingProgress.every(state => state.percent <= 34),
    'The 1.2-second hold fills about one third of the bar before the automatic opening').toBe(true);
  for (const phase of ['gathering', 'building', 'anticipation']) {
    expect(progressHistory.some(state => !state.hidden && state.phase === phase && state.percent >= 34 &&
      state.percent < 100), `Progress remains active and incomplete during ${phase}`).toBe(true);
  }
  const activeProgress = progressHistory.filter(state => !state.hidden);
  expect(activeProgress.every((state, index) => index === 0 || state.percent >= activeProgress[index - 1].percent),
    'Progress advances continuously from confirmation through release').toBe(true);
  const openingStates = progressHistory.filter(state => !state.hidden && state.percent === 100 && state.text === 'Opening!');
  expect(openingStates.length).toBeGreaterThan(0);
  expect(openingStates.every(state => state.saved === unopenedSave), 'Opening cannot claim the piece early').toBe(true);
  await testInfo.attach('chest-progress', { body: JSON.stringify(progressHistory, null, 2), contentType: 'application/json' });
  await expect(progress).toHaveAttribute('hidden', '');
  expect(await pieces(page)).toBe(baseline + 1);
  const saved = await rewardSave(page);
  await rendered(page);
  await screenshot(page, testInfo, 'opened');

  const observation = await page.evaluate(() => window.chestObservation);
  const cues = observation.cues;
  expect(cues.filter(event => !isRhythmCue(event) && event.cue !== 'charge_step')
    .map(event => `${event.cue}:${event.step}`)).toEqual([
    'press:0', 'cancel:0', 'press:0', 'opening:0', 'anticipation:0', 'unlock:0', 'release:0', 'settle:0'
  ]);
  const steps = cues.filter(event => event.cue === 'charge_step');
  expect(steps.map(event => event.step), 'Each star lights once across the hold and automatic opening').toEqual([1, 2, 3]);
  const opening = cues.find(event => event.cue === 'opening');
  const acceptedPress = cues.filter(event => event.cue === 'press').at(-1);
  const acceptedCues = cues.slice(cues.indexOf(acceptedPress));
  const holdPulses = acceptedCues.filter(event => event.cue === 'hold_pulse');
  expect(holdPulses.map(event => event.step), 'The accepted hold delivers all five physical beats')
    .toEqual(HOLD_PULSE_TIMES.map((_, index) => index + 1));
  const pulses = cues.filter(event => event.cue === 'tension_pulse');
  expect(pulses.map(event => event.step), 'The automatic opening delivers all eighteen physical beats')
    .toEqual(PULSE_TIMES.map((_, index) => index + 1));
  const rhythm = acceptedCues.filter(isRhythmCue);
  expect(rhythm.map(event => event.cue), 'Confirmation joins five hold beats directly to eighteen opening beats')
    .toEqual([...HOLD_PULSE_TIMES.map(() => 'hold_pulse'), ...PULSE_TIMES.map(() => 'tension_pulse')]);
  // The authored first beat is at 80 ms. This browser bound includes engine
  // frame and bridge delivery jitter, not a physical display-latency claim.
  expect(holdPulses[0].at - acceptedPress.at, 'A physical beat arrives near the start of holding').toBeGreaterThanOrEqual(0);
  expect(holdPulses[0].at - acceptedPress.at, 'The hold does not wait for its first star before shaking').toBeLessThanOrEqual(200);
  expectAccelerating(rhythm.map(pulse => pulse.at), 'The final roll is much faster than the first holding beats');
  expect(cues.every(event => event.theme === 'summer')).toBe(true);
  expect(cues.indexOf(steps[0]), 'The first star belongs to the hold before opening begins').toBeLessThan(cues.indexOf(opening));
  expect(steps[0].at - acceptedPress.at).toBeGreaterThanOrEqual(1070);
  expect(cues.indexOf(steps[1])).toBeGreaterThan(cues.indexOf(opening));
  expect(cues.indexOf(steps[2])).toBeGreaterThan(cues.indexOf(opening));
  const hush = cues.find(event => event.cue === 'anticipation');
  expect(cues.find(event => event.cue === 'unlock').at - hush.at,
    'A short final breath separates the tension rhythm from unlocking').toBeGreaterThanOrEqual(100);
  expect(cues.find(event => event.cue === 'unlock').at - hush.at).toBeLessThanOrEqual(350);
  expect(openingStates[0].at - opening.at, '100 percent waits for the 2.32-second release').toBeGreaterThanOrEqual(2220);
  // These are browser-observed beat times. Allow frame delivery jitter while
  // still rejecting an early release or the former ten-second sequence.
  for (const [cue, milliseconds] of [['anticipation', 1940], ['unlock', 2120], ['release', 2320], ['settle', 2950]]) {
    const elapsed = cues.find(event => event.cue === cue).at - opening.at;
    expect(elapsed, `${cue} cannot precede its automatic-opening boundary`).toBeGreaterThanOrEqual(milliseconds - 100);
    expect(elapsed, `${cue} stays within the shorter automatic-opening sequence`).toBeLessThanOrEqual(milliseconds + 500);
  }
  const completed = observation.statuses.find(status => status.text === 'Chest opened! Ready for another adventure?');
  expect(completed).toBeDefined();
  expect(completed.at - opening.at, 'Saving waits for the full 3.8-second automatic sequence').toBeGreaterThanOrEqual(3700);
  expect(completed.at - acceptedPress.at, 'The full hold and opening last five seconds').toBeGreaterThanOrEqual(4900);
  expect(completed.at - acceptedPress.at, 'The completed chest no longer takes ten seconds').toBeLessThanOrEqual(6000);
  await testInfo.attach('chest-completion-timing', {
    body: JSON.stringify({ hold: opening.at - acceptedPress.at, automatic: completed.at - opening.at,
      total: completed.at - acceptedPress.at }, null, 2), contentType: 'application/json'
  });

  if (await page.evaluate(() => window.audioObservation.available)) {
    const allSounds = await page.evaluate(() => window.audioObservation.playbacks);
    await testInfo.attach('all-audio', { body: JSON.stringify(allSounds, null, 2), contentType: 'application/json' });
    // These are observable scheduling measurements, not a physical-device
    // claim about display scanout, speakers or Bluetooth output latency.
    const timing = cues.filter(event => ['press', 'unlock', 'release', 'settle'].includes(event.cue))
      .map(event => ({ cue: event.cue, milliseconds: event.at - (event.cue === 'press'
        ? observation.presses.filter(at => at <= event.at).at(-1) : opening.at) }));
    await testInfo.attach('chest-cue-timing', {
      body: JSON.stringify({ cues, timing }, null, 2), contentType: 'application/json'
    });
    const startsAt = cues[0].at - 100;
    const chestSounds = allSounds.filter(sound => sound.at >= startsAt && isChestSound(sound));
    await testInfo.attach('chest-audio', { body: JSON.stringify(chestSounds, null, 2), contentType: 'application/json' });
    expect(chestSounds.filter(sound => Math.abs(sound.duration - 0.19) < 0.001)).toHaveLength(2);
    expect(chestSounds.filter(sound => Math.abs(sound.duration - 0.22) < 0.001)).toHaveLength(1);
    for (const duration of [0.31, 0.48, 0.68, 0.74]) {
      expect(chestSounds.filter(sound => Math.abs(sound.duration - duration) < 0.001)).toHaveLength(1);
    }
    const reward = chestSounds.find(sound => Math.abs(sound.duration - 0.74) < 0.001);
    expect(reward.at - opening.at).toBeGreaterThanOrEqual(3700);
    const beds = chestSounds.filter(sound => hasDuration(sound, 0.8));
    const cancel = cues.find(event => event.cue === 'cancel');
    const cancelledBed = beds.filter(sound => audioOnset(sound) < acceptedPress.at - 100);
    const acceptedBed = beds.filter(sound => audioOnset(sound) >= acceptedPress.at - 100);
    expectBedChain(cancelledBed, { press: cues[0], stop: cancel });
    expectBedChain(acceptedBed, { press: acceptedPress, stop: hush, opening });
    const strikes = chestSounds.filter(sound => hasDuration(sound, 0.24));
    const strikeCues = cues.filter(isRhythmCue);
    expect(strikes, 'Only physical hold and opening beats play; all stars and confirmation remain silent').toHaveLength(strikeCues.length);
    expect(new Set(strikes.map(sound => sound.fingerprint)).size, 'All attacks use the same themed step sample, without an opening one-shot').toBe(1);
    for (const [index, sound] of strikes.entries()) {
      expect(Math.abs(audioOnset(sound) - strikeCues[index].at),
        `${strikeCues[index].cue} ${strikeCues[index].step} follows its physical cue`).toBeLessThanOrEqual(100);
    }
    // Match by cue order so a cancelled hold or a shared confirmation frame
    // cannot make a valid hold beat look like an extra opening attack.
    const cancelledStrikes = strikeCues.length - rhythm.length;
    const acceptedStrikes = strikes.slice(cancelledStrikes);
    expect(acceptedStrikes).toHaveLength(HOLD_PULSE_TIMES.length + PULSE_TIMES.length);
    expectAccelerating(acceptedStrikes.map(audioOnset), 'Actual WebAudio onsets accelerate from the hold into the final roll');
    for (const [index, sound] of acceptedStrikes.entries()) {
      const scheduledTime = index < HOLD_PULSE_TIMES.length ? HOLD_PULSE_TIMES[index] :
        1.2 + PULSE_TIMES[index - HOLD_PULSE_TIMES.length];
      const energy = Math.pow(scheduledTime / 3.14, 0.72);
      expect(sound.playbackRate, 'Strike pitch follows scheduled tension without restarting at confirmation')
        .toBeCloseTo(0.95 + (1.55 - 0.95) * energy, 3);
      if (index) expect(sound.playbackRate, 'Every later audible strike rises in pitch')
        .toBeGreaterThan(acceptedStrikes[index - 1].playbackRate);
    }
    expect(acceptedStrikes.at(-1).playbackRate / acceptedStrikes[0].playbackRate, 'The final strike has a clearly higher register').toBeGreaterThan(1.5);
    expect(Math.abs(audioStop(acceptedStrikes.at(-1)) - hush.at), 'The last strike tail stops with the sustained bed for a clean final breath').toBeLessThanOrEqual(100);
    expect(chestSounds.filter(sound => audioOnset(sound) > hush.at + 30 && audioOnset(sound) < cues.find(event => event.cue === 'unlock').at - 30),
      'No material attack fills the quiet breath').toEqual([]);
    const alignment = [['unlock', 0.31], ['release', 0.68], ['settle', 0.48]].map(([cue, duration]) => ({
      cue, milliseconds: audioOnset(chestSounds.find(sound => hasDuration(sound, duration))) - cues.find(event => event.cue === cue).at
    }));
    await testInfo.attach('chest-audio-alignment', { body: JSON.stringify(alignment, null, 2), contentType: 'application/json' });
    for (const sound of alignment) expect(Math.abs(sound.milliseconds), `${sound.cue} audio follows its physical cue`).toBeLessThanOrEqual(100);
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

  // A second hold on the opened chest must never repeat the persisted reward
  // or return to a charging state.
  const finishedCueCount = await page.evaluate(() => window.chestObservation.cues.length);
  await pressChest(page);
  try {
    await page.waitForTimeout(1350);
  } finally {
    await page.mouse.up();
  }
  await expect(progress).toHaveAttribute('hidden', '');
  expect(await page.evaluate(() => window.chestObservation.cues.length), 'Pressing an opened chest cannot restart its physical timeline').toBe(finishedCueCount);
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
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
  } finally {
    await page.mouse.up();
  }
  await expect(progress).toHaveAttribute('hidden', '');
  expect(await pieces(page)).toBe(baseline + 1);
  const cues = await page.evaluate(() => window.chestObservation.cues);
  expect(cues.filter(event => ['hold_pulse', 'tension_pulse', 'unlock', 'release', 'settle'].includes(event.cue))).toEqual([]);
  expect(cues.filter(event => event.cue === 'opening')).toHaveLength(1);
  await screenshot(page, testInfo, 'reduced-motion-opened');
  expect(errors).toEqual([]);
});

test('background completion stops tension and never replays missed beats on return', async ({ page }, testInfo) => {
  await observeAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  await observeChest(page);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await chooseTheme(page, 1);
  await winMatch(page);
  const baseline = await pieces(page);
  await pressChest(page);
  let hidden;
  try {
    await expect.poll(() => page.evaluate(() => window.chestObservation.cues.filter(cue => cue.cue === 'tension_pulse').length),
      { intervals: [20, 30], timeout: 4000 }).toBeGreaterThanOrEqual(2);
    // Exercise the existing host lifecycle callback, without directly invoking
    // chest state or relying on the runner's actual tab focus.
    hidden = await page.evaluate(() => {
      const state = { at: performance.now(), cues: window.chestObservation.cues.length,
        sounds: window.audioObservation.playbacks.length };
      Object.defineProperty(document, 'hidden', { configurable: true, value: true });
      document.dispatchEvent(new Event('visibilitychange'));
      return state;
    });
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?');
    expect(await pieces(page)).toBe(baseline + 1);
    await page.waitForTimeout(250);
  } finally {
    await page.mouse.up();
    await page.evaluate(() => {
      delete document.hidden;
      document.dispatchEvent(new Event('visibilitychange'));
    });
  }
  const saved = await rewardSave(page);
  await page.waitForTimeout(1600);
  expect(await page.evaluate(() => window.chestObservation.cues.length), 'Returning cannot catch up old tension, unlock or release cues').toBe(hidden.cues);
  const playbacks = await page.evaluate(() => window.audioObservation.playbacks);
  expect(playbacks.slice(hidden.sounds).filter(isChestSound), 'Background completion and return stay silent, including the reward accent').toEqual([]);
  if (await page.evaluate(() => window.audioObservation.available)) {
    const cues = await page.evaluate(() => window.chestObservation.cues);
    const opening = cues.find(cue => cue.cue === 'opening'), press = cues.find(cue => cue.cue === 'press');
    const bed = playbacks.filter(sound => hasDuration(sound, 0.8) && audioOnset(sound) >= press.at - 100);
    expectBedChain(bed, { press, stop: hidden, opening });
  }
  expect(await rewardSave(page)).toBe(saved);
  await screenshot(page, testInfo, 'background-completed');
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
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
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
      [0.2, 0.64, 0.42].some(duration => Math.abs(sound.duration - duration) < 0.001));
    expect(feedback.length).toBeGreaterThanOrEqual(8);
    expect(feedback.filter(sound => Math.abs(sound.duration - 0.42) < 0.001)).toHaveLength(1);
    await testInfo.attach('fallback-audio', { body: JSON.stringify(feedback, null, 2), contentType: 'application/json' });
  }
  const saved = await rewardSave(page);
  await page.waitForTimeout(400);
  expect(await rewardSave(page)).toBe(saved);
  expect(errors).toEqual([]);
});
