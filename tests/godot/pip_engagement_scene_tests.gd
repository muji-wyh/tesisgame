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


func play_looping_voice(app) -> void:
	var silence := AudioStreamWAV.new()
	silence.format = AudioStreamWAV.FORMAT_16_BITS
	silence.mix_rate = 22050
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = 2205
	var samples := PackedByteArray()
	samples.resize(4410)
	samples.fill(0)
	silence.data = samples
	app.audio.voice.stream = silence
	app.audio.voice.play()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://pip-engagement-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	app.duck.settle()
	app._update_duck()
	check(app.duck._proactive_allowed, "Normal play explicitly enables Pip's quiet invitations")
	var original: Array = [app.model.cards.duplicate(true), app.model.hints_remaining,
		(app.model.matched_ids.size() / 2), app.model.mistakes, app._status_announcement, app.playroom_state.toy_id]
	check(not observe_idle(app, 5.5) and observe_idle(app, 3.6)
		and app.duck._idle_action == "dance-wave", "Pip's first quiet invitation is a dance within 6–9 seconds")
	check([app.model.cards, app.model.hints_remaining, (app.model.matched_ids.size() / 2), app.model.mistakes,
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
	for phase in ["feedback", "won"]:
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
	check(not observe_idle(app, 20) and app.duck.is_visible_in_tree()
		and app.duck.tooltip_text == "Pip: change game mode",
		"Voice input suppresses Pip's invitations while keeping its game-mode trigger available")
	app._voice_mode = false
	app._update_duck()
	_test_pop_and_audio_gates(app)
	app._duck_trick_index = 3
	app._play_duck()
	check(app._mode_menu_open() and app.duck._trick.is_empty() and app._duck_trick_index == 3,
		"Header Pip opens the game-mode menu without advancing its companion trick cycle")
	app._hide_mode_menu()
	var playing_phase: String = app.model.phase
	app.model.phase = "won"
	app._refresh()
	app._layout()
	await settle()
	app.duck.settle()
	app._play_duck()
	check(app.duck._trick == "high-five", "Result Pip's tap cycle includes a new high five")
	app._play_duck()
	check(app.duck._trick == "high-five" and app._duck_trick_index == 4,
		"A repeated result companion activation preserves the current action and next trick index")
	app.duck._process(app.duck.TRICK_SECONDS)
	app._play_duck()
	check(app.duck._trick == "peekaboo", "The next result companion tap offers peekaboo")
	app.duck._process(app.duck.TRICK_SECONDS)
	app._play_duck()
	check(app.duck._trick == "flutter", "The next result companion tap offers a flutter")
	app.duck.settle()
	app.model.phase = playing_phase
	app._refresh()
	app._show_collection()
	await settle()
	app.duck.settle()
	check(not observe_idle(app, 0.2) and observe_idle(app, 0.3)
		and app.duck.home_playground and app.duck._idle_action == "home-dance",
		"Entering Home starts the loading-page dance within half a second without a tap")
	_test_home_gates(app)
	app.on_page_hidden()
	check(not observe_idle(app, 20), "Page lifecycle keeps the separate idle pause effective")
	app.on_page_visible()
	check(not observe_idle(app, 0.2) and observe_idle(app, 0.3) and app.duck._idle_action == "home-dance",
		"Returning to Home waits a short quiet beat before its dance resumes")
	await _test_home_focus_headroom(app)
	app.set_reduced_motion(true)
	check(not observe_idle(app, 20), "Reduced motion suppresses unsolicited visual movement")
	await _test_consumed_touches(app)
	_test_contextual_attention(app)
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

	for dimensions in [Vector2i(390, 568), Vector2i(960, 600)]:
		root.size = dimensions
		await settle()
		app._collection_back.grab_focus()
		var before_scroll: int = app._collection_scroll.scroll_vertical
		check(before_scroll == 0 and app._collection_scroll.get_global_rect().encloses(app.duck.get_global_rect()),
			"The fixed Home viewport keeps Pip visible at " + str(dimensions))
		app.duck.grab_focus()
		await settle()
		var viewport_bounds: Rect2 = app._collection_scroll.get_global_rect()
		var slot_bounds: Rect2 = app._collection_duck_slot.get_global_rect()
		var jump_bounds := Rect2(slot_bounds.position - Vector2(0, 16), slot_bounds.size + Vector2(0, 16))
		check(app.duck.has_focus() and app._collection_scroll.scroll_vertical == before_scroll
			and slot_bounds.position.y - viewport_bounds.position.y >= 15.5
			and viewport_bounds.grow(0.5).encloses(jump_bounds),
			"Focusing Pip preserves its whole slot plus 16 logical pixels above the head at %s: viewport=%s slot=%s scroll=%d -> %d" % [
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
	play_looping_voice(app)
	check(app.audio.voice.playing and not observe_idle(app, 12), "Home dancing yields while a word is playing")
	app.audio.stop_voice()
	check(not observe_idle(app, 0.2) and observe_idle(app, 0.3) and app.duck._idle_action == "home-dance",
		"Home dancing resumes after word playback ends and a short quiet beat")
	touch(app, 0, true)
	touch(app, 1, true)
	touch(app, 0, false)
	check(not observe_idle(app, 12), "Home dancing remains paused while the second finger is still down")
	touch(app, 1, false)
	check(not observe_idle(app, 0.2) and observe_idle(app, 0.3) and app.duck._idle_action == "home-dance",
		"Lifting the final Home pointer restarts the dance after a short quiet beat")


func _test_pop_and_audio_gates(app) -> void:
	app.duck._idle_action = "dance-wave"
	app.duck._idle_left = 2.0
	play_looping_voice(app)
	app._update_duck()
	check(app.audio.voice.playing and app.duck._idle_action.is_empty() and not observe_idle(app, 12),
		"Word playback interrupts a dance and blocks invitations independently of the speaking pose")
	app.audio.stop_voice()
	check(not observe_idle(app, 5.5) and observe_idle(app, 4),
		"Finished word playback restarts the quiet interval")
	app.audio.halt()
	app._mode_id = "pop"
	app._configure_pop(7)
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
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
		check(app.duck._attention == "thinking", "Pip studies with the held Memory Peek")
		viewport_touch(1, eye_point, false)
		await settle()
		check(not app._memory.memory.studying and app._proactive_touches.is_empty()
			and not app._pointer_focus_active,
			"Consumed touch releases/cancels clear every tracked pointer through real viewport dispatch")
		check(app.duck._attention.is_empty(), "Releasing Peek clears Pip's studying expression")
		check(not observe_idle(app, 5.5) and observe_idle(app, 4),
			"Pip resumes only after a fresh quiet interval once both fingers lift")


func _test_contextual_attention(app) -> void:
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	var saved_rewards: Dictionary = app.medal_progress.counts.duplicate(true)
	check(app.new_round(84, true, "", "match"), "A fresh Match round starts for contextual expressions")
	app.duck.settle()
	app._select_card(app.model.cards[0].id)
	app._update_duck()
	check(app.duck._attention == "thinking" and app.duck._gameplay_reaction.is_empty(),
		"One selected Match card invites thought without judging an unfinished pair")
	var remaining: float = app.duck.reaction_left
	for index in range(8):
		app._update_duck()
	check(is_equal_approx(app.duck.reaction_left, remaining) and app.model.phase == "matching",
		"Repeated context synchronization never restarts selection feedback or advances the game")
	app.duck._process(0.7)
	check(app.duck.expression_name() == "thinking", "A partial Match pair remains thoughtful after its selection reaction")
	app._controller_back()
	app._update_duck()
	check(app.duck._attention.is_empty(), "Canceling the selected Match card clears its context")
	for state in [[false, "Starting microphone..."], [true, "Listening."], [false, "Listening paused. Continuing..."]]:
		app._on_voice_state([true, state[0], state[1]])
		app._update_duck()
		check(app.duck._attention == "listening", "Match microphone opening, listening and rollover retain attention")
	app._on_voice_state([true, false, "Microphone permission was denied. Allow it in browser settings, or tap cards."])
	app._update_duck()
	check(app.duck._attention.is_empty(), "A failed Match microphone never pretends to keep listening")
	app._stop_voice()

	check(app.new_round(84, true, "", "memory"), "A fresh Memory round starts for contextual expressions")
	app._memory.card_buttons[0].pressed.emit()
	app._update_duck()
	check(app.duck._attention == "thinking" and app.duck._gameplay_reaction.is_empty(),
		"A single revealed Memory card has a thoughtful, unjudged context")
	app._show_mode_menu()
	check(app.duck._attention.is_empty(), "The game menu clears the covered board's expression")
	app._hide_mode_menu()
	check(app.duck._attention == "thinking", "Returning to the selected Memory card restores its real context")
	app._show_collection()
	app._update_duck()
	check(app.duck._attention.is_empty(), "Pip's room never inherits the covered Memory board's expression")
	app._hide_collection()
	app._memory.card_buttons[0].pressed.emit()
	app._update_duck()
	check(app.duck._attention.is_empty(), "Covering the selected Memory card clears its expression")

	check(app.new_round(84, true, "", "pop"), "A fresh Voice Pop round starts for contextual expressions")
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	app._pop.set_process(false)
	for state in [[false, "Starting microphone..."], [true, "Listening."], [false, "Listening paused. Continuing..."]]:
		app._on_voice_state([true, state[0], state[1]])
		app._update_duck()
		check(app.duck._attention == "listening", "Voice Pop microphone opening, listening and rollover retain attention")
	app._on_voice_state([true, false, "Speech network error. Check your internet connection, then tap Retry."])
	app._update_duck()
	check(app.duck._attention.is_empty(), "A stopped Voice Pop microphone clears attention while preserving the round")
	app._pop.game.phase = "finished"
	app._pop._listening = true
	app._update_duck()
	check(app.duck._attention.is_empty(), "A completed Voice Pop round ignores a stale microphone flag")
	app._pop.stop()

	check(app.new_round(84, true, "", "phrase"), "A fresh Phrase Builder round starts for contextual expressions")
	var view = app._phrase
	view.option_buttons[0].pressed.emit()
	var partial: Dictionary = view.game.snapshot()
	check(view.pip._attention == "thinking" and view.pip._gameplay_reaction.is_empty()
		and view.game.completed == 0 and view.game.mistakes == 0,
		"A placed phrase word invites thought without judging an incomplete answer")
	view.pause()
	check(view.pip._attention.is_empty(), "Pausing Phrase Builder clears its separate Pip's context")
	view.resume()
	check(view.pip._attention == "thinking" and view.game.snapshot() == partial,
		"Resuming a partial phrase restores its context without changing the answer")
	app.on_page_hidden()
	app._update_duck()
	check(view.pip._attention.is_empty() and app.duck._attention.is_empty(), "A hidden page clears both companions' contexts")
	app.on_page_visible()
	view._refresh()
	check(view.pip._attention == "thinking", "The visible partial phrase restores only its current context")
	view.answer_buttons[0].pressed.emit()
	check(view.pip._attention.is_empty(), "Removing the final phrase word clears its context")
	for word_id in view.game.current_question().words:
		for index in range(view.game.options.size()):
			if view.game.options[index].id == word_id:
				view.option_buttons[index].pressed.emit()
				break
	view.action_button.pressed.emit()
	check(view.pip._attention.is_empty() and view.pip._gameplay_reaction == "happy"
		and is_equal_approx(view.pip._gameplay_left, view.pip.GAMEPLAY_HAPPY_SECONDS),
		"A correct phrase clears thought and retains the existing celebration deadline")
	view.stop()
	check(view.pip._attention.is_empty() and app.medal_progress.counts == saved_rewards,
		"Stopping contextual expressions leaves no stale state or extra rewards")
