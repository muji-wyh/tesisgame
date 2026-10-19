'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const base = __dirname, root = path.resolve(base, '../../..');
const prior = path.join(root, 'build/professional-english/runtime-continuation-2026-10-17-r01/attempts/attempt-002');
const name = process.argv[2];
assert.match(name || '', /^attempt-[0-9]{3}$/);
const attempt = path.join(base, 'attempts', name), project = path.join(attempt, 'project');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
assert.ok(!fs.existsSync(attempt), 'Fresh attempt only; never overwrite prepared or executed evidence.');
const priorInventory = JSON.parse(fs.readFileSync(path.join(prior, 'execution-input-inventory.json')));
const oldReceipt = JSON.parse(fs.readFileSync(path.join(prior, 'validation-receipt.json')));
assert.equal(oldReceipt.ok, true); assert.equal(oldReceipt.checks, 125); assert.equal(oldReceipt.failures, 0);
const copies = [], guards = [], missing = [];
function priorRead(relative) {
  const row = priorInventory.files.find(item => item.path === relative);
  assert.ok(row, 'Retained executed file missing from inventory: ' + relative);
  const source = path.join(prior, 'project', relative), bytes = fs.readFileSync(source);
  assert.equal(bytes.length, row.bytes); assert.equal(hash(bytes), row.sha256);
  guards.push({ path: path.relative(root, source).replaceAll('\\', '/'), bytes: bytes.length, sha256: hash(bytes) });
  return bytes;
}
function put(relative, bytes) {
  const destination = path.join(project, relative);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, bytes, { flag: 'wx' });
  copies.push({ path: relative, bytes: bytes.length, sha256: hash(bytes) });
}
function json(value) { return Buffer.from(JSON.stringify(value, null, 2) + '\n'); }
function copyCurrent(relative) {
  const source = path.join(root, relative), bytes = fs.readFileSync(source);
  put(relative, bytes);
  guards.push({ path: relative, bytes: bytes.length, sha256: hash(bytes) });
}
const owner = priorRead('candidate_owner.gd');
assert.equal(hash(owner), '5ca565b95bad3702c4592acb0b6c34a3c786abd1bba20b66bd1951e5f0a93a50');
put('candidate_owner_reference.gd', owner);
for (const relative of priorInventory.files.filter(row => row.path.startsWith('scripts/')).map(row => row.path)) copyCurrent(relative);
put('fixture_catalog.gd', priorRead('fixture_catalog.gd'));
put('project.godot', priorRead('project.godot'));
put('negative_tests.gd', fs.readFileSync(path.join(base, 'negative_tests.gd')));
const descriptorRaw = priorRead('fixture/release.json'), descriptor = JSON.parse(descriptorRaw);
const indexRaw = priorRead('fixture/release/index.json'), index = JSON.parse(indexRaw);
const ready = index.modules.find(row => row.state === 'ready');
assert.equal(index.modules.filter(row => row.state === 'ready').length, 1);
const payloadRaw = priorRead('fixture/release/' + ready.payload.path), payload = JSON.parse(payloadRaw);
const themesRaw = priorRead('fixture/themes.json');
const selected = payload.course.modules.find(row => row.id === payload.module_id);
const mediaPath = selected.media_manifest.path.slice(6), mediaRaw = priorRead(mediaPath);
put(mediaPath, mediaRaw);
assert.equal(hash(indexRaw), descriptor.index.sha256);
assert.equal(hash(payloadRaw), ready.payload.sha256);
assert.equal(hash(themesRaw), descriptor.themes.sha256);
assert.equal(hash(mediaRaw), selected.media_manifest.sha256);
const cases = [];
function fixture(id, mutate, expectedError, forbiddenPhase, scope) {
  const prefix = 'cases/' + id + '/fixture/', resourcePrefix = 'res://' + prefix;
  const state = {
    descriptor: structuredClone(descriptor), index: structuredClone(index), payload: structuredClone(payload),
    indexRaw: Buffer.from(indexRaw), payloadRaw: Buffer.from(payloadRaw), themesRaw: Buffer.from(themesRaw),
    payloadStoragePath: ready.payload.path,
    missing: new Set(), indexChanged: false, payloadChanged: false, themesChanged: false,
    descriptorRaw: null, extraFiles: []
  };
  state.descriptor.index.path = resourcePrefix + 'release/index.json';
  state.descriptor.themes.path = resourcePrefix + 'themes.json';
  if (mutate) mutate(state);
  const selectedRow = state.index.modules.find(row => row.state === 'ready');
  if (state.payloadChanged) {
    state.payloadRaw = json(state.payload);
    selectedRow.payload = { path: 'modules/' + hash(state.payloadRaw) + '.json', bytes: state.payloadRaw.length, sha256: hash(state.payloadRaw) };
    state.payloadStoragePath = selectedRow.payload.path;
    state.indexChanged = true;
  }
  if (state.indexChanged) state.indexRaw = json(state.index);
  if (state.indexChanged) state.descriptor.index = { path: resourcePrefix + 'release/index.json', bytes: state.indexRaw.length, sha256: hash(state.indexRaw) };
  if (state.themesChanged) state.descriptor.themes = { path: resourcePrefix + 'themes.json', bytes: state.themesRaw.length, sha256: hash(state.themesRaw) };
  const files = [
    ['descriptor', prefix + 'release.json', state.descriptorRaw || json(state.descriptor)],
    ['index', prefix + 'release/index.json', state.indexRaw],
    ['themes', prefix + 'themes.json', state.themesRaw],
    ['payload', prefix + 'release/' + state.payloadStoragePath, state.payloadRaw]
  ];
  for (const [kind, relative, bytes] of files) {
    if (state.missing.has(kind)) missing.push(relative);
    else put(relative, bytes);
  }
  for (const [relative, bytes] of state.extraFiles) {
    if (bytes === null) missing.push(relative); else put(relative, bytes);
  }
  // Only test resource literals differ. No input path/pin is accepted by the owner API.
  let variant = owner.toString('utf8');
  variant = variant.replaceAll('res://fixture/release.json', resourcePrefix + 'release.json');
  variant = variant.replaceAll('res://fixture/release/', resourcePrefix + 'release/');
  variant = variant.replaceAll('res://fixture/themes.json', resourcePrefix + 'themes.json');
  const restored = variant.replaceAll(resourcePrefix + 'release.json', 'res://fixture/release.json')
    .replaceAll(resourcePrefix + 'release/', 'res://fixture/release/')
    .replaceAll(resourcePrefix + 'themes.json', 'res://fixture/themes.json');
  assert.equal(restored, owner.toString('utf8'), 'Variant may change only fixed synthetic resource literals.');
  put('cases/' + id + '/owner.gd', Buffer.from(variant));
  cases.push({ id, owner_path: 'res://cases/' + id + '/owner.gd', expected_error: expectedError,
    forbidden_phase: forbiddenPhase, scope, expected_ok: id === 'valid', fixed_resource_substitution_only: true });
}
const corrupt = bytes => { const result = Buffer.from(bytes); result[0] ^= 1; return result; };
fixture('valid', null, '', '', 'Exact historical audited synthetic fixture under fixed test paths.');
fixture('missing-descriptor', s => s.missing.add('descriptor'), 'Missing fixture resource.', 'descriptor_read', 'Absent fixed descriptor.');
fixture('descriptor-nonobject', s => { s.descriptorRaw = Buffer.from('[]\n'); }, 'not a JSON object', 'descriptor_validate', 'Native JSON value is not an object.');
fixture('descriptor-unsupported', s => { s.descriptor.kind = 'unsupported'; }, 'unavailable or unsupported', 'index_open', 'Unsupported descriptor contract.');
fixture('descriptor-caller-path', s => { s.descriptor.index.path = 'user://caller-policy.json'; }, 'invalid fixed resource', 'index_open', 'Caller-like descriptor path rejected.');
fixture('missing-index', s => s.missing.add('index'), 'Missing fixture resource.', 'index_read', 'Absent fixed index.');
fixture('index-hash', s => { s.indexRaw = corrupt(s.indexRaw); }, 'digest differs', 'index_decode', 'Same-length index corruption is rejected before decode.');
fixture('index-length', s => { s.descriptor.index.bytes += 1; }, 'length differs', 'index_read', 'Exact index length mismatch.');
fixture('index-policy', s => { s.index.policy_version = 'unsupported-policy'; s.indexChanged = true; }, 'Unsupported compiled fixture index', 'themes_open', 'Rebound synthetic hash cannot relax supported policy.');
fixture('index-duplicate', s => { s.index.modules[1] = structuredClone(s.index.modules[0]); s.indexChanged = true; }, 'Duplicate fixture module identity', 'themes_open', 'Rebound synthetic duplicate index row.');
fixture('index-unsafe-path', s => { s.index.modules.find(row => row.state === 'ready').payload.path = 'modules/../outside.json'; s.indexChanged = true; }, 'Invalid fixture ready descriptor', 'themes_open', 'Unsafe selected module path rejected.');
fixture('missing-themes', s => s.missing.add('themes'), 'Missing fixture resource.', 'themes_read', 'Absent fixed theme snapshot.');
fixture('themes-hash', s => { s.themesRaw = corrupt(s.themesRaw); }, 'digest differs', 'themes_decode', 'Same-length theme corruption is rejected before decode.');
fixture('themes-duplicate', s => { const t = JSON.parse(s.themesRaw); t.profiles[1] = structuredClone(t.profiles[0]); s.themesRaw = json(t); s.themesChanged = true; }, 'Fixture theme identity is invalid', 'select', 'Rebound synthetic theme identity duplication.');
fixture('missing-payload', s => s.missing.add('payload'), 'Missing fixture resource.', 'payload_read', 'Absent selected module.');
fixture('payload-hash', s => { s.payloadRaw = corrupt(s.payloadRaw); }, 'digest differs', 'payload_decode', 'Same-length payload corruption is rejected before native decode.');
fixture('payload-length', s => { s.index.modules.find(row => row.state === 'ready').payload.bytes += 1; s.indexChanged = true; }, 'length differs', 'payload_read', 'Exact selected payload length mismatch.');
fixture('payload-identity', s => { s.payload.module_id = 'module04'; s.payloadChanged = true; }, 'payload identity differs', 'resolve', 'Rebound synthetic payload cannot replace selected module identity.');
fixture('payload-membership', s => { s.payload.lexemes.pop(); s.payloadChanged = true; }, 'membership count differs', 'resolve', 'Rebound synthetic payload cannot omit a selected sense.');
fixture('payload-exception', s => { s.payload.lexical_domain[0].exception = { accepted: true }; s.payloadChanged = true; }, 'grants an exception', 'resolve', 'Rebound synthetic payload cannot introduce an accepted exception.');
fixture('payload-domain-review', s => { s.payload.lexical_domain[0].coarse_required = true; const row = s.payload.lexemes.find(x => x.id === s.payload.lexical_domain[0].id); row.review.domain = 'not_required'; s.payloadChanged = true; }, 'requires the original lexical and expression domain reviews', 'resolve', 'Rebound synthetic payload retains coarse-required domain review.');
fixture('missing-media-manifest', s => { const relative = 'data/professional/negative-fixture/missing-media-manifest.json'; const m = s.payload.course.modules.find(x => x.id === s.payload.module_id); m.media_manifest.path = 'res://' + relative; s.payloadChanged = true; s.extraFiles.push([relative, null]); }, 'media manifest is unavailable', 'publish', 'Unchanged actual catalog rejects missing manifest; no media fetch.');
fixture('media-manifest-hash', s => { const relative = 'data/professional/negative-fixture/corrupt-media-manifest.json'; const m = s.payload.course.modules.find(x => x.id === s.payload.module_id); m.media_manifest.path = 'res://' + relative; s.payloadChanged = true; s.extraFiles.push([relative, corrupt(mediaRaw)]); }, 'SHA-256 integrity check', 'publish', 'Unchanged actual media-manifest parser rejects corrupt bytes; no media fetch.');
put('case-manifest.json', json({ schema: 1, authority: 'none', curriculum_revision: payload.course.curriculum_revision, cases }));
for (const file of missing) assert.ok(!fs.existsSync(path.join(project, file)));
for (const guard of guards) assert.equal(hash(fs.readFileSync(path.join(root, guard.path))), guard.sha256);
const harness = ['prepare.cjs', 'negative_tests.gd', 'run-native.cjs'].map(relative => {
  const bytes = fs.readFileSync(path.join(base, relative));
  return { path: relative, bytes: bytes.length, sha256: hash(bytes) };
});
const runner = 'tools/run-godot.cjs', runnerBytes = fs.readFileSync(path.join(root, runner));
fs.writeFileSync(path.join(attempt, 'preparation-receipt.json'), json({ schema: 1, created_at: new Date().toISOString(),
  authority: 'none', files: copies, expected_missing: missing, source_guards: guards, harness_files: harness,
  runner_dependency: { path: runner, bytes: runnerBytes.length, sha256: hash(runnerBytes) },
  cases: cases.length, negative_cases: cases.length - 1, production_scripts_copied_unchanged: 8,
  candidate_logic_unchanged: true, media_files_copied: 0,
  scope: 'Immutable fixed-path synthetic corruption variants and exact prior owner logic, with current production catalog/resolver copies. Descriptor trust remains synthetic; no app authority.' }), { flag: 'wx' });
console.log(JSON.stringify({ project, files: copies.length, missing: missing.length, cases: cases.length, authority: 'none' }));
