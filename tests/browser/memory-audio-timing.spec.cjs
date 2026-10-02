const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, memoryMetrics, memoryPoint, tap, rendered } = require('./game-ui.cjs');
const { watchAudioRequests, observeOutputAudio, expectRecording } = require('./bundled-audio.cjs');
const catalog = require('../../words.json');

const REVEAL = /^Memory card (\d+)\. (Word|Picture): ([a-z]+)\.$/;

test.use({ deviceScaleFactor: 1,
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

test('Memory reveals start their cue and word before selection publication, including a wrong second card', async ({ page, context, browserName }, info) => {
  const requests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  const errors = await openGame(page, { mode: 'memory', reducedMotion: 'no-preference' });
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  test.skip(!available, 'This browser runtime has no WebAudio.');
  await page.evaluate(() => {
    const status = document.querySelector('#selection-status');
    const text = Object.getOwnPropertyDescriptor(Node.prototype, 'textContent');
    window.memoryAudioTiming = { selections: [], statuses: [], pointerUp: 0 };
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
    Object.defineProperty(document.querySelector('#game-status'), 'textContent', {
      get() { return text.get.call(this); },
      set(value) {
        window.memoryAudioTiming.statuses.push({ text: value, at: performance.now() });
        return text.set.call(this, value);
      }
    });
  });
  const observations = [], cards = [];
  const bounds = await memoryMetrics(page);
  const cardTap = async index => {
    const point = memoryPoint(bounds, index);
    await tap(page, point.x, point.y);
  };
  const reveal = async index => {
    const { from, selectionCount } = await page.evaluate(() => ({
      from: window.audioObservation.playbacks.length, selectionCount: window.memoryAudioTiming.selections.length
    }));
    await cardTap(index);
    await expect.poll(() => page.evaluate(() => window.memoryAudioTiming.selections.length)).toBeGreaterThan(selectionCount);
    const published = await page.evaluate(index => window.memoryAudioTiming.selections[index], selectionCount);
    expect(published.text).toMatch(REVEAL);
    const [, position, kind, text] = published.text.match(REVEAL);
    expect(Number(position)).toBe(index + 1);
    const word = catalog.find(entry => entry.text === text);
    expect(word).toBeTruthy();
    const cue = await expectRecording(page, from, 'assets/audio/sfx/select.wav');
    const pronunciation = await expectRecording(page, from, word.audio);
    observations.push({ index, word: word.audio, published, cue, pronunciation });
    return { index, kind, word: text };
  };
  const cancel = async index => {
    const from = await page.evaluate(() => window.audioObservation.playbacks.length);
    await cardTap(index);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await rendered(page);
    expect(await page.evaluate(from => window.audioObservation.playbacks.slice(from).filter(sound => !sound.loop), from),
      'Concealing a card must not replay its cue or pronunciation').toEqual([]);
  };
  await context.setOffline(true);
  try {
    // Six discoveries guarantee both card kinds and a mismatched pair, without
    // reading hidden game state. A repeat also exercises cached pronunciation.
    for (const index of [0, 1, 2, 3, 4, 5, 0]) {
      const card = await reveal(index);
      if (index === cards.length) cards.push(card);
      await cancel(index);
    }
    const first = cards.find(card => card.kind === 'Word' && cards.some(other => other.kind === 'Picture' && other.word !== card.word));
    const wrong = cards.find(card => card.kind === 'Picture' && card.word !== first.word);
    expect(wrong).toBeTruthy();
    await reveal(first.index);
    const beforeWrong = await page.evaluate(() => window.audioObservation.playbacks.length);
    await reveal(wrong.index);
    await expectRecording(page, beforeWrong, 'assets/audio/sfx/wrong.wav');
    expect(await page.evaluate(() => window.memoryAudioTiming.statuses.some(status => status.text.includes('Try another pair.')))).toBe(true);
    await expect(page.locator('#selection-status')).toBeEmpty();
    await expect(page.locator('#game-status')).toContainText('1 attempts.');
  } finally {
    await context.setOffline(false);
  }
  const timingPath = info.outputPath('memory-audio-timing.json');
  fs.writeFileSync(timingPath, JSON.stringify(observations, null, 2));
  await info.attach('memory-audio-timing.json', { path: timingPath, contentType: 'application/json' });
  expect(observations).toHaveLength(9);
  for (const { published, cue, pronunciation } of observations) {
    expect(published.pointerUp, 'The measurement follows a trusted card gesture').toBeGreaterThan(0);
    for (const sound of [cue, pronunciation]) {
      expect(sound.at, 'Start reveal audio before publishing its selection').toBeLessThanOrEqual(published.at);
      expect(sound.at).toBeGreaterThanOrEqual(published.pointerUp);
    }
    expect(cue.peak, 'The actual reveal cue contains audible samples').toBeGreaterThan(0.01);
  }
  expect(requests, 'First and repeated Memory reveals need no audio download').toEqual([]);
  expect(errors).toEqual([]);
});
