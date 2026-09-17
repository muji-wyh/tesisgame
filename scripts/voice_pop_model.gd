extends RefCounted

const Data = preload("res://scripts/game_data.gd")

const DURATION: float = 30.0
const MAX_TARGETS: int = 3
const MIN_LATE_LIFETIME: float = 3.0
const EPSILON: float = 0.000001
# These nouns do not take a regular plural in the pictured sense. In particular,
# never derive a singular by removing letters from arbitrary recognized speech.
const UNCHANGED_PLURALS: Array[String] = [
	"fish", "sheep", "peas", "corn", "bread", "cheese", "milk", "water", "juice", "rice",
	"rain", "snow", "grass", "pants", "sunglasses", "coral", "squid", "jellyfish", "starfish", "bamboo"
]
const SPECIAL_PLURALS: Dictionary = {
	"mouse": ["mice"], "foot": ["feet"], "tooth": ["teeth"], "leaf": ["leaves"],
	"scarf": ["scarves", "scarfs"], "tomato": ["tomatoes"], "octopus": ["octopuses", "octopi"],
	"cactus": ["cacti", "cactuses"]
}

var phase: String = "ready"
var remaining: float = DURATION
var elapsed: float = 0.0
var targets: Array[Dictionary] = []
var hits: int = 0
var misses: int = 0
var combo: int = 0
var best_combo: int = 0
var score: int = 0
var hit_words: Array[Dictionary] = []
var missed_words: Array[Dictionary] = []

var _words: Array[Dictionary] = []
var _aliases: Dictionary = {}
var _spawn_counts: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next_uid: int = 1
var _next_spawn_at: float = 0.0
var _tokens := RegEx.new()
var _noun := RegEx.new()


func _init() -> void:
	# Keep letters from other alphabets, numbers, and possessives in the same token:
	# "thorn", "cat2", "cat's", and "caté" must not become a hit for horn or cat.
	_tokens.compile("[\\p{L}\\p{N}_]+(?:['’][\\p{L}\\p{N}_]+)*")
	_noun.compile("^[a-z]+$")


func configure(words: Array, seed_value: int = -1) -> bool:
	_words.clear()
	_aliases.clear()
	var seen_ids: Dictionary = {}
	var seen_texts: Dictionary = {}
	for entry in words:
		if not entry is Dictionary or not entry.has_all(["id", "text", "image", "audio"]):
			continue
		var valid: bool = true
		for key in ["id", "text", "image", "audio"]:
			if not entry[key] is String or entry[key].strip_edges().is_empty():
				valid = false
		if not valid:
			continue
		var text: String = entry.text.strip_edges().to_lower()
		if _noun.search(text) == null or seen_ids.has(entry.id) or seen_texts.has(text):
			continue
		var word: Dictionary = entry.duplicate(true)
		word.text = text
		_words.append(word)
		_aliases[word.id] = _word_forms(text)
		seen_ids[word.id] = true
		seen_texts[text] = true
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_reset_round()
	phase = "ready"
	return not _words.is_empty()


func start() -> bool:
	if phase in ["running", "paused"] or _words.is_empty():
		return false
	_reset_round()
	phase = "running"
	_spawn()
	_next_spawn_at = _spawn_interval()
	return true


func advance(delta: float) -> void:
	if phase != "running" or delta <= 0.0 or not is_finite(delta):
		return
	var end_time: float = minf(DURATION, elapsed + delta)
	# Process spawn/expiry events at their actual time even after a slow frame.
	# A large delta therefore cannot extend a round or give a late target less time.
	while phase == "running" and elapsed < end_time:
		var event_time: float = minf(end_time, _next_spawn_at)
		for target in targets:
			event_time = minf(event_time, elapsed + maxf(0.0, target.lifetime - target.age))
		var step: float = maxf(0.0, event_time - elapsed)
		for target in targets:
			target.age = minf(target.lifetime, target.age + step)
		elapsed = event_time
		remaining = maxf(0.0, DURATION - elapsed)
		_expire_targets()
		if elapsed >= DURATION:
			phase = "finished"
			targets.clear()
			break
		if _next_spawn_at <= elapsed + EPSILON:
			_spawn()
			_next_spawn_at = elapsed + _spawn_interval()


func pause() -> void:
	if phase == "running":
		phase = "paused"


func resume() -> void:
	if phase == "paused":
		phase = "running"


func stop() -> void:
	# Leaving a round is not a missed answer and cannot manufacture extra results.
	phase = "finished"
	targets.clear()


func hit_transcript(text: String) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	if phase != "running" or remaining <= 0.0:
		return removed
	var spoken: Dictionary = {}
	for token in _tokens.search_all(text.to_lower()):
		spoken[token.get_string()] = true
	for target in targets.duplicate():
		if target.age + EPSILON >= target.lifetime:
			continue
		var matched: bool = false
		for form in _aliases.get(target.word.id, []):
			if spoken.has(form):
				matched = true
				break
		if not matched:
			continue
		hits += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		var points: int = 10 + mini(combo - 1, 5) * 2
		score += points
		_record_word(hit_words, target.word)
		var hit: Dictionary = target.duplicate(true)
		hit.points = points
		hit.combo = combo
		removed.append(hit)
		targets.erase(target)
	if not removed.is_empty() and targets.is_empty():
		_next_spawn_at = minf(_next_spawn_at, elapsed + 0.65)
	return removed


func summary() -> Dictionary:
	return {
		"hits": hits, "misses": misses, "score": score, "best_combo": best_combo,
		"unique_words": hit_words.size(), "hit_words": hit_words.duplicate(true),
		"missed_words": missed_words.duplicate(true), "duration": DURATION, "elapsed": elapsed
	}


func _reset_round() -> void:
	elapsed = 0.0
	remaining = DURATION
	targets.clear()
	hits = 0
	misses = 0
	combo = 0
	best_combo = 0
	score = 0
	hit_words.clear()
	missed_words.clear()
	_spawn_counts.clear()
	_next_uid = 1
	_next_spawn_at = 0.0


func _spawn_interval() -> float:
	if elapsed < 8.0:
		return 2.15
	return 1.85 if elapsed < 18.0 else 1.6


func _spawn() -> void:
	var lifetime: float = minf(lerpf(5.6, 5.0, elapsed / DURATION), remaining)
	var capacity: int = 2 if elapsed < 6.0 else MAX_TARGETS
	# Keep the closing seconds active while still giving a child a fair chance to
	# see and say a new word. Final throws land at the deadline, never after it.
	if targets.size() >= capacity or lifetime + EPSILON < MIN_LATE_LIFETIME:
		return
	var candidates: Array[Dictionary] = []
	var fewest: int = 2147483647
	for word in _words:
		if not _can_spawn(word):
			continue
		var count: int = _spawn_counts.get(word.id, 0)
		if count < fewest:
			fewest = count
			candidates.clear()
		if count == fewest:
			candidates.append(word)
	if candidates.is_empty():
		return
	var word: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var free_lanes: Array[int] = [0, 1, 2]
	for target in targets:
		free_lanes.erase(target.lane)
	var lane: int = free_lanes[_rng.randi_range(0, free_lanes.size() - 1)]
	var center: float = 0.23 + lane * 0.27
	targets.append({
		"uid": _next_uid, "word": word.duplicate(true), "age": 0.0, "lifetime": lifetime,
		"forms": _aliases[word.id].duplicate(),
		"lane": lane, "x_start": center + _rng.randf_range(-0.02, 0.02),
		"x_end": center + _rng.randf_range(-0.025, 0.025),
		"peak": _rng.randf_range(0.18, 0.45), "spin": _rng.randf_range(-0.14, 0.14)
	})
	_spawn_counts[word.id] = fewest + 1
	_next_uid += 1


func _can_spawn(word: Dictionary) -> bool:
	for target in targets:
		if Data.confusable_words(word.id, target.word.id) or Data.confusable_words(word.text, target.word.text):
			return false
		for form in _aliases[word.id]:
			if _aliases[target.word.id].has(form):
				return false
	return true


func _expire_targets() -> void:
	for target in targets.duplicate():
		if target.age + EPSILON < target.lifetime:
			continue
		misses += 1
		combo = 0
		_record_word(missed_words, target.word)
		targets.erase(target)


func _record_word(collection: Array[Dictionary], word: Dictionary) -> void:
	for entry in collection:
		if entry.id == word.id:
			entry.count += 1
			return
	var entry: Dictionary = word.duplicate(true)
	entry.count = 1
	collection.append(entry)


func _word_forms(noun: String) -> Array[String]:
	var forms: Array[String] = [noun]
	if noun in UNCHANGED_PLURALS:
		return forms
	if SPECIAL_PLURALS.has(noun):
		for form in SPECIAL_PLURALS[noun]:
			forms.append(form)
	elif noun.ends_with("y") and noun.length() > 1 and not noun[-2] in "aeiou":
		forms.append(noun.left(-1) + "ies")
	elif noun.ends_with("s") or noun.ends_with("x") or noun.ends_with("z") or noun.ends_with("ch") or noun.ends_with("sh"):
		forms.append(noun + "es")
	else:
		forms.append(noun + "s")
	return forms
