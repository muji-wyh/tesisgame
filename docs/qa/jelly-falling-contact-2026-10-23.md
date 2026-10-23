# Catching falling jellies

Dragging a word now detects and merges with its matching picture while the
picture descends. Both gravity after lifting a support and supply arrivals
after their scheduled departure use the current rendered outline. A stationary
pointer also receives contact when the falling target reaches it. The existing
slight-touch matching margin and strict nonmatching overlap are unchanged.

The model accepts an airborne target only for a held drop. Queued supply items,
lifted bodies and endpoints of an accepted fusion remain unavailable. An
accepted catch transfers the visible contact position to the union, clears its
fall animation and suppresses the consumed body's landing sound. The ordinary
settlement of the resulting word still runs. Canceling or rejecting a catch
preserves both independent bodies.

This behavior reuses the acquired Jelly Squash skin, word pictures and approved
audio. No assets were acquired or replaced; provenance remains in
[Jelly Words](../assets/jelly-words.md).

## Verification

- Falling contact: 355 checks passed across desktop and phone layouts, mouse
  and touch, ordinary and reduced motion, matching and nonmatching contact,
  stationary catches, incoming supply, active-fusion upgrades and cancellation.
- Existing interaction: 1,569 checks passed.
- Model: 111,961 assertions passed.
- Drag performance: 40 assertions passed.
- Full view: 17,983 assertions passed.
- Hybrid view: 57 checks passed.
- Powerup flow: 229 checks passed.

Native captures at 390 x 844 and 1000 x 720 show `walk` catching its descending
picture. Contact occurs 0.05 seconds into the ordinary fall, before its 0.36
second settlement. Reduced-motion contact is covered separately. These are
desktop renders at the stated viewport sizes, not physical-device recordings.
Evidence is retained in the ignored `build/qa/falling-contact/` directory.

The fresh Web build passed packaged-resource validation. Desktop Chromium and
Pixel 7 Chromium emulation both passed the manual matching flow (2/2), including
contact, accepted fusion, immediate pronunciation and no browser errors. The
browser drag helper follows the target's current visible position even if
lifting its support starts a fall. The packaged core is
`game-62a6de84622692d7.pck.br`; build and browser logs accompany the captures.
