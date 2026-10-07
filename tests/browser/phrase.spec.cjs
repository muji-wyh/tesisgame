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

async function press(page, control) {
  expect(control, 'The game publishes the requested control').toBeTruthy();
  expect(control.visible, `${control.name} is visible`).toBe(true);
  expect(control.disabled, `${control.name} accepts input`).toBe(false);
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function pressAction(page) {
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
  expect(state).toMatchObject({ phase: 'building', completed: 0, question_index: 0 });
  expect(state.question.level).toBe('basic');
  expect(state.target_ids.length).toBeGreaterThanOrEqual(2);
  expect(state.options).toHaveLength(state.target_ids.length + 2);
  const saved = await savedMedals(page), baseline = await pieceCount(page);
  const questionIds = [state.id];
  if (audioAvailable) {
    await expectRecording(page, introFrom, 'assets/audio/voice/phrase-intro.wav');
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
      await expectRecording(page, from, 'assets/audio/voice/phrase-try-again.wav');
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
  await pressAction(page);
  await expect.poll(async () => (await phraseState(page)).phase).toBe('correct');
  state = await phraseState(page);
  expect(state).toMatchObject({ completed: 1, question_index: 0, action: { text: 'Continue' } });
  expect(state.transcript.disabled, 'The completed phrase has no ineffective transcript toggle').toBe(true);
  expect(state.transcript.text).toMatch(/^(Phrase shown|Shown)$/);
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
  expect(state.transcript.disabled, 'The next question restores the transcript helper').toBe(false);
  const nextTranscript = state.transcript_visible;
  await press(page, state.transcript);
  await expect.poll(async () => (await phraseState(page)).transcript_visible).toBe(!nextTranscript);
  await press(page, (await phraseState(page)).transcript);
  await expect.poll(async () => (await phraseState(page)).transcript_visible).toBe(nextTranscript);
  await solve(page);
  expect(await savedMedals(page), 'Two phrases still leave the reward unclaimed').toBe(saved);
  await pressAction(page);
  await expect.poll(async () => (await phraseState(page)).question_index).toBe(2);
  state = await phraseState(page);
  questionIds.push(state.id);
  expect(new Set(questionIds).size, 'A round asks three distinct questions').toBe(3);
  await solve(page);
  state = await phraseState(page);
  expect(state).toMatchObject({ phase: 'correct', completed: 3, action: { text: 'Open chest' } });
  expect(await savedMedals(page), 'The third answer waits for the explicit chest transition').toBe(saved);
  await capture(page, info, 'phrase-three-complete');
  const completionFrom = await audioMark();
  await pressAction(page);
  await expect(page.locator('#game-status')).toContainText('Hold to open your chest');
  await expect.poll(async () => (await phraseState(page)).visible).toBe(false);
  if (audioAvailable) await expectRecording(page, completionFrom, 'assets/audio/voice/phrase-complete.wav');
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
  await expect.poll(async () => (await phraseState(page)).transcript_visible).toBe(true);
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
  for (const size of [{ width: 1366, height: 768 }, { width: 390, height: 844 }, { width: 844, height: 390 }, { width: 320, height: 320 }]) {
    await page.setViewportSize(size);
    await expect.poll(async () => {
      const bounds = await metrics(page), current = await phraseState(page);
      const controls = [...(current.options || []), ...(current.answers || []), current.listen, current.action, current.clear, current.transcript].filter(control => control?.visible);
      return controls.length >= 9 && controls.every(({ rect: [x, y, width, height] }) =>
        x >= -1 && y >= -1 && x + width <= bounds.width + 1 && y + height <= bounds.height + 1 &&
        width * bounds.scale >= 43.5 && height * bounds.scale >= 43.5);
    }, { message: `Every phrase target fits and remains at least 44 CSS pixels at ${size.width}x${size.height}` }).toBe(true);
    state = await phraseState(page);
    expect(progress(state), 'Resizing preserves the phrase and its partially assembled answer').toEqual(selected);
    expect(state.transcript_visible, 'Muted learners can read the target phrase at every size').toBe(true);
    const visible = [...state.options, ...state.answers, state.listen, state.action, state.clear, state.transcript].filter(control => control.visible);
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
  expect((await phraseState(page)).transcript).toMatchObject({ disabled: true, text: 'Shown' });
  await capture(page, info, 'phrase-320x320-correct', { afterResize: true });
  expect(await savedMedals(page)).toBe(saved);
  expect(errors).toEqual([]);
});
