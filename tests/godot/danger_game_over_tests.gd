extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")
const Progress = preload("res://scripts/medal_progress.gd")
const Feel = preload("res://scripts/chest_feel.gd")
const SIZES: Array[Vector2i] = [Vector2i(393, 852), Vector2i(320, 480), Vector2i(568, 320), Vector2i(1473, 1175)]

var checks: int = 0
var failures: int = 0
var serial: int = 0


class Storage extends RefCounted:
	var coins: Variant = null
	var jelly: Variant = null
	var coin_writable: bool = true
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

	func jellyRewardState() -> Variant:
		return jelly

	func saveJellyRewardState(value: String) -> bool:
		if not reward_writable:
			return false
		jelly = value
		return true


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func make_app(mode: String):
	serial += 1
	var directory := "user://danger-game-over-%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), serial]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The settlement fixture has isolated storage")
	var storage := Storage.new()
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.coin_wallet = Wallet.new(directory + "/coins.cfg", storage)
	app.medal_progress = Progress.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.save_preferences()
	app._mode_id = mode
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	for node in [app, app._jelly, app._word_jelly, app._round_celebration, app._jelly_rewards]:
		node.set_process(false)
	check(app._jelly_rewards.connect_storage(storage), mode + ": settlement uses the real reward persistence adapter")
	check(app.new_round(51, false, "", mode, "", false), mode + ": a seeded board starts through GameUI")
	app.set_meta("danger_storage", storage)
	await settle()
	return app


func dispose(app) -> void:
	app.audio.halt()
	app.queue_free()
	await settle()


func key(code: Key, pressed: bool = true, shifted: bool = false, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.shift_pressed = shifted
	event.echo = echo
	root.push_input(event, true)


func fill_and_expire(app, mode: String, held_accept: bool = false) -> void:
	var game = app._active_jelly().game
	for attempt in range(game.CAPACITY * 4):
		if game.full_elapsed >= 0.0 or game.phase != "playing":
			break
		if game.can_drop_now():
			game.drop_now()
		game.step(0.25)
	check(game.phase == "playing" and game.full_elapsed >= 0.0,
		mode + ": actual preview supply fills the board and starts its danger deadline")
	if game.phase != "playing" or game.full_elapsed < 0.0:
		return
	game.step(maxf(0.0, game.FULL_SECONDS - game.full_elapsed - 0.01))
	check(game.phase == "playing" and not app._jelly_game_over.snapshot().visible,
		mode + ": the final warning remains playable until the full deadline expires")
	if held_accept:
		root.gui_release_focus()
		key(KEY_ENTER)
	game.step(0.011)
	check(game.phase == "finished" and app._round_result.get("reason") == "danger",
		mode + ": natural danger expiry records an explicit game-over reason")
	if held_accept:
		var round_id: String = app._round_id
		key(KEY_ENTER, true, false, true)
		key(KEY_ENTER, false)
		check(app._jelly_game_over.is_visible_in_tree() and app._round_id == round_id and not app._mode_menu_open(),
			mode + ": an accept key held before timeout cannot activate the new dialog")


func check_modal(app, mode: String, chests: int) -> void:
	var view = app._active_jelly()
	var modal = app._jelly_game_over
	var room = app._jelly_rewards
	check(modal.is_visible_in_tree() and modal.snapshot().visible and modal.snapshot().title == "Game over",
		mode + ": the expired warning immediately opens a Game over dialog")
	check(app._jelly_rewards_shown and room.is_visible_in_tree() and modal.is_ancestor_of(room)
		and view.is_visible_in_tree() and not view._result_visible,
		mode + ": settlement stays inside the overlay above the frozen board")
	check(not app._round_celebration.is_active() and room._heading.text == "Game over"
		and room.snapshot().result_context == app._round_result,
		mode + ": game over keeps its actual round totals without a victory intermission")
	check(int(app._round_result.chest_count) == chests and room._cards.size() == chests,
		mode + ": the dialog shows only the earned chest count")
	check(not app._jelly_interaction_allowed() and not view.finish_button.is_visible_in_tree(),
		mode + ": the expired board and its Finish action no longer accept play")
	for control: Control in app._focus_candidates():
		check(modal.is_ancestor_of(control), mode + ": focus cannot escape the settlement overlay")
	check(modal.is_ancestor_of(app._default_focus()), mode + ": default focus belongs to the settlement")
	var focused: Control = root.gui_get_focus_owner()
	check(focused != null and modal.is_ancestor_of(focused),
		"%s: the visible dialog actually owns keyboard focus with %d chests (owner: %s)" % [mode, chests,
			str(focused.get_path()) if focused != null else "none"])
	var before: Dictionary = view.game.snapshot()
	view.game.step(100.0)
	view.drop_button.pressed.emit()
	view.finish_button.accessibility_requested.emit()
	check(view.game.snapshot() == before and not app._finish_confirmation_open(),
		mode + ": stale play actions cannot alter an expired round")


func check_keyboard(app, mode: String) -> void:
	var modal = app._jelly_game_over
	for button: Button in [app._jelly_rewards._home, app._jelly_rewards._back]:
		for code: Key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_TAB]:
			for shifted: bool in ([false, true] if code == KEY_TAB else [false]):
				button.grab_focus()
				key(code, true, shifted)
				key(code, false, shifted)
				await process_frame
				var owner: Control = root.gui_get_focus_owner()
				check(owner != null and modal.is_ancestor_of(owner),
					mode + ": native arrows and Tab stay inside the dialog from either footer action")


func check_layout(app, mode: String) -> void:
	var modal = app._jelly_game_over
	for dimensions: Vector2i in SIZES:
		root.size = dimensions
		await settle()
		var bounds := Rect2(Vector2.ZERO, app.size)
		var values: Array = modal.snapshot().panel_rect
		var panel := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
		check(bounds.grow(0.1).encloses(panel), mode + ": the entire dialog fits at " + str(dimensions))
		var scale: float = app.Style.ui_scale(app)
		for control: Control in modal.find_children("*", "Button", true, false):
			if not control.is_visible_in_tree():
				continue
			check(bounds.grow(0.1).encloses(control.get_global_rect()) and control.size.y * scale >= 43.75,
				mode + ": every settlement action remains visible and touchable at " + str(dimensions))
		check(is_zero_approx(float(app._jelly_rewards.snapshot().scroll_max)),
			mode + ": settlement requires no scrolling at " + str(dimensions))
	root.size = Vector2i(393, 852)
	await settle()


func earn_chest(app, mode: String) -> void:
	var view = app._active_jelly()
	var game = view.game
	var word: Dictionary = {}
	if mode == "word_jelly":
		word = app._learning_words().filter(func(item: Dictionary) -> bool: return str(item.text).length() == 3)[0]
		check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, true, 51),
			mode + ": the reward fixture uses a real current-age word")
		app._sync_jelly()
	game.spawn_interval = 10000.0
	for attempt in range(300):
		view.advance_reward_presentation(8.0)
		if game.fragment_count >= 4 or game.phase != "playing":
			break
		game.step(2.0)
		var chosen: Array = []
		for first: Dictionary in game.cells:
			for second: Dictionary in game.cells:
				if first.id == second.id or not game.is_settled(first) or not game.is_settled(second):
					continue
				var compatible: bool = first.word.id == second.word.id and first.kind != second.kind if mode == "jelly" \
					else str(first.text) + str(second.text) == str(word.text)
				if compatible:
					chosen = [first, second]
					break
			if not chosen.is_empty():
				break
		if chosen.is_empty():
			if game.can_drop_now():
				game.drop_now()
			continue
		var outcome: String = game.try_merge(chosen[0].id, chosen[1].id)
		check(outcome == ("correct" if mode == "jelly" else "merged"), mode + ": a real merge earns the reward fixture")
		var merged_id: int = int(game.fusions.back().result.id) if mode == "word_jelly" else -1
		game.step(game.FUSION_SECONDS + 2.0)
		if mode == "word_jelly":
			game._coin_rng.seed = 0
			check(game.collect(merged_id), mode + ": a real word is collected with its carried fragments")
			game.step(game.COLLECT_SECONDS + 2.0)
	view.advance_reward_presentation(8.0)
	check(game.phase == "playing" and game.chest_count == 1 and game.chest_tier == 1,
		mode + ": actual completed play earns one ordinary chest before timeout")


func check_zero_result(mode: String) -> void:
	var app = await make_app(mode)
	fill_and_expire(app, mode, true)
	await settle()
	check_modal(app, mode, 0)
	await check_keyboard(app, mode)
	check(app.coin_wallet.balance == 0 and not app._jelly_rewards.has_pending(),
		mode + ": timeout creates no coin or chest without completed play")
	await check_layout(app, mode)
	var old_round: String = app._round_id
	app.on_page_hidden()
	check(not app._jelly_game_over.is_visible_in_tree(), mode + ": hiding the page hides its dialog")
	app.on_page_visible()
	await settle()
	check(app._jelly_game_over.is_visible_in_tree() and app._round_id == old_round,
		mode + ": returning restores the same finished round")
	var focus: Control = root.gui_get_focus_owner()
	check(focus != null and app._jelly_game_over.is_ancestor_of(focus),
		mode + ": returning to the page restores keyboard focus inside Game over")
	app._jelly_rewards._back.pressed.emit()
	check(app._round_id != old_round and app._active_jelly().game.phase == "playing"
		and not app._jelly_game_over.is_visible_in_tree(), mode + ": Play again dismisses the dialog and starts a fresh board")
	await dispose(app)


func check_earned_result(mode: String) -> void:
	var app = await make_app(mode)
	var storage = app.get_meta("danger_storage")
	earn_chest(app, mode)
	storage.reward_writable = false
	fill_and_expire(app, mode)
	await settle()
	var room = app._jelly_rewards
	check(app._jelly_game_over.is_visible_in_tree() and room._save_failed and room._retry.is_visible_in_tree(),
		mode + ": a failed reward save exposes Retry save inside the game-over dialog")
	await check_layout(app, mode + " save failure")
	var old_round: String = app._round_id
	room._back.pressed.emit()
	check(app._round_id == old_round and app._jelly_game_over.is_visible_in_tree(),
		mode + ": an unsaved reward cannot be discarded by Play again")
	storage.reward_writable = true
	room.retry_save()
	await settle()
	check(not room._save_failed and room.has_pending(), mode + ": Retry save preserves the earned chest")
	check_modal(app, mode, 1)
	await check_keyboard(app, mode + " earned chest")
	await check_layout(app, mode + " earned chest")
	var amount: int = int(app._round_result.chest_tier) * 50
	var initial_coins: int = app.coin_wallet.balance
	room.begin_hold(room._cards[0].button)
	room.advance_hold(Feel.HOLD_SECONDS)
	check(room.snapshot().opened_count == 1 and app.coin_wallet.balance == initial_coins + amount,
		mode + ": holding the chest settles its coins directly inside the dialog")
	var writes: int = storage.coin_writes
	app._active_jelly().game.finish_round()
	room.begin_hold(room._cards[0].button)
	room.advance_hold(Feel.HOLD_SECONDS)
	check(app.coin_wallet.balance == initial_coins + amount and storage.coin_writes == writes,
		mode + ": repeated completion and chest input cannot pay the same reward twice")
	room._back.pressed.emit()
	check(app._round_id != old_round and app._active_jelly().game.phase == "playing"
		and app.coin_wallet.balance == initial_coins + amount, mode + ": replay keeps the settled wallet")
	fill_and_expire(app, mode)
	await settle()
	check_modal(app, mode, 0)
	check(room._cards.is_empty(), mode + ": a later empty result never resurrects an opened chest")
	room.home_requested.emit()
	check(app._mode_menu_open() and not app._jelly_game_over.is_visible_in_tree(),
		mode + ": the dialog offers a direct Home route")
	var finished_round: String = app._round_id
	app.choose_mode(mode)
	await settle()
	check(app._round_id == finished_round and app._jelly_game_over.is_visible_in_tree(),
		mode + ": choosing the same mode from Home restores its settled Game over")
	await dispose(app)


func check_voluntary_finish(mode: String) -> void:
	var app = await make_app(mode)
	app._active_jelly().game.finish_round()
	await settle()
	check(app._round_result.get("reason") == "finished" and not app._jelly_game_over.is_visible_in_tree()
		and app._active_jelly()._result_visible, mode + ": voluntary Finish keeps the ordinary result flow")
	await dispose(app)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	for mode: String in ["jelly", "word_jelly"]:
		await check_zero_result(mode)
		await check_earned_result(mode)
		await check_voluntary_finish(mode)
	print("Danger game over: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
