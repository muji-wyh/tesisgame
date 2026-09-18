const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { setTimeout: sleep } = require('node:timers/promises');
const { PROFILE, speechMarkup, convertVoice } = require('./generate-voices.cjs');

const PROMPT_IDS = Object.freeze([
  ...Array.from({ length: 21 }, (_, index) => `round-${index}`),
  ...Array.from({ length: 20 }, (_, index) => `combo-${index + 1}`),
  'highlights-one', 'highlights-two', 'no-highlights', 'practice', 'practice-next',
  'repeat', 'repeat-next', 'ready', 'high-five', 'round-fallback'
]);

function messagesFor(root) {
  const prompts = JSON.parse(fs.readFileSync(path.join(root, 'pop-voice-prompts.json'), 'utf8'));
  if (!prompts || Array.isArray(prompts) || typeof prompts !== 'object' ||
      Object.keys(prompts).length !== PROMPT_IDS.length ||
      PROMPT_IDS.some(id => !Object.hasOwn(prompts, id))) {
    throw new Error(`pop-voice-prompts.json must contain exactly the ${PROMPT_IDS.length} required report prompt IDs.`);
  }
  return PROMPT_IDS.map(id => {
    const text = prompts[id];
    // Reuse the audited ASCII/length validation and complete-sentence SSML.
    speechMarkup(text);
    return { id, text };
  });
}

async function generatePopVoices({
  root = path.resolve(__dirname, '..'),
  key = process.env.SPEECH_KEY,
  region = process.env.SPEECH_REGION,
  onlyMissing = false,
  fetchImpl = fetch,
  wait = sleep
} = {}) {
  if (typeof key !== 'string' || !key.trim()) throw new Error('Set SPEECH_KEY before generating report speech.');
  if (typeof region !== 'string' || !/^[a-z0-9]+$/.test(region)) {
    throw new Error('Set SPEECH_REGION to an Azure Speech region such as eastasia.');
  }
  root = path.resolve(root);
  let messages = messagesFor(root);
  const output = path.join(root, 'assets', 'audio', 'pop');
  for (const { id } of messages) {
    const destination = path.join(output, `${id}.wav`);
    if (fs.existsSync(destination) && !fs.lstatSync(destination).isFile()) {
      throw new Error(`Report voice destination is not a regular file: ${destination}`);
    }
  }
  if (onlyMissing) messages = messages.filter(({ id }) => !fs.existsSync(path.join(output, `${id}.wav`)));
  if (!messages.length) return { count: 0, characters: 0 };
  const toolchain = spawnSync('ffmpeg', ['-version'], { windowsHide: true, timeout: 30000, stdio: 'ignore' });
  if (toolchain.error || toolchain.status !== 0) {
    throw new Error('FFmpeg must be installed and on PATH before generating report recordings.');
  }
  const base = `https://${region}.tts.speech.microsoft.com/cognitiveservices`;
  const headers = { 'Ocp-Apim-Subscription-Key': key, 'User-Agent': 'WordBuddies-PopVoiceGenerator' };
  async function request(url, options, label) {
    const response = await fetchImpl(url, {
      ...options, redirect: 'error', signal: AbortSignal.timeout(30000)
    });
    if (!response.ok) {
      await response.body?.cancel();
      // Never log request headers, credentials, or provider response bodies.
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
  const build = path.resolve(root, 'build');
  fs.mkdirSync(build, { recursive: true });
  const staging = fs.mkdtempSync(path.join(build, 'pop-voice-generation-'));
  const relativeStaging = path.relative(build, path.resolve(staging));
  if (relativeStaging.startsWith('..') || path.isAbsolute(relativeStaging) ||
      path.dirname(relativeStaging) !== '.' || !path.basename(staging).startsWith('pop-voice-generation-')) {
    throw new Error('Report voice staging escaped the workspace build directory.');
  }
  try {
    for (const message of messages) {
      // The existing resource is F0: keep below its 20 transactions/minute limit.
      await wait(3200);
      const response = await request(`${base}/v1`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/ssml+xml', 'X-Microsoft-OutputFormat': PROFILE.format },
        body: speechMarkup(message.text)
      }, message.id);
      const bytes = Buffer.from(await response.arrayBuffer());
      // This validates both the source and converted PCM, including audible samples.
      convertVoice(bytes, path.join(staging, `${message.id}.wav`));
    }
    // A failed synthesis/conversion leaves every previously published clip intact.
    fs.mkdirSync(output, { recursive: true });
    for (const { id } of messages) fs.renameSync(path.join(staging, `${id}.wav`), path.join(output, `${id}.wav`));
  } finally {
    // staging is the verified absolute child created above, never a caller-supplied path.
    fs.rmSync(staging, { recursive: true, force: true });
  }
  return { count: messages.length, characters: messages.reduce((sum, message) => sum + message.text.length, 0) };
}

if (require.main === module) {
  generatePopVoices({ onlyMissing: process.argv.includes('--missing') }).then(({ count, characters }) => {
    console.log(`Generated ${count} report recordings (${characters} source characters) with ${PROFILE.voice}, ${PROFILE.style} style (${PROFILE.rate}, 22050 Hz PCM16 mono).`);
  }).catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = { PROMPT_IDS, messagesFor, generatePopVoices };
