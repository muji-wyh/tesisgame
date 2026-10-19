'use strict';
// Root-dispatched file copy only. This does not prepare a project or run Godot, a browser, or tests.
const assert = require('node:assert/strict');
const c = require('./common.cjs');
const {fs,path,base,root,attempt,web,json,read,write,binding,assertReferences,assertHarness} = c;
const {inheritedBase,regularFile,assertInherited,assertShellOutputs} = require('./supplement.cjs');
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const harness = assertHarness(), inherited = assertInherited();
assertReferences();
assert(!fs.existsSync(attempt),'Preserve the consumed supplement attempt. Create a fresh revision instead.');
fs.mkdirSync(attempt);
const started = new Date().toISOString();
write(path.join(attempt,'materialize-start.json'),json({schema:1,started_at:started,
  stage:'copy_existing_export_and_change_shell_resize_policy',harness_inventory:harness,
  inherited_export_receipt:inherited.export_receipt,inherited_inputs:inherited.inherited_inputs}));
try {
  const proposal = read(path.join(base,'proposal.json'));
  for (const row of inherited.exported.outputs) {
    const source = regularFile(path.join(inheritedBase,'attempt-001/web'),row.path);
    const raw = fs.readFileSync(row.path === 'index.html' ? path.join(base,'shell-after.html') : source);
    write(path.join(web,row.path),raw);
  }
  const outputs = proposal.planned_outputs.map(row => binding(path.join(web,row.path),row.path));
  assertShellOutputs(outputs);
  assertReferences(); assertHarness(); assertInherited();
  const receipt = {schema:1,ok:true,started_at:started,finished_at:new Date().toISOString(),
    stage:'copy_existing_export_and_change_shell_resize_policy',harness_inventory:harness,
    inherited_export_receipt:inherited.export_receipt,inherited_inputs:inherited.inherited_inputs,
    shell_change:proposal.shell_change,changed_outputs:['index.html'],outputs,
    inherited_inputs_unchanged:true,export_performed:false,preparation_performed:false,
    native_proof_replayed:false,browser_dispatched:false,
    scope:'Copy the reviewed r04 actual Web export; change only the shell canvas resize policy from 2 to 1. This is not a new export or runtime result.'};
  const receiptPath = path.join(attempt,'shell-supplement.json');
  write(receiptPath,json(receipt));
  process.stdout.write(json({ok:true,receipt:binding(receiptPath)}));
} catch(error) {
  write(path.join(attempt,'materialize-failure.json'),json({schema:1,ok:false,started_at:started,
    finished_at:new Date().toISOString(),error:error.stack||String(error),harness_inventory:harness,
    inherited_export_receipt:inherited.export_receipt,inherited_inputs:inherited.inherited_inputs}));
  process.stderr.write((error.stack||String(error))+'\n');
  process.exitCode=1;
}
