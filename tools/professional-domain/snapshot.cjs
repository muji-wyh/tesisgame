'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {codec,LIMITS,DECISIONS,assertAncestors,contractInventory,assertEmptyDecisions} = require('./contract.cjs');
const inputs = require('./inputs.cjs');
const {fullInventory} = require('./release-gates.cjs');

function localPath(resource) {
  if (typeof resource !== 'string' || !/^res:\/\/(?:[A-Za-z0-9_-][A-Za-z0-9_.-]*\/)*[A-Za-z0-9_-][A-Za-z0-9_.-]*$/.test(resource) ||
      resource.slice(6).split('/').some(piece => piece === '.' || piece === '..')) throw Error('Unsafe supporting resource: ' + resource);
  return resource.slice(6);
}
function observe(liveRoot) {
  liveRoot = path.resolve(liveRoot); assertAncestors(liveRoot);
  const governed = inputs.inventory(liveRoot), records = new Map();
  let total = 0;
  const add = relative => {
    if (records.has(relative)) return;
    const filename = path.join(liveRoot, relative); assertAncestors(filename);
    const raw = codec.readBounded(filename, LIMITS.fullFileBytes);
    total += raw.length;
    if (records.size >= LIMITS.fullFiles || total > LIMITS.fullBytes) throw Error('Observed closure budget exceeded');
    records.set(relative, {path:relative, bytes:raw.length, sha256:codec.sha256(raw)});
  };
  governed.forEach(entry => add(entry.path));
  add(DECISIONS);
  assertEmptyDecisions(codec.strictParse(codec.readBounded(path.join(liveRoot, DECISIONS), codec.LIMITS.decisionManifest)));
  const read = resource => {
    const relative = localPath(resource); add(relative);
    return JSON.parse(codec.readBounded(path.join(liveRoot, relative), codec.LIMITS.file).toString('utf8'));
  };
  const catalog = read('res://data/professional/catalog.json');
  const themes = read(catalog.themes).profiles;
  const asset = value => { if (value?.path) add(localPath(value.path)); };
  const schemaDirectory = path.join(liveRoot, 'data/professional/schemas'); assertAncestors(schemaDirectory);
  for (const name of fs.readdirSync(schemaDirectory)) {
    if (!/^[a-z-]+\.schema\.json$/.test(name)) throw Error('Unexpected schema file');
    add('data/professional/schemas/' + name);
  }
  for (const item of catalog.courses) for (const module of read(item.manifest).modules) {
    if (module.media_manifest) {
      const manifest = read(module.media_manifest.path);
      for (const resource of manifest.resources || []) add(localPath('res://' + resource.path));
    }
  }
  for (const [group,key] of [['lexemes','lexeme_files'], ['expressions','expression_files']]) {
    for (const resource of catalog[key]) for (const item of read(resource)[group]) Object.values(item.media).forEach(asset);
  }
  for (const theme of themes) {
    Object.values(theme.art).forEach(asset); asset(theme.preview);
    for (const clip of theme.ambient_motion.clips) asset(clip.image);
    add(localPath(theme.audio.music)); add(localPath(theme.audio.interaction_bank));
  }
  if (codec.canonical(governed) !== codec.canonical(inputs.inventory(liveRoot))) throw Error('Live governed sources changed during observation');
  return [...records.values()].sort((a,b) => a.path < b.path ? -1 : 1);
}
function freeze(liveRoot, destination) {
  liveRoot = path.resolve(liveRoot); destination = path.resolve(destination);
  if (fs.existsSync(destination)) throw Error('Snapshot destination exists; refusing overwrite');
  assertAncestors(path.dirname(destination));
  const contracts = contractInventory(), before = observe(liveRoot);
  fs.mkdirSync(destination);
  for (const entry of before) {
    const raw = codec.readBounded(path.join(liveRoot, entry.path), LIMITS.fullFileBytes);
    if (raw.length !== entry.bytes || codec.sha256(raw) !== entry.sha256) throw Error('Live source drift before copy; partial snapshot retained');
    const filename = path.join(destination, entry.path);
    fs.mkdirSync(path.dirname(filename), {recursive:true}); fs.writeFileSync(filename, raw, {flag:'wx'});
  }
  if (codec.canonical(before) !== codec.canonical(observe(liveRoot))) throw Error('Live source drift during capture; partial snapshot retained');
  if (codec.canonical(contracts) !== codec.canonical(contractInventory())) throw Error('Contract drift during capture');
  if (codec.canonical(before) !== codec.canonical(fullInventory(destination))) throw Error('Snapshot copy mismatch');
  return {schema_version:1,kind:'professional_domain_source_capture_v1',source_root:liveRoot,
    live_closure:before,full_inventory:before,contracts,full_inventory_sha256:codec.digest(before),contracts_sha256:codec.digest(contracts)};
}
module.exports = {localPath,observe,freeze};
