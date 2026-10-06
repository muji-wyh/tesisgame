# Documentation index

Use this index and the [project README](../README.md) for current guidance.
Dated plans and QA reports describe their own revisions; their feature lists,
commands, asset counts, and measurements may no longer describe the game.

## Maintained references

| Reference | Scope | Primary implementation |
| --- | --- | --- |
| [Gameplay](gameplay.md) | Modes, controls, worlds, room, rewards, and accessibility | `scripts/game_ui.gd`, `scripts/voice_pop.gd`, `scripts/playroom_view.gd` |
| [Voice Pop treasure](voice-pop-treasure.md) | Score milestones, persistent chest batches, and the shared animated chest catalog | `scripts/pop_reward_state.gd`, `scripts/pop_reward_room.gd`, `scripts/chest_model_view.gd` |
| [Development and deployment](development.md) | Build, hosting, embedding, and validation | `package.json`, `tools/build-web.cjs`, `tools/deploy-web.ps1` |
| [Performance assessment](performance.md) | Reproducible rendered workloads, paired comparisons, acceptance criteria, and measurement limits | `tools/benchmark-performance.cjs`, `tests/performance/main_scene_benchmark.gd` |
| [Local players and leaderboards](local-leaderboards.md) | Local profiles, result attribution, rankings, persistence | `scripts/leaderboard_state.gd` |
| [Speech matching](voice-matching.md) | Homophones, interim stability, target binding, local experiment | `scripts/speech_words.gd`, `scripts/voice_pop_model.gd`, `web/shell.html` |
| [Voice Pop slices](voice-pop-slice-feedback.md) | Cut presentation, audio integration, original release evidence | `scripts/voice_pop_slice.gd`, `scripts/game_audio.gd` |
| [Chest performance](assets/chest-feel.md) | Theme motion, five-second timeline, cancellation, sound | `scripts/chest_feel.gd`, `scripts/chest_view.gd` |
| [Asset index](assets/README.md) | Media generation, imports, licenses, fallback priority | `tools/`, `assets/`, associated JSON manifests |

Implementation and maintained tests settle discrepancies with old documents.
Build outputs under `build/` are generated evidence, not editable source.

## Historical records

- [QA index](qa/README.md): dated checks, removals, and validation limitations.
- [Design archive](superpowers/README.md): previous plans and specifications.
- [Retired Talk Quest reference](talk-quest.md): former campaign behavior and source provenance.
- [Changelog](../changelog.md): events in chronological context.

Current game modes are Match, Memory, and single-player Voice Pop.
Local names and avatars support leaderboards for all three modes. Talk Quest
was retired on 2026-10-06; its source records and dated QA remain historical.
Local profiles are not the retired enrolled voice profiles. The optional browser-managed local speech experiment is separate
from the removed sherpa-onnx multiplayer runtime. Old medal and sticker records
remain relevant to save compatibility even though their collection UI is gone.
