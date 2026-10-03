# Cross-page presentation review

## Direction and changes

Pip and Words remains a friendly vocabulary game for children, with touch,
keyboard, and controller input. The revised interface uses warm paper, forest
green, and bundled Nunito rather than mixing a bright board with navy utility
pages. Existing sourced characters, word illustrations, islands, rooms, chests,
and audio remain the game material.

- The small Pip popover became an illustrated four-game library. Each game has
  its core action, microphone requirement, and time or campaign scale beside it.
  Pip and the visible mode title open it; Back, Escape, and outside dismissal
  resume the interrupted game through the existing pause lifecycle.
- Sound and motion controls persist independently of scores and treasures. Motion
  follows the system until explicitly changed. Loading-page sounds, animation,
  and browser speech effects also respect these choices.
- Match, Memory, the playroom, vocabulary, players, leaderboards, results, Voice
  Pop, and Talk Quest navigation/intermissions share type, surfaces, and action
  hierarchy. The player picker has wide name targets instead of tiny chips.
- Responsive review corrected short-landscape card targets, two-line toy save
  errors, and a deferred player-list callback whose target could already be freed.

The font was acquired and integrated under the SIL Open Font License. Existing
Twemoji and Kenney illustrations were inspected and reused for the library.
[Source and license details](../../assets/fonts/SOURCE.md) distinguish these
integrated assets from the separate guardian replacement review.

## Evidence

The maintained [visual review](../../tests/godot/presentation_visual_review.gd)
uses the real main scene with isolated saves. It covers desktop 1280 x 800 and
phone 390 x 844, plus compact 320 x 320 and landscape 844 x 390 libraries. Local
captures are in `build/presentation-review/`; before captures are retained in
`build/taste-before/`. These generated artifacts are not required in a checkout.

All 95 Godot regression suites passed, resuming from failures after fixing the
affected code or updating an obsolete presentation assertion. The 150-word,
six-size vocabulary matrix passed 16,201 checks. All 331 Node tests in 23 files
passed; their final log is `build/presentation-node-tests.log`.

The final native pass produced 44 captures. The focused presentation, menu, and
release-layout suites were repeated after the last layout fixes (46, 198, and 52
checks). Browser inspection additionally found Pip painting above the compact
library and loading copy pushing the entry button below 320 x 320; both were
corrected. Static Nunito instances corrected Windows WebKit's variable-font
weight rendering and were inspected in both browser engines.

Eighteen selected browser cases passed across desktop Chromium and iPhone
WebKit emulation: responsive mode switching, library dismissal and title entry,
presentation persistence, system motion changes, loading preferences and layout,
room/toy input, and player editing with cancellation, failed saves, and reload.
The final integration batch passed all 14 cases. Browser screenshots and traces
are retained under `build/presentation-browser-final/`; loading review captures
are under `build/presentation-loading-final/`.

The final exported package also passed fresh Chromium and WebKit entry, player
creation, and library-input smoke checks with no captured browser errors. The
bundled navigation glyph was checked in the native font and the final canvas
captures (`build/presentation-review/final-*.png`). The packaged startup is
33.07 MB; source/export fingerprints and `git diff --check` passed.

## Limits

Native captures use the Dummy audio driver because this host has no working
output device. This review does not establish acoustic quality or live microphone
recognition. Browser speech tests use simulated callbacks or the unavailable
speech path; emulation does not establish physical Safari behavior. Windows
WebKit page captures can become blank after viewport changes while the raw
canvas still renders. The browser library review retains both images and checks
the canvas separately; this is not presented as proof of on-device rendering.

The existing Talk Quest guardian replacement proposal still has its own source
acquisition and animation dependencies. This interface pass does not claim those
proposed creatures have been integrated. Gameplay rules, score semantics, save
formats, and chest timing remain intact.
