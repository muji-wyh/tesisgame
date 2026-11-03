extends SceneTree

const Campaign = preload("res://scripts/word_jelly_campaign.gd")
const Store = preload("res://scripts/word_jelly_campaign_store.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
var checks := 0
var failures := 0


class Host extends RefCounted:
	var campaign: Variant = null
	var coins: Variant = null
	var campaign_writable := true
	var coins_writable := true
	var fail_after_spend := false
	var events: Array[String] = []

	func jellyCampaignState() -> Variant:
		return campaign

	func saveJellyCampaignState(next: String, expected: Variant) -> bool:
		if not campaign_writable or campaign != expected:
			return false
		campaign = next
		events.append("campaign")
		return true

	func coinWalletState() -> Variant:
		return coins

	func saveCoinWalletState(next: String, expected: Variant) -> bool:
		if not coins_writable or coins != expected:
			return false
		coins = next
		events.append("coins")
		if fail_after_spend:
			fail_after_spend = false
			campaign_writable = false
		return true


class Sound extends RefCounted:
	var cues: Array[String] = []

	func play_coin_spend() -> void:
		cues.append("upgrade_coin")

	func play_jelly_cue(cue: String) -> void:
		cues.append(cue)

	func play_upgrade_milestone() -> void:
		cues.append("goal_complete")


class CoinFlight extends RefCounted:
	var balance := 0

	func sync(value: int) -> void:
		balance = value


class Harness extends Node:
	var coin_wallet
	var audio := Sound.new()
	var _coin_flight := CoinFlight.new()
	var _page_hidden := false
	var _host: Object = null
	var _releasing_professional_views := false
	var announcements: Array[String] = []
	var refreshes := 0
	var syncs := 0

	func _announce_status(message: String) -> void:
		announcements.append(message)

	func _refresh() -> void:
		refreshes += 1

	func _sync_jelly() -> void:
		syncs += 1


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func setup(host: Host) -> Dictionary:
	var app := Harness.new()
	app.coin_wallet = Wallet.new("user://contribution-flow-coins.cfg", host)
	check(app.coin_wallet.load_state(), "Load the isolated receipt-backed wallet")
	root.add_child(app)
	var campaign := Campaign.new()
	campaign.configure(app, "user://contribution-flow-campaign.cfg", host)
	check(campaign.store.ready, "Load the isolated campaign")
	check(campaign.upgrades.present(campaign._upgrade_state(),
		{"id": "cat", "text": "cat", "image": "res://assets/images/ui/modes/cat.webp"}, false),
		"Present the production upgrade view with its real artwork")
	campaign.upgrades.set_active(true)
	return {"app": app, "campaign": campaign}


func _run() -> void:
	var host := Host.new()
	var flow := setup(host)
	var app = flow.app
	var campaign = flow.campaign
	var page = campaign.upgrades
	check(app.coin_wallet.credit_amount("fixture:charge-flow", 500).ok, "Fund the isolated flow through a durable receipt")
	page.configure(campaign._upgrade_state())
	host.events.clear()
	page.contribution_requested.emit("jelly", 25)
	check(app.coin_wallet.balance == 475 and campaign.store.merged_level() == 1
		and campaign.store.upgrade_state().funded.jelly == 25,
		"One held pulse invests exactly twenty-five coins without granting the level early")
	check(host.events == ["campaign", "coins", "campaign"],
		"Each pulse reserves its journal before debit and commits funding after the receipt")
	check(page._state.funded.jelly == 25 and not page._state.busy and not campaign._buying_upgrade,
		"Only committed funding reaches the view without disabling the held control")
	check(campaign._upgrade_state().pending.is_empty() and not campaign._upgrade_state().paid,
		"A completed contribution clears its temporary paid journal")
	var saved := Store.new("user://contribution-flow-campaign.cfg", host)
	check(saved.load_state() and saved.upgrade_state().funded.jelly == 25,
		"Partial funding survives a fresh store reload")

	page._state.funded.jelly = 0
	campaign.contribute_upgrade("jelly", 25)
	check(app.coin_wallet.balance == 475 and campaign.store.upgrade_state().funded.jelly == 25,
		"A pulse from stale displayed funding cannot spend another coin")
	page.configure(campaign._upgrade_state())
	campaign.contribute_upgrade("jelly", 50)
	campaign.contribute_upgrade("unknown", 25)
	campaign.contribute_upgrade("auto_merge", 25)
	check(app.coin_wallet.balance == 475, "Invalid amounts and unselected tracks cannot debit the wallet")
	page.hide()
	campaign.contribute_upgrade("jelly", 25)
	page.show()
	page.set_active(false)
	campaign.contribute_upgrade("jelly", 25)
	page.set_active(true)
	app._page_hidden = true
	campaign.contribute_upgrade("jelly", 25)
	app._page_hidden = false
	campaign.starting = true
	campaign.contribute_upgrade("jelly", 25)
	campaign.starting = false
	campaign.settling = true
	campaign.contribute_upgrade("jelly", 25)
	campaign.settling = false
	check(app.coin_wallet.balance == 475, "Hidden, inactive, background, starting and settling pages reject pulses")
	page.contribution_requested.emit("jelly", 25)
	check(app.coin_wallet.balance == 450 and campaign.store.merged_level() == 2
		and campaign.store.upgrade_state().funded.jelly == 0 and campaign._last_unlocked == 2,
		"The exact fifty-coin milestone unlocks Lv2 and resets its next-level funding")
	for frame in range(6):
		page.advance(0.05)
	check(app.announcements.is_empty(), "Successful contributions and milestones add no status prose")
	check(app.audio.cues.has("upgrade_coin") and app.audio.cues.has("goal_complete"),
		"Committed funding and level milestones route their distinct production sound cues")

	host.campaign_writable = false
	campaign.contribute_upgrade("jelly", 25)
	check(app.coin_wallet.balance == 450 and campaign.store.upgrade_state().funded.jelly == 0
		and not campaign.error.is_empty(), "A failed reservation cannot debit or show invented funding")
	host.campaign_writable = true
	campaign.retry()
	check(campaign.error.is_empty() and campaign.store.ready and app.coin_wallet.balance == 450,
		"Retry after a reservation failure reloads without purchasing another pulse")
	host.coins_writable = false
	campaign.contribute_upgrade("jelly", 25)
	check(app.coin_wallet.balance == 450 and campaign.store.upgrade_state().funded.jelly == 0
		and campaign.store.upgrade_state().pending.mode == "contribution",
		"A failed debit retains only its unpaid contribution intent")
	host.coins_writable = true
	campaign.retry()
	check(app.coin_wallet.balance == 425 and campaign.store.upgrade_state().funded.jelly == 25
		and campaign.store.upgrade_state().pending.is_empty(),
		"Retry of the unpaid contribution debits and commits exactly one original pulse")

	host.fail_after_spend = true
	campaign.contribute_upgrade("jelly", 25)
	check(app.coin_wallet.balance == 400 and campaign.store.upgrade_state().funded.jelly == 25
		and campaign._upgrade_state().paid and not campaign.error.is_empty(),
		"A failed funding write shows the saved paid receipt without advancing progress")
	var paid_id: String = campaign.store.upgrade_state().pending.id
	campaign.purchase_upgrade(3)
	check(app.coin_wallet.balance == 400 and app.coin_wallet.has_purchase(paid_id, 25),
		"The legacy full-purchase route cannot reinterpret a paid contribution as a full price")
	page.select_upgrade("auto_merge")
	host.campaign_writable = true
	campaign.retry()
	check(app.coin_wallet.balance == 400 and campaign.store.upgrade_state().funded.jelly == 50
		and campaign.store.upgrade_state().funded.auto_merge == 0
		and campaign.store.upgrade_state().pending.is_empty(),
		"Retry follows the saved track while another category is selected without a second debit")

	page.select_upgrade("jelly")
	host.fail_after_spend = true
	campaign.contribute_upgrade("jelly", 25)
	check(app.coin_wallet.balance == 375 and campaign.store.upgrade_state().funded.jelly == 50,
		"Prepare an interrupted paid contribution before reloading the coordinator")
	host.campaign_writable = true
	var resumed := setup(host)
	check(resumed.campaign._recover_upgrade() and resumed.app.coin_wallet.balance == 375
		and resumed.campaign.store.upgrade_state().funded.jelly == 75,
		"Fresh coordinator recovery commits the paid pulse without charging it again")
	check(resumed.campaign._recover_upgrade() and resumed.app.coin_wallet.balance == 375,
		"Repeating recovery after completion is harmless")
	resumed.campaign.upgrades.configure(resumed.campaign._upgrade_state())
	resumed.campaign.contribute_upgrade("jelly", 25)
	check(resumed.app.coin_wallet.balance == 350 and resumed.campaign.store.merged_level() == 3
		and resumed.campaign.store.upgrade_state().funded.jelly == 0,
		"Funding continues after recovery and crosses the next exact milestone")
	check(resumed.campaign.store.begin_upgrade(2, "auto_merge"), "Reserve a compatible legacy full purchase")
	var legacy: Dictionary = resumed.campaign.store.upgrade_state().pending
	check(resumed.app.coin_wallet.spend(legacy.id, legacy.price).ok,
		"Persist the original full-price wallet receipt")
	check(resumed.campaign._recover_upgrade() and resumed.campaign.store.auto_merge_level() == 2
		and resumed.app.coin_wallet.balance == 300, "Legacy paid journals still recover at their full price")

	var poor := setup(Host.new())
	check(poor.app.coin_wallet.credit_amount("fixture:small-balance", 10).ok, "Fund a balance below one pulse")
	poor.campaign.upgrades.configure(poor.campaign._upgrade_state())
	poor.campaign.contribute_upgrade("jelly", 25)
	check(poor.app.coin_wallet.balance == 10 and poor.campaign.store.upgrade_state().pending.is_empty()
		and poor.campaign.store.upgrade_state().funded.jelly == 0 and poor.app.announcements.is_empty(),
		"Insufficient coins stop quietly before reserving or debiting a pulse")
	var unpaid_host := Host.new()
	var reserved := Store.new("user://contribution-flow-campaign.cfg", unpaid_host)
	var reserved_wallet := Wallet.new("user://contribution-flow-coins.cfg", unpaid_host)
	check(reserved.load_state() and reserved_wallet.load_state()
		and reserved_wallet.credit_amount("fixture:unpaid-reload", 50).ok
		and reserved.begin_upgrade_contribution("auto_merge", 25),
		"Persist an interrupted reservation before its wallet debit")
	var unpaid := setup(unpaid_host)
	check(unpaid.campaign._recover_upgrade() and unpaid.app.coin_wallet.balance == 50
		and unpaid.campaign.store.upgrade_state().funded.auto_merge == 0,
		"Loading and recovery never spend an unpaid saved contribution automatically")
	check(unpaid.campaign._upgrade_state().retry and unpaid.campaign.upgrades.snapshot().buy.enabled
		and not unpaid.campaign.upgrades.snapshot().pending.is_empty(),
		"A reloaded unpaid reservation exposes a usable resume action")
	unpaid.campaign.upgrades._buy.pressed.emit()
	check(unpaid.app.coin_wallet.balance == 25 and unpaid.campaign.store.upgrade_state().funded.auto_merge == 25
		and unpaid.campaign.store.upgrade_state().funded.jelly == 0
		and unpaid.campaign.store.upgrade_state().pending.is_empty(),
		"Only the fresh resume gesture debits and commits the exact saved track and amount")
	for fixture: Dictionary in [flow, resumed, poor, unpaid]:
		fixture.app.queue_free()
	await process_frame
	print("Jelly contribution coordinator: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
