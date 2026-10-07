extends RefCounted

signal changed

const Data = preload("res://scripts/game_data.gd")
const PhraseData = preload("res://scripts/phrase_data.gd")
const QUESTION_COUNT: int = 3
const DISTRACTOR_COUNT: int = 2

var phase: String = "finished"
var questions: Array[Dictionary] = []
var question_index: int = 0
var completed: int = 0
var mistakes: int = 0
var answer: Array[int] = []
var options: Array[Dictionary] = []
var feedback: String = ""
var error: String = ""
var _question_options: Array = []


func reset(vocabulary: Array, age_band: String, seed_value: int = -1) -> bool:
	phase = "finished"
	questions.clear()
	_question_options.clear()
	question_index = 0
	completed = 0
	mistakes = 0
	answer.clear()
	options.clear()
	feedback = ""
	error = ""
	var band: Dictionary = Data.age_band("10-plus" if age_band == "10+" else age_band)
	if band.is_empty():
		return _fail("Please choose an available age level.")
	var by_id: Dictionary = {}
	var seen_text: Dictionary = {}
	var eligible_words: Array[Dictionary] = []
	for word in vocabulary:
		if not word is Dictionary or not _valid_word(word):
			return _fail("Phrase play needs words with a name, picture, voice and valid level.")
		var normalized: String = String(word.text).strip_edges().to_lower()
		if by_id.has(word.id) or seen_text.has(normalized):
			return _fail("Phrase play needs distinct words.")
		by_id[word.id] = word.duplicate(true)
		seen_text[normalized] = true
		if Data.word_level(word) <= int(band.max_level):
			eligible_words.append(word.duplicate(true))
	var available: Array[Dictionary] = []
	for phrase in PhraseData.for_age(age_band):
		if _phrase_available(phrase, by_id) and eligible_words.size() >= phrase.words.size() + DISTRACTOR_COUNT:
			available.append(phrase)
	if available.size() < QUESTION_COUNT:
		return _fail("At least three complete phrases are needed for this age level.")
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	_shuffle(available, rng)
	questions.assign(available.slice(0, QUESTION_COUNT))
	for question in questions:
		var bank: Array[Dictionary] = []
		for id in question.words:
			bank.append(by_id[id].duplicate(true))
		var distractors: Array[Dictionary] = []
		for word in eligible_words:
			if not question.words.has(word.id):
				distractors.append(word)
		_shuffle(distractors, rng)
		for index in range(DISTRACTOR_COUNT):
			bank.append(distractors[index].duplicate(true))
		_shuffle(bank, rng)
		# A shuffled bank must still require the learner to put words in order.
		_avoid_ordered_targets(bank, question.words)
		_question_options.append(bank)
	_start_question()
	changed.emit()
	return true


func current_question() -> Dictionary:
	if question_index < 0 or question_index >= questions.size():
		return {}
	return questions[question_index].duplicate(true)


func select(index: int) -> bool:
	if answer.has(index):
		return false
	return place(index, answer.size())


# The destination is the tile's final zero-based position, not a pre-removal gap.
# answer.size() also means append when moving a tile already in the answer.
func place(option_index: int, answer_position: int) -> bool:
	if phase != "building" or option_index < 0 or option_index >= options.size():
		return false
	if answer_position < 0 or answer_position > answer.size():
		return false
	var old_position: int = answer.find(option_index)
	if old_position < 0 and answer.size() >= current_question().get("words", []).size():
		return false
	var next_answer: Array[int] = answer.duplicate()
	if old_position >= 0:
		next_answer.remove_at(old_position)
	next_answer.insert(mini(answer_position, next_answer.size()), option_index)
	if next_answer == answer:
		return false
	answer.assign(next_answer)
	feedback = ""
	changed.emit()
	return true


func remove(answer_index: int) -> bool:
	if phase != "building" or answer_index < 0 or answer_index >= answer.size():
		return false
	answer.remove_at(answer_index)
	feedback = ""
	changed.emit()
	return true


func clear() -> bool:
	if phase != "building" or answer.is_empty():
		return false
	answer.clear()
	feedback = ""
	changed.emit()
	return true


func check_answer() -> String:
	if phase != "building":
		return "correct" if completed > question_index or completed == QUESTION_COUNT else "incomplete"
	var target: Array = current_question().words
	if answer.size() != target.size():
		feedback = "incomplete"
	else:
		var matches: bool = true
		for index in range(target.size()):
			if answer[index] < 0 or answer[index] >= options.size() or options[answer[index]].id != target[index]:
				matches = false
		if matches:
			completed += 1
			phase = "correct"
			feedback = "correct"
		else:
			mistakes += 1
			feedback = "wrong"
	changed.emit()
	return feedback


func advance() -> bool:
	if phase != "correct":
		return false
	question_index += 1
	if question_index >= questions.size():
		phase = "finished"
		answer.clear()
		options.clear()
	else:
		_start_question()
	changed.emit()
	return true


func snapshot() -> Dictionary:
	var question: Dictionary = current_question()
	var option_ids: Array[String] = []
	for option in options:
		option_ids.append(option.id)
	return {
		"question": question,
		"id": question.get("id", ""),
		"text": question.get("text", ""),
		"audio": question.get("audio", ""),
		"target_ids": question.get("words", []).duplicate(),
		"option_ids": option_ids,
		"answer": answer.duplicate(),
		"completed": completed,
		"question_index": question_index,
		"phase": phase,
		"feedback": feedback,
		"mistakes": mistakes,
		"error": error
	}


func _start_question() -> void:
	phase = "building"
	options.assign(_question_options[question_index].duplicate(true))
	answer.clear()
	feedback = ""


func _fail(message: String) -> bool:
	error = message
	changed.emit()
	return false


func _valid_word(word: Dictionary) -> bool:
	for key in ["id", "text", "image", "audio", "level"]:
		if not word.get(key) is String or String(word[key]).strip_edges().is_empty():
			return false
	return Data.word_level(word) > 0


func _phrase_available(phrase: Dictionary, by_id: Dictionary) -> bool:
	var text: PackedStringArray = []
	for id in phrase.words:
		if not by_id.has(id) or Data.word_level(by_id[id]) > Data.word_level(phrase):
			return false
		text.append(by_id[id].text)
	return " ".join(text) == phrase.text and by_id.has(phrase.picture_id)


func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var item: Variant = items[index]
		items[index] = items[other]
		items[other] = item


func _avoid_ordered_targets(bank: Array[Dictionary], target: Array) -> void:
	var target_positions: Array[int] = []
	var target_ids: Array[String] = []
	for index in range(bank.size()):
		if target.has(bank[index].id):
			target_positions.append(index)
			target_ids.append(bank[index].id)
	if target_ids == target:
		var first: Dictionary = bank[target_positions[0]]
		bank[target_positions[0]] = bank[target_positions[1]]
		bank[target_positions[1]] = first
