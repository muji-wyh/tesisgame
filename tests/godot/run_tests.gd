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
	_test_hints(model_script, words)
	_test_results(model_script, words)
	_test_data(words)
	_test_controls()
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
	# This fixture exercises an earned chest; chance outcomes have separate coverage.
	app.model.chest_earned = true
	for pair in pairs_for(app.model):
		app.cards[pair[0]].pressed.emit()
		app.cards[pair[1]].pressed.emit()
		app.feedback_timer.timeout.emit()
	preload("res://tests/godot/player_flow_fixture.gd").finish_celebration(app)


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


func check_no_collectible_presentation(app, message: String) -> void:
	var medal_script = load("res://scripts/medal_view.gd")
	var art: Array[Node] = app._stage.find_children("*", "", true, false)
	check(not art.any(func(node: Node) -> bool: return node.get_script() == medal_script)
		and app.find_child("MedalFragment", true, false) == null
		and app.find_child("RewardFlight", true, false) == null, message)


func collection_scroll(app) -> ScrollContainer:
	return app._age_catalog.scroll


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
	for seed_value in range(80):
		check(model.reset(words, seed_value), "A valid vocabulary starts a round")
		check(model.cards.size() == 10, "There are ten cards")
		check(pairs_for(model).size() == 5, "There are exactly five complete pairs")
		var ids: Dictionary = {}
		var counts: Dictionary = {}
		var kinds: Dictionary = {"word": 0, "image": 0}
		for card in model.cards:
			ids[card.id] = true
			counts[card.word.id] = counts.get(card.word.id, 0) + 1
			kinds[card.kind] += 1
		check(ids.size() == 10, "Card IDs are unique")
		check(counts.size() == 5, "The five pairs use five distinct words")
		check(counts.values().count(2) == 5, "Every word has exactly one matching picture")
		check(kinds.word == 5 and kinds.image == 5, "The board balances five words and five pictures")
		check(model.phase == "waiting", "Rounds start waiting")
		check((model.matched_ids.size() / 2) == 0 and model.mistakes == 0, "Counters reset")
		seen_themes[model.theme_id] = true
	check(seen_themes.size() == 8, "New rounds can choose each theme")
	model.reset(words, 17)
	var deck: Array = model.cards.duplicate(true)
	var season: String = model.theme_id
	model.reset(words, 17)
	check(model.cards == deck and model.theme_id == season, "Seeded rounds are reproducible")
	check(not model.reset(words.slice(0, 4), 1), "Fewer than five words cannot start a round")
	_test_word_reachability(model, words)


func _test_word_reachability(model, words: Array) -> void:
	var data: GDScript = load("res://scripts/game_data.gd")
	var speech: GDScript = load("res://scripts/speech_words.gd")
	var pictured: Array = words.filter(func(word: Dictionary) -> bool: return data.supports_mode(word, "match"))
	var reached: Dictionary = {}
	for index in range(pictured.size()):
		var word: Dictionary = pictured[index]
		var started: bool = model.reset(words, index, false, "", word.id, str(data.word_age(word)))
		check(started, "The full catalog can deal each pictured word at its own growth level: " + word.id)
		if not started:
			continue
		var target_pair: Array = model.cards.filter(func(card: Dictionary) -> bool: return card.word.id == word.id)
		check(model.lesson_words[0].id == word.id and model.cards.size() == 10
			and pairs_for(model).size() == 5 and target_pair.size() == 2
			and target_pair[0].kind != target_pair[1].kind,
			"Every pictured word becomes one playable picture and word pair: " + word.id)
		check(model.lesson_words.all(func(other: Dictionary) -> bool:
			return data.word_age(other) <= data.word_age(word) and data.supports_mode(other, "match")),
			"Reachable lessons retain their unlocked vocabulary boundaries: " + word.id)
		for first in range(5):
			for second in range(first + 1, 5):
				check(not data.word_pair_conflicts(model.lesson_words[first], model.lesson_words[second])
					and not speech.words_conflict(model.lesson_words[first], model.lesson_words[second]),
					"Every reachable word has unambiguous lesson partners: " + word.id)
		if target_pair.size() == 2:
			reached[word.id] = true
	check(reached.size() == 1285 and reached.size() == pictured.size(),
		"Every production picture word is reachable as a real playable pair")
	print("Round reachability: %d pictured words verified" % reached.size())


func _test_fresh_rounds(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	var vocabulary: Array = words.slice(0, 10)
	model.reset(vocabulary, 17)
	for round_index in range(6):
		var previous: Array = model.cards.map(func(card: Dictionary) -> String: return card.word.id)
		model.reset(vocabulary)
		check(model.cards.all(func(card: Dictionary) -> bool: return not previous.has(card.word.id)),
			"An unseeded model reset prefers five words absent from the previous board")
		check(pairs_for(model).size() == 5 and model.cards.size() == 10,
			"Fresh boards retain five complete pairs and ten cards")
	for count in range(5, 10):
		model.reset(words.slice(0, count))
		model.reset(words.slice(0, count))
		check(model.cards.size() == 10 and pairs_for(model).size() == 5,
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
	check(model.mistakes == 1 and (model.matched_ids.size() / 2) == 0, "Wrong pair increments only mistakes")
	check(model.phase == "feedback", "Wrong feedback locks the round")
	check(model.select(wrong[0]) == "ignored", "Cards cannot be selected during feedback")
	model.resolve_feedback()
	check(model.phase == "waiting" and model.selected_id == "", "Feedback clears selection")
	var pair: Array = pairs_for(model)[0]
	model.select(pair[0])
	check(model.select(pair[1]) == "correct", "Matching opposite kinds are correct")
	check((model.matched_ids.size() / 2) == 1 and model.mistakes == 1, "A completed pair retains the earlier mistake record")
	model.resolve_feedback()
	check(model.matched_ids.size() == 2, "Both matched cards are retained as matched")
	check(model.select(pair[0]) == "ignored", "Matched cards cannot score twice")


func _test_hints(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	check(model.has_method("request_hint") and has_property(model, "hint_ids")
		and has_property(model, "hints_remaining"),
		"The model supports three helpful hints without success or streak counters")
	if not model.has_method("request_hint") or not has_property(model, "hints_remaining"):
		return
	model.reset(words, 6)
	var deck: Array = model.cards.duplicate(true)
	var pairs: Array = pairs_for(model)
	check(model.hints_remaining == 3, "A new round starts with three hints")
	model.select(pairs[1][1])
	check(model.request_hint() and model.hint_ids.has(pairs[1][0]) and model.hint_ids.has(pairs[1][1]),
		"A hint prefers the selected card's real partner")
	check(model.hints_remaining == 2 and model.selected_id == pairs[1][1] and (model.matched_ids.size() / 2) == 0 and model.mistakes == 0,
		"Hints preserve a useful selection without scoring or penalizing")
	check(not model.request_hint() and model.hints_remaining == 2,
		"An active hint cannot spend another allowance")
	check(model.cards == deck, "Repeated hints never shuffle or score the board")
	model.set_theme("winter")
	check(model.hint_ids.size() == 2 and model.hints_remaining == 2,
		"Changing seasons preserves the active hint and remaining allowance")
	model.select(pairs[1][0])
	check(model.hint_ids.is_empty(), "Matching clears the hint and records the actual pair")
	check(not model.request_hint() and model.hints_remaining == 2,
		"Hints cannot interrupt feedback or spend an allowance")
	model.resolve_feedback()
	check(model.select(pairs[1][0]) == "ignored", "Matched cards cannot match twice")
	check(model.request_hint() and model.hints_remaining == 1,
		"Completing a hinted match leaves the second hint available")
	var second_hint: Array = model.hint_ids.duplicate()
	check(not model.request_hint() and model.hints_remaining == 1,
		"Repeated input cannot spend the active second hint")
	model.select(second_hint[0])
	model.select(second_hint[0])
	check(model.hint_ids.is_empty() and model.hints_remaining == 1,
		"Cancelling clears the highlight without refunding the second hint")
	check(model.request_hint() and model.hints_remaining == 0, "The third hint is available")
	var third_hint: Array = model.hint_ids.duplicate()
	check(not model.request_hint() and model.hints_remaining == 0, "A fourth hint is rejected")
	model.select(third_hint[0])
	model.select(third_hint[0])
	for pair in pairs:
		if model.matched_ids.has(pair[0]):
			continue
		model.select(pair[0])
		model.select(pair[1])
		model.resolve_feedback()
	check(model.phase == "won" and not model.request_hint(),
		"Completing all five pairs wins and closes hint input")
	model.reset(words, 6)
	check(model.hint_ids.is_empty() and model.hints_remaining == 3,
		"A new model round clears matched cards and restores all three hints")
	model.select(pairs[0][0])
	model.select(pairs[0][1])
	check(not model.request_hint() and model.hints_remaining == 3,
		"A rejected request during feedback does not spend a hint")
	model.resolve_feedback()
	check(model.request_hint() and model.hints_remaining == 2 and model.selected_id.is_empty(),
		"After a match, a hint finds another complete pair without creating a selection or mistake")
	var hint: Array = model.hint_ids.duplicate()
	check(hint.size() == 2 and not hint.any(func(id: String) -> bool: return model.matched_ids.has(id)),
		"Hints never recommend already matched cards")
	model.select(hint[0])
	check(model.hint_ids.size() == 2, "The hint stays visible while choosing its first card")
	model.select(hint[0])
	check(model.hint_ids.is_empty(), "Cancelling selection clears its hint")
	check(model.hints_remaining == 2, "Cancelling a hint's highlight does not refund it")
	check(not model.reset(words.slice(0, 4)) and model.hints_remaining == 2,
		"A failed reset cannot refill the current round's hints")
	check(model.request_hint() and model.hints_remaining == 1,
		"The remaining allowance stays usable after a rejected reset")
	model.select(model.hint_ids[0])
	model.select(model.hint_ids[0])
	var remaining: Array = pairs.slice(1)
	model.select(remaining[0][0])
	model.select(remaining[1][1])
	check((model.matched_ids.size() / 2) == 1 and model.mistakes == 1,
		"A mistake preserves every earned match")
	model.resolve_feedback()
	for count in range(2):
		model.select(remaining[0][0])
		model.select(remaining[1][1])
		model.resolve_feedback()
	check(model.phase == "waiting" and model.hints_remaining == 1 and model.request_hint()
		and model.hints_remaining == 0, "Hints remain usable after three incorrect pairs")
	model.reset(words, 6)
	check(model.hints_remaining == 3 and model.request_hint() and model.hints_remaining == 2,
		"Starting a new round restores all three hints")


func _test_results(model_script: GDScript, words: Array) -> void:
	var model = model_script.new()
	check(not model.has_method("set_practice") and not has_property(model, "practice_mode"),
		"Unlimited attempts are the standard rules without a separate practice toggle")
	model.reset(words, 27)
	var pairs: Array = pairs_for(model)
	for index in range(pairs.size()):
		var pair: Array = pairs[index]
		model.select(pair[0])
		model.select(pair[1])
		check(model.phase == "feedback" and (model.matched_ids.size() / 2) == index + 1,
			"Every correct pair waits for feedback before a possible result")
		model.resolve_feedback()
		if index in [2, 3]:
			check(model.phase == "waiting" and model.matched_ids.size() == (index + 1) * 2,
				"The round remains active after match %d with its earned cards intact" % (index + 1))
		if index == 2:
			check(model.request_hint() and model.hints_remaining == 2 and model.hint_ids.size() == 2,
				"A remaining hint is still available after the third match")
	check(model.phase == "won" and (model.matched_ids.size() / 2) == 5, "Only the fifth resolved success wins")
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
	check(model.cancel_open() and model.chest_state == "closed" and model.phase == "won"
		and model.reward_id.is_empty() and model.reward_theme.is_empty(),
		"Cancelling opening keeps the won round and discards its unclaimed reward selection")
	check(not model.cancel_open() and not model.finish_open(), "A cancelled opening rejects duplicate cancellation and stale completion")
	check(model.begin_open("spring-1"), "The same earned chest can reopen after cancellation")
	check(model.finish_open(), "Opening completes once")
	check(not model.finish_open(), "Opening completion is one-shot")
	check(not model.cancel_open() and model.chest_state == "opened", "Releasing after completion cannot retract a saved reward")
	check(model.set_theme("winter"), "Theme can change after opening")
	check(model.reward_theme == "spring" and model.chest_state == "opened", "Earned reward is immutable")
	model.reset(words, 27)
	check(model.reward_theme == "" and model.chest_state == "closed" and (model.reward_id == "" if has_property(model, "reward_id") else false),
		"A new model round clears the previous earned reward")
	check(not model.finish_open(), "A stale opening cannot reward the new round")
	var wrong: Array = wrong_pair_for(model)
	for count in range(7):
		model.select(wrong[0])
		model.select(wrong[1])
		model.resolve_feedback()
	check(model.phase == "waiting" and model.mistakes == 7 and model.matched_ids.is_empty(),
		"Seven mistakes leave the same Match board playable")
	check(not model.begin_open(), "An incomplete board cannot grant a chest")
	model.reset(words, 12)
	var pair: Array = pairs_for(model)[0]
	model.select(pair[0])
	model.select(pair[1])
	model.resolve_feedback()
	wrong = wrong_pair_for(model)
	# Retry unmatched cards repeatedly while preserving the earned pair.
	for card in model.cards:
		for other in model.cards:
			if not card.id in model.matched_ids and not other.id in model.matched_ids:
				if card.kind != other.kind and card.word.id != other.word.id:
					wrong = [card.id, other.id]
	for count in range(7):
		model.select(wrong[0])
		model.select(wrong[1])
		model.resolve_feedback()
	check(model.phase == "waiting" and model.matched_ids.size() == 2 and model.mistakes == 7,
		"Seven later mistakes preserve the earned pair without ending the round")
	check(model.request_hint(), "A hint remains available after seven mistakes")
	for remaining_pair in pairs_for(model):
		if model.matched_ids.has(remaining_pair[0]):
			continue
		model.select(remaining_pair[0])
		model.select(remaining_pair[1])
		model.resolve_feedback()
	check(model.phase == "won" and model.matched_ids.size() == model.cards.size(),
		"Matching every real card wins after unlimited retries")
	check(model.begin_open("spring-1") and model.finish_open() and not model.finish_open(),
		"A win after repeated mistakes earns exactly one chest")
	check(not has_property(model, "successes") and not has_property(model, "streak"),
		"Match stores completed cards without redundant correct or streak counters")


func _test_data(words: Array) -> void:
	check(words.size() == 1550, "The game includes 1,550 growth vocabulary entries")
	var path := "res://scripts/game_data.gd"
	check(FileAccess.file_exists(path), "The native data loader exists")
	if not FileAccess.file_exists(path):
		return
	var data_script: GDScript = load(path)
	check(data_script != null and data_script.can_instantiate(), "The data loader compiles")
	if data_script == null or not data_script.can_instantiate():
		return
	check(data_script.validate_words(words) == "", "The shared words.json is accepted")
	for pair in [["earth", "planet"], ["acorn", "seed"], ["boot", "shoe"], ["shell", "clam"], ["flower", "rose"], ["comet", "meteor"]]:
		check(data_script.confusable_words(pair[0], pair[1]) and data_script.confusable_words(pair[1], pair[0]),
			"Overlapping names cannot become contradictory answer alternatives")
	check(not data_script.confusable_words("cat", "dog") and not data_script.confusable_words("rocket", "earth"),
		"Visually distinct vocabulary remains available as useful alternatives")
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
	for bad_text in ["", "abcdefghijklmnopqrstuvwxyz", "two words", "123", "word!"]:
		duplicate = words.duplicate(true)
		duplicate[0].text = bad_text
		check(data_script.validate_words(duplicate) != "", "Vocabulary text needs one English word with 1 to 24 letters")
	duplicate = words.duplicate(true)
	duplicate[0].text = duplicate[0].text.to_upper()
	check(data_script.validate_words(duplicate) == "", "English capitalization remains valid with case-insensitive uniqueness")
	for bad_path in ["https://example.invalid/cat.svg", "assets/images/words/../cat.svg", "C:\\cat.svg"]:
		duplicate = words.duplicate(true)
		duplicate[0].image = bad_path
		check(data_script.validate_words(duplicate) != "", "External/traversal image paths are rejected")
	for season in ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]:
		var theme: Dictionary = data_script.theme(season)
		check(theme.id == season and theme.name != "", "Each theme has a display name")
		check(data_script.has_method("rewards") and data_script.has_method("reward"),
			"Seasonal reward lookup helpers exist")
		if data_script.has_method("rewards") and data_script.has_method("reward"):
			var rewards: Array = data_script.rewards(season)
			var reward_ids: Dictionary = {}
			for reward in rewards:
				reward_ids[reward.id] = true
				check(reward.theme == season and reward.symbol == "res://assets/images/rewards/" + reward.id + ".svg",
					"Every reward variant has its own SVG")
			var expected_count: int = 10 if season in ["spring", "summer", "autumn", "winter"] else 6
			check(rewards.size() == expected_count and reward_ids.size() == expected_count, "Each theme has unique active and archived rewards")
	check(data_script.reward("missing").is_empty() if data_script.has_method("reward") else false,
		"Unknown reward variants are rejected")
	var expected_themes := {
		"spring": {
			"name": "Spring",
			"background": Color("#effbef"),
			"accent": Color("#237a57"),
			"light": Color("#bfe9c5"),
			"spark": Color("#ffa8bb"),
			"tint": Color("#eefbd6")
		},
		"summer": {
			"name": "Summer",
			"background": Color("#fff4df"),
			"accent": Color("#b94545"),
			"light": Color("#ffd192"),
			"spark": Color("#21afbc"),
			"tint": Color("#fff0cd")
		},
		"autumn": {
			"name": "Autumn",
			"background": Color("#fff2e5"),
			"accent": Color("#995323"),
			"light": Color("#ffd19b"),
			"spark": Color("#b46386"),
			"tint": Color("#ffe6c5")
		},
		"winter": {
			"name": "Winter",
			"background": Color("#eef5ff"),
			"accent": Color("#456791"),
			"light": Color("#c9dcf5"),
			"spark": Color("#aa97d4"),
			"tint": Color("#e6edff")
		},
		"ocean": {
			"name": "Ocean",
			"background": Color("#e7f8fa"),
			"accent": Color("#13758b"),
			"light": Color("#afdee6"),
			"spark": Color("#ffad87"),
			"tint": Color("#e1f4ef")
		},
		"space": {
			"name": "Space",
			"background": Color("#f1edfb"),
			"accent": Color("#694a99"),
			"light": Color("#d6c8f0"),
			"spark": Color("#efb451"),
			"tint": Color("#eae3ff")
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
		if not word.image.is_empty():
			word.image = "assets/images/word-library/" + word.id + ".webp"
			word.art_key = "library/" + word.id
	var data = data_script.new()
	check(data.load_all(), "Runtime JSON and imported chest manifest load: " + data.error)
	check(data.words == expected_words,
		"Godot preserves vocabulary fields while selecting the reviewed library image and its provenance")
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
	for season in ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]:
		var track: AudioStreamWAV = load("res://assets/audio/bgm/" + season + ".wav")
		check(track.mix_rate == 22050, "Mobile background music uses 22.05 kHz: " + season)
		check(not track.stereo, "Mobile background music uses mono: " + season)
	var original: AudioStreamWAV = load("res://assets/audio/bgm/spring.wav")
	var original_loop: int = original.loop_mode
	controller.interact("spring")
	check(controller.music.playing, "A gesture starts native background music")
	check(controller.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Background music loops")
	check(controller.music.stream != original and original.loop_mode == original_loop, "Loop setup does not mutate the shared WAV")
	controller.cue("select", "spring-theme")
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


func _test_play_improvements(app) -> void:
	check(has_property(app, "hint_button") and not has_property(app, "_success")
		and not has_property(app, "_mistakes") and not has_property(app, "_match_caption"),
		"The board has a reachable hint without retained counters or a redundant caption")
	if has_property(app, "hint_button") and app.model.has_method("request_hint"):
		app.new_round(6)
		check(app.hint_button.text.is_empty() and app.hint_button.count == 3 and not app.hint_button.disabled,
			"A new Match round shows all three hints")
		app.hint_button.grab_focus()
		app.hint_button.pressed.emit()
		var hinted: Array = app.model.hint_ids.duplicate()
		check(hinted.size() == 2 and app._status_announcement.begins_with("Hint:"),
			"The native Hint button announces a real pair")
		check(not app._controller_mode and app.cards[hinted[0]].has_focus(),
			"A keyboard hint focuses its first playable card without requiring a controller")
		check(app.model.hints_remaining == 2 and app.hint_button.disabled and app.hint_button.count == 2,
			"An active first hint shows two remaining and blocks duplicate spending")
		check(app.hint_button.focus_mode == Control.FOCUS_NONE,
			"Keyboard navigation skips a hint while its current is active")
		app.cards[hinted[0]].pressed.emit()
		app.hint_button.pressed.emit()
		check(app.cards[hinted[0]].has_focus() and app.model.selected_id == hinted[0]
			and app.model.hints_remaining == 2,
			"Repeated hint signals cannot move focus, cancel the card, or spend another hint")
		await create_timer(0.7).timeout
		for id in hinted:
			check(not app.cards[id].match_mark.visible,
				"Hinted cards do not display the success badge before they are matched")
		var link = app._hint_link
		var image_id: String = hinted[0] if app.model.card_by_id(hinted[0]).kind == "image" else hinted[1]
		var word_id: String = hinted[1] if hinted[0] == image_id else hinted[0]
		check(link.active and link.is_visible_in_tree() and link.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and link.source == app.cards[image_id] and link.target == app.cards[word_id] and link.path.size() == 2,
			"One noninteractive electric arc connects the hinted image card to its matching word")
		check(link.is_processing() == not app.reduced_motion,
			"The connecting hint arc survives the selected card's short press feedback")
		check(app.cards[hinted[0]].get_theme_stylebox("normal").bg_color != app.cards[hinted[1]].get_theme_stylebox("normal").bg_color,
			"The selected hint card keeps a distinct surface after its short press reaction ends")
		var previous_reduced_motion: bool = app.reduced_motion
		app.set_reduced_motion(false)
		var moving_phase: float = link.phase
		await create_timer(0.08).timeout
		check(link.phase != moving_phase, "The active connecting arc advances its flowing electrical motion")
		app.set_reduced_motion(true)
		var still_phase: float = link.phase
		await process_frame
		await process_frame
		check(link.reduced_motion and not link.is_processing() and link.active and link.is_visible_in_tree()
			and is_equal_approx(link.phase, still_phase),
			"Reduced motion keeps the connecting arc visible and still")
		app.set_reduced_motion(previous_reduced_motion)
		app._show_collection()
		check(link.paused and link.active and not link.is_processing(), "Opening rewards pauses the connecting hint arc")
		var previous_hint: Array = hinted.duplicate()
		joy_tap(JOY_BUTTON_X)
		await process_frame
		check(app.model.hint_ids == previous_hint and app.model.hints_remaining == 2
			and app.collection_page.visible,
			"Xbox X cannot trigger hints behind a modal")
		app._hide_collection()
		app.on_page_hidden()
		app.choose_theme("winter")
		check(link.paused and link.active and not link.is_processing(),
			"Page hiding keeps the connecting arc paused through a theme refresh")
		check(app.hint_button.disabled and app.model.hints_remaining == 2 and not app.model.request_hint(),
			"Page hiding and season changes preserve the active hint and allowance")
		app.on_page_visible()
		check(not link.paused and link.active and link.is_processing() == not app.reduced_motion,
			"Returning to the board restores arc motion according to the accessibility setting")
		app.cards[hinted[0]].pressed.emit()
		app.cards[hinted[0]].pressed.emit()
		check(app.model.hint_ids.is_empty() and not app.hint_button.disabled and app.hint_button.count == 2,
			"Clearing the current makes the second hint available")
		check(not link.active and not link.is_processing() and link.path.is_empty(),
			"Cancelling a hint removes its connecting arc and stops its animation")
		app.hint_button.pressed.emit()
		var second_hint: Array = app.model.hint_ids.duplicate()
		check(app.model.hints_remaining == 1 and app.hint_button.count == 1,
			"The second successful request leaves one hint")
		app.cards[second_hint[0]].pressed.emit()
		app.cards[second_hint[0]].pressed.emit()
		app._controller_mode = true
		joy_tap(JOY_BUTTON_X)
		await process_frame
		var third_hint: Array = app.model.hint_ids.duplicate()
		check(app.model.hints_remaining == 0 and app.hint_button.count == 0 and app.hint_button.disabled
			and app.hint_button.tooltip_text.begins_with("No hints left"),
			"Xbox X consumes the shared third hint and disables the button")
		if app.model.selected_id != third_hint[0]:
			app.cards[third_hint[0]].pressed.emit()
		app.cards[third_hint[1]].pressed.emit()
		check((app.model.matched_ids.size() / 2) == 1, "Completing a hint uses an already selected card instead of cancelling it")
		check(not link.active and not link.is_processing()
			and app.cards[third_hint[0]].match_mark.visible and app.cards[third_hint[1]].match_mark.visible,
			"Matching the hinted pair removes the arc and shows success badges only on the completed cards")
		check(app.hint_button.disabled, "The exhausted hint stays disabled during match feedback")
		app.feedback_timer.timeout.emit()
		for pair in pairs_for(app.model):
			if app.model.matched_ids.has(pair[0]):
				continue
			app.cards[pair[0]].pressed.emit()
			app.cards[pair[1]].pressed.emit()
			check(app.hint_button.disabled, "The exhausted hint stays disabled during match feedback")
			var sparkle: Control = app.cards[pair[0]].get_node_or_null("MatchSparkle")
			check(sparkle != null and sparkle.particle_count <= 6,
				"Each correct card gets a small, bounded star celebration")
			check(app._status_announcement.contains("Great match!"),
				"Correct feedback encourages matching without a numbered streak")
			app.feedback_timer.timeout.emit()
		check(app.model.matched_ids.size() == 10, "Every completed pair remains matched")
		joy_tap(JOY_BUTTON_X)
		await process_frame
		check(app.model.hint_ids.is_empty() and app.model.hints_remaining == 0 and app.hint_button.disabled,
			"Xbox X cannot exceed the three shared hints")
		app.set_reduced_motion(true)
		check(app.model.matched_ids.size() == 10, "Reduced motion preserves all completed cards")
		check(not app.hint_button.visible, "Finished rounds hide the hint action")
		app.set_reduced_motion(false)
		app.new_round(6)
		check(not app.hint_button.disabled and app.hint_button.count == 3
			and app.model.hints_remaining == 3,
			"A new round restores all three hints")
		var first: Array = pairs_for(app.model)[0]
		app.cards[first[0]].pressed.emit()
		app.hint_button.pressed.emit()
		check(app.cards[first[1]].has_focus() and app.model.selected_id == first[0],
			"The round's first hint focuses the partner of an already selected card")
		app.cards[first[1]].pressed.emit()
		app.on_page_hidden()
		check(app._feedback_tweens.is_empty() and app.cards[first[0]].scale == Vector2.ONE,
			"Hiding the page stops transient match effects without losing progress")
		check(app.feedback_timer.paused, "Hiding the page pauses the pending automatic match transition")
		app.on_page_visible()
		app.feedback_timer.timeout.emit()
		check((app.model.matched_ids.size() / 2) == 1, "Cancelling cosmetic feedback preserves the earned match")
	var saved_rewards: Dictionary = app.collected_rewards.duplicate()
	var data_script: GDScript = load("res://scripts/game_data.gd")
	for season in ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]:
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


func _test_season_progress(app) -> void:
	var saved_rewards: Dictionary = app.collected_rewards.duplicate()
	var data_script: GDScript = load("res://scripts/game_data.gd")
	set_completed_rewards(app, {})
	check(app.medal_progress.completed_count("spring") == 0, "Empty progress starts with no completed medals")
	var completed: Dictionary = {}
	for reward in data_script.medals("spring").slice(0, 3):
		completed[reward.id] = true
	set_completed_rewards(app, completed)
	check(app.medal_progress.completed_count("spring") == 3
		and app.medal_progress.completed_count("summer") == 0,
		"Earned variants are counted separately by season")
	for reward in data_script.medals("spring"):
		completed[reward.id] = true
	set_completed_rewards(app, completed)
	check(app.medal_progress.completed_count("spring") == 6,
		"A completed season retains exactly six earned medals")
	app.new_round(6)
	var seeded_theme: String = app.model.theme_id
	app.choose_theme("summer")
	app.new_round(-1, true)
	check(app.model.theme_id == "summer", "A same-lesson internal fixture reset retains the chosen season")
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
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
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
	_test_season_progress(app)
	check(app.find_child("Practice", true, false) == null,
		"Unlimited attempts do not require a practice toggle")
	check(app._voice_button.disabled and app._voice_button.focus_mode == Control.FOCUS_NONE,
		"Keyboard navigation skips Voice when recognition is unavailable")
	check(app.cards.size() == 10, "The scene creates ten native card buttons")
	check(app.find_child("Mute", true, false) == null and app.find_child("Listen", true, false) == null,
		"Mute and Listen controls are removed")
	check(app.find_child("Motion", true, false) == null,
		"The FX motion button is removed while OS/browser reduced-motion remains supported")
	check(has_property(app, "theme_buttons") and app.theme_buttons.size() == 8,
		"All eight themes remain available")
	if has_property(app, "theme_buttons"):
		check(app.theme_buttons.all(func(button: Button) -> bool:
			return button.text.is_empty() and button.tooltip_text == button.name and button.get("accessibility_name") == button.name),
			"Icon-only world choices retain their exact names in tooltips and accessibility")
		check(app.theme_buttons.all(func(button: Button) -> bool: return app._world_choices.is_ancestor_of(button))
			and not app._world_choices.is_visible_in_tree(),
			"World choices live in More instead of competing with the playfield")
	var theme_style_id: int = app.theme_buttons[0].get_theme_stylebox("normal").get_instance_id()
	var mode_style_id: int = app._mode_buttons[0].get_theme_stylebox("normal").get_instance_id()
	app._refresh()
	check(app.theme_buttons[0].get_theme_stylebox("normal").get_instance_id() == theme_style_id
		and app._mode_buttons[0].get_theme_stylebox("normal").get_instance_id() == mode_style_id,
		"Ordinary gameplay refreshes reuse unchanged theme styles")
	app.choose_mode("pop")
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	check(app._pop.is_visible_in_tree(), "Voice Pop shows its speaking game")
	app.choose_mode("memory")
	check(app._memory.is_visible_in_tree() and app._memory.memory.cards.size() == 10
		and app.find_child("MemoryProgress", true, false) == null and app.find_child("MemoryMistakes", true, false) == null,
		"Memory retains its five-pair board without creating progress or mistake counters")
	app.choose_mode("match")
	check(app.grid.is_visible_in_tree(), "Returning to Match restores its board")
	check(has_property(app, "collection_button") and app.collection_button != null,
		"The rewards collection is directly available")
	check(has_property(app, "collection_page") and app.collection_page != null,
		"The rewards collection has an in-game page")
	var collection_scroll := collection_scroll(app)
	check(collection_scroll != null, "The vocabulary catalog has a native viewport")
	if collection_scroll != null:
		check(collection_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
			and collection_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
			"The catalog scrolls vertically without visible scrollbar chrome")
	check(app._stage.find_children("*", "ProgressBar", true, false).is_empty(),
		"Chest charging uses shake feedback without a progress bar")
	if app.has_method("_show_collection"):
		app.collection_button.grab_focus()
		app._show_collection()
		check(app._collection_back.has_focus() if has_property(app, "_collection_back") else false,
			"Opening rewards moves keyboard focus to Back")
		check(has_property(app, "_status_announcement") and app._status_announcement.begins_with(app.growth.snapshot().label + " · "),
			"Opening growth announces the current learning level")
		check(app.collection_button.focus_mode == Control.FOCUS_NONE,
			"Opening rewards removes underlying controls from keyboard focus")
		check(app.theme_buttons.all(func(button: Button) -> bool: return button.is_visible_in_tree())
			or app._compact_world.is_visible_in_tree(),
			"Opening growth exposes the world rail or its compact cycling control")
		var original_theme: String = app.model.theme_id
		app.choose_theme("ocean")
		check(app._age_catalog._palette.id == "ocean",
			"Choosing a world refreshes the visible word catalog immediately")
		app.choose_theme(original_theme)
		if app.has_method("_hide_collection"):
			app._hide_collection()
		else:
			app.collection_page.hide()
		check(app.collection_button.focus_mode == Control.FOCUS_ALL,
			"Closing rewards restores underlying keyboard focus")
	set_completed_rewards(app, {"spring-1": true})
	app._show_collection()
	var mastery_before: Dictionary = app.growth.snapshot().streaks.duplicate()
	app.set_reduced_motion(true)
	check(app.collection_button.focus_mode == Control.FOCUS_NONE
		and app._focus_candidates().all(func(control: Control) -> bool: return app.collection_page.is_ancestor_of(control)),
		"Restyling preserves the growth page's keyboard focus boundary")
	var catalog_word: Button = app._age_catalog.word_buttons[0]
	catalog_word.grab_focus()
	await process_frame
	await process_frame
	var catalog_focus_target: Control = catalog_word.get_meta("word_label") if catalog_word.size.y > collection_scroll.size.y else catalog_word
	check(catalog_word.has_focus() and collection_scroll.get_global_rect().grow(1).encloses(catalog_focus_target.get_global_rect()),
		"Keyboard focus reveals the vocabulary card or its caption in a short viewport")
	check(app.growth.snapshot().streaks == mastery_before, "Browsing and focus cannot change mastery")
	app.on_page_hidden()
	check(not collection_scroll.is_scrolling()
		and app._collection_rails().all(func(rail: Control) -> bool: return not rail.is_scrolling()),
		"Hiding the page cancels catalog and growth-rail contact state")
	app.on_page_visible()
	app.set_reduced_motion(false)
	app._hide_collection()
	check(app._stage.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW, "Chest effects respect the rounded panel mask")
	check(is_equal_approx(app.feedback_timer.wait_time, 0.7), "Manual and voice feedback advance after 700ms")
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
		check(app.grid.columns in [2, 5] and (dimensions_value.x < dimensions_value.y or app.grid.columns == 5),
			"Grid adapts to the visible instructions and available playfield: " + str(dimensions_value))
		var controls: Array = app.cards.values()
		if has_property(app, "theme_buttons"):
			controls.append_array(app.theme_buttons.filter(func(button: Button) -> bool: return button.is_visible_in_tree()))
		if has_property(app, "collection_button"):
			controls.append(app.collection_button)
		if has_property(app, "hint_button"):
			controls.append(app.hint_button)
		for control in controls:
			var bounds: Rect2 = control.get_global_rect()
			check(viewport.grow(0.5).encloses(bounds), "Control fits " + str(dimensions_value) + ": " + control.name)
			var pixel_size: Vector2 = bounds.size * pixels_per_unit
			var minimum_pixels: float = 44.0 if control in [app.collection_button, app.hint_button] else 48.0
			check(pixel_size.x >= minimum_pixels - 0.1 and pixel_size.y >= minimum_pixels - 0.1,
				"Touch target is at least %dpx: %s %s" % [minimum_pixels, control.name, pixel_size])
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
	app._advance_ui(0.5)
	await process_frame
	check(root.gui_get_focus_owner() == focus_before_axis, "Left stick deadzone does not move focus")
	joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await process_frame
	var focus_after_axis: Control = root.gui_get_focus_owner()
	check(focus_after_axis != null and focus_after_axis != focus_before_axis, "Left stick moves focus once past the deadzone")
	app._advance_ui(0.05)
	await process_frame
	check(root.gui_get_focus_owner() == focus_after_axis, "Left stick repeat waits instead of jumping every frame")
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	await process_frame
	app.cards[controller_first].grab_focus()
	joy_button(JOY_BUTTON_DPAD_DOWN, true)
	await process_frame
	var dpad_first_focus: Control = root.gui_get_focus_owner()
	app._advance_ui(0.4)
	check(root.gui_get_focus_owner() != dpad_first_focus,
		"Holding the D-pad repeats navigation after the initial delay")
	joy_button(JOY_BUTTON_DPAD_DOWN, false)
	await process_frame
	var dpad_released_focus: Control = root.gui_get_focus_owner()
	app._advance_ui(0.5)
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
	check(app._status_announcement.begins_with(app.growth.snapshot().label + " · "),
		"Changing motion preference preserves the collection announcement")
	app.set_reduced_motion(false)
	joy_tap(JOY_BUTTON_B)
	await process_frame
	check(not app.collection_page.visible and app.model.cards == cards_before_controller,
		"Controller B closes My Rewards and preserves the active round")
	# This fixture exercises an earned chest; chance outcomes have separate coverage.
	app.model.chest_earned = true
	var first_pair: Array = pairs_for(app.model)[0]
	app.cards[first_pair[1]].grab_focus()
	app.cards[first_pair[0]].pressed.emit()
	app.cards[first_pair[1]].pressed.emit()
	check(app.cards[first_pair[0]].scale == Vector2.ONE and app.cards[first_pair[1]].scale == Vector2.ONE,
		"Matching cards keep their scale while local badges celebrate the answer")
	check(app.model.matched_ids.size() == 2, "A match records its actual cards")
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
		check(not app.feedback_timer.is_stopped() and app.model.phase == "feedback"
			and not app._message.is_visible_in_tree(), "Match feedback stays on the board until its automatic transition")
		app.feedback_timer.timeout.emit()
	check(app.model.phase == "won", "The native button/timer wiring can win a round")
	preload("res://tests/godot/player_flow_fixture.gd").finish_celebration(app)
	await process_frame
	await process_frame
	check(app.chest_button.has_focus(), "Controller focus moves to the chest after winning")
	for season in ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]:
		app.choose_theme(season)
		await process_frame
		check(app.chest.theme_id == season, "Closed chest follows selected season")
		var chest_style: String = app.data.theme(season).chest
		var expected_pieces: int = 9 if chest_style == "crystal" else 5 if chest_style in ["royal", "energy"] else 1
		var live: Dictionary = app.chest.hold_effect_snapshot().get("live_model", {})
		check(app.chest.piece_count() == expected_pieces
			and (expected_pieces > 1 or (not live.is_empty() and live.mesh_count > 0 and not live.parts.is_empty())),
			"Chest uses the complete imported assembly, physical rig or live animated model")
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
	app._advance_ui(0.4)
	Input.joy_connection_changed.emit(0, false)
	check(not app._holding_chest and not app._controller_holding_chest,
		"Disconnecting the controller cancels its incomplete chest charge")
	joy_button(JOY_BUTTON_A, false)
	joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await process_frame
	app.on_page_hidden()
	check(app._controller_last_direction == Vector2.ZERO and app._controller_stick == Vector2.ZERO,
		"Hiding the page stops controller navigation until another input")
	app.on_page_visible()
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	await process_frame
	app.set_reduced_motion(true)
	app.chest_button.button_down.emit()
	if app.has_method("_process"):
		app._advance_ui(0.5)
	app.chest_button.button_up.emit()
	check(app.model.chest_state == "closed", "A short chest press does not open it")
	app.chest_button.button_down.emit()
	if app.has_method("_process"):
		app._advance_ui(1.21)
	app.chest_button.button_up.emit()
	await process_frame
	check(app.model.chest_state == "opened", "A completed hold reveals the reduced-motion reward")
	check(not app.chest.hold_effect_snapshot().animated
		and is_zero_approx(app.chest.hold_effect_snapshot().release_flash),
		"Reduced motion completes without chest particles or a release flash")
	check(not app.model.reward_id.is_empty(), "Opening selects a seasonal reward variant")
	check(app.collected_rewards.has(app.model.reward_id) if has_property(app, "collected_rewards") else false,
		"Opened rewards are recorded in the collection")
	check_no_collectible_presentation(app, "Reduced motion does not reveal collectible artwork or a flight")
	check(app.collection_button.scale == Vector2.ONE, "Reduced motion does not bounce the rewards button")
	app.choose_theme("winter")
	check(app.model.reward_theme == "spring" and app.chest.theme_id == "spring", "Earned chest remains spring")
	check(app.chest.visible and app.chest.mode == "opened", "Opening keeps the earned chest visible")
	app.new_round(81)
	check(app.audio.muted, "An internal fixture reset preserves mute")
	check(app.model.chest_state == "closed" and app.chest.mode == "closed"
		and not app.chest.hold_effect_snapshot().active,
		"An internal fixture reset clears the reward and chest performance")
	check(app.feedback_timer.is_stopped(), "An internal fixture reset cancels the feedback timer")
	app.set_reduced_motion(false)
	win_round(app)
	prepare_completion(app)
	app.chest_button.grab_focus()
	joy_button(JOY_BUTTON_A, true)
	await process_frame
	if app.has_method("_process"):
		app._advance_ui(1.21)
	await process_frame
	check(app.model.chest_state == "opening", "Normal opening is staged, not immediate")
	check(app.theme_buttons.all(func(button: Button) -> bool: return button.disabled) if has_property(app, "theme_buttons") else false,
		"Opening disables theme selection")
	var locked_theme: String = app.model.theme_id
	joy_tap(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	check(app.model.theme_id == locked_theme, "Controller shoulder season changes are disabled while the chest opens")
	check(is_zero_approx(app.chest.hold_effect_snapshot().release_flash),
		"Opening anticipation waits for the physical release beat")
	app.chest._advance_animation(app.chest.Feel.RELEASE_TIME + 0.01)
	check(app.chest.hold_effect_snapshot().release_flash > 0.0,
		"The lid release lights the chest without a separate collectible celebration")
	check_no_collectible_presentation(app, "The opening chest has no collectible artwork or flight")
	var opened_reward_id: String = app.model.reward_id
	var reward_count_before: int = app.collected_rewards.size()
	var was_collected: bool = app.collected_rewards.has(opened_reward_id)
	app.chest.finish_immediately()
	joy_button(JOY_BUTTON_A, false)
	check(app.model.chest_state == "opened", "The native animation completes the reward")
	check(app.collected_rewards.has(opened_reward_id), "The opened reward is recorded before visual delivery")
	check(app.collected_rewards.size() == reward_count_before + (0 if was_collected else 1),
		"The reward collection changes exactly once when opening finishes")
	check_no_collectible_presentation(app, "A saved chest completes without a collectible pop or flight")
	root.size = Vector2i(390, 844)
	app.choose_theme("winter")
	for frame in range(6):
		await process_frame
	check_no_collectible_presentation(app, "Later frames and a world change cannot reveal a delayed collectible")
	check(app.model.reward_id == opened_reward_id and app.collection_button.scale == Vector2.ONE,
		"World changes preserve the saved reward without bouncing the room button")
	check(app.collected_rewards.size() == reward_count_before + (0 if was_collected else 1),
		"Presentation changes do not duplicate the saved collection entry")
	app.new_round(90)
	check_no_collectible_presentation(app, "Starting a new round leaves no reward flight behind")
	win_round(app)
	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	app._chest_input(drag_press)
	var edge_drag := InputEventMouseMotion.new()
	edge_drag.position = Vector2(10000, 10000)
	edge_drag.relative = edge_drag.position
	edge_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	app._chest_input(edge_drag)
	check(not app._holding_chest and app.chest.drag_offset != Vector2.ZERO,
		"A real chest drag cancels the hold and moves the closed chest")
	drag_press.pressed = false
	app._chest_input(drag_press)
	root.size = Vector2i(844, 390)
	await process_frame
	await process_frame
	var chest_rect := Rect2(
		app.chest._art.position + app.chest._bounds.position * app.chest._art.scale,
		app.chest._bounds.size * app.chest._art.scale
	)
	check(Rect2(Vector2.ZERO, app.chest.size).grow(0.5).encloses(chest_rect),
		"Chest dragging stays inside its canvas after resizing")
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
		app._advance_ui(1.21)
	app.on_page_hidden()
	check(app.model.chest_state == "closed" and app._pending_fragment.is_empty(),
		"Hiding cancels an incomplete opening and preserves the earned closed chest")
	check(not app.chest.hold_effect_snapshot().active
		and is_zero_approx(app.chest.hold_effect_snapshot().release_flash),
		"Hiding during opening clears the chest's charge and flash")
	check_no_collectible_presentation(app, "Background cancellation has no collectible artwork or queued flight")
	app.on_page_visible()
	app.new_round(91)
	win_round(app)
	prepare_completion(app)
	app.chest_button.button_down.emit()
	if app.has_method("_process"):
		app._advance_ui(1.21)
	app.chest.finish_immediately()
	app.chest_button.button_up.emit()
	check_no_collectible_presentation(app, "A completed chest has no collectible delivery before visiting the growth notebook")
	app._show_collection()
	check_no_collectible_presentation(app, "Opening the growth notebook cannot reveal a hidden collectible flight")
	check(app.collection_button.scale == Vector2.ONE, "Opening the growth notebook keeps its entry at its normal scale")
	app._hide_collection()
	app.new_round(91)
	win_round(app)
	prepare_completion(app)
	app.chest_button.button_down.emit()
	if app.has_method("_process"):
		app._advance_ui(1.21)
	app.chest.finish_immediately()
	app.chest_button.button_up.emit()
	check_no_collectible_presentation(app, "A completed chest has no collectible delivery to delay another adventure")
	var lesson_before_adventure: Array = app.model.lesson_words.duplicate(true)
	var saved_before_adventure: Dictionary = app.medal_progress.counts.duplicate()
	app._new_adventure_button.pressed.emit()
	check_no_collectible_presentation(app, "New adventure does not carry over collectible artwork")
	check(app.collection_button.scale == Vector2.ONE, "New adventure preserves the room entry's normal scale")
	check(app._mode_id == "match" and app.model.lesson_words != lesson_before_adventure
		and app.medal_progress.counts == saved_before_adventure,
		"The visible result action starts a fresh Match board without duplicating the delivered reward")
	app.choose_mode("match")
	var wrong: Array = wrong_pair_for(app.model)
	var wrong_start: Vector2 = app.cards[wrong[0]].position
	app.cards[wrong[0]].pressed.emit()
	app.cards[wrong[1]].pressed.emit()
	check(app.cards[wrong[0]].rotation == 0.0 and app.cards[wrong[0]].position == wrong_start,
		"Wrong cards keep their position and use color feedback instead of shaking")
	app.feedback_timer.timeout.emit()
	var retry_cards: Array = app.model.cards.duplicate(true)
	for count in range(6):
		app.cards[wrong[0]].pressed.emit()
		app.cards[wrong[1]].pressed.emit()
		app.feedback_timer.timeout.emit()
	check(app.model.phase == "waiting" and app.model.mistakes == 7 and app.model.cards == retry_cards
		and app.grid.is_visible_in_tree() and not app._outcome.is_visible_in_tree(),
		"Seven incorrect pairs retain the original active board")
	check(not has_property(app, "failure_button") and not has_property(app, "failure_image")
		and not app.has_method("_play_loss_bear"), "Retired Match failure controls and behavior are removed")
	win_round(app)
	check(app.model.phase == "won" and app.model.matched_ids.size() == app.model.cards.size(),
		"The same board completes normally after seven mistakes")
	app.new_round(92)
	var first: String = app.model.cards[0].id
	app.cards[first].pressed.emit()
	var second: String = wrong_pair_for(app.model)[0]
	app.on_page_hidden()
	check(not app.audio.active, "Hiding pauses audio until another gesture")
	check(app._feedback_tweens.is_empty() and app._feedback_sparkles.is_empty(),
		"Hiding clears transient match effects")
	check(app.model.selected_id == first, "Hiding does not reset a selection")
	app.cards[second].pressed.emit()
	app.queue_free()
	await process_frame
	joy_button(JOY_BUTTON_A, true)
	var held_app = packed.instantiate()
	held_app.medal_progress = progress_script.new(directory + "/held.cfg", directory + "/legacy.cfg")
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
