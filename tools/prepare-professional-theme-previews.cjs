const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '..');
const record = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/professional-themes.json'), 'utf8'));
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const readChecked = (file, expected) => {
  const bytes = fs.readFileSync(file);
  if (digest(bytes) !== expected) throw new Error(`Unreviewed or changed bytes: ${file}`);
  return bytes;
};

for (const source of record.source_files) {
  readChecked(source.path, source.sha256);
  for (const dependency of source.dependencies) readChecked(dependency.path, dependency.sha256);
  if (source.retained_copy) {
    readChecked(source.retained_copy.path, source.retained_copy.sha256);
    for (const dependency of source.retained_copy.dependencies) readChecked(dependency.path, dependency.sha256);
  }
}
for (const pack of record.packs) {
  const license = readChecked(pack.license_original, pack.license_sha256);
  const destination = path.join(root, pack.license_destination);
  fs.mkdirSync(path.dirname(destination), {recursive: true});
  fs.writeFileSync(destination, license);
}
const themesPath = path.join(root, 'data/professional/themes.json');
const themes = JSON.parse(fs.readFileSync(themesPath, 'utf8'));
for (const preview of record.previews) {
  const bytes = readChecked(path.join(root, preview.reviewed_candidate), preview.reviewed_sha256);
  if (bytes.readUInt32BE(0) !== 0x89504e47 || Math.max(bytes.readUInt32BE(16), bytes.readUInt32BE(20)) > 512 || bytes.length > 400 * 1024) {
    throw new Error('Home preview exceeds its reviewed PNG budget: ' + preview.id);
  }
  const packs = (preview.source_ids || [preview.source_id]).map(id => record.packs.find(item => item.id === id));
  const theme = themes.profiles.find(item => item.id === preview.theme_id);
  if (!packs.length || packs.some(pack => !pack) || !theme) throw new Error('Unknown reviewed theme/source: ' + preview.id);
  fs.writeFileSync(path.join(root, preview.destination), bytes);
  theme.preview = {status: 'integrated', path: 'res://' + preview.destination, sha256: preview.reviewed_sha256,
    source: packs.map(pack => pack.url).join('; '), creator: [...new Set(packs.map(pack => pack.creator))].join('; '),
    license: [...new Set(packs.map(pack => pack.license))].join('; '), acquisition_status: 'integrated',
    review: preview.review, brief: preview.scope, available_animations: [], adaptations: preview.processing};
}
fs.writeFileSync(themesPath, JSON.stringify(themes, null, 2) + '\n');
console.log(`Imported ${record.previews.length} reviewed Home previews; full theme readiness remains unchanged.`);
