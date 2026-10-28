extends SceneTree

const Celebration = preload("res://scripts/jelly_chest_celebration.gd")
const Flight = preload("res://scripts/chest_reward_flight.gd")
const Style = preload("res://scripts/ui_style.gd")
const BEFORE = preload("res://assets/chests/energy/closed.png")
const AFTER = preload("res://assets/chests/royal/closed.png")
var checks := 0
var failures := 0
var baseline := false
var output := ""


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func begin(view, previous: int, tier: int, reduced: bool = false) -> void:
	view.clear()
	view.reduced_motion = reduced
	view.enqueue(previous, tier, BEFORE, AFTER)


func capture(view, name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output + "/" + name + ".png") == OK,
		"Capture the acquired three-dimensional chest and real grade presentation")


func _run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	output = "res://build/qa/chest-upgrade-levels-" + ("before" if baseline else "after")
	DirAccess.make_dir_recursive_absolute(output)
	RenderingServer.set_default_clear_color(Color("#eef7f1"))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var view := Celebration.new()
	root.add_child(view)
	view.size = Vector2(root.size)
	view.set_chest_anchor(Rect2(194, 16, 44, 44))
	if not baseline:
		begin(view, 3, 4, true)
		check(view.snapshot().has("level_transition"), "The presentation exposes the real previous-to-new level treatment")
		if view.snapshot().has("level_transition"):
			await check_levels(view)
			check_queue(view)
			check_model_upgrade()
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(320, 480), Vector2i(1366, 768), Vector2i(844, 390)]:
		root.size = dimensions
		view.position = Vector2.ZERO
		view.size = Vector2(dimensions)
		view.set_chest_anchor(Rect2(minf(194.0, dimensions.x - 56.0), 16, 44, 44))
		begin(view, 3, 4)
		view.advance(Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS + 0.20)
		await capture(view, "%dx%d-lv3-lv4" % [dimensions.x, dimensions.y])
		if not baseline and view.snapshot().has("level_transition"):
			check_layout(view)
	root.size = Vector2i(393, 852)
	view.size = Vector2(root.size)
	view.set_chest_anchor(Rect2(194, 16, 44, 44))
	begin(view, 29, 30)
	view.advance(Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS + 0.20)
	await capture(view, "393x852-lv29-lv30")
	view.clear()
	view.free()
	await process_frame
	await capture_gameplay()
	print("Chest upgrade levels: %d checks, %d failures%s" % [checks, failures, " (baseline)" if baseline else ""])
	quit(1 if failures else 0)


func check_levels(view) -> void:
	for previous in range(1, 30):
		begin(view, previous, previous + 1, true)
		check(not view.snapshot().level_transition.visible, "No level label precedes the real pickup arrival")
		view.advance(Celebration.ARRIVAL_SECONDS + 0.01)
		var level: Dictionary = view.snapshot().level_transition
		check(level.visible and level.from_tier == previous and level.to_tier == previous + 1
			and level.from_text == "Lv%d" % previous and level.to_text == "Lv%d" % (previous + 1),
			"Every real chest upgrade retains its exact old and new levels, including 29 to 30")
		check_layout(view)
		view.set_paused(true)
		check(not view.snapshot().level_transition.visible, "Pause hides the viewport annotation with its chest")
		view.set_paused(false)
		view.clear()
		check(not view.snapshot().level_transition.visible, "Round cleanup cannot leave an old level transition behind")
	begin(view, 0, 1, true)
	view.advance(Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS)
	check(not view.snapshot().level_transition.visible, "The first chest never invents a level-zero upgrade")
	begin(view, 30, 30, true)
	view.advance(10.0)
	check(not view.is_active() and not view.snapshot().level_transition.visible,
		"A capped chest never invents a level-thirty-one upgrade")
	begin(view, 4, 7, true)
	view.advance(Celebration.ARRIVAL_SECONDS + 0.01)
	check(view.snapshot().level_transition.from_tier == 4 and view.snapshot().level_transition.to_tier == 7,
		"A genuine direct jump uses its recorded source level, not target minus one")
	for dimensions: Vector2i in [Vector2i(320, 220), Vector2i(393, 852), Vector2i(844, 235)]:
		root.size = dimensions
		view.size = Vector2(dimensions)
		view.set_chest_anchor(Rect2(dimensions.x - 50, dimensions.y - 42, 38, 32))
		await process_frame
		check_layout(view)
	root.size = Vector2i(393, 852)
	view.size = Vector2(root.size)
	view.set_chest_anchor(Rect2(194, 16, 44, 44))


func check_queue(view) -> void:
	begin(view, 1, 2)
	view.enqueue(2, 3, BEFORE, AFTER)
	view.enqueue(3, 4, BEFORE, AFTER)
	view.advance(Celebration.ARRIVAL_SECONDS + Flight.TURN_END + 0.01)
	check(view.snapshot().level_transition.from_tier == 1 and view.snapshot().level_transition.to_tier == 2,
		"A queued next turn does not erase the upgrade that just visibly completed")
	view.advance(0.5)
	check(view.snapshot().level_transition.from_tier == 2 and view.snapshot().level_transition.to_tier == 3,
		"The caption advances with the real next turn rather than announcing the final queued level early")
	view.advance(20.0)
	check(not view.snapshot().level_transition.visible and not view.is_active(),
		"The last tier returns on the unchanged reward timeline without a lingering overlay")


func check_layout(view) -> void:
	var level: Dictionary = view.snapshot().level_transition
	var values: Array = level.rect
	var rect := Rect2(values[0], values[1], values[2], values[3])
	check(view._flight_bounds().grow(0.01).encloses(rect), "The complete transition fits the actual viewport")
	var from: Array = level.from_rect
	var to: Array = level.to_rect
	check(Style.HEADING_FONT.get_string_size(str(level.from_text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(level.from_font)).x <= from[2] + 0.1
		and Style.HEADING_FONT.get_string_size(str(level.to_text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(level.to_font)).x <= to[2] + 0.1
		and Style.HEADING_FONT.get_height(int(level.to_font)) <= to[3] + 0.1,
		"Both real numbers fit their own areas instead of clipping or overlapping")


func check_model_upgrade() -> void:
	var data := preload("res://scripts/game_data.gd").new()
	check(data.load_all(), "Load the real current-age chest and word material")
	var words: Array = data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) == 3 and not str(word.get("image", "")).is_empty()).slice(0, 6).map(
			func(word: Dictionary) -> Dictionary: return preload("res://scripts/growth_morphology.gd").decorate(word))
	var owner := preload("res://scripts/word_jelly.gd").new()
	root.add_child(owner)
	owner.set_process(false)
	owner.size = Vector2(1000, 720)
	check(owner.configure(words, 3, data.theme("spring"), data.chests, false, 71), "Use the actual Word Jelly owner")
	var model = owner.game
	model.cells.clear()
	model.fragment_count = 4
	model.chest_count = 1
	model.chest_tier = 1
	var tile: Dictionary = model._new_word_root(words[0])
	model._set_merged_word(tile, words[0], 1, true)
	tile.merge({"column": 2, "row": 7, "age": 100.0, "arrival": false, "settling": false, "fragments": 5}, true)
	model.cells.append(tile)
	check(model.collect(int(tile.id)), "A real completed word contributes its carried chest fragments")
	model.step(model.COLLECT_SECONDS)
	var level: Dictionary = owner._reward_presentation.snapshot().level_transition
	check(model.fragment_count == 9 and model.chest_tier == 2 and level.from_tier == 1 and level.to_tier == 2,
		"The visible level pair comes from a genuinely committed chest milestone, not guessed display arithmetic")
	owner.stop()
	owner.free()


func capture_gameplay() -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	var fixture = preload("res://tests/godot/player_flow_fixture.gd")
	var directory := "user://chest-level-review-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(393, 852)
	var app = load("res://scenes/main.tscn").instantiate()
	fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	for frame in range(6):
		await process_frame
	fixture.enter_mode(app, "word_jelly")
	app.set_process(false)
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	var owner = app._word_jelly
	owner.set_process(false)
	owner.game.spawn_interval = 10000.0
	owner.game.fragment_count = 4
	owner.game.chest_tier = 1
	owner.game.chest_count = 1
	owner._displayed_chest_tier = 1
	var tile: Dictionary = owner.game._new_word_root(owner.game._words[0])
	owner.game._set_merged_word(tile, owner.game._words[0], 1, true)
	var at: Vector2i = owner.game._free_position(owner.game._occupied(), 1, 1)
	tile.merge({"column": at.x, "row": at.y, "age": 100.0, "arrival": false, "settling": false, "fragments": 5}, true)
	owner.game.cells.append(tile)
	check(owner.game.collect(int(tile.id)), "The native gameplay review earns an actual upgrade")
	for frame in range(53):
		owner._process(0.05)
		owner.set_process(false)
	check(not owner._reward_presentation.reduced_motion and not owner._reward_presentation._model_sample.is_empty(),
		"The ordinary gameplay review really renders the acquired moving model, not the static preference")
	await capture(owner._reward_presentation, "393x852-gameplay")
	owner.set_reduced_motion(true)
	await capture(owner._reward_presentation, "393x852-gameplay-reduced")
	app.audio.halt()
	app.queue_free()
	for frame in range(6):
		await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
