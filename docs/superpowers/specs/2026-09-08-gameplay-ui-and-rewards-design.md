# Gameplay UI and Rewards Design

## Goal

Simplify the game chrome, make feedback more playful, and turn the seasonal chest into a draggable long-press reward interaction with a persistent collection page.

## UI

- Remove the `Word Buddies`, Mute, Listen, and bottom instruction controls.
- Put match and mistake indicators at the top-left. Each earned point is one colored icon, with accessible text in tooltips and browser announcements.
- Replace the season popup with four always-visible season icon buttons. Keep reduced-motion support as a compact toggle because it is an accessibility control.
- Add one `Rewards` button that opens a full-screen in-game collection view; Back returns to the current round without resetting it.

## Feedback

- Correct pairs briefly scale and bounce before settling.
- Incorrect pairs shake horizontally and rotate slightly before settling.
- Reduced-motion mode skips both animations.

## Rewards

- Each season defines ten named reward variants, for forty total.
- Every variant has its own generated SVG. The existing image generator produces forty deterministic collectible badges without a new artwork dependency.
- A win selects one variant from the current season when chest charging begins.
- Opening records the reward in `user://rewards.cfg`. Duplicate rewards remain collected once.
- The collection page shows all forty slots and clearly distinguishes locked and collected variants.

## Chest interaction

- Pointer or touch movement drags the chest artwork inside its stage, clamped so it remains visible.
- A stationary press charges for 1.2 seconds. Shaking increases with charge progress; no progress bar is shown.
- Releasing early cancels the charge. Moving far enough to drag also cancels the charge.
- Completing the hold starts the existing 1.8-second themed opening and celebration.
- Keyboard activation remains available through a focused button and uses the same charge path.

## Validation

- Extend the existing Godot tests for ten rewards per season, reward persistence helpers, icon counters, feedback animation state, drag bounds, and long-press-only opening.
- Update browser tests only where removed controls or the new hold gesture change the public UI flow.
