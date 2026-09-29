# Retired runtime and asset cleanup

The audit traced runtime callers, Godot callbacks, dynamic resource names,
export rules, generators, and tests before removing obsolete code. It removes
the collectible celebration node, fragment-only drawing mode, replaced chest
tap/completion APIs, unused Pip shortcut actions, obsolete next-gift/adventure
helpers, unused theme prize labels, and the disabled whole-page inertia logic.
Current horizontal rails keep their own drag handling and click suppression.

The source tree no longer includes eight replaced opening jingles, eight
retired arrival/opening voice prompts, or five unused collectible particle
textures. Their 21 import sidecars were also removed: 42 files totaling
2,485,944 bytes. The importer and generator now maintain 14 original chest
images and 12 general effects. Ten derived chest rig layers, the current glow
texture, all 88 authored chest cues, fallback synthesis, and 360 active voice
recordings remain. Export validation rejects the retired effects and checks
that all required current audio is playable inside the pack.

Tests now use actual press/release and drag paths in place of removed shortcut
APIs. The scene capture helper waits for the current release notification and
completed opening rather than assuming the old timing.

## Compatibility retained

Save versions, migration, reward accounting, and toy unlocking are unchanged.
Existing saved favorites still render through the shared full/partial medal
view. Saved-record compatibility writers and diagnostic/audio control APIs
remain where roundtrip, failure-recovery, or runtime checks still require them.
Historical QA and asset provenance records remain historical; current inventory
documentation reflects the active assets. Export cleanup for old output files
is retained because rebuilding into an existing output directory still needs it.

Before deletion, the exact working copies of the retired assets and import
sidecars were copied and hash-verified in the ignored local directory
`build/retired-assets-backup-20260929-225854`. Unrelated pre-existing import
metadata changes are excluded from this cleanup commit.

## Validation

- 131 distinct Node checks passed across source inventories, asset generators,
  the chest importer, Web export, deployment, and browser host contracts. The
  importer retained the exact source hashes and reported zero writes.
- All 23 selected native suites passed, totaling 13,787 assertions/checks after
  focused rechecks. Coverage includes all three game modes, old saves, reward
  accounting, room rails, Pip gestures, chest motion/audio, and recovery.
- Two old gesture fixtures expected a new Pip action during the preceding
  animation. They now wait on the actual animation/audio busy state and also
  verify ignored taps do not queue extra actions or reports. No production
  serialization behavior changed. Pip playground passed 235 checks and Voice
  Pop passed 812 checks with those corrected fixtures.
- The browser movement fixture also retained a nominal Pip position from before
  fetching a ball and placed its "near" target at the front of a deep room.
  That target correctly triggered a run. It now measures the actor after the
  fetch and checks a short sideways walk and a distant run separately, retaining
  strict captions, distance limits, visible movement, and unchanged-save checks.
- The pack verifier passed for 350 word pronunciations, 12 general effects,
  and all 314 required source/imported audio paths. It also confirmed that the
  retired celebration script, particle textures, and opening jingles are absent.
- The release export completed at 19.12 MB compressed startup transfer, down
  from 19.49 MB before cleanup. It uses `game-047a9627b54b764c.pck` and the
  unchanged `engine-ab20058469bff805` Web engine.
- The focused browser matrix passed 19 cases: 14 Chromium and five emulated
  iPhone WebKit cases, including the corrected movement fixture rechecks.
  It covered old saves/toys, fixed-page and horizontal-rail gestures, Pip
  strokes/throws, cancellation recovery, keyboard/reduced-motion input, chest
  cancellation/release, and exactly-once rewards. Chromium additionally proved
  suspended-context recovery without reload and actual offline chest output,
  with no audio HTTP requests. Windows WebKit lacks WebAudio; its checks establish
  gameplay/layout compatibility, not physical iOS audio behavior.

Import, native tests, export, and browser runtimes run serially. This cleanup
does not change the existing 320 x 320 adventure-loss layout limitation recorded
in the bundled-audio QA report. The recovery suite also emits a headless focus
warning while passing all assertions.
