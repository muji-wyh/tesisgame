# Chest coins

The numerical policy, affordability targets and reproducible budget scenarios
are documented in [Coin economy](coin-economy.md). Chest payouts and saved wallet
balances retain their previous values. Future purchases use escalating per-round
prices. Jelly Words collection bonuses now follow the merged-level table: Lv1
has no bonus; Lv2-6 have respective chances of 2%, 4%, 12%, 20% and 30%, with
winning amounts of 50, 100, 150, 200 and 250 coins. Only collecting a valid merged word can award this level bonus;
root count and mass do not determine it. The same reserved outcome and receipt
survive persistence retries, preventing rerolls or duplicate payment.

Opening an ordinary chest awards **50 coins**. A levelled chest awards **50 × its chest level**: level 2 gives 100, level 3 gives 150, and so on. Pip's learning level and age do not change the payout. Match retains its ordinary tier-one chest, 50% round drop chance, and guarantee after two completed dry rounds. Memory starts at the highest available chest level, currently 6, and loses one level per wrong pair. Completing all five pairs earns the remaining level and its matching payout; level zero earns no chest or coins. Memory has no random drop or dry-round guarantee. Phrase Builder pays 50 coins. Voice Pop and Jelly Match pay according to the final level of each earned chest.

The opening retains the existing chest performance. At completion, eight to fourteen production coin sprites emerge from the measured chest cavity, rise briefly, and follow curved paths into the header's coin display. The first deposit arrives after 1.14 seconds; following coins arrive 45 milliseconds apart. Each arrival releases its exact share into a rolling counter. The particles represent the reward amount rather than one coin apiece. Reduced motion uses a short static acknowledgement and an immediate count update.

`CoinWallet` saves the balance and permanent chest receipts together. The balance starts at zero; previously consumed chests are not credited retroactively. Pop/Jelly entries retain their original reward IDs when unopened inventory moves between batches. Coins are saved before a chest is consumed, so a partial save can be retried without paying twice. The existing silent settlement of earned single-round chests on exit/recovery also settles their coins, without replaying a flight.

The wallet is authoritative; the header has a separate visual total while coins are travelling. Leaving the page, changing rounds, opening the catalog, or leaving the reward room reconciles that display to the saved total and discards old animation callbacks. A subsequent save retry cannot replay an already reconciled deposit. Presentation never writes the wallet. Storage failures preserve the chest and expose the existing retry controls.

All game modes settle in a modal over the completed board; standalone result pages are removed. Match, Memory and Phrase Builder retain their completion performance inside the modal, followed by their existing chest actions. Voice Pop and both Jelly modes show their results immediately, including rounds without a chest. Jelly Finish uses **Round complete**; full-board danger expiry uses **Game over**. Hold an earned chest to open it there and watch its coins fly into the header.

**Home** and **Play again** collect earned unopened chests before leaving a completed round, without waiting for opening or flight animations. Pop and Jelly also settle retained pending treasure using its original receipts. Reentering an ended game from Home starts a fresh round; a live round still pauses and offers **Continue**. Voice Pop replay returns to its microphone gate. A failed save keeps settlement available for retry; repeating an action cannot credit the same chest twice. These presentation changes do not change payouts or reward identities.

Coin artwork, rights, build preparation and inspection are documented in [the coin asset record](assets/coins.md). Local capture images and review scripts remain under the excluded `build/` directory. Focused coverage lives in `coin_wallet_tests.gd`, `pop_reward_identity_tests.gd`, `coin_reward_flow_tests.gd`, and the existing chest lifecycle suites.
