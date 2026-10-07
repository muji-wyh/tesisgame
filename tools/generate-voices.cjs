const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { spawn, spawnSync } = require('node:child_process');

const PROFILE = Object.freeze({
  voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%'
});
const EDGE_TTS_VERSION = '7.2.8';
const MANIFEST_PATH = 'docs/assets/ava-voice.json';
const PROMPT_IDS = [
  ...['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'].map(season => `${season}-theme`),
  'phrase-intro', 'phrase-try-again', 'phrase-complete'
];

function englishText(text) {
  if (typeof text !== 'string' || text.length > 500 ||
      !/^[A-Za-z][A-Za-z0-9 ,.!?'-]*$/.test(text)) {
    throw new Error('Voice messages must be short, nonempty ASCII English text.');
  }
}

function messagesFor(root) {
  const prompts = JSON.parse(fs.readFileSync(path.join(root, 'voice-prompts.json'), 'utf8'));
  const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'));
  const phrases = JSON.parse(fs.readFileSync(path.join(root, 'phrases.json'), 'utf8'));
  if (!prompts || Array.isArray(prompts) || typeof prompts !== 'object' ||
      Object.keys(prompts).length !== PROMPT_IDS.length ||
      PROMPT_IDS.some(id => !Object.hasOwn(prompts, id))) {
    throw new Error(`voice-prompts.json must contain exactly the ${PROMPT_IDS.length} required prompt IDs.`);
  }
  if (!Array.isArray(words) || words.length === 0) {
    throw new Error('words.json must contain a nonempty vocabulary array.');
  }
  if (!Array.isArray(phrases) || phrases.length === 0) {
    throw new Error('phrases.json must contain a nonempty phrase array.');
  }
  const messages = Object.entries(prompts).map(([id, text]) => ({ id, text }));
  for (const word of words) {
    if (!word || typeof word.id !== 'string' || !/^[a-z]+(?:-[a-z]+)*$/.test(word.id) ||
        typeof word.text !== 'string' || !/^[a-z]{2,14}$/.test(word.text)) {
      throw new Error('Vocabulary entries need a lowercase ID and a short English word.');
    }
    const id = `word-${word.id}`;
    if (word.audio !== `assets/audio/voice/${id}.wav`) {
      throw new Error(`Unexpected audio path for vocabulary '${word.id}'.`);
    }
    messages.push({ id, text: word.text });
  }
  for (const phrase of phrases) {
    if (!phrase || typeof phrase.id !== 'string' || !/^[a-z]+(?:-[a-z]+)*$/.test(phrase.id) ||
        typeof phrase.text !== 'string' || !/^[a-z]{2,14}(?: [a-z]{2,14}){1,3}$/.test(phrase.text)) {
      throw new Error('Phrase entries need a lowercase ID and two to four short English words.');
    }
    const id = `phrase-${phrase.id}`;
    if (phrase.audio !== `assets/audio/voice/${id}.wav`) {
      throw new Error(`Unexpected audio path for phrase '${phrase.id}'.`);
    }
    messages.push({ id, text: phrase.text });
  }
  if (new Set(messages.map(message => message.id)).size !== messages.length) {
    throw new Error('Voice IDs must be unique.');
  }
  for (const message of messages) englishText(message.text);
  return messages;
}

function speechText(text) {
  englishText(text);
  // Short grammatical contexts disambiguate words with multiple pronunciations.
  // Keep the original kite clip's audited picture-naming phrase unchanged.
  const contexts = { kite: 'A kite.', close: 'To close.', read: 'To read.', tear: 'To tear.',
    polish: 'To polish.', separate: 'To separate.', concentrate: 'To concentrate.',
    present: 'A present.', minute: 'One minute.' };
  return contexts[text] || (/[.!?]$/.test(text) ? text : `${text}.`);
}

function assertWave(bytes, rate = 22050) {
  if (!Buffer.isBuffer(bytes) || bytes.length < 44 || bytes.length > 4 * 1024 * 1024 ||
      bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WAVE' ||
      bytes.readUInt32LE(4) !== bytes.length - 8) {
    throw new Error('Invalid or truncated voice WAV.');
  }
  let format = false;
  let data;
  let offset = 12;
  while (offset + 8 <= bytes.length) {
    const id = bytes.toString('ascii', offset, offset + 4);
    const size = bytes.readUInt32LE(offset + 4);
    const start = offset + 8;
    if (start + size > bytes.length) throw new Error('Truncated voice WAV chunk.');
    if (id === 'fmt ') {
      if (format || size < 16 || bytes.readUInt16LE(start) !== 1 ||
          bytes.readUInt16LE(start + 2) !== 1 || bytes.readUInt32LE(start + 4) !== rate ||
          bytes.readUInt32LE(start + 8) !== rate * 2 || bytes.readUInt16LE(start + 12) !== 2 ||
          bytes.readUInt16LE(start + 14) !== 16) {
        throw new Error(`Invalid voice WAV format; expected ${rate} Hz PCM16 mono.`);
      }
      format = true;
    } else if (id === 'data') {
      if (data || size < 1000 || size % 2 !== 0) throw new Error('Invalid voice WAV samples.');
      data = bytes.subarray(start, start + size);
    }
    offset = start + size + size % 2;
  }
  if (!format || !data || offset !== bytes.length) throw new Error('Incomplete voice WAV.');
  // Require 20 ms above the noise floor, not merely one nonzero sample.
  let audibleSamples = 0;
  for (let index = 0; index < data.length; index += 2) {
    if (Math.abs(data.readInt16LE(index)) >= 64) audibleSamples += 1;
  }
  if (audibleSamples < Math.ceil(rate * 0.02)) {
    throw new Error('Generated voice WAV is effectively silent or contains only an isolated click.');
  }
}

function ffmpeg(args, input) {
  const result = spawnSync('ffmpeg', args, {
    input, encoding: 'utf8', windowsHide: true, timeout: 30000, maxBuffer: 1024 * 1024
  });
  if (result.error?.code === 'ENOENT') {
    throw new Error('FFmpeg must be installed and on PATH to generate mobile voice recordings.');
  }
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`FFmpeg failed: ${result.stderr.trim()}`);
}

function convertVoice(bytes, destination) {
  // Decode and change the container/sample format only. Preserve the approved
  // voice's pitch, timing, volume, pauses, and unprocessed delivery.
  ffmpeg([
    '-hide_banner', '-loglevel', 'error', '-nostdin', '-n', '-i', 'pipe:0',
    '-ac', '1', '-ar', '22050', '-c:a', 'pcm_s16le', '-map_metadata', '-1',
    '-fflags', '+bitexact', destination
  ], bytes);
  assertWave(fs.readFileSync(destination));
}

function digest(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function cacheIdentity(text, profile = PROFILE) {
  return {
    schema: 1, provider: 'Microsoft Edge TTS', edgeTtsVersion: EDGE_TTS_VERSION,
    profile: { voice: profile.voice, rate: profile.rate, pitch: profile.pitch, volume: profile.volume },
    text: speechText(text), output: '22050-hz-pcm16-mono-no-effects'
  };
}

function cacheKey(text, profile = PROFILE) {
  return digest(JSON.stringify(cacheIdentity(text, profile)));
}

function regularFile(filename) {
  try { return fs.lstatSync(filename).isFile(); }
  catch (error) { if (error.code === 'ENOENT') return false; throw error; }
}

function cachedWave(entry) {
  try {
    if (!regularFile(entry.wave) || !regularFile(entry.metadata)) return null;
    const metadata = JSON.parse(fs.readFileSync(entry.metadata, 'utf8'));
    if (JSON.stringify(metadata.identity) !== JSON.stringify(entry.identity)) return null;
    const bytes = fs.readFileSync(entry.wave);
    if (metadata.sha256 !== digest(bytes)) return null;
    assertWave(bytes);
    return bytes;
  } catch (error) {
    if (error.code === 'EACCES' || error.code === 'EPERM') throw error;
    return null;
  }
}

async function runEdgeBatch({ manifestPath }) {
  const python = process.env.PYTHON || 'python';
  await new Promise((resolve, reject) => {
    const child = spawn(python, [path.join(__dirname, 'edge-voice-batch.py'), '--manifest', manifestPath], {
      stdio: 'inherit', windowsHide: true
    });
    child.once('error', error => reject(new Error(
      `Could not start Python for Edge TTS. Set PYTHON to its executable: ${error.message}`)));
    child.once('exit', (code, signal) => {
      if (code === 0) resolve();
      else reject(new Error(`Edge TTS batch failed (${signal || `exit ${code}`}). Existing recordings were not replaced; completed cache entries will resume next time.`));
    });
  });
}

function fileRecord(message, bytes) {
  return { id: message.id, text: message.text, synthesisText: speechText(message.text),
    path: `assets/audio/voice/${message.id}.wav`, bytes: bytes.length, sha256: digest(bytes) };
}

function retainedRecords(root, messages) {
  let previous;
  try { previous = JSON.parse(fs.readFileSync(path.join(root, MANIFEST_PATH), 'utf8')); }
  catch { /* The complete replacement below is required for undocumented audio. */ }
  const approved = previous?.provider === 'Microsoft Edge TTS' &&
    previous.client?.name === 'edge-tts' && previous.client?.version === EDGE_TTS_VERSION &&
    Object.entries(PROFILE).every(([key, value]) => previous.profile?.[key] === value) &&
    Array.isArray(previous.files);
  const retained = new Map();
  for (const message of messages) {
    const filename = path.join(root, 'assets', 'audio', 'voice', `${message.id}.wav`);
    if (!regularFile(filename)) continue;
    const bytes = fs.readFileSync(filename);
    const record = fileRecord(message, bytes);
    const matching = approved && previous.files.filter(file => file.id === message.id);
    if (!matching || matching.length !== 1 ||
        Object.entries(record).some(([key, value]) => matching[0][key] !== value)) {
      throw new Error(`Cannot use --missing: ${message.id} is not documented with the approved Ava profile and current text/hash. Run a full generation without --missing.`);
    }
    assertWave(bytes);
    retained.set(message.id, record);
  }
  return retained;
}

function publishBatch(publications, staging) {
  const backups = path.join(staging, 'previous');
  fs.mkdirSync(backups);
  for (const [index, entry] of publications.entries()) {
    fs.mkdirSync(path.dirname(entry.destination), { recursive: true });
    entry.previous = regularFile(entry.destination) ? path.join(backups, `${index}.backup`) : null;
    if (entry.previous) fs.copyFileSync(entry.destination, entry.previous);
  }
  const published = [];
  try {
    for (const entry of publications) {
      fs.renameSync(entry.pending, entry.destination);
      published.push(entry);
    }
  } catch (error) {
    for (const entry of published.reverse()) {
      if (entry.previous) fs.copyFileSync(entry.previous, entry.destination);
      else fs.unlinkSync(entry.destination);
    }
    throw error;
  }
}

async function generateVoices({
  root = path.resolve(__dirname, '..'), onlyMissing = false,
  synthesizeBatch = runEdgeBatch, convert = convertVoice
} = {}) {
  root = path.resolve(root);
  const catalog = messagesFor(root);
  let messages = catalog;
  const output = path.join(root, 'assets', 'audio', 'voice');
  for (const { id } of messages) {
    const destination = path.join(output, `${id}.wav`);
    if (fs.existsSync(destination) && !regularFile(destination)) {
      throw new Error(`Voice destination is not a regular file: ${destination}`);
    }
    if (fs.existsSync(path.join(output, `${id}.generating.wav`))) {
      throw new Error(`Unexplained pending voice output exists for ${id}; inspect it before regenerating.`);
    }
  }
  const retained = onlyMissing ? retainedRecords(root, catalog) : new Map();
  if (onlyMissing) messages = messages.filter(({ id }) => !retained.has(id));
  if (messages.length === 0) return 0;
  if (convert === convertVoice) ffmpeg(['-version']);
  const build = path.join(root, 'build');
  const cacheDirectory = path.join(build, 'voice-cache');
  fs.mkdirSync(cacheDirectory, { recursive: true });
  const staging = fs.mkdtempSync(path.join(build, 'voice-generation-'));
  try {
    const entries = messages.map(message => {
      const key = cacheKey(message.text);
      return { ...message, identity: cacheIdentity(message.text),
        source: path.join(cacheDirectory, `${key}.mp3`),
        wave: path.join(cacheDirectory, `${key}.wav`),
        metadata: path.join(cacheDirectory, `${key}.json`),
        pending: path.join(staging, `${message.id}.wav`) };
    });
    const requests = [];
    for (const entry of entries) {
      entry.cached = cachedWave(entry);
      if (!entry.cached && !(regularFile(entry.source) && fs.statSync(entry.source).size > 0)) {
        requests.push({ id: entry.id, text: entry.identity.text, output: entry.source });
      }
    }
    if (requests.length) {
      const manifest = { edgeTtsVersion: EDGE_TTS_VERSION, profile: PROFILE, cacheDirectory, requests };
      const manifestPath = path.join(staging, 'requests.json');
      fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
      await synthesizeBatch({ manifest, manifestPath });
    }
    for (const entry of entries) {
      if (entry.cached) fs.writeFileSync(entry.pending, entry.cached);
      else {
        if (!regularFile(entry.source) || fs.statSync(entry.source).size === 0) {
          throw new Error(`Edge TTS did not produce audio for ${entry.id}. Existing recordings were not replaced.`);
        }
        try {
          await convert(fs.readFileSync(entry.source), entry.pending);
          assertWave(fs.readFileSync(entry.pending));
        } catch (error) {
          // A damaged source cannot poison every subsequent resume attempt.
          fs.unlinkSync(entry.source);
          throw new Error(`Voice conversion failed for ${entry.id}: ${error.message}. Existing recordings were not replaced.`, { cause: error });
        }
        const bytes = fs.readFileSync(entry.pending);
        const cachePending = path.join(staging, `${entry.id}.cache.wav`);
        fs.writeFileSync(cachePending, bytes);
        fs.renameSync(cachePending, entry.wave);
        const metadataPending = path.join(staging, `${entry.id}.cache.json`);
        fs.writeFileSync(metadataPending, JSON.stringify({ identity: entry.identity, sha256: digest(bytes) }, null, 2) + '\n');
        fs.renameSync(metadataPending, entry.metadata);
      }
      retained.set(entry.id, fileRecord(entry, fs.readFileSync(entry.pending)));
    }
    const manifestPending = path.join(staging, 'ava-voice.json');
    fs.writeFileSync(manifestPending, JSON.stringify({
      provider: 'Microsoft Edge TTS', client: { name: 'edge-tts', version: EDGE_TTS_VERSION },
      profile: PROFILE, format: { sampleRate: 22050, channels: 1, bitsPerSample: 16, encoding: 'PCM' },
      postprocessing: 'None; MP3 decoded to the existing WAV format only.',
      generatedAt: new Date().toISOString(), files: catalog.map(message => retained.get(message.id))
    }, null, 2) + '\n');
    // Synthesis, decoding, and validation must all succeed before publication.
    publishBatch([
      ...entries.map(entry => ({ pending: entry.pending, destination: path.join(output, `${entry.id}.wav`) })),
      { pending: manifestPending, destination: path.join(root, MANIFEST_PATH) }
    ], staging);
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
  return messages.length;
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.some(arg => arg !== '--missing')) {
    console.error('Usage: node tools/generate-voices.cjs [--missing]');
    process.exitCode = 1;
  } else {
    generateVoices({ onlyMissing: args.includes('--missing') }).then(count => {
      console.log(`Published ${count} English recordings with ${PROFILE.voice} (rate ${PROFILE.rate}, pitch ${PROFILE.pitch}, volume ${PROFILE.volume}; 22050 Hz PCM16 mono, no effects).`);
    }).catch(error => {
      console.error(error.message);
      process.exitCode = 1;
    });
  }
}

module.exports = { PROFILE, EDGE_TTS_VERSION, MANIFEST_PATH, speechText, messagesFor, assertWave, convertVoice,
  cacheIdentity, cacheKey, generateVoices };
