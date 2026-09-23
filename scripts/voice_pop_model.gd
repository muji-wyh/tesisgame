extends RefCounted

const Data = preload("res://scripts/game_data.gd")

const DURATION: float = 30.0
const MAX_TARGETS: int = 3
const MIN_LATE_LIFETIME: float = 3.0
const EPSILON: float = 0.000001
const MAX_PLAYERS: int = 4
const MAX_VOICE_PROFILES: int = 10
const EMBEDDING_SIZE: int = 256
const MAX_VOICE_TEMPLATES: int = 8
const SETTLE_DURATION: float = 3.0
# Experimental cosine thresholds, deliberately configurable for the short-word
# voice study. These are not a claim of calibrated speaker recognition accuracy.
const SPEAKER_SIMILARITY: float = 0.60
const SPEAKER_MARGIN: float = 0.08
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
var play_mode: String = "single"
var round_id: String = ""

var _round_counter: int = 0
var _settling_elapsed: float = 0.0
var _speaker_similarity: float = SPEAKER_SIMILARITY
var _speaker_margin: float = SPEAKER_MARGIN
var _voice_profiles: Array[Dictionary] = []
var _round_profiles: Array[Dictionary] = []
var _players: Array[Dictionary] = []
var _seen_events: Dictionary = {}
var _target_history: Array[Dictionary] = []
var _history_by_uid: Dictionary = {}

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
	if phase in ["running", "paused", "settling"] or _words.is_empty():
		return false
	if play_mode == "multi" and _voice_profiles.is_empty():
		return false
	_reset_round()
	if play_mode == "multi":
		_round_profiles = _voice_profiles.duplicate(true)
	_round_counter += 1
	round_id = str(_round_counter)
	phase = "running"
	_spawn()
	_next_spawn_at = _spawn_interval()
	return true


func set_play_mode(mode: String) -> bool:
	if not mode in ["single", "multi"] or not phase in ["ready", "finished"]:
		return false
	play_mode = mode
	return true


func set_voice_profiles(profiles: Array) -> bool:
	# Replace the library atomically. An active/paused round retains its own
	# snapshot, including names and avatars, until the next successful start.
	if profiles.size() > MAX_VOICE_PROFILES:
		return false
	var validated: Array[Dictionary] = []
	var ids: Dictionary = {}
	for profile in profiles:
		if not profile is Dictionary or not profile.has_all(["id", "name", "emoji", "embedding"]):
			return false
		for key in ["id", "name", "emoji"]:
			if not profile[key] is String or profile[key].strip_edges().is_empty():
				return false
		var id: String = profile.id.strip_edges()
		if ids.has(id) or id.length() > 128 or profile.name.length() > 64 or profile.emoji.length() > 32:
			return false
		var embedding: Array[float] = _normalized_embedding(profile.embedding)
		if embedding.size() != EMBEDDING_SIZE:
			return false
		var templates: Array = []
		if profile.has("templates"):
			if not profile.templates is Array or profile.templates.is_empty() or profile.templates.size() > MAX_VOICE_TEMPLATES:
				return false
			for candidate in profile.templates:
				var template: Array[float] = _normalized_embedding(candidate)
				if template.size() != EMBEDDING_SIZE:
					return false
				templates.append(template)
		else:
			templates.append(embedding.duplicate())
		var avatar: Variant = profile.get("avatar_png", "")
		if not avatar is String or avatar.length() > 131072:
			return false
		validated.append({"id": id, "name": profile.name.strip_edges(), "emoji": profile.emoji,
			"embedding": embedding, "templates": templates, "avatar_png": avatar})
		ids[id] = true
	_voice_profiles = validated
	return true


func voice_profile_count() -> int:
	return _voice_profiles.size()


func configure_speaker_matching(similarity: float = SPEAKER_SIMILARITY,
		margin: float = SPEAKER_MARGIN) -> bool:
	if not phase in ["ready", "finished"] or not is_finite(similarity) or not is_finite(margin):
		return false
	if similarity < 0.0 or similarity > 1.0 or margin < 0.0 or margin > 1.0:
		return false
	_speaker_similarity = similarity
	_speaker_margin = margin
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
			phase = "settling" if play_mode == "multi" else "finished"
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
	_clear_voice_evidence()


func finish_settling(delta: float) -> void:
	if phase != "settling" or delta <= 0.0 or not is_finite(delta):
		return
	_settling_elapsed = minf(SETTLE_DURATION, _settling_elapsed + delta)
	if _settling_elapsed + EPSILON >= SETTLE_DURATION:
		phase = "finished"
		_clear_voice_evidence()


func hit_transcript(text: String) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	if play_mode != "single" or phase != "running" or remaining <= 0.0:
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


# Timestamps are milliseconds of active round time, excluding microphone pauses.
# A word belongs to targets visible when speech STARTED; late results cannot hit
# a later throw of the same word. Only pre-deadline captured audio is accepted.
func hit_speech_event(event: Dictionary) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	if play_mode != "multi" or not phase in ["running", "settling"]:
		return removed
	if not event.has_all(["round_id", "event_id", "text", "start_ms", "end_ms", "embedding"]):
		return removed
	if not event.round_id is String or event.round_id != round_id or not event.event_id is String or event.event_id.is_empty():
		return removed
	if _seen_events.has(event.event_id) or not event.text is String:
		return removed
	if not _is_number(event.start_ms) or not _is_number(event.end_ms):
		return removed
	var start_ms: float = float(event.start_ms)
	var end_ms: float = float(event.end_ms)
	if not is_finite(start_ms) or not is_finite(end_ms) or start_ms < 0.0 or end_ms <= start_ms:
		return removed
	if start_ms >= DURATION * 1000.0 or end_ms > DURATION * 1000.0 or start_ms > elapsed * 1000.0 + EPSILON:
		return removed
	var embedding: Array[float] = _normalized_embedding(event.embedding)
	if embedding.size() != EMBEDDING_SIZE:
		return removed
	_seen_events[event.event_id] = true
	var spoken: Dictionary = {}
	for token in _tokens.search_all(event.text.to_lower()):
		spoken[token.get_string()] = true
	var eligible: Array[Dictionary] = []
	for entry in _target_history:
		if entry.outcome == "hit" or start_ms < entry.spawned_ms or start_ms + EPSILON >= entry.expires_ms:
			continue
		for form in _aliases.get(entry.target.word.id, []):
			if spoken.has(form):
				eligible.append(entry)
				break
	if eligible.is_empty():
		return removed
	var player_index: int = _identify_player(embedding)
	if player_index < 0:
		return removed
	var player: Dictionary = _players[player_index]
	for entry in eligible:
		entry.outcome = "hit"
		entry.hit_ms = start_ms
		entry.player_index = player_index
		player.hits += 1
		for target in targets.duplicate():
			if target.uid == entry.target.uid:
				targets.erase(target)
	_rebuild_multi_score()
	for entry in eligible:
		var hit: Dictionary = entry.target.duplicate(true)
		hit.age = clampf(elapsed - entry.spawned_ms / 1000.0, 0.0, hit.lifetime)
		hit.points = entry.points
		hit.combo = entry.combo
		hit.player_id = player.id
		hit.player_index = player_index
		hit.player_name = player.name
		hit.player_emoji = player.emoji
		hit.player_avatar_png = player.avatar_png
		removed.append(hit)
	if phase == "running" and targets.is_empty():
		_next_spawn_at = minf(_next_spawn_at, elapsed + 0.65)
	return removed


func players_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in _players:
		result.append(player.duplicate(true))
	return result


func ranking() -> Array[Dictionary]:
	var result: Array[Dictionary] = players_snapshot()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.hits > b.hits if a.hits != b.hits else a.index < b.index)
	var last_hits: int = -1
	var last_rank: int = 0
	for index in range(result.size()):
		if result[index].hits != last_hits:
			last_rank = index + 1
			last_hits = result[index].hits
		result[index].rank = last_rank
	return result


func summary() -> Dictionary:
	return {
		"hits": hits, "misses": misses, "score": score, "best_combo": best_combo,
		"unique_words": hit_words.size(), "hit_words": hit_words.duplicate(true),
		"missed_words": missed_words.duplicate(true), "duration": DURATION, "elapsed": elapsed,
		"play_mode": play_mode, "round_id": round_id, "players": players_snapshot(), "ranking": ranking()
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
	_settling_elapsed = 0.0
	_players.clear()
	_round_profiles.clear()
	_seen_events.clear()
	_target_history.clear()
	_history_by_uid.clear()


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
	var target: Dictionary = {
		"uid": _next_uid, "word": word.duplicate(true), "age": 0.0, "lifetime": lifetime,
		"forms": _aliases[word.id].duplicate(),
		"lane": lane, "x_start": center + _rng.randf_range(-0.02, 0.02),
		"x_end": center + _rng.randf_range(-0.025, 0.025),
		"peak": _rng.randf_range(0.18, 0.45), "spin": _rng.randf_range(-0.14, 0.14)
	}
	targets.append(target)
	if play_mode == "multi":
		var entry: Dictionary = {
			"target": target.duplicate(true), "spawned_ms": elapsed * 1000.0,
			"expires_ms": (elapsed + lifetime) * 1000.0, "outcome": "pending"
		}
		_target_history.append(entry)
		_history_by_uid[_next_uid] = entry
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
		if play_mode == "multi":
			_history_by_uid[target.uid].outcome = "expired"
		else:
			misses += 1
			combo = 0
			_record_word(missed_words, target.word)
		targets.erase(target)
	if play_mode == "multi":
		_rebuild_multi_score()


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _normalized_embedding(value: Variant) -> Array[float]:
	var normalized: Array[float] = []
	if not value is Array and not value is PackedFloat32Array and not value is PackedFloat64Array:
		return normalized
	if value.is_empty() or value.size() > 4096:
		return normalized
	var squared_length: float = 0.0
	for element in value:
		if not _is_number(element) or not is_finite(float(element)):
			return []
		var component: float = float(element)
		squared_length += component * component
		normalized.append(component)
	if not is_finite(squared_length) or squared_length <= EPSILON:
		return []
	var length: float = sqrt(squared_length)
	for index in range(normalized.size()):
		normalized[index] /= length
	return normalized


func _identify_player(embedding: Array[float]) -> int:
	var best_index: int = -1
	var best_similarity: float = -2.0
	var second_similarity: float = -2.0
	for profile_index in range(_round_profiles.size()):
		var profile: Dictionary = _round_profiles[profile_index]
		# Two supporting recordings reduce reliance on one unusually close sample.
		# A legacy profile keeps its original single-template behavior.
		var scores: Array[float] = []
		for template in profile.templates:
			var score: float = 0.0
			for index in range(embedding.size()):
				score += embedding[index] * template[index]
			scores.append(clampf(score, -1.0, 1.0))
		scores.sort()
		var similarity: float = scores[-1]
		if scores.size() > 1:
			similarity = (similarity + scores[-2]) * 0.5
		if similarity > best_similarity:
			second_similarity = best_similarity
			best_index = profile_index
			best_similarity = similarity
		elif similarity > second_similarity:
			second_similarity = similarity
	# Compare against the entire registered library, even profiles that have not
	# hit a word yet. Never turn a weak or ambiguous voice into a new player.
	if best_index < 0 or best_similarity < _speaker_similarity or best_similarity - second_similarity < _speaker_margin:
		return -1
	var matched: Dictionary = _round_profiles[best_index]
	for player in _players:
		if player.id == matched.id:
			return player.index
	if _players.size() >= MAX_PLAYERS:
		return -1
	var player_index: int = _players.size()
	_players.append({"id": matched.id, "name": matched.name, "emoji": matched.emoji,
		"avatar_png": matched.avatar_png, "index": player_index, "hits": 0})
	return player_index


func _rebuild_multi_score() -> void:
	# Recompute in speech-time order so a delayed valid answer replaces its
	# provisional miss and does not corrupt combos or the practice-word list.
	var outcomes: Array[Dictionary] = []
	for entry in _target_history:
		if entry.outcome != "pending":
			outcomes.append(entry)
	outcomes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var time_a: float = a.hit_ms if a.outcome == "hit" else a.expires_ms
		var time_b: float = b.hit_ms if b.outcome == "hit" else b.expires_ms
		return time_a < time_b if time_a != time_b else a.target.uid < b.target.uid)
	hits = 0
	misses = 0
	combo = 0
	best_combo = 0
	score = 0
	hit_words.clear()
	missed_words.clear()
	for entry in outcomes:
		if entry.outcome == "expired":
			misses += 1
			combo = 0
			_record_word(missed_words, entry.target.word)
			continue
		hits += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		entry.points = 10 + mini(combo - 1, 5) * 2
		entry.combo = combo
		score += entry.points
		_record_word(hit_words, entry.target.word)


func _clear_voice_evidence() -> void:
	_round_profiles.clear()
	_target_history.clear()
	_history_by_uid.clear()
	_seen_events.clear()


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
