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
	var app = load("res://scenes/main.tscn").instantiate()
	if not app.has_method("choose_mode"):
		check(false, "The game offers a choice of modes")
		app.free()
		quit(1)
		return
	var directory := "user://expansion-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	app._mode_id = "match"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app._voice_button.disabled = false
	app._voice_button.focus_mode = Control.FOCUS_ALL
	app._voice_mode = true
	app._toggle_voice()
	check(root.gui_get_focus_owner() == app._voice_button, "Toggling Voice retains keyboard focus after layout changes")
	app.choose_mode("sky")
	check(app._mode_id == "sky" and app._choice.is_visible_in_tree() and not app.grid.visible, "Sky mode replaces the matching board")
	check(not app.hint_button.visible and not app._voice_button.visible, "Choice modes show their own controls")
	check(app._choice.answer_buttons[0].get_theme_color("font_focus_color") == Color("#35415e"), "Focused word choices retain dark readable text")
	app.choose_theme("ocean")
	check(app.model.theme_id == "ocean", "New themes are selectable during a choice round")
	app._show_collection()
	var target: Dictionary = app._choice.current_target
	for button in app._choice.answer_buttons:
		button.pressed.emit()
	check(app.model.successes == 0 and app.model.mistakes == 0 and app._choice.current_target == target, "Covered choice controls cannot answer under Rewards")
	app._room.action_button.pressed.emit()
	check(app._playroom_caption.text.to_lower().contains("ball"), "The room toy action gives visible play feedback")
	app._collection_scroll.scroll_vertical = app._collection_max_scroll().y
	await process_frame
	await process_frame
	app.duck.grab_focus()
	await process_frame
	await process_frame
	check(app._collection_scroll.get_global_rect().encloses(app.duck.get_global_rect()), "Keyboard focus scrolls Pip into view")
	var scroll_before: int = app._collection_scroll.scroll_vertical
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(80, 100)
	app.duck.gui_input.emit(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(80, 50)
	drag.relative = Vector2(0, -50)
	app.duck.gui_input.emit(drag)
	app._end_collection_drag(false)
	check(app._collection_scroll.scroll_vertical > scroll_before, "Swiping over Pip scrolls the reward room")
	var trick_before: int = app._duck_trick_index
	app.duck.pressed.emit()
	check(app._duck_trick_index == trick_before, "A swipe release does not also trigger a Pip trick")
	app._hide_collection()
	app._controller_mode = true
	app._choice.answer_buttons[0].grab_focus()
	app._choice.answer_buttons[app._choice.choices.find(app._choice.current_target)].pressed.emit()
	app._show_collection()
	app._hide_collection()
	app._controller_accept()
	check(app._mode_id == "sky" and app._choice.successes == 1, "Closing Rewards during feedback cannot turn A into a mode change")
	app._choice.continue_feedback()
	check(app._choice.answer_buttons.has(root.gui_get_focus_owner()), "The next prompt restores choice focus after a modal")
	for answer in range(4):
		var correct_index: int = app._choice.choices.find(app._choice.current_target)
		check(correct_index >= 0, "Every flying picture has a matching word choice")
		app._choice.answer_buttons[correct_index].pressed.emit()
		app._choice.continue_feedback()
	check(app.model.phase == "won" and app.model.successes == 5, "Five choice answers enter the shared win screen")
	check(app._found_words.get_child_count() == 5, "All five learned words are available for replay")
	app._open_chest()
	app.chest.finish_immediately()
	app._finish_fragment_delivery()
	check(app.medal_progress.count_for("ocean-1") == 1, "A choice win earns one ordinary medal piece")
	app._open_chest()
	check(app.medal_progress.count_for("ocean-1") == 1, "A choice reward cannot be collected twice")
	app._show_collection()
	app._open_reward_preview("ocean-1")
	app._wear_preview_reward()
	check(app._favorite_reward_id == "ocean-1", "An earned medal can be displayed with Pip")
	var saved := ConfigFile.new()
	check(saved.load(app.playroom_save_path.get_basename() + "-v2.cfg") == OK and saved.get_value("playroom", "favorite", "") == "ocean-1", "The favorite survives reload")
	app._hide_collection()
	var lesson: Array = app.model.lesson_words.duplicate(true)
	app._replay()
	check(app._mode_id == "sky" and app.model.phase == "waiting" and app._choice.successes == 0
		and app.model.lesson_words == lesson, "Repeat lesson preserves the mode and words with fresh progress")
	app.audio.set_muted(false)
	app.choose_mode("listen")
	check(app._choice.hear_button.is_visible_in_tree(), "Listening mode offers an explicit replayable Hear control")
	for attempt in range(3):
		var wrong_index: int = 1 - app._choice.choices.find(app._choice.current_target)
		app._choice.answer_buttons[wrong_index].pressed.emit()
		app._choice.continue_feedback()
	check(app.model.phase == "lost" and app.model.mistakes == 3, "Three incorrect choices enter the shared encouragement screen")
	app.choose_mode("match")
	check(app.grid.visible and app.model.cards.size() == 8 and not app._choice.visible, "Switching back restores the original eight-card game")
	for dimensions in [Vector2i(320, 320), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		await process_frame
		await process_frame
		for mode in ["match", "sky", "listen"]:
			app.choose_mode(mode)
			await process_frame
			await process_frame
			for button in app._mode_buttons:
				check(app.get_global_rect().encloses(button.get_global_rect()), "Mode buttons fit " + str(dimensions))
			if mode != "match":
				for button in app._choice.answer_buttons:
					check(app.get_global_rect().encloses(button.get_global_rect()), "Choice buttons fit " + str(dimensions))
	app.on_page_hidden()
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Expansion scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
