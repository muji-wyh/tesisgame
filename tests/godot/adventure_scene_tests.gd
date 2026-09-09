extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	var properties: Array = app.get_property_list().map(
		func(property: Dictionary) -> String: return property.name)
	var integrated := true
	for property in ["_found_words", "_adventure_label", "_goal_label", "_goal_medal"]:
		check(properties.has(property), "The adventure scene provides " + property)
		integrated = integrated and properties.has(property)
	if not integrated:
		app.free()
		print("Adventure scene: %d assertions, %d failures" % [checks, failures])
		quit(1)
		return
	var directory := "user://adventure-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "The adventure fixture has isolated storage")
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	app.new_round(17)
	app.choose_theme("spring")
	var adventure: Variant = app.model.get("adventure_name")
	check(adventure is String and not str(adventure).is_empty()
		and app._adventure_label.text == adventure and app._adventure_label.is_visible_in_tree(),
		"The board names the seeded adventure selected by the model")
	check(not app._found_words.is_visible_in_tree() and app._found_words.get_child_count() == 0,
		"An unplayed board has no earned word buttons")
	check(app._goal_label.text.contains("0/3") and app._goal_medal.pieces == 0
		and app._goal_medal.texture != null
		and app._goal_medal.texture.resource_path == "res://assets/images/rewards/spring-1.svg",
		"The rewards button previews the first medal's three-piece goal")
	var words: Array[Dictionary] = _pairs(app)
	check(words.size() == 3, "The scene starts with three matchable words")
	app._request_hint()
	check(app.model.hint_used and app.model.hint_ids.size() == 2,
		"The adventure keeps the existing one-hint path")
	app._controller_mode = true
	for word in words:
		_match(app, word)
	check(app.model.phase == "won" and not app._adventure_label.is_visible_in_tree(),
		"Winning replaces the adventure heading with the result")
	check(app._default_focus() == app.chest_button and app.chest_button.has_focus(),
		"The chest remains the primary controller action after winning")
	_check_shelf(app, words)
	_check_replay(app)
	app._show_collection()
	for button in _buttons(app):
		check(button.focus_mode == Control.FOCUS_NONE and not app._focus_candidates().has(button),
			"The collection modal excludes result words from controller focus")
	app._refresh()
	for button in _buttons(app):
		check(button.focus_mode == Control.FOCUS_NONE,
			"Refreshing beneath the collection keeps result words out of focus")
	app.audio.halt()
	for button in _buttons(app):
		button.pressed.emit()
	check(not app.audio.voice.playing, "The collection blocks pronunciation from covered result buttons")
	app._hide_collection()
	for button in _buttons(app):
		check(app._focus_candidates().has(button), "Closing the collection restores word replay navigation")
	app.audio.set_muted(true)
	app._open_chest()
	check(app.model.chest_state == "opening" and not app._pending_fragment.is_empty(),
		"Opening captures one reward before pronunciation replay")
	_check_replay(app)
	app.chest.finish_immediately()
	app._finish_fragment_delivery()
	check(app.medal_progress.count_for("spring-1") == 1 and app._goal_label.text.contains("1/3")
		and app._goal_medal.pieces == 1,
		"Collecting a fragment immediately updates the visible next goal")
	_check_replay(app)
	app.audio.set_muted(true)
	for dimensions in [Vector2i(320, 320), Vector2i(320, 321), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		await process_frame
		await process_frame
		_check_result_bounds(app)
	app.new_round(17)
	check(app._adventure_label.text == adventure and app._adventure_label.is_visible_in_tree(),
		"The same seed restores the same visible adventure")
	check(app._found_words.get_child_count() == 0 and not app._found_words.is_visible_in_tree()
		and not app.model.hint_used, "Reset removes old word actions and renews the hint")
	app.medal_progress.counts["spring-1"] = 3
	app.choose_theme("spring")
	check(app._goal_label.text.contains("0/3") and app._goal_medal.pieces == 0
		and app.collection_button.tooltip_text.contains("Ladybug")
		and app._goal_medal.texture != null
		and app._goal_medal.texture.resource_path == "res://assets/images/rewards/spring-2.svg",
		"Completing Blossom moves the next goal to Ladybug")
	app.choose_theme("winter")
	check(app.collection_button.tooltip_text.contains("Snowflake") and app._goal_label.text.contains("0/3"),
		"Changing season updates the reward goal without changing the adventure")
	check(app._adventure_label.text == adventure, "Season selection preserves the current adventure topic")
	for index in range(1, 7):
		app.medal_progress.counts["winter-%d" % index] = 3
	app._refresh()
	check(app._goal_label.text.contains("6/6"), "A completed season shows six collected medals")
	app.new_round(19)
	words = _pairs(app)
	if not words.is_empty():
		_match(app, words[0])
		check(not app._found_words.is_visible_in_tree(), "Matched words stay off the active board")
		_lose(app)
		check(app.model.phase == "lost" and app.model.successes == 1,
			"A round can end with one learned word and three mistakes")
		_check_shelf(app, [words[0]])
		check(app._default_focus() == app.replay_button and app.replay_button.has_focus(),
			"Replay stays the primary controller action after losing")
		_check_replay(app)
		root.size = Vector2i(320, 320)
		await process_frame
		await process_frame
		_check_result_bounds(app)
	app.audio.set_muted(true)
	app.new_round(20)
	_lose(app)
	check(app.model.phase == "lost" and app.model.successes == 0
		and not app._found_words.is_visible_in_tree() and app._found_words.get_child_count() == 0,
		"A loss without matches does not invent word rewards")
	app.new_round(21)
	words = _pairs(app)
	app._on_voice_state([true, true, "Listening"])
	if not words.is_empty():
		app._on_voice_result(["I see " + words[0].text, true])
		app.feedback_timer.timeout.emit()
		_lose(app)
		_check_shelf(app, [words[0]])
		check(not app._voice_mode, "Voice-earned words use the same result shelf and exit listening")
	app.new_round(22)
	words = _pairs(app)
	_match(app, words[0])
	_match(app, words[1])
	app.cards[words[2].id + ":word"].pressed.emit()
	app.cards[words[2].id + ":image"].pressed.emit()
	app._show_collection()
	app.feedback_timer.timeout.emit()
	check(app.model.phase == "won" and app.collection_page.visible,
		"A final match can finish beneath the collection")
	for button in _buttons(app):
		check(not app._focus_candidates().has(button), "Late result words cannot escape the active modal")
	app._hide_collection()
	_check_shelf(app, words)
	for button in _buttons(app):
		check(app._focus_candidates().has(button), "Late result words become reachable after closing the collection")
	app.on_page_hidden()
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	var files := DirAccess.open(directory)
	for filename in files.get_files():
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Adventure scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _pairs(app) -> Array[Dictionary]:
	var words: Array[Dictionary] = []
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			words.append(card.word)
	return words


func _match(app, word: Dictionary) -> void:
	app.cards[word.id + ":word"].pressed.emit()
	app.cards[word.id + ":image"].pressed.emit()
	app.feedback_timer.timeout.emit()


func _lose(app) -> void:
	var wrong: Array[String] = []
	for card in app.model.cards:
		if app.model.card_by_id(card.word.id + (":image" if card.kind == "word" else ":word")).is_empty():
			wrong.append(card.id)
	check(wrong.size() == 2, "The loss fixture uses the board's two genuine distractors")
	if wrong.size() != 2:
		return
	for attempt in range(3):
		app.cards[wrong[0]].pressed.emit()
		app.cards[wrong[1]].pressed.emit()
		app.feedback_timer.timeout.emit()


func _buttons(app) -> Array[Button]:
	var buttons: Array[Button] = []
	for child in app._found_words.get_children():
		if child is Button:
			buttons.append(child)
	return buttons


func _check_shelf(app, expected: Array) -> void:
	var buttons: Array[Button] = _buttons(app)
	check(app._found_words.is_visible_in_tree() and buttons.size() == expected.size(),
		"Results show exactly one button per unique matched word")
	var seen: Array[String] = []
	for button in buttons:
		var id := str(button.get_meta("word_id", ""))
		var matching: Array = expected.filter(func(word: Dictionary) -> bool: return word.id == id)
		check(not id.is_empty() and not seen.has(id) and matching.size() == 1,
			"Word replay excludes duplicate, unmatched, and distractor words")
		seen.append(id)
		if matching.size() != 1:
			continue
		var word: Dictionary = matching[0]
		var labels: Array = button.find_children("*", "Label", true, false)
		var pictures: Array = button.find_children("*", "TextureRect", true, false)
		check(labels.any(func(label: Label) -> bool: return label.text == word.text)
			and button.tooltip_text == "Hear " + word.text + " again",
			"Word replay displays and announces the vocabulary's actual English text")
		check(pictures.any(func(picture: TextureRect) -> bool:
			return picture.texture != null and picture.texture.resource_path == "res://" + word.image),
			"Word replay shows the picture matching its pronunciation")


func _state(app) -> Dictionary:
	return {"successes": app.model.successes, "mistakes": app.model.mistakes,
		"phase": app.model.phase, "streak": app.model.streak, "hint": app.model.hint_used,
		"chest": app.model.chest_state, "reward": app.model.reward_id,
		"matched": app.model.matched_ids.duplicate(), "pending": app._pending_fragment.duplicate(true),
		"medals": app.medal_progress.counts.duplicate(), "collected": app.collected_rewards.duplicate()}


func _check_replay(app) -> void:
	var before: Dictionary = _state(app)
	# Returning from a hidden page leaves real audio inactive until the next gesture.
	app.audio.halt()
	app.audio.set_muted(false)
	for button in _buttons(app):
		var word: Dictionary = app.model.card_by_id(str(button.get_meta("word_id", "")) + ":word").get("word", {})
		if word.is_empty():
			continue
		app.duck.settle()
		for tap in range(8):
			button.pressed.emit()
		check(app.audio.voice.playing and app.audio.voice.stream.resource_path == "res://" + word.audio,
			"Tapping a found word replays that word's bundled pronunciation")
		check(app.duck.reaction_left > 0.0, "Pip reacts when a found word is replayed")
		check(_state(app) == before, "Repeated word taps preserve scoring, chest, pending piece, and saved progress")
		if app.model.phase == "lost":
			check(not app.audio.music.playing and not app.audio._music_pending,
				"Replaying a word after loss never restarts background music")


func _check_result_bounds(app) -> void:
	var viewport: Rect2 = root.get_visible_rect().grow(0.5)
	var buttons: Array[Button] = _buttons(app)
	for button in buttons:
		check(button.size.x >= 72 and button.size.y >= 72,
			"Found words retain 72px logical touch targets")
		check(viewport.encloses(button.get_global_rect()),
			"Found-word actions fit the viewport: %s at %s" % [root.size, button.get_global_rect()])
		check(not button.get_global_rect().intersects(app.replay_button.get_global_rect())
			and not button.get_global_rect().intersects(app._stage.get_global_rect()),
			"Found-word actions do not overlap the chest or replay button")
	for index in range(1, buttons.size()):
		check(not buttons[index - 1].get_global_rect().intersects(buttons[index].get_global_rect()),
			"Adjacent found words retain separate touch targets")
	for control in [app.replay_button, app._title, app._caption]:
		var children: Array = app._result_text.get_children().filter(
			func(child: Control) -> bool: return child.is_visible_in_tree()).map(
			func(child: Control) -> String:
				return "%s: %s, minimum %s" % [child.text if child is Label else child.name,
					child.get_global_rect(), child.get_combined_minimum_size()])
		check(viewport.encloses(control.get_global_rect()),
			"Result control fits around the shelf: %s %s, bounds %s, viewport %s, outcome %s, text minimum %s; children %s" %
			[root.size, control.name, control.get_global_rect(), viewport, app._outcome.get_global_rect(),
				app._result_text.get_combined_minimum_size(), children])
