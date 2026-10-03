const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const shell = fs.readFileSync(path.join(__dirname, '..', 'web', 'shell.html'), 'utf8');
const speechWordsSource = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'speech_words.gd'), 'utf8');
const compoundParts = JSON.parse(speechWordsSource.match(/const COMPOUND_PARTS: Dictionary = (\{[\s\S]*?\n\})/)[1]);

function speechEvent(entries, resultIndex = 0) {
  const results = entries.map(([transcript, isFinal]) => Object.assign(
    [{ transcript, confidence: 0.95 }], { isFinal, item(index) { return this[index]; } }
  ));
  results.item = index => results[index];
  return { resultIndex, results };
}

function fixture({ api = 'standard', secure = true, autoStart = true, online = true, synthesis = false, local = false, captureEvents = false } = {}) {
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
    performance: { now: () => now },
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
    constructor() { if (captureEvents) this.onaudiostart = null; instances.push(this); }
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
  if (synthesis) {
    window.SpeechSynthesisUtterance = class { constructor(text) { this.text = text; } };
    window.speechSynthesis = {
      speak(utterance) { spoken.push(utterance); },
      cancel() {}
    };
  }
  const localPreparation = {
    modeForNewRound: () => local ? 'local' : 'browser',
    getState: () => ({ experimentEnabled: local, enabled: local, ready: local,
      capable: local, status: local ? 'ready' : 'disabled', error: '' }),
    setVisible() {}
  };
  const host = vm.runInNewContext(`(${block})()`, {
    window, document, createLocalSpeechPreparation: () => localPreparation
  });
  host.configureSpeechLexicon(JSON.stringify({ compounds: compoundParts, words: [
    { text: 'cat', forms: ['cat', 'cats'] }, { text: 'dog', forms: ['dog', 'dogs'] },
    { text: 'sun', forms: ['sun', 'suns', 'son', 'sons'] }, { text: 'flower', forms: ['flower', 'flowers', 'flour'] },
    { text: 'horse', forms: ['horse', 'horses', 'hoarse'] },
    ...Object.keys(compoundParts).filter(word => !word.endsWith('s') || word === 'sunglasses')
      .map(text => ({ text, forms: Object.keys(compoundParts).filter(form => form === text || form === text + 's') }))
  ] }));
  let popState = { phase: 'running', round_id: 'round-1', vocabulary: ['cat', 'dog', 'sun'], targets: [
    { uid: 1, text: 'cat', forms: ['cat', 'cats'] },
    { uid: 2, text: 'dog', forms: ['dog', 'dogs'] },
    { uid: 3, text: 'sun', forms: ['sun', 'suns', 'son', 'sons'] }
  ] };
  function publishPop(changes = {}) {
    popState = { ...popState, ...changes };
    return host.popStatus(JSON.stringify(popState));
  }
  publishPop();
  const states = [];
  const results = [];
  const popWords = [];
  const popEvents = [];
  host.observePopSpeech(json => {
    assert.equal(typeof json, 'string', 'Pop emits one JSON event as a positional bridge argument');
    const event = JSON.parse(json);
    assert.equal(typeof event.event_id, 'string');
    assert.equal(typeof event.round_id, 'string');
    assert.equal(typeof event.target_uid, 'number');
    assert.equal(typeof event.text, 'string');
    assert.ok(['interim', 'final'].includes(event.stage));
    assert.equal(typeof event.received_at_ms, 'number');
    popEvents.push(event);
    popWords.push(event.text);
    return event.target_uid > 0;
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
    host, document, window, elements, instances, states, results, popWords, popEvents, advance, spoken, publishPop,
    get starts() { return starts; }, get aborts() { return aborts; },
    get pendingTimers() { return timers.size; },
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

test('the mode menu suspends active or pending speech and resumes it only once', () => {
  for (const autoStart of [true, false]) {
    const f = fixture({ autoStart });
    f.host.speechBounds(0.1, 0.2, 0.8, 0.25);
    f.listen();
    const bounds = { ...f.panel.style };
    const old = f.latest;
    const reports = f.states.length;
    assert.equal(f.host.suspendSpeechForMenu(), true);
    assert.equal(f.host.suspendSpeechForMenu(), true);
    assert.equal(f.aborts, 1, 'Repeated menu opens do not abort twice');
    assert.equal(f.panel.hidden, true);
    assert.deepEqual(f.panel.style, bounds, 'Suspension preserves the voice-panel layout');
    assert.equal(f.aura.attributes['data-listening'], 'false');
    old.result([['cat', true]]);
    old.callbacks.start?.();
    old.end();
    f.advance(10000);
    assert.equal(f.results.length, 0, 'Suspended callbacks cannot score or display old speech');
    assert.equal(f.starts, 1);
    assert.equal(f.pendingTimers, 0);
    assert.equal(f.states.length, reports, 'Successful suspension does not change native voice-panel state or focus');
    assert.equal(f.host.resumeSpeechFromMenu(), true);
    assert.equal(f.host.resumeSpeechFromMenu(), true);
    assert.equal(f.starts, 2, 'Only the first dismissal resumes the recognizer');
    assert.equal(f.panel.hidden, false);
    assert.deepEqual(f.panel.style, bounds);
  }
});

test('the mode menu preserves failed Match speech without requesting the microphone again', () => {
  for (const error of ['not-allowed', 'network', 'audio-capture']) {
    const f = fixture();
    f.listen();
    f.latest.error(error);
    const message = f.status.textContent;
    const state = [...f.states.at(-1)];
    assert.equal(f.panel.attributes['data-state'], 'error');
    assert.equal(f.host.suspendSpeechForMenu(), true);
    f.window.dispatch('offline');
    f.advance(10000);
    assert.equal(f.panel.hidden, true, 'An unrelated offline event cannot cover the menu with the speech panel');
    assert.equal(f.host.resumeSpeechFromMenu(), true);
    assert.equal(f.panel.hidden, false);
    assert.equal(f.starts, 1, 'Dismissing the menu does not retry a failed microphone');
    assert.equal(f.panel.attributes['data-state'], 'error');
    assert.equal(f.status.textContent, message);
    assert.deepEqual(f.states.at(-1), state);
  }
});

test('leaving Match voice discards its menu suspension instead of reopening speech later', () => {
  for (const exit of ['stop', 'hide', 'mode']) {
    const f = fixture();
    f.listen();
    assert.equal(f.host.suspendSpeechForMenu(), true);
    if (exit === 'stop') f.host.stopSpeech();
    if (exit === 'hide') {
      f.document.hidden = true;
      f.document.dispatch('visibilitychange');
      f.document.hidden = false;
    }
    if (exit === 'mode') f.host.speechMode(true, 'pop');
    const starts = f.starts;
    assert.equal(f.host.resumeSpeechFromMenu(), true);
    f.advance(1000);
    assert.equal(f.starts, starts, 'A discarded suspension never creates a second microphone');
    assert.equal(f.panel.hidden, true);
  }
});

test('a failed menu suspension keeps the microphone shutdown error visible', () => {
  const f = fixture();
  f.listen();
  f.latest.abort = () => { throw new Error('abort failed'); };
  f.latest.stop = () => { throw new Error('stop failed'); };
  assert.equal(f.host.suspendSpeechForMenu(), false);
  assert.equal(f.panel.hidden, false);
  assert.equal(f.panel.attributes['data-state'], 'error');
  assert.match(f.status.textContent, /close this tab/i);
  assert.equal(f.host.resumeSpeechFromMenu(), true);
  assert.equal(f.starts, 1, 'A failed shutdown never schedules another recognizer');
});

test('the accessible panel is hidden and the exact speech API joins the existing host', () => {
  for (const id of ['speech-panel', 'speech-status', 'speech-transcript', 'speech-notice']) {
    assert.match(shell, new RegExp(`id="${id}"`));
  }
  assert.match(shell, /id="speech-panel"[^>]*hidden/);
  assert.match(shell, /id="speech-panel"[^>]*aria-describedby="speech-notice"/);
  assert.match(shell, /\.\.\.speechHost/);
  const f = fixture();
  for (const method of ['speechAvailable', 'observeSpeech', 'speechMode', 'stopSpeech', 'speechBounds', 'suspendSpeechForMenu', 'resumeSpeechFromMenu']) {
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
  f.latest.result([['', false]]);
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

test('Pop waits 150 ms for a stable interim while final words resolve immediately', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['Cat', false]]);
  f.advance(149);
  assert.deepEqual(f.popWords, [], 'A provisional spelling does not immediately consume a target');
  f.latest.result([['Cat', false]]);
  f.advance(1);
  assert.deepEqual(f.popWords, ['Cat'], 'Unchanged interim updates do not postpone stability forever');
  assert.equal(f.popEvents[0].stage, 'interim');
  assert.equal(f.popEvents[0].received_at_ms, 0, 'The event reports observation time, not fictional audio timing');
  f.latest.result([['Cat dog', true]]);
  assert.deepEqual(f.popWords, ['Cat', 'dog'], 'A final accepts its new word without an extra stability delay');
  assert.equal(f.popEvents[1].stage, 'final');
});

test('Pop preserves occurrences through inserted prefixes, shortening and reexpanded finals', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['Cat', false]]);
  f.advance(150);
  f.latest.result([['the cat', false]]);
  f.advance(150);
  assert.deepEqual(f.popWords, ['Cat'], 'An inserted prefix cannot replay a consumed target word');
  f.latest.result([['the cat dog', false]]);
  f.advance(150);
  f.latest.result([['cat', false]]);
  f.latest.result([['the cat dog', true]]);
  f.latest.result([['the cat dog', true]]);
  f.latest.result([['the cat dog sun', false]]);
  f.advance(150);
  assert.deepEqual(f.popWords, ['Cat', 'dog'], 'Completed result indexes reject late interim revisions too');
  assert.ok(f.results.some(([text, final]) => text === 'the cat dog' && final), 'The original full-transcript callback stays intact');
  f.latest.result([['the cat dog', true], ['cat', false]], 1);
  f.latest.result([['the cat dog', true], ['cat', true]], 1);
  assert.deepEqual(f.popWords, ['Cat', 'dog', 'cat'], 'A new result segment may legitimately repeat a word');
  assert.equal(new Set(f.popEvents.map(event => event.event_id)).size, 3);
});

test('Pop completes a partial candidate without treating substrings or possessives as hits', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['ca', false]]);
  f.advance(100);
  f.latest.result([['cat', false]]);
  f.advance(149);
  assert.deepEqual(f.popWords, []);
  f.advance(1);
  f.latest.result([['cat cat2 _cat caté cat\'s 2cat cat_dog', true]]);
  assert.deepEqual(f.popWords, ['cat'], 'Only the complete target token produces a bound hit event');
  assert.equal(f.results.at(-1)[0], "cat cat2 _cat caté cat's 2cat cat_dog", 'The raw caption remains complete');
  f.latest.result([['cat', true], ['DOGS', true]], 1);
  assert.equal(f.popWords.at(-1), 'DOGS', 'The model receives original case and handles canonical word matching');
});

test('a repeated word in one result segment gets a new occurrence bound to the new target', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['cat', false]]);
  f.advance(150);
  f.publishPop({ targets: [{ uid: 8, text: 'cat', forms: ['cat', 'cats'] }] });
  f.latest.result([['cat cat', false]]);
  f.advance(150);
  f.latest.result([['cat cats', true]]);
  assert.deepEqual(f.popWords, ['cat', 'cat']);
  assert.deepEqual(f.popEvents.map(event => event.target_uid), [1, 8]);
  assert.notEqual(f.popEvents[0].event_id, f.popEvents[1].event_id);
});

test('a spelling substitution cannot consume two targets for one spoken occurrence', () => {
  const f = fixture();
  f.publishPop({ targets: [{ uid: 1, text: 'cat' }, { uid: 2, text: 'bat' }] });
  f.listen('pop');
  f.latest.result([['cat', false]]);
  f.advance(150);
  f.latest.result([['bat', true]]);
  assert.deepEqual(f.popWords, ['cat']);
  assert.deepEqual(f.results.at(-1), ['bat', true], 'A correction still updates the displayed transcript');
});

test('a correction before stability may resolve the same unconsumed occurrence', () => {
  const f = fixture();
  f.publishPop({ targets: [{ uid: 1, text: 'cat' }, { uid: 2, text: 'bat' }] });
  f.listen('pop');
  f.latest.result([['cat', false]]);
  f.advance(100);
  f.latest.result([['bat', false]]);
  f.advance(149);
  assert.deepEqual(f.popWords, []);
  f.advance(1);
  assert.deepEqual(f.popWords, ['bat']);
  assert.equal(f.popEvents[0].target_uid, 2);
});

test('reordering already consumed occurrences cannot hit replacement targets', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['cat dog', false]]);
  f.advance(150);
  f.publishPop({ targets: [{ uid: 10, text: 'cat' }, { uid: 11, text: 'dog' }] });
  f.latest.result([['dog cat', true]]);
  assert.deepEqual(f.popWords, ['cat', 'dog']);
  assert.deepEqual(f.popEvents.map(event => event.target_uid), [1, 2]);
});

test('a candidate first heard without a target cannot score a later spawn', () => {
  for (const initial of ['cat', 'ca']) {
    const f = fixture();
    f.publishPop({ targets: [] });
    f.listen('pop');
    f.latest.result([[initial, false]]);
    f.publishPop({ targets: [{ uid: 9, text: 'cat' }] });
    f.latest.result([['cat', true]]);
    assert.equal(f.popEvents.filter(event => event.target_uid > 0).length, 0, initial);
    assert.equal(f.popEvents.at(-1).target_uid, 0, 'An unmatched final supplies feedback without inventing a target');
  }
});

test('a target expiring during stability cannot be replaced by a fresh copy', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['cat', false]]);
  f.advance(149);
  f.publishPop({ targets: [{ uid: 9, text: 'cat' }] });
  f.advance(1);
  f.latest.result([['cat', true]]);
  assert.deepEqual(f.popEvents, []);
  assert.ok(f.host.speechDiagnostics().counts.expired_target >= 1);
});

test('pending candidates are cancelled on end, stop, background and round changes', () => {
  for (const action of ['end', 'stop', 'background', 'round', 'removed-result']) {
    const f = fixture();
    f.listen('pop');
    f.latest.result([['cat', false]]);
    if (action === 'end') f.latest.end();
    else if (action === 'stop') f.host.stopSpeech();
    else if (action === 'background') { f.document.hidden = true; f.document.dispatch('visibilitychange'); }
    else if (action === 'round') f.publishPop({ round_id: 'round-2' });
    else f.latest.result([]);
    f.advance(150);
    assert.deepEqual(f.popEvents, [], action);
  }
});

function rotatingWord(index) {
  return 'word' + String.fromCharCode(97 + Math.floor(index / 676),
    97 + Math.floor(index / 26) % 26, 97 + index % 26);
}

test('bounded revision history retires a long segment and cancels its pending target', () => {
  const f = fixture();
  f.listen('pop');
  const prefix = Array.from({ length: 31 }, (_, index) => rotatingWord(index));
  f.latest.result([[prefix.concat('cat').join(' '), false]]);
  for (let revision = 31; revision < 551; revision++) {
    prefix.shift();
    prefix.push(rotatingWord(revision));
    f.latest.result([[prefix.concat('cat').join(' '), false]]);
  }
  assert.equal(f.host.speechDiagnostics().counts.segment_limit, 1,
    'Repeated short hypotheses cannot grow deleted occurrence history without a bound');
  f.advance(150);
  f.latest.result([['cat', true]]);
  f.latest.result([['cat', true]]);
  assert.deepEqual(f.popEvents, [], 'The retired pending occurrence and its final cannot replay');
  f.latest.result([['cat', true], ['cat', true]], 1);
  assert.deepEqual(f.popWords, ['cat'], 'A fresh result index remains playable after the oversized segment');
});

test('retiring at the history limit also cancels a candidate created by the final insertion', () => {
  const f = fixture();
  f.listen('pop');
  const prefix = Array.from({ length: 32 }, (_, index) => rotatingWord(index));
  f.latest.result([[prefix.join(' '), false]]);
  for (let revision = 32; revision < 512; revision++) {
    prefix.shift();
    prefix.push(rotatingWord(revision));
    f.latest.result([[prefix.join(' '), false]]);
  }
  assert.equal(f.host.speechDiagnostics().counts.segment_limit, undefined);
  f.latest.result([[prefix.concat('cat').join(' '), false]]);
  assert.equal(f.host.speechDiagnostics().counts.segment_limit, 1);
  f.advance(150);
  assert.deepEqual(f.popEvents, [], 'A newly allocated slot cannot outlive the segment that retired it');
});

test('more than 256 live words retire the segment without truncating it into fresh hits', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['cat', false]]);
  const oversized = Array.from({ length: 256 }, (_, index) => rotatingWord(index)).concat('cat').join(' ');
  f.latest.result([[oversized, false]]);
  f.latest.result([[oversized, false]]);
  assert.equal(f.host.speechDiagnostics().counts.segment_limit, 1);
  f.advance(150);
  f.latest.result([['cat', true]]);
  assert.deepEqual(f.popEvents, []);
  f.latest.result([['cat', true], ['cat', true]], 1);
  assert.deepEqual(f.popWords, ['cat']);
});

test('native rejection leaves an occurrence unconsumed for a valid final acknowledgement', () => {
  const f = fixture();
  const attempted = [];
  f.host.observePopSpeech(json => { attempted.push(JSON.parse(json)); return attempted.length > 1; });
  f.listen('pop');
  f.latest.result([['cat', false]]);
  f.advance(150);
  f.latest.result([['cat', true]]);
  f.latest.result([['cat', true]]);
  assert.equal(attempted.length, 2);
  assert.equal(attempted[0].event_id, attempted[1].event_id);
  assert.deepEqual(attempted.map(event => event.stage), ['interim', 'final']);
});

test('the Godot bridge acknowledges through a receipt when Callable return values are discarded', () => {
  const f = fixture();
  const attempted = [];
  f.host.observePopSpeech((json, receipt) => {
    attempted.push(JSON.parse(json));
    assert.equal(receipt.accepted, false);
    receipt.accepted = true;
    // The actual Godot JavaScriptBridge callback returns undefined.
  });
  f.listen('pop');
  f.latest.result([['cat', false]]);
  f.advance(150);
  f.publishPop({ targets: [{ uid: 9, text: 'cat' }, { uid: 10, text: 'dog' }] });
  f.latest.result([['dog', true]]);
  assert.equal(attempted.length, 1, 'Acknowledged speech stays consumed across a corrected final');
  assert.equal(f.host.speechDiagnostics().counts.hit, 1);
  assert.equal(f.host.speechDiagnostics().counts.game_rejected, undefined);
  f.latest.result([['dog', true], ['cat', true]], 1);
  assert.equal(attempted.length, 2);
  assert.equal(attempted[1].target_uid, 9);
});

test('a rejected bridge receipt cannot consume speech and each retry receives a fresh receipt', () => {
  const f = fixture();
  const attempts = [], receipts = [];
  f.host.observePopSpeech((json, receipt) => {
    attempts.push(JSON.parse(json));
    receipts.push(receipt);
    receipt.accepted = attempts.length > 1;
  });
  f.listen('pop');
  f.latest.result([['cat', false]]);
  f.advance(150);
  f.latest.result([['cat', true]]);
  assert.equal(attempts.length, 2);
  assert.equal(attempts[0].event_id, attempts[1].event_id);
  assert.notEqual(receipts[0], receipts[1]);
  assert.equal(f.host.speechDiagnostics().counts.game_rejected, 1);
  assert.equal(f.host.speechDiagnostics().counts.hit, 1);
});

test('Pop joins a spoken yo yo before tokenization and preserves its original caption', () => {
  for (const text of ['yo yo', 'YO-YO', 'yo yos']) {
    const f = fixture();
    f.publishPop({ targets: [{ uid: 9, text: 'yoyo', forms: ['yoyo', 'yoyos'] }] });
    f.listen('pop');
    f.latest.result([[text, true]]);
    assert.equal(f.popEvents.length, 1);
    assert.equal(f.popEvents[0].target_uid, 9);
    assert.equal(f.popWords[0], text.endsWith('s') ? 'yoyos' : 'yoyo');
    assert.deepEqual(f.results.at(-1), [text, true]);
  }
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
  f.publishPop({ targets });
  f.latest.result([['ca', false]]);
  f.latest.result([['cat mouse buses', false]]);
  f.advance(150);
  f.publishPop({ targets: [] });
  f.latest.result([['cats mice bus', true]]);
  assert.deepEqual(f.popWords, ['cat', 'mouse', 'buses']);
  assert.equal(f.popStatus.attributes['data-targets'], '[]', 'Only currently displayed target geometry is exposed');
  f.publishPop({ targets: [{ uid: 10, text: 'cat', forms: ['cat', 'cats'] }] });
  f.latest.result([['cats mice bus', true], ['cats', true]], 1);
  assert.deepEqual(f.popWords, ['cat', 'mouse', 'buses', 'cats'], 'New utterances may repeat any accepted noun form');
});

test('Pop homophone revisions share one utterance even after that word is thrown again', () => {
  const f = fixture();
  f.listen('pop');
  const forms = ['bear', 'bears', 'bare', 'bares'];
  f.publishPop({ targets: [{ uid: 7, text: 'bear', forms }] });
  f.latest.result([['BARE', false]]);
  f.advance(150);
  assert.deepEqual(f.popWords, ['BARE'], 'The initial homophone is sent unchanged to canonical model matching');
  f.publishPop({ targets: [] });
  f.latest.result([['bear', false]]);
  f.publishPop({ targets: [{ uid: 8, text: 'bear', forms }] });
  f.latest.result([['bears', false]]);
  f.latest.result([['bares', true]]);
  f.latest.result([['bare bear', false]]);
  assert.deepEqual(f.popWords, ['BARE'], 'Canonical, plural, and late-final revisions cannot hit the replacement target');
  assert.ok(f.results.some(([text, final]) => text === 'bares' && final), 'Full recognized text remains available to the HUD');
  f.latest.result([['bares', true], ['bare', false]], 1);
  f.advance(150);
  f.latest.result([['bares', true], ['bear', true]], 1);
  assert.deepEqual(f.popWords, ['BARE', 'bare'], 'Only a new utterance can hit the later bear');
});

test('noun metadata arriving after first observation cannot retarget that old occurrence', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['mice', false]]);
  f.publishPop({ targets: [{ uid: 8, text: 'mouse', forms: ['mouse', 'mice'] }] });
  f.latest.result([['mouse', true]]);
  assert.equal(f.popEvents.filter(event => event.target_uid > 0).length, 0);
});

test('a Pop hit that ends the round rejects remaining words and all stale browser callbacks', () => {
  const f = fixture();
  const delivered = [];
  f.host.observePopSpeech(json => { delivered.push(JSON.parse(json).text); f.host.stopSpeech(); return true; });
  f.listen('pop');
  const old = f.latest;
  old.result([['cat dog ball', true], ['sun', true]]);
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
  const payload = { phase: 'playing', remaining: 19.3, base_duration: 50, bonus_time: 8, hits: 4, score: 90, combo: 2, best_combo: 3,
    targets: [{ uid: 7, text: 'cat', x: 31, y: 118, width: 103, height: 77, age: 1.2, spawned_at: 29.5, secret: 'discard' }],
    controls: [{ name: 'EndPop', text: 'Finish', x: 300, y: 15, width: 52, height: 44, disabled: false, action: 'discard' }],
    message: 'Nice pop!' };
  assert.equal(f.host.popStatus(JSON.stringify(payload)), true);
  assert.equal(f.popStatus.attributes['data-phase'], 'playing');
  assert.equal(f.popStatus.attributes['data-remaining'], '20');
  assert.equal(f.popStatus.attributes['data-hits'], '4');
  assert.equal(f.popStatus.attributes['data-score'], '90');
  assert.equal(f.popStatus.attributes['data-best-combo'], '3');
  assert.equal(f.popStatus.attributes['data-combo'], '2');
  assert.equal(f.popStatus.attributes['data-base-duration'], '50');
  assert.equal(f.popStatus.attributes['data-bonus-time'], '8');
  assert.deepEqual(JSON.parse(f.popStatus.attributes['data-targets']), [{ uid: 7, text: 'cat', x: 31, y: 118, width: 103, height: 77, age: 1.2, spawned_at: 29.5 }]);
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
  assert.equal(f.popStatus.attributes['data-combo'], '0');
  assert.equal(f.popStatus.attributes['data-bonus-time'], '0');
  assert.equal(f.starts, 0, 'Publishing the UI snapshot cannot start speech or mutate gameplay');
});

test('Pop publishes only changed diagnostic fields while keeping live speech bindings current', () => {
  const f = fixture();
  const writes = [];
  const setAttribute = f.popStatus.setAttribute;
  f.popStatus.setAttribute = function(name, value) {
    writes.push(name);
    setAttribute.call(this, name, value);
  };
  const payload = { phase: 'running', round_id: 'deduplicated-round', remaining: 20, hits: 0, score: 0,
    targets: [{ uid: 7, text: 'cat', forms: ['cat'], x: 31, y: 118, width: 103, height: 77, age: 1.2 }] };
  f.host.popStatus(JSON.stringify(payload));
  writes.length = 0;
  f.host.popStatus(JSON.stringify(payload));
  assert.deepEqual(writes, [], 'An identical snapshot produces no DOM attribute mutations');
  payload.targets[0].y = 119;
  payload.targets[0].age = 1.3;
  f.host.popStatus(JSON.stringify(payload));
  assert.deepEqual(writes, ['data-targets'], 'Motion leaves unchanged counters, controls and result fields alone');
  writes.length = 0;
  payload.hits = 1;
  payload.score = 100;
  f.host.popStatus(JSON.stringify(payload));
  assert.deepEqual(writes, ['data-hits', 'data-score']);
  writes.length = 0;
  payload.targets[0].forms.push('cats');
  f.host.popStatus(JSON.stringify(payload));
  assert.deepEqual(writes, [], 'Accepted forms can change without changing diagnostic geometry');
  f.listen('pop');
  f.latest.result([['cats', true]]);
  assert.equal(f.popEvents.at(-1).target_uid, 7, 'Deduplication never skips current speech target bindings');
  f.host.stopSpeech();
  writes.length = 0;
  f.host.popStatus(JSON.stringify({ phase: 'idle' }));
  assert.equal(f.popStatus.attributes['data-hits'], '0');
  assert.equal(f.popStatus.attributes['data-score'], '0');
  assert.equal(f.popStatus.attributes['data-targets'], '[]');
  assert.ok(writes.includes('data-phase'), 'Returning to idle still publishes the reset');
  writes.length = 0;
  f.host.popStatus(JSON.stringify({ phase: 'idle' }));
  assert.deepEqual(writes, []);
});

test('Pop snapshots sanitize streak bonuses, volley timing and the time bonus popup', () => {
  const f = fixture();
  f.host.popStatus(JSON.stringify({ phase: 'running', base_duration: -50, bonus_time: 'Infinity', combo: -2,
    targets: [{ text: 'cat', age: -1, spawned_at: 'invalid' }],
    hud: { time_bonus: { text: '+8s', x: 10, y: 22, width: 70, height: 30, private: 'discard' },
      time_bonus_caption: { text: 'TIME BONUS', x: 10, y: 56, width: 140, height: 18, private: 'discard' },
      bonus_effect: { serial: 2.9, active: true, amount: 8, awards: [3, 5, '3', null, -1, 'Infinity'],
        reduced_motion: true, duration: 1.8, above_targets: true, private: 'discard' } } }));
  assert.equal(f.popStatus.attributes['data-base-duration'], '0');
  assert.equal(f.popStatus.attributes['data-bonus-time'], '0');
  assert.equal(f.popStatus.attributes['data-combo'], '0');
  assert.deepEqual(JSON.parse(f.popStatus.attributes['data-targets']),
    [{ uid: '', text: 'cat', x: 0, y: 0, width: 0, height: 0, age: 0, spawned_at: 0 }]);
  const hud = JSON.parse(f.popStatus.attributes['data-hud']);
  assert.deepEqual(hud.time_bonus, { text: '+8s', x: 10, y: 22, width: 70, height: 30 });
  assert.deepEqual(hud.time_bonus_caption, { text: 'TIME BONUS', x: 10, y: 56, width: 140, height: 18 });
  assert.deepEqual(hud.bonus_effect, { serial: 2, active: true, amount: 8, awards: [3, 5], reduced_motion: true,
    duration: 1.8, above_targets: true });
  f.host.popStatus(JSON.stringify({ phase: 'running', hud: {
    time_bonus_caption: { text: 23, x: 'Infinity', y: 'invalid', width: -40, height: 'Infinity' },
    bonus_effect: { duration: 'Infinity', above_targets: 'true' }
  } }));
  const invalid = JSON.parse(f.popStatus.attributes['data-hud']);
  assert.deepEqual(invalid.time_bonus_caption, { text: '', x: 0, y: 0, width: 0, height: 0 });
  assert.equal(invalid.bonus_effect.duration, 0);
  assert.equal(invalid.bonus_effect.above_targets, false);
  f.host.popStatus(JSON.stringify({ phase: 'idle' }));
  const cleared = JSON.parse(f.popStatus.attributes['data-hud']);
  assert.deepEqual(cleared.bonus_effect,
    { serial: 0, active: false, amount: 0, awards: [], reduced_motion: false, duration: 0, above_targets: false });
  assert.deepEqual(cleared.time_bonus_caption, { text: '', x: 0, y: 0, width: 0, height: 0 });
});

test('Pop snapshots expose full live speech and result state without repeating interim text in the live region', () => {
  const f = fixture();
  let writes = 0, readable = '';
  Object.defineProperty(f.popStatus, 'textContent', {
    get() { return readable; }, set(value) { readable = value; writes++; }
  });
  const state = { phase: 'running', remaining: 24, transcript: 'I see a ca', transcript_final: false,
    results_hits: { text: '2', total: 4, active: true, private: 'discard' },
    results_scroll: 14.5, results_scroll_max: 96, results_scrollbar_visible: false };
  f.host.popStatus(JSON.stringify(state));
  assert.equal(f.popStatus.attributes['data-transcript'], 'I see a ca');
  assert.equal(f.popStatus.attributes['data-transcript-final'], 'false');
  assert.deepEqual(JSON.parse(f.popStatus.attributes['data-results-hits']), { text: '2', total: 4, active: true, player: {}, rect: [] });
  assert.equal(f.popStatus.attributes['data-results-scroll'], '14.5');
  assert.equal(f.popStatus.attributes['data-results-scroll-max'], '96');
  assert.equal(f.popStatus.attributes['data-results-scrollbar-visible'], 'false');
  f.host.popStatus(JSON.stringify({ ...state, transcript: 'I see a cat', transcript_final: true,
    results_hits: { text: '4', total: 4, active: false }, results_scroll: 38, results_scrollbar_visible: true }));
  assert.equal(f.popStatus.attributes['data-transcript'], 'I see a cat');
  assert.equal(f.popStatus.attributes['data-transcript-final'], 'true');
  assert.equal(f.popStatus.attributes['data-results-scrollbar-visible'], 'true');
  assert.equal(writes, 1, 'Transcription, counter animation and scrolling cannot interrupt the game announcement');
  assert.doesNotMatch(readable, /I see/);
  f.host.popStatus(JSON.stringify({ phase: 'idle' }));
  assert.equal(f.popStatus.attributes['data-transcript'], '');
  assert.equal(f.popStatus.attributes['data-transcript-final'], 'false');
  assert.deepEqual(JSON.parse(f.popStatus.attributes['data-results-hits']), { text: '', total: 0, active: false, player: {}, rect: [] });
  assert.equal(f.popStatus.attributes['data-results-scroll'], '0');
  assert.equal(f.popStatus.attributes['data-results-scroll-max'], '0');
});

test('Pop result snapshots sanitize the hit animation and announce only the final hit total', () => {
  const f = fixture();
  const result = { phase: 'finished', hits: 4, score: 90, best_combo: 3,
    message: 'Round complete. Tap a word to hear it, or play again.',
    results_hits: { text: '4', total: 4.9, active: true, private: 'discard' } };
  f.host.popStatus(JSON.stringify(result));
  assert.deepEqual(JSON.parse(f.popStatus.attributes['data-results-hits']), { text: '4', total: 4, active: true, player: {}, rect: [] });
  assert.match(f.popStatus.textContent, /Round complete.*Voice Pop\. 4 hits\./);
  assert.doesNotMatch(f.popStatus.textContent, /Score|combo|seconds/);
  assert.equal(Object.keys(f.popStatus.attributes).some(name => name.startsWith('data-report')), false);
  for (const malformed of [null, [], '4', { text: '<script>', total: 'Infinity', active: 'true' },
    { text: '1'.repeat(17), total: -5, active: 1 }]) {
    f.host.popStatus(JSON.stringify({ ...result, results_hits: malformed }));
    assert.deepEqual(JSON.parse(f.popStatus.attributes['data-results-hits']), { text: '', total: 0, active: false, player: {}, rect: [] });
  }
});

test('Pop results preserve the chosen player and layout while clearing stale identity on replay', () => {
  const f = fixture();
  const player = { id: 'player-a', name: 'Avery', avatar: 'fox', rect: [20, 40, 180, 56],
    avatar_rect: [20, 40, 56, 56], name_rect: [86, 40, 114, 56] };
  const results_hits = { text: '8', total: 8, active: false, rect: [220, 20, 120, 96],
    player: { ...player, private: 'discard' } };
  f.host.popStatus(JSON.stringify({ phase: 'finished', hits: 8, results_hits }));
  assert.deepEqual(JSON.parse(f.popStatus.attributes['data-results-hits']), { ...results_hits, player });
  assert.match(f.popStatus.textContent, /Voice Pop\. Avery\. 8 hits\./);
  f.host.popStatus(JSON.stringify({ phase: 'running', results_hits }));
  const replay = JSON.parse(f.popStatus.attributes['data-results-hits']);
  assert.deepEqual(replay.player, {});
  assert.deepEqual(replay.rect, []);
  assert.doesNotMatch(f.popStatus.textContent, /Avery/);
  for (const invalid of [null, [], 'Avery', { id: 'a', name: 2, avatar: 'fox' }]) {
    f.host.popStatus(JSON.stringify({ phase: 'finished', results_hits: { ...results_hits, player: invalid } }));
    assert.deepEqual(JSON.parse(f.popStatus.attributes['data-results-hits']).player, {});
  }
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
  assert.match(shell, /html\[data-reduced-motion="true"\] #pop-aura[^{}]*\{[^}]*animation:\s*none;/);
  const auraElement = shell.match(/<[^>]*\bid="pop-aura"[^>]*>/)?.[0];
  assert.ok(auraElement, 'The decorative aura is present in the document');
  assert.ok(shell.indexOf(auraElement) < shell.indexOf('function createSpeechHost()'), 'The aura exists before its host captures the element');
  assert.match(auraElement, /\baria-hidden="true"/);
  assert.match(auraElement, /\bdata-listening="false"/);
  assert.match(shell, /id="pop-status"[^>]*role="status"/);
  assert.match(shell, /Match: find five matching word and picture pairs/);
});

function enablePhraseHints(f) {
  f.window.SpeechRecognition.prototype.phrases = [];
  f.window.SpeechRecognitionPhrase = class {
    constructor(phrase, boost) { this.phrase = phrase; this.boost = boost; }
  };
  f.publishPop({ vocabulary: ['cat', 'SUN', 'cat', 'bad phrase', null], targets: [
    { uid: 1, text: 'cat' }, { uid: 3, text: 'sun' }
  ] });
}

test('local Voice Pop weights live targets above the complete lesson vocabulary', () => {
  const f = fixture({ local: true });
  enablePhraseHints(f);
  f.publishPop({ targets: [{ uid: 1, text: 'cat' }] });
  f.listen('pop');
  assert.equal(f.latest.processLocally, true);
  assert.deepEqual(Array.from(f.latest.phrases, value => [value.phrase, value.boost]), [['cat', 4], ['sun', 1]]);
  f.publishPop({ targets: [{ uid: 3, text: 'sun' }] });
  assert.deepEqual(Array.from(f.latest.phrases, value => [value.phrase, value.boost]), [['cat', 1], ['sun', 4]]);
  assert.equal(f.starts, 1, 'Changing active target hints does not restart the microphone');
  f.latest.result([['hello', true]]);
  assert.deepEqual(f.popWords, ['hello']);
  assert.equal(f.popEvents[0].target_uid, 0, 'Hints do not rewrite unrelated recognition into a target');
  f.host.stopSpeech();
  f.publishPop({ phase: 'ready', round_id: 'round-2', vocabulary: ['pear'], targets: [] });
  f.listen('pop');
  assert.deepEqual(Array.from(f.latest.phrases, value => value.phrase), ['pear'], 'A new lesson replaces old hints');
});

test('local phrase hints include every eligible word in the real 148, 260 and 350 word pools', () => {
  const words = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'words.json'), 'utf8'));
  const levels = { basic: 1, growing: 2, advanced: 3 };
  for (const [maximum, expected] of [[1, 148], [2, 260], [3, 350]]) {
    const f = fixture({ local: true });
    enablePhraseHints(f);
    const vocabulary = words.filter(word => levels[word.level] <= maximum).map(word => word.text);
    assert.equal(vocabulary.length, expected);
    const last = vocabulary.at(-1);
    f.publishPop({ vocabulary, targets: [{ uid: 10, text: last }] });
    f.listen('pop');
    const phrases = Array.from(f.latest.phrases, value => [value.phrase, value.boost]);
    assert.equal(phrases.length, expected, 'No silent first-200 truncation');
    assert.deepEqual(phrases.map(([word]) => word), [...vocabulary].sort());
    assert.equal(phrases.find(([word]) => word === last)[1], 4);
    assert.equal(phrases.find(([word]) => word === 'cat')[1], 1);
  }
});

test('ordinary browser recognition receives no local-only phrase hints even when the API exists', () => {
  const f = fixture();
  enablePhraseHints(f);
  f.listen('pop');
  assert.equal(Object.hasOwn(f.latest, 'phrases'), false);
  assert.equal(f.latest.processLocally, undefined);
  f.latest.result([['cat', true]]);
  assert.deepEqual(f.popWords, ['cat']);
});

test('browsers without contextual phrases retain normal Voice Pop recognition', () => {
  const f = fixture({ api: 'prefixed' });
  f.publishPop({ vocabulary: ['cat'] });
  f.listen('pop');
  assert.equal(f.starts, 1);
  assert.equal('phrases' in f.latest, false);
  f.latest.result([['cat', true]]);
  assert.deepEqual(f.popWords, ['cat']);
});

test('a service rejecting contextual phrases retries once without them and fences old results', () => {
  const f = fixture({ local: true });
  enablePhraseHints(f);
  f.listen('pop');
  const old = f.latest;
  old.error('phrases-not-supported');
  assert.equal(f.aborts, 1);
  old.result([['cat', true]]);
  assert.deepEqual(f.popWords, []);
  f.advance(400);
  assert.equal(f.starts, 2);
  assert.equal(Object.hasOwn(f.latest, 'phrases'), false);
  assert.equal(f.states.at(-1)[1], true);
  f.latest.result([['cat', true]]);
  assert.deepEqual(f.popWords, ['cat']);
  f.latest.error('phrases-not-supported');
  f.advance(5000);
  assert.equal(f.starts, 2, 'A repeated service failure cannot create an unbounded retry loop');
});

test('a browser rejecting the phrase setter falls back before opening the microphone', () => {
  const f = fixture({ local: true });
  enablePhraseHints(f);
  Object.defineProperty(f.window.SpeechRecognition.prototype, 'phrases', {
    configurable: true, get() { return []; }, set() { throw new Error('Experimental API is disabled'); }
  });
  f.listen('pop');
  assert.equal(f.starts, 1);
  assert.equal(f.states.at(-1)[1], true);
  f.latest.result([['sun', true]]);
  assert.deepEqual(f.popWords, ['sun']);
});

test('a synchronous NotSupportedError from biased start falls back and ordinary Match has no hints', () => {
  const f = fixture({ local: true });
  enablePhraseHints(f);
  const start = f.window.SpeechRecognition.prototype.start;
  f.window.SpeechRecognition.prototype.start = function () {
    if (Object.hasOwn(this, 'phrases')) throw Object.assign(new Error('Unsupported hints'), { name: 'NotSupportedError' });
    return start.call(this);
  };
  f.host.speechMode(true, 'pop');
  f.advance(400);
  assert.equal(f.starts, 1);
  assert.equal(f.states.at(-1)[1], true);
  f.latest.result([['cat', true]]);
  assert.deepEqual(f.popWords, ['cat']);

  const match = fixture({ local: true });
  enablePhraseHints(match);
  match.listen('match');
  assert.equal(Object.hasOwn(match.latest, 'phrases'), false);
});

test('homophone revisions cannot replay an already consumed Voice Pop target', () => {
  const f = fixture();
  f.listen('pop');
  f.publishPop({ targets: [
    { uid: 1, text: 'sun', forms: ['sun', 'suns', 'son', 'sons'] }
  ] });
  f.latest.result([['sun', false]]);
  f.advance(150);
  f.publishPop({ targets: [] });
  f.latest.result([['son', false]]);
  f.publishPop({ targets: [
    { uid: 2, text: 'sun', forms: ['sun', 'suns', 'son', 'sons'] }
  ] });
  f.latest.result([['sons', true]]);
  assert.deepEqual(f.popWords, ['sun']);
  f.latest.result([['sons', true], ['son', true]], 1);
  assert.deepEqual(f.popWords, ['sun', 'son'], 'A genuinely new result can score a new throw');
});

test('an empty final Voice Pop hypothesis supplies one unclear-speech notification without restarting', () => {
  const f = fixture();
  f.listen('pop');
  const states = f.states.length;
  f.latest.result([['', false]]);
  assert.deepEqual(f.popWords, []);
  f.latest.result([['...', true]]);
  f.latest.result([['...', true]]);
  assert.deepEqual(f.popWords, ['']);
  assert.deepEqual(f.results, [['...', true]], 'Raw text is presented once');
  assert.equal(f.states.length, states);
  assert.equal(f.starts, 1);
});

test('Voice Pop defaults to system recognition without loading custom models or voice profiles', () => {
  assert.doesNotMatch(shell, /(?:src|href)="(?:multiplayer|voice-profiles)[^"]*"/);
  for (const api of ['standard', 'prefixed']) {
    const f = fixture({ api });
    assert.deepEqual(Object.keys(f.host).sort(), ['beginSpeechPractice', 'configureSpeechLexicon', 'endSpeechPractice',
      'observePopSpeech', 'observeQuestSpeech', 'observeSpeech', 'popStatus', 'practiceTarget', 'practiceWords', 'questTarget', 'questTargets',
      'resumeSpeechFromMenu', 'setSpeechDiagnostics', 'speechAvailable', 'speechBounds', 'speechDiagnostics', 'speechMode', 'stopSpeech',
      'suspendSpeechForMenu']);
    f.listen('pop');
    assert.equal(f.starts, 1);
    assert.equal(f.latest.lang, 'en-US');
    assert.equal(f.latest.maxAlternatives, 3);
    assert.equal(f.latest.processLocally, undefined);
    assert.equal(f.states.at(-1)[1], true);
    f.latest.result([['cat', true]]);
    assert.deepEqual(f.popWords, ['cat']);
    assert.match(f.notice.textContent, /remotely/i);
    f.host.stopSpeech();
    assert.equal(f.aborts, 1);
    assert.equal(f.aura.attributes['data-listening'], 'false');
  }
});

test('alternative hypotheses are diagnostic only and cannot combine into extra hits', () => {
  const f = fixture();
  f.host.setSpeechDiagnostics(true);
  f.listen('pop');
  const result = Object.assign([
    { transcript: 'cat', confidence: 0.7 },
    { transcript: 'dog', confidence: 0.6 },
    { transcript: 'sun', confidence: 0.5 }
  ], { isFinal: true });
  f.latest.callbacks.result({ resultIndex: 0, results: [result] });
  assert.deepEqual(f.popWords, ['cat']);
  const diagnostic = f.host.speechDiagnostics().records.find(record => record.type === 'result');
  assert.deepEqual(JSON.parse(JSON.stringify(diagnostic.alternatives)), result.map(({ transcript: text, confidence }) => ({ text, confidence })));
  const unbound = fixture();
  unbound.listen('pop');
  unbound.latest.callbacks.result({ resultIndex: 0, results: [Object.assign([
    { transcript: 'cap', confidence: 0.7 }, { transcript: 'cat', confidence: 0.6 }
  ], { isFinal: true })] });
  assert.deepEqual(unbound.popWords, ['cap']);
  assert.equal(unbound.popEvents[0].target_uid, 0, 'A lower-ranked target must not turn an unrelated best hypothesis into a hit');
});

test('recognition diagnostics retain transcript alternatives only after explicit opt-in', () => {
  const f = fixture();
  f.listen('pop');
  f.latest.result([['private first sentence', true]]);
  const ordinary = f.host.speechDiagnostics();
  assert.equal(ordinary.enabled, false);
  assert.deepEqual(Array.from(ordinary.records), []);
  assert.equal(ordinary.counts.result, 1);
  assert.doesNotMatch(JSON.stringify(ordinary), /private first sentence/);
  f.host.setSpeechDiagnostics(true);
  f.latest.result([['private first sentence', true], ['cat', true]], 1);
  assert.ok(f.host.speechDiagnostics().records.some(record => record.type === 'result' && record.alternatives[0].text === 'cat'));
  f.host.setSpeechDiagnostics(false);
  f.latest.result([['private first sentence', true], ['cat', true], ['private last sentence', true]], 2);
  const cleared = f.host.speechDiagnostics();
  assert.deepEqual(Array.from(cleared.records), []);
  assert.doesNotMatch(JSON.stringify(cleared), /private|sentence/);
});

test('capture-aware recognition waits for audio, while a valid result can prove capture started', () => {
  for (const evidence of ['audiostart', 'result']) {
    const f = fixture({ captureEvents: true });
    f.listen('pop');
    assert.deepEqual(f.states.at(-1).slice(0, 2), [true, false]);
    assert.match(f.states.at(-1)[2], /waiting for microphone audio/i);
    f.latest.result([['', false]]);
    assert.equal(f.aura.attributes['data-listening'], 'false');
    f.advance(7999);
    if (evidence === 'audiostart') f.latest.onaudiostart();
    else f.latest.result([['cat', false]]);
    assert.deepEqual(f.states.at(-1).slice(0, 2), [true, true]);
    f.advance(1000);
    assert.equal(f.starts, 1);
    assert.equal(f.host.speechDiagnostics().counts.capture_timeout, undefined);
  }
});

test('capture startup timeout is actionable and old audio events cannot unlock a later session', () => {
  const f = fixture({ captureEvents: true });
  f.listen('pop');
  const lateAudio = f.latest.onaudiostart;
  f.advance(8000);
  assert.deepEqual(f.states.at(-1).slice(0, 2), [true, false]);
  assert.match(f.states.at(-1)[2], /microphone audio did not start/i);
  assert.equal(f.aborts, 1);
  f.host.stopSpeech();
  f.listen('pop');
  lateAudio();
  assert.equal(f.aura.attributes['data-listening'], 'false');
  f.latest.onaudiostart();
  assert.equal(f.aura.attributes['data-listening'], 'true');
});

test('a synchronous native stop during capture startup leaves no watchdog behind', () => {
  const f = fixture({ captureEvents: true });
  f.host.observeSpeech(() => {}, (_enabled, _listening, message) => {
    if (message === 'Waiting for microphone audio...') f.host.stopSpeech();
  });
  f.listen('pop');
  assert.equal(f.panel.attributes['data-state'], 'off');
  assert.equal(f.aborts, 1);
  assert.equal(f.pendingTimers, 0);
  f.advance(8000);
  assert.equal(f.starts, 1);
  assert.equal(f.host.speechDiagnostics().counts.capture_timeout, undefined);
});

test('audio lifecycle and cancelled candidates carry session IDs only in opted-in diagnostics', () => {
  const f = fixture({ captureEvents: true });
  f.host.setSpeechDiagnostics(true);
  f.listen('pop');
  for (const name of ['audiostart', 'soundstart', 'speechstart', 'speechend', 'soundend', 'nomatch', 'audioend']) {
    f.latest['on' + name]();
  }
  f.latest.result([['cat', false]]);
  f.advance(149);
  f.latest.end();
  const records = f.host.speechDiagnostics().records;
  for (const type of ['service_start', 'audiostart', 'soundstart', 'speechstart', 'speechend', 'soundend', 'nomatch',
    'audioend', 'session_end']) assert.ok(records.some(record => record.type === type && record.session_id === 1), type);
  assert.ok(records.some(record => record.type === 'candidate_cancelled' && record.reason === 'recognition_end'));
  assert.deepEqual(f.popWords, []);
});

test('reviewed compound prefixes and joined/spaced revisions share one atomic hit', () => {
  for (const [word, parts] of Object.entries(compoundParts)) {
    const f = fixture();
    f.publishPop({ targets: [{ uid: 90, text: word, forms: [word] }] });
    f.listen('pop');
    f.latest.result([[parts[0], false]]);
    f.advance(200);
    assert.deepEqual(f.popWords, [], word + ' prefix');
    f.latest.result([[parts.join(' '), false]]);
    f.advance(150);
    assert.deepEqual(f.popWords, [word]);
    f.publishPop({ targets: [{ uid: 91, text: word, forms: [word] }] });
    f.latest.result([[word, false]]);
    f.latest.result([[parts.join('-'), true]]);
    assert.deepEqual(f.popWords, [word], word + ' revision');
    f.latest.result([[parts.join('-'), true], [word, true]], 1);
    assert.deepEqual(f.popEvents.filter(event => event.target_uid > 0).map(event => event.target_uid), [90, 91]);
  }
});

test('compound completion cannot retarget old partial speech to a later spawn', () => {
  for (const initial of ['sun', 'sun flo', 'sunflower']) {
    const f = fixture();
    f.publishPop({ targets: [] });
    f.listen('pop');
    f.latest.result([[initial, false]]);
    f.publishPop({ targets: [{ uid: 91, text: 'sunflower' }] });
    f.latest.result([['sun flower', true]]);
    assert.equal(f.popEvents.filter(event => event.target_uid > 0).length, 0, initial);
  }
});

test('a genuinely repeated compound in a growing segment keeps a separate target and occurrence', () => {
  for (const word of ['sunflower', 'yoyo']) {
    const f = fixture();
    const phrase = compoundParts[word].join(' ');
    f.publishPop({ targets: [{ uid: 1, text: word, forms: [word, word + 's'] }] });
    f.listen('pop');
    f.latest.result([[phrase, false]]);
    f.advance(150);
    f.publishPop({ targets: [{ uid: 2, text: word, forms: [word, word + 's'] }] });
    f.latest.result([[`${word} ${phrase}`, false]]);
    f.advance(150);
    f.latest.result([[`${phrase} ${word}s`, true]]);
    assert.deepEqual(f.popEvents.map(event => event.target_uid), [1, 2], word);
    assert.equal(new Set(f.popEvents.map(event => event.event_id)).size, 2);
  }
});

test('separate component words remain separate and a joined compound never hits components', () => {
  const f = fixture();
  f.publishPop({ targets: [{ uid: 1, text: 'sun' }, { uid: 2, text: 'flower' }] });
  f.listen('pop');
  f.latest.result([['sun flower', true]]);
  assert.deepEqual(f.popWords, ['sun', 'flower']);
  const joined = fixture();
  joined.publishPop({ targets: [{ uid: 1, text: 'sun' }, { uid: 2, text: 'flower' }] });
  joined.listen('pop');
  joined.latest.result([['sunflower', false]]);
  joined.advance(150);
  joined.latest.result([['sun flower', true]]);
  assert.equal(joined.popEvents.filter(event => event.target_uid > 0).length, 0);
});

test('compound spans cannot steal a consumed component or replay after shortening', () => {
  const f = fixture();
  f.publishPop({ targets: [{ uid: 1, text: 'horse' }] });
  f.listen('pop');
  f.latest.result([['horse', false]]);
  f.advance(150);
  f.publishPop({ targets: [{ uid: 2, text: 'seahorse' }] });
  f.latest.result([['sea horse', true]]);
  assert.deepEqual(f.popWords, ['horse']);
  const joined = fixture();
  joined.publishPop({ targets: [{ uid: 2, text: 'seahorse' }] });
  joined.listen('pop');
  joined.latest.result([['seahorse', false]]);
  joined.advance(150);
  joined.publishPop({ targets: [{ uid: 3, text: 'horse' }, { uid: 4, text: 'seahorse' }] });
  joined.latest.result([['horse', false]]);
  joined.latest.result([['sea horse', true]]);
  assert.deepEqual(joined.popWords, ['seahorse']);
});

test('new members of a revised compound inherit consumed lineage through later splits', () => {
  for (const correction of ['sunflower', 'sunflowers']) {
    const f = fixture();
    f.publishPop({ targets: [{ uid: 1, text: 'cat' }, { uid: 2, text: 'flower', forms: ['flower', 'flowers'] }] });
    f.listen('pop');
    f.latest.result([['cat', false]]);
    f.advance(150);
    f.latest.result([[correction, false]]);
    f.latest.result([['sun', false]]);
    f.latest.result([['flower', true]]);
    assert.deepEqual(f.popWords, ['cat'], correction + ' cannot create an unconsumed sibling');
    f.latest.result([['flower', true], ['flower', true]], 1);
    assert.deepEqual(f.popWords, ['cat', 'flower'], 'A new utterance can still hit the existing flower');
  }
  const f = fixture();
  f.publishPop({ targets: [{ uid: 1, text: 'sunflower' }] });
  f.listen('pop');
  f.latest.result([['sunflower', false]]);
  f.advance(150);
  f.publishPop({ targets: [{ uid: 2, text: 'sun' }, { uid: 3, text: 'flower' }] });
  f.latest.result([['sun', false]]);
  f.latest.result([['flower', true]]);
  assert.deepEqual(f.popWords, ['sunflower']);
});

test('compound aliases respect phrase boundaries and do not perform arbitrary joining', () => {
  for (const text of ['deep-sea-horse', "sea horse's", '_sea horse', 'sea horse2', 'sea, horse', 'sea\nhorse', 'sea hoarse']) {
    const f = fixture();
    f.publishPop({ targets: [{ uid: 1, text: 'seahorse' }] });
    f.listen('pop');
    f.latest.result([[text, true]]);
    assert.equal(f.popEvents.filter(event => event.target_uid > 0).length, 0, text);
  }
});

test('practice uses real recognition and shared matching without native callbacks or prompt replay', () => {
  const f = fixture();
  f.listen('pop');
  const old = f.latest;
  const hits = [], results = [], states = [], diagnostics = [];
  assert.equal(f.host.beginSpeechPractice({ onHit: event => hits.push(event), onResult: (...args) => results.push(args),
    onState: (...args) => states.push(args), onDiagnostic: record => diagnostics.push(record) }), true);
  const nativeCounts = [f.popEvents.length, f.results.length, f.states.length];
  assert.ok(f.host.practiceWords().some(word => word.text === 'seahorse'));
  assert.equal(f.host.practiceTarget('unknown'), null);
  const first = f.host.practiceTarget('sunflower');
  f.advance();
  const instance = f.latest;
  old.result([['cat', true]]);
  instance.result([['sun flower', false]]);
  f.advance(150);
  assert.equal(hits.length, 1);
  assert.equal(hits[0].target_uid, first.uid);
  const second = f.host.practiceTarget('sunflower');
  assert.notEqual(second.uid, first.uid);
  instance.result([['sunflower', true]]);
  assert.equal(hits.length, 1, 'The old hypothesis cannot score the next prompt');
  instance.result([['sunflower', true], ['sunflower', true]], 1);
  assert.equal(hits.length, 2);
  assert.equal(hits[1].target_uid, second.uid);
  assert.equal(f.latest, instance, 'Changing prompts keeps the recognizer and occurrence ledger');
  assert.equal(results[0][2][0].text, 'sun flower');
  assert.ok(states.some(([, listening]) => listening));
  assert.ok(diagnostics.some(record => record.type === 'hit'));
  assert.deepEqual([f.popEvents.length, f.results.length, f.states.length], nativeCounts);
  assert.equal(f.host.endSpeechPractice(), true);
  assert.equal(f.host.speechDiagnostics().enabled, false);
  assert.deepEqual(Array.from(f.host.speechDiagnostics().records), []);
  f.listen('pop');
  f.latest.result([['cat', true]]);
  assert.deepEqual(f.popWords, ['cat']);
});

test('practice stop failure retains isolation until the microphone is safely stopped', () => {
  const f = fixture();
  const states = [];
  assert.equal(f.host.beginSpeechPractice({ onState: (...args) => states.push(args) }), true);
  f.host.practiceTarget('cat');
  f.advance();
  f.latest.abort = () => { throw new Error('abort failed'); };
  f.latest.stop = () => { throw new Error('stop failed'); };
  assert.equal(f.host.endSpeechPractice(), false);
  assert.match(states.at(-1)[2], /close this tab/i);
  assert.equal(f.host.popStatus(JSON.stringify({ phase: 'running', round_id: 'native-round' })), false);
  f.latest.abort = () => {};
  assert.equal(f.host.endSpeechPractice(), true);
});

test('practice keeps the ordinary browser baseline and bounds each diagnostic alternative', () => {
  const f = fixture({ local: true });
  const records = [];
  f.host.beginSpeechPractice({ onDiagnostic: record => records.push(record) });
  f.host.practiceTarget('cat');
  f.advance();
  assert.equal(f.latest.processLocally, undefined);
  assert.equal(f.host.speechDiagnostics().mode, 'browser');
  f.latest.result([['a'.repeat(10000), true]]);
  assert.equal(records.find(record => record.type === 'result').alternatives[0].text.length, 2000);
  f.host.endSpeechPractice();
});
