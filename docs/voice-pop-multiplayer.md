# Local Voice Pop multiplayer

Voice Pop retains browser SpeechRecognition for solo games. Entering the mode
prepares the local runtime in the background and publishes independent model
state. Ready models trigger a nonmodal choice; only a user gesture can start a
new multiplayer round. The current solo round is never converted midway.

## Assets and build

Run `npm run prepare:multiplayer`, then `npm run build:web`. The preparation tool
uses `build/multiplayer-toolchain` for build dependencies and `build/multiplayer`
for the verified runtime/models. These large generated files are ignored by Git.
Preparation needs Node 18+, Python 3 with pip, and tar. On Windows, Git for
Windows supplies sed for the upstream build. The tool downloads a pinned local
Emscripten SDK plus CMake/Ninja; this developer toolchain is much larger than the
browser download and is never shipped to players.
Model/runtime source pins are maintained in `tools/prepare-multiplayer-runtime.cjs`.
The exported `multiplayer/manifest.json` lists content-addressed same-origin URLs,
exact uncompressed byte lengths, and SHA-256 hashes. No runtime model is in the
Godot PCK. The browser reads and verifies every asset before Worker initialization.
Cache Storage is optional: a failed cache write does not prevent in-memory play.

| Purpose | Model | Model files | License |
| --- | --- | --- | --- |
| English words | sherpa-onnx streaming Zipformer English, 2023-06-26, chunk 16 / left 64 | int8 encoder, fp32 decoder, int8 joiner, tokens.txt (73,439,641 bytes) | Apache-2.0 |
| Voice similarity | sherpa-adapted `wespeaker_en_voxceleb_resnet34_LM.onnx` | 26,530,550 bytes | CC-BY-4.0 |
| Speech boundaries | `silero_vad.onnx` | 643,854 bytes | MIT |

Models total **100,614,045 bytes** before the JS/WASM runtime, about **112.34 MB**
including that runtime. This exceeds the original 80–100 MB planning estimate.
The smaller 20M model returned no words for 20 repository recordings; the
selected model recognized 18/20 in the same native smoke test. This motivated
the larger download; it does not establish accuracy for real players.
Browser cache and
compression affect actual network traffic. The preparation tool includes third
party notices in the exported assets. WeSpeaker's model license requires credit;
the sherpa adapter does not replace that license.

Sources:
- https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26
- https://github.com/k2-fsa/sherpa-onnx/releases/tag/speaker-recongition-models
- https://huggingface.co/Wespeaker/wespeaker-voxceleb-resnet34-LM
- https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models
- https://github.com/snakers4/silero-vad

The small C API adapter in `tools/multiplayer-runtime` builds single-threaded
SIMD WASM with sherpa's audio feature extraction. It runs in a normal Worker and
does not add SharedArrayBuffer or cross-origin isolation requirements. Models
and runtime code are served with the game; the recognition worker makes no
audio, transcript, or embedding network requests.

## Events, identity and time

`observeMultiplayerState` publishes a JSON object with `status`, `loaded`, `total`,
`progress` and `message`. Status is idle, downloading, initializing, ready, error,
or unsupported. This never invokes the microphone listening callback. Ready
requires real ASR, VAD and embedding warm-up. A foreground return pings the worker
again; cached bytes alone cannot advertise an operational runtime.

`speechMode(true, 'pop', playMode, sessionId, elapsedMs)` selects exactly one
recognition backend. Each microphone start gets a new session ID. Local
`observePopEvent` JSON events contain `type`, `sessionId`, `eventId`, `text`,
`startMs`, `endMs`, and a 256-dimensional `embedding`. A `flushed` event finishes
the pending tail. Old sessions are ignored in both JavaScript and Godot.

The capture worklet emits mono 16 kHz audio with continuous sample offsets.
Paused time is excluded using the active-round offset at resume. VAD bounds
segments; captured context preserves consonants for recognition. Isolated words
use observed audio onset/end after validating their token timestamp against
captured audio. Multiword results use Zipformer token timings to associate words
with historical targets. These are estimates, not a guarantee of exact acoustic
word boundaries. Each recognized word supplies a separate voice embedding from a
disjoint audio slice, so adjacent words do not automatically share a mixed voice
vector. Very short slices and speaker changes without a pause remain unreliable;
overlapping voices are not separated.

The game normalizes voice vectors and compares cosine similarity with existing
players. Experimental defaults are 0.35 for a new speaker and 0.60 for updating
an existing voice centroid. Between them, credit goes to the closest player
without changing the centroid. A new voice only claims a slot after an eligible
target hit. Four occupied slots reject clearly new voices. Ambiguous fifth
voices can still match an existing player, following the selected product rule.
These values are configurable and must be calibrated with real target users.

Each event and target is counted at most once. Late results use the target that
was valid when the word started, never a later throw of the same word. At 30
seconds new input ends and existing audio can settle for at most three seconds.
The result is ranked by individual hit count, with shared ranks for ties.

Voice vectors survive pauses within one round and are cleared at its end. Only
non-voice statistics are retained for the previous-round summary. Raw microphone
audio, voice vectors and transcripts are not written to storage.

## Validation

`npm run test:multiplayer` covers model rules, the actual Godot scene, downloader,
cache/checksum errors, worker lifecycle, capture resampling and host bridges.
`tests/browser/voice-pop-multiplayer.spec.cjs` uses supplied recognition events to
exercise the exported UI; it never opens a physical microphone. A real runtime
smoke test uses prerecorded audio, separately from those fixtures.

Set `VOICE_POP_REAL_RUNTIME=1` to run the real WASM check in
`tests/multiplayer-runtime.test.cjs` and the opt-in browser suite
`tests/browser/voice-pop-runtime.spec.cjs`. The browser suite exercises cold
preparation, verified cache reuse, real word/voice events, and offline inference
without requesting a physical microphone.

Release acoustic targets remain **unverified until a real-user study**: at least
three groups including children, two to four alternating speakers, comparable
voices, changing distance and volume, and a fifth participant. Report word
recognition, wrong identity, false-new-player rate and scoring coverage separately.
The proposed targets are 95% attribution accuracy, 85% valid-word coverage and
p95 feedback within 1.2 seconds; no automated fixture proves those targets.

Desktop Chromium and Windows WebKit automation are not substitutes for actual
Android Chrome, macOS Safari, iPhone and iPad testing. Measure warm-up time,
peak memory, game frame pacing and capture recovery on the supported devices
before describing the feature as validated for production.
