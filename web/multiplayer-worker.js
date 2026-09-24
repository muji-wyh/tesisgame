/* Local-only inference worker. No microphone samples leave this worker. */
(function (scope) {
  'use strict';
  const RATE = 16000;
  const SPEAKER_MODEL_VERSION = 'wespeaker-en-voxceleb-resnet34-lm:e9848563da86f263117134dfd7ad63c92355b37de492b55e325400c9d9c39012';
  const ENROLLMENT = Object.freeze({ requiredSegments: 3, requiredVoicedMs: 12000,
    minimumSegmentMs: 700, consistencyThreshold: 0.45 });
  const IDENTIFICATION = Object.freeze({ requiredSegments: 2, requiredVoicedMs: 4000,
    minimumSegmentMs: 700, consistencyThreshold: 0.45 });
  const MODEL_FILES = {
    encoder: '/encoder.onnx', decoder: '/decoder.onnx', joiner: '/joiner.onnx',
    tokens: '/tokens.txt', bpe: '/bpe.vocab', speaker: '/speaker.onnx', vad: '/silero_vad.onnx'
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

  function speechFrames(samples) {
    const frames = [];
    let peak = 0;
    for (let start = 0; start < samples.length; start += 160) {
      const end = Math.min(samples.length, start + 160);
      let energy = 0, clipped = 0;
      for (let i = start; i < end; i++) {
        energy += samples[i] * samples[i];
        if (Math.abs(samples[i]) >= 0.98) clipped++;
      }
      const rms = Math.sqrt(energy / (end - start));
      frames.push({ start, end, rms, clipped });
      peak = Math.max(peak, rms);
    }
    // VAD establishes speech; this second, deliberately conservative gate only
    // estimates useful 10 ms frames. Internal pauses never add recording credit.
    const sorted = frames.map(frame => frame.rms).sort((a, b) => a - b);
    const noiseFloor = Math.min(sorted[Math.floor(sorted.length * 0.2)] || 0, peak * 0.15);
    const threshold = Math.max(0.005, peak * 0.08, noiseFloor * 2.5);
    const active = frames.filter(frame => frame.rms >= threshold);
    const activeSamples = active.reduce((sum, frame) => sum + frame.end - frame.start, 0);
    return { start: active[0]?.start || 0, end: active.at(-1)?.end || 0,
      voicedMs: activeSamples / 16,
      peak, clipping: activeSamples ? active.reduce((sum, frame) => sum + frame.clipped, 0) / activeSamples : 0,
      frames: active };
  }

  const cosine = (a, b) => a.reduce((sum, value, i) => sum + value * b[i], 0);
  const median = values => {
    const sorted = [...values].sort((a, b) => a - b), middle = Math.floor(sorted.length / 2);
    return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
  };
  function medoid(vectors) {
    return vectors.reduce((best, vector) => {
      const score = median(vectors.map(other => cosine(vector, other)));
      return !best || score > best.score ? { vector, score } : best;
    }, null)?.vector;
  }
  function averageVoice(segments) {
    const vector = new Array(256).fill(0);
    for (const segment of segments) segment.embedding.forEach((value, i) => {
      vector[i] += value * Math.min(segment.voicedMs, 6000);
    });
    const norm = Math.hypot(...vector);
    for (let i = 0; i < vector.length; i++) vector[i] /= norm;
    return vector;
  }
  function voiceTemplates(vectors) {
    const remaining = [...vectors].sort((a, b) => b.voicedMs - a.voicedMs), selected = [];
    while (remaining.length && selected.length < 8) {
      let index = 0;
      if (selected.length) {
        const similarities = remaining.map(value => Math.max(...selected.map(other => cosine(value.embedding, other))));
        index = similarities.indexOf(Math.min(...similarities));
        if (similarities[index] > 0.9999) break;
      }
      selected.push(remaining.splice(index, 1)[0].embedding);
    }
    return selected.map(vector => [...vector]);
  }

  const QUALITY_MESSAGES = Object.freeze({
    too_quiet: 'The sample is too quiet. Move a little closer and speak in your normal voice.',
    clipping: 'The microphone is clipping. Move a little farther away and speak at a comfortable volume.',
    insufficient_speech: 'Say a longer sentence in your normal voice, then pause.',
    inconsistent_sample: 'That sample was not consistent enough. Keep one person speaking and try another sentence.'
  });

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
      this.enrollment = null;
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
      this.setVocabulary(['cat']);
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

    setVocabulary(vocabulary) {
      // Only canonical English nouns enter the native hotword syntax. Slashes,
      // colons and other syntax cannot inject phrases or change bias scores.
      const words = [...new Set((Array.isArray(vocabulary) ? vocabulary : []).slice(0, 512)
        .filter(word => typeof word === 'string')
        .map(word => word.trim().toUpperCase())
        .filter(word => word.length <= 64 && /^[A-Z]+(?:[ -][A-Z]+)*$/.test(word)))];
      if (!words.length) return;
      const text = `${words.join('\n')}\0`;
      const pointer = this.module._malloc(text.length);
      if (!pointer) throw new Error('Not enough memory for speech vocabulary.');
      try {
        const bytes = new Uint8Array(this.module.HEAPF32.buffer, pointer, text.length);
        for (let i = 0; i < text.length; i++) bytes[i] = text.charCodeAt(i);
        this.module._vp_set_vocabulary(pointer);
      } finally {
        new Uint8Array(this.module.HEAPF32.buffer, pointer, text.length).fill(0);
        this.module._free(pointer);
      }
    }

    start({ sessionId, timeOffsetMs = 0, maxTimeMs = 30000, mode = 'game', vocabulary = [] }) {
      if (!this.ready) throw new Error('Local speech recognition is not ready.');
      if (typeof sessionId !== 'string' || !sessionId) throw new Error('Missing speech session ID.');
      if (!['game', 'enrollment', 'identification'].includes(mode)) throw new Error('Invalid microphone session mode.');
      if (!Number.isFinite(maxTimeMs) || maxTimeMs <= 0) throw new Error('Invalid recording duration.');
      maxTimeMs = Math.min(mode === 'enrollment' ? 60000 : 30000, maxTimeMs);
      if (!Number.isFinite(timeOffsetMs) || timeOffsetMs < 0 || timeOffsetMs >= maxTimeMs) throw new Error('Invalid round clock.');
      this.module._vp_reset();
      if (mode === 'game') this.setVocabulary(vocabulary);
      this.clearAudio();
      this.sessionId = sessionId;
      this.timeOffsetMs = timeOffsetMs;
      this.maxTimeMs = maxTimeMs;
      this.sampleCount = 0;
      this.eventSequence = 0;
      this.clearEnrollment();
      if (mode !== 'game') this.enrollment = { mode, requirements: mode === 'identification' ? IDENTIFICATION : ENROLLMENT,
        segments: 0, voicedMs: 0, vectors: [], turns: [], groups: [], confirmed: null,
        minimumSimilarity: 1, rejectedSegments: 0, rejectionReasons: {}, reason: '',
        lastEnd: -Infinity, turnId: 0, contaminatedTurns: new Set() };
      this.audioBuffer = new Float32Array(Math.floor((this.maxTimeMs - timeOffsetMs) * RATE / 1000));
      this.send({ type: 'started', sessionId });
    }

    feedback(text, startMs, endMs, reason) {
      // Feedback is a terminal, non-scoring alternative to an utterance. It
      // never changes listening state or invents a timestamp in an ASR tail.
      if (!this.sessionId || !Number.isFinite(startMs) || !Number.isFinite(endMs) || endMs <= startMs) return;
      this.send({ type: 'feedback', sessionId: this.sessionId,
        eventId: `${this.sessionId}:${++this.eventSequence}`, text, startMs, endMs, reason });
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
          if (this.enrollment) {
            this.enrollSegment(pointer, Math.min(count, this.sampleCount - start), start);
            if (this.enrollment.failure || this.enrollment.mode === 'identification' && this.enrollmentCanFinish()) break;
            continue;
          }
          const capturedCount = Math.max(0, Math.min(count, this.sampleCount - start));
          const startMs = this.timeOffsetMs + start * 1000 / RATE;
          const endMs = Math.min(this.maxTimeMs, this.timeOffsetMs + (start + capturedCount) * 1000 / RATE);
          // VAD clips can shave off an initial consonant. Preserve 200 ms of
          // actual captured context on each side for ASR, while embeddings and
          // scoring remain bounded by the detected speech segment.
          const contextStart = Math.max(0, start - 3200);
          const contextEnd = Math.min(this.sampleCount, start + count + 3200);
          this.copy(this.audioBuffer.subarray(contextStart, contextEnd));
          const result = JSON.parse(module.UTF8ToString(module._vp_transcribe(this.pointer, contextEnd - contextStart)));
          const text = String(result.text || '').trim();
          if (!text) { this.feedback('', startMs, endMs, 'unclear_speech'); continue; }
          const contextStartMs = this.timeOffsetMs + contextStart * 1000 / RATE;
          const contextEndMs = this.timeOffsetMs + contextEnd * 1000 / RATE;
          let words = wordsFromResult(result, contextStartMs, contextEndMs).filter((word) => word.startMs >= startMs);
          if (words.length === 1) {
            // A transducer timestamp marks token emission, often at the end of
            // an isolated word. Use observed PCM onset/end for single-word
            // scoring, after proving that the token lies in captured audio.
            // A token emitted only in the synthetic ASR tail is still rejected.
            const bounds = voicedBounds(module.HEAPF32.subarray(pointer / 4,
              pointer / 4 + capturedCount));
            if (!bounds) { this.feedback(text, startMs, endMs, 'identity_unconfirmed'); continue; }
            words[0].startMs = startMs + bounds.start * 1000 / RATE;
            words[0].endMs = Math.min(endMs, startMs + bounds.end * 1000 / RATE);
          } else {
            words = wordsFromResult(result, contextStartMs, endMs).filter((word) => word.startMs >= startMs);
          }
          if (!words.length) { this.feedback(text, startMs, endMs, 'timing_unavailable'); continue; }
          // VAD silence boundaries are not speaker boundaries. Adjacent words
          // may come from different players even without overlapping speech.
          // Use disjoint token-aligned clips, allowing 100 ms before token
          // emission. Never reuse a mixed-segment voice vector for every word.
          const boundaries = [0, ...words.slice(1).map((word) => Math.max(0,
            Math.min(capturedCount, Math.floor((word.startMs - startMs) * RATE / 1000) - 1600))), capturedCount];
          for (let i = 0; i < words.length; i++) {
            const clipStart = boundaries[i];
            const clipLength = boundaries[i + 1] - clipStart;
            const unconfirmed = () => this.feedback(words[i].text, words[i].startMs, words[i].endMs, 'identity_unconfirmed');
            if (clipLength < 2560) { unconfirmed(); continue; } // Under 160 ms cannot provide a useful voice sample.
            const dim = module._vp_embed(pointer + clipStart * 4, clipLength);
            if (dim !== 256) { unconfirmed(); continue; }
            const embeddingPointer = module._vp_embedding();
            const embedding = Array.from(module.HEAPF32.subarray(embeddingPointer / 4, embeddingPointer / 4 + dim));
            const norm = Math.hypot(...embedding);
            if (!embedding.every(Number.isFinite) || !Number.isFinite(norm) || norm < 1e-8) {
              embedding.fill(0); unconfirmed(); continue;
            }
            this.send({ type: 'utterance', sessionId: this.sessionId,
              eventId: `${this.sessionId}:${++this.eventSequence}`, ...words[i], embedding });
          }
        } finally {
          module._vp_pop();
        }
        if (this.enrollment?.failure) break;
      }
      if (this.enrollment?.failure || this.enrollment?.mode === 'identification' && this.enrollmentCanFinish())
        this.finishEnrollmentResult();
    }

    enrollmentCanFinish() {
      const sample = this.enrollment;
      return !!sample && sample.segments >= sample.requirements.requiredSegments && sample.voicedMs >= sample.requirements.requiredVoicedMs;
    }

    enrollmentQuality() {
      const sample = this.enrollment;
      return { segments: sample.segments, voicedMs: sample.voicedMs,
        minimumSimilarity: sample.minimumSimilarity, rejectedSegments: sample.rejectedSegments,
        reason: sample.reason, rejectionReasons: { ...sample.rejectionReasons } };
    }

    enrollmentProgress() {
      const sample = this.enrollment;
      const requirements = sample.requirements;
      this.send({ type: `${sample.mode}-progress`, sessionId: this.sessionId,
        ...this.enrollmentQuality(),
        requiredSegments: requirements.requiredSegments, requiredVoicedMs: requirements.requiredVoicedMs,
        progress: Math.min(1, sample.segments / requirements.requiredSegments, sample.voicedMs / requirements.requiredVoicedMs),
        canFinish: this.enrollmentCanFinish(),
        message: QUALITY_MESSAGES[sample.reason] || '' });
    }

    rejectSegment(reason) {
      const sample = this.enrollment;
      sample.rejectedSegments++;
      sample.rejectionReasons[reason] = (sample.rejectionReasons[reason] || 0) + 1;
      sample.reason = reason;
      this.enrollmentProgress();
    }

    discardTurn(turn) {
      turn.embedding.fill(0);
      turn.vectors.forEach(value => value.embedding.fill(0));
    }

    syncEnrollment() {
      const sample = this.enrollment;
      const selected = sample.confirmed || [...sample.groups].sort((a, b) => b.turns.length - a.turns.length)[0];
      sample.turns = selected?.turns || [];
      sample.vectors = sample.turns.flatMap(turn => turn.vectors);
      sample.segments = sample.turns.length;
      sample.voicedMs = sample.turns.reduce((sum, turn) => sum + turn.voicedMs, 0);
      sample.minimumSimilarity = 1;
      for (let i = 0; i < sample.turns.length; i++) for (let j = 0; j < i; j++)
        sample.minimumSimilarity = Math.min(sample.minimumSimilarity, cosine(sample.turns[i].embedding, sample.turns[j].embedding));
    }

    compatibleSample(embedding, group) {
      const vectors = group.turns.map(turn => turn.embedding);
      const reference = group.reference || medoid(vectors);
      return cosine(embedding, reference) >= this.enrollment.requirements.consistencyThreshold &&
        median(vectors.map(vector => cosine(embedding, vector))) >= this.enrollment.requirements.consistencyThreshold;
    }

    readVoice(pointer, count) {
      const dimension = this.module._vp_embed(pointer, count);
      if (dimension === 256) {
        const offset = this.module._vp_embedding() / 4;
        const vector = Array.from(this.module.HEAPF32.subarray(offset, offset + dimension));
        const norm = Math.hypot(...vector);
        if (vector.every(Number.isFinite) && Number.isFinite(norm) && norm >= 1e-8) {
          for (let i = 0; i < vector.length; i++) vector[i] /= norm;
          return vector;
        }
        vector.fill(0);
      }
      this.enrollment.failure = { code: 'invalid_voice_sample', message: 'The voice sample could not be analyzed. Please try again.' };
      return null;
    }

    enrollSegment(pointer, count, start) {
      const sample = this.enrollment;
      if (sample.failure) return;
      const pcm = this.module.HEAPF32.subarray(pointer / 4, pointer / 4 + Math.max(0, count));
      const speech = speechFrames(pcm), length = speech.end - speech.start;
      // Silero may split a long uninterrupted utterance at its maximum length.
      // Only a gap of at least 200 ms between VAD clips starts another turn;
      // amplitude dips inside adjacent forced chunks cannot manufacture turns.
      if (start - sample.lastEnd >= RATE * 0.2) sample.turnId++;
      sample.lastEnd = start + count;
      if (sample.contaminatedTurns.has(sample.turnId)) { this.rejectSegment('inconsistent_sample'); return; }
      if (speech.peak < 0.005) { this.rejectSegment('too_quiet'); return; }
      if (speech.clipping > 0.1) { this.rejectSegment('clipping'); return; }
      if (speech.voicedMs < sample.requirements.minimumSegmentMs) { this.rejectSegment('insufficient_speech'); return; }

      // Embed natural contiguous audio, including its internal pauses. Active
      // frame counting must never splice phonemes together for the voice model.
      const embedding = this.readVoice(pointer + speech.start * 4, length);
      if (!embedding) return;
      const next = { embedding, voicedMs: speech.voicedMs, turnId: sample.turnId,
        vectors: [{ embedding, voicedMs: speech.voicedMs }] };
      const windowCount = Math.floor(length / (RATE * 2));
      const windows = [];
      for (let index = 0; windowCount >= 2 && index < windowCount; index++) {
        const from = speech.start + Math.floor(length * index / windowCount);
        const to = speech.start + Math.floor(length * (index + 1) / windowCount);
        const voicedMs = speech.frames.reduce((sum, frame) => sum + Math.max(0,
          Math.min(to, frame.end) - Math.max(from, frame.start)) / 16, 0);
        if (voicedMs < sample.requirements.minimumSegmentMs) continue;
        const vector = this.readVoice(pointer + from * 4, to - from);
        if (!vector) { this.discardTurn(next); return; }
        windows.push(vector);
        next.vectors.push({ embedding: vector, voicedMs });
      }
      const reference = medoid(windows);
      if (reference && (windows.some(vector => cosine(vector, reference) < sample.requirements.consistencyThreshold) ||
          cosine(embedding, reference) < sample.requirements.consistencyThreshold)) {
        this.discardTurn(next);
        this.rejectSegment('inconsistent_sample');
        return;
      }

      const sameTurn = sample.groups.find(group => group.turns.some(turn => turn.turnId === next.turnId));
      if (sameTurn) {
        const previous = sameTurn.turns.find(turn => turn.turnId === next.turnId);
        if (!this.compatibleSample(embedding, sameTurn)) {
          sameTurn.turns.splice(sameTurn.turns.indexOf(previous), 1);
          this.discardTurn(previous);
          this.discardTurn(next);
          sample.contaminatedTurns.add(next.turnId);
          if (sameTurn.reference) {
            sameTurn.reference.fill(0);
            sameTurn.reference = sameTurn.turns.length ? [...medoid(sameTurn.turns.map(turn => turn.embedding))] : null;
          }
          if (!sameTurn.turns.length) {
            sample.groups.splice(sample.groups.indexOf(sameTurn), 1);
            if (sample.confirmed === sameTurn) sample.confirmed = null;
          }
          this.syncEnrollment();
          this.rejectSegment('inconsistent_sample');
          return;
        }
        const combined = averageVoice([previous, next]);
        // Older aggregates are not retained as templates after another merge.
        if (!previous.vectors.some(value => value.embedding === previous.embedding)) previous.embedding.fill(0);
        previous.embedding = combined;
        previous.voicedMs += next.voicedMs;
        previous.vectors.push(...next.vectors);
      } else {
        let group = sample.groups.find(candidate => this.compatibleSample(embedding, candidate));
        if (!group && sample.confirmed) {
          this.discardTurn(next);
          this.rejectSegment('inconsistent_sample');
          return;
        }
        if (!group) {
          // Before two independent turns agree, keep a few competing seeds.
          // This lets a first noisy/outlier turn lose to a later consistent pair.
          if (sample.groups.length >= 3) {
            const discarded = sample.groups.pop();
            discarded.turns.forEach(turn => this.discardTurn(turn));
          }
          group = { turns: [] };
          sample.groups.push(group);
        }
        group.turns.push(next);
        if (!sample.confirmed && group.turns.length >= 2) {
          sample.confirmed = group;
          group.reference = [...medoid(group.turns.map(turn => turn.embedding))];
          for (const other of sample.groups) if (other !== group) {
            sample.rejectedSegments += other.turns.length;
            sample.rejectionReasons.inconsistent_sample = (sample.rejectionReasons.inconsistent_sample || 0) + other.turns.length;
            other.turns.forEach(turn => this.discardTurn(turn));
          }
          sample.groups = [group];
        }
      }
      this.syncEnrollment();
      sample.reason = sample.groups.length > 1 ? 'inconsistent_sample' : '';
      this.enrollmentProgress();
    }

    clearEnrollment() {
      for (const group of this.enrollment?.groups || []) {
        group.turns.forEach(turn => this.discardTurn(turn));
        group.reference?.fill(0);
      }
      this.enrollment = null;
    }

    finishEnrollmentResult() {
      const sample = this.enrollment;
      if (!sample) return;
      const sessionId = this.sessionId;
      let error = sample.failure;
      if (!error && !this.enrollmentCanFinish())
        error = { code: 'insufficient_speech', message: sample.mode === 'identification' ?
          'Not enough clear speech. Say two full sentences with a pause between them, then try again.' :
          'Not enough clear speech. Read longer sentences with a short pause between them, then try again.' };
      let result;
      if (error) result = { type: `${sample.mode}-error`, sessionId, ...error,
        reason: sample.reason || error.code, quality: this.enrollmentQuality() };
      else {
        result = { type: `${sample.mode}-complete`, sessionId, embedding: averageVoice(sample.turns),
          templates: voiceTemplates(sample.vectors),
          segments: sample.turns.map(turn => ({ embedding: [...turn.embedding], voicedMs: turn.voicedMs })),
          modelVersion: SPEAKER_MODEL_VERSION, quality: this.enrollmentQuality() };
      }
      this.stop({ sessionId });
      this.send(result);
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
      if (this.enrollment) { this.finishEnrollmentResult(); return; }
      if (sessionId !== this.sessionId) return;
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
      this.clearEnrollment();
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
        const identification = engine.enrollment?.mode === 'identification' || data.type === 'start' && data.mode === 'identification';
        engine.stop({});
        scope.postMessage({ type: identification ? 'identification-error' : 'error',
          ...(identification ? { code: 'recognition_failed' } : {}), message: error.message || String(error), sessionId: data.sessionId });
      });
    };
  }
  if (typeof module === 'object' && module.exports) module.exports = { VoicePopInference, wordsFromResult, voicedBounds, MODEL_FILES, ENROLLMENT, IDENTIFICATION, SPEAKER_MODEL_VERSION };
})(typeof self === 'object' ? self : globalThis);
