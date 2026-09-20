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
	check(not observe_idle(app, 5.5) and observe_idle(app, 3.6)
		and app.duck._idle_action == "dance-wave", "Pip's first quiet invitation is a dance within 6–9 seconds")
	check([app.model.cards, app.model.hints_remaining, app.model.successes, app.model.mistakes,
		app._status_announcement, app.playroom_state.toy_id] == original and not app.audio.voice.playing,
		"Invitations never change the game, choices, status or audio")
	app.duck._idle_action = "wave"
	app.duck._idle_left = 1.0
	var key := InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	root.push_input(key, true)
	check(app.duck._idle_action.is_empty() and not observe_idle(app, 5.5),
		"Meaningful keyboard activity preempts an invitation and gives a fresh quiet interval")
	touch(app, 0, true)
	touch(app, 1, true)
	touch(app, 0, false)
	check(not observe_idle(app, 20), "A second held finger keeps Pip quiet after the first finger lifts")
	touch(app, 1, false)
	check(not observe_idle(app, 5.5) and observe_idle(app, 4), "Releasing the final pointer starts a new invitation interval")
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
	_test_pop_and_audio_gates(app)
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
	check(not observe_idle(app, 20) and not app.duck.home_playground, "Medal browsing stays quiet and disables the Home dance")
	app._show_reward_section("room")
	app.duck.settle()
	check(not observe_idle(app, 0.2) and observe_idle(app, 0.3)
		and app.duck.home_playground and app.duck._idle_action == "home-dance",
		"Entering Home starts the loading-page dance within half a second without a tap")
	_test_home_gates(app)
	app._preview_page.show()
	check(not observe_idle(app, 20), "A reward preview blocks unrelated invitations")
	app._preview_page.hide()
	app.on_page_hidden()
	check(not observe_idle(app, 20), "Page lifecycle keeps the separate idle pause effective")
	app.on_page_visible()
	check(not observe_idle(app, 0.2) and observe_idle(app, 0.3) and app.duck._idle_action == "home-dance",
		"Returning to Home waits a short quiet beat before its dance resumes")
	await _test_home_focus_headroom(app)
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


func _test_home_focus_headroom(app) -> void:
	var original_size: Vector2i = root.size
	var original_scroll: int = app._collection_scroll.scroll_vertical
	var saved_toy: String = app.playroom_state.toy_id
	var saved_medals: Dictionary = app.medal_progress.counts.duplicate(true)
	for dimensions in [Vector2i(390, 568), Vector2i(960, 720)]:
		root.size = dimensions
		await settle()
		app._collection_back.grab_focus()
		app._collection_scroll.scroll_vertical = int(app._collection_max_scroll().y)
		await settle()
		var before_scroll: int = app._collection_scroll.scroll_vertical
		var clipped_top: float = app._collection_scroll.get_global_rect().position.y
		check(before_scroll > 0 and app._collection_duck_slot.get_global_rect().position.y < clipped_top + 16,
			"The scrolled Home fixture places Pip's jumping head above the visible area at " + str(dimensions))
		app.duck.grab_focus()
		await settle()
		var viewport_bounds: Rect2 = app._collection_scroll.get_global_rect()
		var slot_bounds: Rect2 = app._collection_duck_slot.get_global_rect()
		var jump_bounds := Rect2(slot_bounds.position - Vector2(0, 16), slot_bounds.size + Vector2(0, 16))
		check(app.duck.has_focus() and app._collection_scroll.scroll_vertical < before_scroll
			and slot_bounds.position.y - viewport_bounds.position.y >= 15.5
			and viewport_bounds.grow(0.5).encloses(jump_bounds),
			"Focusing Pip reveals its whole slot plus 16 logical pixels above the head at %s: viewport=%s slot=%s scroll=%d -> %d" % [
				dimensions, viewport_bounds, slot_bounds, before_scroll, app._collection_scroll.scroll_vertical])
		app.duck.react_in_room("jump")
		app.duck._process(0.425)
		check(app.duck._room_reaction == "jump" and app._collection_duck_slot.get_global_rect() == slot_bounds
			and app._collection_scroll.get_global_rect().grow(0.5).encloses(jump_bounds),
			"A jump at its peak keeps the revealed headroom and stable focus target at " + str(dimensions))
		app.duck.settle()
	check(app.playroom_state.toy_id == saved_toy and app.medal_progress.counts == saved_medals,
		"Revealing and jumping with focused Pip changes no equipment or earned progress")
	app._collection_back.grab_focus()
	root.size = original_size
	await settle()
	app._collection_scroll.scroll_vertical = original_scroll


func _test_home_gates(app) -> void:
	var before: Array = [app.model.cards.duplicate(true), app.medal_progress.counts.duplicate(true),
		app.playroom_state.toy_id, app._status_announcement, app._room.toy_button.position,
		app._room.playground.duck_position]
	check(observe_idle(app, 16) and app.duck._idle_action == "home-dance"
		and [app.model.cards, app.medal_progress.counts, app.playroom_state.toy_id,
			app._status_announcement, app._room.toy_button.position, app._room.playground.duck_position] == before
		and not app.audio.voice.playing,
		"Repeated Home dance loops change no game state, toy positions, announcements or speech")
	for state in ["loading", "speaking"]:
		app.audio._set_narration_state(state)
		check(not observe_idle(app, 12), "Home dancing yields while narration is " + state)
		app.audio.stop_narration()
		check(not observe_idle(app, 0.2) and observe_idle(app, 0.3) and app.duck._idle_action == "home-dance",
			"Home dancing resumes after narration " + state + " ends and a short quiet beat")
	touch(app, 0, true)
	touch(app, 1, true)
	touch(app, 0, false)
	check(not observe_idle(app, 12), "Home dancing remains paused while the second finger is still down")
	touch(app, 1, false)
	check(not observe_idle(app, 0.2) and observe_idle(app, 0.3) and app.duck._idle_action == "home-dance",
		"Lifting the final Home pointer restarts the dance after a short quiet beat")


func _test_pop_and_audio_gates(app) -> void:
	for state in ["loading", "speaking"]:
		app.duck._idle_action = "dance-wave"
		app.duck._idle_left = 2.0
		app.audio._set_narration_state(state)
		app._update_duck()
		check(app.duck._idle_action.is_empty() and not observe_idle(app, 12),
			"Narration " + state + " interrupts a dance and prevents another invitation")
		app.audio.stop_narration()
		check(not observe_idle(app, 5.5) and observe_idle(app, 4),
			"Stopping narration " + state + " starts a fresh quiet interval")
	var silence := AudioStreamWAV.new()
	silence.format = AudioStreamWAV.FORMAT_16_BITS
	silence.mix_rate = 22050
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = 2205
	var samples := PackedByteArray()
	samples.resize(4410)
	samples.fill(0)
	silence.data = samples
	for player in [app.audio.voice, app.audio.narration]:
		player.stream = silence
		player.play()
		check(player.playing and not observe_idle(app, 12),
			"A playing voice or narrator blocks invitations independently of the speaking pose")
		player.stop()
		check(not observe_idle(app, 5.5) and observe_idle(app, 4),
			"Finished playback restarts the quiet interval")
	app.audio.halt()
	app._mode_id = "pop"
	app._configure_pop(7)
	app.duck.settle()
	check(observe_idle(app, 9.5), "Voice Pop's ready page permits a quiet invitation")
	app._pop_speech_active = true
	check(not observe_idle(app, 12), "An outstanding browser microphone request blocks invitations")
	app._pop_speech_active = false
	app._pop.set_listening(true, false, "Starting microphone...")
	check(app._pop._pending and not observe_idle(app, 12), "Opening the microphone keeps Pip quiet before listening starts")
	app._pop.set_listening(true, true, "Listening...")
	check(app._pop.game.phase == "running" and not observe_idle(app, 12), "Live Voice Pop listening keeps Pip quiet")
	app._pop.set_listening(true, false, "Listening paused. Continuing...")
	check(app._pop._reconnecting and not observe_idle(app, 12), "Automatic microphone reconnection keeps Pip quiet")
	app._pop.set_listening(true, true, "Listening...")
	check(app._pop.game.phase == "running" and not observe_idle(app, 12), "Resumed listening still blocks invitations")
	app._pop.pause()
	check(app._pop.game.phase == "paused" and not observe_idle(app, 5.5) and observe_idle(app, 4),
		"A paused Voice Pop round permits invitations only after a new quiet interval")
	app._pop._listening = true
	check(not observe_idle(app, 12), "A late listening flag still blocks invitations in a paused round")
	app._pop._listening = false
	for phase in ["running", "finished"]:
		app._pop.game.phase = phase
		check(not observe_idle(app, 12), "Voice Pop's own " + phase + " phase overrides the idle Match model")
	app._pop.stop()
	app._mode_id = "match"
	app._update_duck()


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
		check(not observe_idle(app, 5.5) and observe_idle(app, 4),
			"Pip resumes only after a fresh quiet interval once both fingers lift")
