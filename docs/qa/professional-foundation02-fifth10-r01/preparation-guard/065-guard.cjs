'use strict';
// UNEXECUTED PROPOSAL. Root dispatch only, after real capture and independent acceptance.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const ROOT = path.resolve(__dirname, '../../..');
const OWN = 'build/professional-english/foundation02-fifth10-preparation-guard-proposal-r02';
const PREP = 'build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const HELPER = 'build/professional-english/foundation02-fifth10-root-binding-proposal-r02';
const AUTHOR = '/root'; // r02 author; r01 was authored by /root/runtime_recovery.
const BINDING_HASH = '022fc186186ade95d6d58908932db5520652f39a1417255c3c5080a4e4841f1b';
const PREP_INVENTORY_HASH = '2f4033d3edfeb6eacc78657e9c215ef8718bd3ceb275c94f4c6168e68d2c6ee3';
const SOURCE_REVIEW_HASH = '5c0472fb71d342262c6c8fcac064b4befef14f95408a5a7ee0aed296eeb8a583';
const HELPER_INVENTORY_HASH = 'b52fea9c2181064d024d35a05f599ad3b24897e2402927031f13e449e5a10993';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const encode = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const clone = value => JSON.parse(JSON.stringify(value));
function at(relative) {
  assert.equal(typeof relative, 'string');
  assert(relative && !relative.includes('\\') && !path.isAbsolute(relative));
  const absolute = path.resolve(ROOT, relative);
  assert.equal(path.relative(ROOT, absolute).replaceAll('\\', '/'), relative);
  assert(!relative.startsWith('../'));
  return absolute;
}
function relative(absolute) {
  const result = path.relative(ROOT, absolute).replaceAll('\\', '/');
  at(result);
  return result;
}
function pinShape(pin) {
  assert.deepEqual(Object.keys(pin).sort(), ['bytes', 'path', 'raw_sha256']);
  at(pin.path);
  assert(Number.isSafeInteger(pin.bytes) && pin.bytes >= 0);
  assert.match(pin.raw_sha256, /^[a-f0-9]{64}$/);
}
function describe(p, bytes) {return {path:p, bytes:bytes.length, raw_sha256:sha(bytes)};}
function independent(identity) {
  assert.equal(typeof identity, 'string');
  assert.match(identity, /^\/root\/[a-z0-9_]+$/);
  assert(!['/root', '/root/recover_delivery', '/root/runtime_recovery', AUTHOR].includes(identity));
}
function errorData(error) {
  return {name:error.name, code:error.code || null, message:String(error.message), stack:String(error.stack || error)};
}
function failBoundary(message) {
  const error = new Error(message);error.code = 'GUARD_VM_BOUNDARY';throw error;
}

function main() {
  assert.equal(ROOT.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
  assert.equal(path.resolve(process.cwd()), ROOT);
  assert.equal(process.argv.length, 8);
  assert.equal(process.argv[2], '--guard-source-sha256');
  assert.equal(process.argv[4], '--root-input');
  assert.equal(process.argv[6], '--root-input-sha256');
  const sourceHash = process.argv[3], configPath = process.argv[5], configHash = process.argv[7];
  assert.match(sourceHash, /^[a-f0-9]{64}$/);assert.match(configHash, /^[a-f0-9]{64}$/);
  const selfBytes = fs.readFileSync(__filename), configBytes = fs.readFileSync(at(configPath));
  assert.equal(sha(selfBytes), sourceHash);assert.equal(sha(configBytes), configHash);
  const config = JSON.parse(configBytes);
  assert.equal(config.schema, 1);
  assert.equal(config.status, 'root_authorized_one_shot_fifth10_memory_guard');
  assert.equal(config.dispatcher, '/root');assert.equal(config.guard_author, AUTHOR);
  assert.equal(config.entrypoint, OWN + '/guard.cjs');
  assert.equal(config.output, OWN + '/attempt-001');
  assert.equal(config.root_confirms_guard_source_reviewed, true);
  assert.equal(config.execute_preparation_or_project_code, false);
  assert.equal(config.production_writers_yielded, true);
  assert(!configPath.startsWith(config.output + '/'));
  assert(!fs.existsSync(at(config.output)), 'Consumed guard attempt must never be replayed');
  assert(!fs.existsSync(at(PREP + '/execution-r01')), 'Actual preparation must not predate this guard');
  fs.mkdirSync(at(config.output));
  const outputPins = [];
  function save(name, value) {
    assert.equal(path.posix.basename(name), name);
    const bytes = encode(value), p = config.output + '/' + name;
    fs.writeFileSync(at(p), bytes, {flag:'wx'});
    const pin = describe(p, bytes);outputPins.push(pin);return pin;
  }
  save('start.json', {schema:1,status:'started',started_at:new Date().toISOString(),dispatcher:'/root',
    guard_source:describe(OWN + '/guard.cjs', selfBytes),root_guard_input:describe(configPath, configBytes),
    preparation_executed:false,project_code_executed:false});
  const bytesCache = new Map(), sourcePins = new Map(), pathCase = new Map(), checkedAncestors = new Set();
  const directorySnapshots = new Map(), absenceSnapshots = new Set();
  let genuine = null, cases = [], outerFailure = null, postcheckFailure = null, cachedMutationFailure = null;
  function add(pin) {
    pinShape(pin);
    const lower = pin.path.toLowerCase();
    if (pathCase.has(lower)) assert.equal(pathCase.get(lower), pin.path, 'Case-ambiguous input');
    pathCase.set(lower, pin.path);
    if (sourcePins.has(pin.path)) {assert.deepEqual(sourcePins.get(pin.path), pin, 'Conflicting input pin');return bytesCache.get(pin.path);}
    const absolute = at(pin.path);
    for (let p = absolute; p !== ROOT; p = path.dirname(p)) {
      if (checkedAncestors.has(p)) break;
      assert(!fs.lstatSync(p).isSymbolicLink(), 'Input link: ' + pin.path);
      checkedAncestors.add(p);
    }
    const bytes = fs.readFileSync(absolute);
    assert.equal(bytes.length, pin.bytes, pin.path);assert.equal(sha(bytes), pin.raw_sha256, pin.path);
    sourcePins.set(pin.path, clone(pin));bytesCache.set(pin.path, bytes);
    return bytes;
  }
  function inventory(pin) {
    const document = JSON.parse(add(pin));
    assert(Array.isArray(document.files) && document.files.length > 0);
    for (const row of document.files) add({path:path.posix.dirname(pin.path) + '/' + row.path, bytes:row.bytes, raw_sha256:row.raw_sha256});
    return document;
  }
  function parse(pin) {return JSON.parse(add(pin));}
  function diskRecheck() {
    for (const pin of sourcePins.values()) {
      const bytes = fs.readFileSync(at(pin.path));
      assert.equal(bytes.length, pin.bytes, pin.path);assert.equal(sha(bytes), pin.raw_sha256, pin.path);
    }
    for (const [p, names] of directorySnapshots) assert.deepEqual(fs.readdirSync(at(p)).sort(), names, p);
    for (const p of absenceSnapshots) assert(!fs.existsSync(at(p)), 'Formerly absent target appeared: ' + p);
    assert(!fs.existsSync(at(PREP + '/execution-r01')), 'Guard must not create actual preparation output');
  }
  try {
    add(describe(OWN + '/guard.cjs', selfBytes));add(describe(configPath, configBytes));
    assert.equal(config.guard_source_inventory.path, OWN + '/source-inventory.json');
    const guardInventory = inventory(config.guard_source_inventory);
    assert.equal(guardInventory.status, 'frozen_unexecuted_fifth10_memory_guard_sources');
    assert.equal(guardInventory.author, AUTHOR);
    const dependencies = JSON.parse(bytesCache.get(OWN + '/dependencies.json'));
    for (const pin of dependencies.files) add(pin);
    assert.equal(sha(bytesCache.get(PREP + '/binding.cjs')), BINDING_HASH);
    const sourceReviewPath = 'build/professional-english/foundation02-fifth10-preparation-independent-review-r03/review.json';
    assert.equal(sha(bytesCache.get(sourceReviewPath)), SOURCE_REVIEW_HASH);
    const sourceReview = JSON.parse(bytesCache.get(sourceReviewPath));
    assert.equal(sourceReview.status, 'source_accepted_pending_actual_binding_and_root_guard_validation');
    assert.equal(sourceReview.preparation_execution_accepted, false);
    assert.equal(sourceReview.actual_binding, null);
    const sourceSpec = JSON.parse(bytesCache.get(PREP + '/guard-cases.json'));
    assert.equal(sourceSpec.negative_cases.length, 29);
    assert.equal(sourceSpec.executed, false);
    assert.equal(config.actual_capture.source_inventory.path, HELPER + '/source-inventory.json');
    assert.equal(config.actual_capture.source_inventory.raw_sha256, HELPER_INVENTORY_HASH);
    inventory(config.actual_capture.source_inventory);
    const helperReview = parse(config.actual_capture.independent_source_review);
    assert.equal(helperReview.status, 'accepted_for_one_root_owned_fifth10_binding_capture');
    independent(helperReview.reviewer);
    assert.deepEqual(helperReview.source_inventory, config.actual_capture.source_inventory);
    assert.equal(helperReview.helper_execution_accepted, true);
    assert.equal(helperReview.actual_binding_accepted, false);
    assert.equal(helperReview.preparation_execution_accepted, false);
    const captureInput = parse(config.actual_capture.root_input);
    assert.equal(captureInput.status, 'root_authorized_one_shot_fifth10_actual_binding_capture');
    assert.deepEqual(captureInput.helper_source_inventory, config.actual_capture.source_inventory);
    assert.deepEqual(captureInput.independent_helper_source_review, config.actual_capture.independent_source_review);
    assert.equal(config.actual_capture.receipt.path, HELPER + '/execution-r01/capture-receipt.json');
    const capture = parse(config.actual_capture.receipt);
    assert.equal(capture.status, 'constructed_binding_pending_independent_actual_binding_review');
    assert.deepEqual(capture.root_capture_input, config.actual_capture.root_input);
    assert.deepEqual(capture.helper_source_inventory, config.actual_capture.source_inventory);
    assert.deepEqual(capture.independent_helper_source_review, config.actual_capture.independent_source_review);
    assert.equal(capture.actual_binding_independently_accepted, false);
    assert.equal(capture.preparation_execution_accepted, false);
    assert.equal(capture.preparation_executed, false);
    for (const pin of capture.artifacts) add(pin);
    const rootInput = parse(config.preparation_root_input);
    assert.equal(rootInput.status, 'root_authorized_one_shot_scratch_preparation');
    assert.equal(rootInput.dispatcher, '/root');assert.equal(rootInput.execute_project_tests, false);
    assert.deepEqual(rootInput.binding, capture.actual_binding);
    assert.equal(rootInput.source_inventory.path, PREP + '/source-inventory.json');
    assert.equal(rootInput.source_inventory.raw_sha256, PREP_INVENTORY_HASH);
    inventory(rootInput.source_inventory);
    const binding = parse(rootInput.binding), acceptance = parse(rootInput.independent_source_review);
    assert.equal(binding.status, 'root_bound_actual_post_bag_persisted_baseline');
    assert.equal(binding.bound, true);
    assert.equal(acceptance.status, 'accepted_for_one_root_owned_fifth10_scratch_preparation');
    independent(acceptance.reviewer);
    assert.deepEqual(acceptance.roles, binding.roles);
    assert.equal(acceptance.reviewer, binding.roles.independent_reviewer);
    assert.deepEqual(acceptance.actual_binding, rootInput.binding);
    assert.deepEqual(acceptance.source_inventory, rootInput.source_inventory);
    assert.equal(acceptance.preparation_execution_accepted, true);
    assert.notEqual(rootInput.independent_source_review.path, sourceReviewPath, 'Separate actual-binding acceptance required');
    for (const pin of binding.input_files) add(pin);
    const bagInput = JSON.parse(add(binding.predecessors.shopping_bag.persisted_input));
    const bagReceipt = JSON.parse(add(binding.predecessors.shopping_bag.persisted_receipt));
    assert.equal(bagReceipt.ok, true);assert.equal(bagReceipt.error, null);assert.equal(bagReceipt.postcheck_error, null);
    const bound = new Map(binding.input_files.map(pin => [pin.path, pin]));
    const union = new Map(Object.entries(bagInput.expected_inputs));
    assert.equal(union.size, 11740);assert.equal(bagInput.evidence_files.length, 579);
    let shared = 0, evidenceOnly = 0;
    for (const row of bagInput.evidence_files) {
      if (union.has(row.path)) {assert.equal(union.get(row.path), row.sha256);shared++;}
      else evidenceOnly++;
      union.set(row.path, row.sha256);
    }
    assert.equal(shared, 89);assert.equal(evidenceOnly, 490);assert.equal(union.size, 12230);
    for (const [p, hash] of union) {assert(bound.has(p), p);assert.equal(bound.get(p).raw_sha256, hash, p);}
    for (const p of binding.must_remain_absent) {assert(!fs.existsSync(at(p)), p);absenceSnapshots.add(p);}
    absenceSnapshots.add(PREP + '/execution-r01');
    for (const kind of ['fourth10', 'shopping_bag']) {
      const stage = binding.predecessors[kind], commit = JSON.parse(add(stage.committed_receipt));
      const rawState = kind === 'fourth10' ? commit.result.state.path : commit.state.path;
      const statePath = path.isAbsolute(rawState) ? relative(rawState) : rawState;
      const directory = path.posix.dirname(statePath);
      assert(!fs.lstatSync(at(directory)).isSymbolicLink());
      directorySnapshots.set(directory, fs.readdirSync(at(directory)).sort());
    }
    genuine = {rootInput, binding, acceptance, rootInputPin:config.preparation_root_input,
      source:bytesCache.get(PREP + '/binding.cjs').toString('utf8')};
    save('protected-inputs.json', {schema:1,files:[...sourcePins.values()].sort((a,b)=>a.path.localeCompare(b.path)),
      directories:[...directorySnapshots].map(([path,names])=>({path,names})),must_remain_absent:[...absenceSnapshots].sort(),
      inherited_bag_union:{expected_inputs:11740,evidence:579,shared:89,evidence_only:490,unique:12230}});
    const caseList = makeCases(genuine, bytesCache, sourcePins, directorySnapshots);
    const required = sourceSpec.negative_cases.map(row => row.id).sort();
    const implemented = [...new Set(caseList.filter(row=>row.spec).map(row=>row.spec))].sort();
    assert.deepEqual(implemented, required, 'Every frozen negative specification must be implemented');
    assert.equal(new Set(caseList.map(row=>row.id)).size, caseList.length);
    for (const [index, spec] of caseList.entries()) {
      const fixture = new Fixture(genuine, bytesCache, sourcePins, directorySnapshots, spec.id);
      const result = {schema:1,id:spec.id,specification:spec.spec || null,classification:spec.classification,
        expected:spec.expected,mutation:spec.description,synthetic_in_memory_only:spec.id !== 'genuine_baseline',
        source_sha256:BINDING_HASH,actual_preparation_input:config.preparation_root_input,
        opened:false,recheck_passed:false,passed:false};
      try {
        if (spec.mutate) spec.mutate(fixture);
        if (!spec.exact) fixture.seal();
        const harness = loadBinding(genuine.source, fixture);
        let failure = null;
        try {
          harness.open();
          result.opened = true;
          if (spec.afterOpen) spec.afterOpen(fixture);
          harness.recheck();
          result.recheck_passed = true;
          result.positive_schema_evidence = harness.evidence();
        } catch (error) {failure = error;}
        result.virtual_io = harness.trace;
        result.virtual_changes = fixture.changes();
        if (spec.expected === 'accept') {
          if (failure) throw failure;
          assert.equal(result.opened, true);assert.equal(result.recheck_passed, true);
        } else {
          assert(failure, 'Guard case unexpectedly accepted');
          result.rejection = errorData(failure);
          assert.equal(failure.code, 'ERR_ASSERTION', 'Only the named binding assertion can satisfy this case');
          const expectedSite = assertionSite(genuine.source, spec.marker);
          const match = String(failure.stack).match(/fifth10-frozen-binding\.cjs:(\d+):(\d+)/);
          assert(match, 'Missing frozen binding assertion frame');
          const actualSite = {line:Number(match[1]),column:Number(match[2])};
          result.expected_assertion = {...expectedSite,source_fragment:spec.marker};
          result.actual_first_binding_frame = actualSite;
          assert.equal(actualSite.line, expectedSite.line, 'Rejected by an earlier or unrelated assertion line');
          assert(actualSite.column >= expectedSite.column_start && actualSite.column < expectedSite.column_end,
            'Rejected by a neighboring or unrelated assertion on the same line');
          if (spec.message) assert(String(failure.message).includes(spec.message), 'Wrong named rejection');
        }
        result.passed = true;
      } catch (error) {result.harness_failure = errorData(error);}
      cases.push(result);
      save('case-' + String(index + 1).padStart(3,'0') + '-' + spec.id + '.json', result);
      assert.equal(result.passed, true, 'Stop at first unexpected guard outcome: ' + spec.id);
    }
    assert.equal(cases.filter(row=>row.specification).every(row=>row.passed), true);
  } catch (error) {outerFailure = errorData(error);}
  try {diskRecheck();} catch (error) {postcheckFailure = errorData(error);}
  try {for (const [p, bytes] of bytesCache) assert.equal(sha(bytes), sourcePins.get(p).raw_sha256, 'Cached originals changed: ' + p);}
  catch (error) {cachedMutationFailure = errorData(error);}
  const ok = outerFailure === null && postcheckFailure === null && cachedMutationFailure === null;
  const receipt = {schema:1,status:ok ? 'passed_fifth10_binding_memory_guard' : 'failed_fifth10_binding_memory_guard',
    ok,finished_at:new Date().toISOString(),dispatcher:'/root',guard_source:describe(OWN+'/guard.cjs',selfBytes),
    root_guard_input:describe(configPath,configBytes),preparation_root_input:config.preparation_root_input,
    actual_capture:config.actual_capture,original_actual_binding:genuine ? genuine.rootInput.binding : null,
    original_independent_preparation_acceptance:genuine ? genuine.rootInput.independent_source_review : null,
    exact_frozen_binding_sha256:BINDING_HASH,expected_negative_specifications:29,
    covered_negative_specifications:[...new Set(cases.filter(row=>row.specification && row.passed).map(row=>row.specification))].sort(),
    completed_cases:cases.length,passed_cases:cases.filter(row=>row.passed).length,
    genuine_positive_passed:cases.some(row=>row.id==='genuine_baseline' && row.passed),
    exact_copy_positive_passed:cases.some(row=>row.id==='exact_bound_journal_copies' && row.passed),
    protected_file_count:sourcePins.size,protected_files_unchanged:postcheckFailure===null,
    cached_original_bytes_unchanged:cachedMutationFailure===null,error:outerFailure,
    postcheck_error:postcheckFailure,cached_mutation_error:cachedMutationFailure,
    artifacts:clone(outputPins),preparation_executed:false,projection_executed:false,test_transform_executed:false,
    project_modules_imported:false,tests_or_native_or_transactions_executed:false,production_written:false,
    boundary:'Only the exact frozen binding source ran in an isolated VM. Fixture mutations and acceptance-pin rebinding were in memory. The real binding and real acceptance remain unchanged. Root may consider actual preparation only after this exact receipt passes and all original pins remain unchanged.'};
  const receiptPin = save('receipt.json', receipt);
  console.log(JSON.stringify({ok,receipt:receiptPin,cases:receipt.completed_cases,passed:receipt.passed_cases,
    covered_specifications:receipt.covered_negative_specifications.length,error:outerFailure,postcheck_error:postcheckFailure}));
  process.exitCode = ok ? 0 : 1;
}

function assertionSite(source, fragment) {
  const start = source.indexOf(fragment);
  assert(start >= 0 && source.indexOf(fragment, start + 1) === -1, 'Unique frozen assertion anchor: ' + fragment);
  const assertions = [...fragment.matchAll(/\bassert(?=\.|\()/g)];
  assert.equal(assertions.length, 1, 'Exactly one assertion in each marker');
  const first = start + assertions[0].index, end = start + fragment.length;
  assert(!source.slice(first, end).includes('\n'), 'One-line assertion span required');
  const lineStart = source.lastIndexOf('\n', first - 1) + 1;
  return {line:source.slice(0,first).split('\n').length,column_start:first-lineStart+1,column_end:end-lineStart+1};
}
class Fixture {
  constructor(genuine, cache, pins, directories, id) {
    this.genuine=genuine;this.cache=cache;this.pins=pins;this.id=id;this.overlay=new Map();
    this.directories=new Map([...directories].map(([p,names])=>[p,[...names]]));
    this.input=clone(genuine.rootInput);this.binding=clone(genuine.binding);this.review=clone(genuine.acceptance);
    this.inputPath=genuine.rootInputPin.path;this.inputHash=genuine.rootInputPin.raw_sha256;
    this.bindingPath=this.input.binding.path;this.reviewPath=this.input.independent_source_review.path;
    this.reviewPinMutation=null;this.rootOnly=false;this.copies=[];this.actions=[];
  }
  read(p) {
    if(this.overlay.has(p))return this.overlay.get(p);
    if(this.cache.has(p))return this.cache.get(p);
    failBoundary('Uncached fixture read: '+p);
  }
  json(p) {return JSON.parse(this.read(p));}
  descriptor(p) {return describe(p,this.read(p));}
  write(p,bytes) {at(p);this.overlay.set(p,Buffer.from(bytes));}
  putEvidence(p,value) {
    this.write(p,Buffer.isBuffer(value)?value:encode(value));
    const pin=this.descriptor(p);
    const index=this.binding.input_files.findIndex(row=>row.path===p);
    assert(index>=0,'Mutated evidence must already have a real baseline pin');
    this.binding.input_files[index]=clone(pin);
    for(const stage of Object.values(this.binding.predecessors))
      for(const key of ['committed_receipt','committed_journal','prepared_journal','persisted_receipt','persisted_input','persisted_source'])
        if(stage[key] && stage[key].path===p)stage[key]=clone(pin);
    return pin;
  }
  stage() {return this.binding.predecessors.shopping_bag;}
  editPersisted(change) {
    const stage=this.stage(), document=this.json(stage.persisted_receipt.path);
    change(document);this.putEvidence(stage.persisted_receipt.path,document);
  }
  editPersistedInput(change) {
    const stage=this.stage(), document=this.json(stage.persisted_input.path);
    change(document);this.putEvidence(stage.persisted_input.path,document);
    this.editPersisted(receipt=>{receipt.input_sha256=stage.persisted_input.raw_sha256;});
  }
  relinkCommit(commit) {
    const stage=this.stage();
    this.putEvidence(stage.committed_receipt.path,commit);
    this.editPersistedInput(document=>{
      document.commit_receipt.path=stage.committed_receipt.path;
      document.commit_receipt.sha256=stage.committed_receipt.raw_sha256;
      document.committed_journal.path=path.isAbsolute(commit.state.path)?relative(commit.state.path):commit.state.path;
      document.committed_journal.sha256=commit.state.sha256;
    });
  }
  relinkState(journal) {
    const stage=this.stage();
    this.putEvidence(stage.committed_journal.path,journal);
    const commit=this.json(stage.committed_receipt.path);
    commit.state.sha256=stage.committed_journal.raw_sha256;
    commit.journal.state=clone(commit.state);
    this.relinkCommit(commit);
  }
  relinkPrepared(prepared,{updatePlanHash=true,updateCommitPlan=true,journalChange=()=>{}}={}) {
    const stage=this.stage();
    if(updatePlanHash)prepared.plan_sha256=sha(encode(prepared.plan));
    this.putEvidence(stage.prepared_journal.path,prepared);
    const journal=this.json(stage.committed_journal.path);journal.prepared_sha256=stage.prepared_journal.raw_sha256;journalChange(journal);
    this.putEvidence(stage.committed_journal.path,journal);
    const commit=this.json(stage.committed_receipt.path);
    commit.prepared_sha256=stage.prepared_journal.raw_sha256;commit.journal.prepared_sha256=commit.prepared_sha256;
    if(updateCommitPlan)commit.plan_sha256=prepared.plan_sha256;
    commit.journal.plan_sha256=commit.plan_sha256;
    commit.state.sha256=stage.committed_journal.raw_sha256;commit.journal.state=clone(commit.state);
    this.relinkCommit(commit);
  }
  exactCopies(kind) {
    const stage=this.binding.predecessors[kind];
    assert.deepEqual(stage.journal_copies,[], 'Actual capture should select original journals');
    for(const key of ['committed_journal','prepared_journal']) {
      const original=clone(stage[key]);
      const alias=OWN+'/memory-only/'+this.id+'/'+kind+'-'+key+'.json';
      assert(!this.cache.has(alias) && !this.overlay.has(alias),'Fresh in-memory alias');
      this.write(alias,this.read(original.path));
      const pin=this.descriptor(alias);this.binding.input_files.push(pin);stage[key]=clone(pin);
      this.binding.required_retained_sources.push(alias);
      const row={kind:key,source_path:original.path,target_path:alias,bytes:pin.bytes,raw_sha256:pin.raw_sha256};
      stage.journal_copies.push(row);this.copies.push({kind,...row});
    }
  }
  seal() {
    if(!this.rootOnly) {
      this.write(this.bindingPath,encode(this.binding));this.input.binding=this.descriptor(this.bindingPath);
      this.review.actual_binding=clone(this.input.binding);
      if(this.reviewPinMutation)this.reviewPinMutation(this.review);
      this.write(this.reviewPath,encode(this.review));this.input.independent_source_review=this.descriptor(this.reviewPath);
    }
    this.write(this.inputPath,encode(this.input));this.inputHash=sha(this.read(this.inputPath));
  }
  changes() {
    return [...this.overlay].map(([p,bytes])=>({path:p,original:this.cache.has(p)?describe(p,this.cache.get(p)):null,
      fixture:describe(p,bytes),scope:'memory_only'})).sort((a,b)=>a.path.localeCompare(b.path));
  }
}

function loadBinding(source,fixture) {
  const trace={imports:[],file_reads:0,directory_reads:0,existence_reads:0,denied:[]};
  const resolveFile=value=>{
    if(typeof value!=='string' || !path.isAbsolute(value))failBoundary('Absolute cached VM path required');
    return relative(value);
  };
  const readOnlyFs=Object.freeze({
    readFileSync(value,options) {
      if(options!==undefined)failBoundary('Binding attempted non-buffer read options');
      trace.file_reads++;return Buffer.from(fixture.read(resolveFile(value)));
    },
    readdirSync(value,options) {
      if(options!==undefined)failBoundary('Binding attempted unexpected directory options');
      const p=resolveFile(value);trace.directory_reads++;
      if(!fixture.directories.has(p))failBoundary('Uncached VM directory: '+p);
      return [...fixture.directories.get(p)];
    },
    existsSync(value) {
      const p=resolveFile(value);trace.existence_reads++;
      if(fixture.overlay.has(p)||fixture.cache.has(p))return true;
      if(fixture.genuine.binding.must_remain_absent.includes(p)||p===PREP+'/execution-r01')return false;
      failBoundary('Uncached VM existence query: '+p);
    }
  });
  const module={exports:{}};
  const allowed=new Map([['node:fs',readOnlyFs],['node:path',path],['node:crypto',Object.freeze({createHash:crypto.createHash})],['node:assert/strict',assert]]);
  const context=vm.createContext({module,exports:module.exports,__dirname:at(PREP),Buffer,
    require(name){trace.imports.push(name);if(!allowed.has(name)){trace.denied.push(name);failBoundary('Disallowed VM import: '+name);}return allowed.get(name);},
    __guardInputPath:fixture.inputPath,__guardInputHash:fixture.inputHash},{name:'fifth10-read-only-binding-guard',codeGeneration:{strings:false,wasm:false}});
  new vm.Script(source,{filename:'fifth10-frozen-binding.cjs'}).runInContext(context,{timeout:600000});
  const run=code=>new vm.Script(code,{filename:'fifth10-memory-guard-call.cjs'}).runInContext(context,{timeout:600000});
  return {trace,
    open(){run('globalThis.__guardSession = module.exports.openSession(__guardInputPath, __guardInputHash); module.exports.assertSession(__guardSession);');},
    recheck(){run('__guardSession.recheck(); module.exports.assertSession(__guardSession);');},
    evidence(){return JSON.parse(run("JSON.stringify({fourth10_schema:__guardSession.binding.predecessors.fourth10.receipt_schema,shopping_bag_schema:__guardSession.binding.predecessors.shopping_bag.receipt_schema,fourth10_targets:__guardSession.fourth.manifest.length,shopping_bag_targets:__guardSession.bag.manifest.length,bag_tests:__guardSession.bag.persisted.tests,independent_reviewer:__guardSession.binding.roles.independent_reviewer,journal_copies:{fourth10:__guardSession.binding.predecessors.fourth10.journal_copies,shopping_bag:__guardSession.binding.predecessors.shopping_bag.journal_copies}})"));}};
}
function makeCases(genuine,cache,pins,directories) {
  const list=[];
  const add=(id,spec,description,marker,mutate,extra={})=>list.push({id,spec,description,marker,mutate,
    expected:'reject',classification:'semantic_guard_with_rebound_fixture_envelopes',...extra});
  const role=(fixture,identity)=>{
    fixture.binding.roles.independent_reviewer=identity;fixture.review.reviewer=identity;
    fixture.review.roles.independent_reviewer=identity;
  };
  const differentHash=hash=>(hash[0]==='a'?'b':'a')+hash.slice(1);
  const installedOutsideNamed=f=>f.stage().installed_targets.find(row=>row.path.startsWith('docs/'));
  const laterState=f=>{
    const stage=f.stage(),commit=f.json(stage.committed_receipt.path);
    const p=path.isAbsolute(commit.state.path)?relative(commit.state.path):commit.state.path,dir=path.posix.dirname(p);
    const number=Number(path.posix.basename(p).slice(0,6))+1;
    f.directories.get(dir).push(String(number).padStart(6,'0')+'-committed.json');
  };
  list.push({id:'genuine_baseline',expected:'accept',classification:'unmodified_actual_binding_and_independent_acceptance',
    description:'Use cached exact real root input, both genuine receipt schemas, complete actual pins and real acceptance without rewriting any bytes.',exact:true});
  list.push({id:'exact_bound_journal_copies',expected:'accept',classification:'exact_content_copy_fixture',
    description:'Select byte-identical in-memory committed and prepared copies for both predecessors, bind originals and copy mappings, and rebind only fixture envelopes.',
    mutate:f=>{f.exactCopies('fourth10');f.exactCopies('shopping_bag');}});
  add('reviewer_missing','reviewer_missing','Remove only the acceptance reviewer and rebind its raw pin.',
    "assert.equal(typeof value, 'string', 'Named independent reviewer required');",f=>{delete f.review.reviewer;});
  add('reviewer_empty','reviewer_empty','Use an empty acceptance reviewer, with valid surrounding hashes.',
    "assert(value.length > 0 && value === value.trim(), 'Nonempty exact reviewer identity required');",f=>{f.review.reviewer='';});
  for(const [suffix,value] of [['only_spaces','   '],['padded',' /root/morph_review ']])
    add('reviewer_whitespace_'+suffix,'reviewer_whitespace','Use '+suffix+' in the acceptance reviewer.',
      "assert(value.length > 0 && value === value.trim(), 'Nonempty exact reviewer identity required');",f=>{f.review.reviewer=value;});
  for(const [id,identity] of [['reviewer_current_author','/root/recover_delivery'],['reviewer_inherited_author','/root/runtime_recovery']])
    add(id,id,'Align binding, acceptance reviewer and roles to the prohibited '+identity+'.',
      "assert(![AUTHOR, INHERITED_AUTHOR, DISPATCHER].includes(value), 'Author or dispatcher cannot accept preparation');",f=>role(f,identity));
  add('reviewer_dispatcher','reviewer_dispatcher','Align all reviewer fields to the root dispatcher.',
    "assert.match(value, /^\\/root\\/[a-z0-9_]+$/, 'Use the canonical independent agent identity');",f=>role(f,'/root'));
  add('reviewer_role_mismatch','reviewer_role_mismatch','Keep valid distinct canonical identities but mismatch acceptance versus binding reviewer.',
    'assert.equal(review.reviewer, binding.roles.independent_reviewer);',f=>{f.review.reviewer=f.binding.roles.independent_reviewer==='/root/memory_guard_distinct_reviewer' ? '/root/memory_guard_alternate_reviewer' : '/root/memory_guard_distinct_reviewer';});
  for(const [suffix,change] of [['binding_path',r=>{r.actual_binding.path=OWN+'/memory-only/unaccepted-binding.json';}],
    ['binding_bytes',r=>{r.actual_binding.bytes++;}],['inventory_path',r=>{r.source_inventory.path=OWN+'/memory-only/unaccepted-inventory.json';}],
    ['inventory_bytes',r=>{r.source_inventory.bytes++;}]])
    add('review_pin_identity_'+suffix,'review_pin_identity_mismatch','Change acceptance '+suffix+' while keeping its accepted raw hash.',
      (suffix.startsWith('binding_') ? 'assert.deepEqual(review.actual_binding, input.binding);' : 'assert.deepEqual(review.source_inventory, input.source_inventory);'),f=>{f.reviewPinMutation=change;});
  add('unrelated_committed_journal','unrelated_committed_journal','Select the genuine fourth10 state pin as the bag state while retaining the genuine bag commit.',
    "assert.equal(pin.raw_sha256, expectedHash, key);",
    f=>{f.stage().committed_journal=clone(f.binding.predecessors.fourth10.committed_journal);});
  add('changed_state_hash','changed_state_hash','Change bag state bytes and rehash its valid pin, retaining the actual receipt state identity.',
    "assert.equal(pin.raw_sha256, expectedHash, key);",
    f=>{const p=f.stage().committed_journal.path,d=f.json(p);d.guard_fixture_marker='changed-state-identity';f.putEvidence(p,d);});
  add('changed_prepared_identity','changed_prepared_identity','Rebind state and receipt raw hashes while making state prepared identity differ from selected prepared journal.',
    "assert.equal(journal.prepared_sha256, selected.prepared_sha256);",
    f=>{const d=f.json(f.stage().committed_journal.path);d.prepared_sha256=differentHash(d.prepared_sha256);f.relinkState(d);});
  add('changed_plan_identity','changed_plan_identity','Change the plan, recompute prepared and state identities and receipt links, but retain the original inner plan hash.',
    "assert.equal(sha(serialize(prepared.plan)), prepared.plan_sha256, 'Prepared plan bytes do not match their identity');",
    f=>{const d=f.json(f.stage().prepared_journal.path);d.plan.guard_fixture_marker='changed-plan';f.relinkPrepared(d,{updatePlanHash:false});});
  add('changed_plan_receipt_identity','changed_plan_identity','Recompute the altered plan and journal identities but keep the receipt original plan identity.',
    "assert.equal(prepared.plan_sha256, selected.plan_sha256, 'Receipt and journal plan identities differ');",
    f=>{const d=f.json(f.stage().prepared_journal.path);d.plan.guard_fixture_marker='changed-plan';f.relinkPrepared(d,{updateCommitPlan:false});});
  add('partial_prepared_manifest','partial_prepared_manifest','Remove one plan, prepared and state target, rebind all hashes, and retain the full authoritative receipt manifest.',
    "if (selected.target_manifest) assert.deepEqual(manifest, selected.target_manifest, 'Receipt target manifest differs from prepared plan');",
    f=>{const d=f.json(f.stage().prepared_journal.path);const removed=d.plan.entries.pop();d.entries.pop();d.plan.allowed_paths=d.plan.allowed_paths.filter(p=>p!==removed.path);
      f.relinkPrepared(d,{journalChange:j=>{j.targets=j.targets.filter(row=>row.path!==removed.path);}});});
  add('partial_installed_targets','partial_installed_targets','Remove a durable evidence installed pin outside the five explicitly named game/test targets.',
    "assert.deepEqual(sorted(stage.installed_targets), sorted(complete), 'Installed target pins must equal the complete authoritative bag manifest');",
    f=>{const row=installedOutsideNamed(f);assert(row);f.stage().installed_targets=f.stage().installed_targets.filter(p=>p.path!==row.path);});
  add('extra_installed_target','extra_installed_target','Add an unrelated genuine pinned file to installed_targets.',
    "assert.deepEqual(sorted(stage.installed_targets), sorted(complete), 'Installed target pins must equal the complete authoritative bag manifest');",
    f=>{const names=new Set(f.stage().installed_targets.map(row=>row.path));const extra=f.binding.input_files.find(row=>!names.has(row.path));assert(extra);f.stage().installed_targets.push(clone(extra));});
  for(const suffix of ['exact','case_alias'])
    add('duplicate_installed_target_'+suffix,'duplicate_installed_target','Duplicate one installed pin using '+suffix+' path spelling.',
      'assert.equal(new Set(stage.installed_targets.map(pin => pin.path.toLowerCase())).size, stage.installed_targets.length);',
      f=>{const p=clone(f.stage().installed_targets[0]);if(suffix==='case_alias')p.path=p.path.toUpperCase();f.stage().installed_targets.push(p);});
  for(const suffix of ['bytes','hash'])
    add('wrong_installed_'+suffix,'wrong_installed_bytes_or_hash','Change installed '+suffix+' while preserving genuine manifest and actual file bytes.',
      "assert.deepEqual(sorted(stage.installed_targets), sorted(complete), 'Installed target pins must equal the complete authoritative bag manifest');",
      f=>{const p=f.stage().installed_targets[0];if(suffix==='bytes')p.bytes++;else p.raw_sha256=differentHash(p.raw_sha256);});
  add('changed_installed_file','changed_installed_file','Append one byte to a cached installed file without refreshing its captured pin.',
    'assert.equal(bytes.length, pin.bytes, pin.path);',
    f=>{const p=installedOutsideNamed(f).path;f.write(p,Buffer.concat([f.read(p),Buffer.from('\n')]));},
    {classification:'intentional_stale_byte_pin_integrity_guard'});
  add('unbound_journal_copy','unbound_journal_copy','Select exact in-memory journal copies and omit their mapping rows.',
    "assert.deepEqual(stage.journal_copies, copies, 'Explicit exact-content journal-copy binding required; no unused aliases');",
    f=>{f.exactCopies('shopping_bag');f.stage().journal_copies=[];});
  add('changed_journal_copy','changed_journal_copy','Alter selected copied state and rebind receipt/persisted hashes so original-versus-copy byte comparison is reached.',
    "assert.deepEqual(bytes, original, 'Durable journal copy differs from actual original');",
    f=>{f.exactCopies('shopping_bag');const stage=f.stage(),p=stage.committed_journal.path,d=f.json(p);d.guard_fixture_marker='copy-differs-from-original';
      const pin=f.putEvidence(p,d);stage.journal_copies[0].bytes=pin.bytes;stage.journal_copies[0].raw_sha256=pin.raw_sha256;
      const commit=f.json(stage.committed_receipt.path);commit.state.sha256=pin.raw_sha256;commit.journal.state=clone(commit.state);f.relinkCommit(commit);});
  add('unused_journal_alias','unused_journal_alias','Add a copy mapping even though the original journal is selected.',
    "assert.deepEqual(stage.journal_copies, copies, 'Explicit exact-content journal-copy binding required; no unused aliases');",
    f=>{const p=f.stage().committed_journal;f.stage().journal_copies.push({kind:'committed_journal',source_path:p.path,target_path:p.path,bytes:p.bytes,raw_sha256:p.raw_sha256});});
  add('wrong_bag_receipt_schema','wrong_bag_receipt_schema','Use the fourth10 schema identifier for the bag predecessor.',
    "assert.equal(stage.receipt_schema, 'shopping_bag_top_level_commit_and_persisted_input_v1');",
    f=>{f.stage().receipt_schema='foundation02_fourth10_nested_result_v1';});
  add('nested_bag_compatibility_receipt','wrong_bag_receipt_schema','Add a fabricated result wrapper to genuine top-level bag fields and rebind related persisted hashes.',
    "assert.equal(Object.hasOwn(commit, 'result'), false, 'Use the genuine top-level bag receipt');",
    f=>{const d=f.json(f.stage().committed_receipt.path);d.result={status:'committed',committed:true};f.relinkCommit(d);});
  add('wrong_bag_persisted_input','wrong_bag_persisted_input','Rehash altered persisted input bytes but leave the genuine success receipt input identity.',
    'assert.equal(stage.persisted_input.raw_sha256, persisted.input_sha256);',
    f=>{const p=f.stage().persisted_input.path,d=f.json(p);d.guard_fixture_marker='different-input';f.putEvidence(p,d);});
  add('wrong_bag_persisted_source','wrong_bag_persisted_input','Rehash altered source bytes but leave the genuine success receipt source identity.',
    'assert.equal(stage.persisted_source.raw_sha256, persisted.source_sha256);',
    f=>{const p=f.stage().persisted_source.path;f.putEvidence(p,Buffer.concat([f.read(p),Buffer.from('\n// In-memory identity fixture.\n')]));});
  add('persisted_commit_mismatch','persisted_commit_or_state_mismatch','Rebind persisted input/receipt while selecting a different committed receipt path.',
    'assert.equal(persistedInput.commit_receipt.path, stage.committed_receipt.path);',
    f=>f.editPersistedInput(d=>{d.commit_receipt.path=f.binding.predecessors.fourth10.committed_receipt.path;}));
  add('persisted_state_mismatch','persisted_commit_or_state_mismatch','Rebind persisted input/receipt while changing the selected committed-state hash.',
    'assert.equal(persistedInput.committed_journal.sha256, commit.state.sha256);',
    f=>f.editPersistedInput(d=>{d.committed_journal.sha256=differentHash(d.committed_journal.sha256);}));
  for(const suffix of ['omission','changed_hash'])
    add('persisted_target_'+suffix,'persisted_target_omission','Rebind input/receipt hashes after '+suffix+' for one committed target.',
      "for (const row of commit.target_manifest) assert.equal(persistedInput.expected_inputs[row.path], row.after.sha256, 'Persisted input omits or changes a committed target: ' + row.path);",
      f=>f.editPersistedInput(d=>{const p=f.stage().installed_targets[0].path;if(suffix==='omission')delete d.expected_inputs[p];else d.expected_inputs[p]=differentHash(d.expected_inputs[p]);}));
  for(const [suffix,key,value] of [['exit','exit_code',1],['error','error','in-memory command error'],['signal','signal','SIGTERM']])
    add('persisted_command_'+suffix,'persisted_command_failure','Rebind success receipt after changing command '+key+'.',
      'assert.equal(command.'+key+', '+(key==='exit_code'?'0':'null')+');',
      f=>f.editPersisted(d=>{d.commands[0][key]=value;}));
  add('persisted_command_log_mismatch','persisted_command_failure','Change cached command log and refresh its baseline pin while retaining the receipt log hash.',
    'assert.equal(sha(read(log)), command.log_sha256, log);',
    f=>{const stage=f.stage(),receipt=f.json(stage.persisted_receipt.path);const p=path.posix.dirname(stage.persisted_receipt.path)+'/'+receipt.commands[0].log;
      f.putEvidence(p,Buffer.concat([f.read(p),Buffer.from('\nfixture-log-change\n')]));});
  add('persisted_postcheck_failure','persisted_postcheck_failure','Rebind receipt with a nonnull postcheck_error.',
    "assert.equal(persisted.postcheck_error, null);",
    f=>f.editPersisted(d=>{d.postcheck_error='in-memory postcheck failure';}));
  for(const field of ['fail','cancelled','skipped'])
    add('persisted_tests_'+field,'persisted_postcheck_failure','Rebind receipt with one '+field+' test counter.',
      "for (const key of ['fail', 'cancelled', 'skipped']) assert.equal(persisted.tests[key], 0);",
      f=>f.editPersisted(d=>{d.tests[field]=1;}));
  add('later_journal_state_initial','later_journal_state','Append a later numbered filename only to the cached directory before openSession.',
    "assert.equal(names.at(-1), path.posix.basename(canonicalState), 'Selected committed state is not the latest actual journal state');",
    laterState,{classification:'directory_snapshot_semantic_guard'});
  add('later_journal_state_recheck','later_journal_state','Open the genuine session, then append a later filename only before recheck.',
    "const names = fs.readdirSync(at(path.posix.dirname(state))).filter(name => /^\\d{6}-[a-z-]+\\.json$/.test(name)).sort();assert.equal(names.at(-1), path.posix.basename(state));",
    null,{exact:true,afterOpen:laterState,classification:'directory_snapshot_recheck_guard'});
  add('unbound_root_template','unbound_template','Use the exact untouched frozen root-input template bytes.',
    "assert.equal(input.status, 'root_authorized_one_shot_scratch_preparation');",
    f=>{f.write(f.inputPath,f.read(PREP+'/root-input.template.json'));f.inputHash=sha(f.read(f.inputPath));},
    {exact:true,classification:'untouched_unbound_template'});
  add('unbound_binding_template','unbound_template','Point the real root input at the exact untouched frozen binding template.',
    "assert.equal(binding.status, 'root_bound_actual_post_bag_persisted_baseline');",
    f=>{f.input.binding=f.descriptor(PREP+'/actual-baseline-binding.template.json');f.rootOnly=true;},
    {classification:'untouched_unbound_template'});
  add('malformed_root_hash',null,'Supply a syntactically invalid caller root-input hash.',
    'assert.match(inputHash, /^[a-f0-9]{64}$/);',
    f=>{f.inputHash='not-a-sha256';},{exact:true,classification:'malformed_hash_syntax_control'});
  add('wrong_root_hash',null,'Supply a valid SHA256-shaped hash that differs from the exact root-input bytes.',
    'const inputBytes = fs.readFileSync(at(inputPath));assert.equal(sha(inputBytes), inputHash);',
    f=>{f.inputHash=differentHash(f.inputHash);},{exact:true,classification:'valid_hash_wrong_bytes_control'});
  add('malformed_binding_pin_hash',null,'Use a malformed binding-pin digest with a correctly rebound root input.',
    'assert(pin && /^[a-f0-9]{64}$/.test(pin.raw_sha256));',
    f=>{f.input.binding.raw_sha256='invalid';f.rootOnly=true;},{classification:'malformed_hash_syntax_control'});
  return list;
}
main();
