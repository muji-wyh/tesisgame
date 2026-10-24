# Runtime and export cleanup - 2026-10-24

The startup pack excludes build-only Professional source records and unused
media while retaining their repository files for validation, authoring, previews,
and historical fixtures. The obsolete medal renderer, button styling helper,
speech queue, and morphology stub were removed. Current documentation and tests
now describe the existing additive Jelly levels through six and 140 ms batch
collection. Gameplay rules, prices, save migrations, and active media are intact.

## Measured delivery change

| Measurement | Before (`683a5950`) | After |
| --- | ---: | ---: |
| Decoded game pack | 143,539,656 bytes | 76,481,276 bytes |
| Brotli game pack | 42,887,211 bytes | 38,456,076 bytes |
| Packed entries | 1,641 | 1,386 |

The game pack download is **4,431,135 bytes smaller (10.33%)**. Its decoded size
is **67,058,380 bytes smaller**. Core startup, including the unchanged engine, is
45.61 MB before the selected vocabulary packs. These are artifact measurements,
not a measured browser startup-time or frame-rate improvement.

The new game pack is `game-0632de80bcd1103a.pck.br`; its decoded SHA-256 is
`0632de80bcd1103a10f7e1251ef21ff993e90e0c6449a9921c47f2ceb054d21d`.

An independent before/after inventory comparison confirms that exactly the 255
intended entries were removed, with no unexpected removals:

- 75 Professional provenance, schema, source-registry, and policy-decision files.
- 89 unused media payloads and their 89 import descriptors: archived Jelly cues,
  original Pip authoring sheets, preview narration, and numbered reward artwork.
- The medal renderer's compiled script and remap.

The generated Professional descriptor and script pin were refreshed by the
normal build. Only the supporting-source digest and resulting artifact hashes
changed; course/module availability and policy rules remain unchanged.

## Verification

The Web build passed content validation, native pack verification, and receipt
generation. All 13,600 source inputs and 117 export files are recorded. The
native verifier found no excluded source or imported payloads, and checked the
three pinned Professional resources, all vocabulary packs, five chest models,
eight chest types, 100 Professional Pip atlases, age artwork and motion, phrase
recordings, and active feedback audio.

Ten focused native suites passed with **118,550 checks/assertions**, covering
Jelly supply and merges, immediate speech and delayed-load cancellation, powerup
silence, medal save compatibility, chest/collection presentation, UI audio, and
economy calculations. **43 Web export tests and 14 packaging/deployment tests**
also passed.

The broad core suite ran 18,202 assertions and reported seven failures. An
isolated source snapshot of `683a5950983e4bbf19f17cc142235eb863ffe03b` reproduced
the same seven failures in the same order: disabled theme text, same-lesson theme
retention, growth announcements, controller theme cycling, motion announcements,
and two startup controller-focus assertions. They predate this cleanup. The
baseline used separate runtime/test sources and read-only access to unchanged
assets/imports; the shared checkout was not swapped.

Eight browser cases passed across desktop Chromium and Android emulation:
Home layout and input boundaries, career navigation, Memory mismatch dismissal,
and accepted-drop Jelly pronunciation. The Home helper was updated to check the
current everyday Home, vocabulary entry, and all six games; it had still expected
the removed path-picker gate. Responsive rendering, scrolling, and touch-target
checks remain in place.

The Age 0 Pip automatic-action test loaded its resources successfully but timed
out waiting 14 seconds for `shell-rock`. The same test and deadline also failed
against the prior production pack, `game-9625351b58444e91.pck.br`, before deployment
of this cleanup. Both the original locator polling and a diagnostic RAF poll
failed locally; RAF polling reproduced the timeout against production. The
diagnostic test change was reverted. This is an inherited test failure whose
underlying cause remains unresolved, not a passing animation check. Pip artwork
rendered correctly in the inspected Home and Memory screenshots.

Local evidence is under `build/qa/unused-cleanup-2026-10-24/`: build and test logs,
`pack-comparison.json`, native results and baseline comparison, browser traces,
and screenshots. The original read-only audit remains under
`build/qa/unused-audit-2026-10-24/`.

## Retained material

Loose Professional lexemes and expressions still ship because the ordinary
catalog retains a dynamic reader; excluding them requires a separate delivery
change and a generated ready-module regression. Asset licenses, original source
files, local previews, and historical Professional evidence remain available.
No bulk deletion of `build/` or source assets was performed.

Browser checks use emulation and instrumented audio playback. They do not
establish physical phone performance, speaker latency, or microphone behavior.
