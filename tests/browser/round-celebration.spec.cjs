const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const {
  openGame, metrics, tap, boardPoint, memoryPoint, discoverMatchCards, chooseMode,
  rendered, openModeMenu, celebrationState, acceptCelebration, visibleColorCount
} = require('./game-ui.cjs');
const { observeOutputAudio, recordingTiming, watchAudioRequests } = require('./bundled-audio.cjs');

async function installPerformanceCapture(page, recordVideo) {
  await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 1.3, trackSourceLifecycle: true });
  await page.addInitScript(recordVideo => {
    const destinations = new Map();
    window.roundCelebrationCapture = { recordVideo, destinations, result: null };
    if (!recordVideo || !window.AudioNode) return;
    const connect = AudioNode.prototype.connect, disconnect = AudioNode.prototype.disconnect;
    const connected = new WeakMap();
    // Add one inaudible recording branch at the game's real output. The
    // original destination and any existing analyser remain connected once.
    AudioNode.prototype.connect = function(destination, ...channels) {
      const result = connect.call(this, destination, ...channels);
      if (destination === this.context.destination && !connected.has(this)) {
        let recording = destinations.get(this.context);
        if (!recording) {
          recording = this.context.createMediaStreamDestination();
          destinations.set(this.context, recording);
        }
        connect.call(this, recording);
        connected.set(this, recording);
      }
      return result;
    };
    AudioNode.prototype.disconnect = function(...args) {
      const recording = connected.get(this);
      const result = disconnect.apply(this, args);
      if (recording && args[0] === this.context.destination) disconnect.call(this, recording);
      if (!args.length || args[0] === this.context.destination) connected.delete(this);
      return result;
    };
  }, recordVideo);
}

async function observeCelebration(page) {
  await page.evaluate(() => {
    const element = document.getElementById('game-status'), growth = document.getElementById('growth-status'),
      canvas = document.getElementById('canvas');
    const observation = { started: null, ready: null, ended: null, lastActive: null, frames: [], output: [], audioFrom: 0 };
    window.roundCelebrationObservation = observation;
    const snapshot = () => JSON.parse(element.dataset.celebration || '{}');
    const observer = new MutationObserver(() => {
      const value = snapshot(), at = performance.now();
      const result = JSON.parse(growth.dataset.view || '{}').result;
      if (value.active) observation.lastActive = value;
      if (value.active && !observation.started) {
        observation.started = { value, at };
        observation.audioFrom = window.audioObservation?.playbacks.length || 0;
        const outputTimer = setInterval(() => {
          observation.output.push(...(window.audioOutputObservation?.read() || []));
        }, 30);
        setTimeout(() => clearInterval(outputTimer), 3550);
        const capture = window.roundCelebrationCapture;
        if (capture?.recordVideo && typeof canvas.captureStream === 'function' && window.MediaRecorder) {
          const video = canvas.captureStream(30);
          const audioTracks = [...capture.destinations.values()].flatMap(destination => destination.stream.getAudioTracks());
          const stream = new MediaStream([...video.getVideoTracks(), ...audioTracks]);
          const mimeType = ['video/webm;codecs=vp8,opus', 'video/webm'].find(type => MediaRecorder.isTypeSupported(type));
          const recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined), chunks = [];
          capture.result = new Promise(resolve => {
            recorder.ondataavailable = event => { if (event.data.size) chunks.push(event.data); };
            recorder.onerror = event => resolve({ error: event.error?.message || 'MediaRecorder failed' });
            recorder.onstop = async () => {
              const blob = new Blob(chunks, { type: recorder.mimeType });
              const raw = await new Promise(resolveRaw => {
                const reader = new FileReader();
                reader.onload = () => {
                  const value = String(reader.result), marker = ';base64,', offset = value.indexOf(marker);
                  resolveRaw(offset < 0 ? null : value.slice(offset + marker.length));
                };
                reader.onerror = () => resolveRaw(null);
                reader.readAsDataURL(blob);
              });
              stream.getTracks().forEach(track => track.stop());
              if (!raw) return resolve({ error: 'The audiovisual recording did not produce a valid base64 data URL' });
              resolve({ raw, mimeType: recorder.mimeType, audioTracks: audioTracks.length,
                videoTracks: video.getVideoTracks().length, startedAt: at, finishedAt: performance.now() });
            };
          });
          recorder.start(100);
          setTimeout(() => { if (recorder.state !== 'inactive') recorder.stop(); }, 3500);
        }
        for (const delay of [120, 520, 1220, 1950, 2720]) {
          setTimeout(() => requestAnimationFrame(() => {
            const state = snapshot();
            if (state.active && state.round_id === value.round_id) {
              observation.frames.push({ at: performance.now(), value: state,
                raw: canvas.toDataURL('image/png').split(',')[1] });
            }
          }), delay);
        }
      }
      if (observation.started && !observation.ready && (value.active && value.ready || !value.active && result?.visible)) {
        observation.ready = { value, at, result };
      }
      if (observation.started && !value.active && !observation.ended) {
        observation.ended = { value, at };
      }
      if (observation.ready && observation.ended) {
        observer.disconnect();
      }
    });
    observer.observe(element, { attributes: true, attributeFilter: ['data-celebration'] });
    observer.observe(growth, { attributes: true, attributeFilter: ['data-view'] });
  });
}

async function savePerformance(page, info, mode) {
  if (await page.evaluate(() => window.roundCelebrationCapture?.recordVideo)) {
    const recording = await page.evaluate(async () => await window.roundCelebrationCapture.result);
    expect(recording, 'Chromium captures the real canvas and final mixed output').toBeTruthy();
    expect(recording.error).toBeUndefined();
    expect(recording.audioTracks).toBeGreaterThan(0);
    expect(recording.videoTracks).toBe(1);
    const recordingPath = info.outputPath(`${mode}-celebration-real-time.webm`);
    const bytes = Buffer.from(recording.raw, 'base64');
    expect(bytes.length, 'The synchronized audiovisual recording is nonempty').toBeGreaterThan(10000);
    fs.writeFileSync(recordingPath, bytes);
    await info.attach(`${mode}-celebration-real-time`, { path: recordingPath, contentType: recording.mimeType });
  }
  const observation = await page.evaluate(() => window.roundCelebrationObservation);
  expect(observation.started?.value, `${mode} enters the shared performance`).toMatchObject({ active: true, mode });
  expect(observation.frames.length, 'Normal-speed inspection retains multiple articulated poses').toBeGreaterThanOrEqual(4);
  for (const [index, frame] of observation.frames.entries()) {
    const bytes = Buffer.from(frame.raw, 'base64');
    fs.writeFileSync(info.outputPath(`${mode}-celebration-${index}.png`), bytes);
    expect(await visibleColorCount(page, bytes), `${mode} frame ${index} contains the real rendered game`).toBeGreaterThan(20);
  }
  fs.writeFileSync(info.outputPath(`${mode}-celebration-timeline.json`), JSON.stringify({
    ...observation, frames: observation.frames.map(({ raw, ...frame }) => frame)
  }, null, 2));
  if (await page.evaluate(() => window.audioObservation?.available)) {
    const playbacks = await page.evaluate(from => window.audioObservation.playbacks.slice(from), observation.audioFrom);
    const step = recordingTiming('assets/imported-audio/chest-reference/step.wav');
    const reward = recordingTiming('assets/imported-audio/chest-reference/reward.wav');
    const near = (sound, timing) => Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate;
    const duringPerformance = sound => sound.at < observation.started.at + 3200;
    const steps = playbacks.filter(sound => near(sound, step) && duringPerformance(sound));
    const rewards = playbacks.filter(sound => near(sound, reward) && duringPerformance(sound));
    expect(steps, 'The actual output starts one takeoff cue and one landing cue').toHaveLength(2);
    expect(new Set(steps.map(sound => sound.fingerprint)).size, 'The two equal-length cues contain distinct audio').toBe(2);
    expect(rewards, 'The reward reveal cue plays only for an earned chest')
      .toHaveLength(observation.started.value.chest_count > 0 && !observation.started.value.chest_announced ? 1 : 0);
    for (const [index, sound] of [...steps, ...rewards].entries()) {
      const onset = sound.at + Math.max(0, sound.scheduledAt - sound.contextTime) * 1000 - observation.started.at;
      expect(Math.abs(onset - [250, 900, 1800][index]), 'Motion and real output share the same performance clock').toBeLessThanOrEqual(450);
      expect(sound.contextState).toBe('running');
      expect(sound.peak).toBeGreaterThan(0.01);
      expect(sound.playbackRate).toBe(1);
    }
    expect(Math.max(0, ...observation.output.map(sample => sample.rms)),
      'The final mixed WebAudio output is audible during the recorded performance').toBeGreaterThan(0.00001);
    fs.writeFileSync(info.outputPath(`${mode}-celebration-audio.json`), JSON.stringify({
      steps, rewards, output: observation.output
    }, null, 2));
  }
  return observation;
}

async function finishMatch(page) {
  const cards = await discoverMatchCards(page), bounds = await metrics(page);
  const words = [...new Set(cards.map(card => card.word))];
  for (const [index, word] of words.entries()) {
    for (const kind of ['Word', 'Picture']) {
      const card = cards.find(value => value.word === word && value.kind === kind);
      const point = boardPoint(bounds, card.index);
      await tap(page, point.x, point.y);
    }
    await expect(page.locator('#game-status')).toContainText('Great match!');
    if (index < words.length - 1) {
      await page.keyboard.press('Escape');
      await expect(page.locator('#game-status')).toContainText('Find 5 word');
    }
  }
}

async function finishMemory(page) {
  await chooseMode(page, 'memory');
  const board = [], bounds = await metrics(page);
  for (let index = 0; index < 10; index++) {
    const point = memoryPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^Memory card \d+\. (Word|Picture): [a-z]+\.$/);
    const [, kind, word] = (await page.locator('#selection-status').textContent())
      .match(/^Memory card \d+\. (Word|Picture): ([a-z]+)\.$/);
    board.push({ index, kind, word });
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  const words = [...new Set(board.map(card => card.word))];
  for (const [index, word] of words.entries()) {
    for (const card of board.filter(value => value.word === word)) {
      const point = memoryPoint(bounds, card.index);
      await tap(page, point.x, point.y);
    }
    if (index < words.length - 1) {
      await expect(page.locator('#game-status')).toContainText('Find a pair.');
    }
  }
}

async function captureReadyLayouts(page, info, earned) {
  const original = page.viewportSize(), originalPanel = (await metrics(page)).growth.settlement.panel_rect;
  for (const viewport of [original, { width: 390, height: 844 }, { width: 844, height: 390 }]) {
    if (JSON.stringify(page.viewportSize()) !== JSON.stringify(viewport)) {
      const previous = (await metrics(page)).growth.settlement.panel_rect;
      await page.setViewportSize(viewport);
      await expect.poll(async () => (await metrics(page)).growth.settlement.panel_rect,
        { message: 'The settlement completes its responsive layout' }).not.toEqual(previous);
    }
    await rendered(page);
    const state = await celebrationState(page), bounds = await metrics(page);
    expect(bounds.growth.settlement.visible).toBe(true);
    expect(state.active).toBe(!earned);
    const visible = { left: Math.max(0, bounds.x), top: Math.max(0, bounds.y),
      right: Math.min(viewport.width, bounds.x + bounds.width * bounds.scale),
      bottom: Math.min(viewport.height, bounds.y + bounds.height * bounds.scale) };
    const controls = earned ? bounds.growth.result.controls.filter(control => control.visible) :
      [{ name: 'Pip', rect: state.pip_rect }, { name: 'Play again', ...state.action }, { name: 'Home', ...state.home }];
    for (const { name, rect: [x, y, width, height] } of controls) {
      expect(width, `${name} has visible width`).toBeGreaterThan(0);
      expect(height, `${name} has visible height`).toBeGreaterThan(0);
      expect(bounds.x + x * bounds.scale, `${name} left edge`).toBeGreaterThanOrEqual(visible.left - 1);
      expect(bounds.y + y * bounds.scale, `${name} top edge`).toBeGreaterThanOrEqual(visible.top - 1);
      expect(bounds.x + (x + width) * bounds.scale, `${name} right edge`).toBeLessThanOrEqual(visible.right + 1);
      expect(bounds.y + (y + height) * bounds.scale, `${name} bottom edge`).toBeLessThanOrEqual(visible.bottom + 1);
    }
    if (earned) {
      const [x, y, width, height] = controls.find(control => control.name === 'OpenSettlementChest').rect;
      for (const action of controls.filter(control => control.name !== 'OpenSettlementChest')) {
        const [bx, by, bw, bh] = action.rect;
        expect(bx + bw <= x || x + width <= bx || by + bh <= y || y + height <= by,
          `${action.name} does not overlap the interactive chest`).toBe(true);
      }
    }
    const image = await page.screenshot({ path: info.outputPath(`match-settlement-${viewport.width}x${viewport.height}.png`), scale: 'css' });
    expect(await visibleColorCount(page, image), 'The complete responsive game UI is rendered').toBeGreaterThan(20);
  }
  await page.setViewportSize(original);
  await expect.poll(async () => (await metrics(page)).growth.settlement.panel_rect).toEqual(originalPanel);
  await rendered(page);
}

async function savedTreasureCounts(page) {
  return page.evaluate(() => (localStorage.getItem('wordBuddies.medalProgress') || '').match(/^counts=(.*)$/m)?.[1] || '{}');
}

for (const mode of ['match', 'memory']) {
  test(`${mode} celebrates before directly offering its chest or Play again`, async ({ page, browserName }, info) => {
    const requests = watchAudioRequests(page);
    await installPerformanceCapture(page, browserName === 'chromium');
    const errors = await openGame(page, { reducedMotion: 'no-preference' });
    await observeCelebration(page);
    const saved = await savedTreasureCounts(page);
    await (mode === 'match' ? finishMatch(page) : finishMemory(page));
    await expect.poll(async () => (await celebrationState(page)).active).toBe(true);
    // A tap on the presentation cannot claim the still-closed chest early.
    const entrance = await celebrationState(page);
    const [x, y, width, height] = entrance.chest_count > 0 ? entrance.chest_rect : entrance.pip_rect;
    await tap(page, x + width / 2, y + height / 2);
    const earned = entrance.chest_count === 1;
    expect([0, 1]).toContain(entrance.chest_count);
    if (earned) await acceptCelebration(page);
    else await expect.poll(async () => (await celebrationState(page)).ready, { timeout: 15000 }).toBe(true);
    const current = await celebrationState(page);
    expect(current.action).toMatchObject(earned ? { visible: false, disabled: true } :
      { text: 'Play again', visible: true, disabled: false });
    expect(await savedTreasureCounts(page), 'The entrance and readiness do not claim the chest.').toBe(saved);
    const observation = await savePerformance(page, info, mode);
    expect(observation.ready.at - observation.started.at, 'The full celebration lasts three seconds').toBeGreaterThanOrEqual(2850);
    expect(observation.lastActive).toMatchObject({ automatic: false, chest_visible: earned,
      caption: earned ? 'You earned a treasure chest!' : 'Every word matched!',
      cue_log: earned && !entrance.chest_announced ? ['step', 'step-detail', 'reward'] : ['step', 'step-detail'] });
    if (earned) {
      expect(observation.ended, 'The performance hands off to the real chest without an extra click.').toBeTruthy();
      expect((await metrics(page)).growth.result.visible).toBe(true);
    } else expect(observation.ended, 'A round without a chest still waits for Play again.').toBeNull();
    const readyId = current.round_id;
    if (mode === 'match' && browserName === 'chromium' && !info.project.use.isMobile) {
      await captureReadyLayouts(page, info, earned);
    }
    await openModeMenu(page);
    await chooseMode(page, mode);
    if (earned) await acceptCelebration(page);
    else {
      await expect.poll(async () => (await celebrationState(page)).ready).toBe(true);
      const restored = await celebrationState(page);
      expect(restored).toMatchObject({ round_id: readyId, ready: true,
        chest_count: 0, chest_visible: false, action: { visible: true, disabled: false } });
      const [bx, by, bw, bh] = restored.action.rect;
      await tap(page, bx + bw / 2, by + bh / 2);
      await expect.poll(async () => (await celebrationState(page)).active).toBe(false);
      await expect(page.locator('#game-status')).toContainText(mode === 'match' ? 'Find 5 word' : 'Find a pair.');
    }
    await rendered(page);
    await page.screenshot({ path: info.outputPath(`${mode}-${earned ? 'unopened-chest' : 'play-again'}.png`), scale: 'css' });
    expect(await savedTreasureCounts(page)).toBe(saved);
    expect(requests, 'Celebration and narration use bundled audio without external media requests').toEqual([]);
    expect(errors).toEqual([]);
  });
}

async function installSpeech(page) {
  await page.addInitScript(() => {
    const fixture = { instances: [], starts: 0, stopped: 0 };
    class Recognition {
      constructor() { this.results = []; this.running = false; fixture.instances.push(this); }
      start() {
        fixture.starts++;
        this.running = true;
        this.callbacks = { start: this.onstart, audio: this.onaudiostart, result: this.onresult, error: this.onerror, end: this.onend };
        queueMicrotask(() => { this.callbacks.start?.(); this.callbacks.audio?.(); });
      }
      abort() {
        fixture.stopped++;
        this.running = false;
        const callbacks = this.callbacks;
        queueMicrotask(() => { callbacks.error?.({ error: 'aborted' }); callbacks.end?.(); });
      }
      stop() { this.abort(); }
      emit(text) {
        const resultIndex = this.results.length;
        this.results.push(Object.assign([{ transcript: text, confidence: 0.95 }], { isFinal: true }));
        this.callbacks.result?.({ resultIndex, results: this.results });
      }
    }
    window.__celebrationSpeech = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: Recognition });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => {
      throw new Error('The speech fixture must never open a physical microphone');
    };
  });
}

test('Voice Pop saves one final upgraded chest directly inside its settlement dialog', async ({ page, browserName }, info) => {
  test.setTimeout(120000);
  const requests = watchAudioRequests(page);
  await installSpeech(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  const errors = await openGame(page, { reducedMotion: 'no-preference', mode: 'pop' });
  await observeCelebration(page);
  await page.evaluate(() => {
    const status = document.getElementById('pop-status'), spoken = new Set();
    const timer = setInterval(() => {
      if (Number(status.dataset.fragmentCount) >= 9 || status.dataset.phase === 'finished') return clearInterval(timer);
      const recognition = window.__celebrationSpeech.instances.at(-1);
      if (status.dataset.phase !== 'running' || !recognition?.running) return;
      const target = JSON.parse(status.dataset.targets || '[]').find(item => !spoken.has(item.uid));
      if (target) { spoken.add(target.uid); recognition.emit(target.text); }
    }, 80);
  });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-fragment-count', '9', { timeout: 65000 });
  await expect(page.locator('#pop-status')).toHaveAttribute('data-chest-count', '1');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-chest-tier', '2');
  await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'finished', { timeout: 70000 });
  await expect.poll(() => page.locator('#pop-reward-status').evaluate(element => {
    const value = JSON.parse(element.dataset.snapshot || '{}');
    return { visible: value.visible, dialog: value.game_over?.visible, count: value.chest_count,
      opened: value.opened_count, tier: value.chests[0]?.tier, fragments: value.result_context?.fragment_count };
  }), { timeout: 45000 }).toEqual({ visible: true, dialog: true, count: 1, opened: 0, tier: 2, fragments: 9 });
  expect(await page.evaluate(() => window.roundCelebrationObservation?.started),
    'Settlement does not start a separate full-page finale').toBeFalsy();
  expect(await page.evaluate(() => window.__celebrationSpeech.instances.every(value => !value.running)),
    'Recognition stops before the settlement dialog opens').toBe(true);
  expect(await page.locator('#pop-status').evaluate(element => ({
    frozen: element.dataset.boardFrozen === 'true', controls: JSON.parse(element.dataset.controls || '[]')
  }))).toEqual({ frozen: true, controls: [] });
  expect(await page.evaluate(() => localStorage.getItem('wordBuddies.popRewards'))).toBeTruthy();
  await page.screenshot({ path: info.outputPath('pop-final-chest-dialog.png'), scale: 'css' });
  expect(requests, 'Voice Pop settlement uses bundled audio without external media requests').toEqual([]);
  expect(errors).toEqual([]);
});
