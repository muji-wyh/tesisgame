extends Control

signal opened

const OPEN_SECONDS: float = 1.8
const RELEASE_SECONDS: float = 0.72
const CHARGE_TICKS: int = 24
const Style = preload("res://scripts/ui_style.gd")

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
var _charge := Node2D.new()
var _charge_label := Label.new()
var _charge_color := Color("#58d7c5")
var _charge_spark := Color("#fff4be")
var _hold_active: bool = false
var _release_active: bool = false
var _charge_time: float = 0.0
var _charge_center := Vector2.ZERO
var _charge_radius := Vector2.ZERO
var _charge_bounds := Rect2()
var _charge_scale: float = 1.0
var _charge_style_scale: float = -1.0
var _charge_status: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_charge)
	_charge.hide()
	_charge.draw.connect(_draw_charge)
	add_child(_art)
	add_child(_glint)
	_glint.hide()
	_glint.draw.connect(_draw_glint)
	_charge_label.name = "UnlockProgress"
	_charge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_charge_label.clip_text = true
	_charge_label.add_theme_color_override("font_color", Color.WHITE)
	_charge_label.hide()
	add_child(_charge_label)
	resized.connect(_fit)
	visibility_changed.connect(_visibility_changed)
	_visibility_changed()


func configure_skin(palette: Dictionary, manifest: Dictionary) -> void:
	if theme_id == palette.id:
		return
	stop_reaction()
	theme_id = palette.id
	_style = palette.chest
	_tint = palette.tint
	_glint_color = palette.light
	_charge_color = palette.get("accent", _glint_color)
	_charge_spark = palette.get("spark", _glint_color).lightened(0.25)
	_charge_style_scale = -1.0
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
	# Leave the themed scenery visible and room for the crystal's opening pieces.
	var fit: float = minf(size.x * 0.62 / _bounds.size.x, size.y * 0.60 / _bounds.size.y)
	_update_charge()
	var bob: float = 0.0 if reduced_motion else sin(_idle_time * 2.0) * 4.0
	var shake_offset := Vector2.ZERO
	if not reduced_motion and hold_progress > 0.0:
		var strength: float = minf(size.x * 0.012, 3.0 / Style.ui_scale(self)) * hold_progress * hold_progress
		shake_offset = Vector2(sin(_idle_time * lerpf(18.0, 72.0, hold_progress)), cos(_idle_time * 61.0)) * strength
	var pulse: Vector2 = Vector2.ONE
	if mode == "opening" and not reduced_motion:
		var charge: float = clampf(_elapsed / 0.42, 0.0, 1.0)
		var shake: float = sin(_elapsed * 65.0) * (1.0 - charge) * 0.035
		pulse = Vector2(1.0 + shake, 1.0 - shake)
		bob -= sin(clampf(_elapsed / OPEN_SECONDS, 0.0, 1.0) * PI) * size.y * 0.07
	if _charge_label.visible:
		var top: float = _charge_label.position.y + _charge_label.size.y + 3.0 / _charge_scale
		var bottom: float = size.y - 6.0 / _charge_scale
		fit = minf(fit, maxf(0.0, bottom - top) * 0.88 / _bounds.size.y)
		var half_height: float = _bounds.size.y * fit * maxf(pulse.y, 1.0) * 0.5
		bob = clampf(size.y * 0.59 + bob, top + half_height, bottom - half_height) - size.y * 0.59
	drag_offset = _clamp_drag_offset(drag_offset, fit, bob)
	_art.scale = Vector2.ONE * fit * pulse
	_art.position = Vector2(size.x * 0.5, size.y * 0.59 + bob) - _bounds.get_center() * _art.scale + drag_offset + shake_offset
	_art.rotation = 0.0 if reduced_motion else sin(_tap_remaining * 24.0) * 0.04 * (_tap_remaining / 0.35)
	_glint.visible = not reduced_motion and (hold_progress > 0.0 or _tap_remaining > 0.0)
	_glint.queue_redraw()


func _update_charge() -> void:
	var active: bool = is_visible_in_tree() and ((_hold_active and mode == "closed")
		or (_release_active and mode == "opening" and _elapsed < 0.95))
	_charge.visible = active
	_charge_label.visible = active
	if not active:
		return
	_charge_scale = maxf(0.25, Style.ui_scale(self))
	var pixel: float = 1.0 / _charge_scale
	var margin: float = minf(10.0 * pixel, minf(size.x, size.y) * 0.08)
	var percent: int = 100 if mode == "opening" else mini(100, floori(hold_progress * 100.0))
	var status: String = "Unlocking" if mode == "opening" else "Keep holding"
	_charge_status = status
	if size.x * _charge_scale < 210:
		status = "Unlocking" if mode == "opening" else "Hold"
	if mode == "opening" and size.x * _charge_scale < 150:
		status = "Open"
	_charge_label.text = "%s · %d%%" % [status, percent]
	var font_size: int = ceili(14.0 * pixel)
	var font: Font = _charge_label.get_theme_font("font")
	var full_status: String = "Hold" if size.x * _charge_scale < 210 else "Keep holding"
	var open_status: String = "Open" if size.x * _charge_scale < 150 else "Unlocking"
	var text_width: float = maxf(font.get_string_size(full_status + " · 100%", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
		font.get_string_size(open_status + " · 100%", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var available: float = maxf(0.0, size.x - margin * 2.0)
	_charge_label.add_theme_font_size_override("font_size", font_size)
	var label_size := Vector2(minf(available, text_width + 22.0 * pixel), font.get_height(font_size) + 10.0 * pixel)
	# The theme badge occupies the upper-left corner on phone-sized stages.
	var label_x: float = size.x - margin - label_size.x if size.x * _charge_scale < 420 else (size.x - label_size.x) * 0.5
	_charge_label.position = Vector2(label_x, margin)
	_charge_label.size = label_size
	if not is_equal_approx(_charge_style_scale, _charge_scale):
		_charge_style_scale = _charge_scale
		var badge: StyleBoxFlat = Style.box(_charge_color.darkened(0.72), _charge_spark.lightened(0.18), ceili(12.0 * pixel), maxi(1, roundi(pixel)))
		badge.content_margin_left = 8.0 * pixel
		badge.content_margin_right = 8.0 * pixel
		badge.content_margin_top = 3.0 * pixel
		badge.content_margin_bottom = 3.0 * pixel
		_charge_label.add_theme_stylebox_override("normal", badge)
	var top: float = _charge_label.position.y + label_size.y + 5.0 * pixel
	var available_height: float = maxf(0.0, size.y - margin - top)
	_charge_center = Vector2(size.x * 0.5, top + available_height * 0.5)
	_charge_radius = Vector2(maxf(0, available * 0.42 - 7.0 * pixel), maxf(0, available_height * 0.42 - 7.0 * pixel))
	# Every halo, tick and spark stays in this measured rectangle, including
	# the one-shot release. The parent stage can safely keep clipping enabled.
	var extent: Vector2 = _charge_radius * 1.13 + Vector2.ONE * 7.0 * pixel
	if _charge_radius.x <= 0.0 or _charge_radius.y <= 0.0:
		extent = Vector2.ZERO
	_charge_bounds = Rect2(_charge_center - extent, extent * 2.0)
	_charge.queue_redraw()


func _ellipse_points(radius: Vector2, start: float, end: float, steps: int = 72) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var angle: float = lerpf(start, end, float(index) / float(steps))
		points.append(_charge_center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw_charge() -> void:
	if _charge_radius.x <= 0.0 or _charge_radius.y <= 0.0:
		return
	var pixel: float = 1.0 / _charge_scale
	var progress: float = 1.0 if mode == "opening" else hold_progress
	var release: float = clampf(_elapsed / RELEASE_SECONDS, 0.0, 1.0) if mode == "opening" else 0.0
	var alpha: float = 1.0 - release if mode == "opening" else 1.0
	var start: float = -PI * 0.5
	var intensity: float = 0.25 + progress * 0.75
	var ring: PackedVector2Array = _ellipse_points(_charge_radius, start, start + TAU)
	_charge.draw_polyline(ring, Color(_charge_color.darkened(0.4), 0.28 * alpha), 5.0 * pixel, true)
	if progress > 0.0:
		var current: PackedVector2Array = _ellipse_points(_charge_radius, start, start + TAU * progress)
		_charge.draw_polyline(current, Color(_charge_spark, 0.13 * intensity * alpha), 13.0 * pixel, true)
		_charge.draw_polyline(current, Color(_charge_color.lightened(0.22), 0.95 * alpha), 5.0 * pixel, true)
		_charge.draw_polyline(current, Color(_charge_spark.lightened(0.7), alpha), 1.8 * pixel, true)
	for index in range(CHARGE_TICKS):
		var direction := Vector2.from_angle(start + TAU * float(index) / float(CHARGE_TICKS))
		var lit: bool = float(index + 1) / float(CHARGE_TICKS) <= progress
		var color := Color(_charge_spark if lit else _charge_color.darkened(0.2), (0.95 if lit else 0.23) * alpha)
		_charge.draw_line(_charge_center + direction * _charge_radius * 1.04,
			_charge_center + direction * _charge_radius * 1.12, color, 2.2 * pixel, true)
	if reduced_motion:
		return
	if mode == "opening":
		if release >= 1.0:
			return
		var radius: Vector2 = _charge_radius * lerpf(0.75, 1.12, release)
		_charge.draw_polyline(_ellipse_points(radius, start, start + TAU),
			Color(_charge_spark.lightened(0.4), (1.0 - release) * 0.85), lerpf(4.0, 1.0, release) * pixel, true)
		for index in range(12):
			var direction := Vector2.from_angle(start + TAU * float(index) / 12.0)
			_charge.draw_line(_charge_center + direction * radius * 0.92,
				_charge_center + direction * radius, Color(_charge_spark, (1.0 - release) * 0.9), 2.0 * pixel, true)
	else:
		for index in range(10):
			var phase: float = fposmod(_charge_time * (0.55 + progress * 0.5) + float(index) * 0.173, 1.0)
			var direction := Vector2.from_angle(start + TAU * float(index) / 10.0 + sin(float(index) * 2.7) * 0.12)
			var position: Vector2 = _charge_center + direction * _charge_radius * lerpf(1.1, 0.58, phase)
			var opacity: float = sin(phase * PI) * intensity
			_charge.draw_line(position, position + direction * 4.0 * pixel, Color(_charge_spark, opacity * 0.55), 1.5 * pixel, true)
			_charge.draw_circle(position, (1.1 + progress * 0.8) * pixel, Color(_charge_spark.lightened(0.45), opacity))


func begin_hold() -> void:
	if mode != "closed" or not is_visible_in_tree():
		return
	_hold_active = true
	_release_active = false
	_charge_time = 0.0
	hold_progress = 0.0
	_tap_remaining = 0.0
	_fit()


func hold_effect_snapshot() -> Dictionary:
	var active: bool = _charge.visible and is_visible_in_tree()
	var opening: bool = active and mode == "opening"
	return {"active": active, "phase": "opening" if opening else ("holding" if active else "idle"),
		"progress": 1.0 if opening else hold_progress,
		"percent": 100 if opening else mini(100, floori(hold_progress * 100.0)),
		"text": _charge_label.text if active else "", "status": _charge_status if active else "",
		"animated": active and not reduced_motion,
		"spark_count": (12 if opening and _elapsed < RELEASE_SECONDS else 10 if not opening else 0) if active and not reduced_motion else 0,
		"bounds": {"x": _charge_bounds.position.x, "y": _charge_bounds.position.y,
			"width": _charge_bounds.size.x, "height": _charge_bounds.size.y},
		"badge_bounds": {"x": _charge_label.position.x, "y": _charge_label.position.y,
			"width": _charge_label.size.x, "height": _charge_label.size.y}}


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
	hold_progress = 0.0
	_hold_active = false
	_release_active = false
	_charge_time = 0.0
	_art.rotation = 0.0
	_glint.hide()
	_charge.hide()
	_charge_label.hide()
	_fit()


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
	_release_active = not reduced_motion
	if reduced_motion:
		finish_immediately()
	else:
		_fit()


func finish_immediately() -> void:
	if mode != "opening":
		return
	mode = "opened"
	_release_active = false
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
	_fit()


func set_hold_progress(value: float) -> void:
	if mode != "closed":
		return
	if not is_finite(value):
		value = 0.0
	if value > 0.0 and not _hold_active:
		begin_hold()
	hold_progress = clampf(value, 0.0, 1.0) if is_visible_in_tree() else 0.0
	if hold_progress <= 0.0:
		_hold_active = false
		_charge_time = 0.0
		_tap_remaining = 0.0
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
	if _hold_active and not reduced_motion:
		_charge_time += delta
	_tap_remaining = maxf(0.0, _tap_remaining - delta)
	if mode == "opening":
		_elapsed += delta
		var progress: float = smoothstep(0.3, 1.15, _elapsed)
		_apply_pose(progress)
		if _elapsed >= OPEN_SECONDS:
			finish_immediately()
	_fit()
