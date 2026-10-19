'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const base = __dirname, root = path.resolve(base, '../../..'), attempt = path.join(base, 'attempt-001');
const project = path.join(attempt, 'project'), web = path.join(attempt, 'web');
const hash = raw => crypto.createHash('sha256').update(raw).digest('hex');
const json = value => JSON.stringify(value, null, 2) + '\n';
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
function contained(file) {
  const resolved = path.resolve(file), fold = value => process.platform === 'win32' ? value.toLowerCase() : value;
  if (!fold(resolved).startsWith(fold(base) + path.sep)) throw Error('Output must remain inside this fixture directory: ' + file);
  return resolved;
}
function write(file, value) {
  file = contained(file); fs.mkdirSync(path.dirname(file), {recursive:true});
  fs.writeFileSync(file, value, {flag:'wx'});
}
function binding(file, relative = path.relative(base, file).replaceAll('\\','/')) {
  const raw = fs.readFileSync(file); return {path:relative,bytes:raw.length,sha256:hash(raw)};
}
function assertReferences() {
  const references = read(path.join(base, 'source-references.json'));
  for (const row of references.files) {
    const observed = binding(path.join(root, row.path), row.path);
    if (JSON.stringify(observed) !== JSON.stringify(row)) throw Error('Source reference drift: ' + row.path);
  }
  return references;
}
function assertBindings(directory, rows) {
  for (const row of rows) {
    const current = binding(path.join(directory, row.path), row.path);
    if (current.bytes !== row.bytes || current.sha256 !== row.sha256) throw Error('Copied input drift: ' + row.path);
  }
}
function assertHarness() {
  const inventory = read(path.join(base, 'inventory.json'));
  if (inventory.status !== 'frozen_unexecuted_candidate' || !Array.isArray(inventory.files)) {
    throw Error('The fixture harness has not been frozen for review.');
  }
  assertBindings(base, inventory.files);
  return binding(path.join(base, 'inventory.json'));
}
module.exports = {fs,path,base,root,attempt,project,web,hash,json,read,write,binding,contained,assertReferences,assertBindings,assertHarness};

