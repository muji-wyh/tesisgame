'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {codec,assertAncestors,contractInventory,DECISIONS,GENERATED,PIN,pinSource} = require('../tools/professional-domain/contract.cjs');
const gates = require('../tools/professional-domain/release-gates.cjs');
const snapshot = require('../tools/professional-domain/snapshot.cjs');
const {compile} = require('../tools/professional-domain/compiler.cjs');
const {audit} = require('../tools/professional-domain/audit.cjs');
const {sourceModel} = require('../tools/professional-domain/source-model.cjs');
const {prepareRelease,verifyPreparedRelease} = require('../tools/professional-domain/package.cjs');
const rootDir = path.resolve(__dirname, '..');
// These test-only builders preserve the previously audited synthetic fixture
// semantics while using only production tools and freshly copied source bytes.
const LABEL = 'SYNTHETIC FIXTURE ONLY - no content, media, human, or specialist approval';
const read = (root,relative) => JSON.parse(fs.readFileSync(path.join(root,relative),'utf8'));
const write = (root,relative,value) => {
  const filename = path.join(root,relative); fs.mkdirSync(path.dirname(filename),{recursive:true});
  fs.writeFileSync(filename,JSON.stringify(value,null,2)+'\n');
};
function clone(source,destination) {
  if (fs.existsSync(destination)) throw Error('Fixture destination exists');
  assertAncestors(path.dirname(destination));
  const before = gates.fullInventory(source);
  fs.mkdirSync(destination);
  for (const entry of before) {
    const from = path.join(source,entry.path), to = path.join(destination,entry.path);
    fs.mkdirSync(path.dirname(to),{recursive:true}); fs.copyFileSync(from,to,fs.constants.COPYFILE_EXCL);
  }
  gates.assertStable(source,before); gates.assertStable(destination,before); return before;
}
function resource(root,asset,kind) {
  const relative = asset.path.slice(6), raw = fs.readFileSync(path.join(root,relative));
  if (codec.sha256(raw) !== asset.sha256) throw Error('Synthetic fixture source asset differs');
  if (kind === 'image') {
    if (!raw.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) throw Error('Fixture image must be actual PNG bytes');
    const width = raw.readUInt32BE(16), height = raw.readUInt32BE(20);
    return {id:'sha256:'+asset.sha256,sha256:asset.sha256,path:relative,kind,format:'png',compressed_bytes:raw.length,decoded_bytes:width*height*8,width,height};
  }
  if (raw.toString('ascii',0,4)!=='RIFF' || raw.toString('ascii',8,12)!=='WAVE') throw Error('Fixture audio must be actual WAV bytes');
  let channels,sample_rate,bits,dataSize;
  for (let at=12;at+8<=raw.length;) {
    const name=raw.toString('ascii',at,at+4),size=raw.readUInt32LE(at+4),start=at+8;
    if (start+size>raw.length) throw Error('Truncated fixture WAV');
    if (name==='fmt ') { if(raw.readUInt16LE(start)!==1)throw Error('Fixture WAV requires PCM'); channels=raw.readUInt16LE(start+2);sample_rate=raw.readUInt32LE(start+4);bits=raw.readUInt16LE(start+14); }
    if(name==='data')dataSize=size;
    at=start+size+(size%2);
  }
  if(bits!==16 || !channels || !sample_rate || !dataSize || dataSize%(channels*2))throw Error('Fixture WAV metadata invalid');
  const frames=dataSize/(channels*2);
  return {id:'sha256:'+asset.sha256,sha256:asset.sha256,path:relative,kind,format:'wav',compressed_bytes:raw.length,decoded_bytes:dataSize,frames,channels,sample_rate};
}
function syntheticReady(source,destination) {
  const basis = clone(source,destination), catalog=read(destination,'data/professional/catalog.json');
  const coursePath=catalog.courses.find(item=>item.id==='retail').manifest.slice(6),course=read(destination,coursePath),module=course.modules.find(item=>item.id==='module03');
  if(module.status!=='draft')throw Error('Synthetic fixture requires a draft Retail03 basis');
  const themes=read(destination,catalog.themes.slice(6)),theme=themes.profiles.find(item=>item.course_id==='retail');
  if(theme.status!=='ready' || theme.ambient_motion.status!=='ready')throw Error('Fixture requires copied reviewed Retail theme dependencies');
  const envelopes=new Map([...catalog.lexeme_files,...catalog.expression_files].map(file=>[file.slice(6),read(destination,file.slice(6))]));
  const lexemes=[...envelopes.values()].flatMap(value=>value.lexemes||[]),expressions=[...envelopes.values()].flatMap(value=>value.expressions||[]);
  const byId=new Map(lexemes.map(item=>[item.id,item])),selected=module.lexeme_ids.map(id=>byId.get(id));
  const image=structuredClone(selected.find(item=>item.media.image.status==='integrated').media.image);
  const audio=structuredClone(selected.find(item=>item.media.audio.status==='integrated').media.audio);
  const syntheticReview=()=>({status:'reviewed',language:'reviewed',domain:'reviewed',reviewer:LABEL,reviewed_at:'2026-10-16'});
  const mediaReview=()=>({status:'reviewed',reviewer:LABEL,reviewed_at:'2026-10-16'});
  const decorate=asset=>({...structuredClone(asset),review:mediaReview(),adaptations:[...(asset.adaptations||[]),LABEL+'; genuine sourced bytes deliberately reused to exercise gate contracts, not sense-appropriate delivery.']});
  const termIds=new Set(module.lexeme_ids),expressionIds=new Set(module.expression_ids);
  for(const item of selected) {
    if(!item.morphology)throw Error('Fixture basis is missing authored morphology');
    item.review=syntheticReview(); item.morphology.review={...item.morphology.review,...mediaReview()};
    item.practice_modes=['phrase'];
    item.media.image={...decorate(image),brief:LABEL+'; this image is a technical dependency only.',picture_suitable:false};
    item.media.audio=decorate(audio);
    item.references=[{source_id:item.references[0].source_id,status:'verified',scope:LABEL+'; structural reference assertion for tests only.'}];
    item.editorial_notes=LABEL;
  }
  for(const item of expressions.filter(item=>expressionIds.has(item.id))) {
    const position=module.expression_ids.indexOf(item.id),ids=module.lexeme_ids.slice(position*5,position*5+5);
    item.text='Synthetic fixture: '+ids.map(id=>byId.get(id).text).join('; ')+'.';
    item.meaning=LABEL; item.context=LABEL;item.focus_lexeme_ids=ids;item.review=syntheticReview();item.media.audio=decorate(audio);
    item.references=[{source_id:item.references[0].source_id,status:'verified',scope:LABEL+'; structural reference assertion for tests only.'}];
    item.tokens=[...item.text.matchAll(/\S+/g)].map((match,index)=>({index,text:match[0],start:match.index,end:match.index+match[0].length}));
  }
  for(const [file,envelope] of envelopes) if((envelope.lexemes||[]).some(item=>termIds.has(item.id)) || (envelope.expressions||[]).some(item=>expressionIds.has(item.id)))write(destination,file,envelope);
  const assets=[['image',image],['audio',audio],...Object.values(theme.art).map(asset=>['image',asset]),...theme.ambient_motion.clips.map(clip=>['image',clip.image])];
  const resources=[...new Map(assets.map(([kind,asset])=>[asset.sha256,resource(destination,asset,kind)])).values()];
  const manifest={schema_version:1,course_id:'retail',module_id:'module03',curriculum_revision:course.curriculum_revision,resources};
  const manifestPath='data/professional/media-manifests/synthetic-retail03-only.json';write(destination,manifestPath,manifest);
  module.status='ready';module.title='SYNTHETIC FIXTURE ONLY - '+module.title;
  module.media_manifest={path:'res://'+manifestPath,sha256:codec.sha256(fs.readFileSync(path.join(destination,manifestPath)))};
  write(destination,coursePath,course);
  write(destination,'scratch-fixture.json',{schema_version:1,label:LABEL,production_authority:false,source_snapshot_sha256:codec.digest(basis),
    synthetic_module:'retail/module03',synthetic_fields:['review','references','phrase-only exercise mapping','expression text and token mapping','record media association','module ready status','media manifest'],
    actual_assets_reused:resources.map(row=>({path:row.path,sha256:row.sha256})),
    prohibited_uses:['production content','app or export trust','human or specialist approval','sense-appropriate artwork or speech claim']});
  const result=gates.inspect(destination);
  if(result.professionalAudit.summary.ready_modules!==1)throw Error('Fixture must exercise exactly one ready module');
  return {label:LABEL,source_snapshot_sha256:codec.digest(basis),full_inventory_sha256:codec.digest(result.fullInventory),
    ready_modules:1,professional_summary:result.professionalAudit.summary,synthetic_module:'retail/module03'};
}

test('Professional domain release preserves source, package and application-pin authority boundaries', async t => {
  const evidenceBase = path.join(rootDir, 'build/professional-english/domain-application-release-r01');
  fs.mkdirSync(evidenceBase, {recursive:true});
  const evidence = fs.mkdtempSync(path.join(evidenceBase, 'node-attempt-'));
  const beforeContracts = contractInventory();
  const source = path.join(evidence, 'draft-source');
  const captured = snapshot.freeze(rootDir, source);
  fs.writeFileSync(path.join(evidence, 'source-capture.json'), codec.encode(captured), {flag:'wx'});
  const output = path.join(evidence, 'draft-package');
  let compilation, checked, readySource, readyOutput, readyResult;
  const packageCopy = name => {
    const destination = path.join(evidence, name);
    fs.cpSync(output, destination, {recursive:true,errorOnExist:true,force:false});
    return destination;
  };
  const sourceCopy = name => {
    const destination = path.join(evidence, name); clone(source,destination); return destination;
  };
  const mutateJSON = (directory, relative, change) => {
    const value = read(directory, relative); change(value); write(directory, relative, value);
  };
  await t.test('complete current source compiles and independently audits as 200 unavailable modules', () => {
    compilation = compile(source, output); checked = audit(source, output);
    assert.equal(checked.modules, 200); assert.equal(checked.ready_modules, 0); assert.equal(checked.unavailable_modules, 200);
    assert.deepEqual(checked.artifact_inventory.map(item => item.path), ['index.json','release.json','themes.json']);
    assert.deepEqual(checked.accepted_ids, []); assert.equal(checked.lexical_exceptions, 0); assert.equal(checked.expression_exceptions, 0);
    assert.deepEqual(checked.artifact_inventory, compilation.artifacts);
    assert.deepEqual([...checked.source_inventory,...checked.supporting_inventory].sort((a,b) => a.path < b.path ? -1 : 1), captured.full_inventory);
    assert(fs.readFileSync(path.join(output,'themes.json')).equals(fs.readFileSync(path.join(source,'data/professional/themes.json'))));
  });
  await t.test('fresh output and snapshot paths cannot overwrite retained evidence', () => {
    assert.throws(() => compile(source,output), /exists/);
    assert.throws(() => snapshot.freeze(rootDir,source), /exists/);
    assert.throws(() => compile(source,path.join(source,'nested')), /disjoint/);
    assert.throws(() => compile(source,path.join(evidence,'bad-options'), {accepted_ids:['any']}), /options/);
    assert.throws(() => audit(source,output,{accepted_ids:['any']}), /options/);
  });
  for (const [name, mutate] of [
    ['nonempty decisions', directory => mutateJSON(directory, DECISIONS, value => value.entries.push({lexeme_id:'retail.cash_register.n.01',acceptance:null}))],
    ['orphan governed source', directory => write(directory,'data/professional/lexemes/orphan.json',{schema_version:1,lexemes:[]})],
    ['missing selected source', directory => { const selected = read(directory,'data/professional/courses/retail.json').modules[2].lexeme_files[0].slice(6); fs.renameSync(path.join(directory,selected),path.join(directory,'retained-retail.json')); }],
    ['duplicate module membership', directory => mutateJSON(directory,'data/professional/courses/retail.json',course => { course.modules[2].lexeme_ids[1] = course.modules[2].lexeme_ids[0]; })]
  ]) await t.test(name + ' fails independent source reconstruction', () => {
    const directory = sourceCopy('source-' + name.replaceAll(' ','-')); mutate(directory);
    assert.throws(() => sourceModel(directory));
    assert.throws(() => compile(directory,path.join(evidence,'reject-' + name.replaceAll(' ','-'))));
  });
  await t.test('promoting a real incomplete module fails unchanged readiness/media gates', () => {
    const directory = sourceCopy('incomplete-ready');
    mutateJSON(directory,'data/professional/courses/retail.json',course => { course.modules[2].status = 'ready'; });
    assert.throws(() => compile(directory,path.join(evidence,'incomplete-ready-output')), /release gates rejected/);
  });
  for (const [name, mutate] of [
    ['changed descriptor pin target', directory => mutateJSON(directory,'release.json',value => { value.index.sha256 = '0'.repeat(64); })],
    ['same-length theme corruption', directory => { const file = path.join(directory,'themes.json'), bytes = fs.readFileSync(file); bytes[20] ^= 1; fs.writeFileSync(file,bytes); }],
    ['invented unavailable payload', directory => mutateJSON(directory,'index.json',value => { value.modules[0].payload = {path:'modules/'+'0'.repeat(64)+'.json',bytes:1,sha256:'0'.repeat(64)}; })],
    ['extra generated member', directory => fs.writeFileSync(path.join(directory,'extra.json'),'{}')],
    ['empty generated directory', directory => fs.mkdirSync(path.join(directory,'modules'))],
    ['missing index', directory => fs.renameSync(path.join(directory,'index.json'),path.join(directory,'retained-index.json'))]
  ]) await t.test(name + ' cannot pass the independent package audit', () => {
    const directory = packageCopy('package-' + name.replaceAll(' ','-')); mutate(directory);
    assert.throws(() => audit(source,directory));
  });
  await t.test('hash-rebound index availability still must equal current source status', () => {
    const directory = packageCopy('rebound-unavailable-index');
    const index = read(directory,'index.json'); index.modules[0].source_status = 'planned';
    fs.writeFileSync(path.join(directory,'index.json'),codec.encode(index));
    const release = read(directory,'release.json');
    release.artifacts = gates.fullInventory(directory).filter(value => value.path !== 'release.json');
    release.index = release.artifacts.find(value => value.path === 'index.json');
    fs.writeFileSync(path.join(directory,'release.json'),codec.encode(release));
    assert.throws(() => audit(source,directory), /Unavailable module status/);
  });
  await t.test('compiler catches concurrent source change after its source load', () => {
    const directory = sourceCopy('concurrent-compiler');
    assert.throws(() => compile(directory,path.join(evidence,'concurrent-compiler-output'),{checkpoint(stage) {
      if (stage === 'after-source-load') mutateJSON(directory,'data/professional/courses/retail.json',course => { course.title += ' changed'; });
    }}), /drift/);
  });
  await t.test('auditor catches output drift after reconstructing expected artifacts', () => {
    const directory = packageCopy('concurrent-auditor'); let mutated = false;
    assert.throws(() => audit(source,directory,{checkpoint(stage) {
      if (stage === 'output_reconstructed') { fs.appendFileSync(path.join(directory,'index.json'),' '); mutated = true; }
    }}));
    assert.equal(mutated,true);
  });
  await t.test('separate copied synthetic ready fixture passes the real compiler and independent media gates', () => {
    readySource = path.join(evidence,'synthetic-ready-source'); syntheticReady(source,readySource);
    readyOutput = path.join(evidence,'synthetic-ready-package');
    compile(readySource,readyOutput); readyResult = audit(readySource,readyOutput);
    assert.equal(readyResult.ready_modules,1); assert.equal(readyResult.unavailable_modules,199);
    assert.equal(readyResult.lexical_domain_rows,50); assert.equal(readyResult.expression_domain_rows,10);
    assert.equal(readyResult.closures[0].cold_opens,5);
    assert(readyResult.closures[0].cold_encoded_bytes <= 2 * 1024 * 1024);
    const index = read(readyOutput,'index.json'), row = index.modules.find(value => value.state === 'ready');
    assert(fs.readFileSync(path.join(readyOutput,row.media_manifest.path)).equals(fs.readFileSync(path.join(readySource,row.media_manifest.source_path.slice(6)))));
  });
  await t.test('rebinding changed selected policy rows does not fool independent reconstruction', () => {
    const directory = path.join(evidence,'rebound-ready-package'); fs.cpSync(readyOutput,directory,{recursive:true,errorOnExist:true,force:false});
    const index = read(directory,'index.json'), row = index.modules.find(value => value.state === 'ready');
    const payload = read(directory,row.payload.path); payload.lexical_domain[0].exception = {accepted:true};
    const raw = codec.encode(payload), newPath = 'modules/' + codec.sha256(raw) + '.json';
    fs.renameSync(path.join(directory,row.payload.path),path.join(evidence,'retained-original-payload.json'));
    fs.writeFileSync(path.join(directory,newPath),raw,{flag:'wx'});
    row.payload = {path:newPath,bytes:raw.length,sha256:codec.sha256(raw)};
    fs.writeFileSync(path.join(directory,'index.json'),codec.encode(index));
    const release = read(directory,'release.json');
    release.artifacts = gates.fullInventory(directory).filter(value => value.path !== 'release.json');
    release.index = release.artifacts.find(value => value.path === 'index.json');
    fs.writeFileSync(path.join(directory,'release.json'),codec.encode(release));
    assert.throws(() => audit(readySource,directory), /reconstructed complete selected payload/);
  });
  await t.test('missing copied source media cannot be legitimized by a new compile', () => {
    const directory = path.join(evidence,'missing-ready-media'); clone(readySource,directory);
    const row = read(readyOutput,'index.json').modules.find(value => value.state === 'ready');
    fs.renameSync(path.join(directory,row.media_manifest.source_path.slice(6)),path.join(directory,'retained-media-manifest.json'));
    assert.throws(() => compile(directory,path.join(evidence,'missing-ready-media-output')), /release gates rejected/);
  });
  await t.test('strict emitted codec preserves bounded values and refuses ambiguous JSON', () => {
    const value = {ascii:'quote"\\\n',unicode:'\u{1f30d} café',integer:Number.MAX_SAFE_INTEGER,minimum:Number.MIN_SAFE_INTEGER,truth:true,empty:null,nested:{parts:[{start:0,end:3}]}};
    assert.deepEqual(codec.strictParse(codec.encode(value)),value);
    for (const raw of ['{"a":1,"a":2}','{"x":9007199254740992}','{"x":0.5}','{"x":"\\ud800"}']) assert.throws(() => codec.strictParse(raw));
    assert.throws(() => codec.encode({exception:undefined}));
  });
  assert.deepEqual(snapshot.observe(rootDir),captured.full_inventory,'Live production source bytes remain unchanged');
  assert.deepEqual(contractInventory(),beforeContracts,'All production contract files remain unchanged during tests');
  fs.writeFileSync(path.join(evidence,'static-verification.json'),codec.encode({schema_version:1,source_files:captured.full_inventory.length,
    source_inventory_sha256:codec.digest(captured.full_inventory),contracts_sha256:codec.digest(beforeContracts),source_and_contracts_unchanged:true,
    production_generation:false,native_execution:false,web_export:false}),{flag:'wx'});
  t.diagnostic('Retained Professional domain evidence: ' + evidence);
});

test('Professional domain package installation preserves previous releases and refuses stale authority', () => {
  const evidenceBase = path.join(rootDir, 'build/professional-english/domain-application-release-r01');
  fs.mkdirSync(evidenceBase,{recursive:true});
  const evidence = fs.mkdtempSync(path.join(evidenceBase,'package-attempt-'));
  const beforeContracts = contractInventory();
  const simulatedRoot = path.join(evidence,'simulated-application');
  const captured = snapshot.freeze(rootDir,simulatedRoot);
  const mutateJSON = (directory, relative, change) => { const value = read(directory,relative); change(value); write(directory,relative,value); };
  fs.writeFileSync(path.join(evidence,'source-capture.json'),codec.encode(captured),{flag:'wx'});
    fs.mkdirSync(path.join(simulatedRoot,'scripts'),{recursive:true}); fs.mkdirSync(path.join(simulatedRoot,'build'),{recursive:true});
    const first = prepareRelease({rootDir:simulatedRoot,workDir:path.join(simulatedRoot,'build/first')});
    verifyPreparedRelease({rootDir:simulatedRoot,report:first});
    assert.equal(first.ready_modules,0); assert.equal(first.unavailable_modules,200);
    assert(fs.readFileSync(path.join(simulatedRoot,PIN)).equals(pinSource(first.descriptor)));
    assert.throws(() => prepareRelease({rootDir:simulatedRoot,workDir:first.work_dir}), /exists/);
    const second = prepareRelease({rootDir:simulatedRoot,workDir:path.join(simulatedRoot,'build/second')});
    assert.deepEqual(first.descriptor,second.descriptor);
    assert(fs.existsSync(path.join(second.work_dir,'previous/generated/release.json')));
    const previousInventory = gates.fullInventory(path.join(simulatedRoot,GENERATED));
    const previousPin = fs.readFileSync(path.join(simulatedRoot,PIN));
    const originalRename = fs.renameSync;
    try {
      fs.renameSync = function(from,to) {
        if (from === path.join(simulatedRoot,'build/rollback/professional_domain_release.gd') && to === path.join(simulatedRoot,PIN)) throw Error('Injected pin install failure');
        return originalRename.call(this,from,to);
      };
      assert.throws(() => prepareRelease({rootDir:simulatedRoot,workDir:path.join(simulatedRoot,'build/rollback')}), /Injected pin install failure/);
    } finally { fs.renameSync = originalRename; }
    assert.deepEqual(gates.fullInventory(path.join(simulatedRoot,GENERATED)),previousInventory);
    assert(fs.readFileSync(path.join(simulatedRoot,PIN)).equals(previousPin));
    const courseFile = path.join(simulatedRoot,'data/professional/courses/retail.json');
    const courseBefore = fs.readFileSync(courseFile), originalObserve = snapshot.observe;
    try {
      snapshot.observe = function(observedRoot) {
        if (path.resolve(observedRoot) === simulatedRoot) mutateJSON(simulatedRoot,'data/professional/courses/retail.json',course => { course.title += ' changed during preparation'; });
        return originalObserve(observedRoot);
      };
      assert.throws(() => prepareRelease({rootDir:simulatedRoot,workDir:path.join(simulatedRoot,'build/source-drift')}), /Live source drift before installation/);
    } finally { snapshot.observe = originalObserve; fs.writeFileSync(courseFile,courseBefore); }
    assert.deepEqual(gates.fullInventory(path.join(simulatedRoot,GENERATED)),previousInventory);
    assert(fs.readFileSync(path.join(simulatedRoot,PIN)).equals(previousPin));
    const forged = structuredClone(second); forged.accepted_ids = ['caller-added'];
    assert.throws(() => verifyPreparedRelease({rootDir:simulatedRoot,report:forged}), /report mismatch/);
    const pinBefore = fs.readFileSync(path.join(simulatedRoot,PIN));
    fs.appendFileSync(path.join(simulatedRoot,PIN),'# changed\n');
    assert.throws(() => verifyPreparedRelease({rootDir:simulatedRoot,report:second}), /pin changed/);
    fs.writeFileSync(path.join(simulatedRoot,PIN),pinBefore);
    mutateJSON(simulatedRoot,DECISIONS,value => { value.entries = [{acceptance:'caller-added'}]; });
    assert.throws(() => prepareRelease({rootDir:simulatedRoot,workDir:path.join(simulatedRoot,'build/invalid')}), /empty decisions/);
    assert(fs.readFileSync(path.join(simulatedRoot,PIN)).equals(pinBefore));
    assert.equal(codec.sha256(fs.readFileSync(path.join(simulatedRoot,GENERATED,'release.json'))),second.descriptor.sha256);
    assert.throws(() => verifyPreparedRelease({rootDir:simulatedRoot,report:second}), /empty decisions/);
  assert.deepEqual(snapshot.observe(rootDir),captured.full_inventory,'Live sources remain unchanged during package tests');
  assert.deepEqual(contractInventory(),beforeContracts,'Domain contracts remain unchanged during package tests');
  fs.writeFileSync(path.join(evidence,'static-verification.json'),codec.encode({schema_version:1,source_files:captured.full_inventory.length,
    source_inventory_sha256:codec.digest(captured.full_inventory),contracts_sha256:codec.digest(beforeContracts),source_and_contracts_unchanged:true,
    production_generation:false,native_execution:false,web_export:false}),{flag:'wx'});
  console.log('Retained package-only evidence: ' + evidence);
});
