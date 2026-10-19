'use strict';

// Independent application output auditor. No compiler or compiler input/projection
// helper is imported. A build audit cannot supply human reviewer acceptance.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {sourceModel} = require('./source-model.cjs');
const {SCHEMA_VERSION, POLICY_VERSION: POLICY, CONTEXT_BOUNDARY: BOUNDARY,
  INDEX_KIND, MODULE_KIND, RELEASE_KIND, TRUST_STATUS, DECISIONS, LIMITS, codec,
  assertAncestors, assertEmptyDecisions, contractInventory} = require('./contract.cjs');
const gates = require('./release-gates.cjs');
const {sha256, digest, encode, canonical, strictParse, exactKeys, readBounded} = codec;

const compare = (left, right) => left < right ? -1 : left > right ? 1 : 0;
const same = (actual, expected, label) => {
  if (canonical(actual) !== canonical(expected)) throw Error(label + ' mismatch');
};
// The independent walk also binds support assets outside the smaller strict
// source-JSON inventory; only its resource ceilings are shared with the compiler.
const FULL_LIMITS = Object.freeze({
  files: LIMITS.fullFiles, entries: LIMITS.fullEntries, depth: LIMITS.fullDepth,
  file: LIMITS.fullFileBytes, total: LIMITS.fullBytes
});

function directoryWithoutLinks(filename) {
  const absolute = path.resolve(filename);
  let cursor = path.parse(absolute).root;
  for (const segment of absolute.slice(cursor.length).split(path.sep).filter(Boolean)) {
    cursor = path.join(cursor, segment);
    const stat = fs.lstatSync(cursor);
    if (!stat.isDirectory() || stat.isSymbolicLink()) {
      throw Error('Auditor requires non-symlink directory ancestry: ' + cursor);
    }
  }
  const stat = fs.lstatSync(absolute);
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw Error('Invalid audit root');
  return absolute;
}

function fileIdentity(stat, includeChangeTime = true) {
  // Windows may refresh path ctime on the first read-open. Match exact inode,
  // size and modification time before opening, then anchor ctime at that fd.
  // BigInt identity avoids rounding this volume's inodes beyond 2^53.
  return [stat.dev, stat.ino, stat.size, stat.mtimeNs, ...(includeChangeTime ? [stat.ctimeNs] : [])].join(':');
}

function guardedFile(root, relative, maximum) {
  const filename = path.join(root, relative);
  assertAncestors(filename);
  const before = fs.lstatSync(filename, {bigint: true});
  if (!before.isFile() || before.isSymbolicLink() || before.size > BigInt(maximum)) {
    throw Error('Auditor file type/byte budget exceeded: ' + relative);
  }
  const handle = fs.openSync(filename, 'r');
  try {
    const opened = fs.fstatSync(handle, {bigint: true});
    if (!opened.isFile() || fileIdentity(opened, false) !== fileIdentity(before, false)) {
      throw Error('Auditor file changed before hashing: ' + relative);
    }
    const hash = crypto.createHash('sha256');
    const chunk = Buffer.alloc(64 * 1024);
    let total = 0;
    for (;;) {
      const count = fs.readSync(handle, chunk, 0, chunk.length, null);
      if (!count) break;
      total += count;
      if (total > maximum || total > Number(opened.size)) throw Error('Auditor file grew during hashing');
      hash.update(chunk.subarray(0, count));
    }
    const after = fs.lstatSync(filename, {bigint: true});
    if (total !== Number(opened.size) || !after.isFile() || after.isSymbolicLink() ||
        fileIdentity(fs.fstatSync(handle, {bigint: true})) !== fileIdentity(opened) ||
        fileIdentity(after) !== fileIdentity(opened)) {
      throw Error('Auditor file changed during hashing: ' + relative);
    }
    return {path: relative, bytes: total, sha256: hash.digest('hex')};
  } finally {
    fs.closeSync(handle);
  }
}

function fullInventory(root, directories = []) {
  root = directoryWithoutLinks(root);
  const inventory = [];
  let entries = 0, bytes = 0;
  const walk = (relative, depth) => {
    if (depth > FULL_LIMITS.depth) throw Error('Auditor full snapshot depth budget exceeded');
    const directory = path.join(root, relative);
    const stat = fs.lstatSync(directory);
    if (!stat.isDirectory() || stat.isSymbolicLink()) throw Error('Auditor full snapshot directory type');
    if (relative) directories.push(relative);
    const handle = fs.opendirSync(directory);
    try {
      for (let item; (item = handle.readSync()) !== null;) {
        if (++entries > FULL_LIMITS.entries) throw Error('Auditor full snapshot entry budget exceeded');
        if (!/^[A-Za-z0-9_.-]+$/.test(item.name) || item.name === '.' || item.name === '..') {
          throw Error('Auditor unsafe snapshot entry name');
        }
        const name = relative ? relative + '/' + item.name : item.name;
        if (item.isSymbolicLink()) throw Error('Auditor full snapshot symlink rejected: ' + name);
        if (item.isDirectory()) walk(name, depth + 1);
        else if (item.isFile()) {
          if (inventory.length >= FULL_LIMITS.files) throw Error('Auditor full snapshot file budget exceeded');
          const record = guardedFile(root, name, FULL_LIMITS.file);
          bytes += record.bytes;
          if (bytes > FULL_LIMITS.total) throw Error('Auditor full snapshot byte budget exceeded');
          inventory.push(record);
        } else throw Error('Auditor unexpected full snapshot entry: ' + name);
      }
    } finally {
      handle.closeSync();
    }
  };
  walk('', 0);
  inventory.sort((left, right) => compare(left.path, right.path));
  directories.sort(compare);
  return inventory;
}

function packageInventory(root) {
  root = directoryWithoutLinks(root);
  const result = [];
  const directories = [];
  const top = fs.opendirSync(root);
  let rootEntries = 0;
  try {
    for (let entry; (entry = top.readSync()) !== null;) {
      if (++rootEntries > 5) throw Error('Unexpected package root inventory');
      if (entry.isSymbolicLink()) throw Error('Package symlink rejected');
      const rootLimits = {'release.json': LIMITS.descriptor, 'index.json': LIMITS.index, 'themes.json': LIMITS.themes};
      if (Object.hasOwn(rootLimits, entry.name) && entry.isFile()) {
        result.push(guardedFile(root, entry.name, rootLimits[entry.name]));
      } else if (['modules', 'media-manifests'].includes(entry.name) && entry.isDirectory()) {
        const group = entry.name;
        directories.push(group);
        const directory = path.join(root, group);
        const stat = fs.lstatSync(directory);
        if (!stat.isDirectory() || stat.isSymbolicLink()) throw Error('Package modules directory type');
        const files = fs.opendirSync(directory);
        let moduleEntries = 0;
        try {
          for (let file; (file = files.readSync()) !== null;) {
            if (++moduleEntries > codec.LIMITS.modules) throw Error('Package module count budget exceeded');
            if (!file.isFile() || file.isSymbolicLink() || !/^[a-f0-9]{64}\.json$/.test(file.name)) {
              throw Error('Unexpected package module inventory');
            }
            result.push(guardedFile(root, group + '/' + file.name, group === 'modules' ? LIMITS.payload : LIMITS.manifest));
          }
        } finally {
          files.closeSync();
        }
        if (!moduleEntries) throw Error('Empty package artifact directory rejected');
      } else throw Error('Unexpected package artifact: ' + entry.name);
    }
  } finally {
    top.closeSync();
  }
  result.sort((left, right) => compare(left.path, right.path));
  directories.sort(compare);
  return {files: result, directories};
}

function canonicalJson(raw, label) {
  const value = strictParse(raw);
  if (!encode(value).equals(raw)) throw Error(label + ' is not canonical JSON');
  return value;
}

function validateOptions(options) {
  if (!options || Object.getPrototypeOf(options) !== Object.prototype ||
      Object.keys(options).some(key => key !== 'checkpoint') ||
      (options.checkpoint !== undefined && typeof options.checkpoint !== 'function')) {
    throw Error('Unsupported auditor options');
  }
  // Mutation tests may observe a phase and change on-disk bytes. They
  // cannot supply or bypass an inventory, source record, audit result, or pin.
  return stage => {
    const result = options.checkpoint && options.checkpoint(stage);
    if (result && typeof result.then === 'function') throw Error('Auditor checkpoints must be synchronous');
  };
}

function audit(sourceRoot, packageRoot, options = {}) {
  const checkpoint = validateOptions(options);
  sourceRoot = directoryWithoutLinks(sourceRoot);
  packageRoot = directoryWithoutLinks(packageRoot);
  const sourceIdentity = process.platform === 'win32' ? sourceRoot.toLowerCase() : sourceRoot;
  const packageIdentity = process.platform === 'win32' ? packageRoot.toLowerCase() : packageRoot;
  if (sourceIdentity === packageIdentity || packageIdentity.startsWith(sourceIdentity + path.sep) ||
      sourceIdentity.startsWith(packageIdentity + path.sep)) {
    throw Error('Source snapshot and output package must be separate roots');
  }

  const sourceDirectoriesBefore = [];
  const fullBefore = fullInventory(sourceRoot, sourceDirectoriesBefore);
  const contractsBefore = contractInventory();
  const artifactsBefore = packageInventory(packageRoot);
  const model = sourceModel(sourceRoot);
  if (model.courses.length !== 20 || model.modules.size !== 200) {
    throw Error('Initial compiled release must preserve the complete 20-course/200-module source graph');
  }
  const fullByPath = new Map(fullBefore.map(record => [record.path, record]));
  for (const record of model.inventory) {
    same(record, fullByPath.get(record.path), 'Governed source/full snapshot inventory');
  }
  const sourcePaths = new Set(model.inventory.map(record => record.path));
  const supportingInventory = fullBefore.filter(record => !sourcePaths.has(record.path));
  assertEmptyDecisions(strictParse(model.blobs.get(DECISIONS)));
  if (model.decisions.size || model.scopes.size) throw Error('Compiled release cannot contain decisions or exceptions');
  checkpoint('source_model_reconstructed');

  // This invokes the unchanged production audit on the copied sources/support.
  // Its independent before/after inventory must agree with our own full walk.
  const gateResult = gates.inspect(sourceRoot);
  if (gateResult.professionalAudit?.ok !== true || !Array.isArray(gateResult.professionalAudit.errors) ||
      gateResult.professionalAudit.errors.length || !Array.isArray(gateResult.professionalAudit.warnings)) {
    throw Error('Unchanged professional audit did not pass');
  }
  same(gateResult.fullInventory, fullBefore, 'Production gate/full snapshot inventory');
  same(gateResult.directories, ['', ...sourceDirectoriesBefore].sort(compare), 'Production gate/full directory inventory');
  same(gateResult.sourceInventory, model.inventory, 'Production gate/independent source inventory');
  same(gateResult.supportingInventory, supportingInventory, 'Production gate/independent support inventory');
  const sourceHash = digest(model.inventory);
  const supportingHash = digest(supportingInventory);
  const fullHash = digest(fullBefore);
  const contractsHash = digest(contractsBefore);
  same(gateResult.sourceInventorySha256, sourceHash, 'Production gate/source inventory hash');
  same(gateResult.supportingInventorySha256, supportingHash, 'Production gate/support inventory hash');
  same(gateResult.contractsSha256, contractsHash, 'Production gate/tool contract hash');

  const releaseRaw = readBounded(path.join(packageRoot, 'release.json'), LIMITS.descriptor);
  const release = canonicalJson(releaseRaw, 'Application release descriptor');
  exactKeys(release, ['schema_version', 'kind', 'policy_version', 'context_boundary', 'trust_status',
    'source_inventory_sha256', 'supporting_inventory_sha256', 'contracts_sha256',
    'index', 'themes', 'artifacts'], 'application release descriptor');
  const releaseDescriptor = {path: 'release.json', bytes: releaseRaw.length, sha256: sha256(releaseRaw)};
  const indexRaw = readBounded(path.join(packageRoot, 'index.json'), LIMITS.index);
  if (!indexRaw.length) throw Error('Empty release index');
  const index = canonicalJson(indexRaw, 'Release index');
  exactKeys(index, ['schema_version', 'kind', 'policy_version', 'context_boundary', 'trust_status',
    'source_inventory_sha256', 'supporting_inventory_sha256', 'contracts_sha256', 'modules'], 'compiled release index');
  if (!Array.isArray(index.modules) || index.modules.length > codec.LIMITS.modules) {
    throw Error('Release index module count budget exceeded');
  }
  const identities = [...model.modules.keys()].sort(compare);
  same(index.modules.map(entry => entry.course_id + '/' + entry.module_id), identities,
    'Complete ordered course/module index');

  const indexDescriptor = {path: 'index.json', bytes: indexRaw.length, sha256: sha256(indexRaw)};
  const expectedEntries = [], artifactMap = new Map();
  const addArtifact = record => {
    if (artifactMap.has(record.path)) same(record, artifactMap.get(record.path), 'Shared artifact descriptor');
    else artifactMap.set(record.path, record);
  };
  addArtifact(indexDescriptor);
  const supportingRaw = (resource, maximum, label) => {
    if (typeof resource !== 'string' ||
        !/^res:\/\/(?:[A-Za-z0-9_-][A-Za-z0-9_.-]*\/)*[A-Za-z0-9_-][A-Za-z0-9_.-]*$/.test(resource)) {
      throw Error('Unsafe ' + label + ' source path');
    }
    const relative = resource.slice(6), filename = path.join(sourceRoot, relative);
    assertAncestors(filename);
    const raw = readBounded(filename, maximum);
    same({path: relative, bytes: raw.length, sha256: sha256(raw)}, fullByPath.get(relative), label + ' source inventory binding');
    return raw;
  };
  // Themes and manifests may contain fractional motion values. Their original
  // raw bytes are authoritative, and the unchanged production audit checks semantics.
  const sourceThemesRaw = supportingRaw(model.catalog.themes, LIMITS.themes, 'Themes');
  const themesRaw = readBounded(path.join(packageRoot, 'themes.json'), LIMITS.themes);
  if (!themesRaw.length || !themesRaw.equals(sourceThemesRaw)) throw Error('Exact source themes copy mismatch');
  const themesDescriptor = {path: 'themes.json', bytes: themesRaw.length, sha256: sha256(themesRaw)};
  addArtifact(themesDescriptor);
  const closures = [];
  let readyCount = 0, lexicalRows = 0, expressionRows = 0;
  const domainRows = (ids, edges, registry, kind) => [...ids].sort(compare).map(id => {
    const memberships = edges.get(id);
    if (!Array.isArray(memberships) || !memberships.length) throw Error('Missing global ' + kind + ' membership');
    const coarse = memberships.some(edge => {
      const context = model.modules.get(edge.course_id + '/' + edge.module_id);
      if (!context) throw Error('Missing global domain context');
      return context.domainRequired;
    });
    const review = registry.get(id).review;
    if (!review || review.status !== 'reviewed' || review.language !== 'reviewed' ||
        !['not_required', 'reviewed'].includes(review.domain) || coarse && review.domain !== 'reviewed') {
      throw Error('Ready ' + kind + ' has incomplete original review: ' + id);
    }
    return {id, coarse_required: coarse, exception: null};
  });

  for (let position = 0; position < identities.length; position++) {
    const context = model.modules.get(identities[position]);
    const entry = index.modules[position];
    const expectedEntry = {
      course_id: context.course.id, module_id: context.module.id,
      state: context.module.status === 'ready' ? 'ready' : 'unavailable', source_status: context.module.status
    };
    if (context.module.status !== 'ready') {
      exactKeys(entry, ['course_id', 'module_id', 'state', 'source_status'], 'unavailable module');
      same(entry, expectedEntry, 'Unavailable module status');
      expectedEntries.push(expectedEntry);
      continue;
    }
    exactKeys(entry, ['course_id', 'module_id', 'state', 'source_status', 'payload', 'media_manifest'], 'ready module');
    exactKeys(entry.payload, ['path', 'bytes', 'sha256'], 'module payload descriptor');
    const descriptor = entry.payload;
    if (typeof descriptor.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(descriptor.sha256) ||
        descriptor.path !== 'modules/' + descriptor.sha256 + '.json' ||
        !Number.isSafeInteger(descriptor.bytes) || descriptor.bytes < 1 || descriptor.bytes > LIMITS.payload) {
      throw Error('Invalid ready module descriptor');
    }
    if (context.module.lexeme_ids.length !== 50 || context.module.expression_ids.length !== 10) {
      throw Error('Ready module must retain exact 50/10 selected inventory');
    }
    const raw = readBounded(path.join(packageRoot, descriptor.path), LIMITS.payload);
    if (raw.length !== descriptor.bytes || sha256(raw) !== descriptor.sha256) {
      throw Error('Module payload digest/length mismatch');
    }
    const payload = canonicalJson(raw, 'Module payload');
    const expectedPayload = {
      schema_version: SCHEMA_VERSION, kind: MODULE_KIND, policy_version: POLICY,
      context_boundary: BOUNDARY, course_id: context.course.id, module_id: context.module.id,
      course: context.course,
      lexemes: context.module.lexeme_ids.map(id => model.lexemes.get(id)),
      expressions: context.module.expression_ids.map(id => model.expressions.get(id)),
      lexical_domain: domainRows(context.module.lexeme_ids, model.lexicalEdges, model.lexemes, 'lexical record'),
      expression_domain: domainRows(context.module.expression_ids, model.expressionEdges, model.expressions, 'expression record')
    };
    same(payload, expectedPayload, 'Independently reconstructed complete selected payload');
    const expectedRaw = encode(expectedPayload);
    if (!raw.equals(expectedRaw)) throw Error('Independent payload canonical bytes mismatch');
    expectedEntry.payload = {path: 'modules/' + sha256(expectedRaw) + '.json', bytes: expectedRaw.length, sha256: sha256(expectedRaw)};
    exactKeys(entry.media_manifest, ['path', 'bytes', 'sha256', 'source_path'], 'ready media manifest descriptor');
    const sourceManifest = context.module.media_manifest;
    if (!sourceManifest || typeof sourceManifest.path !== 'string' ||
        !/^res:\/\/data\/professional\/media-manifests\/[a-zA-Z0-9_.-]+\.json$/.test(sourceManifest.path) ||
        typeof sourceManifest.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(sourceManifest.sha256)) {
      throw Error('Invalid ready source media manifest');
    }
    const sourceMediaRaw = supportingRaw(sourceManifest.path, LIMITS.manifest, 'Selected media manifest');
    const mediaHash = sha256(sourceMediaRaw);
    if (mediaHash !== sourceManifest.sha256) throw Error('Selected source media manifest hash mismatch');
    const mediaDescriptor = {path: 'media-manifests/' + mediaHash + '.json', bytes: sourceMediaRaw.length, sha256: mediaHash};
    const mediaRaw = readBounded(path.join(packageRoot, mediaDescriptor.path), LIMITS.manifest);
    if (!mediaRaw.length || !mediaRaw.equals(sourceMediaRaw)) throw Error('Exact selected media manifest copy mismatch');
    expectedEntry.media_manifest = {...mediaDescriptor, source_path: sourceManifest.path};
    same(entry, expectedEntry, 'Ready module index descriptor');
    expectedEntries.push(expectedEntry);
    addArtifact(expectedEntry.payload);
    addArtifact(mediaDescriptor);
    readyCount++;
    lexicalRows += expectedPayload.lexical_domain.length;
    expressionRows += expectedPayload.expression_domain.length;
    const closure = {
      course_id: context.course.id, module_id: context.module.id,
      descriptor_bytes: releaseRaw.length, index_bytes: indexRaw.length, themes_bytes: themesRaw.length,
      payload_bytes: raw.length, media_manifest_bytes: mediaRaw.length,
      cold_opens: 5,
      cold_encoded_bytes: releaseRaw.length + indexRaw.length + themesRaw.length + raw.length + mediaRaw.length
    };
    if (closure.cold_opens > LIMITS.coldOpens || closure.cold_encoded_bytes > LIMITS.coldBytes) {
      throw Error('Compiled policy closure budget exceeded');
    }
    closures.push(closure);
  }

  const expectedIndex = {
    schema_version: SCHEMA_VERSION, kind: INDEX_KIND, policy_version: POLICY,
    context_boundary: BOUNDARY, trust_status: TRUST_STATUS,
    source_inventory_sha256: sourceHash, supporting_inventory_sha256: supportingHash,
    contracts_sha256: contractsHash, modules: expectedEntries
  };
  same(index, expectedIndex, 'Independently reconstructed complete release index');
  const releaseArtifacts = [...artifactMap.values()].sort((left, right) => compare(left.path, right.path));
  const expectedRelease = {
    schema_version: SCHEMA_VERSION, kind: RELEASE_KIND, policy_version: POLICY,
    context_boundary: BOUNDARY, trust_status: TRUST_STATUS,
    source_inventory_sha256: sourceHash, supporting_inventory_sha256: supportingHash,
    contracts_sha256: contractsHash, index: indexDescriptor, themes: themesDescriptor,
    artifacts: releaseArtifacts
  };
  same(release, expectedRelease, 'Independently reconstructed application descriptor');
  if (!releaseRaw.equals(encode(expectedRelease))) throw Error('Independent application descriptor canonical bytes mismatch');
  addArtifact(releaseDescriptor);
  const expectedArtifacts = [...artifactMap.values()].sort((left, right) => compare(left.path, right.path));
  const expectedDirectories = readyCount ? ['media-manifests', 'modules'] : [];
  same(artifactsBefore.files, expectedArtifacts, 'Both-direction initial package artifact inventory');
  same(artifactsBefore.directories, expectedDirectories, 'Exact initial package directory inventory');
  checkpoint('output_reconstructed');
  const sourceDirectoriesAfter = [];
  same(fullInventory(sourceRoot, sourceDirectoriesAfter), fullBefore, 'Full source snapshot changed during audit');
  same(sourceDirectoriesAfter, sourceDirectoriesBefore, 'Source directory inventory changed during audit');
  same(contractInventory(), contractsBefore, 'Tool contracts changed during audit');
  same(packageInventory(packageRoot), {files: expectedArtifacts, directories: expectedDirectories},
    'Package artifact/directory inventory changed during audit');
  closures.sort((left, right) => right.cold_encoded_bytes - left.cold_encoded_bytes ||
    compare(left.course_id + '/' + left.module_id, right.course_id + '/' + right.module_id));

  return {
    schema_version: SCHEMA_VERSION, status: 'passed_independent_compiled_release_audit',
    trust_status: TRUST_STATUS, descriptor: releaseDescriptor, index_sha256: sha256(indexRaw),
    source_inventory_sha256: sourceHash, supporting_inventory_sha256: supportingHash,
    full_snapshot_sha256: fullHash, contracts_sha256: contractsHash,
    source_files: model.inventory.length, full_snapshot_files: fullBefore.length,
    full_snapshot_bytes: fullBefore.reduce((sum, record) => sum + record.bytes, 0),
    courses: model.courses.length, modules: model.modules.size,
    ready_modules: readyCount, unavailable_modules: model.modules.size - readyCount,
    lexemes: model.lexemes.size, expressions: model.expressions.size,
    pending_decisions: 0, real_acceptances_null: 0, all_real_acceptances_null: true, accepted_ids: [],
    lexical_domain_rows: lexicalRows, expression_domain_rows: expressionRows,
    lexical_exceptions: 0, expression_exceptions: 0,
    artifact_files: expectedArtifacts.length,
    artifact_bytes: expectedArtifacts.reduce((sum, record) => sum + record.bytes, 0),
    artifact_inventory: expectedArtifacts, contracts: contractsBefore,
    source_inventory: model.inventory, supporting_inventory: supportingInventory,
    both_direction_source_inventory: true, both_direction_output_inventory: true,
    full_source_before_after_equal: true, source_directories_before_after_equal: true,
    exact_package_directory_inventory: true, tool_contracts_before_after_equal: true,
    independent_complete_payload_reconstruction: true, global_coarse_flags_recomputed: true,
    exact_source_themes_copy: true, exact_selected_media_manifest_copies: true,
    production_audit_summary: gateResult.professionalAudit.summary,
    production_audit_warning_count: gateResult.professionalAudit.warnings.length,
    build_audit_is_not_reviewer_acceptance: true,
    maximum_cold: closures[0] || null, closures, closure_includes_app_descriptor: true,
    closure_includes_themes_and_media_manifest: true,
    trust_anchor: null, runtime_implementation: false, runtime_timing: null, runtime_heap: null
  };
}

// The read-only helper export is used by deterministic filesystem
// probes. It cannot replace source models, gate results, or audit authority.
module.exports = {audit, guardedFileForTest: guardedFile};
