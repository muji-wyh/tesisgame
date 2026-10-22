const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, chooseMode, activateLibraryControl, metrics, tap, rendered } = require('./game-ui.cjs');
const { watchAudioRequests, observeOutputAudio, expectOutputEnergy, expectRecording, recordingTiming } = require('./bundled-audio.cjs');

const CLIPS = {
  pick: 'assets/imported-audio/ui-click/select.wav',
  release: 'assets/imported-audio/chest-reference/step.wav',
  land: 'assets/audio/jelly-match/land.wav',
  contact: 'assets/imported-audio/jelly-interaction/contact.wav',
  merge: 'assets/imported-audio/jelly-interaction/merge-together-v3.wav'
};
const COLLECTION_CLIP = 'assets/audio/jelly-match/collect-pop.wav';
const LEARNER_AGE = 8;
const vocabulary = new Map(require('../../words.json').map(word => [word.id, word]));
const compositionAnalyses = new Map(Array.from({ length: 10 }, (_, index) =>
  require(`../../data/vocabulary/morphology/age-${String(index + 3).padStart(2, '0')}.json`).entries)
  .flat().map(entry => [entry.id, entry.analysis]));
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const playbackIndex = page => page.evaluate(() => window.audioObservation.playbacks.length);
const playbacksSince = (page, from) => page.evaluate(index => window.audioObservation.playbacks.slice(index), from);

test.use({ deviceScaleFactor: 1,
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

async function libraryControl(page, name) {
  await activateLibraryControl(page, name);
}

async function settledBoard(page) {
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && !state.paused && state.phase === 'playing' &&
      state.tiles.length >= 2 && state.tiles.every(tile => tile.settled) && !Object.keys(state.fusion).length;
  }, { timeout: 20000, message: 'The real Jelly board is ready for another gesture' }).toBe(true);
  return jelly(page);
}

async function availablePair(page) {
  let found;
  await expect.poll(async () => {
    const state = await jelly(page);
    found = undefined;
    if (!state.visible || state.paused || state.phase !== 'playing' || Object.keys(state.fusion || {}).length) return false;
    for (const first of state.tiles || []) {
      if (!first.visible || !first.settled || first.chest) continue;
      const second = state.tiles.find(tile => tile.visible && tile.settled && !tile.chest &&
        tile.id !== first.id && tile.word.id === first.word.id && tile.kind !== first.kind);
      if (second) { found = [first, second]; break; }
    }
    return Boolean(found);
  }, { timeout: 30000, message: 'Batched supply provides a real, unmarked word and picture pair' }).toBe(true);
  return found;
}

async function freshRound(page) {
  // Each audio/lifecycle case uses a new round through the real library. Batch
  // arrivals keep their production pacing instead of expiring one shared board.
  await openModeMenu(page);
  await libraryControl(page, 'Mode_match');
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await openModeMenu(page);
  await libraryControl(page, 'Mode_jelly');
  const state = await settledBoard(page);
  expect(state.cleared_pairs, 'A fresh real round starts without credit from earlier audio checks').toBe(0);
  return { generated_tiles: state.generated_tiles, cleared_pairs: state.cleared_pairs };
}

function center(rect, bounds) {
  return { x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale };
}

async function beginDrag(page, tile) {
  const state = await jelly(page);
  expect(state.phase, 'The gesture starts in an active real round').toBe('playing');
  expect(state.paused).toBe(false);
  const current = state.tiles.find(item => item.id === tile.id);
  expect(current?.visible && current.settled, 'The gesture targets a visible settled tile').toBe(true);
  const point = center(current.rect, await metrics(page));
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  await expect.poll(async () => (await jelly(page)).drag.source).toBe(tile.id);
}

async function hoverTile(page, tile) {
  const current = (await jelly(page)).tiles.find(item => item.id === tile.id);
  const point = center(current.rect, await metrics(page));
  await page.mouse.move(point.x, point.y, { steps: 8 });
  await expect.poll(async () => {
    const state = await jelly(page);
    return { active: state.drag.active, target: state.drag.target };
  }).toEqual({ active: true, target: tile.id });
}

async function hoverEmptySpace(page) {
  const state = await jelly(page), bounds = await metrics(page);
  const [x, y, width, height] = state.board_rect;
  let empty;
  for (const row of [0.12, 0.25, 0.38, 0.5]) {
    for (const column of [0.5, 0.2, 0.8]) {
      const candidate = { x: x + width * column, y: y + height * row };
      if (state.tiles.every(tile => {
        const [left, top, w, h] = tile.rect;
        return candidate.x < left - 8 || candidate.x > left + w + 8 ||
          candidate.y < top - 8 || candidate.y > top + h + 8;
      })) { empty = candidate; break; }
    }
    if (empty) break;
  }
  expect(empty, 'The test uses a visibly empty part of the real board').toBeTruthy();
  await page.mouse.move(bounds.x + empty.x * bounds.scale, bounds.y + empty.y * bounds.scale, { steps: 8 });
  await expect.poll(async () => {
    const state = await jelly(page);
    return { active: state.drag.active, target: state.drag.target };
  }).toEqual({ active: true, target: -1 });
}

async function audibleRecording(page, from, path, excludedFingerprint = '') {
  let playback;
  if (!excludedFingerprint) playback = await expectRecording(page, from, path);
  else {
    const timing = recordingTiming(path);
    await expect.poll(async () => {
      playback = await page.evaluate(({ from, timing, excludedFingerprint }) =>
        window.audioObservation.playbacks.slice(from).findLast(sound =>
          Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate &&
          sound.contextState === 'running' && sound.fingerprint && sound.fingerprint !== excludedFingerprint),
      { from, timing, excludedFingerprint });
      return Boolean(playback);
    }, { message: `${path} plays its own samples, distinct from the landing clip` }).toBe(true);
  }
  expect(playback.fingerprint, `${path} was decoded into observed PCM`).toBeTruthy();
  expect(playback.peak, `${path} contains nonzero samples`).toBeGreaterThan(0.01);
  return playback;
}

function matching(playbacks, recording) {
  return playbacks.filter(playback => playback.fingerprint === recording.fingerprint);
}

function collectionSounds(playbacks, reference) {
  const timing = recordingTiming(COLLECTION_CLIP);
  // Identify the first isolated pop by its source duration. Later collections
  // must also contain exactly the same decoded samples as that first playback.
  return playbacks.filter(sound => sound.contextState === 'running' &&
    Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate &&
    (!reference || sound.fingerprint === reference.fingerprint));
}

async function audibleCollection(page, from) {
  const sound = await audibleRecording(page, from, COLLECTION_CLIP);
  expect(sound.playbackRate, 'Collection preserves the bubble-pop recording at its original pitch').toBe(1);
  return { ...sound, source: COLLECTION_CLIP };
}

async function muteInMenu(page, muted, mode = 'jelly') {
  await openModeMenu(page);
  const isMuted = () => page.evaluate(() => Boolean(JSON.parse(localStorage.getItem('pipAndWords.presentation.v1') || '{}').muted));
  if (await isMuted() !== muted) {
    const bounds = await metrics(page);
    if (!bounds.library.controls.find(control => control.name === 'LibrarySound').fully_visible) {
      const [x, y, width, height] = bounds.library.viewport_rect;
      await page.mouse.move(bounds.x + (x + width / 2) * bounds.scale,
        bounds.y + (y + height / 2) * bounds.scale);
      await page.mouse.wheel(0, 3000);
      await expect.poll(async () => (await metrics(page)).library.controls
        .find(control => control.name === 'LibrarySound').fully_visible).toBe(true);
    }
    await libraryControl(page, 'LibrarySound');
  }
  await expect.poll(isMuted).toBe(muted);
  await chooseMode(page, mode);
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
}

async function interruptFusion(page, tiles) {
  await beginDrag(page, tiles[0]);
  await hoverTile(page, tiles[1]);
  await page.mouse.up();
  // Escape reaches the ordinary menu action after the committed drop. Avoid
  // waiting for a snapshot before interrupting the 700 ms pre-clear phase.
  await page.keyboard.press('Escape');
  await expect.poll(async () => (await metrics(page)).library.visible).toBe(true);
  const state = await jelly(page);
  expect(state.paused).toBe(true);
  expect(state.fusion.popped, 'The real menu interrupts before the scheduled clear').toBe(false);
  return state;
}

test('Jelly gestures render distinct bundled sounds, preserve pronunciation, and respect mute and lifecycle', async ({ page, context, browserName }, info) => {
  test.setTimeout(240000);
  const requests = watchAudioRequests(page), evidence = { rounds: {} };
  await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  test.skip(!available, 'This browser runtime has no WebAudio.');
  await openModeMenu(page);
  const startup = await playbackIndex(page);
  await libraryControl(page, 'Mode_jelly');
  const opening = await settledBoard(page);
  const [x, y, width, height] = opening.preview.rect;
  await tap(page, x + width / 2, y + height / 2);
  await expect.poll(async () => (await jelly(page)).generated_tiles).toBe(opening.generated_tiles + 4);
  await settledBoard(page);
  evidence.land = await audibleRecording(page, startup, CLIPS.land);

  await context.setOffline(true);
  try {
    const first = (await availablePair(page))[0];
    const beforePick = await playbackIndex(page), clearedBeforeDrop = (await jelly(page)).cleared_pairs;
    await beginDrag(page, first);
    evidence.pick = await audibleRecording(page, beforePick, CLIPS.pick);
    evidence.pronunciation = await audibleRecording(page, beforePick, first.word.audio);
    evidence.output = await expectOutputEnergy(page);
    expect(evidence.pick.fingerprint).not.toBe(evidence.pronunciation.fingerprint);
    const beforeHover = await playbackIndex(page);
    await hoverEmptySpace(page);
    expect(matching(await playbacksSince(page, beforeHover), evidence.pick),
      'Dragging across the board does not repeatedly play the pick cue').toEqual([]);
    const dropState = await jelly(page), beforeDrop = await playbackIndex(page);
    const fallingBeforeDrop = dropState.tiles.filter(tile => !tile.settled).length;
    await page.mouse.up();
    evidence.release = await audibleRecording(page, beforeDrop, CLIPS.release, evidence.land.fingerprint);
    // Compare decoded sample identity so a nearby natural landing cannot
    // accidentally satisfy the empty-drop assertion.
    expect(evidence.release.fingerprint).not.toBe(evidence.land.fingerprint);
    await expect.poll(async () => {
      const returned = (await jelly(page)).tiles.find(tile => tile.id === first.id);
      return returned ? Math.max(...returned.rect.map((value, index) => Math.abs(value - first.rect[index]))) : Infinity;
    }, { message: 'The dragged tile visibly returns before another gesture targets it' }).toBeLessThan(0.5);
    const afterDrop = await settledBoard(page);
    expect(afterDrop.cleared_pairs).toBe(clearedBeforeDrop);
    const dropSounds = await playbacksSince(page, beforeDrop);
    expect(matching(dropSounds, evidence.release)).toHaveLength(1);
    const newArrivals = afterDrop.generated_tiles - dropState.generated_tiles;
    const landings = matching(dropSounds, evidence.land);
    evidence.emptyDrop = { fallingBeforeDrop, newArrivals, landings };
    expect(landings.length, 'Only naturally falling tiles can account for landing sounds during snapback')
      .toBeLessThanOrEqual(fallingBeforeDrop + newArrivals);
    if (fallingBeforeDrop === 0 && newArrivals === 0) {
      expect(matching(dropSounds, evidence.land), 'Snapback is not a new falling-tile landing').toEqual([]);
    }

    evidence.rounds.merge = await freshRound(page);
    const tiles = await availablePair(page), beforeMerge = await playbackIndex(page);
    const clearedBeforeMerge = (await jelly(page)).cleared_pairs;
    await beginDrag(page, tiles[0]);
    await hoverTile(page, tiles[1]);
    evidence.contact = await audibleRecording(page, beforeMerge, CLIPS.contact);
    // The drag can cross other jelly bodies before reaching this partner.
    // Only measure repeats after the pointer has stopped on the held contact.
    const heldContacts = matching(await playbacksSince(page, beforeMerge), evidence.contact).length;
    await page.waitForTimeout(250);
    expect(matching(await playbacksSince(page, beforeMerge), evidence.contact),
      'Continuing to hold the same contact does not replay its sound').toHaveLength(heldContacts);
    await page.mouse.up();
    evidence.merge = await audibleRecording(page, beforeMerge, CLIPS.merge);
    evidence.clear = await audibleCollection(page, beforeMerge);
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(clearedBeforeMerge + 1);
    expect(evidence.clear.at).toBeGreaterThan(evidence.merge.at);
    expect(evidence.merge.at).toBeGreaterThan(evidence.contact.at);
    expect(new Set(['pick', 'release', 'land', 'contact', 'merge', 'clear'].map(cue => evidence[cue].fingerprint)).size).toBe(6);
    const mergeSounds = await playbacksSince(page, beforeMerge);
    expect(matching(mergeSounds, evidence.merge)).toHaveLength(1);
    expect(matching(mergeSounds, evidence.clear)).toHaveLength(1);
    expect(matching(mergeSounds, evidence.release), 'A successful drop does not also play empty-drop audio').toEqual([]);

    evidence.rounds.tap = await freshRound(page);
    const tapTiles = await availablePair(page), beforeTaps = await playbackIndex(page);
    const savedGrowth = await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1'));
    evidence.tapPronunciations = [];
    for (const tile of tapTiles) {
      const beforeTap = await playbackIndex(page);
      const current = (await jelly(page)).tiles.find(item => item.id === tile.id);
      const [x, y, width, height] = current.rect;
      await tap(page, x + width / 2, y + height / 2);
      evidence.tapPronunciations.push(await audibleRecording(page, beforeTap, tile.word.audio));
    }
    await page.waitForTimeout(1200);
    const afterTaps = await jelly(page), tapSounds = await playbacksSince(page, beforeTaps);
    expect(afterTaps.drag).toMatchObject({ active: false, source: -1, target: -1, selected: -1 });
    expect(afterTaps.fusion).toEqual({});
    expect(afterTaps.cleared_pairs).toBe(0);
    for (const cue of ['contact', 'merge', 'clear', 'release']) {
      expect(matching(tapSounds, evidence[cue]), `Consecutive taps pronounce words without the ${cue} cue`).toEqual([]);
    }
    expect(await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1')),
      'Pronouncing both halves of a pair does not record a learning attempt').toBe(savedGrowth);

    evidence.rounds.cancel = await freshRound(page);
    const cancelTile = (await availablePair(page))[0];
    await beginDrag(page, cancelTile);
    await hoverEmptySpace(page);
    const beforeCancel = await playbackIndex(page);
    await page.keyboard.press('Escape');
    await page.mouse.up();
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(-1);
    await page.waitForTimeout(300);
    expect(matching(await playbacksSince(page, beforeCancel), evidence.release),
      'Canceling a drag does not play an intentional empty-drop cue').toEqual([]);

    evidence.rounds.muted = await freshRound(page);
    await muteInMenu(page, true);
    const mutedFrom = await playbackIndex(page), mutedPair = await availablePair(page);
    const mutedScore = (await jelly(page)).cleared_pairs;
    await beginDrag(page, mutedPair[0]);
    await hoverTile(page, mutedPair[1]);
    await page.mouse.up();
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(mutedScore + 1);
    expect(await playbacksSince(page, mutedFrom), 'Mute silences pick, speech, contact, merge, clear, and landing').toEqual([]);

    await muteInMenu(page, false);
    evidence.rounds.pauseResume = await freshRound(page);
    const interruptedFrom = await playbackIndex(page), interruptedTiles = await availablePair(page);
    const paused = await interruptFusion(page, interruptedTiles);
    evidence.interruptedMerge = await audibleRecording(page, interruptedFrom, CLIPS.merge);
    const menuFrom = await playbackIndex(page);
    await page.waitForTimeout(1200);
    const stillPaused = await jelly(page);
    expect(stillPaused.cleared_pairs).toBe(paused.cleared_pairs);
    expect(stillPaused.fusion.elapsed).toBe(paused.fusion.elapsed);
    expect(await playbacksSince(page, menuFrom), 'A paused menu never emits delayed gameplay audio').toEqual([]);
    evidence.pausedSounds = await playbacksSince(page, interruptedFrom);
    expect(matching(evidence.pausedSounds, evidence.clear)).toEqual([]);
    expect(evidence.pausedSounds.filter(sound => !sound.loop && sound.stoppedAt === undefined && sound.endedAt === undefined),
      'No pronunciation or gameplay source keeps playing beneath the menu').toEqual([]);

    const resumeFrom = await playbackIndex(page);
    await chooseMode(page, 'jelly');
    evidence.resumedClear = await audibleCollection(page, resumeFrom);
    expect(evidence.resumedClear.fingerprint, 'Resuming collection uses the same bubble-pop recording').toBe(evidence.clear.fingerprint);
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(paused.cleared_pairs + 1);
    const resumed = await playbacksSince(page, resumeFrom);
    expect(matching(resumed, evidence.clear)).toHaveLength(1);
    expect(matching(resumed, evidence.merge), 'Resuming a committed fusion does not restart its merge sound').toEqual([]);

    evidence.rounds.leave = await freshRound(page);
    const leaveFrom = await playbackIndex(page), lastTiles = await availablePair(page);
    await interruptFusion(page, lastTiles);
    await audibleRecording(page, leaveFrom, CLIPS.merge);
    await libraryControl(page, 'Mode_match');
    await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
    const afterLeave = await playbackIndex(page);
    await page.waitForTimeout(1200);
    evidence.afterLeave = await playbacksSince(page, afterLeave);
    for (const cue of ['release', 'land', 'contact', 'merge', 'clear']) {
      expect(matching(evidence.afterLeave, evidence[cue]), `${cue} does not leak into the next game`).toEqual([]);
    }
  } finally {
    await page.mouse.up();
    await context.setOffline(false);
    await info.attach('jelly-browser-audio.json', { body: Buffer.from(JSON.stringify(evidence, null, 2)), contentType: 'application/json' });
  }
  expect(requests, 'Jelly feedback and pronunciation use the already bundled recordings').toEqual([]);
  expect(errors).toEqual([]);
});

async function pressJellyRect(page, rect) {
  const [x, y, width, height] = rect;
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function settledWordSupply(page) {
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.visible && !state.paused && state.phase === 'playing' &&
      state.tiles.every(tile => tile.settled) && !Object.keys(state.fusion).length &&
      !state.reward_presentation.active;
  }, { timeout: 20000, message: 'The authored supply settles before another ordinary gesture' }).toBe(true);
  return jelly(page);
}

async function mergeAuthoredParts(page, left, right, surface) {
  const before = await settledWordSupply(page), bounds = await metrics(page);
  const from = await playbackIndex(page);
  const source = before.tiles.find(tile => tile.id === left.id);
  expect(source?.visible && source.settled, 'The real drag starts from a visible, settled authored tile').toBe(true);
  const start = center(source.rect, bounds);
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  try {
    // Cross the drag threshold before a clipped label can open its Read panel.
    await page.mouse.move(start.x, start.y - 16);
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(left.id);
    await expect.poll(async () => {
      const state = await jelly(page), target = state.tiles.find(tile => tile.id === right.id);
      if (!target?.settled) return false;
      if (state.drag.active && state.drag.target === right.id) return true;
      const point = center(target.rect, bounds);
      await page.mouse.move(point.x, point.y, { steps: 8 });
      return false;
    }, { message: 'The held source follows its authored partner after support-removal gravity' }).toBe(true);
  } finally {
    await page.mouse.up();
  }
  let completed;
  await expect.poll(async () => {
    const state = await jelly(page);
    completed = state.tiles.find(tile => !before.tiles.some(old => old.id === tile.id) &&
      tile.text === surface && tile.mass === left.mass + right.mass);
    return state.merged_count === before.merged_count + 1 && Boolean(completed?.settled) &&
      state.tiles.every(tile => tile.settled);
  }, { message: 'The real drag produces the expected settled authored result' }).toBe(true);
  expect((await jelly(page)).cleared_pairs, 'A word merge waits for deliberate collection').toBe(before.cleared_pairs);
  expect(collectionSounds(await playbacksSince(page, from)), 'Building a word does not play the collection pop').toEqual([]);
  return completed;
}

async function completeAuthoredWord(page, candidate) {
  const { roots, picture, analysis, word } = candidate;
  const ready = new Map(analysis.parts.map((part, index) => [part.id, roots[index]]));
  const visit = async id => {
    if (ready.has(id)) return ready.get(id);
    const node = analysis.nodes.find(item => item.id === id);
    expect(node, 'The supply follows an explicit reviewed composition node').toBeTruthy();
    const left = await visit(node.left), right = await visit(node.right);
    const result = await mergeAuthoredParts(page, left, right, node.surface.replace(/^-+|-+$/g, ''));
    ready.set(id, result);
    return result;
  };
  let completed = await visit(analysis.roots[0]);
  if (picture && completed.jelly_kind !== 'merged')
    completed = await mergeAuthoredParts(page, picture, completed, word.text);
  expect(completed.word.id).toBe(word.id);
  expect(completed.jelly_kind, 'The spelling and required picture have both been completed').toBe('merged');
  expect(completed.merge_level, 'The fixed bubble pop case collects a Lv1 word').toBe(1);
  return completed;
}

async function collectSupplyWord(page, tile, before) {
  await pressJellyRect(page, tile.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  await settledWordSupply(page);
}

async function prepareWordCollection(page, { manual = false } = {}) {
  // Read the live stage's authored packets. A whole-word root still needs its
  // picture, and a saved learner age does not select the current stage's words.
  for (let attempt = 0; attempt < 24; attempt++) {
    const state = await settledWordSupply(page), groups = new Map();
    if (!manual && state.collect_button.count >= 2) return state;
    for (const tile of state.tiles.filter(tile => tile.visible && tile.mass === 1 && tile.supply_group)) {
      if (!groups.has(tile.supply_group)) groups.set(tile.supply_group, []);
      groups.get(tile.supply_group).push(tile);
    }
    const words = [...groups.values()].map(bodies => {
      const roots = bodies.filter(tile => tile.jelly_kind === 'root').sort((a, b) => a.supply_part - b.supply_part);
      const picture = bodies.find(tile => tile.jelly_kind === 'picture');
      const word = vocabulary.get(bodies[0].source_word_id);
      return { roots, picture, word, analysis: compositionAnalyses.get(word?.id) };
    }).filter(candidate => candidate.analysis && candidate.roots.length === candidate.analysis.parts.length &&
      candidate.roots.every((root, index) => root.text === candidate.analysis.parts[index].surface.replace(/^-+|-+$/g, '')) &&
      (!candidate.word.image || candidate.picture?.image_word.id === candidate.word.id))
      .sort((left, right) => left.roots.length - right.roots.length ||
        [...left.roots, left.picture].reduce((sum, tile) => sum + (tile?.fragments || 0), 0) -
        [...right.roots, right.picture].reduce((sum, tile) => sum + (tile?.fragments || 0), 0));
    if (words.length) {
      const completed = await completeAuthoredWord(page, words[0]);
      if (manual) return completed;
      continue;
    }
    if (state.preview.enabled) {
      await pressJellyRect(page, state.preview.rect);
      await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
      continue;
    }
    const blockingWord = state.tiles.find(tile => tile.word?.id);
    expect(blockingWord, 'A full supply board has a real collectable word to make room').toBeTruthy();
    await collectSupplyWord(page, blockingWord, state);
  }
  throw new Error('The ordinary supply did not prepare the collection case within twenty-four gestures.');
}

test('Jelly Words reuses one fixed bubble pop per manual or batch collection and respects mute', async ({ page, context, browserName }, info) => {
  test.setTimeout(180000);
  const requests = watchAudioRequests(page), evidence = { source: COLLECTION_CLIP };
  await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  // Keep the saved learner used by the authored suite while following live stage supply.
  await page.addInitScript(age => {
    const key = 'growWithPip.growth.v1';
    if (!localStorage.getItem(key)) localStorage.setItem(key,
      `[growth]\nversion=3\nlevel=0\nage=${age - 1}\nstreaks={}\nmastered_words=[]\nreceipts=[]\n`);
  }, LEARNER_AGE);
  const errors = await openGame(page, { mode: 'word_jelly', reducedMotion: 'no-preference' });
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  test.skip(!available, 'This browser runtime has no WebAudio.');
  const opening = await settledBoard(page);
  expect(opening.mode).toBe('word_jelly');
  expect(opening.authored_morphology).toBe(true);
  expect(opening.tiles.reduce((area, tile) => area + tile.width * tile.height, 0),
    'The authored opening respects its fifteen-cell occupied-area budget').toBeLessThanOrEqual(15);
  await context.setOffline(true);
  try {
    const manual = await prepareWordCollection(page, { manual: true }), beforeManual = await jelly(page);
    expect(manual.mass, 'The manual case collects a word built by real drags').toBeGreaterThan(1);
    const manualFrom = await playbackIndex(page);
    await pressJellyRect(page, manual.rect);
    evidence.manual = await audibleCollection(page, manualFrom);
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(beforeManual.cleared_pairs + 1);
    expect(collectionSounds(await playbacksSince(page, manualFrom), evidence.manual), 'A manual collection plays exactly one bubble pop').toHaveLength(1);
    await audibleRecording(page, manualFrom, manual.word.audio);

    const beforeBatch = await prepareWordCollection(page), batchFrom = await playbackIndex(page);
    const batchCount = beforeBatch.collect_button.count;
    expect(batchCount).toBeGreaterThanOrEqual(2);
    expect(beforeBatch.collect_button.enabled).toBe(true);
    await pressJellyRect(page, beforeBatch.collect_button.rect);
    await expect.poll(async () => (await jelly(page)).collection_batch.completed).toBe(batchCount);
    await expect.poll(async () => (await jelly(page)).collection_batch.active).toBe(false);
    await expect.poll(async () => collectionSounds(await playbacksSince(page, batchFrom), evidence.manual).length).toBe(batchCount);
    evidence.batch = collectionSounds(await playbacksSince(page, batchFrom), evidence.manual);
    evidence.batchCount = batchCount;
    const afterBatch = await jelly(page);
    expect(afterBatch.cleared_pairs).toBe(beforeBatch.cleared_pairs + batchCount);
    expect(afterBatch.collection_batch.elapsed, 'Each collection uses the 200 ms game cadence').toBeCloseTo(batchCount * 0.20, 6);
    for (const [index, sound] of evidence.batch.entries()) {
      expect(sound.fingerprint, 'Each batch item reuses the manual collection recording').toBe(evidence.manual.fingerprint);
      expect(sound.peak, 'Each collection pop contains audible samples').toBeGreaterThan(0.01);
      expect(sound.playbackRate, 'The fixed recording retains its original pitch and length').toBe(1);
      if (index > 0) expect(sound.at, 'The next collected word starts a new audio beat').toBeGreaterThan(evidence.batch[index - 1].at);
    }
    await page.waitForTimeout(350);
    expect(collectionSounds(await playbacksSince(page, batchFrom), evidence.manual), 'Finished batch presentation never repeats the collection pop').toHaveLength(batchCount);

    await muteInMenu(page, true, 'word_jelly');
    const mutedFrom = await playbackIndex(page), beforeMutedBatch = await prepareWordCollection(page);
    const mutedCount = beforeMutedBatch.collect_button.count;
    expect(mutedCount).toBeGreaterThanOrEqual(2);
    await pressJellyRect(page, beforeMutedBatch.collect_button.rect);
    await expect.poll(async () => (await jelly(page)).collection_batch.completed).toBe(mutedCount);
    await expect.poll(async () => (await jelly(page)).collection_batch.active).toBe(false);
    expect((await jelly(page)).cleared_pairs).toBe(beforeMutedBatch.cleared_pairs + mutedCount);
    evidence.mutedBatchCount = mutedCount;
    expect(await playbacksSince(page, mutedFrom), 'Muted supply preparation and batch collection emit no audio sources').toEqual([]);
  } finally {
    await page.mouse.up();
    await context.setOffline(false);
    await info.attach('word-jelly-browser-audio.json', { body: Buffer.from(JSON.stringify(evidence, null, 2)), contentType: 'application/json' });
  }
  expect(requests, 'The fixed collection pop and pronunciations are bundled for offline collection').toEqual([]);
  expect(errors).toEqual([]);
});
