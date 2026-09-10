extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func win(app) -> void:
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app.cards[card.id].pressed.emit()
			app.cards[card.word.id + ":image"].pressed.emit()
			app.feedback_timer.timeout.emit()


func _run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	var integrated: bool = app.get_property_list().any(
		func(property: Dictionary) -> bool: return property.name == "medal_progress")
	check(integrated, "The native scene integrates persisted medal fragments")
	check(app.has_method("_on_voice_result"), "The native scene integrates voice-result feedback")
	if not integrated:
		app.free()
		print("Medal scene: %d assertions, %d failures" % [checks, failures])
		quit(1)
		return
	var directory := "user://medal-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The isolated medal fixture directory exists")
	var progress_script = app.medal_progress.get_script()
	app.medal_progress = progress_script.new(directory + "/medals.cfg", directory + "/old.cfg")
	app._mode_id = "match"
	app.playroom_save_path = directory + "/playroom.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	check(app._reward_slots.size() == 36, "A new player sees six active medals per theme")
	check(app.medal_progress.count_for("spring-1") == 0, "A new player's first medal is empty")
	app.new_round(6)
	app.choose_theme("spring")
	win(app)
	check(app._medallion.visible and app.reward_image.pieces == 0, "The unopened chest shows the empty medal goal")
	app.chest_button.button_down.emit()
	app._process(0.1)
	app.chest_button.button_up.emit()
	check(app.chest._tap_remaining > 0.0 and app.model.chest_state == "closed",
		"A brief chest press reacts without awarding a piece")
	app.chest_button.button_down.emit()
	app._process(1.21)
	app.chest_button.button_up.emit()
	check(app.model.chest_state == "opening" and app.effects.particle_count() == 24,
		"A full hold starts a small fragment reveal")
	check(app._pending_fragment.medal_id == "spring-1" and app._pending_fragment.after == 1,
		"Opening locks the first missing fragment")
	app.chest.finish_immediately()
	check(app.medal_progress.count_for("spring-1") == 1 and app._fragment_active,
		"The piece is saved before the assembly animation")
	check(app.reward_image.pieces == 0 and app._fragment_image.fragment_index == 0,
		"The flying piece corresponds to the actual empty sector")
	var reload = progress_script.new(directory + "/medals.cfg", directory + "/old.cfg")
	check(reload.load_progress() and reload.count_for("spring-1") == 1,
		"Saved progress is recoverable before animation completion")
	app._fragment_tween.pause()
	app._fragment_tween.custom_step(1.0)
	check(not app._fragment_active and app.reward_image.pieces == 1 and app._reward_tween == null,
		"An ordinary piece snaps into the medal without a second collection flight")
	app._on_chest_opened()
	check(app.medal_progress.count_for("spring-1") == 1, "A repeated opening callback cannot duplicate the piece")
	app._show_collection()
	app._open_reward_preview("spring-1")
	check(app._preview_image.pieces == 1, "A partial medal preview does not reveal the full medal")
	check(app._status_announcement.contains("Piece 1 of 3"),
		"The partial medal preview announces its fragment progress")
	app._hide_reward_preview()
	app._hide_collection()
	app.new_round(7)
	app.choose_theme("spring")
	win(app)
	app._open_chest()
	app.on_page_hidden()
	check(app.medal_progress.count_for("spring-1") == 2 and not app._fragment_active
		and app.reward_image.pieces == 2, "Hiding finalizes one earned piece and leaves a static assembled medal")
	app.new_round(8)
	app.choose_theme("spring")
	win(app)
	app._open_chest()
	app.chest.finish_immediately()
	check(app.medal_progress.completed_count("spring") == 1, "The third piece completes one medal")
	app._finish_fragment_delivery()
	check(app.effects.particle_count() == 72 and app._reward_tween != null,
		"Completing a medal gets the full celebration and collection flight")
	app._finish_fragment_delivery()
	check(app.medal_progress.count_for("spring-1") == 3, "Tapping placement repeatedly cannot add pieces")
	app._show_collection()
	check(app._collection_headings.spring.text == "Spring 1/6", "The collection distinguishes medals from fragments")
	app._hide_collection()
	app.new_round(9)
	app.choose_theme("spring")
	win(app)
	app.set_reduced_motion(true)
	app._open_chest()
	check(app.model.reward_id == "spring-2" and app.medal_progress.count_for("spring-2") == 1,
		"The next win starts the next medal rather than a duplicate")
	check(not app._fragment_active and app.effects.particle_count() == 0,
		"Reduced motion immediately displays the saved piece")
	app.new_round(10)
	app.choose_theme("winter")
	win(app)
	var blocked_path := directory + "/blocked.cfg"
	var failing_progress = progress_script.new(blocked_path, directory + "/old.cfg")
	check(failing_progress.load_progress(), "The failing save fixture starts with valid storage")
	DirAccess.remove_absolute(blocked_path)
	DirAccess.make_dir_absolute(blocked_path)
	app.medal_progress = failing_progress
	app._open_chest()
	check(app._save_error and app.replay_button.text == "Retry saving"
		and not app._fragment_active, "A failed save offers retry instead of pretending to collect a fragment")
	var pending: Dictionary = app._pending_fragment.duplicate()
	app.medal_progress = progress_script.new(directory + "/retry.cfg", directory + "/old.cfg")
	check(app.medal_progress.load_progress(), "The retry fixture can store progress")
	app._replay()
	check(not app._save_error and app.model.phase == "won"
		and app.medal_progress.count_for(pending.medal_id) == pending.after,
		"Retry saving commits the same captured piece without rerolling or replaying")
	DirAccess.remove_absolute(blocked_path)
	app.new_round(11)
	for index in range(1, 7):
		app.medal_progress.counts["winter-%d" % index] = 3
	app.choose_theme("winter")
	win(app)
	var complete: Dictionary = app.medal_progress.counts.duplicate()
	app._open_chest()
	check(app._title.text == "All six collected!" and app.medal_progress.counts == complete,
		"A completed theme celebrates without inventing a seventh medal")
	app.new_round(12)
	var spoken: Array[String] = []
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			spoken.append(card.word.text)
	app._on_voice_state([true, true, "Listening"])
	root.size = Vector2i(320, 321)
	await process_frame
	await process_frame
	for card in app.cards.values():
		check(root.get_visible_rect().grow(0.5).encloses(card.get_global_rect()),
			"Voice mode keeps all cards on a short portrait screen")
	app._on_voice_result(["I see " + spoken[0], false])
	check(app.model.successes == 0, "Interim speech is displayed without committing a match")
	app._on_voice_result(["I see " + spoken[0], true])
	check(app.model.successes == 1 and app.model.phase == "feedback",
		"A final spoken board word uses the normal matching feedback")
	app._on_voice_result([" and ".join(spoken), true])
	for step in range(3):
		app.feedback_timer.timeout.emit()
	check(app.model.phase == "won" and app.model.successes == 3 and not app._voice_mode
		and app._speech_queue.is_empty(), "Distinct spoken words queue safely and winning exits voice mode")
	app._on_voice_result([spoken[0], true])
	check(app.model.successes == 3, "Late voice callbacks cannot change a completed round")
	app.new_round(13)
	app._on_voice_state([true, true, "Listening"])
	app._show_collection()
	check(not app._voice_mode and not app._voice_space.visible,
		"Opening a modal stops voice mode and removes its reserved panel")
	app._hide_collection()
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app.cards[card.id].pressed.emit()
			app.cards[card.word.id + ":image"].pressed.emit()
			break
	app._show_collection()
	app.feedback_timer.timeout.emit()
	app._hide_collection()
	check(not app.hint_button.disabled and app.hint_button.focus_mode == Control.FOCUS_ALL,
		"Closing a collection after feedback restores the currently available hint")
	app._show_collection()
	app._open_reward_preview("winter-1")
	app.medal_progress.counts["spring-1"] = 1
	app._refresh_collection()
	app._refresh()
	app._hide_reward_preview()
	check(app._reward_slots["spring-1"].button.focus_mode == Control.FOCUS_ALL,
		"Closing a preview makes newly earned medal tiles keyboard-reachable")
	app._hide_collection()
	root.size = Vector2i(390, 844)
	app.new_round(6)
	await process_frame
	await process_frame
	var first_id: String = app.model.cards[0].id
	var second_id: String = app.model.cards[1].id
	app._controller_mode = true
	app.cards[first_id].grab_focus()
	app._controller_accept()
	app._cycle_theme(-1)
	app._cycle_theme(1)
	app._toggle_collection()
	app._toggle_collection()
	app._toggle_collection()
	app._controller_back()
	app._controller_back()
	check(app.cards[first_id].has_focus(), "Season/modal round trips retain card focus: " + str(root.gui_get_focus_owner()))
	app._move_focus(Vector2.RIGHT)
	check(app.cards[second_id].has_focus(), "Controller Right reaches the neighboring card: " + str(root.gui_get_focus_owner()))
	app._controller_accept()
	check(app.model.selected_id == second_id, "Controller A selects that neighboring card")
	app.queue_free()
	await process_frame
	var legacy := ConfigFile.new()
	legacy.set_value("rewards", "ids", PackedStringArray(["spring-7"]))
	check(legacy.save(directory + "/legacy.cfg") == OK, "An old-reward archive fixture is saved")
	var archive_app = load("res://scenes/main.tscn").instantiate()
	archive_app.medal_progress = progress_script.new(directory + "/archive.cfg", directory + "/legacy.cfg")
	archive_app.playroom_save_path = directory + "/archive-playroom.cfg"
	root.add_child(archive_app)
	await process_frame
	await process_frame
	check(archive_app._reward_slots.size() == 37 and archive_app._reward_slots.has("spring-7")
		and archive_app.medal_progress.completed_count() == 0,
		"Earlier rewards stay visible without becoming extra active medals")
	archive_app._show_collection()
	archive_app._open_reward_preview("spring-7")
	check(archive_app._preview_title.text == "Sprout #7" and archive_app._preview_image.pieces == 3,
		"An archived reward keeps its full artwork and original name")
	archive_app.queue_free()
	await process_frame
	var files := DirAccess.open(directory)
	for filename in files.get_files():
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Medal scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
