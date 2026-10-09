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
	var display: String = str(word.get("display_text", word.text))
	var measured: Vector2 = font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	check(label.text == display and measured.x <= label.size.x - 8,
		"%s %s %s fits with breathing room: text=%s label=%s font=%d" % [dimensions, mode, word.id, measured, label.size, font_size])
	check(font.get_height(font_size) <= label.size.y and font_size * load("res://scripts/ui_style.gd").ui_scale(label) >= 12,
		"%s %s %s stays legible within its label height" % [dimensions, mode, word.id])


func check_catalog_labels(card: Button, words: Array, mode: String, dimensions: Vector2i) -> void:
	var original: String = card.word_label.text
	for word: Dictionary in words:
		card.word_label.text = str(word.get("display_text", word.text))
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
	app._presentation.path = directory + "/presentation.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	var all_words: Array = app.data.words
	var pictured_words: Array = all_words.filter(func(word: Dictionary) -> bool: return app.Data.supports_mode(word, "match"))
	check(all_words.size() >= 1550 and pictured_words.size() >= 1250 and pictured_words.size() < all_words.size(), "The expanded curriculum retains at least 1,250 production picture cards plus contextual phrase words")
	# Unlock the isolated layout fixture only; production gameplay still derives its level from mastery.
	app.growth.level = 12
	app._refresh_growth()
	var representatives: Array = []
	for age in range(3, 13):
		var tier: Array = pictured_words.filter(func(word: Dictionary) -> bool: return int(word.min_age) == age)
		tier.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first.text.length() > second.text.length())
		representatives.append(tier[0])
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(480, 480), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		for word in representatives:
			check(app.new_round(19, false, "", "match", word.id), "A lesson can render its longest age-cohort word: " + word.id)
			await settle()
			var card: Button = app.cards[word.id + ":word"]
			if dimensions == Vector2i(480, 480):
				check(app.grid.columns == 2, "A small square Match board uses wide cards for the complete word")
			check_label(card.word_label, word, "Match", dimensions)
			check(app._match_playfield.get_global_rect().grow(1).encloses(card.get_global_rect()), "Match keeps each new word inside its original board")
			if word == representatives[0]:
				check_catalog_labels(card, pictured_words, "Match", dimensions)
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
					check_catalog_labels(word_cards[0], pictured_words, "Memory", dimensions)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Expanded word layouts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
