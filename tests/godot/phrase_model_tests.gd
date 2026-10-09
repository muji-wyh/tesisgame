extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const PhraseData = preload("res://scripts/phrase_data.gd")
const PhraseModel = preload("res://scripts/phrase_game_model.gd")

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
	var vocabulary: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	_test_catalog(vocabulary)
	_test_rounds(vocabulary)
	_test_editing_and_completion(vocabulary)
	_test_placement(vocabulary)
	_test_invalid_input(vocabulary)
	print("Phrase model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_catalog(vocabulary: Array) -> void:
	var phrases: Array[Dictionary] = PhraseData.entries()
	check(phrases.size() == 330, "The curriculum contains 330 complete phrases")
	for age in range(3, 13):
		var eligible: Array = PhraseData.for_age(str(age))
		check(eligible.size() >= 3 and eligible.all(func(phrase: Dictionary) -> bool: return int(phrase.min_age) <= age),
			"Every age has a complete cumulative phrase pool")
	check(PhraseData.for_age("12").size() == phrases.size(), "Lv12+ exposes the complete phrase curriculum")
	check(PhraseData.for_age("unknown").is_empty(), "Unknown age levels do not leak a default catalog")
	var by_id: Dictionary = {}
	for word in vocabulary:
		by_id[word.id] = word
	var seen_ids: Dictionary = {}
	var seen_text: Dictionary = {}
	var lengths: Dictionary = {}
	var has_action: bool = false
	var has_description: bool = false
	for phrase in phrases:
		check(not seen_ids.has(phrase.id), "Phrase IDs are distinct: " + phrase.id)
		check(not seen_text.has(phrase.text), "Phrase text is distinct: " + phrase.id)
		seen_ids[phrase.id] = true
		seen_text[phrase.text] = true
		lengths[phrase.words.size()] = true
		check(phrase.words.size() >= 2 and phrase.words.size() <= 5, "Phrases fit two to five answer slots")
		var target_ids: Dictionary = {}
		var text: PackedStringArray = []
		for id in phrase.words:
			check(by_id.has(id), "Every phrase token belongs to the existing vocabulary: " + id)
			if not by_id.has(id):
				continue
			check(not target_ids.has(id), "No phrase requires the same word tile twice")
			target_ids[id] = true
			text.append(by_id[id].text)
			check(Data.word_age(by_id[id]) <= int(phrase.min_age), "Phrase targets fit their age level")
		check(" ".join(text) == phrase.text, "Spoken phrase text matches its target tiles")
		check(phrase.picture_id.is_empty() or (target_ids.has(phrase.picture_id)
			and not str(by_id[phrase.picture_id].image).is_empty()),
			"A phrase uses a pictured target as its cue or presents contextual words without one")
		check(phrase.audio == "assets/audio/voice/phrase-%s.wav" % phrase.id, "Phrase audio has a stable path")
		if by_id.has(phrase.words[0]):
			has_action = has_action or by_id[phrase.words[0]].get("part_of_speech") == "verb"
			has_description = has_description or by_id[phrase.words[0]].get("part_of_speech") == "adjective"
	check(lengths.has(2) and lengths.has(3) and lengths.has(4) and lengths.has(5), "The catalog includes two-, three-, four- and five-word phrases")
	check(has_action and has_description, "Phrases include actions as well as descriptions")
	phrases[0].words.clear()
	check(not PhraseData.entries()[0].words.is_empty(), "Catalog consumers cannot mutate later loads")


func _test_rounds(vocabulary: Array) -> void:
	var distinct_orders: Dictionary = {}
	for age in range(3, 13):
		var age_band: String = str(age)
		for seed_value in range(12):
			var model = PhraseModel.new()
			check(model.reset(vocabulary, age_band, seed_value), "Every age level starts a three-question round")
			check(model.questions.size() == 3, "Each round contains exactly three questions")
			var seen_questions: Dictionary = {}
			for question_index in range(3):
				var question: Dictionary = model.current_question()
				check(not seen_questions.has(question.id), "Round questions never repeat")
				seen_questions[question.id] = true
				check(int(question.min_age) <= age, "Questions use the selected age band")
				check(model.options.size() == question.words.size() + 2, "Every bank includes two distractors")
				var ids: Dictionary = {}
				var texts: Dictionary = {}
				var visible_targets: Array = []
				var distractor_count: int = 0
				for option in model.options:
					check(not ids.has(option.id), "Option IDs are distinct")
					check(not texts.has(option.text.to_lower()), "Option text is distinct")
					ids[option.id] = true
					texts[option.text.to_lower()] = true
					check(Data.word_age(option) <= age, "Distractors and targets stay within the age level")
					if question.words.has(option.id):
						visible_targets.append(option.id)
					else:
						distractor_count += 1
				check(distractor_count == 2, "Distractors are distinct from the target words")
				check(visible_targets.size() == question.words.size(), "Every required word is available exactly once")
				check(visible_targets != question.words, "The bank never supplies the phrase in the correct order")
				distinct_orders[JSON.stringify(model.snapshot().option_ids)] = true
				_solve(model)
				check(model.completed == question_index + 1, "Each solved phrase counts once")
				check(model.advance(), "Each solved phrase can advance")
			check(model.phase == "finished" and model.completed == 3, "Three solved phrases finish the round")
	check(distinct_orders.size() > 30, "Seeded rounds vary their phrases and choices")
	var first = PhraseModel.new()
	var second = PhraseModel.new()
	check(first.reset(vocabulary, "12", 7481) and second.reset(vocabulary, "12", 7481), "Deterministic fixtures start")
	check(first.questions == second.questions and first.snapshot() == second.snapshot(), "Equal seeds reproduce questions and choice order")
	var snapshot: Dictionary = first.snapshot()
	snapshot.question.words.clear()
	snapshot.option_ids.clear()
	check(not first.current_question().words.is_empty() and not first.options.is_empty(), "A debug snapshot cannot mutate the round")
	var question: Dictionary = first.current_question()
	question.words.clear()
	check(not first.current_question().words.is_empty(), "Question consumers cannot mutate model targets")


func _test_editing_and_completion(vocabulary: Array) -> void:
	var model = PhraseModel.new()
	var notifications: Array[int] = [0]
	model.changed.connect(func() -> void: notifications[0] += 1)
	check(model.reset(vocabulary, "3", 47), "An editable round starts")
	check(notifications[0] == 1, "Reset publishes the initial round")
	check(model.check_answer() == "incomplete", "An empty answer is incomplete")
	check(model.completed == 0 and model.mistakes == 0, "Incomplete answers do not count as mistakes or progress")
	check(not model.advance(), "An incomplete question cannot advance")
	check(not model.select(-1) and not model.select(model.options.size()), "Invalid bank indices are ignored")
	var target: Array = model.current_question().words
	var reversed: Array = target.duplicate()
	reversed.reverse()
	for id in reversed:
		var index: int = _option_index(model, id)
		check(model.select(index), "A target can be placed in a different order")
		check(not model.select(index), "A selected tile cannot be placed twice")
	check(not model.select(_distractor_index(model)), "A full answer does not accept an extra word")
	var wrong_answer: Array = model.answer.duplicate()
	for attempt in range(12):
		check(model.check_answer() == "wrong", "Wrong answers remain retryable after three or more attempts")
		check(model.phase == "building" and model.completed == 0, "Wrong answers never fail or advance the round")
		check(model.answer == wrong_answer, "Wrong feedback preserves the editable answer")
	check(model.mistakes == 12, "Mistakes remain diagnostic counts without a failure limit")
	check(not model.advance(), "Wrong answers cannot skip a question")
	check(not model.remove(-1) and not model.remove(model.answer.size()), "Invalid answer positions are ignored")
	while model.answer.size() > 1:
		check(model.remove(0), "A misplaced word can be returned to the bank")
	check(model.feedback.is_empty(), "Editing clears old wrong feedback")
	check(model.check_answer() == "incomplete", "A partly repaired answer is incomplete")
	check(model.mistakes == 12, "An incomplete repair does not add a mistake")
	for index in range(1, target.size()):
		check(model.select(_option_index(model, target[index])), "Removed words can be placed again in the right order")
	check(model.check_answer() == "correct", "Repairing the order solves the phrase")
	check(model.phase == "correct" and model.completed == 1, "A correct answer records exactly one completed question")
	var correct_notifications: int = notifications[0]
	check(model.check_answer() == "correct" and model.completed == 1, "Repeated checks cannot count a correct phrase twice")
	check(notifications[0] == correct_notifications, "Repeated checks do not replay completion events")
	check(not model.select(0) and not model.remove(0) and not model.clear(), "A solved answer cannot change during feedback")
	check(model.advance(), "Correct feedback advances to the next question")
	check(model.phase == "building" and model.answer.is_empty() and model.feedback.is_empty(), "The next question starts with a clean answer")
	check(not model.advance(), "Repeated advance cannot skip an unanswered question")
	check(model.select(0) and model.clear(), "Clear returns selected tiles to the bank")
	check(not model.clear(), "Clearing an empty answer does nothing")
	for remaining in range(2):
		_solve(model)
		check(model.advance(), "Remaining solved questions advance")
	check(model.phase == "finished" and model.completed == 3 and model.question_index == 3, "The third answer finishes without a fourth question")
	check(model.current_question().is_empty() and model.options.is_empty() and model.answer.is_empty(), "Completed rounds expose no playable question")
	check(not model.advance() and not model.select(0), "A finished round cannot advance or accept tiles")
	check(model.check_answer() == "correct" and model.completed == 3, "Rechecking a finished round does not repeat completion")
	check(model.reset(vocabulary, "7", 48), "A new adventure starts after completion")
	check(model.phase == "building" and model.completed == 0 and model.mistakes == 0 and model.question_index == 0, "Reset clears every previous round counter")


func _test_placement(vocabulary: Array) -> void:
	var model = PhraseModel.new()
	var found: bool = false
	for seed_value in range(128):
		if model.reset(vocabulary, "12", seed_value) and model.current_question().words.size() == 4:
			found = true
			break
	check(found, "Placement tests use a real four-word phrase")
	if not found:
		return
	var original_options: Array = model.options.duplicate(true)
	var observed_answers: Array = []
	var live_answer: Array = model.answer
	model.changed.connect(func() -> void: observed_answers.append(live_answer.duplicate()))
	_expect_ignored_place(model, -1, 0, observed_answers)
	_expect_ignored_place(model, model.options.size(), 0, observed_answers)
	_expect_ignored_place(model, 0, -1, observed_answers)
	_expect_ignored_place(model, 0, 1, observed_answers)
	_expect_place(model, 0, 0, [0], observed_answers)
	_expect_place(model, 2, 1, [0, 2], observed_answers)
	_expect_place(model, 1, 1, [0, 1, 2], observed_answers)
	check(not model.select(1), "The append-only selection API still rejects a tile already in the answer")
	check(model.check_answer() == "incomplete", "Placement does not submit an incomplete phrase automatically")
	_expect_ignored_place(model, 1, 1, observed_answers)
	_expect_ignored_place(model, 2, 3, observed_answers)
	check(model.feedback == "incomplete", "Dropping a tile in its current position preserves existing feedback")
	_expect_place(model, 0, 1, [1, 0, 2], observed_answers)
	check(model.feedback.is_empty(), "A successful move clears incomplete feedback")
	_expect_place(model, 2, 0, [2, 1, 0], observed_answers)
	_expect_place(model, 2, 3, [1, 0, 2], observed_answers)
	_expect_place(model, 3, 0, [3, 1, 0, 2], observed_answers)
	_expect_place(model, 3, 1, [1, 3, 0, 2], observed_answers)
	_expect_ignored_place(model, 4, 0, observed_answers)
	_expect_ignored_place(model, 4, 4, observed_answers)
	_expect_ignored_place(model, 1, 5, observed_answers)
	_expect_ignored_place(model, 1, -1, observed_answers)
	_expect_ignored_place(model, 2, 4, observed_answers)
	_expect_place(model, 1, 3, [3, 0, 2, 1], observed_answers)
	check(model.answer.size() == 4 and model.answer.count(1) == 1,
		"A full answer can reorder an existing word without duplicating it or consuming another slot")
	check(model.remove(1) and not model.answer.has(0), "Removing a placed tile returns that word to the bank")
	_expect_place(model, 0, 1, [3, 0, 2, 1], observed_answers)
	check(model.options == original_options and model.completed == 0 and model.mistakes == 0 and model.question_index == 0,
		"Inserting and reordering preserve the bank, questions and progress counters")
	check(model.clear(), "The reorder fixture can return every tile to the bank")
	var target: Array = model.current_question().words
	var rotated: Array = target.slice(1)
	rotated.append(target[0])
	for id in rotated:
		check(model.place(_option_index(model, id), model.answer.size()), "A bank drop can append each word of a complete answer")
	check(model.check_answer() == "wrong" and model.mistakes == 1, "A misplaced complete phrase remains editable after submission")
	var first_option: int = _option_index(model, target[0])
	_expect_ignored_place(model, first_option, model.answer.size(), observed_answers)
	check(model.feedback == "wrong", "A no-op drop preserves wrong feedback and its mistake count")
	var correct_order: Array = []
	for id in target:
		correct_order.append(_option_index(model, id))
	_expect_place(model, first_option, 0, correct_order, observed_answers)
	check(model.phase == "building" and model.feedback.is_empty() and model.mistakes == 1 and model.completed == 0,
		"Reordering corrects the full answer without submitting it or adding a mistake")
	check(model.check_answer() == "correct" and model.completed == 1, "The repaired word order still uses normal explicit checking")
	_expect_ignored_place(model, first_option, 1, observed_answers)
	_expect_ignored_place(model, _distractor_index(model), 0, observed_answers)
	check(model.advance(), "A solved placed phrase advances normally")
	for remaining in range(2):
		_solve(model)
		check(model.advance(), "Placement preserves the ordinary three-question flow")
	_expect_ignored_place(model, 0, 0, observed_answers)
	check(model.phase == "finished" and model.completed == 3 and model.mistakes == 1,
		"Placement leaves the existing completion and unlimited-retry rules intact")
	check(not model.reset([], "12", 2), "An unavailable new round still fails safely")
	_expect_ignored_place(model, 0, 0, observed_answers)


func _expect_place(model, option_index: int, answer_position: int, expected: Array, observed_answers: Array) -> void:
	var notifications: int = observed_answers.size()
	check(model.place(option_index, answer_position), "A valid placement changes the answer")
	check(model.answer == expected, "Placement uses the requested final position: " + str(expected))
	check(observed_answers.size() == notifications + 1 and observed_answers.back() == expected,
		"A placement publishes its complete new order exactly once")
	for index in model.answer:
		check(model.answer.count(index) == 1, "A moved or inserted option occupies only one answer slot")


func _expect_ignored_place(model, option_index: int, answer_position: int, observed_answers: Array) -> void:
	var before: Dictionary = model.snapshot()
	var notifications: int = observed_answers.size()
	check(not model.place(option_index, answer_position), "Invalid, blocked or unchanged placements return false")
	check(model.snapshot() == before and observed_answers.size() == notifications,
		"Rejected placements preserve the answer, feedback, progress and notification count")


func _test_invalid_input(vocabulary: Array) -> void:
	var model = PhraseModel.new()
	check(not model.reset([], "3", 1), "An empty vocabulary fails safely")
	check(not model.error.is_empty() and model.phase == "finished" and model.options.is_empty(), "Unavailable content cannot leave a playable partial round")
	check(not model.reset(vocabulary, "unknown", 1), "Unsupported age bands fail safely")
	check(not model.reset(["invalid"], "12", 1), "Non-dictionary vocabulary fails safely")
	var duplicate: Array = vocabulary.duplicate(true)
	duplicate.append(vocabulary[0].duplicate(true))
	check(not model.reset(duplicate, "12", 1), "Duplicate word IDs are rejected")
	duplicate[-1].id = "duplicate-display-word"
	duplicate[-1].text = duplicate[-1].text.to_upper()
	check(not model.reset(duplicate, "12", 1), "Duplicate display words are rejected case-insensitively")
	var malformed: Array = vocabulary.duplicate(true)
	malformed[0].level = "unavailable"
	check(not model.reset(malformed, "12", 1), "Invalid vocabulary levels are rejected")
	malformed = vocabulary.duplicate(true)
	malformed[0].erase("audio")
	check(not model.reset(malformed, "12", 1), "Words without their voice metadata are rejected")
	var small_vocabulary: Array = vocabulary.filter(func(word: Dictionary) -> bool:
		return word.id in ["red", "apple", "big", "ball", "soft", "toy"])
	check(model.reset(small_vocabulary, "4", 1), "A complete three-phrase subset is playable")
	check(model.questions.size() == 3, "Missing catalog words are excluded before choosing questions")
	check(not model.reset([], "12", 2), "A failed reset after play is reported")
	check(model.questions.is_empty() and model.answer.is_empty() and model.options.is_empty(), "A failed reset clears stale questions and answers")
	check(not model.select(0) and not model.advance() and model.check_answer() == "incomplete", "Failed rounds cannot produce progress")


func _option_index(model, id: String) -> int:
	for index in range(model.options.size()):
		if model.options[index].id == id:
			return index
	return -1


func _distractor_index(model) -> int:
	var target: Array = model.current_question().words
	for index in range(model.options.size()):
		if not target.has(model.options[index].id):
			return index
	return -1


func _solve(model) -> void:
	for id in model.current_question().words:
		check(model.select(_option_index(model, id)), "Each target word can be selected in order")
	check(model.check_answer() == "correct", "The exact spoken phrase is accepted")
