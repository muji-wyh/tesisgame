'use strict';
// Scratch-only helpers; requiring this file does not dispatch a test or renderer.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict');
const here = __dirname, root = path.resolve(here, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const relative = file => path.relative(root, file).replaceAll('\\', '/');
const resolve = rel => {
  assert.equal(typeof rel, 'string');
  assert(!path.isAbsolute(rel) && !rel.includes('\\') && !rel.split('/').some(part => part === '..' || part === ''), rel);
  const file = path.resolve(root, rel);
  assert(file.toLowerCase().startsWith(root.toLowerCase() + path.sep), rel);
  return file;
};
const raw = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const write = (file, value) => fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n', {flag: 'wx'});
function scan(directory, result = {}) {
  for (const entry of fs.readdirSync(directory, {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name))) {
    assert(!entry.isSymbolicLink(), 'No symbolic input traversal: ' + entry.name);
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) scan(file, result);
    else { assert(entry.isFile()); result[relative(file)] = raw(file); }
  }
  return result;
}
const protectedDirectories = ['data', 'scripts', 'scenes', 'tests', 'professional-media', 'assets/fonts', 'tools', 'web'];
const protectedFiles = ['project.godot', 'export_presets.cfg', 'package.json'];
function production() {
  const files = {};
  for (const rel of protectedDirectories) scan(resolve(rel), files);
  for (const rel of protectedFiles) files[rel] = raw(resolve(rel));
  return files;
}
function verifyHashes(hashes) {
  assert(hashes && Object.keys(hashes).length > 0);
  for (const [rel, hash] of Object.entries(hashes)) assert.equal(raw(resolve(rel)), hash, rel);
}
function inventory(directory, expectedHash) {
  const file = path.join(directory, 'inventory.json');
  assert.match(expectedHash, /^[0-9a-f]{64}$/);
  assert.equal(raw(file), expectedHash);
  const value = read(file), listed = {};
  assert.equal(value.inventory_excludes_itself, true);
  for (const item of value.files) {
    const full = resolve(relative(directory) + '/' + item.path);
    assert.equal(fs.statSync(full).size, item.bytes, item.path);
    assert.equal(raw(full), item.sha256, item.path);
    assert(!Object.hasOwn(listed, relative(full)), 'Duplicate inventory path');
    listed[relative(full)] = item.sha256;
  }
  listed[relative(file)] = expectedHash;
  assert.deepEqual(scan(directory), listed, 'Inventory must cover the exact directory tree');
  return listed;
}
function pngResource(file, expected) {
  const bytes = fs.readFileSync(file), digest = raw(file);
  assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  assert.equal(bytes.subarray(12, 16).toString('ascii'), 'IHDR');
  assert.equal(bytes[24], 8, 'PNG bit depth');
  assert.equal(bytes[25], 6, 'PNG RGBA color type');
  const width = bytes.readUInt32BE(16), height = bytes.readUInt32BE(20);
  assert.deepEqual({sha256: digest, bytes: bytes.length, width, height}, expected);
  assert(bytes.length <= 10 * 1024 * 1024 && width * height * 8 <= 32 * 1024 * 1024);
  return {id: 'sha256:' + digest, sha256: digest, path: 'professional-media/' + digest + '.png',
    kind: 'image', format: 'png', compressed_bytes: bytes.length, decoded_bytes: width * height * 8, width, height};
}
module.exports = {fs, path, assert, here, root, relative, resolve, raw, read, write, scan,
  protectedDirectories, protectedFiles, production, verifyHashes, inventory, pngResource};
