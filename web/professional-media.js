(function (root) {
  'use strict';

  const LIMITS = Object.freeze({ manifest: 256 * 1024, compressed: 10 * 1024 * 1024,
    decoded: 32 * 1024 * 1024, resident: 128 * 1024 * 1024, resources: 256 });
  const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
  const identity = value => typeof value === 'string' && /^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,255}$/.test(value);
  const whole = (value, max) => Number.isSafeInteger(value) && value > 0 && value <= max;
  const clone = value => JSON.parse(JSON.stringify(value));
  function check(condition, message, code = 'invalid_manifest') {
    if (!condition) throw Object.assign(new Error(message), { code });
  }
  function validateResource(value) {
    check(object(value) && typeof value.sha256 === 'string' && /^[a-f0-9]{64}$/.test(value.sha256) &&
      value.id === `sha256:${value.sha256}`, 'Media requires its canonical SHA-256 resource identity.');
    check(['png', 'webp', 'jpg', 'wav'].includes(value.format) &&
      value.path === `professional-media/${value.sha256}.${value.format}`, 'Media needs an immutable content-addressed path.');
    check(whole(value.compressed_bytes, LIMITS.compressed) && whole(value.decoded_bytes, LIMITS.decoded),
      'Media exceeds its delivery budget.', 'budget_pressure');
    if (value.kind === 'image') {
      check(['png', 'webp', 'jpg'].includes(value.format) && whole(value.width, 8192) && whole(value.height, 8192) &&
        value.decoded_bytes === value.width * value.height * 8, 'Images require a conservative RGBA8 CPU and GPU budget.');
    } else {
      check(value.kind === 'audio' && value.format === 'wav' && [1, 2].includes(value.channels) &&
        whole(value.sample_rate, 96000) && value.sample_rate >= 8000 && whole(value.frames, LIMITS.decoded / 2) &&
        value.decoded_bytes === value.frames * value.channels * 2, 'Audio requires exact PCM16 frame, channel, and sample-rate metadata.');
    }
    return clone(value);
  }
  function validateManifest(source, expected = {}) {
    check(object(source) && new TextEncoder().encode(JSON.stringify(source)).length <= LIMITS.manifest &&
      [1, 2].includes(source.schema_version) && ['course_id', 'module_id', 'curriculum_revision'].every(key => identity(source[key])),
    'The module media manifest is invalid or too large.');
    check(Array.isArray(source.resources) && source.resources.length > 0 && source.resources.length <= LIMITS.resources,
      'The module needs a small, nonempty resource inventory.');
    for (const key of ['course_id', 'module_id', 'curriculum_revision']) {
      check(expected[key] === undefined || expected[key] === source[key], 'The media manifest belongs to another module revision.');
    }
    if (expected.track !== undefined) check(expected.track === 'professional', 'Professional media needs a professional context.');
    let compressed = 0; let decoded = 0;
    const ids = new Set();
    for (const value of source.resources) {
      const resource = validateResource(value);
      check(!ids.has(resource.id), 'A module must list each shared resource only once.');
      ids.add(resource.id); compressed += resource.compressed_bytes; decoded += resource.decoded_bytes;
    }
    if (source.schema_version === 1) {
      check(source.bundles === undefined, 'Version 1 media cannot declare version 2 bundles.');
      check(compressed <= LIMITS.compressed && decoded <= LIMITS.decoded,
        'The module exceeds the 10 MiB transfer or 32 MiB decoded delivery budget.', 'budget_pressure');
    } else {
      check(compressed <= LIMITS.compressed && decoded <= LIMITS.resident,
        'The module exceeds the 10 MiB transfer or 128 MiB residency budget.', 'budget_pressure');
      validateBundles(source);
    }
    return clone(source);
  }
  function validateBundles(source) {
    check(Array.isArray(source.bundles) && source.bundles.length > 0 && source.bundles.length <= LIMITS.resources,
      'Version 2 media requires a bounded, nonempty bundle inventory.');
    const resources = new Map(source.resources.map(value => [value.id, value]));
    const covered = new Set(); const inventory = new Map();
    for (const bundle of source.bundles) {
      check(object(bundle) && identity(bundle.id) && identity(bundle.revision), 'A bundle needs a stable identity and revision.');
      const key = JSON.stringify([bundle.id, bundle.revision]);
      check(!inventory.has(key), 'A module must list each bundle revision only once.');
      check(Array.isArray(bundle.resource_ids) && bundle.resource_ids.length > 0 && bundle.resource_ids.length <= LIMITS.resources,
        'A bundle needs a bounded, nonempty resource inventory.');
      const members = new Set(); let decoded = 0;
      for (const id of bundle.resource_ids) {
        check(typeof id === 'string' && resources.has(id), 'A bundle refers to absent media.', 'missing_dependency');
        check(!members.has(id), 'A bundle must list each shared resource only once.');
        members.add(id); covered.add(id); decoded += resources.get(id).decoded_bytes;
      }
      check(decoded <= LIMITS.decoded, 'A bundle exceeds the 32 MiB decoded delivery budget.', 'budget_pressure');
      inventory.set(key, [...members].sort());
    }
    check(covered.size === resources.size, 'Every module resource must belong to a delivery bundle.', 'missing_dependency');
    return inventory;
  }
  function bundleInventory(source) {
    const manifest = validateManifest(source);
    return manifest.schema_version === 2 ? validateBundles(manifest) : new Map();
  }
  function validateDependencies(source, requiredIds, expected = {}) {
    const manifest = validateManifest(source, expected);
    check(Array.isArray(requiredIds), 'Media dependencies must be an array.', 'missing_dependency');
    const available = new Set(manifest.resources.map(resource => resource.id));
    check(requiredIds.every(id => typeof id === 'string' && available.has(id)),
      'A required content or theme resource is absent from the module manifest.', 'missing_dependency');
    return manifest;
  }
  const failure = error => ({ ok: false, retryable: true, code: error.code || 'unavailable', error: error.message || String(error) });
  function createProfessionalMediaBridge(options = {}) {
    const fetcher = options.fetch || root.fetch?.bind(root);
    const crypto = options.crypto || root.crypto;
    const base = options.baseURL || root.document?.baseURI;
    const timeoutMs = Math.max(1, Math.min(options.timeoutMs || 15000, 60000));
    const controllers = new Map();
    const retryPaths = new Set();
    let latest = 0;
    let sequence = 0;

    function cancel(generation) {
      for (const pending of controllers.values()) if (pending.generation <= generation) pending.controller.abort();
    }
    async function fetchResource(resource, generation) {
      resource = validateResource(resource);
      check(whole(generation, Number.MAX_SAFE_INTEGER), 'Invalid media request generation.', 'invalid_request');
      check(generation >= latest, 'This media selection has been replaced.', 'cancelled');
      if (generation > latest) { cancel(generation); latest = generation; }
      check(typeof fetcher === 'function' && crypto?.subtle && base, 'Media downloads are unavailable.', 'unavailable');
      const url = new URL(resource.path, base);
      const baseURL = new URL(base);
      check(['http:', 'https:'].includes(url.protocol) && url.origin === baseURL.origin,
        'Media must use the configured same-origin delivery root.', 'invalid_request');
      const key = ++sequence;
      const controller = new AbortController();
      controllers.set(key, { generation, controller });
      let timedOut = false;
      const timer = setTimeout(() => { timedOut = true; controller.abort(); }, timeoutMs);
      const cancelled = () => {
        if (timedOut) throw Object.assign(new Error('Media loading timed out. Please retry.'), { code: 'timeout' });
        check(!controller.signal.aborted && generation === latest, 'This media selection has been replaced.', 'cancelled');
      };
      try {
        const response = await fetcher(url.href, { signal: controller.signal, credentials: 'same-origin', redirect: 'error',
          cache: retryPaths.has(resource.path) ? 'reload' : 'force-cache' });
        cancelled();
        check(response.ok, `Media is unavailable (HTTP ${response.status}). Please retry.`, 'missing_asset');
        const length = response.headers.get('content-length');
        check(length === null || Number(length) <= resource.compressed_bytes, 'Media transfer exceeds its declared size.', 'size_mismatch');
        check(response.body && typeof response.body.getReader === 'function', 'Bounded streaming downloads are unavailable.', 'unavailable');
        const reader = response.body.getReader();
        const data = new Uint8Array(resource.compressed_bytes);
        let offset = 0;
        try {
          while (true) {
            const { done, value } = await reader.read(); cancelled();
            if (done) break;
            check(value instanceof Uint8Array && offset + value.length <= data.length, 'Media transfer exceeds its declared size.', 'size_mismatch');
            data.set(value, offset); offset += value.length;
          }
        } finally { await reader.cancel().catch(() => {}); reader.releaseLock(); }
        check(offset === data.length, 'The media transfer is incomplete. Please retry.', 'size_mismatch');
        const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', data)), byte => byte.toString(16).padStart(2, '0')).join('');
        cancelled();
        check(hash === resource.sha256, 'Media failed its SHA-256 integrity check. Please retry.', 'hash_mismatch');
        retryPaths.delete(resource.path);
        return { ok: true, generation, resource_id: resource.id, bytes: data };
      } catch (error) {
        if (timedOut) return failure(Object.assign(new Error('Media loading timed out. Please retry.'), { code: 'timeout' }));
        if (controller.signal.aborted || generation !== latest) return failure(Object.assign(new Error('This media selection has been replaced.'), { code: 'cancelled' }));
        retryPaths.add(resource.path);
        controller.abort();
        return failure(error);
      } finally { clearTimeout(timer); controllers.delete(key); }
    }
    function professionalMediaRequest(source, callback) {
      let request;
      try {
        request = JSON.parse(source);
        check(object(request) && whole(request.request_id, Number.MAX_SAFE_INTEGER) && object(request.resource), 'Invalid media bridge request.', 'invalid_request');
      } catch (error) {
        setTimeout(() => callback(JSON.stringify({ request_id: request?.request_id || 0, ...failure(error) })), 0);
        return;
      }
      Promise.resolve().then(() => fetchResource(request.resource, request.generation)).then(result => {
        if (result.ok) {
          let binary = '';
          for (let offset = 0; offset < result.bytes.length; offset += 32768) binary += String.fromCharCode(...result.bytes.subarray(offset, offset + 32768));
          result.data_base64 = root.btoa(binary);
          delete result.bytes;
        }
        return result;
      }).catch(failure).then(result => {
        setTimeout(() => callback(JSON.stringify({ request_id: request.request_id, generation: request.generation, ...result })), 0);
      });
    }
    return { fetchResource, professionalMediaRequest, professionalMediaCancel: cancel };
  }
  const api = { LIMITS, validateResource, validateManifest, validateDependencies, bundleInventory, createProfessionalMediaBridge };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.ProfessionalMedia = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
