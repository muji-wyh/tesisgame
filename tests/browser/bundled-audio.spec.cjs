const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { openGame, chooseTheme, metrics, tap, boardPoint } = require('./game-ui.cjs');
const { watchAudioRequests, observeOutputAudio, expectOutputEnergy, expectRecording, waveDuration } = require('./bundled-audio.cjs');
const catalog = require('../../words.json');

// Keep Chromium's normal autoplay policy. A trusted Enter/card gesture must
// unlock actual game audio without an autoplay-permission launch flag.
test.use({ launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

test.beforeAll(() => {
  const html = fs.readFileSync(path.resolve(__dirname, '../../build/web/index.html'), 'utf8');
  const config = JSON.parse(html.match(/const config = (\{[^\r\n]*\});/)[1]);
  expect(config, 'A ready build includes game audio in the pack').not.toHaveProperty('audioAssets');
});

async function requireAudio(page, browserName) {
  const available = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(available, 'Chromium exercises real WebAudio').toBe(true);
  test.skip(!available, 'This browser runtime has no WebAudio; gameplay without audio is covered separately.');
}

async function suspendGameAudio(page) {
  const count = await page.evaluate(async () => {
    window.suspendedGameAudio = window.audioObservation.contexts.filter(context => ['running', 'suspended'].includes(context.state));
    await Promise.all(window.suspendedGameAudio.map(context => context.suspend()));
    return window.suspendedGameAudio.length;
  });
  expect(count, 'Suspend an existing real context, not a simulated state').toBeGreaterThan(0);
  await expect.poll(() => page.evaluate(() => window.suspendedGameAudio.every(context => context.state === 'suspended'))).toBe(true);
}

async function expectOriginalContextsRunning(page) {
  await expect.poll(() => page.evaluate(() => window.suspendedGameAudio.every(context => context.state === 'running')),
    { message: 'The original AudioContext resumes after the trusted gesture' }).toBe(true);
}

test('suspended bundled audio recovers on the next real card gesture without reloading', async ({ page, context, browserName }, info) => {
  const requests = watchAudioRequests(page);
  await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  const errors = await openGame(page);
  await requireAudio(page, browserName);
  await chooseTheme(page, 5);
  await expectRecording(page, 0, 'assets/audio/bgm/space.wav', { active: true });
  await expectOutputEnergy(page);
  const identity = await page.evaluate(() => ({ origin: performance.timeOrigin, contexts: window.audioObservation.contexts.length }));
  await context.setOffline(true);
  try {
    await suspendGameAudio(page);
    const before = await page.evaluate(() => window.audioObservation.playbacks.length);
    const point = boardPoint(await metrics(page), 0);
    await tap(page, point.x, point.y);
    await expect(page.locator('#game-status')).toHaveText('Now find its match!');
    await expectOriginalContextsRunning(page);
    const selected = await page.locator('#selection-status').textContent();
    const word = catalog.find(entry => entry.text === selected.split(': ')[1]);
    expect(word).toBeTruthy();
    // A source may be scheduled during resume() before the browser resolves
    // that promise. Its PCM identity plus live context/output prove recovery.
    const seconds = waveDuration(word.audio);
    await expect.poll(() => page.evaluate(({ from, seconds }) => window.audioObservation.playbacks.slice(from).some(sound =>
      Math.abs(sound.duration - seconds) <= 1 / sound.sampleRate), { from: before, seconds })).toBe(true);
    const output = await expectOutputEnergy(page);
    expect(await page.evaluate(() => ({ origin: performance.timeOrigin, contexts: window.audioObservation.contexts.length }))).toEqual(identity);
    await expect(page.locator('#audio-status')).toBeEmpty();
    expect(requests).toEqual([]);
    expect(errors).toEqual([]);
    await info.attach('suspended-card-audio', { body: JSON.stringify({ word: word.audio, output,
      sources: await page.evaluate(from => window.audioObservation.playbacks.slice(from), before) }, null, 2), contentType: 'application/json' });
  } finally {
    await context.setOffline(false);
  }
});

for (const event of ['visibilitychange', 'pageshow']) {
  test(`${event} restores only prior bundled music and permits suspended audio recovery`, async ({ page, context, browserName }, info) => {
    const requests = watchAudioRequests(page);
    await observeOutputAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
    const errors = await openGame(page);
    await requireAudio(page, browserName);
    await chooseTheme(page, 5);
    await expectRecording(page, 0, 'assets/audio/bgm/space.wav', { active: true });
    await expectOutputEnergy(page);
    const point = boardPoint(await metrics(page), 0);
    await tap(page, point.x, point.y);
    await expect(page.locator('#game-status')).toHaveText('Now find its match!');
    const selected = await page.locator('#selection-status').textContent();
    const identity = await page.evaluate(() => ({ origin: performance.timeOrigin, contexts: window.audioObservation.contexts.length }));
    await context.setOffline(true);
    try {
      await page.evaluate(event => {
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        if (event === 'visibilitychange') document.dispatchEvent(new Event('visibilitychange'));
        else window.dispatchEvent(new Event('pagehide'));
      }, event);
      const seconds = waveDuration('assets/audio/bgm/space.wav');
      await expect.poll(() => page.evaluate(seconds => window.audioObservation.playbacks.some(sound =>
        Math.abs(sound.duration - seconds) <= 1 / sound.sampleRate && sound.stoppedAt === undefined && sound.endedAt === undefined), seconds),
      { message: 'Backgrounding stops the previously playing music' }).toBe(false);
      await suspendGameAudio(page);
      const beforeVisible = await page.evaluate(() => window.audioObservation.playbacks.length);
      const beforeResume = await page.evaluate(() => window.audioOutputObservation.resumes.length);
      await page.evaluate(event => {
        delete document.hidden;
        if (event === 'visibilitychange') document.dispatchEvent(new Event('visibilitychange'));
        else window.dispatchEvent(new Event('pageshow'));
      }, event);
      await expect.poll(() => page.evaluate(from => window.audioObservation.playbacks.length - from, beforeVisible),
        { message: 'Returning restores one background recording without replaying old speech' }).toBe(1);
      const restored = await page.evaluate(from => window.audioObservation.playbacks.slice(from), beforeVisible);
      expect(restored).toHaveLength(1);
      expect(Math.abs(restored[0].duration - seconds)).toBeLessThanOrEqual(1 / restored[0].sampleRate);
      await expect.poll(() => page.evaluate(() => window.audioOutputObservation.resumes.length),
        { message: 'Foreground recovery actually asks the suspended context to resume' }).toBeGreaterThan(beforeResume);
      const resumeAttempts = await page.evaluate(from => window.audioOutputObservation.resumes.slice(from), beforeResume);
      expect(resumeAttempts.some(attempt => attempt.state === 'suspended')).toBe(true);
      await expect(page.locator('#selection-status')).toHaveText(selected);
      await expect(page.locator('#speech-panel')).toBeHidden();
      await expect(page.locator('#pop-status')).toHaveAttribute('data-phase', 'idle');
      const suspendedOnReturn = await page.evaluate(() => window.suspendedGameAudio.some(context => context.state !== 'running'));
      if (suspendedOnReturn) {
        expect(resumeAttempts.some(attempt => attempt.outcome === 'pending' ||
          (attempt.outcome === 'rejected' && ['NotAllowedError', 'SecurityError'].includes(attempt.error))),
        'Only a pending or browser-policy-blocked resume may need another gesture').toBe(true);
        // Browser autoplay restrictions may require another real gesture. Tap
        // the selected card to cancel it without issuing another word prompt.
        await tap(page, point.x, point.y);
        await expect(page.locator('#selection-status')).toBeEmpty();
      }
      await expectOriginalContextsRunning(page);
      const output = await expectOutputEnergy(page);
      const liveMusic = await page.evaluate(({ from, seconds }) => window.audioObservation.playbacks.slice(from).filter(sound =>
        Math.abs(sound.duration - seconds) <= 1 / sound.sampleRate && sound.stoppedAt === undefined && sound.endedAt === undefined),
      { from: beforeVisible, seconds });
      expect(liveMusic, 'Recovery keeps exactly one live background recording').toHaveLength(1);
      expect(await page.evaluate(() => ({ origin: performance.timeOrigin, contexts: window.audioObservation.contexts.length }))).toEqual(identity);
      await expect(page.locator('#audio-status')).toBeEmpty();
      expect(requests).toEqual([]);
      expect(errors).toEqual([]);
      await info.attach(`foreground-${event}-audio`, { body: JSON.stringify({ suspendedOnReturn, resumeAttempts, restored, output, liveMusic }, null, 2), contentType: 'application/json' });
    } finally {
      await page.evaluate(() => { delete document.hidden; });
      await context.setOffline(false);
    }
  });
}
