'use strict';
const fs = require('node:fs'), path = require('node:path');
const {LIMITS, strictParse, sha256, encode, canonical, readBounded} = require('./codec.cjs');
const BASE = 'data/professional/';
const GOVERNED_DIRS = ['courses', 'lexemes', 'expressions'];
const resource = (name, group) => {
  const pattern = new RegExp('^res://data/professional/' + group + '/[a-z0-9_.-]+\\.json$');
  if (typeof name !== 'string' || !pattern.test(name)) throw Error('Invalid governed resource: ' + name);
  return name.slice(6);
};
function enumerate(root) {
  const files = [BASE + 'catalog.json', BASE + 'sources.json'];
  let observedEntries = 0;
  for (const dir of GOVERNED_DIRS) {
    const visit = (relative,depth = 0) => {
      if (depth > LIMITS.traversalDepth) throw Error('Governed directory depth budget exceeded');
      const directory = fs.lstatSync(path.join(root,relative));
      if (!directory.isDirectory() || directory.isSymbolicLink()) throw Error('Governed directory symlink/type rejected: ' + relative);
      const handle = fs.opendirSync(path.join(root,relative));
      try {
        let item;
        while ((item = handle.readSync()) !== null) {
          if (++observedEntries > LIMITS.traversalEntries) throw Error('Governed directory entry count budget exceeded');
          const name = relative + '/' + item.name;
          if (item.isSymbolicLink()) throw Error('Governed symlink rejected: ' + name);
          if (item.isDirectory()) visit(name,depth+1);
          else if (item.isFile()) { files.push(name); if (files.length > LIMITS.files) throw Error('Input file count budget exceeded'); }
          else throw Error('Unexpected governed filesystem entry');
        }
      } finally { handle.closeSync(); }
    };
    visit(BASE + dir);
  }
  if (files.length > LIMITS.files) throw Error('Input file count budget exceeded');
  return files.sort();
}
function read(root, relative,maximum = LIMITS.file) {
  return readBounded(path.join(root,relative),maximum);
}
function inventory(root) {
  let total = 0;
  return enumerate(root).map(relative => {
    const raw = read(root, relative); total += raw.length;
    if (total > LIMITS.inputTotal) throw Error('Input aggregate budget exceeded');
    strictParse(raw);
    return {path: relative, bytes: raw.length, sha256: sha256(raw)};
  });
}
function unique(items, label, limit) {
  if (!Array.isArray(items) || items.length > limit) throw Error('Invalid ' + label + ' count');
  const result = new Map();
  for (const item of items) {
    if (!item || typeof item.id !== 'string' || !/^[a-z][a-z0-9_.-]*$/.test(item.id) || result.has(item.id)) throw Error('Invalid or duplicate ' + label + ' ID');
    result.set(item.id, item);
  }
  return result;
}
function load(root) {
  const decisionPath = 'data/professional/domain-policy/decisions.json';
  const parsed = new Map(); let total = 0;
  const get = relative => {
    if (!parsed.has(relative)) {
      const raw = read(root, relative,relative===decisionPath?LIMITS.decisionManifest:LIMITS.file); total += raw.length;
      if (total > LIMITS.inputTotal) throw Error('Input aggregate budget exceeded');
      parsed.set(relative, strictParse(raw));
    }
    return parsed.get(relative);
  };
  const catalog = get(BASE + 'catalog.json');
  if (catalog.sources !== 'res://data/professional/sources.json') throw Error('Unexpected source registry');
  const declared = [BASE + 'catalog.json', BASE + 'sources.json'];
  unique(catalog.courses, 'catalog course', LIMITS.courses);
  const courses = catalog.courses.map(item => { const file = resource(item.manifest, 'courses'); declared.push(file); const course = get(file); if (course.id !== item.id) throw Error('Course manifest identity mismatch'); return course; });
  const owners = {lexemes: new Map(), expressions: new Map()};
  function records(group, files) {
    if (!Array.isArray(files) || new Set(files).size !== files.length || files.length > LIMITS.files) throw Error('Duplicate or invalid registry files');
    return files.flatMap(name => {
      const file = resource(name, group); declared.push(file);
      const values = get(file)[group]; if (!Array.isArray(values)) throw Error('Missing ' + group);
      for (const value of values) { if (owners[group].has(value.id)) throw Error('Duplicate canonical record'); owners[group].set(value.id, name); }
      return values;
    });
  }
  const lexemes = records('lexemes', catalog.lexeme_files), expressions = records('expressions', catalog.expression_files);
  if (new Set(declared).size !== declared.length || canonical([...declared].sort()) !== canonical(enumerate(root))) throw Error('Governed inventory mismatch: orphan, missing, or new file');
  const sources = get(BASE + 'sources.json').sources;
  const maps = {courses: unique(courses, 'course', LIMITS.courses), lexemes: unique(lexemes, 'lexeme', LIMITS.lexemes), expressions: unique(expressions, 'expression', LIMITS.expressions), sources: unique(sources, 'source', LIMITS.sources)};
  let moduleCount = 0;
  for (const course of courses) {
    unique(course.modules, 'module', LIMITS.modulesPerCourse);
    for (const module of course.modules) {
      moduleCount++;
      if (typeof module.foundation !== 'boolean') throw Error('Module foundation must be boolean');
      for (const [group, idKey, fileKey, cap] of [['lexemes','lexeme_ids','lexeme_files',LIMITS.selectedLexemes], ['expressions','expression_ids','expression_files',LIMITS.selectedExpressions]]) {
        const ids = module[idKey], files = module[fileKey];
        if (!Array.isArray(ids) || ids.length > cap || new Set(ids).size !== ids.length || !Array.isArray(files) || new Set(files).size !== files.length) throw Error('Invalid selected identity/resource count');
        for (const file of files) if (!declared.includes(resource(file, group))) throw Error('Undeclared module resource');
        for (const id of ids) if (!maps[group].has(id) || !files.includes(owners[group].get(id))) throw Error('Unknown or out-of-resource module identity: ' + id);
      }
    }
  }
  if (moduleCount > LIMITS.modules) throw Error('Module count budget exceeded');
  const decisions = get(decisionPath);
  return {catalog, courses, lexemes, expressions, sources, decisions, maps, files: [...declared].sort(), parsed};
}
module.exports = {BASE,GOVERNED_DIRS,resource,enumerate,read,inventory,unique,load};
