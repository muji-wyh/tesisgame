const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const shell = fs.readFileSync(path.join(__dirname, '../web/shell.html'), 'utf8');
const source = shell.match(/      function createSpeechDebugPanel\(host, nativeAction\) \{[\s\S]*?\n      \}/)?.[0];
assert.ok(source);

function fixture({ search = '?speechDebug=1', clipboard = true } = {}) {
  const nodes = [], timers = new Map(), actions = [], copies = [];
  let time = 0, nextTimer = 1, nextTarget = 0, callbacks, canStop = true, canOpen = true;
  function element(tagName) {
    const handlers = {};
    const value = { tagName, children: [], hidden: false, disabled: false, value: '', style: {}, attributes: {},
      append(...children) { this.children.push(...children); },
      addEventListener(type, handler) { (handlers[type] ||= []).push(handler); },
      setAttribute(name, text) { this.attributes[name] = text; },
      dispatch(type, event = {}) { return Promise.all((handlers[type] || []).map(handler => handler({ stopPropagation() {}, ...event }))); },
      click() { return this.disabled ? Promise.resolve() : this.dispatch('click'); },
      focus() { this.focused = true; }, select() { this.selected = true; }
    };
    nodes.push(value);
    return value;
  }
  const canvas = element('canvas');
  canvas.inert = false;
  const document = Object.assign(element('document'), { body: element('body'), hidden: false,
    createElement: element, getElementById: id => id === 'canvas' ? canvas : nodes.find(node => node.id === id) });
  const window = Object.assign(element('window'), {
    location: { search }, performance: { now: () => time }, navigator: { userAgent: 'Test browser' },
    setTimeout(callback, delay) { const id = nextTimer++; timers.set(id, { callback, at: time + delay }); return id; },
    clearTimeout(id) { timers.delete(id); }
  });
  if (clipboard) window.navigator.clipboard = { writeText: async text => copies.push(JSON.parse(text)) };
  const host = {
    begins: 0, ends: 0, prompts: [],
    beginSpeechPractice(value) { callbacks = value; this.begins++; return true; },
    practiceTarget(text) { const target = { uid: ++nextTarget, text, forms: [text] }; this.prompts.push(target); return target; },
    endSpeechPractice() { this.ends++; return canStop; }
  };
  const factory = vm.runInNewContext(`(${source})`, { window, document, URLSearchParams });
  const helper = factory(host, (action, value) => {
    actions.push({ action, value });
    return action === 'open' ? canOpen : true;
  });
  const byText = text => nodes.find(node => node.tagName === 'button' && node.textContent === text);
  return { helper, document, window, nodes, host, actions, copies, canvas, timers, byText,
    get callbacks() { return callbacks; },
    get launch() { return nodes.find(node => node.id === 'speech-debug-launch'); },
    get panel() { return nodes.find(node => node.id === 'speech-debug'); },
    set canStop(value) { canStop = value; }, set canOpen(value) { canOpen = value; },
    async open() { helper.setAvailable(true); await this.launch.click(); },
    async start() { await byText('Start listening').click(); callbacks.onState(true, true, ''); },
    advance(ms) {
      const end = time + ms;
      for (let count = 0; count < 100; count++) {
        const next = [...timers].filter(([, timer]) => timer.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
        if (!next) { time = end; return; }
        time = next[1].at; timers.delete(next[0]); next[1].callback();
      }
      throw new Error('Unexpected timer loop');
    }
  };
}

test('ordinary URLs add no diagnostic UI or native calls', () => {
  for (const search of ['', '?speechDebug=0']) {
    const f = fixture({ search });
    f.helper.setAvailable(true);
    assert.equal(f.launch, undefined);
    assert.deepEqual(f.actions, []);
    assert.equal(f.document.body.children.length, 0);
  }
});

test('diagnostics open only after native pause acknowledgement and microphone activation is explicit', async () => {
  const f = fixture();
  assert.equal(f.launch.hidden, true);
  f.canOpen = false;
  await f.open();
  assert.equal(f.panel.hidden, true);
  assert.equal(f.canvas.inert, false);
  f.canOpen = true;
  await f.launch.click();
  assert.equal(f.panel.hidden, false);
  assert.equal(f.canvas.inert, true);
  assert.equal(f.host.begins, 0);
  await f.start();
  assert.equal(f.host.prompts[0].text, 'cat');
  assert.ok(f.actions.some(value => value.action === 'mix' && value.value === 1));
  f.advance(300);
  assert.ok(f.actions.some(value => value.action === 'cue' && value.value === 'launch'));
  await f.byText('Close').click();
  assert.equal(f.panel.hidden, true);
  assert.equal(f.canvas.inert, false);
  assert.equal(f.timers.size, 0);
  assert.equal(f.host.ends, 1);
  assert.equal(f.actions.at(-1).action, 'close');
});

test('reviewed attempts retain raw candidates and correctly separate target and control statistics', async () => {
  const f = fixture();
  await f.open();
  const selects = f.nodes.filter(node => node.tagName === 'select');
  selects[0].value = '0.35';
  await f.start();
  f.callbacks.onResult('cat', true, [{ text: 'cat', confidence: 0.9 }, { text: 'cap', confidence: 0.8 }]);
  f.callbacks.onHit({ target_uid: f.host.prompts.at(-1).uid });
  await f.byText('Correct').click();
  assert.equal(f.host.begins, 1, 'Next prompt keeps the continuous recognition session');
  assert.equal(f.host.prompts.at(-1).text, 'dog');
  await f.byText('No result').click();
  await f.byText('Copy report').click();
  const report = f.copies[0];
  assert.equal(report.attempts.length, 2);
  assert.equal(report.attempts[0].mix, 0.35);
  assert.equal(report.attempts[0].revisions[0].alternatives[1].text, 'cap');
  assert.equal(report.statistics.correct_text_rate, 0.5);
  assert.equal(report.statistics.no_result_rate, 0.5);
  assert.equal(report.statistics.target_match_rate, 0.5);
  assert.equal(report.statistics.control_false_hit_rate, null, 'No control samples cannot imply zero false hits');
  assert.match(report.timing_basis, /not audio/);
  await f.byText('Stop listening').click();
  selects[3].value = 'other';
  await f.start();
  f.callbacks.onHit({ target_uid: f.host.prompts.at(-1).uid });
  await f.byText('Wrong').click();
  await f.byText('Copy report').click();
  assert.equal(f.copies.at(-1).statistics.control_false_hit_rate, 1);
});

test('stop failure keeps the native game paused and exposes another stop attempt', async () => {
  const f = fixture();
  await f.open(); await f.start();
  f.canStop = false;
  await f.byText('Close').click();
  assert.equal(f.panel.hidden, false);
  assert.equal(f.canvas.inert, true);
  assert.equal(f.actions.some(value => value.action === 'close'), false);
  assert.equal(f.byText('Stop listening').disabled, false);
  assert.equal(f.timers.size, 0);
  f.canStop = true;
  await f.byText('Close').click();
  assert.equal(f.panel.hidden, true);
});

test('background stops cues and microphone, restores the canvas and rejects late callbacks', async () => {
  const f = fixture();
  await f.open(); await f.start();
  const old = f.callbacks;
  f.document.hidden = true;
  await f.document.dispatch('visibilitychange');
  assert.equal(f.host.ends, 1);
  assert.equal(f.panel.hidden, true);
  assert.ok(f.actions.some(value => value.action === 'close' && value.value === true));
  assert.equal(f.canvas.inert, false);
  assert.equal(f.timers.size, 0);
  old.onResult('stale', true, []);
  assert.equal(f.nodes.find(node => node.id === 'speech-debug-heard').textContent, 'No text received yet.');
});

test('report copy fallback is selectable and histories are bounded', async () => {
  const f = fixture({ clipboard: false });
  await f.open(); await f.start();
  for (let index = 0; index < 600; index++) {
    f.callbacks.onDiagnostic({ type: 'result', index, alternatives: [{ text: 'x'.repeat(3000), confidence: 0.9 }] });
    f.callbacks.onResult(`revision ${index}`, false, []);
  }
  await f.byText('Wrong').click();
  await f.byText('Copy report').click();
  const box = f.nodes.find(node => node.id === 'speech-debug-report');
  assert.equal(box.hidden, false);
  assert.equal(box.selected, true);
  const report = JSON.parse(box.value);
  assert.equal(report.events.length, 500);
  assert.equal(report.events[0].alternatives[0].text.length, 2000);
  assert.equal(report.attempts[0].revisions.length, 12);
  await f.byText('Clear report').click();
  assert.equal(box.value, '');
  await f.byText('Copy report').click();
  assert.equal(JSON.parse(box.value).attempts.length, 0);
  assert.equal(JSON.parse(box.value).current_attempt, null);
});

test('a completed pass preserves the actionable message if microphone shutdown fails', async () => {
  const f = fixture();
  await f.open(); await f.start();
  f.canStop = false;
  for (let index = 0; index < 24; index++) await f.byText('No result').click();
  assert.match(f.nodes.find(node => node.attributes.role === 'status').textContent, /could not be stopped/);
  assert.equal(f.byText('Stop listening').disabled, false);
  assert.equal(f.panel.hidden, false);
  assert.equal(f.actions.some(value => value.action === 'close'), false);
});

test('capture failures expose a retry that safely stops the old session first', async () => {
  const f = fixture();
  await f.open(); await f.start();
  f.callbacks.onDiagnostic({ type: 'capture_timeout' });
  f.callbacks.onState(true, false, 'Microphone audio did not start. Tap Retry.');
  assert.equal(f.byText('Retry listening').hidden, false);
  await f.byText('Retry listening').click();
  assert.equal(f.host.ends, 1);
  assert.equal(f.host.begins, 2);
  assert.equal(f.host.prompts.at(-1).text, 'cat');
});

test('a late clipboard failure cannot restore a cleared report or refocus a closed panel', async () => {
  for (const action of ['Clear report', 'Close']) {
    const f = fixture();
    await f.open(); await f.start();
    f.callbacks.onResult('cat', true, []);
    let rejectCopy;
    f.window.navigator.clipboard.writeText = () => new Promise((resolve, reject) => { rejectCopy = reject; });
    const copying = f.byText('Copy report').click();
    await f.byText(action).click();
    rejectCopy(new Error('Clipboard permission denied'));
    await copying;
    const box = f.nodes.find(node => node.id === 'speech-debug-report');
    assert.equal(box.hidden, true);
    assert.equal(box.value, '');
    assert.equal(box.focused, undefined);
  }
});
