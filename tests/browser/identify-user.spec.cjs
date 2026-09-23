const { test, expect } = require('@playwright/test');
const { enterGame, openRewards, metrics, collectionHeaderRect, tap } = require('./game-ui.cjs');
const { SPEAKER_MODEL_VERSION } = require('../../web/voice-profiles.js');

// Exercise the exported UI, real host matching and Godot menu together. Only
// model preparation and microphone hardware are replaced; accuracy needs people.
const hardwareFixture = `(${function installIdentificationHardware() {
  const Host = window.VoicePopMultiplayer;
  const observed = window.identificationHardware = { starts: 0, stops: 0, active: false, commands: [] };
  window.VoicePopCapture.create = async () => {
    observed.starts++;
    observed.active = true;
    observed.gesture = navigator.userActivation?.isActive;
    let stopped = false;
    return { flush: async () => {}, stop() {
      if (!stopped) observed.stops++;
      stopped = true;
      observed.active = false;
    } };
  };
  window.VoicePopMultiplayer = class extends Host {
    constructor(...args) { super(...args); window.identificationHost = this; }
    prepare() {
      this.worker = { terminate() {}, postMessage: message => {
        observed.commands.push(message);
        if (message.type === 'ping') queueMicrotask(() => this.onMessage({ type: 'pong', requestId: message.requestId, ready: true }));
      } };
      this.publish({ status: 'ready', progress: 1 });
      return Promise.resolve(true);
    }
  };
}.toString()})();`;

test('exported Users identifies saved avatars through the real host and releases capture', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  await page.route('**/multiplayer-host.js', async route => {
    const response = await route.fetch();
    await route.fulfill({ contentType: 'application/javascript', body: `${await response.text()}\n${hardwareFixture}` });
  });
  await page.addInitScript(modelVersion => {
    const embedding = Array(256).fill(0); embedding[0] = 1;
    localStorage.setItem('voice-pop-voice-profiles-v1', JSON.stringify({ schemaVersion: 1, revision: 1,
      profiles: [{ id: 'saved-yoki', name: 'Yoki', emoji: '🐶', embedding, modelVersion }] }));
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => { throw new Error('Tests never capture a real microphone'); };
  }, SPEAKER_MODEL_VERSION);
  await page.goto('/');
  await enterGame(page);
  await openRewards(page);
  const users = collectionHeaderRect(await metrics(page), 'users');
  await tap(page, users.x + users.width / 2, users.y + users.height / 2);
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByRole('heading', { name: 'Users 1/10' })).toBeVisible();
  const saved = await page.evaluate(() => localStorage.getItem('voice-pop-voice-profiles-v1'));
  await expect(dialog.getByRole('button', { name: 'Identify user', exact: true })).toBeEnabled();
  await page.screenshot({ path: info.outputPath('identify-user-menu.png') });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await dialog.getByRole('button', { name: 'Identify user', exact: true }).click();
  await expect(dialog).toContainText('Listening…');
  await expect(dialog.locator('.vp-identify-avatar')).toHaveCSS('animation-name', 'none');
  expect(await page.evaluate(() => ({ active: identificationHardware.active, gesture: identificationHardware.gesture,
    mode: identificationHost.session.mode }))).toEqual({ active: true, gesture: true, mode: 'identification' });
  await page.evaluate(() => {
    const host = identificationHost;
    const embedding = Array(256).fill(0); embedding[0] = 1;
    window.finishedIdentification = host.session.sessionId;
    host.onMessage({ type: 'identification-complete', sessionId: host.session.sessionId, embedding,
      templates: [embedding.slice(), embedding.slice()],
      segments: [{ embedding: embedding.slice(), voicedMs: 2200 }, { embedding: embedding.slice(), voicedMs: 2200 }],
      modelVersion: SPEAKER_MODEL_VERSION, quality: { segments: 2, voicedMs: 4400 } });
  });
  await expect(dialog.getByText('User identified', { exact: true })).toBeVisible();
  await expect(dialog.getByRole('heading', { name: 'Yoki', exact: true })).toBeVisible();
  await expect(dialog.locator('.vp-identify-avatar')).toHaveText('🐶');
  expect(await page.evaluate(() => ({ active: identificationHardware.active, stops: identificationHardware.stops,
    session: identificationHost.session }))).toEqual({ active: false, stops: 1, session: null });
  await page.screenshot({ path: info.outputPath('identified-user.png') });
  await dialog.getByRole('button', { name: 'Try again', exact: true }).click();
  await expect(dialog).toContainText('Listening…');
  await page.evaluate(() => {
    const embedding = Array(256).fill(0); embedding[1] = 1;
    identificationHost.onMessage({ type: 'identification-complete', sessionId: finishedIdentification,
      embedding, modelVersion: SPEAKER_MODEL_VERSION });
  });
  await expect(dialog).toContainText('Listening…');
  await dialog.getByRole('button', { name: 'Cancel', exact: true }).click();
  await expect(dialog.getByRole('heading', { name: 'Users 1/10' })).toBeVisible();
  expect(await page.evaluate(() => ({ active: identificationHardware.active, starts: identificationHardware.starts,
    stops: identificationHardware.stops, saved: localStorage.getItem('voice-pop-voice-profiles-v1') })))
    .toEqual({ active: false, starts: 2, stops: 2, saved });
  await dialog.getByRole('button', { name: 'Close users' }).click();
  await expect(dialog).toBeHidden();
  expect(errors).toEqual([]);
});
