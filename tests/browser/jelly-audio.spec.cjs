const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, metrics, tap, rendered } = require('./game-ui.cjs');
const { watchAudioRequests, observeOutputAudio, expectOutputEnergy, expectRecording, recordingTiming } = require('./bundled-audio.cjs');

const CLIPS = {
  pick: 'assets/imported-audio/ui-click/select.wav',
  release: 'assets/imported-audio/chest-reference/step.wav',
  land: 'assets/imported-audio/chest-reference/step-detail.wav',
  merge: 'assets/audio/jelly-match/merge.wav',
  clear: 'assets/audio/jelly-match/clear.wav'
};
const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const playbackIndex = page => page.evaluate(() => window.audioObservation.playbacks.length);
const playbacksSince = (page, from) => page.evaluate(index => window.audioObservation.playbacks.slice(index), from);

test.use({ deviceScaleFactor: 1,
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

async function libraryControl(page, name) {
  const control = (await metrics(page)).library.controls.find(item => item.name === name);
  expect(control, `${name} is present in the game library`).toBeTruthy();
  expect(control.disabled).toBe(false);
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
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
    for (const first of state.tiles || []) {
      if (!first.visible || !first.settled || first.chest) continue;
      const second = state.tiles.find(tile => tile.visible && tile.settled && !tile.chest &&
        tile.id !== first.id && tile.word.id === first.word.id && tile.kind !== first.kind);
      if (second) { found = [first, second]; break; }
    }
    return Boolean(found);
  }, { timeout: 30000, message: 'Single-tile supply provides a real, unmarked word and picture pair' }).toBe(true);
  return found;
}

function center(rect, bounds) {
  return { x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale };
}

async function beginDrag(page, tile) {
  const current = (await jelly(page)).tiles.find(item => item.id === tile.id);
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
    }, { message: `${path} plays its own samples, distinct from the equal-duration landing clip` }).toBe(true);
  }
  expect(playback.fingerprint, `${path} was decoded into observed PCM`).toBeTruthy();
  expect(playback.peak, `${path} contains nonzero samples`).toBeGreaterThan(0.01);
  return playback;
}

function matching(playbacks, recording) {
  return playbacks.filter(playback => playback.fingerprint === recording.fingerprint);
}

async function muteInMenu(page, muted) {
  await openModeMenu(page);
  const isMuted = () => page.evaluate(() => Boolean(JSON.parse(localStorage.getItem('pipAndWords.presentation.v1') || '{}').muted));
  if (await isMuted() !== muted) await libraryControl(page, 'LibrarySound');
  await expect.poll(isMuted).toBe(muted);
  await libraryControl(page, 'LibraryClose');
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
  test.setTimeout(150000);
  const requests = watchAudioRequests(page), evidence = {};
  await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  test.skip(!available, 'This browser runtime has no WebAudio.');
  await openModeMenu(page);
  const startup = await playbackIndex(page);
  await libraryControl(page, 'Mode_jelly');
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
    // Both source files last 240 ms: compare decoded sample identity so a
    // landing sound cannot accidentally satisfy the empty-drop assertion.
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

    const tiles = await availablePair(page), beforeMerge = await playbackIndex(page);
    await beginDrag(page, tiles[0]);
    await hoverTile(page, tiles[1]);
    await page.mouse.up();
    evidence.merge = await audibleRecording(page, beforeMerge, CLIPS.merge);
    evidence.clear = await audibleRecording(page, beforeMerge, CLIPS.clear);
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(clearedBeforeDrop + 1);
    expect(evidence.clear.at).toBeGreaterThan(evidence.merge.at);
    expect(new Set(['pick', 'release', 'land', 'merge', 'clear'].map(cue => evidence[cue].fingerprint)).size).toBe(5);
    const mergeSounds = await playbacksSince(page, beforeMerge);
    expect(matching(mergeSounds, evidence.merge)).toHaveLength(1);
    expect(matching(mergeSounds, evidence.clear)).toHaveLength(1);
    expect(matching(mergeSounds, evidence.release), 'A successful drop does not also play empty-drop audio').toEqual([]);

    await settledBoard(page);
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

    await muteInMenu(page, true);
    const mutedFrom = await playbackIndex(page), mutedPair = await availablePair(page);
    const mutedScore = (await jelly(page)).cleared_pairs;
    await beginDrag(page, mutedPair[0]);
    await hoverTile(page, mutedPair[1]);
    await page.mouse.up();
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(mutedScore + 1);
    expect(await playbacksSince(page, mutedFrom), 'Mute silences pick, speech, merge, clear, and landing').toEqual([]);

    await muteInMenu(page, false);
    await settledBoard(page);
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
    await libraryControl(page, 'LibraryClose');
    evidence.resumedClear = await audibleRecording(page, resumeFrom, CLIPS.clear);
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(paused.cleared_pairs + 1);
    const resumed = await playbacksSince(page, resumeFrom);
    expect(matching(resumed, evidence.clear)).toHaveLength(1);
    expect(matching(resumed, evidence.merge), 'Resuming a committed fusion does not restart its merge sound').toEqual([]);

    await settledBoard(page);
    const leaveFrom = await playbackIndex(page), lastTiles = await availablePair(page);
    await interruptFusion(page, lastTiles);
    await audibleRecording(page, leaveFrom, CLIPS.merge);
    await libraryControl(page, 'Mode_match');
    await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
    const afterLeave = await playbackIndex(page);
    await page.waitForTimeout(1200);
    evidence.afterLeave = await playbacksSince(page, afterLeave);
    for (const cue of ['release', 'land', 'merge', 'clear']) {
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
