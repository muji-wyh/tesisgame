extends SceneTree
## Delayed age packs and settled pickups preserve the same staged learning round.

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Loader = preload("res://scripts/vocabulary_loader.gd")
const Growth = preload("res://scripts/growth_state.gd")
const Stages = preload("res://scripts/word_jelly_stages.gd")

var checks: int = 0
var failures: int = 0
var directories: Array[String] = []


class DownloadHost extends RefCounted:
	var requests: Array[int] = []
	var callbacks: Dictionary = {}

	func requestVocabulary(age: int, callback: Callable) -> void:
		requests.append(age)
		callbacks[age] = callback

	func reply(age: int, state: String) -> void:
		assert(callbacks.has(age), "Only a requested age may complete in this fixture.")
		callbacks[age].call([JSON.stringify({"age": age, "state": state,
			"progress": 1.0 if state == "ready" else 0.0,
			"path": "/vocabulary-%d-0123456789abcdef.pck" % age,
			"error": "This download was interrupted. Please try again." if state == "failed" else ""})])


class DelayedLoader extends Loader:
	var downloads := DownloadHost.new()

	func configure(_host_override: Object = null, _mount_override: Callable = Callable()) -> void:
		super.configure(downloads, func(_path: String, replace: bool) -> bool:
			assert(not replace, "A later age must preserve the earlier round's resources.")
			return true)


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(5):
		await process_frame


func _cohort(app, age: int) -> Array:
	return app.data.words.filter(func(word: Dictionary) -> bool: return int(word.min_age) == age).map(
		func(word: Dictionary) -> String: return str(word.id))


func _make_app(mixed_ages: bool = false):
	var directory: String = "user://jelly-stage-loading-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Create isolated stage loading saves")
	directories.append(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	check(app._presentation.save_preferences(), "Keep the asynchronous loading fixture muted")
	app.vocabulary_loader.free()
	app.vocabulary_loader = DelayedLoader.new()
	if mixed_ages:
		check(app.data.load_all() and app.growth.configure(app.data.words) and app.growth.load_state(),
			"Load real vocabulary before seeding two nearly mastered cohorts")
		for age in [3, 4]:
			var learned: Array = _cohort(app, age).slice(5)
			for attempt in range(Growth.MASTERY_STREAK):
				check(app.growth.record_attempt("seed-%d-%d" % [age, attempt], learned, true, true).save_ok,
					"Seed durable mastery while leaving five targets in each age")
	root.add_child(app)
	await _settle()
	app.audio.set_muted(true)
	app.set_process(false)
	app._word_jelly.set_process(false)
	return app


func _dispose(app) -> void:
	if root.get_tree().paused:
		app._cancel_vocabulary_round()
	app.audio.halt()
	app.queue_free()
	await _settle()


func _master(app, ids: Array, prefix: String) -> void:
	for attempt in range(Growth.MASTERY_STREAK):
		app._record_growth("%s-%d" % [prefix, attempt], ids, true)


func _loading_and_background() -> void:
	var app = await _make_app(true)
	var host = app.vocabulary_loader.downloads
	app.choose_mode("word_jelly")
	check(host.requests.has(3) and app._vocabulary_prompt.visible and app._word_jelly_stages == null,
		"Starting mixed-age Jelly waits for the first required media pack")
	host.reply(3, "ready")
	await _settle()
	check(app._pending_vocabulary_age == 4 and host.requests.has(4)
		and app._word_jelly_stages == null and app._vocabulary_prompt.visible,
		"The same start action then waits for the selected future-age words")
	host.reply(4, "failed")
	check(app._vocabulary_retry.visible and app._word_jelly_stages == null,
		"A future-age failure never builds a partially loaded stage")
	app._retry_vocabulary()
	check(host.requests.count(4) == 2, "Retry requests precisely the missing future-age pack again")
	host.reply(4, "ready")
	await _settle()
	var view = app._word_jelly
	check(app._word_jelly_stages != null and not app._vocabulary_prompt.visible and not view.game.paused,
		"Both mounted packs start one playable stage")
	if app._word_jelly_stages == null:
		await _dispose(app)
		return
	var first: Array = app._word_jelly_stages.snapshot().word_ids
	check(first.size() == 10 and app._word_jelly_stages.words.filter(
		func(word: Dictionary) -> bool: return int(word.min_age) == 3).size() == 5,
		"The actual initial board selects the remaining five words from each age")
	var original_round: String = app._round_id
	var original_context: Dictionary = app._round_context.duplicate(true)
	app.vocabulary_loader.age_ready.emit(4)
	await _settle()
	check(app._round_id == original_round and app._word_jelly_stages.number == 1,
		"A duplicate media completion cannot recreate the started stage")
	_master(app, first, "complete-mixed-stage")
	check(app.growth.age == 4 and app.growth.learning_age() == 5,
		"Completing the mixed stage recognizes both previously unfinished cohorts")
	var board_ids: Array = view.game.cells.map(func(tile: Dictionary) -> int: return int(tile.id))
	view.game.fragment_count = 3
	app._advance_word_jelly_stages(0.1)
	check(app._pending_vocabulary_stage and app._pending_vocabulary_age == 5
		and app._vocabulary_prompt.visible and app._word_jelly_stages.number == 1,
		"Advancing waits for the next age while preserving the completed stage")
	check(app._round_id == original_round and app._round_context == original_context,
		"A stage download preserves frozen learning and reward identity")
	app.on_page_hidden()
	app.on_page_visible()
	await _settle()
	check(view.game.paused and app._vocabulary_prompt.visible,
		"Returning to a pending download keeps gameplay paused behind its modal")
	host.reply(5, "failed")
	check(app._vocabulary_retry.visible and app._word_jelly_stages.number == 1,
		"A failed stage download cannot advance or discard the current board")
	app._retry_vocabulary()
	check(host.requests.count(5) == 2, "Stage retry retains the exact requested age")
	host.reply(5, "ready")
	await _settle()
	check(app._word_jelly_stages.number == 2 and not view.game.paused
		and not app._vocabulary_prompt.visible and not app._pending_vocabulary_stage,
		"A resumed download unpauses and advances after a hidden-tab interruption")
	check(app._round_id == original_round and app._round_context == original_context
		and view.game.fragment_count == 3 and board_ids.all(func(id: int) -> bool: return not view.game.cell(id).is_empty()),
		"The resumed stage preserves earlier board bodies, rewards, and receipts")
	check(app._word_jelly_stages.words.all(func(word: Dictionary) -> bool: return int(word.min_age) == 5),
		"New supply uses only mounted unmastered words from the next stage")
	app._show_mode_menu()
	check(app._home_can_continue(), "Home can resume cross-age Jelly after Pip's learning age advances")
	app.choose_mode("word_jelly")
	check(not app._mode_menu_open() and app._round_id == original_round
		and app._word_jelly_stages.number == 2 and not view.game.paused,
		"Selecting the same Jelly game resumes its stage instead of starting stage one")
	app.vocabulary_loader.age_ready.emit(5)
	await _settle()
	check(app._round_id == original_round and app._word_jelly_stages.number == 2,
		"Repeated stage-media readiness cannot advance twice")
	var restored := Growth.new(app.growth._path)
	check(restored.configure(app.data.words) and restored.load_state()
		and first.all(func(id: String) -> bool: return restored.is_mastered(id)),
		"Every completed cross-age stage target survives durable reload")
	await _dispose(app)


func _post_settlement_selection() -> void:
	var app = await _make_app()
	app.choose_mode("word_jelly")
	app.vocabulary_loader.downloads.reply(3, "ready")
	await _settle()
	check(app.new_round(904, false, "", "word_jelly", "", false),
		"Begin a deterministic round for delayed collection settlement")
	var view = app._word_jelly
	var game = view.game
	var target: Dictionary = app._word_jelly_stages.words[0].duplicate(true)
	for attempt in range(2):
		app._record_growth("partial-%d" % attempt, [target.id], true)
	check(app.growth.streak(target.id) == 2, "The target still needs its final saved collection")
	var predicted := Stages.new()
	predicted.configure(app._round_content.words.filter(app._jelly_stage_assessable), app._jelly_word_mastered, 904)
	check(predicted.snapshot().word_ids.has(target.id),
		"Selecting before settlement would incorrectly include the almost-mastered target")
	game.cells.clear()
	var tile: Dictionary = game._new_word_root(target, 0)
	game._set_merged_word(tile, target, 1, true)
	tile.column = 0
	tile.row = game.ROWS - 1
	tile.age = game.SETTLE_SECONDS
	game.cells.append(tile)
	game._coin_rng.seed = 208
	var credit: Callable = game.credit_collection
	game.credit_collection = func(event_id: String, amount: int) -> Dictionary:
		var result: Dictionary = credit.call(event_id, amount)
		app._show_mode_menu()
		return result
	check(game.collect(int(tile.id)), "Collect the mastered composition through the real credit callback")
	var receipt: String = app._round_id + ":" + str(game.fusions.back().attempt_id)
	game.step(game.COLLECT_SECONDS)
	check(game.fusions.size() == 1 and bool(game.fusions[0].credited) and game.paused
		and app.growth.streak(target.id) == 2,
		"Opening Home after coin persistence leaves the learning pickup pending settlement")
	game.credit_collection = credit
	var balance: int = app.coin_wallet.balance
	check(app.new_round(904, false, "", "word_jelly", "", false),
		"Starting another staged round settles the original accepted pickup")
	check(app.growth.is_mastered(target.id) and not app._word_jelly_stages.snapshot().word_ids.has(target.id)
		and app._word_jelly_stages.words.size() == 10,
		"Post-settlement selection replaces the newly mastered target before creating any board")
	check(game.cells.all(func(body: Dictionary) -> bool: return str(body.get("source_word_id", "")) != str(target.id))
		and game.upcoming.all(func(body: Dictionary) -> bool: return str(body.get("source_word_id", "")) != str(target.id)),
		"Neither initial bodies nor previews reintroduce the settled mastered word")
	check(app.coin_wallet.balance == balance and app.growth.record_attempt(receipt, [target.id], true, true).duplicate,
		"Restarting neither credits coins twice nor changes the original mastery receipt")
	await _dispose(app)


func _run() -> void:
	root.size = Vector2i(1366, 768)
	await _loading_and_background()
	await _post_settlement_selection()
	for directory: String in directories:
		for file in DirAccess.get_files_at(directory):
			check(DirAccess.remove_absolute(directory.path_join(file)) == OK, "Remove an isolated stage save")
		check(DirAccess.remove_absolute(directory) == OK, "Remove the isolated stage directory")
	print("Jelly stage loading: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
