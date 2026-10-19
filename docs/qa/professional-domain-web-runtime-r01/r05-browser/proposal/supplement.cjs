'use strict';
const assert = require('node:assert/strict');
const c = require('./common.cjs');
const {fs,path,base,root,web,read,binding,hash,assertBindings} = c;
const inheritedBase = path.join(root,'build/professional-english/domain-runtime-web-fixture-r04');
function regularFile(directory, relative) {
  assert(typeof relative === 'string' && relative.length > 0 && !relative.includes('\\'));
  assert(!path.posix.isAbsolute(relative) && !relative.split('/').some(part => !part || part === '.' || part === '..'));
  const file = path.join(directory,relative), stat = fs.lstatSync(file);
  assert(stat.isFile() && !stat.isSymbolicLink(), 'Expected a regular immutable input: ' + relative);
  return file;
}
function assertInherited() {
  const inputs = read(path.join(base,'inherited-inputs.json'));
  for (const row of inputs.files) regularFile(root,row.path);
  assertBindings(root,inputs.files);
  const exported = read(path.join(inheritedBase,'attempt-001/export-receipt.json'));
  assert.equal(exported.ok,true);
  assertBindings(inheritedBase,[exported.harness_inventory,exported.preparation]);
  assertBindings(inheritedBase,read(path.join(inheritedBase,'inventory.json')).files);
  assertBindings(path.join(inheritedBase,'attempt-001/web'),exported.outputs);
  const exportFile = path.join(inheritedBase,'attempt-001/export-receipt.json');
  return {exported,export_receipt:binding(exportFile,path.relative(root,exportFile).replaceAll('\\','/')),
    inherited_inputs:binding(path.join(base,'inherited-inputs.json'))};
}
function assertShellOutputs(rows) {
  const proposal = read(path.join(base,'proposal.json'));
  assert.deepEqual(rows,proposal.planned_outputs);
  for (const row of rows) regularFile(web,row.path);
  assertBindings(web,rows);
  const before = fs.readFileSync(path.join(inheritedBase,'attempt-001/web/index.html'));
  const after = fs.readFileSync(path.join(web,'index.html'));
  assert.equal(before.length,after.length);
  const changed = [];
  for (let index=0;index<before.length;index++) if (before[index]!==after[index]) changed.push(index);
  assert.deepEqual(changed,[proposal.shell_change.byte_offset]);
  assert.equal(before[changed[0]],'2'.charCodeAt(0));
  assert.equal(after[changed[0]],'1'.charCodeAt(0));
  assert.equal(hash(after),proposal.shell_change.after.sha256);
  assert(after.equals(fs.readFileSync(path.join(base,'shell-after.html'))));
  return proposal;
}
function assertShellReceipt(receipt,inherited,harness) {
  assert.equal(receipt.schema,1);
  assert.equal(receipt.ok,true);
  assert.equal(receipt.stage,'copy_existing_export_and_change_shell_resize_policy');
  assert.equal(receipt.export_performed,false);
  assert.equal(receipt.preparation_performed,false);
  assert.equal(receipt.native_proof_replayed,false);
  assert.equal(receipt.browser_dispatched,false);
  assert.equal(receipt.inherited_inputs_unchanged,true);
  assert.deepEqual(receipt.harness_inventory,harness);
  assert.deepEqual(receipt.inherited_export_receipt,inherited.export_receipt);
  assert.deepEqual(receipt.inherited_inputs,inherited.inherited_inputs);
  assert.deepEqual(receipt.changed_outputs,['index.html']);
  assertShellOutputs(receipt.outputs);
}
module.exports = {inheritedBase,regularFile,assertInherited,assertShellOutputs,assertShellReceipt};
