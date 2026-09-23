# Identify user — 2026-09-24

This records the initial button implementation. Recording duration, consensus
and template matching are superseded by the subsequent
[voice matching improvements](2026-09-24-voice-accuracy.md).

The Users panel now includes **Identify user** below **Add user**. It is enabled
when the local model is ready and at least one saved voice uses the current
speaker model. A button gesture starts a short recording, with a sentence prompt,
speech progress, Cancel, and automatic completion. Results show the matching
saved name and emoji, or **No match found**, with retry and return actions.

Identification uses the existing local VAD and WeSpeaker model without ASR or
additional downloads. At least two seconds of clear speech are required. The
saved-library match uses the gameplay thresholds: cosine similarity >=0.60 and
a >=0.08 lead over the next candidate. Unknown or ambiguous voices return no
match. Identification never edits saved profiles or joins a game round.

The 15-second deadline starts after microphone permission is granted. At the
deadline, capture is flushed and released; a stalled finish has a further
two-second bound. Completion is delivered only after microphone release.
Cancellation, closing, backgrounding and worker errors stop capture and discard
transient audio/features. Session guards ignore delayed callbacks. A failed
microphone release keeps the dialog open with an explicit stop retry.

## Validation

- Node host, worker, profile store, packaging and browser-speech contracts:
  129 passed, no failures, one optional real-runtime test skipped in that run.
- The worker suite also ran with `VOICE_POP_REAL_RUNTIME=1`: 22/22 passed,
  including actual WASM VAD/embedding identification with repository speech,
  automatic completion without ASR, insufficient speech and memory cleanup.
- Profile UI: 60/60 Playwright cases passed across desktop Chromium and
  iPhone/iPad WebKit profiles. Coverage includes model readiness, old profiles,
  matching and unknown results, no storage writes, retries, duplicate/late
  callbacks, denied or pending permission, cancellation, background interruption,
  failed microphone release, and existing enrollment/edit/delete flows.
  Evidence: `build/identify-users-ui.log` and `build/identify-users-ui-results/`.
- Phone list and result screenshots were inspected for button placement,
  readable names/avatars, touch targets and bounded layouts. A review found and
  fixed CSS specificity so reduced-motion settings disable the listening pulse.
- `npm run build:web` succeeded: 13.66 MB startup payload and the existing
  112.34 MB on-demand multiplayer assets. All four exported identification
  JavaScript/CSS files match their source byte for byte.
  Build log: `build/identify-users-export.log`.
- Final exported game: 6/6 Playwright scenarios passed across desktop Chromium
  and iPhone/iPad WebKit. They exercise More -> Users with the real host matcher,
  trusted microphone gestures, saved-avatar results, microphone release, canceled
  and late events, reduced motion, and the existing enrollment/edit/multiplayer
  scoring flow. Only hardware/model preparation are mocked for the identification
  integration. Evidence: `build/identify-users-export-browser.log` and
  `build/identify-users-export-results/`. Combined browser total: 66/66.

Browser tests use deterministic voice/hardware fixtures and never capture the
machine's microphone. Real WASM tests use repository audio. These checks do not
establish accuracy for human speakers, children, similar voices or noisy rooms;
physical-device microphone behavior still needs field testing.
