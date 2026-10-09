extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
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
	for frame in range(6):
		await process_frame


func check_catalog(app, age_id: String) -> void:
	var band: Dictionary = app.Data.age_band(age_id)
	var expected: Array = app.data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) == int(age_id)).map(func(word: Dictionary) -> String: return word.id)
	var actual: Array = app._age_catalog.snapshot().word_ids
	expected.sort()
	actual.sort()
	check(actual == expected, "Age " + age_id + " shows its exact disjoint curriculum cohort")
	check(app._age_catalog.word_buttons.size() <= app._age_catalog.PAGE_SIZE, "Rendered notebook cards remain bounded by page size")
	var heading: String = str(band.name) + (" · Preview" if int(age_id) > app.growth.level else "")
	check(app._age_catalog.title_label.text == heading
		and app._age_catalog.count_label.text == "%d words" % expected.size(), "The notebook accurately names its cohort, preview status and word count")
	check(app.collection_page.visible and app.collection_page.name == "GrowthNotebook" and app._age_catalog.is_visible_in_tree(), "The permanent progress entry opens the growth notebook")
	check(app.find_child("PipsRoom", true, false) == null and app.find_child("LeaderboardOverlay", true, false) == null, "The notebook contains no retired room or identity overlay")
	var previous := ""
	for button: Button in app._age_catalog.word_buttons:
		var word: Dictionary = button.get_meta("word")
		var picture: TextureRect = button.get_meta("word_art")
		var caption: Label = button.get_meta("word_label")
		check(caption.text == app.Data.display_word(word) and previous.naturalnocasecmp_to(word.text) <= 0, "Every notebook word uses its authored caption and alphabetical position: " + word.id)
		previous = word.text
		if word.image.is_empty():
			check(picture.texture == null and not picture.visible, "Context words use readable text without a misleading picture")
		else:
			check(picture.texture == load("res://" + word.image), "Pictured words retain their real source illustration")
		var mastery: Label = button.get_meta("mastery_label")
		var streak: int = app.growth.streak(word.id)
		check(mastery.text == ("Mastered" if streak == 6 else "%d / 6" % streak), "Every word shows its saved mastery state")


func check_stretched_catalog_resize(app) -> void:
	app._hide_collection()
	root.content_scale_size = Vector2i(480, 480)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(960, 720)
	await settle()
	app._show_collection()
	app._age_buttons["3"].pressed.emit()
	await settle()
	var early_id: String = app._age_catalog.snapshot().word_ids.front()
	check(app._age_catalog.focus_word(early_id), "The stretched scene can focus the first actual curriculum word")
	var early: Button = root.gui_get_focus_owner()
	early.pressed.emit()
	await settle()
	for dimensions in [Vector2i(960, 720), Vector2i(390, 844), Vector2i(557, 1206)]:
		root.size = dimensions
		var largest_offset := 0
		for frame in range(70):
			await process_frame
			largest_offset = maxi(largest_offset, app._age_catalog.scroll.scroll_vertical)
		var snapshot: Dictionary = app._age_catalog.snapshot()
		var focused: Control = root.gui_get_focus_owner()
		var scroll_rect: Rect2 = app._age_catalog.scroll.get_global_rect()
		check(focused == early and scroll_rect.grow(1).encloses(early.get_global_rect()), "The actual stretched scene retains its early focused word at " + str(dimensions))
		check(largest_offset < app._age_catalog.scroll.size.y and snapshot.scroll_offset < snapshot.scroll_max, "Canvas resizing never jumps to the notebook's end")
		var settled_offset: int = app._age_catalog.scroll.scroll_vertical
		for frame in range(30):
			await process_frame
		check(app._age_catalog.scroll.scroll_vertical == settled_offset, "Focused-word scrolling settles after resizing")


func _touch(point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = down
	root.push_input(event, true)
	await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://age-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	Fixture.install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app._mode_id == "match" and app.model.age_band_id == "3" and app.growth.level == 3, "Every new learner begins with a playable Lv3 Match round")
	for number in range(6):
		check(app.growth.record_attempt("notebook-seed-%d" % number, ["cat"], true).save_ok, "Isolated fixture records each correct practice event")
	app._refresh_growth()
	app._request_hint()
	app.cards[app.model.hint_ids[0]].pressed.emit()
	var cards: Array = app.model.cards.duplicate(true)
	var words: Array = app.model.lesson_words.duplicate(true)
	var progress: Array = [app.model.selected_id, app.model.hints_remaining, app.model.phase, app.model.matched_ids.size(), app.model.mistakes]
	var rewards: Dictionary = app.medal_progress.counts.duplicate(true)
	var source_words: Array = app.data.words.duplicate(true)
	var growth_before: Dictionary = app.growth.snapshot().duplicate(true)
	var saved_path: String = app.growth._path
	var saved_bytes := FileAccess.get_file_as_string(saved_path)
	app._growth_button.pressed.emit()
	await settle()
	check(app.collection_page.visible and app._catalog_age == 3, "The progress bar entry opens the current earned cohort")
	for age in range(3, 13):
		var age_id := str(age)
		var button: Button = app._age_buttons[age_id]
		button.grab_focus()
		await settle()
		var scroll: int = app._age_scroll.scroll_horizontal
		button.pressed.emit()
		await settle()
		check_catalog(app, age_id)
		check(button.has_focus() and app._age_scroll.scroll_horizontal == scroll, "Choosing a cohort preserves the age rail's focus and position")
		check(app.model.cards == cards and app.model.lesson_words == words and app.model.age_band_id == "3"
			and [app.model.selected_id, app.model.hints_remaining, app.model.phase, app.model.matched_ids.size(), app.model.mistakes] == progress,
			"Browsing every age preserves the active round, selection and hints")
		check(app._age_notice.text.begins_with("Preview only") == (age > 3)
			and app._age_buttons.values().filter(func(choice: Button) -> bool: return choice.button_pressed).size() == 1,
			"Exactly one cohort is selected and future cohorts explain their locked preview")
		check(app.growth.snapshot() == growth_before and app.medal_progress.counts == rewards
			and FileAccess.get_file_as_string(saved_path) == saved_bytes, "Browsing does not earn mastery, change levels, claim treasure or write a save")
	check(app.data.words == source_words, "Browsing leaves vocabulary content and asset paths unchanged")
	app._back_from_collection()
	await settle()
	check(not app.collection_page.visible and not app._age_catalog.is_visible_in_tree(), "Back returns directly from the notebook to the game")
	app._show_collection()
	await settle()
	check(app._catalog_age == app.growth.level and app._age_buttons["3"].button_pressed, "Reopening starts on the earned level rather than the previous future preview")
	app._age_buttons["4"].grab_focus()
	await settle()
	var point: Vector2 = app._age_buttons["4"].get_global_transform_with_canvas() * (app._age_buttons["4"].size * 0.5)
	await _touch(point, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point - Vector2(60, 0)
	drag.relative = Vector2(-60, 0)
	root.push_input(drag, true)
	await process_frame
	await _touch(drag.position, false)
	check(app._catalog_age == 3, "Dragging the age rail never selects a crossed cohort")
	app._age_scroll.cancel_drag()
	app._collection_multi_touch = true
	app._age_buttons["12"].pressed.emit()
	check(app._catalog_age == 3, "A multi-touch gesture cannot change the notebook cohort")
	app._collection_multi_touch = false
	app._speech_debug_active = true
	app._age_buttons["12"].pressed.emit()
	check(app._catalog_age == 3, "A covered notebook cannot change while speech diagnostics own interaction")
	app._speech_debug_active = false
	app._hide_collection()
	app._age_buttons["12"].pressed.emit()
	check(app._catalog_age == 3 and not app.collection_page.visible, "Hidden age controls cannot reopen or change the notebook")
	for mode in ["memory", "pop", "phrase", "match"]:
		check(app.new_round(31, false, "", mode), "Every mode can start at the earned learning level: " + mode)
		await settle()
		check(app.model.age_band_id == "3" and app.model.lesson_words.all(func(word: Dictionary): return int(word.min_age) <= 3), "Mode switching never adopts a future preview age")
		if mode == "memory":
			check(app._memory.memory.cards.size() == 10, "Memory retains its complete five-pair board")
		elif mode == "phrase":
			var ids: Array = app._phrase.game.current_question().words
			check(ids.all(func(id: String): return app.data.words.any(func(word: Dictionary): return word.id == id and int(word.min_age) <= 3)), "Phrase Builder only teaches unlocked pictured and contextual words")
	app._show_collection()
	await settle()
	app.growth._path = directory + "/missing/growth.cfg"
	app._growth_save_failed = true
	app._age_buttons["12"].pressed.emit()
	await settle()
	check(app._catalog_age == 12 and app._age_catalog.word_count() > 0
		and app._age_notice.text.contains("Retry saving") and FileAccess.get_file_as_string(saved_path) == saved_bytes,
		"A storage failure does not block read-only curriculum browsing or rewrite saved growth")
	app.growth._path = saved_path
	app._growth_save_failed = false
	app._refresh_age_choices()
	var spoken: Dictionary = app._age_catalog.word_buttons[0].get_meta("word")
	app.audio.set_muted(false)
	app._age_catalog.word_buttons[0].pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + spoken.audio)
		and app.growth.snapshot() == growth_before, "A notebook card plays bundled speech without crediting mastery")
	app.on_page_hidden()
	app._age_catalog.hear_requested.emit(spoken)
	app._age_buttons["3"].pressed.emit()
	check(not app.audio.active and not app.audio.voice.playing and app._catalog_age == 12, "Background callbacks cannot resume speech or change the cohort")
	app.on_page_visible()
	check(not app.audio.voice.playing, "Returning never replays interrupted notebook speech")
	app._age_catalog.word_buttons[0].pressed.emit()
	check(app.audio.voice.playing, "A fresh visible tap can pronounce a word after returning")
	app._back_from_collection()
	check(not app.audio.voice.playing, "Leaving the notebook stops its pronunciation")
	app.audio.halt()
	app._age_catalog.hear_requested.emit(spoken)
	check(not app.audio.active and not app.audio.voice.playing, "Stale hidden notebook signals cannot reactivate audio")
	app.audio.set_muted(true)
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768), Vector2i(320, 320)]:
		root.size = dimensions
		app._show_collection()
		await settle()
		var scale: float = app.Style.ui_scale(app)
		check(app._age_buttons.keys() == ["3", "4", "5", "6", "7", "8", "9", "10", "11", "12"], "All ten cohorts remain available for review")
		for id in app._age_buttons:
			var button: Button = app._age_buttons[id]
			button.grab_focus()
			await settle()
			check(button.is_visible_in_tree() and button.size.x * scale >= 48 and button.size.y * scale >= 42, "Age controls retain their physical touch-target dimensions at " + str(dimensions))
			check(app._age_scroll.get_global_rect().grow(1).encloses(button.get_global_rect())
				and str(button.get("accessibility_name")).contains(app.Data.age_band(id).name), "Focus reveals age %s with its accessible name at %s: name=%s rail=%s button=%s" % [id, dimensions, str(button.get("accessibility_name")), app._age_scroll.get_global_rect(), button.get_global_rect()])
		app._age_buttons["3"].grab_focus()
		await settle()
		app._move_focus(Vector2.RIGHT)
		check(app._age_buttons["4"].has_focus(), "Controller navigation traverses the age rail left to right")
		app._controller_accept()
		await settle()
		check(app._catalog_age == 4 and app._age_buttons["4"].button_pressed and app.growth.level == 3, "Controller accept previews an age without unlocking it")
		app._age_buttons["7"].pressed.emit()
		await settle()
		check(app.get_global_rect().grow(1).encloses(app._age_catalog.get_global_rect())
			and app._age_choices.get_global_rect().end.y <= app._age_catalog.global_position.y + 1
			and app._age_catalog.scroll.size.y > 0, "The full notebook fits at %s: app=%s catalog=%s ages=%s scroll=%s" % [dimensions, app.get_global_rect(), app._age_catalog.get_global_rect(), app._age_choices.get_global_rect(), app._age_catalog.scroll.size])
		var last_id: String = app._age_catalog.snapshot().word_ids.back()
		check(app._age_catalog.focus_word(last_id), "The final word can be reached across page boundaries")
		await settle()
		var last: Button = root.gui_get_focus_owner()
		var target: Control = last.get_meta("word_label") if last.size.y > app._age_catalog.scroll.size.y else last
		check(app._age_catalog.snapshot().page == app._age_catalog.snapshot().page_count
			and app._age_catalog.scroll.get_global_rect().grow(1).encloses(target.get_global_rect())
			and not app._age_catalog.scroll.get_v_scroll_bar().visible and not app._age_catalog.scroll.get_h_scroll_bar().visible,
			"Hidden scrollbars still reveal the final word's caption at " + str(dimensions))
		app._controller_back()
		await settle()
		check(not app.collection_page.visible, "Controller Back returns directly to the active game")
	app._show_collection()
	app._build_collection()
	await settle()
	check(app._age_buttons.size() == 10 and app._age_buttons["7"].is_inside_tree(), "Refreshing the notebook preserves all age controls")
	await check_stretched_catalog_resize(app)
	app.audio.halt()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Age controls: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
