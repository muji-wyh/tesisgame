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
	for frame in range(5):
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 800)
	var directory := "user://three-modes-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	check(app.MODES.keys() == ["match", "learn", "memory", "pop"], "The original modes stay ordered before the new Voice Pop mode")
	check(app._mode_buttons.size() == 4, "Each of the four modes has one visible tab")
	check(FileAccess.file_exists("res://scripts/icon_button.gd"), "Toolbar and peek controls share drawn icons")
	for button in [app.collection_button, app.hint_button, app._voice_button]:
		check(button.text.is_empty(), "The top-right actions use icons rather than text")
		check(is_equal_approx(button.size.x, button.size.y) and button.size.x >= 44 and button.size.x <= 48,
			"Toolbar actions are compact square touch targets")
	check(app._mode_buttons.all(func(button: Button) -> bool:
		return button.size.x >= 44 and button.size.x <= 96 and button.size.y >= 44 and button.size.y <= 48),
		"Mode tabs have compact natural widths and accessible heights")
	check(app.find_children("*", "Label", true, false).all(func(label: Label) -> bool:
		return not label.is_visible_in_tree() or not label.text in ["Pip and Words", app.model.adventure_name]),
		"The play screen has no redundant brand or topic headings")
	app.choose_mode("match")
	await settle()
	check(app.find_child("MatchCorrection", true, false) == null, "Match has no correction footer")
	check(app.grid.size.is_equal_approx(app._match_playfield.size), "The matching board uses the entire playfield")
	var pairs: Array[String] = []
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			pairs.append(card.word.id)
	app.cards[pairs[0] + ":word"].pressed.emit()
	app.cards[pairs[0] + ":image"].pressed.emit()
	check(not app.feedback_timer.is_stopped(), "Correct feedback continues automatically without a footer button")
	var word: Dictionary = app.model.card_by_id(pairs[0] + ":word").word
	var hints: int = app.model.hints_remaining
	app.audio.halt()
	check(not app.cards[pairs[0] + ":word"].disabled, "A matched word remains an available pronunciation target")
	app.cards[pairs[0] + ":word"].pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + word.audio),
		"A matched card pronounces its exact word")
	check(app.model.successes == 1 and app.model.hints_remaining == hints, "Replaying a matched card cannot score or spend hints")
	app._show_collection()
	await create_timer(0.8).timeout
	check(app.model.phase == "feedback" and app.model.successes == 1, "More pauses automatic Match feedback")
	app._hide_collection()
	await create_timer(0.8).timeout
	check(app.model.phase == "waiting" and app.model.successes == 1, "The next pair is ready without extra confirmation")
	app.cards[pairs[1] + ":word"].pressed.emit()
	app.cards[pairs[2] + ":image"].pressed.emit()
	check(not app.feedback_timer.is_stopped() and not app._message.is_visible_in_tree(), "Wrong feedback also stays on the board")
	app.on_page_hidden()
	await create_timer(0.8).timeout
	check(app.model.phase == "feedback", "Background pages do not advance Match feedback")
	app.on_page_visible()
	await create_timer(0.8).timeout
	check(app.model.phase == "waiting" and app.model.mistakes == 1, "A wrong pair clears automatically without resetting progress")
	app.choose_mode("memory")
	await settle()
	check(app._memory.has_method("begin_peek") and app._memory.has_method("end_peek"), "Memory exposes hold-to-peek input")
	check(app._memory.find_child("MemoryFeedback", true, false) == null
		and app._memory.find_child("MemoryReviewHint", true, false) == null, "Memory has no bottom panel")
	if app._memory.has_method("begin_peek") and app._memory.has_method("end_peek"):
		app._memory.begin_peek()
		check(app._memory.memory.studying, "Holding the eye reveals the board")
		app._memory.end_peek()
		check(not app._memory.memory.studying and range(10).all(func(index: int) -> bool:
			return not app._memory.memory.is_revealed(index)), "Releasing the eye turns every face back")
		app._memory.begin_peek()
		app.on_page_hidden()
		check(not app._memory.memory.studying, "Hiding the page releases a held eye")
		app.on_page_visible()
	app.choose_mode("match")
	app._show_error("The game data could not load.")
	await settle()
	check(app._message.is_visible_in_tree() and app._message.size.x >= 200,
		"Removing the footer does not remove a readable fatal-error message")
	app.audio.halt()
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Three-mode game: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
