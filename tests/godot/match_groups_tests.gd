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


func state(app) -> Array:
	return [app.model.cards.duplicate(true), app.model.lesson_words.duplicate(true),
		app.model.selected_id, app.model.matched_ids.duplicate(), app.model.hint_ids.duplicate(),
		app.model.hints_remaining, app.model.successes, app.model.mistakes, app.model.phase,
		app.model.age_band_id, app.model.theme_id]


func check_groups(app) -> void:
	var pictures: Array = app.grid.get_children().filter(func(card: Button) -> bool: return card.card_data.kind == "image")
	var words: Array = app.grid.get_children().filter(func(card: Button) -> bool: return card.card_data.kind == "word")
	check(pictures.size() == 4 and words.size() == 4 and app.grid.get_child_count() == 8,
		"Match still has exactly four pictures and four words")
	if pictures.size() != 4 or words.size() != 4:
		return
	for kind in ["image", "word"]:
		var expected: Array = app.model.cards.filter(func(card: Dictionary) -> bool: return card.kind == kind).map(
			func(card: Dictionary) -> String: return card.id)
		var displayed: Array = (pictures if kind == "image" else words).map(
			func(card: Button) -> String: return card.card_data.id)
		check(displayed == expected, "Grouping retains the model's shuffled " + kind + " order")
	for picture in pictures:
		for word in words:
			var image_rect: Rect2 = picture.get_global_rect()
			var word_rect: Rect2 = word.get_global_rect()
			check(image_rect.end.x <= word_rect.position.x if app.grid.columns == 2 else image_rect.end.y <= word_rect.position.y,
				"Pictures and words occupy separate " + ("left/right columns" if app.grid.columns == 2 else "top/bottom rows"))
	for card in app.grid.get_children():
		check(app._match_playfield.get_global_rect().grow(1).encloses(card.get_global_rect()),
			"Grouped cards keep their full playfield and touch targets")
		check(card.size.x * app.Style.ui_scale(app) >= 48 and card.size.y * app.Style.ui_scale(app) >= 48,
			"Grouping does not shrink card input targets")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://match-groups-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	for seed_value in range(8):
		check(app.new_round(seed_value, false, "music-makers", "match", "microphone"),
			"A long-word Match lesson starts normally")
		await settle()
		check(app._default_focus().card_data.kind == "image", "Board focus starts with a picture")
		app._request_hint()
		var first: String = app.model.hint_ids[0]
		var partner: String = app.model.hint_ids[1]
		app.cards[first].pressed.emit()
		app.cards[first].grab_focus()
		var original: Array = state(app)
		var instances: Dictionary = {}
		for id in app.cards:
			instances[id] = app.cards[id].get_instance_id()
		for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768), Vector2i(320, 568)]:
			root.size = dimensions
			await settle()
			check_groups(app)
			check(state(app) == original and app.cards[first].has_focus(),
				"Changing grouping orientation preserves the active round, hint and focus")
			check(app.cards.keys().all(func(id: String) -> bool: return app.cards[id].get_instance_id() == instances[id]),
				"Resizing repositions existing cards rather than rebuilding them")
			var pictures: Array = app.grid.get_children().filter(func(card: Button) -> bool: return card.card_data.kind == "image")
			pictures[0].grab_focus()
			app._move_focus(Vector2.RIGHT if app.grid.columns == 2 else Vector2.DOWN)
			check(root.gui_get_focus_owner().card_data.kind == "word",
				"Directional navigation crosses naturally from the picture group to the word group")
			app.cards[first].grab_focus()
		app.cards[partner].pressed.emit()
		check(app.model.successes == 1 and app.model.mistakes == 0, "A cross-group match still scores exactly once")
		app._resolve_feedback()
		var picture: Dictionary = app.model.cards.filter(func(card: Dictionary) -> bool:
			return card.kind == "image" and not app.model.matched_ids.has(card.id))[0]
		var word: Dictionary = app.model.cards.filter(func(card: Dictionary) -> bool:
			return card.kind == "word" and card.word.id != picture.word.id and not app.model.matched_ids.has(card.id))[0]
		app.cards[picture.id].pressed.emit()
		app.cards[word.id].pressed.emit()
		check(app.model.mistakes == 1 and app.model.successes == 1, "Wrong cross-group pairs retain normal feedback and scoring")
		app._resolve_feedback()
	var lesson: Array = app.model.lesson_words.duplicate(true)
	app.choose_mode("memory")
	await settle()
	var memory_cards: Array = app._memory.memory.cards.duplicate(true)
	root.size = Vector2i(1366, 768)
	await settle()
	check(app.model.lesson_words == lesson and app._memory.memory.cards == memory_cards and app._memory.card_buttons.size() == 10
		and not app.grid.is_visible_in_tree(), "Memory keeps its own ten-card board and order")
	app.choose_mode("pop")
	await settle()
	check(app.model.lesson_words == lesson and app._pop.is_visible_in_tree()
		and not app.grid.is_visible_in_tree() and not app._memory.is_visible_in_tree(),
		"Voice Pop replaces the board without losing the shared five-word adventure")
	app.choose_mode("match")
	await settle()
	check(app.model.lesson_words == lesson, "Returning to Match retains the shared adventure words")
	check_groups(app)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Match groups: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
