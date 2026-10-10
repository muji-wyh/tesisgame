const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const root = path.resolve(__dirname, '../..');
const manifestPath = path.join(__dirname, 'supplemental-library-map.json');
const sourceRoot = path.join(root, 'build/word-art-review/library-source/supplemental');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const wait = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

async function acquire(entry, checkOnly) {
  const target = path.resolve(root, entry.local);
  if (!target.startsWith(`${sourceRoot}${path.sep}`)) {
    throw new Error(`Source path is outside the local acquisition folder: ${entry.id}`);
  }
  if (!/^[a-f0-9]{64}$/.test(entry.source.sha256)) {
    throw new Error(`Missing reviewed source hash: ${entry.id}`);
  }
  if (fs.existsSync(target) && digest(fs.readFileSync(target)) === entry.source.sha256) return;
  if (checkOnly) throw new Error(`Missing or changed source: ${entry.id}`);
  const url = new URL(entry.source.url);
  if (url.protocol !== 'https:') throw new Error(`Expected an HTTPS acquisition URL: ${entry.id}`);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const response = await fetch(url, {
      headers: { 'User-Agent': 'GrowWithPipArtwork/1.0 (educational vocabulary illustration curation)' },
      signal: AbortSignal.timeout(60000),
    });
    if (response.status === 429 || response.status === 503) {
      if (attempt === 3) throw new Error(`Source provider is busy: ${entry.id} (${response.status})`);
      const retrySeconds = Number(response.headers.get('retry-after')) || 15 * (attempt + 1);
      await wait(Math.min(60, Math.max(5, retrySeconds)) * 1000);
      continue;
    }
    if (!response.ok) throw new Error(`Source download failed: ${entry.id} (${response.status})`);
    const bytes = Buffer.from(await response.arrayBuffer());
    if (digest(bytes) !== entry.source.sha256) {
      throw new Error(`Source changed since its visual review: ${entry.id}`);
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, bytes);
    await wait(2000);
    return;
  }
}

async function main() {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const ids = process.argv.slice(2).filter(argument => argument !== '--check');
  const entries = ids.length ? manifest.files.filter(entry => ids.includes(entry.id)) : manifest.files;
  if (ids.some(id => !entries.some(entry => entry.id === id))) throw new Error('Unknown supplemental word ID.');
  for (const entry of entries) await acquire(entry, process.argv.includes('--check'));
  console.log(`Verified ${entries.length} acquired supplemental vocabulary sources.`);
}

if (require.main === module) main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});

module.exports = { acquire };
