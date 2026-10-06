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
	for frame in range(6):
		await process_frame


func check_catalog(app, age_id: String, expected_count: int) -> void:
	var band: Dictionary = app.Data.age_band(age_id)
	# Raw curriculum tiers are independent of the production age-level helper.
	var levels := {"4-6": "basic", "7-9": "growing", "10-plus": "advanced"}
	var expected: Array = app.data.words.filter(func(word: Dictionary) -> bool:
		return age_id == "all" or word.level == levels[age_id]).map(func(word: Dictionary) -> String: return word.id)
	var actual: Array = app._age_catalog.snapshot().word_ids
	expected.sort()
	actual.sort()
	check(actual == expected and actual.size() == expected_count,
		"The " + age_id + " catalogue includes exactly its own age range across all topics, without other tiers")
	check(app._age_catalog.word_buttons.size() <= app._age_catalog.PAGE_SIZE,
		"The complete vocabulary uses a bounded page of rendered cards")
	for sample: Dictionary in [
		{"id": "cat", "age": "4-6"}, {"id": "acorn", "age": "7-9"}, {"id": "abacus", "age": "10-plus"}
	]:
		check(actual.has(sample.id) == (age_id == "all" or age_id == sample.age),
			"The " + age_id + " catalogue includes " + sample.id + " only in its own range or All words")
	check(app._age_catalog.title_label.text == band.name
		and app._age_catalog.count_label.text == "%d words" % expected_count,
		"The catalogue names the chosen age and its exact range's word count")
	check(app.collection_page.visible and app._age_catalog.is_visible_in_tree()
		and not app._collection_scroll.visible and not app._world_choices.visible
		and not app._room.toy_shelf.visible and not app._leaderboard_menu.visible,
		"The catalogue replaces the room, worlds, toys and player menu within More")
	check(not app._focus_candidates().has(app._room.toy_button)
		and not app._focus_candidates().has(app._players_button),
		"Covered room and player controls cannot receive catalogue keyboard focus")
	var captions: Array[String] = []
	for button: Button in app._age_catalog.word_buttons:
		var word: Dictionary = button.get_meta("word")
		var picture: TextureRect = button.get_meta("word_art")
		var caption: Label = button.get_meta("word_label")
		captions.append(caption.text)
		check(picture.texture == load("res://" + word.image) and caption.text == word.text,
			"Catalogue word " + word.id + " uses its real runtime picture and label")
	var ordered: Array[String] = captions.duplicate()
	ordered.sort()
	check(captions == ordered, "The complete catalogue is alphabetically ordered")


func check_stretched_catalog_resize(app) -> void:
	app._hide_collection()
	root.content_scale_size = Vector2i(480, 480)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(960, 720)
	await settle()
	app._show_collection()
	app._age_buttons["4-6"].pressed.emit()
	await settle()
	check(app._age_catalog.focus_word("ant"), "The stretched main scene can focus an early catalogue word")
	var ant: Button = root.gui_get_focus_owner()
	ant.pressed.emit()
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
		print("Main catalogue resize %s: app=%s scale=%.3f columns=%d offset=%d max=%.1f largest=%d focus=%s scroll=%s ant=%s" % [
			dimensions, app.size, app.Style.ui_scale(app), snapshot.columns, snapshot.scroll_offset,
			snapshot.scroll_max, largest_offset, focused.name if is_instance_valid(focused) else "none",
			scroll_rect, ant.get_global_rect()])
		check(focused == ant and scroll_rect.grow(1).encloses(ant.get_global_rect()),
			"The actual stretched main scene keeps the focused ant visible after resize to " + str(dimensions))
		check(largest_offset < app._age_catalog.scroll.size.y and snapshot.scroll_offset < snapshot.scroll_max,
			"The actual stretched main scene never jumps to the catalogue end after resize to " + str(dimensions))
		var settled_offset: int = app._age_catalog.scroll.scroll_vertical
		for frame in range(30):
			await process_frame
		check(app._age_catalog.scroll.scroll_vertical == settled_offset,
			"The actual stretched main scene keeps its catalogue position while idle at " + str(dimensions))


func _run() -> void:
	var probe = load("res://scripts/game_ui.gd").new()
	var ready: bool = probe.has_method("_choose_age_band") and probe.has_method("_back_from_collection")
	check(ready, "More provides age selection and a catalogue-aware Back action")
	probe.free()
	if not ready:
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://age-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app._mode_id == "match" and app.model.age_band_id == "all", "Startup retains Match and all words by default")
	app._request_hint()
	app.cards[app.model.hint_ids[0]].pressed.emit()
	var cards: Array = app.model.cards.duplicate(true)
	var words: Array = app.model.lesson_words.duplicate(true)
	var progress: Array = [app.model.selected_id, app.model.hints_remaining, app.model.phase,
		(app.model.matched_ids.size() / 2), app.model.mistakes]
	var counts: Dictionary = app.medal_progress.counts.duplicate(true)
	var source_words: Array = app.data.words.duplicate(true)
	var eligible_counts := {"all": 1250, "4-6": 448, "7-9": 412, "10-plus": 390}
	app._show_collection()
	for age_id in ["7-9", "10-plus", "all", "4-6"]:
		await settle()
		var button: Button = app._age_buttons[age_id]
		button.grab_focus()
		await settle()
		var scroll: int = app._age_scroll.scroll_horizontal
		button.pressed.emit()
		await settle()
		check_catalog(app, age_id, eligible_counts[age_id])
		check(button.has_focus() and app._age_scroll.scroll_horizontal == scroll,
			"Opening the catalogue keeps focus on the chosen age without moving the age rail")
		check(app.model.cards == cards and app.model.lesson_words == words and app.model.age_band_id == "all"
			and [app.model.selected_id, app.model.hints_remaining, app.model.phase,
				(app.model.matched_ids.size() / 2), app.model.mistakes] == progress,
			"Age selection preserves the exact active round, selection and hints")
		check(app._age_notice.text.is_empty() and not app._age_notice.is_visible_in_tree()
			and app._age_buttons.values().filter(func(choice: Button) -> bool: return choice.button_pressed).size() == 1
			and app.medal_progress.counts == counts,
			"One age is selected without a redundant hint, and rewards are untouched")
	check(app.data.words == source_words, "Browsing all ages leaves the shared vocabulary and its asset paths untouched")
	app._back_from_collection()
	await settle()
	check(app.collection_page.visible and not app._age_catalog.visible and app._room.is_visible_in_tree()
		and app._world_choices.visible and app._room.toy_shelf.visible and app._leaderboard_menu.visible
		and app._age_buttons["4-6"].has_focus(),
		"Back returns to Pip's room and restores the selected age button")
	var saved_before_reopen := FileAccess.get_file_as_string(app.playroom_state._save_path)
	app._age_buttons["4-6"].pressed.emit()
	await settle()
	check(app._age_catalog.visible and app._age_catalog.word_count() == 448
		and FileAccess.get_file_as_string(app.playroom_state._save_path) == saved_before_reopen,
		"Tapping the already selected age reopens all its words without changing saved bytes")
	app._back_from_collection()
	app._collection_dragged = true
	app._age_buttons["10-plus"].pressed.emit()
	check(app.playroom_state.age_band_id == "4-6" and not app._age_catalog.visible,
		"A dragged gesture cannot change age or open the catalogue")
	app._collection_dragged = false
	app._collection_multi_touch = true
	app._age_buttons["10-plus"].pressed.emit()
	check(app.playroom_state.age_band_id == "4-6" and not app._age_catalog.visible,
		"A multi-touch gesture cannot open an age catalogue")
	app._collection_multi_touch = false
	app._show_leaderboard("boards", false)
	app._age_buttons["10-plus"].pressed.emit()
	check(app.playroom_state.age_band_id == "4-6" and not app._age_catalog.visible,
		"An age control cannot change the preference behind the player modal")
	app._hide_leaderboard()
	app._hide_collection()
	app._age_buttons["10-plus"].pressed.emit()
	check(app.playroom_state.age_band_id == "4-6" and not app._age_catalog.visible,
		"Hidden age controls cannot change the preference or open a catalogue")
	for mode in ["memory", "pop", "match"]:
		app.choose_mode(mode)
		if mode == "pop":
			preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
		await settle()
		check(app.model.lesson_words == words and app.model.age_band_id == "all",
			"Switching to " + mode + " retains the active vocabulary, not the next-lesson setting")
		if mode == "memory":
			check(app._memory.memory.cards.size() == 10, "Memory retains five pairs at every age")
	check(app.new_round(31, false, "space-trip", "match"), "A new lesson can start at the saved age")
	await settle()
	check(app.model.age_band_id == "4-6" and app.model.lesson_words.all(
		func(word: Dictionary) -> bool: return app.Data.word_level(word) == 1),
		"The next Match lesson uses the saved basic vocabulary")
	app._show_collection()
	await settle()
	var saved_path: String = app.playroom_state._save_path
	var original := FileAccess.get_file_as_string(saved_path)
	app.playroom_state._save_path = directory + "/missing/room.cfg"
	app._age_buttons["10-plus"].grab_focus()
	app._age_buttons["10-plus"].pressed.emit()
	await settle()
	check(app.playroom_state.age_band_id == "4-6" and app._age_buttons["4-6"].button_pressed
		and not app._age_buttons["10-plus"].button_pressed
		and app._age_notice.text.contains("retry") and app._age_notice.is_visible_in_tree()
		and FileAccess.get_file_as_string(saved_path) == original and not app._age_catalog.visible,
		"A failed save restores the confirmed selection and presents a retry, without changing saved bytes")
	app.playroom_state._save_path = saved_path
	app._age_buttons["10-plus"].pressed.emit()
	await settle()
	check(app.playroom_state.age_band_id == "10-plus" and app._age_buttons["10-plus"].button_pressed
		and app._age_notice.text.is_empty() and not app._age_notice.is_visible_in_tree()
		and app.model.age_band_id == "4-6" and app.collection_page.visible and app._age_catalog.visible
		and app._age_catalog.word_count() == 390,
		"A successful retry opens the complete catalogue without changing the active lesson")
	var reloaded = app.PlayroomState.new(saved_path)
	check(reloaded.load_state() and reloaded.age_band_id == "10-plus", "The UI choice survives a storage reload")
	var confirmed_catalog_save := FileAccess.get_file_as_string(saved_path)
	app.playroom_state._save_path = directory + "/missing/room.cfg"
	app._age_buttons["4-6"].pressed.emit()
	await settle()
	check(app.playroom_state.age_band_id == "10-plus" and app._age_catalog.visible
		and app._age_catalog.word_count() == 390 and app._age_catalog.title_label.text == "Ages 10+"
		and app._age_notice.visible and FileAccess.get_file_as_string(saved_path) == confirmed_catalog_save,
		"A failed age change keeps the previously confirmed catalogue and saved preference together")
	app.playroom_state._save_path = saved_path
	app._age_buttons["10-plus"].pressed.emit()
	await settle()
	var spoken: Dictionary = app._age_catalog.word_buttons[0].get_meta("word")
	app.audio.set_muted(false)
	app._age_catalog.word_buttons[0].pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + spoken.audio),
		"A catalogue card plays that word's bundled pronunciation")
	app.on_page_hidden()
	app._age_catalog.hear_requested.emit(spoken)
	app._age_buttons["4-6"].pressed.emit()
	check(not app.audio.active and not app.audio.voice.playing and app.playroom_state.age_band_id == "10-plus",
		"Background catalogue requests cannot restart audio or change the saved age")
	app.on_page_visible()
	check(not app.audio.voice.playing, "Returning to the page never replays an interrupted catalogue word")
	app._age_catalog.word_buttons[0].pressed.emit()
	check(app.audio.voice.playing, "A fresh visible tap can pronounce a catalogue word after returning")
	app._back_from_collection()
	check(not app.audio.voice.playing, "Leaving the catalogue stops its current pronunciation")
	app.audio.halt()
	app._age_catalog.hear_requested.emit(spoken)
	check(not app.audio.active and not app.audio.voice.playing, "A hidden catalogue signal cannot reactivate pronunciation")
	app.audio.set_muted(true)
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		var scale: float = app.Style.ui_scale(app)
		check(app._age_buttons.keys() == ["all", "4-6", "7-9", "10-plus"], "All four age choices remain directly available")
		for id in app._age_buttons:
			var button: Button = app._age_buttons[id]
			button.grab_focus()
			await settle()
			check(button.is_visible_in_tree() and button.size.x * scale >= 48 and button.size.y * scale >= 48,
				"Age buttons retain 48 CSS-pixel input targets at " + str(dimensions))
			check(app._age_scroll.get_global_rect().grow(1).encloses(button.get_global_rect())
				and str(button.get("accessibility_name")).contains(app.Data.age_band(id).name),
				"Focused age choices fit their strip and retain descriptive accessible names")
		check(app._age_choices.get_global_rect().end.y <= app._collection_scroll.global_position.y
			and app._collection_scroll.size.y * scale >= 100
			and app._collection_scroll.scroll_vertical == 0,
			"The top age strip leaves a usable fixed playground even in landscape")
		check(not app._age_notice.is_visible_in_tree()
			and is_equal_approx(app._age_choices.size.y, app._age_row.size.y),
			"The hidden notice leaves no reserved height or gap below the age buttons")
		var order: Array = app._focus_candidates()
		check(order.find(app._age_buttons["all"]) < order.find(app._room.toy_button)
			and app._focus_center(app._age_buttons["all"]).y < app._focus_center(app._room.toy_button).y,
			"Age controls share the top header and precede the fixed playground in focus order")
		app._age_buttons["all"].grab_focus()
		app._move_focus(Vector2.RIGHT)
		check(app._age_buttons["4-6"].has_focus(), "Controller navigation traverses the age row left to right")
		app._controller_accept()
		await settle()
		check(app.playroom_state.age_band_id == "4-6" and app._age_buttons["4-6"].button_pressed
			and app._age_catalog.visible and app._age_catalog.word_count() == 448,
			"Controller accept selects an age and opens all of its words")
		check(app.get_global_rect().grow(1).encloses(app._age_catalog.get_global_rect())
			and app._age_choices.get_global_rect().end.y <= app._age_catalog.global_position.y,
			"The catalogue fits below the age choices at " + str(dimensions))
		var last: Button = app._age_catalog.word_buttons.back()
		check(app._age_catalog.focus_word(str(last.get_meta("word_id"))), "The final eligible word can receive keyboard focus")
		await settle()
		check(last.has_focus() and app._age_catalog.scroll.scroll_vertical > 0
			and app._age_catalog.scroll.get_global_rect().grow(1).encloses(last.get_global_rect())
			and not app._age_catalog.scroll.get_v_scroll_bar().visible
			and not app._age_catalog.scroll.get_h_scroll_bar().visible,
			"Keyboard focus reveals the last word without visible scrollbars at " + str(dimensions))
		app._controller_back()
		await settle()
		check(app.collection_page.visible and not app._age_catalog.visible and app._age_buttons["4-6"].has_focus(),
			"Controller Back restores Pip's room and the age choice")
	app._hide_collection()
	check(app.new_round(33, false, "music-makers", "match") and app.model.age_band_id == "4-6",
		"A new Match round uses the saved age preference")
	app.choose_mode("memory")
	check(app.model.age_band_id == "4-6" and app._memory.memory.cards.all(
		func(card: Dictionary) -> bool: return app.Data.word_level(card.word) == 1),
		"Memory uses the same age-eligible lesson")
	root.size = Vector2i(320, 320)
	app._show_collection()
	await settle()
	await settle()
	check(not app._collection_grid.is_ancestor_of(app._age_choices) and app._age_choices.is_visible_in_tree()
		and app._collection_scroll.scroll_vertical == 0
		and app.get_global_rect().grow(1).encloses(app._room.toy_shelf.get_global_rect()),
		"Short screens keep the top age strip and bottom toys inside the fixed page")
	app._age_buttons["7-9"].grab_focus()
	await settle()
	check(app._age_scroll.get_global_rect().grow(1).encloses(app._age_buttons["7-9"].get_global_rect()),
		"Keyboard focus reveals the age choice inside its top horizontal strip")
	app._build_collection()
	await settle()
	check(app._age_buttons.size() == 4 and app._age_buttons["7-9"].is_inside_tree(),
		"Rebuilding rewards preserves the responsive age controls")
	await check_stretched_catalog_resize(app)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Age controls: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
