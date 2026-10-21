const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, rendered } = require('./game-ui.cjs');
const { memoryState, startObservation, startMatching, memoryCardTap, waitForMemoryInput, memoryPairs } = require('./memory-flow.cjs');
const { watchAudioRequests, observeOutputAudio, expectRecording, recordingTiming } = require('./bundled-audio.cjs');

test.use({ deviceScaleFactor: 1,
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

test('Memory keeps its concealed first choice silent and synchronizes feedback with the revealed pair', async ({ page, context, browserName }, info) => {
  const requests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  const errors = await openGame(page, { mode: 'memory', reducedMotion: 'no-preference' });
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  test.skip(!available, 'This browser runtime has no WebAudio.');
  const board = await startObservation(page);
  await startMatching(page);
  const theme = await page.locator('html').getAttribute('data-pip-theme');
  const music = recordingTiming(`assets/audio/bgm/${theme}.wav`);
  const nonMusic = sounds => sounds.filter(sound =>
    Math.abs(sound.duration - music.seconds) > music.importAllowance + 1 / sound.sampleRate);
  await page.evaluate(() => {
    const status = document.querySelector('#selection-status');
    const text = Object.getOwnPropertyDescriptor(Node.prototype, 'textContent');
    window.memoryAudioTiming = { selections: [], frames: [], pointerUp: 0 };
    const growth = document.querySelector('#growth-status');
    new MutationObserver(() => {
      const memory = JSON.parse(growth.dataset.view || '{}').memory;
      if (memory) window.memoryAudioTiming.frames.push({ at: performance.now(), phase: memory.phase,
        faces: memory.cards.filter(card => card.face_up).map(card => card.index) });
    }).observe(growth, { attributes: true, attributeFilter: ['data-view'] });
    document.addEventListener('pointerup', event => {
      if (event.isTrusted && event.target.id === 'canvas') window.memoryAudioTiming.pointerUp = performance.now();
    }, { capture: true });
    Object.defineProperty(status, 'textContent', {
      get() { return text.get.call(this); },
      set(value) {
        if (value && value !== text.get.call(this)) window.memoryAudioTiming.selections.push({
          text: value, at: performance.now(), pointerUp: window.memoryAudioTiming.pointerUp,
          sounds: window.audioObservation.playbacks.length
        });
        return text.set.call(this, value);
      }
    });
  });
  const audioCount = () => page.evaluate(() => window.audioObservation.playbacks.length);
  const silentFirst = async index => {
    const from = await audioCount();
    await memoryCardTap(page, index);
    await expect(page.locator('#selection-status')).toHaveText(`Memory card ${index + 1} selected. Choose one more card.`);
    await rendered(page);
    expect((await memoryState(page)).cards[index]).toMatchObject({ selected: true, face_up: false, word_id: '' });
    expect(nonMusic(await page.evaluate(from => window.audioObservation.playbacks.slice(from), from)),
      'Selecting a concealed card never pronounces its hidden answer').toEqual([]);
  };
  const observations = [];
  const revealPair = async (firstIndex, index, correct) => {
    const from = await audioCount();
    const selectionCount = await page.evaluate(() => window.memoryAudioTiming.selections.length);
    await memoryCardTap(page, index);
    await expect.poll(() => page.evaluate(() => window.memoryAudioTiming.selections.length)).toBeGreaterThan(selectionCount);
    const published = await page.evaluate(index => window.memoryAudioTiming.selections[index], selectionCount);
    expect(published.text).toMatch(/^Two cards revealed\./);
    const cue = await expectRecording(page, from, `assets/imported-audio/pair-feedback/${correct ? 'right' : 'wrong'}.wav`);
    const revealed = await page.evaluate(({ since, index }) => window.memoryAudioTiming.frames.find(frame =>
      frame.at >= since && frame.phase === 'feedback' && frame.faces.includes(index)), { since: published.pointerUp, index });
    expect(revealed, 'The transient published feedback shows both selected faces together').toBeTruthy();
    expect(revealed.faces).toEqual([firstIndex, index].sort((a, b) => a - b));
    observations.push({ firstIndex, index, correct, published, cue, revealed });
    await waitForMemoryInput(page);
  };
  await context.setOffline(true);
  try {
    const first = board.find(card => card.kind === 'word');
    const wrong = board.find(card => card.kind === 'image' && card.word !== first.word);
    await silentFirst(first.index);
    const beforeCancel = await audioCount();
    await memoryCardTap(page, first.index);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await rendered(page);
    expect(nonMusic(await page.evaluate(from => window.audioObservation.playbacks.slice(from), beforeCancel)),
      'Cancelling the first choice is silent').toEqual([]);
    await silentFirst(first.index);
    await revealPair(first.index, wrong.index, false);
    const pair = memoryPairs(board).find(pair => pair.includes(first.index));
    await silentFirst(pair[0]);
    await revealPair(pair[0], pair[1], true);
  } finally {
    await context.setOffline(false);
  }
  const timingPath = info.outputPath('memory-audio-timing.json');
  fs.writeFileSync(timingPath, JSON.stringify(observations, null, 2));
  await info.attach('memory-audio-timing.json', { path: timingPath, contentType: 'application/json' });
  expect(observations).toHaveLength(2);
  for (const { published, cue } of observations) {
    expect(published.pointerUp, 'The measurement follows a trusted second-card gesture').toBeGreaterThan(0);
    expect(cue.at, 'Pair feedback starts before publishing the revealed pair').toBeLessThanOrEqual(published.at);
    expect(cue.at).toBeGreaterThanOrEqual(published.pointerUp);
    expect(cue.peak, 'The real feedback cue contains audible samples').toBeGreaterThan(0.01);
  }
  expect(requests, 'Memory feedback uses bundled audio without external media requests').toEqual([]);
  expect(errors).toEqual([]);
});
