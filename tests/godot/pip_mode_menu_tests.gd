extends SceneTree

const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for frame in range(8):
		await process_frame

func _tap(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()

func _escape() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()

func _home_pointer(point: Vector2, down: bool, touch: bool, canceled: bool = false) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = 31
	else:
		event = InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = point
	event.pressed = down
	event.canceled = canceled
	root.push_input(event, true)
	await process_frame

func _home_motion(point: Vector2, touch: bool) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenDrag.new()
		event.index = 31
	else:
		event = InputEventMouseMotion.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	event.relative = Vector2(0, -180)
	root.push_input(event, true)
	await process_frame

func _choice(app, id: String) -> Button:
	return app.find_child("Mode_" + id, true, false) as Button

func _enter(app, id: String) -> void:
	if not app._mode_menu_open():
		app._show_mode_menu()
	await settle()
	check(app._mode_menu_open(), "The player visits Home before choosing " + id)
	app._mode_panel.ensure_mode_visible(id)
	await settle()
	await _tap(_choice(app, id).get_global_rect().get_center())
	check(app._mode_id == id and not app._mode_menu_open(), "The Home card enters " + id)

func _return_home(app) -> void:
	var home: Button = app.find_child("Home", true, false) as Button
	if app._settlement_dialog_open():
		if app._round_celebration.is_active():
			home = app._round_celebration.home_button
		elif app._is_jelly_mode():
			home = app._jelly_rewards._home
		elif app._mode_id == "pop":
			home = app._pop_rewards._home
		else:
			home = app._single_result.home_button
	check(home != null and home.is_visible_in_tree() and not home.disabled,
		"Every gameplay screen exposes an available Home button")
	if home != null and home.is_visible_in_tree() and not home.disabled:
		await _tap(home.get_global_rect().get_center())
	check(app._mode_menu_open(), "The active Home button returns to the dedicated homepage: " + app._mode_id)

func _round_snapshot(app) -> Array:
	return [app._round_id, app._mode_id, app.model.cards.duplicate(true), app.model.lesson_words.duplicate(true),
		app.model.selected_id, app.model.phase, app.model.matched_ids.duplicate(), app.model.mistakes, app.model.hints_used]

func _game_snapshot(app) -> Array:
	var state := _round_snapshot(app)
	match app._mode_id:
		"memory":
			state.append([app._memory.memory.phase, app._memory.memory.selected_indices.duplicate(),
				app._memory.memory.matched_word_ids.duplicate(), app._memory.memory.attempts,
				app._memory.memory.mistakes, app._memory.memory.studying])
		"phrase": state.append(app._phrase.game.snapshot().duplicate(true))
		"pop":
			state.append([app._pop.game.phase, app._pop.game.remaining, app._pop.game.score,
				app._pop.game.hits, app._pop.game.targets.duplicate(true)])
		"jelly", "word_jelly": state.append(app._active_jelly().game.snapshot().duplicate(true))
	return state

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	directory = "user://pip-home-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	PlayerFixture.install(app, directory)
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	await settle()
	await _check_home_preview_lifecycle(app)
	await _check_startup(app)
	await _check_home_touch_gestures(app)
	await _check_modes_and_pause(app)
	await _check_failed_switch(app)
	await _check_memory_and_collection(app)
	await _check_pop_callbacks(app)
	await _check_results_and_replay(app)
	await _check_layout(app)
	app.audio.halt()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Home navigation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_home_preview_lifecycle(app) -> void:
	var before := _round_snapshot(app)
	app.set_reduced_motion(false)
	await settle()
	check(app._mode_panel.snapshot().previews.all(func(entry: Dictionary) -> bool: return entry.animating),
		"All six gameplay scenes animate on Home without hover or selection")
	app.on_page_hidden()
	await settle()
	check(app._mode_panel.snapshot().previews.all(func(entry: Dictionary) -> bool: return not entry.animating),
		"The host's background notification stops every decorative scene")
	app.on_page_visible()
	await settle()
	check(app._mode_panel.snapshot().previews.all(func(entry: Dictionary) -> bool: return entry.animating),
		"The host's foreground notification resumes visible Home scenes automatically")
	check(_round_snapshot(app) == before and app._mode_menu_open() and not app._has_entered_game,
		"Animating and backgrounding Home never selects a mode or changes gameplay state")
	app.set_reduced_motion(true)
	app.on_page_hidden()
	app.on_page_visible()
	await settle()
	check(app._mode_panel.snapshot().previews.all(func(entry: Dictionary) -> bool: return entry.reduced_motion and not entry.animating),
		"Returning from a background tab still honors reduced motion")

func _check_startup(app) -> void:
	check(app._mode_menu_open() and app._mode_panel.is_visible_in_tree(), "The application starts on Home")
	check(not app._has_entered_game and app._mode_panel.snapshot().current == "",
		"The initial homepage does not claim a default game is already playing")
	check(app._mode_buttons.size() == 6 and not app._mode_buttons.any(func(button: Button) -> bool: return button.button_pressed),
		"All six games are offered without a preselected game")
	app._refresh()
	check(not app._mode_buttons.any(func(button: Button) -> bool: return button.button_pressed)
		and app._default_focus() == _choice(app, "word_jelly"),
		"Refreshing initial Home keeps every game unselected and starts keyboard focus on the first visible game")
	check(app.find_child("LibraryClose", true, false) == null, "Home has no transient-menu close action")
	var before := _round_snapshot(app)
	await _escape()
	app._controller_back()
	await _tap(Vector2(2, 2))
	check(app._mode_menu_open() and _round_snapshot(app) == before and not app._has_entered_game,
		"Escape, controller Back, and the page background never enter a default game")
	var card: Button = app.cards[app.model.cards[0].id]
	check(not app._valid_focus(card), "Home keeps gameplay cards out of keyboard focus")
	card.pressed.emit()
	app._toggle_voice()
	check(_round_snapshot(app) == before and not app._voice_mode,
		"Covered cards and microphone controls cannot act through Home")
	for step in range(8):
		app._move_focus(Vector2.DOWN)
		check(app._mode_panel.is_ancestor_of(root.gui_get_focus_owner()), "Controller focus stays inside Home")
	await _enter(app, "match")
	check(app._has_entered_game, "Selecting a game explicitly enters play")
	before = _round_snapshot(app)
	app.choose_mode("memory")
	check(_round_snapshot(app) == before, "Direct gameplay mode switching requires returning Home")
	app.duck.pressed.emit()
	check(not app._mode_menu_open() and _round_snapshot(app) == before,
		"Pip remains a companion instead of acting as a hidden game switcher")

func _check_home_touch_gestures(app) -> void:
	await _return_home(app)
	root.size = Vector2i(390, 420)
	await settle()
	var scroll = app._mode_panel.scroll
	var launches: Array[String] = []
	var record := func(id: String) -> void: launches.append(id)
	app._mode_panel.mode_requested.connect(record)
	var before := _round_snapshot(app)
	for touch_first in [false, true]:
		scroll.cancel_drag()
		root.gui_release_focus()
		scroll.scroll_vertical = 0
		await settle()
		var card: Button = _choice(app, "match")
		var visible_card: Rect2 = card.get_global_rect().intersection(scroll.get_global_rect())
		check(visible_card.size.y > 20 and visible_card.size.y < card.size.y,
			"The compact Home swipe begins on a partially clipped game card")
		var point: Vector2 = visible_card.get_center()
		var offset: int = scroll.scroll_vertical
		await _home_pointer(point, true, touch_first)
		await _home_pointer(point, true, not touch_first)
		check(scroll.scroll_vertical == offset and launches.is_empty(),
			"Pressing a clipped Home card waits for the gesture without a focus-scroll jump")
		var end: Vector2 = point - Vector2(0, 180)
		await _home_motion(end, touch_first)
		await _home_motion(end, not touch_first)
		check(absi(scroll.scroll_vertical - offset - 180) <= 2,
			"A Home card swipe follows 180 pixels once across raw and emulated touch streams")
		await _home_pointer(end, false, touch_first)
		await _home_pointer(end, false, not touch_first)
		await settle()
		check(app._mode_menu_open() and launches.is_empty() and _round_snapshot(app) == before
			and not scroll.is_pointer_active(), "Releasing a Home card drag never launches its game")
	for interruption in ["touch cancel", "host cancel", "background"]:
		scroll.cancel_drag()
		root.gui_release_focus()
		scroll.scroll_vertical = 0
		await settle()
		app._mode_panel.ensure_mode_visible("memory")
		await settle()
		var point: Vector2 = _choice(app, "memory").get_global_rect().get_center()
		check(scroll.get_global_rect().has_point(point), "The interrupted Home tap starts inside a visible Memory card")
		await _home_pointer(point, true, true)
		await _home_pointer(point, true, false)
		match interruption:
			"touch cancel": await _home_pointer(point, false, true, true)
			"host cancel": app._on_input_canceled()
			"background":
				app.on_page_hidden()
				app.on_page_visible()
		await _home_pointer(point, false, false)
		await _home_pointer(point, false, true)
		await settle()
		check(app._mode_menu_open() and launches.is_empty() and _round_snapshot(app) == before
			and not scroll.is_pointer_active(), "A late Home card release cannot launch after " + interruption)
	scroll.cancel_drag()
	root.gui_release_focus()
	scroll.scroll_vertical = 0
	await settle()
	app._mode_panel.ensure_mode_visible("memory")
	await settle()
	var point: Vector2 = _choice(app, "memory").get_global_rect().get_center()
	check(scroll.get_global_rect().has_point(point), "The fresh Home tap targets the visible Memory card after canceled gestures")
	await _home_pointer(point, true, true)
	await _home_pointer(point, true, false)
	await _home_pointer(point, false, true)
	await _home_pointer(point, false, false)
	await settle()
	check(launches == ["memory"] and app._mode_id == "memory" and not app._mode_menu_open(),
		"A fresh Home card tap still enters its game exactly once after canceled gestures")
	app._mode_panel.mode_requested.disconnect(record)
	root.size = Vector2i(960, 720)
	await settle()

func _check_modes_and_pause(app) -> void:
	for id: String in ["match", "memory", "phrase", "pop", "jelly", "word_jelly"]:
		await _enter(app, id)
		var round_id: String = app._round_id
		await _return_home(app)
		check(app._mode_panel.snapshot().current == id and _choice(app, id).button_pressed,
			"Home marks the resumable current game: " + id)
		app._refresh()
		check(app._default_focus() == _choice(app, id),
			"Home keyboard and controller focus follows the current game by identity: " + id)
		for button: Button in app._mode_buttons:
			check(button.button_pressed == (button == _choice(app, id)),
				"An ordinary refresh preserves only the current game's selected card: " + id + " / " + str(button.name))
		check(app.feedback_timer.paused and app._memory._paused and app._phrase._paused,
			"Home pauses feedback and teaching flows: " + id)
		var frozen := _game_snapshot(app)
		await create_timer(0.16).timeout
		await settle()
		check(_game_snapshot(app) == frozen, "A game cannot progress behind Home: " + id)
		app.on_page_hidden()
		app.on_page_visible()
		await settle()
		check(app._mode_menu_open() and app.feedback_timer.paused and app._memory._paused
			and _game_snapshot(app) == frozen, "Backgrounding Home preserves its paused game: " + id)
		await _enter(app, id)
		check(app._round_id == round_id, "The current Home card resumes its existing round: " + id)
		match id:
			"match": check(not app.feedback_timer.paused, "Match feedback resumes after entering its card")
			"memory": check(not app._memory._paused, "Memory resumes after entering its card")
			"phrase": check(not app._phrase._paused and app._phrase_interaction_allowed(), "Phrase Builder resumes after entering its card")
			"pop": check(app._pop.interaction_allowed.call(), "Voice Pop accepts explicit input after entering its card")
			"jelly", "word_jelly": check(not app._active_jelly().game.paused and app._jelly_interaction_allowed(), "Falling jellies resume after entering their card: " + id)
		var unchanged := _round_snapshot(app)
		app.choose_mode("match" if id != "match" else "memory")
		check(_round_snapshot(app) == unchanged, "Gameplay cannot directly enter another mode: " + id)

func _check_failed_switch(app) -> void:
	await _enter(app, "match")
	PlayerFixture.reserve_pair_chest(app)
	var word: Dictionary = app.model.lesson_words[0]
	app.cards[str(word.id) + ":word"].pressed.emit()
	app.cards[str(word.id) + ":image"].pressed.emit()
	app.feedback_timer.stop()
	app._continue_match()
	check(app.model.chest_earned, "The save-failure fixture owns a real earned chest")
	var round_id: String = app._round_id
	var before: int = app.coin_wallet.balance
	var wallet_path: String = app.coin_wallet._path
	app.coin_wallet._path = directory
	await _return_home(app)
	app.choose_mode("memory")
	await settle()
	check(not app._mode_menu_open() and app._mode_id == "match" and app._round_id == round_id,
		"A failed mode-switch settlement reveals the original game instead of trapping its retry behind Home")
	check(app._storage_retry_button.is_visible_in_tree() and not app._storage_retry_button.disabled
		and app._save_error and app.coin_wallet.balance == before,
		"The failed reward exposes an actionable Retry and cannot credit unsaved coins")
	app.coin_wallet._path = wallet_path
	app._retry_storage()
	await settle()
	check(not app._save_error and app.coin_wallet.balance == before + 50,
		"Retry saves the earned chest once after storage becomes available")

func _check_memory_and_collection(app) -> void:
	await _enter(app, "memory")
	app._memory.card_buttons[0].pressed.emit()
	var selected: Array = app._memory.memory.selected_indices.duplicate()
	check(not selected.is_empty(), "Memory starts a real partial pair")
	await _return_home(app)
	check(app._memory.memory.selected_indices == selected, "Returning Home preserves the partial Memory pair")
	await _enter(app, "memory")
	check(app._memory.memory.selected_indices == selected, "Reentering Memory restores its selected card")
	app._memory.begin_peek()
	check(app._memory.memory.studying, "The Memory peek fixture is visibly active")
	var attempts: int = app._memory.memory.attempts
	await _return_home(app)
	check(not app._memory.memory.studying and app._memory.memory.selected_indices.is_empty()
		and app._memory.memory.attempts == attempts, "Returning Home cancels a timed peek without scoring")
	var frozen := _game_snapshot(app)
	app._mode_panel.collection_requested.emit()
	await settle()
	check(app.collection_page.visible, "Home opens the vocabulary and rewards collection")
	app._hide_collection()
	await settle()
	check(not app.collection_page.visible and app._mode_menu_open() and app._memory._paused
		and _game_snapshot(app) == frozen, "Collection Back returns Home without resuming the paused game")
	await _enter(app, "memory")
	app._show_collection()
	await settle()
	app._hide_collection()
	await settle()
	check(not app._mode_menu_open() and not app._memory._paused,
		"A collection visit from gameplay returns to that game")

func _check_pop_callbacks(app) -> void:
	await _enter(app, "pop")
	app._pop.set_listening(true, true, "Listening.")
	app._pop_speech_active = true
	check(app._pop.game.phase == "running", "The microphone fixture starts a live Voice Pop round")
	await _return_home(app)
	check(app._pop.game.phase == "paused" and not app._pop_speech_active and not app._pop._listening,
		"Home pauses Voice Pop and releases active microphone ownership")
	var frozen := _game_snapshot(app)
	app._on_voice_state([true, true, "Listening."])
	app._on_voice_result(["cat", true])
	# A late receipt can still carry stale ownership; Home must reject it itself.
	app._pop_speech_active = true
	check(not app._accept_pop_speech(JSON.stringify({"transcript": "cat", "final": true})),
		"A late Pop receipt is rejected even with stale microphone ownership")
	app._pop_speech_active = false
	check(_game_snapshot(app) == frozen and not app._pop._listening,
		"Late microphone callbacks cannot restart or score behind Home")
	await _enter(app, "pop")
	app._pop.exit_requested.emit()
	await settle()
	check(app._mode_menu_open() and app._mode_id == "pop", "Voice Pop exits through Home without silently changing to Match")
	await _enter(app, "pop")
	app._controller_back()
	await settle()
	check(app._mode_menu_open() and app._mode_id == "pop", "Controller Back leaves Voice Pop through Home")

func _check_results_and_replay(app) -> void:
	await _enter(app, "memory")
	PlayerFixture.reserve_pair_chest(app)
	for word: Dictionary in app.model.lesson_words:
		for index in range(app._memory.memory.cards.size()):
			if app._memory.memory.cards[index].word.id == word.id:
				app._memory.card_buttons[index].pressed.emit()
		app._memory._feedback_timer.stop()
		app._memory.continue_feedback()
	check(app.model.phase == "won" and app.model.chest_earned, "A completed Memory round earns its reserved chest")
	PlayerFixture.finish_celebration(app)
	app._open_chest()
	app.chest.finish_immediately()
	await settle()
	check(app.model.chest_state == "opened" and not app._save_error, "The completed Memory chest is saved")
	await _return_home(app)
	await _enter(app, "memory")
	var previous_round: String = app._round_id
	app._new_adventure()
	await settle()
	check(app._mode_id == "memory" and app._round_id != previous_round and app.model.phase == "waiting",
		"Memory Play again starts another Memory round without a hidden mode switch")
	for id: String in ["jelly", "word_jelly"]:
		await _enter(app, id)
		app._active_jelly().game.finish_round()
		await settle()
		check(app._active_jelly().game.phase == "finished", "The result fixture completes " + id)
		var ended_round: String = app._round_id
		var covered_home: Button = app.find_child("Home", true, false) as Button
		await _tap(covered_home.get_global_rect().get_center())
		check(app._settlement_dialog_open() and not app._mode_menu_open() and app._round_id == ended_round,
			"The covered header Home cannot dismiss the settlement dialog: " + id)
		await _return_home(app)
		check(app._mode_id == id, "A result screen returns Home without switching modes: " + id)

func _check_layout(app) -> void:
	if not app._mode_menu_open():
		app._show_mode_menu()
	for dimensions in [Vector2i(320, 320), Vector2i(390, 420), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 900)]:
		root.size = dimensions
		await settle()
		var viewport: Rect2 = app.get_global_rect()
		var panel: Rect2 = app._mode_panel.get_global_rect()
		check(viewport.grow(1).encloses(panel) and panel.size.is_equal_approx(viewport.size),
			"Home occupies the full viewport at " + str(dimensions))
		for id: String in ["match", "memory", "pop", "phrase", "jelly", "word_jelly"]:
			app._mode_panel.ensure_mode_visible(id)
			await settle()
			var button: Button = _choice(app, id)
			check(button.size.x * app.Style.ui_scale(app) >= 44 and button.size.y * app.Style.ui_scale(app) >= 44,
				"Home keeps a comfortable game target at %s: %s" % [dimensions, id])
			check(viewport.has_point(button.get_global_rect().get_center())
				and app._mode_panel.scroll.get_global_rect().has_point(button.get_global_rect().get_center()),
				"Scrolling Home reaches each game at %s: %s" % [dimensions, id])
			button.grab_focus()
			await settle()
			check(app._valid_focus(button), "Keyboard focus can reach the Home card: " + id)
