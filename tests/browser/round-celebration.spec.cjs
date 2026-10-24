const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const {
  openGame, metrics, tap, boardPoint, discoverMatchCards, chooseMode,
  rendered, openModeMenu, celebrationState, acceptCelebration, visibleColorCount
} = require('./game-ui.cjs');
const { observeOutputAudio, recordingTiming, watchAudioRequests } = require('./bundled-audio.cjs');
const { startObservation, startMatching, completeRememberedBoard } = require('./memory-flow.cjs');

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
    const observation = { started: null, ready: null, ended: null, lastActive: null, frames: [], timeline: [], output: [], audioFrom: 0 };
    window.roundCelebrationObservation = observation;
    const snapshot = () => JSON.parse(element.dataset.celebration || '{}');
    const observer = new MutationObserver(() => {
      const value = snapshot(), at = performance.now();
      const view = JSON.parse(growth.dataset.view || '{}'), result = view.result;
      const room = ['pop', 'jelly'].map(mode => JSON.parse(document.getElementById(`${mode}-reward-status`)?.dataset.snapshot || '{}'))
        .find(state => state.visible);
      if (value.active) {
        observation.lastActive = value;
        observation.timeline.push({ at, value });
      }
      if (value.active && !observation.started) {
        observation.started = { value, at, panel: view.settlement?.panel_rect };
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
        for (const delay of [120, 520, 1220, 1600, 2050, 2720]) {
          setTimeout(() => requestAnimationFrame(() => {
            const state = snapshot();
            if (state.active && state.round_id === value.round_id) {
              observation.frames.push({ at: performance.now(), value: state,
                raw: canvas.toDataURL('image/png').split(',')[1] });
            }
          }), delay);
        }
      }
      if (observation.started && !observation.ready && (value.active && value.ready || !value.active && (result?.visible || room))) {
        observation.ready = { value, at, result, room };
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
    for (const mode of ['pop', 'jelly']) {
      const status = document.getElementById(`${mode}-reward-status`);
      if (status) observer.observe(status, { attributes: true, attributeFilter: ['data-snapshot'] });
    }
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
    expect(bytes.subarray(0, 4).toString('hex'), 'The saved recording has a valid WebM container header').toBe('1a45dfa3');
    fs.writeFileSync(recordingPath, bytes);
    await info.attach(`${mode}-celebration-real-time`, { path: recordingPath, contentType: recording.mimeType });
  }
  const observation = await page.evaluate(() => window.roundCelebrationObservation);
  expect(observation.started?.value, `${mode} enters the shared performance with normal motion`).toMatchObject({ active: true, mode, reduced_motion: false });
  expectPerformanceSequence(observation);
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

function expectPerformanceSequence(observation) {
  const entrance = observation.started.value, final = observation.lastActive;
  expect(entrance.chest_opacity, 'The chest is concealed while Pip starts celebrating').toBe(0);
  expect(entrance.caption_opacity, 'The opening instruction waits for the chest').toBe(0);
  if (!entrance.chest_count) {
    expect(final).toMatchObject({ chest_count: 0, chest_visible: false, caption: 'Every word matched!' });
    return;
  }
  const states = observation.timeline.map(item => item.value);
  const arrival = states.find(state => state.chest_opacity > 0.05);
  const invitation = states.find(state => state.caption_opacity > 0.05);
  expect(arrival, 'The real closed chest appears after Pip makes room').toBeTruthy();
  expect(invitation, 'The opening instruction appears after the chest lands').toBeTruthy();
  expect(invitation.elapsed).toBeGreaterThan(arrival.elapsed);
  expect(invitation).toMatchObject({ title: 'You earned a chest!', caption: 'Hold the chest to open', chest_opacity: 1 });
  expect(arrival.pip_rect[0], 'Pip has reached the side before the chest appears').toBeCloseTo(final.pip_rect[0], 0);
  if (!entrance.reduced_motion) {
    const panel = observation.started.panel;
    expect(panel, 'The celebration retains its settlement panel geometry').toHaveLength(4);
    expect(entrance.pip_rect[0] + entrance.pip_rect[2] / 2,
      'Pip owns the center at the start of the performance').toBeCloseTo(panel[0] + panel[2] / 2, 0);
    expect(entrance.pip_rect[0] + entrance.pip_rect[2] / 2 - final.pip_rect[0] - final.pip_rect[2] / 2,
      'Pip visibly moves aside before the reward invitation').toBeGreaterThan(10);
    expect(states.some(state => state.stage === 'move_aside'), 'Normal playback includes the side step').toBe(true);
  } else {
    for (const state of states) expect(state.pip_rect, 'Reduced motion keeps Pip in its final position').toEqual(final.pip_rect);
  }
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
  const board = await startObservation(page);
  await startMatching(page);
  await completeRememberedBoard(page, board);
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
  await expect.poll(async () => {
    const restored = (await metrics(page)).growth.settlement.panel_rect;
    return Math.max(...restored.map((value, index) => Math.abs(value - originalPanel[index])));
  }, { message: 'The settlement returns to its original geometry within floating-point layout precision' }).toBeLessThan(0.01);
  await rendered(page);
}

async function savedPairProgress(page) {
  return page.evaluate(() => {
    const text = localStorage.getItem('wordBuddies.medalProgress') || '';
    const dictionary = (section, key) => {
      const block = text.match(new RegExp(`\\[${section}\\]\\r?\\n([\\s\\S]*?)(?=\\r?\\n\\[|$)`))?.[1];
      const value = block?.match(new RegExp(`^${key}=(\\{[\\s\\S]*\\})\\s*$`, 'm'))?.[1];
      if (!value) throw new Error(`The persisted ${section}/${key} dictionary is missing`);
      return JSON.parse(value);
    };
    return { counts: dictionary('medals', 'counts'), pairs: dictionary('pair_chests', 'state') };
  });
}

const jellyState = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));

async function pressRect(page, [x, y, width, height]) {
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function finishJelly(page, { fragments = 4 } = {}) {
  for (let attempt = 0; attempt < 100; attempt++) {
    await expect.poll(async () => {
      const state = await jellyState(page);
      return state.phase === 'playing' && state.generated_tiles > 0 && Array.isArray(state.tiles) && !state.reward_presentation?.active &&
        !state.fusions?.length && state.tiles.every(tile => tile.settled);
    }, { timeout: 20000, message: 'The real Jelly board settles before the next action' }).toBe(true);
    const state = await jellyState(page);
    if (state.fragment_count >= fragments) break;
    if (state.mode === 'word_jelly') {
      const candidates = state.tiles.filter(tile => tile.visible && tile.composition?.complete && tile.word?.id);
      const word = candidates.find(tile => tile.fragments > 0) || candidates[0];
      if (word) {
        await pressRect(page, word.rect);
        await expect.poll(async () => (await jellyState(page)).cleared_pairs,
          { message: 'The supplied whole word is genuinely collected' }).toBe(state.cleared_pairs + 1);
        continue;
      }
    } else {
      const pairs = state.tiles.filter(tile => tile.visible && tile.settled).map(first => [first,
        state.tiles.find(second => second.id !== first.id && second.visible && second.settled &&
          second.word.id === first.word.id && second.kind !== first.kind)]).filter(pair => pair[1]);
      const pair = pairs.find(tiles => tiles.some(tile => tile.chest)) || pairs[0];
      if (pair) {
        const bounds = await metrics(page);
        const center = rect => ({ x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
          y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale });
        const from = center(pair[0].rect), to = center(pair[1].rect);
        await page.mouse.move(from.x, from.y);
        await page.mouse.down();
        try {
          await expect.poll(async () => (await jellyState(page)).drag.source).toBe(pair[0].id);
          await page.mouse.move(to.x, to.y, { steps: 10 });
          await expect.poll(async () => (await jellyState(page)).drag.target).toBe(pair[1].id);
        } finally { await page.mouse.up(); }
        await expect.poll(async () => (await jellyState(page)).cleared_pairs,
          { message: 'The actual word-picture fusion credits one pair' }).toBe(state.cleared_pairs + 1);
        continue;
      }
    }
    expect(state.preview.enabled, 'Real supply remains available while earning treasure').toBe(true);
    await pressRect(page, state.preview.rect);
    await expect.poll(async () => (await jellyState(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
  }
  const earned = await jellyState(page);
  expect(earned.fragment_count, 'The played round earns the requested fragments').toBeGreaterThanOrEqual(fragments);
  const bounds = await metrics(page), control = earned.finish;
  expect(control.visible && !control.disabled, 'Finish accepts its deliberate pull').toBe(true);
  const x = bounds.x + (control.rect[0] + control.rect[2] / 2) * bounds.scale;
  const y = bounds.y + (control.rect[1] + control.rect[3] / 2) * bounds.scale;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x, y + control.pull.threshold * bounds.scale + 10, { steps: 4 });
  await page.mouse.up();
  await expect.poll(async () => (await jellyState(page)).phase).toBe('finished');
  return earned;
}

const phraseState = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.phrase || '{}'));

async function finishPhrase(page) {
  for (let question = 0; question < 3; question++) {
    await expect.poll(async () => (await phraseState(page)).question_index).toBe(question);
    const state = await phraseState(page);
    for (const wordId of state.target_ids) {
      let control;
      for (let attempt = 0; attempt < 24; attempt++) {
        const current = await phraseState(page);
        control = current.options.find(option => option.word_id === wordId);
        expect(control?.visible && !control.disabled, 'The target word remains available').toBe(true);
        const [x, , width] = control.rect, [left, top, bankWidth, bankHeight] = current.bank.rect;
        if (x >= left - 0.5 && x + width <= left + bankWidth + 0.5) break;
        const bounds = await metrics(page), direction = x < left ? -1 : 1;
        await page.mouse.move(bounds.x + (left + bankWidth / 2) * bounds.scale,
          bounds.y + (top + bankHeight / 2) * bounds.scale);
        await page.mouse.wheel(0, direction * 80);
        await rendered(page);
        control = null;
      }
      expect(control, 'Scrolling reveals the actual target word').toBeTruthy();
      const before = await phraseState(page);
      await pressRect(page, control.rect);
      await expect.poll(async () => (await phraseState(page)).answer).toEqual([...before.answer, control.index]);
    }
    await pressRect(page, (await phraseState(page)).action.rect);
    await expect.poll(async () => (await phraseState(page)).completed).toBe(question + 1);
    if (question < 2) {
      await expect.poll(async () => {
        const action = (await phraseState(page)).action;
        return action.visible && !action.disabled;
      }, { timeout: 20000, message: 'The completed phrase narration and Pip gesture finish' }).toBe(true);
      await pressRect(page, (await phraseState(page)).action.rect);
    }
  }
}

for (const mode of ['match', 'memory']) {
  test(`${mode} celebrates before directly offering its chest or Play again`, async ({ page, browserName }, info) => {
    // Real play, audiovisual capture and responsive layouts share one software-WebGL budget.
    test.setTimeout(240000);
    const requests = watchAudioRequests(page);
    await installPerformanceCapture(page, browserName === 'chromium');
    const errors = await openGame(page, { reducedMotion: 'no-preference' });
    await observeCelebration(page);
    const saved = (await savedPairProgress(page)).counts;
    const startingBalance = await page.locator('#coin-status').evaluate(element => JSON.parse(element.dataset.snapshot).balance);
    await (mode === 'match' ? finishMatch(page) : finishMemory(page));
    await expect.poll(async () => (await celebrationState(page)).active).toBe(true);
    // A tap on the presentation cannot claim the still-closed chest early.
    const entrance = await celebrationState(page);
    const [x, y, width, height] = entrance.chest_count > 0 ? entrance.chest_rect : entrance.pip_rect;
    await tap(page, x + width / 2, y + height / 2);
    const earned = entrance.chest_count === 1;
    expect([0, 1]).toContain(entrance.chest_count);
    if (mode === 'memory') expect(earned, 'A perfect Memory round keeps its highest available chest').toBe(true);
    if (earned) await acceptCelebration(page);
    else await expect.poll(async () => (await celebrationState(page)).ready, { timeout: 15000 }).toBe(true);
    const current = await celebrationState(page);
    expect(current.action).toMatchObject(earned ? { visible: false, disabled: true } :
      { text: 'Play again', visible: true, disabled: false });
    expect((await savedPairProgress(page)).counts, 'The entrance and readiness do not claim the chest.').toEqual(saved);
    const observation = await savePerformance(page, info, mode);
    expect(observation.ready.at - observation.started.at, 'The full celebration lasts three seconds').toBeGreaterThanOrEqual(2850);
    expect(observation.lastActive).toMatchObject({ automatic: false, chest_visible: earned,
      caption: earned ? 'Hold the chest to open' : 'Every word matched!',
      cue_log: earned && !entrance.chest_announced ? ['step', 'step-detail', 'reward'] : ['step', 'step-detail'] });
    if (earned) {
      expect(observation.ended, 'The performance hands off to the real chest without an extra click.').toBeTruthy();
      expect((await metrics(page)).growth.result.visible).toBe(true);
    } else expect(observation.ended, 'A round without a chest still waits for Play again.').toBeNull();
    const completedId = observation.started.value.round_id;
    const reserved = (await savedPairProgress(page)).pairs[mode].round;
    expect(reserved, 'The completed round retains its exact pending reward until settlement')
      .toMatchObject({ id: completedId, completed: true, awarded: earned, settled: false });
    if (mode === 'memory') expect(reserved.tier).toBe(6);
    const expectedCounts = { ...saved };
    if (earned && Object.keys(reserved.fragment).length) {
      const fragment = reserved.fragment;
      expect(fragment.before).toBe(saved[fragment.medal_id] || 0);
      expect(fragment.after, 'The captured reward adds exactly one legacy medal fragment').toBe(fragment.before + 1);
      expectedCounts[fragment.medal_id] = fragment.after;
    }
    if (mode === 'match' && browserName === 'chromium' && !info.project.use.isMobile) {
      await captureReadyLayouts(page, info, earned);
    }
    const quotedReward = earned ? (await metrics(page)).growth.result.coin_breakdown.reward : null;
    if (earned) expect(quotedReward).toMatchObject({ tier: mode === 'memory' ? 6 : 1,
      base: mode === 'memory' ? 300 : 50 });
    await openModeMenu(page);
    const expectedBalance = startingBalance + (quotedReward?.total || 0);
    await expect.poll(() => page.locator('#coin-status').evaluate(element => JSON.parse(element.dataset.snapshot).balance),
      { message: 'Home settles the one earned chest exactly once' }).toBe(expectedBalance);
    const walletAfterHome = await page.evaluate(() => localStorage.getItem('growWithPip.coinWallet.v1') || '');
    if (earned) {
      const receipts = JSON.parse(walletAfterHome.match(/^receipts=(\{[^}]*\})/m)[1]);
      expect(receipts[`pair:${mode}:${completedId}`],
        'The completed chest has its exact quoted amount in the durable receipt ledger').toBe(quotedReward.total);
    }
    const settled = await savedPairProgress(page);
    expect(settled.counts, 'Home saves exactly the captured medal fragment').toEqual(expectedCounts);
    expect(settled.pairs[mode].round.settled).toBe(earned);
    await chooseMode(page, mode);
    await expect.poll(async () => (await celebrationState(page)).active).toBe(false);
    if (mode === 'match') await expect(page.locator('#game-status')).toContainText('Find 5 word');
    else await expect.poll(async () => (await metrics(page)).growth.memory.start.visible).toBe(true);
    const fresh = await metrics(page), freshId = mode === 'match' ? fresh.growth.match.hint.round_id : fresh.growth.memory.peek.round_id;
    expect(freshId, 'Choosing a completed game starts a fresh round').not.toBe(completedId);
    expect(fresh.growth.settlement.visible, 'The fresh board does not restore the completed settlement').toBe(false);
    expect(await page.evaluate(() => localStorage.getItem('growWithPip.coinWallet.v1') || ''),
      'Returning to the mode cannot award the settled chest twice').toBe(walletAfterHome);
    await rendered(page);
    await page.screenshot({ path: info.outputPath(`${mode}-fresh-round-after-home.png`), scale: 'css' });
    expect((await savedPairProgress(page)).counts, 'Returning to the mode cannot claim the saved fragment twice').toEqual(expectedCounts);
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

test('Voice Pop saves its upgraded chest, celebrates, and offers the exact unopened reward', async ({ page, browserName }, info) => {
  test.setTimeout(240000);
  const requests = watchAudioRequests(page);
  await installSpeech(page);
  await installPerformanceCapture(page, browserName === 'chromium');
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
  const observation = await savePerformance(page, info, 'pop');
  expect(observation.started.value).toMatchObject({ chest_count: 1, chest_tier: 2, chest_announced: true });
  expect(observation.ready.at - observation.started.at, 'The reward waits for the full Pip performance').toBeGreaterThanOrEqual(2850);
  expect(observation.ended, 'The performance hands off without another click').toBeTruthy();
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

for (const mode of ['jelly', 'word_jelly']) {
  test(`${mode} earns a chest through real play and presents it after Pip moves aside`, async ({ page, browserName }, info) => {
    test.setTimeout(240000);
    const requests = watchAudioRequests(page);
    await installPerformanceCapture(page, browserName === 'chromium');
    const errors = await openGame(page, { reducedMotion: 'no-preference', mode });
    await observeCelebration(page);
    const earned = await finishJelly(page);
    expect(earned).toMatchObject({ chest_count: 1, chest_tier: 1 });
    await expect.poll(() => page.locator('#jelly-reward-status').evaluate(element => {
      const room = JSON.parse(element.dataset.snapshot || '{}');
      return { visible: room.visible, count: room.chest_count, opened: room.opened_count,
        tier: room.chests[0]?.tier, score: room.result_context?.score };
    }), { timeout: 15000 }).toEqual({ visible: true, count: 1, opened: 0, tier: 1, score: earned.score });
    const observation = await savePerformance(page, info, mode);
    expect(observation.started.value).toMatchObject({ chest_count: 1, chest_tier: 1, chest_announced: true, score: earned.score });
    expect(observation.started.value.summary, 'The earned score remains readable during the performance').not.toBe('');
    expect(observation.ready.at - observation.started.at, 'The reward waits for the complete presentation').toBeGreaterThanOrEqual(2850);
    expect(observation.ended).toBeTruthy();
    const room = await page.locator('#jelly-reward-status').evaluate(element => JSON.parse(element.dataset.snapshot));
    for (const [index, value] of room.pip_rect.entries()) {
      expect(value, 'Pip retains its final geometry across the reward handoff').toBeCloseTo(observation.lastActive.pip_rect[index], 0);
    }
    expect(await page.evaluate(() => localStorage.getItem('growWithPip.jellyRewards.v1'))).toContain(earned.round_id);
    await page.screenshot({ path: info.outputPath(`${mode}-earned-chest-handoff.png`), scale: 'css' });
    expect(requests, 'The performance uses bundled media').toEqual([]);
    expect(errors).toEqual([]);
  });
}
