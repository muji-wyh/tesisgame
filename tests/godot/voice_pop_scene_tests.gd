extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in range(8):
		await process_frame

func _run() -> void:
	var directory: String = "user://voice-pop-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.size = Vector2i(390, 844)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	check(app._mode_id == "match" and not app._pop.is_visible_in_tree(), "Startup preserves Match without activating speech")
	var modes: Array[String] = ["match", "learn", "memory", "pop"]
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(679, 900), Vector2i(680, 900), Vector2i(844, 390), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		var original_positions: Array[Vector2] = []
		for mode in modes:
			app.choose_mode(mode)
			await settle()
			var current_positions: Array[Vector2] = []
			for button in app._mode_buttons:
				current_positions.append(button.global_position)
				check(Rect2(Vector2.ZERO, app.size).grow(1).encloses(button.get_global_rect()), "Every mode tab fits at %s in %s" % [dimensions, mode])
				var label_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
				check(label_width <= button.size.x - 8.0, "Mode label is fully readable at %s: %s" % [dimensions, button.text])
			if original_positions.is_empty():
				original_positions = current_positions
			else:
				check(current_positions == original_positions, "Mode tabs stay in the same positions at %s in %s" % [dimensions, mode])
		var view = app._pop
		view.set_process(false)
		check(view.is_visible_in_tree() and not app.grid.is_visible_in_tree() and not app._lesson.visible and not app._memory.visible,
			"Voice Pop owns the visible playfield at " + str(dimensions))
		check(not app.hint_button.visible and not app._voice_button.visible and not app._memory.study_button.visible,
			"Other modes' actions do not intrude into Voice Pop")
		check(view.game.phase == "ready" and view.game.remaining == 30.0, "Waiting for microphone does not consume time")
		view._process(2.0)
		check(view.game.remaining == 30.0 and view.game.targets.is_empty(), "Permission waiting never starts target motion")
		app._on_voice_state([true, true, "Listening. Say an English word."])
		check(view.game.phase == "running" and view.game.targets.size() == 1, "A live microphone starts the actual arcade round")
		view._advance_game(1.5)
		var before_catchup: float = view.game.remaining
		var catchup_started: int = Time.get_ticks_usec()
		var missed_frame_usec: int = mini(250000, catchup_started / 2)
		view._listening_tick_usec = catchup_started - missed_frame_usec
		view._process(0.000001)
		var caught_up: float = before_catchup - view.game.remaining
		var catchup_limit: float = float(Time.get_ticks_usec() - catchup_started + missed_frame_usec) / 1000000.0
		check(caught_up >= float(missed_frame_usec) / 1000000.0 - 0.00001 and caught_up <= catchup_limit + 0.00001,
			"A tiny engine delta still consumes the full monotonic interval after a missed frame")
		check(caught_up > 0.000001 and view._listening_tick_usec >= catchup_started,
			"Low frame rates cannot stretch the round by repeatedly consuming clamped engine deltas")
		var before: int = view.game.hits
		var word: Dictionary = view.game.targets[0].word.duplicate(true)
		view.receive_transcript(word.text)
		check(view.game.hits == before + 1 and view.game.hit_words[0].id == word.id, "A spoken visible word produces an exact hit")
		check(view.game.targets.all(func(target: Dictionary) -> bool: return target.word.id != word.id), "A popped target is removed immediately")
		app._on_voice_state([true, false, "Speech network error. Tap Retry."])
		var remaining: float = view.game.remaining
		check(view._listening_tick_usec == -1, "Speech failure clears the active listening clock baseline")
		view._listening_tick_usec = 0
		view._process(3.0)
		check(view.game.phase == "paused" and view.game.remaining == remaining, "Speech failure pauses both targets and the clock")
		view._listening_tick_usec = 0
		var resumed_at: int = Time.get_ticks_usec()
		app._on_voice_state([true, true, "Listening."])
		check(view.game.phase == "running" and view.game.remaining == remaining and view.game.hits == before + 1,
			"Speech recovery resumes the same round")
		check(view._listening_tick_usec >= resumed_at, "Resuming replaces the stale baseline from before the pause")
		view._process(0.000001)
		var resume_limit: float = float(Time.get_ticks_usec() - resumed_at) / 1000000.0
		check(remaining - view.game.remaining >= 0.0 and remaining - view.game.remaining <= resume_limit + 0.00001,
			"The first resumed frame excludes all time spent paused")
		app._show_collection()
		check(view.game.phase == "paused", "More pauses Voice Pop")
		remaining = view.game.remaining
		app._hide_collection()
		check(view.game.phase == "paused" and view.game.remaining == remaining, "Returning from More waits for an explicit Resume without consuming time")
		app._on_voice_state([true, true, "Listening."])
		app.on_page_hidden()
		remaining = view.game.remaining
		check(view._listening_tick_usec == -1, "Hiding the page clears the active listening clock baseline")
		view._listening_tick_usec = 0
		view._process(3.0)
		check(view.game.phase == "paused" and view.game.remaining == remaining, "Hidden pages preserve the remaining round")
		app.on_page_visible()
		app._on_voice_state([true, true, "Listening."])
		view._advance_game(31.0)
		await settle()
		check(view.game.phase == "finished" and view.game.remaining == 0.0, "The view reaches results at the 30-second deadline")
		var result: Dictionary = view.game.summary()
		check(result.hits == before + 1 and result.unique_words == 1 and result.best_combo >= 1,
			"The result report reflects the real spoken hits")
		check(Rect2(Vector2.ZERO, app.size).grow(1).encloses(view.get_global_rect()), "The result view fits at " + str(dimensions))
		var snapshot: Dictionary = view.snapshot()
		check(snapshot.phase == "finished", "Accessible state reflects the visible results")
		var interactive_pip: bool = false
		for control in view.controls():
			if control.is_visible_in_tree() and control.name.to_lower().contains("pip"):
				interactive_pip = true
		check(interactive_pip, "Pip is an actual interactive result control")
		check(not view.default_focus() is Label, "Results provide a usable action for keyboard focus")
		app.choose_mode("match")
		check(not view.is_visible_in_tree(), "Leaving results returns to the existing game")
		view.set_process(true)
	app.playroom_state.age_band_id = "4-6"
	app.choose_mode("pop")
	check(app._pop.game._words.all(func(word: Dictionary) -> bool: return app.Data.word_level(word) == 1),
		"Voice Pop uses only the selected age group's vocabulary")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Voice Pop scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
