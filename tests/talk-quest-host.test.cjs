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

test('Talk Quest accessible help describes finite floating words and level-triggered capture', () => {
  const help = shell.match(/<p\b[^>]*id="help"[^>]*>([\s\S]*?)<\/p>/)?.[1];
  assert.match(help, /Choose a level[^.]*start the microphone/);
  assert.match(help, /say the floating words/);
  assert.match(help, /one health point/);
  assert.match(help, /limited supply of words/);
  assert.match(help, /Speech appears on screen in real time as recognition updates/);
  assert.match(help, /including words that do not match a target/);
  assert.doesNotMatch(help, /last recognized word appears briefly/);
  assert.doesNotMatch(help, /Hear line|use Type|matching sentence|repair five toys/);
});

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
  host.observeQuestSpeech((json, receipt) => {
    assert.equal(typeof json, 'string', 'The Godot bridge receives one serialized event argument');
    const event = JSON.parse(json);
    events.push(event);
    if (receipt) receipt.accepted = event.target_uid > 0;
  });
  host.observeSpeech((...args) => genericResults.push(args), (...args) => states.push(args));
  return { host, window, document, elements, instances, events, states, genericResults, advance,
    get starts() { return starts; }, get aborts() { return aborts; }, get latest() { return instances.at(-1); },
    listen(target = { round_id: 'quest-round-1', target_uid: 1 }) {
      assert.equal(host.questTarget(JSON.stringify(target)), true);
      host.speechMode(true, 'quest');
      advance();
      instances.at(-1).capture();
    },
    publishWords(targets, round = 'quest-words-1') {
      assert.equal(host.questTargets(JSON.stringify({ round_id: round, targets })), true);
    },
    listenWords(targets = [{ uid: 1, text: 'cat', forms: ['cat', 'cats'], remaining_ms: 10000 }], round = 'quest-words-1') {
      this.publishWords(targets, round);
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

function wordCheckpoint() {
  return { version: 2, completion_counts: Array(14).fill(0), run: {
    level_number: 1, hits: 1, misses: 0, spawned: 2, elapsed: 2.8, next_spawn_in: 1.5,
    phase: 'playing', clear_number: 1, run_id: 'tq-run-1-2-3', targets: [{ uid: 2, word_id: 'cat',
      age: 0.65, lifetime: 10, lane: 0, x_start: 0.25, x_end: 0.48, peak: 0.22, spin: 0.05 }]
  } };
}

test('version two quest progress retains finite flights while discarding speech and derived word data', () => {
  const f = questFixture(), expected = wordCheckpoint(), candidate = structuredClone(expected);
  Object.assign(candidate, { transcript: 'private utterance', audio: 'private audio' });
  Object.assign(candidate.run, { line_index: 1, feedback: 'private utterance', selected_parts: ['wheel'] });
  Object.assign(candidate.run.targets[0], { word: { text: 'private utterance' }, forms: ['private utterance'],
    transcript: 'private utterance', event_id: 'speech-1', recording: 'audio', volley: false, x: 0.2, rotation: 0.1 });
  assert.equal(f.host.saveQuestProgress(JSON.stringify(candidate)), true);
  assert.deepEqual(JSON.parse(f.host.questProgress()), expected);
  assert.doesNotMatch(f.host.questProgress(), /private|transcript|event_id|recording|forms|feedback|line_index|selected_parts/);
  assert.equal(f.host.saveQuestProgress(JSON.stringify({ ...expected, run: {} })), true);
  assert.deepEqual(JSON.parse(f.host.questProgress()).run, {});
});

test('ten-second quest checkpoints preserve near-deadline words and accept legacy flights', () => {
  const f = questFixture();
  for (const [lifetime, age] of [[10, 9.99], [6.8, 6.79], [5.8, 5.79]]) {
    const checkpoint = wordCheckpoint();
    Object.assign(checkpoint.run.targets[0], { lifetime, age });
    assert.equal(f.host.saveQuestProgress(JSON.stringify(checkpoint)), true);
    assert.deepEqual(JSON.parse(f.host.questProgress()), checkpoint);
  }
});

test('actual exported Godot runs preserve signed instance IDs without blocking microphone startup', () => {
  const f = questFixture();
  // RefCounted IDs can occupy Godot's signed high bit in the Web export.
  const payload = { completion_counts: Array(14).fill(0), version: 2, run: {
    clear_number: 1, elapsed: 0, hits: 0, level_number: 1, misses: 0, next_spawn_in: 2.15,
    phase: 'playing', run_id: 'tq-run--9223371976255469986-18431100-1', spawned: 1,
    targets: [{ age: 0, drift: -0.00294307246804237, height: 0.322026461362839,
      lane: 2, lifetime: 6.8, peak: 0.322026461362839, rotation: 0.0792519524693489,
      spin: 0.0792519524693489, uid: 1, volley: false, word_id: 'door',
      x: 0.753631644397974, x_end: 0.750688571929932, x_start: 0.753631644397974 }]
  } };
  assert.equal(f.host.saveQuestProgress(JSON.stringify(payload)), true);
  const saved = JSON.parse(f.host.questProgress());
  assert.equal(saved.run.run_id, payload.run.run_id);
  assert.deepEqual(saved.run.targets, [{ age: 0, lane: 2, lifetime: 6.8, peak: 0.322026461362839,
    spin: 0.0792519524693489, uid: 1, word_id: 'door', x_end: 0.750688571929932, x_start: 0.753631644397974 }]);
});

test('malformed version two checkpoints cannot replace valid saved finite flights', () => {
  const f = questFixture(), original = wordCheckpoint();
  assert.equal(f.host.saveQuestProgress(JSON.stringify(original)), true);
  const serialized = f.host.questProgress();
  const changes = [
    value => { value.completion_counts[0] = 'private utterance'; },
    value => { value.completion_counts = []; },
    value => { value.run.hits = 'private utterance'; },
    value => { value.run.elapsed = 3601; },
    value => { value.run.next_spawn_in = -1; },
    value => { value.run.run_id = 'private utterance'; },
    value => { value.run.phase = 'private utterance'; },
    value => { value.run.targets[0].age = 10; },
    value => { value.run.targets[0].lifetime = 9; },
    value => { value.run.targets[0].lifetime = 10.01; },
    value => { value.run.targets[0].word_id = 'private utterance'; },
    value => { value.run.targets[0].lane = 4; },
    value => { value.run.targets[0].uid = 3; },
    value => { value.run.targets = Array(4).fill(value.run.targets[0]); }
  ];
  for (const change of changes) {
    const value = structuredClone(original);
    change(value);
    assert.equal(f.host.saveQuestProgress(JSON.stringify(value)), false);
    assert.equal(f.host.questProgress(), serialized);
  }
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
  f.host.questStatus(JSON.stringify({ active: true, view: 'stage', phase: 'paused', targets: [],
    pause_result: { visible: true, context_phase: 'chest' } }));
  assert.equal(f.status.textContent, 'Talk Quest paused. Choose Continue to resume or Map to return to the adventures.');
  assert.deepEqual(f.calls, [], 'Announcing a pause must not start the microphone or other host actions');
  f.host.questStatus(JSON.stringify({ active: false }));
  assert.equal(f.status.textContent, '');
});

test('repeated Quest snapshots leave the DOM unchanged while geometry and lifecycle changes still publish', () => {
  const f = questFixture();
  let snapshot = '', readable = '', snapshotWrites = 0, textWrites = 0;
  Object.defineProperty(f.status.dataset, 'snapshot', {
    get() { return snapshot; }, set(value) { snapshot = value; snapshotWrites++; }
  });
  Object.defineProperty(f.status, 'textContent', {
    get() { return readable; }, set(value) { readable = value; textWrites++; }
  });
  const states = [
    { active: true, view: 'map', completed: [1, 2] },
    { active: true, view: 'stage', phase: 'paused', pause_result: { visible: true } },
    { active: true, view: 'stage', phase: 'playing', hp: 6, targets: [{ text: 'cat', x: 10 }] },
    { active: true, view: 'stage', phase: 'playing', hp: 6, targets: [{ text: 'cat', x: 20 }] },
    { active: false }
  ];
  for (const state of states) {
    f.host.questStatus(JSON.stringify(state));
    const before = [snapshotWrites, textWrites];
    f.host.questStatus(JSON.stringify(state));
    assert.deepEqual([snapshotWrites, textWrites], before, 'Repeated map, pause and game snapshots do not mutate the DOM');
    assert.deepEqual(JSON.parse(snapshot), state);
  }
  assert.equal(snapshotWrites, states.length, 'New geometry still publishes even when readable words are unchanged');
  assert.equal(textWrites, states.length - 1, 'Moving a target does not repeat the live-region announcement');
  assert.equal(readable, '');
  assert.deepEqual(f.calls, [], 'Snapshot updates never start speech or change its bindings');
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

test('floating-word quest capture starts once and target refreshes keep the active session', () => {
  for (const prefixed of [false, true]) {
    const f = speechFixture({ prefixed });
    const targets = [{ uid: 1, text: 'cat', forms: ['cat', 'cats'], remaining_ms: 10000 }];
    f.publishWords(targets);
    assert.equal(f.starts, 0, 'Publishing words alone never starts the microphone');
    f.host.speechMode(true, 'quest');
    f.advance();
    assert.equal(f.states.at(-1)[1], false);
    f.latest.capture();
    f.publishWords(targets);
    f.host.speechMode(true, 'quest');
    assert.equal(f.starts, 1);
    assert.equal(f.aborts, 0);
    f.latest.result([['cat', false]]);
    f.advance(149);
    assert.equal(f.events.length, 0);
    f.advance(1);
    assert.equal(f.events.length, 1);
    assert.equal(f.events[0].stage, 'interim');
    assert.equal(f.events[0].text, 'cat');
    assert.equal(f.events[0].target_uid, 1);
    assert.equal(f.events[0].round_id, 'quest-words-1');
    assert.equal(f.events[0].received_at_ms, 0);
    f.latest.result([['cats', true]]);
    f.latest.result([['cat', true]]);
    assert.equal(f.events.length, 1, 'Acknowledged interim and rewritten final are the same consumed occurrence');
  }
});

test('Quest publishes every raw live revision immediately and independently from word scoring', () => {
  const f = speechFixture();
  f.listenWords();
  const updates = [
    ['Um, I think a caterpillar!', false],
    ['Um, I think CAT!', false],
    ['', false],
    ['No, that is a dog.', false],
    ['No, that is a dog.', true]
  ];
  for (const [text, final] of updates) {
    f.latest.result([[text, final]]);
    assert.deepEqual(f.genericResults.at(-1), [text, final],
      'The display sees the whole hypothesis synchronously, without waiting 150 ms or requiring a match');
  }
  assert.deepEqual(f.genericResults, updates, 'Every nonempty and empty revision reaches the display exactly once');
  f.advance(200);
  assert.deepEqual(f.events.filter(event => event.target_uid > 0), [],
    'Withdrawn matches and mismatched utterances do not manufacture a scored hit');
});

test('Quest displays raw text before a final word scores and ends the listening session', () => {
  const f = speechFixture(), order = [];
  f.host.observeSpeech((text, final) => order.push(['display', text, final]), () => {});
  f.host.observeQuestSpeech((json, receipt) => {
    const event = JSON.parse(json);
    order.push(['score', event.text, event.target_uid]);
    receipt.accepted = true;
    f.host.stopSpeech();
  });
  f.listenWords();
  f.latest.result([['I said CAT!', true]]);
  assert.deepEqual(order, [['display', 'I said CAT!', true], ['score', 'CAT', 1]],
    'Raw speech survives the scoring callback stopping capture after the winning word');
});

test('Quest empty finals and rewritten final hypotheses update only the display once', () => {
  const f = speechFixture();
  f.listenWords();
  f.latest.result([['cat', false]]);
  assert.deepEqual(f.genericResults, [['cat', false]]);
  assert.deepEqual(f.events, [], 'The display does not wait for the scoring stability timer');
  f.advance(150);
  assert.equal(f.events.length, 1);
  f.latest.result([['cats', true]]);
  f.latest.result([['Actually, a cat!', true]]);
  f.latest.result([['', true]]);
  assert.deepEqual(f.genericResults, [
    ['cat', false], ['cats', true], ['Actually, a cat!', true], ['', true]
  ]);
  assert.equal(f.events.length, 1, 'A corrected or withdrawn final never scores the consumed occurrence twice');
  f.latest.result([['', true], ['', true]], 1);
  assert.deepEqual(f.genericResults.at(-1), ['', true]);
  assert.equal(f.genericResults.length, 5, 'A new empty final is not duplicated by the candidate callback branch');
});

test('Quest raw transcript callbacks cannot leak after pause, map, mode exit or round replacement', () => {
  for (const stop of ['pause', 'map', 'mode', 'round', 'hidden', 'pagehide']) {
    const f = speechFixture();
    f.listenWords();
    const old = f.latest;
    old.result([['cat', false]]);
    if (stop === 'pause' || stop === 'map') f.host.stopSpeech();
    if (stop === 'mode') f.host.speechMode(true, 'match');
    if (stop === 'round') f.publishWords([{ uid: 1, text: 'dog', remaining_ms: 10000 }], 'quest-words-2');
    if (stop === 'hidden') { f.document.hidden = true; f.document.dispatch('visibilitychange'); }
    if (stop === 'pagehide') f.window.dispatch('pagehide');
    old.result([['stale partial', false]]);
    old.result([['stale final', true]]);
    f.advance(200);
    assert.deepEqual(f.genericResults, [['cat', false]], stop + ' suppresses raw callbacks from old capture');
    assert.deepEqual(f.events, [], stop + ' also cancels the old bound candidate');
  }
});

test('Quest transcript observers can end capture without allowing the displayed word to score', () => {
  const f = speechFixture(), visible = [];
  f.host.observeSpeech((text, final) => {
    visible.push([text, final]);
    f.host.stopSpeech();
  }, () => {});
  f.listenWords();
  f.latest.result([['cat', true]]);
  assert.deepEqual(visible, [['cat', true]]);
  assert.deepEqual(f.events, [], 'A synchronous display-side lifecycle change invalidates the candidate before scoring');
});

test('quest floating words share Pop token alignment, reviewed aliases and separate occurrence IDs', () => {
  const f = speechFixture();
  f.listenWords([
    { uid: 11, text: 'cat', forms: ['cat', 'cats'], remaining_ms: 10000 },
    { uid: 12, text: 'dog', forms: ['dog', 'dogs'], remaining_ms: 10000 }
  ]);
  f.latest.result([['cats', false]]);
  f.advance(150);
  f.latest.result([['a cats dogs', false]]);
  f.advance(150);
  f.latest.result([['a cats dogs', true]]);
  assert.deepEqual(f.events.map(event => event.target_uid), [11, 12]);
  assert.notEqual(f.events[0].event_id, f.events[1].event_id);
  assert.deepEqual(f.events.map(event => event.text), ['cats', 'dogs']);
});

test('old quest speech cannot transfer to a newly spawned word with the same text', () => {
  const f = speechFixture();
  f.listenWords();
  f.latest.result([['cat', false]]);
  f.publishWords([{ uid: 2, text: 'cat', forms: ['cat', 'cats'], remaining_ms: 10000 }]);
  f.advance(150);
  f.latest.result([['cats', true]]);
  assert.deepEqual(f.events, []);
  f.latest.result([['cats', true], ['cat', true]], 1);
  assert.equal(f.events.length, 1);
  assert.equal(f.events[0].target_uid, 2);
});

test('quest word expiry blocks stable interims and final callbacks even before the next native publication', () => {
  for (const remaining of [0, 100, 150]) {
    const f = speechFixture();
    f.listenWords([{ uid: 1, text: 'cat', remaining_ms: remaining }]);
    f.latest.result([['cat', false]]);
    f.advance(150);
    f.latest.result([['cat', true]]);
    assert.deepEqual(f.events, []);
  }
  const f = speechFixture();
  f.listenWords([{ uid: 1, text: 'cat', remaining_ms: 100 }]);
  f.latest.result([['cat', false]]);
  f.advance(50);
  f.publishWords([{ uid: 1, text: 'cat', remaining_ms: 10000 }]);
  f.advance(100);
  assert.deepEqual(f.events, [], 'A later publication cannot extend the first-observation binding');
});

test('quest exact words reject partial, possessive and unreviewed suffixes', () => {
  const f = speechFixture();
  f.listenWords();
  const entries = [];
  for (const word of ['caterpillar', "cat's", 'catlike', 'ca']) {
    entries.push([word, true]);
    f.latest.result(entries, entries.length - 1);
  }
  assert.ok(f.events.every(event => event.target_uid === 0));
  entries.push(['CATS!', true]);
  f.latest.result(entries, entries.length - 1);
  assert.equal(f.events.at(-1).target_uid, 1);
  assert.equal(f.events.at(-1).text, 'CATS');
});

test('quest candidates survive unrelated Pop status changes', () => {
  const f = speechFixture();
  f.listenWords();
  f.latest.result([['cat', false]]);
  assert.equal(f.host.popStatus(JSON.stringify({ round_id: 'pop-unrelated', phase: 'idle', targets: [] })), true);
  f.advance(150);
  assert.equal(f.events.length, 1);
  assert.equal(f.events[0].round_id, 'quest-words-1');
  assert.equal(f.events[0].target_uid, 1);
});

test('quest floating-word round changes invalidate pending candidates and every old callback', () => {
  const f = speechFixture();
  f.listenWords();
  const old = f.latest;
  old.result([['cat', false]]);
  f.publishWords([{ uid: 1, text: 'cat', remaining_ms: 10000 }], 'quest-words-2');
  assert.equal(f.aborts, 1);
  old.capture();
  old.result([['cat', true]]);
  old.callbacks.error({ error: 'network' });
  old.callbacks.end();
  f.advance(1000);
  assert.deepEqual(f.events, []);
  assert.equal(f.starts, 1);
  f.host.speechMode(true, 'quest');
  f.advance();
  f.latest.capture();
  f.latest.result([['cat', true]]);
  assert.equal(f.events.length, 1);
  assert.equal(f.events[0].round_id, 'quest-words-2');
});

test('invalid floating-word bindings preserve capture and lifecycle stop cancels pending words', () => {
  for (const stop of ['stop', 'hidden', 'pagehide']) {
    const f = speechFixture();
    f.listenWords();
    for (const input of ['{', 'null', '[]', '{}', '{"round_id":"","targets":[]}',
      '{"round_id":"quest-words-1","targets":{}}']) assert.equal(f.host.questTargets(input), false);
    assert.equal(f.aborts, 0);
    const old = f.latest;
    old.result([['cat', false]]);
    if (stop === 'stop') f.host.stopSpeech();
    if (stop === 'hidden') { f.document.hidden = true; f.document.dispatch('visibilitychange'); }
    if (stop === 'pagehide') f.window.dispatch('pagehide');
    f.advance(1000);
    old.result([['cat', true]]);
    assert.deepEqual(f.events, []);
    assert.equal(f.starts, 1);
  }
});

test('quest candidate acknowledgements accept synchronous native receipts and direct fixture returns', () => {
  for (const direct of [false, true]) {
    const f = speechFixture();
    const received = [];
    f.host.observeQuestSpeech((json, receipt) => {
      received.push(JSON.parse(json));
      if (direct) return true;
      receipt.accepted = true;
    });
    f.listenWords();
    f.latest.result([['cat', false]]);
    f.advance(150);
    f.latest.result([['cats', true]]);
    assert.equal(received.length, 1);
  }
});
