const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { setTimeout: sleep } = require('node:timers/promises');

const PROFILE = Object.freeze({
  voice: 'en-US-JennyNeural',
  style: 'friendly',
  styleDegree: '1.15',
  rate: '-8%',
  format: 'riff-24khz-16bit-mono-pcm'
});
const PROMPT_IDS = [
  'welcome', 'correct', 'wrong', 'loss',
  ...['spring', 'summer', 'autumn', 'winter', 'ocean', 'space'].flatMap(season =>
    [`${season}-theme`, `${season}-arrive`, `${season}-open`])
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
  if (!prompts || Array.isArray(prompts) || typeof prompts !== 'object' ||
      Object.keys(prompts).length !== PROMPT_IDS.length ||
      PROMPT_IDS.some(id => !Object.hasOwn(prompts, id))) {
    throw new Error(`voice-prompts.json must contain exactly the ${PROMPT_IDS.length} required prompt IDs.`);
  }
  if (!Array.isArray(words) || words.length === 0) {
    throw new Error('words.json must contain a nonempty vocabulary array.');
  }
  const messages = Object.entries(prompts).map(([id, text]) => ({ id, text }));
  for (const word of words) {
    if (!word || typeof word.id !== 'string' || !/^[a-z]+(?:-[a-z]+)*$/.test(word.id) ||
        typeof word.text !== 'string' || !/^[a-z]{2,6}$/.test(word.text)) {
      throw new Error('Vocabulary entries need a lowercase ID and a short English word.');
    }
    const id = `word-${word.id}`;
    if (word.audio !== `assets/audio/voice/${id}.wav`) {
      throw new Error(`Unexpected audio path for vocabulary '${word.id}'.`);
    }
    messages.push({ id, text: word.text });
  }
  if (new Set(messages.map(message => message.id)).size !== messages.length) {
    throw new Error('Voice IDs must be unique.');
  }
  for (const message of messages) englishText(message.text);
  return messages;
}

function speechMarkup(text) {
  englishText(text);
  const sentence = /[.!?]$/.test(text) ? text : `${text}.`;
  return `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="en-US">
  <voice name="${PROFILE.voice}">
    <mstts:silence type="Leading-exact" value="60ms"/>
    <mstts:silence type="Tailing-exact" value="100ms"/>
    <mstts:express-as style="${PROFILE.style}" styledegree="${PROFILE.styleDegree}">
      <prosody rate="${PROFILE.rate}"><s>${sentence}</s></prosody>
    </mstts:express-as>
  </voice>
</speak>`;
}

function assertWave(bytes, rate) {
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

function convertVoice(bytes, destination, sourceRate = 24000) {
  assertWave(bytes, sourceRate);
  // Trim only the final pause, retaining quiet endings and pauses within sentences.
  ffmpeg([
    '-hide_banner', '-loglevel', 'error', '-nostdin', '-n', '-i', 'pipe:0',
    '-af', 'areverse,silenceremove=start_periods=1:start_threshold=-65dB:start_silence=0.16:detection=peak,areverse',
    '-ac', '1', '-ar', '22050', '-c:a', 'pcm_s16le', '-map_metadata', '-1',
    '-fflags', '+bitexact', destination
  ], bytes);
  assertWave(fs.readFileSync(destination), 22050);
}

async function generateVoices({
  root = path.resolve(__dirname, '..'),
  key = process.env.SPEECH_KEY,
  region = process.env.SPEECH_REGION,
  onlyMissing = false,
  fetchImpl = fetch,
  wait = sleep
} = {}) {
  if (typeof key !== 'string' || !key.trim()) throw new Error('Set SPEECH_KEY before generating speech.');
  if (typeof region !== 'string' || !/^[a-z0-9]+$/.test(region)) {
    throw new Error('Set SPEECH_REGION to an Azure Speech region such as eastasia.');
  }
  let messages = messagesFor(root);
  const output = path.join(root, 'assets', 'audio', 'voice');
  for (const { id } of messages) {
    const destination = path.join(output, `${id}.wav`);
    if (fs.existsSync(destination) && !fs.lstatSync(destination).isFile()) {
      throw new Error(`Voice destination is not a regular file: ${destination}`);
    }
    if (fs.existsSync(path.join(output, `${id}.generating.wav`))) {
      throw new Error(`Unexplained pending voice output exists for ${id}; inspect it before regenerating.`);
    }
  }
  if (onlyMissing) messages = messages.filter(({ id }) => !fs.existsSync(path.join(output, `${id}.wav`)));
  if (messages.length === 0) return 0;
  ffmpeg(['-version']);
  const base = `https://${region}.tts.speech.microsoft.com/cognitiveservices`;
  const headers = { 'Ocp-Apim-Subscription-Key': key, 'User-Agent': 'WordBuddies-VoiceGenerator' };
  async function request(url, options, label) {
    const response = await fetchImpl(url, {
      ...options, redirect: 'error', signal: AbortSignal.timeout(30000)
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error(`Speech request for ${label} failed (HTTP ${response.status}). Existing recordings were not replaced.`);
    }
    return response;
  }
  const voices = await (await request(`${base}/voices/list`, { headers }, 'voice availability')).json();
  if (!Array.isArray(voices) || !voices.some(voice =>
    voice.ShortName === PROFILE.voice && voice.VoiceType === 'Neural' &&
    voice.Locale === 'en-US' && voice.StyleList?.includes(PROFILE.style))) {
    throw new Error(`${PROFILE.voice} with the friendly style is unavailable in ${region}. No fallback voice will be used.`);
  }
  const build = path.join(root, 'build');
  fs.mkdirSync(build, { recursive: true });
  const staging = fs.mkdtempSync(path.join(build, 'voice-generation-'));
  try {
    for (const message of messages) {
      // F0 allows 20 transactions per minute; leave headroom for the voice-list request.
      await wait(3200);
      const response = await request(`${base}/v1`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/ssml+xml', 'X-Microsoft-OutputFormat': PROFILE.format },
        body: speechMarkup(message.text)
      }, message.id);
      const bytes = Buffer.from(await response.arrayBuffer());
      const pending = path.join(staging, `${message.id}.wav`);
      convertVoice(bytes, pending);
    }
    // Keep the old voice intact if any synthesis or conversion in the batch fails.
    fs.mkdirSync(output, { recursive: true });
    for (const { id } of messages) {
      fs.renameSync(path.join(staging, `${id}.wav`), path.join(output, `${id}.wav`));
    }
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
  return messages.length;
}

if (require.main === module) {
  generateVoices({ onlyMissing: process.argv.includes('--missing') }).then(count => {
    console.log(`Generated ${count} English recordings with ${PROFILE.voice}, ${PROFILE.style} style (${PROFILE.rate}, 22050 Hz PCM16 mono).`);
  }).catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = { PROFILE, speechMarkup, messagesFor, assertWave, convertVoice, generateVoices };
