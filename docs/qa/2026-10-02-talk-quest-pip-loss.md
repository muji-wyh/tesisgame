# Talk Quest countdown and Pip rematch

## Changes

- Every word in all fourteen levels now has a ten-second lifetime. Older saved
  active words retain their elapsed age while adopting the longer limit.
- After the last earned projectile lands, Pip replaces the guardian on the
  rematch screen. His existing articulated artwork performs a 2.4-second sad
  reaction, then a high five with supportive retry copy.
- Existing licensed Pip recordings supply two low calls and a brighter closing
  call. The entire sequence is cancelled on mute, pause, map, retry, leaving the
  mode, and page backgrounding. Refreshing or resuming cannot replay old calls.
- Reduced motion retains static expressions and the encouragement transition.
  Very short landscape screens prioritize Pip, copy, and full-size actions.

## Verification

- Countdown model: 1,048 assertions passed, including all levels at 9.99 and
  10.00 seconds, save migration, pause, reload, and malformed checkpoints.
- Quest scene: 693 checks passed, including delayed final impacts, retry,
  paused losses, persistent rewards, and responsive result cards.
- Pip rematch lifecycle and layout: 202 assertions passed.
- Quest audio integration: 100 checks passed, including all three recorded
  calls, duplicate prevention, cancellation, and no replay after unmuting.
- Existing Pip motion, gameplay feedback, audio, and reaction suites: 305
  assertions passed.
- Browser persistence, Web export, and test runner: 58 Node tests passed.
- Real renderer: ten screenshots across desktop, phone, small phone, compact
  landscape, and reduced motion. An initial high-five hat crop was corrected
  with reserved movement space and the captures were repeated successfully.

Screenshots are in `build/talk-quest-pip-loss-review/`. The visual harness uses
the dummy audio driver; playback routing is tested separately and these images
do not establish audible output from a physical device. Player saves were
isolated in automated checks.

The existing source records remain authoritative: [Pip artwork](../assets/pip-dance.md)
and [Pip audio](../assets/pip-sounds.md). No new external media was acquired.

## Web preview

The Web export and startup-pack checks passed. The verified build receipt is
dated `2026-10-02T13:13:54.946Z`. The in-app browser was reloaded, entered the
game, and returned to Talk Quest with its existing Continue checkpoint intact.
The published loss snapshot contains the new Pip visibility and emotion fields;
the browser reported no console warnings or errors during this startup check.
`build/talk-quest-pip-loss-review/web-startup.png` records that view. This build
updates the local preview only; no commit, push, or deployment was performed.
