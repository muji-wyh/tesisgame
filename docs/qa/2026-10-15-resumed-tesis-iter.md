# Resumed tesis-iter work

The interrupted `tesis-iter` conversation was reviewed through its latest ten
turns and all 123 older available turns. This change completes its nine latest
unfinished requests in the `codex/current-age-vocabulary` worktree.

## Delivered behavior

1. Difficulty advances after every four successful clears, with five increases.
   Jelly Words supply intervals are 20, 18, 16, 14, 12 and 10 seconds; Jelly Match
   intervals are 10, 9, 8, 7, 6 and 5 seconds. The interval currently shown by Next
   stays fixed until dispatch, when the next complete cycle adopts the new pace.
2. Jelly Words has a quiet cloud pattern inside its rounded well. The acquired
   Kenney artwork, CC0 license, original source, inspection and integration are
   recorded in [the asset provenance](../assets/jelly-well.md).
3. The danger glow uses the same scaled corner radius as the well.
4. Pointer navigation no longer leaves a dark keyboard focus ring on the Home
   game card. Keyboard and controller navigation retain a visible focus ring.
5. Collect shares the rounded card layout of Auto merge and Treasure. Its title,
   artwork and count have stable positions while the artwork retains its charge
   and collection feedback.
6. Jelly Words drops each Next slot directly into its displayed column whenever
   that column's entry is open. A sealed entry uses the existing reachable
   fallback; a completely sealed board preserves the unreleased FIFO prefix.
7. Chest opening retains cavity light and sparkles without a rainbow arc.
8. Home and Play again claim and durably save earned, unopened chests before
   leaving a completed round. Failed saves retain the current screen for retry
   without duplicate credit. Reentering a completed mode starts a fresh round;
   unfinished rounds still support Continue. Pop uses the same exit contract.
9. Pulling Finish shows the centered two-line instruction `Drag to` / `finish`
   and restores its ordinary label after recovery.

## Verification

Nineteen targeted Godot suites passed with 287,590 assertions and no failures:

| Area | Suites | Assertions |
| --- | --- | ---: |
| Difficulty and placement models | Jelly Match, Jelly Words | 253,920 |
| Finish and well presentation | Finish pull, Match view, Words view | 25,221 |
| Settlement and rewards | Settlement modal, Jelly coins, danger game over, library, chest reveal, round celebration, Pop reward flow, Home navigation, chest charge, coin rewards | 6,836 |
| Existing interactions affected by pacing and lifecycle | Memory scene, Phrase scene, UI click, UI recovery | 1,613 |

Native visual review covered 1366 x 768, 393 x 852, 320 x 568 and 852 x 393.
Staged screenshots exercise the charged Collect card, danger border and Finish
instruction. They are presentation evidence rather than naturally played rounds.

The Web export passed startup-pack, vocabulary, chest and audio checks. The build
receipt verified 12,679 source inputs and 117 output files. Independent production
diff review found no actionable issues in reward idempotence, failed-save retry,
Home/replay behavior, supply timing, preferred columns or the presentation changes.

Thirteen targeted browser cases passed:

- Chromium mouse and native touch Finish gestures, plus Chromium and iPhone
  WebKit Collect sequences: four passes. Two existing WebKit Finish entries are
  skipped because this suite uses Chromium's native touch dispatch protocol.
- Normal and reduced-motion chest opening without a rainbow, Words danger
  settlement followed by Home and a fresh round, unopened Match treasure with
  Play again, and unopened Phrase treasure with Home: five passes.
- Jelly Words and Jelly Match difficulty in Chromium and iPhone WebKit: four
  passes. Each uses four real successful clears and observes the next complete
  18- or 9-second cycle, unchanged active intervals and preview-column placement.
  The interaction fixture waits for settled pairs and permits legitimate timer
  rollover during slower input instead of assuming a clear completes instantly.

Browser captures were inspected for Collect at zero, one and three words, chest
opening phases, fresh Match/Phrase boards with the credited coins, and Next
departures on an uneven Words board. Local artifacts are retained under
`build/resume-ui-browser`, `build/resume-settlement-browser` and
`build/resume-difficulty-browser`. Repository diff and JavaScript syntax checks
also passed.

## Remaining external limitation

The older Windows Playwright WebKit live-resize failure remains reproducible in a
standalone WebGL canvas without the game. Its composed page becomes blank while
the raw canvas still renders correctly; Chromium passes the same diagnostic.
Fixed-size browser passes do not resolve this issue or establish the behavior of
physical iPhone/iPad Safari. See the [reproduction and investigation](2026-10-15-webkit-resize.md).
