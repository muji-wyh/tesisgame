extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
var checks := 0
var failures := 0
var output := "res://build/qa/jelly-fill-stream"


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


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var directory := "user://fill-stream-view-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	Fixture.enter_mode(app, "match")
	app.set_process(false)
	app.audio.set_muted(true)
	check(app.new_round(1901, false, "", "word_jelly"), "Start the actual application")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	var words: Array = app._learning_words().filter(func(word: Dictionary) -> bool:
		return not str(word.get("image", "")).is_empty()).slice(0, 3).map(
			func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(view.configure(words, app.growth.learning_age(), Data.theme(app.model.theme_id),
		app.data.chests, false, 1901), "Use the existing production Jelly artwork and supply")
	check(view.game.bind_stage(Catalog.make_plan(2, words, app.growth.learning_age(), 1901)),
		"Use ordinary timed play with its optional Fill switch")
	var speed: float = 2.2 if OS.get_cmdline_user_args().has("--fast") else 1.0
	view.game.fall_speed_scale = speed
	output += "-fast" if speed > 1.0 else "-normal"
	view.game._stage_spawn_interval = 10000.0
	view.game.spawn_interval = 10000.0
	Fixture.unlock_auto_collect(app)
	app._sync_jelly()
	view.set_process(false)
	for frame in range(100):
		if not view._stage_banner.ready_pending():
			break
		view._process(0.05)
	view._layout()
	await settle()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = view._fill_button.get_global_rect().get_center()
		event.global_position = event.position
		root.push_input(event)
		await process_frame
	check(view.game.fill_mode and view._fill_button.button_pressed, "A real Fill click owns the continuous stream")
	var capturing: bool = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	if capturing:
		DirAccess.make_dir_recursive_absolute(output + "/frames")
	var first_ids: Array[int] = []
	var first_generated: int = -1
	var overlapping := false
	var timeline: Array[Dictionary] = []
	var settled_at := -1.0
	for frame in range(180):
		view._process(0.025)
		view.set_process(false)
		var generated: int = view.game.generated_tiles
		if first_generated < 0:
			first_generated = generated
			for tile: Dictionary in view.game.cells:
				if tile.get("fill_stream", false):
					first_ids.append(int(tile.id))
		var visible_first: Array = view.game.cells.filter(func(tile: Dictionary) -> bool:
			return (int(tile.id) in first_ids and not view.game.is_settled(tile)
				and float(tile.age) >= view.game.arrival_delay(tile) and view._tiles[int(tile.id)].visible))
		var visible_later: Array = view.game.cells.filter(func(tile: Dictionary) -> bool:
			return (bool(tile.arrival) and int(tile.id) not in first_ids
				and not view.game.is_settled(tile) and float(tile.age) >= view.game.arrival_delay(tile)
				and view._tiles[int(tile.id)].visible))
		for older: Dictionary in visible_first:
			overlapping = overlapping or visible_later.any(func(tile: Dictionary) -> bool:
				return int(tile.column) == int(older.column))
		var preview_overlap := false
		for tile: Dictionary in view.game.cells:
			if not tile.get("fill_stream", false) or not view._arrival_origins.has(int(tile.id)):
				continue
			if float(tile.age) - view.game.arrival_delay(tile) + view.WordModel.EPSILON < view.WordModel.arrival_slot_clearance(tile):
				var slot: int = int(view._arrival_origins[int(tile.id)].slot)
				preview_overlap = preview_overlap or view._preview_tiles[slot].visible
		check(not preview_overlap, "A future preview cannot paint over a streamed body that still owns its entrance")
		timeline.append({"frame": frame, "seconds": (frame + 1) * 0.025, "generated": generated,
			"cells": view.game.cells.size(), "first_visible_falling": visible_first.size(),
			"next_visible_falling": visible_later.size()})
		if capturing:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output + "/frames/frame-%04d.png" % frame) == OK,
				"Capture the actual continuous physical stream")
		if view.game.cells.size() == view.WordModel.CAPACITY and view.game._settling_remaining() <= view.WordModel.EPSILON:
			if settled_at < 0.0:
				settled_at = (frame + 1) * 0.025
			if (frame + 1) * 0.025 >= settled_at + 0.3:
				break
	check(overlapping, "The real view paints a later arrival in the same lane while its predecessor is still visibly airborne")
	check(view.game.cells.size() == view.WordModel.CAPACITY and settled_at > 0.0,
		"The visible stream fills and settles the entire well")
	if capturing:
		var file := FileAccess.open(output + "/timeline.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"fps": 40, "fall_speed_scale": speed,
			"settled_at": settled_at, "frames": timeline}, "\t") + "\n")
		file.close()
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Continuous Fill view: %d checks, %d failures; %d frames" % [checks, failures, timeline.size()])
	quit(1 if failures else 0)
