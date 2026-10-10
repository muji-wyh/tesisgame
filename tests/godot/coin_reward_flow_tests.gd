extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Progress = preload("res://scripts/medal_progress.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const Flight = preload("res://scripts/coin_reward_flight.gd")

var checks: int = 0
var failures: int = 0
var serial: int = 0


class Storage extends RefCounted:
	var coins: Variant = null
	var medals: Variant = null
	var pop: Variant = null
	var jelly: Variant = null
	var coin_writable: bool = true
	var medal_writable: bool = true
	var reward_writable: bool = true
	var coin_writes: int = 0

	func coinWalletState() -> Variant:
		return coins

	func saveCoinWalletState(value: String, expected: Variant) -> bool:
		if not coin_writable or expected != coins:
			return false
		coins = value
		coin_writes += 1
		return true

	func medalProgress() -> Variant:
		return medals

	func saveMedalProgress(value: String) -> bool:
		if not medal_writable:
			return false
		medals = value
		return true

	func popRewardState() -> Variant:
		return pop

	func savePopRewardState(value: String) -> bool:
		if not reward_writable:
			return false
		pop = value
		return true

	func jellyRewardState() -> Variant:
		return jelly

	func saveJellyRewardState(value: String) -> bool:
		if not reward_writable:
			return false
		jelly = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func make_app(mode: String, storage = null):
	serial += 1
	var directory := "user://coin-flow-%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), serial]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Coin flow uses isolated saves")
	var host = Storage.new() if storage == null else storage
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.coin_wallet = Wallet.new(directory + "/coins.cfg", host)
	app.medal_progress = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg", host)
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.reduced_motion = false
	app._presentation.has_motion_override = true
	check(app._presentation.save_preferences(), "Save muted presentation fixture")
	app._mode_id = mode
	check(app.medal_progress.load_progress(), "Load isolated medal ledger")
	if mode in ["match", "memory"] and app.medal_progress.pair_round(mode).is_empty():
		check(not app.medal_progress.begin_pair_round(mode, "reserved", 1).is_empty(), "Reserve one real pair chest")
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	app.set_process(false)
	app._memory.set_process(false)
	app._phrase.set_process(false)
	app._round_celebration.set_process(false)
	app._pop.set_process(false)
	app._jelly.set_process(false)
	app.chest.set_process(false)
	app.set_meta("coin_test_storage", host)
	return app


func dispose(app) -> void:
	app.audio.halt()
	app.queue_free()
	await settle()


func finish_single(app) -> void:
	if app._mode_id in ["match", "memory"]:
		for word in app.model.lesson_words:
			if app._mode_id == "match":
				app.cards[str(word.id) + ":word"].pressed.emit()
				app.cards[str(word.id) + ":image"].pressed.emit()
				app.feedback_timer.stop()
				app._continue_match()
			else:
				for index in range(app._memory.memory.cards.size()):
					if app._memory.memory.cards[index].word.id == word.id:
						app._memory.card_buttons[index].pressed.emit()
				app._memory._feedback_timer.stop()
				app._memory.continue_feedback()
	else:
		var view = app._phrase
		for question in range(3):
			for id in view.game.current_question().words:
				for index in range(view.game.options.size()):
					if view.game.options[index].id == id:
						view.option_buttons[index].pressed.emit()
			view.action_button.pressed.emit()
			view.pip.set_process(false)
			if question < 2:
				view.pip._process(view.pip.GAMEPLAY_HAPPY_SECONDS + 0.01)
				view.action_button.pressed.emit()
	Fixture.finish_celebration(app)
	check(app.model.phase == "won" and app.chest_button.is_visible_in_tree(), app._mode_id + " reaches its real chest page")
	check(app.coin_wallet.balance == 0 and not app._coin_flight.snapshot().active, "Earning a chest does not award coins before opening")


func open_single(app) -> void:
	app.chest_button.button_down.emit()
	app._advance_ui(Feel.HOLD_SECONDS)
	app.chest.set_process(false)
	check(app.model.chest_state in ["opening", "opened"], "The real hold starts the single chest opening")
	if app.model.chest_state == "opening":
		app.chest._advance_animation(Feel.OPEN_SECONDS + 0.01)
	check(app.model.chest_state == "opened", "The physical opening reaches its completion callback")


func make_room(app, tier: int):
	var room = app._pop_rewards if app._mode_id == "pop" else app._jelly_rewards
	check(room.connect_storage(app.get_meta("coin_test_storage")), "Room uses isolated durable rewards")
	var id: String = "coin-room-%d-%d" % [serial, tier]
	check(room.configure(id, 1, RewardProgress.theme_for_tier(tier), app.data.chests, false, tier), "Configure a saved final-tier reward")
	if app._mode_id == "pop":
		app._pop_rewards_shown = true
	else:
		app._jelly_rewards_shown = true
	app._refresh()
	room.resume()
	room.set_process(false)
	await settle()
	check(room.is_visible_in_tree() and room._cards.size() == 1, "Saved treasure is shown through the real mode room")
	return room


func open_room(room) -> void:
	room._cards[0].button.button_down.emit()
	room.advance_hold(Feel.HOLD_SECONDS)
	room._cards[0].art.set_process(false)
	check(room._opening, "The room's actual hold starts its chest")
	room._cards[0].art._advance_animation(Feel.OPEN_SECONDS + 0.01)


func check_arrival(app, expected: int) -> void:
	var state: Dictionary = app._coin_flight.snapshot()
	check(app.coin_wallet.balance == expected and state.active and state.target == 0 and state.displayed == 0.0,
		"Coins save before flight, while the HUD retains its pre-arrival balance")
	app._refresh()
	check(app._coin_flight.snapshot().target == 0, "An ordinary scene refresh cannot reveal unarrived coins")
	app._coin_flight.advance(Flight.BURST_SECONDS + Flight.TRAVEL_SECONDS - 0.001)
	check(app._coin_flight.snapshot().target == 0 and app._coin_flight.snapshot().displayed == 0.0,
		"The burst and travel do not increment the counter before arrival")
	app._coin_flight.advance(0.002)
	state = app._coin_flight.snapshot()
	check(state.target > 0 and state.target < expected and state.active, "The first arriving coin releases only its share")
	app._coin_flight.advance(2.0)
	state = app._coin_flight.snapshot()
	check(not state.active and state.target == expected and state.displayed == float(expected), "All arrivals finish at the saved total")


func check_single(mode: String) -> void:
	var app = await make_app(mode)
	app.choose_theme("space")
	finish_single(app)
	if mode in ["match", "memory"]:
		check(app._pair_reward.chest.theme_id == RewardProgress.theme_for_tier(1)
			and app.chest.theme_id == RewardProgress.theme_for_tier(1), "Pair reward and opening use the ordinary chest independently of the selected theme")
		app.choose_theme("candy")
		check(app.chest.theme_id == RewardProgress.theme_for_tier(1), "Changing outfit theme cannot upgrade an ordinary chest")
	app.chest_button.button_down.emit()
	app._advance_ui(0.3)
	app.chest_button.button_up.emit()
	check(app.coin_wallet.balance == 0 and app.model.chest_state == "closed", "Releasing an unfinished hold grants no coins")
	open_single(app)
	check_arrival(app, 50)
	var writes: int = app.get_meta("coin_test_storage").coin_writes
	app._on_chest_opened()
	app._commit_fragment()
	check(app.coin_wallet.balance == 50 and app.get_meta("coin_test_storage").coin_writes == writes
		and not app._coin_flight.snapshot().active, "Repeated single-chest callbacks cannot save or present another payout")
	check(app.coin_wallet._receipts.has(app._single_chest_receipt()), "Single chest payout uses the stable mode/round receipt")
	await dispose(app)


func check_tier(mode: String, tier: int) -> void:
	var app = await make_app(mode)
	var room = await make_room(app, tier)
	var id: String = room._cards[0].reward_id
	check(id.begins_with(mode + ":") and room._cards[0].art.theme_id == RewardProgress.theme_for_tier(tier), "Tiered room keeps the entry's chest design and receipt identity")
	open_room(room)
	check(room.rewards.entries[0].opened, "A saved coin payout consumes its room chest")
	check_arrival(app, tier * 50)
	var writes: int = app.get_meta("coin_test_storage").coin_writes
	room._finished(0)
	room._announce(0)
	check(room._commit(0) and app.coin_wallet.balance == tier * 50 and app.get_meta("coin_test_storage").coin_writes == writes,
		"Duplicate room completion cannot credit its stable receipt twice")
	check(not app._coin_flight.snapshot().active and app.coin_wallet._receipts.has(id), "A completed receipt cannot replay its flight")
	await dispose(app)


func check_save_retry(mode: String, fail_coins: bool) -> void:
	var app = await make_app(mode)
	var room = await make_room(app, 3)
	var storage = app.get_meta("coin_test_storage")
	storage.coin_writable = not fail_coins
	storage.reward_writable = fail_coins
	open_room(room)
	check(room._save_failed and not room.rewards.entries[0].opened and not app._coin_flight.snapshot().active,
		"Failed wallet or consumption save retains the chest without an unsaved flight")
	check(app.coin_wallet.balance == (0 if fail_coins else 150) and app._coin_flight.snapshot().target == 0,
		"A partial two-store commit preserves exactly its saved wallet state and pre-arrival display")
	storage.coin_writable = true
	storage.reward_writable = true
	room.retry_save()
	check(not room._save_failed and room.rewards.entries[0].opened and app.coin_wallet.balance == 150 and storage.coin_writes == 1,
		"Retry completes consumption with one durable payout, including duplicate-credit recovery")
	check_arrival(app, 150)
	room.retry_save()
	check(app.coin_wallet.balance == 150 and storage.coin_writes == 1 and not app._coin_flight.snapshot().active,
		"A second retry cannot reopen or reanimate its receipt")
	await dispose(app)


func check_single_retry(mode: String, fail_coins: bool, reconcile_in_background: bool = false) -> void:
	var app = await make_app(mode)
	finish_single(app)
	var storage = app.get_meta("coin_test_storage")
	storage.coin_writable = not fail_coins
	storage.medal_writable = fail_coins
	open_single(app)
	check(app._save_error and not app._coin_flight.snapshot().active and app._coin_flight.snapshot().target == 0,
		"Single-chest persistence failure keeps its coins out of the display")
	check(app.coin_wallet.balance == (0 if fail_coins else 50), "Single-chest retry retains the actual durable part of its payout")
	if reconcile_in_background:
		check(not fail_coins and app._pending_coin_reward.get("amount", 0) == 50,
			"Background retry retains a saved coin payout whose medal consumption is pending")
		app.on_page_hidden()
		check(not app._coin_flight.snapshot().active and app._coin_flight.snapshot().target == 50
			and app._coin_flight.snapshot().displayed == 50.0,
			"Backgrounding reconciles the saved wallet before the pending medal retry")
		app.on_page_visible()
	storage.coin_writable = true
	storage.medal_writable = true
	app._retry_reward_save()
	check(not app._save_error and app.coin_wallet.balance == 50 and storage.coin_writes == 1,
		"Single-chest retry completes the same receipt without issuing a second payout")
	if reconcile_in_background:
		var state: Dictionary = app._coin_flight.snapshot()
		check(not state.active and state.target == 50 and state.displayed == 50.0,
			"Retry cannot roll back the reconciled display or replay its already-visible reward")
		app._coin_flight.advance(0.01)
		check(app._coin_flight.snapshot().displayed == 50.0 and app._pending_coin_reward.is_empty(),
			"A reconciled retry clears pending visuals without a delayed rollback")
	else:
		check_arrival(app, 50)
	app._commit_fragment()
	check(storage.coin_writes == 1 and not app._coin_flight.snapshot().active, "Single-chest retry completion remains idempotent")
	await dispose(app)


func check_interruption(kind: String) -> void:
	var app = await make_app("match")
	finish_single(app)
	open_single(app)
	check(app._coin_flight.snapshot().active, "Interruption starts with actual coins in flight")
	match kind:
		"background": app.on_page_hidden()
		"catalog":
			app._show_collection()
			app._advance_ui(0.0)
		"new-round": check(app.new_round(881, false, "", "phrase"), "A new round can replace a completed coin presentation")
	check(not app._coin_flight.snapshot().active and app._coin_flight.snapshot().target == 50
		and app._coin_flight.snapshot().displayed == 50.0, "Leaving a coin flight safely reconciles its already-saved balance")
	if kind == "background":
		app.on_page_visible()
	elif kind == "catalog":
		app._hide_collection()
	app._coin_flight.advance(10.0)
	check(app.coin_wallet.balance == 50 and not app._coin_flight.snapshot().active, "Returning cannot replay or duplicate an interrupted receipt")
	await dispose(app)


func check_reduced() -> void:
	var app = await make_app("phrase")
	finish_single(app)
	app.set_reduced_motion(true)
	open_single(app)
	check(app.coin_wallet.balance == 50 and app._coin_flight.snapshot().target == 0, "Reduced motion retains a short static reward acknowledgement")
	app._coin_flight.advance(0.25)
	check(not app._coin_flight.snapshot().active and app._coin_flight.snapshot().target == 50
		and app._coin_flight.snapshot().displayed == 50.0, "The first reduced-motion update crossing arrival settles immediately without a number roll")
	await dispose(app)


func check_pending_reload() -> void:
	var storage := Storage.new()
	var app = await make_app("match", storage)
	var word: Dictionary = app.model.lesson_words[0]
	app.cards[str(word.id) + ":word"].pressed.emit()
	app.cards[str(word.id) + ":image"].pressed.emit()
	app.feedback_timer.stop()
	check(app.model.chest_earned and app.coin_wallet.balance == 0, "An earned unfinished pair chest has no premature coins")
	var receipt: String = app._single_chest_receipt()
	await dispose(app)
	app = await make_app("match", storage)
	check(app.coin_wallet.balance == 50 and app.coin_wallet._receipts.has(receipt)
		and not app._coin_flight.snapshot().active and app._coin_flight.snapshot().target == 50,
		"Startup silently settles the preserved earned chest into one wallet receipt")
	await dispose(app)
	app = await make_app("match", storage)
	check(app.coin_wallet.balance == 50 and storage.coin_writes == 1, "A second startup cannot retroactively credit the settled chest again")
	await dispose(app)


func check_startup_pending_memory_retry() -> void:
	var storage := Storage.new()
	var app = await make_app("memory", storage)
	var word: Dictionary = app.model.lesson_words[0]
	for index in range(app._memory.memory.cards.size()):
		if app._memory.memory.cards[index].word.id == word.id:
			app._memory.card_buttons[index].pressed.emit()
	app._memory._feedback_timer.stop()
	var pair: Dictionary = app.medal_progress.pair_round("memory")
	var receipt: String = app._single_chest_receipt()
	var fragment: Dictionary = pair.fragment.duplicate(true)
	check(pair.awarded and not pair.settled and app.coin_wallet.balance == 0,
		"A real Memory pair leaves one earned chest pending for startup recovery")
	await dispose(app)
	storage.coin_writable = false
	app = await make_app("phrase", storage)
	check(not app._progress_ready and app._save_error and not app._pair_save_failed,
		"A pending Memory coin-write failure reaches the generic startup retry path in another mode")
	check(not app.medal_progress.pair_round("memory").settled and app.coin_wallet.balance == 0
		and storage.coin_writes == 0 and app.medal_progress.count_for(fragment.medal_id) == int(fragment.before),
		"Failed startup credit preserves both the Memory chest and its unclaimed contents")
	check(app._storage_retry_button.is_visible_in_tree() and not app._storage_retry_button.disabled,
		"The in-session generic retry control is available after startup recovery fails")
	app._storage_retry_button.pressed.emit()
	check(not app._progress_ready and app._save_error and not app.medal_progress.pair_round("memory").settled,
		"Retry while coin storage is still blocked keeps the recoverable chest intact")
	storage.coin_writable = true
	app._storage_retry_button.pressed.emit()
	check(app._progress_ready and not app._save_error and not app._pair_save_failed,
		"The same generic retry completes startup recovery without reloading the scene")
	check(app.coin_wallet.balance == 50 and storage.coin_writes == 1 and app.coin_wallet._receipts.has(receipt)
		and app.medal_progress.pair_round("memory").settled,
		"Startup retry credits the original Memory receipt once and settles its pending chest")
	check(app.medal_progress.count_for(fragment.medal_id) == int(fragment.after)
		and app.collected_rewards.has(fragment.medal_id),
		"Startup retry also refreshes the collected reward from the newly settled chest")
	check(not app._coin_flight.snapshot().active and app._coin_flight.snapshot().target == 50
		and app._coin_flight.snapshot().displayed == 50.0,
		"Recovered startup coins synchronize the HUD without replaying an opening flight")
	app._retry_storage()
	app.choose_mode("memory")
	check(app._mode_id == "memory" and app._memory.is_visible_in_tree() and not app._memory._paused
		and app._memory.memory.phase == "waiting" and not app._pair_save_failed,
		"After generic recovery the player can switch directly into a fresh playable Memory round")
	app._memory.card_buttons[0].pressed.emit()
	check(app._memory.memory.selected_indices.size() == 1,
		"The recovered Memory board accepts its first real card input")
	check(app.coin_wallet.balance == 50 and storage.coin_writes == 1
		and app.medal_progress.count_for(fragment.medal_id) == int(fragment.after)
		and not app._coin_flight.snapshot().active,
		"Repeated retry and mode switching cannot duplicate the recovered coins or chest contents")
	await dispose(app)


func check_header() -> void:
	var app = await make_app("match")
	for high_balance in [false, true]:
		if high_balance:
			var credited: Dictionary = app._credit_coins("layout:large-balance", 24691)
			check(credited.ok and app.coin_wallet.balance == 1234550, "The large-balance layout fixture uses a valid persisted payout")
			app._coin_flight.sync(app.coin_wallet.balance)
		for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(568, 320), Vector2i(844, 390), Vector2i(1000, 800)]:
			root.size = dimensions
			app._layout()
			await settle()
			var bounds: Rect2 = app._coin_counter.get_global_rect()
			var context: String = "%s with %d coins" % [dimensions, app.coin_wallet.balance]
			check(app._coin_counter.is_visible_in_tree() and bounds.has_area() and root.get_visible_rect().encloses(bounds),
				"Coin HUD remains visible inside the viewport at " + context)
			check(bounds.has_point(app._coin_counter.icon_center()), "Flight destination stays inside the resized coin HUD at " + context)
			check(not app._mode_heading.is_visible_in_tree() or not bounds.intersects(app._mode_heading.get_global_rect()),
				"Coin HUD does not overlap the visible game mode text at " + context)
			var hit: Rect2 = app._mode_heading_button.get_global_rect()
			var css_scale: float = app.Style.ui_scale(app)
			check(not app._mode_heading_button.is_visible_in_tree() or (hit.size.x * css_scale >= 44.0 and hit.size.y * css_scale >= 44.0),
				"The mode button preserves its 44 CSS-pixel touch target at " + context)
			check(app._coin_counter.target == app.coin_wallet.balance and app._coin_counter.displayed == float(app.coin_wallet.balance),
				"Responsive relayout preserves the complete saved coin value at " + context)
	check(app._coin_flight.mouse_filter == Control.MOUSE_FILTER_IGNORE and app._coin_counter.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Coin effects and the balance display do not capture gameplay input")
	await dispose(app)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 800)
	for mode in ["match", "memory", "phrase"]:
		await check_single(mode)
	for mode in ["pop", "jelly"]:
		for tier in [1, 3]:
			await check_tier(mode, tier)
		for fail_coins in [true, false]:
			await check_save_retry(mode, fail_coins)
	await check_single_retry("memory", true)
	await check_single_retry("phrase", false)
	for mode in ["memory", "phrase"]:
		await check_single_retry(mode, false, true)
	for kind in ["background", "catalog", "new-round"]:
		await check_interruption(kind)
	await check_reduced()
	await check_pending_reload()
	await check_startup_pending_memory_retry()
	await check_header()
	print("Coin reward flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
