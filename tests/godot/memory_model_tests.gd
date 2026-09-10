extends SceneTree

var checks: int = 0
var failures: int = 0
var vocabulary: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	check(FileAccess.file_exists("res://scripts/memory_game_model.gd"), "Memory has a native state model")
	if failures:
		quit(1)
		return
	var model = load("res://scripts/memory_game_model.gd").new()
	vocabulary = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	_test_layout(model)
	_test_selections(model)
	_test_feedback_and_completion(model)
	_test_study_and_stop(model)
	_test_rejected_resets(model)
	print("Memory model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _words(ids: Array = ["cat", "dog", "sun", "ball", "car"]) -> Array:
	var result: Array = []
	for id in ids:
		for word in vocabulary:
			if word.id == id:
				result.append(word.duplicate(true))
	return result


func _index(model, word_id: String, kind: String) -> int:
	for index in range(model.cards.size()):
		if model.cards[index].word.id == word_id and model.cards[index].kind == kind:
			return index
	return -1


func _snapshot(model) -> Dictionary:
	return {"cards": model.cards.duplicate(true), "selected": model.selected_indices.duplicate(),
		"matched": model.matched_word_ids.duplicate(), "feedback": model.feedback_words.duplicate(true),
		"attempts": model.attempts, "mistakes": model.mistakes, "last_correct": model.last_correct,
		"phase": model.phase, "studying": model.studying}


func _pair(model, id: String) -> void:
	check(model.select(_index(model, id, "word")) == "selected", "An unmatched word starts a pair")
	check(model.select(_index(model, id, "image")) == "correct", "Its picture completes the correct pair")


func _test_layout(model) -> void:
	check(model.select(0) == "ignored" and not model.set_study(true), "An empty model cannot reveal cards")
	var input: Array = _words()
	check(model.reset(input, 71), "Exactly five safe words start Memory")
	check(model.cards.size() == 10 and model.phase == "waiting" and model.attempts == 0
		and model.mistakes == 0 and model.matched_word_ids.is_empty(), "A round starts with ten cards and no score")
	var first: Array = model.cards.duplicate(true)
	var layouts: Dictionary = {}
	for seed_value in range(16):
		check(model.reset(input, seed_value), "Seeded rounds accept the complete lesson")
		var card_ids: Array = []
		for word in input:
			check(_index(model, word.id, "word") >= 0 and _index(model, word.id, "image") >= 0,
				"Every lesson word appears once as text and once as a picture")
		for index in range(10):
			var card: Dictionary = model.cards[index]
			check(not card_ids.has(card.id) and card.id == card.word.id + ":" + card.kind,
				"Cards have unique stable word-kind identifiers")
			card_ids.append(card.id)
			check(not model.is_revealed(index), "A new board hides every answer")
		layouts[str(card_ids)] = true
	check(layouts.size() > 1, "Different seeds vary card positions")
	model.reset(input, 71)
	check(model.cards == first, "A seed reproduces the same board regardless of previous rounds")
	input[0].text = "mutated"
	input[0].image = "changed.png"
	input.clear()
	check(model.cards == first, "Caller mutations cannot change the live board")
	check(not model.is_revealed(-1) and not model.is_revealed(10), "Out-of-range visibility reads are safe")


func _test_selections(model) -> void:
	model.reset(_words(), 17)
	var board: Array = model.cards.duplicate(true)
	var cat: int = _index(model, "cat", "word")
	var dog: int = _index(model, "dog", "word")
	check(model.continue_feedback() == "ignored", "Continue cannot skip an unfinished pair")
	check(model.select(cat) == "selected" and model.phase == "matching", "The first card begins an attempt")
	check(model.selected_indices == [cat] and model.is_revealed(cat), "Only the first selected answer is revealed")
	var selected: Dictionary = _snapshot(model)
	check(model.select(-1) == "ignored" and model.select(10) == "ignored"
		and _snapshot(model) == selected, "Invalid indexes cannot cancel or change a selection")
	check(model.select(dog) == "reselected" and model.selected_indices == [dog]
		and not model.is_revealed(cat) and model.is_revealed(dog), "Same-kind selection swaps the reveal without an attempt")
	check(model.attempts == 0 and model.mistakes == 0, "Browsing cards of one kind does not score")
	check(model.select(dog) == "cancelled" and model.phase == "waiting"
		and model.selected_indices.is_empty() and not model.is_revealed(dog), "Selecting the same first card cancels it")
	var picture: int = _index(model, "cat", "image")
	check(model.select(picture) == "selected" and model.select(cat) == "correct", "Pairs can start with the picture")
	check(model.cards == board, "Reveals and reselection never move cards")


func _test_feedback_and_completion(model) -> void:
	model.reset(_words(), 23)
	var board: Array = model.cards.duplicate(true)
	var cat: int = _index(model, "cat", "word")
	var dog_picture: int = _index(model, "dog", "image")
	for attempt in range(7):
		model.select(cat)
		check(model.select(dog_picture) == "wrong" and model.phase == "feedback"
			and model.attempts == attempt + 1 and model.mistakes == attempt + 1,
			"Each mismatched word-picture pair counts one exploration attempt")
		check(model.feedback_words == _words(["cat", "dog"]) and not model.last_correct,
			"Mismatch feedback supplies both real word-picture associations")
		check(model.selected_indices == [cat, dog_picture] and model.is_revealed(cat)
			and model.is_revealed(dog_picture), "The mismatch remains visible until explicit Continue")
		var feedback: Dictionary = _snapshot(model)
		check(model.select(dog_picture) == "ignored" and model.select(_index(model, "sun", "word")) == "ignored"
			and not model.set_study(true) and _snapshot(model) == feedback, "Feedback rejects duplicate taps and Study")
		check(model.continue_feedback() == "ready" and model.phase == "waiting"
			and model.selected_indices.is_empty() and model.feedback_words.is_empty()
			and not model.is_revealed(cat) and not model.is_revealed(dog_picture),
			"Continue hides only the mismatched pair without ending the round")
		check(model.continue_feedback() == "ignored" and model.cards == board
			and model.matched_word_ids.is_empty(), "Repeated Continue neither scores nor moves the board")
	var matched: Array[String] = []
	for id in ["cat", "dog", "sun", "ball", "car"]:
		_pair(model, id)
		matched.append(id)
		check(model.phase == "feedback" and model.matched_word_ids == matched
			and model.feedback_words == _words([id]) and model.last_correct,
			"Correct pairs are recorded immediately while teaching feedback remains explicit")
		check(model.attempts == 7 + matched.size() and model.mistakes == 7, "Correct exploration retains earlier attempts")
		var feedback: Dictionary = _snapshot(model)
		check(model.select(_index(model, id, "image")) == "ignored" and _snapshot(model) == feedback,
			"A repeated submitted card cannot award the same pair twice")
		var result: String = model.continue_feedback()
		check(result == ("won" if matched.size() == 5 else "ready"), "Only final Continue reports the win")
		for found in matched:
			check(model.is_revealed(_index(model, found, "word"))
				and model.is_revealed(_index(model, found, "image")), "Planted pairs stay visible after feedback")
		check(model.select(_index(model, id, "word")) == "ignored", "Completed pairs cannot be selected again")
	check(model.phase == "won" and model.cards == board, "All five fixed pairs complete the garden despite seven mistakes")
	var won: Dictionary = _snapshot(model)
	check(model.continue_feedback() == "ignored" and model.select(0) == "ignored"
		and not model.set_study(true) and _snapshot(model) == won, "Won rounds reject delayed input and duplicate victory")


func _test_study_and_stop(model) -> void:
	model.reset(_words(), 29)
	_pair(model, "cat")
	model.continue_feedback()
	model.select(_index(model, "dog", "word"))
	var board: Array = model.cards.duplicate(true)
	check(model.set_study(true) and model.studying and model.phase == "waiting"
		and model.selected_indices.is_empty(), "Study cancels an unfinished first selection")
	for index in range(10):
		check(model.is_revealed(index), "Study exposes this same complete board")
	var studying: Dictionary = _snapshot(model)
	check(not model.set_study(true) and model.select(0) == "ignored"
		and model.continue_feedback() == "ignored" and _snapshot(model) == studying,
		"Study rejects scoring input and repeated Study activation")
	check(model.set_study(false) and not model.studying and model.attempts == 1
		and model.mistakes == 0 and model.matched_word_ids == ["cat"] and model.cards == board,
		"Returning from Study retains progress and positions without scoring")
	for index in range(10):
		check(model.is_revealed(index) == (model.cards[index].word.id == "cat"),
			"Returning to play hides only unmatched cards")
	check(not model.set_study(false), "Repeated return to play is a no-op")
	_pair(model, "dog")
	model.stop()
	check(model.phase == "stopped" and not model.studying and model.selected_indices.is_empty()
		and model.feedback_words.is_empty(), "Stop discards transient feedback without a result")
	var stopped: Dictionary = _snapshot(model)
	model.stop()
	check(model.select(0) == "ignored" and model.continue_feedback() == "ignored"
		and not model.set_study(true) and not model.set_study(false) and _snapshot(model) == stopped,
		"Stopped rounds reject delayed controls and repeated Stop is idempotent")
	check(model.reset(_words(), 29) and model.attempts == 0 and model.matched_word_ids.is_empty()
		and model.cards == board and not model.last_correct, "Reset after stopping produces a clean playable round")
	model.set_study(true)
	model.stop()
	check(not model.studying and not model.is_revealed(0), "Stopping a Study session clears its global reveal")


func _test_rejected_resets(model) -> void:
	model.reset(_words(), 42)
	_pair(model, "cat")
	var before: Dictionary = _snapshot(model)
	var invalid: Array = [[], _words().slice(0, 4), _words() + _words(["apple"])]
	for replacement in [null, "cat", 3, {}, {"id": "cat"}]:
		var candidate: Array = _words()
		candidate[0] = replacement
		invalid.append(candidate)
	for field in ["id", "text", "image", "audio"]:
		var missing: Array = _words()
		missing[0].erase(field)
		invalid.append(missing)
		for value in [null, 17, ""]:
			var wrong_type: Array = _words()
			wrong_type[0][field] = value
			invalid.append(wrong_type)
	for field in ["id", "text", "image"]:
		var duplicate: Array = _words()
		duplicate[1][field] = duplicate[0][field]
		invalid.append(duplicate)
	for changes in [{"id": "../cat"}, {"text": "Cat"},
		{"image": "https://example.com/cat.png"}, {"image": "assets/images/words/../cat.png"},
		{"image": "assets/imported-unity/dog.png"}, {"audio": "assets/audio/voice/../secret.wav"}]:
		var unsafe: Array = _words()
		unsafe[0].merge(changes, true)
		invalid.append(unsafe)
	for pair in [["earth", "planet"], ["acorn", "seed"], ["boot", "shoe"],
		["shell", "clam"], ["flower", "rose"], ["comet", "meteor"]]:
		invalid.append(_words(pair + ["cat", "dog", "ball"]))
	var aliases: Array = _words(["earth", "planet", "cat", "dog", "ball"])
	aliases[0].id = "our-earth"
	aliases[1].id = "our-planet"
	invalid.append(aliases)
	for candidate in invalid:
		check(not model.reset(candidate, 99) and not model.error.is_empty(), "Malformed or confusable lessons are rejected")
		check(_snapshot(model) == before, "Rejected resets preserve the live board, score and feedback atomically")
	var imported: Array = _words()
	imported[0].image = "assets/imported-unity/cat.png"
	check(model.reset(imported, 42) and model.error.is_empty(), "Known runtime word-art overrides remain valid")
	check(model.cards[_index(model, "cat", "image")].word.image == imported[0].image,
		"Validation preserves the actual imported picture path for rendering")
