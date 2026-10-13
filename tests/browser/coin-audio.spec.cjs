const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const {
  openGame, enterGame, openModeMenu, chooseMode, activateLibraryControl, metrics, tap
} = require('./game-ui.cjs');
const {
  watchAudioRequests, observeOutputAudio, expectOutputEnergy, expectRecording, recordingTiming
} = require('./bundled-audio.cjs');
const vocabulary = require('../../words.json');

const COIN_CLIP = 'assets/audio/coins/collect.wav';
const PRESENTATION_KEY = 'pipAndWords.presentation.v1';
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const playbackIndex = page => page.evaluate(() => window.audioObservation.playbacks.length);
const playbacksSince = (page, from) => page.evaluate(index => window.audioObservation.playbacks.slice(index), from);
const matching = (sounds, recording) => sounds.filter(sound => sound.fingerprint === recording.fingerprint);

test.use({ deviceScaleFactor: 1, trace: 'off',
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

async function pressRect(page, rect) {
  const [x, y, width, height] = rect;
  await tap(page, x + width / 2, y + height / 2);
}

async function start(page, reducedMotion) {
  // Each Playwright context owns an isolated save. Keep the same current-age
  // vocabulary while exercising the production merge and wallet paths.
  await page.addInitScript(() => {
    const key = 'growWithPip.growth.v1';
    if (localStorage.getItem(key) === null) localStorage.setItem(key,
      '[growth]\nversion=3\nlevel=0\nage=0\nstreaks={}\nmastered_words=[]\nreceipts=[]\n');
  });
  const errors = await openGame(page, { reducedMotion, mode: 'word_jelly' });
  await settled(page);
  return errors;
}

async function settled(page) {
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.mode === 'word_jelly' && !state.paused && state.phase === 'playing' &&
      state.tiles.length >= 2 && state.tiles.every(tile => tile.settled) && !state.reward_presentation.active;
  }, { timeout: 20000, message: 'The real Word Jelly board is ready for a trusted gesture' }).toBe(true);
}

async function makeWord(page) {
  const words = new Map(vocabulary.filter(word => word.min_age === 3).map(word => [word.text.toLowerCase(), word]));
  let pair;
  for (let attempt = 0; attempt < 4; attempt++) {
    await settled(page);
    const state = await jelly(page);
    const roots = state.tiles.filter(tile => tile.visible && tile.settled && tile.mass === 1);
    // Prefer unmarked roots so this audio test does not start an unrelated chest
    // celebration, but keep the regular supply available if no such pair exists.
    const candidates = [];
    for (const first of roots) for (const second of roots) {
      if (first.id !== second.id && words.has((first.text + second.text).toLowerCase())) candidates.push([first, second]);
    }
    candidates.sort((a, b) => a[0].fragments + a[1].fragments - b[0].fragments - b[1].fragments);
    if (candidates.length) { pair = candidates[0]; break; }
    expect(state.preview.enabled).toBe(true);
    await pressRect(page, state.preview.rect);
    await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
  }
  expect(pair, 'The current-age supply contains a complete two-root word').toBeTruthy();
  const bounds = await metrics(page), before = await jelly(page);
  const center = tile => ({ x: bounds.x + (tile.rect[0] + tile.rect[2] / 2) * bounds.scale,
    y: bounds.y + (tile.rect[1] + tile.rect[3] / 2) * bounds.scale });
  const from = center(pair[0]), to = center(pair[1]);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(pair[0].id);
    await page.mouse.move(to.x, to.y, { steps: 10 });
    await expect.poll(async () => (await jelly(page)).drag.target).toBe(pair[1].id);
  } finally {
    await page.mouse.up();
  }
  let merged;
  await expect.poll(async () => {
    const state = await jelly(page);
    merged = state.tiles.find(tile => !before.tiles.some(old => old.id === tile.id) &&
      tile.text === pair[0].text + pair[1].text && tile.mass === 2 && tile.settled);
    return Boolean(merged?.word?.id);
  }, { message: 'The real drag produces a valid word without collecting it' }).toBe(true);
  return merged;
}

async function observeWallet(page) {
  await page.evaluate(() => {
    const element = document.getElementById('coin-status');
    window.coinAudioTimeline = [];
    const record = () => window.coinAudioTimeline.push({ at: performance.now(),
      ...JSON.parse(element.dataset.snapshot || '{}') });
    window.coinAudioObserver?.disconnect();
    window.coinAudioObserver = new MutationObserver(record);
    window.coinAudioObserver.observe(element, { attributes: true, attributeFilter: ['data-snapshot'] });
    record();
  });
}

async function collect(page, count) {
  const before = await jelly(page);
  expect(before.collect_button.count).toBe(count);
  expect(before.collect_button.enabled).toBe(true);
  await pressRect(page, before.collect_button.rect);
  return before;
}

async function toggleHomeSound(page, browserName, mobile) {
  const bounds = await metrics(page);
  const control = bounds.library.controls.find(item => item.name === 'LibrarySound');
  if (!control.fully_visible && !(browserName === 'webkit' && mobile)) {
    const [x, y, width, height] = bounds.library.viewport_rect;
    await page.mouse.move(bounds.x + (x + width / 2) * bounds.scale,
      bounds.y + (y + height / 2) * bounds.scale);
    await page.mouse.wheel(0, 3000);
    await expect.poll(async () => (await metrics(page)).library.controls
      .find(item => item.name === 'LibrarySound').fully_visible).toBe(true);
  }
  await activateLibraryControl(page, 'LibrarySound');
}

function expectNoPronunciation(sounds, words) {
  for (const word of words) {
    const timing = recordingTiming(word.audio);
    expect(sounds.filter(sound => Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate),
      `Collect keeps ${word.text} pronunciation silent, including the final word`).toEqual([]);
  }
}

function expectReleaseAndArrival(sounds, timeline, balance, reducedMotion, maximum) {
  const launches = timeline.filter((frame, index, frames) => frame.active && frame.balance >
    (index ? frames[index - 1].balance : balance));
  const arrivals = timeline.filter((frame, index, frames) => index > 0 &&
    frame.arrived_balance > frames[index - 1].arrived_balance);
  expect(launches.length, 'A visual coin flight begins for the collected word').toBeGreaterThan(0);
  expect(arrivals.length, 'The same flight eventually deposits its coins').toBeGreaterThan(0);
  expect(sounds.length, 'Coin appearance and later arrival both have feedback').toBeGreaterThanOrEqual(2);
  expect(sounds.length, 'Launches and dense arrivals share one bounded cadence').toBeLessThanOrEqual(maximum);
  expect(Math.abs(sounds[0].at - launches[0].at),
    'The first Kenney accent accompanies the appearing coins, including publication latency').toBeLessThan(180);
  expect(arrivals[0].at - sounds[0].at,
    'The initial accent is audible before the later HUD deposit').toBeGreaterThan(reducedMotion === 'reduce' ? 50 : 650);
  expect(sounds.some(sound => arrivals.some(frame => Math.abs(frame.at - sound.at) < 180)),
    'The later HUD deposit retains its own Kenney accent').toBe(true);
  for (const [index, sound] of sounds.entries()) {
    expect([...launches, ...arrivals].some(frame => Math.abs(frame.at - sound.at) < 180),
      'Each coin accent belongs to a visible launch or actual HUD deposit').toBe(true);
    if (index) expect(sound.at - sounds[index - 1].at,
      'Release and arrival share the existing 100 ms cadence without per-frame restarts').toBeGreaterThanOrEqual(75);
  }
  return { launches, arrivals };
}

for (const reducedMotion of ['no-preference', 'reduce']) {
  test(`Jelly coin appearance and deposits play bundled Kenney feedback with ${reducedMotion} motion`, async ({ page, context, browserName }, info) => {
    test.setTimeout(180000);
    const requests = watchAudioRequests(page), evidence = { reducedMotion };
    await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
    const errors = await start(page, reducedMotion);
    const available = await page.evaluate(() => window.audioObservation.available);
    if (browserName === 'chromium') expect(available).toBe(true);
    test.skip(!available, 'This browser runtime has no WebAudio.');
    const single = await makeWord(page);
    await page.waitForTimeout(400);
    const singleBalance = (await wallet(page)).balance;
    await observeWallet(page);
    const singleFrom = await playbackIndex(page);
    await context.setOffline(true);
    try {
      // A deliberate tap uses the real valid-word collection path. Its normal
      // word pronunciation remains separate from the new coin launch accent.
      await pressRect(page, single.rect);
      evidence.recording = await expectRecording(page, singleFrom, COIN_CLIP);
      evidence.singleOutput = await expectOutputEnergy(page);
      await expect.poll(async () => (await wallet(page)).arrived_balance).toBe(singleBalance + 100);
      await expect.poll(async () => (await wallet(page)).active).toBe(false);
      await page.waitForTimeout(450);
      evidence.single = { playbacks: await playbacksSince(page, singleFrom),
        timeline: await page.evaluate(() => window.coinAudioTimeline), word: single.word.id };
      evidence.single.coinSounds = matching(evidence.single.playbacks, evidence.recording);
      evidence.single.events = expectReleaseAndArrival(evidence.single.coinSounds,
        evidence.single.timeline, singleBalance, reducedMotion, reducedMotion === 'reduce' ? 2 : 6);
      expect((await wallet(page)).balance, 'A tapped word credits its coins once').toBe(singleBalance + 100);

      const words = [];
      for (let index = 0; index < 3; index++) words.push(await makeWord(page));
      // Wait for the final merge cue to finish before delimiting Collect audio.
      await page.waitForTimeout(400);
      const balance = (await wallet(page)).balance;
      await observeWallet(page);
      const from = await playbackIndex(page);
      await collect(page, 3);
      const batchRecording = await expectRecording(page, from, COIN_CLIP);
      expect(batchRecording.fingerprint, 'Single taps and Collect use the same bundled Kenney recording')
        .toBe(evidence.recording.fingerprint);
      expect(evidence.recording.fingerprint, 'The bundled recording has observed PCM identity').toBeTruthy();
      expect(evidence.recording.peak, 'The selected Kenney recording contains nonzero samples').toBeGreaterThan(0.01);
      evidence.output = await expectOutputEnergy(page);
      await expect.poll(async () => (await wallet(page)).active).toBe(false);
      await expect.poll(async () => (await wallet(page)).arrived_balance).toBe(balance + 300);
      await page.waitForTimeout(450);
      evidence.playbacks = await playbacksSince(page, from);
      evidence.timeline = await page.evaluate(() => window.coinAudioTimeline);
      evidence.coinSounds = matching(evidence.playbacks, evidence.recording);
      const batch = (await jelly(page)).collection_batch;
      expect(batch.completed).toBe(3);
      expect(batch.elapsed, 'Coin feedback preserves the 100 ms word collection rhythm').toBeCloseTo(0.3, 6);
      expectNoPronunciation(evidence.playbacks, words.map(tile => tile.word));
      evidence.events = expectReleaseAndArrival(evidence.coinSounds, evidence.timeline, balance,
        reducedMotion, reducedMotion === 'reduce' ? 5 : 10);
      const finishedFrom = await playbackIndex(page);
      await page.waitForTimeout(400);
      expect(matching(await playbacksSince(page, finishedFrom), evidence.recording),
        'Finishing the deposit never replays its sound').toEqual([]);

      if (reducedMotion === 'no-preference') {
        await makeWord(page);
        await page.waitForTimeout(400);
        const interruptedFrom = await playbackIndex(page), beforeInterrupt = (await wallet(page)).balance;
        await collect(page, 1);
        await expect.poll(async () => (await wallet(page)).balance).toBe(beforeInterrupt + 100);
        // Browser protocol/renderer latency may allow valid arrivals before
        // Home. Delimit at the actual Home transition instead of treating
        // those earned cues as a cancellation failure.
        await openModeMenu(page);
        const homeFrom = await playbackIndex(page);
        await expect.poll(async () => (await wallet(page)).active).toBe(false);
        await page.waitForTimeout(650);
        evidence.interrupted = await playbacksSince(page, interruptedFrom);
        expect(matching(await playbacksSince(page, homeFrom), evidence.recording),
          'Home never replays settled coins or starts delayed deposit cues').toEqual([]);
        expect(matching(evidence.interrupted, evidence.recording).filter(sound =>
          sound.stoppedAt === undefined && sound.endedAt === undefined),
        'No coin recording keeps playing behind Home').toEqual([]);
        expect((await wallet(page)).arrived_balance).toBe(beforeInterrupt + 100);

        await toggleHomeSound(page, browserName, info.project.use.isMobile);
        await expect.poll(() => page.evaluate(key => JSON.parse(localStorage.getItem(key)).muted, PRESENTATION_KEY)).toBe(true);
        await chooseMode(page, 'word_jelly');
        await makeWord(page);
        const mutedFrom = await playbackIndex(page), mutedBalance = (await wallet(page)).balance;
        await collect(page, 1);
        await expect.poll(async () => (await wallet(page)).arrived_balance).toBe(mutedBalance + 100);
        await expect.poll(async () => (await wallet(page)).active).toBe(false);
        evidence.muted = await playbacksSince(page, mutedFrom);
        expect(evidence.muted, 'Mute prevents coin, collection, and word recordings from starting').toEqual([]);

        await openModeMenu(page);
        await toggleHomeSound(page, browserName, info.project.use.isMobile);
        await expect.poll(() => page.evaluate(key => JSON.parse(localStorage.getItem(key)).muted, PRESENTATION_KEY)).toBe(false);
      }
    } finally {
      await context.setOffline(false);
      const evidencePath = info.outputPath('coin-browser-audio.json');
      fs.writeFileSync(evidencePath, JSON.stringify(evidence, null, 2));
      await info.attach('coin-browser-audio.json', { path: evidencePath, contentType: 'application/json' });
    }
    const finalBalance = (await wallet(page)).balance;
    await page.reload();
    await enterGame(page, { home: true });
    await expect.poll(async () => (await wallet(page)).arrived_balance).toBe(finalBalance);
    await page.waitForTimeout(500);
    const restored = await playbacksSince(page, 0);
    expect(matching(restored, evidence.recording), 'Restoring an owned wallet balance never replays coin feedback').toEqual([]);
    expect(requests, 'All coin and game feedback plays from already bundled recordings').toEqual([]);
    expect(errors).toEqual([]);
  });
}
