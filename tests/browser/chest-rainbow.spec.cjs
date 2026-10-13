const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const { enterGame, chooseMode, metrics, visibleColorCount } = require('./game-ui.cjs');
const { roomState } = require('./pop-treasure-ui.cjs');

// Preserve phone CSS geometry without adding capture cost to the fast hold.
test.use({ deviceScaleFactor: 1, trace: 'off', video: 'off' });

async function openEarnedChest(page, reducedMotion) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (/SCRIPT ERROR|Parse Error|Failed loading resource|Shader compilation failed/.test(message.text())) errors.push(message.text());
  });
  await page.emulateMedia({ reducedMotion });
  await page.addInitScript(() => {
    window.SpeechRecognition = undefined;
    window.webkitSpeechRecognition = undefined;
    localStorage.setItem('wordBuddies.popRewards',
      '[treasure]\nversion=1\nround_id="rainbow-progress-review"\nentries=[{"theme":"spring","opened":false}]\nreceipts=[]\n');
  });
  await page.goto('/');
  await enterGame(page, { home: true });
  await chooseMode(page, 'pop');
  await expect.poll(async () => {
    const room = await roomState(page);
    return room.visible && !room.paused && room.chests?.length === 1 && room.opened_count === 0;
  }).toBe(true);
  const room = await roomState(page), bounds = await metrics(page), rect = room.chests[0].rect;
  await page.mouse.move(bounds.x + (rect.x + rect.width / 2) * bounds.scale,
    bounds.y + (rect.y + rect.height / 2) * bounds.scale);
  return errors;
}

async function observeRainbow(page, reducedMotion) {
  await page.evaluate(reduced => {
    const status = document.getElementById('pop-reward-status');
    const canvas = document.getElementById('canvas');
    const read = () => JSON.parse(status.dataset.snapshot || '{}');
    const picture = () => canvas.toDataURL('image/png').split(',')[1];
    const initial = read();
    const bounds = canvas.getBoundingClientRect();
    const unit = Math.min(bounds.width, bounds.height) / 480;
    window.rainbowReview = { history: [], frames: [], cues: [], baseline: picture(),
      canvasWidth: canvas.width, canvasHeight: canvas.height,
      logicalWidth: bounds.width / unit, logicalHeight: bounds.height / unit,
      art: initial.chests[0].art_rect, thresholds: [0.35, 0.60, 0.86], duration: reduced ? 650 : 1590, done: false };
    window.addEventListener('wordbuddies:chest-cue', event => window.rainbowReview.cues.push(event.detail));
    const record = () => {
      const state = read(), chest = state.chests?.[0];
      if (chest) window.rainbowReview.history.push({ at: performance.now(), holding: state.holding,
        opening: state.opening, opened_count: state.opened_count, ...chest });
    };
    new MutationObserver(record).observe(status, { attributes: true, attributeFilter: ['data-snapshot'] });
    record();
    const capture = () => {
      const state = read(), chest = state.chests?.[0], review = window.rainbowReview;
      const target = review.thresholds[review.frames.length];
      const press = review.cues.find(cue => cue.cue === 'press');
      const elapsed = press ? performance.now() - press.at : 0;
      // This room publishes snapshots on state changes, not every animation
      // frame. Capture against its real press cue without inventing telemetry.
      if (press && target !== undefined && elapsed >= target * review.duration && !chest.opened) {
        review.frames.push({ at: performance.now(), timeline_progress: elapsed / review.duration,
          snapshot_progress: chest.progress,
          phase: chest.phase, png: picture() });
      }
      if (state.opened_count === 1) review.done = true;
      else requestAnimationFrame(capture);
    };
    requestAnimationFrame(capture);
  }, reducedMotion === 'reduce');
}

async function rainbowPixelEvidence(page, evidence) {
  return page.evaluate(async source => {
    const images = await Promise.all([source.baseline, ...source.frames.map(frame => frame.png)].map(async encoded => {
      const image = new Image();
      image.src = `data:image/png;base64,${encoded}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      return context.getImageData(0, 0, image.width, image.height);
    }));
    const { art } = source, scale = source.canvasWidth / source.logicalWidth;
    // Sample the air above the solid lid, in three separated parts of the bow.
    // The baseline rejects static illustration colors and page decorations.
    const regions = { left: [0.12, 0.12, 0.37, 0.20], crown: [0.44, 0.10, 0.12, 0.20], right: [0.51, 0.12, 0.37, 0.20] };
    return images.slice(1).map((image, index) => {
      const result = { timeline_progress: source.frames[index].timeline_progress };
      for (const [name, region] of Object.entries(regions)) {
        const x0 = Math.round((art.x + art.width * region[0]) * scale);
        const y0 = Math.round((art.y + art.height * region[1]) * scale);
        const x1 = Math.round((art.x + art.width * (region[0] + region[2])) * scale);
        const y1 = Math.round((art.y + art.height * (region[1] + region[3])) * scale);
        let pixels = 0, changed = 0, delta = 0;
        for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
          const offset = (y * image.width + x) * 4;
          const difference = [0, 1, 2].reduce((sum, channel) => sum + Math.abs(image.data[offset + channel] - images[0].data[offset + channel]), 0);
          pixels++;
          delta += difference;
          if (difference > 8) changed++;
        }
        result[name] = { pixels, changed, fraction: changed / pixels, meanDelta: delta / pixels };
      }
      return result;
    });
  }, evidence);
}

for (const reducedMotion of ['no-preference', 'reduce']) {
  test(`the chest rainbow reveals from left to right with earned progress (${reducedMotion})`, async ({ page }, testInfo) => {
    test.setTimeout(180000);
    const errors = await openEarnedChest(page, reducedMotion);
    await page.mouse.down();
    await page.waitForTimeout(150);
    await page.mouse.up();
    await expect.poll(async () => (await roomState(page)).chests[0].progress).toBe(0);
    await page.waitForTimeout(1550);
    const cancelled = await roomState(page);
    expect(cancelled.opened_count, 'A cancelled gesture never claims the chest').toBe(0);
    expect(cancelled.chests[0].mode).toBe('closed');
    expect(cancelled.chests[0].progress).toBe(0);
    await observeRainbow(page, reducedMotion);
    await page.mouse.down();
    try {
      await page.waitForFunction(() => {
        const room = JSON.parse(document.getElementById('pop-reward-status').dataset.snapshot || '{}');
        return room.chests?.[0]?.committed || room.opened_count === 1;
      }, null, { timeout: 10000 });
    } finally {
      await page.mouse.up();
    }
    await expect.poll(async () => (await roomState(page)).opened_count).toBe(1);
    await expect.poll(async () => (await roomState(page)).chests[0].mode).toBe('opened');
    const evidence = await page.evaluate(() => window.rainbowReview);
    fs.writeFileSync(testInfo.outputPath('rainbow-baseline.png'), Buffer.from(evidence.baseline, 'base64'));
    const inputPath = testInfo.outputPath('rainbow-input-evidence.json');
    fs.writeFileSync(inputPath, JSON.stringify({ ...evidence, baseline: undefined,
      frames: evidence.frames.map(({ png, ...frame }) => frame) }, null, 2));
    await testInfo.attach('rainbow-input-evidence', {
      path: inputPath, contentType: 'application/json'
    });
    expect(evidence.frames, 'Real input captures early, middle and late visible progression').toHaveLength(3);
    expect(evidence.frames.every((frame, index) => frame.timeline_progress >= evidence.thresholds[index] &&
      frame.timeline_progress < evidence.thresholds[index] + 0.14), 'The three images are captured in separate phases without stretching time').toBe(true);
    for (let index = 0; index < evidence.frames.length; index++) {
      const png = Buffer.from(evidence.frames[index].png, 'base64');
      expect(await visibleColorCount(page, png), 'The progression evidence includes the real rendered game').toBeGreaterThan(20);
      const name = `rainbow-${['early', 'middle', 'late'][index]}`;
      const filename = testInfo.outputPath(`${name}.png`);
      fs.writeFileSync(filename, png);
      await testInfo.attach(name, { path: filename, contentType: 'image/png' });
    }
    const pixels = await rainbowPixelEvidence(page, evidence);
    const progressPath = testInfo.outputPath('rainbow-progress-evidence.json');
    fs.writeFileSync(progressPath, JSON.stringify({ ...evidence, baseline: undefined,
      frames: evidence.frames.map(({ png, ...frame }) => frame), pixels }, null, 2));
    await testInfo.attach('rainbow-progress-evidence', { path: progressPath, contentType: 'application/json' });
    const [early, middle, late] = pixels;
    expect(early.left.changed, 'The first visible spectrum appears on the left').toBeGreaterThan(10);
    expect(early.left.meanDelta, 'A reversed wipe cannot light the right side before the left')
      .toBeGreaterThan(early.right.meanDelta * 1.7 + 0.08);
    expect(middle.crown.meanDelta, 'The growing bow reaches its crown after the left side')
      .toBeGreaterThan(early.crown.meanDelta + 0.2);
    expect(late.right.meanDelta, 'The right side becomes visible near completion')
      .toBeGreaterThan(early.right.meanDelta + 0.2);
    expect(late.right.changed).toBeGreaterThan(early.right.changed + 10);
    const press = evidence.cues.find(cue => cue.cue === 'press');
    expect(press).toBeTruthy();
    const steps = evidence.cues.filter(cue => cue.cue === 'charge_step');
    expect(steps.map(cue => cue.step), 'Actual progress crosses each third once, in order').toEqual([1, 2, 3]);
    if (reducedMotion === 'reduce') {
      expect(evidence.cues.filter(cue => ['hold_pulse', 'tension_pulse', 'release', 'settle'].includes(cue.cue))).toEqual([]);
      const saved = evidence.history.find(frame => frame.opened_count === 1);
      expect(saved.at - press.at, 'Reduced motion preserves the full 650 ms hold').toBeGreaterThanOrEqual(550);
      expect(saved.at - press.at).toBeLessThan(1400);
    } else {
      const opening = evidence.cues.find(cue => cue.cue === 'opening');
      expect(opening.at - press.at, 'The hold still takes 650 ms before automatic opening').toBeGreaterThanOrEqual(550);
      expect(opening.at - press.at).toBeLessThan(1150);
      expect(steps[0].at).toBeLessThan(opening.at);
      expect(steps[1].at).toBeGreaterThan(opening.at);
      const release = evidence.cues.find(cue => cue.cue === 'release');
      expect(release.at - press.at, 'Full reveal waits for the existing 1.59-second lid release').toBeGreaterThanOrEqual(1490);
      expect(release.at - press.at).toBeLessThan(2300);
      expect(evidence.history.some(frame => frame.committed && frame.progress === 1)).toBe(true);
    }
    const saved = await page.evaluate(() => localStorage.getItem('wordBuddies.popRewards'));
    await page.waitForTimeout(350);
    expect(await page.evaluate(() => localStorage.getItem('wordBuddies.popRewards')), 'Finishing the effect cannot award the chest twice').toBe(saved);
    expect(errors).toEqual([]);
  });
}
