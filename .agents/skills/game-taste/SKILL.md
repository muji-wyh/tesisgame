---
name: game-taste
description: "Improve game taste, art direction, audiovisual feedback, interaction feel, pacing, and UI hierarchy. Use for game polish or when an experience feels cheap, flat, floaty, cluttered, repetitive, or unsatisfying. Supports critique, planning, and implementation. Do not invoke for unrelated backend work or a narrow bug fix with no experience-design component."
---

# Game Taste

Make a game feel deliberate, coherent, expressive, and worth playing. Judge each
choice by the intended player experience. Expensive rendering, realism, spectacle,
and minimalism are possible directions, not universal measures of quality.

## Establish what should feel good

Read the project's art direction and relevant product constraints, then inspect
the actual screen or interaction being changed. Use a running build, gameplay
recording, assets, and implementation as available. Distinguish what was observed
from what is inferred; a screenshot cannot establish timing or sound quality.

Form a short working brief: audience, core action, intended emotion, visual and
sonic language, target device, and what must remain intact. Infer this from the
project when possible. Ask only about choices that would materially change the
direction; continue independent inspection while awaiting an answer.

Respect the requested mode of work. A critique produces findings, a plan proposes
changes, and an implementation request carries them through. Skill invocation
does not authorize new game modes, purchases, deployment, or unrelated redesigns.

## Make a diagnosis before choosing effects

Describe the strongest observed problems as a causal chain:
**visible or audible evidence -> player consequence -> specific change -> check**.
For example: a lid and body scaling together makes a chest read as a flat sticker;
separate the hinge motion, interior occlusion, and contact shadow, then compare
the same opening at normal speed on the target device.

Consider the dimensions relevant to the request:

- **Gameplay meaning:** Can the player understand the action, predict its result,
  and learn from feedback? Polish cannot repair an unreadable goal or an arbitrary
  outcome. Flag mechanics issues without silently changing the rules.
- **Art direction:** Silhouette, proportion, perspective, materials, lighting,
  typography, and sound should belong to the same world. Identify a focal subject
  and support it; a collection of individually attractive assets is not yet a style.
- **Composition and interface:** Make the next action and essential state legible.
  Remove redundant labels and competing decoration when that improves the screen.
  Preserve discoverability, touch reach, safe areas, and readable contrast.
- **Physical feel:** Response, resistance, momentum, contact, and settling need
  convincing causes. Decide what actually moves and where it pivots before adding
  shake, squash, or a camera effect.
- **Rhythm and sound:** Build contrast between ordinary actions, buildup, decisive
  events, and recovery. Give frequent actions concise feedback and rare milestones
  enough space. More duration or volume alone seldom improves anticipation.
- **Audience and tone:** Fit the emotional range to the genre and player. For
  child-facing fantasy, seek appealing expressions, gentle power, and readable
  success; inspect extreme poses as well as thumbnails. Other genres may call for
  restraint, danger, abstraction, or silence.

Prioritize the smallest set of changes that materially improves the experience.
Call out high-impact removals as well as additions. Prefer one coherent direction
with reasons over an unranked list of embellishments. Do not invent a numerical
"taste score" or call a preference objectively better.

## Calibrate the judgment

For broad taste work, a new direction, or a disputed subjective choice, use one
or two inspected anchors relevant to the decision. Start with project-approved
work or user-supplied references; a strong existing part of this game can be the
anchor. A narrow adjustment with an established direction does not need new
reference research.

For reference selection, art direction, or asset work, read
[references/art-and-assets.md](references/art-and-assets.md). State what to borrow,
what not to borrow, and why it fits this audience and interaction. Convert those
observations into a few checkable criteria before recommending or editing, not
adjectives such as "premium". Include qualities to preserve and the main trade-off.

If genuinely different directions remain viable, compare their strongest fair
versions and recommend one. Ask only if an unresolved preference would materially
change implementation; do not generate variants for every minor edit.

Keep chosen anchors and criteria stable through comparison. If evidence changes
them, say why rather than moving the goalposts to favor the new output. Keep a
concise record in the task response or an existing project design record; do not
create a benchmark library by default or label a reference user-approved unless
the user actually approved it.

## Ground the direction in real material

Inspect the relevant assets before implementing their presentation. Preserve
strong existing work; replace assets only when the diagnosis calls for it. Use
appropriate production artwork and audio. Do not substitute generic geometry,
flat-color stand-ins, or procedural placeholder drawings for requested artwork.
Simple layout primitives or an intentional abstract visual language can be valid;
they must not be used to disguise missing art.

When sourcing or replacing material, record source, creator, license,
acquisition/integration status, and available animations in the project's existing
asset record. Keep source previews distinct from acquired and integrated files.
Inspect the actual downloaded material and relevant poses. If an asset is
unavailable, mark that dependency precisely and complete useful independent work
without claiming placeholder output is finished artwork.

Use references to understand composition, timing, material, or sonic structure.
Separate these observations from rights to reuse their files. A reference video
does not by itself grant permission to ship its soundtrack or extracted artwork.

## Refine one complete interaction

For motion, game feel, or sound work, read
[references/feel-and-review.md](references/feel-and-review.md). Build one
representative interaction at final display scale before applying variants.

Map the player input, immediate acknowledgement, main action, outcome, and return
to control. Drive the decisive sound, animation, and visual effect from the same
event or timeline. Tie progress to the real state. Keep user-specified durations,
scoring, cancellation boundaries, and replay behavior unless the task changes them.

Tune hierarchy before intensity: subject motion first, material/contact cues
next, lighting and particles in support. Choose curves and sound timbres for the
object's character. Avoid global scaling that flattens a rigid object, an arbitrary
pause that breaks continuity, or constant shaking that erases the final accent.
When the user explicitly asks for stronger spectacle, give it a clear peak and
readable recovery instead of flattening it into tasteful but weak feedback.

Keep scope concrete. Change the relevant assets, layout, motion, and sound code;
do not add systems just to demonstrate the skill. Handle repeated input, late
callbacks, interruption, and reduced motion through the established lifecycle.
New effects must not alter hit ownership, issue rewards twice, or prevent exit.

## Verify the experience and report honestly

Compare before and after with the same input and target size. Replay a common
action several times to expose fatigue, overlap, and pacing issues. Watch once
without sound and listen where appropriate without visuals to isolate problems,
then judge them together. Check relevant small-screen and accessibility states.

Compare against the chosen anchors and criteria as well as the old version.
Improving a weak baseline is not enough if the result still misses the brief.
If the intended focal hierarchy, style, or response remains wrong, revise that
cause before layering more effects.

Use focused checks for state or timing changes. Judge presentation from rendered
output and, for sound claims, actual playback. State any missing live/device
evidence explicitly; passing logic tests does not establish delight or acoustic
quality. Never claim to have watched a recording or heard audio that was not
actually available to inspect.

Use actual user or playtest feedback when available, distinguishing it from
your own interpretation. Self-review is not evidence that players prefer the
result, find it distinctive, or feel delight. Treat judgments without relevant
reference or rendered evidence as provisional, not verified.

Report the concrete improvement, why it fits this game, what was changed or
recommended, what was verified, and remaining dependencies. Link relevant output
when useful. Scale the report to the task; do not create a design document,
scorecard, or asset catalog when the requested change does not need one.
