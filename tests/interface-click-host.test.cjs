const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const shell = fs.readFileSync(path.resolve(__dirname, '../web/shell.html'), 'utf8');
const source = shell.match(/      function createInterfaceClickSound\(\) \{[\s\S]*?\n      \}/)?.[0];
const routing = shell.match(/      function installInterfaceClickFeedback\(sound\) \{[\s\S]*?\n      \}/)?.[0];
assert.ok(source && routing, 'The maintained host exposes its isolated audio lifecycle and activation routing.');

function eventTarget() {
  const listeners = new Map();
  return {
    addEventListener(type, callback) {
      if (!listeners.has(type)) listeners.set(type, new Set());
      listeners.get(type).add(callback);
    },
    removeEventListener(type, callback) { listeners.get(type)?.delete(callback); },
    emit(type, value) { for (const callback of [...(listeners.get(type) || [])]) callback(value); }
  };
}

function fixture({ muted = false, available = true } = {}) {
  const document = Object.assign(eventTarget(), { hidden: false });
  const timers = new Map();
  let timerId = 0;
  const window = Object.assign(eventTarget(), {
    setTimeout(callback) { timers.set(++timerId, callback); return timerId; },
    clearTimeout(id) { timers.delete(id); }
  });
  const players = [], requests = [];
  class Audio {
    constructor(uri) {
      Object.assign(this, eventTarget(), { src: uri, currentTime: 0, paused: true, playbackRate: 1 });
      players.push(this);
    }
    play() {
      this.paused = false;
      return new Promise((resolve, reject) => requests.push({
        resolve: () => { this.paused = false; resolve(); }, reject
      }));
    }
    pause() { this.paused = true; }
  }
  if (available) window.Audio = Audio;
  const sound = vm.runInNewContext(`(${source})()`, { window, document, Audio,
    loadingPreferences: { muted } });
  const flush = async () => { await Promise.resolve(); await Promise.resolve(); };
  return { document, window, timers, players, requests, sound, flush };
}

test('interface clicks honor saved mute and never replay automatically when unmuted or shown', async () => {
  const f = fixture({ muted: true });
  assert.equal(await f.sound.play(true), false);
  assert.equal(f.requests.length, 0);
  f.sound.setMuted(false);
  f.document.emit('visibilitychange');
  assert.equal(f.requests.length, 0);
  const done = f.sound.play(true);
  assert.equal(f.requests.length, 1);
  f.requests[0].resolve();
  f.players[0].emit('ended');
  assert.equal(await done, true);
  assert.equal(f.players[0].volume, .48);
  assert.equal(f.players[0].playbackRate, 1);
});

test('untrusted, background and unavailable-audio activations remain silent without blocking actions', async () => {
  const f = fixture();
  assert.equal(await f.sound.play(false), false);
  f.document.hidden = true;
  assert.equal(await f.sound.play(true), false);
  assert.equal(f.requests.length, 0);
  assert.equal(await fixture({ available: false }).sound.play(true), false);
});

test('hiding the page stops and rewinds a click, including a late browser play promise', async () => {
  const f = fixture();
  const done = f.sound.play(true);
  f.players[0].currentTime = .04;
  f.document.hidden = true;
  f.document.emit('visibilitychange');
  assert.equal(await done, false);
  assert.equal(f.players[0].paused, true);
  assert.equal(f.players[0].currentTime, 0);
  f.requests[0].resolve();
  await f.flush();
  assert.equal(f.players[0].paused, true, 'A stale browser resume is immediately silenced.');
  f.document.hidden = false;
  f.document.emit('visibilitychange');
  assert.equal(f.requests.length, 1);
});

test('rapid interface clicks reuse one player without a stale promise canceling the newer cue', async () => {
  const f = fixture();
  const first = f.sound.play(true), second = f.sound.play(true);
  assert.equal(await first, false);
  assert.equal(f.players.length, 1);
  assert.equal(f.requests.length, 2);
  f.requests[0].resolve();
  await f.flush();
  assert.equal(f.players[0].paused, false);
  f.requests[1].resolve();
  f.players[0].emit('ended');
  assert.equal(await second, true);
  assert.equal(f.timers.size, 0);
});

test('mute and silent diagnostic mix stop pending clicks without stale automatic restart', async () => {
  for (const silence of [sound => sound.setMuted(true), sound => sound.setMix(0)]) {
    const f = fixture();
    const done = f.sound.play(true);
    silence(f.sound);
    assert.equal(await done, false);
    f.requests[0].resolve();
    await f.flush();
    assert.equal(f.players[0].paused, true);
    assert.equal(await f.sound.play(true), false);
    assert.equal(f.requests.length, 1);
  }
});

test('rejected and never-settling media backends release retry actions and allow a later gesture', async () => {
  const f = fixture();
  const rejected = f.sound.play(true);
  f.requests[0].reject(new Error('Autoplay blocked'));
  assert.equal(await rejected, false);
  assert.equal(f.timers.size, 0);
  const pending = f.sound.play(true);
  for (const callback of [...f.timers.values()]) callback();
  assert.equal(await pending, false);
  assert.equal(f.players[0].paused, true);
  f.requests[1].resolve();
  await f.flush();
  assert.equal(f.players[0].paused, true);
});

test('one click listener covers native button activation while excluding play toys and canceled controls', () => {
  const document = eventTarget();
  let plays = 0;
  vm.runInNewContext(`(${routing})(sound)`, { document, sound: { play() { plays++; } } });
  const click = ({ id = 'speech-debug-close', disabled = false, hidden = false, visible = true,
    isTrusted = true, defaultPrevented = false, matched = true } = {}) => {
    const control = { id, matches: () => disabled, closest: () => hidden,
      getClientRects: () => visible ? [{}] : [] };
    document.emit('click', { isTrusted, defaultPrevented, target: { closest: () => matched ? control : null } });
  };
  for (const options of [{ id: 'loading-duck' }, { id: 'loading-toy' }, { id: 'enter-game' }, { id: 'retry' },
    { disabled: true }, { hidden: true }, { visible: false }, { isTrusted: false }, { defaultPrevented: true }, { matched: false }]) click(options);
  assert.equal(plays, 0);
  for (const id of ['loading-theme', 'speech-debug-close', 'local-speech-install', 'checkbox', 'summary']) click({ id });
  assert.equal(plays, 5, 'Each accepted native click calls the sound exactly once.');
  document.emit('pointerdown', {});
  document.emit('keydown', { key: 'Enter' });
  document.emit('focus', {});
  assert.equal(plays, 5, 'Pointer and keyboard down, focus, and hover cannot create a second cue.');
});
