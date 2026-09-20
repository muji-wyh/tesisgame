# Owned toys in Pip's home

Earned toys now appear on compact shelves inside Pip's home. Selecting a shelf
toy equips it for the existing three-step play sequence. Only unearned toys
remain in the catalog below; the catalog disappears once all toys are owned.
Ownership updates move the existing controls between these two locations so
saved selections, keyboard/controller focus and retry actions keep working.

The gesture stage remains separate from the shelves. Dragging a shelf scrolls
the page, while touching a shelf toy selects it. Locked previews can be left by
choosing an owned toy. Completed gift goals also use this owned-toy entry,
including recovery from a failed save. Room announcements report the actual
owned and locked counts for assistive technology.

## Verification

Native checks cover complete and partial ownership, dynamic unlocking without
duplicate controls, all nine toys at 320/390 px, keyboard/controller access,
legacy saves, pronunciation, room scrolling and error recovery. A compact-card
retry text overflow found during verification was fixed by allocating room for
all three lines beneath the toy artwork.

The final targeted native runs passed **1,722 assertions** across playroom view
(292), direct play (98), card polish (250), collection navigation (163), gift
adventure (138), room scrolling (17), goal text (400), recovery (36), legacy saves
(60), audio flow (106), expansion (60) and age controls (102). Asset import and
the final Web export also passed; the startup pack checked 174 optional paths
without failures.

A touch regression check now accounts for the existing scroll behavior: the
first tap stops active inertia, and the next stationary tap selects the toy.
The test verifies both steps. An earlier native ball-replay run had an isolated
sequence failure; the unchanged final suite passed. The browser regression also
exercises all three stages and replay against the exported game.

Main-change browser regression: **21 passed**, zero failures, across desktop Chromium
and emulated iPhone/iPad WebKit. Cases cover starter (1 owned / 8 locked), partial
(3 / 6) and complete (9 / 0) homes, touch selection, unchanged medals, leaving a
locked preview, failed-save recovery, 320 px retry text, reduced motion, and
completed-goal keyboard play/replay.

```powershell
$env:POP_BASE_URL = 'http://127.0.0.1:4173'
$env:POP_QA_LABEL = 'owned-toys-home-browser'
npx playwright test tests/browser/owned-toys-home.spec.cjs tests/browser/gift-adventure.spec.cjs tests/browser/card-polish.spec.cjs tests/browser/expansion.spec.cjs --config build/voice-pop.config.cjs --grep 'toys live|locked preview returns|earned saved goal|failed-load retry|starter toy remains'
```

Inspected real canvas screenshots in
`build/voice-pop-qa/owned-toys-home-browser/`: desktop partial and complete homes,
iPhone partial home and all nine toys, iPhone locked cards below the home, iPad
complete home, and 320 px / iPhone save-error cards. Shelves remain inside the
home border, full toy names and error labels fit, and only locked toys appear
below the room. Small screens scroll to the lower shelves without showing an
empty locked catalog after all toys are earned. WebKit profiles are browser
emulation, not physical-device testing.

## Visual follow-up

The first production screenshot pass exposed clipped second lines in owned-toy
names at 768 and 1366 px (for example, `Jungle monkey` showed only `Jungle`).
The prior mobile-only full-name assertions missed this scaling issue. Titles now
have a 42 CSS px region and zero extra line spacing, and the chosen font size is
bounded by the actual height of two lines. The owned-card size remains 108 px.

The expanded collection-navigation check passed 163 assertions at 320, 390, 768,
1366 and 1920 px; the 250-assertion card-polish suite also passed again. The
42 px title region fixes the previously observed cut-off text without changing
toy ownership, selection, gestures or save handling.

The rebuilt export then passed all **9** Chromium acceptance cases at 390x844,
768x1024 and 1366x768 (each with starter, partial and complete ownership).
Real screenshots under `build/voice-pop-qa/owned-toys-home-final-local/` confirm
the complete `Jungle monkey` name on the tablet and `Autumn apple` on desktop,
with room boundaries, selection and locked cards below still intact.

## Production acceptance

Runtime commit `2028b59` (including the main ownership change `0ce3bf8`) was
merged into `main`, pushed to GitHub and deployed to
https://gentle-forest-02ff42900.3.azurestaticapps.net/.

All four startup files fetched from production match the tested local export
by SHA-256. The exact file sizes and hashes are recorded in
`2026-09-20-owned-toys-home-production-manifest.json`.

The final production run passed all **9 / 9** acceptance cases, with zero
browser errors: 390x844, 768x1024 and 1366x768, each with 1/8, 3/6 and 9/0
owned/locked partitions. Actual touch selection, locked preview return and
failed-save retry preserve the earned medal counts. The tablet complete-home
and desktop locked-preview screenshots were checked again after deployment;
wrapped names are now complete and the lower catalog contains only locked toys.

Final production screenshots and per-case reports:
`build/voice-pop-qa/owned-toys-home-final-production/`.
The fixture saves are isolated browser profiles; no existing player saves were
changed by acceptance testing.
