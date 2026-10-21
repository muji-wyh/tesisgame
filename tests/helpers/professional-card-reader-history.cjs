'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { isDeepStrictEqual } = require('node:util');
const record = require('../../data/professional/provenance/retail-card-reader-image-2026-10-20.json');

assert.equal(record.patches.length, 1);
const patch = record.patches[0];
assert.equal(patch.id, 'card-reader.payment-device.n');

// Older media/morphology receipts keep their exact before-image contract.
// Only either complete accepted state is reversible; partial or unrelated
// lexical, audio, graph, review or note drift cannot be hidden by this helper.
function beforeCardReaderImage(entry) {
  if (entry.id !== patch.id) return entry;
  if (isDeepStrictEqual(entry, patch.before)) return structuredClone(patch.before);
  assert.deepEqual(entry, patch.after, entry.id + ': exact later card-reader image, brief and one obsolete pending-image clause');
  return structuredClone(patch.before);
}

function beforeCardReaderImageBytes(bytes) {
  assert.ok(Buffer.isBuffer(bytes));
  const sha = value => crypto.createHash('sha256').update(value).digest('hex');
  if (sha(bytes) === record.before_file_sha256) return Buffer.from(bytes);
  assert.equal(sha(bytes), record.after_file_sha256, 'Exact complete current Retail file required before reversing the card-reader image');
  const indented = value => JSON.stringify(value, null, 2).split('\n').map(line => '    ' + line).join('\n');
  const after = indented(patch.after);
  const text = bytes.toString('utf8');
  assert.equal(text.split(after).length, 2, 'Exactly one serialized card-reader after-image');
  const historical = Buffer.from(text.replace(after, indented(patch.before)));
  assert.equal(sha(historical), record.before_file_sha256, 'Exact complete historical Retail bytes; no general reserialization');
  return historical;
}

module.exports = { beforeCardReaderImage, beforeCardReaderImageBytes };
