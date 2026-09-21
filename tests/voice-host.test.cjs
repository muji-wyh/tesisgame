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

function fixture({ api = 'standard', secure = true, autoStart = true, online = true, synthesis = false } = {}) {
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
    ['game', 'canvas', 'speech-panel', 'speech-status', 'speech-transcript', 'speech-notice', 'pop-aura', 'pop-status']
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
    navigator: { onLine: online },
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
      if (autoStart) window.setTimeout(() => this.callbacks.start?.(), 0);
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
  const spoken = [];
  let summaryCancels = 0;
  if (synthesis) {
    window.SpeechSynthesisUtterance = class { constructor(text) { this.text = text; } };
    window.speechSynthesis = {
      speak(utterance) { spoken.push(utterance); },
      cancel() { summaryCancels++; }
    };
  }
  const host = vm.runInNewContext(`(${block})()`, { window, document });
  const states = [];
  const results = [];
  const popWords = [];
  host.observePopSpeech(word => {
    assert.equal(typeof word, 'string', 'Pop emits one lexical word as a positional bridge argument');
    popWords.push(word);
  });
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
    host, document, window, elements, instances, states, results, popWords, advance, spoken,
    get starts() { return starts; }, get aborts() { return aborts; },
    get pendingTimers() { return timers.size; },
    get summaryCancels() { return summaryCancels; },
    get latest() { return instances.at(-1); },
    get status() { return elements['speech-status']; },
    get panel() { return elements['speech-panel']; },
    get transcript() { return elements['speech-transcript']; },
    get notice() { return elements['speech-notice']; },
    get aura() { return elements['pop-aura']; },
    get popStatus() { return elements['pop-status']; },
    listen(presentation) { host.speechMode(true, presentation); advance(); }
  };
}

test('Voice activation starts recognition immediately without a second control', () => {
  const f = fixture({ autoStart: false });
  f.host.speechMode(true);
  assert.equal(f.starts, 1);
  assert.equal(f.aura.attributes['data-listening'], 'false', 'Pending permission does not light the border');
  f.latest.callbacks.start();
  assert.equal(f.aura.attributes['data-listening'], 'true', 'Match uses the shared light after actual listening starts');
  f.host.speechMode(true);
  assert.equal(f.starts, 1, 'An already active mode never starts a duplicate recognizer');
  f.host.speechMode(false);
  assert.equal(f.panel.hidden, true);
  assert.equal(f.aura.attributes['data-listening'], 'false');
  assert.equal(f.aborts, 1);
});

test('the recognition panel contains no separate Listen or Stop button', () => {
  assert.doesNotMatch(shell, /id="speech-button"/);
  assert.match(shell, /id="speech-buddy"[^>]*aria-hidden="true"/);
  assert.match(shell, /id="speech-status"/);
});

test('incoming words cycle three bounded duck reactions without restarting recognition', () => {
  const f = fixture();
  f.listen();
  const reactions = [];
  for (const word of ['doll', 'cat', 'ball']) {
    f.latest.result([[`I see a ${word}`, false]]);
    reactions.push(f.panel.attributes['data-reaction']);
    assert.equal(f.panel.attributes['data-heard'], 'true');
  }
  assert.deepEqual(reactions, ['nod', 'wave', 'tilt']);
  assert.equal(f.starts, 1);
  assert.equal(f.pendingTimers, 1, 'Only the latest reaction timer remains');
  f.advance(300);
  assert.equal(f.panel.attributes['data-heard'], 'false');
  f.host.stopSpeech();
  f.advance();
  assert.equal(f.panel.attributes['data-state'], 'off');
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
  assert.equal(f.aura.attributes['data-listening'], 'false');
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
  assert.equal(f.aura.attributes['data-listening'], 'false');
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
  assert.equal(f.aura.attributes['data-listening'], 'false', 'The border stops while recognition reconnects');
  assert.equal(f.panel.attributes['data-heard'], 'false');
  f.advance(1500);
  assert.equal(f.starts, 2, 'duplicate onend schedules only one restart');
  assert.equal(f.aura.attributes['data-listening'], 'true');
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
    assert.equal(f.aura.attributes['data-listening'], 'false');
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
    assert.equal(f.aura.attributes['data-listening'], 'false');
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

test('Pop requests permission immediately but waits for actual listening before lighting the screen', () => {
  const f = fixture({ autoStart: false });
  f.host.speechMode(true, 'pop');
  assert.equal(f.starts, 1);
  assert.equal(f.panel.hidden, true);
  assert.equal(f.aura.attributes['data-listening'], 'false');
  assert.deepEqual(f.states.at(-1).slice(0, 2), [true, false]);
  assert.match(f.states.at(-1)[2], /microphone access.*round starts when listening/i);
  f.latest.result([['cat', false]]);
  f.advance(45000);
  assert.equal(f.starts, 1, 'Pending browser permission neither times out a game nor starts another request');
  assert.deepEqual(f.popWords, []);
  assert.equal(f.states.some(([, listening]) => listening), false);
  f.latest.callbacks.start();
  assert.deepEqual(f.states.at(-1).slice(0, 2), [true, true]);
  assert.equal(f.aura.attributes['data-listening'], 'true');
  assert.equal(f.panel.hidden, true);
  f.host.stopSpeech();
  assert.equal(f.aura.attributes['data-listening'], 'false');
});

test('Pop interim words score once through repeated, shortened and revised finals', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['Cat', false]]);
  assert.deepEqual(f.popWords, ['Cat'], 'Interim speech is delivered immediately');
  f.latest.result([['Cat', false]]);
  f.latest.result([['the cat', false]]);
  assert.deepEqual(f.popWords, ['Cat', 'the'], 'An inserted prefix cannot replay a consumed target word');
  f.latest.result([['the cat dog', false]]);
  f.latest.result([['cat', false]]);
  f.latest.result([['the cat dog', true]]);
  f.latest.result([['the cat dog', true]]);
  f.latest.result([['the cat dog sun', false]]);
  assert.deepEqual(f.popWords, ['Cat', 'the', 'dog'], 'Completed result indexes reject late interim revisions too');
  assert.ok(f.results.some(([text, final]) => text === 'the cat dog' && final), 'The original full-transcript callback stays intact');
  f.latest.result([['the cat dog', true], ['cat', false]], 1);
  f.latest.result([['the cat dog', true], ['cat', true]], 1);
  assert.deepEqual(f.popWords, ['Cat', 'the', 'dog', 'cat'], 'A new utterance may legitimately repeat a word');
});

test('Pop delivers newly completed interim words and preserves full nonmatching lexical tokens', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['ca', false]]);
  f.latest.result([['cat', false]]);
  f.latest.result([['cat cat2 _cat caté cat\'s 2cat cat_dog', true]]);
  assert.deepEqual(f.popWords, ['ca', 'cat', 'cat2', '_cat', 'caté', "cat's", '2cat', 'cat_dog']);
  assert.equal(f.popWords.filter(word => word === 'cat').length, 1, 'Completing an interim prefix scores cat once');
  f.latest.result([['cat', true], ['DOGS', true]], 1);
  assert.equal(f.popWords.at(-1), 'DOGS', 'The model receives original case and handles canonical word matching');
});

test('only Pop emits the lexical callback and switching presentation releases the previous recognizer', () => {
  const f = fixture();
  f.listen();
  const match = f.latest;
  match.result([['cat', false]]);
  assert.deepEqual(f.popWords, []);
  f.host.speechMode(true, 'pop');
  f.advance();
  assert.equal(f.aborts, 1);
  assert.equal(f.starts, 2);
  assert.equal(f.panel.hidden, true);
  match.result([['old dog', true]]);
  f.latest.result([['cat', true]]);
  assert.deepEqual(f.popWords, ['cat']);
  f.host.stopSpeech();
  f.listen();
  assert.equal(f.panel.hidden, false, 'An ordinary activation after Pop uses Match presentation again');
  assert.equal(f.aura.attributes['data-listening'], 'true', 'Match keeps the same listening border after switching from Pop');
  f.latest.result([['sun', true]]);
  assert.deepEqual(f.popWords, ['cat']);
  assert.deepEqual(f.results.at(-1), ['sun', true]);
});

test('model-provided noun aliases prevent revised plurals from replaying a target without swallowing partial words', () => {
  const f = fixture();
  f.listen('pop');
  const targets = [
    { uid: 1, text: 'cat', forms: ['cat', 'cats'] },
    { uid: 2, text: 'mouse', forms: ['mouse', 'mice'] },
    { uid: 3, text: 'bus', forms: ['bus', 'buses'] }
  ];
  f.host.popStatus(JSON.stringify({ phase: 'running', targets }));
  f.latest.result([['ca', false]]);
  f.latest.result([['cat mouse buses', false]]);
  f.host.popStatus(JSON.stringify({ phase: 'running', targets: [] }));
  f.latest.result([['cats mice bus', true]]);
  assert.deepEqual(f.popWords, ['ca', 'cat', 'mouse', 'buses']);
  assert.equal(f.popStatus.attributes['data-targets'], '[]', 'Only currently displayed target geometry is exposed');
  f.latest.result([['cats mice bus', true], ['cats', true]], 1);
  assert.deepEqual(f.popWords, ['ca', 'cat', 'mouse', 'buses', 'cats'], 'New utterances may repeat any accepted noun form');
});

test('noun metadata arriving after an interim still recognizes already-consumed aliases', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['mice', false]]);
  f.host.popStatus(JSON.stringify({ phase: 'running', targets: [{ text: 'mouse', forms: ['mouse', 'mice'] }] }));
  f.latest.result([['mouse', true]]);
  assert.deepEqual(f.popWords, ['mice']);
});

test('a Pop hit that ends the round rejects remaining words and all stale browser callbacks', () => {
  const f = fixture();
  const delivered = [];
  f.host.observePopSpeech(word => { delivered.push(word); f.host.stopSpeech(); });
  f.listen('pop');
  const old = f.latest;
  old.result([['cat dog ball', false], ['sun', true]]);
  assert.deepEqual(delivered, ['cat']);
  assert.equal(f.aura.attributes['data-listening'], 'false');
  assert.equal(f.panel.hidden, true);
  old.callbacks.start();
  old.error('network');
  old.result([['cat dog ball', true]]);
  f.advance(5000);
  assert.deepEqual(delivered, ['cat']);
  assert.deepEqual(f.states.at(-1), [false, false, '']);
  assert.equal(f.starts, 1);
});

for (const code of ['not-allowed', 'service-not-allowed', 'audio-capture', 'network', 'language-not-supported']) {
  test(`Pop ${code} turns off its glow, hides the old panel and requires explicit recovery`, () => {
    const f = fixture();
    f.listen('pop');
    const old = f.latest;
    old.error(code);
    assert.deepEqual(f.states.at(-1).slice(0, 2), [true, false]);
    assert.match(f.states.at(-1)[2], /retry|supported browser/i);
    assert.equal(f.panel.hidden, true);
    assert.equal(f.aura.attributes['data-listening'], 'false');
    f.advance(5000);
    assert.equal(f.starts, 1);
    f.host.speechMode(false);
    f.listen('pop');
    assert.equal(f.starts, 2);
    assert.equal(f.aura.attributes['data-listening'], 'true');
    old.result([['stale cat', true]]);
    f.latest.result([['dog', true]]);
    assert.deepEqual(f.popWords, ['dog']);
  });
}

test('unsupported or offline Pop never pretends to be listening and reports actionable state', () => {
  for (const options of [{ api: 'missing' }, { secure: false }, { online: false }]) {
    const f = fixture(options);
    f.listen('pop');
    assert.equal(f.starts, 0);
    assert.equal(f.panel.hidden, true);
    assert.equal(f.aura.attributes['data-listening'], 'false');
    assert.deepEqual(f.states.at(-1).slice(0, 2), [true, false]);
    assert.match(f.states.at(-1)[2], /HTTPS|supported browser|offline/i);
  }
  const f = fixture();
  f.listen('pop');
  f.window.navigator.onLine = false;
  f.window.dispatch('offline');
  assert.equal(f.aborts, 1);
  assert.equal(f.aura.attributes['data-listening'], 'false');
  assert.match(f.states.at(-1)[2], /offline.*retry/i);
  f.window.navigator.onLine = true;
  f.host.stopSpeech();
  f.listen('pop');
  assert.equal(f.starts, 2);
});

test('Pop silence retries twice quietly, then stops rather than looping microphone requests', () => {
  for (const event of ['error', 'end']) {
    const f = fixture();
    f.listen('pop');
    for (let attempt = 0; attempt < 3; attempt++) {
      if (event === 'error') f.latest.error('no-speech');
      else f.latest.end();
      assert.equal(f.aura.attributes['data-listening'], 'false');
      assert.equal(f.panel.hidden, true);
      f.advance(1000);
      assert.equal(f.starts, Math.min(attempt + 2, 3));
    }
    assert.match(f.states.at(-1)[2], /no speech.*retry/i);
    assert.deepEqual(f.states.at(-1).slice(0, 2), [true, false]);
    f.advance(30000);
    assert.equal(f.starts, 3);
    assert.equal(f.pendingTimers, 0);
  }
});

test('hearing new speech resets the Pop silence budget and natural endings permit repeated new utterances', () => {
  const f = fixture();
  f.listen('pop');
  for (let session = 0; session < 5; session++) {
    f.latest.error('no-speech');
    f.advance(400);
    f.latest.result([['cat', false]]);
    f.latest.result([['cat', true]]);
    const old = f.latest;
    old.end();
    old.end();
    assert.equal(f.aura.attributes['data-listening'], 'false');
    f.advance(400);
    old.result([['old dog', true]]);
  }
  assert.deepEqual(f.popWords, ['cat', 'cat', 'cat', 'cat', 'cat']);
  assert.equal(f.starts, 11);
  assert.equal(f.aura.attributes['data-listening'], 'true');
});

test('Pop background and pending-permission exits abort safely and never resume without a gesture', () => {
  for (const event of ['visibilitychange', 'pagehide']) {
    const f = fixture({ autoStart: false });
    f.host.speechMode(true, 'pop');
    const old = f.latest;
    if (event === 'visibilitychange') {
      f.document.hidden = true;
      f.document.dispatch(event);
    } else f.window.dispatch(event);
    old.callbacks.start();
    old.result([['cat', true]]);
    f.document.hidden = false;
    f.document.dispatch('visibilitychange');
    f.advance(5000);
    assert.equal(f.aborts, 1);
    assert.equal(f.starts, 1);
    assert.equal(f.panel.hidden, true);
    assert.equal(f.aura.attributes['data-listening'], 'false');
    assert.deepEqual(f.popWords, []);
    assert.deepEqual(f.states.at(-1), [false, false, '']);
    assert.equal(f.elements.canvas.focusCalls.length, 0);
  }
});

test('a failed Pop shutdown keeps a visible stop warning through summary and retry attempts', () => {
  const f = fixture({ synthesis: true });
  f.listen('pop');
  f.host.speechBounds(0, 0, 0, 0);
  f.latest.abort = f.latest.stop = () => { throw new Error('device failure'); };
  assert.equal(f.host.stopSpeech(), false);
  assert.equal(f.panel.hidden, false);
  assert.equal(f.panel.attributes['data-pop-stop-failed'], 'true');
  assert.equal(f.panel.attributes['data-state'], 'error');
  assert.equal(f.status.textContent, 'Microphone could not be stopped. Close this tab to stop voice input.');
  assert.equal(f.aura.attributes['data-listening'], 'false');
  assert.match(f.states.at(-1)[2], /close this tab/i);
  assert.equal(f.host.stopSpeech(), false, 'Summary cannot proceed until native microphone shutdown succeeds');
  assert.equal(f.spoken.length, 0);
  assert.equal(f.panel.hidden, false, 'A finished round cannot cover the microphone stop failure');
  assert.equal(f.panel.attributes['data-pop-stop-failed'], 'true');
  assert.match(f.status.textContent, /close this tab/i);
  f.host.speechMode(true, 'pop');
  assert.equal(f.starts, 1);
  assert.equal(f.panel.hidden, false);
  f.latest.abort = () => {};
  assert.equal(f.host.stopSpeech(), true);
  assert.equal(f.panel.hidden, true);
  assert.equal(f.panel.attributes['data-pop-stop-failed'], 'false');
});

test('Pop stop failure has viewport CSS bounds that override a stale Match speech rectangle', () => {
  const rule = shell.match(/#speech-panel\[data-pop-stop-failed="true"\] \{([^}]+)\}/)?.[1];
  assert.ok(rule);
  assert.match(rule, /position:\s*fixed/);
  assert.match(rule, /inset:\s*12px 12px auto\s*!important/);
  assert.match(rule, /width:\s*auto\s*!important/);
  assert.match(rule, /height:\s*auto\s*!important/);
  for (const code of ['not-allowed', 'audio-capture', 'network', 'language-not-supported']) {
    const f = fixture();
    f.listen('pop');
    f.latest.error(code);
    assert.equal(f.panel.hidden, true, code + ' stays in the native Pop view');
    assert.equal(f.panel.attributes['data-pop-stop-failed'], 'false');
  }
});

test('Pop status projects actual target and control geometry without introducing a game mutation API', () => {
  const f = fixture();
  let writes = 0;
  let readable = '';
  Object.defineProperty(f.popStatus, 'textContent', {
    get() { return readable; }, set(value) { readable = value; writes++; }
  });
  const payload = { phase: 'playing', remaining: 19.3, hits: 4, score: 90, best_combo: 3,
    targets: [{ uid: 7, text: 'cat', x: 31, y: 118, width: 103, height: 77, secret: 'discard' }],
    controls: [{ name: 'EndPop', text: 'Finish', x: 300, y: 15, width: 52, height: 44, disabled: false, action: 'discard' }],
    message: 'Nice pop!' };
  assert.equal(f.host.popStatus(JSON.stringify(payload)), true);
  assert.equal(f.popStatus.attributes['data-phase'], 'playing');
  assert.equal(f.popStatus.attributes['data-remaining'], '20');
  assert.equal(f.popStatus.attributes['data-hits'], '4');
  assert.equal(f.popStatus.attributes['data-score'], '90');
  assert.equal(f.popStatus.attributes['data-best-combo'], '3');
  assert.deepEqual(JSON.parse(f.popStatus.attributes['data-targets']), [{ uid: 7, text: 'cat', x: 31, y: 118, width: 103, height: 77 }]);
  assert.deepEqual(JSON.parse(f.popStatus.attributes['data-controls']), [{ name: 'EndPop', text: 'Finish', x: 300, y: 15, width: 52, height: 44, disabled: false }]);
  assert.match(readable, /Nice pop!.*4 hits.*Score 90.*Words: cat/);
  f.host.popStatus(JSON.stringify(payload));
  assert.equal(writes, 1, 'Repeated snapshots do not repeat the same live-region announcement');
  assert.equal(f.host.popStatus('invalid JSON'), false);
  assert.equal(f.host.popStatus('null'), false);
  assert.equal(f.host.popStatus('[]'), false);
  f.host.popStatus(JSON.stringify({ phase: 'idle' }));
  assert.equal(readable, '');
  assert.equal(f.popStatus.attributes['data-targets'], '[]');
  assert.equal(f.popStatus.attributes['data-controls'], '[]');
  assert.equal(f.starts, 0, 'Publishing the UI snapshot cannot start speech or mutate gameplay');
});

test('Pop snapshots expose full live speech and result state without repeating interim text in the live region', () => {
  const f = fixture();
  let writes = 0, readable = '';
  Object.defineProperty(f.popStatus, 'textContent', {
    get() { return readable; }, set(value) { readable = value; writes++; }
  });
  const state = { phase: 'running', remaining: 24, transcript: 'I see a ca', transcript_final: false,
    report: 'You popped four words.', report_step: 2, results_scroll: 14.5, results_scroll_max: 96,
    results_scrollbar_visible: false, report_speaking: true, report_loading: false,
    report_audio: ['res://assets/audio/pop/round-4.wav', 'res://assets/audio/voice/word-cat.wav',
      'https://untrusted.invalid/audio.wav', 'res://assets/audio/pop/../../private.wav'] };
  f.host.popStatus(JSON.stringify(state));
  assert.equal(f.popStatus.attributes['data-transcript'], 'I see a ca');
  assert.equal(f.popStatus.attributes['data-transcript-final'], 'false');
  assert.equal(f.popStatus.attributes['data-report'], 'You popped four words.');
  assert.equal(f.popStatus.attributes['data-report-step'], '2');
  assert.equal(f.popStatus.attributes['data-report-speaking'], 'true');
  assert.equal(f.popStatus.attributes['data-report-loading'], 'false');
  assert.deepEqual(JSON.parse(f.popStatus.attributes['data-report-audio']),
    ['res://assets/audio/pop/round-4.wav', 'res://assets/audio/voice/word-cat.wav']);
  assert.equal(f.popStatus.attributes['data-results-scroll'], '14.5');
  assert.equal(f.popStatus.attributes['data-results-scroll-max'], '96');
  assert.equal(f.popStatus.attributes['data-results-scrollbar-visible'], 'false');
  f.host.popStatus(JSON.stringify({ ...state, transcript: 'I see a cat', transcript_final: true,
    report_step: 3, results_scroll: 38, results_scrollbar_visible: true }));
  assert.equal(f.popStatus.attributes['data-transcript'], 'I see a cat');
  assert.equal(f.popStatus.attributes['data-transcript-final'], 'true');
  assert.equal(f.popStatus.attributes['data-results-scrollbar-visible'], 'true');
  assert.equal(writes, 1, 'Transcription revisions and scrolling cannot interrupt the game announcement');
  assert.doesNotMatch(readable, /I see|four words/);
  f.host.popStatus(JSON.stringify({ phase: 'idle' }));
  assert.equal(f.popStatus.attributes['data-transcript'], '');
  assert.equal(f.popStatus.attributes['data-transcript-final'], 'false');
  assert.equal(f.popStatus.attributes['data-report'], '');
  assert.equal(f.popStatus.attributes['data-report-step'], '0');
  assert.equal(f.popStatus.attributes['data-report-speaking'], 'false');
  assert.equal(f.popStatus.attributes['data-report-loading'], 'false');
  assert.equal(f.popStatus.attributes['data-report-audio'], '[]');
  assert.equal(f.popStatus.attributes['data-results-scroll'], '0');
  assert.equal(f.popStatus.attributes['data-results-scroll-max'], '0');
});

test('the Pop glow covers the viewport edges, ignores input and respects reduced motion', () => {
  const baseRule = shell.match(/#pop-aura\s*\{([^}]*)\}/)?.[1];
  assert.ok(baseRule, 'The viewport overlay has a base style');
  for (const declaration of [/position:\s*fixed;/, /inset:\s*0;/, /pointer-events:\s*none;/,
    /opacity:\s*0;/, /visibility:\s*hidden;/]) assert.match(baseRule, declaration);
  const activeRule = shell.match(/#pop-aura\[data-listening="true"\]\s*\{([^}]*)\}/)?.[1];
  assert.ok(activeRule, 'Actual listening reveals the overlay');
  assert.match(activeRule, /opacity:\s*1;/);
  assert.match(activeRule, /visibility:\s*visible;/);
  assert.match(shell, /#pop-aura[^{}]*\{[^}]*animation-play-state:\s*paused;/);
  assert.match(shell, /#pop-aura\[data-listening="true"\][^{}]*\{[^}]*animation-play-state:\s*running;/);
  assert.match(shell, /@media\s*\(prefers-reduced-motion:\s*reduce\)[\s\S]*?#pop-aura[^{}]*\{[^}]*animation:\s*none;/);
  const auraElement = shell.match(/<[^>]*\bid="pop-aura"[^>]*>/)?.[0];
  assert.ok(auraElement, 'The decorative aura is present in the document');
  assert.ok(shell.indexOf(auraElement) < shell.indexOf('function createSpeechHost()'), 'The aura exists before its host captures the element');
  assert.match(auraElement, /\baria-hidden="true"/);
  assert.match(auraElement, /\bdata-listening="false"/);
  assert.match(shell, /id="pop-status"[^>]*role="status"/);
  assert.match(shell, /Winning Match or Memory earns one piece/);
});
