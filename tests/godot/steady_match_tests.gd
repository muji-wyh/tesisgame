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
	check(app.grid.get_rect().is_equal_approx(Rect2(Vector2.ZERO, app._match_playfield.size)),
		stage + ": the board fills its entire playfield without a feedback reserve")
	check(not app._message.is_visible_in_tree(), stage + ": no feedback footer takes space from the cards")

func check_feedback(app, ids: Array, correct: bool) -> void:
	check(app.model.phase == "feedback" and app.model.feedback_ids == ids and app.model.last_correct == correct,
		"Feedback belongs to exactly the two chosen board cards")
	check(not app.feedback_timer.is_stopped(), "A judged pair always schedules automatic progress")
	for id in ids:
		var card: Button = app.cards[id]
		var data: Dictionary = app.model.card_by_id(id)
		check(card.get_theme_stylebox("normal").border_color == (app.Style.GOOD if correct else app.Style.WRONG),
			"The board card itself marks the correct or incorrect answer: " + id)
		check(card.picture.texture.resource_path == "res://" + data.word.image and card.word_label.text == data.word.text,
			"Feedback preserves the card's original word and picture")
		if correct:
			check(card.match_mark.visible and not card.disabled
				and card.picture.modulate.a == 1.0 and card.word_label.modulate.a == 1.0,
				"Completed cards remain fully readable and enabled for pronunciation replay")
	check(not app._message.is_visible_in_tree()
		and app.find_children("*", "Button", true, false).all(func(button: Button) -> bool:
			return not button.is_visible_in_tree() or not button.text in ["Continue", "See reward", "See result"]),
		"Neither ordinary nor terminal feedback adds a separate result action")
	check(app.cards.values().has(root.gui_get_focus_owner()), "Feedback keeps keyboard/controller focus on the board")

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
	app._controller_mode = true
	await check_feedback_hints(app)
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
		check_feedback(app, [first, pairs[1] + ":image"], false)
		app.cards[first].pressed.emit()
		check(app.model.selected_id == first, "The next card replaces wrong feedback on its first tap")
		app.cards[pairs[0] + ":image"].pressed.emit()
		check_board(app, before, "correct feedback immediately")
		await settle()
		check_board(app, before, "correct feedback settled")
		check_feedback(app, [first, pairs[0] + ":image"], true)
		app._controller_back()
		check(app.model.phase == "waiting", "Back dismisses feedback without selecting or scoring a card")
		await settle()
		check_board(app, before, "Back after correct")
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
		check(app.model.feedback_ids.is_empty() and root.gui_get_focus_owner() == app.cards[next],
			"The tapped card clears old feedback and owns visible selection and keyboard focus")
		app._continue_match()
		check(app.model.selected_id == next and root.gui_get_focus_owner() == app.cards[next], "A stale Continue cannot steal the new selection or focus")
		await settle()
		check_board(app, before, "Direct selection after wrong")
		app.cards[next].pressed.emit()
		check(app.model.phase == "waiting", "A repeated tap cancels the new selection without a mistake")
		app.cards[pairs[1] + ":word"].pressed.emit()
		app.cards[pairs[1] + ":image"].pressed.emit()
		app.cards[pairs[1] + ":word"].pressed.emit()
		check(app.model.phase == "feedback" and not app.cards[pairs[1] + ":word"].disabled
			and app.model.successes == 2 and app.model.selected_id.is_empty(),
			"Replaying a completed card cannot dismiss feedback, select it, or score twice")
		app.cards[next].pressed.emit()
		check(app.model.selected_id == next and app.model.successes == 2, "Correct feedback also accepts the first tap on another card")
		app.cards[pairs[2] + ":image"].pressed.emit()
		check(app.model.phase == "feedback" and app.model.successes == 3, "The final pair scores exactly once")
		check_feedback(app, [next, pairs[2] + ":image"], true)
		var final_hints: int = app.model.hints_remaining
		app._request_hint()
		check(app.hint_button.disabled and app.model.phase == "feedback" and app.model.hints_remaining == final_hints,
			"Hint cannot bypass the terminal feedback timer or spend unused allowance")
		var orphan: String = ""
		for id in app.cards:
			if not app.model.matched_ids.has(id):
				orphan = id
				break
		if dimensions == Vector2i(480, 480):
			app.cards[orphan].pressed.emit()
			check(app.model.phase == "won" and app.model.selected_id.is_empty(),
				"A card tap after the final pair advances only to the result")
		else:
			await create_timer(0.8).timeout
			check(app.model.phase == "won" and app.model.selected_id.is_empty(),
				"The final pair automatically enters the result without another button")
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
	check(app.model.phase == "feedback" and not app.feedback_timer.is_stopped(),
		"The third mistake retains its brief on-board feedback")
	await create_timer(0.8).timeout
	check(app.model.phase == "lost" and app.model.selected_id.is_empty() and app.model.mistakes == 3,
		"The third mistake automatically advances to loss without another attempt")
	check(root.gui_get_focus_owner() == app._new_adventure_button, "The losing result focuses New adventure")
	app.new_round(21, true)
	await settle()
	var before_orphan: Dictionary = board_state(app)
	for kind in ["word", "image"]:
		var orphan: Dictionary = {}
		var paired: Dictionary = {}
		for card in app.model.cards:
			var partner: Dictionary = app.model.card_by_id(card.word.id + (":image" if card.kind == "word" else ":word"))
			if card.kind == kind and partner.is_empty():
				orphan = card
			elif card.kind != kind and not partner.is_empty():
				paired = card
		app.cards[orphan.id].pressed.emit()
		app.cards[paired.id].pressed.emit()
		await settle()
		check(app.model.missed_word_ids.has(orphan.word.id) and app.model.missed_word_ids.has(paired.word.id),
			"Both words in an unpaired-card mistake remain in missed-first result review")
		check_feedback(app, [orphan.id, paired.id], false)
		check_board(app, before_orphan, "Unpaired " + kind)
		var feedback_ids: Array = app.model.feedback_ids.duplicate()
		app._show_collection()
		check(app.feedback_timer.paused and app._focus_candidates().all(func(control: Control) -> bool:
			return not app.cards.values().has(control)), "More pauses feedback and removes the covered board from navigation")
		app.cards[orphan.id].pressed.emit()
		check(app.model.feedback_ids == feedback_ids, "Covered cards cannot clear either incorrect mark")
		app._hide_collection()
		check(app.model.feedback_ids == feedback_ids and not app.feedback_timer.paused,
			"Returning from More preserves the marked cards and resumes automatic progress")
		app._controller_back()
	for mode in ["pop", "memory", "match"]:
		root.size = Vector2i(480, 900)
		app.choose_mode(mode)
		await settle()
		root.size = Vector2i(480, 480)
		await settle()
		var view: Control = app._pop if mode == "pop" else app._memory if mode == "memory" else app.grid
		check(app.get_global_rect().grow(1).encloses(view.get_global_rect()), mode + " returns to the smaller viewport without stale container height: " + str(view.get_global_rect()))
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Steady Match: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_feedback_hints(app) -> void:
	for correct in [true, false]:
		app.new_round(21, true)
		await settle()
		var before: Dictionary = board_state(app)
		app._request_hint()
		var first_hint: Array = app.model.hint_ids.duplicate()
		var other: String = first_hint[1]
		if not correct:
			for card in app.model.cards:
				if card.kind != app.model.card_by_id(first_hint[0]).kind and card.word.id != app.model.card_by_id(first_hint[0]).word.id:
					other = card.id
					break
		app.cards[first_hint[0]].pressed.emit()
		app.cards[other].pressed.emit()
		check(app.model.phase == "feedback" and app.model.hints_remaining == 2,
			"The reported screen is feedback with two hints left")
		check(not app.hint_button.disabled and app.hint_button.focus_mode == Control.FOCUS_ALL
			and app.hint_button.count == 2,
			"Both correct and wrong nonfinal feedback keep two hints available")
		var successes: int = app.model.successes
		var mistakes: int = app.model.mistakes
		app._show_collection()
		app._layout()
		check(app.hint_button.focus_mode == Control.FOCUS_NONE,
			"Relayout cannot expose the covered Hint to keyboard navigation")
		app._request_hint()
		check(app.model.phase == "feedback" and app.model.hints_remaining == 2,
			"A covered Hint cannot dismiss feedback or spend a hint")
		app._hide_collection()
		app.hint_button.pressed.emit()
		check(app.model.phase == "waiting" and app.model.hints_remaining == 1 and app.model.hint_ids.size() == 2,
			"One Hint press acknowledges feedback and highlights a remaining pair")
		check(app.model.successes == successes and app.model.mistakes == mistakes,
			"Hint never scores an extra match or mistake")
		check(app.model.feedback_ids.is_empty() and app.model.hint_ids.all(
			func(id: String) -> bool: return not app.model.matched_ids.has(id)),
			"Hint replaces feedback with stars on unmatched cards only")
		app._request_hint()
		check(app.model.hints_remaining == 1, "Repeated input cannot charge for the same active hint")
		await settle()
		check_board(app, before, "Hint from feedback")
	app.new_round(21, true)
	app._request_hint()
	var spoken_word: Dictionary = app.model.card_by_id(app.model.hint_ids[0]).word
	app._on_voice_state([true, true, "Listening"])
	app._on_voice_result([spoken_word.text, true])
	check(app.model.phase == "feedback" and app.hint_button.disabled,
		"Timed voice feedback keeps its queue lock")
	app._request_hint()
	check(app.model.phase == "feedback" and app.model.hints_remaining == 2 and not app.feedback_timer.is_stopped(),
		"Hint cannot interrupt queued speech or spend an allowance")
	app._stop_voice()
	check(not app.hint_button.disabled and app.hint_button.focus_mode == Control.FOCUS_ALL,
		"Stopping voice immediately restores the manual feedback Hint")
	app._request_hint()
	check(app.model.hints_remaining == 1 and app.model.successes == 1,
		"Hint after leaving voice continues manually without scoring twice")
	app.new_round(21, true)
	app._request_hint()
	var pair: Array = app.model.hint_ids.duplicate()
	for attempt in range(3):
		app.cards[pair[0]].pressed.emit()
		var wrong: String = ""
		for card in app.model.cards:
			if card.kind != app.model.card_by_id(pair[0]).kind and card.word.id != app.model.card_by_id(pair[0]).word.id:
				wrong = card.id
				break
		app.cards[wrong].pressed.emit()
		if attempt < 2:
			app._continue_match()
	app._request_hint()
	check(app.hint_button.disabled and app.model.phase == "feedback" and app.model.hints_remaining == 2,
		"Hint cannot skip the third-mistake result or consume remaining allowance")
