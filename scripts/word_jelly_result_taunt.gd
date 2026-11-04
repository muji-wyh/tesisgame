extends Control
## A finite, view-only performance. Settlement and navigation keep their own clocks.

const Style = preload("res://scripts/ui_style.gd")
const Actor = preload("res://scripts/word_jelly_boss_actor.gd")
const GLOW = preload("res://assets/chests/shared/effects/portal_glow.png")
const SPARKLE = preload("res://assets/chests/shared/effects/sparkle.png")
const DURATION: float = 2.4
const TAUNT_SECONDS: float = 2.0
const STEADY_SAMPLE: float = 1.0
# Nine inspected source poses, with padding around the complete hands and feet.
const FRAME := Rect2(4, 139, 362, 368)

var last_error: String = ""
var reduced_motion: bool = false
var _round_id: String = ""
var _elapsed: float = 0.0
var _active: bool = false
var _record: bool = false
var _scale: float = 1.0
var _last_sample: int = -1
var _pose_time: float = 0.0
var _pose_count: int = 0
var _actor := Actor.new()
var _atlas := AtlasTexture.new()
var _image := TextureRect.new()
var _effects := Control.new()
var _caption: Label
var _image_base := Rect2()
var _hands: Array[Vector2] = []


func _init() -> void:
	name = "GameOverBramble"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	add_child(_actor)
	_atlas.atlas = _actor.get_texture()
	_atlas.region = FRAME
	_image.texture = _atlas
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.draw.connect(_draw_effects)
	add_child(_effects)
	_caption = Style.label("", 14)
	_caption.add_theme_font_override("font", Style.HEADING_FONT)
	_caption.add_theme_color_override("font_color", Color("#76568d"))
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_actor.render_target_update_mode = SubViewport.UPDATE_DISABLED
		else:
			_last_sample = -1
			_sample())
	set_process(false)
	hide()


func present(round_id: String, steady: bool, new_record: bool = false) -> bool:
	if round_id.is_empty():
		last_error = "A Game over performance needs its saved round identity."
		push_error(last_error)
		return false
	if not _actor.load_character():
		last_error = _actor.last_error
		return false
	last_error = ""
	if round_id != _round_id:
		_round_id = round_id
		_elapsed = DURATION if steady else 0.0
		_record = new_record
		_last_sample = -1
		_pose_count = 0
		reduced_motion = steady
		_caption.text = "Nice run!\nOne more round?" if _record else "Catch me next time!"
		accessibility_name = "Bramble. " + _caption.text.replace("\n", " ")
	else:
		set_reduced_motion(steady)
	show()
	_layout()
	_sample()
	return true


func reset() -> void:
	_active = false
	_round_id = ""
	_elapsed = 0.0
	_hands.clear()
	_actor.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hide()


func set_active(value: bool) -> void:
	if value == _active:
		return
	_active = value
	if not value:
		_actor.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_last_sample = -1
		_sample()


func set_reduced_motion(value: bool) -> void:
	if value == reduced_motion:
		return
	reduced_motion = value
	if value:
		_elapsed = DURATION
	_last_sample = -1
	_sample()


func configure_layout(bounds: Rect2, ui_scale: float) -> void:
	position = bounds.position
	size = bounds.size
	_scale = maxf(0.1, ui_scale)
	_layout()


func advance(delta: float) -> void:
	if not _active or not is_visible_in_tree() or reduced_motion or _round_id.is_empty() \
		or _elapsed >= DURATION or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = minf(DURATION, _elapsed + delta)
	_sample()


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var unit: float = 1.0 / _scale
	var pixels: int = ceili(14.0 * unit)
	_caption.add_theme_font_size_override("font_size", pixels)
	_caption.update_minimum_size()
	var horizontal: bool = size.x > size.y * 1.6 and size.y < 180.0 * unit
	if horizontal:
		var image_width: float = minf(size.y, size.x * 0.55)
		_image_base = Rect2(8.0 * unit, 4.0 * unit,
			maxf(1.0, image_width - 16.0 * unit), maxf(1.0, size.y - 8.0 * unit))
		_caption.position = Vector2(image_width + 4.0 * unit, 0)
		_caption.size = Vector2(maxf(1.0, size.x - image_width - 12.0 * unit), size.y)
	else:
		var caption_h: float = maxf((56.0 if _record else 32.0) * unit,
			Style.HEADING_FONT.get_height(pixels) * (2 if _record else 1) + 4.0 * unit)
		caption_h = maxf(ceilf(caption_h), _caption.get_minimum_size().y)
		_image_base = Rect2(16.0 * unit, 4.0 * unit,
			maxf(1.0, size.x - 32.0 * unit), maxf(1.0, size.y - caption_h - 12.0 * unit))
		_caption.position = Vector2(4.0 * unit, size.y - caption_h)
		_caption.size = Vector2(maxf(1.0, size.x - 8.0 * unit), caption_h)
	_effects.size = size
	_sample()


func _sample() -> void:
	if not _active or not is_visible_in_tree() or not _actor._loaded or _round_id.is_empty():
		return
	var frame: int = floori(_elapsed * 24.0)
	if frame != _last_sample:
		_last_sample = frame
		_pose_time = STEADY_SAMPLE if reduced_motion else minf(_elapsed, TAUNT_SECONDS - 0.001)
		_actor.pose("Taunt", _pose_time)
		_pose_count += 1
		_hands = [_actor.project_bone("Middle1.L"), _actor.project_bone("Middle1.R")]
	var entrance: float = 1.0 if reduced_motion else smoothstep(0.0, 0.3, _elapsed)
	_image.position = _image_base.position + Vector2(0, (1.0 - entrance) * 8.0 / _scale)
	_image.size = _image_base.size
	_image.modulate.a = entrance
	_caption.modulate.a = 1.0 if reduced_motion else smoothstep(0.1, 0.45, _elapsed)
	_effects.queue_redraw()


func _image_rect() -> Rect2:
	var fit: float = minf(_image.size.x / FRAME.size.x, _image.size.y / FRAME.size.y)
	var extent: Vector2 = FRAME.size * fit
	return Rect2(_image.position + (_image.size - extent) * 0.5, extent)


func _hand_points() -> Array[Vector2]:
	var rect: Rect2 = _image_rect()
	var points: Array[Vector2] = []
	for hand: Vector2 in _hands:
		points.append(rect.position + (hand - FRAME.position) / FRAME.size * rect.size)
	return points


func effect_strength() -> float:
	if reduced_motion:
		return 0.16
	if _elapsed < 0.3 or _elapsed >= 1.7:
		return 0.0
	return sin(clampf((_elapsed - 0.3) / 1.4, 0.0, 1.0) * PI) * (0.65 if _record else 1.0)


func _draw_effects() -> void:
	if not _active or not is_visible_in_tree() or _hands.is_empty():
		return
	var strength: float = effect_strength()
	if strength <= 0.0:
		return
	var unit: float = 1.0 / _scale
	var edge: float = minf(54.0 * unit, _image_rect().size.x * 0.42)
	var points: Array[Vector2] = _hand_points()
	for hand_index in range(points.size()):
		var hand: Vector2 = points[hand_index]
		_effects.draw_texture_rect(GLOW, Rect2(hand - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
			false, Color(0.80, 0.63, 1.0, strength * 0.62))
		if reduced_motion:
			continue
		var travel: float = clampf((_elapsed - 0.45) / 1.1, 0.0, 1.0)
		for index in range(3):
			var angle: float = -PI * 0.9 + float(index) * PI * 0.42 + hand_index * 0.24
			var point: Vector2 = hand + Vector2(cos(angle), sin(angle)) * (8.0 + travel * 20.0) * unit
			var sparkle_edge: float = (7.0 + strength * 5.0) * unit
			_effects.draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * sparkle_edge * 0.5,
				Vector2.ONE * sparkle_edge), false, Color(0.82, 0.62, 1.0, strength))


func snapshot() -> Dictionary:
	var rect: Rect2 = _image_rect()
	return {"visible": is_visible_in_tree(), "round_id": _round_id, "active": _active,
		"elapsed": _elapsed, "duration": DURATION, "reduced_motion": reduced_motion,
		"clip": "Taunt", "pose_time": _pose_time, "pose_count": _pose_count,
		"model_loaded": _actor._loaded, "caption": _caption.text,
		"effects": effect_strength() if _active and is_visible_in_tree() else 0.0,
		"image_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"hand_points": _hand_points().map(func(point: Vector2) -> Array: return [point.x, point.y])}
