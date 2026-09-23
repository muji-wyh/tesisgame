// Small, single-threaded browser adapter for sherpa-onnx 1.12.29.
// The model bytes are installed in MEMFS by multiplayer-worker.js.
#include <cmath>
#include <algorithm>
#include <cstdint>
#include <sstream>
#include <string>
#include <vector>

#include <emscripten/emscripten.h>
#include "sherpa-onnx/c-api/c-api.h"

namespace {
const SherpaOnnxOnlineRecognizer *recognizer = nullptr;
const SherpaOnnxSpeakerEmbeddingExtractor *speaker = nullptr;
const SherpaOnnxVoiceActivityDetector *vad = nullptr;
const SherpaOnnxSpeechSegment *segment = nullptr;
std::string output;
std::vector<float> embedding;

void ReleaseSegment() {
  if (segment) {
    std::fill(segment->samples, segment->samples + segment->n, 0.0f);
    SherpaOnnxDestroySpeechSegment(segment);
  }
  segment = nullptr;
}
void ClearResult() {
  std::fill(embedding.begin(), embedding.end(), 0.0f);
  std::fill(output.begin(), output.end(), '\0');
  embedding.clear();
  output.clear();
}
}

extern "C" {
EMSCRIPTEN_KEEPALIVE void vp_destroy() {
  ReleaseSegment();
  if (recognizer) SherpaOnnxDestroyOnlineRecognizer(recognizer);
  if (speaker) SherpaOnnxDestroySpeakerEmbeddingExtractor(speaker);
  if (vad) SherpaOnnxDestroyVoiceActivityDetector(vad);
  recognizer = nullptr;
  speaker = nullptr;
  vad = nullptr;
  ClearResult();
}

EMSCRIPTEN_KEEPALIVE int vp_create() {
  vp_destroy();
  SherpaOnnxOnlineRecognizerConfig asr{};
  asr.feat_config.sample_rate = 16000;
  asr.feat_config.feature_dim = 80;
  asr.model_config.transducer.encoder = "/encoder.onnx";
  asr.model_config.transducer.decoder = "/decoder.onnx";
  asr.model_config.transducer.joiner = "/joiner.onnx";
  asr.model_config.tokens = "/tokens.txt";
  asr.model_config.num_threads = 1;
  asr.model_config.provider = "cpu";
  asr.model_config.model_type = "zipformer2";
  asr.decoding_method = "greedy_search";
  recognizer = SherpaOnnxCreateOnlineRecognizer(&asr);
  if (!recognizer) return 0;

  SherpaOnnxSpeakerEmbeddingExtractorConfig voice{};
  voice.model = "/speaker.onnx";
  voice.num_threads = 1;
  voice.provider = "cpu";
  speaker = SherpaOnnxCreateSpeakerEmbeddingExtractor(&voice);
  if (!speaker) return 0;

  SherpaOnnxVadModelConfig detection{};
  detection.silero_vad.model = "/silero_vad.onnx";
  detection.silero_vad.threshold = 0.5f;
  detection.silero_vad.min_silence_duration = 0.30f;
  detection.silero_vad.min_speech_duration = 0.10f;
  detection.silero_vad.max_speech_duration = 5.0f;
  detection.silero_vad.window_size = 512;
  detection.sample_rate = 16000;
  detection.num_threads = 1;
  detection.provider = "cpu";
  vad = SherpaOnnxCreateVoiceActivityDetector(&detection, 35.0f);
  return vad && SherpaOnnxSpeakerEmbeddingExtractorDim(speaker) > 0;
}

EMSCRIPTEN_KEEPALIVE void vp_reset() {
  ReleaseSegment();
  if (vad) SherpaOnnxVoiceActivityDetectorReset(vad);
  ClearResult();
}

EMSCRIPTEN_KEEPALIVE void vp_accept(const float *samples, int n) {
  SherpaOnnxVoiceActivityDetectorAcceptWaveform(vad, samples, n);
}

EMSCRIPTEN_KEEPALIVE void vp_flush() {
  SherpaOnnxVoiceActivityDetectorFlush(vad);
}

EMSCRIPTEN_KEEPALIVE int vp_front() {
  ReleaseSegment();
  if (SherpaOnnxVoiceActivityDetectorEmpty(vad)) return 0;
  segment = SherpaOnnxVoiceActivityDetectorFront(vad);
  return segment->n;
}

EMSCRIPTEN_KEEPALIVE int vp_segment_start() {
  return segment ? segment->start : 0;
}

EMSCRIPTEN_KEEPALIVE const float *vp_segment_samples() {
  return segment ? segment->samples : nullptr;
}

EMSCRIPTEN_KEEPALIVE void vp_pop() {
  ReleaseSegment();
  SherpaOnnxVoiceActivityDetectorPop(vad);
}

// The VAD segment is processed using the selected streaming transducer. A
// stream per utterance prevents a preceding player's words leaking into the
// next turn. InputFinished + tail silence lets the final short word decode.
EMSCRIPTEN_KEEPALIVE const char *vp_transcribe(const float *samples, int n) {
  auto *stream = SherpaOnnxCreateOnlineStream(recognizer);
  SherpaOnnxOnlineStreamAcceptWaveform(stream, 16000, samples, n);
  std::vector<float> tail(8000, 0.0f);
  SherpaOnnxOnlineStreamAcceptWaveform(stream, 16000, tail.data(), tail.size());
  SherpaOnnxOnlineStreamInputFinished(stream);
  while (SherpaOnnxIsOnlineStreamReady(recognizer, stream)) {
    SherpaOnnxDecodeOnlineStream(recognizer, stream);
  }
  const char *json = SherpaOnnxGetOnlineStreamResultAsJson(recognizer, stream);
  output = json ? json : "{}";
  if (json) SherpaOnnxDestroyOnlineStreamResultJson(json);
  SherpaOnnxDestroyOnlineStream(stream);
  return output.c_str();
}

EMSCRIPTEN_KEEPALIVE int vp_embed(const float *samples, int n) {
  std::fill(embedding.begin(), embedding.end(), 0.0f);
  embedding.clear();
  auto *stream = SherpaOnnxSpeakerEmbeddingExtractorCreateStream(speaker);
  SherpaOnnxOnlineStreamAcceptWaveform(stream, 16000, samples, n);
  SherpaOnnxOnlineStreamInputFinished(stream);
  if (SherpaOnnxSpeakerEmbeddingExtractorIsReady(speaker, stream)) {
    const float *values =
        SherpaOnnxSpeakerEmbeddingExtractorComputeEmbedding(speaker, stream);
    if (values) {
      int dim = SherpaOnnxSpeakerEmbeddingExtractorDim(speaker);
      embedding.assign(values, values + dim);
      SherpaOnnxSpeakerEmbeddingExtractorDestroyEmbedding(values);
    }
  }
  SherpaOnnxDestroyOnlineStream(stream);
  // Reject invalid output instead of manufacturing a player identity.
  double squared = 0;
  for (float v : embedding) {
    if (!std::isfinite(v)) { embedding.clear(); return 0; }
    squared += v * v;
  }
  if (squared <= 1e-12) { embedding.clear(); return 0; }
  float norm = std::sqrt(squared);
  for (float &v : embedding) v /= norm;
  return embedding.size();
}

EMSCRIPTEN_KEEPALIVE const float *vp_embedding() {
  return embedding.data();
}
}
