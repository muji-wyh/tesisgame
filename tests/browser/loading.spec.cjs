const fs = require('node:fs');
const path = require('node:path');
const { test, expect } = require('@playwright/test');
const { installGamepad, pressGamepad } = require('./gamepad.cjs');
const { inlineMascot } = require('../../tools/prepare-godot.cjs');

const root = path.resolve(__dirname, '..', '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'build', 'web', 'index.html'), 'utf8')
  .match(/const config = (\{[^\r\n]*\});/)[1]);
const PIP_PARTS = ['body', 'head', 'left-wing', 'right-wing', 'left-foot', 'right-foot'];
const PIP_REACTIONS = ['bonk', 'jump', 'shy'];

async function expectAutomaticDance(page) {
  const duck = page.locator('#loading-duck');
  await expect(duck).toHaveAttribute('data-activity', 'dancing');
  await expect(duck).toHaveAttribute('data-pose', 'dance');
  await expect(duck).toHaveAttribute('data-queued', '0');
  await expect.poll(() => duck.evaluate(element => {
    const animations = element.getAnimations({ subtree: true });
    return animations.length === 6 && animations.every(animation =>
      animation.playState === 'running' && animation.effect.getTiming().iterations === Infinity);
  }), { message: 'All six parts dance continuously without another interaction.' }).toBe(true);
}

async function samplePipMotion(page, duration) {
  return page.evaluate(({ parts, duration }) => new Promise(resolve => {
    const started = performance.now(), frames = [];
    function sample() {
      const duck = document.getElementById('loading-duck');
      frames.push({ at: performance.now() - started, activity: duck.dataset.activity, pose: duck.dataset.pose,
        parts: Object.fromEntries(parts.map(part => {
          const matrix = new DOMMatrix(getComputedStyle(document.getElementById('loading-pip-' + part)).transform);
          return [part, { angle: Math.atan2(matrix.b, matrix.a) * 180 / Math.PI, x: matrix.e, y: matrix.f }];
        })) });
      if (performance.now() - started >= duration) resolve(frames);
      else requestAnimationFrame(sample);
    }
    requestAnimationFrame(sample);
  }), { parts: PIP_PARTS, duration });
}

async function reactionPose(page) {
  const duck = page.locator('#loading-duck');
  await expect(duck).toHaveAttribute('data-activity', 'reacting');
  await expect(duck).toHaveAttribute('data-pose', /^(jump|shy|bonk)$/);
  await expect(duck).toHaveAttribute('data-queued', '0');
  return duck.getAttribute('data-pose');
}

async function enterGame(page) {
  await expect(page.locator('#enter-game')).toBeEnabled({ timeout: 60000 });
  await page.locator('#enter-game').click();
}

for (const cpu of [1, 4]) test(`the real engine bounds loading chest delays at CPU ${cpu}x`, async ({ page, browserName }, testInfo) => {
  test.skip(browserName !== 'chromium', 'CPU throttling requires Chromium CDP');
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.addInitScript(() => {
    window.startupTasks = [];
    window.startupProgressWrites = [{ at: 0, percent: '' }];
    window.startupReadyAt = Infinity;
    new MutationObserver(() => {
      if (document.getElementById('status')?.dataset.state === 'ready' && startupReadyAt === Infinity) startupReadyAt = performance.now();
    }).observe(document, { subtree: true, attributes: true, attributeFilter: ['data-state'] });
    const textContent = Object.getOwnPropertyDescriptor(Node.prototype, 'textContent');
    Object.defineProperty(Node.prototype, 'textContent', {
      ...textContent,
      set(value) {
        if (this.id === 'loading-percent') startupProgressWrites.push({ at: performance.now(), percent: String(value) });
        textContent.set.call(this, value);
      }
    });
    new PerformanceObserver(list => {
      startupTasks.push(...list.getEntries().map(entry => ({
          start: entry.startTime, duration: entry.duration,
          // Observer delivery may be delayed across several engine frames.
          // Attribute each task to the progress actually displayed at its start.
          percent: startupProgressWrites.findLast(write => write.at <= entry.startTime)?.percent || '',
          deliveredPercent: document.getElementById('loading-percent').textContent
      })));
    }).observe({ type: 'longtask', buffered: true });
  });
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
  await page.goto('/', { waitUntil: 'commit' });
  const toy = page.locator('#loading-toy');
  await expect(toy).toBeVisible();
  const box = await toy.boundingBox();
  let ready = false;
  const completion = page.waitForFunction(() => document.getElementById('status').dataset.state === 'ready')
    .then(() => { ready = true; });
  const delays = [];
  while (!ready) {
    const start = Date.now();
    // Queue a complete quick tap in protocol order before waiting for either
    // acknowledgement. Waiting between down/up would add two separate stalls.
    await Promise.all(['mousePressed', 'mouseReleased'].map(type => cdp.send('Input.dispatchMouseEvent', {
      type, x: box.x + box.width / 2, y: box.y + box.height / 2, button: 'left', clickCount: 1
    })));
    delays.push(Date.now() - start);
    await new Promise(resolve => setTimeout(resolve, 80));
  }
  await completion;
  await page.screenshot({ path: testInfo.outputPath('ready-after-responsive-loading.png'), scale: 'css' });
  const tasks = await page.evaluate(() => window.startupTasks.filter(task => task.start < window.startupReadyAt));
  const progressWrites = await page.evaluate(() => window.startupProgressWrites);
  await testInfo.attach('startup-responsiveness.json', {
    body: JSON.stringify({ tasks, delays, progressWrites }), contentType: 'application/json'
  });
  expect(errors).toEqual([]);
  // Godot's core setup is synchronous; bound it separately from the now-yielding game setup.
  expect(Math.max(...tasks.map(task => task.duration)), 'Bound engine setup even on a slower CPU')
    .toBeLessThan(cpu === 1 ? 750 : 2000);
  expect(tasks.filter(task => task.duration > 750 && task.percent !== '98%'), 'Long setup runs only at the final preparation stage').toEqual([]);
  expect(Math.max(...delays), 'Real loading chest clicks receive bounded feedback')
    .toBeLessThan(cpu === 1 ? 1000 : 2000);
  await expect(page.locator('#loading-score')).not.toHaveText('0 sparkles');
  await enterGame(page);
  await expect(page.locator('#status')).toBeHidden();
});

async function useMaintainedShell(page) {
  const shell = inlineMascot(fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8'))
    .replace('$GODOT_HEAD_INCLUDE', '')
    .replace('$GODOT_URL', `${config.executable}.js`)
    .replace('$GODOT_CONFIG', JSON.stringify(config));
  await page.route('**/loader-test*', route => route.fulfill({ contentType: 'text/html', body: shell }));
}

async function whileEngineScriptIsPending(page, action) {
  await useMaintainedShell(page);
  let release;
  const held = new Promise(resolve => { release = resolve; });
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, async route => {
    await held;
    await route.abort();
  });
  try {
    await page.goto('/loader-test', { waitUntil: 'commit' });
    await expect(page.locator('#loading-toy')).toBeVisible();
    await action(page.getByRole('button', { name: 'Tap or wiggle the treasure chest' }));
  } finally {
    release();
    await page.unrouteAll({ behavior: 'wait' });
  }
}

for (const theme of ['jungle', 'candy']) test(`loading Pip keeps the saved ${theme} outfit while dancing`, async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.addInitScript(theme => {
    localStorage.setItem('wordBuddies.playroom', `[playroom]\npreferred_theme_id="${theme}"\n`);
  }, theme);
  // Let the document finish loading for WebKit screenshots. The engine fixture
  // never reports ready, so Pip stays on the real maintained loading surface.
  await progressShell(page);
  const toy = page.locator('#loading-toy'), duck = page.locator('#loading-duck');
  await expect(duck).toHaveAttribute('data-theme', theme);
  await expectAutomaticDance(page);
  const costume = await duck.locator('[id^="loading-pip-"]').evaluateAll(parts => parts.map(part => part.innerHTML));
  await page.screenshot({ path: testInfo.outputPath(`loading-${theme}-automatic-dance.png`), scale: 'css' });
  const reactions = [];
  for (let index = 0; index < 3; index++) {
    await toy.tap();
    const pose = await reactionPose(page);
    reactions.push(pose);
    const frames = await samplePipMotion(page, 160);
    expect(frames.some(frame => frame.pose === pose)).toBe(true);
    await page.screenshot({ path: testInfo.outputPath(`loading-${theme}-${pose}.png`), scale: 'css' });
    await expect(duck).toHaveAttribute('data-theme', theme);
    expect(await duck.locator('[id^="loading-pip-"]').evaluateAll(parts => parts.map(part => part.innerHTML)),
      'Dancing and reactions preserve the saved costume.').toEqual(costume);
    await expectAutomaticDance(page);
  }
  expect(reactions.sort()).toEqual(PIP_REACTIONS);
  await page.screenshot({ path: testInfo.outputPath(`loading-${theme}-full.png`), scale: 'css' });
});

test('loading keeps one visible progress readout and no extra slogan', async ({ page }) => {
  await progressShell(page);
  await expect(page.locator('.loading-heading small')).toHaveCount(0);
  const score = await page.locator('#loading-score').boundingBox();
  expect(score.width).toBeLessThanOrEqual(1);
  await page.evaluate(() => window.reportDownload(50, 100));
  await expect(page.locator('#loading-percent')).toHaveText(/\d+%/);
  await expect(page.locator('#loading-hint')).toBeVisible();
});

async function progressShell(page, engineScript = `window.Engine = class {
  static getMissingFeatures() { return []; }
  static load() { return Promise.resolve(); }
  startGame({ onProgress }) { window.reportDownload = onProgress; return Promise.resolve(); }
};`) {
  await useMaintainedShell(page);
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, route => route.fulfill({
    contentType: 'application/javascript',
    body: engineScript
  }));
  await page.goto('/loader-test');
}

async function observeLoadingAudio(page) {
  await page.addInitScript(() => {
    const Audio = window.AudioContext || window.webkitAudioContext;
    window.loadingAudioProbe = { supported: typeof Audio === 'function', contexts: [], analysers: [], notes: [] };
    if (!Audio) return;
    window.AudioContext = new Proxy(Audio, {
      construct(Type, args) {
        const context = Reflect.construct(Type, args);
        const analyser = context.createAnalyser();
        analyser.fftSize = 256;
        analyser.connect(context.destination);
        loadingAudioProbe.contexts.push(context);
        loadingAudioProbe.analysers.push(analyser);
        const createGain = context.createGain.bind(context);
        context.createGain = () => {
          const gain = createGain();
          const connect = gain.connect.bind(gain);
          gain.connect = (destination, ...channels) => connect(destination === context.destination ? analyser : destination, ...channels);
          return gain;
        };
        const createOscillator = context.createOscillator.bind(context);
        context.createOscillator = () => {
          const oscillator = createOscillator();
          const start = oscillator.start.bind(oscillator);
          oscillator.start = time => {
            loadingAudioProbe.notes.push({ pitch: oscillator.frequency.value, time, type: oscillator.type });
            return start(time);
          };
          return oscillator;
        };
        return context;
      }
    });
  });
}

test('loading Pip dances automatically without input or music and keeps dancing until entry', async ({ page }, testInfo) => {
  await observeLoadingAudio(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await progressShell(page);
  await expectAutomaticDance(page);
  const duck = page.locator('#loading-duck');
  const loopDuration = await duck.evaluate(element => {
    window.initialLoadingDance = element.getAnimations({ subtree: true });
    return Math.max(...initialLoadingDance.map(animation => Number(animation.effect.getTiming().duration)));
  });
  expect(Number.isFinite(loopDuration) && loopDuration > 0).toBe(true);
  const frames = await samplePipMotion(page, loopDuration + 120);
  expect(frames.every(frame => frame.activity === 'dancing' && frame.pose === 'dance')).toBe(true);
  for (const part of PIP_PARTS) {
    const positions = frames.map(frame => frame.parts[part]);
    const change = Math.max(...['angle', 'x', 'y'].map(axis =>
      Math.max(...positions.map(position => position[axis])) - Math.min(...positions.map(position => position[axis]))));
    expect(change, `${part} moves through a real animation cycle without a click.`).toBeGreaterThan(1);
  }
  expect(await duck.evaluate(element => {
    const current = element.getAnimations({ subtree: true });
    return current.length === initialLoadingDance.length && current.every(animation => initialLoadingDance.includes(animation));
  }), 'The same infinite animations survive a whole dance cycle.').toBe(true);
  await expect(page.locator('#loading-score')).toHaveText('0 sparkles');
  expect(await page.evaluate(() => loadingAudioProbe.contexts.length)).toBe(0);
  await page.screenshot({ path: testInfo.outputPath('loading-automatic-dance.png'), scale: 'css' });
  await page.evaluate(() => wordBuddiesHost.ready());
  await expect(page.locator('#enter-game')).toBeEnabled();
  await expectAutomaticDance(page);
  const readyFrames = await samplePipMotion(page, 300);
  expect(readyFrames.every(frame => frame.activity === 'dancing')).toBe(true);
  expect(await page.evaluate(() => loadingAudioProbe.contexts.length)).toBe(0);
  await page.screenshot({ path: testInfo.outputPath('loading-ready-still-dancing.png'), scale: 'css' });
  await page.evaluate(() => {
    document.getElementById('enter-game').addEventListener('click', () => {
      window.pipActivityAtEntry = document.getElementById('loading-duck').dataset.activity;
    }, { capture: true, once: true });
  });
  await duck.tap();
  await reactionPose(page);
  const reactionDuration = await duck.evaluate(element => Math.max(...element.getAnimations({ subtree: true })
    .map(animation => Number(animation.effect.getTiming().duration))));
  expect(Number.isFinite(reactionDuration) && reactionDuration > 0).toBe(true);
  await enterGame(page);
  expect(await page.evaluate(() => window.pipActivityAtEntry)).toBe('reacting');
  await expect(page.locator('#status')).toBeHidden();
  expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
  await page.waitForTimeout(reactionDuration + 120);
  await expect(duck).toHaveAttribute('data-activity', 'idle');
  expect(await page.locator('#loading-play').evaluate(element => element.getAnimations({ subtree: true }).length),
    'A reaction completion callback cannot restart loading effects after entry.').toBe(0);
  expect(await page.evaluate(() => loadingAudioProbe.contexts.every(context => context.state === 'closed'))).toBe(true);
  await testInfo.attach('loading-automatic-motion.json', { body: JSON.stringify({ loopDuration, frames, readyFrames }), contentType: 'application/json' });
});

test('Pip and chest touch, keyboard and controller taps play all three reactions and return to dancing', async ({ page }, testInfo) => {
  await installGamepad(page, { connected: true });
  await page.setViewportSize({ width: 320, height: 568 });
  await progressShell(page);
  await expectAutomaticDance(page);
  const duck = page.getByRole('button', { name: 'Dance with Pip the duck' });
  const toy = page.locator('#loading-toy');
  const inputs = [
    { name: 'pip-touch', activate: () => duck.tap() },
    { name: 'chest-touch', activate: () => toy.tap() },
    { name: 'pip-enter', activate: async () => { await duck.focus(); await page.keyboard.press('Enter'); } },
    { name: 'chest-space', activate: async () => { await toy.focus(); await page.keyboard.press('Space'); } },
    { name: 'controller-a', activate: () => pressGamepad(page, 0) },
    { name: 'pip-space', activate: async () => { await duck.focus(); await page.keyboard.press('Space'); } }
  ];
  const reactions = [], evidence = [];
  for (const input of inputs) {
    await input.activate();
    const pose = await reactionPose(page);
    if (reactions.length) expect(pose).not.toBe(reactions.at(-1));
    reactions.push(pose);
    const remaining = await duck.evaluate(element => Math.max(0, ...element.getAnimations({ subtree: true })
      .map(animation => Number(animation.effect.getTiming().duration) - Number(animation.currentTime))));
    const sampling = samplePipMotion(page, remaining + 80);
    await page.screenshot({ path: testInfo.outputPath(`loading-${input.name}-${pose}.png`), scale: 'css' });
    const frames = await sampling;
    const active = frames.filter(frame => frame.activity === 'reacting' && frame.pose === pose);
    expect(active.length, `${input.name} visibly interrupts the dance.`).toBeGreaterThan(1);
    const positions = new Set(active.map(frame => JSON.stringify(frame.parts)));
    expect(positions.size, `${pose} changes the rendered limbs instead of only its data attribute.`).toBeGreaterThan(1);
    evidence.push({ input: input.name, pose, frames });
    await expectAutomaticDance(page);
  }
  expect([...reactions.slice(0, 3)].sort()).toEqual(PIP_REACTIONS);
  expect([...reactions.slice(3, 6)].sort()).toEqual(PIP_REACTIONS);
  await expect(page.locator('#loading-score')).toHaveText('3 sparkles');
  await testInfo.attach('loading-random-reactions.json', { body: JSON.stringify(evidence), contentType: 'application/json' });
});

test('rapid loading taps replace the active reaction without a backlog and recover to dancing', async ({ page }, testInfo) => {
  await progressShell(page);
  await expectAutomaticDance(page);
  const duck = page.locator('#loading-duck');
  await duck.tap();
  await reactionPose(page);
  const burst = await page.evaluate(() => {
    const duck = document.getElementById('loading-duck'), toy = document.getElementById('loading-toy');
    const records = [];
    for (let index = 0; index < 40; index++) {
      const previous = duck.getAnimations({ subtree: true });
      (index % 2 ? toy : duck).click();
      const current = duck.getAnimations({ subtree: true });
      records.push({ pose: duck.dataset.pose, activity: duck.dataset.activity, queued: duck.dataset.queued,
        count: current.length, replaced: previous.every(animation => !current.includes(animation) && animation.playState === 'idle') });
    }
    return records;
  });
  for (const [index, frame] of burst.entries()) {
    expect(PIP_REACTIONS).toContain(frame.pose);
    expect(frame.activity).toBe('reacting');
    expect(frame.queued).toBe('0');
    expect(frame.count).toBeGreaterThan(0);
    expect(frame.count).toBeLessThanOrEqual(6);
    expect(frame.replaced, `Tap ${index + 1} cancels the previous reaction immediately.`).toBe(true);
    if (index) expect(frame.pose).not.toBe(burst[index - 1].pose);
  }
  await expectAutomaticDance(page);
  const recovered = await samplePipMotion(page, 400);
  expect(recovered.every(frame => frame.activity === 'dancing' && frame.pose === 'dance'),
    'An old completion callback must not resurrect a replaced reaction.').toBe(true);
  await expect(duck).toHaveAttribute('data-queued', '0');
  await page.screenshot({ path: testInfo.outputPath('loading-rapid-taps-recovered.png'), scale: 'css' });
  await testInfo.attach('loading-reaction-preemption.json', { body: JSON.stringify({ burst, recovered }), contentType: 'application/json' });
});

test('loading dance stops while hidden and reduced motion can change without losing interaction', async ({ page }, testInfo) => {
  await observeLoadingAudio(page);
  await progressShell(page);
  const duck = page.locator('#loading-duck');
  await expectAutomaticDance(page);
  await duck.dispatchEvent('click');
  await reactionPose(page);
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(duck).toHaveAttribute('data-activity', 'idle');
  await expect(duck).toHaveAttribute('data-pose', 'idle');
  await expect(duck).toHaveAttribute('data-queued', '0');
  expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
  await page.waitForTimeout(800);
  expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
  await page.evaluate(() => {
    delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expectAutomaticDance(page);
  expect(await page.evaluate(() => loadingAudioProbe.contexts.length)).toBe(0);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(duck).toHaveAttribute('data-activity', 'idle');
  await expect(duck).toHaveAttribute('data-pose', 'idle');
  expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
  const still = await samplePipMotion(page, 250);
  expect(new Set(still.map(frame => JSON.stringify(frame.parts))).size).toBe(1);
  await duck.dispatchEvent('click');
  const pose = await reactionPose(page);
  const reaction = await samplePipMotion(page, 180);
  expect(reaction.every(frame => frame.pose === pose)).toBe(true);
  expect(new Set(reaction.map(frame => JSON.stringify(frame.parts))).size).toBe(1);
  expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
  await page.screenshot({ path: testInfo.outputPath('loading-reduced-static-reaction.png'), scale: 'css' });
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await expectAutomaticDance(page);
  expect(await page.evaluate(() => loadingAudioProbe.contexts.length)).toBe(0);
  await page.screenshot({ path: testInfo.outputPath('loading-restored-automatic-dance.png'), scale: 'css' });
});

test('the automatic loading dance and its controls fit compact and desktop screens', async ({ page }, testInfo) => {
  await progressShell(page);
  await expectAutomaticDance(page);
  for (const viewport of [{ width: 320, height: 568 }, { width: 844, height: 390 }, { width: 320, height: 320 }, { width: 1366, height: 768 }]) {
    await page.setViewportSize(viewport);
    for (const selector of ['#loading-toy', '#loading-duck', '#loading-music', '#progress']) {
      const box = await page.locator(selector).boundingBox();
      expect(box.x, selector).toBeGreaterThanOrEqual(0);
      expect(box.y, selector).toBeGreaterThanOrEqual(0);
      expect(box.x + box.width, selector).toBeLessThanOrEqual(viewport.width);
      expect(box.y + box.height, selector).toBeLessThanOrEqual(viewport.height);
      if (selector === '#loading-music') expect(box.height).toBeGreaterThanOrEqual(44);
    }
    expect(await page.locator('#status').evaluate(element => element.scrollHeight <= element.clientHeight)).toBe(true);
    await expectAutomaticDance(page);
    await page.screenshot({ path: testInfo.outputPath(`loading-dance-layout-${viewport.width}x${viewport.height}.png`), scale: 'css' });
  }
});

test('loading music uses a real quiet audio clock and stays on until explicit game entry', async ({ page }, testInfo) => {
  await observeLoadingAudio(page);
  await progressShell(page);
  const music = page.getByRole('button', { name: 'Loading music', exact: true });
  const toy = page.locator('#loading-toy');
  expect(await page.evaluate(() => loadingAudioProbe.contexts.length)).toBe(0);
  await toy.dispatchEvent('click');
  expect(await page.evaluate(() => loadingAudioProbe.contexts.length)).toBe(0);
  await toy.click();
  if (!await page.evaluate(() => loadingAudioProbe.supported)) {
    await expect(music).toHaveAttribute('data-audio-state', 'unavailable');
    await expect(music).toHaveAttribute('aria-pressed', 'false');
    await expect(music).toHaveText('♪ No music');
    await expect(page.locator('#loading-score')).toHaveText('2 sparkles');
    await page.evaluate(() => window.reportDownload(100, 100));
    await expect(page.locator('#loading-percent')).toHaveText('98%');
    await page.evaluate(() => window.wordBuddiesHost.ready());
    await enterGame(page);
    await expect(page.locator('#status')).toBeHidden({ timeout: 700 });
    expect(await page.evaluate(() => loadingAudioProbe.contexts.length)).toBe(0);
    await testInfo.attach('loading-music-capability.json', {
      body: JSON.stringify({ audioContext: false, verified: 'Explicit unavailable feedback; dance and game readiness remain usable.' }),
      contentType: 'application/json'
    });
    return;
  }
  await expect(music).toHaveAttribute('aria-pressed', 'true');
  await expect.poll(() => page.evaluate(() => {
    const samples = new Float32Array(256);
    loadingAudioProbe.analysers.at(-1).getFloatTimeDomainData(samples);
    return Math.max(...samples.map(Math.abs));
  })).toBeGreaterThan(.001);
  const firstTime = await page.evaluate(() => loadingAudioProbe.contexts[0].currentTime);
  await page.waitForTimeout(260);
  expect(await page.evaluate(() => loadingAudioProbe.contexts[0].currentTime)).toBeGreaterThan(firstTime + .12);
  expect(await page.evaluate(() => new Set(loadingAudioProbe.notes.map(note => note.pitch)).size)).toBeGreaterThan(1);
  await music.focus();
  await page.keyboard.press('Enter');
  await expect(music).toHaveAttribute('aria-pressed', 'false');
  await expect.poll(() => page.evaluate(() => loadingAudioProbe.contexts[0].state)).toBe('closed');
  const stopped = await page.evaluate(() => loadingAudioProbe.notes.length);
  await toy.click();
  await page.waitForTimeout(180);
  expect(await page.evaluate(() => loadingAudioProbe.notes.length)).toBe(stopped);
  await music.focus();
  await page.keyboard.press('Space');
  await expect(music).toHaveAttribute('aria-pressed', 'true');
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect.poll(() => page.evaluate(() => loadingAudioProbe.contexts.every(context => context.state === 'closed'))).toBe(true);
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-pose', 'idle');
  await page.evaluate(() => { delete document.hidden; document.dispatchEvent(new Event('visibilitychange')); });
  await expectAutomaticDance(page);
  const hiddenCount = await page.evaluate(() => loadingAudioProbe.contexts.length);
  await page.waitForTimeout(180);
  expect(await page.evaluate(() => loadingAudioProbe.contexts.length)).toBe(hiddenCount);
  await expect(music).toHaveAttribute('aria-pressed', 'false');
  await toy.click();
  await expect(music).toHaveAttribute('aria-pressed', 'true');
  await page.evaluate(() => window.reportDownload(100, 100));
  await expect(page.locator('#loading-percent')).toHaveText('98%');
  await page.evaluate(() => {
    for (let index = 0; index < 30; index++) document.getElementById('loading-toy').click();
    window.wordBuddiesHost.ready();
  });
  await expect(page.locator('#enter-game')).toBeEnabled();
  await page.waitForTimeout(1000);
  await expect(page.locator('#status')).toBeVisible();
  await expectAutomaticDance(page);
  await expect(music).toHaveAttribute('aria-pressed', 'true');
  expect(await page.evaluate(() => loadingAudioProbe.contexts.at(-1).state)).toBe('running');
  const readyAt = await page.evaluate(() => performance.now());
  await enterGame(page);
  await expect(page.locator('#status')).toBeHidden({ timeout: 700 });
  const elapsed = await page.evaluate(at => performance.now() - at, readyAt);
  expect(elapsed, 'The automatic dance and latest reaction must not delay explicit game entry').toBeLessThan(700);
  await expect.poll(() => page.evaluate(() => loadingAudioProbe.contexts.every(context => context.state === 'closed'))).toBe(true);
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-queued', '0');
  expect(await page.locator('#loading-play').evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
  await testInfo.attach('loading-music-real-clock.json', {
    body: JSON.stringify(await page.evaluate(elapsed => ({
      elapsed, contexts: loadingAudioProbe.contexts.map(context => ({ state: context.state, time: context.currentTime })),
      notes: loadingAudioProbe.notes
    }), elapsed), null, 2), contentType: 'application/json'
  });
});

for (const ending of ['failure', 'pagehide']) test(`loading dance and music stop on ${ending}`, async ({ page }) => {
  await observeLoadingAudio(page);
  await progressShell(page);
  await page.locator('#loading-toy').click();
  const supported = await page.evaluate(() => loadingAudioProbe.supported);
  await expect(page.locator('#loading-music')).toHaveAttribute('data-audio-state', supported ? 'running' : 'unavailable');
  if (ending === 'pagehide') {
    await page.locator('#loading-duck').dispatchEvent('click');
    await reactionPose(page);
    const initialPageShow = await page.locator('#loading-duck').evaluate(element => {
      const before = element.getAnimations({ subtree: true }), pose = element.dataset.pose;
      // A pageshow without a preceding pagehide must preserve the current reaction.
      window.dispatchEvent(new Event('pageshow'));
      const after = element.getAnimations({ subtree: true });
      return { activity: element.dataset.activity, samePose: element.dataset.pose === pose,
        sameAnimations: before.length === 6 && after.length === before.length && before.every(animation => after.includes(animation)) };
    });
    expect(initialPageShow).toEqual({ activity: 'reacting', samePose: true, sameAnimations: true });
  }
  await page.evaluate(ending => {
    if (ending === 'failure') window.wordBuddiesHost.fail('The game could not start. Please retry.');
    else window.dispatchEvent(new Event('pagehide'));
  }, ending);
  await expect.poll(() => page.evaluate(() => loadingAudioProbe.contexts.every(context => context.state === 'closed'))).toBe(true);
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-queued', '0');
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-activity', 'idle');
  expect(await page.locator('#loading-play').evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
  if (ending === 'pagehide') {
    const contextCount = await page.evaluate(() => loadingAudioProbe.contexts.length);
    await page.evaluate(() => window.dispatchEvent(new Event('pageshow')));
    await expectAutomaticDance(page);
    await page.waitForTimeout(180);
    await expect(page.locator('#loading-music')).toHaveAttribute('aria-pressed', 'false');
    expect(await page.evaluate(() => loadingAudioProbe.contexts.length)).toBe(contextCount);
    expect(await page.evaluate(() => loadingAudioProbe.contexts.every(context => context.state === 'closed'))).toBe(true);
  }
});

test('runtime initialization waits until the staged 98 percent has been painted', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page, `window.Engine = class {
    static getMissingFeatures() { return []; }
    static load() { return Promise.resolve(); }
    startGame({ onProgress }) { onProgress(1, 1); return this.start(); }
    start() {
      window.runtimeStartedAt = document.getElementById('loading-percent').textContent;
      window.wordBuddiesHost.ready();
      return Promise.resolve();
    }
  };`);
  expect(await page.evaluate(() => window.runtimeStartedAt)).toBeUndefined();
  await page.clock.runFor(600);
  expect(await page.evaluate(() => window.runtimeStartedAt)).toBeUndefined();
  await page.clock.runFor(1000);
  expect(await page.evaluate(() => window.runtimeStartedAt)).toBe('98%');
  await enterGame(page);
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true');
});

test('late download totals cannot reset final runtime preparation', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page, `window.Engine = class {
    static getMissingFeatures() { return []; }
    static load() { return Promise.resolve(); }
    startGame({ onProgress }) {
      const starting = this.start();
      requestAnimationFrame(() => onProgress(1, 0));
      return starting;
    }
    start() { window.wordBuddiesHost.ready(); return Promise.resolve(); }
  };`);
  await page.clock.runFor(2000);
  await enterGame(page);
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 1000 });
});

for (const stage of ['features', 'constructor', 'load', 'start']) {
  test(`synchronous engine ${stage} failure leaves an actionable retry`, async ({ page }, testInfo) => {
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await progressShell(page, `window.Engine = class {
      static getMissingFeatures() { ${stage === 'features' ? "throw new Error('Feature check failed.');" : 'return [];'} }
      constructor() { ${stage === 'constructor' ? "throw new Error('Engine setup failed.');" : ''} }
      static load() { ${stage === 'load' ? "throw new Error('Download setup failed.');" : 'return Promise.resolve();'} }
      startGame() { ${stage === 'start' ? "throw new Error('Game setup failed.');" : 'return Promise.resolve();'} }
    };`);
    await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 3000 });
    await expect(page.locator('#retry')).toBeFocused();
    await expect(page.locator('#loading-play')).toBeHidden();
    await expect(page.locator('#canvas')).toHaveAttribute('inert');
    expect(errors).toEqual([]);
    if (stage === 'constructor') await page.screenshot({ path: testInfo.outputPath('startup-failure-retry.png'), scale: 'css' });
  });
}

test('an empty startup rejection still gives a clear failure and preserves its first cause', async ({ page }) => {
  await progressShell(page, `window.Engine = class {
    static getMissingFeatures() { return []; }
    static load() { return Promise.reject(null); }
    startGame() { return Promise.resolve(); }
  };`);
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 3000 });
  await expect(page.locator('#retry')).toBeFocused();
  const first = await page.locator('#message').textContent();
  await page.evaluate(() => window.wordBuddiesHost.fail('A later shutdown message.'));
  await expect(page.locator('#message')).toHaveText(first);
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await expect(page.locator('#status')).toBeVisible();
});

test('a stalled download offers retry without stealing focus or stopping the loading toy', async ({ page }, testInfo) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page, `window.Engine = class {
    static getMissingFeatures() { return []; }
    static load() { return new Promise(() => {}); }
    startGame() { return new Promise(() => {}); }
  };`);
  await page.setViewportSize({ width: 320, height: 320 });
  const toy = page.getByRole('button', { name: 'Tap or wiggle the treasure chest' });
  await toy.focus();
  await page.clock.runFor(17000);
  await expect(page.locator('#retry')).toBeVisible({ timeout: 3000 });
  await expect(page.locator('#loading-note')).toContainText('retry');
  await expect(toy).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  expect(await page.locator('#status').evaluate(el => el.scrollHeight <= el.clientHeight)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('stalled-download-320.png'), scale: 'css' });
});

test('losing pointer capture cancels the loading chest drag', async ({ page }) => {
  await whileEngineScriptIsPending(page, async toy => {
    const bounds = await toy.boundingBox();
    const x = bounds.x + bounds.width / 2;
    const y = bounds.y + bounds.height / 2;
    await page.mouse.move(x, y);
    await page.mouse.down();
    await page.mouse.move(x + 32, y);
    expect(await page.locator('#chest-art').evaluate(el => el.style.transform)).not.toBe('');
    await toy.evaluate(el => el.releasePointerCapture(1));
    await page.mouse.move(x + 48, y);
    await expect.poll(() => page.locator('#chest-art').evaluate(el => el.style.transform)).toBe('');
    await page.mouse.up();
  });
});

test('graphics context loss gives a visible recovery action and stops game input', async ({ page }, testInfo) => {
  const dialogs = [];
  page.on('dialog', async dialog => { dialogs.push(dialog.message()); await dialog.dismiss(); });
  await useMaintainedShell(page);
  await page.goto('/loader-test');
  await enterGame(page);
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await page.evaluate(() => document.getElementById('canvas').getContext('webgl2')
    .getExtension('WEBGL_lose_context').loseContext());
  await expect(page.locator('#message')).toContainText('graphics', { timeout: 3000 });
  await expect(page.locator('#retry')).toBeFocused();
  await expect(page.locator('#canvas')).toHaveAttribute('inert');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'false');
  expect(dialogs).toEqual([]);
  await page.screenshot({ path: testInfo.outputPath('graphics-lost-retry.png'), scale: 'css' });
  await page.getByRole('button', { name: 'Try again', exact: true }).click();
  await enterGame(page);
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#canvas')).toBeFocused();
});

test('a cached download pauses at 20, 50, 80 and 98 percent before completing and revealing the game', async ({ page }, testInfo) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page);
  const value = () => page.locator('#progress').evaluate(element => element.value);
  await page.evaluate(() => window.reportDownload(100, 100));
  expect(await value()).toBeLessThan(0.1);
  for (const [elapsed, label] of [[128, '20%'], [240, '50%'], [240, '80%'], [176, '98%']]) {
    await page.clock.runFor(elapsed);
    await expect(page.locator('#loading-percent')).toHaveText(label);
    await page.clock.runFor(48);
    await expect(page.locator('#loading-percent')).toHaveText(label);
    if (label === '50%') await page.screenshot({ path: testInfo.outputPath('milestone-50-percent.png'), scale: 'css' });
  }
  await page.screenshot({ path: testInfo.outputPath('milestone-98-percent.png'), scale: 'css' });
  await page.clock.runFor(3000);
  await expect(page.locator('#loading-percent')).toHaveText('98%');
  await expect(page.locator('#status')).toBeVisible();
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await page.clock.runFor(32);
  await expect(page.locator('#loading-percent')).toHaveText('100%');
  await expect(page.locator('#status')).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('completion-before-reveal.png'), scale: 'css' });
  await page.clock.runFor(200);
  await enterGame(page);
  await expect(page.locator('#status')).toBeHidden();
});

test('game input stays paused while the ready game is still covered by the loading screen', async ({ page }, testInfo) => {
  await installGamepad(page, { connected: true });
  await page.addInitScript(() => {
    document.addEventListener('DOMContentLoaded', () => {
      const host = window.wordBuddiesHost;
      window.wordBuddiesHost = { ...host, ready(onReveal) {
        window.finishLoadingPresentation = () => host.ready(onReveal);
      } };
    });
  });
  await page.goto('/');
  await page.waitForFunction(() => typeof window.finishLoadingPresentation === 'function');
  await expect(page.locator('#status')).toBeVisible();
  const initial = await page.locator('#game-status').textContent();
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toHaveText(initial);
  await page.evaluate(() => window.finishLoadingPresentation());
  await expect(page.locator('#enter-game')).toBeEnabled();
  await page.locator('#loading-toy').click();
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
    delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await pressGamepad(page, 3);
  await page.waitForTimeout(1200);
  await expect(page.locator('#status')).toBeVisible();
  await expect(page.locator('#canvas')).toHaveAttribute('inert');
  await expect(page.locator('#game-status')).toHaveText(initial);
  await page.screenshot({ path: testInfo.outputPath('real-ready-playground.png'), scale: 'css' });
  await pressGamepad(page, 9);
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#game-status')).toHaveText(initial);
  await page.screenshot({ path: testInfo.outputPath('real-entered-game.png'), scale: 'css' });
  await pressGamepad(page, 3);
  await expect(page.locator('#game-status')).toContainText("Pip's room opened.");
});

for (const input of ['touch', 'keyboard', 'mouse']) test(`ready loading playground waits for deliberate ${input} entry`, async ({ page }, testInfo) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page);
  const button = page.getByRole('button', { name: 'Enter game', exact: true });
  await expect(button).toBeDisabled();
  await button.dispatchEvent('click');
  await expect(page.locator('#status')).toBeVisible();
  await page.locator('#loading-toy').focus();
  await page.keyboard.down('Enter');
  await page.evaluate(() => {
    window.reveals = 0;
    wordBuddiesHost.ready(() => { window.reveals++; });
    wordBuddiesHost.ready(() => { throw new Error('Duplicate readiness replaced the callback'); });
  });
  await page.clock.runFor(2000);
  await expect(button).toBeEnabled();
  await expect(page.locator('#loading-toy')).toBeFocused();
  await page.keyboard.up('Enter');
  await page.locator('#loading-toy').tap();
  await page.locator('#loading-duck').tap();
  await expect(page.locator('#loading-score')).toHaveText('2 sparkles');
  await page.clock.runFor(60000);
  await expect(page.locator('#status')).toHaveAttribute('data-state', 'ready');
  await expect(page.locator('#status')).toBeVisible();
  await expect(page.locator('#loading-percent')).toHaveText('100%');
  await expect(page.locator('#retry')).toBeHidden();
  await expect(page.locator('#canvas')).toHaveAttribute('inert');
  expect(await page.evaluate(() => window.reveals)).toBe(0);
  if (input === 'touch') {
    for (const viewport of [{ width: 1366, height: 768 }, { width: 390, height: 844 },
      { width: 844, height: 390 }, { width: 320, height: 568 }, { width: 320, height: 320 }]) {
      await page.setViewportSize(viewport);
      const bounds = await button.boundingBox();
      expect(bounds.height).toBeGreaterThanOrEqual(48);
      expect(bounds.y).toBeGreaterThanOrEqual(0);
      expect(bounds.y + bounds.height).toBeLessThanOrEqual(viewport.height);
      expect(await page.locator('#status').evaluate(element => element.scrollHeight <= element.clientHeight)).toBe(true);
      await page.screenshot({ path: testInfo.outputPath(`ready-to-enter-${viewport.width}x${viewport.height}.png`), scale: 'css' });
    }
    await button.tap();
  } else if (input === 'keyboard') {
    await page.locator('#loading-music').focus();
    await page.keyboard.press('Tab');
    await expect(button).toBeFocused();
    await page.keyboard.press('Enter');
  } else await button.click();
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#canvas')).toBeFocused();
  await expect(page.locator('#canvas')).not.toHaveAttribute('inert');
  await expect(page.locator('#loading-toy')).toBeDisabled();
  await expect(page.locator('#loading-duck')).toHaveAttribute('data-queued', '0');
  await page.evaluate(() => { document.getElementById('enter-game').dispatchEvent(new Event('click')); wordBuddiesHost.ready(); });
  expect(await page.evaluate(() => window.reveals)).toBe(1);
});

test('a controller Start held before readiness cannot enter on release', async ({ page }) => {
  await installGamepad(page, { connected: true, heldButtons: [9] });
  await progressShell(page);
  await page.evaluate(() => wordBuddiesHost.ready());
  await expect(page.locator('#enter-game')).toBeEnabled();
  await page.evaluate(() => gamepadFixture.button(9, false));
  await page.waitForTimeout(120);
  await expect(page.locator('#status')).toBeVisible();
  await pressGamepad(page, 0);
  await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  await expect(page.locator('#status')).toBeVisible();
  await pressGamepad(page, 9);
  await expect(page.locator('#status')).toBeHidden();
});

test('an engine failure while waiting for entry removes entry and keeps Retry actionable', async ({ page }) => {
  await progressShell(page);
  await page.evaluate(() => { window.reveals = 0; wordBuddiesHost.ready(() => { window.reveals++; }); });
  await expect(page.locator('#enter-game')).toBeEnabled();
  await page.evaluate(() => window.dispatchEvent(new PromiseRejectionEvent('unhandledrejection', {
    promise: Promise.resolve(), reason: new WebAssembly.RuntimeError('Runtime stopped while waiting')
  })));
  await expect(page.locator('#message')).toContainText('Runtime stopped while waiting');
  await expect(page.locator('#enter-game')).toBeHidden();
  await expect(page.locator('#retry')).toBeFocused();
  await expect(page.locator('#canvas')).toHaveAttribute('inert');
  await page.evaluate(() => document.getElementById('enter-game').dispatchEvent(new Event('click')));
  expect(await page.evaluate(() => window.reveals)).toBe(0);
});

test('loading holds 98 percent until the game is ready', async ({ page }, testInfo) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page);
  await expect(page.locator('#progress')).not.toHaveAttribute('value');
  await expect(page.locator('#message')).toContainText('Loading');
  await page.evaluate(() => window.reportDownload(2 * 1048576, 10 * 1048576));
  await page.clock.runFor(5000);
  await expect(page.locator('#loading-percent')).toHaveText('20%');
  await expect(page.locator('#download-status')).toContainText('2.0 / 10.0 MB');
  await page.evaluate(() => window.reportDownload(6 * 1048576, 10 * 1048576));
  await page.clock.runFor(1500);
  await expect(page.locator('#loading-percent')).toHaveText('60%');
  await page.screenshot({ path: testInfo.outputPath('real-download-60-percent.png'), scale: 'css' });
  await page.evaluate(() => window.reportDownload(99, 100));
  await page.clock.runFor(1500);
  await expect(page.locator('#loading-percent')).toHaveText('98%');
  await expect(page.locator('#progress')).toHaveAttribute('value', '0.98');
  await page.evaluate(() => window.reportDownload(10 * 1048576, 10 * 1048576));
  await page.clock.runFor(500);
  await expect(page.locator('#message')).toHaveText('Loading game...');
  await expect(page.locator('#progress')).toHaveAttribute('value', '0.98');
  await expect(page.locator('#progress')).toHaveAttribute('aria-label', 'Game loading progress');
  await expect(page.locator('#loading-percent')).toHaveText('98%');
  await expect(page.locator('#download-status')).toHaveText('Getting ready to play...');
  await page.clock.runFor(30000);
  await expect(page.locator('#loading-percent')).toHaveText('98%');
  await expect(page.locator('#progress')).toHaveAttribute('value', '0.98');
  await expect(page.locator('body')).not.toHaveAttribute('data-engine-ready', 'true');
  await page.getByRole('button', { name: 'Tap or wiggle the treasure chest' }).click();
  await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  await page.screenshot({ path: testInfo.outputPath('preparing-game-98-percent.png'), scale: 'css' });
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await page.clock.runFor(500);
  await expect(page.locator('#loading-percent')).toHaveText('100%');
  await enterGame(page);
  await expect(page.locator('#status')).toBeHidden();
});

test('a real engine waiting to initialize keeps 98 percent visible and can finish loading', async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    const instantiate = WebAssembly.instantiate;
    const held = new Promise(resolve => { window.finishInitialization = resolve; });
    WebAssembly.instantiateStreaming = async (response, imports) => {
      const bytes = await (await response).arrayBuffer();
      await held;
      return instantiate(bytes, imports);
    };
  });
  await page.goto('/');
  await expect(page.locator('#loading-percent')).toHaveText('98%');
  await expect(page.locator('#progress')).toHaveAttribute('value', '0.98');
  await expect(page.locator('#message')).toHaveText('Loading game...');
  await page.screenshot({ path: testInfo.outputPath('real-engine-preparing-98-percent.png'), scale: 'css' });
  await page.evaluate(() => window.finishInitialization());
  await enterGame(page);
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#loading-percent')).toHaveText('100%');
});

test('early readiness completes the milestones and failed startup never finishes progress', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page);
  await page.evaluate(() => {
    window.loadingValues = [];
    const bar = document.getElementById('progress');
    new MutationObserver(() => window.loadingValues.push(bar.value))
      .observe(bar, { attributes: true, attributeFilter: ['value'] });
  });
  await page.evaluate(() => window.reportDownload(100, 100));
  await page.clock.runFor(100);
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await expect(page.locator('#status')).toBeVisible();
  await page.evaluate(() => window.wordBuddiesHost.ready());
  await page.clock.runFor(2000);
  expect(await page.evaluate(() => [...new Set(window.loadingValues)]
    .filter(value => [0.2, 0.5, 0.8, 0.98, 1].includes(value))))
    .toEqual([0.2, 0.5, 0.8, 0.98, 1]);
  await expect(page.locator('#loading-percent')).toHaveText('100%');
  await enterGame(page);
  await expect(page.locator('#status')).toBeHidden();
  await page.clock.runFor(5000);
  await expect(page.locator('#loading-percent')).toHaveText('100%');
  await page.reload();
  await page.evaluate(() => window.reportDownload(25, 100));
  await page.clock.runFor(100);
  const interrupted = await page.locator('#loading-percent').textContent();
  expect(parseInt(interrupted)).toBeGreaterThan(0);
  expect(parseInt(interrupted)).toBeLessThan(25);
  await page.evaluate(() => window.wordBuddiesHost.fail('The game could not start.'));
  await page.clock.runFor(5000);
  await page.evaluate(() => window.reportDownload(100, 100));
  await expect(page.locator('#loading-percent')).toHaveText(interrupted);
  await expect(page.locator('#retry')).toBeVisible();
  await expect(page.locator('#download-status')).toBeHidden();
});

test('unknown totals stay indeterminate and time or visibility never invents progress', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await progressShell(page);
  await page.evaluate(() => window.reportDownload(1048576, 0));
  await page.clock.runFor(2000);
  await expect(page.locator('#loading-percent')).toBeEmpty();
  await expect(page.locator('#progress')).not.toHaveAttribute('value');
  await expect(page.locator('#download-status')).toContainText('1.0 MB');
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.runFor(5000);
  await expect(page.locator('#loading-percent')).toBeEmpty();
  await page.evaluate(() => {
    delete document.hidden;
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.runFor(1300);
  await expect(page.locator('#loading-percent')).toBeEmpty();
  await page.evaluate(() => window.reportDownload(2, 10));
  await page.clock.runFor(32);
  await expect(page.locator('#loading-percent')).toHaveText('20%');
  await page.evaluate(() => window.reportDownload(1, 10));
  await expect(page.locator('#loading-percent')).toHaveText('10%');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.evaluate(() => window.reportDownload(8, 10));
  await page.clock.runFor(100);
  expect(await page.locator('#progress').evaluate(element => element.value)).toBeLessThan(0.8);
  await page.evaluate(() => window.reportDownload(11, 10));
  await page.clock.runFor(3000);
  await expect(page.locator('#progress')).not.toHaveAttribute('value');
  await expect(page.locator('#loading-percent')).toBeEmpty();
});

test('loading chest taps have no browser highlight but keyboard focus stays visible', async ({ page }) => {
  await whileEngineScriptIsPending(page, async toy => {
    // Desktop WebKit builds do not implement the mobile tap-highlight property.
    if (await page.evaluate(() => CSS.supports('-webkit-tap-highlight-color', 'transparent'))) {
      await expect(toy).toHaveCSS('-webkit-tap-highlight-color', 'rgba(0, 0, 0, 0)');
    }
    await expect(toy).toHaveCSS('appearance', 'none');
    for (let i = 0; i < 7; i++) await toy.tap();
    await expect(page.locator('#loading-score')).toHaveText('7 sparkles');
    expect(await page.evaluate(() => String(window.getSelection()))).toBe('');
    await expect(toy).toHaveCSS('outline-style', 'none');
    await toy.focus();
    await page.keyboard.press('Enter');
    await expect(page.locator('#loading-score')).toHaveText('8 sparkles');
    await expect(toy).toHaveCSS('outline-style', 'solid');
    await expect(toy).toHaveCSS('outline-width', '3px');
    await expect(toy).toHaveCSS('touch-action', 'pinch-zoom');
  });
});

test('Pip is an inline loading companion with bounded, motion-safe reactions', async ({ page }) => {
  const imageRequests = [];
  page.on('request', request => {
    if (/pip\.svg|PIP_MASCOT_URI/.test(request.url())) imageRequests.push(request.url());
  });
  await whileEngineScriptIsPending(page, async () => {
    const duck = page.getByRole('button', { name: 'Dance with Pip the duck' });
    await expect(duck).toBeVisible();
    await expect(duck.locator('svg')).toHaveCount(1);
    await expect(duck.locator('[id^="loading-pip-"]')).toHaveCount(6);
    for (let tap = 0; tap < 8; tap++) await duck.click();
    await expect(page.locator('#loading-score')).toHaveText('0 sparkles');
    expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBeLessThanOrEqual(6);
    await expect(duck).toHaveAttribute('data-queued', '0');
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await duck.click();
    expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
    expect(imageRequests).toEqual([]);
  });
});

for (const elapsed of [400, 1080]) {
  test(`failure during completion at ${elapsed}ms cancels the pending game reveal`, async ({ page }) => {
    await page.clock.install();
    await page.clock.pauseAt(new Date());
    await progressShell(page);
    await page.evaluate(() => window.wordBuddiesHost.ready());
    await page.clock.runFor(elapsed);
    await expect(page.locator('#status')).toBeVisible();
    if (elapsed === 1080) await expect(page.locator('#loading-percent')).toHaveText('100%');
    await page.evaluate(() => window.wordBuddiesHost.fail('The game could not start.'));
    await page.clock.runFor(5000);
    await expect(page.locator('#status')).toBeVisible();
    await expect(page.locator('#canvas')).toHaveAttribute('inert');
    await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'false');
    await expect(page.locator('#retry')).toBeVisible();
  });
}

test('a reveal callback error shows retry instead of leaving the completed loader stuck', async ({ page }) => {
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await progressShell(page);
  await page.evaluate(() => window.wordBuddiesHost.ready(() => { throw new Error('Game resume failed.'); }));
  await page.clock.runFor(2000);
  await enterGame(page);
  await expect(page.locator('#message')).toContainText('Game resume failed.');
  await expect(page.locator('#status')).toBeVisible();
  await expect(page.locator('#canvas')).toHaveAttribute('inert');
  await expect(page.locator('#retry')).toBeVisible();
});

test('every Pip tap gives visible feedback with reduced motion without awarding chest sparkles', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await whileEngineScriptIsPending(page, async toy => {
    const duck = page.getByRole('button', { name: 'Dance with Pip the duck' });
    const hint = page.locator('#loading-hint');
    await expect(duck).toHaveAttribute('data-activity', 'idle');
    let previous = await hint.textContent();
    let previousParts;
    const reactions = [];
    for (let tap = 0; tap < 6; tap++) {
      await duck.click();
      const pose = await reactionPose(page);
      if (reactions.length) expect(pose).not.toBe(reactions.at(-1));
      reactions.push(pose);
      await expect(hint).not.toHaveText(previous, { timeout: 1000 });
      previous = await hint.textContent();
      await expect(hint).toContainText('Pip');
      await expect(page.locator('#loading-score')).toHaveText('0 sparkles');
      const frames = await samplePipMotion(page, 120);
      expect(frames.every(frame => frame.activity === 'reacting' && frame.pose === pose)).toBe(true);
      const parts = JSON.stringify(frames[0].parts);
      expect(new Set(frames.map(frame => JSON.stringify(frame.parts))).size).toBe(1);
      if (previousParts) expect(parts, 'Each new reaction has a distinct static pose.').not.toBe(previousParts);
      previousParts = parts;
      expect(await duck.evaluate(element => element.getAnimations({ subtree: true }).length)).toBe(0);
    }
    expect([...reactions.slice(0, 3)].sort()).toEqual(PIP_REACTIONS);
    expect([...reactions.slice(3, 6)].sort()).toEqual(PIP_REACTIONS);
    await toy.click();
    await expect(hint).toContainText('Boing!');
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  });
});

test('repeated clicks around the loading chest do not select its caption', async ({ page }) => {
  await whileEngineScriptIsPending(page, async toy => {
    await toy.dblclick();
    await page.locator('#loading-hint').dblclick();
    expect(await page.evaluate(() => String(window.getSelection()))).toBe('');
    await expect(page.locator('#loading-play')).toHaveCSS('-webkit-user-select', 'none');
  });
});

test('loading taps vary the chest reaction and celebrate every five sparkles', async ({ page }) => {
  await whileEngineScriptIsPending(page, async toy => {
    await toy.click();
    await expect(page.locator('#loading-hint')).toContainText('Boing!');
    await toy.click();
    await expect(page.locator('#loading-hint')).toContainText('Peekaboo!');
    expect(await page.locator('#chest-lid').evaluate(el => el.getAnimations().length)).toBeGreaterThan(0);
    for (let i = 0; i < 3; i++) await toy.dispatchEvent('click');
    await expect(page.locator('#loading-score')).toHaveText('5 sparkles');
    await expect(page.locator('#loading-hint')).toContainText('Star party!');
    expect(await page.locator('#loading-surprise').evaluate(el => el.getAnimations().length)).toBeGreaterThan(0);
    expect(await page.locator('#loading-sparks > *').count()).toBeLessThanOrEqual(12);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    for (let i = 0; i < 5; i++) await toy.dispatchEvent('click');
    await expect(page.locator('#loading-score')).toHaveText('10 sparkles');
    await expect(page.locator('#loading-hint')).toContainText('Star party!');
    expect(await page.locator('#loading-play').evaluate(el => el.getAnimations({ subtree: true }).length)).toBe(0);
  });
});

test('Xbox A plays with the HTML chest once per press before the engine arrives', async ({ page }) => {
  await installGamepad(page);
  await whileEngineScriptIsPending(page, async () => {
    await page.evaluate(() => window.gamepadFixture.connect());
    await page.evaluate(() => window.gamepadFixture.button(0, true));
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await page.waitForTimeout(300);
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await page.evaluate(() => window.gamepadFixture.button(0, false));
    await page.waitForTimeout(120);
    await pressGamepad(page, 0);
    await expect(page.locator('#loading-score')).toHaveText('2 sparkles');
    await page.evaluate(() => window.gamepadFixture.disconnect());
  });
});

test('quick Xbox taps are caught within two rendered frames', async ({ page }) => {
  await installGamepad(page, { connected: true });
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await whileEngineScriptIsPending(page, async () => {
    await page.evaluate(() => window.gamepadFixture.button(0, true));
    await page.clock.runFor(34);
    await page.evaluate(() => window.gamepadFixture.button(0, false));
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  });
});

test('loading controller polling stops when hidden or disconnected and ignores a held resume', async ({ page }) => {
  await installGamepad(page);
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await whileEngineScriptIsPending(page, async () => {
    const polls = () => page.evaluate(() => window.gamepadFixture.polls);
    const initial = await polls();
    await page.clock.runFor(240);
    expect(await polls()).toBe(initial);
    await page.evaluate(() => {
      window.gamepadFixture.connect();
      window.gamepadFixture.button(0, true);
    });
    await page.clock.runFor(120);
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await page.evaluate(() => {
      Object.defineProperty(document, 'hidden', { configurable: true, value: true });
      document.dispatchEvent(new Event('visibilitychange'));
    });
    const hidden = await polls();
    await page.clock.runFor(240);
    expect(await polls()).toBe(hidden);
    expect(await page.locator('#loading-play').evaluate(el => el.getAnimations({ subtree: true }).length)).toBe(0);
    await page.evaluate(() => {
      delete document.hidden;
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await page.clock.runFor(120);
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await page.evaluate(() => window.gamepadFixture.button(0, false));
    await page.clock.runFor(120);
    await page.evaluate(() => window.gamepadFixture.button(0, true));
    await page.clock.runFor(120);
    await expect(page.locator('#loading-score')).toHaveText('2 sparkles');
    await page.evaluate(() => window.gamepadFixture.disconnect());
    const disconnected = await polls();
    await page.clock.runFor(240);
    expect(await polls()).toBe(disconnected);
  });
});

for (const support of ['unavailable', 'blocked']) {
  test(`the loading toy still works when the Gamepad API is ${support}`, async ({ page }) => {
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(support => {
      Object.defineProperty(navigator, 'getGamepads', {
        value: support === 'unavailable' ? undefined : () => {
          throw new DOMException('Disabled by the embedding permissions policy.', 'SecurityError');
        }
      });
    }, support);
    await whileEngineScriptIsPending(page, async toy => {
      await toy.tap();
      await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
      await expect(page.locator('#retry')).toBeHidden();
      expect(errors).toEqual([]);
    });
  });
}

for (const extension of ['wasm', 'pck']) {
  test(`an interrupted ${extension} response body does not strand the loading screen`, async ({ page }) => {
    await useMaintainedShell(page);
    await page.addInitScript(extension => {
      const originalFetch = window.fetch;
      window.fetch = (resource, options) => {
        if (String(resource).endsWith('.' + extension)) {
          return Promise.resolve(new Response(new ReadableStream({
            start(controller) {
              controller.enqueue(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0]));
              setTimeout(() => controller.error(new TypeError('Network connection lost while reading the download.')), 100);
            }
          }), { headers: { 'Content-Type': extension === 'wasm' ? 'application/wasm' : 'application/octet-stream' } }));
        }
        return originalFetch(resource, options);
      };
    }, extension);
    await page.goto('/loader-test');
    await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 4000 });
    await expect(page.locator('#retry')).toBeVisible();
    await expect(page.locator('#loading-play')).toBeHidden();
  });
}

test('the loading toy works before the engine script arrives and fits small screens', async ({ page }) => {
  await useMaintainedShell(page);
  await page.clock.install();
  let release;
  const held = new Promise(resolve => { release = resolve; });
  await page.route(/\/engine-[a-f0-9]{16}\.js$/, async route => {
    await held;
    await route.continue();
  });
  try {
    await page.goto('/loader-test', { waitUntil: 'commit' });
    const toy = page.getByRole('button', { name: 'Tap or wiggle the treasure chest' });
    await expect(toy).toBeVisible({ timeout: 3000 });
    await toy.tap();
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    await toy.focus();
    await page.keyboard.press('Enter');
    await expect(page.locator('#loading-score')).toHaveText('2 sparkles');
    await expect(page.locator('#progress')).not.toHaveAttribute('value');
    for (const viewport of [{ width: 390, height: 844 }, { width: 844, height: 390 }, { width: 320, height: 320 }]) {
      await page.setViewportSize(viewport);
      const bounds = await toy.boundingBox();
      expect(bounds.y).toBeGreaterThanOrEqual(0);
      expect(bounds.y + bounds.height).toBeLessThanOrEqual(viewport.height);
      expect(await page.locator('#status').evaluate(el => el.scrollHeight <= el.clientHeight)).toBe(true);
    }
    await page.clock.fastForward(17000);
    await expect(page.locator('#loading-note')).toBeVisible();
    expect(await page.locator('#status').evaluate(el => el.scrollHeight <= el.clientHeight)).toBe(true);
  } finally {
    release();
  }
  await enterGame(page);
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#loading-toy')).toBeDisabled();
  await expect(page.locator('#loading-sparks > *')).toHaveCount(0);
  await expect(page.locator('#canvas')).toBeFocused();
});

test('the game pack starts while the first WASM response is still pending', async ({ page }) => {
  await useMaintainedShell(page);
  let release;
  const held = new Promise(resolve => { release = resolve; });
  let packs = 0;
  let wasm = 0;
  page.on('request', request => {
    if (request.url().endsWith('.pck')) packs++;
  });
  await page.route('**/*.wasm', async route => {
    wasm++;
    await held;
    await route.continue();
  });
  try {
    await page.goto('/loader-test');
    await expect.poll(() => wasm).toBe(1);
    await expect.poll(() => packs, { timeout: 3000 }).toBe(1);
    await page.getByRole('button', { name: 'Tap or wiggle the treasure chest' }).click();
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
  } finally {
    release();
  }
  await enterGame(page);
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  expect(wasm).toBe(1);
  expect(packs).toBe(1);
});

test('wiggling the loading toy stays bounded and reduced motion stops all effects', async ({ page }) => {
  await useMaintainedShell(page);
  let release;
  const held = new Promise(resolve => { release = resolve; });
  await page.route('**/*.pck', async route => {
    await held;
    await route.abort();
  });
  try {
    await page.goto('/loader-test?scoutTheme=dark');
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
    for (const selector of ['#loading-title', '#loading-hint', '#message', '#loading-note']) {
      const contrast = await page.locator(selector).evaluate(element => {
        function luminance(color) {
          const channels = color.match(/[\d.]+/g).slice(0, 3).map(value => {
            const channel = Number(value) / 255;
            return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
          });
          return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
        }
        const text = luminance(getComputedStyle(element).color);
        const background = luminance(getComputedStyle(document.getElementById('status')).backgroundColor);
        return (Math.max(text, background) + 0.05) / (Math.min(text, background) + 0.05);
      });
      expect(contrast, selector).toBeGreaterThanOrEqual(4.5);
    }
    const toy = page.getByRole('button', { name: 'Tap or wiggle the treasure chest' });
    await expect(toy).toBeVisible();
    const bounds = await toy.boundingBox();
    await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
    await page.mouse.down();
    await page.mouse.move(bounds.x + bounds.width / 2 + 45, bounds.y + bounds.height / 2, { steps: 4 });
    await page.mouse.up();
    await expect(page.locator('#loading-score')).toHaveText('1 sparkle');
    for (let i = 0; i < 15; i++) await toy.dispatchEvent('click');
    expect(await page.locator('#loading-sparks > *').count()).toBeLessThanOrEqual(12);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect.poll(() => page.locator('#loading-play').evaluate(el =>
      el.getAnimations({ subtree: true }).filter(animation => animation.playState === 'running').length)).toBe(0);
    await toy.click();
    await expect(page.locator('#loading-score')).toHaveText('17 sparkles');
    await expect(page.locator('#loading-sparks > *')).toHaveCount(0);
    expect(await page.locator('#loading-play').evaluate(el => el.getAnimations({ subtree: true }).length)).toBe(0);
  } finally {
    release();
  }
  await expect(page.locator('#message')).toContainText('The game could not start.', { timeout: 15000 });
  await expect(page.locator('#retry')).toBeVisible();
  await expect(page.locator('#loading-play')).toBeHidden();
});
