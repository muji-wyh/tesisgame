extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const SpeechWords = preload("res://scripts/speech_words.gd")

const DURATION: float = 50.0
const MAX_TARGETS: int = 3
const MIN_LATE_LIFETIME: float = 3.0
const BURST_WARMUP: float = 8.0
const EPSILON: float = 0.000001
const RECOGNITION_MESSAGES: Dictionary = {
	"unclear_speech": "Say the word again, loud and clear.",
	"no_matching_target": "Try a word you can see on screen."
}

var phase: String = "ready"
var remaining: float = DURATION
var elapsed: float = 0.0
var bonus_time: float = 0.0
var targets: Array[Dictionary] = []
var hits: int = 0
var misses: int = 0
var combo: int = 0
var best_combo: int = 0
var score: int = 0
var hit_words: Array[Dictionary] = []
var missed_words: Array[Dictionary] = []
var recognition_feedback: String = ""
var recognition_message: String = ""

var _words: Array[Dictionary] = []
var _aliases: Dictionary = {}
var _spawn_counts: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next_uid: int = 1
var _next_spawn_at: float = 0.0
var _next_burst_at: float = INF
var _noun := RegEx.new()


func _init() -> void:
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
		_aliases[word.id] = SpeechWords.forms(text, true)
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
	_next_burst_at = _rng.randf_range(BURST_WARMUP, BURST_WARMUP + 3.0)
	_next_spawn_at = _spawn_interval()
	return true


func vocabulary() -> Array[String]:
	var result: Array[String] = []
	for word in _words:
		result.append(word.text)
	return result


func advance(delta: float) -> void:
	if phase != "running" or delta <= 0.0 or not is_finite(delta):
		return
	var deadline: float = DURATION + bonus_time
	var end_time: float = minf(deadline, elapsed + delta)
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
		remaining = maxf(0.0, deadline - elapsed)
		_expire_targets()
		if elapsed >= deadline:
			phase = "finished"
			targets.clear()
			break
		if _next_spawn_at <= elapsed + EPSILON:
			_spawn()
			_next_spawn_at = elapsed + _spawn_interval()


func pause() -> void:
	if phase == "running":
		phase = "paused"
		clear_recognition_feedback()


func resume() -> void:
	if phase == "paused":
		phase = "running"


func stop() -> void:
	# Leaving a round is not a missed answer and cannot manufacture extra results.
	phase = "finished"
	targets.clear()
	clear_recognition_feedback()


func hit_transcript(text: String) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	if phase != "running" or remaining <= 0.0:
		return removed
	var spoken: Dictionary = {}
	for token in SpeechWords.tokens(text):
		spoken[token] = true
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
		hit.time_bonus = 3 if combo == 2 else 5 if combo == 3 else 0
		bonus_time += float(hit.time_bonus)
		remaining = maxf(0.0, DURATION + bonus_time - elapsed)
		removed.append(hit)
		targets.erase(target)
	if not removed.is_empty() and targets.is_empty():
		_next_spawn_at = minf(_next_spawn_at, elapsed + 0.65)
	_set_recognition_feedback("" if not removed.is_empty() else "unclear_speech" if spoken.is_empty() else "no_matching_target")
	return removed


func _set_recognition_feedback(code: String) -> void:
	recognition_feedback = code
	recognition_message = RECOGNITION_MESSAGES.get(code, "")


func clear_recognition_feedback() -> void:
	if not recognition_feedback.is_empty() or not recognition_message.is_empty():
		_set_recognition_feedback("")


func summary() -> Dictionary:
	return {
		"hits": hits, "misses": misses, "score": score, "best_combo": best_combo,
		"unique_words": hit_words.size(), "hit_words": hit_words.duplicate(true),
		"missed_words": missed_words.duplicate(true), "base_duration": DURATION,
		"bonus_time": bonus_time, "duration": DURATION + bonus_time, "elapsed": elapsed
	}


func _reset_round() -> void:
	recognition_feedback = ""
	recognition_message = ""
	elapsed = 0.0
	bonus_time = 0.0
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
	_next_burst_at = INF


func _spawn_interval() -> float:
	for target in targets:
		if bool(target.get("volley", false)) and float(target.age) <= EPSILON:
			return 3.0
	if elapsed < 8.0:
		return 2.15
	return 1.85 if elapsed < 18.0 else 1.6


func _spawn() -> void:
	var lifetime: float = minf(lerpf(5.6, 5.0, clampf(elapsed / DURATION, 0.0, 1.0)), remaining)
	var capacity: int = 2 if elapsed < 6.0 else MAX_TARGETS
	# Keep the closing seconds active while still giving a child a fair chance to
	# see and say a new word. Final throws land at the deadline, never after it.
	if targets.size() >= capacity or lifetime + EPSILON < MIN_LATE_LIFETIME:
		return
	var burst_due: bool = elapsed >= _next_burst_at
	var available: int = capacity - targets.size()
	# Give a shared launch a clear stage and a short reading window. Older single
	# throws must land before the wave; closing throws keep their fair window.
	if burst_due and not targets.is_empty() and remaining >= MIN_LATE_LIFETIME + _spawn_interval():
		return
	var count: int = mini(available, _rng.randi_range(2, 3)) if burst_due else 1
	var spawned: int = 0
	for _index in range(count):
		if not _spawn_target(lifetime):
			break
		spawned += 1
	if spawned > 1:
		for index in range(targets.size() - spawned, targets.size()):
			targets[index].volley = true
	if burst_due and spawned > 0:
		_next_burst_at = elapsed + _rng.randf_range(8.0, 12.0)


func _spawn_target(lifetime: float) -> bool:
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
		return false
	var word: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var free_lanes: Array[int] = [0, 1, 2]
	for target in targets:
		free_lanes.erase(target.lane)
	var lane: int = free_lanes[_rng.randi_range(0, free_lanes.size() - 1)]
	var center: float = 0.23 + lane * 0.27
	targets.append({
		"uid": _next_uid, "word": word.duplicate(true), "age": 0.0, "lifetime": lifetime,
		"volley": false,
		"forms": _aliases[word.id].duplicate(),
		"lane": lane, "x_start": center + _rng.randf_range(-0.02, 0.02),
		"x_end": center + _rng.randf_range(-0.025, 0.025),
		"peak": _rng.randf_range(0.18, 0.45), "spin": _rng.randf_range(-0.14, 0.14)
	})
	_spawn_counts[word.id] = fewest + 1
	_next_uid += 1
	return true


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
