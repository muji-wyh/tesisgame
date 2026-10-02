const fs = require('node:fs');
const path = require('node:path');
const { expect } = require('@playwright/test');
const { observeAudio } = require('./game-ui.cjs');

function watchAudioRequests(page) {
  const requests = [];
  page.on('request', request => {
    const url = new URL(request.url());
    if (!['http:', 'https:'].includes(url.protocol)) return;
    if (request.resourceType() === 'media' || /\.(?:sample|wav|mp3|ogg|m4a|aac|opus|flac)$/i.test(url.pathname) ||
        /\/audio-[^/]+$/i.test(url.pathname)) {
      requests.push({ url: request.url(), type: request.resourceType() });
    }
  });
  return requests;
}

async function observeOutputAudio(page, options = {}) {
  await observeAudio(page, options);
  await page.addInitScript(() => {
    const outputs = new Map();
    window.audioOutputObservation = {
      resumes: [],
      read() {
        return [...outputs].map(([context, analyser]) => {
          const samples = new Float32Array(analyser.fftSize);
          // A suspended analyser can retain its last nonzero waveform. Count
          // only a running context as current rendered output.
          if (context.state === 'running') analyser.getFloatTimeDomainData(samples);
          let sum = 0, peak = 0;
          for (const sample of samples) {
            sum += sample * sample;
            peak = Math.max(peak, Math.abs(sample));
          }
          return { state: context.state, at: performance.now(), time: context.currentTime,
            rms: Math.sqrt(sum / samples.length), peak };
        });
      }
    };
    if (!window.AudioNode) return;
    const Context = window.AudioContext || window.webkitAudioContext;
    if (Context && typeof Context.prototype.resume === 'function') {
      const resume = Context.prototype.resume;
      Context.prototype.resume = function(...args) {
        const attempt = { at: performance.now(), state: this.state, outcome: 'pending' };
        window.audioOutputObservation.resumes.push(attempt);
        let result;
        try {
          result = resume.apply(this, args);
        } catch (error) {
          attempt.outcome = 'rejected';
          attempt.error = error.name;
          throw error;
        }
        return Promise.resolve(result).then(value => {
          attempt.outcome = 'fulfilled';
          attempt.stateAfter = this.state;
          return value;
        }, error => {
          attempt.outcome = 'rejected';
          attempt.error = error.name;
          throw error;
        });
      };
    }
    const connect = AudioNode.prototype.connect;
    const disconnect = AudioNode.prototype.disconnect;
    function output(context) {
      if (!outputs.has(context)) {
        const analyser = context.createAnalyser();
        analyser.fftSize = 2048;
        connect.call(analyser, context.destination);
        outputs.set(context, analyser);
      }
      return outputs.get(context);
    }
    // Insert a transparent analyser only at the actual destination. Preserve
    // every other connection, channel argument and disconnect operation.
    AudioNode.prototype.connect = function(destination, ...channels) {
      if (destination !== this.context.destination) return connect.call(this, destination, ...channels);
      connect.call(this, output(this.context), ...channels);
      return destination;
    };
    AudioNode.prototype.disconnect = function(...args) {
      if (args[0] === this.context.destination && outputs.has(this.context)) args[0] = outputs.get(this.context);
      return disconnect.apply(this, args);
    };
  });
}

async function expectOutputEnergy(page) {
  let output;
  await expect.poll(async () => {
    output = await page.evaluate(() => window.audioOutputObservation.read());
    return Math.max(0, ...output.map(sample => sample.rms));
  }, { message: 'The running WebAudio destination renders nonzero audio', intervals: [25, 50, 100] })
    .toBeGreaterThan(0.00001);
  return output;
}

function waveInfo(relative) {
  const bytes = fs.readFileSync(path.resolve(__dirname, '../..', relative));
  let byteRate, dataSize, sampleRate;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const chunk = bytes.toString('ascii', offset, offset + 4), size = bytes.readUInt32LE(offset + 4);
    if (chunk === 'fmt ') {
      sampleRate = bytes.readUInt32LE(offset + 12);
      byteRate = bytes.readUInt32LE(offset + 16);
    }
    if (chunk === 'data') dataSize = size;
    offset += 8 + size + (size % 2);
  }
  if (!byteRate || !dataSize || !sampleRate) throw new Error(`Invalid WAV: ${relative}`);
  return { seconds: dataSize / byteRate, sampleRate };
}

function waveDuration(relative) {
  return waveInfo(relative).seconds;
}

function recordingTiming(relative) {
  const { seconds, sampleRate } = waveInfo(relative);
  const metadata = fs.readFileSync(path.resolve(__dirname, '../..', `${relative}.import`), 'utf8');
  let importedRate = sampleRate;
  if (/^force\/max_rate=true\r?$/m.test(metadata)) {
    const maximumRate = Number(metadata.match(/^force\/max_rate_hz=(\d+)\r?$/m)?.[1]);
    if (!maximumRate) throw new Error(`Invalid imported sample rate: ${relative}`);
    importedRate = Math.min(sampleRate, maximumRate);
  }
  // Import downsampling can truncate one imported frame. The browser conversion
  // can truncate one output frame too; callers add 1 / playback.sampleRate.
  // The epsilon covers floating-point comparison at the exact frame boundary.
  return { seconds, importAllowance: 1 / importedRate + 1e-9 };
}

async function expectRecording(page, from, relative, { active = false } = {}) {
  const timing = recordingTiming(relative);
  let sound;
  await expect.poll(async () => {
    sound = await page.evaluate(({ from, timing, active }) => window.audioObservation.playbacks.slice(from).findLast(playback =>
      Math.abs(playback.duration - timing.seconds) <= timing.importAllowance + 1 / playback.sampleRate &&
      playback.contextState === 'running' &&
      (!active || (playback.stoppedAt === undefined && playback.endedAt === undefined))), { from, timing, active });
    return Boolean(sound);
  }, { message: `The real browser plays bundled ${relative}` }).toBe(true);
  return sound;
}

module.exports = { watchAudioRequests, observeOutputAudio, expectOutputEnergy, waveDuration, recordingTiming, expectRecording };
