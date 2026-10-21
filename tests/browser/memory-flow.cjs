const { expect } = require('@playwright/test');
const { metrics, tap, rendered } = require('./game-ui.cjs');

async function memoryState(page) {
  return (await metrics(page)).growth.memory;
}

async function pressMemoryRect(page, rect) {
  const [x, y, width, height] = rect;
  await tap(page, x + width / 2, y + height / 2);
}

async function startObservation(page) {
  await expect.poll(async () => (await memoryState(page))?.start.visible).toBe(true);
  const opening = await memoryState(page);
  expect(opening.started).toBe(false);
  await pressMemoryRect(page, opening.start.rect);
  await expect.poll(async () => (await memoryState(page)).peek.studying).toBe(true);
  const observation = await memoryState(page);
  expect(observation.peek).toMatchObject({ count: 1, duration: 10, next_price: 100 });
  expect(observation.cards).toHaveLength(10);
  expect(observation.cards.every(card => card.face_up && card.word_id)).toBe(true);
  // Remember only identities the player can actually see in this observation.
  return observation.cards.map(card => ({ index: card.index, kind: card.kind, word: card.word_id }));
}

async function startMatching(page) {
  const action = (await memoryState(page)).peek.countdown.action;
  expect(action).toMatchObject({ text: 'Start matching', visible: true, disabled: false });
  await pressMemoryRect(page, action.rect);
  await expect.poll(async () => (await memoryState(page)).peek.studying).toBe(false);
}

async function startMemory(page) {
  const board = await startObservation(page);
  await startMatching(page);
  return board;
}

async function memoryCardTap(page, index) {
  const card = (await memoryState(page)).cards.find(card => card.index === index);
  if (!card) throw new Error(`Memory card ${index} is missing`);
  await pressMemoryRect(page, card.rect);
  await rendered(page);
}

async function waitForMemoryInput(page) {
  await expect.poll(async () => {
    const state = await memoryState(page);
    return state.phase === 'waiting' && !state.peek.studying;
  }, { timeout: 10000 }).toBe(true);
}

function memoryPairs(board) {
  return [...new Set(board.map(card => card.word))].map(word => {
    const cards = board.filter(card => card.word === word);
    expect(cards.map(card => card.kind).sort()).toEqual(['image', 'word']);
    return cards.map(card => card.index);
  });
}

async function completeRememberedBoard(page, board) {
  const pairs = memoryPairs(board);
  for (const pair of pairs) {
    if ((await memoryState(page)).cards[pair[0]].pair > 0) continue;
    await waitForMemoryInput(page);
    await memoryCardTap(page, pair[0]);
    await memoryCardTap(page, pair[1]);
    await expect.poll(async () => (await memoryState(page)).cards[pair[0]].pair).toBeGreaterThan(0);
  }
  await expect.poll(async () => (await memoryState(page)).phase).toBe('won');
}

module.exports = { memoryState, pressMemoryRect, startObservation, startMatching, startMemory,
  memoryCardTap, waitForMemoryInput, memoryPairs, completeRememberedBoard };
