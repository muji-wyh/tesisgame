extends Control
## Presentation only: the model commits fragments before this timeline starts.

signal cue_requested(cue: String)

const Style = preload("res://scripts/ui_style.gd")
const Progress = preload("res://scripts/jelly_reward_progress.gd")
const RewardConfetti = preload("res://scripts/reward_confetti.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const ARRIVAL_SECONDS: float = 0.65
const REVEAL_SECONDS: float = 0.72
const PERFORMANCE_SECONDS: float = 2.15

var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_instance_valid(_confetti):
			_sync_confetti()
			_layout()
			queue_redraw()
var _events: Array[Dictionary] = []
var _elapsed: float = 0.0
var _serial: int = 0
var _started: bool = false
var _revealed: bool = false
var _heading: Label
var _caption: Label
var _confetti: RewardConfetti


func _init() -> void:
	name = "JellyChestCelebration"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	_heading = Style.label("", 30)
	_caption = Style.label("", 18)
	for label: Label in [_heading, _caption]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)
	_heading.add_theme_font_override("font", Style.HEADING_FONT)
	_heading.add_theme_color_override("font_color", Color("#fff6dd"))
	_caption.add_theme_color_override("font_color", Color("#ecfff5"))
	_confetti = RewardConfetti.new()
	add_child(_confetti)
	resized.connect(_layout)
	hide()


func enqueue(previous_tier: int, tier: int, before: Texture2D, after: Texture2D) -> void:
	if tier <= previous_tier:
		return
	_events.append({"previous_tier": previous_tier, "tier": tier, "before": before, "after": after})
	if _events.size() == 1:
		_elapsed = 0.0
		_started = false
		_revealed = false
		_sync()


func is_active() -> bool:
	return not _events.is_empty()


func clear() -> void:
	_serial += 1
	_events.clear()
	_elapsed = 0.0
	_started = false
	_revealed = false
	_confetti.hide()
	hide()
	queue_redraw()


func advance(delta: float, pickup_ready: bool = true) -> float:
	if not is_finite(delta) or delta <= 0.0:
		return 0.0
	var generation: int = _serial
	var remaining: float = delta
	while is_active() and remaining > 0.0 and generation == _serial:
		var boundary: float = ARRIVAL_SECONDS if not _started else ARRIVAL_SECONDS + REVEAL_SECONDS if not _revealed else ARRIVAL_SECONDS + PERFORMANCE_SECONDS
		var consume: float = minf(remaining, maxf(0.0, boundary - _elapsed))
		_elapsed += consume
		remaining -= consume
		if not _started and _elapsed >= ARRIVAL_SECONDS:
			if not pickup_ready:
				_sync()
				return 0.0
			_started = true
			cue_requested.emit("assemble")
			if generation != _serial or not is_active():
				return 0.0
		if not _revealed and _elapsed >= ARRIVAL_SECONDS + REVEAL_SECONDS:
			_revealed = true
			cue_requested.emit("reward")
			if generation != _serial or not is_active():
				return 0.0
		if _elapsed >= ARRIVAL_SECONDS + PERFORMANCE_SECONDS:
			_events.pop_front()
			_elapsed = 0.0
			_started = false
			_revealed = false
	_sync()
	return remaining


func _sync() -> void:
	visible = is_active() and _started
	_sync_confetti()
	if is_active():
		var event: Dictionary = _events[0]
		_heading.text = "Chest upgraded!" if int(event.previous_tier) > 0 else "Chest unlocked!"
		_caption.text = Progress.title_for_tier(int(event.tier))
	_layout()
	queue_redraw()


func _sync_confetti() -> void:
	var age: float = _elapsed - ARRIVAL_SECONDS
	_confetti.sample(age - REVEAL_SECONDS if is_active() and _revealed and not reduced_motion else -1.0,
		PERFORMANCE_SECONDS - REVEAL_SECONDS, 1.0 - smoothstep(1.91, PERFORMANCE_SECONDS, age))


func _layout() -> void:
	var unit: float = 1.0 / Style.ui_scale(self)
	var compact: bool = size.y < 280.0 * unit
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var edge: float = minf(250.0 * unit, minf(size.x * 0.62, size.y * 0.56))
	_heading.position = Vector2(0, maxf(4.0 * unit, center.y - edge * 0.63 - 42.0 * unit))
	_heading.size = Vector2(size.x, 38.0 * unit)
	_heading.add_theme_font_size_override("font_size", ceili((23.0 if compact else 30.0) * unit))
	_caption.position = Vector2(0, minf(size.y - 34.0 * unit, center.y + edge * 0.58))
	_caption.size = Vector2(size.x, 30.0 * unit)
	_caption.add_theme_font_size_override("font_size", ceili(18.0 * unit))
	if is_active():
		var age: float = maxf(0.0, _elapsed - ARRIVAL_SECONDS)
		var opacity: float = 1.0 if reduced_motion else smoothstep(REVEAL_SECONDS - 0.1, REVEAL_SECONDS + 0.12, age)
		_heading.modulate.a = opacity
		_caption.modulate.a = opacity


func _texture_rect(texture: Texture2D, center: Vector2, edge: float) -> Rect2:
	if texture == null:
		return Rect2()
	var dimensions: Vector2 = texture.get_size()
	var fit: Vector2 = dimensions * edge / maxf(dimensions.x, dimensions.y)
	return Rect2(center - fit * 0.5, fit)


func _draw() -> void:
	if not is_active() or not _started:
		return
	var event: Dictionary = _events[0]
	var age: float = _elapsed - ARRIVAL_SECONDS
	var unit: float = 1.0 / Style.ui_scale(self)
	var edge: float = minf(250.0 * unit, minf(size.x * 0.62, size.y * 0.56))
	var center: Vector2 = size * 0.5
	var fade: float = 1.0 if reduced_motion else smoothstep(0.0, 0.16, age) * (1.0 - smoothstep(1.91, PERFORMANCE_SECONDS, age))
	draw_style_box(Style.box(Color("#143b36", 0.93 * fade), Color.TRANSPARENT, 22), Rect2(Vector2.ZERO, size))
	var after: Texture2D = event.after
	var before: Texture2D = event.before
	var upgrade: bool = int(event.previous_tier) > 0
	if reduced_motion:
		if after != null:
			draw_texture_rect(after, _texture_rect(after, center, edge), false)
		return
	var reveal: float = clampf((age - REVEAL_SECONDS) / 0.4, 0.0, 1.0)
	var light: float = sin(clampf((age - 0.25) / 1.1, 0.0, 1.0) * PI)
	var glow_edge: float = edge * lerpf(1.0, 2.15, reveal)
	draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * glow_edge * 0.5, Vector2.ONE * glow_edge), false,
		Color("#ffdc8d", light * 0.86 * fade))
	if not upgrade and age < REVEAL_SECONDS:
		_draw_pieces(after, center, edge, age / REVEAL_SECONDS, fade)
	else:
		var texture: Texture2D = before if age < REVEAL_SECONDS else after
		if texture != null:
			var anticipation: float = smoothstep(0.0, 0.2, age) * (1.0 - smoothstep(0.2, 0.4, age))
			var lift: float = sin(clampf((age - 0.2) / 0.98, 0.0, 1.0) * PI)
			var landing: float = sin(clampf((age - 1.18) / 0.28, 0.0, 1.0) * PI) * 0.035
			var point: Vector2 = center + Vector2(0.0, edge * (anticipation * 0.025 - lift * 0.17 - landing))
			var turn: float = sin(clampf(age / 1.2, 0.0, 1.0) * TAU) * 0.1
			var scale_amount: float = 1.0 + sin(reveal * PI) * 0.1
			draw_set_transform(point, turn, Vector2.ONE * scale_amount)
			draw_texture_rect(texture, _texture_rect(texture, Vector2.ZERO, edge), false, Color(1, 1, 1, fade))
			draw_set_transform(Vector2.ZERO)


func _draw_pieces(texture: Texture2D, center: Vector2, edge: float, progress: float, opacity: float) -> void:
	if texture == null:
		return
	var target: Rect2 = _texture_rect(texture, center, edge)
	var join: float = smoothstep(0.08, 0.91, progress)
	for index in range(4):
		var quadrant := Vector2(index % 2, floorf(float(index) / 2.0))
		var direction: Vector2 = quadrant * 2.0 - Vector2.ONE
		var offset: Vector2 = direction * edge * 0.40 * (1.0 - join)
		var rect := Rect2(target.position + quadrant * target.size * 0.5 + offset, target.size * 0.5)
		var source := Rect2(quadrant * texture.get_size() * 0.5, texture.get_size() * 0.5)
		draw_texture_rect_region(texture, rect, source, Color(1, 1, 1, opacity))


func snapshot() -> Dictionary:
	return {"active": is_active(), "visible": visible, "elapsed": _elapsed,
		"tier": int(_events[0].tier) if is_active() else 0,
		"kind": ("upgrade" if int(_events[0].previous_tier) > 0 else "synthesis") if is_active() else "none",
		"revealed": _revealed, "queued": _events.size(), "reduced_motion": reduced_motion,
		"confetti": _confetti.is_visible_in_tree(),
		"confetti_rect": _screen_bounds()}


func _screen_bounds() -> Array:
	var screen: Rect2 = _confetti.get_global_transform_with_canvas() * _confetti.screen_rect()
	return [screen.position.x, screen.position.y, screen.size.x, screen.size.y]
