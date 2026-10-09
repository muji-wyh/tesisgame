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


func _paired_tap(point: Vector2, touch_first: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		for touch in [touch_first, not touch_first]:
			var event: InputEvent
			if touch:
				event = InputEventScreenTouch.new()
				event.index = 0
			else:
				event = InputEventMouseButton.new()
				event.device = InputEvent.DEVICE_ID_EMULATION
				event.global_position = point
				event.button_index = MOUSE_BUTTON_LEFT
				event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			event.position = point
			event.pressed = down
			root.push_input(event, true)
		await process_frame
	await settle()


func _choice(app, id: String) -> Button:
	return app.find_child("Mode_" + id, true, false) as Button


func _round_snapshot(app) -> Array:
	return [app._mode_id, app.model.cards.duplicate(true), app.model.lesson_words.duplicate(true),
		app.model.selected_id, app.model.phase, (app.model.matched_ids.size() / 2), app.model.mistakes, app.model.hints_remaining]


func _pop_ready_snapshot(app) -> Array:
	var pop = app._pop
	return [pop.game.phase, pop.game.remaining, pop._gate_title.text, pop._gate_copy.text,
		pop._gate_note.text, pop.retry_button.text, pop.retry_button.disabled,
		app._pop_speech_active, pop._listening, pop._pending]


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	directory = "user://pip-mode-menu-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	PlayerFixture.install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	await settle()
	check(not app._mode_menu.visible and not app._mode_row.is_visible_in_tree()
		and app._mode_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()),
		"Gameplay starts with mode choices tucked away behind Pip")
	check(app._mode_panel.is_ancestor_of(app._mode_row) and not app._header.is_ancestor_of(app._mode_row),
		"The mode list belongs to the popover instead of reserving a gameplay header row")
	await _check_toggle_and_round(app)
	await _check_dismissal_and_focus(app)
	await _check_paired_touches(app)
	await _check_mode_selection(app)
	await _check_lifecycle(app)
	await _check_layout(app)
	await _check_direct_pop_entry(app)
	app.audio.halt()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Pip mode menu: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_toggle_and_round(app) -> void:
	var card: Button = app.cards[app.model.cards[0].id]
	card.pressed.emit()
	# Selecting a card schedules header and mascot layout updates.
	await settle()
	var before := _round_snapshot(app)
	await _tap(app.duck.get_global_rect().get_center())
	check(app._mode_menu.visible and app._mode_panel.is_visible_in_tree(),
		"Clicking upper-left Pip opens the mode popover")
	check(_round_snapshot(app) == before, "Opening the menu preserves the selected Match card and exact round")
	check(_choice(app, "match").button_pressed
		and app._mode_buttons.filter(func(button: Button) -> bool: return button.button_pressed).size() == 1,
		"The current game has one unambiguous selected mode")
	check(root.gui_get_focus_owner() == _choice(app, "match"),
		"Opening the popover focuses the current mode for keyboard and controller navigation")
	await _tap(_choice(app, "match").get_global_rect().get_center())
	check(not app._mode_menu.visible and _round_snapshot(app) == before,
		"Selecting the current mode closes the popover without restarting the round")
	await _tap(app.duck.get_global_rect().get_center())
	await _tap(app.duck.get_global_rect().get_center())
	check(not app._mode_menu.visible and _round_snapshot(app) == before,
		"A second Pip click toggles the popover closed without changing gameplay")


func _check_dismissal_and_focus(app) -> void:
	await _tap(app.duck.get_global_rect().get_center())
	var before := _round_snapshot(app)
	var card: Button
	for candidate in app.cards.values():
		if not app._mode_panel.get_global_rect().has_point(candidate.get_global_rect().position + Vector2(4, 4)):
			card = candidate
			break
	check(card != null, "The outside-click fixture has a visible card behind the dismissal layer")
	if card != null:
		check(not app._valid_focus(card), "Covered gameplay cannot enter popover keyboard navigation")
		await _tap(card.get_global_rect().position + Vector2(4, 4))
		check(not app._mode_menu.visible and _round_snapshot(app) == before,
			"Clicking outside closes the menu without selecting the underlying card")
		check(app.duck.has_focus(), "Outside dismissal restores focus to the Pip trigger")
	await _tap(app.duck.get_global_rect().get_center())
	for step in range(6):
		app._move_focus(Vector2.DOWN)
		check(app._mode_panel.is_ancestor_of(root.gui_get_focus_owner()),
			"Controller navigation stays within the open mode popover")
	await _escape()
	check(not app._mode_menu.visible and app.duck.has_focus() and _round_snapshot(app) == before,
		"Escape dismisses the menu, restores Pip focus, and preserves the round")
	await _tap(app.duck.get_global_rect().get_center())
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	root.push_input(back, true)
	back.pressed = false
	root.push_input(back, true)
	await settle()
	check(not app._mode_menu.visible and app.duck.has_focus() and not app.collection_page.visible,
		"Controller Back dismisses only the mode popover")


func _check_mode_selection(app) -> void:
	var lesson: Array = app.model.lesson_words.duplicate(true)
	for id in ["memory", "pop", "match"]:
		await _tap(app.duck.get_global_rect().get_center())
		check(app._mode_menu.visible, "Pip opens the chooser from " + app._mode_id)
		await _tap(_choice(app, id).get_global_rect().get_center())
		if id == "pop":
			check(not app._mode_menu.visible and app._pop.is_visible_in_tree(),
				"Voice Pop closes its chooser and opens the microphone gate directly")
			PlayerFixture.choose_pop_player(app)
			await settle()
		check(app._mode_id == id and not app._mode_menu.visible,
			"A mode choice closes the menu and opens " + id)
		check(app.model.lesson_words == lesson, "Changing mode keeps the same selected lesson: " + id)
		var ready_before: Array = []
		if id == "pop":
			check(app._pop.game.phase == "ready" and not app._pop_speech_active
				and not app._pop._listening and not app._pop._pending,
				"The native Voice Pop fixture is ready with no active microphone")
			ready_before = _pop_ready_snapshot(app)
		app._show_mode_menu()
		await settle()
		check(_choice(app, id).button_pressed
			and app._mode_buttons.filter(func(button: Button) -> bool: return button.button_pressed).size() == 1,
			"Reopening identifies the newly selected current mode: " + id)
		app._hide_mode_menu()
		await settle()
		if id == "pop":
			check(_pop_ready_snapshot(app) == ready_before,
				"Opening and dismissing modes preserves the ready Voice Pop gate, retry action, clock, and speech state exactly")
			await _check_pop_error_gate(app)


func _check_paired_touches(app) -> void:
	for touch_first in [false, true]:
		app._hide_mode_menu()
		await settle()
		var before := _round_snapshot(app)
		await _paired_tap(app.duck.get_global_rect().get_center(), touch_first)
		check(app._mode_menu.visible,
			"Paired touch/emulated events open Pip's menu once: touch-first=%s" % touch_first)
		if not app._mode_menu.visible:
			continue
		var outside: Button
		for candidate in app.cards.values():
			if not app._mode_panel.get_global_rect().has_point(candidate.get_global_rect().position + Vector2(4, 4)):
				outside = candidate
				break
		check(outside != null, "The paired-touch fixture has an underlying card outside the popover")
		if outside == null:
			continue
		await _paired_tap(outside.get_global_rect().position + Vector2(4, 4), touch_first)
		check(not app._mode_menu.visible and _round_snapshot(app) == before,
			"Paired outside releases dismiss once without activating the covered card: touch-first=%s" % touch_first)


func _check_pop_error_gate(app) -> void:
	var pop = app._pop
	pop.set_listening(true, true, "Listening.")
	pop.set_listening(true, false, "Speech network error. Check your internet connection, then tap Retry.")
	# The browser can retain ownership after a hard speech error even though
	# no recognizer is listening, connecting, or reconnecting anymore.
	app._pop_speech_active = true
	check(pop.game.phase == "paused" and not pop._listening and not pop._pending and not pop._reconnecting,
		"The hard-error fixture is paused with stale host ownership and no active recognizer")
	var before: Array = _pop_ready_snapshot(app)
	before[7] = false
	var progress: Array = [pop.game.score, pop.game.hits, pop._enabled, pop._reconnecting]
	app._show_mode_menu()
	await settle()
	check(_pop_ready_snapshot(app) == before and not app._pop_speech_active,
		"Opening the menu clears stale microphone ownership without replacing the hard-error gate")
	app._hide_mode_menu()
	await settle()
	check(_pop_ready_snapshot(app) == before
		and [pop.game.score, pop.game.hits, pop._enabled, pop._reconnecting] == progress,
		"Dismissing the menu preserves a paused hard error and its Retry action without retrying speech")
	var round_id: String = app._round_id
	app._show_collection()
	await settle()
	check(app.collection_page.visible and _pop_ready_snapshot(app) == before,
		"Opening growth preserves the existing hard-error explanation and Retry action")
	app._hide_collection()
	await settle()
	check(_pop_ready_snapshot(app) == before and app._round_id == round_id
		and [pop.game.score, pop.game.hits, pop._enabled, pop._reconnecting] == progress,
		"Closing growth preserves the hard-error round without restarting speech")
	pop.set_listening(true, true, "Listening.")
	app._pop_speech_active = true
	app._show_collection()
	await settle()
	check(pop.game.phase == "paused" and not pop._listening and not pop._pending
		and not pop._reconnecting and not app._pop_speech_active and app._round_id == round_id,
		"Opening growth still pauses an active Pop round and stops microphone ownership")
	app._hide_collection()
	await settle()
	check(pop.game.phase == "paused" and not pop._listening and not app._pop_speech_active,
		"Closing growth waits for an explicit microphone retry after interrupting active play")


func _check_lifecycle(app) -> void:
	app.choose_mode("memory")
	await settle()
	app._memory.card_buttons[0].pressed.emit()
	var selected: Array = app._memory.memory.selected_indices.duplicate()
	app._show_mode_menu()
	await settle()
	check(app._mode_menu.visible and app._memory.memory.selected_indices == selected,
		"Opening modes preserves a partially selected Memory pair")
	app._hide_mode_menu()
	await settle()
	app._memory.begin_peek()
	check(app._memory.memory.studying, "The held-peek fixture really reveals the Memory cards")
	var matched: Array = app._memory.memory.matched_word_ids.duplicate()
	var attempts: int = app._memory.memory.attempts
	app._show_mode_menu()
	await settle()
	check(app._mode_menu.visible and not app._memory.memory.studying
		and app._memory.memory.selected_indices.is_empty()
		and app._memory.memory.matched_word_ids == matched and app._memory.memory.attempts == attempts,
		"Opening modes releases a held Memory peek without scoring or changing matched pairs")
	app._hide_mode_menu()
	await settle()
	# Peek intentionally clears a partial pair. Start another selection to
	# exercise preservation across the room and background lifecycle below.
	app._memory.card_buttons[0].pressed.emit()
	selected = app._memory.memory.selected_indices.duplicate()
	check(not selected.is_empty(), "The lifecycle fixture starts with a partially selected Memory pair")
	app._show_mode_menu()
	app._show_collection()
	await settle()
	check(app.collection_page.visible and not app._mode_menu.visible,
		"Opening the growth notebook closes the gameplay mode popover")
	app._show_mode_menu()
	check(not app._mode_menu.visible, "The room cannot open a second gameplay menu behind itself")
	app._hide_collection()
	await settle()
	app._show_mode_menu()
	app.on_page_hidden()
	check(not app._mode_menu.visible, "Backgrounding closes the transient mode menu")
	app._show_mode_menu()
	check(not app._mode_menu.visible, "A background page cannot reopen the mode menu")
	app.on_page_visible()
	await settle()
	check(not app._mode_menu.visible and app._memory.memory.selected_indices == selected,
		"Returning to the page resumes the existing attempt without reopening the menu")
	app.choose_mode("match")
	await settle()


func _check_layout(app) -> void:
	for dimensions in [Vector2i(320, 320), Vector2i(390, 420), Vector2i(390, 600), Vector2i(390, 640), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 900)]:
		root.size = dimensions
		await settle()
		check(not app._mode_row.is_visible_in_tree(), "Mode choices reserve no closed-menu row at " + str(dimensions))
		var playfield_before: Rect2 = app._match_playfield.get_global_rect()
		app._show_mode_menu()
		await settle()
		var viewport: Rect2 = app.get_global_rect().grow(1)
		var panel: Rect2 = app._mode_panel.get_global_rect()
		var scale: float = app.Style.ui_scale(app)
		check(viewport.encloses(panel) and panel.size.x > 0 and panel.size.y > 0,
			"The anchored popover fits phone, landscape, and desktop bounds: " + str(dimensions))
		check(app._match_playfield.get_global_rect() == playfield_before,
			"Opening the floating menu does not shrink or shift the game board")
		for button: Button in app._mode_buttons:
			var font: Font = button.get_theme_font("font")
			var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			check(button.is_visible_in_tree() and panel.grow(1).encloses(button.get_global_rect())
				and button.size.x * scale >= 44 and button.size.y * scale >= 44,
				"Every popover choice remains visible and touchable at " + str(dimensions))
			check(width <= button.size.x - 8, "Mode labels including the current indicator remain readable: " + button.text)
		app._hide_mode_menu()
		await settle()


func _check_direct_pop_entry(app) -> void:
	for dimensions in [Vector2i(320, 568), Vector2i(844, 390), Vector2i(1366, 900)]:
		root.size = dimensions
		app.choose_mode("match")
		app.choose_mode("pop")
		await settle()
		var ready: Array = _pop_ready_snapshot(app)
		var round_id: String = app._round_id
		check(app._pop.is_visible_in_tree() and app._pop.game.phase == "ready"
			and not app.has_method("_show_leaderboard"),
			"Voice Pop opens directly without a profile gate at " + str(dimensions))
		app._show_mode_menu()
		await settle()
		check(app._mode_menu_open() and not app._pop.interaction_allowed.call(),
			"The mode menu blocks microphone input at " + str(dimensions))
		app._hide_mode_menu()
		app._show_collection()
		await settle()
		check(app.collection_page.visible and not app._pop.interaction_allowed.call(),
			"The growth catalog covers the microphone gate")
		check(_pop_ready_snapshot(app) == ready and app._round_id == round_id,
			"Opening growth preserves the prepared gate and its original Start listening action")
		app._hide_collection()
		await settle()
		check(_pop_ready_snapshot(app) == ready and app._round_id == round_id,
			"Closing growth preserves the prepared round without opening a microphone: before=%s, after=%s" % [
				str(ready), str(_pop_ready_snapshot(app))])
		app.choose_mode("match")
		check(app._mode_id == "match" and not app._mode_menu_open(),
			"The player can leave a ready microphone gate using the mode menu")
