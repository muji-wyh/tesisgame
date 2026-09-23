/* AudioWorklet: mono capture with a streaming, anti-aliasing 16 kHz resampler. */
'use strict';

class VoicePopResampler {
  constructor(inputRate, emit) {
    if (!Number.isFinite(inputRate) || inputRate < 8000) throw new Error('Invalid sample rate');
    this.step = inputRate / 16000;
    this.emit = emit;
    this.position = 0;
    this.inputCount = 0;
    this.outputCount = 0;
    this.bufferStart = 0;
    this.buffer = new Float32Array(0);
    this.packet = new Float32Array(512);
    this.packetLength = 0;
    this.half = 16;
    this.filters = [];
    const cutoff = Math.min(1, 16000 / inputRate) * 0.9;
    for (let phase = 0; phase < 256; phase++) {
      const coefficients = new Float32Array(32);
      let sum = 0;
      for (let j = 0; j < 32; j++) {
        const delta = j - 15 - phase / 256;
        const sinc = Math.abs(delta) < 1e-8 ? cutoff : Math.sin(Math.PI * cutoff * delta) / (Math.PI * delta);
        const window = 0.42 + 0.5 * Math.cos(Math.PI * delta / 16) + 0.08 * Math.cos(2 * Math.PI * delta / 16);
        coefficients[j] = sinc * window;
        sum += coefficients[j];
      }
      for (let j = 0; j < 32; j++) coefficients[j] /= sum;
      this.filters.push(coefficients);
    }
  }

  push(input) {
    const merged = new Float32Array(this.buffer.length + input.length);
    merged.set(this.buffer);
    merged.set(input, this.buffer.length);
    this.buffer = merged;
    this.inputCount += input.length;
    this.consume(false);
  }

  consume(flush) {
    while (this.position < this.inputCount && (flush || Math.floor(this.position) + this.half < this.inputCount)) {
      const center = Math.floor(this.position);
      const filter = this.filters[Math.min(255, Math.floor((this.position - center) * 256))];
      let value = 0;
      for (let j = 0; j < 32; j++) {
        const index = Math.max(0, Math.min(this.inputCount - 1, center - 15 + j));
        value += (this.buffer[index - this.bufferStart] || 0) * filter[j];
      }
      this.packet[this.packetLength++] = Math.max(-1, Math.min(1, value));
      this.outputCount++;
      this.position += this.step;
      if (this.packetLength === this.packet.length) this.send();
    }
    const retainFrom = Math.max(this.bufferStart, Math.floor(this.position) - this.half);
    this.buffer = this.buffer.slice(retainFrom - this.bufferStart);
    this.bufferStart = retainFrom;
  }

  send() {
    if (!this.packetLength) return;
    const samples = this.packet.slice(0, this.packetLength);
    this.emit(samples, this.outputCount - this.packetLength);
    this.packetLength = 0;
  }

  flush() {
    this.consume(true);
    this.send();
  }
}

if (typeof registerProcessor === 'function') {
  class VoicePopCaptureProcessor extends AudioWorkletProcessor {
    constructor() {
      super();
      this.active = true;
      this.resampler = new VoicePopResampler(sampleRate, (samples, sampleOffset) => {
        this.port.postMessage({ type: 'audio', samples, sampleOffset }, [samples.buffer]);
      });
      this.port.onmessage = ({ data }) => {
        if (data.type === 'flush') {
          this.active = false;
          this.resampler.flush();
          this.port.postMessage({ type: 'flushed', requestId: data.requestId });
        } else if (data.type === 'stop') {
          this.active = false;
        }
      };
    }

    process(inputs) {
      if (!this.active) return true;
      const channels = inputs[0];
      if (!channels || !channels.length || !channels[0].length) return true;
      if (channels.length === 1) this.resampler.push(channels[0]);
      else {
        const mono = new Float32Array(channels[0].length);
        for (const channel of channels) {
          for (let i = 0; i < mono.length; i++) mono[i] += channel[i] / channels.length;
        }
        this.resampler.push(mono);
      }
      return true;
    }
  }
  registerProcessor('voice-pop-capture', VoicePopCaptureProcessor);
}

if (typeof module === 'object' && module.exports) module.exports = { VoicePopResampler };
