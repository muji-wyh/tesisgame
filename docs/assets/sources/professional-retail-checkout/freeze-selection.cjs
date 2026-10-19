'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../../..'),base=__dirname;
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(path.join(base,file),'utf8'));
const record=file=>{const bytes=fs.readFileSync(path.join(base,file));return {path:file,bytes:bytes.length,sha256:sha(bytes)};};
const source=read('source-record.json'),ranked=read('ranked-composition-review.json'),report=read('composition-probe/report.json'),native=read('composition-native-receipt.json');
const probe=report.probes.find(p=>p.name==='compact-three-quarter');
const selectedChecks=report.checks.filter(c=>c.check.startsWith('compact-three-quarter:'));
assert.equal(selectedChecks.length,18);assert.equal(selectedChecks.filter(c=>!c.passed).length,0);
assert.equal(report.checks.length,72);assert.equal(report.failed,2);assert.equal(native.ok,false);assert.equal(native.guard_error,null);
assert.equal(record(ranked.recommended_image.path).sha256,ranked.recommended_image.sha256);
for(const crop of ranked.recommended_card_crops)assert.equal(record(crop.path).sha256,crop.sha256);
const evidence=[];
function visit(dir=''){for(const ent of fs.readdirSync(path.join(base,dir),{withFileTypes:true})){const rel=(dir?dir+'/':'')+ent.name;if(ent.isDirectory()){if(!ent.name.startsWith('delivery-')&&!ent.name.startsWith('production-delivery-'))visit(rel);}else if(!['review-receipt.json','root-image-review.json'].includes(rel))evidence.push(record(rel));}}
visit();evidence.sort((a,b)=>a.path.localeCompare(b.path));
const receipt={
  date:'2026-10-16',status:'frozen_selected_candidate_pending_exact_independent_root_acceptance',
  reviewer:'Codex retail_register_art (AI source and author visual review; not independent production acceptance)',
  sense_id:source.sense_id,definition:source.definition,example:source.example,approved_brief:source.approved_brief,
  sources:source.packs.map(pack=>({...pack,record:record('source-record.json'),available_animations:source.available_animations[pack.id]??'See exact model animation names and durations in source-record.json',integration_status:'Acquired source retained in scratch; final PNG not integrated.'})),
  source_integrity:{complete_selected_models:5,selected_source_models:probe.source_instances,retained_complete_models:6,retained_source_files:24,source_pose_review:record('source-pose-review.json'),source_probe_receipt:record('sources-native-receipt.json'),original_and_retained_source_comparisons_unchanged:48,geometry_materials_textures_skins_and_child_bind_transforms:'Preserved. Character poses use only sampled original included animation clips.',unused_retained_model:'Mini Market floor.glb is retained as rejected-variant evidence and is absent from the selected composition.'},
  selected_candidate:{name:probe.name,file:record(ranked.recommended_image.path),size:ranked.recommended_image.dimensions,decoded_cpu_gpu_bytes:512*393*8,rgba_pixel_sha256:ranked.recommended_image.rgba_pixel_sha256,available_animations:[],source_instances:probe.source_instances,camera:probe.camera,lighting:{ambient_energy:0.18,directional_energy:0.38,directional_rotation:[-50,-35,0]},raw_size:[768,768],crop:probe.crop,postprocessing:'16 pixel alpha-bound margin and proportional Lanczos downscale only; no paintover or substitute art.',rendering_script:record('probe-composition.gd'),card_crops:ranked.recommended_card_crops,card_measurements:probe.measurements,production_integration:false,independent_acceptance:null},
  native_validation:{selected_candidate:{checks:18,failures:0,successful_checks:selectedChecks},aggregate:{ok:false,checks:72,failures:2,failed_checks:report.checks.filter(c=>!c.passed),receipt:record('composition-native-receipt.json'),report:record('composition-probe/report.json'),log:record('composition-native.log'),reason:'Both tiled variants clip the complete floor at the viewport sides. The aggregate failed and remains failed; selected-candidate success is bounded to compact-three-quarter only.'},unchanged_production_file_guards:658,unchanged_source_comparisons:48,guard_error:null,delivery_boundary:'The four card captures use direct scratch ImageTexture on the actual WordCard. Production Loader/cache/pixel delivery is not yet verified.'},
  author_visual_findings:{ranked_review:record('ranked-composition-review.json'),meaning:ranked.meaning_check,selected_findings:ranked.ranking[0],inspection:ranked.inspected,scope:'Scoped AI visual judgment only; no human, domain, curriculum, recognition-study or module-readiness claim.'},
  production_content_written_by_this_task:false,production_media_status_at_packaging:'Checkout image pending; exact user-approved Ava word recording remains integrated and unchanged.',
  render_dependencies:['scripts/word_card.gd','scripts/game_data.gd','scripts/ui_style.gd','scripts/professional_catalog.gd','tools/run-godot.cjs'].map(file=>({path:file,sha256:sha(fs.readFileSync(path.join(root,file)))})),
  evidence_files:evidence
};
fs.writeFileSync(path.join(base,'review-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({receipt:record('review-receipt.json'),selected_checks:18,selected_failures:0,aggregate_checks:72,aggregate_failures:2,evidence_files:evidence.length}));
