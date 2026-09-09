const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const shell = fs.readFileSync(path.join(__dirname, '..', 'web', 'shell.html'), 'utf8');

function speechEvent(entries, resultIndex = 0) {
  const results = entries.map(([transcript, isFinal]) => Object.assign(
    [{ transcript, confidence: 0.95 }], { isFinal, item(index) { return this[index]; } }
  ));
  results.item = index => results[index];
  return { resultIndex, results };
}

function fixture({ api = 'standard', secure = true } = {}) {
  const block = shell.match(/      function createSpeechHost\(\) \{[\s\S]*?\n      \}/)?.[0];
  assert.ok(block, 'The maintained shell needs its isolated inline speech host');
  const handlers = new WeakMap();
  function element() {
    const value = {
      hidden: false, disabled: false, textContent: '', style: {}, attributes: {}, focusCalls: [],
      addEventListener(type, handler) {
        const events = handlers.get(this);
        events[type] ||= [];
        events[type].push(handler);
      },
      dispatch(type, event = {}) {
        for (const handler of handlers.get(this)[type] || []) handler(event);
      },
      setAttribute(name, value) { this.attributes[name] = String(value); },
      focus(options) {
        if (this.disabled) return;
        this.focusCalls.push(options);
        document.activeElement = this;
      },
      click() { if (!this.disabled) this.dispatch('click', { stopPropagation() {} }); }
    };
    handlers.set(value, {});
    return value;
  }
  const elements = Object.fromEntries(
    ['game', 'canvas', 'speech-panel', 'speech-status', 'speech-transcript', 'speech-notice']
      .map(id => [id, element()])
  );
  elements['speech-panel'].hidden = true;
  const document = Object.assign(element(), {
    hidden: false,
    activeElement: elements.canvas,
    getElementById: id => elements[id]
  });
  const timers = new Map();
  let now = 0;
  let nextTimer = 1;
  const window = Object.assign(element(), {
    isSecureContext: secure,
    setTimeout(callback, delay) {
      const id = nextTimer++;
      timers.set(id, { at: now + delay, callback });
      return id;
    },
    clearTimeout(id) { timers.delete(id); }
  });
  function advance(ms = 0) {
    const target = now + ms;
    for (let attempts = 0; attempts < 1000; attempts++) {
      const next = [...timers.entries()].filter(([, timer]) => timer.at <= target)
        .sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) { now = target; return; }
      now = next[1].at;
      timers.delete(next[0]);
      next[1].callback();
    }
    assert.fail('Speech restarts must be bounded, not a tight loop');
  }
  const instances = [];
  let starts = 0;
  let aborts = 0;
  class Recognition {
    constructor() { instances.push(this); }
    start() {
      starts++;
      this.callbacks = { start: this.onstart, result: this.onresult, error: this.onerror, end: this.onend };
      window.setTimeout(() => this.callbacks.start?.(), 0);
    }
    abort() {
      aborts++;
      window.setTimeout(() => this.callbacks?.end?.(), 0);
    }
    end() { this.callbacks.end?.(); }
    result(entries, index = 0) { this.callbacks.result?.(speechEvent(entries, index)); }
    error(error) { this.callbacks.error?.({ error }); this.end(); }
  }
  if (api === 'standard') window.SpeechRecognition = Recognition;
  if (api === 'prefixed') window.webkitSpeechRecognition = Recognition;
  const host = vm.runInNewContext(`(${block})()`, { window, document });
  const states = [];
  const results = [];
  host.observeSpeech((...values) => {
    assert.deepEqual(values.map(value => typeof value), ['string', 'boolean'],
      'Speech results use positional arguments so the Godot bridge receives a flat Array');
    results.push(values);
  }, (...values) => {
    assert.deepEqual(values.map(value => typeof value), ['boolean', 'boolean', 'string'],
      'Speech state uses positional arguments, matching existing host.observe');
    states.push(values);
  });
  return {
    host, document, window, elements, instances, states, results, advance,
    get starts() { return starts; }, get aborts() { return aborts; },
    get pendingTimers() { return timers.size; },
    get latest() { return instances.at(-1); },
    get status() { return elements['speech-status']; },
    get panel() { return elements['speech-panel']; },
    get transcript() { return elements['speech-transcript']; },
    get notice() { return elements['speech-notice']; },
    listen() { host.speechMode(true); advance(); }
  };
}

test('Voice activation starts recognition immediately without a second control', () => {
  const f = fixture();
  f.host.speechMode(true);
  assert.equal(f.starts, 1);
  f.host.speechMode(true);
  assert.equal(f.starts, 1, 'An already active mode never starts a duplicate recognizer');
  f.host.speechMode(false);
  assert.equal(f.panel.hidden, true);
  assert.equal(f.aborts, 1);
});

test('the recognition panel contains no separate Listen or Stop button', () => {
  assert.doesNotMatch(shell, /id="speech-button"/);
  assert.match(shell, /id="speech-buddy"[^>]*aria-hidden="true"/);
  assert.match(shell, /id="speech-status"/);
});

test('recognition activity drives one bounded visual reaction and stops cleanly', () => {
  const f = fixture();
  f.listen();
  assert.equal(f.panel.attributes['data-state'], 'listening');
  for (let index = 0; index < 10; index++) f.latest.result([[`word ${index}`, false]]);
  assert.equal(f.panel.attributes['data-heard'], 'true');
  assert.equal(f.pendingTimers, 1, 'Rapid words replace the reaction timer rather than stacking timers');
  f.host.stopSpeech();
  f.advance(1000);
  assert.equal(f.panel.attributes['data-state'], 'off');
  assert.equal(f.panel.attributes['data-heard'], 'false');
  assert.equal(f.pendingTimers, 0);
});

test('a failed microphone shutdown stays visible and blocks another recording', () => {
  const f = fixture();
  f.listen();
  f.latest.abort = () => { throw new Error('abort failed'); };
  f.latest.stop = () => { throw new Error('stop failed'); };
  f.host.stopSpeech();
  assert.equal(f.panel.hidden, false);
  assert.equal(f.panel.attributes['data-state'], 'error');
  assert.match(f.status.textContent, /close this tab/i);
  f.host.speechMode(true);
  assert.equal(f.starts, 1);
  f.latest.result([['doll', true]]);
  assert.equal(f.results.length, 0);
});

test('microphone cleanup falls back to stop without starting another recognizer', () => {
  const f = fixture();
  f.listen();
  let stopped = 0;
  f.latest.abort = () => { throw new Error('abort failed'); };
  f.latest.stop = () => { stopped++; };
  f.host.stopSpeech();
  assert.equal(stopped, 1);
  assert.equal(f.panel.hidden, true);
  assert.equal(f.starts, 1);
});

test('the accessible panel is hidden and the exact speech API joins the existing host', () => {
  for (const id of ['speech-panel', 'speech-status', 'speech-transcript', 'speech-notice']) {
    assert.match(shell, new RegExp(`id="${id}"`));
  }
  assert.match(shell, /id="speech-panel"[^>]*hidden/);
  assert.match(shell, /id="speech-panel"[^>]*aria-describedby="speech-notice"/);
  assert.match(shell, /\.\.\.speechHost/);
  const f = fixture();
  for (const method of ['speechAvailable', 'observeSpeech', 'speechMode', 'stopSpeech', 'speechBounds']) {
    assert.equal(typeof f.host[method], 'function', method);
  }
  assert.equal(f.panel.hidden, true);
  assert.deepEqual(f.states.at(-1), [false, false, '']);
  assert.equal(f.starts, 0);
});

test('standard and prefixed recognition require a secure context', () => {
  assert.equal(fixture().host.speechAvailable(), true);
  assert.equal(fixture({ api: 'prefixed' }).host.speechAvailable(), true);
  for (const options of [{ api: 'missing' }, { secure: false }]) {
    const f = fixture(options);
    assert.equal(f.host.speechAvailable(), false);
    f.host.speechMode(true);
    assert.equal(f.panel.attributes['data-state'], 'error');
    assert.match(f.status.textContent, /unavailable|HTTPS|secure/i);
    assert.equal(f.starts, 0);
  }
});

test('Voice starts English listening synchronously with a visible privacy notice', () => {
  const f = fixture();
  f.host.speechMode(true);
  assert.equal(f.panel.hidden, false);
  assert.match(f.notice.textContent, /browser.*remotely/i);
  assert.match(f.notice.textContent, /(?:save|store)s? no voice or transcripts/i);
  assert.equal(f.starts, 1, 'start is called synchronously from Voice activation');
  assert.equal(f.latest.lang, 'en-US');
  assert.equal(f.latest.interimResults, true);
  assert.equal(f.latest.continuous, true);
  f.advance();
  assert.equal(f.panel.attributes['data-state'], 'listening');
  assert.deepEqual(f.states.at(-1).slice(0, 2), [true, true]);
});

test('Voice activation does not steal canvas focus or duplicate microphone requests', () => {
  const f = fixture();
  f.host.speechMode(true);
  assert.equal(f.document.activeElement, f.elements.canvas);
  assert.equal(f.elements.canvas.focusCalls.length, 0);
  assert.equal(f.starts, 1);
  f.host.speechMode(true);
  assert.equal(f.elements.canvas.focusCalls.length, 0);
  assert.equal(f.starts, 1, 'An already enabled mode does not start a second recognizer');
});

test('every explicit voice exit restores canvas focus once without scrolling', () => {
  for (const exit of ['stopSpeech', 'speechMode', 'Escape']) {
    const f = fixture();
    f.listen();
    if (exit === 'stopSpeech') f.host.stopSpeech();
    if (exit === 'speechMode') f.host.speechMode(false);
    if (exit === 'Escape') f.panel.dispatch('keydown', { key: 'Escape', stopPropagation() {} });
    assert.equal(f.panel.hidden, true);
    assert.equal(f.document.activeElement, f.elements.canvas, exit);
    assert.deepEqual(f.elements.canvas.focusCalls.map(options => options.preventScroll), [true], exit);
    f.host.stopSpeech();
    assert.equal(f.elements.canvas.focusCalls.length, 1, 'Repeated stop does not steal focus');
  }
});

test('a synchronous native rejection of voice mode never starts the microphone', () => {
  const f = fixture();
  f.host.observeSpeech(() => {}, enabled => { if (enabled) f.host.stopSpeech(); });
  f.host.speechMode(true);
  assert.equal(f.panel.hidden, true);
  assert.equal(f.document.activeElement, f.elements.canvas);
  assert.equal(f.starts, 0);
});

test('interim speech is plain visible text and only finals are marked for scoring', () => {
  const f = fixture();
  f.listen();
  f.latest.result([['I see a <doll>', false]]);
  assert.equal(f.transcript.textContent, 'I see a <doll>');
  assert.deepEqual(f.results, [['I see a <doll>', false]]);
  f.latest.result([['I see a doll', true]]);
  assert.equal(f.transcript.textContent, 'I see a doll');
  assert.deepEqual(f.results.at(-1), ['I see a doll', true]);
  f.latest.result([['I see a doll', true]]);
  assert.equal(f.results.filter(([, final]) => final).length, 1, 'A final result is delivered once');
  f.latest.result([['I see a doll', true], ['cat', false]], 1);
  assert.deepEqual(f.results.filter(([, final]) => final), [['I see a doll', true]]);
  f.latest.result([['I see a doll', true], ['cat', true]], 1);
  assert.deepEqual(f.results.filter(([, final]) => final), [['I see a doll', true], ['cat', true]]);
});

test('utterance endings restart once after a delay while Stop exits the entire mode', () => {
  const f = fixture();
  f.listen();
  const old = f.latest;
  old.result([['one word', false]]);
  old.end();
  old.end();
  assert.equal(f.starts, 1, 'onend cannot restart synchronously');
  assert.equal(f.panel.attributes['data-state'], 'starting');
  assert.equal(f.panel.attributes['data-heard'], 'false');
  f.advance(1500);
  assert.equal(f.starts, 2, 'duplicate onend schedules only one restart');
  old.result([['stale doll', true]]);
  assert.deepEqual(f.results, [['one word', false]]);
  f.host.speechMode(false);
  assert.equal(f.panel.hidden, true);
  assert.equal(f.transcript.textContent, '');
  assert.equal(f.aborts, 1);
  assert.deepEqual(f.states.at(-1), [false, false, '']);
  f.advance(3000);
  assert.equal(f.starts, 2);
});

test('stopping during start or a pending restart releases the mic and rejects late results', () => {
  const f = fixture();
  f.host.speechMode(true);
  const old = f.latest;
  f.host.stopSpeech();
  old.result([['doll', true]]);
  f.advance(3000);
  assert.equal(f.starts, 1);
  assert.equal(f.aborts, 1);
  assert.equal(f.panel.hidden, true);
  assert.deepEqual(f.results, []);
  f.listen();
  f.latest.end();
  f.host.speechMode(false);
  f.advance(3000);
  assert.equal(f.starts, 2);
  f.host.stopSpeech();
  assert.equal(f.aborts, 1, 'idempotent stop does not abort a released recognizer twice');
});

test('a newer session ignores old start, result, error and end callbacks', () => {
  const f = fixture();
  f.listen();
  const old = f.latest;
  f.host.stopSpeech();
  f.listen();
  old.callbacks.start();
  old.result([['old cat', true]]);
  old.error('not-allowed');
  f.advance(3000);
  assert.equal(f.starts, 2);
  assert.deepEqual(f.results, []);
  assert.equal(f.panel.hidden, false);
  assert.deepEqual(f.states.at(-1).slice(0, 2), [true, true]);
  f.latest.result([['new doll', true]]);
  assert.deepEqual(f.results, [['new doll', true]]);
});

test('a native win stop during a multi-result callback prevents all remaining results', () => {
  const f = fixture();
  const delivered = [];
  f.host.observeSpeech((...values) => { delivered.push(values); f.host.stopSpeech(); }, () => {});
  f.listen();
  f.latest.result([['doll', true], ['cat', true], ['sun', true]]);
  assert.deepEqual(delivered, [['doll', true]]);
  assert.equal(f.panel.hidden, true);
  assert.equal(f.transcript.textContent, '');
  f.advance(3000);
  assert.equal(f.starts, 1);
});

test('a synchronous native stop during onend clears rather than queues a restart', () => {
  const f = fixture();
  f.host.observeSpeech(() => {}, (enabled, listening) => {
    if (f.starts && enabled && !listening) f.host.stopSpeech();
  });
  f.listen();
  f.latest.end();
  assert.equal(f.panel.hidden, true);
  assert.equal(f.pendingTimers, 0);
  f.advance(3000);
  assert.equal(f.starts, 1);
});

for (const code of ['not-allowed', 'service-not-allowed', 'no-speech', 'audio-capture', 'network']) {
  test(`${code} reports a visible error without any automatic retry`, () => {
    const f = fixture();
    f.listen();
    const old = f.latest;
    old.error(code);
    const error = f.status.textContent;
    assert.match(error, code.includes('allowed') ? /permission|denied|blocked/i :
      code === 'no-speech' ? /no speech/i : code === 'audio-capture' ? /microphone/i : /network/i);
    assert.equal(f.panel.attributes['data-state'], 'error');
    assert.equal(f.panel.hidden, false, 'The error remains visible with manual play available');
    assert.deepEqual(f.states.at(-1).slice(0, 2), [true, false]);
    f.advance(5000);
    old.result([['late doll', true]]);
    assert.equal(f.starts, 1);
    assert.equal(f.aborts, 1);
    assert.deepEqual(f.results, []);
    assert.equal(f.status.textContent, error);
  });
}

test('an error preserves the native voice slot until an explicit retry or mode exit', () => {
  const f = fixture();
  f.host.speechBounds(0.025, 0.3, 0.95, 0.15);
  const bounds = { ...f.panel.style };
  f.listen();
  f.latest.error('not-allowed');
  f.advance(5000);
  assert.deepEqual(f.states.at(-1).slice(0, 2), [true, false]);
  assert.equal(f.panel.hidden, false);
  assert.deepEqual(f.panel.style, bounds);
  assert.equal(f.starts, 1);
  f.host.speechMode(false);
  f.host.speechMode(true);
  f.advance();
  assert.equal(f.starts, 2, 'Only another Voice off/on activation retries after denial');
  assert.deepEqual(f.states.at(-1).slice(0, 2), [true, true]);
  f.latest.error('network');
  f.host.speechMode(false);
  assert.equal(f.panel.hidden, true);
  assert.deepEqual(f.states.at(-1), [false, false, '']);
  f.advance(5000);
  assert.equal(f.starts, 2);
});

test('visibility and pagehide stop speech; showing the page never starts it again', () => {
  for (const event of ['visibilitychange', 'pagehide']) {
    const f = fixture();
    f.listen();
    const old = f.latest;
    if (event === 'visibilitychange') {
      f.document.hidden = true;
      f.document.dispatch(event);
    } else f.window.dispatch(event);
    old.result([['late doll', true]]);
    f.document.hidden = false;
    f.document.dispatch('visibilitychange');
    f.advance(3000);
    assert.equal(f.panel.hidden, true);
    assert.equal(f.aborts, 1);
    assert.equal(f.starts, 1);
    assert.deepEqual(f.results, []);
    assert.equal(f.elements.canvas.focusCalls.length, 0, 'Page-hide cleanup never changes focus');
  }
  const hidden = fixture();
  hidden.document.hidden = true;
  hidden.host.speechMode(true);
  assert.equal(hidden.starts, 0);
  assert.equal(hidden.panel.hidden, true);
  assert.equal(hidden.elements.canvas.focusCalls.length, 0);
  const stopping = fixture();
  stopping.listen();
  stopping.document.hidden = true;
  stopping.host.stopSpeech();
  assert.equal(stopping.elements.canvas.focusCalls.length, 0, 'Native stop is safe on hidden pages');
});

test('synchronous start errors release the recognizer and require a new gesture', () => {
  const f = fixture();
  f.window.SpeechRecognition.prototype.start = function () {
    throw Object.assign(new Error('Permission denied'), { name: 'NotAllowedError' });
  };
  f.listen();
  assert.match(f.status.textContent, /permission|denied/i);
  assert.deepEqual(f.states.at(-1).slice(0, 2), [true, false]);
  assert.equal(f.aborts, 1);
  f.advance(5000);
  assert.equal(f.instances.length, 1);
});

test('normalized bounds stay inside the native rectangle and keys do not reach the canvas', () => {
  const f = fixture();
  f.host.speechBounds(0.025, 0.3, 0.95, 0.15);
  assert.equal(f.panel.style.left, '2.5%');
  assert.equal(f.panel.style.top, '30%');
  assert.equal(f.panel.style.width, '95%');
  assert.equal(f.panel.style.height, '15%');
  f.host.speechBounds(-1, 0.9, 5, 1);
  assert.equal(f.panel.style.left, '0%');
  assert.equal(f.panel.style.width, '100%');
  assert.ok(parseFloat(f.panel.style.top) + parseFloat(f.panel.style.height) <= 100.001);
  let stopped = 0;
  for (const type of ['keydown', 'keyup']) {
    f.panel.dispatch(type, { key: 'Enter', stopPropagation() { stopped++; } });
  }
  assert.equal(stopped, 2);
});
