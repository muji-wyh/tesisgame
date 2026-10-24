# Jelly Words combo system

## Behavior

Successful manual merges and committed manual or automatic collections increase
one round's exact combo count. Only an invalid merge resets it. Preview fast
drops, repositioning, waiting, pauses and stage changes preserve the chain.
Paid Auto Merge is neutral. A new round starts from zero.

Manual merges pay 0 coins at counts 1-2, 1 at 3-5, 2 at 6-9 and 3 at 10 or
above. Collections advance the chain without a combo payout and retain their
existing level bonus. The cap limits additional income to three coins per net
body consumed by manual merging. See [the economy analysis](../coin-economy.md).

The badge shows D/C/B/A/S/SS/SSS at counts 1/3/6/10/15/25/40, together with the
exact count. Each increment triggers a bounded sparkle/ray flourish, a short
text pop and a rising audio accent. A paying merge briefly displays its exact
coin increment. Reduced motion retains static rank, count and reward feedback.
The badge uses existing space beside Collect or in the side rail, preserving
the previous board size and touch targets.

## Persistence and lifecycle

Wallet version 3 accepts exact positive integer credits while preserving older
wallets and whole-tier purchase validation. The wallet saves the stable combo
receipt before consuming either merge input. Failed saves preserve both inputs
and the original amount until Retry saving; repeated calls cannot pay twice.

Collection learning evidence is recorded before its presentation callbacks.
Generic HUD refreshes cannot consume a new combo event before its sound and
flourish. Each automatic collection completion therefore keeps its own feedback.

## Verification

Evidence is retained under `build/qa/jelly-combo-2026-10-25/`.

- Model, wallet, GameUI flow, hybrid, morphology, stage and professional
  integration suites: 116,241 checks, zero failures.
- The focused combo suite contributes 365 of those checks, including real
  GameUI persistence failure/retry/reload and one sound/HUD pulse per committed
  word in a three-item Auto Collect batch.
- Word Jelly view suite after final layout changes: 19,841 assertions, zero
  failures. Existing board utilization and minimum cell-size constraints pass.
- Shared coin-economy suite: 880 checks, zero failures.
- Browser wallet host and test-runner suites: eight tests passed.
- Bundled audio inventory and existing world-audio suite: six tests passed.
- Combo audio lifecycle: 117 checks; existing level and Jelly audio: 93 and
  195 checks. Export suite: 43 tests passed.
- Final Web build verifies 391 audio resources, all vocabulary packs and the
  startup game pack. Its receipt verifies 13,608 source inputs and 117 outputs.
- Three final-export Playwright cases passed: desktop combo, Android combo,
  and the existing desktop pictured-word/menu/reload flow. Real input produced
  counts 1/2/3 with balances 0/0/1; preview fast drop preserved count 3 and
  Collect advanced it to 6 in 420ms without an additional combo payout. Both
  platforms recorded six progressively rising playback rates. The three-item
  collection completes the seeded curriculum, so its final screenshot shows
  the expected round-complete modal; the count and audio proof remain in JSON.

The original extra header row reduced phone cell sizes. Final placement uses
existing footer/rail space instead. An additional short-landscape card-edge
collision moved the narrow-layout fallback into the lower left gutter, below
the collected-word cards. Native render fixtures inspect local and
hosted layouts, portrait and short landscape, high ranks, collection fireworks,
idle recovery and reduced motion. These fixtures seed diagnostic game states;
they do not represent a recorded player session.

The final 144-capture audit checks 36 scenarios across 18 layout slots: all
recorded HUD/label bounds and Finish, Collect, stage and reading-card separation
checks pass. All 72 successful pulse/cue transitions and 24 reduced-motion
frames pass. The original collision captures remain in
`integrated-before-card-separation/` for comparison.

Artwork and recordings were already acquired production inputs. Their original
creators, licenses and adaptation details are in [combo artwork](../assets/jelly-combo.md)
and [combo audio](../assets/jelly-combo-audio.md). Audio waveform, routing,
playback-rate and mix checks are technical evidence, not an auditory or physical
device sign-off.
