extends Control

const Style = preload("res://scripts/ui_style.gd")
const MEDAL = preload("res://assets/images/ui/mastery-medal.webp")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const DURATION: float = 1.6
var reduced_motion: bool = false
var value: int = -1
var _previous: int = -1
var _elapsed: float = DURATION
var _scale: float = 1.0
var _base_number_position := Vector2.ZERO
var _medal := TextureRect.new()
var _number: Label
var _old_number: Label


func _init() -> void:
	name = "ChallengeRecord"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_medal.texture = MEDAL
	_medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_medal)
	for index in range(2):
		var label := Style.label("", 30)
		label.add_theme_font_override("font", Style.HEADING_FONT)
		label.add_theme_color_override("font_color", Color("#a56b20"))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		if index == 0:
			_old_number = label
		else:
			_number = label
	_old_number.hide()


func reset() -> void:
	value = -1
	_previous = -1
	_elapsed = DURATION
	_number.text = ""
	_old_number.hide()
	queue_redraw()


func set_record(record: int, celebrate: bool = false, previous: int = -1) -> void:
	record = clampi(record, 0, 16384)
	if record == value and not celebrate:
		return
	_previous = previous if previous >= 0 else value
	value = record
	_elapsed = 0.0 if celebrate else DURATION
	_number.text = str(value)
	_old_number.text = str(maxi(0, _previous))
	tooltip_text = "Best Stage %d" % value
	set("accessibility_name", tooltip_text)
	layout_badge(get_rect(), _scale)
	_pose()


func layout_badge(bounds: Rect2, ui_scale: float) -> void:
	position = bounds.position
	size = bounds.size
	_scale = maxf(0.1, ui_scale)
	var edge: float = minf(size.y * 0.80, size.x * 0.38)
	_medal.size = Vector2.ONE * edge
	_medal.position = Vector2(2.0 / _scale, (size.y - edge) * 0.5)
	_medal.pivot_offset = _medal.size * 0.5
	_base_number_position = Vector2(_medal.get_rect().end.x + 5.0 / _scale, 0)
	var area := Vector2(maxf(1.0, size.x - _base_number_position.x - 3.0 / _scale), size.y)
	var pixels: int = maxi(1, ceili(minf(64.0, size.y * _scale * 0.78) / _scale))
	var width: float = Style.HEADING_FONT.get_string_size(_number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	if width > area.x:
		pixels = maxi(1, floori(float(pixels) * area.x / width))
	for label: Label in [_number, _old_number]:
		label.position = _base_number_position
		label.size = area
		label.pivot_offset = area * 0.5
		label.add_theme_font_size_override("font_size", pixels)
	_pose()


func feedback_active() -> bool:
	return _elapsed < (0.25 if reduced_motion else DURATION)


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or not feedback_active():
		return
	_elapsed = minf(DURATION, _elapsed + delta)
	_pose()


func _pose() -> void:
	var p: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	var pulse: float = 0.0 if reduced_motion else sin(p * PI)
	_number.scale = Vector2.ONE * (1.0 + 0.18 * pulse)
	_number.modulate.a = smoothstep(0.0, 0.28, p) if feedback_active() and not reduced_motion and _previous != value else 1.0
	_medal.scale = Vector2.ONE * (1.0 + 0.10 * pulse)
	_old_number.visible = not reduced_motion and feedback_active() and _previous >= 0 and _previous != value and p < 0.40
	_old_number.modulate.a = 1.0 - clampf(p / 0.40, 0.0, 1.0)
	_old_number.position = _base_number_position - Vector2(0, 14.0 * p / _scale)
	queue_redraw()


func _draw() -> void:
	if value < 0:
		return
	var center: Vector2 = _medal.get_rect().get_center()
	var glow: float = 0.10
	if feedback_active():
		glow += 0.30 if reduced_motion else 0.50 * sin(PI * _elapsed / DURATION)
	draw_texture_rect(GLOW, _medal.get_rect().grow(_medal.size.x * 0.35), false, Color(1.0, 0.83, 0.30, glow))
	if reduced_motion or not feedback_active():
		return
	var strength: float = sin(PI * _elapsed / DURATION)
	draw_set_transform(center, _elapsed * 0.30)
	draw_texture_rect(RAYS, Rect2(-_medal.size * 0.8, _medal.size * 1.6), false,
		Color(1.0, 0.81, 0.32, strength * 0.55))
	draw_set_transform(Vector2.ZERO)
	for index in range(4):
		var angle: float = TAU * float(index) / 4.0 + _elapsed * 0.35
		var at: Vector2 = center + Vector2(cos(angle), sin(angle)) * _medal.size.x * 0.65
		var edge: float = minf(14.0 / _scale, size.y * 0.22) * strength
		draw_texture_rect(SPARKLE, Rect2(at - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false,
			Color(1.0, 0.85, 0.35, strength))


func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "value": maxi(0, value), "previous": _previous,
		"active": feedback_active(), "elapsed": _elapsed, "number_scale": _number.scale.x,
		"text": _number.text}
