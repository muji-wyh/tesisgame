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

func settle() -> void:
	for frame in range(5):
		await process_frame

func board_state(app) -> Dictionary:
	var result: Dictionary = {}
	for id in app.cards:
		result[id] = app.cards[id].get_global_rect()
	return result

func check_board(app, before: Dictionary, stage: String) -> void:
	check(app.grid.is_visible_in_tree(), stage + ": board remains visible")
	for id in before:
		var card: Control = app.cards[id]
		check(card.get_global_rect().is_equal_approx(before[id]), stage + ": " + id + " stays in place")
		check(card.scale == Vector2.ONE and is_zero_approx(card.rotation), stage + ": no card bounce or shake")
		check(app.get_global_rect().grow(1).encloses(card.get_global_rect()), stage + ": card stays inside screen")
		check(card.size.x >= 44 and card.size.y >= 44, stage + ": usable card target")
	if app._match_feedback.is_visible_in_tree():
		for control in app._match_feedback.controls():
			check(app.get_global_rect().grow(1).encloses(control.get_global_rect()), stage + ": feedback %s fits %s inside %s" % [control.name, control.get_global_rect(), app.get_global_rect()])
			check(not app.grid.get_global_rect().intersects(control.get_global_rect()), stage + ": feedback leaves board clear")

func _run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	var directory := "user://steady-match-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.choose_mode("match")
	for dimensions in [Vector2i(480, 480), Vector2i(854, 480), Vector2i(480, 720), Vector2i(480, 1038)]:
		root.size = dimensions
		app.size = dimensions
		app.new_round(21, true)
		await settle()
		var before: Dictionary = board_state(app)
		var pairs: Array = []
		for card in app.model.cards:
			if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
				pairs.append(card.word.id)
		var first: String = pairs[0] + ":word"
		app.cards[first].pressed.emit()
		await settle()
		check_board(app, before, str(dimensions) + " first selection")
		app.cards[first].pressed.emit()
		await settle()
		check_board(app, before, "deselect")
		app.cards[first].pressed.emit()
		app.cards[pairs[1] + ":image"].pressed.emit()
		check_board(app, before, "wrong feedback immediately")
		await settle()
		check_board(app, before, "wrong feedback settled")
		var attempts: int = app.model.mistakes
		app.cards[pairs[2] + ":word"].pressed.emit()
		check(app.model.mistakes == attempts and app.model.phase == "feedback", "Rapid answer cannot bypass feedback")
		app._match_feedback.next_button.pressed.emit()
		await settle()
		check_board(app, before, "second correction word")
		app._match_feedback.action_button.pressed.emit()
		await settle()
		check_board(app, before, "Continue after wrong")
		app.cards[first].pressed.emit()
		app.cards[pairs[0] + ":image"].pressed.emit()
		check_board(app, before, "correct feedback immediately")
		await settle()
		check_board(app, before, "correct feedback settled")
		app._match_feedback.action_button.pressed.emit()
		await settle()
		check_board(app, before, "Continue after correct")
		check(app.model.successes == 1 and app.model.mistakes == 1, "Exactly one match and mistake recorded")
	for mode in ["learn", "sky", "listen", "memory", "match"]:
		root.size = Vector2i(480, 900)
		app.choose_mode(mode)
		await settle()
		root.size = Vector2i(480, 480)
		await settle()
		var view: Control = app._lesson if mode == "learn" else app._choice if mode in ["sky", "listen"] else app._memory if mode == "memory" else app.grid
		check(app.get_global_rect().grow(1).encloses(view.get_global_rect()), mode + " returns to the smaller viewport without stale container height: " + str(view.get_global_rect()))
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Steady Match: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
