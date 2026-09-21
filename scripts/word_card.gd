extends Button

const Style = preload("res://scripts/ui_style.gd")
const WordPlay = preload("res://scripts/word_play.gd")
const CardMotion = preload("res://scripts/card_motion.gd")

class MatchMark:
	extends Control

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.44
		Style.draw_match_badge(self, center, radius)


class FeedbackOverlay:
	extends Control

	var kind: String = ""
	var progress: float = 0.0
	var accent: Color = Style.GOOD
	var spark: Color = Color("#ffd24d")
	var particle_count: int = 8

	func _draw() -> void:
		if kind.is_empty():
			return
		var center := size * 0.5
		var edge := minf(size.x, size.y)
		var fade := 1.0 - progress
		var tint := Color(Style.GOOD if kind == "matched" else Style.WRONG if kind == "wrong" else accent, fade)
		if kind in ["selected", "tap"]:
			var radius := edge * lerpf(0.29, 0.44, progress)
			draw_arc(center, radius, 0.0, TAU, 40, Color(tint, fade * 0.45), lerpf(2.5, 1.0, progress), true)
			var sparkle_size: float = minf(5 / Style.ui_scale(self), edge * 0.05) * (1.0 - progress * 0.65)
			for index in range(particle_count):
				var direction := Vector2.UP.rotated(TAU * float(index) / float(particle_count) + progress * 0.18)
				var point := center + direction * radius
				var color := Color(accent if index % 2 == 0 else spark, fade)
				var star := PackedVector2Array()
				for vertex in range(8):
					star.append(point + Vector2.UP.rotated(PI * float(vertex) / 4.0) * sparkle_size * (1.0 if vertex % 2 == 0 else 0.28))
				draw_colored_polygon(star, color)
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
var face_up: bool = true
var _face: Control
var _back: Control
var _shown_face_up: bool = true
var _flip: Tween
var _feedback: FeedbackOverlay
var _feedback_state: String = ""
var _feedback_kind: String = ""
var _feedback_left: float = 0.0
var _feedback_duration: float = 0.0
var _word_play := WordPlay.new()
var _press_motion := CardMotion.new()


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
	_face = Control.new()
	_face.name = "CardFace"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(picture)
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
	_face.add_child(word_label)
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
	_face.resized.connect(_resize_face)
	set_process(false)
	_resize_face()


func refresh(palette: Dictionary, selected: bool, matched: bool, wrong: bool, locked: bool, hinted: bool = false) -> void:
	stop_word_play()
	if accent != palette.accent:
		stop_press()
	accent = palette.accent
	_show_face(_shown_face_up)
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
	_feedback.spark = palette.get("spark", accent.lightened(0.3))
	var fill: Color = Color.WHITE.lerp(palette.get("light", Color.WHITE), 0.1)
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
	if hinted and not selected and not matched and not wrong:
		var hint_colors: Dictionary = Style.hint_palette(palette)
		fill = hint_colors.fill
		border = hint_colors.border
	var radius: int = ceili(14 / Style.ui_scale(self)) if _back != null else 20
	var normal: StyleBoxFlat = Style.box(fill, border, radius, 2 if selected or matched or wrong or hinted else 1)
	normal.shadow_color = Color(accent, 0.11)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	add_theme_stylebox_override("hover", Style.box(fill, accent, radius, 3))
	add_theme_stylebox_override("pressed", Style.box(accent.lightened(0.8), accent, radius, 3))
	add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, accent, radius, 4))
	disabled = matched or locked
	match_mark.visible = matched
	match_mark.queue_redraw()
	picture.modulate.a = 0.4 if matched else 1.0
	word_label.modulate.a = 0.4 if matched else 1.0


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		stop_word_play()
		_stop_feedback()
		_settle_flip()


func set_back(back: Control) -> void:
	_back = back
	_face.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_face(_shown_face_up)


func set_face_up(value: bool, animate: bool = true) -> void:
	var changed: bool = face_up != value
	if changed:
		stop_word_play()
	face_up = value
	if not animate or reduced_motion or not is_visible_in_tree():
		_settle_flip()
		return
	if not changed:
		return
	if _flip != null:
		_flip.kill()
	_flip = create_tween()
	if _shown_face_up != value:
		_flip.tween_property(_face, "scale:x", 0.0, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_flip.tween_callback(_show_face.bind(value))
	_flip.tween_property(_face, "scale:x", 1.0, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_face(value: bool) -> void:
	_shown_face_up = value
	picture.visible = value and card_data.kind == "image"
	word_label.visible = value and card_data.kind == "word"
	word_label.text = card_data.word.text if value else ""
	if _back != null:
		_back.visible = not value
	_fit_text()


func _settle_flip() -> void:
	stop_press()
	if _flip != null:
		_flip.kill()
		_flip = null
	if _face != null:
		_face.scale = Vector2.ONE
		_show_face(face_up)


func _resize_face() -> void:
	stop_word_play()
	_settle_flip()
	_face.pivot_offset = _face.size * 0.5


func clear_feedback() -> void:
	stop_word_play()
	_feedback_state = ""
	_stop_feedback()
	_settle_flip()


func _stop_feedback() -> void:
	_feedback_kind = ""
	_feedback_left = 0.0
	set_process(false)
	if _feedback != null:
		_feedback.kind = ""
		_feedback.hide()


func _visibility_changed() -> void:
	if not is_visible_in_tree():
		stop_word_play()
		_stop_feedback()
		_settle_flip()


func play_word() -> void:
	if face_up and _shown_face_up and card_data.get("kind", "") == "image":
		_word_play.play(picture, card_data.word.id, reduced_motion)


func play_press() -> void:
	if not disabled:
		_press_motion.play(_face, reduced_motion)
		if not reduced_motion and is_visible_in_tree() and not (_feedback_kind in ["matched", "wrong"] and _feedback_left > 0):
			_feedback_kind = "tap"
			_feedback_duration = 0.45
			_feedback_left = _feedback_duration
			_feedback.kind = "tap"
			_feedback.progress = 0.0
			_feedback.show()
			_feedback.queue_redraw()
			set_process(true)


func stop_press() -> void:
	_press_motion.stop()
	if _feedback_kind == "tap":
		_stop_feedback()


func stop_word_play() -> void:
	_word_play.stop()


func _exit_tree() -> void:
	stop_word_play()
	stop_press()


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
	var minimum_font: int = 12
	var available_width: float = word_label.size.x if size.x < 72 else size.x - 18
	while font_size > minimum_font and font.get_string_size(word_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
		font_size -= 1
	word_label.add_theme_font_size_override("font_size", font_size)
	# Short Memory cards need a smaller corner mark to leave the word readable.
	if match_mark != null:
		if _back != null:
			var scale: float = Style.ui_scale(self)
			var side: float = minf(22 / scale, minf(size.x, size.y) * 0.3)
			match_mark.offset_left = -side - 4 / scale
			match_mark.offset_right = -4 / scale
			match_mark.offset_top = 4 / scale
			match_mark.offset_bottom = 4 / scale + side
			return
		var short_card: bool = size.y < 64
		match_mark.offset_left = -18 if short_card else -36
		match_mark.offset_right = -4 if short_card else -8
		match_mark.offset_top = 0 if short_card else 8
		match_mark.offset_bottom = 14 if short_card else 36
