# Pip's Gift Adventures — release verification

This iteration gives practice a chosen reward: select a locked toy or room,
start a related lesson, earn its existing medal pieces, then play with the gift.
Toy lessons always include the toy's noun. All six toys have three deliberate
steps and replay, with distinct still results when reduced motion is enabled.

## Behavior checked

- Goal and world save together; failed saves preserve the previous room, goal,
  lesson and storage bytes. Legacy saves remain compatible.
- All six toy goals and six backdrop goals choose their documented world/topic.
  The five lesson words remain the same across Learn, Match, Sky, Listen and Memory.
- A real Match win and chest claim supply the last piece. Selecting a goal,
  learning or playing a toy never grants extra pieces or stickers.
- Unopened and unsaved chests remain protected. Completed toy and backdrop goals
  remain usable after reload, including equipment-save failure and retry.
- Hidden/swiped controls cannot launch a goal. Toy replay and page hiding settle
  transient animation without affecting progress.
- Browser screenshot review caught two short-viewport issues: locked-preview
  focus hid the new goal button, and equipping a gift could leave its action below
  the viewport. The host now focuses the goal on preview and repositions the
  equipped toy action after layout. Native navigation checks failed before the
  preview fix and pass after it; browser checks use actual clicks on both buttons.
- Save/chest guidance now appears beside the goal button as well as in the room
  caption, so the retry instruction stays visible on short screens. Three native
  regression assertions failed before this change and pass after it.

## Validation

- `npm test`: **26 native suites, 13,761 checks/assertions**, zero failures;
  **100 Node passes**, zero failures, one pre-existing external chest-source skip.
- `npm run build:web`: Godot 4.7.1 export succeeds; **12.10 MB** startup transfer,
  all 140 word pronunciations retained, 28 optional audio assets loaded on demand.
- Actual exported PCK: **19 verified Unity textures and 140 original fallbacks**
  load correctly; packed texture bytes match the current import, zero failures.
- Native room evidence covers six three-stage sheets, motion variants and narrow
  captions. Goal, stage and replay controls retain their written nouns.

- Browser regression suites: **45/45** across desktop Chromium and iPhone/iPad
  WebKit profiles. Coverage includes Learn, Match, Sky, Listen, Memory/rewards
  navigation, saved equipment, drag/scroll, reduced motion, 320px and landscape.
- New gift-adventure suite: **9/9** have passing results on this final pack,
  covering the real last-piece loop, visible goal-save failure/retry, completed
  goals, touch actions, keyboard stages and reload. The iPad loop exceeded its
  90-second total test limit during four concurrent browsers; its isolated rerun
  passed in **20.9 seconds** with the same limit and no code change. The original
  timeout trace is retained, separate from `ipad-rerun-results/`.
- Reviewed browser stage pictures include flower, ball, apple, shell and rocket;
  all six toys, including bell, also have native stage/motion screenshot coverage.

Production verification is pending deployment of this tested export.

## Tested artifact

Pack: `game-2c5d82a29e601ea7.pck` (5,750,948 bytes).

SHA256: `2c5d82a29e601ea70ed5ae944a06f6e9a744f50e7636bb304c8141b41fe99905`.

HTML SHA256: `a620251661ee68b9bcbdaab98e0ad29332bd3290824d61aa2fa63595cd183177`.

Local evidence is under `build/gift-adventures/`, with native/build logs at
`build/gift-adventures-native.log` and `build/gift-adventures-build.log`.
Toy contact sheets are under `build/visuals/playroom-*.png`.

## Limits

The known Chrome Canary first uncached WASM compilation stall remains unresolved.
This gameplay release makes no claim to repair it. Browser device profiles on
Windows do not replace testing on physical iPhones/iPads. Existing word recordings
are reused; button/status checks are not a new human listening audit. Building
with the licensed Unity artwork still requires the verified ignored local import;
clean checkouts use the original SVG fallbacks.
