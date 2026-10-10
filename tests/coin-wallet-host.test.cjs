const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const shell = fs.readFileSync('web/shell.html', 'utf8').replace(/\r\n/g, '\n');
const key = 'growWithPip.coinWallet.v1';

function host(storage) {
  const block = shell.match(/        coinWalletState\(\) \{[\s\S]*?\n        \},\n        saveCoinWalletState\(text, expectedText\) \{[\s\S]*?\n        \}/)?.[0];
  assert.ok(block, 'The browser exposes wallet reads and conditional writes');
  return vm.runInNewContext(`({${block}})`, { localStorage: storage, TextEncoder });
}

test('coins use an independent namespace and compare the previously loaded snapshot', () => {
  const records = new Map([['growWithPip.growth.v1', 'growth'], ['wordBuddies.popRewards', 'chests']]);
  let writes = 0;
  const bridge = host({ getItem: name => records.get(name) ?? null, setItem(name, text) { records.set(name, text); writes++; } });
  const initial = bridge.coinWalletState();
  assert.equal(initial, null);
  const first = '[wallet]\nversion=1\nbalance=50\nreceipts={"match:one":50}\n';
  assert.equal(bridge.saveCoinWalletState(first, initial), true);
  assert.equal(bridge.coinWalletState(), first);
  assert.equal(bridge.saveCoinWalletState('stale coins', initial), false);
  assert.equal(bridge.coinWalletState(), first);
  assert.equal(writes, 1);
  assert.equal(records.get('growWithPip.growth.v1'), 'growth');
  assert.equal(records.get('wordBuddies.popRewards'), 'chests');
  assert.equal(bridge.saveCoinWalletState('next snapshot', first), true);
  assert.equal(records.get(key), 'next snapshot');
});

test('missing, unavailable, malformed and oversized storage are distinguished', () => {
  const blocked = host({ getItem() { throw Error('blocked'); }, setItem() { throw Error('blocked'); } });
  assert.equal(blocked.coinWalletState(), false);
  assert.equal(blocked.saveCoinWalletState('coins', null), false);
  let writes = 0;
  const bridge = host({ getItem: () => null, setItem() { writes++; } });
  for (const text of [null, false, {}, '', 'x'.repeat(4 * 1024 * 1024 + 1), 'é'.repeat(2 * 1024 * 1024 + 1)]) {
    assert.equal(bridge.saveCoinWalletState(text, null), false);
  }
  for (const expected of [undefined, false, {}, 'stale']) {
    assert.equal(bridge.saveCoinWalletState('valid text', expected), false);
  }
  assert.equal(writes, 0);
});

test('silently dropped and quota-failed coin writes never report success', () => {
  assert.equal(host({ getItem: () => 'previous', setItem() {} }).saveCoinWalletState('next', 'previous'), false);
  const quota = host({ getItem: () => null, setItem() { throw Error('quota exceeded'); } });
  assert.equal(quota.saveCoinWalletState('next', null), false);
});
