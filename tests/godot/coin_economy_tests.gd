extends SceneTree

const Economy = preload("res://scripts/coin_economy.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Jelly = preload("res://scripts/word_jelly_model.gd")
const Report = preload("res://tools/coin-economy-report.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")

var checks: int = 0
var failures: int = 0


class Storage extends RefCounted:
	var text: Variant = null
	var fail_write: bool = false

	func coinWalletState() -> Variant:
		return text

	func saveCoinWalletState(value: String, expected: Variant) -> bool:
		if fail_write or text != expected:
			return false
		text = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	_test_economy_ladder()
	_test_pip_chest_rewards()
	_test_supply_and_budget()
	_test_treasure_cannot_self_fund()
	_test_max_pip_treasure_sink()
	_test_paid_model_and_wallet()
	_test_real_lucky_collection()
	print("Coin economy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_economy_ladder() -> void:
	var hints: Array[int] = []
	var peeks: Array[int] = []
	var auto: Array[int] = []
	var family: Array[int] = []
	var treasure: Array[int] = []
	var extra_time: Array[int] = []
	for use in range(5):
		hints.append(Economy.match_hint_price(use))
		peeks.append(Economy.memory_peek_price(use))
		auto.append(Economy.powerup_price("auto_merge", use))
		family.append(Economy.powerup_price("family_merge", use))
		treasure.append(Economy.powerup_price("fragments", use))
		extra_time.append(Economy.powerup_price("extra_time", use))
	check(hints == [100, 150, 200, 200, 200], "Match starts accessible and charges more for repeated help")
	check(peeks == [0, 100, 200, 300, 300], "Memory preserves a free first look and its existing capped ladder")
	check(auto == [50, 100, 150, 150, 150], "Auto Merge charges its differentiated capped successful-use ladder at Lv1-5")
	check(family == [25, 50, 75, 75, 75], "Family merge keeps the accessible 25/50/75 per-use price ladder")
	check(treasure == [200, 300, 400, 400, 400], "Treasure is a smaller decision with increasing repeat prices")
	check(extra_time == [100, 150, 200, 250, 300], "Extra time retains its independent fifty-coin repeat increment")
	for price: int in hints + peeks + auto + family + treasure + extra_time:
		check(price >= 0 and price % 25 == 0, "Every configured price fits the wallet's quarter-hundred purchase unit")
	check(Economy.match_hint_price(-1) == 100 and Economy.memory_peek_price(-1) == 0
		and Economy.powerup_price("auto_merge", -1) == 50
		and Economy.powerup_price("family_merge", -1) == 25, "Negative counters cannot discount a first purchase")
	check(Economy.powerup_price("unknown", 0) == 0, "Unknown item kinds have no purchasable price")
	for level in range(1, 10):
		var expected_discount: int = 25 if level >= 6 else 0
		for use in range(5):
			var price: int = Economy.powerup_price("auto_merge", use, level)
			var expected_auto: int = 50 + 50 * mini(use, 2) - expected_discount
			check(price == expected_auto and price % 25 == 0,
				"Owned Auto Merge Lv%d use %d applies the exact wallet-compatible quote" % [level, use])
	check(Economy.powerup_price("auto_merge", 0, -5) == 50
		and Economy.powerup_price("auto_merge", 999999, 5) == 150
		and Economy.powerup_price("auto_merge", 999999, 99) == 125,
		"Repeat-use inflation stays capped and Lv6+ discount applies cleanly even at extreme inputs")
	for use in range(5):
		var use_price: int = Economy.powerup_price("family_merge", use)
		var auto_lv9_price: int = Economy.powerup_price("auto_merge", use, 9)
		for freed_spaces in [-1, 0, 1, 2, 3, 6, 11, 56, 999999]:
			var price: int = Economy.powerup_price("family_merge", use, 1, freed_spaces)
			check(price == use_price and price % 25 == 0
				and Economy.powerup_price("auto_merge", use, 9, freed_spaces) == auto_lv9_price,
				"Both merge tools charge once per use regardless of the number of board spaces freed")
	check(Economy.powerup_price("family_merge", 0, 1, 0) == 25
		and Economy.powerup_price("family_merge", 0, 1, -1) == 25
		and Economy.powerup_price("auto_merge", 0, 1, 0) == 50
		and Economy.powerup_price("auto_merge", 0, 9, 0) == 25,
		"Legacy reduction arguments do not change either tool's first-use price")
	check(Economy.boss_first_victory_bounty(1) == 100 and Economy.boss_first_victory_bounty(8) == 500
		and Economy.boss_first_victory_bounty(0) == 0 and Economy.boss_first_victory_bounty(9) == 0,
		"Boss first-victory bounties scale from 100 to 500 across the 8 main bosses")
	check(Economy.challenge_milestone_bonus(4) == 0 and Economy.challenge_milestone_bonus(5) == 50
		and Economy.challenge_milestone_bonus(10) == 150 and Economy.challenge_milestone_bonus(15) == 300,
		"Challenge stage milestones award cumulative 50*k bonuses every 5 stages")
	check(Economy.leftover_fragment_coins(0) == 0 and Economy.leftover_fragment_coins(3) == 45
		and Economy.leftover_fragment_coins(4) == 0 and Economy.leftover_fragment_coins(7) == 45
		and Economy.leftover_fragment_coins(9) == 0,
		"Leftover unconverted chest fragments convert cleanly at 15 coins per fragment")
	check(Economy.prestige_price(1) == 1000 and Economy.prestige_price(2) == 1250
		and Economy.prestige_price(50) == 13250,
		"Golden Crown prestige rank pricing scales linearly from 1000 by 250 per rank")
	check(is_equal_approx(Economy.star_charm_boss_damage_bonus(4), 0.0)
		and is_equal_approx(Economy.star_charm_boss_damage_bonus(5), 0.08)
		and is_equal_approx(Economy.star_charm_boss_damage_bonus(9), 0.15),
		"Star Charm grants +8% Boss damage at Lv5 and +15% at Lv9")
	var chances: Array[float] = [0.0, 0.12, 0.22, 0.32, 0.42, 0.52, 0.62, 0.72, 0.85]
	var amounts: Array[int] = [0, 50, 100, 150, 200, 250, 300, 350, 450]
	# Higher merged levels improve both the chance and potential payout.
	for level in range(1, 10):
		check(is_equal_approx(Economy.jelly_bonus_chance(level), chances[level - 1])
			and Economy.jelly_bonus(level) == amounts[level - 1],
			"Collection odds and amounts preserve the recorded level %d table" % level)
		if level > 1:
			check(Economy.jelly_bonus_chance(level) > Economy.jelly_bonus_chance(level - 1)
				and Economy.jelly_bonus(level) > Economy.jelly_bonus(level - 1),
				"Upgrading through Lv9 never reduces the collection chance or potential payout")
	check(Economy.jelly_bonus(0) == 0 and Economy.jelly_bonus(-1) == 0
		and Economy.jelly_bonus(999) == 450 and is_equal_approx(Economy.jelly_bonus_chance(999), 0.85),
		"Reward lookup uses bounded merged levels and never infers a reward from mass")
	check(Economy.chest_coins(0) == 50 and Economy.chest_coins(1) == 50 and Economy.chest_coins(6) == 300,
		"Ordinary and existing levelled chest rewards keep their saved meaning")


func _test_pip_chest_rewards() -> void:
	var totals: Dictionary = {-10: 75, 0: 75, 1: 76, 4: 76, 5: 77, 20: 80, 96: 99, 97: 99, 99: 99, 1000: 99}
	for level: int in totals:
		var reward: Dictionary = Economy.chest_reward(1, level)
		check(reward.total == totals[level] and reward.base == 75 and reward.bonus == int(totals[level]) - 75
			and reward.pip_level == clampi(level, 0, 99) and reward.policy == "pip-chest-v2",
			"Pip Lv%d has the expected bounded ordinary-chest payout and visible breakdown" % level)
	check(Economy.chest_reward(0, 5) == Economy.chest_reward(1, 5)
		and Economy.chest_reward(-10, 5) == Economy.chest_reward(1, 5), "Untiered chest quotes use the ordinary tier")
	check(Economy.chest_reward(6, 99) == {"policy": Economy.CHEST_REWARD_POLICY, "pip_level": 99,
		"tier": 6, "base": 450, "bonus": 144, "total": 594}, "A highest-art-tier chest shows its full bounded Pip contribution")
	for tier in [1, 2, 6, 50, 300]:
		var previous: int = 0
		for level in range(100):
			var reward: Dictionary = Economy.chest_reward(tier, level)
			check(reward.total >= previous and reward.total >= tier * 75 and reward.total <= tier * 99
				and reward.base + reward.bonus == reward.total, "Pip advancement cannot reduce or overinflate a chest payout")
			previous = reward.total
	check(Economy.chest_coins(6) == 300 and Economy.jelly_bonus(2) == 50 and Economy.jelly_combo_bonus(10) == 4
		and Economy.jelly_combo_bonus(15) == 6,
		"Chest growth does not change fixed tier, random collection, or combo reward policies")


func _test_max_pip_treasure_sink() -> void:
	var largest_return: int = 0
	for existing in range(101):
		var before_tier: int = RewardProgress.reward_progress(existing).chest_tier
		var before: int = Economy.chest_reward(before_tier, 99).total if before_tier > 0 else 0
		for added in range(Economy.TREASURE_FRAGMENT_MIN, Economy.TREASURE_FRAGMENT_MAX + 1):
			var after_tier: int = RewardProgress.reward_progress(existing + added).chest_tier
			var after: int = Economy.chest_reward(after_tier, 99).total if after_tier > 0 else 0
			var extra: int = after - before
			largest_return = maxi(largest_return, extra)
			check(extra <= 198 and extra < Economy.powerup_price("fragments", 0),
				"Even maximum-Pip Treasure luck cannot refund the purchase that supplied its fragments")
	check(largest_return == 198 and Economy.powerup_price("fragments", 0) - largest_return == 2,
		"Higher chest payouts still cannot refund or profit from their own Treasure purchase")


func _test_supply_and_budget() -> void:
	for count in [1, 7, 20, 60]:
		var supplied: Array[Dictionary] = Report.supply_groups(count)
		check(supplied.size() == count and supplied.all(func(group: Dictionary) -> bool: return int(group.chunks) == 2),
			"Odd seven-piece packets never count an incomplete source word in the income ledger")
	var groups: Array[Dictionary] = Report.supply_groups(60)
	check(groups.size() == 60, "The report enumerates sixty actual supplied word groups")
	var fragments: int = 0
	for group: Dictionary in groups:
		check(int(group.chunks) == 2, "Natural source words still consist of complete two-chunk pairs")
		fragments += int(group.fragments)
	check(fragments == 30, "The budget uses actual natural supply: thirty fragments per sixty source words")
	check(Report.chest_payout(3) == 0 and Report.chest_payout(4) == 75
		and Report.chest_payout(8) == 75 and Report.chest_payout(9) == 150,
		"Budget calculations observe real chest unlock and upgrade thresholds")
	check(is_equal_approx(Report.expected_chest(10, 0.6), 74.369664),
		"Partial success uses the exact threshold distribution instead of rounding mean fragments")
	var report: Dictionary = Report.build_report()
	check(report == Report.build_report(), "Economy reports reproduce exactly from the fixed supply seed")
	for row: Dictionary in report.scenarios:
		check(int(row.auto_merge_level) == 9 and int(row.auto_merge_reduction_count) == 11,
			"The workload comparison explicitly models eleven simple full-capacity paths at owned Lv9")
		check(float(row.free_play_total) > 0.0, "Playing without paid help always builds savings in the modeled workloads")
		check(float(row.free_play_bonus) == 0.0 and float(row.free_play_chest) == float(row.free_play_total),
			"Collecting ordinary Lv1 words earns only the unchanged chest income")
		if int(row.supplied_words) >= 40:
			check(float(row.one_treasure_every_three_sessions_net_average) > 0.0,
				"Larger ordinary workloads can save while buying a first-price Treasure every three rounds")
		check(is_equal_approx(float(row.one_auto_merge_net), float(row.free_play_total) - 25.0)
			and is_equal_approx(float(row.three_auto_merge_net), float(row.free_play_total) - 225.0),
			"Per-use pricing subtracts the exact Lv9-discounted first debit or three-use total from modeled earnings")
		check(float(row.three_treasure_net) < 0.0,
			"Three Treasure purchases cannot sustain themselves even when every paid fragment is retained")
		if is_equal_approx(float(row.success_probability), 1.0):
			check(is_equal_approx(float(row.free_play_total), int(row.supplied_words) * 7.5),
				"Perfect Lv1 completion earns 7.5 chest coins per source word in full ten-word blocks")
	check(report.upgraded_collections.size() == 9, "The report includes all nine playable merge levels")
	var expected_per_source: Array[float] = [0.0, 6.0 / 2.0, 22.0 / 3.0, 48.0 / 4.0, 84.0 / 5.0, 130.0 / 6.0,
		186.0 / 7.0, 252.0 / 8.0, 382.5 / 9.0]
	var source_counts: Array[int] = []
	for row: Dictionary in report.upgraded_collections:
		check(is_equal_approx(float(row.expected_bonus), Economy.jelly_bonus_chance(int(row.merge_level)) * Economy.jelly_bonus(int(row.merge_level))),
			"Every upgrade scenario uses the exact level-dependent expectation")
		source_counts.append(int(row.source_words))
		check(is_equal_approx(float(row.expected_bonus_per_source_word), expected_per_source[int(row.merge_level) - 1]),
			"The source-word budget accounts for additive merges instead of same-level doubling")
	check(source_counts == [1, 2, 3, 4, 5, 6, 7, 8, 9], "Each playable collection level retains its completed source-word count")
	check(report.scenarios.all(func(row: Dictionary) -> bool: return float(row.one_auto_merge_net) > 0.0),
		"Every modeled workload can retain savings after one first-price Auto Merge use")
	check(report.auto_merge_prices.size() == 9, "The live report includes every owned Auto Merge full-capacity example")
	for row: Dictionary in report.auto_merge_prices:
		var level: int = int(row.owned_level)
		var discount: int = 25 if level >= 6 else 0
		check(int(row.capacity) == Economy.auto_merge_capacity(level) and int(row.reduction_count) == int(row.capacity)
			and int(row.first_use) == 50 - discount
			and int(row.second_use) == 100 - discount
			and int(row.third_and_later) == 150 - discount,
			"Reported full-capacity examples reflect the 50/100/150 ladder and Lv6+ -25 discount")
	check(Report.purchase_total("auto_merge", 3, 9, 11) == 225
		and Report.purchase_total("auto_merge", 3, 1, 3) == 300
		and Report.purchase_total("auto_merge", 3, 5) == 300
		and Report.purchase_total("auto_merge", 3, 6) == 225
		and Report.purchase_total("fragments", 3) == 900,
		"Workload comparisons reflect the Lv6+ discount while preserving retired receipt policies")
	check(report.upgrade_totals == {"jelly": 4650, "auto_merge": 3700, "star_charm": 5225, "combined": 13575},
		"Economy report publishes the exact differentiated 3-track upgrade totals")
	check(Report.purchase_total("family_merge", 3) == 150,
		"Three family purchases cost the actual twenty-five, fifty and seventy-five tiers")
	check(Report.purchase_total("family_merge", 3, 1, 3) == 150,
		"Larger family operations retain the same successful-use tiers")


func _test_treasure_cannot_self_fund() -> void:
	var largest_return: int = 0
	for existing in range(101):
		for added in range(Economy.TREASURE_FRAGMENT_MIN, Economy.TREASURE_FRAGMENT_MAX + 1):
			var extra: int = Report.chest_payout(existing + added) - Report.chest_payout(existing)
			largest_return = maxi(largest_return, extra)
			check(extra <= 150 and extra < Economy.powerup_price("fragments", 0),
				"Every fragment threshold and two-to-eight outcome is strictly cheaper to earn than to buy")
	check(largest_return == 150, "The exhaustive Lv0 Treasure ceiling is two chest levels or one hundred fifty coins")
	var average_over_offsets: float = 0.0
	for existing in range(5, 10):
		for added in range(2, 9):
			average_over_offsets += (Report.chest_payout(existing + added) - Report.chest_payout(existing)) / 35.0
	check(is_equal_approx(average_over_offsets, 75.0), "Across all five upgrade offsets, average Lv0 Treasure return is seventy-five coins")
	check(Economy.powerup_price("fragments", 0) - largest_return >= 50,
		"Even perfect Lv0 Treasure luck consumes at least fifty previously earned coins")


func _test_paid_model_and_wallet() -> void:
	var storage := Storage.new()
	var wallet := Wallet.new("user://unused-economy-wallet.cfg", storage)
	check(wallet.load_state() and wallet.balance == 0, "Fresh players keep free play and receive no invented starter currency")
	var game := Jelly.new()
	check(game.configure(Report.fixture_words(), 3, 19), "The purchase fixture uses a real stable opening board")
	var prepare: Callable = func() -> void:
		game.cells.clear()
		var word: Dictionary = Report.fixture_words()[0]
		for index in range(4):
			var tile: Dictionary = game._new_word_root(word, 1)
			game._set_merged_word(tile, word, 1, true)
			tile.merge({"column": index, "row": Jelly.ROWS - 1, "age": 100.0,
				"settling": false, "falling": false, "arrival": false}, true)
			game.cells.append(tile)
	prepare.call()
	var charges: Array[int] = []
	game.purchase_powerup = func(id: String, _kind: String, price: int) -> Dictionary:
		charges.append(price)
		return wallet.spend(id, price)
	var before: Array[Dictionary] = game.cells.duplicate(true)
	check(not game.activate_powerup("auto_merge") and game.cells == before and game.powerup_price("auto_merge") == 50,
		"An unaffordable first Auto merge cannot change the board or increase its next price")
	check(wallet.credit("earned:old-chest", 20).ok and wallet.balance == 1000, "Existing chest values fund a saved-wallet purchase")
	check(wallet.credit("earned:auto-merge-help", 40).ok and wallet.balance == 3000,
		"Additional earned fixture chests fund the live automatic-use ladder")
	storage.fail_write = true
	check(not game.activate_powerup("auto_merge") and wallet.balance == 3000 and game.powerup_price("auto_merge") == 50,
		"Failed persistence leaves both balance and successful-use price untouched")
	storage.fail_write = false
	for expected_price: int in [50, 100, 150]:
		prepare.call()
		var previous_balance: int = wallet.balance
		check(game.activate_powerup("auto_merge"), "A live Auto merge starts after a durable debit")
		check(wallet.balance == previous_balance - expected_price and int(charges.back()) == expected_price,
			"The real model charges the current escalating price through CoinWallet")
		game.finish_powerup(true)
		check(game.powerup_snapshot().affected_jellies == 4 and game.powerup_snapshot().completed_results == 2
			and game.cells.size() == 2
			and game.cells.reduce(func(total: int, tile: Dictionary) -> int: return total + int(tile.fragments), 0) == 4,
			"The two available complete pairs survive as two products without inventing a third or losing fragments")
	check(wallet.balance == 2700,
		"Three successful Lv1 purchases spend three hundred saved coins regardless of affected quantity")
	check(game.fragment_count == 0 and game.collected_coins == 0,
		"Automatic construction cannot grant chest progress or refund coins before word collection")
	check(game.powerup_price("auto_merge") == 150 and game.powerup_price("family_merge") == 25
		and game.powerup_price("fragments") == 0,
		"Repeat prices cap and independent item kinds do not inflate one another")
	game.configure(Report.fixture_words(), 3, 20)
	check(game.powerup_price("family_merge") == 25 and game.snapshot().powerup_uses.auto_merge == 0
		and game.snapshot().powerup_uses.family_merge == 0 and game.auto_merge_level == 1,
		"A new isolated round resets both use counters and starts with free capacity")
	var reloaded := Wallet.new("user://unused-economy-wallet.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == 2700 and reloaded.credit("earned:old-chest", 20).duplicate,
		"New price policy preserves the saved balance and old chest receipt identity")
	game.purchase_powerup = Callable()


func _test_real_lucky_collection() -> void:
	var storage := Storage.new()
	var wallet := Wallet.new("user://unused-economy-bonus.cfg", storage)
	wallet.load_state()
	var game := Jelly.new()
	game.configure(Report.fixture_words(), 3, 73)
	game.cells.clear()
	game.cells.append(game._new_tile("cat", 2, 0))
	game._set_merged_word(game.cells[0], Report.fixture_words()[0], 2, true)
	var probe := RandomNumberGenerator.new()
	var winning_seed: int = -1
	for candidate in range(10000):
		probe.seed = candidate
		if probe.randf() < Economy.jelly_bonus_chance(2):
			winning_seed = candidate
			break
	check(winning_seed >= 0, "A deterministic real RNG seed exercises the rare winning branch")
	game._coin_rng.seed = winning_seed
	game.credit_collection = func(id: String, amount: int) -> Dictionary:
		return wallet.credit("word:" + id, int(amount / Wallet.COINS_PER_TIER))
	check(game.collect(int(game.cells[0].id)), "A real completed word can reserve a lucky collection")
	game.step(Jelly.COLLECT_SECONDS + Jelly.SETTLE_SECONDS)
	check(wallet.balance == 50 and game.collected_coins == 50 and game.cleared_pairs == 1,
		"Eligible Lv2 collection commits its fifty-coin payout through the wallet")
	game.credit_collection = Callable()
