'use strict';
// Public-source retrieval for this research packet. No source or production serializers are imported.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const output = path.join(__dirname, 'fresh-http-retrieval.json');
if (fs.existsSync(output)) throw new Error('Keep the original retrieval; do not overwrite.');
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const requests = [
  ['cefrj_v15_csv', 'https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master/cefrj-vocabulary-profile-1.5.csv'],
  ['cefrj_readme', 'https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master/README.md'],
  ...['collect_1', 'notify', 'postpone', 'verify', 'unsafe', 'hazard_1'].map(term => ['oxford_' + term, 'https://www.oxfordlearnersdictionaries.com/definition/english/' + term])
];
(async () => {
  const results = [];
  for (const [id, url] of requests) {
    const started = new Date().toISOString();
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(20000) });
      const bytes = Buffer.from(await response.arrayBuffer());
      const text = bytes.toString('utf8');
      const result = { id, url, fetched_at: started, final_url: response.url, http_status: response.status, ok: response.ok, bytes: bytes.length, sha256: sha(bytes), content_type: response.headers.get('content-type'), etag: response.headers.get('etag'), last_modified: response.headers.get('last-modified'), complete_source_retained: false };
      if (response.ok && id === 'cefrj_v15_csv') {
        const lines = text.split(/\r?\n/);
        const terms = ['collect', 'notify', 'postpone', 'verify', 'unsafe', 'hazard', 'inform', 'double-check', 'gather', 'warn', 'danger', 'dangerous'];
        result.header = lines[0];
        result.rows = terms.map(term => ({ term, matches: lines.flatMap((line, index) => line.split(',')[0] === term ? [{ line_number_1_based: index + 1, csv: line }] : []) }));
        result.scope = 'Headword/POS profile rows. These are not selected-sense or productive-skill certifications. Absence is limited to exact first-column matches in this v1.5 file.';
      } else if (response.ok && id.startsWith('oxford_')) {
        result.sense_opening_tags = [...text.matchAll(/<[^>]*\bclass="[^"]*\bsense\b[^"]*"[^>]*>/g)].map(match => match[0]).filter(tag => /\bid="/.test(tag));
        result.scope = 'Only raw sense opening-tag metadata retained. Definitions inspected separately through fresh web retrieval; page footer levels excluded.';
      } else if (response.ok && id === 'cefrj_readme') {
        result.scope = 'Terms and citation read separately through fresh web retrieval. Raw document hash identifies this successful download; full text is not copied.';
      }
      results.push(result);
    } catch (error) {
      results.push({ id, url, fetched_at: started, ok: false, error: error.name + ': ' + error.message, complete_source_retained: false });
    }
  }
  fs.writeFileSync(output, JSON.stringify({ status: 'research_only_unaccepted', retrieval_kind: 'fresh_direct_http', results }, null, 2) + '\n', { flag: 'wx' });
  console.log(JSON.stringify(results));
})().catch(error => { console.error(error); process.exitCode = 1; });
