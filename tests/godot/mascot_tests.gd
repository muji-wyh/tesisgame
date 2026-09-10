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


func _run() -> void:
	var path := "res://scripts/duck_mascot.gd"
	check(FileAccess.file_exists(path), "The animated duck mascot exists")
	if not FileAccess.file_exists(path):
		print("Mascot: %d assertions, %d failures" % [checks, failures])
		quit(1)
		return
	var duck = load(path).new()
	root.add_child(duck)
	duck.size = Vector2(72, 72)
	check(duck.pose == 0, "Pip starts with an innocent resting expression")
	_check_idle_actions(duck)
	duck.set_speaking(true)
	check(duck.pose == 1, "Actual speech opens Pip's beak immediately")
	duck._process(0.15)
	check(duck.pose == 0, "Speech alternates beak poses without creating animation nodes")
	duck.set_speaking(false)
	check(duck.pose == 0, "Stopping speech closes the beak")
	for index in range(30):
		duck.react("happy")
	check(duck.reaction_left <= 0.65, "Rapid interactions replace rather than stack duck reactions")
	duck._process(0.8)
	check(is_zero_approx(duck.reaction_left), "Duck reactions finish on their own")
	duck.set_reduced_motion(true)
	duck.set_speaking(true)
	duck._process(0.5)
	check(duck.pose == 1 and duck.scale == Vector2.ONE, "Reduced motion uses a static speaking pose")
	duck.set_speaking(false)
	duck.react("happy")
	check(duck.scale == Vector2.ONE and is_zero_approx(duck.rotation), "Reduced-motion greetings never move the hit target")
	check(duck.pose == 3, "Reduced-motion greetings still give a static wave")
	duck.free()
	var app = load("res://scenes/main.tscn").instantiate()
	var integrated: bool = app.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "duck")
	check(integrated, "The duck is integrated into every native page")
	if integrated:
		var directory := "user://duck-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		DirAccess.make_dir_recursive_absolute(directory)
		app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
		app.playroom_save_path = directory + "/playroom.cfg"
		app._mode_id = "match"
		# Godot consumes Escape to dismiss a hovered tooltip before scene input.
		# Keep this keyboard fixture independent of the inherited pointer position.
		var pointer := InputEventMouseMotion.new()
		pointer.position = Vector2(-100, -100)
		Input.parse_input_event(pointer)
		root.add_child(app)
		await process_frame
		await process_frame
		app.audio.halt()
		app._update_duck()
		check(app.duck.visible and not app.duck.speaking, "The board duck is idle without spoken audio")
		var cards: Array = app.model.cards.duplicate(true)
		app.duck.pressed.emit()
		check(app.model.cards == cards and app.model.successes == 0 and not app.model.hint_used,
			"Playing with Pip never changes game progress")
		check(app.audio.voice.playing, "Pip's greeting uses the bundled duck pronunciation")
		app.audio.halt()
		app.audio.interact(app.model.theme_id, false)
		app.audio.cue("select")
		app._update_duck()
		check(not app.duck.speaking, "Sound effects do not make Pip pretend to speak")
		app.audio.say("res://" + app.model.cards[0].word.audio)
		app._update_duck()
		check(app.audio.voice.playing and app.duck.speaking, "Pip speaks with the actual pronunciation player")
		var selected: String = app.model.cards[0].id
		app.cards[selected].grab_focus()
		app.cards[selected].pressed.emit()
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		Input.parse_input_event(escape)
		await process_frame
		check(app.model.selected_id.is_empty(), "Escape still cancels a card with the mascot present")
		escape.pressed = false
		Input.parse_input_event(escape)
		app._show_collection()
		await process_frame
		app._update_duck()
		check(app.duck.visible and not app.duck.speaking and app.duck.get_global_rect().intersects(app._collection_duck_slot.get_global_rect()),
			"The collection duck stops speaking about the covered game picture")
		app.duck.pressed.emit()
		app._update_duck()
		check(app.audio.voice.playing and app.duck.speaking, "Pip can greet again in the collection")
		app.medal_progress.counts["spring-1"] = 1
		app._refresh_collection()
		app._open_reward_preview("spring-1")
		await process_frame
		app._update_duck()
		check(app.duck.visible and app.duck.get_global_rect().intersects(app._preview_duck_slot.get_global_rect()),
			"The reward preview has its own visible duck position")
		app._preview_play_button.grab_focus()
		app._move_focus(Vector2.UP)
		check(app._preview_close.has_focus(), "Up from reward play still reaches Back before the optional mascot")
		app.on_page_hidden()
		check(not app.duck.speaking, "Hiding the page silences Pip along with the audio")
		if app.duck.has_method("set_idle_paused"):
			check(not app.duck.is_processing(), "Background pages stop Pip's idle animation loop")
			app.on_page_visible()
			check(app.duck.is_processing() and not app.audio.active,
				"Returning resumes quiet mascot activity without restarting audio")
		app._hide_collection()
		app._on_voice_state([true, true, "Listening"])
		app._update_duck()
		check(not app.duck.visible, "Voice mode uses its HTML duck without a duplicate native mascot")
		app._stop_voice()
		app.audio.halt()
		app._update_duck()
		check(app.duck.visible and not app.duck.speaking, "Leaving voice mode returns the quiet board mascot")
		for dimensions in [Vector2i(320, 320), Vector2i(390, 844), Vector2i(844, 390)]:
			root.size = dimensions
			await process_frame
			await process_frame
			app._update_duck()
			check(root.get_visible_rect().encloses(app.duck.get_global_rect()), "The duck fits the supported viewport")
			check(app.duck.size.x >= 72 and app.duck.size.y >= 72, "The duck retains an accessible touch target")
		# Headless frames can finish before the audio thread consumes its stop queue.
		await create_timer(0.1).timeout
		app.queue_free()
		await process_frame
		var files := DirAccess.open(directory)
		for filename in files.get_files():
			DirAccess.remove_absolute(directory + "/" + filename)
		DirAccess.remove_absolute(directory)
	else:
		app.free()
	print("Mascot: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_idle_actions(duck: Button) -> void:
	check(duck.has_method("set_idle_paused"), "Pip supports autonomous gestures and explicit page suspension")
	if not duck.has_method("set_idle_paused"):
		return
	var original_rect: Rect2 = duck.get_rect()
	var gestures: Array[String] = []
	for step in range(750):
		duck._process(0.1)
		var action: String = duck._idle_action
		if not action.is_empty() and (gestures.is_empty() or gestures.back() != action):
			gestures.append(action)
	check(gestures.size() >= 5 and ["look", "stretch", "wave", "preen", "hop"].all(
		func(action: String) -> bool: return gestures.has(action)), "Quiet play gets five distinct, occasional gestures without clicks")
	check(duck.get_rect() == original_rect and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation),
		"Autonomous motion never moves or scales the button hit target")
	duck.set_speaking(true)
	check(duck._idle_action.is_empty(), "Pronunciation immediately interrupts idle gestures")
	for step in range(200):
		duck._process(0.1)
	check(duck._idle_action.is_empty(), "Pip never starts an idle gesture over sustained speech")
	duck.set_speaking(false)
	duck.react("happy")
	check(duck._idle_action.is_empty() and duck.pose == 3, "Player feedback takes priority over autonomous animation")
	duck.perform_trick("snack")
	duck._process(0.3)
	check(duck._idle_action.is_empty() and duck._trick == "snack", "An explicit trick stays in charge")
	duck.settle()
	duck._process(0.2)
	check(duck._idle_action.is_empty(), "Reset leaves a quiet interval before the next autonomous action")
	duck._process(60.0)
	check(duck._idle_action.is_empty(), "A stalled frame cannot replay missed idle actions")
	duck.set_idle_paused(true)
	for step in range(200):
		duck._process(0.1)
	check(duck._idle_action.is_empty() and not duck.is_processing(), "Page suspension stops both action and animation processing")
	duck.set_idle_paused(false)
	check(duck.is_processing(), "Returning to a visible page resumes the idle scheduler")
	duck.hide()
	check(duck._idle_action.is_empty() and not duck.is_processing(), "A hidden mascot has no idle work")
	duck.show()
	duck.set_reduced_motion(true)
	for step in range(200):
		duck._process(0.1)
	check(duck._idle_action.is_empty() and not duck.is_processing(), "Reduced motion suppresses all autonomous gestures")
	duck.set_reduced_motion(false)
	duck.settle()
