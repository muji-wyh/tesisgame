extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Store = preload("res://scripts/word_jelly_campaign_store.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
var checks := 0
var failures := 0


class Host extends RefCounted:
	var campaign: String
	var coins: String
	var campaign_writable := true
	var fail_after_spend := false

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
		if coins != expected:
			return false
		coins = next
		if fail_after_spend:
			fail_after_spend = false
			campaign_writable = false
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func advance(app, delta: float) -> void:
	app._word_jelly._process(delta)
	app._word_jelly.set_process(false)
	app._advance_ui(delta)
	if app._round_celebration_active():
		Fixture.finish_celebration(app)


func tap(view, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = at
		event.pressed = pressed
		root.push_input(event)
		view.set_process(false)
		await process_frame


func capture_ui(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	var directory := "res://build/qa/jelly-upgrades"
	DirAccess.make_dir_recursive_absolute(directory)
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory + "/" + name + ".png") == OK,
		"Capture the actual " + name)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var directory := "user://jelly-upgrade-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The complete upgrade journey owns isolated saves")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_process(false)
	app._show_mode_menu()
	app.choose_mode("word_jelly")
	await settle()
	check(app._campaign.map.visible and app.coin_wallet.balance == 0
		and app._campaign.store.merged_level() == 1, "A real new journey starts with no coins and only Lv1")
	app._campaign.request_stage(1)
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	for frame in range(100):
		if not view._stage_banner.ready_pending():
			break
		advance(app, 0.05)
	view.game.set_fill_mode(false)
	view.game._stage_spawn_interval = 10000.0
	view.game.spawn_interval = 10000.0
	var goals: Array = view.game.stage_run.words.duplicate(true)
	for word: Dictionary in goals:
		view.game.cells.clear()
		var tile: Dictionary = view.game._new_word_root(word, 0)
		view.game._set_merged_word(tile, word, 1, true)
		tile.merge({"column": 3, "row": 7, "age": 100.0, "settling": false,
			"arrival": false, "falling": false}, true)
		view.game.cells.append(tile)
		view._sync_tiles()
		view._layout()
		var before: int = view.game.cleared_pairs
		await tap(view, view._tiles[int(tile.id)].get_global_rect().get_center())
		for frame in range(14):
			advance(app, 0.05)
		check(view.game.cleared_pairs > before, "A genuine player tap collects the actual reviewed goal")
	for frame in range(900):
		advance(app, 0.05)
		if app._campaign.upgrades.visible:
			break
	var campaign = app._campaign
	var page = campaign.upgrades
	check(campaign.store.highest_cleared("growth") == 1 and page.visible and page.is_offer(),
		"Only saved stage-one completion opens the special-power introduction")
	check(app.coin_wallet.balance >= 50 and campaign.store.merged_level() == 1
		and campaign.store.upgrade_state().intro == "offer",
		"The chest-free first clear has already saved at least fifty coins without auto-unlocking Lv2")
	check(not app._jelly_interaction_allowed() and app._default_focus() == page._offer_accept
		and app._valid_focus(page._offer_accept) and not app._valid_focus(campaign.map._nodes[1].button),
		"The first-clear modal owns keyboard and pointer input instead of leaking into the map")
	var saved_offer := Store.new(directory + "/campaign.cfg")
	check(saved_offer.load_state() and saved_offer.upgrade_state().intro == "offer",
		"The offered introduction survives reload before its first button")
	await capture_ui("first-clear-powers")
	await tap(view, page._offer_accept.get_global_rect().get_center())
	await settle()
	check(page.visible and not page.is_offer() and not campaign.map.visible
		and page.snapshot().selected_level == 2 and page.snapshot().buy.guided
		and page.snapshot().buy.enabled and campaign.store.upgrade_state().intro == "guide",
		"The modal button opens the real upgrades page and highlights its affordable Lv2 purchase")
	await capture_ui("lv2-first-upgrade")
	var host := Host.new()
	host.campaign = FileAccess.get_file_as_string(campaign.store._path)
	host.coins = FileAccess.get_file_as_string(app.coin_wallet._path)
	campaign.store._host = host
	app.coin_wallet._host = host
	host.fail_after_spend = true
	var before_purchase: int = app.coin_wallet.balance
	await tap(view, page._buy.get_global_rect().get_center())
	check(app.coin_wallet.balance == before_purchase - 50 and campaign.store.merged_level() == 1
		and page.snapshot().pending.level == 2 and page.snapshot().buy.enabled
		and not page.snapshot().error.is_empty(),
		"A blocked final write retains a real paid receipt and offers Retry without faking an unlock")
	await capture_ui("paid-upgrade-retry")
	host.campaign_writable = true
	await tap(view, page._buy.get_global_rect().get_center())
	check(campaign.store.merged_level() == 2 and app.coin_wallet.balance == before_purchase - 50
		and campaign.store.upgrade_state().pending.is_empty()
		and campaign.store.upgrade_state().intro == "complete",
		"The actual Retry action finishes the already-paid Lv2 without charging a second fifty coins")
	check(page.snapshot().level == 2 and not page.snapshot().buy.enabled and not page.snapshot().buy.guided,
		"Only a saved unlock completes the FRE and marks Lv2 owned")
	await capture_ui("lv2-unlocked")
	page._buy.pressed.emit()
	campaign.purchase_upgrade(2)
	check(app.coin_wallet.balance == before_purchase - 50 and campaign.store.merged_level() == 2,
		"Repeated input cannot double-charge or buy a second level")
	var saved_upgrade := Store.new(directory + "/campaign.cfg", host)
	var saved_wallet := Wallet.new(directory + "/coins.cfg", host)
	check(saved_upgrade.load_state() and saved_wallet.load_state() and saved_upgrade.merged_level() == 2
		and saved_wallet.balance == before_purchase - 50,
		"A fresh store and wallet recover the exact committed global purchase")
	page.select_level(9)
	var valid_campaign: String = host.campaign
	host.campaign = "Expected unreadable campaign fixture"
	campaign.retry()
	check(not campaign.store.ready and page.snapshot().level == 2 and page.snapshot().buy.enabled
		and not page.snapshot().error.is_empty(),
		"A failed reload retains known ownership and exposes an actionable Retry even on a future-level preview")
	host.campaign = valid_campaign
	await tap(view, page._buy.get_global_rect().get_center())
	check(campaign.store.ready and page.snapshot().error.is_empty() and not page.snapshot().buy.enabled
		and campaign.store.merged_level() == 2 and app.coin_wallet.balance == before_purchase - 50,
		"Retrying an unreadable progress save restores ownership without buying the inspected future level")
	await tap(view, page._back.get_global_rect().get_center())
	check(campaign.map.visible and not page.visible and campaign.map.snapshot().merged_level == 2,
		"Back returns to the same map with its newly owned level")
	await capture_ui("map-upgrade-entry")
	check(app.coin_wallet.credit_amount("fixture:auto-merge-upgrade", 100).ok,
		"Fund the additional upgrade only through an isolated fixture receipt")
	app._coin_flight.sync(app.coin_wallet.balance)
	await tap(view, campaign.map._upgrades.get_global_rect().get_center())
	await settle()
	await tap(view, page._category_buttons.auto_merge.get_global_rect().get_center())
	check(page.snapshot().kind == "auto_merge" and page.snapshot().owned_level == 1
		and page.snapshot().preview.capacity == 4 and page.snapshot().buy.enabled
		and campaign.store.auto_merge_level() == 1,
		"The real category opens an inspectable four-Jelly Lv2 upgrade without granting it")
	await capture_ui("auto-merge-lv2-upgrade")
	var before_auto: int = app.coin_wallet.balance
	host.fail_after_spend = true
	await tap(view, page._buy.get_global_rect().get_center())
	check(app.coin_wallet.balance == before_auto - 50 and campaign.store.auto_merge_level() == 1
		and page.snapshot().pending.kind == "auto_merge" and page.snapshot().buy.enabled,
		"A blocked final Auto merge write retains its paid fifty-coin intent and original capacity")
	await capture_ui("auto-merge-paid-retry")
	page.select_upgrade("jelly")
	page.select_level(9)
	host.campaign_writable = true
	await tap(view, page._buy.get_global_rect().get_center())
	check(campaign.store.auto_merge_level() == 2 and campaign.store.merged_level() == 2
		and app.coin_wallet.balance == before_auto - 50 and campaign.store.upgrade_state().pending.is_empty(),
		"Retry follows the saved Auto merge kind even while a future Jelly power is inspected, without another debit")
	page.select_upgrade("auto_merge")
	page.select_level(2)
	check(page.snapshot().owned_level == 2 and not page.snapshot().buy.enabled
		and page.snapshot().preview.capacity == 4, "Only the committed Auto merge upgrade owns four output slots")
	await capture_ui("auto-merge-lv2-owned")
	var restored_auto := Store.new(directory + "/campaign.cfg", host)
	check(restored_auto.load_state() and restored_auto.auto_merge_level() == 2
		and restored_auto.merged_level() == 2, "Reload keeps the two independently purchased upgrades")
	await tap(view, page._back.get_global_rect().get_center())
	campaign.request_stage(2)
	await settle()
	view.set_process(false)
	view._process(0.0)
	check(view.game.merged_level_limit == 2 and view.game.auto_merge_level == 2
		and view.snapshot().powerup_buttons.auto_merge.capacity == 4
		and not view.game.boss.definition.has("unlock_level"),
		"The next genuine stage and live badge use the independently saved levels, not the last inspected preview")
	for frame in range(100):
		if not view._stage_banner.ready_pending():
			break
		advance(app, 0.05)
	view.game.set_fill_mode(false)
	view.game._stage_spawn_interval = 10000.0
	view.game.spawn_interval = 10000.0
	view.game.cells.clear()
	var auto_word: Dictionary = view.game.stage_run.words[0]
	for index in range(8):
		var tile: Dictionary = view.game._new_word_root(auto_word, 1) if index % 2 == 0 else view.game._new_picture_tile(auto_word, 1)
		tile.merge({"column": index % view.game.COLUMNS, "row": 7 - int(index / view.game.COLUMNS), "age": 100.0,
			"settling": false, "falling": false, "arrival": false}, true)
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	view._process(0.0)
	check(app.coin_wallet.credit_amount("fixture:auto-merge-use", 600).ok, "Fund one actual isolated paid use")
	app._coin_flight.sync(app.coin_wallet.balance)
	var before_use: int = app.coin_wallet.balance
	await tap(view, view.powerup_buttons.auto_merge.get_global_rect().get_center())
	check(view.game.hit_stop_snapshot().active and view.game.hit_stop_snapshot().source == "auto_merge"
		and not view._powerup_effects.stamps.is_empty(),
		"The real paid button immediately owns a visible, receipt-bound hit-stop")
	for frame in range(800):
		if not view.game.powerup_active():
			break
		advance(app, 0.025)
	check(not view.game.powerup_active() and view.game.powerup_snapshot().affected_jellies == 8
		and view.game.powerup_snapshot().completed_results == 4 and view.game.collectable_ids().size() == 4
		and view.game.cells.size() == 4 and app.coin_wallet.balance == before_use - 600
		and view.snapshot().powerup_buttons.auto_merge.capacity_badge.text == "4",
		"A genuine touch pays once and leaves exactly four complete Jellies matching its badge")
	await capture_ui("auto-merge-lv2-gameplay")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly upgrade first-clear journey: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
