const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap, boardPoint, rendered, observeAudio } = require('./game-ui.cjs');
const { memoryState, startObservation, startMatching, memoryCardTap, waitForMemoryInput } = require('./memory-flow.cjs');
const catalog = require('../../words.json');
const { expectRecording, recordingTiming } = require('./bundled-audio.cjs');

const duckRecordings = require('../../docs/assets/pip-sounds.json').assets.map(asset => recordingTiming(asset.file));
const isDuckCall = sound => duckRecordings.some(timing =>
  Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate);

async function discoverCards(page, mode) {
  if (mode === 'memory') {
    const observed = await startObservation(page);
    await startMatching(page);
    return observed.map(card => ({
      index: card.index,
      kind: card.kind === 'word' ? 'Word' : 'Picture',
      word: catalog.find(word => word.id === card.word).text
    }));
  }
  const bounds = await metrics(page);
  const cards = [];
  for (let index = 0; index < 10; index++) {
    const point = boardPoint(bounds, index);
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toHaveText(/^(Word|Picture): .+$/);
    const label = await page.locator('#selection-status').textContent();
    const [, kind, word] = label.match(/^(Word|Picture): (.+)$/);
    cards.push({ index, kind, word, point });
    await tap(page, point.x, point.y);
    await expect(page.locator('#selection-status')).toBeEmpty();
  }
  return cards;
}

for (const mode of ['match', 'memory']) {
  test(`${mode} outcomes play the reference effects without Pip calls or spoken corrections`, async ({ page, browserName }, info) => {
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
    const choose = card => mode === 'memory'
      ? memoryCardTap(page, card.index) : tap(page, card.point.x, card.point.y);

    for (const correct of [false, true]) {
      const second = correct ? partner : wrong;
      if (mode === 'memory') await waitForMemoryInput(page);
      await choose(first);
      if (mode === 'memory') {
        expect((await memoryState(page)).cards[first.index]).toMatchObject({ face_up: false, selected: true, word_id: '' });
      }
      await rendered(page);
      const from = await page.evaluate(() => audioObservation.playbacks.length);
      await choose(second);
      await expect(page.locator('#game-status')).toContainText(mode === 'memory'
        ? (correct ? 'Great match!' : 'Not a pair.') : (correct ? 'Great match!' : 'Not quite.'));
      const outcomeSounds = () => page.evaluate(start => audioObservation.playbacks.slice(start), from);
      if (audioAvailable) {
        const sound = await expectRecording(page, from, `assets/imported-audio/pair-feedback/${correct ? 'right' : 'wrong'}.wav`);
        expect(sound.contextState).toBe('running');
        expect(sound.fingerprint).toBeTruthy();
        expect(sound.peak).toBeGreaterThan(0.01);
        expect(sound.loop).toBe(false);
        expect(sound.playbackRate).toBe(1);
        if (mode === 'match' && correct) {
          const recording = catalog.find(word => word.text === second.word)?.audio;
          expect(recording, 'The revealed word resolves to its vocabulary recording').toBeTruthy();
          await expectRecording(page, from, recording);
        } else {
          expect((await outcomeSounds()).filter(item => !item.loop),
            'Memory outcomes and wrong Match pairs play only their outcome cue, without word narration.').toHaveLength(1);
        }
      }
      await page.screenshot({ path: info.outputPath(`${mode}-${correct ? 'happy' : 'sad'}.png`), scale: 'css' });
      evidence.push({ correct, word: second.word, audio: await outcomeSounds() });
      await expect(page.locator('#selection-status')).toBeEmpty();
      await page.waitForTimeout(100);
      if (audioAvailable) {
        const sounds = await outcomeSounds();
        expect(sounds.filter(isDuckCall), 'Match and Memory feedback never plays a duck call.').toEqual([]);
        const timing = recordingTiming(`assets/imported-audio/pair-feedback/${correct ? 'right' : 'wrong'}.wav`);
        expect(sounds.filter(sound => Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate),
          'Each outcome plays its reference recording exactly once.').toHaveLength(1);
      }
    }
    if (mode === 'memory') await expect(page.locator('#game-status')).toContainText('1 of 5 pairs matched. 2 attempts.');
    if (audioAvailable) {
      const playbacks = await page.evaluate(() => audioObservation.playbacks);
      expect(playbacks.filter(isDuckCall), 'Entering the mode, revealing cards and resolving outcomes never plays any Pip recording.').toEqual([]);
    }
    await info.attach(`${mode}-pip-gameplay-audio.json`, { body: JSON.stringify({ audioAvailable, evidence }), contentType: 'application/json' });
    expect(errors).toEqual([]);
  });
}
