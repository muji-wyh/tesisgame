const { test, expect } = require('@playwright/test');
const { chooseMode, enterGame, metrics, rendered, tap, openRewards, collectionHeaderRect } = require('./game-ui.cjs');
const { SPEAKER_MODEL_VERSION } = require('../../web/voice-profiles.js');
const catalogWords = require('../../words.json').map(word => word.text);

// This fixture exercises the real host, JavaScriptBridge and Godot UI with
// deterministic recognition events. It does not assert acoustic model quality.
const multiplayerFixture = `(${function installMultiplayerFixture() {
  class Multiplayer {
    constructor() {
      window.__multi = this;
      this.state = { status: 'idle', loaded: 0, total: 1000 };
      this.observers = [];
      this.records = [];
      this.prepares = 0;
      this.flushes = 0;
      this.serial = 0;
      this.automatic = false;
      this.holdFlush = false;
      this.current = null;
    }
    observe(callback) { this.observers.push(callback); callback(this.state); }
    setState(state) { this.state = { ...state }; this.observers.forEach(callback => callback(this.state)); }
    prepare() {
      this.prepares++;
      if (this.state.status === 'idle') this.setState({ status: 'downloading', loaded: 420, total: 1000 });
      return Promise.resolve();
    }
    isReady() { return this.state.status === 'ready'; }
    verifyReady() { return Promise.resolve(this.isReady()); }
    async start(options) {
      const record = { options, gesture: navigator.userActivation?.isActive ?? null, stopped: false, started: false };
      this.current = record;
      this.records.push(record);
      if (this.automatic) queueMicrotask(() => this.grant());
    }
    grant() {
      const record = this.current;
      if (!record || record.stopped || record.started) return;
      record.started = true;
      record.startedAt = performance.now();
      record.options.onStarted();
    }
    stop() { if (this.current) this.current.stopped = true; this.current = null; return true; }
    async startEnrollment(options) {
      this.stop();
      this.enrollment = options;
      options.onStarted();
      return true;
    }
    sample() { this.enrollment.onProgress({ segments: 3, voicedMs: 13200, requiredSegments: 3, requiredVoicedMs: 12000, progress: 1, canFinish: true }); }
    async finishEnrollment() {
      const embedding = Array(256).fill(0); embedding[0] = 1;
      this.enrollment.onComplete({ embedding, templates: [embedding.slice(), embedding.slice(), embedding.slice()],
        segments: Array.from({ length: 3 }, () => ({ embedding: embedding.slice(), voicedMs: 4400 })),
        modelVersion: window.SPEAKER_MODEL_VERSION, quality: { segments: 3, voicedMs: 13200 } });
      this.enrollment = null;
      return true;
    }
    cancelEnrollment() { this.enrollment = null; return true; }
    async flush() {
      this.flushes++;
      const record = this.current;
      if (!record || this.holdFlush) return;
      record.options.onFlushed({ type: 'flushed', sessionId: record.options.sessionId });
    }
    emit(text, player, eventId = '') {
      const record = this.current;
      if (!record?.started) throw new Error('Fixture microphone has not started');
      const elapsed = record.options.elapsedMs + performance.now() - record.startedAt;
      const embedding = Array(256).fill(0);
      embedding[player - 1] = 1;
      const event = { type: 'utterance', sessionId: record.options.sessionId,
        eventId: eventId || 'fixture-' + (++this.serial), text,
        startMs: Math.max(record.options.elapsedMs, elapsed - 60), endMs: Math.max(record.options.elapsedMs + 1, elapsed - 15), embedding };
      this.lastEvent = event;
      record.options.onEvent(event);
      return event;
    }
    repeatLast() { this.current?.options.onEvent(this.lastEvent); }
    feedback(reason, text = '') {
      const record = this.current;
      if (!record?.started) throw new Error('Fixture microphone has not started');
      const elapsed = record.options.elapsedMs + performance.now() - record.startedAt;
      const event = { type: 'feedback', sessionId: record.options.sessionId,
        eventId: 'feedback-' + (++this.serial), reason, text,
        startMs: Math.max(record.options.elapsedMs, elapsed - 60), endMs: Math.max(record.options.elapsedMs + 1, elapsed - 15) };
      this.lastFeedback = event;
      record.options.onFeedback(event);
      return event;
    }
    fail() { this.current?.options.onError(new Error('Fixture microphone interrupted. Tap Retry.')); }
  }
  window.VoicePopMultiplayer = Multiplayer;
}.toString()})();`;

async function open(page, { seed = true } = {}) {
  await page.route('**/multiplayer-host.js', route => route.fulfill({ contentType: 'application/javascript', body: multiplayerFixture }));
  await page.route('**/models/voice-pop/**', route => route.abort());
  await page.addInitScript(() => {
    const fixture = { instances: [], starts: 0, aborts: 0 };
    class Recognition {
      constructor() { this.results = []; fixture.instances.push(this); }
      start() {
        fixture.starts++;
        this.callbacks = { start: this.onstart, result: this.onresult, end: this.onend };
        queueMicrotask(() => this.callbacks.start?.());
      }
      abort() { fixture.aborts++; this.onend?.(); }
      stop() { this.abort(); }
      emit(text) {
        const result = Object.assign([{ transcript: text, confidence: 1 }], { isFinal: true });
        this.results.push(result);
        this.callbacks.result?.({ resultIndex: this.results.length - 1, results: this.results });
      }
    }
    window.__solo = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: Recognition });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => { throw new Error('Tests never capture a real microphone'); };
  });
  if (seed) await page.addInitScript(modelVersion => {
    if (localStorage.getItem('voice-pop-voice-profiles-v1') !== null) return;
    localStorage.setItem('voice-pop-voice-profiles-v1', JSON.stringify({ schemaVersion: 1, revision: 1,
      profiles: ['🐱', '🐶', '🐼', '🦊', '🐰'].map((emoji, index) => ({
        id: 'user-' + (index + 1), name: ['Mia', 'Leo', 'Amy', 'Max', 'Zoe'][index], emoji,
        embedding: Array.from({ length: 256 }, (_, i) => i === index ? 1 : 0), modelVersion
      })) }));
  }, SPEAKER_MODEL_VERSION);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  await page.goto('/');
  await enterGame(page);
  expect(await page.evaluate(() => window.__multi.prepares)).toBe(0);
  await chooseMode(page, 'pop');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  return errors;
}

async function state(page) {
  return page.locator('#pop-status').evaluate(element => ({
    phase: element.dataset.phase, remaining: Number(element.dataset.remaining), hits: Number(element.dataset.hits),
    transcript: element.dataset.transcript || '', recognitionFeedback: element.dataset.recognitionFeedback || '',
    recognitionMessage: element.dataset.recognitionMessage || '',
    mode: element.dataset.playMode, multiplayer: JSON.parse(element.dataset.multiplayerState || '{}'),
    choices: element.dataset.modeChoicesVisible === 'true', previous: JSON.parse(element.dataset.previousRound || '{}'),
    players: JSON.parse(element.dataset.players || '[]'), ranking: JSON.parse(element.dataset.ranking || '[]'),
    targets: JSON.parse(element.dataset.targets || '[]'), controls: JSON.parse(element.dataset.controls || '[]'),
    message: element.textContent
  }));
}

async function action(page, name) {
  let control, lastGeometry = '';
  await expect.poll(async () => {
    await rendered(page);
    control = (await state(page)).controls.find(item => item.name === name && !item.disabled && item.width > 1 && item.height > 1);
    const geometry = control ? JSON.stringify([control.x, control.y, control.width, control.height]) : '';
    const settled = geometry !== '' && geometry === lastGeometry;
    lastGeometry = geometry;
    return settled;
  }, { message: `The ${name} action has stable, visible geometry`, intervals: [50, 100] }).toBe(true);
  await tap(page, control.x + control.width / 2, control.y + control.height / 2);
  await rendered(page);
}

async function ready(page) {
  await page.evaluate(() => window.__multi.setState({ status: 'ready', loaded: 1000, total: 1000 }));
  await expect.poll(async () => (await state(page)).choices).toBe(true);
}

async function startMultiplayer(page) {
  await ready(page);
  await page.evaluate(() => { window.__multi.automatic = true; });
  await action(page, 'StartMultiplayer');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-play-mode', 'multi');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
}

async function pop(page, player = 0) {
  let target;
  await expect.poll(async () => {
    target = (await state(page)).targets[0];
    return Boolean(target);
  }).toBe(true);
  // Let the target exist for longer than the fixture's timestamp offset.
  await page.waitForTimeout(90);
  target = (await state(page)).targets.find(item => item.uid === target.uid);
  expect(target, 'The chosen word is still visible when spoken').toBeTruthy();
  const before = (await state(page)).hits;
  await page.evaluate(({ text, player }) => {
    if (player) window.__multi.emit(text, player);
    else window.__solo.instances.at(-1).emit(text);
  }, { text: target.text, player });
  if (player < 5) await expect.poll(async () => (await state(page)).hits).toBe(before + 1);
  return target;
}

async function users(page) {
  await openRewards(page);
  const control = collectionHeaderRect(await metrics(page), 'users');
  await tap(page, control.x + control.width / 2, control.y + control.height / 2);
  await expect(page.getByRole('dialog')).toBeVisible();
}

test('Users records, saves and restores an emoji profile that can score in multiplayer', async ({ page }, info) => {
  const errors = await open(page, { seed: false });
  await users(page);
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByRole('heading', { name: 'Users 0/10' })).toBeVisible();
  await dialog.getByRole('button', { name: 'Add user', exact: true }).click();
  await dialog.getByLabel('Name', { exact: true }).fill('Mia');
  await dialog.getByRole('button', { name: 'Cat', exact: true }).click();
  await expect(dialog.getByRole('button', { name: 'Record voice', exact: true })).toBeDisabled();
  await page.evaluate(() => window.__multi.setState({ status: 'ready', loaded: 1000, total: 1000 }));
  await expect(dialog.getByLabel('Name', { exact: true })).toHaveValue('Mia');
  await dialog.getByRole('button', { name: 'Record voice', exact: true }).click();
  await page.evaluate(() => window.__multi.sample());
  await expect(dialog).toContainText('Ready to stop');
  await dialog.getByRole('button', { name: 'Stop', exact: true }).click();
  await expect(dialog).toContainText('Ready to save');
  expect(await page.evaluate(() => localStorage.getItem('voice-pop-voice-profiles-v1'))).toBeNull();
  await dialog.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(dialog.getByRole('heading', { name: 'Users 1/10' })).toBeVisible();
  await page.screenshot({ path: info.outputPath('saved-voice-user.png') });
  await dialog.getByRole('button', { name: 'Close users' }).click();
  await expect(dialog).toBeHidden();
  expect(await page.evaluate(() => window.__multi.enrollment)).toBeNull();
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('voice-pop-voice-profiles-v1')));
  expect(saved.profiles).toHaveLength(1);
  expect(saved.profiles[0]).toMatchObject({ name: 'Mia', emoji: '🐱', modelVersion: SPEAKER_MODEL_VERSION });
  expect(Object.keys(saved.profiles[0]).sort()).toEqual(['embedding', 'emoji', 'id', 'modelVersion', 'name', 'templates']);
  expect(saved.profiles[0].templates).toHaveLength(3);
  for (const template of saved.profiles[0].templates) {
    expect(template).toHaveLength(256);
    expect(Math.hypot(...template)).toBeCloseTo(1, 6);
  }

  await page.reload();
  await enterGame(page);
  await users(page);
  await expect(dialog.getByRole('heading', { name: 'Users 1/10' })).toBeVisible();
  await dialog.getByRole('button', { name: 'Edit Mia', exact: true }).click();
  await dialog.getByLabel('Name', { exact: true }).fill('Mimi');
  await dialog.getByRole('button', { name: 'Fox', exact: true }).click();
  await dialog.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(dialog.getByRole('button', { name: 'Edit Mimi', exact: true })).toBeVisible();
  await dialog.getByRole('button', { name: 'Close users' }).click();
  const back = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await chooseMode(page, 'pop');
  await startMultiplayer(page);
  await pop(page, 6);
  await rendered(page);
  expect((await state(page)).players).toEqual([]);
  await pop(page, 1);
  expect((await state(page)).players[0]).toMatchObject({ id: saved.profiles[0].id, name: 'Mimi', emoji: '🦊', hits: 1 });
  await page.screenshot({ path: info.outputPath('enrolled-avatar-playing.png') });
  await users(page);
  await dialog.getByRole('button', { name: 'Edit Mimi', exact: true }).click();
  await dialog.getByRole('button', { name: 'Delete user', exact: true }).click();
  await dialog.getByRole('button', { name: 'Delete permanently', exact: true }).click();
  await expect(dialog.getByRole('heading', { name: 'Users 0/10' })).toBeVisible();
  await dialog.getByRole('button', { name: 'Close users' }).click();
  await tap(page, back.x + back.width / 2, back.y + back.height / 2);
  await action(page, 'RetryListening');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await pop(page, 1);
  expect((await state(page)).players[0]).toMatchObject({ name: 'Mimi', emoji: '🦊', hits: 2 });
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('voice-pop-voice-profiles-v1')).profiles)).toEqual([]);
  expect(errors).toEqual([]);
});

test('background readiness leaves solo playable and switches only after a new microphone starts', async ({ page, browserName }, info) => {
  const errors = await open(page);
  expect((await state(page)).multiplayer).toMatchObject({ status: 'downloading', loaded: 420, total: 1000 });
  await pop(page);
  const before = await state(page);
  await page.evaluate(() => window.__multi.setState({ status: 'initializing', loaded: 1000, total: 1000 }));
  expect((await state(page)).choices).toBe(false);
  await page.evaluate(() => window.__multi.setState({ status: 'error', message: 'Fixture warmup failed' }));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect((await state(page)).hits).toBe(before.hits);
  await ready(page);
  expect((await state(page)).mode).toBe('single');
  expect((await state(page)).hits).toBe(before.hits);
  expect((await state(page)).remaining).toBeLessThanOrEqual(before.remaining);
  await action(page, 'ContinueSolo');
  expect((await state(page)).choices).toBe(false);
  await page.evaluate(() => window.__multi.setState({ status: 'ready' }));
  expect((await state(page)).choices).toBe(false);
  await action(page, 'ChoosePopMode');
  await action(page, 'StartMultiplayer');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-play-mode', 'multi');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'ready');
  const waiting = await state(page);
  expect(waiting.previous.hits).toBe(before.hits);
  expect(waiting.previous.play_mode).toBe('single');
  expect(waiting.hits).toBe(0);
  expect(waiting.remaining).toBe(30);
  if (browserName === 'chromium') expect(await page.evaluate(() => window.__multi.records[0].gesture)).toBe(true);
  expect(await page.evaluate(() => window.__solo.aborts)).toBeGreaterThan(0);
  await page.waitForTimeout(350);
  expect((await state(page)).remaining).toBe(30);
  await page.evaluate(() => window.__multi.grant());
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const unknown = await pop(page, 6);
  await rendered(page);
  expect((await state(page)).players).toEqual([]);
  expect((await state(page)).targets.some(target => target.uid === unknown.uid)).toBe(true);
  for (const player of [1, 2, 3, 4]) await pop(page, player);
  await page.evaluate(() => window.__multi.repeatLast());
  expect((await state(page)).hits).toBe(4);
  const fifth = await pop(page, 5);
  await rendered(page);
  expect((await state(page)).hits).toBe(4);
  expect((await state(page)).players.map(player => [player.id, player.emoji, player.hits])).toEqual([
    ['user-1', '🐱', 1], ['user-2', '🐶', 1], ['user-3', '🐼', 1], ['user-4', '🦊', 1]
  ]);
  expect((await state(page)).targets.some(target => target.uid === fifth.uid)).toBe(true);
  await page.screenshot({ path: info.outputPath('four-player-hud.png') });
  await page.evaluate(() => window.__multi.fail());
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  const paused = await state(page);
  await page.waitForTimeout(250);
  expect((await state(page)).remaining).toBe(paused.remaining);
  expect((await state(page)).players).toEqual(paused.players);
  await page.evaluate(() => { window.__multi.automatic = true; });
  await action(page, 'RetryListening');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect((await state(page)).players).toEqual(paused.players);
  const hits = (await state(page)).hits;
  await page.evaluate(() => {
    const old = window.__multi.records[0];
    old.options.onEvent({ ...window.__multi.lastEvent, eventId: 'stale-after-resume' });
  });
  expect((await state(page)).hits).toBe(hits);
  await action(page, 'ChoosePopMode');
  await action(page, 'ContinueSolo');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-play-mode', 'single');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect((await state(page)).previous.hits).toBe(4);
  expect(errors).toEqual([]);
});

test('multiplayer receives round vocabulary and shows non-scoring recognition feedback independently of hits', async ({ page }, info) => {
  const errors = await open(page);
  await startMultiplayer(page);
  const vocabulary = await page.evaluate(() => window.__multi.current.options.vocabulary);
  expect([...vocabulary].sort()).toEqual([...catalogWords].sort());
  const before = await state(page);
  expect(vocabulary.length).toBeGreaterThan(before.targets.length);
  await page.waitForTimeout(100);
  const word = (await state(page)).targets[0].text;
  await page.evaluate(text => window.__multi.feedback('identity_unconfirmed', text), word);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-recognition-feedback', 'identity_unconfirmed');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', word);
  expect((await state(page)).recognitionMessage).toMatch(/voice|who|identify/i);
  expect((await state(page)).hits).toBe(before.hits);
  expect((await state(page)).players).toEqual([]);
  expect((await state(page)).phase).toBe('running');
  await rendered(page);
  expect((await state(page)).transcript).toBe(word);
  await page.screenshot({ path: info.outputPath('word-heard-identity-unconfirmed.png') });

  await page.evaluate(() => window.__multi.feedback('unclear_speech'));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-recognition-feedback', 'unclear_speech');
  expect((await state(page)).recognitionMessage).toMatch(/hear|clear|try|again|say/i);
  expect((await state(page)).hits).toBe(before.hits);
  await pop(page, 1);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-recognition-feedback', '');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-recognition-message', '');
  expect((await state(page)).players[0]).toMatchObject({ name: 'Mia', hits: 1 });
  await page.evaluate(() => { window.__firstScoredEvent = window.__multi.lastEvent; });
  await pop(page, 1);
  const afterHit = await state(page);
  await page.evaluate(() => {
    window.__multi.current.options.onFeedback(window.__multi.lastFeedback);
    window.__multi.current.options.onEvent(window.__firstScoredEvent);
  });
  await rendered(page);
  expect((await state(page)).recognitionFeedback).toBe('');
  expect((await state(page)).transcript).toBe(afterHit.transcript);
  expect((await state(page)).hits).toBe(afterHit.hits);
  expect(errors).toEqual([]);
});

test('stale recognition feedback cannot cross microphone sessions or a switch back to Solo', async ({ page }) => {
  const errors = await open(page);
  await startMultiplayer(page);
  await page.waitForTimeout(100);
  await page.evaluate(() => window.__multi.feedback('timing_unavailable', 'a word was heard'));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-recognition-feedback', 'timing_unavailable');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', 'a word was heard');
  await page.evaluate(() => window.__multi.fail());
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await action(page, 'RetryListening');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await pop(page, 1);
  const resumed = await state(page);
  await page.evaluate(() => {
    const old = window.__multi.records[0];
    const event = { ...window.__multi.lastFeedback, eventId: 'stale-feedback', text: 'stale feedback' };
    old.options.onFeedback(event);
    window.__multi.current.options.onFeedback(event);
  });
  await rendered(page);
  expect((await state(page)).recognitionFeedback).toBe('');
  expect((await state(page)).transcript).toBe(resumed.transcript);
  expect((await state(page)).hits).toBe(resumed.hits);

  await action(page, 'ChoosePopMode');
  await action(page, 'ContinueSolo');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-play-mode', 'single');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await pop(page);
  const solo = await state(page);
  await page.evaluate(() => {
    for (const record of window.__multi.records) record.options.onFeedback({
      ...window.__multi.lastFeedback, sessionId: record.options.sessionId,
      eventId: 'stale-after-switch', reason: 'identity_unconfirmed', text: 'old multiplayer words'
    });
  });
  await rendered(page);
  expect((await state(page)).recognitionFeedback).toBe('');
  expect((await state(page)).transcript).toBe(solo.transcript);
  expect((await state(page)).hits).toBe(solo.hits);
  expect(errors).toEqual([]);
});

test('multiplayer drains at the deadline, ranks tied hits, and replay remembers the chosen mode', async ({ page }, info) => {
  const errors = await open(page);
  await startMultiplayer(page);
  await pop(page, 1);
  await pop(page, 2);
  await page.evaluate(() => { window.__multi.holdFlush = true; });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'settling', { timeout: 35000 });
  expect(await page.evaluate(() => window.__multi.flushes)).toBe(1);
  expect((await state(page)).remaining).toBe(0);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 5000 });
  const result = await state(page);
  expect(result.ranking.map(player => [player.name, player.emoji, player.hits, player.rank])).toEqual([['Mia', '🐱', 1, 1], ['Leo', '🐶', 1, 1]]);
  await page.screenshot({ path: info.outputPath('multiplayer-results.png') });
  await action(page, 'Replay');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect((await state(page)).mode).toBe('multi');
  expect((await state(page)).players).toEqual([]);
  expect((await state(page)).hits).toBe(0);
  expect(errors).toEqual([]);
});

for (const viewport of [{ width: 320, height: 568 }, { width: 844, height: 390 }]) {
  test(`multiplayer choice and player HUD fit ${viewport.width}x${viewport.height} with reduced motion`, async ({ page }, info) => {
    await page.setViewportSize(viewport);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    const errors = await open(page);
    await ready(page);
    await rendered(page);
    let current = await state(page);
    const bounds = await metrics(page);
    for (const name of ['ChoosePopMode', 'ContinueSolo', 'StartMultiplayer']) {
      const control = current.controls.find(item => item.name === name);
      expect(control, `${name} has visible geometry`).toBeTruthy();
      expect(control.x).toBeGreaterThanOrEqual(0);
      expect(control.x + control.width).toBeLessThanOrEqual(bounds.width + 1);
      expect(control.y + control.height).toBeLessThanOrEqual(bounds.height + 1);
    }
    const choicesBottom = Math.max(...current.controls.filter(item => ['ContinueSolo', 'StartMultiplayer'].includes(item.name)).map(item => item.y + item.height));
    expect(current.targets.every(target => target.y >= choicesBottom)).toBe(true);
    await page.screenshot({ path: info.outputPath('multiplayer-ready.png') });
    await page.evaluate(() => { window.__multi.automatic = true; });
    await action(page, 'StartMultiplayer');
    await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
    await pop(page, 1);
    await pop(page, 2);
    await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
    await page.waitForTimeout(120);
    current = await state(page);
    expect(current.players.map(player => player.id)).toEqual(['user-1', 'user-2']);
    for (const target of current.targets) {
      expect(target.x).toBeGreaterThanOrEqual(-1);
      expect(target.x + target.width).toBeLessThanOrEqual(bounds.width + 1);
      expect(target.y + target.height).toBeLessThanOrEqual(bounds.height + 1);
    }
    await page.screenshot({ path: info.outputPath('multiplayer-playing.png') });
    expect(errors).toEqual([]);
  });
}
