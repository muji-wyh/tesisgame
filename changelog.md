# Changelog

Notable changes to Word Buddies, grouped by date with the newest changes first.

## 2026-09-10

- Added Learn with close picture/word associations and pronunciation, sharing the
  same five-word lesson across Match, Sky, and Listen.
- Added self-paced correct-answer feedback, visible Match instructions, missed-first
  review of all five words, Repeat lesson, and New adventure.
- Excluded ambiguous label pairs from distractors and added a visible Listen fallback
  for unavailable sound. Improved twelve unclear original illustrations.
- Added playable toys and room backdrops unlocked by medal progress, locked gift
  previews, named gift goals, and a Try it with Pip reward action.
- Consolidated room selections and favorite into one immediately saved record with
  legacy migration and retryable failures; existing medal saves remain unchanged.
- Added a validated offline Unity CLI art-import pipeline with original-art fallbacks.
  New Asset Store package acquisition and actual import remain pending.

## 2026-09-09

### Added

- Ocean and Space worlds, twelve new medals, and forty new illustrated/pronounced words
  for a total of 140 words across twelve rotating adventures.
- Sky words and Listen modes: five untimed picture/word choices share the three-mistake
  limit and one-piece chest reward flow with the original matching game.
- Pip's playroom with dancing, snacks, and bubbles, plus a saved favorite medal display.
- Browser medal progress and favorites save immediately, including across quick reloads.
- Card selection ripples, match sparks, falling-picture arrivals, and reduced-motion alternatives.
- A next-medal preview on My rewards, and a replayable picture-and-word shelf after
  each round that celebrates matches even when the round ends with mistakes.
- Pip, an original animated duck mascot shared across all pages, with greetings,
  blinks, contextual reactions, and beak movement synchronized to actual spoken audio.
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

- Kept the duck out of the initial unlaid-out viewport, avoiding phantom tooltips
  and preserving one-press keyboard cancellation.
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
