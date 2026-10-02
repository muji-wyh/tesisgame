# Talk Quest word battles

Talk Quest now uses finite flying-word battles in all fourteen destinations. A
recognized word becomes a projectile, and its impact removes one displayed
health segment. Health increases from 5 to 28 across the campaign. Each attempt
has N + max(3, ceil(N / 4)) words, so missed targets consume a limited opportunity.
Defeating the monster retains the shared hold-to-open treasure sequence.

The map fits the viewport in three chapter pages without a scrolling container
or monster portraits. The stage removes sentence, Speak, Hear line, and Type
controls. A level-selection gesture starts continuous speech recognition;
actionable microphone errors expose Retry microphone.

## Validation

- Model: 902 assertions passed for all fourteen battles, finite launch budgets,
  bound recognition occurrences, duplicates, stale results, pause/resume, and
  save migration. Log: `build/quest-word-model-tests.log`.
- Map: 1,239 checks passed for viewport bounds, chapter navigation, focus, and
  compact destination captions and badges.
  Log: `build/quest-short-map-tests.log`.
- Scene: 610 checks passed for increasing health, finite wins, projectile impact,
  pause, all fourteen chests, responsive layout, and restored runs. The final
  regression also covers late effect callbacks after fallback damage and
  background/resume/retry after a lost round.
  Log: `build/quest-word-scene-compact-final-tests.log`.
- Reward lifecycle: 38 checks passed, including cancellation, controller input,
  audio cues, save retries, and reduced motion.
  Log: `build/quest-word-reward-flow-tests.log`.
- Browser host: 117 Node tests passed across Talk Quest and the existing Voice
  Pop speech host: `node --test tests/talk-quest-host.test.cjs tests/voice-host.test.cjs`.
- Rendered 30 native captures covering all fourteen scenes, desktop/phone/small
  and landscape maps, word projectiles, impacts, victory, and treasure.
  Representative captures were visually inspected in `build/talk-quest-words/`.
  Adjusted health-label spacing after the first visual pass and confirmed the
  phone layouts again.
- Final Web export passed its startup resource checks: 20.47 MB compressed
  startup, 350 word pronunciations, 12 effects, and all required chest/audio
  paths. The final map release build is recorded in
  `build/quest-words-map-release-web-build.log`.
  Release pack: `game-e35979cd80496b74.pck`.
- Desktop Chromium: all three focused browser cases passed against the tested
  export, covering gesture-owned capture, word attacks, duplicate/stale speech,
  microphone errors and retry, finite loss/retry, pending chest reload, real
  chest hold, and exactly-once reward persistence.
  Log: `build/quest-words-desktop-browser.log`. Battle and reward screenshots
  were visually inspected in `build/quest-words-browser-results/`.
- iPhone WebKit at its original DPR 3 passed the full battle/chest/reload flow
  and reduced-motion chest hold. One earlier run stopped at four hits because a
  selected-word callback did not score; that run did not preserve sufficient
  evidence to determine why. The unchanged runtime then passed a diagnostic
  replay. The test now selects a current word and emits its recognition in one
  browser evaluation, avoiding selection-to-callback transport delay, and
  preserves callback evidence before reload. Its final run passed with five
  hits and zero expired-target, game-rejected, or no-matching-target events.
  Evidence: `build/quest-words-iphone-final-results/`; logs:
  `build/quest-words-iphone-final.log` and `build/quest-words-iphone-browser.log`.
- Visual review of the iPhone raw canvas exposed a short-landscape layout issue
  despite passing control-bound checks. Short viewports now use a single-row
  header with the monster and word arena side by side. Word cards stay readable,
  the microphone retry action does not cover them, and the narrow portrait map
  keeps the full Treasures button on-screen. The final native tests passed 153
  checks, and the rendered run passed 163 checks with ten captures of the actual
  constrained game body. Logs: `build/quest-short-map-compact-tests.log` and
  `build/quest-short-map-renders.log`; captures: `build/talk-quest-compact/`.
  The first browser layout rerun passed its geometry assertions but its raw
  landscape map capture exposed clipped destination numbers and captions when
  Continue was present. Continue now shares the short map header, and compact
  destination cards place their numbers and captions within their touch targets.
  All three chapter captures with Continue visible were inspected. The browser
  regression also checks minimum touch dimensions and painted caption/badge
  bounds; passing the earlier control bounds alone was insufficient to approve
  the release.
  The final iPhone WebKit phone-layout case passed against release pack
  `e35979cd80496b74`, including all three saved-map chapters and both battle
  orientations. Raw captures were inspected with complete labels and no word
  obstruction. Log: `build/quest-words-map-release-browser.log`; screenshots:
  `build/quest-words-map-release-browser-results/`.
  Windows WebKit page captures can turn blank after a live
  viewport resize while the raw canvas still renders; layout review therefore
  also uses raw canvas captures, consistent with the existing renderer QA note.

Browser speech checks use controlled recognition callbacks and emulated device
profiles; they do not establish physical microphone behavior. The earlier
mobile player-name keyboard fix is included in this release; its reproduction
and verification are recorded in `2026-10-02-mobile-keyboard-reopen.md`.

## Release

The first Web integration run reproduced a storage rejection on initial level
selection. Godot's reference-counted instance ID can be negative, producing a
run ID such as `tq-run--9223371976255469986-18431100-1`. The new browser checkpoint
validator accepted only unsigned components and therefore blocked storage and
microphone start. Browser and native restoration validation now accept the
signed first component while preserving the bounded progress-only schema.

Deployed to production on October 2, 2026. The production HTML, engine
JavaScript, WebAssembly, and game pack all match the tested local export by
SHA-256. Deployment log: `build/quest-words-production-deploy.log`; verification:
`build/quest-words-production-verification.log`.

Verified release: https://gentle-forest-02ff42900.3.azurestaticapps.net/?v=e35979cd80496b74
