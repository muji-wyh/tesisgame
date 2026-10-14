# Obsolete logic audit

The follow-up audit traced production callers, state transitions, saved data,
export inputs and current gameplay rules after the Jelly sky and UI update.

## Removed

- **Invalid-word splitting.** Current merges accept only exact current-age
  words. There is no saved board or board-import path that can restore the old
  invalid merged bodies. The split API, split animation, split reservations,
  accessibility hint and recursive ancestry tree therefore had no production
  entry. Rejected contacts still separate with elastic feedback and a negative
  cue. Valid words can still merge into other valid words.
- **Cosmetic chest toys.** Coin rewards replaced both runtime callers of
  `show_surprise` in commit `1a1558fa`. The unused child node, animation clock,
  snapshot field and standalone implementation have been removed. The current
  opening flourish and durable coin release remain in place.
- **Jelly finale branches.** Jelly Finish and danger expiry settle directly in
  the board modal. Their former branches in the shared pre-result celebration
  have been removed; Match, Memory, Phrase Builder and Voice Pop keep that
  celebration.
- **Unused UI remnants.** Removed the age text field, medal piece-count helper
  and mode-grid alias that no production caller used.
- **Obsolete export dependencies.** Removed the requirement to ship 48 old
  theme-specific chest recordings and excluded them and six retired toy SVGs
  from the runtime pack. Original source assets and attribution remain archived
  in the repository. Export verification also rejects their imported copies.

## Corrected

Home selection and keyboard/controller default focus still indexed the display
buttons using the old mode dictionary order. With Jelly Words first, an ordinary
refresh could select the wrong card and default focus could land on a different
game. Both paths now resolve the mode by identity. Initial Home remains
unselected and starts navigation on its first displayed card.

Voice Pop's Play again action also reused the saved-treasure restoration path.
An unopened chest could therefore cover the newly started round with the reward
room. Explicit replay now retains the saved chest and shows the fresh board;
returning from Home still restores pending treasure, including older batches.
The replay intent survives deferred vocabulary loading and save recovery.

The Web screen-reader instructions still described free hints, gameplay theme
shortcuts, older restart behavior and arbitrary Jelly concatenation. They now
describe current paid Hint/Peek rules, Home navigation, exact-word merges and
pointer versus keyboard/controller Finish controls.

The build receipt now tracks the chest milestone-art preparation helper that
the build already executes. Changing that helper invalidates an existing
receipt. Current gameplay documentation now describes ordered valid merges,
independent collection reveals, silent 100 ms Collect batches, modal settlement,
fragment-based Voice Pop chests and the current coin policy.

The full regression run also exposed test fixtures that still switched modes
without Home, selected the Memory card by an outdated grid index, expected
seasonal artwork instead of tier-one chest artwork, or treated an earned chest
as having no saved reward. Other fixtures assumed cross-age question selection,
free paid hints, Pip as the Home button, or that paused chest flights had already
finished. These fixtures now use the real Home route, select
cards by identity, separate seasonal medal identity from chest appearance, and
compare reward balances before and after actions. Controller release gating,
blocked save transitions, audio cancellation and duplicate-reward checks remain
covered.

Browser fixtures also assumed that one unmastered word was guaranteed to appear
and that opening a chest required at least one second. They now select actual
current-age word pairs and observe the current 0.65-second hold. Short-hold
cancellation sends its down/up gesture without intervening snapshot polling,
then verifies that neither opening nor a durable reward occurred.
Voice feedback likewise targets an actual displayed word; exact homophone
tables retain deterministic native coverage. The cohort-promotion browser
fixture stages a valid shared save for its actual target before answering,
exercising the existing persistence rebase instead of demanding a fixed deal.
Rejected Jelly drags now verify the final supported grid footprint rather than
the old pixel position: lifting a source can let its former stack fall into that
space. The browser still checks preserved bodies and contents, no overlap,
visible separation, one negative cue and no unintended merge or reward.

## Preserved deliberately

- Keyboard and controller Finish confirmation remains the accessible alternative
  to the pointer pull gesture.
- Restored unopened treasure, old multi-chest batches, wallet receipts and
  learning/medal migrations still have live callers and saved-data obligations.
- Ordered completion glow, all-body collision feedback, support-loss gravity,
  200 ms Auto Merge launches and 300 ms travel retain their current behavior.
- Current coin prices and the independent 1% collection reward roll are unchanged.
- Web audio attachment and the Windows WebKit presentation workaround have live
  engine callers. The previously reproduced Windows WebKit dynamic-resize issue
  is outside this cleanup; see the [sky review](../assets/jelly-sky.md).

## Validation

- All 113 Godot suites passed across coordinated sequential runs and targeted
  reruns after fixing obsolete fixtures. This includes the new Home identity
  checks, ordered/nested merges, purchased fragment retention, failed collection
  rewards, independent retry receipts, and Voice Pop replay/download recovery.
- All 415 Node tests passed in the final complete Node run. Updated asset checks
  identify all 15 added artwork imports explicitly; theme-choice checks cover
  both the current four-column grid and the compact scrolling row.
- The real exported pack passed its inventory, deferred vocabulary, chest model,
  motion and audio checks, including absence of archived chest recordings and
  toy artwork. Existing chest tests verify the active opening and coin lifecycle.
- Fifteen distinct private Chromium browser flows passed across targeted runs:
  six-mode Home identity and keyboard resume; mouse and touch Finish in both
  Jelly modes; Voice Pop cancellation, explicit replay, Home restoration and
  reload; paid items and separate manual collection; rhythmic silent Collect;
  valid and rejected ordered merges with support-loss gravity; natural chest
  unlock/upgrade; manual merge pronunciation and batch speech cancellation;
  long current-age word labels; normalized spoken feedback; and cohort promotion
  with independent level progress and reload. Failed old assumptions were
  corrected and rerun; no gameplay change was made to force the fixtures to pass.
- The final Web build receipt verified all 12,663 source inputs and 117 output
  files. The packaged startup download is 32.89 MB, plus the selected vocabulary
  pack. Syntax, UTF-8 and Git whitespace checks passed.

## Production delivery

Runtime commit `28a0bd8daae9032f3e8502a377dde99a52057a55` was pushed to `main`
and deployed to the existing Azure Static Web App. Verification at
`2026-10-14T06:40:14Z` confirmed that live HTML matches the tested export exactly
and the complete decoded live game pack matches its local bytes. All eight
reviewed runtime/build entries match the receipt; the removed chest-surprise
script is absent.

- URL: <https://gentle-forest-02ff42900.3.azurestaticapps.net/>
- Pack: `game-7da80c0380c4a7c4.pck.br`
- Decoded SHA-256: `7da80c0380c4a7c4006d7f23078a79bdb17389a99ecc637ba527f72a7d702979`
- Detailed local delivery record: `build/obsolete-logic-production.json`
