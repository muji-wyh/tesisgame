'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {codec,LIMITS,GENERATED,PIN,RELEASE_KIND,TRUST_STATUS,assertAncestors,contractInventory,pinSource} = require('./contract.cjs');
const snapshot = require('./snapshot.cjs');
const gates = require('./release-gates.cjs');
const {compile} = require('./compiler.cjs');
const {audit} = require('./audit.cjs');

const same = (left, right, label) => {
  if (codec.canonical(left) !== codec.canonical(right)) throw Error(label + ' mismatch');
};
function insideBuild(rootDir, workDir) {
  const build = path.resolve(rootDir, 'build'), absolute = path.resolve(workDir);
  const fold = value => process.platform === 'win32' ? value.toLowerCase() : value;
  if (!fold(absolute).startsWith(fold(build) + path.sep)) throw Error('Release work directory must be a fresh child of this project build directory');
  assertAncestors(path.dirname(absolute));
  return absolute;
}
function artifactList(inventory) {
  return inventory.map(entry => ({path:'res://' + GENERATED + '/' + entry.path,bytes:entry.bytes,sha256:entry.sha256}));
}
function reportFor(rootDir, workDir, auditResult) {
  const descriptor = {path:'res://' + GENERATED + '/release.json',bytes:auditResult.descriptor.bytes,sha256:auditResult.descriptor.sha256};
  const rawPin = pinSource(descriptor);
  return {schema_version:1,kind:'professional_domain_prepared_release_v1',trust_status:TRUST_STATUS,
    source_inventory_sha256:auditResult.source_inventory_sha256,supporting_inventory_sha256:auditResult.supporting_inventory_sha256,
    contracts_sha256:auditResult.contracts_sha256,descriptor,pin:{path:'res://' + PIN,bytes:rawPin.length,sha256:codec.sha256(rawPin)},
    generated_inventory:artifactList(auditResult.artifact_inventory),source_inventory:auditResult.source_inventory,
    supporting_inventory:auditResult.supporting_inventory,contracts:auditResult.contracts,
    ready_modules:auditResult.ready_modules,unavailable_modules:auditResult.unavailable_modules,
    accepted_ids:[],all_real_acceptances_null:true,lexical_exceptions:0,expression_exceptions:0,
    work_dir:workDir,source_root:rootDir,build_audit_is_not_reviewer_acceptance:true};
}
function verifyPreparedRelease({rootDir, report}) {
  rootDir = path.resolve(rootDir); assertAncestors(rootDir);
  if (!report || report.schema_version !== 1 || report.kind !== 'professional_domain_prepared_release_v1' ||
      typeof report.work_dir !== 'string' || report.source_root !== rootDir) throw Error('Invalid prepared release report');
  const workDir = insideBuild(rootDir, report.work_dir), sourceRoot = path.join(workDir, 'source');
  assertAncestors(sourceRoot);
  const current = snapshot.observe(rootDir);
  const expected = [...report.source_inventory, ...report.supporting_inventory].sort((a,b) => a.path < b.path ? -1 : 1);
  same(current, expected, 'Current source/release binding');
  same(gates.fullInventory(sourceRoot), current, 'Retained source snapshot');
  same(contractInventory(), report.contracts, 'Current domain contracts');
  const checked = audit(sourceRoot, path.join(rootDir, GENERATED));
  same(reportFor(rootDir, workDir, checked), report, 'Independent prepared release report');
  const pinFile = path.join(rootDir, PIN); assertAncestors(pinFile);
  const rawPin = codec.readBounded(pinFile, LIMITS.descriptor);
  if (!rawPin.equals(pinSource(report.descriptor))) throw Error('Application descriptor pin changed or is missing');
  same(snapshot.observe(rootDir), current, 'Source drift during prepared release verification');
  same(contractInventory(), report.contracts, 'Domain contract drift during prepared release verification');
  return report;
}
function prepareRelease({rootDir, workDir}) {
  rootDir = path.resolve(rootDir); assertAncestors(rootDir);
  workDir = insideBuild(rootDir, workDir);
  if (fs.existsSync(workDir)) throw Error('Release work directory already exists; refusing to overwrite evidence');
  const generatedRoot = path.join(rootDir, GENERATED), pinFile = path.join(rootDir, PIN);
  assertAncestors(path.dirname(generatedRoot)); assertAncestors(path.dirname(pinFile));
  if (fs.existsSync(generatedRoot)) {
    assertAncestors(generatedRoot);
    if (!fs.lstatSync(generatedRoot).isDirectory()) throw Error('Generated release path is not a directory');
    const old = JSON.parse(codec.readBounded(path.join(generatedRoot, 'release.json'), LIMITS.descriptor));
    if (old.kind !== RELEASE_KIND) throw Error('Refusing to replace an unrecognized generated directory');
  }
  if (fs.existsSync(pinFile)) assertAncestors(pinFile);
  fs.mkdirSync(workDir);
  const sourceRoot = path.join(workDir, 'source'), outputRoot = path.join(workDir, 'package');
  const capture = snapshot.freeze(rootDir, sourceRoot);
  fs.writeFileSync(path.join(workDir, 'source-capture.json'), codec.encode(capture), {flag:'wx'});
  const compilation = compile(sourceRoot, outputRoot);
  fs.writeFileSync(path.join(workDir, 'compile-report.json'), codec.encode(compilation), {flag:'wx'});
  const checked = audit(sourceRoot, outputRoot);
  fs.writeFileSync(path.join(workDir, 'audit-report.json'), codec.encode(checked), {flag:'wx'});
  same(snapshot.observe(rootDir), capture.full_inventory, 'Live source drift before installation');
  same(contractInventory(), capture.contracts, 'Contract drift before installation');
  same(checked.artifact_inventory, compilation.artifacts, 'Compiler/auditor artifact inventory');
  const report = reportFor(rootDir, workDir, checked), rawPin = pinSource(report.descriptor);
  const stagedPin = path.join(workDir, 'professional_domain_release.gd');
  fs.writeFileSync(stagedPin, rawPin, {flag:'wx'});
  fs.writeFileSync(path.join(workDir, 'prepared-release.json'), codec.encode(report), {flag:'wx'});

  // Only these two fixed owned output paths are replaced. Their previous bytes
  // move into this fresh evidence directory; failures retain both generations.
  const previous = path.join(workDir, 'previous'); fs.mkdirSync(previous);
  let oldPackage = false, oldPin = false, installedPackage = false, installedPin = false;
  try {
    if (fs.existsSync(generatedRoot)) { fs.renameSync(generatedRoot, path.join(previous, 'generated')); oldPackage = true; }
    if (fs.existsSync(pinFile)) { fs.renameSync(pinFile, path.join(previous, 'professional_domain_release.gd')); oldPin = true; }
    fs.renameSync(outputRoot, generatedRoot); installedPackage = true;
    fs.renameSync(stagedPin, pinFile); installedPin = true;
    verifyPreparedRelease({rootDir,report});
  } catch (error) {
    if (installedPin) fs.renameSync(pinFile, path.join(workDir, 'failed-installed-pin.gd'));
    if (installedPackage) fs.renameSync(generatedRoot, path.join(workDir, 'failed-installed-package'));
    if (oldPin) fs.renameSync(path.join(previous, 'professional_domain_release.gd'), pinFile);
    if (oldPackage) fs.renameSync(path.join(previous, 'generated'), generatedRoot);
    throw error;
  }
  fs.writeFileSync(path.join(workDir, 'installed-release.json'), codec.encode(report), {flag:'wx'});
  return report;
}
module.exports = {prepareRelease,verifyPreparedRelease};
