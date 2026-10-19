'use strict';
// Unexecuted exact-anchor proposal. Returns bytes only; never writes shared tests or executes callbacks.
const assert = require('node:assert/strict');
const provenance = 'data/professional/provenance/foundation-module02-language-fourth10-2026-10-17.json';
const files = ['tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs',
  'tests/godot/professional_retail_morphology_tests.gd'];
const helper = String.raw`function beforeFoundation02FourthLanguage(entry) {
  const patches = foundation02FourthLanguageRecord.patches.filter(item => item.id === entry.id);
  if (!patches.length) return entry;
  assert.equal(patches.length, 1);
  const patch = patches[0];
  if (require('node:util').isDeepStrictEqual(entry, patch.before)) return structuredClone(patch.before);
  assert.deepEqual(entry, patch.after, entry.id + ': exact later fourth-ten language and reviewed metadata');
  return structuredClone(patch.before);
}
function beforeFoundation02FourthSources(sources) {
  const additions = foundation02FourthLanguageRecord.sources;
  assert.equal(additions.length, 20);
  assert.deepEqual(sources.slice(-additions.length), additions, 'Exact fourth-ten source suffix required');
  return sources.slice(0, -additions.length);
}`;
const contentTests = String.raw`

test('Foundation02 fourth-ten installs ten exact accepted language projections with separately scoped delivery metadata', () => {
  const r=foundation02FourthLanguageRecord,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  const accepted=JSON.parse(fs.readFileSync(path.join(rootDir,r.independent_review.path),'utf8'));
  assert.equal(r.independent_review.raw_sha256,'58993d8767ec701e37613fdee70d75e94f22a68d467b94157ea41a211bc9f8bd');
  assert.equal(r.patches.length,10);assert.equal(r.sources.length,20);assert.equal(r.held.length,0);assert.equal(r.new_language_approval,false);assert.equal(r.independent_review.human_or_specialist_approval,false);
  assert.deepEqual(r.independent_review.limitations,accepted.limits);
  assert.deepEqual(['difficulty','definition','example'].map(field=>r.patches.filter(p=>p.before[field]!==p.after[field]).length),[6,1,1]);
  assert.equal(r.patches.filter(p=>hash(p.before)!==hash(p.accepted_content)).length,6);
  for(const p of r.patches){
    const a=accepted.entries.find(row=>row.id===p.id);assert.equal(a.decision,'accept_exact_language_projection');
    assert.equal(hash(p.before),a.before_entry_sha256);assert.equal(hash(p.accepted_content),a.accepted_content_projection_sha256);
    assert.deepEqual(p.accepted_fields,a.accepted_fields);assert.equal(hash(p.accepted_fields),a.accepted_fields_sha256);assert.equal(hash(p.after),p.after_sha256);
    assert.deepEqual(source.lexemes.find(entry=>entry.id===p.id),p.after);
    for(const field of ['definition','example','difficulty']){assert.equal(p.after[field],a.accepted_fields[field]);assert.deepEqual(p.field_decisions[field],a.field_decisions[field]);assert.equal(p.field_decisions[field].decision,'accept');}
    const protect=entry=>{const out=structuredClone(entry);for(const k of ['definition','example','difficulty','references','editorial_notes'])delete out[k];for(const k of ['status','language','reviewer','reviewed_at'])delete out.review[k];return out;};
    assert.deepEqual(protect(p.after),protect(p.before));assert.equal(p.after.review.status,'reviewed');assert.equal(p.after.review.language,'reviewed');assert.equal(p.after.review.reviewer,accepted.reviewer);assert.equal(p.after.review.reviewed_at,accepted.date_local);
    assert.deepEqual(p.after.references.slice(0,p.before.references.length),p.before.references);assert.equal(p.after.references.length,p.before.references.length+2);
    assert.deepEqual(p.after.references.slice(-2).map(row=>row.source_id),p.source_ids);assert(p.after.references.slice(-2).every(row=>row.status==='verified'));
    assert.equal(p.dictionary_or_lesson_level_certification,false);assert.equal(p.historical_research_context_boundary,a.context_boundary);
    for(const text of [p.after.editorial_notes,...p.after.references.slice(-2).map(row=>row.scope)]){assert.match(text,/freshly consulted all 20 rendered/);assert.match(text,/raw HTML was not independently retrieved/);assert.match(text,/No human, subject-matter/);}
    for(const s of p.selected_source_observations){assert.equal(s.independent_consultation.fresh_raw_html_retrieval,false);assert.equal(s.independent_consultation.fresh_raw_body_sha256,null);assert.equal(s.source_pages_imported,false);assert.equal(s.source_examples_imported,false);assert.equal(s.media_acquired,false);}
  }
  assert.deepEqual(source.sources.slice(-20),r.sources);for(const row of r.sources){assert.equal(row.status,'consulted');assert.equal(row.assets_acquired,false);assert.equal(row.asset_license,null);assert.match(row.scope,/not source consensus or psychometric CEFR certification/);}
});

test('Foundation02 fourth-ten preserves exact historical rebase, four lexical holds and all expression boundaries', () => {
  const r=foundation02FourthLanguageRecord,c=r.protected_context,hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(r.rebase.historical_registry_json_sha256,'f470936fc3bff7ff619b3af057a20cf5e05034013bbf08948e380847228dc4c5');
  assert.equal(r.rebase.current_registry_json_sha256,'fb45e1d9c7cbf479bf06ac0c00b39ec28de473c96c86cc1b071c72a572f8d437');
  const previous={...source,lexemes:source.lexemes.map(beforeFoundation02FourthLanguage),sources:beforeFoundation02FourthSources(source.sources)};
  assert.equal(hash(previous),r.rebase.current_registry_json_sha256);
  const research={...source,lexemes:source.lexemes.map(beforeFoundation02ThirdLanguage),sources:beforeFoundation02ThirdSources(source.sources)};
  assert.equal(hash(research),r.rebase.historical_registry_json_sha256);assert.equal(r.rebase.historical_approval_transferred,false);
  assert.deepEqual(c.prior_lexical_holds.map(row=>row.id),['collect.gather.v','notify.inform.v','postpone.delay-until-later.v','verify.establish-accuracy.v']);
  for(const row of c.prior_lexical_holds){const entry=source.lexemes.find(entry=>entry.id===row.id);assert.deepEqual(entry,row.before_entry);assert.equal(hash(entry),row.entry_json_sha256);assert.equal(entry.review.language,'pending');}
  assert.deepEqual([c.memberships.length,c.modules.length,c.expressions.length,c.derivative_expressions.length,c.focus_expressions.length,c.related_entries.length,c.inherited_expression_holds.length,c.containing_module_expressions.length,c.additional_foundation02_preservation.length],[200,20,130,42,4,63,17,10,4]);
  for(const group of ['expressions','derivative_expressions','focus_expressions','containing_module_expressions','additional_foundation02_preservation','inherited_expression_holds'])for(const row of c[group]){const entry=source.expressions.find(entry=>entry.id===row.id);assert.deepEqual(entry,row.before_entry);assert.equal(hash(entry),row.entry_json_sha256||row.before_entry_json_sha256);}
  for(const row of c.focus_expressions)assert.equal(row.before_entry.review.language,'pending');
  for(const row of c.related_entries){const entry=source.lexemes.find(entry=>entry.id===row.id);assert.deepEqual(beforeFoundation02FourthLanguage(entry),row.before_entry);assert.equal(hash(row.before_entry),row.entry_json_sha256);assert.equal(hash(beforeFoundation02ThirdLanguage(entry)),row.historical_entry_json_sha256);}
  for(const row of c.memberships)assert.equal(source.courses.find(course=>course.id===row.course_id).modules.find(module=>module.id===row.module_id).lexeme_ids[row.index],row.lexeme_id);
  for(const row of c.modules)assert.equal(hash(source.courses.find(course=>course.id===row.course_id).modules.find(module=>module.id===row.module_id)),row.module_json_sha256);
  assert.deepEqual(c.additional_foundation02_preservation.map(row=>row.id),['expr.foundation.module02.04','expr.foundation.module02.05','expr.foundation.module02.07','expr.foundation.module02.08']);
  assert.equal(hash(source.lexemes.find(entry=>entry.id==='complete.finish.v')),'63f724e5609017e7ea9077c84221bd2cd68f5c7f70b212034eb2d8603dbcec14');
});

test('Foundation02 fourth-ten keeps literal dictionary levels and fresh-rendered versus frozen-HTML provenance', () => {
  const r=foundation02FourthLanguageRecord,p=term=>r.patches.find(row=>row.after.text===term),a=(term,publisher)=>p(term).author_source_observations.find(row=>row.publisher===publisher),s=(term,publisher)=>p(term).selected_source_observations.find(row=>row.publisher===publisher);
  assert.equal(a('submit','Oxford University Press').observed_html_selected_levels[0].cefr,'b2');assert.equal(s('submit','Oxford University Press').independent_consultation.observed_rendered_selected_level,null);
  assert.equal(a('approve','Oxford University Press').observed_html_selected_levels[0].element_id,'approve_sng_2');assert.equal(a('approve','HarperCollins').observed_rendered_selected_level,'B1+');
  assert.equal(a('reject','Oxford University Press').observed_html_selected_levels[0].cefr,'b1');assert.equal(a('reject','HarperCollins').observed_rendered_selected_level,'B2');
  assert.equal(a('sign','Oxford University Press').observed_html_selected_levels[0].element_id,'sign_sng_7');assert.equal(a('sign','HarperCollins').observed_rendered_selected_level,'B1');
  assert.equal(a('delay','Oxford University Press').observed_html_selected_levels[0].cefr,'b2');assert.equal(a('delay','HarperCollins').observed_rendered_selected_level,'A2');assert.equal(p('delay').after.difficulty,'A2');
  for(const [term,level] of [['error','a2'],['shortage','b2']]){const attributes=a(term,'Oxford University Press').observed_html_selected_levels[0];assert.equal(attributes.cefr,null);assert.equal(attributes.fkcefr,level);assert.equal(a(term,'HarperCollins').observed_rendered_selected_level,'B2');}
  assert.equal(a('fault','Oxford University Press').observed_html_selected_levels[0].cefr,'b2');assert.equal(a('damage','Oxford University Press').observed_html_selected_levels[0].cefr,'b1');assert.equal(a('damage','HarperCollins').observed_rendered_selected_level,'B1+');
  assert.equal(p('missing').after.difficulty,'A2');assert.equal(a('missing','HarperCollins').observed_rendered_selected_level,'A2 for senses 1 and 2; no level observed for sense 3');assert.equal(s('missing','HarperCollins').independent_consultation.observed_rendered_selected_level,'A2 senses 1 and 2; no level observed on sense 3');
  for(const patch of r.patches)for(const observed of patch.author_source_observations){const independent=patch.selected_source_observations.find(row=>row.source_id===observed.id);if(observed.publisher==='Oxford University Press'){assert.deepEqual(independent.frozen_author_metadata.literal_selected_attributes,observed.observed_html_selected_levels);assert.equal(independent.frozen_author_metadata.author_raw_body_sha256,observed.raw_body_sha256);assert.match(independent.frozen_author_metadata.provenance,/not independently refetched/);}}
});

test('Foundation02 fourth-ten chronology rejects partial drift across all earlier histories', () => {
  const reversals=[beforeFoundation02FourthLanguage,beforeFoundation02ThirdLanguage,beforeFoundation02SecondLanguage,beforeAttendanceLanguage,beforeFoundation02FirstLanguage,beforeSupervisorLanguage,beforeFoundationFifthLanguage,beforeFoundationFourthLanguage,beforeFoundationThirdLanguage,beforeFoundationSecondLanguage];
  for(const p of foundation02FourthLanguageRecord.patches){for(const state of [p.before,p.after]){
    for(const reverse of reversals)assert.deepEqual(reverse(state),p.before);
    for(const change of [e=>{e.definition+=' Drift.';},e=>{e.example+=' Drift.';},e=>{e.difficulty='C2';},e=>{e.review.status='unexpected';},e=>{e.review.language='unexpected';},e=>{e.review.reviewer='unexpected';},e=>{e.review.domain='reviewed';},e=>{e.references[0].scope+=' Drift.';},e=>{e.editorial_notes+=' Drift.';},e=>{e.media.image.status='reviewed';},e=>{e.media.audio.voice='unexpected';},e=>{e.morphology.review.status='reviewed';},e=>{e.accepted_forms.push('unexpected');},e=>{e.regions.push('US');},e=>{e.practice_modes.push('unexpected');},e=>{e.extra=true;}]){const bad=structuredClone(state);change(bad);for(const reverse of reversals)assert.throws(()=>reverse(bad));}
  }const clone=beforeFoundation02FourthLanguage(p.after);clone.definition='clone only';assert.notEqual(clone.definition,p.before.definition);}
  const badSources=structuredClone(source.sources);badSources.at(-1).scope+=' Drift.';assert.throws(()=>beforeFoundation02FourthSources(badSources));assert.throws(()=>beforeFoundation02ThirdSources(badSources));
});

test('Foundation02 fourth-ten preserves registry isolation and separate readiness gates', () => {
  const r=foundation02FourthLanguageRecord,c=r.protected_context,ids=new Set(r.patches.map(row=>row.id)),hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(hash(source.lexemes.filter(entry=>!ids.has(entry.id))),c.all_other_lexemes_json_sha256);assert.equal(hash(source.expressions),c.all_expressions_json_sha256);assert.equal(hash(source.courses),c.all_courses_json_sha256);assert.equal(hash(source.themes),c.all_themes_json_sha256);assert.equal(hash(beforeFoundation02FourthSources(source.sources)),c.previous_sources_json_sha256);
  assert.equal(source.lexemes.filter(entry=>entry.review.status==='reviewed').length,148);assert.equal(source.lexemes.filter(entry=>entry.review.language==='reviewed').length,335);
  assert.equal(source.lexemes.filter(entry=>source.lexemeOrigins[entry.id]==='res://data/professional/lexemes/foundation-module02.json'&&entry.review.language==='reviewed').length,36);
  const audit=auditProfessionalContent({data:source});assert.equal(audit.summary.reviewed_lexemes,148);assert.equal(audit.summary.ready_modules,0);assert.equal(audit.summary.release_ready,false);
});
`;
const morphologyTests = String.raw`

test('Foundation02 fourth-ten language leaves exact morphology, media and historical Foundation donors unchanged', () => {
  for(const p of foundation02FourthLanguageRecord.patches){const entry=data.lexemes.find(row=>row.id===p.id);assert.deepEqual(entry,p.after);assert.deepEqual(entry.morphology,p.before.morphology);assert.deepEqual(entry.media,p.before.media);assert.equal(entry.review.domain,p.before.review.domain);assert.equal(entry.morphology.review.status,'pending');assert.deepEqual(beforeFoundationLanguage(entry),p.before);const bad=structuredClone(entry);bad.morphology.parts[0].canonical_id+='drift';assert.throws(()=>beforeFoundationLanguage(bad));
    for(const history of [foundationLanguageRecord,foundationSecondLanguageRecord,foundationThirdLanguageRecord,foundationFourthLanguageRecord,foundationFifthLanguageRecord]){const snapshots=history.protected_context.lexemes.filter(row=>row.entry.id===p.id);assert.equal(snapshots.length,1);assert.deepEqual(beforeFoundationLanguage(entry),snapshots[0].entry);}
  }
});
`;
const nativeTests = String.raw`

var _f02f_language_record: Dictionary = {}

func _f02f_reverse(entry: Dictionary) -> Dictionary:
	if _f02f_language_record.is_empty():
		_f02f_language_record = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module02-language-fourth10-2026-10-17.json"))
	var patches: Array = _f02f_language_record.patches.filter(func(patch: Dictionary) -> bool: return patch.id == entry.get("id", ""))
	if patches.is_empty():
		return {"ok": true, "entry": entry}
	if patches.size() != 1:
		return {"ok": false}
	var patch: Dictionary = patches[0]
	if entry != patch.before and entry != patch.after:
		return {"ok": false}
	return {"ok": true, "entry": patch.before.duplicate(true)}

func _check_foundation02_fourth_language() -> void:
	_f02f_language_record = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module02-language-fourth10-2026-10-17.json"))
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/foundation-module02.json"))
	check(_f02f_language_record.patches.size() == 10 and _f02f_language_record.held.is_empty(), "Foundation02 fourth-ten has ten language decisions and no new whole-entry holds")
	for patch: Dictionary in _f02f_language_record.patches:
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == patch.id)
		check(rows.size() == 1 and rows[0] == patch.after, "Fourth-ten live entry equals the exact delivered projection: " + patch.id)
		if rows.size() != 1:
			continue
		check(rows[0].morphology == patch.before.morphology and rows[0].morphology.review.status == "pending" and not Analysis.compile(rows[0].morphology).ok, "Language approval cannot admit pending morphology: " + patch.id)
		check(rows[0].media == patch.before.media and rows[0].review.domain == patch.before.review.domain, "Fourth-ten preserves exact media and domain gates: " + patch.id)
		for state: Dictionary in [patch.before, patch.after]:
			var reversed: Dictionary = _f02f_reverse(state)
			check(reversed.ok and reversed.entry == patch.before, "Fourth-ten exact historical and accepted states reverse: " + patch.id)
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
				check(not _f02f_reverse(changed).ok and not _f02t_reverse(changed).ok and not _f02s_reverse(changed).ok, "Fourth-ten and earlier chronology reject field drift: " + patch.id + "/" + field)
		var independent: Dictionary = _f02f_reverse(patch.after)
		independent.entry.definition = "clone only"
		check(patch.before.definition != "clone only", "Fourth-ten returns an independent historical clone")
	for held: Dictionary in _f02f_language_record.protected_context.prior_lexical_holds:
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == held.id)
		check(rows.size() == 1 and rows[0] == held.before_entry and rows[0].review.language == "pending", "Four prior lexical holds stay exact: " + held.id)
`;
function transform(file, before) {
  assert(files.includes(file));let text = before.toString('utf8');const edits = [];
  function replace(old, next, count = 1) {
    assert.equal(text.split(old).length - 1, count, file + ': exact anchor ' + old);
    text = text.split(old).join(next);edits.push({before: old, after: next, count});
  }
  if (file.endsWith('.gd')) {
    replace('\t_check_foundation02_third_language()', '\t_check_foundation02_third_language()\n\t_check_foundation02_fourth_language()');
    replace('func _f02t_reverse(entry: Dictionary) -> Dictionary:\n', 'func _f02t_reverse(entry: Dictionary) -> Dictionary:\n\tvar fourth_language: Dictionary = _f02f_reverse(entry)\n\tif not fourth_language.ok:\n\t\treturn {"ok": false}\n\tentry = fourth_language.entry\n');
    return {bytes: Buffer.from(text + nativeTests), edits, native: true, appended_tests: 1};
  }
  const content = file.includes('professional-content');
  replace('function beforeFoundation02ThirdLanguage(entry) {',
    `const foundation02FourthLanguageRecord = JSON.parse(fs.readFileSync(path.join(${content ? 'rootDir' : 'root'}, '${provenance}'), 'utf8'));\n${helper}\nfunction beforeFoundation02ThirdLanguage(entry) {\n  entry = beforeFoundation02FourthLanguage(entry);`);
  replace('function beforeFoundation02ThirdSources(sources) {', 'function beforeFoundation02ThirdSources(sources) {\n  sources = beforeFoundation02FourthSources(sources);');
  if (content) {
    replace('...foundation02ThirdLanguageRecord.patches].map(item => item.id)', '...foundation02ThirdLanguageRecord.patches, ...foundation02FourthLanguageRecord.patches].map(item => item.id)');
    replace('assert.equal(result.summary.reviewed_lexemes, 138);', 'assert.equal(result.summary.reviewed_lexemes, 148);');
    replace('assert.deepEqual(source.sources.slice(-16),r.sources);', 'assert.deepEqual(beforeFoundation02FourthSources(source.sources).slice(-16),r.sources);');
    replace('hash(source.lexemes.filter(entry=>!ids.has(entry.id)))', 'hash(source.lexemes.map(beforeFoundation02FourthLanguage).filter(entry=>!ids.has(entry.id)))');
    replace("assert.equal(source.lexemes.filter(entry=>entry.review.status==='reviewed').length,138);assert.equal(source.lexemes.filter(entry=>entry.review.language==='reviewed').length,325);",
      "assert.equal(source.lexemes.map(beforeFoundation02FourthLanguage).filter(entry=>entry.review.status==='reviewed').length,138);assert.equal(source.lexemes.map(beforeFoundation02FourthLanguage).filter(entry=>entry.review.language==='reviewed').length,325);");
    replace("source.lexemes.filter(entry=>source.lexemeOrigins[entry.id]==='res://data/professional/lexemes/foundation-module02.json'&&entry.review.language==='reviewed').length,26", "source.lexemes.map(beforeFoundation02FourthLanguage).filter(entry=>source.lexemeOrigins[entry.id]==='res://data/professional/lexemes/foundation-module02.json'&&entry.review.language==='reviewed').length,26");
    replace('const audit=auditProfessionalContent({data:source});assert.equal(audit.summary.reviewed_lexemes,138);', 'const historical={...source,lexemes:source.lexemes.map(beforeFoundation02FourthLanguage),sources:beforeFoundation02FourthSources(source.sources)};const audit=auditProfessionalContent({data:historical});assert.equal(audit.summary.reviewed_lexemes,138);');
    replace("const badSources=structuredClone(source.sources);badSources.at(-1).scope+=' Drift.';assert.throws(()=>beforeFoundation02ThirdSources(badSources));", "const badSources=structuredClone(source.sources);badSources.at(-21).scope+=' Drift.';assert.throws(()=>beforeFoundation02ThirdSources(badSources));");
  }
  return {bytes: Buffer.from(text + (content ? contentTests : morphologyTests)), edits, native: false, appended_tests: content ? 5 : 1};
}
module.exports = {transform, files};
