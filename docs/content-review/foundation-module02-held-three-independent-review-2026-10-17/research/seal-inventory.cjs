'use strict';
// Research artifact integrity bookkeeping only. No repository module or test is loaded.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const out = __dirname;
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const write = (name, value) => fs.writeFileSync(path.join(out, name), JSON.stringify(value, null, 2) + '\n', { flag: 'wx' });
if (fs.existsSync(path.join(out, 'inventory.json')) || fs.existsSync(path.join(out, 'integrity-summary.json'))) throw new Error('Preserve the sealed inventory.');
const pins = JSON.parse(fs.readFileSync(path.join(out, 'input-pins.json'))).files;
const unique = [...new Map(pins.map(pin => [pin.path, pin])).values()];
const drift = unique.flatMap(pin => {
  const bytes = fs.readFileSync(path.join(root, pin.path));
  const current = sha(bytes);
  return current === pin.sha256 ? [] : [{ path: pin.path, before_sha256: pin.sha256, current_sha256: current }];
});
const context = JSON.parse(fs.readFileSync(path.join(out, 'context.json')));
const current = JSON.parse(fs.readFileSync(path.join(root, 'data/professional/lexemes/foundation-module02.json'))).lexemes;
const heldEntries = context.entries.map(record => ({ id: record.id, expected_sha256: record.object_sha256, current_sha256: sha(JSON.stringify(current.find(entry => entry.id === record.id))) }));
const receipt = unique.find(pin => pin.path.endsWith('foundation02-third10-persisted-validation-r01/attempt-001/receipt.json'));
write('integrity-summary.json', {
  status: 'research_only_unaccepted', sealed_at: new Date().toISOString(),
  source_files_unique: unique.length, source_drift_since_capture: drift,
  six_held_entry_hashes: heldEntries,
  all_six_historical_holds_exact: heldEntries.every(entry => entry.expected_sha256 === entry.current_sha256),
  parent_receipt_sha256: receipt.sha256,
  production_changes_by_this_agent: false,
  tests_native_or_production_serializers_run: false,
  observations: ['Source file hashes and object hashes are distinct.', 'Other agents can continue disjoint work; this seals this research packet only.']
});
const walk = directory => fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
  const full = path.join(directory, entry.name);
  return entry.isDirectory() ? walk(full) : [full];
});
const files = walk(out).sort().map(full => {
  const bytes = fs.readFileSync(full);
  return { path: path.relative(out, full).replaceAll('\\', '/'), bytes: bytes.length, sha256: sha(bytes) };
});
write('inventory.json', { schema_version: 1, status: 'research_only_unaccepted', hash_algorithm: 'SHA256', note: 'This inventory excludes itself.', files });
console.log(JSON.stringify({ files: files.length, source_drift: drift, all_six_historical_holds_exact: heldEntries.every(entry => entry.expected_sha256 === entry.current_sha256), parent_receipt_sha256: receipt.sha256, inventory_sha256: sha(fs.readFileSync(path.join(out, 'inventory.json'))) }));
