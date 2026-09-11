extends Button

const Style = preload("res://scripts/ui_style.gd")

class MatchMark:
	extends Control

	var hinted: bool = false

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.44
		if not hinted:
			Style.draw_match_badge(self, center, radius)
			return
		var star := PackedVector2Array()
		for index in range(10):
			star.append(center + Vector2.UP.rotated(PI * float(index) / 5.0) * radius * (1.0 if index % 2 == 0 else 0.45))
		draw_colored_polygon(star, Color("#ffd24d"))
		star.append(star[0])
		draw_polyline(star, Style.INK, 2.0, true)


class FeedbackOverlay:
	extends Control

	var kind: String = ""
	var progress: float = 0.0
	var accent: Color = Style.GOOD

	func _draw() -> void:
		if kind.is_empty():
			return
		var center := size * 0.5
		var edge := minf(size.x, size.y)
		var fade := 1.0 - progress
		var tint := Color(Style.GOOD if kind == "matched" else Style.WRONG if kind == "wrong" else accent, fade)
		if kind == "selected":
			var radius := edge * lerpf(0.29, 0.46, progress)
			draw_arc(center, radius, 0.0, TAU, 40, Color(tint, fade * 0.65), lerpf(4.0, 1.0, progress), true)
			for index in range(4):
				draw_circle(center + Vector2.UP.rotated(index * PI * 0.5) * radius, edge * 0.022 * fade, tint)
		elif kind == "matched":
			for index in range(8):
				var direction := Vector2.UP.rotated(float(index) * TAU / 8.0)
				var point := center + direction * edge * lerpf(0.23, 0.44, progress)
				var radius := maxf(1.0, edge * 0.035 * fade)
				draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), tint, 2.0, true)
				draw_line(point - Vector2(0, radius), point + Vector2(0, radius), tint, 2.0, true)
		else:
			var sway := sin(progress * TAU * 2.0) * edge * 0.025 * fade
			for index in range(3):
				var point := center + Vector2((index - 1) * edge * 0.1 + sway, edge * 0.36)
				draw_circle(point, edge * 0.022, tint)


var card_data: Dictionary = {}
var picture: TextureRect
var word_label: Label
var match_mark: MatchMark
var accent: Color = Style.GOOD
var reduced_motion: bool = false
var _feedback: FeedbackOverlay
var _feedback_state: String = ""
var _feedback_kind: String = ""
var _feedback_left: float = 0.0
var _feedback_duration: float = 0.0


func _ready() -> void:
	set_process(_feedback_left > 0.0 and not reduced_motion)


func setup(value: Dictionary) -> void:
	card_data = value
	name = value.id.replace(":", "_")
	tooltip_text = value.word.text if value.kind == "word" else "Picture: " + value.word.text
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(72, 72)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 12
	picture.offset_top = 10
	picture.offset_right = -12
	picture.offset_bottom = -10
	picture.visible = value.kind == "image"
	picture.texture = load("res://" + value.word.image)
	word_label = Style.label(value.word.text, 32)
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.clip_text = true
	word_label.visible = value.kind == "word"
	add_child(word_label)
	word_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match_mark = MatchMark.new()
	match_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(match_mark)
	match_mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	match_mark.offset_left = -36
	match_mark.offset_right = -8
	match_mark.offset_top = 8
	match_mark.offset_bottom = 36
	match_mark.hide()
	_feedback = FeedbackOverlay.new()
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feedback)
	_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback.hide()
	visibility_changed.connect(_visibility_changed)
	resized.connect(_fit_text)
	set_process(false)
	_fit_text()


func refresh(palette: Dictionary, selected: bool, matched: bool, wrong: bool, locked: bool, hinted: bool = false) -> void:
	accent = palette.accent
	picture.visible = card_data.kind == "image"
	word_label.visible = card_data.kind == "word"
	_fit_text()
	var state: String = "matched" if matched else "wrong" if wrong else "selected" if selected and not locked else ""
	if state != _feedback_state:
		_feedback_state = state
		_stop_feedback()
		if not state.is_empty() and not reduced_motion:
			_feedback_kind = state
			_feedback_duration = 0.6 if state == "matched" else 0.4
			_feedback_left = _feedback_duration
			_feedback.kind = state
			_feedback.progress = 0.0
			_feedback.show()
			_feedback.queue_redraw()
			set_process(true)
	_feedback.accent = accent
	var fill: Color = Color.WHITE
	var border: Color = accent.lightened(0.68)
	if selected:
		fill = accent.lightened(0.86)
		border = accent
	elif matched:
		fill = Color("#e7f5e9")
		border = Style.GOOD
	elif wrong:
		fill = Color("#ffe8e2")
		border = Style.WRONG
	elif hinted:
		fill = Color("#fff8cf")
		border = Color("#8f7400")
	var normal: StyleBoxFlat = Style.box(fill, border, 20, 3)
	normal.shadow_color = Color(0.15, 0.22, 0.3, 0.1)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	add_theme_stylebox_override("hover", Style.box(fill, accent, 20, 3))
	add_theme_stylebox_override("pressed", Style.box(accent.lightened(0.8), accent, 20, 3))
	add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, accent, 20, 4))
	disabled = matched or locked
	match_mark.hinted = hinted and not matched
	match_mark.visible = matched or hinted
	match_mark.queue_redraw()
	picture.modulate.a = 0.4 if matched else 1.0
	word_label.modulate.a = 0.4 if matched else 1.0


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_stop_feedback()


func clear_feedback() -> void:
	_feedback_state = ""
	_stop_feedback()


func _stop_feedback() -> void:
	_feedback_kind = ""
	_feedback_left = 0.0
	set_process(false)
	if _feedback != null:
		_feedback.kind = ""
		_feedback.hide()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		_stop_feedback()


func _process(delta: float) -> void:
	if _feedback_left <= 0.0:
		return
	_feedback_left = maxf(0.0, _feedback_left - delta)
	if is_zero_approx(_feedback_left):
		_stop_feedback()
	else:
		_feedback.progress = 1.0 - _feedback_left / _feedback_duration
		_feedback.queue_redraw()


func _fit_text() -> void:
	if word_label == null:
		return
	var font: Font = word_label.get_theme_font("font")
	var font_size: int = clampi(int(minf(size.x * 0.36, size.y * 0.52)), 20, 64)
	var minimum_font: int = 12 if size.x < 72 else 16
	var available_width: float = word_label.size.x if size.x < 72 else size.x - 18
	while font_size > minimum_font and font.get_string_size(word_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
		font_size -= 1
	word_label.add_theme_font_size_override("font_size", font_size)
	# Short Memory cards need a smaller corner mark to leave the word readable.
	if match_mark != null:
		var short_card: bool = size.y < 64
		match_mark.offset_left = -18 if short_card else -36
		match_mark.offset_right = -4 if short_card else -8
		match_mark.offset_top = 0 if short_card else 8
		match_mark.offset_bottom = 14 if short_card else 36
