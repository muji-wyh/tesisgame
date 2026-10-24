extends Control
## Independent reading bursts, advanced by the same clock as collection.

const Card = preload("res://scripts/word_jelly_word_reveal_card.gd")
const WordModel = preload("res://scripts/word_jelly_model.gd")
const SECONDS: float = 1.95
const BATCH_SECONDS: float = 0.86

var _entries: Array[Card] = []
var _rng := RandomNumberGenerator.new()
var _serial: int = 0
var _reduced_motion: bool = false
var _ui_scale: float = 1.0
var _exclusions: Array[Rect2] = []


func _init() -> void:
	name = "WordJellyWordReveal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 55
	_rng.randomize()
	hide()


func configure_layout(available: Rect2, ui_scale: float, exclusions: Array[Rect2] = []) -> void:
	var next_scale: float = maxf(0.5, ui_scale)
	if get_rect() == available and _ui_scale == next_scale and _exclusions == exclusions:
		return
	position = available.position
	size = available.size.max(Vector2.ZERO)
	_ui_scale = next_scale
	_exclusions = exclusions.duplicate()
	var placed: Array[Card] = []
	for entry: Card in _entries:
		entry.fit_content(size, _ui_scale)
		_place(entry, placed)
		placed.append(entry)
		entry.sync()


func present(word: Dictionary, picture: Texture2D, accent: Color, batch: bool = false, initial_age: float = 0.0, level: int = 1, delay: float = 0.0) -> void:
	if str(word.get("text", "")).strip_edges().is_empty():
		return
	var seconds: float = BATCH_SECONDS if batch else SECONDS
	if batch and size.y * _ui_scale < 180.0:
		seconds = 0.48
	elif batch and size.x * _ui_scale < 520.0:
		seconds = 0.62
	if not is_finite(initial_age) or not is_finite(delay):
		return
	# Both jellies charge together; the full reading lifetime starts on release.
	var age: float = maxf(0.0, initial_age) - maxf(0.0, delay)
	if age >= seconds:
		return
	_serial += 1
	var variation: float = _rng.randf_range(0.82, 1.18)
	if not _entries.is_empty() and absf(variation - _entries.back().variant_scale) < 0.10:
		variation = 0.84 if _entries.back().variant_scale > 1.0 else 1.16
	var entry := Card.new()
	add_child(entry)
	entry.configure(_serial, word, picture, accent, batch, variation, seconds, _reduced_motion, clampi(level, 1, WordModel.MAX_MERGE_LEVEL))
	entry.anticipation_seconds = maxf(0.0, delay)
	entry.fit_content(size, _ui_scale)
	_place(entry, _entries)
	entry.elapsed = age
	_entries.append(entry)
	entry.sync()
	show()


func _place(entry: Card, occupied: Array[Card]) -> void:
	# Reserve the entire squash/stretch envelope and the level-specific effect halo.
	var margin := Vector2.ONE * entry.effect_margin()
	var envelope: Vector2 = entry.size * 1.22 + margin * 2.0
	var room: Vector2 = (size - envelope).max(Vector2.ZERO)
	var best := Rect2(margin, entry.size)
	var best_excluded_area: float = INF
	var best_score: float = INF
	for attempt in range(72):
		var anchor := Vector2(_rng.randf(), _rng.randf())
		if attempt < 16:
			anchor = (Vector2(_rng.randi_range(0, 1), _rng.randi_range(0, 1))
				+ (anchor - Vector2.ONE * 0.5) * 0.10).clamp(Vector2.ZERO, Vector2.ONE)
		elif attempt < 40:
			# Jittered edge/center bands leave usable gaps for the next beats.
			anchor = (Vector2(_rng.randi_range(0, 2), _rng.randi_range(0, 2)) * 0.5
				+ (anchor - Vector2.ONE * 0.5) * 0.18).clamp(Vector2.ZERO, Vector2.ONE)
		var candidate := Rect2(room * anchor, envelope)
		var candidate_rest: Vector2 = candidate.get_center() - entry.size * 0.5
		var spelling := Rect2(candidate_rest + entry._spelling.position, entry._spelling.size)
		var excluded_area: float = 0.0
		var score: float = 0.0
		for exclusion: Rect2 in _exclusions:
			var local := Rect2(exclusion.position - position, exclusion.size)
			excluded_area += candidate.intersection(local).get_area()
		for other: Card in occupied:
			var other_margin := Vector2.ONE * other.effect_margin()
			var bounds := Rect2(other.rest_position - other.size * 0.11 - other_margin,
				other.size * 1.22 + other_margin * 2.0)
			var tail: float = 1.0 - smoothstep(other.duration - 0.22, other.duration, other.elapsed)
			score += candidate.intersection(bounds).get_area() * lerpf(0.12, 1.0, tail)
			var other_spelling := Rect2(other.rest_position + other._spelling.position, other._spelling.size)
			score += (candidate.intersection(other_spelling).get_area()
				+ bounds.intersection(spelling).get_area()) * 12.0 * tail
			if other == occupied.back():
				var separation: float = candidate.get_center().distance_to(bounds.get_center())
				score += maxf(0.0, minf(size.x, size.y) * 0.48 - separation) * 16.0
		# Readable controls take priority even during a crowded collection run.
		if excluded_area < best_excluded_area or (is_equal_approx(excluded_area, best_excluded_area) and score < best_score):
			best_excluded_area = excluded_area
			best_score = score
			best = candidate
		if excluded_area <= 0.0 and score <= 0.0:
			break
	entry.rest_position = best.get_center() - entry.size * 0.5


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for index in range(_entries.size() - 1, -1, -1):
		var entry: Card = _entries[index]
		entry.elapsed += delta
		if entry.elapsed >= entry.duration:
			_entries.remove_at(index)
			entry.free()
		else:
			entry.sync()
	visible = not _entries.is_empty()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	for entry: Card in _entries:
		entry.reduced_motion = value
		entry.sync()


func reset() -> void:
	for entry: Card in _entries:
		entry.free()
	_entries.clear()
	hide()


func snapshot() -> Dictionary:
	var states: Array[Dictionary] = []
	for entry: Card in _entries:
		states.append(entry.snapshot())
	var latest: Dictionary = states.back().duplicate(true) if not states.is_empty() else {
		"word_id": "", "word": {}, "picture": "", "spelling": "", "elapsed": 0.0,
		"duration": SECONDS, "rect": [], "resting_rect": [], "picture_rect": [],
		"spelling_rect": [], "content_alpha": 0.0, "reduced_motion": _reduced_motion,
		"merge_level": 1, "effects": {}}
	latest["visible"] = visible and states.any(func(entry: Dictionary) -> bool: return bool(entry.visible))
	latest["entries"] = states
	latest["active_count"] = states.size()
	return latest
