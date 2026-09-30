# Historical plans and specifications

The dated files in `plans/` and `specs/` preserve previous design decisions,
research, implementation checklists, and release context. They are archived
proposals or records, not the current backlog or execution instructions.
An unchecked task is not a request to implement it now, and a checked task
does not mean the feature still exists.

Use the [current documentation index](../README.md), implementation, and
maintained tests before extending the game. In particular:

- Learn, Sky, and Listen modes have been removed; Match, Memory, and Voice Pop
  are the current modes.
- The Words album and Medals collection UI have been removed. Old fields and
  reward accounting remain relevant to save compatibility and toy unlocks.
- The original chest fragment assembly and collectible celebrations have been
  replaced by the [current chest performance](../assets/chest-feel.md).
- Older three-pair boards, 30-second Voice Pop rounds, manual adventure pickers,
  repeated-lesson actions, and audio-loading strategies may appear here.
- Voice Pop now uses [local player attribution](../local-leaderboards.md) and
  [browser speech matching](../voice-matching.md); earlier voice-profile and
  multiplayer experiments are not current architecture.

Keep these paths stable so historical QA, changelog entries, and Git history
remain understandable. Do not restore removed features or run old release
commands merely because an archived plan describes them.
