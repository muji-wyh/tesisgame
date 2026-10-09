const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const shell = fs.readFileSync(path.resolve(__dirname, '../web/shell.html'), 'utf8').replace(/\r\n/g, '\n');
const rewardKey = 'growWithPip.jellyRewards.v1';
const methods = ['phraseStatus', 'jellyStatus', 'jellyRewardState', 'saveJellyRewardState', 'jellyRewardStatus'];
const blocks = methods.map(name => {
  const block = shell.match(new RegExp(`        ${name}\\([^)]*\\) \\{[\\s\\S]*?\\n        \\}`))?.[0];
  assert.ok(block, `The host exposes ${name}`);
  return block;
});

function element(dataset = {}) {
  return {
    dataset,
    set innerHTML(_value) { assert.fail('Diagnostic snapshots must not become HTML'); },
    set outerHTML(_value) { assert.fail('Diagnostic snapshots must not replace DOM elements'); }
  };
}

function host(storage = {}, game = element(), reward = element()) {
  const canvas = { style: { touchAction: 'manipulation' } };
  const document = {
    getElementById(id) {
      if (id === 'game-status') return game;
      if (id === 'jelly-reward-status') return reward;
      assert.fail(`Unexpected status element: ${id}`);
    }
  };
  const bridge = vm.runInNewContext(`({${blocks.join(',')}})`, { localStorage: storage, document, canvas });
  return { bridge, canvas, game, reward };
}

function memoryStorage(entries = []) {
  const records = new Map(entries);
  return {
    records,
    getItem: key => records.get(key) ?? null,
    setItem: (key, value) => records.set(key, value)
  };
}

test('Jelly treasures survive a new host and remain isolated from growth, Pop, and presentation saves', () => {
  const existing = [
    ['growWithPip.growth.v1', 'learning progress'],
    ['wordBuddies.popRewards', 'pending Voice Pop chests'],
    ['wordBuddies.medalProgress', 'medals'],
    ['pipAndWords.presentation.v1', '{"muted":true}']
  ];
  const storage = memoryStorage(existing);
  assert.equal(host(storage).bridge.jellyRewardState(), null, 'A missing save is distinct from a blocked read');
  const record = '[treasure]\nversion=1\nround_id="jelly-round-one"\nchest_count=5\n';
  assert.equal(host(storage).bridge.saveJellyRewardState(record), true);
  assert.equal(host(storage).bridge.jellyRewardState(), record);
  assert.equal(storage.records.get(rewardKey), record);
  for (const [key, value] of existing) assert.equal(storage.records.get(key), value);
  assert.equal(storage.records.size, existing.length + 1);
});

test('Jelly reward writes reject invalid and oversized payloads before touching storage', () => {
  let reads = 0;
  let writes = 0;
  const { bridge } = host({
    getItem() { reads++; return null; },
    setItem() { writes++; }
  });
  for (const value of [undefined, null, false, 42, {}, [], '', 'x'.repeat(2 * 1024 * 1024 + 1)]) {
    assert.equal(bridge.saveJellyRewardState(value), false);
  }
  assert.equal(reads, 0);
  assert.equal(writes, 0);
  const boundary = 'x'.repeat(2 * 1024 * 1024);
  const storage = memoryStorage();
  assert.equal(host(storage).bridge.saveJellyRewardState(boundary), true, 'The documented size limit is inclusive');
  assert.equal(storage.records.get(rewardKey), boundary);
});

test('Jelly blocked reads and writes report failure, and a retry preserves the previous record', () => {
  let blocked = true;
  let saved = 'previous';
  const { bridge } = host({
    getItem(key) {
      assert.equal(key, rewardKey);
      if (blocked) throw new Error('Read denied');
      return saved;
    },
    setItem(key, value) {
      assert.equal(key, rewardKey);
      if (blocked) throw new Error('Storage full');
      saved = value;
    }
  });
  assert.equal(bridge.jellyRewardState(), false);
  assert.equal(bridge.saveJellyRewardState('next'), false);
  assert.equal(saved, 'previous');
  blocked = false;
  assert.equal(bridge.jellyRewardState(), 'previous');
  assert.equal(bridge.saveJellyRewardState('next'), true);
  assert.equal(bridge.jellyRewardState(), 'next');
});

test('Jelly rewards cannot claim success after silently dropped or changed writes', () => {
  const dropped = host({ getItem: () => 'previous', setItem() {} }).bridge;
  assert.equal(dropped.saveJellyRewardState('next'), false);
  assert.equal(dropped.jellyRewardState(), 'previous');
  let saved = 'previous';
  const changed = host({ getItem: () => saved, setItem(_key, value) { saved = `${value} changed`; } }).bridge;
  assert.equal(changed.saveJellyRewardState('next'), false);
  assert.equal(saved, 'next changed');
});

test('Jelly reward readback exceptions cannot turn a completed write into reported success', () => {
  let saved = 'previous';
  let rejectRead = true;
  let writes = 0;
  const { bridge } = host({
    getItem(key) {
      assert.equal(key, rewardKey);
      if (rejectRead) throw new Error('Verification read denied');
      return saved;
    },
    setItem(key, value) { assert.equal(key, rewardKey); saved = value; writes++; }
  });
  assert.equal(bridge.saveJellyRewardState('next'), false);
  assert.equal(saved, 'next', 'A failed verification must remain explicit even when the write reached storage');
  rejectRead = false;
  assert.equal(bridge.jellyRewardState(), 'next');
  assert.equal(bridge.saveJellyRewardState('next'), true);
  assert.equal(writes, 2);
});

test('Jelly diagnostics preserve rich snapshots as inert JSON in separate status elements', () => {
  const { bridge, game, reward } = host();
  const markup = '<img src=x onerror="globalThis.executed=true"><script>throw Error("executed")</script>';
  const gameSnapshot = { visible: true, phase: 'playing', round_id: markup, score: 125, tiles: [{ word: 'apple' }] };
  const rewardSnapshot = { visible: true, chest_count: 5, opened_count: 2, round_id: markup };
  bridge.jellyStatus(JSON.stringify(gameSnapshot));
  bridge.jellyRewardStatus(JSON.stringify(rewardSnapshot));
  assert.deepEqual(JSON.parse(game.dataset.jelly), gameSnapshot);
  assert.deepEqual(JSON.parse(reward.dataset.snapshot), rewardSnapshot);
  assert.equal(game.dataset.snapshot, undefined);
  assert.equal(reward.dataset.jelly, undefined);
  assert.match(game.dataset.jelly, /<script>/);
});

test('Malformed or primitive Jelly diagnostics retain the previous snapshots and touch policy', () => {
  const { bridge, game, reward, canvas } = host();
  bridge.jellyStatus('{"visible":true,"phase":"playing"}');
  bridge.jellyRewardStatus('{"visible":false,"chest_count":2}');
  const beforeGame = game.dataset.jelly;
  const beforeReward = reward.dataset.snapshot;
  for (const invalid of [undefined, '', 'not JSON', '{', 'null', '[]', '[{}]', 'false', '42', '"text"']) {
    assert.doesNotThrow(() => bridge.jellyStatus(invalid));
    assert.doesNotThrow(() => bridge.jellyRewardStatus(invalid));
    assert.equal(game.dataset.jelly, beforeGame);
    assert.equal(reward.dataset.snapshot, beforeReward);
    assert.equal(canvas.style.touchAction, 'pinch-zoom');
  }
});

test('Jelly and Phrase preserve drag touch behavior while either surface is visible', () => {
  for (const first of ['jelly', 'phrase']) {
    const { bridge, canvas } = host();
    const set = {
      jelly: visible => bridge.jellyStatus(JSON.stringify({ visible })),
      phrase: visible => bridge.phraseStatus(JSON.stringify({ visible, options: [] }))
    };
    const second = first === 'jelly' ? 'phrase' : 'jelly';
    set[first](true);
    assert.equal(canvas.style.touchAction, 'pinch-zoom', `${first} supports dragging before the other mode has published`);
    set[second](false);
    assert.equal(canvas.style.touchAction, 'pinch-zoom', `A hidden ${second} must not disable ${first} dragging`);
    set[second](true);
    set[first](false);
    assert.equal(canvas.style.touchAction, 'pinch-zoom', `Hiding ${first} must retain ${second} dragging`);
    set[second](false);
    assert.equal(canvas.style.touchAction, 'manipulation', 'Normal touch behavior resumes when both surfaces are hidden');
  }
});

test('Reward snapshots and malformed Phrase updates cannot change an active Jelly touch policy', () => {
  const { bridge, canvas, game } = host();
  bridge.jellyStatus('{"visible":true}');
  bridge.phraseStatus('{"visible":false,"options":[]}');
  const beforePhrase = game.dataset.phrase;
  for (const invalid of ['not JSON', 'null', '[]', '{"visible":false}', '{"visible":false,"options":{}}']) {
    bridge.phraseStatus(invalid);
    assert.equal(game.dataset.phrase, beforePhrase);
    assert.equal(canvas.style.touchAction, 'pinch-zoom');
  }
  bridge.jellyRewardStatus('{"visible":true,"chest_count":5}');
  assert.equal(canvas.style.touchAction, 'pinch-zoom');
  bridge.jellyStatus('{"visible":false}');
  assert.equal(canvas.style.touchAction, 'manipulation', 'Treasure diagnostics do not keep the hidden game in drag mode');
});
