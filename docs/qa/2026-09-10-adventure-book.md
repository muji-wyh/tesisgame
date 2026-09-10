# Adventure book release verification

## Scope

Pip's adventures makes the existing twelve vocabulary topics deliberately selectable. Explore in Learn and New adventure on results open the illustrated book; each destination starts a five-word Learn lesson. Back preserves the current lesson and attempt. Visits indicate exposure only. Existing medals, gift unlocks and personal room choices remain authoritative.

The optional journey section saves unique known destinations, most recent first, and an explicit preferred world in the existing personal-choices record. Failed reads/writes preserve stored data and allow play; the book exposes a retry. Restoring a previously unreadable record also recovers its preferred world unless the player already chose another world in this session.

## Native and Node checks

- Godot import/export completed. All 17 native suites passed, totaling 7,926 checks, including 1,975 adventure-model checks, 636 personal-choice persistence checks, 704 book-view checks and 42 book scene checks.
- All 90 Node cases ran: 89 passed and one pre-existing external-source-pack checksum case skipped because its source pack is unavailable.
- A native fixture shutdown race was reproduced in 3 of 8 runs: the Dummy audio mixer had not yet reclaimed the final stopped WAV playbacks when the process quit. The lesson test now waits on weak references to the actual playback objects, with a two-second bound and an explicit release assertion. Eight subsequent verbose runs passed without resource leaks. No production audio code changed.
- The host extraction test now normalizes CRLF before matching its JavaScript methods, matching Windows checkouts. Both affected host cases and the complete Node suite then passed.

## Browser and visual checks

- The three new book cases passed on desktop Chromium, iPhone WebKit and iPad WebKit: 9 passes. They cover explicit animal/picnic vocabulary, five distinct words, Back preserving card position, visit failure/retry, reload, preferred world, room and medal preservation, swipe cancellation, restored opener focus, and keyboard access to the last offscreen topic.
- The full learning and playroom browser suites passed on all three profiles: 33 passes. A further 9 controller, adventure-rotation and repeated-lesson medal-assembly cases passed across those profiles. Total changed-area browser verification: **51 passed, 0 skipped, 0 failed**.
- Native screenshots at 320px and 960px and actual browser phone/tablet/desktop screenshots were inspected. The representative SVGs, topic names, visit states, suggestion and retry controls are readable; current and suggested destinations remain distinct.
- Local release smoke passed: book opening, explicit Animal friends selection and persisted visit, Learn pronunciation, Match selection/cancel, Sky feedback/Continue, Listen, and the starter room toy. No browser errors.

## Artifact

- Export command: `npm run build:web`.
- Startup download: 10.87 MB; 140 word pronunciations remain bundled and 28 optional audio assets load on demand.
- Pack: `game-71522da7333b637e.pck`.
- SHA256: `71522da7333b637e862c6241c8f37214c4c08251e8efc0af3fdcb24302d5dd32`.
- Independent review found and verified the recovered-world preference fix; no remaining release blocker was reported.

## Production

Implementation commit `51c121a` was fast-forwarded into `main` and pushed to origin. `npm run deploy -- -SkipBuild` successfully deployed the tested export to https://gentle-forest-02ff42900.3.azurestaticapps.net/.

The production HTML references the pack above, and its downloaded SHA256 exactly matches the local tested pack. A fresh production Chromium session passed book opening, explicit Animal friends selection and saved visit, Learn pronunciation, Match selection/cancel, Sky feedback/Continue, Listen, and the room toy action and save. No browser errors were observed.

This release uses the existing original word illustrations. The earlier real Unity Store package download and CLI import remains incomplete and separately documented in `docs/assets/unity-art.md`; this work did not resume the stopped native Computer Use operation.
