'use strict';
// Fresh reference consultation; retain metadata only, never complete publisher pages.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const output = path.join(__dirname, 'fresh-http-metadata.json');
if (fs.existsSync(output)) throw new Error('Preserve the original retrieval result.');
const requests = [
  { id: 'oxford-collect', url: 'https://www.oxfordlearnersdictionaries.com/definition/english/collect_1' },
  { id: 'collins-collect', url: 'https://www.collinsdictionary.com/dictionary/english/collect' }
];
(async () => {
  const results = await Promise.all(requests.map(async request => {
    const started_at = new Date().toISOString();
    try {
      const response = await fetch(request.url, { signal: AbortSignal.timeout(20000) });
      const bytes = Buffer.from(await response.arrayBuffer());
      const html = bytes.toString('utf8');
      const result = { ...request, started_at, completed_at: new Date().toISOString(), final_url: response.url, http_status: response.status, ok: response.ok, response_bytes: bytes.length, response_sha256: crypto.createHash('sha256').update(bytes).digest('hex'), content_type: response.headers.get('content-type'), full_response_retained: false };
      if (response.ok && request.id === 'oxford-collect') {
        result.selected_sense_tags = [...html.matchAll(/<[^>]*\bclass="[^"]*\bsense\b[^"]*"[^>]*>/g)].map(match => match[0]).filter(tag => /\bid="collect_sng_(?:2|6)"/.test(tag));
        result.selected_metadata = result.selected_sense_tags.map(tag => ({ id: tag.match(/\bid="([^"]+)"/)?.[1] ?? null, cefr: tag.match(/\bcefr="([^"]+)"/)?.[1] ?? null, fkcefr: tag.match(/\bfkcefr="([^"]+)"/)?.[1] ?? null }));
      }
      if (response.ok && request.id === 'collins-collect') {
        result.cefr_label_counts_observed = Object.fromEntries(['A1', 'A2', 'B1', 'B1+', 'B2', 'C1', 'C2'].map(level => [level, (html.match(new RegExp('>' + level.replace('+', '\\+') + '<', 'g')) || []).length]));
        result.scope = 'Raw response identity only. Selected COBUILD gathering B1 and pickup A2/region were read in the fresh rendered consultation; whole-page label counts do not assign senses.';
      }
      return result;
    } catch (error) {
      return { ...request, started_at, completed_at: new Date().toISOString(), ok: false, error: error.name + ': ' + error.message, full_response_retained: false };
    }
  }));
  fs.writeFileSync(output, JSON.stringify({ schema: 1, status: 'fresh_reference_consultation_only_unaccepted', results, rendered_consultations: [
    { url: requests[0].url, inspected: true, selected_sections: ['bring together / sense 1', 'take away / sense 4'], unrelated_word_of_day_level_excluded: true },
    { url: requests[1].url, inspected: true, selected_sections: ['COBUILD sense 1 gathering: B1', 'COBUILD sense 3 pickup: A2, British / American preference for pick up', 'American English dictionary fetching sense'], body_not_retained: true },
    { url: 'https://dictionary.cambridge.org/dictionary/english/collect', inspected: false, outcome: 'Web open returned Internal Error; no Cambridge sense or level claim.' }
  ] }, null, 2) + '\n', { flag: 'wx' });
  process.stdout.write(JSON.stringify(results) + '\n');
})().catch(error => { process.stderr.write(error.stack + '\n'); process.exitCode = 1; });
