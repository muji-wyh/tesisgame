extends SceneTree

const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")

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
	var app = load("res://scenes/main.tscn").instantiate()
	if not app.get_property_list().any(func(p: Dictionary) -> bool: return p.name == "_memory"):
		check(false, "Main scene offers Memory")
		app.free()
		quit(1)
		return
	var directory := "res://build/memory-scene-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var progress_script = app.medal_progress.get_script()
	app.medal_progress = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await process_frame
	await process_frame
	check(app.coin_wallet.credit("fixture:memory-peek-funding", 1000).ok,
		"Fund repeated Memory reveals through the isolated wallet's real credit API")
	app._coin_flight.sync(app.coin_wallet.balance)
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.choose_theme("spring")
	var lesson: Array = app.model.lesson_words.duplicate(true)
	PlayerFixture.enter_mode(app, "memory")
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	preload("res://tests/godot/player_flow_fixture.gd").reserve_pair_chest(app)
	await process_frame
	await process_frame
	var view = app._memory
	check(view.memory.cards.size() == 10, "The integrated Root starts a complete Memory round")
	if view.memory.cards.size() != 10:
		await _finish(app, directory)
		return
	check(view.is_visible_in_tree() and app._mode_buttons.size() == 6 and app.MODES.keys() == ["match", "memory", "pop", "phrase", "jelly", "word_jelly"],
		"Memory remains available alongside Match, Voice Pop, Phrase Builder and Jelly Match")
	check(view.study_button.get_parent() == app._toolbar and view._board.position == Vector2.ZERO and view._board.size == view.size,
		"Root owns the eye while Memory cards fill their entire assigned view")
	check(not view.status_label.visible and view.find_child("FlowerProgress", true, false) == null and view.find_child("FlowerCount", true, false) == null,
		"The Memory board has no redundant instruction or progress row")
	check(app.model.lesson_words == lesson and app.model.theme_id == "spring", "Memory retains the lesson and selected world")
	check(not app.grid.visible and not app._pop.visible, "Memory hides the other mode boards")
	var pip_pixels: float = app._header_duck_art_slot.size.x * app.Style.ui_scale(app)
	var profile_bounds: Rect2 = app._header_duck_slot.get_global_rect().grow(0.1)
	check(app.find_child("MemoryProgress", true, false) == null and app.find_child("MemoryMistakes", true, false) == null
		and pip_pixels >= 44.0 and pip_pixels <= 56.0
		and is_equal_approx(app._header_duck_art_slot.size.x, app._header_duck_art_slot.size.y)
		and profile_bounds.encloses(app._header_duck_art_slot.get_global_rect())
		and profile_bounds.encloses(app._growth_button.get_global_rect()),
		"Memory fits a compact square Pip and growth control in its profile without obsolete mode counters")
	check(app._status_announcement.contains("Memory") and app._status_announcement.contains("0 of 5"), "Memory announces its own goal and progress")
	var board: Array = view.memory.cards.duplicate(true)
	var target_rects: Array = view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect())
	var field_rect: Rect2 = view.get_global_rect()
	view.card_buttons[0].pressed.emit()
	await process_frame
	await process_frame
	check(view.memory.selected_indices == [0], "An actual card button reveals a card")
	check(view.get_global_rect() == field_rect and view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect()) == target_rects, "A first reveal does not move the host playfield or any Memory target")
	app._controller_back()
	check(view.memory.selected_indices.is_empty(), "Xbox B or Escape cancels a Memory selection")
	view.card_buttons[0].grab_focus()
	app._controller_accept()
	check(view.memory.selected_indices == [0], "Xbox A reveals the focused Memory card")
	PlayerFixture.enter_mode(app, "memory")
	check(view.memory.selected_indices == [0] and view.memory.cards == board, "Selecting the current Home card retains the attempt")
	app.on_page_hidden()
	app.set_reduced_motion(false)
	app.set_reduced_motion(true)
	app.choose_theme("ocean")
	check(view.memory.selected_indices == [0] and view.memory.cards == board, "Page hiding, motion and palette changes preserve the board")
	check(view.controls().is_empty(), "Page hiding suspends native Memory input")
	app.on_page_visible()
	check(not app.audio.voice.playing, "Returning to the page never resumes pronunciation automatically")
	view.card_buttons[0].grab_focus()
	app._show_collection()
	view.card_buttons[1].pressed.emit()
	view.study_button.pressed.emit()
	app.choose_mode("match")
	check(view.memory.selected_indices == [0] and not view.memory.studying and app._mode_id == "memory", "Covered controls cannot mutate the attempt")
	app._hide_collection()
	check(root.gui_get_focus_owner() == view.card_buttons[0], "Closing rewards restores the selected card's keyboard focus")
	view.study_button.pressed.emit()
	check(view.memory.studying and view.memory.selected_indices.is_empty(), "Clicking the eye clears unfinished selections")
	check(app._default_focus() == view.study_button, "The active eye remains the default Memory control")
	app._controller_back()
	check(not view.memory.studying, "Xbox B or Escape releases the eye without resetting the board")
	view.study_button.grab_focus()
	var peeks_before: int = view.memory.peeks
	await _joy_accept(true)
	check(view.memory.studying and view.memory.peek_duration == 5.0 and view.memory.peeks == peeks_before + 1,
		"Native Xbox A activates one five-second reveal")
	await _joy_accept(false)
	check(view.memory.studying and view.memory.peeks == peeks_before + 1,
		"Native Xbox A release leaves the countdown running")
	var remaining: float = view.memory.peek_remaining
	await _joy_accept(true)
	await _joy_accept(false)
	check(view.memory.studying and view.memory.peek_remaining <= remaining and view.memory.peeks == peeks_before + 1,
		"Repeated Xbox clicks neither close nor restart the countdown")
	app._on_joy_connection_changed(0, false)
	check(not view.memory.studying and view.memory.peek_remaining == 0.0, "Controller disconnect cancels the active countdown")
	await _joy_accept(false)
	view.begin_peek()
	app.on_page_hidden()
	check(not view.memory.studying and view.controls().is_empty(), "A hidden page cancels the eye and suspends play")
	app.on_page_visible()
	check(_all_hidden(view) and not app.audio.voice.playing, "Returning to the page restores concealed play without audio")
	var word_index := -1
	var image_index := -1
	for index in range(board.size()):
		if board[index].kind == "word":
			word_index = index
			break
	for index in range(board.size()):
		if board[index].kind == "image" and board[index].word.id != board[word_index].word.id:
			image_index = index
			break
	for attempt in range(4):
		view.card_buttons[word_index].pressed.emit()
		view.card_buttons[image_index].pressed.emit()
		await process_frame
		await process_frame
		check(view.card_buttons.all(func(card: Button) -> bool: return card.is_visible_in_tree()), "The real scene keeps every remembered card visible during feedback")
		check(view.get_global_rect() == field_rect and view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect()) == target_rects, "Feedback does not resize or move the host board")
		check(app.model.phase != "lost", "Memory exploration never ends the game after a mismatch")
		check(view.controls().has(app._default_focus()), "Feedback focus stays on an available board control")
		app._show_collection()
		view.continue_feedback()
		check(view.memory.phase == "feedback", "Covered feedback cannot continue")
		app._hide_collection()
		view.continue_feedback()
		await process_frame
		await process_frame
		check(view.get_global_rect() == field_rect and view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect()) == target_rects, "Continue retains the original host card targets")
	check(view.memory.attempts == 4 and view.memory.mistakes == 4 and app.model.mistakes == 0 and app.model.phase != "lost",
		"Memory retains attempt and mistake records without changing the Match model or limiting retries")
	for word in lesson:
		for index in range(board.size()):
			if board[index].word.id == word.id:
				view.card_buttons[index].pressed.emit()
		check(app.model.phase != "won", "A correct pair displays bounded feedback before the final result")
		if view.memory.matched_word_ids.size() == 5:
			view.begin_peek()
			view._choose(-1)
			for button in view.card_buttons:
				button.pressed.emit()
			check(view.memory.phase == "feedback" and view.study_button.disabled and not view.memory.studying and app.model.phase != "won",
				"The fifth pair finishes its feedback automatically, without a peek delay")
			check(view.memory.attempts == 9 and view.memory.matched_word_ids.size() == 5 and app.medal_progress.counts.is_empty(), "Final blocked shortcuts cannot change score or claim rewards")
			var final_focus: Control = root.gui_get_focus_owner()
			check(app._valid_focus(final_focus) and view.controls().is_empty(), "Final feedback leaves focus on a valid host control, not a removed footer")
			await _tap_control(view.card_buttons[0])
			check(root.gui_get_focus_owner() == final_focus, "A planted final card cannot steal host focus")
			await _tap_control(view.study_button)
			check(root.gui_get_focus_owner() == final_focus, "A disabled final eye cannot steal host focus")
			await create_timer(0.8).timeout
			check(app.model.phase == "won" and view.memory.phase == "won", "Final feedback automatically completes in the real scene")
		else:
			check(view.controls().has(root.gui_get_focus_owner()), "A judged nonfinal pair keeps actual focus on playable cards")
			view.continue_feedback()
	check(app.model.phase == "won" and view.memory.matched_word_ids.size() == 5, "Five completed pairs enter the ordinary victory screen")
	check(not app.chest_button.is_visible_in_tree(), "Final pair feedback cannot expose early chest controls")
	app._advance_ui(app._pair_reward.REWARD_SECONDS + 0.01)
	check(app._round_celebration.is_active() and not app.chest_button.is_visible_in_tree(),
		"The completed Memory round presents the shared celebration before its unopened chest")
	preload("res://tests/godot/player_flow_fixture.gd").finish_celebration(app)
	check(view.is_visible_in_tree() and app._settlement_dialog.is_visible_in_tree()
		and app.chest_button.is_visible_in_tree() and not app._single_result.replay_button.disabled
		and not app._single_result.home_button.disabled,
		"The completed Memory board stays behind its unopened chest with automatic-settlement departure actions available")
	check(app.medal_progress.counts.is_empty(), "Completing Memory alone does not fabricate a reward claim")
	var coins_before_chest: int = app.coin_wallet.balance
	app._open_chest()
	check(app.medal_progress.count_for("ocean-1") == 1, "Memory grants one ordinary piece in the selected world")
	var chest_receipt: String = "pair:memory:" + app._round_id
	var earned_receipts: Dictionary = app.coin_wallet._receipts.duplicate()
	app.chest._advance_animation(60.0)
	check(app.model.chest_state == "opened" and app.chest.mode == "opened"
		and app.coin_wallet.balance == coins_before_chest + 50 and earned_receipts.get(chest_receipt, 0) == 50
		and not app.chest.hold_effect_snapshot().opened_effect.active,
		"The opened Memory chest retains its earned piece and one saved coin receipt after its flourish settles")
	app.on_page_hidden()
	app.chest._advance_animation(60.0)
	check(app.model.chest_state == "opened" and app.chest.mode == "opened"
		and app.medal_progress.count_for("ocean-1") == 1 and app.coin_wallet._receipts == earned_receipts
		and app.coin_wallet.balance == coins_before_chest + 50,
		"Backgrounding Memory preserves its opened chest, earned piece, and exact saved coin award")
	app.on_page_visible()
	app.chest._advance_animation(60.0)
	check(app.model.chest_state == "opened" and app.chest.mode == "opened"
		and app.medal_progress.count_for("ocean-1") == 1 and app.coin_wallet._receipts == earned_receipts
		and app.coin_wallet.balance == coins_before_chest + 50 and not app.chest.hold_effect_snapshot().opened_effect.active,
		"Returning to Memory retains the same opened result without replaying or paying another reward")
	view.continue_feedback()
	view.round_finished.emit(true, lesson)
	app._on_chest_opened()
	app._open_chest()
	check(app.medal_progress.count_for("ocean-1") == 1 and app.coin_wallet._receipts == earned_receipts
		and app.coin_wallet.balance == coins_before_chest + 50,
		"Duplicate completion and chest callbacks cannot award extra pieces or coins")
	var reloaded = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	check(reloaded.load_progress() and reloaded.count_for("ocean-1") == 1, "Memory rewards survive storage reload")
	check(app.new_round(-1, true), "A same-lesson internal reset prepares another Memory fixture")
	check(not app.chest.hold_effect_snapshot().opened_effect.active,
		"A new Memory round clears the opening flourish from the previous result")
	check(app._mode_id == "memory" and app.model.lesson_words == lesson and app.model.theme_id == "ocean",
		"The internal Memory fixture reset preserves its mode, lesson, and world")
	check(view.memory.attempts == 0 and view.memory.matched_word_ids.is_empty(), "The fixture reset clears the prior attempt")
	PlayerFixture.enter_mode(app, "match")
	view.round_finished.emit(true, lesson)
	check(app.model.phase != "won" and view.memory.phase == "stopped", "Leaving Memory blocks stale completion")
	for mode in ["match", "memory", "pop", "phrase"]:
		PlayerFixture.enter_mode(app, mode)
		if mode == "pop":
			preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
		check(app._mode_id == mode and app.model.lesson_words == lesson, "The " + mode + " mode remains reachable with the same shared lesson")
	await _check_feedback_shortcut_focus(app)
	await _check_host_layout(app)
	await _check_countdown_presentation(app)
	if "--screenshots" in OS.get_cmdline_user_args():
		await _capture_scenes(app)
	await _finish(app, directory)


func _finish(app, directory: String) -> void:
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Memory scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_feedback_shortcut_focus(app) -> void:
	for correct in [false, true]:
		for action in ["card", "study"]:
			PlayerFixture.enter_mode(app, "match")
			PlayerFixture.enter_mode(app, "memory")
			await process_frame
			await process_frame
			var view = app._memory
			var first := -1
			var second := -1
			var target := -1
			for index in range(view.memory.cards.size()):
				if view.memory.cards[index].kind == "word":
					first = index
					break
			for index in range(view.memory.cards.size()):
				var card: Dictionary = view.memory.cards[index]
				if card.kind == "image" and (card.word.id == view.memory.cards[first].word.id) == correct:
					second = index
				if index > 0 and card.kind == "word" and card.word.id != view.memory.cards[first].word.id:
					target = index
			view.card_buttons[first].pressed.emit()
			view.card_buttons[second].pressed.emit()
			var score: Array = [view.memory.attempts, view.memory.mistakes, view.memory.matched_word_ids.duplicate(), view.memory.matched_word_ids.size(), app.medal_progress.counts.duplicate(true)]
			var board: Array = view.memory.cards.duplicate(true)
			var positions: Array = view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect())
			check(view.controls().has(root.gui_get_focus_owner()) and view.controls().has(app._default_focus()), "Wrong and correct feedback keep focus on the board")
			var control: Button = view.study_button if action == "study" else view.card_buttons[target]
			await _mouse_control(control, true)
			await _mouse_control(control, false)
			check(root.gui_get_focus_owner() == control, "The first " + action + " input moves actual host focus to its target")
			check(view.memory.phase != "feedback", "The first " + action + " input resolves nonfinal feedback")
			if action == "card":
				check(view.memory.phase == "matching" and view.memory.selected_indices == [target], "The host keeps only the first tapped new card selected")
			else:
				check(view.memory.studying and view.memory.selected_indices.is_empty() and app._default_focus() == view.study_button,
					"The host begins a timed peek after a completed eye click")
				check(view.memory.phase == "waiting" and root.gui_get_focus_owner() == view.study_button,
					"Eye click retains focus while the countdown reveals the board")
				view._advance_peek(view.memory.peek_remaining)
				check(not view.memory.studying and root.gui_get_focus_owner() == view.study_button,
					"Expiry restores concealed play while preserving eye focus")
			check([view.memory.attempts, view.memory.mistakes, view.memory.matched_word_ids, view.memory.matched_word_ids.size(), app.medal_progress.counts] == score, "First-tap feedback shortcuts preserve host score and rewards")
			check(view.memory.cards == board and view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect()) == positions, "First-tap feedback shortcuts keep the host board stationary")


func _tap_control(control: Control) -> void:
	for pressed in [true, false]:
		await _mouse_control(control, pressed)


func _mouse_control(control: Control, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _joy_accept(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _all_hidden(view) -> bool:
	return range(10).all(func(index: int) -> bool: return not view.memory.is_revealed(index))


func _check_host_layout(app) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions in [Vector2i(480, 480), Vector2i(480, 900), Vector2i(480, 480)]:
		root.size = dimensions
		PlayerFixture.enter_mode(app, "match")
		PlayerFixture.enter_mode(app, "memory")
		for frame in range(4):
			await process_frame
		var view = app._memory
		var bounds: Rect2 = root.get_visible_rect().grow(0.5)
		check(bounds.encloses(view.get_global_rect()), "Mode changes and resizing keep the Memory playfield on screen at " + str(dimensions))
		check(is_equal_approx(view._board.position.y + view._board.size.y, view.size.y),
			"The Memory board reaches the bottom of its real host view without a footer")
		check(view._board.position == Vector2.ZERO, "Root's toolbar eye reserves no Memory header")
		var columns: int = 2
		var rows: int = 10 / columns
		var gap: float = ceilf(8 / load("res://scripts/ui_style.gd").ui_scale(view))
		var cell := Vector2((view.size.x - gap * (columns - 1)) / columns, (view.size.y - gap * (rows - 1)) / rows)
		for index in range(view.card_buttons.size()):
			var card: Button = view.card_buttons[index]
			check(bounds.encloses(card.get_global_rect()), "Every Memory target fits the real host after resizing")
			check(card.position.is_equal_approx(Vector2((index % columns) * (cell.x + gap), (index / columns) * (cell.y + gap)))
				and card.size.is_equal_approx(cell), "Every real-scene row is complete and uniformly sized")


func _check_countdown_presentation(app) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions in [Vector2i(320, 568), Vector2i(393, 852), Vector2i(1280, 800)]:
		root.size = dimensions
		check(app.new_round(409, false, "", "memory"), "A fresh round prepares the responsive countdown fixture")
		app.set_reduced_motion(true)
		for frame in range(4):
			await process_frame
		var view = app._memory
		var countdown = app._memory_peek_countdown
		var board_bounds: Rect2 = view.get_global_rect()
		var card_bounds: Array = view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect())
		check(not countdown.is_visible_in_tree(), "The countdown takes no visible attention before opening the eye")
		view.study_button.pressed.emit()
		var display: Dictionary = countdown.snapshot()
		check(display.visible and display.seconds == 10 and is_equal_approx(float(display.progress), 1.0),
			"The first reveal displays ten seconds and a full progress bar at " + str(dimensions))
		var area: Rect2 = countdown.get_global_rect()
		var bar: Rect2 = countdown.bar_rect()
		bar.position += countdown.global_position
		var number: Rect2 = countdown.text_rect()
		number.position += countdown.global_position
		check(root.get_visible_rect().grow(0.5).encloses(area) and area.encloses(bar) and area.encloses(number)
			and bar.has_area() and not bar.intersects(number) and not area.intersects(board_bounds),
			"Countdown text and progress fit on screen without overlapping each other or the board")
		check(countdown.mouse_filter == Control.MOUSE_FILTER_IGNORE and countdown.focus_mode == Control.FOCUS_NONE,
			"The decorative countdown cannot intercept gameplay input or keyboard navigation")
		view._advance_peek(6.25)
		display = countdown.snapshot()
		check(display.seconds == 4 and is_equal_approx(float(display.progress), 0.375)
			and str(countdown.get("accessibility_name")).contains("4"),
			"Visible seconds, accessible text and fractional progress agree with elapsed time")
		check(view.get_global_rect() == board_bounds and view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect()) == card_bounds,
			"Opening and updating the countdown never shrinks or moves any Memory target")
		view._advance_peek(view.memory.peek_remaining)
		check(not countdown.is_visible_in_tree() and not view.memory.studying,
			"Automatic expiry removes the countdown and conceals the unmatched cards")
		PlayerFixture.reserve_pair_chest(app)
		var first_word: String = str(view.memory.cards[0].word.id)
		for card in view.card_buttons:
			if card.card_data.word.id == first_word:
				card.pressed.emit()
		view.continue_feedback()
		app._pair_reward.advance(app._pair_reward.REWARD_SECONDS + 0.01)
		app._refresh()
		check(app.model.chest_earned and app._pair_reward.chest.is_visible_in_tree(),
			"A real successful pair supplies the earned-chest coexistence fixture")
		var chest_bounds: Rect2 = app._pair_reward.chest.get_global_rect()
		board_bounds = view.get_global_rect()
		check(app.coin_wallet.credit("fixture:timed-peek:" + str(dimensions), 2).ok, "Fund the later five-second presentation")
		view.study_button.pressed.emit()
		check(countdown.is_visible_in_tree() and countdown.seconds == 5 and countdown.progress() == 1.0
			and app._pair_reward.chest.is_visible_in_tree() and not app._pair_reward._title.visible
			and not app._pair_reward._surface_layer.visible,
			"The five-second timer shares the row with the earned chest while suppressing the old message")
		check(app._pair_reward.chest.get_global_rect() == chest_bounds and view.get_global_rect() == board_bounds,
			"A later countdown preserves the earned chest and playfield positions")
		check(countdown.reduced_motion and not countdown.is_processing(),
			"Reduced motion keeps the functional clock while disabling decorative motion")
		view._advance_peek(5.0)
		check(not countdown.is_visible_in_tree() and app._pair_reward._title.visible
			and app._pair_reward._surface_layer.visible and app._pair_reward.chest.is_visible_in_tree(),
			"Expiry restores the existing reward presentation without removing the earned chest")


func _capture_scenes(app) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	app.set_reduced_motion(false)
	app.choose_theme("spring")
	for dimensions in [Vector2i(480, 480), Vector2i(480, 900)]:
		root.size = dimensions
		PlayerFixture.enter_mode(app, "match")
		PlayerFixture.enter_mode(app, "memory")
		await process_frame
		await process_frame
		var view = app._memory
		var first := -1
		var partner := -1
		var wrong := -1
		for index in range(view.memory.cards.size()):
			if view.memory.cards[index].kind == "word":
				first = index
				break
		for index in range(view.memory.cards.size()):
			var card: Dictionary = view.memory.cards[index]
			if card.kind == "image":
				if card.word.id == view.memory.cards[first].word.id:
					partner = index
				else:
					wrong = index
		var prefix := "memory-%dx%d-" % [dimensions.x, dimensions.y]
		await _save_capture(prefix + "waiting")
		view.card_buttons[first].pressed.emit()
		await _save_capture(prefix + "reveal")
		view.card_buttons[wrong].pressed.emit()
		await _save_capture(prefix + "wrong")
		view.continue_feedback()
		view.begin_peek()
		await create_timer(0.25).timeout
		await _save_capture(prefix + "peek")
		view.end_peek()
		await create_timer(0.25).timeout
		await _save_capture(prefix + "concealed")
		view.card_buttons[first].pressed.emit()
		view.card_buttons[partner].pressed.emit()
		await _save_capture(prefix + "correct")
		view.continue_feedback()
		await create_timer(0.25).timeout
		await _save_capture(prefix + "planted")


func _save_capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://build/visuals"
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory + "/" + filename + ".png") == OK, "The actual Memory scene renders " + filename)
