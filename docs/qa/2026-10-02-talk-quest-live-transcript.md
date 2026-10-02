# Talk Quest live transcript

The speech host now forwards every Quest hypothesis to the existing generic
speech observer before scoring. This includes unfinished phrases, mismatches,
empty revisions, and corrected final results. Bound attack events retain their
own expiry, stability, and duplicate checks.

Quest displays the latest hypothesis immediately and does not replace the full
phrase with a scored word. Its caption retains the newest two wrapped lines in
portrait or one line in compact landscape, with a 2,000-character bound. It
survives automatic recognizer reconnection, clears on explicit stop, pause,
errors, or leaving, and never enters saved progress.

## Verification

- Quest, Match, and Pop browser-host tests: 125 passed.
- Main-scene transcript integration: 53 headless checks passed, including
  scoring separation, stale callbacks, guards, and lifecycle behavior.
- The same integration suite with the real renderer: 56 checks passed and
  three captures inspected for wrapping, newest-word visibility, and overlap.
- Existing Quest scene: 693 checks passed.
- Existing compact layout: 166 checks passed.
- Web export and test-runner checks: 32 Node tests passed.

Captures are in `build/talk-quest-transcript-review/`. Tests use isolated player
saves and simulated recognizer results. They verify presentation and dispatch,
not physical microphone accuracy or the browser speech service's response time.
