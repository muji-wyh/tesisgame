# Talk Quest

Talk Quest is a fourteen-stage spoken-word adventure. Choose a destination,
allow the microphone when prompted, and say a word as its picture flies into
view. The matched word becomes a glowing projectile and strikes the monster
for one health segment. The map presents fourteen dimensional island
destinations along one horizontal journey, without monster portraits.

Each destination uses a rendered diorama assembled from acquired building,
landscape, and prop models. Warm village roofs, an art pavilion, market stalls,
coastal scenery, and the final castle give the route distinct landmarks. A
sourced sky, distant islands, and cloud layers add depth behind the route.
The next adventure carries a floating flag; seals and locks distinguish cleared
and unavailable stops.

Drag, swipe, use a trackpad, or turn the mouse wheel to travel across the map.
Scrolling retains momentum with no visible scrollbar. The region arrows jump
to the starts of the three regions, and keyboard focus reveals an offscreen
unlocked destination. Compact landscape retains readable destination artwork
and usable touch targets. Reduced motion removes ambient movement while
preserving navigation.

The [map source manifest](../assets/talk_quest/map-dimensional/manifest.json)
records the downloaded sources, model usage, render process, and available
animations. The startup-pack verification loads every map texture, including
its scenery layers, so these assets remain available offline after loading.

The twelve ordinary stages and two boss stages retain their distinct scenes,
approved animated creatures, and reward designs. The workshop finale now uses
word combat too. Archived conversations remain in the content catalog for save
migration; they do not control active play. There are no sentence, part-choice,
Speak, Hear line, or Type controls.

## Difficulty and finite attempts

Every monster has N health segments. An attempt can launch at most N + m words,
where m is the larger of three or one quarter of N rounded upward. Up to three
words can be visible at once. Every word has a ten-second countdown at all
fourteen levels. Older saved active words receive the new ten-second limit
while retaining their elapsed age and the rest of the attempt's progress.
Each matched word deals exactly one damage;
expired words use up an opportunity without damaging the monster. Reaching
zero health ends the battle immediately. Exhausting the entire word budget
with health remaining leads to Retry.

The rematch screen brings Pip forward beside a dark, gold-edged result card.
His existing character artwork shows a tearful frown, lowered head, and drooped
wings for 2.4 seconds, accompanied by two soft, low duck calls. Then he offers a
high five and the message "Let's try again together!" with a brighter call.
The calls reuse the [licensed Pip recordings](assets/pip-sounds.md).
Try again and Map remain available throughout. Earned word hits and remaining
monster health appear when space permits; very short landscape screens retain
Pip, encouragement, and the full-size buttons without scrolling. An in-flight
final hit settles before Pip appears. Reduced motion uses static expressions
and still advances to encouragement. Pause, leaving, and mute cancel pending
calls; resuming a loss never replays them. Failed attempts preserve collected
treasure without granting a new reward.

Pausing uses a matching cool-lit card with Continue and Map actions. It retains
the frozen creature or chest and shows the appropriate battle or treasure
status. Words, monster motion, and camera reactions remain suspended; only an
explicit Continue action resumes the encounter and, during combat, listening.
Pausing before a chest releases still cancels the hold; pausing after release
settles its reward exactly once. Reduced motion removes the card entrance and
ambient movement without changing either action.

| Level | Destination | Health N | Extra words m | Word budget |
| --- | --- | ---: | ---: | ---: |
| 1 | At the Front Door | 5 | 3 | 8 |
| 2 | Clean Hands | 6 | 3 | 9 |
| 3 | Breakfast Time | 7 | 3 | 10 |
| 4 | Getting Dressed | 8 | 3 | 11 |
| 5 | Taking Turns | 9 | 3 | 12 |
| 6 | Our Classroom Picture | 10 | 3 | 13 |
| 7 | Fruit Shopping | 12 | 3 | 15 |
| 8 | A Quiet Library | 14 | 4 | 18 |
| 9 | A Day at the Zoo | 16 | 4 | 20 |
| 10 | Riding the Bus | 18 | 5 | 23 |
| 11 | A Sandcastle at the Beach | 20 | 5 | 25 |
| 12 | Camping Under the Stars | 22 | 6 | 28 |
| 13 | The Grand Birthday Party | 25 | 7 | 32 |
| 14 | Magic Toy Workshop | 28 | 7 | 35 |

Vocabulary is selected from the existing validated GameData word catalog,
including its pictures and audio. Each destination has a curated everyday word
pool. Simultaneous targets cannot share an accepted speech form or a visually
confusable noun. Launches favor less-used words in the pool.

## Speech and presentation

The browser receives all live word IDs, reviewed forms, and remaining flight
times. It binds each recognition occurrence to the original visible flight and
speech round. A recognized noun may match its reviewed plural, compound
spelling, or homophone through the shared SpeechWords rules. Arbitrary
substrings, extra nouns, or expired targets never score.

The live caption shows each complete browser hypothesis as soon as it arrives,
including unfinished phrases, corrections, and speech that does not match a
target. It retains the latest phrase while listening and through automatic
recognizer reconnection. Long phrases show their newest two lines in portrait
or one line in short landscape. Explicit stop, pause, microphone errors, and
leaving the encounter clear the caption. Display updates cannot score or replace
the separate bound attack events, and recognized speech is never saved.

A matching interim or final occurrence can hit once. A final mismatch is
consumed without damage, and an interim match cannot hit again when its final
result arrives. Pause, resume, retry, and reload create new speech rounds.
Pausing freezes target ages and launch timing; resuming continues the same
flight windows instead of adding free words.

The stage supplies the matched target's picture, word, position, and flight
progress to the projectile effect. The monster retains its source idle motion,
friendly hit reactions, final retreat, and victory sequence. Reduced motion
retains readable hit feedback and the same combat rules.

Accepted words play a short magic launch sound, followed by a separate impact
when the projectile reaches the monster. The final defeat has its own crumbling
and resolving cue. These locally bundled effects activate on the first attack,
allow overlapping hits, respect mute, and stop when the adventure is paused or
left. They do not start music while speech recognition is active. See the
[combat audio sources](assets/talk-quest-audio.md).

The presentation uses continuous 3D environments, a perspective camera, and
framing that adapts to portrait and landscape play. Natural colors, layered
outdoor terrain, room-specific furnishings, and subtle wood, stone, plaster,
tile, and sand surfaces give each destination depth. Creature-specific material
profiles and skeletal gestures supplement the source idle clips; attacks use
weight-dependent anticipation and alternating recoil. A dark word arena keeps
the flying picture cards distinct from the scene.

Levels 1, 12 and 14 feature the acquired giants Stonewarden, Stormwing and
Embermaw. Their original painted textures, distinct silhouettes and larger
standing bodies use a low camera. Attack framing temporarily widens to retain
lifted heads, wings and horns. Stormwing and Embermaw use imported skeletal
attack, hit and defeat clips; Stonewarden uses verified game-authored skeletal
motion. While an idle giant is in active play, a threat gesture begins after
5.5 seconds and repeats no sooner than 7.5 seconds later. This gesture deals
no damage and does not change the word budget. Pausing freezes it; reduced
motion disables the periodic gesture and moving camera. The other eleven
level creatures remain distinct. See [giant asset provenance](assets/talk-quest-giants.md).

## Rewards

After the last word lands, Pip performs a 3.2-second dance using the shipped
costume atlas, accompanied by three cheerful recorded double quacks. Status
refreshes do not restart it. Pausing, backgrounding, or leaving stops the calls;
resuming the same victory shows a quiet happy Pip. Reduced motion keeps a
static smiling pose and still advances to the treasure room.

The treasure room uses acquired interior artwork, ornamental interface art,
and textured lighting effects. Pip stays beside the treasure; its name,
collection status, and hold instruction remain readable in portrait and short
landscape viewports. See the treasure asset manifest for source and licensing.

First clears award chest-01 through chest-14. The first six replays award
chest-15 through chest-20; later replays cycle through the established twenty
designs. The companion chest remains gated until the final workshop monster
has been defeated and its reward collected.

Treasure uses Match mode's shared ChestView and ChestFeel sequence. Hold with
touch, mouse, keyboard, or controller accept. Confirmation occurs at 1.2 seconds;
physical release occurs at 3.36 seconds and opening completes at 5 seconds.
Releasing before physical release cancels the gesture. Reduced motion completes
after confirmation. Completion commits one reward and one clear; repeated
callbacks cannot award it again.

## Model integration

The pure RefCounted model emits changed when observable gameplay state changes.
The stage calls advance(delta) only while play is active. Flight ages update
every frame without emitting a signal every frame.

| API or state | Purpose |
| --- | --- |
| start_level(number, seed_value = -1) | Start or retry an unlocked level and launch its first word. |
| targets | Live flight dictionaries with uid, word, forms, age, lifetime, lane, x_start, x_end, peak, and spin. |
| hp, max_hp, hits, misses, spawned, total_words | Health segments and finite launch accounting. |
| advance(delta) | Process launch and expiry events in chronological order, including slow frames. |
| speech_targets() | Return copied uid, text, forms, and remaining_ms descriptors for every live target. |
| speech_target() | Return round_id and the oldest target_uid for single-target integrations. |
| submit_speech_event(event) | Validate the original occurrence, round, target, and spoken noun. |
| current_prompt() | Compatibility view of the oldest target's text and uid; empty between launches. |
| submit_transcript(text) | Native test and accessibility helper using the same bound validator. |
| pause(), resume(), stop() | Freeze, resume, or abandon an attempt. |
| finish_victory(), open_chest() | Advance the guarded victory and durable reward stages. |
| export_progress(), import_progress(value) | Serialize or restore validated progress. |

An external event supplies event_id, round_id, target_uid, text, and stage
(interim or final). Optional received_at_ms must be finite and nonnegative.
The receipt includes accepted, matched, completed, damage, reason, phase,
hp, hits, misses, spawned, and total_words. Successful hits also supply target,
word, and target_uid. Only matched indicates damage; accepted can also mean a
valid mismatch was processed. The host must acknowledge a scored occurrence
using matched.

Stages are ready, playing, lost, victory, chest, complete, and paused. A paused
attempt retains its prior playing, victory, or chest phase. Presentation waits
for the final monster animation before finish_victory(), then commits the
reward only when the chest completes.

## Checkpoints and migration

Version-two saves contain fourteen completion counters and an optional pending
run: level number, hits, misses, spawned count, elapsed time, next launch delay,
live flight descriptors, phase, clear number, and generated run ID. Word
descriptors and speech forms are reconstructed from canonical IDs. Recognition
text, event IDs, browser speech rounds, and recordings never enter the save.

A valid pending run restores paused, preserving target IDs and their remaining
flight windows. Invalid counts, nonfinite coordinates, duplicate live IDs,
inconsistent budgets, or stale pending reward counters discard the pending run
without granting progress.

Version-one conversation saves retain validated completion counts, unlocked
destinations, and earned chest designs. Unfinished conversations safely return
to the map because their sentence indexes cannot describe finite word flights.
Already completed pending victories or chests remain claimable exactly once.

## Verification

tests/godot/talk_quest_model_tests.gd covers increasing health, curated words,
bounded overlapping flights, frame-step equivalence, N + m budgets, m versus
m + 1 misses, original speech bindings, reviewed forms, duplicate and stale
callbacks, pause/resume, retries, all fourteen victories, twenty reward designs,
private checkpoints, legacy migration, and malformed saves.

Run the model, scene, map, reward, browser, and export checks through the
project's serialized Godot workflow. Imports, exports, and native game tests
must not run concurrently against this project.
