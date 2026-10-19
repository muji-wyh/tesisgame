'use strict';
// Authored, undispatched. Exact-anchor afterimages require a validated root session.
const assert=require('node:assert/strict');
const B=require('./binding.cjs');
const provenance='data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json';
const files=['tests/professional-content.test.cjs','tests/professional-retail-morphology.test.cjs','tests/professional-retail-media.test.cjs','tests/godot/professional_retail_morphology_tests.gd'];
const helper=String.raw`function beforeFoundation02FifthLanguage(entry) {
  const patches = foundation02FifthLanguageRecord.patches.filter(patch => patch.id === entry.id);
  if (!patches.length) return entry;
  assert.equal(patches.length, 1);
  const patch = patches[0];
  if (require('node:util').isDeepStrictEqual(entry, patch.before)) return structuredClone(patch.before);
  assert.deepEqual(entry, patch.after, entry.id + ': exact fifth-ten language and metadata');
  return structuredClone(patch.before);
}
function beforeFoundation02FifthSources(sources) {
  const additions = foundation02FifthLanguageRecord.sources;
  assert.equal(additions.length, 16);
  assert.equal(new Set(additions.map(row => row.id)).size, 16);
  assert.deepEqual(sources.slice(-16), additions, 'Exact fifth-ten sixteen-source suffix required');
  const prefix = sources.slice(0, -16);
  for (const addition of additions) assert.equal(prefix.some(row => row.id === addition.id), false);
  return prefix;
}
function fifthLanguageHash(value) {
  return require('node:crypto').createHash('sha256').update(JSON.stringify(value)).digest('hex');
}
function verifyFifthLanguageDonors(registry, readHistory) {
  const rows = foundation02FifthLanguageRecord.history.rows;
  assert.equal(rows.length, 50);
  assert.equal(new Set(rows.map(row => row.history_path + '/' + row.id)).size, 50);
  for (const expected of rows) {
    const historical = readHistory(expected.history_path).protected_context.lexemes;
    assert.equal(expected.exact_count, 1);
    assert.equal(historical.filter(row => row.entry.id === expected.id).length, 1);
    const actual = historical[expected.index];
    assert.deepEqual(actual, expected.whole_row);
    assert.equal(fifthLanguageHash(actual), expected.whole_row_json_sha256);
    assert.equal(fifthLanguageHash(actual.entry), actual.json_sha256);
    assert.equal(registry.lexemeOrigins[expected.id], actual.resource);
    assert.deepEqual(beforeFoundation02FifthLanguage(registry.lexemes.find(entry => entry.id === expected.id)), actual.entry);
  }
}`;
const contentTests=String.raw`

test('Foundation02 fifth-ten installs eight exact accepted pairs and sixteen bounded sources', () => {
  const r=foundation02FifthLanguageRecord,h=fifthLanguageHash;
  const bytes=fs.readFileSync(path.join(rootDir,r.accepted_contract.path));
  assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),'e930b6e65c44daa4ab27b44523241edc41e10942d92b25f2254f47073acd2235');
  const accepted=JSON.parse(bytes);assert.equal(accepted.acceptance.delivery_metadata_technical_acceptance,true);assert.equal(accepted.acceptance.new_language_acceptance,false);
  assert.deepEqual(r.patches,accepted.patches);assert.deepEqual(r.sources,accepted.sources);assert.deepEqual(r.held,accepted.whole_entry_holds);
  assert.deepEqual(r.patches.map(p=>p.id),['broken.not-working.adj','urgent.needing-prompt-attention.adj','unclear.not-understandable.adj','safe.free-from-unacceptable-danger.adj','incident.workplace-event.n','concern.worrying-matter.n','solution.problem-answer.n','procedure.agreed-method.n']);
  const delta={definition:0,example:0,difficulty:0};
  for(const p of r.patches){
    const live=source.lexemes.find(entry=>entry.id===p.id);assert.deepEqual(live,p.after);assert.equal(h(p.before),p.before_entry_json_sha256);assert.equal(h(live),p.after_entry_json_sha256);
    const protect=e=>{const c=structuredClone(e);for(const k of ['definition','example','difficulty','references','editorial_notes'])delete c[k];for(const k of ['status','language','reviewer','reviewed_at'])delete c.review[k];return c;};
    assert.deepEqual(protect(live),protect(p.before));assert.equal(h(protect(live)),p.protected_fields_json_sha256);
    for(const key of Object.keys(delta)){assert.deepEqual(live[key],p.accepted_fields[key]);if(live[key]!==p.before[key])delta[key]++;}
    assert.deepEqual(live.references.slice(0,p.before.references.length),p.before.references);assert.equal(live.references.length-p.before.references.length,2);
    assert.deepEqual(live.references.slice(p.before.references.length).map(row=>row.source_id),p.source_ids);
    assert.equal(live.morphology.review.status,'pending');assert.deepEqual(live.media,p.before.media);assert.equal(live.review.domain,p.before.review.domain);
  }
  assert.deepEqual(delta,{definition:4,example:1,difficulty:5});assert.deepEqual(r.content_delta,delta);
  assert.deepEqual(source.sources.slice(-16),r.sources);assert.equal(new Set(r.sources.map(row=>row.id)).size,16);
  for(const row of r.sources){assert.equal(row.status,'consulted');assert.equal(row.assets_acquired,false);assert.equal(row.asset_license,null);}
  for(const id of r.excluded_source_ids)assert.equal(source.sources.some(row=>row.id===id),false);
  assert.deepEqual(r.source_observations,accepted.source_review);
  const observation=id=>r.source_observations.sources.find(row=>row.id===id);
  assert.equal(observation('foundation02-language-fifth10-collins-broken').author_rendered_level,null);
  assert.equal(observation('foundation02-language-fifth10-collins-urgent').author_rendered_level,'B1+');
  assert.equal(observation('foundation02-language-fifth10-collins-solution').author_rendered_level,'B1+');
  assert.equal(observation('foundation02-language-fifth10-collins-unclear').author_rendered_level,'B2');
});

test('Foundation02 fifth-ten preserves six complete holds and every protected context', () => {
  const r=foundation02FifthLanguageRecord,c=r.context,h=fifthLanguageHash;
  assert.deepEqual(r.held.map(row=>row.id).sort(),['collect.gather.v','notify.inform.v','postpone.delay-until-later.v','verify.establish-accuracy.v','unsafe.presenting-danger.adj','hazard.possible-harm.n'].sort());
  for(const row of r.held){const live=source.lexemes.find(e=>e.id===row.id);assert.deepEqual(live,row.before_entry);assert.equal(h(live),row.entry_json_sha256);assert.equal(live.review.language,'pending');}
  assert.deepEqual([c.groups.selected_memberships.length,c.groups.containing_modules.length,c.groups.containing_module_expressions.length,c.groups.expression_uses.length,c.groups.derivative_expression_uses.length,c.groups.focus_expressions.length,c.groups.related_entry_boundaries.length,c.groups.inherited_expression_holds.length,c.groups.additional_foundation02_preservation.length],[200,20,10,90,81,4,46,17,4]);
  for(const group of ['containing_module_expressions','expression_uses','derivative_expression_uses','focus_expressions','inherited_expression_holds','additional_foundation02_preservation'])for(const row of c.groups[group]){const entry=source.expressions.find(e=>e.id===row.id);assert.deepEqual(entry,row.before_entry);assert.equal(h(entry),row.entry_json_sha256||row.before_entry_json_sha256);}
  for(const row of c.groups.related_entry_boundaries){const entry=beforeFoundation02FifthLanguage(source.lexemes.find(e=>e.id===row.id));assert.deepEqual(entry,row.before_entry);assert.equal(h(entry),row.entry_json_sha256);}
  for(const row of c.groups.containing_modules){const module=source.courses.find(course=>course.id===row.course_id).modules.find(module=>module.id===row.module_id);assert.deepEqual(module,row.before_entry);assert.equal(h(module),row.module_json_sha256);}
  for(const row of c.groups.selected_memberships)assert.equal(source.courses.find(course=>course.id===row.course_id).modules.find(module=>module.id===row.module_id).lexeme_ids[row.index],row.lexeme_id);
  assert.deepEqual(source.lexemes.find(e=>e.id===c.complete_existing_form_scope_mismatch.id),c.complete_existing_form_scope_mismatch.before_entry);
  for(const row of c.pending_domain_expressions){const entry=source.expressions.find(e=>e.id===row.id);assert.equal(h(entry),row.preimage_sha256);assert.equal(entry.review.domain,'pending');}
  assert.equal(c.groups.related_entry_boundaries.some(row=>row.id==='shopping-bag.goods-carrier.n'),false);
});

test('Foundation02 fifth-ten whole-object reversals reject drift and preserve fifty donor rows', () => {
  const reversals=[beforeFoundation02FifthLanguage,beforeFoundation02FourthLanguage,beforeFoundation02ThirdLanguage,beforeFoundation02SecondLanguage,beforeAttendanceLanguage,beforeFoundation02FirstLanguage,beforeSupervisorLanguage,beforeFoundationFifthLanguage,beforeFoundationFourthLanguage,beforeFoundationThirdLanguage,beforeFoundationSecondLanguage];
  for(const p of foundation02FifthLanguageRecord.patches){
    for(const state of [p.before,p.after]){
      for(const reverse of reversals)assert.deepEqual(reverse(state),p.before);
      for(const mutate of [e=>{e.definition+=' Drift.';},e=>{e.example+=' Drift.';},e=>{e.difficulty='C2';},e=>{e.review.language='unexpected';},e=>{e.review.status='unexpected';},e=>{e.review.reviewer='unexpected';},e=>{e.review.reviewed_at='unexpected';},e=>{e.review.domain='reviewed';},e=>{e.references[0].scope+=' Drift.';},e=>{e.editorial_notes+=' Drift.';},e=>{e.media.image.status='reviewed';},e=>{e.media.audio.voice='unexpected';},e=>{e.morphology.review.status='reviewed';},e=>{e.accepted_forms.push('unexpected');},e=>{e.regions.push('US');},e=>{e.practice_modes.push('unexpected');},e=>{e.extra=true;}]){const bad=structuredClone(state);mutate(bad);for(const reverse of reversals)assert.throws(()=>reverse(bad));}
    }
    const copy=beforeFoundation02FifthLanguage(p.after);copy.definition='clone only';assert.notEqual(copy.definition,p.before.definition);
  }
  verifyFifthLanguageDonors(source,file=>JSON.parse(fs.readFileSync(path.join(rootDir,file),'utf8')));
  for(let i=1;i<=16;i++){const bad=structuredClone(source.sources);bad.at(-i).scope+=' Drift.';assert.throws(()=>beforeFoundation02FifthSources(bad));assert.throws(()=>beforeFoundation02FourthSources(bad));}
  const duplicated=structuredClone(source.sources);duplicated.unshift(structuredClone(duplicated.at(-1)));assert.throws(()=>beforeFoundation02FifthSources(duplicated));
  const reordered=structuredClone(source.sources);[reordered[reordered.length-1],reordered[reordered.length-2]]=[reordered.at(-2),reordered.at(-1)];assert.throws(()=>beforeFoundation02FifthSources(reordered));
});

test('Foundation02 fifth-ten restores the actual post-bag registry and keeps readiness separate', () => {
  const r=foundation02FifthLanguageRecord,h=fifthLanguageHash,ids=new Set(r.patches.map(p=>p.id));
  const previous={...source,lexemes:source.lexemes.map(beforeFoundation02FifthLanguage),sources:beforeFoundation02FifthSources(source.sources)};
  assert.equal(h(previous),r.registry_before_sha256);assert.equal(h(source),r.registry_after_sha256);
  assert.equal(h(source.lexemes.filter(e=>!ids.has(e.id))),r.protected_state.all_other_lexemes_json_sha256);
  for(const key of ['catalog','themes','courses','expressions','lexemeOrigins','expressionOrigins'])assert.equal(h(source[key]),r.protected_state[key+'_json_sha256']);
  assert.equal(h(previous.sources),r.source_prefix.json_sha256);assert.equal(previous.sources.length,r.source_prefix.count);
  for(const row of r.source_prefix.rows){assert.equal(previous.sources[row.index].id,row.id);assert.equal(h(previous.sources[row.index]),row.json_sha256);}
  const measure=data=>({reviewed_status:data.lexemes.filter(e=>e.review.status==='reviewed').length,reviewed_language:data.lexemes.filter(e=>e.review.language==='reviewed').length,foundation02_language:data.lexemes.filter(e=>data.lexemeOrigins[e.id]==='res://data/professional/lexemes/foundation-module02.json'&&e.review.language==='reviewed').length,sources:data.sources.length,lexemes:data.lexemes.length,expressions:data.expressions.length,images:data.lexemes.filter(e=>e.media.image.status==='integrated').length,audio:data.lexemes.filter(e=>e.media.audio.status==='integrated').length,ready_modules:data.courses.flatMap(c=>c.modules).filter(m=>m.status==='ready').length});
  assert.deepEqual(measure(previous),r.counts.before);assert.deepEqual(measure(source),r.counts.after);
  const audit=auditProfessionalContent({data:source});assert.equal(audit.errors.length,0);assert.equal(audit.summary.reviewed_lexemes,r.counts.after.reviewed_status);assert.equal(audit.summary.ready_modules,0);assert.equal(audit.summary.release_ready,false);
  const bag=source.lexemes.find(e=>e.id==='shopping-bag.goods-carrier.n');assert.deepEqual(bag,r.delivered_bag.entry);assert.equal(h(bag),'25300b5f9d78a6327c16c27143f1aeddd9dba1c41bdd4e42c20f30d36148cc85');assert.deepEqual(previous.lexemes.find(e=>e.id===bag.id),bag);
});

test('Foundation02 fifth-ten retains exact accepted evidence and actual predecessor receipts', () => {
  const r=foundation02FifthLanguageRecord,read=file=>JSON.parse(fs.readFileSync(path.join(rootDir,file),'utf8'));
  for(const row of r.retained_files){const bytes=fs.readFileSync(path.join(rootDir,row.target));assert.equal(bytes.length,row.bytes);assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),row.raw_sha256);}
  for(const prior of Object.values(r.lineage.predecessors)){assert.equal(read(prior.committed_receipt.path).status,'committed');assert.equal(read(prior.committed_journal.path).status,'committed');const receipt=read(prior.persisted_receipt.path);assert.equal(receipt.ok,true);assert.equal(receipt.error,null);assert(receipt.commands.every(command=>command.exit_code===0&&command.error===null&&command.signal===null));}
  for(const flag of ['new_language_acceptance','new_morphology_acceptance','new_expression_acceptance','new_media_acceptance','ready_module_or_course'])assert.equal(r.audit[flag],false);
});
`;
const morphologyTests=String.raw`

test('Foundation02 fifth-ten preserves exact morphology, media, holds and fifty complete historical donors', () => {
  const r=foundation02FifthLanguageRecord;assert.equal(r.patches.length,8);assert.equal(r.held.length,6);
  for(const p of r.patches){const entry=data.lexemes.find(e=>e.id===p.id);assert.deepEqual(entry,p.after);assert.deepEqual(entry.morphology,p.before.morphology);assert.deepEqual(entry.media,p.before.media);assert.equal(entry.review.domain,p.before.review.domain);assert.equal(entry.morphology.review.status,'pending');assert.deepEqual(beforeFoundationLanguage(entry),p.before);const bad=structuredClone(entry);bad.morphology.parts[0].canonical_id+=' Drift.';assert.throws(()=>beforeFoundationLanguage(bad));}
  for(const hold of r.held)assert.deepEqual(data.lexemes.find(entry=>entry.id===hold.id),hold.before_entry);
  verifyFifthLanguageDonors(data,file=>JSON.parse(fs.readFileSync(path.join(root,file),'utf8')));
});

test('Fifth-ten Foundation history and bag history remain disjoint strict routes', () => {
  const bag=shoppingBagImageRecord.patches[0];
  assert.equal(beforeFoundation02FifthLanguage(bag.after),bag.after);
  assert.equal(beforeFoundationLanguage(bag.after),bag.after);
  assert.doesNotThrow(()=>beforeRetailMedia(bag.after));assert.doesNotThrow(()=>beforeCounterImage(bag.after));
  assert.throws(()=>beforeRetailMedia(bag.before));assert.throws(()=>beforeCounterImage(bag.before));
  for(const p of foundation02FifthLanguageRecord.patches){assert.equal(beforeShoppingBagImage(p.after),p.after);assert.deepEqual(beforeRetailMedia(p.after),p.before);assert.deepEqual(beforeCounterImage(p.after),p.before);}
});
`;
const mediaTests=String.raw`

test('Fifth-ten language history preserves delivered bag media without relaxing bag reversal', () => {
  const bag=shoppingBagImageRecord.patches[0];assert.deepEqual(data.lexemes.find(e=>e.id===bag.id),bag.after);
  assert.equal(beforeFoundation02FifthLanguage(bag.after),bag.after);assert.throws(()=>beforeShoppingBagImage(bag.before));
  for(const p of foundation02FifthLanguageRecord.patches){const entry=data.lexemes.find(e=>e.id===p.id);assert.deepEqual(entry,p.after);assert.deepEqual(entry.media,p.before.media);assert.equal(beforeShoppingBagImage(entry),entry);assert.deepEqual(beforeFoundation02FifthLanguage(entry),p.before);}
  assert.equal(fifthLanguageHash(beforeFoundation02FifthSources(data.sources)),shoppingBagImageRecord.protected_state.sources_json_sha256);
});
`;
const nativeTests=String.raw`

var _f02_fifth_language_record: Dictionary = {}

func _f02_fifth_reverse(entry: Dictionary) -> Dictionary:
	if _f02_fifth_language_record.is_empty():
		_f02_fifth_language_record = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json"))
	var patches: Array = _f02_fifth_language_record.patches.filter(func(patch: Dictionary) -> bool: return patch.id == entry.get("id", ""))
	if patches.is_empty():
		return {"ok": true, "entry": entry}
	if patches.size() != 1:
		return {"ok": false}
	var patch: Dictionary = patches[0]
	if entry != patch.before and entry != patch.after:
		return {"ok": false}
	return {"ok": true, "entry": patch.before.duplicate(true)}

func _check_foundation02_fifth_language() -> void:
	_f02_fifth_language_record = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/provenance/foundation-module02-language-fifth10-2026-10-17.json"))
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/foundation-module02.json"))
	check(_f02_fifth_language_record.patches.size() == 8 and _f02_fifth_language_record.held.size() == 6, "Fifth-ten has eight accepted entries and six complete holds")
	for patch: Dictionary in _f02_fifth_language_record.patches:
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == patch.id)
		check(rows.size() == 1 and rows[0] == patch.after, "Fifth-ten exact live accepted object: " + patch.id)
		if rows.size() != 1:
			continue
		check(rows[0].morphology == patch.before.morphology and rows[0].morphology.review.status == "pending" and not Analysis.compile(rows[0].morphology).ok, "Fifth-ten cannot admit pending morphology: " + patch.id)
		check(rows[0].media == patch.before.media and rows[0].review.domain == patch.before.review.domain, "Fifth-ten exact media and domain preservation: " + patch.id)
		for state: Dictionary in [patch.before, patch.after]:
			var reversed: Dictionary = _f02_fifth_reverse(state)
			check(reversed.ok and reversed.entry == patch.before, "Fifth-ten exact historical pair reverses")
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
				check(not _f02_fifth_reverse(changed).ok and not _f02f_reverse(changed).ok and not _f02t_reverse(changed).ok and not _f02s_reverse(changed).ok, "Fifth-ten and earlier chains reject drift: " + patch.id + "/" + field)
		var independent: Dictionary = _f02_fifth_reverse(patch.after)
		independent.entry.definition = "clone only"
		check(patch.before.definition != "clone only", "Fifth-ten reversal clones history")
	for hold: Dictionary in _f02_fifth_language_record.held:
		var rows: Array = envelope.lexemes.filter(func(entry: Dictionary) -> bool: return entry.id == hold.id)
		check(rows.size() == 1 and rows[0] == hold.before_entry and rows[0].review.language == "pending", "Fifth-ten complete lexical hold: " + hold.id)
	var histories: Dictionary = {}
	check(_f02_fifth_language_record.history.rows.size() == 50, "Fifth-ten retains fifty complete donor rows")
	for expected: Dictionary in _f02_fifth_language_record.history.rows:
		if not histories.has(expected.history_path):
			histories[expected.history_path] = JSON.parse_string(FileAccess.get_file_as_string("res://" + expected.history_path))
		var rows: Array = histories[expected.history_path].protected_context.lexemes
		var matches: Array = rows.filter(func(row: Dictionary) -> bool: return row.entry.id == expected.id)
		check(expected.exact_count == 1 and matches.size() == 1 and rows[expected.index] == expected.whole_row, "Fifth-ten complete donor row and index: " + expected.id)
`;
function transform(ctx,file,input,record) {
  B.assertSession(ctx);assert(files.includes(file));assert.equal(B.sha(input),ctx.pins.get(file).raw_sha256);
  const original=input.toString('utf8'),newline=original.includes('\r\n')?'\r\n':'\n';let text=original;const edits=[];
  assert(!original.includes('function beforeFoundation02FifthLanguage(')&&!original.includes('func _f02_fifth_reverse('),'Fifth-ten already present');
  const normal=value=>value.replace(/\r?\n/g,newline);
  function replace(name,before,after,count=1){before=normal(before);after=normal(after);assert.equal(text.split(before).length-1,count,file+': '+name);text=text.split(before).join(after);edits.push({name,occurrences:count,before,after});}
  const native=file===files[3],content=file===files[0],morph=file===files[1];
  if(native){
    replace('native runner fifth-ten call','\t_check_foundation02_fourth_language()','\t_check_foundation02_fourth_language()\n\t_check_foundation02_fifth_language()');
    replace('native fourth-ten reaches fifth-ten once','func _f02f_reverse(entry: Dictionary) -> Dictionary:\n','func _f02f_reverse(entry: Dictionary) -> Dictionary:\n\tvar fifth_language: Dictionary = _f02_fifth_reverse(entry)\n\tif not fifth_language.ok:\n\t\treturn {"ok": false}\n\tentry = fifth_language.entry\n');
    return {bytes:Buffer.from(text+normal(nativeTests)),edits,appended_tests:1,native:true};
  }
  const bagHelper=original.match(/function beforeShoppingBagImage\(entry\) \{[\s\S]*?\r?\n\}/);
  assert(bagHelper,'Actual delivered bag helper required');
  const load=`const foundation02FifthLanguageRecord = JSON.parse(fs.readFileSync(path.join(${content?'rootDir':'root'}, '${provenance}'), 'utf8'));`;
  if(content||morph){
    replace('whole fifth-ten boundary before fourth-ten','function beforeFoundation02FourthLanguage(entry) {',load+'\n'+helper+'\nfunction beforeFoundation02FourthLanguage(entry) {\n  entry = beforeFoundation02FifthLanguage(entry);');
    replace('exact fifth-ten suffix before fourth-ten suffix','function beforeFoundation02FourthSources(sources) {','function beforeFoundation02FourthSources(sources) {\n  sources = beforeFoundation02FifthSources(sources);');
  }else{
    replace('media fifth-ten helpers before separate bag helper','function beforeShoppingBagImage(entry) {',load+'\n'+helper+'\nfunction beforeShoppingBagImage(entry) {');
    replace('bag-time other-lexeme history','hash(data.lexemes.filter(entry=>entry.id!==\'shopping-bag.goods-carrier.n\'))','hash(data.lexemes.map(beforeFoundation02FifthLanguage).filter(entry=>entry.id!==\'shopping-bag.goods-carrier.n\'))');
    replace('bag-time source history only',"for(const key of ['catalog','courses','expressions','sources','themes','lexemeOrigins','expressionOrigins'])assert.equal(hash(data[key]),c[key+'_json_sha256'],key);","for(const key of ['catalog','courses','expressions','sources','themes','lexemeOrigins','expressionOrigins'])assert.equal(hash(key==='sources'?beforeFoundation02FifthSources(data.sources):data[key]),c[key+'_json_sha256'],key);");
  }
  if(content){
    replace('accepted Foundation ID set','...foundation02FourthLanguageRecord.patches].map(item => item.id)','...foundation02FourthLanguageRecord.patches, ...foundation02FifthLanguageRecord.patches].map(item => item.id)');
    assert.equal(record.counts.before.reviewed_status,148,'Reinspect exact live count anchor if actual baseline changes');
    replace('live measured reviewed count','assert.equal(result.summary.reviewed_lexemes, 148);','assert.equal(result.summary.reviewed_lexemes, foundation02FifthLanguageRecord.counts.after.reviewed_status);');
    replace('fourth-ten source suffix remains exact','assert.deepEqual(source.sources.slice(-20),r.sources);','assert.deepEqual(beforeFoundation02FifthSources(source.sources).slice(-20),r.sources);');
    replace('fourth-ten all-other bag collection keeps lexical history','hash(shoppingBagHistoryLexemes().filter(entry=>!ids.has(entry.id)))','hash(shoppingBagHistoryLexemes().map(beforeFoundation02FifthLanguage).filter(entry=>!ids.has(entry.id)))');
    replace('fourth-ten historical counts',"assert.equal(source.lexemes.filter(entry=>entry.review.status==='reviewed').length,148);assert.equal(source.lexemes.filter(entry=>entry.review.language==='reviewed').length,335);","assert.equal(source.lexemes.map(beforeFoundation02FifthLanguage).filter(entry=>entry.review.status==='reviewed').length,148);assert.equal(source.lexemes.map(beforeFoundation02FifthLanguage).filter(entry=>entry.review.language==='reviewed').length,335);");
    replace('fourth-ten historical module count',"source.lexemes.filter(entry=>source.lexemeOrigins[entry.id]==='res://data/professional/lexemes/foundation-module02.json'&&entry.review.language==='reviewed').length,36","source.lexemes.map(beforeFoundation02FifthLanguage).filter(entry=>source.lexemeOrigins[entry.id]==='res://data/professional/lexemes/foundation-module02.json'&&entry.review.language==='reviewed').length,36");
    replace('fourth-ten historical audit restores bag once','const audit=auditProfessionalContent({data:source});assert.equal(audit.summary.reviewed_lexemes,148);','const historical={...source,lexemes:shoppingBagHistoryLexemes().map(beforeFoundation02FifthLanguage),sources:beforeFoundation02FifthSources(source.sources)};const audit=auditProfessionalContent({data:historical});assert.equal(audit.summary.reviewed_lexemes,148);');
    replace('third-ten negative still mutates third-ten suffix',"const badSources=structuredClone(source.sources);badSources.at(-21).scope+=' Drift.';assert.throws(()=>beforeFoundation02ThirdSources(badSources));","const badSources=structuredClone(source.sources);badSources.at(-(foundation02FifthLanguageRecord.sources.length+21)).scope+=' Drift.';assert.throws(()=>beforeFoundation02ThirdSources(badSources));");
    replace('fourth-ten negative still mutates fourth-ten suffix',"const badSources=structuredClone(source.sources);badSources.at(-1).scope+=' Drift.';assert.throws(()=>beforeFoundation02FourthSources(badSources));assert.throws(()=>beforeFoundation02ThirdSources(badSources));","const badSources=structuredClone(source.sources);badSources.at(-(foundation02FifthLanguageRecord.sources.length+1)).scope+=' Drift.';assert.throws(()=>beforeFoundation02FourthSources(badSources));assert.throws(()=>beforeFoundation02ThirdSources(badSources));");
  }
  assert(text.includes(bagHelper[0]),'Strict delivered bag helper bytes must remain exact');
  assert.equal(text.split('entry = beforeShoppingBagImage(entry);').length,original.split('entry = beforeShoppingBagImage(entry);').length,'No new common bag reversal');
  text+=normal(content?contentTests:morph?morphologyTests:mediaTests);
  return {bytes:Buffer.from(text),edits,appended_tests:content?5:morph?2:1,native:false};
}
module.exports={files,transform};
