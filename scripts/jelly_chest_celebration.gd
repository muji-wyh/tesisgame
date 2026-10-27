extends Control
## Presentation only: the model commits fragments before this timeline starts.

signal cue_requested(cue: String)
signal confetti_requested

const RewardModel = preload("res://scripts/chest_reward_model.gd")
const Flight = preload("res://scripts/chest_reward_flight.gd")
const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const ARRIVAL_SECONDS: float = 0.65
const REVEAL_SECONDS: float = Flight.REVEAL_SECONDS
const PERFORMANCE_SECONDS: float = Flight.PERFORMANCE_SECONDS
const TURN_SECONDS: float = Flight.TURN_END - Flight.TURN_START

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
var _paused: bool = false
var _anchor := Rect2()
var _models: RewardModel
var _model_sample: Dictionary = {}
var _model_bounds := Rect2()
var _journey_peak: float = 176.0
var _continuous_turns: bool = false
var _completed_turns: int = 0
var _reveal_effect_elapsed: float = 10.0
var _reveal_effect_tier: int = 0
var _flight_layer := CanvasLayer.new()
var _flight_surface := Node2D.new()


func _init() -> void:
	name = "JellyChestCelebration"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	_models = RewardModel.new()
	add_child(_models)
	# The flight crosses the bounded game area, including Voice Pop's clip.
	_flight_layer.layer = 70
	add_child(_flight_layer)
	_flight_layer.add_child(_flight_surface)
	_flight_surface.draw.connect(_draw_flight)
	visibility_changed.connect(_update_model_visibility)
	hide()


func set_chest_anchor(rect: Rect2) -> void:
	# The owner supplies its existing HUD chest bounds, never a gameplay modal.
	_anchor = rect
	_sync_flight_layer()


func enqueue(previous_tier: int, tier: int, before: Texture2D, after: Texture2D) -> void:
	if tier <= previous_tier:
		return
	_events.append({"previous_tier": previous_tier, "tier": tier, "before": before, "after": after})
	if _events.size() == 1:
		_elapsed = 0.0
		_started = false
		_revealed = false
		_journey_peak = 216.0 if previous_tier > 0 else 176.0
		_continuous_turns = false
		_completed_turns = 0
		_reveal_effect_elapsed = 10.0
		_prepare_models()
		_sync()
	elif _elapsed <= ARRIVAL_SECONDS + Flight.RETURN_START:
		_continuous_turns = true


func is_active() -> bool:
	return not _events.is_empty()


func set_paused(value: bool) -> void:
	_paused = value
	_sync()


func clear() -> void:
	_serial += 1
	_events.clear()
	_elapsed = 0.0
	_started = false
	_revealed = false
	_paused = false
	_continuous_turns = false
	_completed_turns = 0
	_reveal_effect_elapsed = 10.0
	_model_sample.clear()
	_model_bounds = Rect2()
	_models.clear()
	hide()
	_sync_flight_layer()


func advance(delta: float, pickup_ready: bool = true) -> float:
	if _paused or not is_finite(delta) or delta <= 0.0:
		return 0.0
	var generation: int = _serial
	var remaining: float = delta
	while is_active() and remaining > 0.0 and generation == _serial:
		var chained: bool = _events.size() > 1 and _elapsed <= ARRIVAL_SECONDS + Flight.RETURN_START
		var reveal_at: float = ARRIVAL_SECONDS + (Flight.TURN_END if _continuous_turns else REVEAL_SECONDS)
		var finish: float = reveal_at if chained and _continuous_turns \
			else ARRIVAL_SECONDS + (Flight.RETURN_START if chained else PERFORMANCE_SECONDS)
		var boundary: float = ARRIVAL_SECONDS if not _started else reveal_at if not _revealed else finish
		var consume: float = minf(remaining, maxf(0.0, boundary - _elapsed))
		_elapsed += consume
		_reveal_effect_elapsed += consume
		remaining -= consume
		if not _started and _elapsed >= ARRIVAL_SECONDS:
			if not pickup_ready:
				_sync()
				return 0.0
			_started = true
			cue_requested.emit("assemble")
			if generation != _serial or not is_active():
				return 0.0
		if not _revealed and _elapsed >= reveal_at:
			_revealed = true
			_reveal_effect_elapsed = 0.0
			_reveal_effect_tier = int(_events[0].tier)
			if not reduced_motion:
				confetti_requested.emit()
				if generation != _serial or not is_active():
					return 0.0
			cue_requested.emit("reward")
			if generation != _serial or not is_active():
				return 0.0
		if _revealed and chained and _elapsed >= finish:
			if not pickup_ready:
				_sync()
				return 0.0
			_events.pop_front()
			_elapsed = ARRIVAL_SECONDS + (Flight.TURN_START if _continuous_turns else Flight.TOP_SECONDS)
			if _continuous_turns:
				_completed_turns += 1
			_revealed = false
			_prepare_models()
			if not _continuous_turns:
				cue_requested.emit("assemble")
				if generation != _serial or not is_active():
					return 0.0
		elif _elapsed >= ARRIVAL_SECONDS + PERFORMANCE_SECONDS:
			if _continuous_turns and _revealed:
				_completed_turns += 1
			_events.pop_front()
			_elapsed = 0.0
			_started = false
			_revealed = false
			_prepare_models()
	_sync()
	return remaining


func _sync() -> void:
	visible = is_active() and _started and not _paused
	_update_model_visibility()
	_model_sample.clear()
	_model_bounds = Rect2()
	if visible and not reduced_motion:
		var event: Dictionary = _events[0]
		var age: float = _elapsed - ARRIVAL_SECONDS
		var tier: int = int(event.tier) if _revealed or int(event.previous_tier) == 0 else int(event.previous_tier)
		if tier > 0 and int(event.tier) <= 4:
			var pose: Dictionary = _motion(age)
			# Both shapes share the same fitting envelope before and after the swap.
			# This keeps an edge-clamped flight reversible when their silhouettes differ.
			for model_tier: int in [int(event.previous_tier), int(event.tier)]:
				var model_pose: Dictionary = _models.sample(model_tier, pose.yaw, pose.pitch)
				if model_pose.is_empty():
					continue
				if model_tier == tier:
					_model_sample = model_pose
				var framing: Rect2 = model_pose.bounds
				var turned: Rect2 = model_pose.turn_bounds
				var unit: float = 1.0 / maxf(framing.size.x, framing.size.y)
				_model_bounds = _model_bounds.merge(Rect2((turned.position - framing.get_center()) * unit, turned.size * unit))
	_sync_flight_layer()


func _prepare_models() -> void:
	if not is_active() or reduced_motion or int(_events[0].tier) > 4:
		return
	_models.prepare(int(_events[0].previous_tier))
	_models.prepare(int(_events[0].tier))


func _update_model_visibility() -> void:
	if is_instance_valid(_models):
		_models.set_active(is_visible_in_tree() and not reduced_motion)
	_sync_flight_layer()


func _sync_flight_layer() -> void:
	_flight_layer.visible = is_inside_tree() and is_visible_in_tree()
	if is_inside_tree():
		_flight_layer.transform = get_global_transform_with_canvas()
	_flight_surface.queue_redraw()


func _flight_bounds() -> Rect2:
	if not is_inside_tree():
		return Rect2(Vector2.ZERO, size).grow(-2.0)
	return (get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()).grow(-2.0)


func _texture_rect(texture: Texture2D, center: Vector2, edge: float) -> Rect2:
	if texture == null:
		return Rect2()
	var dimensions: Vector2 = texture.get_size()
	var fit: Vector2 = dimensions * edge / maxf(dimensions.x, dimensions.y)
	return Rect2(center - fit * 0.5, fit)


func _motion(age: float) -> Dictionary:
	var edge: float = minf(_anchor.size.x, _anchor.size.y)
	var held_age: float = minf(age, Flight.RETURN_START - 0.000001) \
		if _events.size() > 1 and age <= Flight.RETURN_START + 0.000001 else age
	var pose: Dictionary = Flight.sample(held_age, _anchor.get_center(), _flight_bounds(), edge,
		_journey_peak / Style.ui_scale(self), true)
	if _continuous_turns:
		pose.yaw = (float(_completed_turns) + clampf((age - Flight.TURN_START) / TURN_SECONDS, 0.0, 1.0)) * TAU
		pose.sprite_scale_x = cos(float(pose.yaw))
	return pose


func _placement(pose: Dictionary, edge: float, _center: Vector2) -> Dictionary:
	var local := Rect2(Vector2.ONE * -edge * 0.5, Vector2.ONE * edge)
	if _model_bounds.has_area():
		local = local.merge(Rect2(_model_bounds.position * edge, _model_bounds.size * edge))
	return Flight.fit(pose, local, _flight_bounds())


func _draw_flight() -> void:
	if not is_active() or not _started or not _anchor.has_area():
		return
	var event: Dictionary = _events[0]
	var age: float = _elapsed - ARRIVAL_SECONDS
	var edge: float = minf(_anchor.size.x, _anchor.size.y)
	var center: Vector2 = _anchor.get_center()
	var after: Texture2D = event.after
	var before: Texture2D = event.before
	if reduced_motion:
		var still: Texture2D = after if _revealed or int(event.previous_tier) == 0 else before
		if still != null:
			_flight_surface.draw_texture_rect(still, _texture_rect(still, center, edge), false)
		return
	var pose: Dictionary = _motion(age)
	var accent: Color = _tier_color(_reveal_effect_tier if _reveal_effect_elapsed < 0.85 else int(event.tier))
	var fade: float = float(pose.emphasis)
	var reveal_age: float = _reveal_effect_elapsed if _reveal_effect_elapsed < 0.85 else -1.0
	var placement: Dictionary = _placement(pose, edge, center)
	var point: Vector2 = placement.center
	var accent_edge: float = edge * float(placement.scale)
	var charge: float = smoothstep(Flight.TOP_SECONDS, REVEAL_SECONDS, age) * (1.0 - smoothstep(REVEAL_SECONDS, Flight.TURN_END, age))
	_draw_glow(point, Vector2.ONE * accent_edge * (1.35 + charge), Color(accent, charge * 0.64))
	if reveal_age >= 0.0:
		var rays: float = (1.0 - smoothstep(0.05, 0.85, reveal_age)) * fade
		_flight_surface.draw_set_transform(point, reveal_age * 0.20)
		_flight_surface.draw_texture_rect(RAYS, Rect2(Vector2.ONE * -accent_edge * 1.38, Vector2.ONE * accent_edge * 2.76), false, Color(accent.lightened(0.25), rays))
		_flight_surface.draw_set_transform(Vector2.ZERO)
		for index in range(2):
			var ripple: float = reveal_age - float(index) * 0.11
			if ripple < 0.0 or ripple >= 0.76:
				continue
			var radius: float = accent_edge * lerpf(0.36, 1.34, 1.0 - pow(1.0 - ripple / 0.76, 2.0))
			_draw_ring(point, Vector2.ONE * radius, accent, (1.0 - ripple / 0.76) * 0.85)
	var texture: Texture2D = after if _revealed or int(event.previous_tier) == 0 else before
	var model_weight: float = float(pose.model_weight) if not _model_sample.is_empty() else 0.0
	if texture != null and model_weight < 1.0:
		# Project the original flat artwork around its vertical axis.
		_flight_surface.draw_set_transform(point, 0.0, Vector2(float(pose.sprite_scale_x), 1.0) * float(placement.scale))
		_flight_surface.draw_texture_rect(texture, _texture_rect(texture, Vector2.ZERO, edge), false, Color(1, 1, 1, 1.0 - model_weight))
	if model_weight > 0.0:
		_flight_surface.draw_set_transform(point, 0.0, Vector2.ONE * float(placement.scale))
		var bounds: Rect2 = _model_sample.bounds
		var unit: float = edge / maxf(bounds.size.x, bounds.size.y)
		_flight_surface.draw_texture_rect(_model_sample.texture, Rect2(-bounds.get_center() * unit, Vector2.ONE * 1024.0 * unit), false, Color(1, 1, 1, model_weight))
	_flight_surface.draw_set_transform(Vector2.ZERO)
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
			var star_size: float = accent_edge * 0.22 * sin(t / 0.64 * PI)
			_flight_surface.draw_texture_rect(SPARKLE, Rect2(star_point - Vector2.ONE * star_size * 0.5, Vector2.ONE * star_size), false, Color(accent.lightened(0.6), (1.0 - t / 0.64) * fade))


func _tier_color(tier: int) -> Color:
	var colors: Array[Color] = [Color("#72e8c1"), Color("#ffd777"), Color("#75e5ff"), Color("#bc9dff"), Color("#ffcf65"), Color("#95d6ff")]
	return colors[clampi(tier - 1, 0, colors.size() - 1)]


func _draw_glow(center: Vector2, extent: Vector2, color: Color) -> void:
	_flight_surface.draw_texture_rect(GLOW, Rect2(center - extent * 0.5, extent), false, color)


func _draw_ring(center: Vector2, radius: Vector2, color: Color, opacity: float) -> void:
	# Light contours support the sourced chest and rays; they are not new props.
	var points := PackedVector2Array()
	for index in range(65):
		points.append(center + Vector2.from_angle(float(index) / 64.0 * TAU) * radius)
	_flight_surface.draw_polyline(points, Color(color, opacity * 0.14), 5.0, true)
	_flight_surface.draw_polyline(points, Color(color, opacity * 0.36), 2.5, true)
	_flight_surface.draw_polyline(points, Color(color.lightened(0.60), opacity), 0.85, true)


func snapshot() -> Dictionary:
	var motion: Dictionary = {}
	if is_active() and _started and _anchor.has_area():
		motion = _placement(_motion(_elapsed - ARRIVAL_SECONDS), minf(_anchor.size.x, _anchor.size.y), _anchor.get_center())
		if reduced_motion:
			motion.merge({"center": _anchor.get_center(), "scale": 1.0, "yaw": 0.0, "roll": 0.0,
				"pitch": 0.0, "depth": 0.0, "sprite_scale_x": 1.0, "model_weight": 0.0, "phase": "still"}, true)
		motion.center = [motion.center.x, motion.center.y]
	var bounds: Rect2 = _flight_bounds()
	return {"active": is_active(), "visible": visible, "elapsed": _elapsed,
		"tier": int(_events[0].tier) if is_active() else 0,
		"started": _started, "next_tier": int(_events[1].tier) if _events.size() > 1 else 0,
		"continuous_turns": _continuous_turns,
		"completed_turns": _completed_turns + (1 if _continuous_turns and _revealed else 0),
		"kind": ("upgrade" if int(_events[0].previous_tier) > 0 else "synthesis") if is_active() else "none",
		"revealed": _revealed, "queued": _events.size(), "reduced_motion": reduced_motion,
		"motion": motion, "flight_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"anchor": [_anchor.position.x, _anchor.position.y, _anchor.size.x, _anchor.size.y]}
