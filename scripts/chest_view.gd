extends Control

signal opened

const OPEN_SECONDS: float = 1.8

var theme_id: String = ""
var reduced_motion: bool = false
var mode: String = "closed"
var _art := Node2D.new()
var _pieces: Array[Dictionary] = []
var _bounds := Rect2()
var _elapsed: float = 0.0
var _idle_time: float = 0.0
var _tint: Color = Color.WHITE
var _style: String = ""
var drag_offset: Vector2 = Vector2.ZERO
var hold_progress: float = 0.0
var _tap_remaining: float = 0.0
var _glint := Node2D.new()
var _glint_color: Color = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	add_child(_glint)
	_glint.hide()
	_glint.draw.connect(_draw_glint)
	resized.connect(_fit)
	visibility_changed.connect(_visibility_changed)
	_visibility_changed()


func configure_skin(palette: Dictionary, manifest: Dictionary) -> void:
	if theme_id == palette.id:
		return
	theme_id = palette.id
	_style = palette.chest
	_tint = palette.tint
	_glint_color = palette.light
	mode = "closed"
	_elapsed = 0.0
	_idle_time = 0.0
	for child in _art.get_children():
		child.free()
	_pieces.clear()
	var style: Dictionary = manifest.styles[_style]
	if _style == "crystal":
		for part in style.parts:
			var matrix: Array = part.transform
			var pose := Transform2D(Vector2(matrix[0], matrix[1]), Vector2(matrix[2], matrix[3]), Vector2(matrix[4], matrix[5]))
			_add_piece(part.texture, part.name, pose, Vector2(part.pivot[0], part.pivot[1]), int(part.order), part.flip_h, part.flip_v)
	else:
		_add_piece(style.closed, "closed", Transform2D.IDENTITY, Vector2(0.5, 0.5))
		_add_piece(style.open, "open", Transform2D.IDENTITY, Vector2(0.5, 0.5))
	_measure_bounds()
	_apply_pose(0.0)
	_fit()


func _add_piece(path: String, role: String, pose: Transform2D, pivot: Vector2, order: int = 0, flip_h: bool = false, flip_v: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://" + path)
	sprite.centered = false
	var dimensions: Vector2 = sprite.texture.get_size()
	sprite.offset = Vector2(-dimensions.x * pivot.x, -dimensions.y * (1.0 - pivot.y))
	sprite.transform = pose
	sprite.z_index = order
	sprite.flip_h = flip_h
	sprite.flip_v = flip_v
	_art.add_child(sprite)
	_pieces.append({"node": sprite, "rest": pose, "role": role})


func _measure_bounds() -> void:
	var first := true
	for piece in _pieces:
		var rect: Rect2 = piece.node.get_rect()
		var pose: Transform2D = piece.rest
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var point: Vector2 = pose * corner
			if first:
				_bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				_bounds = _bounds.expand(point)


func _fit() -> void:
	if _pieces.is_empty() or _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0:
		return
	var margin: float = 0.77 if _style == "crystal" else 0.96
	var fit: float = minf(size.x * margin / _bounds.size.x, size.y * 0.78 / _bounds.size.y)
	var bob: float = 0.0 if reduced_motion else sin(_idle_time * 2.0) * 4.0
	var shake_offset := Vector2.ZERO
	if not reduced_motion and hold_progress > 0.0:
		var strength: float = size.x * 0.025 * hold_progress * hold_progress
		shake_offset = Vector2(sin(_idle_time * lerpf(18.0, 72.0, hold_progress)), cos(_idle_time * 61.0)) * strength
	var pulse: Vector2 = Vector2.ONE
	if mode == "opening" and not reduced_motion:
		var charge: float = clampf(_elapsed / 0.42, 0.0, 1.0)
		var shake: float = sin(_elapsed * 65.0) * (1.0 - charge) * 0.035
		pulse = Vector2(1.0 + shake, 1.0 - shake)
		bob -= sin(clampf(_elapsed / OPEN_SECONDS, 0.0, 1.0) * PI) * size.y * 0.07
	drag_offset = _clamp_drag_offset(drag_offset, fit, bob)
	_art.scale = Vector2.ONE * fit * pulse
	_art.position = Vector2(size.x * 0.5, size.y * 0.59 + bob) - _bounds.get_center() * _art.scale + drag_offset + shake_offset
	_art.rotation = 0.0 if reduced_motion else sin(_tap_remaining * 24.0) * 0.04 * (_tap_remaining / 0.35)
	_glint.visible = not reduced_motion and (hold_progress > 0.0 or _tap_remaining > 0.0)
	_glint.queue_redraw()


func _draw_glint() -> void:
	var center: Vector2 = _art.position + _bounds.get_center() * _art.scale
	center.y -= _bounds.size.y * _art.scale.y * 0.08
	var power: float = maxf(hold_progress * hold_progress, _tap_remaining / 0.35 * 0.6)
	var radius: float = minf(size.x, size.y) * 0.07
	for layer in range(3):
		_glint.draw_circle(center, radius * (1.8 - float(layer) * 0.4), Color(_glint_color, power * 0.1))
	_glint.draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(_glint_color, power), 3.0, true)
	_glint.draw_line(center - Vector2(0, radius * 0.6), center + Vector2(0, radius * 0.6), Color(Color.WHITE, power), 2.0, true)


func play_tap() -> void:
	if reduced_motion or mode != "closed":
		return
	_tap_remaining = 0.35
	_fit()


func stop_reaction() -> void:
	_tap_remaining = 0.0
	_art.rotation = 0.0
	_glint.hide()


func _clamp_drag_offset(value: Vector2, fit: float, bob: float) -> Vector2:
	var dimensions: Vector2 = _bounds.size * fit
	var center := Vector2(size.x * 0.5, size.y * 0.59 + bob)
	var minimum := dimensions * 0.5 - center
	var maximum := size - dimensions * 0.5 - center
	return Vector2(
		clampf(value.x, minimum.x, maximum.x) if minimum.x <= maximum.x else 0.0,
		clampf(value.y, minimum.y, maximum.y) if minimum.y <= maximum.y else 0.0
	)


func _apply_pose(progress: float) -> void:
	for index in range(_pieces.size()):
		var piece: Dictionary = _pieces[index]
		var sprite: Sprite2D = piece.node
		var pose: Transform2D = piece.rest
		var alpha: float = 1.0
		if _style == "crystal":
			if piece.role != "chest":
				var direction: Vector2 = pose.origin - _bounds.get_center()
				if direction.length_squared() < 1.0:
					direction = Vector2.UP
				var rotation_delta: float = (0.13 if index % 2 == 0 else -0.13) * progress
				pose = pose * Transform2D(rotation_delta, Vector2.ZERO)
				pose.origin += direction.normalized() * _bounds.size.x * 0.13 * progress
		else:
			alpha = 1.0 - progress if piece.role == "closed" else progress
		sprite.transform = pose
		sprite.modulate = Color(_tint.r, _tint.g, _tint.b, alpha)


func start_open(reduce: bool) -> void:
	if mode != "closed":
		return
	reduced_motion = reduce
	stop_reaction()
	hold_progress = 0.0
	mode = "opening"
	_elapsed = 0.0
	if reduced_motion:
		finish_immediately()


func finish_immediately() -> void:
	if mode != "opening":
		return
	mode = "opened"
	_elapsed = OPEN_SECONDS
	_apply_pose(1.0)
	_fit()
	opened.emit()


func clear() -> void:
	stop_reaction()
	mode = "closed"
	_elapsed = 0.0
	theme_id = ""
	hold_progress = 0.0
	drag_offset = Vector2.ZERO
	_apply_pose(0.0)


func set_hold_progress(value: float) -> void:
	hold_progress = clampf(value, 0.0, 1.0)
	_fit()


func set_drag_offset(value: Vector2) -> void:
	drag_offset = value
	_fit()


func piece_count() -> int:
	return _pieces.size()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		stop_reaction()
	set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	_idle_time += delta
	_tap_remaining = maxf(0.0, _tap_remaining - delta)
	if mode == "opening":
		_elapsed += delta
		var progress: float = smoothstep(0.3, 1.15, _elapsed)
		_apply_pose(progress)
		if _elapsed >= OPEN_SECONDS:
			finish_immediately()
	_fit()
