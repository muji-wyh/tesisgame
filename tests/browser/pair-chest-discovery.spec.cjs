const { test, expect } = require('@playwright/test');
const {
  openGame, metrics, tap, rendered, discoverMatchCards, boardPoint, memoryPoint,
  celebrationState
} = require('./game-ui.cjs');
const {
  watchAudioRequests, observeOutputAudio, expectOutputEnergy, recordingTiming
} = require('./bundled-audio.cjs');

// Preserve phone CSS geometry without multiplying software-renderer fill cost.
test.use({ deviceScaleFactor: 1,
  launchOptions: { ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'] } });

const MESSAGE = 'You found a hidden treasure chest!';
const DISCOVERY = 'assets/audio/pair-chest/discovery.wav';
const MEDAL_KEY = 'wordBuddies.medalProgress';
const GEOMETRIES = [
  { name: 'desktop', width: 1366, height: 768 },
  { name: 'phone', width: 393, height: 852 }
];

test.beforeEach(async ({ page }) => {
  await page.addInitScript(key => {
    // A valid saved pity reservation keeps the reveal on pair one. Starting
    // a real round preserves that reservation; only a real match earns it.
    const state = Object.fromEntries(['match', 'memory'].map(mode => [mode, {
      dry_rounds: 2,
      round: { id: `reserved-${mode}-discovery`, pair: 1, awarded: false,
        settled: false, completed: false, theme: '', fragment: {} }
    }]));
    localStorage.setItem(key, '[medals]\nversion=1\ncounts={}\n[pair_chests]\nversion=1\n' +
      `state=${JSON.stringify(state)}\n`);
  }, MEDAL_KEY);
});

async function discoverMemoryCards(page) {
  const cards = [];
  for (let index = 0; index < 10; index++) {
    const point = memoryPoint(await metrics(page), index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^Memory card \d+\. (Word|Picture): [a-z]+\.$/);
    const [, kind, word] = (await page.locator('#selection-status').textContent()).match(/\. (Word|Picture): ([a-z]+)\.$/);
    cards.push({ index, kind, word });
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  return cards;
}

async function playPair(page, mode, pair) {
  for (const card of pair) {
    const point = (mode === 'match' ? boardPoint : memoryPoint)(await metrics(page), card.index);
    await tap(page, point.x, point.y);
  }
  await expect(page.locator('#game-status')).toContainText(mode === 'match' ? 'Great match!' : 'A new flower!');
}

async function continuePairs(page, mode) {
  if (mode === 'match') await page.keyboard.press('Escape');
  await expect(page.locator('#game-status')).toContainText(mode === 'match' ? 'Find 5 word' : 'Find a pair.');
}

async function discoveryPlaybacks(page, from, timing) {
  return page.evaluate(({ from, timing }) => window.audioObservation.playbacks.slice(from).filter(sound =>
    Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate), { from, timing });
}

async function capture(page, info, label) {
  const screenshot = await page.screenshot({ path: info.outputPath(`${label}.png`), scale: 'css' });
  await info.attach(label, { body: screenshot, contentType: 'image/png' });
}

for (const mode of ['match', 'memory']) {
  for (const geometry of GEOMETRIES) {
    test(`${mode} discovers its hidden chest with one cheer and a readable notice on ${geometry.name}`, async ({ page, browserName }, info) => {
      test.setTimeout(150000);
      await page.setViewportSize({ width: geometry.width, height: geometry.height });
      const requests = watchAudioRequests(page);
      await observeOutputAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 2, trackSourceLifecycle: true });
      const errors = await openGame(page, { mode, reducedMotion: 'no-preference' });
      const available = await page.evaluate(() => window.audioObservation.available);
      if (browserName === 'chromium') expect(available).toBe(true);
      test.skip(!available, 'This browser runtime has no WebAudio.');
      const timing = recordingTiming(DISCOVERY);
      const cards = mode === 'match' ? await discoverMatchCards(page) : await discoverMemoryCards(page);
      const pairs = cards.filter(card => card.kind === 'Word').map(word =>
        [word, cards.find(card => card.kind === 'Picture' && card.word === word.word)]);
      expect(pairs).toHaveLength(5);
      expect(pairs.every(pair => pair[1])).toBe(true);
      const from = await page.evaluate(() => window.audioObservation.playbacks.length);

      await playPair(page, mode, pairs[0]);
      await expect(page.locator('#game-status')).toContainText(MESSAGE);
      // The live region announces acquisition before the flight reaches its
      // reveal. Wait for the actual cheer, so the screenshot captures the
      // visible showcase caption rather than the earlier empty HUD slot.
      let discovery;
      await expect.poll(async () => {
        discovery = (await discoveryPlaybacks(page, from, timing))[0];
        return Boolean(discovery);
      }, { intervals: [25, 50, 100], message: 'The chest showcase starts its bundled discovery cheer.' }).toBe(true);
      await capture(page, info, `${mode}-${geometry.name}-discovery`);
      expect(discovery.contextState).toBe('running');
      expect(discovery.loop).toBe(false);
      expect(discovery.peak, 'The discovered chest plays an audible recording.').toBeGreaterThan(0.01);
      const output = await expectOutputEnergy(page);

      // Native reveal begins at 1.36 s and the whole showcase lasts 3.25 s.
      // Observe real audio time rather than guessing from the earlier notice.
      await page.waitForFunction(at => performance.now() - at >= 2300, discovery.at);
      await rendered(page);
      expect((await metrics(page)).growth.settlement.visible,
        'Finding a chest leaves the live game playable.').toBe(false);
      await capture(page, info, `${mode}-${geometry.name}-discovery-hud`);
      await continuePairs(page, mode);

      for (let index = 1; index < pairs.length; index++) {
        await playPair(page, mode, pairs[index]);
        if (index < pairs.length - 1) await continuePairs(page, mode);
      }
      await expect.poll(async () => (await celebrationState(page)).ready, { timeout: 15000 }).toBe(true);
      const cheers = await discoveryPlaybacks(page, from, timing);
      expect(cheers, 'Further successful pairs and round settlement never repeat the discovery cheer.').toHaveLength(1);
      expect(cheers[0].endedAt, 'The discovery recording completes naturally.').toBeGreaterThan(cheers[0].at);
      if (cheers[0].stoppedAt !== undefined) {
        // Godot disposes a completed WebAudio source by calling stop from its
        // ended handler. That cleanup is valid only after natural completion;
        // a premature stop must still fail both lifecycle/timeline checks.
        expect(cheers[0].stoppedAt, 'Source cleanup follows the natural ended event.').toBeGreaterThanOrEqual(cheers[0].endedAt);
        const naturalEnd = cheers[0].scheduledAt + cheers[0].duration / cheers[0].playbackRate;
        expect(cheers[0].stopScheduledAt + 1 / cheers[0].sampleRate,
          'Cleanup cannot cut off any of the discovery recording.').toBeGreaterThanOrEqual(naturalEnd);
      }
      await info.attach(`${mode}-${geometry.name}-discovery-audio`, {
        body: JSON.stringify({ recording: DISCOVERY, timing, cheers, output }, null, 2),
        contentType: 'application/json'
      });
      expect(requests, 'Discovery uses its bundled cheer without an audio download.').toEqual([]);
      expect(errors).toEqual([]);
    });
  }
}
