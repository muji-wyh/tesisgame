'use strict';
// Evidence-only capture. No production API, validator, suite, or updater is loaded.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../../../..');
if(root.replaceAll('\\','/').toLowerCase()!=='q:/.codex/worktrees/current-age-vocabulary/tesisgame')throw Error('Wrong evidence root');
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex'),hash=value=>sha(JSON.stringify(value));
const raw=relative=>fs.readFileSync(path.join(root,relative)),read=relative=>JSON.parse(raw(relative));
const save=(name,value)=>fs.writeFileSync(path.join(__dirname,name),JSON.stringify(value,null,2)+'\n',{flag:'wx'});
const started=new Date().toISOString();
save('capture-start.json',{schema:1,started_at:started,script_raw_sha256:sha(fs.readFileSync(__filename)),scope:'Evidence only; no production or historical writes.'});
try {
const target='data/professional/lexemes/foundation-module02.json',catalog=read('data/professional/catalog.json');
const priorPath='build/professional-english/foundation-module02-language-review/fourth10-research-r01/context-screen.json',prior=read(priorPath);
const selected=read(target).lexemes.slice(40,50),terms=['broken','urgent','unclear','safe','unsafe','hazard','incident','concern','solution','procedure'];
if(JSON.stringify(selected.map(x=>x.text))!==JSON.stringify(terms))throw Error('Final-ten selection changed');
const ids=new Set(selected.map(x=>x.id));
const files=[...new Set(['data/professional/catalog.json',catalog.themes.slice(6),catalog.sources.slice(6),
  ...catalog.courses.map(x=>x.manifest.slice(6)),...catalog.lexeme_files.map(x=>x.slice(6)),...catalog.expression_files.map(x=>x.slice(6)),
  'data/professional/schemas/lexeme.schema.json',priorPath])].sort();
const bindings=()=>files.map(relative=>{const bytes=raw(relative);return{path:relative,bytes:bytes.length,raw_sha256:sha(bytes)};});
const before=bindings(),lexemes=[],expressions=[],lexemeOrigins={},expressionOrigins={};
for(const resource of catalog.lexeme_files)for(const entry of read(resource.slice(6)).lexemes){lexemes.push(entry);lexemeOrigins[entry.id]=resource;}
for(const resource of catalog.expression_files)for(const entry of read(resource.slice(6)).expressions){expressions.push(entry);expressionOrigins[entry.id]=resource;}
const courses=catalog.courses.map(item=>read(item.manifest.slice(6)));
const forms={broken:['broken'],urgent:['urgent'],unclear:['unclear'],safe:['safe','safer','safest'],unsafe:['unsafe'],hazard:['hazard','hazards'],incident:['incident','incidents'],concern:['concern','concerns'],solution:['solution','solutions'],procedure:['procedure','procedures']};
const derivatives={broken:['break','breaks','broke','breaking'],urgent:['urgency','urgently'],unclear:['clear','clearly','clarify','clarification'],safe:['safely','safety','safeguard','safeguards'],unsafe:['unsafely'],hazard:['hazardous'],incident:['incidental','incidentally','incidence'],concern:['concerned','concerning'],solution:['solve','solves','solved','solving'],procedure:['procedural','procedurally']};
const matches=(text,words)=>[...text.matchAll(new RegExp('\\b(?:'+words.join('|')+')\\b','ig'))].map(match=>({text:match[0],start:match.index,end:match.index+match[0].length}));
const entryPin=entry=>({id:entry.id,before_entry:entry,entry_json_sha256:hash(entry)});
const modules=[],memberships=[];
for(const course of courses)for(const module of course.modules)if(module.lexeme_ids.some(id=>ids.has(id))){
  modules.push({course_id:course.id,module_id:module.id,before_entry:module,module_json_sha256:hash(module)});
  module.lexeme_ids.forEach((id,index)=>{if(ids.has(id))memberships.push({course_id:course.id,module_id:module.id,index,lexeme_id:id});});
}
function screen(table){return expressions.flatMap(entry=>{const hits=selected.flatMap(term=>{
  const occurrences=matches(entry.text,table[term.text]);return occurrences.length?[{term:term.text,selected_lexeme_id:term.id,occurrences,existing_selected_focus:entry.focus_lexeme_ids.includes(term.id)}]:[];
});return hits.length?[{...entryPin(entry),resource:expressionOrigins[entry.id],matches:hits,
  locations:courses.flatMap(course=>course.modules.filter(module=>module.expression_ids.includes(entry.id)).map(module=>({course_id:course.id,module_id:module.id})))}]:[];});}
const surface=screen(forms),derivative=screen(derivatives);
const focus=expressions.filter(entry=>entry.focus_lexeme_ids.some(id=>ids.has(id))).map(entryPin);
const related=lexemes.filter(entry=>!ids.has(entry.id)&&selected.some(term=>matches(entry.text,[...forms[term.text],...derivatives[term.text]]).length)).map(entry=>({...entryPin(entry),resource:lexemeOrigins[entry.id]}));
const holds=prior.previous_whole_entry_holds.map(item=>{const entry=lexemes.find(x=>x.id===item.id);if(!entry||hash(entry)!==item.entry_json_sha256)throw Error('Prior whole-entry hold drift: '+item.id);return entryPin(entry);});
const inherited=prior.inherited_expression_holds.map(item=>{const entry=expressions.find(x=>x.id===item.id);if(!entry||hash(entry)!==item.before_entry_json_sha256)throw Error('Inherited expression hold drift: '+item.id);return item;});
const complete=lexemes.find(entry=>entry.id==='complete.finish.v');
if(hash(complete)!==prior.complete_existing_form_scope_mismatch.entry_json_sha256)throw Error('Complete mismatch preservation drift');
const allModuleExpressions=expressions.filter(entry=>entry.id.startsWith('expr.foundation.module02.')).map(entryPin);
const counts=selected.map(entry=>({id:entry.id,term:entry.text,surface_expressions:surface.filter(row=>row.matches.some(hit=>hit.selected_lexeme_id===entry.id)).length,derivative_expressions:derivative.filter(row=>row.matches.some(hit=>hit.selected_lexeme_id===entry.id)).length,focus_expressions:focus.filter(row=>row.before_entry.focus_lexeme_ids.includes(entry.id)).length}));
if(JSON.stringify(before)!==JSON.stringify(bindings()))throw Error('Source drift during evidence capture');
fs.writeFileSync(path.join(__dirname,'original-foundation-module02.json'),raw(target),{flag:'wx'});
const baseline={schema:1,status:'frozen_author_observations_no_acceptance',created_at:started,
  hash_basis:'Raw files use SHA256 bytes; entry hashes use SHA256 of UTF-8 JSON.stringify(entry), retaining parsed key order.',
  target:{path:target,raw_sha256:sha(raw(target)),frozen_copy:'original-foundation-module02.json'},
  selection:{positions:'41-50',ids:[...ids]},selected_entries:selected.map(entryPin),source_file_hashes:before,
  prior_evidence:{path:priorPath,raw_sha256:sha(raw(priorPath)),reuse:'Hold/context lineage only; fresh fifth-ten dictionary observations are separate.'},
  matching_policy:{scope:'Expression text, case-insensitive word boundaries. Surface hits are not sense acceptance. Derivatives and compounds are a separate exclusion screen.',forms,derivatives},
  selected_memberships:memberships,containing_modules:modules,containing_module_expressions:allModuleExpressions,
  expression_uses:surface,derivative_expression_uses:derivative,focus_expressions:focus,related_entry_boundaries:related,
  previous_whole_entry_holds:holds,inherited_expression_holds:inherited,
  complete_existing_form_scope_mismatch:{...entryPin(complete),action:'Retain the existing pending mismatched form-image brief unchanged and unapproved.'},counts_by_selected_id:counts,
  summary:{selected_entries:10,memberships:memberships.length,containing_modules:modules.length,expressions_scanned:expressions.length,surface_hit_expressions:surface.length,surface_pairs:surface.reduce((n,row)=>n+row.matches.length,0),derivative_hit_expressions:derivative.length,focus_expressions:focus.length,related_identities:related.length,inherited_expression_holds:inherited.length,prior_lexical_holds:holds.length,source_files:before.length},
  observed_status:{senses:lexemes.length,language_reviewed:lexemes.filter(entry=>entry.review.language==='reviewed').length,whole_entry_reviewed:lexemes.filter(entry=>entry.review.status==='reviewed').length,foundation02_language_reviewed:read(target).lexemes.filter(entry=>entry.review.language==='reviewed').length,ready_modules:courses.flatMap(course=>course.modules).filter(module=>module.status==='ready').length},
  validations_run:false,production_writes:false};
save('baseline.json',baseline);
save('capture-completion.json',{schema:1,ok:true,finished_at:new Date().toISOString(),baseline_raw_sha256:sha(fs.readFileSync(path.join(__dirname,'baseline.json'))),summary:baseline.summary,observed_status:baseline.observed_status});
console.log(JSON.stringify({summary:baseline.summary,observed_status:baseline.observed_status,counts},null,2));
}catch(error){save('capture-failure.json',{schema:1,ok:false,error:error.stack||String(error),recorded_at:new Date().toISOString()});throw error;}
