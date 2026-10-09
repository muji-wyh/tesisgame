# Grow with Pip release verification

## Scope

The game now uses a device-local Lv3–Lv12+ learning path. Correct completed
activities increment each unique involved word; mistakes reset those words;
six consecutive successes mark mastery. Completing the current cohort promotes
Pip permanently. Browsing future words never changes the earned level.

The release contains 1,550 words, 330 recorded phrases, ten Pip appearances,
cumulative gestures and ten approved Ava voice lines in the interactive review.
Usernames, identity avatars, leaderboards and Pip's room are retired. Existing
world preferences, treasure saves and four-mode celebration ownership remain.

Curriculum membership and its ESL interpretation are documented in
[the curriculum notes](../vocabulary/growth-curriculum.md). Contextual words
without authentic illustrations have a reachable Phrase Builder activity and
are labelled accordingly in the notebook. Source and voice provenance are in
[growth vocabulary](../assets/growth-vocabulary.md),
[Ava recordings](../assets/ava-voice.md) and [Pip stages](../assets/pip-growth.md).

## Automated and rendered evidence

- The complete Node plan passed **323 tests across 23 files**, with no failures
  or skips. It includes storage verification, failed writes, stale-tab comparison,
  vocabulary reachability, audio hashes, retired-resource exclusion and the
  exact preview packaging inventory.
- Growth state passed **236 checks**; actual four-mode integration passed
  **43 checks**; lesson navigation passed **17 checks**. These cover duplicates,
  wrong resets, permanent promotion, failed-save ordering, startup read failure,
  reloading and rebasing accepted events on another tab's newer state.
- The main model/scene suite passed **18,192 assertions**, including real board
  reachability for all **1,285 pictured words**. Adventure and spoken-match
  model suites passed **2,788** and **3,634** assertions respectively.
- Phrase model and scene suites passed **15,331** and **1,185** assertions.
  They retain optional pictures, drag/reorder behavior, all answer slots,
  long-word scrolling and readable prompts. The final scene check includes
  desktop, phone portrait, short landscape and 320 × 320 layouts.
- Presentation preferences passed **78 checks**. Growth Pip integration passed
  **626 assertions**. Targeted age, catalog, vocabulary layout, Pip expressions,
  motion, feedback, audio and Voice Pop reward suites also passed during this
  implementation. The final catalog check passed **8,862 assertions**.
- Shared round celebration flow passed **118 checks**, including all four
  modes and Voice Pop's 0/1/2/3-chest paths. Interface-click checks passed
  **46 assertions**.
- The exported startup pack loaded all **1,550 word pronunciations**, the
  **330 phrase recordings**, required game effects and reference audio with
  zero validation failures. It verified eight chest types and five animated
  models, and found zero retired resources. The packaged startup is **50.75 MB**.

Rendered native captures were inspected at 1366 × 768, 390 × 844,
844 × 390 and 320 × 320. The smallest Phrase layout keeps a visible progress
bar and level in the heading; the full-sized More button still opens the notebook.
The answer button, prompt and scrolling word rails remain visible.

The Pip preview was exercised on desktop Chromium, an iPhone 13 WebKit profile
and 844 × 390 Chromium. All ten stages, gestures, reduced-motion responses,
audio playback and cancellation were checked. All 68 shipped review files are
byte-checked; generators, test scripts, voice caches and captures are excluded.

## Regressions found and repaired

- Explicit board seeds had inherited the previous board's exclusion order.
  Seeded boards are reproducible again; ordinary rounds still favor fresh words.
- The browser's eval-based preference save did not reliably return success to
  Godot. Explicit host storage methods now read back the exact saved value.
- Growth save failures in Memory, Phrase and Voice Pop now refresh the common
  Retry saving control immediately. An unreadable initial growth save gates play
  until recovery, preventing untracked answers.
- Stale browser instances rebase on current durable state before applying their
  queued attempts, preserving wrong resets and other instances' promotions.
- The new growth row exposed a Phrase footer overflow on very short screens;
  the compact layout now fits without shrinking interactive targets below 44 px.
- The expanded audio list exceeded Windows' command-line limit. Pack validation
  now receives a manifest file and retains the complete verification scope.
- A failed theme save already displayed its retry notice in the notebook, but
  the accessible status omitted it. The status now includes the same notice;
  the 43-check native growth flow passed again after this change.

## Evidence limits

Browser device profiles are emulation, not physical iPhone/iPad testing. Speech
tests inject recognition callbacks; they do not measure acoustic recognition.
Audio decoding, hashes and playback checks do not establish subjective listening
quality. The preview remains the user-facing review surface for the ten voices.

The full browser inventory was not run as one release suite. The focused release
results are recorded below. No new performance improvement percentage is claimed.
`localStorage` comparison prevents stale sequential overwrites but is not an
atomic cross-process transaction during precisely simultaneous writes.

## Focused browser release checks

The four core growth cases passed on desktop Chromium, iPhone WebKit and iPad
WebKit: **12 passed cases**. They exercised the initial Lv3 notebook, real Match
and Memory answers with neutral peeking, Phrase mistakes and corrections with
unused distractors left unchanged, and promotion after a sixth real success
followed by a reload. The separate desktop two-tab case also passed, preserving
both tabs' completed word practice and the saved state after reload.

The two-tab check initially exceeded its 90-second harness budget during the
final reload. Its assertions passed when rerun with a 150-second budget; no
production change was needed. Logs are retained locally as
`build/growth-browser-desktop.log`, `build/growth-browser-tabs.log` and
`build/growth-browser-mobile.log`.

Nine additional desktop regression cases passed: all ten age catalogues,
catalog artwork and pronunciation, the notebook's Pip preview link, trusted
Memory touch release/cancellation, chest opening and New adventure, notebook
Back navigation, all eight world preferences, compact-world save recovery,
and Voice Pop startup without identity or speech-model downloads. This makes
**22 focused release cases passed**, in addition to the separate Pip preview
review described above.

The first regression run passed seven cases and exposed two follow-ups. The
preview assertion needed to include its intentional `#lv3` fragment. The theme
save check exposed the missing accessible failure announcement recorded above.
After fixing those issues and rebuilding, both cases passed. The logs are
`build/growth-browser-regressions.log` and
`build/growth-browser-final-retry.log`.

## Release artifact

The final successful export receipt verifies **7,234 source inputs and 85 output
files**. Deployment uses the existing Azure Static Web App at
<https://gentle-forest-02ff42900.3.azurestaticapps.net/> and the review route at
<https://gentle-forest-02ff42900.3.azurestaticapps.net/preview/pip-growth/>.
The production verification script compares the served HTML, content-addressed
game pack and all 68 preview files against this verified export, and records the
commit, hashes and check time locally in `build/growth-production.json`.
