const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap } = require('./game-ui.cjs');
const { observeOutputAudio, expectRecording, recordingTiming, watchAudioRequests } = require('./bundled-audio.cjs');
const vocabulary = require('../../words.json');

const words = vocabulary.filter(word => word.min_age === 3);
const dictionary = new Map(words.map(word => [word.text.toLowerCase(), word]));
const timings = new Map(words.map(word => [word.id, recordingTiming(word.audio)]));
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const sounds = page => page.evaluate(() => window.audioObservation.playbacks);
const matches = (sound, timing) => Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate;
const pronunciations = (playbacks, from = 0) => playbacks.slice(from).filter(sound =>
  !sound.loop && [...timings.values()].some(timing => matches(sound, timing)));

test.use({ deviceScaleFactor: 1, trace: 'off',
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

async function start(page, browserName) {
  await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
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

async function pressRect(page, rect) {
  await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);
}

async function observeMerges(page) {
  await page.evaluate(() => {
    window.mergeSpeechObserver?.disconnect();
    const status = document.getElementById('game-status');
    const initial = JSON.parse(status.dataset.jelly || '{}');
    const seen = new Set(initial.tiles.map(tile => tile.id));
    const evidence = window.mergeSpeechEvidence = {
      from: window.audioObservation.playbacks.length, completions: [], frames: [], collectionAt: null
    };
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
  expect(sound.endedAt, 'Each queued recording reaches its end').toBeDefined();
  if (sound.stopScheduledAt !== undefined)
    expect(sound.stopScheduledAt - sound.scheduledAt, 'Another merge never cuts off the pronunciation')
      .toBeGreaterThanOrEqual(sound.duration - 0.04);
  expect(sound.endedAt - sound.at, 'The complete word plays before the next queued word')
    .toBeGreaterThanOrEqual(sound.duration * 1000 - 60);
}

test('a manual Jelly Words merge pronounces the completed word once after the fusion', async ({ page, browserName }, info) => {
  test.setTimeout(120000);
  const requests = watchAudioRequests(page), errors = await start(page, browserName);
  const opening = await jelly(page);
  const roots = opening.tiles.filter(tile => tile.visible && tile.settled && tile.mass === 1);
  const source = roots.find(first => roots.some(second => first.id !== second.id && dictionary.has((first.text + second.text).toLowerCase())));
  expect(source, 'The opening three rows contain a valid forward word pair').toBeTruthy();
  const target = roots.find(second => source.id !== second.id && dictionary.has((source.text + second.text).toLowerCase()));
  const word = dictionary.get((source.text + target.text).toLowerCase());
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
    await expect.poll(async () => (await jelly(page)).drag.target).toBe(target.id);
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
  expect(spoken[0].at, 'Pronunciation follows the final animation frame, allowing one publication frame')
    .toBeGreaterThanOrEqual(pending.at(-1).at - 45);
  expect(Math.abs(spoken[0].at - evidence.completions[0].at), 'The completed-word appearance and voice begin together')
    .toBeLessThan(160);
  expectNaturalEnd(spoken[0]);
  expect((await jelly(page)).cleared_pairs, 'Pronouncing a merge does not collect it').toBe(opening.cleared_pairs);
  expect(requests, 'Merge speech uses the existing bundled recording without a network request').toEqual([]);
  expect(errors).toEqual([]);
});

test('Auto Merge speaks every completed word once in order without cutting off earlier words', async ({ page, browserName }, info) => {
  test.setTimeout(120000);
  const errors = await start(page, browserName), opening = await jelly(page);
  await observeMerges(page);
  await pressRect(page, opening.powerup_buttons.auto_merge.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'auto_merge' && !state.powerup.active && state.powerup.stage === 'complete';
  }, { timeout: 20000 }).toBe(true);
  const after = await jelly(page), from = await page.evaluate(() => window.mergeSpeechEvidence.from);
  expect(after.powerup.completed).toBeGreaterThan(1);
  await expect.poll(async () => {
    const spoken = pronunciations(await sounds(page), from);
    return spoken.length === after.powerup.completed && spoken.every(sound => sound.endedAt !== undefined);
  }, { timeout: 30000, message: 'Every automatically merged word finishes its queued recording' }).toBe(true);
  await page.waitForTimeout(150);
  const evidence = await retain(page, info, 'auto-merge-pronunciation-queue');
  const spoken = pronunciations(evidence.playbacks);
  expect(evidence.completions).toHaveLength(after.powerup.completed);
  expect(spoken, 'There is exactly one pronunciation per completed merge').toHaveLength(after.powerup.completed);
  for (const [index, sound] of spoken.entries()) {
    const completion = evidence.completions[index];
    expect(matches(sound, timings.get(completion.word.id)), `Queued position ${index + 1} speaks ${completion.word.text}`).toBe(true);
    // The bridge throttles snapshots independently of the audio callback. Use
    // the actual last pending fusion frame, rather than the later publication
    // timestamp, to bound the completion event from below.
    const pending = evidence.frames.filter(frame => frame.fusions.some(fusion =>
      fusion.operation === 'merge' && fusion.result.id === completion.id));
    expect(pending.length, 'Each automatic union appears in the published animation').toBeGreaterThan(0);
    expect(sound.at, 'Queued speech follows the last observed pending fusion frame')
      .toBeGreaterThanOrEqual(pending.at(-1).at - 10);
    expectNaturalEnd(sound);
    if (index) expect(sound.scheduledAt - spoken[index - 1].scheduledAt,
      'The next word waits for the previous complete recording').toBeGreaterThanOrEqual(spoken[index - 1].duration - 0.04);
  }
  expect(after.cleared_pairs, 'Auto Merge narration does not trigger Collect').toBe(opening.cleared_pairs);
  expect(after.collected_coins).toBe(opening.collected_coins);
  // Most existing word recordings share a padded duration. Compare their PCM
  // identity with the same visible word deliberately tapped through the normal
  // collection path, so equal lengths cannot hide repeated or reordered words.
  const references = [];
  for (const [index, completion] of evidence.completions.entries()) {
    let tile = (await jelly(page)).tiles.find(item => item.id === completion.id);
    if (!tile) continue; // A later valid merge may consume an intermediate word.
    await expect.poll(async () => {
      tile = (await jelly(page)).tiles.find(item => item.id === completion.id);
      return Boolean(tile?.settled);
    }).toBe(true);
    const beforeTap = (await sounds(page)).length;
    await pressRect(page, tile.rect);
    const direct = await expectRecording(page, beforeTap, completion.word.audio);
    expect(direct.fingerprint, `The queued ${completion.word.text} uses the same PCM as tapping that word`)
      .toBe(spoken[index].fingerprint);
    references.push({ word: completion.word.id, queueIndex: index, direct });
  }
  expect(references.length, 'Distinct real words verify the queue content as well as its timing').toBeGreaterThan(1);
  const referencePath = info.outputPath('auto-merge-pronunciation-identities.json');
  fs.writeFileSync(referencePath, JSON.stringify(references, null, 2));
  await info.attach('auto-merge-pronunciation-identities.json', { path: referencePath, contentType: 'application/json' });
  expect(errors).toEqual([]);
});

test('Collect cancels pending merge pronunciation and keeps the whole batch silent', async ({ page, browserName }, info) => {
  test.setTimeout(120000);
  const errors = await start(page, browserName), opening = await jelly(page);
  await observeMerges(page);
  await pressRect(page, opening.powerup_buttons.auto_merge.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.powerup.kind === 'auto_merge' && !state.powerup.active && state.powerup.stage === 'complete' &&
      state.collect_button.enabled;
  }, { timeout: 20000 }).toBe(true);
  const ready = await jelly(page), from = await page.evaluate(() => window.mergeSpeechEvidence.from);
  const queued = pronunciations(await sounds(page), from);
  expect(queued.length, 'Rapid Auto Merge leaves pronunciation waiting when Collect becomes available')
    .toBeLessThan(ready.powerup.completed);
  await pressRect(page, ready.collect_button.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(opening.cleared_pairs + ready.collect_button.count);
  await page.waitForTimeout(1800);
  const evidence = await retain(page, info, 'collect-cancels-merge-pronunciation');
  expect(evidence.collectionAt).not.toBeNull();
  expect(pronunciations(evidence.playbacks).filter(sound => sound.at >= evidence.collectionAt),
    'Neither waiting merge words nor the final collected word speak after Collect starts').toEqual([]);
  expect(errors).toEqual([]);
});
