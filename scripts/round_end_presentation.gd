extends Control
## The finished board stays visible until its end cue hands off to settlement.

signal completed(round_id: String)
signal cue_requested(round_id: String, failed: bool)

const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const DURATION: float = 1.8

var reduced_motion: bool = false
var _round_id: String = ""
var _active: bool = false
var _paused: bool = false
var _elapsed: float = 0.0
var _shade := ColorRect.new()
var _visual := Control.new()
var _glow := TextureRect.new()
var _rays := TextureRect.new()
var _heading: Label
var _caption: Label


func _init() -> void:
	name = "RoundEndPresentation"
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_shade.color = Color(0.06, 0.11, 0.19, 0.56)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	for artwork: TextureRect in [_glow, _rays]:
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_visual.add_child(artwork)
	_glow.texture = GLOW
	_glow.modulate = Color("#a8dacf")
	_rays.texture = RAYS
	_rays.modulate = Color("#ffe5a0")
	_heading = Style.heading("", 60)
	_caption = Style.label("Let's see what you earned.", 20)
	for label: Label in [_heading, _caption]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Style.PAPER)
		_visual.add_child(label)
	_heading.add_theme_color_override("font_shadow_color", Color(0.02, 0.08, 0.12, 0.75))
	_heading.add_theme_constant_override("shadow_offset_y", 3)
	resized.connect(_layout)
	hide()


func begin(round_id: String, failed: bool, steady: bool) -> bool:
	if round_id.is_empty() or round_id == _round_id:
		return false
	_round_id = round_id
	_active = true
	_paused = false
	_elapsed = 0.0
	reduced_motion = steady
	_heading.text = "Game over" if failed else "Round complete"
	set("accessibility_name", _heading.text + ". " + _caption.text)
	show()
	_layout()
	cue_requested.emit(_round_id, failed)
	return true


func is_active() -> bool:
	return _active


func set_paused(value: bool) -> void:
	_paused = value
	visible = _active and not _paused


func advance(delta: float) -> void:
	if not _active or _paused or not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = minf(DURATION, _elapsed + delta)
	_sample()
	if _elapsed >= DURATION:
		_active = false
		hide()
		completed.emit(_round_id)


func stop() -> void:
	_active = false
	_paused = false
	_elapsed = 0.0
	_round_id = ""
	hide()


func _layout() -> void:
	if _heading == null:
		return
	_shade.size = size
	_visual.size = size
	_visual.pivot_offset = size * 0.5
	var s: float = Style.ui_scale(self)
	var width: float = maxf(1.0, size.x - 40.0 / s)
	var pixels: int = maxi(1, floori(minf(64.0 / s, size.y * 0.20)))
	while pixels > 1 and Style.HEADING_FONT.get_string_size(_heading.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > width:
		pixels -= 1
	var height: float = Style.HEADING_FONT.get_height(pixels) + 8.0 / s
	_heading.add_theme_font_size_override("font_size", pixels)
	_heading.position = Vector2((size.x - width) * 0.5, size.y * 0.46 - height * 0.5)
	_heading.size = Vector2(width, height)
	_caption.add_theme_font_size_override("font_size", maxi(1, floori(minf(18.0 / s, minf(width * 0.055, size.y * 0.08)))))
	_caption.position = Vector2(_heading.position.x, _heading.position.y + height + 8.0 / s)
	_caption.size = Vector2(width, minf(62.0 / s, size.y * 0.20))
	var edge: float = minf(500.0 / s, minf(size.x * 0.96, size.y * 0.88))
	for artwork: TextureRect in [_glow, _rays]:
		artwork.size = Vector2.ONE * edge
		artwork.position = Vector2(size.x * 0.5, size.y * 0.47) - artwork.size * 0.5
		artwork.pivot_offset = artwork.size * 0.5
	_sample()


func _sample() -> void:
	var entrance: float = smoothstep(0.0, 0.22, _elapsed)
	var alpha: float = entrance * (1.0 - smoothstep(DURATION - 0.18, DURATION, _elapsed))
	_shade.modulate.a = alpha
	_visual.modulate.a = alpha
	_visual.scale = Vector2.ONE if reduced_motion else Vector2.ONE * lerpf(0.94, 1.0, smoothstep(0.0, 0.40, _elapsed))
	_glow.modulate.a = 0.62
	_rays.modulate.a = 0.26
	_rays.rotation = 0.0 if reduced_motion else _elapsed * 0.035


func snapshot() -> Dictionary:
	return {"active": _active, "visible": is_visible_in_tree(), "paused": _paused,
		"round_id": _round_id, "title": _heading.text, "elapsed": _elapsed,
		"duration": DURATION, "reduced_motion": reduced_motion}
