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
		app.model.selected_id, app.model.phase, app.model.successes, app.model.mistakes, app.model.hints_remaining]


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
	app.playroom_save_path = directory + "/room.cfg"
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
	await _check_pop_picker_header(app)
	await _check_finished_picker_room_return(app)
	app.audio.halt()
	app.queue_free()
	await process_frame
	await _check_onboarding_header()
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
			check(not app._mode_menu.visible and app._leaderboard_overlay.visible,
				"Voice Pop closes its chooser before presenting the existing player selection")
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
		"Opening Pip's room closes its gameplay mode popover")
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


func _picker_player(app) -> Button:
	var player_id: String = str(app.leaderboard_state.profiles[0].id)
	return app._leaderboard_panel.find_child("LeaderboardPlayer_" + player_id, true, false) as Button


func _check_pop_picker_header(app) -> void:
	for dimensions in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 900), Vector2i(320, 320)]:
		root.size = dimensions
		await settle()
		var match_header: Rect2 = app._header.get_global_rect()
		var match_pip: Rect2 = app.duck.get_global_rect()
		var match_more: Rect2 = app.collection_button.get_global_rect()
		await _tap(match_pip.get_center())
		await _tap(_choice(app, "pop").get_global_rect().get_center())
		check(app._pop_picker_open() and not app._mode_menu_open(),
			"Selecting Voice Pop opens its player picker beneath the shared header at " + str(dimensions))
		var viewport: Rect2 = app.get_global_rect()
		var picker: Rect2 = app._leaderboard_overlay.get_global_rect()
		var scroll: Rect2 = app._leaderboard_scroll.get_global_rect()
		var scale: float = app.Style.ui_scale(app)
		check(app._header.get_global_rect().is_equal_approx(match_header)
			and app.duck.get_global_rect().is_equal_approx(match_pip)
			and app.collection_button.get_global_rect().is_equal_approx(match_more),
			"Voice Pop player selection retains Match's exact Pip and More header placement at " + str(dimensions))
		check(app.duck.is_visible_in_tree() and app._valid_focus(app.duck)
			and app.collection_button.is_visible_in_tree() and app._valid_focus(app.collection_button),
			"Pip and More remain visible and keyboard reachable before choosing a player at " + str(dimensions))
		check(viewport.grow(1).encloses(picker) and picker.position.y >= match_header.end.y - 1
			and picker.size.y > 0 and not picker.intersects(match_pip) and not picker.intersects(match_more),
			"The player picker occupies the body without covering the shared header at " + str(dimensions))
		check(picker.grow(1).encloses(scroll) and scroll.size.x > 0 and scroll.size.y > 0
			and not app._leaderboard_close.is_visible_in_tree(),
			"The player list keeps a usable scroll viewport without a duplicate Back header at " + str(dimensions))
		check(not app._pop.interaction_allowed.call() and not app._valid_focus(app._pop.retry_button),
			"Keeping header navigation available does not expose underlying Voice Pop gameplay")
		var player := _picker_player(app)
		check(is_instance_valid(player) and app._valid_focus(player)
			and player.size.x * scale >= 44 and player.size.y * scale >= 44,
			"The player avatar remains a focusable touch target at " + str(dimensions))
		if is_instance_valid(player):
			player.grab_focus()
			app._leaderboard_scroll.ensure_control_visible(player)
			await settle()
			check(app._leaderboard_scroll.get_global_rect().grow(1).encloses(player.get_global_rect()),
				"Keyboard focus can reveal the complete player avatar in the picker body at " + str(dimensions))
		var ready: Array = _pop_ready_snapshot(app)
		var round_id: String = app._leaderboard_round_id
		await _tap(app.duck.get_global_rect().get_center())
		check(app._mode_menu_open() and app._pop_picker_open() and _choice(app, "pop").has_focus()
			and app._valid_focus(_choice(app, "pop")),
			"Pip opens and focuses the game-mode popover above the player picker")
		check(not app._leaderboard_scroll.interaction_allowed.call() and not app._valid_focus(player),
			"The mode popover suspends picker scrolling and player focus")
		for step in range(5):
			app._move_focus(Vector2.DOWN)
			check(app._mode_panel.is_ancestor_of(root.gui_get_focus_owner()),
				"Controller navigation stays inside the mode popover over the player picker")
		await _escape()
		check(not app._mode_menu_open() and app._pop_picker_open() and app.duck.has_focus()
			and _pop_ready_snapshot(app) == ready and app._leaderboard_round_id == round_id
			and app._pop_player_id.is_empty(),
			"Dismissing modes restores the unchanged player picker without assigning a player or starting speech")
		await _tap(app.duck.get_global_rect().get_center())
		await _tap(_choice(app, "pop").get_global_rect().get_center())
		check(app._pop_picker_open() and not app._mode_menu_open()
			and _pop_ready_snapshot(app) == ready and app._leaderboard_round_id == round_id,
			"Choosing the current Voice Pop mode keeps the same unstarted player selection")
		await _tap(app.collection_button.get_global_rect().get_center())
		check(app.collection_page.visible and not app._leaderboard_overlay.visible
			and not app._mode_menu_open() and app._pop_player_id.is_empty() and not app._pop_speech_active,
			"More opens Pip's room directly from player selection without starting a round")
		await _tap(app._collection_back.get_global_rect().get_center())
		check(not app.collection_page.visible and app._pop_picker_open() and app.duck.is_visible_in_tree()
			and app._pop_player_id.is_empty() and not app._pop_speech_active
			and not app._pop._listening and not app._pop._pending
			and app._leaderboard_round_id == round_id and app._pop.game.remaining == float(ready[1]),
			"Leaving Pip's room restores player selection and its unchanged round without a microphone request")
		await _tap(app.duck.get_global_rect().get_center())
		await _tap(_choice(app, "match").get_global_rect().get_center())
		check(app._mode_id == "match" and not app._leaderboard_overlay.visible
			and not app._mode_menu_open() and app._leaderboard_gate.is_empty()
			and app._pop_player_id.is_empty() and not app._pop_speech_active,
			"The shared Pip header can leave Voice Pop before a player is selected")
		check(app._valid_focus(app.duck) and app._valid_focus(app.collection_button)
			and app._valid_focus(app._default_focus()),
			"Leaving player selection restores the normal Match focus controls")
	await _tap(app.collection_button.get_global_rect().get_center())
	await _tap(app._collection_back.get_global_rect().get_center())
	check(app._mode_id == "match" and not app._leaderboard_overlay.visible,
		"A later Match room visit cannot restore an abandoned Voice Pop picker")
	await _tap(app.duck.get_global_rect().get_center())
	await _tap(_choice(app, "pop").get_global_rect().get_center())
	var player := _picker_player(app)
	if is_instance_valid(player):
		player.grab_focus()
		app._leaderboard_scroll.ensure_control_visible(player)
		await settle()
		await _tap(player.get_global_rect().get_center())
		check(app._pop_player_id == str(app.leaderboard_state.profiles[0].id)
			and not app._leaderboard_overlay.visible and app._leaderboard_gate.is_empty(),
			"The visible player avatar still starts its assigned round through a real pointer click")
	else:
		check(false, "Returning to Voice Pop recreates a usable player avatar")


func _check_finished_picker_room_return(app) -> void:
	root.size = Vector2i(390, 844)
	await settle()
	var player_id: String = app._pop_player_id
	check(not player_id.is_empty(), "The replay picker fixture starts with an assigned player")
	if player_id.is_empty():
		return
	app._on_voice_state([true, true, "Listening"])
	app._pop._advance_game(60.0)
	await settle()
	check(app._pop.game.phase == "finished" and not app._pop_rewards.has_pending(),
		"The replay picker fixture finishes a real zero-hit round without pending treasure")
	var round_id: String = app._leaderboard_round_id
	app._pop.replay_button.grab_focus()
	await settle()
	await _tap(app._pop.replay_button.get_global_rect().get_center())
	check(app._pop_picker_open() and app._pop_player_id == player_id,
		"Play again opens player selection while preserving the completed round's owner")
	await _tap(app.collection_button.get_global_rect().get_center())
	check(app.collection_page.visible and not app._leaderboard_overlay.visible,
		"More opens Pip's room from the replay player picker")
	await _tap(app._collection_back.get_global_rect().get_center())
	check(app._pop_picker_open() and not app.collection_page.visible
		and app.duck.is_visible_in_tree() and app._valid_focus(app.duck)
		and app._pop_player_id == player_id and app._leaderboard_round_id == round_id
		and app._pop.game.phase == "finished" and not app._pop_speech_active
		and not app._pop._listening and not app._pop._pending and not app._pop._reconnecting,
		"Returning from More restores the replay picker, Pip, and finished round with the microphone stopped")


func _check_onboarding_header() -> void:
	root.size = Vector2i(390, 844)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/onboarding-medals.cfg", directory + "/onboarding-legacy.cfg")
	app.playroom_save_path = directory + "/onboarding-room.cfg"
	app.pop_reward_save_path = directory + "/onboarding-pop-rewards.cfg"
	app.leaderboard_state = load("res://scripts/leaderboard_state.gd").new(directory + "/onboarding-players.cfg")
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app._on_loading_finished(["summer"])
	await settle()
	check(app._leaderboard_gate == "onboarding" and app._leaderboard_overlay.visible
		and not app._pop_picker_open() and app._leaderboard_overlay.z_index >= 200
		and app._leaderboard_overlay.get_global_rect().is_equal_approx(app.get_global_rect()),
		"First-player onboarding retains its full-screen modal presentation")
	check(not app.duck.is_visible_in_tree() and not app._valid_focus(app.collection_button)
		and not app._leaderboard_close.is_visible_in_tree(),
		"Mandatory onboarding exposes no Pip, More, or Back escape")
	await _tap(app._header_duck_art_slot.get_global_rect().get_center())
	await _tap(app.collection_button.get_global_rect().get_center())
	app._show_mode_menu()
	app.choose_mode("pop")
	check(app._leaderboard_gate == "onboarding" and app._leaderboard_overlay.visible
		and app._mode_id == "match" and not app._mode_menu_open() and not app.collection_page.visible,
		"Covered header gestures and mode actions cannot bypass first-player creation")
	app.audio.halt()
	app.queue_free()
	await process_frame
