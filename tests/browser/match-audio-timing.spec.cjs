const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap, boardPoint, rendered } = require('./game-ui.cjs');
const { watchAudioRequests, observeOutputAudio, expectRecording } = require('./bundled-audio.cjs');
const catalog = require('../../words.json');

test.use({ deviceScaleFactor: 1,
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

test('Match clicks start their cue and pronunciation before publishing the selected card', async ({ page, context, browserName }, info) => {
  const requests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  const errors = await openGame(page, { reducedMotion: 'no-preference' });
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available).toBe(true);
  test.skip(!available, 'This browser runtime has no WebAudio.');
  await page.evaluate(() => {
    const status = document.querySelector('#selection-status');
    const text = Object.getOwnPropertyDescriptor(Node.prototype, 'textContent');
    window.matchAudioTiming = { selections: [], pointerUp: 0 };
    document.addEventListener('pointerup', event => {
      if (event.isTrusted && event.target.id === 'canvas') window.matchAudioTiming.pointerUp = performance.now();
    }, { capture: true });
    Object.defineProperty(status, 'textContent', {
      get() { return text.get.call(this); },
      set(value) {
        if (value && value !== text.get.call(this)) window.matchAudioTiming.selections.push({
          text: value, at: performance.now(), pointerUp: window.matchAudioTiming.pointerUp,
          sounds: window.audioObservation.playbacks.length
        });
        return text.set.call(this, value);
      }
    });
  });
  const observations = [];
  await context.setOffline(true);
  try {
    // First use and immediate replay of three cards exercise cold and cached
    // resources. The intervening cancel must remain a silent selection change.
    for (const index of [0, 0, 1, 1, 2, 2]) {
      const point = boardPoint(await metrics(page), index);
      const from = await page.evaluate(() => window.audioObservation.playbacks.length);
      await tap(page, point.x, point.y);
      await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
      const published = await page.evaluate(() => window.matchAudioTiming.selections.at(-1));
      const word = catalog.find(entry => entry.text === published.text.split(': ')[1]);
      expect(word).toBeTruthy();
      const cue = await expectRecording(page, from, 'assets/audio/sfx/select.wav');
      const pronunciation = await expectRecording(page, from, word.audio);
      observations.push({ word: word.audio, published, cue, pronunciation });
      const beforeCancel = await page.evaluate(() => window.audioObservation.playbacks.length);
      await tap(page, point.x, point.y);
      await expect(page.locator('#selection-status')).toBeEmpty();
      await rendered(page);
      const cancelled = await page.evaluate(from => window.audioObservation.playbacks.slice(from), beforeCancel);
      expect(cancelled.filter(sound => sound.duration === cue.duration || sound.duration === pronunciation.duration),
        'Cancelling a selection does not replay its cue or word').toEqual([]);
    }
  } finally {
    await context.setOffline(false);
  }
  const timingPath = info.outputPath('match-audio-timing.json');
  fs.writeFileSync(timingPath, JSON.stringify(observations, null, 2));
  await info.attach('match-audio-timing.json', { path: timingPath, contentType: 'application/json' });
  expect(observations).toHaveLength(6);
  for (const { published, cue, pronunciation } of observations) {
    expect(published.pointerUp, 'The measurement follows a trusted card gesture').toBeGreaterThan(0);
    for (const sound of [cue, pronunciation]) {
      expect(sound.at, 'Start accepted card audio before the full interface refresh publishes its selection').toBeLessThanOrEqual(published.at);
      expect(sound.at).toBeGreaterThanOrEqual(published.pointerUp);
    }
    expect(cue.peak, 'The actual click cue contains audible samples').toBeGreaterThan(0.01);
  }
  expect(requests, 'Cold and repeated Match clicks need no audio download').toEqual([]);
  expect(errors).toEqual([]);
});
