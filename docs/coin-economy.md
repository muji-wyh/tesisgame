# Coin economy

## Current policy

Coins remain saved help for a difficult moment. Ordinary play is free, the
wallet starts at zero, and purchases never gate finishing or learning. Existing
balances, saved receipts, chest payouts, item prices, and fragment rules are
unchanged by the level-based Jelly collection bonus.

The shared policy is [coin_economy.gd](../scripts/coin_economy.gd):

| Event or item | Values |
| --- | --- |
| Ordinary / tier-one chest | 50 coins |
| Levelled chest | 50 coins multiplied by chest level |
| Match Hint | 100, 150, then 200; no per-round use limit |
| Memory observation | A free initial 10-second observation, then optional 5-second reveals costing 100, 200, 300, then 300 |
| Auto Merge | 600, 900, 1200, then 1200 |
| Treasure | 200, 300, 400, then 400 |
| Treasure fragments | Random 2-8 |

Only successful purchases advance their item's price. Auto Merge and Treasure
have separate counters. A new round resets the prices; a menu, pause, rejected
payment, or wallet retry does not. The current price is shown before purchase.
Auto Merge retains its 200 ms launch rhythm and 300 ms automatic drag and never
collects the resulting words. Treasure banks its fragments only when their
carrying words are collected. Memory's Start matching action can skip either
observation countdown; repeated clicks cannot charge or extend a reveal.

## Jelly Words collection bonuses

A coin bonus is considered only when collecting a valid merged word. Lv1 always
pays zero bonus. Roots, picture pieces, partial spellings, and bodies without a
valid word cannot earn one. Merging, dropping, selecting, or moving a Jelly never
awards coins. The displayed merge level determines both probability and amount;
root count, mass, word length, and carried fragments do not affect either.

| Merged level | Chance on collection | Coins on a successful drop | Expected bonus per collected body |
| ---: | ---: | ---: | ---: |
| 1 | 0% | 0 | 0 |
| 2 | 2% | 50 | 1 |
| 3 | 4% | 100 | 4 |
| 4 | 6% | 150 | 9 |
| 5 | 10% | 200 | 20 |
| 6 | 16% | 250 | 40 |
| 7 | 28% | 300 | 84 |
| 8 | 50% | 350 | 175 |
| 9 | 80% | 450 | 360 |

The expected values are averages over repeated independent collections, not a
promise for any particular collection. Building higher levels consumes matching
words, so this table does not imply an income rate or a typical player level mix.

For a budget measured per source word, a LvN body represents `2^(N-1)` completed
Lv1 words because every upgrade consumes two matching bodies of the same level.
Divide each body's expected bonus by that source count. The maximum is Lv9:
`360 / 256 = 1.40625` expected bonus coins per source word. This counts completed
words, not their component roots, and does not award bonuses during upgrading.

With every natural fragment retained and eventually collected, ordinary supply
provides about five chest coins per source word in the long run. The modeled
chest share of expected gross coins is therefore at least
`5 / (5 + 1.40625)`, approximately 78.05%, across any mix of collection levels.
This is a long-run budget bound under perfect retention, not observed player income or a
guarantee for one round; fragment thresholds, lost words, and purchase spending
can change a particular round's result.

Every accepted collection reserves one outcome under its existing collection
receipt before persistence. Eligible Lv2-9 collections draw once from the separate
coin random stream; Lv1 reserves zero without consuming a draw. A failed save,
pause, batch retry, or repeated tap reuses that decision and amount. Successful
commit pays at most once and leaves word, learning, and fragment settlement under
the existing transaction lifecycle. An upgrade that replaces a body invalidates
its obsolete pending collection receipt only when the merge commits.

## Ordinary source income and saving

All chest rewards remain 50 coins per level. Continuous modes unlock a chest at
four fragments and add one level per five further fragments. Below four fragments
the payout is zero; otherwise it is `50 * floor((fragments + 1) / 5)`.

| Mode | Source rule | Useful source-count budget |
| --- | --- | --- |
| Match | 50% chest chance, guaranteed after two dry completed rounds | 28.57 coins per completed five-pair round on average |
| Memory | Starts at the highest available chest level, currently 6; each mismatch removes one level down to zero | 300 coins for a perfect five-pair round, down to zero after six mistakes |
| Phrase | One ordinary chest after three phrases | 50 coins per completed round |
| Jelly Match | One fragment per three supplied word/picture pairs | About 3.33 chest coins per successfully collected pair in long runs |
| Jelly Words, collected at Lv1 | One fragment per two supplied words; no Lv1 coin bonus | About 5 chest coins per successfully collected ordinary word in long runs |
| Voice Pop | Each target has a 35% chest marker chance | Expected chest coins for 10 / 20 / 30 hits: 24.34 / 59.74 / 95.06 |

Match's expectation includes the three-round guarantee:
`50 / (1 + 0.5 + 0.25) = 28.57`. Memory grants its remaining chest only after the
whole round is completed; leaving an unfinished round earns nothing. Previously
earned Memory chests retain their original payouts.

Collecting ordinary Jelly words at Lv1 requires 38 source words to unlock the
first 200-coin Treasure budget, or 118 for the first 600-coin Auto Merge budget,
when every naturally marked half is collected in one round. Partial rounds can
finish below a chest threshold, and upgraded bodies combine source words, so
these are explicit planning units rather than observed player behavior.

Automatic supply provides three new source words every 20 seconds initially,
down to every 10 seconds after twenty successful word collections. Every four
collections reduce the next cycle's interval by two seconds; the interval is
fixed at dispatch and never shortens the countdown already running. Merging,
Auto Merge, and idle time do not advance that progression. At five chest coins
per source word, perfect Lv1 collection gives a theoretical automatic-supply
bound of 45-90 coins per minute. This excludes the opening board, assumes complete
collection, and is not a measured earning rate. Preview taps can release supply
early. No new cap or waiting gate is introduced.

## Reproducible workload scenarios

The report drains real source packets and models 20, 40, or 60 supplied two-chunk
words with independent 60% or 100% collection success. Each source word is
collected at Lv1, so these scenarios have zero coin bonuses and all income comes
from chests. Upgraded collection probabilities and expectations appear in a
separate report table. The source-normalized bound above assumes perfect
retention; these finite workloads use their exact fragment-threshold distributions.

Chest income uses the full binomial fragment distribution and actual reward
thresholds. Paid scenarios assume an existing wallet can afford each purchase;
negative net values mean savings are spent. Treasure calculations optimistically
retain every injected fragment. Auto Merge uses the same completed workload,
without treating convenience as new supply. One session is one fresh round.

| Supplied words | Collection chance | No paid aid: expected coins | One Treasure: net coins | One Auto Merge: net coins | Three Treasure uses: net coins |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 20 | 60% | 49.58 | -99.90 | -550.42 | -699.99 |
| 20 | 100% | 100.00 | -64.29 | -500.00 | -660.20 |
| 40 | 60% | 109.70 | -39.93 | -490.30 | -640.00 |
| 40 | 100% | 200.00 | 35.71 | -400.00 | -560.20 |
| 60 | 60% | 170.00 | 20.00 | -430.00 | -580.00 |
| 60 | 100% | 300.00 | 135.71 | -300.00 | -460.20 |

The smallest workload no longer quite funds one Treasure every three fresh
rounds on average after removing Lv1 bonuses; larger modeled workloads do.
Repeated purchases still consume savings. Prices have not been changed to offset
the new bonus policy. Three Treasure purchases cost 900; three Auto Merge uses
cost 2700.

## Treasure cannot fund itself

For every existing fragment total from 0 through 100, the regression suite checks
all awards from 2 through 8. The largest extra chest payout is two levels, or
100 coins, below the first 200-coin price. Even perfect fragment luck consumes at
least 100 saved coins. Across all five upgrade offsets, uniformly distributed
fragment awards return 50 coins on average. A particular offset gives
28.57-71.43 expected extra coins. These calculations cover Treasure's injected
fragments; independent level-based word collection bonuses are not a refund
created by buying fragments.

## Saves and validation

The wallet keeps its version, zero starting balance, 50-coin denomination,
receipt identities, and atomic debit/credit behavior. Existing balances and
receipts are not reset or recomputed. Pending saved chests keep their original
tiers and payouts. Collection presentation never writes a second payment.

Run the reproducible report:

```powershell
node tools/run-godot.cjs --headless --path . --script res://tools/coin-economy-report.gd
```

Run policy, supply, budget, Treasure, wallet, and level reward checks:

```powershell
node tools/run-godot.cjs --headless --path . --script res://tests/godot/coin_economy_tests.gd
node tools/run-godot.cjs --headless --path . --script res://tests/godot/word_jelly_model_tests.gd
node tools/run-godot.cjs --headless --path . --script res://tests/godot/word_jelly_morphology_tests.gd
```

Coverage includes Lv1 zero rewards, both sides of every eligible level's random
boundary, mass-independent odds and amounts, higher-level upgrades, coin-stream
independence, mixed batches, persistence retries, pause/reentry, and once-only
credit. Existing wallet and reward-flow suites cover saved receipts, migration,
partial writes, and concurrent-session conflicts.
