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
		app.cards[pairs[1] + ":word"].pressed.emit()
		app.cards[pairs[2] + ":image"].pressed.emit()
		var next: String = pairs[2] + ":word"
		check(not app.cards[next].disabled, "An unmatched card remains actionable during wrong feedback")
		app._select_card("missing-card")
		check(app.model.phase == "feedback", "An invalid card cannot dismiss feedback")
		app._show_collection()
		app.cards[next].pressed.emit()
		check(app.model.phase == "feedback", "A covered board cannot dismiss feedback")
		app._hide_collection()
		app.cards[next].pressed.emit()
		check(app.model.phase == "matching" and app.model.selected_id == next, "The first tap after a mistake selects that exact card")
		check(app.model.mistakes == 2 and app.model.successes == 1, "Continuing by card does not score another attempt")
		check(not app._match_feedback.visible and root.gui_get_focus_owner() == app.cards[next], "The tapped card owns visible selection and keyboard focus")
		app._continue_match()
		check(app.model.selected_id == next and root.gui_get_focus_owner() == app.cards[next], "A stale Continue cannot steal the new selection or focus")
		await settle()
		check_board(app, before, "Direct selection after wrong")
		app.cards[next].pressed.emit()
		check(app.model.phase == "waiting", "A repeated tap cancels the new selection without a mistake")
		app.cards[pairs[1] + ":word"].pressed.emit()
		app.cards[pairs[1] + ":image"].pressed.emit()
		app.cards[pairs[1] + ":word"].pressed.emit()
		check(app.model.phase == "feedback" and app.cards[pairs[1] + ":word"].disabled, "Completed cards cannot dismiss feedback or score twice")
		app.cards[next].pressed.emit()
		check(app.model.selected_id == next and app.model.successes == 2, "Correct feedback also accepts the first tap on another card")
		app.cards[pairs[2] + ":image"].pressed.emit()
		check(app.model.phase == "feedback" and app.model.successes == 3, "The final pair scores exactly once")
		var orphan: String = ""
		for id in app.cards:
			if not app.model.matched_ids.has(id):
				orphan = id
				break
		app.cards[orphan].pressed.emit()
		check(app.model.phase == "won" and app.model.selected_id.is_empty(), "A card tap after the final pair advances only to the result")
		check(root.gui_get_focus_owner() == app.chest_button, "The winning result keeps chest focus")
		app.cards[orphan].pressed.emit()
		app._continue_match()
		check(app.model.phase == "won" and app.model.successes == 3 and app.model.mistakes == 2, "Repeated result input neither restarts nor scores")
	app.new_round(21, true)
	var wrong: Array = []
	for card in app.model.cards:
		if wrong.is_empty() or (card.kind != wrong[0].kind and card.word.id != wrong[0].word.id):
			wrong.append(card)
		if wrong.size() == 2:
			break
	for attempt in range(3):
		app.cards[wrong[0].id].pressed.emit()
		app.cards[wrong[1].id].pressed.emit()
		if attempt < 2:
			app._continue_match()
	app.cards[wrong[0].id].pressed.emit()
	check(app.model.phase == "lost" and app.model.selected_id.is_empty() and app.model.mistakes == 3, "A tap after the third mistake advances to loss without another attempt")
	check(root.gui_get_focus_owner() == app.replay_button, "The losing result keeps replay focus")
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
