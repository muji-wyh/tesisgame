const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const shell = fs.readFileSync('web/shell.html', 'utf8').replace(/\r\n/g, '\n');
const key = 'growWithPip.growth.v1';

function host(storage, document = {}) {
  const storageBlock = shell.match(/        growthState\(\) \{[\s\S]*?\n        \},\n        saveGrowthState\(text, expectedText\) \{[\s\S]*?\n        \}/)?.[0];
  const statusBlock = shell.match(/        growthStatus\(text\) \{[\s\S]*?\n        \}/)?.[0];
  assert.ok(storageBlock && statusBlock, 'The host exposes learning storage and an accessible snapshot');
  return vm.runInNewContext(`({${storageBlock},${statusBlock}})`, { localStorage: storage, document });
}

function presentationHost(storage) {
  const block = shell.match(/        presentationState\(\) \{[\s\S]*?\n        \},\n        savePresentationState\(text\) \{[\s\S]*?\n        \}/)?.[0];
  assert.ok(block, 'Presentation preferences use explicit host storage methods');
  return vm.runInNewContext(`({${block}})`, { localStorage: storage });
}

test('learning saves are verified synchronously and leave existing rewards and settings untouched', () => {
  const records = new Map([
    ['wordBuddies.medalProgress', 'medals'], ['wordBuddies.popRewards', 'pending chests'],
    ['pipAndWords.presentation.v1', '{"muted":true}']
  ]);
  const storage = { getItem: name => records.get(name) ?? null, setItem: (name, value) => records.set(name, value) };
  assert.equal(host(storage).growthState(), null);
  const value = '[growth]\nversion=1\nlevel=3\nstreaks={"apple":6}\nreceipts=["round-1:match-1"]\n';
  assert.equal(host(storage).saveGrowthState(value, null), true);
  assert.equal(host(storage).growthState(), value);
  assert.equal(records.get('wordBuddies.medalProgress'), 'medals');
  assert.equal(records.get('wordBuddies.popRewards'), 'pending chests');
  assert.equal(records.get('pipAndWords.presentation.v1'), '{"muted":true}');
});

test('blocked or silently dropped storage operations cannot report success', () => {
  const blocked = host({ getItem() { throw Error('blocked'); }, setItem() { throw Error('blocked'); } });
  assert.equal(blocked.growthState(), false, 'Unavailable storage differs from a missing save');
  assert.equal(blocked.saveGrowthState('value', null), false);
  assert.equal(host({ getItem: () => 'previous', setItem() {} }).saveGrowthState('next', 'previous'), false);
  let writes = 0;
  const storage = { getItem: () => null, setItem() { writes++; } };
  for (const value of [null, false, {}, '', 'x'.repeat(2 * 1024 * 1024 + 1)]) {
    assert.equal(host(storage).saveGrowthState(value, null), false);
  }
  assert.equal(writes, 0);
});

test('learning writes compare the last read save before replacing another tab\'s progress', () => {
  let current = null, writes = 0;
  const bridge = host({ getItem: () => current, setItem(_name, value) { current = value; writes++; } });
  const initial = bridge.growthState();
  assert.equal(initial, null);
  assert.equal(bridge.saveGrowthState('tab one progress', initial), true);
  assert.equal(bridge.saveGrowthState('stale tab progress', initial), false);
  assert.equal(current, 'tab one progress');
  assert.equal(bridge.saveGrowthState('rebased progress', bridge.growthState()), true);
  assert.equal(current, 'rebased progress');
  for (const expected of [undefined, false, {}, 'stale tab progress']) {
    assert.equal(bridge.saveGrowthState('untracked replacement', expected), false);
  }
  assert.equal(writes, 2, 'Stale or missing expected versions must never reach setItem');
});

test('presentation choices round-trip through the existing key without replacing learning or legacy theme saves', () => {
  const records = new Map([[key, 'learning progress'], ['wordBuddies.playroom', 'legacy theme record']]);
  const bridge = presentationHost({ getItem: name => records.get(name) ?? null, setItem: (name, value) => records.set(name, value) });
  assert.equal(bridge.presentationState(), null);
  const text = JSON.stringify({ muted: true, preferred_theme: 'candy', reduced_motion: false });
  assert.equal(bridge.savePresentationState(text), true);
  assert.equal(bridge.presentationState(), text);
  assert.equal(records.get('pipAndWords.presentation.v1'), text);
  assert.equal(records.get(key), 'learning progress');
  assert.equal(records.get('wordBuddies.playroom'), 'legacy theme record');
});

test('presentation saves report blocked and silently discarded writes instead of claiming success', () => {
  const blocked = presentationHost({ getItem() { throw Error('blocked'); }, setItem() { throw Error('blocked'); } });
  assert.equal(blocked.presentationState(), false);
  assert.equal(blocked.savePresentationState('{"muted":true}'), false);
  assert.equal(presentationHost({ getItem: () => 'previous', setItem() {} }).savePresentationState('next'), false);
  let writes = 0;
  const bridge = presentationHost({ getItem: () => null, setItem() { writes++; } });
  for (const value of [null, false, {}, '', 'x'.repeat(64 * 1024 + 1)]) {
    assert.equal(bridge.savePresentationState(value), false);
  }
  assert.equal(writes, 0);
});

test('growth snapshots use text and expose precise mastery progress without executable markup', () => {
  const status = { dataset: {}, textContent: '' };
  const attributes = new Map();
  const progress = { setAttribute: (name, value) => attributes.set(name, value) };
  const bridge = host({}, { getElementById: id => id === 'growth-status' ? status : progress });
  bridge.growthStatus(JSON.stringify({ level: 4, mastered: 5, total: 20, save_ok: true, error: '<script>bad()</script>' }));
  assert.equal(status.textContent, 'Lv4. 5 of 20 words mastered.');
  assert.equal(attributes.get('aria-valuenow'), '25');
  assert.equal(JSON.parse(status.dataset.snapshot).error, '<script>bad()</script>');
  bridge.growthStatus(JSON.stringify({ level: 12, mastered: 20, total: 20, completed: true, save_ok: false }));
  assert.match(status.textContent, /^Lv12\+.*mastered the final level.*waiting to be saved/);
  const before = status.dataset.snapshot;
  for (const invalid of ['oops', '[]', '{"level":99,"mastered":0,"total":1}', '{"level":3,"mastered":8,"total":1}']) {
    bridge.growthStatus(invalid);
    assert.equal(status.dataset.snapshot, before);
  }
});

test('retired identity and room interfaces are absent while the old theme is only read for migration', () => {
  for (const method of ['leaderboardState', 'saveLeaderboardState', 'leaderboardStatus', 'playroomState', 'savePlayroomState', 'favoriteReward', 'connectVirtualKeyboardNavigation']) {
    assert.doesNotMatch(shell, new RegExp(`\\b${method}\\(`));
  }
  assert.match(shell, /loadingPreferences\.preferred_theme \|\| \(localStorage\.getItem\('wordBuddies\.playroom'\)/);
  assert.doesNotMatch(shell, /setItem\('wordBuddies\.(?:playroom|leaderboards|favoriteReward)'/);
  assert.match(shell, /<title>Grow with Pip<\/title>/);
});
