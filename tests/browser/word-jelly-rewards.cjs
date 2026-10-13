const { expect } = require('@playwright/test');

function collectionCoins(after, before, tiles) {
  const possible = new Set([0]);
  for (const tile of tiles) {
    expect(tile.coin_drop_chance, 'Each completed word advertises a one-percent coin chance').toBe(0.01);
    expect(tile.coins, 'A lucky drop retains the existing size-based reward').toBe(tile.mass * 50);
    for (const amount of [...possible]) possible.add(amount + tile.coins);
  }
  const actual = after.collected_coins - before.collected_coins;
  expect(possible.has(actual), 'Only lucky completed words can contribute coins, each at most once').toBe(true);
  return actual;
}

module.exports = { collectionCoins };
