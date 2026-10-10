# Grow with Pip

The ten age-labelled stages form an editorial English-as-a-second-language curriculum for children learning from a Chinese-language foundation. They are a learning sequence, not age norms or an assessment of a child's development. `words.json` is canonical; `curriculum.json` records each disjoint cohort and its research references. Age 12 is displayed as 12+.

## Mastery, experience and age

Every device starts at **Lv0** with **Baby Pip**. A successful activity adds one to each unique involved word's consecutive-correct streak, capped at six. A wrong activity resets the involved words to zero, including words previously mastered. A word at six is currently mastered.

Experience levels and Pip's age are independent:

- The first mastery of each distinct word adds one permanent experience word. Relearning a word after a mistake restores its current mastery but grants no extra experience. Earned levels never decrease.
- Lv1 requires one unique word; Lv2 requires two more, for three in total. The explicit 99-step cost table in `GrowthState.LEVEL_COSTS` grows gradually from one to thirty words per level. Costs remain steady for several levels before increasing, so the complete 1,550-word curriculum can reach Lv99. Later vocabulary additions do not move these thresholds.
- Pip starts as a baby while learning the age-three cohort. Mastering **all current words** in that cohort makes Pip Age 3 and unlocks the age-four cohort. This repeats through Age 12+. Earned ages never decrease when a word later needs review. Pip's appearance follows this earned age, never the numeric experience level.
- Completing a cohort requires simultaneous current mastery. A lifetime history of having mastered its words at different times cannot bypass a word that was subsequently answered incorrectly.

| Experience level | Unique words mastered at least once |
| --- | ---: |
| Lv0 | 0 |
| Lv1 | 1 |
| Lv2 | 3 |
| Lv3 | 5 |
| Lv10 | 28 |
| Lv20 | 85 |
| Lv30 | 170 |
| Lv40 | 284 |
| Lv50 | 428 |
| Lv60 | 600 |
| Lv70 | 802 |
| Lv80 | 1,033 |
| Lv90 | 1,292 |
| Lv99 | 1,550 |

The six-answer threshold is the requested game rule, not a research-validated learning assessment. Progress is shared across all five modes and saved independently from treasure claiming. The notebook labels future cohorts as previews; browsing or replaying pronunciation cannot grant mastery or select a higher gameplay cohort.

The gameplay header contains one growth button with the earned Lv and a recessed green progress track. The count inside the track shows new unique words earned toward the next experience level; Age appears below it on wide screens and in the tooltip on every screen. Narrow and short screens retain a 44-pixel-tall token with an 8-pixel track. The whole control opens the notebook for the next age cohort to complete. The notebook title separates earned Lv and Pip age; its summary explains the next Lv target and current cohort completion.

The Lv bar measures first-time word mastery, not partial practice streaks or current cohort completion. It resets at each experience threshold and shows MAX at Lv99. Relearning a previously mastered word restores the notebook's current-mastery mark without filling Lv again. An unreadable save displays unavailable progress. The presentation retains the existing Nunito fonts, notebook controls and interface click sound. Baby Pip is a new age composition of the existing production character layers, documented with its sources in the asset record.

| Mode | Correct evidence | Reset boundary | Neutral actions |
| --- | --- | --- | --- |
| Match | Completed matching pair, once per word | Both words in a mismatched word-picture pair | First selection, cancelling, hint, replay |
| Memory | Completed pair, once per word | Both words in a mismatched pair | First reveal, peek, cancelling |
| Phrase Builder | Every unique target word | Target words plus selected wrong words | Dragging, reordering, incomplete checks, replay, unused distractors |
| Voice Pop | A successfully spoken live target | Explicit final wrong answer attributed to a live target | Silence, expiry, unbound or failed recognition, pause, exit |
| Jelly Match | A successfully merged word-picture pair | Both words in a deliberately submitted mismatched pair | Tapping, cancelled drags, waiting, falling blocks |

Match and Memory share the pictured word selection. It shuffles within mastery priority, favors current unmastered words, avoids repeating the previous board when possible, and checks picture/speech ambiguity. Phrase selection prioritizes unmastered words; every contextual word has a phrase reachable no later than its own stage. Contextual words have no invented illustration and participate through phrases. Word tiles retain authentic images wherever one is available.

## Durable state

`GrowthState` schema version 2 stores experience level, earned age, current word streaks, unique lifetime mastered-word IDs and bounded answer receipts. It keeps the existing native `user://growth-v1.cfg` path and browser `growWithPip.growth.v1` key so progress migrates in place. Each attempt combines a unique round ID with its mode-local attempt ID. Repeated callbacks are ignored. The native save uses an atomic replacement and recovery copy; the browser uses a verified comparison write. A failed write queues accepted answers in order, publishes no false mastery, level-up or age change, and exposes Retry saving. Future-word eligibility is captured when an answer arrives, before queued answers might unlock another age cohort.

Version 1 migration interprets the old level as the cohort currently being learned: old Lv3 becomes Baby, old Lv4 becomes Age 3, and so on. Previously completed cohorts provide inferred lifetime experience even if a later mistake reset a word. Current six-answer streaks also provide lifetime experience. An already fully mastered current cohort grants its corresponding age, including Age 12+. Current streaks and answer receipts are retained unchanged. Migration must be saved successfully before gameplay treats the new state as ready; failed writes leave the old save intact for retry.

If the initial growth save cannot be read, scored play waits until Retry saving
successfully loads it. The game explains this gate and then starts a playable
round; it never accepts answers against unknown previous learning progress.

Browser answers rebase on the latest validated save before writing, so an older
open game tab preserves another tab's answers and promotions. Current streaks
are replayed in order rather than maximum-merged, so real mistakes stay reset.
Only permanent mastered-word history and earned ages are united across tabs. Writes compare
the expected save and read back the result; a changed save gets a bounded retry.
The queued answer's original eligibility and order remain intact. This prevents
stale sequential writers from replacing newer progress. `localStorage` is not
a transactional cross-process database, so precisely simultaneous writes from
separate renderer processes remain outside this guarantee.

Existing reward, medal and Voice Pop chest saves are preserved. Legacy age choices, names, avatars and score records are not evidence of mastery and cannot skip the baby learning stage. The internal Godot project name remains unchanged to preserve the existing native `user://` storage directory. Presentation preferences retain their existing key, with theme choice migrated independently of the retired room.

## Pip review

The developer-only asset preview at `http://127.0.0.1:41774/` presents Baby and ten age compositions using Pip's existing layered production artwork and expressions. Start it with `npm run preview:pip`; it is not included in the published game or linked from gameplay. Baby and Age 3 share the existing gentle wave and Sprout greeting; later ages add the existing cumulative motions and click-to-hear Ava lines. Gameplay keeps feedback, pronunciation, pause, mute, reduced motion and chest timing. Extra Pip speech is explicitly requested rather than played as guidance. Source, license, composition and voice settings are documented in `docs/assets/pip-growth.md`.
