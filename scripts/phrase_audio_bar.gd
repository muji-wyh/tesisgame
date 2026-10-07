extends Button
## One phrase replay target, with an optional readable transcript.

const Style = preload("res://scripts/ui_style.gd")
# This designed waveform indicates playback; it does not represent audio samples.
const WAVE_HEIGHTS: Array[float] = [
	0.18, 0.32, 0.60, 0.42, 0.76, 0.94, 0.63, 0.40,
	0.54, 0.85, 1.0, 0.70, 0.38, 0.58, 0.82, 0.48,
	0.28, 0.56, 0.92, 0.72, 0.44, 0.67, 0.38, 0.22
]

var _caption: Label
var _accent: Color = Style.GOOD
var _phrase_text: String = ""
var _show_text: bool = false
var _speaking: bool = false
var _reduced_motion: bool = false
var _paused: bool = false
var _elapsed: float = 0.0


func _init() -> void:
	name = "PhraseListen"
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""
	_caption = Style.label("Tap to listen", 12)
	_caption.name = "PhraseAudioCaption"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.max_lines_visible = 2
	_caption.clip_text = true
	_caption.add_theme_constant_override("line_spacing", 0)
	add_child(_caption)
	resized.connect(_layout)
	visibility_changed.connect(_visibility_changed)
	set_process(false)
	configure({}, false, _accent)


func configure(phrase: Dictionary, show_text: bool, accent: Color) -> void:
	_phrase_text = str(phrase.get("text", ""))
	_show_text = show_text and not _phrase_text.is_empty()
	_accent = accent
	_caption.text = _phrase_text if _show_text else "Tap to listen"
	tooltip_text = "Hear the phrase again"
	set("accessibility_name", "Listen: %s" % _phrase_text if _show_text else "Listen to the phrase")
	_layout()
	_update_activity()


func set_speaking(value: bool) -> void:
	# Playback state is forwarded each frame; idle bars should not redraw.
	if _speaking == value and is_processing() == _should_animate():
		return
	if _speaking != value:
		_elapsed = 0.0
	_speaking = value
	_update_activity()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	_update_activity()


func set_paused(value: bool) -> void:
	_paused = value
	if value:
		_speaking = false
	_update_activity()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_speaking = false
	_update_activity()


func _update_activity() -> void:
	set_process(_should_animate())
	queue_redraw()


func _should_animate() -> bool:
	return _speaking and not _show_text and not _paused and not _reduced_motion and not disabled and is_visible_in_tree()


func transcript_layout() -> Dictionary:
	return {
		"text": _caption.text,
		"shown": _show_text and is_visible_in_tree(),
		"line_count": _caption.get_line_count(),
		"visible_line_count": _caption.get_visible_line_count(),
		"line_height": _caption.get_line_height(),
		"height": _caption.size.y,
		"font_size": _caption.get_theme_font_size("font_size")
	}


func _process(delta: float) -> void:
	if disabled or _paused or not is_visible_in_tree():
		_update_activity()
		return
	_elapsed += delta
	queue_redraw()


func _layout() -> void:
	if not is_instance_valid(_caption):
		return
	var s: float = Style.ui_scale(self)
	var radius: int = ceili(18 / s)
	var fill: Color = Color("#edf6f0").lerp(_accent.lightened(0.93), 0.2)
	var edge: Color = _accent.lightened(0.69)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var surface := Style.box(fill, edge, radius, maxi(1, roundi(1 / s)))
		if state == "hover":
			surface.bg_color = fill.darkened(0.025)
			surface.border_color = _accent.lightened(0.35)
		elif state == "pressed":
			surface.bg_color = fill.darkened(0.055)
			surface.border_color = _accent
		elif state == "disabled":
			surface.bg_color = Color("#f0f2eb")
			surface.border_color = Style.EDGE
		surface.set_content_margin_all(0)
		add_theme_stylebox_override(state, surface)
	add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, _accent.darkened(0.25), radius, maxi(2, roundi(2 / s))))
	custom_minimum_size = Vector2.ZERO
	var left: float = minf(62 / s, size.x * 0.31)
	var available: float = maxf(0, size.x - left - 14 / s)
	var font_size: int = ceili((18 if _show_text else 11) / s)
	_caption.add_theme_font_override("font", Style.HEADING_FONT if _show_text else Style.BODY_FONT)
	_caption.add_theme_color_override("font_color", Style.INK if _show_text else _accent.darkened(0.28))
	_caption.position = Vector2(left, 4 / s if _show_text else size.y * 0.60)
	var available_height: float = maxf(0, size.y - 8 / s) if _show_text else size.y * 0.31
	if _show_text:
		var font: Font = Style.HEADING_FONT
		# Measure the actual wrapped lines, including font ascent and descent.
		# Four-word phrases must fit two full lines even in a 48 px high bar.
		while font_size > ceili(12 / s):
			var measured: Vector2 = font.get_multiline_string_size(_phrase_text, HORIZONTAL_ALIGNMENT_LEFT, available, font_size)
			if measured.x <= available and measured.y <= minf(available_height, font.get_height(font_size) * 2 + 1 / s):
				break
			font_size -= 1
	_caption.add_theme_font_size_override("font_size", font_size)
	_caption.size = Vector2(available, available_height)
	if _show_text:
		# Use Label's visible-line count as well as its rounded line height.
		# Web text shaping can hide a whole line despite a matching height sum.
		while font_size > ceili(12 / s) and (_caption.get_line_count() > 2 or _caption.get_visible_line_count() < _caption.get_line_count() or _caption.get_line_count() * _caption.get_line_height() > available_height):
			font_size -= 1
			_caption.add_theme_font_size_override("font_size", font_size)
			_caption.size = Vector2(available, available_height)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var s: float = Style.ui_scale(self)
	var active: bool = _speaking and not _paused and not disabled
	var ink: Color = Style.MUTED if disabled else _accent.darkened(0.10)
	var icon_radius: float = minf(18 / s, size.y * 0.32)
	var icon_center := Vector2(minf(32 / s, size.x * 0.16), size.y * 0.5)
	draw_circle(icon_center, icon_radius, ink)
	var triangle := PackedVector2Array([
		icon_center + Vector2(-0.23, -0.40) * icon_radius,
		icon_center + Vector2(0.43, 0.0) * icon_radius,
		icon_center + Vector2(-0.23, 0.40) * icon_radius
	])
	draw_colored_polygon(triangle, Color.WHITE)
	if _show_text:
		return
	var left: float = _caption.position.x + 2 / s
	var right: float = size.x - 18 / s
	var wave_width: float = maxf(0, right - left)
	var center_y: float = size.y * 0.36
	var max_height: float = minf(16 / s, size.y * 0.23)
	var count: int = clampi(floori(wave_width * s / 8), 10, 64)
	var spacing: float = wave_width / maxi(1, count - 1)
	var stroke: float = minf(4 / s, spacing * 0.46)
	for index in range(count):
		var t: float = float(index) / maxi(1, count - 1)
		var sample: int = mini(WAVE_HEIGHTS.size() - 1, roundi(t * (WAVE_HEIGHTS.size() - 1)))
		var amount: float = WAVE_HEIGHTS[sample]
		if active and not _reduced_motion:
			amount *= 0.68 + 0.32 * sin(_elapsed * 8.0 - index * 0.7)
		var half_height: float = maxf(stroke * 0.5, amount * max_height)
		var color: Color = ink.lerp(Color("#4e9d9b"), sin(t * PI) * 0.65)
		if disabled:
			color = Style.MUTED.lightened(0.28)
		var top := Vector2(left + t * wave_width, center_y - half_height)
		var bottom := Vector2(top.x, center_y + half_height)
		draw_line(top, bottom, color, stroke, true)
		draw_circle(top, stroke * 0.5, color)
		draw_circle(bottom, stroke * 0.5, color)
