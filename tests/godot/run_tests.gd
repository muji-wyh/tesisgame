extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func has_property(value: Object, property_name: String) -> bool:
	for property in value.get_property_list():
		if property.name == property_name:
			return true
	return false


func _run() -> void:
	var path := "res://scripts/game_model.gd"
	check(FileAccess.file_exists(path), "The Godot game model exists")
	if not FileAccess.file_exists(path):
		quit(1)
		return
	var model_script: GDScript = load(path)
	check(model_script != null and model_script.can_instantiate(), "The model compiles")
	if model_script == null or not model_script.can_instantiate():
		quit(1)
		return
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	_test_rounds(model_script, words)
	_test_fresh_rounds(model_script, words)
	_test_matching(model_script, words)
	_test_hints_and_streaks(model_script, words)
	_test_results(model_script, words)
	_test_data(words)
	_test_controls()
	_test_effects()
	await _test_audio()
	await _test_scene()
	print("Godot: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func pairs_for(model) -> Array:
	var pairs: Array = []
	for card in model.cards:
		if card.kind != "word":
			continue
		for other in model.cards:
			if other.kind == "image" and card.word.id == other.word.id:
				pairs.append([card.id, other.id])
	return pairs


func wrong_pair_for(model) -> Array:
	for card in model.cards:
		for other in model.cards:
			if card.kind != other.kind and card.word.id != other.word.id:
				return [card.id, other.id]
	return []


func win_round(app) -> void:
	for pair in pairs_for(app.model):
		app.cards[pair[0]].pressed.emit()
		app.cards[pair[1]].pressed.emit()
		app.feedback_timer.timeout.emit()


func set_completed_rewards(app, rewards: Dictionary) -> void:
	app.medal_progress.counts.clear()
	app.medal_progress.legacy_rewards.clear()
	var data_script = load("res://scripts/game_data.gd")
	for id in rewards:
		if not data_script.medal(id).is_empty():
			app.medal_progress.counts[id] = 3
		else:
			app.medal_progress.legacy_rewards[id] = true
	app._refresh_collection()


func prepare_completion(app) -> void:
	var fragment: Dictionary = app.medal_progress.next_fragment(app.model.theme_id)
	check(not fragment.is_empty(), "The completion fixture has a medal left to finish")
	if not fragment.is_empty():
		app.medal_progress.counts[fragment.medal_id] = 2
		app._refresh_collection()


func visible_reward_flight(app) -> TextureRect:
	if not has_property(app, "_reward_flight_image"):
		return null
	var flight = app._reward_flight_image
	if flight != null and is_instance_valid(flight) and flight.visible:
		return flight as TextureRect
	return null


func check_no_reward_flight(app, message: String) -> void:
	check(has_property(app, "_reward_flight_image"), "The reward flight overlay exists")
	check(visible_reward_flight(app) == null, message)


func step_reward_tween(app, seconds: float, message: String) -> void:
	check(app._reward_tween != null and app._reward_tween.is_valid(), message)
	if app._reward_tween != null:
		app._reward_tween.pause()
		app._reward_tween.custom_step(seconds)


func collection_scroll(app) -> ScrollContainer:
	if has_property(app, "_collection_scroll"):
		return app._collection_scroll as ScrollContainer
	var scrolls: Array = app.collection_page.find_children("*", "ScrollContainer", true, false)
	return scrolls[0] as ScrollContainer if not scrolls.is_empty() else null


func reward_slot_button(app, id: String) -> Button:
	if not app._reward_slots.has(id):
		return null
	var slot: Dictionary = app._reward_slots[id]
	return slot.get("button") as Button


func preview_visible(app) -> bool:
	return has_property(app, "_preview_page") and app._preview_page != null and app._preview_page.visible


func preview_tween_valid(app) -> bool:
	return has_property(app, "_preview_tween") and app._preview_tween != null and app._preview_tween.is_valid()


func preview_sparkle_visible(app) -> bool:
	return has_property(app, "_preview_sparkle") and app._preview_sparkle != null and app._preview_sparkle.visible


func local_mouse_event(source: Control, event: InputEventMouse, global_position: Vector2) -> InputEventMouse:
	event.position = source.get_global_transform().affine_inverse() * global_position
	return event


func emit_scroll_press(source: Control, global_position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	source.gui_input.emit(local_mouse_event(source, event, global_position))


func emit_scroll_motion(source: Control, global_position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.relative = relative
	source.gui_input.emit(local_mouse_event(source, event, global_position))


func emit_scroll_wheel(source: Control, global_position: Vector2, button_index: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	source.gui_input.emit(local_mouse_event(source, event, global_position))


func joy_button(button: int, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func joy_tap(button: int) -> void:
	joy_button(button, true)
	joy_button(button, false)


func joy_axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _test_rounds(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	var seen_themes: Dictionary = {}
	var seen_words: Dictionary = {}
	for seed_value in range(80):
		check(model.reset(words, seed_value), "A valid vocabulary starts a round")
		check(model.cards.size() == 8, "There are eight cards")
		check(pairs_for(model).size() == 3, "There are exactly three complete pairs")
		var ids: Dictionary = {}
		var counts: Dictionary = {}
		var kinds: Dictionary = {"word": 0, "image": 0}
		for card in model.cards:
			seen_words[card.word.id] = true
			ids[card.id] = true
			counts[card.word.id] = counts.get(card.word.id, 0) + 1
			kinds[card.kind] += 1
		check(ids.size() == 8, "Card IDs are unique")
		check(counts.size() == 5, "Pairs and distractors use five distinct words")
		check(counts.values().count(1) == 2, "Two cards have no matching partner")
		check(kinds.word == 4 and kinds.image == 4, "Distractors are one of each kind")
		check(model.phase == "waiting", "Rounds start waiting")
		check(model.successes == 0 and model.mistakes == 0, "Counters reset")
		seen_themes[model.theme_id] = true
	check(seen_themes.size() == 6, "New rounds can choose each theme")
	for seed_value in range(80, 1000):
		if seen_words.size() == words.size():
			break
		model.reset(words, seed_value)
		for card in model.cards:
			seen_words[card.word.id] = true
	check(seen_words.size() == words.size(), "All 140 words can appear across seeded rounds")
	model.reset(words, 17)
	var deck: Array = model.cards.duplicate(true)
	var season: String = model.theme_id
	model.reset(words, 17)
	check(model.cards == deck and model.theme_id == season, "Seeded rounds are reproducible")
	check(not model.reset(words.slice(0, 4), 1), "Fewer than five words cannot start a round")


func _test_fresh_rounds(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	var vocabulary: Array = words.slice(0, 10)
	model.reset(vocabulary, 17)
	for round_index in range(6):
		var previous: Array = model.cards.map(func(card: Dictionary) -> String: return card.word.id)
		model.reset(vocabulary)
		check(model.cards.all(func(card: Dictionary) -> bool: return not previous.has(card.word.id)),
			"Unseeded replay prefers five words absent from the previous board")
		check(pairs_for(model).size() == 3 and model.cards.size() == 8,
			"Fresh boards retain three complete pairs and eight cards")
	for count in range(5, 10):
		model.reset(words.slice(0, count))
		model.reset(words.slice(0, count))
		check(model.cards.size() == 8 and pairs_for(model).size() == 3,
			"Small vocabularies fall back to a full valid board")
	model.reset(words, 17)
	var expected: Array = model.cards.duplicate(true)
	model.reset(words)
	model.reset(words, 17)
	check(model.cards == expected, "Explicit seeds ignore previous-board exclusions")


func _test_matching(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	model.reset(words, 6)
	var first: Dictionary = model.cards[0]
	check(model.select(first.id) == "selected", "A first click selects a card")
	check(model.phase == "matching" and model.selected_id == first.id, "Selection enters matching")
	check(model.select(first.id) == "cancelled", "A second click on the selection cancels")
	check(model.phase == "waiting", "Cancellation returns to waiting")
	model.select(first.id)
	for card in model.cards:
		if card.kind == first.kind and card.id != first.id:
			check(model.select(card.id) == "reselected", "Same-kind selection is replaced")
			check(model.mistakes == 0, "Reselection does not count as a mistake")
			break
	var before: Array = model.cards.duplicate(true)
	var selected: String = model.selected_id
	check(model.set_theme("winter"), "Theme can change during selection")
	check(model.cards == before and model.selected_id == selected, "Theme change preserves selection/deck")
	check(not model.set_theme("unknown"), "Unknown themes are rejected")
	model.reset(words, 6)
	var wrong: Array = wrong_pair_for(model)
	model.select(wrong[0])
	check(model.select(wrong[1]) == "wrong", "Unrelated opposite kinds are incorrect")
	check(model.mistakes == 1 and model.successes == 0, "Wrong pair increments only mistakes")
	check(model.phase == "feedback", "Wrong feedback locks the round")
	check(model.select(wrong[0]) == "ignored", "Cards cannot be selected during feedback")
	model.resolve_feedback()
	check(model.phase == "waiting" and model.selected_id == "", "Feedback clears selection")
	var pair: Array = pairs_for(model)[0]
	model.select(pair[0])
	check(model.select(pair[1]) == "correct", "Matching opposite kinds are correct")
	check(model.successes == 1 and model.mistakes == 1, "Both counters accumulate independently")
	model.resolve_feedback()
	check(model.matched_ids.size() == 2, "Both matched cards are retained as matched")
	check(model.select(pair[0]) == "ignored", "Matched cards cannot score twice")


func _test_hints_and_streaks(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	check(model.has_method("request_hint") and has_property(model, "hint_ids") and has_property(model, "streak"),
		"The model supports helpful hints and consecutive matches")
	if not model.has_method("request_hint") or not has_property(model, "streak"):
		return
	model.reset(words, 6)
	var deck: Array = model.cards.duplicate(true)
	var pairs: Array = pairs_for(model)
	model.select(pairs[1][1])
	check(model.request_hint() and model.hint_ids.has(pairs[1][0]) and model.hint_ids.has(pairs[1][1]),
		"A hint prefers the selected card's real partner")
	check(model.selected_id == pairs[1][1] and model.successes == 0 and model.mistakes == 0,
		"Hints preserve a useful selection without scoring or penalizing")
	check(not model.request_hint(), "Each round allows only one successful hint request")
	check(model.cards == deck and model.streak == 0, "Repeated hints never shuffle or score the board")
	model.set_theme("winter")
	check(model.hint_ids.size() == 2, "Changing seasons preserves the hint")
	check(not model.request_hint(), "Changing seasons cannot refill the hint")
	model.select(pairs[1][0])
	check(model.hint_ids.is_empty() and model.streak == 1, "Matching clears the hint and starts a streak")
	check(not model.request_hint(), "Hints cannot interrupt feedback")
	model.resolve_feedback()
	check(model.select(pairs[1][0]) == "ignored" and model.streak == 1, "Matched cards cannot inflate a streak")
	check(not model.request_hint(), "Completing a hinted match does not grant another hint")
	model.select(pairs[0][0])
	model.select(pairs[0][1])
	check(model.streak == 2, "Consecutive matches build a streak without a timer")
	model.resolve_feedback()
	model.select(pairs[2][0])
	model.select(pairs[2][1])
	model.resolve_feedback()
	check(model.streak == 3 and model.phase == "won" and not model.request_hint(),
		"A three-match streak wins normally and closes hint input")
	model.reset(words, 6)
	check(model.streak == 0 and model.hint_ids.is_empty(), "Replay clears streaks and hints")
	model.select(pairs[0][0])
	model.select(pairs[0][1])
	check(not model.request_hint(), "A rejected request during feedback does not spend the new hint")
	model.resolve_feedback()
	for card in model.cards:
		if not pairs.any(func(pair: Array) -> bool: return pair.has(card.id)):
			model.select(card.id)
			check(model.request_hint() and not model.hint_ids.has(card.id),
				"A distractor hint finds a complete unmatched pair instead")
			check(model.selected_id == "" and model.phase == "waiting",
				"A distractor selection is cleared so following the hint cannot cause a mistake")
			break
	var hint: Array = model.hint_ids.duplicate()
	check(hint.size() == 2 and not hint.any(func(id: String) -> bool: return model.matched_ids.has(id)),
		"Hints never recommend already matched cards")
	model.select(hint[0])
	check(model.hint_ids.size() == 2, "The hint stays visible while choosing its first card")
	model.select(hint[0])
	check(model.hint_ids.is_empty(), "Cancelling selection clears its hint")
	check(not model.request_hint(), "Cancelling a hint's highlight does not refund the hint")
	check(not model.reset(words.slice(0, 4)) and not model.request_hint(),
		"A failed reset cannot refill the current round's hint")
	var remaining: Array = pairs.slice(1)
	model.select(remaining[0][0])
	model.select(remaining[1][1])
	check(model.streak == 0 and model.successes == 1 and model.mistakes == 1,
		"A mistake resets only the streak, never earned matches")
	model.resolve_feedback()
	for count in range(2):
		model.select(remaining[0][0])
		model.select(remaining[1][1])
		model.resolve_feedback()
	check(model.phase == "lost" and not model.request_hint(), "Hints cannot revive a lost round")
	model.reset(words, 6)
	check(model.request_hint(), "Starting a new round restores exactly one hint")


func _test_results(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	check(not model.has_method("set_practice") and not has_property(model, "practice_mode"),
		"There is no unlimited-attempt mode or method to bypass the loss threshold")
	model.reset(words, 27)
	for pair in pairs_for(model):
		model.select(pair[0])
		model.select(pair[1])
		model.resolve_feedback()
	check(model.phase == "won" and model.successes == 3, "Three successes win")
	check(model.select(model.cards[0].id) == "ignored", "Winning locks the board")
	check(model.set_theme("spring"), "A closed chest follows theme selection")
	check(has_property(model, "reward_id"), "The model stores the selected reward variant")
	if has_property(model, "reward_id"):
		check(not model.begin_open(""), "Opening requires a reward variant")
		check(model.begin_open("spring-1"), "The winning chest can open")
		check(model.reward_id == "spring-1", "Opening captures the selected reward variant")
	else:
		check(false, "The winning chest can open with a reward variant")
	check(model.chest_state == "opening" and model.reward_theme == "spring", "Opening captures its theme")
	check(not model.begin_open("spring-2") if has_property(model, "reward_id") else false, "Repeated opening is rejected")
	check(not model.set_theme("summer"), "Theme changes are locked during opening")
	check(model.finish_open(), "Opening completes once")
	check(not model.finish_open(), "Opening completion is one-shot")
	check(model.set_theme("winter"), "Theme can change after opening")
	check(model.reward_theme == "spring" and model.chest_state == "opened", "Earned reward is immutable")
	model.reset(words, 27)
	check(model.reward_theme == "" and model.chest_state == "closed" and (model.reward_id == "" if has_property(model, "reward_id") else false),
		"Replay clears earned reward")
	check(not model.finish_open(), "A stale opening cannot reward the new round")
	var wrong: Array = wrong_pair_for(model)
	for count in range(3):
		model.select(wrong[0])
		model.select(wrong[1])
		model.resolve_feedback()
	check(model.phase == "lost" and model.mistakes == 3, "Three mistakes lose")
	check(not model.begin_open(), "Losing cannot grant a chest")
	model.reset(words, 12)
	var pair: Array = pairs_for(model)[0]
	model.select(pair[0])
	model.select(pair[1])
	model.resolve_feedback()
	wrong = wrong_pair_for(model)
	# Use unmatched cards so the independent loss threshold is exercised.
	for card in model.cards:
		for other in model.cards:
			if not card.id in model.matched_ids and not other.id in model.matched_ids:
				if card.kind != other.kind and card.word.id != other.word.id:
					wrong = [card.id, other.id]
	for count in range(3):
		model.select(wrong[0])
		model.select(wrong[1])
		model.resolve_feedback()
	check(model.phase == "lost" and model.successes == 1, "Success does not erase earlier/later mistakes")


func _test_data(words: Array) -> void:
	check(words.size() == 140, "The game includes 140 short picture words")
	var path := "res://scripts/game_data.gd"
	check(FileAccess.file_exists(path), "The native data loader exists")
	if not FileAccess.file_exists(path):
		return
	var data_script: GDScript = load(path)
	check(data_script != null and data_script.can_instantiate(), "The data loader compiles")
	if data_script == null or not data_script.can_instantiate():
		return
	check(data_script.validate_words(words) == "", "The shared words.json is accepted")
	check(data_script.validate_words({}) != "", "Non-array vocabularies are rejected")
	check(data_script.validate_words(words.slice(0, 4)) != "", "Small vocabularies are rejected")
	var duplicate: Array = words.duplicate(true)
	duplicate[1].id = duplicate[0].id
	check(data_script.validate_words(duplicate) != "", "Duplicate word IDs are rejected")
	duplicate = words.duplicate(true)
	duplicate[1].text = duplicate[0].text
	check(data_script.validate_words(duplicate) != "", "Duplicate text is rejected")
	duplicate = words.duplicate(true)
	duplicate[1].image = duplicate[0].image
	check(data_script.validate_words(duplicate) != "", "Duplicate images are rejected")
	for bad_text in ["CAT", "a", "toolongword", "two words", "123"]:
		duplicate = words.duplicate(true)
		duplicate[0].text = bad_text
		check(data_script.validate_words(duplicate) != "", "Only short lowercase English words are accepted")
	for bad_path in ["https://example.invalid/cat.svg", "assets/images/words/../cat.svg", "C:\\cat.svg"]:
		duplicate = words.duplicate(true)
		duplicate[0].image = bad_path
		check(data_script.validate_words(duplicate) != "", "External/traversal image paths are rejected")
	for season in ["spring", "summer", "autumn", "winter", "ocean", "space"]:
		var theme: Dictionary = data_script.theme(season)
		check(theme.id == season and theme.prize != "", "Each season has a named reward")
		check(data_script.has_method("rewards") and data_script.has_method("reward"),
			"Seasonal reward lookup helpers exist")
		if data_script.has_method("rewards") and data_script.has_method("reward"):
			var rewards: Array = data_script.rewards(season)
			var reward_ids: Dictionary = {}
			for reward in rewards:
				reward_ids[reward.id] = true
				check(reward.theme == season and reward.symbol == "res://assets/images/rewards/" + reward.id + ".svg",
					"Every reward variant has its own SVG")
			var expected_count: int = 6 if season in ["ocean", "space"] else 10
			check(rewards.size() == expected_count and reward_ids.size() == expected_count, "Each theme has unique active and archived rewards")
	check(data_script.reward("missing").is_empty() if data_script.has_method("reward") else false,
		"Unknown reward variants are rejected")
	var expected_themes := {
		"spring": {
			"name": "Spring",
			"background": Color("#edf8ec"),
			"accent": Color("#438363"),
			"light": Color("#d7efc7"),
			"spark": Color("#75c66f"),
			"tint": Color("#dff6de")
		},
		"summer": {
			"name": "Summer",
			"background": Color("#ffe6e6"),
			"accent": Color("#b53640"),
			"light": Color("#ffc6cb"),
			"spark": Color("#ff8f9d"),
			"tint": Color("#ffe3e8")
		},
		"autumn": {
			"name": "Autumn",
			"background": Color("#fff8cf"),
			"accent": Color("#8f7400"),
			"light": Color("#ffe07a"),
			"spark": Color("#ffd24d"),
			"tint": Color("#fff0ad")
		},
		"winter": {
			"name": "Winter",
			"background": Color.WHITE,
			"accent": Color("#606a73"),
			"light": Color("#eef2f4"),
			"spark": Color("#d8dee3"),
			"tint": Color("#f5f7f8")
		},
		"ocean": {
			"name": "Ocean",
			"background": Color("#e4f6fb"),
			"accent": Color("#216d89"),
			"light": Color("#b8e6ed"),
			"spark": Color("#69cbd6"),
			"tint": Color("#d6f4f4")
		},
		"space": {
			"name": "Space",
			"background": Color("#eeeafa"),
			"accent": Color("#69569b"),
			"light": Color("#d7ccef"),
			"spark": Color("#bba3eb"),
			"tint": Color("#eee3ff")
		}
	}
	for season in expected_themes.keys():
		var theme: Dictionary = data_script.theme(season)
		var expected: Dictionary = expected_themes[season]
		for key in expected.keys():
			check(theme.get(key) == expected[key], "%s %s matches the seasonal palette" % [season, key])
	var source_json: String = FileAccess.get_file_as_string("res://words.json")
	var expected_words: Array = words.duplicate(true)
	for word in expected_words:
		var imported_image: String = "assets/imported-unity/" + word.id + ".png"
		if ResourceLoader.exists("res://" + imported_image):
			word.image = imported_image
	var data = data_script.new()
	check(data.load_all(), "Runtime JSON and imported chest manifest load: " + data.error)
	check(data.words == expected_words,
		"Godot preserves every vocabulary field and selects only each word's available image override")
	check(FileAccess.get_file_as_string("res://words.json") == source_json,
		"Runtime image overrides never rewrite the original words.json")
	if not data.chests.is_empty():
		check(data.chests.styles.crystal.parts.size() == 9, "Crystal has all nine assembled pieces")


func _test_controls() -> void:
	var styles: GDScript = load("res://scripts/ui_style.gd")
	var menu := MenuButton.new()
	styles.button(menu, Color("#438363"), 120)
	check(menu.focus_mode == Control.FOCUS_ALL, "The season menu is keyboard reachable")
	check(menu.get_theme_color("font_disabled_color") == styles.INK, "Disabled theme text remains readable")
	check(menu.get_theme_color("font_hover_pressed_color") == styles.INK,
		"Pressed and hovered text buttons retain contrast on their pale backgrounds")
	menu.free()
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var card = load("res://scripts/word_card.gd").new()
	card.setup({"id": "apple:image", "kind": "image", "word": words[5]})
	check(card.tooltip_text == "Picture: apple", "Picture descriptions do not assume a singular countable noun")
	check(not (card.match_mark is Label), "Matched cards use native badge artwork, not missing-font checkmark glyphs")
	check(not card.match_mark.visible, "Unmatched cards do not display a success badge")
	card.refresh(load("res://scripts/game_data.gd").theme("spring"), false, true, false, false)
	check(card.match_mark.visible, "A matched card displays the success badge")
	card.free()


func _test_effects() -> void:
	var effect_script: GDScript = load("res://scripts/celebration.gd")
	var data_script: GDScript = load("res://scripts/game_data.gd")
	var effect_view = effect_script.new()
	root.add_child(effect_view)
	var data = data_script.new()
	check(data.load_all(), "Celebration assets are valid")
	effect_view.configure(data.chests)
	check(effect_view._textures.is_empty(), "Celebration textures do not delay startup")
	effect_view.start(data_script.theme("spring"), true)
	check(effect_view._textures.is_empty(), "Reduced motion does not load unused particle textures")
	effect_view.start(data_script.theme("spring"), false)
	check(effect_view._textures.size() == data.chests.particles.size(), "The first celebration loads its textures")
	check(effect_view.particle_count() == 72, "Native celebration has 72 particles")
	for category in range(3):
		var quadrants: Dictionary = {}
		for particle in effect_view._particles:
			if particle.kind == category:
				quadrants[int(fposmod(particle.angle, TAU) / (PI * 0.5))] = true
		check(quadrants.size() == 4, "Every particle category spans the whole circle")
	effect_view._process(4.9)
	check(effect_view.particle_count() == 0, "Celebration clears itself after its lifetime")
	effect_view.start(data_script.theme("winter"), true)
	check(effect_view.particle_count() == 0, "Reduced motion creates no particles")
	check(effect_view.has_method("_particle_position"), "Seasons have distinct motion profiles")
	if effect_view.has_method("_particle_position"):
		var positions: Array[Vector2] = []
		var sample := {"kind": 0, "angle": 0.6, "distance": 0.8}
		for season in ["spring", "summer", "autumn", "winter", "ocean", "space"]:
			effect_view.start(data_script.theme(season), false)
			var position: Vector2 = effect_view._particle_position(sample, 1.0, Vector2.ZERO, 200.0)
			check(not positions.has(position), "Each season has a different particle trajectory")
			positions.append(position)
	effect_view.free()


func _test_audio() -> void:
	var audio_script: GDScript = load("res://scripts/game_audio.gd")
	check(audio_script != null and audio_script.can_instantiate(), "The native audio controller compiles")
	if audio_script == null or not audio_script.can_instantiate():
		return
	var controller = audio_script.new()
	root.add_child(controller)
	await process_frame
	var notices: Array[String] = []
	controller.status_changed.connect(func(message: String) -> void: notices.append(message))
	check(not controller.active and not controller.music.playing, "Audio waits for interaction")
	for season in ["spring", "summer", "autumn", "winter", "ocean", "space"]:
		var track: AudioStreamWAV = load("res://assets/audio/bgm/" + season + ".wav")
		check(track.mix_rate == 22050, "Mobile background music uses 22.05 kHz: " + season)
		check(not track.stereo, "Mobile background music uses mono: " + season)
	var original: AudioStreamWAV = load("res://assets/audio/bgm/spring.wav")
	var original_loop: int = original.loop_mode
	controller.interact("spring")
	check(controller.music.playing, "A gesture starts native background music")
	check(controller.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Background music loops")
	check(controller.music.stream != original and original.loop_mode == original_loop, "Loop setup does not mutate the shared WAV")
	controller.cue("select", "welcome")
	check(controller.effect.playing and controller.voice.playing, "Effects and voice use independent native channels")
	check(is_equal_approx(db_to_linear(controller.music.volume_db), 0.04), "Speech ducks background music")
	check(is_equal_approx(db_to_linear(controller.effect.volume_db), 0.24), "Effects have a bounded gain")
	check(is_equal_approx(db_to_linear(controller.voice.volume_db), 0.64), "Speech has a bounded gain")
	controller.say("res://assets/audio/voice/missing-test.wav")
	check(not controller.voice.playing, "An unavailable new voice does not leave the old word speaking")
	check(not notices[-1].is_empty(), "Unavailable speech has an explicit notice")
	controller.interact("missing-test")
	check(not controller.music.playing, "An unavailable new theme does not leave the old music playing")
	controller.interact("summer")
	check(controller.music.playing, "Audio can retry after a missing resource")
	check(notices[-1].is_empty(), "A successful retry clears the earlier audio error")
	controller.set_muted(true)
	check(not controller.active and not controller.music.playing and not controller.effect.playing and not controller.voice.playing,
		"Muting stops all channels")
	controller.interact("winter")
	check(not controller.active, "Interaction does not bypass mute")
	controller.set_muted(false)
	controller.interact("winter")
	check(controller.music.playing and controller.current_theme == "winter", "Unmuted audio can resume after a gesture")
	controller.halt()
	check(not controller.active and not controller.music.playing, "Hiding/resetting suspends audio")
	controller.queue_free()
	await process_frame


func _test_reward_preview_play(app) -> void:
	check(has_property(app, "_preview_tap_count"), "Reward previews track cosmetic taps toward a high-five party")
	if not has_property(app, "_preview_tap_count"):
		return
	var saved_rewards: Dictionary = app.collected_rewards.duplicate()
	var seasons := ["spring", "summer", "autumn", "winter", "ocean", "space"]
	var shape_names := ["HEART", "STAR", "LEAF", "SNOWFLAKE", "CIRCLE", "STAR"]
	var preview_rewards: Dictionary = saved_rewards.duplicate()
	for season in seasons:
		preview_rewards[season + "-1"] = true
	set_completed_rewards(app, preview_rewards)
	app._show_collection()
	var earned_rewards: Dictionary = app.collected_rewards.duplicate()
	for index in range(seasons.size()):
		var season: String = seasons[index]
		app._open_reward_preview(season + "-1")
		await process_frame
		await process_frame
		check(app._preview_tap_count == 0, "Opening a preview starts a fresh play count: " + season)
		check(app._preview_sparkle.shape_kind == app._preview_sparkle.Shape[shape_names[index]],
			"Preview shapes follow the earned season: " + season)
		var node_count: int = app._preview_page.find_children("*", "", true, false).size()
		var poses: Array[Vector2] = []
		for tap in range(1, 7):
			var previous: Tween = app._preview_tween
			app._preview_play_button.pressed.emit()
			check(app._preview_tap_count == tap, "Each deliberate preview tap counts once: " + season)
			check(previous == null or not previous.is_valid(), "New play replaces the previous animation: " + season)
			var party: bool = tap == 5
			check(app._preview_sparkle.particle_count == (12 if party else 8),
				"Seasonal play has eight shapes and the fifth tap has twelve: " + season)
			check(app._preview_caption.text.contains("High five!") if party else app._preview_caption.text.ends_with("Tap %d" % tap),
				"Visible reward feedback explains the tap or party: " + season)
			check(app._status_announcement.contains(app._preview_caption.text),
				"Preview play exposes the same feedback to assistive technology: " + season)
			check(app._preview_page.find_children("*", "", true, false).size() == node_count,
				"Rapid seasonal play does not accumulate particle nodes: " + season)
			if preview_tween_valid(app):
				app._preview_tween.pause()
				app._preview_tween.custom_step(0.20)
				if tap <= 3:
					poses.append(app._preview_image.scale)
		check(poses.size() == 3 and poses[0] != poses[1] and poses[1] != poses[2] and poses[0] != poses[2],
			"The first three taps have distinct bounce, twirl, and hug poses: " + season)
		app._layout()
		check(not preview_tween_valid(app) and app._preview_image.scale == Vector2.ONE and not preview_sparkle_visible(app),
			"Resizing cancels an active preview effect: " + season)
		check(app._preview_tap_count == 6, "Cancelling an effect does not reset play progress: " + season)
		app.set_reduced_motion(true)
		for tap in range(7, 11):
			app._preview_play_button.pressed.emit()
		check(app._preview_tap_count == 10 and app._preview_caption.text.contains("High five!"),
			"Reduced-motion players still get the fifth-tap party message: " + season)
		check(not preview_tween_valid(app) and app._preview_image.scale == Vector2.ONE and not preview_sparkle_visible(app),
			"Reduced-motion parties do not move or emit shapes: " + season)
		check(app.collected_rewards == earned_rewards, "Preview play never grants or changes rewards: " + season)
		app.set_reduced_motion(false)
		app._hide_reward_preview()
	if app.audio.available:
		app._open_reward_preview("spring-1")
		app.audio.set_muted(false)
		app.audio.halt()
		app._preview_play_button.pressed.emit()
		check(app.audio.active and app.audio.effect.playing,
			"A first direct preview interaction unlocks bundled sound")
		app.audio.set_muted(true)
		app._preview_play_button.pressed.emit()
		check(not app.audio.active and not app.audio.effect.playing, "Preview play respects muted sound")
		app.on_page_hidden()
		check(not preview_visible(app) and not preview_tween_valid(app), "Hiding the page cancels preview play")
	set_completed_rewards(app, saved_rewards)
	app._hide_collection()


func _test_play_improvements(app) -> void:
	check(has_property(app, "hint_button") and has_property(app, "_match_caption"),
		"The board has a reachable hint and visible match encouragement")
	if has_property(app, "hint_button") and app.model.has_method("request_hint"):
		app.new_round(6)
		app.hint_button.grab_focus()
		app.hint_button.pressed.emit()
		var hinted: Array = app.model.hint_ids.duplicate()
		check(hinted.size() == 2 and app._status_announcement.begins_with("Hint:"),
			"The native Hint button announces a real pair")
		check(not app._controller_mode and app.cards[hinted[0]].has_focus(),
			"A keyboard hint focuses its first playable card without requiring a controller")
		check(app.hint_button.disabled and app.hint_button.text == "Used",
			"A spent hint is disabled and clearly labeled")
		check(app.hint_button.focus_mode == Control.FOCUS_NONE,
			"Keyboard navigation skips an already used hint")
		app.cards[hinted[0]].pressed.emit()
		app.hint_button.pressed.emit()
		check(app.cards[hinted[0]].has_focus() and app.model.selected_id == hinted[0],
			"Repeated hint signals cannot move focus or cancel the selected card")
		for id in hinted:
			check(app.cards[id].match_mark.visible and app.cards[id].match_mark.hinted,
				"Hinted cards have a star marker, not just a different color")
		check(app._match_caption.text == "Follow stars" and app._match_caption.is_visible_in_tree(),
			"The hint is visible on the board without moving its cards")
		app._show_collection()
		var previous_hint: Array = hinted.duplicate()
		joy_tap(JOY_BUTTON_X)
		await process_frame
		check(app.model.hint_ids == previous_hint and app._status_announcement.begins_with("My rewards"),
			"Xbox X cannot trigger hints behind a modal")
		app._hide_collection()
		app.on_page_hidden()
		app.choose_theme("winter")
		check(app.hint_button.disabled and not app.model.request_hint(),
			"Collection, page hiding and season changes do not refill the hint")
		app.cards[hinted[0]].pressed.emit()
		for pair in pairs_for(app.model).slice(0, 2):
			app.cards[pair[0]].pressed.emit()
			app.cards[pair[1]].pressed.emit()
			check(app.hint_button.disabled, "Hints are disabled during match feedback")
			var sparkle: Control = app.cards[pair[0]].get_node_or_null("MatchSparkle")
			check(sparkle != null and sparkle.particle_count <= 6,
				"Each correct card gets a small, bounded star celebration")
			app.feedback_timer.timeout.emit()
		check(app._match_caption.text == "2 in a row!", "Consecutive matches get visible encouragement")
		joy_tap(JOY_BUTTON_X)
		await process_frame
		check(app.model.hint_ids.is_empty() and app.hint_button.disabled,
			"Xbox X shares the hint already spent through the button")
		app.set_reduced_motion(true)
		var last_pair: Array = pairs_for(app.model)[2]
		app.cards[last_pair[0]].pressed.emit()
		app.cards[last_pair[1]].pressed.emit()
		check(app.cards[last_pair[0]].get_node_or_null("MatchSparkle") == null,
			"Reduced motion keeps the match encouragement without particles")
		check(app._match_caption.text == "3 in a row!", "Reduced-motion players still see the streak")
		app.feedback_timer.timeout.emit()
		check(not app.hint_button.visible, "Finished rounds hide the hint action")
		app.set_reduced_motion(false)
		app.new_round(6)
		check(not app.hint_button.disabled and app.hint_button.text == "Hint",
			"A new round restores the hint control")
		var first: Array = pairs_for(app.model)[0]
		app.cards[first[0]].pressed.emit()
		app.hint_button.pressed.emit()
		check(app.cards[first[1]].has_focus() and app.model.selected_id == first[0],
			"The round's first hint focuses the partner of an already selected card")
		app.cards[first[1]].pressed.emit()
		app.on_page_hidden()
		check(app._feedback_tweens.is_empty() and app.cards[first[0]].scale == Vector2.ONE,
			"Hiding the page stops transient match effects without losing progress")
		app.feedback_timer.timeout.emit()
		check(app.model.successes == 1, "Cancelling cosmetic feedback preserves the earned match")
	var saved_rewards: Dictionary = app.collected_rewards.duplicate()
	var data_script: GDScript = load("res://scripts/game_data.gd")
	for season in ["spring", "summer", "autumn", "winter", "ocean", "space"]:
		app.new_round(6)
		var rewards: Array = data_script.medals(season)
		var completed: Dictionary = {}
		for reward in rewards.slice(0, 5):
			completed[reward.id] = true
		set_completed_rewards(app, completed)
		win_round(app)
		app.choose_theme(season)
		app._open_chest()
		check(app.model.reward_id == rewards[5].id,
			"A chest chooses the last unfinished medal before any duplicate: " + season)
		var locked_reward: String = app.model.reward_id
		app._open_chest()
		check(app.model.reward_id == locked_reward, "Repeated opening cannot reroll the reward")
		app.new_round(6)
		app.medal_progress.counts[rewards[5].id] = 3
		win_round(app)
		app.choose_theme(season)
		app._open_chest()
		check(not data_script.reward(app.model.reward_id).is_empty() and app.model.reward_theme == season,
			"Completing a seasonal collection does not prevent future chest opening")
	app.new_round(6)
	set_completed_rewards(app, saved_rewards)


func _test_season_goals(app) -> void:
	var saved_rewards: Dictionary = app.collected_rewards.duplicate()
	var data_script: GDScript = load("res://scripts/game_data.gd")
	set_completed_rewards(app, {})
	check(app._collection_headings.spring.text == "Spring 0/6", "Empty collections show their seasonal goal")
	var completed: Dictionary = {}
	for reward in data_script.medals("spring").slice(0, 3):
		completed[reward.id] = true
	set_completed_rewards(app, completed)
	check(app._collection_headings.spring.text == "Spring 3/6"
		and app._collection_headings.summer.text == "Summer 0/6",
		"Collection goals count earned variants separately by season")
	for reward in data_script.medals("spring"):
		completed[reward.id] = true
	set_completed_rewards(app, completed)
	check(app._collection_headings.spring.text == "Spring complete! 6/6",
		"A completed season has a distinct, derived completion message")
	app.new_round(6)
	var seeded_theme: String = app.model.theme_id
	app.choose_theme("summer")
	app._replay()
	check(app.model.theme_id == "summer", "Replay retains a manually chosen season")
	app.new_round(6)
	check(app.model.theme_id == seeded_theme, "An explicit seed is not overridden by season preference")
	set_completed_rewards(app, saved_rewards)


func _test_scene() -> void:
	var path := "res://scenes/main.tscn"
	check(FileAccess.file_exists(path), "The native main scene exists")
	if not FileAccess.file_exists(path):
		return
	var packed: PackedScene = load(path)
	check(packed != null, "The main scene loads")
	if packed == null:
		return
	var directory := "user://game-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Scene reward saves use an isolated directory")
	var progress_script = load("res://scripts/medal_progress.gd")
	var app = packed.instantiate()
	app.medal_progress = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	app._mode_id = "match"
	root.add_child(app)
	await process_frame
	await process_frame
	check(app.data.error == "", "The scene loads its data: " + app.data.error)
	if app.data.error != "":
		app.queue_free()
		await process_frame
		return
	app.audio.set_muted(true)
	await _test_play_improvements(app)
	_test_season_goals(app)
	check(app.find_child("Practice", true, false) == null and app._mistakes.get_parent() is HBoxContainer,
		"Mistake badges are passive counters, not an unlimited-attempt toggle")
	check(app._voice_button.disabled and app._voice_button.focus_mode == Control.FOCUS_NONE,
		"Keyboard navigation skips Voice when recognition is unavailable")
	check(app.cards.size() == 8, "The scene creates eight native card buttons")
	check(app.find_child("Mute", true, false) == null and app.find_child("Listen", true, false) == null,
		"Mute and Listen controls are removed")
	check(app.find_child("Motion", true, false) == null,
		"The FX motion button is removed while OS/browser reduced-motion remains supported")
	check(has_property(app, "theme_buttons") and app.theme_buttons.size() == 6,
		"All six themes are directly available")
	if has_property(app, "theme_buttons"):
		check(app.theme_buttons.all(func(button: Button) -> bool: return button.tooltip_text.is_empty()),
			"Season buttons do not show redundant hover/tap tooltip popups")
	check(has_property(app, "collection_button") and app.collection_button != null,
		"The rewards collection is directly available")
	check(has_property(app, "collection_page") and app.collection_page != null,
		"The rewards collection has an in-game page")
	var collection_scroll := collection_scroll(app)
	check(collection_scroll != null, "The rewards collection scrolls in a native ScrollContainer")
	if collection_scroll != null:
		check(collection_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
			and collection_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
			"Rewards scrollbars are hidden without disabling touch or wheel scrolling")
	check(app._reward_slots.size() == 36, "The rewards page contains six medals in each of six themes")
	check(app.find_children("*", "ProgressBar", true, false).is_empty(),
		"Chest charging uses shake feedback without a progress bar")
	for id in app._reward_slots:
		var slot: Dictionary = app._reward_slots[id]
		if app.collected_rewards.has(id):
			check(slot.picture.texture == null, "Hidden earned medals do not eagerly load their artwork")
		else:
			check(slot.picture.texture == null, "Locked rewards do not reveal or eagerly load their artwork")
	if app.has_method("_show_collection"):
		app.collection_button.grab_focus()
		app._show_collection()
		check(app._collection_back.has_focus() if has_property(app, "_collection_back") else false,
			"Opening rewards moves keyboard focus to Back")
		check(has_property(app, "_status_announcement") and app._status_announcement.begins_with("My rewards opened"),
			"Opening rewards announces the collection modal state")
		check(app.collection_button.focus_mode == Control.FOCUS_NONE,
			"Opening rewards removes underlying controls from keyboard focus")
		if app.has_method("_hide_collection"):
			app._hide_collection()
		else:
			app.collection_page.hide()
		check(app.collection_button.focus_mode == Control.FOCUS_ALL,
			"Closing rewards restores underlying keyboard focus")
	set_completed_rewards(app, {"spring-1": true})
	var inventory_before_label_check: Dictionary = app.collected_rewards.duplicate()
	app._show_collection()
	app._show_reward_section("medals")
	for id in app._reward_slots:
		var slot: Dictionary = app._reward_slots[id]
		if app.collected_rewards.has(id):
			check(slot.picture.texture != null and slot.picture.texture.resource_path == slot.reward.symbol,
				"Visible unlocked rewards load their individual artwork")
		else:
			check(slot.picture.texture == null, "Visible locked medals keep their artwork hidden")
	var all_rewards: Dictionary = {}
	for id in app._reward_slots:
		all_rewards[id] = true
	set_completed_rewards(app, all_rewards)
	await process_frame
	await process_frame
	for id in app._reward_slots:
		var slot: Dictionary = app._reward_slots[id]
		check(Rect2(Vector2.ZERO, slot.button.size).encloses(slot.label.get_rect()),
			"Reward name and number fit inside the tile: %s label=%s tile=%s" % [id, slot.label.get_rect(), slot.button.size])
		check(slot.label.get_line_count() <= 2, "Reward captions use at most two lines: " + id)
	set_completed_rewards(app, inventory_before_label_check)
	app._hide_collection()
	var unlocked_slot := reward_slot_button(app, "spring-1")
	var locked_slot := reward_slot_button(app, "spring-2")
	check(unlocked_slot != null and not unlocked_slot.disabled and unlocked_slot.focus_mode == Control.FOCUS_ALL,
		"Earned rewards are deliberate touch and focus targets")
	check(locked_slot != null and locked_slot.disabled and locked_slot.focus_mode == Control.FOCUS_NONE,
		"Locked rewards cannot be focused or activated")
	if locked_slot != null:
		locked_slot.pressed.emit()
	check(not preview_visible(app), "Locked rewards do not open the reward preview")
	if unlocked_slot != null:
		unlocked_slot.grab_focus()
		unlocked_slot.pressed.emit()
	check(preview_visible(app), "Activating an earned reward opens a large native preview")
	if preview_visible(app):
		check(app._preview_image.texture == load("res://assets/images/rewards/spring-1.svg"),
			"The preview shows the earned reward artwork")
		check(app._preview_title.text == "Blossom #1",
			"The preview names the earned reward without exposing locked items")
		check(has_property(app, "_status_announcement") and app._status_announcement == "Blossom #1 reward preview opened. Press the reward to play, or Back to close.",
			"Opening a reward preview announces its modal state")
		check(app._preview_play_button.has_focus(), "Opening the preview focuses its primary play action")
		var saved_rewards: Dictionary = app.collected_rewards.duplicate()
		app._preview_play_button.pressed.emit()
		check(app.collected_rewards == saved_rewards, "Playing with a reward preview does not mutate inventory")
		check(has_property(app, "_status_announcement") and app._status_announcement == "Blossom #1. Boing! Tap 1",
			"Playing with a reward preview announces the playful interaction")
		check(preview_tween_valid(app), "Preview play starts one bounded native flourish")
		app._preview_play_button.pressed.emit()
		var current_preview_tween = app._preview_tween if has_property(app, "_preview_tween") else null
		check(current_preview_tween != null and current_preview_tween.is_valid(), "Rapid preview taps replace earlier flourish cleanly")
		if current_preview_tween != null:
			current_preview_tween.pause()
			current_preview_tween.custom_step(1.0)
		check(app._preview_image.scale == Vector2.ONE and not preview_sparkle_visible(app),
			"Preview flourish settles with no lingering scale or sparkle")
		if app.has_method("_hide_reward_preview"):
			app._hide_reward_preview()
		check(not preview_visible(app) and unlocked_slot.has_focus(),
			"Closing the preview restores focus to the reward slot")
	app.set_reduced_motion(true)
	if unlocked_slot != null:
		unlocked_slot.pressed.emit()
	if preview_visible(app):
		app._preview_play_button.pressed.emit()
	check((not has_property(app, "_preview_tween") or app._preview_tween == null) and (not has_property(app, "_preview_image") or app._preview_image.scale == Vector2.ONE),
		"Reduced motion keeps preview play static")
	if app.has_method("_hide_reward_preview"):
		app._hide_reward_preview()
	app.set_reduced_motion(false)
	await _test_reward_preview_play(app)
	if collection_scroll != null and unlocked_slot != null:
		app._show_collection()
		root.size = Vector2i(320, 320)
		await process_frame
		await process_frame
		collection_scroll.scroll_vertical = 80
		var start_scroll: int = collection_scroll.scroll_vertical
		var point := unlocked_slot.get_global_rect().get_center()
		emit_scroll_press(unlocked_slot, point, true)
		emit_scroll_motion(unlocked_slot, point + Vector2(0, -43), Vector2(0, -43))
		emit_scroll_motion(collection_scroll, point + Vector2(0, -43), Vector2(0, -43))
		emit_scroll_press(unlocked_slot, point + Vector2(0, -43), false)
		check(abs(collection_scroll.scroll_vertical - (start_scroll + 43)) <= 1,
			"Collection touch drag scrolls exactly one logical pixel per finger pixel")
		unlocked_slot.pressed.emit()
		check(not preview_visible(app), "A vertical collection swipe never opens a reward on release")
		collection_scroll.scroll_vertical = 15
		emit_scroll_press(collection_scroll, point, true)
		emit_scroll_motion(collection_scroll, point + Vector2(0, 1000), Vector2(0, 1000))
		emit_scroll_press(collection_scroll, point + Vector2(0, 1000), false)
		check(collection_scroll.scroll_vertical == 0, "Collection drag clamps at the top")
		collection_scroll.scroll_vertical = 0
		emit_scroll_press(collection_scroll, point, true)
		emit_scroll_motion(collection_scroll, point + Vector2(0, -10000), Vector2(0, -10000))
		emit_scroll_press(collection_scroll, point + Vector2(0, -10000), false)
		var max_scroll: int = max(0, int(app._collection_grid.size.y - collection_scroll.size.y))
		check(abs(collection_scroll.scroll_vertical - max_scroll) <= 1, "Collection drag clamps at the bottom")
		var before_wheel: int = collection_scroll.scroll_vertical
		emit_scroll_wheel(collection_scroll, point, MOUSE_BUTTON_WHEEL_UP)
		check(collection_scroll.scroll_vertical < before_wheel, "Mouse wheel scrolling still works with hidden bars")
		check(app.has_method("_advance_collection_inertia"), "The collection supports release momentum")
		if app.has_method("_advance_collection_inertia"):
			collection_scroll.scroll_vertical = 80
			app._start_collection_drag(Vector2(100, 250), 0)
			app._collection_last_sample_usec = Time.get_ticks_usec() - 50000
			app._update_collection_drag(Vector2(100, 210))
			var drag_velocity: Vector2 = app._collection_velocity
			app._update_collection_drag(Vector2(100, 210))
			check(app._collection_velocity == drag_velocity,
				"Duplicated touch and emulated mouse positions do not amplify momentum")
			app._end_collection_drag()
			var released_scroll: int = collection_scroll.scroll_vertical
			app._advance_collection_inertia(0.1)
			check(collection_scroll.scroll_vertical > released_scroll,
				"Releasing a moving finger continues scrolling in the same direction")
			check(app._collection_velocity.length() < drag_velocity.length(),
				"Collection momentum loses speed smoothly")
			app._start_collection_drag(Vector2(100, 210), 0)
			app._start_collection_drag(Vector2(100, 210), -2)
			check(app._collection_velocity == Vector2.ZERO and app._collection_dragged,
				"A new touch stops momentum and remains a stop gesture after mouse emulation")
			app._end_collection_drag()
			unlocked_slot.pressed.emit()
			check(not preview_visible(app), "Tapping to stop momentum does not open a moving reward")
			collection_scroll.scroll_vertical = max_scroll - 5
			app._start_collection_drag(Vector2(100, 210), 0)
			app._collection_last_sample_usec = Time.get_ticks_usec() - 50000
			app._update_collection_drag(Vector2(100, 170))
			app._end_collection_drag()
			app._advance_collection_inertia(0.5)
			check(collection_scroll.scroll_vertical == max_scroll and app._collection_velocity == Vector2.ZERO,
				"Momentum stops at the collection boundary without overshoot")
			collection_scroll.scroll_vertical = 80
			app._start_collection_drag(Vector2(100, 250), 0)
			app._collection_last_sample_usec = Time.get_ticks_usec() - 50000
			app._update_collection_drag(Vector2(100, 210))
			app._end_collection_drag()
			app.set_reduced_motion(true)
			var reduced_scroll: int = collection_scroll.scroll_vertical
			app._advance_collection_inertia(0.5)
			check(collection_scroll.scroll_vertical == reduced_scroll and app._collection_velocity == Vector2.ZERO,
				"Reduced motion cancels automatic gliding without disabling finger scrolling")
			app.set_reduced_motion(false)
			check(app.collection_button.focus_mode == Control.FOCUS_NONE
				and app.theme_buttons.all(func(button: Button) -> bool: return button.focus_mode == Control.FOCUS_NONE),
				"Restyling after a motion change preserves the collection's keyboard focus boundary")
			collection_scroll.scroll_vertical = max_scroll
			await process_frame
			await process_frame
			app._collection_back.grab_focus()
			# Navigate through the room's objects and selectors to the first earned medal.
			for step in range(20):
				if unlocked_slot.has_focus():
					break
				app._move_focus(Vector2.DOWN)
				await process_frame
				await process_frame
			check(unlocked_slot.has_focus(),
				"Controller navigation reaches scrolled-off rewards: focus=%s candidates=%s" % [
					root.gui_get_focus_owner().name,
					app._focus_candidates().map(func(control: Control) -> String:
						return "%s:%s" % [control.name, app._focus_center(control)])])
			check(collection_scroll.get_global_rect().encloses(unlocked_slot.get_global_rect()),
				"Switching from scrolled touch input brings the focused reward back into view: %s within %s" % [unlocked_slot.get_global_rect(), collection_scroll.get_global_rect()])
			app._start_collection_drag(Vector2(100, 250), 0)
			app._collection_last_sample_usec = Time.get_ticks_usec() - 50000
			app._update_collection_drag(Vector2(100, 210))
			app._end_collection_drag()
			app.on_page_hidden()
			check(app._collection_velocity == Vector2.ZERO, "Hiding the page cancels collection momentum")
		app._hide_collection()
	check(app._stage.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW, "Chest effects respect the rounded panel mask")
	check(is_equal_approx(app.feedback_timer.wait_time, 0.7), "Voice feedback advances after 700ms")
	check(not (app._success is Label) and not (app._mistakes is Label),
		"Progress is drawn with friendly native badges instead of text characters")
	check(app._success.has_method("set_filled_count") and app._mistakes.has_method("set_filled_count"),
		"Progress indicators expose filled token counts")
	var dimensions: Array[Vector2i] = [
		Vector2i(320, 320), Vector2i(375, 667), Vector2i(390, 844),
		Vector2i(430, 932), Vector2i(844, 390), Vector2i(768, 1024),
		Vector2i(834, 1194), Vector2i(1194, 834), Vector2i(1024, 1366),
		Vector2i(507, 1024)
	]
	app.new_round(71)
	var round_cards: Array = app.model.cards.duplicate(true)
	for dimensions_value in dimensions:
		root.size = dimensions_value
		await process_frame
		await process_frame
		var viewport: Rect2 = root.get_visible_rect()
		var pixels_per_unit: Vector2 = Vector2(dimensions_value) / viewport.size
		check(app.model.cards == round_cards, "Resizing does not create a new round")
		check(app.grid.columns in [2, 4] and (dimensions_value.x < dimensions_value.y or app.grid.columns == 4),
			"Grid adapts to the visible instructions and available playfield: " + str(dimensions_value))
		var controls: Array = app.cards.values()
		if has_property(app, "theme_buttons"):
			controls.append_array(app.theme_buttons)
		if has_property(app, "collection_button"):
			controls.append(app.collection_button)
		if has_property(app, "hint_button"):
			controls.append(app.hint_button)
		for control in controls:
			var bounds: Rect2 = control.get_global_rect()
			check(viewport.grow(0.5).encloses(bounds), "Control fits " + str(dimensions_value) + ": " + control.name)
			var pixel_size: Vector2 = bounds.size * pixels_per_unit
			check(pixel_size.x >= 47.9 and pixel_size.y >= 47.9,
				"Touch target is at least 48px: " + control.name + " " + str(pixel_size))
	var controller_first: String = app.model.cards[0].id
	app.cards[controller_first].grab_focus()
	joy_tap(JOY_BUTTON_A)
	await process_frame
	check(app.model.selected_id == controller_first, "Controller A activates the focused card")
	joy_tap(JOY_BUTTON_B)
	await process_frame
	check(app.model.phase == "waiting" and app.model.selected_id == "", "Controller B cancels the current card selection")
	var cards_before_controller: Array = app.model.cards.duplicate(true)
	var focus_before_axis: Control = root.gui_get_focus_owner()
	joy_axis(JOY_AXIS_LEFT_X, 0.25)
	app._process(0.5)
	await process_frame
	check(root.gui_get_focus_owner() == focus_before_axis, "Left stick deadzone does not move focus")
	joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await process_frame
	var focus_after_axis: Control = root.gui_get_focus_owner()
	check(focus_after_axis != null and focus_after_axis != focus_before_axis, "Left stick moves focus once past the deadzone")
	app._process(0.05)
	await process_frame
	check(root.gui_get_focus_owner() == focus_after_axis, "Left stick repeat waits instead of jumping every frame")
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	await process_frame
	app.cards[controller_first].grab_focus()
	joy_button(JOY_BUTTON_DPAD_DOWN, true)
	await process_frame
	var dpad_first_focus: Control = root.gui_get_focus_owner()
	app._process(0.4)
	check(root.gui_get_focus_owner() != dpad_first_focus,
		"Holding the D-pad repeats navigation after the initial delay")
	joy_button(JOY_BUTTON_DPAD_DOWN, false)
	await process_frame
	var dpad_released_focus: Control = root.gui_get_focus_owner()
	app._process(0.5)
	check(root.gui_get_focus_owner() == dpad_released_focus,
		"Releasing the D-pad stops repeated navigation")
	var theme_before_controller: String = app.model.theme_id
	joy_tap(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	check(app.model.theme_id != theme_before_controller and app.model.cards == cards_before_controller,
		"Controller RB cycles season without restarting the round")
	joy_tap(JOY_BUTTON_LEFT_SHOULDER)
	await process_frame
	check(app.model.theme_id == theme_before_controller and app.model.cards == cards_before_controller,
		"Controller LB cycles season back without restarting the round")
	joy_tap(JOY_BUTTON_Y)
	await process_frame
	check(app.collection_page.visible and app._collection_back.has_focus(),
		"Controller Y opens My Rewards without restarting the round")
	app.set_reduced_motion(true)
	check(app._status_announcement.begins_with("My rewards opened"),
		"Changing motion preference preserves the collection announcement")
	app.set_reduced_motion(false)
	joy_tap(JOY_BUTTON_B)
	await process_frame
	check(not app.collection_page.visible and app.model.cards == cards_before_controller,
		"Controller B closes My Rewards and preserves the active round")
	app._show_collection()
	if unlocked_slot != null:
		unlocked_slot.grab_focus()
		joy_tap(JOY_BUTTON_A)
		await process_frame
		check(preview_visible(app), "Controller A opens an earned reward preview")
		check(app._preview_play_button.has_focus(), "The reward preview focuses its primary play action")
		joy_tap(JOY_BUTTON_A)
		await process_frame
		check(preview_tween_valid(app),
			"Controller A plays with the focused preview")
		app.set_reduced_motion(true)
		check(app._status_announcement.ends_with("Boing! Tap 1"),
			"Changing motion preference preserves the visible reward announcement")
		check(app.collection_button.focus_mode == Control.FOCUS_NONE and unlocked_slot.focus_mode == Control.FOCUS_NONE,
			"Restyling the open preview does not refocus controls behind either modal")
		app.set_reduced_motion(false)
		app._preview_close.grab_focus()
		joy_tap(JOY_BUTTON_A)
		await process_frame
		check(not preview_visible(app) and unlocked_slot.has_focus(),
			"Controller A activates Back when Back is focused in the preview")
		check(app._status_announcement.begins_with("My rewards opened"),
			"Closing a preview announces the restored collection")
		joy_tap(JOY_BUTTON_A)
		await process_frame
		joy_tap(JOY_BUTTON_B)
		await process_frame
		check(not preview_visible(app) and unlocked_slot.has_focus(),
			"Controller B closes the preview and restores reward focus")
	app._hide_collection()
	var first_pair: Array = pairs_for(app.model)[0]
	app.cards[first_pair[1]].grab_focus()
	app.cards[first_pair[0]].pressed.emit()
	app.cards[first_pair[1]].pressed.emit()
	check(app.cards[first_pair[0]].scale != Vector2.ONE and app.cards[first_pair[1]].scale != Vector2.ONE,
		"Matching cards immediately start a lively bounce")
	if app._success.has_method("set_filled_count"):
		check(app._success.filled_count == 1 and app._success.total_count == 3,
			"A match fills exactly one friendly success badge")
	else:
		check(false, "A match fills exactly one friendly success badge")
	app.set_reduced_motion(true)
	check(app.cards[first_pair[0]].scale == Vector2.ONE and app.cards[first_pair[1]].scale == Vector2.ONE,
		"Enabling reduced motion immediately stops active card animation")
	joy_button(JOY_BUTTON_A, false)
	await process_frame
	app.set_reduced_motion(false)
	app.feedback_timer.timeout.emit()
	check(app.cards.values().has(root.gui_get_focus_owner()) and not root.gui_get_focus_owner().disabled,
		"Finishing a match restores controller focus to an available card")
	for pair in pairs_for(app.model).slice(1):
		app.cards[pair[0]].pressed.emit()
		app.cards[pair[1]].pressed.emit()
		check(app.feedback_timer.is_stopped() and app._match_feedback.visible, "Button interaction waits for visible feedback confirmation")
		app.feedback_timer.timeout.emit()
	check(app.model.phase == "won", "The native button/timer wiring can win a round")
	await process_frame
	await process_frame
	check(app.chest_button.has_focus(), "Controller focus moves to the chest after winning")
	for season in ["spring", "summer", "autumn", "winter", "ocean", "space"]:
		app.choose_theme(season)
		await process_frame
		check(app.chest.theme_id == season, "Closed chest follows selected season")
		check(app.chest.piece_count() == (9 if season in ["winter", "ocean"] else 2), "Chest uses real imported artwork")
	app.choose_theme("spring")
	joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await process_frame
	Input.joy_connection_changed.emit(0, false)
	check(app._controller_last_direction == Vector2.ZERO and app._controller_stick == Vector2.ZERO,
		"Disconnecting a controller stops held-stick navigation")
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	await process_frame
	app.chest_button.grab_focus()
	joy_button(JOY_BUTTON_A, true)
	await process_frame
	check(app._holding_chest and app._controller_holding_chest,
		"The disconnected controller was actually charging the chest")
	app._process(0.4)
	Input.joy_connection_changed.emit(0, false)
	check(not app._holding_chest and not app._controller_holding_chest,
		"Disconnecting the controller cancels its incomplete chest charge")
	joy_button(JOY_BUTTON_A, false)
	joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await process_frame
	app.on_page_hidden()
	check(app._controller_last_direction == Vector2.ZERO and app._controller_stick == Vector2.ZERO,
		"Hiding the page stops controller navigation until another input")
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	await process_frame
	app.set_reduced_motion(true)
	app.chest_button.button_down.emit()
	if app.has_method("_process"):
		app._process(0.5)
	app.chest_button.button_up.emit()
	check(app.model.chest_state == "closed", "A short chest press does not open it")
	app.chest_button.button_down.emit()
	if app.has_method("_process"):
		app._process(1.21)
	app.chest_button.button_up.emit()
	await process_frame
	check(app.model.chest_state == "opened", "A completed hold reveals the reduced-motion reward")
	check(app.effects.particle_count() == 0, "Reduced motion has no moving particles")
	check(not app.model.reward_id.is_empty(), "Opening selects a seasonal reward variant")
	check(app.collected_rewards.has(app.model.reward_id) if has_property(app, "collected_rewards") else false,
		"Opened rewards are recorded in the collection")
	check_no_reward_flight(app, "Reduced motion skips the moving reward flight")
	check(app.collection_button.scale == Vector2.ONE, "Reduced motion does not bounce the rewards button")
	app.choose_theme("winter")
	check(app.model.reward_theme == "spring" and app.chest.theme_id == "spring", "Earned chest remains spring")
	check(app.reward_image.visible, "Opening displays the reward medallion")
	app.new_round(81)
	check(app.audio.muted, "Replay preserves mute")
	check(app.model.chest_state == "closed" and app.effects.particle_count() == 0, "Replay clears reward/effects")
	check(app.feedback_timer.is_stopped(), "Replay cancels feedback timer")
	app.set_reduced_motion(false)
	for pair in pairs_for(app.model):
		app.cards[pair[0]].pressed.emit()
		app.cards[pair[1]].pressed.emit()
		app.feedback_timer.timeout.emit()
	prepare_completion(app)
	app.chest_button.grab_focus()
	joy_button(JOY_BUTTON_A, true)
	await process_frame
	if app.has_method("_process"):
		app._process(1.21)
	joy_button(JOY_BUTTON_A, false)
	await process_frame
	check(app.model.chest_state == "opening", "Normal opening is staged, not immediate")
	check(app.theme_buttons.all(func(button: Button) -> bool: return button.disabled) if has_property(app, "theme_buttons") else false,
		"Opening disables theme selection")
	var locked_theme: String = app.model.theme_id
	joy_tap(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	check(app.model.theme_id == locked_theme, "Controller shoulder season changes are disabled while the chest opens")
	check(app.effects.particle_count() == 24, "Opening first reveals the earned fragment with 24 particles")
	check_no_reward_flight(app, "The reward flight does not appear before the chest finishes opening")
	var opened_reward_id: String = app.model.reward_id
	var reward_count_before: int = app.collected_rewards.size()
	var was_collected: bool = app.collected_rewards.has(opened_reward_id)
	app.chest.finish_immediately()
	app._finish_fragment_delivery()
	check(app.model.chest_state == "opened", "The native animation completes the reward")
	check(app.collected_rewards.has(opened_reward_id), "The opened reward is recorded before visual delivery")
	check(app.collected_rewards.size() == reward_count_before + (0 if was_collected else 1),
		"The reward collection changes exactly once when opening finishes")
	check(visible_reward_flight(app) == null, "The flight copy waits for the reveal pop and pause")
	step_reward_tween(app, 0.56, "The reward tween starts the flight after the pop and pause")
	var flight := visible_reward_flight(app)
	check(flight != null, "A visible reward copy appears for the flight")
	if flight != null:
		var data_script: GDScript = load("res://scripts/game_data.gd")
		var reward: Dictionary = data_script.reward(opened_reward_id)
		check(flight.get_parent() == app and flight.z_index < app.collection_page.z_index,
			"The reward flight is a root overlay below the collection page")
		check(flight.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"The reward flight copy never steals input")
		check(flight.texture == load(reward.symbol),
			"The reward flight uses the locked earned reward texture")
		var start_size: Vector2 = flight.size
		step_reward_tween(app, 0.19, "The reward tween advances along the flight path")
		root.size = Vector2i(390, 844)
		app.choose_theme("winter")
		var manual_tween: Tween = app._reward_tween
		var manual_elapsed := manual_tween.get_total_elapsed_time()
		await process_frame
		await process_frame
		check(is_equal_approx(manual_tween.get_total_elapsed_time(), manual_elapsed),
			"Manual reward timing is unaffected by SceneTree frame delays")
		check(flight.texture == load(reward.symbol),
			"Changing season during flight does not swap the earned reward artwork")
		step_reward_tween(app, 0.201, "The reward tween reaches the current rewards button center")
		var target_center: Vector2 = app.collection_button.get_global_rect().get_center()
		check(flight.get_global_rect().get_center().distance_to(target_center) <= 1.0,
			"The reward flight lands on the actual current My Rewards button center")
		check(flight.size.x < start_size.x and flight.size.y < start_size.y,
			"The reward shrinks into the collection button during flight")
		check(app.collection_button.scale != Vector2.ONE,
			"The rewards button visibly bounces on arrival")
		if app._reward_tween != null:
			app._reward_tween.custom_step(1.0)
		await process_frame
		check(app.collection_button.scale == Vector2.ONE,
			"The rewards button settles back to normal scale")
		check(visible_reward_flight(app) == null,
			"The flight copy is removed after arrival")
	check(app.collected_rewards.size() == reward_count_before + (0 if was_collected else 1),
		"The flight animation does not duplicate the collection entry")
	app.new_round(90)
	check_no_reward_flight(app, "Starting a new round leaves no reward flight behind")
	for pair in pairs_for(app.model):
		app.cards[pair[0]].pressed.emit()
		app.cards[pair[1]].pressed.emit()
		app.feedback_timer.timeout.emit()
	if app.has_method("_drag_chest"):
		app._drag_chest(Vector2(10000, 10000))
		root.size = Vector2i(844, 390)
		await process_frame
		await process_frame
		var chest_rect := Rect2(
			app.chest._art.position + app.chest._bounds.position * app.chest._art.scale,
			app.chest._bounds.size * app.chest._art.scale
		)
		check(Rect2(Vector2.ZERO, app.chest.size).grow(0.5).encloses(chest_rect),
			"Chest dragging stays inside its canvas after resizing")
	else:
		check(false, "The chest can be dragged inside its canvas")
	if app.has_method("_chest_input"):
		root.size = Vector2i(960, 540)
		await process_frame
		await process_frame
		app.chest.set_drag_offset(Vector2.ZERO)
		app.chest_button.button_down.emit()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		Input.parse_input_event(press)
		var mouse_motion := InputEventMouseMotion.new()
		mouse_motion.position = Vector2(160, 90)
		mouse_motion.relative = Vector2(5.0, 0.0)
		mouse_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		app._chest_input(mouse_motion)
		var emulated_touch := InputEventScreenDrag.new()
		emulated_touch.index = 0
		emulated_touch.position = mouse_motion.position
		emulated_touch.relative = mouse_motion.relative
		app._chest_input(emulated_touch)
		check(app.chest.drag_offset.distance_to(Vector2(5.0, 0.0)) < 0.01,
			"Duplicated touch/emulated mouse drag tracks the pointer exactly once")
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		Input.parse_input_event(release)
		app.chest_button.button_up.emit()
		var released_drag := InputEventScreenDrag.new()
		released_drag.index = 0
		released_drag.position = Vector2(220, 120)
		released_drag.relative = Vector2(5.0, 0.0)
		app._chest_input(released_drag)
		check(app.chest.drag_offset.distance_to(Vector2(5.0, 0.0)) < 0.01,
			"Chest drag stops on early release instead of following stale touch events")
	else:
		check(false, "The chest receives native drag input")
	app.chest_button.button_down.emit()
	if app.has_method("_process"):
		app._process(1.21)
	app.chest_button.button_up.emit()
	app.on_page_hidden()
	check(app.model.chest_state == "opened", "Hiding finalizes an already-earned opening once")
	check(app.effects.particle_count() == 0, "Hiding during opening clears particles")
	check_no_reward_flight(app, "Hiding cancels a reward flight started by finish_immediately")
	check(app._medallion.scale == Vector2.ONE, "Hiding does not leave a queued reward-pop animation")
	check(app._reward_tween == null or not app._reward_tween.is_running(), "Hiding cancels the reveal tween too")
	app.new_round(91)
	win_round(app)
	prepare_completion(app)
	app.chest_button.button_down.emit()
	if app.has_method("_process"):
		app._process(1.21)
	app.chest_button.button_up.emit()
	app.chest.finish_immediately()
	app._finish_fragment_delivery()
	step_reward_tween(app, 0.56, "The reward tween can be cancelled by opening the collection")
	check(visible_reward_flight(app) != null, "The reward flight is visible before collection opens")
	app._show_collection()
	check_no_reward_flight(app, "Opening My Rewards cancels the active reward flight")
	check(app.collection_button.scale == Vector2.ONE, "Opening My Rewards resets the target bounce scale")
	app._hide_collection()
	app.new_round(91)
	win_round(app)
	prepare_completion(app)
	app.chest_button.button_down.emit()
	if app.has_method("_process"):
		app._process(1.21)
	app.chest_button.button_up.emit()
	app.chest.finish_immediately()
	app._finish_fragment_delivery()
	step_reward_tween(app, 0.56, "The reward tween can be cancelled by replay")
	check(visible_reward_flight(app) != null, "The reward flight is visible before replay")
	app._replay()
	check_no_reward_flight(app, "Replay cancels the active reward flight")
	check(app.collection_button.scale == Vector2.ONE, "Replay resets the target bounce scale")
	var wrong: Array = wrong_pair_for(app.model)
	var wrong_start: Vector2 = app.cards[wrong[0]].position
	app.cards[wrong[0]].pressed.emit()
	app.cards[wrong[1]].pressed.emit()
	check(app.cards[wrong[0]].rotation != 0.0 or app.cards[wrong[0]].position != wrong_start,
		"Wrong cards immediately start a playful shake")
	if app._mistakes.has_method("set_filled_count"):
		check(app._mistakes.filled_count == 1 and app._mistakes.total_count == 3,
			"A mismatch fills exactly one gentle retry badge")
	else:
		check(false, "A mismatch fills exactly one gentle retry badge")
	app.feedback_timer.timeout.emit()
	for count in range(2):
		app.cards[wrong[0]].pressed.emit()
		app.cards[wrong[1]].pressed.emit()
		app.feedback_timer.timeout.emit()
	check(app.model.phase == "lost" and app.failure_image.visible, "Failure displays the encouraging picture")
	await process_frame
	await process_frame
	for result_control in [app._title, app._caption, app.replay_button]:
		check(result_control.is_visible_in_tree() and root.get_visible_rect().encloses(result_control.get_global_rect()),
			"Loss result controls stay inside the viewport: %s %s" % [result_control.name, result_control.get_global_rect()])
	check(app.replay_button.has_focus(), "Controller focus moves to Play again after losing")
	check(not app.audio.music.playing, "Loss stops background music")
	check(app.has_method("_play_loss_bear") and has_property(app, "failure_button"),
		"The loss-screen bear is an interactive target")
	if app.has_method("_play_loss_bear") and has_property(app, "failure_button"):
		var loss_cards: Array = app.model.cards.duplicate(true)
		var loss_rewards: Dictionary = app.collected_rewards.duplicate()
		check(app.failure_button.visible and not app.failure_button.disabled,
			"The bear can be played with only on the loss screen")
		check(not app.collection_page.visible and not app._preview_page.visible,
			"The loss-screen interaction fixture is not covered by a modal")
		app.failure_button.grab_focus()
		check(app.failure_button.has_focus() and not app._controller_accept_needs_release,
			"The bear has focus and controller accepts are armed before the tap")
		joy_tap(JOY_BUTTON_A)
		await process_frame
		check(app._failure_tween != null and app._failure_tween.is_valid(),
			"Controller A starts a gentle bear reaction")
		check(app._status_announcement.contains("High five!"), "The bear gives an encouraging reaction")
		var previous_loss_tween: Tween = app._failure_tween
		for tap in range(5):
			app.failure_button.pressed.emit()
		check(previous_loss_tween != null and not previous_loss_tween.is_valid(),
			"Rapid bear taps replace, rather than stack, animations")
		check(app.model.phase == "lost" and app.model.mistakes == 3 and app.model.cards == loss_cards
			and app.collected_rewards == loss_rewards, "Bear play never changes the result or grants rewards")
		if app._failure_tween != null:
			app._failure_tween.pause()
			app._failure_tween.custom_step(1.0)
		check(app._failure_tween == null and app.failure_image.scale == Vector2.ONE
			and is_zero_approx(app.failure_image.rotation) and not app._failure_sparkle.visible,
			"The finite bear reaction returns to its resting state")
		app.set_reduced_motion(true)
		check(app.failure_button.has_focus(), "Motion changes preserve the focused bear action")
		app.failure_button.pressed.emit()
		check(app._failure_tween == null and app.failure_image.scale == Vector2.ONE
			and not app._failure_sparkle.visible, "Reduced motion keeps bear feedback static")
		check(not app.audio.music.playing, "Playing with the bear never restarts lost-round music")
		app.set_reduced_motion(false)
		app._play_loss_bear()
		app._show_collection()
		check(app._failure_tween == null and not app._failure_sparkle.visible,
			"Opening My Rewards cancels the bear's reaction")
		app._hide_collection()
		app._play_loss_bear()
		app.on_page_hidden()
		check(app._failure_tween == null and app.model.phase == "lost" and not app.audio.active,
			"Hiding the page cancels bear play without changing the result")
		app._play_loss_bear()
	app.new_round(92)
	if app.has_method("_play_loss_bear"):
		check(not app.failure_button.visible and app._failure_tween == null,
			"Replay removes loss-screen interaction and effects")
		app._play_loss_bear()
		check(app._failure_tween == null, "The bear cannot react outside the loss screen")
	var first: String = app.model.cards[0].id
	app.cards[first].pressed.emit()
	var second: String = wrong_pair_for(app.model)[0]
	app.on_page_hidden()
	check(not app.audio.active, "Hiding pauses audio until another gesture")
	check(app.effects.particle_count() == 0, "Hiding clears transient effects")
	check(app.model.selected_id == first, "Hiding does not reset a selection")
	app.cards[second].pressed.emit()
	app.queue_free()
	await process_frame
	joy_button(JOY_BUTTON_A, true)
	var held_app = packed.instantiate()
	held_app.medal_progress = progress_script.new(directory + "/held.cfg", directory + "/legacy.cfg")
	held_app.playroom_save_path = directory + "/held-playroom.cfg"
	held_app._mode_id = "match"
	root.add_child(held_app)
	await process_frame
	await process_frame
	held_app.audio.set_muted(true)
	var held_first: String = held_app.model.cards[0].id
	held_app.cards[held_first].grab_focus()
	await process_frame
	check(held_app.cards[held_first].has_focus(), "Startup hold regression focuses a native card")
	check(Input.is_joy_button_pressed(0, JOY_BUTTON_A),
		"Startup hold regression begins with controller A already down")
	check(has_property(held_app, "_controller_accept_needs_release") and held_app._controller_accept_needs_release,
		"Native controller accepts are gated until a startup A hold releases")
	joy_button(JOY_BUTTON_A, true)
	await process_frame
	check(held_app.model.selected_id == "",
		"A held on the loading toy cannot activate native focus before release")
	joy_button(JOY_BUTTON_A, false)
	await process_frame
	joy_tap(JOY_BUTTON_A)
	await process_frame
	check(held_app.model.selected_id == held_first,
		"Controller A activates normally after the startup hold is released")
	held_app.audio.halt()
	held_app.queue_free()
	await process_frame
	await process_frame
	var files := DirAccess.open(directory)
	for filename in files.get_files():
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
