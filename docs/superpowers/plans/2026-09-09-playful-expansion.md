# Word Buddies playful expansion

Keep the existing Godot browser game and its matching, voice, chest, and safe medal-save flows. The user's expanded request authorizes new game modes beyond the earlier matching-only design.

## Player experience

- Six visual worlds: the four seasons plus Ocean and Space; six active medals per world.
- 140 illustrated, pronounced words grouped into coherent rotating adventures.
- Three visible game choices: Match, Sky words, and Listen. Choice rounds need five correct answers before three mistakes, with no countdown or speed penalty. Sky words lands a picture above two word choices; Listen gives a replayable spoken prompt and two pictures.
- Selection ripples and success sparks respond once per action, with static reduced-motion equivalents.
- Pip dances, snacks, and blows bubbles. The reward room offers these activities and a favorite medal display.
- Every successful mode uses the same one-piece chest reward flow. Existing saves remain valid.

## Implementation ownership

1. Catalog and original SVG/audio expansion: gameplay_review agent.
2. Duck tricks and card feedback: adventure_ui_tests agent.
3. Self-contained choice-mode Control and rule tests: review_adventures agent.
4. Root: main UI integration, mode/result transitions, reward-room activities, favorite persistence, responsive and accessibility verification.

## Verification

Run native rules and UI regression suites, Node asset/host/export checks, then export and exercise all modes on desktop Chromium and phone/tablet WebKit. Verify choices cannot double-award, switching/replaying clears feedback, rewards remain one-shot, audio stays gesture-controlled, dialogs retain focus, touch targets fit small windows, and reduced motion cancels effects. Inspect screenshots of each new mode and the reward room. Do not publish or push.
