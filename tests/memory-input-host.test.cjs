const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const shell = fs.readFileSync(path.join(__dirname, '..', 'web', 'shell.html'), 'utf8');
const source = shell.match(/        observe\(onHidden, onMotion, onVisible, onInputCanceled, onPointerReleased\) \{[\s\S]*?\n        \}/)?.[0];
assert.ok(source, 'The browser shell contains the input and lifecycle observer');

function eventTarget() {
  const listeners = new Map();
  return {
    listeners,
    addEventListener(type, callback, options) {
      if (!listeners.has(type)) listeners.set(type, []);
      listeners.get(type).push({ callback, options });
    },
    dispatch(type, event = {}) {
      for (const { callback } of listeners.get(type) || []) callback(event);
    }
  };
}

function fixture({ hidden = false, reducedMotion = false } = {}) {
  const window = eventTarget(), canvas = eventTarget();
  const document = Object.assign(eventTarget(), { hidden });
  const motion = Object.assign(eventTarget(), { matches: reducedMotion });
  const calls = { hidden: 0, visible: 0, canceled: 0, motion: [], released: [] };
  const host = vm.runInNewContext(`({${source}})`, { window, canvas, document, motion });
  host.observe(
    () => calls.hidden++,
    value => calls.motion.push(value),
    () => calls.visible++,
    () => calls.canceled++,
    (...args) => calls.released.push(args)
  );
  return { window, canvas, document, motion, calls };
}

test('trusted touch releases forward each changed finger with signed Godot IDs and a touch discriminator', () => {
  const f = fixture();
  f.window.dispatch('touchend', {
    isTrusted: true,
    changedTouches: [-1, -2, 0, 2147483648, 4294967295].map(identifier => ({ identifier })),
    touches: [{ identifier: 42 }]
  });
  assert.deepEqual(f.calls.released, [
    [-1, true], [-2, true], [0, true], [-2147483648, true], [-1, true]
  ], 'Only lifted fingers are forwarded, including negative IDs and unsigned i32 representations');
  f.window.dispatch('mouseup', { isTrusted: true, button: 0 });
  assert.deepEqual(f.calls.released.at(-1), [-1, false],
    'A left mouse release remains distinct from a touch whose signed ID is -1');
});

test('untrusted releases and unrelated mouse buttons cannot reach the pointer release callback', () => {
  const f = fixture();
  for (const isTrusted of [false, undefined]) {
    f.window.dispatch('touchend', { isTrusted, changedTouches: [{ identifier: -1 }] });
    f.window.dispatch('mouseup', { isTrusted, button: 0 });
  }
  for (const button of [1, 2, 3, 4]) f.window.dispatch('mouseup', { isTrusted: true, button });
  f.window.dispatch('mousedown', { isTrusted: true, button: 0 });
  f.window.dispatch('pointerup', { isTrusted: true, button: 0, pointerId: -1 });
  assert.deepEqual(f.calls.released, []);
  f.window.dispatch('touchend', { isTrusted: true, changedTouches: [], touches: [{ identifier: 7 }] });
  assert.deepEqual(f.calls.released, [], 'Still-held fingers are not inferred to have ended');
});

test('release fallbacks use window capture and leave the canvas input event available', () => {
  const f = fixture();
  const fail = () => assert.fail('The release observer must not consume native input');
  for (const type of ['touchend', 'mouseup']) {
    const listeners = f.window.listeners.get(type);
    assert.equal(listeners.length, 1);
    assert.equal(listeners[0].options.capture, true,
      `${type} is observed before a canvas handler can consume it`);
    f.window.dispatch(type, {
      isTrusted: true, button: 0, changedTouches: [{ identifier: -2 }],
      preventDefault: fail, stopPropagation: fail, stopImmediatePropagation: fail
    });
  }
  assert.deepEqual(f.calls.released, [[-2, true], [-1, false]]);
});

test('pointer release changes preserve cancellation, visibility, page, and motion callbacks', () => {
  const f = fixture({ reducedMotion: true });
  assert.deepEqual(f.calls.motion, [true]);
  assert.equal(f.calls.hidden, 0);
  assert.equal(f.calls.visible, 0);
  for (const type of ['touchcancel', 'pointercancel']) {
    assert.equal(f.canvas.listeners.get(type)[0].options.capture, true);
    f.canvas.dispatch(type);
  }
  f.window.dispatch('blur');
  assert.equal(f.calls.canceled, 3);
  f.document.hidden = true;
  f.document.dispatch('visibilitychange');
  f.window.dispatch('pagehide');
  f.window.dispatch('pageshow');
  assert.equal(f.calls.hidden, 2);
  assert.equal(f.calls.visible, 0, 'A hidden restored page stays paused');
  f.document.hidden = false;
  f.document.dispatch('visibilitychange');
  f.window.dispatch('pageshow');
  assert.equal(f.calls.visible, 2);
  f.motion.dispatch('change', { matches: false });
  assert.deepEqual(f.calls.motion, [true, false]);
  assert.deepEqual(f.calls.released, [], 'Lifecycle cancellation is not reclassified as a pointer release');
  const initiallyHidden = fixture({ hidden: true });
  assert.equal(initiallyHidden.calls.hidden, 1);
  assert.deepEqual(initiallyHidden.calls.motion, [false]);
});
