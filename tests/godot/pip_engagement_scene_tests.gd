extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func observe_idle(app, seconds: float) -> bool:
	var offered := false
	for step in range(ceili(seconds / 0.1)):
		app._update_duck()
		app.duck._process(0.1)
		offered = offered or not app.duck._idle_action.is_empty()
	return offered


func touch(app, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = Vector2.ZERO
	root.push_input(event, true)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://pip-engagement-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	app.duck.settle()
	app._update_duck()
	check(app.duck._proactive_allowed, "Normal play explicitly enables Pip's quiet invitations")
	var original: Array = [app.model.cards.duplicate(true), app.model.hints_remaining,
		app.model.successes, app.model.mistakes, app._status_announcement, app.playroom_state.toy_id]
	check(observe_idle(app, 18), "Pip offers a visible invitation after genuine inactivity")
	check([app.model.cards, app.model.hints_remaining, app.model.successes, app.model.mistakes,
		app._status_announcement, app.playroom_state.toy_id] == original and not app.audio.voice.playing,
		"Invitations never change the game, choices, status or audio")
	app.duck._idle_action = "wave"
	app.duck._idle_left = 1.0
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	root.push_input(key, true)
	check(app.duck._idle_action.is_empty() and not observe_idle(app, 11.5),
		"Meaningful keyboard activity preempts an invitation and gives a fresh quiet interval")
	touch(app, 0, true)
	touch(app, 1, true)
	touch(app, 0, false)
	check(not observe_idle(app, 20), "A second held finger keeps Pip quiet after the first finger lifts")
	touch(app, 1, false)
	check(not observe_idle(app, 11.5) and observe_idle(app, 6), "Releasing the final pointer starts a new invitation interval")
	for phase in ["feedback", "won", "lost"]:
		app.model.phase = phase
		check(not observe_idle(app, 20), "Pip does not interrupt " + phase + " with an unsolicited invitation")
	app.model.phase = "waiting"
	app._mode_id = "memory"
	app._memory.memory.phase = "feedback"
	check(not observe_idle(app, 20), "Memory's own answer-feedback phase also suppresses invitations")
	app._memory.memory.phase = "waiting"
	app._mode_id = "match"
	app._memory.memory.studying = true
	check(not observe_idle(app, 20), "A held Memory Peek suppresses invitations")
	app._memory.memory.studying = false
	app._voice_mode = true
	check(not observe_idle(app, 20) and not app.duck.visible, "Voice input never competes with proactive Pip")
	app._voice_mode = false
	app._update_duck()
	app._duck_trick_index = 3
	app._play_duck()
	check(app.duck._trick == "high-five", "Header Pip's tap cycle includes a new high five")
	app._play_duck()
	check(app.duck._trick == "peekaboo", "The next header tap offers peekaboo")
	app._play_duck()
	check(app.duck._trick == "flutter", "The next header tap offers a flutter")
	app.duck.settle()
	app._show_collection()
	app._show_reward_section("medals")
	check(not observe_idle(app, 20), "Medal browsing stays quiet")
	app._show_reward_section("room")
	app.duck.settle()
	check(observe_idle(app, 18), "Pip can invite play in the room without moving its objects")
	app._preview_page.show()
	check(not observe_idle(app, 20), "A reward preview blocks unrelated invitations")
	app._preview_page.hide()
	app.on_page_hidden()
	check(not observe_idle(app, 20), "Page lifecycle keeps the separate idle pause effective")
	app.on_page_visible()
	app.set_reduced_motion(true)
	check(not observe_idle(app, 20), "Reduced motion suppresses unsolicited visual movement")
	await _test_consumed_touches(app)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Pip engagement UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func viewport_touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)


func _test_consumed_touches(app) -> void:
	app._hide_collection()
	app.choose_mode("memory")
	app.set_reduced_motion(false)
	await settle()
	for cancel_first in [false, true]:
		var card_point: Vector2 = app._memory.card_buttons[0].get_global_rect().get_center()
		var eye_point: Vector2 = app._memory.study_button.get_global_rect().get_center()
		viewport_touch(0, card_point, true)
		viewport_touch(1, eye_point, true)
		check(app._memory.memory.studying, "The real second touch holds Memory Peek")
		viewport_touch(0, card_point, false, cancel_first)
		check(not observe_idle(app, 18), "A remaining Peek touch keeps Pip quiet")
		viewport_touch(1, eye_point, false)
		await settle()
		check(not app._memory.memory.studying and app._proactive_touches.is_empty()
			and not app._pointer_focus_active,
			"Consumed touch releases/cancels clear every tracked pointer through real viewport dispatch")
		check(not observe_idle(app, 11.5) and observe_idle(app, 6),
			"Pip resumes only after a fresh quiet interval once both fingers lift")
