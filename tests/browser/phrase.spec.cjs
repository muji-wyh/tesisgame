const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const {
  openGame, chooseMode, openModeMenu, openRewards, metrics, tap, rendered,
  ageControl, collectionHeaderRect, resultPoint, visibleColorCount
} = require('./game-ui.cjs');
const { observeOutputAudio, watchAudioRequests, expectRecording } = require('./bundled-audio.cjs');

const MEDAL_KEY = 'wordBuddies.medalProgress';

async function phraseState(page) {
  return page.locator('#game-status').evaluate(element => JSON.parse(element.dataset.phrase || '{}'));
}

function progress(state) {
  return {
    id: state.id, target_ids: state.target_ids, answer: state.answer, phase: state.phase,
    completed: state.completed, question_index: state.question_index, mistakes: state.mistakes
  };
}

function expectFirstCandidateRow(state) {
  const [, top, , bankHeight] = state.bank.rect;
  const candidates = state.options.filter(option => option.visible);
  expect(candidates.length, 'The untouched first question has available candidates').toBeGreaterThan(0);
  for (let index = 0; index < candidates.length; index++) {
    const option = candidates[index], [x, y, , height] = option.rect;
    expect(y, `First-render ${option.text} begins inside the bank`).toBeGreaterThanOrEqual(top - 0.5);
    expect(y + height, `First-render ${option.text} is not clipped below the bank`).toBeLessThanOrEqual(top + bankHeight + 0.5);
    if (index > 0) {
      const previous = candidates[index - 1];
      expect(previous.rect[0] + previous.rect[2], `First-render ${previous.text} and ${option.text} have a visible gap`)
        .toBeLessThanOrEqual(x - 0.5);
    }
  }
}

function promptFullyVisible(state) {
  if (!state.visible || !state.prompt_text_visible || !state.listen?.visible) return true;
  const layout = state.prompt_layout;
  return Boolean(layout?.shown && layout.text === state.text && layout.line_count >= 1 && layout.line_count <= 2 &&
    layout.visible_line_count === layout.line_count);
}

function expectPromptFullyVisible(state) {
  if (!state.visible || !state.prompt_text_visible || !state.listen?.visible) return;
  expect(state.prompt_layout, 'The full prompt has measured layout information').toBeTruthy();
  expect(state.prompt_layout.shown).toBe(true);
  expect(state.prompt_layout.text, 'The displayed prompt retains the full target phrase').toBe(state.text);
  expect(state.prompt_layout.line_count, 'The prompt occupies at least one line').toBeGreaterThanOrEqual(1);
  expect(state.prompt_layout.line_count, 'The compact prompt fits at most two lines').toBeLessThanOrEqual(2);
  expect(state.prompt_layout.visible_line_count, 'Every line, including the final word, is actually visible')
    .toBe(state.prompt_layout.line_count);
}

async function press(page, control) {
  expect(control, 'The game publishes the requested control').toBeTruthy();
  expect(control.visible, `${control.name} is visible`).toBe(true);
  expect(control.disabled, `${control.name} accepts input`).toBe(false);
  if (control.word_id) control = await revealOption(page, control.word_id);
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function revealOption(page, wordId) {
  for (let attempt = 0; attempt < 24; attempt++) {
    const state = await phraseState(page);
    const option = state.options.find(item => item.word_id === wordId);
    expect(option?.visible, `Candidate ${wordId} remains available`).toBe(true);
    const [x, , width] = option.rect, [left, top, bankWidth, bankHeight] = state.bank.rect;
    if (x >= left - 0.5 && x + width <= left + bankWidth + 0.5) return option;
    const direction = x < left ? -1 : 1;
    const bounds = await metrics(page);
    const centerX = bounds.x + (left + bankWidth / 2) * bounds.scale;
    const centerY = bounds.y + (top + bankHeight / 2) * bounds.scale;
    await page.mouse.move(centerX, centerY);
    if (page.context().browser().browserType().name() === 'webkit') {
      // Mobile WebKit has no wheel automation; exercise the bank's drag gesture.
      await page.mouse.down();
      try { await page.mouse.move(centerX - direction * 80, centerY, { steps: 6 }); }
      finally { await page.mouse.up(); }
    } else {
      await page.mouse.wheel(0, direction * 80);
    }
    await rendered(page);
  }
  throw new Error(`Scrolling could not reveal candidate ${wordId}`);
}

async function pressAction(page) {
  await expect.poll(async () => {
    const action = (await phraseState(page)).action;
    return Boolean(action?.visible && !action.disabled);
  }, { message: 'The phrase action is available after any Pip celebration' }).toBe(true);
  await press(page, (await phraseState(page)).action);
}

async function selectWords(page, ids) {
  for (const id of ids) {
    const state = await phraseState(page);
    const option = state.options.find(item => item.word_id === id);
    await press(page, option);
    await expect.poll(async () => (await phraseState(page)).answer).toEqual([...state.answer, option.index]);
  }
}

async function solve(page) {
  const state = await phraseState(page);
  await selectWords(page, state.target_ids);
  await pressAction(page);
  await expect.poll(async () => (await phraseState(page)).phase).toBe('correct');
  await expect.poll(async () => (await phraseState(page)).completed).toBe(state.completed + 1);
}

async function libraryAction(page, name) {
  const state = (await metrics(page)).library;
  const control = state.controls.find(item => item.name === name);
  expect(control, `The library exposes ${name}`).toBeTruthy();
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function roomBack(page) {
  const rect = collectionHeaderRect(await metrics(page), 'back');
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await rendered(page);
}

async function chooseAge(page, id) {
  await openRewards(page);
  const rect = await ageControl(page, id);
  await tap(page, rect.x + rect.width / 2, rect.y + rect.height / 2);
  await expect(page.locator('#game-status')).toContainText(id === '4-6' ? 'Ages 4-6.' : 'Ages 10+.');
  await roomBack(page);
  await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
  await roomBack(page);
}

async function savedMedals(page) {
  return page.evaluate(key => localStorage.getItem(key), MEDAL_KEY);
}

async function pieceCount(page) {
  const saved = await savedMedals(page) || '';
  return [...saved.matchAll(/"[a-z]+-\d+"\s*:\s*(\d+)/g)].reduce((total, match) => total + Number(match[1]), 0);
}

async function capture(page, info, name, { afterResize = false } = {}) {
  await page.mouse.move(0, 0);
  await rendered(page);
  expectPromptFullyVisible(await phraseState(page));
  const pagePng = await page.screenshot({ path: info.outputPath(`${name}.png`), scale: 'css' });
  const raw = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
  const canvasPng = Buffer.from(raw, 'base64');
  fs.writeFileSync(info.outputPath(`${name}-canvas.png`), canvasPng);
  fs.writeFileSync(info.outputPath(`${name}-state.json`), JSON.stringify(await phraseState(page), null, 2));
  expect(await visibleColorCount(page, canvasPng), `${name} renders the actual game`).toBeGreaterThan(20);
  const colors = await visibleColorCount(page, pagePng);
  if (afterResize && colors === 1 && process.platform === 'win32' && info.project.use.browserName === 'webkit') {
    info.annotations.push({ type: 'rendering-limitation', description: `${name}: Windows WebKit presents a blank page after resizing while the raw canvas renders; both captures retained.` });
  } else expect(colors, `${name} is visible on the page`).toBeGreaterThan(20);
}

async function observeCelebration(page) {
  await page.evaluate(() => {
    const status = document.getElementById('game-status'), canvas = document.getElementById('canvas');
    const observation = { started: null, finished: null, frame: null };
    window.phraseCelebrationObservation = observation;
    const readState = () => JSON.parse(status.dataset.phrase || '{}');
    let frameRequest = 0;
    const observer = new MutationObserver(() => {
      const state = readState();
      if (!observation.started && state.celebrating) {
        observation.started = state;
        // Sample a rendered frame in the page before browser-control latency can miss it.
        frameRequest = requestAnimationFrame(() => {
          frameRequest = requestAnimationFrame(() => {
            const frameState = readState();
            if (frameState.celebrating && frameState.id === observation.started.id) {
              observation.frame = { state: frameState, raw: canvas.toDataURL('image/png').split(',')[1] };
            }
          });
        });
      } else if (observation.started && !state.celebrating) {
        observation.finished = state;
        cancelAnimationFrame(frameRequest);
        observer.disconnect();
      }
    });
    observer.observe(status, { attributes: true, attributeFilter: ['data-phrase'] });
  });
}

async function expectCelebration(page, info, name, actionText) {
  await expect.poll(() => page.evaluate(() => Boolean(window.phraseCelebrationObservation?.finished)),
    { message: 'The in-page observer records Pip finishing the happy reaction naturally' }).toBe(true);
  const { started, finished, frame } = await page.evaluate(() => window.phraseCelebrationObservation);
  expect(started, `${actionText} waits for Pip's celebration`).toMatchObject({
    phase: 'correct', celebrating: true, action: { text: actionText, disabled: true }
  });
  expect(finished, `Pip's natural completion enables ${actionText}`).toMatchObject({
    phase: 'correct', celebrating: false, action: { text: actionText, disabled: false }
  });
  expect(progress(finished), 'Completing the celebration cannot advance the question').toEqual(progress(started));
  expect(frame, 'The in-page observer captures a rendered celebration frame').toBeTruthy();
  expect(frame.state).toMatchObject({
    id: started.id, phase: 'correct', celebrating: true, action: { text: actionText, disabled: true }
  });
  const canvasPng = Buffer.from(frame.raw, 'base64');
  fs.writeFileSync(info.outputPath(`${name}-canvas.png`), canvasPng);
  fs.writeFileSync(info.outputPath(`${name}-state.json`), JSON.stringify(frame.state, null, 2));
  fs.writeFileSync(info.outputPath(`${name}-lifecycle.json`), JSON.stringify({ started, finished }, null, 2));
  expect(await visibleColorCount(page, canvasPng), `${name} renders the actual game`).toBeGreaterThan(20);
  expect(progress(await phraseState(page)), 'The correct answer still waits for an explicit action').toEqual(progress(finished));
  return finished;
}

async function observeRoundCelebration(page) {
  await page.evaluate(() => {
    const status = document.getElementById('game-status'), canvas = document.getElementById('canvas');
    const observation = { started: null, finished: null, frame: null, startedAt: null, finishedAt: null, chestAt: null };
    window.phraseRoundCelebrationObservation = observation;
    const readState = () => JSON.parse(status.dataset.phrase || '{}');
    const observer = new MutationObserver(() => {
      const state = readState();
      if (!observation.started && state.round_celebrating) {
        observation.started = state;
        observation.startedAt = performance.now();
        // Capture the large Pip in motion inside the page, independent of driver latency.
        setTimeout(() => requestAnimationFrame(() => {
          const frameState = readState();
          if (frameState.round_celebrating && frameState.id === observation.started.id) {
            observation.frame = { state: frameState, status: status.textContent,
              raw: canvas.toDataURL('image/png').split(',')[1] };
          }
        }), 550);
      }
      if (observation.started && observation.chestAt === null && status.textContent.includes('Hold to open your chest')) {
        observation.chestAt = performance.now();
      }
      if (observation.started && state.completion_ready) {
        observation.finished = state;
        observation.finishedAt = performance.now();
        observer.disconnect();
      }
    });
    observer.observe(status, { attributes: true, attributeFilter: ['data-phrase'], childList: true, characterData: true, subtree: true });
  });
}

async function expectRoundCelebration(page, info, name) {
  await expect.poll(() => page.evaluate(() => Boolean(window.phraseRoundCelebrationObservation?.finished)),
    { message: 'The final celebration enables Open chest after Pip and the final phrase finish', timeout: 15000 }).toBe(true);
  const observation = await page.evaluate(() => window.phraseRoundCelebrationObservation);
  const { started, finished, frame, startedAt, finishedAt, chestAt } = observation;
  expect(started).toMatchObject({ phase: 'correct', completed: 3, round_celebrating: true, completion_animation_done: false });
  expect(finished).toMatchObject({ phase: 'correct', completed: 3, round_celebrating: true,
    completion_ready: true, celebrating: false, action: { text: 'Open chest', visible: true, disabled: false } });
  expect(finishedAt - startedAt, 'The round celebration has its own readable interval').toBeGreaterThanOrEqual(2450);
  expect(chestAt, 'The chest cannot open before the learner accepts the invitation').toBeNull();
  expect(frame, 'The in-page observer captures the distinct completion stage').toBeTruthy();
  expect(frame.state).toMatchObject({ phase: 'correct', completed: 3, round_celebrating: true });
  expect(frame.state.action).toMatchObject({ text: 'Open chest', visible: true, disabled: true });
  for (const control of [...frame.state.options, ...frame.state.answers, frame.state.listen]) {
    expect(control.visible, `Completion hides ${control.name}`).toBe(false);
    expect(control.disabled, `Completion disables ${control.name}`).toBe(true);
  }
  const canvasPng = Buffer.from(frame.raw, 'base64');
  fs.writeFileSync(info.outputPath(`${name}-canvas.png`), canvasPng);
  fs.writeFileSync(info.outputPath(`${name}-state.json`), JSON.stringify(frame.state, null, 2));
  fs.writeFileSync(info.outputPath(`${name}-lifecycle.json`), JSON.stringify({ started, finished, startedAt, finishedAt, chestAt }, null, 2));
  expect(await visibleColorCount(page, canvasPng), `${name} renders Pip's actual completion stage`).toBeGreaterThan(20);
  return observation;
}

function center([x, y, width, height]) {
  return { x: x + width / 2, y: y + height / 2 };
}

async function cardPointer(page, input) {
  const client = input === 'touch' ? await page.context().newCDPSession(page) : null;
  let held = false, position;
  const cssPoint = async point => {
    const bounds = await metrics(page);
    return { x: bounds.x + point.x * bounds.scale, y: bounds.y + point.y * bounds.scale };
  };
  return {
    async down(point) {
      position = await cssPoint(point);
      if (client) await client.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 1, ...position }] });
      else { await page.mouse.move(position.x, position.y); await page.mouse.down(); }
      held = true;
      await rendered(page);
    },
    async move(point) {
      const destination = await cssPoint(point), start = position;
      for (let step = 1; step <= 4; step++) {
        position = { x: start.x + (destination.x - start.x) * step / 4, y: start.y + (destination.y - start.y) * step / 4 };
        if (client) await client.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ id: 1, ...position }] });
        else await page.mouse.move(position.x, position.y);
        await rendered(page);
      }
    },
    async up({ cancel = false } = {}) {
      if (!held) return;
      if (client) await client.send('Input.dispatchTouchEvent', { type: cancel ? 'touchCancel' : 'touchEnd', touchPoints: [] });
      else await page.mouse.up();
      held = false;
      await rendered(page);
    },
    async dispose() {
      if (held) {
        if (client) await client.send('Input.dispatchTouchEvent', { type: 'touchCancel', touchPoints: [] });
        else await page.mouse.up();
      }
      if (client) await client.detach();
    }
  };
}

async function liftBankCard(page, pointer, wordId) {
  const source = await revealOption(page, wordId), start = center(source.rect);
  await pointer.down(start);
  await pointer.move({ x: start.x, y: start.y - 24 });
}

async function dragCard(page, pointer, source, destination, { dropKind, dropIndex, cancel = false } = {}) {
  const before = progress(await phraseState(page));
  if (source.word_id) source = await revealOption(page, source.word_id);
  await pointer.down(center(source.rect));
  expect((await phraseState(page)).dragging, 'Pressing a card waits for motion before dragging').toBe(false);
  if (source.word_id) {
    const start = center(source.rect);
    await pointer.move({ x: start.x, y: start.y - 24 });
  }
  await pointer.move(destination);
  await expect.poll(async () => (await phraseState(page)).dragging).toBe(true);
  let state = await phraseState(page);
  expect(state.drag_word).toBeTruthy();
  expect(progress(state), 'A drag preview cannot commit or remove a word before release').toEqual(before);
  if (dropKind !== undefined) expect(state.drop_kind).toBe(dropKind);
  if (dropIndex !== undefined) expect(state.drop_index).toBe(dropIndex);
  await pointer.up({ cancel });
  await expect.poll(async () => (await phraseState(page)).dragging).toBe(false);
  state = await phraseState(page);
  expect(state.drag_word, 'Releasing clears the dragged card preview').toBe('');
  return state;
}

async function setDocumentHidden(page, hidden) {
  await page.evaluate(hidden => {
    if (hidden) Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    else delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  }, hidden);
}

test('Phrase Builder corrects unlimited mistakes, finishes three phrases and opens one saved chest', async ({ page, browserName }, info) => {
  test.setTimeout(240000);
  const requests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  await chooseAge(page, '4-6');
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(audioAvailable, 'Chromium provides the actual WebAudio playback path').toBe(true);
  if (!audioAvailable) info.annotations.push({ type: 'audio-limitation', description: 'This browser runtime has no WebAudio; native audio tests and Chromium verify the recordings. Gameplay and muted text fallback remain covered here.' });
  const audioMark = () => page.evaluate(() => window.audioObservation.playbacks.length);
  const introFrom = await audioMark();
  await chooseMode(page, 'phrase');
  await expect.poll(async () => (await phraseState(page)).visible).toBe(true);
  let state = await phraseState(page);
  expectFirstCandidateRow(state);
  expect(state).toMatchObject({ phase: 'building', completed: 0, question_index: 0 });
  expect(state.question.level).toBe('basic');
  expect(state.target_ids.length).toBeGreaterThanOrEqual(2);
  expect(state.options).toHaveLength(state.target_ids.length + 2);
  expect(state.prompt_text_visible, 'Unavailable audio reveals the written phrase in the waveform automatically').toBe(!audioAvailable);
  expect(state.transcript, 'The waveform replaces the separate eye control').toBeUndefined();
  expect(state.progress).toMatchObject({ value: 0, total: 3, visible: true });
  expect(state.answers.every(answer => answer.text === ''), 'The answer line has no numbered placeholders').toBe(true);
  const replayFrom = await audioMark();
  await press(page, state.listen);
  if (audioAvailable) await expectRecording(page, replayFrom, state.audio);
  const saved = await savedMedals(page), baseline = await pieceCount(page);
  const questionIds = [state.id];
  if (audioAvailable) {
    await expectRecording(page, introFrom, state.audio);
  }
  await capture(page, info, 'phrase-first-question');
  const target = state.target_ids;
  const wordsFrom = await audioMark();
  await selectWords(page, [...target].reverse());
  if (audioAvailable) {
    const word = require('../../words.json').find(entry => entry.id === target.at(-1));
    await expectRecording(page, wordsFrom, word.audio);
    await expectRecording(page, wordsFrom, 'assets/imported-audio/ui-click/select.wav');
  }
  for (let attempt = 1; attempt <= 4; attempt++) {
    const from = await audioMark();
    await pressAction(page);
    await expect.poll(async () => (await phraseState(page)).mistakes).toBe(attempt);
    state = await phraseState(page);
    expect(state).toMatchObject({ phase: 'building', feedback: 'wrong', completed: 0, question_index: 0 });
    expect(state.answers.every(answer => !answer.disabled)).toBe(true);
    expect(await savedMedals(page), 'Wrong answers cannot claim or change rewards').toBe(saved);
    if (audioAvailable && attempt === 4) {
      await expectRecording(page, from, 'assets/imported-audio/pair-feedback/wrong.wav');
    }
  }
  await capture(page, info, 'phrase-four-wrong-attempts');
  while ((await phraseState(page)).answer.length > 1) {
    state = await phraseState(page);
    await press(page, state.answers[0]);
    await expect.poll(async () => (await phraseState(page)).answer.length).toBe(state.answer.length - 1);
  }
  await selectWords(page, target.slice(1));
  const correctedFrom = await audioMark();
  await observeCelebration(page);
  await pressAction(page);
  state = await expectCelebration(page, info, 'phrase-pip-celebration', 'Continue');
  expect(state).toMatchObject({ completed: 1, question_index: 0 });
  expect(state.prompt_text_visible, 'The completed phrase appears inside the waveform').toBe(true);
  expect(state.progress).toMatchObject({ value: 1, total: 3, visible: true });
  if (audioAvailable) {
    await expectRecording(page, correctedFrom, 'assets/imported-audio/pair-feedback/right.wav');
    await expectRecording(page, correctedFrom, state.audio);
  }
  await capture(page, info, 'phrase-corrected-answer');
  expect(await savedMedals(page), 'A correct phrase alone does not claim a chest').toBe(saved);
  await pressAction(page);
  await expect.poll(async () => (await phraseState(page)).question_index).toBe(1);
  state = await phraseState(page);
  questionIds.push(state.id);
  expect(state.answer).toEqual([]);
  expect(state.prompt_text_visible).toBe(!audioAvailable);
  expect(state.progress.value).toBe(1);
  const nextReplayFrom = await audioMark();
  await press(page, state.listen);
  if (audioAvailable) await expectRecording(page, nextReplayFrom, state.audio);
  await solve(page);
  expect(await savedMedals(page), 'Two phrases still leave the reward unclaimed').toBe(saved);
  await pressAction(page);
  await expect.poll(async () => (await phraseState(page)).question_index).toBe(2);
  state = await phraseState(page);
  questionIds.push(state.id);
  expect(new Set(questionIds).size, 'A round asks three distinct questions').toBe(3);
  await selectWords(page, state.target_ids);
  const finalFrom = await audioMark(), finalPhraseAudio = state.audio;
  await observeRoundCelebration(page);
  await pressAction(page);
  const completion = await expectRoundCelebration(page, info, 'phrase-pip-round-celebration');
  expect(await savedMedals(page), 'Completing all three phrases and celebrating leave the chest unclaimed').toBe(saved);
  if (audioAvailable) {
    const recording = await expectRecording(page, finalFrom, finalPhraseAudio);
    expect(completion.finishedAt - recording.at, 'The final phrase finishes before enabling Open chest')
      .toBeGreaterThanOrEqual(recording.duration * 1000 - 100);
    if (recording.stopContextTime !== undefined) {
      expect(recording.stopContextTime - recording.scheduledAt, 'The final reading is not cut off by the transition')
        .toBeGreaterThanOrEqual(recording.duration - 0.1);
    }
  }
  expect(progress(await phraseState(page))).toEqual(progress(completion.finished));
  await capture(page, info, 'phrase-earned-chest-invitation');
  await openModeMenu(page);
  await libraryAction(page, 'LibraryClose');
  await expect.poll(async () => (await phraseState(page)).completion_ready).toBe(true);
  expect((await phraseState(page)).action).toMatchObject({ text: 'Open chest', visible: true, disabled: false });
  expect(progress(await phraseState(page)), 'Closing a menu preserves the ready invitation').toEqual(progress(completion.finished));
  await pressAction(page);
  await expect(page.locator('#game-status')).toContainText('Hold to open your chest');
  await expect.poll(async () => (await phraseState(page)).visible).toBe(false);
  await capture(page, info, 'phrase-earned-chest');
  const bounds = await metrics(page), chest = resultPoint(bounds, 'chest');
  const x = bounds.x + chest.x * bounds.scale, y = bounds.y + chest.y * bounds.scale;
  await page.mouse.click(x, y, { delay: 200 });
  expect(await pieceCount(page), 'An incomplete hold leaves the chest unclaimed').toBe(baseline);
  await page.mouse.move(x, y);
  await page.mouse.down();
  try {
    await expect(page.locator('#game-status')).toHaveText('Chest opened! Ready for another adventure?', { timeout: 15000 });
  } finally { await page.mouse.up(); }
  expect(await pieceCount(page)).toBe(baseline + 1);
  await capture(page, info, 'phrase-opened-chest');
  const next = resultPoint(await metrics(page), 'newAdventure');
  await tap(page, next.x, next.y);
  await expect.poll(async () => (await phraseState(page)).visible).toBe(true);
  await expect.poll(async () => progress(await phraseState(page))).toMatchObject({ completed: 0, question_index: 0, phase: 'building', answer: [], mistakes: 0 });
  expect(await pieceCount(page), 'New adventure cannot award the old chest twice').toBe(baseline + 1);
  await capture(page, info, 'phrase-new-adventure');
  expect(requests, 'Phrase prompts, vocabulary and feedback are bundled in the startup pack').toEqual([]);
  expect(errors).toEqual([]);
});

test('Phrase Builder preserves its answer through overlays, mute, background and responsive layouts', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = await openGame(page);
  await chooseAge(page, '10-plus');
  await chooseMode(page, 'phrase');
  await expect.poll(async () => (await phraseState(page)).visible).toBe(true);
  let state = await phraseState(page);
  expectFirstCandidateRow(state);
  expect(state.question.level).toBe('advanced');
  await selectWords(page, [state.target_ids[0]]);
  const selected = progress(await phraseState(page));
  const saved = await savedMedals(page);
  await openModeMenu(page);
  await expect.poll(async () => (await phraseState(page)).paused).toBe(true);
  expect(progress(await phraseState(page))).toEqual(selected);
  await libraryAction(page, 'LibrarySound');
  await libraryAction(page, 'LibraryClose');
  await expect.poll(async () => (await phraseState(page)).paused).toBe(false);
  await expect.poll(async () => (await phraseState(page)).prompt_text_visible).toBe(true);
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')).muted)).toBe(true);
  await openRewards(page);
  await expect.poll(async () => (await phraseState(page)).paused).toBe(true);
  expect(progress(await phraseState(page))).toEqual(selected);
  await roomBack(page);
  await expect.poll(async () => (await phraseState(page)).visible).toBe(true);
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect.poll(async () => (await phraseState(page)).paused).toBe(true);
  expect(progress(await phraseState(page))).toEqual(selected);
  await page.evaluate(() => {
    delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect.poll(async () => (await phraseState(page)).paused).toBe(false);
  expect(progress(await phraseState(page))).toEqual(selected);
  for (const size of [{ width: 1366, height: 768 }, { width: 390, height: 844 }, { width: 390, height: 500 }, { width: 390, height: 540 }, { width: 844, height: 390 }, { width: 320, height: 568 }, { width: 320, height: 320 }]) {
    await page.setViewportSize(size);
    await expect.poll(async () => {
      const bounds = await metrics(page), current = await phraseState(page);
      const controls = [...(current.answers || []), current.listen, current.action].filter(control => control?.visible);
      return promptFullyVisible(current) && controls.length >= 4 && controls.every(({ rect: [x, y, width, height] }) =>
        x >= -1 && y >= -1 && x + width <= bounds.width + 1 && y + height <= bounds.height + 1 &&
        width * bounds.scale >= 43.5 && height * bounds.scale >= 43.5);
    }, { message: `Every phrase target fits and remains at least 44 CSS pixels at ${size.width}x${size.height}` }).toBe(true);
    state = await phraseState(page);
    expectPromptFullyVisible(state);
    expect(progress(state), 'Resizing preserves the phrase and its partially assembled answer').toEqual(selected);
    expect(state.prompt_text_visible, 'Muted learners can read the target phrase at every size').toBe(true);
    const visible = [...state.options, ...state.answers, state.listen, state.action].filter(control => control.visible);
    expect(state.progress).toMatchObject({ value: 0, total: 3, visible: true });
    const [bankX, bankY, bankWidth, bankHeight] = state.bank.rect;
    const bounds = await metrics(page);
    expect(bankX).toBeGreaterThanOrEqual(-1);
    expect(bankX + bankWidth).toBeLessThanOrEqual(bounds.width + 1);
    expect(bankY + bankHeight).toBeLessThanOrEqual(bounds.height + 1);
    expect(Math.abs(state.action.rect[0] + state.action.rect[2] - bankX - bankWidth), 'Check answer aligns with the right edge').toBeLessThanOrEqual(1);
    const candidates = state.options.filter(control => control.visible);
    expect(new Set(candidates.map(control => control.rect[1])).size, 'Candidates stay on a single row').toBe(1);
    for (const option of candidates) {
      expect(option.rect[2] * bounds.scale).toBeGreaterThanOrEqual(43.5);
      expect(option.rect[3] * bounds.scale).toBeGreaterThanOrEqual(43.5);
    }
    for (let first = 0; first < visible.length; first++) for (let second = 0; second < first; second++) {
      const [ax, ay, aw, ah] = visible[first].rect, [bx, by, bw, bh] = visible[second].rect;
      const overlap = Math.min(ax + aw, bx + bw) - Math.max(ax, bx) > 1 && Math.min(ay + ah, by + bh) - Math.max(ay, by) > 1;
      expect(overlap, `${visible[first].name} and ${visible[second].name} must not overlap`).toBe(false);
    }
    await capture(page, info, `phrase-${size.width}x${size.height}`, { afterResize: true });
    await press(page, state.answers[0]);
    await expect.poll(async () => (await phraseState(page)).answer).toEqual([]);
    await selectWords(page, [state.target_ids[0]]);
    expect(progress(await phraseState(page))).toEqual(selected);
  }
  state = await phraseState(page);
  await selectWords(page, state.target_ids.slice(1));
  await pressAction(page);
  await expect.poll(async () => (await phraseState(page)).phase).toBe('correct');
  expect((await phraseState(page)).action.text).toBe('Continue');
  expect((await phraseState(page)).prompt_text_visible).toBe(true);
  expect((await phraseState(page)).progress.value).toBe(1);
  await capture(page, info, 'phrase-320x320-correct', { afterResize: true });
  expect(await savedMedals(page)).toBe(saved);
  expect(errors).toEqual([]);
});

for (const input of ['mouse', 'touch']) test(`Phrase Builder ${input} drags insert, reorder, return and cancel cards without extra clicks`, async ({ page, browserName }, info) => {
  test.setTimeout(300000);
  test.skip(input === 'touch' && browserName !== 'chromium', 'Trusted touch motion and cancellation use Chromium CDP.');
  const errors = await openGame(page);
  await chooseAge(page, '10-plus');
  await chooseMode(page, 'phrase');
  await expect.poll(async () => (await phraseState(page)).visible).toBe(true);
  const pointer = await cardPointer(page, input);
  const saved = await savedMedals(page);
  let state = await phraseState(page);
  expectFirstCandidateRow(state);
  const before = progress(state);
  try {
    state = await dragCard(page, pointer, state.options[0], center(state.answers[0].rect), { dropKind: 'answer', dropIndex: 0 });
    expect(state.answer, 'A released bank card appears in the answer exactly once').toEqual([0]);
    expect(state.options[0].visible, 'The used bank card leaves its original position').toBe(false);
    state = await dragCard(page, pointer, state.options[1], center(state.answers[0].rect), { dropKind: 'answer', dropIndex: 0 });
    expect(state.answer, 'Dropping on an occupied slot inserts before its word').toEqual([1, 0]);
    state = await dragCard(page, pointer, state.answers[1], center(state.answers[0].rect), { dropKind: 'answer', dropIndex: 0 });
    expect(state.answer, 'A selected card can move to an earlier position').toEqual([0, 1]);
    const [x, y, width, height] = state.answer_drop;
    state = await dragCard(page, pointer, state.answers[0], { x: x + width - 2, y: y + height / 2 }, { dropKind: 'answer' });
    expect(state.answer, 'The answer area edge moves a card to the end').toEqual([1, 0]);
    state = await dragCard(page, pointer, state.answers[1], center(state.bank_drop), { dropKind: 'bank' });
    expect(state.answer, 'Returning a card to the bank cannot select it again on release').toEqual([1]);
    expect(state.options[0].visible).toBe(true);
    const partial = progress(state);
    state = await dragCard(page, pointer, state.answers[0], { x: 2, y: 2 }, { dropKind: '' });
    expect(progress(state), 'Dropping outside keeps the selected card in place').toEqual(partial);
    state = await dragCard(page, pointer, state.options[2], { x: 2, y: 2 }, { dropKind: '' });
    expect(progress(state), 'An invalid drop leaves its bank card available').toEqual(partial);
    expect(state.options[2].visible).toBe(true);
    if (input === 'touch') {
      state = await dragCard(page, pointer, state.options[2], center(state.answers[1].rect), { dropKind: 'answer', dropIndex: 1, cancel: true });
      expect(progress(state), 'Touch cancellation never commits the visible drop preview').toEqual(partial);
    }
    await liftBankCard(page, pointer, state.options[2].word_id);
    await pointer.move(center(state.answers[1].rect));
    await expect.poll(async () => (await phraseState(page)).dragging).toBe(true);
    await page.evaluate(type => document.getElementById('canvas').addEventListener(type,
      event => event.stopImmediatePropagation(), { capture: true, once: true }), input === 'touch' ? 'touchend' : 'mouseup');
    await pointer.up();
    await expect.poll(async () => (await phraseState(page)).dragging,
      { message: 'The window release fallback clears a drag when canvas delivery is interrupted' }).toBe(false);
    state = await phraseState(page);
    expect(progress(state), 'A missing canvas release cancels the preview instead of committing an unobserved drop').toEqual(partial);
    await liftBankCard(page, pointer, state.options[2].word_id);
    await pointer.move(center(state.answers[1].rect));
    await expect.poll(async () => (await phraseState(page)).dragging).toBe(true);
    await setDocumentHidden(page, true);
    await expect.poll(async () => (await phraseState(page)).paused).toBe(true);
    expect((await phraseState(page)).dragging, 'Backgrounding clears an active drag').toBe(false);
    await pointer.up();
    expect(progress(await phraseState(page)), 'A release while hidden cannot place the card').toEqual(partial);
    await setDocumentHidden(page, false);
    await expect.poll(async () => (await phraseState(page)).paused).toBe(false);
    state = await phraseState(page);
    expect(progress(state)).toEqual(partial);
    await liftBankCard(page, pointer, state.options[2].word_id);
    await pointer.move(center(state.answers[1].rect));
    await expect.poll(async () => (await phraseState(page)).dragging).toBe(true);
    await page.setViewportSize({ width: 390, height: 844 });
    await expect.poll(async () => (await phraseState(page)).dragging).toBe(false);
    await pointer.up();
    state = await phraseState(page);
    expect(progress(state), 'Resizing cancels a preview without changing the partially assembled phrase').toEqual(partial);
    state = await dragCard(page, pointer, state.answers[0], center(state.bank_drop), { dropKind: 'bank' });
    expect(progress(state)).toEqual(before);
    await press(page, state.options[0]);
    await expect.poll(async () => (await phraseState(page)).answer).toEqual([0]);
    await press(page, (await phraseState(page)).answers[0]);
    await expect.poll(async () => (await phraseState(page)).answer).toEqual([]);
    expect(progress(await phraseState(page)), 'Tap editing remains available after successful and canceled drags').toEqual(before);
    state = await phraseState(page);
    if (state.bank.max_scroll > 0) {
      await revealOption(page, state.options[0].word_id);
      state = await phraseState(page);
      const scrollBefore = state.bank.scroll, bank = center(state.bank.rect);
      await pointer.down(bank);
      await pointer.move({ x: bank.x - 72, y: bank.y + 1 });
      await pointer.up();
      state = await phraseState(page);
      expect(state.bank.scroll, 'A horizontal swipe reveals later candidates').toBeGreaterThan(scrollBefore);
      expect(state.dragging).toBe(false);
      expect(progress(state), 'Swiping the candidate strip never selects a word').toEqual(before);
      const last = state.options.at(-1);
      await press(page, last);
      await expect.poll(async () => (await phraseState(page)).answer).toEqual([last.index]);
      await press(page, (await phraseState(page)).answers[0]);
      expect(progress(await phraseState(page)), 'An offscreen candidate remains selectable after scrolling').toEqual(before);
    }
    expect(await savedMedals(page), 'Editing cards cannot unlock or award a chest').toBe(saved);
    await capture(page, info, `phrase-${input}-drag-edited`, { afterResize: true });
    expect(errors).toEqual([]);
  } finally {
    if (!page.isClosed()) {
      await pointer.dispose();
      if (!page.isClosed()) await setDocumentHidden(page, false);
    }
  }
});
