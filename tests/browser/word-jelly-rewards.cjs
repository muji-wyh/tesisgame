const { expect } = require('@playwright/test');

const CHANCES = [0, 0, 0.02, 0.04, 0.06, 0.10, 0.16, 0.28, 0.50, 0.80];
const AMOUNTS = [0, 0, 50, 100, 150, 200, 250, 300, 350, 450];

function expectCollectionReward(tile) {
  const level = tile.merge_level;
  expect(tile.jelly_kind, 'Only a completed merged word can be collected').toBe('merged');
  expect(Number.isInteger(level) && level >= 1 && level <= 9, 'A collection has an explicit supported merge level').toBe(true);
  expect(tile.coin_drop_chance, `Lv${level} advertises its exact collection chance`).toBe(CHANCES[level]);
  expect(tile.coins, `Lv${level} advertises its exact potential payout`).toBe(AMOUNTS[level]);
}

function collectionCoins(after, before, tiles) {
  const possible = new Set([0]);
  for (const tile of tiles) {
    expectCollectionReward(tile);
    for (const amount of [...possible]) possible.add(amount + tile.coins);
  }
  const actual = after.collected_coins - before.collected_coins;
  expect(possible.has(actual), 'Only lucky completed words can contribute coins, each at most once').toBe(true);
  return actual;
}

module.exports = { collectionCoins, expectCollectionReward };
