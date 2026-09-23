# Voice Pop local multiplayer prototype

## Implemented behavior

- Solo browser speech remains playable during background model preparation.
- Byte progress, initialization, ready, retry and unsupported states are separate
  from microphone/listening state. SHA-256 verification and real inference
  warm-up precede ready. WebAssembly SIMD support is checked before downloads.
- Ready offers Continue solo / Start multiplayer without stopping the round.
  Switching keeps its summary and opens a new 30-second round only after local
  capture starts. Selection is retained for the page session.
- Up to four voice centroids are registered only after valid hits. Ambiguous
  voices use the nearest player; clearly new fifth voices are ignored. Counts
  and shared ranks determine the winner.
- Historical target intervals, event IDs and bridge session IDs prevent delayed
  words from scoring a new target or round. The final drain lasts at most 3s.
- Worker/microphone failures pause local play; foreground return probes runtime
  health without automatically reopening the microphone.
- Local recordings and embeddings stay in memory. Capture/WASM buffers and
  model voice centroids are cleared at the appropriate session/round boundary.
- The exporter verifies and separately publishes models, removes obsolete
  generated model versions, and includes third-party license notices.

## Automated evidence

`npm run test:voice-pop`:

- Existing solo model: 20,334 assertions, zero failures.
- Solo scene including result-button touch scrolling: 684 checks, zero failures.
- Narration: 60 checks, zero failures.
- Multiplayer model: 119 assertions, zero failures.
- Multiplayer scene after final leaderboard layout: 152 checks, zero failures.
- Final combined Node host/runtime, packaging and existing voice tests with
  real WASM enabled: 90 passed, zero failures or skips.

Web export and deployment-script tests: 25 passed. These are isolated script
tests; no production deployment was performed.

Additional targeted regressions cover late permission grants whose microphone
release fails, synchronous Worker transport failure, incompatible SIMD engines,
cache corruption, initialization failure at 100%, old Worker callbacks, and
bounded generated package size after repeated model updates.

The real WASM suite passed 9/9 checks with `VOICE_POP_REAL_RUNTIME=1`.
The opt-in browser runtime suite passed on Chromium and Windows WebKit: it
downloads/verifies the actual 112.34 MB package, reuses Cache Storage without
fetching the model assets again, then recognizes `cat`, `apple` and `dog` with
256-dimensional normalized voice vectors after network access is disabled.
Windows Playwright WebKit has no microphone, AudioContext or AudioWorklet APIs;
the application correctly reports unsupported there before any model download.
Only the recording-driven inference harness bypasses that capture requirement.
This is not evidence that microphone capture works on an Apple device.

The final Web export's compressed engine/game files total 13.66 MB; the
separate model/inference assets total 112.34 MB on demand. These figures exclude
the HTML page and small JavaScript bridge/worker modules. Local
browser evidence is under `build/multiplayer-runtime-browser-final` and the
separate UI/solo regression directories; large generated outputs are ignored.

The exported multiplayer UI matrix passed **12/12** cases across desktop
Chromium and iPhone/iPad WebKit viewport profiles. It covers uninterrupted solo
readiness, explicit switching, delayed microphone permission, P1–P4, fifth-voice
rejection, duplicate/stale results, failure/retry, deadline drain, tied rankings,
replay, 320 px layouts, landscape and reduced motion. Actual screenshots were
reviewed, including four-player HUDs and phone leaderboards. The Mode button's
minimum-width clipping was corrected, and rankings/replay now appear above the
general round report on small screens.
After the final touch-scroll fix, the preparation/switching and deadline/ranking/
replay cases were rerun serially on all three browser profiles: **6/6 passed**
against the final export. Evidence is in `build/multiplayer-ui-browser-final-serial`.

Solo browser regression completed **17 applicable cases**: 11 desktop Chromium,
three iPhone WebKit and three iPad WebKit cases, with passing results across
the targeted runs. After the touch-scroll fix, all three complete spoken-word /
30-second round / report / scroll / replay workflows passed on the final export.
Evidence is in `build/multiplayer-solo-regression/final-serial` (desktop and
iPhone) and `final-long-flows` (iPad). Earlier concurrent browser runs suffered
resource contention and workflow timeouts; the final long-flow checks ran
without a competing browser suite.

The solo regression also exposed a real touch-scroll defect: Godot 4.7 result
buttons consumed drag events, so dragging from a word button only revealed its
keyboard focus instead of scrolling. Result buttons now pass unhandled motion
to the ScrollContainer. Native viewport-input checks verify continued scrolling
from all six button types, cancellation of the pending click during a drag, and
exactly one pronunciation action for a stationary word tap. The WebKit browser
fixture now checks movement after the first touch step so focus reveal alone
cannot satisfy its scrolling assertion.

The solo fixture also distinguishes microphone Retry from model-download Retry,
and checks Godot's stereo WebAudio output for mono source files by comparing
both output-channel fingerprints. No production audio assets were changed.
The complete 30-second-game/report/scroll/replay scenario has a 150-second
overall test budget; its individual response deadlines and gameplay duration
remain unchanged. Browser runs use the existing local server on port 41773.

## Model selection and acoustic limits

Selected models: streaming Zipformer English 2023-06-26 (chunk 16, left 64,
int8 encoder/joiner and fp32 decoder), Silero VAD, and sherpa-adapted WeSpeaker
VoxCeleb ResNet34-LM. Models total 100,614,045 bytes; the runtime adds
11,722,680 bytes, for **112,336,725 bytes (112.34 MB)** on demand. Fixed source
revisions, file lengths and SHA-256 values are maintained
in `tools/prepare-multiplayer-runtime.cjs` and the generated manifest.

A native comparison using 20 repository word recordings gave 18/20 exact words
for the selected Zipformer, with `sun` recognized as `son` and `bear` as `there`.
The earlier 20M model returned no words for all 20 recordings. Additional silence
and alternative decoding did not resolve its short-word failures. The selected model uses
about 28.24 MB more download. These are one voice's recordings, not children or
multiple people, and they do not demonstrate the product accuracy targets.

WASM linear memory after warm-up and the three word probes was 193,331,200
bytes (184.38 MiB). This excludes Godot, JavaScript and download/cache buffers,
and is not a measurement of total memory on a phone.

## Remaining release validation

The feature is a working prototype pending acoustic/device acceptance. No claim
is made that it meets 95% speaker attribution, 85% valid-word coverage or p95
1.2-second feedback. Evaluate children, similar voices, two-to-four-person turns,
a fifth voice, short words, background noise, and speaker distance. Calibrate the
experimental 0.35/0.60 cosine thresholds from those recordings.

Physical microphone tests on desktop Chrome, macOS Safari, Android Chrome,
iPhone and iPad Safari remain necessary. Windows Playwright WebKit and mobile
viewport profiles are browser/layout evidence, not physical Apple-device proof.
Measure peak memory, warm-up, frame pacing, battery/load and interruption recovery.
Overlapping voices are not separated in this version.
