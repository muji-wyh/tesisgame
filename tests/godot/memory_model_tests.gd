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
	_test_start_gate(model)
	_test_selections(model)
	_test_feedback_and_completion(model)
	_test_matched_visibility(model)
	_test_study_and_stop(model)
	_test_peek_prices(model)
	_test_peek_countdown(model)
	_test_rejected_resets(model)
	_test_runtime_library(model)
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
		"phase": model.phase, "started": model.started, "studying": model.studying, "peeks": model.peeks,
		"peek_remaining": model.peek_remaining, "peek_duration": model.peek_duration}


func _pair(model, id: String) -> void:
	check(model.select(_index(model, id, "word")) == "selected", "An unmatched word starts a pair")
	check(model.select(_index(model, id, "image")) == "correct", "Its picture completes the correct pair")


func _start_matching(model) -> void:
	check(model.start_game() and model.started and model.studying, "Start game enters the free observation exactly once")
	check(model.set_study(false), "Start matching ends the initial observation")


func _test_start_gate(model) -> void:
	model.reset(_words(), 71)
	var waiting: Dictionary = _snapshot(model)
	check(not model.started and model.reward_tier() == 6, "A prepared round waits for Start game with the highest tier available")
	check(model.select(0) == "ignored" and not model.set_study(true) and _snapshot(model) == waiting,
		"Cards and the paid eye cannot bypass Start game")
	check(model.start_game() and model.started and model.studying and model.peeks == 1
		and model.peek_duration == 10.0 and model.peek_remaining == 10.0,
		"Start game starts exactly one free ten-second observation")
	var observing: Dictionary = _snapshot(model)
	check(not model.start_game() and model.select(0) == "ignored" and not model.set_study(true)
		and _snapshot(model) == observing, "Repeated Start and observation taps cannot change the clock or score")
	check(model.advance_peek(10.0) and model.started and not model.studying and model.phase == "waiting",
		"Observation expiry enters matching without restarting the round")
	check(not model.start_game() and model.peeks == 1 and model.peek_price() == 100,
		"The initial free observation cannot be replayed")


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
	_start_matching(model)
	var board: Array = model.cards.duplicate(true)
	var cat: int = _index(model, "cat", "word")
	var dog: int = _index(model, "dog", "word")
	check(model.continue_feedback() == "ignored", "Continue cannot skip an unfinished pair")
	check(model.select(cat) == "selected" and model.phase == "matching", "The first card begins an attempt")
	check(model.selected_indices == [cat] and not model.is_revealed(cat), "The first selection keeps its answer concealed")
	var selected: Dictionary = _snapshot(model)
	check(model.select(-1) == "ignored" and model.select(10) == "ignored"
		and _snapshot(model) == selected, "Invalid indexes cannot cancel or change a selection")
	check(model.select(dog) == "selected" and model.selected_indices == [dog]
		and not model.is_revealed(cat) and not model.is_revealed(dog), "A second word replaces the concealed first choice without forming a pair")
	check(model.phase == "matching" and model.attempts == 0 and model.mistakes == 0 and model.reward_tier() == 6
		and model.feedback_words.is_empty(), "Changing a word selection cannot score, publish evidence, or lower the chest")
	check(model.select(dog) == "cancelled" and model.phase == "waiting"
		and model.selected_indices.is_empty() and not model.is_revealed(dog), "Selecting the same first card cancels it")
	var picture: int = _index(model, "cat", "image")
	var other_picture: int = _index(model, "dog", "image")
	check(model.select(picture) == "selected" and model.select(other_picture) == "selected"
		and model.selected_indices == [other_picture] and model.attempts == 0 and model.mistakes == 0
		and not model.is_revealed(picture) and not model.is_revealed(other_picture),
		"Two pictures also replace the first choice without revealing either or recording a miss")
	check(model.select(picture) == "selected" and model.select(cat) == "correct"
		and model.attempts == 1 and model.mistakes == 0, "A real pair can start with the most recently selected picture")
	check(model.cards == board, "Selection, cancellation and pair reveal never move cards")


func _test_feedback_and_completion(model) -> void:
	model.reset(_words(), 23)
	_start_matching(model)
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
		check(model.reward_tier() == maxi(0, 5 - attempt), "Each mistake lowers reward tier by one, bounded at zero")
		check(model.selected_indices == [cat, dog_picture] and model.is_revealed(cat)
			and model.is_revealed(dog_picture), "The mismatch remains visible until feedback is resolved")
		var feedback: Dictionary = _snapshot(model)
		check(model.select(dog_picture) == "ignored" and model.select(_index(model, "sun", "word")) == "ignored"
			and not model.set_study(true) and _snapshot(model) == feedback, "Feedback rejects duplicate taps and Study")
		check(model.continue_feedback() == "ready" and model.phase == "waiting"
			and model.selected_indices.is_empty() and model.feedback_words.is_empty()
			and not model.is_revealed(cat) and not model.is_revealed(dog_picture),
			"Resolving feedback hides the mismatched pair without ending the round")
		check(model.continue_feedback() == "ignored" and model.cards == board
			and model.matched_word_ids.is_empty(), "Repeated Continue neither scores nor moves the board")
	var matched: Array[String] = []
	for id in ["cat", "dog", "sun", "ball", "car"]:
		_pair(model, id)
		matched.append(id)
		check(model.phase == "feedback" and model.matched_word_ids == matched
			and model.feedback_words == _words([id]) and model.last_correct,
			"Correct pairs are recorded immediately while their feedback is visible")
		check(model.attempts == 7 + matched.size() and model.mistakes == 7, "Correct exploration retains earlier attempts")
		var feedback: Dictionary = _snapshot(model)
		check(model.select(_index(model, id, "image")) == "ignored" and _snapshot(model) == feedback,
			"A repeated submitted card cannot award the same pair twice")
		var result: String = model.continue_feedback()
		check(result == ("won" if matched.size() == 5 else "ready"), "Only resolving final feedback reports the win")
		for index in range(model.cards.size()):
			check(model.is_revealed(index) == matched.has(model.cards[index].word.id),
				"After correct feedback only planted pairs remain face up, including every card at completion")
		check(model.matched_word_ids == matched and model.attempts == 7 + matched.size(),
			"Keeping planted faces visible leaves all scored progress intact")
		check(model.select(_index(model, id, "word")) == "ignored", "Completed pairs cannot be selected again")
	check(model.phase == "won" and model.cards == board, "All five fixed pairs complete the garden despite seven mistakes")
	var won: Dictionary = _snapshot(model)
	check(model.continue_feedback() == "ignored" and model.select(0) == "ignored"
		and not model.set_study(true) and _snapshot(model) == won, "Won rounds reject delayed input and duplicate victory")


func _test_matched_visibility(model) -> void:
	model.reset(_words(), 31)
	_start_matching(model)
	_pair(model, "cat")
	model.continue_feedback()
	var board: Array = model.cards.duplicate(true)
	model.select(_index(model, "dog", "word"))
	check(model.select(_index(model, "sun", "image")) == "wrong", "An unmatched pair can fail after an earlier success")
	check(model.is_revealed(_index(model, "cat", "word")) and model.is_revealed(_index(model, "cat", "image")),
		"A later mismatch keeps the previously planted word and picture visible during feedback")
	check(model.continue_feedback() == "ready", "A later mismatch returns the partial garden to play")
	for index in range(model.cards.size()):
		check(model.is_revealed(index) == (model.cards[index].word.id == "cat"),
			"Wrong feedback hides its failed pair and untouched cards while the planted pair stays face up")
	check(model.matched_word_ids == ["cat"] and model.attempts == 2 and model.mistakes == 1 and model.cards == board,
		"Later wrong feedback preserves the planted pair, score and fixed positions")


func _test_study_and_stop(model) -> void:
	model.reset(_words(), 29)
	_start_matching(model)
	_pair(model, "cat")
	model.continue_feedback()
	model.select(_index(model, "dog", "word"))
	var board: Array = model.cards.duplicate(true)
	check(model.set_study(true) and model.studying and model.phase == "waiting"
		and model.selected_indices.is_empty(), "Beginning a peek cancels an unfinished first selection")
	for index in range(10):
		check(model.is_revealed(index), "An active peek exposes every front, including planted pairs")
	var studying: Dictionary = _snapshot(model)
	check(not model.set_study(true) and model.select(0) == "ignored"
		and model.continue_feedback() == "ignored" and _snapshot(model) == studying,
		"An active peek rejects scoring input and repeated activation")
	check(model.set_study(false) and not model.studying and model.attempts == 1
		and model.mistakes == 0 and model.matched_word_ids == ["cat"] and model.cards == board,
		"Ending a peek retains progress and positions without scoring")
	for index in range(10):
		check(model.is_revealed(index) == (model.cards[index].word.id == "cat"),
			"Ending a peek keeps planted faces visible and hides every unmatched card")
	check(not model.set_study(false), "Repeated peek cancellation is a no-op")
	check(model.matched_word_ids == ["cat"] and model.attempts == 1,
		"Repeated cancellations preserve the matched pair and attempt count")
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
	model.start_game()
	model.stop()
	check(not model.studying and not model.is_revealed(0), "Stopping a Study session clears its global reveal")


func _test_peek_prices(model) -> void:
	model.reset(_words(), 83)
	check(model.peeks == 0 and model.peek_price() == 0, "Every Memory round starts with one free peek")
	for price: int in [0, 100, 200, 300, 300, 300]:
		check(model.peek_price() == price, "The next accepted reveal follows the capped per-round price schedule")
		var before: int = model.peeks
		check((model.start_game() if before == 0 else model.set_study(true)) and model.peeks == before + 1,
			"Only a newly accepted reveal increments the per-round peek count")
		check(not model.set_study(true) and model.peeks == before + 1,
			"Repeated countdown activation cannot advance the next reveal price")
		check(model.set_study(false) and not model.set_study(false) and model.peeks == before + 1,
			"Expiry or cancellation of a timed peek retains the price of the next use")
	var used: int = model.peeks
	_pair(model, "cat")
	check(not model.set_study(true) and model.peeks == used and model.peek_price() == 300,
		"Unresolved model feedback cannot silently consume another peek")
	model.stop()
	check(not model.set_study(true) and model.peeks == used, "Stopped rounds cannot consume paid reveal uses")
	check(model.reset(_words(), 84) and model.peeks == 0 and model.peek_price() == 0,
		"Starting a new game resets the reveal price to free")


func _test_peek_countdown(model) -> void:
	model.reset(_words(), 94)
	check(not model.advance_peek(20.0) and model.peek_remaining == 0.0 and model.peek_duration == 0.0,
		"An idle countdown cannot reveal cards or consume a use")
	var progress: Array = [model.cards.duplicate(true), model.matched_word_ids.duplicate(), model.attempts, model.mistakes]
	check(model.start_game() and model.peek_duration == 10.0 and model.peek_remaining == 10.0,
		"The first accepted reveal starts a full ten-second countdown")
	check(not model.advance_peek(3.0) and model.peek_remaining == 7.0 and model.studying,
		"Elapsed time reduces the active countdown while cards remain revealed")
	check(not model.set_study(true) and model.peek_remaining == 7.0 and model.peeks == 1,
		"Clicking an active reveal never refreshes its clock or consumes another use")
	for invalid_delta: float in [0.0, -1.0, NAN, INF]:
		check(not model.advance_peek(invalid_delta) and model.peek_remaining == 7.0 and model.studying,
			"Invalid elapsed time cannot extend, poison, or expire the reveal")
	check(not model.advance_peek(6.99) and model.studying and model.peek_remaining > 0.0,
		"The first reveal remains available until its actual deadline")
	check(model.advance_peek(0.02) and not model.studying and model.peek_remaining == 0.0,
		"Crossing the deadline automatically conceals unmatched cards")
	check(not model.advance_peek(1.0) and model.peeks == 1,
		"Expiry reports once and further elapsed time cannot consume another use")
	for index in range(model.cards.size()):
		check(not model.is_revealed(index), "Initial observation expiry conceals every answer")
	check([model.cards, model.matched_word_ids, model.attempts, model.mistakes] == progress,
		"A timed reveal never changes board positions or earned progress")
	_pair(model, "cat")
	model.continue_feedback()
	for attempt in range(3):
		check(model.set_study(true) and model.peek_duration == 5.0 and model.peek_remaining == 5.0,
			"Every later accepted reveal starts five seconds, including uses after expiry")
		check(model.advance_peek(5.0) and not model.studying and model.peek_remaining == 0.0,
			"Exactly five elapsed seconds closes a later reveal")
		check(model.is_revealed(_index(model, "cat", "word")) and model.is_revealed(_index(model, "cat", "image")),
			"A later observation expiry preserves earned pair faces")
	model.set_study(true)
	model.advance_peek(1.0)
	check(model.set_study(false) and model.peek_remaining == 0.0 and model.peek_duration == 0.0,
		"Explicit cancellation clears the active timer immediately")
	model.set_study(true)
	model.stop()
	check(model.peek_remaining == 0.0 and model.peek_duration == 0.0 and not model.advance_peek(60.0),
		"Stopping discards the old countdown and rejects delayed expiry")
	model.reset(_words(), 95)
	check(model.peeks == 0 and model.peek_remaining == 0.0 and model.start_game()
		and model.peek_duration == 10.0 and model.peek_remaining == 10.0,
		"A new round restores the first free ten-second reveal")
	model.set_study(false)


func _test_rejected_resets(model) -> void:
	model.reset(_words(), 42)
	_start_matching(model)
	_pair(model, "cat")
	var before: Dictionary = _snapshot(model)
	var invalid: Array = [
		{"label": "empty lesson", "words": []},
		{"label": "four words", "words": _words().slice(0, 4)},
		{"label": "six words", "words": _words() + _words(["apple"])}
	]
	for replacement in [null, "cat", 3, {}, {"id": "cat"}]:
		var candidate: Array = _words()
		candidate[0] = replacement
		invalid.append({"label": "incomplete entry: " + JSON.stringify(replacement), "words": candidate})
	for field in ["id", "text", "image", "audio"]:
		var missing: Array = _words()
		missing[0].erase(field)
		invalid.append({"label": "missing " + field, "words": missing})
		for value in [null, 17, ""]:
			var wrong_type: Array = _words()
			wrong_type[0][field] = value
			invalid.append({"label": "invalid %s: %s" % [field, JSON.stringify(value)], "words": wrong_type})
	for field in ["id", "text", "image"]:
		var duplicate: Array = _words()
		duplicate[1][field] = duplicate[0][field]
		invalid.append({"label": "duplicate " + field, "words": duplicate})
	for changes in [{"id": "../cat"}, {"text": "cat!"},
		{"image": "https://example.com/cat.png"}, {"image": "assets/images/words/../cat.png"},
		{"image": "assets/imported-unity/dog.png"}, {"audio": "assets/audio/voice/../secret.wav"}]:
		var unsafe: Array = _words()
		unsafe[0].merge(changes, true)
		invalid.append({"label": "unsafe content: " + JSON.stringify(changes), "words": unsafe})
	for pair in [["earth", "planet"], ["acorn", "seed"], ["boot", "shoe"],
		["shell", "clam"], ["flower", "rose"], ["comet", "meteor"]]:
		invalid.append({"label": "confusable pair: " + "/".join(pair),
			"words": _words(pair + ["cat", "dog", "ball"])})
	var same_art: Array = _words()
	same_art[0].art_key = "mulberry/shared-picture.svg"
	same_art[1].art_key = same_art[0].art_key
	invalid.append({"label": "shared artwork key", "words": same_art})
	var same_meaning: Array = _words()
	same_meaning[0].confusable = [same_meaning[1].id]
	invalid.append({"label": "explicit confusable meaning", "words": same_meaning})
	var aliases: Array = _words(["earth", "planet", "cat", "dog", "ball"])
	aliases[0].id = "our-earth"
	aliases[1].id = "our-planet"
	invalid.append({"label": "confusable meaning under aliased IDs", "words": aliases})
	for index in range(invalid.size()):
		var fixture: Dictionary = invalid[index]
		var label: String = "Reset fixture %d (%s)" % [index + 1, fixture.label]
		check(not model.reset(fixture.words, 99) and not model.error.is_empty(),
			label + ": malformed or confusable lesson is rejected")
		check(_snapshot(model) == before,
			label + ": rejection preserves the live board, score and feedback atomically")
	var capitalized: Array = _words()
	capitalized[0].text = "Cat"
	check(model.reset(capitalized, 42) and model.error.is_empty(), "English word capitalization remains valid")
	check(model.cards[_index(model, "cat", "word")].word.text == "Cat",
		"Validation preserves the lesson's display capitalization")
	var imported: Array = _words()
	imported[0].image = "assets/imported-unity/cat.png"
	check(model.reset(imported, 42) and model.error.is_empty(), "Known runtime word-art overrides remain valid")
	check(model.cards[_index(model, "cat", "image")].word.image == imported[0].image,
		"Validation preserves the actual imported picture path for rendering")


func _test_runtime_library(model) -> void:
	var data = load("res://scripts/game_data.gd").new()
	var loaded: bool = data.load_all()
	check(loaded, "Memory regression uses the actual loaded production vocabulary: " + data.error)
	if not loaded:
		return
	var lesson: Array = data.words.filter(func(word: Dictionary) -> bool:
		return word.id in ["cat", "dog", "sun", "ball", "walk"])
	check(lesson.size() == 5 and lesson.all(func(word: Dictionary) -> bool:
		return word.image == "assets/images/word-library/%s.webp" % word.id),
		"The real Memory lesson includes illustration and character animation sources")
	var started: bool = model.reset(lesson, 73)
	check(started, "Memory accepts the production library paths: " + model.error)
	if not started:
		return
	check(model.cards.size() == 10 and model.cards.all(func(card: Dictionary) -> bool:
		return card.word.image == "assets/images/word-library/%s.webp" % card.word.id),
		"Both Memory card kinds preserve each word's exact runtime library path")
	var before: Dictionary = _snapshot(model)
	var word_id: String = str(lesson[0].id)
	for invalid_path in [
		"assets/images/word-library/hello.webp",
		"assets/images/word-library/../%s.webp" % word_id,
		"assets/images/word-library/nested/%s.webp" % word_id,
		"assets/images/word-library/%s.png" % word_id,
		"res://assets/images/word-library/%s.webp" % word_id,
		"assets/images/word-library\\%s.webp" % word_id
	]:
		var invalid: Array = lesson.duplicate(true)
		invalid[0].image = invalid_path
		check(not data.validate_words(invalid).is_empty(),
			"Library validation rejects mismatched IDs and noncanonical paths: " + invalid_path)
		check(not model.reset(invalid, 73) and _snapshot(model) == before,
			"An invalid library path cannot replace a live Memory round: " + invalid_path)
