const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const { chromium } = require('@playwright/test');
const api = require('../web/professional-progress.js');

function moduleFixture(course = 'retail', revision = 'content-1', requirementsRevision = 'objectives-1') {
  return { course_id: course, module_id: 'workplace', curriculum_revision: revision,
    requirements_revision: requirementsRevision,
    terms: Array.from({ length: 50 }, (_, index) => ({ sense_id: `sense-${index}`, skills: ['recognition', 'context', 'spelling'] })),
    expressions: Array.from({ length: 10 }, (_, index) => `expression-${index}`) };
}
const requirements = () => api.prepareRequirements([moduleFixture(), moduleFixture('nursing')]);
function event(id, changes = {}) {
  const mode = { context: 'phrase', spelling: 'word_jelly', speaking: 'pop' }[changes.skill] || 'match';
  return { id, sense_id: 'sense-0', skill: 'recognition', correct: true, assisted: false, atomic: false,
    context: { track: 'professional', course_id: 'retail', module_id: 'workplace', curriculum_revision: 'content-1', mode }, ...changes };
}

test('canonical sense/skill mastery survives mistakes and shares between careers without certifying other skills', () => {
  const rules = requirements();
  let progress = api.emptyProgress();
  progress = api.applyEvent(progress, event('first'), rules);
  progress = api.applyEvent(progress, event('second'), rules);
  progress = api.applyEvent(progress, event('hinted', { assisted: true }), rules);
  assert.equal(progress.skills['sense-0'].recognition.streak, 2);
  assert.equal(progress.skills['sense-0'].recognition.earned, false);
  const other = event('third'); other.context.course_id = 'nursing';
  progress = api.applyEvent(progress, other, rules);
  assert.equal(progress.skills['sense-0'].recognition.earned, true);
  assert.equal(progress.skills['sense-0'].spelling, undefined);
  progress = api.applyEvent(progress, event('mistake', { correct: false, assisted: true }), rules);
  assert.deepEqual(progress.skills['sense-0'].recognition, { streak: 0, earned: true, exposures: 5 });
  assert.equal(Object.keys(progress.completions).length, 0);
});

test('atomic Word Jelly collection permits ineligible spelling exposure without granting assessed mastery', () => {
  const row = moduleFixture(); row.terms[0].skills = ['recognition', 'context'];
  const rules = api.prepareRequirements([row]);
  let progress = api.emptyProgress();
  for (let index = 0; index < 4; index++) progress = api.applyEvent(progress,
    event(`atomic-${index}`, { atomic: true, skill: 'spelling' }), rules);
  assert.deepEqual(progress.skills['sense-0'].spelling, { streak: 0, earned: false, exposures: 4 });
  assert.equal(progress.skills['sense-0'].recognition, undefined);
  assert.deepEqual(progress.completions, {});
  assert.throws(() => api.validateEvent(event('assessed', { skill: 'spelling' }), rules), /does not belong/);
  assert.throws(() => api.validateEvent(event('unknown', { skill: 'spelling', atomic: true, sense_id: 'missing' }), rules), /does not belong/);
  assert.throws(() => api.validateEvent(event('incorrect', { skill: 'spelling', atomic: true, correct: false }), rules), /Atomic collection/);
  assert.throws(() => api.validateEvent(event('expression', { skill: 'spelling', atomic: true, expression_id: 'expression-0' }), rules), /Atomic collection/);
  assert.throws(() => api.validateEvent(event('wrong-atomic', { atomic: true }), rules), /Atomic collection/);
  const wrongMode = event('wrong-mode', { skill: 'spelling', atomic: true }); wrongMode.context.mode = 'match';
  assert.throws(() => api.validateEvent(wrongMode, rules), /exercise mode/);
});

test('every assessed skill must match the actual exercise mode', () => {
  const row = moduleFixture();
  const skills = ['recognition', 'listening', 'spelling', 'speaking', 'context'];
  row.terms[0].skills = skills;
  const rules = api.prepareRequirements([row]);
  const modes = { match: ['recognition', 'listening'], memory: ['recognition', 'listening'],
    pop: ['speaking'], phrase: ['context', 'listening'], jelly: ['recognition', 'listening'], word_jelly: ['spelling'] };
  for (const [mode, allowed] of Object.entries(modes)) for (const skill of skills) {
    const answer = event(`mode-${mode}-${skill}`, { skill }); answer.context.mode = mode;
    if (allowed.includes(skill)) assert.equal(api.validateEvent(answer, rules).skill, skill);
    else assert.throws(() => api.validateEvent(answer, rules), /exercise mode/);
  }
});

test('50 learned terms and all 10 unassisted expressions earn an immutable requirements receipt', () => {
  const rules = requirements();
  let progress = api.emptyProgress();
  for (let index = 0; index < 50; index++) for (let answer = 0; answer < 3; answer++) {
    progress = api.applyEvent(progress, event(`term-${index}-${answer}`, { sense_id: `sense-${index}` }), rules);
  }
  for (let index = 0; index < 10; index++) progress = api.applyEvent(progress,
    event(`assisted-${index}`, { skill: 'context', expression_id: `expression-${index}`, assisted: true }), rules);
  assert.equal(Object.keys(progress.completions).length, 0);
  for (let index = 0; index < 9; index++) progress = api.applyEvent(progress,
    event(`expression-${index}`, { skill: 'context', expression_id: `expression-${index}` }), rules);
  assert.equal(Object.keys(progress.completions).length, 0);
  progress = api.applyEvent(progress, event('last-expression', { skill: 'context', expression_id: 'expression-9' }), rules);
  const key = api.requirementKey(moduleFixture());
  assert.equal(progress.completions[key].requirements_revision, 'objectives-1');
  const receipt = structuredClone(progress.completions[key]);
  const revised = api.prepareRequirements([moduleFixture('retail', 'content-2')]);
  const next = event('new-content', { correct: false }); next.context.curriculum_revision = 'content-2';
  progress = api.applyEvent(progress, next, revised);
  assert.deepEqual(progress.completions[key], receipt);
  const replacement = moduleFixture('retail', 'content-3', 'objectives-2');
  replacement.terms[49].sense_id = 'new-sense';
  const later = event('new-objectives'); later.context.curriculum_revision = 'content-3';
  progress = api.applyEvent(progress, later, api.prepareRequirements([replacement]));
  assert.deepEqual(progress.completions[key], receipt);
  assert.equal(progress.completions[api.requirementKey(replacement)], undefined);
});

test('content and event validation reject changed revisions, invalid eligibility, malformed history, and fake module counts', () => {
  const row = moduleFixture(); row.terms.pop();
  assert.throws(() => api.prepareRequirements([row]), /50 terms/);
  assert.throws(() => api.validateEvent(event('bad', { sense_id: 'missing' }), requirements()), /does not belong/);
  assert.throws(() => api.validateEvent(event('bad', { correct: 'true' }), requirements()), /invalid/);
  assert.throws(() => api.validateEvent(event('bad', { expression_id: 'expression-0' }), requirements()), /contextual/);
  let progress = api.applyEvent(api.emptyProgress(), event('first'), requirements());
  const changed = moduleFixture(); changed.terms[0].skills = ['spelling'];
  assert.throws(() => api.applyEvent(progress, event('second', { skill: 'spelling' }), api.prepareRequirements([changed])), /without a new revision/);
  progress.skills['sense-0'].recognition.streak = 99;
  assert.throws(() => api.validateProgress(progress), /skill history/);
  assert.throws(() => api.prepareRequirements([moduleFixture(), { ...changed, curriculum_revision: 'content-2' }]), /different objectives/);
});

test('real IndexedDB transactions preserve retries, concurrent receipts, context, reward outbox, and acknowledgment', async () => {
  const server = http.createServer((_request, response) => { response.writeHead(200, { 'Content-Type': 'text/html' }); response.end('<!doctype html><title>Professional storage fixture</title>'); });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    await page.addScriptTag({ content: fs.readFileSync(require.resolve('../web/professional-progress.js'), 'utf8') });
    await page.evaluate(rows => {
      window.rows = rows;
      window.abortNext = false;
      window.first = ProfessionalProgress.createProfessionalProgressStore({ name: 'professional-test', requirements: [],
        beforeCommit(tx, operation) { if (window.abortNext && operation === 'record') { window.abortNext = false; tx.abort(); } } });
      window.second = ProfessionalProgress.createProfessionalProgressStore({ name: 'professional-test', requirements: rows });
      localStorage.setItem('growWithPip.growth.v1', 'legacy untouched');
    }, [moduleFixture(), moduleFixture('nursing')]);
    assert.equal((await page.evaluate(() => first.execute('load'))).progress.sequence, 0);
    assert.equal((await page.evaluate(() => first.execute('register', { requirements: rows }))).registered, 2);
    assert.equal((await page.evaluate(() => first.execute('register', { requirements: rows }))).ok, true);
    const contextValue = event('a').context;
    assert.equal((await page.evaluate(value => first.execute('context', value), contextValue)).ok, true);
    const rewardEvent = event('reward-event', { reward: { operation: 'credit', payload: { tier: 1 } } });
    await page.evaluate(() => { abortNext = true; });
    assert.equal((await page.evaluate(value => first.execute('record', value), rewardEvent)).ok, false);
    let loaded = await page.evaluate(() => second.execute('load'));
    assert.equal(loaded.progress.sequence, 0);
    assert.deepEqual(loaded.outbox, []);
    const duplicateResults = await page.evaluate(value => Promise.all([
      first.execute('record', value), second.execute('record', value), first.execute('record', value)
    ]), rewardEvent);
    assert.equal(duplicateResults.filter(result => result.duplicate === false).length, 1);
    assert.ok(duplicateResults.every(result => result.ok));
    const conflict = structuredClone(rewardEvent); conflict.correct = false; delete conflict.reward;
    assert.equal((await page.evaluate(value => second.execute('record', value), conflict)).ok, false);
    const answers = [event('parallel-a'), event('parallel-b')];
    assert.ok((await page.evaluate(values => Promise.all(values.map((value, index) =>
      (index ? second : first).execute('record', value))), answers)).every(result => result.ok));
    loaded = await page.evaluate(() => first.execute('load'));
    assert.equal(loaded.progress.sequence, 3);
    assert.equal(loaded.progress.skills['sense-0'].recognition.streak, 3);
    const changedRequirements = moduleFixture(); changedRequirements.terms[0].skills = ['spelling'];
    assert.equal((await page.evaluate(row => first.execute('register', { requirements: [row] }), changedRequirements)).ok, false);
    assert.deepEqual(loaded.context, contextValue);
    assert.deepEqual(loaded.outbox, [{ id: 'reward-event', receipt_id: 'professional:reward-event', operation: 'credit', payload: { tier: 1 } }]);
    // Simulate wallet delivery followed by a crash before acknowledgment: reload
    // replays the same permanent wallet receipt, never a newly minted reward ID.
    await page.evaluate(() => { first.close(); second.close(); });
    await page.reload();
    await page.addScriptTag({ content: fs.readFileSync(require.resolve('../web/professional-progress.js'), 'utf8') });
    await page.evaluate(rows => { window.store = ProfessionalProgress.createProfessionalProgressStore({ name: 'professional-test', requirements: rows }); }, [moduleFixture(), moduleFixture('nursing')]);
    loaded = await page.evaluate(() => store.execute('load'));
    assert.equal(loaded.outbox[0].receipt_id, 'professional:reward-event');
    assert.equal((await page.evaluate(() => store.execute('ack', { id: 'reward-event' }))).ok, true);
    assert.equal((await page.evaluate(() => store.execute('ack', { id: 'reward-event' }))).duplicate, true);
    assert.equal((await page.evaluate(value => store.execute('record', value), rewardEvent)).duplicate, true);
    assert.deepEqual((await page.evaluate(() => store.execute('load'))).outbox, []);
    assert.equal((await page.evaluate(() => store.execute('ack', { id: 'parallel-a' }))).ok, false);
    assert.equal(await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1')), 'legacy untouched');
    const secondPage = await context.newPage();
    await secondPage.goto(page.url());
    await secondPage.addScriptTag({ content: fs.readFileSync(require.resolve('../web/professional-progress.js'), 'utf8') });
    await secondPage.evaluate(rows => { window.store = ProfessionalProgress.createProfessionalProgressStore({ name: 'professional-test', requirements: rows }); }, [moduleFixture()]);
    const acrossTabs = event('across-tabs');
    const concurrent = await Promise.all([
      page.evaluate(value => store.execute('record', value), acrossTabs),
      secondPage.evaluate(value => store.execute('record', value), acrossTabs)
    ]);
    assert.equal(concurrent.filter(result => result.ok && !result.duplicate).length, 1);
    assert.equal(concurrent.filter(result => result.ok && result.duplicate).length, 1);
    assert.equal((await page.evaluate(() => store.execute('load'))).progress.sequence, 4);
    await secondPage.evaluate(() => store.close());
    await secondPage.close();
    const bridgeResult = await page.evaluate(async rows => {
      const bridge = ProfessionalProgress.createProfessionalProgressBridge({ name: 'professional-test' });
      let inCall = true, reentered = false;
      const registration = new Promise(resolve => {
        bridge.professionalProgressRequest(JSON.stringify({ request_id: 71, operation: 'register', payload: { requirements: rows } }), text => {
          reentered = inCall;
          resolve(JSON.parse(text));
        });
        inCall = false;
      });
      const registered = await registration;
      const loaded = await new Promise(resolve => bridge.professionalProgressRequest(
        JSON.stringify({ request_id: 72, operation: 'load', payload: {} }), text => resolve(JSON.parse(text))));
      bridge.close();
      return { registered, loaded, reentered };
    }, [moduleFixture()]);
    assert.equal(bridgeResult.registered.request_id, 71);
    assert.equal(bridgeResult.registered.ok, true);
    assert.equal(bridgeResult.loaded.request_id, 72);
    assert.equal(bridgeResult.loaded.progress.sequence, 4);
    assert.equal(bridgeResult.reentered, false);
    await page.evaluate(() => store.close());
    await context.close();
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
});

test('unavailable storage fails visibly without returning a fresh profile', async () => {
  const store = api.createProfessionalProgressStore({ requirements: [moduleFixture()], indexedDB: {
    open() { throw new Error('Storage denied'); }
  } });
  const result = await store.execute('load');
  assert.equal(result.ok, false);
  assert.equal(result.retryable, true);
  assert.equal(result.progress, undefined);
  assert.match(result.error, /Storage denied/);
});


test('held-six populated histories isolate revised identities across IndexedDB retries and restart', async () => {
  const fixture = JSON.parse(fs.readFileSync(require.resolve('./fixtures/professional-held-six-progress.json'), 'utf8'));
  const shell = fs.readFileSync(require.resolve('../web/shell.html'), 'utf8').replace(/\r\n/g, '\n');
  const walletBlock = shell.match(/        coinWalletState\(\) \{[\s\S]*?\n        \},\n        saveCoinWalletState\(text, expectedText\) \{[\s\S]*?\n        \}/)?.[0];
  assert.ok(walletBlock, 'Use the existing browser wallet storage bridge');
  const server = http.createServer((_request, response) => { response.writeHead(200, { 'Content-Type': 'text/html' }); response.end('<!doctype html><title>Held-six populated history fixture</title>'); });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext(), page = await context.newPage();
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    async function connect() {
      await page.addScriptTag({ content: fs.readFileSync(require.resolve('../web/professional-progress.js'), 'utf8') });
      await page.addScriptTag({ content: `window.heldWallet = ({${walletBlock}});` });
      await page.evaluate(f => {
        window.heldName = 'professional-held-six-populated'; window.heldAbort = '';
        window.current = ProfessionalProgress.createProfessionalProgressStore({ name: heldName, requirements: f.current_rows,
          beforeCommit(tx, operation) { if (heldAbort === operation) { heldAbort = ''; tx.abort(); } } });
        window.legacy = ProfessionalProgress.createProfessionalProgressStore({ name: heldName, requirements: f.old_rows });
        window.heldSnapshot = () => new Promise((resolve, reject) => {
          const open = indexedDB.open(heldName);
          open.onerror = () => reject(open.error);
          open.onsuccess = () => {
            const db = open.result, tx = db.transaction(['progress', 'context', 'events', 'outbox'], 'readonly');
            const values = {}, requests = { progress: tx.objectStore('progress').get('current'), context: tx.objectStore('context').get('current'),
              eventKeys: tx.objectStore('events').getAllKeys(), events: tx.objectStore('events').getAll(),
              outboxKeys: tx.objectStore('outbox').getAllKeys(), outbox: tx.objectStore('outbox').getAll() };
            for (const [key, request] of Object.entries(requests)) request.onsuccess = () => { values[key] = request.result; };
            tx.onabort = () => { db.close(); reject(tx.error); };
            tx.oncomplete = () => { db.close(); resolve({ schema: db.version, progress: values.progress, context: values.context,
              events: Object.fromEntries(values.eventKeys.map((key, i) => [key, values.events[i]])),
              outbox: Object.fromEntries(values.outboxKeys.map((key, i) => [key, values.outbox[i]])) }); };
          };
        });
      }, fixture);
    }
    await connect();
    assert.equal((await page.evaluate(() => current.execute('load'))).ok, true);
    await page.evaluate(f => new Promise((resolve, reject) => {
      const open = indexedDB.open(heldName); open.onerror = () => reject(open.error);
      open.onsuccess = () => {
        const db = open.result, tx = db.transaction(['progress', 'context', 'events', 'outbox'], 'readwrite');
        tx.objectStore('progress').put(f.legacy_state.progress, 'current'); tx.objectStore('context').put(f.legacy_state.context, 'current');
        for (const key of ['events', 'outbox']) for (const [id, value] of Object.entries(f.legacy_state[key])) tx.objectStore(key).put(value, id);
        tx.oncomplete = () => { db.close(); resolve(); }; tx.onabort = () => { db.close(); reject(tx.error); };
      };
      localStorage.setItem('growWithPip.growth.v1', 'held-six growth sentinel');
      localStorage.setItem('growWithPip.coinWallet.v1', f.wallet.initial.text);
    }), fixture);
    const snapshot = () => page.evaluate(() => heldSnapshot());
    assert.deepEqual(await snapshot(), fixture.legacy_state);
    assert.equal((await page.evaluate(rows => current.execute('register', { requirements: rows }), fixture.current_rows)).ok, true);
    assert.deepEqual(await snapshot(), fixture.legacy_state, 'Registration preserves every historical saved field');
    for (const id of fixture.current_ids) assert.equal(fixture.legacy_state.progress.skills[id], undefined, 'No selected new-ID evidence is pre-seeded');
    const oldRetry = fixture.legacy_events[0];
    const stale = await page.evaluate(e => current.execute('record', e), oldRetry);
    assert.equal(stale.ok, false); assert.match(stale.error, /professional module revision/);
    assert.equal((await page.evaluate(e => legacy.execute('record', e), oldRetry)).duplicate, true);
    assert.deepEqual(await snapshot(), fixture.legacy_state, 'Old retry is rejected or validated in its exact old context, never translated');
    const changed = structuredClone(fixture.old_rows[0]); changed.terms[0].skills = ['spelling'];
    const changedResult = await page.evaluate(row => current.execute('register', { requirements: [row] }), changed);
    assert.equal(changedResult.ok, false); assert.match(changedResult.error, /without a new revision/);
    assert.equal((await page.evaluate(e => legacy.execute('record', e), fixture.old_later_event)).ok, true);
    const afterOldWriter = await snapshot();
    assert.equal(afterOldWriter.progress.sequence, fixture.expected_sequence.after_old_writer);
    assert.deepEqual(afterOldWriter.progress.completions, fixture.legacy_state.progress.completions);
    assert.equal((await page.evaluate(value => current.execute('context', value), fixture.current_events[0].context)).ok, true);
    const beforeFailedWrite = await snapshot();
    await page.evaluate(() => { heldAbort = 'record'; });
    assert.equal((await page.evaluate(e => current.execute('record', e), fixture.current_events[0])).ok, false);
    assert.deepEqual(await snapshot(), beforeFailedWrite, 'Aborted current write cannot alter old history or create a reward');
    for (const [index, e] of fixture.current_events.entries()) {
      const recorded = await page.evaluate(value => current.execute('record', value), e);
      assert.equal(recorded.ok, true); assert.equal(recorded.duplicate, false);
      const evidence = recorded.progress.skills[e.sense_id], step = index % 8;
      if (step === 0) assert.deepEqual(evidence.recognition, { streak: 0, earned: false, exposures: 1 });
      if (step === 1) assert.deepEqual(evidence.spelling, { streak: 0, earned: false, exposures: 1 });
      if (step === 3) assert.deepEqual(evidence.recognition, { streak: 0, earned: false, exposures: 3 });
      if (step === 6) assert.deepEqual(evidence.recognition, { streak: 3, earned: true, exposures: 6 });
      if (step === 7) assert.deepEqual(evidence.recognition, { streak: 0, earned: true, exposures: 7 });
    }
    const beforeRetry = await snapshot();
    assert.equal((await page.evaluate(e => current.execute('record', e), fixture.current_events[0])).duplicate, true);
    const conflict = structuredClone(fixture.current_events[0]); conflict.assisted = false;
    const conflicted = await page.evaluate(e => current.execute('record', e), conflict);
    assert.equal(conflicted.ok, false); assert.match(conflicted.error, /different event/);
    assert.deepEqual(await snapshot(), beforeRetry);
    assert.equal((await page.evaluate(e => current.execute('record', e), fixture.shared_career_event)).ok, true);
    const currentKey = api.requirementKey(fixture.current_rows[0]), beforeExpressions = await snapshot();
    assert.equal(beforeExpressions.progress.sequence, fixture.expected_sequence.before_new_expressions);
    assert.equal(beforeExpressions.progress.expressions[currentKey], undefined);
    assert.equal(beforeExpressions.progress.completions[currentKey], undefined, 'Retired mastery and the old expression map never satisfy the new revision');
    assert.equal(beforeExpressions.progress.skills[fixture.unchanged_sense_id].recognition.earned, true);
    for (const [index, e] of fixture.expression_events.entries()) {
      const recorded = await page.evaluate(value => current.execute('record', value), e); assert.equal(recorded.ok, true);
      assert.equal(Boolean(recorded.progress.completions[currentKey]), index === 9);
    }
    const beforeWalletFailure = await snapshot();
    assert.equal(await page.evaluate(text => heldWallet.saveCoinWalletState(text, 'not-the-current-wallet'), fixture.wallet.after_legacy_delivery.text), false);
    assert.deepEqual(await snapshot(), beforeWalletFailure, 'Failed wallet persistence leaves pending professional rewards intact');
    assert.equal(await page.evaluate(f => heldWallet.saveCoinWalletState(f.wallet.after_legacy_delivery.text, f.wallet.initial.text), fixture), true);
    await page.evaluate(() => { heldAbort = 'ack'; });
    assert.equal((await page.evaluate(() => current.execute('ack', { id: 'held-six.old.pending' }))).ok, false);
    const beforeRestart = await snapshot();
    await page.evaluate(() => { current.close(); legacy.close(); }); await page.reload(); await connect();
    assert.deepEqual(await snapshot(), beforeRestart, 'Restart preserves the complete populated save, event receipts and both outbox entries');
    assert.equal(await page.evaluate(f => heldWallet.saveCoinWalletState(f.wallet.after_legacy_delivery.text, f.wallet.initial.text), fixture), false, 'A stale wallet write cannot replace the delivered receipt');
    assert.equal(await page.evaluate(() => heldWallet.coinWalletState()), fixture.wallet.after_legacy_delivery.text);
    assert.equal((await page.evaluate(() => current.execute('ack', { id: 'held-six.old.pending' }))).ok, true);
    assert.equal((await page.evaluate(() => current.execute('ack', { id: 'held-six.old.pending' }))).duplicate, true);
    assert.equal(await page.evaluate(f => heldWallet.saveCoinWalletState(f.wallet.final.text, f.wallet.after_legacy_delivery.text), fixture), true);
    assert.equal((await page.evaluate(id => current.execute('ack', { id }), fixture.current_events[0].id)).ok, true);
    assert.equal((await page.evaluate(e => current.execute('record', e), fixture.current_events[0])).duplicate, true);
    assert.equal((await page.evaluate(e => legacy.execute('record', e), fixture.legacy_events[1])).duplicate, true);
    assert.equal((await page.evaluate(e => current.execute('record', e), fixture.legacy_events[1])).ok, false);
    assert.deepEqual(await snapshot(), fixture.expected_final_state, 'Full normalized browser state matches the shared native expectation');
    assert.equal(await page.evaluate(() => heldWallet.coinWalletState()), fixture.wallet.final.text);
    assert.equal(await page.evaluate(() => localStorage.getItem('growWithPip.growth.v1')), 'held-six growth sentinel');
    await page.evaluate(() => { current.close(); legacy.close(); }); await context.close();
  } finally {
    await browser.close(); await new Promise(resolve => server.close(resolve));
  }
});

test('actual Foundation01 senses share career evidence while intact exposure and Growth input cannot grant mastery', () => {
  const document = JSON.parse(fs.readFileSync(require('node:path').join(__dirname, '../data/professional/lexemes/foundation-module01.json'), 'utf8'));
  // Synthetic requirements exercise the progress boundary without claiming
  // that this draft module or its missing media is available for play.
  const row = moduleFixture();
  row.terms = document.lexemes.map(entry => ({sense_id:entry.id,
    skills:entry.morphology.kind === 'atomic' ? ['recognition', 'context'] : ['recognition', 'context', 'spelling']}));
  const rules = api.prepareRequirements([row, {...structuredClone(row), course_id:'nursing'}]);
  let progress = api.emptyProgress();
  const atomic = document.lexemes.filter(entry => entry.morphology.kind === 'atomic');
  assert.equal(atomic.length, 16);
  for (const entry of atomic) {
    for (let index = 0; index < 4; index++) progress = api.applyEvent(progress,
      event('foundation-atomic-' + entry.id + '-' + index, {sense_id:entry.id, skill:'spelling', atomic:true}), rules);
    assert.deepEqual(progress.skills[entry.id].spelling, {streak:0, earned:false, exposures:4});
    assert.equal(progress.skills[entry.id].recognition, undefined);
  }
  assert.deepEqual(progress.completions, {});
  const signature = 'signature.written-name.n';
  for (let index = 0; index < 3; index++) {
    const answer = event('foundation-signature-' + index, {sense_id:signature, skill:'spelling'});
    answer.context.course_id = index === 2 ? 'nursing' : 'retail';
    progress = api.applyEvent(progress, answer, rules);
  }
  assert.equal(progress.skills[signature].spelling.earned, true);
  assert.equal(progress.skills[signature].recognition, undefined);
  const before = structuredClone(progress);
  const growth = event('foundation-growth', {sense_id:'responsibility', skill:'spelling'});
  growth.context = {track:'growth', mode:'word_jelly', age:11};
  assert.throws(() => api.applyEvent(progress, growth, rules));
  assert.deepEqual(progress, before);
  assert.equal(progress.skills.responsibility, undefined);
  for (const id of ['signate', 'sign.observable-clinical-finding.n', 'sign-in.start-authenticated-account-session.v']) {
    assert.throws(() => api.applyEvent(progress, event('wrong-foundation-' + id, {sense_id:id, skill:'spelling'}), rules));
  }
  assert.deepEqual(progress.completions, {});
});
