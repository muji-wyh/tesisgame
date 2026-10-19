'use strict';
// A new bounded raw-data supplement; no replay or project imports.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../../..');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const inputs=JSON.parse(fs.readFileSync(path.join(__dirname,'input-pins.json'),'utf8')).filter(r=>r.path.startsWith('build/professional-english/foundation02-fourth10-native-candidate-r02/attempt-001/project/data/professional/lexemes/'));
const families=new Set(['en','en-','sure','sure-','inform','collect','assure','assurance']);
const extra=[];
const original=JSON.parse(fs.readFileSync(path.join(root,'build/professional-english/foundation02-held-resolution-morphology-research-r01/canonical-family-contexts.before.json'),'utf8'));
const oldIds=new Set(original.map(r=>r.entry.id));
const summaries=[];
for(const r of inputs){
  const b=fs.readFileSync(path.join(root,r.path));if(b.length!==r.bytes||sha(b)!==r.sha256)throw Error('Frozen input drift: '+r.path);
  for(const entry of JSON.parse(b).lexemes){
    const parts=(entry.morphology?.parts||[]).filter(p=>families.has(p.canonical));
    if(parts.length||['sure','ensure','insure','assure','assurance','unsure'].includes(entry.text)){
      const row={resource:'res://'+r.path.split('/project/')[1],entry};
      summaries.push({id:entry.id,definition:entry.definition,review:entry.review,morphology_review:entry.morphology?.review||null,parts,previous_selected_family_capture:oldIds.has(entry.id)});
      if(!oldIds.has(entry.id))extra.push(row);
    }
  }
}
for(const r of inputs){const b=fs.readFileSync(path.join(root,r.path));if(b.length!==r.bytes||sha(b)!==r.sha256)throw Error('End-of-supplement frozen input drift: '+r.path);}
fs.writeFileSync(path.join(__dirname,'family-supplement.json'),JSON.stringify({status:'independent_frozen_surface_and_canonical_spelling_supplement_not_family_unification',recorded_at:new Date().toISOString(),input_count:inputs.length,selection:[...families],summaries,additional_complete_objects:extra,source_sha256:sha(fs.readFileSync(__filename)),all_inputs_exact:true,live_registry_read:false,project_execution:false},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({inputs:inputs.length,matched:summaries.length,additional_complete_objects:extra.length,rows:summaries.map(r=>({id:r.id,parts:r.parts.map(p=>({canonical:p.canonical,canonical_id:p.canonical_id,type:p.type})),prior_capture:r.previous_selected_family_capture}))}));
