'use strict';
const {assert,C,byteHash}=require('./delivery-lib.cjs');
const helper=String.raw`function beforeFoundation02SecondLanguage(entry) {
  const patch = foundation02SecondLanguageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  if (require('node:util').isDeepStrictEqual(entry, patch.before)) return structuredClone(patch.before);
  assert.deepEqual(entry, patch.after, entry.id + ': exact later second-ten accepted language and reviewed metadata');
  return structuredClone(patch.before);
}`;
const contentTests=String.raw`

test('Foundation02 second-ten delivery installs eight exact accepted proposals and scoped metadata', () => {
  const r=foundation02SecondLanguageRecord,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  const acceptance=JSON.parse(fs.readFileSync(path.join(rootDir,r.independent_review.path),'utf8'));
  assert.equal(r.patches.length,8);assert.equal(r.sources.length,16);assert.equal(r.new_language_approval,false);assert.equal(r.independent_review.accepted,true);assert.equal(r.independent_review.human_or_specialist_approval,false);
  assert.equal(r.independent_review.raw_sha256,'2d95fb5e1f08ed79a2b9de27ad2e031e36139385acf0d6d0e3e7a13b1a6f865e');
  for(const p of r.patches){
    const a=acceptance.accepted.find(x=>x.id===p.id);assert(a);assert.equal(hash(p.before),a.before_entry_json_sha256);assert.equal(hash(p.accepted_content),a.accepted_content_projection_json_sha256);assert.equal(hash(p.accepted_fields),a.accepted_fields_json_sha256);
    assert.deepEqual(source.lexemes.find(x=>x.id===p.id),p.after);assert.equal(hash(p.after),p.after_sha256);assert.deepEqual(p.accepted_fields,a.accepted_fields);
    for(const key of ['definition','example','difficulty'])assert.equal(p.after[key],a.accepted_fields[key]);
    const protectedFields=e=>{const out=structuredClone(e);for(const key of ['definition','example','difficulty','review','references','editorial_notes'])delete out[key];return out;};
    assert.deepEqual(protectedFields(p.after),protectedFields(p.before));assert.equal(p.after.review.domain,p.before.review.domain);assert.equal(p.after.review.language,'reviewed');assert.equal(p.after.review.status,'reviewed');assert.equal(p.after.review.reviewer,acceptance.reviewer);
    assert.deepEqual(p.after.references.slice(0,p.before.references.length),p.before.references);assert.equal(p.after.references.length,p.before.references.length+2);assert.deepEqual(p.after.references.slice(-2).map(x=>x.source_id),a.source_ids);assert(p.after.references.slice(-2).every(x=>x.status==='verified'));
    assert.equal(p.after.morphology.review.status,'pending');assert.equal(p.after.media.image.review.status,'pending');assert.equal(p.after.media.audio.review.status,'pending');
  }
  assert.deepEqual(source.sources.slice(-16),r.sources);for(const s of r.sources){assert.equal(s.status,'consulted');assert.equal(s.assets_acquired,false);assert.equal(s.asset_license,null);assert.match(s.scope,/No human, subject-matter/);}
});

test('Foundation02 second-ten preserves literal levels, corrected deliver and complete image mismatch', () => {
  const r=foundation02SecondLanguageRecord,p=text=>r.patches.find(x=>x.after.text===text);
  assert.equal(p('complete').after.definition,'To bring a piece of work or an activity to its end.');assert.equal(p('complete').selected_source_levels.oxford_html.literal,'a1');assert.equal(p('complete').selected_source_levels.collins_rendered,'A2');
  assert.match(p('complete').after.editorial_notes,/former merged-sense claim is not accepted/);assert.match(p('complete').after.editorial_notes,/form-image brief/);assert.match(p('complete').after.editorial_notes,/mismatch/);assert.doesNotMatch(p('complete').after.editorial_notes,/Finishing a form is an instance of that sense/);
  assert.deepEqual(p('complete').after.media,p('complete').before.media);assert.equal(p('complete').after.media.image.status,'pending');assert.match(p('complete').after.media.image.brief,/form/);
  assert.equal(p('deliver').after.definition,'To take physical items to the person or place they are intended for.');assert.equal(p('deliver').accepted_content_json_sha256,'bf7339125c5ec83bd6c1f8170bb68e731fb89d7a8713d36491208677290864ea');assert.equal(p('deliver').after.difficulty,'B1');
  for(const text of ['arrange','replace','report']){assert.equal(p(text).after.difficulty,'A2');assert.equal(p(text).selected_source_levels.oxford_html.literal,'a2');assert.equal(p(text).selected_source_levels.collins_rendered,'B1');}
  for(const text of ['return','contact']){assert.equal(p(text).after.difficulty,'A2');assert.equal(p(text).selected_source_levels.oxford_html.literal,'b1');assert.equal(p(text).selected_source_levels.collins_rendered,'A2');}
  assert.match(p('replace').after.editorial_notes,/B1\+/);assert.equal(p('replace').selected_source_levels.oxford_html.sense_element,'replace_sng_3');assert.match(p('return').after.definition,/borrowed item/);
  for(const p of r.patches)assert.equal(p.dictionary_or_lesson_level_certification,false);
});

test('Foundation02 second-ten retains whole-entry holds, all expressions and inherited exclusions', () => {
  const r=foundation02SecondLanguageRecord,c=r.protected_context,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.deepEqual(r.held.map(x=>x.id),['collect.gather.v','notify.inform.v']);for(const h of r.held){assert.deepEqual(source.lexemes.find(x=>x.id===h.id),h.value);assert.equal(hash(h.value),h.whole_entry_json_sha256);assert.equal(h.reference_or_note_additions,0);assert.equal(h.review_gate_changes,0);assert.equal(h.value.review.language,'pending');}
  assert.equal(r.excluded_source_ids.length,4);for(const id of r.excluded_source_ids)assert.equal(source.sources.some(x=>x.id===id),false);
  assert.equal(c.expressions.length,245);assert.equal(c.focus_expressions.length,6);assert.equal(c.related_entries.length,66);assert.equal(c.inherited_expression_holds.length,17);assert.equal(c.expression_hold_ids.length,17);assert.equal(c.memberships.length,200);
  for(const e of c.expressions)assert.equal(hash(source.expressions.find(x=>x.id===e.id)),e.expression_json_sha256);
  for(const e of c.focus_expressions)assert.deepEqual(source.expressions.find(x=>x.id===e.id),e.before_entry);
  for(const e of c.inherited_expression_holds){assert.equal(hash(source.expressions.find(x=>x.id===e.id)),e.before_entry_json_sha256);assert.equal(source.expressions.find(x=>x.id===e.id).review.language,'pending');}
  for(const e of c.related_entries)assert.equal(hash(beforeFoundation02SecondLanguage(source.lexemes.find(x=>x.id===e.id))),e.entry_json_sha256);
  for(const id of ['expr.foundation.module02.09','expr.foundation.module02.10'])assert.equal(source.expressions.find(x=>x.id===id).review.domain,'pending');
  for(const m of c.memberships)assert.equal(source.courses.find(x=>x.id===m.course_id).modules.find(x=>x.id===m.module_id).lexeme_ids[m.index],m.lexeme_id);
});

test('Foundation02 second-ten chronological reversal rejects partial fields and protects independent clone states', () => {
  const reversals=[beforeFoundation02SecondLanguage,beforeAttendanceLanguage,beforeFoundation02FirstLanguage,beforeSupervisorLanguage,beforeFoundationFifthLanguage,beforeFoundationFourthLanguage,beforeFoundationThirdLanguage,beforeFoundationSecondLanguage];
  for(const p of foundation02SecondLanguageRecord.patches){for(const state of [p.before,p.after]){
    for(const reverse of reversals)assert.deepEqual(reverse(state),p.before);
    for(const change of [e=>{e.definition+=' Drift.';},e=>{e.example+=' Drift.';},e=>{e.difficulty='C2';},e=>{e.review.status='unexpected';},e=>{e.review.reviewer='unexpected';},e=>{e.review.domain='reviewed';},e=>{e.references[0].scope+=' Drift.';},e=>{e.editorial_notes+=' Drift.';},e=>{e.media.image.status='reviewed';},e=>{e.media.audio.voice='unexpected';},e=>{e.morphology.review.status='reviewed';},e=>{e.accepted_forms.push('unexpected');},e=>{e.regions.push('US');},e=>{e.practice_modes.push('unexpected');},e=>{e.extra=true;}]){const bad=structuredClone(state);change(bad);for(const reverse of reversals)assert.throws(()=>reverse(bad));}
  }const clone=beforeFoundation02SecondLanguage(p.after);clone.definition='clone only';assert.notEqual(clone.definition,p.before.definition);}
});

test('Foundation02 second-ten preserves registry isolation and separate readiness gates', () => {
  const r=foundation02SecondLanguageRecord,c=r.protected_context,ids=new Set(r.patches.map(x=>x.id)),hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(hash(source.lexemes.filter(x=>!ids.has(x.id))),c.all_other_lexemes_json_sha256);assert.equal(hash(source.expressions),c.all_expressions_json_sha256);assert.equal(hash(source.courses),c.all_courses_json_sha256);assert.equal(hash(source.themes),c.all_themes_json_sha256);assert.equal(hash(source.sources.slice(0,-16)),c.previous_sources_json_sha256);
  assert.equal(source.lexemes.filter(x=>source.lexemeOrigins[x.id]==='res://data/professional/lexemes/foundation-module02.json'&&x.review.language==='reviewed').length,18);
  const audit=auditProfessionalContent({data:source});assert.equal(audit.summary.reviewed_lexemes,130);assert.equal(audit.summary.ready_modules,0);assert.equal(audit.summary.release_ready,false);
});

test('Foundation02 second-ten delivery binds explicit composite evidence and committed guarded journal', () => {
  const r=foundation02SecondLanguageRecord,raw=file=>fs.readFileSync(path.join(rootDir,file)),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
  assert.equal(r.status,'integrated_language_outputs_require_committed_journal');assert.equal(r.baseline_bound,true);
  assert.equal(sha(raw(r.lineage.validation.path)),r.lineage.validation.raw_sha256);const b=JSON.parse(raw(r.lineage.validation.path));assert.equal(b.kind,'composite_validation_baseline');assert.equal(b.ok,true);assert.equal(b.full_combined_validation_of_current_state,false);assert.equal(b.current_registry_sha256,r.lineage.registry_before_sha256);
  assert.equal(sha(raw(r.lineage.validation.verifier.path)),r.lineage.validation.verifier.raw_sha256);for(const row of r.lineage.validation.pinned_files)assert.equal(sha(raw(row.path)),row.raw_sha256);
  assert.equal(sha(raw(r.lineage.binding.path)),r.lineage.binding.raw_sha256);const binding=JSON.parse(raw(r.lineage.binding.path));assert.equal(binding.registry_before_sha256,r.lineage.registry_before_sha256);assert.equal(binding.registry_after_sha256,r.lineage.registry_after_sha256);
  const states=fs.readdirSync(path.join(rootDir,r.integration_guards.transaction_path,'states')).filter(x=>/^\d+-.*\.json$/.test(x)).sort();assert(states.length);assert.equal(JSON.parse(raw(r.integration_guards.transaction_path+'/states/'+states.at(-1))).status,'committed');for(const row of r.retained_files)assert.equal(sha(raw(row.path)),row.raw_sha256);
});
`;
const morphologyTests=String.raw`

test('Foundation02 second-ten language leaves every morphology graph pending and preserves historical donors', () => {
  const r=foundation02SecondLanguageRecord;
  for(const p of r.patches){const entry=data.lexemes.find(x=>x.id===p.id);assert.deepEqual(entry,p.after);assert.deepEqual(entry.morphology,p.before.morphology);assert.equal(entry.morphology.review.status,'pending');assert.deepEqual(beforeFoundationLanguage(entry),p.before);const bad=structuredClone(entry);bad.morphology.parts[0].canonical_id+='drift';assert.throws(()=>beforeFoundationLanguage(bad));}
  for(const [record,id]of [[fourthRecord,'return.send-back.v'],[retail04FirstRecord,'arrange.organize.v']]){const historical=record.protected_related_entries.find(x=>x.entry.id===id);assert(historical);const live=data.lexemes.find(x=>x.id===id);assert.deepEqual(beforeFoundationLanguage(live),historical.entry);assert.deepEqual(live.morphology,historical.entry.morphology);}
});
`;
const nativeHelper=String.raw`

var _f02s_language_record: Dictionary = {}

func _f02s_reverse(entry: Dictionary) -> Dictionary:
	if _f02s_language_record.is_empty():
		_f02s_language_record = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module02-language-second10-2026-10-17.json"))
	var patches: Array = _f02s_language_record.patches.filter(func(patch: Dictionary) -> bool: return patch.id == entry.get("id", ""))
	if patches.is_empty():
		return {"ok": true, "entry": entry}
	if patches.size() != 1:
		return {"ok": false}
	var patch: Dictionary = patches[0]
	if entry != patch.before and entry != patch.after:
		return {"ok": false}
	return {"ok": true, "entry": patch.before.duplicate(true)}

func _check_foundation02_second_language() -> void:
	_f02s_language_record = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module02-language-second10-2026-10-17.json"))
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/foundation-module02.json"))
	check(_f02s_language_record.patches.size() == 8 and _f02s_language_record.held.size() == 2, "Foundation02 second-ten has eight accepted lexical deltas and two whole-entry holds")
	for patch: Dictionary in _f02s_language_record.patches:
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == patch.id)
		check(rows.size() == 1 and rows[0] == patch.after, "Foundation02 second-ten live entry equals exact accepted language output: " + patch.id)
		if rows.size() != 1:
			continue
		check(rows[0].morphology == patch.before.morphology and rows[0].morphology.review.status == "pending" and not Analysis.compile(rows[0].morphology).ok, "Foundation02 language acceptance cannot admit pending morphology: " + patch.id)
		check(rows[0].media == patch.before.media and rows[0].review.domain == patch.before.review.domain, "Foundation02 language acceptance preserves exact media and domain gates: " + patch.id)
		for state: Dictionary in [patch.before, patch.after]:
			var reversed: Dictionary = _f02s_reverse(state)
			check(reversed.ok and reversed.entry == patch.before, "Foundation02 exact historical and accepted states reverse chronologically: " + patch.id)
			for field: String in ["definition", "example", "difficulty", "review", "references", "editorial_notes", "media", "morphology", "accepted_forms", "regions", "extra"]:
				var changed: Dictionary = state.duplicate(true)
				match field:
					"review": changed.review.domain = "reviewed"
					"references": changed.references[0].scope += " Drift."
					"media": changed.media.audio.voice = "unexpected"
					"morphology": changed.morphology.review.status = "reviewed"
					"accepted_forms", "regions": changed[field].append("unexpected")
					"extra": changed.extra = true
					_: changed[field] += " Drift."
				check(not _f02s_reverse(changed).ok, "Foundation02 chronology rejects unrecognized field drift: " + patch.id + "/" + field)
		var independent: Dictionary = _f02s_reverse(patch.after)
		independent.entry.definition = "clone only"
		check(patch.before.definition != "clone only", "Foundation02 reversal returns an independent historical clone")
	for held: Dictionary in _f02s_language_record.held:
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == held.id)
		check(rows.size() == 1 and rows[0] == held.value and rows[0].review.language == "pending", "Foundation02 unresolved entry stays exact: " + held.id)
	for donor: Array in [["retail-module03-morphology-fourth10-2026-10-16.json", "return.send-back.v"], ["retail-module04-morphology-first10-2026-10-16.json", "arrange.organize.v"]]:
		var history: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/" + donor[0]))
		var snapshots: Array = history.protected_related_entries.filter(func(row: Dictionary) -> bool: return row.entry.id == donor[1])
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == donor[1])
		check(snapshots.size() == 1 and rows.size() == 1, "Foundation02 historical donor identity remains unique: " + donor[1])
		if snapshots.size() == 1 and rows.size() == 1:
			var reversed: Dictionary = _f02s_reverse(rows[0])
			check(reversed.ok and reversed.entry == snapshots[0].entry and rows[0].morphology == snapshots[0].entry.morphology, "Foundation02 exact language reversal preserves the pending historical donor: " + donor[1])
`;
function transform(file,before){
  assert(C.tests.includes(file));let text=before.toString('utf8');const edits=[];
  function replace(old,next,count=1){assert.equal(text.split(old).length-1,count,file+': exact anchor '+old);text=text.split(old).join(next);edits.push({before:old,after:next,count});}
  if(file.endsWith('.gd')){
    replace('\t_check_retail04_third10()','\t_check_retail04_third10()\n\t_check_foundation02_second_language()');
    replace('\tvar comparable: Dictionary = current[0]','\tvar second_language: Dictionary = _f02s_reverse(current[0])\n\tcheck(second_language.ok, "Newest Foundation02 language state must match its exact chronological boundary")\n\tif not second_language.ok:\n\t\treturn {}\n\tvar comparable: Dictionary = second_language.entry');
    text+=nativeHelper;return {bytes:Buffer.from(text),edits,appended_tests:1,native:true,before_sha256:byteHash(before),after_sha256:byteHash(text)};
  }
  const content=file.includes('professional-content'),rootName=content?'rootDir':'root';
  replace('function beforeAttendanceLanguage(entry) {',`const foundation02SecondLanguageRecord = JSON.parse(fs.readFileSync(path.join(${rootName}, '${C.provenance}'), 'utf8'));\n${helper}\nfunction beforeAttendanceLanguage(entry) {\n  entry = beforeFoundation02SecondLanguage(entry);`);
  if(content){
    replace('...attendanceLanguageRecord.patches].map(item => item.id)','...attendanceLanguageRecord.patches, ...foundation02SecondLanguageRecord.patches].map(item => item.id)');
    replace('assert.equal(result.summary.reviewed_lexemes, 122);','assert.equal(result.summary.reviewed_lexemes, 130);');
    replace("assert.match(word('complete').definition,/providing everything required/);","assert.match(beforeFoundation02SecondLanguage(word('complete')).definition,/providing everything required/);");
    replace('assert.equal(hash(source.lexemes.filter(e=>e.id!==p.id)),c.all_other_lexemes_json_sha256);','assert.equal(hash(source.lexemes.map(beforeFoundation02SecondLanguage).filter(e=>e.id!==p.id)),c.all_other_lexemes_json_sha256);');
    replace('assert.equal(hash(source.sources.slice(0,-r.sources.length)),c.previous_sources_json_sha256);','assert.equal(hash(source.sources.slice(0,-foundation02SecondLanguageRecord.sources.length).slice(0,-r.sources.length)),c.previous_sources_json_sha256);');
    replace('const audit=auditProfessionalContent({data:source});assert.equal(audit.summary.reviewed_lexemes,122);','const historical={...source,lexemes:source.lexemes.map(beforeFoundation02SecondLanguage),sources:source.sources.slice(0,-foundation02SecondLanguageRecord.sources.length)};const audit=auditProfessionalContent({data:historical});assert.equal(audit.summary.reviewed_lexemes,122);');
    text+=contentTests;
  }else text+=morphologyTests;
  return {bytes:Buffer.from(text),edits,appended_tests:content?6:1,native:false,before_sha256:byteHash(before),after_sha256:byteHash(text)};
}
module.exports={transform};
