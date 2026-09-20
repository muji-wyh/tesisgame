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
	var new_words: Array = app.data.words.slice(140)
	check(new_words.size() == 60, "All sixty new words receive real-mode layout coverage")
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(480, 480), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		for word in new_words:
			var topic: Dictionary = app.Data.ADVENTURES.filter(func(value: Dictionary) -> bool: return value.words.has(word.id))[0]
			check(app.new_round(19, false, topic.id, "match", word.id), "A lesson can render its new noun: " + word.id)
			await settle()
			var card: Button = app.cards[word.id + ":word"]
			check_label(card.word_label, word, "Match", dimensions)
			check(app._match_playfield.get_global_rect().grow(1).encloses(card.get_global_rect()), "Match keeps each new word inside its original board")
			app.choose_mode("memory")
			app._memory.begin_peek()
			await settle()
			var word_cards: Array = app._memory.card_buttons.filter(
				func(value: Button) -> bool: return value.card_data.kind == "word" and value.card_data.word.id == word.id)
			check(word_cards.size() == 1, "Memory still has exactly one word partner for each new noun")
			if word_cards.size() == 1:
				check_label(word_cards[0].word_label, word, "Memory", dimensions)
				check(app._memory.get_global_rect().grow(1).encloses(word_cards[0].get_global_rect()), "Memory keeps new words inside its five-pair board")
			app.choose_mode("match")
			for phase in ["lost", "won"]:
				app.model.phase = phase
				app._refresh()
				await settle()
				for review in app._found_words.get_children():
					var label: Label = review.get_child(1)
					var font: Font = label.get_theme_font("font")
					var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
					check(width <= label.size.x - 8 and review.size.x >= 72,
						"%s %s review shows the full spelling of %s: text=%s label=%s" % [dimensions, phase, label.text, width, label.size.x])
				app.model.phase = "waiting"
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Expanded word layouts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
