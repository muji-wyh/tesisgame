extends SceneTree

const Store = preload("res://scripts/word_jelly_campaign_store.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Economy = preload("res://scripts/coin_economy.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
var checks := 0
var failures := 0
var words: Array = []


class Host extends RefCounted:
	var campaign: Variant = null
	var coins: Variant = null
	var campaign_writable := true
	var coins_writable := true

	func jellyCampaignState() -> Variant:
		return campaign

	func saveJellyCampaignState(next: String, expected: Variant) -> bool:
		if not campaign_writable or campaign != expected:
			return false
		campaign = next
		return true

	func coinWalletState() -> Variant:
		return coins

	func saveCoinWalletState(next: String, expected: Variant) -> bool:
		if not coins_writable or coins != expected:
			return false
		coins = next
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _clear(store, number: int, boss_id: int = 0) -> void:
	var plan: Dictionary = Catalog.make_plan(number, words, 3, 71)
	check(store.reserve_plan("growth", plan), "Reserve an actual immutable stage recipe")
	var result: Dictionary = {"kind": "main", "number": number, "outcome": "cleared", "stars": 1}
	if boss_id > 0:
		result.merge({"boss_id": boss_id, "boss_victory": true, "boss_roster_version": 2})
	var id := "upgrade-test:clear:%d" % number
	check(store.queue_result("growth", id, result) and store.complete_result("growth", id),
		"Commit the ordinary stage journal and rewards frontier")


func _test_purchase_and_recovery() -> void:
	var host := Host.new()
	var store := Store.new("user://jelly-upgrade-tests.cfg", host)
	var wallet := Wallet.new("user://jelly-upgrade-coins.cfg", host)
	check(store.load_state() and wallet.load_state() and store.merged_level() == 1,
		"A new journey owns Lv1 without a purchase or Boss victory")
	check(Economy.JELLY_UPGRADE_PRICES == [50, 100, 200, 350, 550, 800, 1100, 1500],
		"Lv2 costs exactly fifty coins and every later price increases")
	check(wallet.credit_amount("fixture:upgrades", 5000).ok, "Only isolated fixture coins fund purchases")
	check(not store.begin_upgrade(3) and store.merged_level() == 1,
		"A purchase cannot skip the next permanent level")
	check(store.begin_upgrade(2), "Persist the original fifty-coin quote before debiting coins")
	var quote: Dictionary = store.upgrade_state().pending
	check(quote.level == 2 and quote.price == 50 and not quote.id.is_empty()
		and store.merged_level() == 1 and wallet.balance == 5000,
		"Reserving an upgrade neither spends nor announces an unsaved unlock")
	check(not store.complete_upgrade(2, wallet) and store.merged_level() == 1,
		"A saved exact debit is mandatory before the level can increase")
	host.coins_writable = false
	check(not wallet.spend(quote.id, quote.price).ok and wallet.balance == 5000,
		"A failed wallet write never charges the upgrade")
	host.coins_writable = true
	check(wallet.spend(quote.id, quote.price).ok and wallet.balance == 4950,
		"The real wallet records the exact Lv2 purchase once")
	host.campaign_writable = false
	check(not store.complete_upgrade(2, wallet) and store.merged_level() == 1
		and not store.upgrade_state().pending.is_empty(),
		"A failed unlock commit retains its paid journal instead of losing fifty coins")
	host.campaign_writable = true
	var restored := Store.new("user://jelly-upgrade-tests.cfg", host)
	check(restored.load_state() and restored.complete_upgrade(2, wallet) and restored.merged_level() == 2,
		"Reload recovers the already-paid level without another debit")
	check(restored.complete_upgrade(2, wallet) and wallet.balance == 4950
		and restored.upgrade_state().pending.is_empty() and restored.upgrade_state().intro == "complete",
		"Duplicate completion cannot charge, advance or repeat the introduction")
	var total := 50
	for level in range(3, 10):
		check(restored.begin_upgrade(level), "Each next level reserves its own durable quote")
		quote = restored.upgrade_state().pending
		total += int(quote.price)
		check(wallet.spend(quote.id, quote.price).ok and restored.complete_upgrade(level, wallet)
			and restored.merged_level() == level, "The paid sequential level is permanently owned")
		check(wallet.balance == 5000 - total, "The wallet preserves every exact increasing debit")
	check(not restored.begin_upgrade(10) and restored.merged_level() == 9,
		"Lv9 is the maximum and cannot create an invalid purchase")
	var reload := Store.new("user://jelly-upgrade-tests.cfg", host)
	check(reload.load_state() and reload.merged_level() == 9,
		"All bought levels survive reload independently of learning-route context")


func _test_first_clear_and_boss_independence() -> void:
	var host := Host.new()
	var store := Store.new("user://jelly-upgrade-first.cfg", host)
	check(store.load_state(), "Load isolated first-clear progression")
	for stars in [1, 2, 3]:
		var reward: Dictionary = Catalog.clear_reward(1, stars, 0)
		check(reward.ok and reward.total >= 50 and reward.bonus >= Economy.jelly_upgrade_price(2),
			"Even a one-star first clear with no chest guarantees enough saved coins for Lv2")
	_clear(store, 1)
	check(store.upgrade_state().intro == "offer" and store.merged_level() == 1,
		"The saved first clear offers special Jelly powers but never grants or charges Lv2")
	check(store.begin_upgrade_guide() and store.upgrade_state().intro == "guide",
		"The primary introduction action durably starts a purchase FRE")
	var restored := Store.new("user://jelly-upgrade-first.cfg", host)
	check(restored.load_state() and restored.upgrade_state().intro == "guide",
		"Reload preserves an unfinished FRE without charging automatically")
	_clear(restored, 2)
	_clear(restored, 3, 1)
	check(restored.merged_level() == 1 and restored.boss_victories("growth") == [1],
		"A newly defeated Boss keeps its story victory but cannot unlock a Jelly level")
	_clear(restored, 1)
	check(restored.upgrade_state().intro == "guide" and restored.merged_level() == 1,
		"Replaying stage one cannot re-offer or farm the first-use experience")


func _test_legacy_and_stale_tabs() -> void:
	var state: Dictionary = {"highest_cleared": 5, "recipes": {}, "ratings": {}, "pending": {},
		"completed": [], "boss_victories": [1, 2], "challenge_best_stage": 0}
	for number in range(1, 6):
		state.recipes[str(number)] = Catalog.to_recipe(Catalog.make_plan(number, words, 3, 71))
		state.ratings[str(number)] = 3
	var config := ConfigFile.new()
	config.set_value("campaign", "version", 3)
	config.set_value("campaign", "contexts", {"growth": state})
	var host := Host.new()
	host.campaign = config.encode_to_text()
	var original: String = host.campaign
	var store := Store.new("user://jelly-upgrade-legacy.cfg", host)
	check(store.load_state() and store.merged_level() == 3 and host.campaign == original,
		"Migration retains legitimately earned old levels without rewriting or charging the save")
	check(store.highest_cleared("growth") == 5 and store.best_stars("growth", 5) == 3
		and store.upgrade_state().intro == "complete", "Old stars, stages and ownership remain intact")
	var stale := Store.new("user://jelly-upgrade-legacy.cfg", host)
	check(stale.load_state() and store.begin_upgrade(4), "The current tab can reserve the next global upgrade")
	check(not stale.begin_upgrade(4) and not stale.error.is_empty(),
		"A stale tab cannot overwrite another tab's upgrade intent")
	var reloaded := Store.new("user://jelly-upgrade-legacy.cfg", host)
	check(reloaded.load_state() and reloaded.upgrade_state().pending.price == 200
		and reloaded.merged_level() == 3, "The version-four journal retains its exact quote on reload")
	var professional: Dictionary = state.duplicate(true)
	professional.highest_cleared = 7
	professional.boss_victories = [1, 2, 3]
	for number in [6, 7]:
		professional.recipes[str(number)] = Catalog.to_recipe(Catalog.make_plan(number, words, 3, 71))
		professional.ratings[str(number)] = 3
	config.set_value("campaign", "contexts", {"growth": state, "professional:retail:module01": professional})
	var combined := Host.new()
	combined.campaign = config.encode_to_text()
	var global := Store.new("user://jelly-upgrade-global.cfg", combined)
	check(global.load_state() and global.merged_level() == 4
		and global.boss_victories("growth") == [1, 2]
		and global.boss_victories("professional:retail:module01") == [1, 2, 3],
		"One-time migration keeps the highest legitimately earned cap without merging separate stage histories")


func _test_invalid_upgrade_saves() -> void:
	for invalid: Dictionary in [
			{"level": 10, "pending": {}, "intro": "complete"},
			{"level": 2, "pending": {}, "intro": "offer"},
			{"level": 1, "pending": {"level": 3, "price": 100, "id": "jelly-level-v1:3"}, "intro": "guide"},
			{"level": 1, "pending": {"level": 2, "price": 49, "id": "jelly-level-v1:2"}, "intro": "guide"},
			{"level": 1, "pending": {"level": 2, "price": 50, "id": "another-receipt"}, "intro": "guide"}]:
		var config := ConfigFile.new()
		config.set_value("campaign", "version", 4)
		config.set_value("campaign", "contexts", {})
		config.set_value("campaign", "upgrades", invalid)
		var host := Host.new()
		host.campaign = config.encode_to_text()
		var original: String = host.campaign
		var store := Store.new("user://jelly-upgrade-invalid.cfg", host)
		check(not store.load_state() and not store.error.is_empty() and host.campaign == original,
			"Malformed levels, quotes and introduction state fail explicitly without resetting or rewriting the save")


func _test_auto_merge_purchases() -> void:
	var host := Host.new()
	var store := Store.new("user://auto-merge-upgrades.cfg", host)
	var wallet := Wallet.new("user://auto-merge-upgrades-coins.cfg", host)
	check(store.load_state() and wallet.load_state() and store.auto_merge_level() == 1
		and store.merged_level() == 1, "Both permanent upgrades start independently at free Lv1")
	check(wallet.credit_amount("fixture:auto-merge-upgrades", 5000).ok, "Fund only isolated Auto merge upgrades")
	check(not store.begin_upgrade(3, "auto_merge") and store.auto_merge_level() == 1,
		"Auto merge cannot skip its next capacity level")
	var total := 0
	for level in range(2, 10):
		var before: int = wallet.balance
		check(store.begin_upgrade(level, "auto_merge"), "Reserve the next permanent Auto merge upgrade")
		var pending: Dictionary = store.upgrade_state().pending
		check(pending.kind == "auto_merge" and pending.id == "auto-merge-level-v1:%d" % level
			and pending.price == Economy.JELLY_UPGRADE_PRICES[level - 2],
			"Auto merge has an exact increasing quote and a separate immutable receipt identity")
		check(not store.begin_upgrade(2) and not store.complete_upgrade(2, wallet)
			and store.merged_level() == 1, "An Auto merge intent cannot buy or complete the Jelly upgrade instead")
		if level == 2:
			host.coins_writable = false
			check(not wallet.spend(pending.id, pending.price).ok and wallet.balance == before
				and store.auto_merge_level() == 1, "A failed Auto merge debit cannot grant capacity")
			host.coins_writable = true
		check(wallet.spend(pending.id, pending.price).ok, "Persist the exact Auto merge debit")
		if level == 2:
			host.campaign_writable = false
			check(not store.complete_upgrade(level, wallet, "auto_merge")
				and store.auto_merge_level() == 1 and not store.upgrade_state().pending.is_empty(),
				"A failed capacity commit keeps the paid intent for Retry")
			host.campaign_writable = true
			var reloaded := Store.new("user://auto-merge-upgrades.cfg", host)
			check(reloaded.load_state(), "Reload the paid Auto merge journal without rewriting it")
			store = reloaded
		check(store.complete_upgrade(level, wallet, "auto_merge") and store.auto_merge_level() == level,
			"Only the matching saved debit grants the next capacity level")
		total += int(pending.price)
		check(store.complete_upgrade(level, wallet, "auto_merge") and wallet.balance == 5000 - total
			and store.merged_level() == 1 and store.upgrade_state().intro == "unseen",
			"Duplicate completion never charges or advances Jelly ownership or its separate introduction")
	check(not store.begin_upgrade(10, "auto_merge") and store.auto_merge_level() == 9,
		"Auto merge stops at Lv9 with eleven participating Jellies")
	_clear(store, 1)
	check(store.upgrade_state().intro == "offer" and store.auto_merge_level() == 9,
		"Buying Auto merge cannot consume the first-clear Jelly introduction")
	check(store.begin_upgrade(2), "The separate fifty-coin Jelly purchase remains available")
	var pending: Dictionary = store.upgrade_state().pending
	check(not store.complete_upgrade(2, wallet) and store.merged_level() == 1,
		"The existing equal-priced Auto merge receipt is not proof of a Jelly purchase")
	check(wallet.spend(pending.id, pending.price).ok and store.complete_upgrade(2, wallet)
		and store.auto_merge_level() == 9 and store.merged_level() == 2,
		"Equal-priced Jelly and Auto merge levels need distinct saved debits")
	var restored := Store.new("user://auto-merge-upgrades.cfg", host)
	check(restored.load_state() and restored.auto_merge_level() == 9 and restored.merged_level() == 2,
		"Both permanent upgrade tracks survive reload without merging their ownership")


func _test_version_four_upgrade_migration() -> void:
	var host := Host.new()
	var wallet := Wallet.new("user://auto-merge-v4-wallet.cfg", host)
	check(wallet.load_state() and wallet.credit_amount("fixture:v4-upgrades", 500).ok,
		"Fund a legacy paid-intent fixture")
	check(wallet.spend("jelly-level-v1:3", 125).ok, "The old saved Jelly quote may differ from today's price")
	var config := ConfigFile.new()
	config.set_value("campaign", "version", 4)
	config.set_value("campaign", "contexts", {})
	config.set_value("campaign", "upgrades", {"level": 2, "intro": "complete",
		"pending": {"level": 3, "price": 125, "id": "jelly-level-v1:3"}})
	host.campaign = config.encode_to_text()
	var original: String = host.campaign
	var store := Store.new("user://auto-merge-v4.cfg", host)
	check(store.load_state() and store.merged_level() == 2 and store.auto_merge_level() == 1
		and host.campaign == original and store.upgrade_state().pending.kind == "jelly"
		and store.upgrade_state().pending.price == 125,
		"Reading v4 adds free Auto merge Lv1 in memory without changing its old paid Jelly quote or source save")
	check(store.complete_upgrade(3, wallet) and wallet.balance == 375 and store.merged_level() == 3,
		"The old exact receipt still completes after migration without a second debit")
	var migrated := ConfigFile.new()
	check(migrated.parse(host.campaign) == OK and migrated.get_value("campaign", "version") == Store.VERSION,
		"The next actual write persists both upgrade tracks and their contribution state")
	for invalid: Dictionary in [
			{"level": 1, "auto_merge_level": 0, "pending": {}, "intro": "unseen"},
			{"level": 1, "auto_merge_level": 10, "pending": {}, "intro": "unseen"},
			{"level": 1, "auto_merge_level": 1, "intro": "unseen",
				"pending": {"kind": "auto_merge", "level": 3, "price": 100, "id": "auto-merge-level-v1:3"}},
			{"level": 1, "auto_merge_level": 1, "intro": "unseen",
				"pending": {"kind": "auto_merge", "level": 2, "price": 50, "id": "jelly-level-v1:2"}},
			{"level": 1, "auto_merge_level": 1, "intro": "unseen",
				"pending": {"kind": "fragments", "level": 2, "price": 50, "id": "auto-merge-level-v1:2"}}]:
		invalid.funded = {"jelly": 0, "auto_merge": 0}
		migrated.set_value("campaign", "upgrades", invalid)
		host.campaign = migrated.encode_to_text()
		original = host.campaign
		var rejected := Store.new("user://auto-merge-invalid.cfg", host)
		check(not rejected.load_state() and not rejected.error.is_empty() and host.campaign == original,
			"Malformed Auto merge ownership, kind, next level and cross-track receipts fail without resetting data")


func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Upgrade tests use actual reviewed stage vocabulary")
	words = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3).map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	_test_purchase_and_recovery()
	_test_first_clear_and_boss_independence()
	_test_legacy_and_stale_tabs()
	_test_invalid_upgrade_saves()
	_test_auto_merge_purchases()
	_test_version_four_upgrade_migration()
	print("Coin-bought Jelly levels: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
