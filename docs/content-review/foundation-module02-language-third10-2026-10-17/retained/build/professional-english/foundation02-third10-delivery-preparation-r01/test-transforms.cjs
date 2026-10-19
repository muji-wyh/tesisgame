'use strict';
// Unexecuted exact-anchor proposal. Returns bytes only; never writes shared tests or executes callbacks.
const assert = require('node:assert/strict');
const provenance = 'data/professional/provenance/foundation-module02-language-third10-2026-10-17.json';
const files = ['tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs',
  'tests/godot/professional_retail_morphology_tests.gd'];
const helper = String.raw`function beforeFoundation02ThirdLanguage(entry) {
  const patches = foundation02ThirdLanguageRecord.patches.filter(item => item.id === entry.id);
  if (!patches.length) return entry;
  assert.equal(patches.length, 1);
  const patch = patches[0];
  if (require('node:util').isDeepStrictEqual(entry, patch.before)) return structuredClone(patch.before);
  assert.deepEqual(entry, patch.after, entry.id + ': exact later third-ten language and reviewed metadata');
  return structuredClone(patch.before);
}
function beforeFoundation02ThirdSources(sources) {
  const additions = foundation02ThirdLanguageRecord.sources;
  assert.equal(additions.length, 16);
  assert.deepEqual(sources.slice(-additions.length), additions, 'Exact third-ten source suffix required');
  return sources.slice(0, -additions.length);
}`;

const contentTests = String.raw`

test('Foundation02 third-ten installs only eight accepted language projections and proposed delivery metadata', () => {
  const r=foundation02ThirdLanguageRecord,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  const accepted=JSON.parse(fs.readFileSync(path.join(rootDir,r.independent_review.path),'utf8'));
  assert.equal(r.independent_review.raw_sha256,'2aaac3d8672600001faa104594a221ed1d079caf9723cc5495d1172de7fb0c4d');
  assert.equal(r.patches.length,8);assert.equal(r.sources.length,16);assert.equal(r.new_language_approval,false);assert.equal(r.independent_review.human_or_specialist_approval,false);
  assert.deepEqual(r.independent_review.limitations,accepted.limitations);assert.match(r.independent_review.limitations[0],/not reopened/);
  assert.equal(r.patches.filter(p=>p.before.difficulty!==p.after.difficulty).length,7);
  for(const p of r.patches){
    const a=accepted.entries.find(row=>row.id===p.id);assert.equal(a.decision,'accept_exact_bounded_language_fields');
    assert.equal(hash(p.before),a.before_entry_sha256);assert.equal(hash(p.accepted_content),a.content_projection_sha256);
    assert.deepEqual(p.accepted_fields,a.accepted_fields);assert.equal(hash(p.after),p.after_sha256);
    assert.deepEqual(source.lexemes.find(entry=>entry.id===p.id),p.after);
    assert.equal(p.after.definition,p.before.definition);assert.equal(p.after.example,p.before.example);assert.equal(p.after.difficulty,a.accepted_fields.difficulty);
    const protect=entry=>{const out=structuredClone(entry);for(const k of ['definition','example','difficulty','references','editorial_notes'])delete out[k];for(const k of ['status','language','reviewer','reviewed_at'])delete out.review[k];return out;};
    assert.deepEqual(protect(p.after),protect(p.before));assert.equal(p.after.review.status,'reviewed');assert.equal(p.after.review.language,'reviewed');assert.equal(p.after.review.reviewer,accepted.reviewer);assert.equal(p.after.review.reviewed_at,accepted.reviewed_on);
    assert.deepEqual(p.after.references.slice(0,p.before.references.length),p.before.references);assert.equal(p.after.references.length,p.before.references.length+2);
    assert.deepEqual(p.after.references.slice(-2).map(row=>row.source_id),p.source_ids);assert(p.after.references.slice(-2).every(row=>row.status==='verified'));
    assert.deepEqual(p.selected_source_observations,a.selected_source_observations);assert.equal(p.dictionary_or_lesson_level_certification,false);
    for(const text of [p.after.editorial_notes,...p.after.references.slice(-2).map(row=>row.scope)]){assert.match(text,/did not reopen/);assert.match(text,/cannot be independently rehashed/);assert.match(text,/No human, subject-matter/);}
  }
  assert.deepEqual(source.sources.slice(-16),r.sources);for(const row of r.sources){assert.equal(row.status,'consulted');assert.equal(row.assets_acquired,false);assert.equal(row.asset_license,null);assert.match(row.scope,/not psychometric CEFR certification/);}
});

test('Foundation02 third-ten retains four lexical holds and exact expression context without new bindings', () => {
  const r=foundation02ThirdLanguageRecord,c=r.protected_context,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.deepEqual(r.held.map(row=>row.id),['postpone.delay-until-later.v','verify.establish-accuracy.v']);
  for(const row of r.held){assert.equal(hash(source.lexemes.find(entry=>entry.id===row.id)),row.whole_entry_json_sha256);assert.deepEqual(source.lexemes.find(entry=>entry.id===row.id),row.value);assert.equal(row.reference_or_note_additions,0);assert.equal(row.review_gate_changes,0);assert.equal(row.value.review.language,'pending');}
  assert.deepEqual(c.prior_lexical_holds.map(row=>row.id),['collect.gather.v','notify.inform.v']);
  for(const row of c.prior_lexical_holds){assert.equal(hash(source.lexemes.find(entry=>entry.id===row.id)),row.whole_entry_json_sha256);assert.deepEqual(source.lexemes.find(entry=>entry.id===row.id),row.before_entry);}
  assert.equal(r.excluded_source_ids.length,4);for(const id of r.excluded_source_ids)assert.equal(source.sources.some(row=>row.id===id),false);
  assert.deepEqual([c.memberships.length,c.modules.length,c.expressions.length,c.focus_expressions.length,c.related_entries.length,c.inherited_expression_holds.length],[200,20,39,4,43,17]);
  for(const row of c.expressions)assert.equal(hash(source.expressions.find(entry=>entry.id===row.id)),row.expression_json_sha256);
  for(const row of c.focus_expressions){const live=source.expressions.find(entry=>entry.id===row.id);assert.deepEqual(live,row.before_entry);assert.equal(live.review.language,'pending');}
  for(const row of c.inherited_expression_holds)assert.equal(hash(source.expressions.find(entry=>entry.id===row.id)),row.before_entry_json_sha256);
  for(const row of c.related_entries)assert.equal(hash(beforeFoundation02ThirdLanguage(source.lexemes.find(entry=>entry.id===row.id))),row.entry_json_sha256);
  for(const row of c.memberships)assert.equal(source.courses.find(course=>course.id===row.course_id).modules.find(module=>module.id===row.module_id).lexeme_ids[row.index],row.lexeme_id);
  assert.equal(hash(source.lexemes.find(entry=>entry.id==='complete.finish.v')),c.complete_pending_form_image_mismatch.current_whole_entry_json_sha256);
});

test('Foundation02 third-ten preserves literal source disagreements and selected senses', () => {
  const r=foundation02ThirdLanguageRecord,p=term=>r.patches.find(row=>row.after.text===term),level=(term,publisher)=>p(term).selected_source_observations.find(row=>row.publisher===publisher);
  assert.equal(level('correct','Oxford University Press').observed_html_selected_levels[0].cefr,'a1');assert.equal(level('correct','HarperCollins').observed_rendered_selected_level,'B2');assert.equal(p('correct').after.difficulty,'A2');
  assert.equal(level('reschedule','Oxford University Press').observed_html_selected_levels[0].cefr,null);assert.equal(level('reschedule','HarperCollins').observed_rendered_selected_level,'B2');
  assert.equal(level('cancel','HarperCollins').observed_rendered_selected_level,'B1+');assert.equal(level('cancel','Oxford University Press').observed_html_selected_levels.length,2);assert(level('cancel','Oxford University Press').observed_html_selected_levels.every(row=>row.cefr==='b2'));
  assert.equal(level('resolve','HarperCollins').observed_rendered_selected_level,null);
  for(const term of ['assist','locate']){assert.equal(level(term,'Oxford University Press').observed_html_selected_levels[0].cefr,'b1');assert.equal(level(term,'HarperCollins').observed_rendered_selected_level,'B2');}
  assert.equal(level('attach','Oxford University Press').observed_html_selected_levels[0].element_id,'attach_sng_6');assert.equal(level('attach','HarperCollins').observed_rendered_selected_level,'B1');
  assert.match(p('attach').after.editorial_notes,/lack an explicit electronic-message meaning|do not expressly identify email|no new binding/);
});

test('Foundation02 third-ten chronology rejects partial fields and keeps every historical snapshot exact', () => {
  const reversals=[beforeFoundation02ThirdLanguage,beforeFoundation02SecondLanguage,beforeAttendanceLanguage,beforeFoundation02FirstLanguage,beforeSupervisorLanguage,beforeFoundationFifthLanguage,beforeFoundationFourthLanguage,beforeFoundationThirdLanguage,beforeFoundationSecondLanguage];
  for(const p of foundation02ThirdLanguageRecord.patches){for(const state of [p.before,p.after]){
    for(const reverse of reversals)assert.deepEqual(reverse(state),p.before);
    for(const change of [e=>{e.definition+=' Drift.';},e=>{e.example+=' Drift.';},e=>{e.difficulty='C2';},e=>{e.review.status='unexpected';},e=>{e.review.language='unexpected';},e=>{e.review.reviewer='unexpected';},e=>{e.review.domain='reviewed';},e=>{e.references[0].scope+=' Drift.';},e=>{e.editorial_notes+=' Drift.';},e=>{e.media.image.status='reviewed';},e=>{e.media.audio.voice='unexpected';},e=>{e.morphology.review.status='reviewed';},e=>{e.accepted_forms.push('unexpected');},e=>{e.regions.push('US');},e=>{e.practice_modes.push('unexpected');},e=>{e.extra=true;}]){const bad=structuredClone(state);change(bad);for(const reverse of reversals)assert.throws(()=>reverse(bad));}
  }const clone=beforeFoundation02ThirdLanguage(p.after);clone.definition='clone only';assert.notEqual(clone.definition,p.before.definition);}
  const badSources=structuredClone(source.sources);badSources.at(-1).scope+=' Drift.';assert.throws(()=>beforeFoundation02ThirdSources(badSources));
});

test('Foundation02 third-ten preserves registry isolation and separate readiness gates', () => {
  const r=foundation02ThirdLanguageRecord,c=r.protected_context,ids=new Set(r.patches.map(row=>row.id)),hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(hash(source.lexemes.filter(entry=>!ids.has(entry.id))),c.all_other_lexemes_json_sha256);assert.equal(hash(source.expressions),c.all_expressions_json_sha256);assert.equal(hash(source.courses),c.all_courses_json_sha256);assert.equal(hash(source.themes),c.all_themes_json_sha256);assert.equal(hash(beforeFoundation02ThirdSources(source.sources)),c.previous_sources_json_sha256);
  assert.equal(source.lexemes.filter(entry=>entry.review.status==='reviewed').length,138);assert.equal(source.lexemes.filter(entry=>entry.review.language==='reviewed').length,325);
  assert.equal(source.lexemes.filter(entry=>source.lexemeOrigins[entry.id]==='res://data/professional/lexemes/foundation-module02.json'&&entry.review.language==='reviewed').length,26);
  const audit=auditProfessionalContent({data:source});assert.equal(audit.summary.reviewed_lexemes,138);assert.equal(audit.summary.ready_modules,0);assert.equal(audit.summary.release_ready,false);
});
`;

const morphologyTests = String.raw`

test('Foundation02 third-ten language leaves exact morphology, media and historical Foundation donors unchanged', () => {
  for(const p of foundation02ThirdLanguageRecord.patches){const entry=data.lexemes.find(row=>row.id===p.id);assert.deepEqual(entry,p.after);assert.deepEqual(entry.morphology,p.before.morphology);assert.deepEqual(entry.media,p.before.media);assert.equal(entry.review.domain,p.before.review.domain);assert.equal(entry.morphology.review.status,'pending');assert.deepEqual(beforeFoundationLanguage(entry),p.before);const bad=structuredClone(entry);bad.morphology.parts[0].canonical_id+='drift';assert.throws(()=>beforeFoundationLanguage(bad));
    for(const history of [foundationLanguageRecord,foundationSecondLanguageRecord,foundationThirdLanguageRecord,foundationFourthLanguageRecord,foundationFifthLanguageRecord]){const snapshots=history.protected_context.lexemes.filter(row=>row.entry.id===p.id);assert.equal(snapshots.length,1);assert.deepEqual(beforeFoundationLanguage(entry),snapshots[0].entry);}
  }
});
`;

const nativeTests = String.raw`

var _f02t_language_record: Dictionary = {}

func _f02t_reverse(entry: Dictionary) -> Dictionary:
	if _f02t_language_record.is_empty():
		_f02t_language_record = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module02-language-third10-2026-10-17.json"))
	var patches: Array = _f02t_language_record.patches.filter(func(patch: Dictionary) -> bool: return patch.id == entry.get("id", ""))
	if patches.is_empty():
		return {"ok": true, "entry": entry}
	if patches.size() != 1:
		return {"ok": false}
	var patch: Dictionary = patches[0]
	if entry != patch.before and entry != patch.after:
		return {"ok": false}
	return {"ok": true, "entry": patch.before.duplicate(true)}

func _check_foundation02_third_language() -> void:
	_f02t_language_record = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module02-language-third10-2026-10-17.json"))
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/foundation-module02.json"))
	check(_f02t_language_record.patches.size() == 8 and _f02t_language_record.held.size() == 2, "Foundation02 third-ten has eight language decisions and two new whole-entry holds")
	for patch: Dictionary in _f02t_language_record.patches:
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == patch.id)
		check(rows.size() == 1 and rows[0] == patch.after, "Third-ten live entry equals the exact delivered projection: " + patch.id)
		if rows.size() != 1:
			continue
		check(rows[0].morphology == patch.before.morphology and rows[0].morphology.review.status == "pending" and not Analysis.compile(rows[0].morphology).ok, "Language approval cannot admit pending morphology: " + patch.id)
		check(rows[0].media == patch.before.media and rows[0].review.domain == patch.before.review.domain, "Third-ten preserves exact media and domain gates: " + patch.id)
		for state: Dictionary in [patch.before, patch.after]:
			var reversed: Dictionary = _f02t_reverse(state)
			check(reversed.ok and reversed.entry == patch.before, "Third-ten exact historical and accepted states reverse: " + patch.id)
			for field: String in ["definition", "example", "difficulty", "review", "references", "editorial_notes", "media", "morphology", "accepted_forms", "regions", "practice_modes", "extra"]:
				var changed: Dictionary = state.duplicate(true)
				match field:
					"review": changed.review.domain = "reviewed"
					"references": changed.references[0].scope += " Drift."
					"media": changed.media.audio.voice = "unexpected"
					"morphology": changed.morphology.review.status = "reviewed"
					"accepted_forms", "regions", "practice_modes": changed[field].append("unexpected")
					"extra": changed.extra = true
					_: changed[field] += " Drift."
				check(not _f02t_reverse(changed).ok and not _f02s_reverse(changed).ok, "Third-ten and earlier chronology reject field drift: " + patch.id + "/" + field)
		var independent: Dictionary = _f02t_reverse(patch.after)
		independent.entry.definition = "clone only"
		check(patch.before.definition != "clone only", "Third-ten returns an independent historical clone")
	for held: Dictionary in _f02t_language_record.held:
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == held.id)
		check(rows.size() == 1 and rows[0] == held.value and rows[0].review.language == "pending", "Third-ten held entry stays exact: " + held.id)
	for held: Dictionary in _f02t_language_record.protected_context.prior_lexical_holds:
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == held.id)
		check(rows.size() == 1 and rows[0] == held.before_entry and rows[0].review.language == "pending", "Prior lexical hold stays exact: " + held.id)
`;

function transform(file, before) {
  assert(files.includes(file));
  let text = before.toString('utf8');
  const edits = [];
  function replace(old, next, count = 1) {
    assert.equal(text.split(old).length - 1, count, file + ': exact anchor ' + old);
    text = text.split(old).join(next);
    edits.push({before: old, after: next, count});
  }
  if (file.endsWith('.gd')) {
    replace('\t_check_foundation02_second_language()', '\t_check_foundation02_second_language()\n\t_check_foundation02_third_language()');
    replace('func _f02s_reverse(entry: Dictionary) -> Dictionary:\n', 'func _f02s_reverse(entry: Dictionary) -> Dictionary:\n\tvar third_language: Dictionary = _f02t_reverse(entry)\n\tif not third_language.ok:\n\t\treturn {"ok": false}\n\tentry = third_language.entry\n');
    return {bytes: Buffer.from(text + nativeTests), edits, native: true, appended_tests: 1};
  }
  const content = file.includes('professional-content');
  replace('function beforeFoundation02SecondLanguage(entry) {',
    `const foundation02ThirdLanguageRecord = JSON.parse(fs.readFileSync(path.join(${content ? 'rootDir' : 'root'}, '${provenance}'), 'utf8'));\n${helper}\nfunction beforeFoundation02SecondLanguage(entry) {\n  entry = beforeFoundation02ThirdLanguage(entry);`);
  if (content) {
    replace('...foundation02SecondLanguageRecord.patches].map(item => item.id)', '...foundation02SecondLanguageRecord.patches, ...foundation02ThirdLanguageRecord.patches].map(item => item.id)');
    replace('assert.equal(result.summary.reviewed_lexemes, 130);', 'assert.equal(result.summary.reviewed_lexemes, 138);');
    replace('source.sources.slice(0,-foundation02SecondLanguageRecord.sources.length)', 'beforeFoundation02ThirdSources(source.sources).slice(0,-foundation02SecondLanguageRecord.sources.length)', 2);
    replace('assert.deepEqual(source.sources.slice(-16),r.sources);', 'assert.deepEqual(beforeFoundation02ThirdSources(source.sources).slice(-16),r.sources);');
    replace('hash(source.lexemes.filter(x=>!ids.has(x.id)))', 'hash(source.lexemes.map(beforeFoundation02ThirdLanguage).filter(x=>!ids.has(x.id)))');
    replace('hash(source.sources.slice(0,-16))', 'hash(beforeFoundation02ThirdSources(source.sources).slice(0,-16))');
    replace("source.lexemes.filter(x=>source.lexemeOrigins[x.id]==='res://data/professional/lexemes/foundation-module02.json'&&x.review.language==='reviewed').length,18", "source.lexemes.map(beforeFoundation02ThirdLanguage).filter(x=>source.lexemeOrigins[x.id]==='res://data/professional/lexemes/foundation-module02.json'&&x.review.language==='reviewed').length,18");
    replace('const audit=auditProfessionalContent({data:source});assert.equal(audit.summary.reviewed_lexemes,130);', 'const historical={...source,lexemes:source.lexemes.map(beforeFoundation02ThirdLanguage),sources:beforeFoundation02ThirdSources(source.sources)};const audit=auditProfessionalContent({data:historical});assert.equal(audit.summary.reviewed_lexemes,130);');
  }
  return {bytes: Buffer.from(text + (content ? contentTests : morphologyTests)), edits, native: false,
    appended_tests: content ? 5 : 1};
}

module.exports = {transform, files};
