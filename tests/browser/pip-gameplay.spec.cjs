const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const { openGame, metrics, memoryMetrics, tap, boardPoint, memoryPoint, rendered, observeAudio } = require('./game-ui.cjs');
const catalog = require('../../words.json');

function wavDuration(relative) {
  const bytes = fs.readFileSync(path.resolve(__dirname, '../..', relative));
  let byteRate, dataSize;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const id = bytes.toString('ascii', offset, offset + 4), size = bytes.readUInt32LE(offset + 4);
    if (id === 'fmt ') byteRate = bytes.readUInt32LE(offset + 16);
    if (id === 'data') dataSize = size;
    offset += 8 + size + (size % 2);
  }
  if (!byteRate || !dataSize) throw new Error(`Invalid WAV: ${relative}`);
  return dataSize / byteRate;
}

const happyCall = { duration: wavDuration('assets/audio/pip/duck_double_01_bouncy.wav'), rate: 1.12 };
const sadCall = { duration: wavDuration('assets/audio/pip/duck_quack_innocent_deep_short_04.wav'), rate: 0.8 };
const matchesCall = (sound, expected) => Math.abs(sound.duration - expected.duration) <= 1 / sound.sampleRate &&
  Math.abs(sound.playbackRate - expected.rate) < 0.001;

async function discoverCards(page, mode) {
  const bounds = mode === 'memory' ? await memoryMetrics(page) : await metrics(page);
  const pointFor = mode === 'memory' ? memoryPoint : boardPoint;
  const cards = [];
  for (let index = 0; index < 10; index++) {
    const point = pointFor(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(mode === 'memory'
      ? /^Memory card \d+\. (Word|Picture): .+\.$/ : /^(Word|Picture): .+$/);
    const label = await page.locator('#selection-status').textContent();
    const [, kind, word] = label.match(mode === 'memory'
      ? /^Memory card \d+\. (Word|Picture): (.+)\.$/ : /^(Word|Picture): (.+)$/);
    cards.push({ index, kind, word, point });
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  return cards;
}

for (const mode of ['match', 'memory']) {
  test(`${mode} outcomes give Pip distinct calls while retaining card speech`, async ({ page, browserName }, info) => {
    test.setTimeout(120000);
    await observeAudio(page, { fingerprintBuffers: true, trackSourceLifecycle: true });
    const errors = await openGame(page, { mode, reducedMotion: 'no-preference' });
    const audioAvailable = await page.evaluate(() => audioObservation.available);
    if (browserName === 'chromium') expect(audioAvailable, 'Chromium exercises real WebAudio recordings').toBe(true);
    const cards = await discoverCards(page, mode);
    const first = cards.find(card => card.kind === 'Word');
    const partner = cards.find(card => card.kind === 'Picture' && card.word === first.word);
    const wrong = cards.find(card => card.kind === 'Picture' && card.word !== first.word);
    expect(partner).toBeTruthy();
    expect(wrong).toBeTruthy();
    const evidence = [];

    for (const correct of [false, true]) {
      const second = correct ? partner : wrong;
      await tap(page, first.point.x, first.point.y);
      await rendered(page);
      const from = await page.evaluate(() => audioObservation.playbacks.length);
      await tap(page, second.point.x, second.point.y);
      await expect(page.locator('#game-status')).toContainText(mode === 'memory'
        ? (correct ? 'A new flower!' : 'Try another pair.') : (correct ? 'Great match!' : 'Not quite.'));
      const expected = correct ? happyCall : sadCall;
      const outcomeSounds = () => page.evaluate(start => audioObservation.playbacks.slice(start), from);
      if (audioAvailable) {
        await expect.poll(async () => (await outcomeSounds()).filter(sound => matchesCall(sound, expected)).length,
          { message: 'One real duck recording accompanies this pair result.' }).toBe(1);
        const sound = (await outcomeSounds()).find(item => matchesCall(item, expected));
        expect(sound.contextState).toBe('running');
        expect(sound.fingerprint).toBeTruthy();
        expect(sound.peak).toBeGreaterThan(0.01);
        expect(sound.loop).toBe(false);
        const recording = mode === 'match' && !correct ? 'assets/audio/voice/wrong.wav'
          : catalog.find(word => word.text === second.word)?.audio;
        expect(recording, 'The revealed word resolves to its real vocabulary recording').toBeTruthy();
        const seconds = wavDuration(recording);
        await expect.poll(async () => (await outcomeSounds()).some(item => item.playbackRate === 1 &&
          Math.abs(item.duration - seconds) <= 1 / item.sampleRate),
        { message: 'The duck call leaves the existing word or correction recording audible.' }).toBe(true);
      }
      await page.screenshot({ path: info.outputPath(`${mode}-${correct ? 'happy' : 'sad'}.png`), scale: 'css' });
      evidence.push({ correct, word: second.word, audio: await outcomeSounds() });
      await expect(page.locator('#selection-status')).toBeEmpty();
      await page.waitForTimeout(100);
      if (audioAvailable) expect((await outcomeSounds()).filter(sound => matchesCall(sound, expected)).length,
        'Feedback completion cannot replay the duck call.').toBe(1);
    }
    if (mode === 'memory') await expect(page.locator('#game-status')).toContainText('1 of 5 pairs grown. 2 attempts.');
    await info.attach(`${mode}-pip-gameplay-audio.json`, { body: JSON.stringify({ audioAvailable, evidence }), contentType: 'application/json' });
    expect(errors).toEqual([]);
  });
}
