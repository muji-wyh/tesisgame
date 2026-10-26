extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func make_model(seconds: float = 90.0, challenge: bool = false):
	var plan: Dictionary = Catalog.make_plan(0 if challenge else 1, words, 3, 71, challenge)
	plan.seconds = 0.0 if challenge else seconds
	var model = Model.new()
	model.allow_cross_age = true
	var selected: Array = plan.words.slice(0, 3) if challenge else plan.words
	check(model.configure(selected, 3, 71) and model.bind_stage(plan), "Bind an actual campaign attempt to normal Jelly physics")
	model.cells.clear()
	model.spawn_elapsed = 0.0
	return model


func put(model, tile: Dictionary, column: int) -> Dictionary:
	tile.column = column
	tile.row = 7
	tile.age = 100.0
	tile.falling = false
	tile.arrival = false
	tile.settling = false
	model.cells.append(tile)
	return tile


func ready_word(model, word: Dictionary, column: int, level: int = 1) -> Dictionary:
	var tile: Dictionary = model._new_word_root(word, 1)
	model._set_merged_word(tile, word, level, true)
	return put(model, tile, column)


func advance_until_ended(model) -> void:
	for index in range(500):
		if model.phase == "finished":
			return
		model.step(0.05)
	check(false, "A bounded campaign end sweep must finish without an infinite wait: " + model.error)


func test_clear_sweep() -> void:
	var model = make_model()
	for index in range(model.stage_run.words.size()):
		ready_word(model, model.stage_run.words[index], index)
	var extra: Dictionary = ready_word(model, model.stage_run.words[0], 4)
	for word: Dictionary in model.stage_run.words:
		var tile: Dictionary = model.cells.filter(func(item: Dictionary) -> bool:
			return item.word.id == word.id and item.id != extra.id)[0]
		check(model.collect(int(tile.id)), "A goal word is deliberately collected")
		model.step(Model.COLLECT_SECONDS + 0.02)
	check(model.stage_run.outcome == "cleared", "All committed per-word quotas decide a clear before cleanup")
	check(not model.collect(int(extra.id)) and not model.drop_now(),
		"A decided stage blocks new manual actions while its sweep owns the board")
	model.step(0.20)
	check(model.phase == "playing",
		"The final goal has time for its short success cue before the end presentation takes over")
	advance_until_ended(model)
	check(model.collectable_ids().is_empty() and model.cleared_pairs == 4 and model.fragment_count == 4,
		"Clearing automatically gathers every leftover merged word, even below the normal Auto Collect unlock")
	var result: Dictionary = model.finish_round()
	check(result.get("campaign", {}).get("outcome") == "cleared" and result.campaign.stars == 3
		and result.campaign.current.values().all(func(value: int) -> bool: return value == 1),
		"The final result keeps exact pre-sweep objectives and the original timed star rating")


func test_timeout_and_retry() -> void:
	var model = make_model(0.12)
	var first: Dictionary = ready_word(model, model.stage_run.words[0], 0)
	var second: Dictionary = ready_word(model, model.stage_run.words[1], 1)
	model.step(0.12)
	check(model.stage_run.outcome == "timeout", "The actual active-play deadline decides failure exactly at zero")
	advance_until_ended(model)
	check(model.cleared_pairs == 2 and model.stage_run.current.values().all(func(value: int) -> bool: return value == 0)
		and model.finish_round().campaign.stars == 0,
		"Failure cleanup collects its two words without filling goals or inventing a clear")
	model = make_model(0.01)
	var paid: Dictionary = ready_word(model, model.stage_run.words[0], 0, 9)
	model._coin_rng.seed = 0
	model._collection_event_ids[int(paid.id)] = "sweep:paid"
	model._collection_coin_rewards["sweep:paid"] = 450
	var writable: Array[bool] = [false]
	var receipts: Array[String] = []
	model.credit_collection = func(id: String, _amount: int) -> Dictionary:
		receipts.append(id)
		return {"ok": writable[0], "error": "Expected test save failure"}
	model.step(1.0)
	check(model.phase == "playing" and model.stage_ending() and not model.error.is_empty()
		and not model.cell(int(paid.id)).is_empty() and model.fragment_count == 0,
		"A failed sweep payout remains recoverable instead of deleting its body or pretending completion")
	var before: int = receipts.size()
	model.step(1.0)
	check(receipts.size() == before, "An end sweep waits for explicit save retry instead of hammering failed storage")
	writable[0] = true
	model.retry_stage_finish()
	advance_until_ended(model)
	check(model.collected_coins == 450 and receipts.size() == 2 and receipts[0] == receipts[1]
		and model.stage_run.outcome == "timeout",
		"The retry keeps the failed outcome, original pickup receipt and exact reward")
	model.credit_collection = Callable()


func test_timer_pause_and_extra_time() -> void:
	var model = make_model(90.0)
	model.set_paused(true)
	model.step(10.0)
	check(model.stage_run.remaining == 90.0, "Explicit pause consumes no stage clock")
	model.set_paused(false)
	model.step(29.0)
	check(is_equal_approx(model.stage_run.remaining, 61.0) and model.stage_run.stars_now() == 3,
		"The live model advances the domain clock only during active play")
	var attempts: Array = []
	model.purchase_powerup = func(id: String, kind: String, price: int) -> Dictionary:
		attempts.append([id, kind, price])
		return {"ok": true}
	model.cells.clear()
	check(model.activate_powerup("extra_time") and model.powerup_price("extra_time") == 150
		and is_equal_approx(model.stage_run.remaining, 91.0) and attempts[0][2] == 100,
		"A saved first extra-time purchase adds 30 seconds and increases the next price")
	model.step(2.0)
	check(model.stage_run.stars_now() == 2, "Bought time never restores an expired original star tier")
	check(model.activate_powerup("extra_time") and attempts[1][2] == 150 and model.powerup_price("extra_time") == 200,
		"Every paid extension increases its own price rather than capping after two uses")
	model.stage_run._added_seconds = model.stage_run.MAX_ADDED_SECONDS - 30
	check(model.activate_powerup("extra_time") and attempts.size() == 3,
		"The final supported extension can still be purchased and applied")
	check(not model.can_activate_powerup("extra_time") and not model.activate_powerup("extra_time")
		and attempts.size() == 3,
		"An exhausted extension allowance disables the item before any payment is attempted")
	model.purchase_powerup = Callable()


func test_challenge_pressure_and_blocked_top() -> void:
	var model = make_model(0.0, true)
	for index in range(10):
		model.cells.clear()
		var tile: Dictionary = ready_word(model, model.stage_run.words[0], 0)
		check(model.collect(int(tile.id)), "Untimed challenge accepts a committed pickup")
		model.step(Model.COLLECT_SECONDS)
	check(model.stage_run.outcome.is_empty() and model.stage_run.challenge_pressure().level == 2
		and model._words.size() == 4 and model.fall_speed_scale > 1.0 and model.spawn_interval < 20.0,
		"Challenge progression really changes active supply variety, incoming speed and cadence")
	check(not model.can_activate_powerup("extra_time"), "A no-timer challenge cannot charge for extra time")
	model.cells.clear()
	for index in range(Model.CAPACITY):
		var tile: Dictionary = model._new_word_root(model.stage_run.words[0])
		tile.column = index % Model.COLUMNS
		tile.row = index / Model.COLUMNS
		tile.age = 100.0
		tile.settling = false
		tile.arrival = false
		model.cells.append(tile)
	model.step(0.01)
	check(model.phase == "playing" and model.stage_run.outcome.is_empty() and model.full_elapsed >= 0.0,
		"A full challenge starts the flashing danger countdown instead of failing immediately")
	model.step(Model.FULL_SECONDS - 0.1)
	check(model.phase == "playing" and model.stage_run.outcome.is_empty(),
		"The board remains playable throughout the ten-second warning")
	model.step(0.1)
	check(model.phase == "finished" and model.stage_run.outcome == "blocked"
		and model.finish_round().campaign.stars == 0,
		"An expired full-board countdown ends through the normal failed campaign sweep")


func test_main_stage_full_warning() -> void:
	var model = make_model()
	for index in range(Model.CAPACITY):
		var tile: Dictionary = model._new_word_root(model.stage_run.words[0])
		tile.column = index % Model.COLUMNS
		tile.row = index / Model.COLUMNS
		tile.age = 100.0
		tile.settling = false
		model.cells.append(tile)
	model.step(0.01)
	check(model.phase == "playing" and model.stage_run.outcome.is_empty()
		and model.full_elapsed >= 0.0 and model.stage_run.remaining < 90.0,
		"A numbered stage keeps its independent countdown while the full-board warning starts")
	model.step(3.0)
	var warning: float = model.full_elapsed
	var deadline: float = model.stage_run.remaining
	model.set_paused(true)
	model.step(20.0)
	check(model.full_elapsed == warning and model.stage_run.remaining == deadline,
		"Explicit pause freezes both the stage deadline and full-board warning")
	model.set_paused(false)
	model.cells.pop_front()
	model.step(0.01)
	check(model.full_elapsed < 0.0 and model.stage_run.outcome.is_empty(),
		"Making room cancels the warning without ending the stage")


func test_full_board_pending_collection() -> void:
	var model = make_model()
	var pickup: Dictionary = ready_word(model, model.stage_run.words[0], Model.COLUMNS - 1)
	for index in range(Model.CAPACITY - 1):
		var tile: Dictionary = model._new_word_root(model.stage_run.words[0])
		tile.column = index % Model.COLUMNS
		tile.row = index / Model.COLUMNS
		tile.age = 100.0
		tile.settling = false
		tile.arrival = false
		model.cells.append(tile)
	model.cells[1].age = Model.SETTLE_SECONDS - 0.02
	model.cells[1].settling = true
	check(model.collect(int(pickup.id)), "A collection can begin while the last entrance tile finishes landing")
	model.step(1.0)
	check(model.cleared_pairs == 1 and model.cell(int(pickup.id)).is_empty()
		and model.stage_run.outcome.is_empty(),
		"A full entrance advances its pending collection and rescuing gravity instead of freezing or failing early")


func _run() -> void:
	var probe = Model.new()
	check(probe.has_method("bind_stage") and probe.has_method("retry_stage_finish"),
		"Jelly physics exposes optional campaign binding and recoverable end sweeps")
	if failures:
		print("Jelly campaign model: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	var data := Data.new()
	check(data.load_all(), "Campaign uses reviewed real game vocabulary")
	words = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3) \
		.map(func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	var browser_words: Array = words.filter(func(word: Dictionary) -> bool: return str(word.id) in ["cat", "dog", "duck"])
	var browser_recipe: Dictionary = Catalog.to_recipe(Catalog.make_plan(1, browser_words, 3, 71))
	check(browser_recipe.identities == {
		"cat": "a4208d2c8e0f08ed8403187f69dd03a9b7981346ebd4a1b1e007ca4f2af68678",
		"dog": "90fcaf7bd13303e2356c1abaf395485216d12aa30e7878aa85aa6efa63dc498a",
		"duck": "be7067beca171f75cc3fd7608a03cba9accc4982492b38dd912ad9082340535c"},
		"The real catalog accepts the same immutable reviewed identities as saved browser replay fixtures")
	if OS.get_cmdline_user_args().has("--blocked-collection-only"):
		test_full_board_pending_collection()
		print("Jelly pending collection: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	test_clear_sweep()
	test_timeout_and_retry()
	test_timer_pause_and_extra_time()
	test_challenge_pressure_and_blocked_top()
	test_main_stage_full_warning()
	test_full_board_pending_collection()
	print("Jelly campaign model: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
