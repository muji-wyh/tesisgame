'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function resolveTarget(repositoryRoot, relativePath) {
  assert.equal(typeof relativePath, 'string');
  assert.equal(relativePath.includes('\\'), false, 'Use repository-relative forward-slash paths');
  assert.equal(path.isAbsolute(relativePath), false);
  const root = path.resolve(repositoryRoot), target = path.resolve(root, relativePath);
  const relative = path.relative(root, target);
  assert.ok(relative && relative !== '..' && !relative.startsWith('..' + path.sep) && !path.isAbsolute(relative));
  assert.equal(relative.replaceAll('\\', '/'), relativePath, 'Target path must be canonical');
  return target;
}
function observedBytes(repositoryRoot, relativePath) {
  const target = resolveTarget(repositoryRoot, relativePath);
  if (!fs.existsSync(target)) return null;
  const stats = fs.lstatSync(target);
  assert.ok(stats.isFile() && !stats.isSymbolicLink(), 'Existing target must be a regular file: ' + relativePath);
  return fs.readFileSync(target);
}
function makeChanges({repositoryRoot, artifacts, expectedPreimages}) {
  assert.equal(new Set(artifacts.map(item => item.path)).size, artifacts.length, 'Duplicate transaction target');
  assert.deepEqual(Object.keys(expectedPreimages).sort(), artifacts.map(item => item.path).sort(), 'Exact planned preimage membership');
  return artifacts.map(artifact => {
    resolveTarget(repositoryRoot, artifact.path);
    assert.ok(Buffer.isBuffer(artifact.after), 'Planned output must be an exact Buffer');
    assert.ok(['replace', 'create', 'immutable'].includes(artifact.policy));
    const before = observedBytes(repositoryRoot, artifact.path), beforeSha = before === null ? null : sha256(before);
    assert.equal(beforeSha, expectedPreimages[artifact.path], 'Target changed since baseline binding: ' + artifact.path);
    if (artifact.policy === 'replace') assert.notEqual(before, null, 'Replacement must have a frozen preimage');
    else if (artifact.policy === 'create') assert.equal(before, null, 'One-shot output must be absent: ' + artifact.path);
    else if (before !== null) assert.ok(before.equals(artifact.after), 'Existing immutable file differs from exact approved bytes: ' + artifact.path);
    return {path: artifact.path, before, after: Buffer.from(artifact.after)};
  });
}
function verifyChanges(repositoryRoot, changes, phase) {
  assert.ok(['before', 'after'].includes(phase));
  for (const change of changes) {
    const expected = change[phase], actual = observedBytes(repositoryRoot, change.path);
    if (expected === null) assert.equal(actual, null, 'Expected absent ' + phase + ': ' + change.path);
    else assert.ok(actual !== null && actual.equals(expected), 'Exact ' + phase + ' bytes required: ' + change.path);
  }
}
function trustedChanges({repositoryRoot, artifacts, expectedPreimages, replacementPreimages}) {
  assert.equal(new Set(artifacts.map(item => item.path)).size, artifacts.length);
  assert.deepEqual(Object.keys(expectedPreimages).sort(), artifacts.map(item => item.path).sort());
  return artifacts.map(artifact => {
    resolveTarget(repositoryRoot, artifact.path);
    assert.ok(Buffer.isBuffer(artifact.after));
    assert.ok(['replace', 'create', 'immutable'].includes(artifact.policy));
    const expected = expectedPreimages[artifact.path];
    let before = null;
    if (artifact.policy === 'replace') {
      assert.ok(Buffer.isBuffer(replacementPreimages[artifact.path]));
      before = Buffer.from(replacementPreimages[artifact.path]);
      assert.equal(sha256(before), expected, 'Frozen raw replacement preimage');
    } else if (artifact.policy === 'create') assert.equal(expected, null);
    else if (expected !== null) {
      assert.equal(sha256(artifact.after), expected, 'Pre-existing immutable bytes must equal exact planned bytes');
      before = Buffer.from(artifact.after);
    }
    return {path: artifact.path, before, after: Buffer.from(artifact.after)};
  });
}
module.exports = {sha256, resolveTarget, observedBytes, makeChanges, verifyChanges, trustedChanges};
