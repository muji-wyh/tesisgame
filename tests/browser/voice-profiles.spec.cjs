const path = require('node:path');
const { test, expect } = require('@playwright/test');

// The real UI and persistent store run against a deterministic voice host.
// These tests check consent, lifecycle and accessibility, not acoustic accuracy.
const KEY = 'voice-pop-voice-profiles-v1';
async function fixture(page, { count = 0, status = 'ready', corrupt = false, oldModel = false, templateCount = 0 } = {}) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/voice-profiles-fixture.html', route => route.fulfill({
    contentType: 'text/html',
    body: '<!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Voice profile UI fixture</title><style>*{box-sizing:border-box}body{margin:0;font-family:sans-serif}button{font:inherit}</style></head><body><main id="background"><button id="users">Users</button><button id="play">Play</button></main></body></html>'
  }));
  await page.goto('/voice-profiles-fixture.html');
  await page.addStyleTag({ path: path.resolve(__dirname, '../../web/voice-profiles.css') });
  await page.addScriptTag({ path: path.resolve(__dirname, '../../web/voice-profiles.js') });
  await page.addScriptTag({ path: path.resolve(__dirname, '../../web/voice-profiles-ui.js') });
  await page.evaluate(({ count, status, corrupt, oldModel, templateCount, key }) => {
    const store = new VoiceProfileStore();
    const embedding = Array(256).fill(0); embedding[0] = 1;
    for (let index = 0; index < count; index++) store.save({ id: `saved-${index}`, name: `Player ${index + 1}`, emoji: '🐱',
      embedding, ...(templateCount ? { templates: Array.from({ length: templateCount }, () => embedding.slice()) } : {}),
      modelVersion: SPEAKER_MODEL_VERSION });
    if (corrupt) localStorage.setItem(key, '{unreadable-save');
    if (oldModel) {
      const saved = JSON.parse(localStorage.getItem(key));
      saved.profiles[0].modelVersion = 'previous-speaker-model';
      localStorage.setItem(key, JSON.stringify(saved));
    }
    const host = {
      state: { status, loaded: 0, total: 0 }, listeners: [], starts: 0, stops: 0, prepares: 0,
      current: null, blockedStop: false, permissionPending: false, nextStartError: '', nextFinishError: '',
      identification: null, identificationStarts: 0, identificationStops: 0,
      identificationActive: false, nextIdentificationError: '',
      observe(callback) { this.listeners.push(callback); callback(this.state); return () => {}; },
      setState(state) { this.state = state; this.listeners.forEach(callback => callback(state)); },
      isReady() { return this.state.status === 'ready'; },
      prepare() { this.prepares++; this.setState({ status: 'downloading', loaded: 420, total: 1000 }); return Promise.resolve(false); },
      verifyReady() { return Promise.resolve(this.isReady()); },
      startEnrollment(options) {
        this.starts++;
        this.current = options;
        if (this.nextStartError) {
          const error = this.nextStartError; this.nextStartError = '';
          queueMicrotask(() => options.onError(new Error(error)));
          return Promise.resolve(false);
        }
        if (!this.permissionPending) options.onStarted();
        return Promise.resolve(true);
      },
      progress(segments = 3, voicedMs = 13200) {
        this.current.onProgress({ segments, voicedMs, requiredSegments: 3, requiredVoicedMs: 12000,
          progress: Math.min(1, segments / 3, voicedMs / 12000), canFinish: segments >= 3 && voicedMs >= 12000 });
      },
      result() {
        const templates = [0, 1, 2].map(index => {
          const vector = embedding.slice();
          if (index) { vector[0] = 0.98; vector[index] = Math.sqrt(1 - 0.98 ** 2); }
          return vector;
        });
        return { embedding: embedding.slice(), templates,
          segments: templates.map(vector => ({ embedding: vector.slice(), voicedMs: 4400 })),
          modelVersion: SPEAKER_MODEL_VERSION, quality: { segments: 3, voicedMs: 13200 } };
      },
      async finishEnrollment() {
        if (this.nextFinishError) { const error = this.nextFinishError; this.nextFinishError = ''; throw new Error(error); }
        const result = this.result();
        this.current.onComplete(result);
        return result;
      },
      cancelEnrollment() {
        this.stops++;
        if (this.blockedStop) return false;
        if (this.state.microphoneBlocked) this.setState({ ...this.state, microphoneBlocked: false, microphoneMessage: '' });
        return true;
      },
      startIdentification(options) {
        this.identificationStarts++;
        this.identification = options;
        this.identificationActive = true;
        if (this.nextIdentificationError) {
          const error = this.nextIdentificationError; this.nextIdentificationError = '';
          queueMicrotask(() => options.onError(new Error(error)));
          return Promise.resolve(false);
        }
        if (!this.permissionPending) options.onStarted();
        return Promise.resolve(true);
      },
      identificationProgress(voicedMs = 2000, requiredVoicedMs = 4000) {
        this.identification.onProgress({ progress: Math.min(1, voicedMs / requiredVoicedMs),
          segments: 1, requiredSegments: 2, voicedMs, requiredVoicedMs, message: 'Listening — keep speaking in your normal voice.' });
      },
      identificationResult(index = 0) {
        const match = index < 0 ? null : this.identification.profiles[index];
        return { profile: match ? { id: match.id, name: match.name, emoji: match.emoji } : null,
          quality: { segments: 2, voicedMs: 4400, similarity: match ? 0.91 : 0.18, reason: match ? 'matched' : 'unknown_voice' } };
      },
      completeIdentification(index = 0) {
        this.identificationActive = false;
        this.identification.onComplete(this.identificationResult(index));
      },
      cancelIdentification() {
        this.identificationStops++;
        if (this.blockedStop) return false;
        this.identificationActive = false;
        if (this.state.microphoneBlocked) this.setState({ ...this.state, microphoneBlocked: false, microphoneMessage: '' });
        return true;
      }
    };
    const observed = { changes: [], closes: 0, gameKeys: 0, gameClicks: 0, profileWrites: 0 };
    const writeStorage = Storage.prototype.setItem;
    Storage.prototype.setItem = function (storageKey, value) {
      if (storageKey === key) observed.profileWrites++;
      return writeStorage.call(this, storageKey, value);
    };
    const ui = new VoiceProfilesUI({ multiplayer: host, store,
      onChanged: profiles => observed.changes.push(profiles), onClose: () => observed.closes++ });
    document.getElementById('users').addEventListener('click', () => ui.open());
    document.addEventListener('keydown', () => observed.gameKeys++);
    document.addEventListener('click', event => { if (event.target.closest('#voice-profiles')) observed.gameClicks++; });
    window.profileFixture = { store, host, ui, observed };
  }, { count, status, corrupt, oldModel, templateCount, key: KEY });
  await page.locator('#users').click();
  await expect(page.getByRole('dialog')).toBeVisible();
  return errors;
}

const button = (page, name) => page.getByRole('button', { name, exact: true });
async function add(page, name = 'Alex') {
  await button(page, 'Add user').click();
  await page.getByLabel('Name', { exact: true }).fill(name);
}
async function recording(page) {
  await button(page, 'Record voice').click();
  await expect(page.locator('.vp-record-status')).toContainText('Recording');
  await page.evaluate(() => profileFixture.host.progress());
  await expect(page.locator('.vp-timing')).toContainText('3/3 voice samples');
  await expect(page.locator('.vp-timing')).toContainText('13.2 / 12 s effective speech');
  await button(page, 'Stop').click();
  await expect(page.locator('.vp-record-status')).toContainText('Ready to save');
}

test('downloads show byte progress and initialization never enables recording prematurely', async ({ page }) => {
  const errors = await fixture(page, { status: 'idle' });
  await expect(page.locator('.vp-model')).toContainText('42%');
  await add(page);
  await expect(button(page, 'Record voice')).toBeDisabled();
  await page.evaluate(() => profileFixture.host.setState({ status: 'downloading', loaded: 1000, total: 1000 }));
  await expect(page.locator('.vp-model')).toContainText('100%');
  await expect(button(page, 'Record voice')).toBeDisabled();
  await page.evaluate(() => profileFixture.host.setState({ status: 'initializing', loaded: 1000, total: 1000 }));
  await expect(page.locator('.vp-model')).toContainText('Starting voice recording');
  await expect(button(page, 'Record voice')).toBeDisabled();
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Alex');
  await page.evaluate(() => profileFixture.host.setState({ status: 'error', message: 'Model initialization failed.' }));
  await expect(page.locator('.vp-model')).toContainText('Model initialization failed');
  await button(page, 'Retry').click();
  expect(await page.evaluate(() => profileFixture.host.prepares)).toBe(2);
  await page.evaluate(() => profileFixture.host.setState({ status: 'ready' }));
  await expect(button(page, 'Record voice')).toBeEnabled();
  expect(errors).toEqual([]);
});

test('six voice prompts only become a saved profile after explicit Save, retaining the voice templates and native emoji avatar', async ({ page }) => {
  const errors = await fixture(page);
  await add(page, 'Alex');
  await expect(page.locator('.vp-phrases li')).toHaveCount(6);
  await expect(page.getByRole('dialog')).toContainText('12–20 seconds of speech');
  await button(page, 'Cat').click();
  await expect(button(page, 'Save')).toBeDisabled();
  await recording(page);
  expect(await page.evaluate(() => profileFixture.store.list())).toEqual([]);
  await page.getByLabel('Name', { exact: true }).fill('a'.repeat(25));
  await expect(button(page, 'Save')).toBeDisabled();
  await expect(page.getByLabel('Name', { exact: true })).toHaveAttribute('aria-invalid', 'true');
  await page.getByLabel('Name', { exact: true }).fill('Alex 🐥');
  await button(page, 'Save').click();
  await expect(page.getByRole('heading', { name: 'Users 1/10' })).toBeVisible();
  const saved = await page.evaluate(() => ({ profiles: profileFixture.store.list(), metadata: profileFixture.ui.metadataSnapshot(),
    changes: profileFixture.observed.changes.length, raw: localStorage.getItem('voice-pop-voice-profiles-v1') }));
  expect(saved.profiles[0]).toMatchObject({ name: 'Alex 🐥', emoji: '🐱' });
  expect(saved.profiles[0].embedding).toHaveLength(256);
  expect(saved.profiles[0].templates).toHaveLength(3);
  expect(saved.profiles[0].templates[0]).not.toEqual(saved.profiles[0].templates[1]);
  expect(saved.metadata[0].embedding).toBeUndefined();
  expect(saved.metadata[0].avatar_png).toMatch(/^data:image\/png;base64,/);
  expect(saved.raw).not.toMatch(/audio|pcm|recording/i);
  expect(saved.changes).toBe(1);
  const dimensions = await page.evaluate(async () => {
    const image = new Image(); image.src = profileFixture.ui.metadataSnapshot()[0].avatar_png; await image.decode();
    return [image.width, image.height];
  });
  expect(dimensions).toEqual([128, 128]);
  await expect(page.getByText('Changes apply to the next round.')).toBeVisible();
  expect(errors).toEqual([]);
});

test('transient voice vectors survive duplicate completion then are erased on cancel or successful Save without erasing stored copies', async ({ page }) => {
  const errors = await fixture(page);
  await add(page, 'Renée');
  await recording(page);
  const duplicate = await page.evaluate(() => {
    window.voiceVectors = result => [result.embedding, ...result.templates, ...result.segments.map(segment => segment.embedding)];
    window.canceledVoiceResult = profileFixture.ui.result;
    const expected = JSON.stringify(canceledVoiceResult);
    // finishEnrollment already resolves the same object sent to onComplete.
    // Delivering it once more must also leave the pending Save intact.
    profileFixture.host.current.onComplete(canceledVoiceResult);
    const late = profileFixture.host.result();
    profileFixture.host.current.onComplete(late);
    return { retained: profileFixture.ui.result === canceledVoiceResult,
      intact: JSON.stringify(canceledVoiceResult) === expected,
      lateErased: voiceVectors(late).every(vector => vector.every(value => value === 0)),
      nonzero: voiceVectors(canceledVoiceResult).every(vector => vector.some(value => value !== 0)) };
  });
  expect(duplicate).toEqual({ retained: true, intact: true, lateErased: true, nonzero: true });
  await expect(button(page, 'Save')).toBeEnabled();
  await button(page, 'Cancel').click();
  expect(await page.evaluate(() => voiceVectors(canceledVoiceResult).every(vector => vector.every(value => value === 0)))).toBe(true);
  expect(await page.evaluate(() => profileFixture.observed.profileWrites)).toBe(0);
  await add(page, 'Renée');
  await recording(page);
  const expected = await page.evaluate(() => {
    window.savedVoiceResult = profileFixture.ui.result;
    return { embedding: savedVoiceResult.embedding, templates: savedVoiceResult.templates };
  });
  await button(page, 'Save').click();
  const saved = await page.evaluate(() => ({ profile: profileFixture.store.list()[0],
    erased: voiceVectors(savedVoiceResult).every(vector => vector.every(value => value === 0)),
    writes: profileFixture.observed.profileWrites, draft: profileFixture.ui.result }));
  expect(saved.erased).toBe(true);
  expect(saved.draft).toBeNull();
  expect(saved.writes).toBe(1);
  expect(saved.profile.embedding).toEqual(expected.embedding);
  expect(saved.profile.templates).toHaveLength(expected.templates.length);
  saved.profile.templates.forEach((template, index) => template.forEach((value, dimension) =>
    expect(value).toBeCloseTo(expected.templates[index][dimension], 12)));
  expect(saved.profile.embedding.some(value => value !== 0)).toBe(true);
  expect(errors).toEqual([]);
});

test('retry and close erase transient samples and a late completion cannot retain another recording', async ({ page }) => {
  const errors = await fixture(page);
  await add(page);
  await recording(page);
  await page.evaluate(() => {
    window.voiceVectors = result => [result.embedding, ...result.templates, ...result.segments.map(segment => segment.embedding)];
    window.retriedVoiceResult = profileFixture.ui.result;
    window.previousVoiceCallbacks = profileFixture.host.current;
  });
  await button(page, 'Retry recording').click();
  expect(await page.evaluate(() => voiceVectors(retriedVoiceResult).every(vector => vector.every(value => value === 0)))).toBe(true);
  expect(await page.evaluate(() => {
    const late = profileFixture.host.result();
    previousVoiceCallbacks.onComplete(late);
    return voiceVectors(late).every(vector => vector.every(value => value === 0));
  })).toBe(true);
  await expect(page.locator('.vp-record-status')).toContainText('Recording');
  await page.evaluate(() => profileFixture.host.progress());
  await button(page, 'Stop').click();
  await page.evaluate(() => { window.closedVoiceResult = profileFixture.ui.result; });
  await button(page, 'Close users').click();
  await expect(page.getByRole('dialog')).toBeHidden();
  expect(await page.evaluate(() => voiceVectors(closedVoiceResult).every(vector => vector.every(value => value === 0)))).toBe(true);
  expect(await page.evaluate(() => {
    const late = profileFixture.host.result();
    profileFixture.host.current.onComplete(late);
    return voiceVectors(late).every(vector => vector.every(value => value === 0));
  })).toBe(true);
  expect(await page.evaluate(() => profileFixture.observed.profileWrites)).toBe(0);
  expect(await page.evaluate(() => profileFixture.ui.result)).toBeNull();
  expect(errors).toEqual([]);
});

test('saved names and emoji remain editable without a ready model, and old voices request re-recording', async ({ page }) => {
  const errors = await fixture(page, { count: 1, status: 'unsupported', oldModel: true });
  await expect(page.getByText('Re-record needed')).toBeVisible();
  await button(page, 'Edit Player 1').click();
  await expect(page.locator('.vp-record-status')).toContainText('older model');
  const original = await page.evaluate(() => profileFixture.store.list()[0]);
  await page.getByLabel('Name', { exact: true }).fill('Sam');
  await button(page, 'Fox').click();
  await button(page, 'Save').click();
  const updated = await page.evaluate(() => profileFixture.store.list()[0]);
  expect(updated).toMatchObject({ name: 'Sam', emoji: '🦊', modelVersion: original.modelVersion, embedding: original.embedding });
  await button(page, 'Edit Sam').click();
  await button(page, 'Re-record voice').click();
  await expect(button(page, 'Record voice')).toBeDisabled();
  await expect(button(page, 'Save')).toBeDisabled();
  await button(page, 'Close users').click();
  await expect(page.getByRole('dialog')).toBeHidden();
  expect(await page.evaluate(() => profileFixture.host.starts)).toBe(0);
  expect(errors).toEqual([]);
});

test('adding voice samples preserves a legacy voice until one explicit Save updates voice and metadata together', async ({ page }) => {
  const errors = await fixture(page, { count: 1 });
  const original = await page.evaluate(key => localStorage.getItem(key), KEY);
  await expect(button(page, 'Identify user')).toBeEnabled();
  await expect(page.getByText('Add samples for a stronger voice match')).toBeVisible();
  await button(page, 'Edit Player 1').click();
  await expect(page.locator('.vp-record-status')).toContainText('Your saved voice still works');
  await page.getByLabel('Name', { exact: true }).fill('Renée');
  await button(page, 'Fox').click();
  await button(page, 'Add voice samples').click();
  await expect(page.getByRole('dialog')).toContainText('Your saved voice stays unchanged until you choose Save');
  await expect(button(page, 'Save')).toBeDisabled();
  await recording(page);
  expect(await page.evaluate(key => localStorage.getItem(key), KEY)).toBe(original);
  expect(await page.evaluate(() => profileFixture.observed.profileWrites)).toBe(0);
  await page.evaluate(() => {
    const addVoice = profileFixture.store.addVoice.bind(profileFixture.store);
    profileFixture.observed.appends = [];
    profileFixture.store.addVoice = (id, sample) => {
      profileFixture.observed.appends.push({ id, name: sample.name, emoji: sample.emoji, templates: sample.templates.length });
      return addVoice(id, sample);
    };
  });
  await button(page, 'Save').click();
  await expect(button(page, 'Edit Renée')).toBeVisible();
  const saved = await page.evaluate(() => ({ profile: profileFixture.store.list()[0], observed: profileFixture.observed }));
  expect(saved.profile).toMatchObject({ id: 'saved-0', name: 'Renée', emoji: '🦊' });
  expect(saved.profile.templates).toHaveLength(4);
  expect(saved.profile.templates[0]).toEqual(JSON.parse(original).profiles[0].embedding);
  expect(saved.observed.appends).toEqual([{ id: 'saved-0', name: 'Renée', emoji: '🦊', templates: 3 }]);
  expect(saved.observed.profileWrites).toBe(1);
  expect(saved.observed.changes).toHaveLength(1);
  await expect(page.getByText('Add samples for a stronger voice match')).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('canceling extra samples or failing their recording preserves the saved voice and draft metadata never leaks', async ({ page }) => {
  const errors = await fixture(page, { count: 1, templateCount: 3 });
  const original = await page.evaluate(key => localStorage.getItem(key), KEY);
  await button(page, 'Edit Player 1').click();
  await page.getByLabel('Name', { exact: true }).fill('Unsaved Renée');
  await button(page, 'Add voice samples').click();
  await page.evaluate(() => { profileFixture.host.nextFinishError = 'Please record more clear speech.'; });
  await button(page, 'Record voice').click();
  await button(page, 'Stop').click();
  await expect(page.getByRole('alert')).toContainText('more clear speech');
  await expect(button(page, 'Save')).toBeDisabled();
  expect(await page.evaluate(key => localStorage.getItem(key), KEY)).toBe(original);
  await button(page, 'Retry recording').click();
  await page.evaluate(() => profileFixture.host.progress());
  await button(page, 'Stop').click();
  await expect(button(page, 'Save')).toBeEnabled();
  await button(page, 'Cancel').click();
  await expect(button(page, 'Edit Player 1')).toBeVisible();
  expect(await page.evaluate(key => localStorage.getItem(key), KEY)).toBe(original);
  expect(await page.evaluate(() => profileFixture.observed.profileWrites)).toBe(0);
  expect(await page.evaluate(() => profileFixture.observed.changes)).toEqual([]);
  expect(errors).toEqual([]);
});

for (const failure of ['voice mismatch', 'storage failure']) {
  test(`an extra-sample ${failure} preserves all saved fields and allows explicit Save after retry`, async ({ page }) => {
    const errors = await fixture(page, { count: 1, templateCount: 3 });
    const original = await page.evaluate(key => localStorage.getItem(key), KEY);
    await button(page, 'Edit Player 1').click();
    await page.getByLabel('Name', { exact: true }).fill('Renée');
    await button(page, 'Fox').click();
    await button(page, 'Add voice samples').click();
    if (failure === 'voice mismatch') await page.evaluate(() => {
      window.restoreSampleResult = profileFixture.host.result.bind(profileFixture.host);
      profileFixture.host.result = () => {
        const result = restoreSampleResult();
        const different = Array(256).fill(0); different[8] = 1;
        result.embedding = different.slice(); result.templates = [different.slice(), different.slice(), different.slice()];
        return result;
      };
    });
    await recording(page);
    if (failure === 'storage failure') await page.evaluate(() => {
      const write = Storage.prototype.setItem;
      Storage.prototype.setItem = function (key, value) {
        if (key === 'voice-pop-voice-profiles-v1') throw new DOMException('Storage full', 'QuotaExceededError');
        return write.call(this, key, value);
      };
      window.restoreSampleStorage = () => { Storage.prototype.setItem = write; };
    });
    await button(page, 'Save').click();
    await expect(page.getByRole('alert')).toContainText(failure === 'voice mismatch' ? 'does not match' : 'could not be saved');
    await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Renée');
    expect(await page.evaluate(key => localStorage.getItem(key), KEY)).toBe(original);
    expect(await page.evaluate(() => profileFixture.observed.profileWrites)).toBe(0);
    expect(await page.evaluate(() => profileFixture.observed.changes)).toEqual([]);
    if (failure === 'voice mismatch') {
      await page.evaluate(() => { profileFixture.host.result = restoreSampleResult; });
      await button(page, 'Retry recording').click();
      await page.evaluate(() => profileFixture.host.progress());
      await button(page, 'Stop').click();
    } else await page.evaluate(() => restoreSampleStorage());
    await button(page, 'Save').click();
    const saved = await page.evaluate(() => ({ profile: profileFixture.store.list()[0], writes: profileFixture.observed.profileWrites }));
    expect(saved.profile).toMatchObject({ id: 'saved-0', name: 'Renée', emoji: '🦊' });
    expect(saved.profile.templates).toHaveLength(6);
    expect(saved.writes).toBe(1);
    expect(errors).toEqual([]);
  });
}

test('re-recording replaces saved voice samples while adding samples is a separate choice', async ({ page }) => {
  const errors = await fixture(page, { count: 1, templateCount: 5 });
  await button(page, 'Edit Player 1').click();
  await expect(button(page, 'Add voice samples')).toBeVisible();
  await button(page, 'Re-record voice').click();
  await recording(page);
  expect(await page.evaluate(() => profileFixture.store.list()[0].templates.length)).toBe(5);
  await button(page, 'Save').click();
  expect(await page.evaluate(() => profileFixture.store.list()[0].templates.length)).toBe(3);
  expect(await page.evaluate(() => profileFixture.observed.profileWrites)).toBe(1);
  expect(errors).toEqual([]);
});

test('recording progress uses effective speech and the requested sample count while preserving quality feedback', async ({ page }) => {
  const errors = await fixture(page);
  await add(page);
  await button(page, 'Record voice').click();
  await page.evaluate(() => profileFixture.host.current.onProgress({ segments: 2, requiredSegments: 4,
    voicedMs: 6000, requiredVoicedMs: 12000, progress: 0.5, canFinish: false, message: 'Speak a little closer to the microphone.' }));
  await expect(page.locator('.vp-timing')).toContainText('2/4 voice samples');
  await expect(page.locator('.vp-timing')).toContainText('6.0 / 12 s effective speech');
  await expect(page.locator('.vp-record-status')).toContainText('closer to the microphone');
  await expect(page.locator('.vp-timing')).toContainText('Keep going');
  await page.evaluate(() => profileFixture.host.current.onProgress({ segments: 4, requiredSegments: 4,
    voicedMs: 12000, requiredVoicedMs: 12000, progress: 1, canFinish: true }));
  await expect(page.locator('.vp-timing')).toContainText('4/4 voice samples');
  await expect(page.locator('.vp-timing')).toContainText('Ready to stop');
  await expect(button(page, 'Save')).toBeDisabled();
  expect(await page.evaluate(() => profileFixture.observed.profileWrites)).toBe(0);
  await button(page, 'Cancel').click();
  expect(errors).toEqual([]);
});

test('permission and quality errors keep drafts unsaved and allow another recording', async ({ page }) => {
  const errors = await fixture(page);
  await add(page, 'Mia');
  await page.evaluate(() => { profileFixture.host.nextStartError = 'Microphone permission was denied.'; });
  await button(page, 'Record voice').click();
  await expect(page.getByRole('alert')).toContainText('permission was denied');
  await expect(button(page, 'Save')).toBeDisabled();
  await page.evaluate(() => { profileFixture.host.nextFinishError = 'Please read three phrases with a little more speech.'; });
  await button(page, 'Retry recording').click();
  await button(page, 'Stop').click();
  await expect(page.getByRole('alert')).toContainText('three phrases');
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Mia');
  expect(await page.evaluate(() => profileFixture.store.list())).toEqual([]);
  await button(page, 'Retry recording').click();
  await page.evaluate(() => profileFixture.host.progress());
  await button(page, 'Stop').click();
  await expect(button(page, 'Save')).toBeEnabled();
  await button(page, 'Save').click();
  expect(await page.evaluate(() => profileFixture.observed.changes.length)).toBe(1);
  expect(errors).toEqual([]);
});

test('Escape, page backgrounding and late enrollment callbacks cannot leak recording or save a draft', async ({ page }) => {
  const errors = await fixture(page);
  await add(page);
  await page.evaluate(() => { profileFixture.host.permissionPending = true; });
  await button(page, 'Record voice').click();
  await expect(page.locator('.vp-record-status')).toContainText('microphone permission');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toBeHidden();
  await expect(page.locator('#users')).toBeFocused();
  await page.evaluate(() => {
    const stale = profileFixture.host.current;
    stale.onStarted(); stale.onProgress({ segments: 3, voicedMs: 13200 }); stale.onComplete(profileFixture.host.result());
  });
  expect(await page.evaluate(() => profileFixture.store.list())).toEqual([]);
  await page.locator('#users').click();
  await add(page);
  await page.evaluate(() => { profileFixture.host.permissionPending = false; });
  await button(page, 'Record voice').click();
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(page.locator('.vp-record-status')).toContainText('background');
  await expect(button(page, 'Save')).toBeDisabled();
  expect(await page.evaluate(() => profileFixture.host.stops)).toBe(2);
  await button(page, 'Close users').click();
  expect(await page.evaluate(() => profileFixture.observed.closes)).toBe(2);
  expect(errors).toEqual([]);
});

test('a failed microphone release keeps the modal and warning visible until stopping succeeds', async ({ page }) => {
  const errors = await fixture(page);
  await add(page);
  await button(page, 'Record voice').click();
  await page.evaluate(() => { profileFixture.host.blockedStop = true; });
  await button(page, 'Close users').click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await expect(page.getByRole('alert')).toContainText('microphone could not be stopped');
  await expect(button(page, 'Save')).toBeDisabled();
  expect(await page.evaluate(() => profileFixture.observed.closes)).toBe(0);
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.evaluate(() => { profileFixture.host.blockedStop = false; });
  await button(page, 'Retry stopping microphone').click();
  await expect(page.getByRole('alert')).toBeHidden();
  await button(page, 'Close users').click();
  await expect(page.getByRole('dialog')).toBeHidden();
  expect(await page.evaluate(() => profileFixture.store.list())).toEqual([]);
  expect(errors).toEqual([]);
});

test('ten-user capacity and deletion confirmation preserve users until the final choice', async ({ page }) => {
  const errors = await fixture(page, { count: 10 });
  await expect(page.getByRole('heading', { name: 'Users 10/10' })).toBeVisible();
  await expect(button(page, 'Add user')).toBeDisabled();
  await button(page, 'Edit Player 1').click();
  await button(page, 'Delete user').click();
  await expect(page.getByRole('group', { name: 'Confirm deletion' })).toBeVisible();
  expect(await page.evaluate(() => profileFixture.store.list().length)).toBe(10);
  await button(page, 'Keep user').click();
  await expect(page.getByRole('group', { name: 'Confirm deletion' })).toBeHidden();
  await button(page, 'Delete user').click();
  await button(page, 'Delete permanently').click();
  await expect(page.getByRole('heading', { name: 'Users 9/10' })).toBeVisible();
  await expect(button(page, 'Add user')).toBeEnabled();
  expect(await page.evaluate(() => profileFixture.store.list().some(profile => profile.id === 'saved-0'))).toBe(false);
  expect(await page.evaluate(() => profileFixture.observed.changes.length)).toBe(1);
  expect(errors).toEqual([]);
});

test('mobile editing traps focus, keeps emoji targets usable and blocks game input without blocking text', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 568 });
  const errors = await fixture(page);
  await add(page, 'Alex Renée');
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Alex Renée');
  await expect(page.locator('#background')).toHaveJSProperty('inert', true);
  const dimensions = await page.locator('.vp-emoji').evaluateAll(buttons => buttons.map(button => {
    const rect = button.getBoundingClientRect(); return [rect.width, rect.height];
  }));
  for (const [width, height] of dimensions) { expect(width).toBeGreaterThanOrEqual(44); expect(height).toBeGreaterThanOrEqual(44); }
  await button(page, 'Rocket').click();
  await expect(button(page, 'Rocket')).toHaveAttribute('aria-pressed', 'true');
  await button(page, 'Close users').focus();
  await page.keyboard.press('Shift+Tab');
  await expect(button(page, 'Cancel')).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(button(page, 'Close users')).toBeFocused();
  const observed = await page.evaluate(() => profileFixture.observed);
  expect(observed.gameKeys).toBe(0);
  expect(observed.gameClicks).toBe(0);
  const dialog = await page.getByRole('dialog').boundingBox();
  expect(dialog.x).toBeGreaterThanOrEqual(0);
  expect(dialog.x + dialog.width).toBeLessThanOrEqual(320);
  expect(dialog.y).toBeGreaterThanOrEqual(0);
  expect(dialog.y + dialog.height).toBeLessThanOrEqual(568);
  await page.screenshot({ path: testInfo.outputPath('voice-profile-editor-320.png'), scale: 'css' });
  await page.keyboard.press('Escape');
  await expect(page.locator('#background')).toHaveJSProperty('inert', false);
  await expect(page.locator('#users')).toBeFocused();
  expect(errors).toEqual([]);
});

test('unreadable profile storage is retained, retryable and never prevents closing', async ({ page }) => {
  const errors = await fixture(page, { corrupt: true });
  await expect(page.getByRole('alert')).toContainText('kept unchanged');
  await expect(button(page, 'Add user')).toHaveCount(0);
  await button(page, 'Retry loading users').click();
  expect(await page.evaluate(key => localStorage.getItem(key), KEY)).toBe('{unreadable-save');
  await button(page, 'Close users').click();
  await expect(page.getByRole('dialog')).toBeHidden();
  expect(errors).toEqual([]);
});

test('a failed Save preserves the completed draft and fresh metadata does not reuse stale names', async ({ page }) => {
  const errors = await fixture(page);
  await add(page, 'Alex');
  await recording(page);
  await page.evaluate(() => {
    const original = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (key === 'voice-pop-voice-profiles-v1') throw new DOMException('Storage full', 'QuotaExceededError');
      return original.call(this, key, value);
    };
    window.restoreProfileStorage = () => { Storage.prototype.setItem = original; };
  });
  await button(page, 'Save').click();
  await expect(page.getByRole('alert')).toContainText('could not be saved');
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Alex');
  await expect(button(page, 'Save')).toBeEnabled();
  expect(await page.evaluate(() => profileFixture.observed.changes.length)).toBe(0);
  expect(await page.evaluate(() => profileFixture.store.list())).toEqual([]);
  await page.evaluate(() => window.restoreProfileStorage());
  await button(page, 'Save').click();
  const metadata = await page.evaluate(() => {
    const saved = profileFixture.store.list()[0];
    profileFixture.store.update(saved.id, { name: 'Fresh name', emoji: '🚀' });
    return profileFixture.ui.metadataSnapshot(profileFixture.store.list());
  });
  expect(metadata[0]).toMatchObject({ name: 'Fresh name', emoji: '🚀' });
  expect(metadata[0].embedding).toBeUndefined();
  expect(await page.evaluate(() => profileFixture.observed.changes.length)).toBe(1);
  expect(errors).toEqual([]);
});

test('a late microphone release failure can be retried without an active enrollment or model reload', async ({ page }) => {
  const errors = await fixture(page);
  await page.evaluate(() => {
    profileFixture.host.blockedStop = true;
    profileFixture.host.setState({ status: 'ready', microphoneBlocked: true,
      microphoneMessage: 'The previous microphone could not be stopped. Please retry stopping it.' });
  });
  await expect(page.getByRole('alert')).toContainText('previous microphone');
  await button(page, 'Close users').click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.evaluate(() => { profileFixture.host.blockedStop = false; });
  await button(page, 'Retry stopping microphone').click();
  await expect(page.getByRole('alert')).toBeHidden();
  await button(page, 'Close users').click();
  await expect(page.getByRole('dialog')).toBeHidden();
  expect(await page.evaluate(() => profileFixture.host.starts)).toBe(0);
  expect(await page.evaluate(() => profileFixture.host.prepares)).toBe(0);
  expect(await page.evaluate(() => profileFixture.observed.closes)).toBe(1);
  expect(errors).toEqual([]);
});

async function unchangedIdentificationProfiles(page, original) {
  expect(await page.evaluate(key => localStorage.getItem(key), KEY)).toBe(original);
  expect(await page.evaluate(() => profileFixture.observed.profileWrites)).toBe(0);
  expect(await page.evaluate(() => profileFixture.observed.changes)).toEqual([]);
  expect(await page.evaluate(() => profileFixture.host.starts)).toBe(0);
}

for (const library of [{ name: 'empty', count: 0 }, { name: 'older-model', count: 1, oldModel: true }]) {
  test(`identification stays unavailable for an ${library.name} voice library`, async ({ page }) => {
    const errors = await fixture(page, library);
    const original = await page.evaluate(key => localStorage.getItem(key), KEY);
    await expect(button(page, 'Identify user')).toBeVisible();
    await expect(button(page, 'Identify user')).toBeDisabled();
    await expect(page.locator('.vp-identify-help')).toContainText(library.count ? 'Re-record' : 'Add a user');
    await expect(button(page, 'Add user')).toBeEnabled();
    expect(await page.evaluate(() => profileFixture.host.identificationStarts)).toBe(0);
    await unchangedIdentificationProfiles(page, original);
    expect(errors).toEqual([]);
  });
}

test('identification waits for model readiness, uses current voices and shows the matched avatar without saving', async ({ page }, testInfo) => {
  const errors = await fixture(page, { count: 2, oldModel: true, status: 'idle' });
  const original = await page.evaluate(key => localStorage.getItem(key), KEY);
  await expect(button(page, 'Identify user')).toBeDisabled();
  await page.evaluate(() => profileFixture.host.setState({ status: 'downloading', loaded: 1000, total: 1000 }));
  await expect(page.locator('.vp-model')).toContainText('100%');
  await expect(button(page, 'Identify user')).toBeDisabled();
  await page.evaluate(() => profileFixture.host.setState({ status: 'initializing', loaded: 1000, total: 1000 }));
  await expect(button(page, 'Identify user')).toBeDisabled();
  await page.evaluate(() => profileFixture.host.setState({ status: 'error', message: 'Model initialization failed.' }));
  await expect(button(page, 'Identify user')).toBeDisabled();
  await button(page, 'Retry').click();
  await page.evaluate(() => profileFixture.host.setState({ status: 'ready' }));
  await expect(button(page, 'Identify user')).toBeEnabled();
  expect(await page.evaluate(() => profileFixture.host.identificationStarts)).toBe(0);
  await page.screenshot({ path: testInfo.outputPath('voice-identify-users-list.png'), scale: 'css' });

  await button(page, 'Identify user').click();
  await expect(page.getByRole('heading', { name: 'Identify user', exact: true })).toBeVisible();
  await expect(page.locator('.vp-record-status')).toHaveText('Listening…');
  await expect(page.getByRole('dialog')).toContainText('Read both sentences in your normal voice');
  await expect(page.locator('.vp-identify-phrase li')).toHaveCount(2);
  await expect(page.getByRole('dialog')).toContainText('4–6 seconds of speech');
  await expect(button(page, 'Cancel')).toBeVisible();
  await expect(button(page, 'Try again')).toBeHidden();
  const capture = await page.evaluate(() => ({ starts: profileFixture.host.identificationStarts,
    sessionId: profileFixture.host.identification.sessionId,
    profiles: profileFixture.host.identification.profiles.map(({ id, modelVersion }) => ({ id, modelVersion })),
    version: SPEAKER_MODEL_VERSION }));
  expect(capture.starts).toBe(1);
  expect(capture.sessionId).toEqual(expect.any(String));
  expect(capture.sessionId.length).toBeGreaterThan(0);
  expect(capture.profiles).toEqual([{ id: 'saved-1', modelVersion: capture.version }]);
  await page.evaluate(() => profileFixture.host.identificationProgress());
  await expect(page.getByRole('progressbar', { name: 'Voice sample progress' })).toHaveJSProperty('value', 0.5);
  await expect(page.locator('.vp-timing')).toContainText('1/2 voice samples');
  await expect(page.locator('.vp-timing')).toContainText('2.0 / 4 s effective speech');
  await page.evaluate(() => profileFixture.host.completeIdentification());
  await expect(page.locator('.vp-record-status')).toHaveText('User identified');
  await expect(page.getByRole('heading', { name: 'Player 2', exact: true })).toBeVisible();
  await expect(page.locator('.vp-identify-avatar')).toHaveText('🐱');
  await expect(page.getByRole('progressbar', { name: 'Voice sample progress' })).toBeHidden();
  await expect(button(page, 'Try again')).toBeEnabled();
  await expect(button(page, 'Back to users')).toBeVisible();
  await expect(button(page, 'Save')).toHaveCount(0);
  await expect(page.getByLabel('Name', { exact: true })).toHaveCount(0);
  expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(false);
  await page.screenshot({ path: testInfo.outputPath('voice-identify-matched-avatar.png'), scale: 'css' });
  await unchangedIdentificationProfiles(page, original);
  await button(page, 'Back to users').click();
  await expect(page.getByRole('heading', { name: 'Users 2/10' })).toBeVisible();
  await expect(button(page, 'Identify user')).toBeFocused();
  await unchangedIdentificationProfiles(page, original);
  expect(errors).toEqual([]);
});

test('no-match identification can retry and stale results cannot replace the current or completed match', async ({ page }) => {
  const errors = await fixture(page, { count: 2 });
  const original = await page.evaluate(key => localStorage.getItem(key), KEY);
  await button(page, 'Identify user').click();
  const firstSession = await page.evaluate(() => {
    window.staleIdentification = profileFixture.host.identification;
    profileFixture.host.completeIdentification(-1);
    return staleIdentification.sessionId;
  });
  await expect(page.locator('.vp-record-status')).toHaveText('No match found');
  await expect(page.getByRole('heading', { name: /Player [12]/ })).toHaveCount(0);
  await expect(button(page, 'Try again')).toBeEnabled();
  await button(page, 'Try again').click();
  const secondSession = await page.evaluate(() => profileFixture.host.identification.sessionId);
  expect(secondSession).not.toBe(firstSession);
  await page.evaluate(() => {
    staleIdentification.onStarted();
    staleIdentification.onProgress({ progress: 1, segments: 2, requiredSegments: 2, voicedMs: 9999, requiredVoicedMs: 4000, message: 'Stale voice' });
    staleIdentification.onComplete({ profile: { id: 'saved-0', name: 'Player 1', emoji: '🐱' }, quality: {} });
    staleIdentification.onError(new Error('Stale microphone error'));
  });
  await expect(page.locator('.vp-record-status')).toHaveText('Listening…');
  await expect(page.getByRole('alert')).toBeHidden();
  await expect(page.getByRole('progressbar', { name: 'Voice sample progress' })).toHaveJSProperty('value', 0);
  await page.evaluate(() => profileFixture.host.completeIdentification(1));
  await expect(page.getByRole('heading', { name: 'Player 2', exact: true })).toBeVisible();
  await page.evaluate(() => {
    // Duplicate completion from this same capture is stale once it has released.
    profileFixture.host.identification.onComplete({ profile: null, quality: {} });
    profileFixture.host.identification.onError(new Error('Late completion error'));
  });
  await expect(page.locator('.vp-record-status')).toHaveText('User identified');
  await expect(page.getByRole('heading', { name: 'Player 2', exact: true })).toBeVisible();
  await expect(page.getByRole('alert')).toBeHidden();
  expect(await page.evaluate(() => profileFixture.host.identificationStarts)).toBe(2);
  await unchangedIdentificationProfiles(page, original);
  expect(errors).toEqual([]);
});

for (const [reason, guidance] of [
  ['unknown_voice', 'does not clearly match a saved user'],
  ['ambiguous_voice', 'close to more than one saved user'],
  ['segment_disagreement', 'did not match the same saved user'],
  ['insufficient_consensus', 'two clear samples of the same voice']
]) {
  test(`identification explains ${reason} without naming or saving a guessed user`, async ({ page }) => {
    const errors = await fixture(page, { count: 2, templateCount: 3 });
    const original = await page.evaluate(key => localStorage.getItem(key), KEY);
    await button(page, 'Identify user').click();
    await page.evaluate(reason => {
      profileFixture.host.identificationActive = false;
      profileFixture.host.identification.onComplete({ profile: null, quality: { segments: 2, voicedMs: 4400, reason } });
    }, reason);
    await expect(page.locator('.vp-record-status')).toHaveText('No match found');
    await expect(page.getByRole('dialog')).toContainText(guidance);
    await expect(page.getByRole('heading', { name: /Player [12]/ })).toHaveCount(0);
    await expect(button(page, 'Try again')).toBeEnabled();
    expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(false);
    await unchangedIdentificationProfiles(page, original);
    expect(errors).toEqual([]);
  });
}

test('identification permission and speech-quality errors release capture and allow a fresh retry', async ({ page }) => {
  const errors = await fixture(page, { count: 1 });
  const original = await page.evaluate(key => localStorage.getItem(key), KEY);
  await page.evaluate(() => { profileFixture.host.nextIdentificationError = 'Microphone permission was denied.'; });
  await button(page, 'Identify user').click();
  await expect(page.getByRole('alert')).toContainText('permission was denied');
  await expect(button(page, 'Back to users')).toBeVisible();
  expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(false);
  await button(page, 'Try again').click();
  await expect(page.getByRole('alert')).toBeHidden();
  await expect(page.locator('.vp-record-status')).toHaveText('Listening…');
  await page.evaluate(() => profileFixture.host.identification.onError(new Error('Please speak a little longer.')));
  await expect(page.getByRole('alert')).toContainText('speak a little longer');
  expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(false);
  await expect(button(page, 'Try again')).toBeEnabled();
  await button(page, 'Try again').click();
  await page.evaluate(() => profileFixture.host.completeIdentification());
  await expect(page.locator('.vp-record-status')).toHaveText('User identified');
  await expect(page.getByRole('alert')).toBeHidden();
  expect(await page.evaluate(() => profileFixture.host.identificationStarts)).toBe(3);
  await unchangedIdentificationProfiles(page, original);
  expect(errors).toEqual([]);
});

for (const permissionPending of [true, false]) {
  test(`identification ${permissionPending ? 'awaiting permission' : 'already listening'} cancels safely and Escape restores game focus`, async ({ page }) => {
    const errors = await fixture(page, { count: 1 });
    const original = await page.evaluate(key => localStorage.getItem(key), KEY);
    await page.evaluate(pending => { profileFixture.host.permissionPending = pending; }, permissionPending);
    await button(page, 'Identify user').click();
    await expect(page.locator('.vp-record-status')).toContainText(permissionPending ? 'microphone permission' : 'Listening');
    await page.evaluate(() => { window.cancelledIdentification = profileFixture.host.identification; });
    await button(page, 'Cancel').click();
    await expect(page.getByRole('heading', { name: 'Users 1/10' })).toBeVisible();
    await expect(button(page, 'Identify user')).toBeFocused();
    expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(false);
    expect(await page.evaluate(() => profileFixture.host.identificationStops)).toBe(1);
    await page.evaluate(() => {
      cancelledIdentification.onStarted();
      cancelledIdentification.onProgress({ progress: 1, segments: 2, requiredSegments: 2, voicedMs: 4400, requiredVoicedMs: 4000 });
      cancelledIdentification.onComplete({ profile: { id: 'saved-0' }, quality: {} });
      cancelledIdentification.onError(new Error('Cancelled capture failed'));
      profileFixture.host.permissionPending = false;
    });
    await expect(page.getByRole('heading', { name: 'Users 1/10' })).toBeVisible();
    await expect(page.getByRole('alert')).toBeHidden();
    await button(page, 'Identify user').click();
    await expect(page.locator('.vp-record-status')).toHaveText('Listening…');
    await page.keyboard.press('Escape');
    await expect(page.getByRole('dialog')).toBeHidden();
    await expect(page.locator('#users')).toBeFocused();
    await expect(page.locator('#background')).toHaveJSProperty('inert', false);
    expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(false);
    expect(await page.evaluate(() => profileFixture.host.identificationStops)).toBe(2);
    await page.evaluate(() => profileFixture.host.identification.onComplete({ profile: { id: 'saved-0' }, quality: {} }));
    await expect(page.getByRole('dialog')).toBeHidden();
    await unchangedIdentificationProfiles(page, original);
    expect(errors).toEqual([]);
  });
}

test('backgrounding and pagehide stop identification and discard callbacks without automatically restarting', async ({ page }) => {
  const errors = await fixture(page, { count: 1 });
  const original = await page.evaluate(key => localStorage.getItem(key), KEY);
  await button(page, 'Identify user').click();
  await page.evaluate(() => {
    window.backgroundIdentification = profileFixture.host.identification;
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(page.getByRole('dialog')).toContainText('background');
  await expect(button(page, 'Back to users')).toBeVisible();
  expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(false);
  await page.evaluate(() => {
    backgroundIdentification.onStarted();
    backgroundIdentification.onComplete({ profile: { id: 'saved-0' }, quality: {} });
    Object.defineProperty(document, 'hidden', { configurable: true, value: false });
    document.dispatchEvent(new Event('visibilitychange'));
    window.dispatchEvent(new Event('pageshow'));
  });
  await expect(page.locator('.vp-record-status')).not.toContainText('User identified');
  await expect(button(page, 'Try again')).toBeEnabled();
  expect(await page.evaluate(() => profileFixture.host.identificationStarts)).toBe(1);
  await button(page, 'Try again').click();
  await expect(page.locator('.vp-record-status')).toHaveText('Listening…');
  await page.evaluate(() => window.dispatchEvent(new Event('pagehide')));
  await expect(page.getByRole('dialog')).toContainText('left this page');
  await expect(button(page, 'Back to users')).toBeVisible();
  expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(false);
  expect(await page.evaluate(() => profileFixture.host.identificationStops)).toBe(2);
  await unchangedIdentificationProfiles(page, original);
  expect(errors).toEqual([]);
});

test('identification cannot leave a blocked microphone behind and retries stopping before another capture', async ({ page }) => {
  const errors = await fixture(page, { count: 1 });
  const original = await page.evaluate(key => localStorage.getItem(key), KEY);
  await button(page, 'Identify user').click();
  await page.evaluate(() => { profileFixture.host.blockedStop = true; });
  await button(page, 'Close users').click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await expect(page.getByRole('alert')).toContainText('microphone could not be stopped');
  await expect(button(page, 'Retry stopping microphone')).toBeVisible();
  expect(await page.evaluate(() => profileFixture.observed.closes)).toBe(0);
  expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(true);
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toBeVisible();
  await button(page, 'Cancel').click();
  await expect(page.getByRole('heading', { name: 'Identify user', exact: true })).toBeVisible();
  await page.evaluate(() => {
    profileFixture.host.identification.onComplete({ profile: { id: 'saved-0' }, quality: {} });
    profileFixture.host.setState({ status: 'ready' });
  });
  await expect(page.getByRole('alert')).toContainText('microphone could not be stopped');
  await expect(page.locator('.vp-record-status')).not.toContainText('User identified');
  expect(await page.evaluate(() => profileFixture.host.identificationStarts)).toBe(1);
  await page.evaluate(() => { profileFixture.host.blockedStop = false; });
  await button(page, 'Retry stopping microphone').click();
  await expect(page.getByRole('alert')).toBeHidden();
  await expect(button(page, 'Try again')).toBeEnabled();
  expect(await page.evaluate(() => profileFixture.host.identificationActive)).toBe(false);
  await button(page, 'Try again').click();
  await expect(page.locator('.vp-record-status')).toHaveText('Listening…');
  expect(await page.evaluate(() => profileFixture.host.identificationStarts)).toBe(2);
  await button(page, 'Cancel').click();
  await expect(page.getByRole('heading', { name: 'Users 1/10' })).toBeVisible();
  await button(page, 'Close users').click();
  await expect(page.getByRole('dialog')).toBeHidden();
  await unchangedIdentificationProfiles(page, original);
  expect(errors).toEqual([]);
});
