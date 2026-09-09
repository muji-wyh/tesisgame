extends RefCounted

signal changed

const THEMES: Array[String] = ["spring", "summer", "autumn", "winter"]

var cards: Array[Dictionary] = []
var matched_ids: Array[String] = []
var feedback_ids: Array[String] = []
var hint_ids: Array[String] = []
var selected_id: String = ""
var successes: int = 0
var mistakes: int = 0
var streak: int = 0
var practice_mode: bool = false
var phase: String = "waiting"
var theme_id: String = "spring"
var chest_state: String = "closed"
var reward_theme: String = ""
var reward_id: String = ""
var error: String = ""
var last_correct: bool = false


func reset(words: Array, seed_value: int = -1) -> bool:
	if words.size() < 5:
		error = "At least five words are needed to play."
		return false
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var pool: Array = words.duplicate(true)
	_shuffle(pool, rng)
	if seed_value < 0 and not cards.is_empty():
		# ponytail: only the previous board; a learner profile needs separate evidence and design.
		var previous: Array = cards.map(func(card: Dictionary) -> String: return card.word.id)
		var fresh: Array = pool.filter(func(word: Dictionary) -> bool: return not previous.has(word.id))
		if fresh.size() >= 5:
			pool = fresh
	cards.clear()
	for index in range(3):
		_add_card(pool[index], "word")
		_add_card(pool[index], "image")
	_add_card(pool[3], "word")
	_add_card(pool[4], "image")
	_shuffle(cards, rng)
	theme_id = THEMES[rng.randi_range(0, THEMES.size() - 1)]
	matched_ids.clear()
	feedback_ids.clear()
	hint_ids.clear()
	selected_id = ""
	successes = 0
	mistakes = 0
	streak = 0
	phase = "waiting"
	chest_state = "closed"
	reward_theme = ""
	reward_id = ""
	error = ""
	last_correct = false
	changed.emit()
	return true


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


func request_hint() -> bool:
	if not phase in ["waiting", "matching"]:
		return false
	# ponytail: eight-card boards; scan for partners instead of maintaining a pair index.
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
		if not selected_id.is_empty() and not hint_ids.has(selected_id):
			selected_id = ""
			phase = "waiting"
		changed.emit()
		return true
	return false


func select(id: String) -> String:
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
				successes += 1
				streak += 1
				matched_ids.append_array(feedback_ids)
				result = "correct"
			else:
				if not practice_mode:
					mistakes += 1
				streak = 0
				result = "wrong"
	changed.emit()
	return result


func resolve_feedback() -> void:
	if phase != "feedback":
		return
	feedback_ids.clear()
	selected_id = ""
	if successes >= 3:
		phase = "won"
	elif mistakes >= 3 and not practice_mode:
		phase = "lost"
	else:
		phase = "waiting"
	changed.emit()


func set_practice(enabled: bool) -> bool:
	if not phase in ["waiting", "matching", "lost"] or (phase == "lost" and not enabled):
		return false
	if practice_mode != enabled:
		practice_mode = enabled
		mistakes = 0
		if phase == "lost":
			phase = "waiting"
		changed.emit()
	return true


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


func finish_open() -> bool:
	if phase != "won" or chest_state != "opening":
		return false
	chest_state = "opened"
	changed.emit()
	return true
