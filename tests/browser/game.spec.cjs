const { test, expect } = require('@playwright/test');

const errors = new WeakMap();

test.beforeEach(async ({ page }) => {
  const messages = [];
  errors.set(page, messages);
  page.on('pageerror', (error) => messages.push(error.message));
  await page.addInitScript(() => {
    window.__cues = [];
    window.addEventListener('game:audio', (event) => window.__cues.push(event.detail));
  });
  await page.goto('/');
});

test.afterEach(async ({ page }) => {
  expect(errors.get(page)).toEqual([]);
});

async function ids(page) {
  await expect(page.locator('.card')).toHaveCount(8);
  return page.locator('.card:not(:disabled)').evaluateAll((buttons) => {
    const pictures = new Set(buttons.filter((button) => button.dataset.kind === 'image')
      .map((button) => button.dataset.wordId));
    return buttons.filter((button) => button.dataset.kind === 'word' && pictures.has(button.dataset.wordId))
      .map((button) => button.dataset.wordId);
  });
}

async function pair(page, id, reverse = false) {
  const kinds = reverse ? ['image', 'word'] : ['word', 'image'];
  await page.locator(`[data-card-id="${id}:${kinds[0]}"]`).tap();
  await page.locator(`[data-card-id="${id}:${kinds[1]}"]`).tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', /^(waiting|won|lost)$/);
}

async function wrong(page) {
  const [a, b] = await ids(page);
  await page.locator(`[data-card-id="${a}:word"]`).tap();
  await page.locator(`[data-card-id="${b}:image"]`).tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', /^(waiting|lost)$/);
}

async function win(page) {
  for (const id of await ids(page)) await pair(page, id);
  await expect(page.locator('#win-screen')).toBeVisible();
}

async function lose(page) {
  for (let i = 0; i < 3; i += 1) await wrong(page);
  await expect(page.locator('#loss-screen')).toBeVisible();
}

function installAudioGraphStandIn(onlyIfMissing = false) {
  if (onlyIfMissing && (window.AudioContext || window.webkitAudioContext)) return;
  window.AudioContext = class {
    constructor() { this.state = 'running'; this.currentTime = 0; this.destination = {}; }
    createGain() {
      return { gain: { value: 1, setTargetAtTime(value) { this.value = value; } }, connect() {} };
    }
    createMediaElementSource() { return { connect() {} }; }
  };
}

test('waits, changes same-kind selection, and locks feedback against repeated taps', async ({ page }) => {
  const [a, b] = await ids(page);
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await page.locator(`[data-card-id="${a}:image"]`).tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'matching');
  await page.locator(`[data-card-id="${b}:image"]`).tap();
  await expect(page.locator('#error-count')).toHaveText('0');
  await page.locator(`[data-card-id="${b}:word"]`).tap();
  await expect(page.locator('.card:disabled')).toHaveCount(8);
  await page.locator(`[data-card-id="${a}:word"]`).evaluate((button) => button.click());
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await expect(page.locator('#success-count')).toHaveText('1');
  await expect(page.locator('.card.is-matched')).toHaveCount(2);
});

test('theme switching preserves selection and scores and controls the winning chest', async ({ page }) => {
  const [a] = await ids(page);
  await page.locator(`[data-card-id="${a}:word"]`).tap();
  await page.locator('#theme').selectOption('winter');
  await expect(page.locator(`[data-card-id="${a}:word"]`)).toHaveAttribute('aria-pressed', 'true');
  await page.locator(`[data-card-id="${a}:image"]`).tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await page.locator('#theme').selectOption('spring');
  await expect(page.locator('#success-count')).toHaveText('1');
  await win(page);
  await expect(page.locator('#chest-button')).toHaveAttribute('data-theme', 'spring');
});

test('loss shows its illustration and replay clears counters', async ({ page }) => {
  await lose(page);
  await expect(page.locator('#loss-art')).toBeVisible();
  await expect(page.locator('#chest-button')).toBeHidden();
  expect(await page.evaluate(() => window.__cues.filter((cue) => cue.type === 'loss').length)).toBe(1);
  await page.locator('#loss-replay').tap();
  await expect(page.locator('#success-count')).toHaveText('0');
  await expect(page.locator('#error-count')).toHaveText('0');
  await expect(page.locator('.card:not(:disabled)')).toHaveCount(8);
});

for (const [draw, theme] of [[0.1, 'spring'], [0.3, 'summer'], [0.6, 'autumn'], [0.9, 'winter']]) {
  test(`random ${theme} theme opens exactly one matching chest`, async ({ page }) => {
    await page.addInitScript((value) => { Math.random = () => value; }, draw);
    await page.reload();
    await ids(page);
    await expect(page.locator('#app')).toHaveAttribute('data-theme', theme);
    await win(page);
    await page.locator('#chest-button').tap();
    await expect(page.locator('#effects .fx-particle')).toHaveCount(72);
    await expect(page.locator('#effects .fx-ring')).toHaveCount(2);
    await expect(page.locator('#effects .fx-beam')).toHaveCount(1);
    await page.locator('#chest-button').evaluate((button) => button.click());
    await expect(page.locator('#app')).toHaveAttribute('data-chest', 'opened');
    await expect(page.locator('#reward')).toBeVisible();
    expect(await page.evaluate(() => window.__cues.filter((cue) => cue.type === 'open').length)).toBe(1);
    const other = theme === 'winter' ? 'spring' : 'winter';
    await page.locator('#theme').selectOption(other);
    await expect(page.locator('#app')).toHaveAttribute('data-theme', other);
    await expect(page.locator('#chest-button')).toHaveAttribute('data-theme', theme);
    expect(await page.evaluate(() => window.__cues.filter((cue) => cue.type === 'open').length)).toBe(1);
  });
}

test('replay during opening cancels the old callback', async ({ page }) => {
  await win(page);
  await page.locator('#chest-button').tap();
  await page.locator('#win-replay').tap();
  await wrong(page);
  await pair(page, (await ids(page))[0]);
  await pair(page, (await ids(page))[0]);
  await expect(page.locator('#reward')).toHaveJSProperty('hidden', true);
  await expect(page.locator('#app')).toHaveAttribute('data-chest', 'closed');
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await expect(page.locator('#effects')).toBeEmpty();
});

test('the two extra cards are distractors, not a fourth matching pair', async ({ page }) => {
  const pairs = await ids(page);
  expect(pairs).toHaveLength(3);
  const decoy = await page.locator('.card[data-kind="word"]').evaluateAll((buttons, paired) =>
    buttons.find((button) => !paired.includes(button.dataset.wordId)).dataset.cardId, pairs);
  await page.locator(`[data-card-id="${decoy}"]`).tap();
  await page.locator(`[data-card-id="${pairs[0]}:image"]`).tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await expect(page.locator('#error-count')).toHaveText('1');
  await expect(page.locator('#success-count')).toHaveText('0');
  await win(page);
});

async function contained(page) {
  const failures = await page.evaluate(() => {
    const failures = [];
    const containers = [
      document.documentElement, document.body, document.querySelector('#app'),
      document.querySelector('#screens'), ...document.querySelectorAll('.screen:not([hidden])')
    ];
    for (const node of containers) {
      if (node.scrollWidth > node.clientWidth + 1 || node.scrollHeight > node.clientHeight + 1) {
        failures.push(`overflow:${node.id || node.tagName}`);
      }
    }
    for (const node of document.querySelectorAll('button, select')) {
      if (!node.getClientRects().length) continue;
      const box = node.getBoundingClientRect();
      if (box.left < -1 || box.top < -1 || box.right > innerWidth + 1 || box.bottom > innerHeight + 1) {
        failures.push(`outside:${node.id || node.dataset.cardId}`);
      }
      if (box.width < 48 || box.height < 48) {
        failures.push(`small:${node.id || node.dataset.cardId}`);
      }
    }
    return failures;
  });
  expect(failures).toEqual([]);
}

for (const [width, height] of [
  [320, 320], [375, 667], [390, 844], [430, 932], [844, 390],
  [768, 1024], [834, 1194], [1194, 834], [1024, 1366], [507, 1024]
]) {
  test(`all screens fit ${width}x${height}`, async ({ page }) => {
    await page.setViewportSize({ width, height });
    await ids(page);
    await contained(page);
    await win(page);
    await contained(page);
    await page.locator('#chest-button').tap();
    await expect(page.locator('#app')).toHaveAttribute('data-chest', 'opened');
    await contained(page);
    await page.locator('#win-replay').tap();
    await lose(page);
    await contained(page);
  });
}

test('rotation and theme changes preserve selection; keyboard and reduced motion work', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const [id] = await ids(page);
  const first = page.locator(`[data-card-id="${id}:word"]`);
  await first.focus();
  await page.keyboard.press('Enter');
  await page.setViewportSize({ width: 1194, height: 834 });
  await page.locator('#theme').selectOption('winter');
  await expect(first).toHaveAttribute('aria-pressed', 'true');
  await page.locator(`[data-card-id="${id}:image"]`).focus();
  await page.keyboard.press('Space');
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await win(page);
  await page.locator('#chest-button').tap();
  await expect(page.locator('#app')).toHaveAttribute('data-chest', 'opened');
  await expect(page.locator('#effects')).toBeEmpty();
  await contained(page);
});

test('mixed results do not end at a combined total of three', async ({ page }) => {
  await wrong(page);
  await pair(page, (await ids(page))[0], true);
  await wrong(page);
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await expect(page.locator('#success-count')).toHaveText('1');
  await expect(page.locator('#error-count')).toHaveText('2');
});

test('invalid JSON vocabulary shows an English error and Retry recovers', async ({ page }) => {
  await page.route('**/words.json', (route) => route.fulfill({
    status: 200, contentType: 'application/json', body: '[]'
  }));
  await page.reload();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'error');
  await expect(page.locator('#load-message')).toContainText('Could not load');
  await page.unroute('**/words.json');
  await page.locator('#retry').tap();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await ids(page);
  await contained(page);
});

test('a missing word picture is visible rather than becoming a broken game card', async ({ page }) => {
  await page.route('**/assets/images/words/cat.svg', (route) => route.abort());
  await page.reload();
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'error');
  await expect(page.locator('#retry')).toBeVisible();
  await contained(page);
});

test('blocked media playback is visible and does not block matching', async ({ page }) => {
  // The Windows WebKit build does not expose AudioContext; isolate the media-play rejection here.
  await page.addInitScript(installAudioGraphStandIn, true);
  await page.addInitScript(() => {
    HTMLMediaElement.prototype.play = function () {
      return Promise.reject(new DOMException('Playback denied', 'NotAllowedError'));
    };
  });
  await page.reload();
  const [id] = await ids(page);
  await page.locator(`[data-card-id="${id}:word"]`).tap();
  await expect(page.locator('#audio-status')).toContainText('Listen');
  await page.locator(`[data-card-id="${id}:image"]`).tap();
  await expect(page.locator('#success-count')).toHaveText('1');
  await expect(page.locator('#app')).toHaveAttribute('data-phase', 'waiting');
  await contained(page);
});

test('unsupported audio displays a clear message without blocking the game', async ({ page }) => {
  await page.addInitScript(() => {
    window.AudioContext = undefined;
    window.webkitAudioContext = undefined;
  });
  await page.reload();
  const [id] = await ids(page);
  await pair(page, id);
  await expect(page.locator('#audio-status')).toContainText('Audio is not supported');
  await expect(page.locator('#success-count')).toHaveText('1');
});

test('UI reaches generated word audio, theme BGM and mute controls', async ({ page }) => {
  await page.addInitScript(installAudioGraphStandIn);
  await page.addInitScript(() => {
    window.__audio = [];
    window.Audio = class {
      constructor() {
        this.src = '';
        this.paused = true;
        this.readyState = 4;
        this.error = null;
        this.events = {};
      }
      addEventListener(name, listener) { this.events[name] = listener; }
      play() {
        this.paused = false;
        window.__audio.push(this.src);
        this.events.playing?.();
        return Promise.resolve();
      }
      pause() { this.paused = true; this.events.pause?.(); }
      load() {}
    };
  });
  await page.reload();
  const [id] = await ids(page);
  expect(await page.evaluate(() => window.__audio)).toEqual([]);
  await page.locator(`[data-card-id="${id}:word"]`).tap();
  expect(await page.evaluate(() => window.__audio)).toContain(`assets/audio/voice/word-${id}.wav`);
  await page.locator('#theme').selectOption('winter');
  expect(await page.evaluate(() => window.__audio)).toContain('assets/audio/bgm/winter.wav');
  await page.locator('#mute').tap();
  const count = await page.evaluate(() => window.__audio.length);
  await page.locator('#listen').tap();
  expect(await page.evaluate(() => window.__audio.length)).toBe(count);
  await page.locator('#mute').tap();
  expect(await page.evaluate(() => window.__audio.length)).toBeGreaterThan(count);
});

test('all requested resources stay on the local static origin', async ({ page }) => {
  const remote = [];
  await page.route('**/*', (route) => {
    if (new URL(route.request().url()).origin !== 'http://127.0.0.1:4173') {
      remote.push(route.request().url());
      return route.abort();
    }
    return route.continue();
  });
  await page.reload();
  await win(page);
  await page.locator('#chest-button').tap();
  await expect(page.locator('#reward')).toBeVisible();
  expect(remote).toEqual([]);
});
