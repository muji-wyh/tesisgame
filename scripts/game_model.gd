extends RefCounted

signal changed
signal word_attempted(event_id: String, word_ids: Array[String], correct: bool)

const Data = preload("res://scripts/game_data.gd")
const SpeechWords = preload("res://scripts/speech_words.gd")
const THEMES: Array[String] = ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]
const MAX_HINTS: int = 3
const MATCH_PAIR_COUNT: int = 5

var cards: Array[Dictionary] = []
var lesson_words: Array = []
var matched_ids: Array[String] = []
var feedback_ids: Array[String] = []
var hint_ids: Array[String] = []
var hints_remaining: int = MAX_HINTS
var selected_id: String = ""
# Mistakes provide feedback and never end a round.
var mistakes: int = 0
var phase: String = "waiting"
var theme_id: String = "spring"
var adventure_id: String = ""
var adventure_name: String = "Word explorers"
var age_band_id: String = "3"
var chest_state: String = "closed"
var reward_theme: String = ""
var reward_id: String = ""
var error: String = ""
var last_correct: bool = false
var _attempt_sequence: int = 0


func reset(words: Array, seed_value: int = -1, repeat_lesson: bool = false, requested_adventure_id: String = "", required_word_id: String = "", requested_age_band_id: String = "3") -> bool:
	var band: Dictionary = Data.age_band(requested_age_band_id)
	if band.is_empty():
		error = "Please choose an available age level."
		return false
	var maximum_age: int = int(band.get("max_age", 3))
	var eligible: Array = []
	for word in words:
		if not word is Dictionary or not word.has_all(["id", "min_age", "image"]):
			error = "Learning words need an ID, a minimum age and a picture."
			return false
		if int(word.min_age) <= maximum_age and "match" in word.get("practice_modes", ["match", "memory"]):
			eligible.append(word)
	var saved_theme: String = theme_id
	var repeating: bool = repeat_lesson and lesson_words.size() == MATCH_PAIR_COUNT and age_band_id == requested_age_band_id
	if repeating:
		for previous in lesson_words:
			if not eligible.any(func(word: Dictionary) -> bool: return word.id == previous.id):
				repeating = false
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var pool: Array = eligible.duplicate(true)
	_shuffle(pool, rng)
	# Every required pictured word must remain reachable. Theme/adventure names
	# do not randomly narrow this pool to a topic that can starve another word.
	var previous_ids: Array = lesson_words.map(func(word: Dictionary) -> String: return str(word.id)) if seed_value < 0 else []
	var prioritized: Array = []
	for priority in range(2, -1, -1):
		var cohort: Array = pool.filter(func(word: Dictionary) -> bool: return clampi(int(word.get("_growth_priority", 0)), 0, 2) == priority)
		prioritized.append_array(cohort.filter(func(word: Dictionary) -> bool: return not previous_ids.has(word.id)))
		prioritized.append_array(cohort.filter(func(word: Dictionary) -> bool: return previous_ids.has(word.id)))
	pool = prioritized
	if not requested_adventure_id.is_empty() and not repeating:
		var requested: Dictionary = {}
		for adventure in Data.adventures(eligible):
			if adventure.id == requested_adventure_id:
				requested = adventure
				break
		if requested.is_empty():
			error = "Please choose an available adventure."
			return false
		pool = pool.filter(func(word: Dictionary) -> bool: return requested.words.has(word.id))
	if not required_word_id.is_empty() and not repeating:
		var requested_words: Array = pool.filter(func(word: Dictionary) -> bool: return word.id == required_word_id)
		if requested_words.is_empty():
			error = "The requested word is unavailable at this learning level."
			return false
		pool.erase(requested_words[0])
		pool.push_front(requested_words[0])
	if not repeating:
		var distinct: Array = _distinct_words(pool, MATCH_PAIR_COUNT)
		if distinct.size() < MATCH_PAIR_COUNT:
			error = "This lesson needs five clearly different pictured words."
			return false
		lesson_words = distinct.slice(0, MATCH_PAIR_COUNT)
		age_band_id = requested_age_band_id
		adventure_id = requested_adventure_id
		adventure_name = "Your learning path"
	cards.clear()
	for word in lesson_words:
		_add_card(word, "word")
		_add_card(word, "image")
	_shuffle(cards, rng)
	theme_id = saved_theme if repeat_lesson else THEMES[rng.randi_range(0, THEMES.size() - 1)]
	matched_ids.clear()
	feedback_ids.clear()
	hint_ids.clear()
	hints_remaining = MAX_HINTS
	selected_id = ""
	mistakes = 0
	phase = "waiting"
	chest_state = "closed"
	reward_theme = ""
	reward_id = ""
	error = ""
	last_correct = false
	_attempt_sequence = 0
	changed.emit()
	return true


func _distinct_words(words: Array, limit: int = 0) -> Array:
	var distinct: Array = []
	for word in words:
		if not distinct.any(func(other: Dictionary) -> bool:
			return Data.word_pair_conflicts(word, other) or SpeechWords.words_conflict(word, other)):
			distinct.append(word)
			if limit > 0 and distinct.size() >= limit:
				break
	return distinct


func _add_card(word: Dictionary, kind: String) -> void:
	cards.append({"id": word.id + ":" + kind, "kind": kind, "word": word})


func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var item: Variant = items[index]
		items[index] = items[other]
		items[other] = item


func card_by_id(id: String) -> Dictionary:
	for card in cards:
		if card.id == id:
			return card
	return {}


func spoken_matches(transcript: String) -> Array[String]:
	var matches: Array[String] = []
	if phase == "won":
		return matches
	var accepted_forms: Array[String] = []
	for card in cards:
		if card.kind == "word" and not _spoken_pair(card.word.id).is_empty():
			accepted_forms.append_array(SpeechWords.word_forms(card.word))
	for token in SpeechWords.tokens(transcript, accepted_forms):
		var candidate: String = ""
		for card in cards:
			if card.kind != "word" or _spoken_pair(card.word.id).is_empty():
				continue
			var word_id: String = card.word.id
			# One token resolves to one available pair. Exact spelling wins if a
			# future board contains both spellings of the same sound.
			if card.word.text == token:
				candidate = word_id
				break
			if candidate.is_empty() and SpeechWords.word_forms(card.word).has(token):
				candidate = word_id
		if not candidate.is_empty() and not matches.has(candidate):
			matches.append(candidate)
	return matches


func match_spoken_word(word_id: String) -> String:
	if not phase in ["waiting", "matching"]:
		return "ignored"
	var pair: Array[String] = _spoken_pair(word_id)
	if pair.is_empty():
		return "ignored"
	selected_id = ""
	phase = "waiting"
	select(pair[0])
	return select(pair[1])


func _spoken_pair(word_id: String) -> Array[String]:
	var word_card: Dictionary = card_by_id(word_id + ":word")
	var image_card: Dictionary = card_by_id(word_id + ":image")
	if word_card.is_empty() or image_card.is_empty():
		return []
	if word_card.kind != "word" or image_card.kind != "image":
		return []
	if matched_ids.has(word_card.id) or matched_ids.has(image_card.id):
		return []
	return [word_card.id, image_card.id]


func request_hint() -> bool:
	if hints_remaining <= 0 or not hint_ids.is_empty() or not phase in ["waiting", "matching"]:
		return false
	# Scan this small board for partners instead of maintaining a separate pair index.
	var candidates: Array[Dictionary] = cards.duplicate()
	if not selected_id.is_empty():
		candidates.push_front(card_by_id(selected_id))
	for card in candidates:
		if matched_ids.has(card.id):
			continue
		var partner_id: String = card.word.id + (":image" if card.kind == "word" else ":word")
		if card_by_id(partner_id).is_empty():
			continue
		hint_ids.assign([card.id, partner_id])
		hints_remaining -= 1
		if not selected_id.is_empty() and not hint_ids.has(selected_id):
			selected_id = ""
			phase = "waiting"
		changed.emit()
		return true
	return false


func select(id: String, notify: bool = true) -> String:
	if not phase in ["waiting", "matching"] or matched_ids.has(id):
		return "ignored"
	var card: Dictionary = card_by_id(id)
	if card.is_empty():
		return "ignored"
	if not hint_ids.has(id):
		hint_ids.clear()
	var result := "selected"
	if selected_id == id:
		selected_id = ""
		hint_ids.clear()
		phase = "waiting"
		result = "cancelled"
	elif selected_id.is_empty():
		selected_id = id
		phase = "matching"
	else:
		var previous: Dictionary = card_by_id(selected_id)
		if previous.kind == card.kind:
			selected_id = id
			result = "reselected"
		else:
			hint_ids.clear()
			last_correct = previous.word.id == card.word.id
			feedback_ids.assign([selected_id, id])
			selected_id = ""
			phase = "feedback"
			if last_correct:
				matched_ids.append_array(feedback_ids)
				result = "correct"
			else:
				mistakes += 1
				result = "wrong"
			_attempt_sequence += 1
			var involved: Array[String] = [str(previous.word.id)]
			if not involved.has(str(card.word.id)):
				involved.append(str(card.word.id))
			word_attempted.emit("match-%d" % _attempt_sequence, involved, last_correct)
	if notify:
		changed.emit()
	return result


func resolve_feedback() -> void:
	if phase != "feedback":
		return
	feedback_ids.clear()
	selected_id = ""
	if not cards.is_empty() and cards.all(func(card: Dictionary) -> bool: return matched_ids.has(card.id)):
		phase = "won"
	else:
		phase = "waiting"
	changed.emit()


func set_theme(id: String) -> bool:
	if not THEMES.has(id) or chest_state == "opening":
		return false
	if theme_id != id:
		theme_id = id
		changed.emit()
	return true


func begin_open(id: Variant = null) -> bool:
	var selected_id: String = theme_id + "-1" if id == null else str(id)
	if phase != "won" or chest_state != "closed" or selected_id.is_empty():
		return false
	chest_state = "opening"
	reward_theme = theme_id
	reward_id = selected_id
	changed.emit()
	return true


func cancel_open() -> bool:
	if phase != "won" or chest_state != "opening":
		return false
	chest_state = "closed"
	reward_theme = ""
	reward_id = ""
	changed.emit()
	return true


func finish_open() -> bool:
	if phase != "won" or chest_state != "opening":
		return false
	chest_state = "opened"
	changed.emit()
	return true
