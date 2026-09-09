const { test, expect } = require('@playwright/test');

async function installRecognition(page, api = 'standard') {
  await page.addInitScript(({ api }) => {
    const fixture = { instances: [], starts: 0, aborts: 0 };
    class Recognition {
      constructor() { this.results = []; this.running = false; fixture.instances.push(this); }
      start() {
        if (this.running) throw new DOMException('Already started', 'InvalidStateError');
        this.running = true;
        fixture.starts++;
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
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
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
  const columns = bounds.width >= bounds.height ? 4 : 2;
  const rows = 8 / columns;
  const cellWidth = (bounds.width / scale - 24 - (columns - 1) * 10) / columns;
  const cellHeight = (bounds.height / scale - 184 - (rows - 1) * 10) / rows;
  return {
    x: bounds.x + (12 + (index % columns) * (cellWidth + 10) + cellWidth / 2) * scale,
    y: bounds.y + (172 + Math.floor(index / columns) * (cellHeight + 10) + cellHeight / 2) * scale
  };
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
    await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  }
  const pairs = [...cards].filter(([, card]) => card.Word !== undefined && card.Picture !== undefined);
  expect(pairs).toHaveLength(3);
  return { pairs, bounds };
}

async function enableVoice(page) {
  const bounds = await metrics(page);
  const scale = Math.min(bounds.width, bounds.height) / 480;
  await page.touchscreen.tap(bounds.x + bounds.width - 208 * scale, bounds.y + 48 * scale);
  await expect(page.locator('#speech-panel')).toBeVisible();
  await expect(page.locator('#speech-button')).toHaveText('Listen');
  await expect(page.locator('#speech-button')).toBeFocused();
  await expect(page.locator('#speech-notice')).toContainText(/browser.*remotely/i);
  await expect(page.locator('#speech-notice')).toContainText(/(?:save|store)s? no voice or transcripts/i);
}

async function listen(page) {
  await enableVoice(page);
  await page.locator('#speech-button').click();
  await expect(page.locator('#speech-button')).toHaveText('Stop');
}

test('voice needs a separate Listen gesture and fits the reserved space at 320px', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = await openGame(page);
  expect(await page.evaluate(() => window.wordBuddiesHost.speechAvailable())).toBe(true);
  await enableVoice(page);
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(0);
  const panel = await page.locator('#speech-panel').boundingBox();
  const button = await page.locator('#speech-button').boundingBox();
  const notice = await page.locator('#speech-notice').boundingBox();
  expect(panel.height).toBeGreaterThanOrEqual(73);
  expect(panel.height).toBeLessThanOrEqual(77);
  expect(button.height).toBeGreaterThanOrEqual(48);
  expect(panel.x).toBeGreaterThanOrEqual(0);
  expect(panel.x + panel.width).toBeLessThanOrEqual(320);
  expect(button.y + button.height).toBeLessThanOrEqual(panel.y + panel.height);
  expect(notice.y + notice.height).toBeLessThanOrEqual(panel.y + panel.height + 1);
  await page.screenshot({ path: testInfo.outputPath('voice-panel-320.png'), scale: 'css' });
  await page.keyboard.press('Enter');
  await expect(page.locator('#speech-button')).toHaveText('Stop');
  expect(await page.evaluate(() => {
    const { starts, instances } = window.speechFixture;
    const current = instances.at(-1);
    return [starts, current.lang, current.interimResults, current.continuous];
  })).toEqual([1, 'en-US', true, true]);
  await page.keyboard.press('Space');
  await expect(page.locator('#speech-panel')).toBeHidden();
  await expect(page.locator('#canvas')).toBeFocused();
  await expect(page.locator('#selection-status')).toBeEmpty();
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
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
  await page.evaluate(word => window.speechFixture.emit(`${word} ${word}`, true), first);
  await page.waitForTimeout(900);
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
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

test('Stop clears the panel and stale results cannot score or interfere with a newer session', async ({ page }) => {
  const errors = await openGame(page);
  const { pairs } = await discoverBoard(page);
  await listen(page);
  await page.evaluate(() => window.speechFixture.emit('unfinished words', false));
  await page.locator('#speech-button').click();
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
  await expect(page.locator('#speech-button')).toHaveText('Stop');
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
  await expect(page.locator('#speech-button')).toHaveText('Stop');
  await page.evaluate(() => window.speechFixture.emit('some live words', false));
  await expect(page.locator('#speech-transcript')).toHaveText('some live words');
  await page.locator('#speech-button').click();
  await page.waitForTimeout(900);
  expect(await page.evaluate(() => window.speechFixture.starts)).toBe(2);
  await expect(page.locator('#speech-panel')).toBeHidden();
  expect(errors).toEqual([]);
});

test('permission denial stays visible and never retries automatically', async ({ page }) => {
  const errors = await openGame(page);
  await listen(page);
  await page.evaluate(() => window.speechFixture.error('not-allowed'));
  await expect(page.locator('#speech-notice')).toContainText(/permission|denied|blocked/i);
  await expect(page.locator('#speech-button')).toHaveText('Listen');
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
  await expect(page.locator('#game-status')).toContainText('Find three pairs.');
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
