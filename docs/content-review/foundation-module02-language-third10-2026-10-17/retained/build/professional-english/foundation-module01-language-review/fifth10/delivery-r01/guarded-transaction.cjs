'use strict';
// Synchronous, recoverable file transactions. The caller owns the repository write slot.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const VERSION = 1;
const active = new Set();
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const encode = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const key = file => process.platform === 'win32' ? file.toLowerCase() : file;
const inside = (parent, child) => key(child).startsWith(key(parent) + path.sep);
const samePath = (left, right) => key(left) === key(right);
const relative = (root, file) => path.relative(root, file).replaceAll('\\', '/');
const exists = file => { try { fs.lstatSync(file); return true; } catch (error) { if (error.code === 'ENOENT') return false; throw error; } };
function absolute(value, label) {
  assert.equal(typeof value, 'string', label + ' must be a path string');
  assert.ok(path.isAbsolute(value), label + ' must be absolute');
  return path.resolve(value);
}
function safePath(root, file, allowMissing = true) {
  assert.ok(inside(root, file), 'Path must remain beneath the intended repository: ' + file);
  let cursor = root;
  for (const segment of path.relative(root, file).split(path.sep)) {
    cursor = path.join(cursor, segment);
    if (!exists(cursor)) {
      assert.ok(allowMissing, 'Missing path: ' + cursor);
      continue;
    }
    const stat = fs.lstatSync(cursor);
    assert.ok(!stat.isSymbolicLink(), 'Symlinks and junctions are not transaction paths: ' + cursor);
    if (!samePath(cursor, file)) assert.ok(stat.isDirectory(), 'Ancestor must be a directory: ' + cursor);
  }
  return file;
}
function context(options) {
  const repositoryRoot = absolute(options.repositoryRoot, 'repositoryRoot');
  assert.ok(fs.statSync(repositoryRoot).isDirectory(), 'Repository root must exist');
  assert.ok(!fs.lstatSync(repositoryRoot).isSymbolicLink(), 'Repository root must not be a symlink or junction');
  const transactionDir = safePath(repositoryRoot, absolute(options.transactionDir, 'transactionDir'));
  const parent = path.dirname(transactionDir);
  assert.ok(inside(repositoryRoot, parent), 'Transaction parent must be below the repository');
  assert.ok(Array.isArray(options.allowedPaths) && options.allowedPaths.length > 0, 'An exact nonempty allowlist is required');
  const allowedPaths = options.allowedPaths.map(file => safePath(repositoryRoot, absolute(file, 'allowed path')));
  assert.equal(new Set(allowedPaths.map(key)).size, allowedPaths.length, 'Duplicate allowed path');
  for (const file of allowedPaths) {
    assert.ok(!samePath(file, transactionDir) && !inside(transactionDir, file), 'Targets must be outside transaction artifacts');
    assert.ok(!inside(file, transactionDir), 'Target must not contain the transaction directory');
    assert.ok(!samePath(file, path.join(parent, 'active-transaction.json')), 'Lock is not a target');
    assert.ok(!inside(parent, file), 'Targets must not overwrite shared transaction history');
    if (exists(file)) assert.ok(fs.lstatSync(file).isFile(), 'Target must be a regular file: ' + file);
  }
  const sortedAllowed = [...allowedPaths].sort((a, b) => key(a).localeCompare(key(b)));
  return { repositoryRoot, transactionDir, parent, allowedPaths: sortedAllowed, lockFile: path.join(parent, 'active-transaction.json') };
}
function planFor(options, ctx) {
  assert.ok(Array.isArray(options.changes), 'changes must be an array');
  const changes = options.changes.map((change, index) => {
    const file = safePath(ctx.repositoryRoot, absolute(change.path, 'change.path'));
    assert.ok(change.before === null || Buffer.isBuffer(change.before), 'before must be a Buffer or null');
    assert.ok(Buffer.isBuffer(change.after), 'after must be a Buffer');
    const before = change.before === null ? null : Buffer.from(change.before);
    const after = Buffer.from(change.after);
    return { path: file, before, after, index };
  });
  assert.equal(new Set(changes.map(change => key(change.path))).size, changes.length, 'Duplicate planned path');
  assert.deepEqual(changes.map(change => key(change.path)).sort(), ctx.allowedPaths.map(key).sort(), 'Planned files must equal the exact allowlist');
  const entries = changes.map(change => ({ path: relative(ctx.repositoryRoot, change.path), before: change.before === null ? null : { bytes: change.before.length, sha256: digest(change.before) }, after: { bytes: change.after.length, sha256: digest(change.after) }, noop: change.before !== null && change.before.equals(change.after) }));
  const descriptor = { schema: VERSION, repository_root: ctx.repositoryRoot, allowed_paths: ctx.allowedPaths.map(file => relative(ctx.repositoryRoot, file)), entries };
  return { changes, descriptor, planSha256: digest(encode(descriptor)) };
}
function describePlan(options) {
  const ctx = context(options), plan = planFor(options, ctx);
  return { planSha256: plan.planSha256, descriptor: plan.descriptor };
}
function current(ctx, file) {
  safePath(ctx.repositoryRoot, file);
  if (!exists(file)) return null;
  assert.ok(fs.lstatSync(file).isFile(), 'Target must be a regular file: ' + file);
  return fs.readFileSync(file);
}
function matches(bytes, expected) {
  return expected === null ? bytes === null : bytes !== null && bytes.length === expected.bytes && digest(bytes) === expected.sha256;
}
function expectCurrent(ctx, file, expected, label) {
  assert.ok(matches(current(ctx, file), expected), (label || 'Target drift') + ': ' + relative(ctx.repositoryRoot, file));
}
function mkdirChecked(ctx, directory) {
  if (samePath(directory, ctx.repositoryRoot)) return;
  safePath(ctx.repositoryRoot, directory);
  if (exists(directory)) {
    assert.ok(fs.lstatSync(directory).isDirectory(), 'Expected directory: ' + directory);
    return;
  }
  mkdirChecked(ctx, path.dirname(directory));
  fs.mkdirSync(directory);
}
function durableNew(file, bytes) {
  const fd = fs.openSync(file, 'wx');
  try { fs.writeFileSync(fd, bytes); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
}
function artifact(ctx, name, value) {
  const final = safePath(ctx.repositoryRoot, path.join(ctx.transactionDir, name));
  assert.ok(inside(ctx.transactionDir, final), 'Artifact path escapes the transaction');
  assert.ok(!exists(final), 'Immutable artifact already exists: ' + name);
  mkdirChecked(ctx, path.dirname(final));
  const pending = path.join(ctx.transactionDir, '.pending-' + crypto.randomUUID());
  durableNew(pending, Buffer.isBuffer(value) ? value : encode(value));
  assert.ok(!exists(final), 'Immutable artifact appeared: ' + name);
  fs.renameSync(pending, final);
  return final;
}
function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8')); }
function liveProcess(pid) {
  if (!Number.isInteger(pid) || pid < 1) return true;
  try { process.kill(pid, 0); return true; } catch (error) { return error.code !== 'ESRCH'; }
}
function acquire(ctx, recovery) {
  mkdirChecked(ctx, ctx.parent);
  safePath(ctx.repositoryRoot, ctx.lockFile);
  if (exists(ctx.lockFile)) {
    assert.ok(recovery, 'Another transaction requires completion or explicit recovery');
    const bytes = fs.readFileSync(ctx.lockFile), lock = JSON.parse(bytes.toString('utf8'));
    assert.equal(lock.schema, VERSION, 'Unknown lock schema');
    assert.ok(samePath(lock.transaction_dir, ctx.transactionDir), 'Recover the transaction owning the shared lock first');
    assert.ok(samePath(lock.repository_root, ctx.repositoryRoot), 'Lock repository mismatch');
    assert.ok(!active.has(lock.token), 'Transaction is still active in this process');
    assert.ok(lock.pid === process.pid || !liveProcess(lock.pid), 'Lock owner is still running');
    assert.ok(fs.readFileSync(ctx.lockFile).equals(bytes), 'Lock changed during recovery');
    fs.unlinkSync(ctx.lockFile);
  }
  const lock = { schema: VERSION, token: crypto.randomUUID(), pid: process.pid, repository_root: ctx.repositoryRoot, transaction_dir: ctx.transactionDir, purpose: recovery ? 'recovery' : 'commit' };
  const bytes = encode(lock);
  durableNew(ctx.lockFile, bytes);
  active.add(lock.token);
  return { ...lock, bytes };
}
function release(ctx, lock) {
  if (!lock) return;
  active.delete(lock.token);
  if (exists(ctx.lockFile) && fs.readFileSync(ctx.lockFile).equals(lock.bytes)) fs.unlinkSync(ctx.lockFile);
}
function events(ctx, preparedHash) {
  const directory = path.join(ctx.transactionDir, 'states');
  if (!exists(directory)) return [];
  safePath(ctx.repositoryRoot, directory, false);
  const names = fs.readdirSync(directory).filter(name => /^\d{6}-[a-z-]+\.json$/.test(name)).sort();
  let previous = null;
  return names.map((name, index) => {
    const file = safePath(ctx.repositoryRoot, path.join(directory, name), false), bytes = fs.readFileSync(file), value = JSON.parse(bytes.toString('utf8'));
    assert.equal(value.sequence, index + 1, 'State sequence gap');
    assert.equal(value.prepared_sha256, preparedHash, 'State preparation mismatch');
    assert.equal(value.previous_state_sha256, previous, 'State history changed');
    previous = digest(bytes);
    return { name, value, sha256: previous };
  });
}
function append(ctx, preparedHash, status, details = {}) {
  const history = events(ctx, preparedHash), sequence = history.length + 1;
  const name = 'states/' + String(sequence).padStart(6, '0') + '-' + status + '.json';
  const value = { schema: VERSION, sequence, status, prepared_sha256: preparedHash, previous_state_sha256: history.at(-1)?.sha256 || null, recorded_at: new Date().toISOString(), ...details };
  const file = artifact(ctx, name, value);
  return { path: file, sha256: digest(fs.readFileSync(file)), status };
}
function loadPrepared(ctx, expectedPlanSha256) {
  const file = safePath(ctx.repositoryRoot, path.join(ctx.transactionDir, 'prepared.json'), false), bytes = fs.readFileSync(file), prepared = JSON.parse(bytes.toString('utf8'));
  assert.equal(prepared.schema, VERSION);
  assert.ok(samePath(prepared.plan.repository_root, ctx.repositoryRoot), 'Prepared repository mismatch');
  assert.deepEqual(prepared.plan.allowed_paths, ctx.allowedPaths.map(file => relative(ctx.repositoryRoot, file)), 'Recovery allowlist mismatch');
  assert.equal(digest(encode(prepared.plan)), prepared.plan_sha256, 'Prepared plan changed');
  if (expectedPlanSha256 !== undefined) assert.equal(prepared.plan_sha256, expectedPlanSha256, 'Recovery plan differs from trusted caller plan');
  assert.equal(prepared.entries.length, prepared.plan.entries.length);
  assert.deepEqual(prepared.entries.map(entry => entry.path).sort(), prepared.plan.allowed_paths.slice().sort(), 'Prepared targets differ from allowlist');
  prepared.entries.forEach((entry, index) => {
    assert.deepEqual({ path: entry.path, before: entry.before, after: entry.after, noop: entry.noop }, prepared.plan.entries[index]);
    const target = safePath(ctx.repositoryRoot, path.resolve(ctx.repositoryRoot, entry.path));
    assert.ok(ctx.allowedPaths.some(file => samePath(file, target)), 'Unapproved prepared target');
    const suffix = String(index).padStart(4, '0') + '.bin';
    assert.equal(entry.staged, 'staged/' + suffix);
    assert.equal(entry.backup, entry.before === null ? null : 'backups/' + suffix);
    for (const [name, expected] of [[entry.staged, entry.after], [entry.backup, entry.before]]) {
      if (name === null) continue;
      const stored = safePath(ctx.repositoryRoot, path.join(ctx.transactionDir, name), false);
      assert.ok(inside(ctx.transactionDir, stored), 'Backup or stage escapes transaction');
      assert.ok(matches(fs.readFileSync(stored), expected), 'Backup or staged bytes changed: ' + name);
    }
  });
  const preparedHash = digest(bytes);
  return { prepared, preparedHash, history: events(ctx, preparedHash) };
}
function checkpoint(options, name, details = {}) {
  if (options.onCheckpoint) {
    const result = options.onCheckpoint(name, details);
    assert.ok(!result || typeof result.then !== 'function', 'onCheckpoint must be synchronous');
  }
}
function replace(ctx, entry, kind, expectedCurrent, operation) {
  const file = path.resolve(ctx.repositoryRoot, entry.path);
  const stored = path.join(ctx.transactionDir, kind === 'after' ? entry.staged : entry.backup);
  const expectedBytes = kind === 'after' ? entry.after : entry.before;
  const bytes = fs.readFileSync(stored);
  assert.ok(matches(bytes, expectedBytes), 'Immutable replacement bytes drifted');
  mkdirChecked(ctx, path.dirname(file));
  const work = path.join(ctx.transactionDir, 'work', crypto.randomUUID() + '.bin');
  mkdirChecked(ctx, path.dirname(work));
  durableNew(work, bytes);
  append(ctx, operation.preparedHash, kind === 'after' ? 'applying' : 'restoring', { path: entry.path, work: relative(ctx.transactionDir, work) });
  expectCurrent(ctx, file, expectedCurrent, 'Pre-replacement drift');
  // Both paths are in the same non-symlink repository tree. EXDEV fails safely.
  fs.renameSync(work, file);
  if (operation.onRenamed) operation.onRenamed();
  expectCurrent(ctx, file, expectedBytes, 'Replacement verification failed');
}
function inferOwnership(ctx, preparedHash) {
  const owned = new Set();
  for (const { value } of events(ctx, preparedHash)) {
    if (!value.path) continue;
    if (value.status === 'applied') owned.add(value.path);
    if (value.status === 'restored') owned.delete(value.path);
    if (value.status === 'applying' || value.status === 'restoring') {
      assert.match(value.work, /^work\/[0-9a-f-]+\.bin$/);
      const work = safePath(ctx.repositoryRoot, path.join(ctx.transactionDir, value.work));
      if (!exists(work)) {
        if (value.status === 'applying') owned.add(value.path);
        else owned.delete(value.path);
      }
    }
    if (value.status === 'removing') {
      assert.match(value.retired, /^retired\/[0-9a-f-]+\.bin$/);
      if (exists(safePath(ctx.repositoryRoot, path.join(ctx.transactionDir, value.retired)))) owned.delete(value.path);
    }
  }
  return owned;
}
function rollback(ctx, loaded, cause, knownOwnership) {
  const { prepared, preparedHash } = loaded;
  const owned = knownOwnership || inferOwnership(ctx, preparedHash);
  append(ctx, preparedHash, 'rollback-started', { cause });
  const restored = [], untouched = [], conflicts = [];
  for (const entry of [...prepared.entries].reverse()) {
    const file = path.resolve(ctx.repositoryRoot, entry.path);
    try {
      const bytes = current(ctx, file);
      if (entry.noop) { untouched.push({ path: entry.path, reason: 'planned-noop' }); continue; }
      if (matches(bytes, entry.before)) { untouched.push({ path: entry.path, reason: 'already-before' }); continue; }
      if (!owned.has(entry.path)) { conflicts.push({ path: entry.path, reason: 'The helper has no completed replacement for these current bytes; preserved unchanged.' }); continue; }
      if (!matches(bytes, entry.after)) { conflicts.push({ path: entry.path, reason: 'Current bytes match neither the before nor after commitment; preserved unchanged.' }); continue; }
      if (entry.before === null) {
        const retired = path.join(ctx.transactionDir, 'retired', crypto.randomUUID() + '.bin');
        mkdirChecked(ctx, path.dirname(retired));
        append(ctx, preparedHash, 'removing', { path: entry.path, retired: relative(ctx.transactionDir, retired) });
        expectCurrent(ctx, file, entry.after, 'Pre-removal drift');
        fs.renameSync(file, retired);
        owned.delete(entry.path);
      } else replace(ctx, entry, 'before', entry.after, { preparedHash, onRenamed: () => owned.delete(entry.path) });
      restored.push(entry.path);
      append(ctx, preparedHash, 'restored', { path: entry.path });
    } catch (error) { conflicts.push({ path: entry.path, reason: error.message }); }
  }
  const status = conflicts.length ? 'recovery-required' : 'rolled-back';
  const final = append(ctx, preparedHash, status, { restored, untouched, conflicts, directory_policy: 'All directories are retained conservatively; unrelated bytes are never restored or deleted.' });
  return { status, committed: false, planSha256: prepared.plan_sha256, preparedSha256: preparedHash, transactionDir: ctx.transactionDir, state: final, restored, untouched, conflicts };
}
function commitTransaction(options) {
  const ctx = context(options), plan = planFor(options, ctx);
  assert.ok(!exists(ctx.transactionDir), 'Use a fresh transaction directory; recover an existing one explicitly');
  let lock, loaded, committed = false;
  const owned = new Set();
  try {
    lock = acquire(ctx, false);
    for (let i = 0; i < plan.changes.length; i++) expectCurrent(ctx, plan.changes[i].path, plan.descriptor.entries[i].before, 'Preparation preimage drift');
    fs.mkdirSync(ctx.transactionDir);
    artifact(ctx, 'intent.json', { schema: VERSION, plan: plan.descriptor, plan_sha256: plan.planSha256, created_at: new Date().toISOString() });
    const entries = plan.descriptor.entries.map((entry, index) => {
      const suffix = String(index).padStart(4, '0') + '.bin', staged = 'staged/' + suffix, backup = entry.before === null ? null : 'backups/' + suffix;
      if (backup) artifact(ctx, backup, plan.changes[index].before);
      artifact(ctx, staged, plan.changes[index].after);
      return { ...entry, backup, staged };
    });
    checkpoint(options, 'staged', { transactionDir: ctx.transactionDir, planSha256: plan.planSha256 });
    for (let i = 0; i < plan.changes.length; i++) expectCurrent(ctx, plan.changes[i].path, entries[i].before, 'Pre-preparation drift');
    artifact(ctx, 'prepared.json', { schema: VERSION, plan: plan.descriptor, plan_sha256: plan.planSha256, entries, prepared_at: new Date().toISOString(), durability: 'File contents are fsynced; this is process-interruption recovery, not a power-loss or multi-file atomicity guarantee.' });
    loaded = loadPrepared(ctx, plan.planSha256);
    append(ctx, loaded.preparedHash, 'prepared');
    checkpoint(options, 'prepared', { transactionDir: ctx.transactionDir, planSha256: plan.planSha256, preparedSha256: loaded.preparedHash });
    for (let index = 0; index < entries.length; index++) {
      const entry = entries[index], file = plan.changes[index].path;
      checkpoint(options, 'before-write', { index, path: file, noop: entry.noop });
      expectCurrent(ctx, file, entry.before, 'Pre-commit drift');
      if (!entry.noop) replace(ctx, entry, 'after', entry.before, { preparedHash: loaded.preparedHash, onRenamed: () => { owned.add(entry.path); checkpoint(options, 'after-replace', { index, path: file }); } });
      append(ctx, loaded.preparedHash, entry.noop ? 'noop' : 'applied', { index, path: entry.path });
      checkpoint(options, 'after-write', { index, path: file, noop: entry.noop });
    }
    checkpoint(options, 'before-verify');
    for (const entry of entries) expectCurrent(ctx, path.resolve(ctx.repositoryRoot, entry.path), entry.after, 'Post-write drift');
    if (options.verify) {
      const result = options.verify();
      assert.ok(!result || typeof result.then !== 'function', 'verify must be synchronous');
    }
    checkpoint(options, 'after-verify');
    for (const entry of entries) expectCurrent(ctx, path.resolve(ctx.repositoryRoot, entry.path), entry.after, 'Post-verification drift');
    const final = append(ctx, loaded.preparedHash, 'committed', { targets: entries.map(entry => ({ path: entry.path, ...entry.after, noop: entry.noop })) });
    committed = true;
    return { status: 'committed', committed: true, planSha256: plan.planSha256, preparedSha256: loaded.preparedHash, transactionDir: ctx.transactionDir, state: final };
  } catch (cause) {
    let result = { status: 'not-prepared', committed: false, planSha256: plan.planSha256, transactionDir: ctx.transactionDir, conflicts: [] };
    if (loaded && !committed) {
      try { result = rollback(ctx, loaded, cause.message, owned); }
      catch (rollbackError) { result = { ...result, status: 'recovery-required', conflicts: [{ reason: rollbackError.message }] }; }
    }
    const error = new Error('Transaction failed (' + result.status + '): ' + cause.message, { cause });
    error.transactionResult = result;
    throw error;
  } finally { release(ctx, lock); }
}
function recoverTransaction(options) {
  const ctx = context(options);
  assert.ok(exists(ctx.transactionDir), 'Missing transaction directory');
  assert.ok(fs.lstatSync(ctx.transactionDir).isDirectory(), 'Transaction path must be a directory');
  let lock;
  try {
    lock = acquire(ctx, true);
    if (!exists(path.join(ctx.transactionDir, 'prepared.json'))) {
      // No target mutation is possible before the complete prepared journal is published.
      return { status: 'not-prepared', committed: false, transactionDir: ctx.transactionDir, targetFilesMutated: false };
    }
    const loaded = loadPrepared(ctx, options.expectedPlanSha256);
    const terminal = loaded.history.at(-1)?.value.status;
    if (terminal === 'committed' || terminal === 'rolled-back') return { status: terminal, committed: terminal === 'committed', planSha256: loaded.prepared.plan_sha256, preparedSha256: loaded.preparedHash, transactionDir: ctx.transactionDir, recovered: false, targetFilesMutated: false };
    return { ...rollback(ctx, loaded, 'Explicit interrupted-transaction recovery'), recovered: true };
  } finally { release(ctx, lock); }
}
module.exports = { commitTransaction, recoverTransaction, describePlan };
