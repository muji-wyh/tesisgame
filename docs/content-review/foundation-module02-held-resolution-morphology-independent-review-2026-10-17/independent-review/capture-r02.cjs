'use strict';
// Independent raw-data inspection only. Never imports or executes project code.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const author = 'build/professional-english/foundation02-held-resolution-morphology-research-r01';
const candidate = 'build/professional-english/foundation02-fourth10-native-candidate-r02/attempt-001/project';
const webFixture = 'build/professional-english/domain-runtime-web-fixture-r04/attempt-001/project';
const out = __dirname;
const measured = new Map();
const checks = [];
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const stable = v => JSON.stringify(v, function(k, x) { return x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.keys(x).sort().map(key => [key, x[key]])) : x; });
const norm = p => p.replaceAll('\\', '/');
function allowed(p) {
  return p.startsWith(author + '/') || p.startsWith(candidate + '/') || p.startsWith(webFixture + '/') || p === 'build/professional-english/foundation02-fourth10-native-candidate-r02/attempt-001/receipt.json' || p.startsWith('docs/content-review/foundation-module02-verify-resolution-independent-review-2026-10-17/') || p.startsWith('docs/content-review/foundation-module02-notify-resolution-independent-review-2026-10-17/') || p.startsWith('docs/content-review/foundation-module02-collect-gather-independent-review-2026-10-17/');
}
function bytes(p) {
  p = norm(p);
  if (!allowed(p) || p.split('/').includes('..')) throw new Error('Read outside immutable allowlist: ' + p);
  const b = fs.readFileSync(path.join(root, p));
  const row = {path: p, bytes: b.length, sha256: sha(b)};
  if (measured.has(p) && stable(measured.get(p)) !== stable(row)) throw new Error('Input changed during inspection: ' + p);
  measured.set(p, row);
  return b;
}
const json = p => JSON.parse(bytes(p).toString('utf8'));
function check(label, passed) { checks.push({label, passed: Boolean(passed)}); if (!passed) throw new Error(label); }
function exact(label, a, b) { check(label, stable(a) === stable(b)); }
function write(name, value) { fs.writeFileSync(path.join(out, name), JSON.stringify(value, null, 2) + '\n', {flag: 'wx'}); }
const attempt = path.join(out, 'capture-r02-attempt.json');
fs.writeFileSync(attempt, JSON.stringify({started_at: new Date().toISOString(), scope: 'frozen raw data only', script_sha256: sha(fs.readFileSync(__filename))}, null, 2) + '\n', {flag: 'wx'});
try {
  const inv = json(author + '/inventory.json');
  check('Exact assigned author inventory', measured.get(author + '/inventory.json').sha256 === '9ecff44931f5512774c98ef4781d1720d3fdb416855dd53e6e56b065cb0d6741');
  for (const r of inv.files) { const b = bytes(author + '/' + r.path); check('Author file bytes and hash: ' + r.path, b.length === r.bytes && sha(b) === r.sha256); }
  const pins = json(author + '/input-pins.json');
  const skipped = [];
  for (const r of pins) {
    if (!allowed(norm(r.path))) { skipped.push(r); continue; }
    const b = bytes(r.path); check('Frozen author input exact: ' + norm(r.path), b.length === r.bytes && sha(b) === r.sha256);
  }
  const replacements = [
    ['data/professional/schemas/morphology.schema.json', candidate + '/data/professional/schemas/morphology.schema.json'],
    ['scripts/morphology_analysis.gd', candidate + '/scripts/morphology_analysis.gd'],
    ['scripts/learning_content_resolver.gd', webFixture + '/scripts/learning_content_resolver.gd']
  ];
  for (const [original, frozen] of replacements) {
    const pin = pins.find(p => norm(p.path) === original);
    const b = bytes(frozen);
    check('Immutable equivalent of author runtime pin: ' + original, pin && pin.bytes === b.length && pin.sha256 === sha(b));
  }
  const accepted = json(author + '/accepted-language-basis.json');
  exact('Ensure accepted nine fields including insure', accepted.ensure, json('docs/content-review/foundation-module02-verify-resolution-independent-review-2026-10-17/review/accepted-lexical-fields.json'));
  exact('Inform accepted new identity and nine lexical fields', accepted.inform, json('docs/content-review/foundation-module02-notify-resolution-independent-review-2026-10-17/independent-review/accepted-lexical-fields.json'));
  exact('Collect exact accepted gathering projection', accepted.collect.fields, json('docs/content-review/foundation-module02-collect-gather-independent-review-2026-10-17/review/review.json').accepted_lexical_fields);
  const analyses = json(author + '/analyses.proposed.json');
  const fallback = json(author + '/ensure.atomic-alternative.proposed.json');
  const catalog = json(candidate + '/data/professional/catalog.json');
  check('Frozen catalog has 163 lexical envelopes', catalog.lexeme_files.length === 163);
  const entries = [];
  const byId = new Map();
  for (const resource of catalog.lexeme_files) {
    const envelope = json(candidate + '/' + resource.replace('res://', ''));
    for (const entry of envelope.lexemes) { check('Unique frozen lexeme: ' + entry.id, !byId.has(entry.id)); const row = {resource, entry}; entries.push(row); byId.set(entry.id, row); }
  }
  check('Frozen corpus has 4,939 lexemes', entries.length === 4939);
  const scan = json(author + '/canonical-family-scan.json');
  const contexts = json(author + '/canonical-family-contexts.before.json');
  const selected = new Set(scan.matched_canonical_ids);
  const matching = entries.filter(r => r.entry.morphology?.parts.some(p => selected.has(p.canonical_id)));
  check('Exactly 21 selected-family context records', matching.length === 21 && contexts.length === 21);
  exact('All 21 complete selected-family snapshots exact', contexts, matching);
  exact('All selected-family summary rows exact', scan.rows, matching.map(({entry: e}) => ({id: e.id, definition: e.definition, language: e.review.language, domain: e.review.domain, morphology_review: e.morphology.review.status, matched_parts: e.morphology.parts.filter(p => selected.has(p.canonical_id)).map(p => ({id:p.id,canonical_id:p.canonical_id,canonical:p.canonical,surface:p.surface,type:p.type}))})));
  const contrasts = json(author + '/protected-contexts.additional.json').objects;
  check('Four additional complete contrasts', contrasts.length === 4);
  for (const r of contrasts) exact('Additional contrast exact: ' + r.entry.id, {resource:r.resource,entry:r.entry}, byId.get(r.entry.id));
  const newIds = [...analyses.flatMap(a => a.parts.map(p => p.canonical_id)), ...fallback.parts.map(p => p.canonical_id)];
  exact('Five declared new IDs cover selected structures and fallback', newIds, scan.proposed_canonical_ids);
  const collisions = entries.flatMap(r => (r.entry.morphology?.parts || []).filter(p => newIds.includes(p.canonical_id)).map(p => ({lexeme_id:r.entry.id, canonical_id:p.canonical_id})));
  exact('No proposed canonical ID collision in frozen corpus', collisions, []);
  const structural = [];
  for (const a of [...analyses, fallback]) {
    check('Author has not self-approved: ' + a.lexeme_id + '/' + a.kind, a.review.status === 'pending' && a.review.reviewer === null && a.review.reviewed_at === null);
    const ids = new Set(); const span = new Map();
    a.parts.forEach((p,i) => { check('Unique part ID: '+a.id+'/'+p.id, !ids.has(p.id)); ids.add(p.id); span.set(p.id,{start:i,end:i+1,surface:p.surface}); check('No false layout split: '+a.id+'/'+p.id, p.break_offsets.length === 0); });
    for (const n of a.nodes) {
      check('Unique node ID: '+a.id+'/'+n.id, !ids.has(n.id)); ids.add(n.id);
      const l=span.get(n.left), r=span.get(n.right);
      check('Exact adjacent authored join: '+a.id+'/'+n.id, l && r && l.end===r.start && n.surface===l.surface+r.surface && n.break_offsets.length===0);
      span.set(n.id,{start:l.start,end:r.end,surface:n.surface});
    }
    const used = new Set(); const visit = id => { used.add(id); const n=a.nodes.find(x=>x.id===id); if(n){visit(n.left);visit(n.right);} };
    for(const id of a.roots){const r=span.get(id);check('Full exact root: '+a.id+'/'+id,r && r.start===0 && r.end===a.parts.length && r.surface===a.text);visit(id);}
    check('No unreachable or extra graph elements: '+a.id, used.size===ids.size);
    check('Atomic versus composed shape: '+a.id, a.kind==='atomic' ? a.parts.length===1 && a.nodes.length===0 : a.parts.length===2 && a.nodes.length===1);
    if(a !== fallback) structural.push(Object.fromEntries(['schema','lexeme_id','text','kind','parts','nodes','roots'].map(k=>[k,a[k]])));
  }
  check('Ensure accepted surface remains canonical ensure', analyses[0].text === accepted.ensure.text && accepted.ensure.accepted_forms.includes('insure'));
  check('Inform distinct from pending clinical base', analyses[1].parts[0].canonical_id !== byId.get('informed-consent.informed-voluntary-care-agreement.n').entry.morphology.parts[0].canonical_id);
  check('Collect distinct from pending pickup bases', ['waste-collection.organized-pickup-of-waste-for-transport.n','waste-collection-point.designated-place-where-waste-is-picked-up.n'].every(id=>byId.get(id).entry.morphology.parts.every(p=>p.canonical_id!==analyses[2].parts[0].canonical_id)));
  const rows = [...measured.values()].sort((a,b)=>a.path.localeCompare(b.path));
  for(const r of rows){const b=bytes(r.path);check('End-of-inspection exact: '+r.path,sha(b)===r.sha256 && b.length===r.bytes);}
  write('accepted-analysis-structure.json', structural);
  write('input-pins.json', rows);
  write('capture-r02-result.json', {
    status:'passed_independent_raw_data_inspection_not_project_execution', recorded_at:new Date().toISOString(),
    author_inventory_sha256:measured.get(author+'/inventory.json').sha256,
    counts:{author_payload_files:inv.files.length,author_pins:pins.length,frozen_author_pins:pins.length-skipped.length,live_author_pins_not_read:skipped.length,immutable_runtime_substitutions:replacements.length,measured_immutable_inputs:rows.length,lexeme_envelopes:catalog.lexeme_files.length,lexemes:entries.length,selected_family_contexts:contexts.length,additional_contrasts:contrasts.length,proposed_canonical_ids:newIds.length,accepted_structures:structural.length,checks:checks.length},
    original_live_pins_not_read:skipped, immutable_substitutions:replacements.map(([original,frozen])=>({original,frozen})),
    checks,project_modules_imported:false,project_tests_or_native_executed:false,production_or_shared_tests_written:false,live_saves_opened:false,live_binding:'UNBOUND'
  });
  console.log(JSON.stringify({status:'passed',measured_inputs:rows.length,checks:checks.length,lexemes:entries.length}));
} catch(error) {
  write('capture-r02-failure.json',{status:'failed',recorded_at:new Date().toISOString(),error:String(error.stack || error),checks,measured_inputs:[...measured.values()]});
  console.error(String(error.stack || error));process.exitCode=1;
}
