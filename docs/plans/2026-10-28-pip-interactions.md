# Pip: more personality through interaction

Status: **interaction plan, not implemented gameplay**. The all-actions review
page is implemented separately and shows the existing production repertoire.

## Brief and diagnosis

Pip should feel like a warm, curious companion who notices the player, shares
their effort and occasionally surprises them. Keep the existing painted duck,
eleven age appearances, soft matte materials and kind expressions. Primary
targets are touch phones, the 52-pixel header and larger Home/result companions.

The current material is not short of animation: the native mascot has 22
age-specific performances, 10 inherited gestures, greetings, ten expressions,
attention/speech states, answer reactions and the shared celebration. The old
review selects one age at a time and omits the general response/celebration
families. This makes gaps in interaction harder to distinguish from gaps in art.
The new review catalogs **58 existing actions/states, 334 performances**:
55 native actions/states with 331 age variants, plus the loading screen's jump,
shy and bonk responses. Those are not 58 new animations; expression and attention
stills are labeled. Professional Pip reuses the 12+ motion repertoire; its
different career wardrobe is not counted as new choreography.

In the runtime, proactive age gestures alternate after 6-9 quiet seconds.
Correct answers share the same jump choreography with three facial variants;
the failed-answer response moves from thinking to encouragement. These are
code observations, not evidence that players prefer more or less motion.
The loading screen already has three non-repeating tap responses; the proposal
is to bring meaningful, context-appropriate interaction to the large in-game
companion, not pretend those existing responses are new.

The opportunity is to connect a small expressive response to a clear player
intent, rather than add more always-running dances.

## Inspected anchors and what transfers

1. **Existing Pip material:** inspected Baby, age 6 and age 12 production atlases,
   native pose functions, and the per-age preview. Preserve rounded cheeks,
   cocoa eyes, short bill, layered wings, age-specific pivots and planted feet.
   Do not replace these with Duo's geometric silhouette or flat material style.
2. **Duolingo's public product examples:**
   [Building character](https://blog.duolingo.com/building-character/) and
   [streak milestone design](https://blog.duolingo.com/streak-milestone-design-animation/).
   Inspected time-labelled frame sequences from the articles' original
   `junior_correct_vidmock2.gif` (4.62 s) and `04_AnimationPasses.gif` (7.00 s).
   In the lesson example, the character's jump follows a correct answer while
   Continue remains available. The milestone comparison separates preparation,
   transformation, a large open silhouette and a held finish. Borrow that causal
   response and ordinary/rare contrast, not the fire transformation, artwork,
   soundtrack, interstitial interruption or any guilt-based reminder behavior.

These are official published product demonstrations, not hands-on Duolingo
testing. No audio, physical-device reaction time or player preference was
verified. Duolingo retains its rights; no reference artwork/audio is integrated
into the review or game. The existing Pip source/rights caveats remain in
`docs/assets/pip-growth.md`; this task acquires no new artwork.

## Proposed implementation order

| Priority | Interaction | Input, performance and recovery | Material / integration work |
| --- | --- | --- | --- |
| P0 | Acknowledgement and gentle head pat | A deliberate tap receives a small head/wing acknowledgement; target acknowledgement within 80 ms, then a short anticipation, soft lean and recovery. Repeated taps do not queue performances. | Reuse existing layers and expressions; author contact-oriented keyframes. Only on the large Home/result Pip, never hijack the header's menu action. |
| P0 | Offered high five | Pip offers one wing; a second tap on the offered target commits contact, a short recoil and proud settle. Offer times out quietly and never blocks navigation. | Reuse the wing rig, author an actual contact pose and inspect a sourced contact cue before enabling sound. This is not just replaying the existing 1.7 s gesture. |
| P0 | Curious awareness | A bounded head turn notices a selected word or nearby pointer; touch gets one acknowledgement. Return to rest on leaving or starting another action. | Baked pupils cannot track a pointer. Author directional head/eye variants or a reviewed eye layer first; don't promise real gaze tracking with a whole-body rotate. |
| P1 | Share learning effort | A small nod/open-wing response supports ordinary progress; mistakes receive warm, brief recovery, not punishment or tears. Reserve the existing complete celebration for meaningful clears. | Keep the current 1.25 s success, 1.35 s encouragement and 3 s shared celebration clocks until explicitly changed. Tune amplitude and event mapping inside those boundaries; pronunciation and reward ownership retain priority. |
| P1 | Quiet personality | Use an occasional purposeful peek, little stretch or sleepy recovery during a genuine lull, with several non-repeating variants. Any gameplay input cancels it immediately. | Reuse the 22 age signatures initially. Compare the current 6-9 s quiet cadence against a calmer contextual cadence before changing it; do not make a new global idle scheduler just for novelty. |
| P2 | Age-specific surprises | Baby can peek from the shell; older Pip might recover a slipping visor, inspect a feather or offer a balance challenge. A tiny setup and consequence should make each action readable. | Identify missing shell/hat/feather layers and author the relevant age-specific keyframes. Props need inspected production assets, provenance and attachment rules; no geometric stand-ins. |

Make the high-five interaction on one representative age first, then compare
Baby, age 6 and age 12 before expanding. A small contextual repertoire is the
trade-off: less constant spectacle, but clearer intent, less fatigue and room
for an actual milestone to feel special.

## Acceptance criteria for the proposed work

- Read acknowledgement at 52 px and 256 px without relying on particles or sound.
  The 80 ms acknowledgement is a design target to measure, not a current claim.
- Keep wings attached to the torso, feet/contact anchored and hit rectangles
  still. Anticipation, contact, expression and any sound share one owned event.
- No extra learning credit, coins, new purchases or hidden progress for touching
  Pip. No action delays the next answer or captures the header's menu action.
- Speaking, pause, hidden page, scene exit and a newer higher-priority action
  cancel or replace the gesture. Late callbacks cannot restart it.
- Reduced motion has a meaningful inspected still; muted play stays readable.
  No sound autoplay, fake speech or overlapping quacks.
- Compare repeated ordinary actions, cancellation and quiet periods at the same
  size/input sequence, not only the best isolated clip. Seek actual playtest
  feedback before claiming delight or improved motivation.

## Review page delivered now

Run `npm run preview:pip`, then open `http://127.0.0.1:41774/actions.html`.
The Growth journey and All actions pages link to each other.

The new page includes category/age/search filters, every supported age variant,
one selected animated subject, replay/pause, scrubbing, native/slow speed,
optional loop, 52/120/256 px inspection and actual reduced-motion samples.
All thumbnails are stills; loading the page never starts dozens of competing loops.

`tools/pip-growth/export-review.cjs` runs the native sampler
`tools/pip-growth/export-review.gd`, then samples the maintained loading-screen
functions through real Web Animations in an isolated browser. It writes the
review-only `action-catalog.json` and copies the original Spring SVG atlas.
Its source hashes make a stale catalog detectable. The browser draws the
unmodified production PNG cells at those sampled transforms; it does not invent
new choreography or run wallet/learning code. Samples are 24 fps and omit game
audio and surrounding reward particles. Expression and attention states are
distinguished from finite animations, and proposed work has its own section.

Regenerate after changing the mascot or its source catalogs:

    node tools\pip-growth\export-review.cjs

The review remains development-only and excluded from production export. No new
gameplay interaction, asset acquisition, commit, push or deployment is included
in this task.
