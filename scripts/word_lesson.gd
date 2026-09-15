extends Control

signal hear_requested(word: Dictionary)
signal word_changed(word: Dictionary)

const Style = preload("res://scripts/ui_style.gd")

var current_word: Dictionary = {}
var progress_label: Label
var word_label: Label
var hear_hint_label: Label
var picture: TextureRect
var picture_button: Button
var reduced_motion: bool = false
var audio_available: bool = true

var _words: Array[Dictionary] = []
var _index: int = 0
var _paused: bool = false
var _card: Button
var _palette: Dictionary = {"accent": Style.GOOD}
var _pointer: int = -1
var _press: Vector2
var _travel: float = 0.0
var _card_home: Vector2
var _slide_preview: Button
var _slide_tween: Tween
var _keyboard_focus: bool = false


func _ready() -> void:
	_build()


func _build() -> void:
	if picture != null:
		return
	custom_minimum_size = Vector2(216, 200)
	clip_contents = true
	progress_label = Style.label("", 18)
	progress_label.name = "Progress"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card = Button.new()
	picture_button = _card
	_card.pressed.connect(_hear)
	add_child(_card)
	picture = TextureRect.new()
	picture.name = "Picture"
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(picture)
	word_label = Style.label("", 36)
	word_label.name = "Word"
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word_label.clip_text = true
	_card.add_child(word_label)
	hear_hint_label = Style.label("Tap to hear", 14)
	hear_hint_label.name = "Cue"
	hear_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hear_hint_label.clip_text = true
	hear_hint_label.hide()
	_card.add_child(hear_hint_label)
	_card.add_child(progress_label)
	resized.connect(_layout)
	visibility_changed.connect(cancel_swipe)
	set_palette(_palette)
	_refresh_controls()
	_layout()


func show_words(words: Array) -> void:
	_build()
	cancel_swipe()
	_words.clear()
	var seen: Dictionary = {}
	for word in words:
		if word is Dictionary and word.has_all(["id", "text", "image", "audio"]) and not seen.has(word.id):
			seen[word.id] = true
			_words.append(word)
	_index = 0
	_paused = false
	show()
	_present_word()


func set_palette(palette: Dictionary) -> void:
	_build()
	_palette = palette
	var accent: Color = palette.get("accent", Style.GOOD)
	Style.button(_card, accent, 44)
	var normal := Style.box(Color.WHITE, accent.lightened(0.72), ceili(20 / Style.ui_scale(self)), 1)
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		_card.add_theme_stylebox_override(style_name, normal)
	_update_focus_style()
	_refresh_controls()
	_layout()


func set_audio_available(value: bool) -> void:
	_build()
	audio_available = value
	_refresh_controls()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		cancel_swipe()


func pause(value: bool) -> void:
	_paused = value
	if value:
		cancel_swipe()
	_refresh_controls()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if not is_visible_in_tree() or _paused or current_word.is_empty():
		return result
	if picture_button.visible and not picture_button.disabled:
		result.append(picture_button)
	return result


func _present_word() -> void:
	current_word = {} if _words.is_empty() else _words[_index]
	word_label.text = str(current_word.get("text", ""))
	picture.texture = null if current_word.is_empty() else load("res://" + current_word.image)
	picture.visible = not current_word.is_empty()
	word_label.visible = picture.visible
	progress_label.text = "%d/%d" % [_index + 1, _words.size()] if not _words.is_empty() else ""
	_refresh_controls()
	_layout()
	if not current_word.is_empty():
		word_changed.emit(current_word)


func _refresh_controls() -> void:
	if picture_button == null:
		return
	var enabled: bool = not _paused and not current_word.is_empty()
	_name_control(picture_button, word_label.text)
	hear_hint_label.show()
	hear_hint_label.text = "Swipe left or right · " + ("Tap to hear" if audio_available else "No sound")
	picture_button.disabled = not enabled
	picture_button.focus_mode = Control.FOCUS_NONE if picture_button.disabled else Control.FOCUS_ALL
	progress_label.visible = _words.size() > 1


func _can_interact() -> bool:
	return is_visible_in_tree() and not _paused and not current_word.is_empty()


func _hear() -> void:
	if _can_interact() and audio_available:
		hear_requested.emit(current_word)


func _move(direction: int) -> void:
	if not _can_interact():
		return
	var next_index: int = clampi(_index + direction, 0, _words.size() - 1)
	if next_index != _index:
		_index = next_index
		_present_word()


func _layout() -> void:
	if _card == null:
		return
	cancel_swipe()
	custom_minimum_size = Vector2(216, 200)
	var scale: float = Style.ui_scale(self)
	_card.position = Vector2.ZERO
	_card_home = _card.position
	_card.size = size
	progress_label.position = Vector2(size.x - 64 / scale, 12 / scale)
	progress_label.size = Vector2(52, 24) / scale
	progress_label.add_theme_font_size_override("font_size", ceili(14 / scale))
	if _card.size.x >= 420 and _card.size.x >= _card.size.y * 1.3:
		var edge: float = minf(360 / scale, minf(_card.size.x * 0.5 - 24 / scale, _card.size.y - 48 / scale))
		picture.position = Vector2((_card.size.x * 0.5 - edge) * 0.5, (_card.size.y - edge) * 0.5)
		picture.size = Vector2.ONE * edge
		word_label.position = Vector2(_card.size.x * 0.5, _card.size.y * 0.5 - 40 / scale)
		word_label.size = Vector2(_card.size.x * 0.5 - 12 / scale, 52 / scale)
		hear_hint_label.position = word_label.position + Vector2(0, 56 / scale)
		hear_hint_label.size = Vector2(word_label.size.x, 44 / scale)
	else:
		var edge: float = minf(360 / scale, minf(_card.size.x - 24 / scale, _card.size.y - 100 / scale))
		var top: float = clampf((_card.size.y - edge - 64 / scale) * 0.25, 12 / scale, 64 / scale)
		picture.position = Vector2((_card.size.x - edge) * 0.5, top)
		picture.size = Vector2.ONE * edge
		word_label.position = Vector2(8 / scale, picture.get_rect().end.y + 4 / scale)
		word_label.size = Vector2(_card.size.x - 16 / scale, 52 / scale)
		hear_hint_label.position = Vector2(8 / scale, _card.size.y - 32 / scale)
		hear_hint_label.size = Vector2(_card.size.x - 16 / scale, 24 / scale)
	hear_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hear_hint_label.add_theme_font_size_override("font_size", ceili(12 / scale))
	_fit_word_label(word_label)
	_update_focus_style()


func _fit_word_label(label: Label) -> void:
	var font: Font = label.get_theme_font("font")
	var scale: float = Style.ui_scale(self)
	var font_size: int = ceili(40 / scale)
	while font_size > ceili(16 / scale) and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func cancel_swipe() -> void:
	_pointer = -1
	_travel = 0.0
	if _slide_tween != null:
		_slide_tween.kill()
	_slide_tween = null
	if _card != null:
		_card.position = _card_home
	if _slide_preview != null:
		_slide_preview.hide()


func _in_display(point: Vector2) -> bool:
	return Rect2(_card_home, _card.size).has_point(get_global_transform().affine_inverse() * point)


func _prepare_slide_preview(direction: int) -> bool:
	var index: int = _index + direction
	if index < 0 or index >= _words.size():
		if _slide_preview != null:
			_slide_preview.hide()
		return false
	if _slide_preview == null:
		_slide_preview = _card.duplicate(0) as Button
		_slide_preview.name = "SlidePreview"
		_slide_preview.disabled = true
		_slide_preview.focus_mode = Control.FOCUS_NONE
		_slide_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slide_preview.tooltip_text = ""
		add_child(_slide_preview)
	_slide_preview.size = _card.size
	_slide_preview.add_theme_stylebox_override("disabled", _card.get_theme_stylebox("normal"))
	for name in ["Picture", "Word", "Cue", "Progress"]:
		var source: Control = _card.get_node(name)
		var target: Control = _slide_preview.get_node(name)
		target.position = source.position
		target.size = source.size
		if source is Label:
			target.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))
	var art: TextureRect = _slide_preview.get_node("Picture")
	var label: Label = _slide_preview.get_node("Word")
	var cue: Label = _slide_preview.get_node("Cue")
	art.texture = load("res://" + _words[index].image)
	label.text = _words[index].text
	_name_control(_slide_preview, label.text)
	cue.text = hear_hint_label.text
	var count: Label = _slide_preview.get_node("Progress")
	count.text = "%d/%d" % [index + 1, _words.size()]
	count.add_theme_font_size_override("font_size", progress_label.get_theme_font_size("font_size"))
	_fit_word_label(label)
	_slide_preview.show()
	return true


func _follow_drag(delta: Vector2) -> void:
	if absf(delta.x) < 12 or absf(delta.x) <= absf(delta.y) * 1.35:
		_card.position = _card_home
		if _slide_preview != null:
			_slide_preview.hide()
		return
	var direction: int = 1 if delta.x < 0 else -1
	var adjacent: bool = _prepare_slide_preview(direction)
	var offset: float = clampf(delta.x, -_card.size.x, _card.size.x) * (1.0 if adjacent else 0.22)
	_card.position.x = _card_home.x + offset
	if adjacent:
		_slide_preview.position = _card_home + Vector2(direction * (_card.size.x + 12) + offset, 0)


func _settle_slide(preview_target: float) -> void:
	if reduced_motion or is_equal_approx(_card.position.x, _card_home.x):
		cancel_swipe()
		return
	_slide_tween = create_tween().set_parallel(true)
	_slide_tween.tween_property(_card, "position:x", _card_home.x, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _slide_preview != null and _slide_preview.visible:
		_slide_tween.tween_property(_slide_preview, "position:x", preview_target, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.chain().tween_callback(cancel_swipe)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		cancel_swipe()


func _update_focus_style() -> void:
	if _card == null:
		return
	var scale: float = Style.ui_scale(self)
	_card.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, _palette.accent, ceili(20 / scale), maxi(1, ceili(2 / scale)))
		if _keyboard_focus else StyleBoxEmpty.new())


func _input(event: InputEvent) -> void:
	if not _can_interact():
		return
	if event is InputEventKey or event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.55):
		_keyboard_focus = true
		_update_focus_style()
	elif (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_keyboard_focus = false
		_update_focus_style()
	if event is InputEventKey and _card.has_focus():
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_move(-1 if event.is_action_pressed("ui_left") else 1)
			get_viewport().set_input_as_handled()
		return
	var pointer := -2
	var pressed := false
	var released := false
	var moving := false
	var point := Vector2.ZERO
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# Touch owns its gesture; the emulated mouse must not also pronounce or turn.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			if _pointer >= 0 or _in_display(event.position):
				get_viewport().set_input_as_handled()
			return
		point = event.position
		if event is InputEventMouseButton:
			if event.button_index != MOUSE_BUTTON_LEFT:
				return
			pressed = event.pressed
			released = not pressed
		else:
			if _pointer == -2 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				cancel_swipe()
			moving = true
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer = event.index
		point = event.position
		if _pointer >= 0 or _in_display(point):
			get_viewport().set_input_as_handled()
		if event is InputEventScreenTouch:
			if event.canceled or (event.pressed and _pointer != -1 and _pointer != pointer):
				cancel_swipe()
				return
			pressed = event.pressed
			released = not pressed
		else:
			moving = true
	else:
		return
	if pressed and _pointer == -1 and _in_display(point):
		cancel_swipe()
		_pointer = pointer
		_press = get_global_transform().affine_inverse() * point
		_travel = 0.0
		_card.grab_focus()
		get_viewport().set_input_as_handled()
	elif pointer == _pointer:
		get_viewport().set_input_as_handled()
		var delta: Vector2 = get_global_transform().affine_inverse() * point - _press
		_travel = maxf(_travel, delta.length())
		if moving:
			_follow_drag(delta)
			return
		if released:
			var tapped: bool = _travel < 12.0
			var inside: bool = _in_display(point)
			var direction: int = 1 if delta.x < 0 else -1
			var next: int = _index + direction
			var turn: bool = inside and next >= 0 and next < _words.size() and absf(delta.x) >= clampf(_card.size.x * 0.12, 40.0, 96.0) and absf(delta.x) > absf(delta.y) * 1.35
			_pointer = -1
			_travel = 0.0
			var span: float = _card.size.x + 12
			if turn:
				var offset: float = _card.position.x - _card_home.x
				_move(direction)
				if not reduced_motion:
					_prepare_slide_preview(-direction)
					_card.position.x = _card_home.x + direction * span + offset
					_slide_preview.position = _card_home + Vector2(offset, 0)
					_settle_slide(_card_home.x - direction * span)
			elif tapped and inside:
				cancel_swipe()
				_hear()
			else:
				_settle_slide(_card_home.x + direction * span)


func _name_control(control: Control, label: String) -> void:
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", label)
			return
