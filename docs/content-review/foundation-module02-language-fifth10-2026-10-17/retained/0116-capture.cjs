'use strict';
// Unexecuted author proposal. Built-in-only capture; no preparation or project imports.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const own = 'build/professional-english/foundation02-fifth10-root-binding-proposal-r01';
const prep = 'build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const durable = 'docs/content-review/foundation-module02-language-fifth10-2026-10-17';
const AUTHOR = '/root/recover_delivery';
const INHERITED_AUTHOR = '/root/runtime_recovery';
const DISPATCHER = '/root';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const hash = value => sha(JSON.stringify(value));
const serialize = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const clone = value => structuredClone(value);
const target = 'data/professional/lexemes/foundation-module02.json';
const sourceFile = 'data/professional/sources.json';
const bagProvenance = 'data/professional/provenance/retail-shopping-bag-image-2026-10-17.json';
const acceptedIds = ['broken.not-working.adj','urgent.needing-prompt-attention.adj','unclear.not-understandable.adj','safe.free-from-unacceptable-danger.adj','incident.workplace-event.n','concern.worrying-matter.n','solution.problem-answer.n','procedure.agreed-method.n'];
const heldIds = ['collect.gather.v','notify.inform.v','postpone.delay-until-later.v','verify.establish-accuracy.v','unsafe.presenting-danger.adj','hazard.possible-harm.n'];
const replacements = [target, sourceFile, 'tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs', 'tests/godot/professional_retail_morphology_tests.gd'];
const metadataAdditions = ['data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json', durable + '/DELIVERY.md'];

function at(relative) {
  assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
  assert.equal(typeof relative, 'string');
  assert(relative.length && !relative.includes('\\') && !path.isAbsolute(relative));
  const result = path.resolve(root, relative);
  assert.equal(path.relative(root, result).replaceAll('\\', '/'), relative);
  assert(!relative.startsWith('../'));
  return result;
}
function verifyPin(pin) {
  assert(pin && /^[a-f0-9]{64}$/.test(pin.raw_sha256));
  assert(Number.isSafeInteger(pin.bytes) && pin.bytes >= 0);
  const bytes = fs.readFileSync(at(pin.path));
  assert.equal(bytes.length, pin.bytes, pin.path);
  assert.equal(sha(bytes), pin.raw_sha256, pin.path);
  return bytes;
}
function shaValue(value, label) {assert.equal(typeof value, 'string', label);assert.match(value, /^[a-f0-9]{64}$/, label);}
function readPin(pin, read) {const bytes = read(pin.path);assert.deepEqual(bytes, verifyPin(pin));return bytes;}
function receiptRelative(value) {
  assert.equal(typeof value, 'string');
  const relative = path.isAbsolute(value) ? path.relative(root, value).replaceAll('\\', '/') : value;
  at(relative);return relative;
}
function independentReviewer(value) {
  assert.equal(typeof value, 'string', 'Named independent reviewer required');
  assert(value.length > 0 && value === value.trim(), 'Nonempty exact reviewer identity required');
  assert.match(value, /^\/root\/[a-z0-9_]+$/, 'Use the canonical independent agent identity');
  assert(![AUTHOR, INHERITED_AUTHOR, DISPATCHER].includes(value), 'Author or dispatcher cannot accept preparation');
}
function manifestRows(rows) {
  assert(Array.isArray(rows) && rows.length > 0, 'Complete committed manifest required');
  assert.equal(new Set(rows.map(row => row.path.toLowerCase())).size, rows.length, 'Duplicate committed target');
  for (const row of rows) {
    assert.deepEqual(Object.keys(row).sort(), ['after', 'before', 'noop', 'path']);at(row.path);
    assert.equal(typeof row.noop, 'boolean');
    for (const descriptor of [row.before, row.after]) {
      if (descriptor === null) {assert.notEqual(descriptor, row.after, 'Committed target must have afterimage');continue;}
      assert.deepEqual(Object.keys(descriptor).sort(), ['bytes', 'sha256']);
      assert(Number.isSafeInteger(descriptor.bytes) && descriptor.bytes >= 0);shaValue(descriptor.sha256, row.path);
    }
  }
  return rows;
}
function predecessorJournal(stage, selected, read) {
  shaValue(selected.state.sha256, 'Receipt committed-state hash');shaValue(selected.prepared_sha256, 'Receipt prepared hash');shaValue(selected.plan_sha256, 'Receipt plan hash');
  const transaction = receiptRelative(selected.transaction_dir), canonicalState = receiptRelative(selected.state.path);
  assert.equal(path.posix.dirname(canonicalState), transaction + '/states');
  assert.match(path.posix.basename(canonicalState), /^\d{6}-committed\.json$/);
  const canonicalPrepared = transaction + '/prepared.json';
  const copies = [];
  function exactJournal(key, canonical, expectedHash) {
    const pin = stage[key];assert(pin, 'Missing ' + key);assert.equal(pin.raw_sha256, expectedHash, key);
    const bytes = readPin(pin, read);
    if (pin.path !== canonical) {
      const original = read(canonical);assert.deepEqual(bytes, original, 'Durable journal copy differs from actual original');
      copies.push({kind: key, source_path: canonical, target_path: pin.path, bytes: pin.bytes, raw_sha256: expectedHash});
    }
    return JSON.parse(bytes);
  }
  const journal = exactJournal('committed_journal', canonicalState, selected.state.sha256);
  const prepared = exactJournal('prepared_journal', canonicalPrepared, selected.prepared_sha256);
  assert.deepEqual(stage.journal_copies, copies, 'Explicit exact-content journal-copy binding required; no unused aliases');
  assert.equal(journal.schema, 1);assert.equal(journal.status, 'committed');assert.equal(journal.prepared_sha256, selected.prepared_sha256);
  assert.equal(prepared.schema, 1);assert.equal(prepared.plan.schema, 1);
  assert.equal(path.resolve(prepared.plan.repository_root), root);
  assert.equal(sha(serialize(prepared.plan)), prepared.plan_sha256, 'Prepared plan bytes do not match their identity');
  assert.equal(prepared.plan_sha256, selected.plan_sha256, 'Receipt and journal plan identities differ');
  const manifest = manifestRows(prepared.plan.entries);
  if (selected.target_manifest) assert.deepEqual(manifest, selected.target_manifest, 'Receipt target manifest differs from prepared plan');
  assert.deepEqual(prepared.plan.allowed_paths, manifest.map(row => row.path).sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase())));
  assert.equal(prepared.entries.length, manifest.length);
  for (const [index, row] of prepared.entries.entries()) {
    const {path: target, before, after, noop} = row;assert.deepEqual({path: target, before, after, noop}, manifest[index]);
  }
  assert.deepEqual(journal.targets, manifest.map(row => ({path: row.path, ...row.after, noop: row.noop})), 'Committed state must contain the complete prepared manifest');
  const names = fs.readdirSync(at(transaction + '/states')).filter(name => /^\d{6}-[a-z-]+\.json$/.test(name)).sort();
  assert.equal(names.at(-1), path.posix.basename(canonicalState), 'Selected committed state is not the latest actual journal state');
  return {journal, prepared, manifest, canonicalState};
}
function successfulPredecessor(kind, stage, read) {
  assert(['fourth10', 'shopping_bag'].includes(kind));
  assert(stage && stage.root_confirmed_committed === true && stage.root_confirmed_persisted === true);
  const commit = JSON.parse(readPin(stage.committed_receipt, read));
  const persisted = JSON.parse(readPin(stage.persisted_receipt, read));
  assert.equal(commit.schema, 1);assert.equal(persisted.schema, 1);
  assert.equal(commit.status, 'committed');assert.equal(persisted.ok, true);assert.equal(persisted.error, null);
  let selected;
  if (kind === 'fourth10') {
    assert.equal(stage.receipt_schema, 'foundation02_fourth10_nested_result_v1');
    assert.equal(stage.committed_receipt.raw_sha256, '96fff4c1ac94147e99efcb8f18ff07711a5c2e53729fa07695d7d2296ae037f8');
    assert.equal(stage.persisted_receipt.raw_sha256, 'f25fbeb4fa8fafe08b0431653a5a9171d8369581aed104faad3e0161bbaf40f7');
    assert.equal(commit.result.status, 'committed');assert.equal(commit.result.committed, true);assert.equal(commit.result.state.status, 'committed');
    selected = {transaction_dir: commit.result.transactionDir, state: commit.result.state, prepared_sha256: commit.result.preparedSha256, plan_sha256: commit.result.planSha256};
    assert.equal(persisted.source_before, persisted.source_after);shaValue(persisted.source_before, 'Fourth-ten persisted source');
    assert.equal(persisted.committed_receipt.path, stage.committed_receipt.path);
    assert.equal(persisted.committed_receipt.sha256, stage.committed_receipt.raw_sha256);
    assert.equal(persisted.commands.length, 4);
  } else {
    assert.equal(stage.receipt_schema, 'shopping_bag_top_level_commit_and_persisted_input_v1');
    assert.equal(commit.committed, true);assert.equal(Object.hasOwn(commit, 'result'), false, 'Use the genuine top-level bag receipt');
    selected = {transaction_dir: commit.transaction_dir, state: commit.state, prepared_sha256: commit.prepared_sha256, plan_sha256: commit.plan_sha256, target_manifest: manifestRows(commit.target_manifest)};
    assert.equal(commit.journal.status, 'committed');assert.equal(commit.journal.prepared_sha256, commit.prepared_sha256);assert.equal(commit.journal.plan_sha256, commit.plan_sha256);
    assert.deepEqual(commit.journal.state, commit.state);assert.equal(commit.journal.verified_targets, commit.target_manifest.length);
    assert.equal(persisted.postcheck_error, null);shaValue(persisted.source_sha256, 'Bag persisted source');shaValue(persisted.input_sha256, 'Bag persisted input');
    assert.equal(stage.persisted_source.raw_sha256, persisted.source_sha256);readPin(stage.persisted_source, read);
    assert.equal(stage.persisted_input.raw_sha256, persisted.input_sha256);
    const persistedInput = JSON.parse(readPin(stage.persisted_input, read));
    assert.equal(persistedInput.status, 'root_confirmed_actual_bag_commit_for_persisted_validation');
    assert.equal(persistedInput.commit_receipt.path, stage.committed_receipt.path);assert.equal(persistedInput.commit_receipt.sha256, stage.committed_receipt.raw_sha256);
    assert.equal(persistedInput.committed_journal.path, receiptRelative(commit.state.path));assert.equal(persistedInput.committed_journal.sha256, commit.state.sha256);
    assert.equal(persistedInput.target_count, commit.target_manifest.length);
    assert.equal(persisted.commands.length, 2);assert.equal(persisted.audit.errors, 0);
    assert.deepEqual(persisted.commands.map(command => command.args), [['tools/validate-professional-content.cjs', '--json'], ['--test', 'tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs']]);
    assert(Number.isSafeInteger(persistedInput.expected_tests) && persistedInput.expected_tests > 0);
    assert.equal(persisted.tests.tests, persistedInput.expected_tests);assert.equal(persisted.tests.pass, persistedInput.expected_tests);
    for (const key of ['fail', 'cancelled', 'skipped']) assert.equal(persisted.tests[key], 0);
    for (const [key, value] of Object.entries(persistedInput.expected_audit_summary)) assert.equal(persisted.audit.summary[key], value, key);
    assert.equal(persisted.audit.summary.integrated_word_images, 9);assert.equal(persisted.audit.summary.integrated_word_audio, 12);assert.equal(persisted.audit.summary.ready_modules, 0);
    for (const row of commit.target_manifest) assert.equal(persistedInput.expected_inputs[row.path], row.after.sha256, 'Persisted input omits or changes a committed target: ' + row.path);
  }
  const {journal, prepared, manifest, canonicalState} = predecessorJournal(stage, selected, read);
  if (kind === 'shopping_bag') {
    assert(Array.isArray(stage.installed_targets), 'Complete bag installed target pins required');
    assert.equal(new Set(stage.installed_targets.map(pin => pin.path.toLowerCase())).size, stage.installed_targets.length);
    const sorted = rows => rows.slice().sort((a, b) => a.path.localeCompare(b.path));
    const complete = manifest.map(row => ({path: row.path, bytes: row.after.bytes, raw_sha256: row.after.sha256}));
    for (const pin of stage.installed_targets) assert.deepEqual(Object.keys(pin).sort(), ['bytes', 'path', 'raw_sha256']);
    assert.deepEqual(sorted(stage.installed_targets), sorted(complete), 'Installed target pins must equal the complete authoritative bag manifest');
    for (const pin of stage.installed_targets) readPin(pin, read);
  }
  assert(Array.isArray(persisted.commands) && persisted.commands.length > 0);
  for (const command of persisted.commands) {
    assert.equal(command.exit_code, 0);assert.equal(command.error, null);assert.equal(command.signal, null);
    assert.equal(typeof command.log, 'string');assert.equal(path.posix.basename(command.log), command.log);assert(!command.log.includes('\\'));
    const log = path.posix.dirname(stage.persisted_receipt.path) + '/' + command.log;
    assert.equal(sha(read(log)), command.log_sha256, log);
  }
  assert(Array.isArray(stage.success_assertions) && stage.success_assertions.length > 0);
  for (const item of stage.success_assertions) {
    assert(['commit', 'journal', 'persisted'].includes(item.document));
    const document = {commit, journal, persisted}[item.document];
    assert(Array.isArray(item.keys) && item.keys.length > 0);
    assert.deepEqual(item.keys.reduce((value, key) => value[key], document), item.expected);
  }
  return {commit, journal, prepared, persisted, manifest, canonicalState};
}


function one(rows, id) {const matches=rows.filter(row=>row.id===id);assert.equal(matches.length,1,id);return matches[0];}
function protect(entry) {
  const copy=clone(entry);for(const key of ['definition','example','difficulty','references','editorial_notes'])delete copy[key];
  for(const key of ['status','language','reviewer','reviewed_at'])delete copy.review[key];return copy;
}
function loadRegistry(ctx) {
  const resource=value=>{assert(value.startsWith('res://'));return value.slice(6);};
  const catalog=ctx.parse('data/professional/catalog.json');
  const data={catalog,themes:ctx.parse(resource(catalog.themes)).profiles,sources:ctx.parse(resource(catalog.sources)).sources,courses:[],lexemes:[],expressions:[],lexemeOrigins:{},expressionOrigins:{}};
  for(const item of catalog.courses)data.courses.push(ctx.parse(resource(item.manifest)));
  for(const [key,origin,resources]of [['lexemes','lexemeOrigins',catalog.lexeme_files],['expressions','expressionOrigins',catalog.expression_files]])for(const file of resources){
    const envelope=ctx.parse(resource(file));assert.equal(envelope.schema_version,1);assert(Array.isArray(envelope[key]));
    for(const entry of envelope[key]){assert(!Object.hasOwn(data[origin],entry.id),'Duplicate registry ID');data[key].push(entry);data[origin][entry.id]=file;}
  }
  return data;
}
function counts(data) {return {
  reviewed_status:data.lexemes.filter(entry=>entry.review.status==='reviewed').length,
  reviewed_language:data.lexemes.filter(entry=>entry.review.language==='reviewed').length,
  foundation02_language:data.lexemes.filter(entry=>data.lexemeOrigins[entry.id]==='res://'+target&&entry.review.language==='reviewed').length,
  sources:data.sources.length,lexemes:data.lexemes.length,expressions:data.expressions.length,
  images:data.lexemes.filter(entry=>entry.media.image.status==='integrated').length,
  audio:data.lexemes.filter(entry=>entry.media.audio.status==='integrated').length,
  ready_modules:data.courses.flatMap(course=>course.modules).filter(module=>module.status==='ready').length
};}
function checkContext(data, context) {
  for(const row of context.whole_entry_holds){assert.deepEqual(one(data.lexemes,row.id),row.before_entry);assert.equal(hash(row.before_entry),row.entry_json_sha256);}
  for(const row of context.groups.related_entry_boundaries){assert.deepEqual(one(data.lexemes,row.id),row.before_entry);assert.equal(hash(row.before_entry),row.entry_json_sha256);}
  for(const group of ['containing_module_expressions','expression_uses','derivative_expression_uses','focus_expressions','inherited_expression_holds','additional_foundation02_preservation'])for(const row of context.groups[group]){
    assert.deepEqual(one(data.expressions,row.id),row.before_entry);assert.equal(hash(row.before_entry),row.entry_json_sha256||row.before_entry_json_sha256);
  }
  for(const row of context.groups.containing_modules){const module=one(one(data.courses,row.course_id).modules,row.module_id);assert.deepEqual(module,row.before_entry);assert.equal(hash(module),row.module_json_sha256);}
  for(const row of context.groups.selected_memberships)assert.equal(one(one(data.courses,row.course_id).modules,row.module_id).lexeme_ids[row.index],row.lexeme_id);
  const selectedIds=new Set(context.groups.selected_memberships.map(row=>row.lexeme_id));
  const actualMemberships=[];
  for(const course of data.courses)for(const module of course.modules)for(const [index,id]of module.lexeme_ids.entries())if(selectedIds.has(id))actualMemberships.push({course_id:course.id,module_id:module.id,index,lexeme_id:id});
  const canonical=rows=>rows.map(row=>JSON.stringify(row)).sort();
  assert.deepEqual(canonical(actualMemberships),canonical(context.groups.selected_memberships));
  const mismatch=context.complete_existing_form_scope_mismatch;assert.deepEqual(one(data.lexemes,mismatch.id),mismatch.before_entry);
  for(const row of context.pending_domain_expressions){const entry=one(data.expressions,row.id);assert.equal(hash(entry),row.preimage_sha256);assert.equal(entry.review.domain,row.domain_before);}
}


function inspectAndProject(ctx) {
  const immutablePackets=[
    ['build/professional-english/foundation02-fifth10-delivery-proposal-r01','0e806ef501bbd9e90b1a026857292f13c40e96a5a53906a2ec476800f8b71db9'],
    ['build/professional-english/foundation02-fifth10-proposal-review-r01','b357729273451d34436cb6ea3ec4f81b943594f9c875938c6d83400f4b6c2ebf']
  ];
  const requiredImmutableSources=[];
  for(const [directory,expected]of immutablePackets){
    const filename=directory+'/inventory.json';assert.equal(sha(ctx.read(filename)),expected);requiredImmutableSources.push(filename);
    for(const row of ctx.parse(filename).artifacts){const relative=directory+'/'+row.path,bytes=ctx.read(relative);assert.equal(bytes.length,row.bytes);assert.equal(sha(bytes),row.raw_sha256||row.sha256);requiredImmutableSources.push(relative);}
  }
  const evidencePath=immutablePackets[0][0]+'/evidence-pins.json',evidence=ctx.parse(evidencePath);
  for(const pin of [...evidence.evidence,...evidence.history_files]){const bytes=ctx.read(pin.path);assert.equal(bytes.length,pin.bytes);assert.equal(sha(bytes),pin.raw_sha256);}
  const contractPath=prep+'/accepted-contract.json',contextPath=prep+'/context-contract.json',donorPath=prep+'/donor-row-contract.json';
  assert.equal(sha(ctx.read(contractPath)),'e930b6e65c44daa4ab27b44523241edc41e10942d92b25f2254f47073acd2235');
  assert.equal(sha(ctx.read(contextPath)),'5cf815fb77ebdc45325063e40eb2b1940718e721ed18f46f347277689dd2993a');
  assert.equal(sha(ctx.read(donorPath)),'119814498724b14dd5d272a005ecdcc19f646651d321dd78dcafef0fe1c3d638');
  const contract=ctx.parse(contractPath),context=ctx.parse(contextPath),history=ctx.parse(donorPath),before=loadRegistry(ctx);
  assert.equal(contract.acceptance.delivery_metadata_technical_acceptance,true);assert.equal(contract.acceptance.new_language_acceptance,false);
  assert.deepEqual(contract.patches.map(row=>row.id),acceptedIds);assert.equal(contract.sources.length,16);
  assert.deepEqual([...context.whole_entry_holds.map(row=>row.id)].sort(),[...heldIds].sort());
  checkContext(before,context);
  const delta={definition:0,example:0,difficulty:0};
  for(const p of contract.patches){
    assert.deepEqual(one(before.lexemes,p.id),p.before);assert.equal(before.lexemeOrigins[p.id],'res://'+target);
    assert.equal(hash(p.before),p.before_entry_json_sha256);assert.equal(hash(p.after),p.after_entry_json_sha256);
    const accepted=one(contract.acceptance.accepted_delivery_entries,p.id);assert.equal(hash(p.after),accepted.accepted_delivery_entry_json_sha256);
    assert.deepEqual(protect(p.before),protect(p.after));assert.equal(hash(protect(p.before)),p.protected_fields_json_sha256);
    for(const key of Object.keys(delta)){assert.deepEqual(p.after[key],p.accepted_fields[key]);if(p.before[key]!==p.after[key])delta[key]++;}
    assert.deepEqual(p.after.references.slice(0,p.before.references.length),p.before.references);
    assert.equal(p.after.references.length-p.before.references.length,2);assert.deepEqual(p.after.references.slice(p.before.references.length).map(row=>row.source_id),p.source_ids);
    for(const id of p.source_ids)one(contract.sources,id);
  }
  assert.deepEqual(delta,{definition:4,example:1,difficulty:5});
  assert.equal(history.rows.length,50);assert.equal(new Set(history.rows.map(row=>row.history_path+'/'+row.id)).size,50);
  for(const pin of history.history_files){const bytes=ctx.read(pin.path);assert.equal(bytes.length,pin.bytes);assert.equal(sha(bytes),pin.raw_sha256);}
  for(const expected of history.rows){
    const rows=ctx.parse(expected.history_path).protected_context.lexemes;
    assert.equal(rows.filter(row=>row.entry.id===expected.id).length,1);assert.equal(expected.exact_count,1);
    assert.deepEqual(rows[expected.index],expected.whole_row);assert.equal(hash(rows[expected.index]),expected.whole_row_json_sha256);
    assert.equal(hash(rows[expected.index].entry),rows[expected.index].json_sha256);
    assert.deepEqual(one(before.lexemes,expected.id),expected.whole_row.entry);
  }
  const bag=ctx.parse(bagProvenance);assert.equal(bag.patches.length,1);const bagPatch=bag.patches[0];
  assert.equal(bagPatch.id,'shopping-bag.goods-carrier.n');assert.deepEqual(one(before.lexemes,bagPatch.id),bagPatch.after);
  assert.equal(hash(bagPatch.after),'25300b5f9d78a6327c16c27143f1aeddd9dba1c41bdd4e42c20f30d36148cc85');
  assert.equal(sha(ctx.read(bag.resource.path)),'f978a606233240f896d7255e8f1454df0207194b207d88ef9d5502146c4558bb');
  assert.equal(new Set(before.sources.map(row=>row.id)).size,before.sources.length);
  assert.equal(new Set(contract.sources.map(row=>row.id)).size,16);
  for(const source of contract.sources){assert(!before.sources.some(row=>row.id===source.id));assert.equal(source.status,'consulted');assert.equal(source.assets_acquired,false);assert.equal(source.asset_license,null);}
  for(const id of contract.excluded_source_ids)assert(![...before.sources,...contract.sources].some(row=>row.id===id));
  const map=new Map(contract.patches.map(row=>[row.id,row]));
  const next=clone(before);next.lexemes=before.lexemes.map(row=>clone(map.get(row.id)?.after||row));next.sources.push(...clone(contract.sources));
  assert.deepEqual(next.sources.slice(0,before.sources.length),before.sources);
  const measured={before:counts(before),after:counts(next)};
  for(const key of ['lexemes','expressions','images','audio','ready_modules'])assert.equal(measured.before[key],measured.after[key]);
  assert.equal(measured.after.sources-measured.before.sources,16);assert.equal(measured.after.reviewed_language-measured.before.reviewed_language,8);
  assert.equal(measured.after.foundation02_language-measured.before.foundation02_language,8);assert.equal(measured.after.ready_modules,0);
  return {before,next,measured,delta,requiredImmutableSources};
}


function main() {
  assert.equal(process.argv.length, 6);
  assert.equal(process.argv[2], '--root-input');
  assert.equal(process.argv[4], '--root-input-sha256');
  const configPath = process.argv[3], configHash = process.argv[5];
  shaValue(configHash, 'Exact root capture input hash');
  const configBytes = fs.readFileSync(at(configPath));
  assert.equal(sha(configBytes), configHash);
  const config = JSON.parse(configBytes);
  assert.equal(config.schema, 1);
  assert.equal(config.status, 'root_authorized_one_shot_fifth10_actual_binding_capture');
  assert.equal(config.dispatcher, DISPATCHER);
  assert.equal(config.author, AUTHOR);
  assert.equal(config.entrypoint, own + '/capture.cjs');
  assert.equal(config.output, own + '/execution-r01');
  assert.equal(config.execute_project_or_preparation_code, false);
  assert.equal(config.root_confirms_actual_bag_persisted_success, true);
  assert.equal(config.root_confirms_original_fourth10_lineage, true);
  assert.deepEqual(config.guards, {production_writers_yielded: true, complete_inputs_frozen: true, final_destinations_reviewed: true});
  independentReviewer(config.independent_actual_binding_reviewer);
  assert(!configPath.startsWith(config.output + '/'), 'Root input must predate the capture output');
  assert(!fs.existsSync(at(config.output)), 'Single-use capture: preserve earlier attempts');

  const pins = new Map(), casePaths = new Map(), requiredRetained = new Set();
  function add(pin, retain = false) {
    assert.deepEqual(Object.keys(pin).sort(), ['bytes', 'path', 'raw_sha256']);
    const bytes = verifyPin(pin), lower = pin.path.toLowerCase();
    if (casePaths.has(lower)) assert.equal(casePaths.get(lower), pin.path, 'Case-ambiguous input');
    if (pins.has(pin.path)) assert.deepEqual(pins.get(pin.path), pin, 'Conflicting input pin');
    casePaths.set(lower, pin.path); pins.set(pin.path, clone(pin));
    if (retain) requiredRetained.add(pin.path);
    return bytes;
  }
  function addPath(relative, expectedHash, retain = false) {
    shaValue(expectedHash, relative);
    const bytes = fs.readFileSync(at(relative));
    const pin = {path: relative, bytes: bytes.length, raw_sha256: expectedHash};
    add(pin, retain); return pin;
  }
  const read = relative => {assert(pins.has(relative), 'Unpinned read: ' + relative); return verifyPin(pins.get(relative));};
  const parse = relative => JSON.parse(read(relative));
  function inventory(pin, retain = true) {
    const value = JSON.parse(add(pin, retain));
    const rows = value.files || value.artifacts;
    assert(Array.isArray(rows) && rows.length > 0);
    const names = new Set();
    for (const row of rows) {
      assert.equal(typeof row.path, 'string');
      assert(!row.path.includes('\\') && !row.path.startsWith('../') && !path.posix.isAbsolute(row.path));
      const relative = path.posix.dirname(pin.path) + '/' + row.path;
      at(relative); assert(!names.has(relative.toLowerCase())); names.add(relative.toLowerCase());
      add({path: relative, bytes: row.bytes, raw_sha256: row.raw_sha256 || row.sha256}, retain);
    }
    return value;
  }
  const configPin = {path: configPath, bytes: configBytes.length, raw_sha256: configHash};
  add(configPin, true);
  assert.equal(config.helper_source_inventory.path, own + '/source-inventory.json');
  const ownInventory = inventory(config.helper_source_inventory);
  assert.equal(ownInventory.status, 'frozen_unexecuted_binding_capture_sources');
  assert.equal(ownInventory.author, AUTHOR);
  assert.equal(ownInventory.actual_binding_created, false);
  assert(pins.has(own + '/capture.cjs'));
  assert(pins.has(own + '/closure-supplement.json'));

  const helperReview = JSON.parse(add(config.independent_helper_source_review, true));
  assert.equal(helperReview.schema, 1);
  assert.equal(helperReview.status, 'accepted_for_one_root_owned_fifth10_binding_capture');
  independentReviewer(helperReview.reviewer);
  assert.deepEqual(helperReview.source_inventory, config.helper_source_inventory);
  assert.equal(helperReview.helper_execution_accepted, true);
  assert.equal(helperReview.actual_binding_accepted, false);
  assert.equal(helperReview.preparation_execution_accepted, false);
  assert(Array.isArray(config.additional_review_evidence));
  for (const pin of config.additional_review_evidence) add(pin, true);

  const supplement = parse(own + '/closure-supplement.json');
  assert.equal(supplement.schema, 1);
  assert.equal(supplement.status, 'frozen_source_and_dependency_pin_supplement_not_actual_binding');
  for (const pin of supplement.input_files) add(pin, supplement.required_retained_sources.includes(pin.path));
  for (const relative of supplement.required_retained_sources) {assert(pins.has(relative)); requiredRetained.add(relative);}
  for (const pin of supplement.inventory_roots) inventory(pin);
  assert.equal(supplement.preparation_source_inventory.path, prep + '/source-inventory.json');
  assert.equal(supplement.preparation_source_inventory.raw_sha256, '2f4033d3edfeb6eacc78657e9c215ef8718bd3ceb275c94f4c6168e68d2c6ee3');
  inventory(supplement.preparation_source_inventory);

  const sourceReview = JSON.parse(add(supplement.preparation_source_review, true));
  assert.equal(sourceReview.status, 'source_accepted_pending_actual_binding_and_root_guard_validation');
  independentReviewer(sourceReview.reviewer);
  assert.deepEqual(sourceReview.source_inventory, supplement.preparation_source_inventory);
  assert.equal(sourceReview.source_design_accepted, true);
  assert.equal(sourceReview.source_only_inspection_completed, true);
  assert.equal(sourceReview.actual_binding, null);
  assert.equal(sourceReview.preparation_execution_accepted, false);
  assert.equal(sourceReview.projected_afterimages_accepted, false);

  const bagInputPin = supplement.bag_persisted_input, bagSourcePin = supplement.bag_persisted_source;
  assert.equal(bagInputPin.raw_sha256, 'a31cd76e3f21b19fc727a5ce735bac6c3d20c9de8a71fe80b70b587c1907b70f');
  assert.equal(bagSourcePin.raw_sha256, 'c25cafb5332e391eeb76d59a51e5f317199504a2c112b7fdfca2e7a52435221f');
  const bagInput = JSON.parse(add(bagInputPin, true)); add(bagSourcePin, true);
  assert.equal(bagInput.status, 'root_confirmed_actual_bag_commit_for_persisted_validation');
  assert.equal(Object.keys(bagInput.expected_inputs).length, 11740);
  assert.equal(bagInput.evidence_files.length, 579);
  for (const [relative, expected] of Object.entries(bagInput.expected_inputs)) addPath(relative, expected);
  assert.equal(new Set(bagInput.evidence_files.map(pin => pin.path.toLowerCase())).size, 579);
  for (const pin of bagInput.evidence_files) {
    assert.equal(bagInput.expected_inputs[pin.path], pin.sha256, 'Evidence must remain in the complete bag closure');
    addPath(pin.path, pin.sha256, true);
  }
  for (const relative of supplement.explicit_runtime_dependencies) assert(pins.has(relative), relative);

  function stage(kind, commitPin, persistedPin) {
    const commit = JSON.parse(add(commitPin, true));
    const persisted = JSON.parse(add(persistedPin, true));
    assert.equal(persisted.ok, true); assert.equal(persisted.error, null);
    const isFourth = kind === 'fourth10';
    const selected = isFourth ? {transaction_dir: commit.result.transactionDir, state: commit.result.state, prepared_sha256: commit.result.preparedSha256} : commit;
    const transaction = receiptRelative(selected.transaction_dir);
    const statePath = receiptRelative(selected.state.path);
    const journalPin = addPath(statePath, selected.state.sha256, true);
    const preparedPin = addPath(transaction + '/prepared.json', selected.prepared_sha256, true);
    for (const command of persisted.commands) {
      assert.equal(typeof command.log, 'string');
      assert.equal(path.posix.basename(command.log), command.log); assert(!command.log.includes('\\'));
      addPath(path.posix.dirname(persistedPin.path) + '/' + command.log, command.log_sha256, true);
    }
    const result = {root_confirmed_committed: true, root_confirmed_persisted: true,
      receipt_schema: isFourth ? 'foundation02_fourth10_nested_result_v1' : 'shopping_bag_top_level_commit_and_persisted_input_v1',
      committed_receipt: clone(commitPin), committed_journal: journalPin, prepared_journal: preparedPin, persisted_receipt: clone(persistedPin), journal_copies: [],
      success_assertions: [
        {document: 'commit', keys: ['status'], expected: 'committed'},
        {document: 'journal', keys: ['status'], expected: 'committed'},
        {document: 'persisted', keys: ['ok'], expected: true},
        {document: 'persisted', keys: ['error'], expected: null}
      ]};
    if (!isFourth) {
      result.persisted_source = clone(bagSourcePin); result.persisted_input = clone(bagInputPin);
      result.installed_targets = manifestRows(commit.target_manifest).map(row => ({path: row.path, bytes: row.after.bytes, raw_sha256: row.after.sha256}));
      for (const pin of result.installed_targets) add(pin);
    }
    successfulPredecessor(kind, result, read);
    return result;
  }
  assert.equal(supplement.fourth10_commit.path, 'docs/content-review/foundation-module02-language-fourth10-2026-10-17/commit-receipt.json');
  assert.equal(supplement.fourth10_commit.raw_sha256, '96fff4c1ac94147e99efcb8f18ff07711a5c2e53729fa07695d7d2296ae037f8');
  assert.equal(supplement.fourth10_persisted.raw_sha256, 'f25fbeb4fa8fafe08b0431653a5a9171d8369581aed104faad3e0161bbaf40f7');
  assert.equal(supplement.bag_commit.raw_sha256, 'b5b263fda99813d9c45564d5fdc35a8b437f5a3a91ec60b06eb1b00e45ddb681');
  const originalBagPersisted = 'build/professional-english/shopping-bag-persisted-validation-r01/attempt-001/receipt.json';
  const durableBagPersisted = 'docs/qa/professional-shopping-bag-r01/persisted/attempt-001/receipt.json';
  assert([originalBagPersisted, durableBagPersisted].includes(config.bag_persisted_receipt.path));
  // A root-retained receipt is acceptable only when identical to the genuine execution output.
  addPath(originalBagPersisted, config.bag_persisted_receipt.raw_sha256, true);
  assert.equal(pins.get(originalBagPersisted).bytes, config.bag_persisted_receipt.bytes);
  const actualBagPersisted = parse(originalBagPersisted);
  for (const command of actualBagPersisted.commands) {
    assert.equal(path.posix.basename(command.log), command.log); assert(!command.log.includes('\\'));
    addPath(path.posix.dirname(originalBagPersisted) + '/' + command.log, command.log_sha256, true);
  }
  const predecessors = {
    fourth10: stage('fourth10', supplement.fourth10_commit, supplement.fourth10_persisted),
    shopping_bag: stage('shopping_bag', supplement.bag_commit, config.bag_persisted_receipt)
  };
  const fourthCommit = parse(predecessors.fourth10.committed_receipt.path);
  const bagCommit = parse(predecessors.shopping_bag.committed_receipt.path);
  assert.equal(bagCommit.registry_before_sha256, fourthCommit.registry_after_sha256);
  const projection = inspectAndProject({read, parse});
  assert.equal(hash(projection.before), bagCommit.registry_after_sha256);
  assert.equal(projection.measured.before.reviewed_status, 148, 'Frozen r03 transform anchor requires reinspection if changed');
  for (const relative of projection.requiredImmutableSources) requiredRetained.add(relative);
  for (const relative of replacements) assert(pins.has(relative), relative);

  const requiredRetainedSources = [...requiredRetained].sort();
  const retainedFiles = requiredRetainedSources.map((source, index) => {
    const pin = pins.get(source); assert(pin, source);
    return {source, target: durable + '/retained/' + String(index).padStart(4, '0') + '-' + path.posix.basename(source), bytes: pin.bytes, raw_sha256: pin.raw_sha256};
  });
  const deferred = [
    {kind: 'actual_binding', target: durable + '/binding/actual-baseline-binding.json'},
    {kind: 'independent_source_review', target: durable + '/binding/independent-actual-binding-review.json'},
    {kind: 'root_input', target: durable + '/binding/root-preparation-input.json'}
  ];
  const absent = [...metadataAdditions, ...retainedFiles.map(row => row.target), ...deferred.map(row => row.target)].sort();
  const targetPaths = [...replacements, ...absent].sort();
  assert.equal(new Set(targetPaths.map(value => value.toLowerCase())).size, targetPaths.length, 'Duplicate destination');
  for (const relative of absent) assert(!fs.existsSync(at(relative)), 'Addition already exists: ' + relative);
  const binding = {schema: 1, status: 'root_bound_actual_post_bag_persisted_baseline', bound: true,
    guards: clone(config.guards),
    roles: {preparation_author: AUTHOR, inherited_preparation_author: INHERITED_AUTHOR, dispatcher: DISPATCHER, independent_reviewer: config.independent_actual_binding_reviewer},
    predecessors, registry_before_sha256: hash(projection.before), registry_after_sha256: hash(projection.next), counts: projection.measured,
    input_files: [...pins.values()].sort((a, b) => a.path.localeCompare(b.path)), retained_files: retainedFiles,
    required_retained_sources: requiredRetainedSources, deferred_retained_targets: deferred, must_remain_absent: absent, target_paths: targetPaths};
  assert.equal(binding.input_files.some(pin => pin.path === config.output + '/actual-baseline-binding.json'), false);
  const recheck = () => {
    for (const pin of binding.input_files) verifyPin(pin);
    for (const [kind, value] of Object.entries(predecessors)) successfulPredecessor(kind, value, read);
    for (const relative of absent) assert(!fs.existsSync(at(relative)), relative);
  };
  recheck();
  // No output is created until every source, predecessor, closure and destination gate passes.
  fs.mkdirSync(at(config.output));
  const artifacts = [];
  const save = (name, value) => {
    assert.equal(path.posix.basename(name), name);
    const bytes = serialize(value), relative = config.output + '/' + name;
    fs.writeFileSync(at(relative), bytes, {flag: 'wx'});
    const pin = {path: relative, bytes: bytes.length, raw_sha256: sha(bytes)};
    artifacts.push(pin); return pin;
  };
  try {
    save('capture-start.json', {schema: 1, status: 'started', started_at: new Date().toISOString(), root_capture_input: configPin, helper_source_inventory: config.helper_source_inventory, independent_helper_source_review: config.independent_helper_source_review});
    const actualBinding = save('actual-baseline-binding.json', binding);
    save('capture-observations.json', {schema: 1, status: 'built_in_json_binding_capture_pending_independent_actual_binding_review', actual_binding: actualBinding,
      actual_bag_commit: supplement.bag_commit, actual_bag_persisted: config.bag_persisted_receipt,
      preparation_source_review: supplement.preparation_source_review, preparation_source_inventory: supplement.preparation_source_inventory,
      registry_before_sha256: binding.registry_before_sha256, registry_after_sha256: binding.registry_after_sha256, counts: binding.counts,
      content_delta: projection.delta, input_count: binding.input_files.length, inherited_bag_input_count: 11740, inherited_bag_evidence_count: 579,
      retained_count: retainedFiles.length, deferred_count: 3, replacements, additions_count: absent.length, target_count: targetPaths.length,
      actual_binding_independently_accepted: false, preparation_execution_accepted: false, preparation_executed: false,
      project_or_proposal_code_imported: false, syntax_or_test_or_native_executed: false, production_mutated: false,
      fifth10_commit_receipt: null, fifth10_persisted_receipt: null});
    recheck();
    save('capture-receipt.json', {schema: 1, status: 'constructed_binding_pending_independent_actual_binding_review', finished_at: new Date().toISOString(),
      root_capture_input: configPin, helper_source_inventory: config.helper_source_inventory, independent_helper_source_review: config.independent_helper_source_review,
      actual_binding: actualBinding, artifacts: clone(artifacts), actual_binding_independently_accepted: false, preparation_execution_accepted: false,
      preparation_executed: false, project_or_proposal_code_imported: false, syntax_or_test_or_native_executed: false, production_mutated: false});
    console.log(JSON.stringify({status: 'constructed_binding_pending_independent_actual_binding_review', actual_binding: actualBinding}));
  } catch (error) {
    save('failed-attempt.json', {schema: 1, status: 'failed', recorded_at: new Date().toISOString(), error: error.stack || String(error),
      instruction: 'Preserve this consumed attempt and all sources. Do not use any partial binding. Corrections require a fresh reviewed revision.',
      actual_binding_independently_accepted: false, preparation_execution_accepted: false, production_mutated: false});
    throw error;
  }
}
main();
