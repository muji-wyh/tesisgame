/* Voice profiles stay in this browser. Raw microphone audio is never stored. */
(function (root) {
  'use strict';
  const SPEAKER_MODEL_VERSION = 'wespeaker-en-voxceleb-resnet34-lm:e9848563da86f263117134dfd7ad63c92355b37de492b55e325400c9d9c39012';
  const SCHEMA_VERSION = 1;
  const MAX_PROFILES = 10;
  const MAX_TEMPLATES = 8;
  const fail = (code, message) => Object.assign(new Error(message), { name: 'VoiceProfileError', code });
  const clone = value => JSON.parse(JSON.stringify(value));
  function embeddingVector(value) {
    if (!Array.isArray(value) || value.length !== 256 || !value.every(Number.isFinite))
      throw fail('invalid_profile', 'Record a valid voice sample before saving.');
    const norm = Math.hypot(...value);
    if (!Number.isFinite(norm) || norm < 1e-8) throw fail('invalid_profile', 'The voice sample is empty. Please record again.');
    return value.map(number => number / norm);
  }
  function templateVectors(value) {
    if (!Array.isArray(value) || !value.length || value.length > MAX_TEMPLATES)
      throw fail('invalid_profile', 'Record between 1 and 8 valid voice samples before saving.');
    return value.map(embeddingVector);
  }
  function templateScore(embedding, templates) {
    const scores = templates.map(template => embedding.reduce((sum, value, index) => sum + value * template[index], 0))
      .sort((a, b) => b - a);
    return (scores[0] + (scores[1] ?? scores[0])) / 2;
  }
  function profileValue(value, requireCurrent = false) {
    if (!value || typeof value !== 'object' || typeof value.id !== 'string' || !/^[a-zA-Z0-9_-]{1,64}$/.test(value.id))
      throw fail('invalid_profile', 'The voice profile ID is invalid.');
    const name = typeof value.name === 'string' ? value.name.trim() : '';
    const emoji = typeof value.emoji === 'string' ? value.emoji.trim() : '';
    if (!name || [...name].length > 24 || /[\u0000-\u001f\u007f]/.test(name))
      throw fail('invalid_profile', 'Choose a name with 1–24 characters.');
    if (!emoji || [...emoji].length > 16 || /[\u0000-\u001f\u007f]/.test(emoji))
      throw fail('invalid_profile', 'Choose an avatar before saving.');
    if (typeof value.modelVersion !== 'string' || !value.modelVersion || value.modelVersion.length > 160)
      throw fail('invalid_profile', 'The voice sample model version is missing.');
    if (requireCurrent && value.modelVersion !== SPEAKER_MODEL_VERSION)
      throw fail('model_mismatch', 'This voice sample uses an older model. Please record it again.');
    const profile = { id: value.id, name, emoji, embedding: embeddingVector(value.embedding), modelVersion: value.modelVersion };
    if (Object.prototype.hasOwnProperty.call(value, 'templates')) profile.templates = templateVectors(value.templates);
    return profile;
  }
  class VoiceProfileStore {
    constructor(options = {}) {
      this.env = options.env || root;
      this.key = options.key || 'voice-pop-voice-profiles-v1';
      this.providedStorage = Object.prototype.hasOwnProperty.call(options, 'storage');
      this.storage = options.storage;
    }
    getStorage() {
      try {
        const storage = this.providedStorage ? this.storage : this.env.localStorage;
        if (!storage || typeof storage.getItem !== 'function' || typeof storage.setItem !== 'function') throw new Error();
        return storage;
      } catch { throw fail('storage_unavailable', 'Voice profiles cannot be accessed in this browser.'); }
    }
    read() {
      const storage = this.getStorage();
      let raw;
      try { raw = storage.getItem(this.key); }
      catch { throw fail('storage_unavailable', 'Voice profiles could not be read. Please retry.'); }
      if (raw === null) return { storage, raw, data: { schemaVersion: SCHEMA_VERSION, revision: 0, profiles: [] } };
      try {
        const value = JSON.parse(raw);
        if (!value || value.schemaVersion !== SCHEMA_VERSION || !Number.isSafeInteger(value.revision) || value.revision < 0 ||
            !Array.isArray(value.profiles) || value.profiles.length > MAX_PROFILES) throw new Error();
        const profiles = value.profiles.map(profile => profileValue(profile));
        if (new Set(profiles.map(profile => profile.id)).size !== profiles.length) throw new Error();
        return { storage, raw, data: { schemaVersion: SCHEMA_VERSION, revision: value.revision, profiles } };
      } catch { throw fail('corrupt_store', 'Saved voice profiles could not be read. They have been kept unchanged.'); }
    }
    snapshot() {
      return { ...clone(this.read().data), modelVersion: SPEAKER_MODEL_VERSION };
    }
    list() { return this.snapshot().profiles; }
    write(current, profiles) {
      if (current.data.revision >= Number.MAX_SAFE_INTEGER) throw fail('corrupt_store', 'Voice profile history cannot be updated.');
      const text = JSON.stringify({ schemaVersion: SCHEMA_VERSION, revision: current.data.revision + 1, profiles });
      try {
        if (current.storage.getItem(this.key) !== current.raw) throw fail('conflict', 'Voice profiles changed in another tab. Please retry.');
        current.storage.setItem(this.key, text);
        if (current.storage.getItem(this.key) !== text) throw fail('storage_unavailable', 'Voice profiles could not be saved. Please retry.');
      } catch (error) {
        if (error.name === 'VoiceProfileError') throw error;
        throw fail('storage_unavailable', 'Voice profiles could not be saved. Please retry.');
      }
    }
    save(value) {
      const current = this.read();
      const id = value?.id || this.env.crypto?.randomUUID?.();
      if (!id) throw fail('invalid_profile', 'This browser could not create a voice profile ID.');
      const profile = profileValue({ ...value, id }, true);
      const profiles = current.data.profiles;
      const index = profiles.findIndex(item => item.id === id);
      if (index < 0 && profiles.length >= MAX_PROFILES) throw fail('full', 'You can save up to 10 voice profiles. Remove one before adding another.');
      if (index < 0) profiles.push(profile); else profiles[index] = profile;
      this.write(current, profiles);
      return clone(profile);
    }
    update(id, changes) {
      const current = this.read();
      const index = current.data.profiles.findIndex(profile => profile.id === id);
      if (index < 0) throw fail('not_found', 'This voice profile no longer exists.');
      const profile = profileValue({ ...current.data.profiles[index],
        ...(Object.prototype.hasOwnProperty.call(changes || {}, 'name') ? { name: changes.name } : {}),
        ...(Object.prototype.hasOwnProperty.call(changes || {}, 'emoji') ? { emoji: changes.emoji } : {}) });
      current.data.profiles[index] = profile;
      this.write(current, current.data.profiles);
      return clone(profile);
    }
    addVoice(id, value) {
      const current = this.read();
      const index = current.data.profiles.findIndex(profile => profile.id === id);
      if (index < 0) throw fail('not_found', 'This voice profile no longer exists.');
      const previous = current.data.profiles[index];
      if (previous.modelVersion !== SPEAKER_MODEL_VERSION || value?.modelVersion !== SPEAKER_MODEL_VERSION)
        throw fail('model_mismatch', 'This voice sample uses an older model. Please record it again.');
      const incoming = profileValue({ ...previous, ...value, id, embedding: value.embedding }, true);
      // An omitted templates field means this request contains only its new
      // embedding, rather than implicitly reusing the saved templates.
      const additions = Object.prototype.hasOwnProperty.call(value, 'templates')
        ? incoming.templates : [incoming.embedding];
      const references = previous.templates || [previous.embedding];
      const alternatives = current.data.profiles.filter(profile => profile.id !== id && profile.modelVersion === SPEAKER_MODEL_VERSION);
      if ([incoming.embedding, ...additions].some(template => {
        const similarity = templateScore(template, references);
        return similarity < 0.60 || alternatives.some(profile => {
          const other = templateScore(template, profile.templates || [profile.embedding]);
          return other >= 0.60 && other - similarity >= 0.08;
        });
      }))
        throw fail('voice_mismatch', 'This recording does not match the saved voice clearly enough. Please try again.');
      const merged = [...references, ...additions];
      // Keep the original reference voices while making room for recent ones.
      const anchors = Math.min(2, references.length);
      const templates = merged.length <= MAX_TEMPLATES ? merged
        : [...merged.slice(0, anchors), ...merged.slice(-(MAX_TEMPLATES - anchors))];
      const mean = new Array(256).fill(0);
      for (const template of templates) template.forEach((number, dimension) => { mean[dimension] += number / templates.length; });
      const profile = profileValue({ ...incoming, embedding: embeddingVector(mean), templates }, true);
      current.data.profiles[index] = profile;
      this.write(current, current.data.profiles);
      return clone(profile);
    }
    remove(id) {
      const current = this.read();
      const profiles = current.data.profiles.filter(profile => profile.id !== id);
      if (profiles.length === current.data.profiles.length) return false;
      this.write(current, profiles);
      return true;
    }
  }
  VoiceProfileStore.SPEAKER_MODEL_VERSION = SPEAKER_MODEL_VERSION;
  VoiceProfileStore.MAX_PROFILES = MAX_PROFILES;
  VoiceProfileStore.MAX_TEMPLATES = MAX_TEMPLATES;
  root.VoiceProfileStore = VoiceProfileStore;
  root.SPEAKER_MODEL_VERSION = SPEAKER_MODEL_VERSION;
  if (typeof module === 'object' && module.exports) module.exports = { VoiceProfileStore, SPEAKER_MODEL_VERSION, MAX_PROFILES, MAX_TEMPLATES, embeddingVector };
})(typeof window === 'object' ? window : globalThis);
