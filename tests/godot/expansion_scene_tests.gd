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
	app.choose_mode("memory")
	check(app._mode_id == "memory" and app._memory.is_visible_in_tree() and not app.grid.visible, "Memory replaces the matching board")
	check(not app.hint_button.visible and not app._voice_button.visible, "Memory hides Match-only controls")
	var word_index := 0
	while app._memory.memory.cards[word_index].kind != "word":
		word_index += 1
	app._memory.card_buttons[word_index].pressed.emit()
	check(app._memory.card_buttons[word_index].word_label.is_visible_in_tree()
		and app._memory.card_buttons[word_index].word_label.get_theme_color("font_color") == Color("#35415e"),
		"A revealed Memory word retains dark readable text")
	app.choose_theme("ocean")
	check(app.model.theme_id == "ocean", "All worlds remain selectable during Memory")
	var selection: Array = app._memory.memory.selected_indices.duplicate()
	app._show_collection()
	app._memory.card_buttons[(word_index + 1) % app._memory.card_buttons.size()].pressed.emit()
	app._memory.study_button.button_down.emit()
	check(app.model.successes == 0 and app.model.mistakes == 0 and app._memory.memory.selected_indices == selection
		and not app._memory.memory.studying, "Covered Memory controls cannot change the attempt under More")
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
	var trick_before: int = app._duck_trick_index
	await _stroke_duck(app.duck)
	check(app._collection_scroll.scroll_vertical == scroll_before, "Stroking Pip belongs to the playground and does not scroll the reward room")
	var has_playground: bool = app._room.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "playground")
	check(has_playground and app._room.playground.interaction_kind == "pet", "A real stroke gives Pip a petting reaction")
	check(app._duck_trick_index == trick_before, "Finishing a petting stroke does not also trigger the old Pip trick")
	app._hide_collection()
	app._controller_mode = true
	app.choose_mode("match")
	var pairs: Array[String] = []
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			pairs.append(card.word.id)
	check(pairs.size() == 3, "The shared lesson supplies exactly three playable Match pairs")
	app.cards[pairs[0] + ":word"].grab_focus()
	app.cards[pairs[0] + ":word"].pressed.emit()
	app.cards[pairs[0] + ":image"].pressed.emit()
	app._show_collection()
	app._hide_collection()
	app._controller_accept()
	check(app._mode_id == "match" and app.model.successes == 1, "Closing More during feedback cannot turn A into a mode change or a duplicate score")
	app._continue_match()
	check(app.cards.values().has(root.gui_get_focus_owner())
		and not app.model.matched_ids.has(root.gui_get_focus_owner().card_data.id),
		"The next prompt restores unmatched-card focus after a modal")
	for word_id in pairs.slice(1):
		app.cards[word_id + ":word"].pressed.emit()
		app.cards[word_id + ":image"].pressed.emit()
		app._continue_match()
	check(app.model.phase == "won" and app.model.successes == 3, "Three Match pairs enter the shared win screen")
	check(app._found_words.get_child_count() == 5, "All five learned words are available for replay")
	app._open_chest()
	app.chest.finish_immediately()
	app._finish_fragment_delivery()
	check(app.medal_progress.count_for("ocean-1") == 1, "A Match win earns one ordinary medal piece")
	app._open_chest()
	check(app.medal_progress.count_for("ocean-1") == 1, "A Match reward cannot be collected twice")
	app._show_collection()
	app._open_reward_preview("ocean-1")
	app._wear_preview_reward()
	check(app._favorite_reward_id == "ocean-1", "An earned medal can be displayed with Pip")
	var saved := ConfigFile.new()
	check(saved.load(app.playroom_save_path.get_basename() + "-v2.cfg") == OK and saved.get_value("playroom", "favorite", "") == "ocean-1", "The favorite survives reload")
	app._hide_collection()
	var lesson: Array = app.model.lesson_words.duplicate(true)
	app._new_adventure_button.pressed.emit()
	check(app._mode_id == "match" and app.model.phase == "waiting" and app.model.successes == 0
		and app.model.mistakes == 0 and app.model.hints_remaining == 3 and app.model.lesson_words != lesson,
		"New adventure starts a fresh Match board with a normal new attempt")
	check(app.model.theme_id == "ocean" and app._favorite_reward_id == "ocean-1"
		and app.medal_progress.count_for("ocean-1") == 1,
		"A fresh adventure preserves the selected world, favorite, and earned piece")
	app.choose_mode("match")
	app.audio.set_muted(false)
	var wrong: Array = []
	for card in app.model.cards:
		if wrong.is_empty() or (card.kind != wrong[0].kind and card.word.id != wrong[0].word.id):
			wrong.append(card)
		if wrong.size() == 2:
			break
	for attempt in range(3):
		app.cards[wrong[0].id].pressed.emit()
		app.cards[wrong[1].id].pressed.emit()
		app._continue_match()
	check(app.model.phase == "lost" and app.model.mistakes == 3, "Three incorrect pairs enter the shared encouragement screen")
	app.choose_mode("match")
	check(app.grid.visible and app.model.cards.size() == 8 and not app._pop.visible and not app._memory.visible,
		"Returning from loss restores the original eight-card game")
	for dimensions in [Vector2i(320, 320), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		await process_frame
		await process_frame
		for mode in ["match", "memory", "pop"]:
			app.choose_mode(mode)
			await process_frame
			await process_frame
			for button in app._mode_buttons:
				check(app.get_global_rect().encloses(button.get_global_rect()), "Mode buttons fit " + str(dimensions))
			var view: Control = app.grid if mode == "match" else app._memory if mode == "memory" else app._pop
			check(app.get_global_rect().grow(1).encloses(view.get_global_rect()), mode + " fits " + str(dimensions))
	app.on_page_hidden()
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Expansion scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _stroke_duck(duck: Control) -> void:
	var start: Vector2 = duck.get_global_rect().get_center() - Vector2(20, 0)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = start if pressed else start + Vector2(44, 0)
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
		if pressed:
			for step in range(1, 5):
				var motion := InputEventMouseMotion.new()
				motion.position = start + Vector2(step * 11, 0)
				motion.global_position = motion.position
				motion.relative = Vector2(11, 0)
				motion.button_mask = MOUSE_BUTTON_MASK_LEFT
				root.push_input(motion, true)
				await process_frame
