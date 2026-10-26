const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const shell = fs.readFileSync(path.join(__dirname, '..', 'web', 'shell.html'), 'utf8').replace(/\r\n/g, '\n');
const methods = ['jellyCampaignState', 'saveJellyCampaignState'].map(name => {
  const source = shell.match(new RegExp(`        ${name}\\([^)]*\\) \\{[\\s\\S]*?\\n        \\}`))?.[0];
  assert.ok(source, `The actual shell exposes ${name}`);
  return source;
});
const key = 'growWithPip.jellyCampaign.v1';
function host(storage) {
  return vm.runInNewContext(`({${methods.join(',')}})`, { localStorage: storage, TextEncoder });
}

test('campaign saves retain an isolated namespace and reject stale cross-tab snapshots', () => {
  const records = new Map([['growWithPip.growth.v1', 'mastery'], ['growWithPip.coinWallet.v1', 'coins']]);
  const storage = { getItem: key => records.get(key) ?? null, setItem: (key, value) => records.set(key, value) };
  const bridge = host(storage);
  assert.equal(bridge.jellyCampaignState(), null);
  assert.equal(bridge.saveJellyCampaignState('stage-one-recipe', null), true);
  assert.equal(bridge.saveJellyCampaignState('stale-clear', null), false);
  assert.equal(bridge.saveJellyCampaignState('three-star-clear', 'stage-one-recipe'), true);
  assert.equal(host(storage).jellyCampaignState(), 'three-star-clear');
  assert.equal(records.get('growWithPip.growth.v1'), 'mastery');
  assert.equal(records.get('growWithPip.coinWallet.v1'), 'coins');
  assert.equal(records.size, 3);
});

test('invalid, multibyte oversized and silently dropped campaign writes never report success', () => {
  let writes = 0;
  const dropped = host({ getItem: () => null, setItem: () => writes++ });
  for (const value of [undefined, null, false, 1, {}, [], '', '界'.repeat(700000)]) {
    assert.equal(dropped.saveJellyCampaignState(value, null), false);
  }
  assert.equal(writes, 0);
  assert.equal(dropped.saveJellyCampaignState('saved result', null), false);
  assert.equal(writes, 1);
  assert.equal(dropped.saveJellyCampaignState('saved result', false), false);
});

test('blocked campaign storage remains an explicit failure and can recover without resetting a saved frontier', () => {
  let blocked = true;
  let saved = 'previous progress';
  const bridge = host({
    getItem(name) { assert.equal(name, key); if (blocked) throw new Error('Blocked'); return saved; },
    setItem(name, value) { assert.equal(name, key); if (blocked) throw new Error('Full'); saved = value; }
  });
  assert.equal(bridge.jellyCampaignState(), false);
  assert.equal(bridge.saveJellyCampaignState('new progress', 'previous progress'), false);
  assert.equal(saved, 'previous progress');
  blocked = false;
  assert.equal(bridge.saveJellyCampaignState('new progress', 'previous progress'), true);
  assert.equal(bridge.jellyCampaignState(), 'new progress');
});
