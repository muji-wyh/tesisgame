'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const base=__dirname,root=path.resolve(base,'../../../..');
assert.equal(root.toLowerCase().replaceAll('\\','/'),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8')),raw=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),hash=v=>crypto.createHash('sha256').update(JSON.stringify(v)).digest('hex');
assert.equal(raw(path.join(base,'inventory.json')),'356f6a4fddc108211e8aa8e8d9ea3de881e6627a934e08f0e4f013932231725b');
for(const item of read(path.join(base,'inventory.json')).artifacts){const file=path.join(root,item.path);assert.equal(raw(file),item.raw_sha256);if(item.json_sha256)assert.equal(hash(read(file)),item.json_sha256);}
const ledger=read(path.join(base,'language-ledger.json')),contexts=read(path.join(base,'expression-use-review.json')),pre=read(path.join(base,'preimages.json')),crosschecks=read(path.join(base,'root-source-crosschecks-r01.json'));
assert.equal(hash(ledger),'bbc8b3feab69e52fec9559d34fcc13a9424e4a2182356ef37fd3f0785c7124c8');
assert.equal(hash(contexts),'cb32bed0274a0832013c1659d451c5de1a1ff40b2191a9d4bab8e0ae6b377e3f');
const {loadProfessionalContent}=require(path.join(root,'tools/validate-professional-content.cjs')),data=loadProfessionalContent(root),lexemes=new Map(data.lexemes.map(e=>[e.id,e]));
for(const item of [...pre.selected_entries,...pre.unselected_foundation_entries,...pre.related_entries]){assert.equal(hash(item.entry),item.json_sha256);assert.deepEqual(lexemes.get(item.entry.id),item.entry);}
for(const item of [...pre.local_expressions,...pre.expression_uses]){assert.equal(hash(item.entry),item.json_sha256);assert.deepEqual(data.expressions.find(e=>e.id===item.id),item.entry);}
for(const item of pre.modules)assert.deepEqual(data.courses.find(c=>c.id===item.course_id).modules.find(m=>m.id===item.module_id),item.module);
for(const item of pre.existing_source_records)assert.deepEqual(data.sources.find(s=>s.id===item.source.id),item.source);
for(const [file,digest]of Object.entries({...pre.growth_raw_sha256,...pre.prior_artifacts_raw_sha256}))assert.equal(raw(path.join(root,file)),digest);
const changes={
feedback:{definition:"Comments or information about someone's work or idea, often used to help them improve.",difficulty:'B2'},
permission:{},
responsibility:{example:'Ordering supplies is one of my responsibilities.',difficulty:'B2'},
task:{},
role:{definition:'The function or part a person or group has in a team, organization, or activity.',difficulty:'B2'},
priority:{difficulty:'B2'},
location:{definition:'The place where someone or something is, or where an activity happens.',difficulty:'B1'},
address:{definition:'Details that identify where a person or organization is located or can receive mail.'},
signature:{difficulty:'B1'},
'time zone':{difficulty:'B2'}
};
const reasons={
feedback:'The revision covers evaluative information as well as comments, with the retained trainer/presentation example selecting ordinary response information. Both selected passages show B2. The noun stays uncountable and separate from signal feedback or feed back.',
permission:'The bounded schedule-change example selects ordinary authority-given allowance. Retain editorial A2 with Oxford A2 and Collins B1 preserved literally. This does not accept software access settings, written permission documents or consent validity.',
responsibility:'The assigned-duty meaning is clear, and one of my responsibilities naturally illustrates a countable duty without adding a plural answer form. Collins assigned duties B2 supports the proposed course placement. Blame, liability and actual authority remain separate.',
task:'The welcome-pack example selects a concrete work item. Retain A2 supported by Oxford, with the Collins B2 disagreement explicit. Difficulty and membership of a larger project are not necessary conditions. Computing task processes are excluded.',
role:'The revised person-or-group definition accommodates a department while retaining organizational function. Collins B2 supports the placement; actor A2/B1+ evidence is excluded. Neither work titles nor this lexical acceptance establish authority or professional competence.',
priority:'Retain the existing relative-importance definition and high-priority delivery example. Accept B2 as an independent editorial placement for comparison and work ordering, with no selected-source CEFR claim. Countable important-item B2 and traffic C2 are other senses; no operational priority policy is accepted.',
location:'The revision directly includes places where activities occur and matches meeting location. Accept editorial B1 using Oxford selected B1 while preserving Collins literal B1+ and its separate exact-position B2. Logical file or memory locations remain separate.',
address:'Postal or physical-location details can be spoken, so removing necessarily written improves precision. Retain the A2 course floor while preserving selected Collins A1. Electronic addresses and verbal address remain outside scope, and the ambiguous invitation expression stays held.',
signature:'The retained characteristic written-name definition and form example match the ordinary noun. Collins B1 supports placement. Signing acts, stamps, electronic authentication, style and prescription senses receive no acceptance; no legal effect is inferred.',
'time zone':'The retained shared-standard-time-region definition matches ordinary cross-location scheduling. Oxford selected B2 supports placement. Simplified 24-zone or universal one-hour-offset claims are excluded; no actual conversion or daylight-saving rule is approved.'
};
const allowed=new Set(['definition','example','difficulty','references','editorial_notes']);
const decisions=ledger.proposals.map(row=>{
 assert.equal(hash(row.before_entry),row.before_entry_json_sha256);assert.equal(hash(row.candidate_entry),row.candidate_entry_json_sha256);assert.deepEqual(lexemes.get(row.id),row.before_entry);
 assert.deepEqual(row.substantive_changes,changes[row.text]);
 for(const key of new Set([...Object.keys(row.before_entry),...Object.keys(row.candidate_entry)]))if(!allowed.has(key))assert.deepEqual(row.candidate_entry[key],row.before_entry[key],row.id+':'+key);
 for(const key of ['definition','example','difficulty'])assert.deepEqual(row.candidate_entry[key],Object.hasOwn(changes[row.text],key)?changes[row.text][key]:row.before_entry[key]);
 assert.deepEqual(row.candidate_entry.references,[...row.before_entry.references,...row.added_references]);assert.equal(row.added_references.length,2);assert.equal(row.candidate_entry.review.language,'pending');
 assert.equal(row.memberships.length,20);assert.ok(reasons[row.text]);
 return{id:row.id,text:row.text,decision:'accept_exact_author_language_candidate',candidate_entry_json_sha256:row.candidate_entry_json_sha256,before_entry_json_sha256:row.before_entry_json_sha256,reason:reasons[row.text],editorial_difficulty:row.candidate_entry.difficulty,observed_source_levels:row.difficulty_evidence.observed_selected_source_labels,production_acceptance:false};
});
assert.equal(decisions.length,10);assert.equal(ledger.proposed_additive_source_records.length,20);assert.equal(crosschecks.consultations.length,10);
assert.deepEqual(contexts.expression_ambiguity_hold_ids,['expr.customer_support.module03.08','expr.foundation.module01.06','expr.office_admin.module09.01']);assert.equal(contexts.prior_expression_hold_ids.length,9);assert.equal(contexts.uses.length,111);assert.equal(contexts.related_entry_boundaries.length,65);
const report={
 schema:1,status:'root_ten_scoped_language_acceptances_pending_guarded_delivery',date:new Date().toISOString(),reviewer:'Codex root (independent AI language review; not human or specialist approval)',root_review_recorded:true,
 author_ledger_json_sha256:hash(ledger),context_review_json_sha256:hash(contexts),author_inventory_raw_sha256:raw(path.join(base,'inventory.json')),
 decisions,accepted_candidates:decisions.map(d=>({id:d.id,candidate_json_sha256:d.candidate_entry_json_sha256,scope:'Ordinary language wording, example and editorial course difficulty; no new answer forms.'})),
 preserved_entry_ids:['supervisor.work-overseer.n','attendance.presence-record.n'],
 root_direct_source_crosschecks:crosschecks.consultations.flatMap(c=>c.urls.map(url=>({url,finding:c.observation,consulted_on:'2026-10-16',access:'root_direct_web_open_selected_passages'}))),
 root_source_crosscheck_record:{path:'root-source-crosschecks-r01.json',raw_sha256:raw(path.join(base,'root-source-crosschecks-r01.json'))},
 context_decision:'Root inspected all 111 matching expression texts and classifications, the ten local expressions (five matching and five additional), and 65 related definitions/boundaries. Preserve all expressions and focus bindings, the three new ambiguity holds and all nine historical holds. Postal/electronic addresses, ordinary allowance/software access settings, work/biological roles, physical/logical places and written/electronic signatures remain distinct. This is lexical compatibility review only; no full-expression or domain acceptance.',
 integration_scope:[
 'Integrate the exact ten accepted candidates only after root reviews guarded delivery against a fresh successful current baseline.',
 'Add the twenty exact consulted sources and preserve literal source labels. Attendance-only third10 sources remain excluded.',
 'Set only the ten language gates and narrowly scoped lexical references. Overall language/domain status follows existing not-required rules; morphology and media remain separate.',
 'Replace exact superseded pending-language notes while retaining original snapshots and recording the independent acceptance in current notes.',
 'Preserve identity, all noncandidate definitions/examples, forms, regions, practice modes, memberships, expressions, domain gates, morphology, media, Growth and module readiness.',
 'Supervisor, attendance and all twelve expression holds remain complete unchanged entries.'
 ],
 tests_executed:false,native_runtime_executed:false,production_mutated:false,shared_tests_mutated:false,baseline_bound:false,
 next_step:'Complete unbound guarded delivery and shared-test previews after successful R27; root must inspect, bind and serialize.'
};
const file=path.join(base,'root-language-review-r01.json');fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({path:file,json_sha256:hash(report),raw_sha256:raw(file),accepted:decisions.length,direct_source_crosschecks:report.root_direct_source_crosschecks.length}));
