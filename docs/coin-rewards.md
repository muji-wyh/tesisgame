# Chest coins

The numerical policy, affordability targets and reproducible budget scenarios
are documented in [Coin economy](coin-economy.md). Chest payouts and saved wallet
balances retain their previous values. Future purchases use escalating per-round
prices, and rare Jelly collection bonuses are capped at 100 coins.

Opening an ordinary chest awards **50 coins**. A levelled chest awards **50 × its chest level**: level 2 gives 100, level 3 gives 150, and so on. Pip's learning level and age do not change the payout. Match and Memory always show the ordinary tier-one wooden chest; their existing 50% round drop chance and separate three-round guarantees are unchanged. Phrase Builder also pays 50 coins. Voice Pop and Jelly Match pay according to the final level of each earned chest.

The opening retains the existing chest performance. At completion, eight to fourteen production coin sprites emerge from the measured chest cavity, rise briefly, and follow curved paths into the header's coin display. The first deposit arrives after 1.14 seconds; following coins arrive 45 milliseconds apart. Each arrival releases its exact share into a rolling counter. The particles represent the reward amount rather than one coin apiece. Reduced motion uses a short static acknowledgement and an immediate count update.

`CoinWallet` saves the balance and permanent chest receipts together. The balance starts at zero; previously consumed chests are not credited retroactively. Pop/Jelly entries retain their original reward IDs when unopened inventory moves between batches. Coins are saved before a chest is consumed, so a partial save can be retried without paying twice. The existing silent settlement of earned single-round chests on exit/recovery also settles their coins, without replaying a flight.

The wallet is authoritative; the header has a separate visual total while coins are travelling. Leaving the page, changing rounds, opening the catalog, or leaving the reward room reconciles that display to the saved total and discards old animation callbacks. A subsequent save retry cannot replay an already reconciled deposit. Presentation never writes the wallet. Storage failures preserve the chest and expose the existing retry controls.

All game modes settle in a modal over the completed board; standalone result pages are removed. Match, Memory and Phrase Builder retain their completion performance inside the modal, followed by their existing chest actions. Voice Pop and both Jelly modes show their results immediately, including rounds without a chest. Jelly Finish uses **Round complete**; full-board danger expiry uses **Game over**. Hold an earned chest to open it there and watch its coins fly into the header.

**Play again** collects every pending Jelly chest immediately and starts a fresh round without opening or flight animations, including treasure retained from an earlier session. Voice Pop instead preserves unopened treasure and returns to the microphone gate. **Home** preserves pending Pop and Jelly treasure. A failed save keeps settlement available for retry; repeating an action cannot credit the same chest twice. These presentation changes do not change payouts or reward identities.

Coin artwork, rights, build preparation and inspection are documented in [the coin asset record](assets/coins.md). Local capture images and review scripts remain under the excluded `build/` directory. Focused coverage lives in `coin_wallet_tests.gd`, `pop_reward_identity_tests.gd`, `coin_reward_flow_tests.gd`, and the existing chest lifecycle suites.
