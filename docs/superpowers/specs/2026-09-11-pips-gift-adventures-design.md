# Pip's Gift Adventures

The current game has several complete practice modes but weak motivation between
them: a locked gift is only a preview, and a toy repeats one short animation.
This iteration gives the player a chosen destination and a more playful payoff.
The user has authorized autonomous iteration, implementation, commit, main merge,
push and deployment. Keep the current Godot stack and imported Unity artwork.

## Player loop

1. In Pip's room, inspect any locked toy or backdrop and choose **Help Pip get this**.
   Keep **Back to my room** available. Show the gift's exact remaining pieces.
2. Save the chosen gift and its world together, then start a relevant five-word
   Learn lesson. A toy's noun must appear in this lesson. Spring uses Great outdoors,
   Summer Play time, Autumn Picnic time, Winter Music makers, Ocean Ocean discovery,
   and Space Space trip. Backdrops use the same world/topic mapping without a required noun.
3. Existing practice modes and chest claims advance the existing medal progress.
   The existing narrow goal caption shows the chosen gift, its world and remaining
   pieces. Changing worlds remains possible and must make any world mismatch clear.
4. Opening the last needed piece offers the existing Try gift control. Returning
   later to the room also offers **Play with this gift** for the saved completed goal.
   Equipment is saved through the existing room selection path.
5. Each owned toy becomes a three-step, self-paced interaction: water/grow/bloom;
   roll/return/catch; offer/nibble/finish apple; ring/answer/chime; lift/listen/waves;
   ready/ignite/launch rocket. Each step visibly changes the scene and retains the
   written noun and its recorded pronunciation. A completed sequence offers replay.

## Invariants and presentation

- No new currency, reward duplication, countdown, daily streak, payment or dependency.
- One normal win and claimed chest still earns exactly one existing medal piece.
  Learn, goal selection and toy play never grant medals or word stickers.
- Keep the same five lesson words across modes and retain semantic distractor exclusions.
- Optional saved `goal_item_id` defaults empty for existing saves. Reject invalid
  nonempty values; failed writes must preserve the previous goal, room and journey.
  Derive remaining pieces/completion from medal counts, never a second counter.
- Preserve pending rewards. Starting a gift adventure must not discard an unopened
  or unsaved chest; explain the required Back/open/retry action instead.
- Keep the current playfield/header geometry. New controls belong in the existing
  scrollable room. Touch, keyboard and controller can perform every action.
- Toy progress is temporary, local to the equipped toy. Switching toys or entering
  a locked preview resets the short sequence. No independent timers advance steps.
  Repeated input replaces animation instead of stacking; closing/hiding settles it.
- Reduced motion shows distinct static stage results, with no launch/roll animation.
- Use existing original and verified imported images. No startup network additions.

## Proof

Test goal save migration/failure, required lesson nouns and semantic exclusions,
actual scene navigation, ordinary single-piece claims, completed-goal recovery,
three distinct stages for all six toys, replay and hidden/rapid input. Playtest the
exported game on desktop Chromium and phone/tablet WebKit, plus narrow phone and
keyboard flows. Inspect screenshots, deploy the tested build and verify production
artifact hashes plus the actual gift-to-lesson-to-toy loop. Preserve the documented
Canary first-compilation limitation; this iteration does not establish its repair.
