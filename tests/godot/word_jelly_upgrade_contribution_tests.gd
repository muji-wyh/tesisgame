extends SceneTree

const Store = preload("res://scripts/word_jelly_campaign_store.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Economy = preload("res://scripts/coin_economy.gd")
var checks := 0
var failures := 0


class Host extends RefCounted:
	var campaign: Variant = null
	var coins: Variant = null
	var campaign_writable := true
	var coins_writable := true
	var campaign_writes := 0

	func jellyCampaignState() -> Variant:
		return campaign

	func saveJellyCampaignState(next: String, expected: Variant) -> bool:
		if not campaign_writable or campaign != expected:
			return false
		campaign = next
		campaign_writes += 1
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


func _pulse(store, wallet, kind: String, amount: int = 25) -> bool:
	if not store.begin_upgrade_contribution(kind, amount):
		return false
	var pending: Dictionary = store.upgrade_state().pending
	return wallet.spend(pending.id, pending.amount).ok and store.complete_upgrade_contribution(wallet)


func _encode(upgrades: Dictionary, version: int = Store.VERSION) -> String:
	var config := ConfigFile.new()
	config.set_value("campaign", "version", version)
	config.set_value("campaign", "contexts", {})
	config.set_value("campaign", "upgrades", upgrades)
	return config.encode_to_text()


func _empty_upgrades() -> Dictionary:
	return {"level": 1, "auto_merge_level": 1, "pending": {}, "intro": "unseen",
		"funded": {"jelly": 0, "auto_merge": 0}}


func _test_progress_and_milestones() -> void:
	var host := Host.new()
	var store := Store.new("user://contribution-progress.cfg", host)
	var wallet := Wallet.new("user://contribution-progress-coins.cfg", host)
	check(store.load_state() and wallet.load_state() and wallet.credit_amount("fixture:charge", 5000).ok,
		"Load an isolated real-wallet contribution fixture")
	check(store.upgrade_state().funded == {"jelly": 0, "auto_merge": 0},
		"Both upgrade tracks begin with zero saved funding")
	check(_pulse(store, wallet, "jelly") and store.merged_level() == 1
		and store.upgrade_state().funded.jelly == 25 and wallet.balance == 4975,
		"A paid twenty-five-coin pulse persists halfway to Lv2 without unlocking early")
	check(not store.begin_upgrade(2), "A whole-price purchase cannot charge again over partial funding")
	var restored := Store.new("user://contribution-progress.cfg", host)
	check(restored.load_state() and restored.upgrade_state().funded.jelly == 25,
		"Partial upgrade funding survives reload")
	check(_pulse(restored, wallet, "auto_merge") and restored.auto_merge_level() == 1
		and restored.upgrade_state().funded == {"jelly": 25, "auto_merge": 25},
		"Each upgrade track keeps its own partial contribution")
	check(_pulse(restored, wallet, "jelly") and restored.merged_level() == 2
		and restored.auto_merge_level() == 1 and restored.upgrade_state().intro == "complete"
		and restored.upgrade_state().funded == {"jelly": 0, "auto_merge": 25},
		"Exactly reaching the milestone unlocks one level and resets only its own funding")
	check(_pulse(restored, wallet, "auto_merge") and restored.auto_merge_level() == 2
		and restored.merged_level() == 2 and wallet.balance == 4900,
		"Equal-price milestones require separate debits on both tracks")
	check(not restored.begin_upgrade_contribution("jelly", 125)
		and not restored.begin_upgrade_contribution("jelly", 1)
		and not restored.begin_upgrade_contribution("missing")
		and restored.upgrade_state().pending.is_empty(),
		"Invalid increments and overshooting cannot reserve or skip a level")
	for level in range(3, 10):
		check(_pulse(restored, wallet, "jelly", Economy.permanent_upgrade_price("jelly", level))
			and restored.merged_level() == level and restored.upgrade_state().funded.jelly == 0,
			"Every later contribution milestone unlocks only the next sequential level")
	check(not restored.begin_upgrade_contribution("jelly") and restored.merged_level() == 9,
		"A fully upgraded track cannot reserve or spend another coin")


func _test_journal_and_failure_recovery() -> void:
	var host := Host.new()
	var store := Store.new("user://contribution-recovery.cfg", host)
	var wallet := Wallet.new("user://contribution-recovery-coins.cfg", host)
	check(store.load_state() and wallet.load_state() and wallet.credit_amount("fixture:recovery", 500).ok,
		"Load the isolated failed-write fixture")
	host.campaign_writable = false
	check(not store.begin_upgrade_contribution("jelly") and wallet.balance == 500
		and store.upgrade_state().pending.is_empty(),
		"A failed reservation cannot change ownership, funding or wallet balance")
	host.campaign_writable = true
	check(store.begin_upgrade_contribution("jelly"), "Reserve a contribution before its wallet debit")
	var pending: Dictionary = store.upgrade_state().pending
	var writes: int = host.campaign_writes
	check(store.begin_upgrade_contribution("jelly") and host.campaign_writes == writes
		and store.upgrade_state().pending == pending and not store.begin_upgrade(2)
		and not store.begin_upgrade_contribution("auto_merge")
		and not store.complete_upgrade(2, wallet),
		"A duplicate begin reuses one intent and legacy or other-track calls cannot consume it")
	host.coins_writable = false
	check(not wallet.spend(pending.id, pending.amount).ok
		and not store.complete_upgrade_contribution(wallet) and wallet.balance == 500
		and store.upgrade_state().funded.jelly == 0,
		"A failed wallet write cannot fill the progress bar")
	host.coins_writable = true
	check(wallet.spend(pending.id, pending.amount).ok and wallet.balance == 475,
		"The exact reserved receipt debits one pulse")
	host.campaign_writable = false
	check(not store.complete_upgrade_contribution(wallet) and store.upgrade_state().funded.jelly == 0
		and store.upgrade_state().pending == pending,
		"A failed progress commit keeps the paid receipt for recovery")
	host.campaign_writable = true
	var restored := Store.new("user://contribution-recovery.cfg", host)
	check(restored.load_state() and restored.complete_upgrade_contribution(wallet)
		and restored.upgrade_state().funded.jelly == 25 and wallet.balance == 475,
		"Reload applies the already-paid pulse without a second debit")
	check(wallet.spend(pending.id, pending.amount).ok and restored.complete_upgrade_contribution(wallet)
		and restored.upgrade_state().funded.jelly == 25 and wallet.balance == 475,
		"Duplicate debit and completion cannot repeat a contribution")
	check(restored.begin_upgrade_contribution("jelly")
		and restored.upgrade_state().pending.id != pending.id,
		"The next pulse has a distinct durable receipt based on its saved funding offset")
	var last: Dictionary = restored.upgrade_state().pending
	check(wallet.spend(last.id, last.amount).ok, "Pay the exact final pulse of the level")
	host.campaign_writable = false
	check(not restored.complete_upgrade_contribution(wallet) and restored.merged_level() == 1,
		"A failed milestone commit never announces an unsaved unlock")
	host.campaign_writable = true
	var milestone := Store.new("user://contribution-recovery.cfg", host)
	check(milestone.load_state() and milestone.complete_upgrade_contribution(wallet)
		and milestone.merged_level() == 2 and milestone.upgrade_state().funded.jelly == 0
		and wallet.balance == 450,
		"A paid milestone recovers exactly once after reload")


func _test_stale_tabs() -> void:
	var host := Host.new()
	var first := Store.new("user://contribution-stale.cfg", host)
	var stale := Store.new("user://contribution-stale.cfg", host)
	var wallet := Wallet.new("user://contribution-stale-coins.cfg", host)
	check(first.load_state() and stale.load_state() and wallet.load_state()
		and wallet.credit_amount("fixture:stale", 100).ok,
		"Both tabs load the same initial contribution snapshot")
	check(first.begin_upgrade_contribution("jelly") and not stale.begin_upgrade_contribution("jelly")
		and not stale.complete_upgrade_contribution(wallet),
		"A stale tab cannot replace an intent or complete against an old campaign snapshot")
	var pending: Dictionary = first.upgrade_state().pending
	check(wallet.spend(pending.id, pending.amount).ok and first.complete_upgrade_contribution(wallet),
		"The current tab commits its exact paid pulse")
	check(not stale.begin_upgrade_contribution("auto_merge") and wallet.balance == 75,
		"A stale tab cannot erase funded progress through another upgrade track")


func _test_version_five_and_legacy_purchase() -> void:
	var host := Host.new()
	var old: Dictionary = {"level": 2, "auto_merge_level": 3, "intro": "complete",
		"pending": {"kind": "jelly", "level": 3, "price": 125, "id": "jelly-level-v1:3"}}
	host.campaign = _encode(old, 5)
	var original: String = host.campaign
	var store := Store.new("user://contribution-v5.cfg", host)
	var wallet := Wallet.new("user://contribution-v5-coins.cfg", host)
	check(store.load_state() and store.upgrade_state().funded == {"jelly": 0, "auto_merge": 0}
		and store.merged_level() == 2 and store.auto_merge_level() == 3 and host.campaign == original,
		"Version five gains zero funding in memory without rewriting or changing ownership")
	check(not store.begin_upgrade_contribution("jelly") and not store.complete_upgrade_contribution(wallet),
		"A historical whole-price intent remains separate from the new contribution journal")
	check(wallet.load_state() and wallet.credit_amount("fixture:v5", 500).ok
		and wallet.spend("jelly-level-v1:3", 125).ok and store.complete_upgrade(3, wallet)
		and store.merged_level() == 3 and wallet.balance == 375,
		"The historical exact whole-price receipt still recovers without repricing")
	var saved := ConfigFile.new()
	check(saved.parse(host.campaign) == OK and saved.get_value("campaign", "version") == Store.VERSION
		and _pulse(store, wallet, "jelly") and store.upgrade_state().funded.jelly == 25,
		"A recovered legacy purchase can immediately use saved contribution progress on its next level")


func _test_invalid_funding_and_pending() -> void:
	var invalids: Array[Dictionary] = []
	for funding: Variant in [{}, {"jelly": -25, "auto_merge": 0}, {"jelly": 1, "auto_merge": 0},
			{"jelly": 50, "auto_merge": 0}, {"jelly": 0, "auto_merge": 25.0},
			{"jelly": 0, "auto_merge": 0, "extra": 0}]:
		var invalid: Dictionary = _empty_upgrades()
		invalid.funded = funding
		invalids.append(invalid)
	var capped: Dictionary = _empty_upgrades()
	capped.level = 9
	capped.intro = "complete"
	capped.funded.jelly = 25
	invalids.append(capped)
	var host := Host.new()
	var valid := Store.new("user://contribution-valid.cfg", host)
	check(valid.load_state() and valid.begin_upgrade_contribution("jelly"),
		"Build a real valid contribution intent before corrupting individual fields")
	var journal: Dictionary = valid.upgrade_state()
	for field: String in ["amount", "price", "id", "mode", "level", "kind"]:
		var malformed: Dictionary = journal.duplicate(true)
		match field:
			"amount": malformed.pending.amount = 50
			"price": malformed.pending.price = 75
			"id": malformed.pending.id = "another-receipt"
			"mode": malformed.pending.mode = "unknown"
			"level": malformed.pending.level = 3
			"kind": malformed.pending.kind = "auto_merge"
		invalids.append(malformed)
	var extra: Dictionary = journal.duplicate(true)
	extra.pending.extra = true
	invalids.append(extra)
	var legacy_over_funding: Dictionary = _empty_upgrades()
	legacy_over_funding.funded.jelly = 25
	legacy_over_funding.pending = {"kind": "jelly", "level": 2, "price": 50, "id": "jelly-level-v1:2"}
	invalids.append(legacy_over_funding)
	for invalid: Dictionary in invalids:
		var rejected_host := Host.new()
		rejected_host.campaign = _encode(invalid)
		var original: String = rejected_host.campaign
		var rejected := Store.new("user://contribution-invalid.cfg", rejected_host)
		check(not rejected.load_state() and not rejected.error.is_empty() and rejected_host.campaign == original,
			"Malformed funding or mismatched contribution receipt fails without rewriting the saved data")


func _run() -> void:
	_test_progress_and_milestones()
	_test_journal_and_failure_recovery()
	_test_stale_tabs()
	_test_version_five_and_legacy_purchase()
	_test_invalid_funding_and_pending()
	print("Saved upgrade contributions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
