'use strict';
// UNEXECUTED source snippets, not a transformer. Final anchors and hashes are null.
const foundationHelpers = String.raw`function beforeFoundation02FifthLanguage(entry) {
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
}`;

const bagMediaBoundary = String.raw`// Replace only the bag-time protected-state comparisons after actual final binding.
assert.equal(hash(data.lexemes.map(beforeFoundation02FifthLanguage).filter(entry => entry.id !== 'shopping-bag.goods-carrier.n')), c.other_lexemes_json_sha256);
for (const key of ['catalog', 'courses', 'expressions', 'sources', 'themes', 'lexemeOrigins', 'expressionOrigins']) {
  const historical = key === 'sources' ? beforeFoundation02FifthSources(data.sources) : data[key];
  assert.equal(hash(historical), c[key + '_json_sha256'], key);
}`;

const wholeDonorAssertions = String.raw`assert.equal(r.history.rows.length, 50);
for (const expected of r.history.rows) {
  const history = historyByPath[expected.history_path];
  const rows = history.protected_context.lexemes;
  assert.equal(rows.filter(row => row.entry.id === expected.id).length, 1);
  assert.equal(expected.exact_count, 1);
  const row = rows[expected.index];
  assert.deepEqual(row, expected.whole_row);
  assert.equal(hash(row), expected.whole_row_json_sha256);
  assert.equal(hash(row.entry), row.json_sha256);
  assert.deepEqual(beforeFoundation02FifthLanguage(data.lexemes.find(entry => entry.id === expected.id)), row.entry);
}`;

const nativeHelper = String.raw`var _f02_fifth_language_record: Dictionary = {}

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
`;

const transformations = [
  {target: 'tests/professional-content.test.cjs', final_before_sha256: null, exact_anchors: null, requirements: [
    'Load new provenance and insert whole-object helpers; call fifth lexical helper first in fourth lexical helper, and fifth source helper first in fourth source helper.',
    'Append eight patches to the accepted Foundation ID set; bind live reviewed totals from actual measured final input only.',
    'Keep all fourteen bag collection boundaries. Add fifth lexical mapping only to the existing fourth-ten all-other bag collection filter.',
    'Wrap fourth-ten exact twenty-source suffix assertion with fifth source restoration. Preserve literal old expected hashes and counts.',
    'Historical fourth-ten count checks restore fifth lexical state; its audit restores fifth plus bag lexical state and fifth sources. New fifth previous-registry audit retains delivered bag.',
    'Retarget earlier source-drift mutations to their intended exact historical suffix after fifth restoration; preserve assertions for each earlier helper.',
    'Add focused tests for exact accepted eight projections/metadata, 16 sources, six holds, context, 50 whole donor rows, chronology rejection, protected state and retained evidence.'
  ]},
  {target: 'tests/professional-retail-morphology.test.cjs', final_before_sha256: null, exact_anchors: null, requirements: [
    'Insert fifth lexical/source helpers and chain through fourth helpers. No bag call in any Foundation helper.',
    'Keep bag wrappers at beforeFifth10, beforeCounterImage, and direct Retail03 fifth-ten comparison exactly as delivered.',
    'Add complete eight-entry unchanged morphology/media checks, six full holds, 50 whole donors at original indices, strict drift rejection and clone checks.',
    'Re-enumerate direct historical snapshot callers against eight accepted IDs; review any additional exact required wrapper separately.'
  ]},
  {target: 'tests/professional-retail-media.test.cjs', final_before_sha256: null, exact_anchors: null, requirements: [
    'Load fifth provenance and add fifth lexical/source helpers for bag-time full-registry preservation comparisons.',
    'Use bagMediaBoundary only for the bag all-other-lexeme hash and generic protected key loop; retain delivered bag and all original image/audio assertions.',
    'Keep existing strict bag after-only reversal, its already-reversed negative check, five focused bag cases, descriptor bytes and historical media totals.'
  ]},
  {target: 'tests/godot/professional_retail_morphology_tests.gd', final_before_sha256: null, exact_anchors: null, requirements: [
    'Add nativeHelper and call it first in _f02f_reverse; preserve older native reverse chains and all original expectations.',
    'Add a new check function and one runner call for exact eight afterobjects, pending unchanged morphology/media/domain, six complete holds, drift rejection and independent clone behavior.',
    'Exercise actual caller chains and preserved donor content; no existing native count or success receipt is fabricated.'
  ]}
];

function transform() {
  throw new Error('UNBOUND outline: exact final post-bag shared-test anchors and raw preimages are not captured. No afterimage may be emitted.');
}

module.exports = {status: 'UNBOUND_OUTLINE_ONLY', foundationHelpers, bagMediaBoundary, wholeDonorAssertions, nativeHelper, transformations, transform};
if (require.main === module) transform();
