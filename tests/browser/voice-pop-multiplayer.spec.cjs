const { test, expect } = require('@playwright/test');
const { chooseMode, enterGame, metrics, rendered, tap } = require('./game-ui.cjs');

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
      const embedding = [0, 0, 0, 0, 0];
      embedding[player - 1] = 1;
      const event = { type: 'utterance', sessionId: record.options.sessionId,
        eventId: eventId || 'fixture-' + (++this.serial), text,
        startMs: Math.max(record.options.elapsedMs, elapsed - 60), endMs: Math.max(record.options.elapsedMs + 1, elapsed - 15), embedding };
      this.lastEvent = event;
      record.options.onEvent(event);
      return event;
    }
    repeatLast() { this.current?.options.onEvent(this.lastEvent); }
    fail() { this.current?.options.onError(new Error('Fixture microphone interrupted. Tap Retry.')); }
  }
  window.VoicePopMultiplayer = Multiplayer;
}.toString()})();`;

async function open(page) {
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
  if (player !== 5) await expect.poll(async () => (await state(page)).hits).toBe(before + 1);
  return target;
}

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
  for (const player of [1, 2, 3, 4]) await pop(page, player);
  await page.evaluate(() => window.__multi.repeatLast());
  expect((await state(page)).hits).toBe(4);
  const fifth = await pop(page, 5);
  await rendered(page);
  expect((await state(page)).hits).toBe(4);
  expect((await state(page)).players.map(player => [player.id, player.hits])).toEqual([['P1', 1], ['P2', 1], ['P3', 1], ['P4', 1]]);
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
  expect(result.ranking.map(player => [player.id, player.hits, player.rank])).toEqual([['P1', 1, 1], ['P2', 1, 1]]);
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
    expect(current.players.map(player => player.id)).toEqual(['P1', 'P2']);
    for (const target of current.targets) {
      expect(target.x).toBeGreaterThanOrEqual(-1);
      expect(target.x + target.width).toBeLessThanOrEqual(bounds.width + 1);
      expect(target.y + target.height).toBeLessThanOrEqual(bounds.height + 1);
    }
    await page.screenshot({ path: info.outputPath('multiplayer-playing.png') });
    expect(errors).toEqual([]);
  });
}
