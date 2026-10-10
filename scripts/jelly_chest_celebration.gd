extends Control
## Presentation only: the model commits fragments before this timeline starts.

signal cue_requested(cue: String)
signal confetti_requested

const RewardModel = preload("res://scripts/chest_reward_model.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const ARRIVAL_SECONDS: float = 0.65
const REVEAL_SECONDS: float = 0.72
const PERFORMANCE_SECONDS: float = 2.15

var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_instance_valid(_models):
			_sync()
var _events: Array[Dictionary] = []
var _elapsed: float = 0.0
var _serial: int = 0
var _started: bool = false
var _revealed: bool = false
var _anchor := Rect2()
var _models: RewardModel
var _model_sample: Dictionary = {}


func _init() -> void:
	name = "JellyChestCelebration"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	_models = RewardModel.new()
	add_child(_models)
	visibility_changed.connect(_update_model_visibility)
	hide()


func set_chest_anchor(rect: Rect2) -> void:
	# The owner supplies its existing HUD chest bounds, never a gameplay modal.
	_anchor = rect
	queue_redraw()


func enqueue(previous_tier: int, tier: int, before: Texture2D, after: Texture2D) -> void:
	if tier <= previous_tier:
		return
	_events.append({"previous_tier": previous_tier, "tier": tier, "before": before, "after": after})
	if _events.size() == 1:
		_elapsed = 0.0
		_started = false
		_revealed = false
		_prepare_models()
		_sync()


func is_active() -> bool:
	return not _events.is_empty()


func clear() -> void:
	_serial += 1
	_events.clear()
	_elapsed = 0.0
	_started = false
	_revealed = false
	_model_sample.clear()
	_models.clear()
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
			if not reduced_motion:
				confetti_requested.emit()
				if generation != _serial or not is_active():
					return 0.0
			cue_requested.emit("reward")
			if generation != _serial or not is_active():
				return 0.0
		if _elapsed >= ARRIVAL_SECONDS + PERFORMANCE_SECONDS:
			_events.pop_front()
			_elapsed = 0.0
			_started = false
			_revealed = false
			_prepare_models()
	_sync()
	return remaining


func _sync() -> void:
	visible = is_active() and _started
	_update_model_visibility()
	_model_sample.clear()
	if visible and not reduced_motion:
		var event: Dictionary = _events[0]
		var age: float = _elapsed - ARRIVAL_SECONDS
		var tier: int = int(event.tier) if _revealed else int(event.previous_tier)
		if tier > 0:
			_model_sample = _models.sample(tier, _motion(age).yaw)
	queue_redraw()


func _prepare_models() -> void:
	if not is_active() or reduced_motion:
		return
	_models.prepare(int(_events[0].previous_tier))
	_models.prepare(int(_events[0].tier))


func _update_model_visibility() -> void:
	if is_instance_valid(_models):
		_models.set_active(is_visible_in_tree() and not reduced_motion)


func _texture_rect(texture: Texture2D, center: Vector2, edge: float) -> Rect2:
	if texture == null:
		return Rect2()
	var dimensions: Vector2 = texture.get_size()
	var fit: Vector2 = dimensions * edge / maxf(dimensions.x, dimensions.y)
	return Rect2(center - fit * 0.5, fit)


func _motion(age: float) -> Dictionary:
	# A rigid hop and a real yaw replace the old sticker wobble. The material
	# changes at the back-facing apex, on the same cue as the rings and paper.
	var turn: float = smoothstep(0.18, 1.26, age)
	var lift: float = sin(clampf((age - 0.18) / 1.08, 0.0, 1.0) * PI) * 0.30
	var anticipation: float = sin(clampf(age / 0.18, 0.0, 1.0) * PI)
	var settle: float = sin(clampf((age - 1.26) / 0.26, 0.0, 1.0) * PI) * 0.035
	var growth: float = 1.50 if is_active() and int(_events[0].previous_tier) > 0 else 0.48
	return {"yaw": turn * TAU, "lift": lift + settle - anticipation * 0.025,
		"scale": 1.0 + smoothstep(0.10, 0.48, age) * (1.0 - smoothstep(1.0, 1.72, age)) * growth,
		"roll": -anticipation * 0.10 + sin(turn * TAU) * 0.055}


func _placement(pose: Dictionary, edge: float, center: Vector2) -> Dictionary:
	var local := Rect2(Vector2.ONE * -edge * 0.5, Vector2.ONE * edge)
	if not _model_sample.is_empty():
		var framing: Rect2 = _model_sample.bounds
		var turned: Rect2 = _model_sample.turn_bounds
		var unit: float = edge / maxf(framing.size.x, framing.size.y)
		local = local.merge(Rect2((turned.position - framing.get_center()) * unit, turned.size * unit))
	var scale: float = float(pose.scale)
	var transform := Transform2D(float(pose.roll), Vector2.ONE * scale, 0.0, Vector2.ZERO)
	var bounds: Rect2 = transform * local
	# Fit the real turned silhouette, including its roll, at either HUD edge.
	var available: Vector2 = (size - Vector2.ONE * 4.0).max(Vector2.ONE)
	var fit: float = minf(1.0, minf(available.x / bounds.size.x, available.y / bounds.size.y))
	scale *= fit
	bounds = Rect2(bounds.position * fit, bounds.size * fit)
	var point: Vector2 = center - Vector2(0, edge * float(pose.lift))
	point = point.clamp(Vector2.ONE * 2.0 - bounds.position, size - Vector2.ONE * 2.0 - bounds.end)
	return {"center": point, "scale": scale}


func _draw() -> void:
	if not is_active() or not _started or not _anchor.has_area():
		return
	var event: Dictionary = _events[0]
	var age: float = _elapsed - ARRIVAL_SECONDS
	var edge: float = minf(_anchor.size.x, _anchor.size.y)
	var center: Vector2 = _anchor.get_center()
	var after: Texture2D = event.after
	var before: Texture2D = event.before
	if reduced_motion:
		var still: Texture2D = after if _revealed else before
		if still != null:
			draw_texture_rect(still, _texture_rect(still, center, edge), false)
		return
	var pose: Dictionary = _motion(age)
	var accent: Color = _tier_color(int(event.tier))
	var fade: float = smoothstep(0.0, 0.10, age) * (1.0 - smoothstep(1.70, PERFORMANCE_SECONDS, age))
	var reveal_age: float = age - REVEAL_SECONDS
	var placement: Dictionary = _placement(pose, edge, center)
	var point: Vector2 = placement.center
	var accent_edge: float = edge * lerpf(1.0, float(placement.scale), 0.45) if int(event.previous_tier) > 0 else edge
	var floor_point: Vector2 = Vector2(point.x, center.y + edge * 0.36)
	_draw_glow(floor_point, Vector2(edge * 1.42, edge * 0.30), Color("#193c47", 0.20 * fade))
	_draw_ring(floor_point, Vector2(edge * 0.66, edge * 0.16), accent, fade * 0.85)
	var charge: float = smoothstep(0.22, REVEAL_SECONDS, age) * (1.0 - smoothstep(REVEAL_SECONDS, 1.28, age))
	_draw_glow(point, Vector2.ONE * accent_edge * (1.35 + charge), Color(accent, charge * 0.64))
	if reveal_age >= 0.0:
		var rays: float = (1.0 - smoothstep(0.05, 0.85, reveal_age)) * fade
		draw_set_transform(point, reveal_age * 0.20)
		draw_texture_rect(RAYS, Rect2(Vector2.ONE * -accent_edge * 1.38, Vector2.ONE * accent_edge * 2.76), false, Color(accent.lightened(0.25), rays))
		draw_set_transform(Vector2.ZERO)
		for index in range(2):
			var ripple: float = reveal_age - float(index) * 0.11
			if ripple < 0.0 or ripple >= 0.76:
				continue
			var radius: float = accent_edge * lerpf(0.36, 1.34, 1.0 - pow(1.0 - ripple / 0.76, 2.0))
			_draw_ring(point, Vector2.ONE * radius, accent, (1.0 - ripple / 0.76) * 0.85)
	if int(event.previous_tier) == 0 and not _revealed:
		_draw_pieces(after, point, edge * float(placement.scale), age / REVEAL_SECONDS)
	else:
		draw_set_transform(point, float(pose.roll), Vector2.ONE * float(placement.scale))
		var texture: Texture2D = after if _revealed else before
		var model_weight: float = smoothstep(0.12, 0.24, age) * (1.0 - smoothstep(1.32, 1.55, age))
		if _model_sample.is_empty():
			model_weight = 0.0
		if texture != null and model_weight < 1.0:
			draw_texture_rect(texture, _texture_rect(texture, Vector2.ZERO, edge), false, Color(1, 1, 1, 1.0 - model_weight))
		if model_weight > 0.0:
			var bounds: Rect2 = _model_sample.bounds
			var unit: float = edge / maxf(bounds.size.x, bounds.size.y)
			draw_texture_rect(_model_sample.texture, Rect2(-bounds.get_center() * unit, Vector2.ONE * 1024.0 * unit), false, Color(1, 1, 1, model_weight))
		draw_set_transform(Vector2.ZERO)
	if reveal_age >= 0.0:
		# The short local flash hides only the material swap, never the board.
		var flash: float = 1.0 - smoothstep(0.0, 0.18, reveal_age)
		_draw_glow(point, Vector2.ONE * accent_edge * 1.85, Color(accent.lightened(0.72), flash * 0.94))
		for index in range(5):
			var t: float = reveal_age - 0.055 * index
			if t < 0.0 or t >= 0.64:
				continue
			var direction := Vector2.from_angle(-PI * 0.85 + index * 1.08)
			var star_point: Vector2 = point + direction * accent_edge * (0.65 + t * 0.40)
			var star_size: float = edge * 0.34 * sin(t / 0.64 * PI)
			draw_texture_rect(SPARKLE, Rect2(star_point - Vector2.ONE * star_size * 0.5, Vector2.ONE * star_size), false, Color(accent.lightened(0.6), (1.0 - t / 0.64) * fade))


func _tier_color(tier: int) -> Color:
	var colors: Array[Color] = [Color("#72e8c1"), Color("#ffd777"), Color("#75e5ff"), Color("#bc9dff"), Color("#ffcf65"), Color("#95d6ff")]
	return colors[clampi(tier - 1, 0, colors.size() - 1)]


func _draw_glow(center: Vector2, extent: Vector2, color: Color) -> void:
	draw_texture_rect(GLOW, Rect2(center - extent * 0.5, extent), false, color)


func _draw_ring(center: Vector2, radius: Vector2, color: Color, opacity: float) -> void:
	# Light contours support the sourced chest and rays; they are not new props.
	var points := PackedVector2Array()
	for index in range(65):
		points.append(center + Vector2.from_angle(float(index) / 64.0 * TAU) * radius)
	draw_polyline(points, Color(color, opacity * 0.14), 5.0, true)
	draw_polyline(points, Color(color, opacity * 0.36), 2.5, true)
	draw_polyline(points, Color(color.lightened(0.60), opacity), 0.85, true)


func _draw_pieces(texture: Texture2D, center: Vector2, edge: float, progress: float) -> void:
	if texture == null:
		return
	var target: Rect2 = _texture_rect(texture, Vector2.ZERO, edge)
	for index in range(4):
		var quadrant := Vector2(index % 2, floorf(float(index) / 2.0))
		var direction: Vector2 = quadrant * 2.0 - Vector2.ONE
		var join: float = smoothstep(0.05 + index * 0.055, 0.98, progress)
		var source := Rect2(quadrant * texture.get_size() * 0.5, texture.get_size() * 0.5)
		var pivot: Vector2 = target.position + (quadrant + Vector2.ONE * 0.5) * target.size * 0.5
		var offset: Vector2 = direction * edge * 0.35 * (1.0 - join)
		offset.y += sin(join * PI) * edge * -0.18
		draw_set_transform(center + pivot + offset, direction.x * (1.0 - join) * 0.20)
		draw_texture_rect_region(texture, Rect2(-target.size * 0.25, target.size * 0.5), source, Color(1, 1, 1, smoothstep(0.0, 0.18, progress)))
		draw_set_transform(Vector2.ZERO)


func snapshot() -> Dictionary:
	return {"active": is_active(), "visible": visible, "elapsed": _elapsed,
		"tier": int(_events[0].tier) if is_active() else 0,
		"kind": ("upgrade" if int(_events[0].previous_tier) > 0 else "synthesis") if is_active() else "none",
		"revealed": _revealed, "queued": _events.size(), "reduced_motion": reduced_motion,
		"anchor": [_anchor.position.x, _anchor.position.y, _anchor.size.x, _anchor.size.y]}
