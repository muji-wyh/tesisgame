const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, metrics, tap, rendered, enterGame } = require('./game-ui.cjs');
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
  await pressRect(page, control.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.mode === 'word_jelly' && state.visible && state.phase === 'playing' &&
      state.tiles?.length >= 12 && state.tiles.every(tile => tile.settled);
  }, { timeout: 20000, message: 'The real Word Jelly board opens with twelve settled roots' }).toBe(true);
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

async function observeArrival(page, before) {
  await page.evaluate(before => {
    window.wordJellyArrivalObserver?.disconnect();
    const status = document.getElementById('game-status');
    const wanted = new Set(before.upcoming.map(tile => tile.id));
    window.wordJellyArrivalTimeline = [];
    window.wordJellyArrivalFrame = null;
    let capturePending = false;
    const source = before.preview.slots.find(slot => slot.id === before.upcoming[0].id);
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tracked = state.tiles?.filter(tile => wanted.has(tile.id)) || [];
      if (!tracked.length) return;
      window.wordJellyArrivalTimeline.push(tracked.map(tile => ({ ...tile, time: performance.now() })));
      const first = tracked.find(tile => tile.id === source.id);
      const boardPitch = state.board_rect[3] / state.rows;
      const targetY = state.board_rect[1] + (first?.row + 0.5) * boardPitch;
      const sourceY = source.rect[1] + source.rect[3] / 2;
      const progress = first && (first.rect[1] + first.rect[3] / 2 - sourceY) / (targetY - sourceY);
      if (!capturePending && first && !first.settled && progress > 0.20 && progress < 0.72) {
        capturePending = true;
        // Keep the simulation running while the real intermediate frame is encoded.
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = () => { window.wordJellyArrivalFrame = reader.result.split(',')[1]; };
          reader.readAsDataURL(blob);
        }, 'image/png');
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
  for (const root of before.upcoming) {
    const source = before.preview.slots.find(slot => slot.id === root.id);
    const target = after.tiles.find(tile => tile.id === root.id);
    const frames = timeline.flatMap(frame => frame.filter(tile => tile.id === root.id));
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
  expect(after.generated_tiles).toBe(before.generated_tiles + 6);
  expect(after.merged_count).toBe(before.merged_count);
  expect(after.cleared_pairs).toBe(before.cleared_pairs);
  expect(after.collected_coins).toBe(before.collected_coins);
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyArrivalFrame)),
    { message: 'The actual browser captures the jellies between the tray and their support' }).toBe(true);
  const encoded = await page.evaluate(() => window.wordJellyArrivalFrame);
  fs.writeFileSync(info.outputPath(`word-jelly-${label}-falling-midpoint.png`), Buffer.from(encoded, 'base64'));
  await capture(page, info, `word-jelly-${label}-landed`);
  await page.evaluate(() => window.wordJellyArrivalObserver.disconnect());
}

test('manual and automatic preview packets naturally fall into the well', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors = await startWordJelly(page), manual = await jelly(page);
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
  await observeArrival(page, automatic);
  await verifyArrival(page, info, automatic, 'automatic-supply');
  expect(errors).toEqual([]);
});

test('collecting a lower word makes the stack above it visibly fall onto support', async ({ page }, info) => {
  const errors = await startWordJelly(page), opening = await jelly(page), startingWallet = await wallet(page);
  const words = new Map(vocabulary.filter(word => word.min_age === 3).map(word => [normalize(word.text), word]));
  const floor = opening.tiles.filter(tile => tile.row === opening.rows - 1 && tile.mass === 1)
    .sort((a, b) => a.column - b.column);
  let roots;
  for (const count of [2, 3]) {
    for (let start = 0; start <= floor.length - count; start++) {
      const packet = floor.slice(start, start + count);
      if (packet.every((tile, index) => tile.column === packet[0].column + index) &&
        words.has(normalize(packet.map(tile => tile.text).join('')))) {
        roots = packet;
        break;
      }
    }
    if (roots) break;
  }
  expect(roots, 'The first ordinary supply packet contains a complete adjacent floor word').toBeTruthy();
  let completed = await merge(page, roots[0].id, roots[1].id);
  for (const root of roots.slice(2)) completed = await merge(page, completed.id, root.id);
  expect(completed.word.id).toBe(words.get(normalize(roots.map(tile => tile.text).join(''))).id);
  expect(completed.row, 'The completed floor word remains underneath the initial upper row').toBe(opening.rows - 1);
  const before = await jelly(page);
  const stack = before.tiles.filter(tile => tile.row + tile.height === completed.row &&
    tile.column >= completed.column && tile.column + tile.width <= completed.column + completed.width);
  expect(stack.length, 'The real floor word supports multiple upper jellies').toBeGreaterThanOrEqual(2);
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
  expect(opening.tiles).toHaveLength(12);
  expect(opening.columns).toBe(6);
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
  await page.keyboard.press('Escape');
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
  test.skip(info.project.name !== 'desktop-chromium', 'The complete milestone path supplements the phone and desktop core interactions.');
  test.setTimeout(180000);
  const errors = await startWordJelly(page, { reducedMotion: 'no-preference' });
  await page.evaluate(() => {
    const status = document.getElementById('game-status');
    window.wordJellyMilestones = [];
    window.wordJellyMilestoneFrames = {};
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}'), presentation = state.reward_presentation;
      if (state.mode !== 'word_jelly' || !presentation?.active) return;
      window.wordJellyMilestones.push({ kind: presentation.kind, tier: presentation.tier,
        visible: presentation.visible, revealed: presentation.revealed, elapsed: presentation.elapsed,
        fragments: state.fragment_count, chests: state.chest_count });
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
  const milestones = await page.evaluate(() => window.wordJellyMilestones);
  for (const [kind, tier] of [['synthesis', 1], ['upgrade', 2]]) {
    const frames = milestones.filter(frame => frame.kind === kind && frame.tier === tier);
    expect(frames.some(frame => frame.visible && !frame.revealed), `${kind} has visible anticipation`).toBe(true);
    expect(frames.some(frame => frame.visible && frame.revealed), `${kind} has a visible reward reveal`).toBe(true);
    expect(new Set(frames.map(frame => frame.elapsed)).size, `${kind} advances through several rendered poses`).toBeGreaterThan(3);
  }
  await info.attach('word-jelly-chest-milestones.json', { body: JSON.stringify(milestones, null, 2), contentType: 'application/json' });
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
