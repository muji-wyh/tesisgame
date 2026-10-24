extends SceneTree

const Economy = preload("res://scripts/coin_economy.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Jelly = preload("res://scripts/word_jelly_model.gd")
const Report = preload("res://tools/coin-economy-report.gd")

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
	_test_supply_and_budget()
	_test_treasure_cannot_self_fund()
	_test_paid_model_and_wallet()
	_test_real_lucky_collection()
	print("Coin economy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_economy_ladder() -> void:
	var hints: Array[int] = []
	var peeks: Array[int] = []
	var auto: Array[int] = []
	var treasure: Array[int] = []
	for use in range(5):
		hints.append(Economy.match_hint_price(use))
		peeks.append(Economy.memory_peek_price(use))
		auto.append(Economy.powerup_price("auto_merge", use))
		treasure.append(Economy.powerup_price("fragments", use))
	check(hints == [100, 150, 200, 200, 200], "Match starts accessible and charges more for repeated help")
	check(peeks == [0, 100, 200, 300, 300], "Memory preserves a free first look and its existing capped ladder")
	check(auto == [600, 900, 1200, 1200, 1200], "Auto Merge remains the premium item at every repeat level")
	check(treasure == [200, 300, 400, 400, 400], "Treasure is a smaller decision with increasing repeat prices")
	for price: int in hints + peeks + auto + treasure:
		check(price >= 0 and price % Wallet.COINS_PER_TIER == 0, "Every configured price is legal for existing wallet receipts")
	check(Economy.match_hint_price(-1) == 100 and Economy.memory_peek_price(-1) == 0
		and Economy.powerup_price("auto_merge", -1) == 600, "Negative counters cannot discount a first purchase")
	check(Economy.powerup_price("unknown", 0) == 0, "Unknown item kinds have no purchasable price")
	var chances: Array[float] = [0.0, 0.02, 0.04, 0.12, 0.20, 0.30, 0.28, 0.50, 0.80]
	var amounts: Array[int] = [0, 50, 100, 150, 200, 250, 300, 350, 450]
	# Historical lookup values remain available; the current report is capped at Lv6.
	for level in range(1, 10):
		check(is_equal_approx(Economy.jelly_bonus_chance(level), chances[level - 1])
			and Economy.jelly_bonus(level) == amounts[level - 1],
			"Collection odds and amounts preserve the recorded level %d table" % level)
	check(Economy.jelly_bonus(0) == 0 and Economy.jelly_bonus(-1) == 0
		and Economy.jelly_bonus(999) == 450 and is_equal_approx(Economy.jelly_bonus_chance(999), 0.80),
		"Reward lookup uses bounded merged levels and never infers a reward from mass")
	check(Economy.chest_coins(0) == 50 and Economy.chest_coins(1) == 50 and Economy.chest_coins(6) == 300,
		"Ordinary and existing levelled chest rewards keep their saved meaning")


func _test_supply_and_budget() -> void:
	var groups: Array[Dictionary] = Report.supply_groups(60)
	check(groups.size() == 60, "The report enumerates sixty actual supplied word groups")
	var fragments: int = 0
	for group: Dictionary in groups:
		check(int(group.chunks) == 2, "Natural source words still consist of complete two-chunk pairs")
		fragments += int(group.fragments)
	check(fragments == 30, "The budget uses actual natural supply: thirty fragments per sixty source words")
	check(Report.chest_payout(3) == 0 and Report.chest_payout(4) == 50
		and Report.chest_payout(8) == 50 and Report.chest_payout(9) == 100,
		"Budget calculations observe real chest unlock and upgrade thresholds")
	check(is_equal_approx(Report.expected_chest(10, 0.6), 49.579776),
		"Partial success uses the exact threshold distribution instead of rounding mean fragments")
	var report: Dictionary = Report.build_report()
	check(report == Report.build_report(), "Economy reports reproduce exactly from the fixed supply seed")
	for row: Dictionary in report.scenarios:
		check(float(row.free_play_total) > 0.0, "Playing without paid help always builds savings in the modeled workloads")
		check(float(row.free_play_bonus) == 0.0 and float(row.free_play_chest) == float(row.free_play_total),
			"Collecting ordinary Lv1 words earns only the unchanged chest income")
		if int(row.supplied_words) >= 40:
			check(float(row.one_treasure_every_three_sessions_net_average) > 0.0,
				"Larger ordinary workloads can save while buying a first-price Treasure every three rounds")
		check(float(row.one_auto_merge_net) < 0.0 and float(row.three_auto_merge_net) < float(row.one_auto_merge_net),
			"A premium purchase every modeled round drains savings; repeated use drains faster")
		check(float(row.three_treasure_net) < 0.0,
			"Three Treasure purchases cannot sustain themselves even when every paid fragment is retained")
		if is_equal_approx(float(row.success_probability), 1.0):
			check(is_equal_approx(float(row.free_play_total), int(row.supplied_words) * 5.0),
				"Perfect Lv1 completion earns five chest coins per source word in full ten-word blocks")
	check(report.upgraded_collections.size() == 6, "The report includes only the six playable merge levels")
	var expected_per_source: Array[float] = [0.0, 0.5, 4.0 / 3.0, 18.0 / 4.0, 40.0 / 5.0, 75.0 / 6.0]
	var source_counts: Array[int] = []
	for row: Dictionary in report.upgraded_collections:
		check(is_equal_approx(float(row.expected_bonus), Economy.jelly_bonus_chance(int(row.merge_level)) * Economy.jelly_bonus(int(row.merge_level))),
			"Every upgrade scenario uses the exact level-dependent expectation")
		source_counts.append(int(row.source_words))
		check(is_equal_approx(float(row.expected_bonus_per_source_word), expected_per_source[int(row.merge_level) - 1]),
			"The source-word budget accounts for additive merges instead of same-level doubling")
	check(source_counts == [1, 2, 3, 4, 5, 6], "Each playable collection level retains its completed source-word count")
	check(Report.purchase_total("auto_merge", 3) == 2700 and Report.purchase_total("fragments", 3) == 900,
		"Constant-use scenarios include escalating prices rather than repeating the opening discount")


func _test_treasure_cannot_self_fund() -> void:
	var largest_return: int = 0
	for existing in range(101):
		for added in range(Economy.TREASURE_FRAGMENT_MIN, Economy.TREASURE_FRAGMENT_MAX + 1):
			var extra: int = Report.chest_payout(existing + added) - Report.chest_payout(existing)
			largest_return = maxi(largest_return, extra)
			check(extra <= 100 and extra < Economy.powerup_price("fragments", 0),
				"Every fragment threshold and two-to-eight outcome is strictly cheaper to earn than to buy")
	check(largest_return == 100, "The exhaustive Treasure ceiling is two chest levels or one hundred coins")
	var average_over_offsets: float = 0.0
	for existing in range(5, 10):
		for added in range(2, 9):
			average_over_offsets += (Report.chest_payout(existing + added) - Report.chest_payout(existing)) / 35.0
	check(is_equal_approx(average_over_offsets, 50.0), "Across all five upgrade offsets, average Treasure return is fifty coins")
	check(Economy.powerup_price("fragments", 0) - largest_return >= 100,
		"Even perfect Treasure luck consumes at least one hundred previously earned coins")


func _test_paid_model_and_wallet() -> void:
	var storage := Storage.new()
	var wallet := Wallet.new("user://unused-economy-wallet.cfg", storage)
	check(wallet.load_state() and wallet.balance == 0, "Fresh players keep free play and receive no invented starter currency")
	var game := Jelly.new()
	check(game.configure(Report.fixture_words(), 3, 19), "The purchase fixture uses a real stable opening board")
	var charges: Array[int] = []
	game.purchase_powerup = func(id: String, _kind: String, price: int) -> Dictionary:
		charges.append(price)
		return wallet.spend(id, price)
	var before: Array[Dictionary] = game.cells.duplicate(true)
	check(not game.activate_powerup("fragments") and game.cells == before and game.powerup_price("fragments") == 200,
		"An unaffordable first purchase cannot grant fragments or increase its next price")
	check(wallet.credit("earned:old-chest", 20).ok and wallet.balance == 1000, "Existing chest values fund a saved-wallet purchase")
	storage.fail_write = true
	check(not game.activate_powerup("fragments") and wallet.balance == 1000 and game.powerup_price("fragments") == 200,
		"Failed persistence leaves both balance and successful-use price untouched")
	storage.fail_write = false
	var awarded: int = 0
	for expected_price: int in [200, 300, 400]:
		var previous_balance: int = wallet.balance
		check(game.activate_powerup("fragments"), "A paid Treasure purchase starts after a durable debit")
		var current: Dictionary = game.powerup_snapshot()
		awarded += int(current.total)
		check(wallet.balance == previous_balance - expected_price and int(charges.back()) == expected_price,
			"The real model charges the current escalating price through CoinWallet")
		check(int(current.total) >= 2 and int(current.total) <= 8,
			"The paid model reserves the policy's fragment range")
		game.finish_powerup(true)
	check(wallet.balance == 100 and awarded >= 6 and awarded <= 24,
		"Three successful purchases spend nine hundred coins and only supply collectible fragments")
	check(game.fragment_count == 0 and game.collected_coins == 0,
		"Treasure delivery alone cannot grant chest progress or refund coins before word collection")
	check(game.powerup_price("fragments") == 400 and game.powerup_price("auto_merge") == 600,
		"Repeat prices cap and independent item kinds do not inflate one another")
	game.configure(Report.fixture_words(), 3, 20)
	check(game.powerup_price("fragments") == 200 and game.powerup_price("auto_merge") == 600,
		"Starting a genuinely new round resets both item ladders")
	var reloaded := Wallet.new("user://unused-economy-wallet.cfg", storage)
	check(reloaded.load_state() and reloaded.balance == 100 and reloaded.credit("earned:old-chest", 20).duplicate,
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
