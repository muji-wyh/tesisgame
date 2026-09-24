const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const { chooseMode, metrics, tap, rendered, headerPoint, contentBounds, observeAudio, enterGame } = require('./game-ui.cjs');
const { assets: sliceAssets } = require('../../docs/assets/voice-pop-random-slices.json');
const catalogWords = require('../../words.json').map(word => word.text);
const assetPath = relative => path.resolve(__dirname, '../..', relative);
const expectedSlices = sliceAssets.filter(asset => fs.existsSync(assetPath(asset.destination)));
if (!expectedSlices.length) {
  // A clean source checkout uses one tracked sound; private imports are optional.
  const destination = fs.existsSync(assetPath('assets/imported-audio/pop-slice.wav'))
    ? 'assets/imported-audio/pop-slice.wav' : 'assets/audio/sfx/select.wav';
  const bytes = fs.readFileSync(assetPath(destination));
  let format, dataBytes;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const chunk = bytes.toString('ascii', offset, offset + 4), size = bytes.readUInt32LE(offset + 4);
    if (chunk === 'fmt ') format = bytes.subarray(offset + 8, offset + 8 + size);
    if (chunk === 'data') dataBytes = size;
    offset += 8 + size + (size % 2);
  }
  if (!format || !dataBytes) throw new Error(`Invalid fallback WAV: ${destination}`);
  expectedSlices.push({ destination, seconds: dataBytes / format.readUInt32LE(8), channels: format.readUInt16LE(2) });
}

function expectHitSlice(sound) {
  // Godot may resample to the output rate, so allow one output sample of rounding.
  const possibleSources = expectedSlices.filter(asset => Math.abs(asset.seconds - sound.duration) <= 1 / sound.sampleRate);
  expect(possibleSources.length, `Played ${sound.duration}s must match the imported pool or this checkout's fallback`).toBeGreaterThan(0);
  // Godot's WebAudio sample bridge uploads stereo, including mono fallback WAVs.
  expect(sound.channels).toBe(2);
  if (possibleSources.every(asset => asset.channels === 1)) {
    expect(sound.channelFingerprints, 'The mono fallback must be duplicated into both output channels').toHaveLength(2);
    expect(sound.channelFingerprints[0]).toBe(sound.channelFingerprints[1]);
  }
  expect(sound.loop, 'A slice is a single hit, never a music loop').toBe(false);
  expect(sound.playbackRate).toBe(1);
  expect(sound.contextState, 'The real WebAudio context must be running at playback').toBe('running');
  expect(sound.fingerprint).toBeTruthy();
  expect(sound.peak, 'The selected slice has audible PCM samples').toBeGreaterThan(0.05);
}

async function installSpeech(page, { automatic = true, available = true, phraseHints = false } = {}) {
  // These recognition fixtures exercise solo mode without downloading local models.
  await page.route('**/multiplayer/manifest.json', route => route.abort());
  await page.addInitScript(({ automatic, available, phraseHints }) => {
    const fixture = { starts: 0, aborts: 0, stops: 0, instances: [], spoken: [], utterances: [], cancelled: 0, automatic };
    class Recognition {
      constructor() { this.results = []; fixture.instances.push(this); }
      start() {
        fixture.starts++;
        this.phrasesAtStart = Array.from(this.phrases || [], value => ({ phrase: value.phrase, boost: value.boost }));
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
    if (phraseHints) {
      Recognition.prototype.phrases = [];
      Object.defineProperty(window, 'SpeechRecognitionPhrase', { configurable: true, value: class {
        constructor(phrase, boost) { this.phrase = phrase; this.boost = boost; }
      } });
    }
    window.__popSpeech = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: available ? Recognition : undefined });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    Object.defineProperty(window, 'SpeechSynthesisUtterance', { configurable: true, value: class { constructor(text) { this.text = text; } } });
    Object.defineProperty(window, 'speechSynthesis', { configurable: true, value: {
      speak(utterance) {
        fixture.spoken.push(utterance.text);
        fixture.utterances.push(utterance);
        queueMicrotask(() => utterance.onstart?.());
      }, cancel() { fixture.cancelled++; }
    } });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => { throw new Error('Test must not capture a physical microphone'); };
  }, { automatic, available, phraseHints });
}

async function open(page, options) {
  await installSpeech(page, options);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  await page.goto('/');
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(0);
  await enterGame(page);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(0);
  await chooseMode(page, 'pop');
  return errors;
}

async function state(page) {
  return page.locator('#pop-status').evaluate(element => ({
    phase: element.dataset.phase, remaining: Number(element.dataset.remaining),
    hits: Number(element.dataset.hits), score: Number(element.dataset.score),
    bestCombo: Number(element.dataset.bestCombo), transcript: element.dataset.transcript || '',
    recognitionFeedback: element.dataset.recognitionFeedback || '', recognitionMessage: element.dataset.recognitionMessage || '',
    transcriptFinal: element.dataset.transcriptFinal === 'true', report: element.dataset.report || '',
    reportStep: Number(element.dataset.reportStep), resultsScroll: Number(element.dataset.resultsScroll),
    reportSpeaking: element.dataset.reportSpeaking === 'true', reportLoading: element.dataset.reportLoading === 'true',
    reportAudio: JSON.parse(element.dataset.reportAudio || '[]'),
    resultsScrollMax: Number(element.dataset.resultsScrollMax), resultsScrollbarVisible: element.dataset.resultsScrollbarVisible === 'true',
    targets: JSON.parse(element.dataset.targets || '[]'), controls: JSON.parse(element.dataset.controls || '[]'),
    message: element.textContent
  }));
}

async function expectReportDelivery(page) {
  const available = await page.evaluate(() => window.audioObservation.available);
  if (available) {
    await expect.poll(async () => (await state(page)).reportSpeaking).toBe(true);
  } else {
    await expect.poll(async () => (await state(page)).controls.find(control => control.name === 'HearPip')?.text).toBe('Try Pip again');
    expect((await state(page)).reportSpeaking).toBe(false);
    expect((await state(page)).reportLoading).toBe(false);
    expect((await state(page)).report.length).toBeGreaterThan(0);
  }
  return available;
}

async function visibleAction(page, pattern) {
  let button, previous = '';
  await expect.poll(async () => {
    await rendered(page);
    const bounds = await metrics(page), current = await state(page);
    button = current.controls.find(control => !control.disabled && control.width > 1 && control.height > 1 &&
      control.x >= -1 && control.y >= -1 && control.x + control.width <= bounds.width + 1 &&
      control.y + control.height <= bounds.height + 1 && pattern.test(control.name + ' ' + control.text));
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

async function scrollResults(page, delta) {
  const before = await state(page);
  const bounds = await metrics(page), content = contentBounds(bounds);
  const x = bounds.x + (content.x + content.width / 2) * bounds.scale;
  // The multiplayer status strip sits above the result scroller. Start inside
  // a visible result control's vertical band so touch drags reach that scroller.
  const firstResult = before.controls.filter(control =>
    /^(Pip|HearPip|NextReport|Replay|Back|Hear_)/.test(control.name))
    .sort((a, b) => a.y - b.y)[0];
  const top = bounds.y + (firstResult ? firstResult.y + Math.min(firstResult.height / 2, 10) : content.top) * bounds.scale + 10;
  const bottom = bounds.y + (bounds.height - content.padding) * bounds.scale - 30;
  if (page.context().browser().browserType().name() === 'chromium') {
    await page.mouse.move(x, (top + bottom) / 2);
    await page.mouse.wheel(0, delta);
  } else {
    // Mobile WebKit has no wheel API; dispatch a complete touch gesture to the canvas.
    // Its mouse API does not produce the touch input consumed by ScrollContainer.
    const distance = Math.min(Math.abs(delta), bottom - top);
    const swipes = Math.abs(delta) >= 10000 ? 8 : 1;
    for (let swipe = 0; swipe < swipes; swipe++) {
      const current = await state(page);
      if (delta < 0 ? current.resultsScroll === 0 : current.resultsScroll >= current.resultsScrollMax) break;
      const start = delta < 0 ? top : bottom;
      const end = start - Math.sign(delta) * distance;
      const dispatch = (type, y) => page.evaluate(({ type, x, y }) => {
        const canvas = document.querySelector('#canvas');
        const touch = typeof document.createTouch === 'function'
          ? document.createTouch(window, canvas, 1, x + scrollX, y + scrollY, x, y)
          : new Touch({ identifier: 1, target: canvas, clientX: x, clientY: y,
          pageX: x + scrollX, pageY: y + scrollY, screenX: x, screenY: y,
          radiusX: 1, radiusY: 1, rotationAngle: 0, force: type === 'touchend' ? 0 : 1 });
        // This WebKit build requires TouchList values; modern engines accept arrays.
        const list = items => typeof document.createTouchList === 'function' ? document.createTouchList(...items) : items;
        const touches = list(type === 'touchend' ? [] : [touch]);
        canvas.dispatchEvent(new TouchEvent(type, { bubbles: true, cancelable: true, composed: true,
          touches, targetTouches: touches, changedTouches: list([touch]) }));
      }, { type, x, y });
      let firstMoveScroll, lastMoveScroll;
      await dispatch('touchstart', start);
      try {
        await rendered(page);
        for (let step = 1; step <= 8; step++) {
          await dispatch('touchmove', start + (end - start) * step / 8);
          await rendered(page);
          if (step === 1) firstMoveScroll = (await state(page)).resultsScroll;
          if (step === 8) lastMoveScroll = (await state(page)).resultsScroll;
        }
      } finally {
        await dispatch('touchend', end);
      }
      await rendered(page);
      // Focusing a partly clipped button can nudge the scroll on touch-down.
      // The remaining moves must keep scrolling; a focus-only nudge is not a swipe.
      if (delta > 0 && firstMoveScroll < current.resultsScrollMax - 1) {
        expect(lastMoveScroll, 'Dragging from a result button continues beyond its initial focus adjustment').toBeGreaterThan(firstMoveScroll);
      } else if (delta < 0 && firstMoveScroll > 0) {
        expect(lastMoveScroll, 'A downward swipe keeps moving the result list toward its top').toBeLessThan(firstMoveScroll);
      }
    }
  }
  await rendered(page);
  if (delta < 0 && before.resultsScroll > 0) {
    await expect.poll(async () => (await state(page)).resultsScroll).toBeLessThan(before.resultsScroll);
  } else if (delta > 0 && before.resultsScroll < before.resultsScrollMax) {
    await expect.poll(async () => (await state(page)).resultsScroll).toBeGreaterThan(before.resultsScroll);
  }
}

async function resultAction(page, pattern) {
  await scrollResults(page, -10000);
  await expect.poll(async () => (await state(page)).resultsScroll).toBe(0);
  for (let attempt = 0; attempt < 8; attempt++) {
    if ((await state(page)).controls.some(control => !control.disabled && pattern.test(control.name + ' ' + control.text))) {
      await action(page, pattern);
      return;
    }
    await scrollResults(page, 180);
  }
  throw new Error(`No reachable result action matching ${pattern}`);
}

async function expectGestureStart(page, browserName) {
  if (browserName === 'chromium') {
    expect(await page.evaluate(() => window.__popSpeech.instances.at(-1).activationAtStart),
      'The Godot entry or retry gesture must still be active at SpeechRecognition.start').toBe(true);
  }
}

async function expectListeningAura(page) {
  const aura = page.locator('#pop-aura');
  await expect(aura).toHaveAttribute('data-listening', 'true');
  await expect(aura).toHaveCSS('opacity', '1');
  await expect(aura).toHaveCSS('visibility', 'visible');
  await expect(aura).toHaveCSS('pointer-events', 'none');
  const bounds = await aura.boundingBox(), viewport = page.viewportSize();
  expect(bounds, 'The listening glow follows the full viewport perimeter').toEqual({
    x: 0, y: 0, width: viewport.width, height: viewport.height
  });
  expect(await aura.evaluate(element => {
    const points = [[1, 1], [innerWidth - 2, 1], [1, innerHeight - 2], [innerWidth - 2, innerHeight - 2],
      [innerWidth / 2, 1], [innerWidth / 2, innerHeight - 2], [1, innerHeight / 2], [innerWidth - 2, innerHeight / 2]];
    return points.every(([x, y]) => !element.contains(document.elementFromPoint(x, y)));
  }), 'The decorative edge never steals input from the game').toBe(true);
}

async function expectStillAura(page) {
  await expect.poll(() => page.locator('#pop-aura').evaluate(element => {
    const layers = [element, ...element.querySelectorAll('*')];
    return layers.every(layer => [null, '::before', '::after'].every(pseudo =>
      getComputedStyle(layer, pseudo).animationName.split(',').every(name => name.trim() === 'none')));
  }), { message: 'Reduced motion stops every listening-glow layer' }).toBe(true);
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

test('Solo receives the complete round vocabulary before recognition starts and keeps unmatched speech readable', async ({ page }) => {
  const errors = await open(page, { phraseHints: true });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const hints = await page.evaluate(() => window.__popSpeech.instances.at(-1).phrasesAtStart);
  expect(hints.map(value => value.phrase).sort()).toEqual([...catalogWords].sort());
  expect(hints.every(value => value.boost > 0 && value.boost <= 3)).toBe(true);
  expect(hints.length).toBeGreaterThan((await state(page)).targets.length);
  const before = await state(page);
  await page.evaluate(() => window.__popSpeech.instances.at(-1).emit('hello everybody'));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', 'hello everybody');
  expect((await state(page)).hits).toBe(before.hits);
  await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
  const target = (await state(page)).targets[0];
  const sentence = `${target.text} please`;
  await page.evaluate(text => window.__popSpeech.instances.at(-1).emit(text), sentence);
  await expect.poll(async () => (await state(page)).hits).toBe(before.hits + 1);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', sentence);
  expect((await state(page)).recognitionFeedback).toBe('');
  expect((await state(page)).recognitionMessage).toBe('');
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  expect(errors).toEqual([]);
});

test('the live HUD shows and revises the whole interim sentence while scoring only the spoken target', async ({ page }, info) => {
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const first = 'I am still thinking';
  const before = await state(page);
  await page.evaluate(text => window.__popSpeech.instances.at(-1).emit(text, false), first);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', first);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript-final', 'false');
  expect((await state(page)).hits).toBe(before.hits);
  await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
  const word = (await state(page)).targets[0].text;
  const sentence = `I think it is a ${word}`;
  await page.evaluate(text => window.__popSpeech.instances.at(-1).emit(text, false), sentence);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', sentence);
  await expect.poll(async () => (await state(page)).hits).toBe(before.hits + 1);
  const revised = `I think it is the ${word}, please`;
  await page.evaluate(text => window.__popSpeech.instances.at(-1).emit(text, false), revised);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', revised);
  expect((await state(page)).hits).toBe(before.hits + 1);
  await page.screenshot({ path: info.outputPath('live-interim-sentence.png') });
  await page.evaluate(text => window.__popSpeech.instances.at(-1).emit(text, true), revised);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', revised);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript-final', 'true');
  expect((await state(page)).hits).toBe(before.hits + 1);
  await page.evaluate(() => window.__popSpeech.instances.at(-1).fail('network'));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', '');
  await page.evaluate(() => window.__popSpeech.instances[0].emit('a late stale sentence', false));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', '');
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', '');
  expect(errors).toEqual([]);
});

test('Voice Pop requests permission on entry, waits, recovers from denial, and releases on mode exit', async ({ page, browserName }, info) => {
  const errors = await open(page, { automatic: false });
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  await expectGestureStart(page, browserName);
  await page.waitForTimeout(1300);
  expect((await state(page)).remaining).toBe(30);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await expect(page.locator('#pop-aura')).toHaveCSS('visibility', 'hidden');
  await page.evaluate(() => window.__popSpeech.instances.at(-1).fail('not-allowed'));
  await expect(page.locator('#pop-status')).toContainText(/permission|allow/i);
  await expect(page.locator('#pop-aura')).toHaveCSS('visibility', 'hidden');
  await page.screenshot({ path: info.outputPath('permission-denied.png') });
  await page.evaluate(() => { window.__popSpeech.automatic = true; });
  await action(page, /^RetryListening /);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(2);
  await expectGestureStart(page, browserName);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'true');
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  await expect(page.locator('#pop-status')).toBeEmpty();
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await expect(page.locator('#pop-aura')).toHaveCSS('visibility', 'hidden');
  expect(await page.evaluate(() => window.__popSpeech.aborts)).toBeGreaterThan(0);
  expect(errors).toEqual([]);
});

test('leaving while permission is pending rejects a late grant and every callback from that recognizer', async ({ page }) => {
  const errors = await open(page, { automatic: false });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'ready');
  expect((await state(page)).remaining).toBe(30);
  await chooseMode(page, 'match');
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
  // Includes a real 30-second round, recorded report playback and several full
  // touch swipes. Keep each response deadline strict while allowing the workflow.
  test.setTimeout(150000);
  await observeAudio(page, { fingerprintBuffers: true, phaseSelector: '#pop-status' });
  const errors = await open(page);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(audioAvailable, 'Chromium must exercise real recorded audio').toBe(true);
  await info.attach('native-audio-capability.json', { body: JSON.stringify({ audioAvailable }), contentType: 'application/json' });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const start = Date.now();
  await page.waitForTimeout(1700);
  await page.screenshot({ path: info.outputPath('flying-words.png') });
  const runningSounds = () => page.evaluate(() => window.audioObservation.playbacks.filter(sound => sound.phase === 'running'));
  const runningSoundCount = async () => (await runningSounds()).length;
  expect(await runningSounds(), 'Listening starts quietly, with no prompt or background music').toEqual([]);
  const word = await popOne(page, { interim: true });
  if (audioAvailable) {
    await expect.poll(runningSoundCount, { message: 'A spoken hit immediately plays exactly one fruit slice.' }).toBe(1);
    expectHitSlice((await runningSounds())[0]);
  }
  await page.screenshot({ path: info.outputPath('hit-burst.png') });
  const hits = (await state(page)).hits;
  await page.evaluate(word => window.__popSpeech.instances.at(-1).emit(word, true), word);
  await page.waitForTimeout(300);
  expect((await state(page)).hits).toBe(hits);
  if (audioAvailable) expect(await runningSoundCount(), 'Finalizing the same recognition cannot replay the slice.').toBe(1);
  const secondWord = await popOne(page);
  if (audioAvailable) {
    await expect.poll(runningSoundCount).toBe(2);
    const slices = await runningSounds();
    slices.forEach(expectHitSlice);
    if (expectedSlices.length > 1) {
      expect(slices[1].fingerprint, 'Consecutive spoken hits play different PCM audio, including equal-duration fruit variants').not.toBe(slices[0].fingerprint);
    } else {
      expect(slices[1].fingerprint, 'A checkout with one hit sound can reuse its only clip').toBe(slices[0].fingerprint);
    }
  }
  const after = await state(page);
  expect(after.score).toBeGreaterThan(0);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 35000 });
  expect(await runningSoundCount(), 'The entire listening round contains only its two hit sounds, with no prompts or BGM').toBe(audioAvailable ? 2 : 0);
  expect(await page.evaluate(() => window.__popSpeech.spoken), 'Listening never triggers system speech prompts').toEqual([]);
  await info.attach('hit-audio-durations.json', { body: JSON.stringify({ expectedSources: expectedSlices, playbacks: await runningSounds() }), contentType: 'application/json' });
  expect(Date.now() - start).toBeGreaterThanOrEqual(29000);
  expect((await state(page)).remaining).toBe(0);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  const round = await state(page);
  expect(round.reportStep).toBe(0);
  expect(round.report).toContain('30');
  expect(round.report).toMatch(new RegExp(`\\b${round.hits}\\b`));
  expect(round.resultsScrollbarVisible).toBe(false);
  expect(round.transcript).toBe('');
  expect(round.reportAudio).toEqual([`res://assets/audio/pop/round-${round.hits}.wav`]);
  await expectReportDelivery(page);
  expect(await page.evaluate(() => window.__popSpeech.spoken)).toEqual([]);
  await page.screenshot({ path: info.outputPath('pip-round-report.png') });
  const audioBeforeReplay = await page.evaluate(() => window.audioObservation.starts);
  await resultAction(page, /HearPip/);
  if (await page.evaluate(() => window.audioObservation.available)) {
    await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBeGreaterThan(audioBeforeReplay);
  }
  if (audioAvailable) {
    await expect.poll(async () => (await state(page)).controls.find(control => control.name === 'HearPip')?.text).toBe('Hear again');
    await expect.poll(async () => (await state(page)).reportSpeaking, { timeout: 15000 }).toBe(false);
    expect((await state(page)).controls.find(control => control.name === 'HearPip')?.text).toBe('Hear Pip');
  } else await expectReportDelivery(page);
  expect((await state(page)).report).toBe(round.report);
  await resultAction(page, /NextReport/);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-report-step', '1');
  const highlights = await state(page);
  expect(highlights.report.toLowerCase()).toContain(word.toLowerCase());
  expect(highlights.report.toLowerCase()).toContain(secondWord.toLowerCase());
  expect(highlights.report).toMatch(new RegExp(`\\b${round.bestCombo}\\b`));
  expect(highlights.reportAudio[0]).toBe('res://assets/audio/pop/highlights-two.wav');
  expect(highlights.reportAudio).toContain(`res://assets/audio/voice/word-${word.toLowerCase()}.wav`);
  expect(highlights.reportAudio).toContain(`res://assets/audio/voice/word-${secondWord.toLowerCase()}.wav`);
  expect(highlights.reportAudio.at(-1)).toBe(`res://assets/audio/pop/combo-${round.bestCombo}.wav`);
  await expectReportDelivery(page);
  await resultAction(page, /NextReport/);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-report-step', '2');
  const coaching = await state(page);
  expect(coaching.report).not.toBe(round.report);
  expect(coaching.report).not.toBe(highlights.report);
  expect(coaching.report).toMatch(/say|practi[cs]e|try|next/i);
  expect(coaching.reportAudio).toHaveLength(3);
  expect(coaching.reportAudio[0]).toMatch(/\/(?:practice|repeat)\.wav$/);
  expect(coaching.reportAudio[1]).toMatch(/\/voice\/word-[a-z-]+\.wav$/);
  await expectReportDelivery(page);
  await resultAction(page, /NextReport/);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-report-step', '0');
  expect((await state(page)).report).toBe(round.report);
  const beforeInteraction = (await state(page)).message;
  await resultAction(page, /^Pip(?:\s|$)|high.?five/i);
  await expect(page.locator('#pop-status')).toContainText(/High five/i);
  expect((await state(page)).message).not.toBe(beforeInteraction);
  expect((await state(page)).report).toContain(round.report);
  expect((await state(page)).reportAudio[0]).toBe('res://assets/audio/pop/high-five.wav');
  await expectReportDelivery(page);
  await page.screenshot({ path: info.outputPath('pip-high-five.png') });
  const finished = await state(page);
  expect(finished.hits).toBe(round.hits);
  expect(finished.score).toBe(round.score);
  expect(finished.bestCombo).toBe(round.bestCombo);
  if (finished.resultsScrollMax > 0) {
    await scrollResults(page, -10000);
    await expect.poll(async () => (await state(page)).resultsScroll).toBe(0);
    await scrollResults(page, 300);
    await expect.poll(async () => (await state(page)).resultsScroll).toBeGreaterThan(0);
    expect((await state(page)).resultsScrollbarVisible).toBe(false);
    await page.screenshot({ path: info.outputPath('results-scroll-without-bar.png') });
  }
  const audioStarts = await page.evaluate(() => window.audioObservation.starts);
  await resultAction(page, /Hear_/);
  await expect.poll(async () => (await state(page)).reportSpeaking).toBe(false);
  expect((await state(page)).reportLoading).toBe(false);
  if (await page.evaluate(() => window.audioObservation.available)) {
    await expect.poll(() => page.evaluate(() => window.audioObservation.starts)).toBeGreaterThan(audioStarts);
  }
  expect((await state(page)).hits).toBe(finished.hits);
  expect((await state(page)).score).toBe(finished.score);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished');
  await resultAction(page, /play again|replay|another round/i);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(2);
  await expectGestureStart(page, browserName);
  expect((await state(page)).hits).toBe(0);
  expect((await state(page)).reportSpeaking).toBe(false);
  expect((await state(page)).reportLoading).toBe(false);
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  expect(await page.evaluate(() => window.__popSpeech.spoken)).toEqual([]);
  expect(errors).toEqual([]);
});

test('unavailable report audio stays readable and retries with the natural voice instead of system TTS', async ({ page, browserName }, info) => {
  await observeAudio(page);
  const errors = await open(page);
  if (browserName === 'chromium') expect(await page.evaluate(() => window.audioObservation.available)).toBe(true);
  await page.route('**/audio-*.sample', route => route.fulfill({ status: 404, body: '' }));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 35000 });
  await expect.poll(async () => (await state(page)).controls.find(control => control.name === 'HearPip')?.text).toBe('Try Pip again');
  const report = await state(page);
  expect(report.hits).toBe(0);
  expect(report.score).toBe(0);
  expect(report.report).toContain('0 words');
  expect(report.report).toContain('practise');
  expect(report.reportSpeaking).toBe(false);
  expect(report.reportLoading).toBe(false);
  expect(await page.evaluate(() => window.__popSpeech.spoken)).toEqual([]);
  await page.screenshot({ path: info.outputPath('readable-report-audio-unavailable.png') });
  await page.unroute('**/audio-*.sample');
  const starts = await page.evaluate(() => window.audioObservation.starts);
  await resultAction(page, /HearPip/);
  await expectReportDelivery(page);
  if (await page.evaluate(() => window.audioObservation.available)) {
    expect(await page.evaluate(() => window.audioObservation.starts)).toBeGreaterThan(starts);
  }
  expect((await state(page)).report).toBe(report.report);
  await page.screenshot({ path: info.outputPath('natural-voice-retry.png') });
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-report-speaking', 'false');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-report-loading', 'false');
  expect(await page.evaluate(() => window.__popSpeech.spoken)).toEqual([]);
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
  await chooseMode(page, 'match');
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
  await action(page, /^RetryListening /);
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
  await action(page, /^RetryListening /);
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
  await action(page, /^RetryListening /);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect((await state(page)).hits).toBe(paused.hits);
  const more = headerPoint(await metrics(page));
  await tap(page, more.x, more.y);
  await expect(page.locator('#game-status')).toContainText("Pip's room opened");
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await page.keyboard.press('Escape');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await action(page, /^RetryListening /);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await page.screenshot({ path: info.outputPath('resumed.png') });
  expect(errors).toEqual([]);
});

for (const viewport of [{ width: 320, height: 568 }, { width: 844, height: 390 }]) {
  test(`Voice Pop fits ${viewport.width}x${viewport.height} and responds to reduced motion`, async ({ page }, info) => {
    await page.setViewportSize(viewport);
    const errors = await open(page);
    await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
    await expectListeningAura(page);
    await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
    const firstTarget = (await state(page)).targets[0];
    // Follow the first throw into the middle of its flight; new throws may be crossing the arena edge.
    await expect.poll(async () => (await state(page)).remaining).toBeLessThanOrEqual(28);
    const midFlight = (await state(page)).targets.find(target => target.uid === firstTarget.uid);
    expect(midFlight, 'The first visible throw is still present during its flight').toBeTruthy();
    expectTargetInsidePlayfield(midFlight, await metrics(page));
    await page.screenshot({ path: info.outputPath('arena.png') });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expectStillAura(page);
    await expectListeningAura(page);
    await rendered(page);
    const reduced = await state(page), bounds = await metrics(page);
    expect(reduced.targets.length).toBeGreaterThan(0);
    for (const target of reduced.targets) expectTargetInsidePlayfield(target, bounds);
    await popOne(page);
    await page.screenshot({ path: info.outputPath('reduced-motion-hit.png') });
    await chooseMode(page, 'memory');
    await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
    await expect(page.locator('#pop-aura')).toHaveCSS('opacity', '0');
    await expect(page.locator('#pop-aura')).toHaveCSS('visibility', 'hidden');
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
