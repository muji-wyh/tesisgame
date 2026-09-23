/* Local-only inference worker. No microphone samples leave this worker. */
(function (scope) {
  'use strict';
  const RATE = 16000;
  const MODEL_FILES = {
    encoder: '/encoder.onnx', decoder: '/decoder.onnx', joiner: '/joiner.onnx',
    tokens: '/tokens.txt', speaker: '/speaker.onnx', vad: '/silero_vad.onnx'
  };

  function wordsFromResult(result, segmentStartMs, segmentEndMs) {
    const words = [];
    const tokens = result.tokens;
    const times = result.timestamps;
    if (Array.isArray(tokens) && Array.isArray(times) && tokens.length === times.length) {
      let beginsWord = true;
      for (let i = 0; i < tokens.length; i++) {
        const token = String(tokens[i]);
        if (/^<.*>$/.test(token)) continue;
        const startsWord = /^[▁\s]/.test(token);
        if (startsWord) beginsWord = true;
        const letters = token.replace(/▁/g, ' ').replace(/[^a-zA-Z' ]/g, '').trim().toLowerCase();
        if (!letters) continue;
        if (!Number.isFinite(times[i]) || times[i] < 0) return [];
        if (beginsWord || !words.length) {
          words.push({ text: letters, startMs: segmentStartMs + times[i] * 1000 });
        } else words[words.length - 1].text += letters;
        beginsWord = false;
      }
    } else {
      // A transcript without token timings cannot safely assign several words
      // to historical targets. A single VAD-bounded word remains usable.
      const text = String(result.text || '').toLowerCase().trim();
      if (/^[a-z]+(?:'[a-z]+)?$/.test(text)) words.push({ text, startMs: segmentStartMs });
    }
    return words.map((word, i) => ({
      text: word.text,
      startMs: word.startMs,
      endMs: Math.min(segmentEndMs, i + 1 < words.length ? words[i + 1].startMs : segmentEndMs)
    })).filter((word) => word.startMs >= segmentStartMs && word.startMs < segmentEndMs && word.endMs > word.startMs);
  }

  function voicedBounds(samples) {
    const frameSize = 160; // 10 ms acoustic bounds, independent of ASR latency.
    const rms = [];
    let peak = 0;
    for (let offset = 0; offset < samples.length; offset += frameSize) {
      let squared = 0;
      const end = Math.min(samples.length, offset + frameSize);
      for (let i = offset; i < end; i++) squared += samples[i] * samples[i];
      const value = Math.sqrt(squared / (end - offset));
      rms.push(value);
      peak = Math.max(peak, value);
    }
    const threshold = Math.max(0.003, peak * 0.08);
    const first = rms.findIndex((value) => value >= threshold);
    if (first < 0) return null;
    let last = rms.length - 1;
    while (rms[last] < threshold) last--;
    return { start: first * frameSize, end: Math.min(samples.length, (last + 1) * frameSize) };
  }

  class VoicePopInference {
    constructor(send, loadRuntime) {
      this.send = send;
      this.loadRuntime = loadRuntime;
      this.module = null;
      this.ready = false;
      this.sessionId = null;
      this.timeOffsetMs = 0;
      this.sampleCount = 0;
      this.eventSequence = 0;
      this.pointer = 0;
      this.capacity = 0;
      this.audioBuffer = null;
    }

    async init({ assets, runtime }) {
      if (this.module || this.ready) throw new Error('The local runtime is already initialized.');
      if (!assets || !runtime) throw new Error('Missing local model assets.');
      const module = await this.loadRuntime(assets, runtime);
      this.module = module;
      for (const [id, file] of Object.entries(MODEL_FILES)) {
        if (!(assets[id] instanceof ArrayBuffer) || !assets[id].byteLength) throw new Error(`Missing model: ${id}`);
        if (runtime.modelFiles?.[id] !== file) throw new Error(`Unsupported model location: ${id}`);
        module.FS.writeFile(file, new Uint8Array(assets[id]));
      }
      if (module._vp_create() !== 1) throw new Error('The local speech models could not be opened.');
      // Loaded sessions own their weights. Release MEMFS copies immediately.
      Object.values(MODEL_FILES).forEach((file) => module.FS.unlink(file));

      // Exercise all three actual inference paths before reporting ready.
      const silence = new Float32Array(RATE);
      this.copy(silence);
      for (let i = 0; i < RATE; i += 512) module._vp_accept(this.pointer + i * 4, Math.min(512, RATE - i));
      const result = JSON.parse(module.UTF8ToString(module._vp_transcribe(this.pointer, silence.length)));
      if (typeof result.text !== 'string') throw new Error('Speech recognition warm-up failed.');
      const tone = Float32Array.from({ length: RATE }, (_, i) => 0.025 * Math.sin(i * 2 * Math.PI * 173 / RATE));
      this.copy(tone);
      const dim = module._vp_embed(this.pointer, tone.length);
      if (dim !== 256) throw new Error('Speaker recognition warm-up failed.');
      const values = module.HEAPF32.subarray(module._vp_embedding() / 4, module._vp_embedding() / 4 + dim);
      if (!Array.from(values).every(Number.isFinite)) throw new Error('Speaker recognition returned invalid values.');
      module._vp_reset();
      this.clearAudio();
      this.ready = true;
      this.send({ type: 'ready', sampleRate: RATE, embeddingDimensions: dim });
    }

    copy(samples) {
      if (samples.length > this.capacity) {
        if (this.pointer) {
          this.module.HEAPF32.fill(0, this.pointer / 4, this.pointer / 4 + this.capacity);
          this.module._free(this.pointer);
        }
        this.capacity = Math.max(samples.length, RATE);
        this.pointer = this.module._malloc(this.capacity * 4);
        if (!this.pointer) throw new Error('Not enough memory for local speech recognition.');
      }
      this.module.HEAPF32.set(samples, this.pointer / 4);
    }

    clearAudio() {
      if (this.pointer && this.module) this.module.HEAPF32.fill(0, this.pointer / 4, this.pointer / 4 + this.capacity);
      if (this.audioBuffer) this.audioBuffer.fill(0);
      this.audioBuffer = null;
    }

    start({ sessionId, timeOffsetMs = 0, maxTimeMs = 30000 }) {
      if (!this.ready) throw new Error('Local speech recognition is not ready.');
      if (typeof sessionId !== 'string' || !sessionId) throw new Error('Missing speech session ID.');
      if (!Number.isFinite(timeOffsetMs) || timeOffsetMs < 0 || timeOffsetMs >= maxTimeMs) throw new Error('Invalid round clock.');
      this.module._vp_reset();
      this.clearAudio();
      this.sessionId = sessionId;
      this.timeOffsetMs = timeOffsetMs;
      this.maxTimeMs = Math.min(30000, maxTimeMs);
      this.sampleCount = 0;
      this.eventSequence = 0;
      this.audioBuffer = new Float32Array(Math.floor((this.maxTimeMs - timeOffsetMs) * RATE / 1000));
      this.send({ type: 'started', sessionId });
    }

    audio({ sessionId, samples, sampleOffset }) {
      if (sessionId !== this.sessionId || !this.sessionId) return;
      if (!(samples instanceof Float32Array) || !Number.isSafeInteger(sampleOffset) || sampleOffset < 0) {
        throw new Error('Invalid microphone packet.');
      }
      if (sampleOffset < this.sampleCount) return; // Duplicate packets cannot score twice.
      const limit = Math.floor((this.maxTimeMs - this.timeOffsetMs) * RATE / 1000);
      if (this.sampleCount >= limit) return;
      if (sampleOffset !== this.sampleCount) throw new Error('Microphone audio was interrupted.');
      samples = samples.subarray(0, Math.max(0, limit - this.sampleCount));
      for (const value of samples) if (!Number.isFinite(value)) throw new Error('Invalid microphone samples.');
      if (!samples.length) return;
      this.audioBuffer.set(samples, this.sampleCount);
      this.copy(samples);
      this.module._vp_accept(this.pointer, samples.length);
      this.sampleCount += samples.length;
      this.drain();
    }

    drain() {
      const module = this.module;
      let count;
      while ((count = module._vp_front()) > 0) {
        try {
          const start = module._vp_segment_start();
          const pointer = module._vp_segment_samples();
          const startMs = this.timeOffsetMs + start * 1000 / RATE;
          const endMs = Math.min(this.maxTimeMs, this.timeOffsetMs + Math.min(start + count, this.sampleCount) * 1000 / RATE);
          // VAD clips can shave off an initial consonant. Preserve 200 ms of
          // actual captured context on each side for ASR, while embeddings and
          // scoring remain bounded by the detected speech segment.
          const contextStart = Math.max(0, start - 3200);
          const contextEnd = Math.min(this.sampleCount, start + count + 3200);
          this.copy(this.audioBuffer.subarray(contextStart, contextEnd));
          const result = JSON.parse(module.UTF8ToString(module._vp_transcribe(this.pointer, contextEnd - contextStart)));
          if (!String(result.text || '').trim()) continue;
          const contextStartMs = this.timeOffsetMs + contextStart * 1000 / RATE;
          const contextEndMs = this.timeOffsetMs + contextEnd * 1000 / RATE;
          let words = wordsFromResult(result, contextStartMs, contextEndMs).filter((word) => word.startMs >= startMs);
          if (words.length === 1) {
            // A transducer timestamp marks token emission, often at the end of
            // an isolated word. Use observed PCM onset/end for single-word
            // scoring, after proving that the token lies in captured audio.
            // A token emitted only in the synthetic ASR tail is still rejected.
            const bounds = voicedBounds(module.HEAPF32.subarray(pointer / 4,
              pointer / 4 + Math.min(count, this.sampleCount - start)));
            if (!bounds) continue;
            words[0].startMs = startMs + bounds.start * 1000 / RATE;
            words[0].endMs = Math.min(endMs, startMs + bounds.end * 1000 / RATE);
          } else {
            words = wordsFromResult(result, contextStartMs, endMs).filter((word) => word.startMs >= startMs);
          }
          if (!words.length) continue;
          // VAD silence boundaries are not speaker boundaries. Adjacent words
          // may come from different players even without overlapping speech.
          // Use disjoint token-aligned clips, allowing 100 ms before token
          // emission. Never reuse a mixed-segment voice vector for every word.
          const boundaries = [0, ...words.slice(1).map((word) => Math.max(0,
            Math.min(count, Math.floor((word.startMs - startMs) * RATE / 1000) - 1600))), count];
          for (let i = 0; i < words.length; i++) {
            const clipStart = boundaries[i];
            const clipLength = boundaries[i + 1] - clipStart;
            if (clipLength < 2560) continue; // Under 160 ms cannot provide a useful voice sample.
            const dim = module._vp_embed(pointer + clipStart * 4, clipLength);
            if (dim !== 256) continue;
            const embeddingPointer = module._vp_embedding();
            const embedding = Array.from(module.HEAPF32.subarray(embeddingPointer / 4, embeddingPointer / 4 + dim));
            if (!embedding.every(Number.isFinite)) throw new Error('Speaker recognition produced invalid output.');
            this.send({ type: 'utterance', sessionId: this.sessionId,
              eventId: `${this.sessionId}:${++this.eventSequence}`, ...words[i], embedding });
          }
        } finally {
          module._vp_pop();
        }
      }
    }

    flush({ sessionId }) {
      if (sessionId !== this.sessionId || !sessionId) return;
      // Silero consumes 512-sample windows. Complete only the final analysis
      // window; sampleCount stays at the true recording end for event bounds.
      const padding = (512 - this.sampleCount % 512) % 512;
      if (padding) {
        this.copy(new Float32Array(padding));
        this.module._vp_accept(this.pointer, padding);
      }
      this.module._vp_flush();
      this.drain();
      this.send({ type: 'flushed', sessionId });
      this.sessionId = null;
      this.module._vp_reset();
      this.clearAudio();
    }

    stop({ sessionId }) {
      if (sessionId && sessionId !== this.sessionId) return;
      this.sessionId = null;
      if (this.module && this.ready) this.module._vp_reset();
      this.clearAudio();
    }
  }

  async function loadRuntime(assets, runtime) {
    if (!(assets[runtime.scriptId] instanceof ArrayBuffer) || !(assets[runtime.wasmId] instanceof ArrayBuffer)) {
      throw new Error('Missing local inference runtime.');
    }
    const script = URL.createObjectURL(new Blob([assets[runtime.scriptId]], { type: 'text/javascript' }));
    try { scope.importScripts(script); } finally { URL.revokeObjectURL(script); }
    if (typeof scope.VoicePopSherpa !== 'function') throw new Error('Invalid local inference runtime.');
    return scope.VoicePopSherpa({
      wasmBinary: new Uint8Array(assets[runtime.wasmId]),
      noInitialRun: true,
      print: () => {},
      printErr: () => {}
    });
  }

  if (typeof scope.importScripts === 'function') {
    const engine = new VoicePopInference((message) => scope.postMessage(message), loadRuntime);
    let sequence = Promise.resolve();
    scope.onmessage = ({ data }) => {
      sequence = sequence.then(async () => {
        switch (data.type) {
          case 'init': await engine.init(data); break;
          case 'start': engine.start(data); break;
          case 'audio': engine.audio(data); break;
          case 'flush': engine.flush(data); break;
          case 'stop': engine.stop(data); break;
          case 'ping': scope.postMessage({ type: 'pong', requestId: data.requestId, ready: engine.ready }); break;
          default: throw new Error('Unknown local speech command.');
        }
      }).catch((error) => {
        engine.stop({});
        scope.postMessage({ type: 'error', message: error.message || String(error), sessionId: data.sessionId });
      });
    };
  }
  if (typeof module === 'object' && module.exports) module.exports = { VoicePopInference, wordsFromResult, voicedBounds, MODEL_FILES };
})(typeof self === 'object' ? self : globalThis);
