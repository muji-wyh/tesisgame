const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap } = require('./game-ui.cjs');
const { observeOutputAudio, expectRecording, recordingTiming, watchAudioRequests } = require('./bundled-audio.cjs');
const vocabulary = require('../../words.json');

const words = vocabulary;
const timings = new Map(words.map(word => [word.id, recordingTiming(word.audio)]));
const rewardTiming = recordingTiming('assets/imported-audio/chest-reference/reward.wav');
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const sounds = page => page.evaluate(() => window.audioObservation.playbacks);
const matches = (sound, timing) => Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate;
const pronunciations = (playbacks, from = 0) => playbacks.slice(from).filter(sound =>
  !sound.loop && !(sound.rewardEnvelopeSimilarity >= 0.99) && [...timings.values()].some(timing => matches(sound, timing)));

function rewardEnvelope() {
  const bytes = fs.readFileSync(path.resolve(__dirname, '../../assets/imported-audio/chest-reference/reward.wav'));
  let samples;
  for (let at = 12; at + 8 <= bytes.length;) {
    const length = bytes.readUInt32LE(at + 4), kind = bytes.toString('ascii', at, at + 4);
    if (kind === 'fmt ') {
      if (bytes.readUInt16LE(at + 8) !== 1 || bytes.readUInt16LE(at + 10) !== 1 || bytes.readUInt16LE(at + 22) !== 16)
        throw new Error('The reward classifier expects the production mono PCM16 recording.');
    }
    if (kind === 'data') samples = bytes.subarray(at + 8, at + 8 + length);
    at += 8 + length + (length % 2);
  }
  if (!samples) throw new Error('The production reward recording has no samples.');
  return Array.from({ length: 32 }, (_, bin) => {
    const first = Math.floor(bin * samples.length / 64), last = Math.floor((bin + 1) * samples.length / 64);
    let energy = 0;
    for (let frame = first; frame < last; frame++) energy += (samples.readInt16LE(frame * 2) / 32768) ** 2;
    return Math.sqrt(energy / (last - first));
  });
}

async function observeRewardIdentity(page) {
  // The reward cue and twelve words share a 1.2 s duration. Compare the
  // recording's envelope as well as the existing exact decoded-buffer fingerprint.
  // Envelope identity survives Godot's resampling; all colliding words score below 0.34.
  await page.addInitScript(({ reference, seconds }) => {
    const Context = window.AudioContext || window.webkitAudioContext;
    if (!Context) return;
    const identities = new Map(), referenceNorm = Math.sqrt(reference.reduce((sum, value) => sum + value * value, 0));
    const Wrapped = new Proxy(Context, {
      construct(Target, args) {
        const context = Reflect.construct(Target, args), createSource = context.createBufferSource.bind(context);
        context.createBufferSource = () => {
          const source = createSource(), start = source.start.bind(source);
          source.start = (...values) => {
            const index = window.audioObservation.playbacks.length;
            const result = start(...values), buffer = source.buffer;
            if (!buffer || Math.abs(buffer.duration - seconds) >= 0.001) return result;
            // Init-script wrappers can nest in either order. The outer observer
            // records this exact index before the microtask reads its fingerprint.
            queueMicrotask(() => {
              const sound = window.audioObservation.playbacks[index];
              if (!sound?.fingerprint) return;
              if (!identities.has(sound.fingerprint)) {
                const samples = buffer.getChannelData(0);
                let dot = 0, norm = 0;
                for (let bin = 0; bin < reference.length; bin++) {
                  const first = Math.floor(bin * samples.length / reference.length);
                  const last = Math.floor((bin + 1) * samples.length / reference.length);
                  let energy = 0;
                  for (let frame = first; frame < last; frame++) energy += samples[frame] * samples[frame];
                  const rms = Math.sqrt(energy / (last - first));
                  dot += rms * reference[bin];
                  norm += rms * rms;
                }
                identities.set(sound.fingerprint, norm ? dot / (Math.sqrt(norm) * referenceNorm) : 0);
              }
              sound.rewardEnvelopeSimilarity = identities.get(sound.fingerprint);
            });
            return result;
          };
          return source;
        };
        return context;
      }
    });
    if (window.AudioContext) window.AudioContext = Wrapped;
    else window.webkitAudioContext = Wrapped;
  }, { reference: rewardEnvelope(), seconds: rewardTiming.seconds });
}

test.use({ deviceScaleFactor: 1, trace: 'off',
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

async function start(page, browserName) {
  await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  await observeRewardIdentity(page);
  await page.addInitScript(() => {
    localStorage.setItem('growWithPip.growth.v1',
      '[growth]\nversion=3\nlevel=0\nage=0\nstreaks={}\nmastered_words=[]\nreceipts=[]\n');
    localStorage.setItem('growWithPip.coinWallet.v1',
      '[wallet]\nversion=2\nbalance=5000\nreceipts={"browser-opening-coins":5000}\n');
  });
  const errors = await openGame(page, { mode: 'word_jelly', reducedMotion: 'no-preference' });
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && state.phase === 'playing' && state.tiles.length >= 18 &&
      state.tiles.every(tile => tile.settled) && state.powerup_buttons.auto_merge.enabled;
  }, { timeout: 20000 }).toBe(true);
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  test.skip(!available, 'This browser runtime has no WebAudio.');
  return errors;
}

async function pressRect(page, rect, bounds) {
  await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2, bounds);
}

function wordPicturePair(state) {
  const reserved = new Set(state.fusions.flatMap(fusion => [fusion.a_id, fusion.b_id]));
  const ready = state.tiles.filter(tile => tile.visible && tile.settled && !reserved.has(tile.id))
    .sort((a, b) => a.row - b.row);
  const source = ready.find(tile => tile.jelly_kind === 'root' && tile.word_candidate?.id &&
    ready.some(picture => picture.jelly_kind === 'picture' && picture.image_word?.id === tile.word_candidate.id));
  expect(source, 'The board contains a complete spelling with its matching picture').toBeTruthy();
  return { source, target: ready.find(tile => tile.jelly_kind === 'picture' && tile.image_word?.id === source.word_candidate.id),
    word: source.word_candidate };
}

async function mergeNextPair(page) {
  const state = await jelly(page), bounds = await metrics(page);
  const { source, target } = wordPicturePair(state);
  const point = tile => ({ x: bounds.x + (tile.rect[0] + tile.rect[2] / 2) * bounds.scale,
    y: bounds.y + (tile.rect[1] + tile.rect[3] / 2) * bounds.scale });
  const from = point(source), to = point(target);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source, { intervals: [25, 50] }).toBe(source.id);
    await page.mouse.move(to.x, to.y, { steps: 5 });
    await expect.poll(async () => {
      const next = await jelly(page), live = next.tiles.find(tile => tile.id === target.id);
      if (!live?.settled) return false;
      if (next.drag.target === target.id) return true;
      const destination = point(live);
      await page.mouse.move(destination.x, destination.y, { steps: 4 });
      return false;
    }, { intervals: [25, 50] }).toBe(true);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => {
    const next = await jelly(page);
    return next.fusions.some(fusion => fusion.a_id === source.id && fusion.b_id === target.id) ||
      next.merged_count > state.merged_count;
  }, { intervals: [25, 50] }).toBe(true);
}

async function observeMerges(page) {
  await page.evaluate(() => {
    window.mergeSpeechObserver?.disconnect();
    if (window.mergeSpeechReleaseObserver) window.removeEventListener('pointerup', window.mergeSpeechReleaseObserver, true);
    const status = document.getElementById('game-status');
    const initial = JSON.parse(status.dataset.jelly || '{}');
    const seen = new Set(initial.tiles.map(tile => tile.id));
    const evidence = window.mergeSpeechEvidence = {
      from: window.audioObservation.playbacks.length, releases: [], completions: [], frames: [], collectionAt: null
    };
    window.mergeSpeechReleaseObserver = () => evidence.releases.push(performance.now());
    window.addEventListener('pointerup', window.mergeSpeechReleaseObserver, true);
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      if (state.mode !== 'word_jelly') return;
      const at = performance.now();
      evidence.frames.push({ at, merged: state.merged_count, fusions: state.fusions,
        powerup: state.powerup, batch: state.collection_batch });
      for (const tile of state.tiles) {
        if (!seen.has(tile.id) && tile.mass > 1 && tile.word?.id)
          evidence.completions.push({ at, id: tile.id, word: tile.word });
        seen.add(tile.id);
      }
      if (state.collection_batch.active && evidence.collectionAt === null) evidence.collectionAt = at;
    };
    window.mergeSpeechObserver = new MutationObserver(record);
    window.mergeSpeechObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  });
}

async function retain(page, info, label) {
  const evidence = await page.evaluate(() => ({ ...window.mergeSpeechEvidence,
    playbacks: window.audioObservation.playbacks.slice(window.mergeSpeechEvidence.from) }));
  const path = info.outputPath(`${label}.json`);
  fs.writeFileSync(path, JSON.stringify(evidence, null, 2));
  await info.attach(`${label}.json`, { path, contentType: 'application/json' });
  return evidence;
}

function expectNaturalEnd(sound) {
  expect(sound.peak, 'The bundled pronunciation contains audible PCM samples').toBeGreaterThan(0.01);
  expect(sound.contextState).toBe('running');
  expect(sound.endedAt, 'An uninterrupted recording reaches its end').toBeDefined();
  if (sound.stopScheduledAt !== undefined)
    expect(sound.stopScheduledAt - sound.scheduledAt, 'An isolated pronunciation retains its full duration')
      .toBeGreaterThanOrEqual(sound.duration - 0.04);
  expect(sound.endedAt - sound.at, 'An uninterrupted word plays completely')
    .toBeGreaterThanOrEqual(sound.duration * 1000 - 60);
}

test('picture and complete spelling taps pronounce their word without collecting', async ({ page, browserName }) => {
  test.setTimeout(120000);
  const requests = watchAudioRequests(page), errors = await start(page, browserName);
  const opening = await jelly(page), pair = wordPicturePair(opening);
  for (const id of [pair.target.id, pair.source.id]) {
    const live = (await jelly(page)).tiles.find(tile => tile.id === id);
    const from = (await sounds(page)).length;
    await pressRect(page, live.rect);
    await expectRecording(page, from, pair.word.audio);
    await expect.poll(async () => pronunciations(await sounds(page), from).every(sound => sound.endedAt !== undefined))
      .toBe(true);
    const spoken = pronunciations(await sounds(page), from);
    expect(spoken, 'Each picture or complete spelling tap pronounces exactly once').toHaveLength(1);
    expectNaturalEnd(spoken[0]);
    const current = await jelly(page);
    expect(current.tiles.some(tile => tile.id === id)).toBe(true);
    expect(current.merged_count).toBe(opening.merged_count);
    expect(current.cleared_pairs).toBe(opening.cleared_pairs);
  }
  expect(requests, 'Tap pronunciation uses bundled recordings').toEqual([]);
  expect(errors).toEqual([]);
});

test('a manual Jelly Words merge pronounces its word immediately on the accepted drop', async ({ page, browserName }, info) => {
  test.setTimeout(120000);
  const requests = watchAudioRequests(page), errors = await start(page, browserName);
  const opening = await jelly(page);
  const { source, target, word } = wordPicturePair(opening);
  await observeMerges(page);
  const fromIndex = await page.evaluate(() => window.mergeSpeechEvidence.from), bounds = await metrics(page);
  const point = tile => ({ x: bounds.x + (tile.rect[0] + tile.rect[2] / 2) * bounds.scale,
    y: bounds.y + (tile.rect[1] + tile.rect[3] / 2) * bounds.scale });
  const from = point(source), to = point(target);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(source.id);
    await page.mouse.move(to.x, to.y, { steps: 10 });
    await expect.poll(async () => {
      const next = await jelly(page), live = next.tiles.find(tile => tile.id === target.id);
      if (!live?.settled) return false;
      if (next.drag.target === target.id) return true;
      const destination = point(live);
      await page.mouse.move(destination.x, destination.y, { steps: 4 });
      return false;
    }).toBe(true);
    await page.waitForTimeout(150);
    expect(pronunciations(await sounds(page), fromIndex), 'Touching a compatible target does not pronounce an unfinished word').toEqual([]);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => (await jelly(page)).merged_count).toBe(opening.merged_count + 1);
  await expectRecording(page, fromIndex, word.audio);
  await expect.poll(async () => pronunciations(await sounds(page), fromIndex).every(sound => sound.endedAt !== undefined)).toBe(true);
  await page.waitForTimeout(150);
  const evidence = await retain(page, info, 'manual-merge-pronunciation');
  const spoken = pronunciations(evidence.playbacks);
  expect(spoken, 'One completed merge plays exactly one pronunciation').toHaveLength(1);
  expect(matches(spoken[0], timings.get(word.id))).toBe(true);
  expect(evidence.completions.map(item => item.word.id)).toEqual([word.id]);
  const pending = evidence.frames.filter(frame => frame.fusions.some(fusion => fusion.operation === 'merge'));
  expect(pending.length, 'The browser observes the actual merge animation before completion').toBeGreaterThan(0);
  expect(evidence.releases).toHaveLength(1);
  expect(spoken[0].at).toBeGreaterThanOrEqual(evidence.releases[0]);
  expect(spoken[0].at - evidence.releases[0], 'A valid drop starts playback without the previous 760 ms animation wait')
    .toBeLessThan(200);
  expect(Math.abs(spoken[0].at - pending[0].at), 'Pronunciation begins alongside the accepted fusion')
    .toBeLessThan(160);
  expect(spoken[0].at, 'The merge animation can continue while its word is spoken')
    .toBeLessThan(evidence.completions[0].at);
  expectNaturalEnd(spoken[0]);
  expect((await jelly(page)).cleared_pairs, 'Pronouncing a merge does not collect it').toBe(opening.cleared_pairs);
  expect(requests, 'Merge speech uses the existing bundled recording without a network request').toEqual([]);
  expect(errors).toEqual([]);
});

test('Auto Merge completes its paid animated fusions without pronouncing words', async ({ page, browserName }, info) => {
  test.setTimeout(120000);
  const requests = watchAudioRequests(page), errors = await start(page, browserName);
  const opening = await jelly(page), startingWallet = await wallet(page);
  await observeMerges(page);
  await pressRect(page, opening.powerup_buttons.auto_merge.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'auto_merge' && !state.powerup.active && state.powerup.stage === 'complete';
  }, { timeout: 20000 }).toBe(true);
  const after = await jelly(page);
  expect(after.powerup.completed).toBeGreaterThan(1);
  await expect.poll(async () => (await wallet(page)).balance)
    .toBe(startingWallet.balance - opening.powerup_buttons.auto_merge.price);
  // Wait beyond a complete vocabulary recording so delayed pronunciation is
  // checked as well as audio emitted during the automatic fusion timeline.
  await page.waitForTimeout(Math.max(...[...timings.values()].map(timing => timing.seconds)) * 1000 + 200);
  const evidence = await retain(page, info, 'auto-merge-without-pronunciation');
  const spoken = pronunciations(evidence.playbacks);
  expect(evidence.completions).toHaveLength(after.powerup.completed);
  expect(spoken, 'Automatic merges neither speak immediately nor leave queued words').toEqual([]);
  for (const completion of evidence.completions) {
    const pending = evidence.frames.filter(frame => frame.fusions.some(fusion =>
      fusion.operation === 'merge' && fusion.result.id === completion.id));
    expect(pending.length, 'Each automatic union appears in the published animation').toBeGreaterThan(0);
  }
  expect(after.merged_count).toBe(opening.merged_count + after.powerup.completed);
  expect(after.cleared_pairs, 'Auto Merge does not trigger Collect').toBe(opening.cleared_pairs);
  expect(after.collected_coins).toBe(opening.collected_coins);
  const mergeTiming = recordingTiming('assets/imported-audio/jelly-interaction/merge-together-v3.wav');
  expect(evidence.playbacks.some(sound => matches(sound, mergeTiming) && sound.peak > 0.01),
    'Automatic fusion keeps its existing merge sound effect').toBe(true);
  let tile;
  await expect.poll(async () => {
    tile = (await jelly(page)).tiles.find(item => item.mass > 1 && item.word?.id && item.settled);
    return Boolean(tile);
  }).toBe(true);
  const beforeTap = (await sounds(page)).length;
  await pressRect(page, tile.rect);
  await expectRecording(page, beforeTap, tile.word.audio);
  await expect.poll(async () => pronunciations(await sounds(page), beforeTap).every(sound => sound.endedAt !== undefined)).toBe(true);
  const tapped = pronunciations(await sounds(page), beforeTap);
  expect(tapped, 'A deliberate tap still pronounces an automatically merged word exactly once').toHaveLength(1);
  expectNaturalEnd(tapped[0]);
  expect(requests, 'Automatic and direct interactions use bundled audio').toEqual([]);
  expect(errors).toEqual([]);
});

test('Collect cancels manual merge pronunciation and keeps the whole batch silent', async ({ page, browserName }, info) => {
  test.setTimeout(120000);
  const errors = await start(page, browserName), opening = await jelly(page), bounds = await metrics(page);
  await observeMerges(page);
  const from = await page.evaluate(() => window.mergeSpeechEvidence.from);
  await mergeNextPair(page);
  await mergeNextPair(page);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.merged_count === opening.merged_count + 2 && state.collect_button.enabled && state.collect_button.count === 2;
  }, { intervals: [25, 50], timeout: 20000 }).toBe(true);
  await expect.poll(async () => {
    const earlier = pronunciations(await sounds(page), from);
    return earlier.length === 2 && earlier.every(sound => sound.endedAt !== undefined);
  }).toBe(true);
  // Keep two words ready, then start fresh merge speech. Waiting for this last
  // fusion to settle would consume most of the now-immediate pronunciation.
  await mergeNextPair(page);
  const snapshot = await page.evaluate(() => ({
    ready: JSON.parse(document.getElementById('game-status').dataset.jelly),
    playbacks: window.audioObservation.playbacks.slice(window.mergeSpeechEvidence.from),
    at: performance.now()
  }));
  const { ready, at: collectInputAt } = snapshot;
  const active = pronunciations(snapshot.playbacks)
    .findLast(sound => sound.stoppedAt === undefined && sound.endedAt === undefined);
  expect(ready.collect_button.enabled).toBe(true);
  expect(ready.collect_button.count).toBeGreaterThanOrEqual(2);
  expect(active, 'A manual merge pronunciation is still playing when Collect becomes available').toBeTruthy();
  await pressRect(page, ready.collect_button.rect, bounds);
  await expect.poll(async () => {
    const current = (await sounds(page)).find(sound => sound.at === active.at && sound.scheduledAt === active.scheduledAt);
    return current?.stoppedAt !== undefined;
  }, { message: 'Collect stops the pronunciation that was already playing' }).toBe(true);
  let batchTotal;
  await expect.poll(async () => {
    batchTotal = await page.evaluate(() => window.mergeSpeechEvidence.frames.find(frame => frame.batch.active)?.batch.total || 0);
    return batchTotal;
  }).toBeGreaterThanOrEqual(2);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(opening.cleared_pairs + batchTotal);
  await page.waitForTimeout(1800);
  const evidence = await retain(page, info, 'collect-cancels-merge-pronunciation');
  expect(evidence.collectionAt).not.toBeNull();
  const stopped = evidence.playbacks.find(sound => sound.at === active.at && sound.scheduledAt === active.scheduledAt);
  expect(stopped.stoppedAt, 'The active voice receives its stop after the Collect input').toBeGreaterThanOrEqual(collectInputAt);
  expect(stopped.stopScheduledAt - stopped.scheduledAt, 'Collect interrupts the word before its natural end')
    .toBeLessThan(stopped.duration - 0.04);
  expect(pronunciations(evidence.playbacks).filter(sound => sound.at >= collectInputAt),
    'Neither waiting merge words nor the final collected word speak after Collect starts').toEqual([]);
  expect(errors).toEqual([]);
});
