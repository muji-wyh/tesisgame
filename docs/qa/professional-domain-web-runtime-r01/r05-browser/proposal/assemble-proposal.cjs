'use strict';
// Static artifact assembly only. Never dispatches the supplement or inherited harness.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict');
const base = __dirname, root = path.resolve(base,'../../..');
const inheritedRelative = 'build/professional-english/domain-runtime-web-fixture-r04';
const inheritedBase = path.join(root,inheritedRelative);
const hash = raw => crypto.createHash('sha256').update(raw).digest('hex');
const json = value => JSON.stringify(value,null,2)+'\n';
const read = file => JSON.parse(fs.readFileSync(file,'utf8'));
const bind = (file,relative) => { const raw=fs.readFileSync(file); return {path:relative,bytes:raw.length,sha256:hash(raw)}; };
const write = (relative,raw) => fs.writeFileSync(path.join(base,relative),raw,{flag:'wx'});
const started = new Date().toISOString();
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert(!fs.existsSync(path.join(base,'attempt-001')));
write('assembly-start.json',json({schema:1,started_at:started,stage:'static_proposal_assembly_only',
  source:bind(__filename,'assemble-proposal.cjs'),no_harness_dispatch:true}));
try {
  const expected = {
    'inventory.json':'3014a945f6da95c09cf9e885f170184d467a51fae3dfb855047b124743732e36',
    'source-references.json':'549140e0cb645496c3ba1c5b9b1e5e5474dfff65d0c22eec9cbb041297927b46',
    'attempt-001/preparation.json':'8ffbd226d6a95332723c04ffbf02e2ebfedd0cb4ffb0fe6922c85bf97d069800',
    'attempt-001/export-receipt.json':'6af2c3e988b0cec313f8ff73d51d2416618d4cca3ca5302b7a0e8d3198c452bb',
    'browser.cjs':'275de78a9848f12aea3f4f2fa1536407ab6f19078cfa36e20c2699c57eaf2e87',
    'attempt-001/web/index.html':'49d50d73655a10c8ce93045d2d491e0740d31837742032bc690989dd879b5177',
    'attempt-001/web/index.js':'3e39bb03d73bdfbf927ffb0b58d4a07ef3359c436ae6dca9add84076865cebaf'
  };
  for (const [relative,sha256] of Object.entries(expected)) assert.equal(hash(fs.readFileSync(path.join(inheritedBase,relative))),sha256,relative);
  const inheritedInventory = read(path.join(inheritedBase,'inventory.json'));
  const exported = read(path.join(inheritedBase,'attempt-001/export-receipt.json'));
  assert.equal(exported.ok,true);
  assert.equal(exported.outputs.length,15);
  for (const row of inheritedInventory.files) assert.deepEqual(bind(path.join(inheritedBase,row.path),row.path),row);
  for (const row of exported.outputs) assert.deepEqual(bind(path.join(inheritedBase,'attempt-001/web',row.path),row.path),row);
  const references = read(path.join(inheritedBase,'source-references.json'));
  for (const row of references.files) assert.deepEqual(bind(path.join(root,row.path),row.path),row);
  const failure = read(path.join(inheritedBase,'attempt-001/browser/receipt.json'));
  assert.equal(failure.ok,false);
  assert(failure.error.includes('page.click: Timeout 30000ms exceeded'));
  assert(failure.error.includes('intercepts pointer events'));
  assert.equal(failure.observations.length,1);
  assert.equal(failure.observations[0].label,'boot:idle');
  const engine = fs.readFileSync(path.join(inheritedBase,'attempt-001/web/index.js'),'utf8');
  const setup = 'switch(GodotConfig.canvas_resize_policy){case 0:GodotDisplayScreen.desired_size=[canvas.width,canvas.height];break;case 1:GodotDisplayScreen.desired_size=[p_width,p_height];break;default:canvas.style.position="absolute";canvas.style.top=0;canvas.style.left=0;break}';
  const sizing = 'if(isFullscreen||wantsFullWindow){width=Math.floor(window.innerWidth*scale);height=Math.floor(window.innerHeight*scale)}';
  assert(engine.includes(setup)); assert(engine.includes(sizing));
  const before = fs.readFileSync(path.join(inheritedBase,'attempt-001/web/index.html'));
  const sourceHtml = before.toString('utf8'), anchor = '"canvasResizePolicy":2';
  assert.equal(sourceHtml.split(anchor).length,2);
  const after = Buffer.from(sourceHtml.replace(anchor,'"canvasResizePolicy":1'));
  const difference = [];
  assert.equal(before.length,after.length);
  for (let index=0;index<before.length;index++) if (before[index]!==after[index]) difference.push(index);
  assert.equal(difference.length,1);
  write('shell-after.html',after);
  write('common.cjs',fs.readFileSync(path.join(inheritedBase,'common.cjs')));
  write('source-references.json',fs.readFileSync(path.join(inheritedBase,'source-references.json')));
  const inputs = new Set(Object.keys(expected).map(relative=>inheritedRelative+'/'+relative));
  for (const row of inheritedInventory.files) inputs.add(inheritedRelative+'/'+row.path);
  for (const row of exported.outputs) inputs.add(inheritedRelative+'/attempt-001/web/'+row.path);
  for (const relative of ['attempt-001/browser/receipt.json','attempt-001/browser/console.json','attempt-001/browser/failure.png','attempt-001/project/project.godot']) inputs.add(inheritedRelative+'/'+relative);
  for (const relative of [
    'build/professional-english/domain-runtime-web-root-r04/browser/receipt.json',
    'build/professional-english/domain-runtime-web-root-r04/browser/execution.log',
    'docs/qa/professional-domain-web-runtime-r01/r04-export-review/review.json',
    'docs/qa/professional-domain-web-runtime-r01/r04-export-review/inventory.json',
    'docs/qa/professional-domain-web-runtime-r01/r04-export-review/inspection-r04.json'
  ]) inputs.add(relative);
  const inheritedInputs = {schema:1,status:'exact_inherited_r04_inputs_for_browser_only_supplement',captured_at:started,
    root_relative:true,files:[...inputs].sort().map(relative=>bind(path.join(root,relative),relative))};
  write('inherited-inputs.json',json(inheritedInputs));
  const originalBrowser = fs.readFileSync(path.join(inheritedBase,'browser.cjs'),'utf8');
  const boundary = 'const requests = [], messages = [], pageErrors = [], observations = [];';
  assert.equal(originalBrowser.split(boundary).length,2);
  const originalTail = originalBrowser.slice(originalBrowser.indexOf(boundary));
  const receiptAnchor = 'harness_inventory:harness,export_receipt:exportBinding,';
  assert.equal(originalTail.split(receiptAnchor).length,3);
  const receiptAfter = receiptAnchor+'shell_supplement_receipt:supplementBinding,inherited_inputs:inherited.inherited_inputs,';
  const finalChecks = '    assertReferences(); assertHarness(); assertBindings(web,exported.outputs);';
  assert.equal(originalTail.split(finalChecks).length,2);
  const extraChecks = '\n    assertInherited(); assertShellReceipt(supplement,inherited,harness);';
  const newTail = originalTail.replaceAll(receiptAnchor,receiptAfter).replace(finalChecks,finalChecks+extraChecks);
  assert.equal(newTail.replaceAll(receiptAfter,receiptAnchor).replace(extraChecks,''),originalTail);
  const prelude = `'use strict';
// Browser-only supplement of the reviewed r04 export. Scenario and assertions are inherited unchanged.
const assert = require('node:assert/strict'), http = require('node:http');
const c = require('./common.cjs');
const {fs,path,base,root,attempt,web,json,read,write,binding,assertReferences,assertBindings,assertHarness} = c;
const {assertInherited,assertShellReceipt} = require('./supplement.cjs');
const harness = assertHarness(), inherited = assertInherited();
const supplement = read(path.join(attempt,'shell-supplement.json'));
assertShellReceipt(supplement,inherited,harness);
// This in-memory view keeps the original audited release and binds the separately copied shell outputs.
const exported = {...inherited.exported,outputs:supplement.outputs};
if (!exported.ok) throw Error('The isolated export and actual raw-PCK proof must pass first.');
const exportBinding = inherited.export_receipt;
const supplementBinding = binding(path.join(attempt,'shell-supplement.json'));
assertReferences(); assertBindings(web,exported.outputs);
const directory = path.join(attempt,'browser');
if (fs.existsSync(directory)) throw Error('Browser evidence is one-shot; preserve the previous run.');
fs.mkdirSync(directory);
const {chromium} = require(path.join(root,'node_modules/@playwright/test'));
const {validatePackProof} = require(path.join(root,'tools/professional-domain-web.cjs'));
`;
  write('browser.cjs',prelude+newTail);
  const planned = exported.outputs.map(row=>row.path==='index.html'?{path:row.path,bytes:after.length,sha256:hash(after)}:row);
  const shellChange = {file:'index.html',byte_offset:difference[0],before:{bytes:before.length,sha256:hash(before)},
    after:{bytes:after.length,sha256:hash(after)},exact_before:anchor,exact_after:'"canvasResizePolicy":1',changed_bytes:1};
  const proposal = {schema:1,status:'frozen_unexecuted_browser_only_supplement',created_at:started,
    reason:'The actual r04 boot and pack proof passed; the first accessible cold button click timed out because the full-window canvas covered the controls.',
    inherited_fixture:inheritedRelative,inherited_export_receipt:bind(path.join(inheritedBase,'attempt-001/export-receipt.json'),inheritedRelative+'/attempt-001/export-receipt.json'),
    inherited_browser_failure:bind(path.join(inheritedBase,'attempt-001/browser/receipt.json'),inheritedRelative+'/attempt-001/browser/receipt.json'),
    shell_change:shellChange,planned_outputs:planned,
    diagnosis:{engine_setup:setup,engine_size_update:sizing,policy_1:'Uses the project viewport size (960 by 640) without applying absolute positioning; the existing block canvas stays after the header.',css_changed:false,real_clicks_required:true},
    browser_preservation:{source:bind(path.join(inheritedBase,'browser.cjs'),inheritedRelative+'/browser.cjs'),
      scenario_tail_sha256:hash(Buffer.from(originalTail)),scenario_tail_unchanged_after_removing_receipt_wiring_and_added_integrity_checks:true,
      original_assertions_unchanged:true,click_options_unchanged:true,forced_clicks_added:false,command_injection_added:false,
      additions:['Prelude binds inherited export and separate copied-output receipt.','Both result receipts add the shell supplement and inherited input bindings.','Success rechecks inherited inputs and copied-shell receipt.']},
    not_run:['project preparation','Godot import','Web export','native proof','browser scenario','tests'],
    preserved_scope:'Phrase-only synthetic technical fixture. No production content approval, full GameUI/six-mode completion, settlement, audibility, device performance, or heap reclamation claim.'};
  write('proposal.json',json(proposal));
  write('README.md',`# Browser-only shell supplement r05

The actual r04 Web export and native pack proof passed. Its browser run reached boot and validated the pack, then failed on its first ordinary click: the canvas intercepted the cold button. The retained engine code confirms that canvas resize policy 2 sets absolute positioning at (0, 0) and fills the browser window.

This proposal changes exactly one byte in index.html: canvasResizePolicy 2 becomes 1. Policy 1 uses the project viewport size, 960 by 640, while retaining normal document flow. Existing CSS, controls, handlers, runtime code, bridges, PCK, Wasm, sourced media, release pins and assertion bodies remain unchanged. No pointer-events override, z-index workaround, forced click, DOM-dispatched click, or direct fixture command is added.

shell-after.html is the concrete reviewable afterimage. proposal.json records its one-byte difference, exact inherited release, all 15 planned output hashes, and the browser scenario preservation check. inherited-inputs.json binds the retained export, original browser failure, frozen export review and original harness. source-references.json is copied byte-for-byte from r04. The inherited fixture and its outputs are never written.

Root reviews this frozen proposal before dispatch. Run materialize.cjs once to copy the existing 15 Web outputs into attempt-001/web and produce attempt-001/shell-supplement.json. This file copy is not a project preparation, export or native-proof replay. Inspect that receipt and output hashes, then run browser.cjs once. Root should persist its own start, command, execution log and outcome receipts for each dispatch. A consumed attempt must remain intact; any failure requires a fresh revision.

The browser uses the original audited release with the separate copied-output inventory. Its scenario, all existing assertions, and ordinary page.click calls are unchanged. Only input/receipt wiring and additional inherited-input integrity checks differ. The result receipts link both the original r04 export and this shell supplement, so a copied shell cannot be reported as a fresh export.

Only static artifact assembly has run at freeze. There is no attempt-001 directory, new export, native result or browser result yet. This remains a phrase-only synthetic technical fixture with one synthetic ready module and 199 unavailable modules. It does not grant production curriculum/asset acceptance or prove full GameUI behavior, the other modes, settlement, physical-device behavior, audibility, performance targets or heap reclamation.
`);
  for (const row of inheritedInputs.files) assert.deepEqual(bind(path.join(root,row.path),row.path),row);
  for (const row of references.files) assert.deepEqual(bind(path.join(root,row.path),row.path),row);
  assert(!fs.existsSync(path.join(base,'attempt-001')));
  write('assembly-result.json',json({schema:1,ok:true,started_at:started,finished_at:new Date().toISOString(),
    stage:'static_proposal_assembly_only',inherited_files_checked:inheritedInputs.files.length,source_refs_checked:references.files.length,
    shell_changed_bytes:1,unchanged_web_outputs:14,existing_browser_assertions_unchanged:true,
    fixture_prepared:false,web_exported:false,native_proof_run:false,browser_run:false,tests_run:false}));
  const files = fs.readdirSync(base).filter(name=>fs.statSync(path.join(base,name)).isFile()).sort();
  write('inventory.json',json({schema:1,status:'frozen_unexecuted_candidate',frozen_at:new Date().toISOString(),
    fixture:'domain-runtime-web-browser-r05',write_scope:'build/professional-english/domain-runtime-web-browser-r05/',
    files:files.map(name=>bind(path.join(base,name),name))}));
  process.stdout.write(json({ok:true,inventory:bind(path.join(base,'inventory.json'),'inventory.json'),shell_change:shellChange,
    inherited_files:inheritedInputs.files.length,source_refs:references.files.length}));
} catch(error) {
  write('assembly-failure.json',json({schema:1,ok:false,started_at:started,finished_at:new Date().toISOString(),error:error.stack||String(error)}));
  process.stderr.write((error.stack||String(error))+'\n'); process.exitCode=1;
}
