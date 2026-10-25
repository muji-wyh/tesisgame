extends SceneTree

const Stages = preload("res://scripts/word_jelly_stages.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
var checks: int = 0
var failures: int = 0


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


func _capture(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/" + filename + ".png")


func _selection() -> void:
	var pool: Array[Dictionary] = []
	var mastered: Dictionary = {"word0": true}
	for index in range(24):
		pool.append({"id": "word%d" % index, "text": "word%d" % index, "min_age": 3 if index < 6 else 4})
	var stages := Stages.new()
	stages.configure(pool, func(word: Dictionary) -> bool: return mastered.has(str(word.id)), 37)
	check(stages.number == 1 and stages.words.size() == 10, "A stage selects exactly ten distinct unmastered targets")
	check(not stages.snapshot().word_ids.has("word0"), "Previously mastered words never enter a new stage")
	check(stages.words.filter(func(word: Dictionary) -> bool: return word.min_age == 3).size() == 5,
		"Five remaining younger words combine with five next-age words")
	var first: Array = stages.snapshot().word_ids
	for index in range(8):
		mastered[first[index]] = true
	check(stages.refresh().size() == 8 and stages.remaining.size() == 2 and stages.words.size() == 10,
		"Mastering eight shrinks supply to two while keeping this stage's ten targets fixed")
	for id: String in first:
		mastered[id] = true
	stages.refresh()
	check(stages.begin_next() and stages.number == 2 and stages.words.size() == 10,
		"Completing ten opens the next ten-word stage")
	for id: String in stages.snapshot().word_ids:
		check(not first.has(id), "The next stage never repeats a mastered target")
		mastered[id] = true
	stages.refresh()
	check(stages.begin_next() and stages.words.size() == 3, "The last partial stage uses only the remaining available words")
	for word: Dictionary in stages.words:
		mastered[word.id] = true
	stages.refresh()
	check(not stages.begin_next() and stages.completed, "Exhausting eligible vocabulary ends without recycling mastered words")


func _run() -> void:
	_selection()
	root.size = Vector2i(1366, 768)
	var directory: String = "user://jelly-stages-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await _settle()
	Fixture.enter_mode(app, "word_jelly")
	await _settle()
	app.set_process(false)
	var view = app._word_jelly
	view.set_process(false)
	check(app._mode_id == "word_jelly" and app._word_jelly_stages != null, "The real Home route starts staged Jelly Words")
	if app._word_jelly_stages == null:
		quit(1)
		return
	var first: Array = app._word_jelly_stages.snapshot().word_ids
	check(first.size() == 10 and view.game._words.size() == 10, "The app scopes the initial board and supply to ten targets")
	check(not app._reward_confetti.is_active(), "Opening a stage does not celebrate an unearned completion")
	app._fragment_confetti_requested("word_jelly")
	check(not app._reward_confetti.is_active(), "Chest acquisition and upgrades cannot request Jelly Words confetti")
	await _capture("jelly-stage-opening")
	var round_id: String = app._round_id
	var context: Dictionary = app._round_context.duplicate(true)
	for index in range(8):
		for attempt in range(3):
			app._record_growth("stage-test-%d-%d" % [index, attempt], [first[index]], true)
	check(app._word_jelly_stages.remaining.size() == 2 and view.game._words.size() == 2,
		"Eight saved mastered targets leave only two supply words")
	for tile: Dictionary in view.game.upcoming:
		check(not first.slice(0, 8).has(str(tile.get("source_word_id", ""))), "Advertised supply removes already-mastered targets")
	var original_path: String = app.growth._path
	app.growth._path = directory + "/missing/growth.cfg"
	for attempt in range(3):
		app._record_growth("unsaved-%d" % attempt, [first[8]], true)
	check(app._growth_save_failed and app._word_jelly_stages.remaining.size() == 2,
		"Failed saves never remove a target or advance the stage")
	check(not app._reward_confetti.is_active(), "Failed mastery saves cannot celebrate a stage")
	app.growth._path = original_path
	app._retry_storage()
	check(not app._growth_save_failed and app._word_jelly_stages.remaining.size() == 1,
		"Retry saving updates the active stage from durable mastery")
	var board_ids: Array = view.game.cells.map(func(tile: Dictionary) -> int: return int(tile.id))
	view.game.fragment_count = 3
	for attempt in range(3):
		app._record_growth("last-%d" % attempt, [first[9]], true)
	app._advance_word_jelly_stages(0.1)
	check(app._word_jelly_stages.number == 2 and view.game._words.size() == 10, "The tenth mastery automatically starts stage two")
	var stage_key: String = round_id + ":word_jelly:stage:1"
	check(app._reward_confetti.is_active() and app._reward_confetti.snapshot().keys.has(stage_key),
		"Completing the current stage launches confetti keyed to that stage, not its chest tier")
	var bursts: int = app._reward_confetti.snapshot().ages.size()
	app._advance_word_jelly_stages(0.1)
	check(app._reward_confetti.snapshot().ages.size() == bursts,
		"Refreshing or entering the next stage never repeats the completed stage's confetti")
	app._fragment_confetti_requested("word_jelly")
	check(app._reward_confetti.snapshot().ages.size() == bursts,
		"Chest callbacks cannot add confetti after a stage celebration")
	check(view.game.fragment_count == 3 and board_ids.all(func(id: int) -> bool: return not view.game.cell(id).is_empty()),
		"Stage transition preserves board bodies and earned fragments")
	check(app._round_id == round_id and app._round_context == context, "Stage changes retain reward receipts and frozen vocabulary context")
	check(view.snapshot().stage.celebrating and view.snapshot().stage.label.begins_with("Stage 2"),
		"A real stage advance updates the permanent counter and starts its arrival effect")
	for id: String in app._word_jelly_stages.snapshot().word_ids:
		check(not first.has(id), "Stage two uses new unmastered words")
	for viewport: Vector2i in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = viewport
		await _settle()
		view._layout()
		view._stage_banner.advance(0.35)
		var stage: Dictionary = view.snapshot().stage
		var badge := Rect2(stage.rect[0], stage.rect[1], stage.rect[2], stage.rect[3])
		check(Rect2(Vector2.ZERO, view.size).encloses(badge), "Stage counter remains within the responsive playfield")
		check(not badge.intersects(view._preview_rect) and not badge.intersects(view._board), "Stage counter does not cover the supply or drag board")
		check(badge.grow(0.1).encloses(view._stage_banner._label.get_rect()),
			"Stage text fits after switching layouts at %s: badge %s, label %s" % [viewport, badge, view._stage_banner._label.get_rect()])
		await _capture("jelly-stage-%dx%d" % [viewport.x, viewport.y])
	view.pause(true)
	check(not view.snapshot().stage.celebrating, "Pause dismisses stage motion without removing progress")
	view.pause(false)
	app._word_jelly_stages._pool = app._word_jelly_stages.words.duplicate(true)
	for id: String in app._word_jelly_stages.snapshot().word_ids:
		for attempt in range(3):
			app._record_growth("final-%s-%d" % [id, attempt], [id], true)
	app._advance_word_jelly_stages(0.1)
	check(app._word_jelly_stages.completed and view.game.phase == "finished"
		and app._reward_confetti.snapshot().keys.has(round_id + ":word_jelly:stage:2"),
		"The final available stage also celebrates without requiring a next-stage supply")
	view.stop()
	check(not view.snapshot().stage.visible, "Leaving the round clears its stage presentation")
	app.queue_free()
	await _settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly stage flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
