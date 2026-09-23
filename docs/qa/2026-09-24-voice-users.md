# Saved voice users — 2026-09-24

This records the initial library implementation. Enrollment duration and voice
templates are superseded by the subsequent
[voice matching improvements](2026-09-24-voice-accuracy.md).

## Scope

- More → Users stores up to 10 names, emoji avatars and 256-dimensional voice
  profiles in this browser. Add, edit, re-record and confirmed deletion are available.
- Enrollment reuses the existing on-demand local models. It requires at least
  three usable speech segments and six seconds of speech; a single short word,
  silence, clipping and inconsistent voices fail with a retry message. Only Save
  persists a profile. Raw audio is discarded on completion/cancellation.
- Multiplayer matches only registered voices with cosine similarity ≥0.60 and
  a ≥0.08 margin over the next profile. Unknown and ambiguous speakers are ignored.
  The existing four-participant round limit remains; the saved library holds 10.
- HUD, hit feedback and standings display native-rendered emoji avatars. Results
  include names and rank by hit count. An active/paused round keeps its opening
  library snapshot, including after all saved profiles are deleted; the next
  round uses the updated library.
- Solo browser recognition still works independently and does not identify users.
  Model preparation, recording and microphone release failures have separate states.
- The previous Medals-page removal and chest/toy reward behavior are preserved.

## Automated checks

- Node: 110/110 passed with `VOICE_POP_REAL_RUNTIME=1`, including the real local
  WASM VAD/WeSpeaker enrollment path and existing ASR. Store, worker, host, shell
  bridge and packaging tests cover invalid/corrupt/versioned profiles, capacity,
  write failures, cancellation, stale events, microphone failure and round resume.
- Native Godot: 8 relevant suites, 21,919 checks, no failures: solo model/scene,
  multiplayer model/scene, gameplay layouts, collection polish, room scrolling
  and Medals removal. Includes actual input-event suppression behind Users and
  emoji textures in the HUD, hit effects and rankings.
- Standalone profile UI: 33/33 Playwright cases passed across desktop Chromium,
  iPhone WebKit and iPad WebKit. Includes a 320px editor, keyboard focus, Unicode
  name entry, readiness/download failures, explicit Save, edit/delete/capacity,
  storage failure, background cancellation and late microphone release failure.
- Full exported game: 17/17 Playwright cases passed (five Voice Pop cases each
  on desktop Chromium, iPhone WebKit and iPad WebKit, plus the existing Medals
  removal/chest/toy regression on both WebKit profiles). Exercises More → Users,
  explicit recording/save, reload, name/avatar edits, library deletion during a
  paused round, registered-only scoring, four-user HUD, tied standings, backend
  transitions and 320px/landscape layouts. Combined browser result: 50/50.
- Web export succeeded: 13.65 MB reported startup payload; existing local model
  assets remain 112.34 MB on demand. Exported user-editor JavaScript matches the
  verified source. `git diff --check` passed.

Desktop and 320px screenshots were visually checked for the menu, saved user
list, emoji HUD and tied-player standings. Browser device profiles emulate
layout/input and are not physical-device certification.

## Limits

Browser recognition/enrollment events in UI tests are deterministic fixtures;
they never capture the machine's microphone. The real WASM test uses repository
audio. These tests do not establish recognition/attribution accuracy for people,
children, similar voices, noise or overlapping speech. Thresholds remain prototype
heuristics. Physical Safari/Chrome device performance and real-speaker accuracy
still need field testing. No new model download was introduced by this feature.

Profiles are origin/browser local and are removed when site data is cleared.
They do not synchronize across devices. An older speaker-model profile remains
editable but must be re-recorded before joining a new multiplayer round.
