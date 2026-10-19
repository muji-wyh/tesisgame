'use strict';
// One-time inventory sealing of reviewer-owned artifacts only.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const out = path.resolve('Q:/.codex/worktrees/current-age-vocabulary/tesisgame/build/professional-english/foundation02-held-three-independent-review-r01');
if (path.resolve(__dirname).toLowerCase() !== out.toLowerCase()) throw new Error('Unexpected review directory');
if (fs.existsSync(path.join(out, 'inventory.json'))) throw new Error('Inventory already exists; preserve it');
const sha = raw => crypto.createHash('sha256').update(raw).digest('hex');
const names = fs.readdirSync(out).sort();
const expected = ['REVIEW.md', 'assemble-review-record.cjs', 'assembly-receipt.json', 'context-checks.json', 'fresh-independent-http.json', 'input-verification.json', 'language-projections.json', 'reference-retrieval-start.json', 'retrieve-reference-evidence.cjs', 'reviewer-decisions.json', 'seal-inventory.cjs', 'source-observations.json'].sort();
if (JSON.stringify(names) !== JSON.stringify(expected)) throw new Error('Unexpected review file set');
const files = names.map(name => {
  const absolute = path.join(out, name);
  if (!fs.lstatSync(absolute).isFile()) throw new Error('Non-file review artifact');
  const raw = fs.readFileSync(absolute);
  return { path: name, bytes: raw.length, sha256: sha(raw) };
});
const projections = JSON.parse(fs.readFileSync(path.join(out, 'language-projections.json')));
for (const entry of projections.entries) {
  if (sha(JSON.stringify(entry.exact_language_projection)) !== entry.accepted_language_projection_sha256) throw new Error('Projection hash mismatch');
  if (JSON.stringify(entry.changed_fields_if_separately_delivered) !== '["difficulty"]') throw new Error('Projection scope mismatch');
}
const raw = Buffer.from(JSON.stringify({ schema: 1, status: 'frozen_independent_three_field_language_review_not_delivered', frozen_at: new Date().toISOString(), reviewer: 'Codex runtime_recovery independent AI language reviewer; not human or subject-matter approval', hash_algorithm: 'SHA256', note: 'Raw file hashes. This inventory excludes itself. Existing production holds and gates remain unchanged.', accepted_projection_count: 3, current_whole_entry_holds_preserved: 6, automatic_application_permitted: false, files }, null, 2) + '\n');
fs.writeFileSync(path.join(out, 'inventory.json'), raw, { flag: 'wx' });
console.log(JSON.stringify({ inventory_sha256: sha(raw), artifact_count: files.length, bytes: raw.length }, null, 2));
