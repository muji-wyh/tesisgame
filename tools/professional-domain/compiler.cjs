'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {codec,LIMITS,SCHEMA_VERSION,POLICY_VERSION,CONTEXT_BOUNDARY,INDEX_KIND,MODULE_KIND,RELEASE_KIND,TRUST_STATUS,
  assertAncestors,contractInventory,disjoint} = require('./contract.cjs');
const inputs = require('./inputs.cjs');
const gates = require('./release-gates.cjs');
const {localPath} = require('./snapshot.cjs');
const DOMAIN_COURSES = new Set(['caregiving','food_service','nursing','customer_support','office_admin','warehouse_logistics','hospitality_tourism',
  'transport_delivery','construction_trades','cleaning_facilities','education_childcare','manufacturing_maintenance','it_support','accounting_finance',
  'sales_marketing','hr_recruitment','clinical_medicine','legal_paralegal']);

function compile(sourceRoot, outputRoot, options = {}) {
  if (!options || Object.getPrototypeOf(options) !== Object.prototype || Object.keys(options).some(key => key !== 'checkpoint') ||
      options.checkpoint !== undefined && typeof options.checkpoint !== 'function') throw Error('Unsupported compiler options');
  sourceRoot = path.resolve(sourceRoot); outputRoot = path.resolve(outputRoot);
  if (fs.existsSync(outputRoot)) throw Error('Compiler output exists; refusing overwrite');
  disjoint(sourceRoot, outputRoot); assertAncestors(path.dirname(outputRoot));
  const contracts = contractInventory(), inspection = gates.inspect(sourceRoot), model = inputs.load(sourceRoot);
  if (options.checkpoint) options.checkpoint('after-source-load');
  const coarse = {lexemes:new Set(), expressions:new Set()};
  for (const course of model.courses) for (const module of course.modules) {
    if (module.id === 'module08' || DOMAIN_COURSES.has(course.id) && !module.foundation) {
      module.lexeme_ids.forEach(id => coarse.lexemes.add(id)); module.expression_ids.forEach(id => coarse.expressions.add(id));
    }
  }
  fs.mkdirSync(outputRoot);
  const modules = [], artifacts = new Map();
  const write = (relative, raw, maximum) => {
    if (raw.length < 1 || raw.length > maximum) throw Error('Compiled artifact byte budget exceeded: ' + relative);
    const descriptor = {path:relative,bytes:raw.length,sha256:codec.sha256(raw)};
    if (artifacts.has(relative)) {
      if (codec.canonical(artifacts.get(relative)) !== codec.canonical(descriptor)) throw Error('Conflicting generated content identity');
      return descriptor;
    }
    const filename = path.join(outputRoot, relative);
    fs.mkdirSync(path.dirname(filename), {recursive:true}); fs.writeFileSync(filename, raw, {flag:'wx'});
    artifacts.set(relative, descriptor); return descriptor;
  };
  const themeRaw = codec.readBounded(path.join(sourceRoot, localPath(model.catalog.themes)), LIMITS.themes);
  const themes = write('themes.json', themeRaw, LIMITS.themes);
  for (const course of [...model.courses].sort((a,b) => a.id < b.id ? -1 : 1)) for (const module of [...course.modules].sort((a,b) => a.id < b.id ? -1 : 1)) {
    const row = {course_id:course.id,module_id:module.id,state:module.status === 'ready' ? 'ready' : 'unavailable',source_status:module.status};
    if (row.state === 'ready') {
      if (module.lexeme_ids.length !== 50 || module.expression_ids.length !== 10) throw Error('Ready module selection requires 50 terms and 10 expressions');
      const payload = {schema_version:SCHEMA_VERSION,kind:MODULE_KIND,policy_version:POLICY_VERSION,context_boundary:CONTEXT_BOUNDARY,
        course_id:course.id,module_id:module.id,course,lexemes:module.lexeme_ids.map(id => model.maps.lexemes.get(id)),
        expressions:module.expression_ids.map(id => model.maps.expressions.get(id)),
        lexical_domain:[...module.lexeme_ids].sort().map(id => ({id,coarse_required:coarse.lexemes.has(id),exception:null})),
        expression_domain:[...module.expression_ids].sort().map(id => ({id,coarse_required:coarse.expressions.has(id),exception:null}))};
      const raw = codec.encode(payload);
      row.payload = write('modules/' + codec.sha256(raw) + '.json', raw, LIMITS.payload);
      const sourcePath = module.media_manifest.path;
      const mediaRaw = codec.readBounded(path.join(sourceRoot, localPath(sourcePath)), LIMITS.manifest);
      const mediaHash = codec.sha256(mediaRaw);
      if (mediaHash !== module.media_manifest.sha256) throw Error('Selected media manifest changed after source audit');
      row.media_manifest = {...write('media-manifests/' + mediaHash + '.json', mediaRaw, LIMITS.manifest),source_path:sourcePath};
    }
    modules.push(row);
  }
  const binding = {source_inventory_sha256:inspection.sourceInventorySha256,supporting_inventory_sha256:inspection.supportingInventorySha256,
    contracts_sha256:inspection.contractsSha256};
  const index = {schema_version:SCHEMA_VERSION,kind:INDEX_KIND,policy_version:POLICY_VERSION,context_boundary:CONTEXT_BOUNDARY,
    trust_status:TRUST_STATUS,...binding,modules};
  const indexDescriptor = write('index.json', codec.encode(index), LIMITS.index);
  const release = {schema_version:SCHEMA_VERSION,kind:RELEASE_KIND,policy_version:POLICY_VERSION,context_boundary:CONTEXT_BOUNDARY,
    trust_status:TRUST_STATUS,...binding,index:indexDescriptor,themes,
    artifacts:[...artifacts.values()].sort((a,b) => a.path < b.path ? -1 : 1)};
  const descriptor = write('release.json', codec.encode(release), LIMITS.descriptor);
  for (const row of modules) if (row.state === 'ready') {
    const closure = [descriptor,indexDescriptor,themes,row.payload,row.media_manifest];
    if (closure.length > LIMITS.coldOpens || closure.reduce((sum,item) => sum + item.bytes, 0) > LIMITS.coldBytes) throw Error('Compiled policy closure exceeds budget');
  }
  if (options.checkpoint) options.checkpoint('before-final-guards');
  gates.assertStable(sourceRoot, inspection.fullInventory, inspection.directories);
  if (codec.canonical(contracts) !== codec.canonical(contractInventory())) throw Error('Compiler contract drift');
  const inventory = [...artifacts.values()].sort((a,b) => a.path < b.path ? -1 : 1);
  if (codec.canonical(gates.fullInventory(outputRoot)) !== codec.canonical(inventory)) throw Error('Compiler output changed before final guard');
  return {schema_version:1,kind:'professional_domain_compile_report_v1',...binding,descriptor,
    modules:modules.length,ready_modules:modules.filter(row => row.state === 'ready').length,
    unavailable_modules:modules.filter(row => row.state === 'unavailable').length,artifacts:inventory,
    professional_summary:inspection.professionalAudit.summary,build_audit_is_not_reviewer_acceptance:true};
}
module.exports = {compile};
