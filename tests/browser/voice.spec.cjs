const { test, expect } = require('@playwright/test');
const { boardPoint, chooseMode, chooseTheme, contentBounds, headerPoint, headerIconRect, uiScale, rendered, observeAudio, metrics: logicalMetrics, tap } = require('./game-ui.cjs');

async function installRecognition(page, api = 'standard') {
  await page.addInitScript(({ api }) => {
    const fixture = { instances: [], starts: 0, aborts: 0 };
    class Recognition {
      constructor() { this.results = []; this.running = false; fixture.instances.push(this); }
      start() {
        if (this.running) throw new DOMException('Already started', 'InvalidStateError');
        this.running = true;
        fixture.starts++;
        this.activationAtStart = navigator.userActivation?.isActive ?? null;
        this.callbacks = { start: this.onstart, result: this.onresult, error: this.onerror, end: this.onend };
        queueMicrotask(() => this.callbacks.start?.());
      }
      abort() {
        this.running = false;
        fixture.aborts++;
        const callbacks = this.callbacks;
        queueMicrotask(() => { callbacks?.error?.({ error: 'aborted' }); callbacks?.end?.(); });
      }
      emit(transcript, isFinal = true) {
        const result = Object.assign([{ transcript, confidence: 0.95 }], {
          isFinal, item(index) { return this[index]; }
        });
        const resultIndex = this.results.length && !this.results.at(-1).isFinal
          ? this.results.length - 1 : this.results.length;
        this.results[resultIndex] = result;
        this.results.item = index => this.results[index];
        this.callbacks.result?.({ resultIndex, results: this.results });
      }
      end() { this.running = false; this.callbacks.end?.(); }
      error(error) { this.callbacks.error?.({ error }); this.end(); }
    }
    Object.defineProperty(window, 'SpeechRecognition', {
      configurable: true, value: api === 'standard' ? Recognition : undefined
    });
    Object.defineProperty(window, 'webkitSpeechRecognition', {
      configurable: true, value: api === 'prefixed' ? Recognition : undefined
    });
    if (navigator.mediaDevices) {
      navigator.mediaDevices.getUserMedia = () => {
        throw new Error('Voice tests must never request the physical microphone');
      };
    }
    fixture.emit = (text, final = true) => fixture.instances.at(-1).emit(text, final);
    fixture.end = () => fixture.instances.at(-1).end();
    fixture.error = code => fixture.instances.at(-1).error(code);
    window.speechFixture = fixture;
  }, { api });
}

async function openGame(page, api = 'standard') {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await installRecognition(page, api);
  await page.goto('/');
  await expect(page.locator('body')).toHaveAttribute('data-engine-ready', 'true', { timeout: 60000 });
  await expect(page.locator('#status')).toBeHidden();
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  await expect(page.locator('#speech-panel')).toBeHidden();
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(0);
  return errors;
}

async function metrics(page) {
  return page.locator('#canvas').evaluate(canvas => {
    const rect = canvas.getBoundingClientRect();
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
  });
}

function cardPoint(bounds, index) {
  const scale = Math.min(bounds.width, bounds.height) / 480;
  const point = boardPoint({ width: bounds.width / scale, height: bounds.height / scale, scale }, index);
  return { x: bounds.x + point.x * scale, y: bounds.y + point.y * scale };
}
async function discoverBoard(page) {
  const bounds = await metrics(page);
  const cards = new Map();
  for (let index = 0; index < 8; index++) {
    const point = cardPoint(bounds, index);
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
    const [kind, word] = (await page.locator('#selection-status').textContent()).split(': ');
    if (!cards.has(word)) cards.set(word, {});
    cards.get(word)[kind] = index;
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  }
  const pairs = [...cards].filter(([, card]) => card.Word !== undefined && card.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  return { pairs, bounds };
}

async function toggleVoice(page, edge = false) {
  await rendered(page);
  const bounds = await logicalMetrics(page), point = headerPoint(bounds, 'voice');
  if (edge) point.x = headerIconRect(bounds, 'voice').x + 1 / bounds.scale;
  await tap(page, point.x, point.y);
}

async function listen(page) {
  await toggleVoice(page);
  await expect(page.locator('#speech-panel')).toBeVisible();
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-state', 'listening');
  await expect(page.locator('#speech-button')).toHaveCount(0);
  await expect(page.locator('#speech-notice')).toContainText(/browser.*remotely/i);
  await expect(page.locator('#speech-notice')).toContainText(/(?:save|store)s? no voice or transcripts/i);
  await rendered(page);
}

test('Voice is a prominent primary action without automatic recording', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const errors = await openGame(page);
  await chooseTheme(page, 4);
  await page.mouse.move(0, 0);
  await rendered(page);
  const bounds = await logicalMetrics(page), rect = headerIconRect(bounds, 'voice');
  const clip = { x: bounds.x + rect.x * bounds.scale, y: bounds.y + rect.y * bounds.scale,
    width: rect.width * bounds.scale, height: rect.height * bounds.scale };
  const available = await page.screenshot({ path: testInfo.outputPath('voice-primary-ready.png'), clip, scale: 'css' });
  const fraction = await page.evaluate(async encoded => {
    const image = new Image(); image.src = 'data:image/png;base64,' + encoded; await image.decode();
    const canvas = document.createElement('canvas'); canvas.width = image.width; canvas.height = image.height;
    const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    let filled = 0;
    for (let index = 0; index < pixels.length; index += 4) {
      if (Math.abs(pixels[index] - 0x13) + Math.abs(pixels[index + 1] - 0x75) + Math.abs(pixels[index + 2] - 0x8b) < 40) filled++;
    }
    return filled / (pixels.length / 4);
  }, available.toString('base64'));
  expect(fraction, 'The microphone has a filled theme surface, not a faint outline-only icon.').toBeGreaterThan(0.5);
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(0);
  await listen(page);
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(1);
  const active = await page.screenshot({ path: testInfo.outputPath('voice-primary-listening.png'), clip, scale: 'css' });
  expect(active.equals(available)).toBe(false);
  await toggleVoice(page);
  await expect(page.locator('#speech-panel')).toBeHidden();
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(1);
  expect(errors).toEqual([]);
});

for (const viewport of [{ width: 320, height: 568 }, { width: 1366, height: 768 }]) {
test(`Voice starts immediately with an 80px buddy in the 112px panel at ${viewport.width}px`, async ({ page, browserName }, testInfo) => {
  await page.setViewportSize(viewport);
  const errors = await openGame(page);
  expect(await page.evaluate(() => window.wordBuddiesHost.speechAvailable())).toBe(true);
  await listen(page);
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(1);
  const panel = await page.locator('#speech-panel').boundingBox();
  const buddy = await page.locator('#speech-buddy').boundingBox();
  const notice = await page.locator('#speech-notice').boundingBox();
  const bounds = await logicalMetrics(page);
  const expectedHeight = Math.ceil(112 / uiScale(bounds)) * bounds.scale;
  expect(Math.abs(panel.height - expectedHeight)).toBeLessThanOrEqual(1);
  expect(panel.height).toBeGreaterThanOrEqual(111);
  expect(panel.height).toBeLessThanOrEqual(114);
  expect(panel.x).toBeGreaterThanOrEqual(0);
  expect(panel.x + panel.width).toBeLessThanOrEqual(viewport.width);
  await expect(page.locator('#speech-buddy')).toHaveCSS('width', '80px');
  await expect(page.locator('#speech-buddy')).toHaveCSS('height', '80px');
  expect(buddy.y).toBeGreaterThanOrEqual(panel.y);
  expect(buddy.y + buddy.height).toBeLessThanOrEqual(panel.y + panel.height);
  expect(notice.x).toBeGreaterThan(buddy.x + buddy.width);
  expect(notice.y + notice.height).toBeLessThanOrEqual(panel.y + panel.height + 1);
  await page.evaluate(() => window.speechFixture.emit('I see a friendly little duck beside a bright red rocket and a cheerful turtle', false));
  const layout = await page.locator('#speech-panel').evaluate(element => {
    const panel = element.getBoundingClientRect();
    const text = document.getElementById('speech-transcript'), notice = document.getElementById('speech-notice');
    const transcript = text.getBoundingClientRect(), privacy = notice.getBoundingClientRect();
    return { panelBottom: panel.bottom, transcriptBottom: transcript.bottom, privacyBottom: privacy.bottom,
      transcriptFont: parseFloat(getComputedStyle(text).fontSize), privacyFont: parseFloat(getComputedStyle(notice).fontSize),
      privacyLines: notice.clientHeight / parseFloat(getComputedStyle(notice).lineHeight),
      privacyFits: notice.scrollHeight <= notice.clientHeight + 1 };
  });
  expect(layout.transcriptBottom).toBeLessThanOrEqual(layout.panelBottom + 1);
  expect(layout.privacyBottom).toBeLessThanOrEqual(layout.panelBottom + 1);
  expect(layout.transcriptFont).toBeGreaterThanOrEqual(15);
  expect(layout.transcriptFont).toBeLessThanOrEqual(20);
  expect(layout.privacyFont).toBeGreaterThanOrEqual(10);
  expect(layout.privacyFont).toBeLessThanOrEqual(11);
  expect(layout.privacyLines).toBeLessThanOrEqual(3.2);
  expect(layout.privacyFits, 'The complete privacy notice stays visible beside the larger buddy.').toBe(true);
  await page.screenshot({ path: testInfo.outputPath(`voice-panel-${viewport.width}.png`), scale: 'css' });
  expect(await page.evaluate(() => {
    const { starts, instances } = window.speechFixture;
    const current = instances.at(-1);
    return [starts, current.lang, current.interimResults, current.continuous];
  })).toEqual([1, 'en-US', true, true]);
  if (browserName === 'chromium') {
    expect(await page.evaluate(() => window.speechFixture.instances[0].activationAtStart)).toBe(true);
  }
  await page.keyboard.press('Space');
  await expect(page.locator('#speech-panel')).toBeHidden();
  await expect(page.locator('#canvas')).toBeFocused();
  await expect(page.locator('#selection-status')).toBeEmpty();
  await expect(page.locator('#game-status')).toContainText('Voice off.');
  await page.keyboard.press('Enter');
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-state', 'listening');
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(2);
  await toggleVoice(page, true);
  await expect(page.locator('#speech-panel')).toBeHidden();
  expect(errors).toEqual([]);
});
}

test('the listening buddy cycles nod, wave and tilt without a speaking pose', async ({ page }, testInfo) => {
  const errors = await openGame(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await listen(page);
  await expect.poll(() => page.locator('#speech-meter').evaluate(element =>
    element.getAnimations({ subtree: true }).filter(animation => animation.playState === 'running').length
  )).toBe(5);
  await expect(page.locator('#speech-buddy')).toHaveCSS('animation-name', 'pip-listen');
  for (const [index, reaction] of ['nod', 'wave', 'tilt'].entries()) {
    const observed = await page.evaluate(({ index, reaction }) => {
      window.speechFixture.emit(`I see word number ${index + 1}`, false);
      const panel = document.getElementById('speech-panel'), buddy = document.getElementById('speech-buddy');
      const sprite = buddy.querySelector('.duck-sprite');
      return { heard: panel.getAttribute('data-heard'), reaction: panel.getAttribute('data-reaction'),
        animation: getComputedStyle(buddy).animationName, duration: parseFloat(getComputedStyle(buddy).animationDuration) * 1000,
        spriteX: parseFloat(getComputedStyle(sprite).backgroundPositionX), spriteAnimation: getComputedStyle(sprite).animationName };
    }, { index, reaction });
    expect(observed.heard).toBe('true');
    expect(observed.reaction).toBe(reaction);
    expect(observed.animation).toBe(`pip-${reaction}`);
    expect(observed.duration).toBe(280);
    expect(observed.spriteX).toBeCloseTo([66.6667, 100, 0][index], 1);
    expect(observed.spriteAnimation).toBe('none');
    await expect(page.locator('#speech-panel')).toHaveAttribute('data-heard', 'false', { timeout: 1000 });
    await expect(page.locator('#speech-buddy')).toHaveCSS('animation-name', 'pip-listen');
  }
  await page.screenshot({ path: testInfo.outputPath('voice-listening.png'), scale: 'css' });
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-heard', 'false');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect.poll(() => page.locator('#speech-panel').evaluate(element =>
    element.getAnimations({ subtree: true }).length
  )).toBe(0);
  await page.evaluate(() => window.speechFixture.emit('I see a little doll', false));
  await expect(page.locator('#speech-buddy')).toHaveCSS('transform', 'none');
  await expect(page.locator('#speech-buddy .duck-sprite')).toHaveCSS('background-position-x', '0%');
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-heard', 'false');
  await rendered(page);
  const still = await page.screenshot({ path: testInfo.outputPath('voice-reduced-before.png'), scale: 'css' });
  await page.waitForTimeout(400);
  const later = await page.screenshot({ path: testInfo.outputPath('voice-reduced-after.png'), scale: 'css' });
  expect(later.equals(still), 'Reduced-motion voice presentation stays still.').toBe(true);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await toggleVoice(page);
  await expect(page.locator('#speech-panel')).toBeHidden();
  await expect.poll(() => page.locator('#speech-panel').evaluate(element =>
    element.getAnimations({ subtree: true }).length
  )).toBe(0);
  expect(errors).toEqual([]);
});

test('interim speech does not score; final sentences queue distinct real pairs and stop on win', async ({ page }) => {
  const errors = await openGame(page);
  const { pairs } = await discoverBoard(page);
  await listen(page);
  const waiting = await page.locator('#game-status').textContent();
  const first = pairs[0][0];
  await page.evaluate(word => window.speechFixture.emit(`I see a ${word}`, false), first);
  await expect(page.locator('#speech-transcript')).toHaveText(`I see a ${first}`);
  await page.waitForTimeout(900);
  await expect(page.locator('#game-status')).toHaveText(waiting);
  await page.evaluate(word => window.speechFixture.emit(`I see a ${word.toUpperCase()}!`, true), first);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  await page.evaluate(word => window.speechFixture.emit(`${word} ${word}`, true), first);
  await page.waitForTimeout(900);
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  await page.evaluate(words => window.speechFixture.emit(`A ${words[0]}, ${words[0]} and ${words[1]}!`),
    pairs.slice(1).map(([word]) => word));
  await expect(page.locator('#game-status')).toContainText('You did it!');
  await expect(page.locator('#speech-panel')).toBeHidden();
  await expect(page.locator('#speech-transcript')).toBeEmpty();
  expect(await page.evaluate(() => window.speechFixture.aborts)).toBeGreaterThanOrEqual(1);
  const won = await page.locator('#game-status').textContent();
  await page.evaluate(() => {
    window.speechFixture.emit('doll cat sun');
    window.speechFixture.end();
  });
  await page.waitForTimeout(800);
  await expect(page.locator('#game-status')).toHaveText(won);
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(1);
  expect(errors).toEqual([]);
});

test('turning Voice off during feedback resumes the automatic Match timer', async ({ page }) => {
  const errors = await openGame(page);
  const { pairs } = await discoverBoard(page);
  await listen(page);
  await page.evaluate(word => window.speechFixture.emit(word), pairs[0][0]);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await toggleVoice(page);
  await expect(page.locator('#speech-panel')).toBeHidden();
  await expect(page.locator('#game-status')).toContainText('Voice off.');
  await expect(page.locator('#game-status'), 'No deleted Continue control is required after leaving Voice.').toContainText('Find 3 word', { timeout: 2500 });
  await expect(page.locator('#selection-status')).toBeEmpty();
  expect(errors).toEqual([]);
});

test('matched cards stay quiet and cannot rescore while Voice is listening', async ({ page }) => {
  await observeAudio(page);
  const errors = await openGame(page);
  const { pairs } = await discoverBoard(page);
  await listen(page);
  const [word, pair] = pairs[0];
  await page.evaluate(word => window.speechFixture.emit(word), word);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  const saved = await page.evaluate(() => [localStorage.getItem('wordBuddies.medalProgress'), localStorage.getItem('wordBuddies.playroom')]);
  const starts = await page.evaluate(() => window.audioObservation.starts);
  const bounds = await logicalMetrics(page), panel = await page.locator('#speech-panel').boundingBox();
  const top = (panel.y + panel.height - bounds.y) / bounds.scale + contentBounds(bounds).gap;
  const matched = boardPoint(bounds, pair.Word, { top });
  for (let repeat = 0; repeat < 3; repeat++) {
    await tap(page, matched.x, matched.y);
    await rendered(page);
    await expect(page.locator('#game-status')).toContainText('Find 3 word');
    await expect(page.locator('#selection-status')).toBeEmpty();
    await expect(page.locator('#speech-panel')).toHaveAttribute('data-state', 'listening');
    expect(await page.evaluate(() => window.audioObservation.starts)).toBe(starts);
    expect(await page.evaluate(() => [localStorage.getItem('wordBuddies.medalProgress'), localStorage.getItem('wordBuddies.playroom')])).toEqual(saved);
  }
  await toggleVoice(page);
  await expect(page.locator('#speech-panel')).toBeHidden();
  expect(errors).toEqual([]);
});

test('Voice Pip displays the real round progress supplied by the native game', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = await openGame(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  expect(await page.evaluate(() => typeof window.wordBuddiesHost.roundProgress)).toBe('function');
  const { pairs, bounds } = await discoverBoard(page);
  const word = cardPoint(bounds, pairs[0][1].Word), wrong = cardPoint(bounds, pairs[1][1].Picture);
  await page.touchscreen.tap(word.x, word.y);
  await expect(page.locator('#selection-status')).toHaveText(`Word: ${pairs[0][0]}`);
  await page.touchscreen.tap(wrong.x, wrong.y);
  await expect(page.locator('#game-status')).toContainText('Not quite.');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  await listen(page);
  await expect(page.locator('#speech-successes')).toHaveText('0/3');
  await expect(page.locator('#speech-mistakes')).toHaveText('1/3');
  await expect(page.locator('#speech-successes')).toBeVisible();
  await expect(page.locator('#speech-mistakes')).toBeVisible();
  const buddy = await page.locator('#speech-buddy').boundingBox();
  const panel = await page.locator('#speech-panel').boundingBox();
  for (const selector of ['#speech-successes', '#speech-mistakes']) {
    const count = await page.locator(selector).boundingBox();
    expect(count.x).toBeGreaterThanOrEqual(buddy.x);
    expect(count.x + count.width).toBeLessThanOrEqual(buddy.x + buddy.width + 1);
    expect(count.y).toBeGreaterThanOrEqual(panel.y);
    expect(count.y + count.height).toBeLessThanOrEqual(panel.y + panel.height);
  }
  const before = await page.locator('.speech-score').screenshot({ scale: 'css' });
  await page.evaluate(word => window.speechFixture.emit(word), pairs[0][0]);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await expect(page.locator('#game-status')).toContainText('Find 3 word');
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-heard', 'false');
  await expect(page.locator('#speech-successes')).toHaveText('1/3');
  await expect(page.locator('#speech-mistakes')).toHaveText('1/3');
  await rendered(page);
  const after = await page.locator('.speech-score').screenshot({ scale: 'css' });
  expect(after.equals(before), 'The visible Pip cluster must reflect a real score change, not only a host callback.').toBe(false);
  await page.screenshot({ path: testInfo.outputPath('voice-native-progress.png'), scale: 'css' });
  await toggleVoice(page);
  expect(errors).toEqual([]);
});

test('Voice off clears the panel and stale results cannot interfere with a newer session', async ({ page }) => {
  const errors = await openGame(page);
  const { pairs } = await discoverBoard(page);
  await listen(page);
  await page.evaluate(() => window.speechFixture.emit('unfinished words', false));
  await toggleVoice(page);
  await expect(page.locator('#speech-panel')).toBeHidden();
  await expect(page.locator('#speech-transcript')).toBeEmpty();
  const stopped = await page.locator('#game-status').textContent();
  await page.evaluate(words => {
    window.speechFixture.instances[0].emit(words.join(' '));
    window.speechFixture.instances[0].end();
  }, pairs.map(([word]) => word));
  await page.waitForTimeout(900);
  await expect(page.locator('#game-status')).toHaveText(stopped);
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(1);
  await listen(page);
  await page.evaluate(words => {
    const old = window.speechFixture.instances[0];
    old.emit(words.join(' '));
    old.error('not-allowed');
    old.callbacks.start();
  }, pairs.map(([word]) => word));
  await page.waitForTimeout(900);
  await expect(page.locator('#speech-panel')).toBeVisible();
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-state', 'listening');
  await expect(page.locator('#speech-transcript')).toBeEmpty();
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(2);
  await page.evaluate(word => window.speechFixture.emit(`I see a ${word}`), pairs[0][0]);
  await expect(page.locator('#game-status')).toContainText('Great match!');
  expect(errors).toEqual([]);
});

test('an utterance end resumes listening without asking for another mode toggle', async ({ page }) => {
  const errors = await openGame(page, 'prefixed');
  await listen(page);
  await page.evaluate(() => window.speechFixture.end());
  await expect.poll(() => page.evaluate(() => window.speechFixture.starts)).toBe(2);
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-state', 'listening');
  await page.evaluate(() => window.speechFixture.emit('some live words', false));
  await expect(page.locator('#speech-transcript')).toHaveText('some live words');
  await toggleVoice(page);
  await page.waitForTimeout(900);
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(2);
  await expect(page.locator('#speech-panel')).toBeHidden();
  expect(errors).toEqual([]);
});

test('permission denial stays visible and never retries automatically', async ({ page }) => {
  const errors = await openGame(page);
  await listen(page);
  await page.evaluate(() => window.speechFixture.error('not-allowed'));
  await expect(page.locator('#speech-status')).toContainText(/permission|denied|blocked/i);
  await expect(page.locator('#speech-panel')).toHaveAttribute('data-state', 'error');
  await expect.poll(() => page.locator('#speech-panel').evaluate(element =>
    element.getAnimations({ subtree: true }).filter(animation => animation.playState === 'running').length
  )).toBe(0);
  await page.waitForTimeout(1600);
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(1);
  expect(await page.evaluate(() => window.speechFixture.aborts)).toBeGreaterThanOrEqual(1);
  await page.evaluate(() => window.wordBuddiesHost.stopSpeech());
  await expect(page.locator('#speech-panel')).toBeHidden();
  const point = cardPoint(await metrics(page), 0);
  await page.touchscreen.tap(point.x, point.y);
  await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): [a-z]+$/);
  expect(errors).toEqual([]);
});

test('missing recognition leaves ordinary manual matching available', async ({ page }) => {
  const errors = await openGame(page, 'missing');
  expect(await page.evaluate(() => window.wordBuddiesHost.speechAvailable())).toBe(false);
  const { pairs, bounds } = await discoverBoard(page);
  for (const index of [pairs[0][1].Word, pairs[0][1].Picture]) {
    const point = cardPoint(bounds, index);
    await page.touchscreen.tap(point.x, point.y);
  }
  await expect(page.locator('#game-status')).toContainText('Great match!');
  await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText('Find 3 word–picture pairs.');
  await expect(page.locator('#selection-status')).toBeEmpty();
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(0);
  await expect(page.locator('#speech-panel')).toBeHidden();
  expect(errors).toEqual([]);
});

for (const event of ['visibilitychange', 'pagehide']) {
  test(`${event} releases speech and cannot resume or accept late results`, async ({ page }) => {
    const errors = await openGame(page);
    await listen(page);
    await page.evaluate(event => {
      if (event === 'visibilitychange') {
        Object.defineProperty(document, 'hidden', { configurable: true, value: true });
        document.dispatchEvent(new Event(event));
      } else window.dispatchEvent(new Event(event));
    }, event);
    await expect(page.locator('#speech-panel')).toBeHidden();
    await page.evaluate(() => {
      window.speechFixture.emit('late doll', true);
      window.speechFixture.end();
      delete document.hidden;
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await page.waitForTimeout(900);
    await expect(page.locator('#speech-transcript')).toBeEmpty();
    expect(await page.evaluate(() => window.speechFixture.starts)).toBe(1);
    expect(await page.evaluate(() => window.speechFixture.aborts)).toBeGreaterThanOrEqual(1);
    expect(errors).toEqual([]);
  });
}
