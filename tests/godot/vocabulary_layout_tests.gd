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
	for frame in range(3):
		await process_frame


func check_label(label: Label, word: Dictionary, mode: String, dimensions: Vector2i) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var measured: Vector2 = font.get_string_size(word.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	check(label.text == word.text and measured.x <= label.size.x - 8,
		"%s %s %s fits with breathing room: text=%s label=%s font=%d" % [dimensions, mode, word.id, measured, label.size, font_size])
	check(font.get_height(font_size) <= label.size.y and font_size * load("res://scripts/ui_style.gd").ui_scale(label) >= 12,
		"%s %s %s stays legible within its label height" % [dimensions, mode, word.id])


func check_catalog_labels(card: Button, words: Array, mode: String, dimensions: Vector2i) -> void:
	var original: String = card.word_label.text
	for word: Dictionary in words:
		card.word_label.text = word.text
		card._fit_text()
		check_label(card.word_label, word, mode, dimensions)
	card.word_label.text = original
	card._fit_text()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://vocabulary-layout-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	var all_words: Array = app.data.words
	check(all_words.size() == 1250, "All 1,250 words receive shared card renderer layout coverage")
	var representatives: Array = []
	for level in ["basic", "growing", "advanced"]:
		var tier: Array = all_words.filter(func(word: Dictionary) -> bool: return word.level == level)
		tier.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first.text.length() > second.text.length())
		representatives.append(tier[0])
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(480, 480), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		for word in representatives:
			var topic: Dictionary = app.Data.adventures(all_words).filter(func(value: Dictionary) -> bool: return value.words.has(word.id))[0]
			check(app.new_round(19, false, topic.id, "match", word.id), "A lesson can render its longest tier word: " + word.id)
			await settle()
			var card: Button = app.cards[word.id + ":word"]
			if dimensions == Vector2i(480, 480):
				check(app.grid.columns == 2, "A small square Match board uses wide cards for the complete word")
			check_label(card.word_label, word, "Match", dimensions)
			check(app._match_playfield.get_global_rect().grow(1).encloses(card.get_global_rect()), "Match keeps each new word inside its original board")
			if word == representatives[0]:
				check_catalog_labels(card, all_words, "Match", dimensions)
			app.choose_mode("memory")
			app._memory.begin_peek()
			await settle()
			if dimensions == Vector2i(480, 480):
				check(app._memory.card_buttons[0].position.y == app._memory.card_buttons[1].position.y
					and app._memory.card_buttons[2].position.y > app._memory.card_buttons[0].position.y,
					"A small square Memory board uses two columns without shrinking long words")
			var word_cards: Array = app._memory.card_buttons.filter(
				func(value: Button) -> bool: return value.card_data.kind == "word" and value.card_data.word.id == word.id)
			check(word_cards.size() == 1, "Memory still has exactly one word partner for each lesson word")
			if word_cards.size() == 1:
				check_label(word_cards[0].word_label, word, "Memory", dimensions)
				check(app._memory.get_global_rect().grow(1).encloses(word_cards[0].get_global_rect()), "Memory keeps new words inside its five-pair board")
				if word == representatives[0]:
					check_catalog_labels(word_cards[0], all_words, "Memory", dimensions)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Expanded word layouts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
