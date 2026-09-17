const { test, expect } = require('@playwright/test');
const { chooseMode, metrics, tap, rendered, headerPoint, contentBounds, observeAudio } = require('./game-ui.cjs');

async function installSpeech(page, { automatic = true, available = true } = {}) {
  await page.addInitScript(({ automatic, available }) => {
    const fixture = { starts: 0, aborts: 0, stops: 0, instances: [], spoken: [], cancelled: 0, automatic };
    class Recognition {
      constructor() { this.results = []; fixture.instances.push(this); }
      start() {
        fixture.starts++;
        this.activationAtStart = navigator.userActivation?.isActive ?? null;
        this.callbacks = { start: this.onstart, result: this.onresult, error: this.onerror, end: this.onend };
        if (fixture.automatic) queueMicrotask(() => this.grant());
      }
      grant() { this.callbacks.start?.(); }
      abort() {
        fixture.aborts++;
        if (this.failShutdown) throw new Error('Simulated microphone shutdown failure');
        const callbacks = this.callbacks;
        queueMicrotask(() => { callbacks?.error?.({ error: 'aborted' }); callbacks?.end?.(); });
      }
      stop() {
        fixture.stops++;
        if (this.failShutdown) throw new Error('Simulated microphone shutdown failure');
        const callbacks = this.callbacks;
        queueMicrotask(() => callbacks?.end?.());
      }
      emit(transcript, isFinal = true) {
        const result = Object.assign([{ transcript, confidence: 0.95 }], { isFinal });
        const resultIndex = this.results.length && !this.results.at(-1).isFinal ? this.results.length - 1 : this.results.length;
        this.results[resultIndex] = result;
        this.callbacks.result?.({ resultIndex, results: this.results });
      }
      fail(error) { this.callbacks.error?.({ error }); this.end(); }
      end() { this.callbacks.end?.(); }
    }
    window.__popSpeech = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: available ? Recognition : undefined });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    Object.defineProperty(window, 'SpeechSynthesisUtterance', { configurable: true, value: class { constructor(text) { this.text = text; } } });
    Object.defineProperty(window, 'speechSynthesis', { configurable: true, value: {
      speak(utterance) { fixture.spoken.push(utterance.text); }, cancel() { fixture.cancelled++; }
    } });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => { throw new Error('Test must not capture a physical microphone'); };
  }, { automatic, available });
}

async function open(page, options) {
  await installSpeech(page, options);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  await page.goto('/');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(0);
  await chooseMode(page, 'pop');
  return errors;
}

async function state(page) {
  return page.locator('#pop-status').evaluate(element => ({
    phase: element.dataset.phase, remaining: Number(element.dataset.remaining),
    hits: Number(element.dataset.hits), score: Number(element.dataset.score),
    targets: JSON.parse(element.dataset.targets || '[]'), controls: JSON.parse(element.dataset.controls || '[]'),
    message: element.textContent
  }));
}

async function visibleAction(page, pattern) {
  let button, previous = '';
  await expect.poll(async () => {
    await rendered(page);
    const bounds = await metrics(page), current = await state(page);
    button = current.controls.find(control => !control.disabled && control.width > 1 && control.height > 1 &&
      control.x >= -1 && control.y >= -1 && control.x + control.width <= bounds.width + 1 &&
      control.y + control.height <= bounds.height + 1 && pattern.test(control.text + ' ' + control.name));
    const geometry = button ? JSON.stringify([button.name, button.x, button.y, button.width, button.height]) : '';
    const settled = geometry !== '' && geometry === previous;
    previous = geometry;
    return settled;
  }, { message: `A visible action matching ${pattern} must have settled, nonempty bounds`, intervals: [50, 100, 200] }).toBe(true);
  return button;
}

async function action(page, pattern) {
  const button = await visibleAction(page, pattern);
  await tap(page, button.x + button.width / 2, button.y + button.height / 2);
  await rendered(page);
}

async function expectGestureStart(page, browserName) {
  if (browserName === 'chromium') {
    expect(await page.evaluate(() => window.__popSpeech.instances.at(-1).activationAtStart),
      'The Godot entry or retry gesture must still be active at SpeechRecognition.start').toBe(true);
  }
}

function expectTargetInsidePlayfield(target, bounds) {
  const content = contentBounds(bounds);
  expect(target.width, target.text + ' has visible width').toBeGreaterThan(0);
  expect(target.height, target.text + ' has visible height').toBeGreaterThan(0);
  expect(target.x, target.text + ' left edge').toBeGreaterThanOrEqual(content.x - 1);
  expect(target.x + target.width, target.text + ' right edge').toBeLessThanOrEqual(content.x + content.width + 1);
  expect(target.y, target.text + ' top edge').toBeGreaterThanOrEqual(content.top - 1);
  expect(target.y + target.height, target.text + ' bottom edge').toBeLessThanOrEqual(bounds.height - content.padding + 1);
}

async function popOne(page, { interim = false } = {}) {
  await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
  const before = await state(page), word = before.targets[0].text;
  await page.evaluate(({ word, interim }) => window.__popSpeech.instances.at(-1).emit(word, !interim), { word, interim });
  await expect.poll(async () => (await state(page)).hits).toBe(before.hits + 1);
  return word;
}

test('Voice Pop requests permission on entry, waits, recovers from denial, and releases on mode exit', async ({ page, browserName }, info) => {
  const errors = await open(page, { automatic: false });
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  await expectGestureStart(page, browserName);
  await page.waitForTimeout(1300);
  expect((await state(page)).remaining).toBe(30);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await page.evaluate(() => window.__popSpeech.instances.at(-1).fail('not-allowed'));
  await expect(page.locator('#pop-status')).toContainText(/permission|allow/i);
  await page.screenshot({ path: info.outputPath('permission-denied.png') });
  await page.evaluate(() => { window.__popSpeech.automatic = true; });
  await action(page, /retry|try.*mic|enable|listen/i);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(2);
  await expectGestureStart(page, browserName);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'true');
  await chooseMode(page, 'learn');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  await expect(page.locator('#pop-status')).toBeEmpty();
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  expect(await page.evaluate(() => window.__popSpeech.aborts)).toBeGreaterThan(0);
  expect(errors).toEqual([]);
});

test('leaving while permission is pending rejects a late grant and every callback from that recognizer', async ({ page }) => {
  const errors = await open(page, { automatic: false });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'ready');
  expect((await state(page)).remaining).toBe(30);
  await chooseMode(page, 'learn');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  const otherModeStatus = await page.locator('#game-status').textContent();
  await page.evaluate(() => {
    const old = window.__popSpeech.instances[0];
    old.grant();
    old.emit('cat');
    old.fail('network');
    old.end();
  });
  await page.waitForTimeout(650);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  expect(await page.evaluate(() => window.__popSpeech.aborts)).toBe(1);
  await expect(page.locator('#pop-status')).toBeEmpty();
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await expect(page.locator('#speech-panel')).toBeHidden();
  await expect(page.locator('#game-status')).toHaveText(otherModeStatus);
  expect(errors).toEqual([]);
});

test('a spoken interim word pops its exact target once, gives hit feedback and produces Pip report after 30 seconds', async ({ page, browserName }, info) => {
  await observeAudio(page);
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const start = Date.now();
  await page.waitForTimeout(1700);
  await page.screenshot({ path: info.outputPath('flying-words.png') });
  const word = await popOne(page, { interim: true });
  await page.screenshot({ path: info.outputPath('hit-burst.png') });
  const hits = (await state(page)).hits;
  await page.evaluate(word => window.__popSpeech.instances.at(-1).emit(word, true), word);
  await page.waitForTimeout(300);
  expect((await state(page)).hits).toBe(hits);
  await popOne(page);
  const after = await state(page);
  expect(after.score).toBeGreaterThan(0);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 35000 });
  expect(Date.now() - start).toBeGreaterThanOrEqual(29000);
  expect((await state(page)).remaining).toBe(0);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  expect(await page.evaluate(() => window.__popSpeech.spoken.at(-1))).toMatch(/Pip here.*30 seconds/);
  await visibleAction(page, /play again|replay|another round/i);
  await visibleAction(page, /pip|high.?five/i);
  await page.screenshot({ path: info.outputPath('pip-round-report.png') });
  const beforeInteraction = (await state(page)).message;
  await action(page, /pip|high.?five/i);
  await expect(page.locator('#pop-status')).toContainText(/High five! \d+ hits, \d+ words\. Ready for another round\?/);
  expect((await state(page)).message).not.toBe(beforeInteraction);
  await page.screenshot({ path: info.outputPath('pip-high-five.png') });
  const finished = await state(page);
  const audioStarts = await page.evaluate(() => window.audioObservation.starts);
  const cancelled = await page.evaluate(() => window.__popSpeech.cancelled);
  await action(page, /Hear_/);
  await expect.poll(() => page.evaluate(() => window.__popSpeech.cancelled)).toBe(cancelled + 1);
  if (await page.evaluate(() => window.audioObservation.available)) {
    await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBeGreaterThan(audioStarts);
  }
  expect((await state(page)).hits).toBe(finished.hits);
  expect((await state(page)).score).toBe(finished.score);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished');
  await action(page, /play again|replay|another round/i);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(2);
  await expectGestureStart(page, browserName);
  expect((await state(page)).hits).toBe(0);
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  expect(errors).toEqual([]);
});

test('a natural recognizer ending pauses the clock until its automatic replacement actually starts', async ({ page }) => {
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await popOne(page);
  await page.evaluate(() => {
    window.__popSpeech.automatic = false;
    window.__popSpeech.instances.at(-1).end();
  });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  const paused = await state(page);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await expect.poll(() => page.evaluate(() => window.__popSpeech.starts)).toBe(2);
  await page.waitForTimeout(650);
  expect((await state(page)).remaining).toBe(paused.remaining);
  expect((await state(page)).hits).toBe(paused.hits);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(2);
  await page.evaluate(() => window.__popSpeech.instances.at(-1).grant());
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'true');
  expect((await state(page)).hits).toBe(paused.hits);
  await popOne(page);
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  expect(errors).toEqual([]);
});

test('failed abort and stop keep a visible microphone warning and block mode exit and retry', async ({ page, browserName }, info) => {
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await popOne(page);
  await page.evaluate(() => { window.__popSpeech.instances.at(-1).failShutdown = true; });
  await chooseMode(page, 'learn');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await expect(page.locator('#speech-panel')).toBeVisible();
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-pop-stop-failed', 'true');
  await expect(page.locator('#speech-status')).toContainText(/Microphone could not be stopped\. Close this tab/);
  await expect(page.locator('#speech-panel')).toHaveCSS('position', 'fixed');
  const warning = await page.locator('#speech-panel').boundingBox();
  expect(warning.width).toBeGreaterThan(0);
  expect(warning.height).toBeGreaterThan(0);
  expect(warning.x).toBeGreaterThanOrEqual(0);
  expect(warning.x + warning.width).toBeLessThanOrEqual(page.viewportSize().width);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  const paused = await state(page);
  await action(page, /retry|listen/i);
  await page.evaluate(() => {
    const old = window.__popSpeech.instances[0];
    old.grant();
    old.emit('cat');
  });
  await page.waitForTimeout(650);
  expect((await state(page)).remaining).toBe(paused.remaining);
  expect((await state(page)).hits).toBe(paused.hits);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  expect(await page.evaluate(() => window.__popSpeech.stops)).toBeGreaterThan(0);
  expect(await page.evaluate(() => window.__popSpeech.spoken)).toEqual([]);
  await expect(page.locator('#speech-panel')).toBeVisible();
  await page.screenshot({ path: info.outputPath('microphone-stop-failed.png') });
  await page.evaluate(() => { window.__popSpeech.instances[0].failShutdown = false; });
  await action(page, /retry|listen/i);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect((await state(page)).hits).toBe(paused.hits);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(2);
  await expectGestureStart(page, browserName);
  await expect(page.locator('#speech-panel')).toBeHidden();
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-pop-stop-failed', 'false');
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  expect(errors).toEqual([]);
});

test('speech failure and More pause the round, then Resume keeps the remaining time', async ({ page }, info) => {
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await popOne(page);
  await page.evaluate(() => window.__popSpeech.instances.at(-1).fail('network'));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  const paused = await state(page);
  await page.waitForTimeout(1200);
  expect((await state(page)).remaining).toBe(paused.remaining);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await action(page, /resume|retry|listen/i);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect((await state(page)).hits).toBe(paused.hits);
  const more = headerPoint(await metrics(page));
  await tap(page, more.x, more.y);
  await expect(page.locator('#game-status')).toContainText('My rewards opened');
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await page.keyboard.press('Escape');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await action(page, /resume|retry|listen/i);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await page.screenshot({ path: info.outputPath('resumed.png') });
  expect(errors).toEqual([]);
});

for (const viewport of [{ width: 320, height: 568 }, { width: 844, height: 390 }]) {
  test(`Voice Pop fits ${viewport.width}x${viewport.height} and responds to reduced motion`, async ({ page }, info) => {
    await page.setViewportSize(viewport);
    const errors = await open(page);
    await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
    await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
    const firstTarget = (await state(page)).targets[0];
    // Follow the first throw into the middle of its flight; new throws may be crossing the arena edge.
    await expect.poll(async () => (await state(page)).remaining).toBeLessThanOrEqual(28);
    const midFlight = (await state(page)).targets.find(target => target.uid === firstTarget.uid);
    expect(midFlight, 'The first visible throw is still present during its flight').toBeTruthy();
    expectTargetInsidePlayfield(midFlight, await metrics(page));
    await page.screenshot({ path: info.outputPath('arena.png') });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect.poll(() => page.locator('#pop-aura').evaluate(element => getComputedStyle(element, '::before').animationName)).toBe('none');
    await rendered(page);
    const reduced = await state(page), bounds = await metrics(page);
    expect(reduced.targets.length).toBeGreaterThan(0);
    for (const target of reduced.targets) expectTargetInsidePlayfield(target, bounds);
    await popOne(page);
    await page.screenshot({ path: info.outputPath('reduced-motion-hit.png') });
    await chooseMode(page, 'memory');
    await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
    expect(errors).toEqual([]);
  });
}

test('unsupported speech gives an actionable explanation without starting a timer', async ({ page }, info) => {
  const errors = await open(page, { available: false });
  await expect(page.locator('#pop-status')).toContainText(/unavailable|supported browser|speech recognition/i);
  expect((await state(page)).remaining).toBe(30);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await page.screenshot({ path: info.outputPath('unsupported.png') });
  await action(page, /back|match|exit/i);
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  expect(errors).toEqual([]);
});
