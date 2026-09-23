/* Local model preparation is independent of microphone and round lifecycles. */
(function (root) {
  'use strict';
  class VoicePopMultiplayer {
    constructor(options = {}) {
      this.env = options.env || root;
      this.baseUrl = options.baseUrl || this.env.document?.baseURI || 'http://localhost/';
      this.manifestUrl = new URL(options.manifestUrl || 'multiplayer/manifest.json', this.baseUrl).href;
      this.state = { status: 'idle', loaded: 0, total: 0, progress: 0, message: '' };
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
      if (message.sessionId && message.sessionId !== this.session?.sessionId) return;
      if (message.type === 'error') { this.runtimeError(message.message || 'Local multiplayer stopped.'); return; }
      const waiter = this.waiters.get(message.type === 'pong' ? `ping-${message.requestId}` : message.type);
      if (waiter) {
        this.env.clearTimeout(waiter.timer); this.waiters.delete(message.type === 'pong' ? `ping-${message.requestId}` : message.type);
        waiter.resolve(message);
      }
      if (!this.session || message.sessionId !== this.session.sessionId) return;
      if (message.type === 'utterance') this.session.onEvent?.(message);
      if (message.type === 'flushed') this.session.onFlushed?.(message);
    }
    runtimeError(message) {
      for (const waiter of this.waiters.values()) {
        this.env.clearTimeout(waiter.timer); waiter.reject(new Error(message));
      }
      this.waiters.clear();
      const session = this.session;
      this.stop();
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
      const session = this.session = { ...options, accepting: true };
      const queued = [];
      let started = false;
      try { this.worker.postMessage({ type: 'start', sessionId: options.sessionId, timeOffsetMs: options.elapsedMs || 0 }); }
      catch (error) { this.runtimeError(error.message); return Promise.reject(error); }
      const send = frame => {
        if (token !== this.generation || !session.accepting) return;
        if (!started) { queued.push(frame); return; }
        this.worker.postMessage({ type: 'audio', sessionId: options.sessionId, samples: frame.samples,
          sampleOffset: frame.sampleOffset }, [frame.samples.buffer]);
      };
      // Call create synchronously inside the user's gesture (Safari microphone/audio policy).
      let capturePromise;
      try {
        capturePromise = this.env.VoicePopCapture.create({ onAudio: send,
          workletUrl: new URL('multiplayer-audio.js', this.baseUrl).href,
          onError: error => { if (token === this.generation) options.onError?.(error); } });
      } catch (error) { this.stop(); return Promise.reject(error); }
      this.pendingCapture = Promise.resolve(capturePromise).then(capture => {
        if (token !== this.generation) {
          // Permission may resolve after cancellation. Retain a failed release
          // so no subsequent start can lose track of this physical microphone.
          try { capture.stop(); }
          catch (error) {
            this.capture = capture;
            this.publish({ status: 'error', message: 'The previous microphone could not be stopped. Close this tab to stop voice input.' });
            throw error;
          }
          return false;
        }
        this.capture = capture;
        started = true;
        options.onStarted?.();
        for (const frame of queued) send(frame);
        return true;
      }).catch(error => {
        if (token === this.generation) this.stop();
        throw error;
      }).finally(() => { this.pendingCapture = null; });
      return this.pendingCapture;
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
    stop() {
      this.generation++;
      const previous = this.session;
      this.session = null;
      if (previous) {
        try { this.worker?.postMessage({ type: 'stop', sessionId: previous.sessionId }); } catch { /* Still release the physical microphone. */ }
      }
      if (this.capture) {
        const capture = this.capture; this.capture = null;
        try { capture.stop(); } catch { this.capture = capture; return false; }
      }
      return true;
    }
  }
  root.VoicePopMultiplayer = VoicePopMultiplayer;
  if (typeof module !== 'undefined' && module.exports) module.exports = { VoicePopMultiplayer };
})(typeof window !== 'undefined' ? window : globalThis);
