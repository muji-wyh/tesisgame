const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const shell = fs.readFileSync(path.join(__dirname, '..', 'web', 'shell.html'), 'utf8');
const source = shell.match(/      function createLocalSpeechPreparation\(\{ onChange, onDiagnostic \} = \{\}\) \{[\s\S]*?\n      \}/)?.[0];
assert.ok(source, 'The browser shell exposes an isolated local preparation helper');

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

function fixture({ search = '?speechLocal=1', secure = true, api = 'standard',
  supportsLocal = true, writableLocal = true, startsSupported = true,
  availabilitySupported = true, installationSupported = true,
  available = () => Promise.resolve('available'), install = () => Promise.resolve(true),
  activation = true, constructorFails = false } = {}) {
  const nodes = [];
  function element(tagName) {
    const handlers = {};
    const node = {
      tagName, style: {}, children: [], attributes: {}, hidden: false, disabled: false,
      textContent: '', checked: false, parent: null,
      append(...children) {
        this.children.push(...children);
        for (const child of children) child.parent = this;
      },
      remove() {
        if (this.parent) this.parent.children = this.parent.children.filter(child => child !== this);
        this.parent = null;
      },
      addEventListener(type, callback) { (handlers[type] ||= []).push(callback); },
      setAttribute(name, value) { this.attributes[name] = String(value); },
      dispatch(type, details = {}) {
        const event = { target: this, stopPropagation() {}, ...details };
        for (const callback of handlers[type] || []) callback(event);
      },
      get listenerCount() { return Object.values(handlers).reduce((total, callbacks) => total + callbacks.length, 0); },
      click() { if (!this.disabled) this.dispatch('click'); }
    };
    nodes.push(node);
    return node;
  }
  const document = { body: element('body'), createElement: element };
  const calls = { available: [], install: [], probes: 0, starts: 0, aborts: 0 };
  class Recognition {
    constructor() {
      calls.probes++;
      if (constructorFails) throw new Error('Unavailable engine');
      if (supportsLocal) {
        let value = false;
        Object.defineProperty(this, 'processLocally', {
          get() { return value; },
          set(next) { if (writableLocal) value = next; }
        });
      }
    }
    abort() { calls.aborts++; }
  }
  if (startsSupported) Recognition.prototype.start = function () { calls.starts++; };
  if (availabilitySupported) Recognition.available = options => {
    calls.available.push(JSON.parse(JSON.stringify(options)));
    return available();
  };
  if (installationSupported) Recognition.install = options => {
    calls.install.push(JSON.parse(JSON.stringify(options)));
    return install();
  };
  const window = { isSecureContext: secure, location: { search },
    navigator: { userActivation: { isActive: activation } } };
  if (api === 'standard') window.SpeechRecognition = Recognition;
  if (api === 'prefixed') window.webkitSpeechRecognition = Recognition;
  const changes = [], diagnostics = [];
  const factory = vm.runInNewContext(`(${source})`, { window, document, URLSearchParams });
  const helper = factory({
    onChange: state => changes.push(JSON.parse(JSON.stringify(state))),
    onDiagnostic: event => diagnostics.push(JSON.parse(JSON.stringify(event)))
  });
  return { helper, window, document, calls, changes, diagnostics, nodes,
    panel: nodes.find(node => node.id === 'local-speech-experiment'),
    action: nodes.find(node => node.tagName === 'button'),
    checkbox: nodes.find(node => node.tagName === 'input') };
}

test('ordinary URLs create no experiment UI, probes, downloads, or audio capture', async () => {
  for (const search of ['', '?speechLocal=0', '?speechLocal=true']) {
    const f = fixture({ search });
    f.helper.setEnabled(true);
    f.helper.setVisible(true);
    await f.helper.prepare();
    await f.helper.install();
    assert.equal(f.document.body.children.length, 0);
    assert.equal(f.document.body.listenerCount, 0, 'Ordinary game gestures remain untouched');
    assert.equal(f.helper.getState().experimentEnabled, false);
    assert.equal(f.helper.getState().enabled, false);
    assert.equal(f.helper.modeForNewRound('one'), 'browser');
    assert.deepEqual(f.calls, { available: [], install: [], probes: 0, starts: 0, aborts: 0 });
  }
});

test('experiment keyboard and pointer events do not reach the game or block native activation', () => {
  const f = fixture();
  let stopped = 0, prevented = 0;
  for (const type of ['keydown', 'keyup', 'pointerdown', 'pointerup', 'mousedown', 'mouseup',
    'click', 'touchstart', 'touchend']) {
    const before = stopped;
    f.panel.dispatch(type, { key: ' ', stopPropagation() { stopped++; }, preventDefault() { prevented++; } });
    assert.equal(stopped, before + 1, `${type} is kept out of the game input path`);
  }
  assert.equal(prevented, 0, 'Checkboxes, buttons, and details retain their browser gestures');
});

test('opt-in only exposes accessible controls and waits for a manual check', async () => {
  const f = fixture();
  assert.equal(f.helper.getState().enabled, true);
  assert.equal(f.helper.getState().ready, false);
  assert.equal(f.panel.hidden, true);
  assert.equal(f.checkbox.parent.tagName, 'label');
  assert.equal(f.checkbox.type, 'checkbox');
  assert.equal(f.action.type, 'button');
  assert.equal(f.calls.available.length, 0);
  f.helper.setVisible(true);
  assert.equal(f.panel.hidden, false);
  f.action.click();
  await f.helper.prepare();
  assert.equal(f.helper.getState().status, 'ready');
  assert.equal(f.calls.starts, 0, 'Preparing the browser model never starts the microphone');
  assert.equal(f.calls.aborts, 0);
  assert.equal(f.calls.install.length, 0);
});

test('availability is checked explicitly for local English and does not infer readiness from API presence', async () => {
  const f = fixture({ api: 'prefixed', available: () => Promise.resolve('downloadable') });
  assert.equal(f.helper.modeForNewRound(1), 'browser');
  await f.helper.prepare();
  assert.deepEqual(f.calls.available, [{ langs: ['en-US'], processLocally: true }]);
  assert.equal(f.helper.getState().capable, true);
  assert.equal(f.helper.getState().status, 'downloadable');
  assert.equal(f.helper.getState().ready, false);
  assert.equal(f.action.textContent, 'Download English');
  assert.equal(f.calls.install.length, 0);
});

test('unsupported or nonfunctional APIs preserve browser mode without starting downloads', async () => {
  for (const options of [{ secure: false }, { api: 'none' }, { supportsLocal: false },
    { writableLocal: false }, { startsSupported: false }, { availabilitySupported: false },
    { installationSupported: false }, { constructorFails: true }]) {
    const f = fixture(options);
    await f.helper.prepare();
    assert.equal(f.helper.getState().status, 'unsupported');
    assert.equal(f.helper.getState().capable, false);
    assert.equal(f.helper.getState().ready, false);
    assert.equal(f.helper.modeForNewRound(1), 'browser');
    assert.equal(f.calls.available.length, 0);
    assert.equal(f.calls.install.length, 0);
  }
});

test('browser downloading, unavailable, and invalid replies cannot mark ready', async () => {
  for (const [reply, expected] of [['downloading', 'downloading'], ['unavailable', 'unsupported'],
    ['unexpected', 'error'], [true, 'error']]) {
    const f = fixture({ available: () => Promise.resolve(reply) });
    await f.helper.prepare();
    assert.equal(f.helper.getState().status, expected);
    assert.equal(f.helper.getState().ready, false);
    assert.equal(f.helper.modeForNewRound(1), 'browser');
    assert.equal(f.action.disabled, false, 'An external download can be checked again');
  }
});

test('download starts synchronously from its button and readiness is rechecked afterward', async () => {
  const downloading = deferred();
  let availability = 'downloadable';
  const f = fixture({ available: () => Promise.resolve(availability), install: () => downloading.promise });
  await f.helper.prepare();
  f.action.click();
  assert.equal(f.calls.install.length, 1, 'No await consumes the download button activation');
  assert.deepEqual(f.calls.install[0], { langs: ['en-US'], processLocally: true });
  assert.equal(f.helper.getState().status, 'downloading');
  assert.equal(f.action.disabled, true);
  assert.equal(f.helper.getState().ready, false);
  const completion = f.helper.install();
  availability = 'available';
  downloading.resolve(true);
  await completion;
  assert.equal(f.calls.available.length, 2);
  assert.equal(f.calls.install.length, 1);
  assert.equal(f.helper.getState().status, 'ready');
  assert.equal(f.helper.getState().ready, true);
});

test('a successful install still needs available status before local mode can start', async () => {
  const f = fixture({ available: () => Promise.resolve('downloading') });
  await f.helper.install();
  assert.equal(f.calls.install.length, 1);
  assert.equal(f.calls.available.length, 1);
  assert.equal(f.helper.getState().status, 'downloading');
  assert.equal(f.helper.getState().ready, false);
  assert.equal(f.helper.modeForNewRound('one'), 'browser');
});

test('installation failure is retryable and never marks ready', async () => {
  let succeeds = false;
  const f = fixture({ install: () => Promise.resolve(succeeds) });
  await f.helper.install();
  assert.equal(f.helper.getState().status, 'error');
  assert.equal(f.helper.getState().error, 'installation-failed');
  assert.equal(f.calls.available.length, 0);
  assert.equal(f.helper.getState().ready, false);
  succeeds = true;
  await f.helper.install();
  assert.equal(f.helper.getState().ready, true);
  assert.equal(f.calls.install.length, 2);
});

test('download requires a user gesture when browser activation can be checked', async () => {
  const f = fixture({ activation: false });
  await f.helper.install();
  assert.equal(f.helper.getState().error, 'user-gesture-required');
  assert.equal(f.helper.getState().ready, false);
  assert.equal(f.calls.install.length, 0);
  f.window.navigator.userActivation.isActive = true;
  await f.helper.install();
  assert.equal(f.helper.getState().ready, true);
});

test('readiness or user toggles affect only the next round', async () => {
  const f = fixture();
  assert.equal(f.helper.modeForNewRound('a'), 'browser');
  await f.helper.prepare();
  assert.equal(f.helper.modeForNewRound('a'), 'browser');
  assert.equal(f.helper.modeForNewRound('b'), 'local');
  f.helper.setEnabled(false);
  assert.equal(f.helper.getState().enabled, false);
  assert.equal(f.helper.getState().ready, true, 'Disabling the experiment does not uninstall the browser pack');
  assert.equal(f.helper.modeForNewRound('b'), 'local');
  assert.equal(f.helper.modeForNewRound('c'), 'browser');
  f.helper.setEnabled(true);
  assert.equal(f.helper.modeForNewRound('c'), 'browser');
  assert.equal(f.helper.modeForNewRound('d'), 'local');
});

test('concurrent actions share one request and do not install during a pending check', async () => {
  const checking = deferred();
  const f = fixture({ available: () => checking.promise });
  const first = f.helper.prepare();
  assert.equal(f.helper.prepare(), first);
  assert.equal(f.helper.install(), first);
  assert.equal(f.calls.available.length, 1);
  assert.equal(f.calls.install.length, 0);
  checking.resolve('available');
  await first;
  assert.equal(f.helper.getState().ready, true);
});

test('a disabled or replaced request cannot overwrite the new preparation state', async () => {
  const old = deferred();
  let request = 0;
  const f = fixture({ available: () => ++request === 1 ? old.promise : Promise.resolve('available') });
  const first = f.helper.prepare();
  f.helper.setEnabled(false);
  assert.equal(f.helper.getState().status, 'disabled');
  f.helper.setEnabled(true);
  await f.helper.prepare();
  old.resolve('unavailable');
  await first;
  assert.equal(f.helper.getState().status, 'ready');
  assert.equal(f.helper.getState().ready, true);
});

test('disabling an in-flight install ignores its completion and does not start its follow-up check', async () => {
  const downloading = deferred();
  const f = fixture({ install: () => downloading.promise });
  const work = f.helper.install();
  f.helper.setEnabled(false);
  downloading.resolve(true);
  await work;
  assert.equal(f.helper.getState().status, 'disabled');
  assert.equal(f.helper.getState().ready, false);
  assert.equal(f.calls.available.length, 0);
});

test('errors expose bounded diagnostic codes without storing arbitrary browser messages', async () => {
  for (const [name, expected] of [['NotAllowedError', 'permission-denied'],
    ['InvalidStateError', 'inactive-document'], ['Error', 'availability-failed']]) {
    const f = fixture({ available: () => Promise.reject(Object.assign(new Error('Private browser detail'), { name })) });
    await f.helper.prepare();
    assert.equal(f.helper.getState().error, expected);
    assert.equal(f.helper.getState().ready, false);
    assert.equal(JSON.stringify(f.diagnostics).includes('Private browser detail'), false);
    assert.equal(JSON.stringify(f.changes).includes('transcript'), false);
  }
});

test('checkbox interaction can recheck support but never automatically downloads', async () => {
  const f = fixture({ available: () => Promise.resolve('downloadable') });
  f.checkbox.checked = false;
  f.checkbox.dispatch('change');
  assert.equal(f.helper.getState().enabled, false);
  f.checkbox.checked = true;
  f.checkbox.dispatch('change');
  await f.helper.prepare();
  assert.equal(f.helper.getState().status, 'downloadable');
  assert.equal(f.calls.available.length, 1);
  assert.equal(f.calls.install.length, 0);
});

test('dispose removes controls and makes late promises and future actions inert', async () => {
  const checking = deferred();
  const f = fixture({ available: () => checking.promise });
  const work = f.helper.prepare();
  const changes = f.changes.length;
  f.helper.dispose();
  f.helper.dispose();
  checking.resolve('available');
  await work;
  await f.helper.prepare();
  await f.helper.install();
  f.helper.setEnabled(true);
  f.helper.setVisible(true);
  assert.equal(f.changes.length, changes);
  assert.equal(f.document.body.children.length, 0);
  assert.equal(f.helper.getState().ready, false);
  assert.equal(f.helper.getState().status, 'disabled');
  assert.equal(f.helper.modeForNewRound('disposed'), 'browser');
  assert.equal(f.calls.available.length, 1);
  assert.equal(f.calls.install.length, 0);
});
