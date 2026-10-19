'use strict';
// Scratch-only acquisition from the existing licensed local library. No native run.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const base = __dirname;
const root = path.resolve(base, '../../../..');
const library = 'Q:/uwok/Kenney Game Assets All-in-1 3.7.0/3D assets';
const raw = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const json = (name, data) => fs.writeFileSync(path.join(base, name), JSON.stringify(data, null, 2) + '\n', {flag: 'wx'});
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
assert.equal(fs.existsSync(path.join(base, 'source-record.json')), false, 'Preserve each existing revision');
const lexemePath = path.join(root, 'data/professional/lexemes/retail-pilot.json');
const lexeme = JSON.parse(fs.readFileSync(lexemePath, 'utf8')).lexemes.find(x => x.id === 'checkout.payment-area.n');
assert(lexeme);
const packs = [
  {id: 'mini-market', folder: 'Mini Market', version: '1.0', source: 'https://kenney.nl/assets/mini-market', creator: 'Kenney', additional_credits: ['Fleur Keijsers', 'Guus Vermeulen'], models: ['cash-register', 'character-employee', 'floor'], overview_previews: ['Preview.png', 'Sample.png']},
  {id: 'mini-characters', folder: 'Mini Characters', version: '1.0', source: 'https://kenney.nl/assets/mini-characters', creator: 'Kenney', additional_credits: [], models: ['character-female-b'], overview_previews: ['Preview.png']},
  {id: 'food-kit', folder: 'Food Kit', version: '2.0', source: 'https://kenney.nl/assets/food-kit', creator: 'Kenney', additional_credits: [], models: ['carton', 'apple'], overview_previews: []}
];
const files = [];
const models = [];
function retain(pack, relative, retainedRelative, role) {
  const original = path.join(library, pack.folder, relative);
  const retained = path.join(base, retainedRelative);
  fs.mkdirSync(path.dirname(retained), {recursive: true});
  fs.copyFileSync(original, retained, fs.constants.COPYFILE_EXCL);
  assert.equal(raw(original), raw(retained));
  const entry = {pack: pack.id, role, original_path: original.replaceAll('\\', '/'), retained_path: retainedRelative, bytes: fs.statSync(retained).size, sha256: raw(retained)};
  files.push(entry);
  return retained;
}
for (const pack of packs) {
  for (const model of pack.models) {
    const relative = `source/${pack.id}/original/${model}.glb`;
    const retained = retain(pack, `Models/GLB format/${model}.glb`, relative, 'complete original GLB');
    retain(pack, `Previews/${model}.png`, `source/${pack.id}/previews/${model}.png`, 'supplied source preview; not new render or accepted artwork');
    const bytes = fs.readFileSync(retained);
    assert.equal(bytes.toString('ascii', 0, 4), 'glTF');
    const gltf = JSON.parse(bytes.toString('utf8', 20, 20 + bytes.readUInt32LE(12)));
    models.push({id: `${pack.id}/${model}`, retained_path: relative, sha256: raw(retained), asset: gltf.asset, nodes: gltf.nodes, meshes: gltf.meshes.map(m => ({name: m.name, primitives: m.primitives.map(p => ({material: p.material, position_accessor: gltf.accessors[p.attributes.POSITION]}))})), materials: gltf.materials, images: gltf.images || [], skins: gltf.skins || [], animations: (gltf.animations || []).map(a => ({name: a.name, channel_count: a.channels.length, duration_seconds: Math.max(...a.samplers.map(s => gltf.accessors[s.input].max?.[0] || 0))}))});
    assert((gltf.images || []).every(i => i.uri === 'Textures/colormap.png'), 'Retain every external image dependency');
  }
  retain(pack, 'Models/GLB format/Textures/colormap.png', `source/${pack.id}/original/Textures/colormap.png`, 'original external material texture');
  retain(pack, 'License.txt', `source/${pack.id}/License.txt`, 'original license evidence');
  retain(pack, 'Overview.html', `source/${pack.id}/Overview.html`, 'original pack inventory');
  for (const file of pack.overview_previews) retain(pack, file, `source/${pack.id}/previews/${file}`, 'supplied source overview; not new render or accepted artwork');
}
json('source-record.json', {
  date: '2026-10-16', sense_id: lexeme.id, status: 'previously_acquired_originals_retained_for_scratch_inspection_only',
  definition: lexeme.definition, example: lexeme.example, approved_brief: lexeme.media.image.brief,
  brief_source: 'data/professional/lexemes/retail-pilot.json', brief_source_raw_sha256: raw(lexemePath),
  packs: packs.map(({models, overview_previews, folder, ...p}) => ({...p, license: 'CC0 1.0', license_url: 'https://creativecommons.org/publicdomain/zero/1.0/', acquisition_status: 'Already acquired in local Kenney All-in-1 3.7.0 library; exact originals copied into this scratch revision only.'})), files, models,
  available_animations: {station_floor_carton_apple: [], employee_and_shopper: models.filter(m => m.animations.length).map(m => ({model: m.id, animations: m.animations, inspection_status: 'Clip names and durations verified from GLB metadata. Supplied static previews inspected; native pose inspection has not run.'}))},
  preview_findings: [
    'Existing native cash-register source views show a complete pale checkout station with a dark goods belt and a terminal/display. This previously failed the isolated physical-key cash-register brief, but supplies the correct complete station for the payment-area sense.',
    'Mini Market employee source preview shows a green-and-white retail uniform and a friendly neutral face. Mini Characters character-female-b preview shows a casual yellow top, purple lower clothing and orange hair, visually distinct from the staff uniform.',
    'Food Kit carton and apple supplied previews show recognizable generic groceries, with no readable brand or payment information. Their original colormap materials will be retained.',
    'Mini Market supplied floor preview is a pale tiled surface. A complete 2-by-2 floor assembly may establish shared customer/staff space, but it must not reduce checkout recognition at real card sizes.'
  ],
  earlier_station_inspection: {path: 'build/professional-english/retail-term-art-review/cash-register/source-inspection', reviewed_views: ['front-three-quarter.png', 'rear-three-quarter.png'], source_sha256: '155f2eb666dea3a931d133a4953379898c8adb4b827ab60b86cae07235b9b598', reuse_scope: 'Read-only source evidence. Preserve the prior rejected-source outcome for the separate cash-register sense.'},
  acquisition_required: false, source_previews_are_term_artwork: false, production_integration: false,
  preservation: 'Complete original GLBs, all source child nodes, original skins, materials and external colormap textures are retained. Only complete-model root translation, yaw and uniform scale are planned. A named included character animation may be sampled for a still; no manual skeleton or mesh changes.'
});
json('composition-decision.json', {
  date: '2026-10-16', sense_id: lexeme.id, status: 'prepared_for_original_source_and_pose_probe_not_rendered_or_accepted',
  selected_meaning: lexeme.definition, exact_brief: lexeme.media.image.brief,
  working_brief: {audience: 'Professional English vocabulary learners using the existing phone-size Match and Memory cards', action: 'Recognize the place in a store where purchases are paid for', emotion: 'Clear, friendly, ordinary retail interaction', visual_language: 'Existing soft low-poly Kenney production sources, original materials, restrained studio lighting, no labels', target: 'Actual Match 126x72 (picture 102x52) and Memory 144x74 (picture 120x54), including the actual badge and matched 0.68 picture alpha'},
  diagnosis: 'An isolated counter or register cannot establish the payment-area sense. A complete belt-and-terminal station, two clearly related roles, and a few groceries should identify one staffed checkout lane; every subordinate element must remain subordinate at native phone size.',
  focal_subject: 'One complete checkout station and the space connecting a staff member behind the terminal with a shopper beside the goods belt.',
  proposed_composition: [
    'Use the complete Mini Market cash-register station at its original root scale.',
    'Place the green-and-white employee behind the terminal and the yellow-top shopper beside the goods belt, facing the same transaction area.',
    'Place one complete carton and one complete apple on the belt, scaled uniformly to remain groceries rather than focal icons.',
    'Compare one compact transparent group with one group on four complete original floor tiles; use the floor only if the lane remains legible at card size.',
    'Sample only the included static, idle or interact-right character clips. Confirm the sampled poses visually before rendering a candidate. No hand-authored joint posing.',
    'Use a camera that preserves the belt, terminal, both character roles and customer space without hiding faces or purchases. Keep all brand marks and credentials absent.'
  ],
  compare_against: {counter: 'Broad customer-serving surface with a small sealed parcel; no payment apparatus or staff/shopper interaction.', cash_register: 'One machine with physical keys and drawer base, excluded from this whole-lane picture.', checkout: 'Whole staffed payment place with store goods and a customer side.'},
  reject_if: ['The terminal alone dominates.', 'The scene reads as a help desk, table, hotel reception, two unrelated characters, or a generic shop.', 'Belt/groceries or staff/customer distinction disappear at 102x52.', 'The shopper pose floats, intersects the station, or suggests an unrelated action.', 'Source floor lowers scale so far that the checkout cannot be recognized.', 'Any mesh/material/texture substitution, readable labels, credentials or branding appears.'],
  sequence: ['Native original-source and included-pose inspection after root grants a slot.', 'Review those rendered sources before authorizing composition probe.', 'Run compact and tiled lane compositions, then choose only if actual WordCard states retain the intended sense.', 'Independent image review and production handoff remain later steps owned by root.'],
  scope: 'Scratch preparation only. No production, test, curriculum, language, morphology or readiness edits. No native rendering has run.'
});
console.log(JSON.stringify({base, retained_files: files.length, models: models.length, source_record_sha256: raw(path.join(base, 'source-record.json')), composition_decision_sha256: raw(path.join(base, 'composition-decision.json')), native_run: false}));
