(function (root) {
  'use strict';

  const MAX_PACK_BYTES = 128 * 1024 * 1024;
  const DEFAULT_TIMEOUT_MS = 90000;
  const MAX_DEPENDENCIES = 512;

  function createVocabularyLoader(options) {
    const entries = new Map();
    const bundles = new Map();
    const pending = [];
    let activeDownloads = 0;
    const fetchPack = options.fetch || root.fetch.bind(root);
    const digest = options.crypto || root.crypto;
    const timeoutMs = options.timeoutMs || DEFAULT_TIMEOUT_MS;
    const maximumBytes = options.maximumBytes || MAX_PACK_BYTES;
    const defer = options.defer || queueMicrotask;

    function snapshot(entry) {
      return { age: entry.age, state: entry.state, progress: entry.progress, path: entry.path,
        paths: [...entry.paths], error: entry.error };
    }

    function notify(entry, callback) {
      const value = JSON.stringify(snapshot(entry));
      for (const listener of callback ? [callback] : [...entry.listeners]) {
        // Avoid reentering the running WASM call that requested this pack.
        defer(() => { try { listener(value); } catch (_) {} });
      }
    }

    function unavailable() {
      return new Error('This word set is unavailable. Please reload the game and try again.');
    }

    function validatePack(pack, age, shared) {
      let hashPrefix = '';
      if (typeof pack?.file === 'string') {
        if (shared) {
          const match = pack.file.match(/^vocabulary-shared-((?:[0-9]+-)+)([a-f0-9]{16,64})\.pck\.br$/);
          if (match) {
            const labels = match[1].slice(0, -1).split('-');
            const ages = labels.map(Number);
            if (ages.length >= 2 && ages.length <= 10 && ages.includes(age) && ages.every((value, index) =>
              Number.isInteger(value) && value >= 3 && value <= 12 && String(value) === labels[index] &&
              (index === 0 || value > ages[index - 1]))) hashPrefix = match[2];
          }
        } else {
          const match = pack.file.match(new RegExp(`^vocabulary-${age}-([a-f0-9]{16,64})\\.pck\\.br$`));
          if (match) hashPrefix = match[1];
        }
      }
      if (!hashPrefix || !Number.isSafeInteger(pack.bytes) || pack.bytes < 1 || pack.bytes > maximumBytes ||
          typeof pack.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(pack.sha256) || !pack.sha256.startsWith(hashPrefix)) {
        throw unavailable();
      }
      const previous = bundles.get(pack.file);
      if (previous && (previous.pack.bytes !== pack.bytes || previous.pack.sha256 !== pack.sha256)) throw unavailable();
      return { file: pack.file, bytes: pack.bytes, sha256: pack.sha256 };
    }

    function manifestFor(age) {
      const manifest = typeof options.packs === 'function' ? options.packs() : options.packs;
      const source = manifest?.[String(age)];
      const base = validatePack(source, age, false);
      const dependencies = source.dependencies === undefined ? [] : source.dependencies;
      if (!Array.isArray(dependencies) || dependencies.length > MAX_DEPENDENCIES) throw unavailable();
      const required = [...dependencies.map(pack => validatePack(pack, age, true)), base];
      if (new Set(required.map(pack => pack.file)).size !== required.length) throw unavailable();
      return required;
    }

    function notifyBundle(bundle) {
      for (const listener of [...bundle.listeners]) listener();
    }

    async function download(bundle) {
      const pack = bundle.pack;
      const controller = new AbortController();
      bundle.controller = controller;
      let reader = null;
      let timer;
      const timedOut = new Error('The word download took too long. Please try again.');
      const checkActive = () => {
        if (controller.signal.aborted || bundles.get(pack.file) !== bundle) throw timedOut;
      };
      const timeout = new Promise((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          if (reader) Promise.resolve(reader.cancel()).catch(() => {});
          reject(timedOut);
        }, timeoutMs);
      });
      try {
        await Promise.race([timeout, (async () => {
          const response = await fetchPack(pack.file, {
            signal: controller.signal, cache: bundle.retry ? 'reload' : 'force-cache', credentials: 'same-origin', redirect: 'error'
          });
          checkActive();
          if (!response.ok) throw new Error('The words could not be downloaded. Please try again.');
          // Fetch exposes decoded bytes even when the immutable URL ends in .br.
          // Require a stream so an oversized response cannot allocate unbounded memory.
          if (!response.body || typeof response.body.getReader !== 'function') {
            throw new Error('This browser could not read the word download. Please try again.');
          }
          reader = response.body.getReader();
          const bytes = new Uint8Array(pack.bytes);
          let received = 0;
          while (true) {
            const chunk = await reader.read();
            checkActive();
            if (chunk.done) break;
            if (!(chunk.value instanceof Uint8Array) || received + chunk.value.byteLength > pack.bytes) {
              throw new Error('The word download was incomplete or damaged. Please try again.');
            }
            bytes.set(chunk.value, received);
            received += chunk.value.byteLength;
            const progress = Math.min(0.95, received / pack.bytes * 0.95);
            if (progress > bundle.progress) {
              bundle.progress = progress;
              notifyBundle(bundle);
            }
          }
          if (received !== pack.bytes) throw new Error('The word download was incomplete or damaged. Please try again.');
          if (!digest?.subtle) throw new Error('This browser could not verify the word download. Please reload and try again.');
          const hash = Array.from(new Uint8Array(await digest.subtle.digest('SHA-256', bytes)),
            value => value.toString(16).padStart(2, '0')).join('');
          checkActive();
          if (hash !== pack.sha256) throw new Error('The word download was incomplete or damaged. Please try again.');
          const engine = typeof options.engine === 'function' ? options.engine() : options.engine;
          if (typeof engine?.copyToFS !== 'function') throw new Error('The game is not ready to load these words. Please try again.');
          const path = '/' + pack.file.slice(0, -3);
          await engine.copyToFS(path, bytes);
          checkActive();
          bundle.path = path;
          bundle.progress = 1;
          bundle.state = 'ready';
        })()]);
      } catch (error) {
        controller.abort();
        if (reader) Promise.resolve(reader.cancel()).catch(() => {});
        bundle.state = 'failed';
        bundle.path = '';
        bundle.error = error?.message || 'The words could not be downloaded. Please try again.';
      } finally {
        clearTimeout(timer);
        bundle.controller = null;
      }
      notifyBundle(bundle);
      return bundle;
    }

    function startPending() {
      // Shared resources are downloaded once, with bounded concurrent buffers.
      while (activeDownloads < 3 && pending.length) {
        const { bundle, resolve } = pending.shift();
        activeDownloads++;
        download(bundle).then(resolve).finally(() => { activeDownloads--; startPending(); });
      }
    }

    function requestBundle(pack) {
      const previous = bundles.get(pack.file);
      if (previous && previous.state !== 'failed') return previous;
      const bundle = { pack, state: 'loading', progress: 0, path: '', error: '', listeners: new Set(),
        retry: previous?.state === 'failed', task: null };
      bundles.set(pack.file, bundle);
      bundle.task = new Promise(resolve => { pending.push({ bundle, resolve }); });
      startPending();
      return bundle;
    }

    async function loadAge(entry) {
      let required = [];
      let update;
      try {
        // Validate the complete dependency set before starting any download.
        const packs = manifestFor(entry.age);
        required = packs.map(requestBundle);
        const totalBytes = packs.reduce((total, pack) => total + pack.bytes, 0);
        update = () => {
          if (entry.state !== 'loading') return;
          const progress = required.reduce((total, bundle) => total + bundle.pack.bytes * bundle.progress, 0) / totalBytes;
          if (progress > entry.progress) {
            entry.progress = progress;
            notify(entry);
          }
        };
        for (const bundle of required) bundle.listeners.add(update);
        update();
        await Promise.all(required.map(async bundle => {
          await bundle.task;
          if (bundle.state !== 'ready') throw new Error(bundle.error);
        }));
        entry.paths = required.map(bundle => bundle.path);
        entry.path = entry.paths.at(-1);
        entry.progress = 1;
        entry.state = 'ready';
      } catch (error) {
        entry.state = 'failed';
        entry.path = '';
        entry.paths = [];
        entry.error = error?.message || 'The words could not be downloaded. Please try again.';
      } finally {
        for (const bundle of required) bundle.listeners.delete(update);
      }
      notify(entry);
      entry.listeners.clear();
      return snapshot(entry);
    }

    function request(age, callback) {
      if (!Number.isInteger(age) || age < 3 || age > 12 || typeof callback !== 'function') {
        const invalid = { age, state: 'failed', progress: 0, path: '', paths: [],
          error: 'Please choose an available age word set.', listeners: new Set() };
        if (typeof callback === 'function') notify(invalid, callback);
        return Promise.resolve(snapshot(invalid));
      }
      const previous = entries.get(age);
      if (previous && previous.state !== 'failed') {
        if (previous.state === 'loading') previous.listeners.add(callback);
        notify(previous, callback);
        return previous.task || Promise.resolve(snapshot(previous));
      }
      const entry = { age, state: 'loading', progress: 0, path: '', paths: [], error: '',
        listeners: new Set([callback]), task: null };
      entries.set(age, entry);
      notify(entry);
      entry.task = loadAge(entry);
      return entry.task;
    }

    return Object.freeze({
      request,
      status(age) { return entries.has(age) ? snapshot(entries.get(age)) :
        { age, state: 'idle', progress: 0, path: '', paths: [], error: '' }; }
    });
  }

  if (typeof module === 'object' && module.exports) module.exports = { createVocabularyLoader, MAX_PACK_BYTES };
  else root.createVocabularyLoader = createVocabularyLoader;
})(typeof window === 'object' ? window : globalThis);
