'use strict';

// Independent source reconstruction. No compiler, input loader, or projection
// implementation is imported; only the bounded byte/schema contract is shared.
const fs = require('node:fs');
const path = require('node:path');
const {codec, DECISIONS, assertAncestors, assertEmptyDecisions} = require('./contract.cjs');
const {LIMITS, canonical, strictParse, readBounded, sha256} = codec;
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const same = (actual, expected, label) => {
  if (canonical(actual) !== canonical(expected)) throw Error(label + ' mismatch');
};

function scan(root, relative, output, traversal, depth = 0) {
  if (depth > LIMITS.traversalDepth) throw Error('Auditor source directory depth budget exceeded');
  const filename = path.join(root, relative);
  assertAncestors(filename);
  const stat = fs.lstatSync(filename);
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw Error('Auditor source directory type rejected');
  const handle = fs.opendirSync(filename);
  try {
    for (let entry; (entry = handle.readSync()) !== null;) {
      if (++traversal.entries > LIMITS.traversalEntries) throw Error('Auditor source entry budget exceeded');
      if (!/^[A-Za-z0-9_.-]+$/.test(entry.name) || entry.isSymbolicLink()) throw Error('Auditor unsafe source entry');
      const relativeFile = relative + '/' + entry.name;
      if (entry.isDirectory()) scan(root, relativeFile, output, traversal, depth + 1);
      else if (entry.isFile()) output.push(relativeFile);
      else throw Error('Auditor unexpected source entry');
      if (output.length > LIMITS.files) throw Error('Auditor source file budget exceeded');
    }
  } finally {
    handle.closeSync();
  }
}

function sourceModel(root) {
  root = path.resolve(root);
  assertAncestors(root);
  if (!fs.lstatSync(root).isDirectory()) throw Error('Auditor source root must be a directory');
  const observed = ['data/professional/catalog.json', 'data/professional/sources.json'];
  const traversal = {entries: 0};
  for (const group of ['courses', 'lexemes', 'expressions']) {
    scan(root, 'data/professional/' + group, observed, traversal);
  }
  observed.sort(compare);
  if (observed.length + 1 > LIMITS.files) throw Error('Auditor source file count budget exceeded');
  let aggregate = 0;
  const blobs = new Map(), parsed = new Map(), inventory = [];
  for (const relative of [...observed, DECISIONS].sort(compare)) {
    const filename = path.join(root, relative);
    assertAncestors(filename);
    const maximum = relative === DECISIONS ? LIMITS.decisionManifest : LIMITS.file;
    const raw = readBounded(filename, maximum);
    aggregate += raw.length;
    if (aggregate > LIMITS.inputTotal) throw Error('Auditor aggregate source byte budget exceeded');
    blobs.set(relative, raw);
    parsed.set(relative, strictParse(raw));
    inventory.push({path: relative, bytes: raw.length, sha256: sha256(raw)});
  }
  const catalog = parsed.get('data/professional/catalog.json');
  if (catalog.sources !== 'res://data/professional/sources.json') throw Error('Unexpected registry source path');
  const declared = new Set(['data/professional/catalog.json', 'data/professional/sources.json']);
  const resolve = (resource, kind) => {
    if (typeof resource !== 'string' ||
        !new RegExp('^res://data/professional/' + kind + '/[a-z0-9_.-]+\\.json$').test(resource)) {
      throw Error('Invalid declared source resource');
    }
    const relative = resource.slice(6);
    if (declared.has(relative) || !parsed.has(relative)) throw Error('Duplicate or missing declared source');
    declared.add(relative);
    return parsed.get(relative);
  };
  const index = (records, label, maximum) => {
    if (!Array.isArray(records) || records.length > maximum) throw Error(label + ' count budget exceeded');
    const result = new Map();
    for (const item of records) {
      if (!item || typeof item.id !== 'string' || !/^[a-z][a-z0-9_.-]*$/.test(item.id) || result.has(item.id)) {
        throw Error('Invalid or duplicate ' + label + ' identity');
      }
      result.set(item.id, item);
    }
    return result;
  };
  const catalogCourses = index(catalog.courses, 'catalog course', LIMITS.courses);
  const courses = [];
  for (const item of catalog.courses) {
    const course = resolve(item.manifest, 'courses');
    if (course.id !== item.id) throw Error('Catalog course identity differs');
    courses.push(course);
  }
  index(courses, 'course', LIMITS.courses);
  const owners = {lexemes: new Map(), expressions: new Map()};
  const registries = {};
  for (const [kind, key, maximum] of [
    ['lexemes', 'lexeme_files', LIMITS.lexemes],
    ['expressions', 'expression_files', LIMITS.expressions]
  ]) {
    if (!Array.isArray(catalog[key]) || catalog[key].length > LIMITS.files) throw Error('Registry file count budget exceeded');
    const records = [];
    for (const file of catalog[key]) {
      const content = resolve(file, kind);
      if (!Array.isArray(content[kind])) throw Error('Missing registry records');
      for (const record of content[kind]) {
        if (!record || owners[kind].has(record.id)) throw Error('Duplicate or invalid canonical record');
        records.push(record);
        owners[kind].set(record.id, file);
      }
      if (records.length > maximum) throw Error('Registry record count budget exceeded');
    }
    registries[kind] = index(records, kind, maximum);
  }
  same([...declared].sort(compare), observed, 'Both-direction source inventory');
  const sources = index(parsed.get('data/professional/sources.json').sources, 'source', LIMITS.sources);
  const modules = new Map(), lexicalEdges = new Map(), expressionEdges = new Map();
  const domainNames = new Set([
    'accounting_finance', 'caregiving', 'cleaning_facilities', 'clinical_medicine',
    'construction_trades', 'customer_support', 'education_childcare', 'food_service',
    'hospitality_tourism', 'hr_recruitment', 'it_support', 'legal_paralegal',
    'manufacturing_maintenance', 'nursing', 'office_admin', 'sales_marketing',
    'transport_delivery', 'warehouse_logistics'
  ]);
  for (const course of courses) {
    if (!domainNames.has(course.id) && course.id !== 'retail' && course.id !== 'software_data') {
      throw Error('Unsupported course domain policy');
    }
    index(course.modules, 'module', LIMITS.modulesPerCourse);
    for (const module of course.modules) {
      const key = course.id + '/' + module.id;
      if (modules.has(key) || modules.size >= LIMITS.modules) throw Error('Duplicate module or module count budget exceeded');
      if (typeof module.foundation !== 'boolean') throw Error('Module foundation must be boolean');
      const domainRequired = module.id === 'module08' || domainNames.has(course.id) && !module.foundation;
      modules.set(key, {course, module, catalogContext: catalogCourses.get(course.id), domainRequired});
      for (const [kind, idKey, fileKey, maximum, edges] of [
        ['lexemes', 'lexeme_ids', 'lexeme_files', LIMITS.selectedLexemes, lexicalEdges],
        ['expressions', 'expression_ids', 'expression_files', LIMITS.selectedExpressions, expressionEdges]
      ]) {
        const ids = module[idKey], files = module[fileKey];
        if (!Array.isArray(ids) || ids.length > maximum || new Set(ids).size !== ids.length ||
            !Array.isArray(files) || files.length > LIMITS.files || new Set(files).size !== files.length) {
          throw Error('Module membership count or duplicates');
        }
        for (const file of files) {
          if (!catalog[kind === 'lexemes' ? 'lexeme_files' : 'expression_files'].includes(file)) {
            throw Error('Undeclared module registry');
          }
        }
        for (const id of ids) {
          if (!registries[kind].has(id) || !files.includes(owners[kind].get(id))) {
            throw Error('Missing or out-of-resource membership');
          }
          const memberships = edges.get(id) || [];
          memberships.push({course_id: course.id, module_id: module.id});
          edges.set(id, memberships);
        }
      }
    }
  }
  for (const edges of [lexicalEdges, expressionEdges]) {
    for (const memberships of edges.values()) {
      memberships.sort((a, b) => compare(a.course_id + '/' + a.module_id, b.course_id + '/' + b.module_id));
    }
  }
  assertEmptyDecisions(parsed.get(DECISIONS));
  return {
    inventory, blobs, catalog, courses, modules,
    lexemes: registries.lexemes, expressions: registries.expressions, sources,
    lexicalEdges, expressionEdges, decisions: new Map(), scopes: new Map()
  };
}

module.exports = {sourceModel};
