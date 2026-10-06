const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const { enterGame, metrics, openModeMenu, tap, rendered, boardPoint, observeAudio } = require('./game-ui.cjs');
const { expectRecording, recordingTiming } = require('./bundled-audio.cjs');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');

const recording = 'assets/imported-audio/ui-click/select.wav';
const uri = `data:audio/wav;base64,${fs.readFileSync(path.resolve(__dirname, '../..', recording)).toString('base64')}`;
const timing = recordingTiming(recording);

async function observeInterfaceMedia(page) {
  await page.addInitScript(uri => {
    const observation = window.interfaceClickObservation = { events: [], players: [], maximumPlaying: 0 };
    const original = HTMLMediaElement.prototype.play;
    const latest = new WeakMap();
    HTMLMediaElement.prototype.play = function (...args) {
      if (this.src !== uri) return original.apply(this, args);
      if (!observation.players.includes(this)) {
        observation.players.push(this);
        for (const type of ['playing', 'ended', 'pause', 'timeupdate']) this.addEventListener(type, () => {
          const event = latest.get(this);
          if (!event) return;
          event.maxTime = Math.max(event.maxTime, this.currentTime);
          if (type === 'playing') event.playing = true;
          if (type === 'ended') event.ended = true;
          observation.maximumPlaying = Math.max(observation.maximumPlaying,
            observation.players.filter(player => !player.paused && !player.ended).length);
        });
      }
      const event = { at: performance.now(), volume: this.volume, rate: this.playbackRate,
        playing: false, ended: false, maxTime: 0 };
      latest.set(this, event);
      observation.events.push(event);
      return original.apply(this, args);
    };
  }, uri);
}

async function expectMediaClicks(page, count) {
  await expect.poll(() => page.evaluate(() => interfaceClickObservation.events.length)).toBe(count);
  if (count > 0) await expect.poll(() => page.evaluate(() => interfaceClickObservation.events.at(-1).ended),
    { message: 'The actual reference click finishes through the browser media output.' }).toBe(true);
}

test('interface reference click plays once for loader mouse, touch, keys and controller without sounding for play toys', async ({ page, browserName }, info) => {
  test.skip(browserName !== 'chromium', 'This playback test requires the working Chromium media backend.');
  await observeInterfaceMedia(page);
  await installGamepad(page, { connected: true });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await expect(page.locator('#status')).toHaveAttribute('data-state', 'ready', { timeout: 60000 });
  await expectMediaClicks(page, 0);
  const summer = page.locator('[data-theme="summer"].loading-theme');
  await summer.dispatchEvent('click');
  await expectMediaClicks(page, 0);
  await summer.click();
  await expectMediaClicks(page, 1);
  await page.locator('[data-theme="autumn"].loading-theme').tap();
  await expectMediaClicks(page, 2);
  await page.locator('[data-theme="autumn"].loading-theme').focus();
  await page.keyboard.press('Enter');
  await expectMediaClicks(page, 3);
  await page.keyboard.press('Space');
  await expectMediaClicks(page, 4);
  await page.keyboard.press('ArrowRight');
  await expectMediaClicks(page, 5);
  await pressGamepad(page, 5);
  await expectMediaClicks(page, 6);
  await page.locator('#loading-toy').click();
  await page.locator('#loading-duck').click();
  await expectMediaClicks(page, 6);
  await pressGamepad(page, 9);
  await expect(page.locator('#status')).toBeHidden();
  await expectMediaClicks(page, 7);
  await page.locator('#enter-game').dispatchEvent('click');
  await expectMediaClicks(page, 7);
  const evidence = await page.evaluate(() => ({ events: interfaceClickObservation.events,
    players: interfaceClickObservation.players.length, maximumPlaying: interfaceClickObservation.maximumPlaying }));
  expect(evidence.players).toBe(1);
  expect(evidence.maximumPlaying).toBe(1);
  for (const event of evidence.events) {
    expect(event.playing).toBe(true);
    expect(event.volume).toBe(.48);
    expect(event.rate).toBe(1);
    expect(event.maxTime).toBeGreaterThanOrEqual(timing.seconds - .01);
  }
  await info.attach('interface-click-loader-playback.json', { body: JSON.stringify(evidence), contentType: 'application/json' });
  expect(errors).toEqual([]);
});

async function activateLibrary(page, name) {
  const control = (await metrics(page)).library.controls.find(value => value.name === name);
  expect(control, `${name} is visible`).toBeTruthy();
  const [x, y, width, height] = control.rect;
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function nativeClicks(page, from) {
  return page.evaluate(({ from, timing }) => audioObservation.playbacks.slice(from).filter(sound =>
    !sound.loop && Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate), { from, timing });
}

test('native menus play the same click once, gameplay cards stay separate, and muted settings reach the shell', async ({ page, browserName }, info) => {
  test.skip(browserName !== 'chromium', 'This playback test requires the working Chromium audio backends.');
  await observeInterfaceMedia(page);
  await observeAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/?speechDebug=1');
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText('Find 5 word');
  await expectMediaClicks(page, 1);
  const evidence = [];
  for (const [name, action] of [
    ['open library', () => openModeMenu(page)],
    ['change motion', () => activateLibrary(page, 'LibraryMotion')],
    ['close library', () => activateLibrary(page, 'LibraryClose')]
  ]) {
    const from = await page.evaluate(() => audioObservation.playbacks.length);
    await action();
    const sound = await expectRecording(page, from, recording);
    expect(sound.fingerprint).toBeTruthy();
    expect(sound.peak).toBeGreaterThan(.1);
    expect(sound.playbackRate).toBe(1);
    expect(await nativeClicks(page, from), 'One accepted native action starts one interface click.').toHaveLength(1);
    evidence.push({ name, sound });
  }
  await expectMediaClicks(page, 1);
  const beforeCard = await page.evaluate(() => audioObservation.playbacks.length);
  const point = boardPoint(await metrics(page), 0);
  await tap(page, point.x, point.y);
  await expect(page.locator('#selection-status')).not.toBeEmpty();
  expect(await nativeClicks(page, beforeCard), 'Selecting a gameplay card keeps its existing gameplay sound.').toHaveLength(0);
  await expectMediaClicks(page, 1);
  await openModeMenu(page);
  await activateLibrary(page, 'LibrarySound');
  await expect.poll(() => page.evaluate(() => JSON.parse(localStorage.getItem('pipAndWords.presentation.v1')).muted)).toBe(true);
  await activateLibrary(page, 'LibraryClose');
  await page.locator('#speech-debug-launch').click();
  await expect(page.locator('#speech-debug')).toBeVisible();
  await expectMediaClicks(page, 1);
  await page.locator('#speech-debug').getByRole('button', { name: 'Close', exact: true }).click();
  await expect(page.locator('#speech-debug')).toBeHidden();
  await openModeMenu(page);
  await activateLibrary(page, 'LibrarySound');
  await activateLibrary(page, 'LibraryClose');
  await page.locator('#speech-debug-launch').click();
  await expect(page.locator('#speech-debug')).toBeVisible();
  await expectMediaClicks(page, 2);
  await page.locator('#speech-debug').getByRole('button', { name: 'Close', exact: true }).click();
  await expectMediaClicks(page, 3);
  await info.attach('interface-click-native-playback.json', { body: JSON.stringify(evidence), contentType: 'application/json' });
  expect(errors).toEqual([]);
});
