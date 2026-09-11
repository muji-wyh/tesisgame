extends Control

signal hear_requested(word: Dictionary)
signal word_changed(word: Dictionary)
signal finished

const Style = preload("res://scripts/ui_style.gd")

var current_word: Dictionary = {}
var heading_label: Label
var progress_label: Label
var word_label: Label
var hear_hint_label: Label
var picture: TextureRect
var picture_button: Button
var hear_button: Button
var previous_button: Button
var next_button: Button
var action_button: Button
var reduced_motion: bool = false
var audio_available: bool = true

var _words: Array[Dictionary] = []
var _index: int = 0
var _paused: bool = false
var _completed: bool = false
var _card: Button
var _palette: Dictionary = {"accent": Style.GOOD}
var _compact: bool = false


func _ready() -> void:
	_build()


func _build() -> void:
	if picture != null:
		return
	custom_minimum_size = Vector2(216, 200)
	heading_label = Style.label("", 18)
	heading_label.clip_text = true
	add_child(heading_label)
	progress_label = Style.label("", 18)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(progress_label)
	_card = Button.new()
	picture_button = _card
	_card.pressed.connect(_hear)
	add_child(_card)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(picture)
	word_label = Style.label("", 36)
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word_label.clip_text = true
	_card.add_child(word_label)
	hear_hint_label = Style.label("Tap to hear", 14)
	hear_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hear_hint_label.clip_text = true
	hear_hint_label.hide()
	_card.add_child(hear_hint_label)
	hear_button = _button("Hear", "Hear the displayed word")
	previous_button = _button("Previous", "Previous word")
	next_button = _button("Next", "Next word")
	action_button = _button("Play Match", "Play Match")
	hear_button.pressed.connect(_hear)
	previous_button.pressed.connect(_move.bind(-1))
	next_button.pressed.connect(_move.bind(1))
	action_button.pressed.connect(_finish)
	resized.connect(_layout)
	set_palette(_palette)
	_refresh_controls()
	_layout()


func _button(text: String, accessible_name: String) -> Button:
	var button := Button.new()
	button.text = text
	_name_control(button, accessible_name)
	add_child(button)
	return button


func show_words(words: Array, heading: String, action_text: String = "Play Match") -> void:
	_build()
	_words.clear()
	var seen: Dictionary = {}
	for word in words:
		if word is Dictionary and word.has_all(["id", "text", "image", "audio"]) and not seen.has(word.id):
			seen[word.id] = true
			_words.append(word)
	_index = 0
	_completed = false
	_paused = false
	set_heading(heading if not _words.is_empty() else "No words to review yet.")
	action_button.text = action_text
	_name_control(action_button, action_text)
	show()
	_present_word()


func set_heading(text: String) -> void:
	_build()
	heading_label.text = text
	_layout()


func set_palette(palette: Dictionary) -> void:
	_build()
	_palette = palette
	var accent: Color = palette.get("accent", Style.GOOD)
	Style.button(_card, accent, 44)
	for style_name in ["normal", "disabled"]:
		_card.add_theme_stylebox_override(style_name, Style.box(Color.WHITE, accent.lightened(0.45), 22, 3))
	heading_label.add_theme_color_override("font_color", accent)
	for button in [hear_button, previous_button, next_button, action_button]:
		Style.button(button, accent)
		button.add_theme_font_size_override("font_size", 18)
	_refresh_controls()
	_layout()


func set_audio_available(value: bool) -> void:
	_build()
	audio_available = value
	hear_button.text = "Hear" if value else "No sound"
	_refresh_controls()


func set_compact(value: bool) -> void:
	_build()
	_compact = value
	previous_button.text = "‹" if value else "Previous"
	next_button.text = "›" if value else "Next"
	for button in [previous_button, next_button]:
		button.custom_minimum_size.x = 44 if value else 72
	action_button.clip_text = value
	hear_hint_label.visible = value
	progress_label.add_theme_font_size_override("font_size", 14 if value else 18)
	_refresh_controls()
	_layout()


func set_reduced_motion(value: bool) -> void:
	# The association view is intentionally static at every motion setting.
	reduced_motion = value


func pause(value: bool) -> void:
	_paused = value
	_refresh_controls()


func controls() -> Array[Control]:
	var result: Array[Control] = []
	if not is_visible_in_tree() or _paused or _completed or current_word.is_empty():
		return result
	var ordered: Array = [action_button, picture_button, previous_button, next_button] if _compact else [picture_button, hear_button, previous_button, next_button, action_button]
	for button in ordered:
		if button.visible and not button.disabled:
			result.append(button)
	return result


func _present_word() -> void:
	current_word = {} if _words.is_empty() else _words[_index]
	word_label.text = str(current_word.get("text", ""))
	picture.texture = null if current_word.is_empty() else load("res://" + current_word.image)
	picture.visible = not current_word.is_empty()
	word_label.visible = picture.visible
	progress_label.text = "%d of %d" % [_index + 1, _words.size()] if not _words.is_empty() else ""
	_name_control(hear_button, "Hear " + word_label.text)
	picture_button.tooltip_text = "Hear " + word_label.text
	_refresh_controls()
	_layout()
	if not current_word.is_empty():
		word_changed.emit(current_word)


func _refresh_controls() -> void:
	if hear_button == null:
		return
	var enabled: bool = not _paused and not _completed and not current_word.is_empty()
	_name_control(picture_button, ("Hear " if _compact else "") + word_label.text)
	hear_button.visible = not _compact
	hear_hint_label.text = "Tap to hear" if audio_available else "No sound"
	hear_button.disabled = not enabled or not audio_available
	picture_button.disabled = hear_button.disabled
	picture_button.focus_mode = Control.FOCUS_NONE if picture_button.disabled else Control.FOCUS_ALL
	action_button.disabled = not enabled
	previous_button.visible = _words.size() > 1
	next_button.visible = _words.size() > 1
	progress_label.visible = _words.size() > 1
	previous_button.disabled = not enabled or _index == 0
	next_button.disabled = not enabled or _index >= _words.size() - 1
	for button in [previous_button, next_button]:
		button.custom_minimum_size.x = 44 if _compact else 72
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var action_style: StyleBox = action_button.get_theme_stylebox(state)
		action_style.content_margin_left = 4 if _compact else 10
		action_style.content_margin_right = 4 if _compact else 10


func _can_interact() -> bool:
	return is_visible_in_tree() and not _paused and not _completed and not current_word.is_empty()


func _hear() -> void:
	if _can_interact() and audio_available:
		hear_requested.emit(current_word)


func _move(direction: int) -> void:
	if not _can_interact():
		return
	var next_index: int = clampi(_index + direction, 0, _words.size() - 1)
	if next_index != _index:
		var focused: Control = get_viewport().gui_get_focus_owner()
		_index = next_index
		_present_word()
		if focused == next_button and next_button.disabled:
			action_button.grab_focus()
		elif focused == previous_button and previous_button.disabled:
			(next_button if not next_button.disabled else action_button).grab_focus()


func _finish() -> void:
	if not _can_interact():
		return
	_completed = true
	_refresh_controls()
	finished.emit()


func _layout() -> void:
	if _card == null:
		return
	if _compact:
		_layout_compact()
		return
	var multiple: bool = _words.size() > 1
	var wide: bool = size.x >= 420 and size.x >= size.y * 1.3
	heading_label.add_theme_font_size_override("font_size", 18)
	custom_minimum_size = Vector2(216, 320 if multiple and not wide else 200)
	var heading_width: float = maxf(0, size.x - (80 if multiple else 0))
	heading_label.position = Vector2.ZERO
	heading_label.size = Vector2(heading_width, 26)
	progress_label.position = Vector2(heading_width, 0)
	progress_label.size = Vector2(size.x - heading_width, 26)
	var button_height: float = 152 if multiple else 72
	var button_origin: Vector2
	var button_width: float
	if wide:
		var content_width: float = minf(size.x, 900)
		var content_left: float = (size.x - content_width) * 0.5
		var picture_width: float = floorf((content_width - 12) * 0.48)
		var card_height: float = minf(size.y - 32, 420)
		_card.position = Vector2(content_left, 32 + (size.y - 32 - card_height) * 0.5)
		_card.size = Vector2(picture_width, card_height)
		button_width = (content_width - picture_width - 20) * 0.5
		button_origin = Vector2(content_left + picture_width + 12, 32 + maxf(0, (size.y - 32 - button_height) * 0.5))
	else:
		var content_width: float = minf(size.x, 480)
		var card_height: float = maxf(88, minf(size.y - 40 - button_height, 420))
		var group_height: float = card_height + 8 + button_height
		_card.position = Vector2((size.x - content_width) * 0.5, 32 + maxf(0, (size.y - 32 - group_height) * 0.5))
		_card.size = Vector2(content_width, card_height)
		button_width = (content_width - 8) * 0.5
		button_origin = Vector2(_card.position.x, _card.get_rect().end.y + 8)
	hear_button.position = button_origin
	action_button.position = button_origin + Vector2(button_width + 8, 0)
	previous_button.position = button_origin + Vector2(0, 80)
	next_button.position = button_origin + Vector2(button_width + 8, 80)
	for button in [hear_button, previous_button, next_button, action_button]:
		var button_font: Font = button.get_theme_font("font")
		var button_font_size: int = 18
		while button_font_size > 14 and button_font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button_font_size).x > button_width - 20:
			button_font_size -= 1
		button.add_theme_font_size_override("font_size", button_font_size)
		button.size = Vector2(button_width, 72)
	if _card.size.y < 150:
		var edge: float = _card.size.y - 16
		picture.position = Vector2(8, 8)
		picture.size = Vector2(edge, edge)
		word_label.position = Vector2(edge + 12, 8)
		word_label.size = Vector2(maxf(1, _card.size.x - edge - 20), edge)
	else:
		var edge: float = minf(320, minf(_card.size.x - 16, _card.size.y - 72))
		picture.position = Vector2((_card.size.x - edge) * 0.5, (_card.size.y - edge - 56) * 0.5)
		picture.size = Vector2.ONE * edge
		word_label.position = Vector2(8, picture.get_rect().end.y + 4)
		word_label.size = Vector2(_card.size.x - 16, 52)
	var font: Font = word_label.get_theme_font("font")
	var font_size: int = 36
	while font_size > 16 and font.get_string_size(word_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > word_label.size.x:
		font_size -= 1
	word_label.add_theme_font_size_override("font_size", font_size)


func _layout_compact() -> void:
	var wide: bool = size.x >= 392
	custom_minimum_size = Vector2(160, 104 if wide else 176)
	size.y = custom_minimum_size.y
	var navigation_width: float = 44
	var gap: float = 8 if size.x >= 176 else 0
	var action_width: float = 88 if wide else size.x - navigation_width * 2 - gap * 2
	var controls_width: float = navigation_width * 2 + action_width + gap * 2
	heading_label.position = Vector2.ZERO
	heading_label.size = Vector2(maxf(0, size.x - (64 if _words.size() > 1 else 0)), 24)
	progress_label.position = Vector2(size.x - 64, 0)
	progress_label.size = Vector2(64, 24)
	var heading_font: Font = heading_label.get_theme_font("font")
	var heading_size: int = 16
	while heading_size > 12 and heading_font.get_string_size(heading_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_size).x > heading_label.size.x:
		heading_size -= 1
	heading_label.add_theme_font_size_override("font_size", heading_size)
	_card.position = Vector2(0, 32 if wide else 24)
	_card.size = Vector2(size.x - controls_width - 8 if wide else size.x, 72)
	picture.position = Vector2(8, 12)
	picture.size = Vector2(48, 48)
	word_label.position = Vector2(64, 6)
	word_label.size = Vector2(maxf(1, _card.size.x - 72), 32)
	hear_hint_label.position = Vector2(64, 38)
	hear_hint_label.size = Vector2(word_label.size.x, 26)
	var font: Font = word_label.get_theme_font("font")
	var font_size: int = 22
	while font_size > 14 and font.get_string_size(word_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > word_label.size.x:
		font_size -= 1
	word_label.add_theme_font_size_override("font_size", font_size)
	var origin := Vector2(_card.get_rect().end.x + 8, 32) if wide else Vector2(0, 104)
	previous_button.position = origin
	previous_button.size = Vector2(navigation_width, 72)
	action_button.position = origin + Vector2(navigation_width + gap, 0)
	action_button.size = Vector2(action_width, 72)
	next_button.position = origin + Vector2(navigation_width + action_width + gap * 2, 0)
	next_button.size = Vector2(navigation_width, 72)
	hear_button.position = origin
	hear_button.size = Vector2(72, 72)
	font = action_button.get_theme_font("font")
	font_size = 18
	var content_width: float = action_width - action_button.get_theme_stylebox("normal").get_minimum_size().x
	while font_size > 12 and font.get_string_size(action_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > content_width:
		font_size -= 1
	action_button.add_theme_font_size_override("font_size", font_size)


func _name_control(control: Control, label: String) -> void:
	for property in control.get_property_list():
		if property.name == "accessibility_name":
			control.set("accessibility_name", label)
			return
