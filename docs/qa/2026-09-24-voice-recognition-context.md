# Voice Pop recognition context and feedback — 2026-09-24

## Behavior

- The round's full age-appropriate noun pool is passed to both recognition
  backends before listening starts. Solo uses optional contextual phrases with
  a modest boost when supported. Missing APIs, a rejected phrase setter,
  synchronous `NotSupportedError`, and asynchronous `phrases-not-supported`
  retain normal browser recognition. A service rejection retries once without
  hints; old callbacks are fenced out.
- Local Zipformer recognition uses modified beam search with four active paths
  and a 1.0-per-token vocabulary bonus. It remains open-vocabulary recognition;
  the game does not turn arbitrary text into the nearest target spelling.
- A 12,590-byte BPE vocabulary is derived from the pinned ASR repository's
  `bpe.model` using build-only `sentencepiece==0.2.1`. Source and derived hashes
  are verified and recorded in the asset manifest. The build sets the pinned
  upstream BPE encoder's unused worker pool to zero for single-threaded WASM.
  This patch is guarded, repeatable, and disclosed in generated notices.
- Existing ONNX weights and speaker-profile versions remain unchanged. Updated
  runtime assets remain optional downloads. Unchanged assets from an older
  cache can be reused only after length and SHA-256 validation; corrupt or
  inaccessible cached data falls back to downloading.
- Exact whole-token matching accepts four explicit homophone pairs and their
  regular plurals: sun/son, flower/flour, pear/pair and plane/plain. Spawn
  collision checks include these aliases. Partial words, possessives, arbitrary
  spelling corrections and function-word homophones are not accepted.
- The live caption distinguishes unclear speech, unconfirmed identity,
  expired targets, unrelated words, and unavailable word timing. Raw local text
  can be shown independently of a usable speaker vector or word timestamp.
  Feedback never scores or changes microphone readiness. Session, round,
  event-ID and captured-time validation apply before native presentation.
- A correct Solo hit keeps its short celebration when a following filler such
  as “please” is delivered. Pause, backgrounding and leaving clear feedback.
  Multiplayer presentation uses the validated event path only, so replaying an
  old utterance cannot overwrite the latest accepted transcript.

## Validation

- Full `npm run test:voice-pop`: 21,703 native assertions/checks passed;
  168 Node tests passed, no failures, and one optional actual-WASM test skipped
  in this ordinary regression run. Evidence: `build/recognition-regression.log`.
- Packaging, deployment-script and Web-export contracts: 26 tests passed.
  Coverage includes content-addressed `.vocab` cleanup without deleting
  unrelated files. Evidence: `build/recognition-package-tests.log`.
- Actual WASM runtime: 32 tests passed, including biased silence, off-vocabulary
  speech, unrelated narration, unavailable speaker evidence, and unchanged
  enrollment/identification checks. Evidence:
  `build/voice-vocabulary-runtime-tests.log`.
- Browser integration: 15 tests passed across desktop Chromium, iPhone WebKit,
  and iPad WebKit configurations. Coverage includes vocabulary delivery,
  background readiness, recognition feedback, duplicate/stale callbacks,
  live transcripts, and switching back to Solo. These are browser-engine
  configurations, not tests on physical iPhones or iPads. Evidence:
  `build/recognition-browser.log`.
- Final Solo speech-host regression: 71 tests passed after the empty-hypothesis
  presentation correction. Evidence: `build/recognition-host-final.log`.
- Prepared runtime version: `voice-pop-local-v1-78fcbbfe2081cfcd`, with nine
  optional assets totaling 112,350,217 bytes. A repeat prepare run produced
  the same version and required no native rebuild.
- Chromium cold preparation downloaded and verified the real exported assets,
  initialized and warmed the Worker/WASM, reached `ready`, and passed a health
  ping with zero microphone requests. All 112,350,217 bytes were accounted for.
  Windows Playwright WebKit lacks microphone/Web Audio APIs and correctly
  reported `unsupported`. A separate preparation-only check bypassed that
  capability gate and passed with its real Worker/WASM, without claiming audio
  capture support. Evidence: `build/recognition-runtime-browser.log`.

## Synthetic short-word diagnostic

The same 16 repository noun recordings were processed serially with the old
greedy runtime and the updated runtime. These recordings use the same configured
synthetic source voice; the test is a small diagnostic, not human accuracy.

| Decoder context | Exact raw words | Median decode | Total decode |
| --- | --- | --- | --- |
| Previous greedy decoder | 13/16 | 212 ms | 3,498 ms |
| Modified beam, no context | 13/16 | 202 ms | 3,337 ms |
| Modified beam, five lesson nouns | 14/16 | 201 ms | 3,359 ms |
| Modified beam, full 200 nouns | 14/16 | 206 ms | 3,442 ms |

Vocabulary bias corrected `octapus` to `octopus` and preserved all 13 previously
correct nouns. `sun` remained `son` (now an explicit accepted homophone), and
`helicopter` remained incorrect. Silence emitted zero events. Unrelated welcome
narration stayed unchanged in every condition: `FIND THREE PAIRS / SOME CARDS
HAVE NO MATCH / A PICTURE OR A WORD`.

The longest observed decode was 261 ms before and 278 ms with the full vocabulary.
With only 16 samples, this maximum is not a reliable population p95. Total
VAD/ASR/embedding processing was 6,166 ms before and 6,134 ms after; a single pass
does not establish a speed improvement or microphone-to-feedback latency.

Speaker acceptance remained 8/16. Exact raw recognition plus speaker acceptance
was 6/16 before and 7/16 after. The unchanged identity gate is still a major limit
for short isolated words; no lower similarity threshold was used to inflate
coverage. Diagnostic evidence is in `build/voice-short-word-before.json` and
`build/voice-short-word-after-{unbiased,five,full}.json`.

## Limits

Browser recognition services and contextual-phrase availability vary by browser.
Solo still matches targets at result receipt because the browser API does not
provide reliable word timestamps. Multiplayer retains captured-time matching
and its three-second settlement limit. No identity threshold was lowered.

Synthetic repository audio and mocked recognition events verify processing,
matching and UI behavior. They do not establish real-person accuracy, a 95%
speaker-attribution rate, or a device-independent latency target. Short-word
speaker matching, children's voices, similar voices, noisy rooms and physical
Safari/Chrome microphones still require field evaluation. Overlapping-speaker
separation remains outside this implementation.
