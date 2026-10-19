(function (root) {
  'use strict';

  const SCHEMA = 1;
  const SKILLS = ['recognition', 'listening', 'spelling', 'speaking', 'context'];
  const MODES = ['match', 'memory', 'pop', 'phrase', 'jelly', 'word_jelly'];
  const MODE_SKILLS = { match: ['recognition', 'listening'], memory: ['recognition', 'listening'],
    pop: ['speaking'], phrase: ['context', 'listening'], jelly: ['recognition', 'listening'], word_jelly: ['spelling'] };
  const STORES = ['progress', 'context', 'events', 'outbox'];
  const clone = value => JSON.parse(JSON.stringify(value));
  const own = (value, key) => Object.prototype.hasOwnProperty.call(value, key);
  const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
  const identity = value => typeof value === 'string' && /^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,255}$/.test(value);
  const canonical = value => JSON.stringify(value, (_key, item) => object(item)
    ? Object.fromEntries(Object.keys(item).sort().map(key => [key, item[key]])) : item);
  const moduleKey = context => JSON.stringify([context.course_id, context.module_id, context.curriculum_revision]);
  const requirementKey = row => JSON.stringify([row.course_id, row.module_id, row.requirements_revision]);
  const requirementFingerprint = row => canonical({ course_id: row.course_id, module_id: row.module_id,
    requirements_revision: row.requirements_revision, terms: row.terms, expressions: row.expressions });
  const failure = error => ({ ok: false, retryable: true, error: error?.message || String(error) });
  function requireThat(condition, message) { if (!condition) throw new Error(message); }

  function prepareRequirements(source) {
    requireThat(Array.isArray(source), 'Professional requirements must be an array.');
    const result = new Map();
    for (const original of source) {
      const row = clone(original);
      requireThat(object(row) && ['course_id', 'module_id', 'curriculum_revision', 'requirements_revision'].every(key => identity(row[key])),
        'Professional requirements need stable course, module, and revision IDs.');
      requireThat(Array.isArray(row.terms) && row.terms.length === 50 && Array.isArray(row.expressions) &&
        row.expressions.length === 10 && row.expressions.every(identity) && new Set(row.expressions).size === 10,
      'A professional module requires 50 terms and 10 distinct expressions.');
      const seen = new Set();
      for (const term of row.terms) {
        requireThat(object(term) && identity(term.sense_id) && !seen.has(term.sense_id) &&
          Array.isArray(term.skills) && term.skills.length > 0 && term.skills.every(skill => SKILLS.includes(skill)) &&
          new Set(term.skills).size === term.skills.length, 'Each module term needs a distinct sense and eligible skills.');
        seen.add(term.sense_id);
        term.skills.sort();
      }
      row.terms.sort((a, b) => a.sense_id < b.sense_id ? -1 : a.sense_id > b.sense_id ? 1 : 0);
      row.expressions.sort();
      const key = moduleKey(row);
      requireThat(!result.has(key), 'Duplicate professional module revision.');
      for (const previous of result.values()) requireThat(requirementKey(previous) !== requirementKey(row) ||
        requirementFingerprint(previous) === requirementFingerprint(row), 'One requirements revision cannot describe different objectives.');
      result.set(key, row);
    }
    return result;
  }

  function validateContext(context, requirements, professionalOnly = false) {
    requireThat(object(context) && MODES.includes(context.mode), 'Choose an available exercise mode.');
    if (context.track === 'growth' && !professionalOnly) return clone(context);
    requireThat(context.track === 'professional' &&
      ['course_id', 'module_id', 'curriculum_revision'].every(key => identity(context[key])) &&
      requirements.has(moduleKey(context)), 'Choose an available professional module revision.');
    return clone(context);
  }

  function validateEvent(event, requirements) {
    requireThat(object(event) && identity(event.id) && identity(event.sense_id) && SKILLS.includes(event.skill) &&
      ['correct', 'assisted', 'atomic'].every(key => typeof event[key] === 'boolean'), 'The professional answer is invalid.');
    validateContext(event.context, requirements, true);
    requireThat(MODE_SKILLS[event.context.mode].includes(event.skill), 'This skill does not match the selected exercise mode.');
    const atomicExposure = event.atomic && event.correct && event.context.mode === 'word_jelly' &&
      event.skill === 'spelling' && !own(event, 'expression_id');
    requireThat(!event.atomic || atomicExposure, 'Atomic collection must be a correct Word Jelly spelling exposure.');
    const row = requirements.get(moduleKey(event.context));
    const term = row.terms.find(item => item.sense_id === event.sense_id);
    requireThat(term && (term.skills.includes(event.skill) || atomicExposure), 'This sense or skill does not belong to the selected module.');
    if (own(event, 'expression_id')) requireThat(event.skill === 'context' && row.expressions.includes(event.expression_id),
      'The expression does not belong to this module or contextual skill.');
    if (own(event, 'reward')) {
      const reward = event.reward;
      requireThat(object(reward) && reward.operation === 'credit' && object(reward.payload) &&
        Number.isSafeInteger(reward.payload.tier) && reward.payload.tier >= 0 && reward.payload.tier <= 180143985094819 &&
        Object.keys(reward.payload).length === 1 && Object.keys(reward).length === 2 && event.correct,
      'A reward needs a correct completed event and an existing wallet credit tier.');
    }
    return clone(event);
  }

  function emptyProgress() { return { schema: SCHEMA, sequence: 0, skills: {}, expressions: {}, completions: {}, requirements: {} }; }

  function validateProgress(progress) {
    requireThat(object(progress) && progress.schema === SCHEMA && Number.isSafeInteger(progress.sequence) && progress.sequence >= 0 &&
      ['skills', 'expressions', 'completions', 'requirements'].every(key => object(progress[key])),
    'Professional progress could not be read. Please retry.');
    for (const [sense, skills] of Object.entries(progress.skills)) {
      requireThat(identity(sense) && object(skills), 'Invalid professional sense history.');
      for (const [skill, evidence] of Object.entries(skills)) requireThat(SKILLS.includes(skill) && object(evidence) &&
        Number.isInteger(evidence.streak) && evidence.streak >= 0 && evidence.streak <= 3 && typeof evidence.earned === 'boolean' &&
        (evidence.streak < 3 || evidence.earned) && Number.isSafeInteger(evidence.exposures) && evidence.exposures > 0,
      'Invalid professional skill history.');
    }
    for (const [key, expressions] of Object.entries(progress.expressions)) requireThat(object(expressions) &&
      own(progress.requirements, key) && Object.entries(expressions).every(([id, earned]) => identity(id) && earned === true),
    'Invalid professional expression history.');
    for (const [key, receipt] of Object.entries(progress.completions)) requireThat(object(receipt) &&
      key === requirementKey(receipt) && Number.isSafeInteger(receipt.sequence) && receipt.sequence > 0 &&
      receipt.sequence <= progress.sequence && own(progress.requirements, key), 'Invalid professional completion receipt.');
    for (const value of Object.values(progress.requirements)) requireThat(typeof value === 'string' && value.length > 0,
      'Invalid professional requirements history.');
    return progress;
  }

  function applyEvent(saved, event, requirements) {
    validateProgress(saved);
    event = validateEvent(event, requirements);
    const progress = clone(saved);
    const row = requirements.get(moduleKey(event.context));
    const key = requirementKey(row);
    const fingerprint = requirementFingerprint(row);
    requireThat(!own(progress.requirements, key) || progress.requirements[key] === fingerprint,
      'This curriculum changed without a new revision. Please reload.');
    progress.requirements[key] = fingerprint;
    requireThat(progress.sequence < Number.MAX_SAFE_INTEGER, 'Professional progress storage has reached its supported limit.');
    progress.sequence++;
    if (!own(progress.skills, event.sense_id)) progress.skills[event.sense_id] = {};
    const skills = progress.skills[event.sense_id];
    const evidence = own(skills, event.skill) ? skills[event.skill] : { streak: 0, earned: false, exposures: 0 };
    requireThat(evidence.exposures < Number.MAX_SAFE_INTEGER, 'This professional history has reached its supported limit.');
    evidence.exposures++;
    // Assisted success and atomic collection are exposure, never assessed mastery.
    // An actual incorrect answer still breaks the streak, even after a hint.
    if (!event.atomic && !event.correct) evidence.streak = 0;
    else if (!event.atomic && !event.assisted) {
      evidence.streak = Math.min(3, evidence.streak + 1);
      evidence.earned ||= evidence.streak === 3;
    }
    skills[event.skill] = evidence;
    if (event.expression_id && event.correct && !event.assisted && !event.atomic) {
      if (!own(progress.expressions, key)) progress.expressions[key] = {};
      progress.expressions[key][event.expression_id] = true;
    }
    // Only visited revisions have an immutable requirement record. Shared skills
    // can finish another visited course without manufacturing an unvisited course.
    for (const candidate of requirements.values()) {
      const candidateKey = requirementKey(candidate);
      if (!own(progress.requirements, candidateKey) || own(progress.completions, candidateKey)) continue;
      requireThat(progress.requirements[candidateKey] === requirementFingerprint(candidate),
        'This curriculum changed without a new revision. Please reload.');
      const learned = candidate.terms.every(term => term.skills.some(skill =>
        own(progress.skills, term.sense_id) && own(progress.skills[term.sense_id], skill) && progress.skills[term.sense_id][skill].earned));
      const expressions = progress.expressions[candidateKey] || {};
      if (learned && candidate.expressions.every(id => own(expressions, id))) {
        progress.completions[candidateKey] = { course_id: candidate.course_id, module_id: candidate.module_id,
          requirements_revision: candidate.requirements_revision, sequence: progress.sequence };
      }
    }
    return progress;
  }

  function createProfessionalProgressStore(options = {}) {
    const requirements = prepareRequirements(options.requirements || []);
    const factory = options.indexedDB || root.indexedDB;
    let connection = null;
    let opening = null;
    function open() {
      if (connection) return Promise.resolve(connection);
      if (opening) return opening;
      opening = new Promise((resolve, reject) => {
        requireThat(factory && typeof factory.open === 'function', 'Professional storage is unavailable. Please retry.');
        const request = factory.open(options.name || 'growWithPip.professional.v1', SCHEMA);
        let finished = false;
        request.onupgradeneeded = () => {
          for (const name of STORES) if (!request.result.objectStoreNames.contains(name)) request.result.createObjectStore(name);
          request.transaction.objectStore('progress').put(emptyProgress(), 'current');
        };
        request.onblocked = () => { finished = true; reject(new Error('Close the older game tab, then retry professional storage.')); };
        request.onerror = () => { finished = true; reject(request.error); };
        request.onsuccess = () => {
          if (finished) { request.result.close(); return; }
          connection = request.result;
          connection.onversionchange = () => { connection?.close(); connection = null; };
          connection.onclose = () => { connection = null; };
          resolve(connection);
        };
      }).finally(() => { opening = null; });
      return opening;
    }

    async function execute(operation, payload = {}) {
      try {
        requireThat(['load', 'record', 'context', 'ack', 'register'].includes(operation), 'Unknown professional storage operation.');
        const additions = operation === 'register' ? prepareRequirements(payload.requirements) : null;
        if (operation === 'record') payload = validateEvent(payload, requirements);
        if (operation === 'context') payload = validateContext(payload, requirements);
        if (operation === 'ack') {
          requireThat(object(payload) && identity(payload.id), 'Choose a valid reward receipt.');
          payload = clone(payload);
        }
        const db = await open();
        return await new Promise(resolve => {
          let tx, result, reason;
          try { tx = db.transaction(STORES, operation === 'load' ? 'readonly' : 'readwrite'); }
          catch (error) { resolve(failure(error)); return; }
          const progressStore = tx.objectStore('progress'), contextStore = tx.objectStore('context');
          const eventStore = tx.objectStore('events'), outboxStore = tx.objectStore('outbox');
          tx.oncomplete = () => {
            if (additions) for (const [key, row] of additions) requirements.set(key, row);
            resolve(result);
          };
          tx.onabort = () => resolve(failure(reason || tx.error || new Error('Professional progress was not saved. Please retry.')));
          tx.onerror = () => { reason ||= tx.error; };
          const read = progressStore.get('current');
          read.onsuccess = () => {
            try {
              const saved = validateProgress(read.result);
              if (operation === 'register') {
                const combined = new Map(requirements);
                for (const [key, row] of additions) {
                  requireThat(!combined.has(key) || canonical(combined.get(key)) === canonical(row),
                    'This curriculum changed without a new revision. Please reload.');
                  const pinned = requirementKey(row);
                  requireThat(!own(saved.requirements, pinned) || saved.requirements[pinned] === requirementFingerprint(row),
                    'This curriculum changed without a new revision. Please reload.');
                  combined.set(key, row);
                }
                prepareRequirements([...combined.values()]);
                result = { ok: true, registered: additions.size, error: '' };
              } else if (operation === 'load') {
                const contextRead = contextStore.get('current');
                contextRead.onsuccess = () => {
                  const rewards = outboxStore.getAll();
                  rewards.onsuccess = () => { result = { ok: true, progress: saved,
                    context: contextRead.result ?? null, outbox: rewards.result, error: '' }; };
                };
              } else if (operation === 'context') {
                contextStore.put(payload, 'current');
                result = { ok: true, context: payload, error: '' };
              } else if (operation === 'record') {
                const receipt = eventStore.get(payload.id);
                receipt.onsuccess = () => {
                  try {
                    const fingerprint = canonical(payload);
                    if (receipt.result !== undefined) {
                      requireThat(receipt.result.fingerprint === fingerprint,
                        'This answer ID was already used for a different event.');
                      result = { ok: true, duplicate: true, progress: saved, error: '' };
                      return;
                    }
                    const progress = applyEvent(saved, payload, requirements);
                    progressStore.put(progress, 'current');
                    eventStore.add({ fingerprint, reward_acknowledged: false }, payload.id);
                    if (payload.reward) outboxStore.add({ id: payload.id, receipt_id: 'professional:' + payload.id,
                      operation: payload.reward.operation, payload: payload.reward.payload }, payload.id);
                    result = { ok: true, duplicate: false, progress, error: '' };
                  } catch (error) { reason = error; tx.abort(); }
                };
              } else {
                const receipt = eventStore.get(payload.id);
                receipt.onsuccess = () => {
                  try {
                    requireThat(receipt.result, 'The reward has no saved answer receipt.');
                    const reward = outboxStore.get(payload.id);
                    reward.onsuccess = () => {
                      try {
                        requireThat(reward.result || receipt.result.reward_acknowledged,
                          'This answer has no pending wallet reward.');
                        eventStore.put({ ...receipt.result, reward_acknowledged: true }, payload.id);
                        outboxStore.delete(payload.id);
                        result = { ok: true, duplicate: !!receipt.result.reward_acknowledged, error: '' };
                      } catch (error) { reason = error; tx.abort(); }
                    };
                  } catch (error) { reason = error; tx.abort(); }
                };
              }
              // Test injection can abort a real transaction without replacing IndexedDB.
              if (typeof options.beforeCommit === 'function') options.beforeCommit(tx, operation);
            } catch (error) { reason = error; tx.abort(); }
          };
        });
      } catch (error) { return failure(error); }
    }
    return Object.freeze({ execute, close() { connection?.close(); connection = null; } });
  }

  function createProfessionalProgressBridge(options) {
    const store = createProfessionalProgressStore(options);
    return Object.freeze({
      professionalProgressRequest(text, callback) {
        let message;
        try {
          requireThat(typeof text === 'string' && text.length <= 65536, 'The professional storage request is invalid.');
          message = JSON.parse(text);
          requireThat(object(message) && Number.isSafeInteger(message.request_id), 'A storage request needs an ID.');
        } catch (error) {
          queueMicrotask(() => {
            try { callback(JSON.stringify({ request_id: message?.request_id ?? -1, ...failure(error) })); } catch (_) {}
          });
          return;
        }
        store.execute(message.operation, message.payload).then(result => {
          try { callback(JSON.stringify({ request_id: message.request_id, ...result })); } catch (_) {}
        });
      },
      close: store.close
    });
  }

  const api = { prepareRequirements, validateContext, validateEvent, validateProgress, emptyProgress,
    applyEvent, moduleKey, requirementKey, canonical, createProfessionalProgressStore, createProfessionalProgressBridge };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ProfessionalProgress = Object.freeze(api);
})(typeof window === 'object' ? window : globalThis);
