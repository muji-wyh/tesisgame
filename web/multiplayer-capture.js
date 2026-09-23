(function (scope) {
  'use strict';

  // Both permission acquisition and AudioContext.resume begin in the caller's
  // gesture, before the first await (required on Safari).
  async function create({ onAudio, onError = () => {}, workletUrl = 'multiplayer-audio.js' }) {
    const AudioContext = scope.AudioContext || scope.webkitAudioContext;
    if (!scope.navigator?.mediaDevices?.getUserMedia || !AudioContext || !scope.AudioWorkletNode) {
      throw new Error('This device does not support local microphone capture.');
    }
    const context = new AudioContext({ latencyHint: 'interactive' });
    const resume = context.resume();
    const microphone = scope.navigator.mediaDevices.getUserMedia({
      audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true, autoGainControl: false },
      video: false
    });
    let stream;
    let source;
    let node;
    let sink;
    let stopped = false;
    let released = false;
    let failed = false;
    let flushSequence = 0;
    const pending = new Map();
    const fail = (error) => {
      if (stopped || failed) return;
      failed = true;
      onError(error instanceof Error ? error : new Error(String(error)));
    };
    try {
      // Attach both rejection handlers immediately; permission can fail before
      // loading the worklet and a resume failure must release a granted track.
      const results = await Promise.allSettled([microphone, resume]);
      if (results[0].status === 'fulfilled') stream = results[0].value;
      for (const result of results) if (result.status === 'rejected') throw result.reason;
      if (!context.audioWorklet) throw new Error('AudioWorklet is unavailable.');
      await context.audioWorklet.addModule(workletUrl);
      node = new scope.AudioWorkletNode(context, 'voice-pop-capture', {
        numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [1]
      });
      node.port.onmessage = ({ data }) => {
        if (stopped) return;
        if (data.type === 'audio') onAudio({ samples: data.samples, sampleOffset: data.sampleOffset });
        if (data.type === 'flushed') {
          const waiter = pending.get(data.requestId);
          if (waiter) { clearTimeout(waiter.timer); pending.delete(data.requestId); waiter.resolve(); }
        }
      };
      node.onprocessorerror = () => fail(new Error('Microphone processing stopped.'));
      for (const track of stream.getTracks()) {
        track.addEventListener('ended', () => fail(new Error('Microphone disconnected.')));
      }
      context.onstatechange = () => {
        if (context.state === 'interrupted' || context.state === 'suspended') {
          fail(new Error('Microphone capture was interrupted.'));
        }
      };
      source = context.createMediaStreamSource(stream);
      sink = context.createGain();
      sink.gain.value = 0;
      source.connect(node);
      node.connect(sink);
      sink.connect(context.destination);
      return {
        sampleRate: 16000,
        flush() {
          if (stopped) return Promise.resolve();
          const requestId = ++flushSequence;
          return new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
              pending.delete(requestId);
              reject(new Error('Microphone did not finish capturing.'));
            }, 1500);
            pending.set(requestId, { resolve, reject, timer });
            node.port.postMessage({ type: 'flush', requestId });
          });
        },
        stop() {
          if (released) return;
          stopped = true;
          for (const waiter of pending.values()) { clearTimeout(waiter.timer); waiter.resolve(); }
          pending.clear();
          try { node.port.postMessage({ type: 'stop' }); } catch (_) {}
          node.port.onmessage = null;
          try { node.disconnect(); } catch (_) {}
          try { source.disconnect(); } catch (_) {}
          try { sink.disconnect(); } catch (_) {}
          let releaseError;
          for (const track of stream.getTracks()) {
            try { track.stop(); } catch (error) { releaseError = error; }
          }
          context.onstatechange = null;
          try { context.close().catch(() => {}); } catch (_) {}
          if (releaseError) throw new Error('Could not release the microphone. Close this tab before opening another microphone session.');
          released = true;
        }
      };
    } catch (error) {
      stopped = true;
      if (stream) for (const track of stream.getTracks()) { try { track.stop(); } catch (_) {} }
      try { node?.disconnect(); } catch (_) {}
      try { source?.disconnect(); } catch (_) {}
      try { sink?.disconnect(); } catch (_) {}
      try { context.close().catch(() => {}); } catch (_) {}
      throw error;
    }
  }

  scope.VoicePopCapture = { create };
  if (typeof module === 'object' && module.exports) module.exports = scope.VoicePopCapture;
})(typeof window === 'object' ? window : globalThis);
