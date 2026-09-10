extends SceneTree

var checks := 0
var failures := 0

class BrowserStorage extends RefCounted:
	var text: Variant = null
	var writable := true
	func playroomState() -> Variant:
		return text
	func savePlayroomState(value: String) -> bool:
		if not writable:
			return false
		text = value
		return true

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	if not app.get_property_list().any(func(p: Dictionary) -> bool: return p.name == "_word_book"):
		check(false, "My rewards includes the word sticker album")
		app.free()
		quit(1)
		return
	var directory := "user://word-sticker-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app._word_book.word_buttons.is_empty(), "Startup does not build or load a hidden 140-word album")
	app._lesson.next_button.pressed.emit()
	app._lesson.previous_button.pressed.emit()
	check(app.playroom_state.collected_word_ids.is_empty(), "Browsing Learn earns no stickers")
	app.choose_mode("match")
	var pairs: Array = []
	for word in app.model.lesson_words:
		if not app.model.card_by_id(word.id + ":word").is_empty() and not app.model.card_by_id(word.id + ":image").is_empty():
			pairs.append(word)
	app._select_card(pairs[0].id + ":word")
	app._select_card(pairs[1].id + ":image")
	check(app.playroom_state.collected_word_ids.is_empty(), "Wrong associations earn no stickers")
	app._continue_match()
	for word in pairs:
		app._select_card(word.id + ":word")
		app._select_card(word.id + ":image")
		check(app.playroom_state.collected_word_ids.has(word.id), "A correct Match target is collected: " + word.id)
		check(app._match_feedback.heading_label.text == "New sticker: %s!" % word.text, "The exact new word is celebrated")
		app._select_card(word.id + ":image")
		app._continue_match()
	check(app.playroom_state.collected_word_ids.size() == 3, "Match collects its three pairs, never orphan words")
	check(app.medal_progress.counts.is_empty(), "Stickers never claim medal pieces")
	app._open_chest()
	check(app.medal_progress.count_for(app.model.theme_id + "-1") == 1, "The ordinary chest still grants one piece")
	app._replay()
	app.choose_mode("memory")
	var memory = app._memory
	memory.study_button.pressed.emit()
	check(app.playroom_state.collected_word_ids.size() == 3, "Memory Study does not grant stickers")
	memory.study_button.pressed.emit()
	for word in app.model.lesson_words:
		for index in range(memory.memory.cards.size()):
			if memory.memory.cards[index].word.id == word.id:
				memory.card_buttons[index].pressed.emit()
		memory.feedback_view.action_button.pressed.emit()
	check(app.playroom_state.collected_word_ids.size() == 5, "Memory adds only missing correct pairs and keeps previous stickers")
	app._replay()
	app.choose_mode("sky")
	for mode_id in ["sky", "listen"]:
		app.new_round(177 if mode_id == "sky" else 236, false, "picnic-time", mode_id)
		var target: Dictionary = app._choice.current_target
		var index: int = app._choice.choices.find(target)
		app._choice.answer_buttons[index].pressed.emit()
		check(app.playroom_state.collected_word_ids.has(target.id), mode_id + " collects its exact correct target")
		app._choice.feedback_view.action_button.pressed.emit()
	app.new_round(333, false, "music-makers", "match")
	var voice_word := ""
	for card in app.model.cards:
		if not app.model.card_by_id(card.word.id + ":word").is_empty() and not app.model.card_by_id(card.word.id + ":image").is_empty():
			voice_word = card.word.id
			break
	app._voice_mode = true
	app._speech_queue.append(voice_word)
	app._consume_spoken_word()
	check(app.playroom_state.collected_word_ids.has(voice_word), "Spoken Match uses the same collection path")
	app._stop_voice()
	app._show_collection()
	app._show_reward_section("words")
	await process_frame
	await process_frame
	check(app._word_book.visible and not app._room.visible, "Words has its own reward section")
	check(app._collection_rows.all(func(row) -> bool: return not row.visible), "Words never overlaps Medals")
	check(app._word_book.word_buttons.size() <= 24, "Only the selected topic gets cards")
	var displayed: String = app.playroom_state.collected_word_ids[0]
	app._display_word_sticker(displayed)
	check(app.playroom_state.displayed_word_id == displayed, "A collected word can be displayed with Pip")
	app._show_reward_section("room")
	check(app._room.word_sticker_button.visible, "Pip's room displays the selected word")
	app._hide_collection()
	var before: String = app.playroom_state.displayed_word_id
	app._display_word_sticker(voice_word)
	check(app.playroom_state.displayed_word_id == before, "Hidden album controls cannot change room choices")
	var storage := BrowserStorage.new()
	app.playroom_state = load("res://scripts/playroom_state.gd").new(directory + "/isolated.cfg", storage)
	app._playroom_ready = app.playroom_state.load_state()
	storage.writable = false
	app.new_round(555, false, "animal-friends", "sky")
	var failed_target: Dictionary = app._choice.current_target
	app._choice.answer_buttons[app._choice.choices.find(failed_target)].pressed.emit()
	check(app.playroom_state.collected_word_ids.is_empty(), "Failed writes never pretend the sticker was saved")
	check(app._pending_sticker_ids == [failed_target.id], "A failed correct answer remains pending")
	app.choose_mode("learn")
	check(app._pending_sticker_ids == [failed_target.id], "Pending stickers survive mode changes")
	storage.writable = true
	app._show_collection()
	app._show_reward_section("words")
	app._word_book.retry_button.pressed.emit()
	check(app.playroom_state.collected_word_ids == [failed_target.id] and app._pending_sticker_ids.is_empty(), "Explicit retry saves the original pending word once")
	app._word_book.retry_button.pressed.emit()
	check(app.playroom_state.collected_word_ids.size() == 1, "Repeated retry cannot duplicate stickers")
	for viewport_size in [Vector2i(320, 568), Vector2i(853, 1272), Vector2i(960, 480)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		for button in app._collection_tabs.values():
			check(button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= app.size.x + 1, "Reward tabs fit the viewport")
	app._hide_collection()
	app.new_round(789, false, "animal-friends", "sky")
	var target_index: int = app._choice.choices.find(app._choice.current_target)
	app._choice.answer_buttons[1 - target_index].pressed.emit()
	await process_frame
	await process_frame
	var correction = app._choice.feedback_view
	check(correction.picture_button.disabled, "The muted correction picture cannot pronounce")
	correction.action_button.grab_focus()
	await _tap_control(correction.picture_button)
	check(root.gui_get_focus_owner() == correction.action_button, "Tapping a silent correction picture preserves Continue focus")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	check(app._choice.status == "asking", "Enter continues after tapping the muted correction picture")
	app.audio.set_muted(false)
	app._choice.answer_buttons[target_index].pressed.emit()
	for lesson_mode in ["sky", "learn"]:
		if lesson_mode == "learn":
			app.choose_mode(lesson_mode)
		var picture: Button = app._lesson.picture_button if lesson_mode == "learn" else correction.picture_button
		picture.grab_focus()
		app._show_collection()
		check(not app._focus_candidates().has(picture), lesson_mode + " picture stays outside modal focus")
		app._hide_collection()
		check(not picture.disabled and app._focus_candidates().has(picture), lesson_mode + " picture rejoins focus navigation after closing rewards")
		check(root.gui_get_focus_owner() == picture, lesson_mode + " restores focus to its audible picture")
	app.audio.set_muted(true)
	app._show_collection()
	app._show_reward_section("words")
	app._display_word_sticker(failed_target.id)
	app._show_reward_section("room")
	app._collection_back.grab_focus()
	app._collection_scroll.ensure_control_visible(app._room.word_sticker_button)
	await process_frame
	await process_frame
	await _tap_control(app._room.word_sticker_button)
	check(root.gui_get_focus_owner() == app._collection_back, "A silent room sticker cannot steal Back focus")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Word sticker scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _tap_control(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
