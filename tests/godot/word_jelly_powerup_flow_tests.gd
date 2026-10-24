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
	var fixture_words: Array = app._learning_words().filter(func(item: Dictionary) -> bool:
		return str(item.text).length() >= 3 and str(item.text).length() <= 6 and not str(item.get("image", "")).is_empty()).slice(0, pairs)
	check(fixture_words.size() == pairs, "Every automatic fixture pair has a distinct current-age word")
	check(view.configure(fixture_words, app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, false, round_seed),
		"The powerup board uses distinct pictured current-age words")
	Fixture.unlock_auto_collect(app)
	app._sync_jelly()
	view.set_process(false)
	var game = view.game
	game.spawn_interval = 10000.0
	game.cells.clear()
	for index in range(pairs * 2):
		var word: Dictionary = fixture_words[index / 2]
		var tile: Dictionary = game._new_word_root(word) if index % 2 == 0 else game._new_picture_tile(word)
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
	var saved: Variant = app.coin_wallet._saved_text
	for kind: String in ["auto_merge", "fragments"]:
		var board: Array = game.cells.duplicate(true)
		var button = view.powerup_buttons[kind]
		var price: int = game.powerup_price(kind)
		check(button.is_visible_in_tree() and not button.disabled, "An unaffordable " + kind + " remains available for meaningful feedback")
		button.pressed.emit()
		check(game.cells == board and game.fusions.is_empty()
			and not game.powerup_active() and game.collected_coins == 0 and game.fragment_count == 0,
			"An unfunded " + kind + " changes no jelly, reward, or fragment state")
		check(app.coin_wallet.balance == 0 and app.coin_wallet._saved_text == saved
			and app.coin_wallet.ready and app.coin_wallet.error.is_empty() and app._coin_counter.available,
			"Insufficient funds leave wallet storage and the visible coin counter available")
		check(purchases.back() == {"kind": kind, "success": false} and cues.back() == "powerup_wrong",
			"An unfunded button produces one negative purchase response")
		check(game.powerup_price(kind) == price and button.snapshot().price == price
			and game.snapshot().powerup_uses[kind] == 0,
			"An unfunded purchase keeps its current quoted price and first-use tier")
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
		and app.coin_wallet.balance == before - 600 and app.coin_wallet._receipts.size() == receipts + 1,
		"The Auto merge button durably pays once before starting a visible automatic drag")
	check(cues.count("powerup_success") == 1 and purchases == [{"kind": "auto_merge", "success": true}]
		and app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[true]),
		"A saved purchase starts the positive response and its existing sound")
	check(view.collect_button.disabled and view.powerup_buttons.auto_merge.disabled and view.powerup_buttons.fragments.disabled,
		"The automatic sequence reserves all three gameplay action buttons")
	view.powerup_buttons.auto_merge.pressed.emit()
	view.powerup_buttons.fragments.pressed.emit()
	check(app.coin_wallet.balance == before - 600 and app.coin_wallet._receipts.size() == receipts + 1,
		"Repeated button signals during a paid sequence cannot buy another action")
	var from: Vector2 = view._tile_rect(state.source).get_center()
	var to: Vector2 = view._tile_rect(state.target).get_center()
	view._process(game.POWERUP_DRAG_SECONDS * 0.5)
	var halfway: Vector2 = view._tiles[int(state.source_id)].get_rect().get_center()
	check(halfway.distance_to(from) > 2.0 and halfway.distance_to(to) > 2.0
		and halfway.x > minf(from.x, to.x) and halfway.x < maxf(from.x, to.x)
		and view._powerup_effects.stamps.size() > 0 and game.fusions.is_empty(),
		"The source jelly travels through an intermediate position with light effects before union")
	view._process(game.POWERUP_DRAG_SECONDS * 0.25)
	var traveling: Dictionary = game.powerup_snapshot()
	check(traveling.drags.size() == 1 and game.fusions.is_empty()
		and int(traveling.drags[0].source_id) == int(state.source_id)
		and is_equal_approx(float(traveling.drags[0].elapsed), game.POWERUP_DRAG_SECONDS * 0.75),
		"At 187.5 ms the reserved first pair is still traveling within its 250 ms drag")
	view._process(game.POWERUP_MERGE_BEAT_SECONDS - game.POWERUP_DRAG_SECONDS * 0.75)
	var overlapping: Dictionary = game.powerup_snapshot()
	check(overlapping.drags.size() == 2 and game.fusions.is_empty(),
		"At 200 ms the second paid flight starts while the first continues toward its target")
	var following: Dictionary = overlapping.drags[1] if overlapping.drags.size() == 2 else {}
	if not following.is_empty():
		check(is_zero_approx(float(overlapping.drags[0].started_at))
			and is_equal_approx(float(following.started_at), 0.20)
			and int(following.source_id) not in [int(state.source_id), int(state.target_id)]
			and int(following.target_id) not in [int(state.source_id), int(state.target_id)],
			"overlapping launches have independent clocks and reserve four distinct endpoints")
	view._process(game.POWERUP_DRAG_SECONDS - game.POWERUP_MERGE_BEAT_SECONDS)
	var after_contact: Dictionary = game.powerup_snapshot()
	check(game.fusions.size() == 1 and after_contact.drags.size() == 1 and after_contact.stage == "drag",
		"At 250 ms the first pair starts its 110 ms fusion while the second flight continues")
	var first_result_id: int = int(game.fusions[0].result.id)
	view._process(0.05)
	check(game.fusions.size() == 1 and game.powerup_snapshot().drags.size() == 1,
		"an in-progress fusion retains its endpoints without blocking the other flight")
	if not following.is_empty():
		following = game.powerup_snapshot().drags[0]
		var next_from: Vector2 = view._tile_rect(following.source).get_center()
		var next_to: Vector2 = view._tile_rect(following.target).get_center()
		view._process(maxf(0.0, game.POWERUP_DRAG_SECONDS * 0.5 - float(following.elapsed)))
		var next_halfway: Vector2 = view._tiles[int(following.source_id)].get_rect().get_center()
		check(next_halfway.distance_to(next_from) > 2.0 and next_halfway.distance_to(next_to) > 2.0
			and view._powerup_effects.stamps.size() > 0 and game.fusions.size() == 1,
			"the second source reaches its own halfway point while the first fusion remains visible")
		view._process(0.065)
		check(game.is_settled(game.cell(first_result_id)) and game.powerup_snapshot().drags.size() == 1,
			"the first result settles while the second flight completes its independent 250 ms journey")
	_drain(view)
	check(game.cells.size() == 2 and game.collectable_ids().size() == 2 and int(game.powerup_snapshot().completed) == 2,
		"One automatic purchase completes both distinct word-picture pairs on the captured board")
	check(game.collected_coins == 0 and game.fragment_count == 0 and game.cleared_pairs == 0
		and app.coin_wallet.balance == before - 600 and app.growth.snapshot().streaks == growth
		and not app._coin_flight.snapshot().active,
		"Automatic merging leaves words for manual collection without rewards, mastery, or coin flights")
	check(not app.audio.voice.playing,
		"Completed automatic merges neither pronounce words nor queue delayed narration")
	check(not view.collect_button.disabled and not view.powerup_buttons.fragments.disabled,
		"The three-action area returns control after the paid sequence")
	var saved_receipts: Dictionary = app.coin_wallet._receipts.duplicate()
	var saved_text: String = app.coin_wallet._saved_text
	var stale: Dictionary = app._purchase_word_jelly_powerup(str(state.receipt_id) + ":stale", "auto_merge", 600)
	check(not bool(stale.get("ok", false)) and app.coin_wallet.balance == before - 600
		and app.coin_wallet._receipts == saved_receipts and app.coin_wallet._saved_text == saved_text
		and game.snapshot().powerup_uses.auto_merge == 1 and game.powerup_price("auto_merge") == 900,
		"A new receipt cannot reuse the stale first-purchase price after the next price rises")
	var mismatched: Dictionary = app._purchase_word_jelly_powerup(str(state.receipt_id), "auto_merge", 900)
	check(not bool(mismatched.get("ok", false)) and app.coin_wallet.balance == before - 600
		and app.coin_wallet._receipts == saved_receipts and app.coin_wallet._saved_text == saved_text
		and game.snapshot().powerup_uses.auto_merge == 1 and game.powerup_price("auto_merge") == 900
		and not game.powerup_active(),
		"An old receipt with the new higher amount is rejected without spending or advancing its price tier")
	var duplicate: Dictionary = app._purchase_word_jelly_powerup(str(state.receipt_id), "auto_merge", 600)
	check(bool(duplicate.ok) and bool(duplicate.duplicate) and int(duplicate.amount) == 0
		and app.coin_wallet.balance == before - 600 and app.coin_wallet._receipts.size() == receipts + 1,
		"Repeating an already-paid application callback preserves the exact wallet balance and receipt count")
	check(app._status_announcement.contains("already processed") and not app._status_announcement.contains("purchased for")
		and purchases.size() == 1 and cues.count("powerup_success") == 1 and not game.powerup_active(),
		"An idempotent purchase callback never announces or animates a second successful purchase")
	check(game.powerup_price("auto_merge") == 900 and view.powerup_buttons.auto_merge.snapshot().price == 900,
		"A duplicate callback keeps the already-earned next price without another increase")


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
	check(view.game.powerup_price("fragments") == 200 and view.powerup_buttons.fragments.snapshot().price == 200,
		"An unsaved purchase does not consume the lower first-use price")
	check(DirAccess.remove_absolute(staging) == OK, "Restore the wallet staging path for purchase recovery")
	view.powerup_buttons.fragments.pressed.emit()
	check(app.coin_wallet.balance == before - 200 and app._coin_counter.available and view.game.powerup_active(),
		"The same button recovers verified storage and starts one paid powerup after saving succeeds")
	_drain(view)
	check(app.coin_wallet._receipts.size() == receipts.size() + 1 and cues.count("powerup_success") == 1,
		"Storage retry creates exactly one debit and one successful action")
	check(view.game.powerup_price("fragments") == 300 and view.powerup_buttons.fragments.snapshot().price == 300,
		"Only the recovered successful payment advances the visible price")


func _check_escalating_prices(app) -> void:
	await _prepare(app, 1)
	var view = app._word_jelly
	var game = view.game
	var pieces: Array = game.cells.duplicate(true)
	var expected: Dictionary = {"auto_merge": [600, 900, 1200, 1200], "fragments": [200, 300, 400, 400]}
	for index in range(4):
		for kind: String in ["auto_merge", "fragments"]:
			game.cells.assign(pieces.duplicate(true))
			view._sync_tiles()
			view._process(0.0)
			var price: int = expected[kind][index]
			var button = view.powerup_buttons[kind]
			check(not button.disabled and button.snapshot().price == price
				and button.snapshot().price_text == str(price), "The next round-local price is visible before purchase")
			var before: int = app.coin_wallet.balance
			var receipt_count: int = app.coin_wallet._receipts.size()
			button.pressed.emit()
			check(game.powerup_active() and app.coin_wallet.balance == before - price
				and app.coin_wallet._receipts.size() == receipt_count + 1,
				"The full application charges exactly the currently displayed price")
			_drain(view)
			var next: int = expected[kind][mini(index + 1, 3)]
			check(button.snapshot().price == next and game.powerup_price(kind) == next
				and game.snapshot().powerup_uses[kind] == index + 1,
				"The button and model show the same independently escalating capped price")
	await _prepare(app, 1)
	check(view.powerup_buttons.auto_merge.snapshot().price == 600 and view.powerup_buttons.fragments.snapshot().price == 200,
		"Starting a new round resets both displayed prices")


func _check_fragments(app) -> void:
	await _prepare(app)
	var view = app._word_jelly
	var game = view.game
	var before: int = app.coin_wallet.balance
	view.powerup_buttons.fragments.pressed.emit()
	var state: Dictionary = game.powerup_snapshot()
	check(state.active and state.kind == "fragments" and int(state.total) >= 2 and int(state.total) <= 8
		and app.coin_wallet.balance == before - 200 and _carried_fragments(game) == 0,
		"Treasure purchases reserve two to eight fragment arrivals for the exact 200-coin price")
	check(cues.count("powerup_fragment_launch") == 1 and app.audio._fragment_players[0].playing
		and app.audio._fragment_players[0].stream == load(app.audio.FRAGMENT_APPEAR_PATH),
		"The first Treasure fragment plays its appearance recording when its flight starts")
	view._process(game.POWERUP_FRAGMENT_FLIGHT * 0.5)
	check(view._powerup_effects.stamps.size() > 0 and _carried_fragments(game) == 0,
		"Treasure art flies toward the board before any fragment is attached")
	view._process(game.POWERUP_FRAGMENT_FLIGHT * 0.5 + 0.001)
	check(arrivals.size() == 1 and _carried_fragments(game) == 1 and cues.count("powerup_fragment") == 1,
		"The first visible arrival attaches exactly one fragment and triggers its arrival cue")
	var arrived_id: int = int(arrivals[0].tile_id)
	check(view._tiles[arrived_id].visible_fragment_badges() == 1 and not view._powerup_arrivals.is_empty()
		and view._powerup_effects.stamps.size() > 0, "The destination shows its new fragment badge with an arrival flash")
	var arrival_playing: bool = false
	for player: AudioStreamPlayer in app.audio._fragment_players:
		arrival_playing = arrival_playing or (player.playing and player.stream == load(app.audio.FRAGMENT_ARRIVE_PATH))
	check(arrival_playing, "Fragment arrival plays its distinct acquired recording on the fragment channel")
	_drain(view)
	check(_carried_fragments(game) == int(state.total) and arrivals.size() == int(state.total)
		and cues.count("powerup_fragment") == int(state.total) and game.fragment_count == 0
		and game.chest_count == 0 and game.collected_coins == 0 and app.coin_wallet.balance == before - 200,
		"All purchased fragments remain on jelly bodies until collection, with one arrival event each and no immediate chest payout")
	for tile: Dictionary in game.cells:
		var badge: Dictionary = view._tiles[int(tile.id)].fragment_badge_snapshot()
		check(view._tiles[int(tile.id)].visible_fragment_badges() == mini(2, int(tile.fragments))
			and str(badge.count_text) == (str(tile.fragments) if int(tile.fragments) > 2 else ""),
			"Every purchased fragment is represented by a bounded chest stack and its exact total")


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


func _check_fragment_repeated_purchases(app) -> void:
	await _prepare(app)
	var view = app._word_jelly
	var game = view.game
	check(app.coin_wallet.spend("fixture:treasure-repeat-budget", app.coin_wallet.balance - 500).ok,
		"Reserve exactly enough real coins for two immediate Treasure purchases")
	app._coin_flight.sync(app.coin_wallet.balance)
	view._process(0.0)
	var receipts: int = app.coin_wallet._receipts.size()
	var button = view.powerup_buttons.fragments
	button.pressed.emit()
	var first: Dictionary = game.powerup_snapshot()
	check(not button.disabled and not button.snapshot().busy and button.snapshot().price == 300
		and view.powerup_buttons.auto_merge.disabled and app.coin_wallet.balance == 300,
		"Treasure immediately shows its next price and remains tappable while Auto merge stays reserved")
	view._process(0.10)
	button.pressed.emit()
	var combined: Dictionary = game.powerup_snapshot()
	check(not button.disabled and not button.snapshot().affordable and button.snapshot().price == 400
		and app.coin_wallet.balance == 0 and app.coin_wallet._receipts.size() == receipts + 2
		and combined.receipt_id == first.receipt_id and is_equal_approx(float(combined.elapsed), 0.10),
		"A second click pays the displayed 300 coins and appends delivery without resetting the first flight")
	check(int(combined.total) >= int(first.total) + 2 and int(combined.total) <= int(first.total) + 8
		and _carried_fragments(game) == 0 and view._powerup_effects.stamps.size() > 0,
		"Both paid batches retain visible flight effects before their markers arrive")
	view._process(0.05)
	var before_failure: Dictionary = game.powerup_snapshot()
	button.pressed.emit()
	check(game.powerup_snapshot() == before_failure and app.coin_wallet.balance == 0
		and app.coin_wallet._receipts.size() == receipts + 2 and button.snapshot().price == 400
		and not button.snapshot().feedback_success and cues.count("powerup_wrong") == 1
		and cues.count("powerup_success") == 2,
		"An unfunded rapid third click gives negative feedback without disturbing either accepted purchase")
	check(app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[false]),
		"An unfunded repeat plays the negative recording even during earlier Treasure flights")
	view.pause(true)
	view._process(0.40)
	check(game.powerup_snapshot() == before_failure and view._powerup_arrivals.is_empty(),
		"Pausing overlapping Treasure purchases freezes both animation timelines")
	view.pause(false)
	view._process(0.50)
	var delivered: Array = game.powerup_snapshot().arrivals.filter(func(item: Dictionary) -> bool:
		return float(item.at) <= 0.65 + game.EPSILON)
	check(arrivals.size() == delivered.size() and view._powerup_arrivals.size() == delivered.size()
		and _carried_fragments(game) == delivered.size(),
		"One slow frame preserves every interleaved marker and arrival flash from both purchases")
	for index in range(mini(arrivals.size(), view._powerup_arrivals.size())):
		var event: Dictionary = arrivals[index]
		var flash: Dictionary = view._powerup_arrivals[index]
		check(int(flash.index) == int(event.index) and absf(float(flash.elapsed) - (0.65 - float(event.at))) < 0.001,
			"Each overlapping arrival flash keeps its exact deadline instead of using another receipt's array position")
	_drain(view)
	check(_carried_fragments(game) == int(combined.total) and arrivals.size() == int(combined.total)
		and cues.count("powerup_fragment") == int(combined.total)
		and app.coin_wallet.balance == 0 and app.coin_wallet._receipts.size() == receipts + 2,
		"Both paid batches finish once with their original marker sounds and no extra debit")
	check(app.coin_wallet.credit("fixture:after-treasure-repeat-budget", 1000).ok,
		"Restore ordinary fixture funds through a distinct valid chest receipt")
	app._coin_flight.sync(app.coin_wallet.balance)


func _check_lifecycle(app) -> void:
	await _prepare(app, 2)
	var view = app._word_jelly
	var game = view.game
	var before: int = app.coin_wallet.balance
	view.powerup_buttons.auto_merge.pressed.emit()
	view._process(0.225)
	var paused: Dictionary = game.powerup_snapshot()
	check(paused.drags.size() == 2 and game.fusions.is_empty(), "Home interruption preserves both overlapping paid flights")
	app._show_mode_menu()
	view._process(0.40)
	check(game.paused and game.powerup_snapshot() == paused, "Home freezes the paid automatic drag clock")
	check(not view._powerup_effects.is_visible_in_tree(), "Home hides paid automatic drag effects")
	check(not app.audio.pair_feedback.playing, "Home stops purchase feedback audio")
	app._hide_mode_menu()
	view.set_process(false)
	check(not game.paused and game.powerup_snapshot() == paused and app.coin_wallet.balance == before - 600
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
	check(app.coin_wallet.balance == before - 600 and cues.count("powerup_success") == 1,
		"Home and Finish interruptions do not replay purchase feedback or charge again")
	await _prepare(app, 1)
	game = view.game
	before = app.coin_wallet.balance
	view.powerup_buttons.fragments.pressed.emit()
	view._process(0.1)
	view.powerup_buttons.fragments.pressed.emit()
	var total: int = int(game.powerup_snapshot().total)
	view.finish_button.accessibility_requested.emit()
	check(app._finish_confirmation_open(), "Finish confirms before ending a purchased fragment flight")
	app._finish_confirmation.finish_button.pressed.emit()
	check(game.phase == "finished" and not game.powerup_active() and _carried_fragments(game) == total
		and game.collected_coins == 0 and game.fragment_count == 0 and app.coin_wallet.balance == before - 500,
		"Confirmed Finish settles both repeated purchases without automatic collection or another charge")


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
	check(view.game.collectable_ids().size() == 1 and app.coin_wallet.balance == before - 600,
		"Mute and reduced motion preserve the automatic action and exact purchase amount")
	view.powerup_buttons.fragments.pressed.emit()
	_drain(view)
	var any_audio: bool = app.audio.pair_feedback.playing
	for player: AudioStreamPlayer in app.audio._jelly_players:
		any_audio = any_audio or player.playing
	for player: AudioStreamPlayer in app.audio._fragment_players:
		any_audio = any_audio or player.playing
	check(not any_audio and _carried_fragments(view.game) >= 1,
		"Muted fragment delivery remains visible and complete without fragment audio")
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
		check(view.powerup_buttons.auto_merge.snapshot().get("price", 0) == 600
			and view.powerup_buttons.fragments.snapshot().get("price", 0) == 200,
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
	await _check_escalating_prices(app)
	await _check_fragments(app)
	await _check_fragment_coarse_frame(app)
	await _check_fragment_repeated_purchases(app)
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
