# Contact feedback during a dragged fusion

A manual fusion previously moved its artwork without running drag targeting,
so it offered no matching hint or contact pressure until the result committed.
The held fusion now previews the reserved result's word and level while its
original animation clock keeps advancing. Both painted lobes participate in
contact. Compatible targets use the existing wider approach margin; other
targets retain the painted-overlap threshold and neutral pressure.

The joining gel and its target share directional deformation and a contact rim.
The result inherits the pointer, target and existing contact cue on natural
completion. An early drop resolves the accepted pair before applying ordinary
drop rules. Same-word guidance spans levels, while actionable upgrades still
require equal levels below the maximum. No model rules or rewards changed.
All artwork and audio reuse the acquired assets recorded in
[Jelly Words](../assets/jelly-words.md).

## Verification

- Interaction suite: 1,201 checks, zero failures, across 1000 x 720 and
  390 x 844 with normal and reduced motion. New assertions check feedback before
  release, coalesced pointer input, actionable approach drops, cross-level
  guidance, continuous contact, cue deduplication, natural handoff, separation,
  pause and cancellation, with no premature completion or collection.
- Full Word Jelly view: 19,482 assertions, zero failures.
- Authored Word Jelly drag: 988,093 assertions, zero failures.
- Shared Jelly Match view: 3,084 assertions, zero failures.

Native rendered evidence is retained in the ignored `build/qa/fusion-contact/`
directory. Phone matching, phone neutral contact, desktop matching and reduced
motion were captured across approach, held fusion, natural handoff and release.
The phone contact sheet and representative native frames were visually
inspected. This is native render evidence, not a physical-device or audio
audition claim. Browser and deployment checks are recorded separately with the
release artifacts.

## Browser and deployment

The current-stage manual merge scenario passed in desktop Chromium and Pixel 7
Chromium emulation, including contact, the live fusion, one prompt pronunciation
and no collection. Evidence is in `browser-current-stage.log` and
`browser-current-stage/` under the capture directory.

Two older completion-hint browser scenarios failed during fixture discovery,
before their drag assertions. Their age-8 helper searches for two-root words,
while the live game supplies the earliest outstanding Stage 1 vocabulary. It
fills the board and reaches a disabled preview without finding that fixture.
The stage policy and discovery helper are unchanged by this fix. These failures
are retained in `browser.log` and `browser-results/`, not counted as passes;
the exact active-fusion regression is covered by the native interaction suite.

Commit `b84d1056f06efd4b33ef2f9b8dc724d322906b1c` was built and deployed to
https://gentle-forest-02ff42900.3.azurestaticapps.net/ after receipt validation.
Independent production verification matched 107 of 107 files, 232,703,319 bytes,
including SHA-256, sizes and response headers, with zero failures. The deployed
core pack is `game-7003957417c67b03.pck.br`. The immutable build receipt,
deployment log and `production-verification.json` are retained in the same
ignored evidence directory.
