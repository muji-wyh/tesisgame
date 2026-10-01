const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const shell = fs.readFileSync(path.join(__dirname, '../web/shell.html'), 'utf8');
const questSource = shell.match(/      function createQuestHost\(speech\) \{[\s\S]*?\n      \}/)?.[0];
const speechSource = shell.match(/      function createSpeechHost\(\) \{[\s\S]*?\n      \}/)?.[0];
assert.ok(questSource, 'The maintained shell exposes an isolated quest host');
assert.ok(speechSource, 'The quest uses the maintained browser speech host');

function element() {
  const handlers = {};
  return {
    hidden: false, disabled: false, textContent: '', dataset: {}, style: {}, attributes: {},
    addEventListener(type, handler) { (handlers[type] ||= []).push(handler); },
    dispatch(type, event = {}) { for (const handler of handlers[type] || []) handler(event); },
    setAttribute(name, value) { this.attributes[name] = String(value); },
    focus() {}
  };
}

function questFixture({ synthesis = true } = {}) {
  const status = element();
  const document = Object.assign(element(), { getElementById: id => id === 'quest-status' ? status : null });
  const window = element();
  const values = new Map(), writes = [], calls = [], spoken = [];
  let readFails = false, writeFails = false, canStop = true;
  const localStorage = {
    getItem(key) { if (readFails) throw new Error('Storage unavailable'); return values.get(key) ?? null; },
    setItem(key, value) { if (writeFails) throw new Error('Storage full'); values.set(key, value); writes.push({ key, value }); }
  };
  const speech = { stopSpeech() { calls.push('stop'); return canStop; } };
  if (synthesis) {
    window.SpeechSynthesisUtterance = class { constructor(text) { this.text = text; } };
    window.speechSynthesis = {
      speak(utterance) { calls.push('speak'); spoken.push(utterance); },
      cancel() { calls.push('cancel'); }
    };
  }
  const host = vm.runInNewContext(`(${questSource})(speech)`, { window, document, localStorage, speech });
  return { host, window, document, status, values, writes, calls, spoken,
    set readFails(value) { readFails = value; }, set writeFails(value) { writeFails = value; },
    set canStop(value) { canStop = value; }
  };
}

function speechFixture({ prefixed = false } = {}) {
  const elements = Object.fromEntries(['game', 'canvas', 'speech-panel', 'speech-status', 'speech-transcript',
    'speech-notice', 'pop-aura', 'pop-status'].map(id => [id, element()]));
  const document = Object.assign(element(), { activeElement: elements.canvas, getElementById: id => elements[id] });
  let now = 0, nextTimer = 1, starts = 0, aborts = 0;
  const timers = new Map(), instances = [], events = [], states = [], genericResults = [];
  const window = Object.assign(element(), {
    isSecureContext: true, navigator: { onLine: true }, performance: { now: () => now },
    setTimeout(callback, delay) { const id = nextTimer++; timers.set(id, { callback, at: now + delay }); return id; },
    clearTimeout(id) { timers.delete(id); }
  });
  function advance(ms = 0) {
    const end = now + ms;
    for (let attempts = 0; attempts < 1000; attempts++) {
      const next = [...timers].filter(([, value]) => value.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) { now = end; return; }
      now = next[1].at;
      timers.delete(next[0]);
      next[1].callback();
    }
    assert.fail('Recognition timers must be bounded');
  }
  class Recognition {
    constructor() { this.onaudiostart = null; instances.push(this); }
    start() {
      starts++;
      this.callbacks = { start: this.onstart, audio: this.onaudiostart, result: this.onresult,
        error: this.onerror, end: this.onend };
      window.setTimeout(() => this.callbacks.start?.(), 0);
    }
    abort() { aborts++; window.setTimeout(() => this.callbacks.end?.(), 0); }
    capture() { this.callbacks.audio?.(); }
    result(entries, resultIndex = 0) {
      const results = entries.map(([transcript, isFinal]) => Object.assign([{ transcript, confidence: 0.95 }], { isFinal }));
      this.callbacks.result?.({ resultIndex, results });
    }
  }
  window[prefixed ? 'webkitSpeechRecognition' : 'SpeechRecognition'] = Recognition;
  const host = vm.runInNewContext(`(${speechSource})()`, {
    window, document,
    createLocalSpeechPreparation: () => ({ modeForNewRound: () => 'browser', setVisible() {},
      getState: () => ({ enabled: false, ready: false, capable: false, status: 'disabled', error: '' }) })
  });
  host.observeQuestSpeech(json => {
    assert.equal(typeof json, 'string', 'The Godot bridge receives one serialized event argument');
    events.push(JSON.parse(json));
  });
  host.observeSpeech((...args) => genericResults.push(args), (...args) => states.push(args));
  return { host, window, document, elements, instances, events, states, genericResults, advance,
    get starts() { return starts; }, get aborts() { return aborts; }, get latest() { return instances.at(-1); },
    listen(target = { round_id: 'quest-round-1', target_uid: 1 }) {
      assert.equal(host.questTarget(JSON.stringify(target)), true);
      host.speechMode(true, 'quest');
      advance();
      instances.at(-1).capture();
    }
  };
}

test('quest persistence stores progress separately and excludes transient speech data', () => {
  const f = questFixture();
  f.values.set('wordBuddies.medalProgress', 'existing medals');
  assert.equal(f.host.questProgress(), null);
  const progress = { version: 1, completion_counts: [1, ...Array(13).fill(0)],
    run: { level_number: 14, line_index: 5, phase: 'playing', clear_number: 1, run_id: 'tq-run-1',
      selected_parts: ['wheel', 'wing'],
      transcript: 'private sentence', event_id: 'quest-1-0', recording: 'audio' },
    transcript: 'private sentence', recordings: ['audio'] };
  assert.equal(f.host.saveQuestProgress(JSON.stringify(progress)), true);
  const saved = JSON.parse(f.host.questProgress());
  assert.deepEqual(saved, { version: 1, completion_counts: progress.completion_counts,
    run: { level_number: 14, line_index: 5, phase: 'playing', clear_number: 1, run_id: 'tq-run-1',
      selected_parts: ['wheel', 'wing'] } });
  assert.equal(f.writes[0].key, 'wordBuddies.talkQuest');
  assert.equal(f.values.get('wordBuddies.medalProgress'), 'existing medals');
  assert.doesNotMatch(f.host.questProgress(), /private sentence|transcript|event_id|recording/);
});

test('invalid progress and failed storage cannot report a successful checkpoint', () => {
  const f = questFixture();
  const original = JSON.stringify({ version: 1, completion_counts: Array(14).fill(0), run: {} });
  assert.equal(f.host.saveQuestProgress(original), true);
  for (const text of ['{', 'null', '[]', '{}', '{"version":2,"completion_counts":[]}',
    '{"version":1,"completion_counts":{}}']) {
    assert.equal(f.host.saveQuestProgress(text), false);
    assert.equal(f.host.questProgress(), original);
  }
  f.writeFails = true;
  assert.equal(f.host.saveQuestProgress(original), false);
  assert.equal(f.writes.length, 1);
  f.readFails = true;
  assert.equal(f.host.questProgress(), false);
});

test('workshop persistence retains only the five known part IDs', () => {
  const f = questFixture();
  const saved = { version: 1, completion_counts: Array(14).fill(0), run: {
    selected_parts: ['wheel', 'private sentence', 'wing', null, { transcript: 'private sentence' },
      'ribbon', 'screw', 'key', 'wheel']
  } };
  assert.equal(f.host.saveQuestProgress(JSON.stringify(saved)), true);
  assert.deepEqual(JSON.parse(f.host.questProgress()).run.selected_parts, ['wheel', 'wing', 'ribbon', 'screw', 'key']);
  assert.doesNotMatch(f.host.questProgress(), /private sentence|transcript/);
});

test('quest status is a read-only display snapshot and renders recognized text literally', () => {
  const f = questFixture();
  const snapshot = { active: true, view: 'stage', phase: 'playing', hp: 50,
    prompt: { speaker: 'Adam', text: 'Knock, knock.' }, transcript: '<img src=x onerror=alert(1)>' };
  f.host.questStatus(JSON.stringify(snapshot));
  assert.deepEqual(JSON.parse(f.status.dataset.snapshot), snapshot);
  assert.equal(f.status.textContent, 'Adam: Knock, knock.. <img src=x onerror=alert(1)>');
  assert.deepEqual(f.writes, []);
  assert.deepEqual(f.calls, []);
  for (const invalid of ['{', 'null', '[]', 'true']) f.host.questStatus(invalid);
  assert.deepEqual(JSON.parse(f.status.dataset.snapshot), snapshot);
  f.host.questStatus(JSON.stringify({ active: true, view: 'map', completed: [1, 2] }));
  assert.equal(f.status.textContent, 'Talk Quest. 2 of 14 adventures complete.');
  f.host.questStatus(JSON.stringify({ active: false }));
  assert.equal(f.status.textContent, '');
});

test('Hear line stops capture before speaking and cannot be cleared by an old utterance callback', () => {
  const f = questFixture();
  assert.equal(f.host.questSpeak('Knock, knock.'), true);
  assert.deepEqual(f.calls, ['stop', 'speak']);
  assert.equal(f.spoken[0].lang, 'en-US');
  assert.equal(f.spoken[0].rate, 0.85);
  assert.equal(f.host.questSpeak('x'.repeat(700)), true);
  assert.equal(f.spoken[1].text.length, 512);
  assert.deepEqual(f.calls, ['stop', 'speak', 'cancel', 'stop', 'speak']);
  f.spoken[0].onend();
  f.host.questCancelSpeak();
  assert.equal(f.calls.at(-1), 'cancel', 'A late previous callback cannot orphan the current utterance');
  const count = f.calls.length;
  f.host.questCancelSpeak();
  assert.equal(f.calls.length, count, 'Repeated cancellation is harmless');
});

test('Hear line fails safely for hidden pages, missing synthesis and failed microphone shutdown', () => {
  const f = questFixture();
  for (const value of ['', '  ', null, 42]) assert.equal(f.host.questSpeak(value), false);
  f.document.hidden = true;
  assert.equal(f.host.questSpeak('Hello.'), false);
  f.document.hidden = false;
  f.canStop = false;
  assert.equal(f.host.questSpeak('Hello.'), false);
  assert.deepEqual(f.spoken, []);
  assert.deepEqual(f.calls, ['stop']);
  assert.equal(questFixture({ synthesis: false }).host.questSpeak('Hello.'), false);
  f.canStop = true;
  f.window.speechSynthesis.speak = () => { throw new Error('Speech unavailable'); };
  assert.equal(f.host.questSpeak('Hello.'), false);
});

test('hiding or leaving the page cancels spoken prompts without restarting the microphone', () => {
  for (const type of ['visibilitychange', 'pagehide']) {
    const f = questFixture();
    f.host.questSpeak('Hello.');
    if (type === 'visibilitychange') { f.document.hidden = true; f.document.dispatch(type); }
    else f.window.dispatch(type);
    assert.deepEqual(f.calls, ['stop', 'speak', 'cancel']);
  }
});

test('quest recognition starts explicitly and binds interim and final revisions to one occurrence', () => {
  for (const prefixed of [false, true]) {
    const f = speechFixture({ prefixed });
    assert.equal(f.host.questTarget(JSON.stringify({ round_id: 'quest-round-1', target_uid: 1 })), true);
    assert.equal(f.starts, 0);
    f.host.speechMode(true, 'quest');
    f.advance();
    assert.equal(f.states.at(-1)[1], false, 'Service start alone is not capture readiness');
    f.latest.capture();
    assert.equal(f.states.at(-1)[1], true);
    f.host.speechMode(true, 'quest');
    assert.equal(f.starts, 1);
    f.latest.result([['  Knock, knock.  ', false]]);
    f.latest.result([['Knock, knock.', true]]);
    assert.deepEqual(f.events.map(event => ({ ...event, event_id: 'same-occurrence' })), [
      { round_id: 'quest-round-1', target_uid: 1, event_id: 'same-occurrence', text: 'Knock, knock.', stage: 'interim' },
      { round_id: 'quest-round-1', target_uid: 1, event_id: 'same-occurrence', text: 'Knock, knock.', stage: 'final' }
    ]);
    assert.equal(f.events[0].event_id, f.events[1].event_id);
    f.latest.result([['Changed final text.', true]]);
    assert.equal(f.events.length, 2, 'A rewritten final cannot become a second scored occurrence');
    f.latest.result([['Knock, knock.', true], ["Who's that?", true]], 1);
    assert.equal(f.events.length, 3);
    assert.notEqual(f.events[2].event_id, f.events[1].event_id);
    assert.equal(f.events[2].target_uid, 1, 'Results retain their captured binding, not a guessed next target');
    assert.equal(f.elements['speech-panel'].hidden, true, 'Quest owns its visible sentence controls');
  }
});

test('invalid bindings preserve the active target and switching targets rejects every old callback', () => {
  const f = speechFixture();
  f.listen();
  const old = f.latest;
  for (const text of ['{', 'null', '{}', '{"round_id":"","target_uid":1}',
    '{"round_id":"quest-round-1","target_uid":"2"}', '{"round_id":"quest-round-1","target_uid":0}',
    '{"round_id":"quest-round-1","target_uid":1.5}']) assert.equal(f.host.questTarget(text), false);
  assert.equal(f.aborts, 0);
  old.result([['Knock, knock.', true]]);
  assert.equal(f.events[0].target_uid, 1);
  assert.equal(f.host.questTarget(JSON.stringify({ round_id: 'quest-round-1', target_uid: 2 })), true);
  assert.equal(f.aborts, 1);
  old.capture();
  old.result([['Knock, knock.', true], ["Who's that?", true]], 1);
  old.callbacks.error({ error: 'network' });
  old.callbacks.end();
  f.advance(500);
  assert.equal(f.events.length, 1);
  assert.equal(f.starts, 1, 'Changing a target does not open the microphone implicitly');
  f.host.speechMode(true, 'quest');
  f.advance();
  f.latest.capture();
  f.latest.result([["Who's that?", true]]);
  assert.equal(f.events[1].target_uid, 2);
  assert.notEqual(f.events[1].event_id, f.events[0].event_id);
});

test('page lifecycle and explicit stop invalidate captured quest callbacks', () => {
  for (const stop of ['stop', 'hidden', 'pagehide']) {
    const f = speechFixture();
    f.listen();
    const old = f.latest;
    if (stop === 'stop') assert.equal(f.host.stopSpeech(), true);
    if (stop === 'hidden') { f.document.hidden = true; f.document.dispatch('visibilitychange'); }
    if (stop === 'pagehide') f.window.dispatch('pagehide');
    old.capture();
    old.result([['Knock, knock.', true]]);
    old.callbacks.end();
    f.advance(1000);
    assert.deepEqual(f.events, []);
    assert.equal(f.starts, 1);
    assert.equal(f.elements['pop-aura'].attributes['data-listening'], 'false');
  }
});

test('quest recognition bounds forwarded text without splitting a sentence into word hits', () => {
  const f = speechFixture();
  f.listen();
  f.latest.result([['a'.repeat(2500), true]]);
  assert.equal(f.events.length, 1);
  assert.equal(f.events[0].text.length, 2000);
  assert.equal(f.events[0].stage, 'final');
  assert.equal(f.events[0].target_uid, 1);
});
