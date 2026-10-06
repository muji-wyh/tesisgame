const { test, expect } = require('@playwright/test');
const { watchAudioRequests, observeOutputAudio, expectOutputEnergy } = require('./bundled-audio.cjs');
const {
  openGame, metrics, tap, rendered, discoverMatchCards, boardPoint, resultPoint,
  openRewards, visibleColorCount, observeAudio, chooseTheme, contentBounds, uiScale
} = require('./game-ui.cjs');

// Keep mobile CSS geometry while isolating cadence from software-renderer fill
// cost. Passive trace screenshots can also stall the final 60 ms beat gaps;
// explicit state screenshots remain. High-DPR timing still needs real devices.
test.use({
  deviceScaleFactor: 1,
  trace: { mode: 'retain-on-failure', screenshots: false, snapshots: true, sources: false }
});

const HOLD_PULSE_TIMES = [0.08, 0.40, 0.68, 0.91, 1.12];
const PULSE_TIMES = [0.11, 0.30, 0.48, 0.65, 0.81, 0.96, 1.10, 1.23,
  1.35, 1.46, 1.56, 1.65, 1.73, 1.80, 1.86];
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

async function openedChestFrame(page, testInfo, name) {
  const bounds = await metrics(page), content = contentBounds(bounds), scale = uiScale(bounds);
  const top = content.padding + content.header + content.gap;
  // The stage fills the outcome. Exclude the header mascot and the lower band
  // containing the floating New adventure button when measuring chest motion.
  const availableHeight = bounds.height - content.padding - top;
  const height = availableHeight - Math.ceil(72 / scale) - 10;
  const frame = await page.screenshot({ scale: 'css', clip: {
    x: bounds.x + (content.x + 4) * bounds.scale, y: bounds.y + (top + 4) * bounds.scale,
    width: (content.width - 8) * bounds.scale, height: (height - 8) * bounds.scale
  } });
  if (testInfo) await testInfo.attach(name, { body: frame, contentType: 'image/png' });
  return frame;
}

async function openedChestMotion(page, before, after) {
  return page.evaluate(async sources => {
    const frames = await Promise.all(sources.map(async source => {
      const image = new Image();
      image.src = `data:image/png;base64,${source}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      return { width: image.width, height: image.height,
        pixels: context.getImageData(0, 0, image.width, image.height).data };
    }));
    const { width, height } = frames[0];
    let changed = 0, bodyChanged = 0, bodyPixels = 0;
    for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
      const offset = (y * width + x) * 4;
      const distance = [0, 1, 2].reduce((sum, channel) =>
        sum + (frames[0].pixels[offset + channel] - frames[1].pixels[offset + channel]) ** 2, 0);
      const body = x > width * 0.22 && x < width * 0.78 && y > height * 0.30 && y < height * 0.92;
      if (body) bodyPixels++;
      // Reject compression noise and the slow, low-contrast breathing glow.
      // The actual chest silhouette must move, not only the distant light rays.
      if (distance > 45 ** 2) {
        changed++;
        if (body) bodyChanged++;
      }
    }
    return { changed: changed / (width * height), bodyChanged: bodyChanged / bodyPixels };
  }, [before, after].map(frame => frame.toString('base64')));
}

async function observeChest(page) {
  await page.addInitScript(() => {
    window.chestObservation = { cues: [], presses: [], releases: [], progress: [], statuses: [] };
    window.addEventListener('wordbuddies:chest-cue', event => {
      window.chestObservation.cues.push(event.detail);
    });
    window.addEventListener('pointerdown', () => {
      window.chestObservation.presses.push(performance.now());
    }, true);
    window.addEventListener('pointerup', () => {
      window.chestObservation.releases.push(performance.now());
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
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
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
  await page.evaluate(() => {
    window.chestOutputSamples = [];
    window.chestOutputTimer = setInterval(() => {
      window.chestOutputSamples.push(...window.audioOutputObservation.read());
    }, 16);
  });
  await pressChest(page);
  try {
    // Capture transient states in the page. Screenshot encoding can take longer
    // than the complete hold, and must not make an already-completed phase fail.
    await page.waitForFunction(() => window.chestObservation.cues.some(cue => cue.cue === 'release'),
      null, { timeout: 7000 });
  } finally {
    await page.mouse.up();
  }
  await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
  const completionObservation = await page.evaluate(() => ({
    chest: window.chestObservation,
    audio: { available: window.audioObservation.available, playbacks: window.audioObservation.playbacks }
  }));
  await testInfo.attach('chest-completion-observation', {
    body: JSON.stringify(completionObservation, null, 2), contentType: 'application/json'
  });
  const progressHistory = await page.evaluate(start => window.chestObservation.progress.slice(start), progressStart);
  const holdingProgress = progressHistory.filter(state => !state.hidden && state.phase === 'holding');
  expect(holdingProgress.some(state => state.percent >= 30 && state.text.includes('Hold to begin'))).toBe(true);
  expect(holdingProgress.every(state => state.percent <= 36),
    'The 1.2-second hold fills about one third of the bar before the opening phase').toBe(true);
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
  const idleCueCount = await page.evaluate(() => window.chestObservation.cues.length);
  const idleAudioCount = await page.evaluate(() => window.audioObservation.playbacks.length);
  const idleFirst = await openedChestFrame(page, testInfo, 'opened-glow-and-sway-first');
  let idleSecond, idleMotion;
  // A single pair can land on equal angles on either side of the six-second
  // sway. Observe at several phases instead of depending on screenshot timing.
  await expect.poll(async () => {
    idleSecond = await openedChestFrame(page);
    idleMotion = await openedChestMotion(page, idleFirst, idleSecond);
    return idleMotion.bodyChanged;
  }, { timeout: 8500, intervals: [700],
    message: 'The opened chest keeps gently swaying after its one-shot release has finished' }).toBeGreaterThan(0.003);
  await testInfo.attach('opened-glow-and-sway-later', { body: idleSecond, contentType: 'image/png' });
  await testInfo.attach('opened-chest-motion', {
    body: JSON.stringify(idleMotion, null, 2), contentType: 'application/json'
  });
  expect(await page.evaluate(() => window.chestObservation.cues.length), 'Ambient movement cannot replay opening cues').toBe(idleCueCount);
  expect((await page.evaluate(start => window.audioObservation.playbacks.slice(start), idleAudioCount)).filter(isChestSound),
    'The persistent glow and sway do not replay opening or reward sounds').toEqual([]);
  expect(await rewardSave(page), 'Ambient movement cannot award another piece').toBe(saved);

  const observation = await page.evaluate(() => window.chestObservation);
  const cues = observation.cues;
  expect(cues.filter(event => !isRhythmCue(event) && event.cue !== 'charge_step')
    .map(event => `${event.cue}:${event.step}`)).toEqual([
    'press:0', 'cancel:0', 'press:0', 'opening:0', 'anticipation:0', 'unlock:0', 'release:0', 'settle:0'
  ]);
  const steps = cues.filter(event => event.cue === 'charge_step');
  expect(steps.map(event => event.step), 'Each star lights once across the hold and opening phases').toEqual([1, 2, 3]);
  const opening = cues.find(event => event.cue === 'opening');
  const acceptedPress = cues.filter(event => event.cue === 'press').at(-1);
  const acceptedCues = cues.slice(cues.indexOf(acceptedPress));
  const holdPulses = acceptedCues.filter(event => event.cue === 'hold_pulse');
  expect(holdPulses.map(event => event.step), 'The accepted hold delivers all five physical beats')
    .toEqual(HOLD_PULSE_TIMES.map((_, index) => index + 1));
  const pulses = cues.filter(event => event.cue === 'tension_pulse');
  expect(pulses.map(event => event.step), 'The opening phase delivers all fifteen physical beats')
    .toEqual(PULSE_TIMES.map((_, index) => index + 1));
  const rhythm = acceptedCues.filter(isRhythmCue);
  expect(rhythm.map(event => event.cue), 'Confirmation joins five hold beats directly to fifteen opening beats')
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
  const anticipation = cues.find(event => event.cue === 'anticipation');
  const release = cues.find(event => event.cue === 'release');
  expect(cues.find(event => event.cue === 'unlock').at - anticipation.at,
    'The final held breath starts before the quiet latch cue').toBeGreaterThanOrEqual(100);
  expect(cues.find(event => event.cue === 'unlock').at - anticipation.at).toBeLessThanOrEqual(350);
  expect(openingStates[0].at - opening.at, '100 percent waits for the 2.16-second release').toBeGreaterThanOrEqual(2060);
  // These are browser-observed beat times. Allow frame delivery jitter while
  // still rejecting an early release or the former ten-second sequence.
  for (const [cue, milliseconds] of [['anticipation', 1940], ['unlock', 2080], ['release', 2160], ['settle', 2580]]) {
    const elapsed = cues.find(event => event.cue === cue).at - opening.at;
    expect(elapsed, `${cue} cannot precede its opening boundary`).toBeGreaterThanOrEqual(milliseconds - 100);
    expect(elapsed, `${cue} stays within the shorter opening sequence`).toBeLessThanOrEqual(milliseconds + 500);
  }
  const completed = observation.statuses.find(status => status.text === 'Chest opened! Ready for another adventure?');
  expect(completed).toBeDefined();
  const pointerUp = observation.releases.find(at => at >= release.at);
  expect(pointerUp, 'The gesture ends as soon as the visible chest starts opening').toBeDefined();
  expect(pointerUp - release.at, 'The test releases during the opening flash instead of waiting for completion').toBeLessThan(500);
  expect(completed.at - pointerUp, 'The remaining opening motion continues without a held pointer').toBeGreaterThan(1000);
  expect(completed.at - opening.at, 'Saving waits for the full 3.8-second opening sequence').toBeGreaterThanOrEqual(3700);
  expect(completed.at - acceptedPress.at, 'The full hold and opening last five seconds').toBeGreaterThanOrEqual(4900);
  expect(completed.at - acceptedPress.at, 'The completed chest no longer takes ten seconds').toBeLessThanOrEqual(6000);
  await testInfo.attach('chest-completion-timing', {
    body: JSON.stringify({ hold: opening.at - acceptedPress.at, automatic: completed.at - opening.at,
      pointerUpAfterRelease: pointerUp - release.at, completionAfterPointerUp: completed.at - pointerUp,
      total: completed.at - acceptedPress.at }, null, 2), contentType: 'application/json'
  });

  if (await page.evaluate(() => window.audioObservation.available)) {
    await expect.poll(() => page.evaluate(start => {
      const payoff = window.audioObservation.playbacks.filter(sound => sound.at >= start &&
        [0.68, 0.74].some(duration => Math.abs(sound.duration - duration) < 0.001));
      return payoff.length === 2 && payoff.every(sound => Number.isFinite(sound.endedAt));
    }, cues[0].at - 100), { message: 'The release and saved reward reach their natural end' }).toBe(true);
    const output = await page.evaluate(() => {
      clearInterval(window.chestOutputTimer);
      return window.chestOutputSamples;
    });
    const payoffOutput = output.filter(sample => sample.at >= release.at && sample.at <= completed.at + 850);
    expect(payoffOutput.length, 'The final release and receipt reach the output analyser').toBeGreaterThan(10);
    expect(Math.max(...payoffOutput.map(sample => sample.peak)),
      'Release, landing, reward and music retain combined output headroom').toBeLessThan(0.99);
    expect(Math.max(...payoffOutput.map(sample => sample.rms)),
      'The final payoff produces audible mixed output').toBeGreaterThan(0.02);
    const rollOutput = output.filter(sample => sample.at >= anticipation.at - 200 && sample.at < anticipation.at);
    const heldOutput = output.filter(sample => sample.at >= anticipation.at + 100 && sample.at < release.at);
    expect(heldOutput.length, 'The brief held breath reaches the actual output analyser').toBeGreaterThanOrEqual(2);
    const meanRms = samples => samples.reduce((sum, sample) => sum + sample.rms, 0) / samples.length;
    expect(meanRms(heldOutput), 'The held pose has a quieter sound bed than the preceding roll')
      .toBeLessThan(meanRms(rollOutput) * 0.70);
    expect(Math.max(...payoffOutput.filter(sample => sample.at < release.at + 300).map(sample => sample.rms)),
      'The opening impact restores strong contrast after the held breath').toBeGreaterThan(meanRms(heldOutput) * 2);
    await testInfo.attach('chest-held-breath-output', {
      body: JSON.stringify({ roll: rollOutput, held: heldOutput }, null, 2), contentType: 'application/json'
    });
    await testInfo.attach('chest-payoff-output', { body: JSON.stringify(payoffOutput, null, 2), contentType: 'application/json' });
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
    for (const duration of [0.68, 0.74]) {
      const sound = chestSounds.find(sound => hasDuration(sound, duration));
      // Godot may stop/disconnect the WebAudio source from its natural-ended
      // callback. Reject early stops, while allowing that completed cleanup.
      if (Number.isFinite(sound.stoppedAt)) {
        expect(sound.stopScheduledAt, 'Release bloom and saved reward finish before source cleanup')
          .toBeGreaterThanOrEqual(sound.scheduledAt + duration / sound.playbackRate - 0.01);
      }
      expect(Number.isFinite(sound.endedAt), 'Both payoff sources reach their natural end').toBe(true);
      expect(sound.endedAt - audioOnset(sound), 'The complete payoff envelope reaches the output')
        .toBeGreaterThanOrEqual(duration * 1000 - 100);
    }
    const beds = chestSounds.filter(sound => hasDuration(sound, 0.8));
    const cancel = cues.find(event => event.cue === 'cancel');
    const cancelledBed = beds.filter(sound => audioOnset(sound) < acceptedPress.at - 100);
    const acceptedBed = beds.filter(sound => audioOnset(sound) >= acceptedPress.at - 100);
    expectBedChain(cancelledBed, { press: cues[0], stop: cancel });
    expectBedChain(acceptedBed, { press: acceptedPress, stop: release, opening });
    expect(audioStop(acceptedBed.at(-1)), 'The pressure bed continues through unlocking until release')
      .toBeGreaterThan(cues.find(event => event.cue === 'unlock').at);
    const attacks = chestSounds.filter(sound => hasDuration(sound, 0.24));
    const attackCues = cues.filter(event => isRhythmCue(event) || event.cue === 'anticipation');
    expect(attacks, 'Every body beat has one source, followed by one final gathered breath').toHaveLength(attackCues.length);
    for (const [index, sound] of attacks.entries()) {
      expect(Math.abs(audioOnset(sound) - attackCues[index].at),
        `${attackCues[index].cue} ${attackCues[index].step} follows its physical cue`).toBeLessThanOrEqual(100);
    }
    const strikes = attacks.filter((_, index) => isRhythmCue(attackCues[index]));
    const transition = attacks[attackCues.findIndex(event => event.cue === 'anticipation')];
    const strikeCues = cues.filter(isRhythmCue);
    expect(strikes, 'Progress stars and confirmation add no extra percussive attacks').toHaveLength(strikeCues.length);
    // Match by cue order so a cancelled hold or a shared confirmation frame
    // cannot make a valid hold beat look like an extra opening attack.
    const cancelledStrikes = strikeCues.length - rhythm.length;
    const acceptedStrikes = strikes.slice(cancelledStrikes);
    expect(acceptedStrikes).toHaveLength(HOLD_PULSE_TIMES.length + PULSE_TIMES.length);
    expectAccelerating(acceptedStrikes.map(audioOnset), 'Actual WebAudio onsets accelerate from the hold into the final roll');
    for (const sound of acceptedStrikes) {
      expect(sound.playbackRate, 'Material strikes retain their physical pitch as their cadence accelerates')
        .toBeCloseTo(1, 3);
    }
    const textures = acceptedStrikes.map(sound => sound.fingerprint)
      .filter((fingerprint, index, all) => index === 0 || fingerprint !== all[index - 1]);
    expect(textures, 'The buildup develops from grounded impact through material detail into a bright final roll').toHaveLength(3);
    expect(new Set(textures).size, 'Each of the three buildup textures has distinct audible content').toBe(3);
    expect(textures.includes(transition.fingerprint), 'The held breath has its own material texture').toBe(false);
    const transitionEnd = transition.stoppedAt === undefined ?
      audioOnset(transition) + transition.duration / transition.playbackRate * 1000 : audioStop(transition);
    expect(transitionEnd, 'The quiet breath remains live through the latch cue without a source restart')
      .toBeGreaterThan(cues.find(event => event.cue === 'unlock').at);
    expect(transitionEnd, 'The transition resolves into the physical release instead of replaying later')
      .toBeLessThanOrEqual(release.at + 150);
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
  const saved = await rewardSave(page);
  // The static cosmetic gift dismisses after 1.1 seconds. Compare the persistent
  // chest only after that one-shot presentation has ended.
  await page.waitForTimeout(1200);
  const first = await openedChestFrame(page, testInfo, 'reduced-opened-static-glow-first');
  await page.waitForTimeout(1500);
  const second = await openedChestFrame(page, testInfo, 'reduced-opened-static-glow-later');
  expect(await openedChestMotion(page, first, second), 'Reduced motion retains a steady illuminated chest without sway or pulsing')
    .toEqual({ changed: 0, bodyChanged: 0 });
  expect(await page.evaluate(() => window.chestObservation.cues.length)).toBe(cues.length);
  expect(await rewardSave(page)).toBe(saved);
  expect(errors).toEqual([]);
});

test('release before the lid opens cancels but release at the opening flash completes once', async ({ page }, testInfo) => {
  await observeAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  await observeChest(page);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await chooseTheme(page, 1);
  await winMatch(page);
  const baseline = await pieces(page), unopenedSave = await rewardSave(page);
  const status = page.locator('#game-status'), progress = page.locator('#chest-progress');

  await pressChest(page);
  let released;
  try {
    // Cancel about two seconds into the performance, after the buildup has
    // started but before the opening flash. Screenshots must not delay release.
    await page.waitForFunction(() => {
      const cues = window.chestObservation.cues;
      const press = cues.find(cue => cue.cue === 'press');
      return press && performance.now() - press.at >= 2000 && cues.some(cue => cue.cue === 'opening');
    }, null, { timeout: 7000 });
    released = await page.evaluate(() => ({
      at: performance.now(), cues: window.chestObservation.cues,
      saved: localStorage.getItem('wordBuddies.medalProgress') || ''
    }));
  } finally {
    await page.mouse.up();
  }
  const press = released.cues.find(cue => cue.cue === 'press');
  expect(released.at - press.at, 'Cancellation happens after the initial hold').toBeGreaterThanOrEqual(1900);
  expect(released.cues.some(cue => cue.cue === 'release'), 'The lid has not opened yet').toBe(false);
  expect(released.saved).toBe(unopenedSave);
  await expect(status).toHaveText('You did it! Hold to open your chest!');
  await expect(progress).toHaveAttribute('hidden', '');
  await expect(progress).toHaveAttribute('aria-valuenow', '0');
  expect(await rewardSave(page)).toBe(unopenedSave);
  const cancelled = await page.evaluate(() => ({
    cues: window.chestObservation.cues.length, sounds: window.audioObservation.playbacks.length
  }));
  // Cross the cancelled attempt's original completion deadline. It must not
  // resume its cues, sounds, or pending save while the chest is closed.
  await page.waitForTimeout(Math.max(500, 5600 - (released.at - press.at)));
  expect(await page.evaluate(() => window.chestObservation.cues.length)).toBe(cancelled.cues);
  expect((await page.evaluate(start => window.audioObservation.playbacks.slice(start), cancelled.sounds)).filter(isChestSound),
    'A cancelled buildup cannot replay a material cue or reward accent').toEqual([]);
  await expect(status).toHaveText('You did it! Hold to open your chest!');
  expect(await rewardSave(page), 'The abandoned buildup cannot save at its former deadline').toBe(unopenedSave);
  await testInfo.attach('released-before-opening-flash', {
    body: JSON.stringify(released, null, 2), contentType: 'application/json'
  });
  await screenshot(page, testInfo, 'cancelled-before-opening-flash');

  await pressChest(page);
  let committed;
  try {
    await page.waitForFunction(() => window.chestObservation.cues.some(cue => cue.cue === 'release'),
      null, { timeout: 7000 });
    committed = await page.evaluate(() => ({
      at: performance.now(), cues: window.chestObservation.cues,
      status: document.getElementById('game-status').textContent,
      saved: localStorage.getItem('wordBuddies.medalProgress') || ''
    }));
  } finally {
    await page.mouse.up();
  }
  expect(committed.saved, 'The opening flash commits the gesture without saving before motion completes').toBe(unopenedSave);
  expect(committed.status, 'The opening flash tells the player the gesture is complete')
    .toBe('You did it! Your chest is open. You can let go!');
  expect(committed.cues.some(cue => cue.cue === 'settle'), 'The pointer is released before settling').toBe(false);
  await expect(status).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
  expect(await pieces(page)).toBe(baseline + 1);
  const saved = await rewardSave(page);
  await page.waitForTimeout(500);
  expect(await rewardSave(page)).toBe(saved);
  const cues = await page.evaluate(() => window.chestObservation.cues);
  expect(cues.filter(cue => cue.cue === 'press')).toHaveLength(2);
  expect(cues.filter(cue => cue.cue === 'cancel')).toHaveLength(1);
  expect(cues.filter(cue => cue.cue === 'opening')).toHaveLength(2);
  expect(cues.filter(cue => cue.cue === 'release')).toHaveLength(1);
  expect(cues.filter(cue => cue.cue === 'settle')).toHaveLength(1);
  expect((await page.evaluate(() => window.chestObservation.statuses))
    .filter(state => state.text === 'Chest opened! Ready for another adventure?')).toHaveLength(1);
  await testInfo.attach('released-at-opening-flash', {
    body: JSON.stringify(committed, null, 2), contentType: 'application/json'
  });
  await screenshot(page, testInfo, 'opened-after-physical-release');
  expect(errors).toEqual([]);
});

for (const interruption of ['background', 'focus loss']) {
  test(`${interruption} cancels opening without a reward or delayed replay`, async ({ page }, testInfo) => {
    await observeAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
    await observeChest(page);
    const errors = await openGame(page, { reducedMotion: 'no-preference' });
    await chooseTheme(page, 1);
    await winMatch(page);
    const baseline = await pieces(page), unopenedSave = await rewardSave(page);
    const status = page.locator('#game-status'), progress = page.locator('#chest-progress');
    await pressChest(page);
    let interrupted, cancelled;
    try {
      await expect.poll(() => page.evaluate(() => window.chestObservation.cues.filter(cue => cue.cue === 'tension_pulse').length),
        { intervals: [20, 30], timeout: 4000 }).toBeGreaterThanOrEqual(2);
      // Exercise the existing host lifecycle callback, without directly invoking
      // chest state or relying on the runner's actual tab focus.
      interrupted = await page.evaluate(interruption => {
        const state = { at: performance.now(), cues: window.chestObservation.cues.length,
          sounds: window.audioObservation.playbacks.length };
        if (interruption === 'background') {
          Object.defineProperty(document, 'hidden', { configurable: true, value: true });
          document.dispatchEvent(new Event('visibilitychange'));
        } else {
          window.dispatchEvent(new Event('blur'));
        }
        return state;
      }, interruption);
      // The lifecycle event itself must cancel, before the pointer is released.
      await expect(status).toHaveText('You did it! Hold to open your chest!');
      await expect(progress).toHaveAttribute('hidden', '');
      await expect(progress).toHaveAttribute('aria-valuenow', '0');
      expect(await rewardSave(page)).toBe(unopenedSave);
      cancelled = await page.evaluate(() => ({ cues: window.chestObservation.cues.length,
        sounds: window.audioObservation.playbacks.length }));
      await page.waitForTimeout(4200);
      await expect(status).toHaveText('You did it! Hold to open your chest!');
      expect(await pieces(page)).toBe(baseline);
    } finally {
      await page.mouse.up();
      if (interruption === 'background') {
        await page.evaluate(() => {
          delete document.hidden;
          document.dispatchEvent(new Event('visibilitychange'));
        });
      } else {
        await page.evaluate(() => window.dispatchEvent(new Event('focus')));
      }
    }
    await page.waitForTimeout(500);
    expect(await page.evaluate(() => window.chestObservation.cues.length), 'Returning cannot catch up old tension, unlock or release cues').toBe(cancelled.cues);
    const playbacks = await page.evaluate(() => window.audioObservation.playbacks);
    expect(playbacks.slice(cancelled.sounds).filter(isChestSound), 'The cancelled opening and return cannot replay material sounds or the reward accent').toEqual([]);
    if (interruption === 'background') {
      expect(cancelled.cues, 'Background cancellation stays silent').toBe(interrupted.cues);
      expect(playbacks.slice(interrupted.sounds).filter(isChestSound)).toEqual([]);
    }
    if (await page.evaluate(() => window.audioObservation.available)) {
      const cues = await page.evaluate(() => window.chestObservation.cues);
      const opening = cues.find(cue => cue.cue === 'opening'), press = cues.find(cue => cue.cue === 'press');
      const bed = playbacks.filter(sound => hasDuration(sound, 0.8) && audioOnset(sound) >= press.at - 100);
      expectBedChain(bed, { press, stop: interrupted, opening });
    }
    expect(await rewardSave(page)).toBe(unopenedSave);
    await screenshot(page, testInfo, `${interruption.replace(' ', '-')}-cancelled`);
    await pressChest(page);
    try {
      await expect(status).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
    } finally {
      await page.mouse.up();
    }
    expect(await pieces(page)).toBe(baseline + 1);
    const saved = await rewardSave(page);
    await page.waitForTimeout(500);
    expect(await rewardSave(page)).toBe(saved);
    expect(errors).toEqual([]);
  });
}

test('background after the opening flash silently saves once without replay on return', async ({ page }, testInfo) => {
  await observeAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  await observeChest(page);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await chooseTheme(page, 1);
  await winMatch(page);
  const baseline = await pieces(page), unopenedSave = await rewardSave(page);
  const status = page.locator('#game-status'), progress = page.locator('#chest-progress');
  let hidden;
  await pressChest(page);
  try {
    await page.waitForFunction(() => window.chestObservation.cues.some(cue => cue.cue === 'release'),
      null, { timeout: 7000 });
    // Interrupt immediately after the visible release, while its remaining
    // motion has not yet saved. The host must preserve that committed reward.
    hidden = await page.evaluate(() => {
      const state = { at: performance.now(), cues: window.chestObservation.cues.length,
        sounds: window.audioObservation.playbacks.length,
        saved: localStorage.getItem('wordBuddies.medalProgress') || '',
        status: document.getElementById('game-status').textContent };
      Object.defineProperty(document, 'hidden', { configurable: true, value: true });
      document.dispatchEvent(new Event('visibilitychange'));
      return state;
    });
    expect(hidden.saved).toBe(unopenedSave);
    expect(hidden.status).toBe('You did it! Your chest is open. You can let go!');
    await expect(status).toHaveText('Chest opened! Ready for another adventure?');
    await expect(progress).toHaveAttribute('hidden', '');
    expect(await pieces(page)).toBe(baseline + 1);
  } finally {
    await page.mouse.up();
    await page.evaluate(() => {
      delete document.hidden;
      document.dispatchEvent(new Event('visibilitychange'));
    });
  }
  const saved = await rewardSave(page);
  // Pass the original settling/completion deadlines after returning. No old
  // cue, reward accent, or save may replay after silent background completion.
  await page.waitForTimeout(2000);
  expect(await page.evaluate(() => window.chestObservation.cues.length)).toBe(hidden.cues);
  const playbacks = await page.evaluate(() => window.audioObservation.playbacks);
  expect(playbacks.slice(hidden.sounds).filter(isChestSound), 'Background completion and return stay silent').toEqual([]);
  const cues = await page.evaluate(() => window.chestObservation.cues);
  expect(cues.filter(cue => cue.cue === 'cancel')).toEqual([]);
  expect(cues.filter(cue => cue.cue === 'release')).toHaveLength(1);
  if (await page.evaluate(() => window.audioObservation.available)) {
    const press = cues.find(cue => cue.cue === 'press'), opening = cues.find(cue => cue.cue === 'opening');
    const release = cues.find(cue => cue.cue === 'release');
    const bed = playbacks.filter(sound => hasDuration(sound, 0.8) && audioOnset(sound) >= press.at - 100);
    expectBedChain(bed, { press, stop: release, opening });
  }
  await expect(status).toHaveText('Chest opened! Ready for another adventure?');
  expect(await rewardSave(page)).toBe(saved);
  await testInfo.attach('background-after-opening-flash', {
    body: JSON.stringify(hidden, null, 2), contentType: 'application/json'
  });
  await screenshot(page, testInfo, 'opened-after-backgrounded-release');
  expect(errors).toEqual([]);
});

test('bundled themed chest samples stay audible offline without delaying rewards', async ({ page, context, browserName }, testInfo) => {
  const requests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  await observeChest(page);
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await context.setOffline(true);
  try {
    // Visit an unplayed world only after disconnecting. Its complete authored
    // bank must already be in the pack, including the sustained material bed.
    await chooseTheme(page, 5);
    await winMatch(page);
    const baseline = await pieces(page);
    const available = await page.evaluate(() => window.audioObservation.available);
    if (browserName === 'chromium') expect(available).toBe(true);
    await pressChest(page, 200);
    expect(await pieces(page)).toBe(baseline);
    await pressChest(page);
    if (available) await expectOutputEnergy(page);
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
    await page.mouse.up();
    expect(await pieces(page)).toBe(baseline + 1);
    const cues = await page.evaluate(() => window.chestObservation.cues);
    expect(cues.every(event => event.theme === 'space')).toBe(true);
    expect(cues.filter(event => event.cue === 'release')).toHaveLength(1);
    if (available) {
      const playbacks = await page.evaluate(() => window.audioObservation.playbacks);
      const feedback = playbacks.filter(sound => sound.at >= cues[0].at - 100 && isChestSound(sound));
      expect(feedback.filter(sound => hasDuration(sound, 0.19)), 'Both presses play the authored sample').toHaveLength(2);
      for (const duration of [0.22, 0.31, 0.68, 0.48, 0.74]) {
        expect(feedback.filter(sound => hasDuration(sound, duration)), 'Cancel, unlock, release, settle and reward each play once').toHaveLength(1);
      }
      expect(feedback.filter(sound => hasDuration(sound, 0.8)).length, 'The authored charge bed loops while offline').toBeGreaterThanOrEqual(2);
      expect(feedback.filter(sound => hasDuration(sound, 0.24)).length, 'The complete buildup remains audible').toBeGreaterThanOrEqual(20);
      for (const sound of feedback) {
        expect(sound.contextState).toBe('running');
        expect(sound.fingerprint).toBeTruthy();
        expect(sound.peak).toBeGreaterThan(0.01);
      }
      await testInfo.attach('bundled-offline-chest-audio', { body: JSON.stringify(feedback, null, 2), contentType: 'application/json' });
    }
    const saved = await rewardSave(page);
    await page.waitForTimeout(400);
    expect(await rewardSave(page)).toBe(saved);
    expect(requests, 'Offline chest playback never attempts an audio HTTP request').toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await page.mouse.up();
    await context.setOffline(false);
  }
});
