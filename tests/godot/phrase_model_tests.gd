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
	_test_invalid_input(vocabulary)
	print("Phrase model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_catalog(vocabulary: Array) -> void:
	var phrases: Array[Dictionary] = PhraseData.entries()
	check(phrases.size() == 36, "The catalog has 36 phrases")
	check(PhraseData.for_age("4-6").size() == 12, "Young learners have 12 phrases")
	check(PhraseData.for_age("7-9").size() == 12, "Growing learners have 12 phrases")
	check(PhraseData.for_age("10-plus").size() == 12, "Advanced learners have 12 phrases")
	check(PhraseData.for_age("10+") == PhraseData.for_age("10-plus"), "Both advanced age identifiers select the same phrases")
	check(PhraseData.for_age("all").size() == 36, "All words includes every phrase")
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
		check(phrase.words.size() >= 2 and phrase.words.size() <= 4, "Phrases fit two to four answer slots")
		var target_ids: Dictionary = {}
		var text: PackedStringArray = []
		for id in phrase.words:
			check(by_id.has(id), "Every phrase token belongs to the existing vocabulary: " + id)
			if not by_id.has(id):
				continue
			check(not target_ids.has(id), "No phrase requires the same word tile twice")
			target_ids[id] = true
			text.append(by_id[id].text)
			check(Data.word_level(by_id[id]) <= Data.word_level(phrase), "Phrase targets fit their age level")
		check(" ".join(text) == phrase.text, "Spoken phrase text matches its target tiles")
		check(target_ids.has(phrase.picture_id), "Each illustration cue belongs to its phrase")
		check(phrase.audio == "assets/audio/voice/phrase-%s.wav" % phrase.id, "Phrase audio has a stable path")
		if by_id.has(phrase.words[0]):
			has_action = has_action or by_id[phrase.words[0]].get("part_of_speech") == "verb"
			has_description = has_description or by_id[phrase.words[0]].get("part_of_speech") == "adjective"
	check(lengths.has(2) and lengths.has(3) and lengths.has(4), "The catalog includes two-, three- and four-word phrases")
	check(has_action and has_description, "Phrases include actions as well as descriptions")
	phrases[0].words.clear()
	check(not PhraseData.entries()[0].words.is_empty(), "Catalog consumers cannot mutate later loads")


func _test_rounds(vocabulary: Array) -> void:
	var levels: Dictionary = {"4-6": "basic", "7-9": "growing", "10-plus": "advanced", "10+": "advanced", "all": ""}
	var distinct_orders: Dictionary = {}
	for age_band in levels:
		var max_level: int = 3 if age_band in ["all", "10-plus", "10+"] else (1 if age_band == "4-6" else 2)
		for seed_value in range(12):
			var model = PhraseModel.new()
			check(model.reset(vocabulary, age_band, seed_value), "Every age level starts a three-question round")
			check(model.questions.size() == 3, "Each round contains exactly three questions")
			var seen_questions: Dictionary = {}
			for question_index in range(3):
				var question: Dictionary = model.current_question()
				check(not seen_questions.has(question.id), "Round questions never repeat")
				seen_questions[question.id] = true
				check(age_band == "all" or question.level == levels[age_band], "Questions use the selected age band")
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
					check(Data.word_level(option) <= max_level, "Distractors and targets stay within the age level")
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
	check(first.reset(vocabulary, "all", 7481) and second.reset(vocabulary, "all", 7481), "Deterministic fixtures start")
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
	check(model.reset(vocabulary, "4-6", 47), "An editable round starts")
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
	check(model.reset(vocabulary, "7-9", 48), "A new adventure starts after completion")
	check(model.phase == "building" and model.completed == 0 and model.mistakes == 0 and model.question_index == 0, "Reset clears every previous round counter")


func _test_invalid_input(vocabulary: Array) -> void:
	var model = PhraseModel.new()
	check(not model.reset([], "4-6", 1), "An empty vocabulary fails safely")
	check(not model.error.is_empty() and model.phase == "finished" and model.options.is_empty(), "Unavailable content cannot leave a playable partial round")
	check(not model.reset(vocabulary, "unknown", 1), "Unsupported age bands fail safely")
	check(not model.reset(["invalid"], "all", 1), "Non-dictionary vocabulary fails safely")
	var duplicate: Array = vocabulary.duplicate(true)
	duplicate.append(vocabulary[0].duplicate(true))
	check(not model.reset(duplicate, "all", 1), "Duplicate word IDs are rejected")
	duplicate[-1].id = "duplicate-display-word"
	duplicate[-1].text = duplicate[-1].text.to_upper()
	check(not model.reset(duplicate, "all", 1), "Duplicate display words are rejected case-insensitively")
	var malformed: Array = vocabulary.duplicate(true)
	malformed[0].level = "unavailable"
	check(not model.reset(malformed, "all", 1), "Invalid vocabulary levels are rejected")
	malformed = vocabulary.duplicate(true)
	malformed[0].erase("audio")
	check(not model.reset(malformed, "all", 1), "Words without their voice metadata are rejected")
	var small_vocabulary: Array = vocabulary.filter(func(word: Dictionary) -> bool:
		return word.id in ["red", "apple", "big", "ball", "soft", "toy"])
	check(model.reset(small_vocabulary, "4-6", 1), "A complete three-phrase subset is playable")
	check(model.questions.size() == 3, "Missing catalog words are excluded before choosing questions")
	check(not model.reset([], "all", 2), "A failed reset after play is reported")
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
