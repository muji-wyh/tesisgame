extends RefCounted
## A fixed set of learning targets that shrinks only after durable mastery.

const FIRST_STAGE_WORDS: int = 3
const MAX_STAGE_WORDS: int = 8
var number: int = 0
var words: Array[Dictionary] = []
var remaining: Array[Dictionary] = []
var completed: bool = false
var _pool: Array[Dictionary] = []
var _mastered: Callable
var _rng := RandomNumberGenerator.new()


func configure(pool: Array, mastered: Callable, seed_value: int = -1) -> void:
	number = 0
	words.clear()
	remaining.clear()
	completed = false
	_pool.assign(pool.duplicate(true))
	_mastered = mastered
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	# Randomize within an age, then fill from the earliest outstanding words.
	# Professional words have no age and keep their shuffled module order.
	for index in range(_pool.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var saved: Dictionary = _pool[index]
		_pool[index] = _pool[other]
		_pool[other] = saved
	_pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("min_age", 0)) < int(b.get("min_age", 0)))
	begin_next()


func next_words() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var spellings: Dictionary = {}
	for word: Dictionary in _pool:
		if _is_mastered(word):
			continue
		var spelling: String = str(word.text).strip_edges().to_lower()
		if spellings.has(spelling):
			continue
		spellings[spelling] = true
		result.append(word.duplicate(true))
		if result.size() == mini(FIRST_STAGE_WORDS + number, MAX_STAGE_WORDS):
			break
	return result


func begin_next() -> bool:
	var selected: Array[Dictionary] = next_words()
	if selected.is_empty():
		completed = true
		return false
	number += 1
	words = selected
	remaining = words.duplicate(true)
	return true


func refresh() -> Array[String]:
	var retired: Array[String] = []
	for word: Dictionary in remaining.duplicate():
		if _is_mastered(word):
			retired.append(str(word.id))
			remaining.erase(word)
	return retired


func snapshot() -> Dictionary:
	var ids: Array[String] = []
	var pending_ids: Array[String] = []
	for word: Dictionary in words:
		ids.append(str(word.id))
	for word: Dictionary in remaining:
		pending_ids.append(str(word.id))
	return {"number": number, "total": words.size(), "mastered": words.size() - remaining.size(),
		"remaining": remaining.size(), "word_ids": ids, "remaining_ids": pending_ids,
		"complete": completed}


func _is_mastered(word: Dictionary) -> bool:
	return _mastered.is_valid() and bool(_mastered.call(word))
