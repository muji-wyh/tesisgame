const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const {
  openGame, enterGame, openModeMenu, chooseMode, activateLibraryControl, metrics, tap
} = require('./game-ui.cjs');
const {
  watchAudioRequests, observeOutputAudio, expectRecording, recordingTiming
} = require('./bundled-audio.cjs');
const { collectionCoins } = require('./word-jelly-rewards.cjs');
const { roomState } = require('./pop-treasure-ui.cjs');

const COIN_CLIPS = { release: 'assets/audio/coins/release.wav', arrival: 'assets/audio/coins/collect.wav' };
const PRESENTATION_KEY = 'pipAndWords.presentation.v1';
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const playbackIndex = page => page.evaluate(() => window.audioObservation.playbacks.length);
const playbacksSince = (page, from) => page.evaluate(index => window.audioObservation.playbacks.slice(index), from);

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

async function makeWord(page, { marked = false } = {}) {
  let pair;
  for (let attempt = 0; attempt < 4; attempt++) {
    await settled(page);
    const state = await jelly(page);
    const roots = state.tiles.filter(tile => tile.visible && tile.settled && tile.jelly_kind === 'root' && tile.word_candidate?.id);
    // One marked word verifies fragment retention; other trials prefer unmarked
    // roots to avoid an unrelated chest celebration in the audio observation.
    const candidates = [];
    for (const first of roots) for (const second of state.tiles) {
      if (second.visible && second.settled && second.jelly_kind === 'picture' &&
        second.image_word?.id === first.word_candidate.id) candidates.push([first, second]);
    }
    candidates.sort((a, b) => (marked ? -1 : 1) * (a[0].fragments + a[1].fragments - b[0].fragments - b[1].fragments));
    if (candidates.length) { pair = candidates[0]; break; }
    expect(state.preview.enabled).toBe(true);
    await pressRect(page, state.preview.rect);
    await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
  }
  expect(pair, 'The current-age supply contains a whole-word root and its exact picture').toBeTruthy();
  const bounds = await metrics(page), before = await jelly(page);
  const center = tile => ({ x: bounds.x + (tile.rect[0] + tile.rect[2] / 2) * bounds.scale,
    y: bounds.y + (tile.rect[1] + tile.rect[3] / 2) * bounds.scale });
  const from = center(pair[0]), to = center(pair[1]);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await page.mouse.move(from.x, from.y - 16);
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(pair[0].id);
    await page.mouse.move(to.x, to.y, { steps: 10 });
    await expect.poll(async () => {
      const current = await jelly(page), target = current.tiles.find(tile => tile.id === pair[1].id);
      if (!target?.settled) return false;
      if (current.drag.target === pair[1].id) return true;
      const next = center(target);
      await page.mouse.move(next.x, next.y, { steps: 4 });
      return false;
    }, { message: 'The drag follows its picture after lifting a supporting root' }).toBe(true);
  } finally {
    await page.mouse.up();
  }
  let merged;
  await expect.poll(async () => {
    const state = await jelly(page);
    merged = state.tiles.find(tile => !before.tiles.some(old => old.id === tile.id) &&
      tile.word?.id === pair[0].word_candidate.id && tile.merge_level === 1 &&
      tile.mass === pair[0].mass + pair[1].mass && tile.settled);
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

function coinRecordings(sounds) {
  return sounds.filter(sound => Object.values(COIN_CLIPS).some(path => {
    const timing = recordingTiming(path);
    return Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate;
  }));
}

for (const reducedMotion of ['no-preference', 'reduce']) {
  test(`Lv1 Jelly collection stays coin-free with ${reducedMotion} motion`, async ({ page, context, browserName }, info) => {
    test.setTimeout(180000);
    const requests = watchAudioRequests(page), evidence = { reducedMotion, collections: [] };
    await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
    const errors = await start(page, reducedMotion);
    const available = await page.evaluate(() => window.audioObservation.available);
    if (browserName === 'chromium') expect(available).toBe(true);
    evidence.audioAvailable = available;
    if (!available) info.annotations.push({ type: 'audio', description: 'WebAudio unavailable; collection and wallet flow remain verified.' });
    await context.setOffline(true);
    try {
      const single = await makeWord(page, { marked: true });
      expect(single.fragments, 'The normal collection route includes a real carried fragment').toBeGreaterThan(0);
      const collectAndCheck = async (tiles, batch) => {
        const before = await jelly(page), startingWallet = await wallet(page);
        const growth = await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'));
        await observeWallet(page);
        const from = await playbackIndex(page);
        if (batch) await collect(page, tiles.length);
        else await pressRect(page, before.tiles.find(tile => tile.id === tiles[0].id).rect);
        await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + tiles.length);
        const after = await jelly(page), earned = collectionCoins(after, before, tiles);
        expect(tiles.every(tile => tile.merge_level === 1)).toBe(true);
        expect(earned, 'Lv1 collection never launches a bonus coin reward').toBe(0);
        await expect.poll(async () => (await wallet(page)).arrived_balance).toBe(startingWallet.balance + earned);
        await expect.poll(async () => (await wallet(page)).active).toBe(false);
        expect(after.fragment_count).toBe(before.fragment_count + tiles.reduce((sum, tile) => sum + tile.fragments, 0));
        expect(after.tiles.some(tile => tiles.some(removed => removed.id === tile.id))).toBe(false);
        await expect.poll(() => page.evaluate(() => localStorage.getItem('growWithPip.growth.v1')),
          { message: 'Learning progress is retained even when collection drops no coins' }).not.toBe(growth);
        await page.waitForTimeout(500);
        const sounds = await playbacksSince(page, from), timeline = await page.evaluate(() => window.coinAudioTimeline);
        const trial = { batch, earned, words: tiles.map(tile => tile.word.id), sounds, timeline };
        evidence.collections.push(trial);
        if (available) expect(coinRecordings(sounds), 'A Lv1 collection plays neither coin appearance nor deposit recording').toEqual([]);
        expect(timeline.every(frame => !frame.active && frame.balance === startingWallet.balance &&
          frame.arrived_balance === startingWallet.arrived_balance), 'Lv1 collection launches no phantom coin flight').toBe(true);
        if (batch) {
          if (available) expectNoPronunciation(sounds, tiles.map(tile => tile.word));
          expect(after.collection_batch.completed).toBe(tiles.length);
          expect(after.collection_batch.elapsed).toBeCloseTo(tiles.length * 0.25, 6);
        }
        expect((await wallet(page)).balance, 'Presentation frames cannot repeat a lucky reward').toBe(startingWallet.balance + earned);
      };
      await collectAndCheck([single], false);
      const words = [];
      for (let index = 0; index < 3; index++) words.push(await makeWord(page));
      await collectAndCheck(words, true);
      const balance = (await wallet(page)).balance;
      await openModeMenu(page);
      const homeFrom = await playbackIndex(page);
      await page.waitForTimeout(500);
      if (available) expect(coinRecordings(await playbacksSince(page, homeFrom)), 'Home does not invent delayed coin feedback').toEqual([]);
      expect((await wallet(page)).balance).toBe(balance);
      if (!info.project.use.isMobile) {
        await toggleHomeSound(page, browserName, false);
        await expect.poll(() => page.evaluate(key => JSON.parse(localStorage.getItem(key)).muted, PRESENTATION_KEY)).toBe(true);
        await chooseMode(page, 'word_jelly');
        const muted = await makeWord(page), mutedBefore = await jelly(page), mutedBalance = (await wallet(page)).balance;
        const mutedFrom = await playbackIndex(page);
        await collect(page, 1);
        await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(mutedBefore.cleared_pairs + 1);
        const mutedCoins = collectionCoins(await jelly(page), mutedBefore, [muted]);
        await expect.poll(async () => (await wallet(page)).arrived_balance).toBe(mutedBalance + mutedCoins);
        await page.waitForTimeout(400);
        expect(await playbacksSince(page, mutedFrom), 'Mute prevents collection, coin, and word recordings').toEqual([]);
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
    expect(requests, 'Collection feedback stays bundled and offline').toEqual([]);
    expect(errors).toEqual([]);
  });
}

test('an earned chest still pays its complete guaranteed coin reward with distinct launch and arrival sounds', async ({ page, browserName }, info) => {
  test.setTimeout(90000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  await page.addInitScript(() => {
    window.SpeechRecognition = undefined;
    window.webkitSpeechRecognition = undefined;
    if (!localStorage.getItem('wordBuddies.popRewards')) localStorage.setItem('wordBuddies.popRewards',
      '[treasure]\nversion=1\nround_id="coin-economy-chest"\nentries=[{"theme":"spring","opened":false}]\nreceipts=[]\n');
  });
  await page.goto('/');
  await enterGame(page, { home: true });
  await chooseMode(page, 'pop');
  await expect.poll(async () => { const room = await roomState(page); return room.visible && room.chests.length === 1; }).toBe(true);
  const opening = await roomState(page), balance = (await wallet(page)).balance;
  const rect = opening.chests[0].rect, bounds = await metrics(page);
  await observeWallet(page);
  const from = await playbackIndex(page), audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(audioAvailable).toBe(true);
  if (!audioAvailable) info.annotations.push({ type: 'audio', description: 'WebAudio unavailable; guaranteed chest payout remains verified.' });
  await page.mouse.move(bounds.x + (rect.x + rect.width / 2) * bounds.scale,
    bounds.y + (rect.y + rect.height / 2) * bounds.scale);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await roomState(page)).opened_count).toBe(1);
  } finally {
    await page.mouse.up();
  }
  const expected = Math.max(1, opening.chests[0].tier) * 50;
  await expect.poll(async () => (await wallet(page)).arrived_balance).toBe(balance + expected);
  await expect.poll(async () => (await wallet(page)).active).toBe(false);
  if (audioAvailable) {
    const release = await expectRecording(page, from, COIN_CLIPS.release);
    const arrival = await expectRecording(page, from, COIN_CLIPS.arrival);
    expect(release.fingerprint, 'Chest coins retain separate appearance and deposit recordings').not.toBe(arrival.fingerprint);
    expect(arrival.at).toBeGreaterThan(release.at);
    expect(release.peak).toBeGreaterThan(0.01);
    expect(arrival.peak).toBeGreaterThan(0.01);
  }
  await page.mouse.click(bounds.x + (rect.x + rect.width / 2) * bounds.scale,
    bounds.y + (rect.y + rect.height / 2) * bounds.scale, { delay: 700 });
  await page.waitForTimeout(500);
  expect((await wallet(page)).balance, 'An opened chest cannot pay the guaranteed reward twice').toBe(balance + expected);
  await page.reload();
  await enterGame(page, { home: true });
  await expect.poll(async () => (await wallet(page)).arrived_balance).toBe(balance + expected);
  await info.attach('guaranteed-chest-coins', { body: JSON.stringify({ expected, balance: await wallet(page) }, null, 2), contentType: 'application/json' });
  expect(errors).toEqual([]);
});
