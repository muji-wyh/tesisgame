const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const shell = fs.readFileSync('web/shell.html', 'utf8').replace(/\r\n/g, '\n');
const key = 'wordBuddies.leaderboards';

function bridge(storage, document = {}) {
  const block = shell.match(/        leaderboardState\(\) \{[\s\S]*?\n        \},\n        saveLeaderboardState\(text\) \{[\s\S]*?\n        \},\n        leaderboardStatus\(text\) \{[\s\S]*?\n        \}/)?.[0];
  assert.ok(block, 'The host exposes isolated local leaderboard storage and diagnostics');
  const context = { localStorage: storage, document };
  Object.defineProperty(context, 'injected', { set() { assert.fail('Player data cannot execute as JavaScript'); } });
  return vm.runInNewContext(`({${block}})`, context);
}

function localStorageFixture() {
  const values = new Map([
    ['wordBuddies.playroom', 'existing room'],
    ['wordBuddies.medalProgress', 'existing progress'],
    ['wordBuddies.favoriteReward', 'space-1']
  ]);
  const calls = [];
  const storage = {
    getItem(name) { calls.push(['read', name]); return values.get(name) ?? null; },
    setItem(name, value) { calls.push(['write', name]); values.set(name, value); }
  };
  return { values, calls, storage };
}

test('reading an empty or existing local leaderboard does not write storage', () => {
  const fixture = localStorageFixture();
  const host = bridge(fixture.storage);
  assert.equal(host.leaderboardState(), null);
  fixture.values.set(key, '[leaderboard]\nversion=1\n');
  assert.equal(host.leaderboardState(), '[leaderboard]\nversion=1\n');
  assert.deepEqual(fixture.calls, [['read', key], ['read', key]]);
});

test('a saved leaderboard is immediately available on reload without changing other game saves', () => {
  const fixture = localStorageFixture();
  const saved = '[leaderboard]\nversion=1\nprofiles=[{"id":"player-a","name":"Zoë","avatar":"fox"}]\nbests={"pop":{"player-a":{"hits":12}},"match":{},"memory":{}}\nreceipts=[]\n';
  assert.equal(bridge(fixture.storage).saveLeaderboardState(saved), true);
  assert.equal(bridge(fixture.storage).leaderboardState(), saved);
  assert.equal(fixture.values.get('wordBuddies.playroom'), 'existing room');
  assert.equal(fixture.values.get('wordBuddies.medalProgress'), 'existing progress');
  assert.equal(fixture.values.get('wordBuddies.favoriteReward'), 'space-1');
  assert.deepEqual(fixture.calls, [['write', key], ['read', key]]);
});

test('blocked reads remain explicit and never attempt a replacement write', () => {
  let writes = 0;
  const host = bridge({
    getItem() { throw new Error('Storage access denied'); },
    setItem() { writes++; }
  });
  assert.equal(host.leaderboardState(), false);
  assert.equal(writes, 0);
});

test('quota failures preserve the prior record and a later deliberate save can retry', () => {
  let value = 'prior complete record';
  let blocked = true;
  const host = bridge({
    getItem() { return value; },
    setItem(name, text) {
      assert.equal(name, key);
      if (blocked) throw new Error('Quota exceeded');
      value = text;
    }
  });
  assert.equal(host.saveLeaderboardState('new complete record'), false);
  assert.equal(host.leaderboardState(), 'prior complete record');
  blocked = false;
  assert.equal(host.saveLeaderboardState('new complete record'), true);
  assert.equal(host.leaderboardState(), 'new complete record');
});

function diagnosticsFixture() {
  const element = { dataset: { snapshot: '{}' } };
  for (const property of ['innerHTML', 'outerHTML', 'textContent']) {
    Object.defineProperty(element, property, {
      set() { assert.fail(`Diagnostics must not render player data through ${property}`); }
    });
  }
  const fixture = localStorageFixture();
  const host = bridge(fixture.storage, {
    getElementById(id) {
      assert.equal(id, 'leaderboard-status');
      return element;
    }
  });
  return { host, element, fixture };
}

test('player names remain inert JSON data in read-only diagnostics', () => {
  const { host, element, fixture } = diagnosticsFixture();
  const snapshot = {
    view: 'boards',
    rows: [{ player_id: 'player-a', name: '"><svg onload="globalThis.injected=true"></svg>', avatar: 'duck', rank: 1 }]
  };
  host.leaderboardStatus(JSON.stringify(snapshot));
  assert.deepEqual(JSON.parse(element.dataset.snapshot), snapshot);
  assert.deepEqual(fixture.calls, [], 'Publishing diagnostics never reads or writes saved scores');
});

test('malformed or non-object diagnostics leave the last valid snapshot intact', () => {
  const { host, element, fixture } = diagnosticsFixture();
  host.leaderboardStatus('{"mode":"pop","rows":[]}');
  const previous = element.dataset.snapshot;
  for (const text of ['', '{broken', 'null', 'true', '42', '"text"', '[]']) {
    host.leaderboardStatus(text);
    assert.equal(element.dataset.snapshot, previous);
  }
  assert.deepEqual(fixture.calls, []);
});
