# Three Hints Per Round Design

## Goal

Increase Match mode from one hint to three successful hints per round without changing scoring, board rules, or the shared touch, keyboard, and Xbox input path.

## Behavior

- A new round starts with three hints remaining.
- A successful hint highlights one available word-picture pair and decrements the remaining count.
- Pressing Hint again while a hint is already highlighted does nothing and spends nothing.
- Requests during feedback or after the round ends do nothing and spend nothing.
- Selecting, cancelling, or resolving cards may clear the current highlight but does not refund a hint.
- Changing the reward world preserves the current allowance. Starting a new round restores all three hints.
- The button reads `Hint 3`, `Hint 2`, `Hint 1`, then `Used` and becomes disabled.

## Implementation

Replace the model's `hint_used` boolean with one `hints_remaining` integer and a fixed maximum of three. Keep `request_hint()` as the single shared entry point; it decrements only after finding and displaying a valid pair. The UI reads the model counter directly, so all input methods stay consistent.

Update current player-facing help, README text, changelog text, and focused native/browser tests. Historical design and release documents remain unchanged.

## Verification and Release

Run the focused model/UI/browser hint checks, the full native suite, and the Web build. Then commit the implementation, push `main`, deploy the verified export with the existing Azure command, and confirm production serves the new build and allows three hints.
