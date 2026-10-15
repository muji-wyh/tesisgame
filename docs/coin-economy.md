# Coin economy

## Intent and acceptance criteria

Coins are saved help for a difficult moment. Ordinary play remains free, builds
the wallet steadily, and never requires a purchase to finish or learn. A first
small aid should be reachable; repeated assistance should consume savings.
Chests should be the clear main source of coins, and buying Treasure must never
create a profitable currency loop.

The numerical targets are:

- Preserve every saved coin, receipt, earned chest, and chest level payout.
- Keep at least 85% of expected income in the modeled Jelly Words workloads
  coming from chests; natural long-run two-chunk play is about 91% chest income.
- Price a first Hint at two ordinary chest rewards, Treasure at four, and Auto
  Merge at twelve. This makes their relative value understandable.
- Allow occasional modest help while saving; make repeated premium help and
  repeated Treasure draw down an existing wallet.
- Keep the first Memory peek free and all normal interactions free. Failure to
  afford or save a purchase does not charge coins, grant an effect, or raise the
  next price.

These are design assumptions and reproducible model checks, not measured player
behavior. A later playtest can tune the source-count targets without replacing
the persistence rules.

## Audit and changes

The previous prices were 200 per Match hint, 500 per Treasure, and 2000 per Auto
Merge. Treasure supplied five fragments on average, worth about 50 coins in
long-run chest progression. About 90% of its purchase price was a net coin cost; Auto
Merge took roughly 30-37 minutes of perfect passive-cadence Jelly Words supply.
Those prices made optional help remote rather than creating frequent, thoughtful
decisions. Meanwhile, a lucky ordinary two-chunk word paid 100 coins, twice a
basic chest, weakening the chest's perceived importance.

The shared policy is [coin_economy.gd](../scripts/coin_economy.gd):

| Event or item | Previous values | New values |
| --- | --- | --- |
| Ordinary / tier-one chest | 50 | 50, unchanged |
| Levelled chest | 50 x level | 50 x level, unchanged |
| Match Hint | 200 each | 100, 150, then 200; no per-round use limit |
| Memory peek | 0, 100, 200, 300, then 300 | Prices unchanged. First reveal lasts 10 seconds; later reveals last 5 seconds. Repeated clicks during the countdown do not charge or extend it. |
| Auto Merge | 2000 each | 600, 900, 1200, then 1200 |
| Treasure | 500 each | 200, 300, 400, then 400 |
| Treasure fragments | Random 2-8 | Random 2-8, unchanged |
| Lucky Jelly Words collection | 1%; 50 x original chunk count | 1%; 50 for two chunks, 100 for three or more |

Only successful purchases advance their item's price. Match Hint stays at 200
coins from the third purchase onward, without a use-count allowance. An active
hint cannot be purchased again. Auto Merge and Treasure
have separate counters. A new round resets the prices; a menu, pause, rejected
payment, or wallet retry does not. The current price is shown before purchase.
Auto Merge retains its 200 ms launch rhythm and 300 ms automatic drag. It does
not collect the resulting words. Treasure retains its fragment delivery effects
and only banks its fragments when the carrying words are collected.

Larger valid words still have a larger lucky reward, capped at 100. The 1% roll
remains independent of board randomness and is reserved before payment, so
retrying a failed save cannot reroll or duplicate it.

## Income and saving targets

All chest rewards remain 50 coins per level. The shared continuous-mode chest
progression unlocks at four fragments and adds a level every five fragments.
Below four fragments the payout is zero; otherwise it is
`50 * floor((fragments + 1) / 5)`.

| Mode | Source rule | Useful source-count budget |
| --- | --- | --- |
| Match / Memory | 50% chest chance, guaranteed after two dry completed rounds | 28.57 coins per completed five-pair round on average; 3.5 rounds to save the first 100-coin Hint |
| Phrase | One ordinary chest after three phrases | 50 coins per completed round |
| Jelly Match | One fragment per three supplied word/picture pairs | About 3.33 chest coins per successfully collected pair in long runs |
| Jelly Words | One fragment per two supplied words | About 5 chest coins plus 0.5 lucky coins per successfully collected ordinary word in long runs |
| Voice Pop | Each target has a 35% chest marker chance | Expected chest coins for 10 / 20 / 30 hits: 24.34 / 59.74 / 95.06 |

The Match/Memory expectation includes the three-round guarantee:
`50 / (1 + 0.5 + 0.25) = 28.57`. Their saved guarantees remain separate.
Jelly Words' approximate long-run saving targets are 36 successfully collected
ordinary words for the first Treasure and 110 for the first Auto Merge. Without
relying on any lucky coin, those purchases require 38 and 118 source words
respectively, when their natural marked halves are all collected in one round.
Actual collections may combine pieces from different source groups, and partial
rounds can finish below a chest threshold, so these are planning units.

For reference only, automatic Jelly Words supply provides three new words every
20 seconds initially, down to every 10 seconds after twenty successful word
collections. Every four collections reduce the next cycle's interval by two seconds;
the interval is fixed at successful batch dispatch and never shortens the
countdown already running. Merging alone, Auto Merge, and idle time do not
advance this progression.

At 5.5 expected coins per ordinary source word, perfect completion gives a
theoretical automatic-supply bound of 49.5-99 expected coins per minute:
`3 * (60 / interval_seconds) * 5.5`. This is a supply calculation, not a measured
player earning rate. It excludes the initial board and assumes every supplied
word is successfully collected; players can tap the preview to release supply
early or take longer to solve it. Rewards, odds, prices, and source-count saving
targets remain unchanged. No reward-per-minute cap or artificial waiting gate
is introduced.

## Session budget scenarios

The report drains the real Jelly Words source packets, then models 20, 40, or 60
supplied two-chunk words. Each word has an independent 60% or 100% chance of being
successfully collected. A scenario session means one round. These workload and
success choices are sensitivity tests, not observations of children.

Chest income uses the full binomial fragment distribution and the real chest
thresholds, rather than paying out on rounded mean fragments. Lucky income uses
the exact 1% expected value. Paid scenarios assume an existing wallet can afford
the purchases; negative values mean savings are spent, not a negative wallet.

| Supplied words | Collection chance | No paid aid: expected coins | One Treasure: net coins | One Auto Merge: net coins | Three Treasure uses: net coins |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 20 | 60% | 55.58 | -93.90 | -544.42 | -693.99 |
| 20 | 100% | 110.00 | -54.29 | -490.00 | -650.20 |
| 40 | 60% | 121.70 | -27.93 | -478.30 | -628.00 |
| 40 | 100% | 220.00 | 55.71 | -380.00 | -540.20 |
| 60 | 60% | 188.00 | 38.00 | -412.00 | -562.00 |
| 60 | 100% | 330.00 | 165.71 | -270.00 | -430.20 |

Treasure scenarios optimistically assume every injected fragment is collected,
making their return an upper estimate for that purchase. Auto Merge is compared
at the same completed workload; its convenience and board rescue are not
treated as newly created supply. Even if it rescues every word, the 100% rows
show that using it in every modeled session still spends savings.

An occasional first-price Treasure every three fresh rounds leaves positive
expected savings in all six scenarios: approximately 5.75-275.24 coins per round
averaged across the three. Three Treasure uses in one round cost 900 and drain
savings even with perfect collection of the supplied words and paid fragments.
Three Auto Merge uses cost 2700. Thus occasional aid is reachable while constant
use remains a deliberate expense.

## Treasure cannot fund itself

For each existing fragment total from 0 through 100, the regression suite checks
every possible award from 2 through 8. The largest extra payout is two chest
levels, or 100 coins, below even the first 200-coin price. The best possible
purchase therefore consumes at least 100 saved coins.

Across the five possible upgrade offsets, uniformly distributed fragment
awards return 50 coins on average. A specific offset gives 28.57-71.43 expected
extra coins. At first price the long-run average net cost is 150; repeat prices
increase that to 250 and 350. Combining purchases or starting a fresh round for
the first price cannot turn the fragment return into a profitable loop.

## Saves and regression checks

The wallet still starts at zero and keeps its version, 50-coin denomination,
receipt IDs, and atomic debit/credit behavior. Existing balances and receipts
are not reset or recomputed. Pending saved chests keep their tier and payout.
Permanent chest receipts, retained reserved pair outcomes, and the independent
lucky collection receipt prevent duplicate callbacks, retries, or restarts from
manufacturing a second payment.

Run the reproducible report:

```powershell
node tools/run-godot.cjs --headless --path . --script res://tools/coin-economy-report.gd
```

Run the policy, actual supply, budget, Treasure, wallet, and real lucky-collection
checks:

```powershell
node tools/run-godot.cjs --headless --path . --script res://tests/godot/coin_economy_tests.gd
```

Existing wallet and reward-flow suites remain responsible for save migration,
partial saves, duplicate credit, and concurrent-session conflicts. Model and UI
purchase suites cover current-price presentation, unavailable funds, failed
saves, successful-use escalation, and reset boundaries.
