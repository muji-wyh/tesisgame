'use strict';
// Root-owned one-shot serializer. Default invocation performs read-only preparation.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const base=path.resolve(__dirname,'..'),root=path.resolve(base,'../../../..');
const {loadProfessionalContent,auditProfessionalContent,schemaErrors}=require(path.join(root,'tools/validate-professional-content.cjs'));
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const raw=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
const serialized=x=>JSON.stringify(x,null,2)+'\n';
const relative=p=>path.relative(root,p).replaceAll('\\','/');
const writeNew=(p,x)=>fs.writeFileSync(p,serialized(x),{flag:'wx'});
const integrate=process.argv.includes('--integrate');
assert.ok(process.argv.slice(2).every(a=>a==='--integrate'),'Only --integrate is supported.');
let checks=0;
function same(a,b,label=''){assert.deepEqual(a,b,label);checks++;}
const receiptPath=path.join(base,'review-receipt.json'),approvalPath=path.join(base,'root-image-review.json'),prePath=path.join(__dirname,'preimages.json');
same(raw(receiptPath),'d20283010366f4f1dc293882c323a30102fbceea9c40e9e5e19cd0b0ca70f341');
same(raw(approvalPath),'ada7ad8dee8f16143e4c18b193651fd08260e5766bf735a389cf39c10a0d58ad');
same(raw(prePath),'1557b239cd08f9394b651ac7dd633d0c83feebd8305d08646bf44fea4c0e3ad7');
const receipt=read(receiptPath),approval=read(approvalPath),pre=read(prePath),source=read(path.join(base,'source-record.json'));
function evidence(){
  same(raw(receiptPath),approval.review_receipt_raw_sha256);
  for(const f of receipt.evidence_files){same(raw(path.join(base,f.path)),f.sha256,f.path);same(fs.statSync(path.join(base,f.path)).size,f.bytes);}
  for(const f of receipt.render_dependencies)same(raw(path.join(root,f.path)),f.sha256,f.path);
  for(const f of source.files){same(raw(f.original_path),f.sha256);same(raw(path.join(base,f.retained_path)),f.sha256);}
  for(const [p,sha] of Object.entries(pre.fourth10_dependencies))same(raw(path.join(root,p)),sha,p);
}
evidence();
same(approval.status,'accepted_exact_shelf_image_and_scoped_adaptations_for_integration');
same(approval.sense_id,'shelf.storage-surface.n');same(approval.approved_brief,receipt.approved_brief);
same(approval.image_sha256,'bddc3c2dd3b889c785195a572b95a33455c047e097e927232c735b3b43a24f04');
same(approval.image_sha256,receipt.candidate.file.sha256);same(receipt.native_validation.checks,21);same(receipt.native_validation.failures,0);
same(source.available_animations,[]);same(receipt.candidate.size,[512,309]);
const data=loadProfessionalContent(root),before=data.lexemes.find(e=>e.id===approval.sense_id);
same(before,pre.shelf_entry,'Exact shelf preimage; no audio, morphology or unrelated note drift');
same(before.media.image.status,'pending');same(before.media.image.brief,receipt.approved_brief);
same(auditProfessionalContent({rootDir:root,data}).errors,[]);
const fourthDir=path.join(root,'build/professional-english/retail-module03-morphology-review/fourth10');
const fourthRelative='data/professional/provenance/retail-module03-morphology-fourth10-2026-10-16.json';
const fourthPath=path.join(root,fourthRelative),fourthExists=fs.existsSync(fourthPath);
const changedByFourth=new Map();
// Root explicitly authorized these five later test edits. R06 did not cover them.
const authorizedLaterTests=new Set(['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/godot/professional_retail_morphology_tests.gd','tests/professional-retail-media.test.cjs','tests/godot/professional_approved_audio_tests.gd']);
const laterTestObservations=[],currentMeasured=new Map();
let fourthRecord=null,fourthReceipt=null;
if(fourthExists){
  same(raw(fourthPath),'34f16c20451400665939ab8c7f97e3317f61a9821b59317c8567800fd8edab4d','Exact completed fourth10 provenance');
  fourthRecord=read(fourthPath);fourthReceipt=read(path.join(fourthDir,'integration-receipt.json'));
  same(fourthReceipt.integrated,true);same(fourthReceipt.provenance_raw_sha256,raw(fourthPath));
  same(fourthRecord.status,'ten_exact_morphology_graphs_independently_reviewed_and_integrated');
  same(fourthRecord.independent_approval.accepted,true);
  same(fourthRecord.independent_approval.serializer_raw_sha256,pre.fourth10_dependencies[relative(path.join(fourthDir,'accept-fourth10.cjs'))]);
  same(fourthRecord.independent_approval.native_review,read(path.join(fourthDir,'root-runtime-review.json')));
  same(fourthRecord.independent_approval,read(path.join(fourthDir,'independent-acceptance.json')));
  same(fourthRecord.integration.before_registry_sha256,pre.baseline_registry_sha256);
  same(fourthRecord.integration.proposed_registry_sha256,hash(data));
  same(fourthReceipt.before_registry_sha256,pre.baseline_registry_sha256);same(fourthReceipt.proposed_registry_sha256,hash(data));
  const ledger=read(path.join(fourthDir,'morphology-ledger.json')),consultations=read(path.join(fourthDir,'source-consultations.json'));
  same(fourthRecord.independent_approval.ledger_json_sha256,hash(ledger));
  same(fourthRecord.source_consultation_ledger,consultations);
  same(fourthRecord.patches.map(p=>p.id),ledger.decisions.map(d=>d.id));same(fourthRecord.patches.length,10);
  const reversed=structuredClone(data);
  for(const [i,p]of fourthRecord.patches.entries()){
    const d=ledger.decisions[i],expected=structuredClone(d.before_entry);
    same(p.before,d.before_entry);same(p.before_sha256,hash(p.before));same(p.origin,d.resource);
    expected.morphology=structuredClone(d.candidate);
    Object.assign(expected.morphology.review,{status:'reviewed',reviewer:'Codex root (independent AI morphology review; not human or subject-matter approval)',reviewed_at:'2026-10-16',independent_review:'completed_exact_graph_and_selected_canonical_family_review',acceptance_record:fourthRelative});
    const old=p.before.morphology===null?'Morphology remains unauthored.':'The authored morphology graph remains pending review.';
    same(p.before.editorial_notes.split(old).length,2);
    expected.editorial_notes=p.before.editorial_notes.replace(old,'Independent AI morphology review was completed on 2026-10-16 for this exact graph at the documented modern-stem depth; this is not human or subject-matter approval.');
    same(p.after,expected,'Exact accepted fourth10 after entry: '+p.id);
    same(data.lexemes.find(e=>e.id===p.id),p.after);same(data.lexemeOrigins[p.id],p.origin);
    reversed.lexemes[reversed.lexemes.findIndex(e=>e.id===p.id)]=structuredClone(p.before);
  }
  const registered=consultations.sources.map(s=>({id:s.id,title:s.title,publisher:s.publisher,url:s.url,status:'consulted',consulted_on:s.consulted_at,scope:`Consultation method: ${s.access}. Section: ${s.section}. ${s.finding} Limits: ${s.limits}`,asset_license:null,assets_acquired:false}));
  same(fourthRecord.sources,registered);same(registered.length,26);same(fourthRecord.appended_source_ids,registered.map(s=>s.id));
  for(const s of registered)same(data.sources.find(item=>item.id===s.id),s);
  reversed.sources=reversed.sources.filter(s=>!fourthRecord.appended_source_ids.includes(s.id));
  same(hash(reversed),pre.baseline_registry_sha256,'Undo only exact fourth10 patches/sources to the complete frozen registry');
  const expectedFiles=[...new Set([...fourthRecord.patches.map(p=>p.origin.replace(/^res:\/\//,'')),data.catalog.sources.replace(/^res:\/\//,'')])].sort();
  same(fourthRecord.integration.files.map(f=>f.path).sort(),expectedFiles);
  same(fourthReceipt.files.map(f=>f.path).sort(),expectedFiles);
  for(const f of fourthRecord.integration.files){
    same(f.before_raw_sha256,pre.professional_json_raw_sha256[f.path]);
    const post=fourthReceipt.files.find(item=>item.path===f.path);same(raw(path.join(root,f.path)),post.raw_sha256);
    const envelope=read(path.join(root,f.path));
    if(Array.isArray(envelope.lexemes))for(const p of fourthRecord.patches.filter(p=>p.origin.replace(/^res:\/\//,'')===f.path))envelope.lexemes[envelope.lexemes.findIndex(e=>e.id===p.id)]=structuredClone(p.before);
    if(Array.isArray(envelope.sources))envelope.sources=envelope.sources.filter(s=>!fourthRecord.appended_source_ids.includes(s.id));
    same(crypto.createHash('sha256').update(serialized(envelope)).digest('hex'),f.before_raw_sha256,'Exact raw preimage reconstructed: '+f.path);
    changedByFourth.set(f.path,{before:f.before_raw_sha256,after:post.raw_sha256});
  }
}else same(hash(data),pre.baseline_registry_sha256,'Pre-fourth10 registry is exact');
const professionalFiles=[];
function collect(rel){for(const e of fs.readdirSync(path.join(root,rel),{withFileTypes:true})){const p=rel+'/'+e.name;if(e.isDirectory())collect(p);else if(e.name.endsWith('.json'))professionalFiles.push(p);}}
collect('data/professional');
same(professionalFiles.sort(),[...Object.keys(pre.professional_json_raw_sha256),...(fourthExists?[fourthRelative]:[])].sort(),'No unrecorded Professional JSON additions');
for(const [p,sha]of Object.entries(pre.professional_json_raw_sha256))same(raw(path.join(root,p)),changedByFourth.get(p)?.after||sha,p);
const validationRelative='build/professional-english/continuation-validation-r06.json',validationPath=path.join(root,validationRelative);
let validation=null;
if(fs.existsSync(validationPath)){
  same(raw(validationPath),'0cfea5a4d4a462f9c81c9c479cbd7a96728ae1ed2c870c2df7f43f30fd0f7fdb','Exact successful R06 receipt');
  validation=read(validationPath);same(validation.ok,true);same(validation.registry_before_sha256,pre.baseline_registry_sha256);same(validation.registry_after_sha256,pre.baseline_registry_sha256);
  same(validation.changed_measured_inputs,[]);same(validation.before_input_sha256,validation.after_input_sha256);same(validation.measured_input_count,Object.keys(validation.after_input_sha256).length);
  same(validation.runs.map(r=>r.name),['node','native','native-audio']);
  for(const r of validation.runs){same(r.status,0);same(r.error,null);same(r.signal,null);same(raw(path.join(root,r.log)),r.log_sha256);if(r.name==='node'){same(r.tests>0,true);same(r.pass,r.tests);same(r.fail,0);same(r.cancelled,0);same(r.skipped,0);}else{same(r.checks>0,true);same(r.failures,0);}}
  for(const [p,sha]of Object.entries(validation.after_input_sha256)){
    const current=raw(path.join(root,p));currentMeasured.set(p,current);
    const change=changedByFourth.get(p);if(change)same(change.before,sha);
    if(authorizedLaterTests.has(p))laterTestObservations.push({path:p,r06_raw_sha256:sha,current_raw_sha256:current,changed:current!==sha,coverage:current===sha?'Exact R06 bytes retained.':'Authorized later test edit; awaits R07. R06 is historical evidence only.'});
    else same(current,change?.after||sha,'R06 measured production/runtime/tools/media dependency: '+p);
  }
  for(const [p,sha]of Object.entries(pre.professional_json_raw_sha256))same(validation.after_input_sha256[p],sha,'R06 covers baseline Professional JSON: '+p);
  if(fourthExists){same(fourthRecord.independent_approval.production_validation.path,validationRelative);same(fourthRecord.independent_approval.production_validation.raw_sha256,raw(validationPath));same(fourthReceipt.production_validation_raw_sha256,raw(validationPath));}
}
const next=structuredClone(data),after=structuredClone(before),sha=approval.image_sha256,destination='professional-media/'+sha+'.png';
Object.assign(after.media.image,{status:'integrated',path:'res://'+destination,sha256:sha,source:source.source,creator:source.creator,license:source.license,acquisition_status:'integrated',review:{status:'reviewed',reviewer:approval.reviewer,reviewed_at:'2026-10-16'},adaptations:[
  'Rendered the acquired Kenney Mini Market 1.0 shelf-boxes GLB with its original colormap. Frame and visible box geometry, materials, textures and per-node transforms are preserved; only the model root is recentered.',
  'Six source carton nodes and two rear box nodes are hidden at scene level, leaving the source frame and its two front upper boxes. No replacement geometry or added text/target label is used.',
  'Camera and studio lighting emphasize one upper support surface. A 768 by 768 transparent render is cropped to focus rectangle [0,0,768,640], then alpha bounds plus a 16-pixel margin and Lanczos resizing produce 512 by 309. The crop deliberately cuts the backing panel below the selected shelf and excludes the lower shelf and feet.',
  'Root inspected eight original source views, four sparse compositions, and actual Match 126 by 72 and Memory 144 by 74 cards in unmatched/matched states. The support edge remains distinguishable with the real badge and matched alpha. This is scoped AI image review, not a participant recognition study or domain/module approval.'
]});
const old='Picture suitability and word-media production remain pending.';same(before.editorial_notes.split(old).length,2);
after.editorial_notes=before.editorial_notes.replace(old,'The shelf image has completed scoped physical-sense picture review and integration; word audio remains pending.');
const protect=e=>{const p=structuredClone(e);delete p.media.image;delete p.editorial_notes;return p;};
same(protect(after),protect(before));same(schemaErrors(after,'lexeme'),[]);
next.lexemes[next.lexemes.findIndex(e=>e.id===before.id)]=after;
for(const key of Object.keys(data))if(key!=='lexemes')same(next[key],data[key]);
same(next.lexemes.filter(e=>e.id!==before.id),data.lexemes.filter(e=>e.id!==before.id));
const target=path.join(root,'data/professional/lexemes/retail-pilot.json'),targetRaw=raw(target),envelope=read(target);
envelope.lexemes[envelope.lexemes.findIndex(e=>e.id===before.id)]=after;
const resource={id:'sha256:'+sha,sha256:sha,path:destination,kind:'image',format:'png',compressed_bytes:receipt.candidate.file.bytes,decoded_bytes:receipt.candidate.conservative_decoded_cpu_gpu_bytes,width:512,height:309};
const summary={dry_run:!integrate,checks,image_sha256:sha,before_registry_sha256:hash(data),proposed_registry_sha256:hash(next),baseline_registry_sha256:pre.baseline_registry_sha256,fourth10_traversed:fourthExists,successful_r06_verified:validation!==null,integration_ready:fourthExists&&validation!==null,required_baseline:validationRelative,later_test_observations:laterTestObservations,later_test_boundary:'Only the five explicitly root-authorized test paths may differ from R06. Record exact old/current hashes and await R07 for changed tests; all current measured files are guarded against concurrent edits.',resource,serializer_raw_sha256:raw(__filename),root_image_review_raw_sha256:raw(approvalPath),author_receipt_raw_sha256:raw(receiptPath)};
evidence();same(hash(loadProfessionalContent(root)),hash(data));same(raw(target),targetRaw);
for(const [p,sha]of currentMeasured)same(raw(path.join(root,p)),sha,'Measured file changed during preparation: '+p);
if(!integrate){summary.checks=checks;console.log(JSON.stringify(summary));process.exit(0);}
same(summary.integration_ready,true,'Root must integrate exact fourth10 after successful R06 before this image');
const provenance='data/professional/provenance/retail-shelf-image-2026-10-16.json',retained='docs/assets/sources/professional-retail-shelf';
for(const p of [provenance,retained,destination])same(fs.existsSync(path.join(root,p)),false,p);
same(raw(approvalPath),'ada7ad8dee8f16143e4c18b193651fd08260e5766bf735a389cf39c10a0d58ad');
const validationRaw=raw(validationPath),fourthRaw=raw(fourthPath);
const retainedFiles=receipt.evidence_files.map(f=>f.path).concat('review-receipt.json','root-image-review.json','delivery-r01/preimages.json','delivery-r01/integrate-reviewed.cjs','delivery-r01/HANDOFF.md','delivery-r01/preparation-receipt.json');
for(const p of retainedFiles)same(fs.existsSync(path.join(base,p)),true,p);
same(raw(target),targetRaw);same(hash(loadProfessionalContent(root)),hash(data));
for(const [p,sha]of currentMeasured)same(raw(path.join(root,p)),sha,'Measured file changed before integration: '+p);
for(const p of retainedFiles){const to=path.join(root,retained,p);fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(path.join(base,p),to,fs.constants.COPYFILE_EXCL);same(raw(to),raw(path.join(base,p)));}
fs.copyFileSync(path.join(base,receipt.candidate.file.path),path.join(root,destination),fs.constants.COPYFILE_EXCL);same(raw(path.join(root,destination)),sha);
same(raw(target),targetRaw);same(raw(validationPath),validationRaw);same(raw(fourthPath),fourthRaw);
for(const [p,sha]of currentMeasured)same(raw(path.join(root,p)),sha,'Measured file changed before registry write: '+p);
fs.writeFileSync(target,serialized(envelope));same(loadProfessionalContent(root),next);
const audit=auditProfessionalContent({rootDir:root,data:next});same(audit.errors,[]);
writeNew(path.join(root,provenance),{schema:1,status:'reviewed_image_integrated_pending_production_delivery_validation',independent_approval:approval,source_record:retained+'/source-record.json',retained_evidence:retained,resource,patches:[{id:before.id,before,after,before_sha256:hash(before),protected_fields_sha256:hash(protect(before))}],before_registry_sha256:hash(data),after_registry_sha256:hash(next),integration_guards:{serializer_raw_sha256:raw(__filename),preimages_raw_sha256:raw(prePath),baseline_registry_sha256:pre.baseline_registry_sha256,r06:{path:validationRelative,raw_sha256:validationRaw},fourth10:{path:fourthRelative,raw_sha256:fourthRaw},later_test_observations:laterTestObservations,later_test_boundary:summary.later_test_boundary},audit:{errors:0,warnings:audit.warnings.length,summary:audit.summary}});
console.log(JSON.stringify({...summary,dry_run:false,integrated:true,checks,provenance,after_registry_sha256:hash(next),images:audit.summary.integrated_word_images}));
