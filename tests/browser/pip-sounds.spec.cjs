const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const { openGame, enterGame, metrics, tap, headerPoint, openRewards, roomPoint, observeAudio } = require('./game-ui.cjs');

function hash(source) {
  let value = 2166136261;
  for (let index = 0; index < source.length; index++) value = Math.imul(value ^ source.charCodeAt(index), 16777619) >>> 0;
  return value.toString(16);
}

const samples = ['duck_double_01_bouncy.wav', 'duck_double_03_derpy.wav', 'duck_quack_innocent_deep_short_04.wav'].map(name => {
  const wav = fs.readFileSync(path.resolve(__dirname, '../../assets/audio/pip', name));
  let byteRate, dataSize;
  for (let offset = 12; offset + 8 <= wav.length;) {
    const id = wav.toString('ascii', offset, offset + 4), size = wav.readUInt32LE(offset + 4);
    if (id === 'fmt ') byteRate = wav.readUInt32LE(offset + 16);
    if (id === 'data') dataSize = size;
    offset += 8 + size + size % 2;
  }
  if (!byteRate || !dataSize) throw new Error(`Invalid Pip WAV: ${name}`);
  return { name, hash: hash(`data:audio/wav;base64,${wav.toString('base64')}`), duration: dataSize / byteRate };
});

async function observeLoaderSounds(page) {
  await page.addInitScript(() => {
    const probe = window.pipMediaObservation = { players: [], events: [], maxPlaying: 0 };
    const latest = new WeakMap(), originalPlay = HTMLMediaElement.prototype.play;
    const sampleConcurrency = () => {
      probe.maxPlaying = Math.max(probe.maxPlaying, probe.players.filter(player => !player.paused && !player.ended).length);
    };
    HTMLMediaElement.prototype.play = function (...args) {
      const source = this.src;
      if (!source.startsWith('data:audio/wav;base64,')) return originalPlay.apply(this, args);
      if (!probe.players.includes(this)) {
        probe.players.push(this);
        for (const name of ['playing', 'timeupdate', 'pause', 'ended']) this.addEventListener(name, () => {
          const event = latest.get(this);
          if (!event) return;
          event.maxTime = Math.max(event.maxTime, this.currentTime);
          if (name === 'playing') event.playing = true;
          if (name === 'ended') event.ended = true;
          sampleConcurrency();
        });
      }
      let hash = 2166136261;
      for (let index = 0; index < source.length; index++) hash = Math.imul(hash ^ source.charCodeAt(index), 16777619) >>> 0;
      const event = { hash: hash.toString(16), playing: false, ended: false, maxTime: 0, volume: this.volume, muted: this.muted };
      latest.set(this, event);
      probe.events.push(event);
      // Keep the real promise and all browser playback behavior, including any
      // unhandled rejection. This probe never supplies or simulates audio.
      const result = originalPlay.apply(this, args);
      sampleConcurrency();
      return result;
    };
  });
}

function errorsFrom(page) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  return errors;
}

test('loading Pip plays the three supplied recordings without repeats or overlapping bursts and stops at game entry', async ({ page }, testInfo) => {
  await observeLoaderSounds(page);
  const errors = errorsFrom(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  // Exercise the actual loader with the real engine ready behind it.
  await expect(page.locator('#status')).toHaveAttribute('data-state', 'ready', { timeout: 60000 });
  const controlWav = fs.readFileSync(path.resolve(__dirname, '../../assets/audio/sfx/select.wav'));
  const backend = await page.evaluate(uri => new Promise(resolve => {
    // Windows Playwright WebKit can advertise WAV support while its media
    // backend rejects even a known PCM16 file. Check that independently of Pip.
    const control = new Audio();
    const finish = result => { clearTimeout(timer); control.pause(); resolve(result); };
    const timer = setTimeout(() => finish({ supported: false, error: 'timeout' }), 3000);
    control.addEventListener('loadedmetadata', () => finish({ supported: true }), { once: true });
    control.addEventListener('error', () => finish({ supported: false, error: control.error?.code }), { once: true });
    control.src = uri;
    control.load();
  }), `data:audio/wav;base64,${controlWav.toString('base64')}`);
  if (!backend.supported) {
    expect(backend.error, 'Only an explicit unsupported-source result from the independent PCM16 control permits the UI-only path.').toBe(4);
    testInfo.annotations.push({ type: 'audio capability', description: 'This browser backend rejects known PCM16 and supplied PCM24 WAV audio; audible assertions are unavailable. Direct input, selection and cleanup still run.' });
  }
  await testInfo.attach('loader-media-backend.json', { body: JSON.stringify(backend), contentType: 'application/json' });
  const duck = page.locator('#loading-duck');
  expect(await page.evaluate(() => pipMediaObservation.events)).toEqual([]);
  await duck.dispatchEvent('click');
  expect(await page.evaluate(() => pipMediaObservation.events), 'An untrusted click cannot start audio.').toEqual([]);
  for (let index = 0; index < 6; index++) {
    if (index === 1) await duck.tap();
    else if (index === 2) { await duck.focus(); await page.keyboard.press('Enter'); }
    else await duck.click();
    await expect(duck).toHaveAttribute('data-activity', 'reacting');
    if (backend.supported) await expect.poll(() => page.evaluate(index => pipMediaObservation.events[index]?.ended, index),
      { message: 'The supplied recording reaches its real media ended event.' }).toBe(true);
    const played = await page.evaluate(index => pipMediaObservation.events[index], index);
    const source = samples.find(sample => sample.hash === played.hash);
    expect(source, 'The actual media source exactly matches one of the three supplied WAV files.').toBeTruthy();
    if (backend.supported) {
      expect(played.playing).toBe(true);
      expect(played.maxTime).toBeGreaterThan(source.duration - 0.03);
    }
    expect(played.muted).toBe(false);
    expect(played.volume).toBeGreaterThan(0);
  }
  const sequence = await page.evaluate(() => pipMediaObservation.events.map(event => event.hash));
  expect(new Set(sequence.slice(0, 3)).size, 'One shuffle includes all three real recordings.').toBe(3);
  for (let index = 1; index < sequence.length; index++) expect(sequence[index], 'Adjacent calls differ, including at a shuffle boundary.').not.toBe(sequence[index - 1]);

  for (let index = 0; index < 8; index++) await duck.click({ delay: 0 });
  if (backend.supported) await expect.poll(() => page.evaluate(() => pipMediaObservation.events.at(-1)?.ended)).toBe(true);
  expect(await page.evaluate(() => pipMediaObservation.events.length)).toBe(14);
  const maximum = await page.evaluate(() => pipMediaObservation.maxPlaying);
  expect(maximum, 'Rapid clicks never stack voices.').toBeLessThanOrEqual(1);
  if (backend.supported) expect(maximum, 'A real recording played during the burst.').toBe(1);
  await duck.click();
  await enterGame(page);
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  await expect.poll(() => page.evaluate(() => pipMediaObservation.players.every(player => player.paused && player.currentTime < 0.01)),
    { message: 'Leaving the loader pauses and rewinds every Pip player.' }).toBe(true);
  const count = await page.evaluate(() => pipMediaObservation.events.length);
  await duck.dispatchEvent('click');
  await page.waitForTimeout(450);
  expect(await page.evaluate(() => pipMediaObservation.events.length), 'The hidden loader cannot restart a delayed or stale greeting.').toBe(count);
  await testInfo.attach('loader-pip-real-playback.json', {
    body: JSON.stringify(await page.evaluate(() => ({ events: pipMediaObservation.events, maxPlaying: pipMediaObservation.maxPlaying })), null, 2),
    contentType: 'application/json'
  });
  expect(errors).toEqual([]);
});

async function saves(page) {
  return page.evaluate(() => ({ selection: document.getElementById('selection-status').textContent,
    records: ['wordBuddies.medalProgress', 'wordBuddies.playroom', 'wordBuddies.favoriteReward'].map(key => [key, localStorage.getItem(key)]) }));
}

async function greetings(page) {
  return page.evaluate(durations => audioObservation.playbacks.filter(sound => !sound.loop &&
    durations.some(duration => Math.abs(sound.duration - duration) <= 2 / sound.sampleRate)), samples.map(sample => sample.duration));
}

test('native header and Home poke or pet play real short Pip greetings without changing progress', async ({ page, browserName }, testInfo) => {
  await observeAudio(page, { fingerprintBuffers: true });
  const errors = await openGame(page, { reducedMotion: 'reduce' });
  const available = await page.evaluate(() => audioObservation.available);
  if (browserName === 'chromium') expect(available, 'Chromium must exercise the real native audio path.').toBe(true);
  if (!available) testInfo.annotations.push({ type: 'audio capability', description: 'This WebKit runtime has no AudioContext; native direct input and progress checks still run, audible assertions are unavailable.' });
  const original = await saves(page), header = headerPoint(await metrics(page), 'pip');
  async function expectGreetingAfter(action) {
    const before = (await greetings(page)).length;
    await action();
    if (available) {
      await expect.poll(async () => (await greetings(page)).length).toBe(before + 1);
      const sound = (await greetings(page)).at(-1);
      expect(sound.contextState).toBe('running');
      expect(sound.playbackRate).toBe(1);
      // Godot's Web sample driver can expand the mono resource to stereo.
      expect([1, 2]).toContain(sound.channels);
      expect(sound.peak, 'The native player submits audible PCM, not a silent placeholder.').toBeGreaterThan(0.01);
      expect(sound.fingerprint).toBeTruthy();
      await page.waitForTimeout(420);
    }
  }
  for (let index = 0; index < 4; index++) {
    await expectGreetingAfter(() => tap(page, header.x, header.y));
    await expect(page.locator('#game-status')).toContainText('Pip says hello!');
  }
  await page.screenshot({ path: testInfo.outputPath('pip-random-sound-header.png'), scale: 'css' });
  await openRewards(page);
  const bounds = await metrics(page), pip = roomPoint(bounds, 'pip');
  for (let index = 0; index < 2; index++) {
    await expectGreetingAfter(() => tap(page, pip.x, pip.y));
    await expect(page.locator('#game-status')).toHaveText(/^(Boing! Pip jumps for you!|Aww! Pip feels shy!|Boop! Pip bounces right back!)$/);
  }
  await expectGreetingAfter(async () => {
    const x = bounds.x + pip.x * bounds.scale, y = bounds.y + (pip.y - 18) * bounds.scale;
    await page.mouse.move(x, y);
    await page.mouse.down();
    try {
      for (const offset of [23, -23, 0]) await page.mouse.move(x + offset * bounds.scale, y, { steps: 3 });
    } finally { await page.mouse.up(); }
  });
  await expect(page.locator('#game-status')).toHaveText('Pip leans into your hand. Lovely!');
  expect(await saves(page)).toEqual(original);
  const played = await greetings(page);
  if (available) {
    expect(played).toHaveLength(7);
    expect(new Set(played.map(sound => sound.fingerprint)).size).toBeGreaterThan(1);
    for (let index = 1; index < played.length; index++) expect(played[index].fingerprint).not.toBe(played[index - 1].fingerprint);
  }
  await page.screenshot({ path: testInfo.outputPath('pip-random-sound-home.png'), scale: 'css' });
  await testInfo.attach('native-pip-real-playback.json', { body: JSON.stringify({ available, played }, null, 2), contentType: 'application/json' });
  expect(errors).toEqual([]);
});
