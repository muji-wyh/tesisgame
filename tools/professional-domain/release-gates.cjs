'use strict';
const fs = require('node:fs'), path = require('node:path');
const {REPO_ROOT,DECISIONS,codec,LIMITS,assertAncestors,contractInventory,assertEmptyDecisions} = require('./contract.cjs');
const inputs = require('./inputs.cjs');
const {auditProfessionalContent} = require(path.join(REPO_ROOT,'tools/validate-professional-content.cjs'));
const compare = (a,b) => a < b ? -1 : a > b ? 1 : 0;
function scan(root) {
  root = path.resolve(root); assertAncestors(root);
  const output = [],directories = []; let entries = 0, bytes = 0;
  function visit(relative,depth) {
    if (depth > LIMITS.fullDepth) throw Error('Full snapshot depth budget exceeded');
    const filename = path.join(root,relative), stat = fs.lstatSync(filename);
    if (!stat.isDirectory() || stat.isSymbolicLink()) throw Error('Full snapshot directory type rejected');
    directories.push(relative);
    const handle=fs.opendirSync(filename);
    try { for(let item;(item=handle.readSync())!==null;) {
      if (++entries > LIMITS.fullEntries) throw Error('Full snapshot entry count budget exceeded');
      if (!/^[A-Za-z0-9_.-]+$/.test(item.name) || item.isSymbolicLink()) throw Error('Unsafe snapshot name or symlink');
      const file = relative ? relative+'/'+item.name : item.name;
      if (item.isDirectory()) visit(file,depth+1);
      else if (item.isFile()) {
        const raw = codec.readBounded(path.join(root,file),LIMITS.fullFileBytes);
        bytes += raw.length;
        if (bytes > LIMITS.fullBytes || output.length >= LIMITS.fullFiles) throw Error('Full snapshot aggregate budget exceeded');
        output.push({path:file,bytes:raw.length,sha256:codec.sha256(raw)});
      } else throw Error('Unexpected full snapshot entry');
    } } finally { handle.closeSync(); }
  }
  visit('',0); return {files:output.sort((a,b)=>compare(a.path,b.path)),directories:directories.sort()};
}
function fullInventory(root) { return scan(root).files; }
function assertStable(root,expected,expectedDirectories) {
  const actual=scan(root);
  if (codec.canonical(actual.files) !== codec.canonical(expected) || expectedDirectories && codec.canonical(actual.directories)!==codec.canonical(expectedDirectories)) throw Error('Full source snapshot drift');
}
function inspect(root) {
  const contracts = contractInventory(), observed = scan(root), full = observed.files;
  const loaded = inputs.load(root);
  assertEmptyDecisions(loaded.decisions);
  const sourcePaths = new Set([...loaded.files,DECISIONS]);
  const sourceInventory = full.filter(entry => sourcePaths.has(entry.path));
  if (sourceInventory.length !== sourcePaths.size) throw Error('Missing source inventory member');
  const supportingInventory = full.filter(entry => !sourcePaths.has(entry.path));
  // The unchanged project audit enforces each ready module and every claimed
  // integrated asset, while draft modules retain their existing warnings.
  const professionalAudit = auditProfessionalContent({rootDir:root});
  assertStable(root,full,observed.directories);
  if (codec.canonical(contracts) !== codec.canonical(contractInventory())) throw Error('Release gate contract drift');
  if (!professionalAudit.ok) {
    const error = Error('Professional release gates rejected '+professionalAudit.errors.length+' error(s): '+professionalAudit.errors.slice(0,5).map(x=>x.code+' '+x.path).join('; '));
    error.gateErrors = professionalAudit.errors; throw error;
  }
  if (professionalAudit.summary.courses !== 20 || professionalAudit.summary.modules !== 200) throw Error('Initial compiled release requires all 200 modules');
  return {sourceInventory,supportingInventory,fullInventory:full,directories:observed.directories,sourceInventorySha256:codec.digest(sourceInventory),
    supportingInventorySha256:codec.digest(supportingInventory),contractsSha256:codec.digest(contracts),professionalAudit};
}
module.exports = {scan,fullInventory,assertStable,inspect};
