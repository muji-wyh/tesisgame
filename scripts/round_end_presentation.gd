extends Control
## The finished board stays visible until its end cue hands off to settlement.

signal completed(round_id: String)
signal cue_requested(round_id: String, failed: bool)

const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const RAYS = preload("res://assets/chests/milestone/rays.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const MEDAL = preload("res://assets/images/ui/mastery-medal.webp")
const DURATION: float = 3.2

var reduced_motion: bool = false
var _round_id: String = ""
var _active: bool = false
var _paused: bool = false
var _elapsed: float = 0.0
var _shade := ColorRect.new()
var _visual := Control.new()
var _glow := TextureRect.new()
var _rays := TextureRect.new()
var _medal := TextureRect.new()
var _failed: bool = false
var _heading: Label
var _caption: Label
var _eyebrow: Label
var _failure_panel := Panel.new()
var _failure_bounds := Rect2()


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
	_failure_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface: StyleBoxFlat = Style.box(Color("#fffaf0"), Color("#c6d9d3"), 24, 2)
	surface.shadow_color = Color(0.02, 0.10, 0.12, 0.24)
	surface.shadow_size = 12
	surface.shadow_offset = Vector2(0, 6)
	_failure_panel.add_theme_stylebox_override("panel", surface)
	_visual.add_child(_failure_panel)
	for artwork: TextureRect in [_glow, _rays]:
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_visual.add_child(artwork)
	_glow.texture = GLOW
	_glow.modulate = Color("#a8dacf")
	_rays.texture = RAYS
	_rays.modulate = Color("#ffe5a0")
	_medal.texture = MEDAL
	_medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_medal)
	_heading = Style.heading("", 60)
	_caption = Style.label("Let's see what you earned.", 20)
	_eyebrow = Style.label("ROUND ENDED", 11)
	_eyebrow.add_theme_font_override("font", Style.HEADING_FONT)
	_eyebrow.add_theme_color_override("font_color", Color("#64817a"))
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_eyebrow)
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
	_failed = failed
	_heading.text = "Game over" if failed else "Round complete"
	_caption.text = "Take a breath.\nYour next run is a fresh start." if failed else "Wonderful work!"
	_medal.visible = not failed
	_failure_panel.visible = failed
	_eyebrow.visible = failed
	_glow.visible = not failed
	_rays.visible = not failed
	_shade.color = Color("#183a3e", 0.76) if failed else Color(0.06, 0.11, 0.19, 0.56)
	_heading.add_theme_color_override("font_color", Style.INK if failed else Style.PAPER)
	_caption.add_theme_color_override("font_color", Color("#57746d") if failed else Style.PAPER)
	_heading.add_theme_color_override("font_shadow_color", Color.TRANSPARENT if failed else Color(0.02, 0.08, 0.12, 0.75))
	_glow.modulate = Color("#a8dacf") if failed else Color("#ffe2a3")
	_rays.modulate = Color("#b3dbe9") if failed else Color("#ffe5a0")
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
	_failure_bounds = Rect2(Vector2.ZERO, Vector2(minf(360.0 / s, maxf(1.0, size.x - 32.0 / s)),
		minf(216.0 / s, maxf(1.0, size.y - 32.0 / s))))
	_failure_bounds.position = (size - _failure_bounds.size) * 0.5
	_failure_panel.position = _failure_bounds.position
	_failure_panel.size = _failure_bounds.size
	_eyebrow.position = _failure_bounds.position + Vector2(16.0 / s, minf(18.0 / s, _failure_bounds.size.y * 0.08))
	_eyebrow.size = Vector2(maxf(1.0, _failure_bounds.size.x - 32.0 / s), minf(18.0 / s, _failure_bounds.size.y * 0.12))
	_eyebrow.add_theme_font_size_override("font_size", maxi(1, roundi(11.0 / s)))
	var width: float = maxf(1.0, size.x - 40.0 / s)
	if _failed:
		width = maxf(1.0, _failure_bounds.size.x - 40.0 / s)
	var pixels: int = maxi(1, floori(minf((38.0 if _failed else 60.0) / s, size.y * 0.16)))
	while pixels > 1 and Style.HEADING_FONT.get_string_size(_heading.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > width:
		pixels -= 1
	var height: float = Style.HEADING_FONT.get_height(pixels) + 8.0 / s
	_heading.add_theme_font_size_override("font_size", pixels)
	_heading.position = Vector2((size.x - width) * 0.5, size.y * (0.48 if _failed else 0.58) - height * 0.5)
	if _failed:
		_heading.position.y = _failure_bounds.position.y + minf(45.0 / s, _failure_bounds.size.y * 0.22)
	_heading.size = Vector2(width, height)
	_caption.add_theme_font_size_override("font_size", maxi(1, floori(minf(18.0 / s, minf(width * 0.055, size.y * 0.08)))))
	_caption.position = Vector2(_heading.position.x, _heading.position.y + height \
		+ (minf(12.0 / s, _failure_bounds.size.y * 0.045) if _failed else 8.0 / s))
	_caption.size = Vector2(width, minf(62.0 / s, size.y * 0.20))
	_medal.size = Vector2.ONE * minf(150.0 / s, minf(size.x * 0.32, size.y * 0.29))
	_medal.position = Vector2(size.x * 0.5, size.y * 0.32) - _medal.size * 0.5
	_medal.pivot_offset = _medal.size * 0.5
	var edge: float = minf(500.0 / s, minf(size.x * 0.96, size.y * 0.88))
	for artwork: TextureRect in [_glow, _rays]:
		artwork.size = Vector2.ONE * edge
		artwork.position = Vector2(size.x * 0.5, size.y * 0.47) - artwork.size * 0.5
		artwork.pivot_offset = artwork.size * 0.5
	_sample()


func _sample() -> void:
	var entrance: float = smoothstep(0.0, 0.55, _elapsed)
	var alpha: float = entrance * (1.0 - smoothstep(DURATION - 0.18, DURATION, _elapsed))
	_shade.modulate.a = alpha * (1.0 if _failed else 0.38)
	_visual.modulate.a = alpha
	var reveal: float = smoothstep(0.35, 0.88, _elapsed)
	_heading.modulate.a = reveal
	_caption.modulate.a = smoothstep(0.65, 1.10, _elapsed)
	_visual.scale = Vector2.ONE if reduced_motion or _failed else Vector2.ONE * lerpf(0.90, 1.0, smoothstep(0.0, 0.60, _elapsed))
	_visual.position.y = 0.0 if reduced_motion or not _failed else 10.0 / Style.ui_scale(self) * (1.0 - entrance)
	_medal.scale = Vector2.ONE if reduced_motion else Vector2.ONE * \
		(0.72 + 0.28 * entrance + 0.10 * sin(entrance * PI))
	_medal.rotation = 0.0 if reduced_motion else sin(entrance * PI) * -0.12
	_glow.modulate.a = 0.62
	_rays.modulate.a = 0.26
	_rays.rotation = 0.0 if reduced_motion else _elapsed * 0.035
	queue_redraw()


func _draw() -> void:
	if not _active or reduced_motion or _failed:
		return
	var p: float = clampf(_elapsed / 1.4, 0.0, 1.0)
	var center := Vector2(size.x * 0.5, size.y * (0.43 if _failed else 0.32))
	for index in range(12):
		var angle: float = TAU * index / 12.0
		var offset := Vector2(cos(angle), sin(angle)) * minf(size.x, size.y) * (0.10 + p * 0.22)
		var edge: float = 12.0 / Style.ui_scale(self)
		var tint: Color = Color("#b9e6ee") if _failed else Color("#ffe18b")
		draw_texture_rect(SPARKLE, Rect2(center + offset - Vector2.ONE * edge * 0.5, Vector2.ONE * edge),
			false, Color(tint, sin(p * PI) * 0.75))


func snapshot() -> Dictionary:
	return {"active": _active, "visible": is_visible_in_tree(), "paused": _paused,
		"round_id": _round_id, "title": _heading.text, "elapsed": _elapsed,
		"duration": DURATION, "reduced_motion": reduced_motion, "failed": _failed,
		"heading_font_size": _heading.get_theme_font_size("font_size"),
		"shade_alpha": _shade.color.a * _shade.modulate.a, "celebration_visible": _rays.visible,
		"panel_rect": [_failure_bounds.position.x, _failure_bounds.position.y, _failure_bounds.size.x, _failure_bounds.size.y]}
