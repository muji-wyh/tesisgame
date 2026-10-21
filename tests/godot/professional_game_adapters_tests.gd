extends SceneTree

const Context = preload("res://scripts/learning_context.gd")
const Match = preload("res://scripts/game_model.gd")
const Memory = preload("res://scripts/memory_game_model.gd")
const Jelly = preload("res://scripts/jelly_match_model.gd")
const Pop = preload("res://scripts/voice_pop_model.gd")
const Phrase = preload("res://scripts/phrase_game_model.gd")
const Speech = preload("res://scripts/speech_words.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_pair_and_jelly_cases()
	_speech_cases()
	_phrase_cases()
	print("Professional game adapters: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _words() -> Array:
	var result: Array = []
	var terms: Array[String] = ["MRI", "USB-C", "blood pressure", "invoice", "electrocardiogram"]
	for index in range(terms.size()):
		result.append({"id": "fixture.sense.%d" % index, "text": terms[index], "display_text": terms[index],
			"track": "professional", "pos": "noun", "accepted_forms": [terms[index]],
			"image": "professional://fixture/image%d" % index, "audio": "professional://fixture/audio%d" % index,
			"practice_modes": ["match", "memory", "jelly", "pop"]})
	return result


func _pair_and_jelly_cases() -> void:
	var words: Array = _words()
	var context: Dictionary = Context.professional("nursing", "module03", "v1", "match")
	var model := Match.new()
	check(model.reset(words, 42, false, "", "", "", false, context), "Match accepts resolved professional terms without a Growth age")
	check(model.cards.size() == 10 and model.learning_context == context, "Match freezes the selected professional identity")
	check(words.all(func(word: Dictionary) -> bool: return not word.has("min_age")), "Adapters never manufacture age fields")
	var old_cards: Array = model.cards.duplicate(true)
	check(not model.reset(words, 42), "Professional words cannot leak into an implicit Growth round")
	check(model.cards == old_cards, "Rejected track mismatch leaves the existing Match board intact")
	var next: Dictionary = Context.professional("retail", "module03", "v1", "memory")
	var memory_words: Array = words.duplicate(true)
	for word in memory_words:
		word.practice_modes = ["memory"]
	check(model.reset(memory_words, 43, true, "", "", "", false, next), "Memory eligibility does not require the Match capability")
	check(model.learning_context.course_id == "retail", "Repeating a mode cannot retain the previous career identity")
	var memory := Memory.new()
	check(memory.reset(model.lesson_words, 42) and memory.cards.size() == 10, "Memory accepts professional punctuation and multiword terms")
	check(memory.start_game(), "Professional Memory starts its initial observation")
	memory.set_study(false)
	var ids: Dictionary = {}
	for index in range(memory.cards.size()):
		var word_id: String = memory.cards[index].word.id
		if not ids.has(word_id):
			ids[word_id] = index
		else:
			check(memory.select(ids[word_id]) == "selected" and memory.select(index) == "correct", "Professional pairs assess the canonical sense")
			memory.continue_feedback()
	check(memory.phase == "won", "All professional Memory pairs complete")
	var jelly := Jelly.new()
	check(jelly.configure(words, 11, 42) and jelly.cells.size() == 12, "Jelly Match bypasses age for professional content")
	var unsupported: Array = words.duplicate(true)
	for word in unsupported:
		word.practice_modes = ["pop"]
	check(not jelly.configure(unsupported, 11, 42), "Jelly Match rejects terms outside its reviewed exercise capability")
	check(model.prepare_activity("phrase", "", 42, false, Context.professional("retail", "module03", "v1", "phrase")), "Non-pair professional games initialize without a fake age")


func _speech_cases() -> void:
	var words: Array = _words()
	words[0].accepted_forms.append("M R I")
	var pop := Pop.new()
	check(pop.configure(words, 42), "Voice Pop accepts professional lexical forms")
	check(pop.vocabulary().has("MRI") and pop.vocabulary().has("electrocardiogram"), "Voice Pop preserves display case and long terms")
	check(Speech.word_forms(words[0], true) == ["mri", "m r i"], "Professional speech uses authored forms without invented plurals")
	check(Speech.tokens("MRI and blood pressure", ["mri", "blood pressure"]) == ["mri", "and", "blood pressure"], "An accepted multiword term remains one speech target")
	check(Speech.tokens("USB-C MRI2", ["usb-c", "mri"]) == ["usb-c", "mri2"], "Hyphens are preserved and digit suffixes do not falsely match")
	check(Speech.tokens("Try C++ please", ["c++"]).has("c++"), "Authored punctuation is escaped safely in the speech matcher")
	check(not Speech.tokens("xMRI MRI2", ["mri"]).has("mri"), "Speech matching does not extract a term from a different token")
	check(Speech.words_conflict({"text": "blood", "track": "professional"}, words[2]), "Speech-ambiguous nested terms cannot share a board")
	check(not Speech.words_conflict(words[0], words[1]), "Distinct abbreviations remain compatible")


func _expression(id: String, text: String) -> Dictionary:
	var tokens: Array = []
	var offset: int = 0
	for token in text.split(" "):
		tokens.append({"index": tokens.size(), "text": token, "start": offset, "end": offset + token.length()})
		offset += token.length() + 1
	return {"id": id, "text": text, "audio": "professional://fixture/phrase", "tokens": tokens,
		"focus_lexeme_ids": ["fixture.sense.3"]}


func _phrase_cases() -> void:
	var expressions: Array = [_expression("fixture.expr.1", "Send the invoice to the office."),
		_expression("fixture.expr.2", "Check the USB-C cable, please."),
		_expression("fixture.expr.3", "Is the MRI room ready?")]
	var phrase := Phrase.new()
	check(phrase.reset_professional(expressions, 42), "Phrase Builder accepts authored positional expressions without Growth PhraseData")
	var questions: Array = phrase.questions.duplicate(true)
	var broken: Array = expressions.duplicate(true)
	broken[0].tokens[1].start = 0
	check(not phrase.reset_professional(broken, 42) and phrase.questions == questions, "Invalid token offsets cannot replace a playable round")
	for unused in range(3):
		var question: Dictionary = phrase.current_question()
		var token_ids: Array = question.words
		check(token_ids.size() == question.tokens.size() and token_ids.size() == _unique(token_ids).size(), "Every repeated token retains its own drag identity")
		var repeated: Array[int] = []
		for index in range(phrase.options.size()):
			if phrase.options[index].text == "the":
				repeated.append(index)
		for token in question.tokens:
			var selected: int = -1
			# Deliberately swap indistinguishable repeated articles.
			if token.text == "the" and not repeated.is_empty():
				selected = repeated.pop_back()
			else:
				for index in range(phrase.options.size()):
					if phrase.options[index].text == token.text and not phrase.answer.has(index):
						selected = index
						break
			check(phrase.select(selected), "Each authored token is independently selectable")
		check(phrase.check_answer() == "correct", "Visible sentence order accepts interchangeable copies of repeated words")
		phrase.advance()
	check(phrase.phase == "finished" and phrase.completed == 3, "Professional expressions complete with original punctuation and capitalization")
	check(expressions[0].tokens[1].text == "the", "Question construction leaves the authored expression unchanged")


func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result
