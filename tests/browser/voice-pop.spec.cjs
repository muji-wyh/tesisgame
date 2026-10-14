const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const { chooseMode, openModeMenu, metrics, tap, rendered, headerPoint, contentBounds, observeAudio, enterGame, boardPoint, memoryPoint } = require('./game-ui.cjs');
const { watchAudioRequests, observeOutputAudio, expectOutputEnergy, recordingTiming } = require('./bundled-audio.cjs');
const { roomState } = require('./pop-treasure-ui.cjs');
const { assets: sliceAssets } = require('../../docs/assets/voice-pop-random-slices.json');
const { assets: referenceAssets } = require('../../docs/assets/voice-pop-reference-audio.json');
const catalog = require('../../words.json').filter(word => word.min_age <= 3 && word.image && (word.practice_modes || ['pop']).includes('pop'));
const bundledAudioTest = test.extend({
  // Require the game's real tap gestures to unlock audio in these focused tests.
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] }
});
const assetPath = relative => path.resolve(__dirname, '../..', relative);
const referenceSlices = referenceAssets.filter(asset => asset.id !== 'launch');
const referenceAvailable = referenceSlices.length > 0 && referenceSlices.every(asset => fs.existsSync(assetPath(asset.destination)));
const expectedSlices = (referenceAvailable ? referenceSlices : sliceAssets)
  .filter(asset => fs.existsSync(assetPath(asset.destination)));
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

function waveDuration(relative) {
  const bytes = fs.readFileSync(assetPath(relative));
  let bytesPerSecond, dataBytes;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const chunk = bytes.toString('ascii', offset, offset + 4), size = bytes.readUInt32LE(offset + 4);
    if (chunk === 'fmt ') bytesPerSecond = bytes.readUInt32LE(offset + 16);
    if (chunk === 'data') dataBytes = size;
    offset += 8 + size + (size % 2);
  }
  if (!bytesPerSecond || !dataBytes) throw new Error(`Invalid WAV: ${relative}`);
  return dataBytes / bytesPerSecond;
}

const launchDestination = fs.existsSync(assetPath('assets/imported-audio/pop-reference/launch.wav'))
  ? 'assets/imported-audio/pop-reference/launch.wav' : 'assets/audio/sfx/pop-launch.wav';
const expectedLaunch = { destination: launchDestination, seconds: waveDuration(launchDestination) };

function isLaunch(sound) {
  return sound.playbackRate === 1 && Math.abs(sound.duration - expectedLaunch.seconds) <= 1 / sound.sampleRate;
}

function expectLaunch(sound) {
  expect(isLaunch(sound), 'A fresh target uses the bundled launch whoosh').toBe(true);
  expect(sound.duration, 'The launch is a short cue, not a sustained listening sound').toBeLessThanOrEqual(0.3);
  expect(sound.channels).toBe(2);
  expect(sound.loop).toBe(false);
  expect(sound.contextState).toBe('running');
  expect(sound.fingerprint).toBeTruthy();
  expect(sound.peak, 'The launch recording contains audible PCM').toBeGreaterThan(0.01);
}

const pipRecordings = require('../../docs/assets/pip-sounds.json').assets.map(asset => recordingTiming(asset.file));
const isPipCall = sound => pipRecordings.some(timing =>
  Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate);

function isHitSlice(sound) {
  return sound.playbackRate === 1 && expectedSlices.some(asset => Math.abs(asset.seconds - sound.duration) <= 1 / sound.sampleRate);
}

function expectResultSaveCue(sounds) {
  expect(sounds, 'A zero-chest result remains quiet without profile-score submission').toEqual([]);
}

function expectSilentPipRound(sounds, hits, fragmentCount) {
  const launches = sounds.filter(isLaunch), slices = sounds.filter(isHitSlice);
  const fragmentCues = ['appear', 'arrive'].flatMap(cue => {
    const timing = recordingTiming(`assets/audio/fragments/${cue}.wav`);
    const matching = sounds.filter(sound => Math.abs(sound.duration - timing.seconds) <=
      timing.importAllowance + 1 / sound.sampleRate);
    expect(matching, `Each earned fragment has its own ${cue} recording`).toHaveLength(fragmentCount);
    return matching;
  });
  expect(slices, 'Only accepted hits play slice sounds.').toHaveLength(hits);
  slices.forEach(expectHitSlice);
  expect(sounds.filter(isPipCall), 'Successful hits and falling targets never play a Pip recording.').toEqual([]);
  expect(launches.length, 'Fresh targets retain launch cues throughout the complete round.').toBeGreaterThan(hits);
  launches.forEach(expectLaunch);
  expect(fragmentCues, 'Each earned fragment sounds on appearance and arrival.').toHaveLength(fragmentCount * 2);
  for (const sound of fragmentCues) {
    expect(sound.fingerprint).toBeTruthy();
    expect(sound.peak).toBeGreaterThan(0.01);
    expect(sound.playbackRate).toBe(1);
    expect(sound.contextState).toBe('running');
  }
  expect(sounds.length, 'Live gameplay contains only launches, hit slices and earned fragment cues, with no Pip vocal calls, prompts or BGM.')
    .toBe(hits + launches.length + fragmentCues.length);
}

async function installSpeech(page, { automatic = true, available = true, phraseHints = false,
  localSupport = false, localAvailability = 'downloadable', installedAvailability = 'available' } = {}) {
  // Exercise the browser recognition lifecycle without opening a physical microphone.
  await page.addInitScript(({ automatic, available, phraseHints, localSupport, localAvailability, installedAvailability }) => {
    const fixture = { starts: 0, aborts: 0, stops: 0, instances: [], spoken: [], automatic,
      preparationCalls: [], localAvailability };
    class Recognition {
      constructor() { this.results = []; fixture.instances.push(this); }
      start() {
        fixture.starts++;
        this.phrasesAtStart = Array.from(this.phrases || [], value => ({ phrase: value.phrase, boost: value.boost }));
        this.localAtStart = this.processLocally === true;
        this.alternativesAtStart = this.maxAlternatives;
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
      emit(transcript, isFinal = true, alternatives = []) {
        const result = Object.assign([{ transcript, confidence: 0.95 }, ...alternatives.map((text, index) =>
          ({ transcript: text, confidence: Math.max(0, 0.85 - index * 0.1) }))], { isFinal });
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
    if (localSupport) {
      Recognition.prototype.processLocally = false;
      Recognition.available = async options => {
        fixture.preparationCalls.push({ method: 'available', options });
        return fixture.localAvailability;
      };
      Recognition.install = async options => {
        fixture.preparationCalls.push({ method: 'install', options, activation: navigator.userActivation?.isActive ?? null });
        fixture.localAvailability = installedAvailability;
        return true;
      };
    }
    window.__popSpeech = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: available ? Recognition : undefined });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    Object.defineProperty(window, 'SpeechSynthesisUtterance', { configurable: true, value: class { constructor(text) { this.text = text; } } });
    Object.defineProperty(window, 'speechSynthesis', { configurable: true, value: {
      speak(utterance) {
        fixture.spoken.push(utterance.text);
        queueMicrotask(() => utterance.onstart?.());
      }, cancel() {}
    } });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => { throw new Error('Test must not capture a physical microphone'); };
  }, { automatic, available, phraseHints, localSupport, localAvailability, installedAvailability });
}

async function open(page, { url = '/', ...speechOptions } = {}) {
  await installSpeech(page, speechOptions);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  await page.goto(url);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(0);
  await enterGame(page);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(0);
  await chooseMode(page, 'pop');
  return errors;
}

async function state(page) {
  return page.locator('#pop-status').evaluate(element => ({
    sampledAt: performance.now(),
    phase: element.dataset.phase, remaining: Number(element.dataset.remaining),
    combo: Number(element.dataset.combo), bonusTime: Number(element.dataset.bonusTime),
    hits: Number(element.dataset.hits), score: Number(element.dataset.score), chestCount: Number(element.dataset.chestCount),
    fragmentCount: Number(element.dataset.fragmentCount), chestTier: Number(element.dataset.chestTier),
    bestCombo: Number(element.dataset.bestCombo), transcript: element.dataset.transcript || '',
    recognitionFeedback: element.dataset.recognitionFeedback || '', recognitionMessage: element.dataset.recognitionMessage || '',
    transcriptFinal: element.dataset.transcriptFinal === 'true', boardFrozen: element.dataset.boardFrozen === 'true',
    targets: JSON.parse(element.dataset.targets || '[]'), controls: JSON.parse(element.dataset.controls || '[]'),
    hud: JSON.parse(element.dataset.hud || '{}'),
    message: element.textContent
  }));
}


function expectRewardRect(rect, parent, message) {
  expect(rect, message).toHaveLength(4);
  expect(rect.every(Number.isFinite), message).toBe(true);
  expect(rect[2], message).toBeGreaterThan(0);
  expect(rect[3], message).toBeGreaterThan(0);
  if (!parent) return;
  expect(rect[0], message).toBeGreaterThanOrEqual(parent[0] - 1);
  expect(rect[1], message).toBeGreaterThanOrEqual(parent[1] - 1);
  expect(rect[0] + rect[2], message).toBeLessThanOrEqual(parent[0] + parent[2] + 1);
  expect(rect[1] + rect[3], message).toBeLessThanOrEqual(parent[1] + parent[3] + 1);
}


async function expectSettlement(page, expected = {}) {
  await expect.poll(async () => (await roomState(page)).game_over?.visible).toBe(true);
  const current = await state(page), room = await roomState(page), bounds = await metrics(page);
  expect(current.phase).toBe('finished');
  expect(current.boardFrozen, 'The completed game remains behind the dialog').toBe(true);
  expect(current.controls, 'The retired result page has no interactive controls').toEqual([]);
  expect(current.transcript).toBe('');
  expect(room.visible).toBe(true);
  expect(room.result_context).toMatchObject({ hits: current.hits, score: current.score,
    chest_count: current.chestCount, chest_tier: current.chestTier, ...expected });
  expect(room.score_text).toBe(String(current.score));
  expect(room.progress_text).toContain(`${current.hits} ${current.hits === 1 ? 'word popped' : 'words popped'}`);
  expectRewardRect(room.game_over.panel_rect, [0, 0, bounds.width, bounds.height], 'Settlement fits the viewport');
  for (const text of ['Home', 'Play again']) {
    const action = room.actions.find(action => action.visible && action.text === text);
    expect(action, `${text} remains reachable in settlement`).toBeTruthy();
    expectRewardRect(action.rect, room.game_over.panel_rect, `${text} fits the dialog`);
  }
  return room;
}

async function settlementAction(page, text) {
  const room = await expectSettlement(page);
  const action = room.actions.find(action => action.visible && !action.disabled && action.text === text);
  expect(action, `Settlement has an enabled ${text} action`).toBeTruthy();
  await tap(page, action.rect[0] + action.rect[2] / 2, action.rect[1] + action.rect[3] / 2);
  await rendered(page);
}

async function replaySettlement(page) {
  await settlementAction(page, 'Play again');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'ready');
  expect((await state(page)).boardFrozen).toBe(false);
  await action(page, /^RetryListening /);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
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
  return button;
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

function expectCompactHud(hud, bounds) {
  expect(Object.keys(hud).sort()).toEqual(['bonus_effect', 'chests', 'hit_effect', 'hits', 'next_chest', 'score', 'status', 'targets_above_hud', 'time', 'time_bonus', 'time_bonus_caption', 'transcript']);
  const content = contentBounds(bounds);
  for (const key of ['time', 'hits', 'transcript', 'status']) {
    const rect = hud[key];
    expect(typeof rect.text).toBe('string');
    expect([rect.x, rect.y, rect.width, rect.height].every(Number.isFinite), `${key} exposes finite HUD geometry`).toBe(true);
    expect(rect.width, `${key} retains a real layout even while its text is empty`).toBeGreaterThan(0);
    expect(rect.height).toBeGreaterThan(0);
    expect(rect.x).toBeGreaterThanOrEqual(content.x - 1);
    expect(rect.x + rect.width).toBeLessThanOrEqual(content.x + content.width + 1);
    expect(rect.y).toBeGreaterThanOrEqual(content.top - 1);
  }
  expect(hud.time.text).toMatch(/^\d{2,}$/);
  expect(hud.hits.text).toMatch(/^\d+$/);
  expect(hud.time.x).toBeLessThan(hud.transcript.x);
  expect(hud.transcript.x).toBeLessThan(hud.hits.x);
  expect(Math.abs(hud.time.y - hud.hits.y)).toBeLessThanOrEqual(2);
  expect(Math.abs(hud.transcript.x + hud.transcript.width / 2 - (content.x + content.width / 2))).toBeLessThanOrEqual(2);
  expect(hud.status.y).toBeGreaterThanOrEqual(hud.transcript.y + hud.transcript.height - 1);
  expect(hud.targets_above_hud, 'Airborne words use the foreground layer above the compact HUD').toBe(true);
}

function expectForegroundTimeBonus(hud, bounds, seconds, reducedMotion) {
  expect(hud.bonus_effect).toMatchObject({ active: true, amount: seconds, reduced_motion: reducedMotion,
    duration: 1.8, above_targets: true });
  expect(hud.time_bonus.text).toBe(`+${seconds}s`);
  expect(hud.time_bonus_caption.text).toBe('TIME BONUS');
  const content = contentBounds(bounds);
  for (const key of ['time_bonus', 'time_bonus_caption']) {
    const label = hud[key];
    expect([label.x, label.y, label.width, label.height].every(Number.isFinite), `${key} has real foreground geometry`).toBe(true);
    expect(label.x).toBeGreaterThanOrEqual(content.x - 1);
    expect(label.x + label.width).toBeLessThanOrEqual(content.x + content.width + 1);
    expect(label.y).toBeGreaterThanOrEqual(hud.time.y + hud.time.height - 1);
    expect(label.y + label.height).toBeLessThanOrEqual(bounds.height - content.padding + 1);
  }
  expect(hud.time_bonus.height, 'The reward reserves prominent bounds throughout its animation')
    .toBeGreaterThanOrEqual(hud.time.height);
  // Font ascent/descent rounds up at fractional scale; allow two CSS pixels of
  // line-box whitespace while keeping the caption below the number's glyphs.
  expect(hud.time_bonus_caption.y, 'The caption sits below the earned number')
    .toBeGreaterThanOrEqual(hud.time_bonus.y + hud.time_bonus.height - 2 / bounds.scale);
}

function intersects(first, second) {
  return first.x < second.x + second.width && first.x + first.width > second.x &&
    first.y < second.y + second.height && first.y + first.height > second.y;
}

async function observeHudFeedback(page) {
  await page.evaluate(() => {
    const element = document.querySelector('#pop-status');
    window.__hudFeedback = [];
    window.__bonusFeedback = [];
    const read = () => {
      const hud = JSON.parse(element.dataset.hud || '{}');
      if (hud.hit_effect) window.__hudFeedback.push(hud);
      if (hud.bonus_effect) window.__bonusFeedback.push({ at: performance.now(), ...hud.bonus_effect });
      if (window.__hudFeedback.length > 128) window.__hudFeedback.shift();
      if (window.__bonusFeedback.length > 128) window.__bonusFeedback.shift();
    };
    window.__hudFeedbackObserver?.disconnect();
    window.__hudFeedbackObserver = new MutationObserver(read);
    window.__hudFeedbackObserver.observe(element, { attributes: true, attributeFilter: ['data-hud'] });
    read();
  });
}

test('Voice Pop keeps a compact top HUD while airborne words can pass in front of it', async ({ page }, info) => {
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const initial = await state(page);
  expectCompactHud(initial.hud, await metrics(page));
  expect(initial.hud.transcript.text).toBe('');
  expect(initial.hud.status.text).toBe('');
  expect(initial.hud.hit_effect).toEqual({ serial: 0, active: false, amount: 0, words: [] });
  await page.screenshot({ path: info.outputPath('compact-top-hud.png') });
  const phrase = 'I am still thinking';
  await page.evaluate(text => window.__popSpeech.instances.at(-1).emit(text, false), phrase);
  await expect.poll(async () => (await state(page)).hud.transcript.text).toBe(phrase);
  let overhead;
  await expect.poll(async () => {
    const current = await state(page);
    overhead = current.targets.find(target => ['time', 'hits', 'transcript'].some(key => intersects(target, current.hud[key])));
    return Boolean(overhead);
  }, { timeout: 9000, intervals: [100], message: 'The real throw arc reaches the information strip in the foreground' }).toBe(true);
  const high = await state(page);
  expect(high.hud.targets_above_hud).toBe(true);
  expectTargetInsidePlayfield(overhead, await metrics(page));
  expect(high.hits, 'High throws and HUD layout cannot award a hit').toBe(initial.hits);
  await page.screenshot({ path: info.outputPath('word-above-top-hud.png') });
  await info.attach('compact-hud-geometry.json', { body: JSON.stringify({ initial: initial.hud, high: high.hud, overhead }), contentType: 'application/json' });
  await chooseMode(page, 'match');
  expect(errors).toEqual([]);
});

test('Voice Pop starts with browser recognition without voice users or local model downloads', async ({ page }) => {
  const legacyRequests = [];
  page.on('request', request => {
    if (/\/(?:multiplayer(?:\/|-)|voice-profiles(?:-ui)?\.)/.test(new URL(request.url()).pathname)) {
      legacyRequests.push(request.url());
    }
  });
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  const current = await state(page);
  expect(current.controls.some(control => /ChoosePopMode|ContinueSolo|StartMultiplayer|VoiceProfiles/.test(control.name))).toBe(false);
  await popOne(page);
  const more = headerPoint(await metrics(page));
  await tap(page, more.x, more.y);
  await expect(page.locator('#game-status')).toContainText('Lv0');
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  expect(legacyRequests).toEqual([]);
  expect(errors).toEqual([]);
});

test('ordinary Voice Pop requests three alternatives without unsupported phrase hints and keeps unmatched speech readable', async ({ page }) => {
  const errors = await open(page, { phraseHints: true });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const recognition = await page.evaluate(() => {
    const current = window.__popSpeech.instances.at(-1);
    return { phrases: current.phrasesAtStart, local: current.localAtStart, alternatives: current.alternativesAtStart };
  });
  expect(recognition).toEqual({ phrases: [], local: false, alternatives: 3 });
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

test('local speech preparation keeps ordinary play available and enables full hints only in a ready new round', async ({ page, browserName }, info) => {
  const errors = await open(page, { url: '/?speechLocal=1', localSupport: true, phraseHints: true });
  const preparation = page.locator('#local-speech-experiment');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const ordinary = await page.evaluate(() => {
    const current = window.__popSpeech.instances.at(-1);
    return { local: current.localAtStart, phrases: current.phrasesAtStart, preparationCalls: window.__popSpeech.preparationCalls };
  });
  expect(ordinary, 'An experimental URL alone cannot start an unprepared local recognizer')
    .toEqual({ local: false, phrases: [], preparationCalls: [] });
  await expect(preparation).toBeHidden();

  await openModeMenu(page);
  await expect(preparation).toBeVisible();
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await preparation.locator('summary').click();
  await preparation.getByRole('button', { name: 'Check availability', exact: true }).click();
  await expect(preparation.getByRole('button', { name: 'Download English', exact: true })).toBeEnabled();
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  expect((await state(page)).remaining).toBeGreaterThan(0);
  await preparation.getByRole('button', { name: 'Download English', exact: true }).click();
  await expect(preparation.locator('summary')).toContainText('English ready for the next round');
  const preparationCalls = await page.evaluate(() => window.__popSpeech.preparationCalls);
  expect(preparationCalls.map(call => call.method)).toEqual(['available', 'install', 'available']);
  for (const call of preparationCalls) expect(call.options).toEqual({ langs: ['en-US'], processLocally: true });
  if (browserName === 'chromium') {
    expect(preparationCalls.find(call => call.method === 'install').activation,
      'English installation is invoked during the actual download-button gesture').toBe(true);
  }
  expect(await page.evaluate(() => window.__popSpeech.starts), 'Preparation never opens a microphone or restarts a round').toBe(1);
  expect((await state(page)).phase).toBe('paused');
  expect((await state(page)).remaining).toBeGreaterThan(0);

  await page.screenshot({ path: info.outputPath('local-speech-ready.png') });
  await chooseMode(page, 'match');
  await chooseMode(page, 'pop');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
  const local = await page.evaluate(() => {
    const current = window.__popSpeech.instances.at(-1);
    return { local: current.localAtStart, alternatives: current.alternativesAtStart,
      phrasesAtStart: current.phrasesAtStart,
      phrases: Array.from(current.phrases || [], value => ({ phrase: value.phrase, boost: value.boost })),
      targets: JSON.parse(document.getElementById('pop-status').dataset.targets || '[]'),
      diagnostics: window.wordBuddiesHost.speechDiagnostics() };
  });
  expect(local.local).toBe(true);
  expect(local.alternatives).toBe(3);
  expect(local.phrasesAtStart.map(value => value.phrase).sort()).toEqual(catalog.map(word => word.text).sort());
  expect(local.phrases.map(value => value.phrase).sort()).toEqual(catalog.map(word => word.text).sort());
  const active = new Set(local.targets.map(target => target.text));
  for (const hint of local.phrases) expect(hint.boost).toBe(active.has(hint.phrase) ? 4 : 1);
  expect(local.diagnostics.mode).toBe('local');
  await expect(preparation).toBeHidden();
  await popOne(page);
  expect(await page.evaluate(() => window.__popSpeech.starts), 'Updating active-target hints does not restart recognition').toBe(2);
  await info.attach('local-speech-preparation.json', {
    body: JSON.stringify({ preparationCalls, local }), contentType: 'application/json'
  });
  await chooseMode(page, 'match');
  expect(errors).toEqual([]);
});

test('Voice Pop shows interim speech before scoring and cannot score a corrected occurrence twice', async ({ page }, info) => {
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  // Keep the entire live-target sequence inside the page. Mobile protocol
  // round trips can outlast a throw even when recognition itself is correct.
  const evidence = await page.evaluate(async () => {
    const element = document.getElementById('pop-status');
    const read = () => ({ at: performance.now(), hits: Number(element.dataset.hits),
      transcript: element.dataset.transcript, targets: JSON.parse(element.dataset.targets || '[]') });
    const waitFor = (predicate, description) => new Promise((resolve, reject) => {
      const observer = new MutationObserver(check);
      const timeout = setTimeout(() => {
        observer.disconnect();
        reject(new Error(`Timed out waiting for ${description}: ${JSON.stringify(read())}`));
      }, 10000);
      function check() {
        const value = read();
        if (!predicate(value)) return;
        clearTimeout(timeout);
        observer.disconnect();
        resolve(value);
      }
      observer.observe(element, { attributes: true, attributeFilter: ['data-hits', 'data-transcript', 'data-targets'] });
      check();
    });
    const before = await waitFor(value => {
      const youngest = [...value.targets].sort((a, b) => a.age - b.age).slice(0, 2);
      return youngest.length === 2 && youngest[0].age <= 0.7 && youngest[1].age <= 2.8;
    }, 'two fresh targets');
    const [second, first] = [...before.targets].sort((a, b) => a.age - b.age);
    const recognition = window.__popSpeech.instances.at(-1);
    const emittedAt = performance.now();
    recognition.emit(first.text, false);
    const immediate = read();
    const scored = await waitFor(value => value.hits === before.hits + 1, 'the stable interim hit');
    const beforeCorrection = read();
    recognition.emit(second.text, true);
    const immediateCorrection = read();
    // Wait beyond the real stability window to catch an incorrectly retained
    // timer before proving that a separate utterance can hit this same card.
    await new Promise(resolve => setTimeout(resolve, 200));
    const afterCorrection = read();
    recognition.emit(second.text, true);
    const independent = await waitFor(value => value.hits === before.hits + 2, 'the independent final occurrence');
    return { first, second, before, emittedAt, immediate, scored, beforeCorrection,
      immediateCorrection, afterCorrection, independent };
  });
  const { first, second, before, immediate, scored, beforeCorrection, immediateCorrection, afterCorrection, independent } = evidence;
  expect(immediate.hits, 'Interim recognition must wait for the stability window before awarding a hit').toBe(before.hits);
  expect(immediate.transcript, 'The recognition callback publishes live text without waiting for scoring').toBe(first.text);
  expect(scored.hits).toBe(before.hits + 1);
  expect(scored.at - evidence.emittedAt, 'The actual stability timer runs before the interim hit').toBeGreaterThanOrEqual(140);
  expect(beforeCorrection.targets.some(target => target.uid === second.uid), 'The correction still has a real, hittable target').toBe(true);
  expect(immediateCorrection.transcript).toBe(second.text);
  expect(immediateCorrection.hits).toBe(before.hits + 1);
  expect(afterCorrection.hits, 'Revising the committed occurrence cannot pop a second target').toBe(before.hits + 1);
  expect(afterCorrection.targets.some(target => target.uid === second.uid), 'The unscored correction target remains live after the stability window').toBe(true);
  expect(independent.hits).toBe(before.hits + 2);
  expect(independent.targets.some(target => target.uid === second.uid), 'The next actual occurrence pops the retained target').toBe(false);
  await info.attach('speech-occurrence-revision.json', { body: JSON.stringify(evidence), contentType: 'application/json' });
  await chooseMode(page, 'match');
  expect(errors).toEqual([]);
});

test('Voice Pop never scores a lower alternative when the first candidate misses', async ({ page }) => {
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
  const before = await state(page), target = [...before.targets].sort((a, b) => a.age - b.age)[0];
  await page.evaluate(word => window.__popSpeech.instances.at(-1).emit('zzzzzz', true, [word]), target.text);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', 'zzzzzz');
  await rendered(page);
  expect((await state(page)).hits, 'Alternative hypotheses cannot manufacture a correct answer').toBe(before.hits);
  expect((await state(page)).targets.some(value => value.uid === target.uid)).toBe(true);
  await page.evaluate(word => window.__popSpeech.instances.at(-1).emit(word, true), target.text);
  await expect.poll(async () => (await state(page)).hits).toBe(before.hits + 1);
  await chooseMode(page, 'match');
  expect(errors).toEqual([]);
});

test('the live HUD shows and revises the whole interim sentence while scoring only the spoken target', async ({ page }, info) => {
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const first = 'hello everybody';
  const before = await state(page);
  expectCompactHud(before.hud, await metrics(page));
  await observeHudFeedback(page);
  await page.evaluate(text => window.__popSpeech.instances.at(-1).emit(text, false), first);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', first);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript-final', 'false');
  expect((await state(page)).hits).toBe(before.hits);
  expect((await state(page)).hud.hit_effect.serial).toBe(before.hud.hit_effect.serial);
  const hit = await page.evaluate(async expectedHits => {
    const element = document.getElementById('pop-status');
    const read = () => ({ at: performance.now(), hits: Number(element.dataset.hits),
      targets: JSON.parse(element.dataset.targets || '[]'), hud: JSON.parse(element.dataset.hud || '{}') });
    const waitFor = (predicate, description) => new Promise((resolve, reject) => {
      const observer = new MutationObserver(check);
      const timeout = setTimeout(() => {
        observer.disconnect();
        reject(new Error(`Timed out waiting for ${description}: ${JSON.stringify(read())}`));
      }, 10000);
      function check() {
        const value = read();
        if (!predicate(value)) return;
        clearTimeout(timeout);
        observer.disconnect();
        resolve(value);
      }
      observer.observe(element, { attributes: true, attributeFilter: ['data-hits', 'data-targets', 'data-hud'] });
      check();
    });
    const ready = await waitFor(value => value.targets.some(target => target.age <= 0.7), 'a fresh HUD target');
    const target = [...ready.targets].sort((a, b) => a.age - b.age)[0];
    const sentence = `please show the ${target.text}`;
    // Select and speak in the same browser task. Remote mobile protocol
    // round trips must not consume the target's remaining flight time.
    window.__popSpeech.instances.at(-1).emit(sentence, false);
    const scored = await waitFor(value => value.hits === expectedHits, 'the interim HUD hit');
    return { target, sentence, scored };
  }, before.hits + 1);
  const word = hit.target.text, sentence = hit.sentence;
  expect(hit.scored.hits).toBe(before.hits + 1);
  expect(hit.scored.hud.transcript.text).toBe(sentence);
  await info.attach('live-hud-hit.json', { body: JSON.stringify(hit), contentType: 'application/json' });
  await page.screenshot({ path: info.outputPath('hit-counter-feedback.png') });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', sentence);
  const serial = before.hud.hit_effect.serial + 1;
  await expect.poll(async () => (await state(page)).hud.hit_effect.serial).toBe(serial);
  expect((await state(page)).hud.hits.text).toBe(String(before.hits + 1));
  expect((await state(page)).hud.transcript.text).toBe(sentence);
  expect(await page.evaluate(serial => window.__hudFeedback.some(hud => hud.hit_effect.serial === serial &&
    hud.hit_effect.active && hud.hit_effect.amount === 1 && hud.hit_effect.words.length === 1), serial),
    'One true hit starts a shared counter and transcript highlight').toBe(true);
  const revised = `please show that ${word}, please`;
  await page.evaluate(text => window.__popSpeech.instances.at(-1).emit(text, false), revised);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', revised);
  expect((await state(page)).hits).toBe(before.hits + 1);
  expect((await state(page)).hud.hit_effect.serial, 'Revising the same recognized word cannot replay the hit pulse').toBe(serial);
  expect((await state(page)).hud.transcript.text).toBe(revised);
  await page.screenshot({ path: info.outputPath('live-interim-sentence.png') });
  await page.evaluate(text => window.__popSpeech.instances.at(-1).emit(text, true), revised);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', revised);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript-final', 'true');
  expect((await state(page)).hits).toBe(before.hits + 1);
  expect((await state(page)).hud.hit_effect.serial, 'Finalizing the interim hit cannot replay its HUD celebration').toBe(serial);
  await expect.poll(async () => (await state(page)).hud.hit_effect.active).toBe(false);
  expect((await state(page)).hud.transcript.text, 'The complete recognized sentence outlives its brief celebration').toBe(revised);
  await page.evaluate(() => window.__popSpeech.instances.at(-1).fail('network'));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', '');
  expect((await state(page)).hud.hit_effect.active).toBe(false);
  await page.evaluate(() => window.__popSpeech.instances[0].emit('a late stale sentence', false));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', '');
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', '');
  expect(errors).toEqual([]);
});

test('50-second Voice Pop awards combo time once and keeps reduced-motion feedback readable', async ({ page }, info) => {
  const errors = await open(page, { automatic: false });
  expect((await state(page)).remaining).toBeGreaterThan(0);
  await page.evaluate(() => window.__popSpeech.instances.at(-1).grant());
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await observeHudFeedback(page);
  await popOne(page);
  expect((await state(page)).bonusTime).toBe(0);

  for (const [combo, bonus, total] of [[2, 3, 3], [3, 5, 8]]) {
    if (combo === 3) await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
    const before = await state(page);
    const word = await popOne(page, { interim: true });
    // Inspect the readable hold phase rather than the badge's first pop-in frame.
    await page.waitForTimeout(280);
    const awarded = await state(page);
    expect(awarded.combo).toBe(combo);
    expect(awarded.bonusTime).toBe(total);
    const elapsedSeconds = (awarded.sampledAt - before.sampledAt) / 1000;
    const expectedRemaining = before.remaining + bonus - elapsedSeconds;
    expect(Math.abs(awarded.remaining - expectedRemaining),
      'The countdown adds the award and subtracts measured play time, within one displayed-second rounding interval')
      .toBeLessThanOrEqual(1);
    const bounds = await metrics(page);
    expectCompactHud(awarded.hud, bounds);
    expectForegroundTimeBonus(awarded.hud, bounds, bonus, combo === 3);
    await page.screenshot({ path: info.outputPath(`combo-${combo}-time-bonus.png`) });
    await page.evaluate(word => window.__popSpeech.instances.at(-1).emit(word, true), word);
    await rendered(page);
    const finalized = await state(page);
    expect(finalized.hits).toBe(awarded.hits);
    expect(finalized.bonusTime).toBe(total);
    expect(finalized.hud.bonus_effect.serial).toBe(awarded.hud.bonus_effect.serial);
    if (combo === 3) {
      // Screenshot capture can outlast this short effect on a remote build.
      // Compare geometry independently of text that correctly clears on expiry.
      for (const key of ['time_bonus', 'time_bonus_caption']) {
        const { text: beforeText, ...beforeRect } = awarded.hud[key];
        const { text: afterText, ...afterRect } = finalized.hud[key];
        expect(afterRect, 'Reduced motion keeps the reward and caption in a stable position').toEqual(beforeRect);
        expect(afterText).toBe(finalized.hud.bonus_effect.active ? beforeText : '');
      }
    }
  }
  await popOne(page);
  expect((await state(page)).combo).toBe(4);
  expect((await state(page)).bonusTime).toBe(8);
  await expect.poll(async () => (await state(page)).hud.bonus_effect.active).toBe(false);
  const ended = await state(page);
  expect(ended.hud.time_bonus.text).toBe('');
  const presentation = await page.evaluate(serial => {
    const frames = window.__bonusFeedback.filter(frame => frame.serial === serial);
    const start = frames.find(frame => frame.active), end = frames.find(frame => !frame.active);
    return start && end ? end.at - start.at : null;
  }, ended.hud.bonus_effect.serial);
  expect(presentation, 'The bonus has a visible start and a completed cleanup').not.toBeNull();
  expect(presentation, 'The award remains visible long enough to read').toBeGreaterThan(1500);
  expect(presentation, 'The transient bonus does not linger over play').toBeLessThan(2600);
  await page.screenshot({ path: info.outputPath('time-bonus-cleared.png') });
  await page.evaluate(() => window.__popSpeech.instances.at(-1).fail('network'));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  const paused = await state(page);
  await page.waitForTimeout(350);
  expect((await state(page)).remaining).toBe(paused.remaining);
  expect(paused.hud.bonus_effect.active).toBe(false);
  await chooseMode(page, 'match');
  await chooseMode(page, 'pop');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'ready');
  expect((await state(page)).remaining).toBeGreaterThan(0);
  expect((await state(page)).bonusTime).toBe(0);
  expect(errors).toEqual([]);
});

test('Voice Pop occasionally throws several words together with one launch cue', async ({ page, browserName }, info) => {
  await observeAudio(page, { fingerprintBuffers: true, phaseSelector: '#pop-status' });
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  await page.evaluate(() => {
    const status = document.querySelector('#pop-status');
    window.__popVolley = null;
    const read = () => {
      if (window.__popVolley || status.dataset.phase !== 'running') return;
      const targets = JSON.parse(status.dataset.targets || '[]');
      const groups = new Map();
      for (const target of targets) {
        const key = Number(target.spawned_at).toFixed(5);
        groups.set(key, [...(groups.get(key) || []), target]);
      }
      const wave = [...groups.values()].find(group => group.length >= 2);
      // Timestamp the actual DOM publication, without a Playwright round trip.
      if (wave) window.__popVolley = { wave, at: performance.now(), targetCount: targets.length };
    };
    const observer = new MutationObserver(read);
    observer.observe(status, { attributes: true, attributeFilter: ['data-targets'] });
    read();
  });
  await expect.poll(() => page.evaluate(() => Boolean(window.__popVolley)),
    { timeout: 24000, intervals: [40, 80] }).toBe(true);
  const { wave, at: waveObservedAt, targetCount } = await page.evaluate(() => window.__popVolley);
  expect(targetCount).toBeLessThanOrEqual(3);
  expect(new Set(wave.map(target => target.text)).size).toBe(wave.length);
  expect(wave[0].spawned_at).toBeGreaterThanOrEqual(8);
  if (available) {
    try {
      await expect.poll(async () => {
        const sounds = await page.evaluate(() => window.audioObservation.playbacks.filter(sound => sound.phase === 'running'));
        return sounds.filter(isLaunch).filter(sound => sound.at >= waveObservedAt - 300 && sound.at <= waveObservedAt + 250).length;
      }, { message: 'This volley plays one whoosh, without stacking identical sources or reusing an earlier launch' }).toBe(1);
    } finally {
      const sounds = await page.evaluate(() => window.audioObservation.playbacks.filter(sound => sound.phase === 'running'));
      await info.attach('volley-audio.json', { body: JSON.stringify({ wave, waveObservedAt, sounds }), contentType: 'application/json' });
    }
  }
  // Let the new wave rise fully into the clipped playfield before the capture.
  await page.waitForTimeout(1200);
  await page.screenshot({ path: info.outputPath('simultaneous-word-volley.png') });
  await info.attach('word-volley.json', { body: JSON.stringify(wave), contentType: 'application/json' });
  await chooseMode(page, 'match');
  expect(errors).toEqual([]);
});

test('Voice Pop requests permission on entry, waits, recovers from denial, and releases on mode exit', async ({ page, browserName }, info) => {
  const errors = await open(page, { automatic: false });
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  await expectGestureStart(page, browserName);
  await page.waitForTimeout(1300);
  expect((await state(page)).remaining).toBeGreaterThan(0);
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

bundledAudioTest('leaving Voice Pop restores music immediately and card audio in Match and Memory', async ({ page, browserName }, info) => {
  const audioRequests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  const errors = await open(page);
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available, 'Chromium must exercise real WebAudio playback').toBe(true);
  bundledAudioTest.skip(!available, 'This browser runtime has no WebAudio; native mode-switch audio coverage runs separately.');
  expect(audioRequests, 'Startup audio is bundled in the game pack').toEqual([]);
  const evidence = [];
  const selectSeconds = waveDuration('assets/audio/sfx/select.wav');

  for (const destination of ['match', 'memory']) {
    if (destination === 'memory') {
      // Voice recognition correctly pauses offline; start the next round online.
      await page.context().setOffline(false);
      expect(await page.evaluate(() => navigator.onLine)).toBe(true);
      await chooseMode(page, 'pop');
    }
    await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
    const listeningTheme = await page.locator('html').getAttribute('data-pip-theme');
    const listeningMusicTiming = recordingTiming(`assets/audio/bgm/${listeningTheme}.wav`);
    const listening = await page.evaluate(() => ({
      soundIndex: window.audioObservation.playbacks.length,
      recognizers: window.__popSpeech.starts,
      recognizerIndex: window.__popSpeech.instances.length - 1
    }));
    await page.waitForTimeout(650);
    const listeningSounds = await page.evaluate(from => window.audioObservation.playbacks.slice(from), listening.soundIndex);
    expect(listeningSounds.every(isLaunch), 'Listening without a hit permits only a fresh target launch').toBe(true);
    listeningSounds.forEach(expectLaunch);
    expect(await page.evaluate(timing => window.audioObservation.playbacks.some(sound =>
      Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate &&
      sound.stoppedAt === undefined && sound.endedAt === undefined),
    listeningMusicTiming), 'Voice Pop stops the previous mode\'s music').toBe(false);

    await page.context().setOffline(true);
    expect(await page.evaluate(() => navigator.onLine)).toBe(false);
    const beforeExit = await page.evaluate(() => window.audioObservation.playbacks.length);
    await chooseMode(page, destination);
    await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
    await expect(page.locator('#speech-panel')).toBeHidden();
    const theme = await page.locator('html').getAttribute('data-pip-theme');
    const musicTiming = recordingTiming(`assets/audio/bgm/${theme}.wav`);
    // Godot restarts looping samples itself; AudioBufferSourceNode.loop stays
    // false. Identify this world's music from its actual recording instead.
    await expect.poll(() => page.evaluate(({ from, timing }) => window.audioObservation.playbacks.slice(from).some(sound =>
      Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate && sound.contextState === 'running' &&
      sound.stoppedAt === undefined && sound.endedAt === undefined), { from: beforeExit, timing: musicTiming }),
    { message: `Switching from Voice Pop to ${destination} must restore music before any card tap` }).toBe(true);
    const modeStatus = await page.locator('#game-status').textContent();

    // Browsers can deliver an already queued start/result/end after abort. None
    // may re-enter the listening quiet guard or stop the destination's music.
    await page.evaluate(index => {
      const old = window.__popSpeech.instances[index];
      old.grant();
      old.emit('cat');
      old.fail('network');
      old.end();
    }, listening.recognizerIndex);
    await page.waitForTimeout(650);
    expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(listening.recognizers);
    await expect(page.locator('#game-status')).toHaveText(modeStatus);
    await expect(page.locator('#speech-panel')).toBeHidden();
    const music = await page.evaluate(({ from, timing }) => window.audioObservation.playbacks.slice(from).findLast(sound =>
      Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate && sound.endedAt === undefined),
    { from: beforeExit, timing: musicTiming });
    expect(music, 'The restored recording remains live after late recognition callbacks').toBeTruthy();
    expect(music.stoppedAt, 'Late recognition callbacks cannot stop restored music').toBeUndefined();
    expect(music.endedAt).toBeUndefined();
    expect(await page.evaluate(() => window.audioObservation.contexts.some(context => context.state === 'running'))).toBe(true);
    const musicOutput = await expectOutputEnergy(page);

    const beforeCard = await page.evaluate(() => window.audioObservation.playbacks.length);
    const bounds = await metrics(page);
    const point = destination === 'match' ? boardPoint(bounds, 0) : memoryPoint(bounds, 0);
    await tap(page, point.x, point.y);
    const pattern = destination === 'match' ? /^(Word|Picture): (.+)$/ : /^Memory card 1\. (Word|Picture): (.+)\.$/;
    await expect(page.locator('#selection-status')).toHaveText(pattern);
    const word = (await page.locator('#selection-status').textContent()).match(pattern)[2];
    const selectedWord = catalog.find(entry => entry.text === word);
    expect(selectedWord, 'The selected label must belong to the real vocabulary').toBeTruthy();
    const wordSeconds = waveDuration(selectedWord.audio);
    await expect.poll(() => page.evaluate(({ from, seconds }) => window.audioObservation.playbacks.slice(from).some(sound =>
      sound.contextState === 'running' && Math.abs(sound.duration - seconds) <= 1 / sound.sampleRate),
    { from: beforeCard, seconds: wordSeconds }), { message: `${destination} must pronounce its selected word after Voice Pop` }).toBe(true);
    const sounds = await page.evaluate(from => window.audioObservation.playbacks.slice(from), beforeCard);
    const select = sounds.find(sound => Math.abs(sound.duration - selectSeconds) <= 1 / sound.sampleRate);
    expect(select, 'The destination card also plays its bundled selection sound').toBeTruthy();
    expect(select.contextState).toBe('running');
    expect(select.fingerprint).toBeTruthy();
    expect(select.peak, 'Selection feedback contains audible PCM').toBeGreaterThan(0.01);
    const cardOutput = await expectOutputEnergy(page);
    await expect(page.locator('#audio-status')).toBeEmpty();
    expect(audioRequests, `Offline ${destination} music and card audio need no audio HTTP requests`).toEqual([]);
    evidence.push({ destination, theme, word, recording: selectedWord.audio, music, cardSounds: sounds,
      musicOutput, cardOutput });
  }
  await info.attach('voice-pop-exit-audio.json', {
    body: JSON.stringify({ offlineDuringDestination: true, audioRequests, transitions: evidence }), contentType: 'application/json'
  });
  expect(audioRequests).toEqual([]);
  expect(errors).toEqual([]);
});

test('leaving while permission is pending rejects a late grant and every callback from that recognizer', async ({ page }) => {
  const errors = await open(page, { automatic: false });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'ready');
  expect((await state(page)).remaining).toBeGreaterThan(0);
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

bundledAudioTest('fresh Voice Pop targets launch once with audible whooshes and never replay on layout or recognition resume', async ({ page, browserName }, info) => {
  const audioRequests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, phaseSelector: '#pop-status', trackSourceLifecycle: true });
  const errors = await open(page, { automatic: false });
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available, 'Chromium must exercise real launch playback').toBe(true);
  bundledAudioTest.skip(!available, 'This browser runtime has no WebAudio; native launch lifecycle coverage runs separately.');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'ready');
  const originalViewport = page.viewportSize();
  await page.evaluate(() => {
    const status = document.querySelector('#pop-status');
    const seen = new Set();
    const observation = window.__popLaunchObservation = { targets: [], output: [] };
    observation.observer = new MutationObserver(() => {
      if (status.dataset.phase !== 'running') return;
      for (const target of JSON.parse(status.dataset.targets || '[]')) {
        if (seen.has(target.uid)) continue;
        seen.add(target.uid);
        observation.targets.push({ uid: target.uid, at: performance.now() });
      }
    });
    observation.observer.observe(status, { attributes: true, attributeFilter: ['data-targets', 'data-phase'] });
    // Sample the actual destination throughout each short launch. Starting an
    // analyser poll only after a browser assertion can miss its 240 ms tail.
    observation.timer = setInterval(() => {
      if (status.dataset.phase === 'running') observation.output.push(...window.audioOutputObservation.read());
    }, 10);
    window.__popSpeech.instances.at(-1).grant();
  });
  const runningSounds = () => page.evaluate(() => window.audioObservation.playbacks.filter(sound => sound.phase === 'running'));
  const launches = async () => (await runningSounds()).filter(isLaunch);
  const seenTargets = () => page.evaluate(() => window.__popLaunchObservation.targets);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await expect.poll(async () => (await launches()).length).toBe(1);
  expectLaunch((await launches())[0]);
  expect((await seenTargets()).map(target => target.uid)).toEqual([1]);

  await page.setViewportSize({ width: originalViewport.width - 24, height: originalViewport.height });
  await page.evaluate(() => {
    window.dispatchEvent(new Event('resize'));
    window.__popSpeech.instances.at(-1).emit('supercalifragilisticexpialidocious', false);
  });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-transcript', 'supercalifragilisticexpialidocious');
  await rendered(page);
  expect((await state(page)).hits).toBe(0);
  expect((await launches()).length, 'Layout and transcript refreshes do not replay existing targets').toBe((await seenTargets()).length);

  await page.evaluate(() => window.__popSpeech.instances.at(-1).end());
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  const paused = await state(page), pausedLaunches = (await launches()).length;
  await expect.poll(() => page.evaluate(() => window.__popSpeech.starts)).toBe(2);
  await page.setViewportSize(originalViewport);
  await page.waitForTimeout(850);
  expect((await state(page)).remaining).toBe(paused.remaining);
  expect((await state(page)).targets.map(target => target.uid)).toEqual(paused.targets.map(target => target.uid));
  expect((await launches()).length, 'Waiting for the next recognizer never catches up launch sounds').toBe(pausedLaunches);
  await page.evaluate(() => window.__popSpeech.instances.at(-1).grant());
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  await rendered(page);
  expect((await launches()).length, 'Resuming preserved targets cannot replay their launch cues').toBe((await seenTargets()).length);
  await expect.poll(async () => (await seenTargets()).length, { timeout: 10000, intervals: [25, 50, 100] }).toBeGreaterThan(pausedLaunches);
  await expect.poll(async () => (await launches()).length).toBe((await seenTargets()).length);
  const all = await runningSounds(), launchSounds = all.filter(isLaunch);
  launchSounds.forEach(expectLaunch);
  expect(all.every(isLaunch), 'A round without hits or misses contains launches only, with no BGM, prompts or Pip happy calls').toBe(true);
  await expect.poll(() => page.evaluate(() => window.__popLaunchObservation.output.some(sample =>
    sample.state === 'running' && sample.rms > 0.00001)), { message: 'The launch whoosh reaches the real audio destination' }).toBe(true);
  expect(await page.evaluate(() => window.__popSpeech.spoken)).toEqual([]);
  const evidence = await page.evaluate(() => {
    const observation = window.__popLaunchObservation;
    clearInterval(observation.timer);
    observation.observer.disconnect();
    return { targets: observation.targets, output: observation.output.filter(sample => sample.rms > 0.00001) };
  });
  await chooseMode(page, 'match');
  expect(audioRequests, 'The short launch recording is bundled and never fetched during a round').toEqual([]);
  expect(errors).toEqual([]);
  await info.attach('voice-pop-launch-audio.json', {
    body: JSON.stringify({ expectedLaunch, launches: launchSounds, ...evidence }), contentType: 'application/json'
  });
});

bundledAudioTest.describe('slice audio timing', () => {
  bundledAudioTest.use({ deviceScaleFactor: 1 });

  bundledAudioTest('accepted hits start their slice sound before publishing the visual hit', async ({ page, browserName }, info) => {
    const audioRequests = watchAudioRequests(page);
    await observeOutputAudio(page, { trackSourceLifecycle: true, phaseSelector: '#pop-status' });
    const errors = await open(page);
    const available = await page.evaluate(() => window.audioObservation.available);
    if (browserName === 'chromium') expect(available).toBe(true);
    bundledAudioTest.skip(!available, 'This browser runtime has no WebAudio.');
    await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
    await page.evaluate(() => {
      const status = document.querySelector('#pop-status');
      const setAttribute = status.setAttribute;
      let hits = Number(status.dataset.hits);
      window.popAudioTiming = [];
      window.popAudioOutput = [];
      window.popAudioTimer = setInterval(() => {
        if (window.popAudioTiming.length) window.popAudioOutput.push(...window.audioOutputObservation.read());
      }, 10);
      status.setAttribute = function(name, value) {
        if (name === 'data-hits' && Number(value) > hits) {
          hits = Number(value);
          window.popAudioTiming.push({ at: performance.now(), hits,
            sounds: window.audioObservation.playbacks.length });
        }
        return setAttribute.apply(this, arguments);
      };
    });
    // Include cold and repeated samples, combos, and the first chest award.
    for (let hit = 1; hit <= 9; hit++) {
      let current;
      await expect.poll(async () => {
        current = await state(page);
        return current.targets.length;
      }, { intervals: [25] }).toBeGreaterThan(0);
      await page.evaluate(word => window.__popSpeech.instances.at(-1).emit(word), current.targets[0].text);
      await expect.poll(async () => (await state(page)).hits, { intervals: [25] }).toBe(hit);
    }
    const observation = await page.evaluate(() => {
      clearInterval(window.popAudioTimer);
      return { hits: window.popAudioTiming, sounds: window.audioObservation.playbacks,
        output: window.popAudioOutput.filter(sample => sample.rms > 0.00001),
        chests: Number(document.querySelector('#pop-status').dataset.chestCount),
        contexts: window.audioObservation.contexts.map(context => ({ state: context.state,
          baseLatency: context.baseLatency, outputLatency: context.outputLatency })) };
    });
    const slices = observation.sounds.filter(isHitSlice);
    const timingPath = info.outputPath('slice-audio-timing.json');
    fs.writeFileSync(timingPath, JSON.stringify({ ...observation,
      slices: slices.map(sound => ({ ...sound, preparationMs: sound.at - sound.createdAt })) }, null, 2));
    await info.attach('slice-audio-timing.json', { path: timingPath, contentType: 'application/json' });
    expect(slices).toHaveLength(9);
    expect(observation.hits).toHaveLength(9);
    expect(observation.output.length, 'Hit feedback reaches the running audio destination').toBeGreaterThan(0);
    expect(observation.chests, 'Timing includes the award celebration').toBeGreaterThan(0);
    for (const [index, hit] of observation.hits.entries()) {
      expect(slices[index].at, 'Start the sample in the hit callback before publishing its slice effect').toBeLessThanOrEqual(hit.at);
    }
    expect(audioRequests, 'Every hit uses already bundled audio').toEqual([]);
    expect(errors).toEqual([]);
  });
});

bundledAudioTest('three words in one utterance keep all slice tails and backgrounding stops the whole pool', async ({ page, browserName }, info) => {
  const audioRequests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true, phaseSelector: '#pop-status' });
  const errors = await open(page);
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  bundledAudioTest.skip(!available, 'This browser runtime has no WebAudio; native slice pool coverage runs separately.');
  // The introductory throws allow two targets. Three first overlap only
  // after the spawn cadence accelerates, and that overlap has a short window.
  let before;
  await expect.poll(async () => {
    before = await state(page);
    return before.targets.length;
  }, { timeout: 20000, intervals: [50] }).toBe(3);
  const words = before.targets.map(target => target.text).join(' ');
  const started = await page.evaluate(words => {
    const from = window.audioObservation.playbacks.length;
    window.__popSpeech.instances.at(-1).emit(words, false);
    return from;
  }, words);
  const slicesSince = async from => (await page.evaluate(from => window.audioObservation.playbacks.slice(from), from)).filter(isHitSlice);
  await expect.poll(async () => (await state(page)).hits).toBe(before.hits + 3);
  await expect.poll(async () => (await slicesSince(started)).length).toBe(3);
  await expect.poll(async () => (await slicesSince(started)).every(sound => sound.endedAt !== undefined)).toBe(true);
  const triple = await slicesSince(started);
  triple.forEach(expectHitSlice);
  expect(Math.max(...triple.map(sound => sound.scheduledAt)) - Math.min(...triple.map(sound => sound.scheduledAt)),
    'Three lexical callbacks share the same short hit window').toBeLessThan(0.12);
  for (const sound of triple) {
    if (sound.stopScheduledAt !== undefined) {
      expect(sound.stopScheduledAt - sound.scheduledAt, 'A simultaneous hit keeps its complete PCM tail')
        .toBeGreaterThanOrEqual(sound.duration - 0.04);
    }
    expect(sound.endedAt - sound.at, 'A hit is not interrupted by the next hit').toBeGreaterThan(sound.duration * 1000 - 60);
  }
  if (expectedSlices.length > 1) {
    expect(triple[1].fingerprint).not.toBe(triple[0].fingerprint);
    expect(triple[2].fingerprint).not.toBe(triple[1].fingerprint);
  }
  await page.evaluate(words => window.__popSpeech.instances.at(-1).emit(words, true), words);
  await rendered(page);
  expect((await state(page)).hits).toBe(before.hits + 3);
  expect((await slicesSince(started)).length, 'Finalizing an utterance never replays any slice').toBe(3);

  let next;
  await expect.poll(async () => {
    next = await state(page);
    return next.targets.length;
  }, { timeout: 10000, intervals: [50] }).toBe(3);
  const interrupted = await page.evaluate(words => {
    const from = window.audioObservation.playbacks.length;
    window.__popSpeech.instances.at(-1).emit(words);
    // Let Godot submit this frame's sources, then use the actual page lifecycle.
    setTimeout(() => window.dispatchEvent(new Event('pagehide')), 60);
    return from;
  }, next.targets.map(target => target.text).join(' '));
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'paused');
  await expect.poll(async () => (await slicesSince(interrupted)).length).toBe(3);
  const stopped = await slicesSince(interrupted);
  for (const sound of stopped) {
    expect(sound.stopScheduledAt, 'Backgrounding stops every active slice channel').toBeDefined();
    expect(sound.stopScheduledAt - sound.scheduledAt).toBeLessThan(sound.duration);
  }
  const paused = await state(page);
  await page.evaluate(words => window.__popSpeech.instances.at(-1).emit(words), words);
  await page.waitForTimeout(400);
  expect((await state(page)).hits).toBe(paused.hits);
  expect((await slicesSince(interrupted)).length).toBe(3);
  expect(audioRequests, 'Reference sounds are already in the game pack').toEqual([]);
  expect(errors).toEqual([]);
  await info.attach('triple-slice-audio.json', { body: JSON.stringify({ triple, stopped }), contentType: 'application/json' });
});

bundledAudioTest('Voice Pop keeps Pip silent through hits, misses and settlement while preserving game sounds', async ({ page, browserName }, info) => {
  bundledAudioTest.setTimeout(150000);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true, phaseSelector: '#pop-status' });
  const errors = await open(page);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(audioAvailable, 'Chromium must exercise the real audio output.').toBe(true);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'running');
  const firstWord = await popOne(page, { interim: true });
  const firstHit = await state(page);
  await page.evaluate(word => window.__popSpeech.instances.at(-1).emit(word, true), firstWord);
  await page.waitForTimeout(300);
  expect((await state(page)).hits, 'Finalizing an accepted word never scores it twice.').toBe(firstHit.hits);
  expect((await state(page)).score).toBe(firstHit.score);
  await popOne(page);
  const scored = await state(page);
  expect(scored.hits).toBe(2);
  expect(scored.score).toBeGreaterThan(0);
  // Leave the remaining targets untouched so real misses run through the same audio path.
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 60000 });
  const round = await state(page);
  expect(round.hits).toBe(2);
  expect(round.score).toBe(scored.score);
  expect(round.remaining).toBe(0);
  const fragmentCount = await page.locator('#pop-status').evaluate(element => Number(element.dataset.fragmentCount));
  const runningSounds = await page.evaluate(() => window.audioObservation.playbacks.filter(sound => sound.phase === 'running'));
  if (audioAvailable) expectSilentPipRound(runningSounds, 2, fragmentCount);
  else expect(runningSounds).toEqual([]);
  expect(await page.evaluate(() => window.__popSpeech.spoken), 'Pip adds no system speech during gameplay.').toEqual([]);

  await expectSettlement(page, { hits: 2 });
  const settlementSounds = await page.evaluate(() => window.audioObservation.playbacks.filter(sound => sound.phase === 'finished'));
  expect(settlementSounds.filter(isPipCall), 'The settlement dialog adds no Pip narration.').toEqual([]);
  expect((await state(page)).score).toBe(round.score);
  await info.attach('pip-silent-full-round-audio.json', {
    body: JSON.stringify({ audioAvailable, hits: round.hits, score: round.score, fragmentCount, runningSounds, settlementSounds }),
    contentType: 'application/json'
  });
  expect(errors).toEqual([]);
});

test('a spoken interim word pops once and settles over its frozen board', async ({ page, browserName }, info) => {
  // Includes a real 50-second round plus earned time, settlement and explicit microphone replay.
  // Keep each response deadline strict while allowing the complete workflow.
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
  const hitSlices = async () => (await runningSounds()).filter(isHitSlice);
  const pipCalls = async () => (await runningSounds()).filter(isPipCall);
  const initialSounds = await runningSounds();
  if (audioAvailable) {
    expect(initialSounds.length, 'The first target has a launch cue').toBeGreaterThan(0);
    expect(initialSounds.every(isLaunch), 'Listening starts with target launches, without prompts, Pip calls or background music').toBe(true);
    initialSounds.forEach(expectLaunch);
  } else expect(initialSounds).toEqual([]);
  const word = await popOne(page, { interim: true });
  if (audioAvailable) {
    await expect.poll(async () => (await hitSlices()).length, { message: 'A spoken hit immediately plays exactly one fruit slice.' }).toBe(1);
    expect(await pipCalls(), 'Pip celebrates a Voice Pop hit visually without adding a vocal call.').toEqual([]);
    expectHitSlice((await hitSlices())[0]);
  }
  await page.screenshot({ path: info.outputPath('hit-burst.png') });
  const hits = (await state(page)).hits;
  await page.evaluate(word => window.__popSpeech.instances.at(-1).emit(word, true), word);
  await page.waitForTimeout(300);
  expect((await state(page)).hits).toBe(hits);
  if (audioAvailable) {
    expect((await hitSlices()).length, 'Finalizing the same recognition cannot replay the slice.').toBe(1);
    expect(await pipCalls(), 'Finalizing the same recognition cannot add a Pip vocal call.').toEqual([]);
  }
  const secondWord = await popOne(page);
  if (audioAvailable) {
    await expect.poll(async () => (await hitSlices()).length).toBe(2);
    expect(await pipCalls(), 'Repeated Voice Pop hits retain slicing audio without Pip vocal calls.').toEqual([]);
    const slices = await hitSlices();
    slices.forEach(expectHitSlice);
    if (expectedSlices.length > 1) {
      expect(slices[1].fingerprint, 'Consecutive spoken hits play different PCM audio, including equal-duration fruit variants').not.toBe(slices[0].fingerprint);
    } else {
      expect(slices[1].fingerprint, 'A checkout with one hit sound can reuse its only clip').toBe(slices[0].fingerprint);
    }
  }
  const after = await state(page);
  expect(after.score).toBeGreaterThan(0);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 60000 });
  if (audioAvailable) {
    const all = await runningSounds();
    const fragmentCount = await page.locator('#pop-status').evaluate(element => Number(element.dataset.fragmentCount));
    expectSilentPipRound(all, 2, fragmentCount);
  } else {
    expect(await runningSoundCount()).toBe(0);
  }
  expect(await page.evaluate(() => window.__popSpeech.spoken), 'Listening never triggers system speech prompts').toEqual([]);
  await info.attach('hit-audio-durations.json', { body: JSON.stringify({ expectedSources: expectedSlices, playbacks: await runningSounds() }), contentType: 'application/json' });
  expect(Date.now() - start).toBeGreaterThanOrEqual(49000);
  expect((await state(page)).remaining).toBe(0);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  const round = await state(page);
  expect(round.hits).toBe(2);
  expect(round.score, 'The result summary retains exactly the points earned by the two accepted hits').toBe(after.score);
  expect(round.score).toBeGreaterThan(0);
  expect(round.score).toBeLessThan(100);
  await expectSettlement(page, { hits: 2 });
  await page.screenshot({ path: info.outputPath('pop-settlement.png') });
  expectResultSaveCue(await page.evaluate(() => window.audioObservation.playbacks.filter(sound => sound.phase === 'finished')),
    audioAvailable);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(1);
  await replaySettlement(page);
  expect(await page.evaluate(() => window.__popSpeech.starts)).toBe(2);
  await expectGestureStart(page, browserName);
  expect((await state(page)).hits).toBe(0);
  expect((await roomState(page)).game_over.visible).toBe(false);
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  expect(await page.evaluate(() => window.__popSpeech.spoken)).toEqual([]);
  expect(errors).toEqual([]);
});

bundledAudioTest('zero-hit Voice Pop settles offline without narration or a standalone results page', async ({ page, browserName }, info) => {
  bundledAudioTest.setTimeout(120000);
  const audioRequests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true, phaseSelector: '#pop-status' });
  const errors = await open(page);
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available, 'Chromium must exercise real audio output').toBe(true);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 55000 });
  const zero = await state(page);
  expect(zero.hits).toBe(0);
  expect(zero.score).toBe(0);
  const room = await expectSettlement(page, { hits: 0, chest_count: 0 });
  expect(room.chests).toEqual([]);
  expect(room.progress_text).toContain('No chest this round');
  expectResultSaveCue(await page.evaluate(() => window.audioObservation.playbacks.filter(sound => sound.phase === 'finished')));
  await page.context().setOffline(true);
  expect(await page.evaluate(() => navigator.onLine)).toBe(false);
  await expectSettlement(page, { hits: 0 });
  await page.screenshot({ path: info.outputPath('zero-hit-settlement-offline.png') });
  await settlementAction(page, 'Home');
  await chooseMode(page, 'match');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
  expect(await page.evaluate(() => window.__popSpeech.spoken)).toEqual([]);
  expect(audioRequests, 'Settlement uses only bundled assets offline').toEqual([]);
  expect(errors).toEqual([]);
});

test('Voice Pop settlement fits desktop and phone layouts and blocks the frozen board', async ({ page, isMobile }, info) => {
  // Include the real 50-second round and both full-resolution mobile captures.
  test.setTimeout(180000);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const errors = await open(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 55000 });
  const starts = await page.evaluate(() => window.__popSpeech.starts);
  const viewports = isMobile
    ? [{ width: 390, height: 844 }, { width: 844, height: 390 }]
    : [{ width: 1366, height: 768 }, { width: 960, height: 600 }];
  for (const viewport of viewports) {
    await page.setViewportSize(viewport);
    await rendered(page);
    const room = await expectSettlement(page, { hits: 0 });
    const before = await state(page);
    await tap(page, 8, 8);
    await page.keyboard.press('Tab');
    await page.keyboard.press('Escape');
    await expectSettlement(page, { hits: 0 });
    expect((await state(page)).score).toBe(before.score);
    expect(await page.evaluate(() => window.__popSpeech.starts), 'The covered board cannot restart recognition').toBe(starts);
    expect(room.scroll_max, 'The compact settlement needs no scrollbar').toBeLessThanOrEqual(1);
    await page.screenshot({ path: info.outputPath(`pop-settlement-${viewport.width}x${viewport.height}.png`) });
  }
  expect(errors).toEqual([]);
});

test('reduced-motion Voice Pop settlement shows the final score immediately', async ({ page }, info) => {
  test.setTimeout(100000);
  await page.setViewportSize({ width: 844, height: 390 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const errors = await open(page);
  await popOne(page);
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 55000 });
  const room = await expectSettlement(page, { hits: 1 });
  expect(room.game_over.reduced_motion).toBe(true);
  await page.waitForTimeout(400);
  expect((await roomState(page)).score_text).toBe(room.score_text);
  await page.screenshot({ path: info.outputPath('reduced-motion-settlement.png') });
  await replaySettlement(page);
  expect((await state(page)).hits).toBe(0);
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
  await expect(page.locator('#game-status')).toContainText('Lv0');
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
    expectCompactHud((await state(page)).hud, await metrics(page));
    await expectListeningAura(page);
    await expect.poll(async () => (await state(page)).targets.length).toBeGreaterThan(0);
    const firstTarget = (await state(page)).targets[0];
    // Follow the first throw into the middle of its flight; new throws may be crossing the arena edge.
    await expect.poll(async () => (await state(page)).remaining).toBeLessThanOrEqual(48);
    const midFlight = (await state(page)).targets.find(target => target.uid === firstTarget.uid);
    expect(midFlight, 'The first visible throw is still present during its flight').toBeTruthy();
    expectTargetInsidePlayfield(midFlight, await metrics(page));
    await page.screenshot({ path: info.outputPath('arena.png') });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expectStillAura(page);
    await expectListeningAura(page);
    await rendered(page);
    const reduced = await state(page), bounds = await metrics(page);
    expectCompactHud(reduced.hud, bounds);
    expect(reduced.targets.length).toBeGreaterThan(0);
    for (const target of reduced.targets) expectTargetInsidePlayfield(target, bounds);
    await observeHudFeedback(page);
    const hitWord = await popOne(page);
    const updated = await state(page);
    expect(updated.hud.hit_effect.serial).toBe(reduced.hud.hit_effect.serial + 1);
    expect(updated.hud.hits.text).toBe(String(updated.hits));
    expect(updated.hud.transcript.text).toBe(hitWord);
    expect(await page.evaluate(serial => window.__hudFeedback.some(hud => hud.hit_effect.serial === serial &&
      hud.hit_effect.active), updated.hud.hit_effect.serial), 'Reduced motion retains static hit feedback').toBe(true);
    for (const key of ['time', 'hits', 'transcript', 'status']) {
      expect([updated.hud[key].x, updated.hud[key].y, updated.hud[key].width, updated.hud[key].height],
        'Reduced-motion feedback preserves the HUD layout').toEqual([reduced.hud[key].x, reduced.hud[key].y,
        reduced.hud[key].width, reduced.hud[key].height]);
    }
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
  expect((await state(page)).remaining).toBeGreaterThan(0);
  await expect(page.locator('#pop-aura')).toHaveAttribute('data-listening', 'false');
  await page.screenshot({ path: info.outputPath('unsupported.png') });
  await action(page, /back|match|exit/i);
  await expect(page.locator('#game-status')).toContainText('Find 5 word');
  expect(errors).toEqual([]);
});
