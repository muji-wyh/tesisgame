const { test, expect } = require('@playwright/test');
const { enterGame, chooseMode, observeAudio, rendered } = require('./game-ui.cjs');

async function installRecognition(page, prefixed) {
  await page.addInitScript(({ prefixed }) => {
    const fixture = { instances: [], starts: 0, aborts: 0, automaticCapture: true };
    class Recognition {
      constructor() {
        this.results = [];
        this.running = false;
        this.onaudiostart = null;
        fixture.instances.push(this);
      }
      start() {
        this.running = true;
        fixture.starts++;
        this.callbacks = { start: this.onstart, audio: this.onaudiostart, result: this.onresult,
          speechStart: this.onspeechstart, speechEnd: this.onspeechend, error: this.onerror, end: this.onend };
        queueMicrotask(() => {
          this.callbacks.start?.();
          if (fixture.automaticCapture) this.capture();
        });
      }
      capture() { this.callbacks.audio?.(); }
      abort() {
        this.running = false;
        fixture.aborts++;
        const callbacks = this.callbacks;
        queueMicrotask(() => { callbacks?.error?.({ error: 'aborted' }); callbacks?.end?.(); });
      }
      stop() { this.abort(); }
      emit(text, alternatives = [], final = true) {
        this.callbacks.speechStart?.();
        const result = Object.assign([text, ...alternatives].map((transcript, index) =>
          ({ transcript, confidence: 0.95 - index * 0.15 })), { isFinal: final });
        const resultIndex = this.results.length && !this.results.at(-1).isFinal ? this.results.length - 1 : this.results.length;
        this.results[resultIndex] = result;
        this.callbacks.result?.({ resultIndex, results: this.results });
        this.callbacks.speechEnd?.();
      }
    }
    window.__speechDebugFixture = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: prefixed ? undefined : Recognition });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: prefixed ? Recognition : undefined });
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      async writeText() { throw new DOMException('Clipboard unavailable in this check', 'NotAllowedError'); }
    } });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => {
      throw new Error('Browser speech checks must not open a physical microphone');
    };
  }, { prefixed });
}

async function frozenGame(page) {
  return page.evaluate(() => {
    const state = document.getElementById('pop-status').dataset;
    return { phase: state.phase, remaining: state.remaining, hits: state.hits, score: state.score,
      round: state.roundId, leaderboard: window.wordBuddiesHost.leaderboardState() };
  });
}

async function emit(page, text, alternatives = []) {
  await page.evaluate(({ text, alternatives }) => window.__speechDebugFixture.instances.at(-1).emit(text, alternatives),
    { text, alternatives });
}

test('speech diagnostics remain absent without the explicit query flag', async ({ page, browserName }) => {
  await installRecognition(page, browserName === 'webkit');
  await page.goto('/');
  await enterGame(page);
  await expect(page.locator('#speech-debug')).toHaveCount(0);
  await expect(page.locator('#speech-debug-launch')).toHaveCount(0);
  expect(await page.evaluate(() => window.__speechDebugFixture.starts)).toBe(0);
  expect(await page.locator('#canvas').evaluate(canvas => canvas.inert)).toBe(false);
});

test('a native Pop hit acknowledges its occurrence before later recognition revisions', async ({ page, browserName }, info) => {
  await installRecognition(page, browserName === 'webkit');
  await page.goto('/');
  await enterGame(page);
  await chooseMode(page, 'pop');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  // Keep the timing-sensitive observation beside the real DOM/native bridge.
  // Protocol round trips on mobile must not consume either target's flight.
  const evidence = await page.evaluate(async () => {
    const element = document.getElementById('pop-status');
    const host = window.wordBuddiesHost;
    host.setSpeechDiagnostics(true);
    const read = () => ({ hits: Number(element.dataset.hits), round: element.dataset.roundId,
      phase: element.dataset.phase, targets: JSON.parse(element.dataset.targets || '[]') });
    const waitForState = predicate => new Promise((resolve, reject) => {
      let timer;
      const inspect = () => {
        const state = read();
        if (!predicate(state)) return;
        observer.disconnect();
        clearTimeout(timer);
        resolve(state);
      };
      const observer = new MutationObserver(inspect);
      observer.observe(element, { attributes: true });
      timer = setTimeout(() => {
        observer.disconnect();
        reject(new Error('The live Pop state did not reach its expected step: ' + JSON.stringify(read())));
      }, 10000);
      inspect();
    });
    const before = await waitForState(state => state.phase === 'running' &&
      state.targets.filter(target => target.age < 3).length >= 2);
    const [first, second] = before.targets.filter(target => target.age < 3);
    const recognition = window.__speechDebugFixture.instances.at(-1);
    const countsBefore = host.speechDiagnostics().counts;
    recognition.emit(first.text, [], false);
    const afterHit = await waitForState(state => state.hits === before.hits + 1);
    const acknowledged = host.speechDiagnostics();
    recognition.emit(second.text, [], false);
    await new Promise(resolve => setTimeout(resolve, 250));
    recognition.emit(second.text, [], true);
    await new Promise(resolve => setTimeout(resolve, 175));
    return { before, first, second, countsBefore, afterHit, acknowledged,
      afterRevision: read(), diagnostics: host.speechDiagnostics() };
  });
  expect(evidence.afterHit.hits).toBe(evidence.before.hits + 1);
  expect(evidence.acknowledged.counts.hit || 0).toBe((evidence.countsBefore.hit || 0) + 1);
  expect(evidence.acknowledged.counts.game_rejected || 0).toBe(evidence.countsBefore.game_rejected || 0);
  expect(evidence.acknowledged.records.filter(event => event.type === 'hit').map(event => event.target_uid))
    .toEqual([evidence.first.uid]);
  expect(evidence.afterRevision.hits, 'Revising the consumed occurrence cannot score another live card')
    .toBe(evidence.afterHit.hits);
  expect(evidence.afterRevision.round).toBe(evidence.before.round);
  expect(evidence.afterRevision.targets.some(target => target.uid === evidence.second.uid),
    'The revised-to target stays available for a genuinely new utterance').toBe(true);
  expect(evidence.diagnostics.counts.hit).toBe(evidence.acknowledged.counts.hit);
  expect(evidence.diagnostics.counts.game_rejected || 0).toBe(evidence.countsBefore.game_rejected || 0);
  await info.attach('native-pop-acknowledgement', { body: JSON.stringify(evidence, null, 2), contentType: 'application/json' });
});

test('the exported speech check isolates gameplay, compares sound, and exports real candidates', async ({ page, browserName }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  await installRecognition(page, browserName === 'webkit');
  await observeAudio(page);
  await page.goto('/?speechDebug=1');
  await enterGame(page);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(audioAvailable, 'Chromium must exercise actual game sounds').toBe(true);
  if (!audioAvailable) {
    // The Windows WebKit runtime omits WebAudio. Keep flow/layout assertions
    // active and report this limit rather than claiming a sound comparison.
    await expect(page.locator('#audio-status')).toContainText('Sound is not available');
    info.annotations.push({ type: 'audio-limit', description: 'This WebKit runtime has no WebAudio; sound gains are covered in native tests and actual playback in Chromium.' });
  }
  await page.evaluate(() => { window.__speechDebugFixture.automaticCapture = false; });
  await chooseMode(page, 'pop');
  await expect.poll(() => page.evaluate(() => window.__speechDebugFixture.starts)).toBe(1);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'ready');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-remaining', '50');
  expect(await page.locator('#pop-aura').getAttribute('data-listening')).toBe('false');
  await page.evaluate(() => window.__speechDebugFixture.instances.at(-1).capture());
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await expect(page.locator('#speech-debug-launch')).toBeVisible();
  await page.locator('#speech-debug-launch').click();
  const dialog = page.getByRole('dialog', { name: 'Speech check' });
  await expect(dialog).toBeVisible();
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  expect(await page.locator('#canvas').evaluate(canvas => canvas.inert)).toBe(true);
  const paused = await frozenGame(page);
  expect(await page.evaluate(() => window.__speechDebugFixture.instances.some(instance => instance.running))).toBe(false);

  // The service-start acknowledgement alone is not capture evidence. Keep the
  // practice prompt pending until the supported audio event reaches the host.
  await page.evaluate(() => { window.__speechDebugFixture.automaticCapture = false; });
  await dialog.getByRole('button', { name: 'Start listening', exact: true }).click();
  await expect(dialog.getByRole('button', { name: 'Stop listening', exact: true })).toBeEnabled();
  await expect(dialog.getByRole('status')).not.toHaveText('Listening. Say the displayed word.');
  await expect(page.locator('#speech-debug-heard')).toHaveText('No text received yet.');
  await page.evaluate(() => window.__speechDebugFixture.instances.at(-1).capture());
  await expect(dialog.getByRole('status')).toHaveText('Listening. Say the displayed word.');
  const normalSoundFrom = await page.evaluate(() => window.audioObservation.playbacks.length);
  await emit(page, 'cat', ['cap', 'bat']);
  await expect(page.locator('#speech-debug-heard')).toHaveText('cat');
  await expect(page.locator('#speech-debug-alternatives')).toHaveText('1. cat\n2. cap\n3. bat');
  await expect(dialog.getByText('Matched: cat', { exact: true })).toBeVisible();
  if (audioAvailable) await expect.poll(() => page.evaluate(() => window.audioObservation.playbacks.length),
    { message: 'Normal practice uses the actual native game sound channel' }).toBeGreaterThan(normalSoundFrom);
  await dialog.getByRole('button', { name: 'Correct', exact: true }).click();
  for (let index = 1; index < 16; index++) await dialog.getByRole('button', { name: 'No result', exact: true }).click();
  await expect(page.locator('#speech-debug-word')).toHaveText('seahorse');
  await emit(page, 'sea horse', ['seahorse']);
  await expect(dialog.getByText('Matched: seahorse', { exact: true })).toBeVisible();
  await dialog.getByRole('button', { name: 'Correct', exact: true }).click();
  await dialog.getByRole('button', { name: 'Stop listening', exact: true }).click();

  await page.evaluate(() => { window.__speechDebugFixture.automaticCapture = true; });
  await dialog.getByLabel('Game sound level').selectOption('0.35');
  await dialog.getByRole('button', { name: 'Start listening', exact: true }).click();
  await expect(dialog.getByRole('status')).toHaveText('Listening. Say the displayed word.');
  await expect(page.locator('#speech-debug-word')).toHaveText('sunflower');
  const reducedSoundFrom = await page.evaluate(() => window.audioObservation.playbacks.length);
  await emit(page, 'sun', ['sunflower']);
  await expect(page.locator('#speech-debug-alternatives')).toHaveText('1. sun\n2. sunflower');
  await expect(dialog.getByText('No match yet.', { exact: true })).toBeVisible();
  if (audioAvailable) await expect.poll(() => page.evaluate(() => window.audioObservation.playbacks.length),
    { message: 'Reduced practice keeps the actual game cues available' }).toBeGreaterThan(reducedSoundFrom);
  await dialog.getByRole('button', { name: 'Wrong', exact: true }).click();
  await dialog.getByRole('button', { name: 'Stop listening', exact: true }).click();

  await dialog.getByLabel('Game sound level').selectOption('0');
  await dialog.getByRole('button', { name: 'Start listening', exact: true }).click();
  await expect(dialog.getByRole('status')).toHaveText('Listening. Say the displayed word.');
  await expect(page.locator('#speech-debug-word')).toHaveText('sunglasses');
  const silentSoundFrom = await page.evaluate(() => window.audioObservation.playbacks.length);
  await emit(page, 'sun glasses');
  await expect(dialog.getByText('Matched: sunglasses', { exact: true })).toBeVisible();
  // Observe both the 300 ms first cue and the following scheduled cue. An
  // immediate equality check could pass before the native silent path runs.
  await page.waitForTimeout(1700);
  expect(await page.evaluate(() => window.audioObservation.playbacks.length)).toBe(silentSoundFrom);
  await dialog.getByRole('button', { name: 'Correct', exact: true }).click();
  await dialog.getByRole('button', { name: 'Stop listening', exact: true }).click();
  await dialog.getByRole('button', { name: 'Copy report', exact: true }).click();
  const exported = page.getByRole('textbox', { name: 'Diagnostic report for manual copying' });
  await expect(exported).toBeVisible();
  const report = JSON.parse(await exported.inputValue());
  expect(report.attempts).toHaveLength(19);
  expect(report.attempts.find(attempt => attempt.word === 'seahorse')).toMatchObject({ hit: true, label: 'correct', mix: 1 });
  expect(report.attempts.find(attempt => attempt.word === 'sunflower')).toMatchObject({ hit: false, label: 'wrong', mix: 0.35 });
  expect(report.attempts.find(attempt => attempt.word === 'sunglasses')).toMatchObject({ hit: true, label: 'correct', mix: 0 });
  expect(report.attempts[0].revisions[0].alternatives.map(value => value.text)).toEqual(['cat', 'cap', 'bat']);
  expect(report.attempts[0].capture_ready_at_ms).toBeGreaterThanOrEqual(report.attempts[0].requested_at_ms);
  expect(report.events.some(event => event.type === 'audiostart')).toBe(true);
  expect(report.timing_basis).toContain('not audio or word-end timestamps');
  expect(await frozenGame(page), 'Unscored practice never advances the saved round or leaderboard').toEqual(paused);
  expect(await dialog.evaluate(element => element.scrollWidth <= element.clientWidth + 1),
    'The diagnostic controls and report fit desktop and phone widths').toBe(true);
  await info.attach('speech-check-report', { body: JSON.stringify(report, null, 2), contentType: 'application/json' });
  await info.attach('audio-capability', { body: JSON.stringify({ audioAvailable, browserName }), contentType: 'application/json' });
  await page.screenshot({ path: info.outputPath('speech-check-report.png') });

  const startsBeforeClose = await page.evaluate(() => window.__speechDebugFixture.starts);
  await dialog.getByRole('button', { name: 'Close', exact: true }).click();
  await expect(dialog).toBeHidden();
  await expect(page.locator('#speech-debug-launch')).toBeVisible();
  expect(await page.locator('#canvas').evaluate(canvas => canvas.inert)).toBe(false);
  await rendered(page);
  expect(await page.evaluate(() => ({ starts: window.__speechDebugFixture.starts,
    running: window.__speechDebugFixture.instances.some(instance => instance.running) })))
    .toEqual({ starts: startsBeforeClose, running: false });
  expect(await frozenGame(page)).toEqual(paused);
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  await expect(page.locator('#game-status')).toContainText('Find 5 word–picture pairs.');
  expect(errors).toEqual([]);
});
