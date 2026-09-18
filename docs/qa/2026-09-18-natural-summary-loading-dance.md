# Natural Pip reports and an interactive loading dance

The Voice Pop results page used the browser's default speech synthesizer, so its
voice could sound mechanical and differ from the game's prerecorded words.
Reports now use Jenny Neural's friendly delivery: complete recorded sentences
for the actual hit count and combo, plus existing pronunciations of words from
that round. Precise scores and distinct-word counts remain visible in the four
result tiles. Report audio is optional and fetched on demand.

Pip's loading-screen dance advances with chest taps: left wing, right wing and
alternating hip movements. A quiet, locally synthesized accompaniment starts
only after interaction and ends when loading finishes or the page hides. Dance
feedback must not delay entry into the game or compromise progress reporting.

## Acceptance

- [x] Recorded assets verified against the maintained prompt catalog.
- [x] Narration playback, cancellation, loading failure and mute checks.
- [x] Native Voice Pop report and compact layout checks.
- [x] Browser results playback with no calls to system speech synthesis.
- [x] Loading dance input sequence, bounded rapid taps and audio cleanup.
- [x] Visual review of poses at desktop, phone and compact landscape sizes.
- [x] Production export and startup-pack exclusions.
- [ ] Main integration, deployment and production verification.

Speech-recognition fixtures avoid using a physical microphone. Narration plays
the actual shipped recordings in browser checks. Evidence is kept under ignored
`build/voice-pop-qa/` and the test output directories.

## Native and asset verification

- `test:voice-pop`: 20,334 model assertions, 760 scene checks, 56 narration
  checks and 51 Node tests passed.
- Core game: 1,885 assertions; UI audio flow: 70; recovery: 36;
  layout release: 53. All passed.
- Combined art, voice-generation, report-asset and host checks: 81 passed.
  Export and deployment contracts: 22 passed.
  Final exported-shell contracts, host and report assets: 73 passed.
- All 51 distinct WAVs passed format and audible-sample validation:
  9,507,592 bytes and 215.541 seconds total. The import uses compressed
  Godot resources; the recordings are optional downloads.
- The unified Web export passed 200 bundled pronunciation checks and 158
  optional-path exclusions. It has 79 on-demand audio assets and a 13.25 MB
  compressed startup transfer.
- A failed shared download resolves all waiting callers to the same failure.
  Cancelled narration cannot queue automatic retries or restart old speech.

Windows Playwright WebKit has neither `AudioContext` nor
`webkitAudioContext`, including on an independent blank page after a real
click. Its checks cover readable fallback and continued interaction. Actual
recorded playback and synthesized loading-music output are verified in
Chromium; no claim of real iPhone audio validation is made.

## Browser and visual verification

- Complete 30-second rounds passed in Chromium at 1366×768, 320×568 and
  844×390, plus the iPhone WebKit profile. These cover three report pages,
  replay, high-five, word review, another round, mode exit, actual audio
  state and zero system-speech calls. Original screenshots were inspected.
- Loading checks cover touch, keyboard and controller, all five dance steps,
  reduced motion, capped queues, music activation, mute and cleanup after
  hidden/pagehide/ready/failure. All 18 selected project cases have passing
  evidence; the three pose cases were rerun after replacing cross-process
  sampling with continuous in-page animation-frame sampling.
- Five real touches were delivered in 92.5/106/100 ms in Chromium/iPhone
  WebKit/iPad WebKit. Recorded SVG transforms reached ±108° wing lifts,
  ±8 px hip shifts and counter-rotating heads. Forty inputs kept a queue of
  at most five; the remaining dance cleared within 1,800 ms.
- Loading screenshots at 1366×768, 320×568, 844×390 and 320×320 show no
  clipped controls. The music target remains at least 44 px high.
- Loading evidence: `build/natural-pip-loading-stub/initial-results.json`,
  `results.json` and `pose-final-v2/`. Runtime evidence:
  `build/voice-pop-qa/natural-pip-report-local/`.
- Missing-clip and retry scenarios passed in Chromium and WebKit. Chromium
  recovered by playing the actual recording; WebKit retained the readable
  unavailable state. Neither called browser speech synthesis.
- Real-engine startup passed at CPU 1× and 4×. Maximum recorded long tasks
  were 377/1,567 ms; maximum complete quick-tap dispatch waits were
  299/1,573 ms. Slow setup remained at 98%.
- The startup observer now associates tasks with timestamped progress writes,
  rather than the percentage visible when a delayed observer batch arrives.
  It also retains pre-ready entries delivered after reveal. Quick taps queue
  down/up together in protocol order, preventing two artificial waits before
  the release is even sent. All existing time limits remain unchanged.
  Evidence: `natural-pip-startup-timing-tests.json`,
  `natural-pip-startup-final-tests.json` and retained traces.
