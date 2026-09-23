# Voice matching improvements — 2026-09-24

## Behavior

- Enrollment offers six phrases and requires at least 12 seconds of estimated
  effective speech across three independent turns. The microphone deadline is
  60 seconds after capture starts. A 10 ms energy gate inside VAD speech clips
  excludes internal pauses from progress; embeddings still use natural,
  contiguous audio. This frame estimate is a heuristic, not phoneme labeling.
- Quiet, clipped, short or inconsistent clips produce actionable feedback.
  Competing initial samples allow one early outlier to lose to later consistent
  turns. The existing 0.45 enrollment-consistency threshold is retained.
  Forced adjacent VAD chunks cannot satisfy the independent-turn requirement;
  turns need an observed gap of at least 200 ms between VAD clips.
- Profiles keep up to eight normalized voice templates. Identification and
  gameplay both score a person using the mean of their two strongest templates.
  The existing 0.60 similarity and 0.08 next-person margin remain unchanged.
  A legacy profile uses its original embedding without an automatic rewrite.
- **Add voice samples** appends only on explicit Save and keeps original
  references alongside recent recordings. The aggregate and every added
  template must support the selected person. A recording clearly matching a
  different saved user is rejected without a partial voice or metadata write.
  **Re-record voice** remains a separate replacement action.
- **Identify user** requires at least four seconds of effective speech,
  agreement from at least two independent turns, and a matching aggregate.
  Conflicting recognized identities, ambiguous voices and insufficient evidence
  return no match with guidance. Capture stops automatically when ready, with a
  25-second capture deadline and two-second finishing bound.
- Recording results and unsaved templates are discarded on cancellation,
  replacement, completion or failure. Saved profiles remain browser-local.
  Existing models are reused; this change adds no model download.

## Validation

- `npm run test:voice-pop`: 21,491 native assertions/checks passed across the
  solo model/scene, narration and multiplayer model/scene. Node contracts passed
  155 tests with no failures and one optional real-runtime test skipped.
  Evidence: `build/voice-accuracy-regression.log`.
- The worker suite separately ran with actual local WASM: 30/30 passed. A
  repository narration fixture provided 15,660 ms of estimated enrollment
  speech across 16 VAD turns and 5,090 ms of identification speech across four
  turns. Held-out same-recording cosine similarity was 0.6971 for the aggregate
  and 0.6949, 0.6996, 0.6961 and 0.6789 for the independent turns. The actual
  saved-template matcher also accepted the aggregate (0.7068) and all four turns
  (0.6905–0.7115), consuming the eight templates from the real enrollment result.
- Profile/host contracts include backward-compatible reads, normalized bounded
  templates, atomic saves, cross-user contamination rejection, independent-turn
  consensus, microphone release, timeouts, stale callbacks and memory cleanup.
  Native matching tests exercise multi-template variation, single-template
  outliers, ambiguous identities, unknown speakers and immutable round snapshots.
- Standalone profile UI: 96/96 Playwright cases passed serially across desktop
  Chromium and iPhone/iPad WebKit profiles. Coverage includes explicit Save,
  append/cancel/replacement, storage failure, effective-speech progress,
  reason-specific guidance, duplicate/late callbacks and transient-vector
  disposal without clearing saved copies. The 320px editor and identified-avatar
  screenshots were inspected. Evidence: `build/voice-accuracy-ui.log` and
  `build/voice-accuracy-ui-results/`.
- Final Web export succeeded: 13.66 MB startup payload and the existing
  112.34 MB on-demand multiplayer assets. All seven exported voice scripts/CSS
  match their source byte for byte. Evidence: `build/voice-accuracy-export.log`.
- Exported-game integration: 6/6 selected scenarios passed in their final runs
  across desktop Chromium and iPhone/iPad WebKit. They cover the actual menu,
  real host identification, microphone release, persisted templates, reload,
  edited emoji avatars, unknown-user rejection and multiplayer scoring from an
  immutable round snapshot. The initial run exposed a stale single-template
  schema assertion; it was updated to verify stored normalized templates and
  the affected flow passed on all three profiles. Evidence:
  `build/voice-accuracy-export-browser.log`,
  `build/voice-accuracy-enrollment-browser.log` and their results directories.
  Combined final browser coverage: 102 passed.

## Limits

The narration fixture and synthetic vectors verify the processing pipeline and
matching rules. They do not establish an accuracy percentage or latency target
for real people. Children's short words, similar voices, room noise and physical
Chrome/Safari microphones still require a consented field evaluation. Browser
device profiles emulate layout and input; they do not certify physical devices.

Gameplay still embeds short word clips, and overlapping-speaker separation is
not implemented. Users with old recordings can choose **Add voice samples** or
re-record in the room and microphone position used for play. No new threshold
calibration or claim of 95% attribution accuracy is made by this release.
