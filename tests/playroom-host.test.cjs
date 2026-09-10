const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const shell = fs.readFileSync('web/shell.html', 'utf8').replace(/\r\n/g, '\n');
function bridge(storage) {
  const block = shell.match(/        playroomState\(\) \{[\s\S]*?\n        \},\n        savePlayroomState\(text\) \{[\s\S]*?\n        \}/)?.[0];
  assert.ok(block, 'The host exposes a synchronous consolidated playroom record');
  return vm.runInNewContext(`({${block}})`, { localStorage: storage });
}

test('room selections are committed before the next immediate page load', () => {
  const values = new Map([['wordBuddies.favoriteReward', 'space-1'], ['wordBuddies.medalProgress', 'existing medals']]);
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) };
  assert.equal(bridge(storage).playroomState(), null);
  const saved = '[playroom]\nversion=2\ntoy="toy-space"\nbackdrop="backdrop-home"\nfavorite="space-1"\n';
  assert.equal(bridge(storage).savePlayroomState(saved), true);
  assert.equal(bridge(storage).playroomState(), saved);
  assert.equal(values.get('wordBuddies.medalProgress'), 'existing medals');
  assert.equal(values.get('wordBuddies.favoriteReward'), 'space-1');
});

test('blocked reads and quota failures stay explicit', () => {
  const host = bridge({ getItem() { throw Error('blocked'); }, setItem() { throw Error('quota'); } });
  assert.equal(host.playroomState(), false);
  assert.equal(host.savePlayroomState('new room'), false);
});
