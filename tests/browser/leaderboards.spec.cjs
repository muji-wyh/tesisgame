const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const { enterGame, chooseMode, chooseRoundPlayer, metrics, tap, rendered, openRewards,
  leaderboardSnapshot: snapshot, leaderboardControl: control, activateLeaderboardControl: activate,
  typeLeaderboardName: typeName } = require('./game-ui.cjs');

const STORAGE_KEY = 'wordBuddies.leaderboards';
// This fixture is also loaded by the native state suite before browser coverage.
const RANKING_FIXTURE = '[leaderboard]\nversion=1\n' +
  'profiles=[{"id":"player-a","name":"Avery","avatar":"fox"},{"id":"player-b","name":"Blake","avatar":"duck"}]\n' +
  'bests={"pop":{"player-a":{"hits":1},"player-b":{"hits":0}},"match":{},"memory":{}}\nreceipts=[]\n';

async function installFixtures(page, { seed = null, speech = false } = {}) {
  await page.addInitScript(({ key, seed, speech }) => {
    if (seed && localStorage.getItem(key) === null) localStorage.setItem(key, seed);
    window.__leaderboardWrites = [];
    window.__denyLeaderboardSave = false;
    const setItem = Storage.prototype.setItem;
    Storage.prototype.setItem = function (name, value) {
      if (name === key) {
        if (window.__denyLeaderboardSave) throw new DOMException('Simulated full storage', 'QuotaExceededError');
        window.__leaderboardWrites.push(value);
      }
      return setItem.call(this, name, value);
    };
    if (!speech) return;
    const fixture = { instances: [], starts: 0 };
    class Recognition {
      constructor() { this.results = []; fixture.instances.push(this); }
      start() {
        fixture.starts++;
        this.callbacks = { start: this.onstart, result: this.onresult, error: this.onerror, end: this.onend };
        queueMicrotask(() => this.callbacks.start?.());
      }
      abort() {
        const callbacks = this.callbacks;
        queueMicrotask(() => { callbacks?.error?.({ error: 'aborted' }); callbacks?.end?.(); });
      }
      stop() { const callbacks = this.callbacks; queueMicrotask(() => callbacks?.end?.()); }
      emit(transcript) {
        const resultIndex = this.results.length;
        this.results.push(Object.assign([{ transcript, confidence: 0.95 }], { isFinal: true }));
        this.callbacks.result?.({ resultIndex, results: this.results });
      }
    }
    window.__leaderboardSpeech = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: Recognition });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => { throw new Error('The fixture must not capture a physical microphone'); };
  }, { key: STORAGE_KEY, seed, speech });
}

function observeErrors(page) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  return errors;
}

async function openPanel(page, name) {
  await openRewards(page);
  await activate(page, name);
}

async function replay(page) {
  // Keyboard navigation reveals Play again even when a rank rise scrolled down.
  for (let attempt = 0; attempt < 55; attempt++) {
    const button = await page.locator('#pop-status').evaluate(element =>
      JSON.parse(element.dataset.controls || '[]').find(item => item.name === 'Replay' && !item.disabled));
    if (button) {
      await tap(page, button.x + button.width / 2, button.y + button.height / 2);
      await rendered(page);
      return;
    }
    await page.keyboard.press('Shift+Tab');
    await page.waitForTimeout(130);
  }
  throw new Error('Play again could not be revealed through the result focus order.');
}

function expectNarrowLayout(current, bounds) {
  for (const item of current.controls || []) {
    const [x, , width, height] = item.rect;
    expect([x, width, height].every(Number.isFinite), `${item.name} has finite geometry`).toBe(true);
    expect(x, `${item.name} left edge`).toBeGreaterThanOrEqual(-1);
    expect(x + width, `${item.name} right edge`).toBeLessThanOrEqual(bounds.width + 1);
  }
}

function expectInstantPlayerPicker(current) {
  expect(current.controls.some(item => item.name === 'LeaderboardStartGame'),
    'The player choice is the only start action').toBe(false);
  const [left, top, width, height] = current.surface_rect;
  const choices = current.controls.filter(item => item.name.startsWith('LeaderboardPlayer_'));
  expect(choices.length).toBeGreaterThan(0);
  for (const player of choices) {
    const [x, y, playerWidth, playerHeight] = player.rect;
    expect(x, `${player.name} stays inside the choice frame`).toBeGreaterThanOrEqual(left);
    expect(x + playerWidth).toBeLessThanOrEqual(left + width + 1);
    expect(y).toBeGreaterThanOrEqual(top);
    expect(y + playerHeight).toBeLessThanOrEqual(top + height + 1);
  }
  const add = current.controls.find(item => item.name === 'LeaderboardAddPlayer');
  expect(add, 'The separate add-player action remains available').toBeTruthy();
  expect(add.rect[1], 'Add player is below and outside the bordered choice frame').toBeGreaterThan(top + height);
}

function expectCompactResultBoard(current) {
  expect(current.view, 'The embedded board uses the compact result presentation').toBe('result');
  expect(current.mode).toBe('pop');
  expect(current.controls.some(item => item.name.startsWith('LeaderboardMode_')),
    'Mode switches are available in the menu, not inside a Voice Pop result').toBe(false);
  expect(current.controls.some(item => item.name.startsWith('LeaderboardPlayer_') || item.name === 'LeaderboardAddPlayer'),
    'The chosen player cannot be edited in the result board').toBe(false);
}

async function expectResultIdentity(page, expected) {
  await rendered(page);
  const hits = await page.locator('#pop-status').evaluate(element => JSON.parse(element.dataset.resultsHits || '{}'));
  expect(hits.player).toMatchObject(expected);
  const bounds = await metrics(page);
  for (const [name, rect] of Object.entries({ player: hits.player.rect, avatar: hits.player.avatar_rect, name: hits.player.name_rect, hits: hits.rect })) {
    expect(rect, `${name} exposes its visible layout`).toHaveLength(4);
    const [x, y, width, height] = rect;
    expect(rect.every(Number.isFinite), `${name} has finite geometry`).toBe(true);
    expect(width, `${name} has a visible width`).toBeGreaterThan(0);
    expect(height, `${name} has a visible height`).toBeGreaterThan(0);
    expect(x, `${name} remains on the left side of the canvas`).toBeGreaterThanOrEqual(-1);
    expect(x + width, `${name} remains on the right side of the canvas`).toBeLessThanOrEqual(bounds.width + 1);
    expect(y, `${name} remains visible at the top of the results`).toBeGreaterThanOrEqual(-1);
    expect(y + height).toBeLessThanOrEqual(bounds.height + 1);
  }
  expect(hits.player.rect[0] + hits.player.rect[2], 'The avatar and name sit to the left of Hits without overlapping')
    .toBeLessThanOrEqual(hits.rect[0] + 1);
}

test('first entry requires a saved player, players persist locally and every mode has a board', async ({ page }, info) => {
  // Software-rendered canvas calls are slow; action deadlines remain strict.
  test.setTimeout(180000);
  const errors = observeErrors(page);
  await installFixtures(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page, { onboarding: false });
  await expect.poll(async () => (await snapshot(page)).view).toBe('onboarding');
  await page.screenshot({ path: info.outputPath('first-player-onboarding.png') });
  expect((await snapshot(page)).controls.some(item => item.name === 'LeaderboardClose'),
    'The mandatory first player cannot be dismissed with Back').toBe(false);
  await page.keyboard.press('Escape');
  await rendered(page);
  expect((await snapshot(page)).view, 'Escape cannot skip first-player creation').toBe('onboarding');
  expect((await control(page, 'LeaderboardCreatePlayer')).disabled, 'A blank profile cannot be saved').toBe(true);
  await activate(page, 'LeaderboardAvatar_fox');
  await typeName(page, 'Avery');
  await page.evaluate(() => { window.__denyLeaderboardSave = true; });
  await activate(page, 'LeaderboardCreatePlayer');
  await expect.poll(async () => (await snapshot(page)).error || '').not.toBe('');
  expect((await snapshot(page)).view, 'Save failure keeps gameplay behind the first-player gate').toBe('onboarding');
  expect((await snapshot(page)).profiles).toEqual([]);
  expect(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEY)).toBeNull();
  await page.evaluate(() => { window.__denyLeaderboardSave = false; });
  await activate(page, 'LeaderboardCreatePlayer');
  await expect.poll(async () => (await snapshot(page)).visible).toBe(false);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await openPanel(page, 'MenuPlayers');
  await expect.poll(async () => (await snapshot(page)).profiles?.map(item => item.name)).toEqual(['Avery']);
  const profile = (await snapshot(page)).profiles[0];
  expect(profile.avatar).toBe('fox');
  expect(profile.id).toBeTruthy();
  expectNarrowLayout(await snapshot(page), await metrics(page));
  await page.screenshot({ path: info.outputPath('local-player-with-avatar.png') });

  // Tab cannot move focus into the covered game or Pip's room.
  for (let index = 0; index < 22; index++) {
    const previous = (await snapshot(page)).controls.find(item => item.focused)?.name || '';
    await page.keyboard.press('Tab');
    await expect.poll(async () => {
      const focused = (await snapshot(page)).controls.find(item => item.focused)?.name || '';
      return focused !== '' && focused !== previous;
    }, { message: 'Modal focus stays within the panel and advances after Tab', intervals: [50, 100] }).toBe(true);
  }
  await page.keyboard.press('Escape');
  await rendered(page);
  await activate(page, 'MenuLeaderboards');
  for (const mode of ['pop', 'match', 'memory']) {
    await activate(page, `LeaderboardMode_${mode}`);
    await expect.poll(async () => (await snapshot(page)).mode).toBe(mode);
    expect((await snapshot(page)).rows, 'An unsaved round never creates a score').toEqual([]);
  }
  await page.reload();
  await enterGame(page, { onboarding: false });
  await expect.poll(async () => (await snapshot(page)).visible).toBe(false);
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  await openPanel(page, 'MenuPlayers');
  expect((await snapshot(page)).profiles).toEqual([profile]);
  expect(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEY)).toContain('Avery');
  expect(errors).toEqual([]);
});

test('a completed Voice Pop round saves once, survives a failed save and visibly climbs the local board', async ({ page }, info) => {
  test.setTimeout(170000);
  const errors = observeErrors(page);
  await installFixtures(page, { seed: RANKING_FIXTURE, speech: true });
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/');
  await enterGame(page);
  await chooseMode(page, 'pop', { choosePlayer: false });
  await expect.poll(async () => (await snapshot(page)).view).toBe('picker');
  expectInstantPlayerPicker(await snapshot(page));
  await page.screenshot({ path: info.outputPath('voice-pop-player-picker.png') });
  expect((await snapshot(page)).selected_player).toBe('');
  expect(await page.evaluate(() => window.__leaderboardSpeech.starts), 'The microphone stays off while choosing a player').toBe(0);
  const remaining = await page.locator('#pop-status').getAttribute('data-remaining');
  await page.waitForTimeout(250);
  expect(await page.locator('#pop-status').getAttribute('data-remaining'), 'The round clock does not tick in the player picker').toBe(remaining);
  await chooseRoundPlayer(page, { playerId: 'player-b' });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await expect.poll(async () => (await snapshot(page)).round_player_id).toBe('player-b');
  expect(await page.evaluate(() => window.__leaderboardSpeech.starts), 'One player gesture starts the microphone once').toBe(1);
  await expect.poll(() => page.locator('#pop-status').evaluate(element => JSON.parse(element.dataset.targets || '[]').length)).toBeGreaterThan(0);
  for (let hit = 1; hit <= 2; hit++) {
    await expect.poll(() => page.locator('#pop-status').evaluate(element => JSON.parse(element.dataset.targets || '[]').length)).toBeGreaterThan(0);
    const word = await page.locator('#pop-status').evaluate(element => JSON.parse(element.dataset.targets)[0].text);
    await page.evaluate(word => window.__leaderboardSpeech.instances.at(-1).emit(word), word);
    await expect(page.locator('#pop-status')).toHaveAttribute('data-hits', String(hit));
  }
  await page.evaluate(() => { window.__denyLeaderboardSave = true; });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 60000 });
  await expect.poll(async () => (await snapshot(page)).round_id || '').not.toBe('');
  const round = (await snapshot(page)).round_id;
  expect((await snapshot(page)).submitted).toBe(false);
  await expect.poll(async () => (await snapshot(page)).error || '').not.toBe('');
  expectCompactResultBoard(await snapshot(page));
  await expectResultIdentity(page, { id: 'player-b', name: 'Blake', avatar: 'duck' });
  await page.screenshot({ path: info.outputPath('voice-pop-compact-result-retry.png') });
  expect((await snapshot(page)).selected_player, 'The automatic result save uses the player selected before play').toBe('player-b');
  expect((await snapshot(page)).controls.some(item => item.name.startsWith('LeaderboardPlayer_')),
    'Results never ask for a second player choice, including after a save failure').toBe(false);
  expect((await control(page, 'LeaderboardSaveScore')).disabled, 'A failed automatic save has an enabled retry').toBe(false);
  expect((await snapshot(page)).submitted, 'A storage failure must not claim or animate the round').toBe(false);
  expect((await snapshot(page)).animation.active).toBe(false);
  expect(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEY)).toBe(RANKING_FIXTURE);

  await page.evaluate(() => {
    window.__denyLeaderboardSave = false;
    window.__rankFrames = [];
    window.__rankCapture = null;
    window.__rankCaptureError = '';
    let capturePending = false;
    const element = document.querySelector('#leaderboard-status');
    const read = () => {
      const current = JSON.parse(element.dataset.snapshot || '{}');
      if (!current.animation?.active) return;
      window.__rankFrames.push({ ...current.animation, at: performance.now() });
      if (window.__rankCapture || capturePending || current.animation.progress < 0.3 || current.animation.progress > 0.65) return;
      capturePending = true;
      // Capture in the page's render frame. A remote screenshot roundtrip can
      // outlast the entire rise on a software-rendered browser.
      requestAnimationFrame(() => {
        const rendered = JSON.parse(element.dataset.snapshot || '{}');
        if (!rendered.animation?.active) {
          window.__rankCaptureError = 'The avatar ascent ended before its render-frame capture.';
          return;
        }
        try {
          window.__rankCapture = { snapshot: rendered, png: document.querySelector('#canvas').toDataURL('image/png') };
        } catch (error) {
          window.__rankCaptureError = String(error);
        }
      });
    };
    new MutationObserver(read).observe(element, { attributes: true, attributeFilter: ['data-snapshot'] });
    read();
  });
  await activate(page, 'LeaderboardSaveScore');
  await expect.poll(async () => (await snapshot(page)).submitted,
    { message: 'Retry durably saves the selected player before showing promotion' }).toBe(true);
  await expect.poll(() => page.evaluate(() => Boolean(window.__rankCapture || window.__rankCaptureError)),
    { message: 'The page captures the avatar and name during their ascent' }).toBe(true);
  expect(await page.evaluate(() => window.__rankCaptureError)).toBe('');
  const capture = await page.evaluate(() => window.__rankCapture);
  const celebration = capture.snapshot;
  expectCompactResultBoard(celebration);
  expect(celebration.animation.active).toBe(true);
  expect(celebration.animation.progress).toBeGreaterThanOrEqual(0.3);
  expect(celebration.animation.progress).toBeLessThan(1);
  const capturedPath = info.outputPath('avatar-name-rank-climb.png');
  fs.writeFileSync(capturedPath, Buffer.from(capture.png.split(',')[1], 'base64'));
  await info.attach('avatar-name-rank-climb', { path: capturedPath, contentType: 'image/png' });
  expect(celebration.submitted).toBe(true);
  expect(celebration.animation).toMatchObject({ player_id: 'player-b', old_rank: 2, new_rank: 1 });
  expect(celebration.rows.find(item => item.player_id === 'player-b')).toMatchObject({ rank: 1, name: 'Blake', avatar: 'duck' });
  expect(celebration.rows.find(item => item.player_id === 'player-a').rank, 'The previous leader moves below the improved personal best').toBe(2);
  const bounds = await metrics(page);
  expectNarrowLayout(celebration, bounds);
  expect(celebration.animation.rect[1], 'The promoted avatar and name remain on screen').toBeGreaterThanOrEqual(0);
  expect(celebration.animation.rect[1] + celebration.animation.rect[3], 'The rank climb is visible rather than below the result scroller').toBeLessThanOrEqual(bounds.height + 1);
  await expect.poll(async () => (await snapshot(page)).animation.active).toBe(false);
  await page.screenshot({ path: info.outputPath('saved-local-leaderboard.png') });
  const frames = await page.evaluate(() => window.__rankFrames);
  expect(frames.length, 'The celebration has multiple rendered animation samples').toBeGreaterThan(2);
  expect(frames.at(-1).progress).toBeGreaterThan(frames[0].progress);
  expect(frames[0].origin_y, 'The avatar and name start in the player\'s previous row').toBeGreaterThan(frames[0].target_y);
  expect(frames.at(-1).current_y - frames.at(-1).target_y,
    'The actual avatar/name row moves upward relative to the board even while the camera follows it')
    .toBeLessThan(frames[0].current_y - frames[0].target_y);
  await info.attach('rank-climb-frames.json', { body: JSON.stringify(frames), contentType: 'application/json' });
  const submitted = await snapshot(page);
  expectCompactResultBoard(submitted);
  expect(submitted.controls, 'The saved compact board has no redundant actions').toEqual([]);
  expect(submitted.round_id).toBe(round);
  expect(submitted.controls.some(item => item.name === 'LeaderboardSaveScore' || item.name.startsWith('LeaderboardPlayer_')),
    'A saved round cannot be reassigned to another player').toBe(false);
  const saved = await page.evaluate(key => localStorage.getItem(key), STORAGE_KEY);
  expect(await page.evaluate(() => window.__leaderboardWrites.length), 'The failed attempt was retried with one durable write').toBe(1);
  const startsBeforeReplay = await page.evaluate(() => window.__leaderboardSpeech.starts);
  await replay(page);
  await expect.poll(async () => (await snapshot(page)).view).toBe('picker');
  expect((await snapshot(page)).selected_player, 'Replay requires a fresh explicit choice').toBe('');
  expectInstantPlayerPicker(await snapshot(page));
  expect(await page.evaluate(() => window.__leaderboardSpeech.starts), 'Replay waits for the next player before listening').toBe(startsBeforeReplay);
  await activate(page, 'LeaderboardPlayer_player-a');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await expect.poll(async () => (await snapshot(page)).round_player_id).toBe('player-a');
  expect(await page.evaluate(() => window.__leaderboardSpeech.starts), 'The next player starts replay with one gesture').toBe(startsBeforeReplay + 1);
  expect(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEY), 'An unfinished replay cannot overwrite the completed round').toBe(saved);
  await page.reload();
  await enterGame(page);
  await openPanel(page, 'MenuLeaderboards');
  expect((await snapshot(page)).view, 'The menu retains the full leaderboard browser').toBe('boards');
  expect((await snapshot(page)).controls.filter(item => item.name.startsWith('LeaderboardMode_'))).toHaveLength(3);
  await activate(page, 'LeaderboardMode_pop');
  expect((await snapshot(page)).rows.find(item => item.player_id === 'player-b')).toMatchObject({ rank: 1, name: 'Blake', avatar: 'duck' });
  expect((await snapshot(page)).animation.active, 'Reading a saved score does not replay its celebration').toBe(false);
  expect(await page.evaluate(key => localStorage.getItem(key), STORAGE_KEY)).toBe(saved);
  expect(await page.evaluate(() => window.__leaderboardWrites.length), 'Opening boards performs no score writes').toBe(0);
  expect(errors).toEqual([]);
});

test('adding a player before Voice Pop returns to the choices until the new avatar is tapped', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors = observeErrors(page);
  await installFixtures(page, { seed: RANKING_FIXTURE, speech: true });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  await enterGame(page);
  await chooseMode(page, 'pop', { choosePlayer: false });
  await expect.poll(async () => (await snapshot(page)).view).toBe('picker');
  expectInstantPlayerPicker(await snapshot(page));
  await activate(page, 'LeaderboardAddPlayer');
  await activate(page, 'LeaderboardAvatar_cat');
  await typeName(page, 'Casey');
  await activate(page, 'LeaderboardCreatePlayer');
  await expect.poll(async () => (await snapshot(page)).profiles?.map(profile => profile.name)).toEqual(['Avery', 'Blake', 'Casey']);
  const current = await snapshot(page);
  const created = current.profiles.find(profile => profile.name === 'Casey');
  expect(current.view, 'Saving a profile does not implicitly choose a round player').toBe('picker');
  expect(current.controls.some(item => item.name === 'LeaderboardName'), 'Saving closes the player editor').toBe(false);
  expectInstantPlayerPicker(current);
  await expect.poll(async () => (await control(page, `LeaderboardPlayer_${created.id}`)).focused,
    { message: 'The newly created player receives focus so one gesture can start the round' }).toBe(true);
  expect(await page.evaluate(() => window.__leaderboardSpeech.starts), 'Creating a profile does not start recording').toBe(0);
  expect(await page.locator('#pop-status').getAttribute('data-phase')).not.toBe('running');
  await page.screenshot({ path: info.outputPath('voice-pop-new-player-ready.png') });
  await activate(page, `LeaderboardPlayer_${created.id}`);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await expect.poll(async () => (await snapshot(page)).round_player_id).toBe(created.id);
  expect(await page.evaluate(() => window.__leaderboardSpeech.starts)).toBe(1);
  expect(errors).toEqual([]);
});
