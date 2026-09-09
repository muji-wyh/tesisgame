# Changelog

Notable changes to Word Buddies, grouped by date with the newest changes first.

## 2026-09-09

### Added

- Optional English voice play with a single Voice start/stop button, live
  transcription, and matching of complete board words from final speech results.
  Voice play stops on victory, exit, replay, page hiding, or opening a collection.
- Fragment-based rewards: three fragments complete a medal, with six medals per
  season. Each win advances the next unfinished medal without duplicate pieces.
- Short-tap chest reactions, charging glow, automatic fragment assembly, and
  distinct celebrations and collection flights for completed medals.
- Star-marked hints, consecutive-match celebrations, fresher replay boards, and
  remembered season choices.
- Visible seasonal collection goals and partial-medal previews.
- A seasonal speech bubble and microphone buddy with listening animations and
  bounded reactions to incoming words; reduced motion keeps the effects static.

### Changed

- Limited each round to one hint, shared by touch, keyboard, and Xbox controls.
  Only starting a new round restores the hint.
- Preserved the three-mistake loss limit for every round.
- Migrated previously earned rewards 1-6 into complete medals and preserved earned
  rewards 7-10 under Earlier rewards. The original reward save remains unchanged.
- Added retryable fragment saving without rerolling or duplicating the reward.
- Added microphone privacy notices and visible permission/service errors.
  Game audio is quiet during voice play to avoid matching its own speech.
- Replaced the separate Listen control with immediate listening from Voice.
- Added staged startup pacing at 35%, 75%, and 95%, labeled as an estimate.
  Real data-loading details remain visible, and 100% requires the game to be ready.

### Removed

- Unlimited-attempt Practice mode, which was introduced earlier in the day.

### Fixed

- Keyboard navigation through unavailable or used controls.
- Focus restoration after collection and preview state changes.
- Text contrast on pressed buttons and card layout on short screens in voice mode.
- Cancellation of stale speech callbacks and handling of microphone shutdown errors.

## 2026-09-08

### Added

- Expanded the vocabulary to 100 short words with distinct pictures and recordings.
- Introduced forty illustrated seasonal collectibles and a locally saved collection.
- Draggable chests with long-press charging.
- Interactive reward previews with bounce, twirl, hug, and high-five reactions.
- Xbox controller navigation, chest charging, season switching, and collection access.
- An interactive loading-screen chest.

### Improved

- Mobile startup delivery, loading feedback, and reward delivery animations.
- Touch scrolling with momentum, swipe-safe reward previews, and controller scrolling.
- Loss-screen bear interaction and reduced-motion behavior.

## 2026-09-07

- Migrated the matching game to Godot Web with native gameplay, audio, and animations.
- Added seasonal chest rewards, palettes, music, and cinematic effects.
- Added original game artwork and prerecorded English audio.
- Improved responsive layouts and mobile asset delivery.
- Configured Azure Static Web Apps deployment.

## 2026-09-06

- Created the project, JSON vocabulary, and matching state machine.
