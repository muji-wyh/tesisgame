# Grow with Pip

The ten age-labelled stages form an editorial English-as-a-second-language curriculum for children learning from a Chinese-language foundation. They are a learning sequence, not age norms or an assessment of a child's development. `words.json` is canonical; `curriculum.json` records each disjoint cohort and its research references. Age 12 is displayed as 12+.

## Mastery and level rules

Every device starts at Lv3. A successful activity adds one to each unique involved word's consecutive-correct streak, capped at six. A wrong activity resets the involved words to zero, including words previously mastered. A word at six is mastered. Mastering every word in the current cohort unlocks the next level. Earned levels never decrease, even when an earlier word needs practice again. Lv12+ is the final stage.

The six-answer threshold is the requested game rule, not a research-validated learning assessment. Progress is shared across four modes and saved independently from treasure claiming. The notebook labels future cohorts as previews; browsing or replaying pronunciation cannot grant mastery or choose a higher gameplay level.

| Mode | Correct evidence | Reset boundary | Neutral actions |
| --- | --- | --- | --- |
| Match | Completed matching pair, once per word | Both words in a mismatched word-picture pair | First selection, cancelling, hint, replay |
| Memory | Completed pair, once per word | Both words in a mismatched pair | First reveal, peek, cancelling |
| Phrase Builder | Every unique target word | Target words plus selected wrong words | Dragging, reordering, incomplete checks, replay, unused distractors |
| Voice Pop | A successfully spoken live target | Explicit final wrong answer attributed to a live target | Silence, expiry, unbound or failed recognition, pause, exit |

Match and Memory share the pictured word selection. It shuffles within mastery priority, favors current unmastered words, avoids repeating the previous board when possible, and checks picture/speech ambiguity. Phrase selection prioritizes unmastered words; every contextual word has a phrase reachable no later than its own stage. Contextual words have no invented illustration and participate through phrases. Word tiles retain authentic images wherever one is available.

## Durable state

`GrowthState` stores a versioned level, word streaks and bounded answer receipts. Each attempt combines a unique round ID with its mode-local attempt ID. Repeated callbacks are ignored. The native save uses an atomic replacement and recovery copy; the browser uses `growWithPip.growth.v1` with a verified write. A failed write queues accepted answers in order, publishes no false mastery or level-up, and exposes Retry saving. Future-word eligibility is captured when an answer arrives, before queued answers might unlock another level.

If the initial growth save cannot be read, scored play waits until Retry saving
successfully loads it. The game explains this gate and then starts a playable
round; it never accepts answers against unknown previous learning progress.

Browser answers rebase on the latest validated save before writing, so an older
open game tab preserves another tab's answers and promotions. Writes compare
the expected save and read back the result; a changed save gets a bounded retry.
The queued answer's original eligibility and order remain intact. This prevents
stale sequential writers from replacing newer progress. `localStorage` is not
a transactional cross-process database, so precisely simultaneous writes from
separate renderer processes remain outside this guarantee.

Existing reward, medal and Voice Pop chest saves are preserved. Legacy age choices, names, avatars and score records are not evidence of mastery and cannot skip Lv3. The internal Godot project name remains unchanged to preserve the existing native `user://` storage directory. Presentation preferences retain their existing key, with theme choice migrated independently of the retired room.

## Pip review

The developer-only asset preview at `http://127.0.0.1:41774/` presents ten compositions using Pip's existing layered production artwork and expressions. Start it with `npm run preview:pip`; it is not included in the published game or linked from gameplay. Every successive stage adds one motion and one click-to-hear Ava line. Gameplay keeps feedback, pronunciation, pause, mute, reduced motion and chest timing. Extra Pip speech is explicitly requested rather than played as guidance. Source, license, composition and voice settings are documented in `docs/assets/pip-growth.md`.
