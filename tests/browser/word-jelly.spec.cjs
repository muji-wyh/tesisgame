const fs = require('node:fs');
const { test, expect } = require('@playwright/test');
const { openGame, openModeMenu, chooseMode, metrics, tap, rendered, enterGame, observeAudio, seedGrowth } = require('./game-ui.cjs');
const { recordingTiming, expectRecording } = require('./bundled-audio.cjs');
const { collectionCoins, expectCollectionReward } = require('./word-jelly-rewards.cjs');
const vocabulary = require('../../words.json');
const morphology = Array.from({ length: 10 }, (_, index) =>
  require(`../../data/vocabulary/morphology/age-${String(index + 3).padStart(2, '0')}.json`).entries).flat();
const analyses = new Map(morphology.map(entry => [entry.analysis.id, entry.analysis]));
const reviewed = new Map(morphology.map(entry => [entry.id, entry]));
const COMPOSITION_AGE = 8;

const jelly = page => page.locator('#game-status').evaluate(node => JSON.parse(node.dataset.jelly || '{}'));
const previewReady = state => state.upcoming.every((body, index) => !body.id || state.preview.slots[index].visible);
const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const growth = page => page.locator('#growth-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const normalize = text => text.trim().toLowerCase().replace(/\s+/g, ' ');
const semanticSurface = text => text.replace(/^-+|-+$/g, '');
const hasAuthoredSpellingChange = analysis => analysis.nodes.some(node => {
  const left = analysis.parts.find(part => part.id === node.left) || analysis.nodes.find(part => part.id === node.left);
  const right = analysis.parts.find(part => part.id === node.right) || analysis.nodes.find(part => part.id === node.right);
  return semanticSurface(left.surface) + semanticSurface(right.surface) !== semanticSurface(node.surface);
});
const jellyWordsForAge = age => vocabulary.filter(word => word.min_age === age &&
  ['id', 'text', 'audio'].every(key => typeof word[key] === 'string' && word[key].trim()) &&
  reviewed.get(word.id)?.review.status === 'reviewed');
const expectRestingPalette = (tile, resting, message) => {
  expect(tile.palette_index, message).toBe(resting.palette_index);
  expect(tile.palette_hue, message).toBeCloseTo(resting.palette_hue, 5);
};

async function pressRect(page, rect) {
  expect(rect).toHaveLength(4);
  const [x, y, width, height] = rect;
  expect(width).toBeGreaterThan(0);
  expect(height).toBeGreaterThan(0);
  await tap(page, x + width / 2, y + height / 2);
  await rendered(page);
}

async function startWordJelly(page, { age = COMPOSITION_AGE, reducedMotion = 'no-preference', preseededGrowth = false } = {}) {
  const earnedAge = age === 3 ? 0 : age - 1;
  if (!preseededGrowth) await page.addInitScript(earnedAge => {
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
      state.authored_morphology && state.tiles?.length > 0 && state.tiles.every(tile => tile.settled);
  }, { timeout: 20000, message: 'The real Word Jelly board opens with reviewed, settled content' }).toBe(true);
  const opening = await jelly(page);
  const occupiedArea = opening.tiles.reduce((sum, tile) => sum + tile.width * tile.height, 0);
  expect(occupiedArea, 'The opening contains eighteen ordinary square cells').toBe(18);
  const next = opening.upcoming.find(tile => tile.id);
  expect(occupiedArea + next.width * next.height,
    'The next fixed-size body would exceed the opening budget').toBeGreaterThan(18);
  for (const tile of opening.tiles) {
    expect([tile.width, tile.height], 'Every source part uses one normal square cell').toEqual([1, 1]);
    expect(tile.rect[2], 'The displayed starter keeps the ordinary square proportions').toBeCloseTo(tile.rect[3], 3);
    if (tile.jelly_kind === 'picture') {
      expect(tile.image_word.id, 'Every picture retains its exact vocabulary identity').toBe(tile.source_word_id);
      expect(tile.display_text, 'A picture source does not reveal its spelling').toBe('');
    } else expect(tile.composition?.signature, 'Every root has reviewed composition identity').toBeTruthy();
    expectSupportedChild(opening, tile);
  }
  expect(opening.tiles.every(tile => tile.focused === false),
    'Pointer entry does not give any starter jelly an unsolicited keyboard focus ring').toBe(true);
  expect(opening.drag.source, 'Pointer entry starts without a held jelly').toBe(-1);
  expect(opening.drag.selected, 'Pointer entry starts without a keyboard-selected jelly').toBe(-1);
  expect(opening.tiles.every(tile => tile.completion_hint === false),
    'Pointer entry does not advertise a selected completion target').toBe(true);
  return errors;
}

function center(rect, bounds) {
  return { x: bounds.x + (rect[0] + rect[2] / 2) * bounds.scale,
    y: bounds.y + (rect[1] + rect[3] / 2) * bounds.scale };
}

function authoredJoin(left, right) {
  if (!left || !right || left.id === right.id) return null;
  if (left.jelly_kind === 'merged' && right.jelly_kind === 'merged') {
    if (left.word.id !== right.word.id || left.merge_level !== right.merge_level || left.merge_level >= 9) return null;
    return { kind: 'upgrade', node: { surface: left.word.text }, complete: true, collectable: true,
      mergeLevel: left.merge_level + 1, masteryEligible: left.mastery_eligible || right.mastery_eligible };
  }
  const picture = left.jelly_kind === 'picture' ? left : right.jelly_kind === 'picture' ? right : null;
  if (picture) {
    const root = picture === left ? right : left;
    if (root.jelly_kind !== 'root' || !root.word_candidate?.id || root.word_candidate.id !== picture.image_word?.id) return null;
    return { kind: 'picture', node: { surface: root.word_candidate.text }, complete: true,
      collectable: true, mergeLevel: 1, masteryEligible: true };
  }
  if (left.jelly_kind !== 'root' || right.jelly_kind !== 'root' || !left.composition || !right.composition) return null;
  const matches = [];
  for (const candidate of left.composition.candidates) {
    const analysis = analyses.get(candidate.analysis_id);
    if (!analysis) continue;
    for (const node of analysis.nodes) if (node.left === candidate.node_id &&
      right.composition.candidates.some(other => other.analysis_id === analysis.id && other.node_id === node.right))
      matches.push({ kind: 'roots', analysis, node, complete: analysis.roots.includes(node.id),
        collectable: analysis.roots.includes(node.id) && !vocabulary.find(word => word.id === analysis.lexeme_id)?.image });
  }
  if (!matches.length) return null;
  expect(new Set(matches.map(match => match.node.surface)), 'The reviewed ordered join has one exact output').toHaveProperty('size', 1);
  return matches.find(match => match.complete) || matches[0];
}

function suppliedWords(state, age) {
  const words = new Map(jellyWordsForAge(age).map(word => [word.id, word]));
  const groups = new Map();
  for (const tile of state.tiles.filter(tile => tile.visible && tile.settled && tile.mass === 1 && tile.supply_group)) {
    if (!groups.has(tile.supply_group)) groups.set(tile.supply_group, []);
    groups.get(tile.supply_group).push(tile);
  }
  return [...groups.values()].map(bodies => {
    const picture = bodies.find(tile => tile.jelly_kind === 'picture');
    const roots = bodies.filter(tile => tile.jelly_kind !== 'picture');
    roots.sort((a, b) => a.supply_part - b.supply_part);
    const word = words.get(bodies[0].source_word_id), analysis = reviewed.get(word?.id)?.analysis;
    return { roots, picture, word, analysis };
  }).filter(candidate => candidate.analysis && candidate.roots.length === candidate.analysis.parts.length &&
    candidate.roots.every((root, index) => root.text === semanticSurface(candidate.analysis.parts[index].surface)) &&
    (!candidate.word.image || candidate.picture?.image_word.id === candidate.word.id));
}

function rootsForWord(state, age, count, markedOnly = false, invalidReverse = false) {
  return suppliedWords(state, age).find(candidate => candidate.roots.length === count &&
    (!markedOnly || [...candidate.roots, candidate.picture].some(tile => tile?.fragments > 0)) &&
    (!invalidReverse || candidate.roots.length > 1 && !authoredJoin(candidate.roots[1], candidate.roots[0]))) || null;
}

async function availableWord(page, age, count, { markedOnly = false, invalidReverse = false } = {}) {
  for (let attempt = 0; attempt < jellyWordsForAge(age).length; attempt++) {
    await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    const state = await jelly(page), found = rootsForWord(state, age, count, markedOnly, invalidReverse);
    const atomic = state.tiles.find(tile => tile.settled && tile.jelly_kind === 'merged' &&
      !tile.word?.image && tile.composition && !tile.composition.composed);
    if (atomic) {
      await pressRect(page, atomic.rect);
      await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(state.cleared_pairs + 1);
      await expect.poll(async () => (await jelly(page)).reward_presentation.active).toBe(false);
      continue;
    }
    if (found) return found;
    const other = suppliedWords(state, age).find(candidate => candidate.roots.length !== count ||
      (markedOnly && [...candidate.roots, candidate.picture].every(tile => !tile?.fragments)));
    if (other) {
      const completed = await completeSuppliedWord(page, other);
      await pressRect(page, completed.rect);
      await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(state.cleared_pairs + 1);
      await expect.poll(async () => (await jelly(page)).reward_presentation.active).toBe(false);
      continue;
    }
    expect(state.preview.enabled, 'The ordinary preview can supply another complete word packet').toBe(true);
    await pressRect(page, state.preview.rect);
    await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
  }
  throw new Error(`The current age ${age} supply did not provide a ${count}-part word.`);
}

async function merge(page, sourceId, targetId) {
  const before = await jelly(page), bounds = await metrics(page);
  const source = before.tiles.find(tile => tile.id === sourceId), target = before.tiles.find(tile => tile.id === targetId);
  const authored = authoredJoin(source, target);
  expect(authored, 'The drag follows a reviewed root join, matching picture, or equal-level upgrade').toBeTruthy();
  expect(source?.settled, 'The held jelly is ready').toBe(true);
  expect(target?.settled, 'The destination jelly is ready').toBe(true);
  const from = center(source.rect, bounds), to = center(target.rect, bounds);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    // Begin the actual drag before polling: a stationary clipped label opens Read.
    // A single first move crosses the hold threshold even when traced steps are slow.
    await page.mouse.move(from.x, from.y - 16);
    await page.mouse.move(to.x, to.y, { steps: 12 });
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(sourceId);
    await expect.poll(async () => {
      const state = await jelly(page), liveTarget = state.tiles.find(tile => tile.id === targetId);
      if (!liveTarget?.settled) return false;
      if (state.drag.target === targetId) return true;
      const livePoint = center(liveTarget.rect, bounds);
      await page.mouse.move(livePoint.x, livePoint.y, { steps: 4 });
      return false;
    }, { message: 'The held source follows the real target after any support-removal fall' }).toBe(true);
  } finally {
    await page.mouse.up();
  }
  let result;
  await expect.poll(async () => {
    const state = await jelly(page);
    result = state.tiles.find(tile => !before.tiles.some(old => old.id === tile.id) &&
      tile.text === semanticSurface(authored.node.surface) && tile.mass === source.mass + target.mass);
    return state.merged_count === before.merged_count + 1 && Boolean(result?.settled) &&
      before.tiles.filter(tile => tile.id !== sourceId && tile.id !== targetId).every(original =>
        state.tiles.some(tile => tile.id === original.id && tile.settled));
  }, { message: 'The union settles into a composed square jelly in source-then-target order' }).toBe(true);
  const after = await jelly(page);
  expect(after.tiles.some(tile => tile.id === sourceId || tile.id === targetId)).toBe(false);
  expect(after.cleared_pairs, 'Merging does not automatically collect a word').toBe(before.cleared_pairs);
  expect(after.fragment_count, 'Carried fragments are collected only after a valid word is tapped').toBe(before.fragment_count);
  expect(result.fragments).toBe(source.fragments + target.fragments);
  if (authored.kind === 'roots') {
    expect(result.composition.complete).toBe(authored.complete);
    expect(result.mastery_eligible).toBe(authored.complete && !result.word_candidate?.image);
  } else {
    expect(result.jelly_kind).toBe('merged');
    expect(result.merge_level).toBe(authored.mergeLevel);
    expectCollectionReward(result);
    expect(result.mastery_eligible).toBe(authored.masteryEligible);
  }
  expect([result.width, result.height], 'Composition preserves the ordinary one-cell body').toEqual([1, 1]);
  expect(result.rect[2], 'Partial and completed compositions remain square').toBeCloseTo(result.rect[3], 3);
  expect(result.placement_locked, 'Automatic merging releases any previous manual placement').toBe(false);
  expectSupportedChild(after, result);
  for (const original of before.tiles.filter(tile => tile.id !== sourceId && tile.id !== targetId && tile.settled)) {
    const unchanged = after.tiles.find(tile => tile.id === original.id);
    expect(unchanged, 'Merging preserves every unrelated jelly').toBeTruthy();
    expect([unchanged.width, unchanged.height], 'Merging preserves every unrelated ordinary square')
      .toEqual([1, 1]);
    expect(unchanged.column, 'Automatic gravity preserves an unrelated jelly column').toBe(original.column);
    expect(unchanged.row, 'An unsupported neighbor can descend after merging removes its support').toBeGreaterThanOrEqual(original.row);
    expectSupportedChild(after, unchanged);
    for (const axis of [0, 2, 3])
      expect(unchanged.rect[axis], 'Automatic settlement preserves unrelated horizontal positions and sizes')
        .toBeCloseTo(original.rect[axis], 3);
  }
  return result;
}

async function completeSuppliedWord(page, candidate) {
  const { roots, picture, analysis, word } = candidate;
  const ready = new Map(analysis.parts.map((part, index) => [part.id, roots[index]]));
  const visit = async id => {
    if (ready.has(id)) return ready.get(id);
    const node = analysis.nodes.find(item => item.id === id);
    expect(node, 'The completion follows an explicit authored node').toBeTruthy();
    const left = await visit(node.left), right = await visit(node.right);
    const result = await merge(page, left.id, right.id);
    expect(result.text).toBe(semanticSurface(node.surface));
    if (!analysis.roots.includes(id)) {
      expect(result.word, 'An authored intermediate is not prematurely collectable').toEqual({});
      expect(result.picture_visible).toBe(false);
    }
    ready.set(id, result);
    return result;
  };
  let result = await visit(analysis.roots[0]);
  if (picture && result.jelly_kind !== 'merged') result = await merge(page, picture.id, result.id);
  expect(result.word.id).toBe(word.id);
  expect(result.jelly_kind).toBe('merged');
  expect(result.merge_level).toBe(1);
  expect(result.mastery_eligible, 'A manual picture match or multi-root composition earns mastery on collection')
    .toBe(Boolean(picture) || analysis.parts.length > 1);
  return result;
}

async function rejectMerge(page, sourceId, targetId, { info, label, reducedMotion = 'no-preference', inspectContact } = {}) {
  const before = await jelly(page), bounds = await metrics(page);
  const source = before.tiles.find(tile => tile.id === sourceId), target = before.tiles.find(tile => tile.id === targetId);
  const contents = tile => ({ id: tile.id, text: tile.text, mass: tile.mass, word: tile.word,
    fragments: tile.fragments, badges: tile.fragment_badges, picture: tile.picture_visible, coins: tile.coins });
  expect(source?.settled).toBe(true);
  expect(target?.settled).toBe(true);
  const from = center(source.rect, bounds), to = center(target.rect, bounds);
  to.y -= target.rect[3] * bounds.scale * 0.34;
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  let held;
  try {
    await page.mouse.move(from.x, from.y - 16);
    await page.mouse.move(to.x, to.y, { steps: 8 });
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(sourceId);
    await expect.poll(async () => {
      const state = await jelly(page), liveTarget = state.tiles.find(tile => tile.id === targetId);
      if (!liveTarget?.settled) return false;
      if (state.drag.target === targetId) return true;
      const livePoint = center(liveTarget.rect, bounds);
      livePoint.y -= liveTarget.rect[3] * bounds.scale * 0.34;
      await page.mouse.move(livePoint.x, livePoint.y, { steps: 4 });
      return false;
    }).toBe(true);
    await expect.poll(async () => (await jelly(page)).contact).toMatchObject({ kind: 'touch', source: sourceId, target: targetId });
    held = await jelly(page);
    expect(held.contact.strength, 'An incompatible pair still responds to physical contact').toBeGreaterThan(0);
    expect(held.tiles.find(tile => tile.id === targetId).completion_hint).toBe(false);
    if (inspectContact) await inspectContact(held);
    await page.evaluate(({ sourceId, targetId }) => {
      const status = document.getElementById('game-status');
      const evidence = window.wordJellyRejection = { releaseAt: null, timeline: [], frame: null };
      let capturing = false;
      window.wordJellyRejectionInput = () => { evidence.releaseAt = performance.now(); };
      document.addEventListener('pointerup', window.wordJellyRejectionInput, { capture: true, once: true });
      window.wordJellyRejectionObserver = new MutationObserver(() => {
        if (evidence.releaseAt === null) return;
        const state = JSON.parse(status.dataset.jelly || '{}');
        const tracked = state.tiles?.filter(tile => tile.id === sourceId || tile.id === targetId) || [];
        evidence.timeline.push({ at: performance.now(), contact: state.contact, tiles: tracked,
          merged: state.merged_count, fusions: state.fusions, cleared: state.cleared_pairs,
          coins: state.collected_coins, fragments: state.fragment_count });
        if (!capturing && state.contact?.kind === 'mismatch' && state.contact.strength > 0.15) {
          capturing = true;
          document.getElementById('canvas').toBlob(blob => {
            if (!blob) return;
            const reader = new FileReader();
            reader.onload = () => { evidence.frame = reader.result.split(',')[1]; };
            reader.readAsDataURL(blob);
          }, 'image/png');
        }
      });
      window.wordJellyRejectionObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    }, { sourceId, targetId });
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.drag.active && state.contact.kind === 'none' && before.tiles.every(original => {
      const tile = state.tiles.find(item => item.id === original.id);
      if (!tile?.settled || tile.lifted) return false;
      const pitch = state.board_rect[2] / state.columns;
      return Math.abs(tile.rect[0] + tile.rect[2] / 2 - state.board_rect[0] - (tile.column + tile.width / 2) * pitch) < 0.1 &&
        Math.abs(tile.rect[1] + tile.rect[3] / 2 - state.board_rect[1] - (tile.row + tile.height / 2) * pitch) < 0.1;
    });
  }, { message: 'The rejected pair separates and every original body visibly rests on its current supported footprint' }).toBe(true);
  const after = await jelly(page);
  const evidence = await page.evaluate(() => {
    window.wordJellyRejectionObserver.disconnect();
    document.removeEventListener('pointerup', window.wordJellyRejectionInput, { capture: true });
    return window.wordJellyRejection;
  });
  if (info) fs.writeFileSync(info.outputPath(`${label}-timeline.json`), JSON.stringify({ before, held, after,
    ...evidence, frame: Boolean(evidence.frame) }, null, 2));
  expect(evidence.releaseAt).not.toBeNull();
  expect(evidence.timeline.some(frame => frame.contact.kind === 'mismatch'),
    'The release produces a visible rejection cue').toBe(true);
  for (const frame of evidence.timeline) {
    expect(frame.tiles).toHaveLength(2);
    for (const original of [source, target]) expect(contents(frame.tiles.find(tile => tile.id === original.id))).toEqual(contents(original));
    expect(frame.merged).toBe(before.merged_count);
    expect(frame.cleared).toBe(before.cleared_pairs);
    expect(frame.coins).toBe(before.collected_coins);
    expect(frame.fragments).toBe(before.fragment_count);
    expect(frame.fusions, 'A rejected release never creates a merge or collection operation').toEqual([]);
  }
  for (const original of before.tiles) {
    const retained = after.tiles.find(tile => tile.id === original.id);
    expect(retained, 'Rejection never consumes an original body').toBeTruthy();
    expect(contents(retained), 'Rejection preserves every original body and its contents').toEqual(contents(original));
    expectSupportedChild(after, retained);
  }
  const returnedSource = after.tiles.find(tile => tile.id === sourceId), returnedTarget = after.tiles.find(tile => tile.id === targetId);
  if (returnedSource.column !== source.column || returnedSource.row !== source.row) {
    expect(after.tiles.some(other => other.id !== sourceId &&
      source.column < other.column + other.width && source.column + source.width > other.column &&
      source.row < other.row + other.height && source.row + source.height > other.row),
    'A rejected source changes its return position only when its former space was occupied after lifting').toBe(true);
  }
  const heldSource = held.tiles.find(tile => tile.id === sourceId), heldTarget = held.tiles.find(tile => tile.id === targetId);
  const separation = (a, b) => Math.hypot(a[0] + a[2] / 2 - b[0] - b[2] / 2,
    a[1] + a[3] / 2 - b[1] - b[3] / 2);
  const poses = evidence.timeline.map(frame => frame.tiles.find(tile => tile.id === sourceId).rect);
  expect(separation(returnedSource.rect, returnedTarget.rect), 'The source finishes visibly separated from the rejected target')
    .toBeGreaterThan(separation(heldSource.rect, heldTarget.rect));
  if (reducedMotion !== 'reduce') expect(poses.some(rect =>
    Math.hypot(rect[0] - heldSource.rect[0], rect[1] - heldSource.rect[1]) > 0.5 &&
    Math.hypot(rect[0] - returnedSource.rect[0], rect[1] - returnedSource.rect[1]) > 0.5),
  'The rejected body has a visible separating pose before it returns').toBe(true);
  if (info) {
    await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyRejection.frame)),
      { message: 'The rejection cue retains a real rendered frame' }).toBe(true);
    const frame = await page.evaluate(() => window.wordJellyRejection.frame);
    fs.writeFileSync(info.outputPath(`${label}-separating.png`), Buffer.from(frame, 'base64'));
    await capture(page, info, `${label}-restored`);
  }
  return { before, held, after, ...evidence };
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

function expectWordRevealContent(entry, bounds, area) {
  for (const rect of [entry.rect, entry.resting_rect, entry.picture_rect, entry.spelling_rect]) expectInside(rect, bounds);
  expect(entry.rect[1] + entry.rect[3], 'Each independent word remains in the upper part of the playfield')
    .toBeLessThan(area[1] + area[3] * 0.42);
  const [x, y, width, height] = entry.rect;
  for (const rect of [entry.picture_rect, entry.spelling_rect]) {
    expect(rect[0], 'Word content remains inside its own card').toBeGreaterThanOrEqual(x - 1);
    expect(rect[1], 'Word content remains inside its own card').toBeGreaterThanOrEqual(y - 1);
    expect(rect[0] + rect[2], 'Word content remains inside its own card').toBeLessThanOrEqual(x + width + 1);
    expect(rect[1] + rect[3], 'Word content remains inside its own card').toBeLessThanOrEqual(y + height + 1);
  }
  expect(entry.picture_rect[0] + entry.picture_rect[2], 'Picture and spelling have distinct reading space')
    .toBeLessThan(entry.spelling_rect[0]);
  const contentWidth = entry.spelling_rect[0] + entry.spelling_rect[2] - entry.picture_rect[0];
  const contentHeight = Math.max(entry.picture_rect[1] + entry.picture_rect[3], entry.spelling_rect[1] + entry.spelling_rect[3]) -
    Math.min(entry.picture_rect[1], entry.spelling_rect[1]);
  expect(width, 'The card fits its picture and spelling without a wide empty fixed-size shell').toBeLessThan(contentWidth * 1.6);
  expect(height, 'The card height follows its content with modest padding').toBeLessThan(contentHeight * 1.7);
}

function expectSupplyLayout(state, bounds) {
  const board = state.board_rect, tray = state.preview.rect, area = state.playfield_rect;
  const collect = state.collect_button.rect, paidTools = Object.values(state.powerup_buttons).map(button => button.rect);
  const autoMerge = state.powerup_buttons.auto_merge.rect, divider = state.action_divider.rect;
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
    const body = state.upcoming[index];
    if (!body.id) {
      expect(slot.visible, 'Reserved or empty lanes do not display a duplicate body').toBe(false);
      if (body.reservation) expect(state.upcoming[body.anchor].id).toBe(body.reservation);
      continue;
    }
    expect(slot.visible, `Advertised preview ${index} stays visible`).toBe(true);
    expect([body.width, body.height], `Preview ${index} uses one normal square cell`).toEqual([1, 1]);
    expect(slot.rect[2], `Preview ${index} keeps square proportions`).toBeCloseTo(slot.rect[3], 3);
    inside(slot.rect, tray, `Preview ${index}`);
    expect(Math.abs(slot.rect[0] + slot.rect[2] / 2 - (board[0] + (index + body.width / 2) * board[2] / 6)),
      `Preview ${index} is centered over its reserved well columns`).toBeLessThan(tolerance);
  }
  const regions = [['well', board], ['supply tray', tray], ['Collect words', collect], ['Action divider', divider],
    ...Object.entries(state.powerup_buttons).map(([kind, button]) => [kind, button.rect])];
  inside(area, [0, 0, bounds.width, bounds.height], 'Jelly Words playfield');
  for (const [index, [label, rect]] of regions.entries()) {
    inside(rect, area, label);
    for (const [otherLabel, other] of regions.slice(index + 1)) {
      const width = Math.min(rect[0] + rect[2], other[0] + other[2]) - Math.max(rect[0], other[0]);
      const height = Math.min(rect[1] + rect[3], other[1] + other[3]) - Math.max(rect[1], other[1]);
      expect(width <= tolerance || height <= tolerance, `${label} and ${otherLabel} do not overlap`).toBe(true);
    }
  }
  expect(Math.abs(collect[0] - autoMerge[0]), 'Collect aligns directly above Auto merge').toBeLessThan(tolerance);
  expect(Math.abs(autoMerge[1] - collect[1] - collect[3] - 20 / scale),
    'A twenty-pixel separator gap keeps Collect adjacent to the paid tools').toBeLessThan(tolerance);
  expect(state.action_divider.visible, 'The free Collect action has a visible divider from paid tools').toBe(true);
  expect(divider[1], 'The divider stays below Collect').toBeGreaterThanOrEqual(collect[1] + collect[3] - tolerance);
  for (const rect of paidTools) {
    expect(divider[1] + divider[3], 'The divider stays above every paid tool').toBeLessThanOrEqual(rect[1] + tolerance);
    expect(divider[0], 'The divider spans each paid tool center').toBeLessThanOrEqual(rect[0] + rect[2] / 2 + tolerance);
    expect(divider[0] + divider[2], 'The divider spans each paid tool center').toBeGreaterThanOrEqual(rect[0] + rect[2] / 2 - tolerance);
  }
  if (collect[0] >= board[0] + board[2] - tolerance) {
    for (const rect of paidTools) {
      expect(Math.abs(rect[0] - collect[0]), 'Paid tools share the Collect rail').toBeLessThan(tolerance);
    }
  } else {
    expect(collect[1], 'Collect remains with the tools below the well on narrow layouts')
      .toBeGreaterThanOrEqual(board[1] + board[3] - tolerance);
    for (const rect of paidTools) {
      expect(rect[1], 'Paid tools remain below the well on narrow layouts')
        .toBeGreaterThanOrEqual(board[1] + board[3] - tolerance);
      expect(Math.abs(rect[1] - paidTools[0][1]), 'Both paid tools share the bottom row').toBeLessThan(tolerance);
    }
  }
  const chest = state.loot.progress.rect;
  inside(chest, [0, 0, bounds.width, bounds.height], 'Header chest');
  inside(state.loot.rect, chest, 'Chest artwork');
  expect(chest[1] + chest[3] + 4 / scale,
    'The chest uses the header without reserving playfield space').toBeLessThanOrEqual(area[1] + tolerance);
  expect(chest[2] * scale, 'The header chest keeps its full touch width').toBeGreaterThanOrEqual(43.75);
  expect(chest[3] * scale, 'The header chest keeps its full touch height').toBeGreaterThanOrEqual(43.75);
  for (const [label, rect] of [...regions, ['Finish', state.finish.rect]]) {
    const width = Math.min(chest[0] + chest[2], rect[0] + rect[2]) - Math.max(chest[0], rect[0]);
    const height = Math.min(chest[1] + chest[3], rect[1] + rect[3]) - Math.max(chest[1], rect[1]);
    expect(width <= tolerance || height <= tolerance, `Header chest and ${label} do not overlap`).toBe(true);
  }
  inside(state.finish.rect, [0, 0, bounds.width, bounds.height], 'Header Finish');
  expect(state.finish.visible, 'Finish is visible in the active round header').toBe(true);
  expect(state.finish.rect[1] + state.finish.rect[3] + 4 / scale,
    'Finish stays above the playfield with a separate header gap').toBeLessThanOrEqual(area[1] + tolerance);
  expect(collect[1] - state.finish.rect[1] - state.finish.rect[3],
    'Collect words keeps a separate sixteen-pixel gap below Finish').toBeGreaterThanOrEqual(16 / scale - tolerance);
  expect(tray[3] * scale, 'The supply tray retains a forty-four-pixel target height within viewport rounding').toBeGreaterThanOrEqual(43.75);
  expect(state.finish.rect[3] * scale, 'Finish retains a forty-four-pixel target height within viewport rounding').toBeGreaterThanOrEqual(43.75);
  for (const [label, rect] of [['Collect words', collect],
    ...Object.entries(state.powerup_buttons).map(([kind, button]) => [kind, button.rect])]) {
    expect(rect[2] * scale, `${label} retains a forty-four-pixel target width within viewport rounding`).toBeGreaterThanOrEqual(43.75);
    expect(rect[3] * scale, `${label} retains a forty-four-pixel target height within viewport rounding`).toBeGreaterThanOrEqual(43.75);
  }
  const bottom = Math.max(...regions.map(([, rect]) => rect[1] + rect[3]));
  expect(Math.abs(bottom - (area[1] + area[3] - 12 / scale)), 'The authored board retains twelve-pixel bottom padding').toBeLessThan(tolerance);
}

function expectSupportedChild(state, child) {
  const resting = state.tiles.filter(tile => !tile.lifted);
  const bottom = child.row + child.height;
  const supported = bottom === state.rows || resting.some(other => other.id !== child.id &&
    other.row === bottom && other.column < child.column + child.width && other.column + other.width > child.column);
  expect(supported, `Jelly ${child.text} touches the floor or an occupied footprint immediately below`).toBe(true);
  for (const other of resting.filter(tile => tile.id !== child.id)) {
    const overlaps = child.column < other.column + other.width && child.column + child.width > other.column &&
      child.row < other.row + other.height && child.row + child.height > other.row;
    expect(overlaps, `Jelly ${child.text} cannot overlap jelly ${other.id}`).toBe(false);
  }
}

function expectMixedRootPacket(roots, label) {
  roots = roots.filter(root => root.id);
  expect(roots.length, `${label} contains genuine supplied bodies`).toBeGreaterThan(0);
  for (const [index, root] of roots.entries()) {
    expect(Number.isInteger(root.supply_group), `${label}: root provenance remains available`).toBe(true);
    expect(root.source_word_id, `${label}: every root retains its vocabulary identity`).toBeTruthy();
    const analysis = reviewed.get(root.source_word_id).analysis;
    const word = vocabulary.find(item => item.id === root.source_word_id);
    if (root.jelly_kind === 'picture') {
      expect(root.supply_part).toBe(analysis.parts.length);
      expect(root.image_word.id).toBe(word.id);
      expect(root.display_text, `${label}: the picture source contains no caption`).toBe('');
    } else expect(root.text, `${label}: the source is an authored part, never a midpoint split`)
      .toBe(semanticSurface(analysis.parts[root.supply_part].surface));
    expect(root.supply_parts).toBe(analysis.parts.length + (word.image ? 1 : 0));
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
    const firstBody = before.upcoming.find(body => body.id);
    const source = before.preview.slots.find(slot => slot.id === firstBody.id);
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
      const targetY = state.board_rect[1] + (first?.row + first?.height / 2) * boardPitch;
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
    return before.upcoming.filter(root => root.id).every(root => state.tiles.some(tile => tile.id === root.id && tile.settled));
  }, { timeout: Math.ceil(before.spawn_interval * 1000) + 12000,
    message: `${label} supply visibly descends and finishes its planted recovery` }).toBe(true);
  const after = await jelly(page);
  const timeline = await page.evaluate(() => window.wordJellyArrivalTimeline);
  await info.attach(`word-jelly-${label}-arrival-timeline.json`, {
    body: JSON.stringify({ before: before.preview, roots: before.upcoming, timeline }, null, 2), contentType: 'application/json'
  });
  for (const root of before.upcoming.filter(root => root.id)) {
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
      expect(tile.fragment_badges).toBe(Math.min(2, root.fragments));
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
  const arrivals = before.upcoming.flatMap((root, slot) => root.id ? [{
    ...after.tiles.find(tile => tile.id === root.id), slot, source: before.preview.slots[slot]
  }] : []);
  const delay = root => root.arrival_delay;
  for (const root of arrivals) expect(delay(root), 'The advertised lane keeps its authored crossing release beat')
    .toBeCloseTo([0, 3, 1, 4, 2, 5].indexOf(root.slot) * 0.15, 4);
  expect(new Set(arrivals.map(delay)).size, `${label}: advertised bodies have separate release beats`).toBe(arrivals.length);
  expect(Math.max(...arrivals.map(delay)) - Math.min(...arrivals.map(delay)),
    `${label}: the packet spreads across a perceptible release sequence`).toBeGreaterThanOrEqual((arrivals.length - 1) * 0.15 - 0.001);
  const crossLanePairs = arrivals.flatMap(early => arrivals
    .filter(late => early.slot > late.slot && delay(late) - delay(early) > 0.29)
    .map(late => ({ early, late })));
  const expectedCrossLane = arrivals.some(early => arrivals.some(late => early.slot > late.slot &&
    [0, 3, 1, 4, 2, 5].indexOf(late.slot) - [0, 3, 1, 4, 2, 5].indexOf(early.slot) >= 2));
  expect(crossLanePairs.length > 0).toBe(expectedCrossLane);
  const pitch = after.board_rect[3] / after.rows;
  const travel = (frame, root) => {
    const tile = frame.tiles.find(tile => tile.id === root.id);
    return tile ? tile.rect[1] + tile.rect[3] / 2 - root.source.rect[1] - root.source.rect[3] / 2 : Number.NaN;
  };
  if (crossLanePairs.length) expect(timeline.some(frame => crossLanePairs.some(({ early, late }) =>
    travel(frame, early) > pitch * 0.15 && Math.abs(travel(frame, late)) < 1)),
  `${label}: a later column visibly falls while an earlier column still waits at the tray`).toBe(true);
  if (arrivals.length > 1) expect(timeline.some(frame => arrivals.some(early => travel(frame, early) > pitch * 0.25 &&
    frame.preview[early.slot].visible && frame.preview[early.slot].id !== early.id) &&
    arrivals.some(late => Math.abs(travel(frame, late)) < 1 && !frame.preview[late.slot].visible)),
  `${label}: cleared preview slots refill while other departing roots still wait`).toBe(true);
  expect(after.generated_tiles).toBe(before.generated_tiles + arrivals.length);
  expect(after.merged_count).toBe(before.merged_count);
  expect(after.cleared_pairs).toBe(before.cleared_pairs);
  expect(after.collected_coins).toBe(before.collected_coins);
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyArrivalFrame)),
    { message: 'The actual browser captures the jellies between the tray and their support' }).toBe(true);
  const encoded = await page.evaluate(() => window.wordJellyArrivalFrame);
  fs.writeFileSync(info.outputPath(`word-jelly-${label}-falling-midpoint.png`), Buffer.from(encoded, 'base64'));
  if (arrivals.length > 1) {
    await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyStaggerFrame)),
      { message: 'The browser captures bodies falling at visibly different heights' }).toBe(true);
    const stagger = await page.evaluate(() => window.wordJellyStaggerFrame);
    fs.writeFileSync(info.outputPath(`word-jelly-${label}-staggered-release.png`), Buffer.from(stagger, 'base64'));
  }
  await capture(page, info, `word-jelly-${label}-landed`);
  await page.evaluate(() => window.wordJellyArrivalObserver.disconnect());
}

test('manual and automatic preview packets naturally fall into the well', async ({ page }, info) => {
  test.setTimeout(120000);
  const errors = await startWordJelly(page), manual = await jelly(page);
  expectSupplyLayout(manual, await metrics(page));
  expectMixedRootPacket(manual.tiles, 'Starter supply');
  expectMixedRootPacket(manual.upcoming, 'Manual supply');
  expectRootBreathingRoom(manual.preview.slots.filter(slot => slot.visible), manual.board_rect[2] / manual.columns, 'Preview row');
  expect(manual.preview.slots.filter(slot => slot.visible)).toHaveLength(manual.upcoming.filter(root => root.id).length);
  expect(manual.preview.rect[1] + manual.preview.rect[3], 'The supply tray remains above the well')
    .toBeLessThanOrEqual(manual.board_rect[1]);
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

test('blocked preview lanes retain their roots while open columns release and refill', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = await startWordJelly(page, { age: 3 }), opening = await jelly(page);
  const candidate = suppliedWords(opening, 3).find(item => item.roots.length === 1 && item.picture &&
    [item.roots[0], item.picture].some(tile => tile.row + tile.height === opening.rows));
  expect(candidate, 'The real atomic cohort provides a matching word and picture at floor level').toBeTruthy();
  const [source, target] = [candidate.roots[0], candidate.picture].sort((a, b) => a.row - b.row);
  const completed = await merge(page, source.id, target.id);
  const beforeCollection = await jelly(page);
  await pressRect(page, completed.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.cleared_pairs === beforeCollection.cleared_pairs + 1 && !state.fusions.length &&
      state.tiles.every(tile => tile.settled) && previewReady(state);
  }, { message: 'Collecting the real word leaves its surviving roots settled at uneven heights' }).toBe(true);

  const openAnchors = state => state.upcoming.flatMap((body, column) => body.id && !state.tiles.some(tile =>
    tile.column < column + body.width && tile.column + tile.width > column && tile.row < body.height) ? [column] : []);
  const blockedColumns = state => state.upcoming.flatMap((body, column) => body.id && !openAnchors(state).includes(column) ? [column] : []);
  let before = await jelly(page);
  const heights = Array.from({ length: before.columns }, (_, column) =>
    Math.min(before.rows, ...before.tiles.filter(tile => tile.column <= column && column < tile.column + tile.width).map(tile => tile.row)));
  expect(new Set(heights).size, 'A genuine collection creates different column heights').toBeGreaterThan(1);
  const filling = [];
  // Each manual release resets the supply clock. Reach the first mixed entrance
  // without waiting for an automatic packet or a fully blocked danger countdown.
  for (let packet = 0; packet < before.rows && blockedColumns(before).length === 0; packet++) {
    expect(before.preview.enabled).toBe(true);
    const previous = before;
    await pressRect(page, previous.preview.rect);
    await expect.poll(async () => {
      const state = await jelly(page);
      return state.generated_tiles === previous.generated_tiles + previous.upcoming.filter(body => body.id).length &&
        state.tiles.every(tile => tile.settled) && previewReady(state);
    }, { message: 'One ordinary manual packet settles before inspecting the next entrance' }).toBe(true);
    before = await jelly(page);
    filling.push({ generated: before.generated_tiles, blocked: blockedColumns(before), elapsed: before.spawn_elapsed });
  }
  const blocked = blockedColumns(before);
  const open = openAnchors(before);
  expect(blocked.length, 'Some full columns obstruct their own top entrances').toBeGreaterThan(0);
  expect(open.length, 'The collected word leaves at least one other entrance open').toBeGreaterThan(0);
  expect(before.full_elapsed, 'Mixed entrances do not start the full-board countdown').toBeLessThan(0);
  expect(before.preview.enabled, 'Open columns still allow a manual release').toBe(true);
  await capture(page, info, 'word-jelly-mixed-entrances-before-release');

  await page.evaluate(({ before, open }) => {
    const status = document.getElementById('game-status');
    const wanted = new Set(before.upcoming.map(root => root.id));
    const departing = new Set(open.map(column => before.upcoming[column].id));
    window.wordJellyLaneEvidence = { timeline: [], frame: null };
    let capturing = false;
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tiles = state.tiles?.filter(tile => wanted.has(tile.id)) || [];
      window.wordJellyLaneEvidence.timeline.push({ generated: state.generated_tiles, tiles,
        upcoming: state.upcoming, preview: state.preview?.slots, at: performance.now() });
      const moved = tiles.some(tile => {
        const source = before.preview.slots.find(slot => slot.id === tile.id);
        return departing.has(tile.id) && !tile.settled &&
          tile.rect[1] + tile.rect[3] / 2 > source.rect[1] + source.rect[3] / 2 + 0.5;
      });
      if (!capturing && moved) {
        capturing = true;
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = () => { window.wordJellyLaneEvidence.frame = reader.result.split(',')[1]; };
          reader.readAsDataURL(blob);
        }, 'image/png');
      }
    };
    window.wordJellyLaneObserver = new MutationObserver(record);
    window.wordJellyLaneObserver.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  }, { before, open });
  await pressRect(page, before.preview.rect);
  await expect.poll(async () => {
    const state = await jelly(page);
    return state.generated_tiles > before.generated_tiles && state.tiles.every(tile => tile.settled) &&
      previewReady(state);
  }, { message: 'The partial packet lands and only its departing slots finish refilling' }).toBe(true);
  const after = await jelly(page);
  await page.evaluate(() => window.wordJellyLaneObserver.disconnect());
  // Freeze immediately: the partial release may have filled the final gaps.
  await openModeMenu(page);
  await expect.poll(async () => (await jelly(page)).paused).toBe(true);
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyLaneEvidence.frame)),
    { message: 'The real partial release retains a rendered canvas frame' }).toBe(true);
  const evidence = await page.evaluate(() => window.wordJellyLaneEvidence);
  fs.writeFileSync(info.outputPath('word-jelly-partial-release.png'), Buffer.from(evidence.frame, 'base64'));
  fs.writeFileSync(info.outputPath('word-jelly-partial-release-timeline.json'),
    JSON.stringify({ filling, blocked, open, before, after, timeline: evidence.timeline }, null, 2));

  const identity = root => ({ id: root.id, text: root.text, fragments: root.fragments });
  const expectedIds = open.map(column => before.upcoming[column].id).sort((a, b) => a - b);
  const arrivals = after.tiles.filter(tile => !before.tiles.some(original => original.id === tile.id));
  expect(after.generated_tiles, 'Only the open entrances generate a new body').toBe(before.generated_tiles + open.length);
  expect(arrivals.map(tile => tile.id).sort((a, b) => a - b), 'No blocked preview falls into another column').toEqual(expectedIds);
  expect(evidence.timeline.some(frame => frame.tiles.length === open.length),
    'The published timeline includes every root in the partial packet').toBe(true);
  for (const column of open) {
    const root = before.upcoming[column], landed = arrivals.find(tile => tile.id === root.id);
    expect(identity(landed), 'A released root retains its advertised contents').toEqual(identity(root));
    expect(landed.column, 'Each released preview lands in its own column').toBe(column);
    expect(after.preview.slots[column].id, 'Only a released slot advertises a replacement').not.toBe(root.id);
    expect(after.preview.slots[column].id).toBe(after.upcoming[column].id);
  }
  for (const frame of evidence.timeline.filter(frame => frame.generated > before.generated_tiles)) {
    expect(frame.generated, 'The partial release cannot create an extra fallback root').toBe(before.generated_tiles + open.length);
    for (const column of blocked) {
      expect(identity(frame.upcoming[column]), 'Blocked preview text and fragments remain in the same slot')
        .toEqual(identity(before.upcoming[column]));
      expect(frame.preview[column]).toMatchObject({ id: before.upcoming[column].id, visible: true });
    }
    for (const tile of frame.tiles) {
      const column = before.upcoming.findIndex(root => root.id === tile.id);
      expect(open, 'Every observed departure belongs to an open entrance').toContain(column);
      expect(tile.column).toBe(column);
      expect(tile.rect[0] + tile.rect[2] / 2, 'The visible fall stays centered in its advertised lane')
        .toBeCloseTo(before.preview.slots[column].rect[0] + before.preview.slots[column].rect[2] / 2, 2);
    }
  }
  expect(after.merged_count).toBe(before.merged_count);
  expect(after.cleared_pairs).toBe(before.cleared_pairs);
  expect(errors).toEqual([]);
});

test('collecting a lower word makes the stack above it visibly fall onto support', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = await startWordJelly(page, { age: 3 }), opening = await jelly(page), startingWallet = await wallet(page);
  const supportedStack = (state, support) => {
    return state.tiles.filter(tile => tile.mass === 1 && tile.settled && !tile.placement_locked &&
      tile.row + tile.height === support.row && tile.column < support.column + support.width &&
      tile.column + tile.width > support.column && !state.tiles.some(other =>
        other.id !== support.id && other.id !== tile.id && other.row === support.row &&
        other.column < tile.column + tile.width && other.column + other.width > tile.column));
  };
  const lowerWord = state => state.tiles.find(tile => tile.word?.id && supportedStack(state, tile).length);
  let before = opening, completed;
  // Match a pictured word through normal input, preserving its supported stack.
  for (let packet = 0; packet < 3 && !completed; packet++) {
    const candidate = suppliedWords(before, 3).find(item => item.roots.length === 1 && item.picture &&
      [item.roots[0], item.picture].some(tile => supportedStack(before, tile).some(upper =>
        upper.id !== item.roots[0].id && upper.id !== item.picture.id)));
    if (candidate) {
      const target = [candidate.roots[0], candidate.picture].find(tile => supportedStack(before, tile).some(upper =>
        upper.id !== candidate.roots[0].id && upper.id !== candidate.picture.id));
      const source = target.id === candidate.picture.id ? candidate.roots[0] : candidate.picture;
      await merge(page, source.id, target.id);
      before = await jelly(page);
      completed = lowerWord(before);
      if (completed) break;
    }
    await expect.poll(async () => (await jelly(page)).preview.enabled).toBe(true);
    await pressRect(page, before.preview.rect);
    await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    before = await jelly(page);
    completed = lowerWord(before);
  }
  expect(completed, 'The reviewed whole-word cohort supplies a collectable sole support').toBeTruthy();
  const stack = supportedStack(before, completed);
  expect(stack.length, 'At least one ordinary upper root rests directly on the word being collected').toBeGreaterThan(0);
  for (const tile of stack) expectSupportedChild(before, tile);
  completed = before.tiles.find(tile => tile.id === completed.id);
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
        first.rect[1] < stack[0].rect[1] + (first.row - stack[0].row) * state.board_rect[3] / state.rows)
        descentPositions.add(first.rect[1]);
      // The 100 ms bridge may publish only one strictly intermediate pose in
      // this short fall; capture that pose instead of waiting past the landing.
      if (!capturePending && descentPositions.size > 0) {
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
      return tile?.settled && tile.row > original.row;
    });
  }, { message: 'Removing the lower word lets every supported upper jelly fall to its next support' }).toBe(true);
  const after = await jelly(page), bounds = await metrics(page);
  for (const original of stack) {
    const landed = after.tiles.find(tile => tile.id === original.id);
    expect(landed.column).toBe(original.column);
    expect(landed.row).toBeGreaterThanOrEqual(original.row + 1);
    expect({ text: landed.text, mass: landed.mass, fragments: landed.fragments })
      .toEqual({ text: original.text, mass: original.mass, fragments: original.fragments });
    expect(landed.fragment_badges).toBe(Math.min(2, original.fragments));
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
  const travel = timeline.flat().filter(tile => tile.id === original.id);
  const descent = travel.filter(tile => !tile.settled && tile.y > original.rect[1] && tile.y < landed.rect[1]);
  expect(descent.length, 'Collection gravity has an observed in-flight pose between its supported start and landing').toBeGreaterThan(0);
  expect(new Set(travel.map(tile => tile.y)).size, 'The browser observes distinct start, intermediate and landing positions').toBeGreaterThanOrEqual(3);
  let previousY = original.rect[1];
  for (const frame of travel) {
    expect(frame.y, 'The sampled fall moves downward without returning to its unsupported start').toBeGreaterThanOrEqual(previousY - 0.05);
    expect(frame.y).toBeLessThanOrEqual(landed.rect[1] + 0.05);
    previousY = frame.y;
  }
  await expect.poll(() => page.evaluate(() => Boolean(window.wordJellyGravityFrame)),
    { message: 'The asynchronous intermediate-frame capture finishes without stalling the descent' }).toBe(true);
  const frame = await page.evaluate(() => window.wordJellyGravityFrame);
  fs.writeFileSync(info.outputPath('word-jelly-stack-falling-midpoint.png'), Buffer.from(frame, 'base64'));
  await capture(page, info, 'word-jelly-stack-landed-after-collection');
  const earnedCoins = collectionCoins(after, before, [completed]);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + earnedCoins);
  expect(after.fragment_count).toBe(before.fragment_count + completed.fragments);
  expect(errors).toEqual([]);
});

test('lifting a lower jelly drops its stack while the pointer remains held', async ({ page }, info) => {
  const errors = await startWordJelly(page, { age: 3 }), bounds = await metrics(page);
  const before = await jelly(page), startingWallet = await wallet(page);
  const above = lower => before.tiles.find(upper => upper.id !== lower.id && upper.row + upper.height === lower.row &&
    upper.column < lower.column + lower.width && upper.column + upper.width > lower.column &&
    !before.tiles.some(other => other.id !== lower.id && other.id !== upper.id && other.row === lower.row &&
      other.column < upper.column + upper.width && other.column + other.width > upper.column));
  const support = before.tiles.find(tile => !tile.requires_read && above(tile));
  expect(support, 'The opening contains an authored body with a removable sole support').toBeTruthy();
  const upper = above(support);
  const from = center(support.rect, bounds);
  const destination = center([before.board_rect[0] + before.board_rect[2] * 0.8,
    before.board_rect[1] + before.board_rect[3] * 0.15, 0, 0], bounds);
  await page.evaluate(id => {
    const status = document.getElementById('game-status');
    window.heldSupportFall = [];
    const observer = new MutationObserver(() => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tile = state.tiles?.find(item => item.id === id);
      if (tile) window.heldSupportFall.push({ time: performance.now(), tile, drag: state.drag });
    });
    observer.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
  }, upper.id);
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  try {
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(support.id);
    expect((await jelly(page)).tiles.find(tile => tile.id === upper.id).row,
      'A press alone keeps the original support').toBe(upper.row);
    await page.mouse.move(destination.x, destination.y);
    await expect.poll(async () => {
      const state = await jelly(page), fallen = state.tiles.find(tile => tile.id === upper.id);
      return state.drag.active && state.drag.source === support.id && fallen?.settled && fallen.row > upper.row;
    }, { message: 'The upper jelly lands without waiting for pointer-up' }).toBe(true);
    const held = await jelly(page), landed = held.tiles.find(tile => tile.id === upper.id);
    expect(landed.rect[1]).toBeGreaterThan(upper.rect[1]);
    expectSupportedChild(held, landed);
    const timeline = await page.evaluate(() => window.heldSupportFall);
    expect(timeline.some(frame => frame.drag.source === support.id && frame.tile.falling && !frame.tile.settled &&
      frame.tile.rect[1] > upper.rect[1] && frame.tile.rect[1] < landed.rect[1]),
    'The browser renders an intermediate fall while the lower jelly is held').toBe(true);
    fs.writeFileSync(info.outputPath('word-jelly-held-support-fall.json'), JSON.stringify({ before, held, timeline }, null, 2));
    await capture(page, info, 'word-jelly-stack-landed-while-support-held');
    expect(held.collected_coins).toBe(before.collected_coins);
    expect(held.merged_count).toBe(before.merged_count);
    const outside = center([before.board_rect[0] - 20, before.board_rect[1] + before.board_rect[3] * 0.3, 0, 0], bounds);
    await page.mouse.move(outside.x, outside.y);
  } finally {
    await page.mouse.up();
  }
  await expect.poll(async () => {
    const state = await jelly(page);
    return !state.drag.active && state.tiles.every(tile => tile.settled);
  }).toBe(true);
  const after = await jelly(page);
  for (const tile of after.tiles) {
    expect(Boolean(tile.lifted), 'Cancellation returns every body to the board').toBe(false);
    expectSupportedChild(after, tile);
    for (const other of after.tiles.filter(item => item.id > tile.id)) {
      expect(tile.column < other.column + other.width && tile.column + tile.width > other.column &&
        tile.row < other.row + other.height && tile.row + tile.height > other.row,
      'Cancellation never overlaps the stack that occupied the old source position').toBe(false);
    }
  }
  for (const original of before.tiles) {
    const restored = after.tiles.find(tile => tile.id === original.id);
    expect(restored).toBeTruthy();
    for (const field of ['text', 'mass', 'width', 'height', 'word', 'fragments', 'composition'])
      expect(restored[field], `Cancellation preserves authored ${field}`).toEqual(original[field]);
  }
  expect((await wallet(page)).balance).toBe(startingWallet.balance);
  expect(errors).toEqual([]);
});

test('released roots and merged words fall onto support and keep their contents through later moves and rejected merges', async ({ page }, info) => {
  test.setTimeout(240000);
  const reducedMotion = info.project.use.reducedMotion || 'no-preference';
  const errors = await startWordJelly(page, { reducedMotion }), bounds = await metrics(page);
  const { roots, word } = await availableWord(page, COMPOSITION_AGE, 2, { markedOnly: true });
  const opening = await jelly(page), startingWallet = await wallet(page);
  const read = () => page.evaluate(() => JSON.parse(document.getElementById('game-status').dataset.jelly));
  const content = tile => ({ id: tile.id, text: tile.text, mass: tile.mass, parts: tile.parts_count,
    word: tile.word, coins: tile.coins, fragments: tile.fragments,
    picture: tile.picture_visible, badges: tile.fragment_badges });
  const footprint = tile => [tile.column, tile.row, tile.width, tile.height];
  const vacant = (state, tile, { sameColumn = false, outside = null } = {}) => {
    const columns = Array.from({ length: state.columns - tile.width + 1 }, (_, column) => column)
      .filter(column => !outside || column + tile.width <= outside.column || column >= outside.column + outside.width)
      .sort((a, b) => Number(a === tile.column) * (sameColumn ? -1 : 1) - Number(b === tile.column) * (sameColumn ? -1 : 1));
    for (let row = 1; row < state.rows - tile.height; row++) for (const column of columns) {
      if (column === tile.column && row === tile.row) continue;
      // Leave air below the release footprint so a grounded outcome cannot be
      // confused with a body pinned to the pointer's last position.
      if (!state.tiles.some(other => other.id !== tile.id && other.column < column + tile.width &&
        other.column + other.width > column && other.row < row + tile.height + 1 && other.row + other.height > row))
        return { column, row };
    }
    throw new Error('The ordinary board needs an empty footprint with free space below for this placement check.');
  };
  const dropPoint = (state, tile, placement) => ({
    x: state.board_rect[0] + (placement.column + tile.width / 2) * state.board_rect[2] / state.columns,
    y: state.board_rect[1] + (placement.row + tile.height / 2) * state.board_rect[3] / state.rows
  });
  const observeFall = async (id, label, origin) => page.evaluate(({ id, label, origin }) => {
    const status = document.getElementById('game-status');
    window.wordJellyPlacementFalls ||= {};
    const evidence = window.wordJellyPlacementFalls[label] = { origin, timeline: [], frame: null };
    let capturing = false;
    const record = () => {
      const state = JSON.parse(status.dataset.jelly || '{}');
      const tile = state.tiles?.find(item => item.id === id);
      if (!tile || state.drag.source === id) return;
      evidence.timeline.push({ time: performance.now(), tile });
      const pitch = state.board_rect[3] / state.rows;
      const gap = tile.height * pitch - tile.rect[3];
      const landingY = state.board_rect[1] + tile.row * pitch + gap / 2;
      const progress = (tile.rect[1] - origin.rect[1]) / (landingY - origin.rect[1]);
      if (!capturing && tile.falling && !tile.settled && progress > 0.12 && progress < 0.85) {
        capturing = true;
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = () => { evidence.frame = reader.result.split(',')[1]; };
          reader.readAsDataURL(blob);
        }, 'image/png');
      }
    };
    const observer = new MutationObserver(record);
    observer.observe(status, { attributes: true, attributeFilter: ['data-jelly'] });
    record();
  }, { id, label, origin });
  const verifyFall = async (label, original, landed, { release = false } = {}) => {
    const evidence = await page.evaluate(label => window.wordJellyPlacementFalls[label], label);
    const frames = evidence.timeline.map(frame => frame.tile);
    fs.writeFileSync(info.outputPath(`${label}-timeline.json`), JSON.stringify({ reducedMotion, bounds,
      original, landed, origin: evidence.origin, timeline: evidence.timeline }, null, 2));
    expect(content(landed), 'Falling keeps the word, picture, reward and carried fragments').toEqual(content(original));
    for (const tile of frames) expect(content(tile)).toEqual(content(original));
    if (reducedMotion !== 'reduce') {
      const falling = frames.filter(tile => tile.falling && !tile.settled);
      expect(falling.length, 'The real browser publishes an airborne pose before landing').toBeGreaterThan(0);
      const travel = landed.rect[1] - evidence.origin.rect[1];
      if (release) expect(Math.abs(falling[0].rect[1] - evidence.origin.rect[1]),
        'The released jelly starts near the hand instead of snapping to its old resting position')
        .toBeLessThan(travel * 0.18 + 1);
      if (release) expect(falling[0].rect[1], 'Final pointer-up rounding stays within one display pixel of the held pose')
        .toBeGreaterThanOrEqual(evidence.origin.rect[1] - 1 / bounds.scale);
      expect(falling.some(tile => tile.rect[1] > evidence.origin.rect[1] + 0.1 && tile.rect[1] < landed.rect[1] - 0.1),
        'At least one visible position lies between the release and supported landing').toBe(true);
      // The final pointer-up event can round differently from the last mousemove.
      // Check monotonic descent between published post-release frames.
      let previousY = frames[0].rect[1];
      for (const tile of frames) {
        expect(tile.rect[1], 'The falling body never rewinds upward').toBeGreaterThanOrEqual(previousY - 0.1);
        expect(tile.rect[1]).toBeLessThanOrEqual(landed.rect[1] + 0.1);
        previousY = tile.rect[1];
      }
      await expect.poll(() => page.evaluate(label => Boolean(window.wordJellyPlacementFalls[label].frame), label),
        { message: 'The browser retains an actual intermediate falling frame' }).toBe(true);
      const frame = await page.evaluate(label => window.wordJellyPlacementFalls[label].frame, label);
      fs.writeFileSync(info.outputPath(`${label}-midfall.png`), Buffer.from(frame, 'base64'));
    }
  };
  const drag = async (id, point, ready, screenshot, beforeRelease) => {
    const state = await read(), tile = state.tiles.find(item => item.id === id);
    expect(tile?.settled, 'The player grabs a settled body').toBe(true);
    const from = center(tile.rect, bounds), to = center([point.x, point.y, 0, 0], bounds);
    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    try {
      await page.mouse.move(from.x, from.y - 16);
      await page.mouse.move(to.x, to.y, { steps: 3 });
      await expect.poll(async () => (await read()).drag.source).toBe(id);
      await expect.poll(async () => ready(await read()), { message: 'The ordinary drag presents the expected drop affordance' }).toBe(true);
      if (screenshot) await capture(page, info, screenshot);
      if (beforeRelease) await beforeRelease(await read());
    } finally {
      await page.mouse.up();
    }
    await expect.poll(async () => (await read()).drag.active).toBe(false);
  };
  let relocation = 0;
  const dropAndLand = async (id, screenshot, options = {}) => {
    const state = await read(), tile = state.tiles.find(item => item.id === id), placement = vacant(state, tile, options);
    const point = dropPoint(state, tile, placement);
    if (screenshot) {
      point.x += state.board_rect[2] / state.columns * 0.2;
      point.y -= state.board_rect[3] / state.rows * 0.15;
    }
    await drag(id, point, current => current.placement.visible && current.placement.valid &&
      current.placement.tile_id === id && current.placement.column === placement.column && current.placement.row === placement.row,
    screenshot, current => observeFall(id, `word-jelly-release-${++relocation}`, current.tiles.find(item => item.id === id)));
    await expect.poll(async () => {
      const moved = (await read()).tiles.find(item => item.id === id);
      return moved?.settled && moved.column === placement.column && moved.row > placement.row;
    }).toBe(true);
    const current = await read(), moved = current.tiles.find(item => item.id === id);
    expect([moved.column, moved.width, moved.height], 'The release keeps the chosen column and body footprint')
      .toEqual([placement.column, tile.width, tile.height]);
    expectSupportedChild(current, moved);
    await verifyFall(`word-jelly-release-${relocation}`, tile, moved, { release: true });
    return moved;
  };
  const join = async (sourceId, targetId) => {
    // Lifting a real support can move the target before release. The shared
    // gesture follows its live supported position and validates the authored join.
    const merged = await merge(page, sourceId, targetId);
    expect(merged.placement_locked, 'A new automatic merge resumes ordinary gravity').toBe(false);
    expectSupportedChild(await read(), merged);
    return merged;
  };

  await dropAndLand(roots[0].id);
  let merged = await join(roots[0].id, roots[1].id);
  const picture = (await read()).tiles.find(tile => tile.jelly_kind === 'picture' && tile.image_word.id === word.id);
  if (picture) merged = await join(merged.id, picture.id);
  expect(merged.word.id).toBe(word.id);
  expect([merged.width, merged.height]).toEqual([1, 1]);
  expect(merged.picture_visible).toBe(true);
  let placed = await dropAndLand(merged.id, 'word-jelly-word-held-over-empty-space', { sameColumn: true });
  const firstLanding = placed;
  placed = await dropAndLand(placed.id, null, { sameColumn: true });
  expect(placed.column, 'Lifting a supported word straight upward keeps its lane').toBe(firstLanding.column);
  await capture(page, info, 'word-jelly-released-word-on-support');

  const beforeSupportMove = placed;
  await observeFall(placed.id, 'word-jelly-released-word-loses-support', beforeSupportMove);
  for (let attempt = 0; attempt < 3 && placed.row === beforeSupportMove.row; attempt++) {
    const state = await read();
    const support = state.tiles.find(tile => tile.id !== placed.id && tile.settled &&
      tile.row === placed.row + placed.height && tile.column < placed.column + placed.width && tile.column + tile.width > placed.column);
    expect(support, 'The released word has a real removable support body').toBeTruthy();
    await dropAndLand(support.id, null, { outside: placed });
    await expect.poll(async () => (await read()).tiles.find(tile => tile.id === placed.id)?.settled).toBe(true);
    placed = (await read()).tiles.find(tile => tile.id === placed.id);
  }
  expect(placed.row, 'Moving away the supports lets an already relocated word fall again').toBeGreaterThan(beforeSupportMove.row);
  expect(placed.column).toBe(beforeSupportMove.column);
  expectSupportedChild(await read(), placed);
  await verifyFall('word-jelly-released-word-loses-support', beforeSupportMove, placed);
  await capture(page, info, 'word-jelly-released-word-after-support-moves');

  const beforeInvalid = await read();
  const returnedToPlacement = async () => {
    const tile = (await read()).tiles.find(item => item.id === placed.id);
    return JSON.stringify(footprint(tile)) === JSON.stringify(footprint(placed)) &&
      tile.rect.every((value, axis) => Math.abs(value - placed.rect[axis]) < 0.05);
  };
  const overflow = { x: beforeInvalid.board_rect[0] + beforeInvalid.board_rect[2] * (1 - 0.3 / beforeInvalid.columns),
    y: beforeInvalid.board_rect[1] + beforeInvalid.board_rect[3] * 0.5 / beforeInvalid.rows };
  await drag(placed.id, overflow, current => current.drag.target === -1 && current.placement.visible && !current.placement.valid);
  await expect.poll(returnedToPlacement, { message: 'A footprint crossing the edge visibly returns to its supported position' }).toBe(true);
  const outside = { x: beforeInvalid.board_rect[0] - 12 / bounds.scale, y: overflow.y };
  await drag(placed.id, outside, current => current.drag.target === -1 && !current.placement.valid);
  await expect.poll(returnedToPlacement, { message: 'A pointer released outside the well visibly returns to its supported position' }).toBe(true);
  const returned = await read();
  expect(content(returned.tiles.find(tile => tile.id === placed.id))).toEqual(content(placed));
  expect(returned.merged_count, 'A rejected empty or outside drop never starts a merge').toBe(beforeInvalid.merged_count);
  expect(returned.collected_coins).toBe(opening.collected_coins);
  expect(returned.fragment_count).toBe(opening.fragment_count);

  const words = new Set(vocabulary.filter(item => item.min_age === COMPOSITION_AGE).map(item => normalize(item.text)));
  const extra = returned.tiles.find(tile => tile.id !== placed.id && tile.mass === 1 && tile.settled &&
    !authoredJoin(tile, placed));
  expect(extra, 'An ordinary unfinished root can join the moved word').toBeTruthy();
  const rejected = await rejectMerge(page, extra.id, placed.id, {
    info, label: 'word-jelly-moved-word-rejects-invalid-append', reducedMotion
  });
  for (const original of [extra, placed]) {
    const retained = rejected.after.tiles.find(tile => tile.id === original.id);
    expect(content(retained), 'A rejected append preserves the relocated word and root').toEqual(content(original));
    expectSupportedChild(rejected.after, retained);
  }
  expect((await wallet(page)).balance, 'Dragging and a rejected merge do not collect word coins').toBe(startingWallet.balance);
  await pressRect(page, rejected.after.tiles.find(tile => tile.id === placed.id).rect);
  await expect.poll(async () => (await read()).cleared_pairs).toBe(opening.cleared_pairs + 1);
  const final = await read();
  const earnedCoins = collectionCoins(final, opening, [placed]);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + earnedCoins);
  expect(final.cleared_pairs).toBe(opening.cleared_pairs + 1);
  expect(final.fragment_count).toBe(opening.fragment_count + placed.fragments);
  expect(errors).toEqual([]);
});

test('word pair colors distinguish exact completion targets and preserve source order', async ({ page }, info) => {
  const errors = await startWordJelly(page);
  const supplied = await availableWord(page, COMPOSITION_AGE, 2, { invalidReverse: true });
  const opening = await jelly(page);
  const words = new Set(jellyWordsForAge(COMPOSITION_AGE).map(word => normalize(word.text)));
  const roots = opening.tiles.filter(tile => tile.mass === 1 && tile.settled && tile.visible);
  const pair = { source: supplied.roots[0], target: supplied.roots[1] };
  expect(pair, 'The real board provides a shared-color word pair with an unambiguous spelling order').toBeTruthy();
  for (const tile of roots) {
    expect(tile.palette_index).toBeGreaterThanOrEqual(0);
    expect(tile.palette_hue).toBeGreaterThanOrEqual(0);
    for (const other of roots.filter(other => other.id > tile.id && other.palette_index === tile.palette_index))
      expect(Boolean(authoredJoin(tile, other) || authoredJoin(other, tile)),
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
    await page.mouse.move(point.x, point.y - 12);
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(pair.source.id);
    const selected = await jelly(page), source = selected.tiles.find(tile => tile.id === pair.source.id);
    const validTargets = selected.tiles.filter(tile => tile.id !== source.id && authoredJoin(source, tile));
    expect(validTargets.length).toBeGreaterThan(0);
    for (const target of validTargets) {
      expect(target.palette_index).toBe(source.palette_index);
      expect(target.palette_hue).toBeCloseTo(source.palette_hue, 5);
    }
    for (const target of selected.tiles.filter(tile => tile.id !== source.id && !authoredJoin(source, tile)))
      expectRestingPalette(target, opening.tiles.find(tile => tile.id === target.id),
        'An invalid ordered target retains its resting color even if it shares the held source hue');
    await capture(page, info, 'word-jelly-compatible-target-colors');
  } finally {
    await page.keyboard.press('Escape');
    await page.mouse.up();
  }
  await expect.poll(async () => (await jelly(page)).drag.source).toBe(-1);
  await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
  const reverseOpening = await jelly(page);
  const reverse = center(reverseOpening.tiles.find(tile => tile.id === pair.target.id).rect, bounds);
  await page.mouse.move(reverse.x, reverse.y);
  await page.mouse.down();
  try {
    await page.mouse.move(reverse.x, reverse.y - 12);
    await expect.poll(async () => (await jelly(page)).drag.source).toBe(pair.target.id);
    const selected = await jelly(page);
    expectRestingPalette(selected.tiles.find(tile => tile.id === pair.source.id),
      reverseOpening.tiles.find(tile => tile.id === pair.source.id),
      'Selecting the suffix leaves the original prefix in its resting color');
    expect(selected.tiles.find(tile => tile.id === pair.source.id).completion_hint,
      'Shared resting colors do not advertise an invalid reversed word as a completion').toBe(false);
  } finally {
    await page.keyboard.press('Escape');
    await page.mouse.up();
  }
  await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
  const completed = await completeSuppliedWord(page, supplied);
  expect(words.has(normalize(completed.text))).toBe(true);
  expect(completed.picture_visible).toBe(true);
  expect(completed.palette_index).toBeGreaterThanOrEqual(0);
  await capture(page, info, 'word-jelly-color-guided-completed-word');
  expect(errors).toEqual([]);
});

for (const { layout, viewport, reducedMotion } of [
  { layout: 'desktop', viewport: { width: 1366, height: 768 }, reducedMotion: 'no-preference' },
  { layout: 'desktop', viewport: { width: 1366, height: 768 }, reducedMotion: 'reduce' },
  { layout: 'phone', viewport: { width: 393, height: 852 }, reducedMotion: 'no-preference' },
  { layout: 'phone', viewport: { width: 393, height: 852 }, reducedMotion: 'reduce' }
]) {
  test(`drag completion hints follow exact source order and clear with the gesture (${layout}, ${reducedMotion})`, async ({ page }, info) => {
    test.setTimeout(240000);
    await page.setViewportSize(viewport);
    await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5 });
    const errors = await startWordJelly(page, { reducedMotion });
    const pair = await availableWord(page, COMPOSITION_AGE, 2, { invalidReverse: true });
    const opening = await jelly(page), bounds = await metrics(page);
    const audioAvailable = await page.evaluate(() => window.audioObservation.available);
    const playbackIndex = () => page.evaluate(() => window.audioObservation.playbacks.length);
    const contactSounds = (from, recording) => page.evaluate(({ from, fingerprint }) =>
      window.audioObservation.playbacks.slice(from).filter(sound => sound.fingerprint === fingerprint),
    { from, fingerprint: recording.fingerprint });
    const evidence = { layout, viewport, reducedMotion, prefix: pair.roots[0].text, suffix: pair.roots[1].text,
      audioAvailable, opening };
    const evidencePath = info.outputPath('word-jelly-completion-samples.json');
    const retainEvidence = () => fs.writeFileSync(evidencePath, JSON.stringify(evidence, null, 2));
    const words = new Set(jellyWordsForAge(COMPOSITION_AGE).map(word => normalize(word.text)));
    const hintedIds = state => state.tiles.filter(tile => tile.completion_hint).map(tile => tile.id).sort((a, b) => a - b);
    const expectedIds = (state, source) => state.tiles.filter(tile => tile.id !== source.id && tile.settled &&
      Boolean(authoredJoin(source, tile))).map(tile => tile.id).sort((a, b) => a - b);
    const expectQuiet = state => {
      expect(hintedIds(state), 'Idle, canceled and paused jellies do not advertise a held prefix').toEqual([]);
      expect(state.contact.kind, 'Contact pressure clears when the gesture ends or pauses').toBe('none');
      for (const tile of state.tiles) expect(tile.completion_scale).toBe(1);
    };
    const safePoint = center([opening.board_rect[0] + opening.board_rect[2] * 0.25,
      opening.board_rect[1] + opening.board_rect[3] * 0.18, 0, 0], bounds);
    const beginDrag = async source => {
      await expect.poll(async () => (await jelly(page)).tiles.find(tile => tile.id === source.id)?.settled,
        { message: 'The next held root is settled after the previous cancellation' }).toBe(true);
      const point = center((await jelly(page)).tiles.find(tile => tile.id === source.id).rect, await metrics(page));
      await page.mouse.move(point.x, point.y);
      await page.mouse.down();
      await page.mouse.move(point.x, point.y - 16);
      await page.mouse.move(safePoint.x, safePoint.y, { steps: 8 });
      await expect.poll(async () => (await jelly(page)).drag.source).toBe(source.id);
      await expect.poll(async () => {
        const held = await jelly(page);
        return JSON.stringify(hintedIds(held)) === JSON.stringify(expectedIds(held, source));
      }, { message: 'A held prefix publishes its forward completions as dragging begins' }).toBe(true);
      await capture(page, info, `word-jelly-completion-held-${source.id}`);
      await expect.poll(async () => (await jelly(page)).drag.active).toBe(true);
      await expect.poll(async () => (await jelly(page)).tiles.filter(tile => tile.id !== source.id).every(tile => tile.settled),
        { message: 'Lifting a supporting jelly lets the remaining stack settle before measuring its glow' }).toBe(true);
      await expect.poll(async () => {
        const state = await jelly(page);
        return JSON.stringify(hintedIds(state)) === JSON.stringify(expectedIds(state, source));
      }).toBe(true);
      return jelly(page);
    };
    expectQuiet(opening);
    await capture(page, info, 'word-jelly-completion-idle');
    const activeOpening = await beginDrag(pair.roots[0]);
    try {
      const samples = [];
      for (let frame = 0; frame < 8; frame++) {
        const state = await jelly(page);
        expect(hintedIds(state), 'Only exact current-age source-plus-target words receive a completion effect')
          .toEqual(expectedIds(state, pair.roots[0]));
        for (const tile of state.tiles.filter(tile => tile.id !== pair.roots[0].id)) {
          const original = opening.tiles.find(item => item.id === tile.id);
          const layout = activeOpening.tiles.find(item => item.id === tile.id);
          if (layout) expect(tile.rect, 'Breathing changes the jelly skin without moving its hit box or text layout').toEqual(layout.rect);
          if (original && !authoredJoin(pair.roots[0], tile))
            expectRestingPalette(tile, original, 'Dragging a prefix leaves all invalid ordered targets in their resting colors');
          expect(tile.completion_scale).toBeGreaterThanOrEqual(1);
          expect(tile.completion_scale).toBeLessThanOrEqual(1.065);
          if (reducedMotion === 'reduce' || !tile.completion_hint) expect(tile.completion_scale).toBe(1);
        }
        samples.push(state.tiles.find(tile => tile.id === pair.roots[1].id).completion_scale);
        await page.waitForTimeout(120);
      }
      if (reducedMotion === 'no-preference') {
        expect(Math.max(...samples), 'A compatible target softly grows during an actual drag').toBeGreaterThan(1.01);
        expect(Math.max(...samples) - Math.min(...samples), 'The target breathes gently rather than snapping to one size')
          .toBeGreaterThan(0.003);
      }
      await capture(page, info, 'word-jelly-completion-active');
      evidence.active = await jelly(page);
      evidence.scales = samples;
      const forwardTarget = center((await jelly(page)).tiles.find(tile => tile.id === pair.roots[1].id).rect, bounds);
      forwardTarget.y -= pair.roots[1].rect[3] * bounds.scale * 0.34;
      await page.mouse.move(forwardTarget.x, forwardTarget.y, { steps: 8 });
      await expect.poll(async () => (await jelly(page)).contact).toMatchObject({
        kind: 'match', source: pair.roots[0].id, target: pair.roots[1].id
      });
      evidence.forwardContact = await jelly(page);
      expect(evidence.forwardContact.contact.strength).toBeGreaterThan(0);
      expect(evidence.forwardContact.tiles.find(tile => tile.id === pair.roots[1].id).completion_hint).toBe(true);
      await capture(page, info, 'word-jelly-completion-forward-contact');
      await page.keyboard.press('Escape');
      await expect.poll(async () => (await jelly(page)).drag.active).toBe(false);
      expectQuiet(await jelly(page));
    } finally {
      await page.mouse.up();
    }
    const reverseOpening = await jelly(page);
    const restingPrefix = reverseOpening.tiles.find(tile => tile.id === pair.roots[0].id);
    await beginDrag(pair.roots[1]);
    try {
      const reversed = await jelly(page);
      expect(reversed.tiles.find(tile => tile.id === pair.roots[0].id).completion_hint,
        'Dragging a suffix never highlights the original prefix when their reversed spelling is invalid').toBe(false);
      expectRestingPalette(reversed.tiles.find(tile => tile.id === pair.roots[0].id), restingPrefix,
        'Dragging a suffix does not recolor its original prefix before contact');
      evidence.reverseActive = reversed;
      const reverseTarget = center(reversed.tiles.find(tile => tile.id === pair.roots[0].id).rect, bounds);
      reverseTarget.y -= pair.roots[0].rect[3] * bounds.scale * 0.34;
      const beforeContact = await playbackIndex();
      await page.mouse.move(reverseTarget.x, reverseTarget.y, { steps: 8 });
      await expect.poll(async () => (await jelly(page)).drag.target).toBe(pair.roots[0].id);
      const touching = await jelly(page);
      expect(touching.contact.kind, 'Every settled body gives neutral pressure without advertising a reversed word as a match').toBe('touch');
      expect(touching.contact.strength).toBeGreaterThan(0);
      expect(touching.contact).toMatchObject({ source: pair.roots[1].id, target: pair.roots[0].id });
      expect(touching.tiles.find(tile => tile.id === pair.roots[0].id).completion_hint).toBe(false);
      expectRestingPalette(touching.tiles.find(tile => tile.id === pair.roots[0].id), restingPrefix,
        'Neutral physical contact does not recolor the prefix of an invalid reversed word');
      evidence.reverseContact = touching;
      await capture(page, info, 'word-jelly-completion-reverse-contact');
      if (audioAvailable) {
        evidence.contactAudio = await expectRecording(page, beforeContact, 'assets/imported-audio/jelly-interaction/contact.wav');
        expect(evidence.contactAudio.fingerprint).toBeTruthy();
        expect(evidence.contactAudio.peak).toBeGreaterThan(0.01);
        const heldSounds = await contactSounds(beforeContact, evidence.contactAudio);
        await page.waitForTimeout(250);
        expect(await contactSounds(beforeContact, evidence.contactAudio),
          'Holding a noncompleting contact does not repeat the bundled contact sound').toHaveLength(heldSounds.length);
        await page.mouse.move(safePoint.x, safePoint.y);
        await expect.poll(async () => (await jelly(page)).contact.kind).toBe('none');
        const beforeReturn = await playbackIndex();
        await page.mouse.move(reverseTarget.x, reverseTarget.y);
        await expect.poll(async () => (await jelly(page)).contact.kind).toBe('touch');
        await expectRecording(page, beforeReturn, 'assets/imported-audio/jelly-interaction/contact.wav');
        evidence.recontactAudio = await contactSounds(beforeReturn, evidence.contactAudio);
        expect(evidence.recontactAudio, 'Separating and touching the same jelly again produces one new cue').toHaveLength(1);
      }
      retainEvidence();
      const outside = center([opening.board_rect[0] - 20 / bounds.scale,
        opening.board_rect[1] + opening.board_rect[3] * 0.18, 0, 0], bounds);
      await page.mouse.move(outside.x, outside.y, { steps: 5 });
    } finally {
      await page.mouse.up();
    }
    await expect.poll(async () => (await jelly(page)).drag.active).toBe(false);
    expectQuiet(await jelly(page));
    await beginDrag(pair.roots[0]);
    try {
      await openModeMenu(page);
      await expect.poll(async () => (await jelly(page)).paused).toBe(true);
      expectQuiet(await jelly(page));
    } finally {
      await page.mouse.up();
    }
    await chooseMode(page, 'word_jelly');
    await expect.poll(async () => (await jelly(page)).paused).toBe(false);
    expectQuiet(await jelly(page));
    await capture(page, info, 'word-jelly-completion-cleared');
    evidence.cleared = await jelly(page);
    expect(evidence.cleared.merged_count, 'Contact previews and cancellation do not commit a merge').toBe(opening.merged_count);
    expect(evidence.cleared.cleared_pairs).toBe(opening.cleared_pairs);
    expect(evidence.cleared.fragment_count).toBe(opening.fragment_count);
    retainEvidence();
    await info.attach('word-jelly-completion-samples.json', { path: evidencePath, contentType: 'application/json' });
    expect(errors).toEqual([]);
  });
}

test('merged word mastery is recorded only on collection and survives reload', async ({ page }) => {
  test.setTimeout(180000);
  const streaks = Object.fromEntries(jellyWordsForAge(COMPOSITION_AGE).map(word => [word.id, 2]));
  await page.addInitScript(({ age, streaks }) => {
    const key = 'growWithPip.growth.v1';
    if (!localStorage.getItem(key)) localStorage.setItem(key,
      `[growth]\nversion=3\nlevel=0\nage=${age - 1}\nstreaks=${JSON.stringify(streaks)}\nmastered_words=[]\nreceipts=[]\n`);
  }, { age: COMPOSITION_AGE, streaks });
  const errors = await startWordJelly(page, { reducedMotion: 'reduce', preseededGrowth: true });
  const candidate = await availableWord(page, COMPOSITION_AGE, 2), { word } = candidate;
  expect((await growth(page)).streaks[word.id], 'The word needs one more correct attempt for mastery').toBe(2);
  const merged = await completeSuppliedWord(page, candidate);
  expect((await growth(page)).streaks[word.id], 'Merging alone grants no mastery attempt').toBe(2);
  const before = await jelly(page);
  await pressRect(page, merged.rect);
  await pressRect(page, merged.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  await expect.poll(async () => (await growth(page)).streaks[word.id],
    { message: 'Collecting the manual merged word grants its third attempt regardless of its coin roll' }).toBe(3);
  await openModeMenu(page);
  await chooseMode(page, 'match');
  await page.reload();
  await enterGame(page, { home: true });
  await expect.poll(async () => (await growth(page)).streaks[word.id],
    { message: 'Mastery survives leaving the mode and reloading saved progress' }).toBe(3);
  expect(errors).toEqual([]);
});

test('six columns build a pictured word and a deliberate tap collects Lv1 without coins', async ({ page }, info) => {
  const errors = await startWordJelly(page), opening = await jelly(page), bounds = await metrics(page);
  expect(opening.columns).toBe(6);
  expect(opening.rows).toBe(8);
  const occupied = new Set();
  for (const tile of opening.tiles) for (let row = tile.row; row < tile.row + tile.height; row++)
    for (let column = tile.column; column < tile.column + tile.width; column++) {
      expect(occupied.has(row * opening.columns + column), 'Authored starter footprints do not overlap').toBe(false);
      occupied.add(row * opening.columns + column);
    }
  expect(occupied.size).toBe(18);
  expect(opening.upcoming).toHaveLength(6);
  for (const tile of opening.tiles) {
    expect(tile.mass).toBe(1);
    expect(tile.picture_visible, 'Only picture sources and pictured merged words show image artwork')
      .toBe(tile.jelly_kind === 'picture' || tile.jelly_kind === 'merged' && Boolean(tile.word.image));
    expectInside(tile.rect, bounds);
  }
  await capture(page, info, 'word-jelly-six-column-opening');
  const originalViewport = page.viewportSize();
  for (const viewport of [{ width: 1473, height: 1175 }, { width: 768, height: 1024 },
    { width: 390, height: 844 }, { width: 393, height: 852 }]) {
    await page.setViewportSize(viewport);
    await rendered(page);
    await expect(async () => expectSupplyLayout(await jelly(page), await metrics(page)))
      .toPass({ timeout: 5000 });
    if (viewport.width === 393) await capture(page, info, 'word-jelly-header-finish-393x852');
  }
  await page.setViewportSize({ width: 568, height: 320 });
  await rendered(page);
  await expect.poll(async () => (await jelly(page)).layout_paused,
    { message: 'An undersized landscape viewport pauses instead of shrinking authored text below its reading floor' }).toBe(true);
  const undersized = await jelly(page);
  await page.waitForTimeout(250);
  expect((await jelly(page)).spawn_elapsed, 'The cramped-layout pause preserves the supply clock').toBe(undersized.spawn_elapsed);
  await capture(page, info, 'word-jelly-landscape-reading-pause');
  await page.setViewportSize(originalViewport);
  await rendered(page);
  await expect(async () => expectSupplyLayout(await jelly(page), await metrics(page)))
    .toPass({ timeout: 5000 });
  const candidate = rootsForWord(await jelly(page), COMPOSITION_AGE, 2) ||
    await availableWord(page, COMPOSITION_AGE, 2);
  const { roots, word } = candidate;
  const startingWallet = await wallet(page);
  await pressRect(page, roots[0].rect);
  await page.waitForTimeout(500);
  expect((await jelly(page)).tiles.some(tile => tile.id === roots[0].id), 'Tapping an unfinished root leaves it on the board').toBe(true);
  expect((await wallet(page)).balance).toBe(startingWallet.balance);
  const merged = await completeSuppliedWord(page, candidate);
  expect(merged.word.id).toBe(word.id);
  expect(merged.word.min_age).toBe(COMPOSITION_AGE);
  expect(merged.picture_visible, 'The actual word art appears on the completed jelly').toBe(true);
  expect([merged.width, merged.height], 'The completed body keeps one normal square cell').toEqual([1, 1]);
  expect(merged.rect[2], 'The pictured word keeps square proportions').toBeCloseTo(merged.rect[3], 3);
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
  const collected = await jelly(page);
  const earnedCoins = collectionCoins(collected, before, [merged]);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + earnedCoins);
  expect(collected.tiles.some(tile => tile.id === merged.id)).toBe(false);
  expect(collected.fragment_count).toBe(before.fragment_count + merged.fragments);
  await openModeMenu(page);
  await chooseMode(page, 'match');
  await expect.poll(async () => (await metrics(page)).library.current).toBe('match');
  expect((await wallet(page)).balance, 'Leaving the mode never pays the collected word again').toBe(startingWallet.balance + earnedCoins);
  await page.reload();
  await enterGame(page);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + earnedCoins);
  expect(errors).toEqual([]);
});

test('collect button grows with completed words and collects a rhythmic batch once', async ({ page }, info) => {
  test.setTimeout(240000);
  const errors = await startWordJelly(page);
  const availableStageWord = async (markedOnly = false) => {
    await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    const state = await jelly(page);
    const candidates = Array.from({ length: 10 }, (_, index) => suppliedWords(state, index + 3)).flat()
      .filter(candidate => !markedOnly || [...candidate.roots, candidate.picture].some(tile => tile?.fragments > 0))
      .sort((left, right) => Number(!(left.roots.length === 1 && left.picture)) -
        Number(!(right.roots.length === 1 && right.picture)));
    expect(candidates.length, 'The live mastery stage supplies a complete word packet across age groups').toBeGreaterThan(0);
    return candidates[0];
  };
  await availableStageWord(true);
  const initial = await jelly(page), bounds = await metrics(page);
  expect(initial.collect_button.visible).toBe(true);
  expect(initial.collect_button.enabled).toBe(false);
  expect(initial.collect_button.count).toBe(0);
  expectSupplyLayout(initial, bounds);
  await capture(page, info, 'word-jelly-collect-count-0');
  const collectedIds = [];
  const stages = [initial.collect_button];
  for (let count = 1; count <= 3; count++) {
    const candidate = await availableStageWord(count === 1);
    const merged = await completeSuppliedWord(page, candidate);
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
  const expectedFragments = selected.reduce((sum, tile) => sum + tile.fragments, 0);
  expect(expectedFragments, 'The ordinary-input batch includes a real carried treasure fragment').toBeGreaterThan(0);
  const readingTiming = { interval: 0.25, entrance: 0.055, fade: 0.22 };
  await page.exposeFunction('saveWordJellyBatchFrame', (index, encoded) =>
    fs.writeFileSync(info.outputPath(`word-jelly-batch-${index}.png`), Buffer.from(encoded, 'base64')));
  await page.evaluate(readingTiming => {
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
      // Status publications can miss a short pickup during slower frames. Capture
      // playback and the overlapping reading burst, without requiring every transient.
      const entries = reveal?.entries || [];
      const opaqueSeconds = Math.max(0, Math.min(...entries.map(entry => entry.duration)) -
        readingTiming.entrance - readingTiming.fade);
      const requiredOpaque = Math.min(batch.total, 1 + Math.floor(opaqueSeconds / readingTiming.interval));
      const readingBurst = batch.active && batch.started === batch.total &&
        entries.filter(entry => entry.content_alpha > 0.9).length >= requiredOpaque;
      const index = readingBurst ? 'reveal' :
        batch.active && batch.started && state.fusion_effects?.length ? 'active' : '';
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
  }, readingTiming);
  // Consecutive trusted presses exercise the disabled state during playback.
  const point = center(before.collect_button.rect, bounds);
  await page.touchscreen.tap(point.x, point.y);
  await page.touchscreen.tap(point.x, point.y);
  await expect.poll(async () => (await jelly(page)).collection_batch.completed,
    { message: 'Every captured completed word is collected through the rhythmic queue' }).toBe(3);
  await expect.poll(async () => (await jelly(page)).collection_batch.active).toBe(false);
  const expectedCoins = collectionCoins(await jelly(page), before, selected);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + expectedCoins);
  let timeline;
  try {
    await expect.poll(() => page.evaluate(() => window.wordJellyBatchCaptured.slice().sort()),
      { message: 'The real batch animation and overlapping readable words both produce rendered evidence' }).toEqual(['active', 'reveal']);
  } finally {
    timeline = await page.evaluate(() => {
      window.wordJellyBatchObserver.disconnect();
      return window.wordJellyBatchTimeline;
    });
    const layout = { board: initial.board_rect, preview: initial.preview.rect, collect: initial.collect_button.rect,
      paidTools: Object.fromEntries(Object.entries(initial.powerup_buttons).map(([kind, button]) => [kind, button.rect])),
      divider: initial.action_divider, finish: initial.finish.rect };
    fs.writeFileSync(info.outputPath('word-jelly-batch-timeline.json'), JSON.stringify({ layout, stages, timeline }, null, 2));
  }
  const final = await jelly(page);
  expect(timeline.some(frame => frame.active), 'The observer sees the disabled control during batch playback').toBe(true);
  expect(timeline.some(frame => !frame.active && frame.completed === 3), 'The browser observes the completed queue').toBe(true);
  const selectedById = new Map(selected.map(tile => [tile.id, tile]));
  let previousStarted = 0, previousCompleted = 0;
  const entryStates = new Map();
  for (const frame of timeline) {
    expect(frame.button.rect, 'The Collect target stays fixed throughout real batch playback').toEqual(initial.collect_button.rect);
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
    collectionCoins({ collected_coins: frame.collectedCoins }, before, paid);
    expect(frame.fragments, 'Observed treasure credit matches the same completed prefix')
      .toBe(before.fragment_count + paid.reduce((sum, tile) => sum + tile.fragments, 0));
    for (const entry of frame.revealed.entries) {
      expect(entry.entry_id, 'Each word owns a stable independent reveal identity').toBeTruthy();
      const earlier = entryStates.get(entry.entry_id);
      if (earlier) {
        expect(entry.word_id, 'Later pickups cannot replace an active entry content').toBe(earlier.word_id);
        expect(entry.resting_rect, 'Each card keeps its chosen position throughout its lifetime').toEqual(earlier.resting_rect);
        expect(entry.variant_scale, 'Each card keeps its own chosen size throughout its lifetime').toBe(earlier.variant_scale);
        expect(entry.elapsed, 'Each card advances its own lifetime').toBeGreaterThanOrEqual(earlier.elapsed);
      }
      entryStates.set(entry.entry_id, entry);
    }
    if (frame.active) expect(frame.button.enabled).toBe(false);
    previousStarted = frame.started;
    previousCompleted = frame.completed;
  }
  expect(final.collection_batch.started).toBe(3);
  expect(final.collection_batch.completed).toBe(3);
  expect(final.collection_batch.elapsed, 'Three 250 ms collections finish in 750 ms of game time').toBeCloseTo(0.75, 6);
  expect(entryStates.size, 'Each of the three collected words owns an independent reading card').toBe(3);
  const opaqueSeconds = Math.max(0, Math.min(...[...entryStates.values()].map(entry => entry.duration)) -
    readingTiming.entrance - readingTiming.fade);
  const requiredOpaque = Math.min(3, 1 + Math.floor(opaqueSeconds / readingTiming.interval));
  const readable = timeline.find(frame => frame.active && frame.started === 3 &&
    frame.revealed.entries.filter(entry => entry.content_alpha > 0.9).length >= requiredOpaque);
  const lastWord = selectedById.get(final.collection_batch.ids.at(-1)).word;
  expect(readable, `The batch sustains ${requiredOpaque} opaque cards within the layout's reading lifetime`).toBeTruthy();
  expect(readable.revealed.word_id).toBe(lastWord.id);
  expect(readable.revealed.spelling).toBe(lastWord.text);
  const entries = timeline.flatMap(frame => frame.revealed.entries);
  const burst = [...entryStates.keys()].map(id => {
    const entry = entries.find(candidate => candidate.entry_id === id && candidate.content_alpha > 0.9);
    expect(entry, 'Each collected word has an opaque reading beat, even if older cards have begun fading').toBeTruthy();
    return entry;
  });
  expect(new Set(burst.map(entry => entry.entry_id)).size, 'New words add independent cards').toBe(3);
  expect(burst.map(entry => entry.word_id).sort()).toEqual(selected.map(tile => tile.word.id).sort());
  expect(new Set(burst.map(entry => entry.resting_rect.slice(0, 2).join(','))).size,
    'The three words occupy different positions instead of covering a shared center').toBe(3);
  expect(new Set(burst.map(entry => entry.variant_scale)).size,
    'The burst varies its card sizes for a staggered rhythm').toBeGreaterThan(1);
  for (const entry of burst) expectWordRevealContent(entry, bounds, before.playfield_rect);
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
  const errors = await startWordJelly(page, { age: 3 }), opening = await jelly(page), bounds = await metrics(page);
  const scale = Math.max(2 / 3, bounds.scale), area = opening.playfield_rect;
  const gameBottom = Math.max(...[opening.board_rect, opening.collect_button.rect, opening.loot.progress.rect,
    ...Object.values(opening.powerup_buttons).map(button => button.rect)]
    .map(rect => rect[1] + rect[3]));
  expect(Math.abs(gameBottom - (area[1] + area[3] - 6 / scale)) * bounds.scale,
    'The board and collection controls retain their bottom padding within a quarter rendered pixel')
    .toBeLessThan(0.25);
  expect(opening.preview.rect[1] + opening.preview.rect[3], 'The full supply tray remains above the board')
    .toBeLessThanOrEqual(opening.board_rect[1]);
  expect(opening.word_reveal.visible).toBe(false);
  await capture(page, info, 'word-jelly-bottom-anchored-opening');
  const candidatesAtFloor = suppliedWords(opening, 3).filter(candidate => candidate.roots.length === 1 && candidate.picture &&
    [candidate.roots[0], candidate.picture].some(tile => tile.row + tile.height === opening.rows));
  const grounded = [];
  for (const candidate of candidatesAtFloor) {
    if (grounded.some(tile => tile.word.id === candidate.word.id)) continue;
    const current = await jelly(page);
    const pair = [candidate.roots[0], candidate.picture].map(tile => current.tiles.find(item => item.id === tile.id));
    const [source, target] = pair.sort((a, b) => a.row - b.row);
    grounded.push(await merge(page, source.id, target.id));
    if (grounded.length === 2) break;
  }
  expect(grounded.length, 'Two actual picture matches produce independently floor-supported words').toBeGreaterThanOrEqual(2);
  expect(grounded.every(tile => tile.row + tile.height === opening.rows)).toBe(true);
  const firstMerged = grounded[0], secondMerged = grounded[1];
  const first = { word: firstMerged.word }, second = { word: secondMerged.word };
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
      for (const entry of reveal.entries) {
        if (!entry.visible || entry.content_alpha < 0.95 || entry.elapsed < 0.20 || pending.has(entry.word_id)) continue;
        pending.add(entry.word_id);
        document.getElementById('canvas').toBlob(blob => {
          if (!blob) return;
          const reader = new FileReader();
          reader.onload = () => {
            const encoded = reader.result.split(',')[1];
            window.wordRevealFrames[entry.word_id] = encoded;
            window.saveWordRevealFrame(entry.word_id, encoded);
          };
          reader.readAsDataURL(blob);
        }, 'image/png');
      }
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
  const together = evidence.timeline.find(reveal => reveal.entries.some(entry => entry.word_id === first.word.id) &&
    reveal.entries.some(entry => entry.word_id === second.word.id));
  expect(together, 'The next word appears while the earlier card continues its own reading beat').toBeTruthy();
  const firstEntry = together.entries.find(entry => entry.word_id === first.word.id);
  const secondEntry = together.entries.find(entry => entry.word_id === second.word.id);
  expect(firstEntry.entry_id).not.toBe(secondEntry.entry_id);
  expect(firstEntry.resting_rect.slice(0, 2), 'Successive taps use different reveal positions')
    .not.toEqual(secondEntry.resting_rect.slice(0, 2));
  expect(firstEntry.elapsed, 'Showing another word does not restart the earlier card').toBeGreaterThan(secondEntry.elapsed);
  if (audioAvailable) expect(evidence.inputs, 'The four real taps delimit separate word-audio windows').toHaveLength(4);
  const pronunciationObservations = [];
  for (const [index, candidate] of candidates.entries()) {
    const reveal = evidence.timeline.flatMap(frame => frame.entries)
      .find(entry => entry.word_id === candidate.word.id && entry.content_alpha > 0.95);
    expect(reveal, 'Each collected word owns a readable opaque hold within its actual lifetime').toBeTruthy();
    expect(reveal.spelling).toBe(candidate.word.text);
    expect(reveal.word.id).toBe(candidate.word.id);
    expect(reveal.picture.replace(/^res:\/\//, '')).toBe(candidate.merged.word.image);
    expectWordRevealContent(reveal, bounds, area);
    if (index === 1) expect(reveal.reduced_motion, 'The new word also supports a steady reduced-motion reading beat').toBe(true);
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
  const earnedCoins = collectionCoins(await jelly(page), before, [firstMerged, secondMerged]);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + earnedCoins);
  await expect.poll(async () => (await jelly(page)).word_reveal.visible,
    { message: 'The picture and spelling leave on their own after the reading beat' }).toBe(false);
  const final = await jelly(page);
  expect(final.collected_coins).toBe(before.collected_coins + earnedCoins);
  expect(final.fragment_count).toBe(before.fragment_count + firstMerged.fragments + secondMerged.fragments);
  fs.writeFileSync(info.outputPath('word-jelly-reveal-timeline.json'), JSON.stringify({ timeline: evidence.timeline, pronunciationObservations }, null, 2));
  await page.evaluate(() => {
    window.wordRevealObserver.disconnect();
    document.removeEventListener('pointerdown', window.wordRevealInputHandler, { capture: true });
  });
  expect(errors).toEqual([]);
});

test('only reviewed ordered joins merge while rejected pairs separate without loss or duplicate feedback', async ({ page }, info) => {
  test.setTimeout(180000);
  const reducedMotion = info.project.use.reducedMotion || 'no-preference';
  await observeAudio(page, { fingerprintBuffers: true, fingerprintMaxDuration: 5, trackSourceLifecycle: true });
  const errors = await startWordJelly(page, { reducedMotion });
  const pair = await availableWord(page, COMPOSITION_AGE, 2, { invalidReverse: true });
  const opening = await jelly(page), startingWallet = await wallet(page);
  const { roots, word } = pair;
  expect(authoredJoin(roots[0], roots[1]).node.surface).toBe(word.text);
  expect(word.min_age).toBe(COMPOSITION_AGE);
  expect(authoredJoin(roots[1], roots[0])).toBeNull();
  const negativePath = 'assets/imported-audio/pair-feedback/wrong.wav';
  const negativeTiming = recordingTiming(negativePath);
  const audioAvailable = await page.evaluate(() => window.audioObservation.available);
  const playbackIndex = () => page.evaluate(() => window.audioObservation.playbacks.length);
  const negativeSounds = from => page.evaluate(({ from, timing }) => window.audioObservation.playbacks.slice(from).filter(sound =>
    Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate), { from, timing: negativeTiming });
  const evidence = { reducedMotion, audioAvailable, negativePath, word, roots, trials: [] };
  const retain = () => fs.writeFileSync(info.outputPath('word-jelly-rejection-audio.json'), JSON.stringify(evidence, null, 2));
  const attempt = async (sourceId, targetId, label) => {
    const audioFrom = await playbackIndex();
    const trial = { label, audioFrom };
    evidence.trials.push(trial);
    const rejection = await rejectMerge(page, sourceId, targetId, { info, label, reducedMotion,
      inspectContact: async held => {
        trial.heldContact = held.contact;
        if (audioAvailable) {
          trial.contactSound = await expectRecording(page, audioFrom, 'assets/imported-audio/jelly-interaction/contact.wav');
          expect(trial.contactSound.contextState).toBe('running');
          expect(trial.contactSound.peak).toBeGreaterThan(0.01);
          const count = await page.evaluate(({ from, fingerprint }) => window.audioObservation.playbacks.slice(from)
            .filter(sound => sound.fingerprint === fingerprint).length,
          { from: audioFrom, fingerprint: trial.contactSound.fingerprint });
          await page.waitForTimeout(400);
          expect(await page.evaluate(({ from, fingerprint }) => window.audioObservation.playbacks.slice(from)
            .filter(sound => sound.fingerprint === fingerprint).length,
          { from: audioFrom, fingerprint: trial.contactSound.fingerprint }), 'Held contact emits no repeated pressure cue').toBe(count);
          expect(await negativeSounds(audioFrom), 'Hovering an incompatible body never plays the negative cue').toEqual([]);
        }
        retain();
      }
    });
    trial.releaseAt = rejection.releaseAt;
    trial.rejectionFrames = rejection.timeline.filter(frame => frame.contact.kind === 'mismatch').map(frame => ({
      at: frame.at, strength: frame.contact.strength, tiles: frame.tiles.map(tile => ({ id: tile.id, rect: tile.rect }))
    }));
    if (audioAvailable) {
      trial.negativeSound = await expectRecording(page, audioFrom, negativePath);
      retain();
      expect(trial.negativeSound.at, 'The negative cue follows pointer-up, never hover').toBeGreaterThanOrEqual(trial.releaseAt - 2);
      expect(trial.negativeSound.at - trial.releaseAt, 'Rejection sound responds promptly to the actual release').toBeLessThan(250);
      expect(trial.negativeSound.peak).toBeGreaterThan(0.01);
      expect(trial.negativeSound.channels).toBe(2);
      expect(trial.negativeSound.channelFingerprints[0]).toBe(trial.negativeSound.channelFingerprints[1]);
      expect(trial.negativeSound.fingerprint).not.toBe(trial.contactSound.fingerprint);
      await page.waitForTimeout(950);
      trial.negativeSounds = await negativeSounds(audioFrom);
      expect(trial.negativeSounds, 'One rejected release plays the short negative recording exactly once').toHaveLength(1);
      expect(trial.negativeSounds[0].endedAt, 'The negative tail ends instead of looping').toBeGreaterThan(trial.negativeSound.at);
    }
    expect((await wallet(page)).balance, 'Rejecting a pair leaves the saved coin balance unchanged').toBe(startingWallet.balance);
    retain();
    return rejection;
  };

  await attempt(roots[1].id, roots[0].id, 'word-jelly-reversed-word-rejection');
  let unrelated;
  for (let packet = 0; packet < 4; packet++) {
    await expect.poll(async () => (await jelly(page)).tiles.every(tile => tile.settled)).toBe(true);
    const state = await jelly(page);
    const marked = state.tiles.filter(tile => tile.fragments === 1 && tile.mass === 1 && tile.settled)
      .sort((a, b) => b.row - a.row);
    unrelated = marked.flatMap(source => marked.map(target => ({ source, target }))).find(({ source, target }) =>
      source.id !== target.id && !authoredJoin(source, target) && !authoredJoin(target, source));
    if (unrelated) break;
    expect(state.preview.enabled, 'Normal supply can provide another marked body without consuming either reviewed root').toBe(true);
    await pressRect(page, state.preview.rect);
    await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
  }
  expect(unrelated, 'The real supply offers unrelated marked bodies for a second rejected release').toBeTruthy();
  const nonword = await attempt(unrelated.source.id, unrelated.target.id, 'word-jelly-unrelated-marked-rejection');
  expect(nonword.after.tiles.filter(tile => [unrelated.source.id, unrelated.target.id].includes(tile.id))
    .reduce((sum, tile) => sum + tile.fragments, 0)).toBe(2);

  const beforeValid = await jelly(page), audioFrom = await playbackIndex();
  const completed = await completeSuppliedWord(page, pair);
  expect(completed.text).toBe(word.text);
  expect(completed.word.id).toBe(word.id);
  expect(completed.word.min_age).toBe(COMPOSITION_AGE);
  expect(completed.picture_visible).toBe(true);
  expect(completed.fragments).toBe(roots.reduce((sum, root) => sum + root.fragments, 0) + (pair.picture?.fragments || 0));
  expect(completed.fragment_badges).toBe(Math.min(2, completed.fragments));
  if (audioAvailable) {
    evidence.validMergeSound = await expectRecording(page, audioFrom, 'assets/imported-audio/jelly-interaction/merge-together-v3.wav');
    expect(await negativeSounds(audioFrom), 'A valid forward merge never plays the negative cue').toEqual([]);
  }
  await capture(page, info, 'word-jelly-forward-word-after-rejections');
  expect((await wallet(page)).balance).toBe(startingWallet.balance);
  await pressRect(page, completed.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(opening.cleared_pairs + 1);
  const final = await jelly(page);
  const earnedCoins = collectionCoins(final, opening, [completed]);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + earnedCoins);
  expect(final.merged_count).toBe(beforeValid.merged_count + roots.length - 1 + (pair.picture ? 1 : 0));
  expect(final.cleared_pairs).toBe(opening.cleared_pairs + 1);
  expect(final.fragment_count).toBe(opening.fragment_count + completed.fragments);
  expect(final.tiles.some(tile => tile.id === completed.id || roots.some(root => root.id === tile.id))).toBe(false);
  evidence.final = final;
  retain();
  expect(errors).toEqual([]);
});

test('ordinary collected fragments synthesize a chest and then celebrate its upgrade', async ({ page }, info) => {
  test.skip(!['desktop-chromium', 'iphone-webkit'].includes(info.project.name), 'The complete milestone route covers desktop and phone renderers.');
  test.setTimeout(300000);
  const errors = await startWordJelly(page, { age: 3, reducedMotion: 'no-preference' });
  await page.exposeFunction('saveWordJellyFlight', (key, encoded) => {
    fs.writeFileSync(info.outputPath(`word-jelly-chest-${key}.png`), Buffer.from(encoded, 'base64'));
  });
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
            window.saveWordJellyFlight(key, window.wordJellyFlightFrames[key]).then(resolve, resolve);
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
        if (motion.phase === 'depart') {
          captureFlight(`${kind}-departure`);
          if (presentation.elapsed >= 0.65 + 0.84 / 2) captureFlight(`${kind}-transit`);
        }
        if (motion.phase === 'celebrate' && !presentation.revealed) captureFlight(`${kind}-upper-arrival`);
        if (presentation.revealed && motion.phase === 'celebrate') captureFlight(`${kind}-enlarged-turn`);
        if (motion.phase === 'return') {
          captureFlight(`${kind}-return`);
          if (presentation.elapsed >= 0.65 + (1.98 + 2.65) / 2) captureFlight(`${kind}-return-transit`);
        }
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
    const found = rootsForWord(state, 3, 1, true) || rootsForWord(state, 3, 1);
    if (!found) {
      expect(state.preview.enabled, 'Real supply remains available while building the chest').toBe(true);
      await pressRect(page, state.preview.rect);
      await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
      continue;
    }
    const completed = await completeSuppliedWord(page, found);
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
  const milestonesPath = info.outputPath('word-jelly-chest-milestones.json');
  fs.writeFileSync(milestonesPath, JSON.stringify(milestones, null, 2));
  await info.attach('word-jelly-chest-milestones.json', { path: milestonesPath, contentType: 'application/json' });
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
    expect(phases, `${kind} flies upstairs, celebrates, and returns without an intermediate stop`).toEqual(['depart', 'celebrate', 'return']);
    const upper = visible.filter(frame => frame.motion.phase === 'celebrate');
    expect(upper.length, `${kind} has an upper-screen presentation beat`).toBeGreaterThan(2);
    const upperCenter = upper[0].motion.center;
    const departure = visible.filter(frame => frame.motion.phase === 'depart');
    expect(departure.length, `${kind} has several observed poses on its outbound journey`).toBeGreaterThan(1);
    const outboundDistance = distance(anchorCenter, upperCenter);
    const route = [upperCenter[0] - anchorCenter[0], upperCenter[1] - anchorCenter[1]];
    const routeProgress = point => ((point[0] - anchorCenter[0]) * route[0] +
      (point[1] - anchorCenter[1]) * route[1]) / outboundDistance ** 2;
    const routeDeviation = point => Math.abs((point[0] - anchorCenter[0]) * route[1] -
      (point[1] - anchorCenter[1]) * route[0]) / outboundDistance;
    let previousUpperDistance = Infinity;
    let previousProgress = -Infinity;
    let previousDepartureScale = 1;
    for (const frame of departure) {
      const currentDistance = distance(frame.motion.center, upperCenter);
      const progress = routeProgress(frame.motion.center);
      expect(progress, `${kind} keeps making forward progress toward its sole upper destination`)
        .toBeGreaterThanOrEqual(previousProgress - 0.001);
      expect(progress, `${kind} has not overshot its upper destination`).toBeLessThanOrEqual(1.001);
      expect(frame.motion.scale, `${kind} grows continuously while flying toward the showcase`)
        .toBeGreaterThanOrEqual(previousDepartureScale - 0.0001);
      expect(frame.motion.scale, `${kind} reserves its largest size for arrival`)
        .toBeLessThanOrEqual(upper[0].motion.scale + 0.001);
      previousProgress = progress;
      previousUpperDistance = currentDistance;
      previousDepartureScale = frame.motion.scale;
    }
    expect(previousUpperDistance, `${kind} makes visible progress toward its upper destination`)
      .toBeLessThan(distance(departure[0].motion.center, upperCenter) - 1);
    expect(previousUpperDistance, `${kind} completes most of its flight before the upper celebration`)
      .toBeLessThan(Math.max(tolerance, outboundDistance * 0.15));
    for (const frame of upper) {
      expect(Math.abs(frame.motion.center[0] - screenCenter[0]), `${kind} stays horizontally centered upstairs`).toBeLessThan(1);
      expect(frame.motion.center[1], `${kind} celebrates in the upper portion of the screen`).toBeLessThan(bounds[1] + bounds[3] * 0.4);
    }
    expect(Math.max(...departure.map(frame => routeDeviation(frame.motion.center))),
      `${kind} visibly arcs away from the straight anchor-to-showcase line`).toBeGreaterThan(4);
    expect(Math.max(...departure.map(frame => frame.motion.scale)),
      `${kind} grows as it approaches the viewer`).toBeGreaterThan(1.1);
    expect(departure.some(frame => frame.motion.model_weight > 0.9 && Math.abs(frame.motion.pitch) > 0.025 &&
      Math.abs(frame.motion.yaw) > 0.025 && Math.abs(frame.motion.roll) > 0.025),
    `${kind} shows its real pitched and yawed model while banking through the curve`).toBe(true);
    const peakScale = Math.max(...upper.map(frame => frame.motion.scale));
    expect(upper[0].motion.scale, `${kind} reaches full size on arrival`).toBeGreaterThan(1.3);
    expect(peakScale - upper[0].motion.scale, `${kind} has no second enlargement after arriving`).toBeLessThan(0.001);
    expect(previousDepartureScale - 1, `${kind} completes most growth during its actual flight`)
      .toBeGreaterThan((peakScale - 1) * 0.85);
    expect(upper.some(frame => frame.motion.yaw > 0.1 && frame.motion.yaw < 6.1), `${kind} visibly turns while enlarged upstairs`).toBe(true);
    expect(Math.max(...visible.map(frame => frame.motion.yaw)), `${kind} completes its full closed-chest turn by the return journey`).toBeGreaterThan(6.2);
    const returning = visible.filter(frame => frame.motion.phase === 'return');
    expect(returning.length, `${kind} has a visible return journey`).toBeGreaterThan(2);
    let previousDistance = Infinity;
    let previousScale = Infinity;
    const outboundPoses = [{ center: anchorCenter, scale: 1 }, ...departure.map(frame => frame.motion), upper[0].motion];
    for (const frame of returning) {
      const currentDistance = distance(frame.motion.center, anchorCenter);
      expect(currentDistance, `${kind} returns continuously toward its original anchor`).toBeLessThanOrEqual(previousDistance + 0.1);
      expect(frame.motion.scale, `${kind} shrinks continuously on its return journey`).toBeLessThanOrEqual(previousScale);
      const next = outboundPoses.findIndex(pose => pose.scale >= frame.motion.scale);
      expect(next, `${kind} returns through the outbound size range`).toBeGreaterThanOrEqual(0);
      const a = outboundPoses[Math.max(0, next - 1)], b = outboundPoses[next];
      const blend = b.scale > a.scale ? (frame.motion.scale - a.scale) / (b.scale - a.scale) : 0;
      const outboundCenter = a.center.map((value, axis) => value + (b.center[axis] - value) * blend);
      // Browser status samples are sparse; the native suite checks exact mirrored poses.
      expect(distance(frame.motion.center, outboundCenter), `${kind} retraces its outbound curve at the same size`)
        .toBeLessThan(Math.max(3, outboundDistance * 0.025));
      previousDistance = currentDistance;
      previousScale = frame.motion.scale;
    }
    expect(Math.max(...returning.map(frame => routeDeviation(frame.motion.center))),
      `${kind} also follows a visible curve back to its HUD anchor`).toBeGreaterThan(4);
    expect(returning.some(frame => frame.motion.model_weight > 0.9 && Math.abs(frame.motion.pitch) > 0.025),
      `${kind} keeps the three-dimensional model visible during its recovery`).toBe(true);
    expect(previousDistance, `${kind} visibly covers most of the return distance before the HUD icon takes over`)
      .toBeLessThan(Math.max(tolerance, distance(upper.at(-1).motion.center, anchorCenter) * 0.35));
    expect(previousScale - 1, `${kind} visibly recovers most of its original size before the HUD icon takes over`)
      .toBeLessThan((peakScale - 1) * 0.35);
    const firstReveal = visible.find(frame => frame.revealed);
    expect(firstReveal.wordRevealVisible, 'The chest peak follows the completed word-picture reading beat').toBe(false);
    expect(['departure', 'transit', 'upper-arrival', 'enlarged-turn', 'return', 'return-transit']
      .every(phase => Boolean(keyframes[`${kind}-${phase}`])), `${kind} records all six real rendered flight keyframes`).toBe(true);
  }
  expect(errors).toEqual([]);
});


for (const { age, parts, minimumLength } of [
  { age: 3, parts: 1, minimumLength: 2 },
  { age: 12, parts: 2, minimumLength: 10 },
  { age: 12, parts: 3, minimumLength: 10 }
]) test('reviewed age ' + age + ' words use ' + parts + ' authored parts with readable labels and the same rare reward', async ({ page }, info) => {
  test.setTimeout(600000);
  const matchesReviewedCase = word => {
    const analysis = reviewed.get(word.id).analysis;
    return analysis.parts.length === parts && word.text.length >= minimumLength &&
      (parts !== 3 || hasAuthoredSpellingChange(analysis));
  };
  const targetWords = jellyWordsForAge(age).filter(matchesReviewedCase);
  // Saved learning progress applies the ordinary mastery bias to this reviewed case.
  // Supply still comes through the production sampler and real board controls.
  await seedGrowth(page, age, { unmastered: targetWords.map(word => word.id) });
  await page.addInitScript(() => {
    const key = 'growWithPip.coinWallet.v1', balance = 30000;
    if (!localStorage.getItem(key)) localStorage.setItem(key,
      `[wallet]\nversion=2\nbalance=${balance}\nreceipts=${JSON.stringify({ 'reviewed-route-opening-coins': balance })}\n`);
  });
  const errors = await startWordJelly(page, { age, reducedMotion: 'reduce', preseededGrowth: true });
  const sampled = [], discovery = [], targetIds = new Set(targetWords.map(word => word.id));
  const discoveryBounds = await metrics(page);
  const pressDiscovery = rect => tap(page, rect[0] + rect[2] / 2, rect[1] + rect[3] / 2, discoveryBounds);
  const recordDiscovery = event => {
    discovery.push(event);
    fs.writeFileSync(info.outputPath('word-jelly-reviewed-discovery.json'),
      JSON.stringify({ age, parts, targets: [...targetIds], sampled, actions: discovery }, null, 2));
  };
  let protectTarget = false;
  let selected;
  // Advance genuine supply in batches. Paid Auto merge and Collect clear unrelated
  // packets, then stop as soon as any target source reaches the board or preview.
  for (let turn = 0; turn < jellyWordsForAge(age).length * 5; turn++) {
    let state;
    await expect.poll(async () => {
      state = await jelly(page);
      return state.phase === 'playing' && !state.reward_presentation.active && !state.fusions.length &&
        !state.powerup.active && !state.collection_batch.active && state.tiles.every(tile => tile.settled);
    }).toBe(true);
    const supplied = suppliedWords(state, age);
    selected = supplied.find(candidate => matchesReviewedCase(candidate.word));
    if (selected) break;
    protectTarget ||= [...state.tiles, ...state.upcoming].some(tile => targetIds.has(tile.source_word_id));
    const ready = state.tiles.filter(tile => tile.jelly_kind === 'merged' && tile.settled);
    if (ready.length) {
      expect(ready.every(tile => !targetIds.has(tile.word.id)), 'Discovery never automatically completes a target word').toBe(true);
      for (const tile of ready) sampled.push({ id: tile.word.id, parts: reviewed.get(tile.word.id).analysis.parts.length,
        text: tile.text, assisted: tile.assisted });
      recordDiscovery({ action: 'collect', count: ready.length, generated: state.generated_tiles });
      expect(state.collect_button.enabled).toBe(true);
      await pressDiscovery(state.collect_button.rect);
      await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(state.cleared_pairs + ready.length);
      continue;
    }
    if (!protectTarget && state.tiles.length >= 30 && state.powerup_buttons.auto_merge.enabled) {
      recordDiscovery({ action: 'auto_merge', bodies: state.tiles.length, generated: state.generated_tiles });
      const previousReceipt = state.powerup.receipt_id;
      await pressDiscovery(state.powerup_buttons.auto_merge.rect);
      await expect.poll(async () => {
        const current = await jelly(page);
        return current.powerup.receipt_id !== previousReceipt && current.powerup.kind === 'auto_merge' &&
          !current.powerup.active && current.powerup.stage === 'complete';
      }, { timeout: 90000, intervals: [250, 500, 1000], message: 'The real paid tool finishes the unrelated captured supply' }).toBe(true);
      continue;
    }
    const targetColumns = state.upcoming.flatMap((tile, column) => targetIds.has(tile.source_word_id) ? [column] : []);
    const unrelated = supplied.filter(candidate => !targetIds.has(candidate.word.id));
    const blocksTarget = candidate => [...candidate.roots, candidate.picture].some(tile => tile && targetColumns.includes(tile.column));
    const other = unrelated.find(blocksTarget) || unrelated.find(candidate => candidate.roots.length === 1) || unrelated[0];
    if (other && (!state.preview.enabled || protectTarget && state.tiles.length >= 36)) {
      const completed = await completeSuppliedWord(page, other);
      sampled.push({ id: other.word.id, parts: other.analysis.parts.length, text: completed.text });
      recordDiscovery({ action: 'manual_clear', word: other.word.id, generated: state.generated_tiles });
      await pressDiscovery(completed.rect);
      await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(state.cleared_pairs + 1);
      continue;
    }
    expect(state.preview.enabled, 'The normal supply can release missing parts into the available space').toBe(true);
    recordDiscovery({ action: 'supply', generated: state.generated_tiles, protectTarget });
    await pressDiscovery(state.preview.rect);
    await expect.poll(async () => (await jelly(page)).generated_tiles).toBeGreaterThan(state.generated_tiles);
  }
  expect(selected, 'The real current-age supply reaches the reviewed part-count case').toBeTruthy();
  const { word, roots, analysis } = selected;
  expect(word.min_age).toBe(age);
  expect(roots).toHaveLength(parts);
  expect(roots.map(root => root.text)).toEqual(analysis.parts.map(part => semanticSurface(part.surface)));
  expect(roots.map(root => root.composition.canonical_id)).toEqual(analysis.parts.map(part => part.canonical_id));
  expect([...roots, selected.picture].filter(Boolean).every(tile => !tile.assisted),
    'The target sources remain untouched by the discovery powerups').toBe(true);
  const labelEvidence = { age, parts, sampled, discovery, roots, analysis };
  const save = () => fs.writeFileSync(info.outputPath('word-jelly-reviewed-morphology-labels.json'), JSON.stringify(labelEvidence, null, 2));
  const expectCompactLabel = tile => {
    expect([tile.width, tile.height], 'Every spelling occupies one normal cell').toEqual([1, 1]);
    expect(tile.rect[2], 'Spelling length does not change the square proportions').toBeCloseTo(tile.rect[3], 3);
    expect(tile.accessibility_name, 'Accessibility retains every spelling character').toContain(tile.text);
    expect(tile.tooltip_text, 'The tooltip retains every spelling character').toContain(tile.text);
    expect(tile.read_button_visible, 'The Read gesture leaves the square face unobstructed').toBe(false);
    expect(tile.read_available, 'Hold-to-read availability reflects the displayed text overflow').toBe(tile.requires_read);
    if (tile.label_visible) {
      expect(tile.label_font_pixels, 'Visible labels stay at least thirteen physical pixels').toBeGreaterThanOrEqual(13);
      expect(tile.label_line_count).toBeGreaterThan(0);
      expect(tile.label_visible_line_count, 'Every displayed line fits vertically').toBeGreaterThanOrEqual(tile.label_line_count);
      expect(tile.label_line_count * tile.label_line_height, 'The measured text lines fit the body').toBeLessThanOrEqual(tile.label_height + 0.1);
    }
  };
  roots.forEach(expectCompactLabel);
  save();
  await capture(page, info, 'word-jelly-reviewed-source-parts');
  const beforeMerge = await jelly(page), startingWallet = await wallet(page);
  const completed = await completeSuppliedWord(page, selected);
  labelEvidence.completed = completed;
  save();
  expectCompactLabel(completed);
  expect(completed.mass).toBe(parts + (selected.picture ? 1 : 0));
  expect((await jelly(page)).merged_count).toBe(beforeMerge.merged_count + parts - 1 + (selected.picture ? 1 : 0));
  expect(completed.merge_level).toBe(1);
  expect(completed.coins).toBe(0);
  expect(completed.coin_drop_chance).toBe(0);
  expect(completed.picture_visible).toBe(Boolean(word.image));
  expectInside(completed.rect, await metrics(page));
  if (parts === 3) {
    expect(hasAuthoredSpellingChange(analysis), 'The three-part browser route exercises a real authored spelling change').toBe(true);
  }
  const originalViewport = page.viewportSize();
  for (const viewport of [{ width: 1366, height: 768 }, { width: 390, height: 844 }, { width: 393, height: 852 }]) {
    await page.setViewportSize(viewport);
    await rendered(page);
    const current = (await jelly(page)).tiles.find(tile => tile.id === completed.id);
    expect([current.width, current.height], 'Viewport changes preserve the normal one-cell body').toEqual([1, 1]);
    expectCompactLabel(current);
    expectInside(current.rect, await metrics(page));
  }
  await page.setViewportSize(originalViewport);
  await rendered(page);
  await capture(page, info, 'word-jelly-reviewed-complete-word');
  const before = await jelly(page), live = before.tiles.find(tile => tile.id === completed.id);
  await pressRect(page, live.rect);
  await expect.poll(async () => (await jelly(page)).cleared_pairs).toBe(before.cleared_pairs + 1);
  const after = await jelly(page);
  expect(after.fragment_count).toBe(before.fragment_count + completed.fragments);
  expect(after.tiles.some(tile => tile.id === completed.id)).toBe(false);
  const earnedCoins = collectionCoins(after, before, [completed]);
  await expect.poll(async () => (await wallet(page)).balance).toBe(startingWallet.balance + earnedCoins);
  expect(errors).toEqual([]);
});
