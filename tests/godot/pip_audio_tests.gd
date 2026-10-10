extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	await _check_click_routes()
	print("Pip audio: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_click_routes() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 900)
	var directory := "user://pip-audio-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._mode_id = "match"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await _settle()
	app.set_reduced_motion(true)
	app.audio.halt()
	app.medal_progress.counts["spring-1"] = 1
	app._refresh_collection()
	# Prepare the result states before measuring whether companion input writes.
	for mode in ["match", "memory"]:
		app._mode_id = mode
		preload("res://tests/godot/player_flow_fixture.gd").earn_pair_chest(app)
		check(app.medal_progress.finish_pair_round(mode, app._round_id), "Prepare a completed companion fixture")
	app._mode_id = "match"
	# Refreshing reduced motion schedules container layout before Pip can be hit.
	await _settle()
	var saved: Dictionary = _saved_files(directory)
	var progress: Array = _progress(app)
	var players: Array[Node] = app.audio.get_children()
	app._update_duck()
	check(not app.collection_page.visible and app.duck.is_visible_in_tree(),
		"The isolated learning fixture exposes the gameplay header")
	var trick_index: int = app._duck_trick_index
	await _tap(app.duck.get_global_rect().get_center())
	# Opening the menu cancels pronunciation without starting a companion action.
	check(app._mode_menu_open() and not app.audio.voice.playing
		and app._duck_trick_index == trick_index,
		"A real header mouse click opens game modes without starting a duck greeting")
	app._hide_mode_menu()
	var before: int
	var original_mode: String = app._mode_id
	var playing_phase: String = app.model.phase
	for mode in ["match", "memory"]:
		app._mode_id = mode
		await _show_result_companion(app)
		app.set_reduced_motion(false)
		before = _voice_requests(app)
		app.duck.pressed.emit()
		check(app.duck.is_manual_action_busy() and not app.audio.voice.playing
			and (app.audio.pip_reaction == null or not app.audio.pip_reaction.playing) and _voice_requests(app) == before,
			mode + " result Pip keeps its visual trick without a quack")
		app.duck.settle()
	app._mode_id = original_mode
	app.set_reduced_motion(true)
	await _show_result_companion(app)
	for guard in ["_voice_mode", "_pop_speech_active"]:
		app.audio.halt()
		before = _voice_requests(app)
		app.set(guard, true)
		app.duck.pressed.emit()
		check(not app.audio.voice.playing and _voice_requests(app) == before,
			"Result Pip stays silent while " + guard + " owns the microphone")
		app.set(guard, false)
	app.model.phase = playing_phase
	app._refresh()
	await _show_result_companion(app)
	before = _voice_requests(app)
	app.duck.pressed.emit()
	check(not app.audio.voice.playing and _voice_requests(app) == before, "Match result Pip reacts without a greeting")
	app.on_page_hidden()
	check(not app.audio.voice.playing and not app.audio.active,
		"Backgrounding the page stops companion audio")
	app.on_page_visible()
	await _settle()
	check(app.audio.active and app.audio.music.playing and not app.audio.voice.playing
		and not app.audio.effect.playing,
		"Returning to the page restores background music without replaying a stale greeting")
	app.model.phase = playing_phase
	app._refresh()
	check(app.audio.get_children() == players, "All native Pip click routes keep the same audio players")
	check(_progress(app) == progress, "Pip interactions leave lesson cards, rewards and learning progress unchanged")
	check(_saved_files(directory) == saved, "Pip greetings do not write or alter any saved progress")
	app.audio.halt()
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)


func _show_result_companion(app) -> void:
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	preload("res://tests/godot/player_flow_fixture.gd").earn_pair_chest(app)
	app.model.phase = "won"
	if app._mode_id == "memory":
		app._memory.memory.phase = "won"
	app._refresh()
	preload("res://tests/godot/player_flow_fixture.gd").finish_celebration(app)
	app._layout()
	await _settle()
	app.audio.halt()
	app.duck.settle()
	app._update_duck()
	check(app.duck.is_visible_in_tree() and not app._mode_menu_open(),
		"The result fixture exposes Pip's companion interaction")


func _voice_requests(app) -> int:
	return app.audio._playback_requests.get(app.audio.voice, 0)


func _progress(app) -> Array:
	return [app.model.phase, (app.model.matched_ids.size() / 2), app.model.mistakes, app.model.hints_remaining,
		app.model.cards.duplicate(true), app.model.lesson_words.duplicate(true), app.medal_progress.counts.duplicate(true),
		app.growth.snapshot(), app.growth._streaks.duplicate(true)]


func _saved_files(directory: String) -> Dictionary:
	var result: Dictionary = {}
	for filename in DirAccess.get_files_at(directory):
		result[filename] = FileAccess.get_file_as_bytes(directory + "/" + filename)
	return result


func _settle() -> void:
	await process_frame
	await process_frame


func _tap(point: Vector2, method: String = "mouse") -> void:
	if method == "mouse":
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, true)
		await process_frame
	await _button(point, true, method)
	await _button(point, false, method)


func _button(point: Vector2, pressed: bool, method: String) -> void:
	if method == "touch":
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
