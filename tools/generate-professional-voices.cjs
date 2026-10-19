'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const {PROFILE, EDGE_TTS_VERSION, convertVoice, assertWave} = require('./generate-voices.cjs');
const {loadProfessionalContent} = require('./validate-professional-content.cjs');
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const write = (file, value) => fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');

// This tool acquires candidates only. Publishing, pronunciation review, and
// curriculum readiness are separate operations against exact candidate hashes.
function prepareBatch({root = path.resolve(__dirname, '..'), courseId, moduleId, outputDirectory, senseIds = []}) {
  const data = loadProfessionalContent(root);
  const course = data.courses.find(item => item.id === courseId);
  const module = course?.modules.find(item => item.id === moduleId);
  if (!module) throw new Error('Select an existing Professional course and module.');
  if (!outputDirectory || !path.isAbsolute(outputDirectory)) throw new Error('Use an absolute candidate output directory.');
  if (!Array.isArray(senseIds) || new Set(senseIds).size !== senseIds.length) throw new Error('Sense selections must be unique.');
  const selected = senseIds.length ? senseIds : module.lexeme_ids;
  if (selected.some(id => !module.lexeme_ids.includes(id))) throw new Error('Every selected sense must belong to the module.');
  const byId = new Map(data.lexemes.map(entry => [entry.id, entry]));
  const candidates = selected.map(id => byId.get(id));
  if (candidates.some(entry => entry?.review.language !== 'reviewed')) {
    throw new Error('Review the selected term text and meaning before acquiring pronunciation candidates.');
  }
  const retained = [];
  const terms = [];
  const cacheDirectory = path.join(outputDirectory, 'source-mp3');
  fs.mkdirSync(cacheDirectory, {recursive: true});
  for (const entry of candidates) {
    if (entry.media.audio.status === 'integrated') {
      const audio = entry.media.audio;
      if (audio.review.status !== 'reviewed' || !audio.path?.startsWith('res://professional-media/') ||
          !/^[a-f0-9]{64}$/.test(audio.sha256) || audio.path !== `res://professional-media/${audio.sha256}.wav` ||
          Object.entries({...PROFILE, postprocessing: false}).some(([key, value]) => audio.voice_settings?.[key] !== value)) {
        throw new Error(`Cannot retain inconsistent integrated audio for ${entry.id}.`);
      }
      const bytes = fs.readFileSync(path.join(root, audio.path.slice(6)));
      assertWave(bytes);
      if (digest(bytes) !== audio.sha256) throw new Error(`Integrated audio hash changed for ${entry.id}.`);
      retained.push({sense_id: entry.id, sha256: audio.sha256});
      continue;
    }
    // Do not borrow Growth's sense-specific homograph contexts (for example,
    // present = a gift). The exact lexical term is submitted and retained for
    // subsequent pronunciation review; synthesis alone cannot approve it.
    const text = entry.text;
    if (typeof text !== 'string' || text.length > 500 || !/^[A-Za-z][A-Za-z0-9 ,.!?'-]*$/.test(text)) {
      throw new Error(`Unsupported spoken term text for ${entry.id}; author an explicit pronunciation request first.`);
    }
    const synthesisText = /[.!?]$/.test(text) ? text : `${text}.`;
    const identity = {schema: 1, provider: 'Microsoft Edge TTS', client: {name: 'edge-tts', version: EDGE_TTS_VERSION},
      profile: PROFILE, synthesis_text: synthesisText, format: '22050-hz-pcm16-mono-no-effects'};
    const key = digest(JSON.stringify(identity));
    const wave = path.join(outputDirectory, `${key}.wav`);
    const receipt = path.join(outputDirectory, `${key}.json`);
    const source = path.join(cacheDirectory, `${key}.mp3`);
    let cached = false;
    if (fs.existsSync(wave) || fs.existsSync(receipt)) {
      if (!fs.existsSync(wave) || !fs.existsSync(receipt)) throw new Error(`Incomplete candidate pair: ${key}`);
      const previous = read(receipt);
      const bytes = fs.readFileSync(wave);
      assertWave(bytes);
      if (JSON.stringify(previous.identity) !== JSON.stringify(identity) || previous.wav_sha256 !== digest(bytes) ||
          !fs.existsSync(source) || previous.source_mp3_sha256 !== digest(fs.readFileSync(source))) {
        throw new Error(`Candidate provenance or bytes changed: ${key}`);
      }
      cached = true;
    }
    terms.push({sense_id: entry.id, text, key, identity, source, wave, receipt, cached});
  }
  const missing = new Map();
  for (const term of terms.filter(term => !term.cached)) {
    missing.set(term.key, {id: `candidate-${term.key.replace(/[0-9]/g, number => 'g' + String.fromCharCode(97 + Number(number)))}`,
      text: term.identity.synthesis_text, output: term.source});
  }
  const manifest = {edgeTtsVersion: EDGE_TTS_VERSION, profile: PROFILE, cacheDirectory, requests: [...missing.values()]};
  const manifestPath = path.join(outputDirectory, 'manifest.json');
  write(manifestPath, manifest);
  const batch = {schema_version: 1, course_id: courseId, module_id: moduleId,
    status: 'prepared_candidates_only', retained, terms, manifest_path: manifestPath,
    missing_recordings: manifest.requests.length, listening_review: 'pending'};
  write(path.join(outputDirectory, 'batch.json'), batch);
  return batch;
}

function acquireBatch(options, {run = spawnSync, convert = convertVoice} = {}) {
  const batch = prepareBatch(options);
  if (batch.missing_recordings) {
    const result = run(options.python || process.env.PYTHON || 'python', [path.join(__dirname, 'edge-voice-batch.py'), '--manifest', batch.manifest_path],
      {stdio: 'inherit', windowsHide: true});
    if (result.error || result.status !== 0) throw result.error || new Error('Pronunciation acquisition failed; existing production audio is unchanged.');
  }
  const done = new Set();
  for (const term of batch.terms) {
    if (term.cached || done.has(term.key)) continue;
    const source = fs.readFileSync(term.source);
    const pending = `${term.wave}.${process.pid}.part.wav`;
    try {
      convert(source, pending);
      const bytes = fs.readFileSync(pending);
      assertWave(bytes);
      // Candidate files have never been production assets. A later invocation
      // verifies their source, synthesis identity and exact hashes before reuse.
      fs.renameSync(pending, term.wave);
      write(term.receipt, {status: 'acquired_candidate', identity: term.identity,
        source_mp3_sha256: digest(source), wav_sha256: digest(bytes), bytes: bytes.length,
        creator: 'Microsoft Ava Neural; project-authored term text',
        rights: 'Microsoft Services Agreement applies; client software licensing is separate.',
        processing: 'MP3 decoded/resampled to PCM16 mono 22050 Hz; no effects or trimming.',
        pronunciation_and_listening_review: 'pending', production_integrated: false});
      done.add(term.key);
    } finally {
      if (fs.existsSync(pending)) fs.unlinkSync(pending);
    }
  }
  const completed = prepareBatch(options);
  completed.status = 'acquired_candidates_only';
  write(path.join(options.outputDirectory, 'batch.json'), completed);
  return completed;
}

if (require.main === module) {
  try {
    const args = process.argv.slice(2), values = {}, selected = [];
    let acquire = false;
    for (let index = 0; index < args.length; index++) {
      const flag = args[index];
      if (flag === '--acquire') { acquire = true; continue; }
      if (!['--course', '--module', '--output', '--sense', '--python'].includes(flag) || !args[index + 1] || args[index + 1].startsWith('--')) {
        throw new Error('Usage: node tools/generate-professional-voices.cjs --course ID --module ID --output DIRECTORY [--sense ID ...] [--acquire] [--python EXECUTABLE]');
      }
      const value = args[++index];
      if (flag === '--sense') selected.push(value); else values[flag.slice(2)] = value;
    }
    const options = {courseId: values.course, moduleId: values.module,
      outputDirectory: values.output && path.resolve(values.output), senseIds: selected, python: values.python};
    const result = acquire ? acquireBatch(options) : prepareBatch(options);
    console.log(JSON.stringify({status: result.status, selected: result.terms.length + result.retained.length,
      retained_integrated: result.retained.length, missing_recordings: result.missing_recordings,
      manifest: result.manifest_path, listening_review: 'pending'}, null, 2));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}

module.exports = {prepareBatch, acquireBatch};
