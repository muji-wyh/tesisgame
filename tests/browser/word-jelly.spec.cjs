const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, chooseMode, metrics, tap, rendered, enterGame, observeAudio } = require('./game-ui.cjs');
const { recordingTiming } = require('./bundled-audio.cjs');
const vocabulary = require('../../words.json');

const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const normalize = text => text.trim().toLowerCase().replace(/\s+/g, ' ');

async function pressRect(page, rect) {
  expect(rect).toHaveLength(4);
  const [x, y, width, height] = rect;
  expect(width).toBeGreaterThan(0);
  expect(height).toBeGreaterThan(0);
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function startWordJelly(page, { age = 3, reducedMotion = 'no-preference' } = {}) {
  const earnedAge = age === 3 ? 0 : age - 1;
  await page.addInitScript(earnedAge => {
    const key = 'growWithPip.growth.v1';
    if (!localStorage.getItem(key)) localStorage.setItem(key,
      `[growth]\nversion=3\nlevel=0\nage=${earnedAge}\nstreaks={}\nmastered_words=[]\nreceipts=[]\n`);
  }, earnedAge);
  const errors = await openGame(page, { reducedMotion });
  await openModeMenu(page);
  const control = (await metrics(page)).library.controls.find(item => item.name === 'Mode_word_jelly');
  expect(control, 'Word Jelly appears in the ordinary game library').toBeTruthy();
  expect(control.disabled).toBe(false);
  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.mode === 'word_jelly' && state.visible && state.phase === 'playing' &&
      state.tiles?.length >= 18 && state.tiles.every(tile => tile.settled);
  }, { timeout: 20000, message: 'The real Word Jelly board opens with three rows of settled roots' }).toBe(true);
  return errors;
}

function center(rect, bounds) {
  return { x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale };
}

function rootsForWord(state, age, count, markedOnly = false, invalidReverse = false) {
  const words = new Map(vocabulary.filter(word => word.min_age === age).map(word => [normalize(word.text), word]));
  const roots = state.tiles.filter(tile => tile.visible && tile.settled && tile.mass === 1);
  for (const first of roots) for (const second of roots) {
    if (first.id === second.id) continue;
    const prefix = first.text + second.text;
    if (count === 2 && words.has(normalize(prefix)) && (!markedOnly || first.fragments + second.fragments > 0) &&
      (!invalidReverse || !words.has(normalize(second.text + first.text))))
      return { roots: [first, second], word: words.get(normalize(prefix)) };
    if (count !== 3) continue;
    for (const third of roots) {
      if (third.id === first.id || third.id === second.id) continue;
      const text = normalize(prefix + third.text);
      if (words.has(text)) return { roots: [first, second, third], word: words.get(text) };
    }
  }
  return null;
}

async function availableWord(page, age, count, { markedOnly = false, invalidReverse = false } = {}) {
  for (let attempt = 0; attempt < 4; attempt++) {
    await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    const state = await jelly(page), found = rootsForWord(state, age, count, markedOnly, invalidReverse);
    if (found) return found;
    expect(state.preview.enabled, 'The ordinary preview can supply another complete word packet').toBe(true);
    await pressRect(page, state.preview.rect);
    await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
  }
  throw new Error(`The current age ${age} supply did not provide a ${count}-part word.`);
}

async function merge(page, sourceId, targetId) {
  const before = await jelly(page), bounds = await metrics(page);
  const source = before.tiles.find(tile => tile.id === sourceId), target = before.tiles.find(tile => tile.id === targetId);
  expect(source?.settled, 'The held jelly is ready').toBe(true);
  expect(target?.settled, 'The destination jelly is ready').toBe(true);
  const from = center(source.rect, bounds), to = center(target.rect, bounds);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(sourceId);
    await page.mouse.move(to.x, to.y, { steps: 12 });
    await expect.poll(async () => (await jelly(page)).drag.target).toBe(targetId);
  } finally {
    await page.mouse.up();
  }
  let result;
  await expect.poll(async () => {
    const state = await jelly(page);
    result = state.tiles.find(tile => !before.tiles.some(old => old.id === tile.id) &&
      tile.text === source.text + target.text && tile.mass === source.mass + target.mass);
    return state.merged_count === before.merged_count + 1 && Boolean(result?.settled);
  }, { message: 'The union settles into a persistent larger jelly in source-then-target order' }).toBe(true);
  const after = await jelly(page);
  expect(after.tiles.some(tile => tile.id === sourceId || tile.id === targetId)).toBe(false);
  expect(after.cleared_pairs, 'Merging does not automatically collect a word').toBe(before.cleared_pairs);
  expect(after.fragment_count, 'Carried fragments are collected only after a valid word is tapped').toBe(before.fragment_count);
  expect(result.fragments).toBe(source.fragments + target.fragments);
  expect(result.row, 'A merged jelly stays at the target row or grows upward without sinking').toBeLessThanOrEqual(target.row);
  for (const original of before.tiles.filter(tile => tile.id !== sourceId && tile.id !== targetId && tile.settled)) {
    const unchanged = after.tiles.find(tile => tile.id === original.id);
    expect(unchanged, 'Merging preserves every unrelated jelly').toBeTruthy();
    const expanded = unchanged.width !== original.width || unchanged.height !== original.height;
    if (expanded) {
      const compressed = original.width < Math.min(before.columns, original.mass) ||
        original.height < Math.min(before.rows, Math.ceil(original.mass / before.columns));
      expect(compressed, 'Only an already compressed jelly can expand when a merge frees space').toBe(true);
      expect(unchanged.width).toBeGreaterThanOrEqual(original.width);
      expect(unchanged.height).toBeGreaterThanOrEqual(original.height);
      expect(unchanged.row, 'Restored growth cannot make an unrelated jelly sink').toBeLessThanOrEqual(original.row);
      continue;
    }
    expect([unchanged.column, unchanged.row], 'A merge leaves unrelated occupied cells in place')
      .toEqual([original.column, original.row]);
    for (let axis = 0; axis < original.rect.length; axis++)
      expect(unchanged.rect[axis], 'Unrelated settled jelly positions and sizes remain visually stable')
        .toBeCloseTo(original.rect[axis], 3);
  }
  return result;
}

async function capture(page, info, name) {
  await rendered(page);
  await page.screenshot({ path: info.outputPath(`${name}.png`), scale: 'css' });
  const image = await page.locator('#canvas').evaluate(canvas => canvas.toDataURL('image/png').split(',')[1]);
  fs.writeFileSync(info.outputPath(`${name}-canvas.png`), Buffer.from(image, 'base64'));
}

function expectInside(rect, bounds) {
  expect(rect.every(Number.isFinite)).toBe(true);
  expect(rect[0]).toBeGreaterThanOrEqual(-1);
  expect(rect[1]).toBeGreaterThanOrEqual(-1);
  expect(rect[2]).toBeGreaterThan(0);
  expect(rect[3]).toBeGreaterThan(0);
  expect(rect[0] + rect[2]).toBeLessThanOrEqual(bounds.width + 1);
  expect(rect[1] + rect[3]).toBeLessThanOrEqual(bounds.height + 1);
}

function expectSupplyLayout(state, bounds) {
  const board = state.board_rect, tray = state.preview.rect, area = state.playfield_rect;
  const scale = Math.max(2 / 3, bounds.scale), tolerance = 0.25 / bounds.scale;
  const inside = (rect, parent, label) => {
    expect(rect.every(Number.isFinite), `${label} has finite bounds`).toBe(true);
    expect(rect[2], `${label} has visible width`).toBeGreaterThan(0);
    expect(rect[3], `${label} has visible height`).toBeGreaterThan(0);
    expect(rect[0], `${label} is inside the left edge`).toBeGreaterThanOrEqual(parent[0] - tolerance);
    expect(rect[1], `${label} is inside the top edge`).toBeGreaterThanOrEqual(parent[1] - tolerance);
    expect(rect[0] + rect[2], `${label} is inside the right edge`).toBeLessThanOrEqual(parent[0] + parent[2] + tolerance);
    expect(rect[1] + rect[3], `${label} is inside the bottom edge`).toBeLessThanOrEqual(parent[1] + parent[3] + tolerance);
  };
  expect(Math.abs(tray[0] - board[0]), 'The supply tray starts at the well left edge').toBeLessThan(tolerance);
  expect(Math.abs(tray[2] - board[2]), 'The supply tray is exactly as wide as the six-column well').toBeLessThan(tolerance);
  expect(tray[1] + tray[3], 'The supply tray stays above the well').toBeLessThanOrEqual(board[1] + tolerance);
  for (const [axis, value] of state.preview.control.rect.entries())
    expect(Math.abs(value - tray[axis]), 'The whole tray remains the manual drop target').toBeLessThan(tolerance);
  expect(state.preview.slots).toHaveLength(6);
  for (const [index, slot] of state.preview.slots.entries()) {
    expect(slot.visible, `Preview ${index} stays visible`).toBe(true);
    inside(slot.rect, tray, `Preview ${index}`);
    expect(Math.abs(slot.rect[0] + slot.rect[2] / 2 - (board[0] + (index + 0.5) * board[2] / 6)),
      `Preview ${index} is centered over its well column`).toBeLessThan(tolerance);
  }
  const regions = [['well', board], ['supply tray', tray], ['chest meter', state.loot.progress.rect],
    ['Finish', state.finish.rect], ['Collect words', state.collect_button.rect]];
  inside(area, [0, 0, bounds.width, bounds.height], 'Jelly Words playfield');
  for (const [index, [label, rect]] of regions.entries()) {
    inside(rect, area, label);
    for (const [otherLabel, other] of regions.slice(index + 1)) {
      const width = Math.min(rect[0] + rect[2], other[0] + other[2]) - Math.max(rect[0], other[0]);
      const height = Math.min(rect[1] + rect[3], other[1] + other[3]) - Math.max(rect[1], other[1]);
      expect(width <= tolerance || height <= tolerance, `${label} and ${otherLabel} do not overlap`).toBe(true);
    }
  }
  expect(tray[3] * scale, 'The supply tray retains a forty-four-pixel target height within viewport rounding').toBeGreaterThanOrEqual(43.75);
  expect(state.finish.rect[3] * scale, 'Finish retains a forty-four-pixel target height within viewport rounding').toBeGreaterThanOrEqual(43.75);
  expect(state.collect_button.rect[3] * scale, 'Collect words retains a forty-four-pixel target height within viewport rounding').toBeGreaterThanOrEqual(43.75);
  const bottom = Math.max(board[1] + board[3], state.finish.rect[1] + state.finish.rect[3]);
  expect(Math.abs(bottom - (area[1] + area[3] - 12 / scale)), 'The game retains twelve-pixel bottom padding').toBeLessThan(tolerance);
}

function expectSupportedChild(state, child) {
  const bottom = child.row + child.height;
  const supported = bottom === state.rows || state.tiles.some(other => other.id !== child.id &&
    other.row === bottom && other.column < child.column + child.width && other.column + other.width > child.column);
  expect(supported, `Restored part ${child.text} touches the floor or an occupied footprint immediately below`).toBe(true);
  for (const other of state.tiles.filter(tile => tile.id !== child.id)) {
    const overlaps = child.column < other.column + other.width && child.column + child.width > other.column &&
      child.row < other.row + other.height && child.row + child.height > other.row;
    expect(overlaps, `Restored part ${child.text} cannot overlap jelly ${other.id}`).toBe(false);
  }
}

function expectMixedRootPacket(roots, label) {
  expect(roots, `${label} contains six roots`).toHaveLength(6);
  expect(new Set(roots.map(root => root.supply_group)).size,
    `${label} contains parts from several words`).toBeGreaterThan(1);
  for (const [index, root] of roots.entries()) {
    expect(Number.isInteger(root.supply_group), `${label}: root provenance remains available`).toBe(true);
    expect(root.source_word_id, `${label}: every root retains its vocabulary identity`).toBeTruthy();
    if (index > 0) expect(root.supply_group,
      `${label}: parts from the same supplied word have another root between them`)
      .not.toBe(roots[index - 1].supply_group);
  }
}

function expectRootBreathingRoom(roots, pitch, label) {
  const ordered = [...roots].sort((a, b) => a.rect[0] - b.rect[0]);
  for (let index = 1; index < ordered.length; index++) {
    const previous = ordered[index - 1].rect, current = ordered[index].rect;
    expect(current[0] - previous[0] - previous[2],
      `${label}: neighboring root bodies retain visible breathing room`).toBeGreaterThanOrEqual(pitch * 0.08);
  }
}

async function observeArrival(page, before) {
  await page.evaluate(before => {
    window.wordJellyArrivalObserver?.disconnect();
    const status = document.getElementById('game-status');
    const wanted = new Set(before.upcoming.map(tile => tile.id));
    window.wordJellyArrivalTimeline = [];
    window.wordJellyArrivalFrame = null;
    window.wordJellyStaggerFrame = null;
    let capturePending = false;
    let staggerCapturePending = false;
    const source = before.preview.slots.find(slot => slot.id === before.upcoming[0].id);
    const capture = key => document.getElementById('canvas').toBlob(blob => {
      if (!blob) return;
      const reader = new FileReader();
      reader.onload = () => { window[key] = reader.result.split(',')[1]; };
      reader.readAsDataURL(blob);
    }, 'image/png');
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tracked = state.tiles?.filter(tile => wanted.has(tile.id)) || [];
      if (!tracked.length) return;
      window.wordJellyArrivalTimeline.push({ tiles: tracked, preview: state.preview.slots, time: performance.now() });
      const first = tracked.find(tile => tile.id === source.id);
      const boardPitch = state.board_rect[3] / state.rows;
      const targetY = state.board_rect[1] + (first?.row + 0.5) * boardPitch;
      const sourceY = source.rect[1] + source.rect[3] / 2;
      const progress = first && (first.rect[1] + first.rect[3] / 2 - sourceY) / (targetY - sourceY);
      if (!capturePending && first && !first.settled && progress > 0.20 && progress < 0.72) {
        capturePending = true;
        // Keep the simulation running while the real intermediate frame is encoded.
        capture('wordJellyArrivalFrame');
      }
      const travel = tracked.map(tile => {
        const preview = before.preview.slots.find(slot => slot.id === tile.id);
        return tile.rect[1] + tile.rect[3] / 2 - preview.rect[1] - preview.rect[3] / 2;
      });
      if (!staggerCapturePending && travel.some(value => Math.abs(value) < 1) &&
        travel.some(value => value > boardPitch * 0.25)) {
        staggerCapturePending = true;
        capture('wordJellyStaggerFrame');
      }
    };
    window.wordJellyArrivalObserver = new MutationObserver(record);
    window.wordJellyArrivalObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  }, before);
}

async function verifyArrival(page, info, before, label) {
  await expect.poll(async () => {
    const state = await jelly(page);
    return before.upcoming.every(root => state.tiles.some(tile => tile.id === root.id && tile.settled));
  }, { timeout: Math.ceil(before.spawn_interval * 1000) + 12000,
    message: `${label} supply visibly descends and finishes its planted recovery` }).toBe(true);
  const after = await jelly(page);
  const timeline = await page.evaluate(() => window.wordJellyArrivalTimeline);
  await info.attach(`word-jelly-${label}-arrival-timeline.json`, {
    body: JSON.stringify({ before: before.preview, roots: before.upcoming, timeline }, null, 2), contentType: 'application/json'
  });
  for (const root of before.upcoming) {
    const source = before.preview.slots.find(slot => slot.id === root.id);
    const target = after.tiles.find(tile => tile.id === root.id);
    const frames = timeline.flatMap(frame => frame.tiles.filter(tile => tile.id === root.id));
    const sourceY = source.rect[1] + source.rect[3] / 2;
    const destinationY = target.rect[1] + target.rect[3] / 2;
    const descent = frames.filter(tile => !tile.settled && tile.rect[1] + tile.rect[3] / 2 < destinationY - 0.1);
    expect(descent.length, `${label}: ${root.text} is visible in several airborne frames`).toBeGreaterThanOrEqual(3);
    expect(descent[0].rect[1] + descent[0].rect[3] / 2,
      `${label}: ${root.text} begins at its source tray instead of appearing near its landing cell`)
      .toBeLessThan(sourceY + (destinationY - sourceY) * 0.12);
    let previousY = sourceY - 0.1;
    for (const tile of descent) {
      const centerY = tile.rect[1] + tile.rect[3] / 2;
      expect(centerY, `${label}: ${root.text} travels continuously downward`).toBeGreaterThanOrEqual(previousY - 0.1);
      expect(tile.text).toBe(root.text);
      expect(tile.fragments).toBe(root.fragments);
      expect(tile.palette_index, `${label}: the body retains its preview partner color`).toBe(source.palette_index);
      expect(tile.fragment_badges).toBe(root.fragments);
      previousY = centerY;
    }
    const moving = descent.filter(tile => tile.rect[1] + tile.rect[3] / 2 > sourceY + 0.5);
    const unique = moving.filter((tile, index) => index === 0 || tile.age > moving[index - 1].age + 0.001);
    if (unique.length >= 4) {
      const speed = (a, b) => ((b.rect[1] + b.rect[3] / 2) - (a.rect[1] + a.rect[3] / 2)) / (b.age - a.age);
      expect(speed(unique.at(-2), unique.at(-1)), `${label}: gravity accelerates the falling ${root.text}`)
        .toBeGreaterThan(speed(unique[0], unique[1]));
    }
    expect(target.text).toBe(root.text);
    expect(target.fragments).toBe(root.fragments);
    expectSupportedChild(after, target);
  }
  const arrivals = before.upcoming.map((root, slot) => ({
    ...after.tiles.find(tile => tile.id === root.id), slot, source: before.preview.slots[slot]
  }));
  const delay = root => root.arrival_delay;
  expect(new Set(arrivals.map(delay)).size, `${label}: all six roots have separate release beats`).toBe(6);
  expect(Math.max(...arrivals.map(delay)) - Math.min(...arrivals.map(delay)),
    `${label}: the packet spreads across a perceptible release sequence`).toBeGreaterThan(0.55);
  const crossLanePairs = arrivals.flatMap(early => arrivals
    .filter(late => early.slot > late.slot && delay(late) - delay(early) > 0.29)
    .map(late => ({ early, late })));
  expect(crossLanePairs.length, `${label}: release order crosses the row instead of sweeping left to right`).toBeGreaterThan(0);
  const pitch = after.board_rect[3] / after.rows;
  const travel = (frame, root) => {
    const tile = frame.tiles.find(tile => tile.id === root.id);
    return tile ? tile.rect[1] + tile.rect[3] / 2 - root.source.rect[1] - root.source.rect[3] / 2 : Number.NaN;
  };
  expect(timeline.some(frame => crossLanePairs.some(({ early, late }) =>
    travel(frame, early) > pitch * 0.15 && Math.abs(travel(frame, late)) < 1)),
  `${label}: a later column visibly falls while an earlier column still waits at the tray`).toBe(true);
  expect(timeline.some(frame => arrivals.some(early => travel(frame, early) > pitch * 0.25 &&
    frame.preview[early.slot].visible && frame.preview[early.slot].id !== early.id) &&
    arrivals.some(late => Math.abs(travel(frame, late)) < 1 && !frame.preview[late.slot].visible)),
  `${label}: cleared preview slots refill while other departing roots still wait`).toBe(true);
  expect(after.generated_tiles).toBe(before.generated_tiles + 6);
  expect(after.merged_count).toBe(before.merged_count);
  expect(after.cleared_pairs).toBe(before.cleared_pairs);
  expect(after.collected_coins).toBe(before.collected_coins);
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyArrivalFrame)),
    { message: 'The actual browser captures the jellies between the tray and their support' }).toBe(true);
  const encoded = await page.evaluate(() => window.wordJellyArrivalFrame);
  fs.writeFileSync(info.outputPath(`word-jelly-${label}-falling-midpoint.png`), Buffer.from(encoded, 'base64'));
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyStaggerFrame)),
    { message: 'The browser captures roots falling at visibly different heights' }).toBe(true);
  const stagger = await page.evaluate(() => window.wordJellyStaggerFrame);
  fs.writeFileSync(info.outputPath(`word-jelly-${label}-staggered-release.png`), Buffer.from(stagger, 'base64'));
  await capture(page, info, `word-jelly-${label}-landed`);
  await page.evaluate(() => window.wordJellyArrivalObserver.disconnect());
}

test('manual and automatic preview packets naturally fall into the well', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors = await startWordJelly(page), manual = await jelly(page);
  expectSupplyLayout(manual, await metrics(page));
  for (let row = manual.rows - 3; row < manual.rows; row++) {
    const roots = manual.tiles.filter(tile => tile.row === row).sort((a, b) => a.column - b.column);
    expectMixedRootPacket(roots, `Starter row ${row}`);
    expectRootBreathingRoom(roots, manual.board_rect[2] / manual.columns, `Starter row ${row}`);
  }
  expectMixedRootPacket(manual.upcoming, 'Manual supply');
  expectRootBreathingRoom(manual.preview.slots, manual.board_rect[2] / manual.columns, 'Preview row');
  expect(manual.preview.slots.filter(slot => slot.visible)).toHaveLength(6);
  expect(manual.preview.rect[1] + manual.preview.rect[3], 'The supply tray is above the well on every layout')
    .toBeLessThanOrEqual(manual.board_rect[1]);
  expect(new Set(manual.preview.slots.map(slot => Math.round(slot.rect[1]))).size,
    'All six visible previews share one horizontal row').toBe(1);
  await capture(page, info, 'word-jelly-supply-before-release');
  await observeArrival(page, manual);
  await pressRect(page, manual.preview.rect);
  await verifyArrival(page, info, manual, 'manual-supply');
  const automatic = await jelly(page);
  expectMixedRootPacket(automatic.upcoming, 'Automatic supply');
  await observeArrival(page, automatic);
  await verifyArrival(page, info, automatic, 'automatic-supply');
  expect(errors).toEqual([]);
});

test('collecting a lower word makes the stack above it visibly fall onto support', async ({ page }, info) => {
  const errors = await startWordJelly(page), opening = await jelly(page), startingWallet = await wallet(page);
  const floor = opening.tiles.filter(tile => tile.row === opening.rows - 1 && tile.mass === 1)
    .sort((a, b) => a.column - b.column);
  const found = rootsForWord({ tiles: floor }, 3, 2) || rootsForWord({ tiles: floor }, 3, 3);
  expect(found, 'The first ordinary supply packet contains a complete word among its dispersed floor roots').toBeTruthy();
  const { roots, word } = found;
  let completed = await merge(page, roots[0].id, roots[1].id);
  for (const root of roots.slice(2)) completed = await merge(page, completed.id, root.id);
  expect(completed.word.id).toBe(word.id);
  const before = await jelly(page);
  // Joining separated floor roots can move their larger body upward. Their old
  // columns stay in place until collection initiates the ordinary gravity pass.
  const stack = before.tiles.filter(tile => tile.row === before.rows - 2 && tile.mass === 1 &&
    roots.some(root => root.column === tile.column) &&
    !before.tiles.some(support => support.id !== completed.id && support.row === before.rows - 1 &&
      support.column <= tile.column && support.column + support.width > tile.column));
  expect(stack.length, 'At least one original upper root will lose its floor support after collection').toBeGreaterThan(0);
  for (const tile of stack) {
    const original = opening.tiles.find(root => root.id === tile.id);
    expect(tile.settled, 'Merging keeps the suspended upper root still until collection').toBe(true);
    expect([tile.column, tile.row]).toEqual([original.column, original.row]);
    expect(tile.rect).toEqual(original.rect);
  }
  await page.evaluate(stack => {
    const status = document.getElementById('game-status');
    window.wordJellyGravityTimeline = [];
    window.wordJellyGravityFrame = null;
    let capturePending = false;
    const descentPositions = new Set();
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tracked = state.tiles?.filter(tile => stack.some(original => original.id === tile.id)) || [];
      window.wordJellyGravityTimeline.push(tracked.map(tile => ({ id: tile.id, row: tile.row,
        y: tile.rect[1], settled: tile.settled, falling: tile.falling, age: tile.age, time: performance.now() })));
      const first = tracked.find(tile => tile.id === stack[0].id);
      if (first?.falling && !first.settled && first.rect[1] > stack[0].rect[1] &&
        first.rect[1] < stack[0].rect[1] + state.board_rect[3] / state.rows)
        descentPositions.add(first.rect[1]);
      if (!capturePending && descentPositions.size > 1) {
        capturePending = true;
        // Encoding a full device-resolution PNG synchronously can stall the short fall on WebKit.
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = () => { window.wordJellyGravityFrame = reader.result.split(',')[1]; };
          reader.readAsDataURL(blob);
        }, 'image/png');
      }
    };
    new MutationObserver(record).observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  }, stack);
  await capture(page, info, 'word-jelly-supported-stack-before-collection');
  await pressRect(page, completed.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.cleared_pairs === before.cleared_pairs + 1 && stack.every(original => {
      const tile = state.tiles.find(tile => tile.id === original.id);
      return tile?.settled && tile.row === original.row + 1;
    });
  }, { message: 'Removing the lower word lets every supported upper jelly settle one row lower' }).toBe(true);
  const after = await jelly(page), bounds = await metrics(page);
  for (const original of stack) {
    const landed = after.tiles.find(tile => tile.id === original.id);
    expect([landed.column, landed.row]).toEqual([original.column, original.row + 1]);
    expect({ text: landed.text, mass: landed.mass, fragments: landed.fragments })
      .toEqual({ text: original.text, mass: original.mass, fragments: original.fragments });
    expect(landed.fragment_badges).toBe(original.fragments);
    expect(landed.rect[1]).toBeGreaterThan(original.rect[1]);
    expectSupportedChild(after, landed);
    expectInside(landed.rect, bounds);
  }
  for (const grounded of before.tiles.filter(tile => tile.id !== completed.id && tile.row + tile.height === before.rows)) {
    const unchanged = after.tiles.find(tile => tile.id === grounded.id);
    expect([unchanged.column, unchanged.row], 'Gravity leaves an already grounded neighbor in place')
      .toEqual([grounded.column, grounded.row]);
  }
  const timeline = await page.evaluate(() => window.wordJellyGravityTimeline);
  await info.attach('word-jelly-gravity-timeline.json', { body: JSON.stringify(timeline, null, 2), contentType: 'application/json' });
  const original = stack[0], landed = after.tiles.find(tile => tile.id === original.id);
  const descent = timeline.flat().filter(tile => tile.id === original.id && !tile.settled &&
    tile.y > original.rect[1] && tile.y < landed.rect[1]);
  expect(new Set(descent.map(tile => tile.y)).size, 'Collection gravity has multiple visible descent positions').toBeGreaterThan(1);
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyGravityFrame)),
    { message: 'The asynchronous intermediate-frame capture finishes without stalling the descent' }).toBe(true);
  const frame = await page.evaluate(() => window.wordJellyGravityFrame);
  fs.writeFileSync(info.outputPath('word-jelly-stack-falling-midpoint.png'), Buffer.from(frame, 'base64'));
  await capture(page, info, 'word-jelly-stack-landed-after-collection');
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + completed.mass * 50);
  expect(after.collected_coins).toBe(before.collected_coins + completed.mass * 50);
  expect(after.fragment_count).toBe(before.fragment_count + completed.fragments);
  expect(errors).toEqual([]);
});

test('word pair colors distinguish exact completion targets and preserve source order', async ({ page }, info) => {
  const errors = await startWordJelly(page), opening = await jelly(page);
  const words = new Set(vocabulary.filter(word => word.min_age === 3).map(word => normalize(word.text)));
  const roots = opening.tiles.filter(tile => tile.mass === 1 && tile.settled && tile.visible);
  const pair = roots.flatMap(source => roots.map(target => ({ source, target }))).find(({ source, target }) =>
    source.id !== target.id && source.palette_index === target.palette_index &&
    words.has(normalize(source.text + target.text)) && !words.has(normalize(target.text + source.text)));
  expect(pair, 'The real board provides a shared-color word pair with an unambiguous spelling order').toBeTruthy();
  for (const tile of roots) {
    expect(tile.palette_index).toBeGreaterThanOrEqual(0);
    expect(tile.palette_hue).toBeGreaterThanOrEqual(0);
    for (const other of roots.filter(other => other.id > tile.id && other.palette_index === tile.palette_index))
      expect(words.has(normalize(tile.text + other.text)) || words.has(normalize(other.text + tile.text)),
        'An unrelated pair cannot share a resting hint color').toBe(true);
  }
  for (const slot of opening.preview.slots.filter(slot => slot.visible)) {
    expect(slot.palette_index, 'Upcoming roots render an assigned word-pair color').toBeGreaterThanOrEqual(0);
    expect(slot.palette_hue).toBeGreaterThanOrEqual(0);
  }
  await capture(page, info, 'word-jelly-distinct-word-pair-colors');
  const bounds = await metrics(page), point = center(pair.source.rect, bounds);
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(pair.source.id);
    const selected = await jelly(page), source = selected.tiles.find(tile => tile.id === pair.source.id);
    const validTargets = selected.tiles.filter(tile => tile.id !== source.id && words.has(normalize(source.text + tile.text)));
    expect(validTargets.length).toBeGreaterThan(0);
    for (const target of validTargets) {
      expect(target.palette_index).toBe(source.palette_index);
      expect(target.palette_hue).toBeCloseTo(source.palette_hue, 5);
    }
    for (const target of selected.tiles.filter(tile => tile.id !== source.id && !words.has(normalize(source.text + tile.text))))
      expect(target.palette_index, 'Every invalid ordered target differs from the held source').not.toBe(source.palette_index);
    await capture(page, info, 'word-jelly-compatible-target-colors');
  } finally {
    await page.mouse.up();
  }
  const reverse = center(pair.target.rect, bounds);
  await page.mouse.move(reverse.x, reverse.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(pair.target.id);
    const selected = await jelly(page);
    expect(selected.tiles.find(tile => tile.id === pair.source.id).palette_index,
      'Selecting the suffix does not falsely advertise the reversed word as a completion')
      .not.toBe(selected.tiles.find(tile => tile.id === pair.target.id).palette_index);
  } finally {
    await page.mouse.up();
  }
  const completed = await merge(page, pair.source.id, pair.target.id);
  expect(words.has(normalize(completed.text))).toBe(true);
  expect(completed.picture_visible).toBe(true);
  expect(completed.palette_index).toBeGreaterThanOrEqual(0);
  await capture(page, info, 'word-jelly-color-guided-completed-word');
  expect(errors).toEqual([]);
});

test('six columns build a pictured word and a deliberate tap credits its coins once', async ({ page }, info) => {
  const errors = await startWordJelly(page), opening = await jelly(page), bounds = await metrics(page);
  expect(opening.tiles).toHaveLength(18);
  expect(opening.columns).toBe(6);
  const startingRows = [opening.rows - 3, opening.rows - 2, opening.rows - 1];
  expect([...new Set(opening.tiles.map(tile => tile.row))].sort((a, b) => a - b),
    'The opening occupies exactly the three bottom rows').toEqual(startingRows);
  for (const row of startingRows) {
    expect(opening.tiles.filter(tile => tile.row === row).map(tile => tile.column).sort((a, b) => a - b),
      'Every opening row fills all six columns').toEqual([0, 1, 2, 3, 4, 5]);
  }
  expect([...new Set(opening.tiles.map(tile => tile.column))].sort((a, b) => a - b)).toEqual([0, 1, 2, 3, 4, 5]);
  expect(new Set(opening.tiles.map(tile => Math.round(tile.rect[0]))).size,
    'All six columns occupy distinct rendered horizontal positions').toBe(6);
  expect(opening.upcoming).toHaveLength(6);
  for (const tile of opening.tiles) {
    expect(tile.mass).toBe(1);
    expect(tile.picture_visible, 'A standalone root does not pretend to be a completed word').toBe(false);
    expectInside(tile.rect, bounds);
  }
  await capture(page, info, 'word-jelly-six-column-opening');
  const originalViewport = page.viewportSize();
  for (const viewport of [{ width: 1473, height: 1175 }, { width: 768, height: 1024 },
    { width: 390, height: 844 }, { width: 568, height: 320 }]) {
    await page.setViewportSize(viewport);
    await rendered(page);
    await expect(async () => expectSupplyLayout(await jelly(page), await metrics(page)))
      .toPass({ timeout: 5000 });
  }
  await page.setViewportSize(originalViewport);
  await rendered(page);
  await expect(async () => expectSupplyLayout(await jelly(page), await metrics(page)))
    .toPass({ timeout: 5000 });
  const { roots, word } = await availableWord(page, 3, 2), startingWallet = await wallet(page);
  await pressRect(page, roots[0].rect);
  await page.waitForTimeout(500);
  expect((await jelly(page)).tiles.some(tile => tile.id === roots[0].id), 'Tapping an unfinished root leaves it on the board').toBe(true);
  expect((await wallet(page)).balance).toBe(startingWallet.balance);
  const merged = await merge(page, roots[0].id, roots[1].id);
  expect(merged.word.id).toBe(word.id);
  expect(merged.word.min_age).toBe(3);
  expect(merged.picture_visible, 'The actual word art appears on the completed jelly').toBe(true);
  expect(merged.rect[2] * merged.rect[3]).toBeGreaterThan(roots[0].rect[2] * roots[0].rect[3] * 1.5);
  expect((await wallet(page)).balance, 'A word can remain on the board without spending its reward').toBe(startingWallet.balance);
  await capture(page, info, 'word-jelly-valid-pictured-word');
  await openModeMenu(page);
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  const paused = await jelly(page);
  await page.waitForTimeout(500);
  const stillPaused = await jelly(page);
  expect(stillPaused.spawn_elapsed, 'The word supply clock pauses behind the menu').toBe(paused.spawn_elapsed);
  expect(stillPaused.tiles.map(tile => tile.id)).toEqual(paused.tiles.map(tile => tile.id));
  await chooseMode(page, 'word_jelly');
  await expect.poll(async () => (await jelly(page)).paused).toBe(false);
  await expect.poll(async () => (await jelly(page)).visible).toBe(true);
  const before = await jelly(page);
  const resumed = before.tiles.find(tile => tile.id === merged.id);
  expect(resumed.picture_visible, 'The complete word survives opening and closing the menu').toBe(true);
  await pressRect(page, resumed.rect);
  await pressRect(page, resumed.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + 100);
  const collected = await jelly(page);
  expect(collected.tiles.some(tile => tile.id === merged.id)).toBe(false);
  expect(collected.collected_coins).toBe(before.collected_coins + 100);
  expect(collected.fragment_count).toBe(before.fragment_count + merged.fragments);
  await openModeMenu(page);
  const match = (await metrics(page)).library.controls.find(item => item.name === 'Mode_match');
  await pressRect(page, match.rect);
  await expect.poll(async () => (await metrics(page)).library.current).toBe('match');
  expect((await wallet(page)).balance, 'Leaving the mode never pays the collected word again').toBe(startingWallet.balance + 100);
  await page.reload();
  await enterGame(page);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + 100);
  expect(errors).toEqual([]);
});

test('collect button grows with completed words and collects a rhythmic batch once', async ({ page }, info) => {
  test.setTimeout(240000);
  const errors = await startWordJelly(page), initial = await jelly(page), bounds = await metrics(page);
  expect(initial.collect_button.visible).toBe(true);
  expect(initial.collect_button.enabled).toBe(false);
  expect(initial.collect_button.count).toBe(0);
  expectSupplyLayout(initial, bounds);
  await capture(page, info, 'word-jelly-collect-count-0');
  const collectedIds = [];
  const stages = [initial.collect_button];
  for (let count = 1; count <= 3; count++) {
    const { roots } = await availableWord(page, 3, 2, { markedOnly: count === 1 });
    const merged = await merge(page, roots[0].id, roots[1].id);
    collectedIds.push(merged.id);
    await expect.poll(async () => (await jelly(page)).collect_button.count).toBe(count);
    await expect.poll(async () => (await jelly(page)).collect_button.charge).toBeGreaterThan(count - 0.1);
    const state = await jelly(page);
    expect(state.collect_button.enabled).toBe(true);
    expect(state.collect_button.rect, 'Accumulation grows artwork without moving its hit target').toEqual(initial.collect_button.rect);
    if (count === 1 || count === 3) {
      stages.push(state.collect_button);
      await capture(page, info, `word-jelly-collect-count-${count}`);
    }
  }
  expect(stages[1].visual_scale, 'One ready word charges the quiet empty control').toBeGreaterThan(stages[0].visual_scale);
  expect(stages[2].visual_scale, 'Three words visibly grow the charged control').toBeGreaterThan(stages[1].visual_scale);
  expect(stages[2].sparkle_count).toBeGreaterThanOrEqual(stages[1].sparkle_count);
  const before = await jelly(page), startingWallet = await wallet(page);
  const selected = before.tiles.filter(tile => collectedIds.includes(tile.id));
  const retained = before.tiles.filter(tile => !collectedIds.includes(tile.id)).map(tile => tile.id);
  const expectedCoins = selected.reduce((sum, tile) => sum + tile.coins, 0);
  const expectedFragments = selected.reduce((sum, tile) => sum + tile.fragments, 0);
  expect(expectedFragments, 'The ordinary-input batch includes a real carried treasure fragment').toBeGreaterThan(0);
  await page.exposeFunction('saveWordJellyBatchFrame', (index, encoded) =>
    fs.writeFileSync(info.outputPath(`word-jelly-batch-${index}.png`), Buffer.from(encoded, 'base64')));
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.wordJellyBatchTimeline = [];
    window.wordJellyBatchCaptured = [];
    const pending = new Set();
    window.wordJellyBatchObserver = new MutationObserver(() => {
      const state = JSON.parse(status.dataset.jelly || '{}'), batch = state.collection_batch;
      if (!batch?.total) return;
      window.wordJellyBatchTimeline.push({ ...batch, button: state.collect_button,
        effects: state.fusion_effects, revealed: state.word_reveal, cleared: state.cleared_pairs,
        collectedCoins: state.collected_coins, fragments: state.fragment_count, at: performance.now() });
      const reveal = state.word_reveal;
      // A 100 ms status publication can skip a whole 100 ms pickup. Capture
      // playback and the final reading pose, without requiring every transient.
      const index = batch.active && batch.started && state.fusion_effects?.length ? 'active' :
        !batch.active && batch.completed === batch.total && reveal?.visible && reveal.content_alpha > 0.9 ? 'reveal' : '';
      if (!index || pending.has(index)) return;
      pending.add(index);
      // Let the status update reach the rendered canvas before capturing it.
      requestAnimationFrame(() => requestAnimationFrame(() => {
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = async () => {
            await window.saveWordJellyBatchFrame(index, reader.result.split(',')[1]);
            window.wordJellyBatchCaptured.push(index);
          };
          reader.readAsDataURL(blob);
        }, 'image/png');
      }));
    });
    window.wordJellyBatchObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
  });
  // Consecutive trusted presses exercise the disabled state during playback.
  const point = center(before.collect_button.rect, bounds);
  await page.touchscreen.tap(point.x, point.y);
  await page.touchscreen.tap(point.x, point.y);
  await expect.poll(async () => (await jelly(page)).collection_batch.completed,
    { message: 'Every captured completed word is collected through the rhythmic queue' }).toBe(3);
  await expect.poll(async () => (await jelly(page)).collection_batch.active).toBe(false);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + expectedCoins);
  let timeline;
  try {
    await expect.poll(() => page.evaluate(() => window.wordJellyBatchCaptured.slice().sort()),
      { message: 'The real batch animation and final readable word both produce rendered evidence' }).toEqual(['active', 'reveal']);
  } finally {
    timeline = await page.evaluate(() => {
      window.wordJellyBatchObserver.disconnect();
      return window.wordJellyBatchTimeline;
    });
    fs.writeFileSync(info.outputPath('word-jelly-batch-timeline.json'), JSON.stringify({ stages, timeline }, null, 2));
  }
  const final = await jelly(page);
  expect(timeline.some(frame => frame.active), 'The observer sees the disabled control during batch playback').toBe(true);
  expect(timeline.some(frame => !frame.active && frame.completed === 3), 'The browser observes the completed queue').toBe(true);
  const selectedById = new Map(selected.map(tile => [tile.id, tile]));
  let previousStarted = 0, previousCompleted = 0;
  for (const frame of timeline) {
    expect(frame.total).toBe(3);
    expect(frame.ids.slice().sort((a, b) => a - b)).toEqual(collectedIds.slice().sort((a, b) => a - b));
    expect(frame.skipped, 'Every captured word remains eligible throughout playback').toBe(0);
    expect(frame.started).toBeGreaterThanOrEqual(previousStarted);
    expect(frame.started).toBeLessThanOrEqual(3);
    expect(frame.completed).toBeGreaterThanOrEqual(previousCompleted);
    expect(frame.completed).toBeLessThanOrEqual(frame.started);
    expect(frame.started - frame.completed, 'The active disappearance never overlaps a second payout').toBeLessThanOrEqual(1);
    expect(frame.effects.length, 'Only one collection effect is active at each observed point').toBeLessThanOrEqual(1);
    const paid = frame.ids.slice(0, frame.completed).map(id => selectedById.get(id));
    expect(frame.cleared, 'Only the completed prefix has cleared from the board').toBe(before.cleared_pairs + paid.length);
    expect(frame.collectedCoins, 'Observed coin credit matches the completed prefix exactly')
      .toBe(before.collected_coins + paid.reduce((sum, tile) => sum + tile.coins, 0));
    expect(frame.fragments, 'Observed treasure credit matches the same completed prefix')
      .toBe(before.fragment_count + paid.reduce((sum, tile) => sum + tile.fragments, 0));
    if (frame.active) expect(frame.button.enabled).toBe(false);
    previousStarted = frame.started;
    previousCompleted = frame.completed;
  }
  expect(final.collection_batch.started).toBe(3);
  expect(final.collection_batch.completed).toBe(3);
  expect(final.collection_batch.elapsed, 'Three 100 ms collections finish in 300 ms of game time').toBeCloseTo(0.3, 6);
  const readable = timeline.find(frame => !frame.active && frame.revealed?.visible && frame.revealed.content_alpha > 0.9);
  const lastWord = selectedById.get(final.collection_batch.ids.at(-1)).word;
  expect(readable, 'The final collected word retains an opaque reading pose after the fast batch').toBeTruthy();
  expect(readable.revealed.word_id).toBe(lastWord.id);
  expect(readable.revealed.spelling).toBe(lastWord.text);
  expect(final.cleared_pairs).toBe(before.cleared_pairs + 3);
  expect(final.collected_coins).toBe(before.collected_coins + expectedCoins);
  expect(final.fragment_count).toBe(before.fragment_count + expectedFragments);
  expect(final.tiles.some(tile => collectedIds.includes(tile.id))).toBe(false);
  for (const id of retained) expect(final.tiles.some(tile => tile.id === id), 'Batch collection preserves unfinished roots').toBe(true);
  expect(final.collect_button.enabled).toBe(false);
  expect(final.collect_button.count).toBe(0);
  await capture(page, info, 'word-jelly-batch-completed');
  await page.waitForTimeout(800);
  expect((await wallet(page)).balance, 'Later presentation frames cannot repeat batch rewards').toBe(startingWallet.balance + expectedCoins);
  expect(errors).toEqual([]);
});

test('collected words reveal their picture and spelling above the bottom-anchored game with one pronunciation', async ({ page, browserName }, info) => {
  await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 4 });
  const errors = await startWordJelly(page), opening = await jelly(page), bounds = await metrics(page);
  const scale = Math.max(2 / 3, bounds.scale), area = opening.playfield_rect;
  const gameBottom = Math.max(opening.board_rect[1] + opening.board_rect[3], opening.finish.rect[1] + opening.finish.rect[3]);
  expect(Math.abs(gameBottom - (area[1] + area[3] - 12 / scale)) * bounds.scale,
    'The game group ends at its bottom padding within a quarter rendered pixel, including the portrait Finish control')
    .toBeLessThan(0.25);
  expect(opening.preview.rect[1] + opening.preview.rect[3], 'The full supply tray remains above the board')
    .toBeLessThanOrEqual(opening.board_rect[1]);
  expect(opening.word_reveal.visible).toBe(false);
  await capture(page, info, 'word-jelly-bottom-anchored-opening');
  const supportedWords = state => rootsForWord({ ...state, tiles: state.tiles.filter(tile => tile.row + tile.height === state.rows) }, 3, 2);
  const first = supportedWords(await jelly(page));
  expect(first, 'A floor-supported word is available for the first collection').toBeTruthy();
  const firstMerged = await merge(page, first.roots[0].id, first.roots[1].id);
  const second = supportedWords(await jelly(page));
  expect(second, 'The initial board supplies another word for rapid successive collection').toBeTruthy();
  const secondMerged = await merge(page, second.roots[0].id, second.roots[1].id);
  expect(second.word.id).not.toBe(first.word.id);
  await page.exposeFunction('saveWordRevealFrame', (id, encoded) =>
    fs.writeFileSync(info.outputPath(`word-jelly-reveal-${id}.png`), Buffer.from(encoded, 'base64')));
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.wordRevealTimeline = [];
    window.wordRevealFrames = {};
    window.wordRevealInputs = [];
    window.wordRevealInputHandler = event => {
      if (event.isTrusted && event.target.id === 'canvas')
        window.wordRevealInputs.push({ at: performance.now(), sounds: window.audioObservation.playbacks.length });
    };
    document.addEventListener('pointerdown', window.wordRevealInputHandler, { capture: true });
    const pending = new Set();
    window.wordRevealObserver = new MutationObserver(() => {
      const state = JSON.parse(status.dataset.jelly || '{}'), reveal = state.word_reveal;
      if (!reveal) return;
      window.wordRevealTimeline.push({ ...reveal, at: performance.now(), cleared: state.cleared_pairs });
      if (!reveal.visible || reveal.content_alpha < 0.95 || reveal.elapsed < 0.20 || pending.has(reveal.word_id)) return;
      pending.add(reveal.word_id);
      document.getElementById('canvas').toBlob(blob => {
        if (!blob) return;
        const reader = new FileReader();
        reader.onload = () => {
          const encoded = reader.result.split(',')[1];
          window.wordRevealFrames[reveal.word_id] = encoded;
          window.saveWordRevealFrame(reveal.word_id, encoded);
        };
        reader.readAsDataURL(blob);
      }, 'image/png');
    });
    window.wordRevealObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
  });
  const before = await jelly(page), startingWallet = await wallet(page);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  if (browserName === 'chromium') expect(audioAvailable).toBe(true);
  const candidates = [{ merged: firstMerged, word: first.word }, { merged: secondMerged, word: second.word }];
  const points = candidates.map(candidate => center(before.tiles.find(tile => tile.id === candidate.merged.id).rect, bounds));
  // Keep trusted gestures inside the reading beat. Helpers that wait for DOM
  // snapshots between each tap can consume the whole short effect under tracing.
  await page.touchscreen.tap(points[0].x, points[0].y);
  await page.touchscreen.tap(points[0].x, points[0].y);
  await page.waitForTimeout(240);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.touchscreen.tap(points[1].x, points[1].y);
  await page.touchscreen.tap(points[1].x, points[1].y);
  await expect.poll(() => page.evaluate(() => Object.keys(window.wordRevealFrames).length),
    { message: 'Both real reading beats produce a captured opaque picture and spelling' }).toBe(2);
  const evidence = await page.evaluate(() => ({ timeline: window.wordRevealTimeline, frames: window.wordRevealFrames,
    inputs: window.wordRevealInputs, sounds: window.audioObservation.playbacks }));
  fs.writeFileSync(info.outputPath('word-jelly-reveal-timeline.json'), JSON.stringify(evidence.timeline, null, 2));
  const firstReplacement = evidence.timeline.findIndex(reveal => reveal.visible && reveal.word_id === second.word.id);
  expect(firstReplacement).toBeGreaterThan(0);
  expect(evidence.timeline[firstReplacement - 1].word_id, 'The next word replaces the first while its layer is still active').toBe(first.word.id);
  expect(evidence.timeline[firstReplacement - 1].visible).toBe(true);
  if (audioAvailable) expect(evidence.inputs, 'The four real taps delimit separate word-audio windows').toHaveLength(4);
  const pronunciationObservations = [];
  for (const [index, candidate] of candidates.entries()) {
    const reveal = evidence.timeline.find(frame => frame.visible && frame.word_id === candidate.word.id && frame.content_alpha > 0.95);
    expect(reveal, 'Each collected word owns a readable opaque hold within its actual lifetime').toBeTruthy();
    expect(reveal.spelling).toBe(candidate.word.text);
    expect(reveal.word.id).toBe(candidate.word.id);
    expect(reveal.picture.replace(/^res:\/\//, '')).toBe(candidate.merged.word.image);
    for (const rect of [reveal.rect, reveal.picture_rect, reveal.spelling_rect]) expectInside(rect, bounds);
    expect(reveal.rect[1] + reveal.rect[3], 'The reveal uses the upper part of the playfield')
      .toBeLessThan(area[1] + area[3] * 0.42);
    expect(reveal.picture_rect[0] + reveal.picture_rect[2]).toBeLessThan(reveal.spelling_rect[0]);
    if (index === 1) expect(reveal.reduced_motion, 'The replacement word also supports a steady reduced-motion reading beat').toBe(true);
    if (audioAvailable) {
      const from = evidence.inputs[index * 2].sounds, end = evidence.inputs[(index + 1) * 2]?.sounds;
      const timing = recordingTiming(candidate.word.audio);
      const sounds = evidence.sounds.slice(from, end).filter(sound => sound.contextState === 'running' &&
        Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate);
      expect(sounds, 'Duplicate taps and the effect play one pronunciation per word, even when both recordings have equal length').toHaveLength(1);
      expect(sounds[0].peak, 'The bundled pronunciation contains audible samples').toBeGreaterThan(0.01);
      pronunciationObservations.push({ from, end, relative: candidate.word.audio, sound: sounds[0] });
    }
  }
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 2);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + 200);
  await expect.poll(async () => (await jelly(page)).word_reveal.visible,
    { message: 'The picture and spelling leave on their own after the reading beat' }).toBe(false);
  const final = await jelly(page);
  expect(final.collected_coins).toBe(before.collected_coins + 200);
  expect(final.fragment_count).toBe(before.fragment_count + firstMerged.fragments + secondMerged.fragments);
  fs.writeFileSync(info.outputPath('word-jelly-reveal-timeline.json'), JSON.stringify({ timeline: evidence.timeline, pronunciationObservations }, null, 2));
  await page.evaluate(() => {
    window.wordRevealObserver.disconnect();
    document.removeEventListener('pointerdown', window.wordRevealInputHandler, { capture: true });
  });
  expect(errors).toEqual([]);
});

test('an incorrect merged word splits into its original parts and can be corrected for one reward', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors = await startWordJelly(page);
  const { roots, word } = await availableWord(page, 3, 2, { markedOnly: true, invalidReverse: true });
  const startingWallet = await wallet(page);
  const incorrect = await merge(page, roots[1].id, roots[0].id);
  expect(incorrect.mass).toBe(2);
  expect(incorrect.word).toEqual({});
  expect(incorrect.picture_visible).toBe(false);
  expect(incorrect.fragment_badges).toBe(roots[0].fragments + roots[1].fragments);
  await capture(page, info, 'word-jelly-incorrect-merged-word');
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.wordJellySplitTimeline = [];
    window.wordJellySplitFrame = null;
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const split = state.fusions?.find(fusion => fusion.operation === 'split');
      if (!split) return;
      window.wordJellySplitTimeline.push({ elapsed: split.elapsed, duration: split.duration,
        parent: split.a_id, children: split.results.map(child => child.id) });
      if (!window.wordJellySplitFrame && split.elapsed >= split.duration * 0.45 && split.elapsed < split.duration * 0.8)
        window.wordJellySplitFrame = document.getElementById('canvas').toDataURL('image/png').split(',')[1];
    };
    new MutationObserver(record).observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
  });
  const before = await jelly(page);
  await pressRect(page, incorrect.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.tiles.some(tile => tile.id === incorrect.id) &&
      roots.every(root => state.tiles.some(tile => tile.id === root.id && tile.visible && tile.settled));
  }, { message: 'Tapping an incorrect merge restores its two original roots after separation' }).toBe(true);
  const restored = await jelly(page), bounds = await metrics(page);
  expect(new Set(restored.tiles.map(tile => tile.id)).size, 'No split can duplicate a child identity').toBe(restored.tiles.length);
  for (const root of roots) {
    const child = restored.tiles.find(tile => tile.id === root.id);
    expect({ text: child.text, mass: child.mass, fragments: child.fragments })
      .toEqual({ text: root.text, mass: root.mass, fragments: root.fragments });
    expect(child.fragment_badges).toBe(root.fragments);
    expectInside(child.rect, bounds);
    expectSupportedChild(restored, child);
  }
  for (const original of before.tiles.filter(tile => tile.id !== incorrect.id)) {
    const unchanged = restored.tiles.find(tile => tile.id === original.id);
    expect([unchanged.column, unchanged.row], 'Splitting leaves unrelated occupied cells in place')
      .toEqual([original.column, original.row]);
  }
  expect(restored.cleared_pairs).toBe(before.cleared_pairs);
  expect(restored.fragment_count).toBe(before.fragment_count);
  expect(restored.collected_coins).toBe(before.collected_coins);
  expect((await wallet(page)).balance, 'Splitting an incorrect word cannot pay coins').toBe(startingWallet.balance);
  const animation = await page.evaluate(() => ({ timeline: window.wordJellySplitTimeline, frame: window.wordJellySplitFrame }));
  expect(new Set(animation.timeline.map(frame => frame.elapsed)).size, 'Split advances through distinct separation poses').toBeGreaterThan(2);
  expect(animation.frame, 'The real split has a rendered midpoint').toBeTruthy();
  fs.writeFileSync(info.outputPath('word-jelly-split-midpoint.png'), Buffer.from(animation.frame, 'base64'));
  await capture(page, info, 'word-jelly-restored-original-parts');
  const corrected = await merge(page, roots[0].id, roots[1].id);
  expect(corrected.word.id).toBe(word.id);
  expect(corrected.picture_visible).toBe(true);
  expect(corrected.fragments).toBe(roots[0].fragments + roots[1].fragments);
  await capture(page, info, 'word-jelly-corrected-pictured-word');
  await pressRect(page, corrected.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + 100);
  expect((await jelly(page)).fragment_count).toBe(before.fragment_count + corrected.fragments);
  expect((await jelly(page)).tiles.some(tile => tile.id === corrected.id || roots.some(root => root.id === tile.id))).toBe(false);
  expect(errors).toEqual([]);
});

test('splitting a raised incorrect merge places both original roots on solid support', async ({ page }, info) => {
  const errors = await startWordJelly(page), opening = await jelly(page), startingWallet = await wallet(page);
  const words = new Set(vocabulary.filter(word => word.min_age === 3).map(word => normalize(word.text)));
  const bottom = opening.tiles.filter(tile => tile.visible && tile.settled && tile.mass === 1 && tile.row === opening.rows - 1);
  const upper = opening.tiles.filter(tile => tile.visible && tile.settled && tile.mass === 1 && tile.row === opening.rows - 2);
  const candidates = bottom.flatMap(source => upper.map(target => ({ source, target })));
  const pair = candidates.find(({ source, target }) => Math.abs(source.column - target.column) >= 2 &&
    source.fragments + target.fragments > 0 && !words.has(normalize(source.text + target.text)));
  expect(pair, 'The real starter board offers a marked, nonadjacent bottom-to-upper incorrect merge').toBeTruthy();
  const { source, target } = pair;
  const raised = await merge(page, source.id, target.id);
  expect(raised.word).toEqual({});
  expect(raised.row, 'The two-wide merge must remain raised above the crowded target row').toBeLessThan(target.row);
  const beforeSplit = await jelly(page);
  const lowerRow = raised.row + raised.height;
  const hasHoleBelow = Array.from({ length: raised.width }, (_, offset) => raised.column + offset)
    .some(column => !beforeSplit.tiles.some(tile => tile.id !== raised.id &&
      tile.column <= column && tile.column + tile.width > column && tile.row <= lowerRow && tile.row + tile.height > lowerRow));
  expect(hasHoleBelow, 'The raised parent straddles an empty cell left by the nonadjacent merge').toBe(true);
  await capture(page, info, 'word-jelly-raised-parent-over-gap');
  await pressRect(page, raised.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.tiles.some(tile => tile.id === raised.id) && [source, target].every(original =>
      state.tiles.some(tile => tile.id === original.id && tile.settled && tile.visible));
  }, { message: 'Splitting the raised parent restores two settled children with supported destinations' }).toBe(true);
  const restored = await jelly(page), bounds = await metrics(page);
  for (const original of [source, target]) {
    const child = restored.tiles.find(tile => tile.id === original.id);
    expect({ text: child.text, mass: child.mass, fragments: child.fragments })
      .toEqual({ text: original.text, mass: original.mass, fragments: original.fragments });
    expect(child.fragment_badges).toBe(original.fragments);
    expectInside(child.rect, bounds);
    expectSupportedChild(restored, child);
  }
  expect(new Set(restored.tiles.map(tile => tile.id)).size).toBe(restored.tiles.length);
  expect(restored.fragment_count).toBe(beforeSplit.fragment_count);
  expect(restored.collected_coins).toBe(beforeSplit.collected_coins);
  expect((await wallet(page)).balance).toBe(startingWallet.balance);
  await capture(page, info, 'word-jelly-split-children-on-support');
  expect(errors).toEqual([]);
});

test('ordinary collected fragments synthesize a chest and then celebrate its upgrade', async ({ page }, info) => {
  test.skip(!['desktop-chromium', 'iphone-webkit'].includes(info.project.name), 'The complete milestone route covers desktop and phone renderers.');
  test.setTimeout(300000);
  const errors = await startWordJelly(page, { reducedMotion: 'no-preference' });
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.wordJellyMilestones = [];
    window.wordJellyMilestoneFrames = {};
    window.wordJellyFlightFrames = {};
    window.wordJellyFlightCaptures = [];
    const captureFlight = key => {
      if (Object.hasOwn(window.wordJellyFlightFrames, key)) return;
      window.wordJellyFlightFrames[key] = null;
      window.wordJellyFlightCaptures.push(new Promise(resolve => {
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return resolve();
          const reader = new FileReader();
          reader.onload = () => {
            window.wordJellyFlightFrames[key] = reader.result.split(',')[1];
            resolve();
          };
          reader.onerror = resolve;
          reader.readAsDataURL(blob);
        }, 'image/png');
      }));
    };
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}'), presentation = state.reward_presentation;
      if (state.mode !== 'word_jelly' || !presentation?.active) return;
      window.wordJellyMilestones.push({ kind: presentation.kind, tier: presentation.tier,
        visible: presentation.visible, revealed: presentation.revealed, elapsed: presentation.elapsed,
        fragments: state.fragment_count, chests: state.chest_count, motion: presentation.motion,
        anchor: presentation.anchor, flightBounds: presentation.flight_bounds,
        wordRevealVisible: state.word_reveal.visible });
      if (presentation.visible && presentation.motion?.center) {
        const motion = presentation.motion, kind = presentation.kind;
        if (motion.phase === 'center') captureFlight(`${kind}-departure`);
        if (motion.phase === 'rise') captureFlight(`${kind}-screen-center`);
        if (motion.phase === 'celebrate' && !presentation.revealed) captureFlight(`${kind}-upper-arrival`);
        if (presentation.revealed && motion.phase === 'celebrate') captureFlight(`${kind}-enlarged-turn`);
        if (motion.phase === 'return') captureFlight(`${kind}-return`);
      }
      if (presentation.visible && presentation.revealed && !window.wordJellyMilestoneFrames[presentation.kind])
        window.wordJellyMilestoneFrames[presentation.kind] = document.getElementById('canvas').toDataURL('image/png').split(',')[1];
    };
    new MutationObserver(record).observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  });
  for (let attempt = 0; attempt < 40; attempt++) {
    await expect.poll(async () => {
      const state = await jelly(page);
      return state.phase === 'playing' && !state.reward_presentation.active && state.tiles.every(tile => tile.settled);
    }, { message: 'The previous milestone finishes before the next deliberate word' }).toBe(true);
    const state = await jelly(page);
    if (state.fragment_count >= 9) break;
    const found = rootsForWord(state, 3, 2, true) || rootsForWord(state, 3, 2);
    if (!found) {
      expect(state.preview.enabled, 'Real supply remains available while building the chest').toBe(true);
      await pressRect(page, state.preview.rect);
      await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
      continue;
    }
    const completed = await merge(page, found.roots[0].id, found.roots[1].id);
    await pressRect(page, completed.rect);
    await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(state.cleared_pairs + 1);
    const after = await jelly(page);
    if (after.chest_tier > state.chest_tier) {
      const kind = state.chest_tier === 0 ? 'synthesis' : 'upgrade';
      await expect.poll(async () => {
        const reward = (await jelly(page)).reward_presentation;
        return reward.kind === kind && reward.visible && reward.revealed;
      }, { intervals: [50], message: `The ${kind} visibly reaches its flash and confetti reveal` }).toBe(true);
      const peak = await page.evaluate(kind => window.wordJellyMilestoneFrames[kind], kind);
      expect(peak, `The first rendered ${kind} reveal is captured before its flash fades`).toBeTruthy();
      fs.writeFileSync(info.outputPath(`word-jelly-chest-${kind}-reveal.png`), Buffer.from(peak, 'base64'));
      await capture(page, info, `word-jelly-chest-${kind}`);
    }
  }
  const final = await jelly(page);
  expect(final.fragment_count).toBeGreaterThanOrEqual(9);
  expect(final.chest_count).toBe(1);
  expect(final.chest_tier).toBe(2);
  await expect.poll(async () => (await jelly(page)).reward_presentation.active,
    { timeout: 10000, message: 'The upgraded chest visibly finishes its return to the HUD anchor' }).toBe(false);
  await capture(page, info, 'word-jelly-chest-returned-to-anchor');
  const { milestones, keyframes } = await page.evaluate(async () => {
    await Promise.all(window.wordJellyFlightCaptures);
    return { milestones: window.wordJellyMilestones, keyframes: window.wordJellyFlightFrames };
  });
  await info.attach('word-jelly-chest-milestones.json', { body: JSON.stringify(milestones, null, 2), contentType: 'application/json' });
  for (const [name, encoded] of Object.entries(keyframes)) {
    if (encoded) fs.writeFileSync(info.outputPath(`word-jelly-chest-${name}.png`), Buffer.from(encoded, 'base64'));
  }
  for (const [kind, tier] of [['synthesis', 1], ['upgrade', 2]]) {
    const frames = milestones.filter(frame => frame.kind === kind && frame.tier === tier);
    expect(frames.some(frame => frame.visible && !frame.revealed), `${kind} has visible anticipation`).toBe(true);
    expect(frames.some(frame => frame.visible && frame.revealed), `${kind} has a visible reward reveal`).toBe(true);
    expect(new Set(frames.map(frame => frame.elapsed)).size, `${kind} advances through several rendered poses`).toBeGreaterThan(3);
    const visible = frames.filter(frame => frame.visible && frame.motion?.center);
    const first = visible[0], bounds = first.flightBounds, anchor = first.anchor;
    const screenCenter = [bounds[0] + bounds[2] / 2, bounds[1] + bounds[3] / 2];
    const anchorCenter = [anchor[0] + anchor[2] / 2, anchor[1] + anchor[3] / 2];
    const distance = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
    const tolerance = Math.max(3, Math.hypot(bounds[2], bounds[3]) * 0.03);
    // Periodic status updates are at least 100 ms apart, so the first and last
    // endpoints can fall between samples. Check the observed journey here;
    // native route tests cover exact start/end poses and timing boundaries.
    const phases = visible.map(frame => frame.motion.phase).filter((phase, index, all) => index === 0 || phase !== all[index - 1]);
    expect(phases, `${kind} flies to screen center, rises, celebrates, and returns in order`).toEqual(['center', 'rise', 'celebrate', 'return']);
    const departure = visible.filter(frame => frame.motion.phase === 'center');
    expect(departure.length, `${kind} has several observed poses on its outbound journey`).toBeGreaterThan(1);
    const outboundDistance = distance(anchorCenter, screenCenter);
    let previousCenterDistance = Infinity;
    for (const frame of departure) {
      const currentDistance = distance(frame.motion.center, screenCenter);
      expect(distance(frame.motion.center, anchorCenter) + currentDistance,
        `${kind} departs along the route from its HUD chest to screen center`).toBeLessThanOrEqual(outboundDistance + 1);
      expect(currentDistance, `${kind} moves closer to screen center`).toBeLessThanOrEqual(previousCenterDistance + 0.1);
      previousCenterDistance = currentDistance;
    }
    expect(previousCenterDistance, `${kind} makes visible progress toward screen center`)
      .toBeLessThan(distance(departure[0].motion.center, screenCenter) - 1);
    const centered = visible.filter(frame => ['center', 'rise'].includes(frame.motion.phase));
    expect(Math.min(...centered.map(frame => distance(frame.motion.center, screenCenter))),
      `${kind} visibly travels through the actual screen center`).toBeLessThan(tolerance);
    const upper = visible.filter(frame => frame.motion.phase === 'celebrate');
    expect(upper.length, `${kind} has an upper-screen presentation beat`).toBeGreaterThan(2);
    let previousHeight = screenCenter[1];
    for (const frame of visible.filter(frame => frame.motion.phase === 'rise')) {
      expect(Math.abs(frame.motion.center[0] - screenCenter[0]), `${kind} rises from the horizontal screen center`).toBeLessThan(1);
      expect(frame.motion.center[1], `${kind} moves upward before celebrating`).toBeLessThanOrEqual(previousHeight + 0.1);
      previousHeight = frame.motion.center[1];
    }
    for (const frame of upper) {
      expect(Math.abs(frame.motion.center[0] - screenCenter[0]), `${kind} stays horizontally centered upstairs`).toBeLessThan(1);
      expect(frame.motion.center[1], `${kind} celebrates in the upper portion of the screen`).toBeLessThan(bounds[1] + bounds[3] * 0.4);
    }
    expect(centered.every(frame => frame.motion.scale <= 1.05 && Math.abs(frame.motion.yaw) < 0.01),
      `${kind} travels to its upper destination before enlarging and turning`).toBe(true);
    expect(Math.max(...upper.map(frame => frame.motion.scale)), `${kind} clearly enlarges at its destination`).toBeGreaterThan(1.3);
    expect(upper.some(frame => frame.motion.yaw > 0.1 && frame.motion.yaw < 6.1), `${kind} visibly turns while enlarged upstairs`).toBe(true);
    expect(Math.max(...visible.map(frame => frame.motion.yaw)), `${kind} completes its full closed-chest turn by the return journey`).toBeGreaterThan(6.2);
    const returning = visible.filter(frame => frame.motion.phase === 'return');
    expect(returning.length, `${kind} has a visible return journey`).toBeGreaterThan(2);
    let previousDistance = Infinity;
    let previousScale = Infinity;
    for (const frame of returning) {
      const currentDistance = distance(frame.motion.center, anchorCenter);
      expect(currentDistance, `${kind} returns continuously toward its original anchor`).toBeLessThanOrEqual(previousDistance + 0.1);
      expect(frame.motion.scale, `${kind} shrinks continuously on its return journey`).toBeLessThanOrEqual(previousScale);
      previousDistance = currentDistance;
      previousScale = frame.motion.scale;
    }
    expect(previousDistance, `${kind} visibly covers most of the return distance before the HUD icon takes over`)
      .toBeLessThan(Math.max(tolerance, distance(upper.at(-1).motion.center, anchorCenter) * 0.35));
    const peakScale = Math.max(...upper.map(frame => frame.motion.scale));
    expect(previousScale - 1, `${kind} visibly recovers most of its original size before the HUD icon takes over`)
      .toBeLessThan((peakScale - 1) * 0.35);
    const firstReveal = visible.find(frame => frame.revealed);
    expect(firstReveal.wordRevealVisible, 'The chest peak follows the completed word-picture reading beat').toBe(false);
    expect(['departure', 'screen-center', 'upper-arrival', 'enlarged-turn', 'return']
      .every(phase => Boolean(keyframes[`${kind}-${phase}`])), `${kind} records all five real rendered flight keyframes`).toBe(true);
  }
  expect(errors).toEqual([]);
});

test('carried fragments stack and a merged jelly stays draggable as it wraps beyond six parts', async ({ page }, info) => {
  const errors = await startWordJelly(page, { reducedMotion: 'reduce' });
  const opening = await jelly(page), marked = opening.tiles.filter(tile => tile.fragments > 0);
  expect(marked.length, 'The opening supply contains several independently marked roots').toBeGreaterThanOrEqual(2);
  let merged = await merge(page, marked[0].id, marked[1].id);
  expect(merged.fragments).toBe(2);
  expect(merged.fragment_badges, 'Both inherited fragments are presented on the merged jelly').toBe(2);
  await capture(page, info, 'word-jelly-two-carried-fragments');
  while (merged.mass < 7) {
    const state = await jelly(page);
    const next = state.tiles.find(tile => tile.id !== merged.id && tile.visible && tile.settled && tile.mass === 1 && tile.fragments === 0);
    expect(next, 'The starter packet has enough unmarked roots to grow this jelly').toBeTruthy();
    merged = await merge(page, merged.id, next.id);
  }
  expect(merged.mass).toBe(7);
  expect(merged.width).toBe(6);
  expect(merged.height).toBeGreaterThan(1);
  expect(merged.fragments).toBe(2);
  expect(merged.fragment_badges).toBe(2);
  expectInside(merged.rect, await metrics(page));
  expect((await jelly(page)).fragment_count, 'Merging never consumes the visible fragments').toBe(opening.fragment_count);
  await capture(page, info, 'word-jelly-wrapped-seven-part-body');
  expect(errors).toEqual([]);
});

test('three-part words use only the active age and pay more when the larger jelly is collected', async ({ page }, info) => {
  const errors = await startWordJelly(page, { age: 12, reducedMotion: 'reduce' });
  const { roots, word } = await availableWord(page, 12, 3), startingWallet = await wallet(page);
  const partial = await merge(page, roots[0].id, roots[1].id);
  const completed = await merge(page, partial.id, roots[2].id);
  expect(completed.mass).toBe(3);
  expect(completed.word.id).toBe(word.id);
  expect(completed.word.min_age).toBe(12);
  expect(completed.picture_visible).toBe(true);
  expectInside(completed.rect, await metrics(page));
  await capture(page, info, 'word-jelly-current-age-three-part-word');
  const before = await jelly(page);
  await pressRect(page, completed.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + 150);
  expect((await jelly(page)).collected_coins).toBe(before.collected_coins + 150);
  expect(errors).toEqual([]);
});
