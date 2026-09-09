# Playful Chest Reveal Plan

**Status:** Implemented. Three fragments complete each of six active medals per
theme; earlier whole rewards are preserved during migration.

**Goal:** Make opening a chest feel like discovering and assembling something,
not just watching particles before an item disappears into the collection.

**Architecture:** Keep the current Godot scene, imported chest artwork,
long-press interaction, seasonal effects, and reward-preview controls. Add a
small shared medal-piece view only when fragment progression is implemented.
Keep earned progress independent of cosmetic animations.

**Tech stack:** Godot 4.7, GDScript, native Controls/Tweens, ConfigFile, and the
existing native and Playwright test runners. No new runtime dependency.

## What the game already does

The source currently provides:

| Existing behavior | Source |
| --- | --- |
| A stationary 1.2-second hold, cancelled by early release or dragging | `scripts\game_ui.gd`: `_start_chest_hold`, `_process`, `_chest_input` |
| Idle bobbing, stronger charging shake, and a 1.8-second opening | `scripts\chest_view.gd`: `_fit`, `start_open`, `_process` |
| Seasonal light, two rings, and 72 particles with a 4.8-second lifetime | `scripts\celebration.gd`: `start`, `_draw`, `LIFETIME` |
| A medallion pop followed by a flight to My rewards | `scripts\game_ui.gd`: `_start_reward_delivery`, `_place_reward_flight` |
| One-shot opening and saving before cosmetic reward delivery | `scripts\game_model.gd`: `begin_open`, `finish_open`; UI: `_on_chest_opened`, `_record_reward` |
| Reduced-motion handling, controller hold, and page-hide cleanup | UI: `set_reduced_motion`, `_controller_accept`, `on_page_hidden` |

The missing ingredient is not more effects. It is a visible connection between
this chest, the piece just earned, and a medal the child is building.

## Options considered

| Direction | Advantage | Drawback | Recommendation |
| --- | --- | --- | --- |
| More particles and bigger flashes | Small implementation cost | Quickly becomes repetitive; does not explain progress | Do not make this the main change |
| A puzzle or precision drag to unlock each chest | More direct interaction | Adds another failure point after the child already won | Avoid mandatory puzzles and precise drops |
| A responsive chest followed by automatic medal assembly | Anticipation, visible progress, and a distinct completion moment | Requires careful fragment persistence and migration | Recommended |

## Recommended player experience

### 1. Make the unopened chest react

- Keep the existing 1.2-second hold. Do not require extra taps before it works.
- A brief tap gives one small wiggle and a glint: an invitation, not a penalty.
- Holding progressively brightens the chest seam while the current shake grows.
  No progress bar, flashing screen, or numeric countdown.
- Dragging the closed chest remains optional play. It cancels charging and
  stays within the panel.
- Show a compact view of the current medal and its progress near the chest:
  for example, one filled piece and two missing pieces.
- Caption: **Hold to find a piece!**

### 2. Reveal one unmistakable prize

- Keep the existing 1.8-second lid/opening sequence.
- The light focuses on one large fragment rather than obscuring it.
- Use a smaller 24-particle burst for an ordinary fragment. Reserve the full
  existing 72-particle celebration for completing a medal.
- Show **A new piece!** and a simple count such as **2 of 3**.
- The fragment has the same shape, artwork, and orientation as the gap it fills.
  Avoid a generic token that turns into an unrelated medal afterward.

### 3. Let the piece snap into its medal

- After a short reveal, the piece automatically moves into the nearby medal
  preview. The child can tap it or press A/Enter to place it sooner.
- Placement always succeeds. Do not require aiming, rotation, matching a
  silhouette under time pressure, or another correct answer.
- The filled region remains visible after the motion ends. This is the
  central moment: **I can see what my win added.**
- Ordinary fragments stay represented in the partial medal. They do not need
  a second flight animation into My rewards.

### 4. Make a completed medal feel different

- On the final fragment, join the seams and briefly enlarge the complete medal.
- Play one seasonal celebration and show **Medal complete!**
- Show the season goal separately: for example, **Spring: 2 of 6 medals**.
  Do not confuse fragment progress with completed-medal progress.
- Only the complete medal makes the existing flight to the collection entry.
- Allow the completed medal to use the existing bounce/twirl/hug preview.
- Keep **Play again** obvious; use the existing collection entry to inspect
  the medal. No forced extra menu or automatic next round.

### Animation budget

These are proposed target durations, not new delays to add before the existing
sequence. Ambient particles may finish in the background without blocking input.

| Moment | Proposed duration |
| --- | --- |
| Player hold | Existing 1.2 seconds |
| Chest opening | Existing 1.8 seconds |
| Fragment shown clearly | About 0.35 seconds |
| Automatic snap into medal | About 0.45 seconds |
| Completed-medal celebration, only when earned | About 0.8 seconds |
| Completed-medal flight | About 0.4 seconds |

After the hold, aim for less than 3 seconds for an ordinary piece and less than
4 seconds for a completed medal. Once saving succeeds, Play again can settle
the cosmetic sequence immediately rather than making the player wait.

## Fragment progression

Use **three fragments per medal** and **six medals per theme** for the requested
implementation.

- Four themes, six active medals each: **24 complete medals**.
- Three pieces per medal: **18 wins per theme**, or **72 wins for a new full set**.
- One won round contributes exactly one fragment after the chest opens.
- Finish one medal at a time within each theme. Do not scatter random fragments
  across all six medals or award duplicate fragments.
- Changing themes changes the active goal, not progress already earned.
- Hints do not reduce fragment quality or require extra wins.
- After all six medals in a season are complete, further wins can still open
  the chest for a cosmetic celebration. Show **All six collected!**; do not
  invent a seventh medal, reset progress, or disguise a duplicate as new.
- Start with three large, clearly shaped pieces. Increasing to four or more
  should require observing that children want longer goals, not assuming it.

## Layout and seasonal identity

- The chest remains the main object, with one active medal preview and one
  short caption. Avoid showing all six large medals on the opening page.
- Portrait: large chest above the result controls; keep the partial-medal
  preview inside the lower part of the artwork panel.
- Landscape: retain the existing artwork/text split, placing the active medal
  with the result text when space allows.
- At the minimum 320px viewport, collapse the preview to one compact badge and
  its piece count. Do not push Play again outside the viewport.
- Collection: show six active medals per theme in a 3-by-2 portrait grid,
  with distinct empty, partial, and complete states.
- Reuse the current green Spring, red Summer, gold Autumn, and outlined white
  Winter palettes. Keep their existing particle trajectories.
- Spring can emphasize a petal/glint, Summer a sunburst, Autumn a falling leaf,
  and Winter a crisp crystal sparkle. These are small treatments of existing
  art, not four new interaction systems.

## Persistence and existing rewards

The current save stores ten whole rewards per theme in `user://rewards.cfg`.
Do not replace that with six empty medals or silently delete earlier rewards.

Recommended migration for a first implementation:

1. Keep the existing forty reward definitions and the old save readable.
2. Use the first six existing reward IDs in each theme as the six active medals.
   Reuse their artwork, after visually confirming the name and image agree.
3. Map an already-earned active reward to a completed medal, never to a fragment.
4. Keep earned rewards numbered 7-10 in a clearly labeled **Earlier rewards**
   section, using the existing preview. They are not extra active medals.
5. Store new progress in a versioned `user://medals.cfg`, with integer counts
   from 0 to 3 keyed by active medal ID. Leave the old save unchanged.
6. Migrate only when the new file is genuinely absent. A malformed or unsupported
   file must show an error, not trigger a reset disguised as migration.

Select and lock the next fragment when opening begins. Commit it exactly once,
before showing it as added to the medal. Use one captured before/after count,
not a fresh random choice on animation callbacks or retry.

A failed save leaves previous progress intact and offers **Retry saving** for
that same fragment. Retrying, hiding the page, changing motion preferences,
opening the collection, or replaying must not grant another piece.

Keep this local and single-player. Do not add an account service, cloud sync,
currency, rarity tiers, or a general inventory framework.

## Implementation stages

### Stage 1: Responsive chest, without changing saved rewards

**Files:** `scripts\chest_view.gd`, `scripts\game_ui.gd`,
`tests\godot\run_tests.gd`, `tests\browser\godot.spec.cjs`.

- [x] Add a finite short-tap reaction and a seam glow driven by the existing
  `hold_progress`, without extending the hold time.
- [x] Cover early release, drag cancellation, repeated input, controller
  disconnect, and reduced motion before changing the animation.
- [x] Keep the chest's hold/open input contract while introducing fragment
  display only together with its progress storage.

### Stage 2: Six-medal progression and safe migration

**Files:** `scripts\game_data.gd`, a focused `scripts\medal_progress.gd`,
`scripts\game_ui.gd`, `tests\godot\run_tests.gd`.

- [x] Implement three pieces per medal. Derive the active set from six stable
  IDs per theme.
- [x] Add progression, version validation, migration, and persistence in one
  small module. Cosmetic drawing and tweens never grant or save rewards.
- [x] Cover 0-to-1, 1-to-2, and 2-to-3 transitions; no duplicates; all-six
  completion; old first-six rewards; old 7-10 rewards; repeated migration;
  corrupt data; failed writes; and repeated save retries.

### Stage 3: Fragment reveal, assembly, and collection

**Files:** one shared `scripts\medal_view.gd`, `scripts\game_ui.gd`,
`scripts\celebration.gd`, native/browser tests.

- [x] Draw the medal's three pieces from the same artwork in the reveal and
  collection, instead of generating separate fragment-image downloads.
- [x] Replace the ordinary reward flight with the short automatic snap.
  Tap/A/Enter can finish that cosmetic action, never grant the reward again.
- [x] Add the smaller fragment burst and the distinct completed-medal sequence.
- [x] Render six active medals per season, progress counts, and preserved
  Earlier rewards. Keep collection scrolling and preview focus intact.
- [x] Use existing sound effects initially. Do not play existing speech that
  announces a whole flower/sun/leaf/snowflake when only a fragment was earned.
  Correct card pronunciation remains unchanged.

### Stage 4: Accessibility, play observation, and release

**Files:** existing test files, `README.md`, `web\shell.html`.

- [x] Reduced motion shows the opened chest, awarded piece, and updated medal
  immediately after the hold, with no bob, shake, particle burst, or flight.
- [x] Announce both levels of progress clearly, for example:
  **Blossom, piece 2 of 3. Spring, 1 of 6 medals complete.**
- [x] Keep every required action reachable with touch, keyboard, and Xbox.
  Preserve at least 48px touch targets and visible focus.
- [x] Exercise page hiding at every stage, replay during cosmetic movement,
  resizing mid-flight, repeated input, and failed or delayed optional audio.
- [x] Run the existing native and relevant browser suites against the exported
  game, including collection scroll and reward persistence regressions.

Manual follow-up, not an automated release claim: observe whether a child
understands what a fragment added and wants to finish a medal. Automated checks
do not establish increased enjoyment or recognition accuracy.

Release procedure: commit the verified source to main, push, deploy the same
export, and exercise the published game through the existing release process.

## Acceptance criteria

- A child can see what this win contributed without opening another page.
- Ordinary pieces and complete medals have visibly different celebrations.
- Every piece advances a known goal; no duplicate fragments or unlucky gaps.
- Opening remains a simple hold, with optional playful reactions rather than
  another skill test.
- All six medals and all previously earned rewards remain accounted for.
- Interrupting an animation neither loses nor duplicates saved progress.
- The page remains usable on a small phone, without sound, and with reduced motion.
- The separate round rules remain **one hint and three mistakes per round**.

**Not included:** precision dragging, paid rerolls, rare fragments, daily timers,
extra lives, or paid reward mechanics.
