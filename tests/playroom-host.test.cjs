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

function recoveryFixture() {
  const block = shell.match(/      function createGameAudioRecovery\(\) \{[\s\S]*?\n      \}/)?.[0];
  assert.ok(block, 'The shell recovers the engine context independently from loading-page sounds');
  function target() {
    const events = new Map();
    return {
      addEventListener(type, callback) { const handlers = events.get(type) || []; handlers.push(callback); events.set(type, handlers); },
      dispatch(type, event = {}) { for (const callback of events.get(type) || []) callback(event); }
    };
  }
  const document = Object.assign(target(), { hidden: false });
  const window = target();
  const recovery = vm.runInNewContext(`(${block})()`, { document, window });
  return { document, window, recovery };
}

test('engine playback unlocks on entry and recovers from background without restarting audio sources', async () => {
  const f = recoveryFixture();
  let resumes = 0;
  const context = { state: 'suspended', resume() { resumes++; this.state = 'running'; return Promise.resolve(); } };
  f.recovery.attach(context);
  f.document.dispatch('pointerup', { isTrusted: true });
  f.window.dispatch('pageshow');
  assert.equal(resumes, 0, 'Loading-page interactions do not start the paused game audio');
  f.recovery.enter();
  assert.equal(resumes, 1, 'The deliberate Enter game gesture unlocks the existing engine context');
  f.document.hidden = true;
  context.state = 'suspended';
  f.document.dispatch('visibilitychange');
  f.document.dispatch('pointerup', { isTrusted: true });
  assert.equal(resumes, 1, 'A hidden page never resumes its playback context');
  f.document.hidden = false;
  f.document.dispatch('visibilitychange');
  f.window.dispatch('pageshow');
  assert.equal(resumes, 2, 'Returning resumes once, and duplicate lifecycle notifications leave running audio alone');
  context.state = 'interrupted';
  f.document.dispatch('pointerup', { isTrusted: false });
  assert.equal(resumes, 2, 'Synthetic input cannot unlock audio');
  f.document.dispatch('keydown', { isTrusted: true });
  assert.equal(resumes, 3, 'A real keyboard gesture also recovers interrupted audio');
  await Promise.resolve();
});

test('blocked or pending audio resume attempts remain retryable through the next trusted gesture', async () => {
  const f = recoveryFixture();
  let resumes = 0;
  const context = { state: 'suspended', resume() { resumes++; return Promise.reject(new Error('Gesture required')); } };
  f.recovery.attach(context);
  f.recovery.enter();
  await new Promise(resolve => setImmediate(resolve));
  context.resume = () => { resumes++; return new Promise(() => {}); };
  f.document.dispatch('pointerup', { isTrusted: true });
  context.resume = () => { resumes++; context.state = 'running'; return Promise.resolve(); };
  f.document.dispatch('pointerup', { isTrusted: true });
  assert.equal(resumes, 3, 'Neither rejection nor an unresolved autoplay promise prevents a later successful gesture');
  f.document.dispatch('keydown', { isTrusted: true });
  assert.equal(resumes, 3);
});

test('closed contexts and stopped games never restart through old lifecycle listeners', () => {
  const f = recoveryFixture();
  let resumes = 0;
  const context = { state: 'closed', resume() { resumes++; throw new Error('Closed context'); } };
  f.recovery.attach(context);
  f.recovery.enter();
  f.window.dispatch('pageshow');
  assert.equal(resumes, 0);
  context.state = 'suspended';
  f.recovery.stop();
  f.document.dispatch('pointerup', { isTrusted: true });
  f.document.dispatch('visibilitychange');
  assert.equal(resumes, 0, 'Failure cleanup removes the engine context and its playback intent');
});
