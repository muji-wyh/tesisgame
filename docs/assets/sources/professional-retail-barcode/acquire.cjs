'use strict';
// Acquire a licensed secondary distribution of a credited source illustration.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const base = __dirname;
const digest = b => crypto.createHash('sha256').update(b).digest('hex');
const write = (name, data) => fs.writeFileSync(path.join(base, name), data, {flag: 'wx'});
const inputs = [
  ['source-page.html', 'https://www.clipsafari.com/clips/o38797-barcode'],
  ['cc0-deed.html', 'https://creativecommons.org/publicdomain/zero/1.0/'],
  ['barcode.svg', 'https://images.clipsafari.com/m4x37i5o8zhx4cgzznyaeqcutovn?filename=barcode.svg']
];
async function main() {
  write('started.json', JSON.stringify({recorded_at: new Date().toISOString(), inputs}, null, 2) + '\n');
  const files = [];
  try {
    for (const [name, url] of inputs) {
      const response = await fetch(url, {signal: AbortSignal.timeout(20000)});
      assert.ok(response.ok, `${url}: HTTP ${response.status}`);
      const chunks = []; let length = 0;
      for await (const chunk of response.body) {
        length += chunk.length; assert.ok(length <= 2 * 1024 * 1024, 'bounded source size');
        chunks.push(Buffer.from(chunk));
      }
      const bytes = Buffer.concat(chunks); write(name, bytes);
      files.push({path: name, requested_url: url, final_url: response.url, bytes: length, sha256: digest(bytes)});
    }
    const page = fs.readFileSync(path.join(base, 'source-page.html'), 'utf8');
    assert.match(page, /netalloy/i); assert.match(page, /CC0/);
    const svg = fs.readFileSync(path.join(base, 'barcode.svg'), 'utf8');
    assert.match(svg, /<svg[\s>]/);
    assert.doesNotMatch(svg, /<script\b|<foreignObject\b|<!ENTITY\b|\bon[a-z]+\s*=/i);
    assert.doesNotMatch(svg, /(?:href\s*=\s*["'](?:https?:|file:|data:)|url\(\s*["']?(?:https?:|file:|data:))/i);
    const receipt = {
      schema: 1, status: 'secondary_source_acquired_uninspected_not_integrated',
      recorded_at: new Date().toISOString(), sense_id: 'barcode.product-code.n',
      creator: 'netalloy', title: 'Barcode',
      original_source: 'https://openclipart.org/detail/38797/netalloy-barcode',
      acquired_from: inputs[0][1], original_source_downloaded: false,
      license: 'CC0 1.0 Universal', license_url: inputs[1][1],
      license_evidence: 'ClipSafari explicitly attributes netalloy and labels this exact downloadable SVG CC0. The Openclipart original timed out and is not claimed acquired.',
      files, available_animations: [], adaptation: 'none', visual_review: 'pending', production_changed: false
    };
    write('acquisition-receipt.json', JSON.stringify(receipt, null, 2) + '\n');
    console.log(JSON.stringify({status: receipt.status, files}));
  } catch (error) {
    write('failed-attempt.json', JSON.stringify({status: 'failed_acquisition_preserved', files, error: String(error), production_changed: false}, null, 2) + '\n');
    console.error(String(error)); process.exitCode = 1;
  }
}
main();
