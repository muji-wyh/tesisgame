extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Wallet = preload("res://scripts/coin_wallet.gd")

var checks: int = 0
var failures: int = 0
var round_seed: int = 910
var cues: Array[String] = []
var purchases: Array[Dictionary] = []
var arrivals: Array[Dictionary] = []


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


func _prepare(app, pairs: int = 2) -> void:
	round_seed += 1
	check(app.new_round(round_seed, false, "", "word_jelly"), "A powerup fixture starts through the full application's round route")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	var word: Dictionary = app._learning_words().filter(func(item: Dictionary) -> bool:
		return str(item.text).length() >= 3 and str(item.text).length() <= 6)[0]
	check(view.configure([word], app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, false, round_seed),
		"The powerup board uses an actual pictured current-age word")
	app._sync_jelly()
	view.set_process(false)
	var game = view.game
	game.spawn_interval = 10000.0
	game.cells.clear()
	var parts: Array[String] = game._parts_for_word(word)
	for index in range(pairs * 2):
		var tile: Dictionary = game._new_tile(parts[index % 2], 1, 0)
		tile.column = int(index / 2) if index % 2 == 0 else 3 + int(index / 2)
		tile.row = game.ROWS - 1
		game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	view._process(0.0)
	app.audio.set_muted(false)
	app.audio.interact(app.model.theme_id, false)
	app.audio.stop_pair_feedback()
	app.audio.stop_jelly_sounds()
	cues.clear()
	purchases.clear()
	arrivals.clear()


func _drain(view) -> void:
	for frame in range(500):
		if not view.game.powerup_active():
			break
		view._process(0.04)
	view._process(0.0)
	check(not view.game.powerup_active(), "Every paid powerup completes within its bounded animation sequence")


func _carried_fragments(game) -> int:
	var total: int = 0
	for tile: Dictionary in game.cells:
		total += int(tile.fragments)
	return total


func _check_insufficient(app) -> void:
	await _prepare(app)
	var view = app._word_jelly
	var game = view.game
	var history: Dictionary = game._merge_history.duplicate(true)
	var saved: Variant = app.coin_wallet._saved_text
	for kind: String in ["auto_merge", "fragments"]:
		var board: Array = game.cells.duplicate(true)
		var button = view.powerup_buttons[kind]
		check(button.is_visible_in_tree() and not button.disabled, "An unaffordable " + kind + " remains available for meaningful feedback")
		button.pressed.emit()
		check(game.cells == board and game._merge_history == history and game.fusions.is_empty()
			and not game.powerup_active() and game.collected_coins == 0 and game.fragment_count == 0,
			"An unfunded " + kind + " changes no jelly, reward, or fragment state")
		check(app.coin_wallet.balance == 0 and app.coin_wallet._saved_text == saved
			and app.coin_wallet.ready and app.coin_wallet.error.is_empty() and app._coin_counter.available,
			"Insufficient funds leave wallet storage and the visible coin counter available")
		check(purchases.back() == {"kind": kind, "success": false} and cues.back() == "powerup_wrong",
			"An unfunded button produces one negative purchase response")
		check(app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[false]),
			"Unfunded purchases use the application's negative feedback recording")
		view._process(0.09)
		check(button.snapshot().feedback_active and not button.snapshot().feedback_success and float(button.snapshot().light) > 0.0,
			"The rejected purchase remains visibly marked on its own button")
		app.audio.stop_pair_feedback()
	check(cues.count("powerup_wrong") == 2 and cues.count("powerup_success") == 0,
		"Two unfunded attempts never announce success")


func _check_auto_merge(app) -> void:
	await _prepare(app)
	var view = app._word_jelly
	var game = view.game
	var before: int = app.coin_wallet.balance
	var receipts: int = app.coin_wallet._receipts.size()
	var growth: Dictionary = app.growth.snapshot().streaks.duplicate(true)
	view.powerup_buttons.auto_merge.pressed.emit()
	var state: Dictionary = game.powerup_snapshot()
	check(state.active and state.kind == "auto_merge" and state.stage == "drag"
		and app.coin_wallet.balance == before - 2000 and app.coin_wallet._receipts.size() == receipts + 1,
		"The Auto merge button durably pays once before starting a visible automatic drag")
	check(cues.count("powerup_success") == 1 and purchases == [{"kind": "auto_merge", "success": true}]
		and app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[true]),
		"A saved purchase starts the positive response and its existing sound")
	check(view.collect_button.disabled and view.powerup_buttons.auto_merge.disabled and view.powerup_buttons.fragments.disabled,
		"The automatic sequence reserves all three gameplay action buttons")
	view.powerup_buttons.auto_merge.pressed.emit()
	view.powerup_buttons.fragments.pressed.emit()
	check(app.coin_wallet.balance == before - 2000 and app.coin_wallet._receipts.size() == receipts + 1,
		"Repeated button signals during a paid sequence cannot buy another action")
	var from: Vector2 = view._tile_rect(state.source).get_center()
	var to: Vector2 = view._tile_rect(state.target).get_center()
	view._process(game.POWERUP_DRAG_SECONDS * 0.5)
	var halfway: Vector2 = view._tiles[int(state.source_id)].get_rect().get_center()
	check(halfway.distance_to(from) > 2.0 and halfway.distance_to(to) > 2.0
		and halfway.x > minf(from.x, to.x) and halfway.x < maxf(from.x, to.x)
		and view._powerup_effects.stamps.size() > 0 and game.fusions.is_empty(),
		"The source jelly travels through an intermediate position with light effects before union")
	view._process(0.10)
	var concurrent: Dictionary = game.powerup_snapshot()
	check(concurrent.drags.size() == 2 and game.fusions.is_empty(),
		"At 250 ms two automatic sources travel simultaneously before the first contact")
	var following: Dictionary = concurrent.drags.back()
	check(int(following.source_id) != int(state.source_id) and int(following.target_id) != int(state.target_id)
		and is_equal_approx(float(following.elapsed), 0.05),
		"The second random source receives its own reserved pair and starts at 200 ms")
	var next_from: Vector2 = view._tile_rect(following.source).get_center()
	var next_to: Vector2 = view._tile_rect(following.target).get_center()
	for drag: Dictionary in concurrent.drags:
		var origin: Vector2 = view._tile_rect(drag.source).get_center()
		var target: Vector2 = view._tile_rect(drag.target).get_center()
		var body: Vector2 = view._tiles[int(drag.source_id)].get_rect().get_center()
		check(body.distance_to(origin) > 0.1 and body.distance_to(target) > 0.1
			and body.x > minf(origin.x, target.x) and body.x < maxf(origin.x, target.x),
			"Each concurrent source is painted at its own intermediate travel position")
	view._process(0.05)
	var after_contact: Dictionary = game.powerup_snapshot()
	check(game.fusions.size() == 1 and after_contact.drags.size() == 1
		and int(after_contact.drags[0].source_id) == int(following.source_id)
		and is_equal_approx(float(after_contact.drags[0].elapsed), 0.1),
		"At 300 ms only the first source contacts while the second keeps its existing motion clock")
	view._process(0.05)
	var next_halfway: Vector2 = view._tiles[int(following.source_id)].get_rect().get_center()
	check(game.fusions.size() == 1 and next_halfway.distance_to(next_from) > 2.0
		and next_halfway.distance_to(next_to) > 2.0 and view._powerup_effects.stamps.size() > 0,
		"The next source visibly travels with its own light trail while the previous fusion remains animated")
	_drain(view)
	check(game.cells.size() == 2 and game.collectable_ids().size() == 2 and int(game.powerup_snapshot().completed) == 2,
		"One automatic purchase completes each available forward word pair on the captured board")
	check(game.collected_coins == 0 and game.fragment_count == 0 and game.cleared_pairs == 0
		and app.coin_wallet.balance == before - 2000 and app.growth.snapshot().streaks == growth
		and not app._coin_flight.snapshot().active,
		"Automatic merging leaves words for manual collection without rewards, mastery, or coin flights")
	check(app.audio.voice.playing and app.audio._voice_queue.size() == 1,
		"Two completed automatic merges pronounce one word and queue the next without interrupting it")
	check(not view.collect_button.disabled and not view.powerup_buttons.fragments.disabled,
		"The three-action area returns control after the paid sequence")
	var duplicate: Dictionary = app._purchase_word_jelly_powerup(str(state.receipt_id), "auto_merge", 2000)
	check(bool(duplicate.ok) and bool(duplicate.duplicate) and int(duplicate.amount) == 0
		and app.coin_wallet.balance == before - 2000 and app.coin_wallet._receipts.size() == receipts + 1,
		"Repeating an already-paid application callback preserves the exact wallet balance and receipt count")
	check(app._status_announcement.contains("already processed") and not app._status_announcement.contains("purchased for")
		and purchases.size() == 1 and cues.count("powerup_success") == 1 and not game.powerup_active(),
		"An idempotent purchase callback never announces or animates a second successful purchase")


func _check_storage_failure(app) -> void:
	await _prepare(app, 1)
	var view = app._word_jelly
	var before: int = app.coin_wallet.balance
	var board: Array = view.game.cells.duplicate(true)
	var receipts: Dictionary = app.coin_wallet._receipts.duplicate()
	var saved: String = FileAccess.get_file_as_string(app.coin_wallet._path)
	var staging: String = app.coin_wallet._path + ".pending"
	check(DirAccess.make_dir_absolute(staging) == OK, "Block the isolated wallet staging path for a purchase failure")
	view.powerup_buttons.fragments.pressed.emit()
	check(app.coin_wallet.balance == before and app.coin_wallet._receipts == receipts
		and FileAccess.get_file_as_string(app.coin_wallet._path) == saved
		and view.game.cells == board and not view.game.powerup_active(),
		"A failed durable purchase starts no effect and leaves all money, fragments, and receipts untouched")
	check(not app._coin_counter.available and not app.coin_wallet.error.is_empty()
		and purchases == [{"kind": "fragments", "success": false}] and cues.count("powerup_wrong") == 1,
		"Storage failure reports unavailable coins and negative feedback instead of pretending the powerup was purchased")
	check(DirAccess.remove_absolute(staging) == OK, "Restore the wallet staging path for purchase recovery")
	view.powerup_buttons.fragments.pressed.emit()
	check(app.coin_wallet.balance == before - 500 and app._coin_counter.available and view.game.powerup_active(),
		"The same button recovers verified storage and starts one paid powerup after saving succeeds")
	_drain(view)
	check(app.coin_wallet._receipts.size() == receipts.size() + 1 and cues.count("powerup_success") == 1,
		"Storage retry creates exactly one debit and one successful action")


func _check_fragments(app) -> void:
	await _prepare(app)
	var view = app._word_jelly
	var game = view.game
	var before: int = app.coin_wallet.balance
	view.powerup_buttons.fragments.pressed.emit()
	var state: Dictionary = game.powerup_snapshot()
	check(state.active and state.kind == "fragments" and int(state.total) >= 2 and int(state.total) <= 8
		and app.coin_wallet.balance == before - 500 and _carried_fragments(game) == 0,
		"Treasure purchases reserve two to eight fragment arrivals for the exact 500-coin price")
	view._process(game.POWERUP_FRAGMENT_FLIGHT * 0.5)
	check(view._powerup_effects.stamps.size() > 0 and _carried_fragments(game) == 0,
		"Treasure art flies toward the board before any fragment is attached")
	view._process(game.POWERUP_FRAGMENT_FLIGHT * 0.5 + 0.001)
	check(arrivals.size() == 1 and _carried_fragments(game) == 1 and cues.count("powerup_fragment") == 1,
		"The first visible arrival attaches exactly one fragment and triggers its assembly cue")
	var arrived_id: int = int(arrivals[0].tile_id)
	check(view._tiles[arrived_id].visible_fragment_badges() == 1 and not view._powerup_arrivals.is_empty()
		and view._powerup_effects.stamps.size() > 0, "The destination shows its new fragment badge with an arrival flash")
	var assemble_playing: bool = false
	for player: AudioStreamPlayer in app.audio._jelly_players:
		assemble_playing = assemble_playing or (player.playing and player.stream == load(app.audio.JELLY_PATHS.assemble))
	check(assemble_playing, "Fragment arrival uses the application's acquired assembly recording")
	_drain(view)
	check(_carried_fragments(game) == int(state.total) and arrivals.size() == int(state.total)
		and cues.count("powerup_fragment") == int(state.total) and game.fragment_count == 0
		and game.chest_count == 0 and game.collected_coins == 0 and app.coin_wallet.balance == before - 500,
		"All purchased fragments remain on jelly bodies until collection, with one arrival event each and no immediate chest payout")
	for tile: Dictionary in game.cells:
		check(view._tiles[int(tile.id)].visible_fragment_badges() == int(tile.fragments),
			"Every purchased fragment is represented by its destination's badge count")


func _check_fragment_coarse_frame(app) -> void:
	await _prepare(app)
	var view = app._word_jelly
	var game = view.game
	var probe := RandomNumberGenerator.new()
	for seed_value in range(100):
		probe.seed = seed_value
		if probe.randi_range(2, 8) >= 3:
			game._rng.seed = seed_value
			break
	view.powerup_buttons.fragments.pressed.emit()
	check(int(game.powerup_snapshot().total) >= 3, "A real random purchase schedules at least three staggered fragment arrivals")
	view._process(0.35)
	check(arrivals.is_empty() and view._powerup_arrivals.is_empty(), "A coarse frame before the first contact cannot show an early fragment pop")
	view._process(0.50)
	check(arrivals.size() == 3 and view._powerup_arrivals.size() == 3 and _carried_fragments(game) == 3,
		"One coarse frame crossing three arrival beats preserves every fragment attachment and pop")
	var expected_ages: Array[float] = [0.43, 0.25, 0.07]
	for index in range(mini(3, view._powerup_arrivals.size())):
		var arrival: Dictionary = view._powerup_arrivals[index]
		check(int(arrival.index) == index and absf(float(arrival.elapsed) - expected_ages[index]) < 0.001,
			"Fragment pop %d retains its own scheduled age across a slow frame" % index)
	view._process(0.10)
	check(view._powerup_arrivals.size() >= 2 and int(view._powerup_arrivals[0].index) == 1,
		"The oldest pop expires independently while later arrival flashes remain visible")
	_drain(view)


func _check_lifecycle(app) -> void:
	await _prepare(app, 2)
	var view = app._word_jelly
	var game = view.game
	var before: int = app.coin_wallet.balance
	view.powerup_buttons.auto_merge.pressed.emit()
	view._process(0.25)
	var paused: Dictionary = game.powerup_snapshot()
	check(paused.drags.size() == 2, "Home interruption covers both concurrently moving paid sources")
	app._show_mode_menu()
	view._process(0.40)
	check(game.paused and game.powerup_snapshot() == paused, "Home freezes the paid automatic drag clock")
	check(not view._powerup_effects.is_visible_in_tree(), "Home hides paid automatic drag effects")
	check(not app.audio.pair_feedback.playing, "Home stops purchase feedback audio")
	app._hide_mode_menu()
	view.set_process(false)
	check(not game.paused and game.powerup_snapshot() == paused and app.coin_wallet.balance == before - 2000
		and view._powerup_effects.is_visible_in_tree(),
		"Returning from Home resumes the same already-paid automatic drag")
	view.finish_button.accessibility_requested.emit()
	check(app._finish_confirmation_open() and game.paused, "Finish confirmation can pause a paid automatic sequence")
	view._process(0.40)
	check(game.powerup_snapshot() == paused, "An open Finish confirmation cannot advance paid motion")
	app._finish_confirmation.keep_playing_button.pressed.emit()
	view.set_process(false)
	check(not game.paused and game.powerup_snapshot() == paused, "Cancelling Finish resumes the original powerup rather than purchasing again")
	_drain(view)
	check(app.coin_wallet.balance == before - 2000 and cues.count("powerup_success") == 1,
		"Home and Finish interruptions do not replay purchase feedback or charge again")
	await _prepare(app, 1)
	game = view.game
	before = app.coin_wallet.balance
	view.powerup_buttons.fragments.pressed.emit()
	var total: int = int(game.powerup_snapshot().total)
	view.finish_button.accessibility_requested.emit()
	check(app._finish_confirmation_open(), "Finish confirms before ending a purchased fragment flight")
	app._finish_confirmation.finish_button.pressed.emit()
	check(game.phase == "finished" and not game.powerup_active() and _carried_fragments(game) == total
		and game.collected_coins == 0 and game.fragment_count == 0 and app.coin_wallet.balance == before - 500,
		"Confirmed Finish settles the purchased obligation without automatic collection or a second charge")


func _check_preferences(app) -> void:
	await _prepare(app, 1)
	var view = app._word_jelly
	app.set_reduced_motion(true)
	app.audio.set_muted(true)
	var before: int = app.coin_wallet.balance
	view.powerup_buttons.auto_merge.pressed.emit()
	var state: Dictionary = view.game.powerup_snapshot()
	view._process(view.game.POWERUP_DRAG_SECONDS * 0.5)
	var from: Vector2 = view._tile_rect(state.source).get_center()
	var to: Vector2 = view._tile_rect(state.target).get_center()
	check(view.reduced_motion and view._tiles[int(state.source_id)].get_rect().get_center().distance_to(from.lerp(to, 0.5)) < 0.1,
		"Reduced motion uses a direct readable automatic transfer without the arcing lift")
	check(not app.audio.pair_feedback.playing and not app.audio.voice.playing,
		"Muted powerups retain visual feedback while positive feedback and narration remain silent")
	_drain(view)
	check(view.game.collectable_ids().size() == 1 and app.coin_wallet.balance == before - 2000,
		"Mute and reduced motion preserve the automatic action and exact purchase amount")
	view.powerup_buttons.fragments.pressed.emit()
	_drain(view)
	var any_audio: bool = app.audio.pair_feedback.playing
	for player: AudioStreamPlayer in app.audio._jelly_players:
		any_audio = any_audio or player.playing
	check(not any_audio and _carried_fragments(view.game) >= 1,
		"Muted fragment delivery remains visible and complete without assembly audio")
	app.set_reduced_motion(false)
	app.audio.set_muted(false)


func _check_responsive_actions(app) -> void:
	await _prepare(app)
	var view = app._word_jelly
	for dimensions: Vector2i in [Vector2i(1473, 1175), Vector2i(1000, 720), Vector2i(768, 1024), Vector2i(393, 852), Vector2i(320, 480), Vector2i(568, 320)]:
		root.size = dimensions
		await settle()
		view.set_process(false)
		view._process(0.0)
		var scale: float = app.Style.ui_scale(app)
		var buttons: Array = [view.powerup_buttons.auto_merge, view.collect_button, view.powerup_buttons.fragments]
		var context: String = " at " + str(dimensions)
		for index in range(buttons.size()):
			var button = buttons[index]
			var bounds: Rect2 = button.get_global_rect()
			check(button.is_visible_in_tree() and view.get_global_rect().grow(0.1).encloses(bounds)
				and bounds.size.x * scale >= 44.0 - 0.1 and bounds.size.y * scale >= 44.0 - 0.1,
				"All three gameplay actions fit with full touch targets" + context)
			check(not bounds.intersects(view._global_rect(view._board)) and not bounds.intersects(view.drop_button.get_global_rect())
				and not bounds.intersects(view._loot_meter.get_global_rect()) and not bounds.intersects(view.finish_button.get_global_rect()),
				"Powerups and Collect remain separate from the board, supply, chest, and Finish" + context)
			for previous in range(index):
				check(not bounds.intersects(buttons[previous].get_global_rect()), "The three action targets never overlap" + context)
		check(view.powerup_buttons.auto_merge.snapshot().get("price", 0) == 2000
			and view.powerup_buttons.fragments.snapshot().get("price", 0) == 500,
			"Responsive powerup buttons retain their exact visible price metadata" + context)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 800)
	var directory: String = "user://word-jelly-powerups-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	Fixture.enter_mode(app, "match")
	var view = app._word_jelly
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	view.game.powerup_feedback.connect(func(kind: String, success: bool) -> void: purchases.append({"kind": kind, "success": success}))
	view.game.powerup_fragment_arrived.connect(func(event: Dictionary) -> void: arrivals.append(event))
	await _check_insufficient(app)
	check(app.coin_wallet.credit("fixture:powerup-funding", 1000).ok, "Fund the isolated wallet through the real credit API")
	app._coin_flight.sync(app.coin_wallet.balance)
	await _check_auto_merge(app)
	await _check_storage_failure(app)
	await _check_fragments(app)
	await _check_fragment_coarse_frame(app)
	await _check_lifecycle(app)
	await _check_preferences(app)
	await _check_responsive_actions(app)
	var balance: int = app.coin_wallet.balance
	var receipts: Dictionary = app.coin_wallet._receipts.duplicate()
	var reloaded := Wallet.new(directory + "/coins.cfg")
	check(reloaded.load_state() and reloaded.balance == balance and reloaded._receipts == receipts,
		"Application purchases preserve the exact final coin balance and every receipt across native reload")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly Words powerup flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
