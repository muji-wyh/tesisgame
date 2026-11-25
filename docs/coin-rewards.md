# Coin rewards

The numerical policy, affordability targets and reproducible budget scenarios
are documented in [Coin economy](coin-economy.md). Paid receipts and saved wallet
balances retain their previous values. Future purchases use escalating per-round
prices. Jelly Words collection bonuses follow the merged-level table: Lv1
has no bonus; Lv2-Lv9 have respective chances of 12%, 22%, 32%, 42%, 52%, 62%,
72%, and 85%, with winning amounts of 50, 100, 150, 200, 250, 300, 350, and 450
coins. Only collecting a valid merged word can award this level bonus;
root count and mass do not determine it. The same reserved outcome and receipt
survive persistence retries, preventing rerolls or duplicate payment.

An ordinary newly quoted chest has a **75-coin base** plus
**ceil(24 * Pip level / 99)** bonus coins.
Pip's earned level is clamped to 0-99; age does not affect payment. Professional
vocabulary uses the current career Pip level, matching the header. A tiered chest
multiplies both base and bonus by its tier. For example, Pip Lv20 earns 80 coins
from an ordinary chest or 480 from tier six; Pip Lv99 earns 99 or 594. The bonus
stops at 32% of the increased base. Match and Phrase use ordinary chests. Voice Pop and both
Jelly modes use each earned chest's final tier. Memory begins at tier six and
loses one tier per wrong pair; finishing all five pairs earns the remaining
chest, while tier zero earns none. Existing drop and guarantee rules are unchanged.

The opening retains the existing chest performance. At completion, eight to fourteen production coin sprites emerge from the measured chest cavity, rise briefly, and follow curved paths into the header's coin display. The first deposit arrives after 1.14 seconds; following coins arrive 45 milliseconds apart. Each arrival releases its exact share into a rolling counter. The particles represent the reward amount rather than one coin apiece. Reduced motion uses a short static acknowledgement and an immediate count update.

## Jelly combo bonus

Paying manual merges launch coins from the gold **COMBO BONUS** coin in the combo
display, not from a collected jelly or a random screen position. The existing
acquired gold atlas supplies one to six sprites matching the exact one-, two-,
four-, or six-coin reward (`0 / 1 / 2 / 4 / 6` for chains `1-2 / 3-5 / 6-9 /
10-14 / 15+`). A compact lift leads into curved travel to the header's
coin icon; the existing bonus caption stays at its source instead of duplicating
a large floating amount.

The wallet saves the immutable combo receipt first. Its display holds the old
total while the sprites travel, then the same arrival-driven odometer rolls
upward and the icon pulses. Pausing freezes both timelines. Leaving or hiding
the game reconciles to the saved balance without replaying the payout. Failed
saves and duplicate receipts never launch coins. Reduced motion keeps a short
static acknowledgement and updates the exact total without flight or rolling.

## Campaign stars

New numbered-stage settlements add a separate immutable clear receipt under the
`jelly-stage-clear-v2` policy:

- **First-clear base**: `75 + 15 * (chapter - 1)` coins (`75` in Chapter 1 up to
  `225` in Chapter 11). Replaying an already-cleared stage uses **50%** of that
  base (`round(raw_base * 0.5)`).
- **Star multiplier & chest cap**: For 1, 2 or 3 stars, the sum of the stage base
  and up to **200 coins** of the current stage's already-quoted chest
  (`weighted_chest = min(chest_coins, 200)`) is multiplied by **1x, 1.5x or 2x**
  (rounding upward). Any chest coins above 200 are paid in full (`1x`) without
  multiplication so high-tier chests cannot explode payouts.
- **Pure Clear bonus**: First-time clears completed with **0 paid powerups**
  earn an extra **+20% of base** (`+15` on Stage 1 up to `+45` on Stage 99).
- **Star-upgrade bonus**: Replaying a stage and improving its best star rating
  awards **+35 coins per newly earned star**.
- **Leftover fragment rebate**: Unconverted chest fragments left at settlement
  (`fragments < 4` or `(fragments - 4) % 5`) convert at **15 coins per fragment**,
  including on failed runs and Challenges.
- **Boss & Challenge bonuses**: Defeating one of the 8 main-story Bosses for the
  first time pays a one-time bounty (`100, 125, 150, 200, 250, 300, 350, 500`);
  Pirate Mini-Raids pay `+75`. Survival Challenge awards cumulative `50 * k`
  milestone coins every 5th stage reached plus `+75` for setting a new record at
  Stage 3+.

The chest is still paid through its original receipt; the clear receipt pays
only the difference plus applicable bonuses. Already credited combo and
rare-pickup coins are not multiplied again. Replays have their own round
receipt; retrying that same settlement cannot pay twice or downgrade stars.

For example, a Stage 1 first clear with no chest and zero paid powerups pays
`75 + 15 = 90` (1★), `113 + 15 = 128` (2★), or `150 + 15 = 165` (3★). Replaying
Stage 1 for 3★ with no chest pays `round(75 * 0.5) * 2 = 76` coins (plus `+35`
per star if improving an earlier 1★ or 2★ record).

Newly earned chests stop upgrading at **Lv30**. Existing historical quotes and
their paid receipts remain valid without silently changing their original tier
or amount. Real 3D tier presentation is documented in
[the chest catalog](../assets/chests/sources/cc0/README.md).

`CoinWallet` version 5 retains the chest quotes introduced in version 4: each chest's original
receipt ID, tier, Pip level, base, bonus and total. The first settlement
presentation or claim locks this quote across level changes and reloads.
An older chest without a quote receives the new `pip-chest-v2` policy. Already
reserved `pip-chest-v1` quotes retain their original amounts even if unopened;
paid legacy receipts also retain their original amount without a top-up.
Pop/Jelly entries keep their original reward
IDs across inventory batches. Coins are saved before chest consumption, so a
partial save retries the same total without paying twice. Silent exit/recovery
uses the same quote without replaying a flight.

New purchases use 25-coin units, including the 75-coin goal-family tier.
Versions 1-4 still load without rewriting balances, receipts or chest quotes.
Only a successfully saved change updates the format; failed saves, retries and
duplicate acknowledgments cannot migrate or charge twice. Older versions retain
their original 50-coin debit validation. Reward amounts and historical payments
are not rounded, repriced or refunded.

The wallet is authoritative; the header has a separate visual total while coins are travelling. Leaving the page, changing rounds, opening the catalog, or leaving the reward room reconciles that display to the saved total and discards old animation callbacks. A subsequent save retry cannot replay an already reconciled deposit. Coin-flight presentation never writes the wallet. Storage failures preserve the chest and expose the existing retry controls.

All game modes settle in a modal over the completed board; standalone result
pages are removed. Match, Memory and Phrase Builder retain their completion
performance inside the modal, followed by their existing chest actions. Voice
Pop shows its result immediately. Both Jelly modes first show a 1.8-second
visual and sound cue, including rounds without a chest, before opening the
modal. Jelly Finish uses **Round complete**; full-board danger expiry uses
**Game over**. Hold an earned chest to open it there and watch its coins fly
into the header.

After opening, the settlement receipt shows **Chest base + Pip Lv bonus** and
an emphasized **Total coins**. Its reserved space matches the preceding chest
invitation, so the artwork does not jump when the receipt appears. Hold and
save/retry instructions remain available until successful opening. Paid legacy
receipts show their saved total without inventing a historical Pip level.

**Home** and **Play again** collect earned unopened chests before leaving a completed round, without waiting for opening or flight animations. Pop and Jelly also settle retained pending treasure using its original receipts. Reentering an ended game from Home starts a fresh round; a live round still pauses and offers **Continue**. Voice Pop replay returns to its microphone gate. A failed save keeps settlement available for retry; repeating an action cannot credit the same chest twice.

Coin artwork, rights, build preparation and inspection are documented in [the coin asset record](assets/coins.md). Local capture images and review scripts remain under the excluded `build/` directory. Focused coverage lives in `coin_wallet_tests.gd`, `pop_reward_identity_tests.gd`, `coin_reward_flow_tests.gd`, and the existing chest lifecycle suites.
