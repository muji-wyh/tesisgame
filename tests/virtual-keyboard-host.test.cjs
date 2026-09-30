const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const shell = fs.readFileSync('web/shell.html', 'utf8').replace(/\r\n/g, '\n');
const source = shell.match(/      function connectVirtualKeyboardNavigation\(\) \{[\s\S]*?\n      \}/)?.[0];
assert.ok(source, 'The host connects keyboard navigation to the engine editors');

function fixture(change = () => {}) {
  const parent = {};
  const document = { activeElement: null };
  const forwarded = [];
  const focusOptions = [];
  function editor(tagName) {
    const listeners = new Map();
    return {
      tagName, parentElement: parent, style: { position: 'absolute', zIndex: '-1' },
      disabled: false, isConnected: true,
      addEventListener(type, handler) { listeners.set(type, handler); },
      send(type, options = {}) {
        const event = { target: this, key: '', code: '', prevented: false, stopped: false,
          preventDefault() { this.prevented = true; }, stopPropagation() { this.stopped = true; }, ...options };
        listeners.get(type)?.(event);
        return event;
      },
      listeners
    };
  }
  const input = editor('INPUT');
  const textarea = editor('TEXTAREA');
  textarea.previousElementSibling = input;
  const canvas = {
    parentElement: parent, previousElementSibling: textarea, inert: false,
    focus(options) {
      focusOptions.push(options.preventScroll);
      document.activeElement?.send?.('blur');
      document.activeElement = canvas;
    },
    dispatchEvent(event) { forwarded.push(event); }
  };
  document.activeElement = input;
  const result = { document, input, textarea, canvas, forwarded, focusOptions };
  change(result);
  vm.runInNewContext(`${source}\nconnectVirtualKeyboardNavigation();`, {
    document, canvas, KeyboardEvent: class { constructor(type, options) { this.type = type; Object.assign(this, options); } }
  });
  return result;
}

test('only the engine native-editor pair receives navigation listeners', () => {
  for (const change of [
    ({ canvas }) => { canvas.previousElementSibling = null; },
    ({ input }) => { input.tagName = 'DIV'; },
    ({ textarea }) => { textarea.style.zIndex = '1'; },
    ({ input }) => { input.parentElement = {}; }
  ]) {
    const { input, textarea } = fixture(change);
    assert.equal(input.listeners.size + textarea.listeners.size, 0);
  }
});

test('Tab, Shift+Tab and Escape return focus and forward one keydown to Godot', () => {
  for (const options of [{ key: 'Tab' }, { key: 'Tab', shiftKey: true }, { key: 'Escape' }]) {
    const { input, canvas, document, forwarded, focusOptions } = fixture();
    const event = input.send('keydown', { code: options.key, ...options });
    assert.equal(event.prevented, true);
    assert.equal(event.stopped, true);
    assert.equal(document.activeElement, canvas);
    assert.deepEqual(focusOptions, [true]);
    assert.equal(forwarded.length, 1);
    assert.equal(forwarded[0].type, 'keydown');
    assert.equal(forwarded[0].key, options.key);
    assert.equal(forwarded[0].code, options.key);
    assert.equal(forwarded[0].shiftKey, options.shiftKey);
    assert.equal(forwarded[0].bubbles, true);
  }
});

test('text, Enter, composition and browser shortcuts keep their native behavior', () => {
  for (const options of [
    { key: 'a' }, { key: 'Enter' }, { key: 'Tab', ctrlKey: true },
    { key: 'Tab', metaKey: true }, { key: 'Escape', altKey: true },
    { key: 'Escape', isComposing: true }, { key: 'Escape', keyCode: 229 }
  ]) {
    const { input, document, forwarded } = fixture();
    const event = input.send('keydown', options);
    assert.equal(event.prevented, false);
    assert.equal(event.stopped, false);
    assert.equal(document.activeElement, input);
    assert.equal(forwarded.length, 0);
  }
});

test('composition events protect candidate selection even without isComposing', () => {
  const { textarea, document, forwarded } = fixture();
  document.activeElement = textarea;
  textarea.send('compositionstart');
  assert.equal(textarea.send('keydown', { key: 'Escape' }).prevented, false);
  assert.equal(forwarded.length, 0);
  textarea.send('compositionend');
  assert.equal(textarea.send('keydown', { key: 'Escape' }).prevented, true);
  assert.equal(forwarded.length, 1);
});

test('inactive, detached, disabled or startup editors cannot redirect keyboard input', () => {
  for (const change of [
    ({ document }) => { document.activeElement = {}; },
    ({ input }) => { input.isConnected = false; },
    ({ input }) => { input.disabled = true; },
    ({ canvas }) => { canvas.inert = true; }
  ]) {
    const state = fixture();
    change(state);
    assert.equal(state.input.send('keydown', { key: 'Tab' }).prevented, false);
    assert.equal(state.forwarded.length, 0);
  }
});
