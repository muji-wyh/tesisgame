/* Local model preparation is independent of microphone and round lifecycles. */
(function (root) {
  'use strict';
  const SPEAKER_MODEL_VERSION = 'wespeaker-en-voxceleb-resnet34-lm:e9848563da86f263117134dfd7ad63c92355b37de492b55e325400c9d9c39012';
  const identificationError = (code, message) => Object.assign(new Error(message), { code });
  function validVoice(value) {
    if (!Array.isArray(value) || value.length !== 256 || !value.every(Number.isFinite)) return false;
    const norm = Math.hypot(...value);
    return Number.isFinite(norm) && norm >= 1e-8;
  }
  function normalizedVoice(value) {
    if (!validVoice(value)) return null;
    const norm = Math.hypot(...value);
    return value.map(number => number / norm);
  }
  function voiceTemplates(value, fallback) {
    if (value === undefined) return fallback ? [fallback.slice()] : null;
    if (!Array.isArray(value) || !value.length || value.length > 8) return null;
    const templates = value.map(normalizedVoice);
    if (templates.every(Boolean)) return templates;
    templates.forEach(template => template?.fill(0));
    return null;
  }
  function clearVoiceResult(value) {
    const clear = vector => { if (Array.isArray(vector) || ArrayBuffer.isView(vector) && typeof vector.fill === 'function') vector.fill(0); };
    clear(value?.embedding);
    if (Array.isArray(value?.templates)) value.templates.forEach(clear);
    if (Array.isArray(value?.segments)) value.segments.forEach(segment => clear(segment?.embedding));
  }
  function clearProfiles(profiles) { profiles.forEach(clearVoiceResult); }
  function identificationProfiles(values) {
    if (!Array.isArray(values) || values.length > 10) return [];
    const counts = new Map();
    for (const value of values) counts.set(value?.id, (counts.get(value?.id) || 0) + 1);
    return values.flatMap(value => {
      if (!value || value.modelVersion !== SPEAKER_MODEL_VERSION ||
          typeof value.id !== 'string' || !/^[a-zA-Z0-9_-]{1,64}$/.test(value.id) || counts.get(value.id) !== 1 ||
          typeof value.name !== 'string' || !value.name.trim() || [...value.name.trim()].length > 24 ||
          typeof value.emoji !== 'string' || !value.emoji.trim() || [...value.emoji.trim()].length > 16 ||
          /[\u0000-\u001f\u007f]/.test(value.name + value.emoji)) return [];
      const embedding = normalizedVoice(value.embedding);
      const templates = value.templates === undefined ? undefined : voiceTemplates(value.templates);
      if (!embedding || templates === null) { embedding?.fill(0); templates?.forEach(template => template.fill(0)); return []; }
      return [{ id: value.id, name: value.name.trim(), emoji: value.emoji.trim(),
        embedding, ...(templates ? { templates } : {}), modelVersion: SPEAKER_MODEL_VERSION }];
    });
  }
  function matchVoiceProfile(embedding, profiles) {
    const voice = normalizedVoice(embedding);
    if (!voice) throw identificationError('invalid_voice_sample', 'The voice sample was unclear. Please try again.');
    let best = null, similarity = -1, second = -1;
    for (const profile of profiles) {
      const scores = (profile.templates || [profile.embedding]).map(template =>
        Math.max(-1, Math.min(1, voice.reduce((sum, value, index) => sum + value * template[index], 0)))).sort((a, b) => b - a);
      const score = (scores[0] + (scores[1] ?? scores[0])) / 2;
      if (score > similarity) { second = similarity; similarity = score; best = profile; }
      else if (score > second) second = score;
    }
    voice.fill(0);
    const margin = similarity - second;
    return { profile: best && similarity >= 0.60 && margin >= 0.08
      ? { id: best.id, name: best.name, emoji: best.emoji } : null, similarity, margin };
  }
  function identifyVoice(result, profiles) {
    const aggregate = matchVoiceProfile(result.embedding, profiles);
    const output = reason => ({ profile: reason === 'matched' ? aggregate.profile : null,
      quality: { ...result.quality, similarity: aggregate.similarity, margin: aggregate.margin, reason } });
    if (!Array.isArray(result.segments) || result.segments.length < 2 || result.segments.length !== result.quality.segments ||
        result.segments.some(segment => !segment || !Number.isFinite(segment.voicedMs) || segment.voicedMs <= 0 || !validVoice(segment.embedding)) ||
        result.segments.reduce((sum, segment) => sum + segment.voicedMs, 0) + 1 < 4000)
      return output('insufficient_consensus');
    const matches = result.segments.map(segment => matchVoiceProfile(segment.embedding, profiles));
    const ids = new Set(matches.filter(match => match.profile).map(match => match.profile.id));
    if (ids.size > 1) return output('segment_disagreement');
    if (!aggregate.profile) return output(aggregate.similarity < 0.60 ? 'unknown_voice' : 'ambiguous_voice');
    if ([...ids].some(id => id !== aggregate.profile.id)) return output('segment_disagreement');
    if (matches.filter(match => match.profile?.id === aggregate.profile.id).length >= 2) return output('matched');
    return output(matches.some(match => match.similarity >= 0.60 && match.margin < 0.08)
      ? 'ambiguous_voice' : 'insufficient_consensus');
  }
  class VoicePopMultiplayer {
    constructor(options = {}) {
      this.env = options.env || root;
      this.baseUrl = options.baseUrl || this.env.document?.baseURI || 'http://localhost/';
      this.manifestUrl = new URL(options.manifestUrl || 'multiplayer/manifest.json', this.baseUrl).href;
      this.state = { status: 'idle', loaded: 0, total: 0, progress: 0, message: '', microphoneBlocked: false, microphoneMessage: '' };
      this.listeners = new Set();
      this.worker = null;
      this.preparation = null;
      this.session = null;
      this.capture = null;
      this.pendingCapture = null;
      this.generation = 0;
      this.waiters = new Map();
      this.requestId = 0;
    }
    observe(callback) {
      this.listeners.add(callback);
      callback({ ...this.state });
      return () => this.listeners.delete(callback);
    }
    publish(update) {
      const before = this.state;
      this.state = { ...this.state, ...update };
      if (before.status === 'downloading' && this.state.status === 'downloading' &&
          before.total === this.state.total && before.message === this.state.message &&
          before.microphoneBlocked === this.state.microphoneBlocked && before.microphoneMessage === this.state.microphoneMessage &&
          Math.floor(before.progress * 100) === Math.floor(this.state.progress * 100)) return;
      for (const listener of this.listeners) listener({ ...this.state });
    }
    isReady() { return this.state.status === 'ready' && !!this.worker; }
    supported() {
      const e = this.env;
      // The prepared sherpa runtime requires SIMD. Fail before downloading its
      // weights on engines that cannot execute this minimal SIMD function.
      const simd = e.WebAssembly?.validate?.(new Uint8Array([0,97,115,109,1,0,0,0,1,5,1,96,0,1,123,3,2,1,0,10,10,1,8,0,65,0,253,15,253,98,11]));
      return e.isSecureContext === true && !!e.Worker && !!e.WebAssembly &&
        !!e.crypto?.subtle && !!e.navigator?.mediaDevices?.getUserMedia &&
        !!(e.AudioContext || e.webkitAudioContext) && !!e.AudioWorkletNode && !!simd;
    }
    prepare() {
      if (this.isReady()) return Promise.resolve(true);
      if (this.preparation) return this.preparation;
      if (!this.supported()) {
        this.publish({ status: 'unsupported', message: 'This device cannot run local multiplayer.' });
        return Promise.resolve(false);
      }
      this.preparation = this.load().then(() => true).catch(error => {
        this.worker?.terminate();
        this.worker = null;
        this.publish({ status: 'error', message: error.message || 'Multiplayer preparation failed.' });
        return false;
      }).finally(() => { this.preparation = null; });
      return this.preparation;
    }
    async fetchTimed(url) {
      const controller = new this.env.AbortController();
      const timer = this.env.setTimeout(() => controller.abort(), 120000);
      try {
        const response = await this.env.fetch(url, { signal: controller.signal, credentials: 'same-origin' });
        if (!response.ok) throw new Error(`Multiplayer download failed (${response.status}). Tap Retry.`);
        // Keep the timeout active until the entire body has been consumed.
        return { response, done: () => this.env.clearTimeout(timer) };
      } catch (error) { this.env.clearTimeout(timer); throw error; }
    }
    async digest(buffer) {
      const hash = await this.env.crypto.subtle.digest('SHA-256', buffer);
      return Array.from(new Uint8Array(hash), n => n.toString(16).padStart(2, '0')).join('');
    }
    async load() {
      this.publish({ status: 'downloading', loaded: 0, total: 0, progress: 0, message: '' });
      const manifestRequest = await this.fetchTimed(this.manifestUrl);
      let manifest;
      try { manifest = await manifestRequest.response.json(); } finally { manifestRequest.done(); }
      if (!manifest || !Array.isArray(manifest.assets) || !manifest.assets.length || !manifest.runtime ||
          !/^[a-zA-Z0-9._-]+$/.test(manifest.version)) throw new Error('Multiplayer download manifest is invalid.');
      const ids = new Set();
      for (const asset of manifest.assets) {
        if (!asset || typeof asset.id !== 'string' || ids.has(asset.id) ||
            !Number.isSafeInteger(asset.bytes) || asset.bytes <= 0 || asset.bytes > 256000000 ||
            !/^[a-f0-9]{64}$/.test(asset.sha256)) throw new Error('Multiplayer asset manifest is invalid.');
        asset.href = new URL(asset.url, this.manifestUrl).href;
        if (new URL(asset.href).origin !== new URL(this.manifestUrl).origin)
          throw new Error('Multiplayer models must be served with the game.');
        ids.add(asset.id);
      }
      const total = manifest.assets.reduce((n, asset) => n + asset.bytes, 0);
      this.publish({ total });
      let cache = null;
      try { cache = await this.env.caches?.open(`voice-pop-models-${manifest.version}`); } catch { /* In-memory play still works. */ }
      let loaded = 0;
      const assets = {};
      for (const asset of manifest.assets) {
        let bytes = null;
        try {
          const cached = await cache?.match(asset.href);
          if (cached) {
            const stored = await cached.arrayBuffer();
            if (stored.byteLength === asset.bytes && await this.digest(stored) === asset.sha256) bytes = stored;
            else await cache.delete(asset.href);
          }
        } catch { /* A private-mode storage error must not prevent downloading. */ }
        if (!bytes) {
          const request = await this.fetchTimed(asset.href);
          try {
            if (request.response.body?.getReader) {
              const reader = request.response.body.getReader();
              const data = new Uint8Array(asset.bytes);
              let offset = 0;
              for (;;) {
                const { done, value } = await reader.read();
                if (done) break;
                if (offset + value.byteLength > data.byteLength) { await reader.cancel(); throw new Error('Multiplayer model size changed. Tap Retry.'); }
                data.set(value, offset); offset += value.byteLength;
                this.publish({ loaded: loaded + offset, progress: (loaded + offset) / total });
              }
              if (offset !== data.byteLength) throw new Error('Multiplayer download was interrupted. Tap Retry.');
              bytes = data.buffer;
            } else bytes = await request.response.arrayBuffer();
          } finally { request.done(); }
          if (bytes.byteLength !== asset.bytes || await this.digest(bytes) !== asset.sha256)
            throw new Error('Multiplayer model verification failed. Tap Retry.');
          try { await cache?.put(asset.href, new this.env.Response(bytes)); } catch { /* Cache is optional. */ }
        }
        assets[asset.id] = bytes;
        loaded += bytes.byteLength;
        this.publish({ loaded, progress: loaded / total });
      }
      this.publish({ status: 'initializing', message: '' });
      this.worker?.terminate();
      const worker = this.worker = new this.env.Worker(new URL('multiplayer-worker.js', this.baseUrl).href);
      worker.onmessage = event => { if (worker === this.worker) this.onMessage(event.data); };
      worker.onerror = event => { if (worker === this.worker) this.runtimeError(event.message || 'Local multiplayer stopped.'); };
      const ready = this.waitFor('ready', 120000);
      try { worker.postMessage({ type: 'init', assets, runtime: manifest.runtime }, Object.values(assets)); }
      catch (error) { this.runtimeError(error.message); }
      await ready;
      this.publish({ status: 'ready', progress: 1, message: '' });
    }
    waitFor(key, milliseconds) {
      return new Promise((resolve, reject) => {
        const timer = this.env.setTimeout(() => {
          this.waiters.delete(key); reject(new Error('Local multiplayer did not respond. Tap Retry.'));
        }, milliseconds);
        this.waiters.set(key, { resolve, reject, timer });
      });
    }
    onMessage(message) {
      if (!message || typeof message !== 'object') return;
      if (message.sessionId && message.sessionId !== this.session?.sessionId) { clearVoiceResult(message); return; }
      if (message.type === 'error') { this.runtimeError(message.message || 'Local multiplayer stopped.'); return; }
      const waiter = this.waiters.get(message.type === 'pong' ? `ping-${message.requestId}` : message.type);
      if (waiter) {
        this.env.clearTimeout(waiter.timer); this.waiters.delete(message.type === 'pong' ? `ping-${message.requestId}` : message.type);
        waiter.resolve(message);
      }
      if (!this.session || message.sessionId !== this.session.sessionId) { clearVoiceResult(message); return; }
      if (this.session.mode === 'enrollment') {
        const session = this.session;
        if (session.completed || !session.started && message.type === 'enrollment-complete') { clearVoiceResult(message); return; }
        if (message.type === 'enrollment-progress') session.onProgress?.(message);
        if (message.type === 'enrollment-complete') this.settleEnrollment(session, null, message);
        if (message.type === 'enrollment-error') this.settleEnrollment(session,
          Object.assign(new Error(message.message || 'Please record your voice again.'), { code: message.code || 'enrollment_failed' }));
        return;
      }
      if (this.session.mode === 'identification') {
        const session = this.session;
        if (session.completed) { clearVoiceResult(message); return; }
        if (message.type === 'identification-error') {
          this.settleIdentification(session,
            identificationError(message.code || 'identification_failed', message.message || 'Please try identifying your voice again.'));
          return;
        }
        if (!session.started) { clearVoiceResult(message); return; }
        if (message.type === 'identification-progress') session.onProgress?.(message);
        if (message.type === 'identification-complete') this.settleIdentification(session, null, message);
        return;
      }
      if (message.type === 'utterance') this.session.onEvent?.(message);
      if (message.type === 'flushed') this.session.onFlushed?.(message);
    }
    runtimeError(message) {
      for (const waiter of this.waiters.values()) {
        this.env.clearTimeout(waiter.timer); waiter.reject(new Error(message));
      }
      this.waiters.clear();
      const session = this.session;
      this.stop(new Error(message));
      this.worker?.terminate(); this.worker = null;
      this.publish({ status: 'error', message });
      session?.onError?.(new Error(message));
    }
    async verifyReady() {
      if (!this.isReady()) return false;
      const requestId = ++this.requestId;
      const response = this.waitFor(`ping-${requestId}`, 5000);
      try { this.worker.postMessage({ type: 'ping', requestId }); }
      catch (error) { this.runtimeError(error.message); }
      try { await response; return true; } catch (error) { this.runtimeError(error.message); return false; }
    }
    start(options) {
      if (!this.isReady()) return Promise.reject(new Error(this.state.status === 'error' && this.state.message || 'Multiplayer is still preparing. Continue solo or retry.'));
      if (this.pendingCapture) return Promise.reject(new Error('The previous microphone request is still closing. Tap Retry.'));
      if (!this.stop()) return Promise.reject(new Error('The previous microphone could not be stopped. Close this tab to stop voice input.'));
      const token = this.generation;
      const session = this.session = { ...options, mode: options.mode || 'game', accepting: true };
      if (session.mode === 'enrollment' || session.mode === 'identification') {
        session.result = {};
        session.result.promise = new Promise((resolve, reject) => { session.result.resolve = resolve; session.result.reject = reject; });
        // Cancellation can happen before callers request a completed recording.
        session.result.promise.catch(() => {});
      }
      const queued = [];
      session.queued = queued;
      let started = false;
      try { this.worker.postMessage({ type: 'start', sessionId: options.sessionId, timeOffsetMs: options.elapsedMs || 0, mode: session.mode,
        ...(session.mode === 'enrollment' ? { maxTimeMs: 60000 } : session.mode === 'identification' ? { maxTimeMs: 30000 } : {}) }); }
      catch (error) { this.runtimeError(error.message); return Promise.reject(error); }
      const send = frame => {
        if (token !== this.generation || !session.accepting) return;
        if (!started) { queued.push(frame); return; }
        try {
          this.worker.postMessage({ type: 'audio', sessionId: options.sessionId, samples: frame.samples,
            sampleOffset: frame.sampleOffset }, [frame.samples.buffer]);
        } catch (error) { this.runtimeError(error.message); }
      };
      // Call create synchronously inside the user's gesture (Safari microphone/audio policy).
      let capturePromise;
      try {
        capturePromise = this.env.VoicePopCapture.create({ onAudio: send,
          workletUrl: new URL('multiplayer-audio.js', this.baseUrl).href,
          onError: error => { if (token === this.generation) options.onError?.(error); } });
      } catch (error) { this.stop(error); return Promise.reject(error); }
      this.pendingCapture = Promise.resolve(capturePromise).then(capture => {
        if (token !== this.generation) {
          // Permission may resolve after cancellation. Retain a failed release
          // so no subsequent start can lose track of this physical microphone.
          try { capture.stop(); }
          catch (error) {
            this.capture = capture;
            this.microphoneBlocked();
            throw error;
          }
          return false;
        }
        this.capture = capture;
        started = true;
        session.started = true;
        options.onStarted?.();
        for (const frame of queued) send(frame);
        queued.length = 0;
        return true;
      }).catch(error => {
        if (token === this.generation) this.stop(error);
        throw error;
      }).finally(() => { this.pendingCapture = null; });
      return this.pendingCapture;
    }
    startEnrollment(options = {}) {
      if (typeof options.sessionId !== 'string' || !options.sessionId)
        return Promise.reject(new Error('A voice recording session ID is required.'));
      return this.start({ ...options, mode: 'enrollment', elapsedMs: 0,
        onStarted: () => {
          const session = this.session;
          if (!session || session.sessionId !== options.sessionId || session.mode !== 'enrollment') return;
          session.deadlineTimer = this.env.setTimeout(() => {
            if (this.session === session) this.finishEnrollment().catch(() => {});
          }, 60000);
          options.onStarted?.();
        },
        onError: error => {
          const session = this.session;
          if (session?.mode === 'enrollment' && session.sessionId === options.sessionId)
            this.settleEnrollment(session, error);
          else options.onError?.(error);
        },
        reportError: options.onError
      });
    }
    finishEnrollment() {
      const session = this.session;
      if (!session || session.mode !== 'enrollment') return Promise.reject(new Error('No voice recording is active.'));
      if (!this.capture) return Promise.reject(new Error('Wait for the microphone before finishing your recording.'));
      if (session.finishing) return session.result.promise;
      session.finishing = true;
      this.env.clearTimeout(session.deadlineTimer);
      session.finishTimer = this.env.setTimeout(() => {
        if (this.session === session) this.settleEnrollment(session, new Error('Voice recording did not finish. Please retry.'));
      }, 15000);
      this.flush().catch(error => { if (this.session === session) this.settleEnrollment(session, error); });
      return session.result.promise;
    }
    settleEnrollment(session, error, result) {
      if (session !== this.session || session.mode !== 'enrollment' || session.completed) { clearVoiceResult(result); return; }
      let completed;
      if (!error) {
        try {
          if (result?.modelVersion !== SPEAKER_MODEL_VERSION)
            throw identificationError('model_mismatch', 'The voice model changed. Please record again.');
          if (!result.quality || !Number.isFinite(result.quality.voicedMs) || result.quality.voicedMs < 12000 ||
              !Number.isSafeInteger(result.quality.segments) || result.quality.segments < 3)
            throw identificationError('insufficient_speech', 'Read at least three phrases with twelve seconds of clear speech.');
          const embedding = normalizedVoice(result.embedding);
          const templates = voiceTemplates(result.templates, embedding);
          if (!embedding || !templates) throw identificationError('invalid_voice_sample', 'The voice sample was unclear. Please record again.');
          completed = { embedding, templates, modelVersion: result.modelVersion, quality: { ...result.quality } };
          if (result.segments !== undefined) {
            if (!Array.isArray(result.segments) || result.segments.length !== result.quality.segments ||
                result.segments.some(segment => !segment || !validVoice(segment.embedding) || !Number.isFinite(segment.voicedMs) || segment.voicedMs <= 0) ||
                result.segments.reduce((sum, segment) => sum + segment.voicedMs, 0) + 1 < 12000)
              throw identificationError('invalid_voice_sample', 'The voice sample was unclear. Please record again.');
            completed.segments = result.segments.map(segment => ({ embedding: normalizedVoice(segment.embedding), voicedMs: segment.voicedMs }));
          }
        } catch (failure) { error = failure; }
      }
      clearVoiceResult(result);
      session.completed = true;
      if (!this.stop()) error = new Error('The microphone could not be stopped. Retry stopping or close this tab.');
      if (error) {
        clearVoiceResult(completed);
        session.result.reject(error);
        session.reportError?.(error);
      } else {
        session.result.resolve(completed);
        session.onComplete?.(completed);
      }
    }
    cancelEnrollment() {
      if (this.session && this.session.mode !== 'enrollment') return true;
      return this.stop();
    }
    startIdentification(options = {}) {
      if (typeof options.sessionId !== 'string' || !options.sessionId)
        return Promise.reject(identificationError('invalid_session', 'An identification session ID is required.'));
      const profiles = identificationProfiles(options.profiles);
      if (!profiles.length) return Promise.reject(identificationError('no_profiles', 'Add or re-record a saved voice before identifying a user.'));
      let reported = false, ownedSession = null;
      const report = error => {
        if (reported) return;
        reported = true;
        options.onError?.(error);
      };
      const starting = this.start({ ...options, profiles, mode: 'identification', elapsedMs: 0,
        onStarted: () => {
          const session = this.session;
          if (!session || session !== ownedSession) return;
          session.deadlineTimer = this.env.setTimeout(() => {
            if (this.session === session) this.finishIdentification(session);
          }, 25000);
          options.onStarted?.();
        },
        onError: error => {
          const session = this.session;
          if (session && session === ownedSession) this.settleIdentification(session, error);
          else if (!ownedSession?.canceled && !this.session) report(error);
        },
        reportError: report
      });
      if (this.session?.mode === 'identification' && this.session.profiles === profiles) ownedSession = this.session;
      return starting.catch(error => {
        if (!ownedSession) clearProfiles(profiles);
        if (!ownedSession?.canceled && (!this.session || this.session === ownedSession)) report(error);
        throw error;
      });
    }
    finishIdentification(session) {
      if (session !== this.session || session.mode !== 'identification' || session.finishing) return;
      session.finishing = true;
      this.env.clearTimeout(session.deadlineTimer);
      session.finishTimer = this.env.setTimeout(() => {
        if (this.session === session) this.settleIdentification(session,
          identificationError('identification_timeout', 'Voice identification timed out. Please try again.'));
      }, 2000);
      this.flush().catch(error => { if (this.session === session) this.settleIdentification(session, error); });
    }
    settleIdentification(session, error, result) {
      if (session !== this.session || session.mode !== 'identification' || session.completed) { clearVoiceResult(result); return; }
      let completed;
      if (!error) {
        try {
          if (result?.modelVersion !== SPEAKER_MODEL_VERSION)
            throw identificationError('model_mismatch', 'The voice model changed. Please try again.');
          if (!result.quality || !Number.isFinite(result.quality.voicedMs) || result.quality.voicedMs < 4000 ||
              !Number.isSafeInteger(result.quality.segments) || result.quality.segments < 2)
            throw identificationError('insufficient_speech', 'Read at least two phrases with four seconds of clear speech.');
          completed = identifyVoice(result, session.profiles);
        } catch (failure) { error = failure; }
      }
      clearVoiceResult(result);
      session.completed = true;
      if (!this.stop()) error = identificationError('microphone_release_failed', 'The microphone could not be stopped. Retry stopping or close this tab.');
      if (error) {
        session.result.reject(error);
        session.reportError?.(error);
      } else {
        session.result.resolve(completed);
        session.onComplete?.(completed);
      }
    }
    cancelIdentification() {
      if (this.session && this.session.mode !== 'identification') return true;
      return this.stop();
    }
    microphoneBlocked() {
      this.publish({ microphoneBlocked: true,
        microphoneMessage: 'The microphone could not be stopped. Retry stopping it or close this tab.' });
    }
    async flush() {
      const session = this.session;
      if (!session || !session.accepting) return;
      const token = this.generation;
      await this.capture?.flush();
      if (token !== this.generation || this.session !== session) return;
      session.accepting = false;
      this.capture?.stop(); this.capture = null;
      this.worker?.postMessage({ type: 'flush', sessionId: session.sessionId });
    }
    stop(reason = Object.assign(new Error('Voice recording canceled.'), { code: 'canceled' })) {
      this.generation++;
      const previous = this.session;
      this.session = null;
      if (previous) {
        previous.canceled = !previous.completed && reason.code === 'canceled';
        this.env.clearTimeout(previous.deadlineTimer);
        this.env.clearTimeout(previous.finishTimer);
        previous.queued?.forEach(frame => { if (frame.samples.byteLength) frame.samples.fill(0); });
        if (previous.queued) previous.queued.length = 0;
        if ((previous.mode === 'enrollment' || previous.mode === 'identification') && !previous.completed)
          previous.result.reject(reason);
        if (previous.mode === 'identification') {
          clearProfiles(previous.profiles);
          previous.profiles.length = 0;
        }
        try { this.worker?.postMessage({ type: 'stop', sessionId: previous.sessionId }); } catch { /* Still release the physical microphone. */ }
      }
      if (this.capture) {
        const capture = this.capture; this.capture = null;
        try { capture.stop(); } catch { this.capture = capture; this.microphoneBlocked(); return false; }
      }
      if (this.state.microphoneBlocked) this.publish({ microphoneBlocked: false, microphoneMessage: '' });
      return true;
    }
  }
  root.VoicePopMultiplayer = VoicePopMultiplayer;
  if (typeof module !== 'undefined' && module.exports) module.exports = { VoicePopMultiplayer, SPEAKER_MODEL_VERSION, identificationProfiles, matchVoiceProfile };
})(typeof window !== 'undefined' ? window : globalThis);
