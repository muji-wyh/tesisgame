extends RefCounted

const Data = preload("res://scripts/game_data.gd")

var cards: Array[Dictionary] = []
var selected_indices: Array[int] = []
var matched_word_ids: Array[String] = []
var feedback_words: Array[Dictionary] = []
var attempts: int = 0
var mistakes: int = 0
var last_correct: bool = false
var phase: String = "waiting"
var studying: bool = false
var error: String = ""


func reset(words: Array, seed_value: int = -1) -> bool:
	if words.size() != 5:
		error = "Memory needs exactly five different words."
		return false
	var validated: Array = words.duplicate(true)
	for word in validated:
		if word is Dictionary and word.get("id") is String and word.get("image") is String:
			# Data.load_all replaces original images with these verified runtime overrides.
			if word.get("image") == "assets/imported-unity/" + word.id + ".png":
				word.image = "assets/images/words/" + word.id + ".png"
	error = Data.validate_words(validated)
	if not error.is_empty():
		return false
	for index in range(words.size()):
		for other in range(index):
			if Data.confusable_words(words[index].id, words[other].id) \
				or Data.confusable_words(words[index].text, words[other].text):
				error = "Memory needs five clearly different words and pictures."
				return false
	var next_cards: Array[Dictionary] = []
	for word in words.duplicate(true):
		for kind in ["word", "image"]:
			next_cards.append({"id": word.id + ":" + kind, "kind": kind, "word": word})
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	for index in range(next_cards.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var card: Dictionary = next_cards[index]
		next_cards[index] = next_cards[other]
		next_cards[other] = card
	cards = next_cards
	selected_indices.clear()
	matched_word_ids.clear()
	feedback_words.clear()
	attempts = 0
	mistakes = 0
	last_correct = false
	studying = false
	phase = "waiting"
	return true


func select(index: int) -> String:
	if studying or not phase in ["waiting", "matching"] or index < 0 or index >= cards.size():
		return "ignored"
	var card: Dictionary = cards[index]
	if matched_word_ids.has(card.word.id):
		return "ignored"
	if selected_indices.has(index):
		selected_indices.clear()
		phase = "waiting"
		return "cancelled"
	if selected_indices.is_empty():
		selected_indices.append(index)
		phase = "matching"
		return "selected"
	var previous: Dictionary = cards[selected_indices[0]]
	if previous.kind == card.kind:
		selected_indices.assign([index])
		return "reselected"
	selected_indices.append(index)
	attempts += 1
	last_correct = previous.word.id == card.word.id
	feedback_words.assign([previous.word])
	phase = "feedback"
	if last_correct:
		matched_word_ids.append(card.word.id)
		return "correct"
	mistakes += 1
	feedback_words.append(card.word)
	return "wrong"


func continue_feedback() -> String:
	if phase != "feedback":
		return "ignored"
	selected_indices.clear()
	feedback_words.clear()
	phase = "won" if matched_word_ids.size() == 5 else "waiting"
	return "won" if phase == "won" else "ready"


func set_study(value: bool) -> bool:
	if not phase in ["waiting", "matching"] or cards.is_empty() or studying == value:
		return false
	studying = value
	selected_indices.clear()
	phase = "waiting"
	return true


func is_revealed(index: int) -> bool:
	if index < 0 or index >= cards.size():
		return false
	return studying or selected_indices.has(index) or matched_word_ids.has(cards[index].word.id)


func stop() -> void:
	phase = "stopped"
	studying = false
	selected_indices.clear()
	feedback_words.clear()
