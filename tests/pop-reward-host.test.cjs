const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const shell = fs.readFileSync('web/shell.html', 'utf8').replace(/\r\n/g, '\n');
const block = shell.match(/        popRewardState\(\) \{[\s\S]*?\n        \},\n        savePopRewardState\(text\) \{[\s\S]*?\n        \},\n        popRewardStatus\(text\) \{[\s\S]*?\n        \}/)?.[0];
const key = 'wordBuddies.popRewards';
function host(storage, status = { dataset: {} }) {
  assert.ok(block);
  return vm.runInNewContext(`({${block}})`, { localStorage: storage, document: { getElementById: () => status } });
}

test('Pop treasure survives a new host without touching other modes or player scores', () => {
  const values = new Map([['wordBuddies.leaderboards', 'scores'], ['wordBuddies.talkQuest', 'quest']]);
  const storage = { getItem: name => values.get(name) ?? null, setItem: (name, value) => values.set(name, value) };
  assert.equal(host(storage).popRewardState(), null);
  const record = '[treasure]\nversion=1\nround_id="round-one"\n';
  assert.equal(host(storage).savePopRewardState(record), true);
  assert.equal(host(storage).popRewardState(), record);
  assert.equal(values.get('wordBuddies.leaderboards'), 'scores');
  assert.equal(values.get('wordBuddies.talkQuest'), 'quest');
});

test('blocked reads and writes stay explicit, and a retry preserves the previous record', () => {
  let fail = true, saved = 'previous';
  const storage = {
    getItem(name) { assert.equal(name, key); if (fail) throw new Error('Denied'); return saved; },
    setItem(name, text) { assert.equal(name, key); if (fail) throw new Error('Full'); saved = text; }
  };
  const bridge = host(storage);
  assert.equal(bridge.popRewardState(), false);
  assert.equal(bridge.savePopRewardState('next'), false);
  assert.equal(saved, 'previous');
  fail = false;
  assert.equal(bridge.popRewardState(), 'previous');
  assert.equal(bridge.savePopRewardState('next'), true);
  assert.equal(bridge.popRewardState(), 'next');
});

test('reward diagnostics reject malformed input and remain inert JSON', () => {
  const status = { dataset: { snapshot: '{}' } };
  const bridge = host({}, status);
  for (const invalid of ['null', '[]', 'false', 'not JSON']) bridge.popRewardStatus(invalid);
  assert.equal(status.dataset.snapshot, '{}');
  bridge.popRewardStatus(JSON.stringify({ visible: true, chest_count: 3, name: '<script>alert(1)</script>' }));
  assert.equal(JSON.parse(status.dataset.snapshot).chest_count, 3);
  assert.match(status.dataset.snapshot, /<script>/);
});
