const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap } = require('./game-ui.cjs');
const vocabulary = require('../../words.json');

const snapshot = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const normalize = value => value.trim().toLowerCase().replace(/\s+/g, ' ');
const ageThreeWords = new Set(vocabulary.filter(word => word.min_age === 3 &&
  ['id', 'text', 'image', 'audio'].every(key => typeof word[key] === 'string' && word[key].trim()))
  .map(word => normalize(word.text)));

test.use({ deviceScaleFactor: 1, viewport: { width: 393, height: 852 } });

async function tapRect(page, rect) {
  await tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2);
}

function expectPreviewColumns(before, after, mode) {
  if (mode !== 'word_jelly') return;
  const occupied = new Set();
  for (const tile of before.tiles) {
    for (let column = tile.column; column < tile.column + tile.width; column++) {
      for (let row = tile.row; row < tile.row + tile.height; row++) occupied.add(`${column},${row}`);
    }
  }
  for (const [slot, advertised] of before.upcoming.entries()) {
    const tile = after.tiles.find(tile => tile.id === advertised.id);
    if (!tile) continue; // A sealed well may admit only the FIFO prefix.
    expect(tile.arrival_index, 'The released body retains its visible preview slot').toBe(slot);
    if (!occupied.has(`${slot},0`)) {
      expect(tile.column, 'An open preview lane drops directly down its own column').toBe(slot);
    }
    expect(occupied.has(`${tile.column},${tile.row}`), 'Supply never overlaps a reserved body').toBe(false);
    occupied.add(`${tile.column},${tile.row}`);
  }
}

function availablePair(state, mode) {
  const tiles = state.tiles.filter(tile => tile.visible && tile.settled && (mode === 'jelly' || tile.mass === 1));
  const pairs = [];
  for (const source of tiles) for (const target of tiles) {
    if (source.id === target.id) continue;
    // Removing a supporting source must not move the destination during the drag.
    if (source.column === target.column && source.row > target.row) continue;
    const matches = mode === 'word_jelly' ? ageThreeWords.has(normalize(source.text + target.text)) :
      source.word.id === target.word.id && source.kind !== target.kind;
    if (matches) pairs.push([source, target]);
  }
  const hasTreasure = pair => pair.some(tile => tile.chest || tile.fragments > 0);
  pairs.sort((a, b) => Number(hasTreasure(a)) - Number(hasTreasure(b)));
  return pairs[0];
}

async function dragPair(page, pair) {
  const bounds = await metrics(page);
  const center = tile => ({ x: bounds.x + (tile.rect[0] + tile.rect[2] / 2) * bounds.scale,
    y: bounds.y + (tile.rect[1] + tile.rect[3] / 2) * bounds.scale });
  const from = center(pair[0]), to = center(pair[1]);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await snapshot(page)).drag.source).toBe(pair[0].id);
    await page.mouse.move(to.x, to.y, { steps: 4 });
    await expect.poll(async () => (await snapshot(page)).drag.target).toBe(pair[1].id);
  } finally {
    await page.mouse.up();
  }
}

async function observeCycles(page) {
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.jellyDifficultyFrames = [];
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      window.jellyDifficultyFrames.push({ at: performance.now(), generated: state.generated_tiles,
        cleared: state.cleared_pairs, interval: state.spawn_interval, elapsed: state.spawn_elapsed });
    };
    window.jellyDifficultyObserver = new MutationObserver(record);
    window.jellyDifficultyObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  });
}

for (const { mode, initial, reduction, batch } of [
  { mode: 'word_jelly', initial: 20, reduction: 2, batch: 5 },
  { mode: 'jelly', initial: 10, reduction: 1, batch: 4 }
]) {
  test(`${mode} difficulty preserves the current timer and gives the next faster packet a full cycle`, async ({ page }, info) => {
    test.setTimeout(150000);
    const errors = await openGame(page, { mode, reducedMotion: 'no-preference' });
    await expect.poll(async () => {
      const state = await snapshot(page);
      return state.mode === mode && state.phase === 'playing' && state.preview?.enabled &&
        state.tiles?.length >= (mode === 'word_jelly' ? 15 : 12) && state.tiles.every(tile => tile.settled);
    }).toBe(true);
    const opening = await snapshot(page);
    expect(opening.spawn_interval).toBe(initial);
    expect(opening.cleared_pairs).toBe(0);
    await observeCycles(page);
    try {
      // Start a fresh ordinary cycle so startup time cannot race the first success.
      await tapRect(page, opening.preview.rect);
      await expect.poll(async () => (await snapshot(page)).generated_tiles).toBe(opening.generated_tiles + batch);
      await expect.poll(async () => (await snapshot(page)).tiles.every(tile => tile.settled)).toBe(true);
      let before, cleared;
      for (let completed = 1; completed <= 4; completed++) {
        let pair;
        await expect.poll(async () => {
          before = await snapshot(page);
          pair = availablePair(before, mode);
          return Boolean(pair);
        }, { message: 'A complete pair becomes playable after the previous clear and any incoming packet settle' }).toBe(true);
        expect(before.spawn_interval).toBe(initial);
        await dragPair(page, pair);
        if (mode === 'word_jelly') {
          let merged;
          await expect.poll(async () => {
            const state = await snapshot(page);
            merged = state.tiles.find(tile => tile.text === pair[0].text + pair[1].text && tile.mass === 2 && tile.settled &&
              !before.tiles.some(previous => previous.id === tile.id));
            return Boolean(merged) && !state.tiles.some(tile => pair.some(root => root.id === tile.id));
          }, { message: 'A real ordered merge creates the pictured word before collection' }).toBe(true);
          const built = await snapshot(page);
          expect(built.cleared_pairs, 'Building a word alone does not earn a difficulty step').toBe(completed - 1);
          expect(built.spawn_interval).toBe(initial);
          await tapRect(page, merged.rect);
        }
        await expect.poll(async () => (await snapshot(page)).cleared_pairs,
          { message: 'The ordinary merge or word tap completes one successful clear' }).toBe(completed);
        cleared = await snapshot(page);
        if (cleared.generated_tiles === before.generated_tiles) {
          expect(cleared.spawn_interval, 'A success preserves the interval already being anticipated').toBe(initial);
          expect(cleared.spawn_elapsed, 'Success does not restart the active supply clock').toBeGreaterThanOrEqual(before.spawn_elapsed);
        }
        if (completed < 4) expect(cleared.spawn_interval, 'Fewer than four successes keep the opening stage').toBe(initial);
        expect(cleared.preview.enabled).toBe(true);
        if (completed === 1) {
          // Keep room for the automatic packets that may arrive during slow browser input.
          // This manual cycle also verifies that one success cannot advance the stage.
          await tapRect(page, cleared.preview.rect);
          await expect.poll(async () => (await snapshot(page)).generated_tiles).toBe(cleared.generated_tiles + batch);
          const next = await snapshot(page);
          expect(next.spawn_interval, 'One clear cannot advance a stage at dispatch').toBe(initial);
          expectPreviewColumns(cleared, next, mode);
          await expect.poll(async () => (await snapshot(page)).tiles.every(tile => tile.settled)).toBe(true);
        }
      }

      const advertised = cleared.upcoming.map(tile => tile.id);
      await tapRect(page, cleared.preview.rect);
      const manualGenerated = cleared.generated_tiles + batch;
      await expect.poll(async () => (await snapshot(page)).generated_tiles).toBe(manualGenerated);
      const latched = await snapshot(page), nextInterval = initial - reduction;
      expectPreviewColumns(cleared, latched, mode);
      expect(latched.spawn_interval, 'Manual Next latches the first stage after four successful clears').toBe(nextInterval);
      expect(advertised.every(id => latched.tiles.some(tile => tile.id === id)),
        'The gesture releases exactly the packet advertised before the faster cycle').toBe(true);
      await page.screenshot({ path: info.outputPath(`${mode}-difficulty-faster-cycle.png`), scale: 'css' });

      await expect.poll(async () => (await snapshot(page)).generated_tiles,
        { timeout: (nextInterval + 15) * 1000, intervals: [100], message: 'The next automatic packet waits through its full faster cycle' })
        .toBe(manualGenerated + batch);
      const after = await snapshot(page);
      expect(after.spawn_interval).toBe(nextInterval);
      expect(after.cleared_pairs).toBe(4);
      const frames = await page.evaluate(() => window.jellyDifficultyFrames);
      expect(frames.some(frame => frame.cleared === 4), 'The stage-completing clear is observed').toBe(true);
      const intervalsByPacket = new Map();
      for (const frame of frames) {
        if (!intervalsByPacket.has(frame.generated)) intervalsByPacket.set(frame.generated, frame.interval);
        expect(frame.interval, 'Success never shortens the interval of an already running packet')
          .toBe(intervalsByPacket.get(frame.generated));
        if (frame.cleared < 4) expect(frame.interval, 'One, two, or three clears do not advance a stage').toBe(initial);
      }
      const fasterCycle = frames.filter(frame => frame.generated === manualGenerated);
      expect(fasterCycle.length).toBeGreaterThan(3);
      expect(fasterCycle[0].elapsed, 'The newly latched cycle begins at zero instead of inheriting elapsed time').toBeLessThan(0.6);
      expect(fasterCycle.every(frame => frame.interval === nextInterval)).toBe(true);
      // Publications are spaced by 100 ms; a rendered game frame may consume up to 500 ms.
      expect(Math.max(...fasterCycle.map(frame => frame.elapsed)), 'The clock reaches the end of the full earned interval')
        .toBeGreaterThan(nextInterval - 0.6);
      const automatic = frames.find(frame => frame.generated === manualGenerated + batch);
      expect(automatic, 'The observer records the automatic dispatch').toBeTruthy();
      expect(automatic.elapsed, 'The automatic dispatch also starts a fresh complete cycle').toBeLessThan(0.6);
      await info.attach('difficulty-cycle-timeline', {
        body: JSON.stringify({ mode, initial, nextInterval, before, cleared, frames }, null, 2), contentType: 'application/json'
      });
      expect(errors).toEqual([]);
    } finally {
      const frames = await page.evaluate(() => window.jellyDifficultyFrames || []).catch(() => []);
      await info.attach('observed-difficulty-frames', {
        body: JSON.stringify(frames, null, 2), contentType: 'application/json'
      });
      await page.evaluate(() => window.jellyDifficultyObserver?.disconnect()).catch(() => {});
    }
  });
}
